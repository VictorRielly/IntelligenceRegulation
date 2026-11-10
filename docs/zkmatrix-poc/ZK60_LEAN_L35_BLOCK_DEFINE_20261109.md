# D63 lane L35: the block's `define` and the tables part of the slot polynomials (2026-11-09)

Lean lane L35 (Claude), on its own worktree (perf `b938ae87`, then perf merged in at `921633fb`: L32, L33, A28, L34).
Lean 4.34.1, Mathlib v4.34.1, no new dependency. New library files under `formal/ZK60Formal/`, all `BlockDefine*.lean`.
No Rust. `Statements.lean` and every existing Lean file are unchanged. Evidence: `results/zk60_lean_l35_20261109/`.

**STATUS: IN PROGRESS (this section is rewritten when the lane closes).** The interface for lane L36 (section 6) is
written first, as the coordinator asked.

## 6. The interface for lane L36 (the per-outcome algebra)

Everything below is in namespace `ZK60.Exec.Block`. `K` is the extension field (`[Field K] [Algebra GF K]`), `U` the
square root of 7 in it (`hU : U ^ 2 = algebraMap GF K 7`).

**The block's `define` as data.**
- `Sym`: an expression for a coefficient or challenge word (`one`, `negOne`, `zero`, `base v`, `p16 k`, `p256 k`,
  `u64 n`, `alpha`, `beta`, `gtag t`, `dr slot i` (draw `i` of slot `slot`), `add`, `sub`, `mul`, `neg`, `pow`).
  `Sym.eval (hist : Hist) (k : ℕ) (dr : List Fp2) : Sym → Fp2` is its word at slot `k`.
- `CoordS` (`rho k`, `flip k`, `fixed v`), `PrivS` (`cm`, `slices : List (ℕ × Bool)`, `log`, `coords`, `maskRow`,
  `extRound`), `TabS` (`eq point start`, `pub i`, `priv p`), `SlotS` (`tabs : List TabS`, `ir : Ir Sym`,
  `hosted : List (ℕ × Sym)`, `nonzero : List Sym`).
- `PubTabs := ℕ → Hist → List Fp2 → ℕ → List Fp2`: public table `i` of slot `k` (a function of the block's public
  statement; opaque here).
- `defineS (prog : List SlotS) (pubs : PubTabs) : ℕ → Hist → List Fp2 → Except String SlotDef`: `define` run on a
  program. `defineS_ok` unfolds an accepted definition.
- `progOKb (rl : Cm → ℕ) (prog : List SlotS) (slots : List (ℕ × ℕ × ℕ)) : Bool`: the program's check (one program
  per slot; each private table has a slice, a point of its slice's length, a positive row log, and coordinates that
  read each challenge at most once; each IR's degree in its tables `irDeg` is at most the slot's degree).
- `cmCountS (cm : Cm) (ts : List TabS) : ℕ`: the private tables of a slot in commitment `cm`.
- W16R2: `DefW16.progW16 (c : DefW16.W16Cfg) (ioIn ioOut : ℕ) : List SlotS` (namespace `ZK60.Exec.Block.DefW16`), and
  `DefW16.rawSlot c s` for slot `s` before the reserved rows are numbered. Slot `s`'s IR is L13's builder for that slot
  (`ssIr`, `tzcIr`, `lzcIr`, `rsIr`, `mmIr`, `bilIr`, `dzcIr`, `qzcIr`, `szcIr`, `fzcIr`, `tabIr`, `zsIr`, `ioIr`) at
  the constants `DefW16.cstS` and the table positions written in `rawSlot`.

**The tables' extensions and the tables part.**
- `CmData K P` (`rows : Cm → ℕ`, `Q : Cm → ℕ`, `X : (cm : Cm) → Fin (rows cm) → Fin (2 ^ rowLog P cm + Q cm) → K`):
  the committed matrices the claims are read on.
- `tabK U P D n e x : Tab → K`: a table's extension at the point `x : Fin N → K` (`n` main variables, then `e`
  extension variables): `sel·eq(point, x[start..])`, `sel·T̃(x[..n])`, or for a private table L10's claim functional
  on `D.X cm` of `build_claim`'s parts (`claimK` of `privSpecs`), that is `sel·plane~(point) + cm·(R_re + u·R_im)(tail)`.
  `sel = selK n e x = Π_j (1 − e_j)`; the mask coefficient is `cmK n e x r`.
- `polyS U P D prog pubs : (k : ℕ) → Seen → (Fin (n_k + e_k) → K) → K`: the tables part of slot `k`'s polynomial,
  `irEval (ir_k read in K) (tables_k at x)`, `define`'s inputs read off what the trace shows (`histSeen`, `drSeen`).
- `dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt : CmData K P`: the matrices of a block's run (`A` and `H` as L31's
  `csXof` reads them, the endpoints' `XE`); `polyXof … prog pubs := fun cu rt => polyS U P (dXof … cu rt) prog pubs`.

**What is proved about them** (theorems L36 can cite):
- `tabVals_toK`: on an accepting slot (canonical challenges) whose claims are true of `D`, the terminal values the
  verifier computes ARE the tables' extensions at the slot's point.
- `polyS_slotEvalN` (`hPoly`), `polyS_indDeg` (`hdegP`), `defineS_polyC` (`hpolyC`), `defineS_defCm` (`hdc`).
- `tabK_indDeg`, `affAt_tabK`: every table's extension is affine in each variable.
- `irEval_indDeg`, `irDeg_map`: the slot polynomial's individual degree is at most the IR's degree in its tables.
- `claimSem_parts`: L10's `claimSem` of a claim IS `claimK` of its parts read in the field.

**What L36 will need that is not here yet**: the value of `tabK` at a point of the Boolean cube with `e = 0`
(a private table's extension at a cube point is the plane's entry at that row and column, plus nothing from the mask
pair since `cm = 0` there), so that `polyS` on the cube is the relation's residual; this is the bridge from `polyS` to
L23's certified slot polynomials `spR`, `spH`.
