impl<'a>B<'a>{
    fn a_slice(&mut self, off: usize, log: usize, coords: Vec<Coord>, ext_round: usize) -> Result<usize, String> {
        let mask_row = self.lay.a_site(self.slot, self.ak)?;
        self.ak += 1;
        Ok(self.push(Tab::Priv(Priv { cm: Cm::A, slices: vec![(off, Fp2::ONE)], log, coords, mask_row, ext_round })))
    }
}
