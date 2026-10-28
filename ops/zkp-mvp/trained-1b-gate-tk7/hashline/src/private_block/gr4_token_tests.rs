//! [PRIVACY GATE LANE, GATE ROUND 10, 2026-10-20, tk7 gate copy] TEST-ONLY.
//! A child of `gr4_trained_tests` (it reuses that module's private replay
//! helpers: `Draws`, `zk_root`, `rebuild_on`, `boundary_root_on`, `probe`,
//! `probe_at`, `position_tag`, `words`, `assert_pairwise_distinct`), mounted
//! by one `#[path]` line at the end of that file. No production file and no
//! pinned file changes.
//!
//! **Not a privacy result and not an acceptance of anything.**
//!
//! TWO CHECKS, the privacy review round 4's PR4-8 and PR4-9:
//!
//! **PR4-8: THE STAGE-47 ROOT-REBUILD REPLAY OF A TOKEN-I/O RUN** (the block
//! replay of `gr4_trained_tests` extended to stage IN and stage OUT). A token
//! run of the trained TinyLlama T32 blocks at the export the token captures
//! used (`pg_rot1_b4_T32_cal128`, the R2 head tables) is proved with
//! `prove_token_run_with`'s body REPLICATED line for line
//! (`token_io/run.rs:744-822`) on ONE SEEDED stream: stage IN
//! (`stage_in::prove`: B_in, A_in, M_in, H_in on the run stream), each block
//! stage (B_{k+1} by `boundary::prepare`, then `protocol::prove_core`, then
//! B_k's one opening), stage OUT (`stage_out::prove`: A_out, M_out, H_out, then
//! B_out's opening and the output endpoint's). Every segment is encoded with
//! the production encoders and the run is VERIFIED BY THE PRODUCTION TOKEN-RUN
//! VERIFIER (`verify_token_run`) from the segment bytes, which re-derives every
//! geometry and replays the whole Fiat-Shamir chain: an inexact replication
//! would be refused. The statement's private helpers this needs
//! (`ntt_log`, `in_geom`, `out_geom`, `block_geom`, `block_layout`) are
//! restated here from `pub(crate)` pieces, each next to the line it mirrors;
//! the verifier's acceptance checks them.
//!
//! THE PREDICTION: ONE replay stream in the predicted order -- B_in's mask
//! rows, pads, salts; A_in's mask rows, pads, salts; M_in; H_in's mask rows,
//! zero-sum rows, pads, salts; for each block k: B_{k+1}, then the block's A,
//! M, H (`rebuild_on`); then A_out, M_out, H_out -- REBUILDS EVERY ROOT from the
//! witness and the stream (the token stages' H rows from the replayed
//! challenges), and every root must equal the prover's; the replay must end
//! where the prover's generator did (next-draw probe; the counted bytes; the
//! 16-byte non-vacuity of the probe).
//!
//! NON-VACUITY, each must move the named root(s): A_in's proximity word
//! zeroed (A_in); B_in drawn after A_in (B_in and A_in); stage OUT predicted on
//! a fresh stream (A_out); H_out's first reserved word := A_out's (H_out);
//! M_out's slot 1 coefficient := slot 0's (M_out); H_in's zero-sum rows from a
//! stream reset (H_in).
//!
//! THE TOKEN ENDPOINTS are sealed by `seal_endpoints` on their own OS-seeded
//! generators: checked IN SITU (no drawn value or salt repeats inside or
//! across the two), as the block replay checks its endpoints.
//!
//! **PR4-9: THE CALIBRATION ATTRIBUTION.** For each export and layer range
//! the token captures used, the trained-model statement over those layers
//! and the token profile are built from the EXPORT and the named TABLE FILES
//! by the production loaders (the capture test's own recipe), and the token
//! run's calibration word is composed here as
//! BLAKE3("hashline/token-io-calibration/v1" || identity || profile digest)
//! (`token_io/run.rs:303-308`) and cross-checked against the statement's own
//! header word. The words are printed (they are public: the run header
//! absorbs them) so the gate can compare them with every capture's absorbed
//! `calibration`.
//!
//! THE CAPTURE RULE of the parent applies to PR4-8 (booleans, counts, labels,
//! seconds; the seeded receipt is never written). PR4-9 prints only public
//! digests.

use super::*;
use crate::mle::eq_table_msb;
use crate::private_block::boundary::{self, BoundarySpec};
use crate::private_block::run::RunShape;
use crate::private_block::token_io::load::{load_token_tables, read_manifests, token_run_profile_of, TableFiles};
use crate::private_block::token_io::run::{endpoint_specs, honest_pipeline_at, seal_endpoints, verify_token_run, TokenRunStatement, VerifierPolicy, STAGE_IN_MAGIC, STAGE_OUT_MAGIC};
use crate::private_block::token_io::stage_in::{self, StageInWitness};
use crate::private_block::token_io::stage_out::{self, StageOutWitness};
use crate::private_block::token_io::{k as fk, Dim, SelectorVariant, StageLayout, StageSegGeom, Tier, TokenProfile, TokenTables, TAG_EMB};
use crate::private_block::trained_block::hex as thex;
use crate::private_block::trained_statement::{apply_own, has_own, IntegerCalibration, Provenance, TrainedModelStatement};

fn tl_export() -> PathBuf {
    match std::env::var("HL_PB_TOKEN_EXPORT") {
        Ok(v) => PathBuf::from(v),
        Err(_) => PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../../results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128"),
    }
}

fn tl_head() -> PathBuf {
    match std::env::var("HL_PB_TOKEN_HEAD") {
        Ok(v) => PathBuf::from(v),
        Err(_) => PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../../results/zk60_token_io_r1_20261017/r2_inputs"),
    }
}

