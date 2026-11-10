#!/usr/bin/env python3
"""D63 lane L42 (2026-11-10): write formal/ZK60Formal/StatementsD76Gate.lean.

The top production gates of the classify run are stated in the instance-leak form `ProductionReady`:
L30's `classifyUExec_productionReady_run_r13` / `_w16r2` (RunChainUExec.lean) and L34's `rt_productionReady_r13`
(RunTrGate.lean). Victor's ruling D76 makes the approved gate `ProductionReadyL … Λ …` with the allowed leakage named.
This script copies each gate's statement out of its file, renames it, and replaces ONLY its conclusion
`ProductionReady M A P εcTarget εsTarget εsTarget εzkTarget` by `ProductionReadyL M A P (classifyLeak S R) εcTarget …`,
so that the amended statements cannot drift from the gates they come from: the premises are the same text. The proofs
are the bridge `productionReadyL_of_productionReady` applied to the original gate, every explicit argument passed by
name, and the instance's leak factoring (`classifyUExec_leaksAtMost`, `classifyU_leaksAtMost`).

It also writes `rt_productionReadyL_r13_exec`: L34's gate at `V := classifyRunV …` (the run verifier with L29's
executable stages), so at L30's instance `classifyProtocolUExec`, which D77 makes the production target.

usage: python3 -I l42_mk_gate.py <formal/ZK60Formal dir> [output file, default <dir>/StatementsD76Gate.lean]
"""
import re
import sys

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else f"{src}/StatementsD76Gate.lean"
uexec = open(f"{src}/RunChainUExec.lean", encoding="utf-8").read()
rtgate = open(f"{src}/RunTrGate.lean", encoding="utf-8").read()

END = "      εcTarget εsTarget εsTarget εzkTarget :=\n"
RUNV = "(classifyRunV Lb preA preB start inc incG blk outc outcG)"
BINDERS = ("(Lb : ℕ) (preA preB : Hdr → Except String Unit)\n"
           "    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)\n"
           "    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)")


def statement(text, name):
    """The statement of theorem `name`: from `theorem name` to the `:=` that ends its signature."""
    i = text.index(f"theorem {name} ")
    j = text.index(END, i) + len(END)
    return text[i:j]


OPEN, CLOSE = "({[⦃", ")}]⦄"


def explicit_names(st):
    """The names of the explicit binders `( … )` of a statement (top level, before the conclusion's colon)."""
    return binder_names(st, st.index(" ", len("theorem ")) + 1)  # after the theorem's name


def binder_names(st, i):
    """The names of the explicit binders `( … )` in `st` from position `i` to a top-level colon or the end."""
    names = []
    while True:
        while i < len(st) and st[i].isspace():
            i += 1
        if i == len(st):
            return names
        c = st[i]
        if c == ":":
            return names
        assert c in OPEN, (c, st[i:i + 40])
        depth, j = 0, i
        while True:
            if st[j] in OPEN:
                depth += 1
            elif st[j] in CLOSE:
                depth -= 1
                if depth == 0:
                    break
            j += 1
        group = st[i + 1:j]
        if c == "(":
            k, d = 0, 0
            while True:  # the binder's own colon: the first one at depth 0 inside the group
                if group[k] in OPEN:
                    d += 1
                elif group[k] in CLOSE:
                    d -= 1
                elif group[k] == ":" and d == 0:
                    break
                k += 1
            names += group[:k].split()
        i = j + 1


def amend(st, old, new, leak):
    """Rename `old` to `new` and put the allowed leakage `leak` into the conclusion."""
    n = {}
    st, n["name"] = re.subn(rf"theorem {old} ", f"theorem {new} ", st)
    k = st.rindex("    ProductionReady (")
    st = st[:k] + "    ProductionReadyL (" + st[k + len("    ProductionReady ("):]
    st, n["end"] = re.subn(re.escape(END) + r"$", f"      ({leak}) εcTarget εsTarget εsTarget εzkTarget := by\n", st)
    assert n["name"] == 1 and n["end"] == 1, (old, n)
    return st


