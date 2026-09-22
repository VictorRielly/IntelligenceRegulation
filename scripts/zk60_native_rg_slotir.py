#!/usr/bin/env python3
"""ROUND 9c: the LANE's slot-expression IR export, read as a CROSS-CHECK of
this gate's hand port.

    python3 scripts/zk60_native_rg_slotir.py \
      --pair rung_c6:/path/to/run-m-dense-c6 \
      --pair m125:/path/to/m125-capture-dense-l2 \
      --evidence results/zk60_native_run_gate_9c --name slot_ir_crosscheck

**What this is, and what it is NOT.**  Lane stage 34 exports each
registered shape's twenty-three slot polynomials as canonical JSON (schema
`zk60-slot-ir/1`, `results/zk60_block125m_lane/x34-slot-ir/*.json`, each
pinned by SHA-256 and by length in a Rust test).  The export carries table
ids, kinds, field kinds and coefficient PROVENANCE -- never a challenge
value.  This module reads it and compares its STRUCTURE with what this
gate's own port declares and with what the bundle's capture declares.

Ruling I-8 (`ZK60_SLOT_EXPRESSION_IR_DISPOSITION.md`): the hand port stays
the gate's evaluator.  Nothing here evaluates anything, nothing here is
consumed by the terminal identity, and a disagreement is a QUESTION -- it
is either a defect in the port (finding M-F1's class) or a defect in the
export, and the answer is found by reading the Rust arm, never by making
one side agree with the other.

Eight comparisons per slot, each one of them a statement that could be
false:

  1  table COUNT: the export's `tables` against the capture's;
  2  table KIND SEQUENCE in push order, mapped to the common alphabet
     {eq, priv, pub}: the export against the capture;
  3  the PRIVATE sequence: the export's `(role, id)` pairs against the
     plane index table's `slot_planes`, which is the object this gate's
     `SlotCtx` resolves every table by name through (`cx.expect` refuses
     on any other order, so agreeing with the plane index IS agreeing
     with the port);
  4  the PUBLIC tables: the export's `supp(dom)` / `pub` entries against
     this port's `PUBLIC_SPEC`, entry for entry in push order;
  5  `declared_degree`, `main_rounds`, `extension_rounds`: the export
     against the capture's `arguments[s]` and the shape's `slots` triple;
  6  `pad_on`: the export against `PadGeometry.pads` over the domains the
     slot HOSTS -- the sentence finding M-F1 was about;
  7  `group_bits` at the two bilinear slots: the export against
     `log2(kv_heads)` from the shape;
  8  the LogUp terms: this port's `lookups_at(dom)` -- the byte-limb
     lookup list of `layout.rs`, which is where correction C-6 lives --
     against the export's helper columns for the six domains that have
     any.  `helper_sum` pairs the lookups two to a helper, so the count
     is `ceil(len / 2)`, and the ONE extra pair helper `Dom::S` and
     `Dom::F` carry (`H_SEXP`, `H_FACT`) is identified BY NAME in the
     plane index and excluded rather than subtracted by hand.  Slots 02,
     19, 20, 21 and 22 are excluded and say why: `Dom::T` has no byte
     limbs, and the `Tab` and zero-sum helpers are not byte-limb lookups.
"""

from __future__ import annotations

import argparse
import gc
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_rg_bundle import RunBundle  # noqa: E402
from zk60_native_rg_predict import ZERO_CHECK_SLOTS  # noqa: E402
from zk60_native_rg_terminals import (  # noqa: E402
    PUBLIC_SPEC,
    PadGeometry,
    lookups_at,
)

EXPORT_DIR = ("/home/victor/wt-zk60-block125m/results/zk60_block125m_lane/"
              "x34-slot-ir")

