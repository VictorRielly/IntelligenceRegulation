/-
D63 lane L68c, part 3c (`HonestShieldZKProg.lean`):
deduplicated 112-tree + 28-segment Shieldstral T128 R13 oracle-program (`PProg`) building blocks with
`.dep` `colDigest`, `.pt` `saltLeaf` / `nodeHash` / transcript / cached `posTag`, and `0` duplicate
opening-audit draws — feeding `RunShieldOpenShell.classifyP_zk_of_prog_model` directly inside Sol's
conservative `T = 2^20` budget (`HonestShieldZKBase.shdRunErrRes`, `pts = 11,767,696`).

What this file defines and proves (standard Lean foundations `propext`, `Classical.choice`, `Quot.sound` only):
1. **Domain-separated unused padding query (`shdP_zkPad`)**:
   49-byte unkeyed query `prevDig ‖ "zk-pad/v1" ‖ le64 idx`, proved disjoint from all column-digest queries
   (`shdP_zkPad_ne_col`, `shdP_zkPad_ne_colBytes`), 64-byte leaf/node queries (`shdP_zkPad_ne_leaf`,
   `shdP_zkPad_ne_node`), transcript squeezes/absorbs (`shdP_zkPad_ne_squeeze`, `shdP_zkPad_ne_absorb`,
   `shdP_zkPad_ne_tr`), and start queries with `domain.length ≠ 37` (`shdP_zkPad_ne_start`), plus
   injectivity in `(idx, prevDig)` on `idx < 2^64` (`shdP_zkPad_injective_idx`).
2. **Bottom-up `.dep`-`colDigest` + `.pt`-`saltLeaf`/`nodeHash` Merkle tree `PProg` (`merkleTreeProg`)**:
   emits each leaf as `.dep colQ → .pt leafQ` and `2^d - 1` internal nodes bottom-up as `.pt nodeQ`,
   returning cached `MerkleLevels d` (`0` extra queries for root and authentication paths). Proves exact
   `.run G` agreement with `rootOf` and `pathOf` (`merkleTreeProg_run`, `merkleTableProg_run`,
   `merkleMaskTableProg_run`), `PtLE (2^d + (2^d - 1))`, `QLE (2^d + 2^d + (2^d - 1))`, `DepAbsorbed`, `DepIn`.
3. **Deduplicated transcript, `posTag`, opening-audit, `bOpen`, `bMask`, and run-header `PProg` combinators**:
   `trAbsorbProg`, `trChallengeFp2Prog`, `trChallengeFp2VecProg`, `posTagProg` (`2` `.pt`s per segment
   boundary, `29 * 2 = 58` total), `zkRhosProg`, `openingAuditProveProg` (draws `zkRhos` ONCE, runs pure
   `openingAuditOk` equivalent to `openingChallenges`, and builds `OpeningZk` from cached `MerkleLevels`
   with `0` duplicate draws and `0` Merkle queries), `bOpenProg`, `bMaskProg`, and `shdP_hdrPProg`.
4. **Full 112-tree + 28-segment budget arithmetic (`shdP_zkProg_counts`), `ShdRunDepSet`, and
   `shdP_zk_of_prog_res`**:
   verifies `112` trees, `L = 5,359,616`, `N = 5,359,504`, `283,821` main transcript `.pt`s + `58` deduped
   `posTag` `.pt`s = `283,879 ≤ 2^20`, total `k = 11,002,999 ≤ 11,767,696`, packages `ShdRunDepSet` (disjoint
   from `shdP_zkPad`), and wraps `classifyP_zk_of_prog_model` at `shdRunErrRes` discharging `hres` via `DepAbsorbed`.
-/
import ZK60Formal.HonestShieldProgBase
import ZK60Formal.HonestShieldZKBase
import ZK60Formal.HonestOpenFields
import ZK60Formal.HonestShieldCore

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.ZKHonest ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)

/-! ## 1. Domain-separated unused padding query (`shdP_zkPad`) -/

section ZkPad

/-- ASCII bytes of `"zk-pad/v1"` (`9` bytes; leading byte `'z' = 122`). -/
def shdP_zkPadTag : List UInt8 := [122, 107, 45, 112, 97, 100, 47, 118, 49]

/-- Padding message `prevDig ‖ "zk-pad/v1" ‖ le64 idx` (`49` bytes): length `49` separates it from all `8 * m`
column digests, 64-byte leaf/node queries, and 47-byte squeezes; byte 32 (`122`) separates it from every `absorbMsg`. -/
def shdP_zkPadMsg (idx : ℕ) (prev : Dig) : List UInt8 :=
  prev.toList ++ (shdP_zkPadTag ++ le64 (UInt64.ofNat idx))

theorem shdP_zkPadMsg_length (idx : ℕ) (prev : Dig) : (shdP_zkPadMsg idx prev).length = 49 := by
  simp only [shdP_zkPadMsg, List.length_append, prev.2, le64_length]
  rfl

/-- Domain-separated unkeyed padding query in `QB Lq` for `PProg.ptsOf` early-refusal slots. -/
def shdP_zkPad (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig) : QB Lq :=
  (none, ⟨shdP_zkPadMsg idx prev, by rw [shdP_zkPadMsg_length]; omega⟩)

private theorem shdP_zkPad_ne_of_len {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (bs : List UInt8) (hbs : bs.length ≤ Lq) (hne : bs.length ≠ 49) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨bs, hbs⟩) := by
  intro h
  have hlen : (shdP_zkPadMsg idx prev).length = bs.length := congrArg (fun q : QB Lq => q.2.1.length) h
  rw [shdP_zkPadMsg_length] at hlen
  exact hne hlen.symm

theorem shdP_zkPad_ne_colBytes (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (bs : List UInt8) (hbs : bs.length ≤ Lq) (h8 : bs.length % 8 = 0) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨bs, hbs⟩) :=
  shdP_zkPad_ne_of_len hL20 idx prev k bs hbs (by omega)

