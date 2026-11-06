/-
D63 step L5 (the executable verifier), the foundation: the Fiat–Shamir transcript, executable, as `transcript.rs` runs
it, and proved to be `FSChain.lean`'s chain model for EVERY hash function.

What is mirrored (`ops/zkp-mvp/gpu-metal/zkp-core/src/transcript.rs`, read 2026-11-06; nothing there is changed):
* the state: 32 bytes, a squeeze counter (`u64`, wrapping as the release build does), and the key of a tagged profile
  (ruling T-1: `None` is the legacy unkeyed rule, `Some k` BLAKE3's keyed mode under the profile's Fiat–Shamir key);
* `new(domain)` / `new_tagged(domain, key)`: the state is `H(key; "hashline-v1/" ‖ domain)`, the counter `0`;
* `absorb(label, data)`: `H(key; state ‖ le64 |label| ‖ label ‖ le64 |data| ‖ data)`; `absorb_u64` (8 bytes LE),
  `absorb_fp` (`Fp::to_bytes` of each), `absorb_fp2` (`Fp2::to_bytes` of each, `c0` then `c1`). The A14 parallel absorb
  is the same digest by BLAKE3's tree (the code's own test, `a14_the_parallel_absorb_equals_the_serial_digest`), so it
  is not a separate path here; the `RoundMask` hook is the prover's (it replaces what is absorbed, which the verifier
  reads off the proof), not the verifier's;
* `squeeze_bytes`: `H(key; state ‖ "squeeze" ‖ le64 counter)`, which becomes the state; the counter increments;
* `challenge_fp`: the first 16 bytes as a little-endian `u128`, reduced (`Fp::from_u128`); `challenge_fp2`: the two
  16-byte halves, each reduced, the low half `c0`; `challenge_fp2_vec`: `n` of them; `challenge_indices(n, bound)`:
  refused unless `bound` is a power of two, then 8-byte little-endian chunks of successive squeezes, each masked with
  `bound − 1`, as many as needed.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `decodeLink_msg`: the code's two kinds of chain input (an absorb's, at least 48 bytes; a squeeze's, exactly 47) are
  decoded back to the state digest and the item, for every label and data shorter than `2^64` bytes;
* `chainEnc`: so the code's transcript IS a `ChainEnc` of `FSChain.lean` (for a domain whose start string decodes as no
  link, `decodeLink (startMsg domain) = none`, an explicit premise checked per profile string; `startMsg_ok_example`
  checks one by `decide`);
* `runOps_chain`: for every hash function `H`, the executable transcript's state after any sequence of absorbs and
  squeezes is `lastD H (chainFrom H [] items)` of that `ChainEnc`, the items carrying the code's counters, and each
  squeeze's output is that chain's digest (`squeeze_out`). So `chain_sound`, `fs_chain_sound_of_rbr` and the rest of
  the FS files apply to the code's transcript as executed, not to a paraphrase of it;
* `challengeFp2Of_toGF`: `challenge_fp2` is exactly `FSChallenge.lean`'s `fp2Chal gP (2^128)` on the digest's two
  halves; `challengeFpOf_toGF` the same for `challenge_fp`; `idx_eq_idxChal`: each index is `idxChal h` of its chunk.
-/
import ZK60Formal.ExecBlake3
import ZK60Formal.FSChain
import ZK60Formal.FSChallenge

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## Digests and hash inputs -/

/-- A 32-byte digest (also the type of a key and of a salt). -/
abbrev Dig := List.Vector UInt8 32

/-- One hash call: BLAKE3's mode (unkeyed, or keyed under a 32-byte key) and the message. Ruling T-1's random oracle
is a family indexed by the mode and key, which is one random function on these inputs. -/
structure HIn where
  key : Option Dig
  msg : List UInt8
  deriving DecidableEq

/-- The first 32 bytes of a BLAKE3 output. -/
def toDig (b : ByteArray) : Dig := ⟨List.ofFn (fun i : Fin 32 => b.get! i), List.length_ofFn⟩

