#!/usr/bin/env python3
"""m8b_margins.py — U-PERF3 round 3 lane AA: the margin-bit round to
ZERO violations under the ADOPTED v3 widened stack, plus the shared v3
machinery used by the export paths (scripts/m8b_export_ffn.py
--profile v3 and scripts/m8b_gemma4_walker.py --export-v3).

THE ADOPTED STACK (TARGET_CONTRACT §2 v3 + the widened-stack amendment,
Victor's ruling 2026-08-26; measured record
docs/zkmatrix-poc/U_PERF3_QUANTIZATION_MEASUREMENTS.md §0):
  - round-to-nearest requant (the m125-documented mode: the SAME proven
    floor relation applied to a publicly pre-shifted value);
  - activation-table OUTPUT at int16 resolution (exponent e_A - 8; the
    table keeps its 256-row int8 domain) — "a16-out";
  - int16 classes at the u / h / z sites (exponent e - 8, SAME absmax
    coverage, 256x finer step; range facts at Q16 = 32767);
  - X and the gate/up matmul inputs STAY int8; weights STAY int8;
  - negative requant shifts are exact public up-scalings (no rounding).

MARGIN BITS (this script's question — kills the L1 residuals):
A margin bit at chain site s of layer l adds +1 to that site's
PER-TENSOR BASE exponent (coverage doubles; the class width is
unchanged):  X: eX+1 (int8) | gate: eGate+1 (int8; the table member
becomes (eGate+1, eA-8)) | u: eUp+1 (int16 at eUp+1-8) | h: eH+1 |
z: eZ+1.  The a site has no range fact (table output) and gets no
margin.  Iteration: run the exact chain on the FULL held-out windows,
add +1 bit to exactly the (layer, site) cells that violated, re-run;
stop at 0 violations (the smallest greedy margin set) or --rounds.
Expected quality cost ~none (margins move coverage, not bulk
resolution); the JSON records it either way.

THE INT16-OUT TABLE FAMILY (C5 registry candidates, deliverable 3):
Generation + digest follow the FROZEN silu-int8-table-v2 convention
(zkmatrix-rs/src/ring/lookup.rs silu_v2_generate/table_spec_digest_v2;
scripts/m125_export_ffn.py replicates it and pins the two frozen
members — reproduced on import here via m8b_gemma4_gelu_member's
self-check) with the output widened to 16 bits:

  S[g] = clamp(round_half_up(f(g * 2^e_in) / 2^e_out), -32767, 32767),
         g = -128..127,  f = silu | gelu_tanh,  evaluated in f64,
         round_half_up(x) = floor(x + 1/2),  stored int16.

  digest = sha256 of the canonical spec-header JSON (v2 layout; the
  function and rounding strings are part of the preimage):
    {"function":"silu-int16out-table-v3",           (resp. gelu-tanh-)
     "input":{"width":8,"scale_exp":E_IN,"signed":true},
     "output":{"width":16,"scale_exp":E_OUT,"signed":true},
     "rounding":"y = clamp(round_half_up(f(x*2^in_exp)/2^out_exp), -32767, 32767)",
     "table":[[-128,S],...,[127,S]]}

NOTE the clamp: the registry table is bounded to the int16 witness
class by construction.  The 2026-08-26 measurement scripts
(m8b_widen_attrib / m8b_gemma4_attrib) generated the a16-out rows
UNCLAMPED; rows outside +/-32767 exist only where eGate > eA (silu ~
identity at the positive end, so real data does not reach them when
calibration chose eA < eGate).  This script counts actual index hits
on clamped rows (a16_clamp_hits) so any semantic gap is measured, not
assumed.

MODES:
  # the margin iteration (one full-window verdict walk per round;
  # wrap the invocation in `flock -w 7200 /tmp/zk-heavy.lock`):
  python3 scripts/m8b_margins.py --model mistral
  python3 scripts/m8b_margins.py --model gemma
  # smoke (TRUNCATED — results are not the model's):
  python3 scripts/m8b_margins.py --model mistral --max-layers 2 \
      --val-take 1 --rounds 2 --out results/m8b_margins_SMOKE.json
  # the C5 registry record (int16-out members for both checkpoints,
  # margin-adjusted member set included when the margins JSONs exist):
  python3 scripts/m8b_margins.py --tables

Baselines consumed verbatim (same seed/windows/text as every prior
measurement): results/m8b_int8_calibration_wsl.json (Mistral),
results/m8b_gemma4_calibration.json (Gemma).  Round-0 (no margins) is
the sanity leg: it must reproduce the ruling-package verdicts
(+0.2157 / 32 viols Mistral, +0.0353 / 14 viols Gemma) up to the
clamp-hit caveat above.
"""

