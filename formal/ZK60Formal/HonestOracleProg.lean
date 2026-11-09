/-
D63 Lean lane L29 (2026-11-07), part 6: **the honest prover's ORACLE FORM, the transcript-program combinators, and the
stages' refusal sites as transcript programs** (lane L25's L25-3: O9's transcript-program sites, O10's `δ = 0`).

L25's `TProg` is a refusal site's computation as the oracle sees it: absorbs and squeezes of ONE transcript (each
continuation reads the squeeze's output) and outside queries (`ext`), its site the transcript's NEXT squeeze;
`tprogSite` turns one into L18's `Site` with `δ = 0` PROVED (`tprog_point_fresh`). The honest prover's computation up to
any of its refusals is such a program built by sequencing (`bindP`) the pieces the code runs, in its order:
* `drawsP n` (`challenge_fp2_vec(n)`), `.absorb` (every `absorb*`), `scP` (the honest sumcheck's rounds: each round's
  words absorbed under `"sc-round"`, then its challenge, the next words the strategy's at it: L25's `scProve`);
* a commitment's root as a program `RootProg` (its Merkle hashes: queries that are never 47 bytes long, so they are
  separated from every transcript squeeze whatever their keys: a node or a salted leaf is 64 bytes, a column digest a
  multiple of 8; finding L19-3's programmed points are exactly these queries);
* the transcript's creation (`Transcript::new_tagged`: one query of `"hashline-v1/" ‖ profile`, `startP`, never 47
  bytes for the registered profiles: 96 bytes at Shieldstral T128, L25-5).

Proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `bindP`, **`final_bindP`**, `sep_bindP`; `SqLE` (at most `n` squeezes on every path), **`noWrap_of_sqLE`** (no wrap
  below `2^64` squeezes), `sqLE_bindP`, `sqLE_mono`;
* `drawsP`, **`final_drawsP`**; `scP`, **`final_scP`** (the honest sumcheck as a program is L25's `scProve`);
* `RootProg`, `final_rootP`; `StartProg`, **`startProg_point_fresh`** (`δ = 0` for a site whose computation creates
  the transcript: the start query is not 47 bytes);
* **`slotCProg`**, `final_slotCProg`, **`slotCSite`**, **`slotCSite_fires`**: every slot's CFS refusal (`c = 0`, the
  squeeze after `pb-slot`) is a transcript-program site, `k = 1`, `δ = 0`, firing EXACTLY when the honest prover's
  guard does (L25's `slot_c_guard_iff`), after ANY prefix program that ends at the slot's entry;
* **`outcAlphaProg`**, `final_outcAlphaProg`, **`outcAlphaSite`**, **`outcAlphaSite_fires`**: stage OUT-C's D66(3)
  refusal is a transcript-program site with at most 256 bad values (the byte table's `z + γ·TAG_U8`), `δ = 0`, firing
  EXACTLY when `outcProve`'s guard does, after any prefix program ending at OUT-C's start, with `A`'s and `M`'s roots
  computed by their Merkle programs.
-/
import ZK60Formal.StageVerifyExecComplete
import ZK60Formal.HonestClassifyCount

set_option autoImplicit false

namespace ZK60.HonestOracle

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.HonestClassify ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams labA labH labM labRows labLogCols labPbSlot absorbRoot)
open ZK60.Exec.StageV

/-! ## Sequencing transcript programs -/

section Seq

variable {α β : Type}

/-- **Sequencing**: the first program's result feeds the second (`done a` replaced by `f a`). -/
def bindP : TProg α → (α → TProg β) → TProg β
  | .done a, f => f a
  | .absorb l d k, f => .absorb l d (bindP k f)
  | .squeeze k, f => .squeeze (fun dg => bindP (k dg) f)
  | .ext q k, f => .ext q (fun dg => bindP (k dg) f)

variable (H : HIn → Dig)

/-- **A sequence runs the first program, then the second from where it ended.** -/
theorem final_bindP : ∀ (p : TProg α) (f : α → TProg β) (t : Tr),
    (bindP p f).final H t = (f (p.final H t).2).final H (p.final H t).1
  | .done _, _, _ => rfl
  | .absorb _ _ k, f, t => final_bindP k f _
  | .squeeze k, f, t => final_bindP (k _) f _
  | .ext _ k, f, t => final_bindP (k _) f t

theorem sep_bindP (key : Option Dig) : ∀ (p : TProg α) (f : α → TProg β), TProg.Sep key p →
    (∀ a, TProg.Sep key (f a)) → TProg.Sep key (bindP p f)
  | .done a, _, _, hf => hf a
  | .absorb _ _ k, f, hp, hf => sep_bindP key k f hp hf
  | .squeeze k, f, hp, hf => fun dg => sep_bindP key (k dg) f (hp dg) hf
  | .ext _ k, f, hp, hf => ⟨hp.1, fun dg => sep_bindP key (k dg) f (hp.2 dg) hf⟩

/-- **At most `n` squeezes on every path.** -/
def SqLE : ℕ → TProg α → Prop
  | _, .done _ => True
  | n, .absorb _ _ k => SqLE n k
  | 0, .squeeze _ => False
  | n + 1, .squeeze k => ∀ dg, SqLE n (k dg)
  | n, .ext _ k => ∀ dg, SqLE n (k dg)

/-- **Fewer than `2^64` squeezes from the transcript's counter: no wrap** (L25's `NoWrap`). -/
theorem noWrap_of_sqLE : ∀ (p : TProg α) (n : ℕ) (t : Tr), SqLE n p → t.counter.toNat + n < 2 ^ 64 → TProg.NoWrap p t
  | .done _, _, _, _, _ => trivial
  | .absorb _ _ k, n, t, hp, hc => fun dg => noWrap_of_sqLE k n { t with state := dg } hp hc
  | .squeeze _, 0, _, hp, _ => False.elim hp
  | .squeeze k, n + 1, t, hp, hc => by
    have h1 : t.counter.toNat + 1 < 2 ^ 64 := lt_of_le_of_lt (by omega) hc
    refine ⟨h1, fun dg => noWrap_of_sqLE (k dg) n { t with state := dg, counter := t.counter + 1 } (hp dg) ?_⟩
    show (t.counter + 1).toNat + n < 2 ^ 64
    rw [UInt64.toNat_add, UInt64.toNat_one, Nat.mod_eq_of_lt h1]
    exact lt_of_le_of_lt (by omega) hc
  | .ext _ k, n, t, hp, hc => fun dg => noWrap_of_sqLE (k dg) n t (hp dg) hc

