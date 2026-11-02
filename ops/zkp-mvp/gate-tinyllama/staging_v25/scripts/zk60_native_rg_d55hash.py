#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02, TS / CENSUS lane] The hash layer and the Python
HASH CENSUS on a D55 "commit, fork, join" fork-run capture.

    python3 -B zk60_native_rg_d55hash.py --bundle <D55 capture> --evidence <dir> --name <name> [--no-controls]
    (the D55 driver `zk60_native_rg_d55.d55_gate` calls `d55_hash` for an R13 base)

HASH-1  THE HASH LAYER, computed (D12a's run gate stage 9,
        `zk60_native_rg_hashlayer.check_hash_layer`, ported to the D55
        layout).  Every opened column of every fork's M, A and H (the D12a
        function, unchanged: a D55 bundle's `stages` are its forks) AND of
        every tail opening (each internal boundary, both external endpoints:
        the same fold, written here because the tail carries no M) re-hashed
        and its Merkle path re-folded under the rule the loader DERIVED from
        the block profile (D19, ruling T-7): leaf = H_column(column bytes),
        salted = H_leaf(leaf || salt), root = fold H_node; the path depth
        checked against the tree.  Controls, each must fire (in memory, the
        files untouched, every edit restored): the D12a cross-rule probe
        (legacy and three role-permuted key sets on fork 0's A column: none
        may reach the root); HL-2 every opened column of the run under the key
        set DERIVED for another registered R13 block profile (CH-7's
        construction without a second bundle): 0 authenticate; HL-3 the
        tail's columns under the legacy rule: 0 authenticate; HL-4 one tail
        column's value moved by one; HL-5 one fork column's salt byte
        flipped; HL-6 one tail path one entry short (refused by the depth
        check); HL-7 two tail openings' roots exchanged (none of either's
        columns folds); HR-1 / HR-2 / HR-3 the declared `hash_tag`'s key,
        context and profile altered (refused by the derivation, D12a's CH-1
        .. CH-3); HR-4 the D55 header absorbed under the legacy rule does not
        reproduce `run_binding` (the derived rule does).