# The lane's own pinned digests and lengths (lane ledger, "Stage 34", task
# 5's table).  The export is READ ONLY if it is the pinned artefact: an
# unpinned file is not a cross-check of anything.
PINNED = {
    "toy": (99232,
            "12e7ed013f6ca106232e2f3be87ecce6a82e7382df75c45aabe0a13f358f6bfc"),
    "rung": (109631,
             "506d06db2158a16952975a29e5b36d7213761b2ce7fce28ba260d24e8bf774ad"),
    "rung_g": (109635,
               "5cb8323a2a6607f38860e6c79ec1ee9b2f37fb4468cd7cf053fb77838f17d496"),
    "rung_k4": (109637,
                "e40501335cd10bfe75c04cf49d5b184426472e420658c8c7ade794a17a7f0401"),
    "rung_p2": (107276,
                "fa11ed91ecf9662d446d123ee3c7b9ef190e099a8b40b3656ff92ab4ae80d677"),
    "rung_c6": (105384,
                "120b116474c7265ebe75bbb122b87e2d5c1db10f068f5c951de2d133d2b4a9ba"),
    "rung_w14": (105395,
                 "d207b45cae6a43a950cb641c75ad2f8c1c8d3698a4255bc61c973d0a6aa9d3ad"),
    "rung_e32": (105393,
                 "500aefdcf6655f4c40aeb8a36d9651b51992f8427bd6aa6981eb0bbc031c04a7"),
    "m125": (105382,
             "2e8cdb877d4938a63d92dc8f4b054e59ff296456c56063f61c1ad8e39e948d39"),
}

# The domains each zero-check slot HOSTS -- the same table the prediction
# module restates from `pad::pad_zero_host`, imported here rather than
# copied so that the two cannot drift apart silently.
HOSTS = {s: list(v[2]) for s, v in ZERO_CHECK_SLOTS.items()}

# Which domain's byte-limb LogUp lookups a slot carries.  `lookups_at`
# builds a list for six domains only; `Dom::T` has no byte limbs and
# `Dom::Tab`'s three helpers are the lookup TABLES' own columns, not byte
# limbs, so slots 02 and 19 are not in this table and neither is slot 20,
# whose single helper is the zero-sum row's.
LOGUP_DOMAIN = {s: v[1] for s, v in ZERO_CHECK_SLOTS.items()
                if v[1] in ("L", "D", "Q", "Kv", "S", "F")}
LOGUP_EXCLUDED = {
    2: "Dom::T has no byte-limb lookups: `lookups_at` builds nothing for "
       "it and the slot carries no helper column",
    19: "Dom::Tab's three helpers (H_GU8, H_GEXP, H_GACT) are the lookup "
        "TABLES' own value columns, not byte-limb lookups",
    20: "the single helper H_U is the zero-sum row's, not a lookup",
}
# The ONE extra pair helper `Dom::S` and `Dom::F` carry beyond their
# byte-limb helpers (`shape.rs:486-489`), named so it can be identified in
# the plane index rather than subtracted as a constant.
PAIR_HELPERS = {"H_SEXP", "H_FACT"}

BILINEAR = (8, 9)


def load_export(shape_key: str, directory: str = EXPORT_DIR) -> dict:
    """Read one shape's export and CHECK it against the lane's pin."""
    path = os.path.join(directory, f"slot_ir_{shape_key}.json")
    with open(path, "rb") as fh:
        raw = fh.read()
    want = PINNED.get(shape_key)
    got = (len(raw), hashlib.sha256(raw).hexdigest())
    if want is not None and got != want:
        raise ValueError(
            f"slot IR export {shape_key}: the file on disk is "
            f"{got[0]} bytes / {got[1][:12]} and the lane pins "
            f"{want[0]} bytes / {want[1][:12]}"
        )
    d = json.loads(raw.decode())
    if d.get("schema") != "zk60-slot-ir/1":
        raise ValueError(f"slot IR export {shape_key}: schema {d.get('schema')!r}")
    d["_pin_checked"] = want is not None
    d["_bytes"], d["_sha256"] = got
    return d


def _export_kind(tab: dict) -> str:
    """The export's alphabet, mapped to the capture's three kinds."""
    k = tab["kind"].split("(")[0]
    if k in ("eq", "group_eq"):
        return "eq"
    if k in ("pub", "supp"):
        return "pub"
    return "priv"          # A, H, EP -- a committed plane


