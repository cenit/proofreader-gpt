#!/usr/bin/env pwsh

<#

.SYNOPSIS
        process-documents
        Created By: Stefano Sinigardi
        Created Date: August 7, 2024
        Last Modified Date: August 7, 2024

.DESCRIPTION
Process a PDF folder with ai_converter.py

.PARAMETER DisableInteractive
Disable script interactivity (useful for CI runs)

.PARAMETER DoNotUpdateTOOL
Do not update the tool before running the build (valid only if tool is git-enabled)

.PARAMETER SkipImages
Do not process images in the PDF files looking for text

.PARAMETER PDFFolder
Path of the folder containing the PDF files to process

.PARAMETER OutputFolder
Path of the folder where the output files will be saved

.EXAMPLE
.\process-documents -DisableInteractive

#>

<#
Copyright (c) Stefano Sinigardi

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

param (
  [switch]$DisableInteractive = $false,
  [switch]$DoNotUpdateTOOL = $false,
  [switch]$SkipImages = $false,
  [string]$PDFFolder,
  [string]$OutputFolder
)

$global:DisableInteractive = $DisableInteractive

$process_documents_ps1_version = "1.0.0"
$script_name = $MyInvocation.MyCommand.Name
if (Test-Path $PSScriptRoot/utils.psm1) {
  Import-Module -Name $PSScriptRoot/utils.psm1 -Force
  $utils_psm1_avail = $true
  $IsInGitSubmodule = $true
}
elseif (Test-Path $PSScriptRoot/cmake/utils.psm1) {
  Import-Module -Name $PSScriptRoot/cmake/utils.psm1 -Force
  $utils_psm1_avail = $true
  $IsInGitSubmodule = $false
}
elseif (Test-Path $PSScriptRoot/ci/utils.psm1) {
  Import-Module -Name $PSScriptRoot/ci/utils.psm1 -Force
  $utils_psm1_avail = $true
  $IsInGitSubmodule = $false
}
elseif (Test-Path $PSScriptRoot/ccm/utils.psm1) {
  Import-Module -Name $PSScriptRoot/ccm/utils.psm1 -Force
  $utils_psm1_avail = $true
  $IsInGitSubmodule = $false
}
elseif (Test-Path $PSScriptRoot/scripts/utils.psm1) {
  Import-Module -Name $PSScriptRoot/scripts/utils.psm1 -Force
  $utils_psm1_avail = $true
  $IsInGitSubmodule = $false
}
else {
  $utils_psm1_version = "unavail"
  $IsWindowsPowerShell = $false
  $IsInGitSubmodule = $false
}

$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
if($IsInGitSubmodule) {
  $PSCustomScriptRoot = Split-Path $PSScriptRoot -Parent
}
else {
  $PSCustomScriptRoot = $PSScriptRoot
}
$ProcessDocumentsLogPath = "$PSCustomScriptRoot/process-documents.log"
Start-Transcript -Path $ProcessDocumentsLogPath

Write-Host "Process documents script version ${setup_tesseract_ps1_version}, utils module version ${utils_psm1_version}"
Write-Host "Working directory: $PSCustomScriptRoot, log file: $ProcessDocumentsLogPath, $script_name is in submodule: $IsInGitSubmodule"

Write-Host -NoNewLine "PowerShell version:"
$PSVersionTable.PSVersion

if ($IsWindowsPowerShell) {
  Write-Host "Running on Windows Powershell, please consider update and running on newer Powershell versions"
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
  MyThrow("Your PowerShell version is too old, please update it.")
}

Push-Location $PSCustomScriptRoot

if (Test-Path $PDFFolder) {
  $PDFFolder = Resolve-Path $PDFFolder
  Write-Host "PDF folder: $PDFFolder"
}
else {
  MyThrow("PDF folder not found: $PDFFolder")
}

if (Test-Path $OutputFolder) {
  $OutputFolder = Resolve-Path $OutputFolder
  Write-Host "Output folder: $OutputFolder"
}
else {
  New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
}

if ($utils_psm1_avail) {
  $venv_dir = "$PSCustomScriptRoot/.venv"
  activateVenv($venv_dir)
}

$PYTHON_EXE = Get-Command "python" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Definition
if (-Not $PYTHON_EXE) {
  $PYTHON_EXE = Get-Command "python3" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Definition
  if (-Not $PYTHON_EXE) {
    MyThrow("Could not find python, please install it")
  }
}
else {
  Write-Host "Using python from ${PYTHON_EXE}"
}

if ($SkipImages) {
  $skip_images = "--skip-images"
}
else {
  $skip_images = ""
}

$PDFFiles = Get-ChildItem -Path $PDFFolder -Filter *.pdf -Recurse
foreach ($PDFFile in $PDFFiles) {
  $PDFFileBaseName = $PDFFile.BaseName
  $DocumentFolder = Join-Path -Path $OutputFolder -ChildPath $PDFFileBaseName
  New-Item -ItemType Directory -Force -Path $DocumentFolder | Out-Null
  $ImagesFolder = Join-Path -Path $DocumentFolder -ChildPath "images"
  New-Item -ItemType Directory -Force -Path $ImagesFolder | Out-Null
  $PDFFileCopy = (Join-Path -Path $DocumentFolder -ChildPath $PDFFileBaseName) + ".pdf"
  Copy-Item -Path $PDFFile -Destination $PDFFileCopy
  $PDFFileCopy = Resolve-Path $PDFFileCopy
  $MDFile = (Join-Path -Path $DocumentFolder -ChildPath $PDFFileBaseName) + ".md"
  $MDFileBasename = $PDFFileBaseName + ".md"
  Write-Host "Processing document: $PDFFileCopy" -ForegroundColor Yellow
  Write-Host "Output file: $MDFileBaseName" -ForegroundColor Cyan
  Write-Host "Images folder: $ImagesFolder" -ForegroundColor Cyan
  if (Test-Path $MDFile) {
    Write-Host "Output file already exists, skipping document"
    continue
  }
  $python_args = " $PSCustomScriptRoot\src\ai_converter.py --pdf `"$PDFFileCopy`" --md `"$MDFile`" --images `"$ImagesFolder`" $skip_images"
  $proc = Start-Process -NoNewWindow -PassThru -FilePath $PYTHON_EXE -ArgumentList $python_args
  $handle = $proc.Handle
  $proc.WaitForExit()
  $exitCode = $proc.ExitCode
  if (-Not ($exitCode -eq 0)) {
    MyThrow("Unable to process document! Exited with error code $exitCode.")
  }
}

$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
