/-
D63 Lean lane L32 (2026-11-09), part 2: **the openings' honest provers as transcript programs** (the piece lanes L25
and L29 left open: finding L25-3, L29 §6 O9 (a)).

A refusal site's computation must be a transcript program (L25's `TProg`: absorbs and squeezes of ONE transcript, with
the outside queries that feed it), so that its challenge point is fresh (`δ = 0`, `tprog_point_fresh`). L29 wrote the
heads and the slot loop of a part as programs. The transcript after the slots is moved by the openings: `M`'s
(`zk::mask_open`), then `A`'s and `H`'s (`pcs::open_zk`); the sites after them (`check_opening` of `A` sits after
`M`'s opening, `check_opening` of `H` after `A`'s, the next part after `H`'s) need those as programs too. Here:
* `sqsP`, `final_sqsP`: `n` squeezes (`challenge_indices`' loop), reading the digests;
* `rhosP`, `final_rhosP`: `zk_rhos` (the members' draws group by group, then the proximity weights) is L10's
  `zkRhosAux`;
* `absorbsP`, `final_absorbsP`: the group vectors' absorbs are `absorbVecs`;
* **`maskProg`**, **`final_maskProg_prove`**: `M`'s opening as a program after any prefix, with the functionals and the
  committed rows read off the prefix's data: it ends on EXACTLY the transcript of this lane's honest prover
  `maskProve`;
* **`pcsProg`**, **`final_pcsProg_prove`**: one commitment's opening as a program after any prefix, with the table and
  the claims read off the prefix's data: it ends on EXACTLY the transcript of `pcsProve`;
* `maskProve_tr`, `pcsProve_tr`: the provers' final transcripts are the index squeezes after the last absorb;
* `sep_*`: the programs make no outside query (the opened columns' Merkle paths are read, not hashed, by the prover's
  transcript), so separation is the prefix's.

The opening's words are functions of the prefix's data and of the opening's own challenges only (the committed rows
are the coins'): no hash query outside the transcript. With these, the prefix of every site of a part is a program
once the part's start is (L29's `coreHeadProg` / `famPre`, then `maskProg`, `pcsProg`); chaining the parts of the run
is the remaining step (it needs the commitments' Merkle programs as `RootProg`s and the frames between the parts).
-/
import ZK60Formal.HonestOpenM
import ZK60Formal.HonestOracleParts

set_option autoImplicit false

namespace ZK60.HonestRun

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.HonestClassify ZK60.HonestOracle ZK60.HonestOpen
open ZK60.Circuit (gP GF)

/-! ## Squeezes, `zk_rhos` and the vectors' absorbs as programs -/

section Pieces

variable {β : Type} (H : HIn → Dig)

/-- **`n` squeezes as a program** (`challenge_indices`' loop): the continuation reads the digests. -/
def sqsP : ℕ → (List Dig → TProg β) → TProg β
  | 0, k => k []
  | n + 1, k => .squeeze (fun dg => sqsP n (fun ds => k (dg :: ds)))

theorem final_sqsP : ∀ (n : ℕ) (k : List Dig → TProg β) (t : Tr),
    (sqsP n k).final H t = (k (sqDs H t n)).final H (runOps H t (List.replicate n Op.squeeze))
  | 0, _, _ => rfl
  | n + 1, k, t => by
    rw [sqDs_succ, List.replicate_succ]
    exact final_sqsP n (fun ds => k ((t.squeeze H).1 :: ds)) (t.squeeze H).2

theorem sep_sqsP (key : Option Dig) : ∀ (n : ℕ) (k : List Dig → TProg β), (∀ ds, TProg.Sep key (k ds)) →
    TProg.Sep key (sqsP n k)
  | 0, _, hk => hk []
  | n + 1, _, hk => fun _ => sep_sqsP key n _ (fun _ => hk _)

/-- **`zk_rhos` as a program**: per group its members' draws and its combination (`groupComb`), then the `rows`
proximity weights; the continuation reads the combinations and the wanted values. -/
def rhosP (rows : ℕ) : List (List Fp2 × List (List Fp2 × Fp2)) → (List (List Fp2) × List Fp2 → TProg β) → TProg β
  | [], k => drawsP rows (fun r => k ([r], []))
  | g :: gs, k => drawsP g.2.length (fun l => rhosP rows gs (fun rest =>
      k ((groupComb rows g.2 l).1 :: rest.1, (groupComb rows g.2 l).2 :: rest.2)))

theorem final_rhosP (rows : ℕ) : ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2)))
    (k : List (List Fp2) × List Fp2 → TProg β) (t : Tr),
    (rhosP rows gs k).final H t
      = (k ((zkRhosAux H rows gs t).1, (zkRhosAux H rows gs t).2.1)).final H (zkRhosAux H rows gs t).2.2
  | [], k, t => by
    rw [rhosP, final_drawsP]
    rfl
  | g :: gs, k, t => by
    rw [rhosP, final_drawsP, final_rhosP rows gs]
    rfl

theorem sep_rhosP (key : Option Dig) (rows : ℕ) : ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2)))
    (k : List (List Fp2) × List Fp2 → TProg β), (∀ r, TProg.Sep key (k r)) → TProg.Sep key (rhosP rows gs k)
  | [], _, hk => sep_drawsP key rows _ (fun _ => hk _)
  | g :: gs, _, hk => sep_drawsP key g.2.length _ (fun _ => sep_rhosP key rows gs _ (fun _ => hk _))

