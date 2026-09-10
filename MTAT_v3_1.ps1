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
Write-Terminal "   Memory Tiering Assessment Tool (MTAT) v3.1 Engine       " "White"
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
$LogFilePath = Join-Path $TempDir "MTAT_debug_log.txt"

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
    if ($ExceptionText -match "Sequence contains no elements") {
        return "$ExceptionText [Likely cause: installed VMware PowerCLI is older than this vCenter/ESXi build and doesn't recognize its API version -- common right after a vSphere upgrade, and Memory Tiering itself requires vSphere 8.0 Update 3+. Check with: Get-Module -ListAvailable VMware.PowerCLI. Fix with: Update-Module VMware.PowerCLI -Force, then restart MTAT.]"
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

function Send-JsonResponse ($Response, $Object, [switch]$AllowCrossOrigin) {
    try {
        [string]$jsonString = ConvertTo-Json -InputObject $Object -Depth 5 -Compress
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
$LogoBase64 = "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CcpLElSUJigvLaW0JEFpSYJoJILjOIM/xhis7Q+A+D6+79OXStHV1UNndxcdXd10dvfQ3t1Dc3cvqb4UoUiYqmiYRCRCeFhvkjz5NfBN4KGmxoZMPk8sIiIiIiITowCIiIiIiMghLllXfzi5QMhzgHLyfJ0/UN7KtxbrW7z+AEe2P9PDYvEtWCxYMAYMZvC/HccQchxcx8FxcqWwHGOAgUbneeUD7cDPgC81NTbszfsIRERERERkUigAIiIiIiJSIJJ19TOB15ELhBwJVAQ7okPKbuBR4I/AFU2NDb0Bj0dERERERCZIARARERERkQKTrKsvAZ4LXAicCiwKdkTT2lrg38BfgFuaGhvSwQ5HREREREQmiwIgIiIiIiIFKllXHwXqgDPI9Qk5I8jxTCO9wC3ATcB/mhobGgMej4iIiIiITAEFQEREREREClyyrt4BaoDZwPnAC4H6QAcVjJuBq4BbgX1NjQ0tAY9HRERERESmkAIgIiIiIiJFKFlXXwE8E3gtcBoQAUJBjmmSZchlelwL/A74p/p6iIiIiIgUFwVARERERESKXLKuvhR4FnABcBi5bJFqoIpDIyiSBlr6f/YBDwE3ANc1NTYEOS4REREREQmQAiAiIiIiIjIoWVdvgCS5QMgKYCmwAFhMrpl6eWCDG9IMbAK29v9sINfM/PGmxoYtAY5LRERERESmEQVARERERERkVMm6+hpgHjAXmE8uGDILmNn/U9v/UzmJp20hF+jY0/+zF9jFUOBjO7CzqbGhfRLPKSIiIiIiBUQBEBEREREROSDJuvoQEO3/iQz77wi5slkLyAVMavr/tzC5UlphwAWy5Hp0DPx3ilyQYyCw0UGurFW6/39LDfz/TY0NXj5+RxERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERERGZ9kzQAxARERGR/ErW1RtgHjADqOz/iQOR/h8XyAKZ/p8uoK3/Z19TY8O2PA9ZREREpplkXf1MoBaoAiqAMnLXEeH+Hwfw+n/SQDfQA3QArUALsLupsSHvYxcRkeKhAIiIiIhIEUjW1S8ATgaOBJaRC4DUkpuwqCAXAAk9xaFZchMW7f0/LcBO4HHgYeDOpsaG3VM9fhEREQlW/7XEKcDhwBJgLlBNbiFFBVBCLgDiPMXhPrngRw9DCytagd3AFmA98Chwf1NjQ2YKfw0RESkyCoCIiMi4JevqjwZ+RO7Gxk7w6VygCXh3U2PDzomObTySdfUfB55P7gZsomLAp5saG35/kGM5Dvg+uddhoq/lVHGAXcD7mhobHj/Qg5N19acAPyF3oztRLvBEU2PDyyfhucYlWVf/beA0cqsWJyoBvKGpseGOSXiucUvW1YeAFwAvBVaTm6SoYHKuAX36M0KAB4GrmxobrpyE5z0gybr6NwFvJZepMhVs/3OngF6GVqzuJDdZsw54uKmxITvREyXr6pPANeQCTgfDBf4LXNbU2LB9ouMZj2Rd/d/JBdIO5nPVITcJ9rmmxoabJnVgY0jW1f8JWMrk/H1PJ4ZcoPITTY0Ntz/dTsm6+l+TC4Ye6O/vAK1NjQ1nH+wAk3X1fwCWH8S58ykKfLepseFHB3pgsq5+HvAp4Fim7nccWE2fBjrJfQ7vBbYCG8l9Xz45ReceVbKuPgp8FzieXAD9QLjAQ8DrD2YCPFlXPwP4NHDSQZx7gAPsbGpsuPAgj39aybr6VcAfOPDPeAe4pamx4X2TPabxSNbV1wAvAy4EVpDLHi3jqYMcE9FF7vOrjdx32bXA9U2NDV2TfB4RESkyT7XKT0RE5OmUAScyeQH0I4BbgB9O0vM9rf4JideSW602WWZN4NhycpMD091ucqv5DkYlsHLyhsLSZF39s5oaG66fxOd8Ssm6+lOBi4D5k/i0lZP4XKPqnwR6J/AGJvY+HY1DLqBSTW5C5EXJuvqvAV8BftnU2LB3is67vwXA0Xk619PxknX1m4CbgauAO5oaG9IH8TxPAv8BXj+BsawmF5T5wgSeY1ySdfWfAs6d4NP8Nd/Bj36ryQVAClEnY3/eHMXB/910HORxA44h95kx3R3s53+UXHBp9eQN5cAl6+p7gbuBv5ELrG6ajEDtOBhyv/8xB3m8z8FfZ0bIXVse7LkHrEnW1b+0qbHhqgk+z/5KyGVOHIy8BLWHS9bVHwt8lFzgI5KHU5b2/8wj9x56FZBN1tXfAXyP3EILZYaIiMgBm+yIvYiIFDbLwa+oeyoR4MJkXX3VJD7n03klkzuZDRPLJLETPD5fshz8OCc7s6UcyFcGyHOZXu+XcUnW1c9N1tW/k1zg6mNMXfDj6cwCvgo8lqyrf0+yrn5hHs45HVaRu+TKir0J+BewK1lX/41kXf0pybr6xHifpH9y8jPkMmom4kPJuvr6CT7HqPozvN4ywafZw8SCPRMxHd43UyXL2J+/E/kun+h1wKHy2k/ku286/I5x4Axyn8nrgPuSdfVvSNbVL+zvAzWVJvL7T+T9NZnXqV9N1tW7k/RcAyZyXZSX91Syrr40WVd/TrKu/gbgPnKLQfIR/Hg6IeB04PdAc7Ku/kvJuvoTk3X18QDHJCIihxgFQEREJGgnAydM5Qn6V8OfS64ZoxzaTkzW1U/1++Vw4JypPMdkS9bVh5N19S8B/gJ8i+DLnNYCXwf+nKyrvyDgsQShCng3cCPw3f5VtOPS1NiwhVwWTecEzl8OfD5ZVz8l1/r9Qev3kyuDMhHvz2OmkEixOwb4MbmMkHf0XxvJ05tP7nO8aCTr6k8iV571b8B0/O4uB/4PuI1cRrqIiMi4KAAiIiJBqwbO668ZPVVOZYqDLJI3K4CzpvgcJwNrpvgckyZZV18OfJlcKbnp9j4/Fvh1sq7+E8m6+sqgBxOAUuAScq/Baw/guD/3/0zEmUxddsVLgGdO8Dn+DPx6EsYiIgfmKOBrwM+TdfWTWaayEF3c3/S74PVnj/4KeDW5Mm7TWYTcQgMREZFxUQBERESmg1cwRaV6+svPnE9u1ZgUhguTdfWTXZ4KgGRdfQXw4ql47qnQX8bkeuBdTN/JgBrg4+QyIaqDHkxADge+nayrf+94dm5qbOgFPgdsm+B5P5Osq58zwecYIVlXvxT4ABObINsGfKapsWGyy+SJyPiEyPV1uLG/R5o8tVXAxUEPYiol6+pLknX1l5PLPFwW9HgOgL4/RERk3BQAERGR6WA28MIpeu4V5FYrS+E4lalrIH8k07Psw/9I1tXPBf4LnELwJa/G4pDrw3N1sq5+dtCDCUgZ8OVkXf0bxrNzU2PDOnKlPiZiJrnGsZMiWVcP8EkmNklmgc82NTY8MAlDEpGJWQj8J1lXPzPogUxTDvDSZF390UEPZCok6+qXA9cClxJsnw8REZEppQCIiIhMF++bonr1L2L6royXg/eWKSqb9qEpeM5Jl6yrXwFcR66m+6HkNODmZF19WdADCYgLfClZV3/ceHZuamz4Lbm+LhNxfrKu/o0TfI4BzyFXHmUifgf8ZhLGIiKTYzHw4ykuRXooOwp48VT1VApKsq7+GOCP5MolioiIFLSC+hIXEZFD2jxypaomTX85o3GttpZDzrnkygpNmmRd/SxyE7zTWn+5km8Cq4MdyUE7Evhp/99nMaoCPn0A+78L2DGB8yWANyXr6pMTeI6Bz9PvTOQ5gM3A15saGybS4F1EJt/ZwMuDHsQ0dglwRNCDmCzJuvolwOUceosoREREDooCICIiMp18eJKf77lMUW8RmRbeNcnP9+5Jfr5Jl6yrDwMfA54V9Fgm6MXAR/pLKhWjZ463pEpTY8NWcj1UJlLvvA544wRXeH8KWDSB4wG+2dTYcN8En0NEJl8pcFGyrr426IFMU/OA1wU9iMnQ3xvvJ8C4MhFFREQKgQIgIiIynRyXrKtfPYnP95FJfK5i5TB9+0u8erJKdiTr6uNMvLRPPlwEvHmSnzMF/I3cJPtLyZXDOJmhFcEfBW4B/Ek+7xuZut4/h4K3HsC+fwB+P8HzvY2D7J2TrKu/gFwPl4m4q6mx4ZsTfI7JNF0/1yaD7vEmRyG/R57KaeTKPclTe3eyrn5O0IOYBF8k9/0+Ve4HfgS8n9xih3PJ9W47pf+8zyP3/f8p4FfAQ1M4FhEREQBCQQ9ARERkmDjwTiZhlV2yrv5MJrlE0jSTBTymdoLGAfqY2MrzqRQil7XxpUl4rtcD07o5d7KuvoRc/4TJsgN4D/DXpsaGvjH2/Xyyrr4KeAW5SY3Fk3D+SuCjybr6R5saG56YhOc7WOkx/nfT/+MyuX9vL2acwaymxoaOZF39V4E1wMGWsooBlyfr6lc2NTaM+2+6v2n9B4CJrAy35IJr00mK3GeoNwnPZYEwEws8jPU+HK+Bz+3JDlhOJymmPjgRIfc9GwR/jHMP/O4Ouc+lyVIFHJ+sq7+lqbFhEp+2YBjgG8DLgh7IwUrW1b+ZyS8Na4EbgO8BtwI9B/gdY8j9va0mVwr3eeQCceFJHqeIiBQxBUBERGS6OT1ZV7+qqbHhkQk+z3snZTTT18X9DZKL3aXJuvrvNDU29BzsE/SXg3gZkzuRNBW+z+RM+jUD325qbPjMgRzU1NjQCnwvWVf/Y3IrN98JlExwLGuAVybr6j/R1NgQ1IRteVNjQ+rp/sdkXb1LrvzJauAc4CxyQYiJTs6UJOvqj29qbLh3PDs3NTbcl6yr/w7wNXKTRQfjMHL9Ry4bz879E1NvIPc7T8Q7+kt5TRtNjQ2rJvP5knX1PyK3qvlgPAnUNTU2tE/ikArVhqbGhuVBD2KK/bqpseE1o+2QrKsvA1aQ+wx9NnAiMBnZCScCFYDei0/t/9u77zBZqmph4+855CgSLiLBhCUmhEKkFEwIGFH59IpXRUUbMF77mmgD5istiLcNmGgDKAZABQFFUEBQLFTKBIIlIqLkLBwO8fD9sRs9DN1zurqqu3pm3t/zzANU1d57UdM907N37bX2jOLkkGF/bk+TKE4eS9gJuHpFXV4FHAe08yy9aNROeosltwFn974+1Ft4fzkhle0jMJ2tJKkkt0dLkqbNgwh/8IwsipPtmf+5jctOPM8XmwIvKdnHc5jy3UJRnOxINemi/gy8pujix/LyLL0jz9J3A2+iXHHue7yeeovLzlqMPc/Su/IsvSTP0u/nWfrfhMWA/wVuLjnuShRPN/NFwpO2Zbw9ipPthrx2B4ql6urnBODIkn3MBWXS8a3ECl6H+pdpX6iuwqpRnKw72wV5lt6UZ2mWZ+mX8izdg7DD6pQKxn4EsGYF/cxn74niZE7No0RxsirwSqCqhd+TgZflWbpvmcWPQfIsvSLP0kMIKTlfRth5U/bBKEnSAjanfnFLkhaElYBnRHGyaYk+/pMpT2ekyqwJ7B7FyUhPNPbaPQtYv9KoqvdGyi96XQO8Ls/S4yuIhzxLv0pIh3VVya42APYrHdCE5Fl6VZ6lHyTUTCljJQqmEsuz9HbCPR95xxPh6d8PR3Gy9mwX9QrUv49yP0v/Dnwiz9IbSvQhaQXyLD2TsFvr1JJdbUZ1OwTmq6cQdt3MJY8ipPqswpeBV+VZ+pOK+hsoz9JleZaemmfpWwk7Qt4D/Kl32rksSdLQ/KUhSZpGOzJ6sd4tgadWG46m3BOAJ47Y9jGMtxhoaVGcPIHwJH5Zr82ztOzk2L300rAdQvn6BW+sIJyJyrP0/4ALS3SxiLD4U3TcC4F3lRgXwmt+RbWWXgU8u8QYy4DD8yw9rUQfkoaUZ+nfCMWnry/Rzf0wTfaK3B94xYp26UyZvQh1t8r6HNDMs/SKCvoqJM/S3+dZ+lFgd+Ag4OpJxyBJmrtcAJEkTcoy4I4hr10NeHEvx3VROxMmxIe1ouLPqkeR78tmwLOLpqTo1TfYjWJP4d/G5IvCPxd4aMk+vp5n6ferCKaP/wNOLNnHoihOyqZaqsOhJdvPugtjFp8jpCAZ1arAG6M46ZsqMIqT9Qk1Z8pICanCJE3O6cAfSvaxENKMlbU7oWD31Ovt9quiLt63gHfnWXpTBX2NLM/SP+dZuj9wZp1xSJLmFhdAJEmT8leKTdj9J1Co0GkUJxtTrE7CHYQ/6OoqvqzBzqTY0/V7ULyOxwOBVxe4/hLgDIZfyCstipMtKL+j6WpC2qSxyLP0DuDDlE+FNRcXQE4q2f7OURr17vnbgctLjB0Bb4ni5F6p1Xqpr7qUqwNwM/CmPEtdYJYmKM/Sq4CLS3Yz6UX+uWh1YN8oTjaqO5AhvK6CPn4DfHCa0hnmWVp3CJKkOcQFEEnSpFxCsafEVyXk+y1ia8IOkGGdTCiquKjgOBq/y4FvFLh+S0Je7iKeBjy8wPUnEHJPT/Lp2IcA25Ts49OMOVVEnqW/ofxiwOZRnEx1Mfo+yqYBuaFE23MJ6cdGWkTpeQXw/BnHXknYGVXGIb3XhKTJK7MYfTvlfqYsJLsw5Sk0e4p+lp5pKfD5PEsvqCIYSZLq4AKIJGlS7iAU58wLtNlv2OLWvfRHL6NY7urvAlfiAsg0WgL8CLi2QJt9ChZDf0eBa28iLJhdy2Q/P21DyMk+qsuBk/MsncQup3bJ9msQCtLPJXcz+g6yuymxAJJn6d3AEcCPR+2j52NRnKwH/6qh9EZgrVlbzO7XhPzskuqxBLhrxLb/LNF2rruF4ovaB0RxMrUpw6I4eSihAHoZGfC1CsKRJKk2LoBIkiZllTxL/0TICz+stYGXDnnthoSivcP6A/AzTH81rVYCfkX4Hg0rZsj6L1GcbA08rkDffyBMNE+sOGwvNVHZ4uc/p9ii48jyLD0f+HuJLlZh9GL2dRr18/SdwJ/LDJxn6dXAgcB1JbrZHPho79/3plgNpZmWAvvnWXpLiT4klbM6o/9cupjwPl6ILgO+R6j1NaxHER6+mVa7EX63lvHlPEsX6mtCkjRPuAAiSZqUe3ZZfJNik3XvHfK6JsV2cvwkz9KcCU5oq5DFvToHJxKeyhzWAUNe94ECfd4JHJ9n6RIm+9lpTWDbkn2cnWfp9VUEM6TDS7bfIoqTMjteJm29Em3vBM4uG0CepWcAnyzZzWuiOPkw8JaS/RxEKMIsqT4bMPrO1t8RdjwuVN8FTivY5pAoTqZ1J/FTKLfLeWmepV+uKhhJkuriAogkaaLyLD2JkLt+WA+O4mSP2S7o/eFZZOLuH8DRBa6fRhMrxF2z7wHnFbh+lyhOHjTbBVGcRBRLtfQPyk/sj2Jdihd2X97lFHuvVeGEku03JBTnnivKpOy6PM/Sv1YRRJ6lHwLOKdHFaoTF5jKpr34MHDahdGtauHx9zaKXzu5hJbr49QLewbUSoV7dl4GbC7TbCHjfWCIqIYqTVYBHluzmO1XEIklS3XzqVZJUh0MZvmD1SoTUVt+b5Zp9CU/LDyvLs/SsAtdPo2f06p6UTW0wyMrAz/Ms/d2Y+h9KnqXXRHFyErB9gWbvAN40y/n9CPUmhvWDPEsvL3B9VbYs2f5K4MIqAingIsKOnSLvx+XdH9iCkP5sLnhlibaHVRZFsB9wJsVe21W5DvhknqWX1jC2FpZ1ozjZi/G9zhcBN+dZeuSY+h+37YFHjNj2IsotpM4HqwPHED5X7lKg3cujOPlanqUXjSeskUTAOiX7OLaCOCRJqp0LIJKkicuz9KgoTj4N/MeQTbaL4uSJeZb+YuaJKE5Wptgk5DLgKwWun1Z79b7G6QBCOoy6fZGww2fdIa9/dhQnD8yz9LKZJ6I42Rx4RsHxDy54fVUeWrL9dZSryTGK24Hzge1GbL8WYRfI1Ivi5IXAk0p0UWlakTxLz4ni5GMUS+9WlSPyLC27+0caxobAEWMe43pgzi2ARHGyNqGOzwNH7OJMJr9rcNosyrP07ihODqTYAsjDgNcwfNrWSdiEcrv6AOb6w0KSJAGmwJIk1edzBa7dDHj+gHPPotgW/0vyLD22wPUL2VSk2cqz9B/ADwo02QzYc8C551Ls6dgz8yy9uMD1VXpIyfbX5FlapJhrFW4nPEU8qtWZ/ALI3UUbRHHyfOBTJcY8OM/Sq0q0H6TL5Gtw/B14z4THlMZpGgo+F/q51NsRejDwkhHHuwL4msWugzxLT6VYLZDFwB5RnDxuTCGNYmPK7ZS6mrAYKEnSnOcOEElSXT5NeFJupSGv3zWKk8PzLL1gxvGXEtLmDOugAtdqeryf8L0exqrA83qvl+vuORjFyYbAcwiT7MP6QIFrq1Z2AeTKSqIo5k7gPjtvCtqgikAKmLVAbBQn91yzMiF1XxN4JqOnn/sd0Bmx7azyLL00ipODgEcT8tJPwp4LuGaANC7D/lzaANiDUINisxLjHZln6U9KtJ+P3kSxGmSPAl4Sxcm5eZbeNaaYitiE0dNRAvyFCmruRHGyEuG1WvhhgyEsApZZe0qStCIugEiS6nI98FngzUNevx1h8vFfCyBRnDwZ2KnAmLdQfd59TUCepXkUJ2cCTx6yyeOBXYFvL3csAXYuMOyvgPukXZug9Uq0vYvw9OakVTHuGlGcrDTBCaRDozhZyn0nHBcRFsvWBjYFHlPBWH8F3tAvPVtV8iz9YRQnhwHvYgWTqBX4RL/UhJJKSYAvRnFyO/d9Dy8m1HVYj1DjYeMKxjs6z9K3V9DPvJJn6R+jOOkCjQLNXkcoHJ6NJ6pC1qZcnbh/UHIBJIqTTYEfA1uV6WcFvgX81xj7lyTNAy6ASJJqkWfpsihOjgH2Yfgn8l8cxcl38iy9NoqTRYTJ7AcVGPYzeZbeWTRWTY1PMvwCyLrAblGcnJBn6ZIoTlYnpL8qkg/7yzWnAymTuuIuYElVgQyr976+qWQ3qxB2hk1qAeTFExrnQuCteZZOIqd6B3g68MQxjnEO8Ikx9i8tVA/ufU3CjyhWR22h+Txhh82wOxPXJyyC7Du2iIa3Wsn211N+B8gyoOxnghWZ+GcdSdLcYw0QSVKdzgNOKnD9Lvz7KewtgBcUaLsEOKrA9Zo+Pwd+X+D65xKekAXYnMF1QfrJgZ8WuH4cyqSuuJtQj6MOZcddlfn3kM4ZwF55lh4/icHyLL2asANkXG4g1DG5dIxjSBqfWwkLmHvlWXpr3cFMsXOBIwq2aURxUqQ23bgUSffZj68LSdK84QKIJKk2eZZeC/yQ4Z/0XgTs3fv3HYBtCwx3PPDnAtdr+lwJfLPA9RsTajUAvIhitWJOJCyC1KlM6gqY3A6Kmco+MboS8+cz6lLgfwl1MtJJDpxn6U+Bz4yp++8A3x1T35LG6zeEmlrv7i2WaoA8S28DjiGkLxzWIuDA8URUyLA19ga5k/HU7ZAkaeLmyx+XkqS568eEVCrDelUUJxsBry/Q5g7gO3mW/rNQZJoqeZbeDfyEUJhzWG+I4mQNYP8CbS4DfjgFRUzLpN9aRNhJUYeyCzd3UN/iTRWWEVKHfAZ4VJ6l782z9IqaYtmf6hd+LwA+mGfpHRX3K2k87ib8XLoQ2AvYLs/S43qT+1qBXtrCYws22z2Kkx3HEE4RZXdjrs7460hJkjQRLoBIkmqVZ+lFwCkUe8rsi8DTClx/OiF9kua+cwg5y4e1OXA4xQqK/wI4rcD143JLibb3FPCeqF5tnrLj3kZYBJmrDgfiPEvfnGfpxXUGkmfpLcB+lFtMW96dwLvyLP17Rf1JGr9Lgf8Gts6z9Ou9hwlUzKEU2xW6GPhQFCd1zreUTWG1Ji6ASJLmCRdAJEnT4FvA5QWuf2GBa+8EfpJnaZH+NaXyLF1GqBtTJG3Hfxa4dglwbJ6ldxYKbDzKFPZcmWKLPlVZTCgCW8btU3L/R7U3cFwUJ++J4mTLuoMBziJM3lXhG3mWHltRX5ImYzPgYOA7UZy8qLcrUgXkWfoXiqXgBHg8xWqPVW0p5VJSbozzRZKkecJfaJKk2uVZei7j26HxN4qnLlCwWt0BDHAKoTDpOFzM9NQ2KJM2aRGwUVWBFLAysGHJPm6uIpCabQ18BPhWFCcvqjOQXpqbLwC/LNnVPyiWSk6aq9auO4AxWAN4NnAk8H9RnDyk5njmoo8TapENa13gZVGclP2dOKrrCTsqR/VAnC+SJM0TK9cdgCRJPR2KPak/rDPyLP3TGPqtW5tQiHhcdR4WU6zo58TkWXprFCfHAE+hfJHPmY7spQ2aBheXbP8fVQRR0CrAFiXa3w1cW1Es02A74CtRnKydZ+nhdQWRZ+mFUZx8A3gsYSJ0FAfWWMtEusflwLMY7yJF2doJ02w1Qlq8KIqTffMsvbDugOaKPEtvjuLkQMLn1WHtCuxC2Ok8aVcSUmmO+jN/K0yBJUmaJ1wAkSRNhTxLz4ri5I/Aoyrs9g7g0xX2N03yPEt/XXcQNfoC8H6qn+Q/uOL+yrioZPv1ozjZIM/SSS4orAJEJdovoVh6s7lgHeALUZwszbP0qBrjuJbwM3HUyTDrfmga3Jpn6e/rDmIeeDrwtShOXpBn6VV1BzOHfA5oAg8e8vrVgH2iODktz9Iiu0eqcDlhAWSDEduvSvj/vKCqgCRJqosLIJKkafJ+4OgK+zsrz9LfVNjfNKl658OckmfpXVGcfBL43wq7/eyU1Z4oO+mwMfBwJrujYj3goSXa3whcVk0oQ/sdoVbQ8k+6rkSY/FmHMHlUNmf+asBnoji5Js/SU0v2NapFlHua11QomgYL4Yn06wnpO+/i3/+/iwh/u69O+DlbRYrDhLAI8iwLow8nz9LbozjZH/h2gWY7E9KPfXUsQQ32V8qnlNydcp9FbgA+QHhYZVA9kruAbYG3lRhHkqRZuQAiSZomPwQuoVwKneV9pKJ+NJ2+QLULIJ+rsK8qXE5YELjfiO03IezGSCuLaMV2LNn+WsrvfCnqiXmWLp15MIqTdYEtCZOETydMBJWpi7MR8L4oTv6cZ6m7KSQNcgLwqpmLElGcADwAeBxhUn03YJuSY+0GvIViaZ0WutOAnwDPKNDmvb00hGWKkheSZ+nlUZxcATyyRDcvosTO2N7v1h+s6LpenC6ASJLGxie5JElTI8/SJYRJ7Sr8hfAHquapXmqnb1bU3feBvKK+qrIU+EOJ9msBW0dxMsknpssW/L6GyS+ArNPvYJ6l/8yzNMuz9LPAXsDrgUtLjvVUoBHFiQ8hSRpkFfr8XMqzlDxLr8iz9Ed5lu4P7AkcSqidVMb7ojjZrmQfC0aepVcDRxDSSw3rYcDewK1jCWqw35Vsv30UJ5tUEsnsVpnAGJKkBcwFEEnStDkJqCIf9adM6bAgHFpRP0fkWTpthW9vAcqmcHsC1e2oGsYLSrb/0zS+b/MsvTXP0q8ADcIutTKawKNLByVpQcuzNCc8NV92J+T9CTsUnIQe3gnAmQXbHEC415N0JuV2nSwG9qsoFkmSauMCiCRp2pwPHFuyj0uBE8uHojngj4RFszJ+BvyqglgqlWfpbRSfYJnpyYR0KWMXxcnelMvPvxT4UUXhjEWepScB+xNSk41qXeCgaiKStJDlWXpbnqUHEHYxlrEbYaebhpBn6XXAV4B/Fmi2CWERZJKOJfxuLeMVUZxsWkEskiTVxgUQSdJU6eULPp5QBHRUX6P8U9qaA/IsvZ7w/S7je3mWTuvr5QLComAZb4jiZO0qghkkipNVgXeU7OYGyi9mjV2epd+ifKq+3aI4eXoV8UgS8ApC6s9RrQm8OoqTzSuKZ97Ls/TbhAcohrUY2HVM4fSVZ+kyyj9U9DDgneWjkSSpPi6ASJKm0c+Bs0dsezVwSp6ld1QYj6bbLxn99XI+cGqFsVTtIsrvTnlm72uc3kQoGF7Gab1dL3PBIZTPre4uEEmVyLP0JuA9QJnPPk8GnlNNRAvGh4G76g5iBQ6roI89ozh5YQX9SJJUCxdAJElTp/dU/4+AUSZDz2AK0xlpfPIsvZDRFzHOyrP0txWGU6k8S5cApwE3l+zqU1GcrFFBSPcRxck2wD6UL2L68fLRTEaepVdRPt44ipOXVBGPJAGnEGpTlLFPFCcbVhHMQpBnaUr5ez5uZxLShZaxMfDBKE4eVUE8kiRNnAsgkqRp9U3g8oJtlgA/6j0JqYXlBODvBdvcABxVfSiV+xGQl+zjgUC3gljuJYqTDYD3A1uV7CrPs7RswfeJyrP068CfSnSxGNgvipPVKgpJ0gLWq0vxDeC6Et1sBzyrmogWjFbdAcymlwbrExV0tTVwZBQnG1fQlyRJE+UCiCRpKuVZeiXw3YLN/gIcM4ZwNOXyLD2L4jt/zs+z9ORxxFOlPEsvJ+TwvrtkVy+L4uTQKE5WKh8VRHGyOmFS5YUVdPeBCvqow9tLtt8ecBeIpKocR0gjWka7ikAWijxLLwA+X3ccK3AScE4F/WwD/DqKk7IPPUiSNFEugEiSptlBwLIC1x/VS5+lhelQ4NYC1390XIGMwccIBdHLegPhCc5S9TqiONmUMKHyygpiOhk4voJ+6vAjihXBnWkd4OWmnJFUhV79s88BN5boZtMoThoVhbRQdIAr6w5ikDxLLyV8pq6iztZmwB+iOHlnFCcPrKA/KPZZX5KkwlwAkSRNrd4ukBOHvPwmxpDiZ4rNlWLRE5Nn6akMv0hwdZ6l0563+1/yLL2dUOC2CnsCR0dx0oji5AFFGkZx8pAoTvYh1CV5agWxLAEOzbO0bI2TWvQmGz9VspunAM+oIBxpIXCidAXyLP0h8MuS3bzT9HyFXAR8qe4gVuBkiu+sHmRlwoMZx0Zx8uYoTh4XxcnKJfrbpKK4JEnqq8wvKUmSJuFdwI+BO2e5ZhFwXW/BZKF4dRQnMVBJOqNZLAYuAY7Is/SKMY9VhTcD2wJ3zXLNYuDCyYRTnTxLvxfFyQnA8yrobhvgMOCUKE5+AfyasHj0jzxLl95zURQnaxEmJrYhpGvaCdiB6l53Xwd+UlFfdTmT8P8w6iLGGsArojg5Kc/SMk9tSwvBhlGcHAxMYnJ+NaCbZ2nR9IrT4EPAriXaPwx4LfDZasKZ3/IsvSOKk2OAFwGPqDuefvIsvaH33tkBeGhF3W7f+zqPkBrr98D5wMXAFf12ZUdxsh6wIbA58HDC54udKopHkqS+XACRJE21PEvPI/xhpXvbufc1CecRduJM/QJInqU/o1xKomn3dkIh0i0q6m/X3tfVwPXATVGc3E54ynoxYQJwLWAjYP2KxrzHucBBeZYuqbjficqz9IooTo4m7ORYZcRungc8ATilssCk+WldytfeKWKU+lK1y7P0Z1GcnEMoaj6KxYT0fN/Os/TaCkObt/Is/U0UJ8cB76w7lkF6Me4PHF1x14/ufd0BXAf8E7glipNbCQ+k3POZYiXC54o1CCkg1wPWrDgWSZLuwxRYkiRpRW6nfAFuVSDP0j8BTeCWirveCIgIk2VPBHbs/TMmPM1a9eLHEuAteZZeVHG/dTkOSEv28cEqApFUqdl2E067t5Vs/3jgpVUEsoB8FvhL3UHMJs/SY4ADxtT9KsDGhJ0djyPsNnkSYYfHk3r/vQ3hc8UDcfFDkjQhLoBIkiTNIXmWfg94C2ERYa56ea9my7zQSw93JHBriW6eGMWJtUAkVeUsoEytq1WBl0ZxUtWOw3kvz9K/EYrQT7U8Sz8CHFx3HJIkTYoLIJIkSXPPlwg53m+rO5CCbgJaeZYeV3cgY3Ak5dP1faSKQCQpz9I7gC8Q0hKN6knALtVEtGB8Cvhb3UEM4QDgEGDpii6UJGmucwFEkiRpjsmz9G7g44Si73PF1cD+wMfqDmQc8iy9mfJP/m4fxcnzq4hHkoBfAD8s0X4x8NooTqpOgzhv9Raepj6lYZ6ltwHv733N5R2lkiStkAsgkiRJc1CepcvyLD0M2Au4oeZwVuQy4HXA5/OsbKmM6ZVn6ZeAK0p0sRLwxihOVq4oJEkLWK+A+XcoN8H9JMD0fMV8C/hj3UGsSJ6lS4D/A14OXF9zOKNao+4AJEnTzwUQSZKkOSzP0q8TipafWXcsA5wOPCHP0u/2dq7Md+8p2f4JwIuqCESSgOOAs0v2cWAVgSwUeZYuZXyFxiuVZ+mdvbSUEfDjuuMp4G7gy8D/1B2IJGn6uQAiSZI0x+VZ+kfg6cDbgAtrDgfCxMRfgXfmWfr0PEsvrTugCfo6cH6J9usBe0Vxcv9qwpG0kOVZeiOhbtQtJbp5WBQnL6sopIXiNOD7dQcxrDxLr8mzdFfgFUAG3FlzSP3cBJwLtIH/yLP0tXmWXlVzTJKkOcAFEEmSpHkgz9K78iz9BKFg7ReBC2oK5feEwqo751l6cE0x1CbP0tsJ//9lPBXYuYJwJAngaMLP5jLeY3q+4eVZej3wNcKk/ZyRZ+mRwG7Auwk7S2+tNyLuJKQTO5qQSnOnPEvflWfpNfWGJUmaS/wAI0mSNI/kWfo3YL8oTmLCrpBnAk8BVhvjsEuBFDgGOL23I2VSyn6eXVRJFPf2Y+AcYLsR268NvDqKk1N7k2iafmVeh6synteh6rEIWKVE+zJt+8qz9I4oTg4m1AMZ1aOAfYDPVRPVgnAK4ffBHnUHUkSvdszBUZx8g7AY/wzgacCDJhTC3cCve1+/An4L/HaBpNGUJI2BCyCSpCJWZvQ/zNeuMpAKlZkUXr1E25WZOzsx1yEUZy6qzCTOmiXajtMajD5RuWqVgaxInqUZkPUmMDYhPNH5TGB7YK0KhrgB+AXwI0J++UvyLL2sgn6L+i1hUu9OwqRJEWsRFm+q9jdCio49gbsoHtdi4HZgXaorTLsa4b08qom+fuegnxN+J9xRsN1i4CrKFakeRZnXwv1qHHvSRvmMcDNwEnAJxdMIrQKcQfHX0QrlWfrdKE6+TPg8tqxg80WE1+p6UZwszrN0tvaLKPeZbx1G/z27mNFfX+tS8fxInqU3RnHydeB5lF/Ymvjn6F76yq9FcXIssBnwcODZhEWRqOLhziWk3voV4QGCy4Ere/VUJEkqxQUQSVIRPydMfBSdzFvEdOYSBvgq8G1Gm6Ask0/7VEa7l5O2iDCBO8ofoCcQ6hmMMtFy+wjjTUILeD+jvV5urj6cFcuz9HLCREIWxcknCJ//tgAS4LHAQ4AHAxsRFp7WJkx230aYlF0KXEao6fFXQmqtX9Cb3MuztPKJuoK+AxzLaO+lReOIP89Soji5J65RLabaSdDDCT/rFjHa63fSE/RzzReBw0q0n/TvyG0JC9uj/D4v+3trK8Jratp//436e/4q4EOMPol/d56ld43YdkX2pdxuo0Ws4Hd6nqVLozjZidFfX3flWXrbiPFdStipsHLBse/5/yrzuW6Q7wHrU+41X+vn6DxLbyLUtjo/ipMTCYs5awKPJvwseTiwJeGzxf0JD4us1bvuDkIaraXANYTPE1cAFxM+T5wH/KV33Z15lk7r3wuSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEnlLao7AEmSpLmg1el+E3jpgNNfbTcbe49hzLWB5wJPAx4HPAhYD1gNuBm4EbgKOAf4FXBcu9m4Zi6M2+p0TwKeWTbWWTyy3WxcMGQs8/k+/7bX92zuAjZsNxs3DNnnZ4HXD3Hp7u1m44Q+7Wv53rc63W8Be/a5/nLg4e1mY8mwA7Q63S2BP/c5dWm72dhsxrWrA0uH7buET7abjWbRRtMYX6vT3QR4DrAj8EjCe2NdYA3gNuAG4BLgD8BZwIntZuOq6kOebCytTvfjwNv6nFrSbjbWHqVPSZKkhW7lugOQJEmadq1Od31gj1ku2bPV6f7PsBPIQ473XmA/YM0Bl92v97UF8PjetYe2Ot1jgAPazcZf58q4dfE+/8tKwM7Ad4e8fpcKx54GmwDvBN5fdyALXavTfTzwYWA3YPGAy9bofW0C7AA0gGWtTvcE4KB2s/Hz+RaLJEmSRjfog5wkSZL+bS/CU/mDrNG7prRWp7sTcC7wPwyeHB9kNeDlwO9anW6heOoaty7e5/vYdZiLWp3u5sDDKx57Gry91eluWsm3+m4AAA/dSURBVHcQC1Wr01271ekeSdjp9CyK/526GHg+8LNWp/utVqe7wXyIRZIkSeW5ACJJkrRijSGu2a/sIK1ONwFOJjxNXMY6wOGtTvdV0zxuXbzPfQ27q2OohZI5aE3gI3UHsRC1Ot0HE1JHvayiLvcEftvqdFeU+m2qY5EkSVI1XACRJEmaRW/S+jFDXPro3tP9o46zFnAUYTdJFRYB3VanG0/juHXxPg+0ZW/yd0XmW/qr5b2y1eluU3cQC0mvvsaZwGMr7noz4Iwi749pikWSJEnVsQaIJEnS7Prt/vgFsBVw/xnH9wN+NuI4/w1sPuDcZcBngFMIhZeXAGv3YtgDeDP9J9ZXBj4JPHkKxx3k7HazkYzQblje58F2AboruGbnisbqZ9zf+xVZDBwCPKPKTtvNxq2EBatZtTrdFnDggNNr9PqpXF3xtTrdNYHjCQsEg1wOHA78ALgQuJZQG2dzwut1LwYvUK8L/KDV6W7bbjYunyuxSJIkqVougEiSJA3Q6nTXJqQwmen7wN+Al844/uJWp/uWdrNx3QjD7T3g+I+BPdrNxs0zjt8ApEDay1f/U2C9Pu13anW6cbvZyKZs3Lp4n4O7ue+k967MsgDS6nQfC2w8ZF9z1c6tTvd57WbjhLoDWQD+F9hulvMHAx9sNxtLZhy/uveVtTrdjwP7EBYC+9Vp2hj4CqGWx1yJRZIkSRUyBZYkSdJg/0V4En+mHwD9JkhXBwrXZWh1uhsxuLD0m/pMjt9Lu9n4PdCa5ZI9pmncunif7+WPfY7t3Op0Z1vI6Jf+6u4Bfc1lB7c6XR8UG6NWp7sV8KYBp+8GGu1m4519Fhzupd1sLGs3G18AdiPsnOrnma1O9/lzIRZJkiRVzwUQSZKkwfbpc+wfvQnpHwJ39Tk/SjH0B8xy7uoh+zgCuGnAuW2nbNy6eJ//7bQ+xzZcQV/9FkD+AFwzwvjT5I4Z/70VsG8dgSwgH2JwNoJD283Gl4p01m42zgDeOssl754jsUiSJKliLoBIkiT10Uv3s32fUz8E6KW5Svucf0Sr031aweFm2wHwgmE6aDcbS4GzBpx+8JSNWxfv87+dPuB43yLnrU53FeApfU71W0iZaz5PeNJ/eR9odbrr1hHMfNfqdDdg8Ov+auCdo/Tbbja+CJw94PQOrU5362mORZIkSePh1m5JkqT++u3+gJD+6h4nADv2uWY/Bk8w93MZcDuwap9zn2p1ure0m41vr6iTdrNRNLd8XePWxfv8b1cC5wOPnHF8V+CgPtfvQP90cKcD21QYVx0y4GvAK5c7thHwrt6XqvUs+r8XAL7SW+wb1ecIr9V+XgD8fopjkSRJ0hi4A0SSJGmGVqe7OvCKPqduJxStvsegQsn/r1f3YSjtZuM24OQBp9cGvtXqdM9vdbqtXr76StQ1bl28z/fRb/fGTr3X/0z9doYsIxRnnw/eA8yc7G62Ot0H1RHMPPfkWc4dVbLv7xJel/3028E0TbFIkiRpDNwBIkmSdF8vAu7f5/gZyxesbjcb57Y63b8BMydJVwX2pv+T9IN8GnjeLOe3Ag4EDmx1uv8gTDz/tBfTnwqMMy3jDrJDq9OdmY6oiCXtZqPfToV7eJ//7XTgDTOOrQ7sxL0X+qD/Asjv2s3G9a1Ot6p4xv29H6jdbPyj1el+grAQco/VgY8CLy8Rk+7rsQOO30bJXRHtZuOmVqebE95PM/WrbzNNsUiSJGkM3AEiSZJ0X40Bx3/Q59iJA67dt9XpLhp2wHazcTLwzSEv34wwKftF4IJWp3tpq9Pttjrd3Xu1GoZW17h18T7fy+nct/YFzFjsaHW6awNP6HPdfKj/sbw2ITXY8v6r1en2+3/X6B4y4PgF7WZjZkH6UfxhwPENeq/laY1FkiRJY+ACiCRJ0nJane6WwFMHnO63ADIoDdbDgGcUHP61jJZS6IG9tt8HLm91uu1Wp7v+HBi3Lt5noN1sXA2c1+fUrjP++2lAv4WXebUA0tvd9b4ZhxcBh9QQznw2KD3gtRX1f/0s5x4wxbFIkiRpDFwAkSRJurcGYdJzposGpCI6DVgyoK/9igzcK7j7HOCwIu1m2ADYHziv1enuMc3j1sX7fC+n9zm2bavT3WC5/+63kHcXcGYF40+bLwHnzji2U6vT/X91BDPf9HYwDUrDfGNFw8zWz5rTGIskSZLGxwUQSZKknlanuzLwqgGn++3+oN1s3Ar8ZECbF7Q63UJP+babjVvazca+hJRDxxEmmkfxAOC7rU73zdM8bl28z//SbxfHIu696NGv/kfWbjaqmiSeGu1m4y7gHX1OfWyupHmbcrPVoBw6ZWBFY0xTLJIkSRoTi6BLkiT92+4MTkvSdwGk50Tg+X2OrwK8hlBIuZB2s/Er4IWtTndj4KXAc4EnEwozF9FpdboXt5uN46d53OWc3W42koJtRraA7/M9fkqoAzJzMnZX4KhefI/p024c6a8m+r0fpN1snNTqdE8Gdlvu8JbAG4FOLUHNH7fOcm69isa43yznli7379MUiyRJksbEHSCSJEn/Nqj4+VJmn/AdVAcEYJ9WpzvyZ652s3Flu9n4ZLvZ2A24P7Az8H7gVIabQFsMfLbV6RaaWK9r3Los1PvcbjaupX+h5l1m/HOmeVX/o4+3c9/dOQe0Ot371xHMfNFuNu4GrhtwesOKhpmtn6umMRZJkiSNjztAJEmSgFanuxnwrAGnT+uluuqr3Wxc1up0fwNs2+f0gwlPkp9UNsZeDKf1vmh1uqsCOwIvAl4NrDWg6WaE3S1Hz6Vx67IA7/NpwNYzjj241eluSf8FkDuBn4041pzQbjb+0Op0v8K9F0XXBw4A3lpPVPPGxYR7OdNWrU53jV6tnDK2GXD8xnazccMUxyJJkqQxcAFEkiQpeA2Dd8c+p9Xp3l2i79dRwQLITO1m43Z6E+atTvcDwDcZ/MT+M6hoIaKuceuyAO7zacBb+hzfhf4F0H/VbjZuHnGsueQAQnqytZc79sZWp3toTfHMF78D4j7HVwYeD5w5ase9mktbDDj9mymPRZIkSWPgAogkSVrweimq9h7jEM9rdbqbtpuNSweM/RBgK+CRvX/+66vdbFwzzADtZuOaVqf7YuCvhFRKM0XTMG5dvM+zOgNYxn0XAF8PbN7n+vme/gqAdrNxRavTPQj40HKHVwXawLvqiWpe+BmDf96+ghKLDsDLZjnXr99pikWSJEljYA0QSZKkUPD5wWPsfyXgtQPO7QJcSKgjcnDvuh2BDXpxDa3dbNwIZANOrzMl49bF+zy43+sJT8LPNDMt1j0WxAJIzyHAzIXLFxO+hxrNCdy3vso9Xt7qdEeqv9HqdFcG9pvlkuOmPBZJkiSNgQsgkiRJg4ufVzpGq9Ndqc/xXwKD0mu9boRxNhhw/KYpGbcu3ufZnT7kdbcDZ5Uca85oNxu3AO/pc+ojk45lvmg3G1cRFh76WQs4bMSuD2DwTqjftpuNc6Y5FkmSJI2HCyCSJGlBa3W6GwEvmMBQmwPPmXmwVwh3UD74p7Q63ZcOO0Cr030ig4vunjsN49bF+7xCw+7qOLu3KLCQfI37fg83qyOQeaQ9y7kXtjrdQgtMrU73P+m/UHWPA+dILJIkSaqYNUAkSdJC9ypglUHn2s3GEUU6a3W6ewGD2uwHHN/n+GHA5wa0+XKr013abjZmTZnS6nS3Bo6Z5ZJ+TznXNW5dvM+DnUFIBdRvl9LyFlL6KwDazcayVqf7NuDUumOZL9rNRtrqdL/B4DoZ72l1ulsAb52tTk6r010NeAfwQQY/3HdGu9k4ai7EIkmSpOq5ACJJkha6QbU5bgK+M0J/RwMdYP0+557d6nS3aDcbl8w4/nXgvcCmfdqsARzb6nRPBA4HzgauJKRV2oBQp+FFwKsZvJBzHnBKn+N1jVsX7/MA7Wbjxlan+1tguxVcuuAWQADazcZprU73eGD3umOZR94IPInB9Zf2AnZvdbpfBb4P/Am4Bli31+bZhALmD5lljOuAV86xWCRJklQhF0AkSdKC1ep0nwxsNeD0Ue1mY0nRPtvNxq2tTvcIoNnn9GJCvZH3zWhzc6vT3Rc4cZaun9v7KmoZ8MZ2s3GfOhR1jbsCO7Q63aJt+jm73Wwkyx/wPq/Qacy+AHIrkFYwziBj+95X5J2EiW7/hqpAu9m4odXpPhs4ExhUbHw9ws/S5ghD3ALs3m42/jaXYhlgrQreGw9pNxsXl+xDkiRpzrEGiCRJWshmK37+lRL9fmGWc69tdbr3mUBtNxs/AN5eYsxB3tFuNn466GRd49bF+zyrFe3u+EW72bi1orHmnHazcQGzv7dVUO+e7gRcVHHXVwE7t5uNs+ZiLJIkSaqOCyCSJGlBanW69wNePOD0n9vNxs9H7bs3kXbGgNMPZEAanXazcQghJddNo469nFuARrvZ+MSKLqxr3Lp4nwc6k1AHZJAFmf5qhg8AN9YdxHzSbjb+BMTAVwmp38o6AXhcu9k4ey7HIkmSpGq4ACJJkhaqlwNrDjhXZvfHPWZ7Uny/QSfazcaXCWm5vgTcPMK4txHif0y72fjSsI3qGrcu3ue+sd0EnDPLJQt+AaRXBPujdccx37SbjRvbzcbewPaEOkp3FuzibkIdnF3bzcbu7WbjivkQiyRJksozf60kSVqoBqW/WgYcUUH/3wE+RShkPdNurU73oe1mo2+qlXazcRnQaHW6/w08D9gB2JZQbPd+wDrAImApoRDvJcDvgbOAH7SbjX+OEnBd49bF+9zXacAT+hxfCvxyjOPOJZ8EXs/ggtkaUbvZOAd4SavTXR94DrAjsDXwIGB9YDXgDuCfhPfFeYT3xQntZuPS+RqLJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJEmSJGmO+f/dA7AGeIndkwAAAABJRU5ErkJggg==
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
        Write-DebugLog "[-] CRITICAL: VMware PowerCLI module is missing."
        Write-Terminal "ERROR: VMware PowerCLI module is missing. Please install it to use MTAT." "Red"
        try {
            $wshell = New-Object -ComObject Wscript.Shell
            [void]$wshell.Popup("CRITICAL ERROR: VMware PowerCLI module is missing. Please install it to use MTAT.", 10, "MTAT Error", 16)
        } catch {}
        exit
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
    Set-PowerCLIConfiguration -Scope Session -DefaultVIServerMode Multiple -InvalidCertificateAction Ignore -ParticipateInCEIP $false -Confirm:$false | Out-Null
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
    <title>Memory Tiering Assessment Tool v3.1</title>
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
        .container { max-width: 1100px; background: var(--surface-card); padding: 30px; border-radius: 8px; box-shadow: var(--shadow-card); margin: 0 auto; transition: background-color 0.15s ease; }
        .header-frame { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        h1 { font-size: 24px; margin: 0; color: var(--text-primary); display: inline-block; }
        /* Logo art is a light-background asset -- kept on its own fixed-white chip regardless of
           app theme (rather than var(--surface-card)) so it's never handed a dark backing it
           wasn't designed for. */
        .logo-box { background: #ffffff; border-radius: 6px; padding: 6px 14px; display: inline-flex; align-items: center; border: 1px solid var(--border); }
        .logo-box img { max-height: 180px; max-width: 560px; object-fit: contain; }
        .tab-header { display: flex; border-bottom: 2px solid var(--border); margin-bottom: 25px; align-items: flex-end; }
        .tab-header-btn { flex: 1 1 0; padding: 12px; background: var(--surface-page); border: 1px solid var(--border); border-bottom: none; font-size: 15px; font-weight: bold; color: var(--text-secondary); cursor: pointer; text-align: center; }
        .tab-header-btn.active { background: var(--surface-card); color: var(--text-primary); border-top: 3px solid var(--fill-accent); margin-bottom: -2px; font-weight: bold; }
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
            <h1>Memory Tiering Assessment Tool v3.1</h1>
            <div id="mainVerInfo" style="font-size: 11px; color: var(--text-muted);"></div>
        </div>
        <div class="logo-box" id="brandingLogoCell">##LOGO_HTML_PLACEHOLDER##</div>
    </div>
    <div class="tab-header">
        <div style="display: flex; flex-grow: 1;" role="tablist" aria-label="Assessment steps">
            <button class="tab-header-btn active" id="btn-tab-connect" role="tab" aria-selected="true" aria-controls="tab-connect" onclick="switchTab('tab-connect', this)">1. vCenter Connection</button>
            <button class="tab-header-btn" id="btn-tab-baseline" role="tab" aria-selected="false" aria-controls="tab-baseline" onclick="switchTab('tab-baseline', this)" style="display:none;">2. Baseline Assessment</button>
            <button class="tab-header-btn" id="btn-tab-simulator" role="tab" aria-selected="false" aria-controls="tab-simulator" onclick="switchTab('tab-simulator', this)" style="display:none;">3. Sizing &amp; Savings</button>
        </div>
        <button class="btn btn-sm theme-toggle-btn" id="themeToggleBtn" onclick="toggleTheme()" style="margin-bottom: 6px; margin-left: 15px; height: 28px; width: auto; padding: 0 15px;" title="Toggle light/dark appearance">&#9789; <span id="themeToggleLabel">Dark Mode</span></button>
        <button class="btn btn-sm" onclick="downloadDebugLog()" style="margin-bottom: 6px; margin-left: 15px; height: 28px; width: auto; padding: 0 15px; background-color:#5a6268;" title="Download this session's debug log -- useful if data looks incomplete or wrong">Download Debug Log</button>
        <button class="btn btn-sm btn-danger" onclick="shutdownServer()" style="margin-bottom: 6px; margin-left: 15px; height: 28px; width: auto; padding: 0 15px;">Exit Engine</button>
    </div>
    
    <div id="tab-connect" class="tab-content active" role="tabpanel" aria-labelledby="btn-tab-connect">
        <div class="form-panel" id="loginLoadingFrame">
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
            <div style="margin-top: 20px;">
                <button class="btn" id="connectBtn" onclick="runVcenterConnectPipeline()">Establish PowerCLI Sessions</button>
                <div id="connectProgressChips" class="progress-chip-row" style="display:none;" role="status" aria-live="polite"></div>
            </div>
        </div>
    </div>
    
    <div id="tab-baseline" class="tab-content" role="tabpanel" aria-labelledby="btn-tab-baseline">
        <div id="lockout-baseline" class="lockout-msg">Awaiting active inventory connection profile. Please complete Step 1.</div>
        <div id="content-baseline" style="display: none;">
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
                            <option value="rvtools">RVTools Export (vHost + vMemory/vInfo CSV)</option>
                            <option value="history">MTAT History (Matrix CSV / All-Tables Bundle)</option>
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
                    <div class="input-group">
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
                <div id="importStatusMsg" style="font-size:13px; font-weight:bold; margin-bottom:15px; display:none;" role="status" aria-live="polite"></div>
                <div style="display:flex; gap:15px;">
                    <button class="btn btn-green" id="importProcessBtn" style="width:auto; padding:0 25px;" onclick="processImportFiles()">Process Import</button>
                    <button class="btn" style="width:auto; padding:0 25px; background-color:#a0a0a0;" onclick="toggleImportPanel()">Cancel</button>
                </div>
            </div>

            <div class="section-block" id="metricsDisplayCard" style="display: none;">
                <div id="rowCollectionFailureWarn" class="warn-panel-box" style="display:none;" role="alert" aria-live="polite"></div>
                <div class="panel-title" id="lblChecklistTitle">Baseline Qualification Checklist:</div>
                <div class="assess-panel">
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Average CPU utilization across the selected range(s). Tiering candidates should run cool on CPU, since accessing the NVMe tier costs extra cycles.">CPU Usage (Avg)</span><span class="metric-target">[ Target: &lt;= 50% ]</span><div class="metric-value"><span id="lblBaseCpu">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseCpu"></div></div></div><span class="badge" id="badgeBaseCpu"></span></div>
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Highest sampled Active Memory % using vCenter's average-rollup samples (a true maximum-rollup query often isn't retained). Capacity math uses this worst-case value so sizing doesn't under-provision for bursty workloads.">Active Memory (Peak)</span><span class="metric-target">[ Target: &lt;= 50% ]</span><div class="metric-value"><span id="lblBaseActive">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseActive"></div></div></div><span class="badge" id="badgeBaseActive"></span></div>
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Average Active Memory % across the range -- shown for reference only. The Peak figure above (not this average) drives the pass/fail badge and all capacity/sizing math.">Active Memory (Avg)</span><span class="metric-target" style="font-style:italic;">[ For reference only ]</span><div class="metric-value"><span id="lblBaseActiveAvg">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseActiveAvg"></div></div></div></div>
                    <div id="rowActiveVariabilityWarn" style="display:none; margin: -6px 0 12px 0; font-size:12px; font-weight:bold; color:var(--text-warning-soft);" role="status" aria-live="polite"></div>
                    <div class="metric-row" style="justify-content:flex-start;"><span class="metric-name" title="Average Consumed Memory %. Tiering only activates once real memory pressure exists, so this must be at or above 80% before a cluster is a good candidate.">Consumed Memory (Avg)</span><span class="metric-target">[ Target: &gt;= 80% ]</span><div class="metric-value"><span id="lblBaseConsumed">0%</span><div class="pct-bar-track"><div class="pct-bar-fill" id="barBaseConsumed"></div></div></div><span class="badge" id="badgeBaseConsumed"></span><span class="note-text note-blue" id="lblBaseConsumedNote"></span></div>
                </div>
            </div>

            <div class="section-block section-block-alt" id="comparisonContainer" style="display: none;">
                <div class="action-container">
                    <div class="grid-title">Range Comparison Matrix (Historical Workload Trend Tracking)</div>
                    <button class="btn btn-sm" onclick="exportSectionToCSV('matrix')">Export Matrix CSV</button>
                </div>
                <table class="comp-table"><thead><tr><th>Target Cluster Scope</th><th>Analyzed Range Profile</th><th>CPU Avg %</th><th>Active Mem Peak %</th><th>Active Mem Avg %</th><th>Consumed Mem Avg %</th></tr></thead><tbody id="comparisonMatrixBody"></tbody></table>
                <div style="font-size:11px; color:var(--text-muted); margin-top:6px; font-style:italic;">Bars are scaled 0-100% for a quick visual read; exact figures are in the cell text.</div>
            </div>

            <div class="section-block" id="hostContainerPanel" style="display: none;">
                <div class="action-container">
                    <div class="grid-title">Physical Host Breakdown</div>
                    <button class="btn btn-sm" onclick="exportSectionToCSV('hosts')">Export Hosts CSV</button>
                </div>
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
                        <th class="sortable" data-type="text" onclick="sortTableByHeader(this)" title="Yes = memory is hardware-reservation-locked (vGPU, PCI passthrough, etc.) and can never be tiered to NVMe, regardless of how active it measures.">Pinned_Memory<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Pages_1GB<span class="sort-arrow"></span></th>
                        <th class="sortable" data-type="num" onclick="sortTableByHeader(this)">Pages_2MB<span class="sort-arrow"></span></th>
                    </tr></thead><tbody></tbody></table>
                </div>
            </div>

            <div style="margin-bottom:30px;">
                <button class="btn btn-orange" id="btnExportAll" style="display:none; width:100%; height:45px;" onclick="exportAllTablesToCSV()">Export All Tables Bundle</button>
            </div>
        </div>
    </div>
    
    <div id="tab-simulator" class="tab-content" role="tabpanel" aria-labelledby="btn-tab-simulator">
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
                            <option value="128">128 GB</option>
                            <option value="256">256 GB</option>
                            <option value="512">512 GB</option>
                            <option value="768">768 GB</option>
                            <option value="1024">1 TB (1024 GB)</option>
                            <option value="1536">1.5 TB (1536 GB)</option>
                            <option value="2048" selected>2 TB (2048 GB)</option>
                            <option value="3072">3 TB (3072 GB)</option>
                            <option value="4096">4 TB (4096 GB)</option>
                            <option value="6144">6 TB (6144 GB)</option>
                            <option value="8192">8 TB (8192 GB)</option>
                            <option value="custom">Custom...</option>
                        </select>
                        <input type="number" id="gfNodeCapCustom" value="2048" min="16" step="16" oninput="runSimulationMath()" style="display:none; width: 80px; padding: 10px;">
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
                    <input type="checkbox" id="chkMirroring" onchange="runSimulationMath()">
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
                        <div class="headroom-desc">Estimated additional compute slots gained (assumes standard 16GB VM profile sizing)</div>
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
    var globalDram = 0, globalConsumed = 0, globalActive = 0, globalActiveAvg = null, globalCpu = 0, selectedRangeName = "";
    var cachedHosts = [], cachedVms = [];
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
        // it fires after ~15 seconds (3 missed 5-second heartbeats) of this specific browser tab
        // failing to reach the engine at all (network drop, engine process crashed/exited, etc.),
        // not after minutes of genuine inactivity. The two are easy to conflate but describe
        // different things; keep this message worded to match what actually triggers it.
        if (missedBeats >= 3) {
            document.body.innerHTML = `
                <div style='text-align:center; padding:100px; font-family:sans-serif;'>
                    <h2 style='color:var(--text-danger-strong);'>Session Timed Out</h2>
                    <p style='color:var(--text-secondary); font-size:16px; font-weight:bold;'>The connection to the background engine was lost.</p>
                    <p style='color:var(--text-muted); font-size:14px; line-height:1.6; max-width:600px; margin:0 auto;'>
                        This tab could not reach the MTAT background engine for about 15 seconds -- it may have crashed, been closed, or the network path to it dropped. (Separately, to conserve system resources, the engine also shuts itself down automatically after 5 minutes with no connected tab at all.)<br><br>
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
            downloadBlobTrigger(data.content || "(log is empty)", "MTAT_debug_log.txt");
        })
        .catch(function(err) { showToast("Could not reach the engine to fetch the debug log: " + err.message, 'error'); });
    }

    function switchTab(id, btn) {
        var contents = document.querySelectorAll('.tab-content');
        for (var i = 0; i < contents.length; i++) contents[i].className = "tab-content";
        var buttons = document.querySelectorAll('.tab-header-btn');
        for (var j = 0; j < buttons.length; j++) { buttons[j].className = "tab-header-btn"; buttons[j].setAttribute('aria-selected', 'false'); }
        document.getElementById(id).className = "tab-content active";
        btn.className = "tab-header-btn active";
        btn.setAttribute('aria-selected', 'true');

        if(id === 'tab-simulator') { loadClusterSimulation(); }
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

    function runVcenterConnectPipeline() {
        var btn = document.getElementById('connectBtn');
        var servers = parseServersInput();
        if (servers.length === 0) { showToast("Please declare a vCenter.", 'warn'); return; }

        btn.disabled = true; btn.innerText = "Connecting...";
        buildProgressChips('connectProgressChips', servers);
        var useSame = document.getElementById('useSameCreds').checked;
        var payload = { targets: [] };

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
                btn.disabled = false; btn.innerText = "Establish PowerCLI Sessions";
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data.error) { showToast("vCenter Connection Error: " + data.error, 'error'); clearProgressChips('connectProgressChips'); return; }

                        // A (re)connect can point at an entirely different vCenter / server set than
                        // whatever was cached before -- clear it so a cluster name that happens to
                        // match one from the previous session can't silently serve stale data from a
                        // different vCenter (nothing here re-fetches on cluster-name collision alone).
                        clusterSessionCache = {};
                        cachedHosts = []; cachedVms = [];
                        rebuildGroupedMatrix();

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
                        var cList = data.clusters; if (typeof cList === 'string') cList = [cList];
                        for (var i = 0; i < cList.length; i++) {
                            var optHtml = "<option value='" + escapeHtml(cList[i].Value) + "'>" + escapeHtml(cList[i].Text) + "</option>";
                            cSelect.innerHTML += optHtml;
                            simSelect.innerHTML += optHtml;
                        }

                        document.getElementById('content-baseline').style.display = 'block';
                        document.getElementById('lockout-baseline').style.display = 'none';
                        document.getElementById('btn-tab-baseline').style.display = 'block';
                        document.getElementById('btn-tab-simulator').style.display = 'block';

                        loadClusterRanges();
                        switchTab('tab-baseline', document.getElementById('btn-tab-baseline'));
                    } catch(e) {
                        showToast("Response Formatting Trapped: " + e.message + "\n\nRaw Trace:\n" + xhr.responseText, 'error');
                        clearProgressChips('connectProgressChips');
                    }
                } else {
                    showToast("Fatal Web Channel Anomaly. HTTP Status: " + xhr.status + " (" + xhr.statusText + ")", 'error');
                    clearProgressChips('connectProgressChips');
                }
            }
        };
        xhr.onerror = function() {
            btn.disabled = false; btn.innerText = "Establish PowerCLI Sessions";
            showToast("Connection lost or network channel handshake dropped completely during vCenter authentication.", 'error');
            clearProgressChips('connectProgressChips');
        };
        xhr.send(JSON.stringify(payload));
    }

    function loadClusterRanges() {
        var activeCluster = document.getElementById('clusterSelect').value;
        if (!activeCluster) return;

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "/api/get-cluster-ranges", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
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
                            var isChecked = (rList[j] === "Real-Time Snapshot") ? "checked" : "";
                            var safeRange = escapeHtml(rList[j]);
                            rDiv.innerHTML += '<label class="checkbox-item"><input type="checkbox" class="range-cb" value="' + safeRange + '" ' + isChecked + '> ' + safeRange + '</label>';
                        }
                    } catch(e) { showToast("Error parsing cluster ranges: " + e.message, 'error'); }
                } else {
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
        // Guard against incomplete data from any of this function's three possible origins (live
        // analyze, CSV import, or a cached matrix record). Without this, a missing dram/consumed/
        // active/cpu field previously rendered as the literal string "undefined%" and/or silently
        // produced a false PASS/WARN badge below (JS comparisons against undefined/NaN don't error,
        // they just quietly evaluate to something that looks like a real, healthy result).
        var coreFieldsMissing = [];
        if (typeof parsed.dram !== 'number') coreFieldsMissing.push('dram');
        if (typeof parsed.consumed !== 'number') coreFieldsMissing.push('consumed');
        if (typeof parsed.active !== 'number') coreFieldsMissing.push('active');
        if (typeof parsed.cpu !== 'number') coreFieldsMissing.push('cpu');

        globalDram = (typeof parsed.dram === 'number') ? parsed.dram : 0;
        globalConsumed = (typeof parsed.consumed === 'number') ? parsed.consumed : 0;
        globalActive = (typeof parsed.active === 'number') ? parsed.active : 0;
        globalCpu = (typeof parsed.cpu === 'number') ? parsed.cpu : 0;
        // activeAvg is a reference-only companion to the peak Active Memory figure. It's optional:
        // live vCenter analysis always supplies it, but a re-imported MTAT export can't (the exported
        // CSV never retained a separate average), so it may be missing -- rendered as "N/A" below.
        globalActiveAvg = (typeof parsed.activeAvg === 'number') ? parsed.activeAvg : null;
        cachedHosts = parsed.hosts || []; cachedVms = parsed.vms || [];

        if (!clusterSessionCache[activeClusterValue]) {
            clusterSessionCache[activeClusterValue] = { lastRange: "", ranges: {} };
        }
        clusterSessionCache[activeClusterValue].lastRange = rangeLabel;
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
            warnMsgParts.push("&#9888; Data collection failed for " + parts.join(" and ") + " during this analysis -- they're excluded from the totals below (failed hosts still show as a row marked \"ERROR\"). Download the debug log (top-right) for details.");
        }
        if (coreFieldsMissing.length > 0) {
            warnMsgParts.push("&#9888; This data is incomplete -- missing: " + coreFieldsMissing.map(escapeHtml).join(", ") + " (defaulted to 0). The PASS/WARN badges below may not reflect real values. This usually means an older or partial import/cache record rather than a live analysis.");
        }
        if (warnMsgParts.length > 0) {
            failureWarnDiv.innerHTML = warnMsgParts.join("<br>");
            failureWarnDiv.style.display = 'block';
        } else {
            failureWarnDiv.style.display = 'none';
        }

        document.getElementById('lblChecklistTitle').innerText = "Baseline Qualification Checklist (Raw Hardware - " + rangeLabel + "):";

        var activePct = globalDram > 0 ? ((globalActive / globalDram) * 100).toFixed(1) : 0;
        var consumedPct = globalDram > 0 ? ((globalConsumed / globalDram) * 100).toFixed(1) : 0;
        var activeAvgPct = (globalActiveAvg !== null && globalDram > 0) ? ((globalActiveAvg / globalDram) * 100).toFixed(1) : null;

        document.getElementById('lblBaseCpu').innerText = globalCpu + "%";
        document.getElementById('lblBaseActive').innerText = activePct + "%";
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

        var activeB = document.getElementById('badgeBaseActive');
        activeB.innerText = activePct <= 50 ? "[ \u2713 ] PASS" : "[ X ] WARN";
        activeB.className = activePct <= 50 ? "badge badge-pass" : "badge badge-warn";
        setPctBar('barBaseActive', activePct, { pass: activePct <= 50 });
        setPctBar('barBaseActiveAvg', activeAvgPct === null ? 0 : activeAvgPct, {});

        var consumedB = document.getElementById('badgeBaseConsumed');
        consumedB.innerText = consumedPct >= 80 ? "[ \u2713 ] PASS" : "[ i ] NOTE";
        consumedB.className = consumedPct >= 80 ? "badge badge-pass" : "badge badge-info";
        setPctBar('barBaseConsumed', consumedPct, { pass: consumedPct >= 80 });

        document.getElementById('lblBaseConsumedNote').innerText = consumedPct >= 80 ? "" : " (Memory Tiering will not trigger until there is memory pressure (80%))";

        rebuildGroupedMatrix();

        // New data replaces the tables wholesale -- clear any leftover filter text/sort indicator
        // from a previous analysis so it can't silently hide/reorder rows that were never filtered.
        var hostFilterEl = document.getElementById('hostTableFilter'); if (hostFilterEl) hostFilterEl.value = "";
        var vmFilterEl = document.getElementById('vmTableFilter'); if (vmFilterEl) vmFilterEl.value = "";
        document.querySelectorAll('#hostTable th.sortable, #vmTable th.sortable').forEach(function(h) {
            h.removeAttribute('data-sort-dir');
            var arrow = h.querySelector('.sort-arrow'); if (arrow) arrow.textContent = '';
        });

        var hBody = document.querySelector('#hostTable tbody'); hBody.innerHTML = "";
        for (var k = 0; k < cachedHosts.length; k++) {
            var h = cachedHosts[k];
            var rowStyle = (h.Tiering === "ERROR") ? " style=\"background-color:var(--soft-bg-danger); color:var(--text-danger-soft); font-weight:bold;\"" : "";
            // Cluster/HostName/Tiering can originate from a live vCenter object name OR an offline
            // CSV import (an arbitrary file picked from disk) -- escaped like every other dynamic
            // value in this function, rather than trusted as always-safe plain text.
            hBody.innerHTML += "<tr" + rowStyle + "><td>" + escapeHtml(h.Cluster) + "</td><td>" + escapeHtml(h.HostName) + "</td><td>" + escapeHtml(h.Tiering) + "</td><td>" + h.CPU_Pct + "%</td><td>" + h.Physical_RAM + "</td><td>" + h.Consumed_GB + "</td><td>" + h.Active_GB + "</td><td>" + h.Active_Pct + "%</td></tr>";
        }

        var vBody = document.querySelector('#vmTable tbody'); vBody.innerHTML = "";
        for (var m = 0; m < cachedVms.length; m++) {
            var v = cachedVms[m];
            var pinnedCell = (v.Pinned_Memory === "Yes")
                ? "<span style=\"color:var(--text-warning-soft); font-weight:bold;\">Yes</span>"
                : escapeHtml(v.Pinned_Memory || "N/A");
            vBody.innerHTML += "<tr><td>" + escapeHtml(v.Host) + "</td><td>" + escapeHtml(v.VMName) + "</td><td>" + v.Provisioned_GB + "</td><td>" + v.Active_GB + "</td><td>" + v.Active_Pct + "%</td><td>" + pinnedCell + "</td><td>" + escapeHtml(v.Pages_1GB) + "</td><td>" + escapeHtml(v.Pages_2MB) + "</td></tr>";
        }

        document.getElementById('simClusterSelect').value = activeClusterValue;
        loadClusterSimulation();
    }

    function executeClusterDataCollection() {
        var btn = document.getElementById('analyzeBtn');
        btn.disabled = true; btn.innerText = "Querying Metrics...";
        var activeClusterValue = document.getElementById('clusterSelect').value;
        if (!activeClusterValue) { showToast("Please select a Target Cluster Scope.", 'warn'); btn.disabled = false; btn.innerText = "Analyze Selection Profile"; return; }

        var checkboxes = document.querySelectorAll('.range-cb:checked');
        if (checkboxes.length === 0) { showToast("Please select at least one range.", 'warn'); btn.disabled = false; btn.innerText = "Analyze Selection Profile"; return; }

        analysisInProgress = true;
        missedBeats = 0;
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
                if (collectionErrors.length > 0) {
                    showToast("Analysis finished, but " + collectionErrors.length + " of " + totalRequests + " range(s) failed:\n\n" + collectionErrors.join("\n"), 'error');
                }
            }
        }

        for (var x = 0; x < checkboxes.length; x++) {
            (function(selectedRange, chipIndex) {
                var payload = { cluster: activeClusterValue, range: selectedRange };
                var xhr = new XMLHttpRequest();
                xhr.open("POST", "/api/analyze", true);
                xhr.setRequestHeader("Content-Type", "application/json");
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === 4) {
                        if (xhr.status === 200) {
                            try {
                                var parsed = JSON.parse(xhr.responseText);
                                if (parsed.error) {
                                    collectionErrors.push(selectedRange + ": " + parsed.error);
                                    setProgressChipState('analyzeProgressChips', chipIndex, 'failed', selectedRange);
                                    checkTaskCompletion(); return;
                                }
                                applyAnalysisResult(activeClusterValue, selectedRange, parsed);
                                setProgressChipState('analyzeProgressChips', chipIndex, 'done', selectedRange);
                            } catch(e) {
                                collectionErrors.push(selectedRange + ": " + e.message);
                                setProgressChipState('analyzeProgressChips', chipIndex, 'failed', selectedRange);
                            }
                        } else {
                            var errMsg = (xhr.status === 0)
                                ? "CRITICAL: The background MTAT engine is no longer running. It likely timed out due to 5 minutes of inactivity. Please relaunch the application."
                                : "Analysis failed on route with status code: " + xhr.status;
                            collectionErrors.push(selectedRange + ": " + errMsg);
                            setProgressChipState('analyzeProgressChips', chipIndex, 'failed', selectedRange);
                        }
                        checkTaskCompletion();
                    }
                };
                xhr.onerror = function() {
                    collectionErrors.push(selectedRange + ": Connection to the background engine was lost.");
                    setProgressChipState('analyzeProgressChips', chipIndex, 'failed', selectedRange);
                    checkTaskCompletion();
                };
                // Safety net only -- a genuinely large cluster/historical range can legitimately take
                // a while. Without this, a request the server accepts but never answers (e.g. a
                // hung Get-Stat call) leaves completedRequests permanently short, disabling the
                // "Analyze Selection Profile" button forever with no visible error at all.
                xhr.timeout = 300000;
                xhr.ontimeout = function() {
                    collectionErrors.push(selectedRange + ": timed out after 5 minutes with no response from the engine.");
                    setProgressChipState('analyzeProgressChips', chipIndex, 'failed', selectedRange);
                    checkTaskCompletion();
                };
                xhr.send(JSON.stringify(payload));
            })(checkboxes[x].value, x);
        }
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
            cachedHosts = data.hosts || []; cachedVms = data.vms || [];

            document.getElementById('gfTargetHosts').value = cachedHosts.length || 4;
            
            if (cachedHosts.length > 0 && globalDram > 0) {
                var avgDramPerHost = Math.round(globalDram / cachedHosts.length);
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

    function rebuildGroupedMatrix() {
        var compBody = document.getElementById('comparisonMatrixBody');
        compBody.innerHTML = "";

        for (var clusterKey in clusterSessionCache) {
            var cache = clusterSessionCache[clusterKey];
            var rangesObj = cache.ranges;
            var rangeNames = Object.keys(rangesObj);
            var rowSpanCount = rangeNames.length;

            var parts = clusterKey.split('|');
            var serverLabel = parts[0];
            var clusterLabel = parts[1];
            var printableTitle = clusterLabel + " (" + serverLabel + ")";

            for (var i = 0; i < rowSpanCount; i++) {
                var currentRange = rangeNames[i];
                var data = rangesObj[currentRange];
                var actPct = data.dram > 0 ? ((data.active / data.dram) * 100).toFixed(1) : 0;
                var actAvgPct = (typeof data.activeAvg === 'number' && data.dram > 0) ? ((data.activeAvg / data.dram) * 100).toFixed(1) : null;
                var consPct = data.dram > 0 ? ((data.consumed / data.dram) * 100).toFixed(1) : 0;

                var rowHtml = "";
                if (i === 0) {
                    // The cluster key is passed via a data-attribute, read back with getAttribute(),
                    // rather than interpolated directly into the onclick JS source string -- entity-
                    // encoding a quote (e.g. "&#39;") does NOT actually protect an inline event handler,
                    // since the browser HTML-decodes attribute values BEFORE parsing them as JS, so a
                    // key containing an apostrophe could otherwise still break out of the string
                    // literal or inject script. This way the onclick text itself is a fixed, static
                    // string with no untrusted content in it at all.
                    rowHtml += '<td rowspan="' + rowSpanCount + '"><a href="#" class="cluster-link" data-cluster-key="' + escapeHtml(clusterKey) + '" onclick="loadClusterFromCache(this.getAttribute(\'data-cluster-key\')); return false;">' + escapeHtml(printableTitle) + '</a></td>';
                }
                rowHtml += "<td>" + escapeHtml(currentRange) + "</td><td>" + pctBarCellHtml(data.cpu, data.cpu) + "</td><td>" + pctBarCellHtml(actPct, actPct) + "</td><td>" + (actAvgPct === null ? "N/A" : pctBarCellHtml(actAvgPct, actAvgPct)) + "</td><td>" + pctBarCellHtml(consPct, consPct) + "</td>";
                compBody.innerHTML += "<tr>" + rowHtml + "</tr>";
            }
        }
    }

    function runSimulationMath() {
        var strategy = document.getElementById('simStrategy') ? document.getElementById('simStrategy').value : 'brownfield';
        var hostCount = cachedHosts.length || 1;
        var avgDramPerHost = Math.round(globalDram / hostCount);
        var activePct = globalDram > 0 ? ((globalActive / globalDram) * 100).toFixed(1) : 0;

        var clusterIsAlreadyTiered = cachedHosts.some(function(h) { return h.Tiering === "Enabled"; });
        var activeTierAlertDiv = document.getElementById('simTieringActiveAlert');
        var matchingConfig = false;
        var existingRatioPct = 100;
        
        if (clusterIsAlreadyTiered) {
            var tieredHosts = cachedHosts.filter(function(h) { return h.Tiering === "Enabled"; });
            // Use a type check, not `||` -- a genuine ratio of 0 is falsy in JS and would otherwise
            // be silently replaced by the 100 default, same class of bug as the server-side
            // $hostTierRatioReported fix for TierRatioPct.
            existingRatioPct = (typeof tieredHosts[0].TierRatioPct === 'number') ? tieredHosts[0].TierRatioPct : 100;
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
            
            var serverCost = parseFloat(document.getElementById('gfServerCost').value) || 15000;
            var priceDramGB = parseFloat(document.getElementById('costDram').value) || 100;
            var priceNvmeGB = parseFloat(document.getElementById('costNvme').value) || 0.25;
            var mirroringActive = document.getElementById('chkMirroring').checked;

            var standardReqHosts = 0, tieredReqHosts = 0;
            var totalNodeMem = 0, gfDram = 0, gfNvme = 0;
            var stdMemProfile = 0;
            var limitingFactorMsg = "";
            var partitionExceeded = false;
            // Capacity mode and Target-Usable-Hosts mode hit the same 4096 GB NVMe partition cap in
            // genuinely different ways (capacity mode reduces deliverable capacity; host-count mode
            // shifts the shortfall into DRAM instead) -- each branch below sets its own accurate
            // explanation rather than sharing one hardcoded message that's only true for one of them.
            var partitionExceededMsg = "";
            var currentTotalCpu = globalCpu * hostCount;

            if (gfMode === 'capacity') {
                var selVal = document.getElementById('gfNodeCapSelect').value;
                var gfNodeCap = parseFloat(selVal === 'custom' ? document.getElementById('gfNodeCapCustom').value : selVal);
                if (isNaN(gfNodeCap) || gfNodeCap < 1) gfNodeCap = 2048;
                var cpuMult = parseFloat(document.getElementById('gfCpuMult').value) || 1.0;

                // Option A (Standard Refresh) is 100% DRAM -- it has no NVMe tier, so it must size
                // against the FULL capacity the user actually requested, never the NVMe-partition-
                // capped figure below. stdMemProfile is fixed to the requested capacity for exactly
                // this reason; only Tiered's own totalNodeMem/gfDram/gfNvme are affected by the cap.
                var requestedNodeCap = gfNodeCap;
                stdMemProfile = requestedNodeCap;

                gfDram = Math.round(requestedNodeCap / (1 + gfRatioVal));
                gfNvme = requestedNodeCap - gfDram;
                if (gfNvme > 4096) {
                    gfNvme = 4096;
                    partitionExceeded = true;
                    totalNodeMem = gfDram + gfNvme;
                } else {
                    totalNodeMem = requestedNodeCap;
                }

                // Live feedback on the Ratio dropdown itself: the ratio is a % of node capacity, but
                // the Active Memory safety floor below is an absolute GB amount -- the same ratio is
                // harmless on a large node and can shrink DRAM to a sliver on a small one. Surfacing
                // the resulting GB split here, before the host-count math runs, catches that early.
                if (gfRatioPreviewDiv) { gfRatioPreviewDiv.innerText = "-> " + gfDram + " GB DRAM + " + gfNvme + " GB NVMe per host"; }
                // 32: not a hard platform limit like the 4096 GB partition cap elsewhere -- just a
                // practical "this is probably too small to be a useful fast tier" heuristic, since a
                // DRAM tier this size will usually fail the Active Memory safety check below and
                // balloon the host count long before it fails for any other reason.
                if (gfSmallDramWarnDiv && gfDram < 32) {
                    gfSmallDramWarnDiv.innerHTML = "[ ! ] This ratio leaves only <strong>" + gfDram + " GB</strong> of DRAM per host at " + requestedNodeCap + " GB node capacity -- likely too small to hold your Active Memory safely, which is what drives the host count up below. Try a lower NVMe ratio or a larger Target Node Capacity instead.";
                    gfSmallDramWarnDiv.style.display = 'block';
                }

                var reqConsumedStd = Math.ceil(globalConsumed / stdMemProfile);
                var reqConsumedTiered = Math.ceil(globalConsumed / totalNodeMem);
                // 80: CPU safety ceiling -- host count is sized so no host runs above 80% average
                // CPU utilization, leaving headroom for HA failover absorption and burst load rather
                // than sizing to the theoretical 100% ceiling.
                var reqCpu = Math.ceil(currentTotalCpu / (80 * cpuMult));

                var standardBase = Math.max(reqConsumedStd, reqCpu);
                if (standardBase < 1) standardBase = 1;
                standardReqHosts = standardBase + haNodes;

                // 0.50: Active Memory safety limit -- the same "keep Active Memory <= 50% of Tier-0
                // DRAM" target shown on the Baseline Assessment checklist. Host count here is
                // whatever's needed so the cluster's Active Memory never exceeds half of the
                // deployed DRAM capacity, leaving headroom since Memory Tiering performance degrades
                // as the hot/active working set approaches the full size of the fast tier.
                var reqActive = Math.ceil(globalActive / (gfDram * 0.50));
                var tieredBase = Math.max(reqConsumedTiered, reqCpu, reqActive);
                if (tieredBase < 1) tieredBase = 1;
                tieredReqHosts = tieredBase + haNodes;

                if (tieredBase === reqActive && reqActive >= Math.max(reqConsumedTiered, reqCpu)) {
                    limitingFactorMsg = "This extra host is intentional, not a miscalculation: Active Memory (" + globalActive + " GB) must stay within 50% of each host's DRAM tier to protect performance, so " + tieredReqHosts + " hosts are required here. A larger Target Node Capacity (or a DRAM-heavier ratio) closes this cost gap while keeping that same protection.";
                } else if (tieredBase === reqCpu && reqCpu >= Math.max(reqConsumedTiered, reqActive)) {
                    limitingFactorMsg = "You need " + tieredReqHosts + " total hosts because your current CPU workload would overload fewer servers (capped at 80% usage per host). Increase your 'New Node CPU Capacity' if buying faster servers.";
                } else if (tieredBase === reqConsumedTiered) {
                    limitingFactorMsg = "You need " + tieredReqHosts + " total hosts simply because your VMs are currently consuming " + globalConsumed + " GB of memory. To consolidate into fewer hosts, select a larger Target Node Capacity.";
                }

                if (partitionExceeded) {
                    partitionExceededMsg = "NVMe tier allocations are automatically capped at 4TB (4,096 GB) per host to align with vSphere maximum kernel limits. Your Tiered node's deliverable capacity was reduced to " + totalNodeMem + " GB instead of the requested " + requestedNodeCap + " GB. Option A (Standard Refresh) is unaffected, since it has no NVMe tier.";
                }
            } else {
                var targetHosts = parseInt(document.getElementById('gfTargetHosts').value);
                if (isNaN(targetHosts) || targetHosts < 1) targetHosts = hostCount;
                
                var usableHosts = targetHosts;
                if (usableHosts < 1) {
                    usableHosts = 1;
                    limitingFactorMsg = "[!] Warning: Sizing reflects a single usable host.<br><br>";
                }

                var reqConsumed = Math.ceil(globalConsumed / usableHosts);
                // 80: same CPU safety ceiling as the capacity-mode branch above -- here solved for
                // the CPU speed multiplier needed (given a fixed host count) instead of for host
                // count (given a fixed speed), but it's the same "don't run hotter than 80%" target.
                var reqCpuMult = (currentTotalCpu / usableHosts) / 80;
                var cpuString = reqCpuMult > 1.0 ? reqCpuMult.toFixed(2) + "x" : "1.0x";

                standardReqHosts = usableHosts + haNodes;
                stdMemProfile = Math.ceil(reqConsumed / 64) * 64;
                if(stdMemProfile < 128) stdMemProfile = 128;

                // 0.50: same Active Memory safety limit as the capacity-mode branch -- here solved
                // for the minimum DRAM needed (given a fixed host count) so Active Memory never
                // exceeds half of it, instead of for host count (given a fixed DRAM size).
                var reqActive = Math.ceil(globalActive / usableHosts);
                var minDramForActive = Math.ceil(reqActive / 0.50);
                var dramForCons = Math.ceil(reqConsumed / (1 + gfRatioVal));
                
                gfDram = Math.max(minDramForActive, dramForCons);
                gfDram = Math.ceil(gfDram / 64) * 64; 
                
                gfNvme = Math.ceil(gfDram * gfRatioVal);
                if (gfNvme > 4096) {
                    gfNvme = 4096;
                    partitionExceeded = true;
                    var missingCap = reqConsumed - (gfDram + gfNvme);
                    if (missingCap > 0) {
                        gfDram += Math.ceil(missingCap / 64) * 64;
                    }
                    partitionExceededMsg = "NVMe tier allocations are automatically capped at 4TB (4,096 GB) per host to align with vSphere maximum kernel limits. Remaining required capacity was shifted to DRAM.";
                }

                tieredReqHosts = usableHosts + haNodes;
                totalNodeMem = gfDram + gfNvme;

                if (limitingFactorMsg === "") {
                     var haString = haNodes > 0 ? " (plus " + haNodes + " HA node" + (haNodes > 1 ? "s" : "") + ")" : "";
                     limitingFactorMsg = "To safely run this workload on exactly " + usableHosts + " usable host(s)" + haString + ", each new server requires at least <strong>" + stdMemProfile + " GB</strong> of total memory capacity, and CPUs roughly <strong>" + cpuString + " faster</strong> than your existing hosts.";
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
            var projectedActivePct = (tieredReqHosts * gfDram) > 0 ? ((globalActive / (tieredReqHosts * gfDram)) * 100).toFixed(1) : 0;

            if (clusterIsAlreadyTiered) {
                activeTierAlertDiv.innerText = "[ i ] Environment Context: Memory Tiering is already active on this cluster (currently configured at " + existingRatioPct + "% ratio). Formulas below outline incremental capacity shifts vs the active baseline.";
            }

            document.getElementById('gfStdProfile').innerText = stdMemProfile + " GB / Host";
            document.getElementById('gfStdHosts').innerText = standardReqHosts;
            document.getElementById('gfStdConsol').innerText = hostCount + " \u2794 " + standardReqHosts;
            document.getElementById('gfStdCost').innerText = "$" + totalStandardCost.toLocaleString('en-US', {minimumFractionDigits: 0, maximumFractionDigits: 0});

            document.getElementById('gfTierProfile').innerText = gfDram + " GB + " + gfNvme + " GB NVMe";
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
            if (msg !== "") ceilingWarningCard.innerHTML = msg;

            var simActiveBadge = document.getElementById('gfActiveBadge');
            if (projectedActivePct <= 50) {
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
            var nvmePerHostUsable = 0;
            var effectiveMultiplier = 1;
            var ratioExceeded = false;
            var partitionExceeded = false;

            var driveSizeGBSelected = 0;
            if (mode === 'ratio') {
                effectiveMultiplier = parseInt(document.getElementById('simRatio').value) || 1;
                nvmePerHostUsable = Math.round(avgDramPerHost * effectiveMultiplier);

                // The 4096 GB NVMe partition cap is a vSphere kernel/hardware constraint -- it applies
                // regardless of which UI control (ratio dropdown vs. custom % vs. raw drive size) was
                // used to reach the same effective per-host NVMe size. Without this, a host with high
                // avgDramPerHost could reach an unsupported >4096 GB/host config via this dropdown with
                // no warning, while the identical value entered through 'custom' mode would be capped.
                if (nvmePerHostUsable > 4096) {
                    nvmePerHostUsable = 4096;
                    partitionExceeded = true;
                    effectiveMultiplier = avgDramPerHost > 0 ? (4096 / avgDramPerHost) : 0;
                }
                driveSizeGBSelected = nvmePerHostUsable;
            } else if (mode === 'custom') {
                var inputPct = parseFloat(document.getElementById('customPct').value) || 0;
                effectiveMultiplier = inputPct / 100;
                nvmePerHostUsable = Math.round(avgDramPerHost * effectiveMultiplier);
                
                if (nvmePerHostUsable > 4096) {
                    nvmePerHostUsable = 4096;
                    partitionExceeded = true;
                    effectiveMultiplier = avgDramPerHost > 0 ? (4096 / avgDramPerHost) : 0;
                }
                
                if (effectiveMultiplier > 4) {
                    effectiveMultiplier = 4;
                    nvmePerHostUsable = Math.round(avgDramPerHost * 4);
                    ratioExceeded = true;
                }
                driveSizeGBSelected = nvmePerHostUsable;
            } else {
                driveSizeGBSelected = parseFloat(document.getElementById('simDriveSize').value) || 0;
                nvmePerHostUsable = driveSizeGBSelected;
                
                if (nvmePerHostUsable > 4096) {
                    nvmePerHostUsable = 4096;
                    partitionExceeded = true;
                }

                effectiveMultiplier = avgDramPerHost > 0 ? (nvmePerHostUsable / avgDramPerHost) : 0;
                
                if (effectiveMultiplier > 4) {
                    effectiveMultiplier = 4;
                    nvmePerHostUsable = Math.round(avgDramPerHost * 4);
                    ratioExceeded = true;
                }
            }

            var totalNvmeClusterSizeUsable = nvmePerHostUsable * hostCount;
            var totalTieredMem = globalDram + totalNvmeClusterSizeUsable;
            
            var totalUsed = totalTieredMem > 0 ? ((globalConsumed / totalTieredMem) * 100).toFixed(2) : 0;

            var priceDramGB = parseFloat(document.getElementById('costDram').value) || 100;
            var priceNvmeGB = parseFloat(document.getElementById('costNvme').value) || 0.25;
            var mirroringActive = document.getElementById('chkMirroring').checked;
            
            var totalPhysicalNvmeClusterSize = driveSizeGBSelected * hostCount;
            var rawDramExpansionCost = totalNvmeClusterSizeUsable * priceDramGB;
            var tieredHardwareCost = totalPhysicalNvmeClusterSize * priceNvmeGB * (mirroringActive ? 2 : 1);
            
            if (clusterIsAlreadyTiered) {
                var inputSimPct = 0;
                if (mode === 'ratio') {
                    inputSimPct = parseInt(document.getElementById('simRatio').value) * 100;
                } else if (mode === 'custom') {
                    inputSimPct = parseFloat(document.getElementById('customPct').value);
                } else {
                    inputSimPct = effectiveMultiplier * 100;
                }

                if (Math.abs(inputSimPct - existingRatioPct) < 1) { 
                    matchingConfig = true;
                }
                
                if (matchingConfig) {
                    activeTierAlertDiv.innerText = "[ i ] Environment Context: Memory Tiering is already active on this cluster at a " + existingRatioPct + "% NVMe ratio configuration. The target you selected matches the live baseline exactly.";
                } else {
                    activeTierAlertDiv.innerText = "[ i ] Environment Context: Memory Tiering is already active on this cluster (currently configured at " + existingRatioPct + "% ratio). Formulas below outline incremental capacity shifts vs the active baseline.";
                }
            }

            var netFinancialSavings = rawDramExpansionCost - tieredHardwareCost;

            var typicalVmProfileGB = 16;
            var currentVmDensity = Math.floor(globalDram / typicalVmProfileGB);
            var simulatedVmDensity = Math.floor(totalTieredMem / typicalVmProfileGB);
            var netVmDensityGain = simulatedVmDensity - currentVmDensity;

            document.getElementById('bfDram').innerText = globalDram + " GB";
            document.getElementById('bfDramPerHost').innerText = avgDramPerHost + " GB";
            
            document.getElementById('bfNvme').innerText = "+ " + totalNvmeClusterSizeUsable + " GB Usable Total";
            document.getElementById('bfNvmePerHost').innerText = "+ " + nvmePerHostUsable + " GB";
            
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
            
            document.getElementById('bfHeadroom').innerText = "+ " + netVmDensityGain + " VMs";

            var driveCountLabel = mirroringActive ? "2x " : "1x ";
            if (mode === 'ratio') {
                document.getElementById('bfDriveReqLabel').innerText = driveCountLabel + (nvmePerHostUsable >= 1000 ? (nvmePerHostUsable/1024).toFixed(2) + " TB" : nvmePerHostUsable + " GB") + " Drive/Host minimum specification (Ratio 1:" + effectiveMultiplier + ")";
            } else if (mode === 'custom') {
                document.getElementById('bfDriveReqLabel').innerText = driveCountLabel + (nvmePerHostUsable >= 1000 ? (nvmePerHostUsable/1024).toFixed(2) + " TB" : nvmePerHostUsable + " GB") + " Drive/Host minimum specification (" + (effectiveMultiplier * 100).toFixed(0) + "% NVMe)";
            } else {
                document.getElementById('bfDriveReqLabel').innerText = driveCountLabel + (driveSizeGBSelected >= 1000 ? (driveSizeGBSelected/1024).toFixed(2) + " TB" : driveSizeGBSelected + " GB") + " Drive provisioned \u2794 Yields Usable Ratio 1:" + effectiveMultiplier.toFixed(2);
            }

            // 1:1 is the only ratio that doesn't ask Active Memory to fit inside a smaller DRAM
            // tier than the workload's own baseline -- anything above it is a deliberate tradeoff,
            // not a free multiplier, so it's called out every time it's selected, independent of
            // (and always shown alongside, never replaced by) whichever cap/exceed notice below
            // also applies. Tolerance covers 'drive' mode, where the effective ratio is derived
            // from a physical drive size and rarely lands on an exact integer.
            var ratioAdvisoryMsg = (Math.abs(effectiveMultiplier - 1) > 0.03)
                ? "The recommended ratio for Memory Tiering is 1:1 (Default). Ratios above 1:1 require additional workload assessment, since Active Memory needs to be proportionally lower to reliably fit within the DRAM tier."
                : "";

            if (ratioAdvisoryMsg || partitionExceeded || ratioExceeded) {
                ceilingWarningCard.style.display = 'block';
                ceilingWarningCard.className = 'info-panel-box';
                var msg = "";
                if (ratioAdvisoryMsg) { msg += "[ i ] INFO: " + ratioAdvisoryMsg; }
                if (partitionExceeded || ratioExceeded) {
                    var capMsg = "The highest supported memory tiering configuration is a 1:4 ratio. ";
                    if (partitionExceeded && ratioExceeded) {
                        capMsg += "The active capacity parameters have been capped at a usable 4TB (4,096 GB) per host, matching maximum layout profile boundaries.";
                    } else if (partitionExceeded) {
                        capMsg += "Usable tier allocations are capped at 4TB per host to align with vSphere kernel constraints.";
                    } else if (ratioExceeded) {
                        capMsg += "The target hardware specs have been automatically balanced to map within standard 1:4 layout configurations.";
                    }
                    msg += (msg ? "<br><br>" : "") + "[ i ] INFO: " + capMsg;
                }
                ceilingWarningCard.innerHTML = msg;
            }

            var simActiveBadge = document.getElementById('bfActiveBadge');
            if (activePct <= 50) {
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

    function toggleSelectAllRanges() {
        var cbs = document.querySelectorAll('.range-cb');
        var lnk = document.getElementById('selectAllToggle');
        var checking = (lnk.innerText.trim() === "Select All");
        for (var i = 0; i < cbs.length; i++) { cbs[i].checked = checking; }
        lnk.innerText = checking ? "Deselect All" : "Select All";
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

    function generateCsvString(type) {
        var csv = "";
        if (type === 'matrix') {
            csv = "Target Cluster Scope,Analyzed Range Profile,CPU Avg Pct,Active Mem Peak Pct,Active Mem Avg Pct,Consumed Mem Avg Pct\r\n";
            for (var clusterKey in clusterSessionCache) {
                var cache = clusterSessionCache[clusterKey];
                for (var rName in cache.ranges) {
                    var d = cache.ranges[rName];
                    var actPct = d.dram > 0 ? ((d.active / d.dram) * 100).toFixed(1) : 0;
                    var actAvgPct = (typeof d.activeAvg === 'number' && d.dram > 0) ? ((d.activeAvg / d.dram) * 100).toFixed(1) : null;
                    var consPct = d.dram > 0 ? ((d.consumed / d.dram) * 100).toFixed(1) : 0;
                    csv += csvField(clusterKey.split('|')[1]) + "," + csvField(rName) + "," + d.cpu + "%," + actPct + "%," + (actAvgPct === null ? "N/A" : actAvgPct + "%") + "," + consPct + "%\r\n";
                }
            }
            return csv;
        }
        if (type === 'hosts') {
            csv = "Cluster,HostName,Tiering,CPU_Pct,Physical_RAM,Consumed_GB,Active_GB,Active_Pct\r\n";
            for (var j = 0; j < cachedHosts.length; j++) {
                var h = cachedHosts[j]; csv += csvField(h.Cluster) + "," + csvField(h.HostName) + "," + csvField(h.Tiering) + "," + h.CPU_Pct + "," + h.Physical_RAM + "," + h.Consumed_GB + "," + h.Active_GB + "," + h.Active_Pct + "\r\n";
            }
            return csv;
        }
        if (type === 'vms') {
            csv = "Host,VMName,Provisioned_GB,Active_GB,Active_Pct,Pinned_Memory,Pages_1GB,Pages_2MB\r\n";
            for (var k = 0; k < cachedVms.length; k++) {
                var v = cachedVms[k]; csv += csvField(v.Host) + "," + csvField(v.VMName) + "," + v.Provisioned_GB + "," + v.Active_GB + "," + v.Active_Pct + "," + csvField(v.Pinned_Memory || "N/A") + "," + csvField(v.Pages_1GB) + "," + csvField(v.Pages_2MB) + "\r\n";
            }
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
        var globalHostCsv = "Cluster,RangeName,ClusterContext,HostName,Tiering,CPU_Pct,Physical_RAM,Consumed_GB,Active_GB,Active_Pct\r\n";
        var globalVmCsv = "Cluster,RangeName,ClusterContext,Host,VMName,Provisioned_GB,Active_GB,Active_Pct,Pinned_Memory,Pages_1GB,Pages_2MB\r\n";

        for (var clusterKey in clusterSessionCache) {
            var cache = clusterSessionCache[clusterKey];
            var cName = clusterKey.split('|')[1];
            for (var rName in cache.ranges) {
                var dataObj = cache.ranges[rName];
                var safeCluster = csvField(cName);
                var safeRange = csvField(rName);
                var clusterContext = csvField(cName + " (" + rName + ")");
                var hArr = dataObj.hosts || [];
                for (var x = 0; x < hArr.length; x++) {
                    var h = hArr[x]; globalHostCsv += safeCluster + "," + safeRange + "," + clusterContext + "," + csvField(h.HostName) + "," + csvField(h.Tiering) + "," + h.CPU_Pct + "," + h.Physical_RAM + "," + h.Consumed_GB + "," + h.Active_GB + "," + h.Active_Pct + "\r\n";
                }
                var vArr = dataObj.vms || [];
                for (var y = 0; y < vArr.length; y++) {
                    var v = vArr[y]; globalVmCsv += safeCluster + "," + safeRange + "," + clusterContext + "," + csvField(v.Host) + "," + csvField(v.VMName) + "," + v.Provisioned_GB + "," + v.Active_GB + "," + v.Active_Pct + "," + csvField(v.Pinned_Memory || "N/A") + "," + csvField(v.Pages_1GB) + "," + csvField(v.Pages_2MB) + "\r\n";
                }
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

        if (sourceType === 'history') {
            document.getElementById('importPrimaryLabel').innerText = "Matrix CSV (optional)";
            document.getElementById('importSecondaryLabel').innerText = "All-Tables Hosts History CSV (optional)";
            tertiaryWrap.style.display = 'grid';
            rangeLabelWrap.style.display = 'none';
            infoBox.innerHTML = "&#9432; Restores potentially many clusters/ranges at once from previously exported history files (at least one of the three is required). The Hosts+VMs History pair carries full per-host detail and powers sizing exactly like a live analysis. The Matrix CSV only carries percentages (no absolute GB, no host/VM breakdown, no host count) &mdash; it repopulates the Range Comparison Matrix below for trend viewing, but Sizing &amp; Savings will show \"No hardware profiles collected\" for those specific ranges since real capacity/host-count data isn't recoverable from percentages alone. Import does not require a Target Cluster Scope selection above; cluster/range names come from the files themselves.";
        } else {
            var isRvtools = sourceType === 'rvtools';
            document.getElementById('importPrimaryLabel').innerText = isRvtools ? "vHost CSV (required)" : "Hosts CSV (required)";
            document.getElementById('importSecondaryLabel').innerText = isRvtools ? "vMemory or vInfo CSV (optional, needed for Active %)" : "VMs CSV (optional)";
            tertiaryWrap.style.display = 'none';
            rangeLabelWrap.style.display = 'flex';
            infoBox.innerHTML = "&#9432; Populates the checklist above, the tables below, and the Sizing &amp; Savings tab for the Target Cluster Scope selected above &mdash; without querying vCenter. Memory Tiering status cannot be determined from imported files and defaults to \"Unknown\".";
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
        var dramSum = 0, consumedSum = 0, activeSum = 0, cpuSum = 0;
        var anyTiered = false;

        for (var i = 0; i < hostRows.length; i++) {
            var r = hostRows[i];
            var physRam = parseNum(r.Physical_RAM) || 0;
            var consumed = parseNum(r.Consumed_GB) || 0;
            var active = parseNum(r.Active_GB) || 0;
            var cpuPct = parseNum(r.CPU_Pct) || 0;
            var activePct = parseNum(r.Active_Pct);
            if (isNaN(activePct)) activePct = physRam > 0 ? Math.round((active / physRam) * 1000) / 10 : 0;
            var tiering = r.Tiering || "Unknown";
            if (tiering === "Enabled") anyTiered = true;

            hosts.push({
                Cluster: r.Cluster || "", HostName: r.HostName || "", Tiering: tiering, TierRatioPct: 100,
                CPU_Pct: cpuPct, Physical_RAM: physRam, Consumed_GB: consumed, Active_GB: active, Active_Pct: activePct
            });

            dramSum += physRam; consumedSum += consumed; activeSum += active; cpuSum += cpuPct;
        }

        if (anyTiered) warnings.push("Tiering ratio % is not included in exported CSVs and was defaulted to 100% for hosts already showing 'Enabled'.");
        warnings.push("Exported CSVs only retain the peak Active Memory figure, not a separate average -- Active Memory (Avg) will show as N/A.");

        var vms = [];
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
                var provisioned = parseNum(v.Provisioned_GB) || 0;
                var vActive = parseNum(v.Active_GB) || 0;
                var vActivePct = parseNum(v.Active_Pct);
                if (isNaN(vActivePct)) vActivePct = provisioned > 0 ? Math.round((vActive / provisioned) * 1000) / 10 : 0;
                vms.push({
                    Host: v.Host || "", VMName: v.VMName || "", Provisioned_GB: provisioned, Active_GB: vActive,
                    Active_Pct: vActivePct, Pinned_Memory: v.Pinned_Memory || "N/A", Pages_1GB: v.Pages_1GB || "N/A", Pages_2MB: v.Pages_2MB || "N/A"
                });
            }
        }

        return {
            dram: Math.round(dramSum), consumed: Math.round(consumedSum), active: Math.round(activeSum),
            cpu: hostRows.length > 0 ? Math.round((cpuSum / hostRows.length) * 10) / 10 : 0,
            hosts: hosts, vms: vms, warnings: warnings
        };
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

            var provGB = Math.round(vProvMiB / 1024);
            var actGB = Math.round((vActiveMiB / 1024) * 100) / 100;
            vmTableOut.push({
                Host: vHostName, VMName: vName, Provisioned_GB: provGB, Active_GB: actGB,
                Active_Pct: provGB > 0 ? Math.round((actGB / provGB) * 1000) / 10 : 0,
                Pinned_Memory: "N/A", Pages_1GB: "N/A", Pages_2MB: "N/A"
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
            var dramGB = Math.round(memMiB / 1024);
            var cpuPct = parseNum(pickField(fh, RVTOOLS_HOST_ALIASES.cpuUsagePct)) || 0;
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
                consumedGB = Math.round((vmConsumedByHost[hName] / 1024) * 100) / 100;
            } else {
                consumedGB = 0; missingConsumedInfo = true;
            }

            var activeGB = haveVmActive ? Math.round(((vmActiveByHost[hName] || 0) / 1024) * 100) / 100 : 0;

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
                Active_GB: activeGB, Active_Pct: dramGB > 0 ? Math.round((activeGB / dramGB) * 1000) / 10 : 0
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
            dram: Math.round(dramSum), consumed: Math.round(consumedSum), active: Math.round(activeSum), activeAvg: Math.round(activeSum),
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
        consumedPct: ["Consumed Mem Avg Pct", "Consumed Memory Pct"]
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

            var cpuPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.cpuPct)) || 0;
            var activePeakPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.activePeakPct)) || 0;
            var activeAvgPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.activeAvgPct));
            var consumedPct = parseNum(pickField(fr, MATRIX_CSV_ALIASES.consumedPct)) || 0;
            if (isNaN(activeAvgPct)) missingActiveAvgCount++;

            var group = {
                clusterName: clusterName, rangeName: rangeName + " (Matrix Import)",
                dram: 100, consumed: consumedPct, active: activePeakPct, cpu: cpuPct, hosts: [], vms: []
            };
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

        function getGroup(clusterName, rangeName) {
            var key = clusterName + "::" + rangeName;
            if (!groupsByKey[key]) {
                groupsByKey[key] = { clusterName: clusterName, rangeName: rangeName, hosts: [], vms: [], dramSum: 0, consumedSum: 0, activeSum: 0, cpuSum: 0, hostCount: 0 };
                order.push(key);
            }
            return groupsByKey[key];
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
                var g = getGroup(ctx.clusterName, ctx.rangeName);

                var physRam = parseNum(r.Physical_RAM) || 0;
                var consumed = parseNum(r.Consumed_GB) || 0;
                var active = parseNum(r.Active_GB) || 0;
                var cpuPct = parseNum(r.CPU_Pct) || 0;
                var activePct = parseNum(r.Active_Pct);
                if (isNaN(activePct)) activePct = physRam > 0 ? Math.round((active / physRam) * 1000) / 10 : 0;

                g.hosts.push({
                    Cluster: ctx.clusterName, HostName: r.HostName || "", Tiering: r.Tiering || "Unknown", TierRatioPct: 100,
                    CPU_Pct: cpuPct, Physical_RAM: physRam, Consumed_GB: consumed, Active_GB: active, Active_Pct: activePct
                });
                g.dramSum += physRam; g.consumedSum += consumed; g.activeSum += active; g.cpuSum += cpuPct; g.hostCount++;
            }
        }

        if (vmsHistoryText && vmsHistoryText.trim().length > 0) {
            var vmRows = parseCsvText(vmsHistoryText);
            for (var j = 0; j < vmRows.length; j++) {
                var v = vmRows[j];
                var vctx = resolveClusterAndRange(v);
                if (!vctx.clusterName || !vctx.rangeName) continue;
                var vg = getGroup(vctx.clusterName, vctx.rangeName);

                var provisioned = parseNum(v.Provisioned_GB) || 0;
                var vActive = parseNum(v.Active_GB) || 0;
                var vActivePct = parseNum(v.Active_Pct);
                if (isNaN(vActivePct)) vActivePct = provisioned > 0 ? Math.round((vActive / provisioned) * 1000) / 10 : 0;

                vg.vms.push({
                    Host: v.Host || "", VMName: v.VMName || "", Provisioned_GB: provisioned, Active_GB: vActive,
                    Active_Pct: vActivePct, Pinned_Memory: v.Pinned_Memory || "N/A", Pages_1GB: v.Pages_1GB || "N/A", Pages_2MB: v.Pages_2MB || "N/A"
                });
            }
        }

        if (order.length === 0) warnings.push("No recognizable rows found in the supplied history file(s). Expected a 'ClusterContext' column formatted like 'ClusterName (Range Name)'.");
        else warnings.push("All-Tables History CSVs only retain the peak Active Memory figure, not a separate average -- Active Memory (Avg) will show as N/A for these ranges.");

        var groups = [];
        for (var k = 0; k < order.length; k++) {
            var grp = groupsByKey[order[k]];
            groups.push({
                clusterName: grp.clusterName, rangeName: grp.rangeName,
                dram: Math.round(grp.dramSum), consumed: Math.round(grp.consumedSum), active: Math.round(grp.activeSum),
                cpu: grp.hostCount > 0 ? Math.round((grp.cpuSum / grp.hostCount) * 10) / 10 : 0,
                hosts: grp.hosts, vms: grp.vms
            });
        }

        return { groups: groups, warnings: warnings };
    }

    function processImportFiles() {
        var sourceType = document.getElementById('importSourceType').value;
        if (sourceType === 'history') { processHistoryImport(); return; }

        var activeClusterValue = document.getElementById('clusterSelect').value;
        if (!activeClusterValue) { showToast("Please select a Target Cluster Scope before importing.", 'warn'); return; }

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
            if (!parsed.hosts || parsed.hosts.length === 0) throw new Error("No host rows could be parsed from the supplied file(s).");

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
        if (typeof group.activeAvg === 'number') { entry.activeAvg = group.activeAvg; }
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

            var clusterNamesSeen = {};
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
            $secondsSincePulse = ((Get-Date) - $lastHeartbeat).TotalSeconds

            # Dead-Man's Switch: If UI is connected but drops pulse for 5 minutes (300s), exit cleanly
            if ($uiConnected -and $secondsSincePulse -gt 300) {
                Write-DebugLog "[+] UI Heartbeat lost for 5 minutes. Safely shutting down engine."
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
        
        if ($req.HttpMethod -eq "GET" -and ($rawPath -eq "" -or $rawPath -eq "index.html")) {
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
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/shutdown") {
            # User clicked the explicit Exit Engine button
            Write-DebugLog "[+] Manual shutdown signal received. Terminating."
            Send-JsonResponse -Response $res -Object @{ status = "shutdown" }
            try { $listener.Stop(); $listener.Close() } catch {}
            [Environment]::Exit(0)
        }
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/connect") {
            Write-DebugLog "[->] Inbound route match hit on api/connect."
            try {
                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
                $payload = $body | ConvertFrom-Json

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
                        if ($sessionStillAlive) { continue }
                    }

                    try {
                        [void](Connect-VIServer -Server $srv -User $user -Password $pass -WarningAction SilentlyContinue -ErrorAction Stop)
                    } catch {
                        Write-DebugLog "[connect] WARNING: could not connect to vCenter '$srv' -- excluded from this session, other targets still attempted: $(Get-FullExceptionText $_)"
                        $failedTargets.Add([PSCustomObject]@{ server = $srv; error = (Add-KnownIssueHints (Get-FullExceptionText $_)) })
                    }
                }

                $clusterList = New-Object System.Collections.Generic.List[PSObject]
                foreach ($server in $global:DefaultVIServers) {
                    $serverClusters = Get-Cluster -Server $server -ErrorAction SilentlyContinue
                    foreach ($c in $serverClusters) {
                        $clusterList.Add([PSCustomObject]@{
                            Value = "$($server.Name)|$($c.Name)"
                            Text  = "$($c.Name) ($($server.Name))"
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
        elseif ($req.HttpMethod -eq "POST" -and $rawPath -eq "api/analyze") {
            try {
                $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
                try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
                $payload = $body | ConvertFrom-Json

                $clusterComposite = $payload.cluster
                $rangeSelection = $payload.range

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
                $clusterName = $parts[1]

                $viServerObj = $global:DefaultVIServers | Where-Object { $_.Name -eq $targetServer } | Select-Object -First 1
                if ($null -eq $viServerObj) {
                    throw "No active vCenter session found for server '$targetServer' -- it may have disconnected. Please reconnect on Step 1 and try again."
                }
                $targetCluster = Invoke-WithRetry -Description "Get-Cluster '$clusterName'" -Action {
                    Get-Cluster -Name $clusterName -Server $viServerObj | Select-Object -First 1
                }

                $hosts = Invoke-WithRetry -Description "Get-VMHost for cluster '$clusterName'" -Action {
                    Get-VMHost -Location $targetCluster -Server $viServerObj
                }

                # A single VM with malformed/incomplete config data can crash PowerCLI's bulk Get-VM
                # for the ENTIRE cluster -- a known PowerCLI failure mode ("Sequence contains no
                # elements" thrown from deep inside its own object/property-construction logic, not
                # from vCenter itself). Confirmed intermittent across clusters in the same vCenter,
                # which rules out a session-wide API version mismatch and points at specific VMs.
                # Rather than lose an entire cluster's data to one bad VM: list VM identities via the
                # lower-level Get-View (which bypasses that fragile wrapper), then resolve each VM
                # individually so exactly one bad VM can be isolated, named in the log, and skipped --
                # instead of taking every other VM in the cluster down with it. This is slower than one
                # bulk call for large clusters, but only when there's something to actually retry/skip.
                $failedVmNames = New-Object System.Collections.Generic.List[string]
                $vmViews = Invoke-WithRetry -Description "Get-View VM listing for cluster '$clusterName'" -Action {
                    Get-View -ViewType VirtualMachine -SearchRoot $targetCluster.ExtensionData.MoRef -Property Name, Runtime.PowerState -Server $viServerObj
                }
                $poweredOnViews = @($vmViews | Where-Object { $_.Runtime.PowerState -eq "poweredOn" })

                $allVMs = New-Object System.Collections.Generic.List[object]
                foreach ($vmView in $poweredOnViews) {
                    try {
                        $allVMs.Add((Get-VM -Id $vmView.MoRef.ToString() -Server $viServerObj -ErrorAction Stop))
                    } catch {
                        $failedVmNames.Add("$clusterName/$($vmView.Name) (unresolvable)")
                        Write-DebugLog "[analyze] WARNING: Get-VM could not resolve VM '$($vmView.Name)' in cluster '$clusterName' -- this VM likely has malformed/incomplete config data that PowerCLI can't process, and it was excluded entirely: $(Get-FullExceptionText $_)"
                    }
                }

                # Inventory counts up front so a "the tool isn't pulling all the data" report can be
                # checked against what vCenter actually returned for this cluster/range. Powered-off
                # VMs are intentionally excluded (this is a live-usage assessment), not a bug -- logged
                # explicitly so that distinction is visible rather than assumed.
                Write-DebugLog "[analyze] Cluster '$clusterName' on '$targetServer', range '$rangeSelection': found $($hosts.Count) host(s), $($allVMs.Count) powered-on VM(s) (powered-off VMs are intentionally excluded)."

                $hostStats = @(); $vmStats = @()
                if ($rangeSelection -notmatch "Real-Time") {
                    $daysBack = -7
                    if ($rangeSelection -match "Past 24 Hours") { $daysBack = -1 }
                    if ($rangeSelection -match "Past 30 Days")  { $daysBack = -30 }
                    if ($rangeSelection -match "Past 365 Days") { $daysBack = -365 }
                    $startTime = (Get-Date).AddDays($daysBack)

                    # Note: we always request the "average" rollup, never "maximum"/"minimum" -- those
                    # rollup types only exist if this vCenter's Statistics Level is 3+ for this interval
                    # (most environments run Level 1, which archives average only, and Get-Stat throws
                    # "metric counter ... doesn't exist" the moment you ask for a rollup that isn't
                    # collected). Instead, for Active Memory we take the MAX across the returned
                    # average-rollup samples below (see Measure-Object -Maximum) -- the worst single
                    # bucket in the window -- which works regardless of Statistics Level.
                    # KNOWN RISK, NOT YET HARDENED: these are bulk calls across every host/VM in the
                    # cluster, unlike the deliberately per-entity-isolated Get-VM listing above (which
                    # exists specifically because a single malformed VM can crash a bulk PowerCLI call
                    # for the entire cluster). If Get-Stat has the same failure mode for a single bad
                    # entity, one host/VM could take down this whole historical analysis instead of
                    # degrading gracefully like the rest of this handler. Not rewritten to per-entity
                    # calls here because that's a real performance tradeoff on large clusters and this
                    # failure mode hasn't actually been reproduced/confirmed -- flagging so it's the
                    # first thing to suspect if a cluster-wide "no data returned" report comes in that
                    # Invoke-WithRetry's 3 attempts don't resolve.
                    $hostStats = Invoke-WithRetry -Description "Get-Stat (hosts) for cluster '$clusterName'" -Action {
                        Get-Stat -Entity $hosts -Stat "cpu.usage.average","mem.active.average","mem.consumed.average" -Start $startTime -Server $viServerObj
                    }
                    $vmStats = Invoke-WithRetry -Description "Get-Stat (VMs) for cluster '$clusterName'" -Action {
                        Get-Stat -Entity $allVMs -Stat "mem.active.average" -Start $startTime -Server $viServerObj
                    }

                    # A host/VM silently defaults to 0 for a metric with no samples returned (see the
                    # $cpuVals/$actVals/$consVals null-guards below) -- that's indistinguishable from a
                    # genuinely idle entity unless it's logged here.
                    $hostNamesWithStats = @($hostStats | ForEach-Object { $_.Entity.Name } | Select-Object -Unique)
                    $hostNamesMissingStats = @($hosts.Name | Where-Object { $hostNamesWithStats -notcontains $_ })
                    if ($hostNamesMissingStats.Count -gt 0) {
                        Write-DebugLog "[analyze] WARNING: vCenter returned zero performance samples for range '$rangeSelection' on host(s): $($hostNamesMissingStats -join ', ') -- their CPU/Consumed/Active figures will show as 0."
                    }

                    $vmNamesWithStats = @($vmStats | ForEach-Object { $_.Entity.Name } | Select-Object -Unique)
                    $vmNamesMissingStats = @($allVMs.Name | Where-Object { $vmNamesWithStats -notcontains $_ })
                    if ($vmNamesMissingStats.Count -gt 0) {
                        Write-DebugLog "[analyze] WARNING: vCenter returned zero performance samples for range '$rangeSelection' on VM(s): $($vmNamesMissingStats -join ', ') -- their Active Memory figures will show as 0."
                    }
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
                $esxcliPhaseStartTime = Get-Date
                $esxcliCallCount = 0
                $esxcliMinSampleSize = 5          # don't judge the average off just a handful of hosts
                $esxcliAvgThresholdSeconds = 10   # generous margin above the ~1-3s/host normally seen
                $esxcliHardCeilingSeconds = 1200  # 20 min absolute backstop regardless of the average
                $esxcliBudgetExceeded = $false

                foreach ($h in $hosts) {
                  try {
                    $hostIsTiered = "Disabled"
                    $hostTierRatioPct = 0
                    # Tracks whether esxcli itself actually reported a Ratio/Percentage value below,
                    # as opposed to $hostTierRatioPct just sitting at its 0 default -- a host can be
                    # "Enabled" with a genuine 0 ratio (e.g. no NVMe currently attached/active), and
                    # without this flag that real 0 was indistinguishable from "esxcli didn't say" and
                    # got silently overwritten by the Mem.TierNVMePct/100 fallback below.
                    $hostTierRatioReported = $false
                    if ($esxcliBudgetExceeded) {
                        Write-DebugLog "[analyze] Skipping esxcli tiering-status query for host '$($h.Name)' -- per-host esxcli response time looked abnormal earlier this run; Tiering will show as 'Disabled' for this and any remaining host(s)."
                    } else {
                    try {
                        $esxcli = Get-EsxCli -VMHost $h -V2 -ErrorAction SilentlyContinue
                        if ($null -ne $esxcli.memtier) {
                            $status = $esxcli.memtier.status.get.Invoke()
                            if ($status.Status -match "Enabled") {
                                $hostIsTiered = "Enabled"
                                if ($null -ne $status.Ratio) { $hostTierRatioPct = [int]$status.Ratio; $hostTierRatioReported = $true }
                                elseif ($null -ne $status.Percentage) { $hostTierRatioPct = [int]$status.Percentage; $hostTierRatioReported = $true }
                            }
                        } elseif ($null -ne $esxcli.system.settings.kernel) {
                            if (($esxcli.system.settings.kernel.list.Invoke() | Where-Object { $_.Name -eq "MemoryTiering" }).Runtime -match "TRUE") {
                                $hostIsTiered = "Enabled"
                            }
                        }
                    } catch {
                        # $hostIsTiered may already be "Enabled" here if the failure happened AFTER
                        # that was set (e.g. casting $status.Ratio/$status.Percentage to [int] below
                        # it) -- log what will actually be shown, not an assumption that it's always
                        # "Disabled".
                        Write-DebugLog "[analyze] WARNING: esxcli tiering-status query failed for host '$($h.Name)' -- Tiering will show as '$hostIsTiered' (ratio/percentage detail may be incomplete if this failed partway through). Error: $(Get-FullExceptionText $_)"
                    }
                    $esxcliCallCount++

                    $esxcliElapsedSeconds = ((Get-Date) - $esxcliPhaseStartTime).TotalSeconds
                    $esxcliAvgSecondsPerHost = $esxcliElapsedSeconds / $esxcliCallCount
                    $esxcliAvgLooksAbnormal = ($esxcliCallCount -ge $esxcliMinSampleSize -and $esxcliAvgSecondsPerHost -gt $esxcliAvgThresholdSeconds)
                    $esxcliHitHardCeiling = ($esxcliElapsedSeconds -gt $esxcliHardCeilingSeconds)
                    if (-not $esxcliBudgetExceeded -and ($esxcliAvgLooksAbnormal -or $esxcliHitHardCeiling)) {
                        $esxcliBudgetExceeded = $true
                        Write-DebugLog "[analyze] WARNING: esxcli tiering-status queries are averaging $([math]::Round($esxcliAvgSecondsPerHost, 1))s/host across $esxcliCallCount host(s) so far (hard ceiling hit: $esxcliHitHardCeiling) -- this looks like genuinely abnormal esxcli behavior, not just a large cluster, so remaining host(s) this run will skip it and show 'Disabled' rather than wait indefinitely."
                    }
                    }

                    $cpuTotalMhz = [math]::Round(($h.ExtensionData.Hardware.CpuInfo.Hz * $h.ExtensionData.Hardware.CpuInfo.NumCpuCores) / 1000000, 0)

                    $hv = Get-View -Id $h.Id -Server $viServerObj -Property Hardware, Config.Option

                    if ($hostIsTiered -eq "Enabled" -and -not $hostTierRatioReported) {
                        $tierPctSetting = $hv.Config.Option | Where-Object { $_.Key -eq "Mem.TierNVMePct" } | Select-Object -First 1
                        if ($null -ne $tierPctSetting) {
                            $hostTierRatioPct = [int]$tierPctSetting.Value
                        } else {
                            $hostTierRatioPct = 100
                        }
                    }

                    $hostDramGB = [math]::Round($hv.Hardware.MemorySize / 1GB, 0)

                    if ($rangeSelection -notmatch "Real-Time") {
                        $myStats = $hostStats | Where-Object {$_.Entity.Name -eq $h.Name}
                        $cpuVals = $myStats | Where-Object {$_.MetricId -eq "cpu.usage.average"} | Select-Object -ExpandProperty Value
                        $actVals = $hostStats | Where-Object {$_.MetricId -eq "mem.active.average" -and $_.Entity.Name -eq $h.Name} | Select-Object -ExpandProperty Value
                        $consVals = $hostStats | Where-Object {$_.MetricId -eq "mem.consumed.average" -and $_.Entity.Name -eq $h.Name} | Select-Object -ExpandProperty Value

                        if ($null -eq $cpuVals) { $cpuVals = @(0) }; if ($null -eq $actVals) { $actVals = @(0) }; if ($null -eq $consVals) { $consVals = @(0) }
                        $hostCpuPct = ($cpuVals | Measure-Object -Average).Average
                        # Active Memory only: worst-case sizing wants the single highest average-rollup
                        # bucket in the window (e.g. the worst 30-min sample of the past week), not the
                        # window-wide average, so bursty clusters aren't under-sized. CPU and Consumed
                        # Memory stay plain time-weighted averages.
                        $hostActiveGB = [math]::Round((($actVals | Measure-Object -Maximum).Maximum) / 1048576, 2)
                        $hostConsumedMemGB = [math]::Round((($consVals | Measure-Object -Average).Average) / 1048576, 2)
                        $cpuUsageMhz = $cpuTotalMhz * ($hostCpuPct / 100)
                    } else {
                        $cpuUsageMhz = $h.ExtensionData.Summary.QuickStats.OverallCpuUsage
                        $hostCpuPct = if ($cpuTotalMhz -gt 0) { [math]::Round(($cpuUsageMhz / $cpuTotalMhz) * 100, 2) } else { 0 }
                        $hostConsumedMemGB = [math]::Round($h.ExtensionData.Summary.QuickStats.OverallMemoryUsage / 1024, 2)
                        $hostActiveGB = 0
                    }

                    $currentHostName = $h.Name
                    $hostVMs = $allVMs | Where-Object { $_.VMHost.Name -eq $currentHostName }
                    foreach ($vm in $hostVMs) {
                      try {
                        if ($rangeSelection -notmatch "Real-Time") {
                            $myVmStats = $vmStats | Where-Object {$_.Entity.Name -eq $vm.Name} | Select-Object -ExpandProperty Value
                            if ($null -eq $myVmStats) { $myVmStats = @(0) }
                            $activeGB = [math]::Round((($myVmStats | Measure-Object -Maximum).Maximum) / 1048576, 2)
                            # Reference-only companion figure: the plain time-weighted average over the same
                            # window, so the UI can show "peak vs. average" side by side for context.
                            $activeGB_Avg = [math]::Round((($myVmStats | Measure-Object -Average).Average) / 1048576, 2)
                        } else {
                            $activeGB = [math]::Round($vm.ExtensionData.Summary.QuickStats.GuestMemoryUsage / 1024, 2)
                            $activeGB_Avg = $activeGB
                            $hostActiveGB += $activeGB
                        }

                        # VMs with a hardware passthrough device (vGPU, PCI passthrough, etc.) are
                        # forced by ESXi into a full memory reservation ("Reserve all guest memory
                        # (All locked)") since a passthrough device DMAs directly to guest physical
                        # addresses -- that memory can never be ballooned, swapped, or tiered to NVMe,
                        # regardless of how "active" it measures. Flagged here as its own column
                        # rather than folded into Active_Pct, since Active_Pct is measuring correctly;
                        # this is a separate "can this VM's memory ever leave DRAM" question.
                        $pinnedMemory = if ($vm.ExtensionData.Config.MemoryReservationLockedToMax -eq $true) { "Yes" } else { "No" }

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

                        if ($hostIsTiered -eq "Enabled" -and $vmTieringDisabled -eq $false) {
                            $page1GB = "False"
                            $page2MB = if ($mmuLpOverride) { "True (Forced Overwrite)" } else { "False (4KB Tiering Split)" }
                        }

                        # Commit this VM's contribution only after everything above succeeded, so a
                        # mid-VM failure below can't leave the cluster-wide totals partially updated.
                        # Note: $totalActiveGB itself is NOT accumulated here in historical mode -- see
                        # the per-host commit below for why. $totalActiveGB_Avg has no host-level
                        # counterpart shown anywhere in the UI (it's a VM-only reference figure), so it's
                        # fine to keep building it from per-VM values regardless of mode.
                        $totalActiveGB_Avg += $activeGB_Avg
                        $vmResults.Add([PSCustomObject]@{
                            Host = $currentHostName; VMName = $vm.Name; Provisioned_GB = [math]::Round($vm.MemoryGB); Active_GB = $activeGB
                            Active_Pct = if($vm.MemoryGB -gt 0){[math]::Round(($activeGB/$vm.MemoryGB)*100,1)}else{0}; Pinned_Memory = $pinnedMemory
                            Pages_1GB = $page1GB; Pages_2MB = $page2MB
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

                    $hostResults.Add([PSCustomObject]@{
                        Cluster      = $clusterName
                        HostName     = $currentHostName; Tiering = $hostIsTiered; TierRatioPct = $hostTierRatioPct; CPU_Pct = [math]::Round($hostCpuPct, 1)
                        Physical_RAM = $hostDramGB; Consumed_GB = $hostConsumedMemGB; Active_GB = $hostActiveGB; Active_Pct = if($hostDramGB -gt 0){[math]::Round(($hostActiveGB/$hostDramGB)*100,1)}else{0}
                    })
                  } catch {
                    $failedHostNames.Add($h.Name)
                    Write-DebugLog "[analyze] ERROR: host '$($h.Name)' failed entirely and was excluded from cluster totals (still listed below as 'ERROR'): $(Get-FullExceptionText $_)"
                    $hostResults.Add([PSCustomObject]@{
                        Cluster = $clusterName; HostName = $h.Name; Tiering = "ERROR"; TierRatioPct = 0; CPU_Pct = 0
                        Physical_RAM = 0; Consumed_GB = 0; Active_GB = 0; Active_Pct = 0
                    })
                  }
                }

                if ($failedHostNames.Count -gt 0 -or $failedVmNames.Count -gt 0) {
                    Write-DebugLog "[analyze] Completed with $($failedHostNames.Count) failed host(s) [$($failedHostNames -join ', ')] and $($failedVmNames.Count) failed VM(s) [$($failedVmNames -join ', ')] excluded from results."
                } else {
                    Write-DebugLog "[analyze] Completed cleanly: $($hostResults.Count) host(s), $($vmResults.Count) VM(s) returned."
                }

                Send-JsonResponse -Response $res -Object @{
                    dram = $totalDramGB_Sum; consumed = [math]::Round($totalConsumedMemGB_Sum); active = [math]::Round($totalActiveGB)
                    activeAvg = [math]::Round($totalActiveGB_Avg)
                    cpu = if ($totalCpuMhz_Sum -gt 0) { [math]::Round(($totalCpuUsageMhz_Sum / $totalCpuMhz_Sum) * 100, 1) } else { 0 }
                    hosts = $hostResults; vms = @($vmResults | Sort-Object Active_Pct -Descending)
                    failedHosts = @($failedHostNames); failedVms = @($failedVmNames)
                }
            } catch {
                Send-JsonResponse -Response $res -Object @{ error = (Add-KnownIssueHints (Get-FullExceptionText $_)) }
            }
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