fn token_context() -> Digest {
    *blake3::hash(b"privacy gate PR4-8: the seeded token-run replay fixture context").as_bytes()
}

/// a sequence manifest's `token_ids` (the capture test's `seq_tokens`)
fn seq_ids(export: &std::path::Path, seq: &str) -> Vec<u64> {
    let m = std::fs::read_to_string(export.join(format!("seq_{seq}")).join("manifest.json")).unwrap_or_else(|e| panic!("seq_{seq}: {e}"));
    let at = m.find("\"token_ids\"").expect("token_ids") + "\"token_ids\"".len();
    let open = at + m[at..].find('[').unwrap() + 1;
    let close = open + m[open..].find(']').unwrap();
    m[open..close].split(',').map(|x| x.trim().parse::<u64>().expect("a token id")).collect()
}

/// the statement pieces of one token run (the capture test's recipe,
/// `token_io/capture_tests.rs` `capture_token_export`); `keep_blocks` false
/// drops every block once its record is taken (the attribution needs none)
struct TokenParts {
    sh: Shape,
    shapes: Vec<Shape>,
    profile: &'static str,
    blocks: Vec<BlockPublic>,
    digests: Vec<Digest>,
    model: TrainedModelStatement,
    tables: TokenTables,
    tp: TokenProfile,
    bos: u64,
    norm: crate::private_block::token_io::FinalNorm,
}

fn token_parts(export: &std::path::Path, emb_dir: &std::path::Path, head_dir: &std::path::Path, layers: &[u32], keep_blocks: bool) -> TokenParts {
    let ex = TrainedExport::load(export).unwrap_or_else(|e| panic!("the export: {e}"));
    assert!(layers.iter().all(|k| ex.layers.contains(k)), "layers {layers:?} are not all in the export");
    let c = ex.run_constants(layers).unwrap_or_else(|e| panic!("{e}"));
    let sh = ex.shape_for(&c).unwrap_or_else(|e| panic!("{e}"));
    let profile = token_run_profile_of(&sh).unwrap_or_else(|e| panic!("{e}"));
    let (mut blocks, mut records, mut digests) = (Vec::new(), Vec::new(), Vec::new());
    for &l in layers {
        let t = ex.load_layer(&sh, &c, l, false).unwrap_or_else(|e| panic!("layer {l}: {e}"));
        digests.push(t.blk.digest());
        records.push(t.record);
        if keep_blocks {
            blocks.push(t.blk);
        }
    }
    let prov = Provenance {
        label: format!("export:{}", ex.variant),
        residual_unit: ex.residual_unit,
        quantizer_sha256: ex.tool_sha256,
        calibration_set_sha256: ex.calibration_set_sha256,
        export_profile_sha256: ex.profile_sha256,
        calibration_tool_sha256: ex.tool_sha256,
        rope_theta: c.rope_theta,
    };
    let cal = IntegerCalibration::as_the_code_proves(&sh, &prov);
    let base = sh.norm_calibration();
    let shapes: Vec<Shape> = records.iter().map(|r| if has_own(&r.own) { sh.with_layer_calibration(&apply_own(&base, &r.own).unwrap()).unwrap() } else { sh.clone() }).collect();
    let model = TrainedModelStatement::new(&sh, profile, ex.source.clone(), cal, records).unwrap_or_else(|e| panic!("the trained-model statement over {layers:?}: {e}"));
    let files = TableFiles { emb_dir: emb_dir.to_path_buf(), head_dir: head_dir.to_path_buf() };
    let (tables, tm) = load_token_tables(&files, read_manifests(&files).unwrap().v, sh.width).unwrap_or_else(|e| panic!("the tables: {e}"));
    let tp = TokenProfile::new(&sh, &tables, tm.bos, tm.norm, SelectorVariant::PublicRow, Tier::R1_MVP).unwrap_or_else(|e| panic!("{e}"));
    TokenParts { sh, shapes, profile, blocks, digests, model, tables, tp, bos: tm.bos, norm: tm.norm }
}

/// `TokenRunStatement::ntt_log` (private), restated
fn st_ntt_log(st: &TokenRunStatement) -> u32 {
    let sh = st.sh();
    let t = st.tp.tier;
    [
        protocol::ntt_log_at(sh),
        (sh.endpoint_log_n + sh.endpoint_inv_rate.trailing_zeros() as usize) as u32,
        (t.stage_log_n + t.stage_inv_rate.trailing_zeros() as usize) as u32,
        (t.ep_log_n + t.ep_inv_rate.trailing_zeros() as usize) as u32,
        crate::zk::MASK_LOG_DOM,
    ]
    .into_iter()
    .max()
    .unwrap_or(crate::zk::MASK_LOG_DOM)
}

/// `TokenRunStatement::in_geom` (private), restated
fn st_in_geom<'a>(st: &TokenRunStatement, lay: &'a StageLayout) -> StageSegGeom<'a> {
    let ed = Dim::of(&st.in_spec.params());
    StageSegGeom { magic: STAGE_IN_MAGIC, lay, has_b_root: true, a_groups: stage_in::A_GROUPS, h_groups: stage_in::H_GROUPS, closes: vec![(ed, 1, st.in_spec.commitment_rows())], total: st.l() + 2, index: 0 }
}

/// `TokenRunStatement::out_geom` (private), restated
fn st_out_geom<'a>(st: &TokenRunStatement, lay: &'a StageLayout) -> StageSegGeom<'a> {
    let b = st.boundary_spec(st.l()).expect("B_out's statement");
    let (bd, ed) = (Dim::of(&b.params()), Dim::of(&st.out_spec.params()));
    StageSegGeom {
        magic: STAGE_OUT_MAGIC,
        lay,
        has_b_root: false,
        a_groups: stage_out::A_GROUPS,
        h_groups: stage_out::H_GROUPS,
        closes: vec![(bd, 2, b.commitment_rows()), (ed, 1, st.out_spec.commitment_rows())],
        total: st.l() + 2,
        index: st.l() + 1,
    }
}

