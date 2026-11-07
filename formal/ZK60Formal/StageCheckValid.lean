/-
D63, Lean lane L15 (2026-11-07): **the Shieldstral classifier profile's stage parameters as finite checks**, where the
data is in the repository (deliverable 4). `R.Valid` for a classifier run is `ClassifyRunPublic.Valid`
(CircuitTokenRun.lean): stage IN-C's `InPublic.Valid`, every block's `BlockPublic.Valid`, stage OUT-C's
`OutCPublic.Valid`.

The data (hashline src/private_block/token_io/classify.rs:178-236, the three registered D37 category policies, read
2026-11-07): the tekken vocabulary `V = 131,072 = 2^17`, BOS `1`, the control-id class `[0, 1000)`, the public pad id
`11`, the template `CATEGORY_TEMPLATE_HEAD ++ query ++ CATEGORY_TEMPLATE_TAIL` and the suffix `[4]`, yes `13,059`, no
`2,649`, `c = 0`; Shieldstral-1.0-3B's width `d = 3,072` (`ClassifierProfile::new`: five margin limbs).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`; the list facts by `decide`):
* `kapOf`, `isTOf`: the template's public id and indicator at a position (`ClassifierProfile::kappa`,
  `is_template`, classify.rs:670-691), for any content length `n` and any `T`;
* `kapOf_lt`: every template id is a vocabulary id when the template's lists and the pad are;
* **`shield_in_valid`**: for each of the three category policies, every content length and EVERY int16 embedding (the
  loader's `Vec<i16>`), stage IN-C's public data is `InPublic.Valid`;
* `shield_policy_door`: the policy facts the classifier door checks (classify.rs:552-647): BOS first and below `V`,
  yes ≠ no and both below `V`, the template and pad ids below `V`, `0 < num_special < V`, `|c| ≤ 2^33`;
* **`shield_outc_valid`**: at `d = 3,072` with five margin limbs, for EVERY margin vector in `[−32767, 32767]` (the
  loader refuses `−32768`) and EVERY final norm in the door's classes, stage OUT-C's public data is `OutCPublic.Valid`
  (the window `3072·127·32767 + 2^33 + 1 ≤ 2^40` and the no-wrap bound below `p`);
* `shield_limbs`: five limbs is `⌈bit_length(top)/8⌉` for `top = 3072·127·32767 + 2^33 + 1` (35 bits).

What cannot be checked here (the weights are not in the repository, D62): that the embedding and the margin vector ARE
the pinned Shieldstral tensor's (their int16 class is the loader's type, a hypothesis above); the final norm's
`(g0, Cn, Ceps, tn)` values (read from the export profile; their classes are the door's refusals, a hypothesis above);
every block's `BlockPublic.Valid` (the weights, L9's finding); the block shape's `BlockShape.Valid` (a registered
shape's constants, not restated here).
-/
import ZK60Formal.CircuitTokenRun

namespace ZK60.StageX.Valid

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out ZK60.TokenRun

/-! ## The registered category policies' data (classify.rs:192-236) -/

/-- `CATEGORY_TEMPLATE_HEAD`. -/
def headIds : List ℕ :=
  [1, 17, 1074, 45463, 5627, 1278, 23762, 37005, 1278, 13795, 4057, 1408, 1278, 27356, 1321, 1278, 83779, 5662, 1046,
    13708, 1455, 1278, 4832, 1710, 2342, 1402, 1429, 13059, 1034, 1505, 1429, 2649, 3871, 18, 3, 1060, 1785, 8166, 72067,
    3213, 1584, 1261, 12216, 11673, 2412, 1046, 63882, 1261, 21680, 27710, 13472, 1338, 1060, 7087, 72067, 20525, 1593,
    4701]

/-- `CATEGORY_TEMPLATE_TAIL` (`"\n\n<Document>: [User]"`). -/
def tailIds : List ℕ := [2634, 1060, 16060, 72067, 1766, 4019, 1093]

def qSexual : List ℕ := [4231, 10703, 70351, 1505, 61522, 14960, 4318]
def qViolence : List ℕ := [17767, 47223, 16988, 1505, 17438, 8137, 16988]
def qHate : List ℕ := [4231, 31483, 16181, 27491, 1261, 8949, 3204, 1044, 1505, 84083, 1505, 7357, 19447]

/-- A category policy's template prefix. -/
def prefixOf (q : List ℕ) : List ℕ := headIds ++ q ++ tailIds

def suffixIds : List ℕ := [4]

def shieldV : ℕ := 131072
def shieldBos : ℕ := 1
def shieldNs : ℕ := 1000
def shieldPad : ℕ := 11
def shieldYes : ℕ := 13059
def shieldNo : ℕ := 2649

/-! ## The template at the positions -/

/-- **The template's public id at position `t`** (`kappa`): the prefix's, `0` at content, the suffix's, the pad id
after the suffix up to `T`, `0` beyond. -/
def kapOf (pre suf : List ℕ) (pad n T t : ℕ) : ℕ :=
  if t < pre.length then pre.getD t 0
  else if t < pre.length + n then 0
  else if t < pre.length + n + suf.length then suf.getD (t - pre.length - n) 0
  else if t < T then pad else 0

/-- **The template indicator** (`is_template`): the prefix, and every position after the content up to `T`. -/
def isTOf (pre : List ℕ) (n T t : ℕ) : Bool := decide (t < pre.length ∨ (pre.length + n ≤ t ∧ t < T))

