//! **W16 (D54): THE MECHANICAL PRIVACY GATE AT THE W16 PROFILES.** TEST CODE
//! ONLY (2026-11-01, the D54 privacy re-check's tooling step).
//!
//! **What the gate knew before this module.** The recorder (`run_capture.rs`)
//! and its plane index (`plane_index.rs`) enumerate every committed `A` and
//! `H` plane of a stage and, per slot, the planes its masked claims evaluate;
//! a capture is refused unless every slot's actual private tables are that
//! list. At a W16 layout the index REFUSED: its `H` name table had no entry
//! for the range families' table helpers, its `SC_TAB` push order had three
//! (histogram, helper) pairs, and its `SC_SZC` range was the legacy
//! `A_S8 ..= sg(ls - 1)` (no legacy `sigma_s` id is mapped at W16). And the
//! recorder's statement-table labels put R13's ACT support at `SC_TAB`'s
//! fifth public table, which at W16 is a range column. So no W16 run could
//! be captured, and nothing listed the 16-bit histograms.
//!
//! **What W16 adds to the verifier's view** (`DESIGN.md` step 6, review §
//! "Privacy-relevant changes"): one multiplicity plane `A_R{w}_{s}` per range
//! sub-plane, each a HISTOGRAM of the hidden words and limbs of its width
//! (the count moves with the layer's gate denominator, whose remainder top
//! is a `G - 16`-bit family: 14 at the rung and 13 at both T128 shapes at the
//! denominators these tests' synthetic data derive); one table helper `H_GR{w}_{s}` per
//! sub-plane; and one public range column (`v + gamma tag(w)`) per sub-plane
//! (plus a support column per narrow family when `Dom::Tab` pads).
//!
//! **The checks** (each printed `W16-PG <shape> <check> PASS|FAIL`):
//!
//! * PG-1 the plane index builds (tiling, domains against `Ids` / `HIds`,
//!   per-slot counts against `Shape::claim_sites`);
//! * PG-2 every W16 plane is named: the histograms and their helpers, by
//!   family and sub-plane, on `Dom::Tab`;
//! * PG-3 each histogram and each range helper is read by exactly ONE masked
//!   claim, in `SC_TAB`, and by no other slot;
//! * PG-4 every claim site has its own reserved mask pair;
//! * PG-5 `argument::define` pushes exactly the index's order at every slot
//!   (synthetic public data, no proof);
//! * on a real proved-and-verified W16 run captured through the recorder:
//!   PG-6 the capture (independent replay at every site, the push-order
//!   cross-check, the export replay of the statement tables); PG-7 the
//!   allow-list; PG-8 the masked claims as captured (distinct pairs, each
//!   new plane read once, in `SC_TAB`); PG-9 the public tables (each range
//!   column and support column rebuilt by the gate from the shape and the
//!   recorded `gamma`; the ACT support is the one statement table; no public
//!   table equals any committed `A` plane); PG-10 the view's STRUCTURE does
//!   not depend on the hidden input (two inputs: the same keys, array
//!   lengths, table lengths, claims, mask pairs and segment lengths).
//!
//! Controls show each check fires (`C-1` .. `C-6`).
//!
//! **NOTHING HERE IS A PRIVACY STATEMENT OR AN ACCEPTANCE.** These are
//! mechanical consistency checks of one development shape's view (and, by
//! name, the two trained T128 shapes'); the Python gate's rank, mask / CFS,
//! joint, NL-1 and terminal-identity checks are not ported to W16.

use super::argument::{define, Ctx, Points, Tab};
use super::layout::*;
use super::plane_index::{self, PlaneIndex, Ref};
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::run_capture::{self, Bundle, CaptureOpts};
use super::shape::{self, NormCalibration, Shape};
use super::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind, TrainedModelStatement};
use super::witness::{self, Witness};
use super::*;
use crate::field::{Fp, Fp2};
use crate::transcript::Transcript;
use std::collections::{BTreeMap, HashSet};

/// **TEST-ONLY RUN IDENTITIES** over the W16 block profiles: W16 registers no
/// run profile yet (registration is still owed, D54), and a capture needs a
/// run. `run.rs`'s `registered_block_shape` admits these in test builds only
/// (CS-7: each names exactly its block shape); no production build has them.
pub(super) const W16_TEST_RUN_PROFILES: [(&str, &str); 3] = [
    ("hashline-zk-mr1/private-run-rung-lh-t32-w16-tst/1", shape::W16_RUNG_H24),
    ("hashline-zk-mr1/private-run-shieldstral-3b-t128-lowh24-w16-tst/1", shape::W16_SHIELD_T128_H24),
    ("hashline-zk-mr1/private-run-llama-3-8b-t128-lh24-w16-tst/1", shape::W16_8B_T128_H24),
];

fn run_profile_of(block: &str) -> &'static str {
    W16_TEST_RUN_PROFILES.iter().find(|(_, b)| *b == block).map(|(r, _)| *r).expect("a W16 block profile with a test-only run identity")
}

// ---------------------------------------------------------------- the record

/// one check's outcome, printed as one line
struct Check {
    shape: String,
    name: &'static str,
    pass: bool,
    detail: String,
}

#[derive(Default)]
struct Record(Vec<Check>);

impl Record {
    fn put(&mut self, shape: &str, name: &'static str, r: Result<String, String>) {
        let (pass, detail) = match r {
            Ok(d) => (true, d),
            Err(d) => (false, d),
        };
        eprintln!("W16-PG {shape} {name} {} {detail}", if pass { "PASS" } else { "FAIL" });
        self.0.push(Check { shape: shape.to_string(), name, pass, detail });
    }
    /// every check passed (the test's verdict, after every line is printed)
    fn assert_all(&self) {
        let failed: Vec<String> = self.0.iter().filter(|c| !c.pass).map(|c| format!("{} {}: {}", c.shape, c.name, c.detail)).collect();
        assert!(failed.is_empty(), "W16 privacy gate: {} of {} checks FAILED:\n{}", failed.len(), self.0.len(), failed.join("\n"));
        eprintln!("W16-PG VERDICT {} checks, all PASS", self.0.len());
    }
}

/// a control: the check must FAIL on the doctored input
fn control(rec: &mut Record, shape: &str, name: &'static str, doctored: Result<String, String>) {
    rec.put(shape, name, match doctored {
        Ok(d) => Err(format!("the control did NOT fire ({d})")),
        Err(e) => Ok(format!("fires: {}", e.chars().take(160).collect::<String>())),
    });
}

// ---------------------------------------------------------------- the cases

/// A W16 block case: the rung at the M4 byte gate's recipe
/// (`range16_tests::rung_case`'s calibration and, at `seed = 0`, its input),
/// a trained T128 shape at the M4 trained-digest recipe; the first
/// admissible synthetic input from `seed`. Public synthetic data only.
fn w16_case(profile: &str, seed: usize) -> (Shape, BlockPublic, Witness) {
    let original = super::range16_tests::built(profile);
    let rung = original.tokens == 32;
    let original = if rung {
        let cal = NormCalibration { cn_a: 4000, cn_m: 4000, ..original.norm_calibration() };
        Shape::accuracy_trained(original.profile, &cal, original.f_e, 20).expect("the W16 rung at the M4 recipe")
    } else {
        original
    };
    let (sh, data, public, ff) = super::range16_tests::case(original, 3);
    let mut s = seed;
    let w = loop {
        let input: Vec<i16> = if rung {
            (0..sh.tokens * sh.width).map(|i| ((i * (37 + 16 * s) + 11 + 5 * s) % 201) as i16 - 100).collect()
        } else {
            (0..sh.tokens * sh.width).map(|i| ((i * 37 + 11 + s) % (41 + 20 * (s % 3))) as i16 - 20).collect()
        };
        match witness::build_accuracy(&sh, &public, &ff, &data, &input) {
            Ok(w) => break w,
            Err(_) if s < seed + 8 => s += 1,
            Err(e) => panic!("{}: no admissible synthetic input from seed {seed}: {e}", sh.name),
        }
    };
    (sh, BlockPublic::new(public, ff).with_accuracy(data), w)
}

/// the synthetic one-layer statement of a W16 test run (the test-only
/// constructor; a public synthetic recipe, never a checkpoint)
fn model_of(sh: &Shape, blk: &BlockPublic) -> TrainedModelStatement {
    let mut prov = Provenance::recipe("W16 privacy gate fixture (public synthetic)", 1.0, [3; 32], [4; 32]);
    prov.rope_theta = shape::trained_rope_theta(sh.profile).expect("a W16 profile's pinned RoPE base");
    prov.rope_scaling = shape::trained_rope_scaling(sh.profile).expect("a W16 profile's pinned RoPE transform");
    let source = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "synthetic/w16-privacy-gate".into(), revision: "w16-gate".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: 1 };
    TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh, run_profile_of(sh.profile), source, IntegerCalibration::as_the_code_proves(sh, &prov), vec![LayerRecord::of_block(0, blk, vec![])])
        .unwrap_or_else(|e| panic!("{}: the synthetic statement: {e}", sh.name))
}

