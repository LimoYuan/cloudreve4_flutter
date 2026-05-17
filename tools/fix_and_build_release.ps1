param(
    [string]$ProjectRoot = "",
    [string]$ProxyHost = "127.0.0.1",
    [int]$ProxyPort = 7897,
    [switch]$NoProxy
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

Write-Host "== 梦灵网盘 Release 构建修复 ==" -ForegroundColor Cyan
Write-Host "ProjectRoot: $ProjectRoot"

# 1. 删除旧包名下重复 MainActivity，修复 Redeclaration。
$oldMainActivity = Join-Path $ProjectRoot "android\app\src\main\kotlin\com\example\cloudreve4_flutter\MainActivity.kt"
if (Test-Path $oldMainActivity) {
    Remove-Item $oldMainActivity -Force
    Write-Host "Removed duplicate MainActivity: $oldMainActivity" -ForegroundColor Yellow
}
$oldExampleDir = Join-Path $ProjectRoot "android\app\src\main\kotlin\com\example"
if (Test-Path $oldExampleDir) {
    $hasFiles = Get-ChildItem $oldExampleDir -Recurse -File -ErrorAction SilentlyContinue
    if (-not $hasFiles) {
        Remove-Item $oldExampleDir -Recurse -Force
        Write-Host "Removed empty old package folder: $oldExampleDir" -ForegroundColor Yellow
    }
}

# 2. 配置 Gradle / 当前进程代理，用于 media_kit 从 GitHub 下载 JAR。
if (-not $NoProxy) {
    $proxy = "http://${ProxyHost}:${ProxyPort}"
    $env:HTTP_PROXY = $proxy
    $env:HTTPS_PROXY = $proxy
    $env:http_proxy = $proxy
    $env:https_proxy = $proxy

    $gradleDir = Join-Path $env:USERPROFILE ".gradle"
    $gradleProps = Join-Path $gradleDir "gradle.properties"
    New-Item -ItemType Directory -Force $gradleDir | Out-Null

    $existing = ""
    if (Test-Path $gradleProps) {
        $existing = Get-Content $gradleProps -Raw
        $existing = ($existing -split "`r?`n" | Where-Object {
            $_ -notmatch "^systemProp\.http\.proxyHost=" -and
            $_ -notmatch "^systemProp\.http\.proxyPort=" -and
            $_ -notmatch "^systemProp\.https\.proxyHost=" -and
            $_ -notmatch "^systemProp\.https\.proxyPort="
        }) -join "`r`n"
    }

    @"
$existing
systemProp.http.proxyHost=$ProxyHost
systemProp.http.proxyPort=$ProxyPort
systemProp.https.proxyHost=$ProxyHost
systemProp.https.proxyPort=$ProxyPort
"@ | Set-Content $gradleProps -Encoding UTF8

    Write-Host "Proxy set for this shell and Gradle: $proxy" -ForegroundColor Green
} else {
    Write-Host "Proxy disabled by -NoProxy" -ForegroundColor Yellow
}

# 3. 先清理并获取依赖。
flutter clean
flutter pub get

# 4. 预下载 media_kit_libs_android_video 的 GitHub JAR，避免 Gradle evaluate 阶段超时。
$pubRoot = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted"
$pluginBuildGradle = Get-ChildItem $pubRoot -Recurse -Filter "build.gradle" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "media_kit_libs_android_video-[^\\]+\\android\\build\.gradle$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if ($null -eq $pluginBuildGradle) {
    Write-Host "media_kit_libs_android_video build.gradle not found. Running build directly." -ForegroundColor Yellow
} else {
    Write-Host "Found media_kit plugin: $($pluginBuildGradle.FullName)" -ForegroundColor Green
    $content = Get-Content $pluginBuildGradle.FullName -Raw
    $urls = [regex]::Matches(
        $content,
        "https://github\.com/media-kit/libmpv-android-video-build/releases/download/[^`"`'\s]+/default-[^`"`'\s]+\.jar"
    ) | ForEach-Object { $_.Value } | Select-Object -Unique

    if (-not $urls -or $urls.Count -eq 0) {
        Write-Host "No media_kit JAR URLs parsed; Gradle will try downloading itself." -ForegroundColor Yellow
    } else {
        $pluginAndroidDir = Split-Path -Parent $pluginBuildGradle.FullName
        foreach ($url in $urls) {
            $fileName = Split-Path $url -Leaf
            $tag = ([regex]::Match($url, "/releases/download/([^/]+)/")).Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($tag)) {
                throw "Cannot parse media_kit release tag from URL: $url"
            }

            $targetDirs = @(
                (Join-Path $pluginAndroidDir "build\$tag"),
                (Join-Path $ProjectRoot "build\media_kit_libs_android_video\$tag")
            ) | Select-Object -Unique

            $alreadyOk = $false
            foreach ($dir in $targetDirs) {
                $target = Join-Path $dir $fileName
                if ((Test-Path $target) -and ((Get-Item $target).Length -gt 1048576)) {
                    $alreadyOk = $true
                }
            }

            if (-not $alreadyOk) {
                $tmp = Join-Path $env:TEMP ("media_kit_" + [IO.Path]::GetFileName($fileName))
                Write-Host "Downloading $fileName from GitHub..." -ForegroundColor Cyan
                if ($NoProxy) {
                    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 300
                } else {
                    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 300 -Proxy "http://${ProxyHost}:${ProxyPort}"
                }

                if ((Get-Item $tmp).Length -le 1048576) {
                    throw "Downloaded file is too small, likely failed: $tmp"
                }

                foreach ($dir in $targetDirs) {
                    New-Item -ItemType Directory -Force $dir | Out-Null
                    Copy-Item $tmp (Join-Path $dir $fileName) -Force
                }
            }

            Write-Host "Prepared $fileName for media_kit ($tag)" -ForegroundColor Green
        }
    }
}

# 5. 构建小体积 ABI 分包。
flutter build apk --release --split-per-abi

Write-Host ""
Write-Host "Build finished. APK files:" -ForegroundColor Green
Get-ChildItem (Join-Path $ProjectRoot "build\app\outputs\flutter-apk") -Filter "*.apk" |
    Select-Object Name, @{Name="SizeMB"; Expression={"{0:N2}" -f ($_.Length / 1MB)}} |
    Format-Table -AutoSize

Write-Host "Install the arm64-v8a APK on your Mi 10S." -ForegroundColor Cyan
