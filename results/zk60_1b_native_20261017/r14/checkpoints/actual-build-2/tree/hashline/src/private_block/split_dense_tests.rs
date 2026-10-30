//! Full true-support signed matrices and varying public input. This is a
//! synthetic arithmetic/geometry gate, separate from actual-model acceptance.
use super::split_definition_tests::{calibration, data, public};
use super::*;
use crate::private_block::{
    shape,
    split_profile::SplitProfile,
    split_witness::PieceWitness,
    trained_block::{hex, sha256},
    witness, BlockPublic,
};

fn sign(r: usize, c: usize, seed: u32) -> i8 {
    let v = (r as u32)
        .wrapping_mul(1103515245)
        .wrapping_add((c as u32).wrapping_mul(12345))
        .wrapping_add(((r ^ c) as u32).wrapping_mul(2654435761))
        .wrapping_add(seed);
    if (v >> 16) & 1 == 0 {
        -1
    } else {
        1
    }
}
fn fill(
    matrix: &mut [i8],
    rows: usize,
    cols: usize,
    true_rows: usize,
    true_cols: usize,
    seed: u32,
) {
    assert_eq!(matrix.len(), rows * cols);
    matrix.fill(0);
    for r in 0..true_rows {
        for c in 0..true_cols {
            matrix[r * cols + c] = sign(r, c, seed);
        }
    }
}
fn setup(dd: bool) -> (Shape, BlockPublic, Vec<i16>) {
    let mut cal = calibration();
    cal.sh_qkv = 2;
    cal.sh_s = 7;
    let sh = Shape::accuracy_trained(
        if dd {
            shape::R13_SHIELD_T128_H24_DD
        } else {
            shape::R13_SHIELD_T128_H24
        },
        &cal,
        9,
        20,
    )
    .unwrap();
    let (mut a, mut f) = public(&sh);
    let kv = sh.kv_heads * sh.head_dim;
    fill(&mut a.wq, sh.q_pad(), sh.d_pad, sh.q_pad(), sh.width, 101);
    fill(&mut a.wk, kv, sh.d_pad, kv, sh.width, 211);
    fill(&mut a.wv, kv, sh.d_pad, kv, sh.width, 307);
    fill(&mut a.wo, sh.d_pad, sh.q_pad(), sh.width, sh.q_pad(), 401);
    fill(&mut f.wg_t, sh.d_pad, sh.f_pad, sh.width, sh.hidden, 503);
    fill(&mut f.wu_t, sh.d_pad, sh.f_pad, sh.width, sh.hidden, 601);
    fill(&mut f.wd_t, sh.f_pad, sh.d_pad, sh.hidden, sh.width, 701);
    for j in 0..sh.width {
        a.gamma_a[j] = ((j % 255) as i16 - 127) as i8;
        f.gamma_m[j] = a.gamma_a[j];
    }
    let (cos, sin) =
        crate::tables_attn::rope_tables_generate(sh.tokens, sh.head_dim, 10000.0, F_RO);
    a.rope_cos = cos;
    a.rope_sin = sin;
    a.exp = crate::tables_attn::exp_table_generate(2, sh.head_dim, sh.f_e).to_vec();
    let input = (0..sh.tokens)
        .flat_map(|t| (0..sh.width).map(move |j| sign(t, j, 809) as i16))
        .collect();
    (
        sh.clone(),
        BlockPublic::new(a, f).with_accuracy(data(&sh)),
        input,
    )
}
const SITES: [(&str, usize); 19] = [
    ("input", A_X),
    ("y", A_Y),
    ("q", A_Q8),
    ("k", A_K8),
    ("v", A_V8),
    ("qr", A_QR8),
    ("kr", A_KR8),
    ("s", A_S8),
    ("p", A_P),
    ("o", A_O8),
    ("ao", A_AO),
    ("x1", A_X1),
    ("nm", A_YM),
    ("gate", A_G8),
    ("a_scaled", A_A16),
    ("up", A_U16),
    ("h", A_H16),
    ("z", A_Z16),
    ("x2", A_X2),
];

