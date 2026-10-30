"""Independent rational-area oracle and portable image preprocessing vectors."""
import hashlib
import io
import json
import random
import sys
import unittest
from fractions import Fraction as F
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media import image_preprocess as P
from proven_media import items


def oracle(raw, w, h, nw, nh):
    # Deliberately enumerate all source pixels using exact rational geometry.
    result = []
    for y in range(nh):
        for x in range(nw):
            accum = [F(0)] * 3
            for sy in range(h):
                wy = max(F(0), min(F(y + 1, nh), F(sy + 1, h)) - max(F(y, nh), F(sy, h)))
                for sx in range(w):
                    wx = max(F(0), min(F(x + 1, nw), F(sx + 1, w)) - max(F(x, nw), F(sx, w)))
                    for ch in range(3):
                        accum[ch] += raw[(sy * w + sx) * 3 + ch] * wx * wy * nw * nh
            result.extend((v + F(1, 2)).numerator // (v + F(1, 2)).denominator for v in accum)
    return bytes(result)


class TestIntegerImages(unittest.TestCase):
    def test_nonintegral_scale_matches_rational_geometry(self):
        rng = random.Random(20261026)
        for w, h, nw, nh in [(3, 2, 2, 3), (7, 5, 3, 2), (2, 3, 5, 7),
                              (1, 7, 3, 2), (7, 1, 2, 3), (4, 4, 1, 1), (3, 3, 3, 3)]:
            with self.subTest(shape=(w, h, nw, nh)):
                raw = bytes(rng.randrange(256) for _ in range(w * h * 3))
                self.assertEqual(P.area_rgb8(raw, w, h, nw, nh), oracle(raw, w, h, nw, nh))

    def test_single_round_and_half_up(self):
        # Rounding each axis separately would incorrectly produce 1 for this mean 1/4.
        self.assertEqual(P.area_rgb8(bytes([0] * 9 + [1] * 3), 2, 2, 1, 1), bytes(3))
        self.assertEqual(P.area_rgb8(bytes([0] * 3 + [1] * 3), 2, 1, 1, 1), bytes([1] * 3))

    def test_size_tie_and_odd_letterbox(self):
        # 3 * 224 / 192 = 3.5; ties go up, not banker's rounding.
        self.assertEqual(P.fitted_size(192, 3), (224, 4))
        self.assertEqual(P.fitted_size(448, 5), (224, 3))
        self.assertEqual(P.fitted_size(40_000_000, 1), (224, 1))
        raw = P.letterbox_rgb8(bytes([9, 8, 7]) * (448 * 5), 448, 5)
        pixel = lambda x, y: raw[(y * 224 + x) * 3:(y * 224 + x + 1) * 3]
        self.assertEqual(pixel(0, 109), bytes(P.FILL_RGB))
        self.assertEqual(pixel(0, 110), bytes([9, 8, 7]))
        self.assertEqual(pixel(0, 112), bytes([9, 8, 7]))
        self.assertEqual(pixel(0, 113), bytes(P.FILL_RGB))

    def test_all_patch_offsets(self):
        raw = bytes((x * 7 + y * 13 + c * 71) % 256
                    for y in range(224) for x in range(224) for c in range(3))
        tensor = P.patch_tensor(raw)
        restored = bytearray(len(raw))
        for y in range(224):
            for x in range(224):
                for c in range(3):
                    k = (((y // 14 * 16 + x // 14) * 3 + c) * 14 + y % 14) * 14 + x % 14
                    restored[(y * 224 + x) * 3 + c] = tensor[k]
        self.assertEqual(raw, restored)

    def test_vectors(self):
        data = json.loads((Path(__file__).parent / "fixtures/image_area_v1.json").read_text())
        self.assertEqual(data["spec"], P.SPEC_ID)
        for v in data["vectors"]:
            with self.subTest(name=v["name"]):
                raw = bytes.fromhex(v["rgb8_hex"])
                canvas = P.letterbox_rgb8(raw, v["width"], v["height"])
                tensor = P.patch_tensor(canvas)
                self.assertEqual(hashlib.sha256(canvas).hexdigest(), v["canvas_sha256"])
                self.assertEqual(hashlib.sha256(tensor).hexdigest(), v["tensor_sha256"])
                self.assertEqual(items.image_commitment(bytes(32), tensor), v["commitment_zero_salt"])

    def test_master_boundary_and_bad_inputs(self):
        from PIL import Image
        for mode in ("RGBA", "L"):
            buf = io.BytesIO()
            Image.new(mode, (10, 10)).save(buf, "PNG")
            with self.assertRaises(items.ImageRefused):
                items.canonical_canvas(buf.getvalue())
            master, _, _ = items.lossless_master(buf.getvalue())
            self.assertEqual(items.canonical_canvas(master).mode, "RGB")
        with self.assertRaises(ValueError):
            P.area_rgb8(b"", 1, 1, 1, 1)
        for dims in [(0, 1), (1, -1), (40_000_001, 1), (True, 1)]:
            with self.assertRaises(ValueError):
                P.fitted_size(*dims)
        with self.assertRaises(ValueError):
            P.patch_tensor(bytes(3))
        with self.assertRaises(items.ImageRefused):
            items.canonical_tensor(Image.new("RGB", (14, 14)))


if __name__ == "__main__":
    unittest.main()
