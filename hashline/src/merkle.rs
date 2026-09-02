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
}
