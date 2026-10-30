"""Stage v2 export selection and strict base-constant parsing (no install)."""
from pathlib import Path

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'

def once(s,old,new):
    assert s.count(old)==1,old[:100]
    return s.replace(old,new)

s=(src/'trained_block.rs').read_text()
s=once(s,'pub(crate) const PROFILE_SCHEMA: &str = "zk60-trained-profile-export/1";',
    'pub(crate) const PROFILE_SCHEMA: &str = "zk60-trained-profile-export/1";\npub(crate) const ACCURACY_PROFILE_SCHEMA:&str="zk60-trained-profile-export/2";')
s=once(s,'fn constants_of(c: &J, what: &str, rope_pin: f64) -> Result<Constants, String> {','''fn constants_of(c:&J,what:&str,rope_pin:f64)->Result<Constants,String> {
    constants_for_stack(c,what,rope_pin,super::accuracy_precision::Stack::Legacy)
}
fn constants_for_stack(c:&J,what:&str,rope_pin:f64,stack:super::accuracy_precision::Stack)->Result<Constants,String> {''')
s=once(s,'    for (k, want) in fixed_constants() {','''    for (k, want) in fixed_constants() {
        // sh_u=0 remains the BASE export shift; R13 derives effective12.
        // F_P is a fixed arithmetic constant and v2 must declare12.
        let want=if k=="f_p" && stack!=super::accuracy_precision::Stack::Legacy {12} else {want};''')
s=once(s,'    pub geometry: Geometry,','''    pub geometry: Geometry,
    pub accuracy_stack:super::accuracy_precision::Stack,
    pub accuracy_dd:bool,''')
s=once(s,'''        if schema != PROFILE_SCHEMA {
            return Err(ctx(format!("schema `{schema}`, this reader reads `{PROFILE_SCHEMA}`")));
        }''','''        let accuracy_stack=match schema {
            PROFILE_SCHEMA=>{
                if p.opt("accuracy_stack").is_some() {return Err(ctx("legacy export cannot select R13 arithmetic".into()));}
                super::accuracy_precision::Stack::Legacy
            },
            ACCURACY_PROFILE_SCHEMA=>super::accuracy_precision::Stack::from_export_name(p.get("accuracy_stack").and_then(J::str).map_err(ctx)?).map_err(ctx)?,
            _=>return Err(ctx(format!("unsupported schema `{schema}`"))),
        };''')
needle='''        // the model pin: THE pinned source for TinyLlama, a synthetic recipe'''
s=once(s,needle,'''        if accuracy_stack!=super::accuracy_precision::Stack::Legacy {
            accuracy::profile_for(geometry,accuracy_stack,false).map_err(ctx)?;
        }
'''+needle)
s=once(s,'Some(constants_of(pc, &path.display().to_string(), geometry.rope_theta())?)',
    'Some(constants_for_stack(pc,&path.display().to_string(),geometry.rope_theta(),accuracy_stack)?)')
s=once(s,'''            geometry,
            source,''','''            geometry,
            accuracy_stack,
            accuracy_dd:false,
            source,''')
# The two per-layer paths must use the same stack-dependent constant class.
for old,new in [
    ('let c = constants_of(m.get("constants").map_err(|e| format!("{}: {e}", mpath.display()))?, &mpath.display().to_string(), self.geometry.rope_theta())?;',
     'let c = constants_for_stack(m.get("constants").map_err(|e|format!("{}: {e}",mpath.display()))?,&mpath.display().to_string(),self.geometry.rope_theta(),self.accuracy_stack)?;'),
    ('let lc = constants_of(m.get("constants").map_err(ctx)?, &mpath.display().to_string(), self.geometry.rope_theta())?;',
     'let lc = constants_for_stack(m.get("constants").map_err(ctx)?,&mpath.display().to_string(),self.geometry.rope_theta(),self.accuracy_stack)?;'),
]:s=once(s,old,new)
s=once(s,'        let sh = self.geometry.shape_at(&c.cal, c.f_e)?;','''        let sh=if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {
            self.geometry.shape_at(&c.cal,c.f_e)?
        } else {
            // Geometry seed only. A loaded layer's record carries its G.
            Shape::accuracy_trained(accuracy::profile_for(self.geometry,self.accuracy_stack,self.accuracy_dd)?,&c.cal,c.f_e,17)?
        };''')