HASH-2  THE HASH CENSUS, MEASURED (gate round 22's `round22/census/
        hash_census.py`, ported from the classifier replay to the D55 one,
        and widened to every BLAKE3 function the gate computes): while this
        process (1) derives the four tag keys, (2) recomputes the registered
        schedule digest, (3) replays the whole D55 transcript (header, phase
        1, every fork, the join, the tail) and (4) re-folds every opened
        column, EVERY BLAKE3 call is recorded BY LENGTH ONLY (no value is kept)
        and classified by the function that hashes it -- the mode and the key,
        as s25's W-2 census defines it: F_T the transcript key, F_C the
        column key, F_L the leaf key, F_N the node key, K derive_key (its
        context), F_U unkeyed.  The transcript calls are also recorded by KIND
        (constructor, `absorb` of a label with d bytes, squeeze), and the two
        accounts must agree.  The conditions:
          C-R1  no F_U input on the gate's path is 40 bytes (the generator's
                refill length, `rng.rs`);
          C-R2  no transcript constructor input is 47 bytes (the squeeze);
          W-2   (D36 §3 step 5 / hash_census.py) the constructor's length
                equals no other F_T input's and is not one byte from any;
          W-2g  (s25's generalised rule) per function, no two DIFFERENT kinds
                of equal length unless the pair is DECLARED with the fixed
                literal that separates them (s25_tests.rs `DECLARED`, ported
                with its reasons); every pair within one byte is LISTED, not
                failed;
          ACC   every BLAKE3 call is attributed to exactly one of the six
                functions (a keyed call under any other key is a finding),
                and the F_T multiset equals the transcript's own account.
        Optionally (`ZK60_S25_W2_PRINTOUT` names the Rust s25 W-2 census's
        printout; its SHA-256 is recorded) every measured F_T / F_C / F_L /
        F_N / K kind is looked up in the Rust table for the bundle's run
        profile: a measured kind the Rust arithmetic does not list is a
        finding.  Controls (each must fire; each makes REAL BLAKE3 calls
        through the same recorder on doctored inputs, merged into the honest
        measurement): HC-1 a 35-byte transcript domain (constructor 47 B,
        C-R2), HC-2 a domain making the constructor exactly as long as the
        commonest absorb (W-2), HC-3 one byte longer (W-2's margin), HC-4 an
        unkeyed 40-byte input (C-R1), HC-5 an absorb of a new label whose
        input is as long as an existing absorb of another label (W-2g), HC-6
        a keyed call under a key no rule derives (ACC), and with a printout
        HC-7 a `parameters` absorb 64 bytes longer than the run's (the Rust-
        table lookup must name it).

WHAT IS NOT MEASURED HERE.  The prover's own calls (the generator's refill
and seed derivations, R1; the commit-phase / per-fork seed domains) and the
statement digests the gate does not recompute from a capture (D1 calibration
identity, D2 block public digest, D3 / D4 / D7) never run in this process;
the Rust s25 W-2 census covers them by arithmetic.

NOTHING HERE IS A PRIVACY STATEMENT.  These are facts about which hash
function hashed which input length, and about the verifier's authentication
of the columns it opened; what an unopened leaf hides stays a hash
assumption (M-2, M-3).
"""

from __future__ import annotations

import argparse
import collections
import copy
import hashlib
import json
import os
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_jv_field as F  # noqa: E402
import zk60_native_rg_hashrule as HR  # noqa: E402
from zk60_native_rg_hashlayer import check_hash_layer, column_bytes  # noqa: E402

TAIL_FILE = "d55_tail.json"
REFILL_LEN = 40          # rng.rs: the generator's refill block (C-R1)
SQUEEZE_LEN = 32 + 7 + 8  # state || "squeeze" || le64(counter)  (C-R2)

# s25_tests.rs `every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length`,
# DECLARED (:667-742): (length, a, b, the separating literal); a and b are
# substrings of the kinds' plain-words names, matched in either order
DECLARED = (
    (66, "`pb-fork-s0`", "`pb-fork-s1`", "the labels themselves: \"pb-fork-s0\" against \"pb-fork-s1\", which differ at offset 49 (after the state and le64(10)); the data is the same le64(L) in both"),
    (60, "the transcript constructor at", "the transcript absorb of `rows`", "le64(4) || \"rows\" || le64(8): fourteen positions forced to NUL inside the two length fields, where the constructor carries the profile's ASCII (stage 32 / s33 J-7a)"),
    (63, "the transcript constructor at", "the transcript absorb of `pb-slot`", "le64(7) || \"pb-slot\" || le64(8): fourteen positions forced to NUL inside the two length fields (M26 / s33 J-7a)"),
    (49, "the transcript key's derive_key context", "the leaf key's derive_key context", "the context strings themselves (fixed public literals that differ byte for byte)"),
    (64, "a salted Merkle leaf", "a Merkle inner node", "NOTHING under the legacy rule (claim B-7, ruling L-7); under a tag the leaf and node keys separate them"),
    (64, "`log-cols`", "a salted Merkle leaf", "le64(8) || \"log-cols\" || le64(8), 24 fixed bytes at offset 32"),
    (64, "`log-cols`", "a Merkle inner node", "le64(8) || \"log-cols\" || le64(8), 24 fixed bytes at offset 32"),
    (81, "the transcript absorb of `", "the transcript absorb of `", "the one-byte label at offset 40, after the state and le64(1)"),
    (171, "`expected-IO`", "`parameters`", "le64(11) || \"expected-IO\" against le64(10) || \"parameters\", at offset 32"),
    (295, "`parameters`", "`pb-term`", "le64(10) || \"parameters\" against le64(7) || \"pb-term\", at offset 32"),
)
FUNCS = ("F_T", "F_C", "F_L", "F_N", "K", "F_U")


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _label(what):
    """the label of an absorb kind's plain-words name, or None"""
    pre = "the transcript absorb of `"
    return what[len(pre):].split("`", 1)[0] if what.startswith(pre) else None


def declared(length, a, b):
    """s25's matcher, with one tightening: the 81-byte row (two absorbs
    separated by a ONE-BYTE label at offset 40) is applied only when both
    labels are one byte long"""
    for ln, x, y, why in DECLARED:
        if ln == length and ((x in a and y in b) or (y in a and x in b)):
            if x == y:
                la, lb = _label(a), _label(b)
                if la is None or lb is None or len(la) != 1 or len(lb) != 1:
                    continue
            return why
    return None


# ---------------------------------------------------------------- HASH-1: the hash layer
def tail_openings(b):
    out = []
    for i, r in enumerate(b.tail.roles):
        p = r["params"]
        out.append({"name": b.tail.key_at(i), "kind": r["commitment_kind"], "root": r["commitment"]["root"],
                    "rows": r["commitment"]["rows"], "columns": r["columns"], "enc_cols": (1 << p["log_cols"]) * p["inv_rate"],
                    "checks": p["num_col_checks"]})
    return out


def fold_openings(rule, openings, where="tail"):
    """check_hash_layer's per-opening fold, for openings outside a stage file
    (the D55 tail): the same leaf, salt, node and depth rules"""
    out = {"openings": 0, "columns_checked": 0, "columns_authenticated": 0, "path_depth_checked": 0, "bytes_hashed": 0,
           "per_opening": [], "findings": [], "salted": set()}
    for op in openings:
        depth = (op["enc_cols"] - 1).bit_length()
        root = bytes(op["root"])
        n_ok = 0
        for c in op["columns"]:
            out["columns_checked"] += 1
            if len(c["path"]) != depth:
                out["findings"].append(f"{where} {op['name']}: column {c['index']} carries a path of {len(c['path'])} entries; the tree is {depth} deep")
                continue
            out["path_depth_checked"] += 1
            if not 0 <= c["index"] < op["enc_cols"]:
                out["findings"].append(f"{where} {op['name']}: column index {c['index']} outside the encoded domain {op['enc_cols']}")
                continue
            if len(c["values"]) != op["rows"]:
                out["findings"].append(f"{where} {op['name']}: column {c['index']} has {len(c['values'])} entries for {op['rows']} rows")
                continue
            cb = column_bytes(c["values"])
            out["bytes_hashed"] += len(cb)
            salted = rule.salt_leaf(rule.column_digest(cb), bytes(c["salt"]))
            out["salted"].add(salted)
            if rule.verify_path(root, c["index"], salted, [bytes(x) for x in c["path"]]):
                n_ok += 1
                out["columns_authenticated"] += 1
            else:
                out["findings"].append(f"{where} {op['name']}: the Merkle path of column {c['index']} does not fold to the committed root")
        out["openings"] += 1
        out["per_opening"].append({"opening": op["name"], "kind": op["kind"], "rows": op["rows"], "encoded_columns": op["enc_cols"],
                                   "depth": depth, "opened": len(op["columns"]), "authenticated": n_ok, "root": root.hex()[:16]})
    return out


def d55_hash_layer(b, rule=None, probe=True):
    r = rule if rule is not None else b.hash_rule
    if r is None:
        return {"findings": ["the hash rule was refused for this bundle; no column was re-hashed"], "ok": False}
    forks = check_hash_layer(b, rule=r, probe=probe)
    tail = fold_openings(r, tail_openings(b))
    salted = tail.pop("salted")
    rec = {"what": "every opened column of every fork (M, A, H: check_hash_layer, unchanged) and of every tail opening (each "
                   "boundary, both endpoints: the same fold) re-hashed and its Merkle path re-folded under the DERIVED rule",
           "hash_rule": r.name, "forks": forks, "tail": tail,
           "openings": forks.get("openings", 0) + tail["openings"],
           "columns_checked": forks.get("columns_checked", 0) + tail["columns_checked"],
           "columns_authenticated": forks.get("columns_authenticated", 0) + tail["columns_authenticated"],
           "distinct_salted_leaves_forks": forks.get("distinct_salted_leaves", 0), "distinct_salted_leaves_tail": len(salted),
           "findings": list(forks.get("findings", [])) + tail["findings"]}
    rec["ok"] = (bool(forks.get("ok")) and not tail["findings"] and tail["columns_authenticated"] == tail["columns_checked"]
                 and rec["columns_checked"] > 0)
    return rec


def other_r13_profile(block):
    import zk60_native_rg_r13slots as R
    profiles = sorted(p for p in R.ACCURACY_PROFILES if p != block)
    pref = [p for p in profiles if "rung-lh" in p] if "rung" not in block else [p for p in profiles if "llama-3-8b-t128-lh24-v1" in p]
    return (pref or profiles)[0]


def _header_binding(b, rule):
    d = b.run
    tr = rule.transcript(bytes(d["transcript_domain_bytes"]))
    tr.absorb(b"run-shape", b"".join(int(v).to_bytes(8, "little") for v in d["run_shape_words"]))
    tr.absorb(b"expected-IO", bytes(d["expected_policy"]))
    tr.absorb(b"public-statement", bytes(d["public_statement_digest"]))
    tr.absorb(b"parameters", d["parameter_line"].encode())
    tr.absorb(b"calibration", bytes(d["calibration"]))
    tr.absorb(b"schedule", bytes(d["schedule_digest"]))
    return list(tr.state) == d["run_binding"]


def _with_tag(b, mutate):
    keep = b.run.get("hash_tag")
    try:
        tag = copy.deepcopy(keep) if keep is not None else None
        tag = mutate(tag)
        if tag is None:
            b.run.pop("hash_tag", None)
        else:
            b.run["hash_tag"] = tag
        return HR.rule_for_bundle(b)
    finally:
        if keep is None:
            b.run.pop("hash_tag", None)
        else:
            b.run["hash_tag"] = keep


def hash_layer_controls(b):
    out = {}
    rule = b.hash_rule
    block = b.run["shape"]["profile"]
    # HL-2: another registered R13 block profile's derived key set, every opened column
    other = other_r13_profile(block)
    ro = HR.HashRule.for_profile(other)
    f2 = check_hash_layer(b, rule=ro, probe=False)
    t2 = fold_openings(ro, tail_openings(b))
    t2.pop("salted")
    n2 = f2["columns_checked"] + t2["columns_checked"]
    a2 = f2["columns_authenticated"] + t2["columns_authenticated"]
    out["HL-2 another R13 profile's derived key set"] = {"other_profile": other, "columns_checked": n2, "columns_authenticated": a2,
                                                         "fires": n2 > 0 and a2 == 0}
    # HL-3: the tail under the legacy rule
    t3 = fold_openings(HR.HashRule.legacy(), tail_openings(b))
    t3.pop("salted")
    out["HL-3 the tail's columns under the legacy rule"] = {"columns_checked": t3["columns_checked"],
                                                           "columns_authenticated": t3["columns_authenticated"],
                                                           "fires": t3["columns_checked"] > 0 and t3["columns_authenticated"] == 0}

    def one_tail(i, mutate, what, name):
        role = b.tail.roles[i]
        keep = copy.deepcopy(role["columns"][0])
        try:
            mutate(role["columns"][0])
            ops = [o for o in tail_openings(b)][i:i + 1]
            ops[0]["columns"] = ops[0]["columns"][:1]
            r = fold_openings(rule, ops)
        finally:
            role["columns"][0] = keep
        restored = fold_openings(rule, [dict(tail_openings(b)[i], columns=tail_openings(b)[i]["columns"][:1])])["columns_authenticated"] == 1
        out[name] = {"what": what, "opening": b.tail.key_at(i), "authenticated": r["columns_authenticated"],
                     "findings": r["findings"][:1], "restored": restored, "fires": r["columns_authenticated"] == 0 and restored}

    def bump(c):
        v = list(c["values"])
        v[0] = (int(v[0]) + 1) % F.P
        c["values"] = v
    last = len(b.tail.roles) - 1
    one_tail(last, bump, "the first value of the first opened column moved by one", "HL-4 a tail column's value moved")

    def short(c):
        c["path"] = list(c["path"])[:-1]
    one_tail(0, short, "the first opened column's Merkle path one entry short", "HL-6 a tail path one entry short")
    # HL-5: one fork column's salt byte flipped (fork 1's H, or fork 0's)
    st = b.stages[1 if len(b.stages) > 1 else 0]
    h = st.roles[1]
    keep = copy.deepcopy(h["columns"][0])
    try:
        s = list(h["columns"][0]["salt"])
        s[0] = (int(s[0]) ^ 1) & 0xFF
        h["columns"][0]["salt"] = s
        op = {"name": f"fork {st.index} H", "kind": "block", "root": h["commitment"]["root"], "rows": h["commitment"]["rows"],
              "columns": h["columns"][:1], "enc_cols": (1 << h["params"]["log_cols"]) * h["params"]["inv_rate"], "checks": 1}
        r5 = fold_openings(rule, [op], where="fork")
    finally:
        h["columns"][0] = keep
    op["columns"] = h["columns"][:1]
    ok5 = fold_openings(rule, [op], where="fork")["columns_authenticated"] == 1
    out["HL-5 a fork column's salt byte flipped"] = {"opening": op["name"], "authenticated": r5["columns_authenticated"], "restored": ok5,
                                                     "fires": r5["columns_authenticated"] == 0 and ok5}
    # HL-7: two tail openings' roots exchanged
    ops = tail_openings(b)
    i, j = 0, len(ops) - 2 if len(ops) > 2 else len(ops) - 1
    ops[i]["root"], ops[j]["root"] = ops[j]["root"], ops[i]["root"]
    r7 = fold_openings(rule, [ops[i], ops[j]])
    out["HL-7 two tail openings' roots exchanged"] = {"openings": [ops[i]["name"], ops[j]["name"]], "columns_checked": r7["columns_checked"],
                                                      "columns_authenticated": r7["columns_authenticated"],
                                                      "fires": r7["columns_checked"] > 0 and r7["columns_authenticated"] == 0}
    # HR-1 .. HR-3: the declared tag altered; HR-4: the header under the legacy rule
    if b.run.get("hash_tag") is not None:
        def key_alt(t):
            t["keys_hex"]["leaf"] = ("0" if t["keys_hex"]["leaf"][0] != "0" else "1") + t["keys_hex"]["leaf"][1:]
            return t

        def ctx_alt(t):
            t["contexts"]["node"] = t["contexts"]["node"] + " "
            return t

        def prof_alt(t):
            t["profile"] = other
            return t
        for name, mut in (("HR-1 one declared key altered", key_alt), ("HR-2 one declared context altered", ctx_alt),
                          ("HR-3 the declared profile altered", prof_alt)):
            rr = _with_tag(b, mut)
            out[name] = {"refusals": rr["refusals"][:2], "fires": bool(rr["refusals"]) and rr["rule"] is None}
    honest = _header_binding(b, rule)
    legacy = _header_binding(b, HR.HashRule.legacy())
    out["HR-4 the D55 header under the legacy rule"] = {"derived_rule_reproduces_run_binding": honest,
                                                        "legacy_rule_reproduces_run_binding": legacy, "fires": honest and not legacy}
    out["ok"] = all(v["fires"] for v in out.values() if isinstance(v, dict))
    return out


# ---------------------------------------------------------------- HASH-2: the census
class Recorder:
    """every BLAKE3 call made while active, by (function, input length),
    and every transcript call by kind; values are never kept"""

    def __init__(self, rule):
        self.rule = rule
        self.keys = {} if rule is None or rule.is_legacy else {rule.keys[r]: f for r, f in
                                                               (("transcript", "F_T"), ("column", "F_C"), ("leaf", "F_L"), ("node", "F_N"))}
        self.calls = collections.Counter()      # (func, len) -> n
        self.u_sites = collections.Counter()    # (len, caller) -> n   (F_U)
        self.k_ctx = collections.Counter()      # (context, material len) -> n
        self.unknown_keyed = collections.Counter()
        self.t_kinds = collections.Counter()    # (kind, len) -> n     (transcript level)
        self.c_rows = collections.Counter()     # F_C length -> n
        self._saved = None

    # -- the BLAKE3 level
    def _wrap(self):
        import blake3 as B3
        rec = self
        orig = B3.blake3

        class Counting:
            def __init__(self, data=b"", **kw):
                self._kw = {k: v for k, v in kw.items() if v is not None}
                self._h = orig(data, **self._kw) if data else orig(**self._kw)
                self._n = len(data)
                fr = sys._getframe(1)
                self._site = f"{os.path.basename(fr.f_code.co_filename)}:{fr.f_code.co_name}"

            def update(self, data):
                self._n += len(data)
                self._h.update(data)
                return self

            def _note(self):
                key, ctx = self._kw.get("key"), self._kw.get("derive_key_context")
                if ctx is not None:
                    rec.k_ctx[(ctx if isinstance(ctx, str) else bytes(ctx).decode(), self._n)] += 1
                    rec.calls[("K", len(ctx))] += 1
                elif key is None:
                    rec.calls[("F_U", self._n)] += 1
                    rec.u_sites[(self._n, self._site)] += 1
                else:
                    f = rec.keys.get(bytes(key))
                    if f is None:
                        rec.unknown_keyed[(bytes(key).hex()[:16], self._n)] += 1
                    else:
                        rec.calls[(f, self._n)] += 1

            def digest(self, *a, **kw):
                self._note()
                return self._h.digest(*a, **kw)

            def hexdigest(self, *a, **kw):
                self._note()
                return self._h.hexdigest(*a, **kw)

            def copy(self):
                c = Counting.__new__(Counting)
                c._kw, c._h, c._n, c._site = self._kw, self._h.copy(), self._n, self._site
                return c
        return B3, orig, Counting

    # -- the transcript level
    def _wrap_transcripts(self):
        rec = self
        saved = []
        for cls in (F.Transcript, HR.KeyedTranscript):
            init, absorb, squeeze = cls.__dict__.get("__init__"), cls.__dict__.get("absorb"), cls.__dict__.get("_squeeze")
            saved.append((cls, init, absorb, squeeze))

            def _init(self, *a, _init=init, _cls=cls, **kw):
                st = kw.get("state")
                if _cls is HR.KeyedTranscript:
                    domain = kw.get("domain", a[1] if len(a) > 1 else None)
                    st = kw.get("state", a[2] if len(a) > 2 else None)
                else:
                    domain = kw.get("domain", a[0] if a else None)
                    st = kw.get("state", a[1] if len(a) > 1 else None)
                if st is None and domain is not None:
                    d = bytes(domain)
                    rec.t_kinds[(f"the transcript constructor at `{d.decode(errors='replace')}`", 12 + len(d))] += 1
                _init(self, *a, **kw)

            def _absorb(self, label, data, _absorb=absorb):
                lab = bytes(label).decode(errors="replace")
                rec.t_kinds[(f"the transcript absorb of `{lab}` with {len(data)} bytes of data", 48 + len(label) + len(data))] += 1
                return _absorb(self, label, data)

            def _squeeze(self, _squeeze=squeeze):
                rec.t_kinds[("a transcript squeeze", SQUEEZE_LEN)] += 1
                return _squeeze(self)
            cls.__init__, cls.absorb, cls._squeeze = _init, _absorb, _squeeze
        return saved

    def __enter__(self):
        B3, orig, Counting = self._wrap()
        B3.blake3 = Counting
        self._saved = (B3, orig, self._wrap_transcripts())
        return self

    def __exit__(self, *exc):
        B3, orig, saved = self._saved
        B3.blake3 = orig
        for cls, init, absorb, squeeze in saved:
            cls.__init__, cls.absorb, cls._squeeze = init, absorb, squeeze
        return False

    def merged(self, other):
        m = Recorder(self.rule)
        for a in ("calls", "u_sites", "k_ctx", "unknown_keyed", "t_kinds"):
            setattr(m, a, getattr(self, a) + getattr(other, a))
        return m


def kinds(rec: Recorder) -> list:
    """every measured kind as (func, len, what)"""
    out = set()
    tag = rec.rule is not None and not rec.rule.is_legacy
    for (what, ln) in rec.t_kinds:
        out.add(("F_T" if tag else "F_U", ln, what))
    ctx_role = {v: k for k, v in HR.CONTEXTS.items()}
    for (ctx, _n) in rec.k_ctx:
        out.add(("K", len(ctx), f"the {ctx_role.get(ctx, '?')} key's derive_key context"))
    for (f, ln) in rec.calls:
        if f == "F_C":
            out.add((f, ln, f"a commitment column digest of {ln // 8} rows"))
        elif f == "F_L":
            out.add((f, ln, "a salted Merkle leaf"))
        elif f == "F_N":
            out.add((f, ln, "a Merkle inner node"))
    for (ln, site) in rec.u_sites:
        if tag:
            out.add(("F_U", ln, f"an unkeyed BLAKE3 input recomputed by the gate ({site})"))
    return sorted(out)


def evaluate(rec: Recorder, rust=None) -> dict:
    ks = kinds(rec)
    tag = rec.rule is not None and not rec.rule.is_legacy
    f = []
    ctor = sorted({ln for (fn, ln, w) in ks if w.startswith("the transcript constructor at")})
    t_lens = {ln for (fn, ln, w) in ks if fn == ("F_T" if tag else "F_U") and not w.startswith("the transcript constructor at")}
    u_lens = sorted({ln for (fn, ln) in rec.calls if fn == "F_U"})
    cr1 = REFILL_LEN not in u_lens
    cr2 = all(c != SQUEEZE_LEN for c in ctor)
    others = t_lens | {SQUEEZE_LEN}
    w2 = {str(c): sorted(x for x in others if abs(x - c) <= 1) for c in ctor}
    w2_ok = all(not v for v in w2.values())
    if not cr1:
        f.append(f"C-R1: an F_U input of {REFILL_LEN} bytes is on the gate's path")
    if not cr2:
        f.append(f"C-R2: a transcript constructor input is {SQUEEZE_LEN} bytes (the squeeze length)")
    if not w2_ok:
        f.append(f"W-2: a constructor length is equal to or one byte from another F_T input: {w2}")
    # W-2g: per function, equal-length DIFFERENT kinds must be declared
    by = collections.defaultdict(list)
    for fn, ln, w in ks:
        if w not in by[(fn, ln)]:
            by[(fn, ln)].append(w)
    declared_pairs, undeclared = [], []
    for (fn, ln), ws in sorted(by.items()):
        for i in range(len(ws)):
            for j in range(i + 1, len(ws)):
                why = declared(ln, ws[i], ws[j])
                (declared_pairs if why else undeclared).append({"func": fn, "len": ln, "a": ws[i], "b": ws[j], **({"why": why} if why else {})})
    if undeclared:
        f.append(f"W-2g: {len(undeclared)} undeclared pair(s) of different kinds of equal length in one function: {undeclared[:3]}")
    flat = sorted(ks, key=lambda k: (k[1], k[2]))
    one_byte = [f"{a[1]} B {a[2]} ({a[0]}) vs {b_[1]} B {b_[2]} ({b_[0]})" for i, a in enumerate(flat) for b_ in flat[i + 1:] if b_[1] == a[1] + 1]
    # ACC: every call attributed; F_T at the BLAKE3 level = the transcript's account
    t_level = collections.Counter()
    for (what, ln), n in rec.t_kinds.items():
        t_level[ln] += n
    b_level = collections.Counter({ln: n for (fn, ln), n in rec.calls.items() if fn == ("F_T" if tag else "F_U")})
    if not tag:
        # under the legacy rule every unkeyed call is F_U; compare the transcript lengths only
        b_level = collections.Counter({ln: min(n, b_level.get(ln, 0)) for ln, n in t_level.items()})
    acc_ok = not rec.unknown_keyed and t_level == b_level
    if rec.unknown_keyed:
        f.append(f"ACC: {sum(rec.unknown_keyed.values())} keyed call(s) under a key no rule derives: {dict(list(rec.unknown_keyed.items())[:3])}")
    if t_level != b_level:
        f.append("ACC: the transcript calls at the BLAKE3 level are not the transcript's own account")
    out = {"what": "every BLAKE3 call of the gate's own D55 path (the key derivation, the registered schedule digest, the whole D55 "
                   "replay, every opened column's fold), recorded by (function, input length) only, and every transcript call by kind",
           "functions": {fn: {str(ln): n for (f_, ln), n in sorted(rec.calls.items()) if f_ == fn} for fn in FUNCS},
           "calls": sum(rec.calls.values()), "transcript_calls": sum(rec.t_kinds.values()),
           "kinds": [{"func": a, "len": b_, "what": c} for a, b_, c in ks],
           "constructor_lengths": ctor, "F_U_lengths": u_lens,
           "C-R1_no_40_byte_F_U_input": cr1, "C-R2_constructor_not_47": cr2,
           "W-2_constructor_lengths_and_their_neighbours_within_1": w2, "W-2_holds": w2_ok,
           "W-2g_declared_pairs": declared_pairs, "W-2g_undeclared_pairs": undeclared, "W-2g_holds": not undeclared,
           "pairs_within_one_byte": one_byte, "ACC_every_call_attributed": acc_ok,
           "unknown_keyed_calls": {f"{k[0]}:{k[1]}": v for k, v in rec.unknown_keyed.items()},
           "transcript_query_count_measured": sum(rec.t_kinds.values())}
    if rust is not None:
        out["rust_table"] = rust_compare(ks, rust)
        if not out["rust_table"]["ok"]:
            f.append(f"the Rust s25 W-2 table does not list {len(out['rust_table']['measured_not_in_rust'])} measured kind(s)")
    out["findings"] = f
    out["ok"] = not f
    return out


def rust_table(path, profile):
    """the s25 W-2 printout's kinds for `profile` (every block of it, at
    every L): {(func, len, what)}"""
    rows, cur = set(), False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("--- "):
                cur = line.startswith(f"--- {profile} (")
                continue
            if cur and line.startswith("    ") and " B  " in line:
                left, _, rest = line.strip().partition(" B  ")
                fn, _, what = rest.partition(" ")
                try:
                    rows.add((fn.strip(), int(left), what.strip()))
                except ValueError:
                    pass
    return rows


def rust_compare(ks, rust):
    table, path, sha = rust["table"], rust["path"], rust["sha256"]
    names = {(fn, ln) for fn, ln, _w in table}
    whats = {(fn, ln, w) for fn, ln, w in table}
    missing = []
    for fn, ln, w in ks:
        if fn == "F_U":
            continue      # the gate's own unkeyed recomputations are named by call site here, by digest there
        if fn == "F_T":
            if (fn, ln, w) not in whats:
                missing.append({"func": fn, "len": ln, "what": w})
        elif (fn, ln) not in names:
            missing.append({"func": fn, "len": ln, "what": w})
    return {"printout": path, "printout_sha256": sha, "rust_kinds_for_this_profile": len(table),
            "measured_compared": sum(1 for k in ks if k[0] != "F_U"), "measured_not_in_rust": missing, "ok": bool(table) and not missing}


def measure(b) -> Recorder:
    import zk60_native_rg_d55 as D
    import zk60_native_rg_d55r13 as X
    rec = Recorder(b.hash_rule)
    with rec:
        HR.HashRule.for_profile(b.run["shape"]["profile"])
        X.registered_schedule_digest(b.run)
        rp = D.D55Replay(b).run()
        hl = d55_hash_layer(b, probe=False)
    rec.replay_ok = rp.summary().get("ok")
    rec.hash_layer_ok = hl.get("ok")
    return rec


def census_controls(b, honest: Recorder, rust=None) -> dict:
    rule = b.hash_rule
    out = {}
    common = collections.Counter({ln: n for (w, ln), n in honest.t_kinds.items() if "absorb" in w}).most_common(1)[0][0]

    def with_calls(fn):
        r = Recorder(rule)
        with r:
            fn()
        return evaluate(honest.merged(r), rust=None)

    def ctor(n):
        return lambda: rule.transcript(b"x" * n)
    e1 = with_calls(ctor(SQUEEZE_LEN - 12))
    out["HC-1 a 35-byte transcript domain (constructor = the squeeze length)"] = {"C-R2": e1["C-R2_constructor_not_47"], "fires": e1["C-R2_constructor_not_47"] is False}
    e2 = with_calls(ctor(common - 12))
    out["HC-2 the constructor as long as the commonest absorb"] = {"length": common, "W-2": e2["W-2_holds"], "fires": e2["W-2_holds"] is False}
    e3 = with_calls(ctor(common - 11))
    out["HC-3 the constructor one byte longer than the commonest absorb"] = {"length": common + 1, "W-2": e3["W-2_holds"], "fires": e3["W-2_holds"] is False}

    def refill():
        import blake3 as B3
        B3.blake3(b"\0" * REFILL_LEN).digest()
    e4 = with_calls(refill)
    out["HC-4 an unkeyed 40-byte input"] = {"C-R1": e4["C-R1_no_40_byte_F_U_input"], "fires": e4["C-R1_no_40_byte_F_U_input"] is False}
    # HC-5: a new label whose absorb input is as long as an existing absorb of another label
    victim = next(ln for (w, ln) in sorted(honest.t_kinds) if "absorb of `pb-scalar`" in w or "absorb of `pb-term`" in w)
    lab = b"zz-census-ctl"

    def new_label():
        tr = rule.transcript(bytes(b.run["transcript_domain_bytes"]))
        tr.absorb(lab, b"\0" * (victim - 48 - len(lab)))
    e5 = with_calls(new_label)
    out["HC-5 a new label's absorb as long as another label's"] = {"length": victim, "W-2g": e5["W-2g_holds"],
                                                                   "undeclared": e5["W-2g_undeclared_pairs"][:2], "fires": e5["W-2g_holds"] is False}

    def foreign():
        import blake3 as B3
        B3.blake3(key=b"\x07" * 32).update(b"abc").digest()
    e6 = with_calls(foreign)
    out["HC-6 a keyed call under a key no rule derives"] = {"ACC": e6["ACC_every_call_attributed"], "fires": e6["ACC_every_call_attributed"] is False}
    # HC-7 (2026-11-02, after the L = 2..9 finding): the Rust-table lookup itself.  A REAL `parameters`
    # absorb 64 bytes longer than the bundle's (its line with 64 bytes appended: longer than the line at any
    # L, which grows by one byte per digit of L, at most 20) is merged into the measurement: the lookup must
    # name it among the kinds the Rust table does not list.  Only with a printout.
    if rust is not None:
        line = b.run["parameter_line"].encode() + b"x" * 64

        def longer():
            tr = rule.transcript(bytes(b.run["transcript_domain_bytes"]))
            tr.absorb(b"parameters", line)
        r7 = Recorder(rule)
        with r7:
            longer()
        e7 = evaluate(honest.merged(r7), rust=rust)
        want = f"the transcript absorb of `parameters` with {len(line)} bytes of data"
        miss = [m["what"] for m in e7["rust_table"]["measured_not_in_rust"]]
        out["HC-7 a parameters absorb 64 bytes longer than the run's"] = {"kind": want, "named_by_the_lookup": want in miss,
                                                                       "fires": want in miss and not e7["rust_table"]["ok"]}
    out["ok"] = all(v["fires"] for v in out.values() if isinstance(v, dict))
    return out


def load_rust(profile):
    p = os.environ.get("ZK60_S25_W2_PRINTOUT", "")
    if not p or not os.path.exists(p):
        return None, {"not_compared": "ZK60_S25_W2_PRINTOUT is not set to the Rust s25 W-2 printout"}
    t = rust_table(p, profile)
    return {"table": t, "path": p, "sha256": _sha(p)}, None


# ---------------------------------------------------------------- the parts
def d55_hash(b, controls=True) -> tuple:
    """returns (the HASH-1 record, the HASH-2 record); each has `ok`"""
    t0 = time.time()
    hl = d55_hash_layer(b, probe=True)
    if controls and hl.get("columns_checked"):
        hl["controls"] = hash_layer_controls(b)
        hl["ok"] = bool(hl["ok"] and hl["controls"]["ok"])
    hl["seconds"] = round(time.time() - t0, 1)
    t1 = time.time()
    rust, why = load_rust(b.profile)
    rec = measure(b)
    hc = evaluate(rec, rust=rust)
    if why:
        hc["rust_table"] = why
    hc["replay_ok_while_measured"] = rec.replay_ok
    hc["hash_layer_ok_while_measured"] = rec.hash_layer_ok
    hc["not_measured_here"] = ["the prover's calls: the generator's refill and seed derivations (R1), the commit-phase and per-fork "
                               "seed domains", "statement digests a capture does not let the gate recompute: D1 calibration identity, "
                               "D2 block public digest, D3 block schedule, D4 run statement, D7 boundary spec (the Rust s25 W-2 "
                               "census covers them by arithmetic)"]
    hc["ok"] = bool(hc["ok"] and rec.replay_ok and rec.hash_layer_ok)
    if controls:
        hc["controls"] = census_controls(b, rec, rust)
        hc["ok"] = bool(hc["ok"] and hc["controls"]["ok"])
    hc["seconds"] = round(time.time() - t1, 1)
    tools = {os.path.basename(__file__): _sha(os.path.abspath(__file__))}
    hl["tool_sha256"] = hc["tool_sha256"] = tools
    return hl, hc


def main(argv=None):
    import zk60_native_rg_d55 as D
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    b = D.D55Bundle(a.bundle)
    hl, hc = d55_hash(b, controls=not a.no_controls)
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"{a.name}.json")
    with open(path, "w") as fh:
        json.dump({"HASH-1": hl, "HASH-2": hc}, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    print(json.dumps({"HASH-1 ok": hl["ok"], "columns": f"{hl.get('columns_authenticated')}/{hl.get('columns_checked')}",
                      "HASH-2 ok": hc["ok"], "constructor": hc["constructor_lengths"], "C-R1": hc["C-R1_no_40_byte_F_U_input"],
                      "C-R2": hc["C-R2_constructor_not_47"], "W-2": hc["W-2_holds"], "W-2g": hc["W-2g_holds"],
                      "ACC": hc["ACC_every_call_attributed"], "findings": hc["findings"][:3]}, indent=1))
    print(f"-> {path}")
    return 0 if hl["ok"] and hc["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
