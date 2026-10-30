impl Shape{
    pub(crate) fn a_plane_doms(&self) -> Vec<Dom> {
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            let h24=self.accuracy_stack()==super::accuracy_precision::Stack::LowH24;
            let mut v=vec![Dom::T;4];v.extend([Dom::Ht;2]);v.extend([Dom::L;2]);
            v.extend(vec![Dom::D;if h24 {39} else {38}]);v.extend([Dom::Q;14]);v.extend([Dom::Kv;14]);
            v.extend(vec![Dom::S;if self.dd_cap>0 {7} else {9+2*self.limbs_sigma_s()}]);v.extend([Dom::F;16]);
            if self.dd_cap>0 {v.extend(vec![Dom::Dd;4+2*self.limbs_sigma_s()]);}
            v.extend([Dom::Tab;3]);return v;
        }

        let ln = self.limbs_norm();
        let mut v = vec![Dom::T; 4];
        v.extend([Dom::Ht; 2]);
        v.extend([Dom::L; 2]);
        // Dom::D: x, its two limbs, y; norm_a's rho and sigma limbs; the
        // attention output and residual 1 with their limbs; norm_m's rho and
        // sigma limbs; z16, residual 2 and the down-projection remainder
        v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);
        v.extend([Dom::Q; 7]);
        v.extend([Dom::Kv; 6]);
        if self.dd_cap > 0 {
            // NATIVE R9 (D30): a score entry keeps S8, RSL, ZSEL, E and P and
            // drops its own quotient / remainder limbs; the dictionary carries
            // them, per slot, with the quotient itself and the multiplicity —
            // committed in `A`, before every LogUp challenge (B-2), and BELOW
            // the three histograms (CHECK.md E-1)
            v.extend([Dom::S; 5]);
            v.extend([Dom::F; 11]);
            v.extend(vec![Dom::Dd; 2 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
        } else {
            v.extend(vec![Dom::S; 5 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
            v.extend([Dom::F; 11]);
        }
        v.extend([Dom::Tab; 3]);
        v
    }
}
