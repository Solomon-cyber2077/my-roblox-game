<#
.SYNOPSIS
  Cheap screenshots for Claude. Capture -> crop -> downscale -> JPEG -> report cost.

.EXAMPLES
  # one Studio shot at half size (default)
  powershell -File tools\shot.ps1 -Name stalker

  # only the middle of the window (fractions x,y,w,h), skip if nothing changed
  powershell -File tools\shot.ps1 -Name rail -Crop "0.2,0.2,0.6,0.6" -SkipIfSame

  # merge 4 shots into ONE image (costs about the same as one shot)
  powershell -File tools\shot.ps1 -Sheet a.jpg,b.jpg,c.jpg,d.jpg

  # Windows key stuck (Click to Do overlay eating clicks): release modifiers first
  powershell -File tools\shot.ps1 -ReleaseKeys -Name x

Token cost of an image is roughly width*height/750, so halving both
dimensions cuts cost about 4x. Output line tells you the estimate.
#>
[CmdletBinding()]
param(
  [string]$Window = 'RobloxStudioBeta',
  [switch]$FullScreen,
  [double]$Scale = 0.5,
  [string]$Crop,
  [switch]$SkipIfSame,
  [string]$Name = 'shot',
  [string[]]$Sheet,
  [int]$Cols = 2,
  [int]$Quality = 60,
  [int]$MaxWidth = 960,
  [switch]$ReleaseKeys,
  [string]$OutDir = (Join-Path $env:TEMP 'claude-shots')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public struct W32Rect { public int L, T, R, B; }
public static class W32 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out W32Rect r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
[void][W32]::SetProcessDPIAware()
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Tokens([int]$w, [int]$h) { [math]::Round($w * $h / 750) }

function Save-Jpeg($bmp, $path, $q) {
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
  $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter -ArgumentList ([System.Drawing.Imaging.Encoder]::Quality), ([long]$q)
  $bmp.Save($path, $codec, $ep)
}

function Resize-Bmp($src, [int]$w, [int]$h) {
  $dst = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($src, 0, 0, $w, $h)
  $g.Dispose()
  return $dst
}

function Get-Rect {
  $sw = [W32]::GetSystemMetrics(0); $sh = [W32]::GetSystemMetrics(1)
  if ($FullScreen) { return @{ L = 0; T = 0; W = $sw; H = $sh } }
  $p = Get-Process $Window -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { throw "No window for process '$Window'. Use -FullScreen or -Window <process name>." }
  $h = $p.MainWindowHandle
  if ([W32]::IsIconic($h)) { [void][W32]::ShowWindow($h, 9) }
  [void][W32]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 250
  $r = New-Object W32Rect
  [void][W32]::GetWindowRect($h, [ref]$r)
  $l = [math]::Max($r.L, 0); $t = [math]::Max($r.T, 0)
  $rr = [math]::Min($r.R, $sw); $bb = [math]::Min($r.B, $sh)
  return @{ L = $l; T = $t; W = $rr - $l; H = $bb - $t }
}

# mean abs difference of 16x16 thumbnails; ~0 means "same frame"
function Test-Same($bmp, $name) {
  $thumb = Resize-Bmp $bmp 16 16
  $prevPath = Join-Path $OutDir ".last-$name.bmp"
  $same = $false
  if (Test-Path $prevPath) {
    $prev = New-Object System.Drawing.Bitmap $prevPath
    $sum = 0
    for ($x = 0; $x -lt 16; $x++) { for ($y = 0; $y -lt 16; $y++) {
      $a = $thumb.GetPixel($x, $y); $b = $prev.GetPixel($x, $y)
      $sum += [math]::Abs($a.R - $b.R) + [math]::Abs($a.G - $b.G) + [math]::Abs($a.B - $b.B)
    } }
    $prev.Dispose()
    $same = (($sum / (16 * 16 * 3)) -lt 3)
  }
  $thumb.Save($prevPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
  $thumb.Dispose()
  return $same
}

if ($ReleaseKeys) {
  # Win, Shift, Ctrl, Alt key-up (guess at the "Click to Do" blocker: a stuck Win key)
  foreach ($vk in 0x5B, 0x5C, 0x10, 0x11, 0x12) { [W32]::keybd_event([byte]$vk, 0, 2, [UIntPtr]::Zero) }
}

if ($Sheet) {
  $imgs = $Sheet | ForEach-Object { New-Object System.Drawing.Bitmap (Resolve-Path $_).Path }
  $cellW = [int][math]::Floor($MaxWidth / $Cols)
  $cells = @(); foreach ($i in $imgs) { $cells += , @($cellW, [int][math]::Round($i.Height * $cellW / $i.Width)) }
  $cellH = ($cells | ForEach-Object { $_[1] } | Measure-Object -Maximum).Maximum
  $rows = [int][math]::Ceiling($imgs.Count / $Cols)
  $sheet = New-Object System.Drawing.Bitmap ($cellW * $Cols), ($cellH * $rows)
  $g = [System.Drawing.Graphics]::FromImage($sheet)
  $g.Clear([System.Drawing.Color]::Black)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $font = New-Object System.Drawing.Font 'Consolas', 14, ([System.Drawing.FontStyle]::Bold)
  for ($n = 0; $n -lt $imgs.Count; $n++) {
    $cx = ($n % $Cols) * $cellW; $cy = [math]::Floor($n / $Cols) * $cellH
    $g.DrawImage($imgs[$n], $cx, $cy, $cells[$n][0], $cells[$n][1])
    $g.FillRectangle([System.Drawing.Brushes]::Black, $cx, $cy, 90, 24)
    $g.DrawString("#$($n + 1)", $font, [System.Drawing.Brushes]::Yellow, $cx + 4, $cy + 1)
  }
  $g.Dispose()
  $out = Join-Path $OutDir ("sheet-" + (Get-Date -Format HHmmss) + '.jpg')
  Save-Jpeg $sheet $out $Quality
  Write-Output "OK $out $($sheet.Width)x$($sheet.Height) ~$(Tokens $sheet.Width $sheet.Height) tokens ($($imgs.Count) shots in 1 image)"
  return
}

$rect = Get-Rect
$full = New-Object System.Drawing.Bitmap $rect.W, $rect.H
$g = [System.Drawing.Graphics]::FromImage($full)
$g.CopyFromScreen($rect.L, $rect.T, 0, 0, $full.Size)
$g.Dispose()
$origTokens = Tokens $full.Width $full.Height

if ($Crop) {
  $f = $Crop.Split(',') | ForEach-Object { [double]$_ }
  if ($f.Count -ne 4) { throw '-Crop needs "x,y,w,h" as fractions 0-1' }
  $cw = [int]($full.Width * $f[2]); $ch = [int]($full.Height * $f[3])
  $region = New-Object System.Drawing.Rectangle ([int]($full.Width * $f[0])), ([int]($full.Height * $f[1])), $cw, $ch
  $cropped = $full.Clone($region, $full.PixelFormat)
  $full.Dispose(); $full = $cropped
}

if ($SkipIfSame -and (Test-Same $full $Name)) {
  Write-Output "SKIP frame unchanged since last '$Name' shot - no image produced"
  return
}

$w = [int][math]::Min([math]::Round($full.Width * $Scale), $MaxWidth)
$h = [int][math]::Round($full.Height * $w / $full.Width)
$small = Resize-Bmp $full $w $h
$out = Join-Path $OutDir ("$Name-" + (Get-Date -Format HHmmss) + '.jpg')
Save-Jpeg $small $out $Quality
Write-Output "OK $out ${w}x${h} ~$(Tokens $w $h) tokens (full frame would be ~$origTokens)"
