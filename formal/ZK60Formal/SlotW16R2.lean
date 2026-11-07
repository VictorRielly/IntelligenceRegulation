/-
D63 step L11, part 2: **the W16R2 slot list**, as clearly named definitions (W16R3's B2 / B3 replace exactly these):
the 23 slots in transcript order, their kinds and hosts, the schedule `(main rounds, extension rounds, degree)` as a
function of the shape, each slot's challenge draws in `define` (which challenge is `τ`, `μ`, `ν`, `ζ`, which claim
point it starts), the hand-off of claim points from the private slots to their hosts, and the slots' numerator sum at
the W16R2 8B shape (finding F44, ASSEMBLY §4.2 item d).

Read off the sources (2026-11-07; nothing there is changed), all under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`:
* `layout.rs:976-1114`: `SC_*`, `SLOT_NAMES`, `SLOT_KINDS`, `HOSTS`; `shape.rs:619-627` `BASE_DEGREE`,
  `INDICATOR_SLOT_DOMAIN`; `shape.rs:2660-2714` `Shape::slots` (the cube of each slot, a matmul's INNER log, two
  extension rounds for the bilinear slots, `+1` for a padded indicator domain, `+1` for the key-value group `eq`);
* the draws: `argument.rs::define` (`SC_SS` … `SC_DMM`, `SC_LZC`, `SC_RS`, `SC_ZS`, `SC_IO_*`, lines 2022-2331,
  2860-2952) and `argument_accuracy.rs`'s `*_w16` arms (`dzc_w16` 465-467, `fzc_w16` 507-509, `qzc_w16` 541-543,
  `szc_w16` 577-581, `tab_w16` 747-748), each draw `tr.challenge_fp2_vec(len)`;
* the pad host of each domain: `pad.rs:366-382` (`pad_zero_host`).

What is proved here (only `propext`, `Classical.choice`, `Quot.sound`):
* `drawLen_sched`: a slot's draws are the sum of its segments (the checker replays exactly that many squeezes);
* **`w16r2_8B_numerator_le`**, `w16r2_shield_numerator_le`: at the W16R2 8B T128 shape (and at Shieldstral's, which
  has the same axis logs), the slots' small numerators — sumcheck rounds × degree, every zero-check point and claim point
  length, one per batch, and up to 64 per slot for a pad term's `ζ` powers — sum to at most `2^16` (finding F44's
  premise of `BlockZone8B`, FSPathBlock.lean:576): `1,479 + 3·pp` (`1,539 + 4·pp` at Shieldstral), `blockNum_eq`.
-/
import ZK60Formal.SlotW16Ir

namespace ZK60.Exec.Slot.W16R2

/-! ## The slots (layout.rs:976-999) -/

abbrev scSS : ℕ := 0
abbrev scSSM : ℕ := 1
abbrev scTZC : ℕ := 2
abbrev scLZC : ℕ := 3
abbrev scRS : ℕ := 4
abbrev scQMM : ℕ := 5
abbrev scKMM : ℕ := 6
abbrev scVMM : ℕ := 7
abbrev scSCORE : ℕ := 8
abbrev scPV : ℕ := 9
abbrev scWO : ℕ := 10
abbrev scGMM : ℕ := 11
abbrev scUMM : ℕ := 12
abbrev scDMM : ℕ := 13
abbrev scDZC : ℕ := 14
abbrev scQZC : ℕ := 15
abbrev scKVZC : ℕ := 16
abbrev scSZC : ℕ := 17
abbrev scFZC : ℕ := 18
abbrev scTAB : ℕ := 19
abbrev scZS : ℕ := 20
abbrev scIOIN : ℕ := 21
abbrev scIOOUT : ℕ := 22

/-- The W16R2 block runs 23 slots (no dictionary: `SC_DD` is a DD profile's 24th). -/
abbrev nSlots : ℕ := 23

/-- `SlotKind` (layout.rs:1067-1075): a private slot publishes `s + c·G` (its total enters only its host's `Γ`); a
standalone slot has the public claimed sum `0` (it publishes `c·G`); a host's claimed sum is `Σ ν·κ·claim_s + Γ`. -/
inductive Kind where
  | priv
  | standalone
  | host
  deriving DecidableEq, Repr

/-- `SLOT_KINDS` (layout.rs:1077-1104). -/
def kindOf (s : ℕ) : Kind :=
  if s = scTZC ∨ s = scDZC ∨ s = scQZC ∨ s = scKVZC ∨ s = scSZC ∨ s = scFZC then .host
  else if s = scLZC ∨ s = scTAB ∨ s = scZS ∨ s = scIOIN ∨ s = scIOOUT then .standalone
  else .priv

/-- `HOSTS` (layout.rs:1107-1114): each host slot and the two private slots it hosts, in `ν` order. -/
def hostsOf (s : ℕ) : List ℕ :=
  if s = scTZC then [scSS, scSSM]
  else if s = scDZC then [scWO, scDMM]
  else if s = scQZC then [scQMM, scPV]
  else if s = scKVZC then [scKMM, scVMM]
  else if s = scSZC then [scRS, scSCORE]
  else if s = scFZC then [scGMM, scUMM]
  else []

/-- The ten domains' first nine, in `ALL_DOMS` order (layout.rs:973; the dictionary `Dd` is a DD profile's). -/
inductive Dom where
  | T | Ht | L | D | Q | Kv | S | F | Tab
  deriving DecidableEq, Repr

/-- A domain's position in `ALL_DOMS` (the corpus's arrays use this order). -/
def Dom.idx : Dom → ℕ
  | .T => 0 | .Ht => 1 | .L => 2 | .D => 3 | .Q => 4 | .Kv => 5 | .S => 6 | .F => 7 | .Tab => 8

/-- `BASE_DEGREE` (shape.rs:619). -/
def baseDegree (s : ℕ) : ℕ := [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2].getD s 0

/-- `INDICATOR_SLOT_DOMAIN` (shape.rs:626-627): the eight slots whose relation is gated by a support indicator. -/
def indicatorDom (s : ℕ) : Option Dom :=
  if s = scSS ∨ s = scSSM ∨ s = scDZC then some .D
  else if s = scRS ∨ s = scSZC then some .S
  else if s = scQZC then some .Q
  else if s = scKVZC then some .Kv
  else if s = scFZC then some .F
  else none

/-- The cube of a slot that sums over a domain (`Shape::slots`'s `cube`). -/
def cubeDom (s : ℕ) : Option Dom :=
  if s = scSS ∨ s = scSSM ∨ s = scDZC ∨ s = scIOIN ∨ s = scIOOUT then some .D
  else if s = scTZC then some .T
  else if s = scLZC then some .L
  else if s = scRS ∨ s = scSZC then some .S
  else if s = scQZC then some .Q
  else if s = scKVZC then some .Kv
  else if s = scFZC then some .F
  else if s = scTAB ∨ s = scZS then some .Tab
  else none

/-- `pad_zero_host` (pad.rs:366-382): the slot that carries a padded domain's batched pad-zero term. -/
def padHost : Dom → ℕ
  | .T => scTZC | .Ht => scSZC | .L => scLZC | .D => scDZC | .Q => scQZC | .Kv => scKVZC | .S => scSZC
  | .F => scFZC | .Tab => scTAB

/-! ## The shape facts the schedule reads -/

/-- **The shape facts of one W16R2 block** (the corpus's `SHAPE` line; `shape.rs`): the axis logs (tokens, head slots,
head dimension, width, hidden, query width, key-value width, key-value groups), whether the profile carries the pad
rule, the range sub-plane count, the rows per `Dom::Ht` position of `Dom::S`, and per domain its log (after the P-3
lift), whether it pads, its helper count, whether it has zero-rule `A` planes. -/
structure ShapeW where
  lt : ℕ
  lh : ℕ
  ldh : ℕ
  ld : ℕ
  lf : ℕ
  lq : ℕ
  lkvw : ℕ
  lkv : ℕ
  padRule : Bool
  nRange : ℕ
  perRow : ℕ
  logs : Dom → ℕ
  pads : Dom → Bool
  helpers : Dom → ℕ
  zeroRule : Dom → Bool

/-- A matmul's INNER log (shape.rs:2683-2693): the bilinear slots also sum over the key-value group bits. -/
def innerLog (sh : ShapeW) (s : ℕ) : ℕ :=
  if s = scWO then sh.lq
  else if s = scSCORE then sh.lkv + sh.ldh
  else if s = scPV then sh.lkv + sh.lt
  else if s = scDMM then sh.lf
  else sh.ld

/-- **`Shape::slots`** (shape.rs:2660-2714): `(main rounds, extension rounds, degree)` of slot `s`. -/
def sched (sh : ShapeW) (s : ℕ) : ℕ × ℕ × ℕ :=
  let main := match cubeDom s with
    | some d => sh.logs d
    | none => innerLog sh s
  let bil := s = scSCORE ∨ s = scPV
  let ext := if bil then 2 else 1
  let ind : ℕ := match indicatorDom s with
    | some d => if sh.padRule && sh.pads d then 1 else 0
    | none => 0
  let geq : ℕ := if bil ∧ 0 < sh.lkv then 1 else 0
  (main, ext, baseDegree s + ind + geq)

/-- Whether slot `s` hosts a batched pad-zero term (`pad_on`): some domain it is the pad host of has zero-rule planes. -/
def padOn (sh : ShapeW) (s : ℕ) : Bool :=
  [Dom.T, .Ht, .L, .D, .Q, .Kv, .S, .F, .Tab].any fun d => padHost d == s && sh.zeroRule d

/-! ## The challenges each slot's `define` draws -/

/-- What a run of draws is for: a zero-check point `τ`, a claim point's coordinates (named), the batching vectors `μ`,
`ν`, the pad batching `ζ`, the row-sum batching `λ`, `SC_LZC`'s pad weight. -/
inductive Seg where
  | tau
  | pt (name : String)
  | mu
  | nu
  | zeta
  | lam
  | muPad
  deriving DecidableEq, Repr

/-- **The draws of slot `s`'s `define`, in order** (each one `challenge_fp2_vec(len)`; `p` is the slot's `pad_on`). -/
def draws (sh : ShapeW) (s : ℕ) : List (Seg × ℕ) :=
  let p : ℕ := if padOn sh s then 1 else 0
  if s = scSS then [(.pt "r_t", sh.lt)]
  else if s = scSSM then [(.pt "r_t2", sh.lt)]
  else if s = scTZC then [(.tau, sh.lt), (.mu, 6 + p), (.nu, 2), (.zeta, p)]
  else if s = scLZC then [(.tau, sh.logs .L), (.muPad, p), (.zeta, p)]
  else if s = scRS then [(.pt "p_ht", sh.logs .Ht), (.lam, 1)]
  else if s = scQMM then [(.pt "r_q", sh.lt), (.pt "r_j", sh.lq)]
  else if s = scKMM ∨ s = scVMM then [(.pt "r_j", sh.lkvw)]
  else if s = scSCORE then [(.pt "r_h", sh.lh), (.pt "r_t", sh.lt), (.pt "r_j", sh.lt)]
  else if s = scPV then [(.pt "r_h", sh.lh), (.pt "r_t", sh.lt), (.pt "r_i", sh.ldh)]
  else if s = scWO then [(.pt "r_q", sh.lt), (.pt "r_j", sh.ld)]
  else if s = scGMM then [(.pt "r_tf", sh.lt), (.pt "r_j", sh.lf)]
  else if s = scUMM then [(.pt "r_j", sh.lf)]
  else if s = scDMM then [(.pt "r_row", sh.lt), (.pt "r_j", sh.ld)]
  else if s = scDZC then [(.mu, 6 + sh.helpers .D + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .D)]
  else if s = scQZC then [(.mu, 1 + sh.helpers .Q + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .Q)]
  else if s = scKVZC then [(.mu, 1 + sh.helpers .Kv + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .Kv)]
  else if s = scSZC then [(.tau, sh.logs .S), (.mu, 4 + sh.helpers .S + 1 + p), (.nu, 2), (.zeta, p)]
  else if s = scFZC then [(.mu, 2 + sh.helpers .F + p), (.nu, 2), (.zeta, p), (.tau, sh.logs .F)]
  else if s = scTAB then [(.tau, sh.logs .Tab), (.mu, 3 + sh.nRange + p), (.zeta, p)]
  else if s = scIOIN ∨ s = scIOOUT then [(.tau, sh.logs .D)]
  else []

/-- How many squeezes slot `s`'s `define` makes. -/
def drawLen (sh : ShapeW) (s : ℕ) : ℕ := ((draws sh s).map Prod.snd).sum

/-- Split a slot's draws into its segments, in order. -/
def splitDraws : List (Seg × ℕ) → List Fp2 → List (Seg × List Fp2)
  | [], _ => []
  | (g, k) :: gs, xs => (g, xs.take k) :: splitDraws gs (xs.drop k)

/-- The first segment of a kind. -/
def segOf (g : Seg) (l : List (Seg × List Fp2)) : List Fp2 := ((l.find? fun q => q.1 == g).map Prod.snd).getD []

theorem drawLen_sched (sh : ShapeW) (s : ℕ) : drawLen sh s = ((draws sh s).map Prod.snd).sum := rfl

/-! ## The hand-off of claim points (argument.rs `Points`, read by the hosts' `b.eq`) -/

/-- **The claim point slot `s` publishes** for its host, from the slots' draws so far (`segs k` = slot `k`'s segments):
`SC_SS`: `r_t`; `SC_SSM`: `r_t2`; `SC_RS`: `p_ht`; `SC_QMM`: `(r_q, r_j)`; `SC_KMM` / `SC_VMM`: `(r_q of SC_QMM, r_j)`;
`SC_SCORE`: `(r_h, r_t, r_j)`; `SC_PV`: `(r_t, r_h, r_i)`; `SC_WO`: `(its own r_q, r_j)`; `SC_GMM`: `(r_tf, r_j)`;
`SC_UMM`: `(r_tf of SC_GMM, r_j)`; `SC_DMM`: `(r_row, r_j)`. -/
def claimPoint (segs : ℕ → List (Seg × List Fp2)) (s : ℕ) : List Fp2 :=
  let g := fun k (n : String) => segOf (.pt n) (segs k)
  if s = scSS then g scSS "r_t"
  else if s = scSSM then g scSSM "r_t2"
  else if s = scRS then g scRS "p_ht"
  else if s = scQMM then g scQMM "r_q" ++ g scQMM "r_j"
  else if s = scKMM ∨ s = scVMM then g scQMM "r_q" ++ g s "r_j"
  else if s = scSCORE then g s "r_h" ++ g s "r_t" ++ g s "r_j"
  else if s = scPV then g s "r_t" ++ g s "r_h" ++ g s "r_i"
  else if s = scWO then g s "r_q" ++ g s "r_j"
  else if s = scGMM then g s "r_tf" ++ g s "r_j"
  else if s = scUMM then g scGMM "r_tf" ++ g s "r_j"
  else if s = scDMM then g s "r_row" ++ g s "r_j"
  else []

/-- **The eq tables a slot must hold, in table order**: a zero-check's `τ` first (then, for a host, its hosted slots'
claim points in `ν` order); a standalone `IO` slot's `τ`; a private row-sum slot's own point; a bilinear slot's group
`eq(r_g, ·)` over the top `lkv` bits of its head point (`B::group_eq`, the S19-F1 repair; none at one key-value head). -/
def eqPoints (sh : ShapeW) (segs : ℕ → List (Seg × List Fp2)) (s : ℕ) : List (List Fp2) :=
  if kindOf s = .host then segOf .tau (segs s) :: (hostsOf s).map (claimPoint segs)
  else if s = scLZC ∨ s = scTAB ∨ s = scIOIN ∨ s = scIOOUT then [segOf .tau (segs s)]
  else if s = scSS ∨ s = scSSM ∨ s = scRS then [claimPoint segs s]
  else if s = scSCORE ∨ s = scPV then (if 0 < sh.lkv then [(segOf (.pt "r_h") (segs s)).take sh.lkv] else [])
  else []

/-- **The hosted coefficients of a host's claimed sum** (`hosted`): `ν_k`, and `ν_0·per_row` for `SC_RS`
(`szc_w16`, argument_accuracy.rs:597). -/
def hostedCoefs (sh : ShapeW) (segs : ℕ → List (Seg × List Fp2)) (s : ℕ) : List (ℕ × Fp2) :=
  let nu := segOf .nu (segs s)
  (hostsOf s).zipIdx.map fun p =>
    (p.1, if p.1 = scRS then (nu.getD p.2 Fp2.zero).mul (Fp2.fromU64 (UInt64.ofNat sh.perRow)) else nu.getD p.2 Fp2.zero)

/-! ## The numerator sum (finding F44) -/

/-- A draw segment's small numerator in L3's accounting (`Kind8BP`, FSPathBlock.lean:440-473): a point of length `ℓ`
(a zero-check or a claim point) costs `ℓ`, a batch `1`; a pad term's `ζ` costs `pp` (at most its plane count, the
degree of the pad polynomial in `ζ`) per drawn `ζ`, counted by `zetaLen`. -/
def segFix : Seg × ℕ → ℕ
  | (.tau, l) => l
  | (.pt _, l) => l
  | (.mu, k) => if 0 < k then 1 else 0
  | (.nu, _) => 1
  | (.zeta, _) => 0
  | (.lam, _) => 1
  | (.muPad, k) => if 0 < k then 1 else 0

/-- How many `ζ` a segment draws. -/
def zetaLen : Seg × ℕ → ℕ
  | (.zeta, k) => k
  | _ => 0

def segNum (pp : ℕ) (g : Seg × ℕ) : ℕ := segFix g + pp * zetaLen g

/-- **A slot's numerator**: its sumcheck's `(main + ext)·degree`, its draws' numerators, and its hosted claim
points' lengths (charged at the private slot, whose claim is checked at its point by the host). The claim points of
`SC_KMM`, `SC_VMM` and `SC_UMM` reuse coordinates drawn by `SC_QMM` / `SC_GMM`; their lengths are charged again in
full (`claimLen`). -/
def claimLen (sh : ShapeW) (s : ℕ) : ℕ :=
  if s = scKMM ∨ s = scVMM then sh.lt else if s = scUMM then sh.lt else 0

def slotNum (sh : ShapeW) (pp : ℕ) (s : ℕ) : ℕ :=
  let sc := sched sh s
  (sc.1 + sc.2.1) * sc.2.2 + ((draws sh s).map (segNum pp)).sum + claimLen sh s

/-- The block's slots' numerator sum. -/
def blockNum (sh : ShapeW) (pp : ℕ) : ℕ := ((List.range nSlots).map (slotNum sh pp)).sum

/-- The block's numerator without the pad charges, and its count of pad terms (`ζ` draws). -/
def blockFix (sh : ShapeW) : ℕ := ((List.range nSlots).map (slotNum sh 0)).sum
def zetaTotal (sh : ShapeW) : ℕ := ((List.range nSlots).map fun s => ((draws sh s).map zetaLen).sum).sum

theorem sum_map_split {α : Type} (f g : α → ℕ) (pp : ℕ) :
    ∀ l : List α, (l.map fun s => f s + pp * g s).sum = (l.map f).sum + pp * (l.map g).sum
  | [] => by simp
  | s :: l => by
    simp only [List.map_cons, List.sum_cons]
    rw [sum_map_split f g pp l]
    ring

/-- **The pad charges enter linearly**: `pp` per pad term. -/
theorem blockNum_eq (sh : ShapeW) (pp : ℕ) : blockNum sh pp = blockFix sh + pp * zetaTotal sh := by
  have hs : ∀ s, slotNum sh pp s = slotNum sh 0 s + pp * ((draws sh s).map zetaLen).sum := by
    intro s
    have e : ∀ q, (draws sh s).map (segNum q) = (draws sh s).map (fun g => segFix g + q * zetaLen g) := fun q => rfl
    simp only [slotNum]
    rw [e pp, e 0, sum_map_split segFix zetaLen pp, sum_map_split segFix zetaLen 0]
    ring
  unfold blockNum blockFix zetaTotal
  rw [← sum_map_split (slotNum sh 0) (fun s => ((draws sh s).map zetaLen).sum) pp]
  exact congrArg List.sum (List.map_congr_left fun s _ => hs s)

/-- **The W16R2 8B T128 shape** (shape.rs:302: tokens 128, width 4096, hidden 14336, 32 query heads of 128, 8 key-value
heads, `log_cols = 14`): axis logs `lt = 7`, `lh = 5`, `ldh = 7`, `ld = 12`, `lf = 14`, `lq = 12`, `lkvw = 10`,
`lkv = 3`; domain logs `T 7, Ht 12, L 14 (lifted), D 19, Q 19, Kv 17, S 19, F 21, Tab 14 (lifted)`; padded: `L`, `F`
(14336 of 16384 hidden channels), `Tab`. The helper counts and the range sub-plane count enter no numerator; they are
left at `0` here. -/
def sh8B : ShapeW where
  lt := 7
  lh := 5
  ldh := 7
  ld := 12
  lf := 14
  lq := 12
  lkvw := 10
  lkv := 3
  padRule := true
  nRange := 0
  perRow := 128
  logs d := match d with
    | .T => 7 | .Ht => 12 | .L => 14 | .D => 19 | .Q => 19 | .Kv => 17 | .S => 19 | .F => 21 | .Tab => 14
  pads d := match d with
    | .L | .F | .Tab => true
    | _ => false
  helpers _ := 0
  zeroRule d := match d with
    | .L | .F | .Tab => true
    | _ => false

/-- **The W16R2 Shieldstral T128 shape** (shape.rs:301: width 3072 → `d_pad = 4096`, hidden 9216 → `f_pad = 16384`,
otherwise the 8B geometry): the same axis and domain logs. `D`'s true width is 3072 of 4096 and `F`'s 9216 of 16384, so
`D` pads too. -/
def shShield : ShapeW := { sh8B with
  pads := fun d => match d with
    | .L | .D | .F | .Tab => true
    | _ => false
  zeroRule := fun d => match d with
    | .L | .D | .F | .Tab => true
    | _ => false }

theorem blockFix_8B : blockFix sh8B = 1479 := by decide

theorem zetaTotal_8B : zetaTotal sh8B = 3 := by decide

theorem blockFix_shield : blockFix shShield = 1539 := by decide

theorem zetaTotal_shield : zetaTotal shShield = 4 := by decide

/-- **F44 discharged at the W16R2 8B shape**: with a pad charge of at most `64` per pad term (the `ζ` polynomial's
degree is below its plane count), the 23 slots' small numerators sum to `1,479 + 3·pp ≤ 1,671`, at most `2^16`
(`BlockZone8B`'s premise). -/
theorem w16r2_8B_numerator_le (pp : ℕ) (hpp : pp ≤ 64) : blockNum sh8B pp ≤ 2 ^ 16 := by
  rw [blockNum_eq, blockFix_8B, zetaTotal_8B]
  omega

/-- The same at the W16R2 Shieldstral T128 shape: `1,539 + 4·pp`. -/
theorem w16r2_shield_numerator_le (pp : ℕ) (hpp : pp ≤ 64) : blockNum shShield pp ≤ 2 ^ 16 := by
  rw [blockNum_eq, blockFix_shield, zetaTotal_shield]
  omega

end ZK60.Exec.Slot.W16R2
