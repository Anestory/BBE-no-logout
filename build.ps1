# Package the extension into a zip in the parent directory.
# Reads the version from manifest.json and uses it in the zip filename.
# Output: <parent-of-this-folder>\bbe-no-logout-<version>.zip
#
# Uses .NET ZipArchive directly so entry paths use forward slashes
# (Compress-Archive uses backslashes on Windows, which AMO/web-ext reject).

$ErrorActionPreference = 'Stop'

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $ScriptDir 'manifest.json'

# Read version from manifest.json
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$version  = $manifest.version

# Output path: one level above the project folder
$ParentDir = Split-Path -Parent $ScriptDir
$BaseName  = 'bbe-no-logout'
$ZipPath   = Join-Path $ParentDir "$BaseName-$version.zip"

# Source path -> entry name (forward slashes for ZIP / cross-platform compatibility)
$Items = @(
    @{ Path = 'manifest.json';      Entry = 'manifest.json'      },
    @{ Path = 'background.js';      Entry = 'background.js'      },
    @{ Path = 'icons\icon-48.png';  Entry = 'icons/icon-48.png'  },
    @{ Path = 'icons\icon-96.png';  Entry = 'icons/icon-96.png'  },
    @{ Path = 'icons\icon-128.png'; Entry = 'icons/icon-128.png' }
)

# Validate everything exists before creating the archive
foreach ($item in $Items) {
    $full = Join-Path $ScriptDir $item.Path
    if (-not (Test-Path $full)) {
        throw "Missing required file: $full"
    }
}

# Overwrite any existing zip
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open(
    $ZipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    foreach ($item in $Items) {
        $sourcePath = Join-Path $ScriptDir $item.Path
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $sourcePath,
            $item.Entry,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

Write-Host "Created $ZipPath" -ForegroundColor Green
