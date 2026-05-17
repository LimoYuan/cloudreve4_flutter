param(
    [string]$ProjectRoot = "",
    [string]$ProxyHost = "127.0.0.1",
    [int]$ProxyPort = 7897,
    [switch]$NoProxy,
    [switch]$RunDebug,
    [string]$DeviceId = "13257dbf"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

Write-Host "== media_kit_libs_android_video download timeout fix ==" -ForegroundColor Cyan
Write-Host "ProjectRoot: $ProjectRoot"

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

    Write-Host "Proxy set: $proxy" -ForegroundColor Green

    try {
        curl.exe -x $proxy -I --connect-timeout 20 https://github.com | Out-Null
        Write-Host "GitHub proxy test OK." -ForegroundColor Green
    } catch {
        Write-Host "GitHub proxy test failed. Check proxy port or enable proxy mode." -ForegroundColor Yellow
        Write-Host $_
    }
} else {
    Write-Host "Proxy disabled by -NoProxy" -ForegroundColor Yellow
}

Write-Host "Running flutter pub get..." -ForegroundColor Cyan
flutter pub get

$pubRoot = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted"
if (-not (Test-Path $pubRoot)) {
    throw "Pub hosted cache not found: $pubRoot"
}

$pluginBuildGradles = Get-ChildItem $pubRoot -Recurse -Filter "build.gradle" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "media_kit_libs_android_video-[^\\]+\\android\\build\.gradle$" } |
    Sort-Object FullName -Descending

if ($pluginBuildGradles.Count -eq 0) {
    throw "media_kit_libs_android_video android build.gradle not found."
}

foreach ($pluginBuildGradle in $pluginBuildGradles) {
    Write-Host "Found plugin: $($pluginBuildGradle.FullName)" -ForegroundColor Green
    $content = Get-Content $pluginBuildGradle.FullName -Raw

    $urls = [regex]::Matches(
        $content,
        "https://github\.com/media-kit/libmpv-android-video-build/releases/download/[^`"`'\s]+/default-[^`"`'\s]+\.jar"
    ) | ForEach-Object { $_.Value } | Select-Object -Unique

    if (-not $urls -or $urls.Count -eq 0) {
        $tagMatch = [regex]::Match($content, "(v[0-9]+\.[0-9]+\.[0-9]+)")
        $tag = if ($tagMatch.Success) { $tagMatch.Groups[1].Value } else { "v1.1.7" }
        $abis = @("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        $urls = $abis | ForEach-Object {
            "https://github.com/media-kit/libmpv-android-video-build/releases/download/$tag/default-$_.jar"
        }
        Write-Host "Could not parse direct URLs. Fallback tag: $tag" -ForegroundColor Yellow
    }

    $pluginAndroidDir = Split-Path -Parent $pluginBuildGradle.FullName

    foreach ($url in $urls) {
        $fileName = Split-Path $url -Leaf
        $tag = ([regex]::Match($url, "/releases/download/([^/]+)/")).Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($tag)) {
            throw "Cannot parse release tag from URL: $url"
        }

        $targetDirs = @(
            (Join-Path $pluginAndroidDir "build\$tag"),
            (Join-Path $ProjectRoot "build\media_kit_libs_android_video\$tag")
        ) | Select-Object -Unique

        $existsOk = $false
        foreach ($dir in $targetDirs) {
            $target = Join-Path $dir $fileName
            if ((Test-Path $target) -and ((Get-Item $target).Length -gt 1048576)) {
                $existsOk = $true
            }
        }

        if (-not $existsOk) {
            $tmp = Join-Path $env:TEMP ("media_kit_" + $tag + "_" + $fileName)
            if (Test-Path $tmp) { Remove-Item $tmp -Force }

            Write-Host "Downloading $fileName ($tag)..." -ForegroundColor Cyan
            if ($NoProxy) {
                curl.exe -L --retry 10 --connect-timeout 30 -o $tmp $url
            } else {
                curl.exe -x "http://${ProxyHost}:${ProxyPort}" -L --retry 10 --connect-timeout 30 -o $tmp $url
            }

            if (-not (Test-Path $tmp) -or ((Get-Item $tmp).Length -le 1048576)) {
                throw "Downloaded file is missing or too small: $url -> $tmp"
            }

            foreach ($dir in $targetDirs) {
                New-Item -ItemType Directory -Force $dir | Out-Null
                Copy-Item $tmp (Join-Path $dir $fileName) -Force
                Write-Host "Copied to: $(Join-Path $dir $fileName)" -ForegroundColor Green
            }
        } else {
            Write-Host "Already exists: $fileName ($tag)" -ForegroundColor Green
        }
    }
}

Write-Host "media_kit JARs are prepared." -ForegroundColor Green

if ($RunDebug) {
    Write-Host "Running flutter run -d $DeviceId ..." -ForegroundColor Cyan
    flutter run -d $DeviceId
} else {
    Write-Host "Now run:" -ForegroundColor Cyan
    Write-Host "  flutter run -d $DeviceId"
    Write-Host "or"
    Write-Host "  flutter build apk --release --split-per-abi"
}
