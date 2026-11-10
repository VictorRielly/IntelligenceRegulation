#!/usr/bin/env python3
"""D63 lane L30 (2026-11-09): write formal/ZK60Formal/RunChainUToken.lean.

The two gates of RunChainUGate.lean are stated for any input plane commitment `Cin`, with the link between the
BASE-field extracted matrix and the column test's chain event as ONE premise (`hlink`). At the two registered
token-words endpoints (`w16r2TokenCommit`, `R13.r13TokenCommit`) the commitment's code is fixed, so:
* the radius premises `he`, `hN20` and the plane premise `hplane` are facts;
* the column test's code can be named (the registered code with scalars extended to the test's field), and then the
  step from the base field to the extension field inside `hlink` is `xlink_of_read` (finding L26-3, a theorem):
  `hlink` splits into `hwin` (the test's windows at steps' ends), `hread` (the test's matrix and openable set at its
  window are the run extractor's) and `hBal` (the test's second half alive at the end).
This script copies the two statements out of RunChainUGate.lean and makes exactly those replacements, so that the
files cannot drift apart. The proofs are the generic gates applied at the registered commitment.

usage: python3 -I l30_mk_token.py <formal/ZK60Formal dir> [output file, default <dir>/RunChainUToken.lean]
"""
import re
import sys

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else f"{src}/RunChainUToken.lean"
gate = open(f"{src}/RunChainUGate.lean", encoding="utf-8").read()

ARGS1 = "U hbij site kOf δOf E O"
ARGS2 = ("tr\n    Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hℓ hnp hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU Ko hKo RCx htrx hℓx T hwA hwB\n"
         "    Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin\n"
         "    hdblk hdout")


def statement(name):
    i = gate.index(f"theorem {name} ")
    end = "      εcTarget εsTarget εsTarget εzkTarget :=\n"
    j = gate.index(end, i) + len(end)
    return gate[i:j]


def sub1(st, old, new, count=1):
    assert st.count(old) == count, (old, st.count(old))
    return st.replace(old, new)


def token_gate(p):
    st = statement(p["gate"])
    st = sub1(st, f"theorem {p['gate']} ", f"theorem {p['gate']}_token ")
    st = sub1(st, "(P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)",
              "(P : RunP Hdr (S.Tok → ℕ) Coins) (h64 : 64 ≤ Lq)")
    st = sub1(st, " (e : ℕ)\n    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)\n", "\n")
    st = sub1(st, "    (pos : S.Tok → Fin Cin.dR × Fin Cin.n) (hplane : ∀ x, Cin.plane x = posPlane pos x) "
              "(mk : Cin.SaltMk)\n", "    (mk : Cin.SaltMk)\n")
    st = sub1(st, "(ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))",
              f"(ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin (2 ^ {p['h']}) → Option (MerkleOpening Dig Dig (ColR Rr)))")
    st = sub1(st, "{F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]\n"
              "    [DecidableEq Cl] (RCx",
              "{F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl]\n"
              "    [DecidableEq Cl] (RCx")
    st = sub1(st, f"(T : XTest F κ μ Cl {p['h']}) (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)\n",
              f"(T : XTest F (Fin Rr) (Fin (2 ^ 14 + {p['Q']})) Cl {p['h']})\n"
              f"    (hTenc : T.enc = encLin (Q := {p['Q']}) (fun j => algebraMap GF F ({p['pts']} j)) (rowFormK14 F))\n"
              f"    (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)\n")
    st = sub1(st, f"(Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ {p['h']}) → F)",
              f"(Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin Rr → Fin (2 ^ {p['h']}) → F)")
    # `hlink` becomes three premises under the same two conditions (accepted, no extraction failure)
    i = st.index("    (hlink : ")
    j = st.index("    (hdzero : ")
    blk = st[i:j].split("\n")
    assert blk[1].lstrip().startswith("(classifyProtocolU") and blk[2].lstrip().startswith("¬ EvXR"), blk[:3]
    head = lambda nm: "\n".join([blk[0].replace("(hlink :", f"({nm} :"), blk[1], blk[2]])
    tau = "(tr G (A.run G))"
    new = (head("hwin") + "\n"
           f"      tRem RCx.W ({tau}.take T.aA) = some 0 ∧ T.aB ≤ {tau}.length\n"
           f"        ∧ tRem RCx.W ({tau}.take T.aB) = some 0)\n"
           + head("hread") + "\n"
           f"      Xx (A.runLog G).2 ({tau}.take T.aA) = exX (ops (A.runLog G).2 (A.runLog G).1.1)\n"
           f"        ∧ Ux (A.runLog G).2 ({tau}.take T.aA)\n"
           f"          = fun i j => algebraMap GF F (exU (ops (A.runLog G).2 (A.runLog G).1.1) i j))\n"
           + head("hBal") + "\n"
           f"      subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) {tau})\n")
    st = st[:i] + new + st[j:]
    # the radius is the registered one
    n = {}
    st, n["a"] = re.subn(r"hon\.base e\)", f"hon.base {p['e']})", st)
    st, n["b"] = re.subn(r"\(ops lg s\) e\)", f"(ops lg s) {p['e']})", st)
    st, n["c"] = re.subn(r"\(A\.runLog G\)\.1\.1\) e\)", f"(A.runLog G).1.1) {p['e']})", st)
    assert n == {"a": 10, "b": 3, "c": 1}, n
    assert not re.search(r"(?<![\w.])e(?![\w.])", st), "a free radius `e` is left"
    # the commitment is the registered one: the section's notation, always in parentheses (`CinR.R` would be read
    # as one dotted identifier, `(CinR).R` is the notation and a projection)
    st, n["cin"] = re.subn(r"\bCin\b", "(" + p["cin"] + ")", st)
    proof = (f"  {p['gate']} R Lq V P ({p['cin']}) h64 hr hon {ARGS1} {p['e']}\n"
             f"    (by show 2 * {p['e']} + (2 ^ 14 + {p['Q']}) ≤ 2 ^ {p['h']}; norm_num)\n"
             f"    (by show 2 ^ {p['h']} ≤ 2 ^ 20; norm_num) {ARGS2} pos (fun _ => rfl) mk ops hE hops hcan\n"
             f"    (fun A G hv hx hnc => xlink_of_read {p['pts']} {p['form']} (rowFormK14 F) ({p['ext']} F) T hTenc\n"
             f"      {p['e']} hTe RCx.W Ux Xx (A.runLog G).2 (tr G (A.run G)) (ops (A.runLog G).2 (A.runLog G).1.1)\n"
             f"      (hread A G hv hx).1 (hread A G hv hx).2 (hwin A G hv hx).1 (hwin A G hv hx).2.1\n"
             f"      (hwin A G hv hx).2.2 (hBal A G hv hx) hnc)\n"
             f"    hdzero hzk\n")
    print(f"{p['gate']}_token: {n['cin']} occurrences of the commitment replaced")
    return st + proof


