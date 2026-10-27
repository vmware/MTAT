MTAT: vSphere & Memory Tiering Best Practices Alignment
=======================================================

This document explains the capacity-planning and sizing decisions built into
MTAT, the vSphere/ Memory Tiering technical reasoning behind each one, and
exactly where in the tool each is enforced. It's meant to answer "why does the
tool do X" for anyone reviewing an assessment it produced, or deciding whether
to trust its sizing output for a hardware purchase.

Each item below is labeled as one of: - **Hard vSphere limit**: a real platform
constraint; MTAT enforces it because exceeding it produces an unsupported or
non-functional configuration, not just a suboptimal one. - **Widely recognized
capacity-planning guidance**: a convention broadly recommended across VMware's
own sizing guidance and general vSphere capacity-planning practice, not unique
to MTAT. - **Memory Tiering-specific guidance**: a recommendation specific to
how the Memory Tiering feature itself technically behaves, distinct from general
vSphere sizing conventions. - **MTAT design choice**: a conservative judgment
call this tool makes that isn't a documented external threshold, included here
for transparency about what's a "rule" versus a "default."

1. CPU Sizing Headroom: cap new hosts at 80% average utilization
----------------------------------------------------------------

**Category:** Widely recognized capacity-planning guidance

Sizing new hardware to run at 100% average CPU utilization leaves no room for
DRS load-balancing moves, no room to absorb a failed host's workload during HA
failover, and no room for burst load above the historical average. Capping
planned utilization at 80% leaves that headroom by design.

