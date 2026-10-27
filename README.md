# Memory Tiering Assessment Tool (MTAT)

> **This repo was updated from v3.1 to v3.2.** The v3.1 release is preserved and downloadable under **Releases → v3.1.0** for reference; everything in this repository now reflects v3.2. See `CHANGELOG.md` for the full list of what changed.

**MTAT** is a workload planning and sizing utility designed to help system administrators, engineers, and architects evaluate and plan memory tiering deployments. This tool analyzes system requirements and helps optimize memory allocation across different performance tiers.

Capacities and prices use **decimal GB** (1 GB = 1,000,000,000 bytes;
1 TB = 1,000 GB). New CSV exports include `Memory_Unit=GB`; older unmarked
MTAT exports are converted automatically. Partially missing CPU data blocks
refresh sizing, and VM imports require valid configured memory.

## 🗂️ Repository Contents

This repository provides a PowerShell file and an executable (Windows). The PowerShell file can be used in a variety of operating systems such as macOS, Windows, Linux, etc. 

Version 3.2 adds an **Advanced Analytics** tab with fleet-wide, interactive memory analytics, and a **VCF Operations (vROps) .xlsx import** for offline assessments. See `CHANGELOG.md` for details, and `BUG_FIXES.md` for the bugs fixed in this version. `HOW_MTAT_WORKS.md` explains what MTAT reads from vCenter, every calculation it makes, and the reasoning behind its design.

---

## ✅ Requirements

### Software & Environment Requirements

*   **PowerShell:** The script is cross-platform and will run on Windows (Windows PowerShell) as well as macOS and Linux (PowerShell Core).
*   **VMware PowerCLI:** The `VMware.VimAutomation.Core` module must be installed. The engine will perform a pre-flight check upon launch and will intentionally shut down with a critical error if this module is missing. See *Installing PowerCLI* below.
*   **A Modern Web Browser:** The tool spins up an instant local web server and launches a dynamic HTML5 interface.
*   **Local TCP Port Availability:** The local engine requires an open port to bind to. It defaults to TCP port `8600` and will dynamically increment to the next available port (e.g., `8601`, `8602`) if the primary port is currently occupied.

### vSphere & Connectivity Requirements

*   **vCenter Network Access:** The machine running the script must have direct line-of-sight/network connectivity to the target vCenter server(s) over HTTPS (Port 443).
*   **Valid Credentials:** You need a valid username and password (e.g., `administrator@vsphere.local`) to authenticate and establish the PowerCLI session.
*   **Read Permissions:** The account must have sufficient permissions to read the vSphere inventory (Clusters, Hosts, VMs) and query historical performance statistics.
*   **Memory Tiering status:** Each host's tiering status and ratio are read from vCenter's memory tier information (vSphere 8.0 Update 3 and later), which needs no extra permissions and no esxcli. Only if that is not available (for example with an older PowerCLI) does MTAT ask the host through esxcli (read-only status queries). If neither answers, the host shows as **Unknown** rather than guessing.
*   **Certificates:** Self-signed vCenter certificates are accepted by default. Tick **Require valid vCenter certificates** on the Connection tab to refuse any vCenter whose certificate this computer does not trust.

### Data Collection Requirements (Optional for historical data)

*   **vCenter Statistical Level 2:** To perform historical baseline assessments (such as viewing the "Active Memory (Peak)" figure for the past 24 Hours, 7 Days, or 30 Days), vCenter's Historical Intervals must be enabled and set to Level 2 or higher. If statistics are disabled or set lower, the tool will gracefully fall back to default ranges, but the data resolution will be limited. "Active Memory (Peak)" is computed as the maximum across the standard `.average`-rollup samples in the selected window, not a separate `.maximum`-rollup query, so this works at Level 2 without requiring a higher (and rarer) Statistics Level.

---

## 🔧 Installing PowerCLI

The compiled `.exe` does **not** include PowerCLI, so it must be installed once on the machine that runs MTAT. Open PowerShell and run:

```powershell
Install-Module -Name VMware.PowerCLI -Scope CurrentUser -AllowClobber
```

**Use `-AllowClobber`.** Without it, the install stops with an error such as *"One or more commands are already available"* whenever an older or partial VMware module is already on the machine. That can leave PowerCLI half-installed, and MTAT will keep reporting that PowerCLI is missing. If you already hit this, run the command above again with `-AllowClobber`, then restart MTAT.

If PowerShell asks to trust the PowerShell Gallery or install the NuGet provider, answer **Y**. After installing, you can confirm with:

```powershell
Get-Module -ListAvailable -Name VMware.VimAutomation.Core
```

---

## 🚀 Installation & Setup

### For Windows (Using the Executable)
1. Download `MTAT_v3_2.exe` from the repository.
2. Double-click the executable to launch the sizing tool.

### ANY OS (Using PowerShell)
1. Clone the repository or download `MTAT_v3_2.ps1`.
2. Open PowerShell as an Administrator.
3. Ensure your execution policy allows scripts to run:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser


Execute the script 
    .\MTAT_v3_2.ps1
