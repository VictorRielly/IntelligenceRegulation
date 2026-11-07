/-
D63 Lean lane L17 (2026-11-07): **L9's block verifier at R13**, and the frame the R13 classifier run carries.

L9's decoder (`decodeFork`, `rdCore`), verifier (`blockVerify`, `blockSlots`) and Fiat–Shamir bound
(`block_sumchecks_fs_sound`, `block_sumchecks_fs_sound_shape`) are GENERIC in the verifier's geometry `Geom` and its
parameters `BlockParams`: an R13 block is an instance. R13 changes three numbers of the geometry (the opened columns
`Q = 256`, the clear vectors' `n + Q = 16,640` words, the encoded width `2^16` and the path depth `16`, from rate
`1/4`), the slot schedule's table (the same 23 slots, `Shape::slots`' same degree table; the terminal counts and the
draws move with the R13 plane and lookup lists), and nothing of the reader, the transcript or the slot loop.

What is new here:
* **the D12a SEGMENT frame** (`HLPRUNS1`, `wire::decode_segment`, wire.rs:277-496), which the R13 classifier run
  (`hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/2`) carries: the header (magic, the run
  binding, `L`, `k`, the start position tag, each COMPARED, never adopted), the optional boundary root `B_k`, the block
  core (L9's `rdCore`), the opening of the commitment the stage closes (the input endpoint at `k = 0`, else `B_{k−1}`),
  the output endpoint's opening on the last stage, the end tag; the counted length first; the code's refusal strings.
  `decodeSegment_spec` (an accepted segment is exactly `encSeg` of what it decodes to; every word canonical; the core's
  counts are the geometry's; the optional parts are the schedule's), `decodeSegment_injective` (one encoding);
* **the R13 geometry** (`R13.blkDim`, `R13.geom`, `R13.segGeom`) and the instances of L9's decoder theorems at it;
* **the R13 rung's schedule** (`R13.rungSlots`, `rungTerms`, `rungDrawList`, recorded by the agreement corpus from a real
  R13 rung core and checked by `CheckR13Block.lean`), `R13.rung_len`, and **`R13.rung_block_fs_sound`**: L9's bound on
  the real R13 schedule, at most `2^-61`; the Shieldstral T128 R13 schedule (`R13.shieldSlots`, from the shape corpus) and
  its bound (`R13.shield_block_fs_sound`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExecBlockFS

namespace ZK60.Exec.Block

open ZK60.Circuit (gP GF)

/-! ## The D12a segment -/

/-- `b"HLPRUNS1"` (wire.rs:281). -/
def runMagic : List UInt8 := [72, 76, 80, 82, 85, 78, 83, 49]

theorem runMagic_length : runMagic.length = 8 := rfl

/-- **`wire::Segment`**: the boundary root this stage commits (absent on the last), the block core, the opening of the
commitment the stage closes, the output endpoint's opening (the last stage only). -/
structure Segment where
  bRoot : Option Dig
  core : Core
  inOpen : OpeningZk
  outOpen : Option OpeningZk
  deriving DecidableEq

/-- **`wire::SegGeom`** with the block core's geometry and the endpoints' `Dim`: every count of a segment, from the
verifier's own statement (`L`, `k`, the shape, the boundary construction). -/
structure SegGeom where
  g : Geom
  ed : Dim
  eRows : ℕ
  l : ℕ
  k : ℕ
  boundaryRows : ℕ
  sites : ℕ

/-- `commits_boundary`. -/
def SegGeom.commits (s : SegGeom) : Bool := decide (s.k + 1 < s.l)
/-- `closes_output`. -/
def SegGeom.closes (s : SegGeom) : Bool := decide (s.k + 1 = s.l)
/-- `incoming`: `(groups, rows)` of the opening the stage closes. -/
def SegGeom.incoming (s : SegGeom) : ℕ × ℕ := if s.k = 0 then (1, s.eRows) else (s.sites, s.boundaryRows)

/-- **`segment_len`** (wire.rs:353-370). -/
def SegGeom.len (s : SegGeom) : ℕ :=
  (8 + 32 + 8 + 8 + 32) + (if s.commits then 32 else 0) + 3 * 32 + s.g.slotsLen + s.g.maskLen
    + s.g.blk.openingLen s.g.aGroups s.g.aRows + s.g.blk.openingLen s.g.hGroups s.g.hRows
    + s.ed.openingLen s.incoming.1 s.incoming.2 + (if s.closes then s.ed.openingLen 1 s.eRows else 0) + 32

/-- An optional part, present exactly when the schedule says. -/
def rdOpt {α : Type} : Bool → Rd α → Rd (Option α)
  | true, r => Rd.bnd r fun a => Rd.ret (some a)
  | false, _ => Rd.ret none

def encOpt {α : Type} (f : α → List UInt8) : Option α → List UInt8
  | none => []
  | some a => f a

/-- The segment header (wire.rs:458-469): each field COMPARED with the verifier's own. -/
def rdSegHeader (bindg : Dig) (l k : ℕ) (startTag : Dig) : Rd Unit :=
  Rd.bnd (rdBytes 8) fun mg => Rd.bnd (Rd.guard (mg ≠ runMagic) "private run wire: segment profile") fun _ =>
  Rd.bnd rdDig fun b => Rd.bnd (Rd.guard (b ≠ bindg) "private run wire: this segment belongs to another run") fun _ =>
  Rd.bnd rdU64 fun l' => Rd.bnd rdU64 fun k' =>
  Rd.bnd (Rd.guard (l'.toNat ≠ l % 2 ^ 64 ∨ k'.toNat ≠ k % 2 ^ 64)
    s!"private run wire: segment {k} is not the {l}-segment run's segment {k}") fun _ =>
  Rd.bnd rdDig fun st =>
  Rd.guard (st ≠ startTag) s!"private run wire: segment {k}'s header is not the verifier's own transcript position"

/-- The segment after its length check: the header, `B_k`'s root, the core, the incoming opening, the output
endpoint's opening, the end tag. -/
def rdSegBody (s : SegGeom) (bindg startTag : Dig) : Rd (Segment × Dig) :=
  Rd.bnd (rdSegHeader bindg s.l s.k startTag) fun _ =>
  Rd.bnd (rdOpt s.commits rdDig) fun br =>
  Rd.bnd (rdCore s.g) fun c =>
  Rd.bnd (rdHiding s.ed s.incoming.1 s.incoming.2) fun io =>
  Rd.bnd (rdOpt s.closes (rdHiding s.ed 1 s.eRows)) fun oo =>
  Rd.bnd rdDig fun e => Rd.ret (⟨br, c, io, oo⟩, e)

/-- **`wire::decode_segment`**: segment `k` of an `L`-stage D12a run, against the verifier's run binding and start
position. Returns the segment and the end tag (to be compared after the stage is replayed). -/
def decodeSegment (s : SegGeom) (bindg startTag : Dig) (bytes : List UInt8) : Except String (Segment × Dig) :=
  if bytes.length ≠ s.len ∨ s.g.ceiling < s.len then
    .error s!"private run wire: segment {s.k} is {bytes.length} B, the counted length is {s.len}"
  else
    match rdSegBody s bindg startTag bytes with
    | .error e => .error e
    | .ok (r, rest) => if rest ≠ [] then .error "private run wire: trailing bytes" else .ok r

/-- `encode_segment` (wire.rs:407-444). -/
def encSeg (bindg : Dig) (l k : ℕ) (startTag : Dig) (sg : Segment) (endTag : Dig) : List UInt8 :=
  runMagic ++ (bindg.toList ++ (le64 (UInt64.ofNat l) ++ (le64 (UInt64.ofNat k) ++ (startTag.toList
    ++ (encOpt (fun d : Dig => d.toList) sg.bRoot ++ (encCore sg.core ++ (encHiding sg.inOpen
    ++ (encOpt encHiding sg.outOpen ++ endTag.toList))))))))

/-! ## The segment's theorems -/

theorem rdOpt_ok {α : Type} {b : Bool} {r : Rd α} {enc : α → List UInt8} {P : α → Prop}
    (hr : ∀ bs a rest, r bs = .ok (a, rest) → bs = enc a ++ rest ∧ P a)
    {bs rest : List UInt8} {o : Option α} (h : rdOpt b r bs = .ok (o, rest)) :
    bs = encOpt enc o ++ rest ∧ o.isSome = b ∧ ∀ a ∈ o, P a := by
  cases b with
  | false =>
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok h
    exact ⟨rfl, rfl, fun a ha => by cases ha⟩
  | true =>
    obtain ⟨a, m, e1, e2⟩ := Rd.bnd_ok h
    obtain ⟨rfl, rfl⟩ := Rd.ret_ok e2
    obtain ⟨hb, hp⟩ := hr _ _ _ e1
    exact ⟨hb, rfl, fun a' ha' => by cases ha'; exact hp⟩

theorem rdSegHeader_ok {bindg : Dig} {l k : ℕ} {startTag : Dig} {bs rest : List UInt8} {u : Unit}
    (h : rdSegHeader bindg l k startTag bs = .ok (u, rest)) :
    bs = runMagic ++ (bindg.toList ++ (le64 (UInt64.ofNat l) ++ (le64 (UInt64.ofNat k) ++ (startTag.toList ++ rest)))) := by
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

/-- **`decode_segment` refuses every non-canonical word and every other encoding**: an accepted segment is EXACTLY
`encSeg` of the decoded segment and end tag (with the verifier's own binding, `L`, `k` and start tag); its words are
canonical; the core's counts are the geometry's; `B_k`'s root is present exactly when the stage commits a boundary,
the output endpoint's opening exactly on the last stage. -/
theorem decodeSegment_spec {s : SegGeom} (hgt : s.g.slots.length = s.g.terms.length) {bindg startTag : Dig}
    {bytes : List UInt8} {sg : Segment} {e : Dig} (h : decodeSegment s bindg startTag bytes = .ok (sg, e)) :
    bytes = encSeg bindg s.l s.k startTag sg e ∧ CoreCanon sg.core ∧ CoreShape s.g sg.core ∧ HidingCanon sg.inOpen
      ∧ (∀ o ∈ sg.outOpen, HidingCanon o) ∧ sg.bRoot.isSome = s.commits ∧ sg.outOpen.isSome = s.closes
      ∧ bytes.length = s.len := by
  unfold decodeSegment at h
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
        unfold rdSegBody at hr
        obtain ⟨u, m1, e1, e2⟩ := Rd.bnd_ok hr
        obtain ⟨br, m2, e3, e4⟩ := Rd.bnd_ok e2
        obtain ⟨c, m3, e5, e6⟩ := Rd.bnd_ok e4
        obtain ⟨io, m4, e7, e8⟩ := Rd.bnd_ok e6
        obtain ⟨oo, m5, e9, e10⟩ := Rd.bnd_ok e8
        obtain ⟨e', m6, e11, e12⟩ := Rd.bnd_ok e10
        obtain ⟨hce, hm6⟩ := Rd.ret_ok e12
        subst hm6
        cases hce
        have f1 := rdSegHeader_ok e1
        obtain ⟨f2, hbs, -⟩ := rdOpt_ok (enc := fun d : Dig => d.toList) (P := fun _ => True)
          (fun _ _ _ h => ⟨rdDig_ok h, trivial⟩) e3
        obtain ⟨f3, hcan, hsh⟩ := rdCore_ok hgt e5
        obtain ⟨f4, hic, -⟩ := rdHiding_ok e7
        obtain ⟨f5, hos, hoc⟩ := rdOpt_ok (enc := encHiding) (P := HidingCanon)
          (fun _ _ _ h => ⟨(rdHiding_ok h).1, (rdHiding_ok h).2.1⟩) e9
        have f6 := rdDig_ok e11
        refine ⟨?_, hcan, hsh, hic, hoc, hbs, hos, not_not.mp (not_or.mp hlen).1⟩
        rw [f1, f2, f3, f4, f5, f6, encSeg, List.append_nil]

/-- **A segment has ONE encoding**: two segments that decode to the same segment and end tag are the same bytes. -/
theorem decodeSegment_injective {s : SegGeom} (hgt : s.g.slots.length = s.g.terms.length) {bindg startTag : Dig}
    {b₁ b₂ : List UInt8} {r : Segment × Dig} (h₁ : decodeSegment s bindg startTag b₁ = .ok r)
    (h₂ : decodeSegment s bindg startTag b₂ = .ok r) : b₁ = b₂ := by
  rw [(decodeSegment_spec hgt h₁).1, (decodeSegment_spec hgt h₂).1]

/-- What the decoder guarantees about an opening's counts (`Dim::hiding_ok`). -/
def HidingShape (d : Dim) (groups rows : ℕ) (o : OpeningZk) : Prop :=
  o.groupVecs.length = groups ∧ (∀ v ∈ o.groupVecs, v.length = d.vec) ∧ o.proxVec.length = d.vec
    ∧ o.columns.length = d.checks ∧ ∀ c ∈ o.columns, c.j < d.encCols ∧ c.col.length = rows ∧ c.path.length = d.path

theorem rdOpt_enc {α : Type} {b : Bool} {r : Rd α} {enc : α → List UInt8} {P : α → Prop}
    (hr : ∀ a rest, P a → r (enc a ++ rest) = .ok (a, rest)) (o : Option α) (ho : o.isSome = b)
    (hP : ∀ a ∈ o, P a) (rest : List UInt8) : rdOpt b r (encOpt enc o ++ rest) = .ok (o, rest) := by
  cases o with
  | none =>
    subst ho
    rfl
  | some a =>
    subst ho
    show Rd.bnd r (fun a => Rd.ret (some a)) (enc a ++ rest) = _
    rw [Rd.bnd_of_ok (hr a rest (hP a (by simp)))]
    rfl

theorem rdSegHeader_enc (bindg : Dig) (l k : ℕ) (startTag : Dig) (rest : List UInt8) :
    rdSegHeader bindg l k startTag
      (runMagic ++ (bindg.toList ++ (le64 (UInt64.ofNat l) ++ (le64 (UInt64.ofNat k) ++ (startTag.toList ++ rest)))))
      = .ok ((), rest) := by
  unfold rdSegHeader
  rw [Rd.bnd_of_ok (rdBytes_enc runMagic _ 8 runMagic_length),
    Rd.bnd_of_ok (Rd.guard_enc (c := runMagic ≠ runMagic) _ (by simp)),
    Rd.bnd_of_ok (rdDig_enc _ _), Rd.bnd_of_ok (Rd.guard_enc (c := bindg ≠ bindg) _ (by simp)),
    Rd.bnd_of_ok (rdU64_enc _ _), Rd.bnd_of_ok (rdU64_enc _ _),
    Rd.bnd_of_ok (Rd.guard_enc (c := (UInt64.ofNat l).toNat ≠ l % 2 ^ 64 ∨ (UInt64.ofNat k).toNat ≠ k % 2 ^ 64) _
      (by simp [UInt64.toNat_ofNat'])),
    Rd.bnd_of_ok (rdDig_enc _ _), Rd.guard_enc (c := startTag ≠ startTag) _ (by simp)]

/-- **The honest segment decodes**: the encoding of a canonical segment of the verifier's geometry (the core's counts,
the closed commitment's opening and the output endpoint's opening of their counted shapes, the optional parts the
schedule's), of the counted length, under the verifier's own binding and start tag, decodes back to it. -/
theorem decodeSegment_enc (s : SegGeom) (hgt : s.g.slots.length = s.g.terms.length) (hdom : s.g.maskDom ≤ 2 ^ 64)
    (henc : s.g.blk.encCols ≤ 2 ^ 64) (hee : s.ed.encCols ≤ 2 ^ 64) (bindg startTag : Dig) (sg : Segment) (e : Dig)
    (hcan : CoreCanon sg.core) (hsh : CoreShape s.g sg.core) (hbr : sg.bRoot.isSome = s.commits)
    (hic : HidingCanon sg.inOpen) (his : HidingShape s.ed s.incoming.1 s.incoming.2 sg.inOpen)
    (hos : sg.outOpen.isSome = s.closes) (hoc : ∀ o ∈ sg.outOpen, HidingCanon o ∧ HidingShape s.ed 1 s.eRows o)
    (hlen : (encSeg bindg s.l s.k startTag sg e).length = s.len) (hceil : s.len ≤ s.g.ceiling) :
    decodeSegment s bindg startTag (encSeg bindg s.l s.k startTag sg e) = .ok (sg, e) := by
  have hhid : ∀ (groups rows : ℕ) (o : OpeningZk) (rest : List UInt8), HidingCanon o ∧ HidingShape s.ed groups rows o →
      rdHiding s.ed groups rows (encHiding o ++ rest) = .ok (o, rest) := fun groups rows o rest h =>
    rdHiding_enc s.ed groups rows o h.1 h.2.1 h.2.2.1 h.2.2.2.1 h.2.2.2.2.1 h.2.2.2.2.2 hee rest
  have hr : rdSegBody s bindg startTag (encSeg bindg s.l s.k startTag sg e) = .ok ((sg, e), []) := by
    unfold rdSegBody
    rw [encSeg, Rd.bnd_of_ok (rdSegHeader_enc _ _ _ _ _),
      Rd.bnd_of_ok (rdOpt_enc (P := fun _ => True) (fun a rest _ => rdDig_enc a rest) sg.bRoot hbr (fun _ _ => trivial) _),
      Rd.bnd_of_ok (rdCore_enc s.g hgt hdom henc sg.core hcan hsh _),
      Rd.bnd_of_ok (hhid _ _ sg.inOpen _ ⟨hic, his⟩),
      Rd.bnd_of_ok (rdOpt_enc (P := fun o => HidingCanon o ∧ HidingShape s.ed 1 s.eRows o)
        (fun a rest h => hhid 1 s.eRows a rest h) sg.outOpen hos hoc _),
      ← List.append_nil e.toList, Rd.bnd_of_ok (rdDig_enc _ _)]
    rfl
  have hc : ¬ ((encSeg bindg s.l s.k startTag sg e).length ≠ s.len ∨ s.g.ceiling < s.len) := by omega
  unfold decodeSegment
  simp only [hc, ↓reduceIte, hr, ne_eq, not_true_eq_false]

/-! ## The R13 geometry -/

namespace R13

/-- `COL_CHECKS`: the opened columns and the pads per row of every regular R13 commitment (shape.rs:1091). -/
def openedCols : ℕ := 256
/-- R13's regular row width `2^14` and inverse rate `4` (shape.rs:695-699). -/
def logCols : ℕ := 14
def invRate : ℕ := 4

/-- **The block `Dim` at R13** (`wire::Dim::new(14, 4, 256)`): `256` opened columns, clear vectors of `2^14 + 256`
words, `2^16` encoded columns, paths of depth `16`. The endpoints' `Dim` is the same (`endpoint_log_n = log_cols`,
`endpoint_inv_rate = inv_rate` at every R13 profile). -/
def blkDim : Dim := ⟨256, 2 ^ 14 + 256, 2 ^ 16, 16⟩

/-- `MAX_WIRE_BYTES_TRAINED` (an R13 profile is a trained-calibration profile). -/
def ceiling : ℕ := 256 * 1024 * 1024

/-- **The R13 frame geometry** of a block: the slot schedule and terminal counts, `M`'s constants (`zk.rs`, the same at
every profile: L9's `W16R2.maskVec` etc.), its row count, R13's block `Dim`, `A`'s and `H`'s groups and rows. -/
def geom (slots : List (ℕ × ℕ × ℕ)) (terms : List ℕ) (mRows aGroups aRows hGroups hRows : ℕ) : Geom :=
  ⟨slots, terms, W16R2.maskVec, W16R2.maskQ, W16R2.maskDom, W16R2.maskPath, mRows, blkDim, aGroups, aRows, hGroups,
    hRows, ceiling⟩

/-- **The R13 segment geometry**: the core's, the endpoints' `Dim` (`blkDim`), the endpoint rows, `L`, `k`, the
boundary's rows and sites. -/
def segGeom (g : Geom) (eRows l k boundaryRows sites : ℕ) : SegGeom := ⟨g, blkDim, eRows, l, k, boundaryRows, sites⟩

/-- **L9's decoder theorem at R13** (the D55 fork frame of an R13 D55 run, D60): an instance. -/
theorem decodeFork_spec_r13 {slots : List (ℕ × ℕ × ℕ)} {terms : List ℕ} (hgt : slots.length = terms.length)
    {mRows aGroups aRows hGroups hRows : ℕ} {bindg : Dig} {l k : ℕ} {startTag : Dig} {bytes : List UInt8} {c : Core}
    {e : Dig} (h : decodeFork (geom slots terms mRows aGroups aRows hGroups hRows) bindg l k startTag bytes = .ok (c, e)) :
    bytes = encFork bindg l k startTag c e ∧ CoreCanon c ∧ CoreShape (geom slots terms mRows aGroups aRows hGroups hRows) c
      ∧ bytes.length = (geom slots terms mRows aGroups aRows hGroups hRows).forkLen :=
  decodeFork_spec hgt h

/-- **The D12a segment theorem at R13**: an instance of `decodeSegment_spec`. -/
theorem decodeSegment_spec_r13 {slots : List (ℕ × ℕ × ℕ)} {terms : List ℕ} (hgt : slots.length = terms.length)
    {mRows aGroups aRows hGroups hRows eRows l k br st : ℕ} {bindg startTag : Dig} {bytes : List UInt8} {sg : Segment}
    {e : Dig}
    (h : decodeSegment (segGeom (geom slots terms mRows aGroups aRows hGroups hRows) eRows l k br st) bindg startTag bytes
      = .ok (sg, e)) :
    bytes = encSeg bindg l k startTag sg e ∧ CoreCanon sg.core
      ∧ CoreShape (geom slots terms mRows aGroups aRows hGroups hRows) sg.core ∧ HidingCanon sg.inOpen
      ∧ (∀ o ∈ sg.outOpen, HidingCanon o) :=
  let r := decodeSegment_spec (s := segGeom (geom slots terms mRows aGroups aRows hGroups hRows) eRows l k br st) hgt h
  ⟨r.1, r.2.1, r.2.2.1, r.2.2.2.1, r.2.2.2.2.1⟩

/-! ## The R13 rung's schedule and its Fiat–Shamir bound -/

open ZK60.Sound
open scoped ENNReal

/-- **The R13 development rung's slot schedule**, `(n, e, d)` per slot (`Layout::slots` at
`hashline-zk-mr1/private-block-rung-lh-t32-dev/2`, recorded by the corpus and checked by `CheckR13Block`): the same as
W16R2's rung (`W16R2.rungSlots`), slot for slot. -/
def rungSlots : List (ℕ × ℕ × ℕ) :=
  [(14, 1, 4), (14, 1, 4), (5, 1, 3), (14, 1, 4), (14, 1, 3), (9, 1, 2), (9, 1, 2), (9, 1, 2), (9, 2, 3), (8, 2, 3),
    (10, 1, 2), (9, 1, 2), (9, 1, 2), (10, 1, 2), (14, 1, 5), (15, 1, 4), (14, 1, 4), (14, 1, 4), (15, 1, 5),
    (14, 1, 3), (14, 1, 2), (14, 1, 2), (14, 1, 2)]

theorem rungSlots_eq_w16r2 : rungSlots = W16R2.rungSlots := rfl

/-- The R13 rung's terminal count per slot (`slot_terms`; the R13 plane and helper lists move the zero-checks'). -/
def rungTerms : List ℕ := [1, 1, 22, 3, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 58, 22, 22, 27, 24, 6, 1, 2, 2]

/-- How many challenges each slot's `define` draws at the R13 rung (counted by the export on the code's transcript;
`Slot.R13.drawLen` of the rung's shape facts, checked by `CheckR13Slots`). -/
def rungDrawList : List ℕ := [5, 5, 13, 16, 10, 15, 9, 9, 14, 15, 14, 15, 10, 14, 48, 28, 27, 31, 30, 19, 0, 14, 14]

def rungDraws (k : ℕ) : ℕ := rungDrawList.getD k 0

/-- **The R13 rung's item count**: `ℓ = hdrLen + 1068` (the 10 root operations, 375 draws, 23 × 3 slot prefixes, 22
`pb-term` absorbs, and 296 rounds of two items). -/
theorem rung_len (h : ℕ) : blockLen rungDraws rungSlots h = h + 1068 := by
  simp [blockLen, rungSlots, rungDraws, rungDrawList, List.range_succ]

theorem rung_slot_facts : ∀ k, k < 23 → 1 ≤ (rungSlots.getD k (0, 0, 0)).2.2 ∧ (rungSlots.getD k (0, 0, 0)).2.2 ≤ 5
    ∧ 56 + 16 * ((rungSlots.getD k (0, 0, 0)).2.2 + 1) ≤ 2 ^ 20 ∧ 55 + 16 * rungTerms.getD k 0 ≤ 2 ^ 20 := by
  decide

/-- **The R13 rung block's sumcheck Fiat–Shamir bound** (L9's `block_sumchecks_fs_sound_shape` on the R13 schedule):
with a header of at most `2^19` operations, hash inputs of at most `L ≥ 2^20` bytes and a prover making at most
`q ≤ 2^64` queries, a false claimed sum in ANY of the 23 slots passes `blockSlots` with every terminal check with
probability at most `2^-61` (degree `≤ 5`, `T = q + hdrLen + 1069 ≤ 2^64 + 2^20`). -/
theorem rung_block_fs_sound {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hdr : P.draws = rungDraws) (hsl : P.geom.slots = rungSlots)
    (htm : P.geom.terms = rungTerms) (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (q : ℕ) (hq : q ≤ 2 ^ 64) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen f G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  refine block_sumchecks_fs_sound_shape U hU hK2 key domain hs L hL hL64 (by omega) P hdrLen f 5 ?_ ?_ q A hA
    (by norm_num) ?_
  · intro k hk
    rw [hsl] at hk
    have hk' : k < 23 := by simpa [rungSlots] using hk
    obtain ⟨h1, h2, h3, h4⟩ := rung_slot_facts k hk'
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  · rw [hsl, htm]
    rfl
  · rw [hdr, hsl, rung_len]
    have h1 : hdrLen + 1068 + 1 ≤ 2 ^ 20 :=
      le_trans (Nat.add_le_add_right (Nat.add_le_add_right hh 1068) 1) (by norm_num)
    calc q + (hdrLen + 1068) + 1 = q + (hdrLen + 1068 + 1) := by rw [Nat.add_assoc]
      _ ≤ 2 ^ 64 + 2 ^ 20 := Nat.add_le_add hq h1

/-! ## The Shieldstral T128 R13 block (the media app's classifier block) -/

/-- **The registered Shieldstral T128 R13 block's slot schedule** (`hashline-zk-mr1/private-block-shieldstral-3b-t128-
lowh24-blocks/2`, `Shape::slots`, recorded by the shape corpus; `W16R2.sched` of its shape facts, checked by
`CheckR13Slots`). -/
def shieldSlots : List (ℕ × ℕ × ℕ) :=
  [(19, 1, 4), (19, 1, 4), (7, 1, 3), (14, 1, 4), (19, 1, 3), (12, 1, 2), (12, 1, 2), (12, 1, 2), (10, 2, 3),
    (10, 2, 3), (12, 1, 2), (12, 1, 2), (12, 1, 2), (14, 1, 2), (19, 1, 5), (19, 1, 4), (17, 1, 4), (19, 1, 4),
    (21, 1, 5), (14, 1, 3), (14, 1, 2), (19, 1, 2), (19, 1, 2)]

/-- Its terminal counts (`slot_terms`, the shape corpus). -/
def shieldTerms : List ℕ := [1, 1, 22, 3, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 58, 22, 22, 24, 24, 6, 1, 2, 2]

/-- Its draws (`Slot.R13.drawLen` of its shape facts, `SlotR13.lean`'s `shieldDraws_eq`). -/
def shieldDrawList : List ℕ := [7, 7, 15, 16, 13, 19, 10, 10, 19, 19, 19, 21, 14, 19, 53, 32, 30, 35, 36, 19, 0, 19, 19]

def shieldDraws (k : ℕ) : ℕ := shieldDrawList.getD k 0

/-- **The Shieldstral T128 R13 block's item count**: `ℓ = hdrLen + 1292` (10 root operations, 451 draws, 69 slot
prefixes, 22 `pb-term` absorbs, 370 rounds of two items). -/
theorem shield_len (h : ℕ) : blockLen shieldDraws shieldSlots h = h + 1292 := by
  simp [blockLen, shieldSlots, shieldDraws, shieldDrawList, List.range_succ]

theorem shield_slot_facts : ∀ k, k < 23 → 1 ≤ (shieldSlots.getD k (0, 0, 0)).2.2
    ∧ (shieldSlots.getD k (0, 0, 0)).2.2 ≤ 5
    ∧ 56 + 16 * ((shieldSlots.getD k (0, 0, 0)).2.2 + 1) ≤ 2 ^ 20 ∧ 55 + 16 * shieldTerms.getD k 0 ≤ 2 ^ 20 := by
  decide

/-- **The Shieldstral T128 R13 block's sumcheck Fiat–Shamir bound**: at most `2^-61` (as at the rung). -/
theorem shield_block_fs_sound {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hdr : P.draws = shieldDraws) (hsl : P.geom.slots = shieldSlots)
    (htm : P.geom.terms = shieldTerms) (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (q : ℕ) (hq : q ≤ 2 ^ 64) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen f G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  refine block_sumchecks_fs_sound_shape U hU hK2 key domain hs L hL hL64 (by omega) P hdrLen f 5 ?_ ?_ q A hA
    (by norm_num) ?_
  · intro k hk
    rw [hsl] at hk
    have hk' : k < 23 := by simpa [shieldSlots] using hk
    obtain ⟨h1, h2, h3, h4⟩ := shield_slot_facts k hk'
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  · rw [hsl, htm]
    rfl
  · rw [hdr, hsl, shield_len]
    have h1 : hdrLen + 1292 + 1 ≤ 2 ^ 20 :=
      le_trans (Nat.add_le_add_right (Nat.add_le_add_right hh 1292) 1) (by norm_num)
    calc q + (hdrLen + 1292) + 1 = q + (hdrLen + 1292 + 1) := by rw [Nat.add_assoc]
      _ ≤ 2 ^ 64 + 2 ^ 20 := Nat.add_le_add hq h1

end R13

end ZK60.Exec.Block
