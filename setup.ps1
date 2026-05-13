#Requires -Version 5.1
# One-shot setup for the Roblox + Cursor + Rojo development environment.
# Run from this directory:  .\setup.ps1
#
# What this does:
#   1. Installs Rokit (toolchain manager) if not already on PATH.
#   2. Runs `rokit install` to download Rojo and StyLua at the versions pinned in rokit.toml.
#   3. Runs `rojo plugin install` to drop the Rojo plugin into Roblox Studio.

$ErrorActionPreference = "Stop"

function Refresh-PathFromRegistry {
	$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
	$userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
	$env:Path = "$machinePath;$userPath"
}

Write-Host ""
Write-Host "==> Roblox dev environment setup" -ForegroundColor Cyan
Write-Host "    project: $PSScriptRoot"
Write-Host ""

# 1. Rokit
if (-not (Get-Command rokit -ErrorAction SilentlyContinue)) {
	Write-Host "==> Rokit not found, installing..." -ForegroundColor Yellow
	Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
	Refresh-PathFromRegistry
	if (-not (Get-Command rokit -ErrorAction SilentlyContinue)) {
		Write-Error @"
Rokit installer ran but 'rokit' is still not on PATH in this session.
Close this terminal, open a new PowerShell, cd back here, and re-run .\setup.ps1.
"@
		exit 1
	}
	Write-Host "==> Rokit installed: $((rokit --version))" -ForegroundColor Green
} else {
	Write-Host "==> Rokit already installed: $((rokit --version))" -ForegroundColor Green
}

# 2. Tools from rokit.toml (Rojo + StyLua, versions pinned)
Write-Host ""
Write-Host "==> Installing tools from rokit.toml (this can take a minute on first run)..." -ForegroundColor Cyan
rokit install --force

Write-Host ""
Write-Host "    rojo  -> $((rojo --version))"
Write-Host "    stylua -> $((stylua --version))"

# 3. Roblox Studio plugin
Write-Host ""
Write-Host "==> Installing Rojo plugin into Roblox Studio..." -ForegroundColor Cyan
rojo plugin install

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open Roblox Studio (sign in if you haven't yet)."
Write-Host "  2. File -> New -> Baseplate."
Write-Host "  3. Plugins toolbar -> Rojo -> Connect (defaults to localhost:34872)."
Write-Host "  4. In this terminal, start the sync server:  rojo serve"
Write-Host "  5. Edit src/server/Hello.server.luau, save, watch Studio update live."
Write-Host ""
