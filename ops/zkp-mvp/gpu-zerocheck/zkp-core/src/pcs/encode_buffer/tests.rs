use super::*;
use crate::pcs::*;
use crate::rng::ZkRng;

fn old_matrix(ntt: &NttTables, data: &[Fp], n: usize, pads: &[Fp], q: usize, pows: &[Fp]) -> Vec<Fp> {
    let nn = pows.len();
    let mut out = vec![Fp::ZERO; data.len() / n * nn];
    for (r, row) in out.chunks_mut(nn).enumerate() {
        encode_row_zk(ntt, &data[r * n..(r + 1) * n], &pads[r * q..(r + 1) * q], pows, row);
    }
    out
}

#[test]
fn initialized_matrix_matches_original_at_boundaries_and_in_parallel() {
    for threads in [1, 2] {
        rayon::ThreadPoolBuilder::new().num_threads(threads).build().unwrap().install(|| {
            let mut rng = ZkRng::new(77, b"R2a matrix oracle");
            // Includes no zero tail, q == n, q > n, and the 2^14 row.
            for (n, q, nn) in [(1, 1, 2), (1, 7, 8), (2, 3, 8), (4, 4, 8), (4, 12, 16), (16, 3, 64), (64, 32, 256), (256, 256, 2048), (1024, 256, 4096), (16384, 256, 65536)] {
                let ntt = NttTables::new((nn as usize).trailing_zeros());
                let pows = coset_powers(Fp::new(7), nn);
                for rows in [1, 3, 7] {
                    let data = rng.fp_vec(rows * n);
                    let pads = rng.fp_vec(rows * q);
                    let expected = old_matrix(&ntt, &data, n, &pads, q, &pows);
                    assert_eq!(encode_rows(&ntt, &data, n, &pads, q, &pows), expected, "n={n} q={q} nn={nn} rows={rows} threads={threads}");
                    // A second allocation of the same shape cannot inherit data.
                    let zero = vec![Fp::ZERO; data.len()];
                    assert_eq!(encode_rows(&ntt, &zero, n, &pads, q, &pows), old_matrix(&ntt, &zero, n, &pads, q, &pows));
                }
            }
        });
    }
}

#[test]
fn initializer_writes_every_position_and_stays_inside_its_row() {
    let ntt = NttTables::new(6);
    let pows = coset_powers(Fp::new(7), 64);
    let mut rng = ZkRng::new(991, b"R2a poisoned row");
    let data = rng.fp_vec(16);
    let pads = rng.fp_vec(8);
    let expected = old_matrix(&ntt, &data, 16, &pads, 8, &pows);
    for poison in [Fp::ZERO, Fp::new(0xa5a5_a5a5_a5a5_a5a5)] {
        let mut surrounded = vec![MaybeUninit::new(poison); 66];
        let row = initialize_row(&ntt, &data, &pads, &pows, &mut surrounded[1..65]);
        assert!(row[24..].iter().all(|x| *x == Fp::ZERO));
        ntt.forward(row);
        assert_eq!(row, &expected);
        // SAFETY: both sentinels were initialized before calling the helper,
        // and the mutable slice passed to it excludes them.
        assert_eq!(unsafe { surrounded[0].assume_init() }, poison);
        assert_eq!(unsafe { surrounded[65].assume_init() }, poison);
    }
}

#[test]
fn invalid_shapes_refuse_before_any_uninitialized_reference() {
    let ntt = NttTables::new(6);
    let data = vec![Fp::ONE; 16];
    let pads = vec![Fp::ONE; 8];
    let pows = coset_powers(Fp::new(7), 64);
    let cases = [
        (0, 8, &data[..], &pads[..], &pows[..]),
        (3, 8, &data[..], &pads[..], &pows[..]),
        (16, 8, &data[..15], &pads[..], &pows[..]),
        (16, 8, &data[..], &pads[..7], &pows[..]),
        (16, 0, &data[..], &pads[..0], &pows[..]),
        (16, usize::MAX, &data[..], &pads[..], &pows[..]),
        (16, 8, &data[..], &pads[..], &pows[..16]),
        (16, 8, &data[..], &pads[..], &pows[..63]),
        (16, 8, &data[..0], &pads[..0], &pows[..]),
    ];
    for (n, q, data, pads, pows) in cases {
        assert!(std::panic::catch_unwind(|| encode_rows(&ntt, data, n, pads, q, pows)).is_err());
    }
    let short = NttTables::new(4);
    assert!(std::panic::catch_unwind(|| encode_rows(&short, &data, 16, &pads, 8, &pows)).is_err());
}

#[test]
fn tagged_commitment_matches_old_encoding_tree_and_rng_continuation() {
    for tag in [HashTag::legacy(), HashTag::for_profile("hashline-zk-mr1/private-block-rung-g-t24-dev/1")] {
        for (log_n, rows, q) in [(4, 3, 8), (8, 17, 256), (14, 3, 256)] {
            let p = PcsParams { log_cols: log_n, inv_rate: 4, num_col_checks: q };
            let ntt = NttTables::new(p.enc_cols().trailing_zeros());
            let zk = ZkOpts { q_pad: q, coset: Fp::new(7) };
            let mut data_rng = ZkRng::new(23, b"R2a data");
            let data = data_rng.fp_vec(rows * p.cols());
            let mut old_rng = ZkRng::new(17, b"R2a pads and salts");
            let pads = old_rng.fp_vec(rows * q);
            let salts: Vec<_> = (0..p.enc_cols()).map(|_| old_rng.bytes32()).collect();
            let pows = coset_powers(zk.coset, p.enc_cols());
            let encoded = old_matrix(&ntt, &data, p.cols(), &pads, q, &pows);
            let leaves = hash_columns_keyed(&encoded, rows, p.enc_cols(), tag.column_key());
            let salted: Vec<_> = leaves.iter().zip(&salts).map(|(l,s)| salt_leaf_keyed(l,s,tag.leaf_key())).collect();
            let tree = crate::merkle::MerkleTree::build_keyed(salted, tag.node_key());
            let mut new_rng = ZkRng::new(17, b"R2a pads and salts");
            let new = commit_zk_owned_with_tag(&Cpu, &p, data.clone(), &ntt, &zk, &mut new_rng, &tag);
            let actual = match &new.cm.store { Store::Host { encoded } => encoded, _ => unreachable!() };
            assert_eq!(*actual, encoded);
            assert_eq!(new.data, data);
            assert_eq!(new.pads, pads);
            assert_eq!(new.salts, salts);
            assert_eq!(new.cm.tree.root(), tree.root());
            assert_eq!(new_rng.bytes32(), old_rng.bytes32());
        }
    }
}
