<#
.SYNOPSIS
    Extracts Windows driver installation executables by leveraging 7-Zip.

.DESCRIPTION
    eXetract.ps1 scans the provided source directory for executable files (*.exe).
    Every discovered file is treated as an archive and unpacked into a dedicated
    subfolder beneath the chosen target directory. The script uses the console
    variant of 7-Zip (7z/7zz) to avoid triggering installer GUIs and to ensure a
    fully unattended workflow for reverse-engineering or repackaging driver
    payloads. The script auto-detects 7-Zip in common installation locations, can
    respect the SEVEN_ZIP_PATH environment variable, and falls back to executables
    that are available via the PATH environment variable. Cross-platform usage on
    Windows, Linux, and macOS is supported as long as a compatible 7-Zip binary is
    installed.

.PARAMETER SourceFolder
    Path to the directory containing the driver installation executables that
    should be extracted. The folder must exist.

.PARAMETER TargetFolder
    Path to the directory that will receive the extracted content. The folder is
    created automatically when it does not already exist.

.EXAMPLE
    PS> .\eXetract.ps1 -SourceFolder "C:\\Temp\\Drivers" -TargetFolder "C:\\Temp\\Extracted"
    Extracts every .exe file inside the Drivers directory into a dedicated folder
    inside C:\\Temp\\Extracted by using 7-Zip.

.EXAMPLE
    PS> .\eXetract.ps1 -SourceFolder ./Installers -TargetFolder ./Packages -Verbose
    Executes the extraction in verbose mode while honoring -WhatIf/-Confirm switches.

.NOTES
    Author : ~ mimic ~ (release build prepared by OpenAI Assistant)
    Requires: 7-Zip (https://www.7-zip.org/)
    Hint   : Use the environment variable SEVEN_ZIP_PATH to override autodetection.
    Version: 1.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                throw "The source folder '$_' was not found."
            }

            return $true
        })]
    [string]$SourceFolder,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-SevenZipPath {
    <#
        .SYNOPSIS
            Determines the absolute path to a usable 7-Zip console executable.

        .OUTPUTS
            System.String. The fully qualified path to the executable.

        .NOTES
            Preference order:
              1. Explicit SEVEN_ZIP_PATH environment variable
              2. Well known installation paths (Program Files variations)
              3. 7z/7zz executables found through Get-Command (PATH environment variable)
    #>
    [CmdletBinding()]
    param()

    $candidatePaths = @()

    if ($env:SEVEN_ZIP_PATH) {
        $candidatePaths += $env:SEVEN_ZIP_PATH
    }

    $programFilesW6432 = [Environment]::GetEnvironmentVariable('ProgramW6432')
    if ($programFilesW6432) {
        $candidatePaths += Join-Path -Path $programFilesW6432 -ChildPath '7-Zip\\7z.exe'
    }

    $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
    if ($programFiles) {
        $candidatePaths += Join-Path -Path $programFiles -ChildPath '7-Zip\\7z.exe'
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $candidatePaths += Join-Path -Path $programFilesX86 -ChildPath '7-Zip\\7z.exe'
    }

    $candidatePaths += @(
        Join-Path -Path $PSScriptRoot -ChildPath '7z.exe'
        Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Bin') -ChildPath '7z.exe'
        Join-Path -Path $PSScriptRoot -ChildPath '7zz'
        Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Bin') -ChildPath '7zz'
        Join-Path -Path $PSScriptRoot -ChildPath '7zz.exe'
        Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Bin') -ChildPath '7zz.exe'
    )

    foreach ($path in $candidatePaths | Where-Object { $_ }) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return (Resolve-Path -LiteralPath $path).ProviderPath
        }
    }

    $command = Get-Command -Name @('7z.exe', '7z', '7zz', '7za') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        return $command.Source
    }

    throw "Unable to locate a 7-Zip console executable. Install 7-Zip or point SEVEN_ZIP_PATH to the binary."
}

function Ensure-Directory {
    <#
        .SYNOPSIS
            Creates a directory when it does not exist yet.

        .PARAMETER Path
            The directory path that should exist after the function returns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Verbose "Creating directory '$Path'."
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Ensure-Directory -Path $TargetFolder

$SourceFolder = (Resolve-Path -LiteralPath $SourceFolder).ProviderPath
$TargetFolder = (Resolve-Path -LiteralPath $TargetFolder).ProviderPath

try {
    $sevenZipPath = Resolve-SevenZipPath
}
catch {
    throw $_
}

Write-Verbose "Using 7-Zip located at '$sevenZipPath'."

$driverFiles = @(Get-ChildItem -Path $SourceFolder -Filter '*.exe' -File -ErrorAction Stop | Sort-Object -Property Name)
if (-not $driverFiles) {
    Write-Warning "No .exe files found in source folder '$SourceFolder'."
    return
}

Write-Host "Starting batch extraction for $($driverFiles.Count) file(s)." -ForegroundColor Green

foreach ($file in $driverFiles) {
    Write-Host "---"
    Write-Host "Processing: $($file.Name)"

    $destination = Join-Path -Path $TargetFolder -ChildPath $file.BaseName
    Ensure-Directory -Path $destination

    if (-not $PSCmdlet.ShouldProcess($file.FullName, "Extract to '$destination'")) {
        continue
    }

    $arguments = @(
        'x'
        $file.FullName
        "-o$destination"
        '-y'
    )

    Write-Verbose "Launching 7-Zip for '$($file.FullName)' -> '$destination'."

    try {
        $process = Start-Process -FilePath $sevenZipPath -ArgumentList $arguments -Wait -NoNewWindow -PassThru -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to launch 7-Zip: $_"
        continue
    }

    if ($process.ExitCode -eq 0) {
        Write-Host "Successfully extracted -> $destination" -ForegroundColor Cyan
    }
    else {
        Write-Error "Extraction failed for $($file.Name) (exit code: $($process.ExitCode))."
    }
}

Write-Host "---"
Write-Host "Batch extraction completed." -ForegroundColor Green