import argparse
import hashlib
import json
import math
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125     # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b       # noqa: E402  (store/arch/walker)
import m8b_gemma4_gelu_member as gmem    # noqa: E402  (gelu_tanh; silu-v2
#                                          pins self-checked on its import)
from m8b_int8_calibration import p, rss_gb  # noqa: E402

Q16 = 32767
SITES = ("X", "gate", "u", "h", "z")
VIOL2SITE = {"X_clip": "X", "gate_range": "gate", "up_range": "u",
             "h_range": "h", "z_range": "z"}

MISTRAL_BASE = ROOT / "results" / "m8b_int8_calibration_wsl.json"
GEMMA_BASE = ROOT / "results" / "m8b_gemma4_calibration.json"
MARGINS_OUT = {"mistral": ROOT / "results" / "m8b_margins_mistral_wsl.json",
               "gemma": ROOT / "results" / "m8b_margins_gemma_wsl.json"}

# --------------------------------------------------------------------------
# the int16-out table family (C5 candidates; frozen-v2 conventions)
# --------------------------------------------------------------------------

I16_FAMILY = {
    "silu": ("silu-int16out-table-v3",
             "y = clamp(round_half_up(silu(x*2^in_exp)/2^out_exp), "
             "-32767, 32767)"),
    "gelu": ("gelu-tanh-int16out-table-v3",
             "y = clamp(round_half_up(gelu_tanh(x*2^in_exp)/2^out_exp), "
             "-32767, 32767)"),
}


def act_f64(kind, x):
    """Scalar f64 activation: the model functions exactly as the frozen
    generators evaluate them (m125_export_ffn silu_v2_generate /
    m8b_gemma4_gelu_member.gelu_tanh)."""
    if kind == "silu":
        return x / (1.0 + math.exp(-x))
    return gmem.gelu_tanh(x)


def i16out_generate(kind, e_in, e_out):
    """The family generation formula, byte-deterministic in f64.
    Returns (table int16[256], clamped_rows list of g values whose
    unclamped value fell outside +/-32767)."""
    out = np.zeros(256, dtype=np.int16)
    clamped = []
    for i in range(256):
        g = i - 128
        v = math.floor(act_f64(kind, g * (2.0 ** e_in))
                       / (2.0 ** e_out) + 0.5)
        if v < -Q16 or v > Q16:
            clamped.append(g)
        out[i] = max(-Q16, min(Q16, v))
    return out, clamped


def i16out_digest(kind, e_in, e_out, table):
    """The canonical v2 spec-header digest, int16-out fields."""
    name, rounding = I16_FAMILY[kind]
    j = ('{"function":"%s",'
         '"input":{"width":8,"scale_exp":%d,"signed":true},'
         '"output":{"width":16,"scale_exp":%d,"signed":true},'
         '"rounding":"%s",'
         '"table":[' % (name, e_in, e_out, rounding))
    j += ','.join('[%d,%d]' % (i - 128, int(s))
                  for i, s in enumerate(table))
    j += ']}'
    return hashlib.sha256(j.encode()).hexdigest()


class MemberCache:
    """(kind, e_in, e_out) -> dict(table f64[256], table_i16, digest,
    clamped_rows, clamp_mask bool[256])."""

    def __init__(self):
        self._c = {}

    def get(self, kind, e_in, e_out):
        key = (kind, e_in, e_out)
        if key not in self._c:
            t, clamped = i16out_generate(kind, e_in, e_out)
            dg = i16out_digest(kind, e_in, e_out, t)
            mask = np.zeros(256, dtype=bool)
            for g in clamped:
                mask[g + 128] = True
            self._c[key] = dict(table=t.astype(np.float64), table_i16=t,
                                digest=dg, clamped_rows=clamped,
                                clamp_mask=mask)
        return self._c[key]

    def items(self):
        return self._c.items()


# --------------------------------------------------------------------------
# the v3 exact chain (shared by the margin verdict and both exports)
# --------------------------------------------------------------------------

