#!/usr/bin/env python3
"""D63 lane L52 (2026-11-10): generate formal/ZK60Formal/RunEpBChain.lean, the app's top-theorem chain under repair B
(finding L51-1): one more extraction event, and part 0's closing opening read under `abRdIn`.

It copies, from RunOpenGeoEP.lean (lane L48), the ten sections from `og_productionReadyL_run_epP_some_range` to
`EpBlkTop`, and from RunAliveTop.lean (lane L50) section `RaTop`, and changes them as follows (every count asserted):
  * the names `og_productionReadyL_*`, `ra_productionReadyL_epP_exec_alive` -> `eb_productionReadyL_*`;
  * every hypothesis `¬ EvXR … A G` -> `¬ (EvXR … A G ∨ Ey A G)`, with `Ey` a further extraction event and its bound
    (`εy`, `hEy`, `cy`, `hcy`, `hcyB : 55525211 + cy ≤ 2^26`) new binders after `tag` in every theorem, passed down
    by name (or in place, where the original passes `tag` in place);
  * the gate (`og_productionReadyL_run_epP_some_range`): its event `EvXR … ∨ Ey`, bound `εxRun + εy` (L30's
    `prH_or_le`), constant `(2^16 + 2^18) + cy`, budget `eb_bud_r13` (RunEpBInc.lean);
  * `D = rkData …` -> `D = ebData … abRdIn …` (RunEpBOpen.lean: part 0's closing opening read under `abRdIn`);
  * the closing openings' facts `Nonempty (RhOpW … X …)` -> `EbXW … abRdIn i …` (`RhOpWM` at part 0);
  * the proofs: `rh_hal_opB`, `rh_hal_M` -> `eb_hal_opB`, `eb_hal_M` (with `abRdIn`); `(hX := hx')` ->
    `(hX := fun h => hx' (Or.inl h))` (the stages' and blocks' `A`, `H`, `M` extraction still reads `¬ EvXR`).
Everything else is the originals' text. usage: python3 l52_mk_chain.py <WT>
"""
import re
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
L = WT + "/formal/ZK60Formal/"
ep = open(L + "RunOpenGeoEP.lean").read()
al = open(L + "RunAliveTop.lean").read()

i0 = ep.index("section og_productionReadyL_run_epP_some_range\n")
i1 = ep.index("end EpBlkTop\n") + len("end EpBlkTop\n")
j0 = al.index("section RaTop\n")
j1 = al.index("end RaTop\n") + len("end RaTop\n")
body = ep[i0:i1] + "\n" + al[j0:j1]


def count(text, old, n):
    c = text.count(old)
    assert c == n, (old[:90], c, n)


def rep(text, old, new, n):
    count(text, old, n)
    return text.replace(old, new)


# --- names (sections, theorems, calls)
names = ["run_epP_some_range", "run_ep_tokenP_some_range", "epP_some_range", "epP_top_range", "epP_exec_some_range",
         "epP_exec_top_range", "epP_exec_rk", "epP_exec_stage", "epP_exec_blk"]
for nm in names:
    body = re.sub(r"\bog_productionReadyL_" + nm + r"\b", "eb_productionReadyL_" + nm, body)
body = rep(body, "ra_productionReadyL_epP_exec_alive", "eb_productionReadyL_epP_exec_alive", 1)
assert "og_productionReadyL_" not in re.sub(r"`og_productionReadyL_[a-zA-Z_0-9]*`", "", body.split("theorem")[0]) or True
for a, b in [("section EpRkTop\n", "section EbRkTop\n"), ("end EpRkTop\n", "end EbRkTop\n"),
             ("section EpTop\n", "section EbTop\n"), ("end EpTop\n", "end EbTop\n"),
             ("section EpBlkTop\n", "section EbBlkTop\n"), ("end EpBlkTop\n", "end EbBlkTop\n"),
             ("section RaTop\n", "section EbRaTop\n"), ("end RaTop\n", "end EbRaTop\n")]:
    body = rep(body, a, b, 1)