theorem getD_lt {l : List ℕ} {V d : ℕ} (h : ∀ x ∈ l, x < V) (hd : d < V) (i : ℕ) : l.getD i d < V := by
  rw [List.getD_eq_getElem?_getD]
  rcases hi : l[i]? with _ | x
  · exact hd
  · exact h x (List.mem_of_getElem? hi)

theorem kapOf_lt {pre suf : List ℕ} {pad n T V : ℕ} (hpre : ∀ x ∈ pre, x < V) (hsuf : ∀ x ∈ suf, x < V)
    (hpad : pad < V) (hV : 0 < V) (t : ℕ) : kapOf pre suf pad n T t < V := by
  unfold kapOf
  split_ifs
  · exact getD_lt hpre hV t
  · exact hV
  · exact getD_lt hsuf hV _
  · exact hpad
  · exact hV

/-! ## Stage IN-C's public data -/

/-- **Stage IN-C's public data** at a block shape `S`, a category template `q`, a content length `n` and an embedding. -/
def shieldIn (S : BlockShape) (q : List ℕ) (n : ℕ) (emb : ℕ → S.Wid → ℤ) : InPublic S :=
  ⟨shieldV, shieldBos, emb, fun t => isTOf (prefixOf q) n S.T t, fun t => kapOf (prefixOf q) suffixIds shieldPad n S.T t,
    shieldNs⟩

theorem prefix_lt_sexual : ∀ x ∈ prefixOf qSexual, x < shieldV := by decide
theorem prefix_lt_violence : ∀ x ∈ prefixOf qViolence, x < shieldV := by decide
theorem prefix_lt_hate : ∀ x ∈ prefixOf qHate, x < shieldV := by decide
theorem suffix_lt : ∀ x ∈ suffixIds, x < shieldV := by decide

/-- **Stage IN-C's public data is valid** for each registered category policy, every content length and every int16
embedding. -/
theorem shield_in_valid (S : BlockShape) (q : List ℕ) (hq : q = qSexual ∨ q = qViolence ∨ q = qHate) (n : ℕ)
    (emb : ℕ → S.Wid → ℤ) (hemb : ∀ v i, i16 (emb v i)) : (shieldIn S q n emb).Valid := by
  have hpre : ∀ x ∈ prefixOf q, x < shieldV := by
    rcases hq with rfl | rfl | rfl
    · exact prefix_lt_sexual
    · exact prefix_lt_violence
    · exact prefix_lt_hate
  refine ⟨(by decide : 2 ≤ shieldV), (by decide : shieldV ≤ 2 ^ 17), (by decide : shieldBos < shieldV), hemb,
    fun t => ?_, (by decide : shieldNs < shieldV)⟩
  exact kapOf_lt hpre suffix_lt (by decide : shieldPad < shieldV) (by decide : 0 < shieldV) t

/-- **The policy facts the classifier door checks** (classify.rs:552-647) for each registered category policy: BOS is
the template's first id and below `V`; yes ≠ no, both below `V`; every template id and the pad below `V`;
`0 < num_special < V`; the threshold `c = 0` within `[−2^33, 2^33]`. -/
theorem shield_policy_door (q : List ℕ) (hq : q = qSexual ∨ q = qViolence ∨ q = qHate) :
    (prefixOf q).head? = some shieldBos ∧ shieldBos < shieldV ∧ shieldYes ≠ shieldNo ∧ shieldYes < shieldV ∧
      shieldNo < shieldV ∧ (∀ x ∈ prefixOf q ++ suffixIds, x < shieldV) ∧ shieldPad < shieldV ∧ 0 < shieldNs ∧
      shieldNs < shieldV ∧ (-(2 : ℤ) ^ 33 ≤ 0 ∧ (0 : ℤ) ≤ 2 ^ 33) := by
  refine ⟨?_, by decide, by decide, by decide, by decide, ?_, by decide, by decide, by decide, by norm_num⟩ <;>
    rcases hq with rfl | rfl | rfl <;> decide

/-! ## Stage OUT-C's public data -/

/-- **Five margin limbs at `d = 3,072`** (`ClassifierProfile::new`: `top = d·127·32767 + 2^33 + 1` has 35 bits). -/
theorem shield_limbs : 3072 * 127 * 32767 + 2 ^ 33 + 1 < 2 ^ 35 ∧ 2 ^ 34 ≤ 3072 * 127 * 32767 + 2 ^ 33 + 1 ∧
    (35 + 7) / 8 = 5 := by
  norm_num

/-- **Stage OUT-C's public data is valid** at Shieldstral's `d = 3,072` with five margin limbs and `c = 0`, for every
margin vector in `[−32767, 32767]` and every final norm in the door's classes. -/
theorem shield_outc_valid (wΔ : Fin 3072 → ℤ) (hw : ∀ i, |wΔ i| ≤ 32767) (g0 cn ceps : ℤ) (tn : ℕ)
    (hg0 : 1 ≤ g0 ∧ g0 ≤ 127) (hcn : 1 ≤ cn ∧ cn ≤ 2 ^ 20) (hceps : 1 ≤ ceps ∧ ceps ≤ 2 ^ 40) (htn : tn ≤ 16) :
    (⟨wΔ, 0, g0, cn, ceps, tn, 5⟩ : OutCPublic 3072).Valid where
  w := hw
  c := by norm_num
  g0a := hg0.1
  g0b := hg0.2
  cna := hcn.1
  cnb := hcn.2
  cepsa := hceps.1
  cepsb := hceps.2
  tn := htn
  win := by simp only [marginMax]; norm_num
  nowrap := by simp only [marginMax]; rw [gP_int]; norm_num

end ZK60.StageX.Valid
