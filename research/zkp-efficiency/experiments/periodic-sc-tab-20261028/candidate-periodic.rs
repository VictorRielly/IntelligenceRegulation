// Research sketch only: UNCOMPILED, UNAPPLIED; no native integration claimed.
// Intended behind argument::Tab::PeriodicPublic, admitted only at SC_TAB.
// This is a public table representation; NEVER accept a private payload here.
use zkp_core::field::Fp2;

pub struct PeriodicPublic {
    n: usize,
    bound: usize,
    values: Vec<Fp2>, // exactly 256 fresh challenge-encoded rows initially
}
impl PeriodicPublic {
    pub fn new(n: usize, declared_len: usize, values: Vec<Fp2>) -> Result<Self, String> {
        // Narrow adapter gate; other Tab::Pub inputs remain on their old path.
        let size = 1usize.checked_shl(n as u32).filter(|_| n < usize::BITS as usize)
            .ok_or("periodic public cube")?;
        if n < 8 || values.len() != 256 || declared_len != size {
            return Err("periodic public table length".into());
        }
        Ok(Self { n, bound: 0, values })
    }
    pub fn at(&self, index: usize) -> Fp2 {
        assert!(index < (1usize << (self.n - self.bound)));
        self.values[index & (self.values.len()-1)]
    }
    pub fn bind(&mut self, r: Fp2) {
        assert!(self.bound < self.n);
        if self.n-self.bound <= 8 {
            let half=self.values.len()/2;
            let (lo,hi)=self.values.split_at_mut(half);
            for (a,b) in lo.iter_mut().zip(hi.iter()) {
                *a=a.add(r.mul(b.sub(*a)));
            }
            self.values.truncate(half);
        }
        self.bound+=1;
    }
    pub fn terminal(&self) -> Fp2 {
        assert_eq!(self.bound,self.n);
        self.values[0]
    }
}
// Owner must wire EVERY Tab match: validation, table builder/move, optional
// census, ClosureRounds adapter, verifier public evaluation and captures.
// Preserve source table order, exact n, all six private terms/pad-zero lists,
// CFS/RNG/transcript/refusals/claims/PCS. Public extension targets stay ZERO.
// Verifier: evaluate the freshly encoded 256-row MLE at rho[n-8..], then
// multiply each (1-e). Never multiply a high-coordinate equality selector:
// the lifted cube repeats rows, rather than zero-extending the 256 rows.
