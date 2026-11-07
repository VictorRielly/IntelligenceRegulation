/-
D63 lane L22 (2026-11-07), part 2: **the block verifier's run as one trace of steps** (the executable half of L20-3's
`hexec`, (a)).

L9's `blockVerify` runs, after the prover's header: the roots and the slots (`blockSlots`), then `M`'s check, then the
`A` and `H` openings. Here, for ANY block verifier whose `M` and opening fields move the transcript as L9's
`maskTranscript` / `pcsTranscript` (L10's `maskField_transcript`, `pcsField_transcript`; L17's
`pcsFieldR13_transcript`):

* `opsStps`, `mStps`, `pcsStps`, `vStps`: the verifier's operations as steps; the header and the slots are single
  absorbs and single squeezes, `M` is `θ`, `"mask-q"`, the `2S + 2` row coefficients, `"mask-prox"`, the `64` index
  squeezes, an opening is its `(λ, ρ)` vector, the group vectors, `"pcs-prox"`, its index squeezes;
* `slotsLoop_tr`, `blockSlots_tr`: an accepting slot phase leaves the transcript at `runOps` of its operations;
* `maskTranscript_runOps`, `pcsTranscript_runOps`: `M`'s and an opening's transcript schedules are `runOps` of their
  steps, their challenges the trace's digests (`challengeFp2Of` of the run, `idxOf` of the index run);
* `groupZclaims_count`: the claims' groups hold every claim once (the `(λ, ρ)` vector has `#claims + rows` entries);
* **`blockVerify_ok`**, **`blockAcc_run`**: an accepting block verifier's transcript is `runOps` of `vStps`, with `M`
  accepted at the slots' end, `A` after `M`, `H` after `A`;
