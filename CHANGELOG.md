MTAT v3.1 Changelog
===================

Changes made going from `MTAT_v3_0.ps1` to `MTAT_v3_1.ps1`.

 

1. Data Import (new capability: Step 2, "Import Data Instead")
--------------------------------------------------------------

Lets you populate the Baseline Assessment / Sizing tabs without a live vCenter
connection.

-   **MTAT CSV re-import**: reload previously exported Hosts CSV + VMs CSV.

-   **RVTools import**: vHost CSV (+ optional vMemory/vInfo CSV) approximates a
    baseline; fuzzy/alias header matching tolerates RVTools version differences.
    Tiering status can't be known from RVTools, so it's marked `"Unknown"`
    rather than guessed.

-   **MTAT History import** (Matrix CSV / All-Tables Bundle): can restore *many*
    cluster+range combos in one shot.

    -   All-Tables Bundle → full fidelity (same as a live analysis).

    -   Matrix CSV → percentages only, honestly scoped: populates the comparison
        matrix for trend viewing, but Sizing & Savings correctly shows "No
        hardware profiles collected" for those ranges instead of fabricating
        capacity numbers.

-   Backward-compatible with this project's own earlier CSV header formats (`CPU
    Avg/Peak`, `CPU Peak Pct`, etc.), since the format changed multiple times
    during development.

-   Refactor: extracted `applyAnalysisResult()` as the single rendering path
    shared by live analyze, imports, and the comparison-matrix "click to drill
    in" flow (previously three separate copies of the same \~60 lines).

 

2. Worst-case sizing methodology (peak vs. average)
---------------------------------------------------

Went through three iterations based on what real vCenter environments actually
support:

-   **Final state**: CPU and Consumed Memory use plain time-weighted averages.
    Active Memory uses **peak**, but computed as the max across the
    `.average`-rollup samples in the window (not a `.maximum`-rollup query),
    since most vCenters only archive the average rollup at their configured
    Statistics Level, and `.maximum`/`.minimum` queries throw "metric counter
    doesn't exist" otherwise. This works regardless of Statistics Level.

-   Added **"Active Memory (Avg)"** as a reference-only companion figure (no
    pass/fail badge), computed from the same sample array, no extra vCenter
    query.

-   Added a **burstiness flag**: warns when peak is ≥2x average AND the gap is
    ≥10 percentage points, since a big gap signals a spiky workload worth
    investigating before sizing around it.

-   Relabeled everything consistently: checklist rows ("CPU Usage (Avg)",
    "Active Memory (Peak)", "Consumed Memory (Avg)"), comparison matrix/CSV
    columns, and the Sizing tab's disclaimer text.

-   Import paths updated to match: RVTools sets `activeAvg = active`
    (mathematically correct: one snapshot, not a time series); MTAT CSV
    re-imports show `N/A` (the export format never retained a separate average).

 

2a. Sizing-engine bug fixes from the same audit
-----------------------------------------------

Four more fixes from the full code audit, this batch focused on the Sizing &
Savings math since wrong numbers there directly drive a hardware purchase
decision:

-   **Fixed: capacity-mode NVMe overflow clamp was also shrinking Option A (100%
    DRAM).** When a large Target Node Size + high ratio pushed the NVMe tier
    past the 4096 GB kernel/partition limit, the code reduced the node's total
    capacity and used that *reduced* figure for Option A's sizing too -- even
    though Option A has no NVMe tier and isn't subject to that limit at all.
    Verified with a concrete example (6144 GB target, 1:4 ratio) where this had
    overstated Option A's cost by \~\$138,000 and correspondingly inflated
    Tiered's apparent savings. Option A now always sizes against the full
    requested capacity; only Option B's own numbers are affected by the cap.

-   **Fixed: the "capacity was shifted to DRAM" overflow message was false in
    capacity mode.** That explanation only describes what host-count mode
    actually does; capacity mode just reduces deliverable capacity (see above).
    Each mode now shows its own accurate explanation.

-   **Fixed: the "Tiered DRAM sizing is driven by the 50% Active Memory safety
    limit" note almost never displayed** in host-count mode, even when Active
    Memory genuinely was the binding constraint -- the check compared a
    post-64GB-rounding value against a pre-rounding one, which rarely match. Now
    compares the actual pre-rounding candidates directly.

-   **Fixed: Brownfield's "ratio" input mode had no 4096 GB/host cap**, unlike
    the "custom %" and "drive size" input modes, which already enforce it. A
    host with high average DRAM (e.g. 1536 GB) at a 1:3 ratio could silently
    produce an unsupported \>4096 GB/host configuration with no warning through
    this one dropdown, while the identical value entered via "custom" mode was
    correctly capped. Now clamped the same way as the other two modes.

All four verified with a dedicated unit-test harness (8 checks across 4
scenarios, including a regression check against the original hand-verified
example) before being considered done.

3. Diagnostics & resilience
---------------------------

Addressed feedback that an older version wasn't "pulling all the data":

-   `/api/analyze` now logs host/VM inventory counts, and warns when vCenter
    returns **zero performance samples** for a specific host/VM (previously
    silently defaulted to 0).

-   Fixed a **silently swallowed exception** in the esxcli tiering-status
    lookup, now logged.

-   **Made per-host and per-VM collection resilient**: previously, one host
    throwing an exception (e.g. a `Get-View` hiccup) killed the *entire*
    analysis, discarding every other host. Now a failed host gets a clearly
    marked `ERROR` row (styled red) instead of taking down the whole batch; a
    failed VM is skipped without affecting its siblings. Cluster-wide totals
    only commit after a host/VM fully succeeds, so a partial failure can't
    silently skew the numbers.

-   Added a **"Download Debug Log"** button (new `/api/get-debug-log` endpoint),
    needed because the compiled `.exe` runs with no visible console window.

-   Added a visible warning banner in the checklist when any host/VM failed
    during collection, naming exactly which ones.

### 3a. Follow-up hardening (found via real-world troubleshooting)

-   **Exception messages now show the real cause.** PowerCLI frequently wraps
    the actual error inside a generic `TargetInvocationException` ("Exception
    has been thrown by the target of an invocation."). `$_.ToString()` only
    showed that outer wrapper. Added `Get-FullExceptionText` to walk the full
    `InnerException` chain, used everywhere an error reaches the log or the
    browser.

-   **Added retry** (`Invoke-WithRetry`, 3 attempts / 2s apart) around
    `Get-Cluster`, `Get-VMHost`, and both `Get-Stat` calls. These ran *before*
    the per-host resilience above, so a transient failure there previously
    killed the entire analysis with zero data and no fallback.

-   **Logs the installed PowerCLI version** at startup, next to the existing
    pre-flight check.

-   **Added** `Add-KnownIssueHints`: recognizes specific
    cryptic-but-well-documented PowerCLI error signatures and appends an
    actionable hint (cause + fix command) instead of leaving a bare .NET
    exception chain to decode.

-   **Root-caused and fixed a real customer-reported hang**: a single VM with
    malformed/incomplete config data was crashing PowerCLI's bulk `Get-VM` for
    its *entire* cluster ("Sequence contains no elements", thrown from inside
    PowerCLI's own object-construction code, not vCenter). Confirmed
    intermittent across clusters in the same vCenter/session, which ruled out a
    PowerCLI/vCenter version mismatch and pointed at a specific VM instead.
    Fixed by listing VMs via the lower-level `Get-View` (bypasses the fragile
    code path) and resolving each VM individually via `Get-VM -Id`, so exactly
    one bad VM gets isolated, named in the log/UI, and excluded, instead of
    taking every other VM in the cluster down with it.

-   **Added environment pre-checks at startup**: logs the host PowerShell
    version/edition (purely informational), and now also warns (non-blocking
    since exact compatibility boundaries aren't something this tool can verify
    with confidence) when the installed PowerCLI is older than major version 12,
    since an outdated PowerCLI is a common source of cryptic errors against a
    recently-upgraded vCenter. Previously the version was only logged, never
    actually checked.

-   **Splash screen and main app header now show the current + latest available
    PowerCLI version**, so even a perfectly adequate installed version prompts
    an "update available" nudge. "Latest" is a live, best-effort check kicked
    off as a background job (`Start-Job`) at startup via `Find-Module
    -Repository PSGallery`, running concurrently with the rest of startup so it
    doesn't add delay. Environments with no internet egress (common on isolated
    vSphere management networks) simply show "unable to check" after a 15-second
    grace period; this is treated as a normal, expected outcome, never an error.
    New `/api/get-version-info` endpoint (with CORS support via a new
    `-AllowCrossOrigin` switch on `Send-JsonResponse`, since the splash page is
    `file://` origin) serves the info to both the splash screen and the main app
    header, so the result isn't lost if the redirect to the main UI wins the
    race against the background check finishing. PowerShell's own version was
    deliberately left out of this check/display (and an earlier
    auto-relaunch-into-`pwsh` attempt was reverted): nothing in this tool
    requires PS7+, so the host PowerShell version is purely informational and
    the extra complexity wasn't worth it. It's still logged (not displayed) at
    startup per the pre-flight check above.

 
-

4. Dark Mode & Standalone Documentation
---------------------------------------

-   **Dark Mode** (new capability): a persistent light/dark toggle in the main
    app header, next to "Download Debug Log" / "Exit Engine". Defaults to the
    OS/browser's `prefers-color-scheme`, then remembers an explicit choice via
    `localStorage` across reloads. Covers every screen, including the
    splash/loading screen shown while the engine boots. Every color in the app
    is now a semantic CSS custom property (status/badge colors, panels, tables,
    toasts, progress chips) rather than a hardcoded hex value, so light mode is
    unchanged pixel-for-pixel and dark mode is individually tuned per role for
    contrast rather than a blind color invert.

-   **Ratio guidance on the Sizing & Savings tab** (new capability): selecting
    any NVMe ratio other than 1:1 (Brownfield's ratio/custom%/drive-size modes,
    or Greenfield's ratio dropdown) now surfaces an explicit recommendation that
    1:1 is the default/recommended configuration, and that higher ratios require
    additional workload assessment since Active Memory needs to be
    proportionally lower to reliably fit within the DRAM tier. Shown alongside
    (not instead of) the existing 4096 GB/host cap and Greenfield
    sizing-rationale notices when more than one applies at once.

 
