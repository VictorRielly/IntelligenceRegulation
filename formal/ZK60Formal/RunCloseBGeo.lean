/-
D63 lane L55 (2026-11-10), part 3: **the closing openings of parts `1` on: the run's boundary commitments' geometry**
(the brief's deliverable 2; L50 §5 item 4).

At part `i ≥ 1` the closing opening is a BOUNDARY opening: block `k = i − 1` opens boundary `B_k` (the previous part's
`B` commitment: `B_in` for `k = 0`) through the run's `bndOpen` (`pcs::verify_zk_tagged` at `pspec.params()`,
classify_run.rs:436-441), and stage OUT-C opens `B_out = B_L` (`b_spec.params()`, stage_out_c.rs:722-725; `b_spec` is the
last block's `boundary_spec(L)`, classify_run.rs:483-486). Every boundary is `ClassifyRunStatement::boundary_spec(j)`
(classify.rs:1139-1146): the plane `t_pad × d_pad`, TWO claim sites, the shape's `endpoint_log_n`, `endpoint_inv_rate`,
`opened_cols`, and `commitment_rows() = data_rows + 2·sites + 2` (boundary.rs:181-188, refused otherwise at :149).
At the app's profile R13 Shieldstral T128 (`R13_SHIELD_T128_H24`, built by `trained_geometry` with no endpoint
override, so `endpoint_log_n = log_cols = 14`, `endpoint_inv_rate = inv_rate = 4`, `opened_cols = COL_CHECKS = 256`):

* **`cbBndRows`**, **`cbBndRows_r13`**: the boundary's rows, `128·4096 / 2^14 + 2·2 + 2 = 38`;
* **`cb_bnd_geo`**: its code geometry is L48's block geometry `ogR13` (`2^16` symbols, `2^14` columns, `256` queries
  and pads, the largest radius `24448`, `64` index squeezes), which meets `OGeo.Ok` (`ogR13_ok`).

`RunCloseBGeoCheck.lean` (an executable, not imported) checks these against the code: the R13 Shieldstral T128 shape
L49 exported from the production code, B_out's spec on L29's real classifier run, and the production sources' text,
with a negative control (`results/zk60_lean_l55_20261110/l55_negative.py`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoTier

set_option autoImplicit false

namespace ZK60.Exec.Link

/-- **A boundary commitment's rows** (`BoundarySpec::commitment_rows`): the plane of `tPad·dPad` words cut into rows of
`2^lc`, one reserved pair per claim site, then the proximity pair. -/
def cbBndRows (tPad dPad lc sites : ℕ) : ℕ := tPad * dPad / 2 ^ lc + 2 * sites + 2

/-- **At R13 Shieldstral T128 a boundary has `38` rows** (`t_pad = 128`, `d_pad = 4096`, `endpoint_log_n = 14`, two
sites: `32` data rows). -/
theorem cbBndRows_r13 : cbBndRows 128 4096 14 2 = 38 := by
  unfold cbBndRows
  norm_num

/-- **The boundary geometry at R13 Shieldstral T128 is the block geometry `ogR13`**: `2^14` message columns
(`endpoint_log_n`), `2^16 = 2^14·4` symbols (`endpoint_inv_rate 4`), `256` queries and pads (`opened_cols`), the code's
`(Q + 3)/4` index squeezes, the largest radius (`2·24448 + 2^14 + 256 = 2^16`), and `OGeo.Ok`. -/
theorem cb_bnd_geo : ogR13.lc = 14 ∧ 2 ^ ogR13.h = 2 ^ 14 * 4 ∧ ogR13.Q = 256 ∧ ogR13.mI = (256 + 3) / 4
    ∧ 2 * ogR13.e + (2 ^ ogR13.lc + ogR13.Q) = 2 ^ ogR13.h ∧ ogR13.Ok := by
  refine ⟨rfl, ?_, rfl, ?_, ?_, ogR13_ok⟩
  · show 2 ^ 16 = 2 ^ 14 * 4
    norm_num
  · show 64 = (256 + 3) / 4
    norm_num
  · show 2 * 24448 + (2 ^ 14 + 256) = 2 ^ 16
    norm_num

end ZK60.Exec.Link
