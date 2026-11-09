/-
D63 lane L26 (2026-11-07), part 4: **the decoding link of O11d** (deterministic): from the columns that open and agree
with a decoded codeword, the input commitment opens at the unique-decoding radius (`OpensU`) to the decoded value.

The extractor reads, for every column `j`, an opening `ops j` off the prover's log (`none` when it finds none); the
columns that open are the `j` with `ops j = some _`; the extracted matrix reads the opened columns' entries (`colGF`).
* `colGF`, `col_of_colGF`: a canonical column is the column of its own entries;
* `colOf`, `SaltMk`, `column_mk`: the column of decoded rows; opening data built from the decoded rows' messages and
  pads and the extracted salts and paths (a property of the instance's opening-data type: it can hold them); its
  columns are the decoded rows' columns when the decoded data rows are the value's plane;
* **`opensU_of_decoded`**: if on all but at most `e` columns the extracted opening verifies and its column is the
  encoding of the decoded rows, the decoded data rows are `v`'s plane and `v` is admissible, the built opening data
  opens the commitment to `v` at radius `e`;
* **`agree_of_closeIn`**: the extracted matrix close INSIDE the set of columns that open (`CloseIn`, the column test's
  good state) gives such decoded rows and such a set (the extracted columns canonical, as the code's decoder demands);
* `decodeIn`, `decodeIn_spec`, **`opensU_of_closeIn`**: the decoded rows as a function of the extraction (by choice),
  and the link in one step;
* `posPlane_eq_of_zero`: for the token-words plane (`posPlane`), the decoded data rows ARE the plane of the words read
  canonically at the token positions, given that they vanish elsewhere (SIC_IO's identity on the decoded data).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BindingUTest
import ZK60Formal.RunExtractOpenU
import ZK60Formal.StageInExtract

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound Code
open ZK60.Circuit (gP GF)

/-- Entry `i` of a column, as a field element. -/
noncomputable def colGF {R : ℕ} (c : ColR R) (i : Fin R) : GF :=
  Fp.toGF (c.1[i.val]'(by rw [c.2]; exact i.isLt))

/-- **A canonical column is the column of its own entries.** -/
theorem col_of_colGF {R : ℕ} (c : ColR R) (hc : ∀ a ∈ c.1, a.Canon) :
    (⟨List.ofFn (fun i : Fin R => Fp.ofGF (colGF c i)), List.length_ofFn⟩ : ColR R) = c := by
  apply Subtype.ext
  show List.ofFn (fun i : Fin R => Fp.ofGF (colGF c i)) = c.1
  apply List.ext_getElem
  · rw [List.length_ofFn, c.2]
  · intro n h1 h2
    rw [List.getElem_ofFn]
    have hmem : c.1[n]'h2 ∈ c.1 := List.mem_iff_getElem.mpr ⟨n, h2, rfl⟩
    show Fp.ofGF (Fp.toGF (c.1[n]'h2)) = c.1[n]'h2
    exact Fp.ofGF_toGF _ (hc _ hmem)

/-- **The columns that open**: the positions where the extractor found an opening. -/
def exX {N R : ℕ} (ops : Fin N → Option (MerkleOpening Dig Dig (ColR R))) : Finset (Fin N) :=
  Finset.univ.filter (fun j => (ops j).isSome = true)

theorem exX_spec {N R : ℕ} (ops : Fin N → Option (MerkleOpening Dig Dig (ColR R))) :
    ∀ j ∈ exX ops, ∃ o, ops j = some o := by
  intro j hj
  exact Option.isSome_iff_exists.mp (Finset.mem_filter.mp hj).2

/-- **The extracted matrix**: row `i`, column `j` is entry `i` of the extractor's opened column (`0` where it has
none). -/
noncomputable def exU {N R : ℕ} (ops : Fin N → Option (MerkleOpening Dig Dig (ColR R))) (i : Fin R) (j : Fin N) :
    GF :=
  ((ops j).map (fun o => colGF o.col i)).getD 0

theorem exU_spec {N R : ℕ} (ops : Fin N → Option (MerkleOpening Dig Dig (ColR R))) :
    ∀ j o, ops j = some o → ∀ i, exU ops i j = colGF o.col i := by
  intro j o h i
  simp [exU, h]

/-- **From the extension field to the base field** (finding L26-3's link, reduced to a code fact). The column test
runs over an extension `K` (its weights live there) with the base-field matrix embedded by `f`. If every `K`-codeword
whose values on a set of all but `e` columns are base-field values agrees there with (the image of) a base-field
codeword (`hbc`: for Reed–Solomon codes, the base-field interpolant), then the embedded matrix close inside `X` over
`K` gives the base-field matrix close inside `X`. -/
theorem closeIn_base {K ι κ' : Type} [Field K] [Fintype ι] (f : GF →+* K) (hf : Function.Injective f)
    (DK : Submodule K (ι → K)) (DG : Submodule GF (ι → GF)) (e : ℕ) (X : Finset ι) (U : κ' → ι → GF)
    (hbc : ∀ c ∈ DK, ∀ S : Finset ι, Fintype.card ι ≤ S.card + e → (∀ j ∈ S, ∃ a, c j = f a) →
      ∃ c' ∈ DG, ∀ j ∈ S, c j = f (c' j))
    (h : CloseIn DK e X (fun i j => f (U i j))) : CloseIn DG e X U := by
  obtain ⟨S, hSX, hS, hagr⟩ := h
  refine ⟨S, hSX, hS, fun i => ?_⟩
  obtain ⟨c, hc, hcU⟩ := mem_agreeOn.mp (hagr i)
  obtain ⟨c', hc', hcc⟩ := hbc c hc S hS (fun j hj => ⟨U i j, (hcU j hj).symm⟩)
  exact mem_agreeOn.mpr ⟨c', hc', fun j hj => hf ((hcU j hj).trans (hcc j hj))⟩

namespace PlaneCommit

variable {V St Salt : Type} (C : PlaneCommit V St Salt)

/-- **The column of rows** with messages `Mg` and pads `Pd` at position `j` (the code's canonical words). -/
noncomputable def colOf (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF) (j : Fin C.N) : ColR C.R :=
  ⟨List.ofFn (fun i => Fp.ofGF (encWord C.pts C.form (Mg i) (Pd i) j)), List.length_ofFn⟩

/-- **Opening data an extractor can build** from every row's message and pad and every column's salt and path (the
instance's opening-data type holds them: the non-data rows' messages, the pads, the salts, the paths). -/
structure SaltMk where
  bld : (Fin C.R → Fin C.n → GF) → (Fin C.R → Fin C.Q → GF) → (Fin C.N → Dig) → (Fin C.N → List Dig) → Salt
  msg_mk : ∀ (v : V) Mg Pd sl pa i, (∀ k, C.place k ≠ i) → C.msg v (bld Mg Pd sl pa) i = Mg i
  pad_mk : ∀ Mg Pd sl pa, C.pad (bld Mg Pd sl pa) = Pd
  salt_mk : ∀ Mg Pd sl pa, C.salt (bld Mg Pd sl pa) = sl
  path_mk : ∀ Mg Pd sl pa, C.path (bld Mg Pd sl pa) = pa

/-- **The built opening data's columns are the decoded rows' columns**, when the decoded data rows are `v`'s plane. -/
theorem column_mk (mk : C.SaltMk) (v : V) (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF)
    (sl : Fin C.N → Dig) (pa : Fin C.N → List Dig) (hdata : ∀ k, Mg (C.place k) = C.plane v k) (j : Fin C.N) :
    C.column v (mk.bld Mg Pd sl pa) j = C.colOf Mg Pd j := by
  have hmsg : ∀ i, C.msg v (mk.bld Mg Pd sl pa) i = Mg i := by
    intro i
    by_cases hi : ∃ k, C.place k = i
    · obtain ⟨k, rfl⟩ := hi
      rw [C.msg_place, hdata]
    · exact mk.msg_mk v Mg Pd sl pa i (fun k hk => hi ⟨k, hk⟩)
  apply Subtype.ext
  show List.ofFn (fun i => Fp.ofGF (C.word v (mk.bld Mg Pd sl pa) i j))
    = List.ofFn (fun i => Fp.ofGF (encWord C.pts C.form (Mg i) (Pd i) j))
  congr 1
  funext i
  rw [word, hmsg i, mk.pad_mk]

/-- The salts the extractor's openings carry (`zeroDig` where it has none). -/
def exSalt (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R))) (j : Fin C.N) : Dig :=
  ((ops j).map MerkleOpening.salt).getD zeroDig

/-- The paths the extractor's openings carry (`[]` where it has none). -/
def exPath (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R))) (j : Fin C.N) : List Dig :=
  ((ops j).map MerkleOpening.path).getD []

/-- **The decoding link** (deterministic; D63 lane L26). If, on a set `S` of all but at most `e` columns, the
extractor's opening `ops j` verifies at `j` and its column is the encoding of the decoded rows `(Mg, Pd)`, the decoded
data rows are `v`'s plane and `v` is admissible, then the opening data built from the decoded rows and the extracted
salts and paths opens the commitment to `v` at radius `e`. -/
theorem opensU_of_decoded (mk : C.SaltMk) (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (G : QB L → Dig)
    (s : St) (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (hops : ∀ j o, ops j = some o → (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root s) j.val o)
    (v : V) (hv : C.ok v) (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF)
    (hdata : ∀ k, Mg (C.place k) = C.plane v k) (S : Finset (Fin C.N)) (hS : C.N ≤ S.card + e)
    (hagree : ∀ j ∈ S, ∃ o, ops j = some o ∧ o.col = C.colOf Mg Pd j) :
    C.OpensU L h64 hr e G s v (mk.bld Mg Pd (C.exSalt ops) (C.exPath ops)) := by
  refine ⟨hv, S, hS, fun j hj => ?_⟩
  obtain ⟨⟨oc, osalt, opath⟩, ho, hcol⟩ := hagree j hj
  have hcol' : oc = C.colOf Mg Pd j := hcol
  have hsalt : C.salt (mk.bld Mg Pd (C.exSalt ops) (C.exPath ops)) j = osalt := by
    rw [mk.salt_mk]
    simp [exSalt, ho]
  have hpath : C.path (mk.bld Mg Pd (C.exSalt ops) (C.exPath ops)) j = opath := by
    rw [mk.path_mk]
    simp [exPath, ho]
  rw [C.column_mk mk v Mg Pd _ _ hdata j, hsalt, hpath, ← hcol']
  exact hops j _ ho

/-- **From closeness inside the openable set to agreement** (deterministic). If the extracted rows `U`, read off the
extracted canonical columns, are close INSIDE the set `X` of columns that open (at radius `e`, to the encoder's code),
then there are decoded rows `(Mg, Pd)` and a set of all but `e` columns, all opening, on which the opened column IS the
encoding of the decoded rows. -/
theorem agree_of_closeIn (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (hcan : ∀ j o, ops j = some o → ∀ a ∈ o.col.1, a.Canon) (X : Finset (Fin C.N))
    (hX : ∀ j ∈ X, ∃ o, ops j = some o) (U : Fin C.R → Fin C.N → GF)
    (hU : ∀ j o, ops j = some o → ∀ i, U i j = colGF o.col i) (e : ℕ)
    (hcl : CloseIn (LinearMap.range (encLin (Q := C.Q) C.pts C.form)) e X U) :
    ∃ (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF) (S : Finset (Fin C.N)),
      C.N ≤ S.card + e ∧ ∀ j ∈ S, ∃ o, ops j = some o ∧ o.col = C.colOf Mg Pd j := by
  obtain ⟨S, hSX, hS, hagr⟩ := hcl
  choose u hu hUu using fun i => mem_agreeOn.mp (hagr i)
  choose m hm using fun i => LinearMap.mem_range.mp (hu i)
  refine ⟨fun i t => m i (Fin.castAdd C.Q t), fun i t => m i (Fin.natAdd C.n t), S, ?_, fun j hj => ?_⟩
  · rw [Fintype.card_fin] at hS
    exact hS
  · obtain ⟨o, ho⟩ := hX j (hSX hj)
    refine ⟨o, ho, ?_⟩
    rw [← col_of_colGF o.col (hcan j o ho)]
    apply Subtype.ext
    show List.ofFn (fun i => Fp.ofGF (colGF o.col i))
      = List.ofFn (fun i => Fp.ofGF (encWord C.pts C.form (fun t => m i (Fin.castAdd C.Q t))
          (fun t => m i (Fin.natAdd C.n t)) j))
    congr 1
    funext i
    rw [← hU j o ho i, hUu i j hj, ← hm i]
    rfl

open Classical in
/-- **The decoded rows of the extraction** (by choice when some decoded rows agree with the opened columns on all but
`e` columns; zero otherwise): a function of the extractor's openings, as `KnowledgeSound`'s extractor must be. -/
noncomputable def decodeIn (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R))) (e : ℕ) :
    (Fin C.R → Fin C.n → GF) × (Fin C.R → Fin C.Q → GF) :=
  if h : ∃ (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF) (S : Finset (Fin C.N)),
      C.N ≤ S.card + e ∧ ∀ j ∈ S, ∃ o, ops j = some o ∧ o.col = C.colOf Mg Pd j
  then (h.choose, h.choose_spec.choose) else (0, 0)

/-- `decodeIn` agrees with the opened columns whenever some decoded rows do. -/
theorem decodeIn_spec (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R))) (e : ℕ)
    (h : ∃ (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF) (S : Finset (Fin C.N)),
      C.N ≤ S.card + e ∧ ∀ j ∈ S, ∃ o, ops j = some o ∧ o.col = C.colOf Mg Pd j) :
    ∃ S : Finset (Fin C.N), C.N ≤ S.card + e
      ∧ ∀ j ∈ S, ∃ o, ops j = some o ∧ o.col = C.colOf (C.decodeIn ops e).1 (C.decodeIn ops e).2 j := by
  classical
  have hd : C.decodeIn ops e = (h.choose, h.choose_spec.choose) := by
    unfold decodeIn
    rw [dite_eq_left h]
  rw [hd]
  exact h.choose_spec.choose_spec

/-- **The decoding link in one step** (D63 lane L26): the extracted matrix close inside the set of columns that open,
the extracted openings verifying with canonical columns, and the decoded data rows `v`'s plane for an admissible `v`:
the commitment opens to `v` at radius `e` with the built opening data. -/
theorem opensU_of_closeIn (mk : C.SaltMk) (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (G : QB L → Dig)
    (s : St) (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (hops : ∀ j o, ops j = some o → (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root s) j.val o)
    (hcan : ∀ j o, ops j = some o → ∀ a ∈ o.col.1, a.Canon) (X : Finset (Fin C.N))
    (hX : ∀ j ∈ X, ∃ o, ops j = some o) (U : Fin C.R → Fin C.N → GF)
    (hU : ∀ j o, ops j = some o → ∀ i, U i j = colGF o.col i)
    (hcl : CloseIn (LinearMap.range (encLin (Q := C.Q) C.pts C.form)) e X U) (v : V) (hv : C.ok v)
    (hdata : ∀ k, (C.decodeIn ops e).1 (C.place k) = C.plane v k) :
    C.OpensU L h64 hr e G s v (mk.bld (C.decodeIn ops e).1 (C.decodeIn ops e).2 (C.exSalt ops) (C.exPath ops)) := by
  obtain ⟨S, hS, hag⟩ := C.decodeIn_spec ops e (C.agree_of_closeIn ops hcan X hX U hU e hcl)
  exact C.opensU_of_decoded mk L h64 hr e G s ops hops v hv _ _ hdata S hS hag

end PlaneCommit

/-! ## The token-words plane -/

section Token

open ZK60.StageX (canonWord canonWord_cast)

/-- **The decoded data rows are the plane of the words at the token positions** (`posPlane`, the token-words
endpoint's plane), read canonically, when they vanish at every other position (SIC_IO's identity, `end = supp·tok`,
on the decoded data). -/
theorem posPlane_eq_of_zero {T : Type} {dR n : ℕ} {pos : T → Fin dR × Fin n}
    (Dt : Fin dR → Fin n → GF) (hz : ∀ k i, (¬ ∃ t, pos t = (k, i)) → Dt k i = 0) :
    Dt = posPlane pos (fun t => canonWord (Dt (pos t).1 (pos t).2)) := by
  classical
  funext k i
  by_cases hex : ∃ t, pos t = (k, i)
  · have hc := hex.choose_spec
    simp only [posPlane, dite_eq_left hex, canonWord_cast, hc]
  · simp only [posPlane, dite_eq_right hex]
    exact hz k i hex

/-- **W16R2's token-words endpoint has the token-words plane** (the premise `hplane` of `epCoverU`), by definition. -/
theorem w16r2TokenCommit_plane {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 14)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 280 → GF)
    (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (root : St → Dig) (tag : MTag)
    (x : T → ℕ) :
    (w16r2TokenCommit R dR hpos place msg msg_place pad salt path root tag).plane x = posPlane pos x :=
  rfl

/-- **R13's token-words endpoint has the token-words plane**, by definition. -/
theorem r13TokenCommit_plane {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 14)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (root : St → Dig) (tag : MTag)
    (x : T → ℕ) :
    (R13.r13TokenCommit R dR hpos place msg msg_place pad salt path root tag).plane x = posPlane pos x :=
  rfl

end Token

end ZK60.Exec
