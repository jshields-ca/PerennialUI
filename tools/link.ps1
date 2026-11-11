# SPDX-License-Identifier: GPL-3.0-or-later
# Link the addon into your game client so edits show up after /reload.
#   .\tools\link.ps1 -AddOnsPath "C:\...\World of Warcraft\<forever folder>\Interface\AddOns"
# The Forever client's folder name varies by install; pass your own AddOns path.
param(
    [Parameter(Mandatory = $true)]
    [string]$AddOnsPath
)

$source = Join-Path (Split-Path -Parent $PSScriptRoot) "PerennialUI"
$target = Join-Path $AddOnsPath "PerennialUI"

if (-not (Test-Path $AddOnsPath)) {
    Write-Error "AddOns folder not found: $AddOnsPath"
    exit 1
}
if (Test-Path $target) {
    Write-Error "$target already exists. Remove it first if you want to relink."
    exit 1
}

# A junction needs no administrator rights, unlike a symbolic link.
New-Item -ItemType Junction -Path $target -Target $source | Out-Null
Write-Host "Linked $target -> $source"