def proof(callee, names, leakLemma, subst=None, extra=()):
    """The bridge applied to the original gate, every explicit argument passed by name."""
    subst = subst or {}
    pieces = [f"({a} := {subst.get(a, a)})" for a in list(extra) + names]
    lines, line = [], "      "
    for p in pieces:
        if len(line) + len(p) + 1 > 118 and line.strip():
            lines.append(line.rstrip())
            line = "      "
        line += p + " "
    lines.append(line.rstrip())
    return (f"  refine productionReadyL_of_productionReady _ ?_\n    ({callee}\n" + "\n".join(lines) + ")\n"
            f"  exact {leakLemma}\n")


def uexec_gate(old, new, doc):
    st = statement(uexec, old)
    names = explicit_names(st)
    return f"{doc}\n{amend(st, old, new, 'classifyLeak S R')}{proof(old, names, 'classifyUExec_leaksAtMost')}"


def gate_section_names():
    """The explicit section variables of RunTrGate.lean's section GateR13 (`Rr dR hpos place msg …`)."""
    v = section_vars(rtgate, "GateR13")
    i = v.index("variable (Rr dR")
    j = v.index("\n\n", i)
    names = binder_names(v[i + len("variable "):j], 0)
    assert names[:2] == ["Rr", "dR"] and names[-1] == "tagc", names
    return names


def rt_gate(new, doc):
    st = statement(rtgate, "rt_productionReady_r13")
    names = explicit_names(st)
    return (f"{doc}\n{amend(st, 'rt_productionReady_r13', new, 'classifyLeak S Rp')}"
            f"{proof('rt_productionReady_r13', names, 'classifyU_leaksAtMost', extra=gate_section_names())}")


def rt_gate_exec(new, doc):
    st = statement(rtgate, "rt_productionReady_r13")
    names = explicit_names(st)
    n = {}
    st, n["V"] = re.subn(r"\(V : RunV Hdr\)\n", BINDERS + "\n", st)
    st, n["prot"] = re.subn(r"classifyProtocolU S Rp Lq V P \(CinR\) h64 hr hon\.base 24448",
                            "classifyProtocolUExec Rp Lq Lb preA preB start inc incG blk outc outcG P (CinR) h64 hr "
                            "hon.base 24448", st)
    st, n["rest"] = re.subn(r"(?<![\w.'])V(?![\w'])", RUNV, st)
    assert n["V"] == 1 and n["prot"] >= 9 and n["rest"] >= 2, n
    print(f"{new}: {n['prot']} occurrences of the instance replaced, {n['rest']} other occurrences of V")
    st = amend(st, "rt_productionReady_r13", new, "classifyLeak S Rp")
    names_new = explicit_names(st)
    assert "V" not in names_new and all(a in names_new for a in names if a != "V"), "binders"
    subst = {"V": RUNV}
    return (f"{doc}\n{st}"
            f"{proof('rt_productionReady_r13', names, 'classifyUExec_leaksAtMost', subst, gate_section_names())}")


def section_vars(text, sec):
    """The `variable` lines and local notation of section `sec` of RunTrGate.lean (up to its first doc comment)."""
    i = text.index(f"section {sec}\n") + len(f"section {sec}\n")
    j = text.index("/--", i)
    return text[i:j]