struct One(Option<Witness>);
impl RunWitnessSource for One {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        if k != 0 {
            return Err("one stage".into());
        }
        self.0.take().ok_or_else(|| "the witness was consumed".into())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("no internal boundary".into())
    }
}

/// one captured W16 run and what the gate reads beside it (the A planes are
/// the PROVER's, kept only so PG-9 can show none of them is published)
struct Captured {
    sh: Shape,
    lay: Layout,
    a_planes: Vec<Vec<i64>>,
    segs: Vec<Vec<u8>>,
    bundle: Bundle,
    replay: String,
}

/// Prove an honest one-block W16 run under its test-only run identity,
/// verify it bare, then verify it again with the recorder attached (array
/// store and public-table values on) and replay the statement tables against
/// the block's public data.
fn prove_and_capture(profile: &str, seed: usize) -> Result<Captured, String> {
    let (sh, blk, w) = w16_case(profile, seed);
    let ids = Ids::new(&sh)?;
    // the committed A planes as the PROVER writes them: the witness carries
    // the multiplicity planes as placeholders, and `prove_core` fills the
    // byte histogram and each range sub-plane's true rows from the looked
    // columns (`protocol::w16_histograms`; padded copies stay zero)
    let mut a_planes = w.planes.clone();
    {
        let lay = Layout::for_shape(&sh)?;
        let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, super::protocol::lookup_values(&lay, &w, *d))).collect();
        let (m_u8, m_rng, missed) = super::protocol::w16_histograms(&lay, &looked);
        if missed != 0 {
            return Err(format!("{missed} looked words miss their table"));
        }
        let fams = sh.range_families();
        for (f, s, plane) in ids.accuracy()?.range_planes() {
            let m = &m_rng[fams.iter().position(|x| *x == f).ok_or("a range sub-plane outside the shape's families")?];
            let (base, sup) = (s << sh.log_cols, super::range16::support(f, sh.log_cols));
            let mut col = vec![0i64; 1usize << sh.log_cols];
            for (i, c) in col.iter_mut().enumerate().take(sup) {
                *c = m[base + i] as i64;
            }
            a_planes[plane] = col;
        }
        let mut col = vec![0i64; sh.size(Dom::Tab)];
        for (i, c) in col.iter_mut().enumerate().take(U8_LEN) {
            *c = m_u8[i] as i64;
        }
        a_planes[ids.at(A_MU8)] = col;
    }
    let input: Vec<i16> = w.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
    let output: Vec<i16> = w.planes[ids.at(A_X2)].iter().map(|&v| v as i16).collect();
    let context = [59u8; 32];
    let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&sh, context, 0, 0)?, &input, &output)?;
    let blocks = vec![blk.clone()];
    let model = model_of(&sh, &blk);
    let rs = RunShape::new(sh.clone(), 1, run_profile_of(sh.profile))?;
    let st = RunStatement::new_bound(rs, context, expected, &blocks, &[(0, 0)], &model)?;
    let mut segs: Vec<Vec<u8>> = Vec::new();
    run::prove_run(&st, &blocks, &mut One(Some(w)), owners, &mut |k, b| {
        if k != segs.len() {
            return Err("segments out of order".into());
        }
        segs.push(b);
        Ok(())
    })
    .map_err(|e| format!("the honest W16 run does not prove: {e}"))?;
    run::verify_run(&st, &blocks, &segs).map_err(|e| format!("the honest W16 run does not verify: {e}"))?;
    let guard = run_capture::Recorder::attach();
    run_capture::begin_run_with(st.capture_header()?, st.binding()?, CaptureOpts { arrays: true, public_tables: true });
    let verdict = run::verify_run(&st, &blocks, &segs);
    let taken = run_capture::take();
    drop(guard);
    verdict.map_err(|e| format!("the run does not verify with a recorder attached: {e}"))?;
    let mut bundle = taken.map_err(|e| format!("the recorder refused the capture: {e}"))?;
    let rep = run_capture::export_replay(&mut bundle, &mut |k| if k == 0 { Ok(blk.clone()) } else { Err(format!("no block {k}")) })?;
    let replay = format!("export replay {} statement tables, {} entries ({})", rep.tables, rep.entries, rep.per_kind.iter().map(|(k, n)| format!("{k} x{n}")).collect::<Vec<_>>().join(", "));
    let lay = Layout::for_shape(&sh)?;
    Ok(Captured { sh, lay, a_planes, segs, bundle, replay })
}

// ---------------------------------------------------------------- reading a stage file

fn find_from(hay: &[u8], needle: &str, from: usize) -> Option<usize> {
    let n = needle.as_bytes();
    if from >= hay.len() || n.len() > hay.len() - from {
        return None;
    }
    hay[from..].windows(n.len()).position(|w| w == n).map(|p| p + from)
}

fn trim(b: &[u8]) -> &[u8] {
    let s = b.iter().position(|c| !c.is_ascii_whitespace()).unwrap_or(b.len());
    let e = b.iter().rposition(|c| !c.is_ascii_whitespace()).map(|p| p + 1).unwrap_or(s);
    &b[s..e.max(s)]
}

/// the top-level entries of the JSON array that opens at `hay[at]`
fn entries(hay: &[u8], at: usize) -> Vec<&[u8]> {
    assert_eq!(hay.get(at), Some(&b'['), "not a JSON array");
    let (mut depth, mut start, mut in_str, mut i) = (0i32, at + 1, false, at);
    let mut out = Vec::new();
    while i < hay.len() {
        let c = hay[i];
        if in_str {
            if c == b'\\' {
                i += 2;
                continue;
            }
            if c == b'"' {
                in_str = false;
            }
            i += 1;
            continue;
        }
        match c {
            b'"' => in_str = true,
            b'[' | b'{' => depth += 1,
            b']' | b'}' => {
                depth -= 1;
                if depth == 0 {
                    let last = trim(&hay[start..i]);
                    if !last.is_empty() {
                        out.push(last);
                    }
                    return out;
                }
            }
            b',' if depth == 1 => {
                out.push(trim(&hay[start..i]));
                start = i + 1;
            }
            _ => {}
        }
        i += 1;
    }
    panic!("an unterminated JSON array");
}

/// `"key":"value"` (the first occurrence)
fn field_str<'a>(e: &'a [u8], key: &str) -> Option<&'a str> {
    let at = find_from(e, &format!("\"{key}\":\""), 0)? + key.len() + 4;
    let end = e[at..].iter().position(|c| *c == b'"')? + at;
    std::str::from_utf8(&e[at..end]).ok()
}

/// every `"key":N` (a direct unsigned number) in order
fn nums(e: &[u8], key: &str) -> Vec<u64> {
    let pat = format!("\"{key}\":");
    let mut out = Vec::new();
    let mut from = 0;
    while let Some(at) = find_from(e, &pat, from) {
        let s = at + pat.len();
        let end = e[s..].iter().position(|c| !c.is_ascii_digit()).map(|p| p + s).unwrap_or(e.len());
        if end > s {
            out.push(std::str::from_utf8(&e[s..end]).unwrap().parse().unwrap());
        }
        from = s;
    }
    out
}

fn num(e: &[u8], key: &str) -> Option<u64> {
    nums(e, key).first().copied()
}

/// every slot's `tables` entries in a stage file, by slot number
fn slot_tables(stage: &[u8], n_slots: usize) -> Result<Vec<Vec<&[u8]>>, String> {
    (0..n_slots)
        .map(|s| {
            let at = find_from(stage, &format!("{{\"slot\":{s},\"name\":"), 0).ok_or(format!("the stage file has no slot {s}"))?;
            let t = find_from(stage, "\"tables\":[", at).ok_or(format!("slot {s} has no tables"))? + "\"tables\":".len();
            Ok(entries(stage, t))
        })
        .collect()
}

/// the stage's recorded LogUp challenges `(beta, gamma, alpha)`
fn logup_challenges(stage: &[u8]) -> Result<Vec<Fp2>, String> {
    let at = find_from(stage, "\"logup_challenges\":[", 0).ok_or("the stage file records no LogUp challenges")? + "\"logup_challenges\":".len();
    entries(stage, at)
        .iter()
        .map(|pair| {
            let p = entries(pair, 0);
            let v = |b: &[u8]| -> Result<u64, String> { std::str::from_utf8(b).map_err(|e| e.to_string())?.parse::<u64>().map_err(|e| e.to_string()) };
            if p.len() != 2 {
                return Err("a LogUp challenge is not a pair".into());
            }
            Ok(Fp2::new(Fp(v(p[0])?), Fp(v(p[1])?)))
        })
        .collect()
}

/// the SHA-256 the recorder takes over a public table (16 bytes an entry)
fn sha_fp2(v: impl Iterator<Item = Fp2>) -> String {
    let mut bytes = Vec::new();
    for x in v {
        bytes.extend_from_slice(&x.to_bytes());
    }
    crate::export_v3::sha256_hex(&bytes)
}

