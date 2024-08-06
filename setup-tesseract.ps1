#!/usr/bin/env pwsh

<#

.SYNOPSIS
        setup-tesseract
        Created By: Stefano Sinigardi
        Created Date: August 6, 2024
        Last Modified Date: August 6, 2024

.DESCRIPTION
Setup tesseract

.PARAMETER DisableInteractive
Disable script interactivity (useful for CI runs)

.PARAMETER DoNotUpdateTOOL
Do not update the tool before running the build (valid only if tool is git-enabled)

.EXAMPLE
.\setup-tesseract -DisableInteractive

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
  [switch]$DoNotUpdateTOOL = $false
)

$global:DisableInteractive = $DisableInteractive

$setup_tesseract_ps1_version = "1.0.0"
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
$SetupTesseractLogPath = "$PSCustomScriptRoot/setup-tesseract.log"
Start-Transcript -Path $SetupTesseractLogPath

Write-Host "Setup tesseract script version ${setup_tesseract_ps1_version}, utils module version ${utils_psm1_version}"
Write-Host "Working directory: $PSCustomScriptRoot, log file: $SetupTesseractLogPath, $script_name is in submodule: $IsInGitSubmodule"

Write-Host -NoNewLine "PowerShell version:"
$PSVersionTable.PSVersion

if ($IsWindowsPowerShell) {
  Write-Host "Running on Windows Powershell, please consider update and running on newer Powershell versions"
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
  MyThrow("Your PowerShell version is too old, please update it.")
}

Push-Location $PSCustomScriptRoot

if ($env:VCPKG_ROOT) {
  $VCPKG_ROOT = $env:VCPKG_ROOT
}
elseif (Test-Path "$PSCustomScriptRoot/vcpkg") {
  $VCPKG_ROOT = "$PSCustomScriptRoot/vcpkg"
}
elseif (Test-Path "$env:WORKSPACE/vcpkg") {
  $VCPKG_ROOT = "$env:WORKSPACE/vcpkg"
}
else {
  git clone https://github.com/microsoft/vcpkg $PSCustomScriptRoot/vcpkg
  $VCPKG_ROOT = "$PSCustomScriptRoot/vcpkg"
}

if (-Not $env:TESSDATA_PREFIX) {
  $env:TESSDATA_PREFIX = "$PSCustomScriptRoot/src"
}

if (-Not $VCPKG_ROOT) {
  MyThrow("Could not find vcpkg, something is broken")
}
else {
  Write-Host "Using vcpkg from ${VCPKG_ROOT}"
  Push-Location $VCPKG_ROOT
  if (-Not $DoNotUpdateTOOL) {
    git pull
  }
  .\bootstrap-vcpkg.bat -disableMetrics
  .\vcpkg install tesseract --triplet=x64-windows-release --host-triplet=x64-windows-release --clean-buildtrees-after-build --clean-packages-after-build --recurse
  Copy-Item installed/x64-windows-release/tools/tesseract/*.* $PSCustomScriptRoot/src
  Pop-Location
}

if (-Not (Test-Path "$env:TESSDATA_PREFIX/eng.traineddata")) {
  curl.exe -o src/eng.traineddata https://raw.githubusercontent.com/tesseract-ocr/tessdata/main/eng.traineddata
}
if (-Not (Test-Path "$env:TESSDATA_PREFIX/frozen_east_text_detection.pb")) {
  curl.exe -o src/frozen_east_text_detection.pb https://raw.githubusercontent.com/oyyd/frozen_east_text_detection.pb/master/frozen_east_text_detection.pb
}

$env:PATH = "$env:TESSDATA_PREFIX;$env:PATH"

$TESSERACT_EXE = Get-Command "tesseract" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Definition
if (-Not $TESSERACT_EXE) {
  MyThrow("Could not find tesseract in PATH, something is broken")
}
else {
  Write-Host "Using tesseract from ${TESSERACT_EXE}"
}

$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
