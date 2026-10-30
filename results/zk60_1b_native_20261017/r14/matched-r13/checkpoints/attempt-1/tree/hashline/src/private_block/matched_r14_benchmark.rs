//! Matched public synthetic two-block R13 baseline, accepted source unchanged.
use super::accuracy_groups::Group;
use super::accuracy_public::{AccuracyPublic, Geometry, Multipliers};
use super::layout::*;
use super::shape::{self, NormCalibration, Shape};
use super::*;
use super::{
    run, trained_statement,
    witness::{self, Witness},
};
const FIXTURE_HELPERS_SHA256: &str =
    "9bce20f3bc9f97592db66bbbef9a307529604dbf46980bac9dce43c3a1ad8c96";
pub(super) fn calibration() -> NormCalibration {
    NormCalibration {
        tn: 9,
        cn_a: 100,
        cn_m: 100,
        ceps: 1,
        sh_ao: 7,
        sh_qkv: 8,
        sh_s: 6,
        sh_o: 9,
        sh_g: 8,
        sh_h: 14,
        sh_z: 6,
    }
}
pub(super) fn data(sh: &Shape) -> AccuracyPublic {
    let values = |n: usize, max: usize| (0..n).map(|j| (1 + (j * 37 + 11) % max) as u16).collect();
    let groups = vec![
        Group {
            e_in: -4,
            e_out: -13,
        },
        Group {
            e_in: -1,
            e_out: -11,
        },
    ];
    let tables = groups
        .iter()
        .map(|g| {
            accuracy_tables::silu_table_for(sh.accuracy_registry(), g.e_in, g.e_out, 12).unwrap()
        })
        .collect();
    AccuracyPublic::new_with_registry(
        sh.accuracy_registry(),
        sh.accuracy_stack(),
        Geometry {
            width: sh.width,
            query_width: sh.q_width(),
            kv_width: sh.kv_heads * sh.head_dim,
            hidden: sh.hidden,
        },
        sh.accuracy_base(),
        (-3, -11),
        Multipliers {
            q: values(sh.q_width(), 32),
            k: values(sh.kv_heads * sh.head_dim, 32),
            v: values(sh.kv_heads * sh.head_dim, 64),
            o: values(sh.width, 256),
            g: values(sh.hidden, 64),
            u: values(sh.hidden, 16),
            d: values(sh.width, 64),
        },
        groups,
        (0..sh.hidden).map(|j| usize::from(j >= 8192)).collect(),
        tables,
    )
    .unwrap()
}
fn matrix(rows: usize, cols: usize, live_rows: usize, live_cols: usize) -> Vec<i8> {
    let mut v = vec![0; rows * cols];
    // Sparse but nonzero on both sides of each true piece boundary. The
    // separate geometry gate supplies dense public-fold differential cases.
    for r in [0, live_rows / 2, live_rows - 1] {
        for c in [0, live_cols / 2, live_cols - 1] {
            v[r * cols + c] = ((r + c) % 253) as i16 as i8;
            if v[r * cols + c] == -128 {
                v[r * cols + c] = 127;
            }
        }
    }
    v
}
pub(super) fn public(sh: &Shape) -> (AttentionPublic, FeedForwardPublic) {
    let kv = sh.kv_heads * sh.head_dim;
    let a = AttentionPublic {
        wq: matrix(sh.q_pad(), sh.d_pad, sh.q_pad(), sh.width),
        wk: matrix(kv, sh.d_pad, kv, sh.width),
        wv: matrix(kv, sh.d_pad, kv, sh.width),
        wo: matrix(sh.d_pad, sh.q_pad(), sh.width, sh.q_pad()),
        gamma_a: (0..sh.d_pad)
            .map(|j| {
                if j < sh.width {
                    (j % 255) as i16 as i8
                } else {
                    0
                }
            })
            .collect(),
        rope_cos: vec![127; sh.tokens * sh.head_dim / 2],
        rope_sin: vec![0; sh.tokens * sh.head_dim / 2],
        exp: vec![1; 256],
    };
    let f = FeedForwardPublic {
        gamma_m: a.gamma_a.clone(),
        wg_t: matrix(sh.d_pad, sh.f_pad, sh.width, sh.hidden),
        wu_t: matrix(sh.d_pad, sh.f_pad, sh.width, sh.hidden),
        wd_t: matrix(sh.f_pad, sh.d_pad, sh.hidden, sh.width),
        act: [0; 256],
    };
    (a, f)
}
fn fixture(
    dd: bool,
) -> (
    Shape,
    Vec<BlockPublic>,
    trained_statement::TrainedModelStatement,
) {
    let base = if dd {
        shape::R13_SHIELD_T128_H24_DD
    } else {
        shape::R13_SHIELD_T128_H24
    };
    let sh = Shape::accuracy_trained(base, &calibration(), 9, 20).unwrap();
    let (mut a, mut f) = public(&sh);
    a.rope_cos.fill(1i64 << F_RO);
    a.exp.fill(1i64 << sh.f_e);
    for j in 0..sh.width {
        a.gamma_a[j] = ((j % 255) as i16 - 127) as i8;
        f.gamma_m[j] = a.gamma_a[j];
    }
    let block = BlockPublic::new(a, f).with_accuracy(data(&sh));
    let blocks = vec![block.clone(), block];
    let mut model = trained_statement::accuracy_hash_model(&sh, 2);
    let digest = blocks[0].digest();
    for record in &mut model.layers {
        record.block_digest = digest;
    }
    let mut next = sh.norm_calibration();
    next.cn_a += 1;
    model.layers[1].own = trained_statement::own_of(&sh.norm_calibration(), &next);
    (sh, blocks, model)
}