theorem sqLE_mono : ∀ (p : TProg α) (m n : ℕ), SqLE m p → m ≤ n → SqLE n p
  | .done _, _, _, _, _ => trivial
  | .absorb _ _ k, m, n, hp, h => sqLE_mono k m n hp h
  | .squeeze _, 0, _, hp, _ => False.elim hp
  | .squeeze _, _ + 1, 0, _, h => by omega
  | .squeeze k, m + 1, n + 1, hp, h => fun dg => sqLE_mono (k dg) m n (hp dg) (by omega)
  | .ext _ k, m, n, hp, h => fun dg => sqLE_mono (k dg) m n (hp dg) h

theorem sqLE_bindP : ∀ (p : TProg α) (f : α → TProg β) (m n : ℕ), SqLE m p → (∀ a, SqLE n (f a)) →
    SqLE (m + n) (bindP p f)
  | .done a, _, m, n, _, hf => sqLE_mono _ n (m + n) (hf a) (by omega)
  | .absorb _ _ k, f, m, n, hp, hf => sqLE_bindP k f m n hp hf
  | .squeeze _, _, 0, _, hp, _ => False.elim hp
  | .squeeze k, f, m + 1, n, hp, hf => by
    rw [show m + 1 + n = (m + n) + 1 by omega]
    exact fun dg => sqLE_bindP (k dg) f m n (hp dg) hf
  | .ext _ k, f, m, n, hp, hf => fun dg => sqLE_bindP (k dg) f m n (hp dg) hf

end Seq

/-! ## The pieces the code runs -/

section Pieces

variable {β : Type} (H : HIn → Dig)

/-- **`challenge_fp2_vec(n)`** as a program: `n` squeezes, the continuation reads the challenges. -/
def drawsP : ℕ → (List Fp2 → TProg β) → TProg β
  | 0, k => k []
  | n + 1, k => .squeeze (fun dg => drawsP n (fun rs => k (challengeFp2Of dg :: rs)))

theorem final_drawsP : ∀ (n : ℕ) (k : List Fp2 → TProg β) (t : Tr),
    (drawsP n k).final H t = (k (t.challengeFp2Vec H n).1).final H (t.challengeFp2Vec H n).2
  | 0, _, _ => rfl
  | n + 1, k, t => final_drawsP n (fun rs => k (challengeFp2Of (t.squeeze H).1 :: rs)) (t.squeeze H).2