theorem shdP_zkPad_ne_col (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (col : List Fp) (hcol : (colBytes col).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨colBytes col, hcol⟩) :=
  shdP_zkPad_ne_of_len hL20 idx prev k (colBytes col) hcol (by rw [colBytes_length]; omega)

theorem shdP_zkPad_ne_leaf (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (x s : Dig) (hl : (x.toList ++ s.toList).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨x.toList ++ s.toList, hl⟩) :=
  shdP_zkPad_ne_of_len hL20 idx prev k _ hl (by rw [digPair_length]; omega)

theorem shdP_zkPad_ne_node (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (a b : Dig) (hn : (a.toList ++ b.toList).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨a.toList ++ b.toList, hn⟩) :=
  shdP_zkPad_ne_of_len hL20 idx prev k _ hn (by rw [digPair_length]; omega)

theorem shdP_zkPad_ne_squeeze (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (st : Dig) (ctr : UInt64) (hs : (squeezeMsg st ctr).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨squeezeMsg st ctr, hs⟩) :=
  shdP_zkPad_ne_of_len hL20 idx prev k _ hs (by rw [squeezeMsg_length]; omega)

theorem shdP_zkPad_ne_absorb (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (st : Dig) (label data : List UInt8) (ha : (absorbMsg st label data).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨absorbMsg st label data, ha⟩) := by
  intro h
  have hm : shdP_zkPadMsg idx prev = absorbMsg st label data := congrArg (fun q : QB Lq => q.2.1) h
  have hlen : (shdP_zkPadMsg idx prev).length = (absorbMsg st label data).length := congrArg List.length hm
  rw [shdP_zkPadMsg_length] at hlen
  have habs_len : (absorbMsg st label data).length = 48 + label.length + data.length := by
    simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length]; omega
  have hlab : label.length = 0 ∨ label.length = 1 := by omega
  have hdrop : shdP_zkPadTag ++ le64 (UInt64.ofNat idx) =
      le64 (UInt64.ofNat label.length) ++ (label ++ (le64 (UInt64.ofNat data.length) ++ data)) := by
    have hd := congrArg (List.drop 32) hm
    rw [shdP_zkPadMsg, absorbMsg, List.drop_left' prev.2, List.drop_left' st.2] at hd
    exact hd
  have h0 := congrArg (fun l : List UInt8 => l[0]?) hdrop
  have hlhs : (shdP_zkPadTag ++ le64 (UInt64.ofNat idx))[0]? = some (122 : UInt8) := rfl
  rw [hlhs] at h0
  rcases hlab with hlab0 | hlab1
  · rw [hlab0, List.getElem?_append_left (by rw [le64_length]; omega)] at h0
    have hrhs : (le64 (UInt64.ofNat 0))[0]? = some (0 : UInt8) := by decide
    rw [hrhs] at h0
    have hf : False := (by decide : (some (122 : UInt8) : Option UInt8) ≠ some 0) h0; cases hf
  · rw [hlab1, List.getElem?_append_left (by rw [le64_length]; omega)] at h0
    have hrhs : (le64 (UInt64.ofNat 1))[0]? = some (1 : UInt8) := by decide
    rw [hrhs] at h0
    have hf : False := (by decide : (some (122 : UInt8) : Option UInt8) ≠ some 1) h0; cases hf

theorem shdP_zkPad_ne_tr (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (st : Dig) (it : TItem) (hm : (it.msg st).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨it.msg st, hm⟩) := by
  cases it with
  | absorb label data => exact shdP_zkPad_ne_absorb Lq hL20 idx prev k st label data hm
  | squeeze ctr => exact shdP_zkPad_ne_squeeze Lq hL20 idx prev k st ctr hm

theorem shdP_zkPad_ne_start (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (idx : ℕ) (prev : Dig)
    (k : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 37) (hs : (startMsg domain).length ≤ Lq) :
    shdP_zkPad Lq hL20 idx prev ≠ (k, ⟨startMsg domain, hs⟩) :=
  shdP_zkPad_ne_of_len hL20 idx prev k _ hs (by
    have htag : startTag.length = 12 := rfl; rw [startMsg, List.length_append, htag]; omega)

theorem shdP_runDomain_length_ne_37 : shdP_runDomain.length ≠ 37 := by decide

theorem shdP_zkPad_injective_idx (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    {i₁ i₂ : ℕ} (hi₁ : i₁ < 2 ^ 64) (hi₂ : i₂ < 2 ^ 64) {d₁ d₂ : Dig}
    (h : shdP_zkPad Lq hL20 i₁ d₁ = shdP_zkPad Lq hL20 i₂ d₂) :
    i₁ = i₂ ∧ d₁ = d₂ := by
  have hm : shdP_zkPadMsg i₁ d₁ = shdP_zkPadMsg i₂ d₂ := congrArg (fun q : QB Lq => q.2.1) h
  have hd : d₁ = d₂ := by
    have ht := congrArg (List.take 32) hm
    rw [shdP_zkPadMsg, shdP_zkPadMsg, List.take_left' d₁.2, List.take_left' d₂.2] at ht
    exact Subtype.ext ht
  have hi : i₁ = i₂ := by
    have hdrop1 := congrArg (List.drop 32) hm
    rw [shdP_zkPadMsg, shdP_zkPadMsg, List.drop_left' d₁.2, List.drop_left' d₂.2] at hdrop1
    have hdrop2 := congrArg (List.drop 9) hdrop1
    have htag : shdP_zkPadTag.length = 9 := rfl
    rw [List.drop_left' htag, List.drop_left' htag] at hdrop2
    have h64 : UInt64.ofNat i₁ = UInt64.ofNat i₂ := by
      rw [← ofLE64_le64 (UInt64.ofNat i₁), hdrop2, ofLE64_le64]
    have hn := congrArg UInt64.toNat h64
    rw [UInt64.toNat_ofNat', UInt64.toNat_ofNat', Nat.mod_eq_of_lt hi₁, Nat.mod_eq_of_lt hi₂] at hn
    exact hn
  exact ⟨hi, hd⟩

end ZkPad

/-! ## 2. `PProg` composition, `DepStrict`/`PurePt`, and bottom-up Merkle tree `PProg` (`merkleTreeProg`) -/

section PProgLib

variable {Q D α β : Type}

private theorem run_ret (H : Q → D) (a : α) : (PProg.ret a : PProg Q D α).run H = a := rfl
private theorem run_dep (H : Q → D) (z : Q) (k : D → PProg Q D α) :
    (PProg.dep z k : PProg Q D α).run H = (k (H z)).run H := rfl
private theorem run_pt (H : Q → D) (z : Q) (k : D → PProg Q D α) :
    (PProg.pt z k : PProg Q D α).run H = (k (H z)).run H := rfl

theorem ptLE_mono : ∀ (p : PProg Q D α) {m n : ℕ}, p.PtLE m → m ≤ n → p.PtLE n
  | .ret _, _, _, _, _ => trivial
  | .dep _ k, _, _, hp, hmn => fun d => ptLE_mono (k d) (hp d) hmn
  | .pt _ k, _, _, hp, hmn => ⟨lt_of_lt_of_le hp.1 hmn, fun d => ptLE_mono (k d) (hp.2 d) (by omega)⟩

theorem ptLE_andThen :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β) {m n : ℕ},
      p.PtLE m → (∀ a, (f a).PtLE n) → (p.andThen f).PtLE (m + n)
  | .ret a, f, m, n, _, hf => ptLE_mono (f a) (hf a) (Nat.le_add_left n m)
  | .dep _ k, f, _, _, hp, hf => fun d => ptLE_andThen (k d) f (hp d) hf
  | .pt _ k, f, m, n, hp, hf =>
    ⟨by have := hp.1; omega, fun d =>
      ptLE_mono ((k d).andThen f) (ptLE_andThen (k d) f (hp.2 d) hf) (by have := hp.1; omega)⟩

theorem qLE_mono : ∀ (p : PProg Q D α) {m n : ℕ}, p.QLE m → m ≤ n → p.QLE n
  | .ret _, _, _, _, _ => trivial
  | .dep _ k, _, _, hp, hmn => ⟨lt_of_lt_of_le hp.1 hmn, fun d => qLE_mono (k d) (hp.2 d) (by omega)⟩
  | .pt _ k, _, _, hp, hmn => ⟨lt_of_lt_of_le hp.1 hmn, fun d => qLE_mono (k d) (hp.2 d) (by omega)⟩

theorem qLE_andThen :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β) {m n : ℕ},
      p.QLE m → (∀ a, (f a).QLE n) → (p.andThen f).QLE (m + n)
  | .ret a, f, m, n, _, hf => qLE_mono (f a) (hf a) (Nat.le_add_left n m)
  | .dep _ k, f, m, n, hp, hf =>
    ⟨by have := hp.1; omega, fun d =>
      qLE_mono ((k d).andThen f) (qLE_andThen (k d) f (hp.2 d) hf) (by have := hp.1; omega)⟩
  | .pt _ k, f, m, n, hp, hf =>
    ⟨by have := hp.1; omega, fun d =>
      qLE_mono ((k d).andThen f) (qLE_andThen (k d) f (hp.2 d) hf) (by have := hp.1; omega)⟩

theorem depIn_mono {S₁ S₂ : Set Q} (hsub : S₁ ⊆ S₂) :
    ∀ (p : PProg Q D α), p.DepIn S₁ → p.DepIn S₂
  | .ret _, _ => trivial
  | .dep _ k, hp => ⟨hsub hp.1, fun d => depIn_mono hsub (k d) (hp.2 d)⟩
  | .pt _ k, hp => fun d => depIn_mono hsub (k d) (hp d)

theorem depIn_andThen {S : Set Q} :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β),
      p.DepIn S → (∀ a, (f a).DepIn S) → (p.andThen f).DepIn S
  | .ret a, f, _, hf => hf a
  | .dep _ k, f, hp, hf => ⟨hp.1, fun d => depIn_andThen (k d) f (hp.2 d) hf⟩
  | .pt _ k, f, hp, hf => fun d => depIn_andThen (k d) f (hp d) hf

/-- Compositional absorption invariant: every `.dep` (or pair of consecutive `.dep`s) is immediately
consumed by a `.pt` whose continuation does not read the `.dep` digest(s). Closed under `andThen` and
implies `HonestShieldProgBase.DepAbsorbed`. -/
inductive DepStrict : PProg Q D α → Prop
  | ret (a : α) : DepStrict (.ret a)
  | pt (z : Q) (k : D → PProg Q D α) : (∀ d, DepStrict (k d)) → DepStrict (.pt z k)
  | depPt (z : Q) (q : D → Q) (k : D → PProg Q D α) : (∀ d, DepStrict (k d)) →
      DepStrict (.dep z (fun d => .pt (q d) k))
  | dep2Pt (z₁ : Q) (z₂ : D → Q) (q : D → D → Q) (k : D → PProg Q D α) : (∀ d, DepStrict (k d)) →
      DepStrict (.dep z₁ (fun d₁ => .dep (z₂ d₁) (fun d₂ => .pt (q d₁ d₂) k)))

theorem DepStrict.toDepAbsorbed {p : PProg Q D α} (h : DepStrict p) : DepAbsorbed p := by
  induction h with
  | ret a => exact DepAbsorbed.ret a
  | pt z k _ ih => exact DepAbsorbed.pt z k ih
  | depPt z q k _ ih => exact depAbsorbed_depPt z q k ih
  | dep2Pt z₁ z₂ q k _ ih => exact depAbsorbed_dep2Pt z₁ z₂ q k ih

theorem DepStrict.andThen {p : PProg Q D α} {f : α → PProg Q D β}
    (hp : DepStrict p) (hf : ∀ a, DepStrict (f a)) : DepStrict (p.andThen f) := by
  induction hp with
  | ret a => exact hf a
  | pt z _ _ ih => exact DepStrict.pt z _ ih
  | depPt z q _ _ ih => exact DepStrict.depPt z q _ ih
  | dep2Pt z₁ z₂ q _ _ ih => exact DepStrict.dep2Pt z₁ z₂ q _ ih

theorem DepStrict.hres [Inhabited D] {p : PProg Q D α} (h : DepStrict p) (H' : Q → D) (v : ℕ → D) :
    p.res H' v 0 = p.res (fun _ => (default : D)) v 0 :=
  hres_of_depAbsorbed h.toDepAbsorbed H' v

/-- Bundled invariant for pure-`.pt` programs (`0` `.dep` queries, at most `n` `.pt` queries). -/
def PurePt (p : PProg Q D α) (n : ℕ) : Prop :=
  p.PtLE n ∧ p.QLE n ∧ DepStrict p ∧ ∀ S, p.DepIn S

theorem PurePt.ret (a : α) : PurePt (Q := Q) (D := D) (.ret a) 0 :=
  ⟨trivial, trivial, DepStrict.ret a, fun _ => trivial⟩

theorem PurePt.pt (z : Q) (k : D → PProg Q D α) {n : ℕ} (hk : ∀ d, PurePt (k d) n) :
    PurePt (.pt z k) (n + 1) :=
  ⟨⟨Nat.zero_lt_succ n, fun d => ptLE_mono _ (hk d).1 (by omega)⟩,
   ⟨Nat.zero_lt_succ n, fun d => qLE_mono _ (hk d).2.1 (by omega)⟩,
   DepStrict.pt z k (fun d => (hk d).2.2.1),
   fun S d => (hk d).2.2.2 S⟩

theorem PurePt.mono {p : PProg Q D α} {m n : ℕ} (hp : PurePt p m) (hmn : m ≤ n) : PurePt p n :=
  ⟨ptLE_mono p hp.1 hmn, qLE_mono p hp.2.1 hmn, hp.2.2.1, hp.2.2.2⟩

theorem PurePt.andThen {p : PProg Q D α} {f : α → PProg Q D β} {m n : ℕ}
    (hp : PurePt p m) (hf : ∀ a, PurePt (f a) n) : PurePt (p.andThen f) (m + n) :=
  ⟨ptLE_andThen p f hp.1 (fun a => (hf a).1),
   qLE_andThen p f hp.2.1 (fun a => (hf a).2.1),
   hp.2.2.1.andThen (fun a => (hf a).2.2.1),
   fun S => depIn_andThen p f (hp.2.2.2 S) (fun a => (hf a).2.2.2 S)⟩

theorem PurePt.depAbsorbed {p : PProg Q D α} {n : ℕ} (hp : PurePt p n) : DepAbsorbed p :=
  hp.2.2.1.toDepAbsorbed

end PProgLib

section MerkleTreeProg

/-- Cached Merkle tree levels for depth `d` (`2^d` leaves), allowing `0`-query root and path extraction. -/
inductive MerkleLevels : ℕ → Type where
  | root : Dig → MerkleLevels 0
  | layer {d : ℕ} : (Fin (2 ^ (d + 1)) → Dig) → MerkleLevels d → MerkleLevels (d + 1)

def MerkleLevels.getRoot : {d : ℕ} → MerkleLevels d → Dig
  | 0, .root r => r
  | _ + 1, .layer _ up => up.getRoot

private def sibIdx (j : ℕ) : ℕ := if j % 2 = 0 then j + 1 else j - 1

private theorem sibIdx_lt {d j : ℕ} (hj : j < 2 ^ (d + 1)) : sibIdx j < 2 ^ (d + 1) := by
  have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
  unfold sibIdx
  by_cases hpar : j % 2 = 0
  · rw [ite_eq_left hpar]; omega
  · rw [ite_eq_right hpar]; omega

/-- Depth-`d` authentication path of leaf `j < 2^d` from cached levels (`0` oracle queries). -/
def MerkleLevels.path : {d : ℕ} → MerkleLevels d → (j : ℕ) → j < 2 ^ d → List Dig
  | 0, .root _, _, _ => []
  | d + 1, .layer lv up, j, hj =>
    lv ⟨sibIdx j, sibIdx_lt hj⟩ :: up.path (j / 2) (by have : 2 ^ (d + 1) = 2 * 2 ^ d := by ring; omega)

/-- Total authentication-path lookup (`0` oracle queries). -/
def MerkleLevels.pathD {d : ℕ} (tr : MerkleLevels d) (j : ℕ) : List Dig :=
  if hj : j < 2 ^ d then tr.path j hj else []

/-- Emit `n` leaves as `.dep colQ → .pt leafQ`, returning the `n` salted leaf digests. -/
def leafLayerAux (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
      (saltOf : Fin n → Dig), PProg (QB Lq) Dig (Fin n → Dig)
  | 0, _, _, _ => .ret (fun _ => zeroDig)
  | n + 1, colOf, hcol, saltOf =>
    .dep (tag.col, ⟨colOf 0, hcol 0⟩) fun cd =>
      .pt (tag.leaf, ⟨cd.toList ++ (saltOf 0).toList, by rw [digPair_length]; exact h64⟩) fun ld =>
        (leafLayerAux Lq h64 tag n (fun j => colOf j.succ) (fun j => hcol j.succ) (fun j => saltOf j.succ)).andThen
          fun rest => .ret (Fin.cons ld rest : Fin (n + 1) → Dig)

theorem leafLayerAux_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin n → Dig) (j : Fin n),
      (leafLayerAux Lq h64 tag n colOf hcol saltOf).run G j =
        saltLeaf (liftH G) tag (liftH G ⟨tag.col, colOf j⟩) (saltOf j)
  | 0, _, _, _, j => by have hf : False := Nat.not_lt_zero j.val j.isLt; cases hf
  | n + 1, colOf, hcol, saltOf, j => by
    unfold leafLayerAux
    rw [run_dep, run_pt, PProg.run_andThen, run_ret]
    refine Fin.cases ?_ (fun k => ?_) j
    · simp only [Fin.cons_zero]
      have hleaf : G (tag.leaf, ⟨(G (tag.col, ⟨colOf 0, hcol 0⟩)).toList ++ (saltOf 0).toList,
            by rw [digPair_length]; exact h64⟩) =
          saltLeaf (liftH G) tag (G (tag.col, ⟨colOf 0, hcol 0⟩)) (saltOf 0) :=
        (liftH_eq G tag.leaf _ (by rw [digPair_length]; exact h64)).symm
      rw [hleaf, ← liftH_eq G tag.col (colOf 0) (hcol 0)]
    · simp only [Fin.cons_succ]
      exact leafLayerAux_run Lq h64 tag G n (fun i => colOf i.succ) (fun i => hcol i.succ) (fun i => saltOf i.succ) k

private theorem leafLayerAux_spec (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin n → Dig),
      let p := leafLayerAux Lq h64 tag n colOf hcol saltOf
      p.PtLE n ∧ p.QLE (n + n) ∧ DepStrict p ∧ p.DepIn {q : QB Lq | q.1 = tag.col}
  | 0, _, _, _ => ⟨trivial, trivial, DepStrict.ret _, trivial⟩
  | n + 1, colOf, hcol, saltOf => by
    have ih := leafLayerAux_spec Lq h64 tag n (fun j => colOf j.succ) (fun j => hcol j.succ) (fun j => saltOf j.succ)
    exact ⟨fun _ => ⟨Nat.zero_lt_succ n, fun _ => ptLE_mono _ (ptLE_andThen _ _ (n := 0) ih.1 (fun _ => trivial)) (by omega)⟩,
      ⟨by omega, fun _ => ⟨by omega, fun _ => qLE_mono _ (qLE_andThen _ _ (n := 0) ih.2.1 (fun _ => trivial)) (by omega)⟩⟩,
      DepStrict.depPt _ _ _ (fun _ => ih.2.2.1.andThen (fun _ => DepStrict.ret _)),
      ⟨rfl, fun _ _ => depIn_andThen _ _ ih.2.2.2 (fun _ => trivial)⟩⟩

private theorem leafLayerAux_depIn_col8 (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (n : ℕ) (colOf : Fin n → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
      (h8 : ∀ j, (colOf j).length % 8 = 0) (saltOf : Fin n → Dig),
      (leafLayerAux Lq h64 tag n colOf hcol saltOf).DepIn {q : QB Lq | q.1 = tag.col ∧ q.2.1.length % 8 = 0}
  | 0, _, _, _, _ => trivial
  | n + 1, colOf, hcol, h8, saltOf =>
    ⟨⟨rfl, h8 0⟩, fun _ _ => depIn_andThen _ _
      (leafLayerAux_depIn_col8 Lq h64 tag n _ _ (fun j => h8 j.succ) _) (fun _ => trivial)⟩

/-- Emit `m` internal `hashPair` `.pt` queries on sibling pairs `(leftOf i, rightOf i)`. -/
def nodeLayerAux (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig), PProg (QB Lq) Dig (Fin m → Dig)
  | 0, _, _ => .ret (fun _ => zeroDig)
  | m + 1, leftOf, rightOf =>
    .pt (tag.node, ⟨(leftOf 0).toList ++ (rightOf 0).toList, by rw [digPair_length]; exact h64⟩) fun nd =>
      (nodeLayerAux Lq h64 tag m (fun i => leftOf i.succ) (fun i => rightOf i.succ)).andThen fun rest =>
        .ret (Fin.cons nd rest : Fin (m + 1) → Dig)

theorem nodeLayerAux_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (G : QB Lq → Dig) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig) (i : Fin m),
      (nodeLayerAux Lq h64 tag m leftOf rightOf).run G i = hashPair (liftH G) tag (leftOf i) (rightOf i)
  | 0, _, _, i => by have hf : False := Nat.not_lt_zero i.val i.isLt; cases hf
  | m + 1, leftOf, rightOf, i => by
    unfold nodeLayerAux
    rw [run_pt, PProg.run_andThen, run_ret]
    refine Fin.cases ?_ (fun k => ?_) i
    · simp only [Fin.cons_zero]
      exact (liftH_eq G tag.node _ (by rw [digPair_length]; exact h64)).symm
    · simp only [Fin.cons_succ]
      exact nodeLayerAux_run Lq h64 tag G m (fun j => leftOf j.succ) (fun j => rightOf j.succ) k

theorem nodeLayerAux_purePt (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (m : ℕ) (leftOf rightOf : Fin m → Dig), PurePt (nodeLayerAux Lq h64 tag m leftOf rightOf) m
  | 0, _, _ => PurePt.ret _
  | m + 1, leftOf, rightOf =>
    PurePt.pt _ _ fun _ =>
      ((nodeLayerAux_purePt Lq h64 tag m _ _).andThen fun _ => PurePt.ret _).mono (by omega)

/-- Bottom-up Merkle tree construction from `2^d` leaf digests (`2^d - 1` internal `.pt` queries). -/
def buildLevelsProg (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (d : ℕ) (lv : Fin (2 ^ d) → Dig), PProg (QB Lq) Dig (MerkleLevels d)
  | 0, lv => .ret (.root (lv ⟨0, by norm_num⟩))
  | d + 1, lv =>
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    let leftOf : Fin (2 ^ d) → Dig := fun i => lv ⟨2 * i.val, by have hi := i.isLt; omega⟩
    let rightOf : Fin (2 ^ d) → Dig := fun i => lv ⟨2 * i.val + 1, by have hi := i.isLt; omega⟩
    (nodeLayerAux Lq h64 tag (2 ^ d) leftOf rightOf).andThen fun parent =>
      (buildLevelsProg Lq h64 tag d parent).andThen fun up => .ret (.layer lv up)

theorem buildLevelsProg_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (G : QB Lq → Dig) :
    ∀ (d : ℕ) (lv : Fin (2 ^ d) → Dig) (v : ℕ → Dig),
      (∀ (j : ℕ) (hj : j < 2 ^ d), lv ⟨j, hj⟩ = v j) →
      ((buildLevelsProg Lq h64 tag d lv).run G).getRoot =
          ZK60.Complete.treeRoot (merkleEnc tag) (liftH G) d v
        ∧ ∀ (j : ℕ) (hj : j < 2 ^ d),
          ((buildLevelsProg Lq h64 tag d lv).run G).path j hj =
            ZK60.Complete.treePath (merkleEnc tag) (liftH G) d v j
  | 0, _, _, hv => ⟨hv 0 (by norm_num), fun _ _ => rfl⟩
  | d + 1, lv, v, hv => by
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    let leftOf : Fin (2 ^ d) → Dig := fun i => lv ⟨2 * i.val, by have hi := i.isLt; omega⟩
    let rightOf : Fin (2 ^ d) → Dig := fun i => lv ⟨2 * i.val + 1, by have hi := i.isLt; omega⟩
    let parent : Fin (2 ^ d) → Dig := (nodeLayerAux Lq h64 tag (2 ^ d) leftOf rightOf).run G
    let v' : ℕ → Dig := fun i => liftH G ((merkleEnc tag).nodeQ (v (2 * i)) (v (2 * i + 1)))
    have hpar : ∀ (i : ℕ) (hi : i < 2 ^ d), parent ⟨i, hi⟩ = v' i := by
      intro i hi
      change (nodeLayerAux Lq h64 tag (2 ^ d) leftOf rightOf).run G ⟨i, hi⟩ = _
      rw [nodeLayerAux_run]
      show hashPair (liftH G) tag (lv ⟨2 * i, _⟩) (lv ⟨2 * i + 1, _⟩) = _
      rw [hv (2 * i) (by omega), hv (2 * i + 1) (by omega)]; rfl
    have ih := buildLevelsProg_run Lq h64 tag G d parent v' hpar
    have hrun : (buildLevelsProg Lq h64 tag (d + 1) lv).run G =
        .layer lv ((buildLevelsProg Lq h64 tag d parent).run G) := by
      unfold buildLevelsProg; rw [PProg.run_andThen, PProg.run_andThen, run_ret]
    rw [hrun]
    refine ⟨ih.1, fun j hj => ?_⟩
    show lv ⟨sibIdx j, sibIdx_lt hj⟩ :: ((buildLevelsProg Lq h64 tag d parent).run G).path (j / 2) _ =
      (if j % 2 = 0 then v (j + 1) else v (j - 1)) ::
        ZK60.Complete.treePath (merkleEnc tag) (liftH G) d v' (j / 2)
    refine congrArg₂ List.cons ?_ (ih.2 (j / 2) (by omega))
    rw [hv (sibIdx j) (sibIdx_lt hj), sibIdx]
    by_cases hparj : j % 2 = 0
    · rw [ite_eq_left hparj, ite_eq_left hparj]
    · rw [ite_eq_right hparj, ite_eq_right hparj]

theorem buildLevelsProg_purePt (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) :
    ∀ (d : ℕ) (lv : Fin (2 ^ d) → Dig), PurePt (buildLevelsProg Lq h64 tag d lv) (2 ^ d - 1)
  | 0, _ => PurePt.ret _
  | d + 1, _ => by
    unfold buildLevelsProg
    refine ((nodeLayerAux_purePt Lq h64 tag (2 ^ d) _ _).andThen fun parent =>
      (buildLevelsProg_purePt Lq h64 tag d parent).andThen fun _ => PurePt.ret _).mono ?_
    have h1 : 1 ≤ 2 ^ d := Nat.one_le_two_pow
    have hpow : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    omega

/-- **Bottom-up Merkle tree `PProg`**: emits each of the `2^d` leaves as `.dep colQ → .pt leafQ`, then the
`2^d - 1` internal `nodeHash` queries bottom-up as `.pt nodeQ`, returning cached `MerkleLevels d`. -/
def merkleTreeProg (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
    (saltOf : Fin (2 ^ d) → Dig) : PProg (QB Lq) Dig (MerkleLevels d) :=
  (leafLayerAux Lq h64 tag (2 ^ d) colOf hcol saltOf).andThen (buildLevelsProg Lq h64 tag d)

theorem merkleTreeProg_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (T : Table) (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
    (saltOf : Fin (2 ^ d) → Dig)
    (hcolEq : ∀ j : Fin (2 ^ d), colOf j = colBytes (T.cols j.val))
    (hsaltEq : ∀ j : Fin (2 ^ d), saltOf j = T.salts j.val) (G : QB Lq → Dig) :
    ((merkleTreeProg Lq h64 tag d colOf hcol saltOf).run G).getRoot = rootOf (liftH G) tag d T
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ d),
        ((merkleTreeProg Lq h64 tag d colOf hcol saltOf).run G).path j hj = pathOf (liftH G) tag d T j := by
  unfold merkleTreeProg
  rw [PProg.run_andThen]
  exact buildLevelsProg_run Lq h64 tag G d _ (leafAt (liftH G) tag T) (fun j hj => by
    rw [leafLayerAux_run, hcolEq ⟨j, hj⟩, hsaltEq ⟨j, hj⟩]; rfl)

theorem merkleTreeProg_ptLE (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).PtLE (2 ^ d + (2 ^ d - 1)) :=
  ptLE_andThen _ _ (leafLayerAux_spec Lq h64 tag (2 ^ d) colOf hcol saltOf).1
    (fun lv => (buildLevelsProg_purePt Lq h64 tag d lv).1)

theorem merkleTreeProg_qLE (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).QLE (2 ^ d + 2 ^ d + (2 ^ d - 1)) :=
  qLE_andThen _ _ (leafLayerAux_spec Lq h64 tag (2 ^ d) colOf hcol saltOf).2.1
    (fun lv => (buildLevelsProg_purePt Lq h64 tag d lv).2.1)

theorem merkleTreeProg_depStrict (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig) :
    DepStrict (merkleTreeProg Lq h64 tag d colOf hcol saltOf) :=
  (leafLayerAux_spec Lq h64 tag (2 ^ d) colOf hcol saltOf).2.2.1.andThen
    (fun lv => (buildLevelsProg_purePt Lq h64 tag d lv).2.2.1)

theorem merkleTreeProg_depAbsorbed (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig) :
    DepAbsorbed (merkleTreeProg Lq h64 tag d colOf hcol saltOf) :=
  (merkleTreeProg_depStrict Lq h64 tag d colOf hcol saltOf).toDepAbsorbed

theorem merkleTreeProg_depIn (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).DepIn {q : QB Lq | q.1 = tag.col} :=
  depIn_andThen _ _ (leafLayerAux_spec Lq h64 tag (2 ^ d) colOf hcol saltOf).2.2.2
    (fun lv => (buildLevelsProg_purePt Lq h64 tag d lv).2.2.2 _)

theorem merkleTreeProg_depIn_col8 (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
    (h8 : ∀ j, (colOf j).length % 8 = 0) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).DepIn
      {q : QB Lq | q.1 = tag.col ∧ q.2.1.length % 8 = 0} :=
  depIn_andThen _ _ (leafLayerAux_depIn_col8 Lq h64 tag (2 ^ d) colOf hcol h8 saltOf)
    (fun lv => (buildLevelsProg_purePt Lq h64 tag d lv).2.2.2 _)

/-- Convenience specialization of `merkleTreeProg` to an `HonestOpen.Table` of `rows`-entry columns. -/
def merkleTableProg (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) : PProg (QB Lq) Dig (MerkleLevels d) :=
  merkleTreeProg Lq h64 tag d (fun j => colBytes (T.cols j.val))
    (fun j => by rw [colBytes_length, hT j]; exact hrows) (fun j => T.salts j.val)

theorem merkleTableProg_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) (G : QB Lq → Dig) :
    ((merkleTableProg Lq h64 tag d rows hrows T hT).run G).getRoot = rootOf (liftH G) tag d T
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ d),
        ((merkleTableProg Lq h64 tag d rows hrows T hT).run G).path j hj = pathOf (liftH G) tag d T j :=
  merkleTreeProg_run Lq h64 tag d T _ _ _ (fun _ => rfl) (fun _ => rfl) G

theorem merkleTableProg_ptLE (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) :
    (merkleTableProg Lq h64 tag d rows hrows T hT).PtLE (2 ^ d + (2 ^ d - 1)) :=
  merkleTreeProg_ptLE Lq h64 tag d _ _ _

theorem merkleTableProg_qLE (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) :
    (merkleTableProg Lq h64 tag d rows hrows T hT).QLE (2 ^ d + 2 ^ d + (2 ^ d - 1)) :=
  merkleTreeProg_qLE Lq h64 tag d _ _ _

theorem merkleTableProg_depAbsorbed (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) :
    DepAbsorbed (merkleTableProg Lq h64 tag d rows hrows T hT) :=
  merkleTreeProg_depAbsorbed Lq h64 tag d _ _ _

theorem merkleTableProg_depIn_col8 (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows) :
    (merkleTableProg Lq h64 tag d rows hrows T hT).DepIn
      {q : QB Lq | q.1 = tag.col ∧ q.2.1.length % 8 = 0} :=
  merkleTreeProg_depIn_col8 Lq h64 tag d _ _ (fun j => by rw [colBytes_length]; omega) _

theorem merkleMaskTableProg_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (S : ℕ)
    (hrows : 8 * (2 * S + 4) ≤ Lq) (M : MTable) (G : QB Lq → Dig) :
    let T := mTab S (cosetPt (rootFp 12)) M
    let hT : ∀ j : Fin (2 ^ 12), (T.cols j.val).length = 2 * S + 4 := fun j => mCol_length S _ M j.val
    ((merkleTableProg Lq h64 tag 12 (2 * S + 4) hrows T hT).run G).getRoot = rootOf (liftH G) tag 12 T
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ 12),
        ((merkleTableProg Lq h64 tag 12 (2 * S + 4) hrows T hT).run G).path j hj = pathOf (liftH G) tag 12 T j :=
  merkleTableProg_run Lq h64 tag 12 (2 * S + 4) hrows (mTab S (cosetPt (rootFp 12)) M)
    (fun j => mCol_length S _ M j.val) G

end MerkleTreeProg

/-! ## 3. Deduplicated transcript, `posTag`, opening-audit, `bOpen`, `bMask`, and run-header `PProg`s -/

section OpeningCombinators

/-! ### Basic transcript `.pt` combinators and cached `posTag` -/

def trAbsorbProg (Lq : ℕ) (t : Tr) (label data : List UInt8) : PProg (QB Lq) Dig Tr :=
  if h : (absorbMsg t.state label data).length ≤ Lq then
    .pt (t.key, ⟨absorbMsg t.state label data, h⟩) fun dg => .ret { t with state := dg }
  else .ret { t with state := zeroDig }

theorem trAbsorbProg_run (Lq : ℕ) (t : Tr) (label data : List UInt8) (G : QB Lq → Dig) :
    (trAbsorbProg Lq t label data).run G = t.absorb (liftH G) label data := by
  unfold trAbsorbProg Tr.absorb liftH
  by_cases h : (absorbMsg t.state label data).length ≤ Lq
  · rw [dite_eq_left h, dite_eq_left h, run_pt, run_ret]
  · rw [dite_eq_right h, dite_eq_right h, run_ret]

theorem trAbsorbProg_purePt (Lq : ℕ) (t : Tr) (label data : List UInt8) :
    PurePt (trAbsorbProg Lq t label data) 1 := by
  unfold trAbsorbProg
  by_cases h : (absorbMsg t.state label data).length ≤ Lq
  · rw [dite_eq_left h]; exact PurePt.pt _ _ (fun _ => PurePt.ret _)
  · rw [dite_eq_right h]; exact (PurePt.ret _).mono (Nat.zero_le 1)

theorem trAbsorbProg_ptLE (Lq : ℕ) (t : Tr) (l d : List UInt8) : (trAbsorbProg Lq t l d).PtLE 1 :=
  (trAbsorbProg_purePt Lq t l d).1
theorem trAbsorbProg_qLE (Lq : ℕ) (t : Tr) (l d : List UInt8) : (trAbsorbProg Lq t l d).QLE 1 :=
  (trAbsorbProg_purePt Lq t l d).2.1
theorem trAbsorbProg_depAbsorbed (Lq : ℕ) (t : Tr) (l d : List UInt8) : DepAbsorbed (trAbsorbProg Lq t l d) :=
  (trAbsorbProg_purePt Lq t l d).depAbsorbed

def trAbsorbFp2Prog (Lq : ℕ) (t : Tr) (label : List UInt8) (vals : List Fp2) : PProg (QB Lq) Dig Tr :=
  trAbsorbProg Lq t label (vals.flatMap Fp2.toBytes)

theorem trAbsorbFp2Prog_run (Lq : ℕ) (t : Tr) (label : List UInt8) (vals : List Fp2) (G : QB Lq → Dig) :
    (trAbsorbFp2Prog Lq t label vals).run G = t.absorbFp2 (liftH G) label vals :=
  trAbsorbProg_run Lq t label (vals.flatMap Fp2.toBytes) G

def trAbsorbVecsProg (Lq : ℕ) : List (List Fp2) → Tr → PProg (QB Lq) Dig Tr
  | [], t => .ret t
  | v :: vs, t => (trAbsorbFp2Prog Lq t pcsVecLabel v).andThen (trAbsorbVecsProg Lq vs)

theorem trAbsorbVecsProg_run (Lq : ℕ) (G : QB Lq → Dig) :
    ∀ (vs : List (List Fp2)) (t : Tr), (trAbsorbVecsProg Lq vs t).run G = absorbVecs (liftH G) vs t
  | [], _ => rfl
  | v :: vs, t => by
    unfold trAbsorbVecsProg; rw [PProg.run_andThen, trAbsorbFp2Prog_run]; exact trAbsorbVecsProg_run Lq G vs _

theorem trAbsorbVecsProg_purePt (Lq : ℕ) :
    ∀ (vs : List (List Fp2)) (t : Tr), PurePt (trAbsorbVecsProg Lq vs t) vs.length
  | [], _ => PurePt.ret _
  | v :: vs, t =>
    ((trAbsorbProg_purePt Lq t _ _).andThen fun t' => trAbsorbVecsProg_purePt Lq vs t').mono
      (by simp only [List.length_cons]; omega)

def trSqueezeProg (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : PProg (QB Lq) Dig (Dig × Tr) :=
  .pt (t.key, ⟨squeezeMsg t.state t.counter, by rw [squeezeMsg_length]; exact h47⟩) fun dg =>
    .ret (dg, { t with state := dg, counter := t.counter + 1 })

theorem trSqueezeProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) (G : QB Lq → Dig) :
    (trSqueezeProg Lq h47 t).run G = t.squeeze (liftH G) := by
  unfold trSqueezeProg Tr.squeeze
  rw [run_pt, run_ret, liftH_eq G t.key _ (by rw [squeezeMsg_length]; exact h47)]

theorem trSqueezeProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : PurePt (trSqueezeProg Lq h47 t) 1 :=
  PurePt.pt _ _ (fun _ => PurePt.ret _)

def trChallengeFp2Prog (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : PProg (QB Lq) Dig (Fp2 × Tr) :=
  (trSqueezeProg Lq h47 t).andThen fun r => .ret (challengeFp2Of r.1, r.2)

theorem trChallengeFp2Prog_run (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) (G : QB Lq → Dig) :
    (trChallengeFp2Prog Lq h47 t).run G = t.challengeFp2 (liftH G) := by
  unfold trChallengeFp2Prog Tr.challengeFp2
  rw [PProg.run_andThen, trSqueezeProg_run, run_ret]

theorem trChallengeFp2Prog_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : PurePt (trChallengeFp2Prog Lq h47 t) 1 :=
  ((trSqueezeProg_purePt Lq h47 t).andThen fun _ => PurePt.ret _).mono (by omega)

theorem trChallengeFp2Prog_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : (trChallengeFp2Prog Lq h47 t).PtLE 1 :=
  (trChallengeFp2Prog_purePt Lq h47 t).1
theorem trChallengeFp2Prog_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : (trChallengeFp2Prog Lq h47 t).QLE 1 :=
  (trChallengeFp2Prog_purePt Lq h47 t).2.1
theorem trChallengeFp2Prog_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) :
    DepAbsorbed (trChallengeFp2Prog Lq h47 t) :=
  (trChallengeFp2Prog_purePt Lq h47 t).depAbsorbed

def trSqueezeVecProg (Lq : ℕ) (h47 : 47 ≤ Lq) : ℕ → Tr → PProg (QB Lq) Dig (List Dig × Tr)
  | 0, t => .ret ([], t)
  | n + 1, t =>
    (trSqueezeProg Lq h47 t).andThen fun r =>
      (trSqueezeVecProg Lq h47 n r.2).andThen fun rs => .ret (r.1 :: rs.1, rs.2)

theorem trSqueezeVecProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (t : Tr),
      (trSqueezeVecProg Lq h47 n t).run G = (sqDs (liftH G) t n, runOps (liftH G) t (List.replicate n Op.squeeze))
  | 0, _ => rfl
  | n + 1, t => by
    unfold trSqueezeVecProg
    rw [PProg.run_andThen, trSqueezeProg_run, PProg.run_andThen, trSqueezeVecProg_run Lq h47 G n, run_ret,
      sqDs_succ, List.replicate_succ, runOps]

theorem trSqueezeVecProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) :
    ∀ (n : ℕ) (t : Tr), PurePt (trSqueezeVecProg Lq h47 n t) n
  | 0, _ => PurePt.ret _
  | n + 1, t =>
    ((trSqueezeProg_purePt Lq h47 t).andThen fun r =>
      (trSqueezeVecProg_purePt Lq h47 n r.2).andThen fun _ => PurePt.ret _).mono (by omega)

def trChallengeFp2VecProg (Lq : ℕ) (h47 : 47 ≤ Lq) : ℕ → Tr → PProg (QB Lq) Dig (List Fp2 × Tr)
  | 0, t => .ret ([], t)
  | n + 1, t =>
    (trChallengeFp2Prog Lq h47 t).andThen fun r =>
      (trChallengeFp2VecProg Lq h47 n r.2).andThen fun rs => .ret (r.1 :: rs.1, rs.2)

theorem trChallengeFp2VecProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (t : Tr), (trChallengeFp2VecProg Lq h47 n t).run G = t.challengeFp2Vec (liftH G) n
  | 0, _ => rfl
  | n + 1, t => by
    unfold trChallengeFp2VecProg
    rw [PProg.run_andThen, trChallengeFp2Prog_run, PProg.run_andThen,
      trChallengeFp2VecProg_run Lq h47 G n, run_ret]
    rfl

theorem trChallengeFp2VecProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) :
    ∀ (n : ℕ) (t : Tr), PurePt (trChallengeFp2VecProg Lq h47 n t) n
  | 0, _ => PurePt.ret _
  | n + 1, t =>
    ((trChallengeFp2Prog_purePt Lq h47 t).andThen fun r =>
      (trChallengeFp2VecProg_purePt Lq h47 n r.2).andThen fun _ => PurePt.ret _).mono (by omega)

theorem trChallengeFp2VecProg_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) (n : ℕ) (t : Tr) :
    (trChallengeFp2VecProg Lq h47 n t).PtLE n := (trChallengeFp2VecProg_purePt Lq h47 n t).1
theorem trChallengeFp2VecProg_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) (n : ℕ) (t : Tr) :
    (trChallengeFp2VecProg Lq h47 n t).QLE n := (trChallengeFp2VecProg_purePt Lq h47 n t).2.1
theorem trChallengeFp2VecProg_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) (n : ℕ) (t : Tr) :
    DepAbsorbed (trChallengeFp2VecProg Lq h47 n t) := (trChallengeFp2VecProg_purePt Lq h47 n t).depAbsorbed

/-- Cached `Exec.Block.posTag` (`2` `.pt` queries per segment boundary, `29 * 2 = 58` total). -/
def posTagProg (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : PProg (QB Lq) Dig Dig :=
  (trChallengeFp2Prog Lq h47 t).andThen fun a =>
    (trChallengeFp2Prog Lq h47 a.2).andThen fun b =>
      .ret ⟨a.1.toBytes ++ b.1.toBytes, by simp [Exec.Block.fp2_toBytes_length]⟩

theorem posTagProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) (G : QB Lq → Dig) :
    (posTagProg Lq h47 t).run G = Exec.Block.posTag (liftH G) t := by
  unfold posTagProg Exec.Block.posTag
  rw [PProg.run_andThen, trChallengeFp2Prog_run, PProg.run_andThen, trChallengeFp2Prog_run, run_ret]

theorem posTagProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : PurePt (posTagProg Lq h47 t) 2 :=
  ((trChallengeFp2Prog_purePt Lq h47 t).andThen fun a =>
    (trChallengeFp2Prog_purePt Lq h47 a.2).andThen fun _ => PurePt.ret _).mono (by omega)

theorem posTagProg_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : (posTagProg Lq h47 t).PtLE 2 :=
  (posTagProg_purePt Lq h47 t).1
theorem posTagProg_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : (posTagProg Lq h47 t).QLE 2 :=
  (posTagProg_purePt Lq h47 t).2.1
theorem posTagProg_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) (t : Tr) : DepAbsorbed (posTagProg Lq h47 t) :=
  (posTagProg_purePt Lq h47 t).depAbsorbed

