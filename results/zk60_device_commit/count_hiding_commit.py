#!/usr/bin/env python3
"""Counting evidence for ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md.

[COUNTED] Everything this script prints is derived from the code and the
shape, not measured. It runs nothing, builds nothing, and touches no device.

WHAT IT COUNTS, and from which source text (all read-only; the lane
worktree /home/victor/wt-zk60-block125m at a8e4939 unless said otherwise):

  * the byte-level contract of `zkp_core::pcs::commit_zk_owned_with_tag`
    (zkp-core/src/pcs.rs:769-808) and the functions it calls --
    `encode_row_zk` (:655-674), `coset_powers` (:642-651),
    `hash_columns_keyed` (:182-202), `salt_leaf_keyed` (:691-696),
    `MerkleTree::build_keyed` (zkp-core/src/merkle.rs:52-65),
    `open_zk` (:1023-1052);
  * the shapes, from the lane's own layout model JSONs
    results/zk60_block125m_lane/model_{m125,rung_w14,toy}.json, whose
    `receipt_bytes` block the Rust asserts part by part in
    hashline/src/private_block/grow_tests.rs:708-727;
  * the random draw sizes, from zkp-core/src/rng.rs: `fp()` is two
    `next_u64`s = 16 stream bytes, `bytes32()` is four = 32 stream bytes
    (the crate's own test `the_consumption_accessor_counts_every_draw_kind_
    exactly`, rng.rs:220-253, pins exactly these).

The receipt reconciliation is the check: this script rebuilds each shape's
`receipt_bytes` total from the per-commitment counts and compares it with
the number in the model JSON, which is the number the Rust asserts and the
number the committed proof logs report. A mismatch is a bug in this script.
"""

import json
import os
import sys

LANE = "/home/victor/wt-zk60-block125m"
MODELS = os.path.join(LANE, "results/zk60_block125m_lane")

# ---------------------------------------------------------------------------
# constants read out of the source, with their file:line
# ---------------------------------------------------------------------------
FP_BYTES = 8           # field.rs:88  Fp::to_bytes -> u64 little-endian
FP2_BYTES = 16         # field.rs:193 Fp2::to_bytes
DIGEST_BYTES = 32      # merkle.rs:6  Digest = [u8; 32]
SALT_BYTES = 32        # pcs.rs:725   salts: Vec<[u8; 32]>
COL_CHECKS = 256       # shape.rs:51
WIRE_HEADER = 8 + 32   # shape.rs:50
MASK_VEC = 1024        # wire.rs:17
MASK_DOM = 4096        # wire.rs:18
MASK_PATH = 12         # wire.rs:19
M_ROWS = 50            # 2 * N_SLOTS(23) + 4, layout.rs:797
RNG_FP_BYTES = 16      # rng.rs:73-77  fp() = two next_u64
RNG_B32_BYTES = 32     # rng.rs:93-99  bytes32() = four next_u64

# BLAKE3, as the `blake3` crate the CPU path uses implements it
B3_BLOCK = 64
B3_CHUNK = 1024