theorem sep_drawsP (key : Option Dig) : ∀ (n : ℕ) (k : List Fp2 → TProg β), (∀ rs, TProg.Sep key (k rs)) →
    TProg.Sep key (drawsP n k)
  | 0, _, hk => hk []
  | n + 1, k, hk => fun dg => sep_drawsP key n _ (fun rs => hk _)

theorem sqLE_drawsP : ∀ (n m : ℕ) (k : List Fp2 → TProg β), (∀ rs, SqLE m (k rs)) → SqLE (n + m) (drawsP n k)
  | 0, m, k, hk => by simpa using hk []
  | n + 1, m, k, hk => by
    rw [show n + 1 + m = (n + m) + 1 by omega]
    exact fun dg => sqLE_drawsP n m _ (fun rs => hk _)

/-- **The honest sumcheck as a program** (L25's `scProve`): each round's words absorbed under `"sc-round"`, then its
challenge; the continuation reads the rounds. -/
def scP : (n : ℕ) → WProver n → (List (List Fp2) → TProg β) → TProg β
  | 0, _, k => k []
  | n + 1, p, k => .absorb scLabel (p.1.flatMap Fp2.toBytes)
      (.squeeze (fun dg => scP n (p.2 (challengeFp2Of dg)) (fun rs => k (p.1 :: rs))))

theorem final_scP : ∀ (n : ℕ) (p : WProver n) (k : List (List Fp2) → TProg β) (t : Tr),
    (scP n p k).final H t = (k (scProve H n p t).1).final H (scProve H n p t).2
  | 0, _, _, _ => rfl
  | n + 1, p, k, t => final_scP n _ (fun rs => k (p.1 :: rs)) _

theorem sep_scP (key : Option Dig) : ∀ (n : ℕ) (p : WProver n) (k : List (List Fp2) → TProg β),
    (∀ rs, TProg.Sep key (k rs)) → TProg.Sep key (scP n p k)
  | 0, _, _, hk => hk []
  | n + 1, p, k, hk => fun dg => sep_scP key n _ _ (fun rs => hk _)

theorem sqLE_scP : ∀ (n m : ℕ) (p : WProver n) (k : List (List Fp2) → TProg β), (∀ rs, SqLE m (k rs)) →
    SqLE (n + m) (scP n p k)
  | 0, m, _, k, hk => by simpa using hk []
  | n + 1, m, p, k, hk => by
    show SqLE (n + 1 + m) (TProg.squeeze _)
    rw [show n + 1 + m = (n + m) + 1 by omega]
    exact fun dg => sqLE_scP n m _ _ (fun rs => hk _)

/-- **A commitment's root as a program** (the honest commitment's Merkle hashes): it does not touch the transcript, it
returns the root the honest data commits (`root H`), every outside query it makes is not 47 bytes long (separated from
every transcript squeeze, whatever its key), and it makes no squeeze. -/
structure RootProg (root : (HIn → Dig) → Dig) where
  p : TProg Dig
  final_eq : ∀ (H : HIn → Dig) (t : Tr), p.final H t = (t, root H)
  sep : ∀ key, TProg.Sep key p
  sq : SqLE 0 p

/-- Absorb a root under its label with its rows and log-columns (`absorb_root`), after computing it. -/
def absorbRootP {root : (HIn → Dig) → Dig} (r : RootProg root) (label : List UInt8) (rows logCols : ℕ)
    (k : Dig → TProg β) : TProg β :=
  bindP r.p (fun d => .absorb label d.toList (.absorb labRows (le64 (UInt64.ofNat rows))
    (.absorb labLogCols (le64 (UInt64.ofNat logCols)) (k d))))

theorem final_absorbRootP {root : (HIn → Dig) → Dig} (r : RootProg root) (label : List UInt8) (rows logCols : ℕ)
    (k : Dig → TProg β) (t : Tr) :
    (absorbRootP r label rows logCols k).final H t = (k (root H)).final H (absorbRoot H t label (root H) rows logCols) := by
  unfold absorbRootP
  rw [final_bindP, r.final_eq]
  rfl

end Pieces

/-! ## The transcript's creation: `δ = 0` from the very first query -/

section Start

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {β : Type}

