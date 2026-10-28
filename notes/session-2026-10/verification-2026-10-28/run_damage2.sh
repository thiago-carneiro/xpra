#!/bin/bash
# v2: no debug flags; kills by PID only; snapshots with timeout. Client on :178 attached to :177.
cd ~/xpra-bench
XPID=$(pgrep -f "Xorg.*:177" | head -1); SPID=$(pgrep -f "xpra start :177" | head -1)
echo "Xorg :177 pid=$XPID  server :177 pid=$SPID"
snap() { timeout -k 5 30 xpra info :177 2>/dev/null | grep -a -E "^client\.0\.(batch\.delay|window\.[0-9]+\.(damage|batch\.(delay|client-latency)|encoding\.|encodings\.core|encoding=|size))" > "$1"; echo "   snapshot $1: $(wc -l < $1) keys"; }
run_phase() {  # $1=label $2=opengl option
  DISPLAY=:178 setsid nohup xpra attach :177 --opengl=$2 --speaker=no --microphone=no --notifications=no --clipboard=no --mmap=no > client_$1.log 2>&1 &
  CPID=$!; sleep 10
  echo "--- [$1] client pid=$CPID: $(grep -a -i -E "OpenGL .*enabled|opengl|backing" client_$1.log | head -2 | cut -c20-120 | tr "\n" ";")"
  echo "[$1] idle 20s:"; ./cpu_sample.sh $CPID 20
  DISPLAY=:177 setsid nohup xclock -update 1 -geometry 200x200+1300+0 > /dev/null 2>&1 &
  XCPID=$!; sleep 5
  echo "[$1] xclock alone 25s:"; ./cpu_sample.sh $CPID 25
  snap info_${1}_light.txt
  DISPLAY=:177 setsid nohup xterm -geometry 200x60+0+0 -e yes > /dev/null 2>&1 &
  XTPID=$!; sleep 6
  echo "[$1] xclock + xterm yes 30s (client / server / Xorg):"
  ./cpu_sample.sh $CPID 30 & a=$!; ./cpu_sample.sh $SPID 30 & b=$!; ./cpu_sample.sh $XPID 30 & c=$!; wait $a $b $c
  kill $XTPID 2>/dev/null; sleep 2
  snap info_${1}_heavy.txt
  kill $XCPID 2>/dev/null; sleep 1
  echo "[$1] draw-related log lines: $(grep -a -c -i -E "warn|error" client_$1.log) warnings/errors"
  kill $CPID; sleep 3
}
run_phase cairo no
run_phase gl force
echo "== done =="