#[test]
#[ignore = "guarded generic dense true-support Shieldstral R14 proof, explicit HL_R14_DD"]
fn split_generic_dense_t128_native_receipt_and_physical_trace() {
    let dd = match std::env::var("HL_R14_DD").unwrap().as_str() {
        "0" => false,
        "1" => true,
        _ => panic!("explicit DD0/1"),
    };
    let (sh, blk, input) = setup(dd);
    let ids = Ids::new(&sh).unwrap();
    let w = witness::build_for_block(&sh, &blk, &input).unwrap();
    let scores = &w.planes[ids.at(A_S8)];
    assert!(
        scores.iter().any(|&v| v < 0) && scores.iter().any(|&v| v > 0),
        "generic scores lack both signs"
    );
    for (role, pad, width, start) in [
        (A_Y, sh.d_pad, sh.width, 2048),
        (A_H16, sh.f_pad, sh.hidden, 8192),
    ] {
        for range in [0..start, start..width] {
            assert!(
                (0..sh.tokens).any(|t| w.planes[ids.at(role)]
                    [t * pad + range.start..t * pad + range.end]
                    .iter()
                    .any(|&v| v != 0)),
                "true piece is all zero"
            );
        }
    }
    if let Ok(path) = std::env::var("HL_R14_DENSE_TRACE_OUTPUT") {
        let dir = std::path::PathBuf::from(path);
        assert!(!dir.exists());
        std::fs::create_dir_all(&dir).unwrap();
        for (name, old) in SITES {
            let parent = ids.at(old);
            let v =
                super::split_actual_tests::native_dense(&sh, ids.dom(parent), &w.planes[parent]);
            let bytes = v.iter().flat_map(|v| v.to_le_bytes()).collect::<Vec<_>>();
            std::fs::write(dir.join(format!("{name}.i64")), &bytes).unwrap();
            eprintln!(
                "R14_GENERIC_TRACE {{\"dd\":{},\"site\":{:?},\"words\":{},\"sha256\":{:?}}}",
                dd,
                name,
                v.len(),
                hex(&sha256(&bytes))
            );
        }
        // Public arrays only: these are inputs to the independent reference,
        // not unmasked values from a private transcript.
        for (name, words) in [
            ("wq", &blk.attention().wq),
            ("wk", &blk.attention().wk),
            ("wv", &blk.attention().wv),
            ("wo", &blk.attention().wo),
            ("wg_t", &blk.feed_forward().wg_t),
            ("wu_t", &blk.feed_forward().wu_t),
            ("wd_t", &blk.feed_forward().wd_t),
            ("gamma_a", &blk.attention().gamma_a),
            ("gamma_m", &blk.feed_forward().gamma_m),
        ] {
            std::fs::write(
                dir.join(format!("{name}.i8")),
                words.iter().map(|&v| v as u8).collect::<Vec<_>>(),
            )
            .unwrap();
        }
        for (name, words) in [
            ("rope_cos", &blk.attention().rope_cos),
            ("rope_sin", &blk.attention().rope_sin),
            ("exp", &blk.attention().exp),
        ] {
            std::fs::write(
                dir.join(format!("{name}.i64")),
                words
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            )
            .unwrap();
        }
        std::fs::write(dir.join("accuracy.bin"), blk.accuracy().unwrap().encode()).unwrap();
        let a = blk.accuracy().unwrap();
        let m = a.multipliers();
        for (name, words) in [
            ("m_q", &m.q),
            ("m_k", &m.k),
            ("m_v", &m.v),
            ("m_o", &m.o),
            ("m_g", &m.g),
            ("m_u", &m.u),
            ("m_d", &m.d),
        ] {
            std::fs::write(
                dir.join(format!("{name}.u16")),
                words
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            )
            .unwrap();
        }
        std::fs::write(
            dir.join("act.i16"),
            a.raw_tables()
                .iter()
                .flatten()
                .flat_map(|v| v.to_le_bytes())
                .collect::<Vec<_>>(),
        )
        .unwrap();
        std::fs::write(
            dir.join("group_ids.i64"),
            a.group_ids()
                .iter()
                .flat_map(|&v| (v as i64).to_le_bytes())
                .collect::<Vec<_>>(),
        )
        .unwrap();
        std::fs::write(
            dir.join("groups.i32"),
            a.groups()
                .iter()
                .flat_map(|g| [g.e_in, g.e_out])
                .flat_map(|v| v.to_le_bytes())
                .collect::<Vec<_>>(),
        )
        .unwrap();
    }
    let profile = SplitProfile::new(sh.clone()).unwrap();
    let mut expected = Vec::new();
    for (name, old) in SITES {
        let parent = ids.at(old);
        let v = super::split_actual_tests::native_dense(&sh, ids.dom(parent), &w.planes[parent]);
        expected.push((
            name,
            hex(&sha256(
                &v.iter().flat_map(|v| v.to_le_bytes()).collect::<Vec<_>>(),
            )),
        ));
    }
    let packed = PieceWitness::from_reference(&profile, w).unwrap();
    for ((name, old), (_, want)) in SITES.into_iter().zip(expected) {
        let v = super::split_actual_tests::piece_dense(&profile, &packed, ids.at(old));
        assert_eq!(
            hex(&sha256(
                &v.iter().flat_map(|v| v.to_le_bytes()).collect::<Vec<_>>()
            )),
            want,
            "generic physical {name}"
        );
    }
    drop(packed);
    let w = witness::build_for_block(&sh, &blk, &input).unwrap();
    super::split_attack_tests::emit(sh, blk, w, 0, "generic-dense", true);
}