/-- **A site's computation from the transcript's creation** (`Transcript::new_tagged`): the start query
`"hashline-v1/" ‖ domain` under the key, then a transcript program from the fresh transcript (counter `0`). -/
structure StartProg (β : Type) where
  key : Option Dig
  domain : List UInt8
  p : TProg β

/-- Its oracle computation on `QB Lq`: the start query, then L25's `TProg.oc` from `⟨state, 0, key⟩`. -/
def StartProg.oc (s : StartProg β) : OC (QB Lq) Dig (QB Lq × β) :=
  TProg.askQ Lq ⟨s.key, startMsg s.domain⟩ (fun dg => s.p.oc Lq hLq ⟨dg, 0, s.key⟩)

/-- **The site's point is never asked by its own computation from the transcript's creation** (L25's
`tprog_point_fresh` and the start query, which is not 47 bytes: `startMsg` has `12 + |domain|` bytes). -/
theorem startProg_point_fresh (G : QB Lq → Dig) (s : StartProg β) (hdom : s.domain.length ≠ 35)
    (hs : TProg.Sep s.key s.p) (hn : ∀ dg, TProg.NoWrap s.p ⟨dg, 0, s.key⟩) :
    ((s.oc Lq hLq).run G).1 ∉ OC.queries G (s.oc Lq hLq) := by
  intro hmem
  have hrun : (s.oc Lq hLq).run G = (s.p.oc Lq hLq ⟨liftH G ⟨s.key, startMsg s.domain⟩, 0, s.key⟩).run G :=
    TProg.askQ_run Lq G _ _
  rw [hrun] at hmem
  rcases TProg.queries_askQ Lq G _ _ _ hmem with ⟨_, e2⟩ | e
  · -- the start query is not a squeeze input
    rw [TProg.oc_run] at e2
    have h47 : (startMsg s.domain).length ≠ 47 := by
      simp only [startMsg, startTag, List.length_append, List.length_cons, List.length_nil]
      omega
    exact h47 (by rw [← e2]; simp [TProg.sqPoint, squeezeMsg_length])
  · exact TProg.tprog_point_fresh Lq hLq G s.p _ hs (hn _) e

end Start

/-! ## A slot's CFS refusal as a transcript-program site -/

section SlotSite

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} (H : HIn → Dig) (P : BlockParams) (s : ℕ)

/-- **A slot's prefix program**: after a prefix `pre` ending at the slot's entry (its data `a`), `define`'s draws and
`absorb_u64("pb-slot", s)`; the next squeeze is the slot's CFS challenge `c`. -/
def slotCProg (pre : TProg α) : TProg (α × List Fp2) :=
  bindP pre (fun a => drawsP (P.draws s) (fun dr => .absorb labPbSlot (le64 (UInt64.ofNat s)) (.done (a, dr))))

theorem final_slotCProg (pre : TProg α) (t : Tr) :
    (slotCProg P s pre).final H t
      = (slotT2 H P s (pre.final H t).1, ((pre.final H t).2, ((pre.final H t).1.challengeFp2Vec H (P.draws s)).1)) := by
  unfold slotCProg
  rw [final_bindP, final_drawsP]
  rfl

theorem sep_slotCProg (key : Option Dig) (pre : TProg α) (hp : TProg.Sep key pre) : TProg.Sep key (slotCProg P s pre) :=
  sep_bindP key pre _ hp (fun _ => sep_drawsP key _ _ (fun _ => trivial))

/-- **The `j`-th draw of `challenge_fp2_vec(n)` is the challenge at the squeeze after the first `j`** (`j < n`). -/
theorem challengeFp2Vec_getD : ∀ (n j : ℕ) (t : Tr), j < n →
    (t.challengeFp2Vec H n).1.getD j Fp2.zero
      = challengeFp2Of (H ⟨(t.challengeFp2Vec H j).2.key, squeezeMsg (t.challengeFp2Vec H j).2.state
          (t.challengeFp2Vec H j).2.counter⟩)
  | 0, _, _, h => absurd h (Nat.not_lt_zero _)
  | n + 1, 0, t, _ => rfl
  | n + 1, j + 1, t, h => challengeFp2Vec_getD n j (t.squeeze H).2 (by omega)

/-- **A draw's prefix program**: after a prefix `pre` ending at slot `s`'s entry, the first `j` of `define`'s draws; the
next squeeze is draw `j` (a batching coefficient, `ν`, `ζ`, refused by `nonzero` when zero). -/
def drawProg (j : ℕ) (pre : TProg α) : TProg (α × List Fp2) :=
  bindP pre (fun a => drawsP j (fun dr => .done (a, dr)))

