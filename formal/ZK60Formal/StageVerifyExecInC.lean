/-
D63 Lean lane L29 (2026-11-07), part 2: **stage IN-C's schedule, layout and slot definitions, executable**, line for
line as hashline's `stage_in_c.rs` writes them (read 2026-11-07; nothing there is changed):
* `layout` (:42-57): the four slots (INC-00 IO-in, INC-01 the query zero-check, INC-02 the table zero-check, INC-03 the
  zero-sum row), `A = [tok, mult]`, `H = [h_q, h_tab, u]` with signs `[1, −1, 1]`, `row_log = [lt, lt, ep_log_n,
  endpoint_log_n]`;
* `challenges` (:254-262): `β, γ, α`, `r_emb` (`clog2(d_pad)` coordinates), `g_emb = γ·TAG_EMB`, the embedding fold;
* `tau_table` (:160-164): `τ(v) = v + β·E~(v, r) + β²·ctl(v) + g_emb`, padded rows repeating row 0;
* `define` (:166-238): each slot's tables in the code's push order, its closure, its draws.

The classifier's public data the stage reads (`ClassifierProfile`, `ClassifierTables`) are `IncPub`'s fields: the
template (`is_template`, `kappa`), the control class (`num_special`), BOS, `T`, the pads, the vocabulary, the tier's
logs, and the embedding's fold `E~(·, r)` as a function (`emb_fold`, the public weights' MLE in the row index; the
weights are not in the repository, D62). The run's geometry (`IncGeo`: the endpoint's data rows and width, `B_in`'s
row width and reserved pair) is the statement's.

Only definitions here (the theorems are in `StageVerifyExec.lean`); nothing is a sorry, an axiom or a native decision.
-/
import ZK60Formal.StageVerifyExecLay

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60.Exec ZK60.Exec.Block
open ZK60.Exec.StageCheck (kI vg mb supp)

/-! ## The public data -/

/-- **Stage IN-C's public data** (`ClassifierProfile`, `ClassifierTables`; the tier's logs). -/
structure IncPub where
  tokens : ℕ
  tPad : ℕ
  dPad : ℕ
  v : ℕ
  bos : ℕ
  numSpecial : ℕ
  isTemplate : ℕ → Bool
  kappa : ℕ → ℕ
  lt : ℕ
  epLogN : ℕ
  embDigest : Dig
  embFold : List Fp2 → List Fp2

/-- **The run's geometry around stage IN-C** (the statement's: `in_spec`, `boundary_spec(0)`). -/
structure IncGeo where
  bLogN : ℕ
  bRows : ℕ
  bInRow : ℕ
  epDataRows : ℕ
  epRows : ℕ

namespace IncPub

variable (I : IncPub)

/-- `ti_log()`, `voc_log()`, `in_ep_words()`, `ep_n()`. -/
def tiLog : ℕ := max (clog2 I.tPad) I.lt
def vocLog : ℕ := max (clog2 I.v) I.lt
def epN : ℕ := 2 ^ I.epLogN
def inEpWords : ℕ := max I.tPad I.epN
/-- `ctl(v)`, `ctl_q(t)`. -/
def ctl (x : ℕ) : Bool := decide (x < I.numSpecial)
def ctlQ (t : ℕ) : Bool := I.isTemplate t && I.ctl (I.kappa t)
/-- `(t_pad·d_pad).trailing_zeros()` (both powers of two). -/
def bInLog : ℕ := Nat.log2 (I.tPad * I.dPad)
def tBits : ℕ := clog2 I.tPad
def rBits : ℕ := clog2 I.dPad

end IncPub

/-! ## The layout -/

def incA_TOK : ℕ := 0
def incA_MULT : ℕ := 1
def incH_Q : ℕ := 0
def incH_TAB : ℕ := 1
def incH_U : ℕ := 2

/-- `A_GROUPS`, `H_GROUPS` (stage_in_c.rs:39-40). -/
def incAGroups : ℕ := 3
def incHGroups : ℕ := 4

/-- **Stage IN-C's schedule** (stage_in_c.rs:45-55). -/
def incSched (I : IncPub) (bLogN : ℕ) : Sched where
  label := "stage IN-C"
  slots :=
    [⟨"INC-00 IO-in: token endpoint = supp_T tok (whole padded plane: template and content)", clog2 I.inEpWords, 1, 3,
        .standalone, 1, 0, 1⟩,
     ⟨"INC-01 query zero-check: LogUp over (id, row, ctl) + BOS + TEMPLATE (prefix, suffix, trailing pad ids) + pad, fresh mu each",
        I.tiLog, 1, 4, .standalone, 1, 1, 1⟩,
     ⟨"INC-02 table zero-check: h_tab (alpha - tau(v, ctl)) = m + pad, fresh mu each", I.vocLog, 1, 4, .standalone, 1, 1,
        0⟩,
     ⟨"INC-03 ZS zero-sum row", I.lt, 1, 2, .standalone, 0, 1, 0⟩]
  hosts := []
  rowLog := [I.lt, I.lt, I.epLogN, bLogN]