/-! ### Deduplicated `checkOpeningExec` + `bOpen` and `bMask` combinators -/

private theorem chalVec_add (H : HIn → Dig) :
    ∀ (a b : ℕ) (t : Tr),
      t.challengeFp2Vec H (a + b) =
        ((t.challengeFp2Vec H a).1 ++ ((t.challengeFp2Vec H a).2.challengeFp2Vec H b).1,
         ((t.challengeFp2Vec H a).2.challengeFp2Vec H b).2)
  | 0, _, _ => by rw [Nat.zero_add]; rfl
  | a + 1, b, t => by
    rw [Nat.succ_add]
    change ((t.challengeFp2 H).1 :: ((t.challengeFp2 H).2.challengeFp2Vec H (a + b)).1,
        ((t.challengeFp2 H).2.challengeFp2Vec H (a + b)).2) =
      (((t.challengeFp2 H).1 :: ((t.challengeFp2 H).2.challengeFp2Vec H a).1) ++
          (((t.challengeFp2 H).2.challengeFp2Vec H a).2.challengeFp2Vec H b).1,
        (((t.challengeFp2 H).2.challengeFp2Vec H a).2.challengeFp2Vec H b).2)
    rw [chalVec_add H a b (t.challengeFp2 H).2, List.cons_append]

