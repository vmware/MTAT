# Memory Tiering Assessment Tool (MTAT) 3.3

Customer-facing overview: [MTAT 3.2 to 3.3 Changes](MTAT_3.2_to_3.3_Changes.md).

MTAT assesses memory use, investigates workload history, and models memory-tiering capacity and hardware costs. It runs locally as `MTAT_v3_3.ps1`, with a browser interface and read-only collectors for vCenter and VMware Aria / VCF Operations.

**Release candidate prepared October 30, 2026.** Local regression evidence and the remaining Windows/live-environment release gates are recorded in [RELEASE_READINESS.md](RELEASE_READINESS.md). A Windows executable is not included in the source package. Do not redistribute an executable built from an earlier script.

## What's new in 3.3

- Live Operations collection alongside direct vCenter connections and offline imports.
- Background collection jobs with progress, cancellation, persistent checkpoints, saved-result loading and guarded recovery.
- Fleet assessment across multiple clusters and sources, preserving inventory identity.
- Matrix / Timeline views, active-memory duration curves, and complete searchable/paginated host and cluster analytics breakdowns.
- Self-contained HTML reports with selectable collected ranges: assessment, analytics and sizing update together in the exported file.
- Improved native Ops workbook and multi-file RVTools imports, decimal GB conversions, retained timestamp handling and missing-data safeguards.

See [CHANGELOG.md](CHANGELOG.md) and [BUG_FIXES.md](BUG_FIXES.md) for details.

## Requirements and launch

- PowerShell 7 on macOS/Linux, or a suitable Windows PowerShell/PowerShell installation on Windows. Windows PowerShell 5.1 and compiled-executable validation remain separate release gates.
- VMware PowerCLI (`VMware.VimAutomation.Core`) is needed for **direct vCenter** connections. Operations and offline imports can start without it. Use a PowerCLI version supported by the target vCenter and PowerShell host.
- A modern JavaScript-enabled browser and a free loopback TCP port. MTAT starts at `127.0.0.1:8600`, trying subsequent ports when necessary.
- HTTPS access and appropriate read permissions to the selected vCenter or Ops endpoint for live collection.

Run from PowerShell:

```powershell
.\MTAT_v3_3.ps1
```

On macOS/Linux, `pwsh -NoProfile -File ./MTAT_v3_3.ps1` is equivalent. Administrator/root privileges are not required for the loopback listener. Follow your organization's execution-policy and signing requirements; changing execution policy is not a universal prerequisite on every OS.

For direct vCenter, install PowerCLI for the user and compatible PowerShell host if needed:

```powershell
Install-Module VMware.PowerCLI -Scope CurrentUser -AllowClobber
Get-Module -ListAvailable VMware.VimAutomation.Core
```

### Windows executable

Build on **Windows** using `Build-MTAT-Exe.ps1`, then sign using `Sign-MTAT.ps1` and an appropriate signing certificate. PS2EXE output is x64 and uses Windows PowerShell; verify PowerCLI availability in that host, including the isolated collection worker. PowerCLI is not bundled. Validate startup, offline import, both live collectors, cancellation/recovery and HTML export on Windows before distributing the EXE. The Mac regression run does not establish Windows EXE compatibility.

## Four tabs

1. **Connection:** select vCenter or Operations, connect to the required servers, or choose offline import.
2. **Baseline Assessment:** select clusters and ranges, start collection or import files, review metrics and CHECK DATA warnings. The cluster/range matrix and long host/VM lists can collapse. Underlined headers and sorting arrows identify sortable columns.
3. **Advanced Analytics:** select cluster/fleet scope and a collected range. Switch Matrix / Timeline, set active thresholds and persistence, inspect peak duration, and search/sort/page through all host and cluster breakdown rows.
4. **Sizing & Savings:** review qualification and model existing-host or refresh scenarios using the entered prices and capacity assumptions. Missing required configuration or data prevents a definitive qualification/quote.

Advanced Analytics focuses on **active memory**. Consumed/provisioned charts were removed; their source measurements still participate where appropriate in assessment and sizing. Breakdown tables omit the Data / configuration notes column; diagnostics and qualification checks still use those underlying flags.

