use crate::field::{Fp2};
const U8_LEN: usize=256;
const ZERO_DENOMINATOR: &str="zero LogUp denominator; discard attempt";
pub fn u8_denominator_inverses(alpha: Fp2, g_u8: Fp2) -> Vec<Option<Fp2>> {
    let den: Vec<Fp2> = (0..U8_LEN).map(|v| alpha.sub(Fp2::from_i64(v as i64).add(g_u8))).collect();
    let mut nonzero: Vec<Fp2> = den.iter().copied().filter(|d| !d.is_zero()).collect();
    crate::field::batch_inverse2(&mut nonzero);
    let mut k = 0usize;
    den.iter()
        .map(|d| {
            if d.is_zero() {
                None
            } else {
                k += 1;
                Some(nonzero[k - 1])
            }
        })
        .collect()
}
pub fn helper_one(v: i64, alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<Fp2, String> {
    match usize::try_from(v) {
        Ok(k) if k < U8_LEN => tbl[k].ok_or_else(|| ZERO_DENOMINATOR.to_string()),
        _ => {
            let d = alpha.sub(Fp2::from_i64(v).add(g_u8));
            if d.is_zero() {
                Err(ZERO_DENOMINATOR.to_string())
            } else {
                Ok(d.inv())
            }
        }
    }
}
