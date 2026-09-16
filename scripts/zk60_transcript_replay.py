#!/usr/bin/env python3
"""ZK60 transcript replay: re-derive every Fiat-Shamir state and challenge of an
`ffn-v3-mr1-fresh-io-poc/2` receipt from public data and check the replay
against the captured checkpoints.

WHY. The round-22 verifier observations (`results/zk60_round22_captures/`)
record the transcript state before/after every PCS opening, the mask opening
and the two IO equality arguments, and the IO arguments' own challenges, but
NOT the six FFN sumcheck slots' challenges (their CFS mask challenge c_s and
their round challenges rho_s). This tool replays the whole verifier transcript
in Python from the receipt bytes + the expected-IO policy + the public
statement, so every challenge of the receipt is explicit, and it checks the
replay against every recorded checkpoint (state AND counter, via `next`).

INPUTS (read-only). Per capture `<sha>.receipt` (the HFFNIO/2 receipt),
`<sha>.expected` (112 policy bytes), `<sha>.json` (schema-3 observations),
and the manifest `zk60_round22_captures.json`. The prover messages absorbed
by the transcript are taken FROM THE RECEIPT; the JSON supplies the
checkpoints, the recorded challenge values and the PCS claim-group sizes,
and every message it repeats is cross-checked against the receipt.

SOURCE OF TRUTH (worktree at commit 763e308; the manifest's per-file SHA-256
of every one of these files matches this worktree, checked by this tool):

  zkp-core/src/transcript.rs
    25-30   Transcript::new: state = blake3("hashline-v1/" || domain), counter 0
    44-52   absorb(label, data): state = blake3(state || len(label) u64 LE || label
            || len(data) u64 LE || data)
    54-56   absorb_u64: absorb(label, v u64 LE)
    58-64   absorb_fp: 8-byte LE words; 66-83 absorb_fp2: 16 bytes per element
    85-94   squeeze: out = blake3(state || "squeeze" || counter u64 LE); counter += 1;
            state = out
    97-100  challenge_fp: from_u128(LE bytes[0..16]);  103-112 challenge_fp2:
            (from_u128(b[0..16]), from_u128(b[16..32]))
    114-116 challenge_fp2_vec(n);  119-131 challenge_indices(n, bound): each
            squeeze yields 4 indices (8-byte LE chunks & (bound-1))
    139-142 clone_state (the captures' `next` = clone_state(tr).challenge_fp2())
  zkp-core/src/field.rs
    10 P = 2^64 - 2^32 + 1;  15 NONRESIDUE = 7;  36-38 from_u128 = v mod p;
    88-90 Fp::to_bytes = u64 LE;  163 Fp2 mul (c0 = ac + 7 bd, c1 = ad + bc);
    193-198 Fp2::to_bytes = c0 LE || c1 LE
  hashline/src/zk_ffn_fresh_io.rs
    12 PROFILE;  13 MAGIC "HFFNIO\\0\\x02";  76-85 ExpectedIo::to_bytes (112 bytes)
    138-146 transcript(): new(PROFILE); absorb "expected-IO" policy; absorb
            "parameters" b"T32/d16/f16/log_cols8/inv_rate8/Q256/two-private-seams"
    371-410 verify_arguments (per side: before-clone; absorb_u64 "io-side" i;
            9 tau; c (nonzero); absorb "io-gamma"; sumcheck::verify(gamma, 2, 10);
            absorb "io-terminals", "io-mask-eval"; after)
    412-481 verify: transcript(expected) -> verify_layer_zk_v3_with_seams(...,
            before_openings = verify_arguments) -> Input, Output openings with
            pcs_for(8) (rows 7) via check_masks (read-only) + pcs::verify_zk
    483-504 binding(): transcript(expected); absorb_statement_v3; absorb
            "actual-table" (256 x i16 LE); "public-W" root | "private-W" b"fresh";
            = receipt[8..40] (514-551 Receipt::to_bytes; 552-591 from_bytes)
  hashline/src/zk.rs
    150-163 ZkPrivacy private_set/public_set;  193-198 OutputClaim::tag
    273-286 body()/header_v3(): legacy P1 -> b"P1-v3"; P3 -> "HL-ZK/1|profile=v3|
            priv=in+act+out+weights|pub=shapes+shifts+table-digest|out=commit|model=w-root"
    373-375 MASK_LOG_MSG 9, MASK_LOG_DOM 12, MASK_Q 256
    552-585 mask_verify: theta; absorb "mask-q" (1024 Fp2); rs = 2*specs+2;
            absorb "mask-prox" (1024); idx = challenge_indices(256, 4096)
    1122-1124 pcs_params: log_cols = min(params.log_cols, min_log)
    2002-2063 ZkLayoutV3::with_masks / with_io (log_n = min(log_cols, log_a_min),
            log_s = max(log_n, 16), 6 table slots);  2149-2172 mask_specs_v3
    3501-3696 the verifier's transcript sequence (statement, "zk" header,
            absorb_com W, A, "M", beta/gamma/alpha, absorb_com H, gu, d, zcF, zcD,
            tab, zs);  3739 before_openings (= the IO arguments);  3742 mask_verify;
            3745-3775 W (P3: verify_zk; P1: plain pcs::verify), A, H openings
    3326-3336 build_claims_zk_v3: the P1 public-W claims (wg, wu at p3; wd at p6)
  zkp-core/src/ffn_v3/statement.rs
    76-84 Statement fields;  148-176 Layout::new;  186-194 absorb_statement
    ("profile" b"v3-widened/round", u64 "layer", "t_rows", "d", "f", "shifts-signed"
    4 x i64 LE, "act" spec name, "table" digest ascii);  199-202 absorb_com
  zkp-core/src/tables.rs
    42-47 spec_name;  62-68 eval (silu = x / (1 + exp(-x)) in f64);  78-90 the
    frozen SiLU members and digests;  103-114 int16out_generate;  117-141
    table_spec_digest_int16out;  143-150 int16out_member (digest pin)
  zkp-core/src/sumcheck.rs 135-161 verify: per round check s(0)+s(1) == claim,
    absorb "sc-round", r = challenge_fp2, claim = interpolate_eval(s, r)
  zkp-core/src/mle.rs 54-63 eq_point;  186-200 interpolate_eval (Lagrange on 0..d)
  zkp-core/src/pcs.rs 41-55 PcsParams (cols = 2^log_cols, enc_cols = cols*inv_rate);
    252-269 group_claims (first-occurrence grouping by column key);  406-456 plain
    verify (lambdas per group, prox_rho = rows, absorb "pcs-vec" per group,
    "pcs-prox", idx = challenge_indices(num_col_checks, enc_cols));  835-855
    zk_rhos;  947-988 verify_zk (same order; vectors are n + q_pad = 512 long)
  hashline/src/zk_ffn_fresh_wire.rs 10 TERMINALS;  20-45 Shape;  228-234 io_shape
    (A rows + 4, 7 A groups, mask rows + 4);  259-291 decode_layer (payload order);
    305-410 Reader (commitment 44 bytes; argument; columns; hiding; plain)
  hashline/src/zk_ffn_io_diagnostic.rs 136-200 where each before/after clone is
    taken;  272-274 the JSON "state"/"next" writer;  325-388 the export layout
  hashline/src/causal_oracle.rs 97, 150, 154-155: the fixture's statement
    (int16out_member(Silu, -3, -11), l = 0, shifts (7, 0, 14, 6)) — the same
    statement `hashline/examples/zk60_bound_ffn.rs` 14-27 verifies against
  hashline/src/zk_ffn_fresh_poc.rs 51-57 parameters() (log_cols 8, inv_rate 8,
    num_col_checks 256);  253+ check_masks (takes &Transcript: no absorb/squeeze)

WHAT IS RECONSTRUCTED VS TAKEN FROM THE CAPTURE. The statement's t_rows/d/f
and shifts come from the capture JSON (`shape`, `shifts`); the layer index,
the activation and the table member come from the capture producer's fixture
(pinned above) and are regenerated here (table + spec digest, checked against
the frozen digest pin). The receipt's 32-byte binding is the first checkpoint
and is the only thing that validates that reconstruction; on a binding
mismatch the tool reports the statement as unconfirmed and names the fields
it could not derive from the capture itself. The PCS claim-group sizes
(how many lambdas each opening draws) are taken from the JSON `groups`
(cross-checked against the manifest); the P1 public-W grouping is derived
from the claim keys (p3, p3, p6) as pcs::group_claims does.

OUTPUT. One JSON with, per capture: every challenge in transcript order
(named), `ffn_slots` = [{name, mask_slot, c, rho}] for gu, d, zc20, zc17, tab,
zs, `io_slots`, `checkpoints` = [{name, kind, ok, ...}], and `oracle_history`
= the ordered absorbs (label, byte length) and squeezes (counter, name).
Exit 0 only if every check of every capture passed; 1 on any mismatch; 2 on a
refusal (an input that cannot be parsed or a statement field that cannot be
reconstructed — reported by name, never guessed).

Hash backend: the `blake3` wheel when importable, else the pure-Python
reference in `zk60_blake3_pure.py` (force with --backend pure).
"""
import argparse
import hashlib
import json
import math
import os
import struct
import sys
import time

