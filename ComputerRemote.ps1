# Computer Remote - PC helper
# Runs quietly in the background. It asks the relay server "any commands from my phone?" and opens
# the app or game you tapped. It only makes OUTGOING web requests: no open ports, no firewall rule,
# no admin rights. It can ONLY run things from its own list below (apps, games, lock PC).
#
# Files (in the same folder as this script):
#   key.txt      - your secret pairing key (made on first run). Anyone with it can open your apps,
#                  so don't share it. Delete it to make a new one (then re-pair your phone).
#   config.json  - optional: extra apps, and what "Start my setup" opens.
#   log.txt      - what it did, for troubleshooting.

param([switch]$Pair, [switch]$ListOnly)

$ErrorActionPreference = 'Stop'
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Server = 'https://drift-club-qvkk.onrender.com'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Log($msg) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg"
  try {
    $f = Join-Path $Dir 'log.txt'
    if ((Test-Path $f) -and (Get-Item $f).Length -gt 200KB) { Remove-Item $f -Force }
    Add-Content -Path $f -Value $line -Encoding UTF8
  } catch {}
  Write-Host $line
}

# ---------------------------------------------------------------- pairing key
$KeyFile = Join-Path $Dir 'key.txt'
if (-not (Test-Path $KeyFile)) {
  $bytes = New-Object byte[] 32
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $k = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  Set-Content -Path $KeyFile -Value $k -Encoding ASCII -NoNewline
}
$Key = (Get-Content $KeyFile -Raw).Trim()

if ($Pair) {
  # Opens a page on this PC that shows a QR code. Scan it with your phone camera.
  # The key goes after '#', so it never travels to the server inside the web address.
  Start-Process "$Server/remote-pair.html#key=$Key"
  return
}

# ---------------------------------------------------------------- config
$Config = @{ setup = @('Discord', 'Opera GX', 'Medal', 'Claude'); apps = @() }
$CfgFile = Join-Path $Dir 'config.json'
if (Test-Path $CfgFile) {
  try {
    $c = Get-Content $CfgFile -Raw | ConvertFrom-Json
    if ($c.setup) { $Config.setup = @($c.setup) }
    if ($c.apps) { $Config.apps = @($c.apps) }
  } catch { Log "config.json has a mistake, ignoring it: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------- find apps
# Looks in the Start menu (yours + all users) and on both desktops for shortcuts.
function Find-Shortcuts {
  $roots = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'),
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path $env:PUBLIC 'Desktop')
  )
  $out = @()
  foreach ($r in $roots) { if ($r -and (Test-Path $r)) { $out += Get-ChildItem -Path $r -Filter *.lnk -Recurse -ErrorAction SilentlyContinue } }
  $out
}
$Wanted = @(
  @{ name = 'Discord';  match = '^Discord$|^Vencord' },
  @{ name = 'Opera GX'; match = '^Opera GX' },
  @{ name = 'Medal';    match = '^Medal' },
  @{ name = 'Claude';   match = '^Claude$' },
  @{ name = 'Steam';    match = '^Steam$' },
  @{ name = 'EA';       match = '^EA$|^EA app' },
  @{ name = 'Epic Games'; match = '^Epic Games Launcher' },
  @{ name = 'OBS Studio'; match = '^OBS Studio' },
  @{ name = 'Lunar Client'; match = '^Lunar Client' },
  @{ name = 'Spotify'; match = '^Spotify$' }
)

