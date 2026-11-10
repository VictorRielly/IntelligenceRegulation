//! **D63 Lean lane L49 (2026-11-10), sub-agent `pub`: the VALUES of the host slots' public tables on a REAL R13 rung
//! block receipt, with the public data they are built from and the draws each was built from** (the R13 counterpart
//! of lane L47's `export_host`, `lean_l47_export_tests.rs`, which closed finding L44-E2 at the W16R2 rung). TEST
//! ONLY: a child of the test-only `private_block/w16r2_tests.rs` (declared there by one `#[cfg(test)]` line; the file
//! lives in `src/`, as lanes L44's and L47's do, so `s25_tests`' `TEST_ONLY_FILES` needs no entry). No prover or
//! verifier source changes; nothing here is reachable from a production build.
//!
//! At the R13 development rung (`shape::R13_RUNG_H24`), with `w16r2_tests`' seeded block harness (`rung_case`,
//! `prove`, `verify`, `header`), as lane L47's R13 export:
//! 1. proves one block CORE with the production `prove_core` and verifies it with the production `verify_core`;
//! 2. replays `verify_core`'s head (the `A` root, `M`, `beta`, `gamma`, `alpha`, the `H` root) and the slot loop (the
//!    production `define` and `run_slot`, `Side::Verify`, on the real transcript), recovering each slot's draws
//!    (`define` only squeezes: lane L11's recovery);
//! 3. writes the shape's numbers, the head slots, and the public data AS THE CODE STORES IT (`gamma_a`, `gamma_m`,
//!    `rope_cos`, `rope_sin`, the ACT group ids, the seven folding multipliers `accuracy_fold::coefficients`, and in
//!    the FULL record the seven weight matrices);
//! 4. writes every slot's draws and table counts, and every public table of every slot but the lookup side's `SC_TAB`
//!    (19) and `SC_ZS` (20) (lane L47 checked those): the host slots 0, 1, 4, 5, 6, 7, 10-18 and `SC_LZC`'s
//!    `supp(Dom::L)` (slot 3): length, two polynomial fingerprints `sum_i v_i rho^i` (at the fixed public points
//!    `rho = 7 + 3u`, `rho = 1234567 + 89u`), the first and last 64 entries, and in the FULL record every entry;
//! 5. writes, at the Shieldstral T128 R13 shape (`shape::R13_SHIELD_T128_H24`, no proof: a function of the shape
//!    alone), `pad::indicator_table(Dom::L)`, the table `B::supp` lays out for `SC_LZC` (its cube IS `Dom::L`);
//! 6. writes the FULL record to `$LEAN_L49_CORPUS` (outside the repository) and the record without the full tables and
//!    weights to `$LEAN_L49_CORPUS_SHORT`, for `formal/ZK60Formal/BlockR13HostExportCheck.lean` (against
//!    `R13H.Pub.pubsR13` and `R13H.Pub.restR13L`).
//!
//!
//! **Deliverable 4 of lane L49 (gap GB-6): ONE block of the app's Shieldstral-1.0-3B T128 R13 export**
//! (`lean_l49_export_a_shieldstral_block`, ignored: run alone, by name, through the resource guard, CPU only): the
//! production loader on the export, one layer's block proved by the production `prove_core` at
//! `R13_SHIELD_T128_H24` (the layer's own calibration) and accepted by `verify_core`, and the same record, the seven
//! folded weights at sampled indices with the weight columns they read, and the LogUp sum claim
//! (`export_shield_block`). The weights, the receipt and the full corpus stay outside the repository.
//!
//! Every value is public: the fixture's public synthetic data, the public model export, the transcript's challenges,
//! the verifier's tables.
use super::super::argument::{define, run_slot, Acc, Ctx, Points, Side, Tab};
use super::*;
use std::fmt::Write as _;

fn f2(x: &Fp2) -> String {
    format!("{},{}", x.c0.0, x.c1.0)
}

fn f2s(v: &[Fp2]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(f2).collect::<Vec<_>>().join(",")
    }
}

