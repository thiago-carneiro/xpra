# ssh:// vs tcp:// ack-latency comparison on harpia-dev1 :177
# Heavy window: xterm 230x70 -e yes (webp ~28fps), both transports hit the SAME server.
# Metric: heavy window client-latency (server-side), plus tile encode stats.
$ErrorActionPreference = "Continue"
$d   = "C:\Users\u4w7\Downloads\Xpra\Xpra-x86_64_6.5.5-r0"
$out = Split-Path -Parent $MyInvocation.MyCommand.Path
$sshArgs = @("-o", "BatchMode=yes", "harpia-dev1")
$infoPat = 'client\.0\.window\.[0-9]+\.(damage\.(fps|client-latency\.(avg|cur|recent)|packets|target-latency)|encoding=|encoding\.pixels_encoded|batch\.(delay\.(avg|cur|max)|client-latency\.(avg|cur|recent))|size|engine|level=)'

function Invoke-Host($cmd) { & ssh @sshArgs $cmd 2>&1 | Where-Object { "$_" -notmatch "post-quantum|store now|openssh.com/pq|prohibited" } }
function Snap($label) {
  Invoke-Host "timeout 25 xpra info :177 2>/dev/null | grep -a -E '$infoPat'" | Set-Content "$out\info_$label.txt"
  "   [$label] snapshot keys: " + (Get-Content "$out\info_$label.txt").Count + " -> " + $out
}
function Start-Client($label, $url) {
  $args = @("attach", $url, "--opengl=no", "--speaker=no", "--microphone=no", "--notifications=no", "--clipboard=no", "--encoding=auto", "--ssh=C:\Windows\System32\OpenSSH\ssh.exe", "--remote-xpra=/usr/bin/xpra", "-d", "latency")
  if ($url -like "tcp*") { $args = $args | Where-Object { $_ -notin @('--ssh=C:\Windows\System32\OpenSSH\ssh.exe','--remote-xpra=/usr/bin/xpra') } }
  $p = Start-Process -FilePath "$d\Xpra_cmd.exe" -ArgumentList $args `
        -RedirectStandardOutput "$out\client_$label.log" -RedirectStandardError "$out\client_${label}_err.log" -PassThru
  Start-Sleep -Seconds 30
  $log = Get-Content "$out\client_$label.log" -ErrorAction SilentlyContinue
  $att = (($log | Select-String "Attached|Connected|authenticated|server version|timeout") -join " | ")
    Write-Host "--- [${label}] pid=$($p.Id) running=$(-not $p.HasExited) :: $att"
    ,$p
}
function Measure-Client($proc, $secs, $label) {
  $proc.Refresh(); $t0=$proc.TotalProcessorTime; $w0=Get-Date
  Start-Sleep -Seconds $secs
  $proc.Refresh(); $t1=$proc.TotalProcessorTime; $w1=Get-Date
  "[{0}] cpu_s={1:N2} wall={2:N1} avg_cpu={3:N2}% ws_MB={4:N0}" -f $label,($t1-$t0).TotalSeconds,($w1-$w0).TotalSeconds,(($t1-$t0).TotalSeconds/($w1-$w0).TotalSeconds*100),($proc.WorkingSet64/1MB)
}

"===== ssh:// round ====="
$ssh = Start-Client "ssh" "ssh://u4w7@gr15sdes01/177"
Start-Sleep -Seconds 5
Measure-Client $ssh 25 "ssh heavy load"
Snap "ssh_heavy"
Snap "ssh_heavy2"
Stop-Process -Id $ssh.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

"===== tcp:// round ====="
$tcp = Start-Client "tcp" "tcp://gr15sdes01:14501"
Start-Sleep -Seconds 5
Measure-Client $tcp 25 "tcp heavy load"
Snap "tcp_heavy"
Snap "tcp_heavy2"
Stop-Process -Id $tcp.Id -Force -ErrorAction SilentlyContinue

"===== done ====="