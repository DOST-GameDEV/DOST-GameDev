# TWO REAL CLIENTS AGAINST A REAL DEDICATED SERVER — see name_visibility_probe.gd.
#
# ⚠️ KILLS EVERY GODOT FIRST, ALWAYS. A stale server still holding the port makes the new
# client talk to an OLD build, and Godot reports that as `The rpc node checksum failed` —
# which looks exactly like a code bug and is not one.
param(
	[int]$Port = 8960,
	[string]$Exe = "C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe"
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = Join-Path $env:TEMP "name_vis"
New-Item -ItemType Directory -Force -Path $out | Out-Null

Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$srvLog = Join-Path $out "server.log"
$aLog = Join-Path $out "clientA.log"
$bLog = Join-Path $out "clientB.log"

Start-Process -FilePath $Exe -WorkingDirectory $repo -RedirectStandardOutput $srvLog `
	-RedirectStandardError (Join-Path $out "server.err") -WindowStyle Hidden `
	-ArgumentList @("--headless", "--path", $repo, "tools/net/name_visibility_probe.tscn", "--", "--role=server", "--tag=S", "--dedicated", "--port=$Port")
Start-Sleep -Seconds 5

# A goes first so it takes the lobby-leader role and owns START MATCH.
Start-Process -FilePath $Exe -WorkingDirectory $repo -RedirectStandardOutput $aLog `
	-RedirectStandardError (Join-Path $out "clientA.err") -WindowStyle Minimized `
	-ArgumentList @("--path", $repo, "tools/net/name_visibility_probe.tscn", "--", "--name=ALICE", "--tag=A", "--port=$Port")
Start-Sleep -Seconds 2
Start-Process -FilePath $Exe -WorkingDirectory $repo -RedirectStandardOutput $bLog `
	-RedirectStandardError (Join-Path $out "clientB.err") -WindowStyle Minimized `
	-ArgumentList @("--path", $repo, "tools/net/name_visibility_probe.tscn", "--", "--name=BENJIE", "--tag=B", "--port=$Port")

Start-Sleep -Seconds 80
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "===== SERVER ====="
Get-Content $srvLog | Select-String -Pattern "^\[S\]"
Write-Host "===== CLIENT A ====="
Get-Content $aLog | Select-String -Pattern "^\[A\]"
Write-Host "===== CLIENT B ====="
Get-Content $bLog | Select-String -Pattern "^\[B\]"
Write-Host "(full logs in $out)"
