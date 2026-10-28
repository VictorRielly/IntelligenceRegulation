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

impl MerkleTree {
    pub fn build(leaves: Vec<Digest>) -> MerkleTree {
        let n = leaves.len();
        assert!(n.is_power_of_two() && n >= 1);
        let mut levels = vec![leaves];
        while levels.last().unwrap().len() > 1 {
            let prev = levels.last().unwrap();
            let next: Vec<Digest> = prev
                .par_chunks(2)
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
                .map(|pair| hash_pair_keyed(&pair[0], &pair[1], key))
                .collect();
            levels.push(next);
        }
        MerkleTree { levels }
    }

    /// Research candidate: retain every level, fuse salting and first parent.
    /// Native build, byte/receipt, failure, privacy and timing gates still owed.
    pub fn build_salted_keyed(leaves: &[Digest], salts: &[Digest], leaf_key: Option<&Digest>, node_key: Option<&Digest>) -> MerkleTree {
        let n = leaves.len();
        assert!(n.is_power_of_two() && n >= 1 && salts.len() == n);
        if n == 1 {
            return MerkleTree { levels: vec![vec![crate::pcs::salt_leaf_keyed(&leaves[0], &salts[0], leaf_key)]] };
        }
        let mut pairs: Vec<[Digest; 2]> = Vec::new();
        let mut first: Vec<Digest> = Vec::new();
        leaves.par_chunks(2).zip(salts.par_chunks(2)).map(|(l, s)| {
            let a = crate::pcs::salt_leaf_keyed(&l[0], &s[0], leaf_key);
            let b = crate::pcs::salt_leaf_keyed(&l[1], &s[1], leaf_key);
            let p = hash_pair_keyed(&a, &b, node_key);
            ([a, b], p)
        }).unzip_into_vecs(&mut pairs, &mut first);
        // Stable since Rust 1.80; reuses the pair buffer without a copy.
        // Indexed Rayon unzip fills both outputs without explicit zeroing.
        let mut levels = vec![pairs.into_flattened(), first];
        while levels.last().unwrap().len() > 1 {
            let prev = levels.last().unwrap();
            let next: Vec<Digest> = prev.par_chunks(2)
                .map(|pair| hash_pair_keyed(&pair[0], &pair[1], node_key)).collect();
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
    /// (`verify_zk_tagged` in `pcs.rs` makes it one) — but under a tagged
    /// profile a node and a salted leaf are no longer the same function, so
    /// the depth confusion the disposition describes needs a key it does not
    /// have.
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
