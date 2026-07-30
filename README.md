# Memory Tiering Assessment Tool (MTAT)

**MTAT** is a workload planning and sizing utility designed to help system administrators, engineers, and architects evaluate and plan memory tiering deployments. This tool analyzes system requirements and helps optimize memory allocation across different performance tiers.

## 🗂️ Repository Contents

This repository provides a PowerShell file and an executable (Windows). The PowerShell file can be used in a variety of operating systems such as macOS, Windows, Linux, etc. 

---

## ✅ Requirements

### Software & Environment Requirements

*   **PowerShell:** The script is cross-platform and will run on Windows (Windows PowerShell) as well as macOS and Linux (PowerShell Core).
*   **VMware PowerCLI:** The `VMware.VimAutomation.Core` module must be installed. The engine will perform a pre-flight check upon launch and will intentionally shut down with a critical error if this module is missing.
*   **A Modern Web Browser:** The tool spins up an instant local web server and launches a dynamic HTML5 interface.
*   **Local TCP Port Availability:** The local engine requires an open port to bind to. It defaults to TCP port `8600` and will dynamically increment to the next available port (e.g., `8601`, `8602`) if the primary port is currently occupied.

### vSphere & Connectivity Requirements

*   **vCenter Network Access:** The machine running the script must have direct line-of-sight/network connectivity to the target vCenter server(s) over HTTPS (Port 443).
*   **Valid Credentials:** You need a valid username and password (e.g., `administrator@vsphere.local`) to authenticate and establish the PowerCLI session.
*   **Read Permissions:** The account must have sufficient permissions to read the vSphere inventory (Clusters, Hosts, VMs) and query historical performance statistics.

### Data Collection Requirements (Optional for historical data)

*   **vCenter Statistical Level 2:** To perform historical baseline assessments (such as viewing Peak Workload for the past 24 Hours, 7 Days, or 30 Days), vCenter's Historical Intervals must be enabled and set to Level 2 or higher. If statistics are disabled or set lower, the tool will gracefully fall back to default ranges, but the data resolution will be limited.

---

## 🚀 Installation & Setup

### For Windows (Using the Executable)
1. Download `MTAT_v3_0.exe` from the repository.
2. Double-click the executable to launch the sizing tool.

### ANY OS (Using PowerShell)
1. Clone the repository or download `MTAT_v3_0.ps1`.
2. Open PowerShell as an Administrator.
3. Ensure your execution policy allows scripts to run:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser


Execute the script 
    .\MTAT_v3_0.ps1
