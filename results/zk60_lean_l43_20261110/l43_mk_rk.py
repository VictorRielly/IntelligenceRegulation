#!/usr/bin/env python3
"""D63 lane L43 (2026-11-10): generate formal/ZK60Formal/RunCoverPRk.lean, THE APP'S TOP THEOREM in D76's approved form
at the per-block-shape model with the kinds data built from the verifier's readers and `hal_opB`, `hal_M` discharged.

From the generated RunCoverPSomeL.lean (l43_mk_someP.py), the theorem `rc_productionReadyL_r13P_exec_top_range` is
copied with exactly these changes:
  * the name -> rc_productionReadyL_r13P_exec_rk;
  * before `hal_opB`, new binders: `hU` (U^2 = 7), the parts `ps`, the accumulator readers `acc`, the LogUp sum claims
    `lsc`, LogUp's escape count `eL`, and `hDe : D = rkData U tag Lq h64 key domain hs hL (RtRun.pf Rn) ps acc lsc eL`;
  * the binder `hal_opB` is replaced by `hopW` (on an accepted run outside EvXR, every part's three openings meet
    `RhOpW` at their windows), `hal_M` by `hMW` (every part's `M` meets `RhMW`);
  * the proof substitutes `hDe` and calls the generated gate with `hal_opB := rh_hal_opB …`, `hal_M := rh_hal_M …`.

usage: python3 -I l43_mk_rk.py <formal/ZK60Formal dir> <out.lean>
"""
import sys

src, out = sys.argv[1], sys.argv[2]
text = open(f"{src}/RunCoverPSomeL.lean", encoding="utf-8").read()
SEC = "rc_productionReadyL_r13P_exec_some_range"
a = text.index(f"section {SEC}")
b = text.index(f"end {SEC}")
sec = text[a:b]
pre = sec[:sec.index("/--")]
t0 = sec.index("theorem rc_productionReadyL_r13P_exec_top_range")
thm = sec[t0:]
thm = thm[:thm.index("εcTarget εsTarget εsTarget εzkTarget :=") + len("εcTarget εsTarget εsTarget εzkTarget :=")]
thm = thm.replace("theorem rc_productionReadyL_r13P_exec_top_range", "theorem rc_productionReadyL_r13P_exec_rk", 1)

i = thm.index("    (hal_opB :")
j = thm.index("    (hal_M :")
k = thm.index("    (hal_slots :")
head = thm[i:j].split("\n")[:3]
PF = "(RtRun.pf Rn)"
TAU = "(rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))"


def opw(gx, nx, clr, oa, ob):
    return (f"Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW {PF}.sqs) (ps i).{gx} (ps i).{nx}\n"
            f"            (fun hdr => {clr}) ({PF}.off i + ({PF}.part i).{oa})\n"
            f"            ({PF}.off i + ({PF}.part i).{ob})\n"
            f"            ({PF}.off i + ({PF}.part i).{oa} + ((ps i).{nx} + (ps i).{gx}.rows)) (A.runLog G).2 G\n"
            f"            {TAU})")


new_bind = [
    "    (hU : U ^ 2 = algebraMap GF K 7) (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Exec.Block.Acc)",
    "    (lsc : ℕ → Exec.Block.ZClaim) (eL : ℕ)",
    "    (hDe : D = rkData U tag Lq h64 key domain hs hL (RtRun.pf Rn) ps acc lsc eL)",
]
hopw = [head[0].replace("(hal_opB :", "(hopW :")] + head[1:] + [
    f"      ∀ i, i < {PF}.parts.length →",
    "        " + opw("gA", "nA", "(acc i hdr).claims.a", "oA", "oBA"),
    "          ∧ " + opw("gH", "nH", "(acc i hdr).claims.h ++ [lsc i]", "oH", "oBH"),
    "          ∧ " + opw("gX", "nX", "rkPend acc i hdr ++ (acc i hdr).claims.inp", "oX", "oBX") + ")",
]
hmw = [head[0].replace("(hal_opB :", "(hMW :")] + head[1:] + [
    f"      ∀ i, i < {PF}.parts.length →",
    f"        Nonempty (RhMW tag Lq h64 key domain hs hL (rtW {PF}.sqs) (ps i).S (ps i).k (ps i).mpos",
    f"          (fun hdr => (acc i hdr).fs ++ (acc i hdr).hostFs) ({PF}.off i + ({PF}.part i).pre) (A.runLog G).2 G",
    f"          {TAU}))",
]
thm = thm[:i] + "\n".join(new_bind + hopw + hmw) + "\n" + thm[k:]

SECA = "Rr dR hpos place msg msg_place pad salt path tagc Rp Lq".split()
VN = "Lb preA preB start inc incG blk outc outcG".split()
COMMON = ("P h64 hr hon U hbij key domain hs hL hL64 Rn hv hD site kOf δOf E O T hTenc hTaA hTaB Ux Xx hUc hXc pr "
          "hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx").split()
