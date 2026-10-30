"""Transport/public-key/source-pin validation for NEW R14 schema6 captures.

This validates the native writer output, not privacy/rank/NL1. It deliberately
does not adapt the capture to an old schema or replace physical dimensions.
"""
import hashlib,json,re,sys,os,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent;TREE=HERE/'capture-working-tree';P=2**64-2**32+1
EXTRA=set('stage plan model context input_root output_root scales profiles descriptor arithmetic_reference N a_rows h_rows m_rows external_rows internal_rows physical_planes physical parent domain part log rows_per_component slots base a_pairs h_pairs joint_piece_offsets joint_piece_logs joint_data_rows calibration norm_tn cn_a cn_m ceps d_max f_e f_p shifts gate_shift joint_spec_digest scale'.split())
EXTRA.update('q_heads kv_heads head_dim q_pad t_pad d_pad f_pad components global_feature_start global_feature_width'.split())
EXTRA.update('block_digests receipt_bytes receipt_sha256'.split())
# Schema6 native public binding, base/extension role tag, FS lookup challenges.
EXTRA.update('binding cm logup'.split())
CHUNK_BYTES=1<<16

def stream_array(blob, start, size, expected):
    assert start>=0 and size>=0 and start%8==0 and size%8==0
    blob.seek(start);remaining=size;digest=hashlib.sha256()
    while remaining:
        chunk=blob.read(min(CHUNK_BYTES,remaining))
        assert len(chunk)==min(CHUNK_BYTES,remaining), 'short array read'
        digest.update(chunk)
        assert all(word<P for (word,) in struct.iter_unpack('<Q',chunk)), 'noncanonical field word'
        remaining-=len(chunk)
    assert digest.hexdigest()==expected, 'array hash differs'

def stream_frame(path):
    digest=hashlib.sha256();size=0;head=b'';tail=b''
    with path.open('rb') as frame:
        before=os.fstat(frame.fileno())
        for chunk in iter(lambda:frame.read(CHUNK_BYTES),b''):
            digest.update(chunk);size+=len(chunk)
            if len(head)<248:head+=chunk[:248-len(head)]
            tail=(tail+chunk)[-32:]
        after=os.fstat(frame.fileno())
    assert size==before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns
    return size,digest.hexdigest(),head,tail

