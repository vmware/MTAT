# MTAT: Changes from 3.2 to 3.3

**More ways to collect data, investigate memory behavior and share an assessment.** MTAT 3.3 adds live Operations collection, recoverable background jobs and interactive reports while preserving the familiar four-step workflow.

| Capability | What's new | What it means for you |
|---|---|---|
| **Live VCF Operations collection** | Connect to VMware Aria Operations / VCF Operations as an alternative to a direct vCenter connection. | Assess using performance history already retained by Operations, without changing vCenter statistics levels. |
| **Current and historical views** | Select the latest Ops sample, past 24 hours, 7 days or 30 days. | Compare recent behavior with longer observation windows, subject to available retention. |
| **Background collection jobs** | Follow progress and cancel a collection while the interface remains available. | Manage longer assessments with clearer visibility into collection status. |
| **Saved results and recovery** | Completed results are saved locally. After an interruption, reopen results and resume unfinished work when the original source and configuration remain compatible. | Preserve completed collection work instead of always starting the entire assessment again. |
| **Multi-cluster assessment** | Collect across selected clusters or all connected clusters and retain source identities. | Review a fleet together while keeping each cluster's results distinguishable. |
| **Matrix and Timeline views** | Switch between memory bands and retained historical series. Timelines include below-threshold series and a labeled threshold line. | See the full picture, including workloads that never cross the selected threshold. |
| **Active-memory investigation** | Adjustable thresholds and persistence, peak-duration views, chart hover details, and per-host/per-cluster breakdowns sorted by average active memory. | Distinguish sustained demand from brief observed peaks and find the busiest workloads. |
| **Large-inventory navigation** | Searchable, sortable, paginated analytics tables and collapsible long lists. | Explore all included rows without filling the screen with thousands of hosts or clusters. |
| **Interactive HTML reports** | Change included collected time ranges, thresholds, persistence and analytics views in the exported HTML. Sort/search analytics breakdowns and inspect chart details without a running MTAT engine. | Share one report for reviewing multiple observation windows instead of generating a separate report for each range. |
| **More flexible offline imports** | Improved native Ops workbook handling and multi-file RVTools imports, with source identities and available timestamps preserved. | Bring supported customer exports into a combined assessment more reliably. |
| **Peak verification** | Ops peak evidence shows host values in decimal GB with the retained UTC sample timestamp. | Check unusually high peaks against the original Operations measurements. |
| **Clearer assessment confidence** | Source notes and CHECK DATA identify missing coverage, unverified physical memory, tier state or VM eligibility. | Keep measured values visible while withholding recommendations that the data cannot support. |

## Easier day-to-day assessment

The cluster/range comparison and long inventory lists can collapse, and sortable headers are easier to recognize. Advanced Analytics focuses on **active memory**, with concise host and cluster breakdowns. Consumed and provisioned values remain available where relevant to assessment and sizing.

Collection also includes the efficiency and diagnostic improvements in 3.2.1: bounded data batches, fewer repeated inventory requests and separate persistent logs for each run. Memory and capacity values continue to use decimal **GB**.

## Understanding the results

- **History comes from the source.** The latest Ops sample is not a vCenter real-time snapshot. Timeline and duration views require timestamped history; summary files cannot recreate it.
- **Duration describes retained observations.** Missing history and peaks averaged out by the source cannot be reconstructed. Summed host maxima need not occur at the same time.
- **Configuration still matters.** Ops and offline exports may not establish physical DRAM, existing tier configuration or all VM eligibility settings. CHECK DATA means verification is needed before quoting qualification or savings.
- **Reports contain collected data.** Range selection switches between windows included at export; it does not collect new history. Large exports have an explicit size limit and may require smaller selections. Interactive features are available in HTML; PDF is a static view.
- **Saved results stay local.** Checkpoints contain assessment inventory and measurements. Credentials are not saved with them; reconnect before resuming collection.

See [README.md](README.md) for setup and use, and [Export from Ops.md](Export%20from%20Ops.md) for workbook export guidance.
