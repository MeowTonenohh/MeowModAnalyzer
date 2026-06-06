# TYMUSHACKER - Prank GUI
# Tylko do autoryzowanych testów!

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "TYMUSHACKER v3.7.1"
$form.WindowState = "Maximized"
$form.FormBorderStyle = "None"
$form.TopMost = $true
$form.BackColor = "Black"
$form.KeyPreview = $true
$form.KeyDown += {
    if ($_.Alt -and $_.KeyCode -eq "F4") {
        $_.SuppressKeyPress = $true
    }
    if ($_.KeyCode -eq "Escape") {
        $_.SuppressKeyPress = $true
    }
}

# Zapobiega Alt+F4 i Escape
$form.Add_KeyDown({
    param($s, $e)
    if ($e.Alt -and $e.KeyCode -eq "F4") { $e.SuppressKeyPress = $true }
    if ($e.KeyCode -eq "Escape") { $e.SuppressKeyPress = $true }
})

# ASCII Banner
$banner = @"
  ████████╗██╗   ██╗███╗   ███╗██╗   ██╗███████╗
  ╚══██╔══╝██║   ██║████╗ ████║██║   ██║██╔════╝
     ██║   ██║   ██║██╔████╔██║██║   ██║███████╗
     ██║   ██║   ██║██║╚██╔╝██║██║   ██║╚════██║
     ██║   ╚██████╔╝██║ ╚═╝ ██║╚██████╔╝███████║
     ╚═╝    ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚══════╝

  ██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗██████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
  ███████║███████║██║     █████╔╝ █████╗  ██████╔╝
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
  ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
"@

$labelBanner = New-Object System.Windows.Forms.Label
$labelBanner.Text = $banner
$labelBanner.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$labelBanner.ForeColor = "Lime"
$labelBanner.BackColor = "Black"
$labelBanner.TextAlign = "MiddleCenter"
$labelBanner.Size = New-Object System.Drawing.Size(1200, 200)
$labelBanner.Location = New-Object System.Drawing.Point(50, 20)
$labelBanner.AutoSize = $false
$form.Controls.Add($labelBanner)

# Główny label statusu
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "INICJALIZOWANIE POŁĄCZENIA..."
$statusLabel.Font = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = "Lime"
$statusLabel.BackColor = "Black"
$statusLabel.TextAlign = "MiddleCenter"
$statusLabel.Size = New-Object System.Drawing.Size(1000, 50)
$statusLabel.Location = New-Object System.Drawing.Point(150, 250)
$form.Controls.Add($statusLabel)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = New-Object System.Drawing.Size(800, 30)
$progressBar.Location = New-Object System.Drawing.Point(200, 320)
$progressBar.Style = "Continuous"
$progressBar.ForeColor = "Lime"
$form.Controls.Add($progressBar)

# ListBox na logi
$logBox = New-Object System.Windows.Forms.ListBox
$logBox.Size = New-Object System.Drawing.Size(1000, 300)
$logBox.Location = New-Object System.Drawing.Point(150, 380)
$logBox.BackColor = "Black"
$logBox.ForeColor = "Lime"
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.BorderStyle = "None"
$form.Controls.Add($logBox)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$step = 0

$messages = @(
    "ŁĄCZENIE Z SERWEREM ZDALNYM...",
    "POBIERANIE DANYCH UŻYTKOWNIKA...",
    "SKANOWANIE PORTÓW... 192.168.1.1:443 OTWARTY",
    "EKSTRAKCJA HASHY LOGOWANIA...",
    "DEKODOWANIE KRYPTOGRAFII AES-256...",
    "PRZEŁAMYWANIE ZAPORY SIECIOWEJ...",
    "ZDOBYWANIE DOSTĘPU ADMINISTRATORA...",
    "KOPIOWANIE PLIKÓW SYSTEMOWYCH...",
    "WSTRZYKIWANIE KODU ZŁOŚLIWEGO...",
    "PRZEJMOWANIE KONTROLI NAD SYSTEMEM...",
    "USUWANIE DANYCH LOGOWANIA...",
    "FORMATOWANIE DYSKU C:\ ... 12%",
    "FORMATOWANIE DYSKU C:\ ... 34%",
    "FORMATOWANIE DYSKU C:\ ... 56%",
    "FORMATOWANIE DYSKU C:\ ... 78%",
    "FORMATOWANIE DYSKU C:\ ... 100%",
    "DELETING SYSTEM32...",
    "USUWANIE REJESTRU SYSTEMOWEGO...",
    "KOMPROMITOWANE WSZYSTKICH KONT...",
    "PRZYGOTOWYWANIE SYSTEMU DO ZAMKNIĘCIA..."
)