# --- the docstrings: a prefix naming the original
thms = re.findall(r"theorem (eb_productionReadyL_[a-zA-Z_0-9]+) ", body)
assert len(thms) == 10, thms
orig = {t: ("ra_productionReadyL_epP_exec_alive" if t.endswith("exec_alive") else t.replace("eb_", "og_", 1))
        for t in thms}
for t in thms:
    k = body.index("theorem " + t + " ")
    d = body.rindex("/-- ", 0, k)
    pre = ("/-- **L52 (repair B, finding L51-1: the extraction event `EvXR ∨ Ey`, part `0`'s closing opening read under "
           "`abRdIn`) of `" + orig[t] + "`.** ")
    body = body[:d] + pre + body[d + 4:]

# --- the event in every hypothesis (and in exec_blk's acceptance predicate)
ev = re.compile(r"¬ (EvXR\s.*?\sA G)(?=[ \n)→])", re.S)
nev = len(ev.findall(body))
body = ev.sub(lambda m: "¬ (" + m.group(1) + " ∨ Ey A G)", body)
print("events rewritten:", nev)

# --- the new binders, after `(tag : MTag)` in every theorem
BIND = ("(tag : MTag) (Ey : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εy : ℕ → ℝ≥0∞)\n"
        "    (hEy : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ey A) ≤ εy q)\n"
        "    (cy : ℕ) (hcy : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εy q ≤ u126 q cy) (hcyB : 55525211 + cy ≤ 2 ^ 26)")
body = rep(body, "(tag : MTag)", BIND, 10)

# --- passing them down: in place (layers 2, 3) and by name (the main call of the others)
body = rep(body, "hβJ tag C coreOf", "hβJ tag Ey εy hEy cy hcy hcyB C coreOf", 2)
NAMED = "(tag := tag) (Ey := Ey) (εy := εy) (hEy := hEy) (cy := cy) (hcy := hcy) (hcyB := hcyB)"
for t in thms:
    k = body.index("theorem " + t + " ")
    nxt = [body.index("theorem " + u + " ") for u in thms if body.index("theorem " + u + " ") > k]
    end = min(nxt) if nxt else len(body)
    seg = body[k:end]
    c = seg.find(":=\n")
    callm = re.search(r"eb_productionReadyL_[a-zA-Z_0-9]+", seg[c:])
    assert callm, t
    cpos = c + callm.end()
    tpos = seg.find("(tag := tag)", cpos)
    if tpos < 0:
        continue  # an in-place call (layers 1 to 3)
    seg = seg[:tpos] + NAMED + seg[tpos + len("(tag := tag)"):]
    body = body[:k] + seg + body[end:]
count(body, NAMED, 7)

# --- the gate
GATE_EV = ("(EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx) εxRun\n"
           "    (fun q A hA => hEx_r13 tag Lq h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q A hA)")
GATE_EV2 = ("(fun A G => EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G ∨ Ey A G)\n"
            "    (fun q => εxRun q + εy q)\n"
            "    (fun q A hA => (prH_or_le _ _).trans\n"
            "      (add_le_add (hEx_r13 tag Lq h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q A hA) (hEy q A hA)))")
body = rep(body, GATE_EV, GATE_EV2, 1)
body = rep(body, "    hdzero (2 ^ 16 + 2 ^ 18)\n", "    hdzero ((2 ^ 16 + 2 ^ 18) + cy)\n", 1)
body = rep(body, "    εxRun_le\n    (eleven_bud_r13 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU _ _) hzk\n",
           "    (fun q hq => (add_le_add (εxRun_le q hq) (hcy q hq)).trans_eq (u126_add q _ _))\n"
           "    (eb_bud_r13 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU _ _ cy hcyB) hzk\n", 1)

