"""Prepare native profile/layout changes in isolated files for inspection."""
from pathlib import Path
import json

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
rows=json.loads((p/"PLAN.json").read_text())["profiles"]
names=["R13_TINY_T128_LOW","R13_TINY_T128_LOW_DD","R13_8B_T128_H24","R13_8B_T128_H24_DD",
    "R13_SHIELD_T128_H24","R13_SHIELD_T128_H24_DD","R13_SHIELD_T256_H24","R13_SHIELD_T256_H24_DD",
    "R13_RUNG_LOW","R13_RUNG_H24","R13_RUNG_LOW_DD","R13_RUNG_H24_DD"]
defs="\n// R13 registry. Construction/counting exists before proof activation.\n"
for n,r in zip(names,rows):defs+=f'pub(crate) const {n}: &str = "{r["profile"]}";\n'
defs+='''#[derive(Clone,Copy)]
pub(crate) struct AccuracyProfile {
    pub profile:&'static str, pub name:&'static str, pub legacy:&'static str,
    pub stack:super::accuracy_precision::Stack, pub registry:super::accuracy_tables::Registry,
    pub tokens:usize,pub width:usize,pub hidden:usize,pub q_heads:usize,pub head_dim:usize,pub kv_heads:usize,pub log_cols:usize,
}
pub(crate) const ACCURACY_PROFILES:[AccuracyProfile;12]=[
'''
for n,r in zip(names,rows):
    legacy={"tinyllama":"TINYLLAMA_T128_TRAINED_PROFILE","llama3-8b":"LLAMA3_8B_T128_TRAINED_PROFILE",
        "shieldstral":"SHIELDSTRAL_T128_TRAINED_PROFILE","development":"TRAINED_HD_RUNG_PROFILE"}[r["model"]]
    stack="Low" if r["stack"]=="low-v1" else "LowH24"
    reg="Shieldstral" if r["model"]=="shieldstral" else "Standard"
    fields=",".join(f"{key}:{r[key]}" for key in ("tokens","width","hidden","q_heads","head_dim","kv_heads","log_cols"))
    defs+=f'AccuracyProfile{{profile:{n},name:"{n}",legacy:{legacy},stack:super::accuracy_precision::Stack::{stack},registry:super::accuracy_tables::Registry::{reg},{fields}}},\n'
defs+=''' ];
pub(crate) fn accuracy_spec(profile:&str)->Option<&'static AccuracyProfile> {ACCURACY_PROFILES.iter().find(|s|s.profile==profile)}
'''
s=(src/"shape.rs").read_text()
marker="/// **The declared parameter class of a trained norm calibration**"
assert s.count(marker)==1
s=s.replace(marker,defs+"\n"+marker)
s=s.replace("TRAINED_CALIBRATION_PROFILES: [&str; 15]", "TRAINED_CALIBRATION_PROFILES: [&str; 27]")
at=s.index("pub(crate) const TRAINED_CALIBRATION_PROFILES:")
end=s.index("];",at)
s=s[:end]+"".join("    "+n+",\n" for n in names)+s[end:]
s=s.replace("DD_PROFILES: [&str; 5]", "DD_PROFILES: [&str; 11]")
at=s.index("pub(crate) const DD_PROFILES:");end=s.index("];",at)
s=s[:end]+", "+", ".join(n for n,r in zip(names,rows) if r["dd_cap"])+s[end:]
for fn in ("trained_rope_theta","trained_rope_scaling"):
    at=s.index("pub(crate) fn "+fn);at=s.index("{",at)+1
    s=s[:at]+"\n    let profile=accuracy_spec(profile).map(|s|s.legacy).unwrap_or(profile);"+s[at:]