def requant_narrow(acc, sh, q, mode, vc, key):
    """Exact requant at a possibly-NEGATIVE scalar shift (negative =
    exact public up-scaling, no rounding), then the range fact at Q=q
    (violations counted pre-clip)."""
    if sh < 0:
        y = acc * (2.0 ** (-sh))            # exact, lossless
    else:
        y = m125.floor_requant(acc, sh, mode)
    vc[key] += int(np.count_nonzero(np.abs(y) > q))
    return np.clip(y, -q, q)


def margin_bits(margins, li, site):
    """margins: {int layer: {site: bits}} (missing = 0)."""
    return int(margins.get(li, {}).get(site, 0))


def v3_exponents(sc, margins, li):
    """The margin-adjusted v3 exponent set for one layer.  Base
    exponents carry the margins; int16 sites live at base - 8."""
    eX = sc["eX"] + margin_bits(margins, li, "X")          # int8
    eG = sc["eGate"] + margin_bits(margins, li, "gate")    # int8
    eA16 = sc["eA"] - 8                                    # int16 (table out)
    eU16 = sc["eUp"] + margin_bits(margins, li, "u") - 8   # int16
    eH16 = sc["eH"] + margin_bits(margins, li, "h") - 8    # int16
    eZ16 = sc["eZ"] + margin_bits(margins, li, "z") - 8    # int16
    return dict(eX=eX, eG=eG, eA16=eA16, eU16=eU16, eH16=eH16,
                eZ16=eZ16, eWg=sc["eWg"], eWu=sc["eWu"], eWd=sc["eWd"])


def v3_shifts(e):
    """Signed requant shifts of the v3 chain (negative = up-scaling)."""
    return dict(g=e["eG"] - e["eX"] - e["eWg"],
                u=e["eU16"] - e["eX"] - e["eWu"],
                h=e["eH16"] - e["eA16"] - e["eU16"],
                z=e["eZ16"] - e["eH16"] - e["eWd"])


def make_v3_ffn(kind, scales, margins, cache, viols, clamp_hits,
                mode="round", getW=None, emit=None):
    """ffn_override(li, x, lw) running the adopted v3 widened chain:
    int8 X/gate + int8 weights, int16-out table (registry-exact,
    CLAMPED), int16 u/h/z, round requant, margin-adjusted exponents.
    Exact integers carried in float64 BLAS (max |acc| = f*32767*127
    ~ 6.4e10 << 2^53 — exact in any summation order).

    getW(li, lw, sc) -> {'w_gate','w_up','w_down': exact int weight
    arrays} (default: quantize lw at the calibrated exponents).
    emit(li, planes, e, sh, accmax) — export hook, B must be 1;
    planes = dict(X int8 (T,d), a16/u16 int16 (T,f), h16 int16 (T,f),
    z16 int16 (T,d))."""

    def default_getW(li, lw, sc):
        out = {}
        for name, ekey in (("w_gate", "eWg"), ("w_up", "eWu"),
                           ("w_down", "eWd")):
            q, _ = m125.quantize(lw[name].astype(np.float64), sc[ekey])
            out[name] = q
        return out

    gw = getW or default_getW

    def ffn(li, x, lw):
        sc = scales[li]
        B, T, C = x.shape
        e = v3_exponents(sc, margins, li)
        sh = v3_shifts(e)
        mem = cache.get(kind, e["eG"], e["eA16"])
        tab, cmask = mem["table"], mem["clamp_mask"]
        Wq = gw(li, lw, sc)
        if emit is not None:
            assert B == 1, "emit (export) path is single-window"
        out = np.empty((B, T, C), dtype=np.float32)
        accmax = dict(gateup=0, down=0, had=0)
        for b in range(B):
            xf = x[b].astype(np.float64)
            qx = np.round(xf / (2.0 ** e["eX"]))
            viols[li]["X_clip"] += int(np.count_nonzero(np.abs(qx) > 127))
            xq = np.clip(qx, -127, 127)
            acc_g = xq @ Wq["w_gate"].T
            acc_u = xq @ Wq["w_up"].T
            accmax["gateup"] = max(accmax["gateup"],
                                   int(np.abs(acc_g).max()),
                                   int(np.abs(acc_u).max()))
            yg = requant_narrow(acc_g, sh["g"], 127, mode, viols[li],
                                "gate_range")
            yu = requant_narrow(acc_u, sh["u"], Q16, mode, viols[li],
                                "up_range")
            idx = yg.astype(np.int64) + 128
            clamp_hits[li] += int(np.count_nonzero(cmask[idx]))
            aq = tab[idx]
            hq = aq * yu
            accmax["had"] = max(accmax["had"], int(np.abs(hq).max()))
            yh = requant_narrow(hq, sh["h"], Q16, mode, viols[li],
                                "h_range")
            acc_d = yh @ Wq["w_down"].T
            accmax["down"] = max(accmax["down"], int(np.abs(acc_d).max()))
            yz = requant_narrow(acc_d, sh["z"], Q16, mode, viols[li],
                                "z_range")
            if emit is not None:
                emit(li, dict(X=xq.astype(np.int8),
                              a16=aq.astype("<i2"),
                              u16=yu.astype("<i2"),
                              h16=yh.astype("<i2"),
                              z16=yz.astype("<i2")),
                     e, sh, accmax)
            out[b] = (yz * (2.0 ** e["eZ16"])).astype(np.float32)
        return out
    return ffn


