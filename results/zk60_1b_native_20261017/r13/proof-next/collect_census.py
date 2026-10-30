"""Retain native census rows without asserting an overall security level."""
from pathlib import Path
import hashlib
import json
import sys

out=Path(__file__).resolve().parent.parent
name=sys.argv[1]
log=out/(name+'.log')
assert (out/(name+'.done')).read_text().strip()=='0'
rows=[json.loads(line.split('R13_NATIVE_CENSUS ',1)[1]) for line in log.read_text().splitlines()
    if 'R13_NATIVE_CENSUS ' in line]
assert len(rows)==12*3*4,len(rows)
assert len({(r['profile'],r['f_e'],r['groups']) for r in rows})==len(rows)
for r in rows:
    assert r['act_table_entries']==4096*r['groups']<=r['n']
    assert r['lookup_positions']==sum(r[k] for k in ['byte_queries','exp_queries','act_queries','dd_queries','dd_table_entries','act_table_entries'])+512
    assert r['proposed_lookup_degree']==2*(r['lookup_positions']-1)
    r['a_base_field_words']=r['a_rows']*r['n']
    r['h_base_field_words']=r['h_rows']*r['n']
report={'scope':'COUNTED native admitted-calibration examples; lookup bound proposal unreviewed; no overall security/privacy/performance acceptance',
    'source_log':str(log),'source_log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
    'identities':len({r['profile'] for r in rows}),'rows':rows}
target=out/'NATIVE_LAYOUT_CENSUS.json';target.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'file':str(target),'identities':report['identities'],'rows':len(rows)}))