/-- **The group vectors' absorbs** (`absorb_fp2("pcs-vec")` per group) as a program. -/
def absorbsP : List (List Fp2) → TProg β → TProg β
  | [], k => k
  | v :: vs, k => .absorb pcsVecLabel (v.flatMap Fp2.toBytes) (absorbsP vs k)

theorem final_absorbsP : ∀ (vs : List (List Fp2)) (k : TProg β) (t : Tr),
    (absorbsP vs k).final H t = k.final H (absorbVecs H vs t)
  | [], _, _ => rfl
  | v :: vs, k, t => final_absorbsP vs k (t.absorbFp2 H pcsVecLabel v)

theorem sep_absorbsP (key : Option Dig) : ∀ (vs : List (List Fp2)) (k : TProg β), TProg.Sep key k →
    TProg.Sep key (absorbsP vs k)
  | [], _, hk => hk
  | _ :: vs, k, hk => sep_absorbsP key vs k hk

/-- A finished program leaves the transcript where it is. -/
theorem final_done_fst (b : β) (t : Tr) : ((TProg.done b).final H t).1 = t := rfl

/-- A finished program returns its data. -/
theorem final_done_snd (b : β) (t : Tr) : ((TProg.done b).final H t).2 = b := rfl

/-- One draw as `challenge_fp2_vec(1)`: the transcript after it is `challenge_fp2`'s. -/
theorem chalVec_one_snd (t : Tr) : (t.challengeFp2Vec H 1).2 = (t.challengeFp2 H).2 := rfl

/-- One draw as `challenge_fp2_vec(1)`: its entry is `challenge_fp2`'s (the `M` prover's `θ`). -/
theorem chalVec_one_getD (t : Tr) : (t.challengeFp2Vec H 1).1.getD 0 Fp2.zero = mTheta H t := rfl

end Pieces

/-! ## The provers' final transcripts -/

section Tr

variable (H : HIn → Dig) (tag : MTag)

/-- The honest opening prover ends on the index squeezes after the proximity vector's absorb. -/
theorem pcsProve_tr (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table)
    (claims : List ZClaim) (t : Tr) :
    (pcsProve H tag prm depth T claims t).2
      = runOps H (pT2 H prm T claims t) (List.replicate ((prm.nQ + 3) / 4) Op.squeeze) := by
  obtain ⟨idx, t3, hidx, -, -, hop⟩ := pcsProve_eq H tag prm depth hnn hnQ T claims t
  rw [hop]
  rw [challengeIndices_sqDs H prm.nQ prm.nn _ (by rw [hnn]; exact isPow2_two_pow depth) hnQ] at hidx
  exact (congrArg Prod.snd (Option.some.inj hidx)).symm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (ω512 ω4096 : Fp)

/-- The honest `M` prover ends on the `64` index squeezes after the proximity vector's absorb. -/
theorem maskProve_tr (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) :
    (maskProve H tag U hbij ω512 ω4096 M S fs t).2
      = runOps H (mT2 H U hbij ω512 M S fs t) (List.replicate ((mQ + 3) / 4) Op.squeeze) := by
  obtain ⟨idx, t3, hidx, -, -, hop⟩ := maskProve_eq H tag U hbij ω512 ω4096 M S fs t
  rw [hop]
  rw [challengeIndices_sqDs H mQ mDom _ (isPow2_two_pow 12) (by norm_num [mQ])] at hidx
  exact (congrArg Prod.snd (Option.some.inj hidx)).symm

end Tr

/-! ## The openings as transcript programs -/

section Progs

variable {α : Type} (H : HIn → Dig) (tag : MTag)

/-- **`M`'s opening as a transcript program** after a prefix `pre`: `θ`, `absorb_fp2("mask-q")` of the words `qw a θ`,
the `2S + 2` row coefficients `r`, `absorb_fp2("mask-prox")` of the words `pw a θ r`, then the index squeezes. The
words are functions of the prefix's data `a` and of the opening's own challenges. -/
def maskProg (S : ℕ) (qw : α → Fp2 → List Fp2) (pw : α → Fp2 → List Fp2 → List Fp2) (pre : TProg α) :
    TProg (α × List Fp2 × List Fp2 × List Dig) :=
  bindP pre (fun a => drawsP 1 (fun th => .absorb maskQLabel ((qw a (th.getD 0 Fp2.zero)).flatMap Fp2.toBytes)
    (drawsP (2 * S + 2) (fun rs => .absorb maskProxLabel ((pw a (th.getD 0 Fp2.zero) rs).flatMap Fp2.toBytes)
      (sqsP ((mQ + 3) / 4) (fun ds => .done (a, th, rs, ds)))))))

