//! blake3 Merkle tree over leaves that are themselves 32-byte digests
//! (the hash of a column of the encoded matrix). Node = blake3(left || right).

use rayon::prelude::*;

pub type Digest = [u8; 32];

pub struct MerkleTree {
    /// levels[0] = leaves, levels[last] = [root]
    pub levels: Vec<Vec<Digest>>,
}

#[inline]
pub fn hash_pair(a: &Digest, b: &Digest) -> Digest {
    let mut h = blake3::Hasher::new();
    h.update(a);
    h.update(b);
    *h.finalize().as_bytes()
}

/// [ZK60 D19, ruling T-1] The same inner node under a tagged profile's NODE
/// key. `hash_pair` above keeps its own body: this is a separate entry
/// point, not a forward, so "the legacy callers are byte-identical" is a fact
/// about unchanged text. With `None` it computes the same digest `hash_pair`
/// does, which is what the isolated control in this file's tests pins.
#[inline]
pub fn hash_pair_keyed(a: &Digest, b: &Digest, key: Option<&[u8; 32]>) -> Digest {
    let mut h = crate::hashtag::hasher(key);
    h.update(a);
    h.update(b);
    *h.finalize().as_bytes()
}

/// [ZK60-METAL M9] the fewest node pairs one rayon task hashes. A task per
/// pair (rayon's default split) made a 2^16-leaf tree take 9-23 ms, slower than
/// one thread (4 ms); 1024 pairs per task take 2.4-4 ms (`m9_bench_keyed_tree_
/// over_2_16_leaves`). The same hashes in the same order: the levels are
/// unchanged, only how the work is split.
const MERKLE_MIN_PAIRS_DEFAULT: usize = 1024;

/// `HL_MERKLE_MIN_PAIRS` overrides it for a same-binary A/B (1 is rayon's
/// per-pair split, the form before M9)
fn merkle_min_pairs() -> usize {
    static N: std::sync::OnceLock<usize> = std::sync::OnceLock::new();
    *N.get_or_init(|| std::env::var("HL_MERKLE_MIN_PAIRS").ok().and_then(|v| v.parse().ok()).filter(|&v: &usize| v >= 1).unwrap_or(MERKLE_MIN_PAIRS_DEFAULT))
}

impl MerkleTree {
    pub fn build(leaves: Vec<Digest>) -> MerkleTree {
        let n = leaves.len();
        assert!(n.is_power_of_two() && n >= 1);
        let mut levels = vec![leaves];
        while levels.last().unwrap().len() > 1 {
            let prev = levels.last().unwrap();
            let next: Vec<Digest> = prev
                .par_chunks(2)
                .with_min_len(merkle_min_pairs())
                .map(|pair| hash_pair(&pair[0], &pair[1]))
                .collect();
            levels.push(next);
        }
        MerkleTree { levels }
    }

    /// [ZK60 D19, ruling T-1] `build` under a tagged profile's NODE key.
    /// `build` above keeps its own body.
    pub fn build_keyed(leaves: Vec<Digest>, key: Option<&[u8; 32]>) -> MerkleTree {
        let n = leaves.len();
        assert!(n.is_power_of_two() && n >= 1);
        let mut levels = vec![leaves];
        while levels.last().unwrap().len() > 1 {
            let prev = levels.last().unwrap();
            let next: Vec<Digest> = prev
                .par_chunks(2)
                .with_min_len(merkle_min_pairs())
                .map(|pair| hash_pair_keyed(&pair[0], &pair[1], key))
                .collect();
            levels.push(next);
        }
        MerkleTree { levels }
    }

    pub fn root(&self) -> Digest {
        self.levels.last().unwrap()[0]
    }

    pub fn num_leaves(&self) -> usize {
        self.levels[0].len()
    }

    /// Authentication path for leaf `idx`: sibling digests from leaf level up.
    pub fn path(&self, idx: usize) -> Vec<Digest> {
        let mut out = Vec::with_capacity(self.levels.len() - 1);
        let mut i = idx;
        for lvl in &self.levels[..self.levels.len() - 1] {
            out.push(lvl[i ^ 1]);
            i >>= 1;
        }
        out
    }

    pub fn verify_path(root: &Digest, mut idx: usize, leaf: &Digest, path: &[Digest]) -> bool {
        let mut cur = *leaf;
        for sib in path {
            cur = if idx & 1 == 0 { hash_pair(&cur, sib) } else { hash_pair(sib, &cur) };
            idx >>= 1;
        }
        cur == *root
    }