def _capture_kind(tab: dict) -> str:
    k = tab["kind"]
    return {"eq": "eq", "public": "pub", "private": "priv"}.get(k, k)


# The export names an endpoint plane `EP` with the label `endpoint in` /
# `endpoint out`; the plane index names the same plane by its ROLE.
EP_ROLE = {"endpoint in": "Input", "endpoint out": "Output"}


def _export_private(tab: dict):
    """`(role, id)` of a committed table, in the plane index's own terms,
    out of the export's kind and label -- `A[80] on its own domain`,
    `H[46]`, `EP` + `endpoint in`."""
    k = tab["kind"]
    lab = tab["label"]
    if k == "EP":
        return (EP_ROLE.get(lab, lab), None)
    if "[" not in lab:
        return (k, None)
    return (k, int(lab.split("[", 1)[1].split("]", 1)[0]))


def _public_spec_names(slot: int) -> list:
    out = []
    for e in PUBLIC_SPEC.get(slot, []):
        kind = e[0]
        if kind == "supp":
            out.append(f"supp({e[1]})")
        elif kind == "captured":
            out.append(f"captured:{e[1]}")
        elif kind == "causal":
            out.append("causal")
        elif kind == "u8":
            out.append("u8")
        elif kind == "ones":
            out.append(f"ones({e[1]})")
        else:
            out.append(str(e))
    return out


# The export's own public-table labels, mapped to this port's PUBLIC_SPEC
# names.  Written out rather than pattern-matched, so that a NEW public
# table in the export is an unmapped label and therefore a disagreement,
# which is the point.
PUBLIC_LABEL_MAP = {
    "causal mask over the Dom::S cube": "causal",
    "the U8 table's value column": "u8",
    "the exp table's value column": "captured:exp_values",
    "the activation table's value column": "captured:act_values",
    "the all-ones vector over Dom::Tab": "ones(Tab)",
}
PUBLIC_LABEL_PREFIX = {
    "gamma_a": "captured:gamma_a",
    "gamma_m": "captured:gamma_m",
    "RoPE cos": "captured:rope_cos",
    "RoPE sin": "captured:rope_sin",
    "the weight matrix": None,        # decided by the slot, below
}
WEIGHT_OF_SLOT = {5: "fold(w_q)", 6: "fold(w_k)", 7: "fold(w_v)",
                  10: "fold(w_o)", 11: "fold(w_g)", 12: "fold(w_u)",
                  13: "fold(w_d)"}


def _export_public_name(slot: int, tab: dict):
    kind = tab["kind"]
    if kind.startswith("supp("):
        return kind
    lab = tab["label"]
    if lab in PUBLIC_LABEL_MAP:
        return PUBLIC_LABEL_MAP[lab]
    for pre, name in PUBLIC_LABEL_PREFIX.items():
        if lab.startswith(pre):
            if name is None:
                w = WEIGHT_OF_SLOT.get(slot)
                return f"captured:{w}" if w else None
            return name
    if "fold" in lab or "weight" in lab:
        w = WEIGHT_OF_SLOT.get(slot)
        return f"captured:{w}" if w else None
    return None


