impl Shape{
    pub(crate) fn h_plane_doms(&self) -> Vec<Dom> {
        let mut v = vec![Dom::L; self.helpers(Dom::L)];
        v.extend(vec![Dom::D; self.helpers(Dom::D)]);
        v.extend(vec![Dom::Q; self.helpers(Dom::Q)]);
        v.extend(vec![Dom::Kv; self.helpers(Dom::Kv)]);
        // the `Dom::S` helpers plus the exponential pair's own helper
        // (NATIVE R9: plus, on a DD profile, the score entry's single tuple
        // helper into its row's dictionary)
        v.extend(vec![Dom::S; self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0)]);
        // the `Dom::F` helpers plus the activation pair's own helper
        v.extend(vec![Dom::F; self.helpers(Dom::F) + 1]);
        // NATIVE R9 (D30): the dictionary's byte-lookup helpers and its TABLE
        // helper (which enters the value-0 sum claim with sign -1)
        if self.dd_cap > 0 {
            v.extend(vec![Dom::Dd; self.helpers(Dom::Dd) + 1]);
        }
        // the three table helpers and the zero-sum pair `u` (P-3 / P-6: `u`
        // stays the last plane, on `Dom::Tab`)
        v.extend([Dom::Tab; 4]);
        v
    }
}