private def zkToKey (k : List Fp2 × ℕ × ℕ) : ZKey := ⟨k.1, k.2.1, k.2.2⟩

private theorem zkToKey_injective : Function.Injective zkToKey := by
  rintro ⟨a₁, b₁, c₁⟩ ⟨a₂, b₂, c₂⟩ h
  simp only [zkToKey, ZKey.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h; rfl

private theorem partKeyAt_eq_zkToKey (p : Exec.Block.ZPart) (rows logN : ℕ) :
    (zpartWeights (toZPart p) rows logN).2 = zkToKey (partKeyAt p logN) := by
  unfold zpartWeights partKeyAt toZPart zkToKey; dsimp only
  by_cases hemp : p.point.isEmpty = true <;> by_cases hle : logN ≤ p.logSize
  · simp [hemp, hle]
  · simp [hemp, hle]
  · simp [hemp, hle]
  · have hsub : p.logSize - logN = 0 := by omega
    simp [hemp, hle, hsub]

private theorem bumpKey_not_mem (key : List Fp2 × ℕ × ℕ) :
    ∀ (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)), key ∉ gs.map Prod.fst → bumpKey key gs = gs ++ [(key, 1)]
  | [], _ => rfl
  | (k, c) :: rest, h => by
    have hne : k ≠ key := fun heq => h (List.mem_cons.mpr (Or.inl heq.symm))
    have hrest : key ∉ rest.map Prod.fst := fun hm => h (List.mem_cons.mpr (Or.inr hm))
    rw [bumpKey, ite_eq_right hne, bumpKey_not_mem key rest hrest]; rfl

private theorem bumpKey_map_fst_mem (key : List Fp2 × ℕ × ℕ) :
    ∀ (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)), key ∈ gs.map Prod.fst → (bumpKey key gs).map Prod.fst = gs.map Prod.fst
  | [], h => by cases h
  | (k, c) :: rest, h => by
    by_cases hk : k = key
    · rw [bumpKey, ite_eq_left hk]; rfl
    · have hrest : key ∈ rest.map Prod.fst := by
        rcases List.mem_cons.mp h with heq | hm
        · have hf : False := hk heq.symm; cases hf
        · exact hm
      rw [bumpKey, ite_eq_right hk, List.map_cons, List.map_cons, bumpKey_map_fst_mem key rest hrest]

