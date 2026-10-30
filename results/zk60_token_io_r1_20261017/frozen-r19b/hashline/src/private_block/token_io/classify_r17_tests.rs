//! **TOKEN I/O ROUND 17: R13 CLASSIFIER CAPTURES FROM A FROZEN TOKEN TREE.**
//! TEST CODE ONLY. A child of the adopted gate-19 hooks
//! (`gate19_capture_tests.rs`, registered by one `#[path]` line at its end),
//! so these tests read its R13-rung helpers (`r13_bind`, `r13_honest_run`,
//! `check_bundle_19`) directly.
//!
//! Gate round 19 (`results/zk60_gate_tinyllama_20261017/round19/R19_SUMMARY.md`
//! §7) found that the token recorder as frozen at r16b cannot record ANY R13
//! run (R19-PIN-1: `plane_index.rs` names the A planes from the legacy table,
//! 79 names for 109 planes at LOW + h24, and its DZC / FZC push ranges are
//! short at R13) and that an R13-rung classifier bundle was written under the
//! TOKEN schema without the classifier pins (F19-1). The gate patched its own
//! copy (H19-3, H19-4). These tests were written FIRST and run against the
//! unpatched recorder (frozen-r16b's bytes), where both fail:
//!
//! * [`r17_the_plane_index_builds_at_an_r13_shape_from_the_accuracy_layout`]:
//!   the plane index builds at every stage shape of a two-stage R13 rung run
//!   (two gate denominators), names exactly `Ids`' independently counted A
//!   planes with the accuracy layout's names and domains, and the four R13
//!   zero-check slots (DZC, QZC, KVZC, FZC) list every A plane of their domain;
//! * [`r17_an_r13_rung_classify_run_is_recorded_under_the_classifier_schema`]:
//!   an honest R13 rung classifier run is recorded (the recorder's own
//!   cross-check of every slot's private-table push order passes), its bundle
//!   is a classifier bundle, and the written manifest declares the classifier
//!   schema and pins the classifier and R13 sources.
//!
//! Then the round's table values (gate round 19's first declared limit: the
//! real capture carried no public-table values, so v22 left the twelve block
//! slots 5-7, 10-16, 18, 19 open):
//!
//! * [`r17_an_r13_capture_with_table_values_records_every_statement_table_and_replays_it_against_the_export`]:
//!   with `public_tables` on, every public table of every stage carries its
//!   values (v22 requires them at IN-C / OUT-C when run.json says
//!   `public_tables_included: true`); per block stage the recorder lists the
//!   sixteen (seventeen when `Dom::Tab` pads) STATEMENT tables of the twelve
//!   slots; the bundle is NOT written until `run_capture::export_replay` has
//!   derived each again from the export's layer and found it byte-equal; then
//!   it is, with the replay in its README;
//! * [`r17_a_recorded_table_that_disagrees_with_the_export_is_refused_by_the_replay`]:
//!   nine one-datum doctorings of either layer of the export (a gain, a weight
//!   of Wq or Wd, a RoPE sine, an exp entry, an output or gate multiplier, a
//!   group id) are each refused by the replay, naming the predicted stage and
//!   slot, and no bundle is written; on the RECORDED side, each of the run's
//!   34 statement tables (17 kinds) recorded with another table's digest is
//!   refused naming exactly that table; an export layer that does not load is
//!   refused by name; the honest export then passes on the same bundle.

use super::*;
use crate::private_block::layout::{Dom, Layout, SC_DZC, SC_FZC, SC_KVZC, SC_QZC};
use crate::private_block::plane_index::{self, Ref};

/// a fixture directory for one test, removed on drop
fn r17_fxdir(tag: &str) -> FxDir {
    let d = FxDir(fixture_root().join(format!("r17-{tag}-{}-{}", std::process::id(), FX_SEQ.fetch_add(1, std::sync::atomic::Ordering::SeqCst))));
    let _ = std::fs::remove_dir_all(&d.0);
    std::fs::create_dir_all(&d.0).unwrap();
    d
}

