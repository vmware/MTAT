# MTAT: Changes from 3.1 to 3.2

Changes from **MTAT 3.1 to the current 3.2 build**, including subsequent fixes applied to 3.2. Prepared October 27, 2026.

| Area | Changes |
|---|---|
| **Offline assessments** | Assess imported data without logging into vCenter; switch back to live collection afterward. |
| **VCF Operations import** | Import multiple `.xlsx` files, including snapshot or timestamped host data and tenant/BOM/datacenter/fabric tags. |
| **Advanced Analytics** | New fleet and cluster views with KPIs, histograms, timelines, heat maps, tenant filters, and searchable tables. |
| **Customer reports** | Generate assessment, analytics, sizing, or combined reports; print or save as PDF. |
| **Name hiding** | Consistent aliases across screens, exports, reports, and downloaded logs, plus a separate private name key. |
| **Baseline qualification** | Consumed Memory becomes reference information; the fixed 80% qualification rule is removed. |
| **More accurate sizing** | Accounts for DRAM-only VMs, VM placement, HA capacity, heterogeneous hosts, and NVMe already installed on each host. |
| **Better savings comparisons** | Automatic refresh reports compare the cheapest feasible tiered configuration against the cheapest feasible DRAM-only configuration. |
| **Data-quality safeguards** | Missing metrics and collection failures produce **CHECK DATA** and withhold dependent recommendations. |
| **Faster, more reliable collection** | Indexed statistics, VM ID matching, sequential range collection, and vCenter tier metadata before ESXCLI. |
| **Longer timeouts** | Up to 60 minutes per range, one-minute browser heartbeat tolerance, and ten-minute engine inactivity shutdown. |
| **Improved exports** | MTAT Bundles preserve more assessment detail, source identity, missing-data flags, and failed VMs. |
| **Interface improvements** | Wider responsive layout, sortable comparison matrix, and smarter export controls. |
| **Certificate checking** | Optional enforcement of trusted vCenter certificates. |
| **Consistent units** | Decimal **GB** throughout, explicit CSV unit metadata, and automatic conversion of older exports. |
| **Import validation** | Partial CPU data blocks refresh sizing; missing or invalid configured VM memory rejects the import. |

For details, see [CHANGELOG.md](CHANGELOG.md) and [BUG_FIXES.md](BUG_FIXES.md).