theorem sep_maskProg (key : Option Dig) (S : ℕ) (qw : α → Fp2 → List Fp2) (pw : α → Fp2 → List Fp2 → List Fp2)
    (pre : TProg α) (hp : TProg.Sep key pre) : TProg.Sep key (maskProg S qw pw pre) :=
  sep_bindP key pre _ hp (fun _ => sep_drawsP key 1 _ (fun _ => sep_drawsP key _ _ (fun _ =>
    sep_sqsP key _ _ (fun _ => trivial))))

/-- **One commitment's opening as a transcript program** after a prefix `pre`: `zk_rhos`, the group vectors' absorbs,
`absorb_fp2("pcs-prox")`, then the index squeezes. The table and the claims are read off the prefix's data. -/
def pcsProg (prm : PcsPrm) (T : α → Table) (claims : α → List ZClaim) (pre : TProg α) :
    TProg (α × List (List Fp2) × List Dig) :=
  bindP pre (fun a => rhosP (T a).rows.length (pGroups prm (T a) (claims a)) (fun r =>
    absorbsP ((r.1.map (fun rho => combVec (prm.n + prm.qPad) rho (T a).rows)).take
        (pGroups prm (T a) (claims a)).length)
      (.absorb pcsProxLabel
        (((r.1.map (fun rho => combVec (prm.n + prm.qPad) rho (T a).rows)).getD
          (pGroups prm (T a) (claims a)).length []).flatMap Fp2.toBytes)
        (sqsP ((prm.nQ + 3) / 4) (fun ds => .done (a, r.1, ds))))))

theorem sep_pcsProg (key : Option Dig) (prm : PcsPrm) (T : α → Table) (claims : α → List ZClaim) (pre : TProg α)
    (hp : TProg.Sep key pre) : TProg.Sep key (pcsProg prm T claims pre) :=
  sep_bindP key pre _ hp (fun _ => sep_rhosP key _ _ _ (fun _ => sep_absorbsP key _ _
    (sep_sqsP key _ _ (fun _ => trivial))))

/-- **The opening's program ends on the honest opening prover's transcript**, at the table and the claims the
prefix's data gives, and keeps the prefix's data. -/
theorem final_pcsProg_prove (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (T : α → Table) (claims : α → List ZClaim) (pre : TProg α) (t : Tr) :
    ((pcsProg prm T claims pre).final H t).1
        = (pcsProve H tag prm depth (T (pre.final H t).2) (claims (pre.final H t).2) (pre.final H t).1).2
      ∧ ((pcsProg prm T claims pre).final H t).2.1 = (pre.final H t).2 := by
  rw [pcsProve_tr H tag prm depth hnn hnQ]
  unfold pcsProg
  rw [final_bindP, final_rhosP, final_absorbsP, final_absorb, final_sqsP]
  exact ⟨rfl, rfl⟩

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (ω512 ω4096 : Fp)

/-- **`M`'s program ends on the honest `M` prover's transcript**, at the rows and the functionals the prefix's data
gives, and keeps the prefix's data. -/
theorem final_maskProg_prove (M : α → MTable) (S : ℕ) (fs : α → List MaskFunctional) (pre : TProg α) (t : Tr) :
    ((maskProg S (fun a th => polyWords U hbij (qPoly U (algebraMap GF K ω512.toGF) (M a) S (fs a) (th.toK U)))
        (fun a _ rs => polyWords U hbij (pPoly U (M a) S rs)) pre).final H t).1
        = (maskProve H tag U hbij ω512 ω4096 (M (pre.final H t).2) S (fs (pre.final H t).2) (pre.final H t).1).2
      ∧ ((maskProg S (fun a th => polyWords U hbij (qPoly U (algebraMap GF K ω512.toGF) (M a) S (fs a) (th.toK U)))
        (fun a _ rs => polyWords U hbij (pPoly U (M a) S rs)) pre).final H t).2.1 = (pre.final H t).2 := by
  rw [maskProve_tr H tag U hbij ω512 ω4096, mT2_eq]
  unfold maskProg
  rw [final_bindP, final_drawsP, final_absorb, final_drawsP, final_absorb, final_sqsP, chalVec_one_snd,
    chalVec_one_getD, final_done_fst, final_done_snd]
  exact ⟨rfl, rfl⟩

end Progs

end ZK60.HonestRun
