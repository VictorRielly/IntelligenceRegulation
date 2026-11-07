//! **D63 Lean lane L15 (2026-11-07): stage OUT-C's agreement corpus, from a REAL classifier receipt.** TEST ONLY: a
//! child of the test-only `classify_capture_tests` (declared there under `cfg(test)`), listed in `s25_tests`'s
//! `TEST_ONLY_FILES`. No prover or verifier source changes; nothing here is reachable from a production build.
//!
//! What it does, on the development rung's classifier fixture (`classify_capture_tests::fx`, one block, the R-C2 tables
//! derived from the pinned tensor, verdict 1):
//! 1. proves an honest classifier run (`honest_run`) and verifies it with the production `verify_classify_run` with the
//!    run capture's recorder attached (`capture`, public tables as their lengths and digests only);
//! 2. takes stage OUT-C's stage file from the bundle (`L + 1`): its LogUp challenges `γ, α` and its eight slot records
//!    (`run_capture::stage_slot`: the definition's draws, `c`, the scalar, the claimed sum, the rounds, the challenges,
//!    the sumcheck's final value, the mask value `g`, the terminal polynomial `fin − c·g`, the masked terminals, the
//!    hosted list, every table with its kind);
//! 3. writes them with the profile facts the stage's public tables are built from (the widths, the domain logs, the
//!    limb count, the verdict, `c`, the final norm's constants, the margin vector `w_Δ`, `TAG_U8`) to the file named by
//!    `LEAN_L15_CORPUS`, one record per line, for `formal/ZK60Formal/StageCheckOutC.lean` to recompute with its own
//!    executable closures and public tables.
//!
//! Every value is public: the fixture's public synthetic data, the public margin vector, the verdict, the receipt and
//! the transcript's challenges (no witness value, no mask coefficient, no RNG state is written).
use super::super::super::run_capture::CaptureOpts;
use super::super::classify::LAM_BASE;
use super::{capture, fx, honest_run};
use std::fmt::Write as _;

/// The JSON value (an array or an object) after the first `"key":` of `s`, brackets matched outside strings.
fn json_value<'a>(s: &'a str, key: &str) -> &'a str {
    let pat = format!("\"{key}\":");
    let start = s.find(&pat).unwrap_or_else(|| panic!("the stage file has no {key}")) + pat.len();
    let b = s.as_bytes();
    let (mut depth, mut in_str, mut esc) = (0i64, false, false);
    for (i, &c) in b.iter().enumerate().skip(start) {
        if in_str {
            if esc {
                esc = false;
            } else if c == b'\\' {
                esc = true;
            } else if c == b'"' {
                in_str = false;
            }
            continue;
        }
        match c {
            b'"' => in_str = true,
            b'[' | b'{' => depth += 1,
            b']' | b'}' => {
                depth -= 1;
                if depth == 0 {
                    return &s[start..=i];
                }
            }
            _ => {}
        }
    }
    panic!("the stage file's {key} is not terminated");
}

/// The top-level elements of a JSON array.
fn json_elems(arr: &str) -> Vec<&str> {
    let b = arr.as_bytes();
    assert!(b.first() == Some(&b'[') && b.last() == Some(&b']'), "not a JSON array");
    let (mut depth, mut in_str, mut esc, mut from) = (0i64, false, false, 1usize);
    let mut out = Vec::new();
    for i in 1..b.len() - 1 {
        let c = b[i];
        if in_str {
            if esc {
                esc = false;
            } else if c == b'\\' {
                esc = true;
            } else if c == b'"' {
                in_str = false;
            }
            continue;
        }
        match c {
            b'"' => in_str = true,
            b'[' | b'{' => depth += 1,
            b']' | b'}' => depth -= 1,
            b',' if depth == 0 => {
                out.push(arr[from..i].trim());
                from = i + 1;
            }
            _ => {}
        }
    }
    let last = arr[from..b.len() - 1].trim();
    if !last.is_empty() {
        out.push(last);
    }
    out
}

#[test]
fn lean_l15_export_the_classifier_stage_out_c_slots() {
    let f = fx(1);
    let r = honest_run(&f, "1", None);
    let b = capture(&r.st, &f.blocks, &r.bound, &r.segs, CaptureOpts { arrays: false, public_tables: false })
        .expect("a bundle for the accepted classifier run (production verify_classify_run with the recorder)");
    let l = f.blocks.len();
    assert_eq!(b.stages.len(), l + 2, "a classifier run has L + 2 stage files");
    let stage = std::str::from_utf8(&b.stages[l + 1]).expect("the stage file is UTF-8");
    assert!(stage.contains("\"stage_kind\":\"OUT-C\""), "stage L + 1 is stage OUT-C");
    let logup = json_value(stage, "logup_challenges");
    let args = json_elems(json_value(stage, "arguments"));
    assert_eq!(args.len(), 8, "stage OUT-C has eight slots");
    let cp = &r.st.cp;
    let verdict = r.st.verdict();
    let w = &r.bound.tables().w_delta;
    assert_eq!(w.len(), cp.d);
    let mut out = String::new();
    writeln!(out, "L15 OUTC {} L={l} slots={}", f.sh.name, args.len()).unwrap();
    writeln!(
        out,
        "PROFILE d={} dpad={} lt={} llo={} ldo={} ltab={} limbs={} lambase={} verdict={verdict} c={} ceps={} g0={} cn={} tn={} tag={}",
        cp.d,
        cp.d_pad,
        cp.tier.stage_log_n,
        cp.lo_log(),
        cp.do_log(),
        cp.tab_log(),
        cp.limbs,
        LAM_BASE,
        cp.policy.c,
        cp.norm.ceps,
        cp.norm.g0,
        cp.norm.cn,
        cp.norm.tn,
        crate::tables_attn::TAG_U8
    )
    .unwrap();
    writeln!(out, "WDELTA {}", w.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")).unwrap();
    writeln!(out, "LOGUP {logup}").unwrap();
    for a in &args {
        assert!(!a.contains('\n'));
        writeln!(out, "SLOT {a}").unwrap();
    }
    writeln!(out, "END {}", args.len()).unwrap();
    eprintln!(
        "LEAN-L15 | stage OUT-C of an accepted classifier run (rung, L = {l}, verdict {verdict}, margin {}): {} slots, corpus {} B",
        r.margin,
        args.len(),
        out.len()
    );
    if let Ok(path) = std::env::var("LEAN_L15_CORPUS") {
        std::fs::write(&path, &out).unwrap_or_else(|e| panic!("writing {path}: {e}"));
        eprintln!("LEAN-L15 | wrote {path}");
    }
}