fn ints(v: &[i64]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

fn i8s(v: &[i8]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

fn u64s(v: &[u64]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

fn usizes(v: &[usize]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

/// `sum_i v_i rho^i` (Horner from the last entry)
fn fingerprint(v: &[Fp2], rho: Fp2) -> Fp2 {
    v.iter().rev().fold(Fp2::ZERO, |acc, x| acc.mul(rho).add(*x))
}

/// the two records: every line goes to both, a table's entries and the weights to the full one only
#[derive(Default)]
struct Out {
    full: String,
    short: String,
}

impl Out {
    fn both(&mut self, line: String) {
        writeln!(self.short, "{line}").unwrap();
        writeln!(self.full, "{line}").unwrap();
    }
    fn full_only(&mut self, line: String) {
        writeln!(self.full, "{line}").unwrap();
    }
    /// one public table: its length, two fingerprints, its ends; every entry in the full record
    fn table(&mut self, head: &str, v: &[Fp2], rho1: Fp2, rho2: Fp2) {
        let n = v.len();
        let e = ENDS.min(n);
        self.both(format!("{head} {n} FP {} {} HEAD {} TAIL {}", f2(&fingerprint(v, rho1)), f2(&fingerprint(v, rho2)), f2s(&v[..e]), f2s(&v[n - e..])));
        let full = head.replacen("PUB", "FULL", 1).replacen("SHIELDL", "FULLSHIELDL", 1);
        self.full_only(format!("{full} {n} {}", f2s(v)));
    }
}

/// the lookup side's slots `SC_TAB` and `SC_ZS`, whose tables lane L47 checked; every other slot's public tables are
/// written
const SKIP_SLOTS: [usize; 2] = [19, 20];

/// how many entries of each table's head and tail the corpus carries
const ENDS: usize = 64;

/// How a record carries the seven weight matrices: whole in the FULL record (the rung), or, for a block whose
/// matrices are too large for the Lean checker's interpreter (the Shieldstral block), the code's fold entries at a
/// sample of indices (the first 64, the last 64 before the padding, the last 64) with exactly the weight columns those
/// entries read (`WCOL`, FULL record only), so that the checker computes `pubsR13`'s entries there.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Weights {
    Whole,
    Sampled,
}

/// the matmul slots, whose public table is a folded weight
const FOLD_SLOTS: [usize; 7] = [5, 6, 7, 10, 11, 12, 13];

/// **One receipt's record**: the shape, the public data as the code stores it, `verify_core`'s head, every slot's
/// draws and table counts, and every public table of every slot but 19 and 20 (`PUB`; `FULL` in the full record).
/// Returns the number of tables and entries written.
fn host_record(out: &mut Out, head: String, sh: &Shape, blk: &BlockPublic, core: &CoreProof, weights: Weights) -> (usize, usize) {
    use super::super::accuracy_fold::{coefficients, Site};
    let lay = Layout::for_shape(sh).unwrap();
    let rho1 = Fp2::new(Fp::new(7), Fp::new(3));
    let rho2 = Fp2::new(Fp::new(1234567), Fp::new(89));
    out.both(head);
    out.both(format!("RHO {} {}", f2(&rho1), f2(&rho2)));
    out.both(format!(
        "SHAPE {} {} {} {} {} {} {} {} {} {} {}",
        sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.head_dim, sh.kv_heads, sh.t_pad, sh.d_pad, sh.f_pad, sh.h_pad, sh.q_pad()
    ));
    out.both(format!("LSIZE {}", sh.size(Dom::L)));
    let slots: Vec<usize> = (0..sh.q_heads).map(|h| sh.head_slot(h)).collect();
    out.both(format!("HEADSLOT {}", usizes(&slots)));
    let truth: Vec<usize> = (0..sh.h_pad).map(|s| usize::from(sh.slot_is_true_head(s))).collect();
    out.both(format!("TRUESLOT {}", usizes(&truth)));
    let (ap, ff) = (blk.attention(), blk.feed_forward());
    let data = blk.accuracy().expect("an R13 block carries accuracy data");
    out.both(format!("GAMA {} {}", ap.gamma_a.len(), i8s(&ap.gamma_a)));
    out.both(format!("GAMM {} {}", ff.gamma_m.len(), i8s(&ff.gamma_m)));
    out.both(format!("ROPECOS {} {}", ap.rope_cos.len(), ints(&ap.rope_cos)));
    out.both(format!("ROPESIN {} {}", ap.rope_sin.len(), ints(&ap.rope_sin)));
    out.both(format!("GROUPIDS {} {}", data.group_ids().len(), usizes(data.group_ids())));
    for (nm, site) in [("Q", Site::Q), ("K", Site::K), ("V", Site::V), ("O", Site::O), ("G", Site::Gate), ("U", Site::Up), ("D", Site::Down)] {
        let c = coefficients(sh, data, site).expect("the multipliers");
        out.both(format!("COEF {nm} {} {}", c.len(), u64s(&c)));
    }
    if weights == Weights::Whole {
        for (nm, m) in [("Q", &ap.wq), ("K", &ap.wk), ("V", &ap.wv), ("O", &ap.wo), ("G", &ff.wg_t), ("U", &ff.wu_t), ("D", &ff.wd_t)] {
            out.full_only(format!("WEIGHT {nm} {} {}", m.len(), i8s(m)));
        }
    }
    // `verify_core`'s head (protocol.rs, as lanes L11's, L44's and L47's exports replay it)
    let mut tr = header(sh, &lay);
    protocol::absorb_root(&mut tr, b"A", &core.a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &core.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(crate::tables_attn::TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(crate::tables_attn::TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(crate::tables_attn::TAG_ACT));
    protocol::absorb_root(&mut tr, b"H", &core.h_root, lay.h_rows, sh.log_cols);
    let g_dd = gamma.mul_base(Fp::new(TAG_DD));
    out.both(format!("LOGUP {} {} {}", f2(&beta), f2(&gamma), f2(&alpha)));
    if weights == Weights::Sampled {
        // the LogUp sum claim `finish_claims` appends to `H`'s claims (lane L47's lines)
        let lc = protocol::logup_sum_claim(&lay);
        out.both(format!("SUMCLAIM {} {}", lc.parts.len(), f2(&lc.value)));
        for (j, p) in lc.parts.iter().enumerate() {
            out.both(format!("PART {j} {} {} {} {}", p.slice.offset, p.slice.log_size, f2(&p.coef), f2s(&p.point)));
        }
    }
    // the slot loop on the real transcript
    let ctx = Ctx { accuracy: blk.accuracy(), lay: &lay, public: blk.attention(), ff: blk.feed_forward(), alpha, beta, g_u8, g_exp, g_act, g_dd };
    let mut side = Side::Verify { slots: &core.slots };
    let mut acc = Acc::default();
    let mut pts = Points::default();
    let (mut n_tabs, mut n_entries) = (0usize, 0usize);
    let mut folds: Vec<(usize, Vec<Fp2>)> = Vec::new();
    for s in 0..sh.n_slots() {
        let before_def = Transcript::clone_state(&tr);
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        // the definition's draws: `define` only squeezes (lane L11's recovery)
        let mut replay = Transcript::clone_state(&before_def);
        let mut draws = Vec::new();
        while replay.counter() < tr.counter() {
            draws.push(replay.challenge_fp2());
        }
        assert_eq!(replay.state(), tr.state(), "slot {s}: the definition did more than squeeze");
        let pubs: Vec<Vec<Fp2>> = def.tabs.iter().filter_map(|t| if let Tab::Pub(v) = t { Some(v.clone()) } else { None }).collect();
        out.both(format!("SLOT {s} {} {}", def.tabs.len(), pubs.len()));
        out.both(format!("DRAWS {s} {}", f2s(&draws)));
        if !SKIP_SLOTS.contains(&s) {
            for (i, v) in pubs.iter().enumerate() {
                out.table(&format!("PUB {s} {i}"), v, rho1, rho2);
                n_tabs += 1;
                n_entries += v.len();
            }
            if FOLD_SLOTS.contains(&s) {
                folds.push((s, pubs[0].clone()));
            }
        }
        run_slot(&mut side, &mut acc, def, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
    }
    if weights == Weights::Sampled {
        // each fold table at its sampled indices, and the weight entries those indices read (the code's storage: `wq`,
        // `wk`, `wv` as (output, input), `wo` as (output, query), `wg_t`, `wu_t` as (input, hidden), `wd_t` as (hidden,
        // output)): the flat indices `k + j*stride`, `j < count`
        let kvw = sh.kv_heads * sh.head_dim;
        for (s, v) in &folds {
            let (nm, m, live): (&str, &[i8], usize) = match *s {
                5 => ("Q", ap.wq.as_slice(), sh.width),
                6 => ("K", ap.wk.as_slice(), sh.width),
                7 => ("V", ap.wv.as_slice(), sh.width),
                10 => ("O", ap.wo.as_slice(), v.len()),
                11 => ("G", ff.wg_t.as_slice(), sh.width),
                12 => ("U", ff.wu_t.as_slice(), sh.width),
                _ => ("D", ff.wd_t.as_slice(), sh.hidden),
            };
            let n = v.len();
            let mut idx: Vec<usize> = (0..ENDS.min(n)).chain(live.saturating_sub(ENDS)..live.min(n)).chain(n.saturating_sub(ENDS)..n).collect();
            idx.sort();
            idx.dedup();
            let vals: Vec<Fp2> = idx.iter().map(|&i| v[i]).collect();
            out.both(format!("FSAMPLE {s} 0 {} {}", usizes(&idx), f2s(&vals)));
            for &i in &idx {
                let (k, stride, count) = match *s {
                    5 => (i, sh.d_pad, sh.q_pad()),
                    6 | 7 => (i, sh.d_pad, kvw),
                    10 => (i, sh.q_pad(), sh.d_pad),
                    11 | 12 => (i * sh.f_pad, 1, sh.f_pad),
                    _ => (i * sh.d_pad, 1, sh.d_pad),
                };
                assert!(k + (count - 1) * stride < m.len(), "slot {s}: a weight column outside the stored matrix");
                let col: Vec<i8> = (0..count).map(|j| m[k + j * stride]).collect();
                out.full_only(format!("WCOL {nm} {k} {stride} {count} {}", i8s(&col)));
            }
        }
    }
    (n_tabs, n_entries)
}

/// **The R13 rung receipt's public tables** (every slot but 19 and 20), with the public data they are built from as
/// the production code stores it, every slot's draws and table counts, and the Shieldstral T128 R13 shape's
/// `supp(Dom::L)`.
fn export_r13_host() -> (String, String) {
    let (sh, blk, w) = rung_case(shape::R13_RUNG_H24);
    let core = prove(&sh, &blk, copy(&w)).expect("the honest R13 rung core");
    verify(&sh, &blk, &core).expect("the honest R13 rung core verifies (production verify_core)");
    let rho1 = Fp2::new(Fp::new(7), Fp::new(3));
    let rho2 = Fp2::new(Fp::new(1234567), Fp::new(89));
    let mut out = Out::default();
    let (n_tabs, n_entries) = host_record(&mut out, format!("L49H {} {} {}", sh.name, sh.n_slots(), sh.log_cols), &sh, &blk, &core, Weights::Whole);
    // the Shieldstral T128 R13 shape's `supp(Dom::L)`: `B::supp(Dom::L, cube)` with `cube = size(Dom::L)` lays out
    // `pad::indicator_table(Dom::L)` itself (`tile_rep` is 1)
    let shs = built(shape::R13_SHIELD_T128_H24);
    assert!(shs.carries_pad_rule() && shs.pads(Dom::L), "the Shieldstral R13 shape pads Dom::L");
    let tl: Vec<Fp2> = super::super::pad::indicator_table(&shs, Dom::L).into_iter().map(Fp2::from_i64).collect();
    out.both(format!("SHIELDSHAPE {} {} {} {}", shs.name, shs.tokens, shs.t_pad, shs.size(Dom::L)));
    out.table("SHIELDL", &tl, rho1, rho2);
    out.both(format!("DONE {n_tabs} {n_entries}"));
    eprintln!("L49 R13 host export {}: {n_tabs} public tables, {n_entries} entries; full {} bytes, short {} bytes", sh.name, out.full.len(), out.short.len());
    (out.full, out.short)
}

#[test]
fn lean_l49_export_the_r13_host_tables() {
    let (full, short) = export_r13_host();
    if let Ok(path) = std::env::var("LEAN_L49_CORPUS") {
        std::fs::write(path, full.as_bytes()).unwrap();
    }
    if let Ok(path) = std::env::var("LEAN_L49_CORPUS_SHORT") {
        std::fs::write(path, short.as_bytes()).unwrap();
    }
}

/// **One block of the app's Shieldstral-1.0-3B T128 R13 export** (`$HL_L49_SHIELD_EXPORT`, the directory of
/// `profile.json`; layer `$HL_L49_SHIELD_LAYER`, default 0): the production loader (`TrainedExport::load`, which
/// authenticates the pinned checkpoint under `$ZK60_MODELS` and re-derives the tied token tables; `load_layer`, every
/// array's SHA-256 against its manifest), the layer's stage shape (`LayerRecord::shape_at`: `R13_SHIELD_T128_H24` at
/// the layer's own calibration), the layer input = the export's token-embedding rows (`token_io/embedding_int16.bin`,
/// checked by the loader) of a fixed public id sequence (id 1, then `1000 + 37 t`), the production witness builder
/// (`build_for_block`), one block CORE by the production `prove_core` (`w16r2_tests`' seeded harness), accepted by the
/// production `verify_core`; then the record (`host_record`, the folds sampled, with the LogUp sum claim). CPU only.
fn export_shield_block() -> (String, String) {
    use super::super::trained_block::TrainedExport;
    use std::io::{Read as _, Seek as _, SeekFrom};
    let t0 = std::time::Instant::now();
    let root = std::path::PathBuf::from(std::env::var("HL_L49_SHIELD_EXPORT").expect("HL_L49_SHIELD_EXPORT: the Shieldstral T128 R13 export"));
    let layer: u32 = std::env::var("HL_L49_SHIELD_LAYER").ok().and_then(|v| v.parse().ok()).unwrap_or(0);
    let ex = TrainedExport::load(&root).expect("the export (the pinned checkpoint and the tied tables authenticated)");
    let c = ex.run_constants(&[layer]).expect("the layer's constants");
    let seed = ex.shape_for(&c).expect("the run's seed shape");
    let tl = ex.load_layer(&seed, &c, layer, false).expect("the layer (every array against its manifest)");
    let sh = tl.record.shape_at(&seed).expect("the layer's stage shape");
    assert_eq!(sh.profile, shape::R13_SHIELD_T128_H24, "the export's block profile");
    let gate = tl.record.accuracy_gate_shift;
    let blk = tl.blk;
    let t_load = t0.elapsed().as_secs_f64();
    eprintln!("L49 Shieldstral layer {layer}: loaded in {t_load:.1} s ({}, gate shift {gate:?})", sh.name);
    // the layer input: the export's embedding rows of a fixed public id sequence
    let ids: Vec<u64> = (0..sh.tokens as u64).map(|t| if t == 0 { 1 } else { 1000 + 37 * t }).collect();
    let mut f = std::fs::File::open(root.join("token_io").join("embedding_int16.bin")).expect("the embedding table");
    let mut x = vec![0i16; sh.tokens * sh.width];
    let mut row = vec![0u8; 2 * sh.width];
    for (t, id) in ids.iter().enumerate() {
        f.seek(SeekFrom::Start(id * 2 * sh.width as u64)).unwrap();
        f.read_exact(&mut row).unwrap();
        for i in 0..sh.width {
            x[t * sh.width + i] = i16::from_le_bytes([row[2 * i], row[2 * i + 1]]);
        }
    }
    let t1 = std::time::Instant::now();
    let w = super::super::witness::build_for_block(&sh, &blk, &x).expect("an admissible layer input");
    let t_wit = t1.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let core = prove(&sh, &blk, w).expect("the honest Shieldstral block core");
    let t_prove = t1.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    verify(&sh, &blk, &core).expect("the honest Shieldstral block core verifies (production verify_core)");
    let t_verify = t1.elapsed().as_secs_f64();
    eprintln!("L49 Shieldstral layer {layer}: witness {t_wit:.1} s, prove {t_prove:.1} s, verify {t_verify:.1} s");
    let t1 = std::time::Instant::now();
    let mut out = Out::default();
    let head = format!("L49S {} {} {} {} {}", sh.name, sh.n_slots(), sh.log_cols, layer, gate.unwrap_or(0));
    let (n_tabs, n_entries) = host_record(&mut out, head, &sh, &blk, &core, Weights::Sampled);
    out.both(format!("INPUT {} embedding-rows-of-ids-1-then-1000+37t", sh.tokens));
    out.both(format!("DONE {n_tabs} {n_entries}"));
    eprintln!(
        "L49 Shieldstral block export {} layer {layer}: record {:.1} s; {n_tabs} public tables, {n_entries} entries; full {} bytes, short {} bytes",
        sh.name,
        t1.elapsed().as_secs_f64(),
        out.full.len(),
        out.short.len()
    );
    (out.full, out.short)
}

#[test]
#[ignore = "D63 L49: one block of the app's Shieldstral T128 R13 export (HL_L49_SHIELD_EXPORT, ZK60_MODELS); CPU only, run alone through the resource guard"]
fn lean_l49_export_a_shieldstral_block() {
    let (full, short) = export_shield_block();
    if let Ok(path) = std::env::var("LEAN_L49_SHIELD_CORPUS") {
        std::fs::write(path, full.as_bytes()).unwrap();
    }
    if let Ok(path) = std::env::var("LEAN_L49_SHIELD_CORPUS_SHORT") {
        std::fs::write(path, short.as_bytes()).unwrap();
    }
}
