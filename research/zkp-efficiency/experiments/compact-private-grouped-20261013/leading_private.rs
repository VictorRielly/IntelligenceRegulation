//! UNCOMPILED / UNAPPLIED research sketch. Include beside argument.rs after
//! adding a Leading variant to the owner-reviewed mixed Table entry type.
//! Keep the original Tab::Priv metadata, ordered finals, mask sites and
//! extension code. Call only for SC_SZC A_MX/A_SUM selected from Layout ids.
//! No source-value test, external lift attestation, or private mask cache.
use super::{Cm, Coord, Priv, ProverData};
use crate::field::Fp2;

pub(super) struct LeadingPrivate {
    n: usize,
    leading: usize,
    bound: usize,
    words: Vec<Fp2>,
}

impl LeadingPrivate {
    pub(super) fn try_from_priv(p: &Priv, n: usize, pd: &ProverData)
        -> Result<Option<Self>, String>
    {
        // Native slot/plane selection and all existing shape checks happen
        // first. Unsupported public mappings use the original priv_table.
        if n >= usize::BITS as usize || p.log > n || p.cm != Cm::A ||
           p.ext_round != 0 || p.coords.len() != p.log || p.slices.len() != 1 ||
           p.slices[0].1 != Fp2::ONE ||
           !p.coords.iter().enumerate().all(|(i,c)| matches!(c,Coord::Rho(k) if *k==i))
        { return Ok(None); }
        let count = 1usize.checked_shl(p.log as u32)
            .ok_or("leading private: dimension overflow")?;
        let off = p.slices[0].0;
        let end = off.checked_add(count).ok_or("leading private: range overflow")?;
        let src = pd.data[p.cm as usize].get(off..end)
            .ok_or("leading private: source bounds")?;
        // Exact existing one_slice/simple priv_table branch, without N-word
        // zero fill, source index maps or trailing-axis broadcast.
        let words = src.iter().copied().map(Fp2::from_base).collect();
        Ok(Some(Self { n, leading:p.log, bound:0, words }))
    }
    pub(super) fn at(&self, index: usize) -> Fp2 {
        assert!(index < (1usize << (self.n-self.bound)));
        if self.bound < self.leading { self.words[index >> (self.n-self.leading)] }
        else { self.words[0] }
    }
    pub(super) fn bind(&mut self, rho: Fp2) {
        assert!(self.bound < self.n);
        if self.bound < self.leading {
            let half=self.words.len()/2;
            for i in 0..half {
                let a=self.words[i];
                self.words[i]=a.add(rho.mul(self.words[i+half].sub(a)));
            }
            self.words.truncate(half);
        }
        self.bound+=1;
    }
    pub(super) fn terminal(&self) -> Fp2 {
        assert_eq!(self.bound,self.n);
        self.words[0]
    }
}