private theorem bumpKey_pushAt_counts {α β : Type} (key : List Fp2 × ℕ × ℕ) (m : β) :
    ∀ (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)) (l : List (α × List β)) (gi : ℕ),
      gs.map Prod.snd = l.map (fun g => g.2.length) →
      (gs.map (fun x => zkToKey x.1)).findIdx? (fun k' => decide (k' = zkToKey key)) = some gi →
      (bumpKey key gs).map Prod.snd = (pushAt l gi m).map (fun g => g.2.length)
  | [], _, _, _, hfi => by simp only [List.map_nil, List.findIdx?_nil] at hfi; cases hfi
  | _ :: _, [], _, hcnt, _ => by simp only [List.map_cons, List.map_nil] at hcnt; cases hcnt
  | (k, c) :: rest, x :: xs, gi, hcnt, hfi => by
    simp only [List.map_cons, List.cons.injEq] at hcnt
    obtain ⟨hc, hrest⟩ := hcnt
    rw [List.map_cons, List.findIdx?_cons] at hfi
    by_cases hk : k = key
    · have hp : decide (zkToKey k = zkToKey key) = true := decide_eq_true (congrArg zkToKey hk)
      rw [ite_eq_left hp] at hfi; cases hfi
      rw [bumpKey, ite_eq_left hk, pushAt, List.map_cons, List.map_cons, List.length_append,
        List.length_singleton, hc, hrest]
    · have hp : decide (zkToKey k = zkToKey key) = false := decide_eq_false (fun h => hk (zkToKey_injective h))
      rw [hp, ite_eq_right Bool.false_ne_true] at hfi
      cases hsub : (rest.map (fun x => zkToKey x.1)).findIdx? (fun k' => decide (k' = zkToKey key)) with
      | none => rw [hsub] at hfi; cases hfi
      | some gi' =>
        rw [hsub] at hfi; cases hfi
        rw [bumpKey, ite_eq_right hk, pushAt, List.map_cons, List.map_cons, hc,
          bumpKey_pushAt_counts key m rest xs gi' hrest hsub]

private theorem openingGroupsAt_foldl_counts_inv (rows logN : ℕ) :
    ∀ (cs : List Exec.Block.ZClaim) (gs gs' : List ((List Fp2 × ℕ × ℕ) × ℕ))
      (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))),
      (∀ c ∈ cs, c.parts ≠ []) →
      gs.map (fun x => zkToKey x.1) = st.1 →
      gs.map Prod.snd = st.2.map (fun g => g.2.length) →
      (cs.foldlM (m := Except String) (fun acc c =>
        let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
        if c.parts.any (fun p => partKeyAt p logN ≠ key) then
          throw "private block: claim parts with different column weights"
        else pure (bumpKey key acc)) gs) = Except.ok gs' →
      gs'.map Prod.snd = ((cs.map toZClaim).foldl (groupStep rows logN) st).2.map (fun g => g.2.length)
  | [], gs, gs', _, _, _, hcnt, h => by
    simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h; subst h; exact hcnt
  | c :: cs, gs, gs', st, hne, hmap, hcnt, h => by
    rw [List.foldlM_cons] at h; dsimp only at h
    split_ifs at h
    · simp [throw, throwThe, MonadExceptOf.throw, Bind.bind, Except.bind] at h
    · simp only [pure, Except.pure, Bind.bind, Except.bind] at h
      have hcne : c.parts ≠ [] := hne c List.mem_cons_self
      cases hp : c.parts with
      | nil => have hf : False := hcne hp; cases hf
      | cons p0 ps =>
        have hw2 : (claimWeights (toZClaim c) rows logN).2 =
            zkToKey (partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN) := by
          simp only [claimWeights, toZClaim, hp, List.map_cons, List.headD_cons]
          exact partKeyAt_eq_zkToKey p0 rows logN
        set key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
        have hstep : (bumpKey key gs).map (fun x => zkToKey x.1) = (groupStep rows logN st (toZClaim c)).1
            ∧ (bumpKey key gs).map Prod.snd = (groupStep rows logN st (toZClaim c)).2.map (fun g => g.2.length) := by
          unfold groupStep; dsimp only; rw [hw2]
          cases hki : keyIdx st.1 (zkToKey key) with
          | none =>
            have hnot : key ∉ gs.map Prod.fst := by
              intro hm; obtain ⟨x, hx, hxk⟩ := List.mem_map.mp hm
              have hmem1 : zkToKey key ∈ st.1 := by rw [← hmap, ← hxk]; exact List.mem_map.mpr ⟨x, hx, rfl⟩
              have hnone : decide (zkToKey key = zkToKey key) = false :=
                List.findIdx?_eq_none_iff.mp hki (zkToKey key) hmem1
              rw [decide_eq_true rfl] at hnone; cases hnone
            rw [bumpKey_not_mem key gs hnot]
            exact ⟨by rw [List.map_append, List.map_singleton, hmap],
              by rw [List.map_append, List.map_singleton, List.map_append, List.map_singleton,
                List.length_singleton, hcnt]⟩
          | some gi =>
            have hfi : (gs.map (fun x => zkToKey x.1)).findIdx? (fun k' => decide (k' = zkToKey key)) = some gi := by
              rw [hmap]; exact hki
            obtain ⟨hlt, hhit, _⟩ := List.findIdx?_eq_some_iff_getElem.mp hfi
            have hmem : key ∈ gs.map Prod.fst := by
              have hlt' : gi < gs.length := by rw [List.length_map] at hlt; exact hlt
              have hEq : zkToKey gs[gi].1 = zkToKey key := by
                have h0 := of_decide_eq_true hhit; rwa [List.getElem_map] at h0
              rw [← zkToKey_injective hEq]; exact List.mem_map.mpr ⟨gs[gi], List.getElem_mem hlt', rfl⟩
            refine ⟨?_, bumpKey_pushAt_counts key ((claimWeights (toZClaim c) rows logN).1, c.value) gs st.2 gi hcnt hfi⟩
            have hcomp : (bumpKey key gs).map (fun x => zkToKey x.1) = ((bumpKey key gs).map Prod.fst).map zkToKey := by
              rw [List.map_map]; rfl
            rw [hcomp, bumpKey_map_fst_mem key gs hmem, List.map_map]; exact hmap
        rw [List.map_cons, List.foldl_cons]
        exact openingGroupsAt_foldl_counts_inv rows logN cs (bumpKey key gs) gs'
          (groupStep rows logN st (toZClaim c))
          (fun c' hc' => hne c' (List.mem_cons_of_mem _ hc')) hstep.1 hstep.2 h

theorem openingGroupsAt_counts_eq_groupZclaims (claims : List Exec.Block.ZClaim) (rows logN : ℕ)
    (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)) (hne : ∀ c ∈ claims, c.parts ≠ [])
    (h : openingGroupsAt claims logN = .ok gs) :
    gs.map Prod.snd = (groupZclaims (claims.map toZClaim) rows logN).map (fun g => g.2.length) :=
  openingGroupsAt_foldl_counts_inv rows logN claims [] gs ([], []) hne rfl rfl h

/-- Single-pass `zkRhos` `PProg`: emits `(gs.map (·.2.length)).sum + rows` `.pt` squeezes ONCE and
returns `(rhos, wants, allLams, proxRho, t_after)`. -/
def zkRhosProg (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ) :
    List (List Fp2 × List (List Fp2 × Fp2)) → Tr →
      PProg (QB Lq) Dig (List (List Fp2) × List Fp2 × List Fp2 × List Fp2 × Tr)
  | [], t => (trChallengeFp2VecProg Lq h47 rows t).andThen fun r => .ret ([r.1], [], [], r.1, r.2)
  | g :: gs, t =>
    (trChallengeFp2VecProg Lq h47 g.2.length t).andThen fun l =>
      (zkRhosProg Lq h47 rows gs l.2).andThen fun rest =>
        let c := groupComb rows g.2 l.1
        .ret (c.1 :: rest.1, c.2 :: rest.2.1, l.1 ++ rest.2.2.1, rest.2.2.2.1, rest.2.2.2.2)

theorem zkRhosProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ) (G : QB Lq → Dig) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
      let r := (zkRhosProg Lq h47 rows gs t).run G
      let z := zkRhosAux (liftH G) rows gs t
      let n := (gs.map (fun g => g.2.length)).sum
      r.1 = z.1 ∧ r.2.1 = z.2.1 ∧ r.2.2.1 = (t.challengeFp2Vec (liftH G) n).1
        ∧ r.2.2.2.1 = ((t.challengeFp2Vec (liftH G) n).2.challengeFp2Vec (liftH G) rows).1
        ∧ r.2.2.2.2 = z.2.2
  | [], t => by
    dsimp only [zkRhosProg, zkRhosAux, List.map_nil, List.sum_nil]
    rw [PProg.run_andThen, trChallengeFp2VecProg_run, run_ret]
    exact ⟨rfl, rfl, rfl, rfl, rfl⟩
  | g :: gs, t => by
    dsimp only [zkRhosProg, zkRhosAux, List.map_cons, List.sum_cons]
    rw [PProg.run_andThen, trChallengeFp2VecProg_run, PProg.run_andThen]
    have ih := zkRhosProg_run Lq h47 rows G gs (t.challengeFp2Vec (liftH G) g.2.length).2
    dsimp only at ih; obtain ⟨h1, h2, h3, h4, h5⟩ := ih
    rw [run_ret]
    have hadd := chalVec_add (liftH G) g.2.length (gs.map (fun x => x.2.length)).sum t
    refine ⟨by dsimp only; rw [h1], by dsimp only; rw [h2],
      by dsimp only; rw [h3, hadd], by dsimp only; rw [h4, hadd], h5⟩

theorem zkRhosProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
      PurePt (zkRhosProg Lq h47 rows gs t) ((gs.map (fun g => g.2.length)).sum + rows)
  | [], t =>
    ((trChallengeFp2VecProg_purePt Lq h47 rows t).andThen fun _ => PurePt.ret _).mono
      (by simp only [List.map_nil, List.sum_nil]; omega)
  | g :: gs, t =>
    ((trChallengeFp2VecProg_purePt Lq h47 g.2.length t).andThen fun l =>
      (zkRhosProg_purePt Lq h47 rows gs l.2).andThen fun _ => PurePt.ret _).mono
      (by simp only [List.map_cons, List.sum_cons]; omega)

theorem zkRhosProg_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr) :
    (zkRhosProg Lq h47 rows gs t).PtLE ((gs.map (fun g => g.2.length)).sum + rows) :=
  (zkRhosProg_purePt Lq h47 rows gs t).1
theorem zkRhosProg_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr) :
    (zkRhosProg Lq h47 rows gs t).QLE ((gs.map (fun g => g.2.length)).sum + rows) :=
  (zkRhosProg_purePt Lq h47 rows gs t).2.1
theorem zkRhosProg_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) (rows : ℕ)
    (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr) :
    DepAbsorbed (zkRhosProg Lq h47 rows gs t) :=
  (zkRhosProg_purePt Lq h47 rows gs t).depAbsorbed

/-- Pure opening-challenge audit on already-drawn `zkRhos` vectors (`0` extra oracle queries). -/
def openingAuditOk (allLams proxRho : List Fp2) (rows prox : ℕ) : Bool :=
  !allLams.any Fp2.isZero
    && !decide (prox + 1 ≥ rows ∨ (Exec.Block.det (proxRho.getD prox Fp2.zero) (proxRho.getD (prox + 1) Fp2.zero)).v = 0)

