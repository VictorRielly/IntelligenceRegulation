//! CL20 round 16: the bounded old/new check for the single pure helper moved
//! in this round, `eval_many` (`hashline::layer` -> `zkp_core::ffn_v3::logup`).
//!
//! Two independent checks:
//!
//! * `eval_many_agrees_with_the_pre_move_implementation` — a differential
//!   test against a VERBATIM copy of the pre-move `hashline::layer::eval_many`
//!   (`0b2b830`, layer.rs 211-221), over a deterministic seeded sample that
//!   covers the shapes the v2 and v3 provers actually pass (1..=12 point
//!   variables, 1..=6 slices, offsets before and after the slice, an empty
//!   point, repeated slices). Exact equality on every case.
//! * `v3_layer_proof_bytes_are_unchanged` — byte identity of the whole v3
//!   layer proof on two seeded tiny fixtures. `eval_many` feeds the terminal
//!   claim values straight into the proof bytes, so any behavioural change
//!   would move these digests.
//!
//! The two frozen digests were recorded from the legacy tree at `0b2b830`
//! BEFORE the move, by the round-15 capture runs of the (now parked)
//! `hashline/tests/zk60_cl20_parity.rs`
//! (`/tmp/zk60-fable-r12/cl20/s4/capture.log`, `capture2.log`; the fixture
//! and the capture harness are that parked agent's work, preserved in
//! `results/zk60_cl20_step2c_wip.diff`), and reproduced by this test on the
//! restored clean tree before the move was made.
//!
//! Explicit seeds are PUBLIC test fixtures; T=2 and T=32 at d=f=16 with
//! deliberately tiny parameters; no security claim.

use hashline::export_v3::{derive_v3, sha256_hex, V3Dims, V3Exps, V3LayerExport, V3Witness};
use hashline::field::{Fp, Fp2};
use hashline::layer::{prove_layer_v3, verify_layer_v3, LayerParams, LayerProofV3, StatementV3};
use hashline::mle::eq_table_msb;
use hashline::ntt::NttTables;
use hashline::tables_v3::{int16out_member, Act16Fn};
use hashline::transcript::Transcript;
use rayon::prelude::*;

const DOMAIN: &[u8] = b"hashline-layer-v3";

// ---------------------------------------------------------------------------
// the differential check
// ---------------------------------------------------------------------------

/// VERBATIM copy of `hashline::layer::eval_many` as it stood at `0b2b830`
/// (layer.rs 210-220), before CL20 round 16 moved it to
/// `zkp_core::ffn_v3::logup`. Kept here, and only here, as the "old" side of
/// the differential; it is not used by the library.
fn legacy_eval_many(data: &[Fp], slices: &[(usize, usize)], point: &[Fp2]) -> Vec<Fp2> {
    let eq = eq_table_msb(point);
    slices
        .iter()
        .map(|&(off, len)| {
            assert_eq!(len, eq.len());
            data[off..off + len].par_iter().zip(eq.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b))
        })
        .collect()
}

/// The deterministic sample: an LCG over the base field, points whose
/// coordinates are full extension elements (as the transcript's challenges
/// are).
struct Lcg(u64);
impl Lcg {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0 >> 11
    }
    fn fp(&mut self) -> Fp {
        Fp::new(self.next())
    }
    fn fp2(&mut self) -> Fp2 {
        Fp2::new(self.fp(), self.fp())
    }
}

/// The moved helper equals the pre-move helper on every case of a seeded
/// sample of the argument shapes: 0 to 12 point variables, 1 to 5 slices per
/// call, offsets at the head, at an odd interior position and at the tail,
/// repeated and reversed slice lists, and an empty slice list. The real
/// prover's much larger point lengths are covered by the byte-identity test
/// below and by the four frozen CPU cases, which run the same code path.
#[test]
fn eval_many_agrees_with_the_pre_move_implementation() {
    let mut g = Lcg(20260916);
    let data: Vec<Fp> = (0..8192).map(|_| g.fp()).collect();
    let mut cases = 0usize;
    for nvars in 0..=12usize {
        let len = 1usize << nvars;
        for round in 0..3usize {
            let point: Vec<Fp2> = (0..nvars).map(|_| g.fp2()).collect();
            let mut slices: Vec<(usize, usize)> = [0usize, len / 3 + round, (data.len() - len) / 2 + round, data.len() - len]
                .into_iter()
                .filter(|&o| o + len <= data.len())
                .map(|o| (o, len))
                .collect();
            // a repeat and a reversal, so order and aliasing are covered too
            if round == 1 && !slices.is_empty() {
                slices.push(slices[0]);
                slices.reverse();
            }
            assert_eq!(zkp_core::ffn_v3::eval_many(&data, &slices, &point), legacy_eval_many(&data, &slices, &point), "nvars {nvars}, round {round}");
            cases += slices.len();
        }
    }
    assert_eq!(zkp_core::ffn_v3::eval_many(&data, &[], &[]), legacy_eval_many(&data, &[], &[]));
    assert!(cases >= 100, "the sample must cover every variable count; got {cases}");
}

