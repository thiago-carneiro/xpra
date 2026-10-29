# Confirmation round: reverse order (tcp then ssh), same heavy load, isolate heavy window 6291490.
$ErrorActionPreference = "Continue"
$d   = "C:\Users\u4w7\Downloads\Xpra\Xpra-x86_64_6.5.5-r0"
$out = Split-Path -Parent $MyInvocation.MyCommand.Path
$sshArgs = @("-o", "BatchMode=yes", "harpia-dev1")
$infoPat = 'client\.0\.window\.6291490\.(damage\.(fps|client-latency\.(avg|recent)|packets)|batch\.(delay\.(avg|max)|client-latency\.(avg|recent)))'
function Invoke-Host($cmd) { & ssh @sshArgs $cmd 2>&1 | Where-Object { "$_" -notmatch "post-quantum|store now|openssh.com/pq|prohibited" } }
function Snap($label) { Invoke-Host "timeout 25 xpra info :177 2>/dev/null | grep -a -E '$infoPat'" | Set-Content "$out\info_confirm_$label.txt"; Write-Host "   [$label] keys=" (Get-Content "$out\info_confirm_$label.txt").Count }
function Cnt($label, $url, $isTcp) {
  $args = @("attach", $url, "--opengl=no", "--speaker=no", "--microphone=no", "--notifications=no", "--clipboard=no", "--encoding=auto", "--ssh=C:\Windows\System32\OpenSSH\ssh.exe", "--remote-xpra=/usr/bin/xpra")
  if ($isTcp) { $args = $args | Where-Object { $_ -notin @('--ssh=C:\Windows\System32\OpenSSH\ssh.exe','--remote-xpra=/usr/bin/xpra') } }
  $p = Start-Process -FilePath "$d\Xpra_cmd.exe" -ArgumentList $args -RedirectStandardOutput "$out\client_confirm_$label.log" -RedirectStandardError "$out\client_confirm_${label}_err.log" -PassThru
  Start-Sleep -Seconds 30
  $att = (Get-Content "$out\client_confirm_$label.log" -ErrorAction SilentlyContinue | Select-String "Attached") -join ' | '
  Write-Host "---[$label] pid=$($p.Id) running=$(-not $p.HasExited) :: $att"
  Start-Sleep -Seconds 3
  ,$p
}
"===== confirm: tcp then ssh (reverse order) ====="
$tcp = Cnt "tcp" "tcp://gr15sdes01:14501" $true
Start-Sleep -Seconds 8; Snap "tcp"; Start-Sleep -Seconds 5; Snap "tcp2"
Stop-Process -Id $tcp.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 6
$ssh = Cnt "ssh" "ssh://u4w7@gr15sdes01/177" $false
Start-Sleep -Seconds 8; Snap "ssh"; Start-Sleep -Seconds 5; Snap "ssh2"
Stop-Process -Id $ssh.Id -Force -ErrorAction SilentlyContinue
"===== confirm done ====="