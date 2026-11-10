/-
D63 Lean lane L48 (2026-11-10): **the classify run's opening geometries, checked against the code.**

Run (through the zk60 resource guard; `results/zk60_lean_l48_20261110/check_l48.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/RunOpenGeoCheck.lean <corpus.txt> <ops/zkp-mvp/gpu-metal>

It compares `RunOpenGeoTier.lean`'s Lean definitions (`tierR1`, `ogStage`, `ogEp`) and `RunOpenGeo.lean`'s block
geometry (`ogR13`) with two independent sources:

* `CORPUS`: lane L29's export of a REAL classifier run (`results/zk60_lean_l29_20261107/corpus.txt`, written by the
  test-only hashline test `lean_l29_export_the_classify_stages` from an honest run the production
  `verify_classify_run` accepted, and checked by L29's `StageVerifyExecCheck` against the production verifier): the
  profile's tier (`cp.tier.stage_log_n`, `cp.tier.ep_log_n`), stage IN-C's and stage OUT-C's commitment parameters
  (`Dim::of(params)`: checks, vector length `n + q_pad`, encoded columns, path depth; `inv_rate.trailing_zeros()`;
  `num_col_checks`) and the classifier's input endpoint spec's (`Dim::of(&st.in_spec.params())`, its rate, its checks,
  its data and commitment rows);
* `SOURCE`: the production sources' text: `Tier::R1_MVP`'s levers and `REGISTERED` (`token_io.rs`), the stages' row
  width (`stage_in_c.rs`, `classify.rs`), `input_endpoint_spec` (`classify.rs`), the tier door (`tier.check()?`), the
  pad count (`ZkOpts::standard`, `zkp-core/src/pcs.rs`), the endpoint's parameters and mask rows (`endpoint_g.rs`), and
  the R13 Shieldstral T128 profile's `log_cols 14` with `endpoint_log_n` defaulting to `log_cols` (`shape.rs`).

It prints the checks per kind and `RunOpenGeoCheck: N checks, F failed`, and exits nonzero on any failure. The negative
control (`results/zk60_lean_l48_20261110/l48_negative.py`) runs it on single-change copies of the corpus and the
sources and requires every copy to be refused. Not imported by the library root (it defines `main`).
-/
import ZK60Formal.RunOpenGeoTier

namespace ZK60.Exec.Link.GeoCheck

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

/-- The number after `field: ` on a line (the code's struct-literal syntax), or `none`. -/
def fieldNat (line field : String) : Option ℕ :=
  match line.splitOn (field ++ ": ") with
  | _ :: rest :: _ => (String.ofList (rest.toList.takeWhile Char.isDigit)).toNat?
  | _ => none

def has (src key : String) : Bool := (src.splitOn key).length > 1

/-- `Dim::of(params)` of a commitment at a geometry: `(checks, n + q_pad, n · inv_rate, log2 (n · inv_rate))`. -/
def dimOf (g : OGeo) : ℕ × ℕ × ℕ × ℕ := (g.Q, 2 ^ g.lc + g.Q, 2 ^ g.h, g.h)

def main (args : List String) : IO UInt32 := do
  let cpath := args.getD 0 "corpus.txt"
  let root := args.getD 1 "ops/zkp-mvp/gpu-metal"
  let lines ← IO.FS.lines cpath
  let words : List (List String) := (lines.toList.filter (fun l => !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))
  let rec1 (k : String) : List String := (words.find? (fun w => w.headD "" = k)).getD []
  let w (k : String) (i : ℕ) : ℕ := nat ((rec1 k).getD i "")
  let t := tierR1
  let gS := ogStage
  let gE := ogEp
  let mut s : St := {}
  -- ================================================================ CORPUS (a real classifier run)
  s := s.check "CORPUS" ((rec1 "L29").length > 0) s!"the corpus is L29's export ({(rec1 "L29").getD 2 "?"})"
  s := s.check "CORPUS" (w "INP" 7 == t.stageLogN && w "OUTP" 4 == t.stageLogN)
    s!"the run's tier: stage_log_n {w "INP" 7} (IN-C), {w "OUTP" 4} (OUT-C); Lean tierR1 {t.stageLogN}"
  s := s.check "CORPUS" (w "INP" 8 == t.epLogN) s!"the run's tier: ep_log_n {w "INP" 8}; Lean tierR1 {t.epLogN}"
  -- stage IN-C's A / H commitment parameters (in_lay.params = tier.stage_params())
  s := s.check "STAGE" ((w "INDIM" 1, w "INDIM" 2, w "INDIM" 3, w "INDIM" 4) == dimOf gS)
    s!"IN-C's A/H Dim (checks, n+q_pad, enc cols, path) = ({w "INDIM" 1}, {w "INDIM" 2}, {w "INDIM" 3}, {w "INDIM" 4}); Lean ogStage {dimOf gS}"
  s := s.check "STAGE" (w "INPCS" 1 == gS.h - gS.lc && w "INPCS" 3 == gS.Q)
    s!"IN-C's A/H log inverse rate {w "INPCS" 1}, column checks {w "INPCS" 3}; Lean ogStage {gS.h - gS.lc}, {gS.Q}"
  s := s.check "STAGE" ((w "OUTDIM" 1, w "OUTDIM" 2, w "OUTDIM" 3, w "OUTDIM" 4) == dimOf gS)
    s!"OUT-C's A/H Dim = ({w "OUTDIM" 1}, {w "OUTDIM" 2}, {w "OUTDIM" 3}, {w "OUTDIM" 4}); Lean ogStage {dimOf gS}"
  s := s.check "STAGE" (w "OUTPCS" 1 == gS.h - gS.lc && w "OUTPCS" 3 == gS.Q)
    s!"OUT-C's A/H log inverse rate {w "OUTPCS" 1}, column checks {w "OUTPCS" 3}"
  -- the classifier's input token endpoint (st.in_spec, input_endpoint_spec)
  s := s.check "ENDPOINT" ((w "INDIM" 5, w "INDIM" 6, w "INDIM" 7, w "INDIM" 8) == dimOf gE)
    s!"the input endpoint's Dim = ({w "INDIM" 5}, {w "INDIM" 6}, {w "INDIM" 7}, {w "INDIM" 8}); Lean ogEp {dimOf gE}"
  s := s.check "ENDPOINT" (w "INPCS" 2 == gE.h - gE.lc && w "INPCS" 4 == gE.Q)
    s!"the input endpoint's log inverse rate {w "INPCS" 2}, column checks {w "INPCS" 4}; Lean ogEp {gE.h - gE.lc}, {gE.Q}"
  s := s.check "ENDPOINT" (w "INGEO" 4 * 2 ^ gE.lc == w "INDERIV" 3 && w "INGEO" 5 == w "INGEO" 4 + 5)
    s!"the input endpoint's rows: {w "INGEO" 4} data rows of 2^{gE.lc} words = {w "INDERIV" 3} words, {w "INGEO" 5} committed (data + MASK_ROWS 5)"
  -- the Lean geometries are the tier's
  s := s.check "LEAN" (gS.lc == t.stageLogN && 2 ^ gS.h == 2 ^ t.stageLogN * t.stageInvRate && gS.Q == t.openedCols
    && gS.mI == (t.openedCols + 3) / 4) "ogStage is tierR1's stage geometry"
  s := s.check "LEAN" (gE.lc == t.epLogN && 2 ^ gE.h == 2 ^ t.epLogN * t.epInvRate && gE.Q == t.openedCols
    && gE.mI == (t.openedCols + 3) / 4) "ogEp is tierR1's endpoint geometry"
  s := s.check "LEAN" (2 * gS.e + (2 ^ gS.lc + gS.Q) == 2 ^ gS.h && 2 * gE.e + (2 ^ gE.lc + gE.Q) == 2 ^ gE.h)
    s!"the radii are the largest: 2·{gS.e} + 2^{gS.lc} + {gS.Q} = 2^{gS.h}, 2·{gE.e} + 2^{gE.lc} + {gE.Q} = 2^{gE.h}"
  -- ================================================================ SOURCE (the production code's text)
  let tio ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io.rs")
  let cls ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/classify.rs")
  let sic ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/stage_in_c.rs")
  let pcs ← IO.FS.readFile (root ++ "/zkp-core/src/pcs.rs")
  let epg ← IO.FS.readFile (root ++ "/hashline/src/private_block/endpoint_g.rs")
  let shp ← IO.FS.readFile (root ++ "/hashline/src/private_block/shape.rs")
  let r1 := lineWith tio "pub(crate) const R1_MVP: Tier = Tier {"
  s := s.check "SOURCE" (r1 != "") "token_io.rs: Tier::R1_MVP is defined"
  s := s.check "SOURCE" (fieldNat r1 "opened_cols" == some t.openedCols)
    s!"R1_MVP.opened_cols {fieldNat r1 "opened_cols"}; Lean {t.openedCols}"
  s := s.check "SOURCE" (fieldNat r1 "stage_log_n" == some t.stageLogN)
    s!"R1_MVP.stage_log_n {fieldNat r1 "stage_log_n"}; Lean {t.stageLogN}"
  s := s.check "SOURCE" (fieldNat r1 "stage_inv_rate" == some t.stageInvRate)
    s!"R1_MVP.stage_inv_rate {fieldNat r1 "stage_inv_rate"}; Lean {t.stageInvRate}"
  s := s.check "SOURCE" (fieldNat r1 "ep_log_n" == some t.epLogN)
    s!"R1_MVP.ep_log_n {fieldNat r1 "ep_log_n"}; Lean {t.epLogN}"
  s := s.check "SOURCE" (fieldNat r1 "ep_inv_rate" == some t.epInvRate)
    s!"R1_MVP.ep_inv_rate {fieldNat r1 "ep_inv_rate"}; Lean {t.epInvRate}"
  s := s.check "SOURCE" (has tio "pub(crate) const REGISTERED: [Tier; 1] = [Tier::R1_MVP];")
    "token_io.rs: R1_MVP is the ONLY registered tier"
  s := s.check "SOURCE" (has cls "        tier.check()?;") "classify.rs: the classifier door refuses an unregistered tier"
  s := s.check "SOURCE" (has tio
    "PcsParams { log_cols: self.stage_log_n as u32, inv_rate: self.stage_inv_rate, num_col_checks: self.opened_cols }")
    "token_io.rs: stage_params() is the tier's stage geometry"
  s := s.check "SOURCE" (has sic "    let lt = cp.tier.stage_log_n;" && has sic "StageLayout::new(cp.tier.stage_params(),")
    "stage_in_c.rs: stage IN-C's A, H at tier.stage_log_n, tier.stage_params()"
  s := s.check "SOURCE" (has cls "        let lt = tier.stage_log_n;") "classify.rs: stage OUT-C's row width is tier.stage_log_n"
  s := s.check "SOURCE" (has (lineWith cls "EndpointSpecG::new_with_tag(context, 1, cp.in_ep_words(), 0, CLASSIFY_IN_EP_SLOTS.0")
      "t.ep_log_n, t.ep_inv_rate, t.opened_cols")
    "classify.rs: input_endpoint_spec commits the input at t.ep_log_n, t.ep_inv_rate, t.opened_cols"
  s := s.check "SOURCE" (has pcs "ZkOpts { q_pad: params.num_col_checks, coset: Fp::new(7) }")
    "zkp-core pcs.rs: ZkOpts::standard: pads = opened columns, coset 7"
  s := s.check "SOURCE" (has epg "PcsParams { log_cols: self.log_n, inv_rate: self.inv_rate, num_col_checks: self.checks }"
      && has epg "pub(crate) const MASK_ROWS: usize = 5;" && has epg "&ZkOpts::standard(&params)")
    "endpoint_g.rs: the endpoint's PCS parameters, five mask rows, ZkOpts::standard"
  let r13 := lineWith shp "AccuracyProfile{profile:R13_SHIELD_T128_H24,"
  s := s.check "SOURCE" (fieldNat (r13.replace ":" ": ") "log_cols" == some ogR13.lc)
    s!"shape.rs: R13_SHIELD_T128_H24 log_cols {fieldNat (r13.replace ":" ": ") "log_cols"}; Lean ogR13 {ogR13.lc}"
  s := s.check "SOURCE" (has shp "(endpoint_log_n.unwrap_or(log_cols), endpoint_inv_rate.unwrap_or(inv_rate))")
    "shape.rs: a block's boundary row width defaults to its log_cols (the block geometry)"
  for l in s.log do
    IO.println l
  for (k, n, f) in s.kinds do
    IO.println s!"{k}: {n} checks, {f} failed"
  IO.println s!"RunOpenGeoCheck: {s.n} checks, {s.failed} failed"
  return (if s.failed = 0 then 0 else 1)

end ZK60.Exec.Link.GeoCheck

def main (args : List String) : IO UInt32 := ZK60.Exec.Link.GeoCheck.main args