/// **THE GATE'S OWN RANGE COLUMN**, from `DESIGN.md` and the review, not from
/// `range16.rs`: entry `i` of sub-plane `s` of the `w`-bit family is
/// `s 2^lc + (i mod min(2^w, 2^lc)) + gamma (200 + tag_width)`
fn range_column_sha(w: u32, s: usize, lc: usize, gamma: Fp2, tag_width: u32) -> String {
    let n = 1usize << lc;
    let support = (1usize << w).min(n);
    let g = gamma.mul_base(Fp::new(200 + u64::from(tag_width)));
    sha_fp2((0..n).map(|i| Fp2::from_i64((s * n + i % support) as i64).add(g)))
}

/// the gate's own support column of a narrow `w`-bit family
fn support_column_sha(w: u32, lc: usize) -> String {
    let n = 1usize << lc;
    sha_fp2((0..n).map(|i| if i < (1usize << w) { Fp2::ONE } else { Fp2::ZERO }))
}

/// every array's top-level entry count, in closing order (a structure
/// fingerprint that ignores every value)
fn array_lengths(bytes: &[u8]) -> Vec<usize> {
    let mut stack: Vec<(u8, usize, bool)> = Vec::new();
    let mut out = Vec::new();
    let (mut in_str, mut i) = (false, 0usize);
    while i < bytes.len() {
        let c = bytes[i];
        if in_str {
            if c == b'\\' {
                i += 2;
                continue;
            }
            if c == b'"' {
                in_str = false;
            }
            i += 1;
            continue;
        }
        match c {
            b'"' => {
                in_str = true;
                if let Some(t) = stack.last_mut() {
                    t.2 = true;
                }
            }
            b'[' | b'{' => {
                if let Some(t) = stack.last_mut() {
                    t.2 = true;
                }
                stack.push((c, 0, false));
            }
            b']' | b'}' => {
                let (k, commas, nonempty) = stack.pop().expect("balanced JSON");
                if k == b'[' {
                    out.push(if nonempty { commas + 1 } else { 0 });
                }
            }
            b',' => {
                if let Some(t) = stack.last_mut() {
                    t.1 += 1;
                }
            }
            c if c.is_ascii_whitespace() => {}
            _ => {
                if let Some(t) = stack.last_mut() {
                    t.2 = true;
                }
            }
        }
        i += 1;
    }
    out
}

/// a table entry with every value that is a field element or a digest left
/// out: what a reader learns about the table's SHAPE
fn descriptor(e: &[u8]) -> String {
    match field_str(e, "kind") {
        Some("private") => format!(
            "P {:?} c{:?} l{:?} m{:?} x{:?} o{:?} rho{:?} flip{:?} fixed{}",
            field_str(e, "role"),
            num(e, "claim"),
            num(e, "log_size"),
            num(e, "mask_row"),
            num(e, "extension_round"),
            nums(e, "offset"),
            nums(e, "rho"),
            nums(e, "flip"),
            find_from(e, "\"fixed\":", 0).is_some()
        ),
        Some("public") => format!("U {:?}", num(e, "len")),
        Some("eq") => format!("E {:?}", num(e, "start")),
        k => format!("? {k:?}"),
    }
}

// ---------------------------------------------------------------- PG-1 .. PG-5: the layout

/// PG-1 .. PG-4 at one W16 layout; the index for the later checks
fn layout_checks(rec: &mut Record, name: &str, lay: &Layout) -> Option<PlaneIndex> {
    let sh = lay.shape();
    let idx = match plane_index::build(lay) {
        Ok(i) => {
            rec.put(name, "PG-1 plane-index", Ok(format!("{} A planes ({} data rows), {} H planes ({} data rows); tiling, domains and per-slot claim counts agree", i.a.len(), i.a_data_rows, i.h.len(), i.h_data_rows)));
            i
        }
        Err(e) => {
            rec.put(name, "PG-1 plane-index", Err(e));
            return None;
        }
    };
    let low = lay.ids().accuracy().expect("a W16 layout has the accuracy allocation");
    let rp = low.range_planes();
    let rh: Vec<usize> = lay.hids().range_helpers().collect();
    // PG-2: every plane named; the new ones by family and sub-plane
    rec.put(name, "PG-2 names", (|| {
        if idx.a.len() != lay.ids().n_a() || idx.h.len() != lay.hids().n_h() {
            return Err("the index's plane counts are not the layout's".to_string());
        }
        for (p, (nm, d)) in idx.a.iter().zip(low.names.iter().zip(low.doms.iter())) {
            if p.name != format!("A_{nm}") || p.dom != *d {
                return Err(format!("A plane {} is {} on {:?}, the allocation says A_{nm} on {d:?}", p.id, p.name, p.dom));
            }
        }
        let mut seen = HashSet::new();
        for nm in idx.a.iter().map(|p| &p.name).chain(idx.h.iter().map(|p| &p.name)) {
            if !seen.insert(nm.clone()) {
                return Err(format!("the plane name {nm} occurs twice"));
            }
        }
        let want = super::range16::sub_planes(&sh.range_families()).len();
        if rp.len() != want || rh.len() != want || want == 0 {
            return Err(format!("{} histograms and {} range helpers for {want} range sub-planes", rp.len(), rh.len()));
        }
        let mut list = Vec::new();
        for ((f, s, p), h) in rp.iter().zip(&rh) {
            let (a, hh) = (&idx.a[*p], &idx.h[*h]);
            if a.name != format!("A_R{}_{s}", f.width) || hh.name != format!("H_GR{}_{s}", f.width) || a.dom != Dom::Tab || hh.dom != Dom::Tab || a.rows != 1 || hh.rows != 1 {
                return Err(format!("range sub-plane ({}, {s}) is named {} / {} on {:?} / {:?}", f.width, a.name, hh.name, a.dom, hh.dom));
            }
            list.push(format!("{}+{}", a.name, hh.name));
        }
        Ok(format!("{} histograms (A, Dom::Tab, one row of 2^{} each) with their table helpers (H, Fp2): {}", rp.len(), sh.log_cols, list.join(" ")))
    })());
    // PG-3: each new plane is read by exactly one claim, in SC_TAB
    rec.put(name, "PG-3 one-claim", new_planes_read_once(&idx.slots, &rp.iter().map(|(_, _, p)| *p).collect::<Vec<_>>(), &rh).map(|d| format!("{d}; SC_TAB declares {} A / {} H sites", lay.a_sites()[SC_TAB], lay.h_sites()[SC_TAB])));
    // PG-4: one reserved pair per claim site
    rec.put(name, "PG-4 mask-pairs", (|| {
        let mut out = Vec::new();
        for (role, base, prox, sites) in [("A", lay.a_mask_base, lay.a_prox, lay.a_sites().to_vec()), ("H", lay.h_mask_base, lay.h_prox, lay.h_sites().to_vec())] {
            let mut rows = HashSet::new();
            for (s, n) in sites.iter().enumerate() {
                for k in 0..*n {
                    let r = if role == "A" { lay.a_site(s, k)? } else { lay.h_site(s, k)? };
                    if r < base || r + 1 >= prox || (r - base) % 2 != 0 || !rows.insert(r) {
                        return Err(format!("{role} site {k} of slot {s} has the pair at row {r}, outside [{base}, {prox}) or shared"));
                    }
                }
            }
            if 2 * rows.len() != prox - base {
                return Err(format!("{role}: {} sites for {} reserved rows", rows.len(), prox - base));
            }
            out.push(format!("{role} {} sites on {} distinct pairs", rows.len(), rows.len()));
        }
        Ok(out.join(", "))
    })());
    Some(idx)
}

/// each histogram and each range helper appears exactly once in the push
/// orders, and only in `SC_TAB`, as the pair (histogram, its helper)
fn new_planes_read_once(slots: &[Vec<Ref>], hist: &[usize], helpers: &[usize]) -> Result<String, String> {
    let mut seen: BTreeMap<(bool, usize), Vec<usize>> = BTreeMap::new();
    for (s, refs) in slots.iter().enumerate() {
        for r in refs {
            match r {
                Ref::A(p) if hist.contains(p) => seen.entry((true, *p)).or_default().push(s),
                Ref::H(p) if helpers.contains(p) => seen.entry((false, *p)).or_default().push(s),
                _ => {}
            }
        }
    }
    for p in hist.iter().map(|p| (true, *p)).chain(helpers.iter().map(|p| (false, *p))) {
        let at = seen.get(&p).cloned().unwrap_or_default();
        if at != vec![SC_TAB] {
            return Err(format!("{} plane {} is read by slots {at:?}, not once by SC_TAB", if p.0 { "A" } else { "H" }, p.1));
        }
    }
    let tab = &slots[SC_TAB];
    for (j, (a, h)) in hist.iter().zip(helpers).enumerate() {
        if tab.get(6 + 2 * j) != Some(&Ref::A(*a)) || tab.get(7 + 2 * j) != Some(&Ref::H(*h)) {
            return Err(format!("SC_TAB's pair {j} is not (A {a}, H {h})"));
        }
    }
    Ok(format!("{} histograms and {} helpers, each read once, by SC_TAB, in (histogram, helper) pairs after the byte / exp / ACT pairs", hist.len(), helpers.len()))
}

