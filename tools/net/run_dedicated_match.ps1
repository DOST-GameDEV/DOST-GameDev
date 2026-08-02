<#
  Plays a whole match through a REAL dedicated server and says PASS or FAIL.

      powershell -ExecutionPolicy Bypass -File tools/net/run_dedicated_match.ps1

  Stands up one dedicated lobby, then drives a real client through the player's
  actual path -- HOST ONLINE, ready up, START MATCH -- and checks that a match is
  running on the far side rather than that a scene merely loaded. See
  dedicated_match_run.gd for what each check means.

  ⚠️ THE PORT MUST BE INSIDE ServerQuery's POOL RANGE (8910-8917). HOST ONLINE can
  only claim a server the pool query found, and the query only asks those ports --
  a lobby on 8955 is invisible to it and the run fails at "claimed a server" with
  no other clue. Measured: the first run of this harness used 8955 and reported
  zero pool rows while the server was up and bound.

  ⚠️ LEFTOVER PROCESSES ARE KILLED FIRST, and that is not tidiness. A dedicated
  server still holding the port from an earlier run makes the new client talk to
  the OLD build, which Godot reports as "The rpc node checksum failed. Make sure
  to have the same methods on both nodes" -- a message that blames your code and
  cost an hour once already.

  ⚠️ THE CLIENT RUNS WITHOUT --headless ON PURPOSE. There is no rendering device
  under --headless on this machine: the 3D scene never draws and the screenshot
  comes back blank.
#>

param(
    [string]$Godot   = 'C:\Users\StarX\Desktop\Godot_v4.7.1-stable_win64.exe',
    [string]$Project = 'C:\Users\StarX\Desktop\SCHOOL\dostgame\DOST-GameDev',
    # Inside 8910-8917. See the ⚠️ above.
    [int]$Port       = 8916,
    [string]$OutDir  = ''
)

$ErrorActionPreference = 'Stop'

if ($OutDir -eq '') {
    $OutDir = Join-Path $env:TEMP ('dostgame-match\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host ("dedicated lobby on {0}, logs -> {1}" -f $Port, $OutDir)
$server = Start-Process -FilePath $Godot -WindowStyle Hidden -PassThru -ArgumentList @(
    '--headless', '--path', $Project, 'res://scenes/ui/MatchSetup.tscn',
    '--', '--dedicated', ('--port=' + $Port)
) -RedirectStandardOutput (Join-Path $OutDir 'server.log') `
  -RedirectStandardError  (Join-Path $OutDir 'server.err')

# The server has to be answering status queries before the client asks, or HOST
# ONLINE finds an empty pool and gives up before the first reply lands.
Start-Sleep -Seconds 7

$exit = 0
try {
    & $Godot --path $Project 'tools/net/dedicated_match_run.tscn' `
        '--' '--pool=127.0.0.1' ('--port=' + $Port) ($OutDir + '\') 2>&1 |
        Tee-Object -FilePath (Join-Path $OutDir 'client.log') |
        Select-String -Pattern '\[run\]|SCRIPT ERROR'
    $exit = $LASTEXITCODE
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}

if ($exit -eq 0) {
    Write-Host "`nPASS - a match played through the dedicated server."
} else {
    Write-Host ("`nFAIL - {0} check(s) failed. Full output: {1}" -f $exit, (Join-Path $OutDir 'client.log'))
}
exit $exit