HEADER = '''/-
D63 lane L42 (2026-11-10), part 4: **the media classifier's production gates in the approved form of D76.**
GENERATED by `results/zk60_lean_l42_20261110/l42_mk_gate.py` from RunChainUExec.lean and RunTrGate.lean: do not edit by
hand.

* `clsLeakOf`, `served_eq`, `clsLeak_eq`: the instance's declared leakage (`ClsLeak`, L18) is `classifyLeak` read as a
  `ClsLeak`;
* **`classify_leaksAtMost`**, **`classifyU_leaksAtMost`**, **`classifyUExec_leaksAtMost`**: the three classify
  instances (L18's `classifyProtocol`, L26's `classifyProtocolU`, L30's `classifyProtocolUExec`, the production target
  by D77) leak no more than `classifyLeak` (`LeaksAtMost`);
* **`classifyUExec_productionReadyL_run_r13`**, **`classifyUExec_productionReadyL_run_w16r2`**: L30's two gates at
  `classifyProtocolUExec`, concluding `ProductionReadyL … (classifyLeak S R) …` under the SAME premises (the statements
  are copied from RunChainUExec.lean, only the conclusion changed);
* **`rt_productionReadyL_r13`**: L34's gate on the run's transcript, the same way (any run verifier `V`, at
  `classifyProtocolU`); **`rt_productionReadyL_r13_exec`**: the same at `V := classifyRunV …`, so at
  `classifyProtocolUExec`;
* **`classifyU_zkL_target_of_refErr`**, **`classifyUExec_zkL_target_of_refErr`**: lane L33's receipt cap meets the
  approved zero-knowledge and semantic-hiding statements AT THE TARGET under D76's range (`R ≤ 2^64` lies inside L33's
  `R ≤ 2^110`): the only premise is L33's own (`ZeroKnowledge` of the classify run at the error of a refusing prover,
  `refErr RunK.kinds`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StatementsD76Bridge
import ZK60Formal.StatementsD76Leak
import ZK60Formal.RunTrGate
import ZK60Formal.ZKHonestRun

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (classifyLeak LeaksAtMost productionReadyL_of_productionReady zeroKnowledgeL_target_of_cap_or
  semanticHidingL_of_zeroKnowledgeL)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## The classify instances leak no more than `classifyLeak` -/

section Leak

/-- `classifyLeak`'s value read as L18's `ClsLeak`. -/
def clsLeakOf (z : ℕ × ℕ × ℕ × Bool) : ClsLeak := ⟨z.1, z.2.1, z.2.2.1, z.2.2.2⟩

/-- The served bit two ways: L18 decides admissibility, `classifyLeak` asks whether the integer model returns a
verdict. -/
theorem served_eq (S : BlockShape) (R : ClassifyRunPublic S) (x : S.Tok → ℕ) :
    @decide ((classifyModel S R).admissible x) (Classical.propDecidable _) = (classifySpec R x).isSome := by
  rw [Bool.eq_iff_iff, @decide_eq_true_iff _ (Classical.propDecidable _), Option.isSome_iff_exists]
  rfl

/-- **The instance's declared leakage is `classifyLeak`**, field by field: `T`, `d`, the block count, and the served
bit. -/
theorem clsLeak_eq (S : BlockShape) (R : ClassifyRunPublic S) (x : S.Tok → ℕ) :
    clsLeak S R x = clsLeakOf (classifyLeak S R x) := by
  unfold clsLeak
  rw [served_eq]
  rfl

variable {R : ClassifyRunPublic S} {Lq : ℕ} {V : RunV Hdr} {P : RunP Hdr (S.Tok → ℕ) Coins}
  {Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt} {h64 : 64 ≤ Lq} {hr : 8 * Cin.R ≤ Lq} {base : Coins → Salt}
  {e : ℕ}

/-- **L18's `classifyProtocol` leaks no more than `classifyLeak`** (superseded by D77; kept for completeness). -/
theorem classify_leaksAtMost :
    LeaksAtMost (classifyProtocol S R Lq V P Cin h64 hr base) (classifyLeak S R) :=
  ⟨clsLeakOf, funext fun x => clsLeak_eq S R x⟩

/-- **L26's `classifyProtocolU` leaks no more than `classifyLeak`.** -/
theorem classifyU_leaksAtMost :
    LeaksAtMost (classifyProtocolU S R Lq V P Cin h64 hr base e) (classifyLeak S R) :=
  ⟨clsLeakOf, funext fun x => clsLeak_eq S R x⟩

variable {Lb : ℕ} {preA preB : Hdr → Except String Unit} {start : (HIn → Dig) → ClsStmt Hdr → Tr} {inc : Hdr → IncV}
  {incG : Hdr → StageGeom} {blk : BlockProfV (ClsStmt Hdr)} {outc : Hdr → ℕ → OutcV} {outcG : Hdr → StageGeom}

/-- **L30's `classifyProtocolUExec`, the production target (D77), leaks no more than `classifyLeak`.** -/
theorem classifyUExec_leaksAtMost :
    LeaksAtMost (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e)
      (classifyLeak S R) :=
  classifyU_leaksAtMost

end Leak

/-! ## The zero-knowledge part from lane L33's receipt cap, at the target -/

section Cap

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **The approved zero-knowledge and semantic-hiding statements at the target for `classifyProtocolU`, from lane L33's
premise alone.** L33 proved (`classifyU_zk_cap110`) that if the classify run is zero knowledge at the error of a
refusing prover (`refErr RunK.kinds`), its error capped at `1` is within `εzkTarget q R` for every `q` and every
`R ≤ 2^110`. D76's range (`R ≤ 2^64`) lies inside, so the approved statements hold at the target. -/
theorem classifyU_zkL_target_of_refErr (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ)
    (hzk : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base)
      (ZKHonest.refErr ZKCount.RunK.kinds)) :
    ZeroKnowledgeL (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr base e) (classifyLeak S R) εzkTarget
      ∧ SemanticHidingL (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr base e) (classifyLeak S R)
          (fun q => εzkTarget q 1) := by
  have h := ZKHonest.classifyU_zk_cap110 R Lq V P Cin h64 hr base e hzk
  have hz := zeroKnowledgeL_target_of_cap_or (classifyLeak S R) classifyU_leaksAtMost h.1 110 (by norm_num) h.2
  exact ⟨hz, semanticHidingL_of_zeroKnowledgeL _ _ hz⟩

/-- **The same at the production target `classifyProtocolUExec` (D77).** -/
theorem classifyUExec_zkL_target_of_refErr (R : ClassifyRunPublic S) (Lq : ℕ) (Lb : ℕ)
    (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV)
    (incG : Hdr → StageGeom) (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (e : ℕ)
    (hzk : ZeroKnowledge (classifyModel S R)
      (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base)
      (ZKHonest.refErr ZKCount.RunK.kinds)) :
    ZeroKnowledgeL (classifyModel S R)
        (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e) (classifyLeak S R)
        εzkTarget
      ∧ SemanticHidingL (classifyModel S R)
          (classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P Cin h64 hr base e)
          (classifyLeak S R) (fun q => εzkTarget q 1) :=
  classifyU_zkL_target_of_refErr R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P Cin h64 hr base e
    hzk

end Cap

/-! ## The gates at `classifyProtocolUExec` (L30), in the approved form -/

section Gates

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

'''