#[test]
fn r17_the_plane_index_builds_at_an_r13_shape_from_the_accuracy_layout() {
    let fxdir = r17_fxdir("t1");
    let fx = r13_bind(&fxdir.0, &policy_rung_dev(), 2);
    let shapes: Vec<BlockShape> = fx.model.layers.iter().map(|r| r.shape_at(&fx.seed).unwrap()).collect();
    assert_eq!(shapes.len(), 2);
    assert_ne!(shapes[0].accuracy_gate_shift, shapes[1].accuracy_gate_shift, "the two stages carry different gate denominators");
    for (k, sh) in shapes.iter().enumerate() {
        let lay = Layout::for_shape(sh).unwrap();
        let low = lay.ids().accuracy().expect("an R13 stage shape has the accuracy layout");
        let idx = plane_index::build(&lay).unwrap_or_else(|e| panic!("stage {k} (G {}): the plane index does not build at an R13 shape (R19-PIN-1): {e}", sh.accuracy_gate_shift));
        assert_eq!(idx.a.len(), lay.ids().n_a(), "stage {k}: the index's A planes are not `Ids`' count");
        assert_eq!(idx.a.len(), low.names.len(), "stage {k}: the index's A planes are not the accuracy layout's");
        let mut seen = std::collections::HashSet::new();
        for (p, (nm, d)) in idx.a.iter().zip(low.names.iter().zip(low.doms.iter())) {
            assert_eq!(p.name, format!("A_{nm}"), "stage {k}: A plane {} is misnamed", p.id);
            assert_eq!(p.dom, *d, "stage {k}: A plane {} ({}) carries another domain", p.id, p.name);
            assert!(seen.insert(p.name.clone()), "stage {k}: the A plane name {} occurs twice", p.name);
        }
        for (slot, dom) in [(SC_DZC, Dom::D), (SC_QZC, Dom::Q), (SC_KVZC, Dom::Kv), (SC_FZC, Dom::F)] {
            let r = lay.ids().domain_range(dom).unwrap();
            let listed: Vec<usize> = idx.slots[slot].iter().filter_map(|x| if let Ref::A(i) = x { Some(*i) } else { None }).collect();
            for p in r.clone() {
                assert!(listed.contains(&p), "stage {k}: R13 slot {slot} does not list A plane {p} ({}) of its domain {dom:?}", idx.a[p].name);
            }
        }
        eprintln!(
            "R17 PLANE INDEX stage {k} G {}: {} A planes (accuracy layout names), {} H planes; R13 slots DZC / QZC / KVZC / FZC list {} / {} / {} / {} planes",
            sh.accuracy_gate_shift,
            idx.a.len(),
            idx.h.len(),
            idx.slots[SC_DZC].len(),
            idx.slots[SC_QZC].len(),
            idx.slots[SC_KVZC].len(),
            idx.slots[SC_FZC].len()
        );
    }
}

#[test]
fn r17_an_r13_rung_classify_run_is_recorded_under_the_classifier_schema() {
    let fxdir = r17_fxdir("t3");
    let r = r13_honest_run(&fxdir.0, 2, "1", None);
    let bundle = capture(&r.st, &r.blocks, &r.bound, &r.segs, CaptureOpts { arrays: true, public_tables: false }).unwrap_or_else(|e| panic!("the recorder does not record an honest R13 classifier run: {e}"));
    let n_slots = r.st.stage_shape(0).unwrap().n_slots();
    check_bundle_19(&bundle, &r.st, &r.segs, &r.dec, 2, n_slots);
    assert!(run_capture::bundle_is_classify(&bundle), "F19-1: a bundle of the R13 rung classifier profile {} is not a classifier bundle", bundle.profile);
    let lay0 = Layout::for_shape(&r.st.stage_shape(0).unwrap()).unwrap();
    let n_a = lay0.ids().n_a();
    assert_eq!(count(&bundle.run_json, ",\"first_row\":"), n_a, "run.json's plane index does not list the R13 shape's {n_a} A planes");
    for nm in lay0.ids().accuracy().unwrap().names.iter() {
        assert!(contains(&bundle.run_json, &format!("\"name\":\"A_{nm}\",")), "run.json's plane index does not name the R13 A plane A_{nm}");
    }
    let dir = fxdir.0.join("bundle");
    run_capture::write_bundle(&dir, &bundle, &r.segs, "token round 17 test bundle", "cargo test (token round 17)").unwrap_or_else(|e| panic!("{e}"));
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    assert!(contains(&manifest, &format!("\"schema\":\"{SCHEMA}\"")), "F19-1: the manifest of an R13 rung classifier bundle does not declare the classifier schema");
    for f in ["src/private_block/token_io/classify.rs", "src/private_block/token_io/classify_run.rs", "src/private_block/argument_accuracy.rs"] {
        assert!(contains(&manifest, &format!("{{\"file\":\"{f}\",")), "the manifest does not pin {f}");
    }
    eprintln!("R17 R13 RUNG CAPTURE L=2 gates {:?} verdict {}: {}; manifest {} B", r.gates, r.st.verdict(), sizes_line(&bundle), manifest.len());
}

