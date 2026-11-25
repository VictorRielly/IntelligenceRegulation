"""A21. Count two proposed n-way OUT-C layouts using the token-I/O Stage counter."""

import importlib.util
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
COUNTER = ROOT / "results/zk60_token_io_design_20261017/token_io_count.py"
SOURCE = ROOT / ("results/zk60_sol_20261105_w16r3/b3/source-d26-sealed-statement541/"
                 "hashline/src/private_block/token_io")
ARCHIVE = ROOT / "results/zk60_astra_20261026/a3_classifier_native_20261105/public-evidence"


def load_counter():
    spec = importlib.util.spec_from_file_location("restricted_head_counter", COUNTER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def baseline(tc):
    src = (SOURCE / "stage_out_c.rs").read_text()
    cls = (SOURCE / "classify.rs").read_text()
    width, hidden, tokens = 4096, 3072, 128
    shift = int(re.search(r"const LAM_BASE: usize = (\d+);", cls)[1])
    cmax = 1 << int(re.search(r"const C_MAX: i64 = 1 << (\d+);", cls)[1])
    limbs = ((hidden * 127 * 32767 + cmax + 1).bit_length() + 7) // 8
    st = tc.Stage("OUT-C", 12)
    assert st.n == width and tc.Q == 256 and tc.INV_RATE == 4
    assert hidden <= width and tokens == 128 and limbs == 5 and shift == 32
    domains = {"d_bits": 12, "ldo": 12, "TO_LOG": 1, "llo": 12, "ltab": 12, "lt": 12}
    helpers = int(re.search(r"const H_DO_HELPERS: usize = (\d+);", src)[1])
    def nat(s):
        return helpers if s == "H_DO_HELPERS" else int(s)
    for name, main, ext, degree, a, h, io in re.findall(
            r'SlotSpec \{ name: "(OUTC-\d\d)[^"]+", main: (\w+), ext: (\d+), degree: (\d+),'
            r' kind: SlotKind::\w+, a_sites: (\w+), h_sites: (\w+), io_sites: (\w+) \}', src):
        a, h, io = map(nat, (a, h, io))
        st.slots.append((name, domains[main], int(ext), int(degree), a + h + io, None, a + h + io))
        st.a_sites += a
        st.h_sites += h
    assert len(st.slots) == 8 and (st.a_sites, st.h_sites) == (29, 9)
    st.a = [("To", 2)] * 2 + [("Lo", width)] + [("Do", width)] * 12 + [("Tab", width)]
    st.h = [("Lo", width)] + [("Do", width)] * helpers + [("Tab", width), ("U", width)]
    st.groups_a = int(re.search(r"const A_GROUPS: usize = (\d+);", src)[1])
    st.groups_h = int(re.search(r"const H_GROUPS: usize = (\d+);", src)[1])
    st.closes_boundary = (38, 14)  # the verified R13 carry
    return st, shift, limbs


def verify_record(size):
    for name in ("hate", "sexual", "violence"):
        record = json.loads((ARCHIVE / f"{name}-record.json").read_text())
        def found(v):
            if isinstance(v, list):
                return any(found(a) for a in v)
            if isinstance(v, dict):
                return (v.get("file") == "segment-027.bin" and v.get("bytes") == size) or any(found(a) for a in v.values())
            return False
        assert found(record), name


def project(tc, n, kind, base_bytes):
    st, shift, limbs = baseline(tc)
    extra = n - 2
    limb_extent = shift + (n - 1) * limbs if kind == "packed-bank" else shift + limbs
    assert limb_extent <= st.n
    for _ in range(extra):
        # Copy the PD slot, reading the same y plane with its own reserved
        # pair; budget a new A group for the fresh point.
        st.slots.append(st.slots[3])
        st.a_sites += 1
        st.groups_a += 1
        if kind == "separate-limbs":
            # Repeat the current LZC geometry for each additional margin.
            st.slots.append(st.slots[4])
            st.a.append(("Lo+margin", st.n))
            st.h.append(("Lo+margin", st.n))
            st.a_sites += 1
            st.h_sites += 1
            st.groups_a += 1
            st.groups_h += 1
    s = st.summary()
    return {"layout": kind, "labels": n, "comparisons": n - 1, "max_limb_extent": limb_extent,
            **{k: s[k] for k in ("log_cols", "A_rows", "H_rows", "M_rows", "elems", "slots", "receipt")},
            "delta_receipt": s["receipt"] - base_bytes}


if __name__ == "__main__":
    tc = load_counter()
    base, _, _ = baseline(tc)
    observed = base.summary()
    assert (observed["A_rows"], observed["H_rows"], observed["M_rows"], observed["elems"], observed["receipt"]) == (
        76, 38, 20, 466_944, 3_292_120)
    verify_record(observed["receipt"])
    print(json.dumps({"profile": "Shieldstral 3B T128 R13 public-row, one output position",
                      "counts": [project(tc, n, k, observed["receipt"])
                                 for n in (2, 4, 8, 16) for k in ("packed-bank", "separate-limbs")]}, indent=2))
