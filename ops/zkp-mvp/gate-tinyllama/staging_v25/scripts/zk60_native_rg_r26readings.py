#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02] Gate round 26: the moved source pins READ, r19b ->
HEAD, wired into the pin classification (`zk60_native_rg_w16.classify_pins`),
and finding F-B1's backend rule.

THE READINGS.  Two independent readers read every source pin that moved since
frozen-r19b (the tree v24 last read) hunk by hunk against HEAD 8b78aabd:

  * the RUN-LEVEL reader, `results/zk60_gate_tinyllama_20261017/round26/
    READINGS_R26_RUN.json` (run, wire, capture and I/O pins; also the older
    dd81ab4f digests the four D60 bundles carry for five files);
  * the BLOCK-LEVEL reader, `.../round26/READINGS_R26_BLOCK.json` (block prover
    and verifier pins, zkp-core, gpu/mod.rs; also shape.rs at the W16R2
    re-check bundles' 3b78b725).

Both found every pin safe.  `R26_READINGS` below is their
`wiring_w16_readings_style` tables in the existing `*_READINGS` style, keyed by
(file, the digest's first 12 hex).  Each value carries the FULL SHA-256 the
reading names; a pin is read only when its digest EQUALS it (a 48-bit prefix
alone never reads a pin, so a file crafted to share a prefix stays UNREAD).
Then: the reading's scope, who read it, a one-line summary, and the pointer
to the record.

`.../round26/READINGS_R26_WIRING.json` adds three entries the round-26 wiring
read itself: `run_capture.rs` after this round's F-B1 change (on top of the
run-level reader's cbb78dc0), and the two Metal backend files at the CPU-PATH
scope only.  [2026-11-02, v25 freeze fixes, FR25-13] All three were checked
independently in commit 748fe707 (`.../round26/READINGS_R26_WIRING_CHECK.md`,
read-only, every digest re-hashed: SAFE at their scope), so their reader is
now that check (`WIRING_CHECKED`), not SELF_READ.  The scope is unchanged:
`metal.rs` and `metal_kernels.metal` stay CPU-PATH only (the check did not
read the device code), so a GPU-made bundle is still refused.

F-B1 (Low, the block reader).  `src/gpu/metal.rs` and
`src/gpu/metal_kernels.metal` compute receipt bytes when a run proves on the
GPU (`HL_GPU=1`: the hiding coset encoding, the column leaves, the opened
columns, the message half of every clear vector, the device sumcheck rounds)
and had no source pin.  Since this round the capture pins both and its
manifest records `proved_on_gpu` (= `gpu::enabled()`, the switch every device
path is gated on).  The rule here (`gpu_backend`):

  * `proved_on_gpu` absent (every bundle written before the fix, the four D60
    bundles among them) -> REFUSED as evidence: the backend is UNKNOWN;
  * `proved_on_gpu` true -> REFUSED while either Metal file has no FULL
    reading at its pinned digest (none exists: F-B1 read the privacy-relevant
    device paths only), or is not pinned;
  * `proved_on_gpu` false -> admissible; the Metal pins then need a reading of
    at least the CPU-PATH scope (with `gpu::enabled()` false metal.rs only
    answers `enabled()` / `label()` and the kernel source is never compiled).

A refused backend keeps the record below PASS (`PINS.ok` false), exactly as an
UNREAD pin does, with the reason in the record.  NOTHING HERE IS A PRIVACY
STATEMENT OR AN ACCEPTANCE.
"""

from __future__ import annotations

R26_DIR = "results/zk60_gate_tinyllama_20261017/round26/"
R26_RUN = R26_DIR + "READINGS_R26_RUN.json"
R26_BLOCK = R26_DIR + "READINGS_R26_BLOCK.json"
R26_WIRING = R26_DIR + "READINGS_R26_WIRING.json"
# FR25-13: the independent check of the three wiring readings (commit 748fe707)
R26_WIRING_CHECK = R26_DIR + "READINGS_R26_WIRING_CHECK.md"
R26_WIRING_CHECK_SHA256 = "3c3dae4a7504ed17b91630d3d8cce224c123f3fe121a1c7b46f10ca4893b0670"
R26_WIRING_CHECK_COMMIT = "748fe7072c490b942b9535771345fc921758c27b"

FULL = "full"
CPU_PATH = "cpu-path"
RUN_READER = "run-level reader (independent)"
BLOCK_READER = "block-level reader (independent)"
# no entry carries SELF_READ since FR25-13; the label stays defined so that a
# future self-read entry is named as one (and is then owed a check: the D55
# driver keeps such a record below D55-PASS, FR25-04)
SELF_READ = "SELF-READ by the round-26 wiring (independent check owed at the v25 freeze review)"
WIRING_CHECKED = ("round-26 wiring reading, independently checked (READINGS_R26_WIRING_CHECK.md, commit 748fe707, "
                  "sha256 3c3dae4a; read-only, every digest re-hashed)")

_D60 = "dd81ab4f (the four D60 bundles): the HEAD reading less commit ed519548's F3 / F4 / F7 / F8 and text hunks; no capture byte differs"

# (file, first 12 hex) -> (full sha256, scope, reader, one-line summary, pointer)
R26_READINGS = {
    # ------------------------------------------------ the run-level reader
    ("src/private_block/run.rs", "0a8f261578cb"): (
        "0a8f261578cbff74161021f9802e2fabc4492c609e29ea4147734272a677b441", FULL, RUN_READER,
        "HEAD: D60's registry of the twelve D55 run profiles (marker + base) and `mod fork`; a #[cfg(test)] W16 run "
        "identity; D60 F4's no-follow / non-blocking reader opens; header, stage order, absorbs, tags and openings unchanged",
        R26_RUN + " readings['src/private_block/run.rs']"),
    ("src/private_block/run.rs", "604b65b1e52b"): (
        "604b65b1e52b02ef5f68420a50971701b5ea149605a45147e6c39f226885ff73", FULL, RUN_READER, _D60,
        R26_RUN + " readings['src/private_block/run.rs']"),
    ("src/private_block/run_fork.rs", "e2cb63282a17"): (
        "e2cb63282a177361b39d7d7216a269638c6759410087de7c8e2aa7b96b024c9e", FULL, RUN_READER,
        "HEAD, NEW, read in full (1,698 lines): the D55 commit / fork / join prover and verifier and its frames; the join "
        "absorbs only words the verifier computes; L + 1 fresh OS generators; no frame carries an IO claim",
        R26_RUN + " readings['src/private_block/run_fork.rs']"),
    ("src/private_block/run_fork.rs", "e7b58ff765f8"): (
        "e7b58ff765f87cb92bcf5d4f1690e0ebf69ffe05fdb34e225829726be268837a", FULL, RUN_READER, _D60,
        R26_RUN + " readings['src/private_block/run_fork.rs']"),
    ("src/private_block/run_fork_wire.rs", "08d93ecfdff4"): (
        "08d93ecfdff450a364d0141fa9d0d32f56250f226cbef7361b5ebc178a83f927", FULL, RUN_READER,
        "HEAD, NEW, read in full (332 lines): the head, fork and tail frames; every field a root, a masked slot proof, a "
        "hiding opening at Q (MASK_Q for M) or a position tag; no field kind a D12a segment lacks",
        R26_RUN + " readings['src/private_block/run_fork_wire.rs']"),
    ("src/private_block/run_fork_wire.rs", "a2dbc6f12410"): (
        "a2dbc6f1241091e799572e75a3e8890a5a66a45ed2533bc1b8cad23a095244b8", FULL, RUN_READER, _D60,
        R26_RUN + " readings['src/private_block/run_fork_wire.rs']"),
    ("src/private_block/run_capture.rs", "cbb78dc04ac5"): (
        "cbb78dc04ac5ca62e56318ae6b2e844666ef3016e03a774e81d7e3d6dc569135", FULL, RUN_READER,
        "HEAD (test-only module): the D55 fork-run and registered-D55 bundle writers, the W16 statement-table label, M's "
        "column count, six more pins; nothing on `not_in_a_capture` is written; ALLOWED_KEYS unchanged",
        R26_RUN + " readings['src/private_block/run_capture.rs']"),
    ("src/private_block/run_capture.rs", "5d5fdfccb7a6"): (
        "5d5fdfccb7a6c9d654668c75e0e5a01792f7c8420d33fad437bb10e5ec61fea9", FULL, RUN_READER, _D60,
        R26_RUN + " readings['src/private_block/run_capture.rs']"),
    ("src/private_block/wire.rs", "b4377c6eddab"): (
        "b4377c6eddabbecc2ca2b891380c365a647628109aacbbf1da1f2035913b7af2", FULL, RUN_READER,
        "HEAD: M's frame constants from zk.rs (value-identical) and M's opened-column count = MASK_Q (D59); `mod fork`; "
        "every pre-W16R2 profile's frames byte for byte r19b's",
        R26_RUN + " readings['src/private_block/wire.rs']"),
    ("src/private_block/hash_domain.rs", "a777ebd07941"): (
        "a777ebd0794131bcb3ba5c1bb2e6c1ea4a392cc111336ab3bffd12dff6cbb0e9", FULL, RUN_READER,
        "HEAD: `path_labels` compiled in production for ForkRun::census (label names and lengths, a refusal guard); no "
        "absorb, no byte",
        R26_RUN + " readings['src/private_block/hash_domain.rs']"),
    ("src/private_block.rs", "7ec8b8552ea5"): (
        "7ec8b8552ea59035c78cc91416bd2dabb18348894f9374ef9b2cca92de3c0cb7", FULL, RUN_READER,
        "HEAD: module declarations only (range16; slot_ir / metal_slot under gpu-metal; three #[cfg(test)] modules); no "
        "item, absorbed word or ExpectedIo / IoSpec byte moves",
        R26_RUN + " readings['src/private_block.rs']"),
    ("src/private_block/trained_block.rs", "9909e8835a15"): (
        "9909e8835a1507fb2c6e120880e736f2aa62e0f9abc9d91101aef3931705e5b4", FULL, RUN_READER,
        "HEAD: D60's stack-prove / stack-verify --d55-workers over the registered D55 profile, fail-closed admission and "
        "the F3 marker; a D12a statement renders byte for byte as before",
        R26_RUN + " readings['src/private_block/trained_block.rs']"),
    ("src/private_block/trained_block.rs", "4d1e24bd98b0"): (
        "4d1e24bd98b06bdcb0ebd58196f848856e5217c37fb46d189cc98f7128997604", FULL, RUN_READER, _D60,
        R26_RUN + " readings['src/private_block/trained_block.rs']"),
    ("src/private_block/plane_index.rs", "702fa81a94ae"): (
        "702fa81a94aec18dc5df6b2215945f7fb841478cee68d8cd74c87087c7ad64a8", FULL, RUN_READER,
        "HEAD (test-only module): W16 plane-index additions switched on only at a W16 layout; at every R13 / legacy layout "
        "the table is r19b's byte for byte",
        R26_RUN + " readings['src/private_block/plane_index.rs']"),
    ("src/private_block/tied_tables.rs", "4b8f215c04d7"): (
        "4b8f215c04d7093fa10adb335a14450a37ef0b371f9bd4ece41feafa181a4050", FULL, RUN_READER,
        "HEAD: D60 F4, `regular()` opens through run::open_nofollow_nonblock; the public, pin-authenticated tables unchanged",
        R26_RUN + " readings['src/private_block/tied_tables.rs']"),
    ("src/private_block/token_io/load.rs", "56bb29a4d955"): (
        "56bb29a4d9550f0d614594c847499d94d466f312ceb0a186936dd80c8ab1f282", FULL, RUN_READER,
        "HEAD: D60 F4, the token-table reader opens through run::open_nofollow_nonblock; public tables authenticated after "
        "the read as before",
        R26_RUN + " readings['src/private_block/token_io/load.rs']"),
    ("src/private_block/token_io/classify_run.rs", "44550938378e"): (
        "44550938378ee273f7a70d45636f0f1ec382fb11033d6a7fdc3a37953da0df1e", FULL, RUN_READER,
        "HEAD (classifier pin): HL_PB_TIMING-gated diagnostics and write-only phase marks; no absorb, draw, opening or byte "
        "moves",
        R26_RUN + " readings['src/private_block/token_io/classify_run.rs']"),
    # ------------------------------------------------ the block-level reader
    ("src/private_block/protocol.rs", "6f4d60f5d7fe"): (
        "6f4d60f5d7fef8fad6a69ab7f78cc06ff3a8f947c8bac98d5bb01ed22b7af73c", FULL, BLOCK_READER,
        "HEAD: the W16 histograms and helpers are new hiding-committed A / H rows reached only through masked claims; the "
        "mask and zero-sum rows are the same draws (fill_fp); audit_claims, check_opening_challenges, pcs_params_at, "
        "endpoint_pcs_params, transcript and verify_core byte-identical to r19b",
        R26_BLOCK + " readings['src/private_block/protocol.rs']"),
    ("src/private_block/argument.rs", "86c9941de199"): (
        "86c9941de1996b555c90fcb79b24c8682651df1ff24efcdff0ff0238ea50e77b", FULL, BLOCK_READER,
        "HEAD: outside `define` (whose text is byte-identical to r19b's repaired definition, read for the D60 gate: "
        "zk60_native_rg_d55r13.ARGUMENT_RS_READING) value-identical table builders, the extension-round mask values and "
        "the Metal seam on a twin transcript (decline -> CPU)",
        R26_BLOCK + " readings['src/private_block/argument.rs']"),
    ("src/private_block/layout.rs", "171656f83ebe"): (
        "171656f83ebeb009573a81fd1c464d4b9173f3c6400fd93942fd70ca93677934", FULL, BLOCK_READER,
        "HEAD: the W16 A / H plane lists (refused unless equal to the shape's counts), the range helpers in the value-0 "
        "LogUp sum claim, the lookup tag type (U8 at every legacy / R13 lookup)",
        R26_BLOCK + " readings['src/private_block/layout.rs']"),
    ("src/private_block/shape.rs", "dce667f98b35"): (
        "dce667f98b350c4ce2c841ce8c1308a8101e29b8106733ac16439945f5c6001a", FULL, BLOCK_READER,
        "HEAD: the W16 / W16R2 registries and counts and D59's fixed rate-1/2, Q = pads = 260 geometry (refused otherwise); "
        "every R13 / legacy profile keeps rate 1/4 and Q = COL_CHECKS",
        R26_BLOCK + " readings['src/private_block/shape.rs']"),
    ("src/private_block/shape.rs", "3b78b7255ded"): (
        "3b78b7255ded2e1ebd17fa06072959bfaa34517c444ad35b114382f47583553d", FULL, BLOCK_READER,
        "2196592d (the W16R2 re-check bundles): the HEAD reading; differs from dce667f9 by one comment block",
        R26_BLOCK + " readings['src/private_block/shape.rs']['also_read']"),
    ("src/private_block/pad.rs", "9a28b306667c"): (
        "9a28b306667c5ee566d272198d5a32177ad6a179daf62c51649a79b4b5224c51", FULL, BLOCK_READER,
        "HEAD: the padding-position rule for the range sub-planes and their helpers; no claim, opening or PCS pad",
        R26_BLOCK + " readings['src/private_block/pad.rs']"),
    ("src/private_block/argument_accuracy.rs", "29a501d03b6f"): (
        "29a501d03b6f7a3455f0b191baf09ea3fd1854da30a0854f1cf0b3032cdb0763", FULL, BLOCK_READER,
        "HEAD: the W16 relations of the seven redefined slots; public tables are functions of the shape, public block data "
        "and challenges; private tables only through masked claims",
        R26_BLOCK + " readings['src/private_block/argument_accuracy.rs']"),
    ("src/private_block/accuracy_act.rs", "08b88855f522"): (
        "08b88855f522c54e0d169815ef756fe56b3195fec79f25d664e846e1087d1b5f", FULL, BLOCK_READER,
        "HEAD: parallel / fused forms of the ACT3 histogram, queries and denominators; equal values",
        R26_BLOCK + " readings['src/private_block/accuracy_act.rs']"),
    ("src/private_block/accuracy_fold.rs", "d260dd26686b"): (
        "d260dd26686b46137544c22d767c9dbff5d2510f6dac75874217e0939e0a9b1b", FULL, BLOCK_READER,
        "HEAD: a parallel i8::MIN scan of the public weights",
        R26_BLOCK + " readings['src/private_block/accuracy_fold.rs']"),
    ("src/private_block/accuracy_layout.rs", "ad5214dee4ab"): (
        "ad5214dee4ab17ad39e1378a54f7d8c0aa49b56e8cf185ac84c9ffe8390b97be", FULL, BLOCK_READER,
        "HEAD: the W16 allocation and lookups; Lk::u8 everywhere else",
        R26_BLOCK + " readings['src/private_block/accuracy_layout.rs']"),
    ("src/private_block/witness_accuracy.rs", "9c66f7622541"): (
        "9c66f7622541b443c395baceaef8b4f01b00b85d1f3d72ad287c40ce4413b573", FULL, BLOCK_READER,
        "HEAD: the W16 witness decomposition (private values; static refusal strings)",
        R26_BLOCK + " readings['src/private_block/witness_accuracy.rs']"),
    ("src/private_block/range16.rs", "62061f62c9f9"): (
        "62061f62c9f96a162fd8eaf5d3ed53928bbfc73c6dad640ceee7603e25899466", FULL, BLOCK_READER,
        "HEAD, NEW, read in full: W16's tags, the public range / support tables (functions of the shape and gamma) and the "
        "lookup constructors; the multiplicities are private A planes",
        R26_BLOCK + " readings['src/private_block/range16.rs']"),
    ("src/private_block/slot_ir.rs", "8f9e283173ee"): (
        "8f9e283173ee989507a737f02d4cc63210058cee86bab9758e0d76c815e31d59", FULL, BLOCK_READER,
        "HEAD, compiled under gpu-metal now, so read in full: the IR, interpreter and builder on the twin transcript only; "
        "no witness access, absorb, file, env, print or ZkRng (F-B2: the module doc is stale)",
        R26_BLOCK + " readings['src/private_block/slot_ir.rs']"),
    ("src/private_block/slot_ir_accuracy.rs", "25c08bb4c951"): (
        "25c08bb4c951a47dac928b6abd1c0827249b5ff4ca75887fd7e0be3db9c19e65", FULL, BLOCK_READER,
        "HEAD, NEW, read in full: the accuracy-stack IR (R13 and W16); twin transcript only; public coefficients",
        R26_BLOCK + " readings['src/private_block/slot_ir_accuracy.rs']"),
    ("src/private_block/metal_slot.rs", "5ced3891eff3"): (
        "5ced3891eff3455121a0ade1bed614f6beb2a7852433cc4250d1e950bc6eaceb", FULL, BLOCK_READER,
        "HEAD, NEW, read in full (gpu-metal only): MSL generation with the coefficient values in a buffer, the runtime guard "
        "on a local splitmix stream; no witness- or challenge-dependent host-visible output",
        R26_BLOCK + " readings['src/private_block/metal_slot.rs']"),
    ("../zkp-core/src/merkle.rs", "6b66c0bcf200"): (
        "6b66c0bcf20042373794b30c1d04b7340163ae3e93117ed19166c593ebe819a7", FULL, BLOCK_READER,
        "HEAD: a rayon task split only, the same tree (agrees with W16_READINGS)",
        R26_BLOCK + " readings['../zkp-core/src/merkle.rs']"),
    ("../zkp-core/src/mle.rs", "ed7f8849f48d"): (
        "ed7f8849f48df402c08b0a74a8119a9eff9aeecf4535847bbeceafa93459cebd", FULL, BLOCK_READER,
        "HEAD: the eq-table threshold and a deferred integer column fold of the public weights; the same values (agrees "
        "with W16_READINGS)",
        R26_BLOCK + " readings['../zkp-core/src/mle.rs']"),
    ("../zkp-core/src/pcs.rs", "856929b34333"): (
        "856929b343335f44638f44d577af4808ce8efc3c4fae44634160efcf6876d224", FULL, BLOCK_READER,
        "HEAD: device fold batching of the same linear map; the pad half stays host-computed (agrees with W16_READINGS)",
        R26_BLOCK + " readings['../zkp-core/src/pcs.rs']"),
    ("../zkp-core/src/pcs/backend.rs", "4f03047ac467"): (
        "4f03047ac467bbb0a6c2c26341f414846577fee44e29a6c8f01d53f78c55b462", FULL, BLOCK_READER,
        "HEAD: a batching hint with default 4 (agrees with W16_READINGS)",
        R26_BLOCK + " readings['../zkp-core/src/pcs/backend.rs']"),
    ("../zkp-core/src/rng.rs", "f6728bd2d520"): (
        "f6728bd2d5208bb5b81f999d59baae12eb760a27811bdd2e0a5c309beba98aa2", FULL, BLOCK_READER,
        "HEAD: `fill_fp` reproduces the fp() stream and state exactly; the generator's construction and entropy source "
        "unchanged (agrees with W16_READINGS)",
        R26_BLOCK + " readings['../zkp-core/src/rng.rs']"),
    ("../zkp-core/src/transcript.rs", "e766e9e14304"): (
        "e766e9e14304a0d58bd17937f2afad490e0cc29e8c27094a0e8f14a96e8e134e", FULL, BLOCK_READER,
        "HEAD: two read-only accessors of public state (agrees with W16_READINGS)",
        R26_BLOCK + " readings['../zkp-core/src/transcript.rs']"),
    ("src/gpu/mod.rs", "d7812f7d9404"): (
        "d7812f7d9404b55963387a9f40270fbdd871f8b6c09378116967e5568643c4c6", FULL, BLOCK_READER,
        "HEAD: the Metal backend seam behind gpu-metal (host-drawn pads and salts, hiding coset encode on the device, "
        "decline -> CPU), +106 / -5 in 5 hunks (F-B4); the backend it reaches is metal.rs (F-B1)",
        R26_BLOCK + " readings['src/gpu/mod.rs']"),
    # ------------------------------------------------ the wiring's own, independently checked (FR25-13)
    ("src/private_block/run_capture.rs", "10b6d3be860c"): (
        "10b6d3be860c73cd257e4b6b040b0351f10b993d8b1d1fdb5775057b71ef21c7", FULL, WIRING_CHECKED,
        "(test-only module) cbb78dc0 (the run-level reading) + round 26's F-B1 diff: metal.rs and metal_kernels.metal "
        "appended to SHARED_SOURCE_FILES, `proved_on_gpu` (= gpu::enabled()) in both manifest writers and on "
        "ALLOWED_KEYS, the M26 pin comment corrected; no other byte (check: SAFE; W-1 Medium latent, W-2 Low)",
        R26_WIRING + " readings['src/private_block/run_capture.rs']; checked in " + R26_WIRING_CHECK + " Pin 1"),
    ("src/gpu/metal.rs", "a96882bcc671"): (
        "a96882bcc6716deedd37f56ba3846724a015c232f84a6d6e26f08667593a121d", CPU_PATH, WIRING_CHECKED,
        "CPU PATH ONLY: with gpu::enabled() false metal.rs is reached only through enabled() / label(), which return "
        "before ctx() unless HL_GPU=1, and every device entry is gated by gpu::enabled() at its caller; the device paths "
        "are F-B1's (privacy-relevant paths read, no leak) -- NOT a full reading (check: SAFE for receipt bytes on the "
        "CPU path; W-3 Low)",
        R26_WIRING + " readings['src/gpu/metal.rs']; checked in " + R26_WIRING_CHECK + " Pin 2"),
    ("src/gpu/metal_kernels.metal", "be9682364115"): (
        "be9682364115ea8d94a2db6bfd68cc2ec6585c92448b1548813ef82a565b3b88", CPU_PATH, WIRING_CHECKED,
        "CPU PATH ONLY: include_str! into metal.rs's SRC (:31), compiled to a device library only inside ctx() "
        "(newLibraryWithSource), so never compiled or run when gpu::enabled() is false -- NOT read as kernel code "
        "(check: SAFE on the CPU path)",
        R26_WIRING + " readings['src/gpu/metal_kernels.metal']; checked in " + R26_WIRING_CHECK + " Pin 3"),
}

# F-B1: the files that compute receipt bytes only on the GPU path
GPU_BACKEND_SOURCES = ("src/gpu/metal.rs", "src/gpu/metal_kernels.metal")


def reading_for(f: str, sha256: str, proved_on_gpu=None):
    """the R26 reading of pin (f, sha256), or None.  The digest must EQUAL the
    reading's full SHA-256.  A CPU-PATH reading reads the pin only on a bundle
    whose manifest says `proved_on_gpu: false`."""
    r = R26_READINGS.get((f, sha256[:12]))
    if r is None or r[0] != sha256:
        return None
    full, scope, reader, summary, pointer = r
    if scope == CPU_PATH and proved_on_gpu is not False:
        return None
    return {"sha256": full[:12], "scope": scope, "reader": reader, "summary": summary, "pointer": pointer,
            "self_read": reader == SELF_READ}


def cpu_path_only(f: str, sha256: str) -> bool:
    r = R26_READINGS.get((f, sha256[:12]))
    return r is not None and r[0] == sha256 and r[1] == CPU_PATH


_MISSING = object()


def gpu_backend(manifest: dict) -> dict:
    """F-B1: refuse a bundle that proved on the GPU while the Metal backend
    has no FULL reading, and a bundle that does not say (`proved_on_gpu`
    absent) as UNKNOWN"""
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    v = manifest.get("proved_on_gpu", _MISSING)
    srcs = {}
    for f in GPU_BACKEND_SOURCES:
        d = pins.get(f)
        r = R26_READINGS.get((f, d[:12])) if d else None
        srcs[f] = {"pinned": d[:12] if d else None,
                   "reading_scope": (r[1] if r is not None and r[0] == d else None)}
    refused = None
    if v is _MISSING:
        refused = ("UNKNOWN PROVER BACKEND: the manifest does not record `proved_on_gpu` (a bundle written before gate "
                   "round 26's F-B1 fix). Under HL_GPU=1 src/gpu/metal.rs and src/gpu/metal_kernels.metal compute receipt "
                   "bytes, and neither has a full reading, so a bundle that does not say how it was proved is refused "
                   "as evidence")
    elif not isinstance(v, bool):
        refused = f"the manifest's `proved_on_gpu` is {v!r}, not a boolean"
    elif v:
        unpinned = [f for f, s in srcs.items() if s["pinned"] is None]
        unread = [f for f, s in srcs.items() if s["pinned"] is not None and s["reading_scope"] != FULL]
        if unpinned or unread:
            why = (["not pinned: " + ", ".join(unpinned)] if unpinned else []) + \
                  (["no FULL reading at the pinned digest: " + ", ".join(unread)] if unread else [])
            refused = ("GPU-MADE BUNDLE (proved_on_gpu = true), and the Metal backend is not admissible (" + "; ".join(why) + "). Under "
                       "HL_GPU=1 these files compute receipt bytes (the hiding coset encoding, the column leaves, the "
                       "opened columns, the clear vectors' message half, the device sumcheck rounds); F-B1 read only "
                       "their privacy-relevant paths. Refused until both are pinned and fully read")
    return {"what": "gate round 26 F-B1: the prover backend the manifest records (`proved_on_gpu` = gpu::enabled() in the "
                    "proving process) and the Metal backend's readings",
            "proved_on_gpu": None if v is _MISSING else v, "gpu_backend_sources": srcs,
            "admissible": refused is None, "refused": refused}
