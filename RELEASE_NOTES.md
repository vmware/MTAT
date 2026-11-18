# MTAT 3.3 release notes

Build **20261117.2**. The public package includes the PowerShell engine.

## Capabilities added since 3.2

A customer overview of the capabilities added since 3.2. Source build:
**20261117.2**.

Collect directly from VCF Operations
------------------------------------

Connect to VMware Aria Operations / VCF Operations as an alternative to vCenter
or offline imports. Use the inventory and performance history Operations already
retains without increasing vCenter statistics levels.

Select the latest Operations sample, past 24 hours, past 7 days or past 30 days.
Compare selected clusters or all connected clusters while keeping each source
and cluster distinct. Available measurements and history depend on the source
version, permissions, collection and retention.

Collect Operations history concurrently
---------------------------------------

Choose 1, 2 or 4 concurrent Operations clusters, with 2 as the default. Each
cluster collects its selected latest snapshot first, then the longest selected
history. Compatible history is reused for shorter ranges, and progress shows
active clusters. Direct vCenter collection stays sequential. Separate task and
job runtime budgets help larger assessments retain useful progress.

Run collections and imports as recoverable jobs
-----------------------------------------------

-   Follow collection and multi-file import progress, including file uploads and
    processing stages.

-   Cancel work while keeping completed checkpoints and results.

-   Reopen saved assessments after restarting the tool.

-   Resume compatible unfinished collection or imports instead of repeating
    completed work. Reconnect to the original authorized inventory before
    resuming live collection.

-   Keep Jobs and saved data available as an expandable panel when needed.

Saved checkpoints contain assessment data, not saved vCenter passwords or
Operations tokens.

Assess larger environments
--------------------------

Large assessments can use local disk storage and paged queries instead of
loading every host, VM and historical observation into the browser at once.
Search, sort and page through host, cluster and VM results, and expand long
lists only when needed.

Choose the import detail appropriate to the assessment, including retained
observations when historical analytics are required. Compatible Operations
history can be reused within a collection run. Repeated cluster-history
threshold counts reuse prepared history, with visible preparation progress and a
Stop counting control.

These capabilities do not remove source-export limits. MTAT cannot recover rows
missing from a truncated Excel export or observations already discarded by
source retention.

Explore active memory with Matrix and Timeline views
----------------------------------------------------

| Capability                            | What you can do                                                                                              |
|---------------------------------------|--------------------------------------------------------------------------------------------------------------|
| Matrix view                           | Compare hosts and clusters across active-memory bands and highlight the selected threshold.                  |
| Timeline view                         | Inspect retained timestamped history, including series below the threshold, with a visible threshold line.   |
| Adjustable thresholds and persistence | Choose an active-memory percentage and how much observed time must meet it.                                  |
| Interactive chart inspection          | Hover for details and pin supported tooltips while investigating individual series.                          |
| Host and cluster breakdowns           | Review both levels, initially sorted by average Active Memory, with sortable columns, search and pagination. |
| Tiering Candidate                     | See Yes, Review, No or CHECK DATA screening using the row's memory and CPU measurements.                     |

Summary-only files cannot establish timelines or time above threshold. A matrix
describes its memory bands; it does not prove historical persistence.

Use sustained active-memory peaks
---------------------------------

Peak Active Memory uses the level reached or exceeded in at least 5% of observed
hourly highs, helping distinguish recurring demand from short isolated spikes.
With fewer than 20 observed hours, the highest observed hourly value remains the
peak. The highest single sample is also retained separately when available.

Operations peak verification provides host values in decimal GB and retained UTC
timestamps so unusually high measurements can be investigated at the source.
Summed host peaks can occur at different times and are not a simultaneous
cluster peak.

Tiering Candidate is a screening aid: **Yes** requires peak/snapshot Active
Memory below 50% and average CPU at or below 50%. **No** requires average Active
Memory, peak Active Memory and average CPU all at least 75%. Other combinations
are **Review**; missing required measurements can produce **CHECK DATA**. Full
qualification and savings retain their separate configuration and placement
checks.

Share an interactive report with multiple collected ranges
----------------------------------------------------------

Export one self-contained HTML report containing the observation windows
included in the assessment. The recipient can switch collected ranges, adjust
supported analytics thresholds and persistence, choose Matrix or Timeline,
search/sort breakdowns and inspect chart details without a running MTAT engine.

Range selection uses data included at export; it does not collect more history.
HTML retains its interactive controls, while PDF is a static view. Reports
retain explicit size budgets and request a smaller selection when necessary.

Control refresh-sizing headroom
-------------------------------

-   Set **Max consumed memory after HA (%)**. The default is **85%**, adjustable
    from **10% to 90%**, with a caution above 85%.

-   Inspect consumed memory against total memory separately from peak active
    memory against DRAM, after the HA reserve.

-   Apply the same chosen consumed-memory ceiling to tiered and DRAM-only
    refresh alternatives and to exported sizing reports.

-   Choose standard target-node memory sizes: **256, 512, 768, 1,024, 1,536,
    2,048, 3,072, 4,096, 6,144 or 8,192 GB**, or enter **Custom**.

-   Use standard upward-rounded DRAM profiles in fixed-host sizing while
    retaining HA, CPU, active-memory and VM-placement safeguards.

The consumed-memory ceiling is an MTAT planning input, not a universal VMware
utilization requirement or a setting that changes ESX tier activation. Capacity
presets are planning sizes, not OEM DIMM compatibility guarantees. Internal
memory calculations use decimal GB; GB values display as whole numbers and
percentages retain decimals.

## Package validation and limits

The application script matches the installed edition byte for byte. Package startup, local HTTP identity and a synthetic two-host/two-cluster import passed on macOS with PowerShell 7. Documentation links were checked. These packaging checks do not establish full product regression coverage, live endpoint compatibility, native Windows/Linux behavior or representative customer-scale performance. No Windows executable was built or included.
