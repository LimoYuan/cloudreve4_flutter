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

Write-Host "== Native Android downloads fix: media_kit + pdfium ==" -ForegroundColor Cyan
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

    Write-Host "Proxy set for shell and Gradle: $proxy" -ForegroundColor Green

    try {
        curl.exe -x $proxy -I --connect-timeout 20 https://github.com | Out-Null
        Write-Host "GitHub proxy test OK." -ForegroundColor Green
    } catch {
        Write-Host "GitHub proxy test failed. Check proxy port or proxy mode." -ForegroundColor Yellow
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

# media_kit
Write-Host ""
Write-Host "Preparing media_kit_libs_android_video native JARs..." -ForegroundColor Cyan

$mediaBuildGradles = Get-ChildItem $pubRoot -Recurse -Filter "build.gradle" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "media_kit_libs_android_video-[^\\]+\\android\\build\.gradle$" } |
    Sort-Object FullName -Descending

if ($mediaBuildGradles.Count -eq 0) {
    Write-Host "media_kit_libs_android_video not found; skipped." -ForegroundColor Yellow
} else {
    foreach ($pluginBuildGradle in $mediaBuildGradles) {
        Write-Host "Found media_kit plugin: $($pluginBuildGradle.FullName)" -ForegroundColor Green
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
            Write-Host "Could not parse direct media_kit URLs. Fallback tag: $tag" -ForegroundColor Yellow
        }

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

                Write-Host "Downloading media_kit $fileName ($tag)..." -ForegroundColor Cyan
                if ($NoProxy) {
                    curl.exe -L --retry 10 --connect-timeout 30 -o $tmp $url
                } else {
                    curl.exe -x "http://${ProxyHost}:${ProxyPort}" -L --retry 10 --connect-timeout 30 -o $tmp $url
                }

                if (-not (Test-Path $tmp) -or ((Get-Item $tmp).Length -le 1048576)) {
                    throw "Downloaded media_kit file is missing or too small: $url -> $tmp"
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
}

# pdfium_dart patch
Write-Host ""
Write-Host "Patching pdfium_dart hook to use curl/proxy cache..." -ForegroundColor Cyan

$pdfiumHooks = Get-ChildItem $pubRoot -Recurse -Filter "build.dart" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "pdfium_dart-[^\\]+\\hook\\build\.dart$" } |
    Sort-Object FullName -Descending

if ($pdfiumHooks.Count -eq 0) {
    Write-Host "pdfium_dart hook/build.dart not found; skipped." -ForegroundColor Yellow
} else {
    foreach ($hook in $pdfiumHooks) {
        Write-Host "Found pdfium_dart hook: $($hook.FullName)" -ForegroundColor Green

        $original = Get-Content $hook.FullName -Raw
        $backup = "$($hook.FullName).original"
        if (-not (Test-Path $backup)) {
            Copy-Item $hook.FullName $backup -Force
        }

        if ($original -match "PDFIUM_DART_CACHE_DIR") {
            Write-Host "pdfium_dart hook already patched." -ForegroundColor Green
            continue
        }

        $patched = @'
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _pdfiumRelease = 'chromium%2F7811';
const _assetName = 'libpdfium';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (input.config.code.targetOS == OS.iOS) return;

    final target = _PdfiumTarget.fromCodeConfig(input.config.code);
    final outputSubdir = _pdfiumRelease.replaceAll('%2F', '_');
    final outputFile = input.outputDirectoryShared.resolve(
      '$outputSubdir/${target.libraryFileName}',
    );

    await _downloadPdfium(
      outputFile: outputFile,
      target: target,
      pdfiumRelease: _pdfiumRelease,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: outputFile,
      ),
    );
  });
}

