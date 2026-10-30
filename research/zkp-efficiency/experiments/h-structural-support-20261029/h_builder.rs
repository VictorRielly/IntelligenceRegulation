impl<'a>B<'a>{
    fn h(&mut self, plane: usize) -> Result<usize, String> {
        let mask_row = self.lay.h_site(self.slot, self.hk)?;
        self.hk += 1;
        let (re, im) = self.lay.h_off[plane];
        let log = self.lay.shape().log(self.lay.hids().dom(plane));
        Ok(self.push(Tab::Priv(Priv { cm: Cm::H, slices: vec![(re, Fp2::ONE), (im, Fp2::U)], log, coords: rho(0..log), mask_row, ext_round: 0 })))
    }
}