// ---------------------------------------------------------------- table values and the export replay

/// does every public table of this stage file that is not a shape table carry
/// its values? `(public tables, public tables with values)`
fn public_tables_with_values(stage: &[u8]) -> (usize, usize) {
    let key = b"{\"kind\":\"public\",\"len\":";
    let (mut n, mut with) = (0, 0);
    let mut i = 0;
    while let Some(off) = stage[i..].windows(key.len()).position(|w| w == key) {
        let at = i + off;
        n += 1;
        // `{"kind":"public","len":N,"sha256":"<64 hex>"` then `,"values":` or `}`
        let rest = &stage[at..];
        let sha = rest.windows(10).position(|w| w == b"\"sha256\":\"").expect("a public table carries its sha256");
        let after = sha + 10 + 64 + 1;
        if rest[after..].starts_with(b",\"values\":") {
            with += 1;
        }
        i = at + key.len();
    }
    (n, with)
}

/// a doctored copy of one layer of the export (one public datum moved), and
/// the slot whose statement table the replay must name
fn doctored(blk: &BlockPublic, case: &str) -> (BlockPublic, usize) {
    use crate::private_block::accuracy_public::AccuracyPublic;
    use crate::private_block::layout::{SC_DMM, SC_GMM, SC_QMM, SC_TAB, SC_WO};
    let bump = |x: i8| if x == 127 { 126 } else { x + 1 };
    let mut b = blk.clone();
    let a = blk.accuracy().expect("an R13 layer");
    let rebuilt = |m: crate::private_block::accuracy_public::Multipliers, ids: Vec<usize>| AccuracyPublic::new(a.stack(), a.geometry(), a.base(), a.member(), m, a.groups().to_vec(), ids, a.raw_tables().to_vec()).expect("a valid doctored accuracy datum");
    let slot = match case {
        "gamma_a" => {
            b.attention.gamma_a[0] = bump(b.attention.gamma_a[0]);
            SC_DZC
        }
        "gamma_m" => {
            b.feed_forward.gamma_m[3] = bump(b.feed_forward.gamma_m[3]);
            SC_DZC
        }
        "w_q" => {
            b.attention.wq[0] = bump(b.attention.wq[0]);
            SC_QMM
        }
        "w_d" => {
            b.feed_forward.wd_t[1] = bump(b.feed_forward.wd_t[1]);
            SC_DMM
        }
        "rope_sin" => {
            b.attention.rope_sin[1] += 1;
            SC_QZC
        }
        "exp" => {
            b.attention.exp[5] += 1;
            SC_TAB
        }
        "m_o" => {
            let mut m = a.multipliers().clone();
            m.o[2] = if m.o[2] > 1 { m.o[2] - 1 } else { m.o[2] + 1 };
            b = b.with_accuracy(rebuilt(m, a.group_ids().to_vec()));
            SC_WO
        }
        "m_g" => {
            let mut m = a.multipliers().clone();
            m.g[0] = if m.g[0] > 1 { m.g[0] - 1 } else { m.g[0] + 1 };
            b = b.with_accuracy(rebuilt(m, a.group_ids().to_vec()));
            SC_GMM
        }
        "group_id" => {
            // another registered group for channel 0; if the gate coefficients move
            // with it (c_j = m_j 2^(G - s_j)), the fold of w_g is the first table to differ
            let mut ids = a.group_ids().to_vec();
            ids[0] = (ids[0] + 1) % a.groups().len();
            let d = rebuilt(a.multipliers().clone(), ids);
            let moved = d.folds().gate.multipliers != a.folds().gate.multipliers;
            b = b.with_accuracy(d);
            if moved {
                SC_GMM
            } else {
                SC_FZC
            }
        }
        other => panic!("no doctoring case {other}"),
    };
    (b, slot)
}

