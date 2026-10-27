MTAT v3.2 Changelog
===================

Changes made going from `MTAT_v3_1.ps1` to `MTAT_v3_2.ps1`.

 

1. Offline Mode (new capability: no vCenter login required)
-----------------------------------------------------------

Merges the standalone offline build into the main tool, so a single script now
covers both live and offline assessments.

-   **"Skip to Offline Import" button on the vCenter Connection tab**, next to
    "Establish PowerCLI Sessions". It unlocks the Baseline Assessment and Sizing
    & Savings tabs without establishing any PowerCLI session, and opens the
    Import panel directly, labeled "(Offline Mode)".

-   **Offline-specific Baseline layout**: the cluster scope selection and the
    "Analyze Selection Profile" button are hidden while in offline mode, since
    they only apply to live collection.

-   **Automatic offline cluster**: importing files without a selected cluster
    creates an `Offline_Cluster (Offline_Import)` entry and registers it in both
    the Baseline and Sizing & Savings cluster dropdowns, so imported data flows
    through the same rendering and sizing path as a live analysis.

-   **Seamless return to online mode**: connecting to a vCenter after using
    offline mode restores the normal scope selection and Analyze button, and
    hides the Import panel again.

 

2. Timeouts and multi-range analysis
------------------------------------

Adjusted how long the tool waits on the engine so large clusters and
multi-range selections can complete.

-   **Ranges are analyzed one at a time**: selecting several time ranges now
    sends them to the engine sequentially, with the progress chips showing which
    range is running. Total time is the sum of the individual ranges.

-   **Per-range limit raised to 60 minutes** (previously 5 minutes). A range that
    exceeds it is marked failed and reported at the end, and the Analyze button
    is re-enabled.

-   **Browser heartbeat tolerance raised to 1 minute** (previously about 15
    seconds) before the "Session Timed Out" screen appears. Does not apply while
    an analysis is running.

-   **Engine inactivity shutdown raised to 10 minutes** (previously 5 minutes)
    with no connected browser tab.

3. Consumed Memory as context, not a target
-------------------------------------------

-   **Consumed Memory (Avg) is now "For reference only"** on the Baseline
    Assessment checklist. The fixed 80% target, its PASS/NOTE badge and the
    "Memory Tiering will not trigger until there is memory pressure (80%)" note
    are removed, since there is no fixed Consumed percentage at which tiering
    starts. Active Memory remains the pass/fail test.

 

4. Advanced Analytics and VCF Operations import
-----------------------------------------------

Fleet-scale analytics and a VCF Operations import, built into the main tool.

### 4a. Advanced Analytics tab

-   **New tab "3. Advanced Analytics"** between Baseline Assessment and Sizing &
    Savings (now tab 4). It reads only what Step 2 analyzed or imported and makes
    no vCenter calls.

-   **Fleet or single-cluster scope**: an "All clusters" view combines every
    analyzed or imported cluster, alongside a picker for any single cluster and
    time range.

-   **Same layout and interactivity as the Host Memory Report** (`report.html`):

    -   Tenant filter chips (All / None) that re-scope every section below.

    -   KPI tiles: hosts, clusters, average host and cluster size, consumed,
        active and provisioned memory per host, CPU, and tiering candidate
        clusters.

    -   Active memory % histograms, time-averaged and peak, with hover detail.

    -   Clusters and hosts crossing an Active % threshold for a minimum share
        of time: overlaid lines, a hover tooltip listing every line's value,
        click-to-pin tooltips, and top-50 tables.

    -   Provisioned and consumed memory: hosts crossing both thresholds, with
        an overlay chart and qualifying-hosts table.

    -   Per-cluster breakdown table with search and click-to-sort columns.

-   **Cluster-level tiering candidate verdict**: each cluster shows Yes or No,
    using the same test as the Baseline checklist (cluster peak Active Memory at
    or below 50% of DRAM), since HA/DRS rebalances VMs across a cluster's hosts.

-   **Per-host time series from live analyses**: historical ranges (Past 24
    Hours, 7, 30 or 365 Days) now keep an hourly series per host (daily for 365
    Days) of Active, Consumed and CPU, built from the samples already collected,
    with no extra vCenter queries. Active keeps the highest sample in each bucket
    so peaks match the Baseline figure.