# --------------------------------------------------------------------------
# checkpoint context (walker + baseline + windows for either model)
# --------------------------------------------------------------------------

def build_ctx(model, max_layers=None, t_override=None):
    if model == "mistral":
        base = json.loads(MISTRAL_BASE.read_text())
        ckpt = base["checkpoint"]
        arch = m8b.make_arch(base["arch"], ckpt)
        kind = "silu"
    else:
        import m8b_gemma4_walker as g4
        base = json.loads(GEMMA_BASE.read_text())
        ckpt = base["checkpoint"]
        arch = g4.arch_gemma4(ckpt)
        kind = "gelu"
    t = t_override or base["dims"]["t"]
    if max_layers:
        arch.n_layers = min(arch.n_layers, max_layers)
    store = m8b.TensorStore(ckpt)
    if model == "mistral":
        walker = m8b.Walker(store, arch, t)
    else:
        import m8b_gemma4_walker as g4
        walker = g4.Gemma4Walker(store, arch, t)
    scales = base["calibration"]

    class A:
        text = str(Path.home() / "models" / "fineweb-edu" /
                   "sample_text.txt")
        tokens = None
        cal_seqs = 8
        val_seqs = 8
    A.t = t
    toks = m8b.load_token_stream(A, ckpt)
    cal, val = m8b.token_batches(toks, base["seed"], A.cal_seqs,
                                 A.val_seqs, t)
    loss_ref = base["int8_chain"]["loss_ref"]
    return dict(base=base, ckpt=ckpt, arch=arch, walker=walker,
                scales=scales, kind=kind, val=val, seed=base["seed"],
                t=t, loss_ref=loss_ref)


def margins_to_json(margins):
    return {str(li): dict(m) for li, m in sorted(margins.items()) if m}


def margins_from_json(d):
    return {int(li): {s: int(b) for s, b in m.items()}
            for li, m in (d or {}).items()}


# --------------------------------------------------------------------------
# the margin iteration
# --------------------------------------------------------------------------

