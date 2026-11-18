# Memory Tiering Assessment Tool (MTAT) 3.3

MTAT helps administrators, engineers and architects assess whether their VMware workloads are candidates for Memory Tiering. It combines inventory, memory and CPU measurements in a local browser interface, shows workload behavior over time, and compares capacity and hardware-cost options.

Collect from **vCenter**, use retained history from **VMware Aria Operations / VCF Operations**, or import **offline CSV/XLSX exports**, including supported Operations and RVTools layouts. MTAT is read-only: it does not enable tiering, change hosts or VMs, or change statistics and collection policies.

## Capabilities

- Assess selected or multiple clusters across collected time ranges.
- Collect Operations clusters concurrently with a bounded 1/2/4 setting; default 2. Direct vCenter collection remains sequential.
- Follow collection/import jobs, cancel work, reopen saved results and resume compatible unfinished work.
- Explore Active Memory through Matrix and Timeline views, adjustable thresholds and searchable, sortable host/cluster breakdowns.
- Distinguish sustained Active Memory peaks from isolated highest samples.
- Export an interactive HTML report with several collected ranges, assessment, analytics and sizing content.
- Model HA, adjustable memory headroom, standard/custom node capacities, tier ratios and hardware prices.

See [Release notes](RELEASE_NOTES.md) for the public feature overview and packaged build information.

## Requirements and quick start

Use a modern browser and PowerShell 7, with a free local TCP port and sufficient disk space for saved assessments. MTAT binds to 127.0.0.1, starting at port 8600 and trying subsequent ports if necessary. Live collection needs HTTPS connectivity and an account with read access to the intended inventory and metrics.

**Direct vCenter collection additionally requires PowerCLI.** Operations and offline imports do not require PowerCLI. To install PowerCLI for your user:

```powershell
Install-Module -Name VMware.PowerCLI -Scope CurrentUser -AllowClobber
```

Download the package contents together. Open a terminal in the downloaded folder and run:

```sh
pwsh -NoProfile -File ./MTAT_v3_3.ps1
```

Or, from PowerShell:

```powershell
.\MTAT_v3_3.ps1
```

## Four-step workflow

| Tab | Purpose |
| --- | --- |
| Connection | Connect to vCenter or Operations, or choose offline mode. |
| Baseline Assessment | Select scope/ranges, collect or import, and review measurements and configuration evidence. |
| Advanced Analytics | Compare host/cluster patterns, sustained peaks, thresholds and candidate screening. |
| Sizing & Savings | Compare capacity and hardware-cost scenarios using explicit HA, headroom and pricing assumptions. |

For Operations history, select the latest collected sample, past 24 hours, 7 days or 30 days. Available vCenter history depends on retained statistics. A summary-only export cannot establish a timeline; historical analytics requires timestamped observations. Allocated VM memory is not actual consumed memory.

## Interpreting results

Peak Active Memory uses the sustained level reached or exceeded in at least 5% of observed hourly highs when history supports it. The highest single retained sample remains separate. Summed host peaks may occur at different times and are not a simultaneous cluster peak.

The Advanced Analytics **Tiering Candidate** column is an initial screen: **Yes** requires peak/snapshot Active Memory below 50% and average CPU at or below 50%. **No** requires average Active Memory, peak Active Memory and average CPU all at least 75%. Other combinations are **Review**; missing required measurements can produce **CHECK DATA**. Full qualification separately requires configuration and VM-constraint validation.

Memory is displayed in decimal **GB** with whole-GB values; calculations retain precision. Refresh sizing defaults to an **85% consumed-memory ceiling after HA**, adjustable from 10% to 90%. This is an MTAT planning input, not a universal VMware utilization requirement. Validate hardware, workload behavior, physical DRAM, existing tier state and VM placement before using sizing results.

## Reports and privacy

Choose Export report and select the scope, collected ranges and sections. The self-contained HTML report supports included range changes and supported analytics/table controls without a running engine. Browser Print / Save as PDF creates a static copy. Reports cannot fetch uncollected data, and explicit size budgets can require a smaller scope.

Saved assessments and logs remain local and may contain inventory names. Check reports before sharing and use Hide real names when appropriate. Endpoint passwords and Operations tokens are not stored in assessment checkpoints. Source-export truncation and discarded source history cannot be recovered by MTAT.

## Package contents and documentation

| Item | Purpose |
| --- | --- |
| [MTAT_v3_3.ps1](MTAT_v3_3.ps1) | Runnable PowerShell engine. |
| [User guide](USER_GUIDE.md) | Best practices, architecture, metrics, peaks, sizing, large assessments and recovery. |
| [Operations export guide](OPS_EXPORT_GUIDE.md) | Step-by-step CSV/XLSX preparation and tenant mapping. |
| [Release notes](RELEASE_NOTES.md) | Customer capabilities, build and validation scope. |
| [License](LICENSE.md) | MTAT license terms. |
| [Tenant mapping template](MTAT_Tenant_Mapping_Template.xlsx) | Optional cluster-to-tenant workbook. |

No executable is included. Windows builds require their own validation.