theorem final_drawProg (j : ℕ) (pre : TProg α) (t : Tr) :
    (drawProg j pre).final H t
      = (((pre.final H t).1.challengeFp2Vec H j).2, ((pre.final H t).2, ((pre.final H t).1.challengeFp2Vec H j).1)) := by
  unfold drawProg
  rw [final_bindP, final_drawsP]
  rfl

variable {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **The CFS refusal of slot `s` as L18's `Site`** (`tprogSite`): the computation is the prefix and the slot's
prefix, the bad set `{0}` (`k = 1`), `δ = 0` PROVED. -/
noncomputable def slotCSite (pre : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (slotCProg P s (pre c)) (t0 c)) : Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => slotCProg P s (pre c)) t0 (fun _ => ({0} : Finset K)) 1 (fun _ => by simp)
    (fun c => sep_slotCProg P s _ (pre c) (hs c)) hn

/-- **A zero draw of `define` as L18's `Site`** (`k = 1`, `δ = 0`). -/
noncomputable def drawZeroSite (j : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (drawProg j (pre c)) (t0 c)) : Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => drawProg j (pre c)) t0 (fun _ => ({0} : Finset K)) 1 (fun _ => by simp)
    (fun c => sep_bindP _ (pre c) _ (hs c) (fun _ => sep_drawsP _ j _ (fun _ => trivial))) hn

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The site fires EXACTLY when the honest slot prover's CFS guard does** (L25's `slot_c_guard_iff`), at the transcript
the prefix leaves: every slot's `c = 0` refusal is a `δ = 0` site once the run up to the slot is a transcript program. -/
theorem slotCSite_fires (pre : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (slotCProg P s (pre c)) (t0 c)) (G : QB Lq → Dig) (c : Coins) :
    (slotCSite Lq hLq P s pre t0 hs hn (K := K)).fires U G c
      ↔ (slotC (liftH G) P s ((pre c).final (liftH G) (t0 c)).1).isZero = true := by
  unfold slotCSite
  rw [tprogSite_fires, final_slotCProg, slot_c_guard_iff U hU]

/-- **`define`'s zero-draw refusal is a site event**: the site of draw `j` fires EXACTLY when draw `j` of slot `s`'s
`challenge_fp2_vec(draws s)` (at the transcript the prefix leaves) is zero; `nonzero` refuses exactly when one of the
batching coordinates is (`nonzeroE`). -/
theorem drawZeroSite_fires (j : ℕ) (hj : j < P.draws s) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (drawProg j (pre c)) (t0 c)) (G : QB Lq → Dig)
    (c : Coins) :
    (drawZeroSite Lq hLq j pre t0 hs hn (K := K)).fires U G c
      ↔ ((((pre c).final (liftH G) (t0 c)).1.challengeFp2Vec (liftH G) (P.draws s)).1.getD j Fp2.zero).isZero = true := by
  unfold drawZeroSite
  rw [tprogSite_fires, final_drawProg, challengeFp2Vec_getD (liftH G) _ j _ hj, Finset.mem_singleton,
    isZero_iff_toK U hU _ (canon_challengeFp2Of _)]

end SlotSite

/-! ## A slot's extension challenges as transcript-program sites (the degenerate-`e` refusal) -/

section ExtSite

variable (Lq : ℕ) (hLq : 47 ≤ Lq) (H : HIn → Dig)

/-- **The honest sumcheck up to round `m`'s words**: rounds `0 … m − 1` in full, then round `m`'s words absorbed; the
next squeeze is round `m`'s challenge. -/
def scUpToP : (N : ℕ) → WProver N → ℕ → TProg Unit
  | 0, _, _ => .done ()
  | _ + 1, p, 0 => .absorb scLabel (p.1.flatMap Fp2.toBytes) (.done ())
  | N + 1, p, m + 1 => .absorb scLabel (p.1.flatMap Fp2.toBytes)
      (.squeeze (fun dg => scUpToP N (p.2 (challengeFp2Of dg)) m))

/-- **Round `m`'s challenge of the honest sumcheck is the challenge at the squeeze after `scUpToP m`** (`m < N`). -/
theorem scUpTo_chal : ∀ (N : ℕ) (p : WProver N) (m : ℕ) (t : Tr), m < N →
    (scChal H (scProve H N p t).1 t).1.getD m Fp2.zero
      = challengeFp2Of (H ⟨((scUpToP N p m).final H t).1.key, squeezeMsg ((scUpToP N p m).final H t).1.state
          ((scUpToP N p m).final H t).1.counter⟩)
  | 0, _, _, _, h => absurd h (Nat.not_lt_zero _)
  | _ + 1, _, 0, _, _ => rfl
  | N + 1, p, m + 1, t, h => scUpTo_chal N _ m _ (by omega)