def run_margin_rounds(args):
    ctx = build_ctx(args.model, args.max_layers)
    arch, walker, scales = ctx["arch"], ctx["walker"], ctx["scales"]
    val = ctx["val"][:args.val_take] if args.val_take else ctx["val"]
    out_path = Path(args.out) if args.out else MARGINS_OUT[args.model]
    smoke = bool(args.max_layers or args.val_take)
    cache = MemberCache()

    report = dict(meta=dict(
        experiment="m8b_margins (margin bits to zero violations, "
                   "adopted v3 widened stack: round, a16-out+u16/h16/"
                   "z16, int16-out tables CLAMPED/registry-exact)",
        model=args.model, checkpoint=ctx["ckpt"], seed=ctx["seed"],
        t=ctx["t"], val_windows=int(val.shape[0]),
        layers=arch.n_layers, loss_ref=ctx["loss_ref"],
        smoke=smoke,
        box="[MEASURED WSL-BOX NT|NOISY-SHARED]"), rounds=[])

    margins = {}
    start_round = 0
    if args.resume and out_path.exists():
        prev = json.loads(out_path.read_text())
        if prev.get("rounds"):
            report["rounds"] = prev["rounds"]
            last = prev["rounds"][-1]
            margins = margins_from_json(last["margins_next"])
            start_round = last["round"] + 1
            p("resuming at round %d with margins %s"
              % (start_round, margins_to_json(margins)))

    p("m8b_margins — %s, %d layers, %d val windows, ref loss %.4f%s"
      % (args.model, arch.n_layers, val.shape[0], ctx["loss_ref"],
         "  ** SMOKE — results are not the model's **" if smoke else ""))

    for rnd in range(start_round, args.rounds):
        viols = [Counter() for _ in range(arch.n_layers)]
        clamp_hits = [0] * arch.n_layers
        ffn = make_v3_ffn(ctx["kind"], scales, margins, cache, viols,
                          clamp_hits)
        t0 = time.time()
        loss = walker.loss(val, ffn_override=ffn)
        wall = time.time() - t0
        total = sum(sum(c.values()) for c in viols)
        by = Counter()
        for c in viols:
            by.update(c)
        per_layer = {str(li): {k: v for k, v in c.items() if v}
                     for li, c in enumerate(viols) if sum(c.values())}
        # grow the margin set: +1 bit exactly where a violation stands
        nxt = {li: dict(m) for li, m in margins.items()}
        for li, c in enumerate(viols):
            for k, n in c.items():
                if n > 0:
                    site = VIOL2SITE[k]
                    nxt.setdefault(li, {})
                    nxt[li][site] = nxt[li].get(site, 0) + 1
        row = dict(round=rnd, margins=margins_to_json(margins),
                   margin_bits_total=sum(b for m in margins.values()
                                         for b in m.values()),
                   loss=loss, delta_vs_ref=loss - ctx["loss_ref"],
                   total_viol=total, viol_by_class=dict(by),
                   per_layer_viol=per_layer,
                   a16_clamp_hits=int(sum(clamp_hits)),
                   wall_s=round(wall, 1),
                   margins_next=margins_to_json(nxt))
        report["rounds"].append(row)
        p("round %d: loss %.4f (delta %+.4f)  viol %d %s  clamp-hits %d"
          "  margins %s  (%.0fs)"
          % (rnd, loss, loss - ctx["loss_ref"], total, dict(by),
             sum(clamp_hits), margins_to_json(margins) or "{}", wall))
        if per_layer:
            p("  per-layer: %s" % per_layer)
        r0 = report["rounds"][0]
        report["final"] = dict(
            margins=row["margins"],
            margin_bits_total=row["margin_bits_total"],
            loss=loss, delta_vs_ref=loss - ctx["loss_ref"],
            delta_vs_round0=loss - r0["loss"],
            total_viol=total,
            verdict=("ZERO-VIOLATIONS" if total == 0
                     else "RESIDUAL-%d" % total))
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(report, indent=1))
        if total == 0:
            break
        margins = nxt

    fin = report["final"]
    p("FINAL: %s — margins %s (%d bits), loss %.4f, delta_vs_ref "
      "%+.4f, margin quality cost %+.4f nats"
      % (fin["verdict"], fin["margins"] or "{}",
         fin["margin_bits_total"], fin["loss"], fin["delta_vs_ref"],
         fin["delta_vs_round0"]))
    if abs(fin["delta_vs_round0"]) > 0.05:
        p("** margin quality cost exceeds 0.05 nats — REPORT THIS **")
    p("JSON -> %s" % out_path)
    p("peak RSS %.2f GB" % rss_gb())


# --------------------------------------------------------------------------
# the C5 registry record (int16-out members, both checkpoints)
# --------------------------------------------------------------------------