needle='impl TrainedExport {'
s=once(s,needle,needle+'''
    pub(crate) fn run_profile(&self)->&'static str {
        match accuracy::profile_for(self.geometry,self.accuracy_stack,self.accuracy_dd) {
            Ok(block)=>super::run::accuracy_run_profile(block).expect("registered R13 run profile"),
            Err(_)=>self.geometry.run_profile(),
        }
    }
    fn enable_dd(&mut self)->Result<(),String> {
        if self.accuracy_stack==super::accuracy_precision::Stack::Legacy {self.geometry=self.geometry.dd()?;}
        else {accuracy::profile_for(self.geometry,self.accuracy_stack,true)?;self.accuracy_dd=true;}
        Ok(())
    }
''')
# Only a legacy export may fall back to a legacy run profile.
s=once(s,'''            Err(_)=>self.geometry.run_profile(),''','''            Err(_) if self.accuracy_stack==super::accuracy_precision::Stack::Legacy=>self.geometry.run_profile(),
            Err(e)=>panic!("invalid R13 export geometry/stack: {e}"),''')
needle='    pub(crate) fn run_shape(self, sh: &Shape, l: usize) -> Result<RunShape, String> {'
s=once(s,needle,needle+'''
        if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {return RunShape::accuracy(sh.clone(),l);}
''')
s=once(s,'TrainedModelStatement::new_with_tied(sh, self.geometry.run_profile(),','TrainedModelStatement::new_with_tied(sh, self.run_profile(),')
assert s.count('js(ex.geometry.run_profile())')==2
s=s.replace('js(ex.geometry.run_profile())','js(ex.run_profile())')
assert s.count('ex.geometry = ex.geometry.dd()?;')==4
s=s.replace('ex.geometry = ex.geometry.dd()?;','ex.enable_dd()?;')
(out/'trained_block.profile.candidate.rs').write_text(s)

s=(src/'trained_accuracy.rs').read_text()
needle='pub(super) struct Loaded {'
addition='''/// The export chooses one approved arithmetic stack for its model.
/// The decoupled-head rung is synthetic and supports both development stacks.
pub(super) fn profile_for(geometry:super::Geometry,stack:Stack,dd:bool)->Result<&'static str,String> {
    use crate::private_block::shape::*;
    use super::Geometry as G;
    let p=match (geometry,stack,dd) {
        (G::TinyLlama(128),Stack::Low,false)=>R13_TINY_T128_LOW,
        (G::TinyLlama(128),Stack::Low,true)=>R13_TINY_T128_LOW_DD,
        (G::Llama3_8B(128),Stack::LowH24,false)=>R13_8B_T128_H24,
        (G::Llama3_8B(128),Stack::LowH24,true)=>R13_8B_T128_H24_DD,
        (G::Shieldstral(128),Stack::LowH24,false)=>R13_SHIELD_T128_H24,
        (G::Shieldstral(128),Stack::LowH24,true)=>R13_SHIELD_T128_H24_DD,
        (G::Shieldstral(256),Stack::LowH24,false)=>R13_SHIELD_T256_H24,
        (G::Shieldstral(256),Stack::LowH24,true)=>R13_SHIELD_T256_H24_DD,
        (G::RungHdDev,Stack::Low,false)=>R13_RUNG_LOW,
        (G::RungHdDev,Stack::LowH24,false)=>R13_RUNG_H24,
        (G::RungHdDev,Stack::Low,true)=>R13_RUNG_LOW_DD,
        (G::RungHdDev,Stack::LowH24,true)=>R13_RUNG_H24_DD,
        _=>return Err("R13 export: this model/context/stack has no registered arithmetic profile".into()),
    };
    Ok(p)
}

'''
s=once(s,needle,addition+needle)
(out/'trained_accuracy.profile.candidate.rs').write_text(s)
print('Staged schema2 selection, per-model stack registry, strict FP12/base shifts and DD/run-profile dispatch; not installed.')
