# A3 before/after and A5 head-of-line test on the Windows client against harpia-dev1 :179
$ErrorActionPreference = "Continue"
$d = "C:\Users\u4w7\Downloads\Xpra\Xpra-x86_64_6.5.5-r0"
$out = "C:\Users\u4w7\AppData\Local\Temp\claude\c--Users-u4w7\275337e8-7be7-4b47-8c64-859ff7297b57\scratchpad\a3"
$sshArgs = @("-o", "BatchMode=yes", "harpia-dev1")
$infoPat = 'client\.0\.(batch\.delay\.(cur|avg|max)|window\.[0-9]+\.(encoding=|encodings\.core|batch\.(delay\.(avg|cur|max)|client-latency\.(avg|cur|recent))|damage\.(packets|fps|target-latency)|encoding\.pixels_encoded|size))'

function Invoke-Host($cmd) { & ssh @sshArgs $cmd 2>&1 | Where-Object { "$_" -notmatch "post-quantum|store now|openssh.com/pq" } }
function Snap($label) { Invoke-Host "xpra info :179 2>/dev/null | grep -a -E '$infoPat'" | Set-Content "$outinfo_$label.txt"; "   snapshot " + $label + ": " + (Get-Content "$outinfo_$label.txt").Count + " keys" }
function Measure-Client($proc, $secs, $label) {
  $proc.Refresh(); $t0 = $proc.TotalProcessorTime; $w0 = Get-Date; Start-Sleep -Seconds $secs; $proc.Refresh(); $t1 = $proc.TotalProcessorTime; $w1 = Get-Date
  "[{0}] cpu_s={1:N2} wall_s={2:N1} avg_cpu={3:N2}% ws_MB={4:N0}" -f $label, ($t1-$t0).TotalSeconds, ($w1-$w0).TotalSeconds, (($t1-$t0).TotalSeconds/($w1-$w0).TotalSeconds*100), ($proc.WorkingSet64/1MB)
}
function Start-Client($label, $extra) {
  $args = @("attach", "ssh://u4w7@gr15sdes01/179", "--opengl=no", "--speaker=no", "--microphone=no", "--notifications=no", "--clipboard=no", "--ssh=C:\Windows\System32\OpenSSH\ssh.exe", "--remote-xpra=/usr/bin/xpra") + $extra
  $p = Start-Process -FilePath "$d\Xpra_cmd.exe" -ArgumentList $args -RedirectStandardOutput "$out\client_$label.log" -RedirectStandardError "$out\client_${label}_err.log" -PassThru
  Start-Sleep -Seconds 28
  "--- [${label}] pid=" + $p.Id + " running=" + (-not $p.HasExited) + " " + ((Get-Content "$out\client_$label.log" | Select-String "Attached|running,") -join " | ")
  return $p
}
function Start-Heavy { Invoke-Host "DISPLAY=:179 setsid nohup xterm -geometry 230x70+0+0 -e yes >/dev/null 2>&1 & sleep 1; echo heavy started" }
function Stop-Heavy { Invoke-Host "pgrep -f 'xterm -geometry 230x70' | xargs -r kill; echo heavy stopped" }
function Start-Light { Invoke-Host "DISPLAY=:179 setsid nohup xclock -update 1 -geometry 200x200+1500+0 >/dev/null 2>&1 & sleep 1; echo light started" }
function Stop-Light { Invoke-Host "pgrep -f 'xclock -update' | xargs -r kill; echo light stopped" }

"===== A3 before/after (opengl=no) ====="
foreach ($enc in @("auto", "rgb")) {
  foreach ($a3 in @("0", "1")) {
    $label = "a3_${enc}_fast$a3"
    $env:XPRA_CAIRO_A3 = $a3
    $p = Start-Client $label @("--encoding=$enc")
    Start-Heavy | Out-Null; Start-Sleep -Seconds 6
    Measure-Client $p 30 $label
    Snap "${label}_heavy"
    Stop-Heavy | Out-Null; Start-Sleep -Seconds 2
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3
    "   paint path stats: " + ((Get-Content "$out\client_$label.log" | Select-String "A3 paint path stats" | Select-Object -Last 1) -replace '.*A3 paint','A3 paint')
  }
}
$env:XPRA_CAIRO_A3 = "1"

"===== A5 head-of-line (opengl=no, -d paint, remote-logging=no) ====="
$label = "a5_paint"
$p = Start-Client $label @("--remote-logging=no", "-d", "paint")
Measure-Client $p 15 "$label idle"
Start-Light | Out-Null; Start-Sleep -Seconds 5
Measure-Client $p 25 "$label xclock only"
Snap "${label}_light"
Start-Heavy | Out-Null; Start-Sleep -Seconds 6
Measure-Client $p 30 "$label xclock + xterm yes"
Snap "${label}_heavy"
Stop-Heavy | Out-Null; Stop-Light | Out-Null; Start-Sleep -Seconds 2
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
"log lines: $((Get-Content "$out\client_$label.log").Count)"
"===== done ====="