/// `TokenRunStatement::block_geom` (private), restated
fn st_block_geom(st: &TokenRunStatement, k: usize) -> SegGeom {
    SegGeom { l: st.l() + 2, k: k + 1, boundary_rows: st.boundary_spec(0).expect("B_in").commitment_rows(), sites: 2 }
}

/// `TokenRunStatement::block_layout` (private), restated
fn st_block_layout(st: &TokenRunStatement, k: usize) -> Layout {
    Layout::for_shape(&st.stage_shape(k).expect("the stage shape"))
        .expect("a layout")
        .with_io_mask_rows([st.boundary_spec(k).unwrap().mask_row(1).unwrap(), st.boundary_spec(k + 1).unwrap().mask_row(0).unwrap()])
}

/// one deliberate error in the token prediction
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum TPert {
    None,
    /// A_in's first proximity-row word := 0
    InAProxZero,
    /// B_in predicted AFTER A_in (stage IN's B-before-A order reversed)
    BinAfterAin,
    /// H_in's zero-sum rows drawn from a stream reset
    InZeroSumReset,
    /// stage OUT predicted on a fresh stream (a stream reset before stage OUT)
    ResetBeforeOut,
    /// H_out's first reserved word := A_out's first reserved word
    OutCopyAIntoH,
    /// M_out's slot 1 first coefficient := slot 0's
    OutAlphaCopy,
}