// ---------------------------------------------------------------------------
// the byte-identity check
// ---------------------------------------------------------------------------

/// sha256 of `LayerProofV3::to_bytes()` of the legacy prover at `0b2b830`,
/// T2 and T32, `params()`.
const LEGACY_T2_SHA256: &str = "6132d0c493a50c070a924e5f10653a27e0738527a29f76c9ddf84ccb8c143f0e"; // 348,784 B
const LEGACY_T32_SHA256: &str = "48d142757a3062e9a0b46f0599e17978f3f63fddf0847ad3295af7398f65b4da"; // 375,344 B

fn params() -> LayerParams {
    LayerParams { log_cols: 5, inv_rate: 4, num_col_checks: 12 }
}

fn ntt(p: &LayerParams) -> NttTables {
    NttTables::new(p.log_cols + p.inv_rate.trailing_zeros())
}

/// The seeded d=f=16 synthetic layer of the identity-gap / mask diagnostics
/// (LCG seed 1), derived through hashline's exact chain at `t` rows.
fn synth(t: usize) -> V3Witness {
    let (d, f) = (16usize, 16usize);
    let mut seed = 1u64;
    let mut next = |m: i64| -> i8 {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (((seed >> 33) as i64) % (2 * m + 1) - m) as i8
    };
    let x = (0..t * d).map(|_| next(127)).collect();
    let wg_t = (0..d * f).map(|_| next(4)).collect();
    let wu_t = (0..d * f).map(|_| next(4)).collect();
    let wd_t = (0..f * d).map(|_| next(4)).collect();
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let export = V3LayerExport {
        l: 0,
        dims: V3Dims { t, d, f, layers: 1 },
        x,
        wg_t,
        wu_t,
        wd_t,
        a16: vec![],
        u16: vec![],
        h16: vec![],
        z16: vec![],
        exps: V3Exps { e_x: 0, e_g: -3, e_a16: -11, e_u16: 0, e_h16: 3, e_z16: 0, e_wg: -10, e_wu: 0, e_wd: -9 },
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
        digest_checks: vec![],
    };
    let w = derive_v3(&export, t);
    assert!(w.range_ok, "the T{t} fixture must be in range");
    w
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 {
        l: w.l,
        t_rows: w.t_rows,
        d: w.dims.d,
        f: w.dims.f,
        shifts: w.shifts,
        act: w.act,
        table: w.table,
        table_digest: w.table_digest.clone(),
    }
}

fn prove(w: &V3Witness, p: &LayerParams, ntt: &NttTables) -> LayerProofV3 {
    prove_layer_v3(w, w.t_rows, p, ntt, &mut Transcript::new(DOMAIN)).proof
}

/// The v3 layer proof bytes must be exactly what the pre-move tree produced,
/// at both fixture sizes, and must still verify.
#[test]
fn v3_layer_proof_bytes_are_unchanged() {
    let p = params();
    let table = ntt(&p);
    for (t, want) in [(2usize, LEGACY_T2_SHA256), (32usize, LEGACY_T32_SHA256)] {
        let w = synth(t);
        let st = statement(&w);
        let proof = prove(&w, &p, &table);
        verify_layer_v3(&st, &proof, &p, &table, &mut Transcript::new(DOMAIN)).unwrap();
        let got = sha256_hex(&proof.to_bytes());
        assert_eq!(got, want, "T{t}: v3 layer proof digest (bytes {})", proof.size_bytes());
    }
}
