<#
	Serves the game to Studio from a mirror of the repo that Syncthing never writes to.

	Syncthing writes a ~syncthing~<name>.tmp file beside each file it syncs and removes it a moment
	later. Rojo's file watcher crashes on those (change_processor.rs:172, Rojo 7.7.0 and 7.7.1 alike),
	and globIgnorePaths does not stop it. This copies src, default.project.json and rokit.toml into a
	folder outside the synced tree every 0.7 s (robocopy /MIR, skipping those temp files) and runs
	`rojo serve` there on the usual port. Edit files in the repo as always; Studio gets them up to a
	second later. Rojo is restarted if it ever exits; if the copy keeps failing, Rojo is stopped
	rather than left serving stale files.

	Usage (from the repo):  powershell -ExecutionPolicy Bypass -File tools\rojo-mirror.ps1 [-Port 34872]
	Stop with Ctrl+C.
#>
param([int]$Port = 34872, [int]$EveryMs = 700, [int]$MaxFailures = 5)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$mirror = Join-Path $env:LOCALAPPDATA 'rojo-mirror\my-roblox-game'
New-Item -ItemType Directory -Force -Path $mirror | Out-Null

# the Rojo that rokit.toml pins, run directly so stopping it stops the server itself
$pinned = Select-String -Path (Join-Path $repo 'rokit.toml') -Pattern 'rojo = "rojo-rbx/rojo@([^"]+)"'
$rojoExe = 'rojo'
if ($pinned) {
	$stored = Join-Path $env:USERPROFILE ".rokit\tool-storage\rojo-rbx\rojo\$($pinned.Matches[0].Groups[1].Value)\rojo.exe"
	if (Test-Path $stored) { $rojoExe = $stored }
}

function Sync {
	robocopy (Join-Path $repo 'src') (Join-Path $mirror 'src') /MIR /XF '~syncthing~*' '*.tmp' /R:1 /W:1 /NJH /NJS /NFL /NDL /NP | Out-Null
	$ok = $LASTEXITCODE -lt 8 # robocopy: 0-7 is success, 8 and up is failure
	foreach ($name in 'default.project.json', 'rokit.toml') {
		$from = Join-Path $repo $name
		$to = Join-Path $mirror $name
		if (-not (Test-Path $to) -or (Get-Item $from).LastWriteTimeUtc -ne (Get-Item $to).LastWriteTimeUtc) {
			Copy-Item $from $to -Force
		}
	}
	return $ok
}

function Start-Rojo {
	Start-Process -FilePath $rojoExe -ArgumentList 'serve', '--port', $Port -WorkingDirectory $mirror -NoNewWindow -PassThru
}

if (-not (Sync)) { throw 'The first copy into the mirror failed.' }
$rojo = Start-Rojo
Write-Host "Serving $mirror on port $Port, mirrored from $repo every $EveryMs ms"
$failures = 0
try {
	while ($true) {
		Start-Sleep -Milliseconds $EveryMs
		if (Sync) {
			$failures = 0
		} else {
			$failures += 1
			if ($failures -ge $MaxFailures) {
				throw "The copy into the mirror failed $failures times in a row; stopping Rojo so Studio is not left on stale files."
			}
		}
		if ($rojo.HasExited) {
			Write-Host "rojo exited ($($rojo.ExitCode)) at $(Get-Date -Format T); restarting"
			Start-Sleep -Seconds 2
			$rojo = Start-Rojo
		}
	}
} finally {
	if ($rojo -and -not $rojo.HasExited) { Stop-Process -Id $rojo.Id -Force }
}