private theorem groupDraws_ok_iff (H : HIn → Dig) : ∀ (n : ℕ) (t t' : Tr),
    Exec.Block.groupDraws H n t = .ok t'
      ↔ (t.challengeFp2Vec H n).1.any Fp2.isZero = false ∧ t' = (t.challengeFp2Vec H n).2
  | 0, t, t' => ⟨fun h => by have h' : (Except.ok t : Except String Tr) = .ok t' := h; cases h'; exact ⟨rfl, rfl⟩,
      fun ⟨_, ht⟩ => by subst ht; rfl⟩
  | n + 1, t, t' => by
    have heq : Exec.Block.groupDraws H (n + 1) t =
        if (t.challengeFp2 H).1.isZero then .error "zero group member coefficient; discard attempt"
        else Exec.Block.groupDraws H n (t.challengeFp2 H).2 := rfl
    have hvec1 : (t.challengeFp2Vec H (n + 1)).1 =
        (t.challengeFp2 H).1 :: ((t.challengeFp2 H).2.challengeFp2Vec H n).1 := rfl
    have hvec2 : (t.challengeFp2Vec H (n + 1)).2 = ((t.challengeFp2 H).2.challengeFp2Vec H n).2 := rfl
    rw [heq, hvec1, hvec2, List.any_cons]
    cases hz : (t.challengeFp2 H).1.isZero with
    | true => rw [ite_eq_left rfl, Bool.true_or]; exact ⟨fun h => by cases h, fun h => by cases h.1⟩
    | false => rw [ite_eq_right Bool.false_ne_true, Bool.false_or]; exact groupDraws_ok_iff H n (t.challengeFp2 H).2 t'

private theorem foldDraws_ok_iff (H : HIn → Dig) : ∀ (counts : List ℕ) (t t' : Tr),
    counts.foldlM (fun t c => Exec.Block.groupDraws H c t) t = .ok t'
      ↔ (t.challengeFp2Vec H counts.sum).1.any Fp2.isZero = false ∧ t' = (t.challengeFp2Vec H counts.sum).2
  | [], t, t' => ⟨fun h => by have h' : (Except.ok t : Except String Tr) = .ok t' := h; cases h'; exact ⟨rfl, rfl⟩,
      fun ⟨_, ht⟩ => by subst ht; rfl⟩
  | c :: cs, t, t' => by
    have hstep : (c :: cs).foldlM (fun t c => Exec.Block.groupDraws H c t) t =
        Exec.Block.groupDraws H c t >>= fun t1 => cs.foldlM (fun t c => Exec.Block.groupDraws H c t) t1 := rfl
    rw [hstep, List.sum_cons, chalVec_add H c cs.sum t, List.any_append]
    cases hg : Exec.Block.groupDraws H c t with
    | error e =>
      refine ⟨fun h => by have h' : (Except.error e : Except String Tr) = .ok t' := h; cases h', ?_⟩
      rintro ⟨h0, _⟩
      cases h1 : (t.challengeFp2Vec H c).1.any Fp2.isZero with
      | true => rw [h1, Bool.true_or] at h0; cases h0
      | false =>
        have hok := (groupDraws_ok_iff H c t (t.challengeFp2Vec H c).2).mpr ⟨h1, rfl⟩
        rw [hg] at hok; cases hok
    | ok t1 =>
      obtain ⟨h1, ht1⟩ := (groupDraws_ok_iff H c t t1).mp hg
      rw [h1, Bool.false_or, ← ht1]; exact foldDraws_ok_iff H cs t1 t'

theorem openingChallenges_ok_iff (H : HIn → Dig) (counts : List ℕ) (rows prox : ℕ) (t : Tr) :
    Exec.Block.openingChallenges H counts rows prox t = .ok ()
      ↔ openingAuditOk (t.challengeFp2Vec H counts.sum).1
          ((t.challengeFp2Vec H counts.sum).2.challengeFp2Vec H rows).1 rows prox = true := by
  rw [openingChallenges_eq]; unfold openingAuditOk
  cases hf : counts.foldlM (fun t c => Exec.Block.groupDraws H c t) t with
  | error e =>
    refine ⟨fun h => by have h' : (Except.error e : Except String Unit) = .ok () := h; cases h', fun h => ?_⟩
    cases h1 : (t.challengeFp2Vec H counts.sum).1.any Fp2.isZero with
    | true => rw [h1] at h; cases h
    | false =>
      have hok := (foldDraws_ok_iff H counts t (t.challengeFp2Vec H counts.sum).2).mpr ⟨h1, rfl⟩
      rw [hf] at hok; cases hok
  | ok t1 =>
    obtain ⟨h1, ht1⟩ := (foldDraws_ok_iff H counts t t1).mp hf
    rw [h1, ← ht1]; simp only [Bind.bind, Except.bind, Bool.not_false, Bool.true_and]
    by_cases hc : prox + 1 ≥ rows ∨ (Exec.Block.det ((t1.challengeFp2Vec H rows).1.getD prox Fp2.zero)
        ((t1.challengeFp2Vec H rows).1.getD (prox + 1) Fp2.zero)).v = 0
    · rw [ite_eq_left hc, decide_eq_true hc]; exact ⟨fun h => by cases h, fun h => by cases h⟩
    · rw [ite_eq_right hc, decide_eq_false hc]; exact ⟨fun _ => rfl, fun _ => rfl⟩

/-- Post-`zkRhos` PCS opening tail using cached `MerkleLevels depth` (`0` extra Merkle queries). -/
def pcsOpenTailProg (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (nGroups : ℕ)
    (rhos : List (List Fp2)) (t : Tr) : PProg (QB Lq) Dig (Exec.Block.OpeningZk × Tr) :=
  let allVecs := rhos.map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)
  let vecs := allVecs.take nGroups
  let prox := allVecs.getD nGroups []
  (trAbsorbVecsProg Lq vecs t).andThen fun t1 =>
    (trAbsorbFp2Prog Lq t1 pcsProxLabel prox).andThen fun t2 =>
      (trSqueezeVecProg Lq h47 ((prm.nQ + 3) / 4) t2).andThen fun sq =>
        let cols := (idxOf prm.nn prm.nQ sq.1).map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
        .ret (⟨vecs, prox, cols⟩, sq.2)

theorem pcsOpenTailProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (tag : MTag) (prm : PcsPrm) (depth : ℕ)
    (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table) (tree : MerkleLevels depth)
    (cl : List Exec.Block.ZClaim) (t : Tr) (G : QB Lq → Dig)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j) :
    (pcsOpenTailProg Lq h47 prm depth T tree (pGroups prm T (cl.map toZClaim)).length
        (pRhos (liftH G) prm T (cl.map toZClaim) t).1 (pRhos (liftH G) prm T (cl.map toZClaim) t).2.2).run G =
      bOpen (liftH G) tag prm depth T cl t := by
  unfold pcsOpenTailProg
  rw [PProg.run_andThen, trAbsorbVecsProg_run, PProg.run_andThen, trAbsorbFp2Prog_run,
    PProg.run_andThen, trSqueezeVecProg_run, run_ret]
  have hsq := challengeIndices_sqDs (liftH G) prm.nQ prm.nn (pT2 (liftH G) prm T (cl.map toZClaim) t)
    (by rw [hnn]; exact isPow2_two_pow depth) hnQ
  obtain ⟨idx, t3, hidx, _, hlt, hpcs⟩ := pcsProve_eq (liftH G) tag prm depth hnn hnQ T (cl.map toZClaim) t
  have hpair := Option.some.inj (hidx.symm.trans hsq)
  have hidx_eq : idx = idxOf prm.nn prm.nQ (sqDs (liftH G) (pT2 (liftH G) prm T (cl.map toZClaim) t) ((prm.nQ + 3) / 4)) :=
    congrArg Prod.fst hpair
  have ht3_eq : t3 = runOps (liftH G) (pT2 (liftH G) prm T (cl.map toZClaim) t) (List.replicate ((prm.nQ + 3) / 4) Op.squeeze) :=
    congrArg Prod.snd hpair
  unfold bOpen; rw [hpcs]
  refine Prod.ext ?_ ht3_eq.symm
  unfold ofOZ; rw [List.map_map]
  refine congrArg (Exec.Block.OpeningZk.mk _ _) ?_
  change (idxOf prm.nn prm.nQ (sqDs (liftH G) (pT2 (liftH G) prm T (cl.map toZClaim) t) ((prm.nQ + 3) / 4))).map _ = _
  rw [← hidx_eq]
  refine List.map_congr_left (fun j hj => ?_)
  have hj' : j < 2 ^ depth := by rw [← hnn]; exact hlt j hj
  show ofOCol (j, T.cols j, T.salts j, tree.pathD j) = ofOCol (j, T.cols j, T.salts j, pathOf (liftH G) tag depth T j)
  unfold MerkleLevels.pathD; rw [dite_eq_left hj', htree j hj']

theorem pcsOpenTailProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (nGroups : ℕ) (rhos : List (List Fp2)) (t : Tr) :
    PurePt (pcsOpenTailProg Lq h47 prm depth T tree nGroups rhos t) (nGroups + 1 + (prm.nQ + 3) / 4) := by
  unfold pcsOpenTailProg
  have hlen : ((rhos.map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)).take nGroups).length ≤ nGroups :=
    List.length_take_le nGroups _
  exact ((trAbsorbVecsProg_purePt Lq _ t).andThen fun t1 =>
    (trAbsorbProg_purePt Lq t1 _ _).andThen fun t2 =>
      (trSqueezeVecProg_purePt Lq h47 ((prm.nQ + 3) / 4) t2).andThen fun _ => PurePt.ret _).mono
    (by omega)

/-- Standalone `bOpen` `PProg` using cached `MerkleLevels depth` (`0` extra Merkle queries). -/
def bOpenProg (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    PProg (QB Lq) Dig (Exec.Block.OpeningZk × Tr) :=
  let gs := pGroups prm T (cl.map toZClaim)
  (zkRhosProg Lq h47 T.rows.length gs t).andThen fun r =>
    pcsOpenTailProg Lq h47 prm depth T tree gs.length r.1 r.2.2.2.2

theorem bOpenProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (tag : MTag) (prm : PcsPrm) (depth : ℕ)
    (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table) (tree : MerkleLevels depth)
    (cl : List Exec.Block.ZClaim) (t : Tr) (G : QB Lq → Dig)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j) :
    (bOpenProg Lq h47 prm depth T tree cl t).run G = bOpen (liftH G) tag prm depth T cl t := by
  unfold bOpenProg; rw [PProg.run_andThen]
  have hz := zkRhosProg_run Lq h47 T.rows.length G (pGroups prm T (cl.map toZClaim)) t
  dsimp only at hz; rw [hz.1, hz.2.2.2.2]
  exact pcsOpenTailProg_run Lq h47 tag prm depth hnn hnQ T tree cl t G htree