### 4b. VCF Operations (vROps) import

-   **New import source "VCF Operations / vROps Host Export (.xlsx)"**, available
    in offline mode. Accepts one or more .xlsx files at once and reads them
    directly in the browser, with no extra software.

-   **Loads every cluster in the export at once** (tested with 41,000+ hosts in
    2,000+ clusters). Each cluster appears in the Baseline comparison matrix, the
    Sizing & Savings dropdown and Advanced Analytics.

-   **Tenant, hardware (BOM), datacenter and fabric tags** are picked up
    automatically from a tenant sheet in the same workbook and drive the
    Advanced Analytics tenant filter.

-   **Automatic unit detection** (KB, MB or GB) from host memory sizes, with all
    values shown in GB.

-   **Snapshot and timestamped exports**: a one-row-per-host export is treated as
    a time-average; a timestamped export yields a true peak and average per host.

-   **Clear data-source notes** on the Baseline checklist explain what a VCF
    Operations export cannot provide: Consumed uses memory allocated to
    powered-on VMs, CPU shows as N/A, and Active from a single-value export is an
    average rather than a peak.

5. Wider, responsive layout
---------------------------

-   **The tool window grows up to 1400px wide** (previously 1100px) on every tab,
    and fills the browser on smaller screens without spilling past the edge.

-   **Header and tab bar wrap on narrow windows** instead of overflowing, and any
    content still wider than the window scrolls inside its tab rather than the
    whole page.

6. Hide real names
------------------

-   **"Hide real names" switch** next to the Process Import button, on the
    Advanced Analytics tab, and above the export buttons on the Baseline tab
    (all copies stay in sync). One on/off setting for the whole tool: when it is
    on, cluster, host, VM and vCenter names are replaced with consistent aliases
    such as `Cluster-001`, `Host-0001`, `VM-0001` and `vCenter-01`, on screen and
    in every export (Hosts, VMs, Matrix and the MTAT Bundle). All numbers are
    unchanged.

-   **Tenant, datacenter and fabric names are hidden too** (`Tenant-01`,
    `DC-01`, `Fabric-001`). These come from the tenant sheet of a VCF Operations
    workbook and drive the Advanced Analytics tenant filter. Hardware (BOM)
    values such as `amd/turin` are kept, since they describe hardware rather than
    the customer.

-   **Switch it on or off at any time**: turning it on aliases everything already
    loaded (live analyses and imports), and turning it off restores the real
    names. New analyses and imports that arrive while it is on are aliased as
    they come in, including VCF Operations source file names, which often carry
    the customer's name.

-   **Consistent aliases across the session**: the same real name always gets the
    same alias, VM rows stay matched to their host's alias, re-importing the same
    file never loads a second copy, and names that are already aliases (for
    example a file someone else already anonymized) are left as they are.

-   **Debug log hides names too**: with the switch on, "Download Debug Log"
    saves `MTAT_debug_log_hidden_names.txt`, with every known vCenter, cluster,
    host, VM and tenant name replaced by its alias and logon user names replaced
    with `[user]`. A note at the top reminds you to review it before sharing,
    since names MTAT never displayed (for example inside a raw error message)
    cannot be recognized.

-   **Downloadable name key** (`MTAT_name_key_PRIVATE.csv`) that maps every alias
    back to its real name, for the customer to keep. It is never included in an
    export, and like the rest of the session it is cleared when the engine exits.

 

7. Smarter export controls
--------------------------

-   **"Export All Tables Bundle" is now "Save as MTAT Bundle"**, since its main
    uses are converting an RVTools or VCF Operations import into MTAT's format and
    saving or sharing a session.

-   **Export controls are hidden when they would be redundant**: if everything in
    the session came from MTAT Export or MTAT History imports, exporting would
    return the same files, so a short note replaces the export buttons. They come
    back as soon as live, RVTools or VCF Operations data is added.

8. Sortable Range Comparison Matrix
-----------------------------------

