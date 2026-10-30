# ==========================================
# --- PORT DISCOVERY ENGINE (CROSS-PLATFORM)
# ==========================================

# Smart Console Check: Prevents ps2exe from turning Write-Host into 9 message boxes
$global:HasConsole = $false
try {
    [void][Console]::WindowWidth
    $global:HasConsole = $true
} catch { }

function Write-Terminal($Message, $Color="White") {
    if ($global:HasConsole -and ($Host.Name -notmatch "PS2EXE")) {
        Write-Host $Message -ForegroundColor $Color
    }
}

if ($global:HasConsole) { Clear-Host }
Write-Terminal "===========================================================" "Cyan"
Write-Terminal "   Memory Tiering Assessment Tool (MTAT) v3.3 Engine       " "White"
Write-Terminal "===========================================================" "Cyan"
Write-Terminal "[*] Initializing core components... Please wait." "Yellow"

$targetPort = 8600
$portFound = $false

while (-not $portFound) {
    if ($targetPort -gt 65500) {
        Write-Terminal "FATAL: No available port found in range 8600-65500. Exiting." "Red"
        exit
    }
    try {
        $listenerTest = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $targetPort)
        $listenerTest.Start()
        $listenerTest.Stop()
        $portFound = $true
    } catch {
        Write-Terminal "[!] Port $targetPort is occupied. Trying next port..." "Yellow"
        $targetPort++
    }
}

# ==========================================
# --- INSTANT LOADING SCREEN GENERATION ----
# ==========================================
$TempDir = [System.IO.Path]::GetTempPath()
$LoadingHtmlPath = Join-Path $TempDir "MTAT_Loading.html"
$MtatAppVersion = '3.3'
$MtatDataRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('MTAT/' + $MtatAppVersion)
try { [void][IO.Directory]::CreateDirectory((Join-Path $MtatDataRoot 'Logs')) } catch { $MtatDataRoot = Join-Path $TempDir ('MTAT/' + $MtatAppVersion); [void][IO.Directory]::CreateDirectory((Join-Path $MtatDataRoot 'Logs')) }
$LogFilePath = Join-Path (Join-Path $MtatDataRoot 'Logs') ('MTAT_' + [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.log')

$loadingHtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <script>
        // Same precedence + storage key as the main app (see applyStoredTheme there): an explicit
        // in-app choice from a previous session beats OS preference, so this transient splash
        // screen doesn't flash a theme different from the one the user is about to land on.
        (function() {
            try {
                var stored = localStorage.getItem('mtatTheme');
                if (stored === 'dark' || stored === 'light') { document.documentElement.setAttribute('data-theme', stored); }
            } catch (e) { }
        })();
    </script>
    <title>MTAT Initializing...</title>
    <style>
        :root {
            --surface-page: #f8f9fa; --surface-card: #ffffff;
            --text-primary: #212529; --text-secondary: #6c757d; --text-muted: #adb5bd;
            --border: #e9ecef; --accent: #0078D7; --accent-text: #0056b3;
            --shadow-card: 0 4px 12px rgba(0,0,0,0.1);
        }
        @media (prefers-color-scheme: dark) {
            html:not([data-theme="light"]) {
                --surface-page: #14161a; --surface-card: #1f2227;
                --text-primary: #e8eaed; --text-secondary: #adb3ba; --text-muted: #868c94;
                --border: #33383f; --accent: #4aa3f0; --accent-text: #6bb6f5;
                --shadow-card: 0 4px 12px rgba(0,0,0,0.4);
            }
        }
        html[data-theme="dark"] {
            --surface-page: #14161a; --surface-card: #1f2227;
            --text-primary: #e8eaed; --text-secondary: #adb3ba; --text-muted: #868c94;
            --border: #33383f; --accent: #4aa3f0; --accent-text: #6bb6f5;
            --shadow-card: 0 4px 12px rgba(0,0,0,0.4);
        }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: var(--surface-page); display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; color: var(--text-primary); }
        .box { text-align: center; background: var(--surface-card); padding: 50px; border-radius: 8px; box-shadow: var(--shadow-card); max-width: 500px; }
        .spinner { border: 4px solid var(--border); border-top: 4px solid var(--accent); border-radius: 50%; width: 45px; height: 45px; animation: spin 1s linear infinite; margin: 0 auto 25px; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        h2 { margin-top: 0; color: var(--accent-text); }
        p { color: var(--text-secondary); font-size: 15px; line-height: 1.5; }
    </style>
</head>
<body>
    <div class="box">
        <div class="spinner"></div>
        <h2>MTAT Engine is Starting...</h2>
        <p>Initializing PowerShell framework and VMware PowerCLI modules in the background.</p>
        <p style="font-size: 13px; font-style: italic;">This usually takes 5-10 seconds. You will be redirected automatically.</p>
        <p id="verinfo" style="font-size: 12px; color: var(--text-muted); margin-top: 20px; border-top: 1px solid var(--border); padding-top: 12px;">Checking PowerCLI version...</p>
    </div>
    <script>
        function paintVersionInfo(info) {
            var box = document.getElementById('verinfo');
            if (!box || !info) { return; }
            var stillChecking = (info.Status !== "done");
            var latestPcliText = info.LatestPowerCli ? info.LatestPowerCli : (stillChecking ? "checking..." : "unable to check");
            box.innerHTML = "PowerCLI: " + info.CurrentPowerCli + " (latest: " + latestPcliText + ")";
        }
        function pollVersionInfo() {
            fetch('http://127.0.0.1:$targetPort/api/get-version-info')
            .then(function(r) { return r.json(); })
            .then(paintVersionInfo)
            .catch(function(){});
        }
        pollVersionInfo();
        setInterval(pollVersionInfo, 2000);

        setInterval(function() {
            fetch('http://127.0.0.1:$targetPort/api/ping', { mode: 'no-cors' })
            .then(function() { window.location.href = 'http://127.0.0.1:$targetPort/'; })
            .catch(function(){});
        }, 1000);
    </script>
</body>
</html>
"@

$loadingHtmlContent | Out-File -FilePath $LoadingHtmlPath -Force -Encoding UTF8

try {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        if ($IsMacOS) { [void](Start-Process "open" -ArgumentList $LoadingHtmlPath -PassThru) }
        elseif ($IsLinux) { [void](Start-Process "xdg-open" -ArgumentList $LoadingHtmlPath -PassThru) }
        else { [void](Start-Process $LoadingHtmlPath -PassThru) }
    } else {
        [void](Start-Process $LoadingHtmlPath -PassThru)
    }
} catch { }

# ==========================================
# --- GLOBAL ENVIRONMENT HARDENING ---------
# ==========================================
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'

function Write-DebugLog ($Message) {
    $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $formatted = "[$timestamp] $Message"
    $formatted | Out-File -FilePath $LogFilePath -Append -Encoding UTF8
    Write-Terminal $formatted "Cyan"
}

# PowerCLI/.NET frequently wraps the real cause of a failure inside a generic
# TargetInvocationException whose own .Message is just "Exception has been thrown by the target of
# an invocation." -- $_.ToString() on an ErrorRecord only shows that outer wrapper, hiding the
# actual root cause. This walks the InnerException chain so the real error is visible in logs/alerts.
function Get-FullExceptionText ($ErrorRecord) {
    $parts = New-Object System.Collections.Generic.List[string]
    $ex = $ErrorRecord.Exception
    while ($null -ne $ex) {
        if ($ex.Message -and (-not $parts.Contains($ex.Message))) { $parts.Add($ex.Message) }
        $ex = $ex.InnerException
    }
    if ($parts.Count -eq 0) { return $ErrorRecord.ToString() }
    return ($parts -join " --> ")
}

# Some PowerCLI failures are cryptic but have a well-known root cause. Appends a short, actionable
# hint when the unwrapped exception text matches one of those known signatures, rather than leaving
# the user to decode ".NET-speak" on their own.
function Add-KnownIssueHints ($ExceptionText) {
    if ($ExceptionText -match '^Ops API ') { return $ExceptionText }
    if ($ExceptionText -match "Sequence contains no elements") {
        return "$ExceptionText [Likely cause: installed VMware PowerCLI is older than this vCenter/ESXi build and doesn't recognize its API version -- common right after a vSphere upgrade, and Memory Tiering itself requires vSphere 8.0 Update 3+. Check with: Get-Module -ListAvailable VMware.PowerCLI. Fix with: Update-Module VMware.PowerCLI -Force, then restart MTAT.]"
    }
    if ($ExceptionText -match "(?i)certificate|SSL connection could not be established|trust relationship") {
        return "$ExceptionText [Likely cause: the vCenter certificate is not trusted by this machine. If 'Require valid vCenter certificates' is ticked on the Connection tab, either install a trusted certificate on vCenter (or trust its CA on this machine), or clear that option.]"
    }
    return $ExceptionText
}

# Wraps a vCenter API call with a short retry: calls like Get-Cluster/Get-VMHost/Get-VM/Get-Stat
# occasionally fail with a transient TargetInvocationException (a brief SOAP/session hiccup) that
# succeeds on a second attempt. Unlike the per-host/per-VM loop bodies further down (which are
# resilient to a single bad entity), these upfront inventory calls have no fallback -- if they
# throw, the entire analysis fails with zero data, so it's worth retrying before giving up.
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [string]$Description = "operation",
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return & $Action
        } catch {
            $fullMsg = Get-FullExceptionText $_
            if ($attempt -ge $MaxAttempts) {
                Write-DebugLog "[retry] '$Description' failed after $attempt attempt(s), giving up: $fullMsg"
                throw
            }
            Write-DebugLog "[retry] '$Description' failed on attempt $attempt/$MaxAttempts, retrying in ${DelaySeconds}s: $fullMsg"
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

"[+] Starting Production Deployment Profile" | Out-File -FilePath $LogFilePath -Force -Encoding UTF8

# ---- Historical stats lookup ----
# Get-Stat returns one flat list of samples for every host or VM in the cluster. Filtering that whole
# list again for every host and every VM grows with the square of the VM count (about 48 s for 200
# VMs over 7 days, and over an hour for 2,000). New-StatIndex groups the samples once instead. Each
# sample is filed under the entity's vCenter ID (MoRef) and under its name; lookups use the ID, so two
# VMs that share a name (allowed in different folders) no longer receive each other's samples. The
# name is only used as a fallback, and only for a name that is unique in the cluster.
function New-StatIndex ($Samples) {
    # foreach without @(): in PowerShell 7.6, @() around a List[object] (such as $allVMs) throws
    # "Argument types do not match". foreach handles $null, one object and any collection.
    $index = @{}
    foreach ($s in $Samples) {
        if ($null -eq $s -or $null -eq $s.Entity) { continue }
        $metric = [string]$s.MetricId
        $value = [double]$s.Value
        if ($s.Entity.Id) {
            $k = "id:" + [string]$s.Entity.Id + "|" + $metric
            $bucket = $index[$k]
            if ($null -eq $bucket) { $bucket = New-Object System.Collections.Generic.List[double]; $index[$k] = $bucket }
            $bucket.Add($value)
        }
        $k = "name:" + [string]$s.Entity.Name + "|" + $metric
        $bucket = $index[$k]
        if ($null -eq $bucket) { $bucket = New-Object System.Collections.Generic.List[double]; $index[$k] = $bucket }
        $bucket.Add($value)
    }
    return $index
}
function Get-NameCounts ($Entities) {
    $counts = @{}
    foreach ($e in $Entities) { if ($null -eq $e) { continue }; $n = [string]$e.Name; $counts[$n] = 1 + [int]$counts[$n] }
    return $counts
}
# The samples for one host/VM and counter, or $null when vCenter returned none.
function Get-StatValues ($Index, $Entity, $MetricId, $NameCounts) {
    $bucket = $null
    if ($Entity.Id) { $bucket = $Index["id:" + [string]$Entity.Id + "|" + $MetricId] }
    if ($null -eq $bucket -and $NameCounts[[string]$Entity.Name] -eq 1) { $bucket = $Index["name:" + [string]$Entity.Name + "|" + $MetricId] }
    if ($null -eq $bucket -or $bucket.Count -eq 0) { return $null }
    return ,$bucket.ToArray()
}

# Why a VM's memory has to stay in DRAM (an empty list means it can be tiered). From Broadcom's
# "Memory Tiering and VM Memory Reservation" guidance: pinned memory "must reside in DRAM and is
# removed from Memory Tiering entirely", which happens with a passthrough device (PCI / DirectPath,
# Dynamic DirectPath, vGPU, SR-IOV, RDMA) or the sched.mem.prealloc.pinnedMainMem / guestMem
# settings; tiering is also off for VMs with Latency Sensitivity = High, Fault Tolerance VMs, and VMs
# with tiering disabled. A full reservation ("Reserve all guest memory (All locked)") is NOT a
# reason: "reserved pages can still be satisfied from either DRAM or NVMe".
function Get-VmDramOnlyReasons ($VmView) {
    $reasons = New-Object System.Collections.Generic.List[string]
    if ($null -eq $VmView -or $null -eq $VmView.Config) { return }
    $cfg = $VmView.Config
    foreach ($dev in $cfg.Hardware.Device) {
        if ($null -eq $dev) { continue }
        $label = $null
        switch ($dev.GetType().Name) {
            "VirtualPCIPassthrough" { $label = if ($null -ne $dev.Backing -and $dev.Backing.GetType().Name -eq "VirtualPCIPassthroughVmiopBackingInfo") { "vGPU" } else { "Passthrough" } }
            "VirtualSriovEthernetCard" { $label = "SR-IOV" }
            "VirtualVmxnet3Vrdma" { $label = "RDMA" }
        }
        if ($null -ne $label -and -not $reasons.Contains($label)) { $reasons.Add($label) }
    }
    $extra = @{}
    foreach ($opt in $cfg.ExtraConfig) { if ($null -ne $opt -and $null -ne $opt.Key) { $extra[[string]$opt.Key] = [string]$opt.Value } }
    if ($extra["sched.mem.prealloc.pinnedMainMem"] -match "^\s*(?i)true\s*$" -or $extra["sched.mem.prealloc.guestMem"] -match "^\s*(?i)true\s*$") { $reasons.Add("Pinned memory") }
    if ($null -ne $cfg.LatencySensitivity -and [string]$cfg.LatencySensitivity.Level -match "^(?i)high$") { $reasons.Add("Latency Sensitivity High") }
    if ($null -ne $VmView.Runtime -and [string]$VmView.Runtime.FaultToleranceState -match "^(?i)(enabled|running|starting|needSecondary)$") { $reasons.Add("Fault Tolerance") }
    if ($extra["sched.mem.enableTiering"] -match "(?i)false") { $reasons.Add("Tiering disabled") }
    return $reasons.ToArray()
}

# --- Read-only Operations connector (Aria Operations 8.x / VCF Operations 9.x) ---
# All credentials/tokens remain in the engine. No internal/unsupported APIs or collection changes.
function New-MtatOpsSession($Server, [bool]$RequireValidCerts = $true) {
    $address = ([string]$Server).Trim()
    if ($address -notmatch '^https://') { $address = 'https://' + $address }
    $uri = $null
    if (-not [uri]::TryCreate($address, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/' -or -not $uri.Host) {
        throw 'Enter one Ops hostname or HTTPS authority, without a path, credentials or query string.'
    }
    return @{ Base = $uri.GetLeftPart([UriPartial]::Authority) + '/suite-api/api'; Server = $uri.Authority
              Token = $null; AuthScheme = 'vRealizeOpsToken'; RequireValidCerts = $RequireValidCerts; Metadata = @{} }
}

function Invoke-MtatOpsApi($Session, [string]$Path, [string]$Method = 'GET', $Body = $null) {
    Test-MtatCollectionCancellation
    Set-MtatCollectionProgress ('Ops query: ' + $Path.Split('?')[0])
    # Constrain callers to the public read/query surface (plus session acquisition/release).
    $readPath = ($Method -eq 'GET' -and $Path -match '^/(versions/current$|resources(\?|$)|resources/(properties|statkeys|stats)\?|adapterkinds/VMWARE/resourcekinds/(HostSystem|VirtualMachine)/(statkeys|properties)(\?retrieveAttributeKeys=true)?$)')
    $queryPath = ($Method -eq 'POST' -and $Path -match '^/(auth/token/(acquire|release)$|resources/bulk/relationships(\?|$)|resources/stats/(query|latest/query)$)')
    if ((-not $readPath -and -not $queryPath) -or $Path.Contains('..')) { throw 'Unsupported Ops API request.' }
    if (-not $Session.RequireValidCerts -and -not ('MtatOpsCertificatePolicy' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class MtatOpsCertificatePolicy {
    public static readonly RemoteCertificateValidationCallback Accept =
        delegate(object sender, X509Certificate cert, X509Chain chain, SslPolicyErrors errors) { return true; };
}
'@
    }
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $request = [System.Net.HttpWebRequest]::Create($Session.Base + $Path)
        $request.Method = $Method; $request.Accept = 'application/json'; $request.ContentType = 'application/json'
        $request.Timeout = if ($Path -eq '/auth/token/release') { 5000 } else { 120000 }; $request.ReadWriteTimeout = $request.Timeout; $request.AllowAutoRedirect = $false
        if (-not $Session.RequireValidCerts) { $request.ServerCertificateValidationCallback = [MtatOpsCertificatePolicy]::Accept }
        if ($Session.Token) { $request.Headers['Authorization'] = $Session.AuthScheme + ' ' + $Session.Token }
        $response = $null
        try {
            if ($null -ne $Body) {
                $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 12 -Compress))
                $request.ContentLength = $bytes.Length
                $stream = $request.GetRequestStream()
                try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
            }
            $response = $request.GetResponse()
            $reader = New-Object IO.StreamReader($response.GetResponseStream())
            try { $json = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($json.Trim()) { return ($json | ConvertFrom-Json) }
            return $null
        } catch [System.Net.WebException] {
            $code = 0
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode; $_.Exception.Response.Dispose() }
            # OpsToken is the current documented scheme; older Suite API appliances use vRealizeOpsToken.
            if ($code -eq 401 -and $Session.Token -and $Session.AuthScheme -eq 'vRealizeOpsToken' -and $attempt -eq 0) {
                $Session.AuthScheme = 'OpsToken'; continue
            }
            if ($code -in @(429,502,503,504) -and $attempt -lt 2) { Start-Sleep -Seconds (2 * ($attempt + 1)); continue }
            $hint = switch ($code) {
                401 { 'Session expired or credentials rejected. Reconnect on Tab 1.' }
                403 { 'The Ops account cannot read the requested objects or metrics. Check its object scope and read permissions.' }
                404 { 'This endpoint or resource is unavailable on this Ops appliance.' }
                400 { 'Ops rejected the statistics request. Check the selected metrics and time range; this is not a certificate validation failure.' }
                default { 'Check connectivity and appliance health. For TLS failures, verify the Operations certificate on Tab 1.' }
            }
            # Do not return remote response bodies: they may contain credentials, tokens or internals.
            throw "Ops API $Method $($Path.Split('?')[0]) failed (HTTP $code). $hint"
        } finally { if ($null -ne $response) { $response.Dispose() } }
    }
}

function Get-MtatOpsPages($Session, [string]$Path, $Body = $null, [string]$Field = 'resourceList') {
    $items = New-Object 'System.Collections.Generic.List[object]'
    for ($page = 0; $page -lt 10000; $page++) {
        $sep = if ($Path.Contains('?')) { '&' } else { '?' }
        $method = if ($null -eq $Body) { 'GET' } else { 'POST' }
        $data = Invoke-MtatOpsApi $Session ($Path + $sep + "page=$page&pageSize=500") $method $Body
        $rows = @($data.$Field | Where-Object { $null -ne $_ })
        foreach ($row in $rows) { $items.Add($row) }
        if ($data.pageInfo -and $null -ne $data.pageInfo.totalCount) {
            if ($items.Count -ge [int]$data.pageInfo.totalCount) { return $items.ToArray() }
            if (-not $rows.Count) { throw 'Ops returned incomplete pagination. Reconnect and retry.' }
        } elseif ($rows.Count -lt 500) { return $items.ToArray() }
    }
    throw 'Ops inventory pagination exceeded the supported limit.'
}

function Get-MtatOpsMetadata($Session, [string]$Kind) {
    if (-not $Session.Metadata.ContainsKey($Kind)) {
        $map = @{}
        foreach ($endpoint in 'statkeys','properties') {
            $data = Invoke-MtatOpsApi $Session "/adapterkinds/VMWARE/resourcekinds/$Kind/${endpoint}?retrieveAttributeKeys=true"
            foreach ($entry in $data.resourceTypeAttributes) { if ($entry.key) { $map[[string]$entry.key] = $entry } }
        }
        $Session.Metadata[$Kind] = $map
    }
    return $Session.Metadata[$Kind]
}

function Get-MtatOpsProperties($Session, [object[]]$Resources) {
    $result = @{}
    for ($offset = 0; $offset -lt $Resources.Count; $offset += 25) {
        $batch = @($Resources | Select-Object -Skip $offset -First 25)
        $query = ($batch | ForEach-Object { 'resourceId=' + [uri]::EscapeDataString([string]$_.identifier) }) -join '&'
        $data = Invoke-MtatOpsApi $Session ('/resources/properties?' + $query)
        foreach ($row in $data.resourcePropertiesList) {
            $map = @{}
            foreach ($p in $row.property) { $map[[string]$p.name] = $p.value }
            $result[[string]$row.resourceId] = $map
        }
    }
    return $result
}

function Get-MtatOpsNumber($Value) {
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $number = 0.0
    if (-not [double]::TryParse([string]$Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or
        [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0) { return $null }
    return $number
}

function Get-MtatOpsFactor($Attribute, [string]$Key) {
    $unit = (([string]$Attribute.unit).Trim().ToLowerInvariant() -replace '[\s_-]', '')
    # Ops VMware memory KB/MB units follow vSphere binary counter units; output is decimal GB.
    switch -Regex ($unit) {
        '^(kb|kib|kilobytes?|kibibytes?)$' { return (1024.0 / 1e9) }
        '^(mb|mib|megabytes?|mebibytes?)$' { return (1048576.0 / 1e9) }
        '^gib$|^gibibytes?$' { return (1073741824.0 / 1e9) }
        '^gb$|^gigabytes?$' { return 1.0 }
        '^b$|^bytes?$' { return 1e-9 }
        '^tb$|^tib$' { return $null } # No unverified unit interpretation.
    }
    if (-not $unit -or $unit -in @('none','na','n/a')) {
        if ($Key -in @('mem|active_average','mem|consumed_average','mem|totalCapacity_average','mem|host_provisioned','mem|guest_provisioned','config|hardware|memoryKB')) { return (1024.0 / 1e9) }
    }
    return $null
}

function Get-MtatOpsAvailableMetrics($Session, $Metadata, [object[]]$Resources) {
    $map = @{}; foreach ($key in $Metadata.Keys) { $map[$key] = $Metadata[$key] }
    $available = @{}; $errors = New-Object 'System.Collections.Generic.List[string]'
    foreach ($resource in @($Resources | Select-Object -First 3)) {
        try {
            $data = Invoke-MtatOpsApi $Session ('/resources/statkeys?resourceId=' + [uri]::EscapeDataString([string]$resource.identifier))
            foreach ($entry in $data.'stat-key') {
                $key = [string]$entry.key
                if (-not $key -or $key.Contains(':')) { continue }
                $available[$key] = $true
                if (-not $map.ContainsKey($key)) { $map[$key] = @{ key=$key; unit=''; property=$false } }
            }
        } catch { $errors.Add($_.Exception.Message) }
    }
    $map['__Available'] = $available
    $map['__DiscoveryErrors'] = $errors.ToArray()
    return $map
}

function Resolve-MtatOpsMetric($Metadata, [string[]]$Keys, [string]$Type) {
    if ($Metadata.ContainsKey('__Available') -and $Metadata['__Available'].Count) {
        $Keys = @($Keys | Where-Object { $Metadata['__Available'].ContainsKey($_) }) + @($Keys | Where-Object { -not $Metadata['__Available'].ContainsKey($_) })
    }
    foreach ($key in $Keys) {
        if (-not $Metadata.ContainsKey($key) -or $Metadata[$key].property -eq $true) { continue }
        $factor = if ($Type -eq 'memory') { Get-MtatOpsFactor $Metadata[$key] $key } else { 1.0 }
        if ($Type -eq 'cpu' -and $Metadata[$key].unit -and [string]$Metadata[$key].unit -notmatch '^(?i)(%|percent|percentage)$') { continue }
        if ($Type -eq 'mhz' -and $Metadata[$key].unit -and [string]$Metadata[$key].unit -notmatch '^(?i)(mhz|megahertz)$') { continue }
        if ($null -ne $factor) { return @{ Key = $key; Factor = $factor } }
    }
    return $null
}

function Get-MtatOpsProperty($Properties, [string[]]$Keys) {
    foreach ($key in $Keys) { if ($Properties.ContainsKey($key) -and $null -ne $Properties[$key] -and [string]$Properties[$key] -ne '') { return $Properties[$key] } }
    return $null
}

function Get-MtatOpsMemoryProperty($Properties, $Metadata, [string[]]$Keys) {
    foreach ($key in $Keys) {
        if (-not $Properties.ContainsKey($key)) { continue }
        $factor = Get-MtatOpsFactor $Metadata[$key] $key
        $value = Get-MtatOpsNumber $Properties[$key]
        if ($null -ne $factor -and $null -ne $value) { return ($value * $factor) }
    }
    return $null
}

function Get-MtatOpsRelations($Session, [string[]]$Ids, [string]$Relationship = 'DESCENDANT') {
    return @(Get-MtatOpsPages $Session '/resources/bulk/relationships' @{ resourceIds = @($Ids); relationshipType = $Relationship; hierarchyDepth = 10 } 'resourcesRelations')
}

function Connect-MtatOps($Payload) {
    $session = New-MtatOpsSession $Payload.server ($Payload.requireValidCerts -ne $false)
    try {
        $auth = @{ username = [string]$Payload.user; password = [string]$Payload.pass }
        if ($Payload.authSource) { $auth.authSource = [string]$Payload.authSource }
        $token = Invoke-MtatOpsApi $session '/auth/token/acquire' 'POST' $auth
        if (-not $token.token) { throw 'Ops did not return an authentication token.' }
        $session.Token = [string]$token.token
        $version = Invoke-MtatOpsApi $session '/versions/current'
        $session.Version = [string]$version.releaseName
        if (-not $session.Version) { $session.Version = "$($version.major).$($version.minor).$($version.minorMinor)" }
        $clusters = @(Get-MtatOpsPages $session '/resources?adapterKind=VMWARE&resourceKind=ClusterComputeResource')
        if (-not $clusters.Count) { throw 'No VMware clusters are visible to this Ops account. Check adapter collection and object permissions.' }
        [void](Get-MtatOpsMetadata $session 'HostSystem')
        [void](Get-MtatOpsMetadata $session 'VirtualMachine')
        $sessionId = [guid]::NewGuid().ToString('N')
        $list = New-Object 'System.Collections.Generic.List[object]'
        $map = @{}
        foreach ($cluster in $clusters) {
            $key = 'Ops:' + $sessionId + '|' + [string]$cluster.identifier
            $vc = @($cluster.resourceKey.resourceIdentifiers | Where-Object { $_.identifierType.name -eq 'VMEntityVCID' } | Select-Object -First 1).value
            $label = [string]$cluster.resourceKey.name
            # Keep identity in Value; display only the customer-facing cluster name.
            $text = $label
            $map[$key] = @{ SessionId = $sessionId; ResourceId = [string]$cluster.identifier; Name = $label }
            $list.Add(@{ Value = $key; Text = $text; Label = $label; Server = $session.Server })
        }
        # Replace only after the new connection and discovery both succeed.
        Close-MtatOpsSessions
        $global:MtatOpsSessions = @{ $sessionId = $session }; $global:MtatOpsClusters = $map
        return @{ clusters = $list.ToArray(); version = $session.Version; source = 'ops' }
    } catch {
        if ($session.Token) { try { [void](Invoke-MtatOpsApi $session '/auth/token/release' 'POST') } catch {} }
        throw
    }
}

function Close-MtatOpsSessions {
    if ($global:MtatOpsSessions) {
        foreach ($session in @($global:MtatOpsSessions.Values)) {
            try { [void](Invoke-MtatOpsApi $session '/auth/token/release' 'POST') } catch {}
            $session.Token = $null
        }
    }
    $global:MtatOpsSessions = @{}; $global:MtatOpsClusters = @{}
}

function Get-MtatOpsTarget([string]$Key) {
    if (-not $global:MtatOpsClusters -or -not $global:MtatOpsClusters.ContainsKey($Key)) { throw 'Ops cluster session is no longer available. Reconnect on Tab 1.' }
    $target = $global:MtatOpsClusters[$Key]
    $session = $global:MtatOpsSessions[$target.SessionId]
    if (-not $session -or -not $session.Token) { throw 'Ops session is unavailable. Reconnect on Tab 1.' }
    return @{ Session = $session; Cluster = $target }
}

function Get-MtatOpsChartBucketMs([long]$Begin,[long]$End,[int]$Resources) {
    # Preserve the usual five-minute Ops positions where the inventory size permits.
    # Bound chart arrays to roughly one million value/timestamp cells instead of multiplying by estate size.
    $points=[math]::Max(2.0,[math]::Min(8640.0,[math]::Floor(1000000.0/([math]::Max(1,$Resources)*6.0))))
    return [long]([math]::Max(300000.0,[math]::Ceiling(($End-$Begin)/$points/300000.0)*300000.0))
}
function Read-MtatOpsStats($Session, [object[]]$Resources, $Metrics, [int64]$Begin, [int64]$End, [switch]$Latest, [switch]$Series) {
    $result = @{}; $keys = @($Metrics.Values | Where-Object { $null -ne $_ } | ForEach-Object { $_.Key } | Select-Object -Unique)
    if (-not $Resources.Count -or -not $keys.Count) { return $result }
    $bucketMs = Get-MtatOpsChartBucketMs $Begin $End $Resources.Count
    # Seven-day time slices and 25-resource batches keep response sizes bounded even for large estates.
    for ($offset = 0; $offset -lt $Resources.Count; $offset += 25) {
        $ids = @($Resources | Select-Object -Skip $offset -First 25 | ForEach-Object { [string]$_.identifier })
        for ($from = $Begin; $from -lt $End; $from = $to) {
            $to = [long][math]::Min($End, $from + 7 * 86400000.0)
            $query = @{ resourceId = $ids; statKey = $keys; currentOnly = $false }
            $path = '/resources/stats/query'
            if ($Latest) { $path = '/resources/stats/latest/query'; $query.maxSamples = 1 }
            else { $query.begin = [long]$from; $query.end = [long]($to - 1) }
            try { $data = Invoke-MtatOpsApi $Session $path 'POST' $query }
            catch {
                if ($Latest -or $_.Exception.Message -notmatch '\(HTTP 400\)') { throw }
                # Read-only GET compatibility path preserves the same resources, counters and time bounds.
                # Small resource batches keep its encoded URL bounded. Never fall back to latest data.
                $rows = New-Object 'System.Collections.Generic.List[object]'
                foreach ($id in $ids) {
                    $queryParts = @('resourceId=' + [uri]::EscapeDataString($id))
                    $queryParts += @($keys | ForEach-Object { 'statKey=' + [uri]::EscapeDataString($_) })
                    $queryParts += @(('begin=' + [string]$query.begin), ('end=' + [string]$query.end), 'currentOnly=false')
                    $fallback = Invoke-MtatOpsApi $Session ('/resources/stats?' + ($queryParts -join '&'))
                    foreach ($row in $fallback.values) { if ($null -ne $row) { $rows.Add($row) } }
                }
                $data = @{ values = $rows.ToArray() }
                if (Get-Command Write-DebugLog -ErrorAction SilentlyContinue) { Write-DebugLog '[ops] Historical POST rejected; used equivalent read-only GET statistics query.' }
            }
            if (Get-Command Write-DebugLog -ErrorAction SilentlyContinue) {
                $returned = @($data.values | Where-Object { $null -ne $_ })
                $fields = if ($returned.Count) { @($returned[0].PSObject.Properties.Name) -join ',' } else { '(none)' }
                Write-DebugLog "[ops] Stats query: requested $($ids.Count) resources; $($keys.Count) counters; returned $($returned.Count) resources; response fields=$fields."
            }
            foreach ($row in $data.values) {
                $id = [string]$row.resourceId
                if ($ids -notcontains $id) { continue }
                if (-not $result.ContainsKey($id)) { $result[$id] = @{} }
                $stats = $row.'stat-list'.stat
                if ($null -eq $stats) { $stats = $row.stats.stat }
                foreach ($stat in $stats) {
                    $key = [string]$stat.statKey.key
                    foreach ($kind in $Metrics.Keys) {
                        $metric = $Metrics[$kind]
                        if (-not $metric -or $key -cne $metric.Key) { continue }
                        if (-not $result[$id].ContainsKey($kind)) {
                            $result[$id][$kind] = @{ Count = 0; Sum = 0.0; Weight = 0.0; Max = 0.0; First = [long]::MaxValue; Last = 0L; LastValue = 0.0; MaxTimestamp = $null; MaxRaw = $null; MaxIntervalSeconds = $null; Buckets = @{}; Intervals = @{} }
                        }
                        $agg = $result[$id][$kind]
                        $step = 300000.0
                        if ($stat.intervalUnit.quantifier -gt 0) {
                            $mult = switch ([string]$stat.intervalUnit.intervalType) { 'SECONDS' { 1000 } 'MINUTES' { 60000 } 'HOURS' { 3600000 } 'DAYS' { 86400000 } default { 0 } }
                            if ($mult) { $step = [double]$stat.intervalUnit.quantifier * $mult }
                        }
                        $values = if ($null -ne $stat.data) { @($stat.data) } else { @($stat.values) }
                        $times = @($stat.timestamps)
                        if ($times.Count -ne $values.Count) { throw "Ops returned mismatched timestamps and values for $key." }
                        for ($i = 0; $i -lt $times.Count; $i++) {
                            $t = [long]$times[$i]
                            if ($t -gt $End + 60000) { continue }
                            if (-not $Latest -and ($t -lt $from -or $t -ge $to)) { continue }
                            $v = Get-MtatOpsNumber $values[$i]
                            if ($null -eq $v) { continue }
                            if ($agg.Last -ge $t -and $agg.Count -gt 0) { throw "Ops returned duplicate or unordered samples for $key. Retry with a smaller range." }
                            $rawValue = $v; $v *= $metric.Factor
                            $weight = [math]::Min($step, [math]::Max(0.0, [double]($End - $t)))
                            if ($i + 1 -lt $times.Count) { $weight = [math]::Min($weight, [math]::Max(0.0, [double]([long]$times[$i + 1] - $t))) }
                            if ($Latest) { $weight = 1 }
                            if ($agg.Count -eq 0 -or $v -gt $agg.Max) {
                                $agg.MaxTimestamp = $t; $agg.MaxRaw = $rawValue; $agg.MaxIntervalSeconds = $step / 1000.0
                            }
                            $agg.Count++; $agg.Sum += $v * $weight; $agg.Weight += $weight
                            $agg.Max = [math]::Max($agg.Max, $v); $agg.First = [math]::Min($agg.First, $t)
                            if ($t -ge $agg.Last) { $agg.Last = $t; $agg.LastValue = $v }
                            $agg.Intervals[[string]$step] = $true
                            if ($Series) {
                                $bi = [int][math]::Floor(($t - $Begin) / $bucketMs)
                                if (-not $agg.Buckets.ContainsKey($bi)) { $agg.Buckets[$bi] = @{ Sum = 0.0; Weight = 0.0; Max = 0.0 } }
                                $cell = $agg.Buckets[$bi]
                                if ($cell.Weight -eq 0 -or $v -gt $cell.Max) { $cell.MaxTimestamp = $t }
                                if (-not $cell.ContainsKey('FirstTimestamp')) { $cell.FirstTimestamp = $t }
                                $cell.Sum += $v * $weight; $cell.Weight += $weight; $cell.Max = [math]::Max($cell.Max, $v)
                            }
                        }
                    }
                }
            }
            if (Get-Command Write-DebugLog -ErrorAction SilentlyContinue) {
                foreach ($id in $ids) { if (-not $result.ContainsKey($id)) {continue};foreach($kind in $result[$id].Keys) {
                    $a=$result[$id][$kind]
                    if($a.Count -gt 0){$firstUtc=[DateTimeOffset]::FromUnixTimeMilliseconds($a.First).UtcDateTime.ToString('o');$lastUtc=[DateTimeOffset]::FromUnixTimeMilliseconds($a.Last).UtcDateTime.ToString('o');Write-DebugLog "[ops-timeline] mode=$(if($Latest){'latest'}else{'historical'}); metric=$kind; samples=$($a.Count); first=$firstUtc; last=$lastUtc; chartPositions=$($a.Buckets.Count); bucketMs=$bucketMs."}
                }}
            }
            if ($Latest) { break }
        }
    }
    return $result
}

function Get-MtatOpsAggregate($Stats, [string]$Id, [string]$Kind) {
    if ($Stats.ContainsKey($Id) -and $Stats[$Id].ContainsKey($Kind) -and $Stats[$Id][$Kind].Count -gt 0) { return $Stats[$Id][$Kind] }
    return $null
}

function Invoke-MtatOpsAnalysis([string]$ClusterKey, [string]$Range) {
    $target = Get-MtatOpsTarget $ClusterKey; $session = $target.Session; $cluster = $target.Cluster
    $latest = $Range -eq 'Latest Ops Sample'
    $days = switch ($Range) { 'Latest Ops Sample' { 1 } 'Past 24 Hours' { 1 } 'Past 7 Days' { 7 } 'Past 30 Days' { 30 } default { throw 'Unsupported Ops assessment range.' } }
    $end = if (-not $latest -and $global:MtatCollectionContext) { [DateTimeOffset]::new($global:MtatCollectionContext.End).ToUnixTimeMilliseconds() } else { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }; $begin = $end - [long]$days * 86400000L
    $relations = @(Get-MtatOpsRelations $session @($cluster.ResourceId))
    $objects = @{}; foreach ($r in $relations) { if ($r.resource.identifier) { if (-not @($r.resource.resourceStatusStates | Where-Object { [string]$_.resourceState -match 'NOT_EXIST|REMOV' -or [string]$_.resourceStatus -match 'NOT_EXIST|REMOV' }).Count) { $objects[[string]$r.resource.identifier] = $r.resource } } }
    $nodes = @($objects.Values | Where-Object { $_.resourceKey.resourceKindKey -eq 'HostSystem' })
    $allVms = @($objects.Values | Where-Object { $_.resourceKey.resourceKindKey -eq 'VirtualMachine' })
    if (-not $nodes.Count) { throw 'Ops returned no hosts for this cluster. Check object visibility and collection.' }
    $properties = Get-MtatOpsProperties $session @($nodes + $allVms)
    $hostMeta = Get-MtatOpsAvailableMetrics $session (Get-MtatOpsMetadata $session 'HostSystem') $nodes
    $vmMeta = Get-MtatOpsAvailableMetrics $session (Get-MtatOpsMetadata $session 'VirtualMachine') $allVms
    $dramKeys = @($hostMeta.Keys | Where-Object { ($_ + ' ' + $hostMeta[$_].description) -match '(?i)(dram|tier.?0)' -and
        ($_ + ' ' + $hostMeta[$_].description) -match '(?i)(capacity|size)' -and ($_ + ' ' + $hostMeta[$_].description) -notmatch '(?i)(consumed|usage|active|free|reserved)' } | Sort-Object)
    $nvmeKeys = @($hostMeta.Keys | Where-Object { ($_ + ' ' + $hostMeta[$_].description) -match '(?i)(nvme|tier.?1)' -and
        ($_ + ' ' + $hostMeta[$_].description) -match '(?i)(capacity|size)' -and ($_ + ' ' + $hostMeta[$_].description) -notmatch '(?i)(consumed|usage|active|free|reserved|disk)' } | Sort-Object)
    $hm = @{
        active = Resolve-MtatOpsMetric $hostMeta @('mem|active_average') 'memory'
        consumed = Resolve-MtatOpsMetric $hostMeta @('mem|consumed_average') 'memory'
        cpu = Resolve-MtatOpsMetric $hostMeta @('cpu|usage_average','cpu|capacity_usagepct_average','cpu|utilization_average') 'cpu'
        cpuCore = Resolve-MtatOpsMetric $hostMeta @('cpu|coreUtilization_average') 'cpu'
        capacity = Resolve-MtatOpsMetric $hostMeta @('mem|totalCapacity_average','mem|host_provisioned') 'memory'
        dram = Resolve-MtatOpsMetric $hostMeta $dramKeys 'memory'
        nvme = Resolve-MtatOpsMetric $hostMeta $nvmeKeys 'memory'
        cpuCapacity = Resolve-MtatOpsMetric $hostMeta @('cpu|capacity_provisioned','cpu|totalCapacity_average') 'mhz'
    }
    $vmMetrics = @{ active = Resolve-MtatOpsMetric $vmMeta @('mem|active_average') 'memory'; configured = Resolve-MtatOpsMetric $vmMeta @('mem|guest_provisioned') 'memory' }
    # Historical statistics and current configuration must never be conflated.
    $performanceMetrics = @{ active=$hm.active; consumed=$hm.consumed; cpu=$hm.cpu; cpuCore=$hm.cpuCore }
    $stats = Read-MtatOpsStats $session $nodes $performanceMetrics $begin $end -Latest:$latest -Series:(-not $latest)
    $current = Read-MtatOpsStats $session $nodes $hm ($end - 86400000L) $end -Latest
    $failedVms = New-Object 'System.Collections.Generic.List[string]'; $vms = New-Object 'System.Collections.Generic.List[object]'
    $powered = New-Object 'System.Collections.Generic.List[object]'
    foreach ($vm in $allVms) {
        $p = $properties[[string]$vm.identifier]; if (-not $p) { $p = @{} }
        $power = Get-MtatOpsProperty $p @('summary|runtime|powerState','runtime|powerState')
        if ([string]$power -match '^(?i)(poweredOn|powered on|on)$') { $powered.Add($vm) }
        elseif ([string]$power -notmatch '^(?i)(poweredOff|powered off|off|suspended)$') { $failedVms.Add([string]$vm.resourceKey.name + ' (power state unavailable)') }
    }
    $vs = Read-MtatOpsStats $session $powered.ToArray() @{ active=$vmMetrics.active } $begin $end -Latest:$latest
    $vc = Read-MtatOpsStats $session $powered.ToArray() @{ configured=$vmMetrics.configured } ($end - 86400000L) $end -Latest
    $nodeNames = @{}; $usedNames = @{}
    foreach ($h in $nodes) {
        $n = [string]$h.resourceKey.name
        if ($usedNames.ContainsKey($n)) { $n += ' [' + $h.identifier + ']' }
        $usedNames[$n] = $true; $nodeNames[[string]$h.identifier] = $n
    }
    # Current VM placement: query by host UUID. Names are never used as relationship identifiers.
    $placements = @{}
    for ($i = 0; $i -lt $nodes.Count; $i += 25) {
        $ids = @($nodes | Select-Object -Skip $i -First 25 | ForEach-Object { [string]$_.identifier })
        foreach ($r in @(Get-MtatOpsRelations $session $ids)) {
            if ($r.resource.resourceKey.resourceKindKey -ne 'VirtualMachine') { continue }
            $parents = @($r.relatedResources | Where-Object { $nodeNames.ContainsKey([string]$_) } | Select-Object -Unique)
            if ($parents.Count -eq 1) { $placements[[string]$r.resource.identifier] = $nodeNames[[string]$parents[0]] }
        }
    }
    foreach ($vm in $powered) {
        $id = [string]$vm.identifier; $p = $properties[$id]; if (-not $p) { $p = @{} }
        $cfg = Get-MtatOpsMemoryProperty $p $vmMeta @('config|hardware|memoryKB')
        if ($null -eq $cfg) { $a = Get-MtatOpsAggregate $vc $id 'configured'; if ($a) { $cfg = $a.LastValue } }
        if (-not $placements.ContainsKey($id) -or -not ($cfg -gt 0)) { $failedVms.Add([string]$vm.resourceKey.name + ' (placement or configured memory unavailable)'); continue }
        $a = Get-MtatOpsAggregate $vs $id 'active'; $missing = New-Object 'System.Collections.Generic.List[string]'
        if (-not $a) { $missing.Add('Active') }
        # No negative eligibility assertion without the complete vSphere configuration used by Get-VmDramOnlyReasons.
        $dramOnly = 'Unknown (Ops configuration incomplete)'
        $latency = Get-MtatOpsProperty $p @('config|latencySensitivity|level','config|latencySensitivity')
        if ([string]$latency -match '^(?i)high$') { $dramOnly = 'Yes (Latency Sensitivity High)' }
        $vms.Add(@{ Host = $placements[$id]; VMName = [string]$vm.resourceKey.name; ResourceId = $id; Provisioned_GB = [math]::Round($cfg,3)
                    Active_GB = if ($a) { [math]::Round($a.Max,3) } else { 0 }; Active_Pct = if ($a) { [math]::Round($a.Max / $cfg * 100,1) } else { 0 }
                    DRAM_Only = $dramOnly; Pages_1GB = 'Unknown'; Pages_2MB = 'Unknown'; Missing_Metrics = $missing -join ', ' })
    }
    $hosts = New-Object 'System.Collections.Generic.List[object]'; $seriesHosts = @{}; $notes = New-Object 'System.Collections.Generic.List[string]'
    $bucketMs = Get-MtatOpsChartBucketMs $begin $end $nodes.Count; $buckets = [int][math]::Ceiling(($end - $begin) / $bucketMs)
    $totalDram = 0.0; $totalActive = 0.0; $totalAvg = 0.0; $totalConsumed = 0.0; $cpuWeight = 0.0; $cpuUse = 0.0
    $first = $end; $last = 0L; $intervals = @{}
    foreach ($h in $nodes) {
        $id = [string]$h.identifier; $p = $properties[$id]; if (-not $p) { $p = @{} }
        $miss = New-Object 'System.Collections.Generic.List[string]'
        $active = Get-MtatOpsAggregate $stats $id 'active'; $consumed = Get-MtatOpsAggregate $stats $id 'consumed'; $cpu = Get-MtatOpsAggregate $stats $id 'cpu'
        foreach ($kind in 'active','consumed','cpu') {
            $a = Get-MtatOpsAggregate $stats $id $kind
            if (-not $a) { $miss.Add(@{active='Active'; consumed='Consumed'; cpu='CPU'}[$kind]); continue }
            $first = [math]::Min($first,$a.First); $last = [math]::Max($last,$a.Last)
            foreach ($int in $a.Intervals.Keys) { $intervals[$int] = $true }
            if (($latest -and ($end - $a.Last) -gt 1800000) -or (-not $latest -and $a.Weight / ($end - $begin) -lt 0.8)) {
                if (-not $miss.Contains('Coverage')) { $miss.Add('Coverage') }
            }
        }
        $tier = 'Unknown'; $tierKeys = @($hostMeta.Keys | Where-Object { $_ -match '(?i)(mem.*tier|tier.*mem)' -and $_ -match '(?i)(enabled|state|status)$' } | Sort-Object)
        $tierValue = Get-MtatOpsProperty $p $tierKeys
        if ([string]$tierValue -match '^(?i)(false|disabled|0)$') { $tier = 'Disabled' }
        elseif ([string]$tierValue -match '^(?i)(true|enabled|1)$') { $tier = 'Enabled' }
        $version = [string](Get-MtatOpsProperty $p @('config|product|version','summary|config|product|version'))
        if ($version -match '^(\d+)\.(\d+)\.(\d+)' -and [version]$Matches[0] -lt [version]'8.0.3') { $tier = 'Disabled' }
        # Prefer explicitly identified DRAM/Tier-0 capacity; total capacity can include NVMe.
        $dram = Get-MtatOpsMemoryProperty $p $hostMeta $dramKeys
        if ($null -eq $dram) { $a = Get-MtatOpsAggregate $current $id 'dram'; if ($a) { $dram = $a.LastValue } }
        $nvme = Get-MtatOpsMemoryProperty $p $hostMeta $nvmeKeys
        if ($null -eq $nvme) { $a = Get-MtatOpsAggregate $current $id 'nvme'; if ($a) { $nvme = $a.LastValue } }
        if ($null -eq $dram) {
            $dram = Get-MtatOpsMemoryProperty $p $hostMeta @('hardware|memorySize')
            if ($tier -ne 'Disabled') { $miss.Add('Capacity') }
        }
        if ($null -eq $dram -and $tier -eq 'Disabled') { $a = Get-MtatOpsAggregate $current $id 'capacity'; if ($a) { $dram = $a.LastValue } }
        if (-not ($dram -gt 0)) { $dram = 0; if (-not $miss.Contains('Capacity')) { $miss.Add('Capacity') } }
        if ($tier -eq 'Unknown' -or ($tier -eq 'Enabled' -and -not ($nvme -gt 0))) { $miss.Add('TierConfig') }
        $mhzAgg = Get-MtatOpsAggregate $current $id 'cpuCapacity'; $mhz = if ($mhzAgg) { $mhzAgg.LastValue } else { 0 }
        if (-not ($mhz -gt 0)) {
            $cores = Get-MtatOpsNumber (Get-MtatOpsProperty $p @('hardware|cpuInfo|numCpuCores','hardware|cpuInfo|num_CpuCores'))
            $hz = Get-MtatOpsNumber (Get-MtatOpsProperty $p @('hardware|cpuInfo|hz'))
            if ($cores -gt 0 -and $hz -gt 0) { $mhz = $cores * $hz / 1e6 }
        }
        if (-not ($mhz -gt 0) -and -not $miss.Contains('CPU')) { $miss.Add('CPU') }
        $hostVms = @($vms | Where-Object { $_.Host -eq $nodeNames[$id] })
        if ($failedVms.Count -or @($hostVms | Where-Object { $_.DRAM_Only -like 'Unknown*' }).Count) { $miss.Add('Eligibility') }
        $av = if ($active) { $active.Max } else { 0 }; $avg = if ($active -and $active.Weight -gt 0) { $active.Sum / $active.Weight } else { 0 }
        $con = if ($consumed -and $consumed.Weight -gt 0) { $consumed.Sum / $consumed.Weight } else { 0 }
        $core = Get-MtatOpsAggregate $stats $id 'cpuCore'
        $cp = if ($cpu -and $cpu.Weight -gt 0) { $cpu.Sum / $cpu.Weight } else { $null }
        $hosts.Add(@{ Cluster = $cluster.Name; HostName = $nodeNames[$id]; ResourceId = $id; Tiering = $tier; TierRatioPct = if ($tier -eq 'Enabled' -and $dram -gt 0 -and $nvme -gt 0) { [math]::Round($nvme / $dram * 100,1) } else { $null }; NVMe_GB = $nvme
            Active_Peak_Timestamp = if ($active) { $active.MaxTimestamp } else { $null }
            Active_Peak_Raw = if ($active) { $active.MaxRaw } else { $null }
            Active_Peak_Unit = if ($hm.active -and $hostMeta[$hm.active.Key].unit) { [string]$hostMeta[$hm.active.Key].unit } else { 'KB (inferred)' }
            Active_Metric_Key = if ($hm.active) { $hm.active.Key } else { $null }
            Active_Peak_Factor = if ($hm.active) { $hm.active.Factor } else { $null }
            Active_Peak_Interval_Seconds = if ($active) { $active.MaxIntervalSeconds } else { $null }
            Active_Sample_Count = if ($active) { $active.Count } else { 0 }
            Active_First_Timestamp = if ($active) { $active.First } else { $null }
            Active_Last_Timestamp = if ($active) { $active.Last } else { $null }
            Active_Intervals_Seconds = if ($active) { (@($active.Intervals.Keys | ForEach-Object { [double]$_ / 1000 } | Sort-Object) -join ', ') } else { '' }
            Physical_RAM = [math]::Round($dram,3); Active_GB = [math]::Round($av,3); Active_Avg_GB = [math]::Round($avg,3)
            Active_Pct = if ($dram -gt 0) { [math]::Round($av / $dram * 100,1) } else { 0 }; Consumed_GB = [math]::Round($con,3)
            CPU_Pct = if ($null -ne $cp) { [math]::Round($cp,1) } else { $null }; CPU_Core_Pct = if ($core -and $core.Weight -gt 0) { [math]::Round($core.Sum / $core.Weight,1) } else { $null }; CPU_MHz = $mhz; Missing_Metrics = $miss -join ', ' })
        if ($active -and (Get-Command Write-DebugLog -ErrorAction SilentlyContinue)) {
            $peakUtc = [DateTimeOffset]::FromUnixTimeMilliseconds($active.MaxTimestamp).UtcDateTime.ToString('yyyy-MM-dd HH:mm:ss')
            Write-DebugLog "[ops] Active peak evidence: host=$($nodeNames[$id]); range=$Range; key=$($hm.active.Key); timestamp=$peakUtc UTC; raw=$($active.MaxRaw); GB-per-unit=$($hm.active.Factor); peakGB=$av; capacityGB=$dram; samples=$($active.Count)."
        }
        $totalDram += $dram; $totalActive += $av; $totalAvg += $avg; $totalConsumed += $con
        if ($null -ne $cp -and $mhz -gt 0) { $cpuWeight += $mhz; $cpuUse += $mhz * $cp }
        if (-not $latest) {
            $entry = @{}
            foreach ($kind in 'active','consumed','cpu') {
                $arr = [object[]]::new($buckets); $a = Get-MtatOpsAggregate $stats $id $kind
                if ($a) { foreach ($bi in $a.Buckets.Keys) { $cell = $a.Buckets[$bi]; $arr[[int]$bi] = if ($kind -eq 'active') { [math]::Round($cell.Max,3) } elseif ($cell.Weight -gt 0) { [math]::Round($cell.Sum / $cell.Weight,3) } else { $null } } }
                $entry[$kind] = $arr
                $timeArr=[object[]]::new($buckets)
                if ($a) { foreach ($bi in $a.Buckets.Keys) { $cell=$a.Buckets[$bi];$timeArr[[int]$bi]=if($kind -eq 'active'){$cell.MaxTimestamp}else{$cell.FirstTimestamp} } }
                $entry[($kind+'Timestamps')] = $timeArr
            }
            $seriesHosts[$nodeNames[$id]] = $entry
        }
    }
    foreach ($spec in @(@{ Name='Host'; Metrics=$hm; Metadata=$hostMeta; Stats=$stats }, @{ Name='VM'; Metrics=$vmMetrics; Metadata=$vmMeta; Stats=$vs })) {
        $mapping = @($spec.Metrics.Keys | Sort-Object | ForEach-Object { if ($spec.Metrics[$_]) { "$_=$($spec.Metrics[$_].Key)" } else { "$_=unavailable" } }) -join '; '
        $count = @($spec.Metadata['__Available'].Keys).Count
        $notes.Add("$($spec.Name) counter discovery: $count aggregate keys available. Selected: $mapping.")
        if ($spec.Metadata['__DiscoveryErrors'].Count) { $notes.Add("$($spec.Name) counter discovery could not complete: $($spec.Metadata['__DiscoveryErrors'] -join '; ')") }
        $populated = @($spec.Stats.Values | Where-Object { @($_.Values | Where-Object { $_.Count -gt 0 }).Count -gt 0 }).Count
        if (-not $populated) { $notes.Add("CHECK DATA: no $($spec.Name.ToLowerInvariant()) performance samples were returned or matched for this range. Try Latest Ops Sample and check collection status; the debug log includes the selected counter keys.") }
        if (Get-Command Write-DebugLog -ErrorAction SilentlyContinue) { Write-DebugLog "[ops] $($spec.Name): available aggregate keys=$count; resources with samples=$populated; $mapping" }
        if (Get-Command Write-DebugLog -ErrorAction SilentlyContinue) {
            $candidates = @($spec.Metadata.Keys | Where-Object { $_ -notmatch '^__' -and $_ -match '(?i)dram|tier|memorysize|physical|pinned|passthrough|vgpu|sriov|fault.?toler|latency.?sens|lpage|largepage' } | Sort-Object | ForEach-Object {
                $attribute = $spec.Metadata[$_]
                "$($_) [unit=$($attribute.unit); property=$($attribute.property)]"
            })
            Write-DebugLog "[ops] $($spec.Name) configuration candidates: $($candidates -join '; ')"
        }
    }
    $notes.Add("Source: live $($session.Version). Latest is the latest collected Ops sample, not a vCenter real-time snapshot. Memory is decimal GB.")
    if ($last -gt 0) {
        $actualStart = [DateTimeOffset]::FromUnixTimeMilliseconds($first).UtcDateTime.ToString('yyyy-MM-dd HH:mm')
        $actualEnd = [DateTimeOffset]::FromUnixTimeMilliseconds($last).UtcDateTime.ToString('yyyy-MM-dd HH:mm')
        $notes.Add("Observed performance samples: $actualStart to $actualEnd UTC. Retained sample intervals (seconds): $((@($intervals.Keys | ForEach-Object { [double]$_ / 1000 } | Sort-Object) -join ', ')). Missing intervals are not reconstructed.")
    }
    if (-not $latest) { $notes.Add("Timeline chart interval: $([int]($bucketMs/1000)) seconds. Observed timestamps are retained alongside chart values; missing positions stay null. Chart intervals widen for larger inventories to bound memory; summary peaks and averages still use all returned samples.") }
    $notes.Add('Active peaks are maxima of retained Ops aggregates; short peaks already averaged out cannot be reconstructed. Cluster peak is a conservative sum of individual host maxima, which may occur at different times; it is not a simultaneous cluster peak. A longer window may include older spikes. Use Verify Ops active-memory peaks below to check each host and timestamp. Historical VM placement uses current inventory.')
    if (@($hosts | Where-Object { $_.Missing_Metrics -match 'Coverage' }).Count) { $notes.Add('CHECK DATA: some counters are stale or cover less than 80% of the requested window. Charts retain gaps; missing history is not filled with zero.') }
    if (@($hosts | Where-Object { $_.Missing_Metrics -match 'Eligibility' }).Count) { $notes.Add('CHECK DATA: The collected Ops data does not establish all VM pinning, passthrough and tiering settings required to certify DRAM-only eligibility. VM page settings remain Unknown; qualification and savings are withheld.') }
    if (@($hosts | Where-Object { $_.Missing_Metrics -match 'Capacity' }).Count) { $notes.Add('CHECK DATA: physical DRAM capacity could not be verified independently from logical tiered capacity. Confirm the host configuration before sizing.') }
    if (@($hosts | Where-Object { $_.Missing_Metrics -match 'TierConfig' }).Count) { $notes.Add('CHECK DATA: tier state or existing NVMe capacity/ratio is unavailable from verified Ops attributes. Existing-tier savings require configuration verification.') }
    return @{ source = 'ops'; dram = [math]::Round($totalDram,3); active = [math]::Round($totalActive,3); activeAvg = [math]::Round($totalAvg,3); consumed = [math]::Round($totalConsumed,3)
        cpu = if ($cpuWeight -gt 0) { [math]::Round($cpuUse / $cpuWeight,1) } else { $null }; cpuUnavailable = ($cpuWeight -le 0)
        hosts = $hosts.ToArray(); vms = $vms.ToArray(); failedHosts = @(); failedVms = $failedVms.ToArray(); dataNotes = $notes.ToArray()
        series = if ($latest) { $null } else { @{ startMs = $begin; bucketSeconds = [int]($bucketMs / 1000); buckets = $buckets; hosts = $seriesHosts } }
        sourceMeta = @{ product = $session.Version; requestedBegin = $begin; requestedEnd = $end; firstSample = if ($last) { $first } else { $null }; lastSample = if ($last) { $last } else { $null }
                        intervalSeconds = @($intervals.Keys | ForEach-Object { [double]$_ / 1000 }); hostMetrics = $hm; vmMetrics = $vmMetrics } }
}

# Bounded collection shared by maintenance and feature releases. Raw samples never enter caches.
function New-MtatCollectionContext([string]$RunId, [datetime]$End = [datetime]::UtcNow) {
    return @{ RunId=$RunId; End=$End.ToUniversalTime(); Inventory=@{}; HostViews=@{}; TierProbes=@{}; TierProbeSeconds=0.0; TierProbeCount=0; Intervals=@{}; Slices=@{}; Cells=0; Clock=0 }
}
function Set-MtatCollectionContext([string]$RunId) {
    if (-not $RunId -or $RunId.Length -gt 100 -or $RunId -notmatch '^[a-zA-Z0-9_-]+$') { $RunId=[guid]::NewGuid().ToString('N') }
    if (-not $global:MtatCollectionContext -or $global:MtatCollectionContext.RunId -ne $RunId) { $global:MtatCollectionContext=New-MtatCollectionContext $RunId }
    return $global:MtatCollectionContext
}
function Test-MtatCollectionCancellation {
    if ($global:MtatDeadlineUtc -and [datetime]::UtcNow -ge $global:MtatDeadlineUtc) { throw [TimeoutException]::new('Collection worker execution limit reached.') }
    if ($global:MtatCancelPath -and (Test-Path -LiteralPath $global:MtatCancelPath)) { throw [OperationCanceledException]::new('Collection cancelled.') }
}
function Set-MtatCollectionProgress([string]$Phase, [int]$Done=0, [int]$Total=0) {
    Test-MtatCollectionCancellation
    if ($global:MtatProgressPath) {
        $now=[datetime]::UtcNow
        if (-not $global:MtatLastProgress -or ($now-$global:MtatLastProgress).TotalSeconds -ge 1 -or $Done -eq $Total) {
            $global:MtatLastProgress=$now
            $state=@{phase=$Phase;done=$Done;total=$Total;updatedUtc=$now.ToString('o');memoryMB=[math]::Round([Diagnostics.Process]::GetCurrentProcess().WorkingSet64/1MB,1)}
            Write-MtatAtomicJson $global:MtatProgressPath $state
        }
    }
}
function Get-MtatInventoryBatch($Ids, $Server, $Failed) {
    Test-MtatCollectionCancellation
    if (-not $Ids.Count) { return }
    try {
        try {
            $properties=@('Name','Runtime','Summary','Config.Hardware','Config.ExtraConfig','Config.LatencySensitivity','Config.Uuid','Config.InstanceUuid','Config.Template','Config.Name','Config.Files')
            $views=@(Get-View -Id $Ids -Property $properties -Server $Server -ErrorAction Stop)
            $objects=@(Get-VIObjectByVIView -VIView $views -ErrorAction Stop)
            if(@($objects|Where-Object{-not $_.Id -or -not ($_.ExtensionData.Config.Hardware.MemoryMB -gt 0)}).Count -or $objects.Count -ne $Ids.Count){throw 'Incomplete selective VM view.'}
        } catch {
            if($_.Exception.Message -match '(?i)timed out|timeout|not authenticated|unauthorized|forbidden|connection.*(closed|refused|reset)|name.*resolution'){throw}
            $objects=@(Get-VM -Id $Ids -Server $Server -ErrorAction Stop)
        }
        $byId=@{};foreach($vm in $objects){$byId[[string]$vm.Id]=$vm}
        foreach($id in $Ids){if(-not $byId.ContainsKey([string]$id)){throw 'Incomplete VM inventory batch.'}}
        foreach($id in $Ids){$byId[[string]$id]}
    } catch {
        if($_.Exception.Message -match '(?i)timed out|timeout|not authenticated|unauthorized|forbidden|connection.*(closed|refused|reset)|name.*resolution'){throw}
        if ($Ids.Count -eq 1) {
            $Failed.Add([string]$Ids[0]+' (unresolvable)')
            Write-DebugLog "[inventory] VM $($Ids[0]) could not be resolved: $(Get-FullExceptionText $_)"
            return
        }
        # Binary isolation keeps a malformed VM from invalidating the entire cluster.
        $half=[int][math]::Floor($Ids.Count/2)
        Get-MtatInventoryBatch @($Ids|Select-Object -First $half) $Server $Failed
        Get-MtatInventoryBatch @($Ids|Select-Object -Skip $half) $Server $Failed
    }
}
function Get-MtatClusterInventory($Cluster,$Server,$Context) {
    $key=[string]$Server.Name+'|'+[string]$Cluster.Id
    if($Context.Inventory.ContainsKey($key)){return $Context.Inventory[$key]}
    # Only one cluster's rich PowerCLI objects are retained, even for fleet jobs.
    $Context.Inventory.Clear();$Context.HostViews.Clear();$Context.TierProbes.Clear();$Context.TierProbeSeconds=0.0;$Context.TierProbeCount=0
    $hosts=@(Invoke-WithRetry -Description 'Host inventory' -Action {Get-VMHost -Location $Cluster -Server $Server -ErrorAction Stop})
    $identities=@(Invoke-WithRetry -Description 'VM identities' -Action {Get-View -ViewType VirtualMachine -SearchRoot $Cluster.ExtensionData.MoRef -Property Name,Runtime.PowerState -Server $Server -ErrorAction Stop}|Where-Object{$_.Runtime.PowerState -eq 'poweredOn'})
    $ids=@($identities|ForEach-Object{[string]$_.MoRef.ToString()})
    $vms=New-Object 'System.Collections.Generic.List[object]';$failed=New-Object 'System.Collections.Generic.List[string]'
    for($offset=0;$offset -lt $ids.Count;$offset+=64){
        Set-MtatCollectionProgress 'VM inventory' $offset $ids.Count
        foreach($vm in @(Get-MtatInventoryBatch @($ids|Select-Object -Skip $offset -First 64) $Server $failed)){$vms.Add($vm)}
    }
    Set-MtatCollectionProgress 'VM inventory' $ids.Count $ids.Count
    $data=@{Hosts=$hosts;VMs=$vms.ToArray();Failed=$failed.ToArray();CapturedUtc=[datetime]::UtcNow.ToString('o')}
    $Context.Inventory[$key]=$data
    Write-DebugLog "[inventory] Snapshot: server=$($Server.Name); cluster=$($Cluster.Name); hosts=$($hosts.Count); VMs=$($vms.Count); failed=$($failed.Count)."
    return $data
}
function Get-MtatHostView($HostObject,$Server,$Context) {
    $key=[string]$Server.Name+'|'+[string]$HostObject.Id
    if(-not $Context.HostViews.ContainsKey($key)){$Context.HostViews[$key]=Get-View -Id $HostObject.Id -Server $Server -Property Hardware,Config.Option -ErrorAction Stop}
    return $Context.HostViews[$key]
}
function Get-MtatEsxCli($HostObject,$Context) {
    # A lightweight facade caches only results, never heavyweight per-host esxcli interfaces.
    $id=[string]$HostObject.Id
    if($Context.TierProbes.ContainsKey($id)){return $Context.TierProbes[$id]}
    Test-MtatCollectionCancellation
    if($Context.TierProbeSeconds -ge 60 -or ($Context.TierProbeCount -ge 2 -and $Context.TierProbeSeconds/$Context.TierProbeCount -gt 10)) {
        $Context.TierProbes[$id]=$null;Write-DebugLog "[configuration] Tier probe budget reached; $id remains unverified.";return $null
    }
    $clock=[Diagnostics.Stopwatch]::StartNew();$kind=$null;$value=$null
    try {
        $cli=Get-EsxCli -VMHost $HostObject -V2 -ErrorAction Stop
        if($null -eq $cli){$Context.TierProbes[$id]=$null;return $null}
        if($null -ne $cli.memtier){$value=$cli.memtier.status.get.Invoke();$kind='memtier'}
        elseif($null -ne $cli.system.settings.kernel){$value=@($cli.system.settings.kernel.list.Invoke());$kind='kernel'}
    } catch {$Context.TierProbes[$id]=$null;Write-DebugLog "[configuration] Tier probe failed for $id; configuration remains unverified: $($_.Exception.Message)";return $null}
    finally {$clock.Stop();$Context.TierProbeSeconds+=$clock.Elapsed.TotalSeconds;$Context.TierProbeCount++}
    $answer=[pscustomobject]@{Value=$value}
    $answer|Add-Member ScriptMethod Invoke {return $this.Value}
    $facade=if($kind -eq 'memtier'){[pscustomobject]@{memtier=[pscustomobject]@{status=[pscustomobject]@{get=$answer}}}}elseif($kind -eq 'kernel'){[pscustomobject]@{system=[pscustomobject]@{settings=[pscustomobject]@{kernel=[pscustomobject]@{list=$answer}}}}}else{[pscustomobject]@{}}
    $Context.TierProbes[$id]=$facade
    return $facade
}
function Get-MtatStatInterval($Server,[double]$SpanSeconds,$Context) {
    $key=[string]$Server.Name
    if(-not $Context.Intervals.ContainsKey($key)){
        try{$si=Get-View ServiceInstance -Server $Server -ErrorAction Stop;$pm=Get-View $si.Content.PerfManager -Server $Server -ErrorAction Stop;$Context.Intervals[$key]=@($pm.HistoricalInterval|Where-Object{$_.Enabled -and $_.SamplingPeriod -gt 0})}
        catch{$Context.Intervals[$key]=@();Write-DebugLog '[stats] Retention metadata unavailable; this historical range cannot be collected safely.'}
    }
    $available=@($Context.Intervals[$key]|Where-Object{$_.Length -ge $SpanSeconds}|Sort-Object SamplingPeriod)
    if($available.Count){return [int]$available[0].SamplingPeriod}
    $last=@($Context.Intervals[$key]|Sort-Object Length -Descending)
    if($last.Count){return [int]$last[0].SamplingPeriod}
    throw 'vCenter retention intervals are unavailable. Reconnect and verify performance-metric permissions before collecting history.'
}
function New-MtatStatCell {return @{Count=0;Sum=0.0;Max=[double]::MinValue;First=[datetime]::MaxValue;Last=[datetime]::MinValue;Buckets=@{}}}
function Merge-MtatStatCell($Into,$From) {
    $Into.Count+=$From.Count;$Into.Sum+=$From.Sum;$Into.Max=[math]::Max($Into.Max,$From.Max)
    if($From.First -lt $Into.First){$Into.First=$From.First};if($From.Last -gt $Into.Last){$Into.Last=$From.Last}
    foreach($k in $From.Buckets.Keys){$b=$From.Buckets[$k];if(-not $Into.Buckets.ContainsKey($k)){$Into.Buckets[$k]=@{Count=0;Sum=0.0;Max=[double]::MinValue}};$a=$Into.Buckets[$k];$a.Count+=$b.Count;$a.Sum+=$b.Sum;$a.Max=[math]::Max($a.Max,$b.Max)}
}
function Read-MtatStatBatch($Entities,$Metrics,[datetime]$Start,[datetime]$Finish,[int]$Interval,$Server,[switch]$Series) {
    Test-MtatCollectionCancellation
    $argsMap=@{Entity=$Entities;Stat=$Metrics;Start=$Start;Finish=$Finish;Server=$Server;Instance=@('');ErrorAction='Stop'}
    if($Interval -gt 0){$argsMap.IntervalSecs=$Interval;$argsMap.MaxSamples=[int][math]::Ceiling(($Finish-$Start).TotalSeconds/$Interval)+2}
    $index=@{};$seen=@{};$idByName=@{};$valid=@{}
    foreach($e in $Entities){$valid[[string]$e.Id]=$true;$n=[string]$e.Name;if($idByName.ContainsKey($n)){$idByName[$n]=$null}else{$idByName[$n]=[string]$e.Id}}
    # Pipeline aggregation bounds retained memory to summaries; no cluster-wide raw sample array.
    Get-Stat @argsMap | ForEach-Object {
        $sample=$_;$id=[string]$sample.Entity.Id
        if(-not $id){$id=$idByName[[string]$sample.Entity.Name]}
        if(-not $sample.Instance -and $id -and $valid.ContainsKey($id) -and $Metrics -contains [string]$sample.MetricId){
            $t=([datetime]$sample.Timestamp).ToUniversalTime();$v=[double]$sample.Value
            if ($sample.IntervalSecs -gt 0 -and $Interval -gt 0 -and [int]$sample.IntervalSecs -ne $Interval) { throw 'vCenter returned a different sampling interval; this batch was not accepted.' }
            if($t -ge $Start -and $t -lt $Finish -and -not [double]::IsNaN($v) -and -not [double]::IsInfinity($v) -and $v -ge 0){
                $identity=$id+'|'+[string]$sample.MetricId;$unique=$identity+'|'+$t.Ticks
                if(-not $seen.ContainsKey($unique)){
                    $seen[$unique]=$true
                    if(-not $index.ContainsKey($identity)){$index[$identity]=New-MtatStatCell}
                    $a=$index[$identity];$a.Count++;$a.Sum+=$v;$a.Max=[math]::Max($a.Max,$v);if($t -lt $a.First){$a.First=$t};if($t -gt $a.Last){$a.Last=$t}
                    if($Series){$hour=[long][math]::Floor(($t-[datetime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).TotalHours);$k=[string]$hour;if(-not $a.Buckets.ContainsKey($k)){$a.Buckets[$k]=@{Count=0;Sum=0.0;Max=[double]::MinValue}};$b=$a.Buckets[$k];$b.Count++;$b.Sum+=$v;$b.Max=[math]::Max($b.Max,$v)}
                }
            }
        }
    }
    return $index
}
function Read-MtatStatistics($Entities,$Metrics,[datetime]$Start,[datetime]$Finish,$Server,$Context,[switch]$Series) {
    $result=@{};$interval=Get-MtatStatInterval $Server ($Finish-$Start).TotalSeconds $Context
    $done=0;$total=[math]::Ceiling($Entities.Count/32.0)
    for($offset=0;$offset -lt $Entities.Count;$offset+=32){
        $batch=@($Entities|Select-Object -Skip $offset -First 32)
        $step=if($interval -gt 0){[math]::Min(86400.0,[math]::Max([double]$interval,[math]::Floor(25000.0/($batch.Count*$Metrics.Count))*$interval))}else{($Finish-$Start).TotalSeconds}
        for($end=$Finish;$end -gt $Start;$end=$from){
            $from=$end.AddSeconds(-$step);if($from -lt $Start){$from=$Start}
            Test-MtatCollectionCancellation
            $cacheKey=([string]$Server.Name)+'|'+(($batch.Id|Sort-Object)-join ',')+'|'+($Metrics -join ',')+'|'+$interval+'|'+$from.Ticks+'|'+$end.Ticks+'|'+[bool]$Series
            if($Context.Slices.ContainsKey($cacheKey)){$slice=$Context.Slices[$cacheKey].Data;$Context.Slices[$cacheKey].Used=++$Context.Clock}
            else{
                $slice=$null
                for($attempt=1;$attempt -le 3;$attempt++){
                    try{$slice=Read-MtatStatBatch $batch $Metrics $from $end $interval $Server -Series:$Series;break}
                    catch{Test-MtatCollectionCancellation;if($attempt -eq 3){throw};Write-DebugLog "[stats] Batch retry $attempt/3: $($_.Exception.Message)";Start-Sleep -Milliseconds (500*$attempt)}
                }
                $cells=0;foreach($a in $slice.Values){$cells+=1+$a.Buckets.Count}
                if($cells -le 20000){
                    while(($Context.Cells+$cells -gt 20000 -or $Context.Slices.Count -ge 512) -and $Context.Slices.Count){$old=($Context.Slices.GetEnumerator()|Sort-Object {$_.Value.Used}|Select-Object -First 1).Key;$Context.Cells-=$Context.Slices[$old].Cells;$Context.Slices.Remove($old)}
                    $Context.Slices[$cacheKey]=@{Data=$slice;Cells=$cells;Used=++$Context.Clock};$Context.Cells+=$cells
                }
                Write-DebugLog "[stats] Batch: entities=$($batch.Count); counters=$($Metrics.Count); interval=$interval; from=$($from.ToString('o')); to=$($end.ToString('o')); summaries=$($slice.Count); cacheCells=$($Context.Cells)."
            }
            foreach($key in $slice.Keys){if(-not $result.ContainsKey($key)){$result[$key]=New-MtatStatCell};Merge-MtatStatCell $result[$key] $slice[$key]}
            Set-MtatCollectionProgress 'Historical statistics' $done $total
        }
        $done++;Set-MtatCollectionProgress 'Historical statistics' $done $total
    }
    return @{Index=$result;Interval=$interval;Start=$Start;Finish=$Finish}
}
function Get-MtatStatCell($Index,$Entity,[string]$Metric) {return $Index[([string]$Entity.Id)+'|'+$Metric]}
function Get-MtatStatMean($Cell) {if($Cell -and $Cell.Count){return $Cell.Sum/$Cell.Count};return 0.0}
function ConvertTo-MtatSeries($Collection,$Hosts,[int]$BucketSeconds) {
    $origin=if($BucketSeconds -ge 86400){$Collection.Start.Date}else{$Collection.Start.Date.AddHours($Collection.Start.Hour)}
    $count=[int][math]::Ceiling(($Collection.Finish-$origin).TotalSeconds/$BucketSeconds);$output=@{}
    foreach($h in $Hosts){
        $entry=@{}
        foreach($spec in @(@('active','mem.active.average'),@('consumed','mem.consumed.average'),@('cpu','cpu.usage.average'))){
            $arr=[object[]]::new($count);$a=Get-MtatStatCell $Collection.Index $h $spec[1];$merged=@{}
            if($a){foreach($hour in $a.Buckets.Keys){$t=([datetime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).AddHours([long]$hour);$bi=[int][math]::Floor(($t-$origin).TotalSeconds/$BucketSeconds);if($bi -lt 0){$bi=0};if($bi -ge $count){continue};$b=$a.Buckets[$hour];if(-not $merged.ContainsKey($bi)){$merged[$bi]=@{Count=0;Sum=0.0;Max=[double]::MinValue}};$c=$merged[$bi];$c.Count+=$b.Count;$c.Sum+=$b.Sum;$c.Max=[math]::Max($c.Max,$b.Max)}}
            foreach($bi in $merged.Keys){$c=$merged[$bi];$v=if($spec[0] -eq 'active'){$c.Max}else{$c.Sum/$c.Count};if($spec[0] -ne 'cpu'){$v*=1024.0/1e9};$arr[[int]$bi]=[math]::Round($v,3)}
            $entry[$spec[0]]=$arr
        }
        $output[[string]$h.Name]=$entry
    }
    return @{bucketSeconds=$BucketSeconds;buckets=$count;startMs=[long](($origin-[datetime]::new(1970,1,1,0,0,0,[DateTimeKind]::Utc)).TotalMilliseconds);hosts=$output}
}

function Invoke-MtatVCenterAnalysis($clusterComposite,$rangeSelection,[string]$CollectionRunId) {
                # Unlike the /api/get-cluster-ranges sibling (which treats a missing/malformed key as
                # a gracefully-handled "just offer Real-Time Snapshot" case), analysis genuinely can't
                # proceed without a valid target -- reject clearly here instead of letting a blank or
                # broken key flow into Get-Cluster with a $null/garbage name below.
                if ([string]::IsNullOrEmpty($clusterComposite)) {
                    throw "No cluster was specified in the request (empty 'cluster' value) -- select a Target Cluster Scope on Step 2 before analyzing."
                }
                $parts = $clusterComposite.Split('|')
                if ($parts.Length -lt 2) {
                    throw "Malformed cluster identifier '$clusterComposite' -- expected '<server>|<cluster>'."
                }
                $targetServer = $parts[0]
                $clusterName = ($parts | Select-Object -Skip 1) -join '|'

                $viServerObj = $global:DefaultVIServers | Where-Object { $_.Name -eq $targetServer } | Select-Object -First 1
                if ($null -eq $viServerObj) {
                    throw "No active vCenter session found for server '$targetServer' -- it may have disconnected. Please reconnect on Step 1 and try again."
                }
                $targetCluster = Invoke-WithRetry -Description "Get-Cluster '$clusterName'" -Action {
                    # By ID when the cluster came from this session's list (see api/connect); otherwise an
                    # exact name match, because Get-Cluster -Name treats * ? [ ] as wildcards.
                    $clusterId = if ($null -ne $global:ClusterKeyMap) { $global:ClusterKeyMap[$clusterComposite] } else { $null }
                    if ($clusterId) { Get-Cluster -Id $clusterId -Server $viServerObj }
                    else { Get-Cluster -Server $viServerObj | Where-Object { $_.Name -eq $clusterName } | Select-Object -First 1 }
                }
                if ($null -eq $targetCluster) {
                    throw "Cluster '$clusterName' was not found on '$targetServer' -- it may have been renamed or removed. Reconnect on Step 1 to refresh the cluster list."
                }

                $collectionContext = Set-MtatCollectionContext $CollectionRunId
                $inventory = Get-MtatClusterInventory $targetCluster $viServerObj $collectionContext
                $hosts = @($inventory.Hosts); $allVMs = @($inventory.VMs)
                $failedVmNames = New-Object 'System.Collections.Generic.List[string]'
                foreach ($failure in $inventory.Failed) { $failedVmNames.Add($failure) }
                # Inventory counts up front so a "the tool isn't pulling all the data" report can be
                # checked against what vCenter actually returned for this cluster/range. Powered-off
                # VMs are intentionally excluded (this is a live-usage assessment), not a bug -- logged
                # explicitly so that distinction is visible rather than assumed.
                Write-DebugLog "[analyze] Cluster '$clusterName' on '$targetServer', range '$rangeSelection': found $($hosts.Count) host(s), $($allVMs.Count) powered-on VM(s) (powered-off VMs are intentionally excluded)."

                $hostStatIndex=@{}; $vmStatIndex=@{}; $seriesPayload=$null; $hostCollection=$null
                if ($rangeSelection -notmatch 'Real-Time') {
                    $daysBack=switch($rangeSelection){'Past 24 Hours'{-1}'Past 7 Days'{-7}'Past 30 Days'{-30}'Past 365 Days'{-365}default{throw 'Unsupported vCenter range.'}}
                    $startTime=$collectionContext.End.AddDays($daysBack)
                    $hostCollection=Read-MtatStatistics $hosts @('cpu.usage.average','mem.active.average','mem.consumed.average') $startTime $collectionContext.End $viServerObj $collectionContext -Series
                    $vmCollection=Read-MtatStatistics $allVMs @('mem.active.average') $startTime $collectionContext.End $viServerObj $collectionContext
                    $hostStatIndex=$hostCollection.Index; $vmStatIndex=$vmCollection.Index
                    $bucketSecs=if($daysBack -le -90){86400}else{3600}
                    $seriesPayload=ConvertTo-MtatSeries $hostCollection $hosts $bucketSecs
                }

                $totalDramGB_Sum = 0; $totalActiveGB = 0; $totalActiveGB_Avg = 0; $totalCpuMhz_Sum = 0; $totalCpuUsageMhz_Sum = 0; $totalConsumedMemGB_Sum = 0
                $hostResults = New-Object System.Collections.Generic.List[PSObject]
                $vmResults = New-Object System.Collections.Generic.List[PSObject]
                $failedHostNames = New-Object System.Collections.Generic.List[string]
                # $failedVmNames was already created above (it starts tracking during VM resolution,
                # before this point) -- do not re-declare it here, that would discard entries already
                # added for VMs that failed to resolve via Get-VM -Id.

                # `Get-EsxCli -V2` binds a fresh per-host interface on every call (roughly 1-3s of
                # overhead each, sequentially, since PowerCLI connection objects aren't safely usable
                # from a background thread to run these in parallel/with a true per-call timeout).
                # A flat total-time cap would unfairly punish a large-but-healthy cluster (e.g. a
                # 90-host cluster running normally at ~2s/host legitimately needs ~180s here -- that's
                # not a problem, just a bigger cluster) while doing nothing smarter for a SMALL cluster
                # where esxcli is genuinely hanging. So instead of capping total elapsed time, this
                # tracks the RUNNING AVERAGE seconds-per-host and only gives up once that average
                # itself looks abnormal -- cluster size alone can never trip this, only genuinely
                # slow/stuck esxcli behavior can. A minimum sample size avoids overreacting to one
                # unlucky slow host early on, and a generous absolute ceiling is kept as a last-resort
                # backstop for defense in depth.
                # Index the samples once (see New-StatIndex) and group the VMs by host, instead of
                # re-filtering the full lists inside the host and VM loops below.
                $hostNameCounts = Get-NameCounts $hosts
                $vmNameCounts = Get-NameCounts $allVMs
                $vmsByHost = @{}
                $hostNamesById=@{}; foreach ($node in $hosts) { $hostNamesById[[string]$node.Id]=[string]$node.Name; if ($node.ExtensionData.MoRef) { $hostNamesById[[string]$node.ExtensionData.MoRef.Value]=[string]$node.Name } }
                foreach ($vmItem in $allVMs) {
                    $hostRef = [string]$vmItem.ExtensionData.Runtime.Host.Value
                    $vmHostKey = if ($hostRef -and $hostNamesById.ContainsKey($hostRef)) { $hostNamesById[$hostRef] } else { [string]$vmItem.VMHost.Name }
                    if (-not $vmsByHost.ContainsKey($vmHostKey)) { $vmsByHost[$vmHostKey] = New-Object System.Collections.Generic.List[object] }
                    $vmsByHost[$vmHostKey].Add($vmItem)
                }

                $esxcliPhaseStartTime = Get-Date
                $esxcliCallCount = 0
                $esxcliMinSampleSize = 5          # don't judge the average off just a handful of hosts
                $esxcliAvgThresholdSeconds = 10   # generous margin above the ~1-3s/host normally seen
                $esxcliHardCeilingSeconds = 1200  # 20 min absolute backstop regardless of the average
                $esxcliBudgetExceeded = $false

                foreach ($h in $hosts) {
                  try {
                    # "Unknown" until vCenter or esxcli actually answers (see below): a failed or skipped
                    # query must never read as "Disabled", or an already-tiered host would be offered
                    # savings it already has.
                    $hostIsTiered = "Unknown"
                    $hostTierRatioPct = 0
                    $hostNvmeGB = $null
                    $hostMissing = New-Object System.Collections.Generic.List[string]
                    # Tracks whether esxcli itself actually reported a Ratio/Percentage value below,
                    # as opposed to $hostTierRatioPct just sitting at its 0 default -- a host can be
                    # "Enabled" with a genuine 0 ratio (e.g. no NVMe currently attached/active), and
                    # without this flag that real 0 was indistinguishable from "esxcli didn't say" and
                    # got silently overwritten by the Mem.TierNVMePct/100 fallback below.
                    $hostTierRatioReported = $false
                    $cpuTotalMhz = [math]::Round(($h.ExtensionData.Hardware.CpuInfo.Hz * $h.ExtensionData.Hardware.CpuInfo.NumCpuCores) / 1000000, 0)

                    Set-MtatCollectionProgress 'Host configuration and assessment' $hostResults.Count $hosts.Count
                    $hv = Get-MtatHostView $h $viServerObj $collectionContext

                    # Tiering status, cheapest reliable source first (checked against esxcli on 9.1.1 lab
                    # hosts, one tiered and one not):
                    #  1. ESXi older than 8.0 U3 cannot run Memory Tiering at all.
                    #  2. vCenter's Hardware.MemoryTierInfo (vSphere 8.0 U3 and later): a DRAM entry, plus
                    #     an NVMe entry while tiering is on, with their sizes. It arrives with the host data
                    #     read just above, so it costs no extra call and cannot hang.
                    #  3. esxcli, only when 1 and 2 cannot answer (for example a PowerCLI too old to read
                    #     MemoryTierInfo). A single esxcli call cannot be interrupted, so it is only used
                    #     when nothing else can answer.
                    $tierInfo = @($hv.Hardware.MemoryTierInfo | Where-Object { $null -ne $_ })
                    $dramTier = $tierInfo | Where-Object { [string]$_.Type -match "^(?i)dram$" } | Select-Object -First 1
                    $nvmeTier = $tierInfo | Where-Object { [string]$_.Type -match "^(?i)nvme$" } | Select-Object -First 1
                    if ($null -ne $nvmeTier -and [double]$nvmeTier.Size -gt 0) { $hostNvmeGB = [math]::Round([double]$nvmeTier.Size / 1000000000.0, 3) }
                    $hostEsxVersion = $null
                    try { $hostEsxVersion = [version]([string]$h.Version) } catch {}
                    $hostConnState = [string]$h.ConnectionState

                    if ($null -ne $hostEsxVersion -and $hostEsxVersion -lt [version]"8.0.3") {
                        $hostIsTiered = "Disabled"
                    } elseif ($tierInfo.Count -gt 0) {
                        $hostIsTiered = if ($null -ne $hostNvmeGB) { "Enabled" } else { "Disabled" }
                        # The ratio is the actual NVMe tier size against the DRAM tier (lab: 24 GB / 24 GB =
                        # 100%, matching esxcli's "100 percent of DRAM").
                        if ($null -ne $hostNvmeGB -and $null -ne $dramTier -and [double]$dramTier.Size -gt 0) {
                            $hostTierRatioPct = [int][math]::Round($hostNvmeGB / ([double]$dramTier.Size / 1000000000.0) * 100)
                            $hostTierRatioReported = $true
                        }
                    } elseif ($hostConnState -match "^(?i)(Disconnected|NotResponding)$") {
                        # A host vCenter cannot reach can only fail or hang in esxcli, so it is not asked.
                        Write-DebugLog "[analyze] Skipping esxcli tiering-status query for host '$($h.Name)' -- the host is '$hostConnState' in vCenter and vCenter has no memory tier information for it, so Tiering shows as 'Unknown'."
                    } elseif ($esxcliBudgetExceeded) {
                        Write-DebugLog "[analyze] Skipping esxcli tiering-status query for host '$($h.Name)' -- per-host esxcli response time looked abnormal earlier this run, so Tiering shows as 'Unknown' for this and any remaining host(s) that vCenter has no memory tier information for."
                    } else {
                    try {
                        $esxcli = Get-MtatEsxCli $h $collectionContext
                        if ($null -eq $esxcli) {
                            Write-DebugLog "[analyze] WARNING: Get-EsxCli returned nothing for host '$($h.Name)' (usually missing permissions for this account, or the host is unreachable), so Tiering shows as 'Unknown'."
                        } elseif ($null -ne $esxcli.memtier) {
                            $status = $esxcli.memtier.status.get.Invoke()
                            if ($status.Status -match "Enabled") {
                                $hostIsTiered = "Enabled"
                                if ($null -ne $status.Ratio) { $hostTierRatioPct = [int]$status.Ratio; $hostTierRatioReported = $true }
                                elseif ($null -ne $status.Percentage) { $hostTierRatioPct = [int]$status.Percentage; $hostTierRatioReported = $true }
                                # 9.1 reports it inside Size, e.g. "23.99GiBs (100 percent of DRAM)".
                                elseif ([string]$status.Size -match '\((\d+)\s*percent') { $hostTierRatioPct = [int]$Matches[1]; $hostTierRatioReported = $true }
                            } else {
                                $hostIsTiered = "Disabled"
                            }
                        } elseif ($null -ne $esxcli.system.settings.kernel) {
                            # 8.0 U3 / 9.0 kernel setting; some builds name it swMemoryTiering. A host with
                            # neither setting cannot run Memory Tiering, so that is a real "Disabled".
                            $tierSetting = @($esxcli.system.settings.kernel.list.Invoke() | Where-Object { $_.Name -eq "MemoryTiering" -or $_.Name -eq "swMemoryTiering" })
                            $hostIsTiered = if (@($tierSetting | Where-Object { [string]$_.Runtime -match "TRUE" }).Count -gt 0) { "Enabled" } else { "Disabled" }
                        }
                    } catch {
                        # $hostIsTiered may already be "Enabled" here if the failure happened AFTER
                        # that was set (e.g. casting $status.Ratio/$status.Percentage to [int] below
                        # it) -- log what it is so far rather than assuming.
                        Write-DebugLog "[analyze] WARNING: esxcli tiering-status query failed for host '$($h.Name)' -- Tiering so far: '$hostIsTiered' (ratio/percentage detail may be incomplete if this failed partway through). Error: $(Get-FullExceptionText $_)"
                    }
                    $esxcliCallCount++

                    $esxcliElapsedSeconds = ((Get-Date) - $esxcliPhaseStartTime).TotalSeconds
                    $esxcliAvgSecondsPerHost = $esxcliElapsedSeconds / $esxcliCallCount
                    $esxcliAvgLooksAbnormal = ($esxcliCallCount -ge $esxcliMinSampleSize -and $esxcliAvgSecondsPerHost -gt $esxcliAvgThresholdSeconds)
                    $esxcliHitHardCeiling = ($esxcliElapsedSeconds -gt $esxcliHardCeilingSeconds)
                    if (-not $esxcliBudgetExceeded -and ($esxcliAvgLooksAbnormal -or $esxcliHitHardCeiling)) {
                        $esxcliBudgetExceeded = $true
                        Write-DebugLog "[analyze] WARNING: esxcli tiering-status queries are averaging $([math]::Round($esxcliAvgSecondsPerHost, 1))s/host across $esxcliCallCount host(s) so far (hard ceiling hit: $esxcliHitHardCeiling) -- this looks like genuinely abnormal esxcli behavior, not just a large cluster, so remaining host(s) this run will skip it (Tiering then shows as 'Unknown' where vCenter has no memory tier information) rather than wait indefinitely."
                    }
                    }

                    if ($hostIsTiered -eq "Enabled" -and -not $hostTierRatioReported) {
                        $tierPctSetting = $hv.Config.Option | Where-Object { $_.Key -eq "Mem.TierNVMePct" } | Select-Object -First 1
                        if ($null -ne $tierPctSetting) {
                            $hostTierRatioPct = [int]$tierPctSetting.Value
                        } else {
                            $hostTierRatioPct = 100
                        }
                    }

                    $hostDramGB = [math]::Round($hv.Hardware.MemorySize / 1000000000.0, 3)
                    # On a tiered host the total memory size includes the NVMe tier (lab: 48 GB = 24 GB DRAM
                    # + 24 GB NVMe), so DRAM is taken from the DRAM tier.
                    if ($null -ne $hostNvmeGB -and $null -ne $dramTier -and [double]$dramTier.Size -gt 0) { $hostDramGB = [math]::Round([double]$dramTier.Size / 1000000000.0, 3) }
                    elseif ($hostIsTiered -eq "Enabled" -and $tierInfo.Count -eq 0 -and $hostTierRatioPct -gt 0) {
                        # No tier list (esxcli answered instead): the total still includes the NVMe tier, so
                        # split it by the ratio, DRAM = total / (1 + ratio).
                        $hostTotalGB = [double]$hv.Hardware.MemorySize / 1000000000.0
                        $hostDramRawGB = $hostTotalGB / (1 + $hostTierRatioPct / 100)
                        $hostDramGB = [math]::Round($hostDramRawGB, 3)
                        $hostNvmeGB = [math]::Round($hostTotalGB - $hostDramRawGB, 3)
                    }

                    if ($rangeSelection -notmatch "Real-Time") {
                        $cpuVals = Get-MtatStatCell $hostStatIndex $h "cpu.usage.average"
                        $actVals = Get-MtatStatCell $hostStatIndex $h "mem.active.average"
                        $consVals = Get-MtatStatCell $hostStatIndex $h "mem.consumed.average"

                        # A counter with no samples still computes as 0 below, but it is recorded in
                        # Missing_Metrics so the UI shows "No data" and never turns it into a PASS.
                        if ($null -eq $cpuVals) { $hostMissing.Add("CPU"); $cpuVals = New-MtatStatCell }
                        if ($null -eq $actVals) { $hostMissing.Add("Active"); $actVals = New-MtatStatCell; $actVals.Max=0 }
                        if ($null -eq $consVals) { $hostMissing.Add("Consumed"); $consVals = New-MtatStatCell }
                        $hostCpuPct = (Get-MtatStatMean $cpuVals)
                        # Active Memory only: worst-case sizing wants the single highest average-rollup
                        # bucket in the window (e.g. the worst 30-min sample of the past week), not the
                        # window-wide average, so bursty clusters aren't under-sized. CPU and Consumed
                        # Memory stay plain time-weighted averages.
                        $hostActiveGB = [math]::Round(($actVals.Max) * 1024.0 / 1000000000.0, 3)
                        $hostActiveAvgGB = [math]::Round(((Get-MtatStatMean $actVals)) * 1024.0 / 1000000000.0, 3)
                        $hostConsumedMemGB = [math]::Round(((Get-MtatStatMean $consVals)) * 1024.0 / 1000000000.0, 3)
                        if ($hostCollection.Interval -gt 0) {
                            foreach ($cell in @($cpuVals,$actVals,$consVals)) {
                                if ($cell.Count * [double]$hostCollection.Interval / ($collectionContext.End-$startTime).TotalSeconds -lt 0.8 -and -not $hostMissing.Contains('Coverage')) { $hostMissing.Add('Coverage') }
                            }
                        }
                        $cpuUsageMhz = $cpuTotalMhz * ($hostCpuPct / 100)
                    } else {
                        $cpuUsageMhz = $h.ExtensionData.Summary.QuickStats.OverallCpuUsage
                        $hostCpuPct = if ($cpuTotalMhz -gt 0) { [math]::Round(($cpuUsageMhz / $cpuTotalMhz) * 100, 2) } else { 0 }
                        $hostConsumedMemGB = [math]::Round($h.ExtensionData.Summary.QuickStats.OverallMemoryUsage * 1048576.0 / 1000000000.0, 3)
                        $hostActiveGB = 0
                        $hostActiveAvgGB = $null
                        # vCenter has no current figures for a host it cannot reach; its QuickStats read 0.
                        if ($hostConnState -match "^(?i)(Disconnected|NotResponding)$") { $hostMissing.Add("CPU"); $hostMissing.Add("Active"); $hostMissing.Add("Consumed") }
                    }

                    if ($hostIsTiered -eq 'Unknown') { if (-not $hostMissing.Contains('TierConfig')) { $hostMissing.Add('TierConfig') }; if (-not $hostMissing.Contains('Capacity')) { $hostMissing.Add('Capacity') } }
                    $currentHostName = $h.Name
                    $hostVMs = if ($vmsByHost.ContainsKey([string]$currentHostName)) { $vmsByHost[[string]$currentHostName] } else { @() }
                    foreach ($vm in $hostVMs) {
                      try {
                        $vmMissing = $false
                        $vmProvisionedGB = [double]$vm.ExtensionData.Config.Hardware.MemoryMB * 1048576.0 / 1000000000.0
                        if ([double]::IsNaN($vmProvisionedGB) -or [double]::IsInfinity($vmProvisionedGB) -or $vmProvisionedGB -le 0) { throw "VM configured memory is missing or invalid." }
                        if ($rangeSelection -notmatch "Real-Time") {
                            $myVmStats = Get-MtatStatCell $vmStatIndex $vm "mem.active.average"
                            $vmMissing = ($null -eq $myVmStats)
                            if ($vmMissing) { $myVmStats = New-MtatStatCell; $myVmStats.Max=0 }
                            $activeGB = [math]::Round(($myVmStats.Max) * 1024.0 / 1000000000.0, 3)
                            # Reference-only companion figure: the plain time-weighted average over the same
                            # window, so the UI can show "peak vs. average" side by side for context.
                            $activeGB_Avg = [math]::Round(((Get-MtatStatMean $myVmStats)) * 1024.0 / 1000000000.0, 3)
                        } else {
                            $activeGB = [math]::Round($vm.ExtensionData.Summary.QuickStats.GuestMemoryUsage * 1048576.0 / 1000000000.0, 3)
                            $activeGB_Avg = $activeGB
                            if ($hostMissing.Contains("Active")) { $vmMissing = $true }
                            $hostActiveGB += $activeGB
                        }

                        # Whether this VM's memory has to stay in DRAM (see Get-VmDramOnlyReasons), kept as
                        # its own column rather than folded into Active_Pct. A full reservation ("Reserve all
                        # guest memory (All locked)") on its own is deliberately not a reason: Broadcom
                        # confirms reserved pages can still be served from either DRAM or NVMe.
                        $dramOnlyReasons = @(Get-VmDramOnlyReasons $vm.ExtensionData)
                        $dramOnly = if ($dramOnlyReasons.Count -gt 0) { "Yes (" + ($dramOnlyReasons -join ", ") + ")" } else { "No" }

                        $extraConfig = $vm.ExtensionData.Config.ExtraConfig
                        $vmTieringDisabled = $false
                        if (($extraConfig | Where-Object { $_.Key -eq "sched.mem.enableTiering" } | Select-Object -First 1).Value -match "(?i)false") { $vmTieringDisabled = $true }

                        $mmuLpOverride = $false
                        if (($extraConfig | Where-Object { $_.Key -eq "monitor_control.disable_mmu_largepages" } | Select-Object -First 1).Value -match "(?i)false") { $mmuLpOverride = $true }

                        $page1GB = "False"
                        $cfg1G = $extraConfig | Where-Object { $_.Key -eq "sched.mem.lpage.enable1GPage" } | Select-Object -First 1
                        if ($null -ne $cfg1G -and $null -ne $cfg1G.Value) { $page1GB = $cfg1G.Value.ToString() }

                        $page2MB = "True (Default)"
                        $cfg2M = $extraConfig | Where-Object { $_.Key -eq "sched.mem.lpage.enable2MPage" } | Select-Object -First 1
                        if ($null -ne $cfg2M -and $null -ne $cfg2M.Value) { $page2MB = $cfg2M.Value.ToString() }

                        # The 4 KB tiering split only applies to VMs that tier; DRAM-only VMs keep large pages.
                        if ($hostIsTiered -eq "Enabled" -and $dramOnlyReasons.Count -eq 0) {
                            $page1GB = "False"
                            $page2MB = if ($mmuLpOverride) { "True (Forced Overwrite)" } else { "False (4KB Tiering Split)" }
                        }

                        # Commit this VM's row only after everything above succeeded. Cluster totals
                        # ($totalActiveGB and $totalActiveGB_Avg) are NOT accumulated here -- see the
                        # per-host commit below for why.
                        $vmResults.Add([PSCustomObject]@{
                            ResourceId = [string]$vm.Id; Host = $currentHostName; VMName = $vm.Name; Provisioned_GB = [math]::Round($vmProvisionedGB, 3); Active_GB = $activeGB
                            Active_Pct = if($vmProvisionedGB -gt 0){[math]::Round(($activeGB/$vmProvisionedGB)*100,1)}else{0}; DRAM_Only = $dramOnly
                            Pages_1GB = $page1GB; Pages_2MB = $page2MB
                            Missing_Metrics = if ($vmMissing) { "Active" } else { "" }
                        })
                      } catch {
                        $failedVmNames.Add("$currentHostName/$($vm.Name)")
                        Write-DebugLog "[analyze] WARNING: skipped VM '$($vm.Name)' on host '$currentHostName' -- data collection failed and it was excluded from results: $(Get-FullExceptionText $_)"
                      }
                    }

                    # Commit this host's contribution only after everything above (including its VMs)
                    # succeeded, so a mid-host failure can't leave the cluster-wide totals partially
                    # updated (e.g. counting a host's DRAM capacity but not its usage).
                    # $totalActiveGB is accumulated from $hostActiveGB (not from the per-VM values
                    # directly) so the cluster-wide total always reconciles with the sum of the
                    # Active_GB column shown in the per-host table below -- in historical mode
                    # $hostActiveGB is the host-level mem.active.average peak (a different vCenter
                    # counter than the per-VM one), and summing THAT independently of this would
                    # silently produce a headline total that doesn't match what the report itself shows
                    # per host. In real-time mode this is a no-op change: $hostActiveGB is itself already
                    # built by summing this same host's VMs' $activeGB just above.
                    $totalCpuMhz_Sum += $cpuTotalMhz
                    $totalDramGB_Sum += $hostDramGB
                    $totalCpuUsageMhz_Sum += $cpuUsageMhz
                    $totalConsumedMemGB_Sum += $hostConsumedMemGB
                    $totalActiveGB += $hostActiveGB
                    # The reference average uses the same counter and the same hosts as the peak (in
                    # Real-Time mode both are this host's VMs' current Active), so the Baseline tab's
                    # peak-vs-average comparison compares like with like. The peak itself is the sum of
                    # each host's own peak: hosts can peak at different times, so it is a conservative
                    # (high) figure for the cluster as a whole.
                    if ($null -eq $hostActiveAvgGB) { $hostActiveAvgGB = $hostActiveGB }
                    $totalActiveGB_Avg += $hostActiveAvgGB

                    $hostResults.Add([PSCustomObject]@{
                        ResourceId   = [string]$h.Id
                        Cluster      = $clusterName
                        HostName     = $currentHostName; Tiering = $hostIsTiered; TierRatioPct = $hostTierRatioPct; CPU_Pct = [math]::Round($hostCpuPct, 1)
                        Physical_RAM = $hostDramGB; Consumed_GB = $hostConsumedMemGB; Active_GB = $hostActiveGB; Active_Pct = if($hostDramGB -gt 0){[math]::Round(($hostActiveGB/$hostDramGB)*100,1)}else{0}
                        Active_Avg_GB = $hostActiveAvgGB; NVMe_GB = $hostNvmeGB; Missing_Metrics = ($hostMissing -join ", "); CPU_MHz = $cpuTotalMhz
                    })
                  } catch {
                    $failedHostNames.Add($h.Name)
                    Write-DebugLog "[analyze] ERROR: host '$($h.Name)' failed entirely and was excluded from cluster totals (still listed below as 'ERROR'): $(Get-FullExceptionText $_)"
                    $hostResults.Add([PSCustomObject]@{
                        ResourceId = [string]$h.Id; Cluster = $clusterName; HostName = $h.Name; Tiering = "ERROR"; TierRatioPct = 0; CPU_Pct = 0
                        Physical_RAM = 0; Consumed_GB = 0; Active_GB = 0; Active_Pct = 0
                    })
                  }
                }

                if ($failedHostNames.Count -gt 0 -or $failedVmNames.Count -gt 0) {
                    Write-DebugLog "[analyze] Completed with $($failedHostNames.Count) failed host(s) [$($failedHostNames -join ', ')] and $($failedVmNames.Count) failed VM(s) [$($failedVmNames -join ', ')] excluded from results."
                } else {
                    Write-DebugLog "[analyze] Completed cleanly: $($hostResults.Count) host(s), $($vmResults.Count) VM(s) returned."
                }

                return @{
                    dram = $totalDramGB_Sum; consumed = [math]::Round($totalConsumedMemGB_Sum, 3); active = [math]::Round($totalActiveGB, 3)
                    activeAvg = [math]::Round($totalActiveGB_Avg, 3)
                    cpu = if ($totalCpuMhz_Sum -gt 0) { [math]::Round(($totalCpuUsageMhz_Sum / $totalCpuMhz_Sum) * 100, 1) } else { 0 }
                    hosts = $hostResults; vms = @($vmResults | Sort-Object Active_Pct -Descending)
                    failedHosts = @($failedHostNames); failedVms = @($failedVmNames)
                    dataNotes = @('Inventory/configuration snapshot: ' + $inventory.CapturedUtc + '. History is collected in bounded batches at the retained resolution. Missing history is not reconstructed.')
                    sourceMeta = @{ inventoryCapturedUtc=$inventory.CapturedUtc; requestedEnd=$collectionContext.End.ToString('o'); collectionRunId=$collectionContext.RunId }
                    series = $seriesPayload
                }
}

# Disk checkpoints contain assessment facts only. Authentication is passed through an anonymous stdin pipe.
function Write-MtatAtomicJson([string]$Path,$Value) {
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    $json=ConvertTo-Json -InputObject $Value -Depth 24 -Compress
    try {
        [IO.File]::WriteAllText($temporary,$json,(New-Object Text.UTF8Encoding($false)))
        if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temporary,$Path,($Path+'.previous'))}else{[IO.File]::Move($temporary,$Path)}
    } finally {if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
}
function Read-MtatJson([string]$Path) {
    try {
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader=New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true)
        try {$json=$reader.ReadToEnd()} finally {$reader.Dispose()}
        return ($json|ConvertFrom-Json -ErrorAction Stop)
    } catch {
        if(Test-Path -LiteralPath ($Path+'.previous')){
            $reader=New-Object IO.StreamReader(($Path+'.previous'),[Text.Encoding]::UTF8)
            try {$json=$reader.ReadToEnd()} finally {$reader.Dispose()}
            return ($json|ConvertFrom-Json -ErrorAction Stop)
        }
        throw
    }
}
function ConvertTo-MtatMap($Value) {
    if($null -eq $Value){return $null}
    if($Value -is [Collections.IDictionary]){$map=@{};foreach($key in $Value.Keys){$map[$key]=ConvertTo-MtatMap $Value[$key]};return ,$map}
    if($Value -is [pscustomobject]){$map=@{};foreach($p in $Value.PSObject.Properties){$map[$p.Name]=ConvertTo-MtatMap $p.Value};return ,$map}
    if($Value -is [Collections.IEnumerable] -and $Value -isnot [string]){$items=@(foreach($v in $Value){ConvertTo-MtatMap $v});return ,$items}
    return $Value
}
function Get-MtatFingerprint($Result) {
    $facts=[ordered]@{
        hosts=@($Result.hosts|Sort-Object ResourceId,HostName|ForEach-Object{[ordered]@{id=[string]$_.ResourceId;name=$_.HostName;dram=$_.Physical_RAM;cpuMHz=$_.CPU_MHz;tier=$_.Tiering;ratio=$_.TierRatioPct;nvme=$_.NVMe_GB}})
        vms=@($Result.vms|Sort-Object ResourceId,Host,VMName|ForEach-Object{[ordered]@{id=[string]$_.ResourceId;name=$_.VMName;host=$_.Host;configured=$_.Provisioned_GB;dramOnly=$_.DRAM_Only;page1=$_.Pages_1GB;page2=$_.Pages_2MB}})
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $facts -Depth 10 -Compress));$sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-MtatJobFolder([string]$Id) {
    if($Id -notmatch '^[a-f0-9]{32}$'){throw 'Invalid job identifier.'}
    return Join-Path (Join-Path $MtatDataRoot 'Jobs') $Id
}
function Get-MtatJobMetadata([string]$Id) {
    $folder=Get-MtatJobFolder $Id;$path=Join-Path $folder 'job.json'
    if(-not (Test-Path -LiteralPath $path)){throw 'Saved job was not found.'}
    $meta=Read-MtatJson $path
    if($meta.schema -ne 1 -or $meta.id -ne $Id){throw 'Unsupported job checkpoint.'}
    if(-not (Test-MtatJobLocked $Id)) {
        $changed=$false;$fingerprints=ConvertTo-MtatMap $meta.fingerprints
        foreach($task in $meta.tasks) {
            if($task.status -eq 'completed'){continue}
            $resultPath=Join-Path $folder ('result_'+$task.index+'.json')
            if(-not(Test-Path -LiteralPath $resultPath)){continue}
            try {
                if((Get-Item -LiteralPath $resultPath).Length -gt 64MB){continue}
                $result=Read-MtatJson $resultPath
                if(-not $result.hosts -or -not (($result.dataNotes -join ' ') -match [regex]::Escape($Id))){continue}
                $identity=$task.source+'|'+$task.server+'|'+$task.clusterId;$fingerprint=Get-MtatFingerprint $result
                if($fingerprints.ContainsKey($identity) -and $fingerprints[$identity] -ne $fingerprint){continue}
                $fingerprints[$identity]=$fingerprint;$task.status='completed';$task.hosts=@($result.hosts).Count;$task.vms=@($result.vms).Count;$task.bytes=(Get-Item -LiteralPath $resultPath).Length;if($task.PSObject.Properties['digest']){$task.digest=(Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash};$task.error=$null;$changed=$true
            } catch {}
        }
        if($changed){$meta.fingerprints=$fingerprints;if(-not @($meta.tasks|Where-Object{$_.status -ne 'completed'}).Count){$meta.status='completed'};$meta.updatedUtc=[datetime]::UtcNow.ToString('o');Write-MtatAtomicJson $path $meta}
    }

    return $meta
}
function Resolve-MtatJobTarget([string]$Key) {
    if($Key -like 'Ops:*'){
        $target=Get-MtatOpsTarget $Key;$session=$target.Session
        return @{key=$Key;source='ops';server=$session.Server;clusterId=$target.Cluster.ResourceId;name=$target.Cluster.Name}
    }
    if(-not $global:ClusterKeyMap -or -not $global:ClusterKeyMap.ContainsKey($Key)){throw 'Reconnect and select a currently accessible cluster.'}
    $serverName=$Key.Split('|')[0];$server=@($global:DefaultVIServers|Where-Object{$_.Name -eq $serverName -and $_.IsConnected})
    if(-not $server.Count){throw 'Reconnect to vCenter before starting or resuming a job.'}
    return @{key=$Key;source='vcenter';server=$serverName;clusterId=[string]$global:ClusterKeyMap[$Key];name=$Key.Substring($Key.IndexOf('|')+1)}
}
function Test-MtatJobLocked([string]$Id) {
    $path=Join-Path (Get-MtatJobFolder $Id) 'owner.lock'
    if(-not(Test-Path -LiteralPath $path)){return $false}
    try{$file=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$file.Dispose();return $false}catch{return $true}
}
function Get-MtatDetachedProcess([string]$Id) {
    if(-not(Test-MtatJobLocked $Id)){return $null}
    $path=Join-Path (Get-MtatJobFolder $Id) 'owner.json'
    try{$owner=Read-MtatJson $path;$p=[Diagnostics.Process]::GetProcessById([int]$owner.pid);if($p.StartTime.ToUniversalTime().Ticks -ne [long]$owner.startTicks){$p.Dispose();return $null};return $p}catch{return $null}
}
function Get-MtatWorkerCode {
    $names=@('Write-Terminal','Write-DebugLog','Get-FullExceptionText','Add-KnownIssueHints','Invoke-WithRetry','Get-NameCounts','Get-VmDramOnlyReasons','Invoke-MtatVCenterAnalysis','Get-MtatFingerprint')
    $names+=@(Get-ChildItem Function:|Where-Object{$_.Name -match '^((New|Set|Test|Get|Read|Merge|ConvertTo|Write)-Mtat)' -and $_.Name -notmatch 'Job|Worker|Fingerprint' -and $_.Name -notin @('Get-MtatOpsTarget') }|ForEach-Object{$_.Name})
    $names+=@(Get-ChildItem Function:|Where-Object{$_.Name -match 'MtatOps'}|ForEach-Object{$_.Name})
    $code='$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"; $global:HasConsole=$false;' + "`n"
    foreach($name in @($names|Select-Object -Unique)){$command=Get-Command $name -CommandType Function -ErrorAction Stop;$code+="function $name {`n"+$command.Definition+"`n}`n"}
    return $code+$script:MtatWorkerEntry
}
function Get-MtatCollectorHash([string]$Code) {
    $sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Code)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Assert-MtatNoDetachedWorker([string]$ExceptId='') {
    $root=Join-Path $MtatDataRoot 'Jobs'
    if(-not(Test-Path -LiteralPath $root)){return}
    foreach($folder in @(Get-ChildItem -LiteralPath $root -Directory)){
        if($folder.Name -eq $ExceptId -or $folder.Name -notmatch '^[a-f0-9]{32}$'){continue}
        $previous=Get-MtatDetachedProcess $folder.Name
        if($previous){$previous.Dispose();throw ('An earlier collection worker is still active (job '+$folder.Name+'). Open the saved job and wait or cancel before starting another.')}
    }
}
function Start-MtatJobProcess($Meta,$Targets) {
    Update-MtatJobs
    if($global:MtatActiveJob){throw 'Another collection job is active. Cancel it or wait for completion.'}
    Assert-MtatNoDetachedWorker $Meta.id
    if(Test-MtatJobLocked $Meta.id){throw 'A previous worker is still finishing this job. Open it and cancel or wait before resuming.'}
    $code=Get-MtatWorkerCode;$hash=Get-MtatCollectorHash $code
    if($Meta.collectorHash -and $Meta.collectorHash -ne $hash){throw 'The collector changed since this checkpoint. Restore its completed results or start a new job.'}
    $Meta.collectorHash=$hash
    $connections=@{};$opsSessions=@{};$opsClusters=@{};$clusterMap=@{};$rebound=@{}
    foreach($target in $Targets){
        $identity=$target.source+'|'+$target.server+'|'+$target.clusterId;$rebound[$identity]=$target.key
        if($target.source -eq 'ops'){
            $o=Get-MtatOpsTarget $target.key;$sid=$o.Cluster.SessionId;$opsSessions[$sid]=$o.Session;$opsClusters[$target.key]=$o.Cluster
        }else{
            if(-not $global:MtatWorkerCredentials -or -not $global:MtatWorkerCredentials.ContainsKey($target.server)){throw 'Reconnect to vCenter to supply credentials for the isolated collection worker.'}
            $auth=$global:MtatWorkerCredentials[$target.server]
            $connections[$target.server]=@{user=$auth.Credential.UserName;pass=$auth.Credential.GetNetworkCredential().Password;requireValidCerts=$auth.RequireValidCerts}
            $clusterMap[$target.key]=$target.clusterId
        }
    }
    foreach($task in $Meta.tasks){$identity=$task.source+'|'+$task.server+'|'+$task.clusterId;if($task.status -ne 'completed'){$task.key=$rebound[$identity]}}
    $folder=Get-MtatJobFolder $Meta.id;[void][IO.Directory]::CreateDirectory($folder)
    $workerPath=Join-Path $MtatDataRoot ('worker_'+$hash+'.ps1')
    if(-not(Test-Path -LiteralPath $workerPath) -or (Get-MtatCollectorHash ([IO.File]::ReadAllText($workerPath))) -ne $hash){
        $temporary=$workerPath+'.tmp';[IO.File]::WriteAllText($temporary,$code,(New-Object Text.UTF8Encoding($true)))
        if(Test-Path -LiteralPath $workerPath){[IO.File]::Replace($temporary,$workerPath,($workerPath+'.previous'))}else{[IO.File]::Move($temporary,$workerPath)}
    }
    $binary=if($PSVersionTable.PSEdition -eq 'Core'){(Get-Command pwsh -ErrorAction Stop).Source}else{Join-Path $PSHOME 'powershell.exe'}
    $pi=New-Object Diagnostics.ProcessStartInfo;$pi.FileName=$binary
    $pi.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$workerPath+'"'
    $pi.UseShellExecute=$false;$pi.CreateNoWindow=$true;$pi.RedirectStandardInput=$true;$pi.RedirectStandardOutput=$true;$pi.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$pi
    $Meta.status='running';$Meta.updatedUtc=[datetime]::UtcNow.ToString('o');$Meta.error=$null
    Write-MtatAtomicJson (Join-Path $folder 'job.json') $Meta
    Remove-Item -LiteralPath (Join-Path $folder 'cancel') -Force -ErrorAction SilentlyContinue
    try{
        [void]$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        $inputValue=@{folder=$folder;meta=$Meta;connections=$connections;opsSessions=$opsSessions;opsClusters=$opsClusters;clusterMap=$clusterMap}
        $inputJson=ConvertTo-Json $inputValue -Depth 32 -Compress
        $inputBytes=[Text.Encoding]::UTF8.GetBytes($inputJson)
        $send=$process.StandardInput.BaseStream.WriteAsync($inputBytes,0,$inputBytes.Length)
        if(-not $send.Wait(10000)){try{$process.Kill()}catch{};throw 'Collection worker startup timed out.'}
        $process.StandardInput.Close();$inputJson=$null;$inputBytes=$null;$inputValue=$null;$connections=$null
        $global:MtatActiveJob=@{Id=$Meta.id;Process=$process;Started=[datetime]::UtcNow;StopAt=$null;StopStatus=$null;Stdout=$stdout;Stderr=$stderr}
        return @{id=$Meta.id;status='running'}
    }catch{
        try{if(-not $process.HasExited){$process.Kill()}}catch{}
        $process.Dispose();$Meta.status='failed';$Meta.error='Could not start the collection worker.';Write-MtatAtomicJson (Join-Path $folder 'job.json') $Meta;throw
    }
}
function New-MtatJob($Payload) {
    Update-MtatJobs
    $keys=@($Payload.clusters|Select-Object -Unique);$ranges=@($Payload.ranges|Select-Object -Unique)
    if(-not $keys.Count -or $keys.Count -gt 500 -or -not $ranges.Count -or $ranges.Count -gt 5){throw 'Choose 1-500 clusters and 1-5 ranges.'}
    if($global:MtatActiveJob){throw ('Job '+$global:MtatActiveJob.Id+' is already active.')}
    Assert-MtatNoDetachedWorker
    $targets=@($keys|ForEach-Object{Resolve-MtatJobTarget ([string]$_)});$tasks=@();$i=0
    foreach($target in $targets){foreach($range in $ranges){
        $allowed=if($target.source -eq 'ops'){@('Latest Ops Sample','Past 24 Hours','Past 7 Days','Past 30 Days')}else{@('Real-Time Snapshot','Past 24 Hours','Past 7 Days','Past 30 Days','Past 365 Days')}
        if($range -notin $allowed){throw ('Range '+$range+' is not available for '+$target.source+'.')}
        $tasks+=@{index=$i++;key=$target.key;source=$target.source;server=$target.server;clusterId=$target.clusterId;name=$target.name;range=[string]$range;status='pending';hosts=0;vms=0;bytes=0;digest=$null;error=$null}
    }}
    $meta=@{schema=1;id=[guid]::NewGuid().ToString('N');appVersion=$MtatAppVersion;createdUtc=[datetime]::UtcNow.ToString('o');endUtc=[datetime]::UtcNow.ToString('o');updatedUtc=[datetime]::UtcNow.ToString('o');status='pending';tasks=$tasks;fingerprints=@{};collectorHash=$null;error=$null}
    return Start-MtatJobProcess $meta $targets
}
function Stop-MtatJob([string]$Id,[string]$Reason='cancelled') {
    $job=$global:MtatActiveJob
    if (-not $job) { $p=Get-MtatDetachedProcess $Id; if($p){$job=@{Id=$Id;Process=$p;Started=[datetime]::UtcNow;StopAt=$null;StopStatus=$null};$global:MtatActiveJob=$job} }
    if(-not $job -or $job.Id -ne $Id){throw 'This job is not currently running.'}
    if(-not $job.StopAt){[IO.File]::WriteAllText((Join-Path (Get-MtatJobFolder $Id) 'cancel'),'cancel');$job.StopAt=[datetime]::UtcNow;$job.StopStatus=$Reason}
    return @{id=$Id;status='cancelling'}
}
function Update-MtatJobs {
    $job=$global:MtatActiveJob;if(-not $job){return}
    if(-not $job.StopAt -and ([datetime]::UtcNow-$job.Started).TotalMinutes -ge 120){[void](Stop-MtatJob $job.Id 'timedOut')}
    try {$job.Process.Refresh();if(-not $job.StopAt -and -not $job.Process.HasExited -and $job.Process.PrivateMemorySize64 -gt 2GB){[void](Stop-MtatJob $job.Id 'memoryLimit')}}catch{}
    if($job.StopAt -and -not $job.Process.HasExited -and ([datetime]::UtcNow-$job.StopAt).TotalSeconds -ge 10){try{$job.Process.Kill()}catch{}}
    if(-not $job.Process.HasExited){return}
    try{
        $meta=Get-MtatJobMetadata $job.Id
        if($job.StopStatus -and @($meta.tasks|Where-Object{$_.status -ne 'completed'}).Count){$meta.status=$job.StopStatus;$meta.error=if($job.StopStatus -eq 'timedOut'){'Execution limit reached; completed results are recoverable.'}elseif($job.StopStatus -eq 'memoryLimit'){'Worker memory budget reached; completed results are recoverable. Resume the remaining tasks in a fresh worker.'}else{'Cancelled; completed results are recoverable.'}}
        elseif($meta.status -eq 'running'){$meta.status='interrupted';$meta.error='The worker exited unexpectedly. Completed results were preserved; reconnect to resume.'}
        $meta.updatedUtc=[datetime]::UtcNow.ToString('o');Write-MtatAtomicJson (Join-Path (Get-MtatJobFolder $job.Id) 'job.json') $meta
        # stderr may contain SDK diagnostics. Do not persist it or authentication input automatically.
        Write-DebugLog "[job] $($job.Id) ended: $($meta.status); worker exit=$($job.Process.ExitCode)."
    } finally {$job.Process.Dispose();$global:MtatActiveJob=$null}
}
function Get-MtatJobStatus([string]$Id) {
    Update-MtatJobs;$meta=Get-MtatJobMetadata $Id
    if($global:MtatActiveJob -and $global:MtatActiveJob.Id -eq $Id -and -not $global:MtatActiveJob.Process.HasExited -and $meta.status -notin @('running','runningDetached','cancelling')){
        $meta.status=if($global:MtatActiveJob.StopAt){'cancelling'}else{'running'}
        $meta.error='Finalizing collection worker; completed results are already saved.'
    }
    if($meta.status -eq 'running' -and (-not $global:MtatActiveJob -or $global:MtatActiveJob.Id -ne $Id)){if(Test-MtatJobLocked $Id){$meta.status='runningDetached';$meta.error='The previous worker is still collecting. Wait or cancel before resuming.'}else{$meta.status='interrupted';$meta.error='Engine restarted. Completed results are available; reconnect to resume.'}}
    $path=Join-Path (Get-MtatJobFolder $Id) 'progress.json';$progress=$null
    if(Test-Path -LiteralPath $path){try{$progress=Read-MtatJson $path}catch{}}
    return @{id=$Id;status=$meta.status;createdUtc=$meta.createdUtc;updatedUtc=$meta.updatedUtc;message=$meta.error;tasks=@($meta.tasks|Select-Object index,source,server,clusterId,name,range,status,hosts,vms,bytes,error);progress=$progress}
}
function Resume-MtatJob($Payload) {
    $meta=Get-MtatJobMetadata ([string]$Payload.id)
    if($meta.status -eq 'completed'){throw 'This job is already complete. Open its saved results.'}
    $targets=@();$used=@{}
    foreach($task in $meta.tasks){
        if($task.status -eq 'completed'){continue}
        $identity=$task.source+'|'+$task.server+'|'+$task.clusterId
        if($used.ContainsKey($identity)){continue}
        $match=$null
        foreach($key in @($Payload.clusters)){
            try{$candidate=Resolve-MtatJobTarget ([string]$key)}catch{continue}
            if($candidate.source -eq $task.source -and $candidate.server -eq $task.server -and $candidate.clusterId -eq $task.clusterId){$match=$candidate;break}
        }
        if(-not $match){throw ('Reconnect to '+$task.server+' and rediscover cluster '+$task.name+' before resuming.')}
        $targets+=$match;$used[$identity]=$true;$task.status='pending';$task.error=$null
    }
    return Start-MtatJobProcess $meta $targets
}
function Get-MtatJobResult([string]$Id,[int]$Index) {
    $meta=Get-MtatJobMetadata $Id;$task=@($meta.tasks|Where-Object{$_.index -eq $Index})
    if($task.Count -ne 1 -or $task[0].status -ne 'completed'){throw 'This task has no completed checkpoint.'}
    $path=Join-Path (Get-MtatJobFolder $Id) ('result_'+$Index+'.json')
    if(-not (Test-Path -LiteralPath $path)){throw 'The result checkpoint is missing.'}
    if((Get-Item -LiteralPath $path).Length -gt 32MB){throw 'Checkpoint exceeds the browser loading budget. Use Download checkpoint for offline processing.'}
    if($task[0].digest -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $task[0].digest){throw 'Checkpoint integrity check failed.'}
    return Read-MtatJson $path
}
$script:MtatWorkerEntry = @'
[Console]::InputEncoding=New-Object Text.UTF8Encoding($false)
$inputJson=[Console]::In.ReadToEnd()
$config=ConvertTo-MtatMap ($inputJson|ConvertFrom-Json);$inputJson=$null
$folder=$config.folder;$meta=$config.meta;$LogFilePath=Join-Path $folder 'worker.log'
$global:MtatProgressPath=Join-Path $folder 'progress.json';$global:MtatCancelPath=Join-Path $folder 'cancel'
$owned=New-Object 'System.Collections.Generic.List[object]';$ownerLock=$null;$certPolicy=@{};$connectionErrors=@{}
$global:MtatDeadlineUtc=[datetime]::UtcNow.AddHours(2)
try {
    $ownerLock=[IO.File]::Open((Join-Path $folder 'owner.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    Write-MtatAtomicJson (Join-Path $folder 'owner.json') @{pid=$PID;startTicks=[Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks}
    $global:ClusterKeyMap=$config.clusterMap;$global:MtatOpsSessions=$config.opsSessions;$global:MtatOpsClusters=$config.opsClusters
    $global:MtatCollectionContext=New-MtatCollectionContext $meta.id ([datetime]$meta.endUtc)
    if($config.connections.Count){
        Import-Module VMware.VimAutomation.Core -ErrorAction Stop -WarningAction SilentlyContinue
        foreach($serverName in $config.connections.Keys){
            Test-MtatCollectionCancellation;$auth=$config.connections[$serverName]
            $cert=if($auth.requireValidCerts){'Fail'}else{'Ignore'};$certPolicy[$serverName]=$cert
            Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Multiple -InvalidCertificateAction $cert -ParticipateInCEIP $false -WebOperationTimeoutSeconds 120 -Confirm:$false|Out-Null
            $secure=ConvertTo-SecureString ([string]$auth.pass) -AsPlainText -Force;$auth.pass=$null
            $credential=New-Object Management.Automation.PSCredential([string]$auth.user,$secure)
            try {foreach($connection in @(Connect-VIServer -Server $serverName -Credential $credential -ErrorAction Stop -WarningAction SilentlyContinue)){$owned.Add($connection)}} catch {$connectionErrors[$serverName]='Could not establish the collection session. Reconnect and resume this server.';Write-DebugLog ('[connection] Worker session failed for '+$serverName+'.')}
        }
    }
    $config.connections=$null
    foreach($task in $meta.tasks){
        if($task.status -eq 'completed'){continue}
        Test-MtatCollectionCancellation;$task.status='running';$task.error=$null
        Set-MtatCollectionProgress ($task.name+' / '+$task.range)
        Write-MtatAtomicJson (Join-Path $folder 'job.json') $meta
        try {
            if ($task.source -eq 'vcenter' -and $connectionErrors.ContainsKey($task.server)) {throw $connectionErrors[$task.server]}
            if ($task.source -eq 'vcenter') {Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction $certPolicy[$task.server] -Confirm:$false | Out-Null}
            $result=if($task.source -eq 'ops'){Invoke-MtatOpsAnalysis $task.key $task.range}else{Invoke-MtatVCenterAnalysis $task.key $task.range $meta.id}
            Test-MtatCollectionCancellation
            $identity=$task.source+'|'+$task.server+'|'+$task.clusterId;$fingerprint=Get-MtatFingerprint $result
            if($meta.fingerprints.ContainsKey($identity) -and $meta.fingerprints[$identity] -ne $fingerprint){throw 'Inventory/configuration changed since the earlier checkpoint. Start a fresh assessment for this cluster; completed checkpoints remain available.'}
            $meta.fingerprints[$identity]=$fingerprint
            $result.dataNotes=@($result.dataNotes)+@('Saved job '+$meta.id+'; assessment started '+$meta.createdUtc+'. Saved results describe that run, not a fresh live snapshot.')
            $resultPath=Join-Path $folder ('result_'+$task.index+'.json')
            Write-MtatAtomicJson $resultPath $result
            $task.hosts=@($result.hosts).Count;$task.vms=@($result.vms).Count;$task.bytes=(Get-Item -LiteralPath $resultPath).Length;$task.digest=(Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash;$task.status='completed'
            $result=$null
        } catch {
            if(Test-Path -LiteralPath $global:MtatCancelPath){throw [OperationCanceledException]::new('Cancelled.')}
            $task.status='failed';$task.error=$_.Exception.Message;if($task.source -eq 'vcenter' -and $task.error -match '(?i)timed out|timeout|not authenticated|unauthorized|forbidden|connection.*(closed|refused|reset)|name.*resolution'){$connectionErrors[$task.server]='Server collection stopped after a transport/authentication failure. Reconnect and resume.'};Write-DebugLog "[job] Task $($task.index) failed: $($task.error)"
        }
        $meta.updatedUtc=[datetime]::UtcNow.ToString('o');Write-MtatAtomicJson (Join-Path $folder 'job.json') $meta
    }
    $meta.status=if(@($meta.tasks|Where-Object{$_.status -ne 'completed'}).Count){'partial'}else{'completed'}
} catch {
    $meta.status=if(Test-Path -LiteralPath $global:MtatCancelPath){'cancelled'}else{'failed'};$meta.error=$_.Exception.Message
} finally {
    foreach($connection in $owned){try{Disconnect-VIServer -Server $connection -Confirm:$false -ErrorAction SilentlyContinue|Out-Null}catch{}}
    $meta.updatedUtc=[datetime]::UtcNow.ToString('o');Write-MtatAtomicJson (Join-Path $folder 'job.json') $meta
    if($ownerLock){$ownerLock.Dispose()}
}
'@

function Send-JsonResponse ($Response, $Object, [switch]$AllowCrossOrigin) {
    try {
        [string]$jsonString = ConvertTo-Json -InputObject $Object -Depth 12 -Compress
        if ([string]::IsNullOrEmpty($jsonString) -or $null -eq $jsonString) {
            $jsonString = '{"error":"Internal engine serialization failure"}'
        }
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
        if ($AllowCrossOrigin) {
            # The splash screen is a file:// origin page polling this endpoint across origins --
            # a plain fetch() would otherwise be blocked/opaque without this header.
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        }
        $Response.ContentType = "application/json; charset=utf-8"
        $Response.ContentLength64 = $buffer.Length
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $Response.OutputStream.Flush()
    } catch {
        Write-DebugLog "[-] Fatal anomaly inside response coordinator: $(Get-FullExceptionText $_)"
    } finally {
        if ($null -ne $Response) { try { $Response.Close() } catch {} }
    }
}

# ==========================================
# --- BRANDING AND LOGO PROFILE ASSIGNMENT -
# ==========================================
$LogoBase64 = "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CcpLElSUJigvLaW0JEFpSYJoJILjOIM/xhis7Q+A+D6+79OXStHV1UNndxcdXd10dvfQ3t1Dc3cvqb4UoUiYqmiYRCRCeFhvkjz5NfBN4KGmxoZMPk8sIiIiIiITowCIiIiIiMghLllXfzi5QMhzgHLyfJ0/UN7KtxbrW7z+AEe2P9PDYvEtWCxYMAYMZvC/HccQchxcx8FxcqWwHGOAgUbneeUD7cDPgC81NTbszfsIRERERERkUigAIiIiIiJSIJJ19TOB15ELhBwJVAQ7okPKbuBR4I/AFU2NDb0Bj0dERERERCZIARARERERkQKTrKsvAZ4LXAicCiwKdkTT2lrg38BfgFuaGhvSwQ5HREREREQmiwIgIiIiIiIFKllXHwXqgDPI9Qk5I8jxTCO9wC3ATcB/mhobGgMej4iIiIiITAEFQEREREREClyyrt4BaoDZwPnAC4H6QAcVjJuBq4BbgX1NjQ0tAY9HRERERESmkAIgIiIiIiJFKFlXXwE8E3gtcBoQAUJBjmmSZchlelwL/A74p/p6iIiIiIgUFwVARERERESKXLKuvhR4FnABcBi5bJFqoIpDIyiSBlr6f/YBDwE3ANc1NTYEOS4REREREQmQAiAiIiIiIjIoWVdvgCS5QMgKYCmwAFhMrpl6eWCDG9IMbAK29v9sINfM/PGmxoYtAY5LRERERESmEQVARERERERkVMm6+hpgHjAXmE8uGDILmNn/U9v/UzmJp20hF+jY0/+zF9jFUOBjO7CzqbGhfRLPKSIiIiIiBUQBEBEREREROSDJuvoQEO3/iQz77wi5slkLyAVMavr/tzC5UlphwAWy5Hp0DPx3ilyQYyCw0UGurFW6/39LDfz/TY0NXj5+RxERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERGZ9kzQAxARERGR/ErW1RtgHjADqOz/iQOR/h8XyAKZ/p8uoK3/Z19TY8O2PA9ZREREpplkXf1MoBaoAiqAMnLXEeH+Hwfw+n/SQDfQA3QArUALsLupsSHvYxcRkeKhAIiIiIhIEUjW1S8ATgaOBJaRC4DUkpuwqCAXAAk9xaFZchMW7f0/LcBO4HHgYeDOpsaG3VM9fhEREQlW/7XEKcDhwBJgLlBNbiFFBVBCLgDiPMXhPrngRw9DCytagd3AFmA98Chwf1NjQ2YKfw0RESkyCoCIiMi4JevqjwZ+RO7Gxk7w6VygCXh3U2PDzomObTySdfUfB55P7gZsomLAp5saG35/kGM5Dvg+uddhoq/lVHGAXcD7mhobHj/Qg5N19acAPyF3oztRLvBEU2PDyyfhucYlWVf/beA0cqsWJyoBvKGpseGOSXiucUvW1YeAFwAvBVaTm6SoYHKuAX36M0KAB4GrmxobrpyE5z0gybr6NwFvJZepMhVs/3OngF6GVqzuJDdZsw54uKmxITvREyXr6pPANeQCTgfDBf4LXNbU2LB9ouMZj2Rd/d/JBdIO5nPVITcJ9rmmxoabJnVgY0jW1f8JWMrk/H1PJ4ZcoPITTY0Ntz/dTsm6+l+TC4Ye6O/vAK1NjQ1nH+wAk3X1fwCWH8S58ykKfLepseFHB3pgsq5+HvAp4Fim7nccWE2fBjrJfQ7vBbYCG8l9Xz45ReceVbKuPgp8FzieXAD9QLjAQ8DrD2YCPFlXPwP4NHDSQZx7gAPsbGpsuPAgj39aybr6VcAfOPDPeAe4pamx4X2TPabxSNbV1wAvAy4EVpDLHi3jqYMcE9FF7vOrjdx32bXA9U2NDV2TfB4RESkyT7XKT0RE5OmUAScyeQH0I4BbgB9O0vM9rf4JideSW602WWZN4NhycpMD091ucqv5DkYlsHLyhsLSZF39s5oaG66fxOd8Ssm6+lOBi4D5k/i0lZP4XKPqnwR6J/AGJvY+HY1DLqBSTW5C5EXJuvqvAV8BftnU2LB3is67vwXA0Xk619PxknX1m4CbgauAO5oaG9IH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
"

$CleanLogo = $LogoBase64 -replace "[\r\n\s]", ""

if ($CleanLogo -and $CleanLogo -ne "PASTE_YOUR_BASE64_STRING_HERE") {
    $LogoHtmlInjection = "<img src='data:image/png;base64,$CleanLogo' />"
} else {
    $LogoHtmlInjection = ""
}

# --- PRE-FLIGHT ENVIRONMENT CHECKS (PowerShell host + PowerCLI module) -----
# Purely informational for the PowerShell host itself -- the script has no hard PS version
# requirement beyond what PowerCLI already demands to load in the first place -- but this has
# repeatedly been the first thing worth checking when troubleshooting a cryptic PowerCLI failure,
# so it's captured up front rather than only reconstructable after the fact from scattered clues.
Write-DebugLog "[+] Host PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition)) on $(if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { 'Win32NT (Windows PowerShell)' })"

try {
    $powerCliInstalled = Get-Module -ListAvailable -Name VMware.VimAutomation.Core
    if ($null -eq $powerCliInstalled) {
        throw 'PowerCLI is not installed. Ops connections and offline imports remain available. Install VMware.PowerCLI to use direct vCenter connections.'
    }
    $powerCliVersion = ($powerCliInstalled | Sort-Object Version -Descending | Select-Object -First 1).Version
    Write-DebugLog "[+] PowerCLI validated successfully (VMware.VimAutomation.Core version $powerCliVersion)."

    # Non-blocking on purpose: exact PowerCLI/vCenter compatibility boundaries aren't something this
    # tool can verify with confidence, so this only flags a version old enough that it's clearly
    # worth a look -- not a hard requirement that could incorrectly block a perfectly fine install.
    # Directly motivated by a real troubleshooting session where "Sequence contains no elements"
    # from Get-VM turned out to be an unrelated malformed VM, but an outdated PowerCLI was a
    # reasonable first suspect that's now worth ruling in/out immediately instead of mid-investigation.
    if ($null -ne $powerCliVersion -and $powerCliVersion.Major -lt 12) {
        Write-DebugLog "[!] WARNING: Installed PowerCLI ($powerCliVersion) is quite old. Memory Tiering itself requires vSphere 8.0 Update 3+, and an outdated PowerCLI is a common source of cryptic errors against newer vCenter/ESXi builds. If anything looks wrong, try: Update-Module VMware.PowerCLI -Force"
    }

    # -InvalidCertificateAction Ignore is a deliberate tradeoff, not an oversight: most vSphere
    # environments run vCenter/ESXi with self-signed certificates, and refusing those by default
    # would break this tool's core "just connect and assess" workflow for the majority of users.
    # This does mean TLS certificate validation is skipped for every vCenter connection made in this
    # session (a MITM risk on whatever network path this tool's traffic takes) -- acceptable for an
    # internal assessment tool, but worth knowing if this is ever deployed somewhere that matters.
    # Bounded batches use a 120-second per-operation timeout and limited retries.
    Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Multiple -InvalidCertificateAction Ignore -ParticipateInCEIP $false -WebOperationTimeoutSeconds 120 -Confirm:$false | Out-Null
} catch {
    Write-DebugLog "[-] Pre-flight initialization failed: $(Get-FullExceptionText $_)"
}

# --- BACKGROUND VERSION-CHECK JOB (best-effort, non-blocking) --------------
# PowerCLI only -- an outdated PowerCLI is a real, recurring source of cryptic errors against
# newer vCenter/ESXi builds (see Add-KnownIssueHints below), so knowing a newer one exists has
# concrete value. The host PowerShell version is purely informational either way (nothing in this
# tool requires PS7+), so it isn't checked or displayed here to avoid the added complexity/noise
# for no real benefit.
# Kicked off now so it runs concurrently with the rest of startup, before the HTTP listener/UI
# are even up -- by the time a browser reaches the splash screen and starts polling, this is
# often already finished or close to it. Runs in a separate PowerShell process (Start-Job), so
# even if the lookup hangs, it can never delay or block the engine coming up. Environments with no
# internet egress (common on isolated vSphere management networks) simply time out below, and the
# UI shows "unable to check" -- this is expected and never treated as an error.
$currentPowerCliVersionString = if ($null -ne $powerCliVersion) { $powerCliVersion.ToString() } else { "Unknown" }

$global:LatestVersionInfo = [PSCustomObject]@{
    CurrentPowerCli = $currentPowerCliVersionString
    LatestPowerCli  = $null
    Status          = "checking"
}

$versionCheckJob = $null
$versionCheckJobStartTime = Get-Date
try {
    $versionCheckJob = Start-Job -ScriptBlock {
        $jobResult = [PSCustomObject]@{
            LatestPowerCli = $null
        }

        try {
            $module = Find-Module -Name VMware.PowerCLI -Repository PSGallery -ErrorAction Stop
            if ($module) {
                $jobResult.LatestPowerCli = $module.Version.ToString()
            }
        } catch {
            # Best-effort: no internet, DNS failure, corporate proxy blocking egress, PSGallery
            # being unreachable, etc. are all expected, normal outcomes here -- not logged as errors.
        }

        return $jobResult
    }
    Write-DebugLog "[+] Background version-check job started (PID job id $($versionCheckJob.Id))."
} catch {
    Write-DebugLog "[-] Could not start background version-check job (non-fatal): $(Get-FullExceptionText $_)"
    $global:LatestVersionInfo.Status = "done"
}

function Update-VersionCheckJobStatus {
    # Non-blocking: only acts if the job already finished, or has been running long enough that
    # it's not worth waiting on any longer. Safe to call frequently from the request loop.
    if ($null -eq $script:versionCheckJob) { return }

    if ($script:versionCheckJob.State -in @('Completed', 'Failed', 'Stopped')) {
        try {
            $jobResult = Receive-Job -Job $script:versionCheckJob -ErrorAction Stop
            if ($jobResult) {
                $global:LatestVersionInfo.LatestPowerCli = $jobResult.LatestPowerCli
            }
            Write-DebugLog "[+] Background version-check finished. Latest PowerCLI: $($jobResult.LatestPowerCli)"
        } catch {
            Write-DebugLog "[-] Background version-check job ended without usable results (non-fatal): $(Get-FullExceptionText $_)"
        } finally {
            try { Remove-Job -Job $script:versionCheckJob -Force -ErrorAction SilentlyContinue } catch {}
            $script:versionCheckJob = $null
            $global:LatestVersionInfo.Status = "done"
        }
    } elseif (((Get-Date) - $script:versionCheckJobStartTime).TotalSeconds -gt 15) {
        Write-DebugLog "[!] Background version-check exceeded 15s without finishing -- giving up (likely no internet egress from this host)."
        try { Stop-Job -Job $script:versionCheckJob -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job -Job $script:versionCheckJob -Force -ErrorAction SilentlyContinue } catch {}
        $script:versionCheckJob = $null
        $global:LatestVersionInfo.Status = "done"
    }
}

$url = "http://127.0.0.1:$targetPort/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)

try {
    $listener.Start()
    Write-DebugLog "[+] HTTP daemon bound to network port $targetPort successfully."
} catch {
    Write-DebugLog "[-] CRITICAL: Port $targetPort bind failed. $(Get-FullExceptionText $_)"
    exit
}

Write-Terminal "===========================================================" "Cyan"
Write-Terminal "[*] Engine is LIVE and ready!" "Green"
Write-Terminal "[*] Launching MTAT interface in your default web browser..." "Green"
Write-Terminal "    (If it does not open automatically, browse to: $url)" "Yellow"
Write-Terminal "===========================================================" "Cyan"
Write-Terminal "Please leave this window open while using the tool. Press Ctrl+C to exit." "DarkGray"

# ==========================================
# --- LITERAL FRONT-END INTERFACE (HTML5) --
# ==========================================
$htmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script>
        // Runs synchronously before first paint so there's no flash of the wrong theme.
        // Precedence: an explicit in-app choice (localStorage) beats the OS preference,
        // which is otherwise honored via the plain @media (prefers-color-scheme) rules.
        (function() {
            try {
                var stored = localStorage.getItem('mtatTheme');
                if (stored === 'dark' || stored === 'light') { document.documentElement.setAttribute('data-theme', stored); }
            } catch (e) { /* localStorage unavailable (e.g. private mode) -- falls back to OS preference */ }
        })();
    </script>
    <title>Memory Tiering Assessment Tool v3.3</title>
    <style>
        /* ==================================================================
           THEME TOKENS -- every color in this app is one of these roles.
           Light values are byte-for-byte the tool's original hardcoded
           hex values (zero visual change in light mode). Dark values are
           deliberately NOT a blind invert: solid button/badge fills that
           already contrast against white text are left unchanged (they
           don't depend on the page background), while anything rendered
           as text/border directly against a surface is re-picked for
           contrast against that surface's dark counterpart. See the
           in-app toggle script (search "applyStoredTheme") for how the
           attribute below gets set; OS preference is honored until the
           user picks explicitly, then localStorage wins from then on.
           ================================================================== */
        :root {
            --surface-page:   #f8f9fa;  --surface-card:   #ffffff;
            --surface-alt:    #f1f3f5;  --surface-alt-2:  #fafbfc;
            --surface-stripe: #fafafa;  --surface-th:     #f5f6f7;
            --surface-hover:  #e9ecef;

            --text-primary:   #212529;  --text-secondary: #495057;  --text-muted: #6c757d;
            --border:         #dee2e6;  --border-input:   #ced4da;

            /* Solid fills (button/badge backgrounds paired with white text) --
               already contrast well against white in both themes, so these
               intentionally do NOT change under the dark overrides below. */
            --fill-accent:    #0078D7;  --fill-accent-hover:  #0056b3;
            --fill-success:   #167c41;  --fill-success-hover: #116230;
            --fill-orange:    #e67e22;  --fill-orange-hover:  #d35400;
            --fill-danger:    #dc3545;  --fill-danger-hover:  #c82333;
            --fill-disabled:  #a0a0a0;

            /* Text-on-surface (links, titles, figures rendered directly on a
               plain card/page background -- these DO need brightening in
               dark mode, since they no longer sit on white). */
            --text-accent:       #0078D7;  --text-accent-hover: #0056b3;  --text-accent-soft: #1d6fa5;
            --text-success:      #167c41;  --text-success-soft: #155724;
            --text-warning-soft: #856404;
            --text-danger-soft:  #721c24;  --text-danger-strong: #b22222;
            --text-info-soft:    #0c5460;

            /* Tinted soft-badge / callout pairs (bg + matching text + border) */
            --soft-bg-accent:  #e8f4fd;  --soft-border-accent:  #b3d7f7;
            --soft-bg-success: #d4edda;
            --soft-bg-warning: #fff3cd;  --soft-border-warning: #ffeeba;
            --soft-bg-info:    #d1ecf1;
            --soft-bg-danger:  #f8d7da;  --soft-border-danger:  #f5c6cb;

            --panel-assess-bg: #f0f7ff;  --panel-assess-border: #b8daff;
            --panel-sim-bg:    #f4fbf7;  --panel-sim-border:    #c3e6cb;
            --banner-savings-bg: #e6f4ea;

            --panel-teal-bg: #e0f2f1;    --panel-teal-border: #b2dfdb;
            --text-teal-title: #00695c;  --text-teal-desc: #004d40;
            --text-teal-value: #00796b;  --border-teal-value: #80cbc4;

            --shadow-card:  0 4px 12px rgba(0,0,0,0.05);
            --shadow-block: 0 2px 5px rgba(0,0,0,0.02);
            --shadow-toast: 0 4px 14px rgba(0,0,0,0.15);
            --shadow-value: 0 2px 4px rgba(0,0,0,0.05);
        }

        @media (prefers-color-scheme: dark) {
            html:not([data-theme="light"]) {
                --surface-page:   #14161a;  --surface-card:   #1f2227;
                --surface-alt:    #191b20;  --surface-alt-2:  #22252a;
                --surface-stripe: #242731;  --surface-th:     #262a30;
                --surface-hover:  #2c3038;

                --text-primary:   #e8eaed;  --text-secondary: #adb3ba;  --text-muted: #868c94;
                --border:         #33383f;  --border-input:   #3a4048;

                --text-accent:       #4aa3f0;  --text-accent-hover: #6bb6f5;  --text-accent-soft: #7cc0f5;
                --text-success:      #3ecf7a;  --text-success-soft: #6fe3a0;
                --text-warning-soft: #e0b23c;
                --text-danger-soft:  #f19a9d;  --text-danger-strong: #e57373;
                --text-info-soft:    #7fd4e8;

                --soft-bg-accent:  #1c2c3d;  --soft-border-accent:  #2f4a63;
                --soft-bg-success: #163828;
                --soft-bg-warning: #3a2f10;  --soft-border-warning: #5c4a1a;
                --soft-bg-info:    #123842;
                --soft-bg-danger:  #3a1e20;  --soft-border-danger:  #5c2c30;

                --panel-assess-bg: #16202e;  --panel-assess-border: #2c445e;
                --panel-sim-bg:    #16201c;  --panel-sim-border:    #2c4a3a;
                --banner-savings-bg: #17301f;

                --panel-teal-bg: #12292a;    --panel-teal-border: #295452;
                --text-teal-title: #4fd1c0;  --text-teal-desc: #9fd8cf;
                --text-teal-value: #5fe0cd;  --border-teal-value: #2f5c56;

                --shadow-card:  0 4px 12px rgba(0,0,0,0.4);
                --shadow-block: 0 2px 5px rgba(0,0,0,0.3);
                --shadow-toast: 0 4px 14px rgba(0,0,0,0.5);
                --shadow-value: 0 2px 4px rgba(0,0,0,0.4);
            }
        }
        html[data-theme="dark"] {
            --surface-page:   #14161a;  --surface-card:   #1f2227;
            --surface-alt:    #191b20;  --surface-alt-2:  #22252a;
            --surface-stripe: #242731;  --surface-th:     #262a30;
            --surface-hover:  #2c3038;

            --text-primary:   #e8eaed;  --text-secondary: #adb3ba;  --text-muted: #868c94;
            --border:         #33383f;  --border-input:   #3a4048;

            --text-accent:       #4aa3f0;  --text-accent-hover: #6bb6f5;  --text-accent-soft: #7cc0f5;
            --text-success:      #3ecf7a;  --text-success-soft: #6fe3a0;
            --text-warning-soft: #e0b23c;
            --text-danger-soft:  #f19a9d;  --text-danger-strong: #e57373;
            --text-info-soft:    #7fd4e8;

            --soft-bg-accent:  #1c2c3d;  --soft-border-accent:  #2f4a63;
            --soft-bg-success: #163828;
            --soft-bg-warning: #3a2f10;  --soft-border-warning: #5c4a1a;
            --soft-bg-info:    #123842;
            --soft-bg-danger:  #3a1e20;  --soft-border-danger:  #5c2c30;

            --panel-assess-bg: #16202e;  --panel-assess-border: #2c445e;
            --panel-sim-bg:    #16201c;  --panel-sim-border:    #2c4a3a;
            --banner-savings-bg: #17301f;

            --panel-teal-bg: #12292a;    --panel-teal-border: #295452;
            --text-teal-title: #4fd1c0;  --text-teal-desc: #9fd8cf;
            --text-teal-value: #5fe0cd;  --border-teal-value: #2f5c56;

            --shadow-card:  0 4px 12px rgba(0,0,0,0.4);
            --shadow-block: 0 2px 5px rgba(0,0,0,0.3);
            --shadow-toast: 0 4px 14px rgba(0,0,0,0.5);
            --shadow-value: 0 2px 4px rgba(0,0,0,0.4);
        }

        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: var(--surface-page); color: var(--text-primary); padding: 30px; margin: 0; transition: background-color 0.15s ease, color 0.15s ease; }
        /* Fluid up to 1400px: fills smaller screens edge to edge (border-box, so padding never pushes it
           past the viewport) and stops growing on large ones. Anything inside that is still wider than
           the window (a wide table, a long chart) scrolls inside its own tab instead of the whole page. */
        .container { box-sizing: border-box; width: 100%; max-width: 1400px; background: var(--surface-card); padding: 30px; border-radius: 8px; box-shadow: var(--shadow-card); margin: 0 auto; transition: background-color 0.15s ease; }
        .tab-content { max-width: 100%; overflow-x: auto; }
        /* "Hide real names" switch: shown next to Process Import and above the export buttons (kept in sync) */
        .obf-card { display: inline-flex; align-items: center; gap: 12px; padding: 8px 14px; border: 2px solid var(--border-input); border-radius: 8px; background: var(--surface-alt); cursor: pointer; user-select: none; transition: border-color 0.15s ease, background-color 0.15s ease; }
        .obf-card:hover { border-color: var(--text-accent); }
        .obf-card .obf-input { position: absolute; opacity: 0; width: 0; height: 0; }
        .obf-slider { position: relative; width: 44px; height: 24px; border-radius: 999px; background: var(--fill-disabled); flex: none; transition: background-color 0.15s ease; }
        .obf-slider::after { content: ""; position: absolute; top: 3px; left: 3px; width: 18px; height: 18px; border-radius: 50%; background: #ffffff; box-shadow: 0 1px 3px rgba(0,0,0,0.35); transition: transform 0.15s ease; }
        .obf-card .obf-input:checked + .obf-slider { background: var(--fill-success); }
        .obf-card .obf-input:checked + .obf-slider::after { transform: translateX(20px); }
        .obf-card .obf-input:focus-visible + .obf-slider { outline: 2px solid var(--text-accent); outline-offset: 2px; }
        .obf-card-text { display: flex; flex-direction: column; line-height: 1.3; }
        .obf-card-title { font-size: 14px; font-weight: bold; color: var(--text-primary); }
        .obf-card-sub { font-size: 11.5px; color: var(--text-muted); }
        .obf-state { display: inline-block; margin-left: 6px; font-size: 10.5px; font-weight: 800; letter-spacing: 0.05em; padding: 1px 7px; border-radius: 999px; background: var(--fill-disabled); color: #ffffff; vertical-align: 1px; }
        .obf-card.is-on { border-color: var(--fill-success); background: var(--soft-bg-success); }
        .obf-card.is-on .obf-state { background: var(--fill-success); }
        .obf-note { font-size: 12px; color: var(--text-muted); margin: 0 0 12px 0; line-height: 1.45; }
        .obf-note b { color: var(--text-secondary); }
        .container img, .container svg { max-width: 100%; }
        .header-frame { display: flex; flex-wrap: wrap; gap: 12px; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        h1 { font-size: 24px; margin: 0; color: var(--text-primary); display: inline-block; }
        /* Logo art is a light-background asset -- kept on its own fixed-white chip regardless of
           app theme (rather than var(--surface-card)) so it's never handed a dark backing it
           wasn't designed for. */
        .logo-box { background: #ffffff; border-radius: 6px; padding: 6px 14px; display: inline-flex; align-items: center; border: 1px solid var(--border); }
        .logo-box img { max-height: 180px; max-width: 560px; object-fit: contain; }
        .tab-header { display: flex; flex-wrap: wrap; row-gap: 6px; border-bottom: 2px solid var(--border); margin-bottom: 25px; align-items: flex-end; }
        .tab-header-btn { flex: 1 1 0; padding: 12px; background: var(--surface-page); border: 1px solid var(--border); border-bottom: none; font-size: 15px; font-weight: bold; color: var(--text-secondary); cursor: pointer; text-align: center; }
        .tab-header-btn.active { background: var(--surface-card); color: var(--text-primary); border-top: 3px solid var(--fill-accent); margin-bottom: -2px; font-weight: bold; }
        /* Advanced Analytics tab: a port of host_metrics_report.py's report.html, scoped to #advReport
           so its styles never leak into the rest of MTAT (and MTAT's table/th rules don't leak in). */
        #advReport {
            --surface-1: #fcfcfb; --page-plane: #f9f9f7; --text-primary: #0b0b0b; --text-secondary: #52514e;
            --text-muted: #898781; --gridline: #e1e0d9; --baseline: #c3c2b7; --border: rgba(11,11,11,0.10);
            --series-1: #2a78d6; --series-1-wash: rgba(42,120,214,0.10); --series-1-100: #cde2fb;
            background: var(--page-plane); color: var(--text-primary); border-radius: 10px;
            padding: 28px clamp(14px, 2vw, 28px) 40px; font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
        }
        @media (prefers-color-scheme: dark) {
            html:not([data-theme="light"]) #advReport {
                --surface-1: #1a1a19; --page-plane: #0d0d0d; --text-primary: #ffffff; --text-secondary: #c3c2b7;
                --text-muted: #898781; --gridline: #2c2c2a; --baseline: #383835; --border: rgba(255,255,255,0.10);
                --series-1: #3987e5; --series-1-wash: rgba(57,135,229,0.14); --series-1-100: #184f95;
            }
        }
        html[data-theme="dark"] #advReport {
            --surface-1: #1a1a19; --page-plane: #0d0d0d; --text-primary: #ffffff; --text-secondary: #c3c2b7;
            --text-muted: #898781; --gridline: #2c2c2a; --baseline: #383835; --border: rgba(255,255,255,0.10);
            --series-1: #3987e5; --series-1-wash: rgba(57,135,229,0.14); --series-1-100: #184f95;
        }
        #advReport * { box-sizing: border-box; }
        #advReport .rpt-head h1 { font-size: 22px; font-weight: 600; margin: 0 0 4px; color: var(--text-primary); }
        #advReport .rpt-head p { font-size: 13px; color: var(--text-secondary); margin: 0 0 22px; }
        #advReport .rpt-view-switch { display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin:10px 0 12px; }
        #advReport .rpt-view-switch button[aria-pressed="true"] { background:var(--text-accent); color:#fff; border-color:var(--text-accent); }
        #advReport .rpt-view-switch button:disabled { opacity:0.55; cursor:not-allowed; }
        #advReport .rpt-view-switch .view-help { flex-basis:100%; font-size:12px; color:var(--text-secondary); }
        #advReport .rpt-scope { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-end; margin-bottom: 20px; }
        #advReport .rpt-scope label { display: flex; flex-direction: column; gap: 5px; font-size: 12px; color: var(--text-secondary); }
        #advReport .rpt-scope label.obf-card { flex-direction: row; align-items: center; gap: 12px; margin-left: auto; }
        #advReport select, #advReport input[type="search"], #advReport input[type="number"] {
            font-size: 13px; padding: 7px 10px; border-radius: 7px; border: 1px solid var(--border);
            background: var(--surface-1); color: var(--text-primary); height: auto; font-weight: normal;
        }
        #advReport .rpt-scope select { min-width: 260px; }
        #advReport .tenant-filter { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; margin-bottom: 20px; }
        #advReport .tenant-filter-head { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; margin-bottom: 10px; }
        #advReport .tenant-filter-title { font-size: 13px; font-weight: 600; }
        #advReport .tenant-filter-actions { font-size: 12px; }
        #advReport .tenant-filter-actions a { color: var(--series-1); text-decoration: none; cursor: pointer; }
        #advReport .tenant-filter-actions a:hover { text-decoration: underline; }
        #advReport .tenant-checks { display: flex; flex-wrap: wrap; gap: 8px; }
        #advReport .tenant-chip { display: inline-flex; align-items: center; gap: 6px; font-size: 12.5px; border: 1px solid var(--border); border-radius: 999px; padding: 5px 12px 5px 10px; cursor: pointer; user-select: none; background: var(--page-plane); color: var(--text-primary); font-weight: normal; margin: 0; }
        #advReport .tenant-chip input { cursor: pointer; }
        #advReport .tenant-chip.excluded { opacity: 0.5; }
        #advReport .tenant-chip .tenant-chip-count { color: var(--text-muted); font-variant-numeric: tabular-nums; }
        #advReport .kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin-bottom: 36px; }
        #advReport .stat-tile { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; }
        #advReport .stat-tile .label { font-size: 12px; color: var(--text-secondary); margin-bottom: 6px; }
        #advReport .stat-tile .value { font-size: 24px; font-weight: 600; letter-spacing: -0.01em; color: var(--text-primary); }
        #advReport .stat-tile .unit { font-size: 13px; font-weight: 400; color: var(--text-secondary); margin-left: 3px; }
        #advReport section { margin-bottom: 40px; }
        #advReport h2 { font-size: 15px; font-weight: 600; margin: 0 0 4px; color: var(--text-primary); }
        #advReport .section-sub { font-size: 12px; color: var(--text-muted); margin: 0 0 16px; line-height: 1.45; }
        #advReport .hist-subhead { font-size: 12.5px; font-weight: 600; color: var(--text-secondary); margin: 22px 0 8px; }
        #advReport .hist-subhead.first { margin-top: 0; }
        #advReport .chart-card { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 20px 20px 8px; }
        #advReport .controls { display: flex; gap: 10px; align-items: center; margin-bottom: 12px; flex-wrap: wrap; }
        #advReport .controls input[type="search"] { width: 260px; }
        #advReport .count { font-size: 12px; color: var(--text-muted); }
        #advReport .threshold-controls .count-emphasis { font-size: 14px; font-weight: 700; color: var(--text-primary); }
        #advReport .controls label, #advReport .threshold-controls label { font-size: 12px; color: var(--text-secondary); font-weight: normal; margin: 0; }
        #advReport table { width: 100%; border-collapse: collapse; background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; font-size: 12.5px; }
        #advReport th, #advReport td { border: none; background: transparent; }
        #advReport thead th { text-align: right; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--text-muted); padding: 10px 14px; border-bottom: 1px solid var(--gridline); cursor: pointer; user-select: none; white-space: nowrap; background: var(--surface-1); }
        #advReport thead th:first-child, #advReport tbody td:first-child { text-align: left; }
        #advReport thead th:hover { color: var(--text-primary); }
        #advReport thead th .arrow { font-size: 9px; margin-left: 3px; opacity: .5; }
        #advReport tbody td { padding: 7px 14px; font-size: 12.5px; text-align: right; font-variant-numeric: tabular-nums; border-bottom: 1px solid var(--gridline); color: var(--text-primary); }
        #advReport tbody td:first-child { font-variant-numeric: normal; color: var(--text-secondary); }
        #advReport tbody tr:last-child td { border-bottom: none; }
        #advReport tbody tr:nth-child(even) td { background: transparent; }
        #advReport tbody tr:hover td { background: var(--series-1-wash); }
        #advReport .table-wrap { max-height: 640px; overflow: auto; border-radius: 10px; }
        #advReport tbody td:first-child { white-space: nowrap; }
        #advReport .rpt-no-timeline { font-size: 12px; color: var(--text-muted); text-align: center; padding: 18px 10px 26px; }
        #advReport thead { position: sticky; top: 0; background: var(--surface-1); z-index: 1; }
        #advReport .hist-svg, #advReport .overlay-svg { width: 100%; height: auto; display: block; touch-action: none; }
        #advReport .hist-bar { fill: var(--series-1); cursor: pointer; }
        #advReport .hist-bar:hover { filter: brightness(1.12); }
        #advReport .axis-line { stroke: var(--baseline); stroke-width: 1; }
        #advReport .grid-line { stroke: var(--gridline); stroke-width: 1; }
        #advReport .axis-label { fill: var(--text-muted); font-size: 10px; font-family: system-ui, sans-serif; }
        #advReport .axis-label-strong { fill: var(--text-secondary); font-size: 10.5px; font-family: system-ui, sans-serif; }
        #advReport .overlay-line { fill: none; stroke: var(--series-1); stroke-width: 1; stroke-linejoin: round; stroke-linecap: round; opacity: var(--overlay-opacity, 0.14); }
        #advReport .overlay-line.emphasis { stroke-width: 2; opacity: 1; }
        #advReport .threshold-controls { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; flex-wrap: wrap; }
        #advReport .threshold-controls input[type="number"] { width: 90px; font-variant-numeric: tabular-nums; }
        #advReport .threshold-note { font-size: 11.5px; color: var(--text-muted); margin: 0 0 8px; }
        #advReport .chart-empty { fill: var(--text-muted); font-size: 12px; font-family: system-ui, sans-serif; text-anchor: middle; }
        #advReport .svg-tooltip { position: absolute; pointer-events: none; background: var(--surface-1); border: 1px solid var(--border); border-radius: 6px; padding: 6px 10px; font-size: 12px; color: var(--text-primary); box-shadow: 0 2px 8px rgba(0,0,0,0.15); display: none; white-space: nowrap; z-index: 5; }
        #advReport .svg-tooltip .tt-value { font-weight: 600; font-variant-numeric: tabular-nums; }
        #advReport .svg-tooltip .tt-label { color: var(--text-secondary); }
        #advReport .svg-tooltip.tt-multi { white-space: normal; min-width: 190px; pointer-events: auto; }
        #advReport .svg-tooltip.pinned { box-shadow: 0 2px 10px rgba(0,0,0,0.2), 0 0 0 1px var(--series-1) inset; }
        #advReport .tt-close { position: absolute; top: 3px; right: 5px; cursor: pointer; font-size: 12px; line-height: 1; color: var(--text-muted); padding: 2px 3px; border-radius: 4px; }
        #advReport .tt-close:hover { color: var(--text-primary); background: var(--series-1-wash); }
        #advReport .tt-list { max-height: 260px; overflow-y: auto; margin-top: 4px; padding-right: 2px; }
        #advReport .tt-row { display: flex; justify-content: space-between; gap: 12px; padding: 1px 0; font-size: 11.5px; color: var(--text-secondary); }
        #advReport .tt-row .tt-row-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        #advReport .tt-row .tt-row-val { font-variant-numeric: tabular-nums; flex-shrink: 0; }
        #advReport .tt-row.tt-row-active { font-weight: 700; color: var(--text-primary); }
        #advReport .tt-more { font-size: 11px; color: var(--text-muted); padding-top: 3px; }
        #advReport .chart-wrap { position: relative; }
        #advReport .cand-yes { color: #1f9d55; font-weight: 600; }
        #advReport .cand-no { color: #d64545; font-weight: 600; }
        #advReport .rpt-footer { font-size: 11px; color: var(--text-muted); border-top: 1px solid var(--gridline); padding-top: 14px; margin-top: 8px; line-height: 1.5; }
        #advReport .rpt-list-details { border:1px solid var(--border);border-radius:7px;margin:14px 0;background:var(--surface-card); }
        #advReport .rpt-list-details>summary { padding:12px 14px;cursor:pointer;font-weight:600; }
        #advReport .rpt-table-controls { display:flex;flex-wrap:wrap;gap:8px;align-items:center;padding:10px 14px; }
        #advReport .rpt-table-controls input { min-width:220px;flex:1; }
        #advReport .rpt-sort { border:0;background:none;color:inherit;font:inherit;font-weight:600;cursor:pointer;text-align:inherit;padding:4px 0; }
        #advReport .rpt-sort:focus-visible { outline:2px solid var(--text-accent); }
        #advReport .rpt-duration-controls { display:flex;flex-wrap:wrap;gap:10px;align-items:end;margin:12px 0; }
        #advReport .rpt-duration-controls label { display:flex;flex-direction:column;gap:5px;font-size:12px; }
        #advReport .rpt-duration-controls select { max-width:480px; }
        #advReport .rpt-duration-controls input[type=number] { width:90px; }
        #advReport .rpt-list-details .table-wrap { max-height:560px;overflow:auto; }
        #advReport .rpt-list-details td { max-width:480px;overflow-wrap:anywhere; }
        #advReport .tenant-checks { max-height:220px;overflow:auto; }
        #advReport .rpt-duration-note { font-size:12px;color:var(--text-secondary); }
        .rep-long-list { border:1px solid #d7dbe0;border-radius:6px;margin:12px 0; }.rep-long-list>summary{padding:10px;cursor:pointer;font-weight:600;}
        @media print { #advReport .rpt-table-controls,#advReport .rpt-sort,#advReport .rpt-view-switch { -webkit-print-color-adjust:exact;print-color-adjust:exact; } #advReport .rpt-list-details .table-wrap{max-height:none} }

        #comparisonContainer .mtat-cluster-list>summary {cursor:pointer;font-weight:700;padding:12px;border:1px solid var(--border-input);border-radius:5px;margin:12px 0;}
        .mtat-sort-help {font-size:12px;font-weight:600;padding:8px 10px;background:var(--bg-panel);border-left:3px solid #0072a3;margin:8px 0;}
        th.sortable {cursor:pointer;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:4px;}
        th.sortable:hover,th.sortable:focus-visible {background:var(--bg-panel);outline:2px solid #0072a3;outline-offset:-2px;}
        th.sortable .sort-arrow:empty::before {content:' \2195';opacity:.7;}
        #advReport .rpt-sort::after {content:' \2195';opacity:.7;font-weight:400;}
.rep-range-toolbar{gap:14px;flex-wrap:wrap}.rep-range-toolbar label{display:flex;align-items:center;gap:10px;font-size:13px;font-weight:600;margin-right:auto}.rep-range-toolbar select{max-width:min(600px,70vw);padding:7px;border:1px solid #8797a0;border-radius:4px;color:#172c43;background:#fff}.rep-range-context{max-width:1000px;margin:auto;padding:12px 24px;background:#f4f8fb;border-bottom:1px solid #d7dbe0}.rep-range-context [role=status]{font-weight:600;margin-bottom:5px}.rep-range-context .small{font-size:12px;color:#52616c}.rep-range-choices{max-height:220px;overflow:auto}.rep-range-choices label{display:flex;align-items:center;gap:6px;padding:4px 0}.rep-range-help{font-size:12px;color:var(--text-muted);margin:8px 0}
@media print{.rep-range-toolbar{display:none!important}.rep-range-context{max-width:none;color:#000;padding:8px 0}#repRangeContent{display:block}}

        /* Customer report: card on the Sizing tab, export buttons and the report dialog */
        .btn.btn-secondary { background-color: transparent; color: var(--text-accent); border: 1px solid var(--text-accent); }
        .btn.btn-secondary:hover { background-color: var(--soft-bg-accent); color: var(--text-accent-hover); }
        .rep-card-top { display: flex; flex-wrap: wrap; gap: 14px 24px; align-items: center; justify-content: space-between; background: var(--soft-bg-success); border: 1px solid var(--panel-sim-border); border-left: 5px solid var(--fill-success); border-radius: 3px; padding: 16px 20px; margin-bottom: 20px; }
        .rep-card-top .rep-title { font-size: 17px; font-weight: 600; color: var(--text-primary); }
        .rep-card-top .rep-desc { font-size: 13px; color: var(--text-secondary); margin-top: 3px; max-width: 640px; line-height: 1.5; }
        .rep-card-top .rep-btns { display: flex; gap: 10px; flex-wrap: wrap; }
        .rep-card-top .rep-btns .btn { width: auto; padding: 0 20px; }
        .rep-toolbar { justify-content: flex-end; align-items: center; gap: 14px; margin: 0 0 16px 0; }
        .rep-toolbar-note { font-size: 12px; color: var(--text-muted); }
        .rep-toolbar .btn { width: auto; padding: 0 18px; }
        .rep-modal { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.55); display: flex; align-items: center; justify-content: center; z-index: 10000; padding: 16px; }
        .rep-card { background: var(--surface-card); color: var(--text-primary); border: 1px solid var(--border); border-radius: 4px; max-width: 640px; width: 100%; max-height: 92vh; overflow: auto; padding: 22px 24px; box-shadow: var(--shadow-toast); box-sizing: border-box; }
        .rep-card h3 { margin: 0 0 14px 0; font-size: 20px; font-weight: 500; }
        .rep-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 12px; }
        .rep-grid label { display: flex; flex-direction: column; font-size: 13px; font-weight: 600; color: var(--text-secondary); gap: 4px; }
        .rep-grid input[type=text] { padding: 8px; border: 1px solid var(--border-input); border-radius: 3px; background: var(--surface-card); color: var(--text-primary); font-size: 14px; font-family: inherit; }
        .rep-card fieldset { border: 1px solid var(--border); border-radius: 3px; margin: 0 0 12px 0; padding: 8px 12px; }
        .rep-card legend { font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-muted); padding: 0 6px; }
        .rep-sel { width: 100%; box-sizing: border-box; margin: 2px 0 6px 0; padding: 8px; border: 1px solid var(--border-input); border-radius: 3px; background: var(--surface-card); color: var(--text-primary); font-size: 14px; font-family: inherit; }
        .rep-opt { display: block; font-size: 14px; margin: 5px 0; cursor: pointer; font-weight: normal; }
        .rep-opt span { color: var(--text-muted); font-size: 12px; }
        .rep-prev { background: var(--soft-bg-success); border-left: 4px solid var(--fill-success); padding: 10px 14px; border-radius: 3px; font-size: 13px; margin: 6px 0 14px 0; line-height: 1.5; }
        .rep-actions { display: flex; gap: 12px; justify-content: flex-end; }
        @media (max-width: 600px) { .rep-grid { grid-template-columns: 1fr; } }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        .form-panel { background: var(--surface-alt); padding: 25px; border-radius: 6px; margin-bottom: 25px; border: 1px solid var(--border); }
        .login-grid { display: grid; grid-template-columns: 2fr 1.5fr 1.5fr; gap: 15px; }
        /* Only 2 fields (Username/Password), not the 3-column Target FQDN/Username/Password layout
           .login-grid is otherwise shared with for per-server dynamic rows -- reusing that template
           here left an empty 1.5fr column and lopsided spacing between the two visible fields. */
        #globalCredsGrid { grid-template-columns: 1fr 1fr; }
        .control-grid { display: grid; grid-template-columns: 2.2fr 3.8fr; gap: 20px; align-items: flex-start; background: var(--surface-alt); padding: 20px; border-radius: 6px; margin-bottom: 25px; border: 1px solid var(--border); }
        .input-group { display: flex; flex-direction: column; }
        .input-group label { font-weight: bold; font-size: 13px; margin-bottom: 6px; color: var(--text-secondary); }
        .input-group input, .input-group select { padding: 10px; border: 1px solid var(--border-input); border-radius: 4px; font-size: 14px; font-weight: bold; background: var(--surface-card); color: var(--text-primary); box-sizing: border-box; height: 41px; }

        .action-container { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; background: var(--surface-page); padding: 10px 15px; border-radius: 4px; border: 1px solid var(--border); }
        .btn { background-color: var(--fill-accent); color: white; border: none; padding: 10px 20px; font-weight: bold; border-radius: 4px; cursor: pointer; font-size: 14px; height: 41px; box-sizing: border-box; text-align: center; width: 100%; white-space: nowrap; }
        .btn:hover { background-color: var(--fill-accent-hover); }
        .btn:disabled { background-color: var(--fill-disabled) !important; cursor: not-allowed; }
        .btn-green { background-color: var(--fill-success); color: white; }
        .btn-green:hover { background-color: var(--fill-success-hover); }
        .btn-orange { background-color: var(--fill-orange); color: white; }
        .btn-orange:hover { background-color: var(--fill-orange-hover); }
        .btn-sm { padding: 6px 14px; font-size: 12px; height: 32px; width: auto; }

        .btn-danger { background-color: var(--fill-danger) !important; color: white !important; border: none; }
        .btn-danger:hover { background-color: var(--fill-danger-hover) !important; }

        .section-block { background: var(--surface-card); padding: 22px; border-radius: 6px; border: 1px solid var(--border); margin-bottom: 30px; box-shadow: var(--shadow-block); }
        .section-block-alt { background: var(--surface-alt-2); }

        .assess-panel { background-color: var(--panel-assess-bg); border: 1px solid var(--panel-assess-border); border-radius: 6px; padding: 20px; }
        .sim-panel { background-color: var(--panel-sim-bg); border: 1px solid var(--panel-sim-border); border-radius: 6px; padding: 20px; }
        .panel-title { font-weight: bold; font-size: 15px; margin-bottom: 15px; text-transform: uppercase; }
        .assess-panel .panel-title { color: var(--text-accent-hover); }
        .sim-panel .panel-title { color: var(--text-success); }
        .grid-title { font-weight: bold; font-size: 15px; text-transform: uppercase; color: var(--text-primary); }
        .metric-row { display: flex; align-items: center; font-size: 14px; margin-bottom: 12px; justify-content: space-between;}
        .metric-name { font-weight: bold; width: 220px; }
        .metric-target { color: var(--text-muted); width: 140px; }
        .metric-value { font-weight: bold; width: 120px; font-size: 15px; }
        .badge { font-weight: bold; padding: 4px 10px; border-radius: 4px; font-size: 12px; text-align: center; display: inline-block; min-width: 70px; }
        .badge-pass { background-color: var(--soft-bg-success); color: var(--text-success-soft); }
        .badge-warn { background-color: var(--soft-bg-warning); color: var(--text-warning-soft); border: 1px solid var(--soft-border-warning); }
        .badge-info { background-color: var(--soft-bg-info); color: var(--text-info-soft); }
        .badge-danger { background-color: var(--soft-bg-danger); color: var(--text-danger-soft); border: 1px solid var(--soft-border-danger); width: 100%; color: white; cursor: pointer; }
        .badge-danger:hover { background-color: var(--fill-danger-hover); }
        .note-text { font-weight: bold; margin-left: 15px; font-size: 13px; }
        .note-blue { color: var(--text-accent-hover); }

        table { width: 100%; border-collapse: collapse; font-size: 13px; border: 1px solid var(--border); }
        th { background-color: var(--surface-th); padding: 10px 12px; text-align: left; border: 1px solid var(--border); border-bottom: 2px solid var(--border); font-weight: bold; color: var(--text-primary); }
        td { padding: 10px 12px; border: 1px solid var(--border); color: var(--text-primary); }
        tr:nth-child(even) { background-color: var(--surface-stripe); }
        .comp-table th { background-color: var(--surface-hover); }

        .cluster-link { color: var(--text-accent); text-decoration: none; font-weight: bold; cursor: pointer; }
        .cluster-link:hover { text-decoration: underline; color: var(--text-accent-hover); }

        .sim-grid { display: grid; grid-template-columns: 1.1fr 1.1fr; gap: 40px; }
        .gf-sim-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .sim-math-box { display: flex; flex-direction: column; gap: 12px; }
        .math-row { display: flex; justify-content: space-between; font-size: 14px; }
        .lockout-msg { text-align: center; padding: 50px; color: var(--text-muted); font-style: italic; font-size: 14px; }
        .checkbox-row { margin: 0 0 10px 0; font-weight: bold; font-size: 13px; display: flex; align-items: center; gap: 8px; }
        .checkbox-row input { width: 16px; height: 16px; cursor: pointer; }

        .checkbox-box { display: flex; flex-direction: column; gap: 8px; background: var(--surface-card); padding: 12px; border: 1px solid var(--border-input); border-radius: 4px; box-sizing: border-box; width: 100%; min-height: 41px; }
        .checkbox-item { display: inline-flex !important; align-items: center !important; gap: 8px; font-size: 13px !important; font-weight: bold !important; cursor: pointer; text-transform: none !important; margin: 0 !important; color: var(--text-primary) !important; }
        .checkbox-item input { width: 16px; height: 16px; cursor: pointer; margin: 0; }

        .info-panel-box { background-color: var(--soft-bg-accent); border: 1px solid var(--soft-border-accent); color: var(--text-accent-soft); padding: 15px; border-radius: 6px; font-weight: bold; font-size: 13px; margin-top: 20px; box-sizing: border-box; line-height: 1.5; }
        .warn-panel-box { background-color: var(--soft-bg-warning); border: 1px solid var(--soft-border-warning); color: var(--text-warning-soft); padding: 15px; border-radius: 6px; font-weight: bold; font-size: 13px; margin-bottom: 20px; box-sizing: border-box; line-height: 1.5; }

        .headroom-banner { display: flex; justify-content: space-between; align-items: center; background: var(--panel-teal-bg); border: 1px solid var(--panel-teal-border); border-radius: 6px; padding: 16px 22px; margin-top: 25px; margin-bottom: 10px; }
        .headroom-text { flex-grow: 1; }
        .headroom-title { font-weight: bold; color: var(--text-teal-title); font-size: 15px; text-transform: uppercase; }
        .headroom-desc { font-size: 13px; color: var(--text-teal-desc); margin-top: 4px; }
        .headroom-value { font-size: 22px; font-weight: bold; color: var(--text-teal-value); background: var(--surface-card); padding: 8px 18px; border-radius: 4px; border: 2px solid var(--border-teal-value); box-shadow: var(--shadow-value); }

        .gf-card { background: var(--surface-card); border: 1px solid var(--border-input); border-radius: 6px; padding: 20px; }
        .gf-card-title { font-size: 16px; font-weight: bold; margin-bottom: 15px; color: var(--text-primary); border-bottom: 2px solid var(--surface-hover); padding-bottom: 8px;}
        .gf-savings-banner { text-align: center; background: var(--banner-savings-bg); border: 2px solid var(--fill-success); padding: 20px; border-radius: 8px; margin-top: 25px; }
        .gf-savings-text { font-size: 16px; color: var(--text-success-soft); font-weight: bold; text-transform: uppercase; margin-bottom: 5px; }
        .gf-savings-amount { font-size: 32px; font-weight: 900; color: var(--text-success); }

        /* Lightweight percentage bars -- no charting library, just a filled track under a % figure */
        .pct-bar-track { background: var(--surface-hover); border-radius: 3px; height: 6px; width: 100%; overflow: hidden; margin-top: 5px; }
        .pct-bar-fill { height: 100%; border-radius: 3px; background: var(--fill-accent); transition: width 0.3s ease; }
        .pct-bar-fill.pct-bar-pass { background: var(--fill-success); }
        .pct-bar-fill.pct-bar-warn { background: var(--fill-orange); }

        /* Toast/status queue -- non-blocking replacement for alert() */
        #toastStack { position: fixed; top: 20px; right: 20px; z-index: 9999; display: flex; flex-direction: column; gap: 10px; max-width: 420px; }
        .toast-item { background: var(--surface-card); border-left: 5px solid var(--fill-accent); border-radius: 6px; box-shadow: var(--shadow-toast); padding: 14px 40px 14px 16px; font-size: 13px; font-weight: bold; color: var(--text-primary); position: relative; line-height: 1.5; animation: toastIn 0.2s ease-out; }
        .toast-item.toast-error { border-left-color: var(--fill-danger); }
        .toast-item.toast-warn { border-left-color: var(--fill-orange); }
        .toast-item.toast-info { border-left-color: var(--fill-accent); }
        .toast-close { position: absolute; top: 10px; right: 12px; cursor: pointer; font-weight: bold; color: var(--text-muted); background: none; border: none; font-size: 14px; padding: 4px; }
        .toast-close:hover { color: var(--text-primary); }
        @keyframes toastIn { from { opacity: 0; transform: translateX(20px); } to { opacity: 1; transform: translateX(0); } }

        /* Per-target progress chips for multi-minute connect/analyze operations */
        .progress-chip-row { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }
        .progress-chip { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; font-weight: bold; padding: 5px 10px; border-radius: 12px; background: var(--surface-alt); border: 1px solid var(--border); color: var(--text-secondary); }
        .progress-chip.chip-running { background: var(--soft-bg-accent); border-color: var(--soft-border-accent); color: var(--text-accent-hover); }
        .progress-chip.chip-done { background: var(--soft-bg-success); border-color: var(--panel-sim-border); color: var(--text-success-soft); }
        .progress-chip.chip-failed { background: var(--soft-bg-danger); border-color: var(--soft-border-danger); color: var(--text-danger-soft); }
        .progress-chip .chip-spinner { width: 9px; height: 9px; border: 2px solid var(--soft-border-accent); border-top-color: var(--text-accent-hover); border-radius: 50%; animation: chipSpin 0.7s linear infinite; }
        @keyframes chipSpin { to { transform: rotate(360deg); } }

        /* Scrollable table container with a sticky header, so long Host/VM lists don't lose column context */
        .table-scroll-box { max-height: 480px; overflow-y: auto; border: 1px solid var(--border); }
        .table-scroll-box table { border: none; }
        .table-scroll-box th { position: sticky; top: 0; z-index: 1; }
        .table-filter-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; gap: 10px; }
        .table-filter-row input { padding: 7px 10px; border: 1px solid var(--border-input); border-radius: 4px; font-size: 13px; width: 220px; box-sizing: border-box; }
        th.sortable { cursor: pointer; user-select: none; }
        th.sortable:hover { background-color: var(--surface-hover); }
        th.sortable .sort-arrow { font-size: 10px; margin-left: 4px; color: var(--text-muted); }

        /* Theme toggle -- sits beside Download Debug Log / Exit Engine in the header */
        .theme-toggle-btn { background-color: var(--surface-alt) !important; color: var(--text-secondary) !important; border: 1px solid var(--border) !important; }
        .theme-toggle-btn:hover { background-color: var(--surface-hover) !important; }

        @media (max-width: 768px) {
            body { padding: 12px; }
            .container { padding: 15px; }
            .control-grid, .login-grid, .sim-grid, .gf-sim-grid, #shared-costs, #brownfield-controls,
            #greenfield-controls > div, .control-grid[style] { grid-template-columns: 1fr !important; }
            .tab-header-btn { font-size: 12px; padding: 8px 4px; }
            .metric-name { width: auto !important; min-width: 140px; }
            .metric-target { width: auto !important; }
        }

        @media print {
            /* Printing intentionally always renders light/white regardless of the on-screen theme --
               unchanged by the dark mode work, this was already theme-independent before it existed. */
            body { background: white; padding: 0; }
            .container { box-shadow: none; max-width: 100%; padding: 0; }
            .tab-header, #importToggleBtn, #btnExportAll, .btn, #toastStack, .table-filter-row,
            th.sortable .sort-arrow { display: none !important; }
            .rep-card-top, .rep-toolbar, .rep-modal { display: none !important; }
            .tab-content { display: block !important; }
            .table-scroll-box { max-height: none; overflow: visible; }
            .section-block, .sim-panel, .assess-panel { box-shadow: none; break-inside: avoid; }
        }
    </style>
</head>
<body>
<div id="toastStack" aria-live="polite" role="status"></div>
<div class="container">
    <div class="header-frame">
        <div style="display: flex; flex-direction: column; justify-content: center;">
            <h1>Memory Tiering Assessment Tool v3.3</h1>
            <div id="mainVerInfo" style="font-size: 11px; color: var(--text-muted);"></div>
        </div>
        <div class="logo-box" id="brandingLogoCell">##LOGO_HTML_PLACEHOLDER##</div>
    </div>
    <div class="tab-header">
        <div style="display: flex; flex-grow: 1;" role="tablist" aria-label="Assessment steps">
            <button class="tab-header-btn active" id="btn-tab-connect" role="tab" aria-selected="true" aria-controls="tab-connect" onclick="switchTab('tab-connect', this)">1. Connection</button>
            <button class="tab-header-btn" id="btn-tab-baseline" role="tab" aria-selected="false" aria-controls="tab-baseline" onclick="switchTab('tab-baseline', this)" style="display:none;">2. Baseline Assessment</button>
            <button class="tab-header-btn" id="btn-tab-advanced" role="tab" aria-selected="false" aria-controls="tab-advanced" onclick="switchTab('tab-advanced', this)" style="display:none;">3. Advanced Analytics</button>
            <button class="tab-header-btn" id="btn-tab-simulator" role="tab" aria-selected="false" aria-controls="tab-simulator" onclick="switchTab('tab-simulator', this)" style="display:none;">4. Sizing &amp; Savings</button>
        </div>
        <button class="btn btn-sm theme-toggle-btn" id="themeToggleBtn" onclick="toggleTheme()" style="margin-bottom: 6px; margin-left: 15px; height: 28px; width: auto; padding: 0 15px;" title="Toggle light/dark appearance">&#9789; <span id="themeToggleLabel">Dark Mode</span></button>
        <button class="btn btn-sm" onclick="downloadDebugLog()" style="margin-bottom: 6px; margin-left: 15px; height: 28px; width: auto; padding: 0 15px; background-color:#5a6268;" title="Download this session's debug log -- useful if data looks incomplete or wrong">Download Debug Log</button>
        <button class="btn btn-sm btn-danger" onclick="shutdownServer()" style="margin-bottom: 6px; margin-left: 15px; height: 28px; width: auto; padding: 0 15px;">Exit Engine</button>
    </div>
    
    <div id="tab-connect" class="tab-content active" role="tabpanel" aria-labelledby="btn-tab-connect">
        <div class="form-panel" id="loginLoadingFrame">
            <fieldset style="border:0; padding:0; margin:0 0 18px;">
                <legend style="font-weight:600; margin-bottom:10px;">Live data source</legend>
                <label style="display:inline-flex; align-items:center; gap:6px; margin-right:24px;"><input type="radio" name="connectionMode" id="connectionModeVc" checked onchange="setConnectionMode('vcenter')"> vCenter</label>
                <label style="display:inline-flex; align-items:center; gap:6px;"><input type="radio" name="connectionMode" id="connectionModeOps" onchange="setConnectionMode('ops')"> vROps / Aria Operations / VCF Operations</label>
            </fieldset>
            <div id="vcenterConnectionFields">
            <div class="input-group" style="margin-bottom: 15px;">
                <label for="vcServer">vCenter Server(s) [comma-separated]</label>
                <input type="text" id="vcServer" value="" oninput="handleServerListChange()">
            </div>
            <div class="checkbox-row">
                <input type="checkbox" id="useSameCreds" checked onchange="toggleCredsLayout()">
                <label for="useSameCreds" style="cursor:pointer;">Use same credentials for all vCenters</label>
            </div>
            <div class="login-grid" id="globalCredsGrid">
                <div class="input-group">
                    <label for="vcUser">Global Username</label>
                    <input type="text" id="vcUser" value="administrator@vsphere.local">
                </div>
                <div class="input-group">
                    <label for="vcPass">Global Password</label>
                    <input type="password" id="vcPass" value="">
                </div>
            </div>
            <div id="dynamicCredsContainer" style="display: none; border-top: 1px solid var(--border-input); padding-top: 15px; margin-top: 15px;"></div>
            <div class="checkbox-row" style="margin-top: 15px;" title="Off by default, because most vCenters use self-signed certificates. When on, MTAT refuses to connect to a vCenter whose certificate this computer does not trust.">
                <input type="checkbox" id="requireValidCerts">
                <label for="requireValidCerts" style="cursor:pointer;">Require valid vCenter certificates (refuse self-signed or untrusted ones)</label>
            </div>
            </div>
            <div id="opsConnectionFields" style="display:none;">
                <div class="input-group" style="margin-bottom:15px;"><label for="opsServer">Operations server (hostname or HTTPS address)</label><input type="text" id="opsServer" placeholder="ops.example.com" autocomplete="off"></div>
                <div class="login-grid">
                    <div class="input-group"><label for="opsUser">Ops Username</label><input type="text" id="opsUser" autocomplete="username"></div>
                    <div class="input-group"><label for="opsPass">Ops Password</label><input type="password" id="opsPass" autocomplete="current-password"></div>
                </div>
                <div class="input-group" style="margin-top:15px;"><label for="opsAuthSource">Authentication source (optional; blank for local)</label><input type="text" id="opsAuthSource" placeholder="Configured Ops authentication source name" autocomplete="off"></div>
                <div class="checkbox-row" style="margin-top:15px;"><input type="checkbox" id="opsRequireValidCerts" checked><label for="opsRequireValidCerts" style="cursor:pointer;">Require a trusted Operations certificate</label></div>
                <p style="font-size:13px; color:var(--text-secondary);">Reads existing Ops inventory and retained metrics without changing vCenter statistics levels. Latest samples follow the Ops collection interval. Available history and configuration details depend on collection and retention.</p>
            </div>
            <div id="connectionStatus" role="status" aria-live="polite" style="margin-top:12px; font-size:13px;"></div>
            <div style="margin-top: 20px; display: flex; justify-content: space-between; align-items: center;">
                <button class="btn" id="connectBtn" onclick="runConnectionPipeline()" style="width: 65%;">Establish PowerCLI Sessions</button>
                <button class="btn" onclick="enableOfflineMode()" style="width: 32%; background-color: #6c757d; font-size: 13px;">Skip to Offline Import</button>
            </div>
            <div id="connectProgressChips" class="progress-chip-row" style="display:none;" role="status" aria-live="polite"></div>
        </div>
    </div>
    
        <div id="mtatSavedOfflineAccess" style="display:none;margin:12px 0;"><button class="btn btn-sm" onclick="mtatOpenOfflineSavedResults()">Open saved assessments</button></div>
        <details id="mtatJobsPanel" class="section-block" style="display:none;margin:12px 0;">
            <summary style="cursor:pointer;"><b id="mtatJobPanelTitle">Collection jobs and saved results</b> <span id="mtatJobSummary"></span></summary>
            <p id="mtatJobStatus" role="status" aria-live="polite">Completed results are saved locally and remain available after a restart. Reconnect before resuming unfinished work.</p>
            <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;">
                <select id="mtatJobSelect" aria-label="Saved collection jobs"></select>
                <button class="btn btn-sm" onclick="mtatRefreshJobs()">Refresh</button>
                <button class="btn btn-sm" onclick="mtatOpenSavedJob()">Open job</button>
                <button class="btn btn-sm" id="mtatLoadAllResults" onclick="mtatLoadCompletedJobResults()">Load all completed results</button>
                <button class="btn btn-sm" id="mtatJobResume" onclick="mtatResumeJob()" disabled>Resume unfinished work</button>
                <button class="btn btn-sm" id="mtatJobCancel" onclick="mtatCancelJob()" disabled>Cancel collection</button>
                <button class="btn btn-sm" onclick="mtatDownloadJobLog()">Download job log</button>
                <button class="btn btn-sm" onclick="mtatDownloadJobResult()">Download checkpoint</button>
            </div>
            <div style="max-height:300px;overflow:auto;margin-top:10px;"><table class="comp-table"><thead><tr><th>Cluster</th><th>Server</th><th>Range</th><th>Status</th><th>Hosts</th><th>VMs</th><th>Result</th></tr></thead><tbody id="mtatJobResults"></tbody></table></div>
            <p>Saved results describe their original run. Open results to include them in assessment, analytics and reports. Collection is sequential and browser loading is bounded.</p>
        </details>

        <div id="mtatLoadedNotice" class="info-panel-box" style="display:none;margin:10px 0;" role="status"></div>

    <div id="tab-baseline" class="tab-content" role="tabpanel" aria-labelledby="btn-tab-baseline">
        <div id="lockout-baseline" class="lockout-msg">Awaiting active inventory connection profile. Please complete Step 1.</div>
        <div id="content-baseline" style="display: none;">
            <div class="rep-toolbar" id="repToolbarBase" style="display:none;"><span class="rep-toolbar-note">Printable report for this step</span><button class="btn btn-sm btn-green" onclick="openReportDialog('assessment')" title="Create a printable report you can save as PDF">Export Assessment Report</button></div>
            <div class="control-grid" id="scopeSelectionPanel">
                <div class="input-group">
                    <label for="clusterSelect">Target Cluster Scope</label>
                    <select id="clusterSelect" onchange="loadClusterRanges()"></select>
                </div>
                <div class="input-group">
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:6px;">
                        <label style="margin:0;">Evaluation Metrics Range</label>
                        <span id="selectAllToggle" onclick="toggleSelectAllRanges()" style="color:var(--text-accent); cursor:pointer; font-size:11px; font-weight:bold; text-transform:none;">Select All</span>
                    </div>
                    <div id="rangeCheckboxes" class="checkbox-box"></div>
                </div>
            </div>

            <div style="margin-bottom: 25px;">
                <div style="display:flex; gap:15px;">
                    <button class="btn btn-green" id="analyzeBtn" style="height: 45px;" onclick="executeClusterDataCollection()">Analyze Selection Profile</button>
                    <button class="btn" id="importToggleBtn" style="height: 45px; background-color:#5a6268;" onclick="toggleImportPanel()">Import Data Instead</button>
                </div>
                <label style="display:block;margin-top:8px;"><input type="checkbox" id="mtatAllClusters"> Include all connected clusters (sequential collection)</label>
                <div id="analyzeProgressChips" class="progress-chip-row" style="display:none;" role="status" aria-live="polite"></div>
            </div>

            <div class="section-block" id="importPanel" style="display:none;">
                <div class="panel-title" style="color:var(--text-secondary);">Import Previously Collected Data</div>
                <div class="info-panel-box" style="margin-bottom:15px;" id="importInfoBox">&#9432; Populates the checklist above, the tables below, and the Sizing &amp; Savings tab for the Target Cluster Scope selected above &mdash; without querying vCenter. Memory Tiering status cannot be determined from imported files and defaults to "Unknown".</div>
                <div class="control-grid" style="grid-template-columns: 1fr 1fr; margin-bottom:15px;">
                    <div class="input-group">
                        <label for="importSourceType">Import Source Format</label>
                        <select id="importSourceType" onchange="toggleImportSourceFields()">
                            <option value="mtat">MTAT Export (Hosts + VMs CSV)</option>
                            <option value="rvtools">RVTools Workbooks or CSV Exports</option>
                            <option value="history">MTAT History (Matrix CSV / MTAT Bundle)</option>
                            <option value="vrops">VCF Operations / vROps Host Export (.xlsx)</option>
                        </select>
                    </div>
                    <div class="input-group" id="importRangeLabelWrap">
                        <label for="importRangeLabel">Range Label</label>
                        <input type="text" id="importRangeLabel" value="Imported Data">
                    </div>
                </div>
                <div class="control-grid" style="grid-template-columns: 1fr 1fr; margin-bottom:15px;">
                    <div class="input-group">
                        <label id="importPrimaryLabel" for="importPrimaryFile">Hosts CSV (required)</label>
                        <input type="file" id="importPrimaryFile" accept=".csv">
                    </div>
                    <div class="input-group" id="importSecondaryWrap">
                        <label id="importSecondaryLabel" for="importSecondaryFile">VMs CSV (optional)</label>
                        <input type="file" id="importSecondaryFile" accept=".csv">
                    </div>
                </div>
                <div class="control-grid" style="grid-template-columns: 1fr 1fr; margin-bottom:15px; display:none;" id="importTertiaryWrap">
                    <div class="input-group">
                        <label id="importTertiaryLabel" for="importTertiaryFile">All-Tables VMs History CSV (optional)</label>
                        <input type="file" id="importTertiaryFile" accept=".csv">
                    </div>
                    <div></div>
                </div>
                <div class="input-group" id="importVropsUnitsWrap" style="display:none; max-width:420px; margin-bottom:15px;">
                <label for="importVropsUnits">Units for memory cells without a unit suffix</label>
                <select id="importVropsUnits">
                    <option value="auto" selected>Detect automatically</option>
                    <option value="GB">GB (1,000,000,000 bytes)</option>
                    <option value="VMWARE_GB">VMware GB (1,073,741,824 bytes)</option>
                    <option value="MB">VMware MB (1,048,576 bytes)</option>
                    <option value="KB">VMware KB (1,024 bytes)</option>
                </select>
            </div>
            <div class="obf-note" id="obfImportNote"></div>
                <div id="importStatusMsg" style="font-size:13px; font-weight:bold; margin-bottom:15px; display:none;" role="status" aria-live="polite"></div>
                <div style="display:flex; gap:15px; flex-wrap:wrap; align-items:stretch;">
                    <label class="obf-card" for="obfToggle">
                        <input type="checkbox" id="obfToggle" class="obf-input" onchange="setObfuscation(this.checked)">
                        <span class="obf-slider" aria-hidden="true"></span>
                        <span class="obf-card-text"><span class="obf-card-title">Hide real names <span class="obf-state">OFF</span></span><span class="obf-card-sub">Aliases cluster, host, VM and tenant names on screen and in exports</span></span>
                    </label>
                    <button class="btn btn-green" id="importProcessBtn" style="width:auto; padding:0 25px;" onclick="processImportFiles()">Process Import</button>
                    <button class="btn" style="width:auto; padding:0 25px; background-color:#a0a0a0;" onclick="toggleImportPanel()">Cancel</button>
                </div>
            </div>

            <div class="section-block" id="metricsDisplayCard" style="display: none;">
                <div id="rowCollectionFailureWarn" class="warn-panel-box" style="display:none;" role="alert" aria-live="polite"></div>
                <div class="panel-title" id="lblChecklistTitle">Baseline Qualification Checklist:</div>
                <div class="assess-panel">
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Average CPU utilization across the selected range(s). Tiering candidates should run cool on CPU, since accessing the NVMe tier costs extra cycles.">CPU Usage (Avg)</span><span class="metric-target">[ Target: &lt;= 50% ]</span><div class="metric-value"><span id="lblBaseCpu">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseCpu"></div></div></div><span class="badge" id="badgeBaseCpu"></span></div>
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Highest sampled Active Memory % using vCenter's average-rollup samples (a true maximum-rollup query often isn't retained). Capacity math uses this worst-case value so sizing doesn't under-provision for bursty workloads. For a cluster it is the sum of each host's own peak; hosts can peak at different times, so it is a conservative (high) figure.">Active Memory (Peak)</span><span class="metric-target">[ Target: &lt;= 50% ]</span><div class="metric-value"><span id="lblBaseActive">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseActive"></div></div></div><span class="badge" id="badgeBaseActive"></span></div>
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Average Active Memory % across the range -- shown for reference only. The Peak figure above (not this average) drives the pass/fail badge and all capacity/sizing math.">Active Memory (Avg)</span><span class="metric-target" style="font-style:italic;">[ For reference only ]</span><div class="metric-value"><span id="lblBaseActiveAvg">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseActiveAvg"></div></div></div></div>
                    <div id="rowActiveVariabilityWarn" style="display:none; margin: -6px 0 12px 0; font-size:12px; font-weight:bold; color:var(--text-warning-soft);" role="status" aria-live="polite"></div>
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Average Consumed Memory %. Shown for context: higher memory demand means more cold pages for tiering to move to NVMe, but there is no fixed Consumed % at which tiering starts.">Consumed Memory (Avg)</span><span class="metric-target" style="font-style:italic;">[ For reference only ]</span><div class="metric-value"><span id="lblBaseConsumed">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseConsumed"></div></div></div></div>
                </div>
            </div>

            <div class="section-block section-block-alt" id="comparisonContainer" style="display: none;">
                <div class="action-container">
                    <div class="grid-title">Range Comparison Matrix (Historical Workload Trend Tracking)</div>
                    <button class="btn btn-sm" onclick="exportSectionToCSV('matrix')">Export Matrix CSV</button>
                </div>
                <details id="comparisonListDetails" class="mtat-cluster-list" open>
                    <summary>Cluster and range list — <span id="comparisonListCount">show / hide</span></summary>
                    <div class="mtat-sort-help">Sortable columns: click an underlined header (&#8597;). Click again to reverse the order. You can also focus a header and press Enter.</div>
                <table class="comp-table"><thead><tr id="comparisonMatrixHead"><th class="sortable" data-mkey="cluster" onclick="sortComparisonMatrix('cluster')">Target Cluster Scope<span class="sort-arrow"></span></th><th class="sortable" data-mkey="range" onclick="sortComparisonMatrix('range')">Analyzed Range Profile<span class="sort-arrow"></span></th><th class="sortable" data-mkey="cpu" onclick="sortComparisonMatrix('cpu')">CPU Avg %<span class="sort-arrow"></span></th><th class="sortable" data-mkey="peak" onclick="sortComparisonMatrix('peak')">Active Mem Peak %<span class="sort-arrow"></span></th><th class="sortable" data-mkey="avg" onclick="sortComparisonMatrix('avg')">Active Mem Avg %<span class="sort-arrow"></span></th><th class="sortable" data-mkey="cons" onclick="sortComparisonMatrix('cons')">Consumed Mem Avg %<span class="sort-arrow"></span></th></tr></thead><tbody id="comparisonMatrixBody"></tbody></table>
                <div style="font-size:11px; color:var(--text-muted); margin-top:6px; font-style:italic;">Bars are scaled 0-100% for a quick visual read; exact figures are in the cell text.</div>
                </details>
            </div>

            <div class="section-block" id="hostContainerPanel" style="display: none;">
                <div class="action-container">
                    <div class="grid-title">Physical Host Breakdown</div>
                    <button class="btn btn-sm" onclick="exportSectionToCSV('hosts')">Export Hosts CSV</button>
                </div>
                <div id="opsPeakEvidence"></div>
                <div class="table-filter-row">
                    <input type="text" id="hostTableFilter" placeholder="Filter hosts..." oninput="filterTableRows(this, '#hostTable tbody')">
                    <span style="font-size:11px; color:var(--text-muted);">Click a column header to sort</span>
                </div>
                <div class="table-scroll-box">
                    <table id="hostTable"><thead><tr>
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)">Cluster<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)">HostName<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)">Tiering<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">CPU_Pct<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Physical_RAM (GB)<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Consumed_GB<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Active_GB<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Active_Pct<span class="sort-arrow"></span></th>
                    </tr></thead><tbody></tbody></table>
                </div>
            </div>

            <div class="section-block section-block-alt" id="vmContainerPanel" style="display: none;">
                <div class="action-container">
                    <div class="grid-title">Virtual Machines by Active Memory % <span style="font-weight:normal; font-style:italic; font-size:12px; color:var(--text-muted); text-transform:none;">(full list, not just a "Top N")</span></div>
                    <button class="btn btn-sm" onclick="exportSectionToCSV('vms')">Export VMs CSV</button>
                </div>
                <div class="table-filter-row">
                    <input type="text" id="vmTableFilter" placeholder="Filter VMs..." oninput="filterTableRows(this, '#vmTable tbody')">
                    <span style="font-size:11px; color:var(--text-muted);">Click a column header to sort</span>
                </div>
                <div class="table-scroll-box">
                    <table id="vmTable"><thead><tr>
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)">Host<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)">VMName<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Provisioned_GB<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Active_GB<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Active_Pct<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)" title="Yes = this VM's memory must stay in DRAM and is never moved to NVMe: a passthrough device (PCI / DirectPath, vGPU, SR-IOV, RDMA), pinned memory, Latency Sensitivity High, Fault Tolerance, or tiering disabled on the VM. A full memory reservation (All locked) on its own does not keep memory in DRAM: reserved memory can still be served from NVMe.">DRAM_Only<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Pages_1GB<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Pages_2MB<span class="sort-arrow"></span></th>
                    </tr></thead><tbody></tbody></table>
                </div>
            </div>

            <div style="margin-bottom:30px;">
                <div id="exportRedundantNote" class="info-panel-box" style="display:none; margin:0 0 12px 0;">&#9432; Exports are hidden because everything in this session came from MTAT's own exports, so exporting again would just return the same files. They come back as soon as live, RVTools or VCF Operations data is added.</div>
                <div id="obfExportSwitchWrap" style="margin-bottom:12px; display:none;"><label class="obf-card" for="obfToggleExport">
                        <input type="checkbox" id="obfToggleExport" class="obf-input" onchange="setObfuscation(this.checked)">
                        <span class="obf-slider" aria-hidden="true"></span>
                        <span class="obf-card-text"><span class="obf-card-title">Hide real names <span class="obf-state">OFF</span></span><span class="obf-card-sub">Aliases cluster, host, VM and tenant names on screen and in exports</span></span>
                    </label></div>
                <div id="obfKeyRow" style="display:none; font-size:12px; margin:-4px 0 12px 0; color:var(--text-muted);">
                    <a href="#" class="cluster-link" onclick="downloadObfuscationKey(); return false;">Download name key (CSV)</a> &middot; maps every alias back to its real name. Keep it private; it is never included in an export, and it is cleared when the engine exits.
                </div>
                <button class="btn btn-orange" id="btnExportAll" style="display:none; width:100%; height:45px;" onclick="exportAllTablesToCSV()">Save as MTAT Bundle</button>
            </div>
        </div>
    </div>
    
    <div id="tab-advanced" class="tab-content" role="tabpanel" aria-labelledby="btn-tab-advanced">
        <div id="advLockout" class="lockout-msg" style="padding: 45px; border: 1px dashed var(--border-input); background: var(--surface-card); border-radius: 6px;">
            <div style="margin-bottom:15px;">No analyzed or imported data yet. Run an analysis or import data in Step 2 first.</div>
            <button class="btn btn-green" style="width:auto; padding: 10px 35px;" onclick="switchTab('tab-baseline', document.getElementById('btn-tab-baseline'))">Jump to Step 2</button>
        </div>
        <div id="advContent" style="display:none;">
        <div class="rep-toolbar" id="repToolbarAdv" style="display:none;"><span class="rep-toolbar-note">Printable report for this step</span><button class="btn btn-sm btn-green" onclick="openReportDialog('analytics')" title="Create a printable report you can save as PDF">Export Analytics Report</button></div>
          <div id="advReport">
            <div id="rptHistoryNotice" role="status" style="display:none;border:1px solid #b17700;border-radius:6px;padding:12px;margin:12px 0;background:var(--surface-1);"></div>

            <div class="rpt-head">
                <h1 id="rptTitle">Host Memory Report &middot; Summary</h1>
                <p id="rptSource"></p>
            </div>
            <div class="rpt-scope">
                <label for="advClusterSelect">Cluster scope<select id="advClusterSelect" onchange="onAdvClusterChange()"></select></label>
                <label for="advRangeSelect">Time range<select id="advRangeSelect" onchange="renderAdvancedAnalytics()"></select></label>
                <label for="rptViewMode"><b>Analytics view</b><select id="rptViewMode" onchange="rptChangeViewMode()" aria-describedby="rptViewModeHint"><option value="matrix">Matrix</option><option value="timeline">Timeline</option></select></label>
                <label class="obf-card" for="obfToggleAdv">
                    <input type="checkbox" id="obfToggleAdv" class="obf-input" onchange="setObfuscation(this.checked)">
                    <span class="obf-slider" aria-hidden="true"></span>
                    <span class="obf-card-text"><span class="obf-card-title">Hide real names <span class="obf-state">OFF</span></span><span class="obf-card-sub">Clusters, hosts, tenants, datacenters and fabrics</span></span>
                </label>
            </div>

            <p id="rptViewModeHint" class="section-sub" role="status" style="margin:-8px 0 18px;"></p>
            <details class="tenant-filter" id="rptTenantFilter" style="display:none;"><summary>Tenant filter (show / hide)</summary>
                <div class="tenant-filter-head">
                    <span class="tenant-filter-title">Filter by tenant</span>
                    <span class="tenant-filter-actions"><a id="rptTenantSelectAll">All</a> &middot; <a id="rptTenantSelectNone">None</a></span>
                    <span class="count" id="rptTenantFilterCount"></span>
                </div>
                <div class="tenant-checks" id="rptTenantChecks"></div>
                <p class="threshold-note" id="rptTenantFilterNote" style="margin:8px 0 0;"></p>
            </details>

            <div class="kpi-row" id="rptKpiRow"></div>

            <section>
                <h2>Active memory % &middot; distribution across hosts</h2>
                <p class="section-sub">Active memory as a % of host capacity. Two bases, since a host's active % moves over time: the time-averaged view can hide a host that spikes briefly. Hover a bar for the exact range and count.</p>
                <h3 class="hist-subhead first" id="rptHistAvgSubhead"></h3>
                <div class="chart-card chart-wrap" id="rptHistCardAvg"><div class="svg-tooltip" id="rptHistTooltipAvg"></div></div>
                <h3 class="hist-subhead" id="rptHistPeakSubhead"></h3>
                <div class="chart-card chart-wrap" id="rptHistCardPeak"><div class="svg-tooltip" id="rptHistTooltipPeak"></div></div>
            </section>

            <section>
                <h2 id="rptClusterViewTitle">Active memory % over time &middot; clusters crossing a threshold</h2>
                <div class="rpt-view-switch" role="group" aria-label="Analytics chart view">
                    <b>View</b>
                    <button type="button" class="btn btn-sm" id="rptClusterMatrixButton" aria-pressed="true" onclick="rptSetViewMode('matrix')">Matrix</button>
                    <button type="button" class="btn btn-sm" id="rptClusterTimelineButton" aria-pressed="false" aria-describedby="rptClusterViewHelp" onclick="rptSetViewMode('timeline')">Timeline</button>
                    <span class="view-help" id="rptClusterViewHelp"></span>
                </div>
                <p class="section-sub" id="rptClusterViewDescription">Every cluster (hourly average across its hosts) whose active % was at or above the threshold for at least the given share of its observed time, overlaid. A one-off spike does not qualify a cluster on its own. Hover the chart to pick out one cluster's line, or click the chart to pin the tooltip open so you can scroll its list; click again (or the &#10005;) to release it.</p>
                <div class="threshold-controls">
                    <label for="rptClusterThresholdInput">Active % threshold</label>
                    <input type="number" id="rptClusterThresholdInput" value="25" min="0" max="100" step="1">
                    <label for="rptClusterPersistInput">for at least</label>
                    <input type="number" id="rptClusterPersistInput" value="5" min="0" max="100" step="1">
                    <label for="rptClusterPersistInput">% of observed intervals</label>
                    <span class="count count-emphasis" id="rptClusterThresholdCount"></span>
                </div>
                <div class="chart-card chart-wrap" id="rptClusterOverlayCard"><div class="svg-tooltip" id="rptClusterOverlayTooltip"></div></div>
                <div id="rptClusterCrossingTable"></div>
            </section>

            <section>
                <h2 id="rptHostViewTitle">Active memory % over time &middot; hosts crossing a threshold</h2>
                <div class="rpt-view-switch" role="group" aria-label="Analytics chart view">
                    <b>View</b>
                    <button type="button" class="btn btn-sm" id="rptHostMatrixButton" aria-pressed="true" onclick="rptSetViewMode('matrix')">Matrix</button>
                    <button type="button" class="btn btn-sm" id="rptHostTimelineButton" aria-pressed="false" aria-describedby="rptHostViewHelp" onclick="rptSetViewMode('timeline')">Timeline</button>
                    <span class="view-help" id="rptHostViewHelp"></span>
                </div>
                <p class="section-sub" id="rptHostViewDescription">Hosts whose active % was at or above the threshold for at least the given share of their observed time, overlaid (hourly). A one-off spike does not qualify a host on its own. Hover the chart to pick out one host's line, or click the chart to pin the tooltip open so you can scroll its list; click again (or the &#10005;) to release it.</p>
                <div class="threshold-controls">
                    <label for="rptThresholdInput">Active % threshold</label>
                    <input type="number" id="rptThresholdInput" value="25" min="0" max="100" step="1">
                    <label for="rptPersistInput">for at least</label>
                    <input type="number" id="rptPersistInput" value="5" min="0" max="100" step="1">
                    <label for="rptPersistInput">% of observed intervals</label>
                    <span class="count count-emphasis" id="rptThresholdCount"></span>
                </div>
                <p class="threshold-note" id="rptThresholdNote"></p>
                <div class="chart-card chart-wrap" id="rptOverlayCard"><div class="svg-tooltip" id="rptOverlayTooltip"></div></div>
                <div id="rptHostCrossingTable"></div>
            </section>

            <section id="rptDurationSection">
                <h2>Peak active memory and observed duration</h2>
                <p class="section-sub">A duration curve ranks retained chart intervals from busiest to quietest. It shows how often a high charted Active % occurs, rather than treating a peak as a sustained average. Choose a host or cluster, then inspect the busiest 10% or 15% of observed intervals.</p>
                <div class="rpt-duration-controls">
                    <label>Target type<select id="rptDurationKind"><option value="host">Host</option><option value="cluster">Cluster mean</option></select></label>
                    <label>Search all targets<input type="search" id="rptDurationSearch" placeholder="Host or cluster name"></label>
                    <label>Target<select id="rptDurationTarget"></select></label>
                    <button type="button" class="btn btn-sm" id="rptDurationPrev" onclick="rptDurationPage--;rptRenderDuration()">Previous targets</button>
                    <button type="button" class="btn btn-sm" id="rptDurationNext" onclick="rptDurationPage++;rptRenderDuration()">Next targets</button>
                    <label>Active threshold (%)<input type="number" id="rptDurationThreshold" value="25" min="0" max="100" step="1"></label>
                    <label>Busiest intervals (%)<input type="number" id="rptDurationPercent" value="10" min="0" max="100" step="1"></label>
                </div>
                <p id="rptDurationCount" class="count"></p><p id="rptDurationSummary" role="status"></p>
                <div class="chart-card chart-wrap" id="rptDurationCard"><div class="svg-tooltip" id="rptDurationTooltip"></div></div>
                <p class="rpt-duration-note">Shares are calculated over available retained chart intervals, not the full wall-clock window. Missing intervals are not filled. Coarse averages and per-bin maxima cannot establish how long a shorter raw spike lasted. A reported host peak may be finer than the chart data; summary-only files do not establish peak duration.</p>
            </section>
            <section>
                <h2>Per-cluster and per-host breakdowns</h2>
                <p class="section-sub">Both lists default to Avg Active % descending. Every available host and cluster is searchable and sortable; pagination limits rendered rows without dropping data. Avg Active % is the mean of available averages. Cluster peak % sums reported host peaks against reported capacity; host peaks may occur at different times. Configuration and missing-data notes remain visible; these views do not certify sizing or savings.</p>
                <div id="rptClusterBreakdownTable"></div><div id="rptHostBreakdownTable"></div>
            </section>

            <div class="rpt-footer" id="rptFooter"></div>
          </div>
        </div>
    </div>

    <div id="tab-simulator" class="tab-content" role="tabpanel" aria-labelledby="btn-tab-simulator">
        <div class="rep-toolbar" id="repToolbarSim" style="display:none;"><span class="rep-toolbar-note">Printable report for this step</span><button class="btn btn-sm btn-green" onclick="openReportDialog('sizing')" title="Create a printable report you can save as PDF">Export Sizing &amp; Savings Report</button></div>
        <div class="rep-card-top" id="repCardTop" style="display:none;"><div><div class="rep-title">Customer report</div><div class="rep-desc">Create a printable report with the assessment, advanced analytics and the full savings picture, ready to present. It shows the highest supported savings alongside the recommended 1:1 figure, with every assumption listed.</div></div>
                <div class="rep-btns"><button class="btn btn-green" onclick="openReportDialog('all')">Generate customer report</button></div></div>
        <div class="info-panel-box" style="margin-bottom: 20px;">&#9432; <strong>Note:</strong> All figures are estimated projections based on your cluster's peak Active Memory usage (worst-case) alongside average CPU and Consumed Memory, plus user-entered pricing. They are intended for planning purposes only and do not represent a formal quote or guaranteed outcome.</div>
        <div class="control-grid" style="grid-template-columns: 1fr 1fr; gap:15px; align-items: flex-end; margin-bottom: 20px;">
            <div class="input-group">
                <label for="simClusterSelect">Target Simulation Cluster</label>
                <select id="simClusterSelect" onchange="loadClusterSimulation()"></select>
            </div>
            <div class="input-group">
                <label for="simStrategy">Simulation Strategy</label>
                <select id="simStrategy" onchange="toggleSimStrategy()" style="font-weight:bold; border-color:var(--text-accent); color:var(--text-accent-hover);">
                    <option value="brownfield">Brownfield (Expand Existing Hosts with NVMe)</option>
                    <option value="greenfield">Greenfield (Hardware Refresh &amp; Consolidation)</option>
                </select>
            </div>
        </div>

        <div id="brownfield-controls" class="control-grid" style="grid-template-columns: 2fr 1.5fr 1.5fr; gap:15px; align-items: flex-end; margin-bottom: 20px;">
            <div class="input-group">
                <label for="simInputMode">Sizing Input Mode</label>
                <select id="simInputMode" onchange="toggleSizingMode()" style="font-weight:bold;">
                    <option value="ratio">Configure by Target Ratio</option>
                    <option value="drive">Configure by NVMe Drive Size</option>
                    <option value="custom">Configure by Custom NVMe %</option>
                </select>
            </div>
            <div class="input-group" id="wrapperSimRatio">
                <label for="simRatio">Simulated Tier Ratio</label>
                <select id="simRatio" onchange="runSimulationMath()">
                    <option value="1" selected>1:1 (100% NVMe)</option>
                    <option value="2">1:2 (200% NVMe)</option>
                    <option value="3">1:3 (300% NVMe)</option>
                    <option value="4">1:4 (400% NVMe)</option>
                </select>
            </div>
            <div class="input-group" id="wrapperSimDrive" style="display:none;">
                <label for="simDriveSize">Drive Size per Host</label>
                <select id="simDriveSize" onchange="runSimulationMath()">
                    <option value="800" selected>800 GB Mixed Use NVMe (3 DWPD)</option>
                    <option value="1600">1.6 TB Mixed Use NVMe (3 DWPD)</option>
                    <option value="3200">3.2 TB Mixed Use NVMe (3 DWPD)</option>
                    <option value="6400">6.4 TB Mixed Use NVMe (3 DWPD)</option>
                </select>
            </div>
            <div class="input-group" id="wrapperSimCustom" style="display:none;">
                <label for="customPct">Custom NVMe % (vs DRAM)</label>
                <input type="number" id="customPct" value="150" min="0" step="10" oninput="runSimulationMath()" style="padding:7px; font-weight:bold; border-radius:4px; border:1px solid var(--border-input); height:41px;">
            </div>
        </div>

        <div id="greenfield-controls" style="display:none; background:var(--soft-bg-accent); border:1px solid var(--soft-border-accent); padding:20px; border-radius:6px; margin-bottom: 20px;">
            <div style="display: grid; grid-template-columns: 1.2fr 1fr 1fr 1fr; gap: 15px; align-items: flex-end;">
                <div class="input-group">
                    <label for="gfInputMode">Sizing Strategy Mode</label>
                    <select id="gfInputMode" onchange="toggleGfInputMode()" style="font-weight:bold; color:var(--text-accent-hover);">
                        <option value="capacity" selected>Target Node Size (Calc Host Count)</option>
                        <option value="hosts">Target Usable Hosts (Calc Node Size)</option>
                    </select>
                </div>
                
                <div class="input-group" id="gfWrapCap">
                    <label for="gfNodeCapSelect">Target Node Capacity (GB)</label>
                    <div style="display: flex; gap: 10px;">
                        <select id="gfNodeCapSelect" onchange="handleGfCapChange()" style="font-weight:bold; flex-grow:1;">
                            <option value="137.438953472">137.439 GB</option>
                            <option value="274.877906944">274.878 GB</option>
                            <option value="549.755813888">549.756 GB</option>
                            <option value="824.633720832">824.634 GB</option>
                            <option value="1099.511627776">1.1 TB (1,099.512 GB)</option>
                            <option value="1649.267441664">1.649 TB (1,649.267 GB)</option>
                            <option value="2199.023255552" selected>2.199 TB (2,199.023 GB)</option>
                            <option value="3298.534883328">3.299 TB (3,298.535 GB)</option>
                            <option value="4398.046511104">4.398 TB (4,398.047 GB)</option>
                            <option value="6597.069766656">6.597 TB (6,597.07 GB)</option>
                            <option value="8796.093022208">8.796 TB (8,796.093 GB)</option>
                            <option value="custom">Custom...</option>
                        </select>
                        <input type="number" id="gfNodeCapCustom" value="2199.023" min="1" step="0.001" oninput="runSimulationMath()" style="display:none; width: 80px; padding: 10px;">
                    </div>
                </div>
                
                <div class="input-group" id="gfWrapHosts" style="display:none;">
                    <label for="gfTargetHosts">Target Usable Hosts</label>
                    <input type="number" id="gfTargetHosts" value="4" min="1" step="1" oninput="runSimulationMath()" style="font-weight:bold;">
                </div>

                <div class="input-group">
                    <label for="gfRatio">Greenfield Tier Ratio</label>
                    <select id="gfRatio" onchange="runSimulationMath()">
                        <option value="1" selected>1:1 (100% NVMe)</option>
                        <option value="2">1:2 (200% NVMe)</option>
                        <option value="3">1:3 (300% NVMe)</option>
                        <option value="4">1:4 (400% NVMe)</option>
                    </select>
                    <div id="gfRatioPreview" style="font-size:11px; color:var(--text-muted); margin-top:5px;"></div>
                </div>
                <div class="input-group">
                    <label for="gfHa">HA / Redundancy Nodes</label>
                    <select id="gfHa" onchange="runSimulationMath()">
                        <option value="0">+0 Nodes (No HA)</option>
                        <option value="1" selected>+1 Node (N+1 HA)</option>
                        <option value="2">+2 Nodes (N+2 HA)</option>
                    </select>
                </div>
            </div>
            <div style="display: grid; grid-template-columns: 1fr 2fr; gap: 15px; align-items: flex-end; padding-top: 15px; border-top: 1px dashed var(--soft-border-accent); margin-top: 15px;">
                <div class="input-group">
                    <label for="gfServerCost">Bare-Metal Server Chassis Cost ($)</label>
                    <input type="number" id="gfServerCost" value="15000" min="0" oninput="runSimulationMath()">
                </div>
                <div class="input-group" id="gfWrapCpu">
                    <label for="gfCpuMult">New Node CPU Capacity <span style="font-weight:normal; font-style:italic; color:var(--text-muted);">(Sizing only - no cost impact)</span></label>
                    <select id="gfCpuMult" onchange="runSimulationMath()">
                        <option value="1.0" selected>1.0x (Match Existing Nodes)</option>
                        <option value="1.25">1.25x (+25% Compute)</option>
                        <option value="1.5">1.50x (+50% Compute)</option>
                        <option value="2.0">2.00x (+100% Compute)</option>
                        <option value="3.0">3.00x (+200% Compute)</option>
                    </select>
                </div>
            </div>
        </div>

        <div id="shared-costs" class="form-panel" style="display: grid; grid-template-columns: 1.5fr 1.5fr 2fr; gap: 20px; margin-bottom: 25px; padding: 15px 25px; align-items: flex-end;">
            <div class="input-group">
                <label for="costDram">DRAM Quote Price ($ per GB)</label>
                <input type="number" id="costDram" value="100.00" min="0" step="1.00" oninput="runSimulationMath()">
            </div>
            <div class="input-group">
                <label for="costNvme">NVMe SSD Price ($ per GB)</label>
                <input type="number" id="costNvme" value="0.25" min="0" step="0.05" oninput="runSimulationMath()">
            </div>
            <div class="input-group" style="height:41px; justify-content:center;">
                <div class="checkbox-row" style="margin:0;">
                    <input type="checkbox" id="chkMirroring" checked onchange="runSimulationMath()">
                    <label for="chkMirroring" style="cursor:pointer; font-weight:bold; color:var(--text-secondary);">Account for NVMe Software Mirroring</label>
                </div>
            </div>
        </div>

        <div id="simLockoutPanel" class="lockout-msg" style="padding: 45px; border: 1px dashed var(--border-input); background: var(--surface-card); border-radius: 6px;">
            No hardware profiles collected for this target cluster segment.<br><br>
            <button class="btn btn-green" style="width:auto; padding: 10px 35px;" onclick="switchTab('tab-baseline', document.getElementById('btn-tab-baseline'))">Jump to Step 2 to Run Analysis</button>
        </div>

        <div id="content-simulator" style="display: none;">
            <div id="simTieringActiveAlert" class="warn-panel-box" style="display:none; margin-bottom: 20px; margin-top: 0;" role="status" aria-live="polite"></div>
            <!-- Moved to the top of the tab (was previously below the results, easy to miss) -- this
                 explains WHY the host count/cost came out the way it did, so it should land before
                 the reader gets to the numbers, not after. -->
            <div id="simCeilingWarningCard" class="info-panel-box" style="display:none; margin-bottom: 20px;" role="status" aria-live="polite"></div>
            <div id="gfSmallDramWarn" class="warn-panel-box" style="display:none; margin-bottom: 20px;" role="alert" aria-live="polite"></div>

            <div id="brownfield-results" class="sim-panel">
                <div class="panel-title">Brownfield Expansion Results:</div>
                <div class="sim-grid">
                    <div class="sim-math-box">
                        <div class="math-row"><span style="font-weight:bold;">Cluster DRAM (Tier 0):</span><span id="bfDram">0 GB</span></div>
                        <div class="math-row" style="font-size:12px; color:var(--text-muted); margin-top:-8px; padding-bottom:8px; border-bottom:1px dashed var(--border);"><span style="font-style:italic;">&#9492; Average per Host:</span><span id="bfDramPerHost">0 GB</span></div>
                        
                        <div class="math-row"><span style="font-weight:bold;">Cluster NVMe (Tier 1):</span><span id="bfNvme" style="color:var(--text-accent); font-weight:bold;">+ 0 GB</span></div>
                        <div class="math-row" style="font-size:12px; color:var(--text-muted); margin-top:-8px;"><span style="font-style:italic;">&#9492; Provisioned per Host:</span><span id="bfNvmePerHost" style="color:var(--text-accent);">+ 0 GB</span></div>
                        
                        <div class="math-row" style="border-top:1px solid var(--border-input); padding-top:10px; margin-top:5px;"><span style="font-weight:bold; font-size:15px;">Total Tiered Memory:</span><span id="bfTotal">= 0 GB</span></div>
                        <div class="math-row" style="color:var(--text-danger-strong);"><span style="font-weight:bold;" id="bfCostLabel">Simulated NVMe Cost:</span><span id="bfCost" style="font-weight:bold;">$0.00</span></div>
                        <div class="math-row" style="border-top:1px dotted var(--border-input); padding-top:10px; margin-top:5px; color:var(--text-success);"><span style="font-weight:bold; font-size:14px;" id="bfSavingsLabel">Net CapEx Saved:</span><span id="bfSavings" style="font-weight:bold;">$0.00</span></div>
                    </div>
                    <div>
                        <div class="metric-row" style="justify-content:space-between;"><span class="metric-name">Active vs DRAM</span><div class="metric-value"><span id="bfActiveVal">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="bfActiveBar"></div></div></div><span class="badge" id="bfActiveBadge"></span></div>
                        <div class="metric-row" style="justify-content:space-between;"><span class="metric-name">Total Capacity Used</span><div class="metric-value"><span id="bfCapacityVal">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="bfCapacityBar"></div></div></div><span class="badge badge-info">[ i ] INFO</span></div>
                    </div>
                </div>
                
                <div class="headroom-banner">
                    <div class="headroom-text">
                        <div class="headroom-title">Projected VM Density Expansion</div>
                        <div class="headroom-desc">Estimated additional compute slots gained (assumes 17.180 GB VM profile sizing)</div>
                    </div>
                    <div class="headroom-value" id="bfHeadroom">+ 0 VMs</div>
                </div>

                <div style="margin-top: 15px; border-top: 1px dashed var(--border-input); padding-top: 12px; font-size: 14px;">
                    <span style="font-weight: bold; color: var(--text-accent-hover); margin-right: 8px;">Minimum Sizing Spec:</span>
                    <span id="bfDriveReqLabel" style="font-weight: bold; color: var(--text-primary);">0 GB / Host</span>
                </div>
            </div>

            <div id="greenfield-results" style="display:none;">
                <div class="gf-sim-grid">
                    <div class="gf-card">
                        <div class="gf-card-title">Option A: Standard Refresh</div>
                        <div class="math-row" style="margin-bottom:8px;"><span style="color:var(--text-muted);">Architecture:</span><span style="font-weight:bold;">100% DRAM</span></div>
                        <div class="math-row" style="margin-bottom:8px;"><span style="color:var(--text-muted);">Node Profile:</span><span id="gfStdProfile" style="font-weight:bold;">0 GB / Host</span></div>
                        <div class="math-row" style="margin-bottom:8px; border-top:1px dashed var(--border); padding-top:8px;"><span style="color:var(--text-muted);">Total Hosts Required:</span><span id="gfStdHosts" style="font-weight:bold; color:var(--text-accent-hover); font-size:16px;">0</span></div>
                        <div class="math-row" style="margin-bottom:8px;"><span style="color:var(--text-muted);">Host Consolidation:</span><span id="gfStdConsol" style="font-weight:bold; color:var(--text-success);">0 &rarr; 0</span></div>
                        <div class="math-row" style="margin-top:15px; padding-top:12px; border-top:2px solid var(--border);"><span style="font-weight:bold; font-size:15px;">Total Cluster Cost:</span><span id="gfStdCost" style="font-weight:bold; font-size:15px; color:var(--text-danger-strong);">$0.00</span></div>
                    </div>
                    <div class="gf-card" style="border-color:var(--soft-border-accent); box-shadow: 0 4px 8px rgba(0,120,215,0.05);">
                        <div class="gf-card-title" style="color:var(--text-accent); border-bottom-color:var(--soft-border-accent);">Option B: Tiered Refresh</div>
                        <div class="math-row" style="margin-bottom:8px;"><span style="color:var(--text-muted);">Architecture:</span><span style="font-weight:bold; color:var(--text-accent);">Memory Tiering over NVMe</span></div>
                        <div class="math-row" style="margin-bottom:8px;"><span style="color:var(--text-muted);">Node Profile:</span><span id="gfTierProfile" style="font-weight:bold;">0 GB + 0 GB NVMe</span></div>
                        <div class="math-row" style="margin-bottom:8px; border-top:1px dashed var(--border); padding-top:8px;"><span style="color:var(--text-muted);">Total Hosts Required:</span><span id="gfTierHosts" style="font-weight:bold; color:var(--text-accent-hover); font-size:16px;">0</span></div>
                        <div class="math-row" style="margin-bottom:8px;"><span style="color:var(--text-muted);">Host Consolidation:</span><span id="gfTierConsol" style="font-weight:bold; color:var(--text-success);">0 &rarr; 0</span></div>
                        <div class="math-row" style="margin-top:15px; padding-top:12px; border-top:2px solid var(--border);"><span style="font-weight:bold; font-size:15px;">Total Cluster Cost:</span><span id="gfTierCost" style="font-weight:bold; font-size:15px; color:var(--text-success);">$0.00</span></div>
                    </div>
                </div>
                
                <div class="gf-savings-banner">
                    <div class="gf-savings-text">Net CapEx Savings vs Standard Refresh</div>
                    <div class="gf-savings-amount" id="gfTotalSavings">$0.00</div>
                    <div style="font-size:13px; color:var(--text-success-soft); margin-top:8px; font-weight:normal;" id="gfSavingsDetail">Includes Server Hardware and Memory Media</div>
                </div>
                
                <div class="sim-panel" style="margin-top:20px; background:var(--surface-card); border-color:var(--border);">
                    <div class="panel-title" style="font-size:13px; color:var(--text-secondary);">Tiered Cluster Telemetry Forecast:</div>
                    <div class="metric-row" style="justify-content:flex-start; margin-bottom:8px;"><span class="metric-name" style="width:180px;">Projected Active Memory</span><div class="metric-value" style="width:100px;"><span id="gfActiveVal">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="gfActiveBar"></div></div></div><span class="badge" id="gfActiveBadge"></span></div>
                    <div class="metric-row" style="justify-content:flex-start; margin-bottom:0;"><span class="metric-name" style="width:180px;">Projected Capacity Used</span><div class="metric-value" style="width:100px;"><span id="gfCapacityVal">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="gfCapacityBar"></div></div></div><span class="badge badge-info" style="min-width:60px;">[ i ] INFO</span></div>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
    // Capacity and prices use decimal GB (1,000,000,000 bytes); TB is 1,000 GB.
    // Preserve the physical memory profiles, DIMM steps and kernel limit in bytes.
    var MT_LEGACY_GB_FACTOR = 1.073741824;
    var MT_DRAM_STEP_GB = 68.719476736, MT_MIN_DRAM_GB = 137.438953472;
    var MT_DEFAULT_NODE_GB = 2199.023255552, MT_NVME_LIMIT_GB = 4398.046511104;
    var MT_VM_PROFILE_GB = 17.179869184;
    function mtRoundGb(v) { return Math.round(v * 1000) / 1000; }
    function mtGbText(v) { return Number(v).toLocaleString('en-US', { maximumFractionDigits: 3 }); }
    function mtDriveText(v) { return v >= 1000 ? (Math.ceil(v / 10 - 1e-10) / 100).toFixed(2) + ' TB' : Math.ceil(v) + ' GB'; }
    function mtDramCeil(v) { return Math.ceil(v / MT_DRAM_STEP_GB - 1e-10) * MT_DRAM_STEP_GB; }
    // Unmarked MTAT CSVs predate decimal GB. New exports explicitly carry Memory_Unit=GB.
    function mtCsvGb(row, field) {
        var unit = String(row.Memory_Unit || '').trim().toUpperCase();
        if (unit && unit !== 'GB' && unit !== 'GIB') throw new Error('Unsupported Memory_Unit: ' + unit);
        var value = parseNum(row[field]);
        return isFinite(value) ? mtRoundGb(value * (unit === 'GB' ? 1 : MT_LEGACY_GB_FACTOR)) : NaN;
    }
    // Entirely unavailable CPU remains N/A (for example VCF Operations). A partially
    // measured fleet is incomplete: do not size a refresh from just its known hosts.
    function mtMarkMissingCpu(hosts) {
        var good = mtGoodHosts(hosts);
        var anyKnown = good.some(function(h) { return typeof h.CPU_Pct === 'number' && isFinite(h.CPU_Pct); });
        if (!anyKnown) return;
        good.forEach(function(h) {
            if (typeof h.CPU_Pct === 'number' && isFinite(h.CPU_Pct)) return;
            var miss = String(h.Missing_Metrics || '').split(/,\s*/).filter(Boolean);
            if (miss.indexOf('CPU') < 0) miss.push('CPU');
            h.Missing_Metrics = miss.join(', ');
        });
    }

    var globalDram = 0, globalConsumed = 0, globalActive = 0, globalActiveAvg = null, globalCpu = 0, selectedRangeName = "";
    var cachedHosts = [], cachedVms = [], cachedFailedVms = [];
    var clusterSessionCache = {};

    var missedBeats = 0;
    var analysisInProgress = false;
    
    setInterval(function() {
        fetch('/api/heartbeat', { method: 'POST' })
        .then(function(response) {
            if (response.ok) { missedBeats = 0; } 
            else { missedBeats++; }
            evaluateEngineHealth();
        })
        .catch(function() {
            missedBeats++;
            evaluateEngineHealth();
        });
    }, 5000);

    function evaluateEngineHealth() {
        if (analysisInProgress) { missedBeats = 0; return; }
        // This is a DIFFERENT, faster check than the server's own 5-minute idle dead-man's-switch --
        // it fires after ~1 minute (12 missed 5-second heartbeats) of this specific browser tab
        // failing to reach the engine at all (network drop, engine process crashed/exited, etc.),
        // not after minutes of genuine inactivity. The two are easy to conflate but describe
        // different things; keep this message worded to match what actually triggers it.
        if (missedBeats >= 12) {
            document.body.innerHTML = `
                <div style='text-align:center; padding:100px; font-family:sans-serif;'>
                    <h2 style='color:var(--text-danger-strong);'>Session Timed Out</h2>
                    <p style='color:var(--text-secondary); font-size:16px; font-weight:bold;'>The connection to the background engine was lost.</p>
                    <p style='color:var(--text-muted); font-size:14px; line-height:1.6; max-width:600px; margin:0 auto;'>
                        This tab could not reach the MTAT background engine for about 1 minute -- it may have crashed, been closed, or the network path to it dropped. (Separately, to conserve system resources, the engine also shuts itself down automatically after 10 minutes with no connected tab at all.)<br><br>
                        <b>Please close this tab and run the MTAT application again.</b>
                    </p>
                </div>`;
        }
    }

    // ---- Light/dark theme toggle -----------------------------------------------------------
    // The actual attribute is already set pre-paint by the inline <script> in <head> (reads
    // localStorage, falls back to nothing so the plain @media(prefers-color-scheme) CSS rules
    // apply). This just keeps the button label in sync and persists an explicit user choice.
    function currentEffectiveTheme() {
        var explicit = document.documentElement.getAttribute('data-theme');
        if (explicit === 'dark' || explicit === 'light') { return explicit; }
        return (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) ? 'dark' : 'light';
    }
    function refreshThemeToggleLabel() {
        var label = document.getElementById('themeToggleLabel');
        if (label) { label.innerText = (currentEffectiveTheme() === 'dark') ? 'Light Mode' : 'Dark Mode'; }
    }
    function toggleTheme() {
        var next = (currentEffectiveTheme() === 'dark') ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        try { localStorage.setItem('mtatTheme', next); } catch (e) { /* private mode etc -- toggle still works for this tab */ }
        refreshThemeToggleLabel();
    }
    refreshThemeToggleLabel();

    function escapeHtml(str) {
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    // ---- Toast/status queue: non-blocking replacement for alert() ----
    var toastCounter = 0;
    function showToast(message, type) {
        type = type || 'info';
        var stack = document.getElementById('toastStack');
        if (!stack) { window.alert(message); return; }
        var id = 'toast-' + (++toastCounter);
        var item = document.createElement('div');
        item.className = 'toast-item toast-' + type;
        item.id = id;
        item.innerHTML = escapeHtml(message).replace(/\n/g, '<br>') +
            '<button class="toast-close" onclick="dismissToast(\'' + id + '\')" aria-label="Dismiss">x</button>';
        stack.appendChild(item);
        setTimeout(function() { dismissToast(id); }, type === 'error' ? 12000 : 7000);
    }
    function dismissToast(id) {
        var item = document.getElementById(id);
        if (item && item.parentNode) { item.parentNode.removeChild(item); }
    }

    // ---- Lightweight percentage bars (checklist + sizing tab, no charting library) ----
    function setPctBar(elId, pct, opts) {
        var el = document.getElementById(elId);
        if (!el) { return; }
        var num = parseFloat(pct);
        if (isNaN(num)) { num = 0; }
        var clamped = Math.max(0, Math.min(100, num));
        el.style.width = clamped + '%';
        el.className = 'pct-bar-fill';
        if (opts && opts.pass === true) { el.className += ' pct-bar-pass'; }
        else if (opts && opts.pass === false) { el.className += ' pct-bar-warn'; }
    }

    // Renders a "value% + tiny bar" cell for static innerHTML tables (Range Comparison Matrix)
    // where there's no live element to update later -- unlike setPctBar(), this returns markup.
    function pctBarCellHtml(valueText, numericPct) {
        var w = Math.max(0, Math.min(100, parseFloat(numericPct) || 0));
        return valueText + '%<div class="pct-bar-track"><div class="pct-bar-fill" style="width:' + w + '%"></div></div>';
    }

    // ---- Host/VM table sort + filter (client-side, no server round-trip) ----
    function sortTableByHeader(th) {
        var table = th.closest('table');
        if (!table) { return; }
        var headerRow = th.parentNode;
        var colIndex = Array.prototype.indexOf.call(headerRow.children, th);
        var isNumeric = th.getAttribute('data-type') === 'num';
        var tbody = table.querySelector('tbody');
        var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
        var asc = th.getAttribute('data-sort-dir') !== 'asc';
        rows.sort(function(a, b) {
            var av = (a.children[colIndex] ? a.children[colIndex].innerText : '').trim();
            var bv = (b.children[colIndex] ? b.children[colIndex].innerText : '').trim();
            if (isNumeric) {
                var an = parseFloat(av.replace(/[^0-9.\-]/g, '')) || 0;
                var bn = parseFloat(bv.replace(/[^0-9.\-]/g, '')) || 0;
                return asc ? (an - bn) : (bn - an);
            }
            return asc ? av.localeCompare(bv) : bv.localeCompare(av);
        });
        rows.forEach(function(r) { tbody.appendChild(r); });
        var allHeaders = headerRow.querySelectorAll('th.sortable');
        for (var i = 0; i < allHeaders.length; i++) {
            allHeaders[i].removeAttribute('data-sort-dir');
            var arrow = allHeaders[i].querySelector('.sort-arrow');
            if (arrow) { arrow.textContent = ''; }
        }
        th.setAttribute('data-sort-dir', asc ? 'asc' : 'desc');
        var thisArrow = th.querySelector('.sort-arrow');
        if (thisArrow) { thisArrow.textContent = asc ? ' ^' : ' v'; }
        mtatInitSortHints();
    }
    function filterTableRows(inputEl, tbodySelector) {
        var q = inputEl.value.toLowerCase();
        var rows = document.querySelectorAll(tbodySelector + ' tr');
        for (var i = 0; i < rows.length; i++) {
            rows[i].style.display = (rows[i].textContent.toLowerCase().indexOf(q) > -1) ? '' : 'none';
        }
    }

    // ---- Per-target progress chips for multi-minute connect/analyze operations ----
    function buildProgressChips(containerId, labels) {
        var box = document.getElementById(containerId);
        if (!box) { return; }
        box.innerHTML = '';
        box.style.display = 'flex';
        for (var i = 0; i < labels.length; i++) {
            var chip = document.createElement('span');
            chip.className = 'progress-chip chip-running';
            chip.id = containerId + '-chip-' + i;
            chip.innerHTML = '<span class="chip-spinner"></span><span>' + escapeHtml(labels[i]) + '</span>';
            box.appendChild(chip);
        }
    }
    function setProgressChipState(containerId, index, state, label) {
        var chip = document.getElementById(containerId + '-chip-' + index);
        if (!chip) { return; }
        chip.className = 'progress-chip chip-' + state;
        var icon = state === 'done' ? '[ OK ]' : (state === 'failed' ? '[ X ]' : '');
        chip.innerHTML = (state === 'running' ? '<span class="chip-spinner"></span>' : '') +
            '<span>' + (icon ? icon + ' ' : '') + escapeHtml(label) + '</span>';
    }
    function clearProgressChips(containerId) {
        var box = document.getElementById(containerId);
        if (!box) { return; }
        box.innerHTML = '';
        box.style.display = 'none';
    }

    // Persists the current + latest PowerCLI version info into the main UI as a fallback, in
    // case the splash screen's redirect-on-ping-success wins the race against the background
    // version-check job finishing (that job usually starts before the splash screen even loads,
    // but it's a best-effort live network call, so it isn't guaranteed to finish fast).
    var versionInfoPollHandle = null;
    function paintMainVersionInfo(info) {
        var box = document.getElementById('mainVerInfo');
        if (!box || !info) { return; }
        var stillChecking = (info.Status !== "done");
        var latestPcliText = info.LatestPowerCli ? info.LatestPowerCli : (stillChecking ? "checking..." : "unable to check");
        box.innerHTML = "PowerCLI " + escapeHtml(info.CurrentPowerCli) + " (latest: " + escapeHtml(latestPcliText) + ")";
        if (!stillChecking && versionInfoPollHandle) {
            clearInterval(versionInfoPollHandle);
            versionInfoPollHandle = null;
        }
    }
    function pollMainVersionInfo() {
        fetch('/api/get-version-info')
        .then(function(response) { return response.json(); })
        .then(paintMainVersionInfo)
        .catch(function(){});
    }
    pollMainVersionInfo();
    versionInfoPollHandle = setInterval(pollMainVersionInfo, 3000);

    function enableOfflineMode() {
        mtatOfflineMode = true; mtatShowOfflineSaved = false; mtatSyncJobVisibility();
        document.getElementById('content-baseline').style.display = 'block';
        document.getElementById('lockout-baseline').style.display = 'none';
        document.getElementById('btn-tab-baseline').style.display = 'block';
        document.getElementById('btn-tab-simulator').style.display = 'block';
        document.getElementById('btn-tab-advanced').style.display = 'block';
        
        // Offline Mode opens on VCF Operations, the most common no-vCenter source; the other formats
        // stay one dropdown change away. Live-mode imports keep their own default (MTAT Export).
        document.getElementById('importSourceType').value = 'vrops';
        var panel = document.getElementById('importPanel');
        if (panel && panel.style.display === 'none') {
            toggleImportPanel();
        } else {
            toggleImportSourceFields();
        }

        // Hide normal online mode elements
        var scopePanel = document.getElementById('scopeSelectionPanel');
        if (scopePanel) scopePanel.style.display = 'none';
        
        var analyzeBtnWrap = document.getElementById('analyzeBtn').parentNode;
        if (analyzeBtnWrap) analyzeBtnWrap.style.display = 'none';

        // Add "Offline Mode" subtitle
        var importTitle = document.querySelector('#importPanel .panel-title');
        if (importTitle && !importTitle.innerHTML.includes('Offline Mode')) {
            importTitle.innerHTML = 'Import Previously Collected Data <span style="color:var(--text-accent); font-size:12px; margin-left:10px;">(Offline Mode)</span>';
        }

        switchTab('tab-baseline', document.getElementById('btn-tab-baseline'));
        showToast("Offline Mode enabled. You can now import files without a vCenter connection.", 'info');
    }

    function shutdownServer() {
        if(confirm("Are you sure you want to shut down the background MTAT engine?")) {
            document.body.innerHTML = "<div style='text-align:center; padding:100px; font-family:sans-serif;'><h2>MTAT Engine Safely Terminated</h2><p style='color:var(--text-muted); font-size:18px;'>The background PowerShell process has been successfully killed.<br><br><b>You may now safely close this browser tab.</b></p></div>";
            fetch('/api/shutdown', { method: 'POST' }).catch(function(){});
            setTimeout(function() { window.close(); }, 1500);
        }
    }

    // Pulls this run's log (lifecycle events, plus per-analysis host/VM counts and any collection
    // failures -- see the [analyze] entries) so it can be attached to a bug report. Needed because
    // a -noConsole compiled build has no visible window to read the log from otherwise.
    function downloadDebugLog() {
        fetch('/api/get-debug-log')
        .then(function(response) { return response.json(); })
        .then(function(data) {
            if (data.error && !data.content) { showToast("Could not read the debug log: " + data.error, 'error'); return; }
            if (obfOn()) {
                downloadBlobTrigger(obfuscateLogText(data.content || "(log is empty)"), "MTAT_debug_log_hidden_names.txt");
                showToast("Debug log downloaded with real names hidden. Review it before sharing: text MTAT never showed on screen (for example inside a raw error message) cannot be recognized.", 'info');
                return;
            }
            downloadBlobTrigger(data.content || "(log is empty)", "MTAT_debug_log.txt");
        })
        .catch(function(err) { showToast("Could not reach the engine to fetch the debug log: " + err.message, 'error'); });
    }

    // ======================= ADVANCED ANALYTICS TAB =======================
    // A port of host_metrics_report.py's report.html (same sections, charts, tooltips, pinning, tenant
    // filter, thresholds and sortable table), fed from clusterSessionCache instead of a pre-built
    // SQLite pipeline. rptBuildModel() reshapes whatever Step 2 analyzed or imported into the report's
    // own DATA / ACTIVE / HOSTACTIVE / PROVCONS / TENANT shapes, so the render code below stays close
    // to the original. No engine calls are made from this tab.
    var ADV_FLEET = "__fleet__";
    var RPT = null;
    function advClusterLabel(key) {
        var parts = key.split('|');
        if (parts.length < 2) return key;
        var liveLabel = (typeof liveClusterLabels !== 'undefined') ? liveClusterLabels[key] : null;
        var server = liveLabel ? liveLabel.server : parts[0], cluster = liveLabel ? liveLabel.cluster : parts.slice(1).join('|');
        if (obfOn()) {
            if (!OBF_SYNTHETIC_PREFIX[server]) server = obfName('server', server);
            cluster = obfName('cluster', cluster);
        }
        return cluster + " (" + server + ")";
    }
    function advClusterKeys() {
        return Object.keys(clusterSessionCache).filter(function(k) {
            var r = clusterSessionCache[k].ranges; return r && Object.keys(r).length > 0;
        });
    }
    function refreshAdvancedTab(preferredKey, preferredRange) {
        var keys = advClusterKeys();
        document.getElementById('advLockout').style.display = keys.length ? 'none' : 'block';
        document.getElementById('advContent').style.display = keys.length ? 'block' : 'none';
        if (!keys.length) return;
        rptBindOnce();
        var sel = document.getElementById('advClusterSelect');
        var prev = preferredKey || sel.value;
        sel.innerHTML = '';
        var frag = document.createDocumentFragment();
        if (keys.length > 1) {
            var fo = document.createElement('option'); fo.value = ADV_FLEET; fo.textContent = 'All clusters (' + keys.length.toLocaleString() + ')'; frag.appendChild(fo);
        }
        keys.slice().sort(function(a, b) { return advClusterLabel(a).localeCompare(advClusterLabel(b)); }).forEach(function(k) {
            var o = document.createElement('option'); o.value = k; o.textContent = advClusterLabel(k); frag.appendChild(o);
        });
        sel.appendChild(frag);
        var valid = keys.concat(keys.length > 1 ? [ADV_FLEET] : []);
        sel.value = (valid.indexOf(prev) >= 0) ? prev : (keys.length > 1 ? ADV_FLEET : keys[0]);
        onAdvClusterChange(preferredRange);
    }
    function onAdvClusterChange(preferredRange) {
        var selKey = document.getElementById('advClusterSelect').value;
        var cache = clusterSessionCache[selKey];
        var rsel = document.getElementById('advRangeSelect');
        var prev = typeof preferredRange === 'string' ? preferredRange : rsel.value;
        rsel.innerHTML = '';
        var labels = cache ? Object.keys(cache.ranges) : [];
        if (selKey === ADV_FLEET) {
            var seen = {};
            advClusterKeys().forEach(function(k) { Object.keys(clusterSessionCache[k].ranges).forEach(function(l) { seen[l] = true; }); });
            labels = Object.keys(seen);
        }
        labels.forEach(function(l) { var o = document.createElement('option'); o.value = l; o.textContent = l; rsel.appendChild(o); });
        if (labels.indexOf(prev) >= 0) rsel.value = prev; else if (cache && labels.indexOf(cache.lastRange) >= 0) rsel.value = cache.lastRange;
        renderAdvancedAnalytics();
    }
    function renderAdvancedAnalytics() {
        var selKey = document.getElementById('advClusterSelect').value, rangeLabel = document.getElementById('advRangeSelect').value;
        var datasets = [];
        if (selKey === ADV_FLEET) {
            var fleetPairs = [];
            advClusterKeys().forEach(function(k) { var d = clusterSessionCache[k].ranges[rangeLabel]; if (d) fleetPairs.push({ key: k, d: d }); });
            datasets = rptDatasets(fleetPairs);
        } else {
            var cache = clusterSessionCache[selKey], one = cache ? cache.ranges[rangeLabel] : null;
            if (one) datasets.push(one);
        }
        if (!datasets.length) return;
        RPT = rptBuildModel(datasets, rangeLabel);
        rptRenderAll();
    }

    // Candidacy is a cluster-level call (HA/DRS rebalances VMs across hosts), using the same test as the
    // Baseline checklist: cluster peak Active Memory <= 50% of cluster DRAM. Returns {clusterName: bool}.
    // extra[cluster] (optional): DRAM-only VM memory { n, gb, active } and the number of hosts with no
    // Active samples ("missing"), so this agrees with the Baseline checklist and the report.
    function advClusterCandidates(hosts, extra) {
        var sums = {}, out = {};
        hosts.forEach(function(h) {
            var s = sums[h.Cluster] || (sums[h.Cluster] = { dram: 0, active: 0 });
            s.dram += h.Physical_RAM; s.active += Number(h.Active_GB) || 0;
        });
        Object.keys(sums).forEach(function(cl) {
            var e = (extra && extra[cl]) || null;
            out[cl] = sums[cl].dram > 0 && !(e && e.missing) && mtActiveOk(mtActivePct(sums[cl].dram, sums[cl].active, e));
        });
        return out;
    }
    // Analytics groups hosts by cluster name. Two vCenters can each have a "Production" cluster, so
    // when one name comes from more than one cache key, those hosts are relabelled with the key's own
    // label ("Production (vcenter-a)") instead of being merged into one cluster. pairs: [{ key, d }].
    // Windows PowerShell can serialize command-produced arrays as {value:[...],Count:n}.
    // Recover those arrays before any table/model code sees them, including restored checkpoints.
    function mtatAsArray(value, label) {
        var expected = [], own = Object.prototype.hasOwnProperty;
        for (var depth=0; depth<8 && value && typeof value==='object' && !Array.isArray(value); depth++) {
            var vk = own.call(value,'value') ? 'value' : own.call(value,'Value') ? 'Value' : null;
            var ck = own.call(value,'Count') ? 'Count' : own.call(value,'count') ? 'count' : null;
            if (!vk || !ck) break;
            var count=Number(value[ck]);
            if (!isFinite(count) || count<0 || Math.floor(count)!==count) throw new Error('Invalid array count in '+label+'. The saved checkpoint remains available.');
            expected.push(count);value=value[vk];
        }
        var result = Array.isArray(value) ? value : (value===null || value===undefined) ? (expected.length && expected[expected.length-1]===1 ? [null] : []) : [value];
        expected.forEach(function(n){if(n!==result.length)throw new Error('Array length mismatch in '+label+'. The saved checkpoint remains available; no samples were discarded.');});
        return result;
    }
    function mtatNumericSeries(value, label) {
        var a=mtatAsArray(value,label);
        for(var i=0;i<a.length;i++) {
            if(a[i]===null)continue; // A retained gap is never converted to zero.
            if(typeof a[i]==='string' && a[i].trim()!=='' && isFinite(Number(a[i])))a[i]=Number(a[i]);
            if(typeof a[i]!=='number' || !isFinite(a[i]))throw new Error('Unrecognized numeric series in '+label+'. Reload the saved checkpoint with an updated engine; its original data remains on disk.');
        }
        return a;
    }
    function mtatNormalizeAnalysisArrays(data) {
        if(!data || typeof data!=='object')return data;
        ['hosts','vms','failedHosts','failedVms','dataNotes'].forEach(function(k){if(Object.prototype.hasOwnProperty.call(data,k))data[k]=mtatAsArray(data[k],k)});
        var series=data.series;
        if(series && series.hosts && !series._mtatArraysNormalized) {
            Object.keys(series.hosts).forEach(function(host){
                var row=series.hosts[host];if(!row || typeof row!=='object')throw new Error('Invalid host chart data; the saved checkpoint remains available.');
                ['active','consumed','cpu','activeTimestamps','consumedTimestamps','cpuTimestamps'].forEach(function(k){
                    if(Object.prototype.hasOwnProperty.call(row,k))row[k]=mtatNumericSeries(row[k],host+' / '+k);
                });
                ['active','consumed','cpu'].forEach(function(k){var t=row[k+'Timestamps'];if(t && row[k] && t.length!==row[k].length)throw new Error('Timestamp/value length mismatch for '+host+' / '+k+'. No samples were discarded.');});
            });
            Object.defineProperty(series,'_mtatArraysNormalized',{value:true,enumerable:false});
        }
        return data;
    }

    function rptDatasets(pairs) {
        pairs.forEach(function(p){mtatNormalizeAnalysisArrays(p.d)});
        var keysByName = {};
        pairs.forEach(function(p) { (p.d.hosts || []).forEach(function(h) { (keysByName[h.Cluster] = keysByName[h.Cluster] || {})[p.key] = true; }); });
        function clash(h) { return Object.keys(keysByName[h.Cluster] || {}).length > 1; }
        return pairs.map(function(p) {
            if (!(p.d.hosts || []).some(clash)) return p.d;
            var label = advClusterLabel(p.key), copy = {};
            Object.keys(p.d).forEach(function(k) { copy[k] = p.d[k]; });
            copy.hosts = p.d.hosts.map(function(h) {
                if (!clash(h)) return h;
                var h2 = {}; Object.keys(h).forEach(function(k) { h2[k] = h[k]; }); h2.Cluster = label; return h2;
            });
            return copy;
        });
    }

    var RPT_AVG_EDGES = (function() { var e = []; for (var i = 0; i <= 20; i++) e.push(i); for (var j = 25; j <= 60; j += 5) e.push(j); return e; })();
    var RPT_PEAK_EDGES = RPT_AVG_EDGES.concat([70, 80, 90, 100]);
    var RPT_DEFAULT_PROV = 80, RPT_DEFAULT_CONS = 70, RPT_TOP_N = 1000, RPT_HOUR_MS = 3600000;
    function rptBinIndex(v, edges) {
        var n = edges.length - 1;
        if (v >= edges[n]) return n - 1;
        for (var i = 0; i < n; i++) if (edges[i] <= v && v < edges[i + 1]) return i;
        return 0;
    }
    function rptMean(a) { return a.length ? a.reduce(function(s, v) { return s + v; }, 0) / a.length : 0; }
    function rptDay(ms) { return new Date(ms).toISOString().slice(0, 10); }

    function rptBuildModel(datasets, rangeLabel) {
        datasets.forEach(mtatNormalizeAnalysisArrays);
        var isRvtools = false, consumedBases = {}, recs = [], origHosts = [], minT = Infinity, maxT = -Infinity, samples = 0, imp = null, isVrops = false, isOps = false, hasOther = false, hasCpu = false, clusterTs = {};
        datasets.forEach(function(d) {
            if (d.source === 'vrops') consumedBases[d.consumedBasis || 'allocated'] = true;
            if (d.source === 'rvtools') isRvtools = true;
            if (d.source === 'vrops') isVrops = true; else if (d.source === 'ops') isOps = true; else hasOther = true;
            if (d.importMeta) imp = d.importMeta;
            var allocByHost = null;
            if (d.vms && d.vms.length) {
                allocByHost = {};
                d.vms.forEach(function(v) { allocByHost[v.Host] = (allocByHost[v.Host] || 0) + (Number(v.Provisioned_GB) || 0); });
            }
            var ser = (d.series && d.series.hosts) ? d.series : null;
            (d.hosts || []).forEach(function(h) {
                if (h.Tiering === 'ERROR' || !(h.Physical_RAM > 0)) return;
                origHosts.push(h);
                if (mtHas(h, 'Active')) return;
                var cap = (typeof h.Capacity_GB === 'number' && h.Capacity_GB > 0) ? h.Capacity_GB : h.Physical_RAM;
                var r = { id: recs.length, host: h.HostName, cluster: h.Cluster, tenant: h.Tenant || null, cap: cap, prov: h.Physical_RAM,
                          alloc: Number(h.Consumed_GB) || 0, cpu: (typeof h.CPU_Pct === 'number' && !mtHas(h, 'CPU')) ? h.CPU_Pct : null, t: [], act: [], cons: [], cpuCore: (typeof h.CPU_Core_Pct === 'number') ? h.CPU_Core_Pct : null };
                if (r.cpu !== null) hasCpu = true;
                var s = ser ? ser.hosts[h.HostName] : null;
                if (s && s.active) {
                    for (var i = 0; i < s.active.length; i++) {
                        if (s.active[i] === null || s.active[i] === undefined) continue;
                        var t = ser.startMs + i * ser.bucketSeconds * 1000;
                        var cv = (s.consumed && s.consumed[i] !== null && s.consumed[i] !== undefined) ? s.consumed[i] / cap * 100 : null;
                        if (!r.clusterT) r.clusterT = [];
                        r.clusterT.push(t);
                        var actualT = s.activeTimestamps && typeof s.activeTimestamps[i] === 'number' ? s.activeTimestamps[i] : t;
                        r.t.push(actualT); r.act.push(s.active[i] / cap * 100); r.cons.push(cv);
                        if (!r.consT) r.consT = [];
                        r.consT.push(s.consumedTimestamps && typeof s.consumedTimestamps[i] === 'number' ? s.consumedTimestamps[i] : t);
                        if (ser.startMs < minT) minT = ser.startMs;
                        if (actualT < minT) minT = actualT; if (actualT > maxT) maxT = actualT;
                    }
                }
                samples += Math.max(1, r.t.length);
                if (r.act.length) {
                    r.avgPct = (d.source === 'ops' && typeof h.Active_Avg_GB === 'number') ? h.Active_Avg_GB / cap * 100 : rptMean(r.act); r.peakPct = Math.max.apply(null, r.act);
                } else {
                    r.peakPct = (Number(h.Active_GB) || 0) / cap * 100;
                    r.avgPct = ((typeof h.Active_Avg_GB === 'number') ? h.Active_Avg_GB : (Number(h.Active_GB) || 0)) / cap * 100;
                }
                r.activeGB = r.avgPct * cap / 100;
                // "Provisioned %" follows report.html (host provisioned memory / capacity) when the source has
                // both figures (VCF Operations). A live vCenter analysis has no separate capacity figure, so
                // it uses memory configured on powered-on VMs / host DRAM (over-commit) instead.
                if (typeof h.Capacity_GB === 'number' && h.Capacity_GB > 0) r.provPct = h.Physical_RAM / h.Capacity_GB * 100;
                else if (typeof h.VM_Alloc_GB === 'number') r.provPct = h.VM_Alloc_GB / h.Physical_RAM * 100;
                else if (allocByHost) r.provPct = (allocByHost[h.HostName] || 0) / h.Physical_RAM * 100;
                else r.provPct = 100;
                // Hourly VCF Operations series (compact bytes, see vropsTsPut): stats are computed here,
                // and the per-host line is only materialized if a chart actually draws it.
                if (h._ts && d.tsMeta) {
                    var ta = h._ts.act, tc = h._ts.alloc, sA = 0, nA = 0, mA = 0, sC = 0, nC = 0, mC = 0, minC = Infinity, hits = 0;
                    for (var k = 0; k < ta.length; k++) {
                        if (ta[k]) { var av = (ta[k] - 1) / 2.5; sA += av; nA++; if (av > mA) mA = av; }
                        if (tc[k]) { var cv2 = tc[k] - 1; sC += cv2; nC++; if (cv2 > mC) mC = cv2; if (cv2 < minC) minC = cv2; if (r.provPct > RPT_DEFAULT_PROV && cv2 > RPT_DEFAULT_CONS) hits++; }
                    }
                    if (nA) {
                        r.ts = h._ts; r.tsHour0 = d.tsMeta.baseHour;
                        r.avgPct = typeof h.Active_Avg_GB === 'number' ? h.Active_Avg_GB / cap * 100 : sA / nA; r.peakPct = mA; r.activeGB = r.avgPct * cap / 100;
                        r.tsCons = nC ? { avg: sC / nC, peak: mC, min: minC, persist: hits / nC * 100 } : null;
                        samples += nA - 1;
                        var t0 = d.tsMeta.baseHour * RPT_HOUR_MS, t1 = (d.tsMeta.baseHour + d.tsMeta.n - 1) * RPT_HOUR_MS;
                        if (t0 < minT) minT = t0; if (t1 > maxT) maxT = t1;
                        clusterTs[h.Cluster] = d.tsMeta;
                    }
                }
                if (!mtHas(h, 'Active') && typeof h.Active_GB === 'number' && isFinite(h.Active_GB) && h.Active_GB >= 0) {
                    r.peakPct = h.Active_GB / cap * 100;
                }
                r.peakGB = r.peakPct * cap / 100;
                recs.push(r);
            });
        });
        var hasSeries = minT !== Infinity;
        var base = hasSeries ? minT : 0;
        recs.forEach(function(r) {
            if (r.ts) return; // built lazily by rptActSeries / rptConsSeries
            if (r.t.length) {
                r.h = r.t.map(function(t) { return (t - base) / RPT_HOUR_MS; });
                r.clusterH = r.clusterT ? r.clusterT.map(function(t) { return (t - base) / RPT_HOUR_MS; }) : r.h;
                r.consH = []; r.consV = [];
                r.cons.forEach(function(v, i) { if (v !== null) { r.consH.push(r.consT ? (r.consT[i]-base)/RPT_HOUR_MS : r.h[i]); r.consV.push(v); } });
                if (!r.consV.length) { r.consH = [0]; r.consV = [r.alloc / r.cap * 100]; }
            } else {
                r.h = [0]; r.act = [r.avgPct]; r.consH = [0]; r.consV = [r.alloc / r.cap * 100];
            }
        });

        function rptActSeries(r) {
            if (!r.ts) return { h: r.h, v: r.act };
            if (r._as) return r._as;
            var a = r.ts.act, h0 = Math.round((r.tsHour0 * RPT_HOUR_MS - base) / RPT_HOUR_MS), hh = [], vv = [];
            for (var i = 0; i < a.length; i++) if (a[i]) { hh.push(h0 + i); vv.push((a[i] - 1) / 2.5); }
            return (r._as = { h: hh, v: vv });
        }
        function rptConsSeries(r) {
            if (!r.ts) return { h: r.consH, v: r.consV };
            if (r._cs) return r._cs;
            var c = r.ts.alloc, h0 = Math.round((r.tsHour0 * RPT_HOUR_MS - base) / RPT_HOUR_MS), hh = [], vv = [];
            for (var i = 0; i < c.length; i++) if (c[i]) { hh.push(h0 + i); vv.push(c[i] - 1); }
            if (!vv.length) { hh = [0]; vv = [r.alloc / r.cap * 100]; }
            return (r._cs = { h: hh, v: vv });
        }

        // DATA (report.html's build_report_data)
        var byCluster = {};
        recs.forEach(function(r) { (byCluster[r.cluster] = byCluster[r.cluster] || []).push(r); });
        var clExtra = {};
        datasets.forEach(function(d) {
            var hostCluster = {};
            (d.hosts || []).forEach(function(h) {
                hostCluster[h.HostName] = h.Cluster;
                if (mtAssessmentMissing([h]).length || h.Tiering === 'ERROR') (clExtra[h.Cluster] = clExtra[h.Cluster] || { n: 0, gb: 0, active: 0, missing: 0 }).missing++;
            });
            if ((d.failedVms || []).length) (d.hosts || []).forEach(function(h) { (clExtra[h.Cluster] = clExtra[h.Cluster] || { n: 0, gb: 0, active: 0, missing: 0 }).missing++; });
            (d.vms || []).forEach(function(v) {
                var c = hostCluster[v.Host], o = mtDramOnly([v]);
                if (c === undefined || !o.n) return;
                var e = clExtra[c] || (clExtra[c] = { n: 0, gb: 0, active: 0, missing: 0 });
                e.n += o.n; e.gb += o.gb; e.active += o.active;
            });
        });
        var cand = advClusterCandidates(origHosts, clExtra);
        var clusters = Object.keys(byCluster).map(function(c) {
            var rs = byCluster[c], cpus = rs.filter(function(r) { return r.cpu !== null; }).map(function(r) { return r.cpu; });
            var peakGB = rs.reduce(function(sum, r) { return sum + r.peakGB; }, 0), capGB = rs.reduce(function(sum, r) { return sum + r.cap; }, 0);
            return {
                cluster: c, hosts: rs.length,
                alloc: rptMean(rs.map(function(r) { return r.alloc; })), active: rptMean(rs.map(function(r) { return r.activeGB; })),
                prov: rptMean(rs.map(function(r) { return r.prov; })), cap: rptMean(rs.map(function(r) { return r.cap; })),
                cpucore: rs.some(function(r) { return r.cpuCore !== null; }) ? rptMean(rs.filter(function(r) { return r.cpuCore !== null; }).map(function(r) { return r.cpuCore; })) : null, cpuutil: cpus.length ? rptMean(cpus) : null,
                activepeak: peakGB, activepeakpct: capGB > 0 ? peakGB / capGB * 100 : null, capacityTotal: capGB,
                activepct: rptMean(rs.map(function(r) { return r.avgPct; })), cand: cand[c] ? 'Yes' : 'No'
            };
        });
        clusters.sort(function(a, b) { return b.hosts - a.hosts; });
        var cpuAll = recs.filter(function(r) { return r.cpu !== null; }).map(function(r) { return r.cpu; });
        var DATA = {
            total_hosts: recs.length, total_clusters: clusters.length, clusters: clusters,
            overall: {
                alloc_gb: rptMean(recs.map(function(r) { return r.alloc; })), active_gb: rptMean(recs.map(function(r) { return r.activeGB; })),
                activepeak_gb: recs.reduce(function(sum, r) { return sum + r.peakGB; }, 0),
                activepeakpct: recs.length ? recs.reduce(function(sum, r) { return sum + r.peakGB; }, 0) / recs.reduce(function(sum, r) { return sum + r.cap; }, 0) * 100 : null,
                cap_gb: rptMean(recs.map(function(r) { return r.cap; })), prov_gb: rptMean(recs.map(function(r) { return r.prov; })),
                cpucore: recs.some(function(r) { return r.cpuCore !== null; }) ? rptMean(recs.filter(function(r) { return r.cpuCore !== null; }).map(function(r) { return r.cpuCore; })) : null, cpuutil: cpuAll.length ? rptMean(cpuAll) : null, activepct: rptMean(recs.map(function(r) { return r.avgPct; }))
            }
        };

        // ACTIVE (build_active_pct_data)
        var avgByCl = {}, peakByCl = {}, clSeries = {};
        recs.forEach(function(r) {
            if (!avgByCl[r.cluster]) { avgByCl[r.cluster] = RPT_AVG_EDGES.slice(1).map(function() { return 0; }); peakByCl[r.cluster] = RPT_PEAK_EDGES.slice(1).map(function() { return 0; }); clSeries[r.cluster] = {}; }
            avgByCl[r.cluster][rptBinIndex(r.avgPct, RPT_AVG_EDGES)]++;
            peakByCl[r.cluster][rptBinIndex(r.peakPct, RPT_PEAK_EDGES)]++;
            if (r.ts) return; // cluster line comes from the import's precomputed hourly cluster average
            var acc = clSeries[r.cluster];
            (r.clusterH || r.h).forEach(function(hh, i) { var a = acc[hh] || (acc[hh] = [0, 0]); a[0] += r.act[i]; a[1]++; });
        });
        var ACTIVE = { base_ts_ms: base, hour_ms: RPT_HOUR_MS, hist_avg_by_cluster: avgByCl, hist_peak_by_cluster: peakByCl, series: {}, cluster_meta: [] };
        Object.keys(clSeries).forEach(function(c) {
            var tm = clusterTs[c];
            if (tm) {
                var h0 = Math.round((tm.baseHour * RPT_HOUR_MS - base) / RPT_HOUR_MS), th = [], tv = [];
                for (var i = 0; i < tm.n; i++) if (!isNaN(tm.clusterAct[i])) { th.push(h0 + i); tv.push(tm.clusterAct[i]); }
                ACTIVE.series[c] = { h: th, v: tv };
            } else {
                var hs = Object.keys(clSeries[c]).map(Number).sort(function(a, b) { return a - b; });
                ACTIVE.series[c] = { h: hs, v: hs.map(function(hh) { return clSeries[c][hh][0] / clSeries[c][hh][1]; }) };
            }
            ACTIVE.cluster_meta.push({ cluster: c, active_pct: rptMean(byCluster[c].map(function(r) { return r.avgPct; })), hosts: byCluster[c].length });
        });
        ACTIVE.cluster_meta.sort(function(a, b) { return b.active_pct - a.active_pct; });

        // HOSTACTIVE (build_host_active_data) -- every host is embedded here, so the floor is 0.
        var HOSTACTIVE = { base_ts_ms: base, hour_ms: RPT_HOUR_MS, embed_floor_pct: 0, host_meta: [], seriesOf: function(id) { return recs[id]?rptActSeries(recs[id]):null; } };
        recs.forEach(function(r) {
            HOSTACTIVE.host_meta.push({ id: r.id, host: r.host, cluster: r.cluster, peak: r.peakPct, avg: r.avgPct,
                capacityGB:r.cap,activeGB:r.activeGB,peakGB:r.peakGB,hasHistory:!!(r.ts || r.t.length),timePct:null,status:'',kind:'host' });
        });
        HOSTACTIVE.host_meta.sort(function(a, b) { return b.peak - a.peak; });
        HOSTACTIVE.all_hosts=HOSTACTIVE.host_meta.slice();var hostIndex=Object.create(null);
        HOSTACTIVE.host_meta.forEach(function(h){hostIndex[h.cluster+'\u0000'+h.host]=h});
        datasets.forEach(function(d){(d.hosts||[]).forEach(function(h){var key=h.Cluster+'\u0000'+h.HostName,m=hostIndex[key];if(m){m.status=h.Missing_Metrics || (h.Tiering==='Unknown'?'Configuration unverified':'Active measurements available');return}
            HOSTACTIVE.all_hosts.push({id:null,host:h.HostName,cluster:h.Cluster,avg:null,peak:null,capacityGB:h.Physical_RAM>0?h.Physical_RAM:null,activeGB:!mtHas(h,'Active')&&typeof h.Active_Avg_GB==='number'?h.Active_Avg_GB:null,peakGB:!mtHas(h,'Active')&&typeof h.Active_GB==='number'?h.Active_GB:null,hasHistory:false,timePct:null,status:h.Missing_Metrics || 'Active % unavailable or host collection failed',kind:'host'});
        })});

        // PROVCONS (rank_hosts + build_provcons_data)
        var always = 0, ranked = recs.map(function(r) {
            if (r.ts && r.tsCons) {
                if (r.tsCons.persist >= 100 - 1e-9) always++;
                return { id: r.id, host: r.host, cluster: r.cluster, provPct: r.provPct, avgConsumed: r.tsCons.avg, peakConsumed: r.tsCons.peak, persistPct: r.tsCons.persist };
            }
            if (r.ts) { var cs0 = rptConsSeries(r); r.consV = cs0.v; }
            var hits = 0; r.consV.forEach(function(v) { if (r.provPct > RPT_DEFAULT_PROV && v > RPT_DEFAULT_CONS) hits++; });
            var persist = hits / r.consV.length * 100;
            if (persist >= 100 - 1e-9) always++;
            return { id: r.id, host: r.host, cluster: r.cluster, provPct: r.provPct, avgConsumed: rptMean(r.consV), peakConsumed: Math.max.apply(null, r.consV), persistPct: persist };
        });
        ranked.sort(function(a, b) { return (b.persistPct - a.persistPct) || (b.avgConsumed - a.avgConsumed); });
        var top = ranked, PROVCONS = {
            base_ts_ms: base, hour_ms: RPT_HOUR_MS, default_prov_threshold: RPT_DEFAULT_PROV, default_cons_threshold: RPT_DEFAULT_CONS,
            top_n: top.length, always_qualifying_count: always, total_hosts_checked: ranked.length, host_meta: top, all: ranked,
            seriesOf: function(id) { return rptConsSeries(recs[id]); }
        };

        // TENANT (build_tenant_map) -- tags come from the import's tenant sheet.
        var ct = {}, tenantsSeen = {};
        recs.forEach(function(r) { if (r.tenant) { ct[r.cluster] = r.tenant; tenantsSeen[r.tenant] = true; } });
        var TENANT = Object.keys(ct).length ? { source_file: imp && imp.tenantFile ? (obfOn() ? 'the import' : imp.tenantFile) : 'import', source_sheet: imp && imp.tenantSheet ? imp.tenantSheet : 'tenant sheet', cluster_tenant: ct, tenants: Object.keys(tenantsSeen).sort() } : null;

        // Coverage / source line
        var dStart = null, dEnd = null;
        if (hasSeries) { dStart = rptDay(minT); dEnd = rptDay(maxT); }
        else if (imp && imp.minTs !== null && imp.maxTs !== null && imp.maxTs > imp.minTs) { dStart = rptDay(imp.minTs); dEnd = rptDay(imp.maxTs); }
        var source;
        var onlyRvtools = isRvtools && datasets.every(function(d) { return d.source === 'rvtools'; });
        if (onlyRvtools) source = 'Source: RVTools inventory snapshots (' + rangeLabel + ')';
        else if (isOps && !isVrops && !hasOther) source = "Source: live Operations API (" + rangeLabel + ") \u00b7 " + fmtInt(samples) + " host samples";
        else if (isOps) source = "Source: mixed Operations API and other sources (" + rangeLabel + ")";
        else if (isVrops && hasOther) source = "Source: mixed (VCF Operations import plus other analyses or imports, " + rangeLabel + ") \u00b7 " + fmtInt(samples) + " host samples";
        else if (isVrops && imp) source = "Source: " + imp.files.length + " VCF Operations xlsx export" + (imp.files.length === 1 ? "" : "s") + " (" + (obfOn() ? imp.files.map(function(f, i) { return "file " + (i + 1); }) : imp.files).join(", ") + ") \u00b7 " + fmtInt(imp.rows) + " rows";
        else source = "Source: live vCenter analysis (" + rangeLabel + ") \u00b7 " + fmtInt(samples) + " host samples";
        if (dStart) source += " \u00b7 coverage " + dStart + " to " + dEnd;
        else source += " \u00b7 one value per host (no timeline)";
        return {
            opsTimelineEvidence: datasets.filter(function(d){return d.source === 'ops'}).map(function(d){
                var samples=0,first=null,last=null,points=0;
                (d.hosts||[]).forEach(function(h){samples+=Number(h.Active_Sample_Count)||0;var a=h.Active_First_Timestamp,z=h.Active_Last_Timestamp;if(typeof a==='number')first=first===null?a:Math.min(first,a);if(typeof z==='number')last=last===null?z:Math.max(last,z)});
                if(d.series&&d.series.hosts)Object.keys(d.series.hosts).forEach(function(k){points+=(d.series.hosts[k].active||[]).filter(function(x){return typeof x==='number'&&isFinite(x)}).length});
                return {samples:samples,points:points,first:first,last:last,bucketSeconds:d.series?d.series.bucketSeconds:null};
            }),
            DATA: DATA, ACTIVE: ACTIVE, HOSTACTIVE: HOSTACTIVE, PROVCONS: PROVCONS, TENANT: TENANT, hasSeries: hasSeries,
            hasCpu: hasCpu, isRvtools: onlyRvtools, consumedBasis: Object.keys(consumedBases).length === 1 ? Object.keys(consumedBases)[0] : 'mixed', isVrops: isVrops, isOps: isOps, dateStart: dStart, dateEnd: dEnd, source: source, rangeLabel: rangeLabel,
            excludedTenants: new Set(), sortKey: 'hosts', sortDir: -1
        };
    }

    function fmt(n, d) { return Number(n).toLocaleString(undefined, { minimumFractionDigits: d, maximumFractionDigits: d }); }
    function fmtInt(n) { return Number(n).toLocaleString(); }
    function fmtOrDash(v) { return (v === null || v === undefined) ? "n/a" : v; }
    var RPT_UNMAPPED = "(unmapped)";
    function rptTenantOf(cluster) { return RPT.TENANT ? (RPT.TENANT.cluster_tenant[cluster] || RPT_UNMAPPED) : null; }
    function rptIncluded(cluster) { return !RPT.TENANT || !RPT.excludedTenants.has(rptTenantOf(cluster)); }
    function rptHostLabel(hm) { var short = String(hm.host).split(".")[0]; return RPT.TENANT ? short + " (" + rptTenantOf(hm.cluster) + ")" : short; }
    function rptEl(id) { return document.getElementById(id); }

    var rptPreferredView = 'matrix';
    var rptEffectiveView = null;
    try { if (localStorage.getItem('mtatAnalyticsView') === 'timeline') rptPreferredView = 'timeline'; } catch(e) {}
    function rptTimelineAvailable(model) { if(!model.hasSeries)return false; if(!model.ACTIVE || !model.ACTIVE.series)return true; return Object.keys(model.ACTIVE.series).some(function(k){var h=model.ACTIVE.series[k].h;return h && h.length>1 && h[h.length-1]>h[0]}); }
    function rptUseTimeline(model) { return rptTimelineAvailable(model) && (rptEffectiveView || rptPreferredView) === 'timeline'; }
    function rptOpsTimelineEvidence(model) {
        return (model.opsTimelineEvidence || []).map(function(e) {
            function utc(ms) { return typeof ms === 'number' && isFinite(ms) ? new Date(ms).toISOString().replace('T',' ').replace('.000Z',' UTC') : 'unavailable'; }
            return 'Ops active-memory evidence: ' + e.samples + ' returned samples; ' + e.points + ' host chart points; first ' + utc(e.first) + '; last ' + utc(e.last) + (e.bucketSeconds ? '; chart interval ' + e.bucketSeconds + ' seconds.' : '.');
        }).join(' ');
    }
    function rptTimelineHelp(model) {
        if (rptTimelineAvailable(model)) return 'All retained series are shown. The threshold line identifies crossings; threshold and duration controls affect counts and tables only.';
        if (model.isOps && model.rangeLabel === 'Latest Ops Sample') return 'Latest Ops Sample is one timestamped snapshot, not history. On Assessment, select Past 24 Hours, Past 7 Days or Past 30 Days and analyze. Open that historical result, then select its Time range here.';
        if (model.isOps) return 'Operations history has fewer than two usable chart time positions for this selection. Inspect observed sample coverage and collection notes on Assessment. Timelines require at least two distinct observed chart positions; the sample evidence below shows what reached analytics.';
        if (model.rangeLabel === 'Real-Time Snapshot') return 'Real-Time Snapshot is one observation. Collect a historical range on Assessment and select it here to enable Timeline.';
        return 'Timeline unavailable: this selection has fewer than two historical time positions. Summary CSVs retain peaks and averages without samples. Use timestamped workbooks or historical collection for a timeline.';
    }
    function rptSyncViewMode() {
        var select = rptEl('rptViewMode'),available=rptTimelineAvailable(RPT),notice=rptEl('rptHistoryNotice');
        if(notice){notice.style.display=available?'none':'block';notice.textContent=RPT.hasSeries
            ? 'Timeline unavailable: this selection has fewer than two usable time positions. Select a collected historical range or inspect the collection notes for missing history.'
            : 'This selection contains summary / snapshot values only, with no historical timestamps. Averages and reported peaks cannot reconstruct a timeline or peak duration. Import a timestamped Ops workbook (one host and timestamp per observation), or collect Past 24 Hours, Past 7 Days or Past 30 Days from a live Ops connection and select that historical range here. The matrix and complete tables remain available.';}

        rptEffectiveView = rptTimelineAvailable(RPT) && rptPreferredView === 'timeline' ? 'timeline' : 'matrix';
        select.value = rptEffectiveView;
        ['Cluster','Host'].forEach(function(key) {
            var matrix = rptEl('rpt' + key + 'MatrixButton'), line = rptEl('rpt' + key + 'TimelineButton');
            matrix.setAttribute('aria-pressed', rptEffectiveView === 'matrix' ? 'true' : 'false');
            line.setAttribute('aria-pressed', rptEffectiveView === 'timeline' ? 'true' : 'false');
            line.disabled = !rptTimelineAvailable(RPT);
            rptEl('rpt' + key + 'ViewHelp').textContent = rptTimelineHelp(RPT) + (RPT.isOps ? ' ' + rptOpsTimelineEvidence(RPT) : '');
        });
        var timeline = rptEffectiveView === 'timeline';
        rptEl('rptClusterViewTitle').textContent = timeline ? 'Active memory over time: all clusters' : 'Active memory matrix: clusters by band';
        rptEl('rptHostViewTitle').textContent = timeline ? 'Active memory over time: all hosts' : 'Active memory matrix: hosts by band';
        rptEl('rptClusterViewDescription').textContent = timeline ? 'All observed clusters in the selected scope, using chart-interval averages across their observed hosts. The dashed line marks the active-memory threshold. Threshold and duration controls affect crossing counts and tables; every available series stays visible.' : 'All included clusters grouped into peak/snapshot memory bands. Outlined cells meet the active-memory threshold. The matrix does not establish time above a threshold; historical persistence is shown in the table.';
        rptEl('rptHostViewDescription').textContent = timeline ? 'All observed hosts in the selected scope. The dashed line marks the active-memory threshold. Threshold and duration controls affect crossing counts and tables; every available series stays visible.' : 'All included hosts grouped into peak/snapshot memory bands. Outlined cells meet the active-memory threshold. The matrix does not establish time above a threshold; historical persistence is shown in the table.';
        Array.prototype.forEach.call(select.options, function(o) { if (o.value === 'timeline') o.disabled = !rptTimelineAvailable(RPT); });
        rptEl('rptViewModeHint').textContent = rptTimelineHelp(RPT) + (RPT.isOps ? ' ' + rptOpsTimelineEvidence(RPT) : '');
    }
    function rptSetViewMode(value) {
        if (value === 'timeline' && !rptTimelineAvailable(RPT)) return;
        rptPreferredView = value === 'timeline' ? 'timeline' : 'matrix';
        rptEffectiveView = rptPreferredView;
        try { localStorage.setItem('mtatAnalyticsView', rptPreferredView); } catch(e) {}
        rptRenderAll();
    }
    function rptChangeViewMode() { rptSetViewMode(rptEl('rptViewMode').value); }

    var rptTables = Object.create(null), rptCollator = new Intl.Collator(undefined,{numeric:true,sensitivity:'base'});
    function rptFinite(v) { return typeof v==='number' && isFinite(v); }
    function rptFmtPercent(v) { return rptFinite(v) ? fmt(v,1)+'%' : 'n/a'; }
    function rptTableColumns(kind,crossing) {
        var name=kind==='host'?[{key:'host',label:'Host'},{key:'cluster',label:'Cluster'}]:[{key:'cluster',label:'Cluster'},{key:'hosts',label:'Hosts',numeric:true,digits:0}];
        return name.concat([{key:'avg',label:'Avg Active %',numeric:true,percent:true},{key:'peak',label:'Reported peak / snapshot %',numeric:true,percent:true}])
            .concat(crossing?[{key:'timePct',label:'Observed intervals >= threshold',numeric:true,percent:true}]:[])
            .concat([{key:'activeGB',label:'Avg active (GB)',numeric:true,digits:2},{key:'capacityGB',label:'Reported capacity (GB)',numeric:true,digits:2}])
            .concat(crossing?[{key:'status',label:'Data / configuration notes'}]:[])
            .concat([{key:'_duration',label:'Duration'}]);
    }
    function rptPagedTable(id,rows,kind,title) {
        var root=rptEl(id),state=rptTables[id];if(!root)return;
        if(!state)state=rptTables[id]={page:0,size:25,sort:'avg',dir:-1,query:'',rows:[],columns:rptTableColumns(kind,id.indexOf('Crossing')>=0),kind:kind};
        state.rows=rows;state.kind=kind;
        if(!root.firstElementChild){
            var details=document.createElement('details');details.className='rpt-list-details';details.open=rows.length>0 && rows.length<=25;
            var summary=document.createElement('summary');summary.textContent=title;details.appendChild(summary);state.summary=summary;
            var bar=document.createElement('div');bar.className='rpt-table-controls';
            var input=document.createElement('input');input.type='search';input.placeholder='Search all '+(kind==='host'?'hosts':'clusters')+'...';input.setAttribute('aria-label',input.placeholder);bar.appendChild(input);
            var timer;input.addEventListener('input',function(){clearTimeout(timer);timer=setTimeout(function(){state.query=input.value.toLowerCase().trim();state.page=0;rptPaintTable(id)},150)});
            var size=document.createElement('select');size.setAttribute('aria-label','Rows per page');[25,50,100,250,500].forEach(function(n){var o=document.createElement('option');o.value=n;o.textContent=n+' rows per page';size.appendChild(o)});
            size.addEventListener('change',function(){state.size=Number(size.value);state.page=0;rptPaintTable(id)});bar.appendChild(size);
            var prev=document.createElement('button');prev.type='button';prev.className='btn btn-sm';prev.textContent='Previous';prev.onclick=function(){state.page--;rptPaintTable(id)};bar.appendChild(prev);state.prev=prev;
            var next=document.createElement('button');next.type='button';next.className='btn btn-sm';next.textContent='Next';next.onclick=function(){state.page++;rptPaintTable(id)};bar.appendChild(next);state.next=next;
            var count=document.createElement('span');count.className='count';count.setAttribute('aria-live','polite');bar.appendChild(count);state.count=count;details.appendChild(bar);
            var wrap=document.createElement('div');wrap.className='table-wrap';var table=document.createElement('table'),head=document.createElement('thead'),tr=document.createElement('tr');state.heads=[];
            state.columns.forEach(function(c){var th=document.createElement('th');if(c.key==='_duration')th.textContent=c.label;else{var b=document.createElement('button');b.type='button';b.className='rpt-sort';b.textContent=c.label;b.onclick=function(){if(state.sort===c.key)state.dir*=-1;else{state.sort=c.key;state.dir=c.numeric?-1:1}state.page=0;rptPaintTable(id)};th.appendChild(b);state.heads.push({th:th,button:b,column:c})}tr.appendChild(th)});
            head.appendChild(tr);table.appendChild(head);state.body=document.createElement('tbody');table.appendChild(state.body);wrap.appendChild(table);details.appendChild(wrap);root.appendChild(details);
        }
        state.title=title;rptPaintTable(id);
    }
    function rptPaintTable(id) {
        var st=rptTables[id];if(!st)return;
        var q=st.query,rows=st.rows.filter(function(r){return !q || [r.host,r.cluster,r.status].join(' ').toLowerCase().indexOf(q)>=0});
        rows.sort(function(a,b){var x=a[st.sort],y=b[st.sort];if(x===null||x===undefined)return y===null||y===undefined?0:1;if(y===null||y===undefined)return -1;var c=typeof x==='number'&&typeof y==='number'?x-y:rptCollator.compare(String(x),String(y));return c*st.dir || rptCollator.compare(String(a.host||a.cluster),String(b.host||b.cluster))});
        st.filtered=rows;var pages=Math.max(1,Math.ceil(rows.length/st.size));st.page=Math.max(0,Math.min(pages-1,st.page));var start=st.page*st.size,end=Math.min(start+st.size,rows.length);
        st.summary.textContent=st.title+' — '+fmtInt(st.rows.length)+' rows (show / hide)';st.count.textContent=(rows.length?fmtInt(start+1)+'–'+fmtInt(end):'0')+' of '+fmtInt(rows.length)+' matching rows; '+fmtInt(st.rows.length)+' total';st.prev.disabled=st.page===0;st.next.disabled=st.page>=pages-1;
        st.heads.forEach(function(h){var on=h.column.key===st.sort;h.th.setAttribute('aria-sort',on?(st.dir===1?'ascending':'descending'):'none');h.button.textContent=h.column.label+(on?(st.dir===1?' ▲':' ▼'):'')});
        st.body.textContent='';var frag=document.createDocumentFragment();
        rows.slice(start,end).forEach(function(r){var tr=document.createElement('tr');st.columns.forEach(function(c){var td=document.createElement('td');if(c.key==='_duration'){var b=document.createElement('button');b.type='button';b.className='btn btn-sm';b.textContent='View';b.disabled=!r.hasHistory;b.onclick=function(){rptSelectDuration(st.kind,st.kind==='host'?r.id:r.cluster)};td.appendChild(b)}else{var v=r[c.key];td.textContent=v===null||v===undefined?'n/a':c.percent?rptFmtPercent(v):c.numeric?fmt(v,c.digits===undefined?1:c.digits):String(v);if(c.numeric)td.style.textAlign='right'}tr.appendChild(td)});frag.appendChild(tr)});
        if(!rows.length){var tr=document.createElement('tr'),td=document.createElement('td');td.colSpan=st.columns.length;td.textContent='No matching rows.';tr.appendChild(td);frag.appendChild(tr)}st.body.appendChild(frag);
    }
    function rptAllHostRows() { return (RPT.HOSTACTIVE.all_hosts || RPT.HOSTACTIVE.host_meta).filter(function(h){return rptIncluded(h.cluster)}); }
    function rptClusterRows() {
        var map=Object.create(null),history=RPT.ACTIVE.series;
        rptAllHostRows().forEach(function(h){var g=map[h.cluster]||(map[h.cluster]={cluster:h.cluster,hosts:0,sumAvg:0,known:0,activeGB:0,capacityGB:0,peakGB:0,complete:true,hasHistory:false,status:[],kind:'cluster'});g.hosts++;if(rptFinite(h.avg)){g.sumAvg+=h.avg;g.known++}if(rptFinite(h.capacityGB))g.capacityGB+=h.capacityGB;else g.complete=false;if(rptFinite(h.activeGB))g.activeGB+=h.activeGB;if(rptFinite(h.peakGB))g.peakGB+=h.peakGB;else g.complete=false;g.hasHistory=g.hasHistory||h.hasHistory;if(h.status&&g.status.indexOf(h.status)<0)g.status.push(h.status)});
        return Object.keys(map).map(function(k){var g=map[k];g.avg=g.known?g.sumAvg/g.known:null;g.peak=g.complete&&g.capacityGB>0?g.peakGB/g.capacityGB*100:null;g.status=g.known+'/'+g.hosts+' hosts with active data'+(g.status.length?'; '+g.status.join('; '):'');if(g.known!==g.hosts)g.activeGB=null;g.timePct=null;return g});
    }
    function rptCrossing(series,threshold) { if(!series||!series.v.length)return null;var n=0;series.v.forEach(function(v){if(v>=threshold)n++});return n/series.v.length*100; }
    function rptActiveThreshold(kind) {
        var host=kind==='host',thrEl=rptEl(host?'rptThresholdInput':'rptClusterThresholdInput'),perEl=rptEl(host?'rptPersistInput':'rptClusterPersistInput');
        var thr=Math.max(0,Math.min(100,Number(thrEl.value))),per=Math.max(0,Math.min(100,Number(perEl.value)));if(!isFinite(thr)||!isFinite(per))return;thrEl.value=thr;perEl.value=per;
        var population=host?rptAllHostRows():rptClusterRows(),rows=[],known=0,unknown=0;
        population.forEach(function(h){var series=host?RPT.HOSTACTIVE.seriesOf(h.id):RPT.ACTIVE.series[h.cluster];var pct=h.hasHistory?rptCrossing(series,thr):null;if(pct===null){if(!rptFinite(h.peak)||h.peak<thr)return;unknown++;rows.push(Object.assign({},h,{timePct:null}));return}if(pct>=per){known++;rows.push(Object.assign({},h,{timePct:pct}))}});
        var count=rptEl(host?'rptThresholdCount':'rptClusterThresholdCount');count.textContent=RPT.hasSeries?fmtInt(known)+' of '+fmtInt(population.length)+' '+(host?'hosts':'clusters')+' meet the ≥'+thr+'% / ≥'+per+'% observed-interval rule'+(unknown?'; '+unknown+' additional peak/snapshot rows have unknown duration':''):fmtInt(rows.length)+' of '+fmtInt(population.length)+' '+(host?'hosts':'clusters')+' have reported peak/snapshot ≥'+thr+'%; duration is unavailable';
        rptPagedTable(host?'rptHostCrossingTable':'rptClusterCrossingTable',rows,kind,'Rows at or above the active threshold');
        var historyClusters=Object.create(null);rptClusterRows().forEach(function(c){if(c.hasHistory)historyClusters[c.cluster]=true});
        var metas=host?RPT.HOSTACTIVE.host_meta.filter(function(h){return rptIncluded(h.cluster)&&h.hasHistory}):RPT.ACTIVE.cluster_meta.filter(function(h){return rptIncluded(h.cluster)&&historyClusters[h.cluster]});
        var items=rptTimelineItems(metas,host?function(h){return RPT.HOSTACTIVE.seriesOf(h.id)}:function(h){return RPT.ACTIVE.series[h.cluster]},host?function(h){return h.host+' ('+h.cluster+')'}:function(h){return h.cluster});
        rptRenderOverlay({card:host?'rptOverlayCard':'rptClusterOverlayCard',tooltip:host?'rptOverlayTooltip':'rptClusterOverlayTooltip',baseMs:RPT.ACTIVE.base_ts_ms,threshold:thr,unit:kind,yLabel:'Active memory % (retained chart interval)',emptyText:'No historical active-memory samples in this scope',items:items,peakOf:function(it){return it.peak},population:population.filter(function(h){return rptFinite(h.peak)}).map(function(h){return {name:host?h.host:h.cluster,cluster:h.cluster,value:h.peak}})});
    }
    function rptRenderClusterOverlay() { rptActiveThreshold('cluster'); }
    function rptRenderHostOverlay() { rptActiveThreshold('host'); }
    function rptRenderTable() { rptPagedTable('rptClusterBreakdownTable',rptClusterRows(),'cluster','Per-cluster breakdown');rptPagedTable('rptHostBreakdownTable',rptAllHostRows(),'host','Per-host breakdown'); }
    function rptBindOnce() {
        if(rptBound)return;rptBound=true;
        ['rptClusterThresholdInput','rptClusterPersistInput'].forEach(function(id){rptEl(id).addEventListener('change',function(){if(RPT)rptRenderClusterOverlay()})});
        ['rptThresholdInput','rptPersistInput'].forEach(function(id){rptEl(id).addEventListener('change',function(){if(RPT)rptRenderHostOverlay()})});
        ['rptDurationThreshold','rptDurationPercent','rptDurationTarget'].forEach(function(id){rptEl(id).addEventListener('change',function(){if(RPT)rptRenderDuration()})});
        rptEl('rptDurationKind').addEventListener('change',function(){rptDurationPage=0;rptRenderDuration()});
        rptEl('rptDurationPrev').onclick=function(){rptDurationPage--;rptRenderDuration()};rptEl('rptDurationNext').onclick=function(){rptDurationPage++;rptRenderDuration()};
        var timer;rptEl('rptDurationSearch').addEventListener('input',function(){clearTimeout(timer);timer=setTimeout(function(){rptDurationPage=0;rptRenderDuration()},150)});
        rptEl('rptTenantSelectAll').addEventListener('click',function(e){e.preventDefault();document.querySelectorAll('#rptTenantChecks input').forEach(function(c){c.checked=true});rptOnTenantChange()});
        rptEl('rptTenantSelectNone').addEventListener('click',function(e){e.preventDefault();document.querySelectorAll('#rptTenantChecks input').forEach(function(c){c.checked=false});rptOnTenantChange()});
    }

    var rptDurationPage=0;
    function rptDurationStats(series,threshold,share) {
        if(!series || series.v.length<2)return null;
        var values=series.v.filter(rptFinite).slice().sort(function(a,b){return b-a});if(values.length<2)return null;
        var peak=values[0],same=0,above=0;values.forEach(function(v){if(Math.abs(v-peak)<1e-9)same++;if(v>=threshold)above++});
        var p=Math.max(0,Math.min(100,share)),index=Math.max(0,Math.min(values.length-1,Math.ceil(values.length*p/100)-1));
        return {values:values,peak:peak,peakShare:same/values.length*100,aboveShare:above/values.length*100,level:values[index],share:p};
    }
    function rptSelectDuration(kind,id) {
        rptEl('rptDurationKind').value=kind;rptEl('rptDurationSearch').value='';rptDurationPage=0;
        var targets=rptDurationTargets(kind),index=targets.findIndex(function(t){return String(t.id)===String(id)});
        if(index>=0)rptDurationPage=Math.floor(index/100);
        rptRenderDuration(id);var section=rptEl('rptDurationSection');if(section) section.scrollIntoView({behavior:'smooth',block:'start'});
    }
    function rptDurationTargets(kind) {
        var rows=kind==='host'?rptAllHostRows().filter(function(h){return h.hasHistory && h.id!==null}):rptClusterRows().filter(function(h){return h.hasHistory});
        return rows.sort(function(a,b){return (rptFinite(b.avg)?b.avg:-Infinity)-(rptFinite(a.avg)?a.avg:-Infinity)||rptCollator.compare(a.host||a.cluster,b.host||b.cluster)}).map(function(r){return {id:kind==='host'?r.id:r.cluster,label:kind==='host'?r.host+' ('+r.cluster+')':r.cluster}});
    }
    function rptRenderDuration(preferred) {
        var kind=rptEl('rptDurationKind').value==='cluster'?'cluster':'host',sel=rptEl('rptDurationTarget'),old=preferred!==undefined&&typeof preferred!=='object'?String(preferred):sel.value;
        var q=rptEl('rptDurationSearch').value.toLowerCase().trim(),targets=RPT.hasSeries?rptDurationTargets(kind).filter(function(t){return !q||t.label.toLowerCase().indexOf(q)>=0}):[];
        var pages=Math.max(1,Math.ceil(targets.length/100));rptDurationPage=Math.max(0,Math.min(pages-1,rptDurationPage));var visible=targets.slice(rptDurationPage*100,rptDurationPage*100+100);sel.textContent='';
        visible.forEach(function(t){var o=document.createElement('option');o.value=t.id;o.textContent=t.label;sel.appendChild(o)});
        if(visible.some(function(t){return String(t.id)===old}))sel.value=old;
        sel.disabled=!visible.length;rptEl('rptDurationPrev').disabled=rptDurationPage===0;rptEl('rptDurationNext').disabled=rptDurationPage>=pages-1;
        rptEl('rptDurationCount').textContent=targets.length?(rptDurationPage*100+1)+'–'+(rptDurationPage*100+visible.length)+' of '+fmtInt(targets.length)+' targets; search or page for any host/cluster':'No historical targets in this scope';
        var thr=Math.max(0,Math.min(100,Number(rptEl('rptDurationThreshold').value))),share=Math.max(0,Math.min(100,Number(rptEl('rptDurationPercent').value)));rptEl('rptDurationThreshold').value=thr;rptEl('rptDurationPercent').value=share;
        var series=sel.disabled?null:kind==='host'?RPT.HOSTACTIVE.seriesOf(Number(sel.value)):RPT.ACTIVE.series[sel.value],stats=rptDurationStats(series,thr,share),card=rptEl('rptDurationCard'),tip=rptEl('rptDurationTooltip');
        card.querySelectorAll('svg, .rpt-duration-empty').forEach(function(n){n.remove()});tip.style.display='none';
        card.style.display=stats?'block':'none';
        if(!stats){rptEl('rptDurationSummary').textContent='Peak duration is unavailable: at least two observed historical intervals are required. A snapshot or summary-only CSV cannot establish how long a peak lasted.';return}
        rptEl('rptDurationSummary').textContent='Highest charted interval: '+rptFmtPercent(stats.peak)+'; intervals at that level: '+rptFmtPercent(stats.peakShare)+'. Active ≥ '+thr+'% in '+rptFmtPercent(stats.aboveShare)+' of observed intervals. The busiest '+share+'% of intervals reached at least '+rptFmtPercent(stats.level)+'. '+fmtInt(stats.values.length)+' retained intervals.';
        var W=960,H=320,M={left:66,right:18,top:22,bottom:52},pw=W-M.left-M.right,ph=H-M.top-M.bottom,yMax=niceTicks(0,Math.max(stats.peak,thr,1),5).slice(-1)[0];
        function x(v){return M.left+v/100*pw}function y(v){return M.top+ph-v/yMax*ph}
        var svg=svgEl('svg',{viewBox:'0 0 '+W+' '+H,role:'img','aria-label':'Active-memory duration: share of observed retained chart intervals','class':'overlay-svg'});
        niceTicks(0,yMax,5).forEach(function(v){svg.appendChild(svgEl('line',{x1:M.left,x2:W-M.right,y1:y(v),y2:y(v),'class':'grid-line'}));var t=svgEl('text',{x:M.left-8,y:y(v)+4,'text-anchor':'end','class':'axis-label'});t.textContent=fmt(v,0)+'%';svg.appendChild(t)});
        [0,10,25,50,75,90,100].forEach(function(v){var t=svgEl('text',{x:x(v),y:H-M.bottom+19,'text-anchor':'middle','class':'axis-label'});t.textContent=v+'%';svg.appendChild(t)});
        // Lossless step runs: include each distinct charted value without one SVG node per observation.
        var points=x(0)+','+y(stats.values[0]),n=stats.values.length;
        for(var i=0;i<n;i++){if(i===n-1 || stats.values[i+1]!==stats.values[i]){var pct=(i+1)/n*100;points+=' '+x(pct)+','+y(stats.values[i]);if(i+1<n)points+=' '+x(pct)+','+y(stats.values[i+1])}}
        svg.appendChild(svgEl('polyline',{points:points,fill:'none',style:'stroke:var(--series-1);stroke-width:2'}));
        svg.appendChild(svgEl('line',{x1:M.left,x2:W-M.right,y1:y(thr),y2:y(thr),'stroke-dasharray':'6,4',style:'stroke:#c25400;stroke-width:2'}));
        svg.appendChild(svgEl('line',{x1:x(share),x2:x(share),y1:M.top,y2:H-M.bottom,'stroke-dasharray':'4,4',style:'stroke:#7765b9;stroke-width:1.5'}));
        addAxisTitles(svg,W,H,M,pw,ph,'Share of observed intervals at or above this level','Active memory %');
        var hit=svgEl('rect',{x:M.left,y:M.top,width:pw,height:ph,fill:'transparent'});svg.appendChild(hit);
        hit.addEventListener('pointermove',function(e){var pt=svg.createSVGPoint();pt.x=e.clientX;pt.y=e.clientY;var p=pt.matrixTransform(svg.getScreenCTM().inverse()),pct=Math.max(0,Math.min(100,(p.x-M.left)/pw*100)),idx=Math.max(0,Math.min(n-1,Math.ceil(pct/100*n)-1));tip.textContent='Busiest '+fmt(pct,1)+'% of observed intervals: Active ≥ '+fmt(stats.values[idx],2)+'%';var box=card.getBoundingClientRect();tip.style.display='block';tip.style.left=Math.max(5,e.clientX-box.left+10)+'px';tip.style.top=Math.max(5,e.clientY-box.top-32)+'px'});
        hit.addEventListener('pointerleave',function(){tip.style.display='none'});card.insertBefore(svg,tip);
    }

    function rptRenderAll() {
        rptEl('rptSource').textContent = RPT.source;
        rptSyncViewMode();
        rptRenderTenantFilter();
        var f = rptFilteredOverall();
        rptRenderKpis(f.totalHosts, f.totalClusters, f.overall);
        rptRenderHistograms();
        rptRenderClusterOverlay();
        rptRenderHostOverlay();
        rptRenderTable();
        rptRenderDuration();
        rptEl('rptFooter').textContent = (RPT.isRvtools
            ? 'RVTools inventory snapshots. Values are decimal GB. Multiple sources and clusters are included in fleet scope; each cluster uses its last selected snapshot. Historical peaks, tiering state and VM eligibility are not established by an inventory snapshot.'
            : RPT.isOps
            ? "Operations API data: true consumed memory and retained active-memory samples, converted to decimal GB. Peaks are maxima of retained aggregates. Charts use bounded retained-sample intervals; summary averages use all retained samples. Missing configuration or history blocks qualification and savings; inspect Tab 2 notes."
            : RPT.isVrops
            ? ("Generated from Operations host workbooks. Memory is decimal GB. " + (RPT.consumedBasis === 'actual' ? "Consumed uses measured host consumed memory. " : RPT.consumedBasis === 'allocated' ? "Consumed uses allocated VM memory as a proxy. " : "Consumed uses measured memory where supplied, allocated memory where marked as a proxy, and leaves unavailable metrics unknown. ") + "CPU utilization and CPU core utilization are separate measurements; unavailable counters show n/a. Host exports do not establish VM eligibility or physical tier breakdown.")
            : "Generated from MTAT's live vCenter analysis (mem.active, mem.consumed, cpu.usage). Capacity is host physical DRAM. Provisioned % is memory configured on powered-on VMs as a % of DRAM. CPU util is cpu.usage; CPU core util is not collected and shows as n/a.") +
            (RPT.hasSeries ? " Chart intervals follow retained data and the collection budget; cluster lines average hosts observed in each chart interval." : " This data source has one value per host, so the over-time charts have no timeline to draw; their tables still list everything at or above the thresholds.");
    }

    function rptFilteredOverall() {
        var D = RPT.DATA;
        var included = D.clusters.filter(function(r) { return rptIncluded(r.cluster); });
        var totalHosts = included.reduce(function(s, r) { return s + r.hosts; }, 0);
        if (!totalHosts) return { totalHosts: 0, totalClusters: 0, included: included, overall: { alloc_gb: 0, active_gb: 0, cap_gb: 0, prov_gb: 0, cpucore: null, cpuutil: null, activepct: 0, activepeak_gb: null, activepeakpct: null } };
        function wmean(key) {
            var withVal = included.filter(function(r) { return r[key] !== null; });
            var n = withVal.reduce(function(s, r) { return s + r.hosts; }, 0);
            return n ? withVal.reduce(function(s, r) { return s + r[key] * r.hosts; }, 0) / n : null;
        }
        var peakGB = included.reduce(function(sum, c) { return sum + c.activepeak; }, 0);
        var capGB = included.reduce(function(sum, c) { return sum + c.capacityTotal; }, 0);
        return { totalHosts: totalHosts, totalClusters: included.length, included: included, overall: {
            activepeak_gb: peakGB, activepeakpct: capGB > 0 ? peakGB / capGB * 100 : null,
            alloc_gb: wmean("alloc"), active_gb: wmean("active"), cap_gb: wmean("cap"), prov_gb: wmean("prov"),
            cpucore: wmean("cpucore"), cpuutil: wmean("cpuutil"), activepct: wmean("activepct") } };
    }

    function rptRenderKpis(totalHosts, totalClusters, overall) {
        var hosts=rptAllHostRows(),clusters=rptClusterRows(),known=hosts.filter(function(h){return rptFinite(h.avg)}),avg=known.length?known.reduce(function(n,h){return n+h.avg},0)/known.length:null;
        var peak=hosts.reduce(function(n,h){return rptFinite(h.peak)?Math.max(n,h.peak):n},-Infinity);
        var kpis=[{label:'Hosts in scope',value:fmtInt(hosts.length),unit:''},{label:'Clusters in scope',value:fmtInt(clusters.length),unit:''},{label:'Avg Active % (available hosts)',value:avg===null?'n/a':fmt(avg,1),unit:avg===null?'':'%'},{label:'Highest reported peak / snapshot %',value:peak===-Infinity?'n/a':fmt(peak,1),unit:peak===-Infinity?'':'%'},{label:'Hosts with active measurements',value:fmtInt(known.length),unit:'of '+fmtInt(hosts.length)}];
        var row = rptEl('rptKpiRow'); row.innerHTML = "";
        kpis.forEach(function(k) {
            var tile = document.createElement("div"); tile.className = "stat-tile";
            var l = document.createElement("div"); l.className = "label"; l.textContent = k.label;
            var v = document.createElement("div"); v.className = "value"; v.appendChild(document.createTextNode(k.value));
            if (k.unit) { var u = document.createElement("span"); u.className = "unit"; u.textContent = k.unit; v.appendChild(u); }
            tile.appendChild(l); tile.appendChild(v); row.appendChild(tile);
        });
    }

    function rptRenderTenantFilter() {
        var box = rptEl('rptTenantFilter'), checks = rptEl('rptTenantChecks');
        checks.innerHTML = "";
        if (!RPT.TENANT) { box.style.display = "none"; return; }
        var D = RPT.DATA, counts = {};
        D.clusters.forEach(function(r) { var t = rptTenantOf(r.cluster); counts[t] = (counts[t] || 0) + 1; });
        Object.keys(counts).sort().forEach(function(t) {
            var label = document.createElement("label"); label.className = "tenant-chip";
            var cb = document.createElement("input"); cb.type = "checkbox"; cb.checked = !RPT.excludedTenants.has(t); cb.dataset.tenant = t;
            cb.addEventListener("change", rptOnTenantChange);
            label.appendChild(cb); label.appendChild(document.createTextNode(" " + t + " "));
            var c = document.createElement("span"); c.className = "tenant-chip-count"; c.textContent = "(" + fmtInt(counts[t]) + ")";
            label.appendChild(c); checks.appendChild(label);
        });
        var unmapped = D.clusters.filter(function(r) { return !(r.cluster in RPT.TENANT.cluster_tenant); }).length;
        rptEl('rptTenantFilterNote').textContent = unmapped
            ? "Tenant mapping from " + RPT.TENANT.source_file + " (sheet '" + RPT.TENANT.source_sheet + "'): " + fmtInt(unmapped) + " of " + fmtInt(D.total_clusters) + " clusters had no entry and are grouped under \"" + RPT_UNMAPPED + "\"."
            : "Tenant mapping from " + RPT.TENANT.source_file + " (sheet '" + RPT.TENANT.source_sheet + "').";
        box.style.display = "";
        rptUpdateTenantCount();
    }
    function rptUpdateTenantCount() {
        var f = rptFilteredOverall(), D = RPT.DATA;
        rptEl('rptTenantFilterCount').textContent = fmtInt(f.totalClusters) + " of " + fmtInt(D.total_clusters) + " clusters \u00b7 " + fmtInt(f.totalHosts) + " of " + fmtInt(D.total_hosts) + " hosts included";
    }
    function rptOnTenantChange() {
        RPT.excludedTenants.clear();
        document.querySelectorAll("#rptTenantChecks input[type=checkbox]").forEach(function(cb) {
            cb.closest(".tenant-chip").classList.toggle("excluded", !cb.checked);
            if (!cb.checked) RPT.excludedTenants.add(cb.dataset.tenant);
        });
        var f = rptFilteredOverall();
        rptRenderKpis(f.totalHosts, f.totalClusters, f.overall);
        rptRenderHistograms(); rptRenderClusterOverlay(); rptRenderHostOverlay(); rptRenderTable(); rptRenderDuration();
        rptUpdateTenantCount();
    }

    // ---------- SVG helpers ----------
    var RPT_SVGNS = "http://www.w3.org/2000/svg";
    function svgEl(tag, attrs) { var el = document.createElementNS(RPT_SVGNS, tag); for (var k in attrs) el.setAttribute(k, attrs[k]); return el; }
    function niceStep(rough) {
        var mag = Math.pow(10, Math.floor(Math.log10(rough))), norm = rough / mag;
        return (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10) * mag;
    }
    function niceTicks(min, max, count) {
        if (min === max) max = min + 1;
        var step = niceStep((max - min) / count) || 1, ticks = [Math.floor(min / step) * step];
        while (ticks[ticks.length - 1] < max - step * 1e-9) ticks.push(Math.round((ticks[ticks.length - 1] + step) * 1000) / 1000);
        return ticks;
    }
    function addAxisTitles(svg, W, H, M, plotW, plotH, xLabel, yLabel) {
        if (xLabel) { var xt = svgEl("text", { x: M.left + plotW / 2, y: H - 5, "class": "axis-label-strong", "text-anchor": "middle" }); xt.textContent = xLabel; svg.appendChild(xt); }
        if (yLabel) { var cy = M.top + plotH / 2, yt = svgEl("text", { x: 12, y: cy, "class": "axis-label-strong", "text-anchor": "middle", transform: "rotate(-90 12 " + cy + ")" }); yt.textContent = yLabel; svg.appendChild(yt); }
    }
    function renderMultiTooltip(tooltipEl, header, entries, activeName, capN) {
        capN = capN || 30;
        var sorted = entries.slice().sort(function(a, b) { return b.value - a.value; });
        tooltipEl.classList.add("tt-multi"); tooltipEl.innerHTML = "";
        var h = document.createElement("div"); h.className = "tt-label"; h.textContent = header; tooltipEl.appendChild(h);
        var list = document.createElement("div"); list.className = "tt-list";
        sorted.slice(0, capN).forEach(function(e) {
            var row = document.createElement("div"); row.className = "tt-row" + (e.name === activeName ? " tt-row-active" : "");
            var n = document.createElement("span"); n.className = "tt-row-name"; n.textContent = e.name;
            var v = document.createElement("span"); v.className = "tt-row-val"; v.textContent = fmt(e.value, 2) + "%";
            row.appendChild(n); row.appendChild(v); list.appendChild(row);
        });
        tooltipEl.appendChild(list);
        if (sorted.length > capN) { var more = document.createElement("div"); more.className = "tt-more"; more.textContent = "+" + (sorted.length - capN) + " more not shown (sorted by value)"; tooltipEl.appendChild(more); }
    }
    function nearestIdxGeneric(hArr, h) {
        var lo = 0, hi = hArr.length - 1;
        if (h <= hArr[0]) return 0;
        if (h >= hArr[hi]) return hi;
        while (lo < hi) { var mid = (lo + hi) >> 1; if (hArr[mid] < h) lo = mid + 1; else hi = mid; }
        var a = hArr[lo - 1] !== undefined ? Math.abs(hArr[lo - 1] - h) : Infinity, b = Math.abs(hArr[lo] - h);
        return a < b ? lo - 1 : lo;
    }

    // ---------- Histograms ----------
    function rptRenderHistogram(edges, counts, cardId, tooltipId, xLabel) {
        var card = rptEl(cardId), tip = rptEl(tooltipId), n = counts.length, labels = [];
        for (var i = 0; i < n; i++) labels.push(edges[i] + "\u2013" + edges[i + 1] + "%");
        var W = 960, H = 320, M = { left: 58, right: 16, top: 14, bottom: 46 }, plotW = W - M.left - M.right, plotH = H - M.top - M.bottom;
        var yTicks = niceTicks(0, Math.max.apply(null, counts.concat([1])), 4), yMax = yTicks[yTicks.length - 1];
        var svg = svgEl("svg", { viewBox: "0 0 " + W + " " + H, "class": "hist-svg", role: "img", "aria-label": "Histogram of active memory percent across hosts" });
        yTicks.forEach(function(t) {
            var y = M.top + plotH - (t / yMax) * plotH;
            svg.appendChild(svgEl("line", { x1: M.left, x2: W - M.right, y1: y, y2: y, "class": "grid-line" }));
            var l = svgEl("text", { x: M.left - 8, y: y + 3, "class": "axis-label", "text-anchor": "end" }); l.textContent = fmtInt(t); svg.appendChild(l);
        });
        svg.appendChild(svgEl("line", { x1: M.left, x2: M.left, y1: M.top, y2: M.top + plotH, "class": "axis-line" }));
        svg.appendChild(svgEl("line", { x1: M.left, x2: W - M.right, y1: M.top + plotH, y2: M.top + plotH, "class": "axis-line" }));
        var gap = 3, barW = plotW / n - gap;
        function showTip(evt, i) {
            var box = card.getBoundingClientRect();
            tip.innerHTML = "";
            var l1 = document.createElement("div"); l1.className = "tt-label"; l1.textContent = labels[i];
            var l2 = document.createElement("div"), strong = document.createElement("span"); strong.className = "tt-value"; strong.textContent = fmtInt(counts[i]);
            l2.appendChild(strong); l2.appendChild(document.createTextNode(" hosts"));
            tip.appendChild(l1); tip.appendChild(l2); tip.style.display = "block";
            tip.style.left = (evt.clientX - box.left + 12) + "px"; tip.style.top = (evt.clientY - box.top - 36) + "px";
        }
        for (var b = 0; b < n; b++) {
            (function(i) {
                var x = M.left + i * (plotW / n) + gap / 2, h = (counts[i] / yMax) * plotH;
                var rect = svgEl("rect", { x: x, y: M.top + plotH - h, width: Math.max(1, barW), height: Math.max(0, h), rx: 3, "class": "hist-bar" });
                rect.addEventListener("pointermove", function(e) { showTip(e, i); });
                rect.addEventListener("pointerleave", function() { tip.style.display = "none"; });
                svg.appendChild(rect);
            })(b);
        }
        for (var e = 0; e <= n; e++) {
            if (edges[e] % 5 !== 0) continue;
            var lbl = svgEl("text", { x: M.left + e * (plotW / n), y: M.top + plotH + 16, "class": "axis-label", "text-anchor": "middle" }); lbl.textContent = edges[e] + "%"; svg.appendChild(lbl);
        }
        addAxisTitles(svg, W, H, M, plotW, plotH, xLabel, "Number of hosts");
        card.querySelectorAll(".hist-chart-wrap").forEach(function(w) { w.remove(); });
        var wrap = document.createElement("div"); wrap.className = "hist-chart-wrap"; wrap.style.position = "relative"; wrap.appendChild(svg);
        card.insertBefore(wrap, tip);
    }
    function rptHistFromByCluster(byCluster, nBins) {
        var counts = []; for (var i = 0; i < nBins; i++) counts.push(0);
        for (var c in byCluster) { if (!rptIncluded(c)) continue; var arr = byCluster[c]; for (var j = 0; j < arr.length; j++) counts[j] += arr[j]; }
        return counts;
    }
    function rptRenderHistograms() {
        var A = RPT.ACTIVE, span = "";
        if (RPT.dateStart) {
            var days = Math.round((new Date(RPT.dateEnd + "T00:00:00Z") - new Date(RPT.dateStart + "T00:00:00Z")) / 86400000);
            span = " (up to " + Math.max(1, days) + " day" + (days === 1 ? "" : "s") + ": " + RPT.dateStart + " to " + RPT.dateEnd + ")";
        }
        rptEl('rptHistAvgSubhead').textContent = "Time-averaged active % \u00b7 mean over each host's full window" + span;
        rptEl('rptHistPeakSubhead').textContent = RPT.hasSeries
            ? "Peak active % \u00b7 reported host peak, before chart bucketing" + span
            : "Peak active % \u00b7 reported host peak or snapshot value; no timeline supplied";
        rptRenderHistogram(RPT_AVG_EDGES, rptHistFromByCluster(A.hist_avg_by_cluster, RPT_AVG_EDGES.length - 1), "rptHistCardAvg", "rptHistTooltipAvg", "Active memory % \u00b7 time-averaged (per host)");
        rptRenderHistogram(RPT_PEAK_EDGES, rptHistFromByCluster(A.hist_peak_by_cluster, RPT_PEAK_EDGES.length - 1), "rptHistCardPeak", "rptHistTooltipPeak", "Active memory % \u00b7 peak (per host)");
    }

    // ---------- Shared overlay renderer (report.html draws three of these) ----------
    // opts: {card, tooltip, items:[{key, name, s:{h,v}}], baseMs, yLabel, threshold, emptyText, unit, peakOf(item)}
    // Draw every observed series in the selected scope; thresholds qualify tables, not visibility.
    function rptTimelineItems(metas, seriesOf, labelOf) {
        var items = [];
        metas.forEach(function(m) {
            var series = seriesOf(m);
            if (!series || !series.h.length || !series.v.length) return;
            items.push({ name: labelOf(m), s: series, peak: Math.max.apply(null, series.v) });
        });
        return items;
    }
    function rptRenderOverlay(opts) {
        var card = rptEl(opts.card), tip = rptEl(opts.tooltip);
        card.querySelectorAll("svg, .rpt-no-timeline").forEach(function(s) { s.remove(); });
        tip.style.display = "none"; tip.classList.remove("pinned"); tip.innerHTML = "";
        var items = opts.items;
        card.style.setProperty("--overlay-opacity", Math.max(0.05, Math.min(0.6, 40 / Math.max(1, items.length))));
        var W = 960, H = 360, M = { left: 58, right: 16, top: 14, bottom: 46 }, plotW = W - M.left - M.right, plotH = H - M.top - M.bottom;
        var svg = svgEl("svg", { viewBox: "0 0 " + W + " " + H, "class": "overlay-svg", role: "img", "aria-label": items.length + " lines over time; threshold " + opts.threshold + "%" });
        var maxH = 0;
        items.forEach(function(it) { if (it.s.h.length) maxH = Math.max(maxH, it.s.h[it.s.h.length - 1]); });
        if (opts.population && opts.population.length && !rptUseTimeline(RPT)) {
            rptRenderSnapshotHeat(card, tip, opts); return;
        }
        if (!items.length) {
            var empty = svgEl("text", { x: W / 2, y: H / 2, "class": "chart-empty" });
            empty.textContent = opts.emptyText;
            svg.appendChild(empty); card.insertBefore(svg, tip); return;
        }
        if (maxH <= 0) maxH = 1;
        var vMax = 0; items.forEach(function(it) { vMax = Math.max(vMax, opts.peakOf(it)); });
        var yTicks = niceTicks(0, Math.max(vMax, opts.threshold, 1), 5), yHi = yTicks[yTicks.length - 1];
        function xScale(h) { return M.left + (h / maxH) * plotW; }
        function yScale(v) { return M.top + plotH - (v / yHi) * plotH; }
        yTicks.forEach(function(t) {
            svg.appendChild(svgEl("line", { x1: M.left, x2: W - M.right, y1: yScale(t), y2: yScale(t), "class": "grid-line" }));
            var l = svgEl("text", { x: M.left - 8, y: yScale(t) + 3, "class": "axis-label", "text-anchor": "end" }); l.textContent = fmt(t, 0) + "%"; svg.appendChild(l);
        });
        svg.appendChild(svgEl("line", { x1: M.left, x2: M.left, y1: M.top, y2: M.top + plotH, "class": "axis-line" }));
        svg.appendChild(svgEl("line", { x1: M.left, x2: W - M.right, y1: M.top + plotH, y2: M.top + plotH, "class": "axis-line" }));
        function dateOf(h) { return new Date(opts.baseMs + h * RPT_HOUR_MS); }
        function fmtDate(d) { return d.toISOString().slice(0,maxH<=48?16:10).replace('T',' ') + (maxH<=48?' UTC':''); }
        [0, maxH / 2, maxH].forEach(function(h, i) {
            var l = svgEl("text", { x: xScale(h), y: M.top + plotH + 16, "class": "axis-label", "text-anchor": i === 0 ? "start" : (i === 2 ? "end" : "middle") });
            l.textContent = fmtDate(dateOf(h)); svg.appendChild(l);
        });
        addAxisTitles(svg, W, H, M, plotW, plotH, "Date", opts.yLabel);

        var lines = [];
        items.forEach(function(it) {
            if (!it.s.h.length) return;
            var pts = "";
            for (var i = 0; i < it.s.h.length; i++) pts += xScale(it.s.h[i]) + "," + yScale(it.s.v[i]) + " ";
            var pl = svgEl("polyline", { points: pts.trim(), "class": "overlay-line" });
            svg.appendChild(pl); lines.push({ el: pl, it: it });
            if (it.s.h.length === 1) svg.appendChild(svgEl('circle',{cx:xScale(it.s.h[0]),cy:yScale(it.s.v[0]),r:2.5,style:'fill:var(--series-1)'}));
        });
        svg.appendChild(svgEl('line', {x1:M.left,x2:W-M.right,y1:yScale(opts.threshold),y2:yScale(opts.threshold),'class':'threshold-line','stroke-dasharray':'6,4',style:'stroke:#c25400;stroke-width:2'}));
        var thresholdLabel = svgEl('text',{x:W-M.right-4,y:Math.max(12,yScale(opts.threshold)-6),'text-anchor':'end','class':'threshold-label',style:'fill:#c25400;font-size:12px;font-weight:600'});
        thresholdLabel.textContent = opts.threshold + '% threshold'; svg.appendChild(thresholdLabel);
        var hit = svgEl("rect", { x: M.left, y: M.top, width: plotW, height: plotH, fill: "transparent" });
        svg.appendChild(hit);
        var cur = null, pinned = false;
        function unpin() { pinned = false; tip.classList.remove("pinned"); tip.style.display = "none"; if (cur) { cur.classList.remove("emphasis"); cur = null; } }
        function pin() {
            pinned = true; tip.classList.add("pinned");
            var x = document.createElement("span"); x.className = "tt-close"; x.textContent = "\u2715";
            x.addEventListener("click", function(e) { e.stopPropagation(); unpin(); }); tip.appendChild(x);
        }
        hit.addEventListener("click", function() { if (pinned) unpin(); else pin(); });
        hit.addEventListener("pointermove", function(evt) {
            if (pinned) return;
            var pt = svg.createSVGPoint(); pt.x = evt.clientX; pt.y = evt.clientY;
            var p = pt.matrixTransform(svg.getScreenCTM().inverse());
            var hoverH = ((p.x - M.left) / plotW) * maxH, hoverV = yHi - ((p.y - M.top) / plotH) * yHi;
            var best = null, bestDist = Infinity, entries = [];
            lines.forEach(function(line) {
                var idx = nearestIdxGeneric(line.it.s.h, hoverH), v = line.it.s.v[idx];
                entries.push({ name: line.it.name, value: v });
                var d = Math.abs(v - hoverV); if (d < bestDist) { bestDist = d; best = { line: line, idx: idx }; }
            });
            if (!best) return;
            if (cur && cur !== best.line.el) cur.classList.remove("emphasis");
            best.line.el.classList.add("emphasis"); cur = best.line.el;
            var hh = best.line.it.s.h[best.idx], x = xScale(hh), y = yScale(best.line.it.s.v[best.idx]);
            var cardBox = card.getBoundingClientRect(), svgBox = svg.getBoundingClientRect(), sc = svgBox.width / W;
            var header = fmtDate(dateOf(hh)) + " " + dateOf(hh).getHours() + ":00 \u00b7 " + entries.length + " " + opts.unit + (entries.length === 1 ? "" : "s") + (opts.headerSuffix || "");
            renderMultiTooltip(tip, header, entries, best.line.it.name, 30);
            tip.style.display = "block";
            tip.style.left = (svgBox.left - cardBox.left + x * sc + 12) + "px";
            tip.style.top = (svgBox.top - cardBox.top + y * sc - 46) + "px";
        });
        hit.addEventListener("pointerleave", function(evt) {
            if (pinned || tip.contains(evt.relatedTarget)) return;
            if (cur) { cur.classList.remove("emphasis"); cur = null; } tip.style.display = "none";
        });
        tip.onpointerleave = function(evt) {
            if (pinned || hit.contains(evt.relatedTarget)) return;
            if (cur) { cur.classList.remove("emphasis"); cur = null; } tip.style.display = "none";
        };
        card.insertBefore(svg, tip);
    }
    // No timeline (one value per cluster/host, e.g. a VCF Operations summary export): instead of an
    // empty chart, a heat map of how many clusters/hosts sit in each band, one row per tenant (or a
    // single row when there is no tenant sheet). Bands at or above the threshold are outlined.
    // Hover a cell for its count and the highest members; click to pin the list.
    var RPT_HEAT_EDGES = [0, 2, 4, 6, 8, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, Infinity];
    function rptRenderSnapshotHeat(card, tip, opts) {
        var edges = opts.heatEdges || RPT_HEAT_EDGES, nb = edges.length - 1, unit = opts.unit, thr = opts.threshold;
        var groups = {}, order = [];
        opts.population.forEach(function(p) {
            var g = RPT.TENANT ? rptTenantOf(p.cluster) : ("All " + unit + "s");
            if (!groups[g]) { groups[g] = []; for (var i = 0; i < nb; i++) groups[g].push([]); order.push(g); }
            var b = 0; while (b < nb - 1 && p.value >= edges[b + 1]) b++;
            groups[g][b].push(p);
        });
        order.sort(function(a, b) { var na = groups[a].reduce(function(s, c) { return s + c.length; }, 0), nb2 = groups[b].reduce(function(s, c) { return s + c.length; }, 0); return nb2 - na; });
        var maxCount = 1;
        order.forEach(function(g) { groups[g].forEach(function(c) { if (c.length > maxCount) maxCount = c.length; }); });
        var labelW = 150, cellW = Math.max(40, Math.floor((960 - labelW - 16) / nb)), cellH = 30, top = 34, W = labelW + cellW * nb + 16, H = top + cellH * order.length + 46;
        var svg = svgEl("svg", { viewBox: "0 0 " + W + " " + H, "class": "overlay-svg", role: "img", "aria-label": "Matrix of " + unit + "s by memory-percent band" });
        function bandLabel(b) { return edges[b + 1] === Infinity ? edges[b] + "%+" : edges[b] + "\u2013" + edges[b + 1] + "%"; }
        for (var b = 0; b < nb; b++) {
            var lx = svgEl("text", { x: labelW + b * cellW + cellW / 2, y: top - 10, "class": "axis-label", "text-anchor": "middle" }); lx.textContent = bandLabel(b); svg.appendChild(lx);
        }
        var cells = [];
        order.forEach(function(g, gi) {
            var y = top + gi * cellH;
            var gl = svgEl("text", { x: labelW - 10, y: y + cellH / 2 + 4, "class": "axis-label-strong", "text-anchor": "end" }); gl.textContent = g.length > 22 ? g.slice(0, 21) + "\u2026" : g; svg.appendChild(gl);
            for (var b2 = 0; b2 < nb; b2++) {
                var list = groups[g][b2], n = list.length, x = labelW + b2 * cellW, atOrAbove = edges[b2] >= thr;
                var op = n ? (0.18 + 0.82 * Math.sqrt(n / maxCount)) : 0;
                var rect = svgEl("rect", { x: x + 1, y: y + 1, width: cellW - 2, height: cellH - 2, rx: 2,
                    fill: n ? "var(--series-1)" : "var(--gridline)", "fill-opacity": n ? op.toFixed(2) : 0.35,
                    stroke: atOrAbove ? "#c25400" : "none", "stroke-width": atOrAbove ? 1.5 : 0, style: "cursor:" + (n ? "pointer" : "default") });
                svg.appendChild(rect);
                if (n) { var ct = svgEl("text", { x: x + cellW / 2, y: y + cellH / 2 + 4, "text-anchor": "middle", "class": "axis-label", style: "fill:" + (op > 0.55 ? "#ffffff" : "var(--text-primary)") + "; font-weight:600; pointer-events:none;" }); ct.textContent = fmtInt(n); svg.appendChild(ct); }
                cells.push({ rect: rect, group: g, band: b2, list: list });
            }
        });
        var thrBand = 0; while (thrBand < nb && edges[thrBand] < thr) thrBand++;
        if (thrBand < nb) {
            var tx = labelW + thrBand * cellW;
            svg.appendChild(svgEl("line", { x1: tx, x2: tx, y1: top - 4, y2: top + cellH * order.length + 4, stroke: "#c25400", "stroke-width": 2, "stroke-dasharray": "4,3" }));
            var tl = svgEl("text", { x: tx + 4, y: top + cellH * order.length + 20, "class": "axis-label", style: "fill:#c25400; font-weight:600;" }); tl.textContent = "\u2265 " + thr + "% threshold"; svg.appendChild(tl);
        }
        var xt = svgEl("text", { x: labelW + (cellW * nb) / 2, y: H - 6, "class": "axis-label-strong", "text-anchor": "middle" }); xt.textContent = (opts.heatLabel || "Active memory %") + " band, " + unit + "s per cell"; svg.appendChild(xt);
        var note = document.createElement("div"); note.className = "rpt-no-timeline"; note.style.padding = "0 0 10px 0"; note.style.textAlign = "left";
        note.textContent = "This matrix shows how many " + unit + "s sit in each peak/snapshot band" + (RPT.TENANT ? ", per tenant" : "") + ". Outlined cells are at or above the threshold. Hover a cell for details, click to pin.";
        card.insertBefore(note, tip); card.insertBefore(svg, tip);
        var pinned = false;
        function show(evt, c) {
            var sorted = c.list.slice().sort(function(a, b) { return b.value - a.value; });
            renderMultiTooltip(tip, c.group + " \u00b7 " + bandLabel(c.band) + " \u00b7 " + fmtInt(c.list.length) + " " + unit + (c.list.length === 1 ? "" : "s"), sorted.map(function(p) { return { name: p.name, value: p.value }; }), null, 30);
            var cb = card.getBoundingClientRect();
            tip.style.display = "block"; tip.style.left = (evt.clientX - cb.left + 14) + "px"; tip.style.top = (evt.clientY - cb.top - 30) + "px";
        }
        cells.forEach(function(c) {
            if (!c.list.length) return;
            c.rect.addEventListener("pointermove", function(e) { if (!pinned) show(e, c); });
            c.rect.addEventListener("pointerleave", function(e) { if (!pinned && !tip.contains(e.relatedTarget)) tip.style.display = "none"; });
            c.rect.addEventListener("click", function(e) {
                if (pinned) { pinned = false; tip.classList.remove("pinned"); tip.style.display = "none"; return; }
                show(e, c); pinned = true; tip.classList.add("pinned");
                var x = document.createElement("span"); x.className = "tt-close"; x.textContent = "\u2715";
                x.addEventListener("click", function(ev) { ev.stopPropagation(); pinned = false; tip.classList.remove("pinned"); tip.style.display = "none"; });
                tip.appendChild(x);
            });
        });
        tip.onpointerleave = function(e) { if (!pinned) tip.style.display = "none"; };
    }

    function rptFillTable(bodyId, rows, alignLeftCols, secondaryCol) {
        var frag = document.createDocumentFragment();
        rows.forEach(function(cells) {
            var tr = document.createElement("tr");
            cells.forEach(function(val, i) {
                var td = document.createElement("td"); td.textContent = val;
                td.style.textAlign = i < alignLeftCols ? "left" : "right"; td.style.fontVariantNumeric = "tabular-nums";
                if (i === secondaryCol) td.style.color = "var(--text-secondary)";
                tr.appendChild(td);
            });
            frag.appendChild(tr);
        });
        var body = rptEl(bodyId); body.innerHTML = ""; body.appendChild(frag);
    }

    // ---------- Clusters crossing a threshold ----------


    // ---------- Hosts crossing a threshold ----------


    // ---------- Provisioned & consumed ----------
    function rptRenderProvconsStatic() {
        var P = RPT.PROVCONS;
        rptEl('rptProvconsTimeHeader').textContent = "Time \u2265 " + P.default_prov_threshold + "/" + P.default_cons_threshold;
        if (P.host_meta.length) {
            var pv = P.host_meta.map(function(h) { return h.provPct; }), cv = P.host_meta.map(function(h) { return h.peakConsumed; });
            rptEl('rptProvRangeHint').textContent = "(embedded hosts range " + fmt(Math.min.apply(null, pv), 1) + "\u2013" + fmt(Math.max.apply(null, pv), 1) + "%)";
            rptEl('rptConsRangeHint').textContent = "(embedded hosts peak " + fmt(Math.min.apply(null, cv), 1) + "\u2013" + fmt(Math.max.apply(null, cv), 1) + "%)";
        } else { rptEl('rptProvRangeHint').textContent = ""; rptEl('rptConsRangeHint').textContent = ""; }
        var provMeaning = RPT.isVrops
            ? "Provisioned % is host provisioned memory \u00f7 host capacity, so it barely varies host-to-host and that input only matters near the edges of its band."
            : "Provisioned % is memory configured on the host's powered-on VMs \u00f7 host DRAM (over 100% means memory is over-committed).";
        rptEl('rptProvconsSub').textContent = "For reference, at the built-in defaults (" + P.default_prov_threshold + "% provisioned / " + P.default_cons_threshold +
            "% consumed, not whatever is currently typed in below): " + fmtInt(P.always_qualifying_count) + " of " + fmtInt(P.total_hosts_checked) + " hosts (" +
            fmt(P.total_hosts_checked ? P.always_qualifying_count / P.total_hosts_checked * 100 : 0, 1) + "%) were above both on every sample. " +
            "All " + fmtInt(P.top_n) + " hosts are available. Timeline shows every observed host in scope; thresholds affect crossing counts and tables only. " +
            (RPT.isVrops ? (RPT.consumedBasis === 'actual' ? "Consumed % is measured host consumed memory divided by the reported capacity. " : RPT.consumedBasis === 'allocated' ? "Consumed % uses allocated VM memory divided by the reported capacity. " : "Consumed combines measured data with explicitly identified allocation proxies where needed; inspect Assessment notes. ") : "Consumed % is vCenter's mem.consumed \u00f7 host DRAM. ") + provMeaning;
    }
    function rptRenderProvcons() {
        var P = RPT.PROVCONS;
        var pT = parseFloat(rptEl('rptProvInput').value), cT = parseFloat(rptEl('rptConsInput').value);
        if (isNaN(pT) || isNaN(cT)) return;
        var pool = P.all.filter(function(hm) { return rptIncluded(hm.cluster); });
        var q = pool.filter(function(hm) { return hm.provPct >= pT && hm.peakConsumed >= cT; });
        rptEl('rptProvconsCount').textContent = fmtInt(q.length) + " of " + fmtInt(pool.length) + " hosts meet both thresholds";
        var alwaysNow = pool.reduce(function(n, hm) { var s = P.seriesOf(hm.id); var mn = s && s.v.length ? Math.min.apply(null, s.v) : -Infinity; return n + (rptIncluded(hm.cluster) && hm.provPct >= pT && mn >= cT ? 1 : 0); }, 0);
        rptEl('rptProvconsDynamicSub').textContent = "At your current settings (" + pT + "% provisioned / " + cT + "% consumed): " + fmtInt(q.length) + " of the " + fmtInt(pool.length) +
            " hosts crossed both at least once; " + fmtInt(alwaysNow) + " of those were above both on every sample.";
        var top = q.slice(0, 50);
        rptEl('rptProvconsTableCount').textContent = "Top " + top.length + " of " + fmtInt(q.length) + " qualifying hosts";
        rptFillTable('rptProvconsTableBody', top.map(function(h) { return [h.host, h.cluster, fmt(h.provPct, 1) + "%", fmt(h.avgConsumed, 1) + "%", fmt(h.peakConsumed, 1) + "%", fmt(h.persistPct, 1) + "%"]; }), 2, 1);
        rptRenderOverlay({ card: 'rptProvconsCard', tooltip: 'rptProvconsTooltip', baseMs: P.base_ts_ms, threshold: cT, unit: 'host', headerSuffix: " (consumed %)",
            yLabel: "Consumed memory % (retained chart interval)", emptyText: "No historical consumed-memory samples in the selected scope",
            items: rptTimelineItems(P.all.filter(function(h) { return rptIncluded(h.cluster); }), function(h) { return P.seriesOf(h.id); }, rptHostLabel), peakOf: function(it) { return it.peak; },
            heatEdges: [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 125, 150, 200, Infinity], heatLabel: 'Consumed % (allocated to VMs)',
            population: P.all.filter(function(hm) { return rptIncluded(hm.cluster); }).map(function(hm) { return { name: rptHostLabel(hm), cluster: hm.cluster, value: hm.peakConsumed }; }) });
    }

    // ---------- Per-cluster table ----------


    var rptBound = false;


    function switchTab(id, btn) {
        var contents = document.querySelectorAll('.tab-content');
        for (var i = 0; i < contents.length; i++) contents[i].className = "tab-content";
        var buttons = document.querySelectorAll('.tab-header-btn');
        for (var j = 0; j < buttons.length; j++) { buttons[j].className = "tab-header-btn"; buttons[j].setAttribute('aria-selected', 'false'); }
        document.getElementById(id).className = "tab-content active";
        btn.className = "tab-header-btn active";
        btn.setAttribute('aria-selected', 'true');

        if(id === 'tab-simulator') { loadClusterSimulation(); }
        if(id === 'tab-advanced') { refreshAdvancedTab(); }
    }

    function toggleSimStrategy() {
        var strategy = document.getElementById('simStrategy').value;
        if (strategy === 'greenfield') {
            document.getElementById('brownfield-controls').style.display = 'none';
            document.getElementById('brownfield-results').style.display = 'none';
            document.getElementById('greenfield-controls').style.display = 'block';
            document.getElementById('greenfield-results').style.display = 'block';
        } else {
            document.getElementById('brownfield-controls').style.display = 'block';
            document.getElementById('brownfield-results').style.display = 'block';
            document.getElementById('greenfield-controls').style.display = 'none';
            document.getElementById('greenfield-results').style.display = 'none';
        }
        runSimulationMath();
    }

    function toggleSizingMode() {
        var mode = document.getElementById('simInputMode').value;
        document.getElementById('wrapperSimRatio').style.display = (mode === 'ratio') ? 'flex' : 'none';
        document.getElementById('wrapperSimDrive').style.display = (mode === 'drive') ? 'flex' : 'none';
        document.getElementById('wrapperSimCustom').style.display = (mode === 'custom') ? 'flex' : 'none';
        runSimulationMath();
    }

    function toggleGfInputMode() {
        var mode = document.getElementById('gfInputMode').value;
        if (mode === 'capacity') {
            document.getElementById('gfWrapCap').style.display = 'flex';
            document.getElementById('gfWrapHosts').style.display = 'none';
            document.getElementById('gfWrapCpu').style.visibility = 'visible';
        } else {
            document.getElementById('gfWrapCap').style.display = 'none';
            document.getElementById('gfWrapHosts').style.display = 'flex';
            document.getElementById('gfWrapCpu').style.visibility = 'hidden';
            document.getElementById('gfHa').value = "0"; // Auto-set HA to 0 when explicitly calculating specific node counts
        }
        runSimulationMath();
    }

    function handleGfCapChange() {
        var sel = document.getElementById('gfNodeCapSelect');
        var cust = document.getElementById('gfNodeCapCustom');
        if (sel.value === 'custom') {
            cust.style.display = 'block';
        } else {
            cust.style.display = 'none';
            cust.value = sel.value;
        }
        runSimulationMath();
    }

    function toggleCredsLayout() {
        var useSame = document.getElementById('useSameCreds').checked;
        document.getElementById('globalCredsGrid').style.display = useSame ? 'grid' : 'none';
        document.getElementById('dynamicCredsContainer').style.display = useSame ? 'none' : 'block';
        if (!useSame) buildDynamicCredRows();
    }

    function handleServerListChange() {
        var useSame = document.getElementById('useSameCreds').checked;
        if (!useSame) buildDynamicCredRows();
    }

    function parseServersInput() {
        var rawInput = document.getElementById('vcServer').value;
        var splitServers = rawInput.split(',');
        var cleanServers = [];
        for (var i = 0; i < splitServers.length; i++) {
            var trimmed = splitServers[i].replace(/^\s+|\s+$/g, '');
            if (trimmed !== '') cleanServers.push(trimmed);
        }
        return cleanServers;
    }

    function buildDynamicCredRows() {
        var servers = parseServersInput();
        var container = document.getElementById('dynamicCredsContainer');

        // This re-runs on every keystroke in the server list (via handleServerListChange) and
        // every credential-mode toggle -- snapshot whatever's already been typed for servers
        // still in the list before wiping the container, so fixing a typo elsewhere in the
        // server field (or flipping "same creds" off/on) doesn't silently discard passwords
        // already entered for the other servers.
        var existingByServer = {};
        var existingRows = container.querySelectorAll('.dyn-cred-row');
        for (var e = 0; e < existingRows.length; e++) {
            var key = existingRows[e].getAttribute('data-server');
            var userEl = existingRows[e].querySelector('.vc-sub-user');
            var passEl = existingRows[e].querySelector('.vc-sub-pass');
            existingByServer[key] = { user: userEl ? userEl.value : "", pass: passEl ? passEl.value : "" };
        }

        container.innerHTML = "";
        for (var i = 0; i < servers.length; i++) {
            var srv = servers[i];
            var srvE = escapeHtml(srv);
            var prior = existingByServer[srvE];
            var userVal = prior ? prior.user : "administrator@vsphere.local";
            var passVal = prior ? prior.pass : "";
            container.innerHTML += '<div class="login-grid dyn-cred-row" data-server="' + srvE + '" style="margin-bottom:12px;">' +
                '<div class="input-group"><label>Target FQDN</label><input type="text" value="' + srvE + '" disabled></div>' +
                '<div class="input-group"><label>Username</label><input type="text" class="vc-sub-user" data-server="' + srvE + '" value="' + escapeHtml(userVal) + '"></div>' +
                '<div class="input-group"><label>Password</label><input type="password" class="vc-sub-pass" data-server="' + srvE + '" value="' + escapeHtml(passVal) + '"></div>' +
                '</div>';
        }
    }

    var connectionMode = 'vcenter', liveClusterLabels = {}, liveConnectionBusy = false;
    function setConnectionMode(mode) {
        if (liveConnectionBusy || (mode !== 'vcenter' && mode !== 'ops')) return;
        connectionMode = mode;
        document.getElementById('vcenterConnectionFields').style.display = mode === 'vcenter' ? 'block' : 'none';
        document.getElementById('opsConnectionFields').style.display = mode === 'ops' ? 'block' : 'none';
        document.getElementById('connectBtn').innerText = mode === 'ops' ? 'Connect to Operations' : 'Establish PowerCLI Sessions';
        document.getElementById('connectionModeVc').checked = mode === 'vcenter';
        document.getElementById('connectionModeOps').checked = mode === 'ops';
    }
    function runConnectionPipeline() {
        if (analysisInProgress || liveConnectionBusy) { showToast('Wait for the current collection to finish before reconnecting.', 'warn'); return; }
        if (connectionMode === 'ops') runOpsConnectPipeline(); else runVcenterConnectPipeline();
    }
    function setConnectionBusy(busy) {
        liveConnectionBusy = busy; analysisInProgress = busy;
        if (!busy) missedBeats = 0;
        document.getElementById('connectBtn').disabled = busy;
        document.getElementById('connectionModeVc').disabled = busy;
        document.getElementById('connectionModeOps').disabled = busy;
    }
    function runOpsConnectPipeline() {
        var server = document.getElementById('opsServer').value.trim(), user = document.getElementById('opsUser').value.trim();
        if (!server || !user || !document.getElementById('opsPass').value) { showToast('Enter the Ops server, username and password.', 'warn'); return; }
        var payload = { server: server, user: user, pass: document.getElementById('opsPass').value,
            authSource: document.getElementById('opsAuthSource').value.trim(), requireValidCerts: document.getElementById('opsRequireValidCerts').checked };
        setConnectionBusy(true); analysisInProgress = true;
        document.getElementById('connectBtn').innerText = 'Connecting to Operations...';
        document.getElementById('connectionStatus').textContent = 'Authenticating and discovering Ops clusters and counters...';
        var xhr = new XMLHttpRequest(), settled = false;
        function finish(error) {
            if (settled) return; settled = true;
            analysisInProgress = false; missedBeats = 0; setConnectionBusy(false); setConnectionMode('ops');
            document.getElementById('opsPass').value = ''; payload.pass = '';
            if (error) { document.getElementById('connectionStatus').textContent = 'Ops connection failed. Previous assessment data is retained.'; showToast(error, 'error'); }
        }
        xhr.open('POST', '/api/ops/connect', true); xhr.setRequestHeader('Content-Type', 'application/json'); xhr.timeout = 900000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4 || xhr.status === 0 || settled) return;
            if (xhr.status !== 200) { finish('Ops connection failed (HTTP ' + xhr.status + ').'); return; }
            try {
                var data = JSON.parse(xhr.responseText);
                if (data.error) { finish(data.error); return; }
                if (!data.clusters || !data.clusters.length) { finish('Ops returned no accessible clusters.'); return; }
                clusterSessionCache = {}; liveClusterLabels = {};
                cachedHosts = []; cachedVms = []; cachedFailedVms = []; lastAppliedClusterKey = null;
                var cSelect = document.getElementById('clusterSelect'), simSelect = document.getElementById('simClusterSelect');
                cSelect.innerHTML = ''; simSelect.innerHTML = '';
                mtSortLiveClusters(data.clusters).forEach(function(c) {
                    liveClusterLabels[c.Value] = { cluster: c.Label, server: c.Server };
                    var html = '<option value="' + escapeHtml(c.Value) + '">' + escapeHtml(c.Text) + '</option>';
                    cSelect.innerHTML += html; simSelect.innerHTML += html;
                });
                if (document.getElementById('importSourceType').value === 'vrops') { document.getElementById('importSourceType').value = 'mtat'; toggleImportSourceFields(); }
                document.getElementById('scopeSelectionPanel').style.display = 'grid';
                document.getElementById('analyzeBtn').parentNode.style.display = 'flex';
                var panel = document.getElementById('importPanel'); if (panel.style.display === 'block') toggleImportPanel();
                document.getElementById('content-baseline').style.display = 'block'; document.getElementById('lockout-baseline').style.display = 'none';
                ['baseline','advanced','simulator'].forEach(function(t) { document.getElementById('btn-tab-' + t).style.display = 'block'; });
                // Clear prior-source displays; no old assessment may appear to belong to the new session.
                ['metricsDisplayCard','comparisonContainer','hostContainerPanel','vmContainerPanel','content-simulator','repToolbarBase'].forEach(function(id) { document.getElementById(id).style.display = 'none'; });
                clearProgressChips('connectProgressChips'); rebuildGroupedMatrix(); refreshAdvancedTab(); refreshClusterOptionLabels();
                document.getElementById('connectionStatus').textContent = 'Connected to ' + data.version + ' at ' + server + '. Select a cluster and range on Tab 2.';
                mtatOfflineMode = false; mtatShowOfflineSaved = false; mtatSyncJobVisibility();
                finish(); loadClusterRanges(); switchTab('tab-baseline', document.getElementById('btn-tab-baseline'));
            } catch (e) { finish('Could not read the Ops connection result: ' + e.message); }
        };
        xhr.onerror = function() { finish('Connection to the MTAT engine was lost during Ops discovery.'); };
        xhr.ontimeout = function() { finish('Ops connection timed out. Check the appliance and reconnect.'); };
        xhr.onabort = function() { finish('Ops connection was cancelled.'); };
        xhr.send(JSON.stringify(payload));
    }
    function mtOpsPeakUtc(ms) {
        return typeof ms === 'number' && isFinite(ms) ? new Date(ms).toISOString().replace('T', ' ').replace('.000Z', ' UTC') : 'No data';
    }
    function mtOpsPeakRows(hosts) {
        return (hosts || []).filter(function(h) { return typeof h.Active_Peak_Timestamp === 'number' && isFinite(h.Active_Peak_Timestamp); });
    }
    function mtOpsPeakRawGb(h) {
        var raw=h.Active_Peak_Raw,factor=h.Active_Peak_Factor;
        if(raw===null || raw===undefined || String(raw).trim()==='' || factor===null || factor===undefined || String(factor).trim()==='')return null;
        raw=Number(raw);factor=Number(factor);var value=raw*factor;
        return isFinite(raw) && raw>=0 && isFinite(factor) && factor>0 && isFinite(value)?value:null;
    }
    function mtOpsPeakEvidenceHtml(hosts, allowExport) {
        var rows = mtOpsPeakRows(hosts);
        if (!rows.length) return '<p>No retained Ops active-memory peak evidence is available for this result. Reanalyze the range to collect it.</p>';
        var text = '<details open style="margin:12px 0"><summary><b>Verify Ops active-memory peaks</b></summary><p>Cluster peak = sum of host peaks divided by total listed capacity. Host peaks may occur at different times. The capacity denominator is current inventory; historical capacity changes can affect the percentage. In Ops, select each host and inspect Memory / Guest Active at the UTC timestamp below, using the finest retained resolution. Keep genuine spikes until verified.</p>';
        if (allowExport) text += '<button class="btn btn-sm" onclick="exportOpsPeakEvidence()">Export Peak Evidence CSV</button>';
        text += '<div style="overflow-x:auto"><table class="comp-table"><thead><tr><th>Host</th><th>Peak UTC</th><th>Ops value (GB)</th><th>Peak GB</th><th>Capacity GB (current)</th><th>Peak %</th><th>Samples</th><th>Peak interval (s)</th><th>Observed active samples UTC</th></tr></thead><tbody>';
        rows.forEach(function(h) {
            var cells = [obfExport('host', h.HostName), mtOpsPeakUtc(h.Active_Peak_Timestamp), mtOpsPeakRawGb(h)===null?'No data':fmt(mtOpsPeakRawGb(h),6), h.Active_GB, mtCapacityLabel(h), h.Active_Pct, h.Active_Sample_Count, h.Active_Peak_Interval_Seconds, mtOpsPeakUtc(h.Active_First_Timestamp) + ' to ' + mtOpsPeakUtc(h.Active_Last_Timestamp)];
            text += '<tr>' + cells.map(function(v) { return '<td>' + escapeHtml(v) + '</td>'; }).join('') + '</tr>';
        });
        return text + '</tbody></table></div><p>Metric: mem|active_average. Ops values are displayed in decimal GB. The peak-evidence CSV in MTAT retains original values, units and conversion factors for verification. Missing coverage or unverified capacity still blocks qualification.</p></details>';
    }
    function mtOpsPeakEvidenceCsv(hosts, rangeLabel) {
        var lines = [['Range','Host','Metric','Peak_UTC','Raw_Value','Raw_Unit','GB_Per_Raw_Unit','Peak_GB','Capacity_GB_Current','Capacity_Verified','Peak_Pct','Retained_Samples','Peak_Interval_Seconds','First_Active_Sample_UTC','Last_Active_Sample_UTC','Retained_Intervals_Seconds']];
        mtOpsPeakRows(hosts).forEach(function(h) { lines.push([rangeLabel, obfExport('host', h.HostName), h.Active_Metric_Key, mtOpsPeakUtc(h.Active_Peak_Timestamp), h.Active_Peak_Raw, h.Active_Peak_Unit, h.Active_Peak_Factor, h.Active_GB, h.Physical_RAM, !mtHas(h,'Capacity') && h.Physical_RAM > 0, h.Active_Pct, h.Active_Sample_Count, h.Active_Peak_Interval_Seconds, mtOpsPeakUtc(h.Active_First_Timestamp), mtOpsPeakUtc(h.Active_Last_Timestamp), h.Active_Intervals_Seconds]); });
        return lines.map(function(row) { return row.map(csvField).join(','); }).join('\r\n') + '\r\n';
    }
    function exportOpsPeakEvidence() {
        var cache = clusterSessionCache[lastAppliedClusterKey], range = cache ? cache.lastRange : '', parsed = cache && cache.ranges[range];
        if (!parsed || parsed.source !== 'ops' || !mtOpsPeakRows(parsed.hosts).length) { showToast('Reanalyze an Ops range to collect peak evidence.', 'warn'); return; }
        downloadBlobTrigger(mtOpsPeakEvidenceCsv(parsed.hosts, range), 'MTAT_Ops_Peak_Evidence.csv');
    }

    function mtMissingCounterHosts(hosts) {
        return (hosts || []).filter(function(h) { return mtHas(h, 'CPU') || mtHas(h, 'Active') || mtHas(h, 'Consumed'); });
    }
    function mtCapacityLabel(host) {
        return mtHas(host, 'Capacity') ? 'Unverified (' + host.Physical_RAM + ' GB)' : String(host.Physical_RAM);
    }
    function mtAssessmentMissing(hosts) {
        return (hosts || []).filter(function(h) { return h.Tiering === 'Unknown' || mtHas(h, 'Active') || mtHas(h, 'Eligibility') || mtHas(h, 'Capacity') || mtHas(h, 'Coverage') || mtHas(h, 'TierConfig'); });
    }

    function mtSortLiveClusters(clusters) {
        var items = !clusters ? [] : (Array.isArray(clusters) ? clusters.slice() : [clusters]);
        var options = { numeric: true, sensitivity: 'base' };
        return items.sort(function(a, b) {
            return String(a.Label || a.Text || '').localeCompare(String(b.Label || b.Text || ''), undefined, options) ||
                String(a.Text || '').localeCompare(String(b.Text || ''), undefined, options) ||
                String(a.Value || '').localeCompare(String(b.Value || ''), undefined, options);
        });
    }

    function runVcenterConnectPipeline() {
        // Restore normal online mode elements if coming from offline mode
        if (document.getElementById('importSourceType').value === 'vrops') { document.getElementById('importSourceType').value = 'mtat'; toggleImportSourceFields(); }
        var scopePanel = document.getElementById('scopeSelectionPanel');
        if (scopePanel) scopePanel.style.display = 'grid'; // Originally control-grid
        
        var analyzeBtnWrap = document.getElementById('analyzeBtn').parentNode;
        if (analyzeBtnWrap) analyzeBtnWrap.style.display = 'flex';
        
        // Hide the import panel by default when in online mode
        var panel = document.getElementById('importPanel');
        if (panel && panel.style.display === 'block') {
            toggleImportPanel();
        }

        var importTitle = document.querySelector('#importPanel .panel-title');
        if (importTitle && importTitle.innerHTML.includes('Offline Mode')) {
            importTitle.innerHTML = 'Import Previously Collected Data';
        }

        var btn = document.getElementById('connectBtn');
        var servers = parseServersInput();
        if (servers.length === 0) { showToast("Please declare a vCenter.", 'warn'); return; }

        setConnectionBusy(true); btn.innerText = "Connecting...";
        buildProgressChips('connectProgressChips', servers);
        var useSame = document.getElementById('useSameCreds').checked;
        var certBox = document.getElementById('requireValidCerts');
        var payload = { targets: [], requireValidCerts: !!(certBox && certBox.checked) };

        if (useSame) {
            var u = document.getElementById('vcUser').value;
            var p = document.getElementById('vcPass').value;
            for (var i = 0; i < servers.length; i++) payload.targets.push({ server: servers[i], user: u, pass: p });
        } else {
            var userInputs = document.querySelectorAll('.vc-sub-user');
            var passInputs = document.querySelectorAll('.vc-sub-pass');
            for (var j = 0; j < userInputs.length; j++) {
                payload.targets.push({
                    server: userInputs[j].getAttribute('data-server'), user: userInputs[j].value, pass: passInputs[j].value
                });
            }
        }

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "/api/connect", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                setConnectionBusy(false); setConnectionMode('vcenter');
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data.error) { showToast("vCenter Connection Error: " + data.error, 'error'); clearProgressChips('connectProgressChips'); return; }

                        // A (re)connect can point at an entirely different vCenter / server set than
                        // whatever was cached before -- clear it so a cluster name that happens to
                        // match one from the previous session can't silently serve stale data from a
                        // different vCenter (nothing here re-fetches on cluster-name collision alone).
                        clusterSessionCache = {}; liveClusterLabels = {};
                        document.getElementById('connectionStatus').textContent = 'vCenter connection completed. Select a cluster and range on Tab 2.';
                        cachedHosts = []; cachedVms = []; cachedFailedVms = []; lastAppliedClusterKey = null;
                        ['metricsDisplayCard','comparisonContainer','hostContainerPanel','vmContainerPanel','content-simulator','repToolbarBase'].forEach(function(id) { document.getElementById(id).style.display = 'none'; });
                        rebuildGroupedMatrix(); refreshAdvancedTab();

                        var failedServers = {};
                        if (data.failedTargets && data.failedTargets.length > 0) {
                            var failedList = data.failedTargets.map(function(t) { failedServers[t.server] = t.error; return t.server + ": " + t.error; }).join("\n");
                            showToast("Connected, but " + data.failedTargets.length + " target(s) failed and were skipped:\n\n" + failedList, 'warn');
                        }
                        for (var s = 0; s < servers.length; s++) {
                            if (failedServers.hasOwnProperty(servers[s])) { setProgressChipState('connectProgressChips', s, 'failed', servers[s] + ' failed'); }
                            else { setProgressChipState('connectProgressChips', s, 'done', servers[s] + ' connected'); }
                        }

                        var cSelect = document.getElementById('clusterSelect'); cSelect.innerHTML = "";
                        var simSelect = document.getElementById('simClusterSelect'); simSelect.innerHTML = "";
                        var cList = mtSortLiveClusters(data.clusters);
                        for (var i = 0; i < cList.length; i++) {
                            var optHtml = "<option value='" + escapeHtml(cList[i].Value) + "'>" + escapeHtml(cList[i].Text) + "</option>";
                            cSelect.innerHTML += optHtml;
                            simSelect.innerHTML += optHtml;
                        }
                        refreshClusterOptionLabels();
                        mtatOfflineMode = false; mtatShowOfflineSaved = false; mtatSyncJobVisibility();
                        document.getElementById('scopeSelectionPanel').style.display = 'grid';
                        document.getElementById('analyzeBtn').parentNode.style.display = 'flex';

                        document.getElementById('content-baseline').style.display = 'block';
                        document.getElementById('lockout-baseline').style.display = 'none';
                        document.getElementById('btn-tab-baseline').style.display = 'block';
                        document.getElementById('btn-tab-simulator').style.display = 'block';
                        document.getElementById('btn-tab-advanced').style.display = 'block';

                        loadClusterRanges();
                        switchTab('tab-baseline', document.getElementById('btn-tab-baseline'));
                    } catch(e) {
                        showToast("Response Formatting Trapped: " + e.message + "\n\nRaw Trace:\n" + xhr.responseText, 'error');
                        clearProgressChips('connectProgressChips');
                    }
                } else if (xhr.status !== 0) {
                    showToast("Fatal Web Channel Anomaly. HTTP Status: " + xhr.status + " (" + xhr.statusText + ")", 'error');
                    clearProgressChips('connectProgressChips');
                }
            }
        };
        xhr.onerror = function() {
            setConnectionBusy(false); setConnectionMode('vcenter');
            showToast("Connection lost or network channel handshake dropped completely during vCenter authentication.", 'error');
            clearProgressChips('connectProgressChips');
        };
        xhr.send(JSON.stringify(payload));
    }

    function loadClusterRanges() {
        var activeCluster = document.getElementById('clusterSelect').value;
        if (!activeCluster) return;
        if (rvLoadCachedRanges(activeCluster)) return;

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "/api/get-cluster-ranges", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (document.getElementById('clusterSelect').value !== activeCluster) return;
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data.error) { showToast("Error reading cluster ranges: " + data.error, 'error'); return; }
                        var rDiv = document.getElementById('rangeCheckboxes'); rDiv.innerHTML = "";
                        var rList = data.ranges; 
                        
                        if (!rList) return;
                        if (typeof rList === 'string') rList = [rList];
                        
                        document.getElementById('selectAllToggle').innerText = "Select All";
                        for (var j = 0; j < rList.length; j++) {
                            var isChecked = (rList[j] === "Real-Time Snapshot" || rList[j] === "Latest Ops Sample" || (activeCluster.indexOf("Ops:") === 0 && rList[j] === "Past 24 Hours")) ? "checked" : "";
                            var safeRange = escapeHtml(rList[j]);
                            rDiv.innerHTML += '<label class="checkbox-item"><input type="checkbox" class="range-cb" value="' + safeRange + '" ' + isChecked + '> ' + safeRange + '</label>';
                        }
                    } catch(e) { showToast("Error parsing cluster ranges: " + e.message, 'error'); }
                } else if (xhr.status !== 0) {
                    showToast("Range discovery fault mapping endpoint code: " + xhr.status, 'error');
                }
            }
        };
        xhr.onerror = function() { showToast("Network dropped querying historical cluster range limits.", 'error'); };
        xhr.send(JSON.stringify({ cluster: activeCluster }));
    }

    // Applies a fully-formed analysis result ({dram, consumed, active, cpu, hosts[], vms[]}) to the
    // Baseline Assessment UI and the Sizing & Savings simulator. Shared by both the live vCenter
    // analyze path and the offline Import path so the two stay pixel-for-pixel identical downstream.
    function applyAnalysisResult(activeClusterValue, rangeLabel, parsed) {
        mtatNormalizeAnalysisArrays(parsed);
        if (obfOn()) obfuscateParsedResult(parsed);
        // Guard against incomplete data from any of this function's three possible origins (live
        // analyze, CSV import, or a cached matrix record). Without this, a missing dram/consumed/
        // active/cpu field previously rendered as the literal string "undefined%" and/or silently
        // produced a false PASS/WARN badge below (JS comparisons against undefined/NaN don't error,
        // they just quietly evaluate to something that looks like a real, healthy result).
        var coreFieldsMissing = [];
        if (typeof parsed.dram !== 'number') coreFieldsMissing.push('dram');
        if (typeof parsed.consumed !== 'number') coreFieldsMissing.push('consumed');
        if (typeof parsed.active !== 'number') coreFieldsMissing.push('active');
        if (typeof parsed.cpu !== 'number' && !parsed.cpuUnavailable) coreFieldsMissing.push('cpu');

        globalDram = (typeof parsed.dram === 'number') ? parsed.dram : 0;
        globalConsumed = (typeof parsed.consumed === 'number') ? parsed.consumed : 0;
        globalActive = (typeof parsed.active === 'number') ? parsed.active : 0;
        globalCpu = (typeof parsed.cpu === 'number') ? parsed.cpu : 0;
        // activeAvg is a reference-only companion to the peak Active Memory figure. It's optional:
        // live vCenter analysis always supplies it, but a re-imported MTAT export can't (the exported
        // CSV never retained a separate average), so it may be missing -- rendered as "N/A" below.
        globalActiveAvg = (typeof parsed.activeAvg === 'number') ? parsed.activeAvg : null;
        cachedHosts = parsed.hosts || []; cachedVms = parsed.vms || []; cachedFailedVms = parsed.failedVms || [];
        var peakPanel = document.getElementById('opsPeakEvidence');
        if (peakPanel) peakPanel.innerHTML = parsed.source === 'ops' ? mtOpsPeakEvidenceHtml(cachedHosts, true) : '';

        if (!clusterSessionCache[activeClusterValue]) {
            clusterSessionCache[activeClusterValue] = { lastRange: "", ranges: {} };
        }
        clusterSessionCache[activeClusterValue].lastRange = rangeLabel;
        lastAppliedClusterKey = activeClusterValue;
        clusterSessionCache[activeClusterValue].ranges[rangeLabel] = parsed;

        document.getElementById('content-simulator').style.display = 'block';
        document.getElementById('metricsDisplayCard').style.display = 'block';
        document.getElementById('comparisonContainer').style.display = 'block';
        document.getElementById('hostContainerPanel').style.display = 'block';
        document.getElementById('vmContainerPanel').style.display = 'block';
        document.getElementById('btnExportAll').style.display = 'block';

        // Surfaces host/VM collection failures directly in the UI, not just the debug log -- this is
        // what "the tool isn't pulling all the data" looks like when it happens: a host or VM that
        // threw mid-collection (e.g. a transient Get-View/esxcli hiccup) and got excluded rather than
        // silently zeroed out. Live-analyze/import responses that predate this feature simply won't
        // have these fields, so this stays hidden for those.
        var failureWarnDiv = document.getElementById('rowCollectionFailureWarn');
        var failedHosts = parsed.failedHosts || [];
        var failedVms = parsed.failedVms || [];
        var warnMsgParts = [];
        if (failedHosts.length > 0 || failedVms.length > 0) {
            var parts = [];
            if (failedHosts.length > 0) parts.push(failedHosts.length + " host(s) [" + failedHosts.map(escapeHtml).join(", ") + "]");
            if (failedVms.length > 0) parts.push(failedVms.length + " VM(s) [" + failedVms.map(escapeHtml).join(", ") + "]");
            warnMsgParts.push("&#9888; Data collection failed for " + parts.join(" and ") + " during this analysis -- they're excluded from the totals below (failed hosts still show as a row marked \"ERROR\"), and the Active Memory check shows CHECK DATA until every host and VM is collected (a missing VM could be one that has to stay in DRAM). Download the debug log (top-right) for details.");
        }
        if (parsed.dataNotes && parsed.dataNotes.length > 0) {
            warnMsgParts.push("&#9432; " + parsed.dataNotes.map(escapeHtml).join("<br>&#9432; "));
        }
        // Counters vCenter returned no samples for, and DRAM-only VMs: both feed the badges below.
        var baseDOnly = mtDramOnly(cachedVms), baseSizingPct = mtActivePct(globalDram, globalActive, baseDOnly);
        var missActHosts = mtMissing(cachedHosts, 'Active'), missCpuHosts = mtMissing(cachedHosts, 'CPU'), missVms = mtMissing(cachedVms, 'Active');
        var missAnyHosts = mtMissingCounterHosts(cachedHosts);
        if (missAnyHosts.length > 0) {
            warnMsgParts.push("&#9888; The data source returned no samples for one or more performance counters on " + missAnyHosts.length + " host(s): " + missAnyHosts.map(function(h) { return escapeHtml(h.HostName) + " (" + escapeHtml(h.Missing_Metrics) + ")"; }).join(", ") + ". Those values show as \"No data\" and count as 0 in the totals, so the affected checks below show CHECK DATA instead of PASS. Check collection status, counter availability and retained history for the selected data source.");
        }
        var unverifiedConfig = cachedHosts.filter(function(h) { return mtHas(h, 'Capacity') || mtHas(h, 'TierConfig') || mtHas(h, 'Eligibility'); });
        if (unverifiedConfig.length) warnMsgParts.push('&#9888; Configuration could not be verified for ' + unverifiedConfig.length + ' host(s). Available CPU, active and consumed measurements are still displayed. Physical DRAM, tier configuration or VM eligibility needs verification before qualification and savings can be confirmed.');
        if (missVms.length > 0) {
            warnMsgParts.push("&#9432; " + missVms.length + " VM(s) returned no Active Memory samples for this range (shown as \"No data\" in the VM table), usually because they were powered on only recently. The cluster totals come from the hosts, so they are not affected.");
        }
        if (baseDOnly.n > 0) {
            warnMsgParts.push("&#9432; " + baseDOnly.n + " VM(s) must keep their memory in DRAM (" + Math.round(baseDOnly.gb) + " GB in total; see DRAM_Only in the VM table). That memory is never moved to NVMe, so the Active Memory check uses the " + Math.max(0, Math.round(globalDram - baseDOnly.gb)) + " GB of DRAM left for tiering: Active Memory is " + mtPctLabel(baseSizingPct) + " of it.");
        }
        var tierUnknownHosts = parsed.source && parsed.source !== 'ops' ? [] : mtTierUnknown(cachedHosts);
        if (tierUnknownHosts.length > 0) {
            warnMsgParts.push("&#9888; Memory Tiering status could not be read on " + tierUnknownHosts.length + " host(s): " + tierUnknownHosts.map(function(h) { return escapeHtml(h.HostName); }).join(", ") + (parsed.source === 'ops' ? " (shown as Unknown). Qualification and savings remain unverified; no enabled/disabled tier state is assumed." : " (shown as Unknown). Confirm in vCenter before quoting savings."));
        }
        if (coreFieldsMissing.length > 0) {
            warnMsgParts.push("&#9888; This data is incomplete -- missing: " + coreFieldsMissing.map(escapeHtml).join(", ") + " (defaulted to 0). The PASS/WARN badges below may not reflect real values. This usually means an older or partial import/cache record rather than a live analysis.");
        }
        if (warnMsgParts.length > 0) {
            var needsReview = failedHosts.length || failedVms.length || missAnyHosts.length || missVms.length ||
                mtAssessmentMissing(cachedHosts).length || tierUnknownHosts.length || coreFieldsMissing.length ||
                (parsed.dataNotes || []).some(function(note) { return /^CHECK DATA:/i.test(note); });
            var diagnosticsSummary = needsReview ? '<b>CHECK DATA</b> - expand assessment details' : 'Assessment notes and collection details';
            failureWarnDiv.innerHTML = '<details class="assessment-diagnostics"><summary style="cursor:pointer;">' + diagnosticsSummary +
                '</summary><div style="margin-top:10px;">' + warnMsgParts.join("<br>") + '</div></details>';
            failureWarnDiv.style.display = 'block';
        } else {
            failureWarnDiv.style.display = 'none';
        }

        document.getElementById('lblChecklistTitle').innerText = "Baseline Qualification Checklist (Raw Hardware - " + rangeLabel + "):";

        var activePct = globalDram > 0 ? ((globalActive / globalDram) * 100).toFixed(1) : 0;
        var consumedPct = globalDram > 0 ? ((globalConsumed / globalDram) * 100).toFixed(1) : 0;
        var activeAvgPct = (globalActiveAvg !== null && globalDram > 0) ? ((globalActiveAvg / globalDram) * 100).toFixed(1) : null;

        document.getElementById('lblBaseCpu').innerText = parsed.cpuUnavailable ? "N/A" : (globalCpu + "%");
        // With DRAM-only VMs the check uses Active Memory against the DRAM left for tiering; show both.
        document.getElementById('lblBaseActive').innerText = activePct + "%" + (baseDOnly.n > 0 ? " (" + mtPctLabel(baseSizingPct) + " of DRAM left for tiering)" : "");
        document.getElementById('lblBaseActiveAvg').innerText = (activeAvgPct === null) ? "N/A" : (activeAvgPct + "%");
        document.getElementById('lblBaseConsumed').innerText = consumedPct + "%";

        // Burstiness flag: a peak far above the average means the workload is spiky, which is worth
        // a second look before sizing around a single peak sample (real recurring pattern vs. a
        // one-off blip in the analyzed window). Needs both a large ratio AND a non-trivial absolute
        // gap, so a near-idle cluster (e.g. 0.5% avg / 2% peak) doesn't trip this on noise alone.
        var activeVarDiv = document.getElementById('rowActiveVariabilityWarn');
        if (activeAvgPct === null) {
            activeVarDiv.style.display = 'none';
        } else {
            var peakPctNum = parseFloat(activePct);
            var avgPctNum = parseFloat(activeAvgPct);
            var gapPts = peakPctNum - avgPctNum;
            var isBursty = (avgPctNum <= 0) ? (peakPctNum > 0) : ((peakPctNum / avgPctNum) >= 2);
            if (isBursty && gapPts >= 10) {
                var varyMsg = (avgPctNum > 0)
                    ? "peak is " + (peakPctNum / avgPctNum).toFixed(1) + "x the average"
                    : "average is ~0% but peak reaches " + peakPctNum.toFixed(1) + "%";
                activeVarDiv.innerText = "[ ! ] High variability: " + varyMsg + " (" + gapPts.toFixed(1) + " pt gap). Confirm this reflects a recurring pattern -- compare across ranges -- before sizing around it.";
                activeVarDiv.style.display = 'block';
            } else {
                activeVarDiv.style.display = 'none';
            }
        }

        var cpuB = document.getElementById('badgeBaseCpu');
        cpuB.innerText = globalCpu <= 50 ? "[ \u2713 ] PASS" : "[ X ] WARN";
        cpuB.className = globalCpu <= 50 ? "badge badge-pass" : "badge badge-warn";
        setPctBar('barBaseCpu', globalCpu, { pass: globalCpu <= 50 });
        if (parsed.cpuUnavailable) { cpuB.innerText = "[ i ] N/A"; cpuB.className = "badge badge-info"; }
        else if (missCpuHosts.length) { cpuB.innerText = "[ ! ] CHECK DATA"; cpuB.className = "badge badge-warn"; setPctBar('barBaseCpu', globalCpu, {}); }

        // The check uses Active Memory against the DRAM tiering can use (identical to Active / DRAM when
        // there are no DRAM-only VMs), and never passes while some hosts returned no Active samples.
        var activeOk = mtActiveOk(baseSizingPct);
        var activeB = document.getElementById('badgeBaseActive');
        activeB.innerText = activeOk ? "[ \u2713 ] PASS" : "[ X ] WARN";
        activeB.className = activeOk ? "badge badge-pass" : "badge badge-warn";
        var activeBarPct = baseDOnly.n > 0 ? Math.min(100, baseSizingPct) : activePct;
        setPctBar('barBaseActive', activeBarPct, { pass: activeOk });
        if (mtAssessmentMissing(cachedHosts).length || mtFailedHosts(cachedHosts).length || failedVms.length) { activeB.innerText = "[ ! ] CHECK DATA"; activeB.className = "badge badge-warn"; setPctBar('barBaseActive', activeBarPct, {}); }
        setPctBar('barBaseActiveAvg', activeAvgPct === null ? 0 : activeAvgPct, {});

        setPctBar('barBaseConsumed', consumedPct, {});

        rebuildGroupedMatrix();

        // New data replaces the tables wholesale -- clear any leftover filter text/sort indicator
        // from a previous analysis so it can't silently hide/reorder rows that were never filtered.
        var hostFilterEl = document.getElementById('hostTableFilter'); if (hostFilterEl) hostFilterEl.value = "";
        var vmFilterEl = document.getElementById('vmTableFilter'); if (vmFilterEl) vmFilterEl.value = "";
        document.querySelectorAll('#hostTable th.sortable, #vmTable th.sortable').forEach(function(h) {
            h.removeAttribute('data-sort-dir');
            var arrow = h.querySelector('.sort-arrow'); if (arrow) arrow.textContent = '';
        });

        var hBody = document.querySelector('#hostTable tbody'); var hRowsHtml = [];
        for (var k = 0; k < cachedHosts.length; k++) {
            var h = cachedHosts[k];
            var rowStyle = (h.Tiering === "ERROR") ? " style=\"background-color:var(--soft-bg-danger); color:var(--text-danger-soft); font-weight:bold;\"" : "";
            // Cluster/HostName/Tiering can originate from a live vCenter object name OR an offline
            // CSV import (an arbitrary file picked from disk) -- escaped like every other dynamic
            // value in this function, rather than trusted as always-safe plain text.
            hRowsHtml.push("<tr" + rowStyle + "><td>" + escapeHtml(h.Cluster) + "</td><td>" + escapeHtml(h.HostName) + "</td><td>" + escapeHtml(h.Tiering) + "</td><td>" + (mtHas(h, 'CPU') ? "No data" : (typeof h.CPU_Pct === 'number' ? h.CPU_Pct + "%" : "N/A")) + "</td><td>" + escapeHtml(mtCapacityLabel(h)) + "</td><td>" + (mtHas(h, 'Consumed') ? "No data" : h.Consumed_GB) + "</td><td>" + (mtHas(h, 'Active') ? "No data" : h.Active_GB) + "</td><td>" + (mtHas(h, 'Active') ? "No data" : h.Active_Pct + "%") + "</td></tr>");
        }
        hBody.innerHTML = hRowsHtml.join("");

        var vBody = document.querySelector('#vmTable tbody'); var vRowsHtml = [];
        for (var m = 0; m < cachedVms.length; m++) {
            var v = cachedVms[m];
            var dramOnlyCell = (String(v.DRAM_Only || "").indexOf("Yes") === 0)
                ? "<span style=\"color:var(--text-warning-soft); font-weight:bold;\">" + escapeHtml(v.DRAM_Only) + "</span>"
                : escapeHtml(v.DRAM_Only || "N/A");
            var vNoData = mtHas(v, 'Active');
            vRowsHtml.push("<tr><td>" + escapeHtml(v.Host) + "</td><td>" + escapeHtml(v.VMName) + "</td><td>" + v.Provisioned_GB + "</td><td>" + (vNoData ? "No data" : v.Active_GB) + "</td><td>" + (vNoData ? "No data" : v.Active_Pct + "%") + "</td><td>" + dramOnlyCell + "</td><td>" + escapeHtml(v.Pages_1GB) + "</td><td>" + escapeHtml(v.Pages_2MB) + "</td></tr>");
        }
        vBody.innerHTML = vRowsHtml.join("");

        document.getElementById('simClusterSelect').value = activeClusterValue;
        loadClusterSimulation();
        mtatCollapseBaselineLists();
    }

    var mtatOfflineMode = false, mtatShowOfflineSaved = false, mtatCollectionBusy = false;
    function mtatSyncJobVisibility() {
        var panel = document.getElementById('mtatJobsPanel');
        if (!panel) return;
        var active = mtatCollectionBusy || (mtatJobState && ['running','runningDetached','cancelling'].indexOf(mtatJobState.status) >= 0);
        var show = active || (mtatOfflineMode ? mtatShowOfflineSaved : mtatJobLiveKeys().length > 0);
        panel.style.display = show ? 'block' : 'none';
        var access = document.getElementById('mtatSavedOfflineAccess');
        if (access) access.style.display = mtatOfflineMode && !active ? 'block' : 'none';
        var button = access ? access.querySelector('button') : null;
        if (button) button.textContent = mtatShowOfflineSaved ? 'Hide saved assessments' : 'Open saved assessments';
        var title = document.getElementById('mtatJobPanelTitle');
        if (title) title.textContent = mtatOfflineMode && !active ? 'Saved assessments' : 'Collection jobs and saved results';
        var resume = document.getElementById('mtatJobResume');
        if (resume) resume.style.display = mtatOfflineMode ? 'none' : '';
        var cancel = document.getElementById('mtatJobCancel');
        if (cancel) cancel.style.display = mtatOfflineMode && !active ? 'none' : '';
    }
    function mtatOpenOfflineSavedResults() {
        mtatShowOfflineSaved = !mtatShowOfflineSaved;
        mtatSyncJobVisibility();
        document.getElementById('mtatJobsPanel').open = mtatShowOfflineSaved;
        if (mtatShowOfflineSaved) mtatRefreshJobs();
    }

    var mtatActiveJobId = null, mtatJobState = null, mtatJobTimer = null, mtatJobLoading = false;
    var mtatSelectedTask = null, mtatLoadedResults = [], MTAT_JOB_CACHE_BYTES = 32 * 1024 * 1024;
    function mtatJobRequest(action, payload) {
        return new Promise(function(resolve, reject) {
            var xhr = new XMLHttpRequest(); xhr.open('POST', '/api/jobs/' + action, true); xhr.timeout = 20000;
            xhr.setRequestHeader('Content-Type', 'application/json');
            xhr.onload = function() { try { var data = JSON.parse(xhr.responseText); if (xhr.status !== 200 || data.error) throw new Error(data.error || 'Job request failed (' + xhr.status + ').'); if(data.tasks!==undefined)data.tasks=mtatAsArray(data.tasks,'job tasks');if(data.jobs!==undefined)data.jobs=mtatAsArray(data.jobs,'saved jobs');resolve(data); } catch(e) { reject(e); } };
            xhr.onerror = function() { reject(new Error('The engine is unreachable. Saved checkpoints remain available after restart.')); };
            xhr.ontimeout = function() { reject(new Error('Job status request timed out. Collection may still be running; refresh saved jobs before starting another.')); };
            xhr.send(JSON.stringify(payload || {}));
        });
    }
    function mtatJobLiveKeys() {
        return Array.prototype.map.call(document.getElementById('clusterSelect').options, function(o) { return o.value; }).filter(Boolean);
    }
    function mtatSetJobBusy(busy) {
        mtatCollectionBusy = busy;
        analysisInProgress = busy; missedBeats = 0;
        document.getElementById('analyzeBtn').disabled = busy;
        if (typeof setConnectionBusy === 'function') setConnectionBusy(busy);
        var cancel = document.getElementById('mtatJobCancel'); if (cancel) cancel.disabled = !busy;
        var loadAll=document.getElementById('mtatLoadAllResults');if(loadAll)loadAll.disabled=busy||mtatBulkJobLoading;
        mtatSyncJobVisibility();
    }
    function mtatStartCollectionJob() {
        var key = document.getElementById('clusterSelect').value;
        if (key && key.indexOf('RVTools|') === 0 && clusterSessionCache[key]) { executeLegacyClusterDataCollection(); return; }
        if (analysisInProgress || mtatJobLoading || mtatBulkJobLoading) { showToast('Wait for or cancel the current collection.', 'warn'); return; }
        var ranges = Array.prototype.map.call(document.querySelectorAll('.range-cb:checked'), function(cb) { return cb.value; });
        if (!key || !ranges.length) { showToast('Connect and select a cluster and at least one range.', 'warn'); return; }
        var keys = document.getElementById('mtatAllClusters').checked ? mtatJobLiveKeys() : [key];
        mtatSetJobBusy(true); document.getElementById('mtatJobsPanel').open = true;
        mtatJobRequest('start', {clusters: keys, ranges: ranges}).then(function(data) {
            mtatActiveJobId = data.id; mtatPollJob();
        }).catch(function(e) { mtatSetJobBusy(false); showToast(e.message, 'error'); mtatRefreshJobs(); });
    }
    function executeClusterDataCollection() { mtatStartCollectionJob(); }
    function mtatPreferredCompletedTask(tasks) {
        var complete = tasks.filter(function(t){return t.status === 'completed'});
        if (!complete.length) return null;
        var first = complete[0];
        var sameScope = complete.filter(function(t){return t.source === first.source && t.server === first.server && t.clusterId === first.clusterId});
        return sameScope.filter(function(t){return t.range === 'Past 24 Hours'})[0] || sameScope.filter(function(t){return /^Past (7|30|365) Days$/.test(t.range)})[0] || first;
    }
    function mtatPollJob() {
        clearTimeout(mtatJobTimer);
        if (!mtatActiveJobId) return;
        mtatJobRequest('status', {id: mtatActiveJobId}).then(function(data) {
            mtatRenderJob(data);
            var active = ['running','runningDetached','cancelling'].indexOf(data.status) >= 0;
            mtatSetJobBusy(active);
            if (active) mtatJobTimer = setTimeout(mtatPollJob, 1500);
            else {
                var first = mtatPreferredCompletedTask(data.tasks);
                if (first && mtatBulkAttemptedJob !== data.id) mtatLoadCompletedJobResults();
                mtatRefreshJobs(data.id);
            }
        }).catch(function(e) {
            mtatSetJobBusy(false); showToast(e.message, 'warn');
            document.getElementById('mtatJobStatus').textContent = 'Connection lost. Reopen this job after restarting the engine; completed results are saved.';
        });
    }
    function mtatRenderJob(data) {
        mtatJobState = data; mtatActiveJobId = data.id;
        var done = data.tasks.filter(function(t) { return t.status === 'completed'; }).length;
        var summary = data.status + ': ' + done + '/' + data.tasks.length + ' results saved';
        if (data.progress && data.status === 'running') summary += ' - ' + data.progress.phase + (data.progress.total ? ' (' + data.progress.done + '/' + data.progress.total + ')' : '');
        document.getElementById('mtatJobStatus').textContent = summary + (data.message ? '. ' + data.message : '') + '. Run started ' + data.createdUtc + '.';
        document.getElementById('mtatJobSummary').textContent = summary;
        document.getElementById('mtatJobResume').disabled = mtatOfflineMode || !mtatJobLiveKeys().length || ['running','runningDetached','cancelling','completed'].indexOf(data.status) >= 0;
        mtatSyncJobVisibility();
        var body = document.getElementById('mtatJobResults'); body.innerHTML = '';
        data.tasks.forEach(function(task) {
            var tr = document.createElement('tr');
            [obfExport('cluster',task.name), obfExport('server',task.server), task.range, task.status, String(task.hosts), String(task.vms)].forEach(function(value) { var td = document.createElement('td'); td.textContent = value; tr.appendChild(td); });
            var cell = document.createElement('td');
            if (task.status === 'completed') { var button = document.createElement('button'); button.className = 'btn btn-sm'; button.textContent = 'Open result'; button.onclick = function() { mtatLoadJobResult(task.index); }; cell.appendChild(button); }
            if (task.error) { var error = document.createElement('span'); error.textContent = ' ' + (obfOn() ? obfuscateLogText(task.error) : task.error); cell.appendChild(error); }
            tr.appendChild(cell); body.appendChild(tr);
        });
    }
    function mtatRefreshJobs(preferred) {
        return mtatJobRequest('list').then(function(data) {
            var select = document.getElementById('mtatJobSelect'), old = preferred || select.value;
            select.innerHTML = '';
            data.jobs.forEach(function(job) { var o = document.createElement('option'); o.value = job.id; o.textContent = job.createdUtc + ' - ' + job.status + ' (' + job.completed + '/' + job.total + ')'; select.appendChild(o); });
            if (data.jobs.some(function(j) { return j.id === old; })) select.value = old;
        }).catch(function(e) { showToast(e.message, 'warn'); });
    }
    function mtatOpenSavedJob() {
        var id = document.getElementById('mtatJobSelect').value; if (!id) return;
        if(mtatBulkJobLoading){showToast('Wait for collected results to finish loading.','info');return;}
        if(analysisInProgress && mtatActiveJobId && id!==mtatActiveJobId){showToast('Wait for or cancel the active job before switching jobs.','warn');return;}
        mtatJobRequest('status', {id:id}).then(function(data) { mtatRenderJob(data); document.getElementById('mtatJobsPanel').open = true; if (['running','runningDetached','cancelling'].indexOf(data.status)>=0) { mtatSetJobBusy(true); mtatPollJob(); } else { mtatLoadCompletedJobResults(); } }).catch(function(e) { showToast(e.message,'error'); });
    }
    function mtatCancelJob() {
        if (!mtatActiveJobId) return;
        mtatJobRequest('cancel',{id:mtatActiveJobId}).then(function() { mtatPollJob(); }).catch(function(e) { showToast(e.message,'error'); });
    }
    function mtatResumeJob() {
        if (!mtatActiveJobId || analysisInProgress) return;
        if (mtatOfflineMode || !mtatJobLiveKeys().length) { showToast('Reconnect to the original servers before resuming collection.', 'info'); return; }
        mtatSetJobBusy(true);
        mtatJobRequest('resume',{id:mtatActiveJobId,clusters:mtatJobLiveKeys()}).then(function(data) { mtatActiveJobId=data.id;mtatPollJob(); }).catch(function(e) { mtatSetJobBusy(false);showToast(e.message,'error'); });
    }
    function mtatMakeResultSpace(bytes) {
        if (bytes > MTAT_JOB_CACHE_BYTES) throw new Error('This result exceeds the browser memory budget. Its checkpoint remains saved; download it for offline processing.');
        var used=mtatLoadedResults.reduce(function(n,r){return n+r.bytes},0);
        while (mtatLoadedResults.length && used + bytes > MTAT_JOB_CACHE_BYTES) {
            var old=mtatLoadedResults.shift(),cache=clusterSessionCache[old.key];
            if(cache){delete cache.ranges[old.range];if(!Object.keys(cache.ranges).length)delete clusterSessionCache[old.key];else if(cache.lastRange===old.range)cache.lastRange=Object.keys(cache.ranges)[0];}
            used-=old.bytes;
        }
    }
    var mtatBulkJobLoading = false, mtatBulkAttemptedJob = null, mtatBulkLastError = '';
    function mtatJobResultKey(id, task) { return 'SavedJob:'+id+'|'+task.source+':'+task.server+':'+task.clusterId; }
    function mtatJobResultCached(id, task) {
        var cache=clusterSessionCache[mtatJobResultKey(id,task)];return cache && cache.ranges[task.range];
    }
    function mtatJobScopeIssue(scope) {
        if(scope==='selected' || typeof mtatJobState==='undefined' || !mtatJobState)return '';
        var data=mtatJobState;if(!data.id || !Array.isArray(data.tasks))return '';
        var relevant=['running','runningDetached','cancelling'].indexOf(data.status)>=0 || mtatBulkAttemptedJob===data.id || mtatLoadedResults.some(function(r){return r.id===data.id});
        if(!relevant)return '';
        if(mtatBulkJobLoading)return 'Loading collected results. Wait before exporting all clusters.';
        var unfinished=data.tasks.filter(function(t){return t.status!=='completed'});
        if(unfinished.length)return 'This collection has '+unfinished.length+' unfinished or failed range(s). Finish or resume the job before exporting all collected clusters; individual completed clusters remain available.';
        var missing=data.tasks.filter(function(t){return !mtatJobResultCached(data.id,t)});
        if(missing.length)return missing.length+' collected range(s) are saved but not loaded. Use Load all completed results before exporting all clusters. '+mtatBulkLastError;
        return '';
    }
    function mtatCacheJobResult(id, task, parsed) {
        mtatNormalizeAnalysisArrays(parsed);
        if(obfOn())obfuscateParsedResult(parsed);
        var key=mtatJobResultKey(id,task);
        liveClusterLabels[key]={cluster:task.name,server:task.server,source:task.source};
        parsed.savedJob=true;
        if(!clusterSessionCache[key])clusterSessionCache[key]={lastRange:'',ranges:{}};
        clusterSessionCache[key].ranges[task.range]=parsed;clusterSessionCache[key].lastRange=task.range;
        mtatLoadedResults=mtatLoadedResults.filter(function(r){return !(r.key===key && r.range===task.range)});
        mtatLoadedResults.push({id:id,key:key,range:task.range,bytes:task.bytes});
        return key;
    }
    function mtatDisplayJobResult(task,key,parsed,fleet) {
        ['baseline','advanced','simulator'].forEach(function(t){document.getElementById('btn-tab-'+t).style.display='block'});
        document.getElementById('content-baseline').style.display='block';document.getElementById('lockout-baseline').style.display='none';
        addSimClusterOptions(Object.keys(clusterSessionCache));document.getElementById('simClusterSelect').value=key;
        mtatSelectedTask={id:mtatJobState.id,index:task.index};
        applyAnalysisResult(key,task.range,parsed);
        refreshAdvancedTab(fleet && advClusterKeys().length>1 ? ADV_FLEET : key, task.range);
        var note=document.getElementById('mtatLoadedNotice');note.style.display='block';
        var count=mtatJobState.tasks.filter(function(t){return t.status==='completed' && mtatJobResultCached(mtatJobState.id,t)}).length;
        var clusters={};mtatJobState.tasks.forEach(function(t){if(mtatJobResultCached(mtatJobState.id,t))clusters[mtatJobResultKey(mtatJobState.id,t)]=true});
        note.textContent='Loaded '+Object.keys(clusters).length+' collected cluster(s), '+count+' range result(s). Assessment details show '+obfExport('cluster',task.name)+' - '+task.range+'. '+(fleet?'Advanced Analytics defaults to all loaded clusters. ':'')+'Reports include loaded results; saved checkpoints remain on disk.';
        switchTab('tab-baseline',document.getElementById('btn-tab-baseline'));
    }
    function mtatLoadJobResult(index) {
        if(!mtatJobState || mtatJobLoading || mtatBulkJobLoading)return Promise.resolve();
        var task=mtatJobState.tasks.filter(function(t){return t.index===index})[0],id=mtatJobState.id;
        if(!task || task.status!=='completed')return Promise.resolve();
        var cached=mtatJobResultCached(id,task);
        if(cached){mtatDisplayJobResult(task,mtatJobResultKey(id,task),cached,false);return Promise.resolve()}
        try{mtatMakeResultSpace(task.bytes)}catch(e){showToast(e.message,'warn');return Promise.resolve()}
        mtatJobLoading=true;
        return mtatJobRequest('result',{id:id,index:index}).then(function(parsed){
            if(!mtatJobState || mtatJobState.id!==id)throw Error('Saved job changed while a result was loading.');
            var key=mtatCacheJobResult(id,task,parsed);mtatDisplayJobResult(task,key,parsed,false);
        }).catch(function(e){showToast(e.message,'error')}).then(function(){mtatJobLoading=false});
    }
    function mtatLoadCompletedJobResults() {
        if(!mtatJobState || mtatJobLoading || mtatBulkJobLoading)return Promise.resolve(false);
        if(['running','runningDetached','cancelling'].indexOf(mtatJobState.status)>=0){showToast('Wait for collection to finish before loading its complete result set.','info');return Promise.resolve(false);}
        var data=mtatJobState,id=data.id,tasks=data.tasks.filter(function(t){return t.status==='completed'});
        mtatBulkAttemptedJob=id;mtatBulkLastError='';
        if(!tasks.length)return Promise.resolve(false);
        var bytes=tasks.reduce(function(n,t){return n+(Number(t.bytes)||0)},0);
        if(tasks.some(function(t){return typeof t.bytes!=='number'||t.bytes<0}) || bytes>MTAT_JOB_CACHE_BYTES){
            mtatBulkLastError='The complete job exceeds the '+Math.round(MTAT_JOB_CACHE_BYTES/1048576)+' MB browser result budget. Open individual results or use fewer clusters/ranges in one assessment; every checkpoint remains saved.';
            document.getElementById('mtatLoadedNotice').style.display='block';document.getElementById('mtatLoadedNotice').textContent=mtatBulkLastError+' All-cluster export is unavailable while collected results are missing.';
            showToast(mtatBulkLastError,'warn');return Promise.resolve(false);
        }
        mtatBulkJobLoading=true;document.getElementById('mtatLoadAllResults').disabled=true;
        // Replace previous saved-job browser facts, preserving unrelated imports and all disk checkpoints.
        // Preflight above prevents eviction of an earlier cluster from this job while later ones load.
        mtatLoadedResults.forEach(function(r){if(r.id!==id){var c=clusterSessionCache[r.key];if(c){delete c.ranges[r.range];if(!Object.keys(c.ranges).length)delete clusterSessionCache[r.key]}}});
        mtatLoadedResults=mtatLoadedResults.filter(function(r){return r.id===id});
        var chain=Promise.resolve(),loaded=0;
        tasks.forEach(function(task){chain=chain.then(function(){
            document.getElementById('mtatJobStatus').textContent='Loading collected result '+(++loaded)+' of '+tasks.length+'...';
            if(mtatJobResultCached(id,task))return;
            return mtatJobRequest('result',{id:id,index:task.index}).then(function(parsed){
                if(!mtatJobState||mtatJobState.id!==id)throw Error('Saved job changed while loading collected results.');
                mtatCacheJobResult(id,task,parsed);
            });
        })});
        return chain.then(function(){
            var groups={};tasks.forEach(function(t){var key=mtatJobResultKey(id,t);(groups[key]||(groups[key]=[])).push(t)});
            Object.keys(groups).forEach(function(k){clusterSessionCache[k].lastRange=mtatPreferredCompletedTask(groups[k]).range});
            var first=mtatPreferredCompletedTask(tasks),key=mtatJobResultKey(id,first);
            mtatDisplayJobResult(first,key,mtatJobResultCached(id,first),true);
            mtatBulkJobLoading=false;document.getElementById('mtatLoadAllResults').disabled=false;
            document.getElementById('mtatJobStatus').textContent='Loaded all '+tasks.length+' completed range results across '+Object.keys(groups).length+' collected clusters.';
            return true;
        }).catch(function(e){
            mtatBulkLastError=e.message;mtatBulkJobLoading=false;document.getElementById('mtatLoadAllResults').disabled=false;
            document.getElementById('mtatLoadedNotice').style.display='block';document.getElementById('mtatLoadedNotice').textContent='Collected result loading is incomplete: '+e.message+'. All-cluster exports require every collected range to be loaded. Use Load all completed results to retry.';
            showToast(e.message,'error');return false;
        });
    }

    function mtatDownloadJobResult() {
        if(!mtatJobState)return;
        var first=mtatJobState.tasks.filter(function(t){return t.status==='completed'&&mtatSelectedTask&&mtatSelectedTask.id===mtatJobState.id&&t.index===mtatSelectedTask.index})[0]||mtatJobState.tasks.filter(function(t){return t.status==='completed'})[0];if(!first){showToast('No completed checkpoints yet.','warn');return;}
        if (obfOn()) {
            if(first.bytes>MTAT_JOB_CACHE_BYTES){showToast('This checkpoint is too large to anonymize in the browser. Open smaller saved results and export their anonymized CSVs.','warn');return;}
            mtatJobRequest('result',{id:mtatJobState.id,index:first.index}).then(function(result){obfuscateParsedResult(result);(result.hosts||[]).forEach(function(h){if(h.ResourceId)h.ResourceId=obfName('host',h.HostName)+':id'});(result.vms||[]).forEach(function(v){if(v.ResourceId)v.ResourceId=obfName('vm',v.VMName)+':id'});downloadBlobTrigger(JSON.stringify(result,null,2),'MTAT_checkpoint_hidden_names.json')}).catch(function(e){showToast(e.message,'error')});
        } else {
            window.location.href='/api/jobs/download?id='+encodeURIComponent(mtatJobState.id)+'&index='+first.index;
        }
    }
    function mtatDownloadJobLog() {
        if(!mtatActiveJobId)return;
        mtatJobRequest('log',{id:mtatActiveJobId}).then(function(data){downloadBlobTrigger(obfOn()?obfuscateLogText(data.content||'(empty log)'):(data.content||'(empty log)'),'MTAT_job_log.txt')}).catch(function(e){showToast(e.message,'error')});
    }
    window.addEventListener('load',function(){mtatSyncJobVisibility();mtatRefreshJobs()});

    function executeLegacyClusterDataCollection() {
        var btn = document.getElementById('analyzeBtn');
        btn.disabled = true; btn.innerText = "Querying Metrics...";
        var activeClusterValue = document.getElementById('clusterSelect').value;
        if (!activeClusterValue) { showToast("Please select a Target Cluster Scope.", 'warn'); btn.disabled = false; btn.innerText = "Analyze Selection Profile"; return; }

        var checkboxes = document.querySelectorAll('.range-cb:checked');
        if (checkboxes.length === 0) { showToast("Please select at least one range.", 'warn'); btn.disabled = false; btn.innerText = "Analyze Selection Profile"; return; }

        if (activeClusterValue.indexOf('RVTools|') === 0 && clusterSessionCache[activeClusterValue]) {
            var rvCache=clusterSessionCache[activeClusterValue];
            Array.prototype.forEach.call(checkboxes,function(cb){if(rvCache.ranges[cb.value])applyAnalysisResult(activeClusterValue,cb.value,rvCache.ranges[cb.value])});
            btn.disabled=false;btn.innerText='Analyze Selection Profile';return;
        }

        analysisInProgress = true;
        missedBeats = 0;
        var collectionRunId = Date.now().toString(36) + '_' + Math.random().toString(36).slice(2);
        var totalRequests = checkboxes.length;
        var completedRequests = 0;
        var rangeLabels = Array.prototype.map.call(checkboxes, function(cb) { return cb.value; });
        var collectionErrors = [];
        buildProgressChips('analyzeProgressChips', rangeLabels);

        function checkTaskCompletion() {
            completedRequests++;
            if (completedRequests === totalRequests) {
                analysisInProgress = false;
                missedBeats = 0;
                btn.disabled = false; btn.innerText = "Analyze Selection Profile";
                var finishedCache = clusterSessionCache[activeClusterValue];
                if (finishedCache && finishedCache.ranges[finishedCache.lastRange]) applyAnalysisResult(activeClusterValue, finishedCache.lastRange, finishedCache.ranges[finishedCache.lastRange]);
                if (collectionErrors.length > 0) {
                    showToast("Analysis finished, but " + collectionErrors.length + " of " + totalRequests + " range(s) failed:\n\n" + collectionErrors.join("\n"), 'error');
                }
            } else {
                startRange(completedRequests);
            }
        }

        // The engine is single-threaded and answers one /api/analyze at a time, so ranges are sent
        // one after another. Firing them all at once only queued the later ones server-side while
        // the browser's clock was already running on them.
        function startRange(x) {
            (function(selectedRange, chipIndex) {
                var payload = { cluster: activeClusterValue, range: selectedRange, collectionRunId: collectionRunId };
                var xhr = new XMLHttpRequest();
                xhr.open("POST", "/api/analyze", true);
                xhr.setRequestHeader("Content-Type", "application/json");
                // Every outcome goes through settle() exactly once. A network error, timeout or abort
                // fires readystatechange (status 0) AND its own error/timeout/abort event; counting
                // both used to start the next range twice and finish the run early.
                var settled = false;
                function settle(state, err) {
                    if (settled) return;
                    settled = true;
                    if (err) collectionErrors.push(selectedRange + ": " + err);
                    setProgressChipState('analyzeProgressChips', chipIndex, state, selectedRange);
                    checkTaskCompletion();
                }
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== 4 || xhr.status === 0) return; // status 0: onerror / ontimeout / onabort report it
                    if (xhr.status !== 200) { settle('failed', "Analysis failed on route with status code: " + xhr.status); return; }
                    var parsed;
                    try { parsed = JSON.parse(xhr.responseText); } catch(e) { settle('failed', e.message); return; }
                    if (parsed.error) { settle('failed', parsed.error); return; }
                    try {
                        if (obfOn()) obfuscateParsedResult(parsed);
                        if (!clusterSessionCache[activeClusterValue]) clusterSessionCache[activeClusterValue] = { lastRange: '', ranges: {} };
                        clusterSessionCache[activeClusterValue].ranges[selectedRange] = parsed;
                        clusterSessionCache[activeClusterValue].lastRange = selectedRange;
                        if (chipIndex === totalRequests - 1) applyAnalysisResult(activeClusterValue, selectedRange, parsed);
                    } catch(e2) { settle('failed', e2.message); return; }
                    settle('done');
                };
                xhr.onerror = function() {
                    settle('failed', "CRITICAL: Connection to the background MTAT engine was lost. If it is no longer running (it stops after 10 minutes of inactivity), please relaunch the application.");
                };
                xhr.onabort = function() { settle('failed', "the request was cancelled."); };
                // Generous per-range cap: a large cluster/historical range can legitimately run for a
                // long time (individual vCenter calls are bounded server-side by PowerCLI's
                // WebOperationTimeoutSeconds, 120s, but a range makes several), so this only exists
                // to keep the Analyze button from staying disabled forever on a true hang.
                xhr.timeout = 3600000;
                xhr.ontimeout = function() { settle('failed', "timed out after 60 minutes with no response from the engine."); };
                xhr.send(JSON.stringify(payload));
            })(checkboxes[x].value, x);
        }

        startRange(0);
    }

    function loadClusterSimulation() {
        var val = document.getElementById('simClusterSelect').value;
        var cache = clusterSessionCache[val];
        var data = cache ? cache.ranges[cache.lastRange] : null;
        // A Matrix-CSV-only import has percentages but no per-host breakdown or real host count --
        // sizing math needs both, so treat "no hosts" the same as "nothing collected yet" rather than
        // running capacity math against fabricated numbers.
        if (!cache || !data || !data.hosts || data.hosts.length === 0) {
            document.getElementById('content-simulator').style.display = 'none';
            document.getElementById('simLockoutPanel').style.display = 'block';
        } else {
            document.getElementById('content-simulator').style.display = 'block';
            document.getElementById('simLockoutPanel').style.display = 'none';

            // Keep every mirrored global in sync here, matching applyAnalysisResult() exactly --
            // this used to only update globalDram/Consumed/Active/Cpu + cachedHosts, leaving
            // cachedVms (and globalActiveAvg) pointing at whichever cluster was previously loaded.
            // Switching the Tab 3 "Target Simulation Cluster" dropdown could then silently pair one
            // cluster's hosts with a different cluster's VMs on export.
            globalDram = data.dram; globalConsumed = data.consumed; globalActive = data.active; globalCpu = data.cpu;
            globalActiveAvg = (typeof data.activeAvg === 'number') ? data.activeAvg : null;
            cachedHosts = data.hosts || []; cachedVms = data.vms || []; cachedFailedVms = data.failedVms || [];

            var simGoodHosts = mtGoodHosts(cachedHosts).length;
            document.getElementById('gfTargetHosts').value = simGoodHosts || 4;
            
            if (simGoodHosts > 0 && globalDram > 0) {
                var avgDramPerHost = Math.round(globalDram / simGoodHosts);
                var gfSelect = document.getElementById('gfNodeCapSelect');
                var options = Array.from(gfSelect.options).map(function(o) { return parseInt(o.value); }).filter(function(v) { return !isNaN(v); });
                var closest = options.reduce(function(prev, curr) { 
                    return Math.abs(curr - avgDramPerHost) < Math.abs(prev - avgDramPerHost) ? curr : prev; 
                });
                gfSelect.value = closest;
                document.getElementById('gfNodeCapCustom').style.display = 'none';
                document.getElementById('gfNodeCapCustom').value = closest;
            }

            runSimulationMath();
        }
    }

    function loadClusterFromCache(clusterKey) {
        var cache = clusterSessionCache[clusterKey];
        if (!cache || !cache.lastRange) return;

        var data = cache.ranges[cache.lastRange];
        if (!data) return;

        // Delegates to the same renderer the live-analyze and import paths use, so this view can
        // never drift out of sync with them (e.g. missing a newly-added checklist row).
        applyAnalysisResult(clusterKey, cache.lastRange, data);

        var selectEl = document.getElementById('clusterSelect');
        selectEl.value = clusterKey;
        if (selectEl.value === clusterKey) {
            // A genuine live-session cluster (key matches a real "<server>|<cluster>" <option>) --
            // querying live ranges from vCenter is meaningful here.
            loadClusterRanges();
        } else {
            // Imported clusters use an "Imported|<name>" key with no matching <option> and no live
            // vCenter session to query ranges from. Setting .value above silently no-ops in that
            // case (leaving the selector empty or stuck on whatever was previously chosen) --
            // rebuild the range checkboxes directly from what's already cached instead, so this
            // view doesn't go stale just because there's nothing live to ask.
            selectEl.value = "";
            var rDiv = document.getElementById('rangeCheckboxes'); rDiv.innerHTML = "";
            var rangeNames = Object.keys(cache.ranges);
            document.getElementById('selectAllToggle').innerText = "Select All";
            for (var j = 0; j < rangeNames.length; j++) {
                var isChecked = (rangeNames[j] === cache.lastRange) ? "checked" : "";
                var safeRange = escapeHtml(rangeNames[j]);
                rDiv.innerHTML += '<label class="checkbox-item"><input type="checkbox" class="range-cb" value="' + safeRange + '" ' + isChecked + '> ' + safeRange + '</label>';
            }
        }
    }

    // Comparison matrix sort state. null = the default grouped view (clusters in load order). Sorting
    // by cluster keeps one rowspan group per cluster; sorting by any other column sorts the individual
    // rows, so each row repeats its cluster name (a rowspan can't survive rows being reordered).
    var matrixSort = { key: null, dir: 1 };
    function sortComparisonMatrix(key) {
        if (matrixSort.key === key) matrixSort.dir *= -1;
        else { matrixSort.key = key; matrixSort.dir = (key === 'cluster' || key === 'range') ? 1 : -1; }
        rebuildGroupedMatrix();
    }
    function rebuildGroupedMatrix() {
        var compBody = document.getElementById('comparisonMatrixBody');
        var matrixRowsHtml = [];
        var rows = [];
        Object.keys(clusterSessionCache).forEach(function(clusterKey, order) {
            var rangesObj = clusterSessionCache[clusterKey].ranges;
            Object.keys(rangesObj).forEach(function(currentRange) {
                var data = rangesObj[currentRange];
                rows.push({
                    key: clusterKey, label: advClusterLabel(clusterKey), order: order, range: currentRange, data: data,
                    cpu: (typeof data.cpu === 'number') ? data.cpu : null,
                    peak: data.dram > 0 ? (data.active / data.dram) * 100 : 0,
                    avg: (typeof data.activeAvg === 'number' && data.dram > 0) ? (data.activeAvg / data.dram) * 100 : null,
                    cons: data.dram > 0 ? (data.consumed / data.dram) * 100 : 0
                });
            });
        });
        var k = matrixSort.key, dir = matrixSort.dir;
        var grouped = (k === null || k === 'cluster');
        if (k === 'cluster') {
            rows.sort(function(a, b) { return (a.label.localeCompare(b.label, undefined, { numeric: true }) * dir) || (a.order - b.order); });
        } else if (k !== null) {
            rows.sort(function(a, b) {
                var av = a[k], bv = b[k];
                if (av === null && bv === null) return 0;
                if (av === null) return 1;            // N/A always sorts last
                if (bv === null) return -1;
                if (typeof av === 'string') return av.localeCompare(bv, undefined, { numeric: true }) * dir;
                return (av - bv) * dir;
            });
        }
        // The cluster key is passed via a data-attribute, read back with getAttribute(), rather than
        // interpolated into the onclick JS source string -- entity-encoding a quote does NOT protect an
        // inline event handler, since the browser HTML-decodes attribute values before parsing them as JS.
        function clusterCell(r, span) {
            return '<td' + (span > 1 ? ' rowspan="' + span + '"' : '') + '><a href="#" class="cluster-link" data-cluster-key="' + escapeHtml(r.key) + '" onclick="loadClusterFromCache(this.getAttribute(\'data-cluster-key\')); return false;">' + escapeHtml(r.label) + '</a></td>';
        }
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i], rowHtml = "";
            if (grouped) {
                if (i === 0 || rows[i - 1].key !== r.key) {
                    var span = 1; while (i + span < rows.length && rows[i + span].key === r.key) span++;
                    rowHtml += clusterCell(r, span);
                }
            } else {
                rowHtml += clusterCell(r, 1);
            }
            var actPct = r.peak.toFixed(1), consPct = r.cons.toFixed(1), actAvgPct = r.avg === null ? null : r.avg.toFixed(1);
            rowHtml += "<td>" + escapeHtml(r.range) + "</td><td>" + (r.cpu !== null ? pctBarCellHtml(r.cpu, r.cpu) : "N/A") + "</td><td>" + pctBarCellHtml(actPct, actPct) + "</td><td>" + (actAvgPct === null ? "N/A" : pctBarCellHtml(actAvgPct, actAvgPct)) + "</td><td>" + pctBarCellHtml(consPct, consPct) + "</td>";
            matrixRowsHtml.push("<tr>" + rowHtml + "</tr>");
        }
        compBody.innerHTML = matrixRowsHtml.join("");
        document.querySelectorAll('#comparisonMatrixHead th').forEach(function(h) {
            var arrow = h.querySelector('.sort-arrow');
            if (arrow) arrow.textContent = (h.getAttribute('data-mkey') === k) ? (dir === 1 ? ' ^' : ' v') : '';
        });
        var list=document.getElementById('comparisonListDetails'),count=document.getElementById('comparisonListCount');
        if(count)count.textContent=fmtInt(Object.keys(clusterSessionCache).length)+' clusters / '+fmtInt(rows.length)+' range rows (show / hide)';
        if(list && rows.length>25 && !list.dataset.largeCollapsed){list.open=false;list.dataset.largeCollapsed='true'}
        mtatInitSortHints();
        updateExportControls();
    }

    // Exports only add something when the session holds data that isn't already an MTAT export:
    // a live analysis, or an RVTools / VCF Operations import (converting it to MTAT's format, or
    // re-sharing it with names obfuscated). A session built only from re-imported MTAT exports would
    // just export the same files again, so the export controls are hidden in that case.
    function updateExportControls() {
        var repCard = document.getElementById('repCardTop'), hasData = Object.keys(clusterSessionCache).length > 0;
        if (repCard) repCard.style.display = hasData ? 'flex' : 'none';
        ['repToolbarBase', 'repToolbarAdv', 'repToolbarSim'].forEach(function(id) { var t = document.getElementById(id); if (t) t.style.display = hasData ? 'flex' : 'none'; });
        var sources = {}, total = 0;
        Object.keys(clusterSessionCache).forEach(function(k) {
            var r = clusterSessionCache[k].ranges || {};
            Object.keys(r).forEach(function(l) { total++; sources[r[l].source || 'live'] = true; });
        });
        var redundant = total > 0 && Object.keys(sources).every(function(src) { return src === 'mtat' || src === 'history'; });
        document.querySelectorAll('button[onclick^="exportSectionToCSV"]').forEach(function(b) { b.style.display = redundant ? 'none' : ''; });
        var allBtn = document.getElementById('btnExportAll');
        if (redundant) allBtn.style.display = 'none'; else if (total > 0) allBtn.style.display = 'block';
        document.getElementById('exportRedundantNote').style.display = redundant ? 'block' : 'none';
        updateObfSwitchVisibility();
    }

    // ---- Shared sizing helpers (Baseline checklist, Sizing tab and customer report use the same ones) ----
    // A number from an input box. The default is used only when the box is empty, not a number or
    // negative, so a real 0 (for example a price of $0 for drives the customer already owns) is kept.
    function mtNum(id, def) {
        var el = document.getElementById(id), v = el ? parseFloat(el.value) : NaN;
        return (isNaN(v) || v < 0) ? def : v;
    }
    // Hosts that count toward sizing. A host whose collection failed (Tiering "ERROR", 0 GB) has no
    // data, so it is left out instead of diluting per-host averages and host counts.
    function mtGoodHosts(hosts) { return (hosts || []).filter(function(h) { return h.Tiering !== 'ERROR'; }); }
    // Per-host DRAM for the per-host NVMe sizing (an even split if a source has no per-host figures).
    function mtHostDrams(hosts, dram) {
        var good = mtGoodHosts(hosts), out = good.map(function(h) { return Number(h.Physical_RAM) || 0; }).filter(function(d) { return d > 0; });
        if (!out.length && dram > 0) { var n = Math.max(1, good.length); for (var i = 0; i < n; i++) out.push(Math.round(dram / n)); }
        return out;
    }
    // True when vCenter returned no samples for this counter on this host/VM row (Missing_Metrics is
    // written by live analysis; older exports and other sources never have it, so never count as missing).
    function mtHas(row, metric) { return !!(row && row.Missing_Metrics) && (', ' + row.Missing_Metrics + ',').indexOf(', ' + metric + ',') >= 0; }
    function mtMissing(rows, metric) { return (rows || []).filter(function(r) { return mtHas(r, metric); }); }
    function mtTierUnknown(hosts) { return (hosts || []).filter(function(h) { return h.Tiering === 'Unknown'; }); }
    // VMs whose memory has to stay in DRAM (DRAM_Only = "Yes (...)": passthrough / vGPU / SR-IOV /
    // RDMA, pinned memory, Latency Sensitivity High, Fault Tolerance, or tiering disabled on the VM).
    function mtDramOnly(vms) {
        var o = { n: 0, gb: 0, active: 0 };
        (vms || []).forEach(function(v) {
            if (String(v.DRAM_Only || '').indexOf('Yes') !== 0) return;
            var gb = Number(v.Provisioned_GB) || 0;
            o.n++; o.gb += gb; o.active += Math.min(Number(v.Active_GB) || 0, gb);
        });
        return o;
    }
    // Active Memory as a % of the DRAM that tiering can use. DRAM-only VMs keep all of their memory in
    // DRAM, so it is taken out of the DRAM. Their Active Memory is NOT taken out of the Active: a VM's
    // peak and its host's peak can come at different times, so subtracting one from the other could
    // understate the rest; keeping it in is the safe side. With no DRAM-only VMs this is exactly
    // active / DRAM, the figure used before.
    function mtActivePct(dram, active, dOnly) {
        if (!dOnly || !(dOnly.gb > 0)) return dram > 0 ? active / dram * 100 : 0;
        var tierDram = dram - dOnly.gb;
        return tierDram > 0 ? active / tierDram * 100 : Infinity;
    }
    function mtPctText(p) { return isFinite(p) ? p.toFixed(1) : '100.0'; }
    // The 50% Active Memory test, on the value as displayed (one decimal), so the Baseline checklist,
    // Advanced Analytics and the customer report always agree at the boundary (50.04% passes in all).
    function mtActiveOk(p) { return parseFloat(mtPctText(p)) <= 50; }
    // For notes and labels: "56.1%", "over 999%", or "over 100%" when no DRAM is left for tiering at all.
    function mtPctLabel(p) { return !isFinite(p) ? "over 100%" : (p > 999 ? "over 999%" : p.toFixed(1) + "%"); }
    // The largest VM, and the largest DRAM-only VM: a new host has to hold each of them on its own.
    function mtLargestVms(vms) {
        var o = { vm: 0, vmName: '', dramOnly: 0, dramOnlyName: '' };
        (vms || []).forEach(function(v) {
            var gb = Number(v.Provisioned_GB) || 0;
            if (gb > o.vm) { o.vm = gb; o.vmName = v.VMName; }
            if (String(v.DRAM_Only || '').indexOf('Yes') === 0 && gb > o.dramOnly) { o.dramOnly = gb; o.dramOnlyName = v.VMName; }
        });
        return o;
    }
    function mtFailedHosts(hosts) { return (hosts || []).filter(function(h) { return h.Tiering === 'ERROR'; }); }
    // Sizes (GB) of the DRAM-only VMs, and how many nodes of a given size they need when each one has to
    // sit whole on one node (first-fit decreasing; Infinity when one is bigger than a node).
    function mtDramOnlySizes(vms) {
        return (vms || []).filter(function(v) { return String(v.DRAM_Only || '').indexOf('Yes') === 0; })
            .map(function(v) { return Number(v.Provisioned_GB) || 0; }).filter(function(x) { return x > 0; });
    }
    function mtPackCount(sizes, bin) {
        if (!sizes || !sizes.length) return 0;
        var s = sizes.slice().sort(function(a, b) { return b - a; }), free = [];
        for (var i = 0; i < s.length; i++) {
            if (s[i] > bin) return Infinity;
            var j = 0; while (j < free.length && free[j] < s[i]) j++;
            if (j === free.length) free.push(bin - s[i]); else free[j] -= s[i];
        }
        return free.length;
    }
    // What a cluster's data is missing. activeIncomplete: the Active Memory check (so qualification and
    // savings) cannot be trusted. refreshIncomplete: a refresh cannot be sized either (it also needs CPU
    // and Consumed Memory). A VM that failed collection may have been DRAM-only, and in a Real-Time
    // snapshot its Active Memory is missing from its host's total, so it counts as a gap too.
    function mtDataGaps(hosts, failedVmCount) {
        var g = { active: mtAssessmentMissing(hosts).length, cpu: mtMissing(hosts, 'CPU').length, consumed: mtMissing(hosts, 'Consumed').length,
                  failedHosts: mtFailedHosts(hosts).length, failedVms: failedVmCount || 0 };
        g.activeIncomplete = !!(g.active || g.failedHosts || g.failedVms);
        g.refreshIncomplete = g.activeIncomplete || !!(g.cpu || g.consumed);
        return g;
    }
    // NVMe already installed on each host, in the same order as mtHostDrams.
    function mtHostExisting(hosts) {
        return mtGoodHosts(hosts).filter(function(h) { return (Number(h.Physical_RAM) || 0) > 0; }).map(function(h) { return mtExistingNvme([h]); });
    }
    // Active-equivalent load for refresh sizing: tiered memory needs DRAM for twice its Active Memory
    // (the 50% guideline) and DRAM-only VMs need all of theirs, so hosts x DRAM >= 2 x load. Equals
    // plain Active Memory when there are no DRAM-only VMs.
    function mtActiveLoad(active, dOnly) { return (dOnly && dOnly.gb > 0) ? active + dOnly.gb / 2 : active; }
    // NVMe already installed on tiered hosts: the NVMe tier vCenter reports when known, otherwise
    // DRAM x the configured tier ratio.
    function mtExistingNvme(hosts) {
        var s = 0;
        (hosts || []).forEach(function(h) {
            if (h.Tiering !== 'Enabled') return;
            if (typeof h.NVMe_GB === 'number' && h.NVMe_GB > 0) s += h.NVMe_GB;
            else s += (Number(h.Physical_RAM) || 0) * ((typeof h.TierRatioPct === 'number' ? h.TierRatioPct : 100) / 100);
        });
        return mtRoundGb(s);
    }
    // Brownfield NVMe, sized host by host: the ratio and both limits (4,398.047 GB NVMe per host, the vSphere
    // partition maximum, and at most 1:4) apply to each host on its own, so a cluster that mixes host
    // sizes is not sized as if every host were average. mode 'ratio' / 'custom': value = NVMe:DRAM
    // multiplier; mode 'drive': value = drive GB per host. Same rules as the Sizing tab always used.
    // existing (optional): NVMe already installed per host, same order as hostDrams. The NVMe to add is
    // worked out host by host, so one host's surplus never offsets another host's shortfall.
    function mtBrownfieldNvme(hostDrams, mode, value, existing) {
        var o = { usable: 0, physical: 0, dram: 0, added: 0, addedPhysical: 0, minPerHost: Infinity, maxPerHost: 0, partitionExceeded: false, ratioExceeded: false, hosts: hostDrams.length };
        hostDrams.forEach(function(d, i) {
            var nv = (mode === 'drive') ? value : mtRoundGb(d * value);
            if (nv > MT_NVME_LIMIT_GB) { nv = MT_NVME_LIMIT_GB; o.partitionExceeded = true; }
            if (mode !== 'ratio' && nv > d * 4) { nv = mtRoundGb(d * 4); o.ratioExceeded = true; }
            var phys = (mode === 'drive') ? value : nv, ex = existing ? (Number(existing[i]) || 0) : 0;
            o.added += Math.max(0, nv - ex); o.addedPhysical += Math.max(0, phys - ex);
            o.usable += nv; o.physical += phys; o.dram += d;
            if (nv > o.maxPerHost) o.maxPerHost = nv;
            if (nv < o.minPerHost) o.minPerHost = nv;
        });
        if (o.minPerHost === Infinity) o.minPerHost = 0;
        return o;
    }
    function mtRatioText(x) { return Math.abs(x - Math.round(x)) < 1e-9 ? String(Math.round(x)) : x.toFixed(2); }
    // Notes for the Sizing tab's info card about what the figures can and cannot account for.
    function mtSizingNotes(hosts, vms, dram, failedVmCount) {
        var notes = [], dOnly = mtDramOnly(vms), missAct = mtMissing(hosts, 'Active'), unk = mtTierUnknown(hosts);
        if (mtAssessmentMissing(hosts).length) notes.push('[ ! ] Qualification or sizing is incomplete: required memory, eligibility, tier configuration or historical coverage could not be verified. See Tab 2 notes.');
        if (dOnly.n) notes.push("[ i ] INFO: " + dOnly.n + " VM(s) must keep their memory in DRAM (" + Math.round(dOnly.gb) + " GB: passthrough or vGPU devices, pinned memory, Latency Sensitivity High, Fault Tolerance, or tiering disabled). That memory is never moved to NVMe, so Active Memory is judged against the " + Math.max(0, Math.round(dram - dOnly.gb)) + " GB of DRAM left for tiering.");
        if (missAct.length) notes.push("[ ! ] " + missAct.length + " host(s) returned no Active Memory samples for this range, so the Active Memory figures here can read too low. See the notes on the Baseline Assessment tab.");
        var failedN = mtFailedHosts(hosts).length;
        if (failedN) notes.push("[ ! ] " + failedN + " host(s) failed data collection and are not in these figures. Collect them again before relying on the results.");
        if (failedVmCount) notes.push("[ ! ] " + failedVmCount + " VM(s) failed data collection, so a VM that has to stay in DRAM could be missing from these figures. Collect them again before relying on the results.");
        var missCC = (hosts || []).filter(function(h) { return mtHas(h, 'CPU') || mtHas(h, 'Consumed'); }).length;
        if (missCC) notes.push("[ ! ] " + missCC + " host(s) returned no CPU or Consumed Memory samples, so the refresh host count can be too low.");
        if (unk.length) notes.push((hosts || []).some(function(h) { return mtHas(h, 'TierConfig'); }) ? "[ ! ] Tier configuration is unverified. Qualification and savings are withheld until the configuration is established." : "[ i ] INFO: Memory Tiering status is not known for " + unk.length + " host(s). Confirm the configuration before relying on sizing or savings.");
        return notes;
    }

    function runSimulationMath() {
        var strategy = document.getElementById('simStrategy') ? document.getElementById('simStrategy').value : 'brownfield';
        var hostCount = mtGoodHosts(cachedHosts).length || 1;
        var avgDramPerHost = Math.round(globalDram / hostCount);
        var hostDrams = mtHostDrams(cachedHosts, globalDram);
        // Active Memory against the DRAM tiering can use (the same as Active / DRAM unless some VMs are DRAM-only).
        var simDOnly = mtDramOnly(cachedVms);
        var activePct = globalDram > 0 ? mtPctText(mtActivePct(globalDram, globalActive, simDOnly)) : 0;
        var simNotes = mtSizingNotes(cachedHosts, cachedVms, globalDram, cachedFailedVms.length);
        // Gaps in the data: results that depend on them are shown as "Check data" rather than as figures.
        var simGaps = mtDataGaps(cachedHosts, cachedFailedVms.length);

        var clusterIsAlreadyTiered = cachedHosts.some(function(h) { return h.Tiering === "Enabled"; });
        var activeTierAlertDiv = document.getElementById('simTieringActiveAlert');
        var matchingConfig = false;
        var existingRatioPct = 100, tierSummary = "";
        
        if (clusterIsAlreadyTiered) {
            var tieredHosts = cachedHosts.filter(function(h) { return h.Tiering === "Enabled"; });
            // Use a type check, not `||` -- a genuine ratio of 0 is falsy in JS and would otherwise
            // be silently replaced by the 100 default, same class of bug as the server-side
            // $hostTierRatioReported fix for TierRatioPct.
            existingRatioPct = (typeof tieredHosts[0].TierRatioPct === 'number') ? tieredHosts[0].TierRatioPct : 100;
            // Describe the whole cluster, not its first tiered host: ratios can differ, and some hosts may not be tiered.
            var ratioList = [];
            tieredHosts.forEach(function(h) { var r0 = (typeof h.TierRatioPct === 'number') ? h.TierRatioPct : 100; if (ratioList.indexOf(r0) < 0) ratioList.push(r0); });
            ratioList.sort(function(a, b) { return a - b; });
            var tierGoodN = mtGoodHosts(cachedHosts).length;
            tierSummary = (tieredHosts.length < tierGoodN ? tieredHosts.length + " of " + tierGoodN + " hosts, " : "") +
                (ratioList.length > 1 ? "ratios from " + ratioList[0] + "% to " + ratioList[ratioList.length - 1] + "%" : "currently configured at " + existingRatioPct + "% ratio");
            activeTierAlertDiv.style.display = 'block';
        } else {
            activeTierAlertDiv.style.display = 'none';
        }

        // Reset here (not just inside the greenfield/capacity branch below) so switching strategy
        // or sizing mode always clears a stale warning/preview from a previous selection.
        var gfRatioPreviewDiv = document.getElementById('gfRatioPreview');
        var gfSmallDramWarnDiv = document.getElementById('gfSmallDramWarn');
        if (gfRatioPreviewDiv) { gfRatioPreviewDiv.innerText = ''; }
        if (gfSmallDramWarnDiv) { gfSmallDramWarnDiv.style.display = 'none'; }

        var ceilingWarningCard = document.getElementById('simCeilingWarningCard');
        ceilingWarningCard.style.display = 'none';

        if (strategy === 'greenfield') {
            // ===============================================
            // NEW GREENFIELD CONSOLIDATION MATH LOGIC
            // ===============================================
            var gfMode = document.getElementById('gfInputMode').value;
            var gfRatioVal = parseFloat(document.getElementById('gfRatio').value) || 1;
            // Same 1:1-is-recommended advisory as Brownfield -- see the comment beside its
            // definition there. The Greenfield ratio dropdown is always an exact integer, so no
            // floating-point tolerance is needed here.
            var ratioAdvisoryMsg = (gfRatioVal !== 1)
                ? "The recommended ratio for Memory Tiering is 1:1 (Default). Ratios above 1:1 require additional workload assessment, since Active Memory needs to be proportionally lower to reliably fit within the DRAM tier."
                : "";

            var haNodes = parseInt(document.getElementById('gfHa').value);
            if (isNaN(haNodes)) haNodes = 1;
            
            var serverCost = mtNum('gfServerCost', 15000);
            var priceDramGB = mtNum('costDram', 100);
            var priceNvmeGB = mtNum('costNvme', 0.25);
            var mirroringActive = document.getElementById('chkMirroring').checked;

            var standardReqHosts = 0, tieredReqHosts = 0;
            var totalNodeMem = 0, gfDram = 0, gfNvme = 0;
            var stdMemProfile = 0;
            var limitingFactorMsg = "";
            var partitionExceeded = false;
            // Capacity mode and Target-Usable-Hosts mode hit the same 4,398.047 GB NVMe partition cap in
            // genuinely different ways (capacity mode reduces deliverable capacity; host-count mode
            // shifts the shortfall into DRAM instead) -- each branch below sets its own accurate
            // explanation rather than sharing one hardcoded message that's only true for one of them.
            var partitionExceededMsg = "";
            var currentTotalCpu = globalCpu * hostCount;
            // DRAM-only VMs need all of their memory in DRAM, tiered memory needs DRAM for twice its
            // Active Memory: gfActiveLoad folds both into one figure (plain Active Memory when there are
            // no DRAM-only VMs), so every "keep Active within 50% of DRAM" rule below covers both.
            var gfDOnly = simDOnly;
            var gfActiveLoad = mtActiveLoad(globalActive, gfDOnly);
            // Capacity in aggregate is not enough: the largest VM has to fit on one node (a DRAM-only VM in
            // the node's DRAM, any VM in its total memory).
            var gfBig = mtLargestVms(cachedVms), gfFitProblem = "", gfSizes = mtDramOnlySizes(cachedVms);

            if (gfMode === 'capacity') {
                var selVal = document.getElementById('gfNodeCapSelect').value;
                var gfNodeCap = parseFloat(selVal === 'custom' ? document.getElementById('gfNodeCapCustom').value : selVal);
                if (isNaN(gfNodeCap) || gfNodeCap < 1) gfNodeCap = MT_DEFAULT_NODE_GB;
                var cpuMult = parseFloat(document.getElementById('gfCpuMult').value) || 1.0;

                // Option A (Standard Refresh) is 100% DRAM -- it has no NVMe tier, so it must size
                // against the FULL capacity the user actually requested, never the NVMe-partition-
                // capped figure below. stdMemProfile is fixed to the requested capacity for exactly
                // this reason; only Tiered's own totalNodeMem/gfDram/gfNvme are affected by the cap.
                var requestedNodeCap = gfNodeCap;
                stdMemProfile = requestedNodeCap;

                gfDram = (requestedNodeCap / (1 + gfRatioVal));
                if (gfDram < 1) gfDram = 1; // a tiny custom node size must not leave 0 GB DRAM (division by zero below)
                gfNvme = requestedNodeCap - gfDram;
                if (gfNvme > MT_NVME_LIMIT_GB) {
                    gfNvme = MT_NVME_LIMIT_GB;
                    partitionExceeded = true;
                    totalNodeMem = gfDram + gfNvme;
                } else {
                    totalNodeMem = requestedNodeCap;
                }

                // Live feedback on the Ratio dropdown itself: the ratio is a % of node capacity, but
                // the Active Memory safety floor below is an absolute GB amount -- the same ratio is
                // harmless on a large node and can shrink DRAM to a sliver on a small one. Surfacing
                // the resulting GB split here, before the host-count math runs, catches that early.
                if (gfRatioPreviewDiv) { gfRatioPreviewDiv.innerText = "-> " + mtGbText(gfDram) + " GB DRAM + " + mtGbText(gfNvme) + " GB NVMe per host"; }
                // 32: not a hard platform limit like the 4,398.047 GB partition cap elsewhere -- just a
                // practical "this is probably too small to be a useful fast tier" heuristic, since a
                // DRAM tier this size will usually fail the Active Memory safety check below and
                // balloon the host count long before it fails for any other reason.
                if (gfSmallDramWarnDiv && gfDram < 32) {
                    gfSmallDramWarnDiv.innerHTML = "[ ! ] This ratio leaves only <strong>" + mtGbText(gfDram) + " GB</strong> of DRAM per host at " + mtGbText(requestedNodeCap) + " GB node capacity -- likely too small to hold your Active Memory safely, which is what drives the host count up below. Try a lower NVMe ratio or a larger Target Node Capacity instead.";
                    gfSmallDramWarnDiv.style.display = 'block';
                }

                var reqConsumedStd = Math.ceil(globalConsumed / stdMemProfile);
                var reqConsumedTiered = Math.ceil(globalConsumed / totalNodeMem);
                // 80: CPU safety ceiling -- host count is sized so no host runs above 80% average
                // CPU utilization, leaving headroom for HA failover absorption and burst load rather
                // than sizing to the theoretical 100% ceiling.
                var reqCpu = Math.ceil(currentTotalCpu / (80 * cpuMult));

                // DRAM-only VMs have to sit whole on hosts other than the HA spares (first-fit placement), so
                // they still fit after a host failure.
                var stdPackN = mtPackCount(gfSizes, stdMemProfile), tierPackN = mtPackCount(gfSizes, gfDram);
                var standardBase = Math.max(reqConsumedStd, reqCpu, isFinite(stdPackN) ? stdPackN : 0);
                if (standardBase < 1) standardBase = 1;
                standardReqHosts = standardBase + haNodes;

                // 0.50: Active Memory safety limit -- the same "keep Active Memory <= 50% of Tier-0
                // DRAM" target shown on the Baseline Assessment checklist. Host count here is
                // whatever's needed so the cluster's Active Memory never exceeds half of the
                // deployed DRAM capacity, leaving headroom since Memory Tiering performance degrades
                // as the hot/active working set approaches the full size of the fast tier.
                var reqActive = Math.ceil(gfActiveLoad / (gfDram * 0.50));
                var tieredBase = Math.max(reqConsumedTiered, reqCpu, reqActive, isFinite(tierPackN) ? tierPackN : 0);
                if (tieredBase < 1) tieredBase = 1;
                tieredReqHosts = tieredBase + haNodes;

                if (isFinite(tierPackN) && tierPackN === tieredBase && tierPackN > Math.max(reqConsumedTiered, reqCpu, reqActive)) {
                    limitingFactorMsg = "You need " + tieredReqHosts + " total hosts because the " + gfSizes.length + " DRAM-only VM(s) must each sit whole in one host's " + mtGbText(gfDram) + " GB DRAM tier, and they need " + tierPackN + " hosts between them" + (haNodes > 0 ? ", with the HA host(s) on top so they still fit after a host failure" : "") + ". A larger Target Node Capacity or a DRAM-heavier ratio fits them on fewer hosts.";
                } else if (tieredBase === reqActive && reqActive >= Math.max(reqConsumedTiered, reqCpu)) {
                    limitingFactorMsg = "This extra host is intentional, not a miscalculation: Active Memory (" + globalActive + " GB) must stay within 50% of each host's DRAM tier" + (gfDOnly.n ? ", after the " + Math.round(gfDOnly.gb) + " GB that DRAM-only VMs keep in DRAM," : "") + " to protect performance, so " + tieredReqHosts + " hosts are required here. A larger Target Node Capacity (or a DRAM-heavier ratio) closes this cost gap while keeping that same protection.";
                } else if (tieredBase === reqCpu && reqCpu >= Math.max(reqConsumedTiered, reqActive)) {
                    limitingFactorMsg = "You need " + tieredReqHosts + " total hosts because your current CPU workload would overload fewer servers (capped at 80% usage per host). Increase your 'New Node CPU Capacity' if buying faster servers.";
                } else if (tieredBase === reqConsumedTiered) {
                    limitingFactorMsg = "You need " + tieredReqHosts + " total hosts simply because your VMs are currently consuming " + globalConsumed + " GB of memory. To consolidate into fewer hosts, select a larger Target Node Capacity.";
                }

                if (partitionExceeded) {
                    partitionExceededMsg = "NVMe tier allocations are automatically capped at 4,398.047 GB per host to align with vSphere maximum kernel limits. Your Tiered node's deliverable capacity was reduced to " + mtGbText(totalNodeMem) + " GB instead of the requested " + mtGbText(requestedNodeCap) + " GB. Option A (Standard Refresh) is unaffected, since it has no NVMe tier.";
                }

                var gfFit = [];
                if (gfBig.dramOnly > gfDram) gfFit.push("the largest DRAM-only VM (" + gfBig.dramOnlyName + ", " + gfBig.dramOnly + " GB) needs more DRAM than the " + mtGbText(gfDram) + " GB a tiered node has");
                if (gfBig.vm > totalNodeMem) gfFit.push("the largest VM (" + gfBig.vmName + ", " + gfBig.vm + " GB) is bigger than a tiered node's " + mtGbText(totalNodeMem) + " GB");
                if (gfBig.vm > stdMemProfile) gfFit.push("the largest VM (" + gfBig.vmName + ", " + gfBig.vm + " GB) is bigger than a " + mtGbText(stdMemProfile) + " GB DRAM-only node");
                if (gfFit.length) gfFitProblem = "This node size cannot run every VM: " + gfFit.join("; ") + ". Choose a larger Target Node Capacity" + (gfBig.dramOnly > gfDram ? " or a DRAM-heavier ratio" : "") + ".";
            } else {
                var targetHosts = parseInt(document.getElementById('gfTargetHosts').value);
                if (isNaN(targetHosts) || targetHosts < 1) targetHosts = hostCount;
                
                var usableHosts = targetHosts;
                if (usableHosts < 1) {
                    usableHosts = 1;
                    limitingFactorMsg = "[!] Warning: Sizing reflects a single usable host.<br><br>";
                }

                var reqConsumed = globalConsumed / usableHosts;
                // 80: same CPU safety ceiling as the capacity-mode branch above -- here solved for
                // the CPU speed multiplier needed (given a fixed host count) instead of for host
                // count (given a fixed speed), but it's the same "don't run hotter than 80%" target.
                var reqCpuMult = (currentTotalCpu / usableHosts) / 80;
                var cpuString = reqCpuMult > 1.0 ? reqCpuMult.toFixed(2) + "x" : "1.0x";

                standardReqHosts = usableHosts + haNodes;
                stdMemProfile = mtDramCeil(reqConsumed);
                if(stdMemProfile < MT_MIN_DRAM_GB) stdMemProfile = MT_MIN_DRAM_GB;
                if (stdMemProfile < gfBig.vm) stdMemProfile = mtDramCeil(gfBig.vm);
                for (var spg = 0; spg < 4096 && mtPackCount(gfSizes, stdMemProfile) > usableHosts; spg++) stdMemProfile += MT_DRAM_STEP_GB;

                // 0.50: same Active Memory safety limit as the capacity-mode branch -- here solved
                // for the minimum DRAM needed (given a fixed host count) so Active Memory never
                // exceeds half of it, instead of for host count (given a fixed DRAM size).
                var reqActive = gfActiveLoad / usableHosts;
                var minDramForActive = reqActive / 0.50;
                var dramForCons = reqConsumed / (1 + gfRatioVal);
                
                gfDram = Math.max(minDramForActive, dramForCons, gfBig.dramOnly, (gfBig.vm / (1 + gfRatioVal)));
                gfDram = mtDramCeil(gfDram); 
                
                // DRAM-only VMs must also fit whole on the usable hosts (not counting HA spares).
                for (var tpg = 0; tpg < 4096 && mtPackCount(gfSizes, gfDram) > usableHosts; tpg++) gfDram += MT_DRAM_STEP_GB;
                gfNvme = gfDram * gfRatioVal;
                if (gfNvme > MT_NVME_LIMIT_GB) {
                    gfNvme = MT_NVME_LIMIT_GB;
                    partitionExceeded = true;
                    var missingCap = reqConsumed - (gfDram + gfNvme);
                    if (missingCap > 0) {
                        gfDram += mtDramCeil(missingCap);
                    }
                    partitionExceededMsg = "NVMe tier allocations are automatically capped at 4,398.047 GB per host to align with vSphere maximum kernel limits. Remaining required capacity was shifted to DRAM.";
                }

                tieredReqHosts = usableHosts + haNodes;
                totalNodeMem = gfDram + gfNvme;
                if (totalNodeMem < gfBig.vm) { gfDram += mtDramCeil(gfBig.vm - totalNodeMem); totalNodeMem = gfDram + gfNvme; }

                if (limitingFactorMsg === "") {
                     var haString = haNodes > 0 ? " (plus " + haNodes + " HA node" + (haNodes > 1 ? "s" : "") + ")" : "";
                     limitingFactorMsg = "To safely run this workload on exactly " + usableHosts + " usable host(s)" + haString + ", each new server requires at least <strong>" + mtGbText(stdMemProfile) + " GB</strong> of total memory capacity, and CPUs roughly <strong>" + cpuString + " faster</strong> than your existing hosts.";
                     // Compare the PRE-rounding candidates directly rather than checking whether the
                     // POST-64GB-rounding gfDram happens to equal minDramForActive -- rounding almost
                     // always changes gfDram away from that exact raw value even when Active Memory
                     // was clearly the binding constraint, which was silently suppressing this note.
                     if (minDramForActive > dramForCons) {
                         limitingFactorMsg += " Note: This DRAM sizing is set by the 50% Active Memory safety limit -- a deliberate performance safeguard, not a rounding artifact.";
                     }
                }
            }

            // FINANCIAL MATH
            var nodeBaseCost = serverCost;
            var totalStandardCost = standardReqHosts * (nodeBaseCost + (stdMemProfile * priceDramGB));
            var totalTieredCost = tieredReqHosts * (nodeBaseCost + (gfDram * priceDramGB) + (gfNvme * priceNvmeGB * (mirroringActive ? 2 : 1)));

            var netSavings = totalStandardCost - totalTieredCost;
            var totalTieredMemDeployed = tieredReqHosts * (gfDram + gfNvme);
            var totalUsed = totalTieredMemDeployed > 0 ? ((globalConsumed / totalTieredMemDeployed) * 100).toFixed(2) : 0;
            var projectedActivePct = (tieredReqHosts * gfDram) > 0 ? mtPctText(mtActivePct(tieredReqHosts * gfDram, globalActive, gfDOnly)) : 0;

            if (clusterIsAlreadyTiered) {
                activeTierAlertDiv.innerText = "[ i ] Environment Context: Memory Tiering is already active on this cluster (" + tierSummary + "). Formulas below outline incremental capacity shifts vs the active baseline.";
            }

            document.getElementById('gfStdProfile').innerText = mtGbText(stdMemProfile) + " GB / Host";
            document.getElementById('gfStdHosts').innerText = standardReqHosts;
            document.getElementById('gfStdConsol').innerText = hostCount + " \u2794 " + standardReqHosts;
            document.getElementById('gfStdCost').innerText = "$" + totalStandardCost.toLocaleString('en-US', {minimumFractionDigits: 0, maximumFractionDigits: 0});

            document.getElementById('gfTierProfile').innerText = mtGbText(gfDram) + " GB + " + mtGbText(gfNvme) + " GB NVMe";
            document.getElementById('gfTierHosts').innerText = tieredReqHosts;
            document.getElementById('gfTierConsol').innerText = hostCount + " \u2794 " + tieredReqHosts;
            document.getElementById('gfTierCost').innerText = "$" + totalTieredCost.toLocaleString('en-US', {minimumFractionDigits: 0, maximumFractionDigits: 0});

            document.getElementById('gfTotalSavings').innerText = "$" + netSavings.toLocaleString('en-US', {minimumFractionDigits: 0, maximumFractionDigits: 0});
            if (netSavings < 0) {
                document.getElementById('gfTotalSavings').style.color = "var(--text-danger-strong)";
                document.getElementById('gfSavingsDetail').innerText = "More expensive here -- a safety-margin host protects performance at this configuration. See Sizing Rationale below.";
            } else {
                document.getElementById('gfTotalSavings').style.color = "var(--text-success)";
                document.getElementById('gfSavingsDetail').innerText = "Includes Server Hardware and Memory Media";
            }
            if (gfFitProblem) {
                document.getElementById('gfTotalSavings').innerText = "Not feasible";
                document.getElementById('gfTotalSavings').style.color = "var(--text-danger-strong)";
                document.getElementById('gfSavingsDetail').innerText = gfFitProblem;
            }
            if (simGaps.refreshIncomplete) {
                document.getElementById('gfTotalSavings').innerText = "Check data";
                document.getElementById('gfTotalSavings').style.color = "var(--text-warning-soft)";
                document.getElementById('gfSavingsDetail').innerText = "Some hosts or VMs are missing Active Memory, CPU or Consumed Memory data, so a refresh cannot be sized reliably. See the notes below.";
            }

            document.getElementById('gfCapacityVal').innerText = totalUsed + "%";
            document.getElementById('gfActiveVal').innerText = projectedActivePct + "%";
            setPctBar('gfCapacityBar', totalUsed, {});
            setPctBar('gfActiveBar', projectedActivePct, { pass: projectedActivePct <= 50 });

            var msg = "";
            if (ratioAdvisoryMsg) {
                ceilingWarningCard.style.display = 'block';
                ceilingWarningCard.className = 'info-panel-box';
                msg += "[ i ] INFO: " + ratioAdvisoryMsg;
            }
            if (limitingFactorMsg !== "") {
                ceilingWarningCard.style.display = 'block';
                ceilingWarningCard.className = "info-panel-box";
                msg += (msg ? "<br><br>" : "") + "<strong>Sizing Rationale:</strong> " + limitingFactorMsg;
            }
            if (partitionExceeded) {
                ceilingWarningCard.style.display = 'block';
                if(msg === "") ceilingWarningCard.className = "info-panel-box";
                msg += (msg ? "<br><br>" : "") + "[ i ] INFO: " + partitionExceededMsg;
            }
            if (gfFitProblem) {
                ceilingWarningCard.style.display = 'block';
                ceilingWarningCard.className = "info-panel-box";
                msg = "[ ! ] " + escapeHtml(gfFitProblem) + (msg ? "<br><br>" + msg : "");
            }
            if (simNotes.length) {
                ceilingWarningCard.style.display = 'block';
                if (msg === "") ceilingWarningCard.className = "info-panel-box";
                msg += (msg ? "<br><br>" : "") + simNotes.join("<br><br>");
            }
            if (msg !== "") ceilingWarningCard.innerHTML = msg;

            var simActiveBadge = document.getElementById('gfActiveBadge');
            if (simGaps.refreshIncomplete) {
                simActiveBadge.innerText = "[ ! ] CHECK DATA"; simActiveBadge.className = "badge badge-warn";
                simActiveBadge.style = "";
            } else if (projectedActivePct <= 50) {
                simActiveBadge.innerText = "[ \u2713 ] LOW RISK"; simActiveBadge.className = "badge badge-pass";
                simActiveBadge.style = "";
            } else if (projectedActivePct <= 80) {
                simActiveBadge.innerText = "[ ! ] ELEVATED"; simActiveBadge.className = "badge badge-warn";
                simActiveBadge.style = "";
            } else {
                simActiveBadge.innerText = "[ X ] THRASH RISK"; simActiveBadge.className = "badge badge-warn";
                simActiveBadge.style.backgroundColor = "var(--soft-bg-danger)"; simActiveBadge.style.color = "var(--text-danger-soft)";
            }

        } else {
            // ===============================================
            // ORIGINAL BROWNFIELD EXPANSION MATH LOGIC
            // ===============================================
            var mode = document.getElementById('simInputMode').value;
            var bfValue = (mode === 'ratio') ? (parseInt(document.getElementById('simRatio').value) || 1)
                        : (mode === 'custom') ? (parseFloat(document.getElementById('customPct').value) || 0) / 100
                        : (parseFloat(document.getElementById('simDriveSize').value) || 0);
            // Each host is sized on its own (mtBrownfieldNvme). The 4,398.047 GB NVMe partition cap is a
            // vSphere kernel limit and 1:4 the highest supported ratio, whichever control (ratio
            // dropdown, custom %, or raw drive size) was used to reach a given per-host NVMe size.
            var bfExisting = clusterIsAlreadyTiered ? mtHostExisting(cachedHosts) : null;
            if (bfExisting && bfExisting.length !== hostDrams.length) bfExisting = null; // no per-host figures: fall back to the cluster totals below
            var bfn = mtBrownfieldNvme(hostDrams, (mode === 'ratio' || mode === 'custom') ? mode : 'drive', bfValue, bfExisting);
            var partitionExceeded = bfn.partitionExceeded, ratioExceeded = bfn.ratioExceeded;
            var uniformHosts = bfn.minPerHost === bfn.maxPerHost;
            var nvmePerHostUsable = bfn.maxPerHost;
            var driveSizeGBSelected = (mode === 'ratio' || mode === 'custom') ? bfn.maxPerHost : bfValue;
            var effectiveMultiplier = ((mode === 'ratio' || mode === 'custom') && !partitionExceeded && !ratioExceeded)
                ? bfValue : (bfn.dram > 0 ? bfn.usable / bfn.dram : 0);

            var totalNvmeClusterSizeUsable = bfn.usable;
            var totalTieredMem = globalDram + totalNvmeClusterSizeUsable;

            var totalUsed = totalTieredMem > 0 ? ((globalConsumed / totalTieredMem) * 100).toFixed(2) : 0;

            var priceDramGB = mtNum('costDram', 100);
            var priceNvmeGB = mtNum('costNvme', 0.25);
            var mirroringActive = document.getElementById('chkMirroring').checked;

            var totalPhysicalNvmeClusterSize = bfn.physical;
            // A cluster that already runs Memory Tiering only needs the NVMe it does not have yet, so
            // both sides of the comparison (DRAM avoided, NVMe bought) use the added capacity only.
            var existingNvme = clusterIsAlreadyTiered ? mtExistingNvme(cachedHosts) : 0;
            var addedNvmeUsable = bfExisting ? bfn.added : Math.max(0, totalNvmeClusterSizeUsable - existingNvme);
            var addedNvmePhysical = bfExisting ? bfn.addedPhysical : Math.max(0, totalPhysicalNvmeClusterSize - existingNvme);
            var rawDramExpansionCost = addedNvmeUsable * priceDramGB;
            var tieredHardwareCost = addedNvmePhysical * priceNvmeGB * (mirroringActive ? 2 : 1);
            
            if (clusterIsAlreadyTiered) {
                // "Already Configured" only when this target needs no NVMe beyond what is installed. Comparing
                // the target with one host's ratio was wrong when ratios differ or only some hosts are tiered.
                matchingConfig = addedNvmeUsable <= 0;
                if (matchingConfig) {
                    activeTierAlertDiv.innerText = "[ i ] Environment Context: Memory Tiering is already active on this cluster (" + tierSummary + "). The target you selected needs no NVMe beyond what is already installed.";
                } else {
                    activeTierAlertDiv.innerText = "[ i ] Environment Context: Memory Tiering is already active on this cluster (" + tierSummary + "). Formulas below outline incremental capacity shifts vs the active baseline.";
                }
            }

            var netFinancialSavings = rawDramExpansionCost - tieredHardwareCost;

            var typicalVmProfileGB = MT_VM_PROFILE_GB;
            var currentVmDensity = Math.floor((globalDram + existingNvme) / typicalVmProfileGB);
            var simulatedVmDensity = Math.floor(totalTieredMem / typicalVmProfileGB);
            var netVmDensityGain = simulatedVmDensity - currentVmDensity;

            document.getElementById('bfDram').innerText = globalDram + " GB";
            document.getElementById('bfDramPerHost').innerText = avgDramPerHost + " GB" + (uniformHosts ? "" : " avg");
            
            document.getElementById('bfNvme').innerText = (existingNvme > 0)
                ? "+ " + addedNvmeUsable + " GB Usable to add (" + totalNvmeClusterSizeUsable + " GB target, " + existingNvme + " GB installed)"
                : "+ " + totalNvmeClusterSizeUsable + " GB Usable Total";
            document.getElementById('bfNvmePerHost').innerText = uniformHosts ? "+ " + mtGbText(nvmePerHostUsable) + " GB" : "+ " + bfn.minPerHost + " to " + bfn.maxPerHost + " GB";
            
            document.getElementById('bfTotal').innerText = "= " + totalTieredMem + " GB";
            document.getElementById('bfCapacityVal').innerText = totalUsed + "%";
            document.getElementById('bfActiveVal').innerText = activePct + "%";
            
            if (matchingConfig) {
                document.getElementById('bfCost').innerText = "Already Configured";
                document.getElementById('bfSavings').innerText = "Already Configured";
                document.getElementById('bfCostLabel').style.color = "var(--text-muted)";
                document.getElementById('bfSavingsLabel').style.color = "var(--text-muted)";
                document.getElementById('bfCost').style.color = "var(--text-muted)";
                document.getElementById('bfSavings').style.color = "var(--text-muted)";
            } else {
                document.getElementById('bfCost').innerText = "$" + tieredHardwareCost.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                document.getElementById('bfSavings').innerText = "$" + netFinancialSavings.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});
                document.getElementById('bfCostLabel').style.color = "var(--text-danger-strong)";
                document.getElementById('bfSavingsLabel').style.color = "var(--text-success)";
                document.getElementById('bfCost').style.color = "var(--text-danger-strong)";
                document.getElementById('bfSavings').style.color = "var(--text-success)";
            }
            // Whether this cluster qualifies at all rests on its Active Memory, so no savings figure while that is incomplete.
            if (simGaps.activeIncomplete && !matchingConfig) {
                document.getElementById('bfSavings').innerText = "Check data";
                document.getElementById('bfSavings').style.color = "var(--text-warning-soft)";
            }
            
            document.getElementById('bfHeadroom').innerText = "+ " + netVmDensityGain + " VMs";

            var driveCountLabel = mirroringActive ? "2x " : "1x ";
            if (mode === 'ratio') {
                document.getElementById('bfDriveReqLabel').innerText = driveCountLabel + mtDriveText(nvmePerHostUsable) + " Drive/Host minimum specification (Ratio 1:" + mtRatioText(effectiveMultiplier) + (uniformHosts ? "" : ", sized for the largest host") + ")";
            } else if (mode === 'custom') {
                document.getElementById('bfDriveReqLabel').innerText = driveCountLabel + mtDriveText(nvmePerHostUsable) + " Drive/Host minimum specification (" + (effectiveMultiplier * 100).toFixed(0) + "% NVMe" + (uniformHosts ? "" : ", sized for the largest host") + ")";
            } else {
                document.getElementById('bfDriveReqLabel').innerText = driveCountLabel + mtDriveText(driveSizeGBSelected) + " Drive provisioned \u2794 Yields Usable Ratio 1:" + effectiveMultiplier.toFixed(2);
            }

            // 1:1 is the only ratio that doesn't ask Active Memory to fit inside a smaller DRAM
            // tier than the workload's own baseline -- anything above it is a deliberate tradeoff,
            // not a free multiplier, so it's called out every time it's selected, independent of
            // (and always shown alongside, never replaced by) whichever cap/exceed notice below
            // also applies. Tolerance covers 'drive' mode, where the effective ratio is derived
            // from a physical drive size and rarely lands on an exact integer.
            // Only above 1:1: a lower effective ratio (a small drive, or a host capped at 4,398.047 GB) needs no extra assessment.
            var ratioAdvisoryMsg = (effectiveMultiplier - 1 > 0.03)
                ? "The recommended ratio for Memory Tiering is 1:1 (Default). Ratios above 1:1 require additional workload assessment, since Active Memory needs to be proportionally lower to reliably fit within the DRAM tier."
                : "";

            if (ratioAdvisoryMsg || partitionExceeded || ratioExceeded || simNotes.length) {
                ceilingWarningCard.style.display = 'block';
                ceilingWarningCard.className = 'info-panel-box';
                var msg = "";
                if (ratioAdvisoryMsg) { msg += "[ i ] INFO: " + ratioAdvisoryMsg; }
                if (partitionExceeded || ratioExceeded) {
                    var capMsg = "The highest supported memory tiering configuration is a 1:4 ratio. ";
                    if (partitionExceeded && ratioExceeded) {
                        capMsg += "The active capacity parameters have been capped at a usable 4,398.047 GB per host, matching maximum layout profile boundaries.";
                    } else if (partitionExceeded) {
                        capMsg += "Usable tier allocations are capped at 4,398.047 GB per host to align with vSphere kernel constraints.";
                    } else if (ratioExceeded) {
                        capMsg += "The target hardware specs have been automatically balanced to map within standard 1:4 layout configurations.";
                    }
                    msg += (msg ? "<br><br>" : "") + "[ i ] INFO: " + capMsg;
                }
                if (simNotes.length) msg += (msg ? "<br><br>" : "") + simNotes.join("<br><br>");
                ceilingWarningCard.innerHTML = msg;
            }

            var simActiveBadge = document.getElementById('bfActiveBadge');
            if (simGaps.activeIncomplete) {
                simActiveBadge.innerText = "[ ! ] CHECK DATA"; simActiveBadge.className = "badge badge-warn";
                simActiveBadge.style = "";
            } else if (activePct <= 50) {
                simActiveBadge.innerText = "[ \u2713 ] LOW RISK"; simActiveBadge.className = "badge badge-pass";
                simActiveBadge.style = "";
            } else if (activePct <= 80) {
                simActiveBadge.innerText = "[ ! ] ELEVATED"; simActiveBadge.className = "badge badge-warn";
                simActiveBadge.style = "";
            } else {
                simActiveBadge.innerText = "[ X ] THRASH RISK"; simActiveBadge.className = "badge badge-warn";
                simActiveBadge.style.backgroundColor = "var(--soft-bg-danger)"; simActiveBadge.style.color = "var(--text-danger-soft)";
            }
            setPctBar('bfActiveBar', activePct, { pass: activePct <= 50 });
            setPctBar('bfCapacityBar', totalUsed, {});
        }
    }

    // ======================= CUSTOMER REPORT (v3.2+) =======================
    // Builds a self-contained, printable HTML report (Print -> Save as PDF) from whatever is loaded.
    // The sizing here uses the SAME formulas as runSimulationMath() above, restated as pure functions
    // so every cluster can be scored without touching the screen (checked against the on-screen
    // results during development). Savings are only counted for clusters that qualify (peak Active
    // Memory at or below 50% of DRAM, not already tiered), and every assumption is printed in the report.
    var repMeta = { customer: '', preparedBy: '' };
    var REP_VM_GB = MT_VM_PROFILE_GB;

    function repNum(id, def) { var el = document.getElementById(id), v = el ? parseFloat(el.value) : NaN; return isNaN(v) ? def : v; }
    function repPricing() {
        var ha = parseInt(document.getElementById('gfHa').value);
        return {
            dram: mtNum('costDram', 100), nvme: mtNum('costNvme', 0.25),
            mirror: !!document.getElementById('chkMirroring').checked,
            server: mtNum('gfServerCost', 15000), ha: isNaN(ha) ? 1 : ha, cpuMult: repNum('gfCpuMult', 1) || 1
        };
    }
    function repMoney(n) { var neg = n < 0; n = Math.abs(Math.round(n)); return (neg ? '-' : '') + '$' + n.toLocaleString('en-US'); }
    function repMoneyShort(n) {
        var a = Math.abs(n), s;
        if (a >= 1e9) s = (a / 1e9).toFixed(2) + 'B'; else if (a >= 1e6) s = (a / 1e6).toFixed(2) + 'M'; else if (a >= 1e3) s = (a / 1e3).toFixed(1) + 'K'; else s = String(Math.round(a));
        return (n < 0 ? '-' : '') + '$' + s;
    }
    function repTb(gb) { return gb >= 10000 ? (gb / 1000).toLocaleString('en-US', { maximumFractionDigits: 1 }) + ' TB' : Math.round(gb).toLocaleString('en-US') + ' GB'; }
    function repPct(v, d) { return (isFinite(v) ? v : 0).toFixed(d === undefined ? 1 : d) + '%'; }

    // Report label: plain cluster name for imports (the "(VCF Ops)" source tag adds nothing for a
    // customer), "cluster (vCenter)" for live clusters, where the vCenter does tell clusters apart.
    function repLabel(key) {
        var bar = key.indexOf('|'), prefix = key.slice(0, bar), cl = key.slice(bar + 1);
        if (!OBF_SYNTHETIC_PREFIX[prefix]) return advClusterLabel(key);
        return obfOn() ? obfName('cluster', cl) : cl;
    }

    // One entry per cluster in scope, using its most recent range.
    function repClusterList(scope, selKey, rangeLabel) {
        var keys = Object.keys(clusterSessionCache);
        if (scope === 'selected') {
            var sel = selKey;
            if (!clusterSessionCache[sel]) sel = document.getElementById('simClusterSelect').value;
            if (!clusterSessionCache[sel]) sel = lastAppliedClusterKey;
            keys = clusterSessionCache[sel] ? [sel] : [];
        }
        var out = [];
        keys.forEach(function(k) {
            var c = clusterSessionCache[k], range = typeof rangeLabel === 'string' ? rangeLabel : c.lastRange, d = c.ranges[range];
            if (!d || !(d.hosts || []).length) return;
            var hostCount = mtGoodHosts(d.hosts).length || d.hosts.length, dram = Number(d.dram) || 0, active = Number(d.active) || 0;
            var dOnly = mtDramOnly(d.vms);
            var tenantHost = d.hosts.filter(function(h) { return h.Tenant; })[0];
            out.push({
                key: k, label: repLabel(k), range: range, d: d, hostCount: hostCount, dram: dram,
                consumed: Number(d.consumed) || 0, active: active, activeAvg: typeof d.activeAvg === 'number' ? d.activeAvg : null,
                cpu: typeof d.cpu === 'number' ? d.cpu : 0, cpuNA: typeof d.cpu !== 'number',
                tiered: d.hosts.some(function(h) { return h.Tiering === 'Enabled'; }),
                activePct: dram > 0 ? active / dram * 100 : 0, consPct: dram > 0 ? (Number(d.consumed) || 0) / dram * 100 : 0,
                avgDramPerHost: Math.round(dram / hostCount), tenant: tenantHost ? tenantHost.Tenant : null,
                hostDrams: mtHostDrams(d.hosts, dram), dOnly: dOnly, sizingActivePct: mtActivePct(dram, active, dOnly),
                missingActive: mtAssessmentMissing(d.hosts).length, missingCpu: mtMissing(d.hosts, 'CPU').length, tierUnknown: mtTierUnknown(d.hosts).length,
                missingConsumed: mtMissing(d.hosts, 'Consumed').length, failedHosts: mtFailedHosts(d.hosts).length, big: mtLargestVms(d.vms),
                failedVms: (d.failedVms || []).length, dOnlySizes: mtDramOnlySizes(d.vms)
            });
        });
        // Qualifies: Active Memory at or below 50% of the DRAM tiering can use, every host collected with
        // Active samples, and not already tiered.
        out.forEach(function(ci) { ci.eligible = !ci.tiered && ci.dram > 0 && !ci.missingActive && !ci.failedHosts && !ci.failedVms && mtActiveOk(ci.sizingActivePct); });
        return out;
    }

    // Brownfield: add NVMe to existing hosts (same math as the Sizing tab's ratio mode).
    function repBrownfield(ci, m, pr) {
        var b = mtBrownfieldNvme(ci.hostDrams, 'ratio', m), capped = b.partitionExceeded || b.ratioExceeded;
        var eff = capped ? (b.dram > 0 ? b.usable / b.dram : 0) : m;
        var usable = b.usable, total = ci.dram + usable;
        var avoided = usable * pr.dram, cost = b.physical * pr.nvme * (pr.mirror ? 2 : 1);
        return { kind: 'brownfield', ratio: eff, nvPerHost: b.maxPerHost, capped: capped, usable: usable, total: total, avoided: avoided, cost: cost,
                 savings: avoided - cost, vmGain: Math.floor(total / REP_VM_GB) - Math.floor(ci.dram / REP_VM_GB) };
    }
    // Greenfield: refresh onto new nodes of a given capacity (same math as the Sizing tab's capacity mode).
    function repGreenfield(ci, nodeCap, ratio, pr) {
        var gfDram = Math.max(1, (nodeCap / (1 + ratio))), gfNvme = nodeCap - gfDram, capped = false, nodeMem = nodeCap;
        if (gfNvme > MT_NVME_LIMIT_GB) { gfNvme = MT_NVME_LIMIT_GB; capped = true; nodeMem = gfDram + gfNvme; }
        var reqConsStd = Math.ceil(ci.consumed / nodeCap), reqConsTier = Math.ceil(ci.consumed / nodeMem);
        var reqCpu = Math.ceil((ci.cpu * ci.hostCount) / (80 * pr.cpuMult));
        // DRAM-only VMs have to sit whole on hosts other than the HA spares, so they still fit after a failure.
        var stdPack = mtPackCount(ci.dOnlySizes, nodeCap), tierPack = mtPackCount(ci.dOnlySizes, gfDram);
        var stdBase = Math.max(reqConsStd, reqCpu, isFinite(stdPack) ? stdPack : 0, 1), stdHosts = stdBase + pr.ha;
        var reqActive = Math.ceil(mtActiveLoad(ci.active, ci.dOnly) / (gfDram * 0.50));
        var tierBase = Math.max(reqConsTier, reqCpu, reqActive, isFinite(tierPack) ? tierPack : 0, 1), tierHosts = tierBase + pr.ha;
        var stdCost = stdHosts * (pr.server + nodeCap * pr.dram);
        var tierCost = tierHosts * (pr.server + gfDram * pr.dram + gfNvme * pr.nvme * (pr.mirror ? 2 : 1));
        var activeProj = (tierHosts * gfDram) > 0 ? mtActivePct(tierHosts * gfDram, ci.active, ci.dOnly) : 0;
        // Every VM has to fit on one node: a DRAM-only VM in the node's DRAM, any VM in its total memory.
        var big = ci.big || { vm: 0, dramOnly: 0 };
        var stdFits = big.vm <= nodeCap && isFinite(stdPack), tierFits = big.dramOnly <= gfDram && big.vm <= nodeMem && isFinite(tierPack);
        return { kind: 'greenfield', fits: stdFits && tierFits, stdFits: stdFits, tierFits: tierFits, nodeCap: nodeCap, ratio: ratio, dramPerNode: gfDram, nvmePerNode: gfNvme, capped: capped,
                 stdHosts: stdHosts, tierHosts: tierHosts, stdCost: stdCost, tierCost: tierCost, savings: stdCost - tierCost, activeProj: activeProj };
    }
    function repGfCaps() {
        var out = [];
        Array.prototype.forEach.call(document.getElementById('gfNodeCapSelect').options, function(o) { var v = parseFloat(o.value); if (!isNaN(v)) out.push(v); });
        return out.length ? out : [512, 1024, 1536, 2048, 3072, 4096].map(function(v) { return v * MT_LEGACY_GB_FACTOR; });
    }
    // Best supported option per cluster: highest savings across the allowed ratios (and node sizes for refresh).
    function repBestBrownfield(ci, pr, maxRatio) {
        var best = null;
        for (var m = 1; m <= maxRatio; m++) { var r = repBrownfield(ci, m, pr); if (!best || r.savings > best.savings) best = r; }
        return best;
    }
    // The cheapest DRAM-only refresh against the cheapest tiered refresh, each at whichever node size
    // (and, for tiered, ratio) costs least while running the workload. Picking the node size with the
    // largest savings instead compared against an ever more expensive DRAM-only baseline, and could
    // recommend a far costlier configuration than a feasible cheaper one.
    function repBestGreenfield(ci, pr, maxRatio, caps) {
        var bestStd = null, bestTier = null;
        function better(r, cur, cost, hosts) { return !cur || r[cost] < cur[cost] || (r[cost] === cur[cost] && r[hosts] < cur[hosts]); }
        caps.forEach(function(cap) {
            for (var m = 1; m <= maxRatio; m++) {
                var r = repGreenfield(ci, cap, m, pr);
                if (m === 1 && r.stdFits && better(r, bestStd, 'stdCost', 'stdHosts')) bestStd = r;
                if (r.tierFits && r.activeProj <= 50 && better(r, bestTier, 'tierCost', 'tierHosts')) bestTier = r;
            }
        });
        if (!bestStd || !bestTier) return null;
        return { kind: 'greenfield', nodeCap: bestTier.nodeCap, ratio: bestTier.ratio, dramPerNode: bestTier.dramPerNode, nvmePerNode: bestTier.nvmePerNode, capped: bestTier.capped,
                 tierHosts: bestTier.tierHosts, tierCost: bestTier.tierCost, activeProj: bestTier.activeProj,
                 stdNodeCap: bestStd.nodeCap, stdHosts: bestStd.stdHosts, stdCost: bestStd.stdCost, savings: bestStd.stdCost - bestTier.tierCost };
    }
    // Scores every cluster in scope at the recommended 1:1 ratio only. Only eligible clusters count
    // toward savings; a scenario that would cost more than it saves contributes $0 (leave it as is).
    function repScoreClusters(list, pr) {
        var caps = repGfCaps();
        list.forEach(function(ci) {
            ci.bf = {}; ci.gf = {};
            if (!ci.eligible) return;
            ci.bf[1] = repBrownfield(ci, 1, pr);
            // A refresh is sized from CPU and Consumed Memory, so none is recommended while hosts lack them.
            ci.gfBlocked = !!(ci.missingCpu || ci.missingConsumed);
            ci.gfRec = ci.gfBlocked ? null : repBestGreenfield(ci, pr, 1, caps);
        });
    }
    function repFleetTotals(list) {
        var t = { all: list.length, eligible: 0, exTiered: 0, exActive: 0, exData: 0, tierUnknown: 0, gfBlocked: 0, hosts: 0, dram: 0, bf1: 0, bfCost: 0, bfNv: 0, bfVm: 0,
                  gf1: 0, gfClusters: 0, gfStdHosts: 0, gfTierHosts: 0, noGain: 0 };
        list.forEach(function(ci) {
            t.hosts += ci.hostCount; t.dram += ci.dram;
            if (ci.tiered) { t.exTiered++; return; }
            if (ci.missingActive || ci.failedHosts || ci.failedVms) { t.exData++; return; }
            if (!ci.eligible) { t.exActive++; return; }
            if (ci.tierUnknown) t.tierUnknown++;
            t.eligible++;
            var b = ci.bf[1]; t.bf1 += Math.max(0, b.savings); t.bfCost += b.cost; t.bfNv += b.usable; t.bfVm += b.vmGain;
            if (ci.gfBlocked) t.gfBlocked++;
            else if (ci.gfRec && ci.gfRec.savings > 0) { t.gf1 += ci.gfRec.savings; t.gfClusters++; t.gfStdHosts += ci.gfRec.stdHosts; t.gfTierHosts += ci.gfRec.tierHosts; }
            else t.noGain++;
        });
        t.best = Math.max(t.bf1, t.gf1); t.bestIsBf = t.bf1 >= t.gf1;
        return t;
    }

    // ---------- report building blocks ----------
    function repKpi(label, value, sub) { return '<div class="kpi"><div class="kl">' + escapeHtml(label) + '</div><div class="kv">' + value + '</div>' + (sub ? '<div class="ks">' + escapeHtml(sub) + '</div>' : '') + '</div>'; }
    function repBadge(ok, yes, no) { return '<span class="bdg ' + (ok ? 'ok' : 'no') + '">' + escapeHtml(ok ? yes : no) + '</span>'; }
    function repTable(headers, rows, opts) {
        opts = opts || {};
        var left = opts.left || 1;
        var h = '<table><thead><tr>' + headers.map(function(x, i) { return '<th' + (i < left ? '' : ' class="r"') + '>' + escapeHtml(x) + '</th>'; }).join('') + '</tr></thead><tbody>';
        rows.forEach(function(r) { h += '<tr' + (r._cls ? ' class="' + r._cls + '"' : '') + '>' + r.cells.map(function(c, i) { return '<td' + (i < left ? '' : ' class="r"') + '>' + c + '</td>'; }).join('') + '</tr>'; });
        var tableHtml=h + '</tbody></table>';return rows.length>10?'<details class="rep-long-list"><summary>Show / hide '+fmtInt(rows.length)+' rows</summary>'+tableHtml+'</details>':tableHtml;
    }
    function repSvgHist(edges, counts) {
        var n = counts.length, W = 860, H = 230, L = 52, R = 10, T = 10, B = 40, pw = W - L - R, ph = H - T - B, max = 1;
        counts.forEach(function(c) { if (c > max) max = c; });
        var ticks = niceTicks(0, max, 4), yMax = ticks[ticks.length - 1], o = '';
        ticks.forEach(function(t) { var y = T + ph - t / yMax * ph; o += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y + '" y2="' + y + '" stroke="#e1e1e1"/><text x="' + (L - 6) + '" y="' + (y + 3) + '" text-anchor="end" font-size="10" fill="#6b6b6b">' + fmtInt(t) + '</text>'; });
        var slot = pw / n, bw = slot - 3;
        for (var i = 0; i < n; i++) {
            var hgt = counts[i] / yMax * ph;
            o += '<rect x="' + (L + i * slot + 1.5) + '" y="' + (T + ph - hgt) + '" width="' + Math.max(1, bw) + '" height="' + hgt + '" rx="2" fill="#0072a3"><title>' + edges[i] + '-' + edges[i + 1] + '%: ' + fmtInt(counts[i]) + ' hosts</title></rect>';
        }
        for (var e = 0; e <= n; e++) { if (edges[e] % 5 === 0) o += '<text x="' + (L + e * slot) + '" y="' + (T + ph + 15) + '" text-anchor="middle" font-size="10" fill="#6b6b6b">' + edges[e] + '%</text>'; }
        o += '<text x="' + (L + pw / 2) + '" y="' + (H - 4) + '" text-anchor="middle" font-size="11" fill="#313131">Active memory % of host capacity</text>';
        o += '<text x="12" y="' + (T + ph / 2) + '" text-anchor="middle" font-size="11" fill="#313131" transform="rotate(-90 12 ' + (T + ph / 2) + ')">Hosts</text>';
        return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%">' + o + '</svg>';
    }
    function repSvgHBars(rows, color) {
        var W = 860, rowH = 24, labelW = 230, valW = 120, H = rows.length * rowH + 8, max = 0, o = '';
        rows.forEach(function(r) { if (r.value > max) max = r.value; });
        rows.forEach(function(r, i) {
            var y = 4 + i * rowH, w = max > 0 ? Math.max(2, r.value / max * (W - labelW - valW - 10)) : 2;
            o += '<text x="' + (labelW - 8) + '" y="' + (y + 15) + '" text-anchor="end" font-size="11" fill="#313131">' + escapeHtml(r.label.length > 34 ? r.label.slice(0, 33) + '...' : r.label) + '</text>';
            o += '<rect x="' + labelW + '" y="' + (y + 3) + '" width="' + w + '" height="' + (rowH - 8) + '" rx="2" fill="' + (r.color || color || '#0072a3') + '"/>';
            o += '<text x="' + (labelW + w + 6) + '" y="' + (y + 15) + '" font-size="11" fill="#313131" font-weight="600">' + escapeHtml(r.text) + '</text>';
        });
        return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%">' + o + '</svg>';
    }
    function repSvgTimeline(model) {
        var A = model.ACTIVE, sum = {}, cnt = {}, any = false;
        Object.keys(A.series).forEach(function(c) { var s = A.series[c]; s.h.forEach(function(hh, i) { sum[hh] = (sum[hh] || 0) + s.v[i]; cnt[hh] = (cnt[hh] || 0) + 1; any = true; }); });
        if (!any) return '';
        var hs = Object.keys(sum).map(Number).sort(function(a, b) { return a - b; }), vals = hs.map(function(h) { return sum[h] / cnt[h]; });
        var W = 860, H = 230, L = 52, R = 10, T = 10, B = 40, pw = W - L - R, ph = H - T - B, vmax = Math.max(60, Math.max.apply(null, vals));
        var ticks = niceTicks(0, vmax, 5), yMax = ticks[ticks.length - 1], hMax = hs[hs.length - 1] || 1, o = '';
        ticks.forEach(function(t) { var y = T + ph - t / yMax * ph; o += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y + '" y2="' + y + '" stroke="#e1e1e1"/><text x="' + (L - 6) + '" y="' + (y + 3) + '" text-anchor="end" font-size="10" fill="#6b6b6b">' + t + '%</text>'; });
        var y50 = T + ph - 50 / yMax * ph;
        o += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y50 + '" y2="' + y50 + '" stroke="#c25400" stroke-dasharray="5,4"/><text x="' + (W - R) + '" y="' + (y50 - 4) + '" text-anchor="end" font-size="10" fill="#c25400">50% guideline</text>';
        var pts = hs.map(function(h, i) { return (L + h / hMax * pw).toFixed(1) + ',' + (T + ph - vals[i] / yMax * ph).toFixed(1); }).join(' ');
        o += '<polyline points="' + pts + '" fill="none" stroke="#0072a3" stroke-width="2"/>';
        [0, hMax / 2, hMax].forEach(function(h, i) { var d = new Date(A.base_ts_ms + h * 3600000); o += '<text x="' + (L + h / hMax * pw) + '" y="' + (T + ph + 15) + '" text-anchor="' + (i === 0 ? 'start' : (i === 2 ? 'end' : 'middle')) + '" font-size="10" fill="#6b6b6b">' + escapeHtml(d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })) + '</text>'; });
        o += '<text x="' + (L + pw / 2) + '" y="' + (H - 4) + '" text-anchor="middle" font-size="11" fill="#313131">Fleet average Active memory % (retained samples)</text>';
        return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%">' + o + '</svg>';
    }

    // ---------- sections ----------
    function repBar(pct, pass) {
        var w = Math.max(0, Math.min(100, pct || 0));
        return '<div class="pbar"><i class="' + (pass === true ? 'pass' : (pass === false ? 'warn' : '')) + '" style="width:' + w.toFixed(1) + '%"></i></div>';
    }
    function repMetricRow(name, target, pctVal, text, badgeHtml) {
        return '<div class="mrow"><div class="mname">' + escapeHtml(name) + '</div><div class="mtarget">' + target + '</div><div class="mval"><b>' + text + '</b>' + (pctVal === null ? '' : repBar(pctVal.pct, pctVal.pass)) + '</div><div class="mbadge">' + (badgeHtml || '') + '</div></div>';
    }
    // Mirrors the Baseline Assessment tab: the qualification checklist, the Range Comparison Matrix,
    // then the Physical Host and VM breakdown tables.
    function repSectionAssessment(list, tot, allowedRanges, matrixKeys) {
        var dram = 0, cons = 0, act = 0, actAvg = 0, avgKnown = true, cpuSum = 0, cpuHosts = 0;
        list.forEach(function(ci) { dram += ci.dram; cons += ci.consumed; act += ci.active; if (ci.activeAvg === null) avgKnown = false; else actAvg += ci.activeAvg; if (!ci.cpuNA) { cpuSum += ci.cpu * ci.hostCount; cpuHosts += ci.hostCount; } });
        var dOa = { n: 0, gb: 0, active: 0 }, missA = 0, missC = 0;
        var failN = 0;
        var failVmN = 0;
        list.forEach(function(ci) { dOa.n += ci.dOnly.n; dOa.gb += ci.dOnly.gb; dOa.active += ci.dOnly.active; missA += ci.missingActive; missC += ci.missingCpu; failN += ci.failedHosts; failVmN += ci.failedVms; });
        var checkA = missA + failN + failVmN;
        var activeOkRep = mtActiveOk(mtActivePct(dram, act, dOa)), checkData = '<span class="bdg no">CHECK DATA</span>';
        var actPct = dram > 0 ? act / dram * 100 : 0, avgPct = (avgKnown && dram > 0) ? actAvg / dram * 100 : null, consPct = dram > 0 ? cons / dram * 100 : 0, cpu = cpuHosts ? cpuSum / cpuHosts : null;
        var rangeNames = {}; list.forEach(function(ci) { rangeNames[ci.range] = true; });
        var rangeText = Object.keys(rangeNames).join(', ');
        var h = '<section class="sec"><h2>1. Baseline assessment</h2>';
        h += '<div class="panel"><div class="ptitle">Baseline qualification checklist (raw hardware - ' + escapeHtml(rangeText) + ')' + (list.length > 1 ? ' <small>' + fmtInt(list.length) + ' clusters combined</small>' : ' <small>' + escapeHtml(list[0].label) + '</small>') + '</div>';
        h += repMetricRow('CPU usage (avg)', '[ Target: &lt;= 50% ]', cpu === null ? null : { pct: cpu, pass: missC ? null : cpu <= 50 }, cpu === null ? 'N/A' : repPct(cpu), cpu === null ? '<span class="bdg na">N/A</span>' : (missC ? checkData : repBadge(cpu <= 50, '\u2713 PASS', 'X WARN')));
        var sizPctRep = mtActivePct(dram, act, dOa);
        h += repMetricRow('Active memory (peak)', '[ Target: &lt;= 50% ]', { pct: dOa.n ? Math.min(100, sizPctRep) : actPct, pass: checkA ? null : activeOkRep }, repPct(actPct) + (dOa.n ? ' <small>(' + mtPctLabel(sizPctRep) + ' of DRAM left for tiering)</small>' : ''), checkA ? checkData : repBadge(activeOkRep, '\u2713 PASS', 'X WARN'));
        h += repMetricRow('Active memory (avg)', '<i>[ For reference only ]</i>', avgPct === null ? null : { pct: avgPct, pass: null }, avgPct === null ? 'N/A' : repPct(avgPct), '');
        h += repMetricRow('Consumed memory (avg)', '<i>[ For reference only ]</i>', { pct: consPct, pass: null }, repPct(consPct), '');
        if (avgPct !== null) {
            var gap = actPct - avgPct, bursty = avgPct <= 0 ? actPct > 0 : (actPct / avgPct) >= 2;
            if (bursty && gap >= 10) h += '<div class="note warnbox">High variability: peak is ' + (avgPct > 0 ? (actPct / avgPct).toFixed(1) + 'x the average' : 'far above an average of about 0%') + ' (' + gap.toFixed(1) + ' point gap). Confirm this reflects a recurring pattern before sizing around it.</div>';
        }
        var notes = [];
        list.forEach(function(ci) { (ci.d.dataNotes || []).forEach(function(n) { if (notes.indexOf(n) < 0) notes.push(n); }); });
        var missingActiveCounters=list.reduce(function(n,ci){return n+mtMissing(ci.d.hosts,'Active').length},0);
        if (missingActiveCounters || missC) notes.push('Some hosts returned no ' + (missingActiveCounters && missC ? 'Active Memory or CPU' : (missingActiveCounters ? 'Active Memory' : 'CPU')) + ' samples for this range. Missing counter values show as No data; affected checks remain CHECK DATA.');
        if(missA>missingActiveCounters)notes.push('Required physical capacity, retained coverage, tier configuration or VM eligibility is unverified for '+fmtInt(missA-missingActiveCounters)+' host(s). Available performance measurements are still displayed; qualification and savings are withheld until the required configuration/data is verified.');
        if (failN) notes.push(fmtInt(failN) + ' host' + (failN === 1 ? '' : 's') + ' failed data collection (marked ERROR below) and ' + (failN === 1 ? 'is' : 'are') + ' not in the totals, so the Active Memory check shows CHECK DATA.');
        if (failVmN) notes.push(fmtInt(failVmN) + ' VM' + (failVmN === 1 ? '' : 's') + ' failed data collection, so a VM that has to stay in DRAM could be missing; the Active Memory check shows CHECK DATA.');
        if (dOa.n) notes.push(fmtInt(dOa.n) + ' VM' + (dOa.n === 1 ? '' : 's') + ' must keep their memory in DRAM (' + repTb(dOa.gb) + ': passthrough or vGPU devices, pinned memory, Latency Sensitivity High, Fault Tolerance, or tiering disabled). That memory is never moved to NVMe, so the Active Memory check uses the DRAM left for tiering: Active Memory is ' + mtPctLabel(mtActivePct(dram, act, dOa)) + ' of it.');
        if (notes.length) h += '<div class="note">' + notes.map(function(n) { return escapeHtml(n); }).join('<br>') + '</div>';
        h += '</div>';

        // Range Comparison Matrix (every analyzed range for the clusters in scope)
        var mrows = [];
        (matrixKeys?matrixKeys.map(function(key){return {key:key,label:repLabel(key)}}):list).forEach(function(ci) {
            var ranges = clusterSessionCache[ci.key].ranges;
            Object.keys(ranges).forEach(function(r, i) {
                if(allowedRanges && allowedRanges.indexOf(r)<0 && !(allowedRanges.indexOf(null)>=0 && clusterSessionCache[ci.key].lastRange===r))return;
                var d = ranges[r], pk = d.dram > 0 ? d.active / d.dram * 100 : 0, av = (typeof d.activeAvg === 'number' && d.dram > 0) ? d.activeAvg / d.dram * 100 : null, cn = d.dram > 0 ? d.consumed / d.dram * 100 : 0, cp = typeof d.cpu === 'number' ? d.cpu : null;
                mrows.push({ cells: [escapeHtml(ci.label), escapeHtml(r), cp === null ? 'N/A' : repPct(cp) + repBar(cp, null), repPct(pk) + repBar(pk, null), av === null ? 'N/A' : repPct(av) + repBar(av, null), repPct(cn) + repBar(cn, null)] });
            });
        });
        list.forEach(function(ci) { if (ci.d.source === 'ops') h += '<h3>Ops peak evidence: ' + escapeHtml(ci.label) + ' - ' + escapeHtml(ci.range) + '</h3>' + mtOpsPeakEvidenceHtml(ci.d.hosts || [], false); });
        h += '<h3>Range comparison matrix</h3>' + repTable(['Target cluster scope', 'Analyzed range', 'CPU avg %', 'Active mem peak %', 'Active mem avg %', 'Consumed mem avg %'], mrows, { left: 2 });

        // Physical Host Breakdown
        var hostRows = [];
        list.forEach(function(ci) { (ci.d.hosts || []).forEach(function(x) { hostRows.push(x); }); });
        var multi = list.length > 1;
        if (multi) hostRows.sort(function(a, b) { return (Number(b.Active_Pct) || 0) - (Number(a.Active_Pct) || 0); });
        var hcap = multi ? 50 : 200;
        h += '<h3>Physical host breakdown' + (hostRows.length > hcap ? ' (' + (multi ? 'busiest ' : 'first ') + hcap + ' of ' + fmtInt(hostRows.length) + ' hosts)' : '') + '</h3>' + repTable(['Cluster', 'Host', 'Tiering', 'CPU %', 'Physical RAM (GB)', 'Consumed (GB)', 'Active (GB)', 'Active %'],
            hostRows.slice(0, hcap).map(function(x) { return { _cls: x.Tiering === 'ERROR' ? 'bad' : '', cells: [escapeHtml(x.Cluster), escapeHtml(x.HostName), escapeHtml(x.Tiering), mtHas(x, 'CPU') ? 'No data' : (typeof x.CPU_Pct === 'number' ? x.CPU_Pct + '%' : 'N/A'), escapeHtml(mtCapacityLabel(x)), mtHas(x, 'Consumed') ? 'No data' : fmt(x.Consumed_GB, 2), mtHas(x, 'Active') ? 'No data' : fmt(x.Active_GB, 2), mtHas(x, 'Active') ? 'No data' : (Math.round((Number(x.Active_Pct) || 0) * 10) / 10) + '%'] }; }), { left: 3 });

        // VM Breakdown (only when the source has VM rows)
        var vmRows = [];
        list.forEach(function(ci) { (ci.d.vms || []).forEach(function(v) { vmRows.push(v); }); });
        if (vmRows.length) {
            vmRows.sort(function(a, b) { return (Number(b.Active_Pct) || 0) - (Number(a.Active_Pct) || 0); });
            var vcap = 50;
            h += '<h3>Virtual machine breakdown' + (vmRows.length > vcap ? ' (highest Active % first, ' + vcap + ' of ' + fmtInt(vmRows.length) + ' VMs)' : '') + '</h3>' + repTable(['Host', 'VM', 'Provisioned (GB)', 'Active (GB)', 'Active %', 'DRAM-only', '1 GB pages', '2 MB pages'],
                vmRows.slice(0, vcap).map(function(v) { return { cells: [escapeHtml(v.Host), escapeHtml(v.VMName), fmt(v.Provisioned_GB, 0), mtHas(v, 'Active') ? 'No data' : fmt(v.Active_GB, 2), mtHas(v, 'Active') ? 'No data' : (Math.round((Number(v.Active_Pct) || 0) * 10) / 10) + '%', escapeHtml(v.DRAM_Only || 'N/A'), escapeHtml(v.Pages_1GB), escapeHtml(v.Pages_2MB)] }; }), { left: 2 });
        }
        return h + '</section>';
    }

    // Static versions of the Advanced Analytics tab's threshold views. With an hourly timeline they
    // draw the overlaid lines of everything that crossed the threshold; with one value per cluster or
    // host they draw the same heat map the tab shows (counts per Active % band, one row per tenant).
    var REP_HEAT_EDGES = [0, 2, 4, 6, 8, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, Infinity];
    function repHeatSvg(pop, o) {
        var edges = o.edges || REP_HEAT_EDGES, nb = edges.length - 1, groups = {}, totals = {};
        pop.forEach(function(p) {
            var g = o.tenantOf ? o.tenantOf(p.cluster) : ('All ' + o.unit + 's');
            if (!groups[g]) { groups[g] = []; totals[g] = 0; for (var i = 0; i < nb; i++) groups[g].push(0); }
            var b = 0; while (b < nb - 1 && p.value >= edges[b + 1]) b++;
            groups[g][b]++; totals[g]++;
        });
        var order = Object.keys(groups).sort(function(a, b) { return totals[b] - totals[a]; });
        if (order.length > 16) {
            var keep = order.slice(0, 15), other = []; for (var q = 0; q < nb; q++) other.push(0);
            order.slice(15).forEach(function(g) { groups[g].forEach(function(n, i) { other[i] += n; }); });
            groups['(other tenants)'] = other; order = keep.concat(['(other tenants)']);
        }
        var maxN = 1; order.forEach(function(g) { groups[g].forEach(function(n) { if (n > maxN) maxN = n; }); });
        var labelW = 150, cellW = Math.max(36, Math.floor((860 - labelW - 12) / nb)), cellH = 26, top = 26, W = labelW + cellW * nb + 12, H = top + cellH * order.length + 44, o2 = '';
        function lab(b) { return edges[b + 1] === Infinity ? edges[b] + '%+' : edges[b] + '-' + edges[b + 1] + '%'; }
        for (var b = 0; b < nb; b++) o2 += '<text x="' + (labelW + b * cellW + cellW / 2) + '" y="' + (top - 9) + '" text-anchor="middle" font-size="9.5" fill="#6b6b6b">' + lab(b) + '</text>';
        order.forEach(function(g, gi) {
            var y = top + gi * cellH;
            o2 += '<text x="' + (labelW - 8) + '" y="' + (y + cellH / 2 + 4) + '" text-anchor="end" font-size="11" fill="#313131">' + escapeHtml(g.length > 22 ? g.slice(0, 21) + '...' : g) + '</text>';
            for (var c = 0; c < nb; c++) {
                var n = groups[g][c], x = labelW + c * cellW, hot = edges[c] >= o.threshold, op = n ? 0.2 + 0.8 * Math.sqrt(n / maxN) : 0;
                o2 += '<rect x="' + (x + 1) + '" y="' + (y + 1) + '" width="' + (cellW - 2) + '" height="' + (cellH - 2) + '" rx="2" fill="' + (n ? '#0072a3' : '#eeeeee') + '" fill-opacity="' + (n ? op.toFixed(2) : 0.6) + '"' + (hot ? ' stroke="#c25400" stroke-width="1.3"' : '') + '/>';
                if (n) o2 += '<text x="' + (x + cellW / 2) + '" y="' + (y + cellH / 2 + 4) + '" text-anchor="middle" font-size="10" font-weight="600" fill="' + (op > 0.55 ? '#ffffff' : '#313131') + '">' + fmtInt(n) + '</text>';
            }
        });
        var tb = 0; while (tb < nb && edges[tb] < o.threshold) tb++;
        if (tb < nb) { var tx = labelW + tb * cellW; o2 += '<line x1="' + tx + '" x2="' + tx + '" y1="' + (top - 4) + '" y2="' + (top + cellH * order.length + 4) + '" stroke="#c25400" stroke-width="2" stroke-dasharray="4,3"/><text x="' + (tx + 4) + '" y="' + (top + cellH * order.length + 18) + '" font-size="10" font-weight="600" fill="#c25400">at or above ' + o.threshold + '% (outlined)</text>'; }
        o2 += '<text x="' + (labelW + cellW * nb / 2) + '" y="' + (H - 6) + '" text-anchor="middle" font-size="11" fill="#313131">' + escapeHtml(o.label) + ' band, ' + o.unit + 's per cell</text>';
        return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%">' + o2 + '</svg>';
    }
    function repLinesSvg(items, baseMs, thr, yLabel) {
        var shown = items.filter(function(it){return it.s && it.s.h.length && it.s.v.length}), maxH = 0, vMax = 0;
        shown.forEach(function(it) { if (it.s.h.length) maxH = Math.max(maxH, it.s.h[it.s.h.length - 1]); vMax = Math.max(vMax, it.peak); });
        if (!shown.length) return '<div class="small">No historical samples in this scope.</div>';
        if (maxH <= 0) maxH = 1;
        var W = 860, H = 260, L = 52, R = 10, T = 10, B = 40, pw = W - L - R, ph = H - T - B, ticks = niceTicks(0, Math.max(vMax, thr), 5), yHi = ticks[ticks.length - 1], o = '';
        ticks.forEach(function(t) { var y = T + ph - t / yHi * ph; o += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y + '" y2="' + y + '" stroke="#e1e1e1"/><text x="' + (L - 6) + '" y="' + (y + 3) + '" text-anchor="end" font-size="10" fill="#6b6b6b">' + Math.round(t) + '%</text>'; });
        var yT = T + ph - thr / yHi * ph; o += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + yT + '" y2="' + yT + '" stroke="#c25400" stroke-dasharray="5,4" class="threshold-line"/><text x="' + (W-R-4) + '" y="' + Math.max(12,yT-6) + '" text-anchor="end" font-size="11" fill="#c25400">' + escapeHtml(String(thr)) + '% threshold</text>';
        var op = Math.max(0.08, Math.min(0.6, 40 / shown.length));
        shown.forEach(function(it) {
            var pts = it.s.h.map(function(hh, i) { return (L + hh / maxH * pw).toFixed(1) + ',' + (T + ph - Math.min(it.s.v[i], yHi) / yHi * ph).toFixed(1); }).join(' ');
            o += '<polyline points="' + pts + '" fill="none" stroke="#0072a3" stroke-width="1" stroke-opacity="' + op.toFixed(2) + '"><title>' + escapeHtml(it.name || 'Series') + ' — peak ' + escapeHtml(fmt(it.peak,1)) + '%</title></polyline>';
        });
        shown.forEach(function(it){if(it.s.h.length===1)o+='<circle cx="'+(L+it.s.h[0]/maxH*pw)+'" cy="'+(T+ph-it.s.v[0]/yHi*ph)+'" r="2.5" fill="#0072a3"><title>'+escapeHtml(it.name||'Series')+'</title></circle>'});
        [0, maxH / 2, maxH].forEach(function(hh, i) { var d = new Date(baseMs + hh * 3600000); o += '<text x="' + (L + hh / maxH * pw) + '" y="' + (T + ph + 15) + '" text-anchor="' + (i === 0 ? 'start' : (i === 2 ? 'end' : 'middle')) + '" font-size="10" fill="#6b6b6b">' + escapeHtml(d.toISOString().slice(0,maxH<=48?16:10).replace('T',' ') + (maxH<=48?' UTC':'')) + '</text>'; });
        o += '<text x="' + (L + pw / 2) + '" y="' + (H - 4) + '" text-anchor="middle" font-size="11" fill="#313131">' + escapeHtml(yLabel) + '</text>';
        return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%">' + o + '</svg>';
    }
    // Same qualifying rule as the tab: peak at or above the threshold, and at or above it for the given share of samples.
    function repCrossing(metas, seriesOf, thr, per) {
        var out = [];
        metas.forEach(function(m) {
            if (m.peak < thr) return;
            var s = seriesOf(m); if (!s || !s.v.length) return;
            var above = 0; s.v.forEach(function(v) { if (v >= thr) above++; });
            var pct = above / s.v.length * 100;
            if (pct >= per) out.push({ m: m, s: s, peak: m.peak, timePct: pct });
        });
        out.sort(function(a, b) { return b.timePct - a.timePct || b.peak - a.peak; });
        return out;
    }

    var REP_ADV_CSS = "        #advReport {\n            --surface-1: #fcfcfb; --page-plane: #f9f9f7; --text-primary: #0b0b0b; --text-secondary: #52514e;\n            --text-muted: #898781; --gridline: #e1e0d9; --baseline: #c3c2b7; --border: rgba(11,11,11,0.10);\n            --series-1: #2a78d6; --series-1-wash: rgba(42,120,214,0.10); --series-1-100: #cde2fb;\n            background: var(--page-plane); color: var(--text-primary); border-radius: 10px;\n            padding: 28px clamp(14px, 2vw, 28px) 40px; font-family: system-ui, -apple-system, \"Segoe UI\", sans-serif;\n        }\n        @media (prefers-color-scheme: dark) {\n            html:not([data-theme=\"light\"]) #advReport {\n                --surface-1: #1a1a19; --page-plane: #0d0d0d; --text-primary: #ffffff; --text-secondary: #c3c2b7;\n                --text-muted: #898781; --gridline: #2c2c2a; --baseline: #383835; --border: rgba(255,255,255,0.10);\n                --series-1: #3987e5; --series-1-wash: rgba(57,135,229,0.14); --series-1-100: #184f95;\n            }\n        }\n        html[data-theme=\"dark\"] #advReport {\n            --surface-1: #1a1a19; --page-plane: #0d0d0d; --text-primary: #ffffff; --text-secondary: #c3c2b7;\n            --text-muted: #898781; --gridline: #2c2c2a; --baseline: #383835; --border: rgba(255,255,255,0.10);\n            --series-1: #3987e5; --series-1-wash: rgba(57,135,229,0.14); --series-1-100: #184f95;\n        }\n        #advReport * { box-sizing: border-box; }\n        #advReport .rpt-head h1 { font-size: 22px; font-weight: 600; margin: 0 0 4px; color: var(--text-primary); }\n        #advReport .rpt-head p { font-size: 13px; color: var(--text-secondary); margin: 0 0 22px; }\n        #advReport .rpt-view-switch { display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin:10px 0 12px; }\n        #advReport .rpt-view-switch button[aria-pressed=\"true\"] { background:var(--text-accent); color:#fff; border-color:var(--text-accent); }\n        #advReport .rpt-view-switch button:disabled { opacity:0.55; cursor:not-allowed; }\n        #advReport .rpt-view-switch .view-help { flex-basis:100%; font-size:12px; color:var(--text-secondary); }\n        #advReport .rpt-scope { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-end; margin-bottom: 20px; }\n        #advReport .rpt-scope label { display: flex; flex-direction: column; gap: 5px; font-size: 12px; color: var(--text-secondary); }\n        #advReport .rpt-scope label.obf-card { flex-direction: row; align-items: center; gap: 12px; margin-left: auto; }\n        #advReport select, #advReport input[type=\"search\"], #advReport input[type=\"number\"] {\n            font-size: 13px; padding: 7px 10px; border-radius: 7px; border: 1px solid var(--border);\n            background: var(--surface-1); color: var(--text-primary); height: auto; font-weight: normal;\n        }\n        #advReport .rpt-scope select { min-width: 260px; }\n        #advReport .tenant-filter { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; margin-bottom: 20px; }\n        #advReport .tenant-filter-head { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; margin-bottom: 10px; }\n        #advReport .tenant-filter-title { font-size: 13px; font-weight: 600; }\n        #advReport .tenant-filter-actions { font-size: 12px; }\n        #advReport .tenant-filter-actions a { color: var(--series-1); text-decoration: none; cursor: pointer; }\n        #advReport .tenant-filter-actions a:hover { text-decoration: underline; }\n        #advReport .tenant-checks { display: flex; flex-wrap: wrap; gap: 8px; }\n        #advReport .tenant-chip { display: inline-flex; align-items: center; gap: 6px; font-size: 12.5px; border: 1px solid var(--border); border-radius: 999px; padding: 5px 12px 5px 10px; cursor: pointer; user-select: none; background: var(--page-plane); color: var(--text-primary); font-weight: normal; margin: 0; }\n        #advReport .tenant-chip input { cursor: pointer; }\n        #advReport .tenant-chip.excluded { opacity: 0.5; }\n        #advReport .tenant-chip .tenant-chip-count { color: var(--text-muted); font-variant-numeric: tabular-nums; }\n        #advReport .kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin-bottom: 36px; }\n        #advReport .stat-tile { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; }\n        #advReport .stat-tile .label { font-size: 12px; color: var(--text-secondary); margin-bottom: 6px; }\n        #advReport .stat-tile .value { font-size: 24px; font-weight: 600; letter-spacing: -0.01em; color: var(--text-primary); }\n        #advReport .stat-tile .unit { font-size: 13px; font-weight: 400; color: var(--text-secondary); margin-left: 3px; }\n        #advReport section { margin-bottom: 40px; }\n        #advReport h2 { font-size: 15px; font-weight: 600; margin: 0 0 4px; color: var(--text-primary); }\n        #advReport .section-sub { font-size: 12px; color: var(--text-muted); margin: 0 0 16px; line-height: 1.45; }\n        #advReport .hist-subhead { font-size: 12.5px; font-weight: 600; color: var(--text-secondary); margin: 22px 0 8px; }\n        #advReport .hist-subhead.first { margin-top: 0; }\n        #advReport .chart-card { background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; padding: 20px 20px 8px; }\n        #advReport .controls { display: flex; gap: 10px; align-items: center; margin-bottom: 12px; flex-wrap: wrap; }\n        #advReport .controls input[type=\"search\"] { width: 260px; }\n        #advReport .count { font-size: 12px; color: var(--text-muted); }\n        #advReport .threshold-controls .count-emphasis { font-size: 14px; font-weight: 700; color: var(--text-primary); }\n        #advReport .controls label, #advReport .threshold-controls label { font-size: 12px; color: var(--text-secondary); font-weight: normal; margin: 0; }\n        #advReport table { width: 100%; border-collapse: collapse; background: var(--surface-1); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; font-size: 12.5px; }\n        #advReport th, #advReport td { border: none; background: transparent; }\n        #advReport thead th { text-align: right; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--text-muted); padding: 10px 14px; border-bottom: 1px solid var(--gridline); cursor: pointer; user-select: none; white-space: nowrap; background: var(--surface-1); }\n        #advReport thead th:first-child, #advReport tbody td:first-child { text-align: left; }\n        #advReport thead th:hover { color: var(--text-primary); }\n        #advReport thead th .arrow { font-size: 9px; margin-left: 3px; opacity: .5; }\n        #advReport tbody td { padding: 7px 14px; font-size: 12.5px; text-align: right; font-variant-numeric: tabular-nums; border-bottom: 1px solid var(--gridline); color: var(--text-primary); }\n        #advReport tbody td:first-child { font-variant-numeric: normal; color: var(--text-secondary); }\n        #advReport tbody tr:last-child td { border-bottom: none; }\n        #advReport tbody tr:nth-child(even) td { background: transparent; }\n        #advReport tbody tr:hover td { background: var(--series-1-wash); }\n        #advReport .table-wrap { max-height: 640px; overflow: auto; border-radius: 10px; }\n        #advReport tbody td:first-child { white-space: nowrap; }\n        #advReport .rpt-no-timeline { font-size: 12px; color: var(--text-muted); text-align: center; padding: 18px 10px 26px; }\n        #advReport thead { position: sticky; top: 0; background: var(--surface-1); z-index: 1; }\n        #advReport .hist-svg, #advReport .overlay-svg { width: 100%; height: auto; display: block; touch-action: none; }\n        #advReport .hist-bar { fill: var(--series-1); cursor: pointer; }\n        #advReport .hist-bar:hover { filter: brightness(1.12); }\n        #advReport .axis-line { stroke: var(--baseline); stroke-width: 1; }\n        #advReport .grid-line { stroke: var(--gridline); stroke-width: 1; }\n        #advReport .axis-label { fill: var(--text-muted); font-size: 10px; font-family: system-ui, sans-serif; }\n        #advReport .axis-label-strong { fill: var(--text-secondary); font-size: 10.5px; font-family: system-ui, sans-serif; }\n        #advReport .overlay-line { fill: none; stroke: var(--series-1); stroke-width: 1; stroke-linejoin: round; stroke-linecap: round; opacity: var(--overlay-opacity, 0.14); }\n        #advReport .overlay-line.emphasis { stroke-width: 2; opacity: 1; }\n        #advReport .threshold-controls { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; flex-wrap: wrap; }\n        #advReport .threshold-controls input[type=\"number\"] { width: 90px; font-variant-numeric: tabular-nums; }\n        #advReport .threshold-note { font-size: 11.5px; color: var(--text-muted); margin: 0 0 8px; }\n        #advReport .chart-empty { fill: var(--text-muted); font-size: 12px; font-family: system-ui, sans-serif; text-anchor: middle; }\n        #advReport .svg-tooltip { position: absolute; pointer-events: none; background: var(--surface-1); border: 1px solid var(--border); border-radius: 6px; padding: 6px 10px; font-size: 12px; color: var(--text-primary); box-shadow: 0 2px 8px rgba(0,0,0,0.15); display: none; white-space: nowrap; z-index: 5; }\n        #advReport .svg-tooltip .tt-value { font-weight: 600; font-variant-numeric: tabular-nums; }\n        #advReport .svg-tooltip .tt-label { color: var(--text-secondary); }\n        #advReport .svg-tooltip.tt-multi { white-space: normal; min-width: 190px; pointer-events: auto; }\n        #advReport .svg-tooltip.pinned { box-shadow: 0 2px 10px rgba(0,0,0,0.2), 0 0 0 1px var(--series-1) inset; }\n        #advReport .tt-close { position: absolute; top: 3px; right: 5px; cursor: pointer; font-size: 12px; line-height: 1; color: var(--text-muted); padding: 2px 3px; border-radius: 4px; }\n        #advReport .tt-close:hover { color: var(--text-primary); background: var(--series-1-wash); }\n        #advReport .tt-list { max-height: 260px; overflow-y: auto; margin-top: 4px; padding-right: 2px; }\n        #advReport .tt-row { display: flex; justify-content: space-between; gap: 12px; padding: 1px 0; font-size: 11.5px; color: var(--text-secondary); }\n        #advReport .tt-row .tt-row-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }\n        #advReport .tt-row .tt-row-val { font-variant-numeric: tabular-nums; flex-shrink: 0; }\n        #advReport .tt-row.tt-row-active { font-weight: 700; color: var(--text-primary); }\n        #advReport .tt-more { font-size: 11px; color: var(--text-muted); padding-top: 3px; }\n        #advReport .chart-wrap { position: relative; }\n        #advReport .cand-yes { color: #1f9d55; font-weight: 600; }\n        #advReport .cand-no { color: #d64545; font-weight: 600; }\n        #advReport .rpt-footer { font-size: 11px; color: var(--text-muted); border-top: 1px solid var(--gridline); padding-top: 14px; margin-top: 8px; line-height: 1.5; }\n        #advReport .rpt-list-details { border:1px solid var(--border);border-radius:7px;margin:14px 0;background:var(--surface-card); }\n        #advReport .rpt-list-details\u003esummary { padding:12px 14px;cursor:pointer;font-weight:600; }\n        #advReport .rpt-table-controls { display:flex;flex-wrap:wrap;gap:8px;align-items:center;padding:10px 14px; }\n        #advReport .rpt-table-controls input { min-width:220px;flex:1; }\n        #advReport .rpt-sort { border:0;background:none;color:inherit;font:inherit;font-weight:600;cursor:pointer;text-align:inherit;padding:4px 0; }\n        #advReport .rpt-sort:focus-visible { outline:2px solid var(--text-accent); }\n        #advReport .rpt-duration-controls { display:flex;flex-wrap:wrap;gap:10px;align-items:end;margin:12px 0; }\n        #advReport .rpt-duration-controls label { display:flex;flex-direction:column;gap:5px;font-size:12px; }\n        #advReport .rpt-duration-controls select { max-width:480px; }\n        #advReport .rpt-duration-controls input[type=number] { width:90px; }\n        #advReport .rpt-list-details .table-wrap { max-height:560px;overflow:auto; }\n        #advReport .rpt-list-details td { max-width:480px;overflow-wrap:anywhere; }\n        #advReport .tenant-checks { max-height:220px;overflow:auto; }\n        #advReport .rpt-duration-note { font-size:12px;color:var(--text-secondary); }\n        .rep-long-list { border:1px solid #d7dbe0;border-radius:6px;margin:12px 0; }.rep-long-list\u003esummary{padding:10px;cursor:pointer;font-weight:600;}\n        @media print { #advReport .rpt-table-controls,#advReport .rpt-sort,#advReport .rpt-view-switch { -webkit-print-color-adjust:exact;print-color-adjust:exact; } #advReport .rpt-list-details .table-wrap{max-height:none} }\n\n#advReport{--text-accent:#0072a3;--surface-card:var(--surface-1)}#advReport .btn{border:1px solid #0072a3;border-radius:4px;background:#0072a3;color:white;padding:6px 10px;cursor:pointer}#advReport .btn:disabled{opacity:.45;cursor:not-allowed}#advReport .section-sub{line-height:1.5}\n        #comparisonContainer .mtat-cluster-list\u003esummary {cursor:pointer;font-weight:700;padding:12px;border:1px solid var(--border-input);border-radius:5px;margin:12px 0;}\n        .mtat-sort-help {font-size:12px;font-weight:600;padding:8px 10px;background:var(--bg-panel);border-left:3px solid #0072a3;margin:8px 0;}\n        th.sortable {cursor:pointer;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:4px;}\n        th.sortable:hover,th.sortable:focus-visible {background:var(--bg-panel);outline:2px solid #0072a3;outline-offset:-2px;}\n        th.sortable .sort-arrow:empty::before {content:' \\2195';opacity:.7;}\n        #advReport .rpt-sort::after {content:' \\2195';opacity:.7;font-weight:400;}\n";
    var REP_ADV_MARKUP = "          \u003cdiv id=\"advReport\"\u003e\u003cdiv id=\"rptHistoryNotice\" role=\"status\" style=\"display:none;border:1px solid #b17700;border-radius:6px;padding:12px;margin:12px 0;background:var(--surface-1);\"\u003e\u003c/div\u003e\n\n            \u003cdiv class=\"rpt-head\"\u003e\n                \u003ch1 id=\"rptTitle\"\u003eHost Memory Report &middot; Summary\u003c/h1\u003e\n                \u003cp id=\"rptSource\"\u003e\u003c/p\u003e\n            \u003c/div\u003e\n            \u003cdiv class=\"rpt-scope\"\u003e\n                \u003clabel for=\"rptViewMode\"\u003e\u003cb\u003eAnalytics view\u003c/b\u003e\u003cselect id=\"rptViewMode\" onchange=\"rptChangeViewMode()\" aria-describedby=\"rptViewModeHint\"\u003e\u003coption value=\"matrix\"\u003eMatrix\u003c/option\u003e\u003coption value=\"timeline\"\u003eTimeline\u003c/option\u003e\u003c/select\u003e\u003c/label\u003e\n\n            \u003c/div\u003e\n\n            \u003cp id=\"rptViewModeHint\" class=\"section-sub\" role=\"status\" style=\"margin:-8px 0 18px;\"\u003e\u003c/p\u003e\n            \u003cdetails class=\"tenant-filter\" id=\"rptTenantFilter\" style=\"display:none;\"\u003e\u003csummary\u003eTenant filter (show / hide)\u003c/summary\u003e\n                \u003cdiv class=\"tenant-filter-head\"\u003e\n                    \u003cspan class=\"tenant-filter-title\"\u003eFilter by tenant\u003c/span\u003e\n                    \u003cspan class=\"tenant-filter-actions\"\u003e\u003ca id=\"rptTenantSelectAll\"\u003eAll\u003c/a\u003e &middot; \u003ca id=\"rptTenantSelectNone\"\u003eNone\u003c/a\u003e\u003c/span\u003e\n                    \u003cspan class=\"count\" id=\"rptTenantFilterCount\"\u003e\u003c/span\u003e\n                \u003c/div\u003e\n                \u003cdiv class=\"tenant-checks\" id=\"rptTenantChecks\"\u003e\u003c/div\u003e\n                \u003cp class=\"threshold-note\" id=\"rptTenantFilterNote\" style=\"margin:8px 0 0;\"\u003e\u003c/p\u003e\n            \u003c/details\u003e\n\n            \u003cdiv class=\"kpi-row\" id=\"rptKpiRow\"\u003e\u003c/div\u003e\n\n            \u003csection\u003e\n                \u003ch2\u003eActive memory % &middot; distribution across hosts\u003c/h2\u003e\n                \u003cp class=\"section-sub\"\u003eActive memory as a % of host capacity. Two bases, since a host's active % moves over time: the time-averaged view can hide a host that spikes briefly. Hover a bar for the exact range and count.\u003c/p\u003e\n                \u003ch3 class=\"hist-subhead first\" id=\"rptHistAvgSubhead\"\u003e\u003c/h3\u003e\n                \u003cdiv class=\"chart-card chart-wrap\" id=\"rptHistCardAvg\"\u003e\u003cdiv class=\"svg-tooltip\" id=\"rptHistTooltipAvg\"\u003e\u003c/div\u003e\u003c/div\u003e\n                \u003ch3 class=\"hist-subhead\" id=\"rptHistPeakSubhead\"\u003e\u003c/h3\u003e\n                \u003cdiv class=\"chart-card chart-wrap\" id=\"rptHistCardPeak\"\u003e\u003cdiv class=\"svg-tooltip\" id=\"rptHistTooltipPeak\"\u003e\u003c/div\u003e\u003c/div\u003e\n            \u003c/section\u003e\n\n            \u003csection\u003e\n                \u003ch2 id=\"rptClusterViewTitle\"\u003eActive memory % over time &middot; clusters crossing a threshold\u003c/h2\u003e\n                \u003cdiv class=\"rpt-view-switch\" role=\"group\" aria-label=\"Analytics chart view\"\u003e\n                    \u003cb\u003eView\u003c/b\u003e\n                    \u003cbutton type=\"button\" class=\"btn btn-sm\" id=\"rptClusterMatrixButton\" aria-pressed=\"true\" onclick=\"rptSetViewMode('matrix')\"\u003eMatrix\u003c/button\u003e\n                    \u003cbutton type=\"button\" class=\"btn btn-sm\" id=\"rptClusterTimelineButton\" aria-pressed=\"false\" aria-describedby=\"rptClusterViewHelp\" onclick=\"rptSetViewMode('timeline')\"\u003eTimeline\u003c/button\u003e\n                    \u003cspan class=\"view-help\" id=\"rptClusterViewHelp\"\u003e\u003c/span\u003e\n                \u003c/div\u003e\n                \u003cp class=\"section-sub\" id=\"rptClusterViewDescription\"\u003eEvery cluster (hourly average across its hosts) whose active % was at or above the threshold for at least the given share of its observed time, overlaid. A one-off spike does not qualify a cluster on its own. Hover the chart to pick out one cluster's line, or click the chart to pin the tooltip open so you can scroll its list; click again (or the &#10005;) to release it.\u003c/p\u003e\n                \u003cdiv class=\"threshold-controls\"\u003e\n                    \u003clabel for=\"rptClusterThresholdInput\"\u003eActive % threshold\u003c/label\u003e\n                    \u003cinput type=\"number\" id=\"rptClusterThresholdInput\" value=\"25\" min=\"0\" max=\"100\" step=\"1\"\u003e\n                    \u003clabel for=\"rptClusterPersistInput\"\u003efor at least\u003c/label\u003e\n                    \u003cinput type=\"number\" id=\"rptClusterPersistInput\" value=\"5\" min=\"0\" max=\"100\" step=\"1\"\u003e\n                    \u003clabel for=\"rptClusterPersistInput\"\u003e% of observed intervals\u003c/label\u003e\n                    \u003cspan class=\"count count-emphasis\" id=\"rptClusterThresholdCount\"\u003e\u003c/span\u003e\n                \u003c/div\u003e\n                \u003cdiv class=\"chart-card chart-wrap\" id=\"rptClusterOverlayCard\"\u003e\u003cdiv class=\"svg-tooltip\" id=\"rptClusterOverlayTooltip\"\u003e\u003c/div\u003e\u003c/div\u003e\n                \u003cdiv id=\"rptClusterCrossingTable\"\u003e\u003c/div\u003e\n            \u003c/section\u003e\n\n            \u003csection\u003e\n                \u003ch2 id=\"rptHostViewTitle\"\u003eActive memory % over time &middot; hosts crossing a threshold\u003c/h2\u003e\n                \u003cdiv class=\"rpt-view-switch\" role=\"group\" aria-label=\"Analytics chart view\"\u003e\n                    \u003cb\u003eView\u003c/b\u003e\n                    \u003cbutton type=\"button\" class=\"btn btn-sm\" id=\"rptHostMatrixButton\" aria-pressed=\"true\" onclick=\"rptSetViewMode('matrix')\"\u003eMatrix\u003c/button\u003e\n                    \u003cbutton type=\"button\" class=\"btn btn-sm\" id=\"rptHostTimelineButton\" aria-pressed=\"false\" aria-describedby=\"rptHostViewHelp\" onclick=\"rptSetViewMode('timeline')\"\u003eTimeline\u003c/button\u003e\n                    \u003cspan class=\"view-help\" id=\"rptHostViewHelp\"\u003e\u003c/span\u003e\n                \u003c/div\u003e\n                \u003cp class=\"section-sub\" id=\"rptHostViewDescription\"\u003eHosts whose active % was at or above the threshold for at least the given share of their observed time, overlaid (hourly). A one-off spike does not qualify a host on its own. Hover the chart to pick out one host's line, or click the chart to pin the tooltip open so you can scroll its list; click again (or the &#10005;) to release it.\u003c/p\u003e\n                \u003cdiv class=\"threshold-controls\"\u003e\n                    \u003clabel for=\"rptThresholdInput\"\u003eActive % threshold\u003c/label\u003e\n                    \u003cinput type=\"number\" id=\"rptThresholdInput\" value=\"25\" min=\"0\" max=\"100\" step=\"1\"\u003e\n                    \u003clabel for=\"rptPersistInput\"\u003efor at least\u003c/label\u003e\n                    \u003cinput type=\"number\" id=\"rptPersistInput\" value=\"5\" min=\"0\" max=\"100\" step=\"1\"\u003e\n                    \u003clabel for=\"rptPersistInput\"\u003e% of observed intervals\u003c/label\u003e\n                    \u003cspan class=\"count count-emphasis\" id=\"rptThresholdCount\"\u003e\u003c/span\u003e\n                \u003c/div\u003e\n                \u003cp class=\"threshold-note\" id=\"rptThresholdNote\"\u003e\u003c/p\u003e\n                \u003cdiv class=\"chart-card chart-wrap\" id=\"rptOverlayCard\"\u003e\u003cdiv class=\"svg-tooltip\" id=\"rptOverlayTooltip\"\u003e\u003c/div\u003e\u003c/div\u003e\n                \u003cdiv id=\"rptHostCrossingTable\"\u003e\u003c/div\u003e\n            \u003c/section\u003e\n\n            \u003csection id=\"rptDurationSection\"\u003e\n                \u003ch2\u003ePeak active memory and observed duration\u003c/h2\u003e\n                \u003cp class=\"section-sub\"\u003eA duration curve ranks retained chart intervals from busiest to quietest. It shows how often a high charted Active % occurs, rather than treating a peak as a sustained average. Choose a host or cluster, then inspect the busiest 10% or 15% of observed intervals.\u003c/p\u003e\n                \u003cdiv class=\"rpt-duration-controls\"\u003e\n                    \u003clabel\u003eTarget type\u003cselect id=\"rptDurationKind\"\u003e\u003coption value=\"host\"\u003eHost\u003c/option\u003e\u003coption value=\"cluster\"\u003eCluster mean\u003c/option\u003e\u003c/select\u003e\u003c/label\u003e\n                    \u003clabel\u003eSearch all targets\u003cinput type=\"search\" id=\"rptDurationSearch\" placeholder=\"Host or cluster name\"\u003e\u003c/label\u003e\n                    \u003clabel\u003eTarget\u003cselect id=\"rptDurationTarget\"\u003e\u003c/select\u003e\u003c/label\u003e\n                    \u003cbutton type=\"button\" class=\"btn btn-sm\" id=\"rptDurationPrev\" onclick=\"rptDurationPage--;rptRenderDuration()\"\u003ePrevious targets\u003c/button\u003e\n                    \u003cbutton type=\"button\" class=\"btn btn-sm\" id=\"rptDurationNext\" onclick=\"rptDurationPage++;rptRenderDuration()\"\u003eNext targets\u003c/button\u003e\n                    \u003clabel\u003eActive threshold (%)\u003cinput type=\"number\" id=\"rptDurationThreshold\" value=\"25\" min=\"0\" max=\"100\" step=\"1\"\u003e\u003c/label\u003e\n                    \u003clabel\u003eBusiest intervals (%)\u003cinput type=\"number\" id=\"rptDurationPercent\" value=\"10\" min=\"0\" max=\"100\" step=\"1\"\u003e\u003c/label\u003e\n                \u003c/div\u003e\n                \u003cp id=\"rptDurationCount\" class=\"count\"\u003e\u003c/p\u003e\u003cp id=\"rptDurationSummary\" role=\"status\"\u003e\u003c/p\u003e\n                \u003cdiv class=\"chart-card chart-wrap\" id=\"rptDurationCard\"\u003e\u003cdiv class=\"svg-tooltip\" id=\"rptDurationTooltip\"\u003e\u003c/div\u003e\u003c/div\u003e\n                \u003cp class=\"rpt-duration-note\"\u003eShares are calculated over available retained chart intervals, not the full wall-clock window. Missing intervals are not filled. Coarse averages and per-bin maxima cannot establish how long a shorter raw spike lasted. A reported host peak may be finer than the chart data; summary-only files do not establish peak duration.\u003c/p\u003e\n            \u003c/section\u003e\n            \u003csection\u003e\n                \u003ch2\u003ePer-cluster and per-host breakdowns\u003c/h2\u003e\n                \u003cp class=\"section-sub\"\u003eBoth lists default to Avg Active % descending. Every available host and cluster is searchable and sortable; pagination limits rendered rows without dropping data. Avg Active % is the mean of available averages. Cluster peak % sums reported host peaks against reported capacity; host peaks may occur at different times. Configuration and missing-data notes remain visible; these views do not certify sizing or savings.\u003c/p\u003e\n                \u003cdiv id=\"rptClusterBreakdownTable\"\u003e\u003c/div\u003e\u003cdiv id=\"rptHostBreakdownTable\"\u003e\u003c/div\u003e\n            \u003c/section\u003e\n\n            \u003cdiv class=\"rpt-footer\" id=\"rptFooter\"\u003e\u003c/div\u003e\n          \u003c/div\u003e";
    var REP_ADV_RUNTIME = "var RPT=null,rptBound=false,rptPreferredView=\"matrix\",rptEffectiveView=null,rptTables=Object.create(null),rptCollator=new Intl.Collator(undefined,{numeric:true,sensitivity:\"base\"}),rptDurationPage=0,RPT_HOUR_MS=3600000;\n    var RPT_UNMAPPED = \"(unmapped)\";\n    var RPT_SVGNS = \"http://www.w3.org/2000/svg\";\n    var RPT_HEAT_EDGES = [0, 2, 4, 6, 8, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, Infinity];\n    var RPT_AVG_EDGES = (function() { var e = []; for (var i = 0; i \u003c= 20; i++) e.push(i); for (var j = 25; j \u003c= 60; j += 5) e.push(j); return e; })();\n    var RPT_PEAK_EDGES = RPT_AVG_EDGES.concat([70, 80, 90, 100]);\n    function rptBinIndex(v, edges) {\n        var n = edges.length - 1;\n        if (v \u003e= edges[n]) return n - 1;\n        for (var i = 0; i \u003c n; i++) if (edges[i] \u003c= v && v \u003c edges[i + 1]) return i;\n        return 0;\n    }\n    function rptMean(a) { return a.length ? a.reduce(function(s, v) { return s + v; }, 0) / a.length : 0; }\n    function rptDay(ms) { return new Date(ms).toISOString().slice(0, 10); }\n    function rptTenantOf(cluster) { return RPT.TENANT ? (RPT.TENANT.cluster_tenant[cluster] || RPT_UNMAPPED) : null; }\n    function rptIncluded(cluster) { return !RPT.TENANT || !RPT.excludedTenants.has(rptTenantOf(cluster)); }\n    function rptHostLabel(hm) { var short = String(hm.host).split(\".\")[0]; return RPT.TENANT ? short + \" (\" + rptTenantOf(hm.cluster) + \")\" : short; }\n    function rptEl(id) { return document.getElementById(id); }\n    function rptTimelineAvailable(model) { if(!model.hasSeries)return false; if(!model.ACTIVE || !model.ACTIVE.series)return true; return Object.keys(model.ACTIVE.series).some(function(k){var h=model.ACTIVE.series[k].h;return h && h.length\u003e1 && h[h.length-1]\u003eh[0]}); }\n    function rptUseTimeline(model) { return rptTimelineAvailable(model) && (rptEffectiveView || rptPreferredView) === 'timeline'; }\n    function rptOpsTimelineEvidence(model) {\n        return (model.opsTimelineEvidence || []).map(function(e) {\n            function utc(ms) { return typeof ms === 'number' && isFinite(ms) ? new Date(ms).toISOString().replace('T',' ').replace('.000Z',' UTC') : 'unavailable'; }\n            return 'Ops active-memory evidence: ' + e.samples + ' returned samples; ' + e.points + ' host chart points; first ' + utc(e.first) + '; last ' + utc(e.last) + (e.bucketSeconds ? '; chart interval ' + e.bucketSeconds + ' seconds.' : '.');\n        }).join(' ');\n    }\n    function rptTimelineHelp(model) {\n        if (rptTimelineAvailable(model)) return 'All retained series are shown. The threshold line identifies crossings; threshold and duration controls affect counts and tables only.';\n        if (model.isOps && model.rangeLabel === 'Latest Ops Sample') return 'Latest Ops Sample is one timestamped snapshot, not history. On Assessment, select Past 24 Hours, Past 7 Days or Past 30 Days and analyze. Open that historical result, then select its Time range here.';\n        if (model.isOps) return 'Operations history has fewer than two usable chart time positions for this selection. Inspect observed sample coverage and collection notes on Assessment. Timelines require at least two distinct observed chart positions; the sample evidence below shows what reached analytics.';\n        if (model.rangeLabel === 'Real-Time Snapshot') return 'Real-Time Snapshot is one observation. Collect a historical range on Assessment and select it here to enable Timeline.';\n        return 'Timeline unavailable: this selection has fewer than two historical time positions. Summary CSVs retain peaks and averages without samples. Use timestamped workbooks or historical collection for a timeline.';\n    }\n    function rptSyncViewMode() {\n        var select = rptEl('rptViewMode'),available=rptTimelineAvailable(RPT),notice=rptEl('rptHistoryNotice');\n        if(notice){notice.style.display=available?'none':'block';notice.textContent=RPT.hasSeries\n            ? 'Timeline unavailable: this selection has fewer than two usable time positions. Select a collected historical range or inspect the collection notes for missing history.'\n            : 'This selection contains summary / snapshot values only, with no historical timestamps. Averages and reported peaks cannot reconstruct a timeline or peak duration. Import a timestamped Ops workbook (one host and timestamp per observation), or collect Past 24 Hours, Past 7 Days or Past 30 Days from a live Ops connection and select that historical range here. The matrix and complete tables remain available.';}\n\n        rptEffectiveView = rptTimelineAvailable(RPT) && rptPreferredView === 'timeline' ? 'timeline' : 'matrix';\n        select.value = rptEffectiveView;\n        ['Cluster','Host'].forEach(function(key) {\n            var matrix = rptEl('rpt' + key + 'MatrixButton'), line = rptEl('rpt' + key + 'TimelineButton');\n            matrix.setAttribute('aria-pressed', rptEffectiveView === 'matrix' ? 'true' : 'false');\n            line.setAttribute('aria-pressed', rptEffectiveView === 'timeline' ? 'true' : 'false');\n            line.disabled = !rptTimelineAvailable(RPT);\n            rptEl('rpt' + key + 'ViewHelp').textContent = rptTimelineHelp(RPT) + (RPT.isOps ? ' ' + rptOpsTimelineEvidence(RPT) : '');\n        });\n        var timeline = rptEffectiveView === 'timeline';\n        rptEl('rptClusterViewTitle').textContent = timeline ? 'Active memory over time: all clusters' : 'Active memory matrix: clusters by band';\n        rptEl('rptHostViewTitle').textContent = timeline ? 'Active memory over time: all hosts' : 'Active memory matrix: hosts by band';\n        rptEl('rptClusterViewDescription').textContent = timeline ? 'All observed clusters in the selected scope, using chart-interval averages across their observed hosts. The dashed line marks the active-memory threshold. Threshold and duration controls affect crossing counts and tables; every available series stays visible.' : 'All included clusters grouped into peak/snapshot memory bands. Outlined cells meet the active-memory threshold. The matrix does not establish time above a threshold; historical persistence is shown in the table.';\n        rptEl('rptHostViewDescription').textContent = timeline ? 'All observed hosts in the selected scope. The dashed line marks the active-memory threshold. Threshold and duration controls affect crossing counts and tables; every available series stays visible.' : 'All included hosts grouped into peak/snapshot memory bands. Outlined cells meet the active-memory threshold. The matrix does not establish time above a threshold; historical persistence is shown in the table.';\n        Array.prototype.forEach.call(select.options, function(o) { if (o.value === 'timeline') o.disabled = !rptTimelineAvailable(RPT); });\n        rptEl('rptViewModeHint').textContent = rptTimelineHelp(RPT) + (RPT.isOps ? ' ' + rptOpsTimelineEvidence(RPT) : '');\n    }\n    function rptSetViewMode(value) {\n        if (value === 'timeline' && !rptTimelineAvailable(RPT)) return;\n        rptPreferredView = value === 'timeline' ? 'timeline' : 'matrix';\n        rptEffectiveView = rptPreferredView;\n        try { localStorage.setItem('mtatAnalyticsView', rptPreferredView); } catch(e) {}\n        rptRenderAll();\n    }\n    function rptChangeViewMode() { rptSetViewMode(rptEl('rptViewMode').value); }\n    function rptFinite(v) { return typeof v==='number' && isFinite(v); }\n    function rptFmtPercent(v) { return rptFinite(v) ? fmt(v,1)+'%' : 'n/a'; }\n    function rptTableColumns(kind,crossing) {\n        var name=kind==='host'?[{key:'host',label:'Host'},{key:'cluster',label:'Cluster'}]:[{key:'cluster',label:'Cluster'},{key:'hosts',label:'Hosts',numeric:true,digits:0}];\n        return name.concat([{key:'avg',label:'Avg Active %',numeric:true,percent:true},{key:'peak',label:'Reported peak / snapshot %',numeric:true,percent:true}])\n            .concat(crossing?[{key:'timePct',label:'Observed intervals \u003e= threshold',numeric:true,percent:true}]:[])\n            .concat([{key:'activeGB',label:'Avg active (GB)',numeric:true,digits:2},{key:'capacityGB',label:'Reported capacity (GB)',numeric:true,digits:2}])\n            .concat(crossing?[{key:'status',label:'Data / configuration notes'}]:[])\n            .concat([{key:'_duration',label:'Duration'}]);\n    }\n    function rptPagedTable(id,rows,kind,title) {\n        var root=rptEl(id),state=rptTables[id];if(!root)return;\n        if(!state)state=rptTables[id]={page:0,size:25,sort:'avg',dir:-1,query:'',rows:[],columns:rptTableColumns(kind,id.indexOf('Crossing')\u003e=0),kind:kind};\n        state.rows=rows;state.kind=kind;\n        if(!root.firstElementChild){\n            var details=document.createElement('details');details.className='rpt-list-details';details.open=rows.length\u003e0 && rows.length\u003c=25;\n            var summary=document.createElement('summary');summary.textContent=title;details.appendChild(summary);state.summary=summary;\n            var bar=document.createElement('div');bar.className='rpt-table-controls';\n            var input=document.createElement('input');input.type='search';input.placeholder='Search all '+(kind==='host'?'hosts':'clusters')+'...';input.setAttribute('aria-label',input.placeholder);bar.appendChild(input);\n            var timer;input.addEventListener('input',function(){clearTimeout(timer);timer=setTimeout(function(){state.query=input.value.toLowerCase().trim();state.page=0;rptPaintTable(id)},150)});\n            var size=document.createElement('select');size.setAttribute('aria-label','Rows per page');[25,50,100,250,500].forEach(function(n){var o=document.createElement('option');o.value=n;o.textContent=n+' rows per page';size.appendChild(o)});\n            size.addEventListener('change',function(){state.size=Number(size.value);state.page=0;rptPaintTable(id)});bar.appendChild(size);\n            var prev=document.createElement('button');prev.type='button';prev.className='btn btn-sm';prev.textContent='Previous';prev.onclick=function(){state.page--;rptPaintTable(id)};bar.appendChild(prev);state.prev=prev;\n            var next=document.createElement('button');next.type='button';next.className='btn btn-sm';next.textContent='Next';next.onclick=function(){state.page++;rptPaintTable(id)};bar.appendChild(next);state.next=next;\n            var count=document.createElement('span');count.className='count';count.setAttribute('aria-live','polite');bar.appendChild(count);state.count=count;details.appendChild(bar);\n            var wrap=document.createElement('div');wrap.className='table-wrap';var table=document.createElement('table'),head=document.createElement('thead'),tr=document.createElement('tr');state.heads=[];\n            state.columns.forEach(function(c){var th=document.createElement('th');if(c.key==='_duration')th.textContent=c.label;else{var b=document.createElement('button');b.type='button';b.className='rpt-sort';b.textContent=c.label;b.onclick=function(){if(state.sort===c.key)state.dir*=-1;else{state.sort=c.key;state.dir=c.numeric?-1:1}state.page=0;rptPaintTable(id)};th.appendChild(b);state.heads.push({th:th,button:b,column:c})}tr.appendChild(th)});\n            head.appendChild(tr);table.appendChild(head);state.body=document.createElement('tbody');table.appendChild(state.body);wrap.appendChild(table);details.appendChild(wrap);root.appendChild(details);\n        }\n        state.title=title;rptPaintTable(id);\n    }\n    function rptPaintTable(id) {\n        var st=rptTables[id];if(!st)return;\n        var q=st.query,rows=st.rows.filter(function(r){return !q || [r.host,r.cluster,r.status].join(' ').toLowerCase().indexOf(q)\u003e=0});\n        rows.sort(function(a,b){var x=a[st.sort],y=b[st.sort];if(x===null||x===undefined)return y===null||y===undefined?0:1;if(y===null||y===undefined)return -1;var c=typeof x==='number'&&typeof y==='number'?x-y:rptCollator.compare(String(x),String(y));return c*st.dir || rptCollator.compare(String(a.host||a.cluster),String(b.host||b.cluster))});\n        st.filtered=rows;var pages=Math.max(1,Math.ceil(rows.length/st.size));st.page=Math.max(0,Math.min(pages-1,st.page));var start=st.page*st.size,end=Math.min(start+st.size,rows.length);\n        st.summary.textContent=st.title+' \u2014 '+fmtInt(st.rows.length)+' rows (show / hide)';st.count.textContent=(rows.length?fmtInt(start+1)+'\u2013'+fmtInt(end):'0')+' of '+fmtInt(rows.length)+' matching rows; '+fmtInt(st.rows.length)+' total';st.prev.disabled=st.page===0;st.next.disabled=st.page\u003e=pages-1;\n        st.heads.forEach(function(h){var on=h.column.key===st.sort;h.th.setAttribute('aria-sort',on?(st.dir===1?'ascending':'descending'):'none');h.button.textContent=h.column.label+(on?(st.dir===1?' \u25b2':' \u25bc'):'')});\n        st.body.textContent='';var frag=document.createDocumentFragment();\n        rows.slice(start,end).forEach(function(r){var tr=document.createElement('tr');st.columns.forEach(function(c){var td=document.createElement('td');if(c.key==='_duration'){var b=document.createElement('button');b.type='button';b.className='btn btn-sm';b.textContent='View';b.disabled=!r.hasHistory;b.onclick=function(){rptSelectDuration(st.kind,st.kind==='host'?r.id:r.cluster)};td.appendChild(b)}else{var v=r[c.key];td.textContent=v===null||v===undefined?'n/a':c.percent?rptFmtPercent(v):c.numeric?fmt(v,c.digits===undefined?1:c.digits):String(v);if(c.numeric)td.style.textAlign='right'}tr.appendChild(td)});frag.appendChild(tr)});\n        if(!rows.length){var tr=document.createElement('tr'),td=document.createElement('td');td.colSpan=st.columns.length;td.textContent='No matching rows.';tr.appendChild(td);frag.appendChild(tr)}st.body.appendChild(frag);\n    }\n    function rptAllHostRows() { return (RPT.HOSTACTIVE.all_hosts || RPT.HOSTACTIVE.host_meta).filter(function(h){return rptIncluded(h.cluster)}); }\n    function rptClusterRows() {\n        var map=Object.create(null),history=RPT.ACTIVE.series;\n        rptAllHostRows().forEach(function(h){var g=map[h.cluster]||(map[h.cluster]={cluster:h.cluster,hosts:0,sumAvg:0,known:0,activeGB:0,capacityGB:0,peakGB:0,complete:true,hasHistory:false,status:[],kind:'cluster'});g.hosts++;if(rptFinite(h.avg)){g.sumAvg+=h.avg;g.known++}if(rptFinite(h.capacityGB))g.capacityGB+=h.capacityGB;else g.complete=false;if(rptFinite(h.activeGB))g.activeGB+=h.activeGB;if(rptFinite(h.peakGB))g.peakGB+=h.peakGB;else g.complete=false;g.hasHistory=g.hasHistory||h.hasHistory;if(h.status&&g.status.indexOf(h.status)\u003c0)g.status.push(h.status)});\n        return Object.keys(map).map(function(k){var g=map[k];g.avg=g.known?g.sumAvg/g.known:null;g.peak=g.complete&&g.capacityGB\u003e0?g.peakGB/g.capacityGB*100:null;g.status=g.known+'/'+g.hosts+' hosts with active data'+(g.status.length?'; '+g.status.join('; '):'');if(g.known!==g.hosts)g.activeGB=null;g.timePct=null;return g});\n    }\n    function rptCrossing(series,threshold) { if(!series||!series.v.length)return null;var n=0;series.v.forEach(function(v){if(v\u003e=threshold)n++});return n/series.v.length*100; }\n    function rptActiveThreshold(kind) {\n        var host=kind==='host',thrEl=rptEl(host?'rptThresholdInput':'rptClusterThresholdInput'),perEl=rptEl(host?'rptPersistInput':'rptClusterPersistInput');\n        var thr=Math.max(0,Math.min(100,Number(thrEl.value))),per=Math.max(0,Math.min(100,Number(perEl.value)));if(!isFinite(thr)||!isFinite(per))return;thrEl.value=thr;perEl.value=per;\n        var population=host?rptAllHostRows():rptClusterRows(),rows=[],known=0,unknown=0;\n        population.forEach(function(h){var series=host?RPT.HOSTACTIVE.seriesOf(h.id):RPT.ACTIVE.series[h.cluster];var pct=h.hasHistory?rptCrossing(series,thr):null;if(pct===null){if(!rptFinite(h.peak)||h.peak\u003cthr)return;unknown++;rows.push(Object.assign({},h,{timePct:null}));return}if(pct\u003e=per){known++;rows.push(Object.assign({},h,{timePct:pct}))}});\n        var count=rptEl(host?'rptThresholdCount':'rptClusterThresholdCount');count.textContent=RPT.hasSeries?fmtInt(known)+' of '+fmtInt(population.length)+' '+(host?'hosts':'clusters')+' meet the \u2265'+thr+'% / \u2265'+per+'% observed-interval rule'+(unknown?'; '+unknown+' additional peak/snapshot rows have unknown duration':''):fmtInt(rows.length)+' of '+fmtInt(population.length)+' '+(host?'hosts':'clusters')+' have reported peak/snapshot \u2265'+thr+'%; duration is unavailable';\n        rptPagedTable(host?'rptHostCrossingTable':'rptClusterCrossingTable',rows,kind,'Rows at or above the active threshold');\n        var historyClusters=Object.create(null);rptClusterRows().forEach(function(c){if(c.hasHistory)historyClusters[c.cluster]=true});\n        var metas=host?RPT.HOSTACTIVE.host_meta.filter(function(h){return rptIncluded(h.cluster)&&h.hasHistory}):RPT.ACTIVE.cluster_meta.filter(function(h){return rptIncluded(h.cluster)&&historyClusters[h.cluster]});\n        var items=rptTimelineItems(metas,host?function(h){return RPT.HOSTACTIVE.seriesOf(h.id)}:function(h){return RPT.ACTIVE.series[h.cluster]},host?function(h){return h.host+' ('+h.cluster+')'}:function(h){return h.cluster});\n        rptRenderOverlay({card:host?'rptOverlayCard':'rptClusterOverlayCard',tooltip:host?'rptOverlayTooltip':'rptClusterOverlayTooltip',baseMs:RPT.ACTIVE.base_ts_ms,threshold:thr,unit:kind,yLabel:'Active memory % (retained chart interval)',emptyText:'No historical active-memory samples in this scope',items:items,peakOf:function(it){return it.peak},population:population.filter(function(h){return rptFinite(h.peak)}).map(function(h){return {name:host?h.host:h.cluster,cluster:h.cluster,value:h.peak}})});\n    }\n    function rptRenderClusterOverlay() { rptActiveThreshold('cluster'); }\n    function rptRenderHostOverlay() { rptActiveThreshold('host'); }\n    function rptRenderTable() { rptPagedTable('rptClusterBreakdownTable',rptClusterRows(),'cluster','Per-cluster breakdown');rptPagedTable('rptHostBreakdownTable',rptAllHostRows(),'host','Per-host breakdown'); }\n    function rptBindOnce() {\n        if(rptBound)return;rptBound=true;\n        ['rptClusterThresholdInput','rptClusterPersistInput'].forEach(function(id){rptEl(id).addEventListener('change',function(){if(RPT)rptRenderClusterOverlay()})});\n        ['rptThresholdInput','rptPersistInput'].forEach(function(id){rptEl(id).addEventListener('change',function(){if(RPT)rptRenderHostOverlay()})});\n        ['rptDurationThreshold','rptDurationPercent','rptDurationTarget'].forEach(function(id){rptEl(id).addEventListener('change',function(){if(RPT)rptRenderDuration()})});\n        rptEl('rptDurationKind').addEventListener('change',function(){rptDurationPage=0;rptRenderDuration()});\n        rptEl('rptDurationPrev').onclick=function(){rptDurationPage--;rptRenderDuration()};rptEl('rptDurationNext').onclick=function(){rptDurationPage++;rptRenderDuration()};\n        var timer;rptEl('rptDurationSearch').addEventListener('input',function(){clearTimeout(timer);timer=setTimeout(function(){rptDurationPage=0;rptRenderDuration()},150)});\n        rptEl('rptTenantSelectAll').addEventListener('click',function(e){e.preventDefault();document.querySelectorAll('#rptTenantChecks input').forEach(function(c){c.checked=true});rptOnTenantChange()});\n        rptEl('rptTenantSelectNone').addEventListener('click',function(e){e.preventDefault();document.querySelectorAll('#rptTenantChecks input').forEach(function(c){c.checked=false});rptOnTenantChange()});\n    }\n    function rptDurationStats(series,threshold,share) {\n        if(!series || series.v.length\u003c2)return null;\n        var values=series.v.filter(rptFinite).slice().sort(function(a,b){return b-a});if(values.length\u003c2)return null;\n        var peak=values[0],same=0,above=0;values.forEach(function(v){if(Math.abs(v-peak)\u003c1e-9)same++;if(v\u003e=threshold)above++});\n        var p=Math.max(0,Math.min(100,share)),index=Math.max(0,Math.min(values.length-1,Math.ceil(values.length*p/100)-1));\n        return {values:values,peak:peak,peakShare:same/values.length*100,aboveShare:above/values.length*100,level:values[index],share:p};\n    }\n    function rptSelectDuration(kind,id) {\n        rptEl('rptDurationKind').value=kind;rptEl('rptDurationSearch').value='';rptDurationPage=0;\n        var targets=rptDurationTargets(kind),index=targets.findIndex(function(t){return String(t.id)===String(id)});\n        if(index\u003e=0)rptDurationPage=Math.floor(index/100);\n        rptRenderDuration(id);var section=rptEl('rptDurationSection');if(section) section.scrollIntoView({behavior:'smooth',block:'start'});\n    }\n    function rptDurationTargets(kind) {\n        var rows=kind==='host'?rptAllHostRows().filter(function(h){return h.hasHistory && h.id!==null}):rptClusterRows().filter(function(h){return h.hasHistory});\n        return rows.sort(function(a,b){return (rptFinite(b.avg)?b.avg:-Infinity)-(rptFinite(a.avg)?a.avg:-Infinity)||rptCollator.compare(a.host||a.cluster,b.host||b.cluster)}).map(function(r){return {id:kind==='host'?r.id:r.cluster,label:kind==='host'?r.host+' ('+r.cluster+')':r.cluster}});\n    }\n    function rptRenderDuration(preferred) {\n        var kind=rptEl('rptDurationKind').value==='cluster'?'cluster':'host',sel=rptEl('rptDurationTarget'),old=preferred!==undefined&&typeof preferred!=='object'?String(preferred):sel.value;\n        var q=rptEl('rptDurationSearch').value.toLowerCase().trim(),targets=RPT.hasSeries?rptDurationTargets(kind).filter(function(t){return !q||t.label.toLowerCase().indexOf(q)\u003e=0}):[];\n        var pages=Math.max(1,Math.ceil(targets.length/100));rptDurationPage=Math.max(0,Math.min(pages-1,rptDurationPage));var visible=targets.slice(rptDurationPage*100,rptDurationPage*100+100);sel.textContent='';\n        visible.forEach(function(t){var o=document.createElement('option');o.value=t.id;o.textContent=t.label;sel.appendChild(o)});\n        if(visible.some(function(t){return String(t.id)===old}))sel.value=old;\n        sel.disabled=!visible.length;rptEl('rptDurationPrev').disabled=rptDurationPage===0;rptEl('rptDurationNext').disabled=rptDurationPage\u003e=pages-1;\n        rptEl('rptDurationCount').textContent=targets.length?(rptDurationPage*100+1)+'\u2013'+(rptDurationPage*100+visible.length)+' of '+fmtInt(targets.length)+' targets; search or page for any host/cluster':'No historical targets in this scope';\n        var thr=Math.max(0,Math.min(100,Number(rptEl('rptDurationThreshold').value))),share=Math.max(0,Math.min(100,Number(rptEl('rptDurationPercent').value)));rptEl('rptDurationThreshold').value=thr;rptEl('rptDurationPercent').value=share;\n        var series=sel.disabled?null:kind==='host'?RPT.HOSTACTIVE.seriesOf(Number(sel.value)):RPT.ACTIVE.series[sel.value],stats=rptDurationStats(series,thr,share),card=rptEl('rptDurationCard'),tip=rptEl('rptDurationTooltip');\n        card.querySelectorAll('svg, .rpt-duration-empty').forEach(function(n){n.remove()});tip.style.display='none';\n        card.style.display=stats?'block':'none';\n        if(!stats){rptEl('rptDurationSummary').textContent='Peak duration is unavailable: at least two observed historical intervals are required. A snapshot or summary-only CSV cannot establish how long a peak lasted.';return}\n        rptEl('rptDurationSummary').textContent='Highest charted interval: '+rptFmtPercent(stats.peak)+'; intervals at that level: '+rptFmtPercent(stats.peakShare)+'. Active \u2265 '+thr+'% in '+rptFmtPercent(stats.aboveShare)+' of observed intervals. The busiest '+share+'% of intervals reached at least '+rptFmtPercent(stats.level)+'. '+fmtInt(stats.values.length)+' retained intervals.';\n        var W=960,H=320,M={left:66,right:18,top:22,bottom:52},pw=W-M.left-M.right,ph=H-M.top-M.bottom,yMax=niceTicks(0,Math.max(stats.peak,thr,1),5).slice(-1)[0];\n        function x(v){return M.left+v/100*pw}function y(v){return M.top+ph-v/yMax*ph}\n        var svg=svgEl('svg',{viewBox:'0 0 '+W+' '+H,role:'img','aria-label':'Active-memory duration: share of observed retained chart intervals','class':'overlay-svg'});\n        niceTicks(0,yMax,5).forEach(function(v){svg.appendChild(svgEl('line',{x1:M.left,x2:W-M.right,y1:y(v),y2:y(v),'class':'grid-line'}));var t=svgEl('text',{x:M.left-8,y:y(v)+4,'text-anchor':'end','class':'axis-label'});t.textContent=fmt(v,0)+'%';svg.appendChild(t)});\n        [0,10,25,50,75,90,100].forEach(function(v){var t=svgEl('text',{x:x(v),y:H-M.bottom+19,'text-anchor':'middle','class':'axis-label'});t.textContent=v+'%';svg.appendChild(t)});\n        // Lossless step runs: include each distinct charted value without one SVG node per observation.\n        var points=x(0)+','+y(stats.values[0]),n=stats.values.length;\n        for(var i=0;i\u003cn;i++){if(i===n-1 || stats.values[i+1]!==stats.values[i]){var pct=(i+1)/n*100;points+=' '+x(pct)+','+y(stats.values[i]);if(i+1\u003cn)points+=' '+x(pct)+','+y(stats.values[i+1])}}\n        svg.appendChild(svgEl('polyline',{points:points,fill:'none',style:'stroke:var(--series-1);stroke-width:2'}));\n        svg.appendChild(svgEl('line',{x1:M.left,x2:W-M.right,y1:y(thr),y2:y(thr),'stroke-dasharray':'6,4',style:'stroke:#c25400;stroke-width:2'}));\n        svg.appendChild(svgEl('line',{x1:x(share),x2:x(share),y1:M.top,y2:H-M.bottom,'stroke-dasharray':'4,4',style:'stroke:#7765b9;stroke-width:1.5'}));\n        addAxisTitles(svg,W,H,M,pw,ph,'Share of observed intervals at or above this level','Active memory %');\n        var hit=svgEl('rect',{x:M.left,y:M.top,width:pw,height:ph,fill:'transparent'});svg.appendChild(hit);\n        hit.addEventListener('pointermove',function(e){var pt=svg.createSVGPoint();pt.x=e.clientX;pt.y=e.clientY;var p=pt.matrixTransform(svg.getScreenCTM().inverse()),pct=Math.max(0,Math.min(100,(p.x-M.left)/pw*100)),idx=Math.max(0,Math.min(n-1,Math.ceil(pct/100*n)-1));tip.textContent='Busiest '+fmt(pct,1)+'% of observed intervals: Active \u2265 '+fmt(stats.values[idx],2)+'%';var box=card.getBoundingClientRect();tip.style.display='block';tip.style.left=Math.max(5,e.clientX-box.left+10)+'px';tip.style.top=Math.max(5,e.clientY-box.top-32)+'px'});\n        hit.addEventListener('pointerleave',function(){tip.style.display='none'});card.insertBefore(svg,tip);\n    }\n    function rptRenderAll() {\n        rptEl('rptSource').textContent = RPT.source;\n        rptSyncViewMode();\n        rptRenderTenantFilter();\n        var f = rptFilteredOverall();\n        rptRenderKpis(f.totalHosts, f.totalClusters, f.overall);\n        rptRenderHistograms();\n        rptRenderClusterOverlay();\n        rptRenderHostOverlay();\n        rptRenderTable();\n        rptRenderDuration();\n        rptEl('rptFooter').textContent = (RPT.isRvtools\n            ? 'RVTools inventory snapshots. Values are decimal GB. Multiple sources and clusters are included in fleet scope; each cluster uses its last selected snapshot. Historical peaks, tiering state and VM eligibility are not established by an inventory snapshot.'\n            : RPT.isOps\n            ? \"Operations API data: true consumed memory and retained active-memory samples, converted to decimal GB. Peaks are maxima of retained aggregates. Charts use bounded retained-sample intervals; summary averages use all retained samples. Missing configuration or history blocks qualification and savings; inspect Tab 2 notes.\"\n            : RPT.isVrops\n            ? (\"Generated from Operations host workbooks. Memory is decimal GB. \" + (RPT.consumedBasis === 'actual' ? \"Consumed uses measured host consumed memory. \" : RPT.consumedBasis === 'allocated' ? \"Consumed uses allocated VM memory as a proxy. \" : \"Consumed uses measured memory where supplied, allocated memory where marked as a proxy, and leaves unavailable metrics unknown. \") + \"CPU utilization and CPU core utilization are separate measurements; unavailable counters show n/a. Host exports do not establish VM eligibility or physical tier breakdown.\")\n            : \"Generated from MTAT's live vCenter analysis (mem.active, mem.consumed, cpu.usage). Capacity is host physical DRAM. Provisioned % is memory configured on powered-on VMs as a % of DRAM. CPU util is cpu.usage; CPU core util is not collected and shows as n/a.\") +\n            (RPT.hasSeries ? \" Chart intervals follow retained data and the collection budget; cluster lines average hosts observed in each chart interval.\" : \" This data source has one value per host, so the over-time charts have no timeline to draw; their tables still list everything at or above the thresholds.\");\n    }\n    function rptFilteredOverall() {\n        var D = RPT.DATA;\n        var included = D.clusters.filter(function(r) { return rptIncluded(r.cluster); });\n        var totalHosts = included.reduce(function(s, r) { return s + r.hosts; }, 0);\n        if (!totalHosts) return { totalHosts: 0, totalClusters: 0, included: included, overall: { alloc_gb: 0, active_gb: 0, cap_gb: 0, prov_gb: 0, cpucore: null, cpuutil: null, activepct: 0, activepeak_gb: null, activepeakpct: null } };\n        function wmean(key) {\n            var withVal = included.filter(function(r) { return r[key] !== null; });\n            var n = withVal.reduce(function(s, r) { return s + r.hosts; }, 0);\n            return n ? withVal.reduce(function(s, r) { return s + r[key] * r.hosts; }, 0) / n : null;\n        }\n        var peakGB = included.reduce(function(sum, c) { return sum + c.activepeak; }, 0);\n        var capGB = included.reduce(function(sum, c) { return sum + c.capacityTotal; }, 0);\n        return { totalHosts: totalHosts, totalClusters: included.length, included: included, overall: {\n            activepeak_gb: peakGB, activepeakpct: capGB \u003e 0 ? peakGB / capGB * 100 : null,\n            alloc_gb: wmean(\"alloc\"), active_gb: wmean(\"active\"), cap_gb: wmean(\"cap\"), prov_gb: wmean(\"prov\"),\n            cpucore: wmean(\"cpucore\"), cpuutil: wmean(\"cpuutil\"), activepct: wmean(\"activepct\") } };\n    }\n    function rptRenderKpis(totalHosts, totalClusters, overall) {\n        var hosts=rptAllHostRows(),clusters=rptClusterRows(),known=hosts.filter(function(h){return rptFinite(h.avg)}),avg=known.length?known.reduce(function(n,h){return n+h.avg},0)/known.length:null;\n        var peak=hosts.reduce(function(n,h){return rptFinite(h.peak)?Math.max(n,h.peak):n},-Infinity);\n        var kpis=[{label:'Hosts in scope',value:fmtInt(hosts.length),unit:''},{label:'Clusters in scope',value:fmtInt(clusters.length),unit:''},{label:'Avg Active % (available hosts)',value:avg===null?'n/a':fmt(avg,1),unit:avg===null?'':'%'},{label:'Highest reported peak / snapshot %',value:peak===-Infinity?'n/a':fmt(peak,1),unit:peak===-Infinity?'':'%'},{label:'Hosts with active measurements',value:fmtInt(known.length),unit:'of '+fmtInt(hosts.length)}];\n        var row = rptEl('rptKpiRow'); row.innerHTML = \"\";\n        kpis.forEach(function(k) {\n            var tile = document.createElement(\"div\"); tile.className = \"stat-tile\";\n            var l = document.createElement(\"div\"); l.className = \"label\"; l.textContent = k.label;\n            var v = document.createElement(\"div\"); v.className = \"value\"; v.appendChild(document.createTextNode(k.value));\n            if (k.unit) { var u = document.createElement(\"span\"); u.className = \"unit\"; u.textContent = k.unit; v.appendChild(u); }\n            tile.appendChild(l); tile.appendChild(v); row.appendChild(tile);\n        });\n    }\n    function rptRenderTenantFilter() {\n        var box = rptEl('rptTenantFilter'), checks = rptEl('rptTenantChecks');\n        checks.innerHTML = \"\";\n        if (!RPT.TENANT) { box.style.display = \"none\"; return; }\n        var D = RPT.DATA, counts = {};\n        D.clusters.forEach(function(r) { var t = rptTenantOf(r.cluster); counts[t] = (counts[t] || 0) + 1; });\n        Object.keys(counts).sort().forEach(function(t) {\n            var label = document.createElement(\"label\"); label.className = \"tenant-chip\";\n            var cb = document.createElement(\"input\"); cb.type = \"checkbox\"; cb.checked = !RPT.excludedTenants.has(t); cb.dataset.tenant = t;\n            cb.addEventListener(\"change\", rptOnTenantChange);\n            label.appendChild(cb); label.appendChild(document.createTextNode(\" \" + t + \" \"));\n            var c = document.createElement(\"span\"); c.className = \"tenant-chip-count\"; c.textContent = \"(\" + fmtInt(counts[t]) + \")\";\n            label.appendChild(c); checks.appendChild(label);\n        });\n        var unmapped = D.clusters.filter(function(r) { return !(r.cluster in RPT.TENANT.cluster_tenant); }).length;\n        rptEl('rptTenantFilterNote').textContent = unmapped\n            ? \"Tenant mapping from \" + RPT.TENANT.source_file + \" (sheet '\" + RPT.TENANT.source_sheet + \"'): \" + fmtInt(unmapped) + \" of \" + fmtInt(D.total_clusters) + \" clusters had no entry and are grouped under \\\"\" + RPT_UNMAPPED + \"\\\".\"\n            : \"Tenant mapping from \" + RPT.TENANT.source_file + \" (sheet '\" + RPT.TENANT.source_sheet + \"').\";\n        box.style.display = \"\";\n        rptUpdateTenantCount();\n    }\n    function rptUpdateTenantCount() {\n        var f = rptFilteredOverall(), D = RPT.DATA;\n        rptEl('rptTenantFilterCount').textContent = fmtInt(f.totalClusters) + \" of \" + fmtInt(D.total_clusters) + \" clusters \\u00b7 \" + fmtInt(f.totalHosts) + \" of \" + fmtInt(D.total_hosts) + \" hosts included\";\n    }\n    function rptOnTenantChange() {\n        RPT.excludedTenants.clear();\n        document.querySelectorAll(\"#rptTenantChecks input[type=checkbox]\").forEach(function(cb) {\n            cb.closest(\".tenant-chip\").classList.toggle(\"excluded\", !cb.checked);\n            if (!cb.checked) RPT.excludedTenants.add(cb.dataset.tenant);\n        });\n        var f = rptFilteredOverall();\n        rptRenderKpis(f.totalHosts, f.totalClusters, f.overall);\n        rptRenderHistograms(); rptRenderClusterOverlay(); rptRenderHostOverlay(); rptRenderTable(); rptRenderDuration();\n        rptUpdateTenantCount();\n    }\n    function rptRenderHistogram(edges, counts, cardId, tooltipId, xLabel) {\n        var card = rptEl(cardId), tip = rptEl(tooltipId), n = counts.length, labels = [];\n        for (var i = 0; i \u003c n; i++) labels.push(edges[i] + \"\\u2013\" + edges[i + 1] + \"%\");\n        var W = 960, H = 320, M = { left: 58, right: 16, top: 14, bottom: 46 }, plotW = W - M.left - M.right, plotH = H - M.top - M.bottom;\n        var yTicks = niceTicks(0, Math.max.apply(null, counts.concat([1])), 4), yMax = yTicks[yTicks.length - 1];\n        var svg = svgEl(\"svg\", { viewBox: \"0 0 \" + W + \" \" + H, \"class\": \"hist-svg\", role: \"img\", \"aria-label\": \"Histogram of active memory percent across hosts\" });\n        yTicks.forEach(function(t) {\n            var y = M.top + plotH - (t / yMax) * plotH;\n            svg.appendChild(svgEl(\"line\", { x1: M.left, x2: W - M.right, y1: y, y2: y, \"class\": \"grid-line\" }));\n            var l = svgEl(\"text\", { x: M.left - 8, y: y + 3, \"class\": \"axis-label\", \"text-anchor\": \"end\" }); l.textContent = fmtInt(t); svg.appendChild(l);\n        });\n        svg.appendChild(svgEl(\"line\", { x1: M.left, x2: M.left, y1: M.top, y2: M.top + plotH, \"class\": \"axis-line\" }));\n        svg.appendChild(svgEl(\"line\", { x1: M.left, x2: W - M.right, y1: M.top + plotH, y2: M.top + plotH, \"class\": \"axis-line\" }));\n        var gap = 3, barW = plotW / n - gap;\n        function showTip(evt, i) {\n            var box = card.getBoundingClientRect();\n            tip.innerHTML = \"\";\n            var l1 = document.createElement(\"div\"); l1.className = \"tt-label\"; l1.textContent = labels[i];\n            var l2 = document.createElement(\"div\"), strong = document.createElement(\"span\"); strong.className = \"tt-value\"; strong.textContent = fmtInt(counts[i]);\n            l2.appendChild(strong); l2.appendChild(document.createTextNode(\" hosts\"));\n            tip.appendChild(l1); tip.appendChild(l2); tip.style.display = \"block\";\n            tip.style.left = (evt.clientX - box.left + 12) + \"px\"; tip.style.top = (evt.clientY - box.top - 36) + \"px\";\n        }\n        for (var b = 0; b \u003c n; b++) {\n            (function(i) {\n                var x = M.left + i * (plotW / n) + gap / 2, h = (counts[i] / yMax) * plotH;\n                var rect = svgEl(\"rect\", { x: x, y: M.top + plotH - h, width: Math.max(1, barW), height: Math.max(0, h), rx: 3, \"class\": \"hist-bar\" });\n                rect.addEventListener(\"pointermove\", function(e) { showTip(e, i); });\n                rect.addEventListener(\"pointerleave\", function() { tip.style.display = \"none\"; });\n                svg.appendChild(rect);\n            })(b);\n        }\n        for (var e = 0; e \u003c= n; e++) {\n            if (edges[e] % 5 !== 0) continue;\n            var lbl = svgEl(\"text\", { x: M.left + e * (plotW / n), y: M.top + plotH + 16, \"class\": \"axis-label\", \"text-anchor\": \"middle\" }); lbl.textContent = edges[e] + \"%\"; svg.appendChild(lbl);\n        }\n        addAxisTitles(svg, W, H, M, plotW, plotH, xLabel, \"Number of hosts\");\n        card.querySelectorAll(\".hist-chart-wrap\").forEach(function(w) { w.remove(); });\n        var wrap = document.createElement(\"div\"); wrap.className = \"hist-chart-wrap\"; wrap.style.position = \"relative\"; wrap.appendChild(svg);\n        card.insertBefore(wrap, tip);\n    }\n    function rptHistFromByCluster(byCluster, nBins) {\n        var counts = []; for (var i = 0; i \u003c nBins; i++) counts.push(0);\n        for (var c in byCluster) { if (!rptIncluded(c)) continue; var arr = byCluster[c]; for (var j = 0; j \u003c arr.length; j++) counts[j] += arr[j]; }\n        return counts;\n    }\n    function rptRenderHistograms() {\n        var A = RPT.ACTIVE, span = \"\";\n        if (RPT.dateStart) {\n            var days = Math.round((new Date(RPT.dateEnd + \"T00:00:00Z\") - new Date(RPT.dateStart + \"T00:00:00Z\")) / 86400000);\n            span = \" (up to \" + Math.max(1, days) + \" day\" + (days === 1 ? \"\" : \"s\") + \": \" + RPT.dateStart + \" to \" + RPT.dateEnd + \")\";\n        }\n        rptEl('rptHistAvgSubhead').textContent = \"Time-averaged active % \\u00b7 mean over each host's full window\" + span;\n        rptEl('rptHistPeakSubhead').textContent = RPT.hasSeries\n            ? \"Peak active % \\u00b7 reported host peak, before chart bucketing\" + span\n            : \"Peak active % \\u00b7 reported host peak or snapshot value; no timeline supplied\";\n        rptRenderHistogram(RPT_AVG_EDGES, rptHistFromByCluster(A.hist_avg_by_cluster, RPT_AVG_EDGES.length - 1), \"rptHistCardAvg\", \"rptHistTooltipAvg\", \"Active memory % \\u00b7 time-averaged (per host)\");\n        rptRenderHistogram(RPT_PEAK_EDGES, rptHistFromByCluster(A.hist_peak_by_cluster, RPT_PEAK_EDGES.length - 1), \"rptHistCardPeak\", \"rptHistTooltipPeak\", \"Active memory % \\u00b7 peak (per host)\");\n    }\n    function rptTimelineItems(metas, seriesOf, labelOf) {\n        var items = [];\n        metas.forEach(function(m) {\n            var series = seriesOf(m);\n            if (!series || !series.h.length || !series.v.length) return;\n            items.push({ name: labelOf(m), s: series, peak: Math.max.apply(null, series.v) });\n        });\n        return items;\n    }\n    function rptRenderOverlay(opts) {\n        var card = rptEl(opts.card), tip = rptEl(opts.tooltip);\n        card.querySelectorAll(\"svg, .rpt-no-timeline\").forEach(function(s) { s.remove(); });\n        tip.style.display = \"none\"; tip.classList.remove(\"pinned\"); tip.innerHTML = \"\";\n        var items = opts.items;\n        card.style.setProperty(\"--overlay-opacity\", Math.max(0.05, Math.min(0.6, 40 / Math.max(1, items.length))));\n        var W = 960, H = 360, M = { left: 58, right: 16, top: 14, bottom: 46 }, plotW = W - M.left - M.right, plotH = H - M.top - M.bottom;\n        var svg = svgEl(\"svg\", { viewBox: \"0 0 \" + W + \" \" + H, \"class\": \"overlay-svg\", role: \"img\", \"aria-label\": items.length + \" lines over time; threshold \" + opts.threshold + \"%\" });\n        var maxH = 0;\n        items.forEach(function(it) { if (it.s.h.length) maxH = Math.max(maxH, it.s.h[it.s.h.length - 1]); });\n        if (opts.population && opts.population.length && !rptUseTimeline(RPT)) {\n            rptRenderSnapshotHeat(card, tip, opts); return;\n        }\n        if (!items.length) {\n            var empty = svgEl(\"text\", { x: W / 2, y: H / 2, \"class\": \"chart-empty\" });\n            empty.textContent = opts.emptyText;\n            svg.appendChild(empty); card.insertBefore(svg, tip); return;\n        }\n        if (maxH \u003c= 0) maxH = 1;\n        var vMax = 0; items.forEach(function(it) { vMax = Math.max(vMax, opts.peakOf(it)); });\n        var yTicks = niceTicks(0, Math.max(vMax, opts.threshold, 1), 5), yHi = yTicks[yTicks.length - 1];\n        function xScale(h) { return M.left + (h / maxH) * plotW; }\n        function yScale(v) { return M.top + plotH - (v / yHi) * plotH; }\n        yTicks.forEach(function(t) {\n            svg.appendChild(svgEl(\"line\", { x1: M.left, x2: W - M.right, y1: yScale(t), y2: yScale(t), \"class\": \"grid-line\" }));\n            var l = svgEl(\"text\", { x: M.left - 8, y: yScale(t) + 3, \"class\": \"axis-label\", \"text-anchor\": \"end\" }); l.textContent = fmt(t, 0) + \"%\"; svg.appendChild(l);\n        });\n        svg.appendChild(svgEl(\"line\", { x1: M.left, x2: M.left, y1: M.top, y2: M.top + plotH, \"class\": \"axis-line\" }));\n        svg.appendChild(svgEl(\"line\", { x1: M.left, x2: W - M.right, y1: M.top + plotH, y2: M.top + plotH, \"class\": \"axis-line\" }));\n        function dateOf(h) { return new Date(opts.baseMs + h * RPT_HOUR_MS); }\n        function fmtDate(d) { return d.toISOString().slice(0,maxH\u003c=48?16:10).replace('T',' ') + (maxH\u003c=48?' UTC':''); }\n        [0, maxH / 2, maxH].forEach(function(h, i) {\n            var l = svgEl(\"text\", { x: xScale(h), y: M.top + plotH + 16, \"class\": \"axis-label\", \"text-anchor\": i === 0 ? \"start\" : (i === 2 ? \"end\" : \"middle\") });\n            l.textContent = fmtDate(dateOf(h)); svg.appendChild(l);\n        });\n        addAxisTitles(svg, W, H, M, plotW, plotH, \"Date\", opts.yLabel);\n\n        var lines = [];\n        items.forEach(function(it) {\n            if (!it.s.h.length) return;\n            var pts = \"\";\n            for (var i = 0; i \u003c it.s.h.length; i++) pts += xScale(it.s.h[i]) + \",\" + yScale(it.s.v[i]) + \" \";\n            var pl = svgEl(\"polyline\", { points: pts.trim(), \"class\": \"overlay-line\" });\n            svg.appendChild(pl); lines.push({ el: pl, it: it });\n            if (it.s.h.length === 1) svg.appendChild(svgEl('circle',{cx:xScale(it.s.h[0]),cy:yScale(it.s.v[0]),r:2.5,style:'fill:var(--series-1)'}));\n        });\n        svg.appendChild(svgEl('line', {x1:M.left,x2:W-M.right,y1:yScale(opts.threshold),y2:yScale(opts.threshold),'class':'threshold-line','stroke-dasharray':'6,4',style:'stroke:#c25400;stroke-width:2'}));\n        var thresholdLabel = svgEl('text',{x:W-M.right-4,y:Math.max(12,yScale(opts.threshold)-6),'text-anchor':'end','class':'threshold-label',style:'fill:#c25400;font-size:12px;font-weight:600'});\n        thresholdLabel.textContent = opts.threshold + '% threshold'; svg.appendChild(thresholdLabel);\n        var hit = svgEl(\"rect\", { x: M.left, y: M.top, width: plotW, height: plotH, fill: \"transparent\" });\n        svg.appendChild(hit);\n        var cur = null, pinned = false;\n        function unpin() { pinned = false; tip.classList.remove(\"pinned\"); tip.style.display = \"none\"; if (cur) { cur.classList.remove(\"emphasis\"); cur = null; } }\n        function pin() {\n            pinned = true; tip.classList.add(\"pinned\");\n            var x = document.createElement(\"span\"); x.className = \"tt-close\"; x.textContent = \"\\u2715\";\n            x.addEventListener(\"click\", function(e) { e.stopPropagation(); unpin(); }); tip.appendChild(x);\n        }\n        hit.addEventListener(\"click\", function() { if (pinned) unpin(); else pin(); });\n        hit.addEventListener(\"pointermove\", function(evt) {\n            if (pinned) return;\n            var pt = svg.createSVGPoint(); pt.x = evt.clientX; pt.y = evt.clientY;\n            var p = pt.matrixTransform(svg.getScreenCTM().inverse());\n            var hoverH = ((p.x - M.left) / plotW) * maxH, hoverV = yHi - ((p.y - M.top) / plotH) * yHi;\n            var best = null, bestDist = Infinity, entries = [];\n            lines.forEach(function(line) {\n                var idx = nearestIdxGeneric(line.it.s.h, hoverH), v = line.it.s.v[idx];\n                entries.push({ name: line.it.name, value: v });\n                var d = Math.abs(v - hoverV); if (d \u003c bestDist) { bestDist = d; best = { line: line, idx: idx }; }\n            });\n            if (!best) return;\n            if (cur && cur !== best.line.el) cur.classList.remove(\"emphasis\");\n            best.line.el.classList.add(\"emphasis\"); cur = best.line.el;\n            var hh = best.line.it.s.h[best.idx], x = xScale(hh), y = yScale(best.line.it.s.v[best.idx]);\n            var cardBox = card.getBoundingClientRect(), svgBox = svg.getBoundingClientRect(), sc = svgBox.width / W;\n            var header = fmtDate(dateOf(hh)) + \" \" + dateOf(hh).getHours() + \":00 \\u00b7 \" + entries.length + \" \" + opts.unit + (entries.length === 1 ? \"\" : \"s\") + (opts.headerSuffix || \"\");\n            renderMultiTooltip(tip, header, entries, best.line.it.name, 30);\n            tip.style.display = \"block\";\n            tip.style.left = (svgBox.left - cardBox.left + x * sc + 12) + \"px\";\n            tip.style.top = (svgBox.top - cardBox.top + y * sc - 46) + \"px\";\n        });\n        hit.addEventListener(\"pointerleave\", function(evt) {\n            if (pinned || tip.contains(evt.relatedTarget)) return;\n            if (cur) { cur.classList.remove(\"emphasis\"); cur = null; } tip.style.display = \"none\";\n        });\n        tip.onpointerleave = function(evt) {\n            if (pinned || hit.contains(evt.relatedTarget)) return;\n            if (cur) { cur.classList.remove(\"emphasis\"); cur = null; } tip.style.display = \"none\";\n        };\n        card.insertBefore(svg, tip);\n    }\n    function rptRenderSnapshotHeat(card, tip, opts) {\n        var edges = opts.heatEdges || RPT_HEAT_EDGES, nb = edges.length - 1, unit = opts.unit, thr = opts.threshold;\n        var groups = {}, order = [];\n        opts.population.forEach(function(p) {\n            var g = RPT.TENANT ? rptTenantOf(p.cluster) : (\"All \" + unit + \"s\");\n            if (!groups[g]) { groups[g] = []; for (var i = 0; i \u003c nb; i++) groups[g].push([]); order.push(g); }\n            var b = 0; while (b \u003c nb - 1 && p.value \u003e= edges[b + 1]) b++;\n            groups[g][b].push(p);\n        });\n        order.sort(function(a, b) { var na = groups[a].reduce(function(s, c) { return s + c.length; }, 0), nb2 = groups[b].reduce(function(s, c) { return s + c.length; }, 0); return nb2 - na; });\n        var maxCount = 1;\n        order.forEach(function(g) { groups[g].forEach(function(c) { if (c.length \u003e maxCount) maxCount = c.length; }); });\n        var labelW = 150, cellW = Math.max(40, Math.floor((960 - labelW - 16) / nb)), cellH = 30, top = 34, W = labelW + cellW * nb + 16, H = top + cellH * order.length + 46;\n        var svg = svgEl(\"svg\", { viewBox: \"0 0 \" + W + \" \" + H, \"class\": \"overlay-svg\", role: \"img\", \"aria-label\": \"Matrix of \" + unit + \"s by memory-percent band\" });\n        function bandLabel(b) { return edges[b + 1] === Infinity ? edges[b] + \"%+\" : edges[b] + \"\\u2013\" + edges[b + 1] + \"%\"; }\n        for (var b = 0; b \u003c nb; b++) {\n            var lx = svgEl(\"text\", { x: labelW + b * cellW + cellW / 2, y: top - 10, \"class\": \"axis-label\", \"text-anchor\": \"middle\" }); lx.textContent = bandLabel(b); svg.appendChild(lx);\n        }\n        var cells = [];\n        order.forEach(function(g, gi) {\n            var y = top + gi * cellH;\n            var gl = svgEl(\"text\", { x: labelW - 10, y: y + cellH / 2 + 4, \"class\": \"axis-label-strong\", \"text-anchor\": \"end\" }); gl.textContent = g.length \u003e 22 ? g.slice(0, 21) + \"\\u2026\" : g; svg.appendChild(gl);\n            for (var b2 = 0; b2 \u003c nb; b2++) {\n                var list = groups[g][b2], n = list.length, x = labelW + b2 * cellW, atOrAbove = edges[b2] \u003e= thr;\n                var op = n ? (0.18 + 0.82 * Math.sqrt(n / maxCount)) : 0;\n                var rect = svgEl(\"rect\", { x: x + 1, y: y + 1, width: cellW - 2, height: cellH - 2, rx: 2,\n                    fill: n ? \"var(--series-1)\" : \"var(--gridline)\", \"fill-opacity\": n ? op.toFixed(2) : 0.35,\n                    stroke: atOrAbove ? \"#c25400\" : \"none\", \"stroke-width\": atOrAbove ? 1.5 : 0, style: \"cursor:\" + (n ? \"pointer\" : \"default\") });\n                svg.appendChild(rect);\n                if (n) { var ct = svgEl(\"text\", { x: x + cellW / 2, y: y + cellH / 2 + 4, \"text-anchor\": \"middle\", \"class\": \"axis-label\", style: \"fill:\" + (op \u003e 0.55 ? \"#ffffff\" : \"var(--text-primary)\") + \"; font-weight:600; pointer-events:none;\" }); ct.textContent = fmtInt(n); svg.appendChild(ct); }\n                cells.push({ rect: rect, group: g, band: b2, list: list });\n            }\n        });\n        var thrBand = 0; while (thrBand \u003c nb && edges[thrBand] \u003c thr) thrBand++;\n        if (thrBand \u003c nb) {\n            var tx = labelW + thrBand * cellW;\n            svg.appendChild(svgEl(\"line\", { x1: tx, x2: tx, y1: top - 4, y2: top + cellH * order.length + 4, stroke: \"#c25400\", \"stroke-width\": 2, \"stroke-dasharray\": \"4,3\" }));\n            var tl = svgEl(\"text\", { x: tx + 4, y: top + cellH * order.length + 20, \"class\": \"axis-label\", style: \"fill:#c25400; font-weight:600;\" }); tl.textContent = \"\\u2265 \" + thr + \"% threshold\"; svg.appendChild(tl);\n        }\n        var xt = svgEl(\"text\", { x: labelW + (cellW * nb) / 2, y: H - 6, \"class\": \"axis-label-strong\", \"text-anchor\": \"middle\" }); xt.textContent = (opts.heatLabel || \"Active memory %\") + \" band, \" + unit + \"s per cell\"; svg.appendChild(xt);\n        var note = document.createElement(\"div\"); note.className = \"rpt-no-timeline\"; note.style.padding = \"0 0 10px 0\"; note.style.textAlign = \"left\";\n        note.textContent = \"This matrix shows how many \" + unit + \"s sit in each peak/snapshot band\" + (RPT.TENANT ? \", per tenant\" : \"\") + \". Outlined cells are at or above the threshold. Hover a cell for details, click to pin.\";\n        card.insertBefore(note, tip); card.insertBefore(svg, tip);\n        var pinned = false;\n        function show(evt, c) {\n            var sorted = c.list.slice().sort(function(a, b) { return b.value - a.value; });\n            renderMultiTooltip(tip, c.group + \" \\u00b7 \" + bandLabel(c.band) + \" \\u00b7 \" + fmtInt(c.list.length) + \" \" + unit + (c.list.length === 1 ? \"\" : \"s\"), sorted.map(function(p) { return { name: p.name, value: p.value }; }), null, 30);\n            var cb = card.getBoundingClientRect();\n            tip.style.display = \"block\"; tip.style.left = (evt.clientX - cb.left + 14) + \"px\"; tip.style.top = (evt.clientY - cb.top - 30) + \"px\";\n        }\n        cells.forEach(function(c) {\n            if (!c.list.length) return;\n            c.rect.addEventListener(\"pointermove\", function(e) { if (!pinned) show(e, c); });\n            c.rect.addEventListener(\"pointerleave\", function(e) { if (!pinned && !tip.contains(e.relatedTarget)) tip.style.display = \"none\"; });\n            c.rect.addEventListener(\"click\", function(e) {\n                if (pinned) { pinned = false; tip.classList.remove(\"pinned\"); tip.style.display = \"none\"; return; }\n                show(e, c); pinned = true; tip.classList.add(\"pinned\");\n                var x = document.createElement(\"span\"); x.className = \"tt-close\"; x.textContent = \"\\u2715\";\n                x.addEventListener(\"click\", function(ev) { ev.stopPropagation(); pinned = false; tip.classList.remove(\"pinned\"); tip.style.display = \"none\"; });\n                tip.appendChild(x);\n            });\n        });\n        tip.onpointerleave = function(e) { if (!pinned) tip.style.display = \"none\"; };\n    }\n    function rptFillTable(bodyId, rows, alignLeftCols, secondaryCol) {\n        var frag = document.createDocumentFragment();\n        rows.forEach(function(cells) {\n            var tr = document.createElement(\"tr\");\n            cells.forEach(function(val, i) {\n                var td = document.createElement(\"td\"); td.textContent = val;\n                td.style.textAlign = i \u003c alignLeftCols ? \"left\" : \"right\"; td.style.fontVariantNumeric = \"tabular-nums\";\n                if (i === secondaryCol) td.style.color = \"var(--text-secondary)\";\n                tr.appendChild(td);\n            });\n            frag.appendChild(tr);\n        });\n        var body = rptEl(bodyId); body.innerHTML = \"\"; body.appendChild(frag);\n    }\n    function fmt(n, d) { return Number(n).toLocaleString(undefined, { minimumFractionDigits: d, maximumFractionDigits: d }); }\n    function fmtInt(n) { return Number(n).toLocaleString(); }\n    function fmtOrDash(v) { return (v === null || v === undefined) ? \"n/a\" : v; }\n    function escapeHtml(str) {\n        return String(str)\n            .replace(/&/g, '&amp;')\n            .replace(/\u003c/g, '&lt;')\n            .replace(/\u003e/g, '&gt;')\n            .replace(/\"/g, '&quot;')\n            .replace(/'/g, '&#39;');\n    }\n    function svgEl(tag, attrs) { var el = document.createElementNS(RPT_SVGNS, tag); for (var k in attrs) el.setAttribute(k, attrs[k]); return el; }\n    function niceStep(rough) {\n        var mag = Math.pow(10, Math.floor(Math.log10(rough))), norm = rough / mag;\n        return (norm \u003c= 1 ? 1 : norm \u003c= 2 ? 2 : norm \u003c= 5 ? 5 : 10) * mag;\n    }\n    function niceTicks(min, max, count) {\n        if (min === max) max = min + 1;\n        var step = niceStep((max - min) / count) || 1, ticks = [Math.floor(min / step) * step];\n        while (ticks[ticks.length - 1] \u003c max - step * 1e-9) ticks.push(Math.round((ticks[ticks.length - 1] + step) * 1000) / 1000);\n        return ticks;\n    }\n    function addAxisTitles(svg, W, H, M, plotW, plotH, xLabel, yLabel) {\n        if (xLabel) { var xt = svgEl(\"text\", { x: M.left + plotW / 2, y: H - 5, \"class\": \"axis-label-strong\", \"text-anchor\": \"middle\" }); xt.textContent = xLabel; svg.appendChild(xt); }\n        if (yLabel) { var cy = M.top + plotH / 2, yt = svgEl(\"text\", { x: 12, y: cy, \"class\": \"axis-label-strong\", \"text-anchor\": \"middle\", transform: \"rotate(-90 12 \" + cy + \")\" }); yt.textContent = yLabel; svg.appendChild(yt); }\n    }\n    function renderMultiTooltip(tooltipEl, header, entries, activeName, capN) {\n        capN = capN || 30;\n        var sorted = entries.slice().sort(function(a, b) { return b.value - a.value; });\n        tooltipEl.classList.add(\"tt-multi\"); tooltipEl.innerHTML = \"\";\n        var h = document.createElement(\"div\"); h.className = \"tt-label\"; h.textContent = header; tooltipEl.appendChild(h);\n        var list = document.createElement(\"div\"); list.className = \"tt-list\";\n        sorted.slice(0, capN).forEach(function(e) {\n            var row = document.createElement(\"div\"); row.className = \"tt-row\" + (e.name === activeName ? \" tt-row-active\" : \"\");\n            var n = document.createElement(\"span\"); n.className = \"tt-row-name\"; n.textContent = e.name;\n            var v = document.createElement(\"span\"); v.className = \"tt-row-val\"; v.textContent = fmt(e.value, 2) + \"%\";\n            row.appendChild(n); row.appendChild(v); list.appendChild(row);\n        });\n        tooltipEl.appendChild(list);\n        if (sorted.length \u003e capN) { var more = document.createElement(\"div\"); more.className = \"tt-more\"; more.textContent = \"+\" + (sorted.length - capN) + \" more not shown (sorted by value)\"; tooltipEl.appendChild(more); }\n    }\n    function nearestIdxGeneric(hArr, h) {\n        var lo = 0, hi = hArr.length - 1;\n        if (h \u003c= hArr[0]) return 0;\n        if (h \u003e= hArr[hi]) return hi;\n        while (lo \u003c hi) { var mid = (lo + hi) \u003e\u003e 1; if (hArr[mid] \u003c h) lo = mid + 1; else hi = mid; }\n        var a = hArr[lo - 1] !== undefined ? Math.abs(hArr[lo - 1] - h) : Infinity, b = Math.abs(hArr[lo] - h);\n        return a \u003c b ? lo - 1 : lo;\n    }\n    var dto=null;\n    function rptInitEmbeddedReport(data,preferences) {\n        try {\n            dto=data || JSON.parse(document.getElementById('rptInteractiveData').textContent);\n            RPT={DATA:dto.data,ACTIVE:dto.active,HOSTACTIVE:{base_ts_ms:dto.active.base_ts_ms,host_meta:dto.hosts.filter(function(h){return h.id!==null}),all_hosts:dto.hosts,seriesOf:function(id){return dto.series[id] || {h:[],v:[]}}},TENANT:dto.tenant,excludedTenants:new Set(preferences?preferences.excludedTenants:[]),hasSeries:dto.hasSeries,hasCpu:dto.hasCpu,isOps:dto.isOps,isVrops:dto.isVrops,isRvtools:dto.isRvtools,consumedBasis:dto.consumedBasis,source:dto.source,rangeLabel:dto.rangeLabel,dateStart:dto.dateStart,dateEnd:dto.dateEnd,opsTimelineEvidence:dto.opsTimelineEvidence};\n            rptTables=Object.create(null);rptDurationPage=0;rptBound=false;\n            var selectedView=preferences?preferences.view:dto.view;rptPreferredView=selectedView==='timeline'?'timeline':'matrix';rptEffectiveView=null;\n            var controls=preferences?preferences.controls:dto.controls;\n            Object.keys(controls||{}).forEach(function(id){var el=document.getElementById(id);if(el && isFinite(controls[id]))el.value=controls[id]});\n            rptBindOnce();rptRenderAll();document.getElementById('advReport').setAttribute('data-interactive-ready','true');\n        } catch(e) {\n            var box=document.getElementById('rptSource');if(box)box.textContent='Interactive analytics could not initialize: '+e.message;\n            console.error(e);\n        }\n    }\n    if(document.getElementById('rptInteractiveData'))rptInitEmbeddedReport();\n";
    function rptPackInteractiveModel(model) {
        var all=model.HOSTACTIVE.all_hosts || model.HOSTACTIVE.host_meta,series=Object.create(null);
        if(model.hasSeries)model.HOSTACTIVE.host_meta.forEach(function(h){if(h.hasHistory)series[h.id]=model.HOSTACTIVE.seriesOf(h.id)});
        var dto={data:model.DATA,active:model.ACTIVE,hosts:all,series:series,tenant:model.TENANT,hasSeries:model.hasSeries,hasCpu:model.hasCpu,isOps:model.isOps,isVrops:model.isVrops,isRvtools:model.isRvtools,consumedBasis:model.consumedBasis,source:model.source,rangeLabel:model.rangeLabel,dateStart:model.dateStart,dateEnd:model.dateEnd,opsTimelineEvidence:model.opsTimelineEvidence,view:rptEffectiveView||rptPreferredView,controls:{}};
        ['rptClusterThresholdInput','rptClusterPersistInput','rptThresholdInput','rptPersistInput','rptDurationThreshold','rptDurationPercent'].forEach(function(id){var el=document.getElementById(id);if(el)dto.controls[id]=Number(el.value)});
        var json=JSON.stringify(dto).replace(/</g,'\\u003c').replace(/>/g,'\\u003e').replace(/&/g,'\\u0026').replace(/\u2028/g,'\\u2028').replace(/\u2029/g,'\\u2029');
        if(new Blob([json]).size>32*1024*1024)throw new Error('Interactive analytics exceeds the 32 MB report-data budget. Export fewer clusters or a shorter range; no rows or timeline samples were truncated.');
        return json;
    }
    function repSectionAnalytics(list) {
        var datasets=rptDatasets(list.map(function(ci){return {key:ci.key,d:ci.d}})),ranges=[];
        list.forEach(function(c){if(ranges.indexOf(c.range)<0)ranges.push(c.range)});
        var model=rptBuildModel(datasets,ranges.length===1?ranges[0]:'selected ranges'),json=rptPackInteractiveModel(model);
        return '<section class="sec"><h2>2. Advanced analytics</h2><p class="lead">Interactive, self-contained assessment data. Change thresholds and persistence, switch Matrix / Timeline, hover charts, and search or sort every host and cluster. Long lists open only when requested. All rows remain in this HTML; printing uses the current table pages.</p><style>'+REP_ADV_CSS+'</style>'+REP_ADV_MARKUP+'<noscript>JavaScript is required for interactive analytics. No connection to MTAT or Operations is required.</noscript><scr'+'ipt type="application/json" id="rptInteractiveData">'+json+'</scr'+'ipt><scr'+'ipt>'+REP_ADV_RUNTIME+'</scr'+'ipt></section>';
    }
    function mtatInitSortHints() {
        document.querySelectorAll('th.sortable').forEach(function(th){
            th.title='Click to sort; click again to reverse. Enter or Space also sorts.';
            th.tabIndex=0;
            if(!th.dataset.sortHintBound){th.dataset.sortHintBound='true';th.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){e.preventDefault();th.click()}})}
            var direction=th.getAttribute('data-sort-dir'),key=th.getAttribute('data-mkey');
            th.setAttribute('aria-sort',key?(matrixSort.key===key?(matrixSort.dir===1?'ascending':'descending'):'none'):(direction?(direction==='asc'?'ascending':'descending'):'none'));
        });
    }
    function mtatCollapseBaselineLists() {
        mtatInitSortHints();
        [['hostContainerPanel','hosts'],['vmContainerPanel','VMs']].forEach(function(pair){
            var panel=document.getElementById(pair[0]);if(!panel || panel.querySelector('.mtat-list-collapse'))return;
            var head=panel.querySelector('.panel-head') || panel.firstElementChild;if(!head)return;
            var body=document.createElement('div');body.className='mtat-list-body';
            Array.prototype.slice.call(panel.children).forEach(function(c){if(c!==head)body.appendChild(c)});panel.appendChild(body);
            var button=document.createElement('button');button.type='button';button.className='btn btn-sm mtat-list-collapse';button.style.marginLeft='8px';
            var open=panel.querySelectorAll('tbody tr').length<=25;
            function paint(){body.hidden=!open;button.textContent=(open?'Hide ':'Show ')+pair[1];button.setAttribute('aria-expanded',String(open))}
            button.onclick=function(){open=!open;paint()};head.appendChild(button);paint();
        });
    }


    function repSectionSizing(list, tot, pr) {
        var headline = tot.best;
        var headlineLabel = tot.bestIsBf ? 'Add NVMe to existing hosts at the recommended 1:1 ratio' : 'Refresh onto new tiered hosts at the recommended 1:1 ratio';
        var h = '<section class="sec"><h2>3. Sizing and savings</h2>';
        h += '<div class="hero"><div class="hl">Estimated hardware savings</div><div class="hv">' + (headline > 0 ? 'Up to ' + repMoney(headline) : (tot.eligible === 0 ? 'No clusters qualify yet' : 'No hardware savings at these prices')) + '</div><div class="hs">' + escapeHtml(headlineLabel) +
             (tot.eligible === 0 ? ' &middot; every cluster here is above the 50% Active Memory guideline, already runs Memory Tiering, or is missing performance data, so no savings are claimed' : ' &middot; ' + fmtInt(tot.eligible) + ' qualifying cluster' + (tot.eligible === 1 ? '' : 's') + ' of ' + fmtInt(tot.all)) + '</div></div>';
        h += '<p class="lead">Savings compare Memory Tiering (DRAM plus lower-cost NVMe) against meeting the same capacity with DRAM alone, at the prices shown below, using the recommended 1:1 ratio (equal NVMe and DRAM). <b>Existing hosts:</b> the saving is the cost of the extra memory you would otherwise buy as DRAM, less the NVMe that replaces it. <b>New hosts:</b> the saving is the cheapest DRAM-only refresh less the cheapest tiered refresh, each at the node size that costs least while running the same workload. Ratios above 1:1 are not included; they need additional workload assessment.</p>';
        h += '<h3>Scenarios (qualifying clusters)</h3>' + repTable(['Scenario', 'Clusters', 'NVMe added', 'NVMe cost', 'Net savings', 'Result'], [
            { _cls: tot.bestIsBf ? 'rec' : '', cells: ['Add NVMe to existing hosts, 1:1', fmtInt(tot.eligible), repTb(tot.bfNv), repMoney(tot.bfCost), '<b>' + repMoney(tot.bf1) + '</b>', '+' + fmtInt(tot.bfVm) + ' VMs of headroom'] },
            { _cls: tot.bestIsBf ? '' : 'rec', cells: ['Refresh onto new tiered hosts, 1:1 (lowest-cost node size)', fmtInt(tot.gfClusters), '-', '-', '<b>' + repMoney(tot.gf1) + '</b>', fmtInt(tot.gfTierHosts) + ' tiered vs ' + fmtInt(tot.gfStdHosts) + ' DRAM-only hosts'] }
        ]);
        h += repSvgHBars([{ label: 'Existing hosts + NVMe, 1:1', value: tot.bf1, text: repMoneyShort(tot.bf1) }, { label: 'New tiered hosts, 1:1', value: tot.gf1, text: repMoneyShort(tot.gf1), color: '#318700' }]);
        // Sensitivity: the savings figure moves with the DRAM price, so show it moving.
        var sens = [0.75, 1, 1.25].map(function(f) {
            var p2 = {}; Object.keys(pr).forEach(function(k) { p2[k] = pr[k]; }); p2.dram = pr.dram * f;
            var copy = list.map(function(ci) { var c2 = {}; Object.keys(ci).forEach(function(k) { c2[k] = ci[k]; }); return c2; });
            repScoreClusters(copy, p2); var t2 = repFleetTotals(copy);
            return { cells: ['$' + (pr.dram * f).toFixed(2) + ' per GB' + (f === 1 ? ' (used in this report)' : ''), repMoney(t2.bf1), repMoney(t2.gf1)], _cls: f === 1 ? 'rec' : '' };
        });
        h += '<h3>How the savings move with DRAM pricing</h3>' + repTable(['DRAM price', 'Existing hosts + NVMe, 1:1', 'New tiered hosts, 1:1'], sens);
        var rows = list.filter(function(ci) { return ci.eligible; }).map(function(ci) {
            var b = Math.max(0, ci.bf[1].savings), g = ci.gfRec && ci.gfRec.savings > 0 ? ci.gfRec.savings : 0;
            return { top: Math.max(b, g), cells: [escapeHtml(ci.label), fmtInt(ci.hostCount), repTb(ci.dram), repPct(ci.activePct), repMoney(b),
                     g > 0 ? repMoney(g) + ' <small>(' + ci.gfRec.tierHosts + ' x ' + repTb(ci.gfRec.nodeCap) + ' tiered vs ' + ci.gfRec.stdHosts + ' x ' + repTb(ci.gfRec.stdNodeCap) + ' DRAM-only hosts)</small>' : '-'] };
        }).sort(function(a, b) { return b.top - a.top; });
        h += '<h3>Savings by cluster' + (rows.length > 25 ? ' (top 25 of ' + fmtInt(rows.length) + ')' : '') + '</h3>' + repTable(['Cluster', 'Hosts', 'DRAM', 'Active peak', 'Existing hosts + NVMe, 1:1', 'New tiered hosts, 1:1'], rows.slice(0, 25));
        var ex = [];
        if (tot.exActive) ex.push(fmtInt(tot.exActive) + ' cluster' + (tot.exActive === 1 ? ' is' : 's are') + ' above 50% peak Active Memory and ' + (tot.exActive === 1 ? 'was' : 'were') + ' not counted');
        if (tot.exData) ex.push(fmtInt(tot.exData) + ' cluster' + (tot.exData === 1 ? ' has' : 's have') + ' hosts or VMs that failed data collection, or hosts with no Active Memory samples for the range, and ' + (tot.exData === 1 ? 'was' : 'were') + ' not counted');
        if (tot.exTiered) ex.push(fmtInt(tot.exTiered) + ' cluster' + (tot.exTiered === 1 ? ' already runs' : 's already run') + ' Memory Tiering and ' + (tot.exTiered === 1 ? 'was' : 'were') + ' not counted');
        if (tot.noGain) ex.push(fmtInt(tot.noGain) + ' qualifying cluster' + (tot.noGain === 1 ? ' has' : 's have') + ' no positive refresh savings at these prices');
        if (tot.gfBlocked) ex.push(fmtInt(tot.gfBlocked) + ' qualifying cluster' + (tot.gfBlocked === 1 ? ' has' : 's have') + ' hosts with no CPU or Consumed Memory samples, so no refresh is recommended for ' + (tot.gfBlocked === 1 ? 'it' : 'them'));
        if (tot.tierUnknown) ex.push('Memory Tiering status is not known for ' + fmtInt(tot.tierUnknown) + ' qualifying cluster' + (tot.tierUnknown === 1 ? '' : 's') + ' (the data source does not report it, or the query failed); ' + (tot.tierUnknown === 1 ? 'it is' : 'they are') + ' assumed not to be tiered yet');
        if (ex.length) h += '<div class="note">' + ex.join('; ') + '.</div>';
        h += '<h3>Assumptions</h3>' + repTable(['Input', 'Value'], [
            { cells: ['NVMe to DRAM ratio', '1:1 (recommended default)'] },
            { cells: ['DRAM price', '$' + pr.dram.toFixed(2) + ' per GB'] }, { cells: ['NVMe price', '$' + pr.nvme.toFixed(2) + ' per GB' + (pr.mirror ? ' (doubled for software mirroring)' : '')] },
            { cells: ['New server chassis (refresh)', repMoney(pr.server) + ' each'] }, { cells: ['HA / spare hosts (refresh)', '+' + pr.ha + ' per cluster'] }, { cells: ['New node CPU capacity (refresh)', pr.cpuMult.toFixed(2) + 'x existing'] },
            { cells: ['Qualifying cluster', 'Peak Active Memory at or below 50% of the DRAM available for tiering (memory of DRAM-only VMs, such as passthrough or vGPU VMs, is set aside first), Active Memory data from every host, and not already tiered'] },
            { cells: ['Platform limit applied', 'NVMe up to 4,398.047 GB per host'] },
            { cells: ['Refresh sizing', 'Active Memory kept within 50% of each host\'s DRAM tier; CPU kept below 80% busy; the largest VM fits on one node (a DRAM-only VM within its DRAM)' + (list.some(function(ci) { return ci.cpuNA; }) ? ' (CPU data was not available for some clusters, so CPU did not limit those)' : '')] }
        ]);
        return h + '</section>';
    }

    var REP_CSS = ':root{--ink:#313131;--muted:#6b6b6b;--line:#d9d9d9;--blue:#0072a3;--green:#318700;--orange:#c25400}*{box-sizing:border-box}body{margin:0;background:#e9edf0;font-family:"Avenir Next","Helvetica Neue",Helvetica,Arial,sans-serif;color:var(--ink);font-size:13.5px;line-height:1.5}' +
        '.page{max-width:1000px;margin:0 auto;background:#fff;padding:0 0 40px}.cover{background:#1b2a32;color:#fff;padding:36px 48px 34px;display:flex;gap:28px;align-items:center;justify-content:space-between}.cover-logo{flex:none;background:#fff;border-radius:4px;padding:8px 14px;display:flex;align-items:center}.cover-logo img{display:block;height:96px;width:auto;max-width:300px}.cover h1{margin:0 0 6px;font-size:30px;font-weight:400}.cover .sub{color:#c5d1d8;font-size:14px}.cover .meta{margin-top:22px;display:flex;gap:36px;flex-wrap:wrap;font-size:13px}.cover .meta b{display:block;color:#9fb3bf;font-size:11px;letter-spacing:.08em;text-transform:uppercase;font-weight:600}' +
        '.sec,.summary{padding:28px 48px 0}h2{font-size:21px;font-weight:500;margin:0 0 6px;color:#1b2a32;border-bottom:3px solid var(--blue);padding-bottom:6px}h3{font-size:14.5px;margin:22px 0 8px;color:#1b2a32}.lead{color:#565656;margin:8px 0 14px}small{font-weight:400;color:var(--muted);font-size:.78em}' +
        '.panel{background:#f5fbfe;border:1px solid #b3e2f2;border-radius:3px;padding:16px 20px;margin:12px 0}.ptitle{font-size:15px;font-weight:600;color:#00567a;margin-bottom:12px}.mrow{display:flex;align-items:center;gap:10px;margin:0 0 12px}.mname{width:190px;font-weight:700}.mtarget{width:170px;color:#6b6b6b}.mval{width:170px}.mval b{font-size:15px}.mbadge{width:100px}.pbar{height:6px;background:#e3e3e3;border-radius:3px;overflow:hidden;margin-top:4px}.pbar i{display:block;height:100%;background:#0072a3}.pbar i.pass{background:#318700}.pbar i.warn{background:#c25400}td .pbar{width:110px;margin-left:auto}.small{font-size:11.5px;color:var(--muted);margin:-6px 0 10px}.warnbox{background:#fef3b5;border-left-color:#e6c200}tr.bad td{background:#f5dbd9}.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin:14px 0}.kpi{border:1px solid var(--line);border-bottom:3px solid #dcdcdc;border-radius:3px;padding:12px 14px}.kl{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);font-weight:600}.kv{font-size:24px;font-weight:500;margin-top:2px}.ks{font-size:11.5px;color:var(--muted)}' +
        '.hero{background:#eef7e8;border:1px solid #b7dc9a;border-left:6px solid var(--green);border-radius:3px;padding:16px 20px;margin:14px 0}.hl{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:#266900;font-weight:700}.hv{font-size:34px;font-weight:600;color:#266900;line-height:1.2}.hs{color:#3d6b22;font-size:13px}' +
        'table{width:100%;border-collapse:collapse;margin:8px 0 14px;font-size:12.5px}th{background:#f4f6f7;text-align:left;padding:7px 10px;border-bottom:2px solid var(--line);font-size:11.5px;color:#565656}td{padding:6px 10px;border-bottom:1px solid #ececec}.r{text-align:right}tr.rec td{background:#f3fbef}' +
        '.bdg{display:inline-block;padding:1px 9px;border-radius:10px;font-size:11px;font-weight:600;border:1px solid transparent}.bdg.ok{background:#dff0d0;color:#266900;border-color:#9fd16b}.bdg.no{background:#fef3b5;color:#6e4c00;border-color:#e6c200}.bdg.na{background:#eee;color:#565656}' +
        '.note{background:#e3f5fc;border-left:4px solid #49afd9;padding:9px 14px;margin:10px 0;font-size:12.5px;border-radius:2px}.summary ul{margin:8px 0 0 18px;padding:0}.summary li{margin:5px 0}.foot{margin:30px 48px 0;padding-top:12px;border-top:1px solid var(--line);color:var(--muted);font-size:11.5px}' +
        '.toolbar{position:sticky;top:0;background:#1b2a32;color:#fff;padding:10px 20px;display:flex;gap:12px;align-items:center;justify-content:flex-end;z-index:5}.toolbar button{background:var(--blue);color:#fff;border:0;border-radius:3px;padding:8px 18px;font-weight:600;letter-spacing:.08em;text-transform:uppercase;font-size:12px;cursor:pointer}' +
        '@media print{body{background:#fff}.page{max-width:none;padding:12mm 14mm;-webkit-box-decoration-break:clone;box-decoration-break:clone}h2,h3{break-after:avoid}.toolbar{display:none}.sec{break-before:page;padding:0}.summary{padding:0}.cover{padding:26px 28px;-webkit-print-color-adjust:exact;print-color-adjust:exact}.cover-logo{-webkit-print-color-adjust:exact;print-color-adjust:exact}tr,.kpi,.hero,.note,svg{break-inside:avoid}thead{display:table-header-group}.hero,.bdg,th,tr.rec td,.note,.kpi{-webkit-print-color-adjust:exact;print-color-adjust:exact}.foot{margin:24px 0 0}}@page{margin:0}';

    function repBuildSingleHtml(o) {
        var scopeIssue=mtatJobScopeIssue(o.scope);if(scopeIssue)throw new Error(scopeIssue);
        var list = repClusterList(o.scope, o.key, o.range), pr = repPricing();
        if (!list.length) return null;
        repScoreClusters(list, pr);
        var tot = repFleetTotals(list), now = new Date();
        var secs = o.sections, headline = tot.best;
        var title = (o.customer ? o.customer + ': ' : '') + 'Memory Tiering Assessment';
        var h = '<!DOCTYPE html><html lang="en" data-theme="light"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>' + escapeHtml(title) + '</title><style>' + REP_CSS + '</style></head><body>';
        h += '<div class="toolbar"><span style="margin-right:auto;font-size:12px;color:#c5d1d8">Use Print and choose Save as PDF. If your browser shows Headers and footers in the print options, turn them off so your file location is not printed.</span><button onclick="window.print()">Print / Save as PDF</button></div><div class="page">';
        var logoEl = document.querySelector('#brandingLogoCell img'), logoHtml = (logoEl && logoEl.src) ? '<div class="cover-logo"><img src="' + escapeHtml(logoEl.src) + '" alt="Memory Tiering Assessment Tool"></div>' : '';
        h += '<div class="cover"><div class="cover-text"><div class="sub">Memory Tiering Assessment Tool</div><h1>' + escapeHtml(o.customer ? o.customer : 'Memory Tiering Assessment') + '</h1><div class="sub">' + escapeHtml(secs.indexOf('sizing') >= 0 ? 'Memory Tiering assessment and savings estimate' : (secs.length === 1 && secs[0] === 'analytics' ? 'Memory Tiering advanced analytics' : 'Memory Tiering assessment')) + '</div>';
        h += '<div class="meta"><div><b>Date</b>' + escapeHtml(now.toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })) + '</div>' + (o.preparedBy ? '<div><b>Prepared by</b>' + escapeHtml(o.preparedBy) + '</div>' : '') +
             '<div><b>Scope</b>' + escapeHtml(o.scope === 'selected' ? list[0].label : fmtInt(list.length) + ' cluster' + (list.length === 1 ? '' : 's') + ', ' + fmtInt(tot.hosts) + ' hosts') + '</div>' + (obfOn() ? '<div><b>Names</b>Hidden</div>' : '') + '</div></div>' + logoHtml + '</div>';
        // Executive summary
        var candN = list.filter(function(ci) { return mtActiveOk(ci.sizingActivePct) && ci.dram > 0 && !ci.missingActive; }).length, dram = tot.dram, act = 0;
        list.forEach(function(ci) { act += ci.active; });
        h += '<div class="summary"><h2>Summary</h2><ul>';
        h += '<li>' + fmtInt(list.length) + ' cluster' + (list.length === 1 ? '' : 's') + ' (' + fmtInt(tot.hosts) + ' hosts, ' + repTb(dram) + ' of DRAM) ' + (list.length === 1 ? 'was' : 'were') + ' assessed.</li>';
        h += '<li>' + fmtInt(candN) + ' ' + (candN === 1 ? 'cluster keeps' : 'clusters keep') + ' peak Active Memory at or below 50% of DRAM' + (dram > 0 ? ' (' + repPct(act / dram * 100) + ' overall)' : '') + ', the profile that suits Memory Tiering.</li>';
        if (secs.indexOf('sizing') >= 0) {
            h += '<li>' + (headline > 0 ? 'Estimated hardware savings of up to <b>' + repMoney(headline) + '</b> across ' + fmtInt(tot.eligible) + ' qualifying cluster' + (tot.eligible === 1 ? '' : 's') + ' at the recommended 1:1 ratio' + '.</li>' : (tot.eligible === 0 ? 'None of the clusters meet the 50% Active Memory guideline (or they already run Memory Tiering, or are missing performance data), so no savings are claimed.</li>' : 'No hardware savings were found at the prices used.</li>'));
        }
        h += '</ul></div>';
        if (secs.indexOf('assessment') >= 0) h += repSectionAssessment(list, tot, o.ranges, o.matrixKeys);
        if (secs.indexOf('analytics') >= 0) h += repSectionAnalytics(list);
        if (secs.indexOf('sizing') >= 0) h += repSectionSizing(list, tot, pr);
        h += '<div class="foot">Planning and sizing estimates only; not a formal quote. Figures are projections from the data collected on the date above and the pricing assumptions shown, and are not a guarantee of results. Generated by the Memory Tiering Assessment Tool.</div></div></body></html>';
        return { html: h, title: title, headline: headline, tot: tot };
    }
    var REP_RANGE_CSS = ".rep-range-toolbar{gap:14px;flex-wrap:wrap}.rep-range-toolbar label{display:flex;align-items:center;gap:10px;font-size:13px;font-weight:600;margin-right:auto}.rep-range-toolbar select{max-width:min(600px,70vw);padding:7px;border:1px solid #8797a0;border-radius:4px;color:#172c43;background:#fff}.rep-range-context{max-width:1000px;margin:auto;padding:12px 24px;background:#f4f8fb;border-bottom:1px solid #d7dbe0}.rep-range-context [role=status]{font-weight:600;margin-bottom:5px}.rep-range-context .small{font-size:12px;color:#52616c}.rep-range-choices{max-height:220px;overflow:auto}.rep-range-choices label{display:flex;align-items:center;gap:6px;padding:4px 0}.rep-range-help{font-size:12px;color:var(--text-muted);margin:8px 0}\n@media print{.rep-range-toolbar{display:none!important}.rep-range-context{max-width:none;color:#000;padding:8px 0}#repRangeContent{display:block}}\n";
    var REP_RANGE_RUNTIME = "    var repEmbeddedWindows=null,repRangePreferences=null;\n    function repCaptureRangePreferences() {\n        if(typeof RPT==='undefined'||!RPT)return repRangePreferences;\n        var preferences={view:rptPreferredView,controls:{},excludedTenants:Array.from(RPT.excludedTenants||[])};\n        ['rptClusterThresholdInput','rptClusterPersistInput','rptThresholdInput','rptPersistInput','rptDurationThreshold','rptDurationPercent'].forEach(function(id){var el=document.getElementById(id);if(el)preferences.controls[id]=el.value});return preferences;\n    }\n    function repSelectCollectedRange(index) {\n        var data=repEmbeddedWindows.windows[index];if(!data)throw new Error('Unknown collected report range.');\n        repRangePreferences=repCaptureRangePreferences();\n        document.getElementById('repRangeContent').innerHTML=data.html;\n        document.getElementById('repTimeRange').value=String(index);\n        document.getElementById('repRangeCoverage').textContent=data.label+' \u2014 '+data.clusters.toLocaleString()+' of '+data.expected.toLocaleString()+' clusters in the selected scope; '+data.hosts.toLocaleString()+' hosts.'+(data.clusters\u003cdata.expected?' This range is incomplete across the selected scope. Totals and savings cover only the listed clusters.':'');\n        if(data.analytics && typeof rptInitEmbeddedReport==='function')rptInitEmbeddedReport(data.analytics,repRangePreferences);\n        document.body.setAttribute('data-collected-range',data.label);\n    }\n    try {\n        repEmbeddedWindows=JSON.parse(document.getElementById('mtatReportWindows').textContent);\n        var select=document.getElementById('repTimeRange');\n        repEmbeddedWindows.windows.forEach(function(w,i){var option=document.createElement('option');option.value=String(i);option.textContent=w.label+' ('+w.clusters+'/'+w.expected+' clusters)';select.appendChild(option)});\n        select.addEventListener('change',function(){try{repSelectCollectedRange(Number(select.value))}catch(e){document.getElementById('repRangeCoverage').textContent='Could not display this collected range: '+e.message;console.error(e)}});\n        repSelectCollectedRange(repEmbeddedWindows.initial||0);document.body.setAttribute('data-report-ranges-ready','true');\n    } catch(e) {document.getElementById('repRangeCoverage').textContent='Could not initialize collected report ranges: '+e.message;console.error(e)}\n";
    function repReportScopeKeys(scope,selKey) {
        var keys=Object.keys(clusterSessionCache);
        if(scope==='selected'){
            var selected=selKey;
            if(!clusterSessionCache[selected])selected=document.getElementById('simClusterSelect').value;
            if(!clusterSessionCache[selected])selected=lastAppliedClusterKey;
            keys=clusterSessionCache[selected]?[selected]:[];
        }
        return keys.filter(function(k){var ranges=clusterSessionCache[k].ranges||{};return Object.keys(ranges).some(function(range){var d=ranges[range];return d&&mtatAsArray(d.hosts).length>0})});
    }
    function repReportRangeInfo(scope,selKey) {
        var keys=repReportScopeKeys(scope,selKey),counts=Object.create(null),last=[];
        keys.forEach(function(k){var c=clusterSessionCache[k];Object.keys(c.ranges||{}).forEach(function(range){if(c.ranges[range]&&mtatAsArray(c.ranges[range].hosts).length)counts[range]=(counts[range]||0)+1});if(last.indexOf(c.lastRange)<0)last.push(c.lastRange)});
        function rank(s){return s==='Latest Ops Sample'||s==='Real-Time Snapshot'?0:s==='Past 24 Hours'?1:s==='Past 7 Days'?2:s==='Past 30 Days'?3:s==='Past 365 Days'?4:5}
        var windows=Object.keys(counts).sort(function(a,b){return rank(a)-rank(b)||a.localeCompare(b,undefined,{numeric:true})}).map(function(range){return {range:range,label:range,clusters:counts[range],expected:keys.length}});
        if(last.length>1)windows.unshift({range:null,label:'Selected result per cluster (mixed time ranges)',clusters:keys.filter(function(k){var c=clusterSessionCache[k];return !!c.ranges[c.lastRange]}).length,expected:keys.length});
        return {keys:keys,windows:windows,defaultRange:last.length===1?last[0]:null};
    }
    function repSafeReportJson(value) {
        return JSON.stringify(value).replace(/</g,'\\u003c').replace(/>/g,'\\u003e').replace(/&/g,'\\u0026').replace(/\u2028/g,'\\u2028').replace(/\u2029/g,'\\u2029');
    }
    function repSplitReportWindow(result,info) {
        var html=result.html,start=html.indexOf('<div class="page">'),end=html.lastIndexOf('</body>');
        if(start<0||end<start)throw new Error('The report window could not be prepared. No report was exported.');
        var page=html.slice(start,end),marker='<scr'+'ipt type="application/json" id="rptInteractiveData">',a=page.indexOf(marker),analytics=null;
        if(a>=0){var z=page.indexOf('</scr'+'ipt>',a);if(z<0)throw new Error('Missing analytics data terminator.');analytics=JSON.parse(page.slice(a+marker.length,z));page=page.slice(0,a)+page.slice(z+9);page=page.replace('<scr'+'ipt>'+REP_ADV_RUNTIME+'</scr'+'ipt>','')}
        return {label:info.label,range:info.range,clusters:result.tot.all,expected:info.expected,hosts:result.tot.hosts,html:page,analytics:analytics};
    }
    function repBuildHtml(o) {
        var issue=mtatJobScopeIssue(o.scope);if(issue)throw new Error(issue);
        var info=repReportRangeInfo(o.scope,o.key),windows=info.windows;
        if(o.ranges!==undefined){if(!Array.isArray(o.ranges)||!o.ranges.length)throw new Error('Select at least one collected time range.');o.ranges.forEach(function(range){if(!windows.some(function(w){return w.range===range}))throw new Error('A selected time range is not collected in this scope.')});windows=windows.filter(function(w){return o.ranges.indexOf(w.range)>=0})}
        else if(typeof o.range==='string')windows=windows.filter(function(w){return w.range===o.range});
        if(!windows.length)return null;
        var bundle={version:1,initial:0,windows:[]},first=null,json='';
        windows.forEach(function(w,i){var options={};Object.keys(o).forEach(function(k){options[k]=o[k]});options.range=w.range;options.matrixKeys=info.keys;options.ranges=windows.map(function(item){return item.range});
            var result=repBuildSingleHtml(options);if(!result)throw new Error('No host results are available for '+w.label+'. Select a completed range; no ranges were silently removed.');
            if(!first || w.range===info.defaultRange){first=result;bundle.initial=i}
            bundle.windows.push(repSplitReportWindow(result,w));json=repSafeReportJson(bundle);
            if(new Blob([json]).size>32*1024*1024)throw new Error('The selected report ranges exceed the combined 32 MB report budget. Select fewer time ranges or clusters in Export report. No rows, samples or ranges were truncated.');
        });
        json=repSafeReportJson(bundle);
        var hasAnalytics=o.sections.indexOf('analytics')>=0;
        var h='<!DOCTYPE html><html lang="en" data-theme="light"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>'+escapeHtml(first.title)+'</title><style>'+REP_CSS+REP_RANGE_CSS+'</style></head><body>';
        h+='<div class="toolbar rep-range-toolbar"><label for="repTimeRange">Collected time range <select id="repTimeRange" aria-describedby="repRangeCoverage"></select></label><button type="button" onclick="window.print()">Print / Save as PDF</button></div><div class="rep-range-context"><div id="repRangeCoverage" role="status"></div><div class="small">Includes collected results only. Switching ranges updates assessment, analytics and sizing in this file; it does not retrieve new data. Printing uses the selected range and current table pages.</div></div><main id="repRangeContent"></main><noscript>Enable JavaScript to select the collected ranges in this self-contained report. No MTAT engine or Operations connection is needed.</noscript>';
        h+='<scr'+'ipt type="application/json" id="mtatReportWindows">'+json+'</scr'+'ipt>'+(hasAnalytics?'<scr'+'ipt>'+REP_ADV_RUNTIME+'</scr'+'ipt>':'')+'<scr'+'ipt>'+REP_RANGE_RUNTIME+'</scr'+'ipt></body></html>';
        return {html:h,title:first.title,headline:first.headline,tot:first.tot,ranges:bundle.windows.map(function(w){return w.label})};
    }


    // ---------- dialog and downloads ----------
    function repDownloadHtml(html, filename) {
        var blob = new Blob([html], { type: 'text/html;charset=utf-8' }), url = URL.createObjectURL(blob), a = document.createElement('a');
        a.href = url; a.download = filename; a.style.visibility = 'hidden'; document.body.appendChild(a); a.click(); document.body.removeChild(a);
        setTimeout(function() { URL.revokeObjectURL(url); }, 2000);
    }
    function repPresetSections(preset) { return preset === 'all' ? ['assessment', 'analytics', 'sizing'] : [preset]; }
    function openReportDialog(preset) {
        if (!Object.keys(clusterSessionCache).length) { showToast("Analyze or import some data first, then export a report.", 'warn'); return; }
        var old = document.getElementById('repModal'); if (old) old.remove();
        var secs = repPresetSections(preset), keys = repReportScopeKeys('all'), nClusters = keys.length, selKey = document.getElementById('simClusterSelect').value;
        if (!clusterSessionCache[selKey]) selKey = lastAppliedClusterKey;
        if (!clusterSessionCache[selKey]) selKey = keys[0];
        var m = document.createElement('div'); m.id = 'repModal'; m.className = 'rep-modal'; m.setAttribute('role', 'dialog'); m.setAttribute('aria-modal', 'true');
        function chk(v) { return secs.indexOf(v) >= 0 ? ' checked' : ''; }
        m.innerHTML = '<div class="rep-card"><h3>' + (preset === 'all' ? 'Customer report' : 'Export report') + '</h3>' +
            '<div class="rep-grid"><label>Customer name<input type="text" id="repCustomer" value="' + escapeHtml(repMeta.customer) + '" placeholder="Optional"></label><label>Prepared by<input type="text" id="repPrepared" value="' + escapeHtml(repMeta.preparedBy) + '" placeholder="Optional"></label></div>' +
            '<fieldset><legend>Include</legend><label class="rep-opt"><input type="checkbox" id="repSecA"' + chk('assessment') + '> Assessment</label><label class="rep-opt"><input type="checkbox" id="repSecB"' + chk('analytics') + '> Advanced analytics</label><label class="rep-opt"><input type="checkbox" id="repSecC"' + chk('sizing') + '> Sizing and savings</label></fieldset>' +
            '<fieldset><legend>Scope</legend><label class="rep-opt"><input type="radio" name="repScope" value="all" checked> All loaded clusters (' + fmtInt(nClusters) + ')</label>' +
            (nClusters > 1 || mtatJobScopeIssue('all') ? '<label class="rep-opt"><input type="radio" name="repScope" value="selected"> One cluster:</label><select id="repClusterSel" class="rep-sel" aria-label="Cluster for the report"></select>' : '') + '</fieldset>' +
            '<fieldset><legend>Collected time ranges</legend><div id="repRangeChoices" class="rep-range-choices"></div><p class="rep-range-help">Include several ranges to compare them in one HTML report. All selected ranges share a combined 32 MB export budget. The exported file can switch collected results without connecting to MTAT.</p></fieldset>' +
            '<div class="rep-prev" id="repPreview"></div><div class="rep-actions"><button class="btn btn-green" id="repGo" style="width:auto;padding:0 22px">Generate report</button><button class="btn btn-secondary" id="repCancel" style="width:auto;padding:0 22px">Cancel</button></div></div>';
        document.body.appendChild(m);
        var csel = document.getElementById('repClusterSel');
        if (csel) {
            var frag = document.createDocumentFragment();
            keys.slice().sort(function(a, b) { return repLabel(a).localeCompare(repLabel(b), undefined, { numeric: true }); }).forEach(function(k) { var o = document.createElement('option'); o.value = k; o.textContent = repLabel(k); frag.appendChild(o); });
            csel.appendChild(frag); csel.value = selKey;
            csel.addEventListener('change', function() { document.querySelector('input[name=repScope][value=selected]').checked = true; refreshPreview(); });
            // The cluster list can be long; typing the first letters of a name jumps to it, as in any dropdown.
        }
        function scopeVal() { return (document.querySelector('input[name=repScope]:checked') || {}).value || 'all'; }
        var rangeChoiceSignature='';
        function selectedReportRanges(){return Array.prototype.map.call(document.querySelectorAll('#repRangeChoices input:checked'),function(cb){return JSON.parse(cb.value)})}
        function refreshRangeChoices(){
            var key=csel?csel.value:null,signature=scopeVal()+'|'+key,info=repReportRangeInfo(scopeVal(),key);
            if(signature!==rangeChoiceSignature){rangeChoiceSignature=signature;var root=document.getElementById('repRangeChoices');root.textContent='';info.windows.forEach(function(w){var label=document.createElement('label'),cb=document.createElement('input');cb.type='checkbox';cb.checked=true;cb.value=JSON.stringify(w.range);cb.addEventListener('change',refreshPreview);label.appendChild(cb);label.appendChild(document.createTextNode(w.label+' ('+w.clusters+'/'+w.expected+' clusters)'));root.appendChild(label)})}
            return info;
        }
        function refreshPreview() {
            var info=refreshRangeChoices(),chosen=selectedReportRanges();
            var issue=mtatJobScopeIssue(scopeVal()) || (!chosen.length?'Select at least one collected time range.':'');document.getElementById('repGo').disabled=!!issue;
            if(issue){document.getElementById('repPreview').textContent=issue;return;}
            var selectedRange=chosen.indexOf(info.defaultRange)>=0?info.defaultRange:chosen[0],list = repClusterList(scopeVal(), csel ? csel.value : null,selectedRange), pr = repPricing(); repScoreClusters(list, pr); var t = repFleetTotals(list);
            document.getElementById('repPreview').innerHTML = '<b>'+chosen.length+' collected time range(s) included.</b> Use the time-range selector in the exported HTML to compare results.<br><small>Preview: '+escapeHtml(selectedRange===null?'Selected result per cluster':selectedRange)+'</small><br><b>' + (t.best > 0 ? 'Up to ' + repMoney(t.best) : (t.eligible === 0 ? 'No qualifying clusters in this scope' : 'No savings at current prices')) + '</b> at the recommended 1:1 ratio, across ' + fmtInt(t.eligible) + ' qualifying cluster' + (t.eligible === 1 ? '' : 's') + ' of ' + fmtInt(t.all) + '. Prices come from the Sizing and Savings tab: DRAM $' + pr.dram.toFixed(2) + '/GB, NVMe $' + pr.nvme.toFixed(2) + '/GB.';
        }
        Array.prototype.forEach.call(m.querySelectorAll('input[type=radio]'), function(r) { r.addEventListener('change', refreshPreview); });
        refreshPreview();
        document.getElementById('repCancel').onclick = function() { m.remove(); };
        m.addEventListener('click', function(e) { if (e.target === m) m.remove(); });
        document.getElementById('repGo').onclick = function() {
            var sections = []; if (document.getElementById('repSecA').checked) sections.push('assessment'); if (document.getElementById('repSecB').checked) sections.push('analytics'); if (document.getElementById('repSecC').checked) sections.push('sizing');
            if (!sections.length) { showToast("Choose at least one section to include.", 'warn'); return; }
            repMeta.customer = document.getElementById('repCustomer').value.trim(); repMeta.preparedBy = document.getElementById('repPrepared').value.trim();
            var btn = document.getElementById('repGo'); btn.disabled = true; btn.innerText = 'Building...';
            var scope = scopeVal(), key = csel ? csel.value : null, includedRanges=selectedReportRanges();
            setTimeout(function() {
                try {
                    var r = repBuildHtml({ sections: sections, scope: scope, key: key, ranges: includedRanges, customer: repMeta.customer, preparedBy: repMeta.preparedBy });
                    if (!r) { showToast("There is no data in the selected scope.", 'warn'); btn.disabled = false; btn.innerText = 'Generate report'; return; }
                    var part = sections.length === 3 ? 'Customer_Report' : sections.map(function(s) { return { assessment: 'Assessment', analytics: 'Analytics', sizing: 'Sizing' }[s]; }).join('_');
                    var stamp = new Date().toISOString().slice(0, 10), who = repMeta.customer ? repMeta.customer.replace(/[^A-Za-z0-9_-]+/g, '_') + '_' : '';
                    repDownloadHtml(r.html, 'MTAT_' + who + part + '_' + stamp + '.html');
                    m.remove();
                    showToast("Report saved. Open it in a browser and use Print, then Save as PDF, to share it.", 'info');
                } catch (e) { showToast("Could not build the report: " + e.message, 'error'); btn.disabled = false; btn.innerText = 'Generate report'; }
            }, 30);
        };
    }

    function toggleSelectAllRanges() {
        var cbs = document.querySelectorAll('.range-cb');
        var lnk = document.getElementById('selectAllToggle');
        var checking = (lnk.innerText.trim() === "Select All");
        for (var i = 0; i < cbs.length; i++) { cbs[i].checked = checking; }
        lnk.innerText = checking ? "Deselect All" : "Select All";
    }

    // ---- Name obfuscation (exports and imports) ----
    // One session-wide alias table, so the same real name always gets the same alias whether it is
    // aliased on import or on export, and a VM's Host column always lines up with its host's row.
    // Aliases are handed out in order of first appearance; the table lives only in this browser tab
    // and can be downloaded as a key (downloadObfuscationKey) so the customer can map results back.
    // Tenant, datacenter and fabric come from the tenant sheet of a VCF Operations workbook and can
    // identify the customer just as well as a cluster name. BOM (hardware family, e.g. "amd/turin")
    // is left as-is: it describes hardware, not the customer, and the breakdowns need it.
    var OBF_PREFIX = { server: 'vCenter-', cluster: 'Cluster-', host: 'Host-', vm: 'VM-', tenant: 'Tenant-', datacenter: 'DC-', fabric: 'Fabric-' };
    var OBF_PAD = { server: 2, cluster: 3, host: 4, vm: 4, tenant: 2, datacenter: 2, fabric: 3 };
    var obfMap = { server: {}, cluster: {}, host: {}, vm: {}, tenant: {}, datacenter: {}, fabric: {} };
    var obfCount = { server: 0, cluster: 0, host: 0, vm: 0, tenant: 0, datacenter: 0, fabric: 0 };
    var obfIsAlias = {};
    var lastAppliedClusterKey = null;
    var OBF_GENERIC_CLUSTERS = { 'Offline_Cluster': true, '(no cluster)': true };

    var obfReverse = {};
    // Prefixes of synthetic (import) cache keys; anything else before the "|" is a real vCenter name.
    var OBF_SYNTHETIC_PREFIX = { 'VCF Ops': true, 'Imported': true, 'Offline_Import': true, 'RVTools': true };
    var OBF_ALIAS_RE = /^(vCenter|Cluster|Host|VM|Tenant|DC|Fabric)-\d+$/;

    function obfOn() { var t = document.getElementById('obfToggle'); return !!(t && t.checked); }
    function obfName(kind, real) {
        if (real === null || real === undefined || real === '') return real;
        real = String(real);
        // Never alias an alias (re-exporting obfuscated data, or importing a file someone else already
        // obfuscated), or the tool's own placeholder names.
        if (obfIsAlias[real] || OBF_ALIAS_RE.test(real) || real === 'ERROR' || OBF_GENERIC_CLUSTERS[real]) return real;
        var m = obfMap[kind];
        if (!Object.prototype.hasOwnProperty.call(m, real)) {
            obfCount[kind]++;
            var n = String(obfCount[kind]); while (n.length < OBF_PAD[kind]) n = '0' + n;
            m[real] = OBF_PREFIX[kind] + n;
            obfIsAlias[m[real]] = true; obfReverse[m[real]] = real;
            var keyRow = document.getElementById('obfKeyRow'); if (keyRow) keyRow.style.display = 'block';
        }
        return m[real];
    }
    function deobfName(kind, name) {
        if (name === null || name === undefined) return name;
        return Object.prototype.hasOwnProperty.call(obfReverse, name) ? obfReverse[name] : name;
    }
    // Exports write whatever is loaded (already aliased when the switch is on); this only covers the
    // live cache keys, whose cluster part is never renamed because the engine needs the real name.
    function obfExport(kind, name) { return obfOn() ? obfName(kind, name) : name; }
    function obfImportOn() { return obfOn(); }

    // Renames every name in a parsed {hosts, vms, failedHosts, failedVms, series} result in place.
    function renameParsedResult(parsed, fn) {
        (parsed.hosts || []).forEach(function(h) {
            h.Cluster = fn('cluster', h.Cluster); h.HostName = fn('host', h.HostName);
            if (h.Tenant) h.Tenant = fn('tenant', h.Tenant);
            if (h.Datacenter) h.Datacenter = fn('datacenter', h.Datacenter);
            if (h.Fabric) h.Fabric = fn('fabric', h.Fabric);
        });
        (parsed.vms || []).forEach(function(v) { v.Host = fn('host', v.Host); v.VMName = fn('vm', v.VMName); });
        if (parsed.failedHosts) parsed.failedHosts = parsed.failedHosts.map(function(n) { return fn('host', n); });
        if (parsed.failedVms) parsed.failedVms = parsed.failedVms.map(function(n) { var i = String(n).indexOf('/'); return i > 0 ? fn('host', n.slice(0, i)) + '/' + fn('vm', n.slice(i + 1)) : fn('vm', n); });
        if (parsed.series && parsed.series.hosts) {
            var renamedSeries = {};
            Object.keys(parsed.series.hosts).forEach(function(hn) { renamedSeries[fn('host', hn)] = parsed.series.hosts[hn]; });
            parsed.series.hosts = renamedSeries;
        }
        return parsed;
    }
    function obfuscateParsedResult(parsed) { return renameParsedResult(parsed, obfName); }

    // Applies fn (obfName or deobfName) to everything already loaded: host/VM/cluster names inside
    // every cached range, plus the cluster part of import keys ("VCF Ops|wh-2baff32e85" <->
    // "VCF Ops|Cluster-002"). Live keys keep their real "server|cluster" value, since the engine needs
    // it to analyze again; their on-screen labels are aliased by advClusterLabel() instead.
    function transformLoadedNames(fn) {
        var renamed = {};
        Object.keys(clusterSessionCache).forEach(function(key) {
            var cache = clusterSessionCache[key];
            Object.keys(cache.ranges || {}).forEach(function(l) { renameParsedResult(cache.ranges[l], fn); });
            var bar = key.indexOf('|'), prefix = key.slice(0, bar), cl = key.slice(bar + 1);
            if (!OBF_SYNTHETIC_PREFIX[prefix] || OBF_GENERIC_CLUSTERS[cl]) return;
            var newKey = prefix + '|' + fn('cluster', cl);
            if (newKey === key) return;
            var target = clusterSessionCache[newKey];
            if (target) { Object.keys(cache.ranges).forEach(function(l) { target.ranges[l] = cache.ranges[l]; }); target.lastRange = cache.lastRange || target.lastRange; }
            else clusterSessionCache[newKey] = cache;
            delete clusterSessionCache[key];
            renamed[key] = newKey;
        });
        if (renamed[lastAppliedClusterKey]) lastAppliedClusterKey = renamed[lastAppliedClusterKey];
        var simSelect = document.getElementById('simClusterSelect'), simWasValue = simSelect.value;
        Array.prototype.slice.call(simSelect.options).forEach(function(o) { if (renamed[o.value]) o.remove(); });
        addSimClusterOptions(Object.keys(renamed).map(function(k) { return renamed[k]; }));
        if (renamed[simWasValue]) simSelect.value = renamed[simWasValue];
    }
    function refreshClusterOptionLabels() {
        ['clusterSelect', 'simClusterSelect'].forEach(function(id) {
            var sel = document.getElementById(id); if (!sel) return;
            Array.prototype.forEach.call(sel.options, function(o) { if (o.value) o.textContent = (typeof liveClusterLabels !== 'undefined' && liveClusterLabels[o.value]) ? obfExport('cluster', mtClusterName(o.value)) : advClusterLabel(o.value); });
        });
    }
    function updateObfuscationNote() {
        var note = document.getElementById('obfImportNote'); if (!note) return;
        note.innerHTML = obfOn()
            ? "<b>Hide real names is on.</b> Cluster, host and VM names (and source file names) are replaced with aliases as files are read, on screen and in exports."
            : "Tip: switch on <b>Hide real names</b> (next to Process Import) before importing to keep real cluster, host and VM names off screen and out of exports. You can switch it on or off at any time.";
    }
    // The "Hide real names" switch: one setting for everything, on screen and in exports.
    // Only one "Hide real names" switch is ever visible: the one next to Process Import while the
    // Import panel is open, otherwise the copy above the export buttons (once there is data to export).
    function updateObfSwitchVisibility() {
        var wrap = document.getElementById('obfExportSwitchWrap'); if (!wrap) return;
        var panel = document.getElementById('importPanel');
        var importOpen = panel && panel.style.display !== 'none' && panel.style.display !== '';
        var exportsShown = document.getElementById('btnExportAll').style.display === 'block';
        wrap.style.display = (!importOpen && exportsShown) ? 'block' : 'none';
    }
    function syncObfuscationSwitches(on) {
        ['obfToggle', 'obfToggleExport', 'obfToggleAdv'].forEach(function(id) {
            var el = document.getElementById(id); if (!el) return;
            el.checked = on;
            var card = el.closest('.obf-card');
            if (card) { card.classList.toggle('is-on', on); var st = card.querySelector('.obf-state'); if (st) st.textContent = on ? 'ON' : 'OFF'; }
        });
    }
    function setObfuscation(on) {
        syncObfuscationSwitches(on);
        transformLoadedNames(on ? obfName : deobfName);
        refreshClusterOptionLabels();
        rebuildGroupedMatrix();
        var k = lastAppliedClusterKey;
        if (k && clusterSessionCache[k] && document.getElementById('metricsDisplayCard').style.display !== 'none') {
            var c = clusterSessionCache[k], d = c.ranges[c.lastRange];
            if (d) applyAnalysisResult(k, c.lastRange, d);
        }
        if (document.getElementById('tab-advanced').className.indexOf('active') >= 0) refreshAdvancedTab();
        if (document.getElementById('tab-simulator').className.indexOf('active') >= 0) loadClusterSimulation();
        updateObfuscationNote();
        if (Object.keys(clusterSessionCache).length) {
            showToast(on ? "Real names are hidden on screen and in exports. New analyses and imports are hidden as they arrive."
                         : "Real names restored.", 'info');
        }
    }
    updateObfuscationNote();
    // The debug log is written by the engine with real names. When "Hide real names" is on, every name
    // MTAT knows (from the alias table, plus vCenter servers and clusters in the dropdowns, which are
    // aliased here first) is swapped for its alias, longest names first so an FQDN wins over its
    // short host name. Logon user names typed on the Connection tab are replaced with "[user]".
    function obfuscateLogText(text) {
        try { parseServersInput().forEach(function(sv) { obfName('server', sv); }); } catch (e) { /* no servers typed */ }
        ['clusterSelect', 'simClusterSelect'].forEach(function(id) {
            var sel = document.getElementById(id); if (!sel) return;
            Array.prototype.forEach.call(sel.options, function(o) {
                var bar = o.value.indexOf('|'); if (bar < 0) return;
                var server = o.value.slice(0, bar);
                if (!OBF_SYNTHETIC_PREFIX[server]) obfName('server', server);
                obfName('cluster', o.value.slice(bar + 1));
            });
        });
        var lookup = {};
        Object.keys(obfMap).forEach(function(kind) { Object.keys(obfMap[kind]).forEach(function(real) { if (!(real in lookup)) lookup[real] = obfMap[kind][real]; }); });
        document.querySelectorAll('#tab-connect input').forEach(function(inp) {
            if (inp.id !== 'vcServer' && inp.type !== 'password' && inp.type !== 'checkbox' && inp.value && /[@\\]/.test(inp.value)) lookup[inp.value] = '[user]';
        });
        var names = Object.keys(lookup).filter(function(n) { return n.length >= 3; }).sort(function(a, b) { return b.length - a.length; });
        function esc(n) { return n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
        // Chunked so a 40,000-name fleet doesn't build one enormous regular expression.
        for (var i = 0; i < names.length; i += 1500) {
            var re = new RegExp('(?<![A-Za-z0-9_-])(?:' + names.slice(i, i + 1500).map(esc).join('|') + ')(?![A-Za-z0-9_-])', 'g');
            text = text.replace(re, function(m) { return lookup[m]; });
        }
        return "# MTAT debug log, real names hidden (\"Hide real names\" was on). Review before sharing: text MTAT never displayed may still contain real names.\r\n" + text;
    }

    function downloadObfuscationKey() {
        var labels = { server: 'vCenter', cluster: 'Cluster', host: 'Host', vm: 'VM', tenant: 'Tenant', datacenter: 'Datacenter', fabric: 'Fabric' }, csv = "Type,Original_Name,Alias_Name\r\n", n = 0;
        ['server', 'cluster', 'host', 'vm', 'tenant', 'datacenter', 'fabric'].forEach(function(kind) {
            Object.keys(obfMap[kind]).forEach(function(real) { csv += labels[kind] + "," + csvField(real) + "," + csvField(obfMap[kind][real]) + "\r\n"; n++; });
        });
        if (!n) { showToast("No names have been hidden in this session yet.", 'warn'); return; }
        downloadBlobTrigger(csv, "MTAT_name_key_PRIVATE.csv");
    }

    function downloadBlobTrigger(content, filename) {
        var blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
        var url = URL.createObjectURL(blob);
        var link = document.createElement("a");
        link.setAttribute("href", url);
        link.setAttribute("download", filename);
        link.style.visibility = 'hidden';
        document.body.appendChild(link); link.click(); document.body.removeChild(link);
        // Without this, the Blob backing this object URL stays alive for the page's entire
        // lifetime -- a real (if modest) memory leak on a long-lived session with many exports.
        setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
    }

    // RFC 4180: a field containing a comma, quote, or newline must be quoted, with any embedded
    // quote doubled. Cluster/host/VM names are free text (vCenter object names, or whatever was in
    // an imported CSV) and can legitimately contain commas -- without this, the CSV export parser
    // used on re-import (parseCsvText, which IS quote-aware) silently misaligns every column after
    // such a name. Only applied to free-text fields below; plain numbers never need it.
    function csvField(value) {
        var s = (value === undefined || value === null) ? "" : String(value);
        if (/[",\r\n]/.test(s)) { return '"' + s.replace(/"/g, '""') + '"'; }
        return s;
    }

    // Columns added in v3.2 so a re-import keeps them (older exports simply lack them), and the
    // vCenter (or import source) each cluster came from, so same-named clusters stay apart.
    function mtCsvNum(v) { return (typeof v === 'number' && isFinite(v)) ? String(v) : ""; }
    function mtHostCsvCells(h) {
        return csvField(h.Tiering) + "," + mtCsvNum(h.CPU_Pct) + "," + h.Physical_RAM + "," + h.Consumed_GB + "," + h.Active_GB + "," + h.Active_Pct + "," +
               mtCsvNum(h.TierRatioPct) + "," + mtCsvNum(h.Active_Avg_GB) + "," + mtCsvNum(h.NVMe_GB) + "," + csvField(h.Missing_Metrics || "") + "," + mtCsvNum(h.CPU_MHz) + ",GB";
    }
    function mtVmCsvCells(v) {
        return csvField(obfExport('host', v.Host)) + "," + csvField(obfExport('vm', v.VMName)) + "," + v.Provisioned_GB + "," + v.Active_GB + "," + v.Active_Pct + "," +
               csvField(v.DRAM_Only || "N/A") + "," + csvField(v.Pages_1GB) + "," + csvField(v.Pages_2MB) + "," + csvField(v.Missing_Metrics || "") + ",GB";
    }
    function mtClusterName(key) {
        var live = (typeof liveClusterLabels !== 'undefined') ? liveClusterLabels[key] : null;
        return live ? live.cluster : key.split('|').slice(1).join('|');
    }
    function mtKeySource(key) {
        var live = (typeof liveClusterLabels !== 'undefined') ? liveClusterLabels[key] : null;
        if (live) return (live.source === 'vcenter' ? 'vCenter: ' : 'Operations: ') + obfExport('server', live.server);
        var bar = key.indexOf('|'), prefix = bar > 0 ? key.slice(0, bar) : '';
        if (!prefix) return '';
        if (OBF_SYNTHETIC_PREFIX[prefix]) {
            var src = (prefix === 'Imported' && clusterSessionCache[key]) ? clusterSessionCache[key].importSource : '';
            if (!src) return prefix;
            return OBF_SYNTHETIC_PREFIX[src] ? src : obfExport('server', src);
        }
        return obfExport('server', prefix);
    }

    // VMs that failed collection travel as VM rows marked "Collection failed" (no figures), so a
    // re-import still knows that cluster's data is incomplete.
    function mtFailedVmCsvRows(names, prefix, suffix) {
        return (names || []).map(function(n) {
            var s = String(n), i = s.indexOf('/'), host = i > 0 ? s.slice(0, i) : '', vm = i > 0 ? s.slice(i + 1) : s;
            return prefix + csvField(obfExport('host', host)) + "," + csvField(obfExport('vm', vm)) + ",,,,Unknown,,," + csvField("Collection failed") + ",GB" + suffix + "\r\n";
        }).join('');
    }

    function generateCsvString(type) {
        var csv = "";
        if (type === 'matrix') {
            csv = "Target Cluster Scope,Analyzed Range Profile,CPU Avg Pct,Active Mem Peak Pct,Active Mem Avg Pct,Consumed Mem Avg Pct,Source\r\n";
            for (var clusterKey in clusterSessionCache) {
                var cache = clusterSessionCache[clusterKey];
                for (var rName in cache.ranges) {
                    var d = cache.ranges[rName];
                    var actPct = d.dram > 0 ? ((d.active / d.dram) * 100).toFixed(1) : 0;
                    var actAvgPct = (typeof d.activeAvg === 'number' && d.dram > 0) ? ((d.activeAvg / d.dram) * 100).toFixed(1) : null;
                    var consPct = d.dram > 0 ? ((d.consumed / d.dram) * 100).toFixed(1) : 0;
                    csv += csvField(obfExport('cluster', mtClusterName(clusterKey))) + "," + csvField(rName) + "," + (typeof d.cpu === 'number' ? d.cpu + "%" : "N/A") + "," + actPct + "%," + (actAvgPct === null ? "N/A" : actAvgPct + "%") + "," + consPct + "%," + csvField(mtKeySource(clusterKey)) + "\r\n";
                }
            }
            return csv;
        }
        if (type === 'hosts') {
            csv = "Cluster,HostName,Tiering,CPU_Pct,Physical_RAM,Consumed_GB,Active_GB,Active_Pct,TierRatioPct,Active_Avg_GB,NVMe_GB,Missing_Metrics,CPU_MHz,Memory_Unit\r\n";
            for (var j = 0; j < cachedHosts.length; j++) {
                var h = cachedHosts[j]; csv += csvField(obfExport('cluster', h.Cluster)) + "," + csvField(obfExport('host', h.HostName)) + "," + mtHostCsvCells(h) + "\r\n";
            }
            return csv;
        }
        if (type === 'vms') {
            csv = "Host,VMName,Provisioned_GB,Active_GB,Active_Pct,DRAM_Only,Pages_1GB,Pages_2MB,Missing_Metrics,Memory_Unit\r\n";
            for (var k = 0; k < cachedVms.length; k++) {
                var v = cachedVms[k]; csv += mtVmCsvCells(v) + "\r\n";
            }
            csv += mtFailedVmCsvRows(cachedFailedVms, "", "");
            return csv;
        }
        return "";
    }

    function exportSectionToCSV(type) {
        var content = generateCsvString(type);
        if (!content || content.split("\r\n").length <= 2) { showToast("Target table dataset is currently empty.", 'warn'); return; }
        downloadBlobTrigger(content, type + "_extract.csv");
    }

    function exportAllTablesToCSV() {
        var mContent = generateCsvString('matrix');
        if (mContent.split("\r\n").length > 2) downloadBlobTrigger(mContent, "comparison_matrix_grouped.csv");

        // Cluster and RangeName are included as their OWN dedicated columns, not just folded into
        // ClusterContext -- specifically so re-import never has to guess where one ends and the
        // other begins. A cluster name containing a literal "(" (e.g. "Production (DMZ)") can't be
        // reliably split back out of "Production (DMZ) (Past 24 Hours)" by ANY string-parsing
        // heuristic (first-paren, last-paren, or otherwise), since RangeName can ALSO legitimately
        // contain parens (e.g. "Past 7 Days (Matrix Import)") -- both sides of the composite string
        // can be ambiguous, not just one. ClusterContext is still included alongside for
        // readability when the CSV is opened directly, and as a fallback when re-importing an older
        // exported file that predates these two columns.
        var globalHostCsv = "Cluster,RangeName,ClusterContext,HostName,Tiering,CPU_Pct,Physical_RAM,Consumed_GB,Active_GB,Active_Pct,TierRatioPct,Active_Avg_GB,NVMe_GB,Missing_Metrics,CPU_MHz,Memory_Unit,Source\r\n";
        var globalVmCsv = "Cluster,RangeName,ClusterContext,Host,VMName,Provisioned_GB,Active_GB,Active_Pct,DRAM_Only,Pages_1GB,Pages_2MB,Missing_Metrics,Memory_Unit,Source\r\n";

        for (var clusterKey in clusterSessionCache) {
            var cache = clusterSessionCache[clusterKey];
            var cName = obfExport('cluster', mtClusterName(clusterKey)), safeSource = csvField(mtKeySource(clusterKey));
            for (var rName in cache.ranges) {
                var dataObj = cache.ranges[rName];
                var safeCluster = csvField(cName);
                var safeRange = csvField(rName);
                var clusterContext = csvField(cName + " (" + rName + ")");
                var hArr = dataObj.hosts || [];
                for (var x = 0; x < hArr.length; x++) {
                    var h = hArr[x]; globalHostCsv += safeCluster + "," + safeRange + "," + clusterContext + "," + csvField(obfExport('host', h.HostName)) + "," + mtHostCsvCells(h) + "," + safeSource + "\r\n";
                }
                var vArr = dataObj.vms || [];
                for (var y = 0; y < vArr.length; y++) {
                    var v = vArr[y]; globalVmCsv += safeCluster + "," + safeRange + "," + clusterContext + "," + mtVmCsvCells(v) + "," + safeSource + "\r\n";
                }
                globalVmCsv += mtFailedVmCsvRows(dataObj.failedVms, safeCluster + "," + safeRange + "," + clusterContext + ",", "," + safeSource);
            }
        }
        downloadBlobTrigger(globalHostCsv, "all_evaluated_hosts_history.csv");
        downloadBlobTrigger(globalVmCsv, "all_evaluated_vms_history.csv");
    }

    // ==========================================
    // --- DATA IMPORT (offline / no-vCenter path) ---
    // ==========================================

    function toggleImportPanel() {
        var panel = document.getElementById('importPanel');
        var show = panel.style.display === 'none' || panel.style.display === '';
        panel.style.display = show ? 'block' : 'none';
        updateObfSwitchVisibility();
        if (show) {
            document.getElementById('importStatusMsg').style.display = 'none';
            toggleImportSourceFields();
        }
    }

    function toggleImportSourceFields() {
        var sourceType = document.getElementById('importSourceType').value;
        var tertiaryWrap = document.getElementById('importTertiaryWrap');
        var rangeLabelWrap = document.getElementById('importRangeLabelWrap');
        var infoBox = document.getElementById('importInfoBox');

        var primaryInput = document.getElementById('importPrimaryFile');
        var vropsMode = sourceType === 'vrops';
        primaryInput.accept = vropsMode ? ".xlsx" : (sourceType === "rvtools" ? ".xlsx,.csv" : ".csv");
        primaryInput.multiple = vropsMode || sourceType === 'rvtools';
        document.getElementById('importSecondaryFile').multiple = sourceType === 'rvtools';
        document.getElementById('importSecondaryWrap').style.visibility = vropsMode ? 'hidden' : 'visible';
        var unitsWrap = document.getElementById('importVropsUnitsWrap'); if (unitsWrap) unitsWrap.style.display = vropsMode ? 'flex' : 'none';
        var rangeLabelInput = document.getElementById('importRangeLabel');
        if (vropsMode && rangeLabelInput.value === "Imported Data") rangeLabelInput.value = "VCF Ops";
        if (!vropsMode && rangeLabelInput.value === "VCF Ops") rangeLabelInput.value = "Imported Data";

        if (vropsMode) {
            document.getElementById('importPrimaryLabel').innerText = "VCF Operations export (.xlsx, one or more files)";
            tertiaryWrap.style.display = 'none';
            rangeLabelWrap.style.display = 'flex';
            infoBox.innerHTML = "&#9432; Imports native Ops workbooks and the legacy Input.xlsx layout, including timestamped history and tenant mappings. Embedded memory units are converted to decimal GB. Actual consumed memory and separate CPU/core utilization are retained when supplied; legacy allocated-memory proxies are labelled. Overlapping historical exports remain separate ranges. Host exports do not establish VM eligibility or physical tier breakdown.";
        } else if (sourceType === 'history') {
            document.getElementById('importPrimaryLabel').innerText = "Matrix CSV (optional)";
            document.getElementById('importSecondaryLabel').innerText = "All-Tables Hosts History CSV (optional)";
            tertiaryWrap.style.display = 'grid';
            rangeLabelWrap.style.display = 'none';
            infoBox.innerHTML = "&#9432; Restores potentially many clusters/ranges at once from previously exported history files (at least one of the three is required). The Hosts+VMs History pair carries full per-host detail and powers sizing exactly like a live analysis. The Matrix CSV only carries percentages (no absolute GB, no host/VM breakdown, no host count) &mdash; it repopulates the Range Comparison Matrix below for trend viewing, but Sizing &amp; Savings will show \"No hardware profiles collected\" for those specific ranges since real capacity/host-count data isn't recoverable from percentages alone. Import does not require a Target Cluster Scope selection above; cluster/range names come from the files themselves.";
        } else {
            var isRvtools = sourceType === 'rvtools';
            document.getElementById('importPrimaryLabel').innerText = isRvtools ? "RVTools .xlsx workbooks or vHost CSV files (one or more)" : "Hosts CSV (required)";
            document.getElementById('importSecondaryLabel').innerText = isRvtools ? "Matching vMemory CSV files (optional; vInfo has no Active metric)" : "VMs CSV (optional)";
            tertiaryWrap.style.display = 'none';
            rangeLabelWrap.style.display = 'flex';
            infoBox.innerHTML = isRvtools ? "&#9432; Select complete RVTools workbooks, or one or more vHost CSV files and their matching vMemory CSV files. Every vCenter/datacenter/cluster is retained separately. Advanced Analytics and report scope All loaded clusters include all loaded clusters; the Assessment tables display the selected cluster. vInfo alone cannot supply Active Memory. Tiering and VM page settings remain unknown." : "&#9432; Imports MTAT Hosts/VMs CSV into the selected target cluster without querying vCenter.";
        }
    }

    function readFileAsText(file) {
        return new Promise(function(resolve, reject) {
            var reader = new FileReader();
            reader.onload = function() { resolve(reader.result); };
            reader.onerror = function() { reject(new Error("Could not read file: " + file.name)); };
            reader.readAsText(file);
        });
    }

    // Minimal RFC4180-style CSV parser (handles quoted fields, embedded commas, "" escapes).
    function parseCsvText(text) {
        text = text.replace(/^\uFEFF/, '');
        var rows = []; var row = []; var field = ''; var inQuotes = false;
        for (var i = 0; i < text.length; i++) {
            var c = text.charAt(i);
            if (inQuotes) {
                if (c === '"') {
                    if (text.charAt(i + 1) === '"') { field += '"'; i++; } else { inQuotes = false; }
                } else { field += c; }
            } else {
                // Per RFC 4180, a quote is only special as the very FIRST character of a field --
                // requiring the field to still be empty here means a raw quote appearing anywhere
                // else (e.g. a VM/host name like 7" Drive) is treated as a literal character instead
                // of incorrectly opening a quoted region and swallowing the rest of the row into it.
                if (c === '"' && field === '') { inQuotes = true; }
                else if (c === ',') { row.push(field); field = ''; }
                else if (c === '\r') { /* no-op, \n closes the row */ }
                else if (c === '\n') { row.push(field); field = ''; rows.push(row); row = []; }
                else { field += c; }
            }
        }
        if (field.length > 0 || row.length > 0) { row.push(field); rows.push(row); }
        // Drop rows that are entirely blank -- not just a single empty cell, but also a row padded
        // with commas to the full column count (e.g. ",,,,,,," from an Excel re-save) that would
        // otherwise become a real, fully-zeroed "phantom" host/VM row downstream with no warning.
        rows = rows.filter(function(r) { return r.some(function(cell) { return cell.trim() !== ''; }); });
        if (rows.length === 0) return [];

        var headers = rows[0].map(function(h) { return h.trim(); });
        var objects = [];
        for (var r = 1; r < rows.length; r++) {
            var obj = {};
            for (var c2 = 0; c2 < headers.length; c2++) {
                // If a header name repeats (or two blank headers exist), keep whichever column
                // filled it in first instead of letting a later duplicate silently overwrite it.
                if (obj.hasOwnProperty(headers[c2])) continue;
                obj[headers[c2]] = rows[r][c2] !== undefined ? rows[r][c2].trim() : '';
            }
            objects.push(obj);
        }
        return objects;
    }

    function normalizeToken(h) {
        return h.toLowerCase().replace(/[^a-z0-9]/g, '');
    }

    // parseFloat() alone truncates at the first non-numeric character -- "16,384" (a plausible
    // thousands-separated value from a locale-formatted Excel re-save) would silently become 16
    // instead of 16384. Strip thousands-separator commas first for every numeric CSV field.
    function parseNum(str) {
        if (str === undefined || str === null) return NaN;
        return parseFloat(String(str).replace(/,/g, ''));
    }

    // Builds a lookup where header names are matched loosely (case/space/punctuation-insensitive)
    // so small formatting differences between RVTools versions don't break parsing.
    function buildFuzzyRow(rowObj) {
        var map = {};
        for (var key in rowObj) { map[normalizeToken(key)] = rowObj[key]; }
        return map;
    }

    // Returns the first alias in the list that actually matches a column in this row. ORDER MATTERS:
    // when a row could plausibly satisfy more than one alias (e.g. RVTOOLS_VM_ALIASES.provisioned
    // lists genuine memory-size columns before anything else), the most correct/specific alias must
    // come first, since this stops at the first match rather than picking the "best" one. Reordering
    // or appending an alias here can silently change which column wins for existing exports -- no
    // test will catch a wrong-but-present column being preferred over the right one.
    function pickField(fuzzyRow, aliases) {
        for (var i = 0; i < aliases.length; i++) {
            var k = normalizeToken(aliases[i]);
            if (fuzzyRow[k] !== undefined && fuzzyRow[k] !== '') return fuzzyRow[k];
        }
        return undefined;
    }

    // Re-imports MTAT's own "Hosts CSV" / "VMs CSV" exports (see generateCsvString) so a prior
    // session can be reloaded without a live vCenter connection.
    // One host / VM row from an MTAT export (single-cluster CSV or the history bundle). CPU left
    // blank (data with no CPU figure, such as VCF Operations) stays N/A instead of becoming 0%. The
    // columns added in v3.2 (TierRatioPct, Active_Avg_GB, NVMe_GB, Missing_Metrics, DRAM_Only) are
    // read when present; "Pinned_Memory" from older exports meant a full reservation, which does not
    // keep memory in DRAM, so it is not carried over.
    function mtImportHostRow(r, clusterName) {
        var physRam = mtCsvGb(r, 'Physical_RAM') || 0, active = mtCsvGb(r, 'Active_GB') || 0;
        var cpuRaw = parseNum(r.CPU_Pct), ratio = parseNum(r.TierRatioPct), avg = mtCsvGb(r, 'Active_Avg_GB'), nvme = mtCsvGb(r, 'NVMe_GB'), mhz = parseNum(r.CPU_MHz);
        var activePct = parseNum(r.Active_Pct);
        if (isNaN(activePct)) activePct = physRam > 0 ? Math.round((active / physRam) * 1000) / 10 : 0;
        var h = {
            Cluster: clusterName, HostName: r.HostName || "", Tiering: r.Tiering || "Unknown", TierRatioPct: isNaN(ratio) ? 100 : ratio,
            CPU_Pct: isFinite(cpuRaw) && cpuRaw >= 0 && cpuRaw <= 100 ? cpuRaw : null, Physical_RAM: physRam, Consumed_GB: mtCsvGb(r, 'Consumed_GB') || 0, Active_GB: active, Active_Pct: activePct,
            Missing_Metrics: mtImportMissing(r), _ratioMissing: isNaN(ratio)
        };
        if (!isNaN(avg)) h.Active_Avg_GB = avg;
        if (!isNaN(nvme)) h.NVMe_GB = nvme;
        if (!isNaN(mhz) && mhz > 0) h.CPU_MHz = mhz;
        return h;
    }
    // Cluster CPU % like live collection: weighted by each host's CPU capacity when every host has it,
    // otherwise the plain average. acc: { sum, n, w, mhz, mhzN }.
    function mtCpuAdd(acc, h) {
        if (h.CPU_Pct === null || h.Tiering === "ERROR") return;
        acc.sum += h.CPU_Pct; acc.n++;
        if (typeof h.CPU_MHz === 'number' && h.CPU_MHz > 0) { acc.w += h.CPU_Pct * h.CPU_MHz; acc.mhz += h.CPU_MHz; acc.mhzN++; }
    }
    function mtCpuResult(acc) {
        if (!acc.n) return null;
        return Math.round(((acc.mhzN === acc.n && acc.mhz > 0) ? acc.w / acc.mhz : acc.sum / acc.n) * 10) / 10;
    }
    function mtImportMissing(r) {
        var miss = String(r.Missing_Metrics || "").split(/,\s*/).filter(Boolean);
        if (r.Tiering !== "ERROR") {
            if (isNaN(parseNum(r.Active_GB)) && miss.indexOf("Active") < 0) miss.push("Active");
            if (isNaN(parseNum(r.Consumed_GB)) && miss.indexOf("Consumed") < 0) miss.push("Consumed");
        }
        return miss.join(", ");
    }
    function mtImportVmRow(v, provisioned, vActive, vActivePct) {
        if (!isFinite(provisioned) || provisioned <= 0) {
            throw new Error('VM "' + (v.VMName || '(unnamed)') + '" has a missing or invalid Provisioned_GB value. Supply its configured memory before sizing.');
        }
        return {
            Host: v.Host || "", VMName: v.VMName || "", Provisioned_GB: provisioned, Active_GB: vActive,
            Active_Pct: vActivePct, DRAM_Only: v.DRAM_Only || "N/A", Pages_1GB: v.Pages_1GB || "N/A", Pages_2MB: v.Pages_2MB || "N/A",
            Missing_Metrics: v.Missing_Metrics || ""
        };
    }

    function parseMtatImport(hostsText, vmsText) {
        var hostRows = parseCsvText(hostsText);
        if (hostRows.length === 0) throw new Error("Hosts CSV appears to be empty or unreadable.");

        // Basic schema validation: this re-imports MTAT's OWN export format exactly (unlike the
        // fuzzy-matched RVTools path), so the expected column names are known precisely. Without
        // this check, dropping the wrong file (e.g. a VMs CSV into the Hosts CSV field) silently
        // produces a full table of zeroed-out hosts with no indication anything went wrong.
        var REQUIRED_HOST_COLUMNS = ["HostName", "Physical_RAM", "Consumed_GB", "Active_GB", "CPU_Pct"];
        var missingHostCols = REQUIRED_HOST_COLUMNS.filter(function(c) { return !hostRows[0].hasOwnProperty(c); });
        if (missingHostCols.length > 0) {
            throw new Error("This doesn't look like an MTAT Hosts CSV -- missing expected column(s): " + missingHostCols.join(", ") + ". Did you select the wrong file (e.g. a VMs CSV instead of a Hosts CSV)?");
        }

        var hosts = []; var warnings = [];
        var dramSum = 0, consumedSum = 0, activeSum = 0, cpuN = 0, avgSum = 0, avgN = 0, cpuAcc = { sum: 0, n: 0, w: 0, mhz: 0, mhzN: 0 };
        var anyTiered = false, ratioMissing = false;

        for (var i = 0; i < hostRows.length; i++) {
            var r = hostRows[i];
            var h0 = mtImportHostRow(r, r.Cluster || "");
            if (h0.Tiering === "Enabled") { anyTiered = true; if (h0._ratioMissing) ratioMissing = true; }
            delete h0._ratioMissing;
            hosts.push(h0);
            dramSum += h0.Physical_RAM; consumedSum += h0.Consumed_GB; activeSum += h0.Active_GB;
            mtCpuAdd(cpuAcc, h0); cpuN = cpuAcc.n;
            if (typeof h0.Active_Avg_GB === 'number') { avgSum += h0.Active_Avg_GB; avgN++; }
        }

        mtMarkMissingCpu(hosts);
        if (anyTiered && ratioMissing) warnings.push("Tiering ratio % is not included in this exported CSV and was defaulted to 100% for hosts already showing 'Enabled'.");
        if (avgN < hostRows.length) warnings.push("This exported CSV only retains the peak Active Memory figure, not a separate average, so Active Memory (Avg) will show as N/A.");
        if (cpuN === 0) warnings.push("This export has no CPU figures (for example data that came from VCF Operations), so CPU shows as N/A.");

        var vms = [], failedVmList = [];
        if (vmsText && vmsText.trim().length > 0) {
            var vmRows = parseCsvText(vmsText);
            if (vmRows.length > 0) {
                var REQUIRED_VM_COLUMNS = ["Host", "VMName", "Provisioned_GB", "Active_GB"];
                var missingVmCols = REQUIRED_VM_COLUMNS.filter(function(c) { return !vmRows[0].hasOwnProperty(c); });
                if (missingVmCols.length > 0) {
                    throw new Error("This doesn't look like an MTAT VMs CSV -- missing expected column(s): " + missingVmCols.join(", ") + ". Did you select the wrong file (e.g. a Hosts CSV instead of a VMs CSV)?");
                }
            }
            for (var j = 0; j < vmRows.length; j++) {
                var v = vmRows[j];
                if (String(v.Missing_Metrics || "").indexOf("Collection failed") >= 0) { failedVmList.push((v.Host || "") + "/" + (v.VMName || "")); continue; }
                var provisioned = mtCsvGb(v, 'Provisioned_GB');
                var vActive = mtCsvGb(v, 'Active_GB') || 0;
                var vActivePct = parseNum(v.Active_Pct);
                if (isNaN(vActivePct)) vActivePct = provisioned > 0 ? Math.round((vActive / provisioned) * 1000) / 10 : 0;
                vms.push(mtImportVmRow(v, provisioned, vActive, vActivePct));
            }
        }

        var out = {
            dram: mtRoundGb(dramSum), consumed: mtRoundGb(consumedSum), active: mtRoundGb(activeSum),
            cpu: mtCpuResult(cpuAcc),
            hosts: hosts, vms: vms, warnings: warnings, failedVms: failedVmList
        };
        if (cpuN === 0) out.cpuUnavailable = true;
        if (hostRows.length > 0 && avgN === hostRows.length) out.activeAvg = mtRoundGb(avgSum);
        return out;
    }

    var RVTOOLS_HOST_ALIASES = {
        host: ["Host", "Host Name", "ESXi Host"],
        cluster: ["Cluster"],
        memoryMiB: ["# Memory", "Memory", "Memory Size", "Total Memory"],
        cpuUsagePct: ["CPU usage %", "CPU usage%", "% CPU used"],
        memUsagePct: ["Memory usage %", "Memory usage%", "% Memory used"],
        numCores: ["# Cores", "NumCoresTotal", "Cores"],
        speedMhz: ["Speed", "CPU MHz", "CPU Speed"]
    };
    var RVTOOLS_VM_ALIASES = {
        vmName: ["VM", "VM Name"],
        host: ["Host"],
        active: ["Active", "Active(MB)", "Active MB", "Active MiB"],
        consumed: ["Consumed", "Consumed(MB)", "Consumed MB", "Consumed MiB"],
        // Deliberately does NOT include "Provisioned MB"/"In Use MB" -- those report the VM's
        // datastore/disk storage commitment in RVTools' vInfo.csv, not its configured RAM size.
        // Including either as a fallback here previously meant a VM whose real memory-size column
        // failed to match could silently adopt its (often 100-1000x larger) disk size as
        // "Provisioned_GB", producing a plausible-looking but meaningless near-zero Active %.
        provisioned: ["Size", "Memory", "Size MiB"],
        powerstate: ["Powerstate", "Power State"]
    };

    // Approximates a baseline from an RVTools export: vHost.csv supplies per-host DRAM/CPU/consumed,
    // and vMemory.csv supplies per-VM Active memory, summed per host. NOTE: vInfo.csv does NOT
    // actually carry per-VM Active/Consumed memory columns (only vMemory.csv does) -- if vInfo.csv
    // is supplied here instead, the alias-match tracking below correctly detects that and warns,
    // rather than silently reporting 0 GB as if it were real data. Memory Tiering state and 1GB/2MB
    // page config are ESXi-only facts RVTools does not capture, so those default to
    // "Unknown"/"N/A" rather than being guessed.
    function parseRvtoolsImport(hostText, vmText) {
        var hostRows = parseCsvText(hostText);
        if (hostRows.length === 0) throw new Error("vHost CSV appears to be empty or unreadable.");

        var vmRowsRaw = (vmText && vmText.trim().length > 0) ? parseCsvText(vmText) : [];
        var warnings = [];
        var vmActiveByHost = {}, vmConsumedByHost = {}, vmTableOut = [];
        // Track whether the Active/Consumed *columns themselves* were ever found, separate from
        // whether their parsed values happened to be 0 -- otherwise a genuinely missing/renamed
        // column (e.g. an RVTools version using "Active MiB" before that alias existed, or vInfo.csv
        // supplied in place of vMemory.csv) silently looks identical to "every VM is truly idle."
        var activeAliasMatched = false, consumedAliasMatched = false, powerstateAliasMatched = false;

        for (var j = 0; j < vmRowsRaw.length; j++) {
            var fv = buildFuzzyRow(vmRowsRaw[j]);
            var ps = pickField(fv, RVTOOLS_VM_ALIASES.powerstate);
            // If this column is never found, the poweredOn-only filter below silently never
            // triggers for ANY row (undefined always passes it) -- every VM, on or off, gets
            // counted, changing the aggregate's meaning with no indication anything's different.
            if (ps !== undefined) powerstateAliasMatched = true;
            if (ps !== undefined && normalizeToken(ps).indexOf("poweredon") === -1) continue;

            var vHostName = pickField(fv, RVTOOLS_VM_ALIASES.host) || "";
            var vActiveRaw = pickField(fv, RVTOOLS_VM_ALIASES.active);
            var vConsumedRaw = pickField(fv, RVTOOLS_VM_ALIASES.consumed);
            if (vActiveRaw !== undefined) activeAliasMatched = true;
            if (vConsumedRaw !== undefined) consumedAliasMatched = true;
            var vActiveMiB = parseNum(vActiveRaw) || 0;
            var vConsumedMiB = parseNum(vConsumedRaw) || 0;
            var vProvMiB = parseNum(pickField(fv, RVTOOLS_VM_ALIASES.provisioned)) || 0;
            var vName = pickField(fv, RVTOOLS_VM_ALIASES.vmName) || "";

            vmActiveByHost[vHostName] = (vmActiveByHost[vHostName] || 0) + vActiveMiB;
            vmConsumedByHost[vHostName] = (vmConsumedByHost[vHostName] || 0) + vConsumedMiB;

            var provGB = mtRoundGb(vProvMiB * 1048576 / 1e9);
            var actGB = mtRoundGb(vActiveMiB * 1048576 / 1e9);
            vmTableOut.push({
                Host: vHostName, VMName: vName, Provisioned_GB: provGB, Active_GB: actGB,
                Active_Pct: provGB > 0 ? Math.round((actGB / provGB) * 1000) / 10 : 0,
                DRAM_Only: "N/A", Pages_1GB: "N/A", Pages_2MB: "N/A"
            });
        }
        var haveVmActive = vmRowsRaw.length > 0 && activeAliasMatched;
        if (vmRowsRaw.length === 0) {
            warnings.push("No vMemory/vInfo file supplied - Active Memory defaulted to 0 GB for every host.");
        } else if (!activeAliasMatched) {
            warnings.push("Could not find an 'Active' memory column in the supplied VM file (vInfo.csv does not carry this -- vMemory.csv is required) - Active Memory defaulted to 0 GB for every host instead of being a real measurement.");
        }
        if (vmRowsRaw.length > 0 && !powerstateAliasMatched) {
            warnings.push("Could not find a 'Powerstate' column in the supplied VM file - powered-off VMs could not be excluded, so totals may include them.");
        }

        var hosts = []; var clusterName = "";
        var dramSum = 0, consumedSum = 0, activeSum = 0;
        var weightedCpuUsageMhzSum = 0, totalCpuMhzSum = 0, cpuPctFallbackSum = 0, missingMhzInfo = false, missingConsumedInfo = false;
        // Basic schema validation: a genuine vHost.csv always has a memory column. If it's missing
        // for every host, this almost certainly isn't a vHost export at all (wrong file selected) --
        // without this check, that case silently produces a full table of 0 GB hosts with no signal.
        var missingMemoryInfo = false, anyMemoryFound = false;

        for (var i = 0; i < hostRows.length; i++) {
            var fh = buildFuzzyRow(hostRows[i]);
            var hName = pickField(fh, RVTOOLS_HOST_ALIASES.host) || ("Host" + (i + 1));
            var hCluster = pickField(fh, RVTOOLS_HOST_ALIASES.cluster) || "";
            if (hCluster) clusterName = hCluster;

            var memRaw = pickField(fh, RVTOOLS_HOST_ALIASES.memoryMiB);
            if (memRaw === undefined) { missingMemoryInfo = true; } else { anyMemoryFound = true; }
            var memMiB = parseNum(memRaw) || 0;
            var dramGB = mtRoundGb(memMiB * 1048576 / 1e9);
            var cpuRawRv = parseNum(pickField(fh, RVTOOLS_HOST_ALIASES.cpuUsagePct)), cpuPct = isNaN(cpuRawRv) ? 0 : cpuRawRv;
            var memUsagePctRaw = pickField(fh, RVTOOLS_HOST_ALIASES.memUsagePct);
            var memUsagePct = parseNum(memUsagePctRaw);

            var numCores = parseNum(pickField(fh, RVTOOLS_HOST_ALIASES.numCores));
            var speedMhz = parseNum(pickField(fh, RVTOOLS_HOST_ALIASES.speedMhz));
            var hostTotalMhz = (!isNaN(numCores) && !isNaN(speedMhz)) ? (numCores * speedMhz) : NaN;
            if (isNaN(hostTotalMhz)) missingMhzInfo = true;

            var consumedGB;
            if (!isNaN(memUsagePct)) {
                consumedGB = Math.round((memUsagePct / 100) * dramGB * 100) / 100;
            } else if (consumedAliasMatched && vmConsumedByHost.hasOwnProperty(hName)) {
                consumedGB = mtRoundGb(vmConsumedByHost[hName] * 1048576 / 1e9);
            } else {
                consumedGB = 0; missingConsumedInfo = true;
            }

            // Figures the export does not carry are recorded as missing (shown as "No data", never a PASS).
            var rvMissing = ['TierConfig','Eligibility'];
            if (isNaN(cpuRawRv)) rvMissing.push("CPU");
            if (!haveVmActive) rvMissing.push("Active");
            if (isNaN(memUsagePct) && !(consumedAliasMatched && vmConsumedByHost.hasOwnProperty(hName))) rvMissing.push("Consumed");
            var activeGB = haveVmActive ? mtRoundGb((vmActiveByHost[hName] || 0) * 1048576 / 1e9) : 0;

            dramSum += dramGB; consumedSum += consumedGB; activeSum += activeGB; cpuPctFallbackSum += cpuPct;
            if (!isNaN(hostTotalMhz)) {
                totalCpuMhzSum += hostTotalMhz;
                weightedCpuUsageMhzSum += hostTotalMhz * (cpuPct / 100);
            }

            hosts.push({
                // TierRatioPct: 0 is a sentinel, not a real measurement -- RVTools has no way to
                // report a host's actual tiering ratio, so this stays 0 alongside Tiering:"Unknown"
                // rather than guessing 100% (which would misleadingly claim full knowledge).
                Cluster: hCluster, HostName: hName, Tiering: "Unknown", TierRatioPct: 0,
                CPU_Pct: Math.round(cpuPct * 10) / 10, Physical_RAM: dramGB, Consumed_GB: consumedGB,
                Active_GB: activeGB, Active_Pct: dramGB > 0 ? Math.round((activeGB / dramGB) * 1000) / 10 : 0,
                CPU_MHz: isNaN(hostTotalMhz) ? null : hostTotalMhz, Missing_Metrics: rvMissing.join(", ")
            });
        }

        if (!anyMemoryFound) {
            throw new Error("This doesn't look like an RVTools vHost.csv -- no memory column (e.g. '# Memory') was found for any host. Confirm you selected the vHost export, not vInfo/vMemory/vCluster.");
        }
        if (missingMemoryInfo) warnings.push("Could not find a memory column on the vHost export for one or more hosts - Physical RAM defaulted to 0 GB for those hosts.");
        if (missingConsumedInfo) warnings.push("Could not find a 'Memory usage %' column on the vHost export or matching VM consumed data - Consumed Memory defaulted to 0 GB for one or more hosts.");
        if (missingMhzInfo) warnings.push("Could not find per-host CPU core/speed columns - CPU% is a simple average across hosts rather than capacity-weighted.");

        for (var k = 0; k < hosts.length; k++) { if (!hosts[k].Cluster) hosts[k].Cluster = clusterName; }

        var cpuAvg;
        if (!missingMhzInfo && totalCpuMhzSum > 0) {
            cpuAvg = Math.round((weightedCpuUsageMhzSum / totalCpuMhzSum) * 1000) / 10;
        } else {
            cpuAvg = hostRows.length > 0 ? Math.round((cpuPctFallbackSum / hostRows.length) * 10) / 10 : 0;
        }

        vmTableOut.sort(function(a, b) { return b.Active_Pct - a.Active_Pct; });

        return {
            // RVTools captures one instantaneous snapshot per VM, not a time series, so "average" and
            // "peak" are the same single sample here (n=1) -- not an approximation.
            dram: mtRoundGb(dramSum), consumed: mtRoundGb(consumedSum), active: mtRoundGb(activeSum), activeAvg: mtRoundGb(activeSum),
            cpu: cpuAvg, hosts: hosts, vms: vmTableOut, warnings: warnings
        };
    }

    // LEGACY FALLBACK ONLY -- used by resolveClusterAndRange() below when a bundle predates the
    // dedicated Cluster/RangeName columns and only has the combined ClusterContext ("<clusterName>
    // (<rangeName>)") column to work with. This split is inherently ambiguous and NOT reliable in
    // general: it assumes cluster names never contain "(", but RangeName legitimately can (e.g.
    // "Past 7 Days (Matrix Import)"), so a cluster literally named e.g. "Production (DMZ)" will be
    // mis-split here. New exports avoid this entirely by writing Cluster/RangeName as their own
    // columns -- this function only exists to still import files created before that fix.
    function parseClusterContext(ctx) {
        ctx = ctx || "";
        var idx = ctx.indexOf(" (");
        if (idx === -1 || ctx.charAt(ctx.length - 1) !== ")") {
            return { clusterName: ctx.trim(), rangeName: "" };
        }
        return { clusterName: ctx.substring(0, idx).trim(), rangeName: ctx.substring(idx + 2, ctx.length - 1).trim() };
    }

    var MATRIX_CSV_ALIASES = {
        clusterScope: ["Target Cluster Scope"],
        rangeProfile: ["Analyzed Range Profile"],
        cpuPct: ["CPU Avg Pct", "CPU Peak Pct", "CPU Avg/Peak"],
        activePeakPct: ["Active Mem Peak Pct", "Active Memory Pct"],
        activeAvgPct: ["Active Mem Avg Pct"],
        consumedPct: ["Consumed Mem Avg Pct", "Consumed Memory Pct"],
        source: ["Source"]
    };

    // Re-imports a previously exported "Matrix CSV" (comparison_matrix_grouped.csv). That export only
    // ever contains PERCENTAGES per cluster+range -- no absolute GB, no per-host/VM breakdown, no host
    // count -- so this can restore the Range Comparison Matrix for trend viewing, but deliberately
    // returns hosts:[] / vms:[] so the Sizing & Savings tab correctly locks out instead of running
    // capacity math on fabricated numbers. dram is fixed at a reference value of 100 so percentages
    // round-trip exactly through the same rendering path live/full imports use (consumed/active are
    // stored as numbers equal to their own percentage, since pct/100*100 == pct). Column aliases cover
    // this tool's own header text as it's evolved across versions, so older exports still import.
    function parseMatrixCsv(text) {
        var rows = parseCsvText(text);
        var groups = [];
        var warnings = [];
        var missingActiveAvgCount = 0;

        for (var i = 0; i < rows.length; i++) {
            var fr = buildFuzzyRow(rows[i]);
            var clusterName = pickField(fr, MATRIX_CSV_ALIASES.clusterScope);
            var rangeName = pickField(fr, MATRIX_CSV_ALIASES.rangeProfile);
            if (!clusterName || !rangeName) continue;

            var cpuRaw = parseNum(pickField(fr, MATRIX_CSV_ALIASES.cpuPct)), cpuPct = isNaN(cpuRaw) ? null : cpuRaw;
            var activePeakPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.activePeakPct)) || 0;
            var activeAvgPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.activeAvgPct));
            var consumedPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.consumedPct)) || 0;
            if (isNaN(activeAvgPct)) missingActiveAvgCount++;

            var group = {
                clusterName: clusterName, rangeName: rangeName + " (Matrix Import)",
                dram: 100, consumed: consumedPct, active: activePeakPct, cpu: cpuPct, hosts: [], vms: [],
                source: pickField(fr, MATRIX_CSV_ALIASES.source) || ""
            };
            if (cpuPct === null) group.cpuUnavailable = true;
            if (!isNaN(activeAvgPct)) group.activeAvg = activeAvgPct;
            groups.push(group);
        }

        if (rows.length === 0) warnings.push("Matrix CSV appears to be empty or unreadable.");
        if (missingActiveAvgCount > 0) warnings.push("This Matrix CSV predates the 'Active Mem Avg' column -- " + missingActiveAvgCount + " row(s) will show Active Memory (Avg) as N/A.");
        if (groups.length > 0) warnings.push("Matrix CSV import has no host/VM breakdown or real capacity data -- Sizing & Savings will show 'No hardware profiles collected' for these ranges.");

        return { groups: groups, warnings: warnings };
    }

    // Re-imports the "All-Tables Bundle" export (all_evaluated_hosts_history.csv +
    // all_evaluated_vms_history.csv), which can contain many cluster+range combinations in one file.
    // Each combination gets the same full per-host/VM aggregation parseMtatImport does for a single
    // cluster, just grouped by its ClusterContext column instead of operating on one flat list.
    function parseHistoryBundle(hostsHistoryText, vmsHistoryText) {
        var groupsByKey = {};
        var order = [];
        var warnings = [];

        function getGroup(clusterName, rangeName, source) {
            var key = (source || "") + "::" + clusterName + "::" + rangeName;
            if (!groupsByKey[key]) {
                groupsByKey[key] = { clusterName: clusterName, rangeName: rangeName, source: source || "", hosts: [], vms: [], failedVms: [], dramSum: 0, consumedSum: 0, activeSum: 0, cpu: { sum: 0, n: 0, w: 0, mhz: 0, mhzN: 0 }, avgSum: 0, avgN: 0, hostCount: 0 };
                order.push(key);
            }
            return groupsByKey[key];
        }

        // A VM row with no Source (a VMs file from an earlier build) joins the one host group with the
        // same cluster and range, whatever its source; only when that is ambiguous does it stand alone.
        function groupForUnsourced(clusterName, rangeName) {
            var tail = "::" + clusterName + "::" + rangeName, hits = order.filter(function(k) { return k.slice(-tail.length) === tail; });
            return hits.length === 1 ? groupsByKey[hits[0]] : getGroup(clusterName, rangeName, "");
        }

        // Prefer the dedicated Cluster/RangeName columns (added specifically because no
        // string-parsing heuristic can reliably split a combined "ClusterName (RangeName)" string
        // back apart when EITHER side can contain a literal "(" -- see parseClusterContext's own
        // comment). Only fall back to that fragile split for older exported files from before those
        // two columns existed.
        function resolveClusterAndRange(row) {
            if (row.Cluster && row.RangeName) {
                return { clusterName: row.Cluster, rangeName: row.RangeName };
            }
            return parseClusterContext(row.ClusterContext);
        }

        if (hostsHistoryText && hostsHistoryText.trim().length > 0) {
            var hostRows = parseCsvText(hostsHistoryText);
            for (var i = 0; i < hostRows.length; i++) {
                var r = hostRows[i];
                var ctx = resolveClusterAndRange(r);
                if (!ctx.clusterName || !ctx.rangeName) continue;
                var g = getGroup(ctx.clusterName, ctx.rangeName, r.Source);

                var hb = mtImportHostRow(r, ctx.clusterName);
                delete hb._ratioMissing;
                g.hosts.push(hb);
                g.dramSum += hb.Physical_RAM; g.consumedSum += hb.Consumed_GB; g.activeSum += hb.Active_GB; g.hostCount++;
                // CPU averages only hosts that have a CPU figure and did not fail collection (ERROR rows are 0).
                mtCpuAdd(g.cpu, hb);
                if (typeof hb.Active_Avg_GB === 'number') { g.avgSum += hb.Active_Avg_GB; g.avgN++; }
            }
        }

        if (vmsHistoryText && vmsHistoryText.trim().length > 0) {
            var vmRows = parseCsvText(vmsHistoryText);
            for (var j = 0; j < vmRows.length; j++) {
                var v = vmRows[j];
                var vctx = resolveClusterAndRange(v);
                if (!vctx.clusterName || !vctx.rangeName) continue;
                var vg = v.Source ? getGroup(vctx.clusterName, vctx.rangeName, v.Source) : groupForUnsourced(vctx.clusterName, vctx.rangeName);
                if (String(v.Missing_Metrics || "").indexOf("Collection failed") >= 0) { vg.failedVms.push((v.Host || "") + "/" + (v.VMName || "")); continue; }

                var provisioned = mtCsvGb(v, 'Provisioned_GB');
                var vActive = mtCsvGb(v, 'Active_GB') || 0;
                var vActivePct = parseNum(v.Active_Pct);
                if (isNaN(vActivePct)) vActivePct = provisioned > 0 ? Math.round((vActive / provisioned) * 1000) / 10 : 0;

                vg.vms.push(mtImportVmRow(v, provisioned, vActive, vActivePct));
            }
        }

        if (order.length === 0) warnings.push("No recognizable rows found in the supplied history file(s). Expected a 'ClusterContext' column formatted like 'ClusterName (Range Name)'.");
        else if (order.some(function(k0) { var g0 = groupsByKey[k0]; return g0.hostCount > 0 && g0.avgN < g0.hostCount; })) warnings.push("These All-Tables History CSVs only retain the peak Active Memory figure, not a separate average, so Active Memory (Avg) will show as N/A for these ranges.");

        var groups = [];
        for (var k = 0; k < order.length; k++) {
            var grp = groupsByKey[order[k]];
            mtMarkMissingCpu(grp.hosts);
            var outGrp = {
                clusterName: grp.clusterName, rangeName: grp.rangeName, source: grp.source,
                dram: mtRoundGb(grp.dramSum), consumed: mtRoundGb(grp.consumedSum), active: mtRoundGb(grp.activeSum),
                cpu: mtCpuResult(grp.cpu),
                hosts: grp.hosts, vms: grp.vms, failedVms: grp.failedVms
            };
            if (grp.cpu.n === 0) outGrp.cpuUnavailable = true;
            if (grp.hostCount > 0 && grp.avgN === grp.hostCount) outGrp.activeAvg = mtRoundGb(grp.avgSum);
            groups.push(outGrp);
        }

        return { groups: groups, warnings: warnings };
    }

    // Each RVTools source is a snapshot. Keep source, datacenter and cluster boundaries intact.
    var rvtoolsSourceIds = Object.create(null), rvtoolsSourceCount = 0;
    function rvValue(row, aliases) { return pickField(buildFuzzyRow(row), aliases); }
    function rvContext(row) {
        return { vc:String(rvValue(row,['VI SDK Server','vCenter','vCenter Server','VC Server','VIServer'])||'').trim(),
            dc:String(rvValue(row,['Datacenter','Datacenter Name','Data Center'])||'').trim(),
            cluster:String(rvValue(row,['Cluster'])||'').trim() };
    }
    function rvFileStem(name) { return String(name).replace(/\.(csv|xlsx)$/i,'').replace(/(?:^|[._ -])v(?:host|memory|info)(?=$|[._ -])/ig,'').replace(/^[._ -]+|[._ -]+$/g,'').toLowerCase(); }
    function rvSheetRows(sheets, name) {
        var sh=sheets.filter(function(s){return s.name.trim().toLowerCase()===name.toLowerCase()})[0];
        if(!sh)return null;
        var aliases=name==='vHost'?RVTOOLS_HOST_ALIASES.host:RVTOOLS_VM_ALIASES.vmName;
        for(var i=0;i<Math.min(30,sh.rows.length);i++){
            var header=sh.rows[i],labels=Object.keys(header).map(function(k){return normalizeToken(String(header[k]))});
            if(!aliases.some(function(a){return labels.indexOf(normalizeToken(a))>=0}))continue;
            var rows=[];
            for(var j=i+1;j<sh.rows.length;j++){
                var row={};Object.keys(header).forEach(function(c){row[String(header[c])]=sh.rows[j][c]===undefined?'':sh.rows[j][c]});
                if(Object.keys(row).some(function(k){return row[k]!==''}))rows.push(row);
            }
            return rows;
        }
        throw Error('The '+name+' sheet has no recognized header in its first 30 rows.');
    }
    function rvProjectHost(row, cluster) {
        var out={},m={Host:'host',Cluster:'cluster','# Memory':'memoryMiB','CPU usage %':'cpuUsagePct','Memory usage %':'memUsagePct','# Cores':'numCores',Speed:'speedMhz'};
        Object.keys(m).forEach(function(k){var v=rvValue(row,RVTOOLS_HOST_ALIASES[m[k]]);if(v!==undefined)out[k]=v});out.Cluster=cluster;return out;
    }
    function rvProjectVm(row, host) {
        var out={},m={VM:'vmName',Host:'host',Powerstate:'powerstate',Active:'active',Consumed:'consumed',Size:'provisioned'};
        Object.keys(m).forEach(function(k){var v=rvValue(row,RVTOOLS_VM_ALIASES[m[k]]);if(v!==undefined)out[k]=v});out.Host=host;return out;
    }
    function rvRowsCsv(rows) {
        if(!rows.length)return '';
        var cols=[],seen=Object.create(null);rows.forEach(function(r){Object.keys(r).forEach(function(k){if(!seen[k]){seen[k]=true;cols.push(k)}})});
        return cols.map(csvField).join(',')+'\r\n'+rows.map(function(r){return cols.map(function(k){return csvField(r[k]===undefined?'':r[k])}).join(',')}).join('\r\n');
    }
    function rvSourceId(source) {
        if(typeof rvtoolsSourceIds==='undefined'){rvtoolsSourceIds=Object.create(null);rvtoolsSourceCount=0;}
        var inventory=source.hosts.map(function(row){var c=rvContext(row);return JSON.stringify([c.vc,c.dc,c.cluster,rvValue(row,RVTOOLS_HOST_ALIASES.host)])}).sort();
        var signature=JSON.stringify([source.name,inventory]);
        if(!rvtoolsSourceIds[signature])rvtoolsSourceIds[signature]=++rvtoolsSourceCount;
        return rvtoolsSourceIds[signature];
    }
    function rvBuildBatch(sources, vmFiles, rangeLabel, obfuscate) {
        var groups=[],registry=Object.create(null),warnings=[],outside=0;
        sources.forEach(function(source,si){
            if(!source.hosts.length)throw Error(source.name+': the vHost table is empty.');
            source.id=rvSourceId(source);source.stem=rvFileStem(source.name);var local=Object.create(null);
            source.hosts.forEach(function(row){
                var c=rvContext(row),host=String(rvValue(row,RVTOOLS_HOST_ALIASES.host)||'').trim();
                if(!host)throw Error(source.name+': a vHost row has no host name.');
                var cluster=c.cluster||'(no cluster)',identity=JSON.stringify([c.vc||('file:'+source.id),c.dc,cluster]),g=local[identity];
                if(!g){g=local[identity]={identity:identity,vc:c.vc,dc:c.dc,cluster:cluster,source:source,sourceIndex:si,hosts:[],memory:[],info:[],hostSeen:Object.create(null),vmSeen:Object.create(null)};groups.push(g)}
                var projected=rvProjectHost(row,cluster),canonical=host.toLowerCase();
                if(g.hostSeen[canonical]){if(JSON.stringify(g.hostSeen[canonical])!==JSON.stringify(projected))throw Error(source.name+': conflicting duplicate host '+host+'. Export one consistent snapshot.');return}
                g.hostSeen[canonical]=projected;g.hosts.push(projected);
                (registry[canonical]||(registry[canonical]=[])).push({group:g,host:host,context:c});
            });
        });
        function assign(rows, file, ownSource){
            rows.forEach(function(row){
                var ps=rvValue(row,RVTOOLS_VM_ALIASES.powerstate);if(ps!==undefined&&normalizeToken(String(ps)).indexOf('poweredon')<0)return;
                var host=String(rvValue(row,RVTOOLS_VM_ALIASES.host)||'').trim(),vc=rvContext(row),candidates=(registry[host.toLowerCase()]||[]).filter(function(x){
                    return (ownSource===null?x.group.source.vmRows===undefined:x.group.sourceIndex===ownSource)&&(!vc.vc||!x.context.vc||vc.vc.toLowerCase()===x.context.vc.toLowerCase())&&(!vc.dc||!x.context.dc||vc.dc===x.context.dc)&&(!vc.cluster||!x.context.cluster||vc.cluster===x.context.cluster);
                });
                if(candidates.length>1&&file.stem){var matched=candidates.filter(function(x){return x.group.source.stem&&x.group.source.stem===file.stem});if(matched.length)candidates=matched;}
                if(candidates.length>1)throw Error('VM rows for '+host+' match more than one export. Use complete RVTools workbooks, include vCenter identity columns, or give matching vHost/vMemory CSV files the same unique prefix.');
                if(!candidates.length){outside++;return}
                var target=candidates[0],g=target.group,projected=rvProjectVm(row,target.host),kind=file.kind;
                var uid=rvValue(row,['VM UUID','VM Instance UUID','VM ID','VMId','Instance UUID']);
                var identity=JSON.stringify([kind,host.toLowerCase(),uid||projected.VM||'']),previous=g.vmSeen[identity];
                // Duplicate VM names within a single table are valid; repeated files must not double count.
                if(previous&&previous.file!==file.token){if(previous.value===JSON.stringify(projected))return;throw Error('Conflicting VM snapshots overlap for '+host+'. Import each snapshot as a separate workbook or CSV batch.');}
                g.vmSeen[identity]={file:file.token,value:JSON.stringify(projected)};
                (kind==='memory'?g.memory:g.info).push(projected);
            });
        }
        sources.forEach(function(source,si){if(source.vmRows)assign(source.vmRows,{kind:source.vmKind,stem:source.stem,token:'workbook:'+si},si)});
        vmFiles.forEach(function(file,i){assign(file.rows,{kind:file.kind,stem:rvFileStem(file.name),token:'csv:'+i},null)});
        if(outside)warnings.push(outside+' powered-on VM rows were outside the supplied vHost scope and were not included.');
        var datasets=[],batchKeys=Object.create(null);
        groups.forEach(function(g){
            var parsed=parseRvtoolsImport(rvRowsCsv(g.hosts),rvRowsCsv(g.memory.length?g.memory:g.info));
            var label=g.cluster+' ['+(g.vc||('RVTools export '+g.source.id))+(g.dc?'; '+g.dc:'')+']';
            var key='RVTools|'+(obfuscate?obfName('cluster',label):label),range=(rangeLabel||'RVTools')+' - Snapshot '+g.source.id;
            if(batchKeys[JSON.stringify([key,range])])throw Error('Two exports have the same source identity and snapshot name. Select a single copy or use distinct source filenames.');
            batchKeys[JSON.stringify([key,range])]=true;
            parsed.source='rvtools';parsed.dataNotes=(parsed.warnings||[]).concat(warnings).concat(['RVTools is an inventory snapshot. Every source/datacenter/cluster is retained separately. Reports use the last selected snapshot for each cluster; snapshots of the same cluster are not added together.']);
            parsed.importMeta={files:[g.source.name],snapshot:g.source.id};
            if(obfuscate)renameParsedResult(parsed,obfName);
            datasets.push({key:key,range:range,data:parsed});
        });
        return {datasets:datasets,warnings:warnings};
    }
    function rvLoadCachedRanges(key) {
        var cache=clusterSessionCache[key];if(key.indexOf('RVTools|')!==0||!cache)return false;
        var ranges=Object.keys(cache.ranges),box=document.getElementById('rangeCheckboxes');
        box.innerHTML=ranges.map(function(range){return '<label class="checkbox-item"><input type="checkbox" class="range-cb" value="'+escapeHtml(range)+'" '+(range===cache.lastRange?'checked':'')+'> '+escapeHtml(range)+'</label>'}).join('');
        document.getElementById('selectAllToggle').innerText='Select All';
        if(cache.ranges[cache.lastRange])applyAnalysisResult(key,cache.lastRange,cache.ranges[cache.lastRange]);
        return true;
    }

    function processRvtoolsBatch() {
        var files=Array.prototype.slice.call(document.getElementById('importPrimaryFile').files||[]),vmFiles=Array.prototype.slice.call(document.getElementById('importSecondaryFile').files||[]);
        if(!files.length){showToast('Select RVTools .xlsx workbooks or vHost CSV files.','warn');return}
        var label=(document.getElementById('importRangeLabel').value||'').trim()||'RVTools',obfuscate=obfImportOn();
        var btn=document.getElementById('importProcessBtn'),status=document.getElementById('importStatusMsg');btn.disabled=true;btn.innerText='Importing...';
        var sources=[],vms=[],chain=Promise.resolve();
        files.forEach(function(file){chain=chain.then(function(){
            if(/\.xlsx$/i.test(file.name))return xlsxReadSheets(file).then(function(sheets){
                var hosts=rvSheetRows(sheets,'vHost');if(!hosts)throw Error(file.name+': no vHost worksheet found.');
                var memory=rvSheetRows(sheets,'vMemory'),info=memory===null?rvSheetRows(sheets,'vInfo'):null;
                sources.push({name:file.name,hosts:hosts,vmRows:memory===null?(info||[]):memory,vmKind:memory===null?'info':'memory'});
            });
            if(!/\.csv$/i.test(file.name))throw Error('Use RVTools .xlsx workbooks or CSV files; '+file.name+' is not supported.');
            return readFileAsText(file).then(function(text){var rows=parseCsvText(text);if(rows.length&&rvValue(rows[0],RVTOOLS_VM_ALIASES.vmName)!==undefined)throw Error(file.name+': this contains VM rows; select vHost CSV in the primary input.');sources.push({name:file.name,hosts:rows})});
        })});
        vmFiles.forEach(function(file){chain=chain.then(function(){
            if(!/\.csv$/i.test(file.name))throw Error('The optional VM input accepts vMemory/vInfo CSV files. Put complete workbooks in the primary input.');
            return readFileAsText(file).then(function(text){var rows=parseCsvText(text);if(rows.length&&rvValue(rows[0],RVTOOLS_VM_ALIASES.vmName)===undefined)throw Error(file.name+': no VM column found.');
                var memory=rows.some(function(row){return rvValue(row,RVTOOLS_VM_ALIASES.active)!==undefined});vms.push({name:file.name,rows:rows,kind:memory?'memory':'info'});
            });
        })});
        chain.then(function(){
            var result=rvBuildBatch(sources,vms,label,obfuscate);if(!result.datasets.length)throw Error('No RVTools host datasets were found.');
            var keys=[];
            result.datasets.forEach(function(entry){if(!clusterSessionCache[entry.key])clusterSessionCache[entry.key]={lastRange:'',ranges:{}};clusterSessionCache[entry.key].lastRange=entry.range;clusterSessionCache[entry.key].ranges[entry.range]=entry.data;if(keys.indexOf(entry.key)<0)keys.push(entry.key)});
            addSimClusterOptions(keys);
            var select=document.getElementById('clusterSelect');keys.forEach(function(key){if(!Array.prototype.some.call(select.options,function(o){return o.value===key})){var o=document.createElement('option');o.value=key;o.textContent=advClusterLabel(key);select.appendChild(o)}});
            var first=result.datasets[0];select.value=first.key;document.getElementById('simClusterSelect').value=first.key;
            rvLoadCachedRanges(first.key);
            document.getElementById('btn-tab-advanced').style.display='block';
            status.style.display='block';status.style.color='var(--text-success)';status.textContent='Imported '+sources.length+' RVTools source(s) into '+keys.length+' cluster(s) and '+result.datasets.length+' snapshot dataset(s). Advanced Analytics and report scope All loaded clusters include every loaded cluster. The selected-cluster tables show one cluster at a time.';
            btn.disabled=false;btn.innerText='Process Import';
        }).catch(function(err){showToast('RVTools import failed: '+err.message,'error');btn.disabled=false;btn.innerText='Process Import'});
    }

    function processImportFiles() {
        var sourceType = document.getElementById('importSourceType').value;
        if (sourceType === 'history') { processHistoryImport(); return; }
        if (sourceType === 'vrops') { processVropsImport(); return; }
        if (sourceType === 'rvtools') { processRvtoolsBatch(); return; }

        var activeClusterValue = document.getElementById('clusterSelect').value;
        if (!activeClusterValue) { 
            activeClusterValue = "Offline_Import|Offline_Cluster"; 
            if (!clusterSessionCache[activeClusterValue]) {
                var cSelect = document.getElementById('clusterSelect');
                var simSelect = document.getElementById('simClusterSelect');
                var optHtml = "<option value='" + activeClusterValue + "'>Offline_Cluster (Offline_Import)</option>";
                cSelect.innerHTML += optHtml;
                simSelect.innerHTML += optHtml;
                document.getElementById('clusterSelect').value = activeClusterValue;
            }
        }

        var primaryFile = document.getElementById('importPrimaryFile').files[0];
        var secondaryFile = document.getElementById('importSecondaryFile').files[0];
        var rangeLabel = (document.getElementById('importRangeLabel').value || "").trim() || "Imported Data";

        if (!primaryFile) {
            showToast(sourceType === 'rvtools' ? "Please choose an RVTools vHost CSV file." : "Please choose a Hosts CSV file.", 'warn');
            return;
        }

        var btn = document.getElementById('importProcessBtn');
        btn.disabled = true; btn.innerText = "Importing...";

        Promise.all([readFileAsText(primaryFile), secondaryFile ? readFileAsText(secondaryFile) : Promise.resolve("")]).then(function(texts) {
            var parsed = sourceType === 'rvtools' ? parseRvtoolsImport(texts[0], texts[1]) : parseMtatImport(texts[0], texts[1]);
            if (obfImportOn()) obfuscateParsedResult(parsed);
            if (!parsed.hosts || parsed.hosts.length === 0) throw new Error("No host rows could be parsed from the supplied file(s).");

            parsed.source = sourceType;
            applyAnalysisResult(activeClusterValue, rangeLabel, parsed);

            var statusDiv = document.getElementById('importStatusMsg');
            statusDiv.style.display = 'block';
            if (parsed.warnings && parsed.warnings.length > 0) {
                statusDiv.style.color = 'var(--text-warning-soft)';
                statusDiv.innerHTML = "[ ! ] Imported " + parsed.hosts.length + " host(s) as \"" + escapeHtml(rangeLabel) + "\" with notes:<br>- " + parsed.warnings.map(escapeHtml).join("<br>- ");
            } else {
                statusDiv.style.color = 'var(--text-success)';
                statusDiv.innerText = "[ OK ] Imported " + parsed.hosts.length + " host(s) successfully as \"" + rangeLabel + "\".";
            }
            btn.disabled = false; btn.innerText = "Process Import";
        }).catch(function(err) {
            showToast("Import failed: " + err.message, 'error');
            btn.disabled = false; btn.innerText = "Process Import";
        });
    }

    // Merges one imported {clusterName, rangeName, dram, consumed, active, activeAvg?, cpu, hosts, vms}
    // group into clusterSessionCache under a synthetic "Imported|<clusterName>" key -- the exported
    // history files never retain which vCenter server a cluster came from, so this can't be reliably
    // matched back to a live connection's "server|cluster" key, and guessing wrong could silently mix
    // two different clusters that merely share a name.
    function mergeImportedGroup(group) {
        var key = "Imported|" + group.clusterName;
        if (!clusterSessionCache[key]) { clusterSessionCache[key] = { lastRange: "", ranges: {} }; }
        clusterSessionCache[key].lastRange = group.rangeName;
        var entry = {
            dram: group.dram, consumed: group.consumed, active: group.active, cpu: group.cpu,
            hosts: group.hosts, vms: group.vms
        };
        if (group.failedVms && group.failedVms.length) entry.failedVms = group.failedVms;
        if (group.cpuUnavailable || typeof group.cpu !== 'number') entry.cpuUnavailable = true;
        if (group.source) clusterSessionCache[key].importSource = group.source;
        if (typeof group.activeAvg === 'number') { entry.activeAvg = group.activeAvg; }
        entry.source = 'history';
        clusterSessionCache[key].ranges[group.rangeName] = entry;
    }

    // Bulk-import path for Matrix CSV / All-Tables Bundle: unlike processImportFiles' single-result
    // path, a history file can carry many cluster+range combinations at once, so there's no single
    // "active" result to hand to applyAnalysisResult. Instead this merges every group directly into
    // clusterSessionCache, rebuilds the comparison matrix, and lets the user click into any cluster
    // (via the existing loadClusterFromCache flow) to drill into its checklist/tables/sizing.
    function processHistoryImport() {
        var matrixFile = document.getElementById('importPrimaryFile').files[0];
        var hostsHistoryFile = document.getElementById('importSecondaryFile').files[0];
        var vmsHistoryFile = document.getElementById('importTertiaryFile').files[0];

        if (!matrixFile && !hostsHistoryFile && !vmsHistoryFile) {
            showToast("Please choose at least one file: Matrix CSV, Hosts History CSV, or VMs History CSV.", 'warn');
            return;
        }

        var btn = document.getElementById('importProcessBtn');
        btn.disabled = true; btn.innerText = "Importing...";

        Promise.all([
            matrixFile ? readFileAsText(matrixFile) : Promise.resolve(""),
            hostsHistoryFile ? readFileAsText(hostsHistoryFile) : Promise.resolve(""),
            vmsHistoryFile ? readFileAsText(vmsHistoryFile) : Promise.resolve("")
        ]).then(function(texts) {
            var allGroups = [];
            var allWarnings = [];

            if (texts[0]) {
                var matrixResult = parseMatrixCsv(texts[0]);
                allGroups = allGroups.concat(matrixResult.groups);
                allWarnings = allWarnings.concat(matrixResult.warnings);
            }
            if (texts[1] || texts[2]) {
                var bundleResult = parseHistoryBundle(texts[1], texts[2]);
                allGroups = allGroups.concat(bundleResult.groups);
                allWarnings = allWarnings.concat(bundleResult.warnings);
            }

            if (allGroups.length === 0) throw new Error("No cluster/range data could be parsed from the supplied file(s).");

            // Exports since v3.2 carry a Source column (the vCenter each cluster came from). Clusters that
            // share a name but came from different sources are kept apart as "name (source)"; the
            // first source keeps the plain name if it is already loaded under it.
            // Loaded keys are aliased while Hide real names is on, and incoming names may or may not be
            // (a file exported with the switch on carries aliases), so both sides compare real names.
            function realCluster(n) { return deobfName('cluster', n); }
            function realSource(s) { return s ? deobfName('server', s) : s; }
            var srcByName = {};
            Object.keys(clusterSessionCache).forEach(function(k) {
                if (k.indexOf('Imported|') !== 0 || !clusterSessionCache[k].importSource) return;
                var real = realCluster(k.slice(9));
                (srcByName[real] = srcByName[real] || {})[realSource(clusterSessionCache[k].importSource)] = true;
            });
            function loadedImport(name) {
                var real = realCluster(name);
                return clusterSessionCache["Imported|" + name] || clusterSessionCache["Imported|" + real] || (obfImportOn() ? clusterSessionCache["Imported|" + obfName('cluster', real)] : null);
            }
            allGroups.forEach(function(g) { if (g.source) { g.source = realSource(g.source); var r0 = realCluster(g.clusterName); (srcByName[r0] = srcByName[r0] || {})[g.source] = true; } });
            allGroups.forEach(function(g) {
                if (!g.source || Object.keys(srcByName[realCluster(g.clusterName)] || {}).length < 2) return;
                var existing = loadedImport(g.clusterName);
                if (existing && realSource(existing.importSource) === g.source) return;
                var nm = g.clusterName + " (" + g.source + ")";
                g.clusterName = nm;
                (g.hosts || []).forEach(function(h) { h.Cluster = nm; });
            });

            var clusterNamesSeen = {};
            if (obfImportOn()) {
                allGroups.forEach(function(g) { g.clusterName = obfName('cluster', g.clusterName); obfuscateParsedResult(g); });
            }
            for (var i = 0; i < allGroups.length; i++) {
                mergeImportedGroup(allGroups[i]);
                clusterNamesSeen[allGroups[i].clusterName] = true;
            }

            document.getElementById('content-simulator').style.display = 'block';
            document.getElementById('metricsDisplayCard').style.display = 'block';
            document.getElementById('comparisonContainer').style.display = 'block';
            document.getElementById('hostContainerPanel').style.display = 'block';
            document.getElementById('vmContainerPanel').style.display = 'block';
            document.getElementById('btnExportAll').style.display = 'block';

            rebuildGroupedMatrix();

            var clusterCount = Object.keys(clusterNamesSeen).length;
            var summary = "Imported " + allGroups.length + " range(s) across " + clusterCount + " cluster(s). Click a cluster name in the Range Comparison Matrix below to view its detail.";
            var statusDiv = document.getElementById('importStatusMsg');
            statusDiv.style.display = 'block';
            if (allWarnings.length > 0) {
                statusDiv.style.color = 'var(--text-warning-soft)';
                statusDiv.innerHTML = "[ ! ] " + escapeHtml(summary) + "<br>- " + allWarnings.map(escapeHtml).join("<br>- ");
            } else {
                statusDiv.style.color = 'var(--text-success)';
                statusDiv.innerText = "[ OK ] " + summary;
            }
            btn.disabled = false; btn.innerText = "Process Import";
        }).catch(function(err) {
            showToast("Import failed: " + err.message, 'error');
            btn.disabled = false; btn.innerText = "Process Import";
        });
    }

    // ======================= VCF OPERATIONS (vROps) XLSX IMPORT =======================
    // Reads .xlsx directly in the browser (an xlsx is a zip of XML parts), with no libraries: the
    // zip central directory is walked by hand and each part is inflated with the built-in
    // DecompressionStream. Requires a current Chrome/Edge/Firefox/Safari.
    function xlsxOpen(file) {
        return file.arrayBuffer().then(function(ab) {
            var buf = new Uint8Array(ab), dv = new DataView(ab), eocd = -1;
            for (var i = buf.length - 22; i >= Math.max(0, buf.length - 65557); i--) {
                if (dv.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
            }
            if (eocd < 0) throw new Error(file.name + " is not a valid .xlsx file.");
            var count = dv.getUint16(eocd + 10, true), p = dv.getUint32(eocd + 16, true), entries = {}, td = new TextDecoder();
            for (var k = 0; k < count; k++) {
                if (dv.getUint32(p, true) !== 0x02014b50) break;
                var nlen = dv.getUint16(p + 28, true), xlen = dv.getUint16(p + 30, true), clen = dv.getUint16(p + 32, true);
                entries[td.decode(buf.subarray(p + 46, p + 46 + nlen))] = { method: dv.getUint16(p + 10, true), csize: dv.getUint32(p + 20, true), lho: dv.getUint32(p + 42, true) };
                p += 46 + nlen + xlen + clen;
            }
            function read(name) {
                var e = entries[name.replace(/^\//, '')];
                if (!e) return Promise.resolve(null);
                var start = e.lho + 30 + dv.getUint16(e.lho + 26, true) + dv.getUint16(e.lho + 28, true);
                var data = buf.subarray(start, start + e.csize);
                if (e.method === 0) return Promise.resolve(td.decode(data));
                if (e.method !== 8) return Promise.reject(new Error(file.name + ": unsupported compression in part " + name));
                if (typeof DecompressionStream === 'undefined') return Promise.reject(new Error("This browser cannot unzip .xlsx files (no DecompressionStream). Use a current Chrome, Edge, Firefox or Safari."));
                return new Response(new Blob([data]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).text();
            }
            return { read: read };
        });
    }
    function xmlUnescape(t) {
        return t.replace(/&(lt|gt|quot|apos|amp|#(\d+)|#x([0-9a-fA-F]+));/g, function(m, n, d, h) {
            if (d) return String.fromCharCode(parseInt(d, 10));
            if (h) return String.fromCharCode(parseInt(h, 16));
            return { lt: '<', gt: '>', quot: '"', apos: "'", amp: '&' }[n];
        });
    }
    function xmlAttr(tagText, name) {
        var m = new RegExp('(?:^|\\s)' + name + '="([^"]*)"').exec(tagText);
        return m ? xmlUnescape(m[1]) : null;
    }
    // Returns [{name, rows: [ {A: 'x', B: 'y', ...}, ... ]}] for every sheet in the workbook.
    function xlsxReadSheets(file) {
        return xlsxOpen(file).then(function(z) {
            return Promise.all([z.read('xl/workbook.xml'), z.read('xl/_rels/workbook.xml.rels'), z.read('xl/sharedStrings.xml')]).then(function(parts) {
                if (!parts[0]) throw new Error(file.name + " does not look like an Excel workbook.");
                var shared = [];
                if (parts[2]) {
                    var siRe = /<si>([\s\S]*?)<\/si>/g, tRe = /<t\b[^>]*>([\s\S]*?)<\/t>/g, m, tm;
                    while ((m = siRe.exec(parts[2])) !== null) {
                        var txt = ''; tRe.lastIndex = 0;
                        while ((tm = tRe.exec(m[1])) !== null) txt += tm[1];
                        shared.push(xmlUnescape(txt));
                    }
                }
                var targets = {}, relRe = /<Relationship\b([^>]*)\/?>/g, rm;
                while ((rm = relRe.exec(parts[1] || '')) !== null) targets[xmlAttr(rm[1], 'Id')] = xmlAttr(rm[1], 'Target');
                var sheets = [], shRe = /<sheet\b([^>]*)\/?>/g, sm;
                while ((sm = shRe.exec(parts[0])) !== null) {
                    var target = targets[xmlAttr(sm[1], 'r:id')] || '';
                    sheets.push({ name: xmlAttr(sm[1], 'name'), path: target.charAt(0) === '/' ? target.slice(1) : 'xl/' + target });
                }
                return Promise.all(sheets.map(function(sh) { return z.read(sh.path); })).then(function(xmls) {
                    return sheets.map(function(sh, i) { return { name: sh.name, rows: xlsxParseRows(xmls[i] || '', shared) }; });
                });
            });
        });
    }
    function xlsxParseRows(xml, shared) {
        var rows = [], rowRe = /<row\b[^>]*>([\s\S]*?)<\/row>/g, cellRe = /<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g, rm, cm;
        while ((rm = rowRe.exec(xml)) !== null) {
            var row = {}; cellRe.lastIndex = 0;
            while ((cm = cellRe.exec(rm[1])) !== null) {
                var ref = xmlAttr(cm[1], 'r'), type = xmlAttr(cm[1], 't'), inner = cm[2] || '';
                if (!ref) continue;
                var col = ref.replace(/\d+/g, ''), val = null, vm;
                if (type === 'inlineStr') { vm = /<t\b[^>]*>([\s\S]*?)<\/t>/.exec(inner); if (vm) val = xmlUnescape(vm[1]); }
                else if ((vm = /<v>([\s\S]*?)<\/v>/.exec(inner)) !== null) val = (type === 's') ? shared[parseInt(vm[1], 10)] : xmlUnescape(vm[1]);
                if (val !== null) row[col] = val;
            }
            rows.push(row);
        }
        return rows;
    }

    // Header aliases: raw VCF Operations metric keys first, then the friendly names a merged/renamed
    // export uses for the same columns (their "(GB)" labels are not trusted -- units are detected).
    // Ops accepts native UI labels as well as the original Input.xlsx metric-key layout.
    var VROPS_COLUMNS = {
        host: ['hostname', 'host', 'name', 'resource name', 'object name'],
        cluster: ['cluster', 'cluster name', 'parent cluster', 'summary|parentcluster', 'summary|parent cluster'],
        ts: ['timestamp', 'time', 'date time', 'datetime'],
        alloc: ['mem|memory_allocated_on_all_powered_on_vms', 'memory allocated on all powered on consumers', 'memory allocated on all powered on vms'],
        active: ['mem|active_average', 'guest active', 'active memory'],
        consumed: ['mem|consumed_average', 'consumed', 'consumed memory'],
        cap: ['mem|totalcapacity_average', 'capacity available to vms'],
        prov: ['mem|host_provisioned', 'total capacity', 'host provisioned', 'provisioned memory'],
        cpu: ['cpu|utilization_average', 'cpu|usage_average', 'cpu|capacity_usagepct_average', 'cpu|utilization', 'cpu|usage', 'cpu utilization', 'cpu usage', 'cpu_pct'],
        core: ['cpu|coreutilization_average', 'cpu|core utilization', 'cpu core utilization'],
        mhz: ['cpu|capacity_provisioned', 'cpu|totalcapacity_average', 'cpu|total capacity', 'cpu_mhz']
    };
    function vropsHeaderUnit(label) {
        var m = /\((bytes?|[kmgt]i?b|b)\)\s*$/i.exec(String(label).trim());
        return m ? m[1].toUpperCase() : '';
    }
    function vropsHeaderName(label) {
        return String(label).replace(/^\uFEFF/, '').trim().toLowerCase().replace(/^memory\s*\|\s*/, '')
            .replace(/\s*\((?:bytes?|[kmgt]i?b|b|%|mhz)\)\s*$/i, '').replace(/\s*\|\s*/g, '|').replace(/\s+/g, ' ').trim();
    }
    function vropsMapHeader(headerRow) {
        var byName = Object.create(null), originals = Object.create(null), map = { units: {} };
        Object.keys(headerRow).forEach(function(col) { var n = vropsHeaderName(headerRow[col]); byName[n] = col; originals[col] = headerRow[col]; });
        Object.keys(VROPS_COLUMNS).forEach(function(key) {
            for (var i = 0; i < VROPS_COLUMNS[key].length; i++) {
                var col = byName[VROPS_COLUMNS[key][i]];
                if (col !== undefined) { map[key] = col; var u = vropsHeaderUnit(originals[col]); map.units[key] = (u === 'GB' && !/^(?:memory\s*\||mem\|)/i.test(String(originals[col]).trim())) ? '' : u; break; }
            }
        });
        return map;
    }
    function vropsNumber(raw, percent) {
        if (typeof raw === 'number') return isFinite(raw) && raw >= 0 ? raw : NaN;
        var s = String(raw === null || raw === undefined ? '' : raw).trim();
        if (percent) s = s.replace(/\s*%$/, '').trim();
        if (!/^[+]?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?(?:e[+-]?\d+)?$/i.test(s)) return NaN;
        var n = Number(s.replace(/,/g, '')); return isFinite(n) && n >= 0 ? n : NaN;
    }
    function vropsMemoryGb(raw, unitPick, headerUnit) {
        if (raw === null || raw === undefined || String(raw).trim() === '') return NaN;
        var s = String(raw).trim(), m = /^(.*?)\s*(bytes?|[kmgt]i?b|b)\s*$/i.exec(s);
        var unit = m ? m[2].toUpperCase() : (headerUnit || ''), n = vropsNumber(m ? m[1] : raw, false);
        if (!isFinite(n)) return NaN;
        // VMware memory exports label binary source units KB/MB/GB/TB. Always render decimal GB.
        // An explicit suffix/header unit takes precedence; the selector applies to unitless cells.
        var factors = { B: 1e-9, BYTE: 1e-9, BYTES: 1e-9, KB: 1024 / 1e9, KIB: 1024 / 1e9,
            MB: 1048576 / 1e9, MIB: 1048576 / 1e9, GB: 1073741824 / 1e9, GIB: 1073741824 / 1e9,
            TB: 1099511627776 / 1e9, TIB: 1099511627776 / 1e9 };
        var value = unit ? (factors[unit] === undefined ? NaN : n * factors[unit]) : n / unitPick.div;
        return isFinite(value) && value >= 0 ? value : NaN;
    }
    function vropsNewContext(range, choice) {
        return { range: range || 'VCF Ops', choice: choice || 'auto', records: [], tags: Object.create(null), files: [], warnings: [], rows: 0, skipped: 0 };
    }
    function vropsMetricAdd(a, key, value, timed) {
        if (!isFinite(value) || value < 0) return;
        var q = a.metrics[key];
        if (!q || (timed && !q.timed)) q = a.metrics[key] = { n: 0, sum: 0, max: 0, timed: !!timed };
        if (q.timed && !timed) return;
        q.n++; q.sum += value; q.max = Math.max(q.max, value);
    }
    function vropsNewHost(host, cluster, source) {
        return { host: host, cluster: cluster, source: source, metrics: Object.create(null), first: Infinity, last: -Infinity, rows: 0, actualColumn: false, seriesActual: false };
    }
    function vropsAddWorkbook(ctx, fileName, sheets) {
        var found = null, fm = null, source = ctx.files.length; ctx.files.push(fileName);
        sheets.forEach(function(sh) {
            var limit = Math.min(sh.rows.length, 30);
            for (var hi = 0; hi < limit; hi++) {
                var header = sh.rows[hi], map = vropsMapHeader(header), names = Object.create(null);
                Object.keys(header).forEach(function(c) { names[vropsHeaderName(header[c])] = c; });
                if (names.tenant !== undefined && names.cluster !== undefined && !map.active) {
                    for (var tr = hi + 1; tr < sh.rows.length; tr++) {
                        var row = sh.rows[tr], cl = row[names.cluster]; if (!cl) continue;
                        ctx.tags[String(cl)] = { Tenant: row[names.tenant] || null, BOM: row[names.bom] || null, Datacenter: row[names.datacenter] || null, Fabric: row[names.fabric] || null };
                    }
                    ctx.tenantFile = fileName; ctx.tenantSheet = sh.name; break;
                }
                if (map.host && map.active && map.prov) {
                    var raw = Object.keys(header).some(function(c) { return String(header[c]).trim().toLowerCase() === 'mem|active_average'; });
                    if (!found || (raw && !found.raw)) { found = { sheet: sh, start: hi + 1, raw: raw }; fm = map; }
                    break;
                }
            }
        });
        if (!found) { ctx.warnings.push(fileName + ': no host metrics table found. Expected Name/HostName, Guest Active and Total Capacity; tenant mappings were retained if present.'); return; }
        var rows = found.sheet.rows, candidates = [];
        for (var i = found.start; i < rows.length; i++) {
            var rawProv = rows[i][fm.prov];
            if (typeof rawProv === 'number' || /^[+]?\d[\d,.eE+-]*$/.test(String(rawProv || '').trim())) {
                var n = vropsNumber(rawProv, false); if (n > 0) candidates.push(n);
            }
        }
        var pick = vropsDetectUnit(vropsMedian(candidates), ctx.choice), local = Object.create(null), missingCluster = false;
        if (candidates.length && pick.ambiguous && !fm.units.prov) ctx.warnings.push(fileName + ': unitless memory was interpreted as ' + pick.name + '. Select the source unit explicitly if needed.');
        for (var r = found.start; r < rows.length; r++) {
            var row = rows[r], hn = row[fm.host]; if (hn === null || hn === undefined || !String(hn).trim()) continue;
            hn = String(hn).trim();
            var prov = vropsMemoryGb(row[fm.prov], pick, fm.units.prov);
            if (!(prov > 0)) { ctx.skipped++; continue; }
            var cl = fm.cluster && row[fm.cluster] ? String(row[fm.cluster]).trim() : '(no cluster)';
            if (cl === '(no cluster)') missingCluster = true;
            var key = JSON.stringify([cl, hn]), a = local[key]; if (!a) a = local[key] = vropsNewHost(hn, cl, source);
            var ts = fm.ts ? vropsTimestampMs(row[fm.ts]) : NaN, timed = isFinite(ts);
            var values = {};
            ['active','consumed','alloc','cap'].forEach(function(k) { values[k] = fm[k] ? vropsMemoryGb(row[fm[k]], pick, fm.units[k]) : NaN; });
            values.cpu = fm.cpu ? vropsNumber(row[fm.cpu], true) : NaN;
            values.core = fm.core ? vropsNumber(row[fm.core], true) : NaN;
            values.mhz = fm.mhz ? vropsNumber(row[fm.mhz], false) : NaN;
            vropsMetricAdd(a, 'prov', prov, timed);
            Object.keys(values).forEach(function(k) { vropsMetricAdd(a, k, values[k], timed); });
            a.actualColumn = a.actualColumn || !!fm.consumed; a.rows++; ctx.rows++;
            if (timed) {
                a.first = Math.min(a.first, ts); a.last = Math.max(a.last, ts);
                var actual = isFinite(values.consumed), cons = actual ? values.consumed : values.alloc;
                if (actual && !a.seriesActual) { if (a.tsC) a.tsC.fill(0); a.seriesActual = true; }
                if (a.seriesActual && !actual) cons = NaN;
                if (isFinite(values.active)) vropsTsPut(a, Math.floor(ts / 3600000), values.active / (values.cap > 0 ? values.cap : prov) * 100,
                    isFinite(cons) ? cons / (values.cap > 0 ? values.cap : prov) * 100 : NaN);
            }
        }
        Object.keys(local).forEach(function(k) { ctx.records.push(local[k]); });
        if (missingCluster) ctx.warnings.push(fileName + ': missing cluster names will be matched by exact hostname to supplemental inventory where possible; unmatched hosts stay under (no cluster).');
    }
    function vropsMergeHost(a, b) {
        Object.keys(b.metrics).forEach(function(k) {
            var x = a.metrics[k], y = b.metrics[k];
            if (!x || (y.timed && !x.timed)) { a.metrics[k] = { n:y.n, sum:y.sum, max:y.max, timed:y.timed }; return; }
            if (x.timed && !y.timed) return;
            x.n += y.n; x.sum += y.sum; x.max = Math.max(x.max, y.max);
        });
        a.actualColumn = a.actualColumn || b.actualColumn; a.rows += b.rows;
        a.first = Math.min(a.first,b.first); a.last = Math.max(a.last,b.last);
        if (b.tsA) {
            if (b.seriesActual && !a.seriesActual) { if (a.tsC) a.tsC.fill(0); a.seriesActual = true; }
            for (var i = 0; i < b.tsA.length; i++) if (b.tsA[i]) {
                var cons = b.tsC[i] && (!a.seriesActual || b.seriesActual) ? b.tsC[i] - 1 : NaN;
                vropsTsPut(a, b.tsBase + i, (b.tsA[i] - 1) / 2.5, cons);
            }
        }
    }
    function vropsFinishImport(ctx, obfuscate) {
        if (!ctx.records.length) throw Error('No host rows could be read. ' + (ctx.skipped ? ctx.skipped + ' rows had missing or invalid host capacity. ' : '') + ctx.warnings.join(' '));
        var known = Object.create(null);
        ctx.records.forEach(function(a) { if (a.cluster !== '(no cluster)') (known[a.host] || (known[a.host] = Object.create(null)))[a.cluster] = true; });
        ctx.records.forEach(function(a) { var names = Object.keys(known[a.host] || {}); if (a.cluster === '(no cluster)' && names.length === 1) a.cluster = names[0]; });
        var timed = Object.create(null), overlap = false;
        ctx.records.forEach(function(a) {
            if (!isFinite(a.first)) return;
            var id = JSON.stringify([a.cluster,a.host]), prior = timed[id] || (timed[id] = []);
            prior.forEach(function(b) { if (a.source !== b.source && a.first <= b.last && b.first <= a.last) overlap = true; }); prior.push(a);
        });
        var parts = [], summaries = ctx.records.filter(function(a) { return !isFinite(a.first); });
        if (overlap) {
            var byFile = Object.create(null), seenTimed = Object.create(null);
            ctx.records.forEach(function(a) { if (isFinite(a.first)) { (byFile[a.source] || (byFile[a.source] = [])).push(a); seenTimed[JSON.stringify([a.cluster,a.host])] = true; } });
            Object.keys(byFile).forEach(function(source) {
                var rows = byFile[source], ids = Object.create(null); rows.forEach(function(a) { ids[JSON.stringify([a.cluster,a.host])] = true; });
                parts.push({ range: ctx.range + ' - Export ' + (Number(source)+1) + ' (' + new Date(rows.reduce(function(n,a){return Math.min(n,a.first)},Infinity)).toISOString().slice(0,10) + ' to ' + new Date(rows.reduce(function(n,a){return Math.max(n,a.last)},-Infinity)).toISOString().slice(0,10) + ')', rows: rows.concat(summaries.filter(function(a) { return ids[JSON.stringify([a.cluster,a.host])]; })) });
            });
            var remaining = summaries.filter(function(a) { return !seenTimed[JSON.stringify([a.cluster,a.host])]; });
            if (remaining.length) parts.push({ range: ctx.range + ' - Supplemental snapshot', rows: remaining });
            ctx.warnings.push('Overlapping historical files were kept as separate evaluation ranges. Supplemental summaries fill missing fields without being averaged into timestamped measurements.');
        } else parts.push({ range: ctx.range, rows: ctx.records });
        var datasets = [];
        parts.forEach(function(part) {
            var merged = Object.create(null);
            part.rows.forEach(function(a) { var id = JSON.stringify([a.cluster,a.host]); if (!merged[id]) merged[id] = vropsNewHost(a.host,a.cluster,a.source); vropsMergeHost(merged[id],a); });
            var first = Infinity, last = -Infinity;
            Object.keys(merged).forEach(function(k) { var a=merged[k]; if (a.tsA) { first=Math.min(first,a.tsBase); for(var i=a.tsA.length-1;i>=0;i--)if(a.tsA[i]) {last=Math.max(last,a.tsBase+i);break;} } });
            var n = isFinite(first) ? Math.min(last-first+1,24*400) : 0, groups=Object.create(null), partRowCount=part.rows.reduce(function(s,a){return s+a.rows;},0);
            Object.keys(merged).forEach(function(id) {
                var a=merged[id], m=a.metrics, ram=m.prov.max, cl=a.cluster, g=groups[cl];
                if(!g) g=groups[cl]={hosts:[],dram:0,active:0,activeAvg:0,consumed:0,bases:Object.create(null),first:Infinity,last:-Infinity};
                function avg(k){return m[k] && m[k].n ? m[k].sum/m[k].n : null;}
                var basis=m.consumed ? 'actual' : (!a.actualColumn && m.alloc ? 'allocated' : 'missing');
                var cons=basis==='actual'?avg('consumed'):(basis==='allocated'?avg('alloc'):null), cpu=avg('cpu'), active=m.active?m.active.max:0, tags=ctx.tags[cl]||{};
                var host={Cluster:cl,HostName:a.host,Tiering:'Unknown',TierRatioPct:0,Physical_RAM:mtRoundGb(ram),Consumed_GB:cons===null?0:mtRoundGb(cons),Consumed_Basis:basis,
                    Active_GB:mtRoundGb(active),Active_Avg_GB:m.active?mtRoundGb(avg('active')):null,Active_Pct:Math.round(active/ram*1000)/10,
                    CPU_Pct:cpu===null?null:Math.round(cpu*10)/10,CPU_Core_Pct:avg('core'),CPU_MHz:avg('mhz'),VM_Alloc_GB:avg('alloc'),Capacity_GB:avg('cap'),
                    Tenant:tags.Tenant||null,BOM:tags.BOM||null,Datacenter:tags.Datacenter||null,Fabric:tags.Fabric||null,
                    Missing_Metrics:[m.active?null:'Active',cons===null?'Consumed':null,'Capacity','TierConfig','Eligibility'].filter(Boolean).join(', ')};
                if(n && a.tsA){
                    var ta=new Uint8Array(n),tc=new Uint8Array(n);
                    for(var i=0;i<n;i++){var j=first+i-a.tsBase;if(j>=0&&j<a.tsA.length){ta[i]=a.tsA[j];tc[i]=a.tsC[j];}}
                    host._ts={act:ta,alloc:tc};
                    if(!g.tsSum){g.tsSum=new Float64Array(n);g.tsCnt=new Uint32Array(n);}
                    for(var i=0;i<n;i++)if(ta[i]){g.tsSum[i]+=(ta[i]-1)/2.5;g.tsCnt[i]++;}
                }
                g.hosts.push(host);g.dram+=ram;g.active+=active;g.activeAvg+=avg('active')||0;g.consumed+=cons||0;g.bases[basis]=true;
                g.first=Math.min(g.first,a.first);g.last=Math.max(g.last,a.last);
            });
            Object.keys(groups).forEach(function(cl){
                var g=groups[cl],cpus=g.hosts.filter(function(h){return h.CPU_Pct!==null;}),weighted=cpus.length===g.hosts.length&&cpus.every(function(h){return h.CPU_MHz>0;}),cpu=null;
                if(cpus.length){cpu=weighted?cpus.reduce(function(s,h){return s+h.CPU_Pct*h.CPU_MHz;},0)/cpus.reduce(function(s,h){return s+h.CPU_MHz;},0):cpus.reduce(function(s,h){return s+h.CPU_Pct;},0)/cpus.length;}
                if(cpus.length&&cpus.length<g.hosts.length)g.hosts.forEach(function(h){if(h.CPU_Pct===null)h.Missing_Metrics+=(h.Missing_Metrics?', ':'')+'CPU';});
                var bases=Object.keys(g.bases),basis=bases.length===1?bases[0]:'mixed';
                var notes=['Imported Ops workbooks; output memory is decimal GB. Explicit VMware KB/MB/GB/TB suffixes are converted per cell; unitless values use the selected/detected source unit.'];
                notes.push(basis==='actual'?'Consumed memory uses the actual consumed counter.':basis==='allocated'?'Consumed memory is an allocated-VM-memory proxy; actual consumed was not supplied.':'Consumed memory uses actual measurements where supplied, an allocated-memory proxy where explicitly available, and marks unavailable values as missing.');
                notes.push(cpu===null?'CPU utilization is unavailable; core utilization is displayed separately when supplied.':weighted?'Cluster CPU is weighted by host CPU capacity.':'Cluster CPU is an equal-host average because CPU capacities are unavailable. Missing host CPU data blocks refresh sizing.');
                notes.push('VM inventory, DRAM-only eligibility, page settings and physical tier breakdown are not established by these host exports. Host Total Capacity is used as the assessment denominator; confirm physical DRAM before sizing tiered hosts.');
                notes.push(isFinite(g.first)?'Active peak is the highest retained sample per host; active average uses the timestamped samples. Supplemental summary rows are not mixed into those averages. Timestamps without a timezone use this browser\'s local timezone.':'This is a summary snapshot. Its Active value cannot establish a historical peak or timeline.');
                var data={dram:mtRoundGb(g.dram),consumed:mtRoundGb(g.consumed),active:mtRoundGb(g.active),activeAvg:mtRoundGb(g.activeAvg),cpu:cpu===null?null:Math.round(cpu*10)/10,cpuUnavailable:cpu===null,
                    hosts:g.hosts,vms:[],source:'vrops',consumedBasis:basis,dataNotes:notes,
                    tsMeta:g.tsSum?{baseHour:first,n:n,clusterAct:(function(){var a=new Float32Array(n);for(var i=0;i<n;i++)a[i]=g.tsCnt[i]?g.tsSum[i]/g.tsCnt[i]:NaN;return a;})()}:null,
                    importMeta:{files:ctx.files.slice(),rows:partRowCount,minTs:isFinite(g.first)?g.first:null,maxTs:isFinite(g.last)?g.last:null,tenantFile:ctx.tenantFile||null,tenantSheet:ctx.tenantSheet||null}};
                if(obfuscate)renameParsedResult(data,obfName);
                datasets.push({cluster:obfuscate?obfName('cluster',cl):cl,range:part.range,data:data});
            });
        });
        if(ctx.skipped)ctx.warnings.push(ctx.skipped+' rows skipped because host capacity was blank, invalid or non-positive.');
        return {datasets:datasets,warnings:ctx.warnings,rows:ctx.rows};
    }
    function processVropsImport() {
        var files=Array.prototype.slice.call(document.getElementById('importPrimaryFile').files||[]);
        if(!files.length){showToast('Please choose one or more Ops .xlsx files.','warn');return;}
        var box=document.getElementById('importVropsUnits'),ctx=vropsNewContext((document.getElementById('importRangeLabel').value||'').trim(),box?box.value:'auto');
        var btn=document.getElementById('importProcessBtn'),status=document.getElementById('importStatusMsg'),obfuscate=obfImportOn();
        btn.disabled=true;btn.innerText='Importing...';status.style.display='block';status.style.color='var(--text-secondary)';
        var chain=Promise.resolve();files.forEach(function(file,i){chain=chain.then(function(){status.innerText='Reading '+file.name+' ('+(i+1)+' of '+files.length+')...';return xlsxReadSheets(file);}).then(function(sheets){vropsAddWorkbook(ctx,file.name,sheets);});});
        chain.then(function(){
            var result=vropsFinishImport(ctx,obfuscate),keys=[];
            result.datasets.forEach(function(entry){var key='VCF Ops|'+entry.cluster;if(!clusterSessionCache[key])clusterSessionCache[key]={lastRange:'',ranges:{}};
                clusterSessionCache[key].lastRange=entry.range;clusterSessionCache[key].ranges[entry.range]=entry.data;if(keys.indexOf(key)<0)keys.push(key);});
            addSimClusterOptions(keys);document.getElementById('content-simulator').style.display='block';document.getElementById('comparisonContainer').style.display='block';document.getElementById('btn-tab-advanced').style.display='block';rebuildGroupedMatrix();
            status.style.color=result.warnings.length?'var(--text-warning-soft)':'var(--text-success)';
            status.innerHTML=escapeHtml('Imported '+result.rows.toLocaleString()+' rows into '+result.datasets.length+' cluster/range datasets. Memory is decimal GB. Open Advanced Analytics or choose a range in the comparison matrix.')+
                (result.warnings.length?'<br>- '+result.warnings.map(escapeHtml).join('<br>- '):'');
            btn.disabled=false;btn.innerText='Process Import';
        }).catch(function(err){status.style.display='none';showToast('Import failed: '+err.message,'error');btn.disabled=false;btn.innerText='Process Import';});
    }

    function vropsDetectUnit(med, choice) {
        // Source units follow VMware's binary reporting convention unless decimal GB
        // is selected explicitly. Every result is converted to decimal GB.
        var units = { GB: 1, VMWARE_GB: 1 / MT_LEGACY_GB_FACTOR, MB: 1e9 / 1048576, KB: 1e9 / 1024 };
        var labels = { GB: 'GB', VMWARE_GB: 'VMware GB', MB: 'VMware MB', KB: 'VMware KB' };
        if (units[choice]) return { name: labels[choice], div: units[choice], ambiguous: false };
        var name = med >= 5e7 ? 'KB' : (med >= 49152 ? 'MB' : 'VMWARE_GB');
        var plausible = ['VMWARE_GB', 'MB', 'KB'].filter(function(u) { var gb = med / units[u]; return gb >= 16 * MT_LEGACY_GB_FACTOR && gb <= 49152 * MT_LEGACY_GB_FACTOR; });
        return { name: labels[name], div: units[name], ambiguous: name === 'VMWARE_GB' || plausible.length > 1 };
    }
    function vropsMedian(values) {
        if (!values.length) return 0;
        var s = values.slice().sort(function(a, b) { return a - b; });
        return s[Math.floor(s.length / 2)];
    }

    // VCF Operations timestamps: epoch milliseconds (the usual export), epoch seconds, or an Excel
    // date serial (days since 1899-12-30) if the sheet stored them as dates. Anything else is ignored.
    // Date strings (ISO "2026-08-04T13:00:00Z", "2026-08-04 13:00", "8/4/2026 1:00 PM") are parsed as
    // dates. Only a value that is a plain number goes through the numeric rules: parseFloat would
    // otherwise read just the year of an ISO date (2026) and the timestamp would be lost.
    function vropsTimestampMs(raw) {
        if (raw === null || raw === undefined) return NaN;
        var s = String(raw).trim();
        if (!s) return NaN;
        if (/^[+-]?\d+(\.\d+)?([eE][+-]?\d+)?$/.test(s)) {
            var v = parseFloat(s);
            if (v > 1e11) return v;
            if (v > 1e9) return v * 1000;
            if (v > 20000 && v < 80000) return Math.round((v - 25569) * 86400000);
            return NaN;
        }
        var d = Date.parse(s);
        if (isNaN(d) && /^\d{4}-\d{2}-\d{2} \d/.test(s)) d = Date.parse(s.replace(' ', 'T'));
        return isNaN(d) ? NaN : d;
    }
    // Per-host hourly series, stored compactly as one byte per hour (0 = no sample): Active % of
    // capacity in 0.4% steps, and memory allocated to VMs as % of capacity in 1% steps (up to 253%).
    // The highest sample within an hour wins. A 40,000-host, two-week export needs about 25 MB.
    function vropsTsPut(a, hr, actPct, allocPct) {
        if (!a.tsA) { a.tsBase = hr; a.tsA = new Uint8Array(64); a.tsC = new Uint8Array(64); }
        var idx = hr - a.tsBase, grow, nA, nC;
        if (idx < 0) {
            grow = -idx + 32; nA = new Uint8Array(a.tsA.length + grow); nC = new Uint8Array(a.tsA.length + grow);
            nA.set(a.tsA, grow); nC.set(a.tsC, grow); a.tsA = nA; a.tsC = nC; a.tsBase -= grow; idx = hr - a.tsBase;
        }
        if (idx >= a.tsA.length) {
            var len = a.tsA.length; while (len <= idx) len *= 2;
            nA = new Uint8Array(len); nC = new Uint8Array(len); nA.set(a.tsA); nC.set(a.tsC); a.tsA = nA; a.tsC = nC;
        }
        var qa = Math.min(254, Math.max(0, Math.round(actPct * 2.5))) + 1;
        if (qa > a.tsA[idx]) a.tsA[idx] = qa;
        if (!isNaN(allocPct)) { var qc = Math.min(254, Math.max(0, Math.round(allocPct))) + 1; if (qc > a.tsC[idx]) a.tsC[idx] = qc; }
    }


    // Imported clusters have no live <option> in the Sizing dropdown; add one per key (once).
    function addSimClusterOptions(keys) {
        var simSelect = document.getElementById('simClusterSelect'), have = {};
        for (var i = 0; i < simSelect.options.length; i++) have[simSelect.options[i].value] = true;
        var frag = document.createDocumentFragment();
        keys.forEach(function(k) {
            if (have[k]) return;
            var o = document.createElement('option'); o.value = k; o.textContent = advClusterLabel(k); frag.appendChild(o);
        });
        simSelect.appendChild(frag);
    }
</script>
</body>
</html>
'@

# ==========================================
# --- WEB ROUTING PROCESSING ENGINE -------
# ==========================================
$finalHtml = $htmlContent.Replace("##LOGO_HTML_PLACEHOLDER##", $LogoHtmlInjection)

$lastHeartbeat = Get-Date
$uiConnected = $false

while ($listener.IsListening) {
    # BeginGetContext/EndGetContext are bare .NET calls -- they can throw (a client aborting
    # mid-request, a malformed request, or a listener-lifecycle race), and unlike every other
    # listener operation in this file, an uncaught exception here isn't scoped to one request --
    # it would unwind straight out of this while loop and kill the whole engine process for every
    # connected user. Caught here specifically so one bad connection attempt can't take down the
    # rest of the session.
    try {
        $contextAsync = $listener.BeginGetContext($null, $null)

        while (-not $contextAsync.IsCompleted) {
            Start-Sleep -Milliseconds 200
            Update-VersionCheckJobStatus
            Update-MtatJobs
            if ($global:MtatActiveJob) { $lastHeartbeat=Get-Date }
            $secondsSincePulse = ((Get-Date) - $lastHeartbeat).TotalSeconds

            # Dead-Man's Switch: If UI is connected but drops pulse for 10 minutes (600s), exit cleanly
            if ($uiConnected -and $secondsSincePulse -gt 600) {
                Write-DebugLog "[+] UI Heartbeat lost for 10 minutes. Safely shutting down engine."
                try { $listener.Stop(); $listener.Close() } catch {}
                [Environment]::Exit(0)
            }

            # Initial Grace Period: If UI never connects within 60 seconds of launch, self-terminate
            if (-not $uiConnected -and $secondsSincePulse -gt 60) {
                Write-DebugLog "[-] UI never connected within 60 seconds. Timeout reached. Shutting down."
                try { $listener.Stop(); $listener.Close() } catch {}
                [Environment]::Exit(0)
            }
        }

        $context = $listener.EndGetContext($contextAsync)
    } catch {
        Write-DebugLog "[-] HTTP listener context error (non-fatal, waiting for next connection): $(Get-FullExceptionText $_)"
        if (-not $listener.IsListening) {
            Write-DebugLog "[-] Listener is no longer listening after that error -- exiting the request loop."
            break
        }
        continue
    }

    try {
        $req = $context.Request
        $res = $context.Response
        $rawPath = $req.Url.LocalPath.ToLower().Trim('/')
        
        # Browsers send an Origin header on POSTs. Only this page (served from http://127.0.0.1:<port>)
        # may drive the engine; without this, any other web page open in the same browser could send
        # /api/shutdown (or /api/connect, /api/analyze) to it. Requests with no Origin header (not from
        # a browser) are unaffected.
        $reqOrigin = $req.Headers["Origin"]
        $originRejected = ($req.HttpMethod -eq "POST" -and -not [string]::IsNullOrEmpty($reqOrigin) -and $reqOrigin -ne "http://127.0.0.1:$targetPort" -and $reqOrigin -ne "http://localhost:$targetPort")
        if ($originRejected) {
            Write-DebugLog "[!] Rejected a POST to '$rawPath' sent from another web page ($reqOrigin)."
            $res.StatusCode = 403
            $res.Close()
        }
        elseif ($req.HttpMethod -eq "GET" -and ($rawPath -eq "" -or $rawPath -eq "index.html")) {
            $uiConnected = $true
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($finalHtml)
            $res.ContentType = "text/html"
            $res.ContentLength64 = $buffer.Length
            $res.OutputStream.Write($buffer, 0, $buffer.Length)
            $res.Close()
        }
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/heartbeat") {
            $uiConnected = $true
            $res.StatusCode = 200
            $res.Close()
        }
        elseif ($req.HttpMethod -eq "GET" -and $rawPath -eq "api/ping") {
            $uiConnected = $true
            $res.StatusCode = 200
            $res.Close()
        }
        elseif ($req.HttpMethod -eq "GET" -and $rawPath -eq "api/get-debug-log") {
            # Lets the "Download Debug Log" button in the UI retrieve this run's log even when
            # compiled with -noConsole (no visible window to read it from otherwise).
            try {
                if (Test-Path $LogFilePath) {
                    $logContent = Get-Content -Path $LogFilePath -Raw -ErrorAction Stop
                    Send-JsonResponse -Response $res -Object @{ content = $logContent; path = $LogFilePath }
                } else {
                    Send-JsonResponse -Response $res -Object @{ content = ""; path = $LogFilePath; error = "Log file does not exist yet." }
                }
            } catch {
                Send-JsonResponse -Response $res -Object @{ error = (Add-KnownIssueHints (Get-FullExceptionText $_)) }
            }
        }
        elseif ($req.HttpMethod -eq "GET" -and $rawPath -eq "api/get-version-info") {
            # Polled by both the splash screen (file:// origin, hence -AllowCrossOrigin) and the
            # main UI, so version info is never lost even if the redirect wins the race against
            # the background check finishing.
            Update-VersionCheckJobStatus
            Send-JsonResponse -Response $res -Object $global:LatestVersionInfo -AllowCrossOrigin
        }
        elseif ($req.HttpMethod -eq 'POST' -and $rawPath -like 'api/jobs/*') {
            try {
                Update-MtatJobs
                $reader=New-Object IO.StreamReader($req.InputStream,[Text.Encoding]::UTF8)
                try { $text=$reader.ReadToEnd();if($text.Length -gt 131072){throw 'Job request too large.'};$payload=if($text.Trim()){$text|ConvertFrom-Json}else{[pscustomobject]@{}} } finally { $reader.Dispose() }
                $answer=switch($rawPath){
                    'api/jobs/start' {New-MtatJob $payload}
                    'api/jobs/status' {Get-MtatJobStatus ([string]$payload.id)}
                    'api/jobs/cancel' {Stop-MtatJob ([string]$payload.id)}
                    'api/jobs/resume' {Resume-MtatJob $payload}
                    'api/jobs/result' {Get-MtatJobResult ([string]$payload.id) ([int]$payload.index)}
                    'api/jobs/log' {
                        [void](Get-MtatJobMetadata ([string]$payload.id));$logPath=Join-Path (Get-MtatJobFolder ([string]$payload.id)) 'worker.log'
                        @{content=if(Test-Path -LiteralPath $logPath){Get-Content -LiteralPath $logPath -Raw -Encoding UTF8}else{''}}
                    }
                    'api/jobs/list' {
                        $root=Join-Path $MtatDataRoot 'Jobs';$items=@()
                        if(Test-Path -LiteralPath $root){foreach($folder in @(Get-ChildItem -LiteralPath $root -Directory|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 30)){
                            if($folder.Name -notmatch '^[a-f0-9]{32}$'){continue}
                            try{$j=Get-MtatJobStatus $folder.Name;$items+=@{id=$j.id;status=$j.status;createdUtc=$j.createdUtc;completed=@($j.tasks|Where-Object{$_.status -eq 'completed'}).Count;total=@($j.tasks).Count}}catch{}
                        }}
                        @{jobs=$items}
                    }
                    default {throw 'Unknown job endpoint.'}
                }
                Send-JsonResponse -Response $res -Object $answer
            } catch {Send-JsonResponse -Response $res -Object @{error=$_.Exception.Message}}
        }
        elseif ($req.HttpMethod -eq 'GET' -and $rawPath -eq 'api/jobs/download') {
            try {
                $jobId=[string]$req.QueryString['id'];$index=[int]$req.QueryString['index'];$metadata=Get-MtatJobMetadata $jobId;$entry=@($metadata.tasks|Where-Object{$_.index -eq $index -and $_.status -eq 'completed'});if($entry.Count -ne 1){throw 'Checkpoint is not complete.'}
                $path=Join-Path (Get-MtatJobFolder $jobId) ('result_'+$index+'.json')
                if($entry[0].digest -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry[0].digest){throw 'Checkpoint integrity check failed.'}
                $res.ContentType='application/json; charset=utf-8';$res.Headers['Content-Disposition']='attachment; filename="MTAT_checkpoint_'+$jobId+'_'+$index+'.json"'
                $res.ContentLength64=(Get-Item -LiteralPath $path).Length
                $file=[IO.File]::OpenRead($path);try{$file.CopyTo($res.OutputStream)}finally{$file.Dispose();$res.OutputStream.Close()}
            }catch{Send-JsonResponse -Response $res -Object @{error=$_.Exception.Message}}
        }
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/shutdown") {
            # User clicked the explicit Exit Engine button
            Write-DebugLog "[+] Manual shutdown signal received. Terminating."
            if ($global:MtatActiveJob) {
                $active=$global:MtatActiveJob;[void](Stop-MtatJob $active.Id)
                if(-not $active.Process.WaitForExit(3000)){try{$active.Process.Kill()}catch{}}
                Update-MtatJobs
            }
            Close-MtatOpsSessions
            Send-JsonResponse -Response $res -Object @{ status = "shutdown" }
            try { $listener.Stop(); $listener.Close() } catch {}
            [Environment]::Exit(0)
        }
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/ops/connect") {
            try {
                if ($global:MtatActiveJob) { throw 'Cancel or finish the active job before reconnecting.' }
                $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
                try { $payload = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                $opsConnection = Connect-MtatOps $payload
                Write-DebugLog "[ops] Connected to $($opsConnection.version); $(@($opsConnection.clusters).Count) clusters visible."
                Send-JsonResponse -Response $res -Object $opsConnection
            } catch {
                Write-DebugLog "[ops] Connection failed: $($_.Exception.Message)"
                Send-JsonResponse -Response $res -Object @{ error = $_.Exception.Message }
            }
        }
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/connect") {
            Write-DebugLog "[->] Inbound route match hit on api/connect."
            try {
                if ($global:MtatActiveJob) { throw 'Cancel or finish the active job before reconnecting.' }
                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
                $payload = $body | ConvertFrom-Json

                if (-not (Get-Command Connect-VIServer -ErrorAction SilentlyContinue)) { throw 'Direct vCenter connections require VMware.PowerCLI. Ops connections and offline imports do not.' }
                # Optional strict certificate checking (the "Require valid vCenter certificates" box on
                # the Connection tab). Off by default because most vCenters use self-signed certificates
                # (see the note at Set-PowerCLIConfiguration near the top of this script).
                $certAction = if ($payload.requireValidCerts -eq $true) { "Fail" } else { "Ignore" }
                Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction $certAction -Confirm:$false -ErrorAction Stop | Out-Null
                Write-DebugLog "[connect] vCenter certificate checking: $(if ($certAction -eq 'Fail') { 'required (untrusted or self-signed certificates are refused)' } else { 'not enforced' })."

                # One bad target (wrong credentials, unreachable host) previously aborted the ENTIRE
                # request -- even targets that already connected successfully lost their cluster
                # listing on this response. Isolated per-target so a single failure is reported back
                # without discarding sessions that DID connect.
                $failedTargets = New-Object System.Collections.Generic.List[PSObject]
                foreach ($target in $payload.targets) {
                    $srv = $target.server
                    $user = $target.user
                    $pass = $target.pass

                    $existingSession = $null
                    if ($null -ne $global:DefaultVIServers) {
                        $existingSession = $global:DefaultVIServers | Where-Object { $_.Name -eq $srv } | Select-Object -First 1
                    }

                    if (-not $global:MtatWorkerCredentials) { $global:MtatWorkerCredentials=@{} }
                    $workerSecure=ConvertTo-SecureString ([string]$pass) -AsPlainText -Force
                    $workerCredential=New-Object Management.Automation.PSCredential([string]$user,$workerSecure)
                    $workerServerName=if($existingSession){[string]$existingSession.Name}else{[string]$srv}
                    $global:MtatWorkerCredentials[$workerServerName]=@{Credential=$workerCredential;RequireValidCerts=($payload.requireValidCerts -eq $true)}
                    if ($null -ne $existingSession) {
                        # A session can still be listed in $global:DefaultVIServers while actually
                        # dead (expired token, network drop) -- PowerCLI doesn't always proactively
                        # notice this. Blindly trusting the listing here previously meant a dead
                        # session was never retried, silently locking the user out of that vCenter
                        # until they restarted the whole engine. Verify it still genuinely works with
                        # a trivial read before trusting it.
                        $sessionStillAlive = $false
                        try {
                            [void](Get-View ServiceInstance -Server $existingSession -ErrorAction Stop)
                            $sessionStillAlive = $true
                        } catch {
                            Write-DebugLog "[connect] Existing session to '$srv' appears dead ($(Get-FullExceptionText $_)) -- disconnecting and reconnecting."
                            try { Disconnect-VIServer -Server $existingSession -Confirm:$false -ErrorAction SilentlyContinue } catch {}
                        }
                        # A session opened before "Require valid vCenter certificates" was ticked never had
                        # its certificate checked, so with the option on it is reconnected to check it now.
                        if ($sessionStillAlive -and $certAction -eq "Fail") {
                            Write-DebugLog "[connect] Reconnecting to '$srv' so its certificate is checked (Require valid vCenter certificates is on)."
                            try { Disconnect-VIServer -Server $existingSession -Confirm:$false -ErrorAction SilentlyContinue } catch {}
                            $sessionStillAlive = $false
                        }
                        if ($sessionStillAlive) { continue }
                    }

                    try {
                        $workerConnected = Connect-VIServer -Server $srv -User $user -Password $pass -WarningAction SilentlyContinue -ErrorAction Stop
                        $global:MtatWorkerCredentials[[string]$workerConnected.Name]=@{Credential=$workerCredential;RequireValidCerts=($payload.requireValidCerts -eq $true)}
                    } catch {
                        Write-DebugLog "[connect] WARNING: could not connect to vCenter '$srv' -- excluded from this session, other targets still attempted: $(Get-FullExceptionText $_)"
                        $failedTargets.Add([PSCustomObject]@{ server = $srv; error = (Add-KnownIssueHints (Get-FullExceptionText $_)) })
                    }
                }

                $clusterList = New-Object System.Collections.Generic.List[PSObject]
                # Cluster names only need to be unique within a datacenter, so one vCenter can have two
                # "Production" clusters. Those get their datacenter (or, failing that, the cluster ID) added
                # to the label, and every label is mapped to the cluster's ID, so analysis reads exactly
                # the cluster that was picked rather than the first name match.
                if ($null -eq $global:ClusterKeyMap) { $global:ClusterKeyMap = @{} }
                foreach ($server in $global:DefaultVIServers) {
                    $serverClusters = @(Get-Cluster -Server $server -ErrorAction SilentlyContinue)
                    $nameCounts = Get-NameCounts $serverClusters
                    # Every name that is already unique is reserved first, so a generated label can never
                    # take a real cluster's name (and with it that cluster's ID mapping).
                    $usedLabels = @{}
                    foreach ($c in $serverClusters) { if ($nameCounts[[string]$c.Name] -eq 1) { $usedLabels[[string]$c.Name] = $true } }
                    foreach ($c in $serverClusters) {
                        $label = [string]$c.Name
                        if ($nameCounts[$label] -gt 1) {
                            $dcName = $null
                            try { $dcName = (Get-Datacenter -Cluster $c -Server $server -ErrorAction Stop | Select-Object -First 1).Name } catch {}
                            $label = if ($dcName) { "$($c.Name) [$dcName]" } else { "$($c.Name) [$($c.Id)]" }
                            if ($usedLabels.ContainsKey($label)) { $label = "$($c.Name) [$($c.Id)]" }
                            $labelBase = $label; $labelN = 2
                            while ($usedLabels.ContainsKey($label)) { $label = "$labelBase #$labelN"; $labelN++ }
                        }
                        $usedLabels[$label] = $true
                        $global:ClusterKeyMap["$($server.Name)|$label"] = [string]$c.Id
                        $clusterList.Add([PSCustomObject]@{
                            Value = "$($server.Name)|$label"
                            Text  = "$label ($($server.Name))"
                        })
                    }
                }

                Send-JsonResponse -Response $res -Object @{ clusters = $clusterList; failedTargets = @($failedTargets) }
            } catch {
                Send-JsonResponse -Response $res -Object @{ error = (Add-KnownIssueHints (Get-FullExceptionText $_)) }
            }
        }
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/get-cluster-ranges") {
            try {
                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
                $payload = $body | ConvertFrom-Json

                $clusterComposite = $payload.cluster
                if ([string]$clusterComposite -like 'Ops:*') {
                    [void](Get-MtatOpsTarget $clusterComposite)
                    Send-JsonResponse -Response $res -Object @{ ranges = @('Latest Ops Sample','Past 24 Hours','Past 7 Days','Past 30 Days') }
                    $lastHeartbeat = Get-Date
                    continue
                }
                $ranges = @("Real-Time Snapshot")
                
                if ([string]::IsNullOrEmpty($clusterComposite) -eq $false) {
                    $parts = $clusterComposite.Split('|')
                    $targetServer = $parts[0]
                    $clusterName = $parts[1]

                    $viServerObj = $global:DefaultVIServers | Where-Object { $_.Name -eq $targetServer } | Select-Object -First 1
                    
                    if ($null -ne $viServerObj) {
                        try {
                            $si = Get-View ServiceInstance -Server $viServerObj
                            $perfMgr = Get-View $si.Content.PerfManager -Server $viServerObj
                            
                            foreach ($int in $perfMgr.HistoricalInterval) {
                                $currentIntervalLevel = [int]$int.Level
                                $currentIntervalEnabled = [bool]$int.Enabled
                                
                                # REQUIRES Statistics Level 2+ for a historical interval to be offered as
                                # a selectable range -- this is a deliberate, confirmed product requirement
                                # (not just a technical minimum): historical ranges should only be surfaced
                                # when the customer has genuinely opted into Level 2+ collection for that
                                # interval, matching what's documented in README.md. Do NOT lower this to
                                # -ge 1 -- that was tried once based on a theory about what Get-Stat's
                                # rollup request technically needs, without live-vCenter verification, and
                                # it was a confirmed regression: it surfaced ranges (e.g. Past 365 Days)
                                # that were never actually enabled at the required level in the customer's
                                # environment. Real-Time Snapshot is always offered regardless of this
                                # check (see $ranges initialization above the try block).
                                if ($currentIntervalEnabled -and $currentIntervalLevel -ge 2) {
                                    $cleanName = $null
                                    if ([int]$int.Key -eq 1 -or $int.Name -match "Day" -or $int.SamplingPeriod -eq 300) { $cleanName = "Past 24 Hours" }
                                    elseif ([int]$int.Key -eq 2 -or $int.Name -match "Week" -or $int.SamplingPeriod -eq 1800) { $cleanName = "Past 7 Days" }
                                    elseif ([int]$int.Key -eq 3 -or $int.Name -match "Month" -or $int.SamplingPeriod -eq 7200) { $cleanName = "Past 30 Days" }
                                    elseif ([int]$int.Key -eq 4 -or $int.Name -match "Year" -or $int.SamplingPeriod -eq 86400) { $cleanName = "Past 365 Days" }
                                    
                                    if ($cleanName) { $ranges += "$cleanName" }
                                }
                            }
                        } catch {
                            Write-DebugLog "Interval matrix error encountered. Falling back to basics: $(Get-FullExceptionText $_)"
                            $ranges += "Past 24 Hours"
                            $ranges += "Past 7 Days"
                        }
                    }
                }

                $uniqueRanges = @($ranges | Select-Object -Unique)
                Send-JsonResponse -Response $res -Object @{ ranges = $uniqueRanges }
            } catch {
                Send-JsonResponse -Response $res -Object @{ error = (Add-KnownIssueHints (Get-FullExceptionText $_)) }
            }
        }
        elseif ($req.HttpMethod -eq 'POST' -and $rawPath -eq 'api/analyze') {
            Send-JsonResponse -Response $res -Object @{error='Reload MTAT: live analysis now uses background collection jobs.'}
        }

        else {
            $res.StatusCode = 404
            $res.ContentType = "text/plain"
            $res.ContentLength64 = 0
            $res.Close()
        }
    } catch {
        $fatalText = Add-KnownIssueHints (Get-FullExceptionText $_)
        Write-DebugLog "[CRITICAL] Outermost loop routing failure occurred: $fatalText"
        if ($null -ne $context -and $null -ne $context.Response) {
            Send-JsonResponse -Response $context.Response -Object @{ error = $fatalText }
        }
    }
    
    # Refresh the heartbeat timer after handling any intense workloads (like API querying)
    $lastHeartbeat = Get-Date
}
# Release Ops tokens when the listener exits normally. Tokens also expire on the appliance.
Close-MtatOpsSessions
