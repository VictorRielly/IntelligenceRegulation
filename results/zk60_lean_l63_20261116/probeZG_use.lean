import ZK60Formal

/-! L63 leg 21 probe (untracked): the generic top at a SECOND error function. `mockErr` / `mockErr_hzk` have exactly
the shape of L68c's `shdRunErrRes` / `shdRunErrRes_hzk` (HonestShieldZKBase.lean at 10112106, lines 65 and 151:
`(q R : ℕ) : ℝ≥0∞` and `(q R' : ℕ) (_hq : q ≤ 2 ^ 64) (hR' : R' ≤ 2 ^ 64) : _ q R' ≤ εzkTarget q R'`), which this
tree does not contain. The instantiation below is the one the handoff gives with `shdRunErrRes` in place of
`mockErr`. -/

open scoped ENNReal

noncomputable def mockErr (q R : ℕ) : ℝ≥0∞ := 0 * (q + R : ℕ)

theorem mockErr_hzk (q R' : ℕ) (_hq : q ≤ 2 ^ 64) (hR' : R' ≤ 2 ^ 64) :
    mockErr q R' ≤ ZK60.εzkTarget q R' := by
  simp [mockErr]

-- the generic top at `εzk := mockErr`: every other argument stays a binder (named args, the rest eta-expanded)
#check ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkEF_zg (εzk := mockErr) (hzkB := mockErr_hzk)

-- the same as a theorem with the explicit arguments positional (the order of the handoff's two lines)
open ZK60.ProtocolClassify in
example := @fun {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins] tag Lq hL20 hL64 key Rp hR hw
    hhdrFit preA preB check0 paths digest bndCheck ioIn ioOut checkOpening embDigest bInRow wDigest bOutRow P epBase
    {ι : Type} [Fintype ι] site kOf δOf O E0b hV131072 =>
  sshC_productionReadyL_epP_blkEF_zg (Hdr := Hdr) (Coins := Coins) (ι := ι) (εzk := mockErr) (hzkB := mockErr_hzk)
    tag Lq hL20 hL64 key Rp hR hw hhdrFit preA preB check0 paths digest bndCheck ioIn ioOut checkOpening embDigest
    bInRow wDigest bOutRow P epBase site kOf δOf O E0b hV131072

#print axioms ZK60.ProtocolClassify.sshC_productionReadyL_epP_blkEF_zg
