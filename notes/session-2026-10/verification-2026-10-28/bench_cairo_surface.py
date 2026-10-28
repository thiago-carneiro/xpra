#!/usr/bin/python3.12
"""A3: cost of make_image_surface() per frame for readonly (network) vs writable buffers,
plus the full cairo paint (surface -> backing blit). No display needed."""
import json, statistics, time
from cairo import Format, ImageSurface, Context
from xpra.cairo.image import make_image_surface

REPS = 15
SIZES = [(499, 316), (1920, 1080), (3840, 2160)]

def t_us(fn, reps=REPS):
    s = []
    for _ in range(reps):
        t0 = time.perf_counter(); fn(); s.append((time.perf_counter() - t0) * 1e6)
    return round(min(s), 1), round(statistics.median(s), 1)

rows = []
for w, h in SIZES:
    stride = w * 4; n = stride * h
    bufs = {
        "bytes(readonly)": bytes(n),
        "memoryview(readonly)": memoryview(bytes(n)),
        "bytearray(writable)": bytearray(n),
    }
    backing = ImageSurface(Format.RGB24, w, h)
    for label, buf in bufs.items():
        for fname, fmt in (("RGB24", Format.RGB24), ("ARGB32", Format.ARGB32)):
            def mk():
                s = make_image_surface(fmt, "BGRX", buf, w, h, stride); s.finish()
            def paint():
                s = make_image_surface(fmt, "BGRX", buf, w, h, stride)
                c = Context(backing); c.set_source_surface(s, 0, 0); c.paint(); s.finish()
            mk_min, mk_med = t_us(mk)
            p_min, p_med = t_us(paint)
            rows.append(dict(size="%dx%d" % (w, h), buffer=label, fmt=fname,
                             make_surface_med_us=mk_med, make_surface_min_us=mk_min,
                             make_plus_paint_med_us=p_med))
            print("%-10s %-22s %-7s make_surface med=%9.1f us  make+paint med=%9.1f us"
                  % ("%dx%d" % (w, h), label, fname, mk_med, p_med))
    alloc_min, alloc_med = t_us(lambda: ImageSurface(Format.RGB24, w, h).finish())
    copy_min, copy_med = t_us(lambda: bytes(bufs["bytearray(writable)"]))
    print("%-10s baseline: ImageSurface alloc med=%.1f us, memcpy %d B med=%.1f us" % ("%dx%d" % (w, h), alloc_med, n, copy_med))
    rows.append(dict(size="%dx%d" % (w, h), buffer="baseline", fmt="-", alloc_med_us=alloc_med, memcpy_med_us=copy_med))
json.dump(rows, open("bench_cairo_surface.json", "w"), indent=1)