at=s.index("    let mask = super::endpoint_g::MASK_ROWS;",s.index("fn trained_geometry"))
s=s[:at]+'''    if let Some(s)=accuracy_spec(profile) {
        let rows=(s.tokens.next_power_of_two()*s.width.next_power_of_two()).div_ceil(1usize<<s.log_cols).max(1)+super::endpoint_g::MASK_ROWS;
        return Some(Shape::build(s.name,s.profile,s.tokens,s.width,s.hidden,s.q_heads,s.head_dim,s.kv_heads,s.log_cols,4,f_e,rows,None,None,None,None));
    }
'''+s[at:]
s=s.replace("    pub dd_cap: usize,", "    pub dd_cap: usize,\n    /// R13 public common gate denominator; zero on every legacy shape.\n    pub accuracy_gate_shift:u32,")
s=s.replace("            dd_cap: if DD_PROFILES.contains(&profile) { DD_CAP } else { 0 },", "            dd_cap: if DD_PROFILES.contains(&profile) { DD_CAP } else { 0 },\n            accuracy_gate_shift: if accuracy_spec(profile).is_some() {17} else {0},")
at=s.index("    #[allow(clippy::too_many_arguments)]",s.index("impl Shape {"))
s=s[:at]+(p/"shape_methods.rs").read_text()+s[at:]
s=s.replace("        let (d_max, wrho) = self.norm_calibration().derive_at_width(self.width)?;", "        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {\n            self.accuracy_precision()?;\n            if !(17..=24).contains(&self.accuracy_gate_shift) {return Err(\"R13 shape: common gate shift outside17..=24\".into());}\n        }\n        let (d_max, wrho) = self.norm_calibration().derive_at_width(self.width)?;")
needle="        .and_then(|b| if self.trained_calibration { b.with_trained_calibration(&self.norm_calibration()) } else { Ok(b) })"
assert s.count(needle)==1
s=s.replace(needle,needle+"\n        .and_then(|b| if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {b.with_accuracy_gate_shift(self.accuracy_gate_shift)} else {Ok(b)})")
s=s.replace('(\"trained_calibration\", rebuilt.trained_calibration != self.trained_calibration),', '(\"trained_calibration\", rebuilt.trained_calibration != self.trained_calibration),\n            (\"accuracy_gate_shift\", rebuilt.accuracy_gate_shift != self.accuracy_gate_shift),')
s=s.replace("        self.norm_wrho.div_ceil(8) as usize", "        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {3} else {self.norm_wrho.div_ceil(8) as usize}")
s=s.replace("        self.norm_wrho == 8 * self.limbs_norm() as u32", "        self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy || self.norm_wrho == 8 * self.limbs_norm() as u32")
s=s.replace("        (F_P + 1).div_ceil(8) as usize", "        (self.f_p() + 1).div_ceil(8) as usize")
needle="    pub(crate) fn a_plane_doms(&self) -> Vec<Dom> {"
s=s.replace(needle,needle+'''
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            let h24=self.accuracy_stack()==super::accuracy_precision::Stack::LowH24;
            let mut v=vec![Dom::T;4];v.extend([Dom::Ht;2]);v.extend([Dom::L;2]);
            v.extend(vec![Dom::D;if h24 {39} else {38}]);v.extend([Dom::Q;14]);v.extend([Dom::Kv;14]);
            v.extend(vec![Dom::S;if self.dd_cap>0 {7} else {9+2*self.limbs_sigma_s()}]);v.extend([Dom::F;16]);
            if self.dd_cap>0 {v.extend(vec![Dom::Dd;4+2*self.limbs_sigma_s()]);}
            v.extend([Dom::Tab;3]);return v;
        }
''')
needle="    pub(crate) fn lookups_per_position(&self, dom: Dom) -> usize {"
s=s.replace(needle,needle+'''
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            return match dom {Dom::L=>2,Dom::D=>if self.accuracy_stack()==super::accuracy_precision::Stack::LowH24 {34} else {33},
                Dom::Q|Dom::Kv|Dom::F=>14,Dom::S=>if self.dd_cap>0 {6} else {11+2*self.limbs_sigma_s()},
                Dom::Dd if self.dd_cap>0=>5+2*self.limbs_sigma_s(),_=>0};
        }
''')
(p/"shape.candidate.rs").write_text(s)

s=(src/"layout.rs").read_text()
s=s.replace("    map: Vec<usize>,", "    map: Vec<usize>,\n    accuracy:Option<super::accuracy_layout::AccuracyIds>,",1)
needle="        let (ln, ls, lp) = (sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p());"
assert s.count(needle)==1
s=s.replace(needle,needle+'''
        if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            let low=super::accuracy_layout::AccuracyIds::new(sh.accuracy_stack(),sh.dd_cap>0,ls)?;
            if low.doms!=sh.a_plane_doms() {return Err("R13 planes differ from the independently counted shape list".into());}
            return Ok(Ids{map:low.map.clone(),doms:low.doms.clone(),ln,ls,lp,pdict:low.pdict,mdd:low.mdd,accuracy:Some(low)});
        }
''')
s=s.replace("Ids { map, doms, ln, ls, lp,", "Ids { map, doms, ln, ls, lp, accuracy:None,")
for fn,bound in [("nr","ln"),("ns","ln"),("mr","ln"),("ms","ln"),("pl","lp"),("sr","ls"),("sg","ls")]:
    needle=f"    pub(crate) fn {fn}(&self, k: usize) -> usize {{"
    assert s.count(needle)==1;s=s.replace(needle,needle+f'\n        assert!(k<self.{bound},"absent limb role {fn}");')
needle="    pub(crate) fn n_a(&self) -> usize {"
s=s.replace(needle,'''    pub(crate) fn accuracy(&self)->Result<&super::accuracy_layout::AccuracyIds,String> {
        self.accuracy.as_ref().ok_or("R13 limb roles requested at a legacy profile".into())
    }
    pub(crate) fn domain_range(&self,dom:Dom)->Result<std::ops::Range<usize>,String> {
        let start=self.doms.iter().position(|&d|d==dom).ok_or("domain has no A planes")?;
        let end=self.doms.iter().rposition(|&d|d==dom).unwrap()+1;
        if self.doms[start..end].iter().any(|&d|d!=dom) {return Err("domain A planes are not contiguous".into());}
        Ok(start..end)
    }
'''+needle)
needle="pub(crate) fn lookups_at(sh: &super::shape::Shape, ids: &Ids, dom: Dom) -> Vec<Lk> {"
assert s.count(needle)==1
s=s.replace(needle,needle+'''
    if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
        return ids.accuracy().expect("R13 allocation").lookups(dom,&sh.accuracy_precision().expect("validated R13 calibration"),sh.accuracy_gate_shift,sh.wrho_s).expect("validated R13 lookup windows");
    }
''')
needle="            if sh.trained_calibration {"
assert s.count(needle)==1
s=s.replace(needle,'''            if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
                format!("calibration: R13 stack={:?} registry={} base={} norm-window=24 fp=12 gate-common={} precision={:?}; exact group-scaled ACT3; symmetric int8 weights/score, full int16 words",sh.accuracy_stack(),sh.accuracy_registry().name(),sh.norm_calibration().describe(),sh.accuracy_gate_shift,sh.accuracy_precision().expect("validated R13 precision"))
            } else if sh.trained_calibration {''')
(p/"layout.candidate.rs").write_text(s)
print("prepared",len(rows),"native profile/Shape/Ids candidates; no installation")
