//! Native regression explaining why the current endpoint owners are consumed.
//! Deliberately bypasses the consuming hashline wrapper and opens one raw PCS
//! owner twice. This is not a full FFN receipt attack or a privacy acceptance
//! test. Only synthetic data are used; recovery receives public vectors and
//! challenges, never the owner, seed, masks, pads, salts or Merkle paths.
use zkp_core::field::{Fp, Fp2};
use zkp_core::mle::eval_mle_base;
use zkp_core::ntt::NttTables;
use zkp_core::pcs::{self, CommittedZk, OpeningZk, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use zkp_core::rng::ZkRng;
use zkp_core::transcript::Transcript;

const N: usize = 256;
fn params() -> PcsParams {
    PcsParams {
        log_cols: 8,
        inv_rate: 8,
        num_col_checks: 256,
    }
}
fn owner(seed: u64, data: &[Fp], ntt: &NttTables) -> CommittedZk {
    // Mirrors private_seam's two data rows plus five random rows. Public seed
    // is fixture-only and is deliberately absent from recovery's interface.
    let mut rng = ZkRng::new(seed, b"PUBLIC endpoint reuse regression");
    let mut rows = data.to_vec();
    rows.extend(rng.fp_vec(5 * N));
    let p = params();
    let mut cm = pcs::commit_zk(&p, &rows, ntt, &ZkOpts::standard(&p), &mut rng);
    cm.mask_rows = vec![2, 3];
    cm.prox_mask_row = Some(4);
    cm
}

fn open_once(cm: &CommittedZk, use_id: u64, ntt: &NttTables) -> ([Fp2; 3], OpeningZk) {
    let transcript = || {
        let mut tr = Transcript::new(b"PUBLIC native endpoint reuse regression");
        tr.absorb(b"root", &cm.commitment().root);
        tr.absorb_u64(b"use", use_id);
        tr
    };
    let mut tr = transcript();
    let rho = tr.challenge_fp2_vec(9);
    let e = tr.challenge_fp2_vec(1)[0];
    assert!(!e.is_zero());
    let tail = rho[1..].to_vec();
    let mask = eval_mle_base(&cm.data[2 * N..3 * N], &tail)
        .add(Fp2::U.mul(eval_mle_base(&cm.data[3 * N..4 * N], &tail)));
    let value = Fp2::ONE
        .sub(e)
        .mul(eval_mle_base(&cm.data[..2 * N], &rho))
        .add(e.mul(mask));
    // Exactly the endpoint claim shape from zk_ffn_fresh_io::claim(0,2,...).
    let claim = ZClaim {
        value,
        parts: vec![
            ZPart {
                slice: Slice {
                    offset: 0,
                    log_size: 9,
                },
                coef: Fp2::ONE.sub(e),
                point: rho.clone(),
            },
            ZPart {
                slice: Slice {
                    offset: 2 * N,
                    log_size: 8,
                },
                coef: e,
                point: tail.clone(),
            },
            ZPart {
                slice: Slice {
                    offset: 3 * N,
                    log_size: 8,
                },
                coef: e.mul(Fp2::U),
                point: tail,
            },
        ],
    };
    tr.absorb_fp2(b"public-claim", &[value]);
    let replay = || {
        let mut t = transcript();
        assert_eq!(t.challenge_fp2_vec(9), rho);
        assert_eq!(t.challenge_fp2_vec(1)[0], e);
        t.absorb_fp2(b"public-claim", &[value]);
        t
    };
    let lambda = replay().challenge_fp2_vec(1)[0];
    assert!(!lambda.is_zero());
    let opening = pcs::open_zk(cm, &[claim.clone()], &mut tr);
    pcs::verify_zk(
        &params(),
        &cm.zk,
        &cm.commitment(),
        &[claim.clone()],
        &opening,
        ntt,
        &mut replay(),
    )
    .unwrap();
    let mut tampered = opening.clone();
    tampered.group_vecs[0][17] = tampered.group_vecs[0][17].add(Fp2::ONE);
    assert!(pcs::verify_zk(
        &params(),
        &cm.zk,
        &cm.commitment(),
        &[claim],
        &tampered,
        ntt,
        &mut replay()
    )
    .is_err());
    (
        [
            lambda.mul(Fp2::ONE.sub(e)).mul(Fp2::ONE.sub(rho[0])),
            lambda.mul(Fp2::ONE.sub(e)).mul(rho[0]),
            lambda.mul(e),
        ],
        opening,
    )
}

fn recover(c1: [Fp2; 3], v1: &[Fp2], c2: [Fp2; 3], v2: &[Fp2]) -> Vec<Fp> {
    // Cancel the common complex mask, then solve its two base-field equations.
    let a = c1[0].mul(c2[2]).sub(c2[0].mul(c1[2]));
    let b = c1[1].mul(c2[2]).sub(c2[1].mul(c1[2]));
    let det = a.c0.mul(b.c1).sub(a.c1.mul(b.c0));
    assert!(
        det != Fp::ZERO,
        "fixture challenge matrix unexpectedly singular"
    );
    let inv = det.inv();
    let mut result = vec![Fp::ZERO; 2 * N];
    for k in 0..N {
        let z = v1[k].mul(c2[2]).sub(v2[k].mul(c1[2]));
        result[k] = z.c0.mul(b.c1).sub(z.c1.mul(b.c0)).mul(inv);
        result[N + k] = a.c0.mul(z.c1).sub(a.c1.mul(z.c0)).mul(inv);
    }
    result
}

#[test]
fn two_native_ordinary_openings_of_one_endpoint_recover_all_512_words() {
    let ntt = NttTables::new(12);
    let data: Vec<Fp> = (0..2 * N)
        .map(|k| Fp::from_i64(((k * 191) % 65536) as i64 - 32768))
        .collect();
    let cm = owner(20260918, &data, &ntt);
    let (c1, o1) = open_once(&cm, 1, &ntt);
    let (c2, o2) = open_once(&cm, 2, &ntt);
    assert_eq!(
        recover(c1, &o1.group_vecs[0][..N], c2, &o2.group_vecs[0][..N]),
        data
    );
}

#[test]
fn independently_prepared_owners_do_not_share_the_cancelled_mask() {
    let ntt = NttTables::new(12);
    let data: Vec<Fp> = (0..2 * N).map(|k| Fp::from_i64(k as i64 - 256)).collect();
    let a = owner(71, &data, &ntt);
    let b = owner(72, &data, &ntt);
    assert_ne!(a.commitment().root, b.commitment().root);
    let (c1, o1) = open_once(&a, 1, &ntt);
    let (c2, o2) = open_once(&b, 2, &ntt);
    assert_ne!(
        recover(c1, &o1.group_vecs[0][..N], c2, &o2.group_vecs[0][..N]),
        data
    );
}