    /// [ZK60 D19, ruling T-1] `verify_path` under a tagged profile's NODE
    /// key. `verify_path` above keeps its own body. It still folds however
    /// many siblings it is handed — the LENGTH is the caller's check
    /// (`verify_zk_tagged` in `pcs.rs` and `zk::mask_verify_tagged` make it
    /// one). Under a tagged profile a node and a salted leaf are different
    /// functions, which stops a node posing as a leaf. It does NOT stop
    /// genuine salted leaves at two depths of one tree (D63 L3 finding F9,
    /// `formal/ZK60Formal/SoundMerkle.lean`, `mixed_depth_opens`), so without
    /// the caller's length check this path is not binding.
    pub fn verify_path_keyed(root: &Digest, mut idx: usize, leaf: &Digest, path: &[Digest], key: Option<&[u8; 32]>) -> bool {
        let mut cur = *leaf;
        for sib in path {
            cur = if idx & 1 == 0 { hash_pair_keyed(&cur, sib, key) } else { hash_pair_keyed(sib, &cur, key) };
            idx >>= 1;
        }
        cur == *root
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// [ZK60-METAL M9, bench, ignored] a keyed tree over 2^16 leaves (one
    /// commitment's columns): today's per-pair rayon tasks, the same map with
    /// a minimum task length, and one thread. Prints only; checks the roots.
    #[test]
    #[ignore]
    fn m9_bench_keyed_tree_over_2_16_leaves() {
        use rayon::prelude::*;
        let key = *blake3::hash(b"m9 node key").as_bytes();
        let leaves: Vec<Digest> = (0..1u64 << 16).map(|i| *blake3::hash(&i.to_le_bytes()).as_bytes()).collect();
        let levels_with = |min: usize| -> Digest {
            let mut cur = leaves.clone();
            while cur.len() > 1 {
                cur = cur.par_chunks(2).with_min_len(min).map(|p| hash_pair_keyed(&p[0], &p[1], Some(&key))).collect();
            }
            cur[0]
        };
        for rep in 0..3 {
            let t = std::time::Instant::now();
            let a = MerkleTree::build_keyed(leaves.clone(), Some(&key)).root();
            let t_now = t.elapsed().as_secs_f64();
            let t = std::time::Instant::now();
            let b = levels_with(1024);
            let t_min = t.elapsed().as_secs_f64();
            let t = std::time::Instant::now();
            let mut cur = leaves.clone();
            while cur.len() > 1 {
                cur = cur.chunks(2).map(|p| hash_pair_keyed(&p[0], &p[1], Some(&key))).collect();
            }
            let t_one = t.elapsed().as_secs_f64();
            assert!(a == b && a == cur[0]);
            eprintln!("[M9 bench] rep {rep}: keyed tree 2^16 leaves: today {:.4} s, min-len 1024 {:.4} s, one thread {:.4} s", t_now, t_min, t_one);
        }
    }

    #[test]
    fn paths_verify_and_tampers_fail() {
        let leaves: Vec<Digest> = (0..64u64).map(|i| *blake3::hash(&i.to_le_bytes()).as_bytes()).collect();
        let t = MerkleTree::build(leaves.clone());
        let root = t.root();
        for i in 0..64 {
            let p = t.path(i);
            assert_eq!(p.len(), 6);
            assert!(MerkleTree::verify_path(&root, i, &leaves[i], &p));
            assert!(!MerkleTree::verify_path(&root, i ^ 1, &leaves[i], &p));
            let mut bad = leaves[i];
            bad[0] ^= 1;
            assert!(!MerkleTree::verify_path(&root, i, &bad, &p));
        }
    }

    /// [ZK60 D19, ruling T-6] **The Merkle node's isolated control**, and
    /// the tree built under a key. A node computed under the right key,
    /// another role's key and no key are pairwise different; a keyed tree's
    /// path verifies under its own key and FAILS under any other, including
    /// the legacy rule.
    #[test]
    fn a_keyed_node_separates_and_a_wrong_node_key_fails_the_path() {
        let tag = crate::hashtag::HashTag::for_profile("hashline-zk-mr1/private-block-rung-g-t24-dev/1");
        let (node, leaf) = (tag.node_key(), tag.leaf_key());
        let (a, b) = ([3u8; 32], [5u8; 32]);
        let right = hash_pair_keyed(&a, &b, node);
        let wrong_role = hash_pair_keyed(&a, &b, leaf);
        let unkeyed = hash_pair_keyed(&a, &b, None);
        assert_eq!(unkeyed, hash_pair(&a, &b), "the unkeyed keyed-variant is not the legacy node");
        assert_ne!(right, wrong_role, "the node and leaf keys gave the same node");
        assert_ne!(right, unkeyed, "the node key gave the legacy node");
        assert_ne!(wrong_role, unkeyed, "the leaf key gave the legacy node");
        let leaves: Vec<Digest> = (0..16u64).map(|i| *blake3::hash(&i.to_le_bytes()).as_bytes()).collect();
        let t = MerkleTree::build_keyed(leaves.clone(), node);
        let root = t.root();
        assert_ne!(root, MerkleTree::build(leaves.clone()).root(), "the keyed tree has the legacy root");
        for i in 0..16 {
            let p = t.path(i);
            assert_eq!(p.len(), 4);
            assert!(MerkleTree::verify_path_keyed(&root, i, &leaves[i], &p, node), "the keyed path fails under its own key");
            assert!(!MerkleTree::verify_path_keyed(&root, i, &leaves[i], &p, leaf), "the keyed path verified under another role's key");
            assert!(!MerkleTree::verify_path(&root, i, &leaves[i], &p), "the keyed path verified under the legacy rule");
        }
    }
}