#[test]
fn r17_an_r13_capture_with_table_values_records_every_statement_table_and_replays_it_against_the_export() {
    let fxdir = r17_fxdir("t4");
    let r = r13_honest_run(&fxdir.0, 2, "1", None);
    let mut bundle = capture(&r.st, &r.blocks, &r.bound, &r.segs, CaptureOpts { arrays: true, public_tables: true }).unwrap_or_else(|e| panic!("the recorder does not record an honest R13 run with table values: {e}"));
    let n_slots = r.st.stage_shape(0).unwrap().n_slots();
    check_bundle_19(&bundle, &r.st, &r.segs, &r.dec, 2, n_slots);
    assert!(contains(&bundle.run_json, "\"public_tables_included\":true,"), "run.json does not declare the values (gate v22 reads `public_tables_included`)");
    // the statement tables: per block stage the seven folds, two gains, two RoPE pairs, the group column, the exp
    // and ACT3 tables (+ the ACT support when Dom::Tab pads), at stages 1 and 2
    let stages: std::collections::BTreeSet<usize> = bundle.statement.iter().map(|t| t.stage).collect();
    assert_eq!(stages.into_iter().collect::<Vec<_>>(), vec![1, 2], "statement tables at the two block stages");
    let need = [(5, 0), (6, 0), (7, 0), (10, 0), (11, 0), (12, 0), (13, 0), (SC_DZC, 0), (SC_DZC, 1), (SC_QZC, 0), (SC_QZC, 1), (SC_KVZC, 0), (SC_KVZC, 1), (SC_FZC, 0), (19, 1), (19, 2)];
    for st in [1usize, 2] {
        let got: Vec<(usize, usize, &str)> = bundle.statement.iter().filter(|t| t.stage == st).map(|t| (t.slot, t.nth, t.what)).collect();
        for (s, n) in need {
            assert!(got.iter().any(|g| g.0 == s && g.1 == n), "stage {st}: statement table {n} of slot {s} is not recorded ({got:?})");
        }
        assert!(got.len() == need.len() || got.len() == need.len() + 1, "stage {st}: {} statement tables ({got:?})", got.len());
        assert!(got.iter().all(|g| [5, 6, 7, 10, 11, 12, 13, 14, 15, 16, 18, 19].contains(&g.0)), "stage {st}: a statement table outside the twelve slots gate v22 leaves open without values");
    }
    // every public table of every stage carries its values (v22 requires them at IN-C / OUT-C when the flag is true)
    for (k, s) in bundle.stages.iter().enumerate() {
        let (n, with) = public_tables_with_values(s);
        assert!(n > 0 && n == with, "stage {k}: {with} of {n} public tables carry values");
    }
    // NOT REPLAYED -> NOT WRITTEN
    let dir0 = fxdir.0.join("unreplayed");
    let e = run_capture::write_bundle(&dir0, &bundle, &r.segs, "token round 17 test bundle", "cargo test").expect_err("a bundle with statement-table values that were not replayed is written");
    assert!(e.contains("were not replayed against the export"), "{e}");
    assert!(!dir0.join("manifest.json").exists(), "a refused bundle left a manifest");
    // the replay against the fixture's layers (the blocks the run was proved with)
    let blocks = r.blocks.clone();
    let mut loads = Vec::new();
    let rep = run_capture::export_replay(&mut bundle, &mut |k| {
        loads.push(k);
        blocks.get(k).cloned().ok_or_else(|| format!("no layer {k}"))
    })
    .unwrap_or_else(|e| panic!("the honest run's statement tables do not replay against the export: {e}"));
    assert_eq!(loads, vec![0, 1], "the replay loads each layer exactly once, in order");
    assert_eq!((rep.tables, rep.blocks), (bundle.statement.len(), 2));
    let dir = fxdir.0.join("bundle");
    run_capture::write_bundle(&dir, &bundle, &r.segs, "token round 17 test bundle", "cargo test (token round 17)").unwrap_or_else(|e| panic!("{e}"));
    let readme = std::fs::read(dir.join("README.md")).expect("a README");
    assert!(contains(&readme, "EXPORT REPLAY (token round 17"), "the README does not say the statement tables were replayed");
    let manifest = std::fs::read(dir.join("manifest.json")).expect("a manifest");
    assert!(contains(&manifest, &format!("\"schema\":\"{SCHEMA}\"")), "the manifest does not declare the classifier schema");
    let arrays = std::fs::metadata(dir.join("arrays.bin")).map(|m| m.len()).unwrap_or(0);
    eprintln!(
        "R17 R13 CAPTURE WITH VALUES L=2 gates {:?}: {} statement tables replayed ({} entries, {} layers; {}), {}; arrays.bin {arrays} B",
        r.gates,
        rep.tables,
        rep.entries,
        rep.blocks,
        rep.per_kind.iter().map(|(k, n)| format!("{k} x{n}")).collect::<Vec<_>>().join(", "),
        sizes_line(&bundle)
    );
}