def b3_compressions(msg_bytes: int) -> int:
    """Compression-function calls BLAKE3 makes on a message of `msg_bytes`.

    One per 64-byte block (a zero-length message still makes one), plus one
    per parent node of the chunk tree: `chunks - 1`. Keyed mode makes
    EXACTLY the same number -- the key words replace the IV in the chunk
    states and the KEYED_HASH flag is set; no extra compression is added
    (hashtag.rs:30-33 states this as a count, and this function is where
    the count is made). [COUNTED]
    """
    blocks = max(1, -(-msg_bytes // B3_BLOCK))
    chunks = max(1, -(-msg_bytes // B3_CHUNK))
    return blocks + (chunks - 1)


def clog2(x: int) -> int:
    assert x > 0 and (x & (x - 1)) == 0, f"{x} is not a power of two"
    return x.bit_length() - 1


class Commitment:
    """One hiding commitment, counted."""

    def __init__(self, name, rows, log_cols, inv_rate, q_pad, groups):
        self.name = name
        self.rows = rows
        self.n = 1 << log_cols
        self.nn = self.n * inv_rate
        self.q = q_pad
        self.groups = groups
        self.depth = clog2(self.nn)

    # -- what the prover holds ------------------------------------------
    @property
    def data_bytes(self):
        """the systematic rows the commitment keeps (CommittedZk.data)"""
        return self.rows * self.n * FP_BYTES

    @property
    def pad_bytes(self):
        """the pad rows (CommittedZk.pads), rows x Q"""
        return self.rows * self.q * FP_BYTES

    @property
    def encoded_bytes(self):
        """the coset-encoded matrix, rows x nn, row-major"""
        return self.rows * self.nn * FP_BYTES

    @property
    def salt_bytes(self):
        return self.nn * SALT_BYTES

    @property
    def leaf_bytes(self):
        """the leaf level of the tree (nn digests)"""
        return self.nn * DIGEST_BYTES

    @property
    def tree_bytes(self):
        """every level of the tree: nn + nn/2 + ... + 1 = 2*nn - 1 digests"""
        return (2 * self.nn - 1) * DIGEST_BYTES

    @property
    def coset_pow_bytes(self):
        return self.nn * FP_BYTES

    # -- what is hashed --------------------------------------------------
    @property
    def column_hash_input_bytes(self):
        """nn columns of `rows` little-endian u64 each"""
        return self.nn * self.rows * FP_BYTES

    @property
    def column_hash_compressions(self):
        return self.nn * b3_compressions(self.rows * FP_BYTES)

    @property
    def leaf_hash_input_bytes(self):
        """nn leaves of (32-byte column digest || 32-byte salt)"""
        return self.nn * (DIGEST_BYTES + SALT_BYTES)

    @property
    def leaf_hash_compressions(self):
        return self.nn * b3_compressions(DIGEST_BYTES + SALT_BYTES)

    @property
    def inner_nodes(self):
        return self.nn - 1

    @property
    def node_hash_input_bytes(self):
        return self.inner_nodes * 2 * DIGEST_BYTES

    @property
    def node_hash_compressions(self):
        return self.inner_nodes * b3_compressions(2 * DIGEST_BYTES)

    @property
    def total_compressions(self):
        return (self.column_hash_compressions
                + self.leaf_hash_compressions
                + self.node_hash_compressions)

    # -- randomness ------------------------------------------------------
    @property
    def rng_pad_bytes(self):
        """rng.fp_vec(rows * q): 16 stream bytes per element"""
        return self.rows * self.q * RNG_FP_BYTES

    @property
    def rng_salt_bytes(self):
        """nn x rng.bytes32()"""
        return self.nn * RNG_B32_BYTES

    @property
    def rng_bytes(self):
        return self.rng_pad_bytes + self.rng_salt_bytes

    # -- what is sent ----------------------------------------------------
    @property
    def sent_column_bytes(self):
        """OpeningZk.write_bytes, the `columns` part:
        per opened column: 8 (index, le64) + rows*8 + 32 (salt) + depth*32"""
        return COL_CHECKS * (8 + self.rows * FP_BYTES + SALT_BYTES
                             + self.depth * DIGEST_BYTES)

    @property
    def sent_vector_bytes(self):
        """(groups + 1) clear vectors of n + Q Fp2 entries each"""
        return (self.groups + 1) * (self.n + self.q) * FP2_BYTES

    @property
    def opening_bytes(self):
        return self.sent_column_bytes + self.sent_vector_bytes

    def row(self):
        return dict(
            name=self.name, rows=self.rows, n=self.n, nn=self.nn, q=self.q,
            groups=self.groups, depth=self.depth,
            data_bytes=self.data_bytes,
            pad_bytes=self.pad_bytes,
            encoded_bytes=self.encoded_bytes,
            salt_bytes=self.salt_bytes,
            leaf_bytes=self.leaf_bytes,
            tree_bytes=self.tree_bytes,
            coset_pow_bytes=self.coset_pow_bytes,
            column_hash_input_bytes=self.column_hash_input_bytes,
            column_hash_compressions=self.column_hash_compressions,
            leaf_hash_input_bytes=self.leaf_hash_input_bytes,
            leaf_hash_compressions=self.leaf_hash_compressions,
            inner_nodes=self.inner_nodes,
            node_hash_compressions=self.node_hash_compressions,
            total_compressions=self.total_compressions,
            rng_pad_bytes=self.rng_pad_bytes,
            rng_salt_bytes=self.rng_salt_bytes,
            rng_bytes=self.rng_bytes,
            sent_column_bytes=self.sent_column_bytes,
            sent_vector_bytes=self.sent_vector_bytes,
            opening_bytes=self.opening_bytes,
        )


def shape_commitments(model):
    """The five hiding commitments of one private block, from the model JSON."""
    sh = model["shape"]
    rows = model["rows"]
    og = model["opening_groups"]
    lc, ir = sh["log_cols"], sh["inv_rate"]
    e_lc, e_ir = sh["endpoint_log_n"], sh["endpoint_inv_rate"]
    return [
        Commitment("A", rows["a_rows"], lc, ir, COL_CHECKS, og["a_groups"]),
        Commitment("H", rows["h_rows"], lc, ir, COL_CHECKS, og["h_groups"]),
        Commitment("endpoint-in", sh["endpoint_rows"], e_lc, e_ir, COL_CHECKS, 1),
        Commitment("endpoint-out", sh["endpoint_rows"], e_lc, e_ir, COL_CHECKS, 1),
    ]


def mask_opening_bytes():
    """`zk::mask_commit`'s opening, whose wire form is fixed (wire.rs:106):
    2 * MASK_VEC Fp2 + COL_CHECKS * (8 + M_ROWS*8 + 32 + MASK_PATH*32)."""
    return (2 * MASK_VEC * FP2_BYTES
            + COL_CHECKS * (8 + M_ROWS * FP_BYTES + SALT_BYTES
                            + MASK_PATH * DIGEST_BYTES))


def reconcile(name, model):
    """Rebuild the shape's receipt total from the per-commitment counts."""
    cms = shape_commitments(model)
    rb = model["receipt_bytes"]
    a, h, e1, e2 = cms
    got = dict(
        a_opening=a.opening_bytes,
        h_opening=h.opening_bytes,
        endpoint_openings=e1.opening_bytes + e2.opening_bytes,
        mask_opening=mask_opening_bytes(),
        header_and_three_roots=WIRE_HEADER + 3 * DIGEST_BYTES,
        slots=rb["slots"],  # the sumcheck slot transcript: NOT a commitment
    )
    got["total"] = sum(got.values())
    ok = all(got[k] == rb[k] for k in rb)
    return cms, got, rb, ok


def fmt(x):
    return f"{x:,}"


def mib(x):
    return x / (1024.0 ** 2)


def gib(x):
    return x / (1024.0 ** 3)


def main():
    out = {}
    shapes = [("125M", "model_m125.json"),
              ("rung-W14", "model_rung_w14.json"),
              ("toy", "model_toy.json")]
    for label, fn in shapes:
        path = os.path.join(MODELS, fn)
        with open(path) as f:
            model = json.load(f)
        cms, got, rb, ok = reconcile(label, model)
        print("=" * 74)
        print(f"{label}   (source: {path})")
        print(f"  log_cols {model['shape']['log_cols']}  inv_rate "
              f"{model['shape']['inv_rate']}  opened columns {COL_CHECKS}  "
              f"pads/row {COL_CHECKS}")
        print("=" * 74)
        for c in cms:
            print(f"\n  -- commitment {c.name}: {fmt(c.rows)} rows, "
                  f"n = {fmt(c.n)}, nn = {fmt(c.nn)}, Q = {c.q}, "
                  f"tree depth {c.depth}, {c.groups} claim group(s)")
            print(f"     systematic data held      {fmt(c.data_bytes):>18} B"
                  f"  ({mib(c.data_bytes):8.1f} MiB)")
            print(f"     pad rows held             {fmt(c.pad_bytes):>18} B"
                  f"  ({mib(c.pad_bytes):8.1f} MiB)")
            print(f"     ENCODED matrix            {fmt(c.encoded_bytes):>18} B"
                  f"  ({mib(c.encoded_bytes):8.1f} MiB)")
            print(f"     coset powers              {fmt(c.coset_pow_bytes):>18} B")
            print(f"     salts                     {fmt(c.salt_bytes):>18} B")
            print(f"     Merkle tree (all levels)  {fmt(c.tree_bytes):>18} B")
            print(f"     column bytes hashed       "
                  f"{fmt(c.column_hash_input_bytes):>18} B"
                  f"  ({mib(c.column_hash_input_bytes):8.1f} MiB)")
            print(f"     leaf bytes hashed         "
                  f"{fmt(c.leaf_hash_input_bytes):>18} B")
            print(f"     inner nodes               {fmt(c.inner_nodes):>18}")
            print(f"     BLAKE3 compressions: columns {fmt(c.column_hash_compressions)}"
                  f" + leaves {fmt(c.leaf_hash_compressions)}"
                  f" + nodes {fmt(c.node_hash_compressions)}"
                  f" = {fmt(c.total_compressions)}")
            print(f"     random stream bytes: pads {fmt(c.rng_pad_bytes)}"
                  f" + salts {fmt(c.rng_salt_bytes)}"
                  f" = {fmt(c.rng_bytes)}")
            print(f"     SENT: columns {fmt(c.sent_column_bytes)}"
                  f" + clear vectors {fmt(c.sent_vector_bytes)}"
                  f" = {fmt(c.opening_bytes)} B")
        tot_enc = sum(c.encoded_bytes for c in cms)
        tot_rng = sum(c.rng_bytes for c in cms)
        tot_hashed = sum(c.column_hash_input_bytes for c in cms)
        tot_comp = sum(c.total_compressions for c in cms)
        print(f"\n  -- the four commitments together")
        print(f"     encoded matrices          {fmt(tot_enc):>18} B"
              f"  ({gib(tot_enc):6.2f} GiB)")
        print(f"     column bytes hashed       {fmt(tot_hashed):>18} B"
              f"  ({gib(tot_hashed):6.2f} GiB)")
        print(f"     BLAKE3 compressions       {fmt(tot_comp):>18}")
        print(f"     random stream bytes       {fmt(tot_rng):>18} B")
        print(f"\n  -- RECEIPT RECONCILIATION against {os.path.basename(path)}"
              f" (which grow_tests.rs:708-727 asserts part by part)")
        for k in sorted(rb):
            mark = "OK " if got[k] == rb[k] else "!! "
            print(f"     {mark}{k:<26} counted {fmt(got[k]):>14}"
                  f"   model {fmt(rb[k]):>14}")
        print(f"     -> {'RECONCILES' if ok else 'DOES NOT RECONCILE'}")
        out[label] = dict(
            commitments=[c.row() for c in cms],
            counted_receipt=got,
            model_receipt=rb,
            reconciles=ok,
            totals=dict(encoded_bytes=tot_enc, column_hash_input_bytes=tot_hashed,
                        compressions=tot_comp, rng_bytes=tot_rng),
        )
        print()

    # ------------------------------------------------------------------
    # the resident-set tables of section 3
    # ------------------------------------------------------------------
    print("=" * 74)
    print("RESIDENT DEVICE BYTES, 125M   [COUNTED from the same shapes]")
    print("=" * 74)
    m = out["125M"]
    a = next(c for c in m["commitments"] if c["name"] == "A")
    h = next(c for c in m["commitments"] if c["name"] == "H")
    for c in (a, h):
        rows, nn, n, q = c["rows"], c["nn"], c["n"], c["q"]
        print(f"\n  {c['name']}: {fmt(rows)} rows")
        print(f"    whole-commitment residency (no chunking)")
        print(f"      message+pad staging (rows x (n+Q) x 8)  "
              f"{fmt(rows * (n + q) * FP_BYTES):>14} B "
              f"({gib(rows * (n + q) * FP_BYTES):5.2f} GiB)")
        print(f"      encoded matrix    (rows x nn x 8)       "
              f"{fmt(c['encoded_bytes']):>14} B "
              f"({gib(c['encoded_bytes']):5.2f} GiB)")
        print(f"      leaves            (nn x 32)             "
              f"{fmt(c['leaf_bytes']):>14} B")
        print(f"      coset powers + twiddles (nn x 8 x 2)    "
              f"{fmt(2 * nn * FP_BYTES):>14} B")
        peak_whole = rows * (n + q) * FP_BYTES + c["encoded_bytes"] + c["leaf_bytes"] + 2 * nn * FP_BYTES
        print(f"      PEAK                                    "
              f"{fmt(peak_whole):>14} B ({gib(peak_whole):5.2f} GiB)")
        # row-chunked: the encode pass owns R rows at a time; the hash pass
        # needs whole columns, so it needs every row of the chunk's columns.
        for rc in (256, 512, 1024):
            stage = rc * (n + q) * FP_BYTES
            enc = rc * nn * FP_BYTES
            print(f"    ROW chunk {rc:>5}: stage {fmt(stage):>13} B + "
                  f"encoded slab {fmt(enc):>14} B "
                  f"({gib(stage + enc):5.2f} GiB) "
                  f"+ the whole encoded matrix must still exist somewhere "
                  f"for the column pass")
        # column-chunked hashing over a resident encoded matrix
        for cc in (4096, 8192, 16384):
            slab = rows * cc * FP_BYTES
            print(f"    COLUMN chunk {cc:>5}: one slab rows x {cc} x 8 = "
                  f"{fmt(slab):>14} B ({gib(slab):5.2f} GiB)")
    print()
    json_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "counts.json")
    with open(json_path, "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
    print(f"wrote {json_path}")
    bad = [k for k, v in out.items() if not v["reconciles"]]
    if bad:
        print(f"FAILURE: these shapes do not reconcile: {bad}")
        return 1
    print("every shape reconciles with its committed layout model")
    return 0


if __name__ == "__main__":
    sys.exit(main())