P = 0xFFFF_FFFF_0000_0001
NONRESIDUE = 7
PROFILE = b"hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2"
RECEIPT_MAGIC = b"HFFNIO\0\x02"
POLICY_MAGIC = b"HFFNEXP1"
POLICY_BYTES = 112
PARAMETERS = b"T32/d16/f16/log_cols8/inv_rate8/Q256/two-private-seams"
STATEMENT_PROFILE = b"v3-widened/round"
MASK_LOG_MSG = 9
MASK_LOG_DOM = 12
MASK_Q = 256
CHECKS = 256
TERMINALS = [3, 2, 10, 4, 1, 12]  # gu, d, zc20, zc17, zs, tab (wire order)
WIRE_ARG_ORDER = ["gu", "d", "zc20", "zc17", "zs", "tab"]
TRANSCRIPT_ARG_ORDER = ["gu", "d", "zc20", "zc17", "tab", "zs"]
MASK_SLOT = {"gu": 0, "d": 1, "zc20": 2, "zc17": 3, "zs": 4, "tab": 5}
SILU_SPEC_NAME = "silu-int16out-table-v3"
FROZEN_SILU_DIGEST_M3_M11 = "1001c138ce0d00f09390b36178044d72712fbdca1071467ea274dc980bd9a3f7"
PARAMS = {"log_cols": 8, "inv_rate": 8, "num_col_checks": 256}
ZERO2 = (0, 0)
ONE2 = (1, 0)


class Refusal(Exception):
    """An input that cannot be parsed or a field that cannot be reconstructed."""


# --------------------------------------------------------------------------
# hash backends
# --------------------------------------------------------------------------

def _wheel_hash():
    try:
        import blake3  # noqa: F401
    except ImportError:
        return None
    import blake3 as _b

    def h(data):
        return _b.blake3(data).digest()
    return h


def _pure_hash():
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
    from zk60_blake3_pure import blake3_hash
    return blake3_hash


def select_backend(name="auto"):
    """Returns (backend_name, hash_fn)."""
    if name == "pure":
        return "pure", _pure_hash()
    wheel = _wheel_hash()
    if name == "wheel":
        if wheel is None:
            raise Refusal("hash backend: the blake3 wheel is not importable")
        return "wheel", wheel
    if wheel is not None:
        return "wheel", wheel
    return "pure", _pure_hash()


# --------------------------------------------------------------------------
# the transcript (zkp-core/src/transcript.rs)
# --------------------------------------------------------------------------

class Transcript:
    def __init__(self, domain=None, hasher=None, state=None, counter=0, history=None):
        self.h = hasher
        if state is None:
            self.state = hasher(b"hashline-v1/" + domain)
        else:
            self.state = bytes(state)
        self.counter = counter
        self.history = history if history is not None else []

    def clone(self):
        return Transcript(hasher=self.h, state=self.state, counter=self.counter, history=[])

    def absorb(self, label, data):
        data = bytes(data)
        self.state = self.h(self.state + struct.pack("<Q", len(label)) + label + struct.pack("<Q", len(data)) + data)
        self.history.append(("absorb", label.decode("ascii"), len(data)))

    def absorb_u64(self, label, v):
        self.absorb(label, struct.pack("<Q", v))

    def absorb_fp2(self, label, vals):
        flat = []
        for c0, c1 in vals:
            flat.append(c0)
            flat.append(c1)
        self.absorb(label, struct.pack("<%dQ" % len(flat), *flat))

    def squeeze(self, name):
        out = self.h(self.state + b"squeeze" + struct.pack("<Q", self.counter))
        self.history.append(("squeeze", self.counter, name))
        self.counter += 1
        self.state = out
        return out

    def challenge_fp2(self, name):
        b = self.squeeze(name)
        return (int.from_bytes(b[:16], "little") % P, int.from_bytes(b[16:], "little") % P)

    def challenge_fp2_vec(self, n, name):
        return [self.challenge_fp2("%s[%d]" % (name, i)) for i in range(n)]

    def challenge_indices(self, n, bound, name):
        assert bound & (bound - 1) == 0
        out = []
        while len(out) < n:
            b = self.squeeze("%s{%d..}" % (name, len(out)))
            for k in range(4):
                if len(out) == n:
                    break
                out.append(int.from_bytes(b[8 * k:8 * k + 8], "little") & (bound - 1))
        return out

    def next_challenge(self):
        """The captures' `next`: one squeeze from a clone (state + counter)."""
        return self.clone().challenge_fp2("next")


# --------------------------------------------------------------------------
# field helpers (zkp-core/src/field.rs, mle.rs)
# --------------------------------------------------------------------------

