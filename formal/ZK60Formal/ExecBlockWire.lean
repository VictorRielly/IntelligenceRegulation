/-
D63 step L9 (the per-profile verifier, its top level), part 1: the RECEIPT DECODER of one W16R2 block, executable.

What is mirrored (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/wire.rs` and `run_fork_wire.rs`, read 2026-11-07;
nothing there is changed):
* the bounded reader (`Reader`): `take` of a fixed count (refusal "truncated frame"), `fp` (an 8-byte little-endian word,
  REFUSED when `≥ p`: "noncanonical field word"; this is where the frame differs from `Fp2::from_bytes`, finding L5-2),
  `fp2` (two words, `c0` first), `fp2_vec`, `column` (an index REFUSED when `≥` the encoded width, the column's words,
  the 32-byte salt, the path's digests) and `hiding` (the group vectors, the proximity vector, the opened columns);
* one block's CORE (`CoreView`'s fields, `wire.rs`'s order): the `A`, `H` and `M` roots; per slot its scalar, its
  `n + e` rounds of `d + 1` values and its terminals; `M`'s opening (`q`, `prox`, `MASK_Q` columns); the `A` and `H`
  openings;
* the D55 FORK FRAME (`HLPFORK1`, `decode_fork`, production since D60): the counted length first, then the magic, the
  run binding, `L`, `k` and the start position tag, each COMPARED with the verifier's own and never adopted; the core;
  the end tag (returned to be compared after the replay); no trailing byte; `validate_fork`. Every count comes from
  the verifier's geometry `Geom`, never from the frame. The refusal strings are the code's.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `rdCore_ok`, `decodeFork_spec`: a frame that decodes is EXACTLY the encoding (`encCore`, `encFork`) of what it
  decodes to, and every field word of the result is canonical (`CoreCanon`). So the decoder refuses every word `≥ p`,
  and two different frames never decode to the same receipt (`decodeFork_injective`): a receipt has ONE encoding
  (finding L5-2 closed for the block decoder);
* `rdCore_enc`, `decodeFork_enc`: conversely, the encoding of a canonical receipt of the verifier's shape decodes back to
  it (the honest frame is accepted by the decoder);
* `CoreShape` is what the decoder guarantees about the counts, so the verifier's own counts are the frame's.

W16R3 (D67): B1 to B3 change no byte of this reader; B2's batched slots change only `Geom.slots` / `Geom.terms`.
-/
import ZK60Formal.ExecComposeFS

namespace ZK60.Exec.Block

open ZK60.Circuit (gP)

/-! ## The receipt -/

/-- `argument::SlotProof`: the slot's ONE published scalar, its sumcheck rounds, its masked terminals. -/
structure SlotProof where
  scalar : Fp2
  rounds : List (List Fp2)
  terms : List Fp2
  deriving DecidableEq, Repr

/-- One opened column: its index, its words, its salt, its Merkle path. -/
structure Column where
  j : ℕ
  col : List Fp
  salt : Dig
  path : List Dig
  deriving DecidableEq

/-- `pcs::OpeningZk`: the group vectors, the proximity vector, the opened columns. -/
structure OpeningZk where
  groupVecs : List (List Fp2)
  proxVec : List Fp2
  columns : List Column
  deriving DecidableEq

/-- `zk::MaskOpening`: `q`, the proximity combination, the opened columns. -/
structure MaskOpening where
  q : List Fp2
  prox : List Fp2
  columns : List Column
  deriving DecidableEq

/-- **One block's core** (`protocol::CoreView`, `wire::fork::ForkFrame`). -/
structure Core where
  aRoot : Dig
  hRoot : Dig
  maskRoot : Dig
  slots : List SlotProof
  maskOpen : MaskOpening
  aOpen : OpeningZk
  hOpen : OpeningZk
  deriving DecidableEq

/-! ## The verifier's geometry (never read from a frame) -/

/-- `wire::Dim`: opened columns, a clear vector's length (`n + Q`), the encoded width, the path length. -/
structure Dim where
  checks : ℕ
  vec : ℕ
  encCols : ℕ
  path : ℕ

/-- `Dim::opening_len`. -/
def Dim.openingLen (d : Dim) (groups rows : ℕ) : ℕ := (groups + 1) * d.vec * 16 + d.checks * (8 + rows * 8 + 32 + d.path * 32)

/-- **The geometry of one block's frame**, a function of the verifier's own shape and layout: per slot
`(n, e, d)` (`Layout::slots`) and its terminal count (`slot_terms`); `M`'s constants (`2·2^MASK_LOG_MSG`, `MASK_Q`,
`2^MASK_LOG_DOM`, `MASK_LOG_DOM`) and row count; the block `Dim`; the `A` / `H` groups and rows; the wire ceiling. -/
structure Geom where
  slots : List (ℕ × ℕ × ℕ)
  terms : List ℕ
  maskVec : ℕ
  maskChecks : ℕ
  maskDom : ℕ
  maskPath : ℕ
  mRows : ℕ
  blk : Dim
  aGroups : ℕ
  aRows : ℕ
  hGroups : ℕ
  hRows : ℕ
  ceiling : ℕ

/-- One slot's bytes (`slots_len`'s summand). -/
def slotLen (s : (ℕ × ℕ × ℕ) × ℕ) : ℕ := (1 + (s.1.1 + s.1.2.1) * (s.1.2.2 + 1) + s.2) * 16

def Geom.slotsLen (g : Geom) : ℕ := ((g.slots.zip g.terms).map slotLen).sum

def Geom.maskLen (g : Geom) : ℕ := 2 * g.maskVec * 16 + g.maskChecks * (8 + g.mRows * 8 + 32 + g.maskPath * 32)

/-- `fork_len`: magic, binding, `L`, `k`, the start tag, three roots, the slots, the three openings, the end tag. -/
def Geom.forkLen (g : Geom) : ℕ :=
  8 + 32 + 8 + 8 + 32 + 3 * 32 + g.slotsLen + g.maskLen + g.blk.openingLen g.aGroups g.aRows
    + g.blk.openingLen g.hGroups g.hRows + 32

/-! ## The reader -/

/-- A reader of a frame: from the remaining bytes, a value and the rest, or the code's refusal. -/
abbrev Rd (α : Type) : Type := List UInt8 → Except String (α × List UInt8)

/-- The reader that reads nothing. -/
def Rd.ret {α : Type} (a : α) : Rd α := fun bs => .ok (a, bs)

/-- One reader, then the next on what is left (the first refusal ends the frame). -/
def Rd.bnd {α β : Type} (r : Rd α) (f : α → Rd β) : Rd β := fun bs =>
  match r bs with
  | .ok (a, rest) => f a rest
  | .error e => .error e

def truncMsg : String := "private block wire: truncated frame"
def noncanonMsg : String := "private block wire: noncanonical field word"
def colIdxMsg : String := "private block wire: column index"

def Rd.fail {α : Type} (e : String) : Rd α := fun _ => .error e

/-- A refusal when `c` holds (the code's `if c { return Err(e) }`). -/
def Rd.guard (c : Prop) [Decidable c] (e : String) : Rd Unit := fun bs => if c then .error e else .ok ((), bs)

/-- `Reader::take::<K>` (the `k` bytes taken first, so a read costs `k`, not the frame's length). -/
def rdBytes (k : ℕ) : Rd (List UInt8) := fun bs =>
  if (bs.take k).length = k then .ok (bs.take k, bs.drop k) else .error truncMsg

/-- `take::<32>()` as a digest. -/
def rdDig : Rd Dig := Rd.bnd (rdBytes 32) fun b =>
  match digOf? b with
  | some d => Rd.ret d
  | none => Rd.fail truncMsg

/-- `u64::from_le_bytes(take::<8>())`. -/
def rdU64 : Rd UInt64 := Rd.bnd (rdBytes 8) fun b => Rd.ret (ofLE64 b)

/-- `Reader::fp`: a word `≥ p` is REFUSED. -/
def rdFp : Rd Fp := Rd.bnd rdU64 fun v => if v.toNat < gP then Rd.ret ⟨v⟩ else Rd.fail noncanonMsg

/-- `Reader::fp2`. -/
def rdFp2 : Rd Fp2 := Rd.bnd rdFp fun a => Rd.bnd rdFp fun b => Rd.ret ⟨a, b⟩

/-- `n` values of one reader, in order. -/
def rdMany {α : Type} (r : Rd α) : ℕ → Rd (List α)
  | 0 => Rd.ret []
  | n + 1 => Rd.bnd r fun a => Rd.bnd (rdMany r n) fun as => Rd.ret (a :: as)

/-- `Reader::column(rows, bound, path)`. -/
def rdColumn (rows bound path : ℕ) : Rd Column :=
  Rd.bnd rdU64 fun j => Rd.bnd (Rd.guard (bound ≤ j.toNat) colIdxMsg) fun _ =>
  Rd.bnd (rdMany rdFp rows) fun col => Rd.bnd rdDig fun salt => Rd.bnd (rdMany rdDig path) fun p =>
  Rd.ret ⟨j.toNat, col, salt, p⟩

/-- `Reader::hiding(d, groups, rows)`. -/
def rdHiding (d : Dim) (groups rows : ℕ) : Rd OpeningZk :=
  Rd.bnd (rdMany (rdMany rdFp2 d.vec) groups) fun gv => Rd.bnd (rdMany rdFp2 d.vec) fun pv =>
  Rd.bnd (rdMany (rdColumn rows d.encCols d.path) d.checks) fun cs => Rd.ret ⟨gv, pv, cs⟩

/-- One slot proof at `(n, e, d)` with `terms` terminals. -/
def rdSlot (s : (ℕ × ℕ × ℕ) × ℕ) : Rd SlotProof :=
  Rd.bnd rdFp2 fun scalar => Rd.bnd (rdMany (rdMany rdFp2 (s.1.2.2 + 1)) (s.1.1 + s.1.2.1)) fun rounds =>
  Rd.bnd (rdMany rdFp2 s.2) fun terms => Rd.ret ⟨scalar, rounds, terms⟩

def rdSlots : List ((ℕ × ℕ × ℕ) × ℕ) → Rd (List SlotProof)
  | [] => Rd.ret []
  | s :: ss => Rd.bnd (rdSlot s) fun p => Rd.bnd (rdSlots ss) fun ps => Rd.ret (p :: ps)

def rdMask (g : Geom) : Rd MaskOpening :=
  Rd.bnd (rdMany rdFp2 g.maskVec) fun q => Rd.bnd (rdMany rdFp2 g.maskVec) fun prox =>
  Rd.bnd (rdMany (rdColumn g.mRows g.maskDom g.maskPath) g.maskChecks) fun cs => Rd.ret ⟨q, prox, cs⟩

/-- **One block's core**, in `wire.rs`'s order. -/
def rdCore (g : Geom) : Rd Core :=
  Rd.bnd rdDig fun a => Rd.bnd rdDig fun h => Rd.bnd rdDig fun m => Rd.bnd (rdSlots (g.slots.zip g.terms)) fun slots =>
  Rd.bnd (rdMask g) fun mo => Rd.bnd (rdHiding g.blk g.aGroups g.aRows) fun ao =>
  Rd.bnd (rdHiding g.blk g.hGroups g.hRows) fun ho => Rd.ret ⟨a, h, m, slots, mo, ao, ho⟩

/-! ## The encoder (`write_bytes`, `encode_fork`) -/

def encFp2s (v : List Fp2) : List UInt8 := v.flatMap Fp2.toBytes

def encColumn (c : Column) : List UInt8 :=
  le64 (UInt64.ofNat c.j) ++ (c.col.flatMap Fp.toBytes ++ (c.salt.toList ++ c.path.flatMap (fun d => d.toList)))

def encHiding (o : OpeningZk) : List UInt8 :=
  o.groupVecs.flatMap encFp2s ++ (encFp2s o.proxVec ++ o.columns.flatMap encColumn)

def encSlot (p : SlotProof) : List UInt8 := p.scalar.toBytes ++ (p.rounds.flatMap encFp2s ++ encFp2s p.terms)

def encMask (m : MaskOpening) : List UInt8 := encFp2s m.q ++ (encFp2s m.prox ++ m.columns.flatMap encColumn)

def encCore (c : Core) : List UInt8 :=
  c.aRoot.toList ++ (c.hRoot.toList ++ (c.maskRoot.toList ++ (c.slots.flatMap encSlot ++ (encMask c.maskOpen
    ++ (encHiding c.aOpen ++ encHiding c.hOpen)))))

/-! ## The fork frame (`decode_fork`) -/

/-- `b"HLPFORK1"`. -/
def forkMagic : List UInt8 := [72, 76, 80, 70, 79, 82, 75, 49]

def encFork (bindg : Dig) (l k : ℕ) (startTag : Dig) (c : Core) (endTag : Dig) : List UInt8 :=
  forkMagic ++ (bindg.toList ++ (le64 (UInt64.ofNat l) ++ (le64 (UInt64.ofNat k) ++ (startTag.toList
    ++ (encCore c ++ endTag.toList)))))

/-- `fork_header`: each field COMPARED with the verifier's own. -/
def rdForkHeader (bindg : Dig) (l k : ℕ) (startTag : Dig) : Rd Unit :=
  Rd.bnd (rdBytes 8) fun mg => Rd.bnd (Rd.guard (mg ≠ forkMagic) "D55 wire: fork frame profile") fun _ =>
  Rd.bnd rdDig fun b => Rd.bnd (Rd.guard (b ≠ bindg) s!"D55 wire: fork frame {k} belongs to another run") fun _ =>
  Rd.bnd rdU64 fun l' => Rd.bnd rdU64 fun k' =>
  Rd.bnd (Rd.guard (l'.toNat ≠ l % 2 ^ 64 ∨ k'.toNat ≠ k % 2 ^ 64)
    s!"D55 wire: frame {k} is not the {l}-block run's fork {k}") fun _ =>
  Rd.bnd rdDig fun st =>
  Rd.guard (st ≠ startTag) s!"D55 wire: fork frame {k}'s start tag is not the verifier's own fork-{k} position"

/-- The fork frame after its length check: the header, the core, the end tag. -/
def rdForkBody (g : Geom) (bindg : Dig) (l k : ℕ) (startTag : Dig) : Rd (Core × Dig) :=
  Rd.bnd (rdForkHeader bindg l k startTag) fun _ => Rd.bnd (rdCore g) fun c => Rd.bnd rdDig fun e => Rd.ret (c, e)

/-- `validate_fork`: the counts the geometry declares (always true of a decoded core; kept as the code keeps it). -/
def CoreShape (g : Geom) (c : Core) : Prop :=
  c.slots.length = g.slots.length
  ∧ (∀ (i : ℕ) (p : SlotProof) (s : ℕ × ℕ × ℕ) (t : ℕ), c.slots[i]? = some p → g.slots[i]? = some s →
      g.terms[i]? = some t → p.rounds.length = s.1 + s.2.1 ∧ (∀ r ∈ p.rounds, r.length = s.2.2 + 1) ∧ p.terms.length = t)
  ∧ c.maskOpen.q.length = g.maskVec ∧ c.maskOpen.prox.length = g.maskVec ∧ c.maskOpen.columns.length = g.maskChecks
  ∧ (∀ col ∈ c.maskOpen.columns, col.j < g.maskDom ∧ col.col.length = g.mRows ∧ col.path.length = g.maskPath)
  ∧ (∀ o ∈ [c.aOpen, c.hOpen], o.proxVec.length = g.blk.vec ∧ (∀ v ∈ o.groupVecs, v.length = g.blk.vec)
      ∧ o.columns.length = g.blk.checks ∧ ∀ col ∈ o.columns, col.j < g.blk.encCols ∧ col.path.length = g.blk.path)
  ∧ c.aOpen.groupVecs.length = g.aGroups ∧ c.hOpen.groupVecs.length = g.hGroups
  ∧ (∀ col ∈ c.aOpen.columns, col.col.length = g.aRows) ∧ (∀ col ∈ c.hOpen.columns, col.col.length = g.hRows)

/-- **`decode_fork`**: the frame of fork `k` of an `L`-block run, against the verifier's binding and start position.
Returns the core and the end tag (to be compared after the replay). -/
def decodeFork (g : Geom) (bindg : Dig) (l k : ℕ) (startTag : Dig) (bytes : List UInt8) : Except String (Core × Dig) :=
  if bytes.length ≠ g.forkLen ∨ g.ceiling < g.forkLen then
    .error s!"D55 wire: fork frame {k} is {bytes.length} B, the counted length is {g.forkLen}"
  else
    match rdForkBody g bindg l k startTag bytes with
    | .error e => .error e
    | .ok (r, rest) => if rest ≠ [] then .error "D55 wire: trailing bytes in a fork frame" else .ok r

/-! ## Canonical receipts -/

def ColCanon (c : Column) : Prop := ∀ x ∈ c.col, x.Canon

def HidingCanon (o : OpeningZk) : Prop :=
  (∀ v ∈ o.groupVecs, ∀ x ∈ v, x.Canon) ∧ (∀ x ∈ o.proxVec, x.Canon) ∧ ∀ c ∈ o.columns, ColCanon c

def SlotCanon (p : SlotProof) : Prop := p.scalar.Canon ∧ (∀ r ∈ p.rounds, ∀ x ∈ r, x.Canon) ∧ ∀ x ∈ p.terms, x.Canon

def MaskCanon (m : MaskOpening) : Prop := (∀ x ∈ m.q, x.Canon) ∧ (∀ x ∈ m.prox, x.Canon) ∧ ∀ c ∈ m.columns, ColCanon c

/-- **Every field word of the core is canonical** (`< p`). -/
def CoreCanon (c : Core) : Prop :=
  (∀ p ∈ c.slots, SlotCanon p) ∧ MaskCanon c.maskOpen ∧ HidingCanon c.aOpen ∧ HidingCanon c.hOpen

/-! ## Bytes -/

theorem leBytes_leNat : ∀ (bs : List UInt8), leBytes bs.length (leNat bs) = bs
  | [] => rfl
  | b :: bs => by
    have hb := b.toNat_lt
    simp only [List.length_cons, leBytes, leNat]
    have h1 : (b.toNat + 256 * leNat bs) / 256 = leNat bs := by omega
    rw [h1, leBytes_leNat bs]
    congr 1
    apply UInt8.toNat_inj.mp
    rw [UInt8.toNat_ofNat']
    show (b.toNat + 256 * leNat bs) % 256 = b.toNat
    omega

theorem le64_ofLE64 (bs : List UInt8) (h : bs.length = 8) : le64 (ofLE64 bs) = bs := by
  have hlt := leNat_lt bs
  rw [h] at hlt
  rw [le64, ofLE64, UInt64.toNat_ofNat', Nat.mod_eq_of_lt (by simpa using hlt), ← h, leBytes_leNat]

theorem fp2_toBytes_length (a : Fp2) : a.toBytes.length = 16 := by
  simp [Fp2.toBytes, Fp.toBytes, le64_length]

theorem digOf?_some {l : List UInt8} {d : Dig} (h : digOf? l = some d) : d.toList = l := by
  unfold digOf? at h
  split at h
  · cases h
    rfl
  · cases h

/-! ## The reader's lemmas -/

theorem Rd.bnd_ok {α β : Type} {r : Rd α} {f : α → Rd β} {bs : List UInt8} {b : β} {rest : List UInt8}
    (h : Rd.bnd r f bs = .ok (b, rest)) : ∃ a mid, r bs = .ok (a, mid) ∧ f a mid = .ok (b, rest) := by
  unfold Rd.bnd at h
  split at h
  · rename_i a mid hr
    exact ⟨a, mid, hr, h⟩
  · cases h

theorem Rd.ret_ok {α : Type} {a b : α} {bs rest : List UInt8} (h : Rd.ret a bs = .ok (b, rest)) :
    b = a ∧ rest = bs := by
  unfold Rd.ret at h
  cases h
  exact ⟨rfl, rfl⟩

theorem Rd.ret_apply {α : Type} (a : α) (bs : List UInt8) : Rd.ret a bs = .ok (a, bs) := rfl

theorem Rd.fail_ok {α : Type} {e : String} {bs : List UInt8} {b : α} {rest : List UInt8} :
    ¬ Rd.fail e bs = .ok (b, rest) := by simp [Rd.fail]

theorem Rd.guard_ok {c : Prop} [Decidable c] {e : String} {bs rest : List UInt8} {u : Unit}
    (h : Rd.guard c e bs = .ok (u, rest)) : ¬ c ∧ rest = bs := by
  unfold Rd.guard at h
  split at h
  · cases h
  · rename_i hc
    cases h
    exact ⟨hc, rfl⟩

theorem Rd.guard_enc {c : Prop} [Decidable c] {e : String} (bs : List UInt8) (hc : ¬ c) :
    Rd.guard c e bs = .ok ((), bs) := by
  unfold Rd.guard
  simp [hc]

theorem Rd.bnd_of_ok {α β : Type} {r : Rd α} {f : α → Rd β} {bs : List UInt8} {a : α} {mid : List UInt8}
    (h : r bs = .ok (a, mid)) : Rd.bnd r f bs = f a mid := by
  unfold Rd.bnd
  rw [h]

theorem rdBytes_ok {k : ℕ} {bs b rest : List UInt8} (h : rdBytes k bs = .ok (b, rest)) :
    bs = b ++ rest ∧ b.length = k := by
  unfold rdBytes at h
  split at h
  · rename_i hk
    cases h
    exact ⟨(List.take_append_drop k bs).symm, hk⟩
  · cases h

theorem rdBytes_enc (b rest : List UInt8) (k : ℕ) (hk : b.length = k) : rdBytes k (b ++ rest) = .ok (b, rest) := by
  subst hk
  simp [rdBytes]

theorem rdDig_ok {bs rest : List UInt8} {d : Dig} (h : rdDig bs = .ok (d, rest)) : bs = d.toList ++ rest := by
  obtain ⟨b, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨hb, -⟩ := rdBytes_ok e1
  cases hd : digOf? b with
  | none =>
    simp only [hd] at e2
    exact absurd e2 Rd.fail_ok
  | some d' =>
    simp only [hd] at e2
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok e2
    rw [hb, digOf?_some hd]

theorem rdDig_enc (d : Dig) (rest : List UInt8) : rdDig (d.toList ++ rest) = .ok (d, rest) := by
  unfold rdDig
  rw [Rd.bnd_of_ok (rdBytes_enc d.toList rest 32 d.2), digOf?_toList]
  rfl

theorem rdU64_ok {bs rest : List UInt8} {v : UInt64} (h : rdU64 bs = .ok (v, rest)) : bs = le64 v ++ rest := by
  obtain ⟨b, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨rfl, rfl⟩ := Rd.ret_ok e2
  obtain ⟨hb, hl⟩ := rdBytes_ok e1
  rw [le64_ofLE64 b hl]
  exact hb

theorem rdU64_enc (v : UInt64) (rest : List UInt8) : rdU64 (le64 v ++ rest) = .ok (v, rest) := by
  unfold rdU64
  rw [Rd.bnd_of_ok (rdBytes_enc (le64 v) rest 8 (le64_length v)), Rd.ret_apply, ofLE64_le64]

theorem rdFp_ok {bs rest : List UInt8} {x : Fp} (h : rdFp bs = .ok (x, rest)) : bs = x.toBytes ++ rest ∧ x.Canon := by
  obtain ⟨v, m1, e1, e2⟩ := Rd.bnd_ok h
  have hv := rdU64_ok e1
  revert e2
  split
  · rename_i hlt
    intro e2
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok e2
    exact ⟨hv, hlt⟩
  · intro e2
    exact absurd e2 Rd.fail_ok

theorem rdFp_enc (x : Fp) (hx : x.Canon) (rest : List UInt8) : rdFp (x.toBytes ++ rest) = .ok (x, rest) := by
  unfold rdFp
  rw [Fp.toBytes, Rd.bnd_of_ok (rdU64_enc x.v rest)]
  simp only [show x.v.toNat < gP from hx, ↓reduceIte]
  rfl

theorem rdFp2_ok {bs rest : List UInt8} {x : Fp2} (h : rdFp2 bs = .ok (x, rest)) :
    bs = x.toBytes ++ rest ∧ x.Canon := by
  obtain ⟨a, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨b, m2, e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨rfl, rfl⟩ := Rd.ret_ok e4
  obtain ⟨ha, hac⟩ := rdFp_ok e1
  obtain ⟨hb, hbc⟩ := rdFp_ok e3
  refine ⟨?_, hac, hbc⟩
  rw [ha, hb, Fp2.toBytes, List.append_assoc]

theorem rdFp2_enc (x : Fp2) (hx : x.Canon) (rest : List UInt8) : rdFp2 (x.toBytes ++ rest) = .ok (x, rest) := by
  unfold rdFp2
  rw [Fp2.toBytes, List.append_assoc, Rd.bnd_of_ok (rdFp_enc x.c0 hx.1 _), Rd.bnd_of_ok (rdFp_enc x.c1 hx.2 _)]
  rfl

/-- **The generic step**: `n` values of a faithful reader are the concatenation of their encodings. -/
theorem rdMany_ok {α : Type} {r : Rd α} {enc : α → List UInt8} {P : α → Prop}
    (hr : ∀ bs a rest, r bs = .ok (a, rest) → bs = enc a ++ rest ∧ P a) :
    ∀ (n : ℕ) (bs : List UInt8) (as : List α) (rest : List UInt8), rdMany r n bs = .ok (as, rest) →
      bs = as.flatMap enc ++ rest ∧ as.length = n ∧ ∀ a ∈ as, P a
  | 0, bs, as, rest, h => by
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok h
    simp
  | n + 1, bs, as, rest, h => by
    obtain ⟨a, m1, e1, e2⟩ := Rd.bnd_ok h
    obtain ⟨as', m2, e3, e4⟩ := Rd.bnd_ok e2
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok e4
    obtain ⟨ha, hp⟩ := hr _ _ _ e1
    obtain ⟨has, hl, hps⟩ := rdMany_ok hr n _ _ _ e3
    refine ⟨?_, by simp [hl], ?_⟩
    · rw [ha, has, List.flatMap_cons, List.append_assoc]
    · intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hp
      · exact hps x hx

theorem rdMany_enc {α : Type} {r : Rd α} {enc : α → List UInt8} {P : α → Prop}
    (hr : ∀ a rest, P a → r (enc a ++ rest) = .ok (a, rest)) :
    ∀ (as : List α) (rest : List UInt8), (∀ a ∈ as, P a) → rdMany r as.length (as.flatMap enc ++ rest) = .ok (as, rest)
  | [], rest, _ => rfl
  | a :: as, rest, hP => by
    rw [List.length_cons, List.flatMap_cons, List.append_assoc, rdMany,
      Rd.bnd_of_ok (hr a _ (hP a List.mem_cons_self)),
      Rd.bnd_of_ok (rdMany_enc hr as rest (fun x hx => hP x (List.mem_cons_of_mem _ hx)))]
    rfl

/-- `n` canonical words read back from their bytes. -/
theorem rdManyFp2_enc (k : ℕ) (v : List Fp2) (rest : List UInt8) (h : v.length = k ∧ ∀ x ∈ v, x.Canon) :
    rdMany rdFp2 k (encFp2s v ++ rest) = .ok (v, rest) := by
  rw [← h.1]
  exact rdMany_enc (fun a rest ha => rdFp2_enc a ha rest) v rest h.2

theorem rdManyFp2_ok (k : ℕ) {bs : List UInt8} {a : List Fp2} {rest : List UInt8}
    (h : rdMany rdFp2 k bs = .ok (a, rest)) : bs = encFp2s a ++ rest ∧ (a.length = k ∧ ∀ x ∈ a, x.Canon) := by
  obtain ⟨e, l, c⟩ := rdMany_ok (fun bs a rest h => rdFp2_ok (bs := bs) (rest := rest) (x := a) h) k bs a rest h
  exact ⟨e, l, c⟩

theorem rdColumn_ok {rows bound path : ℕ} {bs rest : List UInt8} {c : Column}
    (h : rdColumn rows bound path bs = .ok (c, rest)) :
    bs = encColumn c ++ rest ∧ (ColCanon c ∧ c.j < bound ∧ c.col.length = rows ∧ c.path.length = path) := by
  obtain ⟨j, m1, e1, e2⟩ := Rd.bnd_ok h
  have hj := rdU64_ok e1
  obtain ⟨u, m1', e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨hb, hm⟩ := Rd.guard_ok e3
  subst hm
  obtain ⟨col, m2, e5, e6⟩ := Rd.bnd_ok e4
  obtain ⟨salt, m3, e7, e8⟩ := Rd.bnd_ok e6
  obtain ⟨p, m4, e9, e10⟩ := Rd.bnd_ok e8
  obtain ⟨hc', hr'⟩ := Rd.ret_ok e10
  subst hc' hr'
  obtain ⟨hc, hcl, hcc⟩ := rdMany_ok (fun bs a rest h => rdFp_ok (bs := bs) (rest := rest) (x := a) h) rows _ _ _ e5
  have hs := rdDig_ok e7
  obtain ⟨hp, hpl, -⟩ := rdMany_ok (P := fun _ => True) (enc := fun d : Dig => d.toList)
    (fun bs a rest h => ⟨rdDig_ok h, trivial⟩) path _ _ _ e9
  refine ⟨?_, hcc, (show j.toNat < bound by omega), hcl, hpl⟩
  rw [hj, hc, hs, hp, encColumn, UInt64.ofNat_toNat]
  simp only [List.append_assoc]

theorem rdColumn_enc (rows bound path : ℕ) (c : Column) (hc : ColCanon c) (hj : c.j < bound) (hb : bound ≤ 2 ^ 64)
    (hrows : c.col.length = rows) (hpath : c.path.length = path) (rest : List UInt8) :
    rdColumn rows bound path (encColumn c ++ rest) = .ok (c, rest) := by
  have hj64 : c.j < 2 ^ 64 := by omega
  have hjv : (UInt64.ofNat c.j).toNat = c.j := by rw [UInt64.toNat_ofNat', Nat.mod_eq_of_lt hj64]
  subst hrows hpath
  unfold rdColumn
  rw [encColumn]
  simp only [List.append_assoc]
  rw [Rd.bnd_of_ok (rdU64_enc _ _),
    Rd.bnd_of_ok (Rd.guard_enc (c := bound ≤ (UInt64.ofNat c.j).toNat) _ (by rw [hjv]; omega)),
    Rd.bnd_of_ok (rdMany_enc (fun a rest h => rdFp_enc a h rest) c.col _ hc),
    Rd.bnd_of_ok (rdDig_enc _ _),
    Rd.bnd_of_ok (rdMany_enc (P := fun _ => True) (fun a rest _ => rdDig_enc a rest) c.path _ (fun _ _ => trivial)),
    Rd.ret_apply, hjv]

theorem rdHiding_ok {d : Dim} {groups rows : ℕ} {bs rest : List UInt8} {o : OpeningZk}
    (h : rdHiding d groups rows bs = .ok (o, rest)) :
    bs = encHiding o ++ rest ∧ HidingCanon o ∧ o.groupVecs.length = groups ∧ (∀ v ∈ o.groupVecs, v.length = d.vec)
      ∧ o.proxVec.length = d.vec ∧ o.columns.length = d.checks
      ∧ ∀ c ∈ o.columns, c.j < d.encCols ∧ c.col.length = rows ∧ c.path.length = d.path := by
  obtain ⟨gv, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨pv, m2, e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨cs, m3, e5, e6⟩ := Rd.bnd_ok e4
  obtain ⟨ho, hr⟩ := Rd.ret_ok e6
  subst ho hr
  obtain ⟨hg, hgl, hgc⟩ := rdMany_ok (fun bs a rest h => rdManyFp2_ok d.vec (bs := bs) (a := a) (rest := rest) h)
    groups _ _ _ e1
  obtain ⟨hp, hpl, hpc⟩ := rdManyFp2_ok d.vec e3
  obtain ⟨hc, hcl, hcc⟩ := rdMany_ok (fun bs a rest h => rdColumn_ok (bs := bs) (rest := rest) (c := a) h) d.checks
    _ _ _ e5
  refine ⟨?_, ⟨fun v hv' => (hgc v hv').2, hpc, fun c hc' => (hcc c hc').1⟩, hgl, fun v hv' => (hgc v hv').1, hpl, hcl,
    fun c hc' => (hcc c hc').2⟩
  rw [hg, hp, hc, encHiding]
  simp only [List.append_assoc]

theorem rdHiding_enc (d : Dim) (groups rows : ℕ) (o : OpeningZk) (hcan : HidingCanon o) (hg : o.groupVecs.length = groups)
    (hgv : ∀ v ∈ o.groupVecs, v.length = d.vec) (hpv : o.proxVec.length = d.vec) (hcs : o.columns.length = d.checks)
    (hcols : ∀ c ∈ o.columns, c.j < d.encCols ∧ c.col.length = rows ∧ c.path.length = d.path) (henc : d.encCols ≤ 2 ^ 64)
    (rest : List UInt8) : rdHiding d groups rows (encHiding o ++ rest) = .ok (o, rest) := by
  subst hg
  unfold rdHiding
  rw [encHiding]
  simp only [List.append_assoc]
  rw [Rd.bnd_of_ok (rdMany_enc (fun v rest h => rdManyFp2_enc d.vec v rest h) o.groupVecs _
      (fun v hv' => ⟨hgv v hv', hcan.1 v hv'⟩)),
    Rd.bnd_of_ok (rdManyFp2_enc d.vec o.proxVec _ ⟨hpv, hcan.2.1⟩), ← hcs,
    Rd.bnd_of_ok (rdMany_enc (P := fun c => ColCanon c ∧ c.j < d.encCols ∧ c.col.length = rows ∧ c.path.length = d.path)
      (fun c rest h => rdColumn_enc rows d.encCols d.path c h.1 h.2.1 henc h.2.2.1 h.2.2.2 rest) o.columns _
      (fun c hc => ⟨hcan.2.2 c hc, hcols c hc⟩))]
  rfl

theorem rdSlot_ok {s : (ℕ × ℕ × ℕ) × ℕ} {bs rest : List UInt8} {p : SlotProof} (h : rdSlot s bs = .ok (p, rest)) :
    bs = encSlot p ++ rest ∧ SlotCanon p ∧ p.rounds.length = s.1.1 + s.1.2.1
      ∧ (∀ r ∈ p.rounds, r.length = s.1.2.2 + 1) ∧ p.terms.length = s.2 := by
  obtain ⟨sc, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨rs, m2, e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨ts, m3, e5, e6⟩ := Rd.bnd_ok e4
  obtain ⟨hp', hr'⟩ := Rd.ret_ok e6
  subst hp' hr'
  obtain ⟨hs, hsc⟩ := rdFp2_ok e1
  obtain ⟨hr, hrl, hrc⟩ := rdMany_ok (fun bs a rest h => rdManyFp2_ok (s.1.2.2 + 1) (bs := bs) (a := a) (rest := rest) h)
    _ _ _ _ e3
  obtain ⟨ht, htl, htc⟩ := rdManyFp2_ok s.2 e5
  refine ⟨?_, ⟨hsc, fun r hr' => (hrc r hr').2, htc⟩, hrl, fun r hr' => (hrc r hr').1, htl⟩
  rw [hs, hr, ht, encSlot]
  simp only [List.append_assoc]

theorem rdSlot_enc (s : (ℕ × ℕ × ℕ) × ℕ) (p : SlotProof) (hcan : SlotCanon p) (hrl : p.rounds.length = s.1.1 + s.1.2.1)
    (hr : ∀ r ∈ p.rounds, r.length = s.1.2.2 + 1) (ht : p.terms.length = s.2) (rest : List UInt8) :
    rdSlot s (encSlot p ++ rest) = .ok (p, rest) := by
  unfold rdSlot
  rw [encSlot, List.append_assoc, Rd.bnd_of_ok (rdFp2_enc _ hcan.1 _), List.append_assoc, ← hrl,
    Rd.bnd_of_ok (rdMany_enc (fun v rest h => rdManyFp2_enc (s.1.2.2 + 1) v rest h) p.rounds _
      (fun r h => ⟨hr r h, hcan.2.1 r h⟩)),
    Rd.bnd_of_ok (rdManyFp2_enc s.2 p.terms rest ⟨ht, hcan.2.2⟩)]
  rfl

theorem rdSlots_ok : ∀ (ss : List ((ℕ × ℕ × ℕ) × ℕ)) {bs rest : List UInt8} {ps : List SlotProof},
    rdSlots ss bs = .ok (ps, rest) →
    bs = ps.flatMap encSlot ++ rest ∧ ps.length = ss.length ∧ (∀ p ∈ ps, SlotCanon p)
      ∧ ∀ (i : ℕ) (p : SlotProof) (s : (ℕ × ℕ × ℕ) × ℕ), ps[i]? = some p → ss[i]? = some s →
        p.rounds.length = s.1.1 + s.1.2.1 ∧ (∀ r ∈ p.rounds, r.length = s.1.2.2 + 1) ∧ p.terms.length = s.2
  | [], bs, rest, ps, h => by
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok h
    simp
  | s :: ss, bs, rest, ps, h => by
    obtain ⟨p, m1, e1, e2⟩ := Rd.bnd_ok h
    obtain ⟨ps', m2, e3, e4⟩ := Rd.bnd_ok e2
    obtain ⟨hps, hrest⟩ := Rd.ret_ok e4
    subst hps hrest
    obtain ⟨hp, hpc, hpr, hpr', hpt⟩ := rdSlot_ok e1
    obtain ⟨hps, hl, hc, hsh⟩ := rdSlots_ok ss e3
    refine ⟨?_, by simp [hl], ?_, ?_⟩
    · rw [hp, hps, List.flatMap_cons, List.append_assoc]
    · intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hpc
      · exact hc x hx
    · intro i q t hq ht
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at hq ht
        subst hq ht
        exact ⟨hpr, hpr', hpt⟩
      | succ i => exact hsh i q t (by simpa using hq) (by simpa using ht)

theorem rdSlots_enc : ∀ (ss : List ((ℕ × ℕ × ℕ) × ℕ)) (ps : List SlotProof) (rest : List UInt8),
    ps.length = ss.length → (∀ p ∈ ps, SlotCanon p) →
    (∀ (i : ℕ) (p : SlotProof) (s : (ℕ × ℕ × ℕ) × ℕ), ps[i]? = some p → ss[i]? = some s →
        p.rounds.length = s.1.1 + s.1.2.1 ∧ (∀ r ∈ p.rounds, r.length = s.1.2.2 + 1) ∧ p.terms.length = s.2) →
    rdSlots ss (ps.flatMap encSlot ++ rest) = .ok (ps, rest)
  | [], [], _, _, _, _ => rfl
  | [], _ :: _, _, hl, _, _ => by simp at hl
  | _ :: _, [], _, hl, _, _ => by simp at hl
  | s :: ss, p :: ps, rest, hl, hc, hsh => by
    obtain ⟨h1, h2, h3⟩ := hsh 0 p s rfl rfl
    rw [List.flatMap_cons, List.append_assoc, rdSlots, Rd.bnd_of_ok (rdSlot_enc s p (hc p List.mem_cons_self) h1 h2 h3 _),
      Rd.bnd_of_ok (rdSlots_enc ss ps rest (by simpa using hl) (fun q hq => hc q (List.mem_cons_of_mem _ hq))
        (fun i q t e1 e2 => hsh (i + 1) q t (by simpa using e1) (by simpa using e2)))]
    rfl

theorem rdMask_ok {g : Geom} {bs rest : List UInt8} {m : MaskOpening} (h : rdMask g bs = .ok (m, rest)) :
    bs = encMask m ++ rest ∧ MaskCanon m ∧ m.q.length = g.maskVec ∧ m.prox.length = g.maskVec
      ∧ m.columns.length = g.maskChecks
      ∧ ∀ c ∈ m.columns, c.j < g.maskDom ∧ c.col.length = g.mRows ∧ c.path.length = g.maskPath := by
  obtain ⟨q, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨pv, m2, e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨cs, m3, e5, e6⟩ := Rd.bnd_ok e4
  obtain ⟨hm, hr⟩ := Rd.ret_ok e6
  subst hm hr
  obtain ⟨hq, hql, hqc⟩ := rdManyFp2_ok g.maskVec e1
  obtain ⟨hp, hpl, hpc⟩ := rdManyFp2_ok g.maskVec e3
  obtain ⟨hc, hcl, hcc⟩ := rdMany_ok (fun bs a rest h => rdColumn_ok (bs := bs) (rest := rest) (c := a) h) _ _ _ _ e5
  refine ⟨?_, ⟨hqc, hpc, fun c hc' => (hcc c hc').1⟩, hql, hpl, hcl, fun c hc' => (hcc c hc').2⟩
  rw [hq, hp, hc, encMask]
  simp only [List.append_assoc]

theorem rdMask_enc (g : Geom) (m : MaskOpening) (hcan : MaskCanon m) (hq : m.q.length = g.maskVec)
    (hp : m.prox.length = g.maskVec) (hcs : m.columns.length = g.maskChecks)
    (hcols : ∀ c ∈ m.columns, c.j < g.maskDom ∧ c.col.length = g.mRows ∧ c.path.length = g.maskPath)
    (hdom : g.maskDom ≤ 2 ^ 64) (rest : List UInt8) : rdMask g (encMask m ++ rest) = .ok (m, rest) := by
  unfold rdMask
  rw [encMask]
  simp only [List.append_assoc]
  rw [Rd.bnd_of_ok (rdManyFp2_enc g.maskVec m.q _ ⟨hq, hcan.1⟩),
    Rd.bnd_of_ok (rdManyFp2_enc g.maskVec m.prox _ ⟨hp, hcan.2.1⟩), ← hcs,
    Rd.bnd_of_ok (rdMany_enc
      (P := fun c => ColCanon c ∧ c.j < g.maskDom ∧ c.col.length = g.mRows ∧ c.path.length = g.maskPath)
      (fun c rest h => rdColumn_enc g.mRows g.maskDom g.maskPath c h.1 h.2.1 hdom h.2.2.1 h.2.2.2 rest) m.columns _
      (fun c hc => ⟨hcan.2.2 c hc, hcols c hc⟩))]
  rfl

/-- **A core that decodes is the encoding of what it decodes to; its words are canonical; its counts are the
geometry's.** -/
theorem rdCore_ok {g : Geom} (hgt : g.slots.length = g.terms.length) {bs rest : List UInt8} {c : Core}
    (h : rdCore g bs = .ok (c, rest)) : bs = encCore c ++ rest ∧ CoreCanon c ∧ CoreShape g c := by
  obtain ⟨a, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨hr, m2, e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨mr, m3, e5, e6⟩ := Rd.bnd_ok e4
  obtain ⟨ss, m4, e7, e8⟩ := Rd.bnd_ok e6
  obtain ⟨mo, m5, e9, e10⟩ := Rd.bnd_ok e8
  obtain ⟨ao, m6, e11, e12⟩ := Rd.bnd_ok e10
  obtain ⟨ho, m7, e13, e14⟩ := Rd.bnd_ok e12
  obtain ⟨hcd, hrd⟩ := Rd.ret_ok e14
  subst hcd hrd
  have ea := rdDig_ok e1
  have eh := rdDig_ok e3
  have em := rdDig_ok e5
  obtain ⟨es, hsl, hsc, hsh⟩ := rdSlots_ok _ e7
  obtain ⟨emo, hmc, hmq, hmp, hmcs, hmcols⟩ := rdMask_ok e9
  obtain ⟨eao, hac, hag, hagv, hapv, hacs, hacols⟩ := rdHiding_ok e11
  obtain ⟨eho, hhc, hhg, hhgv, hhpv, hhcs, hhcols⟩ := rdHiding_ok e13
  refine ⟨?_, ⟨hsc, hmc, hac, hhc⟩, ?_⟩
  · rw [ea, eh, em, es, emo, eao, eho, encCore]
    simp only [List.append_assoc]
  · refine ⟨by rw [hsl, List.length_zip, hgt, min_self], ?_, hmq, hmp, hmcs, fun col hc => hmcols col hc, ?_, hag, hhg,
      fun col hc => (hacols col hc).2.1, fun col hc => (hhcols col hc).2.1⟩
    · intro i p s t hp hs ht
      have hz : (g.slots.zip g.terms)[i]? = some (s, t) := by simp [List.getElem?_zip_eq_some, hs, ht]
      exact hsh i p (s, t) hp hz
    · intro o ho'
      simp only [List.mem_cons, List.not_mem_nil, or_false] at ho'
      rcases ho' with rfl | rfl
      · exact ⟨hapv, hagv, hacs, fun col hc => ⟨(hacols col hc).1, (hacols col hc).2.2⟩⟩
      · exact ⟨hhpv, hhgv, hhcs, fun col hc => ⟨(hhcols col hc).1, (hhcols col hc).2.2⟩⟩

theorem rdCore_enc (g : Geom) (hgt : g.slots.length = g.terms.length) (hdom : g.maskDom ≤ 2 ^ 64)
    (henc : g.blk.encCols ≤ 2 ^ 64) (c : Core) (hcan : CoreCanon c) (hsh : CoreShape g c) (rest : List UInt8) :
    rdCore g (encCore c ++ rest) = .ok (c, rest) := by
  obtain ⟨hsl, hss, hmq, hmp, hmcs, hmcols, hops, hag, hhg, harows, hhrows⟩ := hsh
  have hA := hops c.aOpen (by simp)
  have hH := hops c.hOpen (by simp)
  have hzip : ∀ (i : ℕ) (p : SlotProof) (st : (ℕ × ℕ × ℕ) × ℕ), c.slots[i]? = some p → (g.slots.zip g.terms)[i]? = some st →
      p.rounds.length = st.1.1 + st.1.2.1 ∧ (∀ r ∈ p.rounds, r.length = st.1.2.2 + 1) ∧ p.terms.length = st.2 := by
    intro i p st hp hst
    obtain ⟨hs, ht⟩ := List.getElem?_zip_eq_some.mp hst
    exact hss i p st.1 st.2 hp hs ht
  unfold rdCore
  rw [encCore]
  simp only [List.append_assoc]
  rw [Rd.bnd_of_ok (rdDig_enc _ _), Rd.bnd_of_ok (rdDig_enc _ _), Rd.bnd_of_ok (rdDig_enc _ _),
    Rd.bnd_of_ok (rdSlots_enc (g.slots.zip g.terms) c.slots _ (by rw [List.length_zip, ← hgt, min_self, hsl])
      hcan.1 hzip),
    Rd.bnd_of_ok (rdMask_enc g c.maskOpen hcan.2.1 hmq hmp hmcs hmcols hdom _),
    Rd.bnd_of_ok (rdHiding_enc g.blk g.aGroups g.aRows c.aOpen hcan.2.2.1 hag hA.2.1 hA.1 hA.2.2.1
      (fun col hc => ⟨(hA.2.2.2 col hc).1, harows col hc, (hA.2.2.2 col hc).2⟩) henc _),
    Rd.bnd_of_ok (rdHiding_enc g.blk g.hGroups g.hRows c.hOpen hcan.2.2.2 hhg hH.2.1 hH.1 hH.2.2.1
      (fun col hc => ⟨(hH.2.2.2 col hc).1, hhrows col hc, (hH.2.2.2 col hc).2⟩) henc _)]
  rfl

/-! ## The fork frame's theorems -/

theorem forkMagic_length : forkMagic.length = 8 := rfl

theorem rdForkHeader_ok {bindg : Dig} {l k : ℕ} {startTag : Dig} {bs rest : List UInt8} {u : Unit}
    (h : rdForkHeader bindg l k startTag bs = .ok (u, rest)) :
    bs = forkMagic ++ (bindg.toList ++ (le64 (UInt64.ofNat l) ++ (le64 (UInt64.ofNat k) ++ (startTag.toList ++ rest)))) := by
  obtain ⟨mg, m1, e1, e2⟩ := Rd.bnd_ok h
  obtain ⟨f1, hl1⟩ := rdBytes_ok e1
  obtain ⟨u1, m1', e3, e4⟩ := Rd.bnd_ok e2
  obtain ⟨hmg, hm1⟩ := Rd.guard_ok e3
  subst hm1
  obtain ⟨b, m2, e5, e6⟩ := Rd.bnd_ok e4
  have f2 := rdDig_ok e5
  obtain ⟨u2, m2', e7, e8⟩ := Rd.bnd_ok e6
  obtain ⟨hb, hm2⟩ := Rd.guard_ok e7
  subst hm2
  obtain ⟨l', m3, e9, e10⟩ := Rd.bnd_ok e8
  obtain ⟨k', m4, e11, e12⟩ := Rd.bnd_ok e10
  have f3 := rdU64_ok e9
  have f4 := rdU64_ok e11
  obtain ⟨u3, m4', e13, e14⟩ := Rd.bnd_ok e12
  obtain ⟨hlk, hm4⟩ := Rd.guard_ok e13
  subst hm4
  obtain ⟨st, m5, e15, e16⟩ := Rd.bnd_ok e14
  have f5 := rdDig_ok e15
  obtain ⟨hst, hm5⟩ := Rd.guard_ok e16
  subst hm5
  obtain ⟨hl'', hk''⟩ := not_or.mp hlk
  have hl' : l' = UInt64.ofNat l := by
    apply UInt64.toNat_inj.mp
    rw [UInt64.toNat_ofNat']
    exact not_not.mp hl''
  have hk' : k' = UInt64.ofNat k := by
    apply UInt64.toNat_inj.mp
    rw [UInt64.toNat_ofNat']
    exact not_not.mp hk''
  rw [f1, not_not.mp hmg, f2, not_not.mp hb, f3, hl', f4, hk', f5, not_not.mp hst]

theorem rdForkHeader_enc (bindg : Dig) (l k : ℕ) (startTag : Dig) (rest : List UInt8) :
    rdForkHeader bindg l k startTag
      (forkMagic ++ (bindg.toList ++ (le64 (UInt64.ofNat l) ++ (le64 (UInt64.ofNat k) ++ (startTag.toList ++ rest)))))
      = .ok ((), rest) := by
  unfold rdForkHeader
  rw [Rd.bnd_of_ok (rdBytes_enc forkMagic _ 8 forkMagic_length),
    Rd.bnd_of_ok (Rd.guard_enc (c := forkMagic ≠ forkMagic) _ (by simp)),
    Rd.bnd_of_ok (rdDig_enc _ _), Rd.bnd_of_ok (Rd.guard_enc (c := bindg ≠ bindg) _ (by simp)),
    Rd.bnd_of_ok (rdU64_enc _ _), Rd.bnd_of_ok (rdU64_enc _ _),
    Rd.bnd_of_ok (Rd.guard_enc (c := (UInt64.ofNat l).toNat ≠ l % 2 ^ 64 ∨ (UInt64.ofNat k).toNat ≠ k % 2 ^ 64) _
      (by simp [UInt64.toNat_ofNat'])),
    Rd.bnd_of_ok (rdDig_enc _ _), Rd.guard_enc (c := startTag ≠ startTag) _ (by simp)]

/-- **`decode_fork` refuses every non-canonical word and every other encoding**: an accepted frame is EXACTLY
`encFork` of the decoded core and end tag (with the verifier's own binding, `L`, `k` and start tag), the core's words
are canonical and its counts are the geometry's. -/
theorem decodeFork_spec {g : Geom} (hgt : g.slots.length = g.terms.length) {bindg : Dig} {l k : ℕ} {startTag : Dig}
    {bytes : List UInt8} {c : Core} {e : Dig} (h : decodeFork g bindg l k startTag bytes = .ok (c, e)) :
    bytes = encFork bindg l k startTag c e ∧ CoreCanon c ∧ CoreShape g c ∧ bytes.length = g.forkLen := by
  unfold decodeFork at h
  split at h
  · cases h
  · rename_i hlen
    split at h
    · cases h
    · rename_i r rest hr
      split at h
      · cases h
      · rename_i hrest
        cases h
        have hrest' : rest = [] := not_not.mp hrest
        subst hrest'
        unfold rdForkBody at hr
        obtain ⟨u, m1, e1, e2⟩ := Rd.bnd_ok hr
        obtain ⟨c', m2, e3, e4⟩ := Rd.bnd_ok e2
        obtain ⟨e', m3, e5, e6⟩ := Rd.bnd_ok e4
        obtain ⟨hce, hm3⟩ := Rd.ret_ok e6
        subst hm3
        cases hce
        have f1 := rdForkHeader_ok e1
        obtain ⟨f2, hcan, hsh⟩ := rdCore_ok hgt e3
        have f3 := rdDig_ok e5
        refine ⟨?_, hcan, hsh, not_not.mp (not_or.mp hlen).1⟩
        rw [f1, f2, f3, encFork, List.append_nil]

/-- **A receipt has ONE encoding**: two frames that decode to the same core and end tag are the same bytes. -/
theorem decodeFork_injective {g : Geom} (hgt : g.slots.length = g.terms.length) {bindg : Dig} {l k : ℕ} {startTag : Dig}
    {b₁ b₂ : List UInt8} {r : Core × Dig} (h₁ : decodeFork g bindg l k startTag b₁ = .ok r)
    (h₂ : decodeFork g bindg l k startTag b₂ = .ok r) : b₁ = b₂ := by
  rw [(decodeFork_spec hgt h₁).1, (decodeFork_spec hgt h₂).1]

/-- **The honest frame decodes**: the encoding of a canonical core of the verifier's shape, of the counted length,
under the verifier's own binding, `L`, `k` and start tag, decodes back to it. -/
theorem decodeFork_enc (g : Geom) (hgt : g.slots.length = g.terms.length) (hdom : g.maskDom ≤ 2 ^ 64)
    (henc : g.blk.encCols ≤ 2 ^ 64) (bindg : Dig) (l k : ℕ) (startTag : Dig) (c : Core) (e : Dig) (hcan : CoreCanon c)
    (hsh : CoreShape g c) (hlen : (encFork bindg l k startTag c e).length = g.forkLen) (hceil : g.forkLen ≤ g.ceiling) :
    decodeFork g bindg l k startTag (encFork bindg l k startTag c e) = .ok (c, e) := by
  have hr : rdForkBody g bindg l k startTag (encFork bindg l k startTag c e) = .ok ((c, e), []) := by
    unfold rdForkBody
    rw [encFork, Rd.bnd_of_ok (rdForkHeader_enc _ _ _ _ _), Rd.bnd_of_ok (rdCore_enc g hgt hdom henc c hcan hsh _),
      ← List.append_nil e.toList, Rd.bnd_of_ok (rdDig_enc _ _)]
    rfl
  have hc : ¬ ((encFork bindg l k startTag c e).length ≠ g.forkLen ∨ g.ceiling < g.forkLen) := by omega
  unfold decodeFork
  simp only [hc, ↓reduceIte, hr, ne_eq, not_true_eq_false]

end ZK60.Exec.Block