/// PG-5: the slot definitions themselves, on the shape's synthetic public
/// data, push exactly the index's order (what the recorder checks per
/// captured slot, here without a proof). `sh` is a shape `w16_case` proved.
fn definitions_match(sh: &Shape) -> Result<String, String> {
    let (csh, data, public, ff) = super::range16_tests::case(sh.clone(), 3);
    if csh != *sh {
        return Err("the synthetic public data is not at the proved shape".into());
    }
    let lay = Layout::for_shape(&csh)?;
    let idx = plane_index::build(&lay)?;
    let k = Fp2::from_i64;
    let ctx = Ctx { accuracy: Some(&data), lay: &lay, public: &public, ff: &ff, alpha: k(7).add(Fp2::U), beta: k(11), g_u8: k(13), g_exp: k(17), g_act: k(19), g_dd: k(23) };
    let mut pts = Points::default();
    let mut tr = Transcript::new(csh.profile.as_bytes());
    let mut refs = 0usize;
    for slot in 0..csh.n_slots() {
        let def = define(slot, &ctx, &mut pts, &mut tr)?;
        let mut observed = Vec::new();
        for t in &def.tabs {
            if let Tab::Priv(p) = t {
                let off = p.slices.first().map(|(o, _)| *o).unwrap_or(usize::MAX);
                observed.push(idx.locate(p.cm as usize, off).ok_or(format!("slot {slot} reads role {} at offset {off}, on no indexed plane", p.cm as usize))?);
            }
        }
        if observed != idx.slots[slot] {
            return Err(format!("slot {slot} [{}] pushes {} private tables that are not the index's {}", SLOT_NAMES[slot], observed.len(), idx.slots[slot].len()));
        }
        refs += observed.len();
    }
    Ok(format!("{} slots, {refs} private tables, each slot's order equal to the index's", csh.n_slots()))
}

// ---------------------------------------------------------------- PG-6 .. PG-10: a captured run

/// PG-7: the allow-list and the forbidden words
fn allow_list(files: &[(&str, &[u8])]) -> Result<String, String> {
    let mut n = 0usize;
    for (name, bytes) in files {
        for key in run_capture::keys_of(bytes) {
            if !run_capture::ALLOWED_KEYS.contains(&key.as_str()) {
                return Err(format!("{name} carries the field {key:?}, which is not on the capture allow-list"));
            }
            n += 1;
        }
        let end = find_from(bytes, "\"not_in_a_capture\"", 0).unwrap_or(bytes.len());
        for forbidden in ["witness", "plaintext", "hidden_input", "hidden_plane", "plane_values", "mask_coefficient", "unopened", "ZkRng", "seed", "secret", "histogram"] {
            if find_from(&bytes[..end], forbidden, 0).is_some() {
                return Err(format!("{name} contains the word {forbidden:?}"));
            }
        }
    }
    Ok(format!("{n} fields, every one on the allow-list; no forbidden word"))
}

/// PG-8: the masked claims of a captured stage
fn masked_claims(lay: &Layout, stage: &[u8], idx: &PlaneIndex) -> Result<String, String> {
    let sh = lay.shape();
    let tables = slot_tables(stage, sh.n_slots())?;
    let low = lay.ids().accuracy()?;
    let hist: Vec<usize> = low.range_planes().iter().map(|(_, _, p)| *p).collect();
    let helpers: Vec<usize> = lay.hids().range_helpers().collect();
    let mut rows: [HashSet<u64>; 2] = [HashSet::new(), HashSet::new()];
    let mut refs: Vec<Vec<Ref>> = vec![Vec::new(); sh.n_slots()];
    for (s, ts) in tables.iter().enumerate() {
        for e in ts.iter().filter(|e| field_str(e, "kind") == Some("private")) {
            let role = field_str(e, "role").ok_or("a private table without a role")?;
            let off = num(e, "offset").ok_or("a private table without a slice")? as usize;
            let cm = match role {
                "A" => 0,
                "H" => 1,
                "Input" => 2,
                "Output" => 3,
                r => return Err(format!("slot {s}: an unknown role {r}")),
            };
            refs[s].push(idx.locate(cm, off).ok_or(format!("slot {s}: a {role} claim at offset {off} is on no indexed plane"))?);
            if cm < 2 {
                let m = num(e, "mask_row").ok_or("a private table without its mask pair")?;
                let (base, prox) = if cm == 0 { (lay.a_mask_base, lay.a_prox) } else { (lay.h_mask_base, lay.h_prox) };
                if (m as usize) < base || m as usize + 1 >= prox || (m as usize - base) % 2 != 0 {
                    return Err(format!("slot {s}: a {role} claim's mask pair at row {m} is outside the reserved rows [{base}, {prox})"));
                }
                if !rows[cm].insert(m) {
                    return Err(format!("slot {s}: two {role} claims share the mask pair at row {m}"));
                }
            }
        }
    }
    let (na, nh): (usize, usize) = (lay.a_sites().iter().sum(), lay.h_sites().iter().sum());
    if rows[0].len() != na || rows[1].len() != nh {
        return Err(format!("{} A / {} H masked claims captured for {na} / {nh} declared sites", rows[0].len(), rows[1].len()));
    }
    let once = new_planes_read_once(&refs, &hist, &helpers)?;
    Ok(format!("{na} A and {nh} H claims as captured, each on its own reserved pair; {once}"))
}

/// PG-9: the public tables of a captured stage. `a_planes` are the prover's
/// committed A planes (test-side only), `statement` the recorder's statement
/// tables.
fn public_tables(lay: &Layout, stage: &[u8], a_planes: &[Vec<i64>], statement: &[run_capture::StatementTable]) -> Result<String, String> {
    let sh = lay.shape();
    let tables = slot_tables(stage, sh.n_slots())?;
    let lc = sh.log_cols;
    let ch = logup_challenges(stage)?;
    let gamma = *ch.get(1).ok_or("fewer than three LogUp challenges")?;
    let rp = lay.ids().accuracy()?.range_planes();
    let tab: Vec<&[u8]> = tables[SC_TAB].iter().copied().filter(|e| field_str(e, "kind") == Some("public")).collect();
    let narrow: Vec<u32> = rp.iter().filter(|(f, _, _)| (1usize << f.width) < (1usize << lc)).map(|(f, _, _)| f.width).collect();
    let padded = tab.len() == 3 + rp.len() + 2 + narrow.len();
    if !padded && tab.len() != 3 + rp.len() {
        return Err(format!("SC_TAB carries {} public tables; W16 has 3 + {} (+ 2 + {} when Dom::Tab pads)", tab.len(), rp.len(), narrow.len()));
    }
    // (a) every range column and support column, rebuilt by the gate
    for (j, (f, s, _)) in rp.iter().enumerate() {
        let got = field_str(tab[3 + j], "sha256").ok_or("a public table without its digest")?;
        if num(tab[3 + j], "len") != Some(1u64 << lc) || got != range_column_sha(f.width, *s, lc, gamma, f.width) {
            return Err(format!("SC_TAB public table {} (the {}-bit range column, sub-plane {s}) is not the gate's rebuild from the shape and gamma", 3 + j, f.width));
        }
    }
    if padded {
        for (k, w) in narrow.iter().enumerate() {
            let got = field_str(tab[5 + rp.len() + k], "sha256").ok_or("a public table without its digest")?;
            if got != support_column_sha(*w, lc) {
                return Err(format!("SC_TAB public table {} (the {w}-bit support column) is not the gate's rebuild", 5 + rp.len() + k));
            }
        }
    }
    // (b) the statement tables: at SC_TAB the exp, ACT3 and (padded) ACT
    // support only, never a range column
    let at_tab: Vec<(usize, &str)> = statement.iter().filter(|t| t.slot == SC_TAB).map(|t| (t.nth, t.what)).collect();
    let want: Vec<(usize, &str)> = if padded { vec![(1, "exp_values"), (2, "act3_values"), (4 + rp.len(), "act_support")] } else { vec![(1, "exp_values"), (2, "act3_values")] };
    if at_tab != want {
        return Err(format!("SC_TAB's statement tables are {at_tab:?}, W16 has {want:?}"));
    }
    // (c) no public table is a committed A plane (a plain publication)
    let shas: HashSet<&str> = tables.iter().flatten().filter(|e| field_str(e, "kind") == Some("public")).filter_map(|e| field_str(e, "sha256")).collect();
    let (mut compared, mut constant) = (0usize, 0usize);
    let mut hist_compared = 0usize;
    for (p, vals) in a_planes.iter().enumerate() {
        if vals.iter().all(|v| *v == vals[0]) {
            constant += 1;
            continue;
        }
        let len = sh.size(lay.ids().dom(p)).min(vals.len());
        for v in [&vals[..len], &vals[..]] {
            if shas.contains(sha_fp2(v.iter().map(|x| Fp2::from_i64(*x))).as_str()) {
                return Err(format!("a public table of the stage equals the committed A plane {p}"));
            }
        }
        compared += 1;
        hist_compared += usize::from(rp.iter().any(|(_, _, q)| *q == p));
    }
    if hist_compared != rp.len() {
        return Err(format!("only {hist_compared} of the {} range histograms were non-constant and compared", rp.len()));
    }
    Ok(format!(
        "{} range columns{} rebuilt from the shape and gamma, byte-equal; SC_TAB statement tables {want:?}; {} distinct public tables, none equal to any of {compared} non-constant A planes (all {hist_compared} range histograms and the byte histogram among them, as the prover fills them; {constant} constant planes skipped)",
        rp.len(),
        if padded { format!(" and {} support columns", narrow.len()) } else { String::new() },
        shas.len(),
    ))
}

