#!/usr/bin/env python3
"""D63 lane L30 (2026-11-09): write formal/ZK60Formal/RunChainUExec.lean.

The two gates of RunChainUGate.lean (`classifyU_productionReady_run_w16r2`, `_r13`) are stated for any run verifier
`V : RunV Hdr`. The instance the final assembly needs has L29's executable stages as well: `V := classifyRunV …`.
The gates at that instance are the same statements with `V` replaced; this script copies the two statements out of
RunChainUGate.lean and makes exactly that replacement, so that the two files cannot drift apart. The proofs are the
generic gates applied at `classifyRunV …`.

usage: python3 -I l30_mk_exec.py <formal/ZK60Formal dir> [output file, default <dir>/RunChainUExec.lean]
"""
import re
import sys

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else f"{src}/RunChainUExec.lean"
gate = open(f"{src}/RunChainUGate.lean", encoding="utf-8").read()

RUNV = "(classifyRunV Lb preA preB start inc incG blk outc outcG)"
# the instance, broken over two lines (an application may continue on an indented line; a line may NOT be
# broken before `.verify` or `.ypub`: a leading dot would be read as a new term)
EXEC = ("classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr\n"
        "          hon.base e")
BINDERS = ("(Lb : ℕ) (preA preB : Hdr → Except String Unit)\n"
           "    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)\n"
           "    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)")
ARGS = ("P Cin h64 hr hon U hbij site kOf δOf E O e he hN20 tr\n"
        "    Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hℓ hnp hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU Ko hKo RCx htrx hℓx T hwA hwB\n"
        "    Ux Xx hUc hXc pr hp1 hp2 hF hw0 hβLR hTe hTQ hβJ tag C coreOf Vx nx hVx hnx rx nrx hrx hnrx halive hdin\n"
        "    hdblk hdout pos hplane mk ops hE hops hcan hlink hdzero hzk")


def statement(name):
    """The statement of theorem `name`: from `theorem name` to the `:=` that ends its signature."""
    i = gate.index(f"theorem {name} ")
    end = "      εcTarget εsTarget εsTarget εzkTarget :=\n"
    j = gate.index(end, i) + len(end)
    return gate[i:j]


def exec_gate(name, new, doc):
    st = statement(name)
    n = {}
    st, n["name"] = re.subn(rf"theorem {name} ", f"theorem {new} ", st)
    st, n["V"] = re.subn(r"\(Lq : ℕ\) \(V : RunV Hdr\)\n", "(Lq : ℕ)\n    " + BINDERS + "\n", st)
    st, n["open"] = re.subn(r"ClassifyOpen R Lq V P Cin", f"ClassifyOpen R Lq {RUNV} P Cin", st)
    st, n["prot"] = re.subn(r"classifyProtocolU S R Lq V P Cin h64 hr hon\.base e", EXEC, st)
    assert n["name"] == 1 and n["V"] == 1 and n["open"] == 1 and n["prot"] >= 8, (name, n)
    assert " V " not in st and "(V " not in st, name
    print(f"{new}: {n['prot']} occurrences of the instance replaced")
    return f"{doc}\n{st}  {name} R Lq {RUNV}\n    {ARGS}\n"


