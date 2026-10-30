"""Stage per-layer R13 gate binding and profile-derived statement constants."""
from pathlib import Path

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'

def update(text,old,new,count=1):
    assert text.count(old)==count,old[:100]
    return text.replace(old,new)

s=(src/'accuracy_public.rs').read_text()
s=update(s,'    pub(crate) fn stack(&self) -> Stack {','''    pub(crate) fn raw_tables(&self)->&[Vec<i16>] {&self.tables}
    pub(crate) fn member(&self)->(i32,i32) {self.member}
    pub(crate) fn stack(&self) -> Stack {''')
(out/'accuracy_public.candidate.rs').write_text(s)

s=(src/'trained_statement.rs').read_text()
for signature in ['    pub(crate) fn pinned_for_profile(profile: &str) -> Option<ModelSource> {',
    "pub(crate) fn tied_tensor_for_profile(profile: &str) -> Option<(&'static str, [u8; 32])> {"]:
    s=update(s,signature,signature+'\n    let profile=super::shape::accuracy_spec(profile).map(|spec|spec.legacy).unwrap_or(profile);')
s=update(s,'            norm_wrho: sh.norm_wrho,','''            norm_wrho: if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {sh.norm_wrho} else {24},''')
s=update(s,'            sh_u: 0,','''            sh_u: if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {0} else {12},''')
s=update(s,'            f_p: F_P,','            f_p: sh.f_p(),')
s=update(s,'    pub own: [Option<i64>; 11],','''    pub own: [Option<i64>; 11],
    /// R13's verifier-derived common gate denominator. Always present for
    /// R13 and absent for legacy; its scalar also determines the stage shape.
    pub accuracy_gate_shift:Option<u32>,''')
s=update(s,'own: [None; 11] }','own: [None; 11], accuracy_gate_shift:None }',2)
s=update(s,'''        let act: Vec<u8> = f.act.iter().flat_map(|v| v.to_le_bytes()).collect();''','''        let act:Vec<u8>=match blk.accuracy() {
            Some(data)=>data.raw_tables().iter().flatten().flat_map(|v|v.to_le_bytes()).collect(),
            None=>f.act.iter().flat_map(|v|v.to_le_bytes()).collect(),
        };''')
s=update(s,'''LayerRecord { index, block_digest: blk.digest(), word_sha256, table_sha256, source_tensors, manifest_sha256: [0; 32], silu_member: (-3, -11), exp_e_s: 0, own: [None; 11], accuracy_gate_shift:None }''','''LayerRecord { index, block_digest: blk.digest(), word_sha256, table_sha256, source_tensors, manifest_sha256: [0; 32],
            silu_member:blk.accuracy().map(|a|a.member()).unwrap_or((-3,-11)),exp_e_s:0,own:[None;11],
            accuracy_gate_shift:blk.accuracy().map(|a|a.folds().gate.shift) }''')
s=update(s,'impl LayerRecord {','''impl LayerRecord {
    pub(crate) fn check_accuracy_gate(&self,sh:&Shape)->Result<(),String> {
        match (sh.accuracy_stack(),self.accuracy_gate_shift) {
            (super::accuracy_precision::Stack::Legacy,None)=>Ok(()),
            (super::accuracy_precision::Stack::Legacy,Some(_))=>Err("trained statement: legacy layer carries an R13 gate denominator".into()),
            (_,None)=>Err("trained statement: R13 layer is missing its common gate denominator".into()),
            (_,Some(g))=>sh.clone().with_accuracy_gate_shift(g).map(|_|()),
        }
    }
''')
s=update(s,'''        for r in &self.layers {
            // NATIVE R8''','''        for r in &self.layers {
            r.check_accuracy_gate(sh)?;
            // NATIVE R8''')
s=update(s,'''            for (k, d) in r.word_sha256.iter().enumerate() {''','''            if let Some(g)=r.accuracy_gate_shift {e.u64("accuracy-gate-layer",u64::from(g));}
            for (k, d) in r.word_sha256.iter().enumerate() {''')
(out/'trained_statement.candidate.rs').write_text(s)

s=(src/'run.rs').read_text()
s=update(s,'    stage_cal: Vec<super::shape::NormCalibration>,','''    stage_cal: Vec<super::shape::NormCalibration>,
    stage_accuracy_gate:Vec<u32>,''')
s=update(s,'        for (k, r) in model.layers.iter().enumerate() {','''        for (k, r) in model.layers.iter().enumerate() {
            r.check_accuracy_gate(&st.rs.sh)?;
            if let Some(g)=r.accuracy_gate_shift {st.stage_accuracy_gate[k]=g;}''')
s=update(s,'''        let stage_cal = vec![rs.sh.norm_calibration(); rs.l];
        let st = RunStatement { rs, expected, block_digests, context, boundary_scales, calibration, stage_cal };''','''        let stage_cal = vec![rs.sh.norm_calibration(); rs.l];
        let stage_accuracy_gate=vec![rs.sh.accuracy_gate_shift;rs.l];
        let st = RunStatement { rs, expected, block_digests, context, boundary_scales, calibration, stage_cal,stage_accuracy_gate };''')
s=update(s,'''        if cal == self.rs.sh.norm_calibration() {
            Ok(self.rs.sh.clone())
        } else {
            self.rs.sh.with_layer_calibration(&cal)
        }''','''        let sh=if cal==self.rs.sh.norm_calibration() {self.rs.sh.clone()} else {self.rs.sh.with_layer_calibration(&cal)?};
        if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {Ok(sh)}
        else {sh.with_accuracy_gate_shift(*self.stage_accuracy_gate.get(k).ok_or("private run: missing R13 stage denominator")?)}''')
(out/'run.candidate.rs').write_text(s)

for name in ['r4_tests.rs','review_d24_tests.rs']:
    s=(src/name).read_text()
    assert 'own: [None; 11] }' in s
    s=s.replace('own: [None; 11] }','own: [None; 11], accuracy_gate_shift:None }')
    (out/(name.removesuffix('.rs')+'.candidate.rs')).write_text(s)
print('Staged optional layer scalar, actual F_P/norm/up metadata, model pins, raw-table hashes and stage reconstruction; not installed.')
