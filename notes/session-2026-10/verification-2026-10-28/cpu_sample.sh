#!/bin/bash
# usage: cpu_sample.sh PID SECONDS  -> average %CPU of PID (all threads) over the window
pid=$1; secs=${2:-30}
t0=$(awk "{print \$14+\$15}" /proc/$pid/stat); s0=$(date +%s.%N)
sleep $secs
t1=$(awk "{print \$14+\$15}" /proc/$pid/stat); s1=$(date +%s.%N)
awk -v a=$t0 -v b=$t1 -v x=$s0 -v y=$s1 "BEGIN{printf \"pid=%d cpu_ticks=%d wall=%.1fs avg_cpu=%.2f%%\n\", $pid, b-a, y-x, (b-a)/100.0/(y-x)*100}"
