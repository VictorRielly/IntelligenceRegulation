"""Stage test-only proof availability; ordinary release R13 stays disabled."""
from pathlib import Path

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'
s=src.with_suffix('.rs').read_text()
needle='#[derive(Clone)]\npub struct BlockPublic {'
assert s.count(needle)==1
scope='''// Temporary development availability, absent from ordinary release.
// Every permitted proof still runs the full R13 public-context validator.
#[cfg(test)]
thread_local! {
    static ACCURACY_PROOF_TESTS:std::cell::Cell<bool>=const{std::cell::Cell::new(false)};
}
#[cfg(test)]
pub(crate) struct AccuracyProofTests {
    was:bool,
    _same_thread:std::marker::PhantomData<std::rc::Rc<()>>,
}
#[cfg(test)]
impl AccuracyProofTests {
    pub(crate) fn scoped()->Self {
        let was=ACCURACY_PROOF_TESTS.with(|flag|flag.replace(true));
        Self{was,_same_thread:std::marker::PhantomData}
    }
}
#[cfg(test)]
impl Drop for AccuracyProofTests {
    fn drop(&mut self) {ACCURACY_PROOF_TESTS.with(|flag|flag.set(self.was));}
}
fn accuracy_proofs_available()->bool {
    #[cfg(test)]
    {ACCURACY_PROOF_TESTS.with(|flag|flag.get())}
    #[cfg(not(test))]
    {false}
}

'''
s=s.replace(needle,scope+needle)
needle='''        if sh.accuracy_stack()!=accuracy_precision::Stack::Legacy {
            return Err("R13 proof profiles remain disabled until all host and lookup relations are integrated".into());
        }'''
assert s.count(needle)==1
s=s.replace(needle,'''        if sh.accuracy_stack()!=accuracy_precision::Stack::Legacy {
            if !accuracy_proofs_available() {
                return Err("R13 proof profiles remain disabled until all host and lookup relations are integrated".into());
            }
            return self.check_accuracy_for_shape(sh);
        }''')
(out/'private_block.scope.candidate.rs').write_text(s)

s=(src/'witness.rs').read_text()
s=s.replace('/// The block-aware builder is the eventual entry for v2 exports. Until\n/// shared R13 activation is complete, its ordinary public check refuses.',
    '/// The block-aware component builder validates the complete public\n/// context independently of proof availability.')
needle='''    blk.check_for_shape(sh)?;
    match blk.accuracy() {
        Some(data)=>build_accuracy(sh,blk.attention(),blk.feed_forward(),data,input),
        None=>build_shaped(sh,blk.attention(),blk.feed_forward(),input),
    }'''
assert s.count(needle)==1
s=s.replace(needle,'''    if sh.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
        // Component construction is valid independently of proof availability,
        // including when Rayon builds it off the invoking test's thread.
        blk.check_accuracy_for_shape(sh)?;
        build_accuracy(sh,blk.attention(),blk.feed_forward(),blk.accuracy().expect("validated public data"),input)
    } else {
        blk.check_for_shape(sh)?;
        build_shaped(sh,blk.attention(),blk.feed_forward(),input)
    }''')
(out/'witness.scope.candidate.rs').write_text(s)
print('Staged scoped test availability with full validation and component-only witness construction; not installed.')