function Get-Actions {
  $actions = New-Object System.Collections.ArrayList
  $run = @{}
  $lnks = Find-Shortcuts
  foreach ($w in $Wanted) {
    $hits = @($lnks | Where-Object { $_.BaseName -match $w.match } | Sort-Object FullName -Unique)
    # same shortcut name on desktop + start menu = same app; keep different names (e.g. two Opera GX)
    $seen = @{}; $paths = @()
    foreach ($h in $hits) { if (-not $seen[$h.BaseName]) { $seen[$h.BaseName] = 1; $paths += $h.FullName } }
    if ($paths.Count) {
      $id = 'app:' + ($w.name -replace '\W', '').ToLower()
      $label = if ($paths.Count -gt 1) { "$($w.name) (x$($paths.Count))" } else { $w.name }
      [void]$actions.Add(@{ id = $id; name = $label; group = 'app' })
      $run[$id] = @{ name = $w.name; paths = $paths }
    }
  }
  foreach ($a in $Config.apps) {
    if (-not $a.name -or -not $a.path) { continue }
    $id = 'app:x' + ($a.name -replace '\W', '').ToLower()
    [void]$actions.Add(@{ id = $id; name = [string]$a.name; group = 'app' })
    $run[$id] = @{ name = [string]$a.name; exe = [Environment]::ExpandEnvironmentVariables([string]$a.path); args = [string]$a.args }
  }

  # ---- Steam games
  try {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\', '\') } }
    $seenApp = @{}
    foreach ($lib in ($libs | Select-Object -Unique)) {
      $sa = Join-Path $lib 'steamapps'
      if (-not (Test-Path $sa)) { continue }
      foreach ($f in Get-ChildItem $sa -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue) {
        $t = Get-Content $f.FullName -Raw
        $appid = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
        $name = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value
        if (-not $appid -or $seenApp[$appid] -or $name -match 'Redistributable|Steamworks|Proton|Steam Linux Runtime|SteamVR|Dedicated Server') { continue }
        $seenApp[$appid] = 1
        $id = "steam:$appid"
        [void]$actions.Add(@{ id = $id; name = $name; group = 'game' })
        $run[$id] = @{ name = $name; uri = "steam://rungameid/$appid" }
      }
    }
  } catch {}

  # ---- Epic games
  try {
    $man = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (Test-Path $man) {
      foreach ($f in Get-ChildItem $man -Filter *.item -ErrorAction SilentlyContinue) {
        $j = Get-Content $f.FullName -Raw | ConvertFrom-Json
        if (-not $j.DisplayName -or -not $j.AppName) { continue }
        $id = 'epic:' + ($j.AppName -replace '[^\w-]', '')
        [void]$actions.Add(@{ id = $id; name = [string]$j.DisplayName; group = 'game' })
        $run[$id] = @{ name = [string]$j.DisplayName; uri = "com.epicgames.launcher://apps/$($j.CatalogNamespace)%3A$($j.CatalogItemId)%3A$($j.AppName)?action=launch&silent=true" }
      }
    }
  } catch {}

  # ---- setup + PC
  $setupIds = @()
  foreach ($n in $Config.setup) { foreach ($k in @($run.Keys)) { if ($k -like 'app:*' -and $run[$k].name -eq $n) { $setupIds += $k } } }
  if ($setupIds.Count) { [void]$actions.Add(@{ id = 'setup'; name = 'Start my setup'; group = 'setup' }); $run['setup'] = @{ name = 'my setup'; list = $setupIds } }
  [void]$actions.Add(@{ id = 'pc:lock'; name = 'Lock PC'; group = 'pc' })
  $run['pc:lock'] = @{ name = 'Lock PC'; exe = 'rundll32.exe'; args = 'user32.dll,LockWorkStation' }

  $games = @($actions | Where-Object { $_.group -eq 'game' } | Sort-Object { $_.name })
  $rest = @($actions | Where-Object { $_.group -ne 'game' })
  return @{ list = @($rest + $games); run = $run }
}

function Invoke-Entry($e) {
  if ($e.list) { foreach ($i in $e.list) { Invoke-Entry $script:A.run[$i]; Start-Sleep -Milliseconds 700 }; return }
  if ($e.uri) { Start-Process $e.uri; return }
  if ($e.paths) { foreach ($p in $e.paths) { Start-Process -FilePath $p; Start-Sleep -Milliseconds 400 }; return }
  if ($e.exe) { if ($e.args) { Start-Process -FilePath $e.exe -ArgumentList $e.args } else { Start-Process -FilePath $e.exe } }
}

$script:A = Get-Actions
if ($ListOnly) { $script:A.list | ForEach-Object { "{0,-6} {1}" -f $_.group, $_.name }; return }

# one copy at a time
$mutex = New-Object Threading.Mutex($false, 'Local\ComputerRemoteHelper')
if (-not $mutex.WaitOne(0)) { Log 'Already running.'; return }

Log "Started. Found $($script:A.list.Count) things to launch."
$done = @()
$sendStatus = $true
$lastScan = Get-Date
$wait = 2
while ($true) {
  try {
    if (((Get-Date) - $lastScan).TotalMinutes -ge 10) { $script:A = Get-Actions; $lastScan = Get-Date; $sendStatus = $true }
    $body = @{ done = $done }
    if ($sendStatus) { $body.status = @{ name = $env:COMPUTERNAME; actions = $script:A.list } }
    $json = $body | ConvertTo-Json -Depth 6 -Compress
    $r = Invoke-RestMethod -Uri "$Server/remote/api/agent" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($json)) `
      -ContentType 'application/json; charset=utf-8' -Headers @{ 'X-Remote-Key' = $Key } -TimeoutSec 40 -UseBasicParsing
    $done = @(); $sendStatus = $false; $wait = 2
    foreach ($c in @($r.cmds)) {
      if (-not $c) { continue }
      $e = $script:A.run[[string]$c.action]
      if (-not $e) { $done += @{ id = $c.id; ok = $false; msg = "Unknown: $($c.action)" }; continue }
      try { Invoke-Entry $e; $done += @{ id = $c.id; ok = $true; msg = "Opened $($e.name)" }; Log "Opened $($e.name)" }
      catch { $done += @{ id = $c.id; ok = $false; msg = "Couldn't open $($e.name)" }; Log "Failed $($e.name): $($_.Exception.Message)" }
    }
    # every so often re-send the list in case the server restarted
    if ((Get-Random -Maximum 40) -eq 0) { $sendStatus = $true }
  } catch {
    $sendStatus = $true
    Log "Can't reach server ($($_.Exception.Message)). Retrying in $wait s."
    Start-Sleep -Seconds $wait
    $wait = [Math]::Min(60, $wait * 2)
  }
}