/-- **The hash the executable verifier runs**: BLAKE3, unkeyed or keyed (`hashtag::hasher`). -/
def blake3H (q : HIn) : Dig :=
  match q.key with
  | none => toDig (Blake3.hash ⟨q.msg.toArray⟩)
  | some k => toDig (Blake3.keyedHash ⟨k.toList.toArray⟩ ⟨q.msg.toArray⟩)

/-- A string's bytes (the code's `b"..."` literals are ASCII). -/
def ascii (s : String) : List UInt8 := s.toUTF8.toList

/-! ## The transcript -/

/-- `b"hashline-v1/"` (`L5Check.lean` checks it is `ascii "hashline-v1/"`). -/
def startTag : List UInt8 := [104, 97, 115, 104, 108, 105, 110, 101, 45, 118, 49, 47]

/-- `Transcript::new`'s input: `"hashline-v1/" ‖ domain`. -/
def startMsg (domain : List UInt8) : List UInt8 := startTag ++ domain

/-- `absorb`'s input: `state ‖ le64 |label| ‖ label ‖ le64 |data| ‖ data`. -/
def absorbMsg (st : Dig) (label data : List UInt8) : List UInt8 :=
  st.toList ++ (le64 (UInt64.ofNat label.length) ++ (label ++ (le64 (UInt64.ofNat data.length) ++ data)))

/-- `b"squeeze"` (`L5Check.lean` checks it is `ascii "squeeze"`). -/
def squeezeTag : List UInt8 := [115, 113, 117, 101, 101, 122, 101]

/-- `squeeze_bytes`'s input: `state ‖ "squeeze" ‖ le64 counter`. -/
def squeezeMsg (st : Dig) (ctr : UInt64) : List UInt8 := st.toList ++ (squeezeTag ++ le64 ctr)

/-- `Transcript`: the state, the squeeze counter, the key of a tagged profile. -/
structure Tr where
  state : Dig
  counter : UInt64
  key : Option Dig

section Run

variable (H : HIn → Dig)

/-- `Transcript::new` (`key = none`) and `Transcript::new_tagged` (`key = some k`). -/
def Tr.newKeyed (domain : List UInt8) (key : Option Dig) : Tr := ⟨H ⟨key, startMsg domain⟩, 0, key⟩

def Tr.new (domain : List UInt8) : Tr := Tr.newKeyed H domain none

def Tr.newTagged (domain : List UInt8) (key : Dig) : Tr := Tr.newKeyed H domain (some key)

/-- `Transcript::absorb`. -/
def Tr.absorb (t : Tr) (label data : List UInt8) : Tr := { t with state := H ⟨t.key, absorbMsg t.state label data⟩ }

/-- `Transcript::absorb_u64`. -/
def Tr.absorbU64 (t : Tr) (label : List UInt8) (v : UInt64) : Tr := t.absorb H label (le64 v)

/-- `Transcript::absorb_fp`. -/
def Tr.absorbFp (t : Tr) (label : List UInt8) (vals : List Fp) : Tr := t.absorb H label (vals.flatMap Fp.toBytes)