theorem sep_scUpToP (key : Option Dig) : ∀ (N : ℕ) (p : WProver N) (m : ℕ), TProg.Sep key (scUpToP N p m)
  | 0, _, _ => trivial
  | _ + 1, _, 0 => trivial
  | N + 1, p, m + 1 => fun dg => sep_scUpToP key N _ m

variable (P : BlockParams) (s : ℕ) (D : SlotData P)

/-- **A slot's prefix up to round `m`'s words** (the extension challenges are the rounds `n … n + e − 1`): after a
prefix `pre` ending at the slot's entry (its history and accumulator), `define`'s draws, `pb-slot`, the CFS challenge
`c`, the published scalar (`absorb_fp2("pb-scalar")`), the honest rounds up to round `m`'s words. -/
def slotEProg (m : ℕ) (pre : TProg (Block.Hist × Block.Acc)) : TProg Unit :=
  bindP (slotCProg P s pre) (fun ad => .squeeze (fun dgc =>
    match P.define s ad.1.1 ad.2 with
    | .ok df => .absorb labPbScalar ([D.scalar s ad.1.1 ad.1.2 df (challengeFp2Of dgc)].flatMap Fp2.toBytes)
        (scUpToP (slotN P s) (D.strat s ad.1.1 ad.1.2 df (challengeFp2Of dgc)) m)
    | .error _ => .done ()))

/-- **The prefix's final transcript is the honest slot's** (through L25's `slotT2`, `slotC`, `slotT4`). -/
theorem final_slotEProg (m : ℕ) (pre : TProg (Block.Hist × Block.Acc)) (t : Tr) (df : Block.SlotDef)
    (hdf : P.define s (pre.final H t).2.1 ((pre.final H t).1.challengeFp2Vec H (P.draws s)).1 = .ok df) :
    ((slotEProg P s D m pre).final H t).1
      = ((scUpToP (slotN P s) (D.strat s (pre.final H t).2.1 (pre.final H t).2.2 df (slotC H P s (pre.final H t).1)) m).final
          H (slotT4 H P s (pre.final H t).1 (D.scalar s (pre.final H t).2.1 (pre.final H t).2.2 df
            (slotC H P s (pre.final H t).1)))).1 := by
  unfold slotEProg
  rw [final_bindP, final_slotCProg]
  show (match P.define s (pre.final H t).2.1 ((pre.final H t).1.challengeFp2Vec H (P.draws s)).1 with
      | .ok df => TProg.absorb labPbScalar _ _
      | .error _ => TProg.done ()).final H ((slotT2 H P s (pre.final H t).1).squeeze H).2 |>.1 = _
  rw [hdf]
  rfl

theorem sep_slotEProg (key : Option Dig) (m : ℕ) (pre : TProg (Block.Hist × Block.Acc)) (hp : TProg.Sep key pre) :
    TProg.Sep key (slotEProg P s D m pre) := by
  refine sep_bindP key _ _ (sep_slotCProg P s key pre hp) (fun ad dg => ?_)
  show TProg.Sep key (match P.define s ad.1.1 ad.2 with
    | .ok df => TProg.absorb labPbScalar _ _
    | .error _ => TProg.done ())
  split
  · exact sep_scUpToP key _ _ _
  · trivial

variable {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **Round `m`'s degenerate value as L18's `Site`** (`{0, 1}`, `k = 2`, `δ = 0`). -/
noncomputable def slotESite (m : ℕ) (pre : Coins → TProg (Block.Hist × Block.Acc)) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (slotEProg P s D m (pre c)) (t0 c)) :
    Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => slotEProg P s D m (pre c)) t0 (fun _ => ({0, 1} : Finset K)) 2
    (fun _ => Finset.card_le_two) (fun c => sep_slotEProg P s D _ m (pre c) (hs c)) hn

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The site of round `m` fires EXACTLY when the honest slot's challenge of round `m` is `0` or `1`** (L25's
`degenerate_guard_iff`), at the slot's entry the prefix leaves; so the degenerate-extension refusal (some challenge of
the rounds `n … n + e − 1` in `{0, 1}`) is covered by these `e` sites. -/
theorem slotESite_fires (m : ℕ) (hm : m < slotN P s) (pre : Coins → TProg (Block.Hist × Block.Acc)) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (slotEProg P s D m (pre c)) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (df : Block.SlotDef)
    (hdf : P.define s ((pre c).final (liftH G) (t0 c)).2.1
      ((((pre c).final (liftH G) (t0 c)).1).challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df) :
    (slotESite Lq hLq P s D m pre t0 hs hn (K := K)).fires U G c
      ↔ (((slotRho (liftH G) P D s ((pre c).final (liftH G) (t0 c)).2.1 ((pre c).final (liftH G) (t0 c)).2.2
            ((pre c).final (liftH G) (t0 c)).1 df).getD m Fp2.zero).isZero
          || decide (((slotRho (liftH G) P D s ((pre c).final (liftH G) (t0 c)).2.1 ((pre c).final (liftH G) (t0 c)).2.2
            ((pre c).final (liftH G) (t0 c)).1 df).getD m Fp2.zero) = Fp2.one)) = true := by
  unfold slotESite
  rw [tprogSite_fires, final_slotEProg (liftH G) P s D m (pre c) (t0 c) df hdf]
  simp only [slotRho, slotSP]
  rw [scUpTo_chal (liftH G) _ _ m _ hm, degenerate_guard_iff U hU _ (canon_challengeFp2Of _)]

end ExtSite

/-! ## Stage OUT-C's D66(3) refusal as a transcript-program site -/

section OutcAlpha

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} (H : HIn → Dig) (V : OutcV)