/-- **Stage IN-C's layout** (`StageLayout::new(stage_params, [lti, lvoc], [lti, lvoc, lt], [1, −1, 1], H_U, sched)`). -/
def incLay (I : IncPub) (bLogN : ℕ) : Lay :=
  ⟨I.lt, [I.tiLog, I.vocLog], [I.tiLog, I.vocLog, I.lt], [1, -1, 1], incH_U, incSched I bLogN⟩

/-- Each slot's IO row width (`row_log[p.cm]`): INC-00's claim is on the token endpoint (`ep_log_n`), INC-01's on
`B_in` (`endpoint_log_n`); INC-02 and INC-03 have none. -/
def incElog (I : IncPub) (bLogN : ℕ) (s : ℕ) : ℕ := if s = 0 then I.epLogN else bLogN

/-! ## The challenges and the table -/

/-- `TAG_EMB` (token_io.rs:355). -/
def tagEmb : ℕ := 135

/-- **What `define` reads** (`InCCtx`): `α`, `β`, `g_emb`, `r_emb`, the table `τ`. -/
structure IncCtx where
  alpha : Fp2
  beta : Fp2
  gEmb : Fp2
  rEmb : List Fp2
  tauTab : List Fp2

/-- **`tau_table`**: true rows `v + β·E~(v, r) + β²·ctl(v) + g_emb`; padded rows repeat row 0's whole tuple. -/
def tauTable (I : IncPub) (ef : List Fp2) (beta gEmb : Fp2) : List Fp2 :=
  let b2 := beta.mul beta
  let row : ℕ → Fp2 := fun x => (((kI x).add (beta.mul (ef.getD x Fp2.zero))).add (if I.ctl x then b2 else Fp2.zero)).add gEmb
  (List.range (2 ^ I.vocLog)).map (fun x => if x < I.v then row x else row 0)

/-- The head's challenge count: `β, γ, α` and `r_emb`. -/
def incHeadDraws (I : IncPub) : ℕ := 3 + I.rBits

/-- **`challenges`** read off the head's draws `[β, γ, α] ++ r_emb`: the context `define` reads. -/
def incCtx (I : IncPub) (ch : List Fp2) : IncCtx :=
  let beta := ch.getD 0 Fp2.zero
  let gamma := ch.getD 1 Fp2.zero
  let alpha := ch.getD 2 Fp2.zero
  let rEmb := ch.drop 3
  let gEmb := gamma.mulBase (Fp.new (UInt64.ofNat tagEmb))
  ⟨alpha, beta, gEmb, rEmb, tauTable I (I.embFold rEmb) beta gEmb⟩

/-! ## The definitions -/

/-- Each slot's draws: INC-00 `τ` (`clog2(words)`); INC-01 `τ` (`ti_log`), `μ` (4), `ζ` (1); INC-02 `τ` (`voc_log`),
`μ` (2), `ζ` (1); INC-03 none. -/
def incDraws (I : IncPub) : ℕ → ℕ
  | 0 => clog2 I.inEpWords
  | 1 => I.tiLog + 4 + 1
  | 2 => I.vocLog + 2 + 1
  | _ => 0

section Define

variable (I : IncPub) (G : IncGeo) (cx : IncCtx)

/-- INC-00 IO-in: `eq·(end − supp·tok)`, tables `[eq τ, supp_T, A tok at (0…0, ρ), In end]`. -/
def incDefIO (dr : List Fp2) : Except String SlotDef :=
  let L := incLay I G.bLogN
  let words := I.inEpWords
  let lw := clog2 words
  build (do
    let iEq ← eqT (dr.take lw) 0
    let iSupp ← pubT (supp I.tokens words)
    let iTok ← aAtT L 0 incA_TOK (fixedC (List.replicate (I.tiLog - lw) Fp2.zero) ++ rhoC 0 lw)
    let iEnd ← ioT .inp lw (rhoC 0 lw) G.epDataRows
    finishT L 0 (fun v => (vg v iEq).mul ((vg v iEnd).sub ((vg v iSupp).mul (vg v iTok)))) [])

