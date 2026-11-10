/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 2: **R13's slots `SC_SZC` (17), `SC_RS` (4) and `SC_SCORE` (8) as
explicit raw slots, generic in the configuration**, and the configuration facts `SzcCfg` the host's identity reads.

R13's `SC_SZC` batches five named clauses (`s0 … s4`, the quotient's decomposition `p − Σ PL` last), LogUp's helpers
over `DefR13.lksS c shaped .S` (`13 + 2·ls` byte lookups, `7 + ls` helpers) and the exp tuple's relation; `Dom::S` has
`11 + 2·ls` planes (ids `75 …`: `S8`, `RSL`, `ZSEL`, `E`, `P`, `PL`, `SR`, `SG`, the softmax remainders' byte limbs
`ls + 1` each); `Dom::S` and `Dom::Ht` do not pad (no pad term, no gate). The rung has `ls = 2`, every Shieldstral
layer `ls = 1`.

* `drsR`, `tS`, `tHt`, `tHS`: draws as expressions, an `A` plane on `Dom::S` / `Dom::Ht`, an `H` plane on `Dom::S`;
* `tabs17R`, `RSzR`, `irSzcR`, **`rawSzcR`**: `SC_SZC`'s tables, table positions, IR and slot;
* **`rawRsR`**, **`rawScR`**: `SC_RS`'s and `SC_SCORE`'s slots;
* **`SzcCfg c ls`**: the configuration facts (the three raw slots ARE these, `Dom::S`'s helper count and lookup
  count, `SC_SZC` does not pad, `per_row = 2^lt`), proved at the rung and at every Shieldstral layer in
  `BlockR13HostSzcCfg.lean`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostSzcIr

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Slot.Build
open ZK60.Exec.Block
open ZK60.Exec.Block.DefW16 (W16Cfg cstS rhoC aTab)
open ZK60.Exec.Block.DefR13 (SzcR13 r13SzcIr)

