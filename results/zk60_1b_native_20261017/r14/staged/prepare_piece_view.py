"""Stage changes only; never writes the source being built."""
from pathlib import Path
HERE=Path(__file__).resolve().parent
SRC=HERE.parent/'working-tree/hashline/src/private_block'

def one(s,a,b):
    assert s.count(a)==1,(a[:100],s.count(a))
    return s.replace(a,b)

s=(SRC/'argument.rs').read_text()
s=one(s,'mod accuracy;','mod accuracy;\n#[path = "argument_split.rs"]\npub(crate) mod split;')
s=one(s,'struct B<\'a> {\n','struct B<\'a> {\n    split: Option<split::View<\'a>>,\n')
s=one(s,'B { lay, slot, tabs: Vec::new(), ak: 0, hk: 0, shaped: Vec::new() }','B { lay, slot, tabs: Vec::new(), ak: 0, hk: 0, shaped: Vec::new(), split: None }')
s=one(s,'    fn push(&mut self, t: Tab) -> usize {','''    fn new_split(lay: &'a Layout, slot: usize, view: split::View<'a>) -> Self {
        let mut b=Self::new(lay,slot);b.split=Some(view);b
    }
    fn is_split(&self)->bool {self.split.is_some()}
    fn cube(&self)->usize {1usize<<self.split.map(|v|v.main()).unwrap_or(self.lay.shape().slots()[self.slot].0)}
    fn push(&mut self, t: Tab) -> usize {''')
s=one(s,'self.push(Tab::Eq { point: point.to_vec(), start })','''let point=if let Some(view)=self.split {&point[..point.len().min(view.main().saturating_sub(start))]}else{point};
        self.push(Tab::Eq { point: point.to_vec(), start })''')
s=one(s,'self.push(Tab::Pub(v))','self.push(Tab::Pub(if let Some(view)=self.split {view.crop(self.lay,v)}else{v}))')
s=one(s,'let mask_row = self.lay.a_site(self.slot, self.ak)?;','''let (off,mask_row)=if let Some(view)=self.split {
            (view.a_offset(self.lay,off,log)?,view.a_pair(self.ak)?)
        }else{(off,self.lay.a_site(self.slot,self.ak)?)};''')
s=one(s,'''fn a_log(&self, plane: usize) -> usize {
        self.lay.shape().log(self.lay.ids().dom(plane))
    }''','''fn a_log(&self, plane: usize) -> Result<usize,String> {
        if let Some(view)=self.split {view.a_log(self.lay,plane)}else{Ok(self.lay.shape().log(self.lay.ids().dom(plane)))}
    }''')
s=one(s,'(self.lay.a_off[plane], self.a_log(plane))','(self.lay.a_off[plane], self.a_log(plane)?)')
s=one(s,'let log = self.a_log(plane);','let log = self.a_log(plane)?;')
s=one(s,'''let mask_row = self.lay.h_site(self.slot, self.hk)?;
        self.hk += 1;
        let (re, im) = self.lay.h_off[plane];
        let log = self.lay.shape().log(self.lay.hids().dom(plane));''','''let (re,im,log,mask_row)=if let Some(view)=self.split {
            let(re,im,log)=view.h_source(self.lay,plane)?;(re,im,log,view.h_pair(self.hk)?)
        }else{
            let(re,im)=self.lay.h_off[plane];
            (re,im,self.lay.shape().log(self.lay.hids().dom(plane)),self.lay.h_site(self.slot,self.hk)?)
        };
        self.hk += 1;''')
s=one(s,'''let sh = self.lay.shape();
        if !sh.carries_pad_rule() || !sh.pads(dom) {''','''let sh = self.lay.shape();
        if (self.split.is_some()&&matches!(dom,Dom::D|Dom::F)) || !sh.carries_pad_rule() || !sh.pads(dom) {''')
s=one(s,'    fn finish(self, poly: Poly, hosted: Vec<(usize, Fp2)>) -> Result<SlotDef, String> {','''    fn finish(self, poly: Poly, mut hosted: Vec<(usize, Fp2)>) -> Result<SlotDef, String> {
        if let Some(view)=self.split {
            if (self.ak,self.hk)!=view.sites() {return Err("R14 piece builder: terminal census mismatch".into());}
            for (slot,_) in &mut hosted {*slot=view.host(*slot)?;}
            return Ok(SlotDef{slot:view.physical,tabs:self.tabs,poly,groups:None,hosted,sh:self.lay.shape().clone()});
        }''')
(HERE/'argument-with-piece-view.rs').write_text(s)

s=(SRC/'argument_accuracy.rs').read_text()
s=one(s,'fn dzc(ctx:&Ctx<\'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {','''pub(super) fn define_piece(slot:usize,ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript,view:split::View<'_>)->Result<SlotDef,String> {
    let sh=ctx.lay.shape();let data=ctx.accuracy.ok_or("R14 piece requires bound accuracy data")?;
    let geometry=crate::private_block::accuracy_public::Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    data.check_for_registry(sh.accuracy_registry(),geometry,sh.accuracy_base(),sh.accuracy_stack())?;
    if data.folds().gate.shift!=sh.accuracy_gate_shift {return Err("R14 piece common gate shift differs from bound public data".into());}
    match slot {SC_DZC=>dzc_with_view(ctx,pts,tr,Some(view)),SC_FZC=>fzc_with_view(ctx,pts,tr,Some(view)),
        _=>Err("R14 piece: unsupported zero check".into())}
}

fn dzc(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {dzc_with_view(ctx,pts,tr,None)}
fn dzc_with_view(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript,view:Option<split::View<'_>>)->Result<SlotDef,String> {''')
s=one(s,'let precision=sh.accuracy_precision()?;let cube=sh.size(Dom::D);let mut b=B::new(lay,SC_DZC);','''let precision=sh.accuracy_precision()?;
    let mut b=if let Some(v)=view {B::new_split(lay,SC_DZC,v)}else{B::new(lay,SC_DZC)};let cube=b.cube();''')
s=one(s,'let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::D).is_empty();','let pad_on=!b.is_split()&&!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::D).is_empty();')
s=one(s,'fn fzc(ctx:&Ctx<\'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {','''fn fzc(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript)->Result<SlotDef,String> {fzc_with_view(ctx,pts,tr,None)}
fn fzc_with_view(ctx:&Ctx<'_>,pts:&Points,tr:&mut Transcript,view:Option<split::View<'_>>)->Result<SlotDef,String> {''')
s=one(s,'let cube=sh.size(Dom::F);let mut b=B::new(lay,SC_FZC);let pad_on=!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::F).is_empty();','''let mut b=if let Some(v)=view {B::new_split(lay,SC_FZC,v)}else{B::new(lay,SC_FZC)};let cube=b.cube();
    let pad_on=!b.is_split()&&!crate::private_block::pad::zero_rule_a_planes(sh,ids,Dom::F).is_empty();''')
(HERE/'argument-accuracy-with-piece-view.rs').write_text(s)
print('Staged B piece view and shared D/F polynomials; candidate source untouched')