/// the files of a bundle: `run.json`, then the stage files
fn bundle_files(b: &Bundle) -> Vec<Vec<u8>> {
    std::iter::once(b.run_json.clone()).chain(b.stages.iter().cloned()).collect()
}

/// PG-10: two captures of the same shape, different hidden inputs, must have
/// the same view STRUCTURE (`fa`, `fb`: `bundle_files`; `la`, `lb`: the
/// segment lengths)
fn same_structure(n_slots: usize, fa: &[Vec<u8>], la: &[usize], fb: &[Vec<u8>], lb: &[usize]) -> Result<String, String> {
    if fa.len() != fb.len() {
        return Err(format!("{} files against {}", fa.len(), fb.len()));
    }
    let mut n_keys = 0;
    for (k, (x, y)) in fa.iter().zip(fb).enumerate() {
        let (kx, ky) = (run_capture::keys_of(x), run_capture::keys_of(y));
        if kx != ky {
            let first = kx.iter().zip(&ky).position(|(p, q)| p != q).unwrap_or(kx.len().min(ky.len()));
            return Err(format!("file {k}: the key sequences differ at key {first} ({:?} against {:?})", kx.get(first), ky.get(first)));
        }
        n_keys += kx.len();
        if array_lengths(x) != array_lengths(y) {
            return Err(format!("file {k}: the array lengths differ"));
        }
        if nums(x, "len") != nums(y, "len") {
            return Err(format!("file {k}: the table / array lengths differ"));
        }
        if k > 0 {
            let (tx, ty) = (slot_tables(x, n_slots)?, slot_tables(y, n_slots)?);
            for (s, (p, q)) in tx.iter().zip(&ty).enumerate() {
                let (dp, dq): (Vec<String>, Vec<String>) = (p.iter().map(|e| descriptor(e)).collect(), q.iter().map(|e| descriptor(e)).collect());
                if dp != dq {
                    return Err(format!("stage {}: slot {s}'s table descriptors differ", k - 1));
                }
            }
        }
    }
    if la != lb {
        return Err(format!("the segment lengths differ: {la:?} against {lb:?}"));
    }
    Ok(format!("two hidden inputs: {n_keys} keys in the same order, the same array and table lengths, every slot's claims and mask pairs, segments {la:?} B"))
}

fn seg_lens(c: &Captured) -> Vec<usize> {
    c.segs.iter().map(|s| s.len()).collect()
}

/// every capture-level check of one run, plus PG-10 when a second is given
fn capture_checks(rec: &mut Record, name: &str, c: &Captured, other: Option<&Captured>) {
    rec.put(name, "PG-6 capture", Ok(format!("an honest one-block run proved and verified; the recorder's own replay agreed at every site and every slot's private tables are the index's order; {}", c.replay)));
    let idx = plane_index::build(&c.lay).expect("the captured layout's index");
    let mut files: Vec<(&str, &[u8])> = vec![("run.json", c.bundle.run_json.as_slice())];
    for s in &c.bundle.stages {
        files.push(("stage", s.as_slice()));
    }
    rec.put(name, "PG-7 allow-list", allow_list(&files));
    let stage = &c.bundle.stages[0];
    rec.put(name, "PG-8 masked-claims", masked_claims(&c.lay, stage, &idx));
    rec.put(name, "PG-9 public-tables", public_tables(&c.lay, stage, &c.a_planes, &c.bundle.statement));
    if let Some(o) = other {
        // the two runs must really hide different data: the inputs and the
        // new histograms themselves differ, while the view's structure may not
        let x = c.lay.ids().at(A_X);
        let hist: Vec<usize> = c.lay.ids().accuracy().expect("a W16 layout").range_planes().iter().map(|(_, _, p)| *p).collect();
        let moved = hist.iter().filter(|p| c.a_planes[**p] != o.a_planes[**p]).count();
        let r = if c.a_planes[x] == o.a_planes[x] || moved == 0 {
            Err(format!("the two captures do not hide different data (inputs equal: {}, histograms that differ: {moved})", c.a_planes[x] == o.a_planes[x]))
        } else {
            same_structure(c.sh.n_slots(), &bundle_files(&c.bundle), &seg_lens(c), &bundle_files(&o.bundle), &seg_lens(o)).map(|d| format!("{d}; the hidden inputs differ and {moved} of the {} range histograms differ between them", hist.len()))
        };
        rec.put(name, "PG-10 input-independent-shape", r);
    }
}

/// the controls on a captured view: each doctored copy must FAIL its check
fn capture_controls(rec: &mut Record, name: &str, a: &Captured, b: Option<&Captured>) {
    let lay = &a.lay;
    let sh = lay.shape();
    let idx = plane_index::build(lay).expect("the captured layout's index");
    let stage = a.bundle.stages[0].clone();
    let rp = lay.ids().accuracy().expect("a W16 layout").range_planes();
    let tables = slot_tables(&stage, sh.n_slots()).expect("the stage's slot tables");
    // C-2: two histogram claims made to share a mask pair
    {
        let hist: Vec<&[u8]> = tables[SC_TAB].iter().copied().filter(|e| field_str(e, "role") == Some("A")).skip(3).take(2).collect();
        let (m0, m1) = (num(hist[0], "mask_row").unwrap(), num(hist[1], "mask_row").unwrap());
        let at = find_from(&stage, std::str::from_utf8(hist[1]).unwrap(), 0).unwrap();
        let entry = String::from_utf8(hist[1].to_vec()).unwrap().replace(&format!("\"mask_row\":{m1},"), &format!("\"mask_row\":{m0},"));
        let mut doctored = stage[..at].to_vec();
        doctored.extend_from_slice(entry.as_bytes());
        doctored.extend_from_slice(&stage[at + hist[1].len()..]);
        control(rec, name, "C-2 shared-mask-pair", masked_claims(lay, &doctored, &idx));
    }
    // C-3: the range columns rebuilt under one collapsed tag, and under gamma + 1
    {
        let gamma = logup_challenges(&stage).unwrap()[1];
        let tab: Vec<&[u8]> = tables[SC_TAB].iter().copied().filter(|e| field_str(e, "kind") == Some("public")).collect();
        let rebuild = |g: Fp2, collapsed: bool| -> Result<String, String> {
            for (j, (f, s, _)) in rp.iter().enumerate() {
                if field_str(tab[3 + j], "sha256") != Some(range_column_sha(f.width, *s, sh.log_cols, g, if collapsed { 16 } else { f.width }).as_str()) {
                    return Err(format!("range column {j} ({}-bit) differs", f.width));
                }
            }
            Ok("every range column matched".into())
        };
        control(rec, name, "C-3a collapsed-tags", rebuild(gamma, true));
        control(rec, name, "C-3b wrong-gamma", rebuild(gamma.add(Fp2::ONE), false));
    }
    // C-4: a histogram published as a public table (planted over the byte
    // table's digest) is seen by PG-9 (c)
    {
        let planted = sha_fp2(a.a_planes[rp[0].2].iter().map(|x| Fp2::from_i64(*x)));
        let byte_table = tables[SC_TAB].iter().copied().find(|e| field_str(e, "kind") == Some("public")).unwrap();
        let old = field_str(byte_table, "sha256").unwrap().to_string();
        let doctored = String::from_utf8(stage.clone()).unwrap().replacen(&format!("\"sha256\":\"{old}\""), &format!("\"sha256\":\"{planted}\""), 1);
        control(rec, name, "C-4 planted-histogram", public_tables(lay, doctored.as_bytes(), &a.a_planes, &a.bundle.statement));
    }
    // C-5: one mask pair moved breaks the structure comparison
    if let Some(b) = b {
        let mut fb = bundle_files(&b.bundle);
        let s = String::from_utf8(fb[1].clone()).unwrap();
        let at = s.find("\"mask_row\":").unwrap() + "\"mask_row\":".len();
        let end = at + s[at..].find(|c: char| !c.is_ascii_digit()).unwrap();
        let v: u64 = s[at..end].parse().unwrap();
        fb[1] = format!("{}{}{}", &s[..at], v + 2, &s[end..]).into_bytes();
        control(rec, name, "C-5 moved-pair", same_structure(sh.n_slots(), &bundle_files(&a.bundle), &seg_lens(a), &fb, &seg_lens(b)));
    }
    // C-6: a field outside the allow-list
    {
        let mut run_json = a.bundle.run_json.clone();
        while run_json.last().map(|c| c.is_ascii_whitespace()).unwrap_or(false) {
            run_json.pop();
        }
        run_json.pop();
        run_json.extend_from_slice(b",\"histogram_values\":[1,2,3]}");
        control(rec, name, "C-6 off-list-field", allow_list(&[("run.json", run_json.as_slice())]));
    }
}