/-- The draws `a … a + n − 1` of slot `s`, as expressions. -/
def drsR (s a n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (a + i)

/-- An `A` plane on `Dom::S` (plane id `q`). -/
def tS (c : W16Cfg) (q : ℕ) : TabS := aTab (DefR13.aOff c q) (c.sh.logs .S) (rhoC 0 (c.sh.logs .S)) 0

/-- An `A` plane on `Dom::Ht` (plane id `q`), read on the first `Dom::Ht` variables of the slot's cube. -/
def tHt (c : W16Cfg) (q : ℕ) : TabS := aTab (DefR13.aOff c q) (c.sh.logs .Ht) (rhoC 0 (c.sh.logs .Ht)) 0

/-- An `H` plane on `Dom::S` (helper plane `hp`, `re + u·im`). -/
def tHS (c : W16Cfg) (hp : ℕ) : TabS :=
  .priv ⟨.h, [((DefR13.hOff c hp).1, false), ((DefR13.hOff c hp).2, true)], c.sh.logs .S, rhoC 0 (c.sh.logs .S), 0, 0⟩

/-- `SC_SZC`'s private tables: the `11 + 2·ls` `Dom::S` planes, `MX`, `SUM`, the `7 + ls` LogUp helpers, the exp
helper. -/
def tabs17Tail (c : W16Cfg) (ls : ℕ) : List TabS :=
  (List.range (11 + 2 * ls)).map (fun i => tS c (75 + i)) ++ [tHt c 4, tHt c 5]
    ++ (List.range (7 + ls)).map (fun j => tHS c (DefR13.fh c 4 + j)) ++ [tHS c (DefR13.fh c 5)]

/-- **`SC_SZC`'s tables**: `eq(τ)`, `eq(p_ht)`, `eq(P_score)`, the mask, then the private tables. -/
def tabs17R (c : W16Cfg) (ls : ℕ) : List TabS :=
  [TabS.eq (drsR 17 0 (c.sh.logs .S)) 0, TabS.eq (drsR 4 0 (c.sh.logs .Ht)) 0, TabS.eq (drsR 8 0 (c.sh.logs .S)) 0,
    TabS.pub 0] ++ tabs17Tail c ls

/-- **`SC_SZC`'s table positions**: the mask `3`; `S8` `4`, `RSL` `5 6 7`, `ZSEL` `8`, `E` `9`, `P` `10`, `PL` `11 12`,
`SR` from `13`, `SG` from `14 + ls`; `MX`, `SUM` after the `Dom::S` planes; the helpers from `17 + 2·ls`; the exp helper
`24 + 3·ls`; no gate. -/
def RSzR (ls : ℕ) : SzcR13 :=
  ⟨3, 4, 8, 9, 10, 15 + 2 * ls, 16 + 2 * ls, 17 + 2 * ls, 24 + 3 * ls, List.range' 13 (ls + 1),
    List.range' (14 + ls) (ls + 1), [11, 12], [5, 6, 7], none, none⟩

/-- The plane-to-table map of `SC_SZC` (`Dom::S`'s planes start at id `75`). -/
def shapedR (q : ℕ) : ℕ := 4 + (q - 75)

/-- **`SC_SZC`'s IR**: `μ` draws `lS … lS + 12 + ls`, `ν` the next two, `λ` `SC_RS`'s last draw, no pad group. -/
def irSzcR (c : W16Cfg) (ls : ℕ) : Ir Sym :=
  r13SzcIr cstS (RSzR ls) c.p.fp c.p.score (DefR13.lksS c shapedR .S) (drsR 17 (c.sh.logs .S) (13 + ls))
    (drsR 17 (c.sh.logs .S + (13 + ls)) 2) (.sub .alpha (.gtag 129)) (.neg .beta) (.dr 4 (c.sh.logs .Ht))
    (fun j => .pow .zero j) []

/-- **`SC_SZC`'s raw slot**: hosting `SC_RS` at `ν₀·per_row` and `SC_SCORE` at `ν₁`. -/
def rawSzcR (c : W16Cfg) (ls : ℕ) : SlotS :=
  ⟨tabs17R c ls, irSzcR c ls,
    [(4, .mul (.dr 17 (c.sh.logs .S + (13 + ls))) (.base c.sh.perRow)), (8, .dr 17 (c.sh.logs .S + (13 + ls) + 1))],
    drsR 17 (c.sh.logs .S + (13 + ls)) 2⟩

/-- **`SC_RS`'s raw slot**: `eq(p_ht)` on the first `Dom::Ht` variables, the mask, `E`, `ZSEL`. -/
def rawRsR (c : W16Cfg) : SlotS :=
  ⟨[TabS.eq (drsR 4 0 (c.sh.logs .Ht)) 0, TabS.pub 0, tS c 80, tS c 79],
    rsIr cstS 0 1 2 3 none (.dr 4 (c.sh.logs .Ht)), [], []⟩

/-- `SC_SCORE`'s `QR` table: `QR` (id `52`) read at `(r_t, ·, r_hj, ·)`. -/
def tQR (c : W16Cfg) : TabS :=
  aTab (DefR13.aOff c 52) (c.sh.logs .Q)
    ((drsR 8 c.sh.lh c.sh.lt).map CoordS.fixed ++ rhoC 0 c.sh.lkv
      ++ (drsR 8 c.sh.lkv (c.sh.lh - c.sh.lkv)).map CoordS.fixed ++ rhoC c.sh.lkv (c.sh.lkv + c.sh.ldh)) 0

/-- `SC_SCORE`'s `KR` table: `KR` (id `71`) read at `(r_3, ·, ·)`, extension round `1`. -/
def tKR (c : W16Cfg) : TabS :=
  aTab (DefR13.aOff c 71) (c.sh.logs .Kv)
    ((drsR 8 (c.sh.lh + c.sh.lt) c.sh.lt).map CoordS.fixed ++ rhoC 0 c.sh.lkv ++ rhoC c.sh.lkv (c.sh.lkv + c.sh.ldh)) 1

/-- **`SC_SCORE`'s raw slot**: `eq(r_g)` on the group variables, `QR`, `KR`. -/
def rawScR (c : W16Cfg) : SlotS :=
  ⟨[TabS.eq (drsR 8 0 c.sh.lkv) 0, tQR c, tKR c], bilIr cstS (some 0) 1 2, [], []⟩

/-- **The configuration facts `SC_SZC`'s identity reads** (each decided at the R13 rung and at every Shieldstral layer,
`BlockR13HostSzcCfg.lean`): the program's raw slots `17`, `4`, `8` are `rawSzcR`, `rawRsR`, `rawScR`; `Dom::S`'s
recorded helper count is `7 + ls` and its lookup list has `13 + 2·ls` entries; `SC_SZC` does not pad; `per_row` is
`2^lt`, a word. -/
structure SzcCfg (c : W16Cfg) (ls : ℕ) : Prop where
  raw17 : DefR13.rawSlot c 17 = rawSzcR c ls
  raw4 : DefR13.rawSlot c 4 = rawRsR c
  raw8 : DefR13.rawSlot c 8 = rawScR c
  help : c.sh.helpers .S = 7 + ls
  lk : (DefR13.lookups c .S).length = 13 + 2 * ls
  pad : ZK60.Exec.Slot.W16R2.padOn c.sh 17 = false
  perRow : c.sh.perRow = 2 ^ c.sh.lt
  perRowLt : c.sh.perRow < 2 ^ 63

end ZK60.Exec.Block.Join.R13H.Szc
