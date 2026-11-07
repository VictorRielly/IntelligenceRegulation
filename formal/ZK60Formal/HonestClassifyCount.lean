/-
D63 Lean lane L25 (2026-11-07), part 4: **obligation O10 of `ClassifyOpen`: the refusal sites' freshness `δ` and
their counts `Σ k`**, against `εcTarget = 2^-40`.

**The freshness (`δ`, L18-4).** A site's bound `k·fibC/|Dig| + δ` (L18's `Site.prob_le`) needs its squeeze point not
asked before by the site's OWN computation `G` (the computation that names the point and the bad set). The point and
the bad set of an honest refusal site are functions of the honest run's MAIN transcript (its absorbs and squeezes, in
order) and of the queries outside the transcript that feed it (the column digests, leaves and nodes of the roots it
absorbs). The run's CLONES (the position tags of every segment's frame, `check_opening`'s replay) feed nothing back
into the main transcript (a tag is written into the frame, never absorbed; the replay's challenges are re-squeezed by
the opening itself), so they are NOT part of a site's computation. Here:
* `TProg`: such a computation, as a program: absorbs and squeezes of ONE transcript, and outside queries (`ext`); its
  site is the transcript's NEXT squeeze; `TProg.oc` is the program as an oracle computation over L5's `QB Lq`
  (`liftH`'s domain), `TProg.final` its transcript semantics;
* `TProg.Sep` (every outside query is under another key than the transcript's or is not 47 bytes long: the Merkle,
  leaf and column-digest encodings) and `TProg.NoWrap` (the squeeze counter does not wrap: fewer than `2^64` squeezes);
* **`tprog_point_fresh`**: the site's squeeze point is NEVER among the program's queries, at every oracle: an absorb's
  input has at least 48 bytes, a squeeze's exactly 47 (`absorbMsg_length`, `squeezeMsg_length`), and the transcript's
  squeezes before the site carry strictly smaller counters (`squeezeMsg_inj`); so **`tprog_delta_zero`**: `δ = 0`;
* `tprogSite`: L18's `Site` from such a program, with `δ = 0` PROVED; `tprogSite_fires`: it fires exactly when the
  challenge read at the transcript's squeeze after the program is a bad value;
* **`slot_c_guard_iff`**, **`degenerate_guard_iff`** (`isZero_iff_toK`): the honest slot prover's two guards
  (`HonestClassifyBlock.lean`'s `slotProve`) ARE such events, with the bad sets `{0}` (`k = 1`) and `{0, 1}` (`k = 2`).
So `δ = 0` (L18-4's expectation) is a theorem for every site whose computation is a transcript program; the premise
that the honest run's sites ARE such programs is the honest run's oracle form (not built here, L25-3).

**The counts.** `kPer` (the bad values per site, by kind: the dependent proximity pair `p`, a zero coefficient `1`,
`c = 0` `1`, a degenerate extension `2`, `ν` / batching `1`, LogUp `α` `M`, D66(3)'s dictionary `cap·2^40`), the
site index `SiteIdx` (`Σ kind, Fin (count kind)`), **`siteK_sum`** (the sum is `Σ_kind count·kPer`),
**`shield_k_le`** (at the Shieldstral classify run's CODE counts, L18 §4.1, with generous margins on every count:
`Σ k ≤ 2^85`, in fact `< 2^72`), and **`classify_counts`**: ClassifyOpen's field O10 in its exact form for every site
family whose sites are transcript programs (`δ = 0`) with at most `kPer` bad values each.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.HonestClassifyRun

set_option autoImplicit false

namespace ZK60.HonestClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)

/-! ## The transcript's messages -/

theorem squeezeMsg_length (st : Dig) (ctr : UInt64) : (squeezeMsg st ctr).length = 47 := by
  simp [squeezeMsg, squeezeTag, le64_length]

theorem absorbMsg_length (st : Dig) (l d : List UInt8) : 48 ≤ (absorbMsg st l d).length := by
  simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length]
  omega

/-- **Two squeeze inputs with the same bytes have the same counter** (the last 8 bytes are `le64 counter`). -/
theorem squeezeMsg_inj {st st' : Dig} {c c' : UInt64} (h : squeezeMsg st c = squeezeMsg st' c') : c = c' := by
  have h1 : (squeezeMsg st c).drop 39 = le64 c := by
    simp [squeezeMsg, squeezeTag, List.drop_append, List.Vector.toList_length]
  have h2 : (squeezeMsg st' c').drop 39 = le64 c' := by
    simp [squeezeMsg, squeezeTag, List.drop_append, List.Vector.toList_length]
  have h3 : le64 c = le64 c' := by rw [← h1, ← h2, h]
  rw [← ofLE64_le64 c, h3, ofLE64_le64]

/-! ## Transcript programs -/

/-- **A transcript program**: the computation behind a refusal site, as the oracle sees it: absorbs and squeezes of
ONE transcript (each continuation reads the squeeze's output digest), and queries outside the transcript (`ext`: a
column digest, a leaf, a node), ending at the site (`done`: the transcript's NEXT squeeze is the site's point, with the
site's data). -/
inductive TProg (β : Type) where
  | done : β → TProg β
  | absorb : List UInt8 → List UInt8 → TProg β → TProg β
  | squeeze : (Dig → TProg β) → TProg β
  | ext : HIn → (Dig → TProg β) → TProg β

namespace TProg

variable {β : Type}

/-- **Its transcript semantics** (under a hash function on all inputs): the transcript at the site and the data. -/
def final (H : HIn → Dig) : TProg β → Tr → Tr × β
  | .done b, t => (t, b)
  | .absorb l d k, t => final H k (t.absorb H l d)
  | .squeeze k, t => final H (k (t.squeeze H).1) (t.squeeze H).2
  | .ext q k, t => final H (k (H q)) t

/-- Outside queries are separated from the transcript's squeezes: another key, or not 47 bytes. -/
def Sep (key : Option Dig) : TProg β → Prop
  | .done _ => True
  | .absorb _ _ k => Sep key k
  | .squeeze k => ∀ dg, Sep key (k dg)
  | .ext q k => (q.key ≠ key ∨ q.msg.length ≠ 47) ∧ ∀ dg, Sep key (k dg)

/-- The squeeze counter does not wrap. -/
def NoWrap : TProg β → Tr → Prop
  | .done _, _ => True
  | .absorb _ _ k, t => ∀ dg : Dig, NoWrap k { t with state := dg }
  | .squeeze k, t => t.counter.toNat + 1 < 2 ^ 64 ∧ ∀ dg, NoWrap (k dg) { t with state := dg, counter := t.counter + 1 }
  | .ext _ k, t => ∀ dg, NoWrap (k dg) t

variable (Lq : ℕ)

/-- One hash query on `QB Lq` (an input longer than `Lq` is answered `0` without a query: `liftH`). -/
def askQ {α : Type} (q : HIn) (k : Dig → OC (QB Lq) Dig α) : OC (QB Lq) Dig α :=
  if h : q.msg.length ≤ Lq then .ask (q.key, ⟨q.msg, h⟩) k else k zeroDig

/-- The site's point: the transcript's next squeeze input. -/
def sqPoint (hLq : 47 ≤ Lq) (t : Tr) : QB Lq :=
  (t.key, ⟨squeezeMsg t.state t.counter, by rw [squeezeMsg_length]; exact hLq⟩)

/-- **The program as an oracle computation** on `QB Lq`: it returns the site's point and data. -/
def oc (hLq : 47 ≤ Lq) : TProg β → Tr → OC (QB Lq) Dig (QB Lq × β)
  | .done b, t => .ret (sqPoint Lq hLq t, b)
  | .absorb l d k, t => askQ Lq ⟨t.key, absorbMsg t.state l d⟩ (fun dg => oc hLq k { t with state := dg })
  | .squeeze k, t => askQ Lq ⟨t.key, squeezeMsg t.state t.counter⟩
      (fun dg => oc hLq (k dg) { t with state := dg, counter := t.counter + 1 })
  | .ext q k, t => askQ Lq q (fun dg => oc hLq (k dg) t)

theorem askQ_run {α : Type} (G : QB Lq → Dig) (q : HIn) (k : Dig → OC (QB Lq) Dig α) :
    (askQ Lq q k).run G = (k (liftH G q)).run G := by
  unfold askQ liftH
  split_ifs with h
  · rfl
  · rfl

/-- **The oracle computation runs the transcript semantics** under `liftH`: its result is the site's point at the
final transcript and the data. -/
theorem oc_run (hLq : 47 ≤ Lq) (G : QB Lq → Dig) :
    ∀ (p : TProg β) (t : Tr), (oc Lq hLq p t).run G = (sqPoint Lq hLq (final (liftH G) p t).1, (final (liftH G) p t).2)
  | .done b, t => rfl
  | .absorb l d k, t => by
    show (askQ Lq _ _).run G = _
    rw [askQ_run]
    exact oc_run hLq G k _
  | .squeeze k, t => by
    show (askQ Lq _ _).run G = _
    rw [askQ_run]
    exact oc_run hLq G (k _) _
  | .ext q k, t => by
    show (askQ Lq _ _).run G = _
    rw [askQ_run]
    exact oc_run hLq G (k _) _

/-- The key of the transcript never changes. -/
theorem final_key (H : HIn → Dig) : ∀ (p : TProg β) (t : Tr), (final H p t).1.key = t.key
  | .done _, _ => rfl
  | .absorb _ _ k, _ => (final_key H k _).trans rfl
  | .squeeze k, _ => (final_key H (k _) _).trans rfl
  | .ext _ k, t => final_key H (k _) t

/-- The counter only grows (without wrapping). -/
theorem final_counter_ge (H : HIn → Dig) : ∀ (p : TProg β) (t : Tr), NoWrap p t →
    t.counter.toNat ≤ (final H p t).1.counter.toNat
  | .done _, _, _ => le_rfl
  | .absorb l d k, t, hn => final_counter_ge H k (t.absorb H l d) (hn _)
  | .squeeze k, t, hn => by
    have h1 := final_counter_ge H (k (t.squeeze H).1) (t.squeeze H).2 (hn.2 _)
    have h2 : (t.squeeze H).2.counter.toNat = t.counter.toNat + 1 := by
      show (t.counter + 1).toNat = _
      rw [UInt64.toNat_add, UInt64.toNat_one, Nat.mod_eq_of_lt hn.1]
    show t.counter.toNat ≤ (final H (k (t.squeeze H).1) (t.squeeze H).2).1.counter.toNat
    omega
  | .ext q k, t, hn => final_counter_ge H (k (H q)) t (hn _)

/-- What every query of the program is, relative to the site: under another key, or not 47 bytes, or a squeeze
input whose counter is strictly below the site's. -/
def Below (key : Option Dig) (c : ℕ) (z : QB Lq) : Prop :=
  z.1 ≠ key ∨ z.2.1.length ≠ 47 ∨ ∃ st ctr, z.2.1 = squeezeMsg st ctr ∧ ctr.toNat < c

theorem queries_askQ {α : Type} (G : QB Lq → Dig) (q : HIn) (k : Dig → OC (QB Lq) Dig α) (z : QB Lq)
    (hz : z ∈ OC.queries G (askQ Lq q k)) :
    (z.1 = q.key ∧ z.2.1 = q.msg) ∨ z ∈ OC.queries G (k (liftH G q)) := by
  unfold askQ at hz
  split_ifs at hz with h
  · rw [OC.queries_ask] at hz
    rcases List.mem_cons.mp hz with e | e
    · exact Or.inl ⟨by rw [e], by rw [e]⟩
    · right
      have : liftH G q = G (q.key, ⟨q.msg, h⟩) := by simp [liftH, h]
      rw [this]
      exact e
  · right
    have : liftH G q = zeroDig := by simp [liftH, h]
    rw [this]
    exact hz

/-- **Every query of the program is below its site.** -/
theorem queries_below (hLq : 47 ≤ Lq) (G : QB Lq → Dig) :
    ∀ (p : TProg β) (t : Tr), Sep t.key p → NoWrap p t → ∀ z ∈ OC.queries G (oc Lq hLq p t),
      Below Lq t.key (final (liftH G) p t).1.counter.toNat z
  | .done _, _, _, _, z, hz => by simp [oc, OC.queries, OC.runLog] at hz
  | .absorb l d k, t, hs, hn, z, hz => by
    rcases queries_askQ Lq G _ _ z hz with ⟨_, e⟩ | e
    · right; left
      rw [e]
      show (absorbMsg t.state l d).length ≠ 47
      have := absorbMsg_length t.state l d
      omega
    · exact queries_below hLq G k { t with state := liftH G ⟨t.key, absorbMsg t.state l d⟩ } hs (hn _) z e
  | .squeeze k, t, hs, hn, z, hz => by
    rcases queries_askQ Lq G _ _ z hz with ⟨_, e⟩ | e
    · right; right
      refine ⟨t.state, t.counter, e, ?_⟩
      have h1 : (t.counter + 1).toNat ≤ (final (liftH G) (k (liftH G ⟨t.key, squeezeMsg t.state t.counter⟩))
          { t with state := liftH G ⟨t.key, squeezeMsg t.state t.counter⟩, counter := t.counter + 1 }).1.counter.toNat :=
        final_counter_ge (liftH G) (k (liftH G ⟨t.key, squeezeMsg t.state t.counter⟩))
          { t with state := liftH G ⟨t.key, squeezeMsg t.state t.counter⟩, counter := t.counter + 1 } (hn.2 _)
      have h2 : (t.counter + 1).toNat = t.counter.toNat + 1 := by
        rw [UInt64.toNat_add, UInt64.toNat_one, Nat.mod_eq_of_lt hn.1]
      show t.counter.toNat < (final (liftH G) (k (liftH G ⟨t.key, squeezeMsg t.state t.counter⟩))
        { t with state := liftH G ⟨t.key, squeezeMsg t.state t.counter⟩, counter := t.counter + 1 }).1.counter.toNat
      omega
    · exact queries_below hLq G (k (liftH G ⟨t.key, squeezeMsg t.state t.counter⟩))
        { t with state := liftH G ⟨t.key, squeezeMsg t.state t.counter⟩, counter := t.counter + 1 } (hs _) (hn.2 _) z e
  | .ext q k, t, hs, hn, z, hz => by
    rcases queries_askQ Lq G _ _ z hz with ⟨e1, e2⟩ | e
    · rcases hs.1 with h | h
      · left
        rw [e1]
        exact h
      · right; left
        rw [e2]
        exact h
    · exact queries_below hLq G (k (liftH G q)) t (hs.2 _) (hn _) z e

/-- **The site's point is never asked by its own computation** (at every oracle): `δ = 0` pointwise. -/
theorem tprog_point_fresh (hLq : 47 ≤ Lq) (G : QB Lq → Dig) (p : TProg β) (t : Tr) (hs : Sep t.key p)
    (hn : NoWrap p t) : ((oc Lq hLq p t).run G).1 ∉ OC.queries G (oc Lq hLq p t) := by
  intro hmem
  rw [oc_run] at hmem
  have hb := queries_below Lq hLq G p t hs hn _ hmem
  rcases hb with h | h | ⟨st, ctr, e, hlt⟩
  · exact h (final_key (liftH G) p t)
  · exact h (squeezeMsg_length _ _)
  · have := squeezeMsg_inj e.symm
    rw [this] at hlt
    exact lt_irrefl _ hlt

end TProg

/-! ## Sites from transcript programs: `δ = 0` -/

section Sites

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {Coins : Type} [Fintype Coins] [Nonempty Coins]

/-- **`δ = 0` for a transcript-program site**: the probability that its point was asked by its own computation is
zero (the event is empty). -/
theorem tprog_delta_zero {β : Type} (p : Coins → TProg β) (t : Coins → Tr) (hs : ∀ c, TProg.Sep (t c).key (p c))
    (hn : ∀ c, TProg.NoWrap (p c) (t c)) :
    prHC (fun H c => (((p c).oc Lq hLq (t c)).run H).1 ∈ OC.queries H ((p c).oc Lq hLq (t c))) ≤ 0 := by
  unfold prHC
  calc _ ≤ (PMF.uniformOfFintype ((QB Lq → Dig) × Coins)).toOuterMeasure ∅ :=
        MeasureTheory.measure_mono (fun x hx =>
          (TProg.tprog_point_fresh Lq hLq x.1 (p x.2) (t x.2) (hs x.2) (hn x.2) hx).elim)
    _ = 0 := MeasureTheory.measure_empty

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **A refusal site from a transcript program** (L18's `Site`), with `δ = 0` PROVED. -/
noncomputable def tprogSite {β : Type} (p : Coins → TProg β) (t : Coins → Tr) (bad : β → Finset K) (k : ℕ)
    (hk : ∀ b, (bad b).card ≤ k) (hs : ∀ c, TProg.Sep (t c).key (p c)) (hn : ∀ c, TProg.NoWrap (p c) (t c)) :
    ProtocolClassify.Site (QB Lq) Coins K where
  β := β
  G c := (p c).oc Lq hLq (t c)
  bad := bad
  k := k
  hk := hk
  δ := 0
  hfresh := tprog_delta_zero Lq hLq p t hs hn

omit [Field K] [DecidableEq K] [Algebra GF K] in
theorem tprogSite_delta {β : Type} (p : Coins → TProg β) (t : Coins → Tr) (bad : β → Finset K) (k : ℕ)
    (hk : ∀ b, (bad b).card ≤ k) (hs : ∀ c, TProg.Sep (t c).key (p c)) (hn : ∀ c, TProg.NoWrap (p c) (t c)) :
    (tprogSite Lq hLq p t bad k hk hs hn).δ = 0 := rfl

omit [DecidableEq K] in
/-- **A transcript-program site fires exactly when its challenge, read at the transcript's next squeeze after the
program (under `liftH`), is a bad value**: the link from a site to the honest prover's guard (`c.isZero`, a degenerate
`e`, LogUp's `α`, `check_opening`'s draws are `challenge_fp2` of that squeeze's output). -/
theorem tprogSite_fires {β : Type} (U : K) (p : Coins → TProg β) (t : Coins → Tr) (bad : β → Finset K) (k : ℕ)
    (hk : ∀ b, (bad b).card ≤ k) (hs : ∀ c, TProg.Sep (t c).key (p c)) (hn : ∀ c, TProg.NoWrap (p c) (t c))
    (G : QB Lq → Dig) (c : Coins) :
    (tprogSite Lq hLq p t bad k hk hs hn).fires U G c ↔
      (challengeFp2Of (liftH G ⟨(TProg.final (liftH G) (p c) (t c)).1.key,
        squeezeMsg (TProg.final (liftH G) (p c) (t c)).1.state (TProg.final (liftH G) (p c) (t c)).1.counter⟩)).toK U
        ∈ bad (TProg.final (liftH G) (p c) (t c)).2 := by
  show (challengeFp2Of (G (((p c).oc Lq hLq (t c)).run G).1)).toK U ∈ bad (((p c).oc Lq hLq (t c)).run G).2 ↔ _
  rw [TProg.oc_run]
  have hl : (squeezeMsg (TProg.final (liftH G) (p c) (t c)).1.state
      (TProg.final (liftH G) (p c) (t c)).1.counter).length ≤ Lq := by rw [squeezeMsg_length]; exact hLq
  simp only [TProg.sqPoint, liftH, hl, ↓reduceDIte]

end Sites

/-! ## The honest prover's guards are site events -/

section Guards

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

omit [DecidableEq K] in
/-- A canonical word is the code's zero (`is_zero`) exactly when its value is `0`. -/
theorem isZero_iff_toK (a : Fp2) (ha : a.Canon) : a.isZero = true ↔ a.toK U = 0 := by
  constructor
  · intro h
    have e : a = Fp2.zero := by
      cases a with
      | mk c0 c1 =>
        simp only [Fp2.isZero, Bool.and_eq_true, beq_iff_eq] at h
        obtain ⟨v0⟩ := c0
        obtain ⟨v1⟩ := c1
        have h0 : v0 = 0 := h.1
        have h1 : v1 = 0 := h.2
        subst h0 h1
        rfl
    rw [e, Fp2.toK_zero]
  · intro h
    have e := Fp2.toK_injective U hU ha Fp2.canon_zero (h.trans (Fp2.toK_zero U).symm)
    subst e
    rfl

omit [DecidableEq K] in
/-- **The CFS guard is a site event with one bad value** (`k = 1`, kind `2` of `kPer`): `c = 0` exactly when the
challenge read at the transcript's squeeze after `pb-slot` has the value `0`. -/
theorem slot_c_guard_iff (H : HIn → Dig) (P : Block.BlockParams) (s : ℕ) (t : Tr) :
    (slotC H P s t).isZero = true ↔
      (challengeFp2Of (H ⟨(slotT2 H P s t).key, squeezeMsg (slotT2 H P s t).state (slotT2 H P s t).counter⟩)).toK U
        ∈ ({0} : Finset K) := by
  rw [Finset.mem_singleton]
  exact isZero_iff_toK U hU _ (canon_challengeFp2Of _)

/-- **The degenerate-extension guard is a site event with two bad values** (`k = 2`, kind `3` of `kPer`): a
canonical challenge is `0` or `1` exactly when its value is. -/
theorem degenerate_guard_iff (x : Fp2) (hx : x.Canon) :
    (x.isZero || decide (x = Fp2.one)) = true ↔ x.toK U ∈ ({0, 1} : Finset K) := by
  have hone : x = Fp2.one ↔ x.toK U = 1 := by
    rw [Fp2.eq_iff_toK U hU hx (show Fp2.one.Canon by decide), Fp2.toK_one]
  rw [Bool.or_eq_true, decide_eq_true_iff, isZero_iff_toK U hU x hx, hone, Finset.mem_insert, Finset.mem_singleton]

/-- **A slot of the honest prover refuses only at a listed site, in the sites' form**: `define`'s own refusal, the CFS
challenge (the squeeze after `pb-slot`) in `{0}`, an extension challenge (a squeeze of the sumcheck's last rounds) in
`{0, 1}`, or a deterministic schedule failure. -/
theorem slotProve_refuses_sites (H : HIn → Dig) (P : Block.BlockParams) (D : SlotData P) (s : ℕ) (hist : Block.Hist)
    (acc : Block.Acc) (t : Tr) (h : slotProve H P D s hist acc t = .error ()) :
    (∃ e, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .error e)
      ∨ ∃ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df
        ∧ ((challengeFp2Of (H ⟨(slotT2 H P s t).key, squeezeMsg (slotT2 H P s t).state (slotT2 H P s t).counter⟩)).toK U
              ∈ ({0} : Finset K)
          ∨ (∃ x ∈ (slotRho H P D s hist acc t df).drop (Block.slotShape P s).1, x.toK U ∈ ({0, 1} : Finset K))
          ∨ (∃ e, Block.slotDefChecks P s acc df = .error e)
          ∨ (∃ e, Block.hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted = .error e)
          ∨ ∃ e, Block.tabVals (Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (Block.slotShape P s).1))
              ((slotRho H P D s hist acc t df).take (Block.slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0
              = .error e) := by
  rcases slotProve_refuses H P D s hist acc t h with hd | ⟨df, hdf, hc | hes | hrest⟩
  · exact Or.inl hd
  · exact Or.inr ⟨df, hdf, Or.inl ((slot_c_guard_iff U hU H P s t).mp hc)⟩
  · refine Or.inr ⟨df, hdf, Or.inr (Or.inl ?_)⟩
    obtain ⟨x, hx, hx'⟩ := List.any_eq_true.mp hes
    have hcan : x.Canon := scChal_canon H _ _ x (List.mem_of_mem_drop hx)
    exact ⟨x, hx, (degenerate_guard_iff U hU x hcan).mp hx'⟩
  · exact Or.inr ⟨df, hdf, Or.inr (Or.inr hrest)⟩

end Guards

/-! ## The counts -/

section Counts

/-- **The bad challenge values per site, by kind** (L18 §4.1, CODE: protocol.rs:312-322, argument.rs:1187, 1478,
1856, `logupRefuses_iff`, D66(3)): `0` the dependent proximity pair (`p` values, L18-3), `1` a zero group member or
first coefficient, `2` the CFS `c = 0`, `3` a degenerate extension challenge (`e ∈ {0, 1}`), `4` a host's `ν` or a
batching coefficient zero, `5` LogUp's `α` a folded table tuple (`M`), `6` D66(3)'s dictionary (`cap·2^40`). -/
def kPer (p M cap : ℕ) : Fin 7 → ℕ
  | 0 => p
  | 1 => 1
  | 2 => 1
  | 3 => 2
  | 4 => 1
  | 5 => M
  | 6 => cap * 2 ^ 40

/-- The run's sites: `count kind` sites of each kind. -/
abbrev SiteIdx (count : Fin 7 → ℕ) : Type := (j : Fin 7) × Fin (count j)

/-- **The total number of bad values is `Σ_kind count·kPer`.** -/
theorem siteK_sum (count : Fin 7 → ℕ) (f : Fin 7 → ℕ) :
    ∑ i : SiteIdx count, f i.1 = ∑ j : Fin 7, count j * f j := by
  rw [Fintype.sum_sigma]
  refine Finset.sum_congr rfl (fun j _ => ?_)
  simp

/-- **At the Shieldstral classify run** (`L = 26` R13 blocks and the two stages; CODE counts, L18 §4.1: `3L + 5 = 83`
openings, `≤ 2^16` zero-coefficient sites, `610` slots, `≤ 2^12` extension challenges, `≤ 2^10` host and batching
coefficients, a few LogUp domains with `M ≤ 2^17`, `≤ 26` dictionaries at `cap ≤ 2^20`), with a margin on every count:
for at most `2^7` openings, `2^20` zero-coefficient sites, `2^12` slots, `2^12` extension challenges, `2^12` host and
batching sites, `2^8` LogUp domains of `M ≤ 2^17` and `2^5` dictionaries of `cap ≤ 2^20`, the total number of bad
values is at most `2^85` (it is below `2^72`). -/
theorem shield_k_le (count : Fin 7 → ℕ) (M cap : ℕ) (h0 : count 0 ≤ 2 ^ 7) (h1 : count 1 ≤ 2 ^ 20)
    (h2 : count 2 ≤ 2 ^ 12) (h3 : count 3 ≤ 2 ^ 12) (h4 : count 4 ≤ 2 ^ 12) (h5 : count 5 ≤ 2 ^ 8)
    (h6 : count 6 ≤ 2 ^ 5) (hM : M ≤ 2 ^ 17) (hcap : cap ≤ 2 ^ 20) :
    ∑ i : SiteIdx count, kPer gP M cap i.1 ≤ 2 ^ 85 := by
  have hs : ∑ j : Fin 7, count j * kPer gP M cap j = count 0 * kPer gP M cap 0 + count 1 * kPer gP M cap 1
      + count 2 * kPer gP M cap 2 + count 3 * kPer gP M cap 3 + count 4 * kPer gP M cap 4
      + count 5 * kPer gP M cap 5 + count 6 * kPer gP M cap 6 := Fin.sum_univ_seven _
  rw [siteK_sum count (kPer gP M cap), hs]
  have hp : gP ≤ 2 ^ 64 := by norm_num [gP]
  have e0 : count 0 * kPer gP M cap 0 ≤ 2 ^ 7 * 2 ^ 64 := Nat.mul_le_mul h0 hp
  have e1 : count 1 * kPer gP M cap 1 ≤ 2 ^ 20 * 1 := Nat.mul_le_mul h1 le_rfl
  have e2 : count 2 * kPer gP M cap 2 ≤ 2 ^ 12 * 1 := Nat.mul_le_mul h2 le_rfl
  have e3 : count 3 * kPer gP M cap 3 ≤ 2 ^ 12 * 2 := Nat.mul_le_mul h3 le_rfl
  have e4 : count 4 * kPer gP M cap 4 ≤ 2 ^ 12 * 1 := Nat.mul_le_mul h4 le_rfl
  have e5 : count 5 * kPer gP M cap 5 ≤ 2 ^ 8 * 2 ^ 17 := Nat.mul_le_mul h5 hM
  have e6 : count 6 * kPer gP M cap 6 ≤ 2 ^ 5 * (2 ^ 20 * 2 ^ 40) :=
    Nat.mul_le_mul h6 (Nat.mul_le_mul_right _ hcap)
  generalize count 0 * kPer gP M cap 0 = a0 at e0 ⊢
  generalize count 1 * kPer gP M cap 1 = a1 at e1 ⊢
  generalize count 2 * kPer gP M cap 2 = a2 at e2 ⊢
  generalize count 3 * kPer gP M cap 3 = a3 at e3 ⊢
  generalize count 4 * kPer gP M cap 4 = a4 at e4 ⊢
  generalize count 5 * kPer gP M cap 5 = a5 at e5 ⊢
  generalize count 6 * kPer gP M cap 6 = a6 at e6 ⊢
  norm_num at e0 e1 e2 e3 e4 e5 e6 ⊢
  omega

/-- **ClassifyOpen's field O10 in its exact form**, for a site family whose sites have freshness `δ = 0` (transcript
programs, `tprogSite`) and at most `kOf i` bad values each, with `Σ kOf ≤ 2^85`: `δOf = 0`. -/
theorem classify_counts {X Q Coins K : Type} [Fintype Q] [DecidableEq Q] [Fintype Coins] [Nonempty Coins]
    [Field K] [DecidableEq K] [Algebra GF K] {ι : Type} [Fintype ι] (site : X → ι → ProtocolClassify.Site Q Coins K)
    (kOf : ι → ℕ) (hk : ∀ x i, (site x i).k ≤ kOf i) (hδ : ∀ x i, (site x i).δ = 0) (hsum : ∑ i, kOf i ≤ 2 ^ 85) :
    (∀ x i, (site x i).k ≤ kOf i) ∧ (∀ x i, (site x i).δ ≤ (fun _ : ι => (0 : ℝ≥0∞)) i) ∧ ∑ i, kOf i ≤ 2 ^ 85
      ∧ ∑ i, (fun _ : ι => (0 : ℝ≥0∞)) i ≤ (2⁻¹ : ℝ≥0∞) ^ 41 :=
  ⟨hk, fun x i => (hδ x i).le, hsum, by simp⟩

/-- **The completeness total at the Shieldstral counts**: `Σ (k·fibC/|Dig| + δ) ≤ εcTarget` (L18's
`refusal_total_le_target` at `δ = 0` and the counts of `shield_k_le`). -/
theorem shield_refusal_total_le (count : Fin 7 → ℕ) (M cap : ℕ) (h0 : count 0 ≤ 2 ^ 7) (h1 : count 1 ≤ 2 ^ 20)
    (h2 : count 2 ≤ 2 ^ 12) (h3 : count 3 ≤ 2 ^ 12) (h4 : count 4 ≤ 2 ^ 12) (h5 : count 5 ≤ 2 ^ 8)
    (h6 : count 6 ≤ 2 ^ 5) (hM : M ≤ 2 ^ 17) (hcap : cap ≤ 2 ^ 20) :
    ∑ i : SiteIdx count, (((kPer gP M cap i.1 * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + 0) ≤ εcTarget :=
  refusal_total_le_target (fun i : SiteIdx count => kPer gP M cap i.1) (fun _ => 0)
    (shield_k_le count M cap h0 h1 h2 h3 h4 h5 h6 hM hcap) (by simp)

end Counts

end ZK60.HonestClassify
