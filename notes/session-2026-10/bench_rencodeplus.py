#!/usr/bin/python3.12
"""Benchmark the real xpra packet encoder path (rencodeplus vs none).

Benchmarks the actual ENCODERS dict entries of xpra.net.packet_encoding,
verifies round-trips of the draw payload, and reports encode/decode cost
and encoded size for control-like and payload-carrying packets.
"""

import json
import statistics
import time

import xpra.net.packet_encoding as pe

REPS = 5
OUT_DIR = "/tgdesenv/src/proj0/u4w7/home2/tmp/xpra-bench"

PAYLOAD_SIZES = [64 * 1024, 1024 * 1024, 4 * 1024 * 1024]


def control_packet():
    return {
        "wid": 1, "x": 0, "y": 0,
        "width": 1920, "height": 1080,
        "encoding": "rgb24", "rowstride": 5760,
    }


def make_packet(draw_n):
    pkt = control_packet()
    if draw_n:
        pkt["draw"] = b"\x00" * draw_n
    return pkt


def time_us(fn, *args):
    """Min and median wall time in microseconds over REPS runs."""
    samples = []
    for _ in range(REPS):
        t0 = time.perf_counter()
        fn(*args)
        samples.append((time.perf_counter() - t0) * 1e6)
    return min(samples), statistics.median(samples)


def describe_buffer(data):
    info = {
        "type": type(data).__name__,
        "len": len(data),
        "has_data_attr": hasattr(data, "data"),
        "has_size_attr": hasattr(data, "size"),
    }
    return info


def bench_encoder(enc, name):
    rows = []
    for n in [0] + PAYLOAD_SIZES:
        label = "control" if n == 0 else "%dKB" % (n // 1024)
        pkt = make_packet(n)
        raw_n = len(str(pkt)) + n  # payload dominates wire cost baseline

        data, flag = enc.encode(pkt)
        buf = describe_buffer(data)
        enc_size = len(data)

        # Round-trip: smallest payload fully; bigger ones length-checked.
        decoded = enc.decode(data)
        if n and n <= 64 * 1024:
            assert decoded["draw"] == pkt["draw"], "round-trip mismatch 64KB"
        elif n:
            assert len(decoded["draw"]) == n, "round-trip length mismatch"
        assert decoded["width"] == 1920

        enc_us = time_us(enc.encode, pkt)
        dec_us = time_us(enc.decode, data)
        rows.append({
            "encoder": name,
            "payload": label,
            "payload_bytes": n,
            "encoded_bytes": enc_size,
            "ratio_vs_payload": (enc_size / n) if n else None,
            "encode_min_us": round(enc_us[0], 1),
            "encode_median_us": round(enc_us[1], 1),
            "decode_min_us": round(dec_us[0], 1),
            "decode_median_us": round(dec_us[1], 1),
            "buffer": buf,
        })
        print("%-12s %-8s enc=%9d B ratio=%-8s enc_med=%10.1f us dec_med=%10.1f us"
              % (name, label, enc_size,
                 ("%.3f" % (enc_size / n)) if n else "-",
                 enc_us[1], dec_us[1]))
    return rows


def main():
    pe.init_all()
    results = {
        "enabled": pe.get_enabled_encoders(),
        "caps": pe.get_packet_encoding_caps(),
        "rows": [],
        "buffer_inspect": None,
        "none_constant_check": [],
        "memoryview_to_bytes": {},
    }

    rows = bench_encoder(pe.ENCODERS["rencodeplus"], "rencodeplus")
    results["rows"].extend(rows)
    # Detailed buffer introspection on the control encode.
    data, _flag = pe.ENCODERS["rencodeplus"].encode(control_packet())
    results["buffer_inspect"] = describe_buffer(data)

    # "none" encoder: known 45B constant — confirm and time once.
    for n in [0, 4 * 1024 * 1024]:
        pkt = make_packet(n)
        data_n, _flag_n = pe.ENCODERS["none"].encode(pkt)
        enc_us = time_us(pe.ENCODERS["none"].encode, pkt)
        results["none_constant_check"].append({
            "payload": n, "encoded_bytes": len(data_n),
            "encode_median_us": round(enc_us[1], 1),
        })
        print("none        payload=%-9d enc=%d B enc_med=%.1f us"
              % (n, len(data_n), enc_us[1]))

    # memoryview_to_bytes copy cost for the big payloads.
    for n in [1024 * 1024, 4 * 1024 * 1024]:
        mv = memoryview(b"\x00" * n)
        mv_us = time_us(pe.memoryview_to_bytes, mv)
        results["memoryview_to_bytes"]["%dKB" % (n // 1024)] = {
            "median_us": round(mv_us[1], 1),
        }
        print("memoryview_to_bytes %dKB med=%.1f us" % (n // 1024, mv_us[1]))

    with open(OUT_DIR + "/bench_rencodeplus.json", "w") as f:
        json.dump(results, f, indent=2)

    # Short MD table.
    lines = [
        "| encoder | payload | encoded B | ratio | enc med us | dec med us |",
        "|---|---|---|---|---|---|",
    ]
    for r in rows:
        lines.append("| %s | %s | %d | %s | %.1f | %.1f |" % (
            r["encoder"], r["payload"], r["encoded_bytes"],
            ("%.3f" % r["ratio_vs_payload"]) if r["ratio_vs_payload"] else "-",
            r["encode_median_us"], r["decode_median_us"]))
    with open(OUT_DIR + "/bench_rencodeplus.md", "w") as f:
        f.write("\n".join(lines) + "\n")

    print("saved: %s/bench_rencodeplus.json .md" % OUT_DIR)


if __name__ == "__main__":
    main()
