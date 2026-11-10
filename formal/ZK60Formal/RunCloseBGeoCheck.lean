/-
D63 Lean lane L55 (2026-11-10): **the run's boundary openings' geometry (the closing openings of parts `1` on),
checked against the code.**

Run (through the zk60 resource guard; `results/zk60_lean_l55_20261110/check_l55.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/RunCloseBGeoCheck.lean <L29 corpus> <L49 Shieldstral export> <ops/zkp-mvp/gpu-metal>

It compares `RunCloseBGeo.lean`'s boundary rows (`cbBndRows`) and L48's block geometry `ogR13` (the boundary geometry
at R13 Shieldstral T128) with three independent sources:

* `R13`: lane L49's export of the app's R13 Shieldstral T128 block shape from the production code
  (`results/zk60_lean_l49_20261110/pub_shield_short.txt`, written by the test-only `lean_l49_export_tests.rs` from the
  production `Shape` of `R13_SHIELD_T128_H24`; L49 checked the block it carries against the production verifier): the
  profile, `log_cols`, `t_pad`, `d_pad`;
* `DEV`: lane L29's export of a REAL classifier run (`results/zk60_lean_l29_20261107/corpus.txt`, an honest run the
  production `verify_classify_run` accepted): stage OUT-C's `B_out` spec (`OUTGEO`: `log_n`, `commitment_rows`,
  `data_rows`, sites; `OUTDIM`: `Dim::of(&bspec.params())`; `OUTPCS`: its rate and checks) on the plane of `OUTDERIV`:
  the boundary formula on a real run, at the development rung's own geometry;
* `SOURCE`: the production sources' text: the R13 profile's registration and `trained_geometry` (no endpoint
  override, rate `4`), the endpoint defaults, `COL_CHECKS`, `boundary_spec`, `BoundarySpec`'s rows and params, and the
  verifier's boundary openings (`classify_run.rs`: `B_in` and `B_{k+1}` are `boundary_spec`, block `k` opens the
  previous one at its params with `ZkOpts::standard`; stage OUT-C opens the last at its params).

It prints the checks per kind and `RunCloseBGeoCheck: N checks, F failed`, and exits nonzero on any failure. The
negative control (`results/zk60_lean_l55_20261110/l55_negative.py`) runs it on single-change copies of the corpora and
the sources and requires every copy to be refused. Not imported by the library root (it defines `main`).
-/
import ZK60Formal.RunCloseBGeo

namespace ZK60.Exec.Link.CloseBCheck

open ZK60.Exec.Link

def nat (s : String) : ℕ := s.toNat?.getD 0

structure St where
  n : ℕ := 0
  failed : ℕ := 0
  kinds : List (String × ℕ × ℕ) := []
  log : List String := []

def St.check (s : St) (kind : String) (ok : Bool) (what : String) : St :=
  let upd := fun (l : List (String × ℕ × ℕ)) =>
    if l.any (·.1 == kind) then l.map (fun e => if e.1 == kind then (e.1, e.2.1 + 1, e.2.2 + if ok then 0 else 1) else e)
    else l ++ [(kind, 1, if ok then 0 else 1)]
  { s with
    n := s.n + 1
    failed := s.failed + (if ok then 0 else 1)
    kinds := upd s.kinds
    log := s.log ++ [s!"{if ok then "ok  " else "FAIL"} {kind}: {what}"] }

/-- The line of `src` containing `key`, or `""`. -/
def lineWith (src key : String) : String :=
  ((src.splitOn "\n").find? (fun l => (l.splitOn key).length > 1)).getD ""

/-- The number after `field:` on a line (the registry's compact struct-literal syntax), or `none`. -/
def fieldNat (line field : String) : Option ℕ :=
  match line.splitOn (field ++ ":") with
  | _ :: rest :: _ => (String.ofList (rest.toList.takeWhile Char.isDigit)).toNat?
  | _ => none

def has (src key : String) : Bool := (src.splitOn key).length > 1

/-- `Dim::of(params)` of a commitment at a geometry: `(checks, n + q_pad, n · inv_rate, log2 (n · inv_rate))`. -/
def dimOf (g : OGeo) : ℕ × ℕ × ℕ × ℕ := (g.Q, 2 ^ g.lc + g.Q, 2 ^ g.h, g.h)

def main (args : List String) : IO UInt32 := do
  let c29 := args.getD 0 "corpus.txt"
  let c49 := args.getD 1 "pub_shield_short.txt"
  let root := args.getD 2 "ops/zkp-mvp/gpu-metal"
  let rd (p : String) : IO (List (List String)) := do
    let lines ← IO.FS.lines p
    return (lines.toList.filter (fun l => !(l.all Char.isWhitespace))).map (fun l => (l.splitOn " ").filter (· ≠ ""))
  let w29 ← rd c29
  let w49 ← rd c49
  let rec1 (ws : List (List String)) (k : String) : List String := (ws.find? (fun w => w.headD "" = k)).getD []
  let a (k : String) (i : ℕ) : ℕ := nat ((rec1 w29 k).getD i "")
  let b (k : String) (i : ℕ) : ℕ := nat ((rec1 w49 k).getD i "")
  let g := ogR13
  let mut s : St := {}
  -- ================================================================ R13 (the app's shape, L49's export)
  s := s.check "R13" ((rec1 w49 "L49S").getD 1 "" == "R13_SHIELD_T128_H24")
    s!"the export is L49's R13 Shieldstral T128 shape ({(rec1 w49 "L49S").getD 1 "?"})"
  s := s.check "R13" (b "L49S" 3 == g.lc) s!"its log_cols {b "L49S" 3} (= endpoint_log_n, the boundaries' row width); Lean ogR13.lc {g.lc}"
  s := s.check "R13" (b "SHAPE" 1 == 128 && b "SHAPE" 7 == 128 && b "SHAPE" 8 == 4096)
    s!"its tokens {b "SHAPE" 1}, t_pad {b "SHAPE" 7}, d_pad {b "SHAPE" 8} (the boundary plane); Lean 128, 128, 4096"
  s := s.check "R13" (cbBndRows (b "SHAPE" 7) (b "SHAPE" 8) (b "L49S" 3) 2 == 38)
    s!"a boundary's rows at it: {b "SHAPE" 7}·{b "SHAPE" 8}/2^{b "L49S" 3} + 2·2 + 2 = {cbBndRows (b "SHAPE" 7) (b "SHAPE" 8) (b "L49S" 3) 2}; Lean cbBndRows_r13 38"
  -- ================================================================ DEV (B_out on L29's real classifier run)
  s := s.check "DEV" ((rec1 w29 "L29").length > 0) s!"the corpus is L29's export ({(rec1 w29 "L29").getD 2 "?"})"
  let bLog := a "OUTGEO" 1
  let plane := 2 ^ (a "OUTDERIV" 4)
  s := s.check "DEV" (a "OUTGEO" 3 == plane / 2 ^ bLog && a "OUTGEO" 4 == 2
      && a "OUTGEO" 2 == cbBndRows plane 1 bLog (a "OUTGEO" 4))
    s!"B_out: log_n {bLog}, data rows {a "OUTGEO" 3} = 2^{a "OUTDERIV" 4}/2^{bLog}, sites {a "OUTGEO" 4}, rows {a "OUTGEO" 2} = cbBndRows {cbBndRows plane 1 bLog (a "OUTGEO" 4)}"
  let gDev : OGeo := ⟨bLog + a "OUTPCS" 2, bLog, a "OUTPCS" 4, 0, (a "OUTPCS" 4 + 3) / 4, by omega⟩
  s := s.check "DEV" ((a "OUTDIM" 5, a "OUTDIM" 6, a "OUTDIM" 7, a "OUTDIM" 8) == dimOf gDev)
    s!"B_out's Dim (checks, n+q_pad, enc cols, path) = ({a "OUTDIM" 5}, {a "OUTDIM" 6}, {a "OUTDIM" 7}, {a "OUTDIM" 8}): the geometry (log_n + log2 rate, log_n, checks) {dimOf gDev}"
  s := s.check "DEV" (a "OUTPCS" 4 == g.Q && a "OUTPCS" 2 == g.h - g.lc)
    s!"B_out's checks {a "OUTPCS" 4}, log inverse rate {a "OUTPCS" 2}: the R13 boundary's {g.Q}, {g.h - g.lc}"
  -- ================================================================ SOURCE (the production code's text)
  let shp ← IO.FS.readFile (root ++ "/hashline/src/private_block/shape.rs")
  let bnd ← IO.FS.readFile (root ++ "/hashline/src/private_block/boundary.rs")
  let cls ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/classify.rs")
  let crun ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/classify_run.rs")
  let soc ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/stage_out_c.rs")
  let epg ← IO.FS.readFile (root ++ "/hashline/src/private_block/endpoint_g.rs")
  let r13 := lineWith shp "AccuracyProfile{profile:R13_SHIELD_T128_H24,"
  s := s.check "SOURCE" (fieldNat r13 "log_cols" == some g.lc && fieldNat r13 "tokens" == some 128
      && fieldNat r13 "width" == some 3072)
    s!"shape.rs: R13_SHIELD_T128_H24 registered at tokens {fieldNat r13 "tokens"}, width {fieldNat r13 "width"}, log_cols {fieldNat r13 "log_cols"}"
  let w16r2 := ((shp.splitOn "pub(crate) const W16R2_PROFILES:").getD 1 "").splitOn "];" |>.headD ""
  s := s.check "SOURCE" (has shp "pub(crate) const R13_SHIELD_T128_H24: &str = \"hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2\";"
      && has shp "pub(crate) fn is_w16r2_profile(profile: &str) -> bool {\n    W16R2_PROFILES.iter().any(|s| s.profile == profile)"
      && w16r2 != "" && !(has w16r2 "profile:R13_SHIELD_T128_H24,"))
    "shape.rs: the R13 profile is not among W16R2_PROFILES (is_w16r2_profile is membership there)"
  s := s.check "SOURCE" (has shp "let inv_rate=if is_w16r2_profile(s.profile) {W16R2_INV_RATE} else {4};"
      && has shp "s.kv_heads,s.log_cols,inv_rate,f_e,rows,None,None,None,None));")
    "shape.rs: trained_geometry builds an R13 accuracy shape at rate 1/4 with NO endpoint override"
  s := s.check "SOURCE" (has shp "(endpoint_log_n.unwrap_or(log_cols), endpoint_inv_rate.unwrap_or(inv_rate))"
      && has shp "endpoint_log_n: e_log_n," && has shp "endpoint_inv_rate: e_rate,")
    "shape.rs: endpoint_log_n defaults to log_cols, endpoint_inv_rate to inv_rate"
  s := s.check "SOURCE" (has shp "const COL_CHECKS: usize = 256;" && has shp "        } else {\n            COL_CHECKS\n        };")
    s!"shape.rs: opened_cols = COL_CHECKS = 256 outside W16R2; Lean ogR13.Q {g.Q}"
  s := s.check "SOURCE" (has cls "BoundarySpec::new_with_tag(self.context, sh.t_pad, sh.d_pad, self.scale, (j + 1) as u64, 2, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1, &sh.hash_tag())")
    "classify.rs: boundary_spec(j) is the t_pad × d_pad plane, TWO sites, the shape's endpoint_log_n, endpoint_inv_rate, opened_cols"
  s := s.check "SOURCE" (has bnd "pub(crate) fn new_with_tag(context: Digest, rows: usize, cols: usize, scale: i32, index: u64, sites: usize, log_n: usize, inv_rate: usize, checks: usize, declared_rows: usize, tag: &HashTag)"
      && has bnd "        if declared_rows != derived {")
    "boundary.rs: new_with_tag's argument order; a declared row count other than the derived one is refused"
  s := s.check "SOURCE" (has bnd "        self.rows * self.cols" && has bnd "        self.len() >> self.log_n"
      && has bnd "        self.data_rows() + 2 * self.sites + 2")
    "boundary.rs: len = rows·cols, data_rows = len >> log_n, commitment_rows = data_rows + 2·sites + 2 (cbBndRows)"
  s := s.check "SOURCE" (has bnd "PcsParams { log_cols: self.log_n, inv_rate: self.inv_rate, num_col_checks: self.checks }")
    "boundary.rs: a boundary's PCS parameters are its log_n, inv_rate, checks"
  s := s.check "SOURCE" (has crun "    let b0 = st.boundary_spec(0)?;" && has crun "    let mut prev: (BoundarySpec, Digest) = (b0, b_root);"
      && has crun "        let spec = st.boundary_spec(k + 1)?;" && has crun "        prev = (spec, root);")
    "classify_run.rs: B_in is boundary_spec(0), B_(k+1) is boundary_spec(k + 1), carried as prev"
  s := s.check "SOURCE" (has crun "        let (pspec, proot) = prev;" && has crun "        let bp = pspec.params();"
      && has crun "pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open, &ntt, &mut tr, &tag)")
    "classify_run.rs: block k opens the PREVIOUS boundary (its root, rows, log_n) at its params, pads = checks"
  s := s.check "SOURCE" (has crun "    let (bspec, broot) = prev;"
      && has crun "super::stage_out_c::verify(&out_lay, cp, tables, st.verdict(), &seg, &bspec, &broot, pending, (l + 1) as u64, &ntt, &mut tr, &tag)?;")
    "classify_run.rs: stage OUT-C is handed the LAST boundary's spec and root (B_out = B_L)"
  s := s.check "SOURCE" (has soc "    let bp = b_spec.params();"
      && has soc "pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(*b_root, b_spec.commitment_rows(), b_spec.log_n()), &claims, &seg.closes[0], ntt, tr, tag)")
    "stage_out_c.rs: B_out is opened at its spec's params, rows and log_n, pads = checks"
  s := s.check "SOURCE" (has epg "pub(crate) const MASK_ROWS: usize = 5;"
      && has shp "let rows=(s.tokens.next_power_of_two()*s.width.next_power_of_two()).div_ceil(1usize<<s.log_cols).max(1)+super::endpoint_g::MASK_ROWS;")
    s!"shape.rs: the R13 shape's endpoint_rows = 128·4096/2^14 + MASK_ROWS 5 = {128 * 4096 / 2 ^ 14 + 5}, and boundary_spec declares endpoint_rows + 1 = {128 * 4096 / 2 ^ 14 + 5 + 1}"
  -- ================================================================ LEAN
  s := s.check "LEAN" (cbBndRows 128 4096 14 2 == 38 && 128 * 4096 / 2 ^ 14 + 5 + 1 == cbBndRows 128 4096 14 2)
    "cbBndRows at R13 is 38, the shape's declared endpoint_rows + 1 (so the code's own refusal at boundary.rs:149 passes)"
  s := s.check "LEAN" (g.lc == 14 && 2 ^ g.h == 2 ^ 14 * 4 && g.Q == 256 && g.mI == (256 + 3) / 4
      && 2 * g.e + (2 ^ g.lc + g.Q) == 2 ^ g.h)
    s!"ogR13 = the boundary geometry ({g.h}, {g.lc}, {g.Q}, {g.e}, {g.mI}): 2^14 columns, rate 1/4, 256 checks, largest radius"
  for l in s.log do
    IO.println l
  for (k, n, f) in s.kinds do
    IO.println s!"{k}: {n} checks, {f} failed"
  IO.println s!"RunCloseBGeoCheck: {s.n} checks, {s.failed} failed"
  return (if s.failed = 0 then 0 else 1)

end ZK60.Exec.Link.CloseBCheck

def main (args : List String) : IO UInt32 := ZK60.Exec.Link.CloseBCheck.main args
