//! Profile-derived R13 precision and shifts, shared by every consumer.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Stack { Legacy, LowH24 }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct BaseShifts {
    pub norm_tn: u32,
    pub qkv: u32,
    pub score: u32,
    pub pv: u32,
    pub ao: u32,
    pub gate: u32,
    pub up: u32,
    pub product: u32,
    pub down: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Precision {
    pub stack: Stack,
    pub norm_tn: u32,
    pub q: u32,
    pub k: u32,
    pub v: u32,
    pub score: u32,
    pub pv: u32,
    pub ao: u32,
    /// Before the group input-step fold.
    pub gate: u32,
    pub up: u32,
    /// Before the group output-unit fold.
    pub product: u32,
    pub down: u32,
    pub f_p: u32,
    pub norm_bits: u32,
    pub attention_bits: u32,
    pub gate_bits: u32,
    pub product_bits: u32,
    pub multiplier_bits: [u32; 7],
}

pub(crate) fn derive(_stack: Stack, _base: BaseShifts) -> Result<Precision, String> {
    Err("R13 precision not implemented".into())
}

#[cfg(test)]
mod tests {
    use super::*;
    const BASE: BaseShifts = BaseShifts { norm_tn: 10, qkv: 8, score: 6, pv: 9, ao: 7, gate: 8, up: 0, product: 14, down: 6 };

    #[test]
    fn legacy_shifts_and_widths_remain_unchanged() {
        let p = derive(Stack::Legacy, BASE).unwrap();
        assert_eq!((p.norm_tn, p.q, p.k, p.v, p.score, p.pv, p.ao, p.gate, p.up, p.product, p.down),
                   (10, 8, 8, 8, 6, 9, 7, 8, 0, 14, 6));
        assert_eq!((p.f_p, p.norm_bits, p.attention_bits, p.gate_bits, p.product_bits), (9, 8, 8, 8, 16));
        assert_eq!(p.multiplier_bits, [0; 7]);
    }

    #[test]
    fn low_h24_matches_the_received_build_spec() {
        let p = derive(Stack::LowH24, BASE).unwrap();
        assert_eq!((p.norm_tn, p.q, p.k, p.v, p.score, p.pv, p.ao, p.gate, p.up, p.product, p.down),
                   (2, 15, 15, 16, 18, 12, 21, 18, 12, 6, 20));
        assert_eq!((p.f_p, p.norm_bits, p.attention_bits, p.gate_bits, p.product_bits), (12, 16, 16, 12, 24));
        assert_eq!(p.multiplier_bits, [5, 5, 6, 8, 6, 4, 6]);
        assert_eq!(derive(Stack::LowH24, BaseShifts { norm_tn: 9, ..BASE }).unwrap().norm_tn, 1);
    }

    #[test]
    fn invalid_base_or_derived_windows_are_refused() {
        for base in [BaseShifts { norm_tn: 8, ..BASE }, BaseShifts { qkv: 0, ..BASE },
                     BaseShifts { qkv: 1, ..BASE }, BaseShifts { score: 4, ..BASE },
                     BaseShifts { pv: 14, ..BASE }, BaseShifts { ao: 2, ..BASE },
                     BaseShifts { gate: 0, ..BASE }, BaseShifts { up: 1, ..BASE },
                     BaseShifts { product: 12, ..BASE }, BaseShifts { down: 2, ..BASE }] {
            assert!(derive(Stack::LowH24, base).is_err(), "{base:?}");
        }
    }
}