/// the gate at one W16 profile: the layout checks at the proved shape, the
/// definitions, the pre-W16 control, and (when `capture`) one or two
/// captured runs with their checks and controls
fn gate_at(rec: &mut Record, profile: &str, pair: bool) {
    let name = shape::accuracy_spec(profile).expect("a W16 profile").name;
    // the shape the captured run proves (its gate denominator is the
    // synthetic data's, so its range families are THAT shape's)
    let (sh, _, _) = w16_case(profile, 0);
    let lay = Layout::for_shape(&sh).expect("the W16 layout");
    if layout_checks(rec, name, &lay).is_none() {
        return;
    }
    rec.put(name, "PG-5 definitions", definitions_match(&sh));
    // C-1: the index as it stood before this re-check refuses a W16 layout
    control(rec, name, "C-1 pre-W16-index", plane_index::build_with(&lay, false).map(|i| format!("{} A / {} H planes", i.a.len(), i.h.len())));
    let a = match prove_and_capture(profile, 0) {
        Ok(c) => c,
        Err(e) => {
            rec.put(name, "PG-6 capture", Err(e));
            return;
        }
    };
    if a.sh != sh {
        rec.put(name, "PG-6 capture", Err("the captured run is not at the layout-checked shape".into()));
        return;
    }
    let b = if pair { Some(prove_and_capture(profile, 1)) } else { None };
    match &b {
        Some(Ok(b)) => capture_checks(rec, name, &a, Some(b)),
        Some(Err(e)) => {
            capture_checks(rec, name, &a, None);
            rec.put(name, "PG-10 input-independent-shape", Err(format!("the second capture: {e}")));
        }
        None => capture_checks(rec, name, &a, None),
    }
    capture_controls(rec, name, &a, b.as_ref().and_then(|r| r.as_ref().ok()));
}

// ---------------------------------------------------------------- the tests

/// **THE W16 DEVELOPMENT RUNG** (`W16_RUNG_H24`): every check, two captured
/// runs (two hidden inputs), the controls, and the R13 additivity control.
#[test]
fn w16_privacy_gate_at_the_development_rung() {
    let mut rec = Record::default();
    gate_at(&mut rec, shape::W16_RUNG_H24, true);
    // additivity: at every R13 profile and the legacy rungs the index is the
    // same table with and without the W16 additions
    rec.put("R13+legacy", "A-1 index-unchanged", (|| {
        let mut shapes = super::accuracy_profile_tests::registered_shapes();
        shapes.extend([Shape::toy(), Shape::rung_g(), Shape::rung_k4()]);
        let mut built = 0;
        for s in &shapes {
            let l = Layout::for_shape(s)?;
            let (x, y) = (plane_index::build_with(&l, true).map(|i| i.render()), plane_index::build_with(&l, false).map(|i| i.render()));
            if x != y {
                return Err(format!("{}: the index moved", s.name));
            }
            built += usize::from(x.is_ok());
        }
        Ok(format!("{} shapes ({built} with an index), each byte-identical with and without the W16 additions", shapes.len()))
    })());
    rec.assert_all();
}

/// **THE TWO TRAINED T128 SHAPES**, by name (`HL_W16PG_PROFILES`, default
/// both; `HL_W16PG_PAIR=1` adds the second capture for PG-10). Heavy: a full
/// one-block W16 run per capture at the trained geometry, on the CPU. Run
/// alone, guarded.
#[test]
#[ignore = "heavy: full W16 T128 runs captured on the CPU; run by name, guarded"]
fn w16_privacy_gate_at_the_trained_t128_shapes() {
    let want = std::env::var("HL_W16PG_PROFILES").unwrap_or_else(|_| "W16_SHIELD_T128_H24,W16_8B_T128_H24".into());
    let pair = std::env::var("HL_W16PG_PAIR").map(|v| v == "1").unwrap_or(false);
    let mut rec = Record::default();
    for spec in shape::W16_PROFILES.iter().filter(|s| want.split(',').any(|w| w == s.name)) {
        let t0 = std::time::Instant::now();
        gate_at(&mut rec, spec.profile, pair);
        eprintln!("W16-PG {} done ({:.0} s wall, shared Mac, not a timing)", spec.name, t0.elapsed().as_secs_f64());
    }
    assert!(!rec.0.is_empty(), "HL_W16PG_PROFILES names no W16 profile");
    rec.assert_all();
}

// ---------------------------------------------------------------- the Metal path (2026-11-01, m24pg)

/// the holder [`leaves`] gives an array reference's `arrays.bin` offset
#[cfg(feature = "gpu-metal")]
const STORE_OFFSET: &str = "<arrays.bin offset of an array reference>";

/// one JSON document's VALUES in order, each with the key that holds it (the
/// object key it is the value of, or the key of the array it sits in). A
/// value is a scalar, or a whole innermost array of scalars: a digest is
/// written as 32 byte values and an `Fp2` as a pair, and one random byte of a
/// digest equals its counterpart in another run one time in 256, so a digest
/// is compared whole (found on the first Metal run, 2026-11-01).
///
/// One value is relabelled, not compared: the `offset` of an array reference
/// `{"array":<sha256>,"elem","len","offset","bytes"}` is a POSITION in
/// `arrays.bin`, and the store writes identical arrays once, so the offset of
/// every later array moves whenever a run's column queries repeat an index
/// (256 queries into 2^16 encoded columns repeat about once in two runs; the
/// two copies are one column, byte-identical). It is held by [`STORE_OFFSET`];
/// every array is still compared by its content digest. Found on the first
/// 8B T128 Metal run, 2026-11-01: a CPU run with three repeated H queries, one
/// with none, the Metal run with one.
#[cfg(feature = "gpu-metal")]
fn leaves(b: &[u8]) -> Result<Vec<(String, &[u8])>, String> {
    let mut out: Vec<(String, &[u8])> = Vec::new();
    let mut holders: Vec<String> = Vec::new();
    // per open container: (is an array, holds a container, first value's
    // index, its opening position, is an array reference: None before its first key)
    let mut frames: Vec<(bool, bool, usize, usize, Option<bool>)> = Vec::new();
    let mut key: Option<String> = None;
    let mut i = 0usize;
    while i < b.len() {
        match b[i] {
            b'{' | b'[' => {
                if let Some(f) = frames.last_mut() {
                    f.1 = true;
                }
                frames.push((b[i] == b'[', false, out.len(), i, None));
                let h = key.take().or_else(|| holders.last().cloned()).unwrap_or_default();
                holders.push(h);
                i += 1;
            }
            b'}' | b']' => {
                let (array, nested, first, open, _) = frames.pop().ok_or("unbalanced JSON")?;
                let h = holders.pop().ok_or("unbalanced JSON")?;
                if array && !nested && out.len() > first {
                    out.truncate(first);
                    out.push((h, &b[open..=i]));
                }
                i += 1;
            }
            b'"' => {
                let s = i;
                i += 1;
                while i < b.len() && b[i] != b'"' {
                    i += if b[i] == b'\\' { 2 } else { 1 };
                }
                i += 1;
                if i > b.len() {
                    return Err("an unterminated JSON string".into());
                }
                let tok = &b[s..i];
                let mut j = i;
                while j < b.len() && b[j].is_ascii_whitespace() {
                    j += 1;
                }
                if b.get(j) == Some(&b':') {
                    let mut name = String::from_utf8_lossy(&tok[1..tok.len() - 1]).into_owned();
                    if let Some(f) = frames.last_mut() {
                        if !f.0 {
                            let is_ref = *f.4.get_or_insert(name == "array");
                            if is_ref && name == "offset" {
                                name = STORE_OFFSET.to_string();
                            }
                        }
                    }
                    key = Some(name);
                    i = j + 1;
                } else {
                    let h = key.take().or_else(|| holders.last().cloned()).unwrap_or_default();
                    out.push((h, tok));
                }
            }
            c if c == b',' || c.is_ascii_whitespace() => i += 1,
            _ => {
                let s = i;
                while i < b.len() && !matches!(b[i], b',' | b']' | b'}') && !b[i].is_ascii_whitespace() {
                    i += 1;
                }
                let h = key.take().or_else(|| holders.last().cloned()).unwrap_or_default();
                out.push((h, &b[s..i]));
            }
        }
    }
    if !holders.is_empty() {
        return Err("unbalanced JSON".into());
    }
    Ok(out)
}

