"""Add uncompiled test-only split regressions; never alter a held candidate."""
from datetime import datetime,timezone
import hashlib,json,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'capture-working-tree';LABEL='sol-r14-capture-build-1'
assert not (HERE/(LABEL+'.command.json')).exists(),'capture source held after launch recorded'
pin=json.loads((HERE/(LABEL+'.source.json')).read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for name,want in pin['files'].items():assert sha(TREE/name)==want,name
source=TREE/'hashline/src/private_block'
path=source/'split_attack_tests.rs';text=path.read_text();assert 'static TABLE_MOVE:' not in text
path.write_text(text+(HERE/'staged/split_regression_append.rs').read_text())
path=source/'split_protocol.rs';text=path.read_text()
needle='    Ok([m_u8, m_exp, m_act])'
assert text.count(needle)==1
text=text.replace(needle,'''    let counts=[m_u8,m_exp,m_act];
    // Test-only malicious prover: move one count beyond registered support.
    // The paired helper injection below preserves the table product and H
    // sum, so the verifier must enforce the table's support-zero relation.
    #[cfg(test)]
    let counts={
        let mut counts=counts;
        if let Some((which,from,to))=argument::split_attack_tests::table_move() {
            let support=counts[which].len();
            assert!(from<support && support<=to && to<p.base().size(Dom::Tab));
            assert!(counts[which][from]>0,"support fixture has no count to move");
            counts[which][from]-=1;counts[which].resize(p.base().size(Dom::Tab),0);
            counts[which][to]=1;
        }
        counts
    };
    Ok(counts)''')
needle='    for x in &mut out[s.h_data_rows * s.n..] {'
assert text.count(needle)==1
text=text.replace(needle,'''    #[cfg(test)]
    if let Some((which,from,to))=argument::split_attack_tests::table_move() {
        let len=sh.size(Dom::Tab);
        let table=match which {
            0=>argument::table_values_u8_at(len,gu8),
            1=>argument::table_values_exp_at(len,blk.attention(),beta,gexp),
            2=>accuracy_act::table(accuracy,len,beta,gact)?.compressed,
            _=>panic!("unknown moved table"),
        };
        assert_eq!(table[from],table[to],"padded table tuple changed");
        let value=inverse(vec![alpha.sub(table[to])])?[0];
        let plane=s.plane(true,hids.table_helpers()[which],Part::Whole)?;
        assert_eq!(m[which][to],1);
        out[plane.offset+to]=value.c0;
        out[plane.offset+plane.rows_per_component*s.n+to]=value.c1;
    }
'''+needle)
path.write_text(text)
for name in ['split_attack_tests.rs','split_protocol.rs']:
    subprocess.run(['/home/victor/.cargo/bin/rustfmt','--edition','2021',str(source/name)],check=True)
files={name:sha(TREE/name) for name in pin['files']}
digest=hashlib.sha256(''.join(f'{k} {v}\n' for k,v in sorted(files.items())).encode()).hexdigest()
(HERE/(LABEL+'.source.json')).write_text(json.dumps({'tree_sha256':digest,'count':len(files),'files':files},indent=2)+'\n')
state=json.loads((HERE/'CAPTURE_BRANCH_STATE.json').read_text());state.update(utc=datetime.now(timezone.utc).isoformat(),source=digest,
    status='Uncompiled independent observer/L25/relation-regression branch; arithmetic candidate unchanged',
    regression_scope='21 high-byte probes across both true D/F pieces and unchanged domains, DD unused/counts, three registered table support tails. No native pass yet.')
(HERE/'CAPTURE_BRANCH_STATE.json').write_text(json.dumps(state,indent=2)+'\n')
print(json.dumps({'source':digest,'files':len(files),'status':'uncompiled'}))