def compare(export: dict, bundle) -> dict:
    """Every comparison, per slot, with the disagreements listed apart."""
    sh = bundle.shape
    raw = sh.raw
    idx = bundle.run["plane_index"]
    logs = {}
    for p in idx["a_planes"] + idx["h_planes"]:
        logs.setdefault(p["domain"], p["log_size"])
    geom = PadGeometry(raw, logs)
    counts = _limb_counts(idx)
    lkv = (raw["kv_heads"] - 1).bit_length()
    args0 = bundle.stages[0].slots
    rows, dis = [], []

    def note(slot, what, mine, theirs):
        dis.append({"slot": slot, "what": what,
                    "the_export": theirs, "this_gate": mine})

    for s in range(sh.n_slots):
        e = export["slots"][s]
        a = args0[s]
        e_tabs = e["tables"]
        c_tabs = a["tables"]
        e_kinds = [_export_kind(t) for t in e_tabs]
        c_kinds = [_capture_kind(t) for t in c_tabs]
        e_priv = [_export_private(t) for t, k in zip(e_tabs, e_kinds)
                  if k == "priv"]
        pi = [(p["role"], p["id"]) for p in idx["slot_planes"][s]["planes"]]
        e_pub = [_export_public_name(s, t) for t, k in zip(e_tabs, e_kinds)
                 if k == "pub"]
        port_pub = _public_spec_names(s)
        # a `supp` entry is absent from the capture when the domain does
        # not pad, and the port's loader skips it there -- so the port's
        # expected list is filtered the same way before comparing
        port_pub_here = [n for n in port_pub
                         if not (n.startswith("supp(")
                                 and not geom.pads(n[5:-1]))]
        hosts = HOSTS.get(s, [])
        port_pad_on = any(geom.pads(d) for d in hosts) if hosts else False
        dom = LOGUP_DOMAIN.get(s)
        h_names = [p["name"] for p in idx["slot_planes"][s]["planes"]
                   if p["role"] == "H"]
        e_helpers = sum(1 for t in e_tabs if t["kind"] == "H")
        e_byte_limb_helpers = e_helpers - sum(1 for n in h_names
                                              if n in PAIR_HELPERS)
        if dom:
            port_lookups = len(lookups_at(dom, counts, raw))
            port_helpers = (port_lookups + 1) // 2
            logup_equal = port_helpers == e_byte_limb_helpers
        else:
            port_lookups = port_helpers = None
            logup_equal = True
        row = {
            "slot": s, "name": e["name"],
            "table_count": {"export": len(e_tabs), "capture": len(c_tabs),
                            "equal": len(e_tabs) == len(c_tabs)},
            "kind_sequence_equal": e_kinds == c_kinds,
            "private_sequence_equal": e_priv == pi,
            "public_sequence": {"export": e_pub, "this_gate": port_pub_here,
                                "equal": e_pub == port_pub_here},
            "declared_degree": {"export": e["declared_degree"],
                                "capture": a["degree"],
                                "shape": sh.slots[s][2],
                                "equal": e["declared_degree"] == a["degree"]
                                == sh.slots[s][2]},
            "rounds": {"export": [e["main_rounds"], e["extension_rounds"]],
                       "capture": [a["main"], a["extension"]],
                       "equal": [e["main_rounds"], e["extension_rounds"]]
                       == [a["main"], a["extension"]]},
            "pad_on": {"export": e["pad_on"], "this_gate": port_pad_on,
                       "hosts": hosts, "equal": e["pad_on"] == port_pad_on},
            "group_bits": {"export": e["group_bits"],
                           "this_gate": lkv if s in BILINEAR else None,
                           "equal": e["group_bits"]
                           == (lkv if s in BILINEAR else None)},
            "logup": {"domain": dom,
                      "export_helper_tables": e_helpers,
                      "export_byte_limb_helpers": e_byte_limb_helpers,
                      "pair_helpers_excluded_by_name":
                          [n for n in h_names if n in PAIR_HELPERS],
                      "this_gate_lookups": port_lookups,
                      "this_gate_helpers": port_helpers,
                      "not_compared_because": LOGUP_EXCLUDED.get(s)
                      if dom is None else None,
                      "equal": logup_equal},
            "max_product_degree": e["max_product_degree"],
        }
        rows.append(row)
        if not row["table_count"]["equal"]:
            note(s, "table count", len(c_tabs), len(e_tabs))
        if not row["kind_sequence_equal"]:
            note(s, "table kind sequence", c_kinds, e_kinds)
        if not row["private_sequence_equal"]:
            note(s, "the private plane sequence", pi, e_priv)
        if not row["public_sequence"]["equal"]:
            note(s, "the public table sequence", port_pub_here, e_pub)
        if not row["declared_degree"]["equal"]:
            note(s, "declared degree", a["degree"], e["declared_degree"])
        if not row["rounds"]["equal"]:
            note(s, "main / extension rounds", [a["main"], a["extension"]],
                 [e["main_rounds"], e["extension_rounds"]])
        if not row["pad_on"]["equal"]:
            note(s, "pad_on", port_pad_on, e["pad_on"])
        if not row["group_bits"]["equal"]:
            note(s, "group_bits", lkv if s in BILINEAR else None,
                 e["group_bits"])
        if not row["logup"]["equal"]:
            note(s, "the LogUp byte-limb helper count", port_helpers,
                 e_byte_limb_helpers)
    return {
        "shape": export["shape"],
        "profile": export["profile"],
        "bundle": os.path.basename(bundle.dir.rstrip("/")),
        "export_bytes": export["_bytes"],
        "export_sha256": export["_sha256"],
        "export_pin_checked": export["_pin_checked"],
        "tables_total": export["tables"],
        "tables_base_field": export["tables_base_field"],
        "slots": rows,
        "comparisons": 8 * sh.n_slots,
        "disagreements": dis,
        "ok": not dis,
    }


