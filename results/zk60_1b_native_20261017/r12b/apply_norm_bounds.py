"""Apply the narrowly scoped accessor-class correction after acceptance ends."""
from pathlib import Path
import hashlib
import json
import datetime

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
NATIVE=ROOT/'ops/zkp-mvp/trained-1b'
NAME='hashline/src/private_block/tied_tables/derive.rs'

def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    suite=json.loads((HERE/'suite-final.guard.json').read_text())
    assert (HERE/'suite-final.done').read_text().strip()==str(suite['exit'])
    assert suite['exit'] in (0,101) and suite['child_rc']==suite['exit'] and not suite.get('guard_killed'),'do not edit source before the original suite is terminal'
    manifest=json.loads((HERE/'source_candidate.json').read_text())
    path=NATIVE/NAME
    before=path.read_text();assert sha(before.encode())==manifest['files'][NAME]
    old='''if out.g0 != 127 || !(1..=1<<20).contains(&out.cn) || !(8..=22).contains(&out.tn) || !(0..1i64<<40).contains(&out.ceps) {'''
    new='''if out.g0 != 127 || !(1..=crate::private_block::shape::TRAINED_CN_MAX).contains(&out.cn)
        || !crate::private_block::shape::TRAINED_TN_RANGE.contains(&out.tn)
        || !(1..=crate::private_block::shape::TRAINED_CEPS_MAX).contains(&out.ceps) {'''
    assert before.count(old)==1
    after=before.replace(old,new)
    old_classifier='''if classifier && out.tn != 10 { return Err("classifier_final_norm.tn must be 10 at Shieldstral width".into()); }'''
    new_classifier='''if classifier && (out.tn != 10 || out.ceps >= crate::private_block::shape::TRAINED_CEPS_MAX) {
        return Err("classifier_final_norm requires tn=10 and ceps<2^40 for its 32-bit norm window".into());
    }'''
    assert after.count(old_classifier)==1;after=after.replace(old_classifier,new_classifier)
    anchor='''        let mut invalid=[1.,2.,3.,4.];'''
    assert after.count(anchor)==1
    addition='''        // The accessor must support the prover's declared head-norm class,
        // rather than narrowing legal calibrations to tn>=8.
        for tn in [1,7,16] {
            let text=format!(r#"{{\"g0\":127,\"cn\":128,\"tn\":{tn},\"ceps\":2439}}"#);
            assert_eq!(norm(&parse_json(text.as_bytes()).unwrap(),false).unwrap().tn,tn);
        }
        for text in [r#"{\"g0\":127,\"cn\":128,\"tn\":17,\"ceps\":2439}"#,
                     r#"{\"g0\":127,\"cn\":128,\"tn\":7,\"ceps\":0}"#] {
            assert!(norm(&parse_json(text.as_bytes()).unwrap(),false).is_err());
        }
        let endpoint=parse_json(br#"{\"g0\":127,\"cn\":128,\"tn\":7,\"ceps\":1099511627776}"#).unwrap();
        assert!(norm(&endpoint,false).is_ok());
'''
    after=after.replace(anchor,addition+anchor)
    (HERE/'source_before_norm_bounds.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (HERE/'derive_before_norm_bounds.rs').write_text(before)
    path.write_text(after)
    manifest['files'][NAME]=sha(after.encode())
    manifest['written_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    manifest['tree_sha256']=sha(''.join(f'{k} {v}\n' for k,v in sorted(manifest['files'].items())).encode())
    (HERE/'source_candidate.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (HERE/'NORM_BOUNDS_DELTA.json').write_text(json.dumps({'changed_files':[NAME],
        'before_sha256':sha(before.encode()),'after_sha256':sha(after.encode()),
        'scope':'Only norm accessor bounds and its endpoint tests; all proof, layout, transcript, witness, quantizer and loader code unchanged',
        'source_tree_sha256':manifest['tree_sha256']},indent=2)+'\n')
    print(manifest['tree_sha256'])

if __name__=='__main__':main()