#[test]
fn r17_a_recorded_table_that_disagrees_with_the_export_is_refused_by_the_replay() {
    let fxdir = r17_fxdir("t5");
    let r = r13_honest_run(&fxdir.0, 2, "1", None);
    let mut bundle = capture(&r.st, &r.blocks, &r.bound, &r.segs, CaptureOpts { arrays: true, public_tables: true }).unwrap_or_else(|e| panic!("the capture: {e}"));
    for layer in [0usize, 1] {
        for case in ["gamma_a", "gamma_m", "w_q", "w_d", "rope_sin", "exp", "m_o", "m_g", "group_id"] {
            let (bad, slot) = doctored(&r.blocks[layer], case);
            let honest = r.blocks.clone();
            let e = run_capture::export_replay(&mut bundle, &mut |k| Ok(if k == layer { bad.clone() } else { honest[k].clone() })).expect_err(&format!("layer {layer} {case}: a table that disagrees with the export was not refused"));
            let stage = layer + 1;
            assert!(e.starts_with("replay: ") && e.contains("disagrees with the export"), "layer {layer} {case}: {e}");
            assert!(e.contains(&format!("stage {stage} (block {layer}) slot {slot} [")), "layer {layer} {case}: the refusal does not name stage {stage} slot {slot}: {e}");
            assert!(bundle.export_replay.is_none(), "a refused replay left a result behind");
            let dir = fxdir.0.join(format!("refused-{layer}-{case}"));
            let w = run_capture::write_bundle(&dir, &bundle, &r.segs, "test", "test").expect_err("a bundle whose replay was refused is written");
            assert!(w.contains("were not replayed against the export"), "{w}");
            eprintln!("R17 EXPORT REPLAY REFUSES layer {layer} {case}: {}", &e[..e.len().min(220)]);
        }
    }
    // the RECORDED side: every statement table, one at a time, recorded as if its values had been another table's
    // (its digest moved) -> the replay refuses exactly that table (the earlier ones are honest)
    let honest_list = bundle.statement.clone();
    let mut kinds = std::collections::BTreeSet::new();
    for i in 0..honest_list.len() {
        let t = honest_list[i].clone();
        let mut list = honest_list.clone();
        let c = if list[i].sha256.starts_with('0') { "1" } else { "0" };
        list[i].sha256.replace_range(0..1, c);
        bundle.statement = list;
        let e = run_capture::export_replay(&mut bundle, &mut |k| Ok(r.blocks[k].clone())).expect_err(&format!("statement table {i} ({}) recorded with another digest was not refused", t.what));
        let want = format!("stage {} (block {}) slot {} [{}] public table {} ({}) disagrees with the export", t.stage, t.block, t.slot, crate::private_block::layout::SLOT_NAMES[t.slot], t.nth, t.what);
        assert!(e.starts_with("replay: ") && e.contains(&want), "statement table {i}: the refusal does not name it ({want}): {e}");
        assert!(bundle.export_replay.is_none());
        kinds.insert(t.what);
    }
    bundle.statement = honest_list;
    assert_eq!(kinds.len(), 17, "every statement-table kind was refused once doctored: {kinds:?}");
    eprintln!("R17 EXPORT REPLAY REFUSES each of the {} recorded statement tables when its recorded digest moves ({} kinds: {:?})", bundle.statement.len(), kinds.len(), kinds);
    // an export of the wrong shape: a layer that does not load is refused by name
    let e = run_capture::export_replay(&mut bundle, &mut |k| if k == 1 { Err("no such layer file".into()) } else { Ok(r.blocks[k].clone()) }).expect_err("a missing export layer was accepted");
    assert!(e.contains("the export's layer 1 does not load: no such layer file"), "{e}");
    // and the honest export passes on the same bundle
    run_capture::export_replay(&mut bundle, &mut |k| Ok(r.blocks[k].clone())).unwrap_or_else(|e| panic!("the honest export: {e}"));
    assert!(bundle.export_replay.is_some());
}
