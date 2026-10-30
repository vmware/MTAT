# Export from Ops

Use VMware Aria Operations or VCF Operations host exports to assess memory use in MTAT. These instructions apply to the MTAT 3.2.1, 3.3 and 4.0 workbook importers; shipped 3.2 remains frozen. Earlier builds that reject `Memory|Guest Active` need the importer update before using native exports.

Export host measurements for the period being assessed. Timestamped samples provide peaks and historical charts; one average per host provides a summary only. MTAT reads existing Ops data without requiring a change to vCenter statistics levels. Available history and resolution depend on what Ops has already collected and retained.

## Choose the export

| Export | Use in MTAT |
| --- | --- |
| Historical host metrics with timestamps | Active-memory peaks and averages, consumed memory, CPU and Advanced Analytics timelines |
| Host summary such as `Input.xlsx` | Host capacity and optional allocated-memory, cluster and tenant context; no historical peak without samples |
| Both together | Historical samples take precedence for the measurements they contain; matching summary rows supply missing context |

Use files from the environment being assessed. A workbook supplied as an example is not inventory for a different customer. MTAT cannot infer that two different hostnames represent the same host.

## Export historical host metrics

1. Sign in to Ops with permission to read the target hosts and their historical metrics.
2. Open the host objects to assess. Use the object **Metrics** or **All Metrics** page, or an existing metric-data view containing those hosts. Navigation and export controls vary between Aria Operations 8.18 and VCF Operations 9.x.
3. Select the following host measurements. Use the metric keys to distinguish counters with similar display names. Availability depends on the Ops version and collection policy.

   | Measurement | Common display name | Metric key |
   | --- | --- | --- |
   | Active memory | Memory / Guest Active | `mem|active_average` |
   | Actual consumed memory | Memory / Consumed | `mem|consumed_average` |
   | Host provisioned capacity | Memory / Total Capacity | `mem|host_provisioned` |
   | Capacity available to VMs | Memory / Capacity Available to VMs | `mem|totalCapacity_average` |
   | CPU utilization | CPU / Utilization or Usage | `cpu|utilization_average`, `cpu|usage_average`, or `cpu|capacity_usagepct_average` |
   | CPU core utilization | CPU / Core Utilization | `cpu|coreUtilization_average` |

4. Select the desired window, for example the past 7 days or past 30 days. Keep the retained sample resolution where available. Do not replace the whole window with one Average or Maximum value when historical charts are required.
5. Use the metric-data export/download control and choose CSV or Excel data if offered. Export the actual observations, including hostname and timestamp. Do not export a chart image or the view/dashboard configuration.
6. Inspect the downloaded table. It must have one row per host and timestamp, with measurements in separate columns. The following native layout is accepted:

   | Name | timestamp | Memory\|Guest Active | Memory\|Consumed | Memory\|Capacity Available to VMs | Memory\|Total Capacity | CPU\|Utilization (%) | CPU\|Core Utilization (%) |
   | --- | --- | --- | --- | --- | --- | --- | --- |
   | esx01.example.com | 2026-10-01T12:00:00Z | 54.98 GB | 971.09 GB | 2.95 TB | 3 TB | 11.18 | 21.96 |
   | esx01.example.com | 2026-10-01T12:05:00Z | 60.25 GB | 975 GB | 2.95 TB | 3 TB | 12.50 | 23.10 |

7. Include a `Cluster` column when available. If the historical export does not include it, a supplemental workbook can supply the cluster by an exact hostname match. An ambiguous or unmatched hostname remains under **(no cluster)**; MTAT does not guess.
8. If the downloaded data is CSV, open it in Excel and **Save As an Excel Workbook (`.xlsx`)**. Changing the filename extension alone does not convert CSV to Excel. Keep a simple table, preferably with the header in row 1. The importer can find a header within the first 30 rows.
9. Save each window separately with a recognizable name, for example `Host metrics 7 days.xlsx` and `Host metrics 30 days.xlsx`.

A download with timestamps spread across columns, a separate table for each metric, or missing host capacity needs reshaping into the table above before import. A custom List View containing one value per host does not automatically provide timestamped history.

## Export a host summary or supplemental workbook

Use a custom List View when a summary is sufficient or when cluster context is needed alongside the historical export.

