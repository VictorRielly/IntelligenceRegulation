"""Typed content items (D39 as narrowed by Victor: TEXT and IMAGE for the POC; video and audio
deferred) and the image's canonical preprocessing.

A prover takes one typed item. Text: one classifier proof over the post. Image: one classifier
proof over the image's CANONICAL CANVAS (Shieldstral's Pixtral path, not built yet), following the
multimodal design (`results/zk60_multimodal_design_20261021/DESIGN.md` §2-§3):

  1. lossless master: decode once, apply the EXIF orientation, RGB8, metadata dropped, stored as
     PNG; the displayed post derives from it (PNG decoding is exact, no decoder to pin);
  2. resize: the longest edge to the canvas size with an integer area-average resample;
  3. letterbox: centred on a fixed square canvas (224 px for the POC, pending Victor), filled with
     the model's per-channel normalisation mean so the normalised padding is about 0;
  4. layout: patch-major uint8 tensor (patch row, patch column, channel, 14 x 14).
The proof will bind to the post through the run's hidden input endpoint (the design's L3: the
binding blob travels with the post); until then the app records a SALTED commitment to the
canonical tensor. The versioned reference is image_preprocess.py: exact integer
area overlaps, one final round-half-up, and test vectors. Image proofs remain in development.
"""
from __future__ import annotations

import hashlib
import io
import struct
from dataclasses import dataclass, field
from pathlib import Path

from .image_preprocess import CANVAS_PX, PATCH_PX, FILL_RGB, SPEC_ID, MAX_PIXELS, letterbox_rgb8, patch_tensor

IMAGE_SPEC_ID = SPEC_ID
IMAGE_DOMAIN = b"zk60/proven-media/image/pm-img-area-v1"
IMAGE_SPEC_TEXT = (
    f"{IMAGE_SPEC_ID}: decode once to a lossless RGB8 master (EXIF orientation applied, metadata dropped, PNG); "
    f"resize so the longest edge is {CANVAS_PX} px, short edge nearest integer (ties up, minimum 1); "
    "exact area-overlap integer weights, one final round-half-up (no intermediate rounding); "
    f"centre on a {CANVAS_PX} x {CANVAS_PX} canvas filled with RGB {FILL_RGB} (the model's normalisation mean); "
    f"lay out as a patch-major uint8 tensor ({CANVAS_PX // PATCH_PX} x {CANVAS_PX // PATCH_PX} patches of "
    f"{PATCH_PX} x {PATCH_PX} x 3); odd padding puts the extra pixel on the right/bottom. "
    "This RGB8 tensor has no model-specific plane padding; the future prover adds zero padding. "
    "Normalisation and the patch convolution belong inside the future proof. "
    "Binding: the run's hidden input endpoint (design L3); the app keeps a salted commitment to the tensor.")


@dataclass
class TextItem:
    text: str
    kind: str = field(default="text", init=False)


@dataclass
class ImageItem:
    path: Path                        # the lossless master PNG
    sha256: str                       # of the master (private: an unsalted hash of content)
    mime: str
    bytes: int
    width: int | None = None
    height: int | None = None
    canvas_sha256: str | None = None  # of the canonical tensor (private)
    kind: str = field(default="image", init=False)


class ImageRefused(ValueError):
    pass


def lossless_master(raw: bytes) -> tuple[bytes, int, int]:
    """decode once, EXIF orientation applied, RGB8, no metadata -> PNG bytes"""
    from PIL import Image, ImageOps

    try:
        with Image.open(io.BytesIO(raw)) as im:
            if im.width < 1 or im.height < 1 or im.width * im.height > MAX_PIXELS:
                raise ImageRefused("image dimensions out of range")
            im.load()
            im = ImageOps.exif_transpose(im)
            if getattr(im, "is_animated", False):
                im.seek(0)                  # the first frame only (an animated GIF is not a video post)
            rgb = im.convert("RGB")
    except Exception as e:
        raise ImageRefused(f"not a decodable image ({type(e).__name__})")
    if rgb.width < 1 or rgb.height < 1 or rgb.width * rgb.height > MAX_PIXELS:
        raise ImageRefused("image dimensions out of range")
    out = io.BytesIO()
    rgb.save(out, "PNG", optimize=False)
    return out.getvalue(), rgb.width, rgb.height


def canonical_canvas(master_png: bytes):
    """the 224 x 224 letterboxed canvas (a PIL image) of the master"""
    from PIL import Image

    with Image.open(io.BytesIO(master_png)) as im:
        if im.format != "PNG" or im.mode != "RGB" or getattr(im, "is_animated", False):
            raise ImageRefused("canonical input must be a lossless, single-frame RGB8 PNG master")
        try:
            if im.width * im.height > MAX_PIXELS:
                raise ValueError("image dimensions out of range")
            raw = letterbox_rgb8(im.tobytes(), im.width, im.height)
        except ValueError as e:
            raise ImageRefused(str(e)) from e
        return Image.frombytes("RGB", (CANVAS_PX, CANVAS_PX), raw)


def canonical_tensor(canvas) -> bytes:
    """patch-major uint8 bytes: for each patch row, patch column: channel-major 14 x 14 planes"""
    if canvas.mode != "RGB" or canvas.size != (CANVAS_PX, CANVAS_PX):
        raise ImageRefused("expected a 224 x 224 RGB8 canvas")
    return patch_tensor(canvas.tobytes())


def image_commitment(salt: bytes, tensor: bytes) -> str:
    """the app's salted commitment to the canonical tensor:
    SHA-256(IMAGE_DOMAIN || salt_32 || u64-be len || tensor), with the spec in the domain."""
    if len(salt) != 32:
        raise ValueError("the salt is 32 bytes")
    return hashlib.sha256(IMAGE_DOMAIN + salt + struct.pack(">Q", len(tensor)) + tensor).hexdigest()