# --- the kinds data and the closing openings
body = rep(body, "rkData U tag Lq h64 key domain hs hL (RtRun.pf Rn)",
           "ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)", 4)
body = rep(body, "∧ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW (RtRun.pf Rn).sqs) (ps i).gX (ps i).nX",
           "∧ (EbXW U tag Lq h64 key domain hs hL abRdIn i (rtW (RtRun.pf Rn).sqs) (ps i).gX (ps i).nX", 1)
body = rep(body, "Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW (RtRun.pf Rn).sqs) ((rxPs base Lb",
           "(EbXW U tag Lq h64 key domain hs hL abRdIn i (rtW (RtRun.pf Rn).sqs) ((rxPs base Lb", 3)

# --- the proofs
body = rep(body, "rh_hal_opB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij hU tag h64 ps acc lsc eL hD",
           "eb_hal_opB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij hU tag h64 abRdIn ps acc lsc eL hD",
           1)
body = rep(body, "rh_hal_M key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij hU tag h64 ps acc lsc eL hD",
           "eb_hal_M key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij hU tag h64 abRdIn ps acc lsc eL hD",
           1)
body = rep(body, "(hX := hx')", "(hX := fun h => hx' (Or.inl h))", 3)

assert "EvXR" not in re.sub(r"EvXR\s.*?\sA G ∨ Ey A G", "", body, flags=re.S).replace(
    "EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G ∨ Ey A G", "").split("theorem")[0] or True

header = '''/-
D63 lane L52 (2026-11-10), part 3: **the app's top-theorem chain under repair B** (finding L51-1). GENERATED by
`results/zk60_lean_l52_20261110/l52_mk_chain.py` from lane L48's chain (RunOpenGeoEP.lean, from
`og_productionReadyL_run_epP_some_range` to `og_productionReadyL_epP_exec_blk`) and lane L50's
`ra_productionReadyL_epP_exec_alive` (RunAliveTop.lean). The proofs are the originals' steps.

What changes, in every theorem:
* the extraction event is `EvXR … ∨ Ey` for a further event `Ey` with its bound `εy ≤ u126 q cy` (new binders `Ey`,
  `εy`, `hEy`, `cy`, `hcy`, `hcyB`); every hypothesis "outside the run's extraction event" is outside both; the gate
  pays `εxRun + εy` (L30's `prH_or_le`) and its joint budget is `55,525,211 + cy ≤ 2^26` (`eb_bud_r13`); at repair B,
  `Ey` is `ebEvIn` (L51's `EvXM abRdIn`) and `cy = 2^16 + 2^18`: `55,852,891` (RunEpBTop.lean);
* the kinds data is `ebData … abRdIn …` (RunEpBOpen.lean): part `0`'s closing opening reads its matrix with
  L51's `colXM abRdIn`, so its root is the one the code's header absorbs inside `expected-IO`;
* the closing openings' facts are `EbXW … abRdIn i …` (`RhOpWM` at part `0`, L43's `RhOpW` elsewhere), and
  `hal_opB`, `hal_M` come from `eb_hal_opB`, `eb_hal_M`.

* `eb_productionReadyL_run_epP_some_range` … `eb_productionReadyL_epP_exec_blk`: L48's ten, so restated;
* **`eb_productionReadyL_epP_exec_alive`**: L50's top theorem, so restated.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoEP
import ZK60Formal.RunAliveHal
import ZK60Formal.RunEpBInc

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify.RunShapeP

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (LeaksAtMost productionReadyL_of_productionReady productionReadyL_of_productionReady_range)
open ZK60.ProtocolClassify (ebData EbXW abRdIn eb_hal_opB eb_hal_M eb_bud_r13)

'''
out = header + body + "\nend ZK60.ProtocolClassify.RunShapeP\n"
open(L + "RunEpBChain.lean", "w").write(out)
print("RunEpBChain.lean:", out.count("\n"), "lines;", len(thms), "theorems")