def f2add(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def f2sub(a, b):
    return ((a[0] - b[0]) % P, (a[1] - b[1]) % P)


def f2mul(a, b):
    return ((a[0] * b[0] + NONRESIDUE * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def f2mul_base(a, k):
    return (a[0] * k % P, a[1] * k % P)


def finv(x):
    return pow(x, P - 2, P)


def interpolate_eval(vals, x):
    d = len(vals)
    acc = ZERO2
    for i in range(d):
        num = ONE2
        den = 1
        for j in range(d):
            if i == j:
                continue
            num = f2mul(num, f2sub(x, (j % P, 0)))
            den = den * ((i - j) % P) % P
        acc = f2add(acc, f2mul_base(f2mul(vals[i], num), finv(den)))
    return acc


def eq_point(r, s):
    assert len(r) == len(s)
    acc = ONE2
    for a, b in zip(r, s):
        acc = f2mul(acc, f2add(f2mul(a, b), f2mul(f2sub(ONE2, a), f2sub(ONE2, b))))
    return acc


# --------------------------------------------------------------------------
# the statement (zkp-core/src/tables.rs, ffn_v3/statement.rs)
# --------------------------------------------------------------------------

def silu_int16out_generate(e_in, e_out):
    out = []
    scale_in = math.ldexp(1.0, e_in)
    scale_out = math.ldexp(1.0, e_out)
    for i in range(256):
        g = i - 128
        x = g * scale_in
        y = x / (1.0 + math.exp(-x))
        v = math.floor(y / scale_out + 0.5)
        out.append(max(-32767, min(32767, v)))
    return out


def silu_table_spec_digest(e_in, e_out, table):
    parts = [
        '{"function":"%s","input":{"width":8,"scale_exp":%d,"signed":true},'
        '"output":{"width":16,"scale_exp":%d,"signed":true},'
        '"rounding":"y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), -32767, 32767)","table":['
        % (SILU_SPEC_NAME, e_in, e_out)
    ]
    parts.append(",".join("[%d,%d]" % (i - 128, s) for i, s in enumerate(table)))
    parts.append("]}")
    return hashlib.sha256("".join(parts).encode("ascii")).hexdigest()


def reconstruct_statement(js):
    """Returns (statement dict, provenance dict). Raises Refusal naming the field."""
    missing = []
    shape = js.get("shape") or {}
    for k in ("t", "d", "f"):
        if not isinstance(shape.get(k), int):
            missing.append("shape.%s" % k)
    shifts = js.get("shifts")
    if not (isinstance(shifts, list) and len(shifts) == 4 and all(isinstance(s, int) for s in shifts)):
        missing.append("shifts")
    if missing:
        raise Refusal("statement: cannot reconstruct %s from the capture" % ", ".join(missing))
    for s in shifts:
        if not (-8 <= s <= 16):
            raise Refusal("statement: shift %d outside the supported window -8..=16" % s)
    table = silu_int16out_generate(-3, -11)
    digest = silu_table_spec_digest(-3, -11, table)
    if digest != FROZEN_SILU_DIGEST_M3_M11:
        raise Refusal("statement: regenerated table digest %s != frozen pin %s (platform libm drift)"
                      % (digest, FROZEN_SILU_DIGEST_M3_M11))
    st = {
        "l": 0,
        "t_rows": shape["t"],
        "d": shape["d"],
        "f": shape["f"],
        "shifts": tuple(shifts),
        "act": SILU_SPEC_NAME,
        "table": table,
        "table_digest": digest,
    }
    prov = {
        "t_rows,d,f": "capture json `shape`",
        "shifts": "capture json `shifts`",
        "l": "fixture pin (causal_oracle.rs:150; zk60_bound_ffn.rs:18) — confirmed only by the binding checkpoint",
        "act": "fixture pin (causal_oracle.rs:155) — confirmed only by the binding checkpoint",
        "table,table_digest": "int16out_member(Silu, -3, -11) regenerated (tables.rs:103-150), digest == frozen pin",
    }
    return st, prov


def layout_numbers(st):
    """Layout::new (statement.rs:148-176) + ZkLayoutV3::with_masks (zk.rs:2002-2055)."""
    t, d, f = st["t_rows"], st["d"], st["f"]
    if t & (t - 1):
        raise Refusal("statement: t_rows must be a power of two")
    log_t = t.bit_length() - 1
    log_db = min((d & -d).bit_length() - 1, 12)
    log_fb = min((f & -f).bit_length() - 1, 12)
    if log_db < 4 or log_fb < 4 or d % (1 << log_db) or f % (1 << log_fb):
        raise Refusal("statement: need >= 16 | d, f")
    nb_d = d // (1 << log_db)
    nb_f = f // (1 << log_fb)
    log_wb = log_db + log_fb
    log_a_min = log_t + min(log_db, log_fb)
    log_n = min(PARAMS["log_cols"], log_a_min)
    log_s = max(log_n, 16)
    log_wn = min(PARAMS["log_cols"], log_wb)
    w_len = 3 * nb_d * nb_f * (1 << log_wb)
    w_rows_p1 = w_len // (1 << log_wn)
    w_rows_p3 = w_rows_p1 + 2 * (2 * nb_d * nb_f) + 2 * (nb_f * nb_d) + 2
    return {
        "log_t": log_t, "log_db": log_db, "log_fb": log_fb, "nb_d": nb_d, "nb_f": nb_f,
        "log_wb": log_wb, "log_a_min": log_a_min, "log_n": log_n, "log_s": log_s,
        "n_tabs": 6, "log_wn": log_wn, "w_rows_p1": w_rows_p1, "w_rows_p3": w_rows_p3,
    }


def absorb_statement(tr, st):
    tr.absorb(b"profile", STATEMENT_PROFILE)
    tr.absorb_u64(b"layer", st["l"])
    tr.absorb_u64(b"t_rows", st["t_rows"])
    tr.absorb_u64(b"d", st["d"])
    tr.absorb_u64(b"f", st["f"])
    tr.absorb(b"shifts-signed", struct.pack("<4q", *st["shifts"]))
    tr.absorb(b"act", st["act"].encode("ascii"))
    tr.absorb(b"table", st["table_digest"].encode("ascii"))


def header_v3(privacy):
    if privacy == "P1":
        return b"P1-v3"
    return b"HL-ZK/1|profile=v3|priv=in+act+out+weights|pub=shapes+shifts+table-digest|out=commit|model=w-root"


def absorb_com(tr, label, root, rows):
    tr.absorb(label, root)
    tr.absorb_u64(label, rows)


def io_transcript(hasher, policy):
    tr = Transcript(PROFILE, hasher)
    tr.absorb(b"expected-IO", policy)
    tr.absorb(b"parameters", PARAMETERS)
    return tr


def binding_state(hasher, policy, st, privacy, public_w_root):
    tr = io_transcript(hasher, policy)
    absorb_statement(tr, st)
    tr.absorb(b"actual-table", struct.pack("<256h", *st["table"]))
    if privacy == "P1":
        tr.absorb(b"public-W", public_w_root)
    else:
        tr.absorb(b"private-W", b"fresh")
    return tr.state


# --------------------------------------------------------------------------
# the receipt (hashline/src/zk_ffn_fresh_wire.rs Reader + zk_ffn_fresh_io.rs)
# --------------------------------------------------------------------------

class Reader:
    def __init__(self, data):
        self.b = data
        self.pos = 0

    def take(self, n):
        end = self.pos + n
        if end > len(self.b):
            raise Refusal("receipt: truncated frame at offset %d" % self.pos)
        out = self.b[self.pos:end]
        self.pos = end
        return out

    def u64(self):
        return struct.unpack("<Q", self.take(8))[0]

    def words(self, n):
        end = self.pos + 8 * n
        if end > len(self.b):
            raise Refusal("receipt: truncated frame at offset %d" % self.pos)
        w = struct.unpack_from("<%dQ" % n, self.b, self.pos)
        self.pos = end
        for x in w:
            if x >= P:
                raise Refusal("receipt: noncanonical field word before offset %d" % self.pos)
        return w

    def fp2(self):
        w = self.words(2)
        return (w[0], w[1])

    def fp2_vec(self, n):
        w = self.words(2 * n)
        return [(w[2 * i], w[2 * i + 1]) for i in range(n)]

    def commitment(self, expected_rows=None):
        """root (32) || rows u64 LE || log_cols u32 LE; `expected_rows` None = read the frame's value."""
        root = self.take(32)
        rows = self.u64()
        log_cols = struct.unpack("<I", self.take(4))[0]
        if log_cols != 8 or (expected_rows is not None and rows != expected_rows):
            raise Refusal("receipt: commitment shape (rows %d, want %s; log_cols %d)" % (rows, expected_rows, log_cols))
        return {"root": root, "rows": rows, "log_cols": log_cols}

    def argument(self, rounds, degree, terms):
        claim = self.fp2()
        rs = [self.fp2_vec(degree + 1) for _ in range(rounds)]
        return {"claim": claim, "rounds": rs, "terminals": self.fp2_vec(terms)}

    def column(self, rows, depth, salted):
        j = self.u64()
        if j >= (1 << depth):
            raise Refusal("receipt: column index out of bounds")
        values = list(self.words(rows))
        salt = self.take(32) if salted else None
        path = [self.take(32) for _ in range(depth)]
        return {"index": j, "values": values, "salt": salt, "path": path}

    def hiding(self, groups, rows):
        gv = [self.fp2_vec(512) for _ in range(groups)]
        prox = self.fp2_vec(512)
        cols = [self.column(rows, 11, True) for _ in range(CHECKS)]
        return {"group_vecs": gv, "prox_vec": prox, "columns": cols}

    def plain(self, rows):
        gv = [self.fp2_vec(256) for _ in range(2)]
        prox = self.fp2_vec(256)
        cols = [self.column(rows, 11, False) for _ in range(CHECKS)]
        return {"group_vecs": gv, "prox_vec": prox, "columns": cols}


def parse_receipt(data, privacy, lay):
    if data[:8] != RECEIPT_MAGIC:
        raise Refusal("receipt: frame profile magic %r != %r" % (data[:8], RECEIPT_MAGIC))
    is_p3 = privacy == "P3"
    x = 1 if is_p3 else 0
    specs = [(lay["log_db"] + 1 + x, 2), (lay["log_fb"] + 1 + x, 2),
             (lay["log_t"] + lay["log_fb"] + 1, 4), (lay["log_t"] + lay["log_db"] + 1, 4),
             (lay["log_n"] + 1, 2), (lay["log_s"] + 1, 3)]
    mask_rows = 2 * len(specs) + 4 + 4  # io_shape: + the two seam slots' rows
    w_rows = lay["w_rows_p3"] if is_p3 else lay["w_rows_p1"]
    r = Reader(data)
    r.take(8)
    rec = {"binding": r.take(32), "specs": specs, "mask_rows": mask_rows}
    rec["w_com"] = r.commitment(w_rows)
    # The A/H row counts are read from the frame; the wire fixes them from the statement
    # (io_shape: rows[1] = a_len/a_n + 4, rows[2] = h_len/a_n) and the replay checks them
    # against the capture's layout description and commitment records.
    rec["a_com"] = r.commitment()
    a_rows = rec["a_com"]["rows"]
    rec["mask_root"] = r.take(32)
    rec["h_com"] = r.commitment()
    h_rows = rec["h_com"]["rows"]
    args = {}
    for name, (rounds, degree), terms in zip(WIRE_ARG_ORDER, specs, TERMINALS):
        args[name] = r.argument(rounds, degree, terms)
    rec["ffn"] = args
    rec["mask_open"] = {
        "q": r.fp2_vec(1024),
        "prox": r.fp2_vec(1024),
        "columns": [r.column(mask_rows, 12, True) for _ in range(CHECKS)],
    }
    if is_p3:
        rec["w_open_zk"] = r.hiding(2, w_rows)
        rec["w_open"] = None
    else:
        rec["w_open"] = r.plain(w_rows)
        rec["w_open_zk"] = None
    rec["a_open"] = r.hiding(7, a_rows)
    rec["h_open"] = r.hiding(5, h_rows)
    io_args = []
    for _ in range(2):
        gamma = r.fp2()
        rounds = [r.fp2_vec(3) for _ in range(10)]
        terminals = r.fp2_vec(2)
        mask_eval = r.fp2()
        io_args.append({"gamma": gamma, "rounds": rounds, "terminals": terminals, "mask_eval": mask_eval})
    rec["arguments"] = io_args
    rec["endpoint_open"] = [r.hiding(1, 7), r.hiding(1, 7)]
    if r.pos != len(data):
        raise Refusal("receipt: %d trailing bytes" % (len(data) - r.pos))
    return rec


# --------------------------------------------------------------------------
# capture loading and manifest checks
# --------------------------------------------------------------------------

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_capture(captures_dir, sha):
    base = os.path.join(captures_dir, sha)
    with open(base + ".json", "r") as f:
        js = json.load(f)
    with open(base + ".receipt", "rb") as f:
        receipt = f.read()
    with open(base + ".expected", "rb") as f:
        expected = f.read()
    return {"sha": sha, "json": js, "receipt": receipt, "expected": expected, "dir": captures_dir}


def check_manifest(manifest, captures_dir, source_root=None):
    """Hash checks of the triplets (and of the pinned source files when a root is given)."""
    checks = []

    def add(name, ok, detail=""):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    cases = manifest.get("captures", {}).get("cases", [])
    add("manifest.cases", len(cases) > 0, "%d cases" % len(cases))
    shas = []
    for case in cases:
        sha = os.path.basename(case["path"])[:-5]
        shas.append(sha)
        base = os.path.join(captures_dir, sha)
        for suffix, key_sha, key_len in (
            (".json", "capture_sha256", "capture_bytes"),
            (".receipt", "proof_sha256", "proof_bytes"),
            (".expected", "expected_policy_sha256", None),
        ):
            path = base + suffix
            if not os.path.exists(path):
                add("%s%s.exists" % (sha[:8], suffix), False, path)
                continue
            got = sha256_file(path)
            add("%s%s.sha256" % (sha[:8], suffix), got == case[key_sha], "%s vs %s" % (got, case[key_sha]))
            if key_len:
                size = os.path.getsize(path)
                add("%s%s.bytes" % (sha[:8], suffix), size == case[key_len], "%d vs %d" % (size, case[key_len]))
        add("%s.receipt-name" % sha[:8], case["proof_sha256"] == sha, "file name is the receipt sha256")
    if source_root:
        for rel, want in manifest.get("source_sha256", {}).items():
            path = os.path.join(source_root, rel)
            if os.path.exists(path):
                got = sha256_file(path)
                add("source.%s" % rel, got == want, "%s vs %s" % (got, want))
            else:
                add("source.%s" % rel, False, "missing at %s" % path)
    return checks, shas, cases


# --------------------------------------------------------------------------
# the replay
# --------------------------------------------------------------------------

def _fp2_list(v):
    return [[int(a), int(b)] for a, b in v]


def _fp2_json(v):
    return [int(v[0]), int(v[1])]


def _as_pairs(v):
    return [(int(a), int(b)) for a, b in v]


def replay_capture(cap, hasher, tamper=None, manifest_case=None, want_history=True):
    js = cap["json"]
    sha = cap["sha"]
    privacy = js.get("privacy")
    checks = []
    challenges = []

    def add(name, ok, kind, **detail):
        entry = {"name": name, "kind": kind, "ok": bool(ok)}
        entry.update(detail)
        checks.append(entry)
        return bool(ok)

    def checkpoint(name, tr, rec_state):
        want_state = bytes(rec_state["state"])
        want_next = (int(rec_state["next"][0]), int(rec_state["next"][1]))
        got_next = tr.next_challenge()
        ok_state = tr.state == want_state
        ok_next = got_next == want_next
        return add(name, ok_state and ok_next, "transcript", counter=tr.counter,
                   state=tr.state.hex(), want_state=want_state.hex(),
                   next=_fp2_json(got_next), want_next=_fp2_json(want_next),
                   state_ok=ok_state, next_ok=ok_next)

    def value(name, got, want):
        g = _fp2_list(got) if got and isinstance(got[0], (tuple, list)) else got
        w = _fp2_list(want) if want and isinstance(want[0], (tuple, list)) else want
        return add(name, g == w, "value")

    def named(name, v):
        challenges.append({"name": name, "value": _fp2_json(v)})
        return v

    def named_vec(name, vs):
        for i, v in enumerate(vs):
            challenges.append({"name": "%s[%d]" % (name, i), "value": _fp2_json(v)})
        return vs

    # --- preflight of the capture's identity ---
    if privacy not in ("P1", "P3"):
        raise Refusal("%s: privacy %r is not P1/P3" % (sha[:8], privacy))
    is_p3 = privacy == "P3"
    if js.get("transcript_domain", "").encode("ascii") != PROFILE:
        raise Refusal("%s: transcript_domain %r != PROFILE" % (sha[:8], js.get("transcript_domain")))
    if js.get("schema") != 3:
        raise Refusal("%s: capture schema %r != 3" % (sha[:8], js.get("schema")))
    policy = cap["expected"]
    if len(policy) != POLICY_BYTES or policy[:8] != POLICY_MAGIC:
        raise Refusal("%s: expected policy is not a %d-byte HFFNEXP1 record" % (sha[:8], POLICY_BYTES))
    add("policy.file==json", bytes(js["expected_policy"]) == policy, "input")
    add("policy.sha256==json", hashlib.sha256(policy).hexdigest() == js["expected_policy_sha256"], "input")
    add("receipt.sha256==json", hashlib.sha256(cap["receipt"]).hexdigest() == js["proof_sha256"] == sha, "input")
    add("receipt.bytes==json", len(cap["receipt"]) == js["proof_bytes"], "input")
    add("layout_digest==sha256(layout_description)",
        hashlib.sha256(js["layout_description"].encode("utf-8")).hexdigest() == js["layout_digest"], "input")
    add("field.modulus", js.get("field_modulus") == P and js.get("extension_nonresidue") == NONRESIDUE, "input")

    # --- the statement ---
    st, provenance = reconstruct_statement(js)
    lay = layout_numbers(st)
    rec = parse_receipt(cap["receipt"], privacy, lay)
    if tamper is not None:
        tamper(rec)
    desc = js["layout_description"]
    a_rows_desc = int(desc.split("A rows=")[1].split(" ")[0])
    h_rows_desc = int(desc.split("H rows=")[1].split(" ")[0])
    add("receipt.A.rows==layout_description", rec["a_com"]["rows"] == a_rows_desc, "input",
        got=rec["a_com"]["rows"], want=a_rows_desc)
    add("receipt.H.rows==layout_description", rec["h_com"]["rows"] == h_rows_desc, "input",
        got=rec["h_com"]["rows"], want=h_rows_desc)
    add("layout.n==layout_description", ("n=%d " % (1 << lay["log_n"])) in desc, "input")
    add("layout.table_slots", desc.count("\ntable tag=") == lay["n_tabs"], "input")
    add("mask.specs==derived",
        [list(s) for s in js["mask"]["specs"]] == [list(s) for s in rec["specs"]] + [[lay["log_t"] + lay["log_db"] + 1, 2]] * 2,
        "input", got=js["mask"]["specs"])

    # --- FIRST CHECKPOINT: the receipt's binding (zk_ffn_fresh_io.rs 483-504) ---
    public_w_root = rec["w_com"]["root"]
    if not is_p3:
        add("public_w.root==receipt", bytes(js["public_w"]["root"]) == public_w_root, "input")
        add("public_w.rows==receipt", js["public_w"]["rows"] == rec["w_com"]["rows"], "input")
    bind = binding_state(hasher, policy, st, privacy, public_w_root)
    binding_ok = add("binding.receipt[8:40]", bind == rec["binding"], "transcript",
                     got=bind.hex(), want=rec["binding"].hex())
    if not binding_ok:
        add("statement.unconfirmed", False, "refusal",
            fields=["l", "act", "table", "table_digest"],
            reason="the binding mismatch means the fixture-pinned statement fields are not confirmed by the receipt")

    # --- cross-check the JSON's copies of the prover messages against the receipt ---
    roles = {r["role"]: r for r in js["roles"]}
    jf = {a["name"]: a for a in js["ffn_arguments"]}
    for name in TRANSCRIPT_ARG_ORDER:
        value("json.ffn_arguments.%s.rounds==receipt" % name,
              [x for rnd in rec["ffn"][name]["rounds"] for x in rnd],
              [tuple(x) for rnd in jf[name]["rounds"] for x in rnd])
        value("json.ffn_arguments.%s.terminals==receipt" % name, rec["ffn"][name]["terminals"], _as_pairs(jf[name]["terminals"]))
    value("json.ffn_matmul_claims==receipt", [rec["ffn"]["gu"]["claim"], rec["ffn"]["d"]["claim"]], _as_pairs(js["ffn_matmul_claims"]))
    value("json.ffn_gammas==receipt",
          [rec["ffn"]["zc20"]["claim"], rec["ffn"]["zc17"]["claim"], rec["ffn"]["tab"]["claim"], rec["ffn"]["zs"]["claim"]],
          _as_pairs(js["ffn_gammas"]))
    add("json.mask.root==receipt", bytes(js["mask"]["root"]) == rec["mask_root"], "input")
    value("json.mask.q==receipt", rec["mask_open"]["q"], _as_pairs(js["mask"]["q"]))
    value("json.mask.prox==receipt", rec["mask_open"]["prox"], _as_pairs(js["mask"]["prox"]))
    add("json.mask.columns==receipt",
        [(c["index"], c["values"]) for c in js["mask"]["columns"]] == [(c["index"], c["values"]) for c in rec["mask_open"]["columns"]],
        "input")
    for i in range(2):
        ja, ra = js["io_arguments"][i], rec["arguments"][i]
        value("json.io[%d].rounds==receipt" % i, [x for rnd in ra["rounds"] for x in rnd], [tuple(x) for rnd in ja["rounds"] for x in rnd])
        value("json.io[%d].gamma,terminals,mask_eval==receipt" % i,
              [ra["gamma"]] + ra["terminals"] + [ra["mask_eval"]],
              [tuple(ja["gamma"])] + _as_pairs(ja["terminals"]) + [tuple(ja["mask_eval"])])
    role_open = {"W": rec["w_open_zk"], "A": rec["a_open"], "H": rec["h_open"],
                 "Input": rec["endpoint_open"][0], "Output": rec["endpoint_open"][1]}
    role_com = {"W": rec["w_com"], "A": rec["a_com"], "H": rec["h_com"],
                "Input": {"root": policy[48:80], "rows": 7}, "Output": {"root": policy[80:112], "rows": 7}}
    for role, jr in roles.items():
        op = role_open[role]
        add("json.%s.commitment==receipt/policy" % role,
            bytes(jr["commitment"]["root"]) == role_com[role]["root"] and jr["commitment"]["rows"] == role_com[role]["rows"], "input")
        add("json.%s.group_vectors==receipt" % role,
            len(jr["groups"]) == len(op["group_vecs"]) and all(_as_pairs(g["vector"]) == op["group_vecs"][i] for i, g in enumerate(jr["groups"])),
            "input")
        value("json.%s.proximity_vector==receipt" % role, op["prox_vec"], _as_pairs(jr["proximity_vector"]))
        add("json.%s.columns==receipt" % role,
            [(c["index"], c["values"]) for c in jr["columns"]] == [(c["index"], c["values"]) for c in op["columns"]], "input")
        if manifest_case is not None:
            mc = manifest_case["roles"].get(role)
            add("manifest.%s.groups==json" % role,
                mc is not None and mc["groups"] == [len(g["members"]) for g in jr["groups"]]
                and mc["rows"] == jr["commitment"]["rows"] and mc["claims"] == len(jr["claims"]), "input")
    add("opening_order", js["opening_order"] == ["M", "W", "A", "H", "Input", "Output"], "input")
    add("roles.order", list(roles.keys()) == (["W"] if is_p3 else []) + ["A", "H", "Input", "Output"], "input")

    # --- the verifier transcript (zk_ffn_fresh_io.rs 412-481 -> zk.rs 3501-3775) ---
    tr = io_transcript(hasher, policy)
    absorb_statement(tr, st)
    tr.absorb(b"zk", header_v3(privacy))
    absorb_com(tr, b"W", rec["w_com"]["root"], rec["w_com"]["rows"])
    absorb_com(tr, b"A", rec["a_com"]["root"], rec["a_com"]["rows"])
    tr.absorb(b"M", rec["mask_root"])
    beta = named("beta", tr.challenge_fp2("beta"))
    gamma = named("gamma", tr.challenge_fp2("gamma"))
    alpha = named("alpha", tr.challenge_fp2("alpha"))
    absorb_com(tr, b"H", rec["h_com"]["root"], rec["h_com"]["rows"])
    del beta, gamma, alpha

    def sumcheck(name, claim, degree, n_rounds, rounds):
        if len(rounds) != n_rounds:
            raise Refusal("%s: %d rounds in the receipt, the schedule needs %d" % (name, len(rounds), n_rounds))
        rho = []
        chain = claim
        chain_ok = True
        first_bad = None
        for j, s in enumerate(rounds):
            if len(s) != degree + 1:
                raise Refusal("%s round %d: %d values for degree %d" % (name, j, len(s), degree))
            if f2add(s[0], s[1]) != chain:
                chain_ok = False
                if first_bad is None:
                    first_bad = j
            tr.absorb_fp2(b"sc-round", s)
            r = tr.challenge_fp2("%s.rho[%d]" % (name, j))
            rho.append(r)
            chain = interpolate_eval(s, r)
        add("%s.sumcheck-chain(s0+s1==claim, %d rounds)" % (name, n_rounds), chain_ok, "identity", first_bad_round=first_bad)
        return chain, rho

    ffn_slots = []
    ext = 1 + (1 if is_p3 else 0)
    # ---- g/u (zk.rs 3536-3569) ----
    named_vec("gu.r_i", tr.challenge_fp2_vec(lay["log_t"], "gu.r_i"))
    named_vec("gu.r_j", tr.challenge_fp2_vec(lay["log_fb"], "gu.r_j"))
    named("gu.lam_gu", tr.challenge_fp2("gu.lam_gu"))
    named_vec("gu.lam_f", tr.challenge_fp2_vec(lay["nb_f"], "gu.lam_f"))
    c_gu = named("gu.c", tr.challenge_fp2("gu.c"))
    tr.absorb_fp2(b"gu-claim", [rec["ffn"]["gu"]["claim"]])
    _, rho_gu = sumcheck("gu", rec["ffn"]["gu"]["claim"], 2, lay["log_db"] + ext, rec["ffn"]["gu"]["rounds"])
    named_vec("gu.rho", rho_gu)
    tr.absorb_fp2(b"gu-term", rec["ffn"]["gu"]["terminals"])
    ffn_slots.append({"name": "gu", "mask_slot": MASK_SLOT["gu"], "c": _fp2_json(c_gu), "rho": _fp2_list(rho_gu)})
    # ---- d (3576-3598) ----
    named_vec("d.r_ip", tr.challenge_fp2_vec(lay["log_t"], "d.r_ip"))
    named_vec("d.r_jp", tr.challenge_fp2_vec(lay["log_db"], "d.r_jp"))
    named_vec("d.lam_d", tr.challenge_fp2_vec(lay["nb_d"], "d.lam_d"))
    c_d = named("d.c", tr.challenge_fp2("d.c"))
    tr.absorb_fp2(b"d-claim", [rec["ffn"]["d"]["claim"]])
    _, rho_d = sumcheck("d", rec["ffn"]["d"]["claim"], 2, lay["log_fb"] + ext, rec["ffn"]["d"]["rounds"])
    named_vec("d.rho", rho_d)
    tr.absorb_fp2(b"d-term", rec["ffn"]["d"]["terminals"])
    ffn_slots.append({"name": "d", "mask_slot": MASK_SLOT["d"], "c": _fp2_json(c_d), "rho": _fp2_list(rho_d)})
    # ---- zero-check F (3605-3635) ----
    nvf = lay["log_t"] + lay["log_fb"]
    named_vec("zc20.tau", tr.challenge_fp2_vec(nvf, "zc20.tau"))
    named_vec("zc20.mu", tr.challenge_fp2_vec(4 * lay["nb_f"], "zc20.mu"))
    nu0 = named("zc20.nu0", tr.challenge_fp2("zc20.nu0"))
    c_f = named("zc20.c", tr.challenge_fp2("zc20.c"))
    tr.absorb_fp2(b"gammaF", [rec["ffn"]["zc20"]["claim"]])
    claimed = f2add(f2mul(nu0, rec["ffn"]["gu"]["claim"]), rec["ffn"]["zc20"]["claim"])
    _, rho_f = sumcheck("zc20", claimed, 4, nvf + 1, rec["ffn"]["zc20"]["rounds"])
    named_vec("zc20.rho", rho_f)
    tr.absorb_fp2(b"zcF-term", rec["ffn"]["zc20"]["terminals"])
    ffn_slots.append({"name": "zc20", "mask_slot": MASK_SLOT["zc20"], "c": _fp2_json(c_f), "rho": _fp2_list(rho_f)})
    # ---- zero-check D (3638-3662) ----
    nvd = lay["log_t"] + lay["log_db"]
    named_vec("zc17.tau2", tr.challenge_fp2_vec(nvd, "zc17.tau2"))
    named_vec("zc17.mu2", tr.challenge_fp2_vec(lay["nb_d"], "zc17.mu2"))
    nu_z = named("zc17.nu_z", tr.challenge_fp2("zc17.nu_z"))
    c_dz = named("zc17.c", tr.challenge_fp2("zc17.c"))
    tr.absorb_fp2(b"gammaD", [rec["ffn"]["zc17"]["claim"]])
    claimed = f2add(f2mul(nu_z, rec["ffn"]["d"]["claim"]), rec["ffn"]["zc17"]["claim"])
    _, rho_dz = sumcheck("zc17", claimed, 4, nvd + 1, rec["ffn"]["zc17"]["rounds"])
    named_vec("zc17.rho", rho_dz)
    tr.absorb_fp2(b"zcD-term", rec["ffn"]["zc17"]["terminals"])
    ffn_slots.append({"name": "zc17", "mask_slot": MASK_SLOT["zc17"], "c": _fp2_json(c_dz), "rho": _fp2_list(rho_dz)})
    # ---- the table-side zero-check (3665-3687) ----
    named_vec("tab.tau3", tr.challenge_fp2_vec(lay["log_s"], "tab.tau3"))
    named_vec("tab.mu3", tr.challenge_fp2_vec(lay["n_tabs"], "tab.mu3"))
    c_tab = named("tab.c", tr.challenge_fp2("tab.c"))
    tr.absorb_fp2(b"gamma-tab", [rec["ffn"]["tab"]["claim"]])
    _, rho_tab = sumcheck("tab", rec["ffn"]["tab"]["claim"], 3, lay["log_s"] + 1, rec["ffn"]["tab"]["rounds"])
    named_vec("tab.rho", rho_tab)
    tr.absorb_fp2(b"tab-term", rec["ffn"]["tab"]["terminals"])
    ffn_slots.append({"name": "tab", "mask_slot": MASK_SLOT["tab"], "c": _fp2_json(c_tab), "rho": _fp2_list(rho_tab)})
    # ---- the zero-sum sumcheck (3690-3696) ----
    c_zs = named("zs.c", tr.challenge_fp2("zs.c"))
    tr.absorb_fp2(b"gamma-zs", [rec["ffn"]["zs"]["claim"]])
    _, rho_zs = sumcheck("zs", rec["ffn"]["zs"]["claim"], 2, lay["log_n"] + 1, rec["ffn"]["zs"]["rounds"])
    named_vec("zs.rho", rho_zs)
    tr.absorb_fp2(b"zs-term", rec["ffn"]["zs"]["terminals"])
    ffn_slots.append({"name": "zs", "mask_slot": MASK_SLOT["zs"], "c": _fp2_json(c_zs), "rho": _fp2_list(rho_zs)})

    # ---- before_openings = the IO equality arguments (zk_ffn_fresh_io.rs 371-410) ----
    io_slots = []
    for i in range(2):
        ja, ra = js["io_arguments"][i], rec["arguments"][i]
        add("io[%d].side,slot" % i, ja["side"] == i and ja["slot"] == 6 + i, "input")
        checkpoint("io[%d].before" % i, tr, ja["before"])
        tr.absorb_u64(b"io-side", i)
        tau = named_vec("io[%d].tau" % i, tr.challenge_fp2_vec(9, "io[%d].tau" % i))
        c = named("io[%d].c" % i, tr.challenge_fp2("io[%d].c" % i))
        add("io[%d].c!=0" % i, c != ZERO2, "identity")
        value("io[%d].tau==json" % i, tau, _as_pairs(ja["tau"]))
        value("io[%d].c==json" % i, [c], [tuple(ja["c"])])
        tr.absorb_fp2(b"io-gamma", [ra["gamma"]])
        fin, rho = sumcheck("io[%d]" % i, ra["gamma"], 2, 10, ra["rounds"])
        named_vec("io[%d].rho" % i, rho)
        value("io[%d].rho==json" % i, rho, _as_pairs(ja["rho"]))
        e = rho[9]
        add("io[%d].e!=0" % i, e != ZERO2, "identity")
        want = f2add(f2mul(f2mul(f2sub(ONE2, e), eq_point(tau, rho[:9])), f2sub(ra["terminals"][0], ra["terminals"][1])),
                     f2mul(c, ra["mask_eval"]))
        add("io[%d].terminal-identity" % i, fin == want, "identity")
        tr.absorb_fp2(b"io-terminals", ra["terminals"])
        tr.absorb_fp2(b"io-mask-eval", [ra["mask_eval"]])
        checkpoint("io[%d].after" % i, tr, ja["after"])
        io_slots.append({"side": i, "mask_slot": 6 + i, "tau": _fp2_list(tau), "c": _fp2_json(c), "rho": _fp2_list(rho)})

    # ---- the mask opening (zk.rs 552-585) ----
    jm = js["mask"]
    checkpoint("M.before", tr, jm["before"])
    theta = named("M.theta", tr.challenge_fp2("M.theta"))
    value("M.theta==json", [theta], [tuple(jm["theta"])])
    tr.absorb_fp2(b"mask-q", rec["mask_open"]["q"])
    rs = named_vec("M.prox_rho", tr.challenge_fp2_vec(2 * len(jm["specs"]) + 2, "M.prox_rho"))
    value("M.proximity_rhos==json", rs, _as_pairs(jm["proximity_rhos"]))
    tr.absorb_fp2(b"mask-prox", rec["mask_open"]["prox"])
    idx = tr.challenge_indices(MASK_Q, 1 << MASK_LOG_DOM, "M.idx")
    challenges.append({"name": "M.idx", "value": idx})
    add("M.indices==receipt-columns", idx == [c["index"] for c in rec["mask_open"]["columns"]], "value")
    add("M.indices==json-columns", idx == [c["index"] for c in jm["columns"]], "value")
    checkpoint("M.after", tr, jm["after"])

    # ---- the PCS openings: W (P3 hiding / P1 plain), A, H, Input, Output ----
    enc_cols = (1 << PARAMS["log_cols"]) * PARAMS["inv_rate"]
    if not is_p3:
        pw = js["public_w"]
        checkpoint("W(public).before", tr, pw["before"])
        # pcs::group_claims on the P1 W claims: wg, wu at p3 then wd at p6 (zk.rs 3326-3336);
        # first-occurrence grouping by the full point (log_size 8 == log_cols: the key is the point).
        p3_key = tuple(rho_gu[:lay["log_db"]]) + tuple(challenge_by_prefix(challenges, "gu.r_j"))
        p6_key = tuple(rho_d[:lay["log_fb"]]) + tuple(challenge_by_prefix(challenges, "d.r_jp"))
        keys = [p3_key] * (2 * lay["nb_d"] * lay["nb_f"]) + [p6_key] * (lay["nb_f"] * lay["nb_d"])
        groups = []
        for k in keys:
            for g in groups:
                if g[0] == k:
                    g[1] += 1
                    break
            else:
                groups.append([k, 1])
        sizes = [g[1] for g in groups]
        add("W(public).groups(derived)", len(sizes) == len(rec["w_open"]["group_vecs"]), "input", sizes=sizes)
        for g, size in enumerate(sizes):
            named_vec("W.lambda[%d]" % g, tr.challenge_fp2_vec(size, "W.lambda[%d]" % g))
        named_vec("W.prox_rho", tr.challenge_fp2_vec(rec["w_com"]["rows"], "W.prox_rho"))
        for v in rec["w_open"]["group_vecs"]:
            tr.absorb_fp2(b"pcs-vec", v)
        tr.absorb_fp2(b"pcs-prox", rec["w_open"]["prox_vec"])
        idx = tr.challenge_indices(PARAMS["num_col_checks"], enc_cols, "W.idx")
        challenges.append({"name": "W.idx", "value": idx})
        add("W(public).indices==receipt-columns", idx == [c["index"] for c in rec["w_open"]["columns"]], "value")
        checkpoint("W(public).after", tr, pw["after"])
    for role in (["W"] if is_p3 else []) + ["A", "H", "Input", "Output"]:
        jr = roles[role]
        op = role_open[role]
        rows = jr["commitment"]["rows"]
        add("%s.params" % role, jr["params"] == PARAMS, "input")
        checkpoint("%s.before" % role, tr, jr["before"])
        for g, grp in enumerate(jr["groups"]):
            lam = named_vec("%s.lambda[%d]" % (role, g), tr.challenge_fp2_vec(len(grp["members"]), "%s.lambda[%d]" % (role, g)))
            value("%s.lambda[%d]==json" % (role, g), lam, _as_pairs(grp["lambdas"]))
        prox = named_vec("%s.prox_rho" % role, tr.challenge_fp2_vec(rows, "%s.prox_rho" % role))
        value("%s.proximity_rhos==json" % role, prox, _as_pairs(jr["proximity_rhos"]))
        for v in op["group_vecs"]:
            tr.absorb_fp2(b"pcs-vec", v)
        tr.absorb_fp2(b"pcs-prox", op["prox_vec"])
        idx = tr.challenge_indices(PARAMS["num_col_checks"], enc_cols, "%s.idx" % role)
        challenges.append({"name": "%s.idx" % role, "value": idx})
        add("%s.indices==receipt-columns" % role, idx == [c["index"] for c in op["columns"]], "value")
        add("%s.indices==json-columns" % role, idx == [c["index"] for c in jr["columns"]], "value")
        checkpoint("%s.after" % role, tr, jr["after"])

    history = [list(h) for h in tr.history] if want_history else None
    n_absorb = sum(1 for h in tr.history if h[0] == "absorb")
    n_squeeze = sum(1 for h in tr.history if h[0] == "squeeze")
    absorbed = sum(h[2] for h in tr.history if h[0] == "absorb")
    all_ok = all(c["ok"] for c in checks)
    return {
        "sha": sha,
        "privacy": privacy,
        "ok": all_ok,
        "statement": {k: (list(v) if isinstance(v, tuple) else v) for k, v in st.items() if k != "table"},
        "statement_provenance": provenance,
        "layout": lay,
        "final_state": tr.state.hex(),
        "final_counter": tr.counter,
        "oracle_summary": {"absorbs": n_absorb, "squeezes": n_squeeze, "absorbed_bytes": absorbed},
        "ffn_slots": ffn_slots,
        "io_slots": io_slots,
        "challenges": challenges,
        "checkpoints": checks,
        "oracle_history": history,
    }


def challenge_by_prefix(challenges, prefix):
    return [tuple(c["value"]) for c in challenges if c["name"].startswith(prefix + "[")]


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--captures", required=True, help="directory of <sha>.json/.receipt/.expected triplets")
    ap.add_argument("--manifest", required=True, help="zk60_round22_captures.json")
    ap.add_argument("--out", required=True, help="output JSON path")
    ap.add_argument("--backend", choices=["auto", "wheel", "pure"], default="auto")
    ap.add_argument("--only", default=None, help="replay only captures whose sha starts with this prefix")
    ap.add_argument("--source-root", default=None,
                    help="repo root for the manifest's source_sha256 checks (default: the parent of this script's dir)")
    ap.add_argument("--no-history", action="store_true", help="omit oracle_history from the output")
    args = ap.parse_args(argv)

    backend, hasher = select_backend(args.backend)
    source_root = args.source_root or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(args.manifest, "r") as f:
        manifest = json.load(f)
    t0 = time.time()
    mchecks, shas, cases = check_manifest(manifest, args.captures, source_root)
    out = {
        "tool": "zk60_transcript_replay.py",
        "profile": PROFILE.decode("ascii"),
        "hash_backend": backend,
        "manifest": {"path": os.path.abspath(args.manifest), "source_commit": manifest.get("source_commit"),
                     "checks": mchecks, "ok": all(c["ok"] for c in mchecks)},
        "captures": [],
    }
    refusals = []
    for sha, case in zip(shas, cases):
        if args.only and not sha.startswith(args.only):
            continue
        t1 = time.time()
        try:
            cap = load_capture(args.captures, sha)
            res = replay_capture(cap, hasher, manifest_case=case, want_history=not args.no_history)
        except Refusal as e:
            refusals.append({"sha": sha, "reason": str(e)})
            out["captures"].append({"sha": sha, "ok": False, "refused": str(e)})
            print("REFUSED %s: %s" % (sha[:12], e), file=sys.stderr)
            continue
        res["seconds"] = round(time.time() - t1, 3)
        out["captures"].append(res)
        bad = [c["name"] for c in res["checkpoints"] if not c["ok"]]
        print("%s %s ok=%s checks=%d failed=%d rho_lengths=%s (%.1fs)" % (
            sha[:12], res["privacy"], res["ok"], len(res["checkpoints"]), len(bad),
            [len(s["rho"]) for s in res["ffn_slots"]], res["seconds"]))
        for name in bad:
            print("  FAIL %s" % name)
    out["refusals"] = refusals
    out["ok"] = out["manifest"]["ok"] and not refusals and all(c.get("ok") for c in out["captures"]) and bool(out["captures"])
    out["seconds"] = round(time.time() - t0, 3)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(out, f, indent=1)
    print("manifest ok=%s; captures ok=%d/%d; refusals=%d; backend=%s; wrote %s" % (
        out["manifest"]["ok"], sum(1 for c in out["captures"] if c.get("ok")), len(out["captures"]),
        len(refusals), backend, args.out))
    if refusals:
        return 2
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
