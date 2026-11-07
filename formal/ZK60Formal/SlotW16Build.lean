/-
D63 step L13, part 1: **the W16R2 slot polynomials as Lean functions of the tables' positions, the shape's constants
and the challenges** (a port of `slot_ir.rs::build_slot_ir` and `slot_ir_accuracy.rs`'s `*_w16` arms), and **what they
evaluate to**: each zero-check slot's polynomial is `eq(τ)·Z + ν₀·eq(p₁)·gate·host₁ + ν₁·eq(p₂)·gate·host₂` with `Z`
the batched relation `Σ_k μ_k·c_k + μ_pad·Σ_j ζ^j·(1 − supp)·plane_j` of its named clause list (`hostPoly`'s integrand,
`SlotW16Sound.lean`), each private slot's is its summand (a plane times a folded weight, the row sums, the squares).

What is mirrored (read 2026-11-07; nothing there is changed), under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`:
* `slot_ir.rs`: `IrB` (a node's id is its position; tables are pushed before any node), `limbs16_node`,
  `limbs_node`, `l3_node`, `IrPad` (the ζ powers continue across a slot's groups), `logup_subterms` (one affine
  denominator per lookup, `h·d₁·d₂ − d₁ − d₂` per pair, `h·d − 1` for an odd last one), and the generic arms of
  `build_slot_ir` (lines 959-1552: `SC_SS`, `SC_SSM`, `SC_TZC`, `SC_LZC`, `SC_RS`, the matmuls, `SC_SCORE`, `SC_PV`,
  `SC_ZS`, `SC_IO_*`);
* `slot_ir_accuracy.rs`: `requant16`, `three_terms`, `batch`, `gated`, and the W16 arms `dzc_w16` (444-497),
  `fzc_w16` (499-553), `qzc_w16` (555-614), `szc_w16` (616-705), `tab_w16` (712-762).

The builders are generic in the coefficient type (`Cst`): at `Fp2` (`cstW`) they produce the code's coefficient words
(`SlotW16BuildCheck.lean` compares every slot's IR with the code's on a real W16R2 receipt); in a commutative ring they
are the polynomials the theorems are about; `Ir.map` carries one to the other (`zcIr_map` and the per-slot `_map`).

The node lists are written statically, with each node's id its position (`zcIr`: the slot-specific nodes, the LogUp
segment, the pad segment, the zero-check node, the host nodes), exactly as `IrB` numbers them.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `nodeVals_append`, `nodeVals_prefix`, `nodeVals_at`: a node's value is fixed when it is pushed;
* `logupGo_spec`, `padGo_spec`: the LogUp segment's subterms sum to `Σ_k μ_k·(h_k·d_{2k}·d_{2k+1} − d_{2k} − d_{2k+1})`
  (`h·d − 1` for a single), the pad segment's to `Σ_groups μ_pad·(1 − supp)·Σ_j ζ^j·plane_j`;
* **`zcIr_eval`**: the zero-check template's value: its terms at the zero-check node `Z = logup + extra + pad + last`;
* the per-slot theorems (`SlotW16BuildEval.lean`).
-/
import ZK60Formal.SlotW16Ir

namespace ZK60.Exec.Slot.Build

open ZK60.Exec ZK60.Exec.Slot

/-! ## The coefficient constants of a coefficient type -/

/-- The constants the builders write (`Coef::one`, `Coef::neg_one`, `Coef::zero`, `Coef::base`, the `2^(16k)` of
`limbs16_node`, the `256^k` of `limbs_node`). -/
structure Cst (α : Type) where
  one : α
  negOne : α
  zero : α
  base : ℤ → α
  p16 : ℕ → α
  p256 : ℕ → α

def Cst.map {α β : Type} (f : α → β) (c : Cst α) : Cst β :=
  ⟨f c.one, f c.negOne, f c.zero, fun v => f (c.base v), fun k => f (c.p16 k), fun k => f (c.p256 k)⟩

/-- **The code's words** (`Fp2::ONE`, `Fp2::ONE.neg()`, `Fp2::ZERO`, `Fp2::from_i64`,
`Fp2::from_base(Fp::new(1 << 16k))`, `layout::pow256`). -/
def cstW : Cst Fp2 :=
  ⟨Fp2.one, Fp2.one.neg, Fp2.zero, fun v => Fp2.fromBase (Fp.fromI64 v),
    fun k => Fp2.fromBase (Fp.new (UInt64.ofNat (2 ^ (16 * k)))), fun k => Fp2.fromU64 (UInt64.ofNat (2 ^ (8 * k)))⟩

/-- The constants of a commutative ring. -/
def cstR (R : Type) [CommRing R] : Cst R := ⟨1, -1, 0, fun v => (v : R), fun k => 2 ^ (16 * k), fun k => 256 ^ k⟩

section Builders

variable {α : Type} (c : Cst α)

/-! ## Bodies and subterms -/

def st (coef : α) (fs : List Factor) : SubTerm α := ⟨coef, fs⟩

/-- `limbs16_node`: `Σ_k 2^(16k)·t_k`. -/
def limbs16B (ix : List ℕ) : Body α := .affine c.zero (ix.zipIdx.map fun q => (c.p16 q.2, q.1))

/-- `limbs_node`: `Σ_k 256^k·t_k` (the isqrt byte limbs, `l3_node`). -/
def limbsB (ix : List ℕ) : Body α := .affine c.zero (ix.zipIdx.map fun q => (c.p256 q.2, q.1))

/-- `requant16`'s sum node, its limbs node at `l`: `2^s·x + limbs − 2^(s−1)`. -/
def reqB (s : ℕ) (x l : ℕ) : Body α :=
  .sum [st (c.base (2 ^ s)) [.tab x], st c.one [.node l], st (c.base (-(2 ^ (s - 1) : ℤ))) []]

/-- `gated`: `1·gate·node` (the constant `1` where the profile has no gate). -/
def gatedSt (gate : Option ℕ) (n : ℕ) : SubTerm α := st c.one ((gate.map Factor.tab).toList ++ [.node n])

/-- `batch`: `Σ_k μ_k·clause_k`. -/
def batchB (mu : List α) (cls : List ℕ) : Body α := .sum (cls.zipIdx.map fun q => st (mu.getD q.2 c.zero) [.node q.1])

/-- `three_terms`. -/
def threeTerms (eqs : ℕ × ℕ × ℕ) (gate : Option ℕ) (zc : ℕ) (nu : List α) (h1 h2 : ℕ) : List (Term α) :=
  [⟨c.one, [eqs.1], [.node zc]⟩, ⟨nu.getD 0 c.zero, eqs.2.1 :: gate.toList, [.node h1]⟩,
    ⟨nu.getD 1 c.zero, eqs.2.2 :: gate.toList, [.node h2]⟩]

/-! ## The LogUp segment (`logup_subterms`) -/

/-- A lookup as the IR needs it: its denominator's constant `α − (cst + g_tag)` and its table terms `−coef·t`. -/
structure LkD (α : Type) where
  konst : α
  terms : List (α × ℕ)

def denB (l : LkD α) : Body α := .affine l.konst l.terms

/-- **The LogUp segment**, its first node at id `o`, its first helper at table `h0 + k`: per pair two denominators and
the relation `h·d₁·d₂ − d₁ − d₂`, an odd last lookup `h·d − 1`; the subterms `μ_k·relation_k`. -/
def logupGo (h0 : ℕ) (mu : ℕ → α) : ℕ → ℕ → List (LkD α) → List (SubTerm α) × List (Body α)
  | _, _, [] => ([], [])
  | k, o, [l] => ([st (mu k) [.node (o + 1)]], [denB l, .sum [st c.one [.tab (h0 + k), .node o], st c.negOne []]])
  | k, o, l₁ :: l₂ :: ls =>
    (st (mu k) [.node (o + 2)] :: (logupGo h0 mu (k + 1) (o + 3) ls).1,
      [denB l₁, denB l₂, .sum [st c.one [.tab (h0 + k), .node o, .node (o + 1)], st c.negOne [.node o],
        st c.negOne [.node (o + 1)]]] ++ (logupGo h0 mu (k + 1) (o + 3) ls).2)

/-! ## The pad segment (`IrPad`) -/

/-- **The pad segment**, its first node at `o`, the next ζ power `j`: per group `(supp, planes)` the nodes `1 − supp`
and `Σ ζ^j·plane`, the subterm `μ_pad·(1 − supp)·Σ ζ^j·plane`; the powers continue across the groups. -/
def padGo (mu : α) (zp : ℕ → α) : ℕ → ℕ → List (ℕ × List ℕ) → List (SubTerm α) × List (Body α)
  | _, _, [] => ([], [])
  | j, o, (s, ps) :: gs =>
    (st mu [.node o, .node (o + 1)] :: (padGo mu zp (j + ps.length) (o + 2) gs).1,
      [.affine c.one [(c.negOne, s)], .affine c.zero (ps.zipIdx.map fun q => (zp (j + q.2), q.1))]
        ++ (padGo mu zp (j + ps.length) (o + 2) gs).2)

/-! ## The zero-check template -/

/-- **A zero-check slot's IR** (every `*_w16` arm, `SC_TZC`, `SC_LZC`, `SC_TAB`): the slot's own nodes `pre`, the LogUp
segment, the pad segment, the zero-check node `Σ (logup ++ extra ++ pad ++ last)` at id `o3`, then the host nodes
`post (o3 + 1)`, and the terms `terms o3`. -/
def zcIr (pre : List (Body α)) (lks : List (LkD α)) (h0 : ℕ) (muL : ℕ → α) (extra : List (SubTerm α)) (padMu : α)
    (zp : ℕ → α) (groups : List (ℕ × List ℕ)) (last : List (SubTerm α)) (post : ℕ → List (Body α))
    (terms : ℕ → List (Term α)) : Ir α :=
  let lg := logupGo c h0 muL 0 pre.length lks
  let pd := padGo c padMu zp 0 (pre.length + lg.2.length) groups
  let o3 := pre.length + lg.2.length + pd.2.length
  ⟨pre ++ lg.2 ++ pd.2 ++ [.sum (lg.1 ++ extra ++ pd.1 ++ last)] ++ post (o3 + 1), terms o3⟩

end Builders

/-! ## The W16R2 slots -/

section Slots

variable {α : Type} (c : Cst α)

/-! ### The private and standalone slots of the generic arm -/

/-- `SC_SS` / `SC_SSM` (tables: `eq(r_t)`, the plane, `supp(D)`): `supp·eq·x·x`. -/
def ssIr (eq a : ℕ) (gate : Option ℕ) : Ir α := ⟨[], [⟨c.one, gate.toList, [.tab eq, .tab a, .tab a]⟩]⟩

/-- `SC_RS` (tables: `eq(p_ht)`, the mask, `E`, `ZSEL`, `supp(S)`): `supp·eq·(mask·e + λ·zsel)`. -/
def rsIr (eq mask e z : ℕ) (gate : Option ℕ) (lam : α) : Ir α :=
  ⟨[.sum [st c.one [.tab mask, .tab e], st lam [.tab z]]], [⟨c.one, gate.toList ++ [eq], [.node 0]⟩]⟩

/-- The matmuls (`SC_QMM`, `SC_KMM`, `SC_VMM`, `SC_WO`, `SC_GMM`, `SC_UMM`, `SC_DMM`): `plane·folded weight`. -/
def mmIr (a w : ℕ) : Ir α := ⟨[], [⟨c.one, [], [.tab a, .tab w]⟩]⟩

/-- `SC_SCORE` / `SC_PV`: `eq(r_g)·a·b` (no group table at one key-value head). -/
def bilIr (geq : Option ℕ) (a b : ℕ) : Ir α := ⟨[], [⟨c.one, geq.toList, [.tab a, .tab b]⟩]⟩

/-- `SC_ZS`: `ones·u`. -/
def zsIr (ones u : ℕ) : Ir α := ⟨[], [⟨c.one, [], [.tab ones, .tab u]⟩]⟩

/-- `SC_IO_IN` / `SC_IO_OUT`: `eq(τ)·(plane − endpoint)`. -/
def ioIr (tau a ep : ℕ) : Ir α := ⟨[.sum [st c.one [.tab a], st c.negOne [.tab ep]]], [⟨c.one, [tau], [.node 0]⟩]⟩

/-! ### `SC_TZC` (generic arm, `build_slot_ir` 977-1044) -/

/-- The tables of `SC_TZC`: `eq(τ)`, `eq(r_t)`, `eq(r_t2)`, `D`, `DSQ`, `D`'s nine limb slices, `DM`, `DSQM`, `DM`'s nine;
the gate `supp(T)`. -/
structure TzcR where
  tau : ℕ
  rt : ℕ
  rt2 : ℕ
  d : ℕ
  dsq : ℕ
  dm : ℕ
  dsqm : ℕ
  gate : Option ℕ

/-- `SC_TZC`'s own nodes: `dl, a1, a2, dl_m, a1_m, a2_m` (byte limbs), `c0 … c5`. -/
def tzcPre (R : TzcR) : List (Body α) :=
  let l := R.dsq + 1
  let lm := R.dsqm + 1
  [limbsB c [l, l + 1, l + 2], limbsB c [l + 3, l + 4, l + 5], limbsB c [l + 6, l + 7, l + 8],
    limbsB c [lm, lm + 1, lm + 2], limbsB c [lm + 3, lm + 4, lm + 5], limbsB c [lm + 6, lm + 7, lm + 8],
    .sum [st c.one [.tab R.dsq], st c.negOne [.tab R.d, .tab R.d]],
    .sum [st c.one [.tab R.d], st c.negOne [.node 0]],
    .sum [st (c.base 2) [.tab R.d], st c.negOne [.node 1], st c.negOne [.node 2]],
    .sum [st c.one [.tab R.dsqm], st c.negOne [.tab R.dm, .tab R.dm]],
    .sum [st c.one [.tab R.dm], st c.negOne [.node 3]],
    .sum [st (c.base 2) [.tab R.dm], st c.negOne [.node 4], st c.negOne [.node 5]]]

/-- `SC_TZC`'s host nodes `dsq + a1 − ceps`, `dsq_m + a1_m − ceps`. -/
def tzcPost (R : TzcR) (ceps : ℤ) (_o : ℕ) : List (Body α) :=
  [.sum [st c.one [.tab R.dsq], st c.one [.node 1], st (c.base (-ceps)) []],
    .sum [st c.one [.tab R.dsqm], st c.one [.node 4], st (c.base (-ceps)) []]]

/-- `SC_TZC`'s batch `μ_k·c_k`, written in the zero-check node directly (build_slot_ir 1026). -/
def tzcExtra (mu : List α) : List (SubTerm α) :=
  [st (mu.getD 0 c.zero) [.node 6], st (mu.getD 1 c.zero) [.node 7], st (mu.getD 2 c.zero) [.node 8],
    st (mu.getD 3 c.zero) [.node 9], st (mu.getD 4 c.zero) [.node 10], st (mu.getD 5 c.zero) [.node 11]]

/-- **`SC_TZC`**: the six clauses batched by `μ_0 … μ_5` directly in the zero-check node; the pad term (`μ_6`, ζ) of
`Dom::T` where it pads. -/

def tzcIr (R : TzcR) (ceps : ℤ) (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c (tzcPre c R) [] 0 (fun _ => c.zero) (tzcExtra c mu) (mu.getD 6 c.zero) zp groups [] (tzcPost c R ceps)
    (fun o => threeTerms c (R.tau, R.rt, R.rt2) R.gate o nu (o + 1) (o + 2))

/-! ### `SC_LZC` (generic arm, 1045-1064) and `SC_TAB` (`tab_w16`) -/

/-- **`SC_LZC`**: the limb LogUp with the all-ones weight, the pad term with its own weight `μ_pad`. -/
def lzcIr (tau h0 : ℕ) (lks : List (LkD α)) (muPad : α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c [] lks h0 (fun _ => c.one) [] muPad zp groups [] (fun _ => []) (fun o => [⟨c.one, [tau], [.node o]⟩])

/-- **`SC_TAB`'s relations** (`tab_w16`'s loop), the first node at id `o`: per table `(m, h, tv)` (multiplicity,
helper, value column) the denominator `α − tv` and the relation `h·(α − tv) − m`; the subterms `μ_k·relation_k`. -/
def tabGo (alpha : α) (mu : List α) : ℕ → ℕ → List (ℕ × ℕ × ℕ) → List (SubTerm α) × List (Body α)
  | _, _, [] => ([], [])
  | k, o, (m, h, tv) :: ts =>
    (st (mu.getD k c.zero) [.node (o + 1)] :: (tabGo alpha mu (k + 1) (o + 2) ts).1,
      [.affine alpha [(c.negOne, tv)], .sum [st c.one [.tab h, .node o], st c.negOne [.tab m]]]
        ++ (tabGo alpha mu (k + 1) (o + 2) ts).2)

/-- **`SC_TAB`** (`tab_w16`): `Σ_k μ_k·(h_k·(α − t_k) − m_k)` and the pad groups (bytes, activation, the narrow range
families), batched by `μ_{3 + #range}`. -/
def tabIr (tau : ℕ) (alpha : α) (ts : List (ℕ × ℕ × ℕ)) (mu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    Ir α :=
  zcIr c (tabGo c alpha mu 0 0 ts).2 [] 0 (fun _ => c.zero) (tabGo c alpha mu 0 0 ts).1
    (mu.getD ts.length c.zero) zp groups [] (fun _ => []) (fun o => [⟨c.one, [tau], [.node o]⟩])

/-! ### `SC_DZC` (`dzc_w16`) -/

/-- The tables of `dzc_w16` that its nodes read. -/
structure DzcR where
  tau : ℕ
  pa : ℕ
  pz : ℕ
  ig : ℕ
  igm : ℕ
  x : ℕ
  y : ℕ
  ao : ℕ
  x1 : ℕ
  ym : ℕ
  z : ℕ
  x2 : ℕ
  nr : List ℕ
  ns : List ℕ
  mr : List ℕ
  ms : List ℕ
  ral : List ℕ
  rdl : List ℕ
  id : ℕ
  idm : ℕ
  h0 : ℕ
  gate : Option ℕ

/-- The shape's constants `dzc_w16` writes: `2·cn_a`, `2·cn_m`, `2^tn`, `2^(tn+1)`, the attention-output and down
shifts. -/
structure DzcK where
  num : ℤ
  numM : ℤ
  dv : ℤ
  den : ℤ
  sao : ℕ
  sdown : ℕ

/-- `dzc_w16`'s own nodes: `nr, ns, mr, ms` (16-bit limbs), `c0 … c5`, the batch `cl`. -/
def dzcPre (R : DzcR) (K : DzcK) (mu : List α) : List (Body α) :=
  [limbs16B c R.nr, limbs16B c R.ns, limbs16B c R.mr, limbs16B c R.ms,
    .sum [st (c.base K.num) [.tab R.ig, .tab R.x], st (c.base K.dv) [.tab R.id], st (c.base (-K.den)) [.tab R.y, .tab R.id],
      st c.negOne [.node 0]],
    .sum [st c.one [.node 0], st c.one [.node 1], st c.one [], st (c.base (-K.den)) [.tab R.id]],
    .sum [st c.one [.tab R.x1], st c.negOne [.tab R.x], st c.negOne [.tab R.ao]],
    .sum [st (c.base K.numM) [.tab R.igm, .tab R.x1], st (c.base K.dv) [.tab R.idm],
      st (c.base (-K.den)) [.tab R.ym, .tab R.idm], st c.negOne [.node 2]],
    .sum [st c.one [.node 2], st c.one [.node 3], st c.one [], st (c.base (-K.den)) [.tab R.idm]],
    .sum [st c.one [.tab R.x2], st c.negOne [.tab R.x1], st c.negOne [.tab R.z]],
    batchB c mu [4, 5, 6, 7, 8, 9]]

/-- `dzc_w16`'s host nodes: `requant16(SC_WO)` and `requant16(SC_DMM)`, from id `o`. -/
def dzcPost (R : DzcR) (K : DzcK) (o : ℕ) : List (Body α) :=
  [limbs16B c R.ral, reqB c K.sao R.ao o, limbs16B c R.rdl, reqB c K.sdown R.z (o + 2)]

/-- **`SC_DZC`** (`dzc_w16`). -/
def dzcIr (R : DzcR) (K : DzcK) (lks : List (LkD α)) (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    Ir α :=
  zcIr c (dzcPre c R K mu) lks R.h0 (fun k => mu.getD (6 + k) c.zero) [] (mu.getD (6 + (lks.length + 1) / 2) c.zero) zp
    groups [gatedSt c R.gate 10] (dzcPost c R K)
    (fun o => threeTerms c (R.tau, R.pa, R.pz) R.gate o nu (o + 2) (o + 4))

/-! ### `SC_FZC` (`fzc_w16`) -/

structure FzcR where
  tau : ℕ
  pg : ℕ
  pu : ℕ
  g : ℕ
  a : ℕ
  u : ℕ
  h : ℕ
  rg : List ℕ
  ru : List ℕ
  rh : List ℕ
  h0 : ℕ
  fact : ℕ
  group : ℕ
  gate : Option ℕ

/-- The shifts `fzc_w16` writes: the product fold's `r`, the gate's and the up projection's. -/
structure FzcK where
  r : ℕ
  sgate : ℕ
  sup : ℕ

/-- `fzc_w16`'s own nodes: `rh` (limbs), `f0`, `α − query` (the ACT tuple's denominator), `fa`, the batch `ar`.
`amqK = α − 2048 − g_act`, `nb = −β`, `nb2 = −β²`. -/
def fzcPre (R : FzcR) (K : FzcK) (mu : List α) (amqK nb nb2 : α) : List (Body α) :=
  [limbs16B c R.rh,
    .sum [st c.one [.tab R.a, .tab R.u], st (c.base (-(2 ^ K.r : ℤ))) [.tab R.h], st c.negOne [.node 0],
      st (c.base (2 ^ (K.r - 1))) []],
    .affine amqK [(c.negOne, R.g), (nb, R.a), (nb2, R.group)],
    .sum [st c.one [.tab R.fact, .node 2], st c.negOne []],
    batchB c mu [1]]

def fzcPost (R : FzcR) (K : FzcK) (o : ℕ) : List (Body α) :=
  [limbs16B c R.rg, reqB c K.sgate R.g o, limbs16B c R.ru, reqB c K.sup R.u (o + 2)]

/-- **`SC_FZC`** (`fzc_w16`): LogUp at `μ_{2+k}`, the ACT tuple at `μ_1`, the pad term, the gated product clause. -/
def fzcIr (R : FzcR) (K : FzcK) (lks : List (LkD α)) (mu nu : List α) (amqK nb nb2 : α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c (fzcPre c R K mu amqK nb nb2) lks R.h0 (fun k => mu.getD (2 + k) c.zero) [st (mu.getD 1 c.zero) [.node 3]]
    (mu.getD (2 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c R.gate 4] (fzcPost c R K)
    (fun o => threeTerms c (R.tau, R.pg, R.pu) R.gate o nu (o + 2) (o + 4))

/-! ### `SC_QZC` / `SC_KVZC` (`qzc_w16`) -/

structure QzcR where
  tau : ℕ
  p1 : ℕ
  p2 : ℕ
  cos : ℕ
  sin : ℕ
  src : ℕ
  rot : ℕ
  oth : ℕ
  flip : ℕ
  rr : List ℕ
  r1 : List ℕ
  r2 : List ℕ
  h0 : ℕ
  gate : Option ℕ

/-- The shifts `qzc_w16` writes: `SH_ROPE` and the two hosts'. -/
structure QzcK where
  rope : ℕ
  s1 : ℕ
  s2 : ℕ

def qzcPre (R : QzcR) (K : QzcK) (mu : List α) : List (Body α) :=
  [limbs16B c R.rr,
    .sum [st c.one [.tab R.cos, .tab R.src], st c.one [.tab R.sin, .tab R.flip], st (c.base (-(2 ^ K.rope : ℤ))) [.tab R.rot],
      st c.negOne [.node 0], st (c.base (2 ^ (K.rope - 1))) []],
    batchB c mu [1]]

def qzcPost (R : QzcR) (K : QzcK) (o : ℕ) : List (Body α) :=
  [limbs16B c R.r1, reqB c K.s1 R.src o, limbs16B c R.r2, reqB c K.s2 R.oth (o + 2)]

/-- **`SC_QZC` / `SC_KVZC`** (`qzc_w16`): LogUp at `μ_{1+k}`, the pad term, the gated RoPE clause. -/
def qzcIr (R : QzcR) (K : QzcK) (lks : List (LkD α)) (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    Ir α :=
  zcIr c (qzcPre c R K mu) lks R.h0 (fun k => mu.getD (1 + k) c.zero) [] (mu.getD (1 + (lks.length + 1) / 2) c.zero) zp
    groups [gatedSt c R.gate 2] (qzcPost c R K)
    (fun o => threeTerms c (R.tau, R.p1, R.p2) R.gate o nu (o + 2) (o + 4))

/-! ### `SC_SZC` (`szc_w16`) -/

structure SzcR where
  tau : ℕ
  pht : ℕ
  ps : ℕ
  mask : ℕ
  s8 : ℕ
  zsel : ℕ
  e : ℕ
  p : ℕ
  sr : List ℕ
  sg : List ℕ
  rsl : List ℕ
  mx : ℕ
  sum : ℕ
  h0 : ℕ
  hx : ℕ
  gHt : Option ℕ
  gS : Option ℕ

/-- The constants `szc_w16` writes: `−MASK_SCORE = 127`, `2^f_p`, the score shift. -/
structure SzcK where
  ms : ℤ
  fp : ℕ
  score : ℕ

/-- `szc_w16`'s own nodes: `δ`, `sr`, `sg` (limbs), `c0 … c3`, `α − δ − β·e − g_exp`, `cx`, the batch `cl`.
`amdK = α − g_exp`, `nb = −β`. -/
def szcPre (R : SzcR) (K : SzcK) (mu : List α) (amdK nb : α) : List (Body α) :=
  [.sum [st c.one [.tab R.mx], st c.negOne [.tab R.mask, .tab R.s8], st (c.base (-K.ms)) [.tab R.mask], st (c.base K.ms) []],
    limbs16B c R.sr, limbs16B c R.sg,
    .sum [st c.one [.tab R.zsel, .tab R.zsel], st c.negOne [.tab R.zsel]],
    .sum [st c.one [.tab R.zsel, .node 0]],
    .sum [st (c.base (2 ^ K.fp)) [.tab R.mask, .tab R.e], st c.negOne [.tab R.p, .tab R.sum], st c.negOne [.node 1]],
    .sum [st c.one [.node 2], st c.one [.node 1], st c.one [], st c.negOne [.tab R.sum]],
    .sum [st amdK [], st c.negOne [.node 0], st nb [.tab R.e]],
    .sum [st c.one [.tab R.hx, .node 7], st c.negOne []],
    batchB c mu [3, 4, 5, 6]]

/-- `szc_w16`'s host nodes: `sum + λ`, `rsl` (limbs), `2^score·s8 + rsl − half(score)`. -/
def szcPost (R : SzcR) (K : SzcK) (lam : α) (o : ℕ) : List (Body α) :=
  [.sum [st c.one [.tab R.sum], st lam []], limbs16B c R.rsl, reqB c K.score R.s8 (o + 1)]

/-- **`SC_SZC`** (`szc_w16`): LogUp at `μ_{4+k}`, the exp tuple at `μ_{4+#helpers}`, the pad term, the gated
softmax clauses; hosts `SC_RS` (`ν_0`, gate `supp(Ht)`) and `SC_SCORE` (`ν_1`, gate `supp(S)`). -/
def szcIr (R : SzcR) (K : SzcK) (lks : List (LkD α)) (mu nu : List α) (amdK nb lam : α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c (szcPre c R K mu amdK nb) lks R.h0 (fun k => mu.getD (4 + k) c.zero)
    [st (mu.getD (4 + (lks.length + 1) / 2) c.zero) [.node 8]] (mu.getD (5 + (lks.length + 1) / 2) c.zero) zp groups
    [gatedSt c R.gS 9] (szcPost c R K lam)
    (fun o => [⟨c.one, [R.tau], [.node o]⟩, ⟨nu.getD 0 c.zero, R.pht :: R.gHt.toList, [.node (o + 1)]⟩,
      ⟨nu.getD 1 c.zero, R.ps :: R.gS.toList, [.node (o + 3)]⟩])

end Slots

end ZK60.Exec.Slot.Build