$timer.Add_Tick({
    $step++
    if ($step -le $messages.Count) {
        $statusLabel.Text = $messages[$step-1]
        $progressBar.Value = [math]::Min(100, ($step / $messages.Count) * 100)
        if (-not $logBox.Items.Contains($messages[$step-1])) {
            $logBox.Items.Add("[>] $($messages[$step-1])")
            $logBox.TopIndex = $logBox.Items.Count - 1
        }
    }
    
    if ($step -eq $messages.Count) {
        $timer.Stop()
        $form.Controls.Clear()
        
        # EKRAN "NO ESCAPE"
        $form.BackColor = "DarkRed"
        
        $noEscapeBanner = New-Object System.Windows.Forms.Label
        $noEscapeBanner.Text = @"

  ███╗   ██╗ ██████╗     ███████╗███████╗ ██████╗ █████╗ ██████╗ ███████╗
  ████╗  ██║██╔═══██╗    ██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝
  ██╔██╗ ██║██║   ██║    █████╗  █████╗  ██║     ███████║██████╔╝█████╗
  ██║╚██╗██║██║   ██║    ██╔══╝  ██╔══╝  ██║     ██╔══██║██╔═══╝ ██╔══╝
  ██║ ╚████║╚██████╔╝    ███████╗███████╗╚██████╗██║  ██║██║     ███████╗
  ╚═╝  ╚═══╝ ╚═════╝     ╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝

           ╔══════════════════════════════════════════════════╗
           ║   TWOJ SYSTEM ZOSTAŁ ZAAKTOWANY                 ║
           ║   WSZYSTKIE TWOJE DANE ZOSTAŁY USUNIĘTE        ║
           ║   NIE MA MOŻLIWOŚCI ODZYSKANIA DANYCH           ║
           ║   WYŁĄCZ KOMPUTER I WŁĄCZ GO PONOWNIE          ║
           ║   ALT+F4 NIE DZIAŁA - TO TYLKO PRANK ;)        ║
           ╚══════════════════════════════════════════════════╝

"@
        $noEscapeBanner.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
        $noEscapeBanner.ForeColor = "Black"
        $noEscapeBanner.BackColor = "DarkRed"
        $noEscapeBanner.TextAlign = "MiddleCenter"
        $noEscapeBanner.Size = New-Object System.Drawing.Size(1200, 600)
        $noEscapeBanner.Location = New-Object System.Drawing.Point(50, 50)
        $noEscapeBanner.AutoSize = $false
        $form.Controls.Add($noEscapeBanner)
        
        # Migający napis na dole
        $blinkLabel = New-Object System.Windows.Forms.Label
        $blinkLabel.Text = "⚠️ SYSTEM ZNISZCZONY - WYŁĄCZ KOMPUTER ⚠️"
        $blinkLabel.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
        $blinkLabel.ForeColor = "Yellow"
        $blinkLabel.BackColor = "DarkRed"
        $blinkLabel.TextAlign = "MiddleCenter"
        $blinkLabel.Size = New-Object System.Drawing.Size(1200, 60)
        $blinkLabel.Location = New-Object System.Drawing.Point(50, 650)
        $form.Controls.Add($blinkLabel)
        
        # Timer migania
        $blinkTimer = New-Object System.Windows.Forms.Timer
        $blinkTimer.Interval = 500
        $blinkTimer.Add_Tick({
            if ($blinkLabel.ForeColor -eq "Yellow") {
                $blinkLabel.ForeColor = "DarkRed"
                $blinkLabel.BackColor = "Black"
            } else {
                $blinkLabel.ForeColor = "Yellow"
                $blinkLabel.BackColor = "DarkRed"
            }
        })
        $blinkTimer.Start()
    }
})

$form.Add_Shown({
    $timer.Start()
})

$form.Add_FormClosing({
    param($s, $e)
    $e.Cancel = $true
})

[System.Windows.Forms.Application]::Run($form)