def emit_tables(args):
    out_json = ROOT / "results" / "m8b_int16out_members.json"
    out_txt = ROOT / "results" / "m8b_int16out_members.txt"
    cache = MemberCache()
    used = {}   # (kind, e_in, e_out) -> {model: [layers]}
    for model, base_path in (("mistral", MISTRAL_BASE),
                             ("gemma", GEMMA_BASE)):
        base = json.loads(base_path.read_text())
        kind = "silu" if model == "mistral" else "gelu"
        mpath = MARGINS_OUT[model]
        margins = {}
        msrc = None
        if mpath.exists():
            mj = json.loads(mpath.read_text())
            margins = margins_from_json(mj["final"]["margins"])
            msrc = str(mpath.name)
        for sc in base["calibration"]:
            li = sc["layer"]
            e = v3_exponents(sc, margins, li)
            cache.get(kind, e["eG"], e["eA16"])
            used.setdefault((kind, e["eG"], e["eA16"]),
                            {}).setdefault(model, []).append(li)
        p("%s: %d layers -> member pairs collected (margins: %s)"
          % (model, len(base["calibration"]), msrc or "none on disk"))

    members = []
    lines = []
    for (kind, e_in, e_out), mem in sorted(cache.items()):
        u = used.get((kind, e_in, e_out), {})
        name = I16_FAMILY[kind][0]
        members.append(dict(
            function=name, e_in=e_in, e_out=e_out,
            digest=mem["digest"],
            out_min=int(mem["table_i16"].min()),
            out_max=int(mem["table_i16"].max()),
            clamped_rows=mem["clamped_rows"],
            used_by={m: sorted(ls) for m, ls in u.items()},
            table=[int(v) for v in mem["table_i16"]]))
        lines.append("%s (e_in %d, e_out %d) sha256 %s  out[%d,%d] "
                     "clamp %d  used_by %s"
                     % (name, e_in, e_out, mem["digest"],
                        int(mem["table_i16"].min()),
                        int(mem["table_i16"].max()),
                        len(mem["clamped_rows"]),
                        {m: len(ls) for m, ls in u.items()}))
        p("  " + lines[-1])
    record = dict(
        meta=dict(
            experiment="m8b_int16out_members (C5 registry candidates "
                       "under the adopted v3 ruling)",
            convention="frozen silu-int8-table-v2 generation/digest "
                       "convention (lookup.rs silu_v2_generate / "
                       "table_spec_digest_v2), output widened to 16 "
                       "bits: S[g]=clamp(round_half_up(f(g*2^e_in)/"
                       "2^e_out), -32767, 32767), g=-128..127, f64; "
                       "digest = sha256 of the canonical spec-header "
                       "JSON with output width 16 (the function and "
                       "rounding strings are digest preimage — a "
                       "rename at freeze time changes every digest)",
            functions={k: dict(name=v[0], rounding=v[1])
                       for k, v in I16_FAMILY.items()},
            selfcheck="silu-int8-table-v2 frozen pins reproduced on "
                      "import (m8b_gemma4_gelu_member gate)",
            sources=[str(MISTRAL_BASE.name), str(GEMMA_BASE.name)]
                    + [str(MARGINS_OUT[m].name) for m in
                       ("mistral", "gemma") if MARGINS_OUT[m].exists()]),
        members=members)
    out_json.write_text(json.dumps(record, indent=1))
    out_txt.write_text("\n".join(lines) + "\n")
    p("%d int16-out members -> %s (+ %s)"
      % (len(members), out_json, out_txt))


# --------------------------------------------------------------------------
# the v3 witness export helpers (called by m8b_export_ffn --profile v3
# and m8b_gemma4_walker --export-v3; the LAYOUT DOC OF RECORD is the
# m8b_export_ffn.py header, section "V3 PROFILE")
# --------------------------------------------------------------------------

