//! **G-7 SUB-LANE OF THE PRIVACY GATE (2026-10-19): THE TRAINED SLOT-IR
//! EXPORT.** Test-only and `#[ignore]`d; mounted as a child of
//! `slot_ir_tests` (itself `cfg(test)`), so no production build compiles a
//! byte of it and no pinned source changes.
//!
//! Stage 34's canonical export (`slot_ir::export_shape`) was written at the
//! nine registered development shapes only. Finding G-7 of the trained
//! TinyLlama T32 privacy draft asks for it at the TRAINED shape, because at
//! pg_rot1's constants (`sh_qkv = sh_g = 8`) the scaled top-limb lookup of
//! RQL / RKL / RVL / RGL has coefficient `2^(8 - 8) = 1` and is the same
//! lookup as the byte lookup of the same plane. This module:
//!
//! 1. reaches the shape through the TRAINED DOOR (`TrainedExport::load`,
//!    `run_constants` over all the export's layers, `shape_for`) and checks it
//!    equals `Shape::tinyllama_t32_trained(pg_calibration, 9)`;
//! 2. prints the duplicate-lookup census of `layout::lookups_at` at the
//!    trained shape and at its frozen structural twin, with the helper each
//!    duplicate lands in (helper `k` covers lookups `2k, 2k + 1`);
//! 3. builds the export from the shape (tame public tables, as stage 34 and
//!    `trained_calib_tests::ir_walk` do), twice, and requires the same bytes;
//! 4. at EVERY trained layer: loads the layer through the door (arrays
//!    verified), runs the stage-34 oracle (the IR evaluates to `define`'s
//!    closure at random points, built on that layer's real public statement)
//!    and requires the export built there to equal step 3's bytes;
//! 5. writes the trained export and the frozen twin's export into
//!    `HL_G7_OUT`.
//!
//! What the export contains is what stage 34's contains: per slot the table
//! list (kind, field, provenance, label), the node graph, the terms, public
//! integer coefficients with their values, challenge coefficients by
//! provenance only. **No witness is built anywhere in this module**, no table
//! payload and no claim point is written, nothing is proved or verified.
//! Nothing here is a privacy result.

use super::super::argument::{define, Ctx, Points};
use super::super::layout::*;
use super::super::shape::{Shape, TINYLLAMA_T32_TRAINED_PROFILE};
use super::super::slot_ir::{build_slot_ir, export_shape, IrPoints, SlotIr, EXPORT_SCHEMA};
use super::super::trained_block::TrainedExport;
use super::super::trained_calib_tests::{pg_calibration, T3_F_E};
use super::super::{AttentionPublic, FeedForwardPublic};
use super::{ctx_scalars, fp2_of, sha256_hex, xs};
use crate::field::Fp2;
use crate::transcript::Transcript;
use std::path::PathBuf;

const PG_ROT1_T32: &str = "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32";
/// the export's `shape` key (stage 34 uses the constructor's name)
const KEY_TRAINED: &str = "tl_t32_trained_pg_rot1";
const KEY_TWIN: &str = "tl_t32_dev";

fn out_dir() -> PathBuf {
    PathBuf::from(std::env::var("HL_G7_OUT").expect("HL_G7_OUT names the evidence directory"))
}

/// the IRs alone (the builder never reads `ctx.public` / `ctx.ff`; step 4
/// measures that rather than assuming it)
fn ir_only(sh: &Shape, lay: &Layout, public: &AttentionPublic, ff: &FeedForwardPublic) -> Vec<SlotIr> {
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay, public, ff, alpha, beta, g_u8, g_exp, g_act };
    let mut tr = Transcript::new(sh.profile.as_bytes());
    let mut pts = IrPoints::default();
    (0..N_SLOTS).map(|s| build_slot_ir(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s} IR: {e}", sh.name))).collect()
}