/// what a capture holds besides its files, as one more JSON document: the
/// statement tables the recorder replayed and the array store's counts
#[cfg(feature = "gpu-metal")]
fn capture_side(c: &Captured) -> Vec<u8> {
    let st: Vec<String> = c.bundle.statement.iter().map(|t| format!("{{\"stage\":{},\"slot\":{},\"nth\":{},\"what\":{:?},\"len\":{},\"sha256\":{:?}}}", t.stage, t.slot, t.nth, t.what, t.len, t.sha256)).collect();
    // (references written and arrays left inline; the distinct / deduplicated
    // counts and the blob length move with repeated column queries, see [`leaves`])
    let (_, s, _, inl, _) = c.bundle.arrays.stats();
    format!("{{\"statement\":[{}],\"arrays\":[{s},{inl}],\"blob_sha256\":{:?}}}", st.join(","), crate::export_v3::sha256_hex(c.bundle.arrays.blob())).into_bytes()
}

/// **MG-2: the Metal view against the CPU's, value by value** ([`leaves`]).
/// `cpu` are CPU-proved captures of ONE hidden input and `m` a Metal-proved
/// one (each a list of JSON documents). A run draws fresh OS randomness and
/// its endpoint owners cannot be cloned, so no two runs are byte-equal; what
/// CAN be asked is: every value the CPU runs reproduce under fresh randomness
/// is byte-equal on Metal, the values line up one to one under the same keys,
/// and Metal differs only where the CPU runs differ.
///
/// `cpu` holds THREE CPU captures in the test: a value counts as reproduced
/// only when all of them agree. Two were not enough (the first 8B T128 run
/// of attempt 2, 2026-11-01): the opened columns' query indices are written
/// in sorted order, so the index at one position is an order statistic in a
/// narrow window and two runs agree there about once in four 8B captures.
/// Three independent runs agree by chance only when two such coincidences
/// meet at one position.
#[cfg(feature = "gpu-metal")]
fn views_agree(cpu: &[&[Vec<u8>]], m: &[Vec<u8>]) -> Result<String, String> {
    if cpu.len() < 2 || cpu.iter().any(|c| c.len() != m.len()) {
        return Err(format!("{} CPU captures of {:?} documents against {}", cpu.len(), cpu.iter().map(|c| c.len()).collect::<Vec<_>>(), m.len()));
    }
    let show = |v: &[u8]| String::from_utf8_lossy(&v[..v.len().min(48)]).into_owned();
    // per key: values, reproduced, CPU/CPU differ, CPU/Metal differ
    let mut per: BTreeMap<String, [usize; 4]> = BTreeMap::new();
    let (mut total, mut repro, mut chance, mut offsets) = (0usize, 0usize, 0usize, 0usize);
    for k in 0..m.len() {
        let lc: Vec<Vec<(String, &[u8])>> = cpu.iter().map(|c| leaves(&c[k])).collect::<Result<_, _>>()?;
        let lz = leaves(&m[k])?;
        if lc.iter().any(|l| l.len() != lz.len()) {
            return Err(format!("document {k}: {:?} CPU values against {} on Metal", lc.iter().map(|l| l.len()).collect::<Vec<_>>(), lz.len()));
        }
        for (i, r) in lz.iter().enumerate() {
            let p = &lc[0][i];
            if lc.iter().any(|l| l[i].0 != r.0) {
                return Err(format!("document {k} value {i}: held by {:?} on the CPU, {:?} on Metal", lc.iter().map(|l| l[i].0.clone()).collect::<Vec<_>>(), r.0));
            }
            if p.0 == STORE_OFFSET {
                offsets += 1;
                continue;
            }
            let e = per.entry(p.0.clone()).or_default();
            e[0] += 1;
            total += 1;
            if lc.iter().all(|l| l[i].1 == p.1) {
                e[1] += 1;
                repro += 1;
                if r.1 != p.1 {
                    return Err(format!("document {k} value {i} (key {:?}): {} CPU runs reproduce {} under fresh randomness, the Metal view has {}", p.0, cpu.len(), show(p.1), show(r.1)));
                }
            } else {
                e[2] += 1;
                if r.1 != p.1 {
                    e[3] += 1;
                } else {
                    chance += 1;
                }
            }
        }
    }
    let moved: Vec<String> = per.iter().filter(|(_, v)| v[2] > 0).map(|(k, v)| format!("{k} {}/{}", v[3], v[0])).collect();
    let cpu_only: Vec<&String> = per.iter().filter(|(_, v)| v[2] > 0 && v[3] == 0).map(|(k, _)| k).collect();
    let differ: usize = per.values().map(|v| v[3]).sum();
    Ok(format!(
        "{total} values (scalars and innermost scalar arrays: digests, Fp2 pairs) in {} documents line up one to one under the same keys, plus {offsets} arrays.bin offsets of array references (storage positions, not compared; each array is compared by its content digest); {repro} are reproduced by all {} CPU runs under fresh randomness and every one is byte-equal on Metal; {differ} differ CPU/Metal, all at values that also differ between CPU runs ({chance} CPU-differing values happen to equal on Metal); keys whose values move with the randomness (CPU/Metal differing / values): {}{}",
        m.len(),
        cpu.len(),
        moved.join(", "),
        if cpu_only.is_empty() { String::new() } else { format!("; keys that moved CPU/CPU but never CPU/Metal: {cpu_only:?}") }
    ))
}