def v3_witness_walk(kind, walker, arch, scales, margins, seq, out_dir,
                    manifest, read_weight_bin):
    """Run the v3 chain on ONE window (B=1), consuming the just-written
    int8 weight BYTES (self-checking export), writing the witness
    planes (X int8; a16/u16/h16/z16 int16 LE) + digests + shifts +
    margin-adjusted exponents + the layer's table member into
    `manifest`.  Asserts ZERO violations (the proof rejects otherwise
    BY DESIGN).  Returns (total_viol, cache)."""
    import hashlib as _h
    cache = MemberCache()
    viols = [Counter() for _ in range(arch.n_layers)]
    clamp_hits = [0] * arch.n_layers

    def getW(li, lw, sc):
        out = {}
        for name, bkey in (("w_gate", "WgT"), ("w_up", "WuT"),
                           ("w_down", "WdT")):
            b = read_weight_bin(li, bkey)
            # bins are TRANSPOSED (matmul layout); the chain uses W
            # row-major (out, in) and multiplies by W.T — undo here.
            out[name] = b.T.astype(np.float64)
        return out

    def emit(li, planes, e, sh, accmax):
        row = manifest["layers"][li]
        for name, arr in planes.items():
            fn = "layer%02d_%s.bin" % (li, name)
            (out_dir / fn).write_bytes(arr.tobytes())
            row["files"][name] = fn
            row["digests"][name] = _h.sha256(arr.tobytes()).hexdigest()
        mem = cache.get(kind, e["eG"], e["eA16"])
        row["shifts"] = {k: int(v) for k, v in sh.items()}
        row["exps_v3"] = {k: int(v) for k, v in e.items()}
        row["margins"] = {s: margin_bits(margins, li, s)
                          for s in SITES if margin_bits(margins, li, s)}
        row["table"] = dict(function=I16_FAMILY[kind][0],
                            e_in=e["eG"], e_out=e["eA16"],
                            digest=mem["digest"])
        row["acc_max"] = dict(accmax)
        v = viols[li]
        p("  layer %2d: shifts g/u/h/z = %d/%d/%d/%d, viol X/g/u/h/z = "
          "%d/%d/%d/%d/%d, z16 digest %s"
          % (li, sh["g"], sh["u"], sh["h"], sh["z"], v["X_clip"],
             v["gate_range"], v["up_range"], v["h_range"],
             v["z_range"], row["digests"]["z16"][:16]))

    ffn = make_v3_ffn(kind, scales, margins, cache, viols, clamp_hits,
                      mode="round", getW=getW, emit=emit)
    walker.walk(seq[:, :-1], ffn_override=ffn)
    total = sum(sum(c.values()) for c in viols)
    manifest["range_violations"] = total
    manifest["a16_clamp_hits"] = int(sum(clamp_hits))
    manifest["tables_v3"] = {
        "%s,%d,%d" % (I16_FAMILY[k][0], ei, eo): dict(digest=m["digest"])
        for (k, ei, eo), m in cache.items()}
    p("range-fact violations across the export pass: %d (0 required)"
      % total)
    return total, cache


def write_v3_sidecar(out_dir, manifest, arch, t):
    """digests.txt in the v3 line set (bf_sidecar-compatible framing:
    '<layer> <name> <rest...>'; see the m8b_export_ffn.py header doc)."""
    lines = ["00 model %s" % arch.tag.replace(" ", "_"),
             "00 dims %d %d %d %d" % (t, arch.d, arch.f, arch.n_layers),
             "00 profile v3-widened",
             "00 requant round"]
    for r in manifest["layers"]:
        li = r["layer"]
        for name in ("X", "WgT", "WuT", "WdT", "a16", "u16", "h16",
                     "z16"):
            lines.append("%02d %s %s" % (li, name, r["digests"][name]))
        s = r["shifts"]
        lines.append("%02d shifts %d %d %d %d" % (li, s["g"], s["u"],
                                                  s["h"], s["z"]))
        e = r["exps_v3"]
        # base-exponent row (margin-adjusted; int16 sites live at -8):
        lines.append("%02d exps %d %d %d %d %d %d %d %d %d"
                     % (li, e["eX"], e["eG"], e["eA16"] + 8,
                        e["eU16"] + 8, e["eH16"] + 8, e["eZ16"] + 8,
                        e["eWg"], e["eWu"], e["eWd"]))
        lines.append("%02d wexps %d %d %d %d"
                     % (li, e["eA16"], e["eU16"], e["eH16"], e["eZ16"]))
        m = r.get("margins", {})
        lines.append("%02d margins %d %d %d %d %d"
                     % (li, m.get("X", 0), m.get("gate", 0),
                        m.get("u", 0), m.get("h", 0), m.get("z", 0)))
        tb = r["table"]
        lines.append("%02d table %s %d %d %s"
                     % (li, tb["function"], tb["e_in"], tb["e_out"],
                        tb["digest"]))
    (out_dir / "digests.txt").write_text("\n".join(lines) + "\n")


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", choices=("mistral", "gemma"))
    ap.add_argument("--rounds", type=int, default=4,
                    help="max verdict walks (round 0 = no margins)")
    ap.add_argument("--val-take", type=int, default=None,
                    help="use only the first N val windows (SMOKE)")
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate the stack (SMOKE ONLY)")
    ap.add_argument("--out", default=None)
    ap.add_argument("--resume", action="store_true",
                    help="continue from the last round in --out")
    ap.add_argument("--tables", action="store_true",
                    help="emit the C5 int16-out member record and exit")
    args = ap.parse_args()

    if args.tables:
        emit_tables(args)
        return
    assert args.model, "--model mistral|gemma (or --tables)"
    run_margin_rounds(args)


if __name__ == "__main__":
    main()