/// stage 34's twin walk and oracle on a GIVEN public statement: `define` and
/// the IR builder on two transcripts in the same state; per slot the table
/// counts agree, the IR is well formed, its max product degree is within the
/// declared degree, and the IR equals the closure at eight random points
fn oracle(sh: &Shape, lay: &Layout, public: &AttentionPublic, ff: &FeedForwardPublic, seed: u64) -> (usize, Vec<SlotIr>) {
    let (alpha, beta, g_u8, g_exp, g_act) = ctx_scalars();
    let ctx = Ctx { lay, public, ff, alpha, beta, g_u8, g_exp, g_act };
    let mut tr_def = Transcript::new(sh.profile.as_bytes());
    let mut tr_ir = Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    let mut ipts = IrPoints::default();
    let mut r = xs(seed);
    let mut n = 0usize;
    let mut irs = Vec::new();
    for s in 0..N_SLOTS {
        let def = define(s, &ctx, &mut pts, &mut tr_def).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        let ir = build_slot_ir(s, &ctx, &mut ipts, &mut tr_ir).unwrap_or_else(|e| panic!("{}: slot {s} IR: {e}", sh.name));
        assert_eq!(ir.tables.len(), def.tabs.len(), "{}: slot {s} [{}]: IR tables {} vs definition {}", sh.name, SLOT_NAMES[s], ir.tables.len(), def.tabs.len());
        ir.is_well_formed().unwrap_or_else(|e| panic!("{}: slot {s} [{}]: IR not well formed: {e}", sh.name, SLOT_NAMES[s]));
        assert!(ir.max_term_degree() <= ir.degree, "{}: slot {s}: product degree {} above the declared {}", sh.name, ir.max_term_degree(), ir.degree);
        for _ in 0..8 {
            let v: Vec<Fp2> = (0..def.tabs.len()).map(|_| fp2_of(&mut r)).collect();
            assert_eq!(ir.eval(&v), (def.poly)(&v), "{}: slot {s} [{}]: the IR and the closure differ", sh.name, SLOT_NAMES[s]);
            n += 1;
        }
        drop(def);
        irs.push(ir);
    }
    (n, irs)
}

/// every pair of IDENTICAL lookups of a domain (same terms, same constant),
/// with the helper each lands in: helper `k` covers lookups `(2k, 2k + 1)`
fn duplicate_census(sh: &Shape) -> Vec<String> {
    let ids = Ids::new(sh).unwrap_or_else(|e| panic!("{}: ids: {e}", sh.name));
    let names = super::super::plane_index::a_plane_names(sh);
    let mut out = Vec::new();
    for dom in LOOKUP_DOMS {
        let lks = lookups_at(sh, &ids, dom);
        for i in 0..lks.len() {
            for j in i + 1..lks.len() {
                if lks[i].terms == lks[j].terms && lks[i].cst == lks[j].cst {
                    let planes: Vec<String> = lks[i].terms.iter().map(|(p, c)| format!("{c} * {}", names[*p])).collect();
                    out.push(format!(
                        "{dom:?}: lookups {i} and {j} identical (cst {}, {}); helper {} and helper {}: {}",
                        lks[i].cst,
                        planes.join(" + "),
                        i / 2,
                        j / 2,
                        if i / 2 == j / 2 { "the SAME helper (one H plane, two identical denominators in its relation)" } else { "DIFFERENT helpers" }
                    ));
                }
            }
        }
    }
    out
}

