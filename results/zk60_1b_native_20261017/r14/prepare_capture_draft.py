"""Stage schema6 observers without mutating a queued source or enabling them."""
import hashlib,json,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
source=HERE/'checkpoints/actual-build-1/tree/hashline/src/private_block/run_capture.rs'
text=source.read_text()
slot=text[text.index('#[allow(clippy::too_many_arguments)]\npub(super) fn slot('):text.index('/// The masking commitment\'s ONE opening.')]
start=slot.index('        // **STAGE 15: THE PLANE INDEX TABLE')
end=slot.index('        let mut out = Vec::new();',start)
slot=slot[:start]+'''        // Physical sources are recorded verbatim below; the profile carries
        // their complete physical extent/offset/component index. Native
        // acceptance and the separate source-map tests remain prerequisites.
'''+slot[end:]
needle='let (n, ext, degree) = def.sh.slots()[s];'
assert slot.count(needle)==1
slot=slot.replace(needle,'''let (n, ext, degree, name, kind) = {
            let k=r.cur.as_ref().unwrap().k;
            let m=&r.header.profiles[k].layout().slots[s];
            (m.main,m.ext,m.degree,format!("R14 {} {:?}",SLOT_NAMES[m.base],m.part),SLOT_KINDS[m.base])
        };''').replace('SLOT_NAMES[s]','name').replace('SLOT_KINDS[s]','kind')
mask=text[text.index('pub(super) fn mask('):text.index('/// ONE hiding commitment\'s ONE opening:')]
pcs=text[text.index('pub(super) fn pcs('):text.index('/// A stage closes: the segment trailer')]
assert pcs.count('after: &Transcript) {')==1
pcs=pcs.replace('after: &Transcript) {','after: &Transcript, joint: Option<JointPublic>) {')
needle='        site(r, &format!("{} opening", g.role), &before, after);'
assert pcs.count(needle)==1
pcs=pcs.replace(needle,'''        if let Some(joint)=joint {
            let mut decorated=Vec::new();
            write!(decorated,"{{\\\"joint_spec_digest\\\":{:?},\\\"scale\\\":{},",joint.digest,joint.scale).unwrap();
            decorated.extend_from_slice(&out[1..]);out=decorated;
        }
'''+needle)
for name,value in [('slot',slot),('mask',mask),('pcs',pcs)]:
    assert 'r.index' not in value
    value=value.replace('pub(super) fn '+name,'pub(crate) fn '+name)
    value=value.replace('r.header.sh.hash_tag()','r.header.profiles[r.cur.as_ref().unwrap().k].tag()')
    if name=='slot':slot=value
    elif name=='mask':mask=value
    else:pcs=value
base=(HERE/'staged/split_capture.base.rs').read_text()
base=base.replace('// @@COPIED_OBSERVERS@@',slot+'\n'+mask+'\n'+pcs)
pin=json.loads((HERE/'sol-r14-actual-build-2.source.json').read_text())
names=sorted(set(pin['files'])|{'hashline/src/private_block/split_capture.rs','hashline/src/private_block/split_capture_tests.rs'})
if (HERE/'staged/split_l25_tests.rs').exists():names=sorted(set(names)|{'hashline/src/private_block/split_l25_tests.rs'})
files='const SOURCE_FILES: &[&str] = &[\n'+''.join('    '+json.dumps(name)+',\n' for name in names)+'];\n'
base=base.replace('// @@SOURCE_FILES@@',files)
path=HERE/'staged/split_capture.rs';path.write_text(base)
subprocess.run(['/home/victor/.cargo/bin/rustfmt','--edition','2021',str(path)],check=True)
(HERE/'NATIVE_CAPTURE_DRAFT.json').write_text(json.dumps({'status':'STAGED ONLY, uncompiled/unhooked; not a native capture or privacy result',
    'draft_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'public_serializer_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'implemented_draft':'New schema, independent public transcript seed/roots/slot/M/PCS replay, physical layout metadata, public serializer reuse, accepted-run-only bundle extraction and explicit source pins.',
    'pending':['Native integration hooks and trusted header getters','Runtime source-map/allow-list tests and rejection bundle suppression',
        'Joint spec/scale/source metadata in IO observations','Native3stage honest/malicious capture fixtures','Exact rank/CFSbudget/NL1/joint privacy adapter and review']},indent=2)+'\n')
print('Staged R14 capture prototype; main/actual queued sources unchanged')