## vCenter and Operations collection

### vCenter

MTAT uses PowerCLI inventory and retained performance counters. Real-Time Snapshot uses current available values. Historical choices require enabled vCenter intervals at Statistics Level 2 or higher; MTAT reads the finest retained enabled interval covering the window where available. It never raises the statistics level or changes the environment. Insufficient retention/coverage remains a data-quality limitation.

Self-signed vCenter certificates are accepted by default. Enable **Require valid vCenter certificates** to enforce trust.

### Operations

Select **vROps / Aria Operations / VCF Operations** on Tab 1. Supply the hostname, username and password. Authentication source is optional: blank uses local authentication; otherwise use the configured Ops source name. Read access to inventory, relationships, properties and metrics is required. Direct vCenter connectivity and PowerCLI are not required in this mode.

Ops certificate verification is enabled by default. Install the trusted certificate chain, or deliberately disable that option for an untrusted/self-signed appliance. Tokens remain in engine/worker memory and are not included in saved results.

- **Latest Ops Sample** is the latest retained Ops collection, not a vCenter real-time snapshot.
- **Past 24 Hours / Past 7 Days / Past 30 Days** request existing retained history. Live Ops does not offer 365 days.
- Counter discovery and request/response compatibility handle 8.x/9.x API forms, including the historical GET fallback. Exact supported appliance/SSO combinations require live validation; mocked API tests are not certification.
- Source notes show observed coverage, counter availability and chart resolution. Collection does not change Ops retention, policies or vCenter statistics levels.

Ops can expose valid performance data while failing to establish physical DRAM, current tier configuration, passthrough/pinning or other VM eligibility settings. Those gaps remain CHECK DATA; measurement availability alone does not certify tiering eligibility or savings.

## Jobs, logs and recovery

Live collection runs in an isolated PowerShell worker. Only one worker per version's local workspace may collect at a time, including an older worker still running after an engine restart. A job is not reported finished until its owned worker exits. Server/cluster/range tasks run sequentially; inventory and statistics are batched within each task.

Default budgets are a **two-hour worker runtime**, **2 GB worker private memory**, a **10-second cancellation grace period**, a **120-second individual SDK/API request timeout**, and **32 MB of serialized results in the browser cache**. These limits bound work; they are not minimum laptop specifications or a guarantee that every query completes within the request timeout. Local cancellation cannot reconstruct history that the source no longer retains.

Data is stored under the current user's LocalApplicationData `MTAT/3.3` directory. Windows normally uses `%LOCALAPPDATA%\MTAT\3.3`. Other OS paths follow PowerShell/.NET's LocalApplicationData location.

- `Logs`: unique persistent engine logs. **Download Debug Log** identifies the current path; a later launch does not overwrite a previous run.
- `Jobs/<job-id>`: metadata, completed result checkpoints, worker log and progress. Completed facts survive a later failed task or worker crash.
- Generated worker scripts contain code, not saved authentication input. Credentials/tokens are transferred in memory through an anonymous stdin pipe.

Open **Collection jobs and saved results** to monitor/cancel a job, reload its completed results, or reconnect to the original targets before resuming unfinished work. Inventory/configuration or collector-hash changes require a new assessment. Completed checkpoints are not silently recomputed. Oversized jobs stay on disk rather than silently evicting part of the selected scope from a fleet report. A checkpoint can be downloaded independently.

Offline mode hides collection jobs by default; **Open saved assessments** can restore local completed facts without reconnecting. Resume requires a live authorized connection. Local checkpoints retain real inventory names; Hide real names applies to displayed/exported facts, not to rewriting the saved checkpoint. Review diagnostic files before sharing them.

## Offline imports

