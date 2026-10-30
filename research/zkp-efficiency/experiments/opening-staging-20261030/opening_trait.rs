pub trait EncodedStore: Sync {
    /// `rho^T M` for several `rho` at once over the systematic data
    /// (`rhos.len()` vectors of `n = 2^log_cols` entries each), the same
    /// linear map the host fold computes.
    fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String>;
    /// Fold one opening without changing rho order. Default keeps max-four calls.
    /// Overrides must retain opening-local scratch through every queued use,
    /// propagate errors, and preserve exact field values and fresh proof state.
    fn fold_rows_opening(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
        let mut out = Vec::with_capacity(rhos.len());
        for chunk in rhos.chunks(4) {
            out.extend(self.fold_rows(chunk)?);
        }
        Ok(out)
    }
    /// The encoded columns at `idx`, each the commitment's `rows` entries,
    /// in the order of `idx` (duplicates repeated).
    fn columns(&self, idx: &[usize]) -> Result<Vec<Vec<Fp>>, String>;
}