def _limb_counts(idx: dict) -> dict:
    """`TerminalGate.counts`: how many byte limbs each family has, counted
    from the plane index's own names (`A_NR*`, `A_SR*`, `A_PL*`)."""
    names = [p["name"] for p in idx["a_planes"]]

    def group(prefix):
        return sum(1 for n in names if n.startswith(prefix)
                   and n[len(prefix):].isdigit())
    return {"ln": group("A_NR"), "ls": group("A_SR"), "lp": group("A_PL")}


WHAT = (
    "the lane's stage-34 slot-expression IR export, read as a CROSS-CHECK "
    "of this gate's hand port (ruling I-8).  Eight structural comparisons "
    "per slot at every shape a bundle exists for.  Nothing here is "
    "evaluated and nothing here is consumed by the terminal identity: a "
    "disagreement is a question about which side is wrong, answered by "
    "reading the Rust arm"
)
NOT = (
    "not a check of the prover, not a privacy statement, and not a "
    "replacement for the hand port.  The export carries no challenge "
    "value, so agreement here says the two agree about the SHAPE of every "
    "slot polynomial and says nothing about any number the gate computes"
)


def run(pairs: list) -> dict:
    """One shape at a time, and the bundle RELEASED before the next.

    A `RunBundle` at 125M opens a 281 MB array store and at rung-W14 a
    42 MB one.  Nothing here needs two of them at once, and inside the
    whole native suite -- one process, every module -- the difference
    between holding them and dropping them is the difference between
    finishing and being killed at `MemoryMax=4G`.  Round 9c's closing
    sequence was killed twice before this was written down."""
    out = {"what": WHAT, "what_this_is_not": NOT, "per_shape": []}
    for key, bundle_dir in pairs:
        export = load_export(key)
        b = RunBundle(bundle_dir)
        out["per_shape"].append(compare(export, b))
        del b, export
        gc.collect()
    out["shapes"] = len(out["per_shape"])
    out["comparisons"] = sum(x["comparisons"] for x in out["per_shape"])
    out["disagreements"] = sum(len(x["disagreements"])
                               for x in out["per_shape"])
    out["ok"] = all(x["ok"] for x in out["per_shape"])
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--pair", action="append", default=[],
                    metavar="SHAPE_KEY:BUNDLE_DIR", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", default="slot_ir_crosscheck")
    args = ap.parse_args(argv)
    pairs = [tuple(p.split(":", 1)) for p in args.pair]
    out = run(pairs)
    os.makedirs(args.evidence, exist_ok=True)
    path = os.path.join(args.evidence, f"{args.name}.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    for x in out["per_shape"]:
        print(f"{x['shape']:10s} {x['bundle']:24s} "
              f"{x['comparisons']} comparisons, "
              f"{len(x['disagreements'])} disagreements")
        for d in x["disagreements"]:
            print(f"    slot {d['slot']:2d} {d['what']}: "
                  f"this gate {d['this_gate']!r}, the export {d['the_export']!r}")
    print(f"record: {path}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