- **MTAT CSV/history:** preserve exported unit and missing-data columns. Unmarked legacy MTAT GB fields are converted from their historical byte convention once; new exports declare `Memory_Unit=GB`.
- **RVTools:** select multiple vHost CSVs or complete XLSX workbooks and matching vMemory/vInfo CSVs. Preserve vCenter and datacenter identity; pair ambiguous same-host exports with matching filename prefixes. Multiple snapshots stay separate. RVTools does not establish retained history, actual tier state or complete VM eligibility; unverified configuration withholds qualification/savings while retaining measurements.
- **Ops XLSX:** accepts native Ops headers and legacy Input.xlsx layouts. Measured consumed memory is distinct from allocated-VM-memory proxies. Timestamped observations take precedence over matching untimestamped summaries; different collection windows remain separate. Host exports do not establish physical tier breakdown or VM eligibility, so those configuration gaps withhold qualification/savings.

See [Export from Ops.md](Export%20from%20Ops.md) for exact customer steps, units, timestamp requirements and Excel's row-limit considerations. Input.xlsx's supported summary layout has **no historical timestamps**. It can populate the matrix and tables but cannot establish a timeline or peak duration.

## Memory units and interpretation

All output capacities and prices use **decimal GB**: 1 GB = 1,000,000,000 bytes; 1 TB = 1,000 GB. VMware KB/MB/GB source conventions are converted before calculations. Existing platform limits retain their underlying byte sizes.

Host active peak is the maximum retained aggregate for that host. Cluster peak sums individual host peaks, which can occur at different times: it is a conservative total, not a simultaneous cluster measurement. Averages use available retained observations; missing periods and short spikes already averaged away are not reconstructed.

Live charts use bounded retained-sample intervals selected for the collection size. Timestamped workbook imports retain compact hourly chart aggregates; the highest active value in a bin can represent a shorter event. Duration/persistence percentages describe **observed chart intervals**, not continuous wall-clock time. Current inventory/capacity and VM placement can differ from their historical values.

**Verify Ops active-memory peaks** shows the source value converted to GB, reported peak GB, timestamp, current capacity and retained coverage. The original unit and GB-per-unit audit columns remain in the peak-evidence CSV rather than the visible table.

## Export one report with multiple ranges

1. Collect or import the required windows once, then load their completed results.
2. Choose **Export report**, the required sections and cluster scope. All available collected ranges start checked; choose a subset if desired.
3. Open the downloaded HTML and use **Collected time range** to switch assessment, analytics and sizing together. Missing cluster coverage is shown explicitly. Overlapping windows are separate analyses, never added together.
4. Change thresholds/persistence, switch Matrix / Timeline, hover charts, and search/sort/paginate the analytics breakdowns without an engine or Ops connection.

Both the complete selected job in browser memory and the combined embedded report payload have 32 MB budgets. If a report is too large, export fewer ranges or clusters. No silent result/sample truncation is used to fit those budgets. Summary-only inputs cannot gain history through an HTML selector; collect/import the actual observations first. Existing HTML files must be regenerated to gain new controls.

The static baseline report includes labeled host/VM excerpts and sizing tables include labeled top rows. Complete host/cluster analytics rows are in the interactive analytics section; use CSV/checkpoint exports for the underlying detailed facts. Printing/PDF uses the currently selected range, expanded sections and current table pages.

## Documentation and release contents

- [HOW_MTAT_WORKS.md](HOW_MTAT_WORKS.md): source semantics, calculations and operational design.
- [BEST_PRACTICES_IMPLEMENTED.md](BEST_PRACTICES_IMPLEMENTED.md): threshold rationale and planning assumptions.
- [Export from Ops.md](Export%20from%20Ops.md): customer workbook export/import guide.
- [CHANGELOG.md](CHANGELOG.md), [BUG_FIXES.md](BUG_FIXES.md), [RELEASE_READINESS.md](RELEASE_READINESS.md).
- `MTAT_Architecture.html`, `MTAT_Infographic.html`, `MTAT_Offline_Mode_Infographic.html` and corresponding Dark PNGs: current 3.3 reference visuals.
- [LICENSE.md](LICENSE.md).

The release ZIP uses an explicit allowlist. Customer reports, customer/reference workbooks, Jobs, Logs, Downloads, internal test fixtures and the inherited standalone analytics engine/report are excluded. The development folder itself is **not** the distributable package.