def main():
    directory=Path(sys.argv[1]);out=Path(sys.argv[2]);assert not out.exists()
    pin=json.loads((HERE/'sol-r14-capture-build-1.source.json').read_text())
    text=(TREE/'hashline/src/private_block/run_capture.rs').read_text()
    block=text.split('pub(super) const ALLOWED_KEYS: &[&str] = &[',1)[1].split('];',1)[0]
    block='\n'.join(line.split('//',1)[0] for line in block.splitlines())
    allowed=EXTRA|set(re.findall(r'"([^"\\]*)"',block))
    run=json.loads((directory/'run.json').read_text());assert run['schema']=='hashline-native-capture/6-split-run'
    assert run['blocks']==3 and len(run['profiles'])==3
    assert run['fully_verified'] is True and len(run['block_digests'])==3
    assert len(run['binding'])==32 and all(type(v) is int and 0<=v<256 for v in run['binding'])
    assert all(len(d)==32 and all(0<=v<256 for v in d) for d in run['block_digests'])
    assert {r['file']:r['sha256'] for r in run['source_pins']}==pin['files']
    with (directory/'arrays.bin').open('rb') as blob:
        blob_size=os.fstat(blob.fileno()).st_size
        arrays={};allkeys=set();observations=[]
        def visit(node):
            if isinstance(node,dict):
                allkeys.update(node);assert set(node)<=allowed,sorted(set(node)-allowed)
                if 'array' in node:
                    assert set(node)=={'array','elem','len','offset','bytes'}
                    size={'fp':8,'fp2':16}[node['elem']];assert node['bytes']==node['len']*size
                    start=node['offset'];end=start+node['bytes'];assert 0<=start<=end<=blob_size and start%8==0
                    if node['array'] not in arrays:
                        stream_array(blob,start,node['bytes'],node['array'])
                        arrays[node['array']]={'offset':start,'bytes':node['bytes']}
                    else:assert arrays[node['array']]=={'offset':start,'bytes':node['bytes']}
                else:
                    for value in node.values():visit(value)
            elif isinstance(node,list):
                for value in node:visit(value)
        visit(run)
        roots=set();committed={tuple(run['input_root']),tuple(run['output_root'])};assert len(committed)==2
        previous_boundary=None;previous_end=None;receipts=[]
        for k,profile in enumerate(run['profiles']):
            assert (profile['tokens'],profile['width'],profile['hidden'])==(128,3072,9216)
            assert (profile['q_heads'],profile['kv_heads'],profile['head_dim'],profile['q_pad'])==(32,8,128,4096)
            assert (profile['t_pad'],profile['d_pad'],profile['f_pad'])==(128,4096,16384)
            assert all(type(p['cm']) is int and p['cm'] in [0,1] for p in profile['physical_planes'])
            for cm in [0,1]:
                planes=[p for p in profile['physical_planes'] if p['cm']==cm]
                assert [p['physical'] for p in planes]==list(range(len(planes)))
                cursor=0;parents={}
                for plane in planes:
                    assert plane['name'] and plane['components']==cm+1
                    assert plane['offset']==cursor*profile['N']
                    assert plane['rows_per_component']==max(1,((1<<plane['log'])+profile['N']-1)//profile['N'])
                    cursor+=(cm+1)*plane['rows_per_component']
                    parents.setdefault(plane['parent'],[]).append(plane)
                    if plane['domain'] in ['D','F']:
                        wide=2048 if plane['domain']=='D' else 8192
                        start,width={'Wide':(0,wide),'Narrow':(wide,1024)}[plane['part']]
                        assert (plane['global_feature_start'],plane['global_feature_width'])==(start,width)
                        assert (1<<plane['log'])==profile['tokens']*width
                    else:
                        assert plane['part']=='Whole'
                        assert plane['global_feature_start'] is None and plane['global_feature_width'] is None
                assert sorted(parents)==list(range(len(parents)))
                for pieces in parents.values():
                    assert len({p['domain'] for p in pieces})==len({p['name'] for p in pieces})==1
                    assert [p['part'] for p in pieces]==(['Wide','Narrow'] if pieces[0]['domain'] in ['D','F'] else ['Whole'])
                reserved=[row for slot in profile['slots'] for row in slot['h_pairs' if cm else 'a_pairs']]
                assert reserved==list(range(cursor,profile['h_rows' if cm else 'a_rows']-2,2))
            stage=json.loads((directory/f'stage{k}.json').read_text());visit(stage)
            assert stage['schema']==run['schema'] and stage['stage']==k
            assert len(stage['logup'])==3 and all(len(v)==2 and all(type(w) is int and 0<=w<P for w in v) for v in stage['logup'])
            frame_size,frame_hash,frame,frame_tail=stream_frame(directory/f'segment{k}.bin')
            assert frame_size==stage['receipt_bytes'] and frame_hash==stage['receipt_sha256']
            assert frame[:8]==b'HLPR14S1' and list(frame[8:40])==run['binding']
            assert list(frame[40:72])==profile['descriptor']
            assert int.from_bytes(frame[72:80],'little')==3 and int.from_bytes(frame[80:88],'little')==k
            assert list(frame[88:120])==stage['start_tag'] and list(frame_tail)==stage['end_tag']
            if previous_end is not None:assert stage['start_tag']==previous_end
            previous_end=stage['end_tag'];offset=120
            if k<2:assert list(frame[offset:offset+32])==stage['boundary'];offset+=32
            assert [list(frame[offset+i*32:offset+(i+1)*32]) for i in range(3)]==[stage['a_root'],stage['h_root'],stage['mask_root']]
            receipts.append({'stage':k,'bytes':frame_size,'sha256':stage['receipt_sha256']})
            assert stage['mask']['root']==stage['mask_root']
            for root in [stage['a_root'],stage['h_root'],stage['mask_root']]+([stage['boundary']] if stage['boundary'] is not None else []):
                assert len(root)==32 and all(0<=b<256 for b in root)
                key=tuple(root);assert key not in committed,'repeated native commitment root';committed.add(key)
            assert (stage['boundary'] is not None)==(k<2)
            assert len(stage['arguments'])==len(profile['slots'])
            assert len(stage['mask']['specs'])==len(profile['slots'])
            assert stage['mask']['rows']==profile['m_rows']
            for arg,meta in zip(stage['arguments'],profile['slots']):
                assert (arg['slot'],arg['main'],arg['extension'],arg['degree'])==(meta['slot'],meta['main'],meta['extension'],meta['degree'])
                assert len(arg['rounds'])==meta['main']+meta['extension']
                assert all(len(row)==meta['degree']+1 for row in arg['rounds'])
            assert [r['role'] for r in stage['roles']]==(['A','H','Input','Output'] if k==2 else ['A','H','Input'])
            for role in stage['roles']:
                key=tuple(role['commitment']['root']);assert key not in roots,'commitment opened twice in capture';roots.add(key)
                assert key in committed
                if role['role'] in ['A','H']:
                    assert role['commitment']['root']==stage['a_root' if role['role']=='A' else 'h_root']
                    assert role['commitment']['rows']==profile['a_rows' if role['role']=='A' else 'h_rows']
                    sites=sum(len(s['a_pairs' if role['role']=='A' else 'h_pairs']) for s in profile['slots'])
                    assert len(role['claims'])==sites+(role['role']=='H')
                    assert len(role['site_rows'])==2*sites
                if role['role'] in ['Input','Output']:
                    internal=role['commitment_kind']=='internal-boundary';expected=4 if internal else 2
                    assert len(role['claims'])==expected and len(role['claim_sources'])==expected
                    assert len(role['groups'])==expected and 'joint_spec_digest' in role and 'scale' in role
                    assert role['data_rows']==24 and role['commitment']['rows']==(34 if internal else 31)
                    assert role['boundary']==(k if internal else None)
                    assert len(role['site_rows'])==2*expected
                    assert role['commitment']['root']==(previous_boundary if internal else run['output_root'] if role['role']=='Output' else run['input_root'])
                observations.append({'stage':k,'role':role['role'],'root':list(key),'groups':len(role['groups']),
                    'claims':len(role['claims']),'rows':role['commitment']['rows'],'boundary':role['boundary']})
            previous_boundary=stage['boundary']
        assert len(observations)==10
        assert len(committed)==13 and len(roots)==10
        report={'schema':run['schema'],'stages':3,'source':pin['tree_sha256'],'array_objects':len(arrays),
            'array_bytes':blob_size,'observations':observations,'receipts':receipts,'keys':sorted(allkeys),
            'validator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'status':'PASS native capture transport/source/public allow-list validation',
            'scope':'Native accepted-run observer output only. Not a rank/CFSbudget/NL1/joint-view privacy result; no old schema overlay.'}
        out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':'PASS','stages':3,'openings':10,'arrays':len(arrays),'privacy_acceptance':False}))
if __name__=='__main__':main()