HEADER = '''/-
D63 lane L30 (2026-11-09), part 5: **the instance with BOTH changes**: the input commitment opening at the
unique-decoding radius (L26's `classifyProtocolU`) AND the two stage verifiers in executable Lean (L29's
`classifyRunV`, the run verifier of `classifyProtocolExec`).

L26's instance and this lane's gates are stated for ANY run verifier `V : RunV Hdr`; L29's `classifyProtocolExec` is
L18's `classifyProtocol` at `V := classifyRunV …`. So the instance the final assembly needs is one instantiation:

* **`classifyProtocolUExec`**: `classifyProtocolU` at `V := classifyRunV L preA preB start inc incG blk outc outcG`;
* `classifyProtocolUExec_verify`, `classifyProtocolUExec_verify_iff`: its verifier IS `classifyProtocolExec`'s (so
  L29's `classifyProtocolExec_verify_iff` unfolds its acceptance into the run's steps);
  `classifyProtocolUExec_prove`: its honest prover is `classifyProtocolExec`'s;
  `classifyProtocolUExec_opensIn`: its input opening is `OpensU` at radius `e`;
* **`classifyUExec_productionReady_run_w16r2`**, **`classifyUExec_productionReady_run_r13`**: this lane's two gates at
  that instance. Their statements are `RunChainUGate.lean`'s with `V` replaced (written by
  `results/zk60_lean_l30_20261109/l30_mk_exec.py`); their proofs are the generic gates applied at `classifyRunV …`.

Nothing is switched: `classifyProtocol`, `classifyProtocolExec` and `classifyProtocolU` are unchanged, and Victor has
not ruled on finding L24-1. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StageVerifyExec
import ZK60Formal.RunChainUGate

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## The instance -/

section Instance

/-- **THE `Protocol` INSTANCE of the classify run with BOTH changes** (D63 lane L30): the input opening at radius `e`
(L26's `classifyProtocolU`, finding L24-1's proposed fix) at the run verifier with the executable stages (L29's
`classifyRunV`). -/
noncomputable def classifyProtocolUExec (R : ClassifyRunPublic S) (Lq : ℕ) (Lb : ℕ)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV)
    (incG : Hdr → StageGeom) (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ) : Protocol (QB Lq) Dig Coins (classifyModel S R) :=
  classifyProtocolU S R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P Cin h64 hr base e

variable (R : ClassifyRunPublic S) (Lq : ℕ) (Lb : ℕ) (preA preB : Hdr → Except String Unit)
  (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
  (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
  (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ)

/-- **The same verifier as `classifyProtocolExec`** (L29's, on L18's instance): the two instances differ only in
`opensIn`. -/
theorem classifyProtocolUExec_verify (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G () s rc
      = (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base).verify G () s rc :=
  rfl

/-- So its acceptance is `classifyProtocolExec`'s, which L29's `classifyProtocolExec_verify_iff` unfolds into the
run's steps (the pre-header checks, `L + 2` segments, stage IN-C's decode and verify, the blocks in order, stage
OUT-C's decode and verify). -/
theorem classifyProtocolUExec_verify_iff (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).verify G () s rc
        = true
      ↔ (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base).verify G () s rc
        = true :=
  Iff.rfl

/-- **The same honest prover as `classifyProtocolExec`.** -/
theorem classifyProtocolUExec_prove (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).prove G () x c
      = (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base).prove G () x c :=
  rfl

/-- **Its input opening is the opening at radius `e`.** -/
theorem classifyProtocolUExec_opensIn (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt) :
    (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e).opensIn G s x r
      ↔ Cin.OpensU Lq h64 hr e G s x r :=
  Iff.rfl

end Instance

/-! ## The gates at the instance with both changes -/

section Gates

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

'''

FOOTER = '''
end Gates

end ZK60.ProtocolClassify
'''

DOC_W = ('/-- **THE GATE at W16R2 at the instance with both changes** (D63 lane L30): '
         '`classifyU_productionReady_run_w16r2` at\n`V := classifyRunV …`, the run verifier with L29\'s executable '
         'stages. The premises are the same, read at\n`classifyProtocolUExec`. -/')
DOC_R = ('/-- **THE GATE at R13, the media app\'s profile, at the instance with both changes** (D63 lane L30):\n'
         '`classifyU_productionReady_run_r13` at `V := classifyRunV …`, the run verifier with L29\'s executable '
         'stages. The\npremises are the same, read at `classifyProtocolUExec`. -/')

body = (exec_gate("classifyU_productionReady_run_w16r2", "classifyUExec_productionReady_run_w16r2", DOC_W) + "\n"
        + exec_gate("classifyU_productionReady_run_r13", "classifyUExec_productionReady_run_r13", DOC_R))
open(dst, "w", encoding="utf-8").write(HEADER + body + FOOTER)
print("wrote", dst)