-   **Click any column header to sort the Range Comparison Matrix.** Click
    again to reverse the order. Sorting by Target Cluster Scope keeps each
    cluster's ranges grouped together; sorting by a range or metric column sorts
    every row, so the clusters with the highest Active Memory, CPU or Consumed
    Memory rise to the top. N/A values always sort last.

9. Advanced Analytics timelines and heat maps
---------------------------------------------

-   **Hourly VCF Operations exports now draw the Advanced Analytics timelines.**
    When the export has a `timestamp` column (one row per host per hour, as used
    for the Host Memory Report), MTAT keeps a compact hourly series per host and
    an hourly average per cluster, so "Active memory % over time" (clusters and
    hosts) and "Provisioned & consumed" show real timelines with hover and pin.
    Timestamps in epoch milliseconds, epoch seconds or Excel date format are
    accepted. About 25 MB of memory covers a 40,000-host, two-week export.

-   **Heat map when there is no timeline**: a one-value-per-host export (such as
    a VCF Operations summary) now shows a heat map in those three sections
    instead of an empty chart: how many clusters or hosts sit in each Active %
    (or Consumed %) band, one row per tenant. Bands at or above the threshold
    are outlined; hover a cell for its count and members, click to pin the list.

10. Customer reports
--------------------

-   **Customer report**: a printable, self-contained report (open it in a
    browser and use Print, then Save as PDF) built from everything loaded. A
    **Customer report** card at the top of the Sizing & Savings tab generates the
    full report in one click: cover with the MTAT logo, customer name and date, summary,
    assessment, advanced analytics and sizing and savings.

-   **An export button on each of the three working tabs**, in the same place
    and style at the top right: Export Assessment Report (Baseline), Export
    Analytics Report (Advanced Analytics) and Export Sizing & Savings Report
    (Sizing & Savings). They appear once data is loaded.

-   **The assessment report mirrors the Baseline tab**: the qualification
    checklist with its bars and PASS badges, the Range Comparison Matrix, the
    Physical Host breakdown and the VM breakdown, rather than a CSV-style dump.

-   **The analytics report carries the tab's visuals**: the Active memory
    histograms, and the same three threshold views as the Advanced Analytics tab
    (clusters crossing a threshold, hosts crossing a threshold, and provisioned
    and consumed memory). With an hourly export they are drawn as overlaid
    timelines; with one value per host they are drawn as the heat map, one row
    per tenant, with the threshold outlined. The report also includes the busiest
    clusters, the tenant breakdown and the per-cluster table.

-   **Report options**: customer name, prepared by, which sections to include,
    and either all loaded clusters or any one cluster you pick from a list.
    Names follow the Hide real names switch, so a report made with it on contains
    only aliases.

-   **Savings at the recommended 1:1 ratio**: the Sizing section scores each
    cluster for adding NVMe to existing hosts and for a refresh onto new tiered
    hosts (best node size), both at 1:1, and reports the higher total as the
    headline with both scenarios shown. Only clusters at or below 50% peak Active
    Memory that do not already run Memory Tiering count toward savings, the 4,096
    GB NVMe per host limit is respected, and the report lists every price and
    rule used plus how the result moves with DRAM pricing. Ratios above 1:1 are
    not offered. The figures match the Sizing tab for the same inputs.

 

11. Connection and export options
---------------------------------

-   **Require valid vCenter certificates**: a new checkbox on the vCenter
    Connection tab. When it is on, MTAT refuses to connect to a vCenter whose
    certificate this computer does not trust (for example a self-signed one) and
    explains how to fix it. It is off by default, so vCenters with self-signed
    certificates connect as before.

-   **Exports keep more on re-import**: the Hosts and VMs CSVs, the MTAT Bundle
    and the Matrix CSV now also carry the tiering ratio, the average Active
    Memory, the NVMe tier size, each host's CPU capacity, which counters had no
    data, the DRAM_Only column (which replaces Pinned_Memory), the VMs that
    failed collection and the vCenter each cluster came from, so a re-imported
    file shows the same results as the session it came from. Files exported by earlier builds still import.

-   **Memory units for VCF Operations files**: a "Memory units in the file"
    option on the VCF Operations import (Detect automatically, GB, MB or KB),
    for files whose host sizes could be read in more than one unit. The import
    says when it had to choose.