**Where MTAT applies it:** the Sizing & Savings engine's host-count math
(`runSimulationMath()`, both the "Target Node Size" and "Target Usable Hosts"
modes) divides the cluster's total current CPU demand by `80% × (New Node CPU
Capacity multiplier)` when solving for host count, so a plan is never sized
assuming new hosts run hotter than 80% on average. The "New Node CPU Capacity"
selector (1.0x–3.0x) lets this scale correctly when the replacement hardware is
faster than the existing fleet.

This is separate from the Baseline Assessment checklist's own CPU threshold
(below): the 80% cap is a *sizing* rule for how many new hosts to buy; the
checklist's 50% is a *candidacy* signal for whether the source cluster is a good
fit for Memory Tiering in the first place.

2. Baseline Candidacy: CPU Usage (Avg) ≤ 50%
--------------------------------------------

**Category:** MTAT design choice, informed by Memory Tiering-specific guidance

Memory Tiering trades some memory-access latency (pages served from NVMe instead
of DRAM) for memory cost savings. A cluster that's already CPU-constrained is a
weaker candidate for this tradeoff, since it has less slack to absorb any added
latency-driven overhead. A ≤50% average CPU utilization bar is a conservative
"this cluster clearly isn't CPU-bound" signal, well below the 80% sizing ceiling
above, deliberately stricter, since this is a go/no-go candidacy check rather
than a hardware-purchase sizing calculation.

**Where MTAT applies it:** Baseline Assessment checklist, "CPU Usage (Avg)
[Target: ≤ 50%]" row: shows PASS/WARN based on the cluster's actual measured
average CPU utilization.

3. Active Memory ≤ 50% of Tier-0 (DRAM) capacity
------------------------------------------------

**Category:** Memory Tiering-specific guidance

Memory Tiering keeps the "hot" (actively-accessed) portion of a VM's memory in
the fast DRAM tier and the "cold" (rarely-accessed) portion in the slower NVMe
tier. If a cluster's actual Active Memory footprint approaches or exceeds the
size of the DRAM tier, tiering can't keep the genuinely hot pages resident in
DRAM. Pages that should be fast start landing on NVMe, and performance degrades.
Keeping Active Memory at or below roughly half of deployed DRAM leaves headroom
for workload growth, day-to-day variance, and the inherent slack of sizing from
a sampled time window rather than a perfect real-time measurement.

**Where MTAT applies it in two places:** - **Candidacy check:** Baseline
Assessment checklist, "Active Memory (Peak) [Target: ≤ 50%]" row. - **Sizing
math:** the Sizing & Savings engine solves for however much DRAM (or however
many hosts) is needed so the cluster's Active Memory never exceeds 50% of total
deployed Tier-0 DRAM capacity (the `0.50` constant used in both Greenfield
sizing modes). A configuration that would put Active Memory above that line
drives the "Sizing Rationale" explanation shown on-screen, naming Active Memory
as the limiting factor and suggesting a larger node capacity or a lower NVMe
ratio.

When some VMs must keep their memory in DRAM (see \#12), their memory is set
aside first: the check becomes "Active Memory of the remaining VMs at or below
50% of the DRAM that is left for tiering", and the refresh sizing reserves DRAM
for those VMs before applying the 50% rule. With no such VMs this is exactly
the plain Active / DRAM check. A cluster where some hosts returned no Active
Memory samples for the range never passes this check; it shows CHECK DATA, and
the customer report leaves it out of the savings.

4. Worst-case (peak) sizing for Active Memory; time-weighted average for CPU and Consumed Memory
------------------------------------------------------------------------------------------------

**Category:** Memory Tiering-specific guidance

Active Memory is the one metric most sensitive to Tier-0 capacity (see \#3): if
it spikes above DRAM capacity even briefly during a business-critical window,
that's exactly when a performance problem would actually be felt. Sizing to its
*average* would under-provision for that spike. CPU and Consumed Memory are more
elastic under transient overcommit (the CPU scheduler and memory
ballooning/compression absorb short bursts more gracefully than Tier-0 capacity
does for hot pages), so a plain time-weighted average is an appropriate, less
conservative basis for those two.

**Where MTAT applies it:** every historical `Get-Stat` query requests only the
`.average` rollup (works at any vCenter Statistics Level, see \#9 below), then:
- **Active Memory:** locally computes the *maximum* value across the returned
average-rollup samples in the window (`Measure-Object -Maximum`), the single
worst sampled bucket, not the window-wide average. - **CPU and Consumed
Memory:** use the plain time-weighted average across the same samples.

The peak figure drives every PASS/WARN badge and every sizing calculation; the
plain average is also computed and shown alongside it ("Active Memory (Avg)") as
a reference-only companion, never used to size or gate anything, so you can see
the spread between the two. Both figures come from the same host-level counter
over the same hosts, so the comparison is like with like. For a cluster, the peak
is the sum of each host's own peak; hosts can peak at different times, so it is a
conservative (high) figure for the cluster as a whole.

5. Burstiness / variability flag
--------------------------------

**Category:** MTAT design choice

A wide gap between an average and its peak is itself useful information: it
could mean a real, recurring spike worth sizing around, or a one-off anomaly in
that specific sampled window that shouldn't drive a hardware purchase on its
own. Neither "just use the average" nor "just use the peak" fully captures that
distinction, so MTAT surfaces the gap explicitly instead of hiding it.

**Where MTAT applies it:** the checklist warns when Active Memory's peak is at
least 2x its average **and** the absolute gap is at least 10 percentage points
(both conditions, so a near-idle cluster with e.g. 0.5% avg / 2% peak doesn't
trip this on noise alone), prompting a cross-check across other time ranges
before committing hardware spend to a single sampled peak.

6. Memory pressure context: Consumed Memory (reference only)
-------------------------------------------------------------

**Category:** Memory Tiering-specific guidance

Memory Tiering moves cold pages to NVMe as memory demand grows, so a cluster
with more of its memory committed has more for tiering to work with. There is
no fixed Consumed Memory percentage at which tiering starts; the point where it
engages depends on the workload and host configuration.

**Where MTAT applies it:** the Baseline Assessment checklist shows "Consumed
Memory (Avg)" as **For reference only**, with no target and no pass/fail badge.
Whether a cluster is a tiering candidate is decided at the cluster level by
Active Memory (peak at or below 50% of DRAM), since HA/DRS rebalances VMs across
the cluster's hosts.

7. NVMe tier hardware ceilings: 4 TB per host, maximum 1:4 DRAM:NVMe ratio
--------------------------------------------------------------------------

**Category:** Hard vSphere limit

vSphere Memory Tiering over NVMe has documented maximum supported configuration
boundaries: a per-host NVMe tier capacity ceiling tied to current
kernel/partition limits (4 TB / 4,096 GB), and a maximum supported DRAM:NVMe
ratio of 1:4. A configuration beyond either isn't just suboptimal; it's not a
supported deployment.

**Where MTAT applies it:** every sizing/expansion input mode across both the
Greenfield (Target Node Capacity, Target Usable Hosts) and Brownfield (ratio,
custom %, raw drive size) calculators clamps at both ceilings, with an on-screen
"[i] INFO" explanation whenever a requested configuration would exceed either
one, rather than silently modeling a config vSphere can't actually run. The
limits are applied to each host on its own, so a cluster that mixes host sizes
is sized the way it would actually be built.

8. HA / N+1 redundancy headroom
-------------------------------

**Category:** Widely recognized capacity-planning guidance

Sizing a cluster to exactly the number of hosts the current workload needs
leaves zero slack for a host failure or planned maintenance; the moment one host
is unavailable, every remaining host would need to exceed the CPU/Active-Memory
headroom targets above just to keep running the same workload. Standard vSphere
HA capacity planning always adds at least one spare host (N+1) beyond the
workload-driven count.

**Where MTAT applies it:** the "HA / Redundancy Nodes" selector (default: **+1
Node**, with +0 and +2 also available) adds that many hosts on top of the
workload-driven count in every sizing calculation, for both the Standard
(all-DRAM) and Tiered options, so the displayed host count and cost already
include redundancy, not just bare workload capacity. VMs that must stay in
DRAM (\#12) are placed on the hosts that remain once the HA spares are set
aside, so they still fit after a host failure.

9. NVMe tier redundancy (software mirroring)
--------------------------------------------

**Category:** Memory Tiering-specific guidance

Memory Tiering treats the NVMe tier as genuine usable memory capacity, not
merely a cache; losing that device can mean losing access to data actively
backing running VMs, which is a materially different risk than losing a
disposable read cache. Production Memory Tiering deployments should protect the
NVMe tier with redundancy (e.g., software mirroring), the same way DRAM already
has its own hardware-level ECC protection.

**Where MTAT applies it:** the "Enable NVMe Software Mirroring" option, when
checked, doubles the modeled NVMe hardware cost everywhere it's used (2x raw
capacity purchased for a mirrored pair) while leaving the DRAM cost term
untouched (DRAM doesn't need this since it already has its own redundancy), so
cost projections reflect a properly protected deployment rather than an
artificially cheap, unprotected one when this option is enabled.

10. Minimum vSphere version: 8.0 Update 3+
------------------------------------------

**Category:** Hard vSphere limit

VMware Memory Tiering over NVMe requires vSphere 8.0 Update 3 or later; it does
not exist as a feature on earlier releases, regardless of hardware.

**Where MTAT applies it:** the pre-flight PowerCLI version check and the
`Add-KnownIssueHints` error-translation logic both explicitly reference this
requirement, steering troubleshooting toward the real, well-documented cause (an
outdated PowerCLI misinterpreting a newer vCenter/ESXi API version, or a
genuinely pre-8.0U3 environment) instead of leaving a generic .NET exception to
decode.

11. Non-disruptive, read-only assessment
----------------------------------------

**Category:** Widely recognized capacity-planning guidance

A planning/assessment tool should never be able to change what it's assessing:
inventory, performance history, and configuration state should be read, never
written, so it can be run against production without any change-control review
or risk.

**Where MTAT applies it:** every PowerCLI call MTAT makes against a connected
vCenter is read-only (`Get-Cluster`, `Get-VMHost`, `Get-View`, `Get-VM`,
`Get-Stat`, and `Get-EsxCli` *status/list* queries only); it never calls a
`Set-*`, `New-*`, or `Remove-*` cmdlet against the target environment.

12. VMs whose memory must stay in DRAM
--------------------------------------

**Category:** Memory Tiering-specific guidance

Some VMs cannot use the NVMe tier at all. Per Broadcom's "Memory Tiering and VM
Memory Reservation" guidance, pinned memory "must reside in DRAM and is removed
from Memory Tiering entirely". That happens with a hardware passthrough device
(PCI / DirectPath I/O, Dynamic DirectPath, vGPU, SR-IOV, RDMA) or the
`sched.mem.prealloc.pinnedMainMem` / `sched.mem.prealloc.guestMem` settings, and
tiering is also off for VMs with Latency Sensitivity set to High, Fault
Tolerance VMs, and VMs with tiering disabled. A full memory reservation
("Reserve all guest memory (All locked)") on its own is not one of them: it
"does not pin memory to DRAM", and reserved pages can still be served from
either DRAM or NVMe.

**Where MTAT applies it:** the VM table's DRAM_Only column names the reason for
each such VM. Their configured memory is taken out of the DRAM available for
tiering in the Active Memory check (\#3), in the Greenfield host-count and DRAM
sizing, and in the customer report's qualifying-cluster test. Their Active
Memory is kept in the total rather than subtracted, because a VM's peak and its
host's peak can come at different times. For a refresh, each one also has to
fit whole in one new host's DRAM, on the hosts that remain once the HA spares
are set aside (\#8), so they still fit after a host failure.

13. Like-for-like refresh comparison
------------------------------------

**Category:** MTAT design choice

A refresh saving is only credible if both sides are configurations a customer
would actually buy. Comparing tiered and DRAM-only refreshes at whichever node
size gives the largest difference inflates the result: a bigger DRAM-only node
costs more, so the gap grows with node size while both options get more
expensive.

**Where MTAT applies it:** the customer report compares the cheapest DRAM-only
refresh with the cheapest tiered refresh. Each side uses whichever node size
costs least while meeting every rule above: Active Memory, CPU, Consumed
Memory, HA, the largest VM, and DRAM-only VM placement. Both configurations are
named in the report. A refresh is not recommended for a cluster whose CPU or
Consumed Memory data is incomplete. On the Sizing tab you choose the node size,
and both options use it.

 
-