struct Source<'a> {
    first: Option<Witness>,
    next: Shape,
    input: Vec<i16>,
    blocks: &'a [BlockPublic],
    boundary: Vec<i16>,
}
impl run::RunWitnessSource for Source<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        match k {
            0 => self
                .first
                .take()
                .ok_or_else(|| "first witness consumed".into()),
            1 => witness::build_for_block(&self.next, &self.blocks[1], &self.input),
            _ => Err("two stages only".into()),
        }
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        if k != 1 {
            return Err("one internal boundary only".into());
        }
        Ok(self.boundary.clone())
    }
}
fn dense(sh: &Shape, w: &Witness, parent: usize) -> Vec<i16> {
    (0..sh.tokens)
        .flat_map(|t| {
            (0..sh.width).map(move |j| i16::try_from(w.planes[parent][t * sh.d_pad + j]).unwrap())
        })
        .collect()
}
fn padded(w: &Witness, parent: usize) -> Vec<i16> {
    w.planes[parent]
        .iter()
        .map(|&v| i16::try_from(v).unwrap())
        .collect()
}
fn case(dd: bool) {
    let (sh, blocks, model) = fixture(dd);
    let scales = vec![model.calibration.block_scales; 2];
    let ids = Ids::new(&sh).unwrap();
    let next = model.layers[1].shape_at(&sh).unwrap();
    let input = (0..sh.tokens * sh.width)
        .map(|j| if j % 2 == 0 { 1i16 } else { -1i16 })
        .collect::<Vec<_>>();
    let first = witness::build_for_block(&sh, &blocks[0], &input).unwrap();
    let pin = padded(&first, ids.at(A_X));
    let boundary = padded(&first, ids.at(A_X2));
    let intermediate = dense(&sh, &first, ids.at(A_X2));
    let second = witness::build_for_block(&next, &blocks[1], &intermediate).unwrap();
    let pout = padded(&second, ids.at(A_X2));
    drop(second);
    let spec = IoSpec::new_shaped(&sh, [107; 32], scales[0].0, scales[1].1).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout).unwrap();
    let st = run::RunStatement::new_bound(
        run::RunShape::accuracy(sh.clone(), 2).unwrap(),
        [107; 32],
        expected,
        &blocks,
        &scales,
        &model,
    )
    .unwrap();
    let mut source = Source {
        first: Some(first),
        next,
        input: intermediate,
        blocks: &blocks,
        boundary,
    };
    let mut frames = Vec::new();
    let tick = std::time::Instant::now();
    run::prove_run(&st, &blocks, &mut source, owners, &mut |k, bytes| {
        assert_eq!(k, frames.len());
        frames.push(bytes);
        Ok(())
    })
    .unwrap();
    let prove_seconds = tick.elapsed().as_secs_f64();
    let tick = std::time::Instant::now();
    run::verify_run(&st, &blocks, &frames).unwrap();
    let verify_seconds = tick.elapsed().as_secs_f64();
    let hex = |d: &[u8]| d.iter().map(|b| format!("{b:02x}")).collect::<String>();
    eprintln!("R13_MATCHED_STREAM {{\"dd\":{},\"tokens\":128,\"blocks\":2,\"prove_seconds\":{},\"verify_seconds\":{},\"process_hwm_mib\":{},\"bytes\":{:?},\"model_identity\":{:?},\"block_digest\":{:?},\"fixture_helpers_sha256\":{:?},\"scope\":\"accepted R13 native source plus test-only exact R14 public synthetic fixture, same2layer calibrations; n1 sharedhost, not approved trained-model performance\"}}",dd,prove_seconds,verify_seconds,run::peak_rss_mib(),frames.iter().map(Vec::len).collect::<Vec<_>>(),hex(&model.identity()),hex(&blocks[0].digest()),FIXTURE_HELPERS_SHA256);
}
#[test]
#[ignore = "separate guarded matched R13 T128 baseline9.5GiB"]
fn r14_matched_r13_t128_non_dd_two_blocks() {
    case(false)
}
#[test]
#[ignore = "separate guarded matched R13 T128 baseline9.5GiB"]
fn r14_matched_r13_t128_dd_two_blocks() {
    case(true)
}
