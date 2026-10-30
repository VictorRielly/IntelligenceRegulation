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