Future<void> _downloadPdfium({
  required Uri outputFile,
  required _PdfiumTarget target,
  required String pdfiumRelease,
}) async {
  final output = File.fromUri(outputFile);
  if (await output.exists()) return;

  final archiveUri = Uri.parse(
    'https://github.com/bblanchon/pdfium-binaries/releases/download/'
    '$pdfiumRelease/pdfium-${target.archivePlatform}-${target.archiveArch}.tgz',
  );

  final cacheDir = Directory(
    Platform.environment['PDFIUM_DART_CACHE_DIR'] ??
        '${Directory.systemTemp.path}${Platform.pathSeparator}pdfium_dart_cache',
  );
  await cacheDir.create(recursive: true);

  final archiveFile = File(
    '${cacheDir.path}${Platform.pathSeparator}${archiveUri.pathSegments.last}',
  );

  if (!await archiveFile.exists() || await archiveFile.length() < 1024 * 1024) {
    final proxy = Platform.environment['HTTPS_PROXY'] ??
        Platform.environment['https_proxy'] ??
        Platform.environment['HTTP_PROXY'] ??
        Platform.environment['http_proxy'] ??
        '';

    final args = <String>[
      if (proxy.isNotEmpty) ...['-x', proxy],
      '-L',
      '--retry',
      '10',
      '--connect-timeout',
      '30',
      '-o',
      archiveFile.path,
      archiveUri.toString(),
    ];

    final result = await Process.run('curl.exe', args);
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to download PDFium with curl: $archiveUri\n'
        'stdout: ${result.stdout}\n'
        'stderr: ${result.stderr}',
      );
    }

    if (!await archiveFile.exists() || await archiveFile.length() < 1024 * 1024) {
      throw Exception('Downloaded PDFium archive is missing or too small: ${archiveFile.path}');
    }
  }

  final archive = TarDecoder().decodeBytes(
    GZipDecoder().decodeBytes(await archiveFile.readAsBytes()),
  );

  final member = archive.findFile(target.archiveLibraryPath);
  if (member == null) {
    throw Exception(
      'PDFium archive $archiveUri does not contain ${target.archiveLibraryPath}.',
    );
  }

  await output.parent.create(recursive: true);
  await output.writeAsBytes(member.content as List<int>);
}

final class _PdfiumTarget {
  const _PdfiumTarget({
    required this.archivePlatform,
    required this.archiveArch,
    required this.archiveLibraryPath,
    required this.libraryFileName,
  });

  final String archivePlatform;
  final String archiveArch;
  final String archiveLibraryPath;
  final String libraryFileName;

  static _PdfiumTarget fromCodeConfig(CodeConfig config) {
    final arch = switch (config.targetArchitecture) {
      Architecture.ia32 => 'x86',
      Architecture.x64 => 'x64',
      Architecture.arm => 'arm',
      Architecture.arm64 => 'arm64',
      _ => throw UnsupportedError(
          'Unsupported PDFium architecture: ${config.targetArchitecture}'),
    };

    return switch (config.targetOS) {
      OS.android => _PdfiumTarget(
          archivePlatform: 'android',
          archiveArch: arch,
          archiveLibraryPath: 'lib/libpdfium.so',
          libraryFileName: 'libpdfium.so',
        ),
      OS.windows => _PdfiumTarget(
          archivePlatform: 'win',
          archiveArch: arch,
          archiveLibraryPath: 'bin/pdfium.dll',
          libraryFileName: 'pdfium.dll',
        ),
      OS.linux => _PdfiumTarget(
          archivePlatform: 'linux',
          archiveArch: arch,
          archiveLibraryPath: 'lib/libpdfium.so',
          libraryFileName: 'libpdfium.so',
        ),
      OS.macOS => _PdfiumTarget(
          archivePlatform: 'mac',
          archiveArch: arch,
          archiveLibraryPath: 'lib/libpdfium.dylib',
          libraryFileName: 'libpdfium.dylib',
        ),
      _ => throw UnsupportedError('Unsupported PDFium platform: ${config.targetOS}'),
    };
  }
}
'@

        Set-Content $hook.FullName $patched -Encoding UTF8
        Write-Host "Patched pdfium_dart hook/build.dart" -ForegroundColor Green
    }
}

$pdfiumHookRunnerDir = Join-Path $ProjectRoot ".dart_tool\hooks_runner\pdfium_dart"
if (Test-Path $pdfiumHookRunnerDir) {
    Remove-Item $pdfiumHookRunnerDir -Recurse -Force
    Write-Host "Removed old pdfium hook runner cache." -ForegroundColor Yellow
}

$env:PDFIUM_DART_CACHE_DIR = Join-Path $ProjectRoot ".native_download_cache\pdfium_dart"
New-Item -ItemType Directory -Force $env:PDFIUM_DART_CACHE_DIR | Out-Null
Write-Host "PDFIUM_DART_CACHE_DIR=$env:PDFIUM_DART_CACHE_DIR" -ForegroundColor Green

Write-Host ""
Write-Host "Native downloads are fixed/prepared." -ForegroundColor Green

if ($RunDebug) {
    Write-Host "Running flutter run -d $DeviceId ..." -ForegroundColor Cyan
    flutter run -d $DeviceId
} else {
    Write-Host "Now run:" -ForegroundColor Cyan
    Write-Host "  flutter run -d $DeviceId"
    Write-Host "or"
    Write-Host "  flutter build apk --release --split-per-abi"
}
