//! Simulator-boundary checks. These do not establish zero knowledge.
use hashline::field::Fp;
use hashline::merkle::{hash_pair, MerkleTree};
use hashline::ntt::NttTables;
use hashline::pcs::{self, PcsParams, ZkOpts};
use hashline::zk::ZkRng;

#[test]
fn salted_leaf_and_internal_node_share_the_same_oracle_input() {
    let column_digest = [17u8; 32];
    let salt = [29u8; 32];
    // FA8's independent-domain premise does not hold for these two roles.
    assert_eq!(pcs::salt_leaf(&column_digest, &salt), hash_pair(&column_digest, &salt));
}

#[test]
fn dummy_endpoint_paths_cannot_be_transplanted_to_a_caller_root() {
    let params = PcsParams { log_cols: 8, inv_rate: 8, num_col_checks: 256 };
    let ntt = NttTables::new(12);
    let opts = ZkOpts::standard(&params);
    let mut actual_rng = ZkRng::new(71, b"test-endpoint-hash-boundary");
    let mut dummy_rng = ZkRng::new(93, b"test-endpoint-hash-boundary");
    let mut actual = vec![Fp::ZERO; 7 * 256];
    actual[..512].fill(Fp::ONE);
    for word in &mut actual[512..] { *word = actual_rng.fp(); }
    let mut dummy = vec![Fp::ZERO; 7 * 256];
    for word in &mut dummy[512..] { *word = dummy_rng.fp(); }
    let actual = pcs::commit_zk_owned(&params, actual, &ntt, &opts, &mut actual_rng);
    let dummy = pcs::commit_zk_owned(&params, dummy, &ntt, &opts, &mut dummy_rng);
    let expected_root = actual.cm.tree.root();
    assert_ne!(expected_root, dummy.cm.tree.root());
    for index in [0, 1, 255, 256, 1023, 1024, 2047] {
        let actual_leaf = actual.cm.tree.levels[0][index];
        assert!(MerkleTree::verify_path(&expected_root, index, &actual_leaf, &actual.cm.tree.path(index)));
        let dummy_leaf = dummy.cm.tree.levels[0][index];
        let dummy_path = dummy.cm.tree.path(index);
        assert!(MerkleTree::verify_path(&dummy.cm.tree.root(), index, &dummy_leaf, &dummy_path));
        assert!(!MerkleTree::verify_path(&expected_root, index, &dummy_leaf, &dummy_path));
    }
}
