//! Isolated diagnostic for the inherited PCS interface, NOT a whole-FFN exploit.
//! The fixture RNG is deterministic, but extraction receives neither its seed
//! nor any private row/pad/salt: only an authenticated clear opening vector and
//! the public transcript coefficient lambda and extension challenge e.
use hashline::field::{Fp, Fp2};
use hashline::mle::eval_mle_base;
use hashline::ntt::NttTables;
use hashline::pcs::{self, OpeningZk, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use hashline::transcript::Transcript;
use hashline::zk::ZkRng;

fn verified_singleton(pair: bool) -> (Vec<Fp>, OpeningZk, Fp2, Fp2) {
    let params = PcsParams {
        log_cols: 2,
        inv_rate: 8,
        num_col_checks: 4,
    };
    let n = params.cols();
    let ntt = NttTables::new(5);
    let mut rng = ZkRng::new(441, b"isolated-single-mask-interface-diagnostic");
    let a: Vec<Fp> = [-7, 0, 9, 17].iter().map(|v| Fp::from_i64(*v)).collect();
    // A, R_re, R_im (or unused random row), and three independent prox masks.
    let mut data = rng.fp_vec(6 * n);
    data[..n].copy_from_slice(&a);
    let e = Fp2::new(Fp::new(2), Fp::new(3));
    let rho = vec![
        Fp2::new(Fp::new(5), Fp::new(6)),
        Fp2::new(Fp::new(7), Fp::new(8)),
    ];
    let mut parts = vec![
        ZPart {
            slice: Slice {
                offset: 0,
                log_size: 2,
            },
            coef: Fp2::ONE.sub(e),
            point: rho.clone(),
        },
        ZPart {
            slice: Slice {
                offset: n,
                log_size: 2,
            },
            coef: e,
            point: rho.clone(),
        },
    ];
    let mut value = Fp2::ONE
        .sub(e)
        .mul(eval_mle_base(&a, &rho))
        .add(e.mul(eval_mle_base(&data[n..2 * n], &rho)));
    if pair {
        parts.push(ZPart {
            slice: Slice {
                offset: 2 * n,
                log_size: 2,
            },
            coef: e.mul(Fp2::U),
            point: rho.clone(),
        });
        value = value.add(e.mul(Fp2::U).mul(eval_mle_base(&data[2 * n..3 * n], &rho)));
    }
    let opts = ZkOpts::standard(&params);
    let mut cmz = pcs::commit_zk_owned(&params, data, &ntt, &opts, &mut rng);
    cmz.mask_rows = if pair { vec![1, 2] } else { vec![1] };
    cmz.prox_mask_row = Some(3);
    let cm = cmz.cm.commitment();
    let claims = vec![ZClaim { parts, value }];
    let make_tr = || {
        let mut tr = Transcript::new(b"single-mask-diagnostic");
        tr.absorb(b"root", &cm.root);
        tr.absorb_fp2(b"e-and-claim", &[e, value]);
        tr
    };
    let mut public_tr = make_tr();
    let lambda = public_tr.challenge_fp2();
    assert!(!lambda.is_zero());
    let opening = pcs::open_zk(&cmz, &claims, &mut make_tr());
    pcs::verify_zk(&params, &opts, &cm, &claims, &opening, &ntt, &mut make_tr()).unwrap();
    assert_eq!(opening.group_vecs.len(), 1);
    (a, opening, lambda, e)
}

fn extract_from_public_vector(opening: &OpeningZk, lambda: Fp2, e: Fp2) -> Vec<Fp> {
    assert!(!e.c1.is_zero());
    let ratio = e.c0.mul(e.c1.inv());
    opening.group_vecs[0][..4]
        .iter()
        .map(|v| {
            let w = v.mul(lambda.inv());
            w.c0.sub(ratio.mul(w.c1))
        })
        .collect()
}

#[test]
fn known_interface_hazard_verified_single_base_mask_reveals_entire_private_row() {
    let (a, opening, lambda, e) = verified_singleton(false);
    assert_eq!(extract_from_public_vector(&opening, lambda, e), a);
}

#[test]
fn independent_fp2_mask_pair_blocks_this_specific_coordinate_extractor() {
    let (a, opening, lambda, e) = verified_singleton(true);
    assert_ne!(extract_from_public_vector(&opening, lambda, e), a);
    // This negative control is not a full simulation/privacy proof.
}