/-- `Transcript::absorb_fp2` (with no masker installed: the verifier's). -/
def Tr.absorbFp2 (t : Tr) (label : List UInt8) (vals : List Fp2) : Tr := t.absorb H label (vals.flatMap Fp2.toBytes)

/-- `Transcript::squeeze_bytes`: the output, which is also the new state. -/
def Tr.squeeze (t : Tr) : Dig × Tr :=
  let out := H ⟨t.key, squeezeMsg t.state t.counter⟩
  (out, { t with state := out, counter := t.counter + 1 })

/-- `challenge_fp` of a squeeze output: the first 16 bytes, a little-endian `u128`, reduced. -/
def challengeFpOf (d : Dig) : Fp := Fp.fromU128 (leNat (d.toList.take 16))

/-- `challenge_fp2` of a squeeze output: the two halves, each reduced; the low half is `c0`. -/
def challengeFp2Of (d : Dig) : Fp2 := ⟨Fp.fromU128 (leNat (d.toList.take 16)), Fp.fromU128 (leNat (d.toList.drop 16))⟩

def Tr.challengeFp (t : Tr) : Fp × Tr := let r := t.squeeze H; (challengeFpOf r.1, r.2)

def Tr.challengeFp2 (t : Tr) : Fp2 × Tr := let r := t.squeeze H; (challengeFp2Of r.1, r.2)

/-- `challenge_fp2_vec`. -/
def Tr.challengeFp2Vec : Tr → ℕ → List Fp2 × Tr
  | t, 0 => ([], t)
  | t, n + 1 =>
    let r := t.challengeFp2 H
    let rs := r.2.challengeFp2Vec n
    (r.1 :: rs.1, rs.2)

/-- The four 8-byte chunks of a squeeze output (`b.chunks(8)`). -/
def chunks8 (d : Dig) : List (List UInt8) :=
  [d.toList.take 8, (d.toList.drop 8).take 8, (d.toList.drop 16).take 8, d.toList.drop 24]

/-- `challenge_indices`' loop: `rem` indices still wanted (`fuel ≥ rem` bounds the recursion). -/
def idxLoop (bound : ℕ) : ℕ → Tr → ℕ → List ℕ → List ℕ × Tr
  | 0, t, _, acc => (acc, t)
  | fuel + 1, t, rem, acc =>
    if rem = 0 then (acc, t)
    else
      let r := t.squeeze H
      let vals := (chunks8 r.1).map (fun c => leNat c &&& (bound - 1))
      if rem ≤ 4 then (acc ++ vals.take rem, r.2) else idxLoop bound fuel r.2 (rem - 4) (acc ++ vals)

/-- `usize::is_power_of_two`. -/
def isPow2 (b : ℕ) : Bool := b != 0 && (b &&& (b - 1)) == 0

/-- `challenge_indices(n, bound)`: its assertion as a refusal. -/
def Tr.challengeIndices (t : Tr) (n bound : ℕ) : Option (List ℕ × Tr) :=
  if isPow2 bound then some (idxLoop H bound n t n []) else none

end Run

/-! ## The code's transcript is `FSChain.lean`'s chain -/

/-- One chain item of the code: an absorb (label, data) or a squeeze at a counter value. -/
inductive TItem
  | absorb (label data : List UInt8)
  | squeeze (ctr : UInt64)
  deriving DecidableEq

/-- The bytes an item is hashed with after the state `d`. -/
def TItem.msg (d : Dig) : TItem → List UInt8
  | .absorb l x => absorbMsg d l x
  | .squeeze c => squeezeMsg d c

/-- An item the code can hash unambiguously: its label and data are shorter than `2^64` bytes (the `u64` lengths). -/
def TItem.Ok : TItem → Prop
  | .absorb l x => l.length < 2 ^ 64 ∧ x.length < 2 ^ 64
  | .squeeze _ => True

abbrev It := {it : TItem // it.Ok}

/-- A 32-byte string as a digest. -/
def digOf? (l : List UInt8) : Option Dig := if h : l.length = 32 then some ⟨l, h⟩ else none

/-- **The decoder of a chain input** (the left inverse `FSChain.lean`'s `ChainEnc` asks for): the state digest, then a
47-byte squeeze (`"squeeze"`, the counter) or a length-prefixed absorb whose lengths account for every byte. -/
def decodeLink (m : List UInt8) : Option (Dig × It) :=
  match digOf? (m.take 32) with
  | none => none
  | some d =>
    let r := m.drop 32
    if r.length = 15 ∧ r.take 7 = squeezeTag then some (d, ⟨.squeeze (ofLE64 (r.drop 7)), trivial⟩)
    else
      let ll := leNat (r.take 8)
      let r1 := r.drop 8
      let r2 := r1.drop ll
      let dl := leNat (r2.take 8)
      if h : ll < 2 ^ 64 ∧ (r2.drop 8).length = dl ∧ dl < 2 ^ 64 ∧ ll + 8 ≤ r1.length ∧ 8 ≤ r.length then
        some (d, ⟨.absorb (r1.take ll) (r2.drop 8),
          ⟨lt_of_le_of_lt (List.length_take_le _ _) h.1, h.2.1 ▸ h.2.2.1⟩⟩)
      else none

theorem digOf?_toList (d : Dig) : digOf? d.toList = some d := by
  obtain ⟨l, hl⟩ := d
  show digOf? l = some ⟨l, hl⟩
  unfold digOf?
  simp [hl]

theorem length_le64 (v : UInt64) : (le64 v).length = 8 := le64_length v

theorem leNat_le64_ofNat {n : ℕ} (h : n < 2 ^ 64) : leNat (le64 (UInt64.ofNat n)) = n := by
  rw [leNat_le64, UInt64.toNat_ofNat', Nat.mod_eq_of_lt h]

theorem squeezeTag_length : squeezeTag.length = 7 := rfl

/-- **The decoder inverts the code's chain inputs.** -/
theorem decodeLink_msg (d : Dig) (it : It) : decodeLink (it.1.msg d) = some (d, it) := by
  obtain ⟨it, hok⟩ := it
  have hd : d.toList.length = 32 := d.2
  cases it with
  | squeeze c =>
    have hr : (squeezeTag ++ le64 c).length = 15 := by rw [List.length_append, length_le64]; rfl
    have h7 : (squeezeTag ++ le64 c).take 7 = squeezeTag := List.take_left' squeezeTag_length
    have hdrop : (squeezeTag ++ le64 c).drop 7 = le64 c := List.drop_left' squeezeTag_length
    simp only [decodeLink, TItem.msg, squeezeMsg, List.take_left' hd, digOf?_toList, List.drop_left' hd, hr, h7,
      hdrop, ofLE64_le64, and_self, ↓reduceIte]
  | absorb l x =>
    obtain ⟨hl, hx⟩ := hok
    have hne : (le64 (UInt64.ofNat l.length) ++ (l ++ (le64 (UInt64.ofNat x.length) ++ x))).length ≠ 15 := by
      simp only [List.length_append, length_le64]
      omega
    have e1 : (le64 (UInt64.ofNat l.length) ++ (l ++ (le64 (UInt64.ofNat x.length) ++ x))).take 8
        = le64 (UInt64.ofNat l.length) := List.take_left' (length_le64 _)
    have e2 : (le64 (UInt64.ofNat l.length) ++ (l ++ (le64 (UInt64.ofNat x.length) ++ x))).drop 8
        = l ++ (le64 (UInt64.ofNat x.length) ++ x) := List.drop_left' (length_le64 _)
    have e3 : (l ++ (le64 (UInt64.ofNat x.length) ++ x)).drop l.length = le64 (UInt64.ofNat x.length) ++ x :=
      List.drop_left' rfl
    have e4 : (l ++ (le64 (UInt64.ofNat x.length) ++ x)).take l.length = l := List.take_left' rfl
    have e5 : (le64 (UInt64.ofNat x.length) ++ x).take 8 = le64 (UInt64.ofNat x.length) :=
      List.take_left' (length_le64 _)
    have e6 : (le64 (UInt64.ofNat x.length) ++ x).drop 8 = x := List.drop_left' (length_le64 _)
    have hc1 : l.length + 8 ≤ (l ++ (le64 (UInt64.ofNat x.length) ++ x)).length := by
      simp only [List.length_append, length_le64]
      omega
    have hc2 : 8 ≤ (le64 (UInt64.ofNat l.length) ++ (l ++ (le64 (UInt64.ofNat x.length) ++ x))).length := by
      simp only [List.length_append, length_le64]
      omega
    simp only [decodeLink, TItem.msg, absorbMsg, List.take_left' hd, digOf?_toList, List.drop_left' hd, hne,
      false_and, ↓reduceIte, e1, e2, leNat_le64_ofNat hl, e3, e5, e6, leNat_le64_ofNat hx, e4, hl, hx, hc1, hc2,
      and_self, ↓reduceDIte]

/-- **A sufficient condition for the start premise**: a start string that is not 47 bytes long, and whose bytes 32–39
read as a length too large for the string, decodes as no link. For an ASCII domain string those bytes are text, so the
length they spell is at least `2^61`. -/
theorem decodeLink_none_of_long (m : List UInt8) (h47 : m.length ≠ 47)
    (hll : m.length < leNat ((m.drop 32).take 8) + 48) : decodeLink m = none := by
  unfold decodeLink
  split
  · rfl
  · have hsq : ¬ ((m.drop 32).length = 15 ∧ (m.drop 32).take 7 = squeezeTag) := by
      rintro ⟨h, -⟩
      rw [List.length_drop] at h
      omega
    simp only [hsq, ↓reduceIte]
    split
    · rename_i h
      exfalso
      have h1 := h.2.2.2.1
      simp only [List.length_drop] at h1
      omega
    · rfl

/-- The development rung's profile string (`hashtag.rs`'s `RUNG_G`), as bytes (`L5Check.lean` checks it is `ascii`
of the string). -/
def rungGDomain : List UInt8 :=
  [104, 97, 115, 104, 108, 105, 110, 101, 45, 122, 107, 45, 109, 114, 49, 47, 112, 114, 105, 118, 97, 116, 101, 45, 98,
    108, 111, 99, 107, 45, 114, 117, 110, 103, 45, 103, 45, 116, 50, 52, 45, 100, 101, 118, 47, 49]

/-- The start premise for one real domain string, by `decide` on the sufficient condition. -/
theorem startMsg_ok_rungG : decodeLink (startMsg rungGDomain) = none :=
  decodeLink_none_of_long _ (by decide) (by decide)

/-- **The code's transcript as a `ChainEnc`** (`FSChain.lean`), for one mode (`key`) and one domain string whose start
input decodes as no link (`hs`: checked per profile string, e.g. by `decide`). -/
def chainEnc (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) :
    ChainEnc It HIn Dig where
  start := ⟨key, startMsg domain⟩
  link d it := ⟨key, it.1.msg d⟩
  ldec q := if q.key = key then decodeLink q.msg else none
  ldec_link d it := by simp [decodeLink_msg]
  ldec_start := by simp [hs]

/-- The operations a verifier performs on a transcript. -/
inductive Op
  | absorb (label data : List UInt8)
  | squeeze

section Ops

variable (H : HIn → Dig)

/-- Run the operations. -/
def runOps : Tr → List Op → Tr
  | t, [] => t
  | t, .absorb l x :: ops => runOps (t.absorb H l x) ops
  | t, .squeeze :: ops => runOps (t.squeeze H).2 ops

/-- The chain items of the operations, the squeezes carrying the code's counter values from `ctr` on. -/
def opItems : UInt64 → List Op → List TItem
  | _, [] => []
  | c, .absorb l x :: ops => .absorb l x :: opItems c ops
  | c, .squeeze :: ops => .squeeze c :: opItems (c + 1) ops

/-- A squeeze's output is the chain digest of its item. -/
theorem squeeze_out (t : Tr) : (t.squeeze H).1 = H ⟨t.key, TItem.msg t.state (.squeeze t.counter)⟩ := rfl

/-- **The executable transcript is the chain**, from any point: if `τ`'s last digest is the state, every later state
is the chain's last digest, for every hash function `H`. -/
theorem runOps_chainFrom (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) :
    ∀ (ops : List Op) (t : Tr) (τ : List (It × Dig)) (its : List It), t.key = key →
      (chainEnc key domain hs).lastD H τ = t.state → its.map Subtype.val = opItems t.counter ops →
      (runOps H t ops).state = (chainEnc key domain hs).lastD H ((chainEnc key domain hs).chainFrom H τ its)
  | [], t, τ, its, _, hτ, hits => by
    have : its = [] := List.map_eq_nil_iff.mp hits
    subst this
    simpa [runOps, ChainEnc.chainFrom] using hτ.symm
  | .absorb l x :: ops, t, τ, its, hk, hτ, hits => by
    cases its with
    | nil => simp [opItems] at hits
    | cons it its =>
      simp only [List.map_cons, opItems, List.cons.injEq] at hits
      rw [runOps, ChainEnc.chainFrom]
      refine runOps_chainFrom key domain hs ops (t.absorb H l x) _ its hk ?_ hits.2
      rw [ChainEnc.lastD_snoc, hτ]
      show H ⟨key, it.1.msg t.state⟩ = H ⟨t.key, absorbMsg t.state l x⟩
      rw [hits.1, hk]
      rfl
  | .squeeze :: ops, t, τ, its, hk, hτ, hits => by
    cases its with
    | nil => simp [opItems] at hits
    | cons it its =>
      simp only [List.map_cons, opItems, List.cons.injEq] at hits
      rw [runOps, ChainEnc.chainFrom]
      refine runOps_chainFrom key domain hs ops (t.squeeze H).2 _ its hk ?_ hits.2
      rw [ChainEnc.lastD_snoc, hτ]
      show H ⟨key, it.1.msg t.state⟩ = H ⟨t.key, squeezeMsg t.state t.counter⟩
      rw [hits.1, hk]
      rfl

/-- **The executable transcript, from `new` / `new_tagged`, is `FSChain.lean`'s chain** of its items. -/
theorem runOps_chain (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (ops : List Op) (its : List It) (hits : its.map Subtype.val = opItems 0 ops) :
    (runOps H (Tr.newKeyed H domain key) ops).state
      = (chainEnc key domain hs).lastD H ((chainEnc key domain hs).chainFrom H [] its) :=
  runOps_chainFrom H key domain hs ops _ [] its rfl rfl hits

end Ops

/-! ## The challenges are `FSChallenge.lean`'s -/

theorem leNat_take16_lt (d : Dig) : leNat (d.toList.take 16) < 2 ^ 128 := by
  have h := leNat_lt (d.toList.take 16)
  have hl : (d.toList.take 16).length = 16 := by simp
  rw [hl] at h
  simpa using h

theorem leNat_drop16_lt (d : Dig) : leNat (d.toList.drop 16) < 2 ^ 128 := by
  have h := leNat_lt (d.toList.drop 16)
  have hl : (d.toList.drop 16).length = 16 := by simp
  rw [hl] at h
  simpa using h

/-- **`challenge_fp2` is `fp2Chal gP (2^128)`** of the digest's two 128-bit halves (`FSChallenge.lean`). -/
theorem challengeFp2Of_toGF (d : Dig) :
    ((challengeFp2Of d).c0.toGF, (challengeFp2Of d).c1.toGF)
      = fp2Chal gP (2 ^ 128) (⟨leNat (d.toList.take 16), leNat_take16_lt d⟩, ⟨leNat (d.toList.drop 16), leNat_drop16_lt d⟩) := by
  simp only [challengeFp2Of, Fp.fromU128, fp2Chal]
  rw [Fp.toGF_reduce128 _ (leNat_take16_lt d), Fp.toGF_reduce128 _ (leNat_drop16_lt d)]

/-- `challenge_fp` is the reduction of the digest's low half. -/
theorem challengeFpOf_toGF (d : Dig) : (challengeFpOf d).toGF = (leNat (d.toList.take 16) : ZK60.Circuit.GF) :=
  Fp.toGF_reduce128 _ (leNat_take16_lt d)

/-- **Each column index is `FSChallenge.lean`'s `idxChal h`** of its 8-byte chunk, for `bound = 2^h`. -/
theorem idx_eq_idxChal (h : ℕ) (c : List UInt8) (hc : c.length = 8) :
    leNat c &&& (2 ^ h - 1) = (idxChal h ⟨leNat c, by simpa [hc] using leNat_lt c⟩ : ℕ) := rfl

end ZK60.Exec