/-- INC-01 the query zero-check: the LogUp clause over `(id, row, ctl)`, the BOS, TEMPLATE and pad clauses, each with
its own coefficient; tables `[eq τ, supp_T, u0, π, κ, cq, A tok, H h_q, Out B_in at (row bits, r_emb)]`. -/
def incDefQZC (dr : List Fp2) : Except String SlotDef := do
  let L := incLay I G.bLogN
  let tl := I.tiLog
  let tau := dr.take tl
  let mu ← nonzeroE ((dr.drop tl).take 4)
  let zeta ← (nonzeroE ((dr.drop (tl + 4)).take 1)).map (fun z => z.getD 0 Fp2.zero)
  let sn := 2 ^ tl
  let b2 := cx.beta.mul cx.beta
  build (do
    let iEq ← eqT tau 0
    let iSupp ← pubT (supp I.tokens sn)
    let iU0 ← pubT (supp 1 sn)
    let iPi ← pubT ((List.range sn).map (fun t => if I.isTemplate t then Fp2.one else Fp2.zero))
    let iKappa ← pubT ((List.range sn).map (fun t => kI (I.kappa t)))
    let iCq ← pubT ((List.range sn).map (fun t => if I.ctlQ t then b2 else Fp2.zero))
    let iTok ← aT L 1 incA_TOK
    let iHq ← hT L 1 incH_Q
    let iB ← ioT .out I.bInLog (rhoC (tl - I.tBits) tl ++ fixedC cx.rEmb) G.bInRow
    let bos := kI I.bos
    finishT L 1 (fun v =>
      let q := (((vg v iTok).add (cx.beta.mul (vg v iB))).add (vg v iCq)).add cx.gEmb
      let logup := ((vg v iHq).mul (cx.alpha.sub q)).sub (vg v iSupp)
      let bosC := (vg v iU0).mul ((vg v iTok).sub bos)
      let tmpl := (vg v iPi).mul ((vg v iTok).sub (vg v iKappa))
      let pad := (Fp2.one.sub (vg v iSupp)).mul ((vg v iTok).add (zeta.mul (vg v iHq)))
      (vg v iEq).mul (((((vg mu 0).mul logup).add ((vg mu 1).mul bosC)).add ((vg mu 2).mul tmpl)).add
        ((vg mu 3).mul pad))) [])

/-- INC-02 the table zero-check: `h_tab·(α − τ) − m` and the pad; tables `[eq τ, supp_V, τ table, A mult, H h_tab]`. -/
def incDefTZC (dr : List Fp2) : Except String SlotDef := do
  let L := incLay I G.bLogN
  let lv := I.vocLog
  let tau := dr.take lv
  let mu ← nonzeroE ((dr.drop lv).take 2)
  let zeta ← (nonzeroE ((dr.drop (lv + 2)).take 1)).map (fun z => z.getD 0 Fp2.zero)
  build (do
    let iEq ← eqT tau 0
    let iSupp ← pubT (supp I.v (2 ^ lv))
    let iTau ← pubT cx.tauTab
    let iM ← aT L 2 incA_MULT
    let iH ← hT L 2 incH_TAB
    finishT L 2 (fun v =>
      let rel := ((vg v iH).mul (cx.alpha.sub (vg v iTau))).sub (vg v iM)
      let pad := (Fp2.one.sub (vg v iSupp)).mul ((vg v iM).add (zeta.mul (vg v iH)))
      (vg v iEq).mul (((vg mu 0).mul rel).add ((vg mu 1).mul pad))) [])

/-- INC-03 the zero-sum row: `1·u`, tables `[ones, H u]`. -/
def incDefZS : Except String SlotDef :=
  let L := incLay I G.bLogN
  build (do
    let i1 ← pubT (List.replicate (2 ^ L.hLog.getD incH_U 0) Fp2.one)
    let iu ← hT L 3 incH_U
    finishT L 3 (fun v => (vg v i1).mul (vg v iu)) [])

/-- **Stage IN-C's `define`** (stage_in_c.rs:166-238), from the slot's draws (L9's modelling step: the draws first,
then the refusals of `nonzero`). -/
def incDefine (s : ℕ) (_hist : Hist) (dr : List Fp2) : Except String SlotDef :=
  match s with
  | 0 => incDefIO I G dr
  | 1 => incDefQZC I G cx dr
  | 2 => incDefTZC I G cx dr
  | 3 => incDefZS I G
  | _ => .error "classifier stage IN-C: unknown slot"

end Define

end ZK60.Exec.StageV