/// `zk::mask_commit_tagged`'s root on a CALLER's stream (the parent's M
/// prediction, restated as a function)
fn mask_root_on(rp: &mut Draws, specs: &[(usize, usize)], ntt: &NttTables, tag: &HashTag, alpha_copy: bool) -> Digest {
    let (m, dom) = (1usize << MASK_LOG_MSG, 1usize << MASK_LOG_DOM);
    let mut alphas: Vec<Vec<Fp2>> = specs.iter().map(|&(nv, d)| (0..CfsMask::len(nv, d)).map(|_| rp.fp2()).collect()).collect();
    if alpha_copy {
        alphas[1][0] = alphas[0][0];
    }
    let n_base = 2 * specs.len() + 4;
    let pows_m = pcs::coset_powers(Fp::new(7), dom);
    let enc_coeffs = |c: &[Fp], out: &mut [Fp]| {
        for v in out.iter_mut() {
            *v = Fp::ZERO;
        }
        for (i, x) in c.iter().enumerate() {
            out[i] = x.mul(pows_m[i]);
        }
        ntt.forward(out);
    };
    let mut enc = vec![Fp::ZERO; n_base * dom];
    for (s, al) in alphas.iter().enumerate() {
        let re: Vec<Fp> = al.iter().map(|c| c.c0).collect();
        let im: Vec<Fp> = al.iter().map(|c| c.c1).collect();
        for (kk, part) in [re, im].iter().enumerate() {
            assert!(part.len() + MASK_Q <= m, "the prediction's mask row overflows");
            let mut msg = vec![Fp::ZERO; m];
            msg[..part.len()].copy_from_slice(part);
            for j in 0..MASK_Q {
                msg[part.len() + j] = rp.fp();
            }
            ntt.inverse(&mut msg);
            enc_coeffs(&msg, &mut enc[(2 * s + kk) * dom..(2 * s + kk + 1) * dom]);
        }
    }
    let mut b_re: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let mut b_im: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    b_re[m] = b_re[0].neg();
    b_im[m] = b_im[0].neg();
    let u_re: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let u_im: Vec<Fp> = (0..2 * m).map(|_| rp.fp()).collect();
    let base0 = 2 * specs.len();
    for (kk, c) in [&b_re, &b_im, &u_re, &u_im].iter().enumerate() {
        enc_coeffs(c, &mut enc[(base0 + kk) * dom..(base0 + kk + 1) * dom]);
    }
    let salts: Vec<[u8; 32]> = (0..dom).map(|_| rp.bytes32()).collect();
    let leaves = pcs::hash_columns_keyed(&enc, n_base, dom, tag.column_key());
    let salted: Vec<Digest> = leaves.iter().zip(salts.iter()).map(|(l, s)| pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    MerkleTree::build_keyed(salted, tag.node_key()).root()
}

fn write_h2(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

/// the zero-sum pair: n - 1 draws per row, the declared closing entry
fn zero_sum_rows(h: &mut [Fp], rows: [usize; 2], n: usize, rp: &mut Draws) {
    for r in rows {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 {
            let v = rp.fp();
            h[r * n + j] = v;
            sum = sum.add(v);
        }
        h[r * n + n - 1] = sum.neg();
    }
}

/// THE STAGE-IN PREDICTION: (B_in, A_in, M_in, H_in) on the caller's stream,
/// from the stage witness, the B_in plane and the transcript at stage IN's
/// start (after the run header; the locality words are absorbed here, as
/// `stage_in::prove` absorbs them)
#[allow(clippy::too_many_arguments)]
fn predict_in(rp: &mut Draws, tp: &TokenProfile, tables: &TokenTables, lay: &StageLayout, wit: &StageInWitness, b_spec: &BoundarySpec, b_plane: &[i16], stage_tr: &Transcript, ntt: &NttTables, tag: &HashTag, pert: TPert) -> [Digest; 4] {
    let n = lay.n;
    let (ti_n, voc_n) = (1usize << tp.ti_log(), 1usize << tp.voc_log());
    let mut tr = Transcript::clone_state(stage_tr);
    tr.absorb_u64(b"pb-run-stage", 0);
    tr.absorb(b"pb-run-block", &tp.emb_digest);
    let b_words = words(b_plane);
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    a[lay.a_off[stage_in::A_TOK]..lay.a_off[stage_in::A_TOK] + ti_n].copy_from_slice(&wit.tok);
    a[lay.a_off[stage_in::A_MULT]..lay.a_off[stage_in::A_MULT] + voc_n].copy_from_slice(&wit.mult);
    let a_part = |rp: &mut Draws, a: &mut Vec<Fp>| -> Digest {
        for x in a[lay.a_mask_base * n..].iter_mut() {
            *x = rp.fp();
        }
        if pert == TPert::InAProxZero {
            a[lay.a_prox * n] = Fp::ZERO;
        }
        zk_root(&lay.params, a, lay.a_rows, rp, ntt, tag)
    };
    let (b_root, a_root) = if pert == TPert::BinAfterAin {
        let ar = a_part(rp, &mut a);
        (boundary_root_on(rp, b_spec, &b_words, ntt, tag), ar)
    } else {
        let br = boundary_root_on(rp, b_spec, &b_words, ntt, tag);
        (br, a_part(rp, &mut a))
    };
    protocol::absorb_root(&mut tr, b"B", &b_root, b_spec.commitment_rows(), b_spec.log_n());
    protocol::absorb_root(&mut tr, b"A", &a_root, lay.a_rows, lay.log_n);
    let m_root = mask_root_on(rp, &lay.mask_specs(), ntt, tag, false);
    tr.absorb(b"M", &m_root);
    // `stage_in::challenges` (private), restated
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let r_emb = tr.challenge_fp2_vec(tp.d_pad.trailing_zeros() as usize);
    let g_emb = gamma.mul_base(Fp::new(TAG_EMB));
    let ef = tables.emb_fold(&r_emb);
    let tau = stage_in::tau_table(tp, &ef, beta, g_emb);
    let e_r = eq_table_msb(&r_emb);
    let mut h_q = vec![Fp2::ZERO; ti_n];
    for t in 0..tp.tokens {
        if wit.hq_zero.contains(&t) {
            continue;
        }
        let row = &b_plane[t * tp.d_pad..(t + 1) * tp.d_pad];
        let xr = row.iter().zip(e_r.iter()).fold(Fp2::ZERO, |acc, (x, e)| if *x == 0 { acc } else { acc.add(e.mul_base(Fp::from_i64(i64::from(*x)))) });
        let q = Fp2::from_base(wit.tok[t]).add(beta.mul(xr)).add(g_emb);
        h_q[t] = alpha.sub(q).inv();
    }
    let mut h_tab = vec![Fp2::ZERO; voc_n];
    for v in 0..voc_n {
        if !wit.mult[v].is_zero() {
            h_tab[v] = alpha.sub(tau[v]).inv().mul_base(wit.mult[v]);
        }
    }
    let mut h = vec![Fp::ZERO; lay.h_rows * n];
    write_h2(&mut h, lay.h_off[stage_in::H_Q], &h_q);
    write_h2(&mut h, lay.h_off[stage_in::H_TAB], &h_tab);
    for x in h[lay.h_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    if pert == TPert::InZeroSumReset {
        let mut fresh = Draws::new();
        zero_sum_rows(&mut h, lay.h_u_rows(), n, &mut fresh);
        // the real stream still advances by what the honest rows consume
        let mut sink = vec![Fp::ZERO; lay.h_rows * n];
        zero_sum_rows(&mut sink, lay.h_u_rows(), n, rp);
    } else {
        zero_sum_rows(&mut h, lay.h_u_rows(), n, rp);
    }
    let h_root = zk_root(&lay.params, &h, lay.h_rows, rp, ntt, tag);
    [b_root, a_root, m_root, h_root]
}

/// `stage_out`'s private `looked` and `helper_col`, restated
fn looked_cols(planes: &[Vec<Fp>], lks: &[stage_out::Lk], n: usize) -> Vec<Vec<Fp>> {
    lks.iter().map(|lk| (0..n).map(|x| lk.terms.iter().fold(Fp::from_i64(lk.cst), |a, (p, c)| a.add(Fp::from_i64(*c).mul(planes[*p][x])))).collect()).collect()
}

fn helper_col2(a: &[Fp], b: Option<&[Fp]>, alpha: Fp2, g: Fp2) -> Vec<Fp2> {
    let inv = |x: Fp| alpha.sub(Fp2::from_base(x).add(g)).inv();
    (0..a.len()).map(|i| match b {
        Some(bb) => inv(a[i]).add(inv(bb[i])),
        None => inv(a[i]),
    }).collect()
}

/// THE STAGE-OUT PREDICTION: (A_out, M_out, H_out) on the caller's stream
#[allow(clippy::too_many_arguments)]
fn predict_out(rp: &mut Draws, tp: &TokenProfile, lay: &StageLayout, wit: &StageOutWitness, stage_index: u64, stage_tr: &Transcript, ntt: &NttTables, tag: &HashTag, pert: TPert) -> [Digest; 3] {
    let n = lay.n;
    let l = tp.limbs;
    let mult = stage_out::a_mult(l);
    let mut tr = Transcript::clone_state(stage_tr);
    tr.absorb_u64(b"pb-run-stage", stage_index);
    tr.absorb(b"pb-run-block", &tp.head_digest);
    let cols: Vec<Vec<Fp>> = [(stage_out::lookups_lo(), tp.lo_log()), (stage_out::lookups_do(), tp.do_log()), (stage_out::lookups_vo(l), tp.vo_log())].iter().flat_map(|(lks, lg)| looked_cols(&wit.planes, lks, 1usize << lg)).collect();
    let mut hist = vec![0u64; U8_LEN];
    for c in &cols {
        for v in c {
            assert!((v.0 as usize) < U8_LEN, "an honest stage-OUT witness looks up a byte");
            hist[v.0 as usize] += 1;
        }
    }
    let mut a = vec![Fp::ZERO; lay.a_rows * n];
    for p in 0..mult {
        a[lay.a_off[p]..lay.a_off[p] + wit.planes[p].len()].copy_from_slice(&wit.planes[p]);
    }
    for (i, c) in hist.iter().enumerate() {
        a[lay.a_off[mult] + i] = Fp::new(*c);
    }
    for x in a[lay.a_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    let a_root = zk_root(&lay.params, &a, lay.a_rows, rp, ntt, tag);
    protocol::absorb_root(&mut tr, b"A", &a_root, lay.a_rows, lay.log_n);
    let m_root = mask_root_on(rp, &lay.mask_specs(), ntt, tag, pert == TPert::OutAlphaCopy);
    tr.absorb(b"M", &m_root);
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let mut h = vec![Fp::ZERO; lay.h_rows * n];
    let mut ci = 0usize;
    for (first, count) in [(stage_out::H_LO, 1usize), (stage_out::H_D0, stage_out::H_DO_HELPERS), (stage_out::H_V0, stage_out::hv(l))] {
        let dom_cols = if first == stage_out::H_LO {
            1
        } else if first == stage_out::H_D0 {
            stage_out::lookups_do().len()
        } else {
            l
        };
        for kk in 0..count {
            let a_col = &cols[ci + 2 * kk];
            let b_col = if 2 * kk + 1 < dom_cols { Some(cols[ci + 2 * kk + 1].as_slice()) } else { None };
            write_h2(&mut h, lay.h_off[first + kk], &helper_col2(a_col, b_col, alpha, g_u8));
        }
        ci += dom_cols;
    }
    let tcol: Vec<Fp2> = (0..1usize << tp.tab_log())
        .map(|z| {
            let m = if z < U8_LEN { hist[z] } else { 0 };
            if m == 0 {
                Fp2::ZERO
            } else {
                alpha.sub(fk((z % U8_LEN) as i64).add(g_u8)).inv().mul_base(Fp::new(m))
            }
        })
        .collect();
    write_h2(&mut h, lay.h_off[stage_out::h_gu8(l)], &tcol);
    for x in h[lay.h_mask_base * n..].iter_mut() {
        *x = rp.fp();
    }
    if pert == TPert::OutCopyAIntoH {
        h[lay.h_mask_base * n] = a[lay.a_mask_base * n];
    }
    zero_sum_rows(&mut h, lay.h_u_rows(), n, rp);
    let h_root = zk_root(&lay.params, &h, lay.h_rows, rp, ntt, tag);
    [a_root, m_root, h_root]
}

/// every drawn field value of a token endpoint owner (the rows above the data
/// row, then the pads) and its salts, read in situ
fn token_endpoint_drawn(e: &pcs::CommittedZk, data_rows: usize) -> (Vec<u64>, Vec<[u8; 32]>) {
    let rows = e.cm.rows;
    let n = e.data.len() / rows;
    assert!(n * rows == e.data.len(), "the token endpoint owner's matrix is not rows x n");
    let mut v: Vec<u64> = e.data[data_rows * n..].iter().map(|x| x.0).collect();
    v.extend(e.pads.iter().map(|x| x.0));
    (v, e.salts.clone())
}

struct TokenRoots {
    b: Vec<Digest>,
    a: Vec<Digest>,
    m: Vec<Digest>,
    h: Vec<Digest>,
    bytes: u64,
    probe: [u64; 4],
}

fn replay_token_run(layers: &[u32], dense: bool) {
    let l = layers.len();
    let label = format!("TinyLlama T32 token run (b4 export), layers {:?}, {}", layers, if dense { "dense ho00" } else { "fixed: 32 x BOS" });
    let t_all = Instant::now();
    let export = tl_export();
    let p = token_parts(&export, &export, &tl_head(), layers, true);
    let sh = p.sh.clone();
    let tokens = if dense { seq_ids(&export, "ho00") } else { vec![p.bos; sh.tokens] };
    let mut pipe = honest_pipeline_at(&p.shapes, &p.tp, &p.tables, &p.blocks, &tokens).unwrap_or_else(|e| panic!("{label}: the honest pipeline: {e}"));
    let (ins, outs) = endpoint_specs(&sh, token_context(), &p.tp).expect("the token endpoint specs");
    let (roots, owners) = seal_endpoints(&ins, &outs, &pipe.in_plane, &pipe.out_plane, &sh.hash_tag()).expect("the token endpoints seal");
    let st = TokenRunStatement::new(RunShape::new(sh.clone(), l, p.profile).unwrap(), token_context(), p.digests.clone(), &p.model, &p.tables, p.bos, p.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap_or_else(|e| panic!("{label}: {e}"));

    // ---- the token endpoints, IN SITU (OS-seeded, cannot be replayed) ----
    let (vi, si) = token_endpoint_drawn(&owners.input, st.in_spec.data_rows());
    let (vo, so) = token_endpoint_drawn(&owners.output, st.out_spec.data_rows());
    let ep_fields = assert_pairwise_distinct(&format!("{label}: the two token endpoint owners' drawn field values"), [vi, vo].concat());
    let ep_salts = assert_pairwise_distinct(&format!("{label}: the two token endpoint owners' salts"), [si, so].concat());

    // ---- `prove_token_run_with`'s body, replicated, on the SEEDED stream ----
    let tag = sh.hash_tag();
    let ntt = NttTables::new(st_ntt_log(&st));
    let mut tr = st.transcript().expect("the token run header");
    let binding = tr.state();
    let binding_ok = binding == st.binding().unwrap();
    let mut rng = ZkRng::new(SEED, DOMAIN);
    let mut segs: Vec<Vec<u8>> = Vec::with_capacity(l + 2);
    let t_prove = Instant::now();
    // stage IN
    let start = position_tag(&tr);
    let in_tr = Transcript::clone_state(&tr);
    let in_lay = stage_in::layout(&sh, &st.tp);
    let b0 = st.boundary_spec(0).unwrap();
    let win = pipe.stage_in.clone();
    let b_in_plane = pipe.b_in.clone();
    let inp = stage_in::prove(&in_lay, &st.tp, &p.tables, win.clone(), &b0, &b_in_plane, owners.input, &ntt, &mut rng, &mut tr, &tag).unwrap_or_else(|e| panic!("{label}: stage IN on the seeded stream: {e}"));
    let end = position_tag(&tr);
    let prover_in = [inp.seg.b_root.expect("stage IN commits B_in"), inp.seg.a_root, inp.seg.mask_root, inp.seg.h_root];
    segs.push(st_in_geom(&st, &in_lay).encode(&inp.seg, &binding, &start, &end).expect("stage IN's segment encodes"));
    let mut pending = inp.pending_b;
    let mut prev = (b0, inp.b_owner);
    // the blocks
    let mut ph = crate::private_block::timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut tick = Instant::now();
    let mut block_trs = Vec::with_capacity(l);
    let mut block_wits = Vec::with_capacity(l);
    let mut prover_blocks: Vec<[Digest; 4]> = Vec::with_capacity(l);
    for k in 0..l {
        let start = position_tag(&tr);
        tr.absorb_u64(b"pb-run-stage", (k + 1) as u64);
        tr.absorb(b"pb-run-block", &p.digests[k]);
        let spec = st.boundary_spec(k + 1).unwrap();
        let bw = words(&pipe.planes[k]);
        let cur = boundary::prepare(&spec, &bw, &ntt, &mut rng, &tag).expect("a boundary commits on the run stream");
        protocol::absorb_root(&mut tr, b"B", &cur.root(), spec.commitment_rows(), spec.log_n());
        block_trs.push(Transcript::clone_state(&tr));
        let lay = st_block_layout(&st, k);
        let ssh = st.stage_shape(k).unwrap();
        let wit = pipe.witnesses[k].take().expect("block k's witness");
        block_wits.push(Witness { planes: wit.planes.clone() });
        let core = protocol::prove_core(&ssh, &lay, &p.blocks[k], wit, [prev.1.data(), cur.data()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick).unwrap_or_else(|e| panic!("{label}: block {k} on the seeded stream: {e}"));
        let [ic, oc] = core.io_claims;
        let mut claims = std::mem::take(&mut pending);
        claims.extend(ic);
        let (pspec, powner) = prev;
        let in_open = powner.into_opening(&pspec, &claims, &mut tr).expect("a boundary's one opening");
        pending = oc;
        let end = position_tag(&tr);
        prover_blocks.push([cur.root(), core.a_root, core.mask_root, core.h_root]);
        let seg = Segment { b_root: Some(cur.root()), a_root: core.a_root, h_root: core.h_root, mask_root: core.mask_root, slots: core.slots, mask_open: core.mask_open, a_open: core.a_open, h_open: core.h_open, in_open, out_open: None };
        segs.push(wire::encode_segment(&seg, &lay, st_block_geom(&st, k), &binding, &start, &end).expect("a block segment encodes"));
        prev = (spec, cur);
    }
    // stage OUT
    let start = position_tag(&tr);
    let out_tr = Transcript::clone_state(&tr);
    let out_lay = stage_out::layout(&sh, &st.tp);
    let (bspec, bowner) = prev;
    let wout = pipe.stage_out.clone();
    let outp = stage_out::prove(&out_lay, &st.tp, &p.tables, wout.clone(), &bspec, bowner, pending, owners.output, (l + 1) as u64, &ntt, &mut rng, &mut tr, &tag).unwrap_or_else(|e| panic!("{label}: stage OUT on the seeded stream: {e}"));
    let end = position_tag(&tr);
    let prover_out = [outp.seg.a_root, outp.seg.mask_root, outp.seg.h_root];
    segs.push(st_out_geom(&st, &out_lay).encode(&outp.seg, &binding, &start, &end).expect("stage OUT's segment encodes"));
    let prove_s = t_prove.elapsed().as_secs_f64();
    let prover_probe = probe(&mut rng);
    drop(pipe);
    let seg_lens: Vec<usize> = segs.iter().map(|s| s.len()).collect();
    let lens_ok = seg_lens == st.segment_lens().unwrap();
    let t_verify = Instant::now();
    // THE PRODUCTION TOKEN-RUN VERIFIER, from the segments' bytes (in memory
    // only: the seeded receipt is never written anywhere)
    let verified = verify_token_run(&st, &p.blocks, &p.tables, &segs, VerifierPolicy { min_whole_run_bits: st.whole_run().floor_bits });
    let verify_s = t_verify.elapsed().as_secs_f64();
    drop(segs);

    // ---- THE PREDICTION: one replay stream, the predicted order ----
    let predict = |pert: TPert| -> TokenRoots {
        let mut rp = Draws::new();
        let [bi, ai, mi, hi] = predict_in(&mut rp, &st.tp, &p.tables, &in_lay, &win, &b0_spec_of(&st), &b_in_plane, &in_tr, &ntt, &tag, pert);
        let (mut b, mut a, mut m, mut h) = (vec![bi], vec![ai], vec![mi], vec![hi]);
        for k in 0..l {
            let spec = st.boundary_spec(k + 1).unwrap();
            b.push(boundary_root_on(&mut rp, &spec, &words(&planes_of(&st, k, &b_in_plane, &block_wits)), &ntt, &tag));
            let lay = st_block_layout(&st, k);
            let ssh = st.stage_shape(k).unwrap();
            let (ak, mk, hk) = rebuild_on(&mut rp, &ssh, &lay, &p.blocks[k], &block_trs[k], &block_wits[k], &ntt, Pert::None);
            a.push(ak);
            m.push(mk);
            h.push(hk);
        }
        if pert == TPert::ResetBeforeOut {
            rp = Draws::new();
        }
        let [ao, mo, ho] = predict_out(&mut rp, &st.tp, &out_lay, &wout, (l + 1) as u64, &out_tr, &ntt, &tag, pert);
        a.push(ao);
        m.push(mo);
        h.push(ho);
        let bytes = rp.bytes;
        TokenRoots { b, a, m, h, bytes, probe: probe(&mut rp.rng) }
    };
    let t_rebuild = Instant::now();
    let r = predict(TPert::None);
    let rebuild_s = t_rebuild.elapsed().as_secs_f64();
    let in_ok = [r.b[0] == prover_in[0], r.a[0] == prover_in[1], r.m[0] == prover_in[2], r.h[0] == prover_in[3]];
    let blocks_ok: Vec<[bool; 4]> = (0..l).map(|k| [r.b[k + 1] == prover_blocks[k][0], r.a[k + 1] == prover_blocks[k][1], r.m[k + 1] == prover_blocks[k][2], r.h[k + 1] == prover_blocks[k][3]]).collect();
    let out_ok = [r.a[l + 1] == prover_out[0], r.m[l + 1] == prover_out[1], r.h[l + 1] == prover_out[2]];
    let ends_ok = r.probe == prover_probe;
    let counted_ok = probe_at(r.bytes) == prover_probe;
    let shifted_differs = probe_at(r.bytes + 16) != prover_probe;
    eprintln!(
        "GR4 TOKEN replay [{label}]: header rebuilt = binding: {binding_ok}; {} segments, lengths = the statement's counted lengths: {lens_ok}; verified by the production token-run verifier = {}; token endpoints in situ: {ep_fields} drawn field values and {ep_salts} salts, all distinct",
        seg_lens.len(),
        verified.is_ok()
    );
    eprintln!("GR4 TOKEN replay [{label}]: stage IN roots rebuilt B_in/A_in/M_in/H_in = {:?}; block roots B_k+1/A/M/H = {:?}; stage OUT roots A_out/M_out/H_out = {:?}", in_ok, blocks_ok, out_ok);
    eprintln!(
        "GR4 TOKEN replay [{label}]: replay stream ends where the prover's did (next-draw probe) = {ends_ok}; prover consumed exactly the predicted {} bytes = {counted_ok}; probe non-vacuity (16 bytes further differs) = {shifted_differs}",
        r.bytes
    );
    assert!(binding_ok, "{label}: the token header is not the binding");
    assert!(lens_ok, "{label}: a replicated segment's length is not the statement's counted length");
    assert!(in_ok.iter().all(|x| *x), "{label}: a stage-IN root is not the prediction (B_in, A_in, M_in, H_in on the run stream)");
    assert!(blocks_ok.iter().all(|r| r.iter().all(|x| *x)), "{label}: a block-stage root (B_k+1, A, M, H) is not the prediction on the run stream");
    assert!(out_ok.iter().all(|x| *x), "{label}: a stage-OUT root is not the prediction (A_out, M_out, H_out on the run stream)");
    assert!(ends_ok, "{label}: the replay did not end where the prover's generator did");
    assert!(counted_ok, "{label}: the prover's generator did not consume exactly the predicted byte count");
    assert!(shifted_differs, "{label}: the next-draw probe cannot tell a 16-byte shift");
    verified.unwrap_or_else(|e| panic!("{label}: the seeded token run does not verify: {e}"));

    // ---- NON-VACUITY ----
    let checks: [(TPert, &str); 6] = [
        (TPert::InAProxZero, "A_in"),
        (TPert::BinAfterAin, "B_in and A_in"),
        (TPert::InZeroSumReset, "H_in"),
        (TPert::ResetBeforeOut, "A_out"),
        (TPert::OutCopyAIntoH, "H_out"),
        (TPert::OutAlphaCopy, "M_out"),
    ];
    for (pert, what) in checks {
        let q = predict(pert);
        let moved = match pert {
            TPert::InAProxZero => q.a[0] != prover_in[1],
            TPert::BinAfterAin => q.b[0] != prover_in[0] && q.a[0] != prover_in[1],
            TPert::InZeroSumReset => q.h[0] != prover_in[3],
            TPert::ResetBeforeOut => q.a[l + 1] != prover_out[0],
            TPert::OutCopyAIntoH => q.h[l + 1] != prover_out[2],
            TPert::OutAlphaCopy => q.m[l + 1] != prover_out[1],
            TPert::None => false,
        };
        eprintln!("GR4 TOKEN replay [{label}]: non-vacuity {pert:?} moves the {what} root(s) = {moved}");
        assert!(moved, "{label}: the perturbation {pert:?} did not move the {what} root(s)");
    }
    eprintln!(
        "GR4 TOKEN replay [{label}]: PASS. seconds: seeded prove {prove_s:.2}, production token-run verify {verify_s:.2}, one prediction {rebuild_s:.2}, whole test {:.2}; process high-water mark {:.2} GiB [MEASURED, shared box, n=1]. Not a privacy result.",
        t_all.elapsed().as_secs_f64(),
        run::peak_rss_mib() / 1024.0
    );
}

/// B_in's statement (the run's boundary 0)
fn b0_spec_of(st: &TokenRunStatement) -> BoundarySpec {
    st.boundary_spec(0).expect("B_in's statement")
}

/// the padded plane committed at boundary k + 1: block k's padded output,
/// read from the kept witness (A_X2), so the prediction does not reuse the
/// pipeline's own plane list
fn planes_of(st: &TokenRunStatement, k: usize, _b_in: &[i16], wits: &[Witness]) -> Vec<i16> {
    let ids = Ids::new(&st.stage_shape(k).unwrap()).expect("a plane map");
    padded(&wits[k], ids.at(A_X2))
}

#[test]
#[ignore = "PR4-8: proves a one-block token run (b4 export, layer 0) on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_token_t32_l1_dense_ho00_commits_exactly_the_predicted_stream() {
    replay_token_run(&[0], true);
}

#[test]
#[ignore = "PR4-8: proves a one-block token run (b4 export, layer 0, 32 x BOS) on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_token_t32_l1_fixed_commits_exactly_the_predicted_stream() {
    replay_token_run(&[0], false);
}

#[test]
#[ignore = "PR4-8: proves a two-block token run (b4 export, layers 0 | 1) on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_token_t32_l2_dense_ho00_commits_exactly_the_predicted_stream() {
    replay_token_run(&[0, 1], true);
}

#[test]
#[ignore = "PR4-8: proves a two-block token run (b4 export, layers 0 | 1, 32 x BOS) on a seeded stream; run with --ignored --exact under the resource guard"]
fn gr4_token_t32_l2_fixed_commits_exactly_the_predicted_stream() {
    replay_token_run(&[0, 1], false);
}

/// PR4-9: one export / table set / layer range -> (identity, profile digest,
/// composed word, the statement's own header word)
fn attribution(tag: &str, export: &std::path::Path, emb: &std::path::Path, head: &std::path::Path, layers: &[u32]) {
    let p = token_parts(export, emb, head, layers, false);
    let ident = p.model.identity();
    let pdig = p.tp.digest_under(p.profile);
    let mut h = blake3::Hasher::new();
    h.update(b"hashline/token-io-calibration/v1");
    h.update(&ident);
    h.update(&pdig);
    let word: Digest = *h.finalize().as_bytes();
    // the statement's own word: a statement needs endpoint roots, which the
    // calibration word does not depend on; seal two public placeholder planes
    let sh = &p.sh;
    let (ins, outs) = endpoint_specs(sh, token_context(), &p.tp).expect("the endpoint specs");
    let in_plane = stage_in::endpoint_plane(&p.tp, &vec![p.bos; sh.tokens]);
    let out_plane = stage_out::endpoint_plane(&p.tp, p.bos);
    let (roots, _owners) = seal_endpoints(&ins, &outs, &in_plane, &out_plane, &sh.hash_tag()).expect("seal");
    let st = TokenRunStatement::new(RunShape::new(sh.clone(), layers.len(), p.profile).unwrap(), token_context(), p.digests.clone(), &p.model, &p.tables, p.bos, p.norm, SelectorVariant::PublicRow, Tier::R1_MVP, roots).unwrap_or_else(|e| panic!("{tag}: {e}"));
    let header = st.capture_header().expect("the header words");
    let same = header.calibration == word;
    let digests: Vec<String> = p.digests.iter().map(|d| thex(d)).collect();
    println!(
        "{{\"event\":\"pr4-9-attribution\",\"tag\":\"{tag}\",\"export\":\"{}\",\"emb_dir\":\"{}\",\"head_dir\":\"{}\",\"layers\":{:?},\"run_profile\":\"{}\",\"trained_statement_identity\":\"{}\",\"token_profile_digest\":\"{}\",\"calibration_word_composed\":\"{}\",\"statement_header_word_equal\":{same},\"block_digests\":{:?}}}",
        export.display(),
        emb.display(),
        head.display(),
        layers,
        p.profile,
        thex(&ident),
        thex(&pdig),
        thex(&word),
        digests
    );
    assert!(same, "{tag}: the composed calibration word is not the statement's header word");
}

#[test]
#[ignore = "PR4-9: builds the trained-model statements and token profiles of the b4 TinyLlama captures (layers {0}, {0,1}, {0..21}) from the export and the named tables; run under the resource guard"]
fn pr4_9_calibration_words_tinyllama_b4() {
    let export = tl_export();
    let head = tl_head();
    attribution("tinyllama-b4-L1", &export, &export, &head, &[0]);
    attribution("tinyllama-b4-L2", &export, &export, &head, &[0, 1]);
    attribution("tinyllama-b4-L22", &export, &export, &head, &(0..22).collect::<Vec<u32>>());
}

#[test]
#[ignore = "PR4-9: the same for the 8B b7voc0 captures (layers {0}, {0,1}); heavy; run under the resource guard"]
fn pr4_9_calibration_words_llama3_8b_b7voc0() {
    let export = match std::env::var("HL_PB_TOKEN_EXPORT_8B") {
        Ok(v) => PathBuf::from(v),
        Err(_) => PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../../results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32"),
    };
    let tio = export.join("token_io");
    attribution("llama3-8b-b7voc0-L1", &export, &tio, &tio, &[0]);
    attribution("llama3-8b-b7voc0-L2", &export, &tio, &tio, &[0, 1]);
}