HALS = "hal_slots hal_R0 hal_R1 hal_H0 hal_H1 hal_LU".split()
TAIL = "hdin hdblk hdout mk ops hE hops hcan hwin hread hBal hdzero hzk".split()
NARGS = f"key domain hs Lq hL {PF} (RtRun.rd Rn) hL64 hv U hbij hU tag h64 ps acc lsc eL hD (Rp.blks.length + 2) (A.runLog G).2 G {TAU}"
args = [f"({x} := {x})" for x in SECA + VN + COMMON]
args.append(f"(hal_opB := fun A G hv' hx' => rh_hal_opB {NARGS} (hopW A G hv' hx'))")
args.append(f"(hal_M := fun A G hv' hx' _ => rh_hal_M {NARGS} (hMW A G hv' hx'))")
args.append("(hal_opA := fun A G hv' _ hB _ => rh_hal_opA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U "
            "hbij _ hD (Rp.blks.length + 2) (le_of_eq ((RtRun.parts_length Rn).trans (congrArg (fun n => n + 2) "
            "O.blocks.2))) (A.runLog G).2 G (A.run G) (rc_good_of_uexecP Rp Lq Lb preA preB start inc incG blk outc "
            "outcG P (CinR) h64 hr hon.base 24448 Rn A G hv') hB)")
args += [f"({x} := {x})" for x in HALS + TAIL]
body = ["  by", "  subst hDe", "  exact rc_productionReadyL_r13P_exec_top_range"]
line = ""
for x in args:
    if len(line) + len(x) + 1 > 110:
        body.append("    " + line.rstrip())
        line = ""
    line += x + " "
body.append("    " + line.rstrip())

doc = ("/-- **THE APP'S TOP THEOREM IN D76'S APPROVED FORM AT ONE SHAPE PER BLOCK, WITH THE KINDS DATA BUILT FROM THE\n"
       "VERIFIER'S READERS AND `hal_opB`, `hal_M` DISCHARGED** (D63 lane L43). `rc_productionReadyL_r13P_exec_top_range`"
       " at\n`D := rkData …` (`hDe`; `hD` is met by `rkData_valid` from the parts' facts), with `hal_opB` replaced by"
       " `hopW`\n(every part's openings `A`, `H` and the closing one meet `RhOpW` at their windows: their `PcsOk` on the"
       " claims the\nreaders return, their extraction; `rh_hal_opB`) and `hal_M` by `hMW` (`RhMW`; `rh_hal_M`); `hal_opA`"
       " is gone\n(`rh_hal_opA`, for every `D`). At a block part the facts `RhOpW`, `RhMW` are PROVED from the acceptance up"
       " to the\nextraction (`rh_blk_opA`, `rh_blk_opH`, `rh_blk_M`). Generated. -/")

out_l = [
    "/-",
    "D63 lane L43 (2026-11-10), part 7c: **the app's top theorem in D76's approved form at the per-block-shape model, with",
    "the kinds data `D` built from the verifier's readers (`rkData`), the first two ordered cover premises `hal_opB`,",
    "`hal_M` discharged to the per-opening acceptance facts `RhOpW`, `RhMW` (RunHalOpB.lean, RunHalM.lean), and the third,",
    "`hal_opA`, discharged outright** (RunHalOpA.lean: the run's layout on every accepted output, L20's `opening_split`).",
    "GENERATED by `results/zk60_lean_l43_20261110/l43_mk_rk.py` from the generated RunCoverPSomeL.lean.",
    "",
    "* **`rc_productionReadyL_r13P_exec_rk`**.",
    "",
    "Only `propext`, `Classical.choice`, `Quot.sound`.",
    "-/",
    "import ZK60Formal.RunCoverPSomeL",
    "import ZK60Formal.RunHalM",
    "import ZK60Formal.RunHalOpA",
    "",
    "set_option autoImplicit false",
    "set_option linter.constructorNameAsVariable false",
    "",
    "namespace ZK60.ProtocolClassify.RunShapeP",
    "",
]
ns = text.index("namespace ZK60.ProtocolClassify.RunShapeP")
ns_end = text.index("\n", ns) + 1
hdr_lines = text[ns_end:text.index("\nsection ", ns_end)].strip("\n").split("\n")
out_l += hdr_lines + ["", pre.replace(f"section {SEC}", "section RkTop").rstrip("\n"), "", doc, thm] + body
out_l += ["", "end RkTop", "", "end ZK60.ProtocolClassify.RunShapeP", ""]
open(out, "w", encoding="utf-8").write("\n".join(out_l))
print(f"wrote {out}")
