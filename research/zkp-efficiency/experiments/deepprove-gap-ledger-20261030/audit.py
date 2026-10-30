"""Separately authored local audit; not external review or native verification."""
import hashlib
import json
from pathlib import Path
import random
import time

import codec
import reference as ref

E=Path(__file__).resolve().parent
start=time.monotonic()
checks={}


def check(name, condition):
    assert condition,name
    checks[name]=checks.get(name,0)+1


pins=json.loads((E/'source-pins.json').read_text())
sources={}
for p in pins:
    snap=E.parent.parent/p['snapshot']
    # snapshots are stored relative to the research directory
    body=snap.read_bytes()
    check('snapshot_hash',hashlib.sha256(body).hexdigest()==p['sha256'])
    check('production_read_only_hash',hashlib.sha256(Path(p['path']).read_bytes()).hexdigest()==p['sha256'])
    sources[p['snapshot'].split('/')[-1]]=body.decode()
shape=sources['0-shape.rs'];wire=sources['1-wire.rs'];token=sources['2-token_io.rs'];classify=sources['3-classify.rs']
for name,condition in [
 ('Q256','const COL_CHECKS: usize = 256' in shape),
 ('block_width14','R13_SHIELD_T128_H24' in shape and 'log_cols:14' in shape),
 ('rate4','s.log_cols,4,f_e' in shape),
 ('stage_tier','opened_cols: 256, stage_log_n: 12, stage_inv_rate: 4, ep_log_n: 8, ep_inv_rate: 8' in token),
 ('four_block_parts',all(x in wire for x in ['s.mask_open.write_bytes','s.a_open.write_bytes','s.h_open.write_bytes','s.in_open.write_bytes'])),
 ('classifier_blocks_have_no_last_output','l: self.l() + 2, k: k + 1' in classify),
 ('stage_close_in','closes: vec![(ed, 1, self.in_spec.commitment_rows())]' in classify),
 ('stage_close_out','closes: vec![(bd, 2, b.commitment_rows())]' in classify),
 ('native_query_with_replacement','out.push((v as usize) & (bound - 1));' in sources['10-transcript.rs']),
 ('native_leaf_to_root_path','out.push(lvl[i ^ 1]);' in sources['9-merkle.rs']),
]:
    check('source_contract_'+name,condition)

c=json.loads((E/'census.json').read_text());q=256
# Count separately by roles, never using the experiment's depth-list formula.
role={'all_M':28*q*12*32,'block_AH':2*26*q*16*32,
      'all_boundaries':27*q*16*32,'stage_AH':4*q*14*32,
      'token_input':q*11*32}
check('independent_path_total',sum(role.values())==c['all_path_bytes'])
check('nonpath_total',c['all_path_bytes']+c['non_path_bytes']==848412096)
check('path_below_2percent',c['all_path_fraction']<0.02)
check('factor_below_1point02',c['impossible_free_all_paths_size_factor']<1.02)

rng=random.Random(2026103017201)
for depth in [1,3,7,11,12,14,16]:
    role_name=f'audit-{depth}'.encode();tree=ref.make_tree(depth,role_name)
    for sample in range(4):
        indices=[rng.randrange(1<<depth) for _ in range(256)]
        paths=ref.paths_for(tree,indices)
        # Independent heap-label compression stream, in first-encounter order.
        heap_seen=set();chunks=[]
        for j,p in zip(indices,paths):
            child=(1<<depth)+j
            for sibling_digest in p:
                sibling=child-1 if child%2 else child+1
                if sibling not in heap_seen:
                    chunks.append(sibling_digest);heap_seen.add(sibling)
                child//=2
        expected=b''.join(chunks)
        encoded=codec.encode(indices,paths,256,depth)
        check('independent_stream_bytes',encoded==expected)
        rebuilt=codec.decode(indices,expected,256,depth)
        check('full_record_bytes',ref.record_bytes(indices,rebuilt,role_name)==ref.record_bytes(indices,paths,role_name))
        check('heap_node_count',len(encoded)==32*len(heap_seen))
        for j,p in zip(indices,rebuilt):
            check('independent_path_root',ref.verify(tree,j,p,role_name))
    del tree

main=json.loads((E/'result.json').read_text())
check('main_fixtures',main['fixtures']==50 and main['full_tuple_roundtrips']==50)
check('main_root_checks',main['independent_synthetic_path_verifications']==12800)
check('main_controls',len(main['controls'])==10 and all(main['controls'].values()))
result={'status':'PASS','checks':checks,'total_checks':sum(checks.values()),'independent_role_path_bytes':role,
        'wall_s':time.monotonic()-start,'proofs':0,'proved_positions':0,
        'scope':'Local independently authored geometry/stream audit only; no native proof or privacy acceptance.'}
(E/'audit-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