def section(p):
    return f'''/-! ## {p['title']} -/

section {p['sec']}

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {{K : Type}} [Field K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {{pos : S.Tok → Fin dR × Fin (2 ^ 14)}} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin {p['Q']} → GF)
  (salt : Salt → Fin (2 ^ {p['h']}) → Dig) (path : Salt → Fin (2 ^ {p['h']}) → List Dig) (tagc : MTag)

-- {p['notedoc']}
local notation "{p['cin']}" =>
  {p['commit']} (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc

{p['doc']}
{token_gate(p)}
end {p['sec']}
'''


W = dict(gate="classifyU_productionReady_run_w16r2", h=15, Q=280, e=8052, pts="w16r2Pts", form="w16r2Form",
         ext="rowFormK14_ext_w16r2", commit="w16r2TokenCommit", cin="CinW", sec="TokenW16R2",
         title="The gate at W16R2's token-words endpoint",
         notedoc="W16R2's token-words endpoint commitment of the classify statement (L10's `w16r2TokenCommit`).",
         doc="/-- **THE GATE at W16R2 at the registered token-words endpoint** (D63 lane L30):\n"
             "`classifyU_productionReady_run_w16r2` at `Cin := w16r2TokenCommit …` and the radius `e = 8052`. The radius\n"
             "and plane premises are facts of the registered commitment. The column test's code is the registered code\n"
             "with scalars extended to the test's field (`hTenc`), so the link `hlink` is `xlink_of_read`: it splits\n"
             "into `hwin` (the test's windows at steps' ends), `hread` (the test's matrix and openable set at its\n"
             "window are the run extractor's, embedded) and `hBal` (the test's second half alive at the end). -/")
R = dict(gate="classifyU_productionReady_run_r13", h=16, Q=256, e=24448, pts="R13.r13Pts", form="R13.r13Form",
         ext="rowFormK14_ext_r13", commit="R13.r13TokenCommit", cin="CinR", sec="TokenR13",
         title="The gate at R13's token-words endpoint, the media app's",
         notedoc="R13's token-words endpoint commitment of the classify statement (L17's `r13TokenCommit`).",
         doc="/-- **THE GATE at R13, the media app's profile, at the registered token-words endpoint** (D63 lane L30):\n"
             "`classifyU_productionReady_run_r13` at `Cin := R13.r13TokenCommit …` and the radius `e = 24,448`. The\n"
             "radius and plane premises are facts of the registered commitment. The column test's code is the\n"
             "registered code with scalars extended to the test's field (`hTenc`), so the link `hlink` is\n"
             "`xlink_of_read`: it splits into `hwin`, `hread` and `hBal`. The run verifier `V` is any; at\n"
             "`V := classifyRunV …` the instance is `classifyProtocolUExec` (`RunChainUExec.lean`). -/")

HEADER = '''/-
D63 lane L30 (2026-11-09), part 6: **the gates at the two registered token-words endpoints** (`w16r2TokenCommit`,
`R13.r13TokenCommit`, the media app's), where the input commitment's code is fixed.

`RunChainUGate.lean`'s gates take any input plane commitment and keep the link between the BASE-field extracted
matrix and the column test's chain event as one premise (`hlink`). At a registered endpoint:
* the radius (`2e + n + Q = N` exactly: `e = 8052` at W16R2, `e = 24,448` at R13) and the token-words plane are facts;
* the test's code is the registered code with scalars extended to the test's field (`rowFormK14`), and the step from
  the base field to the extension field is a theorem (`BindingUCode.lean`, finding L26-3). So `hlink` splits into
  three deterministic premises: `hwin` (the test's two windows at steps' ends on the run's transcript), `hread` (the
  test's matrix and openable set at its window are the run extractor's openings, embedded) and `hBal` (the test's
  second half alive at the end; `xB_subSt_of_opB` gives it from the endpoint opening's own `opB`).

The statements are `RunChainUGate.lean`'s with those replacements (written by
`results/zk60_lean_l30_20261109/l30_mk_token.py`); the proofs are the generic gates applied at the registered
commitment. Nothing is switched. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainUGate

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

'''

FOOTER = '''
end ZK60.ProtocolClassify
'''

open(dst, "w", encoding="utf-8").write(HEADER + section(W) + "\n" + section(R) + FOOTER)
print("wrote", dst)