/// one seeded accuracy-stack core proof's digest (the recipe of
/// `slot_ir::accuracy::tests::seeded_accuracy_digest`, its own seed): the
/// prover with its randomness FIXED, so CPU and Metal must give equal bytes
#[cfg(feature = "gpu-metal")]
fn seeded_core_digest(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<String, String> {
    let lay = Layout::for_shape(sh)?;
    let (rows, n) = (sh.endpoint_rows, 1usize << sh.endpoint_log_n);
    let ids = Ids::new(sh)?;
    let io = |p: usize| -> Vec<Fp> {
        let mut d = vec![Fp::ZERO; rows * n];
        for (i, v) in w.planes[p].iter().enumerate().take(d.len()) {
            d[i] = Fp::from_i64(*v);
        }
        d
    };
    let (ein, eout) = (io(ids.at(A_X)), io(ids.at(A_X2)));
    let ntt = crate::ntt::NttTables::new(super::protocol::ntt_log_at(sh));
    let mut rng = crate::zk::ZkRng::new(20261101, b"zk60 w16 privacy gate metal");
    let mut tr = Transcript::new(b"zk60 w16 privacy gate metal");
    tr.absorb(b"profile", sh.profile.as_bytes());
    tr.absorb(b"schedule", &lay.schedule_digest());
    let mut ph = super::timing::Phases::start();
    let (mut phases, mut tick) = (Vec::new(), std::time::Instant::now());
    let core = super::protocol::prove_core(sh, &lay, blk, w, [ein.as_slice(), eout.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?;
    let text = format!(
        "{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}|{:?}",
        core.a_root, core.h_root, core.mask_root, core.slots, core.mask_open, core.a_open, core.h_open, core.io_claims, core.order, core.lookups, tr.state()
    );
    Ok(blake3::hash(text.as_bytes()).to_hex().to_string())
}

/// the gate on the Metal path at one W16 profile: three CPU captures and one
/// Metal capture of the SAME hidden input (seed 0), the seeded prover's
/// bytes on both, every capture check and control on the Metal view, and the
/// Metal view against the CPU's (MG-2, MG-3)
#[cfg(feature = "gpu-metal")]
fn metal_gate_at(rec: &mut Record, profile: &str) {
    let name = shape::accuracy_spec(profile).expect("a W16 profile").name;
    let mname = format!("{name}@metal");
    std::env::remove_var("HL_GPU");
    let (sh, blk, w) = w16_case(profile, 0);
    let cpu_digest = seeded_core_digest(&sh, &blk, w.clone());
    let (a, a2, a3) = (prove_and_capture(profile, 0), prove_and_capture(profile, 0), prove_and_capture(profile, 0));
    let declines0 = crate::gpu::declines();
    let (sc0, n0) = (crate::gpu::metal_sumcheck_stats().1, crate::gpu::metal_stats().0);
    std::env::set_var("HL_GPU", "1");
    let live = crate::gpu::enabled();
    let label = crate::gpu::label();
    let metal_digest = seeded_core_digest(&sh, &blk, w);
    let (sc1, n1) = (crate::gpu::metal_sumcheck_stats().1, crate::gpu::metal_stats().0);
    let m = prove_and_capture(profile, 0);
    std::env::remove_var("HL_GPU");
    let (sc2, n2) = (crate::gpu::metal_sumcheck_stats().1, crate::gpu::metal_stats().0);
    let declines = crate::gpu::declines() - declines0;
    rec.put(&mname, "MG-0 device", if live && sc1 > sc0 && n1 > n0 && sc2 > sc1 && n2 > n1 && declines == 0 {
        Ok(format!("{label}; the seeded proof ran {} commitments and {:.3} s of sumcheck rounds on the device, the captured run {} commitments and {:.3} s; 0 declines", n1 - n0, sc1 - sc0, n2 - n1, sc2 - sc1))
    } else {
        Err(format!("the device did not carry both proofs (live {live}, {label}; seeded {} commitments / {:.3} s, run {} / {:.3} s, {declines} declines)", n1 - n0, sc1 - sc0, n2 - n1, sc2 - sc1))
    });
    rec.put(&mname, "MG-1 seeded-bytes", match (&cpu_digest, &metal_digest) {
        (Ok(c), Ok(g)) if c == g => Ok(format!("the seeded core proof at this shape and hidden input digests to {} on the CPU and on Metal", &c[..16])),
        (Ok(c), Ok(g)) => Err(format!("the seeded core proof differs: cpu {} metal {}", &c[..16], &g[..16])),
        (c, g) => Err(format!("the seeded core proof failed: cpu {:?} metal {:?}", c.as_ref().err(), g.as_ref().err())),
    });
    let (a, a2, a3, m) = match (a, a2, a3, m) {
        (Ok(a), Ok(a2), Ok(a3), Ok(m)) => (a, a2, a3, m),
        (a, a2, a3, m) => {
            rec.put(&mname, "PG-6 capture", Err(format!("a capture failed: cpu {:?} cpu {:?} cpu {:?} metal {:?}", a.err(), a2.err(), a3.err(), m.err())));
            return;
        }
    };
    if m.sh != sh || a.sh != sh {
        rec.put(&mname, "PG-6 capture", Err("a captured run is not at the case's shape".into()));
        return;
    }
    // every capture-level check and control on the Metal-proved view
    capture_checks(rec, &mname, &m, None);
    capture_controls(rec, &mname, &m, Some(&a));
    // MG-2 / MG-3: the Metal view against the CPU's
    let docs = |c: &Captured| -> Vec<Vec<u8>> { bundle_files(&c.bundle).into_iter().chain(std::iter::once(capture_side(c))).collect() };
    let (da, da2, da3, dm) = (docs(&a), docs(&a2), docs(&a3), docs(&m));
    let cpu: [&[Vec<u8>]; 3] = [&da, &da2, &da3];
    rec.put(&mname, "MG-2 view-vs-cpu", views_agree(&cpu, &dm));
    rec.put(&mname, "MG-3 structure-vs-cpu", same_structure(sh.n_slots(), &bundle_files(&a.bundle), &seg_lens(&a), &bundle_files(&m.bundle), &seg_lens(&m)).map(|d| format!("the same hidden input on the CPU and on Metal: {d}")));
    // C-7: one reproducible leaf of the Metal stage file changed is seen
    {
        let s = String::from_utf8(dm[1].clone()).expect("a UTF-8 stage file");
        let at = s.find("\"log_size\":").expect("a log_size") + "\"log_size\":".len();
        let end = at + s[at..].find(|c: char| !c.is_ascii_digit()).expect("a number");
        let v: u64 = s[at..end].parse().expect("a number");
        let mut doctored = dm.clone();
        doctored[1] = format!("{}{}{}", &s[..at], v + 1, &s[end..]).into_bytes();
        control(rec, &mname, "C-7 doctored-metal-leaf", views_agree(&cpu, &doctored));
    }
    // C-8: a reproducible array's content digest changed in the Metal stage
    // file is seen (the offsets are not compared; the digests are)
    {
        let s = String::from_utf8(dm[1].clone()).expect("a UTF-8 stage file");
        let (sa, sa2) = (String::from_utf8_lossy(&da[1]).into_owned(), String::from_utf8_lossy(&da3[1]).into_owned());
        let pat = "{\"array\":\"";
        let mut from = 0usize;
        let mut hit = None;
        while let Some(p) = s[from..].find(pat) {
            let at = from + p + pat.len();
            let sha = &s[at..at + 64];
            if sa.contains(sha) && sa2.contains(sha) {
                hit = Some(at);
                break;
            }
            from = at;
        }
        let r = match hit {
            Some(at) => {
                let flipped = if &s[at..at + 1] == "0" { "1" } else { "0" };
                let mut doctored = dm.clone();
                doctored[1] = format!("{}{}{}", &s[..at], flipped, &s[at + 1..]).into_bytes();
                views_agree(&cpu, &doctored)
            }
            None => Ok("no reproducible array reference to doctor".into()),
        };
        control(rec, &mname, "C-8 doctored-array-digest", r);
    }
}

/// **THE W16 GATE ON THE METAL PATH** (`HL_W16PG_PROFILES`, default the
/// rung): per profile, three CPU captures and one Metal capture of one hidden
/// input; MG-0 the device carried the proofs, MG-1 the seeded prover's bytes
/// are equal on both, PG-6 .. PG-9 and the controls on the Metal view, MG-2
/// the Metal view against the CPU's leaf by leaf, MG-3 its structure. Toggles
/// `HL_GPU` in-process: run alone by name with `HL_GPU_REQUIRED=1`, guarded.
#[cfg(feature = "gpu-metal")]
#[test]
#[ignore = "toggles HL_GPU in-process; run alone by name on a Mac with HL_GPU_REQUIRED=1, guarded"]
fn w16_privacy_gate_on_the_metal_path() {
    assert!(crate::gpu::required(), "run with HL_GPU_REQUIRED=1, so that no device decline falls back to the CPU unseen");
    let want = std::env::var("HL_W16PG_PROFILES").unwrap_or_else(|_| "W16_RUNG_H24".into());
    let mut rec = Record::default();
    for spec in shape::W16_PROFILES.iter().filter(|s| want.split(',').any(|w| w == s.name)) {
        let t0 = std::time::Instant::now();
        metal_gate_at(&mut rec, spec.profile);
        eprintln!("W16-PG {}@metal done ({:.0} s wall, shared Mac, not a timing)", spec.name, t0.elapsed().as_secs_f64());
    }
    assert!(!rec.0.is_empty(), "HL_W16PG_PROFILES names no W16 profile");
    rec.assert_all();
}

/// **THE W16 GATE BUNDLES ON DISK**, the input of the Python gate's W16
/// items: per profile in `HL_W16PG_PROFILES` (default the rung), one honest
/// one-block run per hidden input (seeds 0 and 1), captured as
/// `prove_and_capture` does and written by `run_capture::write_bundle` into
/// `HL_W16PG_CAPTURE_DIR/<shape>-s<seed>`, with the plane index the recorder
/// checked in `run.json`. The path (CPU, or Metal under `HL_GPU=1`) is the
/// caller's and is named in the README. Test-only bundles; delete them once
/// recorded.
#[test]
#[ignore = "writes the W16 gate bundles; set HL_W16PG_CAPTURE_DIR"]
fn w16_privacy_gate_write_the_w16_bundles() {
    let root = std::path::PathBuf::from(std::env::var("HL_W16PG_CAPTURE_DIR").expect("HL_W16PG_CAPTURE_DIR is not set: this test writes a directory of evidence and will not choose one for you"));
    let want = std::env::var("HL_W16PG_PROFILES").unwrap_or_else(|_| "W16_RUNG_H24".into());
    let mut n = 0usize;
    for spec in shape::W16_PROFILES.iter().filter(|s| want.split(',').any(|w| w == s.name)) {
        for seed in [0usize, 1] {
            let c = prove_and_capture(spec.profile, seed).unwrap_or_else(|e| panic!("{} seed {seed}: {e}", spec.name));
            let dir = root.join(format!("{}-s{seed}", spec.name.to_ascii_lowercase()));
            let note = format!(
                "W16 privacy gate fixture (D54 re-check): one honest one-block run at the W16 block profile `{}` under the TEST-ONLY run identity `{}`, public synthetic weights (`range16_tests::case`), a hidden synthetic input from seed {seed} (`w16_privacy_gate_tests::w16_case`); proved on this path: {}. Test-only: delete once recorded.",
                spec.profile,
                run_profile_of(spec.profile),
                crate::gpu::label()
            );
            run_capture::write_bundle(&dir, &c.bundle, &c.segs, &note, "HL_W16PG_CAPTURE_DIR=<dir> [HL_W16PG_PROFILES=<names>] <hashline lib test binary> --ignored --exact --nocapture private_block::w16_privacy_gate_tests::w16_privacy_gate_write_the_w16_bundles").unwrap_or_else(|e| panic!("{} seed {seed}: {e}", spec.name));
            eprintln!("W16-PG-BUNDLE {} seed {seed} -> {} ({} stage bytes, segments {:?} B)", spec.name, dir.display(), c.bundle.stages.iter().map(|s| s.len()).sum::<usize>(), seg_lens(&c));
            n += 1;
        }
    }
    assert!(n > 0, "HL_W16PG_PROFILES names no W16 profile");
}