#[test]
#[ignore = "G-7 sub-lane: writes the trained slot-IR export into HL_G7_OUT; run by name"]
fn g7_the_trained_t32_slot_ir_export_at_pg_rot1() {
    let out = out_dir();
    std::fs::create_dir_all(&out).expect("the evidence directory");
    let dir = std::env::var("HL_G7_EXPORT").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from(PG_ROT1_T32));

    // 1. the trained door
    let ex = TrainedExport::load(&dir).unwrap_or_else(|e| panic!("the trained door refuses {}: {e}", dir.display()));
    let layers = ex.layers.clone();
    let c = ex.run_constants(&layers).unwrap_or_else(|e| panic!("run constants over {layers:?}: {e}"));
    assert_eq!(c.cal, pg_calibration(), "the export's run calibration is not pg_rot1's");
    assert_eq!(c.f_e, T3_F_E, "f_e");
    let sh = ex.shape_for(&c).unwrap_or_else(|e| panic!("shape_for: {e}"));
    assert_eq!(sh.profile, TINYLLAMA_T32_TRAINED_PROFILE, "the door's profile");
    let built = Shape::tinyllama_t32_trained(&pg_calibration(), T3_F_E).expect("the constructor's shape");
    assert_eq!(sh, built, "the door's shape is not Shape::tinyllama_t32_trained(pg_calibration, 9)");
    eprintln!(
        "G7 door: variant {} from {}; {} layers {:?}; profile {}; T {} width {} hidden {} heads {} kv {}; tn {} cn_a {} cn_m {} ceps {}; sh_qkv {} sh_s {} sh_o {} sh_ao {} sh_g {} sh_h {} sh_z {}; norm_wrho {} (top limb full byte: {}); f_e {}; trained_calibration {}",
        ex.variant,
        dir.display(),
        layers.len(),
        layers,
        sh.profile,
        sh.tokens,
        sh.width,
        sh.hidden,
        sh.q_heads,
        sh.kv_heads,
        c.cal.tn,
        c.cal.cn_a,
        c.cal.cn_m,
        c.cal.ceps,
        sh.sh_qkv,
        sh.sh_s,
        sh.sh_o,
        sh.sh_ao,
        sh.sh_g,
        sh.sh_h,
        sh.sh_z,
        sh.norm_wrho,
        sh.norm_top_is_full_byte(),
        sh.f_e,
        sh.trained_calibration
    );

    // 2. the duplicate census, trained shape and frozen twin
    let twin = Shape::tinyllama_t32_dev();
    let (dups, twin_dups) = (duplicate_census(&sh), duplicate_census(&twin));
    for l in &dups {
        eprintln!("G7 duplicate [trained] {l}");
    }
    for l in &twin_dups {
        eprintln!("G7 duplicate [twin] {l}");
    }
    eprintln!("G7 duplicate census: trained {} identical pairs, twin {} (twin sh_qkv {} sh_g {})", dups.len(), twin_dups.len(), twin.sh_qkv, twin.sh_g);
    {
        let (ids, tids) = (Ids::new(&sh).unwrap(), Ids::new(&twin).unwrap());
        for dom in LOOKUP_DOMS {
            eprintln!(
                "G7 helpers {dom:?}: trained {} lookups -> {} helpers; twin {} lookups -> {} helpers",
                lookups_at(&sh, &ids, dom).len(),
                sh.helpers(dom),
                lookups_at(&twin, &tids, dom).len(),
                twin.helpers(dom)
            );
        }
    }

    // 3. the export from the shape (tame public tables), twice
    let lay = Layout::for_shape(&sh).unwrap_or_else(|e| panic!("layout: {e}"));
    let text = {
        let (pt, ft, _) = super::super::grow_tests::tame_case(&sh);
        let a = export_shape(KEY_TRAINED, &ir_only(&sh, &lay, &pt, &ft));
        let b = export_shape(KEY_TRAINED, &ir_only(&sh, &lay, &pt, &ft));
        assert_eq!(a, b, "the trained export is not the same on a second walk");
        a
    };
    assert!(text.contains(EXPORT_SCHEMA), "the export does not name its schema");
    assert!(!text.contains("\"value\":\"0+0u\"") || text.contains("\"prov\":\"kbase:0\""), "a zero value with no base provenance");

    // 4. every trained layer: arrays verified, oracle on its real statement,
    //    export equal to the shape's
    let mut points = 0usize;
    for &l in &layers {
        let (layer, how) = match ex.load_layer(&sh, &c, l, false) {
            Ok(x) => (x, "generator RoPE"),
            Err(e) => {
                eprintln!("G7 layer {l:02}: generator-RoPE load refused ({e}); retrying with the export's RoPE tables");
                (ex.load_layer(&sh, &c, l, true).unwrap_or_else(|e| panic!("layer {l}: {e}")), "export RoPE")
            }
        };
        let (n, irs) = oracle(&sh, &lay, layer.blk.attention(), layer.blk.feed_forward(), 0x6700_0000 + l as u64);
        points += n;
        let t = export_shape(KEY_TRAINED, &irs);
        assert_eq!(t, text, "layer {l}: the export built on this layer's public statement differs from the shape's");
        eprintln!("G7 layer {l:02}: arrays verified ({how}; {}), {n} oracle points equal, export equal", layer.rope_note);
    }
    eprintln!("G7 oracle: {} layers x 23 slots, {points} random points, IR == closure at every one", layers.len());

    // 5. the frozen twin's export, and both files
    let twin_text = {
        let tlay = Layout::for_shape(&twin).unwrap();
        let (pw, fw, _) = super::super::grow_tests::tame_case(&twin);
        export_shape(KEY_TWIN, &ir_only(&twin, &tlay, &pw, &fw))
    };
    for (name, body) in [(format!("slot_ir_{KEY_TRAINED}.json"), &text), (format!("slot_ir_{KEY_TWIN}.json"), &twin_text)] {
        let p = out.join(&name);
        std::fs::write(&p, body.as_bytes()).unwrap_or_else(|e| panic!("writing {}: {e}", p.display()));
        eprintln!("G7 export {name}: {} bytes, sha256 {}", body.len(), sha256_hex(body.as_bytes()));
    }
}
