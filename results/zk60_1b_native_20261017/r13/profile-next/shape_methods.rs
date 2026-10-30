    /// R13 stack/registry are profile facts, never caller flags.
    pub(crate) fn accuracy_stack(&self) -> super::accuracy_precision::Stack {
        accuracy_spec(self.profile).map(|s|s.stack).unwrap_or(super::accuracy_precision::Stack::Legacy)
    }
    pub(crate) fn accuracy_registry(&self) -> super::accuracy_tables::Registry {
        accuracy_spec(self.profile).map(|s|s.registry).unwrap_or_else(||
            if SHIELDSTRAL_PROFILES.contains(&self.profile) {super::accuracy_tables::Registry::Shieldstral}
            else {super::accuracy_tables::Registry::Standard})
    }
    pub(crate) fn accuracy_base(&self) -> super::accuracy_precision::BaseShifts {
        super::accuracy_precision::BaseShifts { norm_tn:self.norm_tn,qkv:self.sh_qkv,score:self.sh_s,
            pv:self.sh_o,ao:self.sh_ao,gate:self.sh_g,up:0,product:self.sh_h,down:self.sh_z }
    }
    pub(crate) fn accuracy_precision(&self) -> Result<super::accuracy_precision::Precision,String> {
        super::accuracy_precision::derive(self.accuracy_stack(),self.accuracy_base())
    }
    pub(crate) fn f_p(&self) -> u32 {
        if self.accuracy_stack()==super::accuracy_precision::Stack::Legacy {F_P} else {12}
    }
    pub(crate) fn with_accuracy_gate_shift(mut self, shift:u32)->Result<Self,String> {
        if self.accuracy_stack()==super::accuracy_precision::Stack::Legacy || !(17..=24).contains(&shift) {
            return Err("R13 shape: a LOW profile and common gate shift in17..=24 required".into());
        }
        self.accuracy_gate_shift=shift;
        Ok(self)
    }
    pub(crate) fn accuracy_trained(profile:&str,cal:&NormCalibration,f_e:u32,gate_shift:u32)->Result<Self,String> {
        if accuracy_spec(profile).is_none() {return Err("R13 shape: unregistered accuracy profile".into());}
        Self::check_f_e_class(accuracy_spec(profile).unwrap().tokens,f_e)?;
        trained_geometry(profile,f_e).ok_or("R13 shape: missing registered geometry")??
            .with_trained_calibration(cal)?.with_accuracy_gate_shift(gate_shift)
    }

