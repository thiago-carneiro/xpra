#!/usr/bin/python3.12
"""N2/B2: what does SocketProtocol.encode() produce for a draw packet carrying a large Compressed item?
Counts the wire packets and times encode() for 64KB/1MB/4MB payloads. Run with default INLINE_SIZE and with
XPRA_INLINE_SIZE=16777216 (forces inlining) for the A/B."""
import os, time, statistics, json
from xpra.net import packet_encoding, compression; packet_encoding.init_all(); compression.init_all()
from xpra.net.compression import Compressed
from xpra.net.protocol.socket_handler import SocketProtocol, INLINE_SIZE, READ_BUFFER_SIZE, PACKET_JOIN_SIZE

class FakeConn:
    socktype = "tcp"; target = "bench"; info = {}; timeout = 0
    def read(self, n): return b""
    def write(self, d): return len(d)
    def close(self): pass
    def peek(self, n): return b""
    def recv_into(self, b): return 0

p = SocketProtocol(FakeConn(), lambda proto, pkt: None)
p.enable_encoder("rencodeplus"); p.enable_compressor("none")
print("INLINE_SIZE=%d READ_BUFFER_SIZE=%d PACKET_JOIN_SIZE=%d encoder=%s" % (INLINE_SIZE, READ_BUFFER_SIZE, PACKET_JOIN_SIZE, p.encoder))
rows = []
for n in (64 * 1024, 1024 * 1024, 4 * 1024 * 1024):
    data = memoryview(bytes(n))
    def mk():
        return ["draw", 1, 0, 0, 1920, 1080, "rgb24", Compressed("rgb24", data, can_inline=True), 5760, 1, {"rgb_format": "BGRX"}]
    out = p.encode(mk())
    shape = [(t[0], t[1], t[2], len(t[3])) for t in out]  # (seq?, index, level, len)
    s = []
    for _ in range(25):
        pkt = mk(); t0 = time.perf_counter(); p.encode(pkt); s.append((time.perf_counter() - t0) * 1e6)
    med = statistics.median(s)
    print("payload=%8d B -> %d wire packets %s  encode med=%.1f us" % (n, len(out), shape, med))
    rows.append(dict(inline_size=INLINE_SIZE, payload=n, wire_packets=len(out), shape=shape, encode_median_us=round(med, 1)))
json.dump(rows, open("bench_chunking_%d.json" % INLINE_SIZE, "w"), indent=1)