1. Open **Views** in Ops and create a **List View** named `MTAT Host Summary`.
2. Select **Host System** as the subject, then scope the view to the intended vCenter or clusters.
3. Include the host name and parent cluster name. Label those columns `HostName` and `Cluster`.
4. Add Guest Active and host Total Capacity from the metric table above. Optionally add actual Consumed, allocated VM memory, capacity available to VMs, CPU utilization and CPU core utilization.
5. Select the period to summarize. Use **Average** for an average summary and label the workbook accordingly. A single value per host cannot establish separate peak and average figures.
6. For unitless memory columns, use one explicit source unit consistently, preferably KB. Native per-cell unit strings are also accepted by the updated importer.
7. Run or preview the view at the required scope. Once populated, choose **Export to CSV** from the view toolbar. The **Share** or view-configuration export downloads a definition rather than the observations. Broadcom documents this distinction for Aria Operations 8.18 and VCF Operations 9.x. [Exporting historical data from views](https://knowledge.broadcom.com/external/article/455035/exporting-historical-data-from-views-vs.html)
8. Open the CSV in Excel, remove summary/total rows, and save it as `.xlsx`.

Ops views allow custom column labels, units and transformations. [VMware example of configuring and exporting a List View](https://blogs.vmware.com/cloud-foundation/2026/06/01/retrieve-vcenter-server-vms-and-nsx-vms-resource-allocations-in-vcf-operations/)

### Existing Input workbook

The existing `Advanced Analytics/Input.xlsx` layout remains supported. The importer prefers its sheet containing raw metric-key headers rather than importing the same data again from `Merged_Output`.

| Raw column | Purpose |
| --- | --- |
| `HostName` | Host identity |
| `Cluster` | Cluster context |
| `mem|active_average` | Active memory |
| `mem|host_provisioned` | Host provisioned capacity |
| `mem|totalCapacity_average` | Capacity available to VMs |
| `mem|memory_allocated_on_all_powered_on_vms` | Configured memory allocated to powered-on VMs; this is not actual consumed memory |
| `cpu|coreUtilization_average` | Core utilization; this is not interchangeable with CPU utilization |

An optional tenant sheet can contain `Cluster`, `Tenant`, `BOM`, `Datacenter` and `Fabric`. Its cluster names must match the host table. Merely placing tenant columns on an unrelated host sheet does not establish a cluster-to-tenant mapping.

## Import the files into MTAT

1. Start the updated MTAT 3.3 script. Restart an already-running engine after installing the update.
2. Open **Offline Import** or the import panel and choose the **VCF Operations / vROps workbook** source.
3. Select one or more `.xlsx` workbooks. You may select the host summary, tenant mapping and historical files together.
4. Set **Units for memory cells without a unit suffix**. Choose the known source unit for bare numbers; use automatic detection only when the source unit is unknown.
5. Enter an evaluation label and choose **Process Import**.
6. Review the import notes and range comparison matrix. Overlapping historical exports for the same hosts, such as 7-day and 30-day exports, are retained as separate evaluation ranges instead of being averaged together. Unmatched summary hosts appear in a supplemental snapshot when those ranges are separated.
7. Check host count, cluster mapping, RAM, consumed memory and CPU against Ops. Open **Advanced Analytics** for the historical charts and tenant breakdown.

Historical measurements take precedence over untimestamped summaries for the same host and counter. An allocated-memory summary never replaces actual consumed measurements. Supplemental inventory can fill a missing cluster only when exactly one cluster matches the hostname. Hosts missing from all supplied files cannot be detected by MTAT; reconcile the count against the intended Ops inventory scope.

## Memory units and interpretation

MTAT displays decimal **GB**, where 1 GB is 1,000,000,000 bytes. Native VMware memory labels KB, MB, GB and TB are interpreted using VMware's binary source convention, then converted to decimal GB. For example, a VMware-labelled `3 TB` becomes approximately `3298.535 GB`.

Raw KB exports preserve more precision than display-rounded GB/TB exports. Converting rounded text does not recover the precision discarded during export.

Embedded unit suffixes take precedence over the selector, so a workbook may contain both `GB` and `TB` cells. The selector applies to unitless numbers. If values have already been converted to decimal GB, keep them numeric without a suffix and choose **GB (1,000,000,000 bytes)**. The original merged Input layout has historically used misleading `(GB)` headings; its unitless legacy values continue to use source-unit detection or the explicit selector.

Consumed memory uses the actual consumed counter when supplied. For legacy summaries containing only allocated VM memory, MTAT clearly identifies that value as an allocation proxy. CPU utilization and CPU core utilization remain separate. When host CPU capacities are absent, cluster CPU is an equal-host average rather than a capacity-weighted average.

Host exports do not establish VM DRAM-only eligibility, effective page sizes, tiering state or a physical DRAM/NVMe split. On a tiered host, logical Total Capacity must not be assumed to equal physical DRAM. Confirm that denominator before using sizing results. Historical peaks are peaks of the retained exported samples; short peaks averaged away by Ops cannot be recovered.

## Resolve import problems

| Symptom | Action |
| --- | --- |
| No host table found | Confirm hostname, Guest Active and host Total Capacity columns exist. Put the header within the first 30 rows and update older MTAT builds. |
| RAM appears unexpectedly small or large | Check source units and the unitless-cell selector. Do not strip `TB` from a cell and leave its numeric value unchanged. |
| Hosts appear under no cluster | Include `Cluster`, or provide matching supplemental inventory. |
| No historical timeline | Confirm valid timestamps and repeated host observations are present. A one-row-per-host summary has no timeline. |
| Consumed is marked as an allocation proxy | Export Memory / Consumed; do not rename allocated memory to consumed. |
| CPU is unavailable | Include CPU utilization. Core utilization alone does not supply the CPU utilization measurement. |
| Not all hosts appear | Verify scope and permissions in Ops, then check skipped-row notes for invalid or missing capacity. |


## MTAT 3.3 release behavior

- Host workbooks do not establish complete VM eligibility, physical DRAM/tier breakdown or current tier state. Their measurements remain available, but these unverified configuration fields produce CHECK DATA and withhold qualification/savings. Use a verified configuration/inventory source before relying on a sizing result.
- Input.xlsx-style summary rows do not contain a historical timeline. Timestamped native metric exports are required to establish observed time positions. A date in a filename or a selected summary window is not a time series.
- Import the intended windows once. Export report can include several collected ranges, then the HTML Collected time range selector changes assessment, analytics and sizing together. Uncollected periods cannot be fetched by the exported file.
- Ops peak evidence displays source values converted to decimal GB. Original unit and conversion-factor fields remain in the peak-evidence CSV.
- For broad exports, check the observation count and Excel's worksheet row limit before accepting apparent coverage. Split the source export when necessary; a truncated workbook cannot be repaired by selecting a longer period in MTAT.