theorem bOpenProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    PurePt (bOpenProg Lq h47 prm depth T tree cl t)
      (((pGroups prm T (cl.map toZClaim)).map (fun g => g.2.length)).sum + T.rows.length
        + (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) :=
  ((zkRhosProg_purePt Lq h47 T.rows.length _ t).andThen fun r =>
    pcsOpenTailProg_purePt Lq h47 prm depth T tree _ r.1 r.2.2.2.2).mono (by omega)

theorem bOpenProg_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    (bOpenProg Lq h47 prm depth T tree cl t).PtLE
      (((pGroups prm T (cl.map toZClaim)).map (fun g => g.2.length)).sum + T.rows.length
        + (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) :=
  (bOpenProg_purePt Lq h47 prm depth T tree cl t).1
theorem bOpenProg_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    (bOpenProg Lq h47 prm depth T tree cl t).QLE
      (((pGroups prm T (cl.map toZClaim)).map (fun g => g.2.length)).sum + T.rows.length
        + (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) :=
  (bOpenProg_purePt Lq h47 prm depth T tree cl t).2.1
theorem bOpenProg_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    DepAbsorbed (bOpenProg Lq h47 prm depth T tree cl t) :=
  (bOpenProg_purePt Lq h47 prm depth T tree cl t).depAbsorbed

/-- **Deduplicated `checkOpeningExec` + `bOpen` `PProg`**: draws `zkRhos` ONCE, runs the pure
`openingAuditOk` check on those exact draws, returns `none` on refusal, and otherwise builds `OpeningZk`
from cached `MerkleLevels` (`0` duplicate audit draws, `0` extra Merkle queries). -/
def openingAuditProveProg (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    PProg (QB Lq) Dig (Option (Exec.Block.OpeningZk × Tr)) :=
  match auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox with
  | .error _ => .ret none
  | .ok () =>
    match openingGroupsAt cl prm.logCols with
    | .error _ => .ret none
    | .ok og =>
      if og.length ≠ g.groups then .ret none
      else
        let gs := pGroups prm T (cl.map toZClaim)
        (zkRhosProg Lq h47 T.rows.length gs t).andThen fun r =>
          if openingAuditOk r.2.2.1 r.2.2.2.1 g.rows g.prox then
            (pcsOpenTailProg Lq h47 prm depth T tree gs.length r.1 r.2.2.2.2).andThen fun res => .ret (some res)
          else .ret none

theorem openingAuditProveProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (tag : MTag) (prm : PcsPrm) (depth : ℕ)
    (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (g : OpenGeom) (T : Table) (hrows : g.rows = T.rows.length)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (G : QB Lq → Dig)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j) :
    (openingAuditProveProg Lq h47 prm depth g T tree cl t).run G =
      match checkOpeningExec (liftH G) g prm.logCols cl t with
      | .ok () => some (bOpen (liftH G) tag prm depth T cl t)
      | .error _ => none := by
  unfold openingAuditProveProg checkOpeningExec
  cases haud : auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox with
  | error _ => simp [Bind.bind, Except.bind, PProg.run]
  | ok u =>
    cases u
    cases hog : openingGroupsAt cl prm.logCols with
    | error _ => simp [Bind.bind, Except.bind, PProg.run]
    | ok og =>
      by_cases hgl : og.length ≠ g.groups
      · simp [hgl, Bind.bind, Except.bind, throw, throwThe, MonadExceptOf.throw, PProg.run]
      · simp only [hgl, ↓reduceIte, Bind.bind, Except.bind, pure, Except.pure]
        rw [PProg.run_andThen]
        have hcounts : og.map (·.2) = (pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length) :=
          openingGroupsAt_counts_eq_groupZclaims cl T.rows.length prm.logCols og
            (auditClaims_parts_nonempty cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox haud) hog
        have hz := zkRhosProg_run Lq h47 T.rows.length G (pGroups prm T (cl.map toZClaim)) t
        dsimp only at hz
        have haudEq : openingAuditOk
            ((zkRhosProg Lq h47 T.rows.length (pGroups prm T (cl.map toZClaim)) t).run G).2.2.1
            ((zkRhosProg Lq h47 T.rows.length (pGroups prm T (cl.map toZClaim)) t).run G).2.2.2.1
            g.rows g.prox =
          openingAuditOk (t.challengeFp2Vec (liftH G) (og.map (·.2)).sum).1
            ((t.challengeFp2Vec (liftH G) (og.map (·.2)).sum).2.challengeFp2Vec (liftH G) g.rows).1
            g.rows g.prox := by
          rw [hz.2.2.1, hz.2.2.2.1, ← hcounts, ← hrows]
        cases hch : Exec.Block.openingChallenges (liftH G) (og.map (·.2)) g.rows g.prox t with
        | error _ =>
          have hfalse : openingAuditOk
              ((zkRhosProg Lq h47 T.rows.length (pGroups prm T (cl.map toZClaim)) t).run G).2.2.1
              ((zkRhosProg Lq h47 T.rows.length (pGroups prm T (cl.map toZClaim)) t).run G).2.2.2.1
              g.rows g.prox ≠ true := by
            intro ht; rw [haudEq] at ht
            have hok := (openingChallenges_ok_iff (liftH G) (og.map (·.2)) g.rows g.prox t).mpr ht
            rw [hch] at hok; cases hok
          dsimp only; rw [ite_eq_right hfalse, run_ret]
        | ok u' =>
          cases u'
          have htrue : openingAuditOk
              ((zkRhosProg Lq h47 T.rows.length (pGroups prm T (cl.map toZClaim)) t).run G).2.2.1
              ((zkRhosProg Lq h47 T.rows.length (pGroups prm T (cl.map toZClaim)) t).run G).2.2.2.1
              g.rows g.prox = true := by
            rw [haudEq]; exact (openingChallenges_ok_iff (liftH G) (og.map (·.2)) g.rows g.prox t).mp hch
          dsimp only
          rw [ite_eq_left htrue, PProg.run_andThen, run_ret, hz.1, hz.2.2.2.2,
            pcsOpenTailProg_run Lq h47 tag prm depth hnn hnQ T tree cl t G htree]

theorem openingAuditProveProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    PurePt (openingAuditProveProg Lq h47 prm depth g T tree cl t)
      (((pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length)).sum + T.rows.length
        + (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) := by
  unfold openingAuditProveProg
  cases auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox with
  | error _ => exact (PurePt.ret _).mono (Nat.zero_le _)
  | ok u =>
    cases u
    cases openingGroupsAt cl prm.logCols with
    | error _ => exact (PurePt.ret _).mono (Nat.zero_le _)
    | ok og =>
      by_cases hgl : og.length ≠ g.groups
      · rw [ite_eq_left hgl]; exact (PurePt.ret _).mono (Nat.zero_le _)
      · rw [ite_eq_right hgl]
        refine ((zkRhosProg_purePt Lq h47 T.rows.length _ t).andThen
            (n := (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) fun r => ?_).mono (by omega)
        by_cases ha : openingAuditOk r.2.2.1 r.2.2.2.1 g.rows g.prox = true
        · rw [ite_eq_left ha]
          exact ((pcsOpenTailProg_purePt Lq h47 prm depth T tree _ r.1 r.2.2.2.2).andThen
            (fun _ => PurePt.ret _)).mono (by omega)
        · rw [ite_eq_right ha]; exact (PurePt.ret _).mono (Nat.zero_le _)

theorem openingAuditProveProg_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    (openingAuditProveProg Lq h47 prm depth g T tree cl t).PtLE
      (((pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length)).sum + T.rows.length
        + (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) :=
  (openingAuditProveProg_purePt Lq h47 prm depth g T tree cl t).1
theorem openingAuditProveProg_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    (openingAuditProveProg Lq h47 prm depth g T tree cl t).QLE
      (((pGroups prm T (cl.map toZClaim)).map (fun x => x.2.length)).sum + T.rows.length
        + (pGroups prm T (cl.map toZClaim)).length + 1 + (prm.nQ + 3) / 4) :=
  (openingAuditProveProg_purePt Lq h47 prm depth g T tree cl t).2.1
theorem openingAuditProveProg_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) :
    DepAbsorbed (openingAuditProveProg Lq h47 prm depth g T tree cl t) :=
  (openingAuditProveProg_purePt Lq h47 prm depth g T tree cl t).depAbsorbed
theorem openingAuditProveProg_depIn (Lq : ℕ) (h47 : 47 ≤ Lq) (prm : PcsPrm) (depth : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (S : Set (QB Lq)) :
    (openingAuditProveProg Lq h47 prm depth g T tree cl t).DepIn S :=
  (openingAuditProveProg_purePt Lq h47 prm depth g T tree cl t).2.2.2 S

/-- **Honest `M` opening (`bMask`) as a `PProg` using cached `MerkleLevels 12`** (`2 * S + 69` `.pt` queries). -/
noncomputable def bMaskProg (Lq : ℕ) (h47 : 47 ≤ Lq)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    PProg (QB Lq) Dig (Exec.Block.MaskOpening × Tr) :=
  let fs' := fs.map toMF
  (trChallengeFp2Prog Lq h47 t).andThen fun th =>
    let qw := polyWords U hbij (qPoly U (algebraMap GF K (rootFp 9).toGF) M S fs' (th.1.toK U))
    (trAbsorbFp2Prog Lq th.2 maskQLabel qw).andThen fun t1 =>
      (trChallengeFp2VecProg Lq h47 (2 * S + 2) t1).andThen fun rs =>
        let pw := polyWords U hbij (pPoly U M S rs.1)
        (trAbsorbFp2Prog Lq rs.2 maskProxLabel pw).andThen fun t2 =>
          (trSqueezeVecProg Lq h47 ((mQ + 3) / 4) t2).andThen fun sq =>
            let cols := (idxOf mDom mQ sq.1).map (fun j =>
              ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
            .ret (⟨qw, pw, cols⟩, sq.2)

theorem bMaskProg_run (Lq : ℕ) (h47 : 47 ≤ Lq) (tag : MTag)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) (G : QB Lq → Dig)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ 12), tree.path j hj = pathOf (liftH G) tag 12 (mTab S (cosetPt (rootFp 12)) M) j) :
    (bMaskProg Lq h47 U hbij M S tree fs t).run G = bMask (liftH G) tag U hbij M S fs t := by
  unfold bMaskProg
  rw [PProg.run_andThen, trChallengeFp2Prog_run, PProg.run_andThen, trAbsorbFp2Prog_run,
    PProg.run_andThen, trChallengeFp2VecProg_run, PProg.run_andThen, trAbsorbFp2Prog_run,
    PProg.run_andThen, trSqueezeVecProg_run, run_ret]
  have hsq := challengeIndices_sqDs (liftH G) mQ mDom (mT2 (liftH G) U hbij (rootFp 9) M S (fs.map toMF) t)
    (isPow2_two_pow 12) (by norm_num [mQ])
  obtain ⟨idx, t3, hidx, _, hlt, hmp⟩ := maskProve_eq (liftH G) tag U hbij (rootFp 9) (rootFp 12) M S (fs.map toMF) t
  have hpair := Option.some.inj (hidx.symm.trans hsq)
  have hidx_eq : idx = idxOf mDom mQ (sqDs (liftH G) (mT2 (liftH G) U hbij (rootFp 9) M S (fs.map toMF) t) ((mQ + 3) / 4)) :=
    congrArg Prod.fst hpair
  have ht3_eq : t3 = runOps (liftH G) (mT2 (liftH G) U hbij (rootFp 9) M S (fs.map toMF) t) (List.replicate ((mQ + 3) / 4) Op.squeeze) :=
    congrArg Prod.snd hpair
  unfold bMask; rw [hmp]
  refine Prod.ext ?_ ht3_eq.symm
  unfold ofMO; rw [List.map_map]
  refine congrArg (Exec.Block.MaskOpening.mk _ _) ?_
  change (idxOf mDom mQ (sqDs (liftH G) (mT2 (liftH G) U hbij (rootFp 9) M S (fs.map toMF) t) ((mQ + 3) / 4))).map _ = _
  rw [← hidx_eq]
  refine List.map_congr_left (fun j hj => ?_)
  have hj' : j < 2 ^ 12 := show j < 2 ^ 12 from hlt j hj
  show ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j) =
    ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, pathOf (liftH G) tag 12 (mTab S (cosetPt (rootFp 12)) M) j)
  unfold MerkleLevels.pathD; rw [dite_eq_left hj', htree j hj']

theorem bMaskProg_purePt (Lq : ℕ) (h47 : 47 ≤ Lq)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    PurePt (bMaskProg Lq h47 U hbij M S tree fs t) (2 * S + 69) := by
  unfold bMaskProg
  refine ((trChallengeFp2Prog_purePt Lq h47 t).andThen fun th =>
    (trAbsorbProg_purePt Lq th.2 _ _).andThen fun t1 =>
      (trChallengeFp2VecProg_purePt Lq h47 (2 * S + 2) t1).andThen fun rs =>
        (trAbsorbProg_purePt Lq rs.2 _ _).andThen fun t2 =>
          (trSqueezeVecProg_purePt Lq h47 ((mQ + 3) / 4) t2).andThen fun _ => PurePt.ret _).mono ?_
  have hmQ : (mQ + 3) / 4 = 64 := by norm_num [mQ]
  omega

theorem bMaskProg_ptLE (Lq : ℕ) (h47 : 47 ≤ Lq) {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    (bMaskProg Lq h47 U hbij M S tree fs t).PtLE (2 * S + 69) := (bMaskProg_purePt Lq h47 U hbij M S tree fs t).1
theorem bMaskProg_qLE (Lq : ℕ) (h47 : 47 ≤ Lq) {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    (bMaskProg Lq h47 U hbij M S tree fs t).QLE (2 * S + 69) := (bMaskProg_purePt Lq h47 U hbij M S tree fs t).2.1
theorem bMaskProg_depAbsorbed (Lq : ℕ) (h47 : 47 ≤ Lq) {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    DepAbsorbed (bMaskProg Lq h47 U hbij M S tree fs t) := (bMaskProg_purePt Lq h47 U hbij M S tree fs t).depAbsorbed
theorem bMaskProg_depIn (Lq : ℕ) (h47 : 47 ≤ Lq) {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) (Sq : Set (QB Lq)) :
    (bMaskProg Lq h47 U hbij M S tree fs t).DepIn Sq := (bMaskProg_purePt Lq h47 U hbij M S tree fs t).2.2.2 Sq

/-! ### Run-header `PProg` (`2` public `.dep`s + `7` `.pt`s, `DepStrict.dep2Pt`) -/

private theorem hdrShapeFit {Lq : ℕ} (w : ClsHdrW)
    (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq) (d₀ : Dig) :
    (absorbMsg d₀ abLabShape w.shape).length ≤ Lq := by
  simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length,
    abLabShape, List.length_cons, List.length_nil]; omega

private theorem hdrExpFit {Lq : ℕ} (w : ClsHdrW)
    (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq) (d₁ inRoot : Dig) :
    (absorbMsg d₁ abLabExp (abExpMsg w.inDig inRoot)).length ≤ Lq := by
  have hexp := abExpMsg_length w.inDig inRoot
  simp only [absorbMsg, List.length_append, le64_length, List.Vector.toList_length,
    abLabExp, List.length_cons, List.length_nil, hexp]; omega

private def shdP_hdrTailProg (Lq : ℕ) (w : ClsHdrW) (verdict : ℕ) (t₂ : Tr) : PProg (QB Lq) Dig Tr :=
  (trAbsorbProg Lq t₂ abLabPub w.pubSt.toList).andThen fun t₃ =>
  (trAbsorbProg Lq t₃ abLabPar w.params).andThen fun t₄ =>
  (trAbsorbProg Lq t₄ abLabCal w.calib.toList).andThen fun t₅ =>
  (trAbsorbProg Lq t₅ abLabSch w.sched.toList).andThen fun t₆ =>
  (trAbsorbProg Lq t₆ abLabVer [UInt8.ofNat verdict]).andThen fun t₇ =>
  trAbsorbProg Lq t₇ abLabChk w.chunk

private theorem shdP_hdrTailProg_purePt (Lq : ℕ) (w : ClsHdrW) (verdict : ℕ) (t₂ : Tr) :
    PurePt (shdP_hdrTailProg Lq w verdict t₂) 6 :=
  ((trAbsorbProg_purePt Lq t₂ _ _).andThen fun t₃ =>
   (trAbsorbProg_purePt Lq t₃ _ _).andThen fun t₄ =>
   (trAbsorbProg_purePt Lq t₄ _ _).andThen fun t₅ =>
   (trAbsorbProg_purePt Lq t₅ _ _).andThen fun t₆ =>
   (trAbsorbProg_purePt Lq t₆ _ _).andThen fun t₇ =>
   trAbsorbProg_purePt Lq t₇ _ _).mono (by omega)

/-- Run-header `PProg` implementing `clsStart`: `Tr.newKeyed` (`.dep`) → `"run-shape"` (`.dep`) →
`"expected-IO"` (`.pt`, absorbing both `.dep`s into a fresh `inRoot` point) → 6 remaining `.pt` absorbs. -/
def shdP_hdrPProg (Lq : ℕ) (key : Option Dig) (domain : List UInt8) (hdom : (startMsg domain).length ≤ Lq)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) : PProg (QB Lq) Dig Tr :=
  .dep (key, ⟨startMsg domain, hdom⟩) fun d₀ =>
    .dep (key, ⟨absorbMsg d₀ abLabShape w.shape, hdrShapeFit w hfit d₀⟩) fun d₁ =>
      .pt (key, ⟨absorbMsg d₁ abLabExp (abExpMsg w.inDig inRoot), hdrExpFit w hfit d₁ inRoot⟩) fun d₂ =>
        shdP_hdrTailProg Lq w verdict ⟨d₂, 0, key⟩

private theorem G_eq_liftH {Lq : ℕ} (G : QB Lq → Dig) (k : Option Dig) (m : List UInt8) (h : m.length ≤ Lq) :
    G (k, ⟨m, h⟩) = liftH G ⟨k, m⟩ :=
  (liftH_eq G k m h).symm

theorem shdP_hdrPProg_run {Hdr : Type} (Lq : ℕ) (key : Option Dig) (domain : List UInt8)
    (hdom : (startMsg domain).length ≤ Lq) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) (G : QB Lq → Dig) :
    (shdP_hdrPProg Lq key domain hdom (hw hdr) hfit inRoot verdict).run G =
      clsStart domain key hw (liftH G) (honestStmt hdr inRoot verdict) := by
  unfold shdP_hdrPProg shdP_hdrTailProg clsStart clsHdrOf clsHdrOps honestStmt Tr.newKeyed
  rw [run_dep, run_dep, run_pt,
    PProg.run_andThen, trAbsorbProg_run, PProg.run_andThen, trAbsorbProg_run,
    PProg.run_andThen, trAbsorbProg_run, PProg.run_andThen, trAbsorbProg_run,
    PProg.run_andThen, trAbsorbProg_run, trAbsorbProg_run,
    G_eq_liftH, G_eq_liftH, G_eq_liftH]
  rfl

theorem shdP_hdrPProg_ptLE (Lq : ℕ) (key : Option Dig) (domain : List UInt8) (hdom : (startMsg domain).length ≤ Lq)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) :
    (shdP_hdrPProg Lq key domain hdom w hfit inRoot verdict).PtLE 7 :=
  fun _ _ => ⟨by omega, fun d₂ => (shdP_hdrTailProg_purePt Lq w verdict ⟨d₂, 0, key⟩).1⟩

theorem shdP_hdrPProg_qLE (Lq : ℕ) (key : Option Dig) (domain : List UInt8) (hdom : (startMsg domain).length ≤ Lq)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) :
    (shdP_hdrPProg Lq key domain hdom w hfit inRoot verdict).QLE 9 :=
  ⟨by omega, fun _ => ⟨by omega, fun _ => ⟨by omega, fun d₂ => (shdP_hdrTailProg_purePt Lq w verdict ⟨d₂, 0, key⟩).2.1⟩⟩⟩

theorem shdP_hdrPProg_depStrict (Lq : ℕ) (key : Option Dig) (domain : List UInt8) (hdom : (startMsg domain).length ≤ Lq)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) :
    DepStrict (shdP_hdrPProg Lq key domain hdom w hfit inRoot verdict) :=
  DepStrict.dep2Pt _ _ _ _ fun d₂ => (shdP_hdrTailProg_purePt Lq w verdict ⟨d₂, 0, key⟩).2.2.1

theorem shdP_hdrPProg_depAbsorbed (Lq : ℕ) (key : Option Dig) (domain : List UInt8) (hdom : (startMsg domain).length ≤ Lq)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) :
    DepAbsorbed (shdP_hdrPProg Lq key domain hdom w hfit inRoot verdict) :=
  (shdP_hdrPProg_depStrict Lq key domain hdom w hfit inRoot verdict).toDepAbsorbed