* `wRuns`, `wRuns_at`, `wRuns_lt`: the step parse of the wide runs, fixed by the counter at `M`'s window;
* `sqN`, `fullLen`, `fullSq`, `fullLen_shape`, `fullSq_shape`: the window positions and counters are the shape's
  (L16-2: fixed once the header's squeeze count is).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Parse

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## Counting -/

/-- The squeezes of a list of operations. -/
def sqN : List Op → ℕ
  | [] => 0
  | .absorb _ _ :: ops => sqN ops
  | .squeeze :: ops => sqN ops + 1

theorem sqN_append : ∀ (a b : List Op), sqN (a ++ b) = sqN a + sqN b
  | [], b => by simp [sqN]
  | .absorb _ _ :: a, b => by simp only [List.cons_append, sqN, sqN_append a b]
  | .squeeze :: a, b => by simp only [List.cons_append, sqN, sqN_append a b]; omega

theorem sqN_replicate (n : ℕ) : sqN (List.replicate n Op.squeeze) = n := by
  induction n with
  | zero => rfl
  | succ n ih => rw [List.replicate_succ, sqN, ih]

theorem u64_ofNat_add (a b : ℕ) : UInt64.ofNat a + UInt64.ofNat b = UInt64.ofNat (a + b) := by
  apply UInt64.toNat_inj.1
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat']
  omega

/-- Each operation as a step of its own. -/
def opStp : Op → Stp
  | .absorb l x => .ab l x
  | .squeeze => .sq 1

def opsStps (ops : List Op) : List Stp := ops.map opStp

theorem stpsOps_opsStps : ∀ ops : List Op, stpsOps (opsStps ops) = ops
  | [] => rfl
  | .absorb l x :: ops => by
    rw [opsStps, List.map_cons, stpsOps_cons, ← opsStps, stpsOps_opsStps ops]
    rfl
  | .squeeze :: ops => by
    rw [opsStps, List.map_cons, stpsOps_cons, ← opsStps, stpsOps_opsStps ops]
    rfl

theorem stpsSq_opsStps : ∀ ops : List Op, stpsSq (opsStps ops) = sqN ops
  | [] => rfl
  | .absorb l x :: ops => by
    rw [opsStps, List.map_cons, stpsSq_cons, ← opsStps, stpsSq_opsStps ops]
    simp only [opStp, Stp.nsq, sqN]
    omega
  | .squeeze :: ops => by
    rw [opsStps, List.map_cons, stpsSq_cons, ← opsStps, stpsSq_opsStps ops]
    simp only [opStp, Stp.nsq, sqN]
    omega

/-- **Single steps parse under any widths that are `1` at their counters.** -/
theorem stpOK_opsStps (W : UInt64 → ℕ) : ∀ (c : ℕ) (ops : List Op),
    (∀ j, j < sqN ops → W (UInt64.ofNat (c + j)) = 1) → StpOK W (UInt64.ofNat c) (opsStps ops)
  | _, [], _ => trivial
  | c, .absorb l x :: ops, h => by
    show StpOK W (UInt64.ofNat c) (opsStps ops)
    exact stpOK_opsStps W c ops (fun j hj => h j (by simpa [sqN] using hj))
  | c, .squeeze :: ops, h => by
    refine ⟨by simpa using h 0 (by simp [sqN]), Nat.one_pos, ?_⟩
    rw [u64_ofNat_add]
    exact stpOK_opsStps W (c + 1) ops (fun j hj => by
      have := h (j + 1) (by simp [sqN]; omega)
      rwa [show c + (j + 1) = c + 1 + j by omega] at this)

/-! ## The widths of the wide runs -/

/-- **The step parse of the verifier's wide runs**: runs of widths `ns` back to back from counter `c`; every other
counter `1`. -/
def wRuns : ℕ → List ℕ → ℕ → ℕ
  | _, [], _ => 1
  | c, n :: ns, k => if k = c then n else wRuns (c + n) ns k

theorem wRuns_pos : ∀ (c : ℕ) (ns : List ℕ), (∀ n ∈ ns, 0 < n) → ∀ k, 0 < wRuns c ns k
  | _, [], _, _ => Nat.one_pos
  | c, n :: ns, h, k => by
    rw [wRuns]
    split_ifs
    · exact h n List.mem_cons_self
    · exact wRuns_pos (c + n) ns (fun m hm => h m (List.mem_cons_of_mem _ hm)) k

theorem wRuns_le : ∀ (c : ℕ) (ns : List ℕ) (B : ℕ), 1 ≤ B → (∀ n ∈ ns, n ≤ B) → ∀ k, wRuns c ns k ≤ B
  | _, [], _, hB, _, _ => hB
  | c, n :: ns, B, hB, h, k => by
    rw [wRuns]
    split_ifs
    · exact h n List.mem_cons_self
    · exact wRuns_le (c + n) ns B hB (fun m hm => h m (List.mem_cons_of_mem _ hm)) k

/-- Before the runs every counter is `1`. -/
theorem wRuns_lt : ∀ (c : ℕ) (ns : List ℕ), (∀ n ∈ ns, 0 < n) → ∀ k, k < c → wRuns c ns k = 1
  | _, [], _, _, _ => rfl
  | c, n :: ns, h, k, hk => by
    rw [wRuns]
    rw [ite_eq_right (by omega)]
    exact wRuns_lt (c + n) ns (fun m hm => h m (List.mem_cons_of_mem _ hm)) k (by
      have := h n List.mem_cons_self
      omega)

/-- **Run `i` starts at `c + Σ_{j < i} n_j` with its width.** -/
theorem wRuns_at : ∀ (c : ℕ) (ns : List ℕ), (∀ n ∈ ns, 0 < n) → ∀ i, i < ns.length →
    wRuns c ns (c + (ns.take i).sum) = ns.getD i 1
  | _, [], _, i, hi => absurd hi (by simp)
  | c, n :: ns, h, 0, _ => by simp [wRuns]
  | c, n :: ns, h, i + 1, hi => by
    have hn := h n List.mem_cons_self
    rw [wRuns]
    rw [ite_eq_right (by simp only [List.take_succ_cons, List.sum_cons]; omega)]
    have := wRuns_at (c + n) ns (fun m hm => h m (List.mem_cons_of_mem _ hm)) i (by simpa using hi)
    simp only [List.take_succ_cons, List.sum_cons, List.getD_cons_succ]
    rw [← this, Nat.add_assoc]

/-! ## The slots' lengths and counters, from the shape -/

/-- The slot phase's operation count. -/
def fullLen (P : Block.BlockParams) : ℕ → List Block.SlotProof → ℕ
  | _, [] => 0
  | j, sp :: sps => P.draws j + 4 + 2 * sp.rounds.length + fullLen P (j + 1) sps

/-- The slot phase's squeeze count. -/
def fullSq (P : Block.BlockParams) : ℕ → List Block.SlotProof → ℕ
  | _, [] => 0
  | j, sp :: sps => P.draws j + 1 + sp.rounds.length + fullSq P (j + 1) sps

/-- The same counts from the shape (`(n, e, d)` per slot). -/
def shapeLen (P : Block.BlockParams) : ℕ → List (ℕ × ℕ × ℕ) → ℕ
  | _, [] => 0
  | j, s :: ss => P.draws j + 4 + 2 * (s.1 + s.2.1) + shapeLen P (j + 1) ss

def shapeSq (P : Block.BlockParams) : ℕ → List (ℕ × ℕ × ℕ) → ℕ
  | _, [] => 0
  | j, s :: ss => P.draws j + 1 + (s.1 + s.2.1) + shapeSq P (j + 1) ss

theorem fullOps_length (P : Block.BlockParams) : ∀ (j : ℕ) (sps : List Block.SlotProof),
    (Block.fullOps P j sps).length = fullLen P j sps
  | _, [] => rfl
  | j, sp :: sps => by
    rw [Block.fullOps, List.length_append, List.length_append, List.length_append, Block.slotPreOps_length,
      scOps_length, fullOps_length P (j + 1) sps, fullLen]
    simp only [List.length_singleton]
    omega

theorem sqN_scOps : ∀ rounds : List (List Fp2), sqN (scOps rounds) = rounds.length
  | [] => rfl
  | r :: rounds => by
    have h := sqN_scOps rounds
    simp only [scOps, List.flatMap_cons, List.length_cons] at h ⊢
    rw [sqN_append, h]
    simp only [sqN]
    omega

theorem sqN_slotPreOps (P : Block.BlockParams) (j : ℕ) (sp : Block.SlotProof) :
    sqN (Block.slotPreOps P j sp) = P.draws j + 1 := by
  simp only [Block.slotPreOps, Block.drawOps, sqN_append, sqN_replicate]
  simp only [sqN]

theorem fullOps_sq (P : Block.BlockParams) : ∀ (j : ℕ) (sps : List Block.SlotProof),
    sqN (Block.fullOps P j sps) = fullSq P j sps
  | _, [] => rfl
  | j, sp :: sps => by
    rw [Block.fullOps, sqN_append, sqN_append, sqN_append, sqN_slotPreOps, sqN_scOps, fullOps_sq P (j + 1) sps,
      fullSq]
    simp only [Block.termOp, sqN]
    omega

/-- Under the shape, the counts are the shape's. -/
theorem full_shape (P : Block.BlockParams) : ∀ (j : ℕ) (sps : List Block.SlotProof) (ss : List (ℕ × ℕ × ℕ)),
    sps.length = ss.length → (∀ (i : ℕ) (sp : Block.SlotProof) (s : ℕ × ℕ × ℕ), sps[i]? = some sp → ss[i]? = some s →
      sp.rounds.length = s.1 + s.2.1) →
    fullLen P j sps = shapeLen P j ss ∧ fullSq P j sps = shapeSq P j ss
  | _, [], [], _, _ => ⟨rfl, rfl⟩
  | _, [], _ :: _, h, _ => absurd h (by simp)
  | _, _ :: _, [], h, _ => absurd h (by simp)
  | j, sp :: sps, s :: ss, hl, hr => by
    have h0 := hr 0 sp s rfl rfl
    have ih := full_shape P (j + 1) sps ss (by simpa using hl) (fun i sp' s' h1 h2 => hr (i + 1) sp' s' h1 h2)
    simp only [fullLen, fullSq, shapeLen, shapeSq, h0, ih.1, ih.2, and_self]

/-- The roots' operations: ten, three of them squeezes. -/
theorem rootOps_length (P : Block.BlockParams) (core : Block.Core) : (Block.rootOps P core).length = 10 := rfl

theorem rootOps_sq (P : Block.BlockParams) (core : Block.Core) : sqN (Block.rootOps P core) = 3 := rfl

/-! ## The slot phase leaves the transcript at `runOps` of its operations -/

section SlotsTr

variable (H : HIn → Dig)

theorem slotsLoop_tr (P : Block.BlockParams) (b g a : Fp2) :
    ∀ (sps : List Block.SlotProof) (recs : List Block.SlotRec) (j : ℕ) (acc : Block.Acc) (t : Tr)
      (recs' : List Block.SlotRec) (acc' : Block.Acc) (t' : Tr),
      (∀ i, i < sps.length → 1 ≤ (Block.slotShape P (j + i)).2.2) →
      Block.slotsLoop H P b g a recs j sps acc t = .ok (recs', acc', t') → t' = runOps H t (Block.fullOps P j sps)
  | [], recs, j, acc, t, recs', acc', t', _, h => by
    simp only [Block.slotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, -, rfl⟩ := h
    rfl
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', hd1, h => by
    simp only [Block.slotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, hdf, hcl, hsv, ht0, -, -, -, -⟩ := Block.slotStep_ok H P j _ sp0 acc t r0 acc0 t0 hstep
      have hd0 : 1 ≤ (Block.slotShape P j).2.2 := by simpa using hd1 0 (by simp)
      have ht0' : t0 = runOps H t (Block.slotPreOps P j sp0 ++ scOps sp0.rounds ++ [Block.termOp sp0]) := by
        rw [ht0, Block.slot_after H P j sp0 t r0.claimed r0.fin (r0.rho ++ r0.es) hd0 hsv]
      have ih := slotsLoop_tr P b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t'
        (fun i hi => by
          have := hd1 (i + 1) (by simp; omega)
          rwa [show j + (i + 1) = j + 1 + i by omega] at this) h
      rw [ih, ht0', Block.fullOps]
      simp only [runOps_append]

/-- **An accepting slot phase leaves the transcript at `runOps` of the roots' and the slots' operations.** -/
theorem blockSlots_tr (P : Block.BlockParams) (core : Block.Core) (t : Tr) (bga : Fp2 × Fp2 × Fp2)
    (rs : List Block.SlotRec) (acc : Block.Acc) (t' : Tr) (h : Block.blockSlots H P core t = .ok (bga, rs, acc, t'))
    (hd : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape P i).2.2) :
    t' = runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots) := by
  rw [Block.blockSlots_eq] at h
  split at h
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl⟩ := h
    have := slotsLoop_tr H P _ _ _ core.slots [] 0 {} _ rs acc t' (fun i hi => by simpa using hd i hi) hloop
    rw [this, runOps_append]
  · cases h

end SlotsTr

/-! ## `M`'s and an opening's transcript schedules as steps -/

/-- `M`'s steps before its index squeezes: `θ`, `"mask-q"`, the `2S + 2` row coefficients, `"mask-prox"`. -/
def mPre (S : ℕ) (mo : Block.MaskOpening) : List Stp :=
  [.sq 1, .ab Block.labMaskQ (mo.q.flatMap Fp2.toBytes), .sq (2 * S + 2),
    .ab Block.labMaskProx (mo.prox.flatMap Fp2.toBytes)]

/-- **`M`'s steps** (`mask_verify_tagged`'s transcript): `mPre`, then the `64` index squeezes. -/
def mStps (S : ℕ) (mo : Block.MaskOpening) : List Stp := mPre S mo ++ [.sq 64]

/-- The group vectors' absorbs (`"pcs-vec"`). -/
def vecStps (vs : List (List Fp2)) : List Stp := vs.map (fun v => Stp.ab Block.labPcsVec (v.flatMap Fp2.toBytes))

/-- An opening's steps before its index squeezes: the `w0` batching and proximity squeezes, the group vectors,
`"pcs-prox"`. -/
def pcsPre (w0 : ℕ) (o : Block.OpeningZk) : List Stp :=
  .sq w0 :: (vecStps o.groupVecs ++ [.ab Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes)])

/-- **An opening's steps** (`verify_zk_tagged`'s transcript): `pcsPre`, then the `m` index squeezes. -/
def pcsStps (w0 m : ℕ) (o : Block.OpeningZk) : List Stp := pcsPre w0 o ++ [.sq m]

/-- **The block verifier's whole run as steps**: the header, the roots and the slots as single steps, then `M`, `A`
and `H`. -/
def vStps (P : Block.BlockParams) (S w0A w0H m : ℕ) (hdr : List Op) (core : Block.Core) : List Stp :=
  opsStps (hdr ++ Block.rootOps P core ++ Block.fullOps P 0 core.slots) ++ mStps S core.maskOpen
    ++ pcsStps w0A m core.aOpen ++ pcsStps w0H m core.hOpen

theorem stpsSq_vecStps : ∀ vs : List (List Fp2), stpsSq (vecStps vs) = 0
  | [] => rfl
  | v :: vs => by
    rw [vecStps, List.map_cons, stpsSq_cons, ← vecStps, stpsSq_vecStps vs]
    rfl

theorem stpsOps_vecStps_length : ∀ vs : List (List Fp2), (stpsOps (vecStps vs)).length = vs.length
  | [] => rfl
  | v :: vs => by
    rw [vecStps, List.map_cons, stpsOps_cons, ← vecStps, List.length_append, stpsOps_vecStps_length vs]
    simp only [Stp.ops, List.length_cons, List.length_nil]
    omega

theorem stpOK_vecStps (W : UInt64 → ℕ) (c : UInt64) :
    ∀ (vs : List (List Fp2)) (rest : List Stp), StpOK W c rest → StpOK W c (vecStps vs ++ rest)
  | [], _, h => h
  | v :: vs, rest, h => by
    rw [vecStps, List.map_cons, List.cons_append, ← vecStps]
    exact stpOK_vecStps W c vs rest h

theorem stpsSq_mPre (S : ℕ) (mo : Block.MaskOpening) : stpsSq (mPre S mo) = 2 * S + 3 := by
  simp only [mPre, stpsSq, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, Stp.nsq]
  omega

theorem stpsSq_mStps (S : ℕ) (mo : Block.MaskOpening) : stpsSq (mStps S mo) = 2 * S + 67 := by
  rw [mStps, stpsSq_append, stpsSq_mPre]
  simp only [stpsSq, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, Stp.nsq]
  omega

theorem stpsSq_pcsPre (w0 : ℕ) (o : Block.OpeningZk) : stpsSq (pcsPre w0 o) = w0 := by
  rw [pcsPre, stpsSq_cons, stpsSq_append, stpsSq_vecStps]
  simp only [stpsSq, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, Stp.nsq]
  omega

theorem stpsSq_pcsStps (w0 m : ℕ) (o : Block.OpeningZk) : stpsSq (pcsStps w0 m o) = w0 + m := by
  rw [pcsStps, stpsSq_append, stpsSq_pcsPre]
  simp only [stpsSq, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, Stp.nsq]
  omega

theorem stpsOps_mPre_length (S : ℕ) (mo : Block.MaskOpening) : (stpsOps (mPre S mo)).length = 2 * S + 5 := by
  simp only [mPre, stpsOps, List.flatMap_cons, List.flatMap_nil, Stp.ops, List.length_append, List.length_replicate,
    List.length_singleton, List.length_nil]
  omega

theorem stpsOps_mStps_length (S : ℕ) (mo : Block.MaskOpening) : (stpsOps (mStps S mo)).length = 2 * S + 69 := by
  rw [mStps, stpsOps_append, List.length_append, stpsOps_mPre_length]
  simp only [stpsOps, List.flatMap_cons, List.flatMap_nil, Stp.ops, List.length_append, List.length_replicate,
    List.length_nil]

theorem stpsOps_pcsPre_length (w0 : ℕ) (o : Block.OpeningZk) :
    (stpsOps (pcsPre w0 o)).length = w0 + o.groupVecs.length + 1 := by
  rw [pcsPre, stpsOps_cons, stpsOps_append, List.length_append, List.length_append, stpsOps_vecStps_length]
  simp only [stpsOps, List.flatMap_cons, List.flatMap_nil, Stp.ops, List.length_append, List.length_replicate,
    List.length_singleton, List.length_nil]
  omega

theorem stpsOps_pcsStps_length (w0 m : ℕ) (o : Block.OpeningZk) :
    (stpsOps (pcsStps w0 m o)).length = w0 + o.groupVecs.length + 1 + m := by
  rw [pcsStps, stpsOps_append, List.length_append, stpsOps_pcsPre_length]
  simp only [stpsOps, List.flatMap_cons, List.flatMap_nil, Stp.ops, List.length_append, List.length_replicate,
    List.length_nil]
  omega

theorem stpsOps_singleton (s : Stp) : stpsOps [s] = s.ops := by
  simp [stpsOps]

section Sched

variable (H : HIn → Dig)

theorem sqDs_add (t : Tr) (a b : ℕ) :
    sqDs H t (a + b) = sqDs H t a ++ sqDs H (runOps H t (List.replicate a Op.squeeze)) b := by
  rw [sqDs, sqDs, sqDs, List.replicate_add, Block.opTrace_append, List.map_append]

/-- A fold of vector challenges, for any step function that is one: the vectors are `challenge_fp2` of ONE run of
`Σ counts` squeezes. -/
theorem foldl_vec_gen (f : List Fp2 × Tr → ℕ → List Fp2 × Tr)
    (hf : ∀ acc c, f acc c
      = (acc.1 ++ (sqDs H acc.2 c).map challengeFp2Of, runOps H acc.2 (List.replicate c Op.squeeze))) :
    ∀ (counts : List ℕ) (l0 : List Fp2) (t : Tr), counts.foldl f (l0, t)
      = (l0 ++ (sqDs H t counts.sum).map challengeFp2Of, runOps H t (List.replicate counts.sum Op.squeeze))
  | [], l0, t => by simp [sqDs, opTrace, runOps]
  | c :: cs, l0, t => by
    rw [List.foldl_cons, hf, foldl_vec_gen f hf cs, List.sum_cons, sqDs_add, List.map_append, List.append_assoc,
      List.replicate_add, runOps_append]

/-- **`zk_rhos`**: the `λ`s then the proximity coefficients are `challenge_fp2` of ONE run of `Σ counts + rows`
squeezes, and the transcript is `runOps` of that run. -/
theorem zkRhos_sqDs (counts : List ℕ) (rows : ℕ) (t : Tr) :
    (Block.zkRhos H counts rows t).1 ++ (Block.zkRhos H counts rows t).2.1
        = (sqDs H t (counts.sum + rows)).map challengeFp2Of
      ∧ (Block.zkRhos H counts rows t).1.length = counts.sum
      ∧ (Block.zkRhos H counts rows t).2.2 = runOps H t (List.replicate (counts.sum + rows) Op.squeeze) := by
  let F : List Fp2 × Tr → ℕ → List Fp2 × Tr := fun acc c =>
    (acc.1 ++ (acc.2.challengeFp2Vec H c).1, (acc.2.challengeFp2Vec H c).2)
  have hF : ∀ acc c, F acc c
      = (acc.1 ++ (sqDs H acc.2 c).map challengeFp2Of, runOps H acc.2 (List.replicate c Op.squeeze)) := by
    intro acc c
    show (acc.1 ++ (acc.2.challengeFp2Vec H c).1, (acc.2.challengeFp2Vec H c).2) = _
    rw [challengeFp2Vec_sqDs]
  have hfold := foldl_vec_gen H F hF counts [] t
  have e1 : Block.zkRhos H counts rows t = ((counts.foldl F ([], t)).1,
      ((counts.foldl F ([], t)).2.challengeFp2Vec H rows).1, ((counts.foldl F ([], t)).2.challengeFp2Vec H rows).2) :=
    rfl
  rw [e1, hfold, challengeFp2Vec_sqDs]
  simp only [List.nil_append]
  refine ⟨?_, ?_, ?_⟩
  · rw [sqDs_add, List.map_append]
  · rw [List.length_map, sqDs_length]
  · rw [List.replicate_add, runOps_append]

theorem runOps_vecStps : ∀ (vs : List (List Fp2)) (t : Tr),
    runOps H t (stpsOps (vecStps vs)) = vs.foldl (fun t v => t.absorbFp2 H Block.labPcsVec v) t
  | [], _ => rfl
  | v :: vs, t => by
    rw [vecStps, List.map_cons, stpsOps_cons, ← vecStps, runOps_append, List.foldl_cons]
    exact runOps_vecStps vs _

/-- **`M`'s transcript schedule is `runOps` of its steps**, its challenges the trace's digests. -/
theorem maskTranscript_runOps (S : ℕ) (mo : Block.MaskOpening) (t : Tr) (th : Fp2) (rs : List Fp2) (idx : List ℕ)
    (t' : Tr) (h : Block.maskTranscript H S mQ mDom mo t = .ok (th, rs, idx, t')) :
    th = challengeFp2Of (t.squeeze H).1
      ∧ rs = (sqDs H ((t.squeeze H).2.absorbFp2 H Block.labMaskQ mo.q) (2 * S + 2)).map challengeFp2Of
      ∧ idx = idxOf mDom mQ (sqDs H (runOps H t (stpsOps (mPre S mo))) 64)
      ∧ t' = runOps H t (stpsOps (mStps S mo))
      ∧ mo.columns.length = idx.length ∧ ∀ ci ∈ mo.columns.zip idx, ci.1.j = ci.2 := by
  have hpow : isPow2 mDom = true := by decide
  have hT4 : runOps H t (stpsOps (mPre S mo))
      = (((t.challengeFp2 H).2.absorbFp2 H Block.labMaskQ mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
          Block.labMaskProx mo.prox := by
    have e : stpsOps (mPre S mo) = [Op.squeeze, Op.absorb Block.labMaskQ (mo.q.flatMap Fp2.toBytes)]
        ++ (List.replicate (2 * S + 2) Op.squeeze ++ [Op.absorb Block.labMaskProx (mo.prox.flatMap Fp2.toBytes)]) := by
      simp [mPre, stpsOps, Stp.ops]
    rw [e, runOps_append, runOps_append, challengeFp2Vec_sqDs]
    rfl
  have hc : ((((t.challengeFp2 H).2.absorbFp2 H Block.labMaskQ mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
      Block.labMaskProx mo.prox).challengeIndices H mQ mDom
      = some (idxOf mDom mQ (sqDs H (runOps H t (stpsOps (mPre S mo))) 64),
          runOps H (runOps H t (stpsOps (mPre S mo))) (List.replicate 64 Op.squeeze)) := by
    rw [← hT4]
    exact challengeIndices_sqDs H mQ mDom _ hpow (by decide)
  unfold Block.maskTranscript at h
  simp only [hc] at h
  split_ifs at h with h1 h2
  simp only [Except.ok.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl⟩ := h
  refine ⟨rfl, by rw [challengeFp2Vec_sqDs]; rfl, rfl, ?_, by simpa using h1, ?_⟩
  · rw [mStps, stpsOps_append, runOps_append, stpsOps_singleton]
    rfl
  · intro ci hci
    by_contra hne
    exact h2 (List.any_eq_true.mpr ⟨ci, hci, by simpa using hne⟩)

/-- **An opening's transcript schedule is `runOps` of its steps**, its `(λ, ρ)` one run's digests and its indices
the index run's. -/
theorem pcsTranscript_runOps (counts : List ℕ) (rows q nn : ℕ) (hq : 0 < q) (hnn : isPow2 nn = true)
    (o : Block.OpeningZk) (t : Tr) (lams rho : List Fp2) (idx : List ℕ) (t' : Tr)
    (h : Block.pcsTranscript H counts rows q nn o t = .ok (lams, rho, idx, t')) :
    lams ++ rho = (sqDs H t (counts.sum + rows)).map challengeFp2Of
      ∧ lams.length = counts.sum
      ∧ idx = idxOf nn q (sqDs H (runOps H t (stpsOps (pcsPre (counts.sum + rows) o))) ((q + 3) / 4))
      ∧ t' = runOps H t (stpsOps (pcsStps (counts.sum + rows) ((q + 3) / 4) o))
      ∧ o.columns.length = idx.length ∧ ∀ ci ∈ o.columns.zip idx, ci.1.j = ci.2 := by
  obtain ⟨hz1, hz2, hz3⟩ := zkRhos_sqDs H counts rows t
  have hT : runOps H t (stpsOps (pcsPre (counts.sum + rows) o))
      = (o.groupVecs.foldl (fun t v => t.absorbFp2 H Block.labPcsVec v) (Block.zkRhos H counts rows t).2.2).absorbFp2
          H Block.labPcsProx o.proxVec := by
    rw [hz3, pcsPre, stpsOps_cons, stpsOps_append, runOps_append, runOps_append, runOps_vecStps]
    rfl
  have hc : ((o.groupVecs.foldl (fun t v => t.absorbFp2 H Block.labPcsVec v)
      (Block.zkRhos H counts rows t).2.2).absorbFp2 H Block.labPcsProx o.proxVec).challengeIndices H q nn
      = some (idxOf nn q (sqDs H (runOps H t (stpsOps (pcsPre (counts.sum + rows) o))) ((q + 3) / 4)),
          runOps H (runOps H t (stpsOps (pcsPre (counts.sum + rows) o))) (List.replicate ((q + 3) / 4) Op.squeeze)) := by
    rw [← hT]
    exact challengeIndices_sqDs H q nn _ hnn hq
  unfold Block.pcsTranscript at h
  simp only [hc] at h
  split at h
  all_goals (try (cases h; done))
  rename_i hcol
  simp only [Except.ok.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl, rfl⟩ := h
  unfold Block.colIdxCheck at hcol
  split_ifs at hcol with hl
  split at hcol
  all_goals (try (cases hcol; done))
  rename_i hfind
  refine ⟨hz1, hz2, rfl, ?_, by simpa using hl, ?_⟩
  · rw [pcsStps, stpsOps_append, runOps_append, stpsOps_singleton]
    rfl
  · intro ci hci
    rw [List.find?_eq_none] at hfind
    simpa using hfind ci hci

end Sched

/-! ## The claims' groups hold every claim once -/

theorem keyIdx_lt {keys : List ZKey} {k : ZKey} {gi : ℕ} (h : keyIdx keys k = some gi) : gi < keys.length := by
  unfold keyIdx at h
  exact (List.findIdx?_eq_some_iff_getElem.mp h).1

theorem pushAt_count {α β : Type} : ∀ (l : List (α × List β)) (gi : ℕ) (m : β), gi < l.length →
    ((pushAt l gi m).map (fun g => g.2.length)).sum = (l.map (fun g => g.2.length)).sum + 1
  | [], _, _, h => absurd h (by simp)
  | x :: l, 0, m, _ => by simp [pushAt]; omega
  | x :: l, i + 1, m, h => by
    simp only [pushAt, List.map_cons, List.sum_cons]
    rw [pushAt_count l i m (by simpa using h)]
    omega

theorem pushAt_length {α β : Type} : ∀ (l : List (α × List β)) (gi : ℕ) (m : β), (pushAt l gi m).length = l.length
  | [], _, _ => rfl
  | x :: l, 0, m => rfl
  | x :: l, i + 1, m => by simp [pushAt, pushAt_length l i m]

theorem foldl_groupStep_count (rows logCols : ℕ) : ∀ (cl : List ZClaim)
    (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))), st.1.length = st.2.length →
    ((cl.foldl (groupStep rows logCols) st).2.map (fun g => g.2.length)).sum
      = (st.2.map (fun g => g.2.length)).sum + cl.length
  | [], _, _ => rfl
  | c :: cl, st, hst => by
    rw [List.foldl_cons]
    rcases hk : keyIdx st.1 (claimWeights c rows logCols).2 with _ | gi
    · have e : groupStep rows logCols st c = (st.1 ++ [(claimWeights c rows logCols).2],
          st.2 ++ [(zkeyWeights (claimWeights c rows logCols).2 logCols,
            [((claimWeights c rows logCols).1, c.value)])]) := by
        simp only [groupStep, hk]
      rw [e, foldl_groupStep_count rows logCols cl _ (by simp only [List.length_append, List.length_singleton, hst]),
        List.map_append, List.sum_append, List.length_cons]
      simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.length_cons, List.length_nil]
      omega
    · have e : groupStep rows logCols st c = (st.1, pushAt st.2 gi ((claimWeights c rows logCols).1, c.value)) := by
        simp only [groupStep, hk]
      rw [e, foldl_groupStep_count rows logCols cl _ (by rw [pushAt_length]; exact hst),
        pushAt_count st.2 gi _ (by rw [← hst]; exact keyIdx_lt hk), List.length_cons]
      omega

/-- **Every claim is in one group once**: the member counts sum to the number of claims (`zk_rhos` draws one `λ` per
claim). -/
theorem groupZclaims_count (cl : List ZClaim) (rows logCols : ℕ) :
    ((groupZclaims cl rows logCols).map (·.2.length)).sum = cl.length := by
  have := foldl_groupStep_count rows logCols cl ([], []) rfl
  simpa [groupZclaims] using this

/-! ## The block verifier, accepted, as one run -/

section Accept

variable (H : HIn → Dig)

/-- **An accepting block verifier, decomposed**: the slot phase, the functional count, `M`'s check at the slots' end,
the `A` opening after `M`, the `H` opening after `A`. -/
theorem blockVerify_ok (P : Block.BlockParams) (core : Block.Core) (t : Tr) (io : List Block.ZClaim × List Block.ZClaim)
    (t' : Tr) (h : Block.blockVerify H P core t = .ok (io, t')) :
    ∃ bga rs acc tM tA tH, Block.blockSlots H P core t = .ok (bga, rs, acc, tM)
      ∧ (acc.fs ++ acc.hostFs).length = P.nFunctionals
      ∧ P.maskVerify H core.maskRoot (acc.fs ++ acc.hostFs) core.maskOpen tM = .ok tA
      ∧ P.pcsVerify H .a core.aRoot acc.claims.a core.aOpen tA = .ok tH
      ∧ P.pcsVerify H .h core.hRoot (acc.claims.h ++ [P.logupSumClaim]) core.hOpen tH = .ok t' := by
  unfold Block.blockVerify at h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨⟨bga, rs, acc, tM⟩, hbs, h⟩ := Block.ex_bind_ok h
  simp only [] at h
  split at h
  · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
    cases he
  rename_i hnf
  split at h
  · rename_i tA hmv
    obtain ⟨tA', htA, h⟩ := Block.ex_bind_ok h
    cases htA
    obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
    split at h
    · rename_i tH hpa
      obtain ⟨tH', htH, h⟩ := Block.ex_bind_ok h
      cases htH
      obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
      split at h
      · rename_i tF hph
        obtain ⟨tF', htF, h⟩ := Block.ex_bind_ok h
        cases htF
        simp only [pure, Except.pure, Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨-, rfl⟩ := h
        exact ⟨bga, rs, acc, tM, tA, tH, hbs, by simpa using hnf, hmv, hpa, hph⟩
      · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
        cases he
    · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
      cases he
  · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
    cases he

end Accept

end ZK60.Exec.Link
