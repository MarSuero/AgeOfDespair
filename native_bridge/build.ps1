[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $PSScriptRoot "build"

$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if ($null -eq $cmake) {
    throw "CMake was not found on PATH. Install/use a Visual Studio developer environment first."
}

$sdkApi = Join-Path $root "tools\REFramework-sdk\include\reframework\API.hpp"
if (-not (Test-Path -LiteralPath $sdkApi)) {
    throw "REFramework SDK is missing: $sdkApi"
}

& $cmake.Source -S $PSScriptRoot -B $buildDir -A x64
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE"
}

& $cmake.Source --build $buildDir --config $Configuration --target mhws_eatshit_native_bridge
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
}

$dll = Join-Path $buildDir "$Configuration\mhws_eatshit_native_bridge.dll"
if (-not (Test-Path -LiteralPath $dll)) {
    throw "Build completed without the expected DLL: $dll"
}

Write-Output $dll