/-- The byte table's entries `z + γ·TAG_U8` (stage_out_c.rs:582). -/
def u8Entry (gamma : Fp2) (z : ℕ) : Fp2 := (kI z).add (gamma.mulBase (Fp.new (UInt64.ofNat tagU8)))

/-- **Stage OUT-C's head up to `α` as a program**: after a prefix `pre` ending at OUT-C's start, the frame
(`pb-run-stage`, `pb-run-block`), `A`'s root (its Merkle program) and `absorb_root("A")`, `M`'s root and
`absorb("M")`, then `γ`; the next squeeze is `α`. -/
def outcAlphaProg {rA rM : (HIn → Dig) → Dig} (pre : TProg α) (RA : RootProg rA) (RM : RootProg rM) : TProg (List Fp2) :=
  bindP pre (fun _ => .absorb labRunStage (le64 (UInt64.ofNat V.stageIndex)) (.absorb labRunBlock V.pub.wDigest.toList
    (absorbRootP RA labA V.bp.aRows V.bp.logCols (fun _ => bindP RM.p (fun m => .absorb labM m.toList
      (drawsP 1 (fun g => .done g)))))))

theorem final_outcAlphaProg {rA rM : (HIn → Dig) → Dig} (pre : TProg α) (RA : RootProg rA) (RM : RootProg rM) (t : Tr) :
    (outcAlphaProg V pre RA RM).final H t
      = ((((absorbRoot H (V.frame H (pre.final H t).1) labA (rA H) V.bp.aRows V.bp.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 1).2,
         (((absorbRoot H (V.frame H (pre.final H t).1) labA (rA H) V.bp.aRows V.bp.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 1).1) := by
  unfold outcAlphaProg
  rw [final_bindP]
  show (absorbRootP RA labA V.bp.aRows V.bp.logCols _).final H (V.frame H (pre.final H t).1) = _
  rw [final_absorbRootP]
  dsimp only
  rw [final_bindP, RM.final_eq]
  show (drawsP 1 (fun g => TProg.done g)).final H _ = _
  rw [final_drawsP]
  rfl

theorem sep_outcAlphaProg (key : Option Dig) {rA rM : (HIn → Dig) → Dig} (pre : TProg α) (RA : RootProg rA)
    (RM : RootProg rM) (hp : TProg.Sep key pre) : TProg.Sep key (outcAlphaProg V pre RA RM) :=
  sep_bindP key pre _ hp (fun _ => sep_bindP key RA.p _ (RA.sep key) (fun _ =>
    sep_bindP key RM.p _ (RM.sep key) (fun _ => sep_drawsP key 1 _ (fun _ => trivial))))

variable {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)

/-- The bad values: the byte table's 256 entries at `γ`. -/
noncomputable def u8Bad (ch : List Fp2) : Finset K := (Finset.range 256).image (fun z => (u8Entry (ch.getD 0 Fp2.zero) z).toK U)

theorem u8Bad_card (ch : List Fp2) : (u8Bad U ch).card ≤ 256 :=
  Finset.card_image_le.trans (by simp)

/-- **Stage OUT-C's D66(3) refusal as L18's `Site`**: at most 256 bad values, `δ = 0` PROVED. -/
noncomputable def outcAlphaSite {rA rM : (HIn → Dig) → Dig} (pre : Coins → TProg α) (RA : RootProg rA)
    (RM : RootProg rM) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (outcAlphaProg V (pre c) RA RM) (t0 c)) : Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => outcAlphaProg V (pre c) RA RM) t0 (u8Bad U) 256 (u8Bad_card U)
    (fun c => sep_outcAlphaProg V _ (pre c) RA RM (hs c)) hn

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- `outcAlphaBad` read in `K`: `α` is one of the byte table's entries at `γ`. -/
theorem outcAlphaBad_iff (gamma alpha : Fp2) (ha : alpha.Canon) (hg : gamma.Canon) :
    outcAlphaBad [gamma, alpha] = true ↔ alpha.toK U ∈ u8Bad U [gamma, alpha] := by
  unfold outcAlphaBad u8Bad
  rw [List.any_eq_true, Finset.mem_image]
  have hent : ∀ z, (u8Entry gamma z).Canon := fun z => Fp2.canon_add _ _
  constructor
  · rintro ⟨z, hz, h⟩
    refine ⟨z, Finset.mem_range.mpr (List.mem_range.mp hz), ?_⟩
    have h0 := (isZero_iff_toK U hU _ (Fp2.canon_sub _ _ ha (hent z))).mp h
    rw [Fp2.toK_sub U _ _ ha (hent z), sub_eq_zero] at h0
    exact h0.symm
  · rintro ⟨z, hz, h⟩
    refine ⟨z, List.mem_range.mpr (Finset.mem_range.mp hz), ?_⟩
    refine (isZero_iff_toK U hU _ (Fp2.canon_sub _ _ ha (hent z))).mpr ?_
    rw [Fp2.toK_sub U _ _ ha (hent z), sub_eq_zero]
    exact h.symm

/-- **The site fires EXACTLY when stage OUT-C's honest prover refuses at D66(3)** (`outcProve`'s guard on the head's
`γ, α`), when the prefix ends at OUT-C's start and the roots are the honest data's: stage OUT-C's `α` refusal is a
`δ = 0` site with `k = 256` once the run up to OUT-C is a transcript program. -/
theorem outcAlphaSite_fires {rA rM : (HIn → Dig) → Dig} (pre : Coins → TProg α) (RA : RootProg rA) (RM : RootProg rM)
    (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ c, TProg.NoWrap (outcAlphaProg V (pre c) RA RM) (t0 c)) (G : QB Lq → Dig) (c : Coins) (D : OutcData V)
    (hA : D.aRoot = rA (liftH G)) (hM : D.maskRoot = rM (liftH G)) :
    (outcAlphaSite Lq hLq V U pre RA RM t0 hs hn).fires U G c
      ↔ outcAlphaBad (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1 = true := by
  unfold outcAlphaSite
  rw [tprogSite_fires, final_outcAlphaProg]
  set T := ((absorbRoot (liftH G) (V.frame (liftH G) ((pre c).final (liftH G) (t0 c)).1) labA (rA (liftH G)) V.bp.aRows
    V.bp.logCols).absorb (liftH G) labM (rM (liftH G)).toList) with hT
  have hch : (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1
      = [((T.challengeFp2Vec (liftH G) 1).1.getD 0 Fp2.zero),
         challengeFp2Of (liftH G ⟨(T.challengeFp2Vec (liftH G) 1).2.key,
           squeezeMsg (T.challengeFp2Vec (liftH G) 1).2.state (T.challengeFp2Vec (liftH G) 1).2.counter⟩)] := by
    simp only [outcCh, hA, hM, ← hT]
    rfl
  rw [hch, outcAlphaBad_iff U hU _ _ (canon_challengeFp2Of _) (by
    show ((T.challengeFp2Vec (liftH G) 1).1.getD 0 Fp2.zero).Canon
    simp only [Tr.challengeFp2Vec, List.getD_cons_zero]
    exact canon_challengeFp2Of _)]
  try exact Iff.rfl

end OutcAlpha

end ZK60.HonestOracle
