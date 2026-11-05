/-
D63, step L3 (soundness): the straight-line extractor for a Merkle commitment, from the committer's hash-query log.

The extractor (`extractCol`) reads only the log `L` of the COMMIT phase (the queries made before the root is output)
and the root. For a position `j` it descends from the root: it looks up the first logged question whose answer is the
current digest, decodes it as a node, takes the child the bit of `j` names (the same bit the climb uses), and repeats
`h` times; at the leaf level it decodes the logged question as a salted leaf `(x, σ)`, and the logged question whose
answer is `x` as a column. Nothing is guessed or rewound: it is straight-line, and it is a function of the commit
phase alone, so the column vector it returns is fixed before any later challenge (that is what `opening_sound` needs).

What is proved:
* `extract_of_opens` (deterministic): if an opening at `j` verifies against the root, then the extractor returns its
  column at `j`, OR one of the verifier's queries `v` collides with a logged question (`y ≠ v`, `H y = H v`), OR some
  verifier's query that was never logged has an answer in the set `targets L root` (the root and the digests that
  appear inside logged questions; at most `3|L| + 1` of them);
* `extract_sound` (task 3): for any commit phase making at most `q₁` queries and any later phase making at most `q₂`,
  that outputs `n` openings at positions of its choice, the probability that some opening verifies but is not the
  extracted column at its position is at most
    `collBound T D + extGuess T q₁ D`, `T = q₁ + q₂ + n(h + 2)`,
  i.e. `T(T − 1)/2 / |D| + T(3q₁ + 1)/|D|`. The first term is the collision bound for every query of the run (both
  phases and the verifier's). The second is the "unqueried path guess": a query asked for the first time AFTER the
  commit phase whose answer is one of the at most `3q₁ + 1` digests the commit phase named (an adversary that commits
  to a tree with a hole and fills it later must hit one).

The domain separation assumed is again none between the three input kinds: the extractor knows the level it is at,
so it decodes a node query as a node and a leaf query as a leaf, and a logged question that is not the verifier's own
query at that level is a collision. The path-length check (`Opens`) is what fixes the level.
-/
import ZK60Formal.SoundMerkle

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Reading a log -/

section Find

variable {Q D : Type} [DecidableEq D]

/-- The first logged question whose answer is `t`. -/
def findPre (L : List (Q × D)) (t : D) : Option Q := (L.find? (fun e => decide (e.2 = t))).map Prod.fst

/-- A found question is logged with that answer. -/
theorem findPre_some {L : List (Q × D)} {t : D} {y : Q} (h : findPre L t = some y) :
    ∃ e ∈ L, e.1 = y ∧ e.2 = t := by
  unfold findPre at h
  obtain ⟨e, he, rfl⟩ := Option.map_eq_some_iff.mp h
  exact ⟨e, List.mem_of_find?_eq_some he, rfl, by simpa using List.find?_some he⟩

/-- If nothing is found, no logged answer is `t`. -/
theorem findPre_none {L : List (Q × D)} {t : D} (h : findPre L t = none) : ∀ e ∈ L, e.2 ≠ t := by
  unfold findPre at h
  rw [Option.map_eq_none_iff, List.find?_eq_none] at h
  intro e he
  simpa using h e he

/-- **The extraction's bad event** for a list of verifier's queries `vs` against a log `L` and a target set `Tg`: some
`v ∈ vs` collides with a logged question, or was never logged and has its answer in `Tg`. -/
def ExtBad (H : Q → D) (L : List (Q × D)) (Tg : Finset D) (vs : List Q) : Prop :=
  ∃ v ∈ vs, (∃ y ∈ L.map Prod.fst, y ≠ v ∧ H y = H v) ∨ (v ∉ L.map Prod.fst ∧ H v ∈ Tg)

omit [DecidableEq D] in
/-- The bad event grows with the list of queries. -/
theorem ExtBad.mono {H : Q → D} {L : List (Q × D)} {Tg : Finset D} {vs vs' : List Q} (h : ∀ v ∈ vs, v ∈ vs')
    (hb : ExtBad H L Tg vs) : ExtBad H L Tg vs' := by
  obtain ⟨v, hv, hb⟩ := hb
  exact ⟨v, h v hv, hb⟩

/-- **One lookup.** If the verifier asks `v` and its answer is a target, the extractor's lookup of that answer finds
`v` itself, unless `v` collides with a logged question or was never logged. -/
theorem find_or_bad (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (Tg : Finset D) (v : Q)
    (ht : H v ∈ Tg) : findPre L (H v) = some v ∨ ExtBad H L Tg [v] := by
  rcases hf : findPre L (H v) with _ | y
  · right
    refine ⟨v, List.mem_singleton_self _, Or.inr ⟨?_, ht⟩⟩
    intro hv
    obtain ⟨e, he, rfl⟩ := List.mem_map.mp hv
    exact findPre_none hf e he (hL e he)
  · by_cases hy : y = v
    · left
      rw [hy]
    · right
      obtain ⟨e, he, rfl, he2⟩ := findPre_some hf
      exact ⟨v, List.mem_singleton_self _,
        Or.inl ⟨e.1, List.mem_map_of_mem he, hy, by rw [← hL e he, he2]⟩⟩

end Find

/-- The extraction's guess term `T(3q₁ + 1)/|D|`: `T` first-time queries, each landing in a set of at most `3q₁ + 1`
targets. -/
noncomputable def extGuess (T q₁ : ℕ) (D : Type) [Fintype D] : ℝ≥0∞ :=
  ((T * (3 * q₁ + 1) : ℕ) : ℝ≥0∞) / Fintype.card D

namespace MerkleEnc

variable {Q D S Col : Type} (M : MerkleEnc Q D S Col)

/-! ## The climb, top down -/

/-- The climb along `p ++ [s]` ends with one more node query, at the bit `|p|` of the position. -/
theorem climb_append (H : Q → D) (p : List D) (s : D) :
    ∀ (j : ℕ) (cur : D), M.climb H j cur (p ++ [s]) = H (M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s) := by
  induction p with
  | nil => intro j cur; simp [climb]
  | cons s' p ih =>
    intro j cur
    simp only [List.cons_append, climb, List.length_cons]
    rw [ih, Nat.div_div_eq_div_mul, ← pow_succ']

/-- The node queries of the climb along `p ++ [s]`. -/
theorem climbQs_append (H : Q → D) (p : List D) (s : D) :
    ∀ (j : ℕ) (cur : D), M.climbQs H j cur (p ++ [s])
      = M.climbQs H j cur p ++ [M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s] := by
  induction p with
  | nil => intro j cur; simp [climb, climbQs]
  | cons s' p ih =>
    intro j cur
    simp only [List.cons_append, climbQs, climb, List.length_cons]
    rw [ih, Nat.div_div_eq_div_mul, ← pow_succ']

variable [DecidableEq D]

/-- **Descend** from a digest `t` at height `h` to the leaf-level digest at position `j`: look up the first logged
question whose answer is `t`, decode it as a node `(left, right)`, and take the child that bit `h − 1` of `j` names
(0: left, as in the climb); `none` if a lookup or a decoding fails. -/
def descend (L : List (Q × D)) : ℕ → ℕ → D → Option D
  | 0, _, t => some t
  | h + 1, j, t =>
    match (findPre L t).bind M.nodeDec with
    | some lr => descend L h j (if (j / 2 ^ h) % 2 = 0 then lr.1 else lr.2)
    | none => none

/-- **The extracted column** at position `j` of a tree of height `h` with this root: descend to the salted leaf,
decode its logged preimage as `(x, salt)`, and decode the logged preimage of `x` as a column. -/
def extractCol (L : List (Q × D)) (h j : ℕ) (root : D) : Option Col :=
  (M.descend L h j root).bind fun ℓ =>
    ((findPre L ℓ).bind M.leafDec).bind fun xs => (findPre L xs.1).bind M.colDec

/-- The children a logged question names as a node. -/
def nodeKids (y : Q) : Finset D :=
  match M.nodeDec y with
  | some lr => {lr.1, lr.2}
  | none => ∅

/-- The digest a logged question names as a salted leaf's content. -/
def leafKid (y : Q) : Finset D :=
  match M.leafDec y with
  | some xs => {xs.1}
  | none => ∅

/-- **The targets** of a log and a root: the root and every digest that a logged question names as a node's child or
as a leaf's content. These are the only digests the extractor ever looks up. -/
def targets [DecidableEq Q] (L : List (Q × D)) (root : D) : Finset D :=
  insert root ((L.map Prod.fst).toFinset.biUnion (fun y => M.nodeKids y ∪ M.leafKid y))

/-- At most three digests per logged question, and the root. -/
theorem targets_card [DecidableEq Q] (L : List (Q × D)) (root : D) :
    (M.targets L root).card ≤ 3 * L.length + 1 := by
  unfold targets
  refine (card_insert_le _ _).trans (Nat.add_le_add_right ?_ 1)
  refine card_biUnion_le.trans ?_
  have hkid : ∀ y, (M.nodeKids y ∪ M.leafKid y).card ≤ 3 := by
    intro y
    refine (card_union_le _ _).trans ?_
    have h1 : (M.nodeKids y).card ≤ 2 := by
      unfold nodeKids
      split
      · exact card_le_two
      · simp
    have h2 : (M.leafKid y).card ≤ 1 := by
      unfold leafKid
      split
      · simp
      · simp
    omega
  calc ∑ y ∈ (L.map Prod.fst).toFinset, (M.nodeKids y ∪ M.leafKid y).card
      ≤ ∑ _y ∈ (L.map Prod.fst).toFinset, 3 := sum_le_sum (fun y _ => hkid y)
    _ = 3 * (L.map Prod.fst).toFinset.card := by rw [sum_const, smul_eq_mul, mul_comm]
    _ ≤ 3 * L.length := by
        refine Nat.mul_le_mul_left _ ((List.toFinset_card_le _).trans ?_)
        simp

theorem root_mem_targets [DecidableEq Q] (L : List (Q × D)) (root : D) : root ∈ M.targets L root :=
  mem_insert_self _ _

theorem nodeKid_mem_targets [DecidableEq Q] {L : List (Q × D)} {root : D} {y : Q} (hy : y ∈ L.map Prod.fst)
    {lr : D × D} (hd : M.nodeDec y = some lr) : lr.1 ∈ M.targets L root ∧ lr.2 ∈ M.targets L root := by
  have hk : lr.1 ∈ M.nodeKids y ∧ lr.2 ∈ M.nodeKids y := by
    unfold nodeKids
    rw [hd]
    simp
  constructor
  · exact mem_insert_of_mem (mem_biUnion.mpr ⟨y, List.mem_toFinset.mpr hy, mem_union_left _ hk.1⟩)
  · exact mem_insert_of_mem (mem_biUnion.mpr ⟨y, List.mem_toFinset.mpr hy, mem_union_left _ hk.2⟩)

theorem leafKid_mem_targets [DecidableEq Q] {L : List (Q × D)} {root : D} {y : Q} (hy : y ∈ L.map Prod.fst)
    {xs : D × S} (hd : M.leafDec y = some xs) : xs.1 ∈ M.targets L root := by
  have hk : xs.1 ∈ M.leafKid y := by
    unfold leafKid
    rw [hd]
    simp
  exact mem_insert_of_mem (mem_biUnion.mpr ⟨y, List.mem_toFinset.mpr hy, mem_union_right _ hk⟩)

/-- **The descent follows the climb.** If the climb along `p` from `cur` reaches a target `t`, and every node a logged
question names has target children, then descending from `t` by `|p|` levels at position `j` returns `cur` (a target
too), unless the extraction's bad event holds for the climb's queries. -/
theorem descend_of_climb (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (Tg : Finset D)
    (hTg : ∀ y ∈ L.map Prod.fst, ∀ lr, M.nodeDec y = some lr → lr.1 ∈ Tg ∧ lr.2 ∈ Tg) (j : ℕ) (p : List D) :
    ∀ (cur t : D), t ∈ Tg → M.climb H j cur p = t →
      (M.descend L p.length j t = some cur ∧ cur ∈ Tg) ∨ ExtBad H L Tg (M.climbQs H j cur p) := by
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
      have hdesc : M.descend L (p ++ [s]).length j (H (M.stepQ (j / 2 ^ p.length) (M.climb H j cur p) s))
          = M.descend L p.length j (M.climb H j cur p) := by
        rw [List.length_append, List.length_singleton, descend, hf, Option.bind_some, M.nodeDec_stepQ]
        dsimp only
        split_ifs <;> rfl
      rcases ih cur _ hkid rfl with ⟨hd, hcur⟩ | hb'
      · left
        exact ⟨hdesc.trans hd, hcur⟩
      · right
        refine hb'.mono (fun w hw => ?_)
        rw [M.climbQs_append]
        exact List.mem_append_left _ hw
    · right
      refine hb.mono (fun w hw => ?_)
      rw [List.mem_singleton] at hw
      rw [hw, M.climbQs_append]
      simp

/-- **Extraction is correct unless bad (deterministic).** If an opening at position `j` verifies against `root` (with
a path of the tree's depth `h`), the extractor reading the log `L` returns the opening's column at `j`, unless one of
the verifier's queries collides with a logged question or a never-logged verifier's query has an answer among the
log's targets. -/
theorem extract_of_opens [DecidableEq Q] (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (root : D)
    {h j : ℕ} {o : MerkleOpening D S Col} (ho : M.Opens H h root j o) :
    M.extractCol L h j root = some o.col ∨ ExtBad H L (M.targets L root) (M.openQs H j o) := by
  have hsub : ∀ vs : List Q, (∀ v ∈ vs, v ∈ M.openQs H j o) →
      ExtBad H L (M.targets L root) vs → ExtBad H L (M.targets L root) (M.openQs H j o) :=
    fun vs h hb => hb.mono h
  rcases M.descend_of_climb H L hL (M.targets L root) (fun y hy lr hd => M.nodeKid_mem_targets hy hd) j o.path
      (M.leafDigest H o.col o.salt) root (M.root_mem_targets L root) ho.2 with ⟨hd, hℓ⟩ | hb
  · rw [ho.1] at hd
    rcases find_or_bad H L hL (M.targets L root) (M.leafQ (H (M.colQ o.col)) o.salt) hℓ with hf | hb
    · obtain ⟨e, he, he1, -⟩ := findPre_some hf
      have hmem : M.leafQ (H (M.colQ o.col)) o.salt ∈ L.map Prod.fst := he1 ▸ List.mem_map_of_mem he
      have hx := M.leafKid_mem_targets (root := root) hmem (M.leafDec_leafQ (H (M.colQ o.col)) o.salt)
      rcases find_or_bad H L hL (M.targets L root) (M.colQ o.col) hx with hf' | hb'
      · left
        unfold extractCol
        rw [hd, Option.bind_some]
        show ((findPre L (H (M.leafQ (H (M.colQ o.col)) o.salt))).bind M.leafDec).bind
          (fun xs => (findPre L xs.1).bind M.colDec) = some o.col
        rw [hf, Option.bind_some, M.leafDec_leafQ, Option.bind_some]
        dsimp only
        rw [hf', Option.bind_some, M.colDec_colQ]
      · right
        exact hsub _ (fun v hv => by rw [List.mem_singleton] at hv; simp [openQs, hv]) hb'
    · right
      exact hsub _ (fun v hv => by rw [List.mem_singleton] at hv; simp [openQs, hv]) hb
  · right
    exact hsub _ (fun v hv => by simp [openQs, hv]) hb

/-! ## The probability -/

/-- The verifier's hashing for a list of openings, each at its position. -/
def checkAll (h : ℕ) : List (ℕ × MerkleOpening D S Col) → OC Q D Unit
  | [] => .ret ()
  | jo :: rest => (M.checkOC h jo.1 jo.2).bind (fun _ => checkAll h rest)

omit [DecidableEq D] in
/-- Checking `n` openings costs at most `n(h + 2)` queries. -/
theorem checkAll_bounded (h : ℕ) (l : List (ℕ × MerkleOpening D S Col)) :
    (M.checkAll h l).Bounded (l.length * (h + 2)) := by
  induction l with
  | nil => exact trivial
  | cons jo rest ih =>
    have hb := (M.checkOC_bounded h jo.1 jo.2).bind (fun _ => ih)
    refine hb.mono (le_of_eq ?_)
    simp only [List.length_cons]
    ring

omit [DecidableEq D] in
/-- Checking a list of openings asks the verifier's queries of each opening whose path has the tree's depth. -/
theorem checkAll_queries (H : Q → D) (h : ℕ) (l : List (ℕ × MerkleOpening D S Col)) :
    ∀ jo ∈ l, jo.2.path.length = h → ∀ v ∈ M.openQs H jo.1 jo.2, v ∈ OC.queries H (M.checkAll h l) := by
  induction l with
  | nil => intro jo hjo; simp at hjo
  | cons jo' rest ih =>
    intro jo hjo hl v hv
    rw [checkAll, OC.queries_bind]
    rcases List.mem_cons.mp hjo with rfl | hjo
    · rw [M.checkOC_queries H hl]
      exact List.mem_append_left _ hv
    · exact List.mem_append_right _ (ih jo hjo hl v hv)

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The straight-line extractor is sound (task 3).** A commit phase `A₁` makes at most `q₁` hash queries and outputs
a root (and a state); a later phase `B` makes at most `q₂` and outputs `n` openings at positions of its choice. The
extractor reads only the commit phase's log. The probability that some output opening verifies against the root (a
path of the tree's depth `h`) and is NOT the extracted column at its position is at most
`collBound T D + extGuess T q₁ D`, with `T = q₁ + q₂ + n(h + 2)`. -/
theorem extract_sound (h : ℕ) {St : Type} (q₁ q₂ n : ℕ) (A₁ : OC Q D (D × St)) (hA₁ : A₁.Bounded q₁)
    (B : St → OC Q D (Fin n → ℕ × MerkleOpening D S Col)) (hB : ∀ st, (B st).Bounded q₂) :
    prH (fun H => ∃ k, M.Opens H h (A₁.runLog H).1.1 (((B (A₁.runLog H).1.2).run H) k).1
          (((B (A₁.runLog H).1.2).run H) k).2
        ∧ M.extractCol (A₁.runLog H).2 h (((B (A₁.runLog H).1.2).run H) k).1 (A₁.runLog H).1.1
            ≠ some (((B (A₁.runLog H).1.2).run H) k).2.col)
      ≤ collBound (q₁ + q₂ + n * (h + 2)) D + extGuess (q₁ + q₂ + n * (h + 2)) q₁ D := by
  classical
  -- the whole run: the commit phase, the later phase, the verifier's hashing
  let C : OC Q D Unit := A₁.bind (fun rs => (B rs.2).bind (fun ops => M.checkAll h (List.ofFn ops)))
  have hck : ∀ ops : Fin n → ℕ × MerkleOpening D S Col, (M.checkAll h (List.ofFn ops)).Bounded (n * (h + 2)) :=
    fun ops => by simpa using M.checkAll_bounded h (List.ofFn ops)
  have hC : C.Bounded (q₁ + q₂ + n * (h + 2)) :=
    (hA₁.bind (fun rs => (hB rs.2).bind hck)).mono (le_of_eq (Nat.add_assoc _ _ _).symm)
  -- the target sets, read off a log prefix by replaying the commit phase
  let F : List (Q × D) → Finset D := fun P =>
    match A₁.replay P with
    | some (rs, m) => M.targets (P.take m) rs.1
    | none => ∅
  have hF : ∀ P, (F P).card ≤ 3 * q₁ + 1 := by
    intro P
    simp only [F]
    split
    · rename_i rs m hrep
      refine (M.targets_card _ _).trans ?_
      have hm := OC.replay_le A₁ q₁ hA₁ P (rs, m) hrep
      have : (P.take m).length ≤ m := by simp
      omega
    · simp
  have hcoll := collision_prob_le C _ hC
  have hfresh := freshHit_prob_le C _ hC F (fun _ => 3 * q₁ + 1) (fun P => hF P)
  simp only [sum_const, card_range, smul_eq_mul] at hfresh
  -- the event is a collision of the whole run or a fresh hit on a commit-phase target
  have hsub : {H : Q → D | ∃ k, M.Opens H h (A₁.runLog H).1.1 (((B (A₁.runLog H).1.2).run H) k).1
          (((B (A₁.runLog H).1.2).run H) k).2
        ∧ M.extractCol (A₁.runLog H).2 h (((B (A₁.runLog H).1.2).run H) k).1 (A₁.runLog H).1.1
            ≠ some (((B (A₁.runLog H).1.2).run H) k).2.col}
      ⊆ {H | ∃ a ∈ OC.queries H C, ∃ b ∈ OC.queries H C, a ≠ b ∧ H a = H b}
        ∪ {H | FreshHit F (C.runLog H).2} := by
    rintro H ⟨k, ho, hne⟩
    set L₁ := (A₁.runLog H).2 with hL₁
    set rs := (A₁.runLog H).1 with hrs
    have hrs' : rs = A₁.run H := OC.runLog_fst H A₁
    set ops := (B rs.2).run H with hops
    have hlogC : (C.runLog H).2 = L₁ ++ (((B (A₁.run H).2).bind (fun ops => M.checkAll h (List.ofFn ops))).runLog H).2 :=
      OC.runLog_bind H A₁ _
    have hqC : OC.queries H C = L₁.map Prod.fst
        ++ OC.queries H ((B (A₁.run H).2).bind (fun ops => M.checkAll h (List.ofFn ops))) := by
      simp only [OC.queries, hlogC, List.map_append]
    -- every verifier's query of opening `k` is a query of the run
    have hver : ∀ v ∈ M.openQs H (ops k).1 (ops k).2, v ∈ OC.queries H C := by
      intro v hv
      rw [hqC, OC.queries_bind]
      refine List.mem_append_right _ (List.mem_append_right _ ?_)
      rw [← hrs']
      exact M.checkAll_queries H h (List.ofFn ops) (ops k) (List.mem_ofFn.mpr ⟨k, rfl⟩) ho.1 v hv
    rcases M.extract_of_opens H L₁ (OC.runLog_answer H A₁) rs.1 ho with hext | ⟨v, hv, hb⟩
    · exact absurd hext hne
    · rcases hb with ⟨y, hy, hyv, hHy⟩ | ⟨hvL, hvT⟩
      · left
        refine ⟨y, ?_, v, hver v hv, hyv, hHy⟩
        rw [hqC]
        exact List.mem_append_left _ hy
      · right
        have hvC : v ∈ (C.runLog H).2.map Prod.fst := hver v hv
        refine freshHit_of_first H (OC.runLog_answer H C) F hvC (fun t e h1 h2 _ => ?_)
        rw [hlogC] at h1 ⊢
        have hle := first_after_prefix hvL h1 h2
        have htake : (L₁ ++ (((B (A₁.run H).2).bind (fun ops => M.checkAll h (List.ofFn ops))).runLog H).2).take t
            = L₁ ++ (((B (A₁.run H).2).bind (fun ops => M.checkAll h (List.ofFn ops))).runLog H).2.take
                (t - L₁.length) := by
          rw [List.take_append, List.take_of_length_le hle]
        simp only [F, htake]
        rw [hL₁, OC.replay_runLog_append]
        dsimp only
        rw [← hL₁, List.take_left, ← hrs', hrs]
        exact hvT
  calc prH _ ≤ (PMF.uniformOfFintype (Q → D)).toOuterMeasure
          ({H | ∃ a ∈ OC.queries H C, ∃ b ∈ OC.queries H C, a ≠ b ∧ H a = H b}
            ∪ {H | FreshHit F (C.runLog H).2}) := MeasureTheory.measure_mono hsub
    _ ≤ prH (fun H => ∃ a ∈ OC.queries H C, ∃ b ∈ OC.queries H C, a ≠ b ∧ H a = H b)
          + prH (fun H => FreshHit F (C.runLog H).2) := MeasureTheory.measure_union_le _ _
    _ ≤ collBound (q₁ + q₂ + n * (h + 2)) D + extGuess (q₁ + q₂ + n * (h + 2)) q₁ D := add_le_add hcoll hfresh

end MerkleEnc

end ZK60.Sound
