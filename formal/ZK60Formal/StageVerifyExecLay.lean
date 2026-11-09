/-
D63 Lean lane L29 (2026-11-07), part 1: **a token stage's layout, its slot builder and its slot loop, executable**, as
hashline's `token_io.rs` writes them (read 2026-11-07; nothing there is changed):
* `StageLayout::new` (:810-841): the planes contiguous and row aligned, one reserved pair per claim site in slot order,
  then the proximity pair; `a_site` / `h_site` (:849-860), the site rows, `h_u_rows`, `m_rows`, `mask_specs`,
  `n_functionals` (:861-883) and `logup_sum_claim` (:887-896);
* the slot builder `SB` (:1160-1225): `eq`, `public`, `a_slice`, `a_at`, `a`, `h`, `io`, `finish` (the site counts
  checked against the declared schedule);
* `run_stage_slot` (:997-1135) is `argument::run_slot` line for line (lane L15, `StageFS.lean`) EXCEPT that it reads
  each commitment's row width from the stage's own `row_log` (`[A, H, In, Out]`): L9's `BlockParams` has ONE
  `endpointLogN` for both IO commitments, and stage IN-C's two differ (the token endpoint's `ep_log_n`, `B_in`'s
  `endpoint_log_n`; finding L29-1). Every claim of a slot is on ONE IO commitment at most, so the stage's slot loop is
  L9's `slotStep` at the slot's own row width: `stSlotsLoop` (`elog s` the width of slot `s`'s IO commitment).

Proved here:
* `stSlotsLoop_const`: with one width for every slot, the stage's slot loop IS L9's `slotsLoop` (stage OUT-C);
* **`slotStep_strip`**, **`stSlotsLoop_strip`**: the row width changes ONLY the claims: the records, the transcript and
  the rest of the accumulator (`c`s, scalars, `M` functionals) are L9's `slotsLoop`'s at any width; so lane L15's
  `stageSlots` (the Fiat–Shamir model of a stage's slot phase) reads the same run.

Every premise is an explicit hypothesis; every proof is complete and kernel-checked.
-/
import ZK60Formal.StageFS
import ZK60Formal.StageCheckDefs

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60.Exec ZK60.Exec.Block
open ZK60.Exec.StageCheck (kI vg mb)

/-! ## Numbers -/

/-- `clog2(v)` (token_io.rs:370): `v.next_power_of_two().trailing_zeros()` (`v ≥ 1`). -/
def clog2 (v : ℕ) : ℕ := if v ≤ 1 then 0 else Nat.log2 (v - 1) + 1

/-- `rows_of` (token_io.rs:805): `max(1, 2^log >> log_n)`. -/
def rowsOf (log logN : ℕ) : ℕ := max 1 (2 ^ log / 2 ^ logN)

/-! ## The schedule and the layout -/

/-- `SlotSpec` (token_io.rs:742-756). -/
structure SSpec where
  name : String
  main : ℕ
  ext : ℕ
  degree : ℕ
  kind : SlotKind
  aSites : ℕ
  hSites : ℕ
  ioSites : ℕ

/-- `SlotSpec::terms`. -/
def SSpec.terms (x : SSpec) : ℕ := x.aSites + x.hSites + x.ioSites

def sspec0 : SSpec := ⟨"", 0, 0, 0, .priv, 0, 0, 0⟩

/-- `StageSched` (token_io.rs:766-773): the label, the slots, the host groups, the row width of `[A, H, In, Out]`. -/
structure Sched where
  label : String
  slots : List SSpec
  hosts : List (ℕ × List ℕ)
  rowLog : List ℕ

/-- **`StageLayout::new`'s inputs** (token_io.rs:810): the row width `log_cols`, the `A` and `H` planes' logs, the `H`
planes' LogUp signs, the zero-sum pair's plane, the schedule. Everything else is computed as the code computes it. -/
structure Lay where
  logN : ℕ
  aLog : List ℕ
  hLog : List ℕ
  hSign : List ℤ
  hU : ℕ
  sched : Sched

namespace Lay

variable (L : Lay)

def n : ℕ := 2 ^ L.logN
def ns : ℕ := L.sched.slots.length
def spec (s : ℕ) : SSpec := L.sched.slots.getD s sspec0

def aRowsL : List ℕ := L.aLog.map (fun l => rowsOf l L.logN)
def hRowsL : List ℕ := L.hLog.map (fun l => rowsOf l L.logN)

/-- `a_off[p]`: the plane's first row times `n`. -/
def aOff (p : ℕ) : ℕ := (L.aRowsL.take p).sum * L.n
def aDataRows : ℕ := L.aRowsL.sum
/-- `a_prefix[s]`, `h_prefix[s]`. -/
def prefixA (s : ℕ) : ℕ := ((L.sched.slots.take s).map SSpec.aSites).sum
def prefixH (s : ℕ) : ℕ := ((L.sched.slots.take s).map SSpec.hSites).sum
def aMaskBase : ℕ := L.aDataRows
def aProx : ℕ := L.aMaskBase + 2 * L.prefixA L.ns
def aRows : ℕ := L.aProx + 2
/-- `h_off[p]`: the plane's real and imaginary halves (two row blocks). -/
def hOff (p : ℕ) : ℕ × ℕ :=
  ((2 * (L.hRowsL.take p).sum) * L.n, (2 * (L.hRowsL.take p).sum + L.hRowsL.getD p 0) * L.n)
def hDataRows : ℕ := 2 * L.hRowsL.sum
def hMaskBase : ℕ := L.hDataRows
def hProx : ℕ := L.hMaskBase + 2 * L.prefixH L.ns
def hRows : ℕ := L.hProx + 2

/-- `a_site(slot, k)`: the reserved pair of the slot's `k`-th `A` site. -/
def aSite (s k : ℕ) : Except String ℕ :=
  if (L.spec s).aSites ≤ k then .error s!"token I/O {L.sched.label}: undeclared A site {k} in slot {s}"
  else .ok (L.aMaskBase + 2 * (L.prefixA s + k))

def hSite (s k : ℕ) : Except String ℕ :=
  if (L.spec s).hSites ≤ k then .error s!"token I/O {L.sched.label}: undeclared H site {k} in slot {s}"
  else .ok (L.hMaskBase + 2 * (L.prefixH s + k))

def aSiteRows : List ℕ := List.range' L.aMaskBase (L.aProx - L.aMaskBase)
def hSiteRows : List ℕ := List.range' L.hMaskBase (L.hProx - L.hMaskBase)
/-- `h_u_rows()`: the zero-sum pair's two rows. -/
def hURows : ℕ × ℕ := ((L.hOff L.hU).1 / L.n, (L.hOff L.hU).2 / L.n)
def mRows : ℕ := 2 * L.ns + 4
/-- `mask_specs()`: per slot `(main + ext, degree)`. -/
def maskSpecs : List (ℕ × ℕ) := L.sched.slots.map (fun s => (s.main + s.ext, s.degree))
/-- `n_functionals()`. -/
def nFunctionals : ℕ :=
  (L.sched.slots.map (fun s => 1 + if s.kind = SlotKind.standalone then 1 else 0)).sum + L.sched.hosts.length

/-- **`logup_sum_claim()`**: every `H` plane with its sign, real half then imaginary half (`sign·u`), as ONE pairless
claim of value `0`. -/
def logupSumClaim : ZClaim :=
  ⟨(List.range L.hLog.length).flatMap (fun p =>
      [⟨(L.hOff p).1, L.hLog.getD p 0, kI (L.hSign.getD p 0), []⟩,
       ⟨(L.hOff p).2, L.hLog.getD p 0, (kI (L.hSign.getD p 0)).mul fp2U, []⟩]), Fp2.zero⟩

/-- The schedule as L9's geometry rows `(main, ext, degree)` and terminal counts. -/
def geomSlots : List (ℕ × ℕ × ℕ) := L.sched.slots.map (fun s => (s.main, s.ext, s.degree))
def geomTerms : List ℕ := L.sched.slots.map SSpec.terms

end Lay

/-! ## The slot builder (`SB`) -/

/-- The builder's state: the tables so far and the `A`, `H`, IO sites used. -/
structure SBS where
  tabs : List Tab := []
  ak : ℕ := 0
  hk : ℕ := 0
  iok : ℕ := 0

/-- The builder's actions. -/
abbrev SBM (α : Type) : Type := StateT SBS (Except String) α

section Builder

variable (L : Lay) (slot : ℕ)

def pushT (t : Tab) : SBM ℕ := do
  let b ← get
  set { b with tabs := b.tabs ++ [t] }
  pure b.tabs.length

/-- `eq(point, start)`. -/
def eqT (point : List Fp2) (start : ℕ) : SBM ℕ := pushT (.eq point start)
/-- `public(v)`. -/
def pubT (v : List Fp2) : SBM ℕ := pushT (.pub v)
/-- `tabs_len()`. -/
def tabsLen : SBM ℕ := do pure (← get).tabs.length

/-- `a_slice(off, log, coords)`: an `A` slice at the slot's next `A` site. -/
def aSliceT (off log : ℕ) (coords : List Coord) : SBM ℕ := do
  let b ← get
  let row ← (L.aSite slot b.ak : Except String ℕ)
  set { b with ak := b.ak + 1 }
  pushT (.priv ⟨.a, [(off, Fp2.one)], log, coords, row, 0⟩)

/-- `rho(lo..hi)`. -/
def rhoC (lo hi : ℕ) : List Coord := (List.range' lo (hi - lo)).map Coord.rho
/-- `fixed(p)`. -/
def fixedC (p : List Fp2) : List Coord := p.map Coord.fixed
/-- `fixed_bits(value, bits)`: MSB first. -/
def fixedBits (value bits : ℕ) : List Coord :=
  (List.range bits).map (fun b => Coord.fixed (if (value / 2 ^ (bits - 1 - b)) % 2 = 1 then Fp2.one else Fp2.zero))

/-- `a_at(plane, coords)`. -/
def aAtT (plane : ℕ) (coords : List Coord) : SBM ℕ := aSliceT L slot (L.aOff plane) (L.aLog.getD plane 0) coords
/-- `a(plane)`: on its own domain. -/
def aT (plane : ℕ) : SBM ℕ := aAtT L slot plane (rhoC 0 (L.aLog.getD plane 0))

/-- `h(plane)`: the plane's two halves (`1`, `u`) at the slot's next `H` site. -/
def hT (plane : ℕ) : SBM ℕ := do
  let b ← get
  let row ← (L.hSite slot b.hk : Except String ℕ)
  set { b with hk := b.hk + 1 }
  pushT (.priv ⟨.h, [((L.hOff plane).1, Fp2.one), ((L.hOff plane).2, fp2U)], L.hLog.getD plane 0,
    rhoC 0 (L.hLog.getD plane 0), row, 0⟩)

/-- `io(cm, log, coords, mask_row)`: a claim on one of the stage's IO commitments at the run's reserved pair. -/
def ioT (cm : Cm) (log : ℕ) (coords : List Coord) (maskRow : ℕ) : SBM ℕ := do
  let b ← get
  set { b with iok := b.iok + 1 }
  pushT (.priv ⟨cm, [(0, Fp2.one)], log, coords, maskRow, 0⟩)

/-- `finish(poly, hosted)`: the site counts checked against the declared schedule. -/
def finishT (poly : List Fp2 → Fp2) (hosted : List (ℕ × Fp2)) : SBM SlotDef := do
  let b ← get
  let sp := L.spec slot
  if b.ak ≠ sp.aSites ∨ b.hk ≠ sp.hSites ∨ b.iok ≠ sp.ioSites then
    throw s!"token I/O {L.sched.label}: slot {slot} uses {b.ak} A / {b.hk} H / {b.iok} IO sites, the schedule declares {sp.aSites} / {sp.hSites} / {sp.ioSites}"
  else pure ⟨b.tabs, poly, hosted⟩

end Builder

/-- Run a slot's builder from the empty state. -/
def build (m : SBM SlotDef) : Except String SlotDef := (m.run {}).map Prod.fst

/-- `nonzero(v)` (token_io.rs:934): a zero batching challenge refuses. -/
def nonzeroE (v : List Fp2) : Except String (List Fp2) :=
  if v.any Fp2.isZero then .error "zero batching challenge; discard attempt" else .ok v

/-! ## The stage as L9's `BlockParams` -/

/-- **The stage's slot schedule as L9's parameters** (`run_stage_slot` reads exactly these): the geometry and counts of
the layout, the slots' kinds and names, the draws and the definition, the functional count, `logup_sum_claim`, and the
three sub-checks of `M`, `A`, `H` (L10's components). `eLog` is the IO row width this instance reads (`row_log[In]`
or `row_log[Out]`, L29-1). -/
def stageBP (L : Lay) (g : Geom) (eLog aPath hPath maskPath : ℕ) (draws : ℕ → ℕ)
    (define : ℕ → Hist → List Fp2 → Except String SlotDef)
    (maskVerify : (HIn → Dig) → Dig → List MaskFunctional → MaskOpening → Tr → Except String Tr)
    (checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit)
    (pcsVerify : (HIn → Dig) → Cm → Dig → List ZClaim → OpeningZk → Tr → Except String Tr) : BlockParams where
  geom := g
  logCols := L.logN
  endpointLogN := eLog
  aRows := L.aRows
  hRows := L.hRows
  aPath := aPath
  hPath := hPath
  maskPath := maskPath
  preChecks := .ok ()
  kind s := (L.spec s).kind
  name s := (L.spec s).name
  draws := draws
  define := define
  nFunctionals := L.nFunctionals
  logupSumClaim := L.logupSumClaim
  maskVerify := maskVerify
  checkOpening := checkOpening
  pcsVerify := pcsVerify

/-! ## The stage's slot loop -/

section Loop

variable (H : HIn → Dig)

/-- `P` at the IO row width `e`. -/
abbrev atLog (P : BlockParams) (e : ℕ) : BlockParams := { P with endpointLogN := e }

/-- **The stage's slot loop** (`run_slots`: `define`, then `run_stage_slot`, per slot): L9's `slotStep` with slot
`s`'s IO commitment read at its own row width `elog s` (the code's `sched.row_log[p.cm]`). -/
def stSlotsLoop (P : BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    List SlotRec → ℕ → List SlotProof → Acc → Tr → Except String (List SlotRec × Acc × Tr)
  | recs, _, [], acc, t => .ok (recs, acc, t)
  | recs, s, sp :: sps, acc, t =>
    match slotStep H (atLog P (elog s)) s (histOf b g a recs) sp acc t with
    | .error e => .error e
    | .ok (r, acc', t') => stSlotsLoop P elog b g a (recs ++ [r]) (s + 1) sps acc' t'

/-- **With one width for every slot, the stage's slot loop is L9's `slotsLoop`.** -/
theorem stSlotsLoop_const (P : BlockParams) (e : ℕ) (b g a : Fp2) :
    ∀ (recs : List SlotRec) (s : ℕ) (sps : List SlotProof) (acc : Acc) (t : Tr),
      stSlotsLoop H P (fun _ => e) b g a recs s sps acc t = slotsLoop H (atLog P e) b g a recs s sps acc t
  | _, _, [], _, _ => rfl
  | recs, s, sp :: sps, acc, t => by
    simp only [stSlotsLoop, slotsLoop]
    rcases slotStep H (atLog P e) s (histOf b g a recs) sp acc t with err | ⟨r, acc', t'⟩
    · rfl
    · exact stSlotsLoop_const P e b g a _ _ sps _ _

/-- The accumulator without its claims: the `c`s, the scalars, the `M` functionals. -/
def accStrip (a : Acc) : List Fp2 × List Fp2 × List MaskFunctional × List MaskFunctional :=
  (a.cs, a.scalars, a.fs, a.hostFs)

/-- A slot step's result without the accumulator's claims. -/
def stripR (x : SlotRec × Acc × Tr) : SlotRec × (List Fp2 × List Fp2 × List MaskFunctional × List MaskFunctional) × Tr :=
  (x.1, accStrip x.2.1, x.2.2)

/-- **A slot's row width and its incoming claims change only its outgoing claims**: at any width `e` and with any
incoming claims `cl`, `slotStep`'s verdict, record, transcript and claim-free accumulator are L9's. -/
theorem slotStep_strip (P : BlockParams) (e : ℕ) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (cl : Claims4)
    (t : Tr) :
    stripR <$> slotStep H (atLog P e) s hist sp { acc with claims := cl } t = stripR <$> slotStep H P s hist sp acc t := by
  simp only [slotStep, map_bind, map_pure]
  rfl

/-- `Except`'s map on a result. -/
theorem map_ok_iff {ε α β : Type} (f : α → β) (x : Except ε α) (b : β) :
    f <$> x = .ok b ↔ ∃ a, x = .ok a ∧ f a = b := by
  cases x with
  | error e => exact ⟨fun h => (by cases h), fun ⟨_, h, _⟩ => by cases h⟩
  | ok a => exact ⟨fun h => ⟨a, rfl, by cases h; rfl⟩, fun ⟨a', h, h'⟩ => by cases h; rw [← h']; rfl⟩

theorem map_error_iff {ε α β : Type} (f : α → β) (x : Except ε α) (e : ε) :
    f <$> x = .error e ↔ x = .error e := by
  cases x with
  | error e' => exact ⟨fun h => (by cases h; rfl), fun h => by cases h; rfl⟩
  | ok a => exact ⟨fun h => (by cases h), fun h => by cases h⟩

/-- **The stage's slot loop and L9's `slotsLoop` agree on everything but the claims**: at any widths `elog`, the
verdict, the records, the transcript and the claim-free accumulator of `stSlotsLoop` are `slotsLoop`'s at `P` (lane
L15's `stageSlots` reads exactly these: the stage's Fiat–Shamir model sees the same run). -/
theorem stSlotsLoop_strip (P : BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    ∀ (recs : List SlotRec) (s : ℕ) (sps : List SlotProof) (acc : Acc) (cl : Claims4) (t : Tr),
      (fun x : List SlotRec × Acc × Tr => (x.1, accStrip x.2.1, x.2.2)) <$>
          stSlotsLoop H P elog b g a recs s sps { acc with claims := cl } t
        = (fun x : List SlotRec × Acc × Tr => (x.1, accStrip x.2.1, x.2.2)) <$> slotsLoop H P b g a recs s sps acc t
  | _, _, [], _, _, _ => rfl
  | recs, s, sp :: sps, acc, cl, t => by
    have h1 := slotStep_strip H P (elog s) s (histOf b g a recs) sp acc cl t
    simp only [stSlotsLoop, slotsLoop]
    rcases hB : slotStep H P s (histOf b g a recs) sp acc t with e | ⟨r₂, ⟨c₂, s₂, l₂, f₂, g₂⟩, t₂⟩
    · rw [hB] at h1
      have hA : slotStep H (atLog P (elog s)) s (histOf b g a recs) sp { acc with claims := cl } t = .error e :=
        (map_error_iff stripR _ e).mp h1
      rw [hA]
    · rw [hB] at h1
      obtain ⟨⟨r, ⟨c₁, s₁, l₁, f₁, g₁⟩, t'⟩, hA, hy⟩ := (map_ok_iff stripR _ _).mp h1
      rw [hA]
      have hy' : (r, (c₁, s₁, f₁, g₁), t') = (r₂, (c₂, s₂, f₂, g₂), t₂) := hy
      simp only [Prod.mk.injEq] at hy'
      obtain ⟨rfl, ⟨rfl, rfl, rfl, rfl⟩, rfl⟩ := hy'
      exact stSlotsLoop_strip P elog b g a _ _ sps ⟨c₁, s₁, l₂, f₁, g₁⟩ l₁ t'

end Loop

end ZK60.Exec.StageV