end OpeningCombinators

/-! ## 4. Full 112-tree + 28-segment budget arithmetic, `ShdRunDepSet`, and `shdRunErrRes` bridge -/

section ShdRunBudget

open ZK60.ZKW16 ZK60.TokenRun ZK60.RunShape ZK60.ProtocolClassify.RunShapeP

/-- Tree counts for the 28-segment Shieldstral T128 R13 run (`1` `TE`, `4` stage `TA/TH`,
`79` block `TA/TH` + boundary `B_0..26`, `28` `M` trees = `112` trees). -/
def shdP_zkTrees_ep : ℕ := 1
def shdP_zkTrees_stg : ℕ := 4
def shdP_zkTrees_blk : ℕ := 79
def shdP_zkTrees_mask : ℕ := 28
def shdP_zkTrees_total : ℕ := shdP_zkTrees_ep + shdP_zkTrees_stg + shdP_zkTrees_blk + shdP_zkTrees_mask

/-- Total salted leaves (`L = 5,359,616`) and internal nodes (`N = 5,359,504`) across all 112 trees. -/
def shdP_zkLeaves : ℕ :=
  shdP_zkTrees_ep * 2 ^ 11 + shdP_zkTrees_stg * 2 ^ 14 + shdP_zkTrees_blk * 2 ^ 16 + shdP_zkTrees_mask * 2 ^ 12
def shdP_zkNodes : ℕ :=
  shdP_zkTrees_ep * (2 ^ 11 - 1) + shdP_zkTrees_stg * (2 ^ 14 - 1)
    + shdP_zkTrees_blk * (2 ^ 16 - 1) + shdP_zkTrees_mask * (2 ^ 12 - 1)

/-- Main transcript `.pt`s (`7` header + `605` IN-C + `26 * 10,862` blocks + `797` OUT-C = `283,821`),
deduped `posTag` `.pt`s (`29 * 2 = 58`), total transcript `.pt`s (`283,879`), total `.pt`s (`11,002,999`),
total `.dep`s (`5,359,618`), total `QLE` (`16,362,617`), and Sol's `T = 2^20` reserve (`11,767,696`). -/
def shdP_zkMainTrPts : ℕ := 7 + 605 + 26 * 10862 + 797
def shdP_zkPosTagPts : ℕ := 29 * 2
def shdP_zkTrPts : ℕ := shdP_zkMainTrPts + shdP_zkPosTagPts
def shdP_zkPts : ℕ := shdP_zkLeaves + shdP_zkNodes + shdP_zkTrPts
def shdP_zkDeps : ℕ := 2 + shdP_zkLeaves
def shdP_zkQueries : ℕ := shdP_zkPts + shdP_zkDeps
def shdP_zkResT : ℕ := 2 ^ 20
def shdP_zkResPts : ℕ := shdP_zkResT + shdP_zkLeaves + shdP_zkNodes

/-- **Exact 112-tree + 28-segment Shieldstral T128 R13 budget arithmetic** verifying that the deduplicated
`PProg` fits cleanly inside Sol's `T = 2^20` reserve (`HonestShieldZKBase.shdRunErrRes`, `pts = 11,767,696`). -/
theorem shdP_zkProg_counts :
    shdP_zkTrees_total = 112 ∧ shdP_zkLeaves = 5359616 ∧ shdP_zkNodes = 5359504
      ∧ shdP_zkMainTrPts = 283821 ∧ shdP_zkPosTagPts = 58 ∧ shdP_zkTrPts = 283879
      ∧ shdP_zkPts = 11002999 ∧ shdP_zkDeps = 5359618 ∧ shdP_zkQueries = 16362617
      ∧ shdP_zkResPts = 11767696 ∧ shdP_zkTrPts ≤ 2 ^ 20
      ∧ shdP_zkPts ≤ shdP_zkResPts ∧ shdP_zkResPts < 2 ^ 64 := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;>
    norm_num [shdP_zkTrees_total, shdP_zkTrees_ep, shdP_zkTrees_stg, shdP_zkTrees_blk, shdP_zkTrees_mask,
      shdP_zkLeaves, shdP_zkNodes, shdP_zkMainTrPts, shdP_zkPosTagPts, shdP_zkTrPts,
      shdP_zkPts, shdP_zkDeps, shdP_zkQueries, shdP_zkResT, shdP_zkResPts]

theorem shdP_zkProg_ptLE_res {Q D α : Type} {p : PProg Q D α} (hp : p.PtLE shdP_zkPts) :
    p.PtLE shdP_zkResPts :=
  ptLE_mono p hp shdP_zkProg_counts.2.2.2.2.2.2.2.2.2.2.2.1

/-- **Exact `.dep` query set for the Shieldstral T128 R13 run**:
the 2 public header queries (`Tr.newKeyed` start + `"run-shape"` absorb) plus all `tag.col` column-digest
queries (byte length a multiple of `8`). Oracle-independent and disjoint from `shdP_zkPad`. -/
def ShdRunDepSet (Lq : ℕ) (tag : MTag) (key : Option Dig) (domain shape : List UInt8) : Set (QB Lq) :=
  {q : QB Lq |
    (q.1 = key ∧ q.2.1 = startMsg domain)
    ∨ (q.1 = key ∧ ∃ d : Dig, q.2.1 = absorbMsg d abLabShape shape)
    ∨ (q.1 = tag.col ∧ q.2.1.length % 8 = 0)}

theorem shdP_hdrPProg_depIn (Lq : ℕ) (tag : MTag) (key : Option Dig) (domain : List UInt8)
    (hdom : (startMsg domain).length ≤ Lq) (w : ClsHdrW)
    (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) :
    (shdP_hdrPProg Lq key domain hdom w hfit inRoot verdict).DepIn
      (ShdRunDepSet Lq tag key domain w.shape) :=
  ⟨Or.inl ⟨rfl, rfl⟩, fun d₀ =>
    ⟨Or.inr (Or.inl ⟨rfl, d₀, rfl⟩), fun _ d₂ =>
      (shdP_hdrTailProg_purePt Lq w verdict ⟨d₂, 0, key⟩).2.2.2 _⟩⟩

theorem merkleTreeProg_depIn_run (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (key : Option Dig)
    (domain shape : List UInt8) (d : ℕ)
    (colOf : Fin (2 ^ d) → List UInt8) (hcol : ∀ j, (colOf j).length ≤ Lq)
    (h8 : ∀ j, (colOf j).length % 8 = 0) (saltOf : Fin (2 ^ d) → Dig) :
    (merkleTreeProg Lq h64 tag d colOf hcol saltOf).DepIn (ShdRunDepSet Lq tag key domain shape) :=
  depIn_mono (fun _ h => Or.inr (Or.inr h)) _ (merkleTreeProg_depIn_col8 Lq h64 tag d colOf hcol h8 saltOf)

theorem shdP_zkPad_notMem_depSet (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (domain shape : List UInt8) (hdom : domain.length ≠ 37) (idx : ℕ) (prev : Dig) :
    shdP_zkPad Lq hL20 idx prev ∉ ShdRunDepSet Lq tag key domain shape := by
  rintro (⟨_, hst⟩ | ⟨_, d, habs⟩ | ⟨_, h8⟩)
  · exact shdP_zkPad_ne_start Lq hL20 idx prev none domain hdom
      (by rw [← hst]; exact (shdP_zkPad Lq hL20 idx prev).2.2) (Prod.ext rfl (Subtype.ext hst))
  · exact shdP_zkPad_ne_absorb Lq hL20 idx prev none d abLabShape shape
      (by rw [← habs]; exact (shdP_zkPad Lq hL20 idx prev).2.2) (Prod.ext rfl (Subtype.ext habs))
  · change (shdP_zkPadMsg idx prev).length % 8 = 0 at h8
    rw [shdP_zkPadMsg_length] at h8; omega

open Classical in
/-- **Direct bridge into `RunShieldOpenShell.classifyP_zk_of_prog_model` at `HonestShieldZKBase.shdRunErrRes`**:
discharges `hres` via `DepAbsorbed`, lifts `PtLE shdP_zkPts` to `shdP_zkResPts = 11,767,696`, and wires
`shdP_zkPad` and `ShdRunDepSet` directly into the conservative `T = 2^20` budget. -/
theorem shdP_zk_of_prog_res {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (domain shape : List UInt8) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (prog : {x // (classifyModelP R).admissible x} → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (hprog : ∀ H (x : {x // (classifyModelP R).admissible x}) c,
      (prog x c).run H = (classifyProtocolP R Lq V P Cin h64 hr base).prove H () x.1 c)
    (hk : ∀ x c, (prog x c).PtLE shdP_zkPts)
    (habs : ∀ x c, DepAbsorbed (prog x c))
    (hq : ∀ x c, (prog x c).QLE shdP_zkQueries)
    (hdep : ∀ x c, (prog x c).DepIn (ShdRunDepSet Lq tag key domain shape))
    (vis : (Fin shdP_zkResPts → Dig) → Fin shdP_zkResPts → Prop)
    (vp : ClsStmt Hdr × ClsReceipt → (QB Lq → Dig) → (Fin shdP_zkResPts → Dig) → Fin shdP_zkResPts → QB Lq)
    (hvis : ∀ x c H v i, vis v i →
      PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i = vp (PProg.outOf (prog x c) v) H v i)
    (G : (Fin shdP_zkResPts → Dig) → Prop) (hvisG : ∀ v i, G v → ¬ vis v i)
    (hrefG : ∀ x c v, G v → PProg.outOf (prog x c) v = (P.refused, []))
    (hHV : ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 → ∀ v : Fin shdP_zkResPts → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x c) v)
          = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x' c) v))
    (Kf KUf : QB Lq → ℕ) (Km KUm Wp Wpa Kc : ℕ)
    (hKm : ∀ z, Kf z ≤ Km) (hKUm : ∀ z, KUf z ≤ KUm)
    (hwb : ∀ x c, WB Kf (prog x c).oc Wp) (hwba : ∀ x c, WB KUf (prog x c).oc Wpa)
    (hKw : ∀ x (H : QB Lq → Dig) z, (Finset.univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      ∃ i, PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : QB Lq → Dig), (Finset.univ.filter (fun s : Coins × (Fin shdP_zkResPts → Dig) =>
      ¬ Function.Injective (PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2)
        ∨ ∃ i, PProg.ptsOf (shdP_zkPad Lq hL20) (prog x s.1) H s.2 i
          ∈ ShdRunDepSet Lq tag key domain shape)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin shdP_zkResPts → Dig) * KUf z)
    (hUw : ∀ x (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig), ¬ G v →
      ∀ (Zs : (ClsStmt Hdr × ClsReceipt) → Finset (QB Lq)) (Wt : ℕ), (∀ o, ∑ z ∈ Zs o, KUf z ≤ Wt) →
      (Finset.univ.filter (fun c => ∃ i, ¬ vis v i
        ∧ PProg.ptsOf (shdP_zkPad Lq hL20) (prog x c) H v i ∈ Zs (PProg.outOf (prog x c) v))).card ≤ Wt)
    (hrδp : (Km : ℝ≥0∞) / Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) ≤ shdRunRes_δp)
    (hrωp : (Wp : ℝ≥0∞) / Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) ≤ shdRunRes_ωp)
    (hrεc : (Kc : ℝ≥0∞) / Fintype.card (Coins × (Fin shdP_zkResPts → Dig)) ≤ shdRunRes_εc)
    (hrδh : ((2 * KUm : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ shdRunRes_δh)
    (hrωh : ((2 * Wpa : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ shdRunRes_ωh) :
    ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) shdRunErrRes :=
  classifyP_zk_of_prog_model R Lq V P Cin h64 hr base prog hprog shdP_zkResPts
    (fun x c => shdP_zkProg_ptLE_res (hk x c))
    (fun x c H' v => hres_of_depAbsorbed (habs x c) H' v)
    shdP_zkQueries hq (shdP_zkPad Lq hL20)
    (fun _ _ => ShdRunDepSet Lq tag key domain shape) hdep
    vis vp hvis G hvisG hrefG hHV Kf KUf Km KUm Wp Wpa Kc hKm hKUm hwb hwba hKw hKc hKG hUw
    shdRunRes_δp shdRunRes_ωp shdRunRes_δh shdRunRes_ωh shdRunRes_εc hrδp hrωp hrεc hrδh hrωh

end ShdRunBudget

end ZK60.HonestShield
