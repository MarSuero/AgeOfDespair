[CmdletBinding()]
param(
    [string]$Compiler = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $PSScriptRoot "build-manual"

if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = (Get-ChildItem `
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" `
        -Recurse -File -Filter "x86_64-w64-mingw32-clang++.exe" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName)
}

if ([string]::IsNullOrWhiteSpace($Compiler) -or -not (Test-Path -LiteralPath $Compiler)) {
    throw "LLVM-MinGW x86_64-w64-mingw32-clang++.exe was not found."
}

New-Item -ItemType Directory -Force $out | Out-Null
$dll = Join-Path $out "mhws_eatshit_use_action_metadata_bridge.dll"

& $Compiler -std=c++20 -shared -O2 -static -static-libgcc -static-libstdc++ `
    -I (Join-Path $root "tools\REFramework-sdk\include") `
    (Join-Path $PSScriptRoot "UseActionMetadataBridge.cpp") `
    -o $dll

if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dll)) {
    throw "LLVM-MinGW use-action metadata bridge build failed with exit code $LASTEXITCODE"
}

Write-Output $dll
