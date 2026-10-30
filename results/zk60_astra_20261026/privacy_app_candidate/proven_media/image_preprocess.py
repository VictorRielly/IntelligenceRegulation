"""pm-img-area-v1: exact RGB8 area resize and centred 224px letterbox.

The canonical boundary is decoded RGB8 pixels from a lossless master. Every
resize coefficient, dimension and rounding decision below uses integers.
"""
from __future__ import annotations

CANVAS_PX = 224
PATCH_PX = 14
FILL_RGB = (123, 117, 104)
SPEC_ID = "pm-img-area-v1"
MAX_PIXELS = 40_000_000


def _dimensions(w: int, h: int) -> None:
    if type(w) is not int or type(h) is not int or min(w, h) < 1 or w * h > MAX_PIXELS:
        raise ValueError("image dimensions out of range")


def fitted_size(w: int, h: int) -> tuple[int, int]:
    """Longest edge 224; short edge nearest integer, ties upward, minimum 1."""
    _dimensions(w, h)
    longest = max(w, h)
    return tuple(max(1, (2 * n * CANVAS_PX + longest) // (2 * longest)) for n in (w, h))


def _axis(src: int, dst: int):
    # In common integer coordinates source pixel i spans [i*dst,(i+1)*dst),
    # output pixel j spans [j*src,(j+1)*src). Each output's weights sum to src.
    for j in range(dst):
        lo, hi = j * src, (j + 1) * src
        yield [(i, min(hi, (i + 1) * dst) - max(lo, i * dst))
               for i in range(lo // dst, (hi + dst - 1) // dst)]


def area_rgb8(raw: bytes, w: int, h: int, nw: int, nh: int) -> bytes:
    """Exact area average, ONE final round-half-up, including when upsampling.

    Weights are integer overlap lengths. No per-axis intermediate rounding.
    Row streaming keeps auxiliary storage bounded by the output width.
    """
    _dimensions(w, h)
    _dimensions(nw, nh)
    if len(raw) != w * h * 3:
        raise ValueError("RGB8 byte length does not match dimensions")
    if (w, h) == (nw, nh):
        return bytes(raw)
    xs = list(_axis(w, nw))
    out = bytearray(nw * nh * 3)
    denominator = w * h
    cached_y, horizontal = -1, None
    for dy, ys in enumerate(_axis(h, nh)):
        accum = [0] * (nw * 3)
        for sy, yw in ys:
            if sy != cached_y:
                horizontal = [0] * (nw * 3)
                base = sy * w * 3
                for dx, weights in enumerate(xs):
                    k = dx * 3
                    for sx, xw in weights:
                        p = base + sx * 3
                        horizontal[k] += raw[p] * xw
                        horizontal[k + 1] += raw[p + 1] * xw
                        horizontal[k + 2] += raw[p + 2] * xw
                cached_y = sy
            for k, value in enumerate(horizontal):
                accum[k] += value * yw
        offset = dy * nw * 3
        out[offset:offset + nw * 3] = bytes((2 * v + denominator) // (2 * denominator) for v in accum)
    return bytes(out)


def letterbox_rgb8(raw: bytes, w: int, h: int) -> bytes:
    nw, nh = fitted_size(w, h)
    resized = area_rgb8(raw, w, h, nw, nh)
    out = bytearray(bytes(FILL_RGB) * (CANVAS_PX * CANVAS_PX))
    left, top = (CANVAS_PX - nw) // 2, (CANVAS_PX - nh) // 2
    for y in range(nh):
        dst = ((top + y) * CANVAS_PX + left) * 3
        out[dst:dst + nw * 3] = resized[y * nw * 3:(y + 1) * nw * 3]
    return bytes(out)


def patch_tensor(raw: bytes) -> bytes:
    """[patch_y, patch_x, channel, pixel_y, pixel_x], no model plane padding."""
    if len(raw) != CANVAS_PX * CANVAS_PX * 3:
        raise ValueError("expected a 224 x 224 RGB8 canvas")
    out = bytearray()
    for py in range(0, CANVAS_PX, PATCH_PX):
        for px in range(0, CANVAS_PX, PATCH_PX):
            for ch in range(3):
                for y in range(py, py + PATCH_PX):
                    base = (y * CANVAS_PX + px) * 3 + ch
                    out += raw[base:base + PATCH_PX * 3:3]
    return bytes(out)
