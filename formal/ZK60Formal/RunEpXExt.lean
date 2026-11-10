/-
D63 lane L58 (2026-11-10), part 1: **ONE tag-checked extractor for the input endpoint** (the brief's deliverable 1;
findings L52-1, L52-5; L52 §5.3 items 1 to 3).

Lane L52 built the tag-checked extraction of an opening (`ebOpenX`, L52-1) but the top theorem's column test still read
its matrix `Ux` and its column set `Xx` with L51's UNCHECKED `colXM`, which can return columns the checked extractor
drops, so `hread` (the test's extraction and `ops` agree) was not met by every prover. Here `ops`, `Ux`, `Xx` are read
from ONE checked extractor, and its failure is bounded by L16's `ExtBad` argument:

* **`epx_desc_of_climb`**, **`epx_open_of_opens`**: where an opening verifies, the CHECKED descent returns its path and
  the checked extraction returns the WHOLE opening (column, salt, path), unless L16's bad event `ExtBad` holds of the
  verifier's queries (the same event, with the same targets, as L16's `extract_of_opens` for the unchecked one);
* **`epx_fail_run`**: L16's `extract_fail_run` for ANY failure predicate that implies `ExtBad` (its proof, with
  `extract_of_opens` replaced by that implication);
* `EvXC`, **`extract_fail_xc`**, **`extract_fail_xc_u126`**: the extraction failure under a reader with BOTH
  extractions (L51's `EvXM` for `colXM`, or the checked one misses an opened column), bounded exactly as `EvXM`:
  `(q + 1)·(2^16 + 2^18)/2^126`; `evXC_of_xm`: it contains `EvXM`;
* `exEvIn`, **`exEvIn_le`**, `exEvIn_of_eb`: that event at the run (it REPLACES L52's `ebEvIn`, which it contains, with
  the same bound `εxRun`): the R13 total stays `55,852,891 ≤ 2^26` (L52's `eb_total`, `eb_bud_r13`);
* `epxAt`, `epxHn`, `epxH`, `exXx`, `exUx`, `epxOps`: the checked extractor (from the prover's log cut at the root's
  first absorption, tag-checked, `rows`-row columns with canonical entries), read at the root the header shows
  (`Xx`, `Ux`) or at the statement's input root (`ops`); **`exXx_cut`**, **`exUx_cut`**: cut readers (`hXc`, `hUc`);
* **`epxAt_opens`**, **`ex_hops`**, **`ex_hcan`**: every opening it returns opens against the root under the
  commitment's encoding, with canonical entries (the top theorem's `hops`, `hcan`), for every adversary and oracle;
* **`epxH_at_root`**: at a header that shows the root `r`, the header reader IS the extractor at `r` (`hread`'s step);
* **`epx_xok`**: outside `EvXC`, every sampled column that verifies against a root of the list, with `rows` canonical
  entries, is the column the checked extractor returns (`hBal`'s extraction step).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpBExt

set_option autoImplicit false

namespace ZK60.Sound

namespace MerkleEnc

variable {Q D S Col : Type} (M : MerkleEnc Q D S Col) [DecidableEq Q] [DecidableEq D]

/-- **THE CHECKED DESCENT FOLLOWS THE CLIMB** (L16's `descend_of_climb` for `ebDescP`): if the climb along `p` from
`cur` reaches a target `t`, and every node a logged question names has target children, then the checked descent from
`t` by `|p|` levels at position `j` returns `cur` AND the path `p`, unless the extraction's bad event holds for the
climb's queries. -/
theorem epx_desc_of_climb (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (Tg : Finset D)
    (hTg : ∀ y ∈ L.map Prod.fst, ∀ lr, M.nodeDec y = some lr → lr.1 ∈ Tg ∧ lr.2 ∈ Tg) (j : ℕ) (p : List D) :
    ∀ (cur t : D), t ∈ Tg → M.climb H j cur p = t →
      (M.ebDescP L p.length j t = some (cur, p) ∧ cur ∈ Tg) ∨ ExtBad H L Tg (M.climbQs H j cur p) := by
  induction p using List.reverseRecOn with
  | nil =>
    intro cur t ht hc
    left
    simp only [climb] at hc
    subst hc
    exact ⟨rfl, ht⟩
  | append_singleton p s ih =>
    intro cur t ht hc
    rw [M.climb_append] at hc
    subst hc
    rcases find_or_bad H L hL Tg _ ht with hf | hb
    · obtain ⟨e, he, he1, -⟩ := findPre_some hf
      have hmem : M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s ∈ L.map Prod.fst :=
        he1 ▸ List.mem_map_of_mem he
      have hk := hTg _ hmem _ (M.nodeDec_stepQ (j / 2 ^ p.length) (M.climb H j cur p) s)
      have hkid : M.climb H j cur p ∈ Tg := by
        by_cases hbit : (j / 2 ^ p.length) % 2 = 0
        · simpa [hbit] using hk.1
        · simpa [hbit] using hk.2
      have h1 : M.ebNode L (H (M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s))
          = (M.nodeDec (M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s)).bind
            (fun lr => if M.nodeQ lr.1 lr.2 = M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s then some lr
              else none) := by
        simp only [ebNode, hf, Option.bind_some]
      have hnode : M.ebNode L (H (M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s))
          = some (if (j / 2 ^ p.length) % 2 = 0 then (M.climb H j cur p, s) else (s, M.climb H j cur p)) := by
        rw [h1, M.nodeDec_stepQ]
        by_cases hbit : (j / 2 ^ p.length) % 2 = 0
        · simp [hbit, stepQ]
        · simp [hbit, stepQ]
      have hdesc : M.ebDescP L (p ++ [s]).length j (H (M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s))
          = (M.ebDescP L p.length j (M.climb H j cur p)).map (fun r => (r.1, r.2 ++ [s])) := by
        rw [List.length_append, List.length_singleton, ebDescP, hnode]
        by_cases hbit : (j / 2 ^ p.length) % 2 = 0
        · simp [hbit]
        · simp [hbit]
      rcases ih cur _ hkid rfl with ⟨hd, hcur⟩ | hb'
      · left
        refine ⟨?_, hcur⟩
        simp only [hdesc, hd, Option.map_some]
      · right
        refine hb'.mono (fun w hw => ?_)
        rw [M.climbQs_append]
        exact List.mem_append_left _ hw
    · right
      refine hb.mono (fun w hw => ?_)
      rw [List.mem_singleton] at hw
      rw [hw, M.climbQs_append]
      simp

/-- **THE CHECKED EXTRACTION RETURNS THE WHOLE OPENING UNLESS BAD** (L16's `extract_of_opens` for `ebOpenX`): if an
opening at position `j` verifies against `root` (a path of the tree's depth `h`), the checked extraction from the log
`L` returns that opening (column, salt, path), unless one of the verifier's queries collides with a logged question or a
never-logged verifier's query has an answer among the log's targets: the SAME bad event as the unchecked extraction's. -/
theorem epx_open_of_opens (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (root : D)
    {h j : ℕ} {o : MerkleOpening D S Col} (ho : M.Opens H h root j o) :
    M.ebOpenX L h j root = some o ∨ ExtBad H L (M.targets L root) (M.openQs H j o) := by
  have hsub : ∀ vs : List Q, (∀ v ∈ vs, v ∈ M.openQs H j o) →
      ExtBad H L (M.targets L root) vs → ExtBad H L (M.targets L root) (M.openQs H j o) :=
    fun vs h hb => hb.mono h
  rcases M.epx_desc_of_climb H L hL (M.targets L root) (fun y hy lr hd => M.nodeKid_mem_targets hy hd) j o.path
      (M.leafDigest H o.col o.salt) root (M.root_mem_targets L root) ho.2 with ⟨hd, hℓ⟩ | hb
  · rw [ho.1] at hd
    have hd' : M.ebDescP L h j root = some (H (M.leafQ (H (M.colQ o.col)) o.salt), o.path) := hd
    rcases find_or_bad H L hL (M.targets L root) (M.leafQ (H (M.colQ o.col)) o.salt) hℓ with hf | hb
    · obtain ⟨e, he, he1, -⟩ := findPre_some hf
      have hmem : M.leafQ (H (M.colQ o.col)) o.salt ∈ L.map Prod.fst := he1 ▸ List.mem_map_of_mem he
      have hx := M.leafKid_mem_targets (root := root) hmem (M.leafDec_leafQ (H (M.colQ o.col)) o.salt)
      rcases find_or_bad H L hL (M.targets L root) (M.colQ o.col) hx with hf' | hb'
      · left
        unfold ebOpenX
        simp [hd', hf, M.leafDec_leafQ, hf', M.colDec_colQ]
      · right
        exact hsub _ (fun v hv => by rw [List.mem_singleton] at hv; simp [openQs, hv]) hb'
    · right
      exact hsub _ (fun v hv => by rw [List.mem_singleton] at hv; simp [openQs, hv]) hb
  · right
    exact hsub _ (fun v hv => by simp [openQs, hv]) hb

end MerkleEnc

end ZK60.Sound

namespace ZK60.Exec

open ZK60.Sound
open scoped ENNReal
open Finset

section EpxRun

variable {Q D S Col : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **AN EXTRACTION FAILURE THAT IMPLIES L16'S BAD EVENT IS RARE, IN ANY RUN** (L16's `extract_fail_run` for any
failure predicate `Bad` of the cut log, the depth, the position, the root and the opening, such that a verifying opening
with `Bad` forces `ExtBad`). The proof is L16's, with `extract_of_opens` replaced by that implication. -/
theorem epx_fail_run (M : MerkleEnc Q D S Col) (absOf : Q → Option D) {α β : Type} (A : OC Q D α)
    (rootsOf : α → List D) (nr : ℕ) (hnr : ∀ a, (rootsOf a).length ≤ nr) (V : α → OC Q D β) (T : ℕ)
    (hCm : (A.bind V).Bounded T)
    (Bad : List (Q × D) → ℕ → ℕ → D → MerkleOpening D S Col → Prop)
    (hBad : ∀ (H : Q → D) (L : List (Q × D)), (∀ e ∈ L, e.2 = H e.1) →
      ∀ (r : D) (h j : ℕ) (o : MerkleOpening D S Col), M.Opens H h r j o → Bad L h j r o →
        ExtBad H L (M.targets L r) (M.openQs H j o)) :
    prH (fun H => ∃ r ∈ rootsOf (A.run H), ∃ (h j : ℕ) (o : MerkleOpening D S Col), M.Opens H h r j o
        ∧ (∀ v ∈ M.openQs H j o, v ∈ OC.queries H (A.bind V))
        ∧ Bad (cutAt absOf r (A.runLog H).2) h j r o)
      ≤ collBound T D + ((2 * T * T + (1 + nr) * T : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  set Cm := A.bind V with hCmdef
  set FX : List (Q × D) → Q → Finset D := extNamedR M absOf A rootsOf with hFX
  have hcoll := collision_prob_le Cm T hCm
  have hfr := freshHitQ_prob_le_gen Cm T hCm FX (fun t => 4 * t + (1 + nr))
    (fun P y => extNamedR_card M absOf A rootsOf nr hnr P y)
  have hfr' : prH (fun H => FreshHitQ FX (Cm.runLog H).2)
      ≤ ((2 * T * T + (1 + nr) * T : ℕ) : ℝ≥0∞) / Fintype.card D :=
    hfr.trans (ENNReal.div_le_div_right (Nat.cast_le.mpr (sum_range_four_mul_add_le (1 + nr) T)) _)
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
    (add_le_add hcoll hfr'))
  rintro H ⟨r, hr, h, j, o, hop, hv, hne⟩
  set Lp := (A.runLog H).2 with hLp
  set Lc := cutAt absOf r Lp with hLcdef
  obtain ⟨Lr, hLr⟩ : ∃ Lr, (Cm.runLog H).2 = Lp ++ Lr := ⟨_, OC.runLog_bind H A V⟩
  have hLpQ : ∀ y ∈ Lp.map Prod.fst, y ∈ OC.queries H Cm := by
    intro y hy
    show y ∈ (Cm.runLog H).2.map Prod.fst
    rw [hLr, List.map_append]
    exact List.mem_append_left _ hy
  have hLcA : ∀ e ∈ Lc, e.2 = H e.1 := fun e he => OC.runLog_answer H A e (List.mem_of_mem_take he)
  obtain ⟨v, hvq, hb⟩ := hBad H Lc hLcA r h j o hop hne
  rcases hb with ⟨y, hy, hyv, hHy⟩ | ⟨hvL, hvT⟩
  · left
    have hyLp : y ∈ Lp.map Prod.fst := by
      obtain ⟨e', he', rfl⟩ := List.mem_map.mp hy
      exact List.mem_map_of_mem (List.mem_of_mem_take he')
    exact ⟨y, hLpQ y hyLp, v, hv v hvq, hyv, hHy⟩
  · right
    have hvC : v ∈ (Cm.runLog H).2.map Prod.fst := hv v hvq
    refine freshHitQ_of_first H (OC.runLog_answer H Cm) FX hvC (fun t e ht he hfirst => ?_)
    set c := Lp.findIdx (isAbsAt absOf r) with hc
    have hLc : Lc = Lp.take c := rfl
    have hsplit : (Cm.runLog H).2 = Lc ++ (Lp.drop c ++ Lr) := by
      rw [hLr, hLc, ← List.append_assoc, List.take_append_drop]
    have htc : Lc.length ≤ t := first_after_prefix hvL (by rw [← hsplit]; exact ht) he
    have hpre : Lc <+: (Cm.runLog H).2.take t := by
      rw [hsplit, List.take_append, List.take_of_length_le htc]
      exact List.prefix_append _ _
    rw [MerkleEnc.targets, Finset.mem_insert] at hvT
    rcases hvT with hvr | hvb
    · rw [hvr]
      by_cases hcl : c < Lp.length
      · have hpc : isAbsAt absOf r (Lp[c]'hcl) = true := List.findIdx_getElem
        have hra : absOf (Lp[c]'hcl).1 = some r := by simpa [isAbsAt] using hpc
        have hLclen : Lc.length = c := by rw [hLc, List.length_take, min_eq_left hcl.le]
        have hLc_c : (Cm.runLog H).2[c]? = some (Lp[c]'hcl) := by
          rw [hLr, List.getElem?_append_left hcl, List.getElem?_eq_getElem hcl]
        rcases Nat.lt_or_ge c t with hlt | hge
        · have hmem : (Lp[c]'hcl).1 ∈ ((Cm.runLog H).2.take t).map Prod.fst := mem_take_of_getElem? hLc_c hlt
          refine mem_union_left _ (mem_union_left _ (mem_biUnion.mpr ⟨_, List.mem_toFinset.mpr hmem, ?_⟩))
          refine mem_union_right _ ?_
          rw [hra]
          simp
        · have htc' : t = c := le_antisymm hge (hLclen ▸ htc)
          rw [htc'] at ht
          have hee : e = Lp[c]'hcl := Option.some.inj (ht.symm.trans hLc_c)
          refine mem_union_left _ (mem_union_right _ ?_)
          rw [← he, hee, hra]
          simp
      · have hcl' : c = Lp.length := le_antisymm List.findIdx_le_length (not_lt.mp hcl)
        have hLcLp : Lc = Lp := by rw [hLc, hcl', List.take_length]
        have htLp : Lp.length ≤ t := hLcLp ▸ htc
        have hrep : A.replay ((Cm.runLog H).2.take t) = some (A.run H, Lp.length) := by
          rw [hLr, List.take_append, List.take_of_length_le htLp]
          exact OC.replay_runLog_append H A _
        refine mem_union_right _ ?_
        rw [hrep]
        simp [hr]
    · obtain ⟨y', hy', hvy'⟩ := mem_biUnion.mp hvb
      have hy'P : y' ∈ ((Cm.runLog H).2.take t).map Prod.fst := by
        obtain ⟨e', he', rfl⟩ := List.mem_map.mp (List.mem_toFinset.mp hy')
        exact List.mem_map_of_mem (hpre.subset he')
      exact mem_union_left _ (mem_union_left _ (mem_biUnion.mpr ⟨y', List.mem_toFinset.mpr hy'P,
        mem_union_left _ hvy'⟩))

end EpxRun

end ZK60.Exec

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

/-! ## The failure of either extraction under a reader, and its bound -/

section Fail

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) {α : Type}

/-- **The extraction failure under a reader, for both extractions** (L51's `EvXM`, widened): an opened column verifies
against one of the roots `rx`, all its queries were asked by the prover or by the run verifier's Merkle work, and EITHER
the unchecked extraction (`extractCol`) does not return its column OR the tag-checked one (`ebOpenX`) does not return the
opening, both from the prover's log cut at that root's first absorption under `rd`. -/
def EvXC (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig) (A : OC (QB L) Dig α) (G : QB L → Dig) : Prop :=
  ∃ r ∈ rx (A.run G), ∃ (h j : ℕ) (o : MerkleOpening Dig Dig (ColV L)),
    (merkleEncV tag L h64).Opens G h r j o
    ∧ (∀ v ∈ (merkleEncV tag L h64).openQs G j o,
        v ∈ OC.queries G (A.bind (runV tag L h64 nA nH nM dA dH dM n coreOf Vx)))
    ∧ ((merkleEncV tag L h64).extractCol (cutAt (absMOf L key domain hs hL rd) r (A.runLog G).2) h j r ≠ some o.col
      ∨ (merkleEncV tag L h64).ebOpenX (cutAt (absMOf L key domain hs hL rd) r (A.runLog G).2) h j r ≠ some o)

/-- **It contains L51's `EvXM`.** -/
theorem evXC_of_xm (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig) (A : OC (QB L) Dig α) (G : QB L → Dig)
    (h : EvXM tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx rx A G) :
    EvXC tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx rx A G := by
  obtain ⟨r, hr, h', j, o, hop, hq, hne⟩ := h
  exact ⟨r, hr, h', j, o, hop, hq, Or.inl hne⟩

/-- **The failure of either extraction is as rare as `EvXM`** (`epx_fail_run`: both failures force L16's `ExtBad`,
by `extract_of_opens` and `epx_open_of_opens`). -/
theorem extract_fail_xc (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx) (q : ℕ) (A : OC (QB L) Dig α)
    (hA : A.Bounded q) :
    prH (EvXC tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx rx A)
      ≤ collBound (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx)) Dig
        + ((2 * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx))
            * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx))
          + (1 + nrx) * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx)) : ℕ) : ℝ≥0∞)
          / Fintype.card Dig := by
  classical
  exact epx_fail_run (merkleEncV tag L h64) (absMOf L key domain hs hL rd) A rx nrx hrx
    (runV tag L h64 nA nH nM dA dH dM n coreOf Vx) _
    (OC.Bounded.bind hA (runV_bounded tag L h64 nA nH nM dA dH dM n coreOf Vx nx hVx))
    (fun L' h j r o => (merkleEncV tag L h64).extractCol L' h j r ≠ some o.col
      ∨ (merkleEncV tag L h64).ebOpenX L' h j r ≠ some o)
    (fun H L' hL' r h j o hop hb => by
      rcases hb with hb | hb
      · rcases (merkleEncV tag L h64).extract_of_opens H L' hL' r hop with he | he
        · exact absurd he hb
        · exact he
      · rcases (merkleEncV tag L h64).epx_open_of_opens H L' hL' r hop with he | he
        · exact absurd he hb
        · exact he)

/-- **In the target's units** (L51's `extract_fail_xm_u126` for `EvXC`): for `q + 1 ≤ 2^102`, the run verifier's
Merkle work within `2^22` queries and at most `2^100` roots, at most `(q + 1)·(2^16 + 2^18)/2^126`: the same as
`EvXM`'s. -/
theorem extract_fail_xc_u126 (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hT : n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx ≤ 2 ^ 22) (hnr : nrx ≤ 2 ^ 100)
    (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXC tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx rx A) ≤ u126 q (2 ^ 16 + 2 ^ 18) :=
  (extract_fail_xc tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx nx hVx rx nrx hrx q A hA).trans
    (xfail_le_u126_102 q _ _ hq (by
      have h := hT
      generalize n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx = X at h ⊢
      omega) hnr)

end Fail

/-! ## The event at the run, its bound -/

section Ev

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) {Hdr : Type}

/-- **THE INPUT ENDPOINT'S EXTRACTION EVENT AT THE RUN** (L52's `ebEvIn` widened to both extractions): `EvXC` with the
input root's reader `abRdIn`, the input root as the one root, and the run's own Merkle work. -/
def exEvIn (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB L) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB L → Dig) : Prop :=
  EvXC tag L h64 key domain hs hL abRdIn 256 256 256 16 16 12 26 (rxCoreOf sgeom) (rxVx tag L h64 incG outcG sgeom Lb)
    ebInRoots A G

/-- **It contains L52's `ebEvIn`.** -/
theorem exEvIn_of_eb (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ)
    (A : OC (QB L) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB L → Dig)
    (h : ebEvIn tag L h64 key domain hs hL incG outcG sgeom Lb A G) :
    exEvIn tag L h64 key domain hs hL incG outcG sgeom Lb A G :=
  evXC_of_xm tag L h64 key domain hs hL abRdIn 256 256 256 16 16 12 26 (rxCoreOf sgeom)
    (rxVx tag L h64 incG outcG sgeom Lb) ebInRoots A G h

/-- **ITS BOUND IS `ebEvIn`'S**: within `εxRun q` for every `q` (`(q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102`), at
the run's Merkle work (`907,264 ≤ 2^22` queries) and one root. So it REPLACES `ebEvIn` in the count: the R13 total
stays `55,525,211 + 327,680 = 55,852,891 ≤ 2^26` (L52's `eb_total`, `eb_bud_r13` with the same `cy`). -/
theorem exEvIn_le (incG outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom) (Lb : ℕ) (q : ℕ)
    (A : OC (QB L) Dig (ClsStmt Hdr × ClsReceipt)) (hA : A.Bounded q) :
    prH (exEvIn tag L h64 key domain hs hL incG outcG sgeom Lb A) ≤ εxRun q := by
  unfold εxRun
  by_cases hq : q + 1 ≤ 2 ^ 102
  · rw [ite_eq_left hq]
    exact extract_fail_xc_u126 tag L h64 key domain hs hL abRdIn 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag L h64 incG outcG sgeom Lb) 574464 (rxVx_bounded tag L h64 incG outcG sgeom Lb) ebInRoots 1
      ebInRoots_length (by norm_num) (by norm_num) q hq A hA
  · rw [ite_eq_right hq]
    exact prH_le_one _

/-- **The count with the widened event** (PROVED): it replaces `ebEvIn` with the same constant, so R13's total with the
run's extraction event and the input endpoint's is `55,525,211 + (2^16 + 2^18) = 55,852,891 ≤ 2^26 = 67,108,864`. -/
theorem ex_total : 55525211 + (2 ^ 16 + 2 ^ 18) = 55852891 ∧ 55852891 ≤ 2 ^ 26 ∧ (2 : ℕ) ^ 26 = 67108864 :=
  eb_total

end Ev

/-! ## The checked extractor and its readers -/

section Ext

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **THE CHECKED EXTRACTOR AT A ROOT**: the tag-checked opening at position `j` of the depth-`d` tree with root `r`,
read from the prover's log cut at `r`'s first absorption under `rd`, kept as an opening of `rows`-row columns only if its
column has `rows` entries, all canonical. -/
noncomputable def epxAt (rd : List UInt8 → Option Dig) (d rows : ℕ) (r : Dig) (log : List (QB L × Dig)) (j : ℕ) :
    Option (MerkleOpening Dig Dig (ColR rows)) :=
  ((merkleEncV tag L h64).ebOpenX (cutAt (absMOf L key domain hs hL rd) r log) d j r).bind fun o =>
    if hc : o.col.1.length = rows ∧ ∀ a ∈ o.col.1, a.Canon then some ⟨⟨o.col.1, hc.1⟩, o.salt, o.path⟩ else none

/-- **The checked extractor at the root the header's message at position `i` reads as** (under `rd`), at a position
`j : ℕ`. -/
noncomputable def epxHn (rd : List UInt8 → Option Dig) (d i rows : ℕ) (log : List (QB L × Dig))
    (hdr : List (TItem × Dig)) (j : ℕ) : Option (MerkleOpening Dig Dig (ColR rows)) :=
  match (Block.absAt hdr i).bind rd with
  | some r => epxAt tag L h64 key domain hs hL rd d rows r log j
  | none => none

/-- The same at a position `j : Fin N` (the `ops` shape). -/
noncomputable def epxH (rd : List UInt8 → Option Dig) (d i rows : ℕ) {N : ℕ} (log : List (QB L × Dig))
    (hdr : List (TItem × Dig)) (j : Fin N) : Option (MerkleOpening Dig Dig (ColR rows)) :=
  epxHn tag L h64 key domain hs hL rd d i rows log hdr j.val

/-- **THE TEST'S COLUMN SET** (`Xx`): the columns where the checked extractor at the header's root returns an
opening. -/
noncomputable def exXx (rd : List UInt8 → Option Dig) (d i rows : ℕ) {N : ℕ} (log : List (QB L × Dig))
    (hdr : List (TItem × Dig)) : Finset (Fin N) :=
  exX (epxH tag L h64 key domain hs hL rd d i rows (N := N) log hdr)

/-- **THE TEST'S MATRIX** (`Ux`): the checked extractor's columns at the header's root, read in the base field and
embedded in `K` (`0` where it returns none). -/
noncomputable def exUx {K : Type} [Field K] [Algebra GF K] (rd : List UInt8 → Option Dig) (d i rows : ℕ) {N : ℕ}
    (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) : Fin rows → Fin N → K :=
  fun r j => algebraMap GF K (exU (epxH tag L h64 key domain hs hL rd d i rows (N := N) log hdr) r j)

/-- **THE TOP THEOREM'S `ops`**: the checked extractor at the statement's input root. -/
noncomputable def epxOps {Hdr : Type} (rd : List UInt8 → Option Dig) (d rows : ℕ) {N : ℕ}
    (log : List (QB L × Dig)) (s : ClsStmt Hdr) (j : Fin N) : Option (MerkleOpening Dig Dig (ColR rows)) :=
  epxAt tag L h64 key domain hs hL rd d rows s.inRoot log j.val

/-- **The header reader is a cut reader** (L51's `colXM_cutEq` for the checked extractor). -/
theorem epxHn_cutEq (rd : List UInt8 → Option Dig) (d i rows : ℕ) (hdr : List (TItem × Dig))
    (P P' : List (QB L × Dig)) (h : CutEq (Block.absOfC (chainEncB key domain hs L hL)) hdr P P') (j : ℕ) :
    epxHn tag L h64 key domain hs hL rd d i rows P hdr j = epxHn tag L h64 key domain hs hL rd d i rows P' hdr j := by
  unfold epxHn
  rcases hx : Block.absAt hdr i with _ | x
  · rfl
  · simp only [Option.bind_some]
    rcases hr : rd x with _ | r
    · rfl
    · simp only
      have hc := h i
      rw [hx] at hc
      have hfg : ∀ y, Block.absOfC (chainEncB key domain hs L hL) y = some x → absMOf L key domain hs hL rd y = some r :=
        fun y hy => by rw [absMOf, hy, Option.bind_some, hr]
      unfold epxAt
      rw [ab_cut_coarse_eq _ _ x r hfg P P' hc]

/-- **`hXc`: the test's column set is a cut reader.** -/
theorem exXx_cut (rd : List UInt8 → Option Dig) (d i rows N : ℕ) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs L hL))
      (fun P hdr => exXx tag L h64 key domain hs hL rd d i rows (N := N) P hdr) := by
  intro P P' hdr h
  have e : epxH tag L h64 key domain hs hL rd d i rows (N := N) P hdr
      = epxH tag L h64 key domain hs hL rd d i rows (N := N) P' hdr :=
    funext fun j => epxHn_cutEq tag L h64 key domain hs hL rd d i rows hdr P P' h j.val
  show exX (epxH tag L h64 key domain hs hL rd d i rows (N := N) P hdr)
    = exX (epxH tag L h64 key domain hs hL rd d i rows (N := N) P' hdr)
  rw [e]

/-- **`hUc`: the test's matrix is a cut reader.** -/
theorem exUx_cut {K : Type} [Field K] [Algebra GF K] (rd : List UInt8 → Option Dig) (d i rows N : ℕ) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs L hL))
      (fun P hdr => exUx (K := K) tag L h64 key domain hs hL rd d i rows (N := N) P hdr) := by
  intro P P' hdr h
  have e : epxH tag L h64 key domain hs hL rd d i rows (N := N) P hdr
      = epxH tag L h64 key domain hs hL rd d i rows (N := N) P' hdr :=
    funext fun j => epxHn_cutEq tag L h64 key domain hs hL rd d i rows hdr P P' h j.val
  funext r j
  show algebraMap GF K (exU (epxH tag L h64 key domain hs hL rd d i rows (N := N) P hdr) r j)
    = algebraMap GF K (exU (epxH tag L h64 key domain hs hL rd d i rows (N := N) P' hdr) r j)
  rw [e]

/-- **At a header that shows the root `r`, the header reader IS the extractor at `r`.** -/
theorem epxH_at_root (rd : List UInt8 → Option Dig) (d i rows : ℕ) {N : ℕ} (log : List (QB L × Dig))
    (hdr : List (TItem × Dig)) (r : Dig) (h : (Block.absAt hdr i).bind rd = some r) :
    epxH tag L h64 key domain hs hL rd d i rows (N := N) log hdr
      = fun j => epxAt tag L h64 key domain hs hL rd d rows r log j.val := by
  funext j
  show epxHn tag L h64 key domain hs hL rd d i rows log hdr j.val = _
  simp only [epxHn, h]

/-- **The checked extractor at a found opening**: where the checked extraction returns `o` with `rows` canonical
entries, the extractor returns it as an opening of `rows`-row columns. -/
theorem epxAt_of_ext (rd : List UInt8 → Option Dig) (d rows : ℕ) (r : Dig) (log : List (QB L × Dig)) (j : ℕ)
    (o : MerkleOpening Dig Dig (ColV L))
    (ho : (merkleEncV tag L h64).ebOpenX (cutAt (absMOf L key domain hs hL rd) r log) d j r = some o)
    (hc : o.col.1.length = rows ∧ ∀ a ∈ o.col.1, a.Canon) :
    epxAt tag L h64 key domain hs hL rd d rows r log j = some ⟨⟨o.col.1, hc.1⟩, o.salt, o.path⟩ := by
  simp only [epxAt, ho, Option.bind_some, dite_eq_left hc]

/-- An opening of `rows`-row columns built from a verifying opening of the variable-width encoding verifies under the
bounded encoding (the same queries). -/
theorem epx_opensB (rows : ℕ) (hr : 8 * rows ≤ L) (G : QB L → Dig) (d j : ℕ) (r : Dig)
    (o : MerkleOpening Dig Dig (ColV L)) (hop : (merkleEncV tag L h64).Opens G d r j o)
    (hlen : o.col.1.length = rows) :
    (merkleEncB tag L rows h64 hr).Opens G d r j ⟨⟨o.col.1, hlen⟩, o.salt, o.path⟩ := by
  obtain ⟨hl, hc⟩ := hop
  refine ⟨hl, ?_⟩
  rw [climbV_eq] at hc
  show (merkleEncB tag L rows h64 hr).climb G j
    (G ((merkleEncB tag L rows h64 hr).leafQ (G ((merkleEncB tag L rows h64 hr).colQ ⟨o.col.1, hlen⟩)) o.salt))
    o.path = r
  rw [climbB_eq]
  exact hc

/-- **What the checked extractor returns has canonical entries.** -/
theorem epxAt_canon (rd : List UInt8 → Option Dig) (d rows : ℕ) (r : Dig) (log : List (QB L × Dig)) (j : ℕ)
    (o : MerkleOpening Dig Dig (ColR rows)) (h : epxAt tag L h64 key domain hs hL rd d rows r log j = some o) :
    ∀ a ∈ o.col.1, a.Canon := by
  unfold epxAt at h
  obtain ⟨o', -, hif⟩ := Option.bind_eq_some_iff.mp h
  by_cases hc : o'.col.1.length = rows ∧ ∀ a ∈ o'.col.1, a.Canon
  · rw [dite_eq_left hc] at hif
    obtain rfl := Option.some.inj hif
    exact hc.2
  · rw [dite_eq_right hc] at hif
    cases hif

/-- **EVERY OPENING THE CHECKED EXTRACTOR RETURNS OPENS** against its root under the bounded encoding of `rows`-row
columns, on a log consistent with the oracle (deterministically: the checks of `ebOpenX`, L52's `ebOpenX_opens`). -/
theorem epxAt_opens (rd : List UInt8 → Option Dig) (d rows : ℕ) (hr : 8 * rows ≤ L) (G : QB L → Dig) (r : Dig)
    (log : List (QB L × Dig)) (hlog : ∀ e ∈ log, e.2 = G e.1) (j : ℕ) (o : MerkleOpening Dig Dig (ColR rows))
    (h : epxAt tag L h64 key domain hs hL rd d rows r log j = some o) :
    (merkleEncB tag L rows h64 hr).Opens G d r j o := by
  unfold epxAt at h
  obtain ⟨o', ho', hif⟩ := Option.bind_eq_some_iff.mp h
  by_cases hc : o'.col.1.length = rows ∧ ∀ a ∈ o'.col.1, a.Canon
  · rw [dite_eq_left hc] at hif
    obtain rfl := Option.some.inj hif
    have hop := (merkleEncV tag L h64).ebOpenX_opens G _ (fun e he => hlog e (List.mem_of_mem_take he)) d j r o' ho'
    exact epx_opensB tag L h64 rows hr G d j r o' hop hc.1
  · rw [dite_eq_right hc] at hif
    cases hif

/-- **THE TOP THEOREM'S `hops` FOR `ops := epxOps`**: every opening it returns on the prover's log opens against the
statement's input root under the commitment's encoding, for every adversary and oracle. -/
theorem ex_hops {Hdr : Type} (rd : List UInt8 → Option Dig) (d rows : ℕ) (hr : 8 * rows ≤ L) {N : ℕ} :
    ∀ (A : OC (QB L) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB L → Dig) (j : Fin N)
      (o : MerkleOpening Dig Dig (ColR rows)),
      epxOps tag L h64 key domain hs hL rd d rows (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB tag L rows h64 hr).Opens G d ((A.runLog G).1.1.inRoot) j.val o :=
  fun A G j o h => epxAt_opens tag L h64 key domain hs hL rd d rows hr G _ _ (OC.runLog_answer G A) j.val o h

/-- **THE TOP THEOREM'S `hcan` FOR `ops := epxOps`.** -/
theorem ex_hcan {Hdr : Type} (rd : List UInt8 → Option Dig) (d rows : ℕ) {N : ℕ} :
    ∀ (lg : List (QB L × Dig)) (s : ClsStmt Hdr) (j : Fin N) (o : MerkleOpening Dig Dig (ColR rows)),
      epxOps tag L h64 key domain hs hL rd d rows lg s j = some o → ∀ a ∈ o.col.1, a.Canon :=
  fun lg _ j o h => epxAt_canon tag L h64 key domain hs hL rd d rows _ lg j.val o h

end Ext

/-! ## Outside the event, the sampled columns are the checked extractor's -/

section XOk

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) {α : Type}

/-- **OUTSIDE `EvXC`, EVERY SAMPLED COLUMN IS THE CHECKED EXTRACTOR'S** (L51's `ab_xok_in` for `epxAt`): if `EvXC` did
not happen, the root is one of `rx`, the rows fit `L`, the opening's columns are canonical and the run verifier's Merkle
work checks the sampled columns, then every sampled column that verifies against that root, with `rows` entries, is the
column the checked extractor returns there. -/
theorem epx_xok (rd : List UInt8 → Option Dig) (coreOf : α → ℕ → List Op × Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig) (A : OC (QB L) Dig α) (G : QB L → Dig)
    (hX : ¬ EvXC tag L h64 key domain hs hL rd 256 256 256 16 16 12 26 coreOf Vx rx A G)
    (d rows Q : ℕ) (zo : Block.OpeningZk) (root : Dig) (hroot : root ∈ rx (A.run G)) (hfit : 8 * rows ≤ L)
    (hcan : Block.HidingCanon zo)
    (hq : ∀ k, k < Q → k < zo.columns.length → (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = d →
      ∀ (hf : 8 * (zo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (zo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(zo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (zo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx))) :
    ∀ (k : ℕ), k < Q → k < zo.columns.length →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = d →
      verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
        (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
          ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
        = true →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = rows →
      (epxAt tag L h64 key domain hs hL rd d rows root (A.runLog G).2
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map (fun o => o.col.1)
        = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1 := by
  intro k hkQ hkl hpath hver hlen
  rw [rx_toOZ_getD] at hpath hver hlen ⊢
  have hmem : zo.columns.getD k ⟨0, [], zeroDig, []⟩ ∈ zo.columns := mem_of_getD_lt _ _ hkl _
  set c := zo.columns.getD k ⟨0, [], zeroDig, []⟩ with hcdef
  have hpath' : c.path.length = d := hpath
  have hver' : verifyPath (liftH G) tag root c.j (saltLeaf (liftH G) tag (colDigest (liftH G) tag c.col) c.salt) c.path
      = true := hver
  have hlen' : c.col.length = rows := hlen
  have hf : 8 * c.col.length ≤ L := by rw [hlen']; exact hfit
  have hop := opensV_of_exec tag L h64 G d root c.j c.col hf c.salt c.path hpath' hver'
  have hext : (merkleEncV tag L h64).ebOpenX (cutAt (absMOf L key domain hs hL rd) root (A.runLog G).2) d c.j root
      = some ⟨⟨c.col, hf⟩, c.salt, c.path⟩ := by
    by_contra hne
    exact hX ⟨root, hroot, d, c.j, ⟨⟨c.col, hf⟩, c.salt, c.path⟩, hop, hq k hkQ hkl hpath' hf, Or.inr hne⟩
  have hcc : ∀ a ∈ c.col, a.Canon := hcan.2.2 c hmem
  have he := epxAt_of_ext tag L h64 key domain hs hL rd d rows root (A.runLog G).2 c.j _ hext ⟨hlen', hcc⟩
  show (epxAt tag L h64 key domain hs hL rd d rows root (A.runLog G).2 c.j).map (fun o => o.col.1) = some c.col
  exact (congrArg (Option.map (fun o : MerkleOpening Dig Dig (ColR rows) => o.col.1)) he).trans rfl

end XOk

end ZK60.ProtocolClassify