MID = '''
end Gates

/-! ## The gate on the run's transcript (L34), in the approved form -/

section GateR13

'''

FOOTER = '''
end GateR13

end ZK60.ProtocolClassify
'''

DOC_UR = ('/-- **THE GATE at R13, the media app\'s profile, at the production instance, in the approved form (D76)**: '
          'L30\'s\n`classifyUExec_productionReady_run_r13` with its conclusion `ProductionReadyL … (classifyLeak S R) …`'
          '. The premises\nare the same text. -/')
DOC_UW = ('/-- **THE GATE at W16R2 at the production instance, in the approved form (D76)**: L30\'s\n'
          '`classifyUExec_productionReady_run_w16r2` with its conclusion `ProductionReadyL … (classifyLeak S R) …`. '
          'The\npremises are the same text. -/')
DOC_RT = ('/-- **THE GATE at R13 on the run\'s transcript, in the approved form (D76)**: L34\'s `rt_productionReady_r13` '
          'with its\nconclusion `ProductionReadyL … (classifyLeak S Rp) …`, for any run verifier `V`. The premises are '
          'the same text. -/')
DOC_RX = ('/-- **THE GATE at R13 on the run\'s transcript at the production instance `classifyProtocolUExec` (D77), in '
          'the approved\nform (D76)**: L34\'s `rt_productionReady_r13` at `V := classifyRunV …`, with its conclusion\n'
          '`ProductionReadyL … (classifyLeak S Rp) …`. The premises are the same text with `V` replaced. -/')

body = (uexec_gate("classifyUExec_productionReady_run_r13", "classifyUExec_productionReadyL_run_r13", DOC_UR) + "\n"
        + uexec_gate("classifyUExec_productionReady_run_w16r2", "classifyUExec_productionReadyL_run_w16r2", DOC_UW))
gate_vars = section_vars(rtgate, "GateR13")
body2 = (gate_vars + rt_gate("rt_productionReadyL_r13", DOC_RT) + "\n"
         + rt_gate_exec("rt_productionReadyL_r13_exec", DOC_RX))
open(dst, "w", encoding="utf-8").write(HEADER + body + MID + body2 + FOOTER)
print("wrote", dst)
