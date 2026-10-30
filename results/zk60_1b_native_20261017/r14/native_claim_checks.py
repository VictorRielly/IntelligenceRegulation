"""Schema6 native private-functional/claim and B-gate provenance checks.

Rebuilds every published ZClaim from the observed native Tab, extension
challenges and masked terminal. Checks new norm/matrix projections and public
zero lifts. This is not the complete polynomial, rank or privacy proof.
"""
import argparse,hashlib,json,re,struct
from pathlib import Path
from native_mask_checks import P,ZERO,ONE,pair,sub,mul
U=(0,1)
def product(values):
    out=ONE
    for v in values:out=mul(out,v)
    return out
def coordinates(table,rho,main):
    point=[];moving=[]
    for coord in table['coordinates']:
        assert len(coord)==1
        if 'fixed' in coord:point.append(pair(coord['fixed']))
        else:
            kind=next(iter(coord));assert kind in ['rho','flip']
            i=coord[kind];assert type(i) is int and 0<=i<main
            moving.append(i);point.append(rho[i] if kind=='rho' else sub(ONE,rho[i]))
    assert len(set(moving))==len(moving),'repeated moving coordinate'
    assert len(point)==table['log_size'];return point
def rebuilt_claim(table,arg,logn,value):
    rho=[pair(v) for v in arg['rho']];main=arg['main'];point=coordinates(table,rho,main)
    extensions=rho[main:];assert len(extensions)==arg['extension']
    assert all(e not in [ZERO,ONE] for e in extensions)
    ext=table['extension_round'];assert 0<=ext<len(extensions)
    cd=product(sub(ONE,e) for e in extensions)
    cm=mul(extensions[ext],product(sub(ONE,e) for e in extensions[ext+1:]))
    log=table['log_size'];n=1<<logn;tail_log=min(log,logn)
    column=table['slices'][0]['offset']%n if log<logn else 0
    def part(offset,log_size,coefficient,point):
        return {'offset':offset,'log_size':log_size,'coefficient':list(coefficient),'point':[list(v) for v in point]}
    parts=[part(s['offset'],log,mul(pair(s['coefficient']),cd),point) for s in table['slices']]
    parts += [part((table['mask_row']+k)*n+column,tail_log,mul(cm,u),point[-tail_log:]) for k,u in enumerate([ONE,U])]
    return {'value':list(pair(value)),'parts':parts}
def source_plane(profile,table):
    cm={'A':0,'H':1}[table['role']];slices=table['slices']
    assert [pair(s['coefficient']) for s in slices]==([ONE] if cm==0 else [ONE,U]),'private source carries a lift/foreign coefficient'
    candidates=[];N=profile['N'];log=table['log_size']
    for plane in profile['physical_planes']:
        if plane['cm']!=cm:continue
        delta=None
        for component,sl in enumerate(slices):
            start=plane['offset']+component*plane['rows_per_component']*N
            offset=sl['offset']-start
            if offset<0 or offset+(1<<log)>1<<plane['log']:break
            if delta is not None and delta!=offset:break
            delta=offset
        else:candidates.append(plane)
    assert len(candidates)==1,'source slice crosses or aliases physical roles';return candidates[0]
def split_projection(table,plane,arg,profile,*,norm=False):
    lt=profile['t_pad'].bit_length()-1
    own=(plane['global_feature_width'].bit_length()-1) if plane['domain'] in ['D','F'] else plane['log']-lt
    if norm:
        large=arg['main']-lt
        expected=[{'rho':i} for i in range(lt)]+[{'rho':i} for i in range(lt+large-own,lt+large)]
    else:
        assert all(set(c)=={'fixed'} for c in table['coordinates'][:lt]),'matrix token point is not fixed'
        expected=table['coordinates'][:lt]+[{'rho':i} for i in range(arg['main']-own,arg['main'])]
    assert table['coordinates']==expected,'wrong omitted feature bit or moving token map'
    assert table['slices'][0]['offset']==plane['offset'] and table['log_size']==plane['log']
    return own
def check_run(run,stages,constants,public_values):
    assert len(stages)==len(run['profiles'])==run['blocks']
    opened=[{r['role']:r for r in st['roles']} for st in stages];used=set();site_pairs=set();report=[]
    norm_bases={constants['SC_SS']:'A_X',constants['SC_SSM']:'A_X1'}
    matrix_bases={constants[k]:name for k,name in [('SC_QMM','A_Y'),('SC_KMM','A_Y'),('SC_VMM','A_Y'),
        ('SC_WO','A_O'),('SC_GMM','A_YM'),('SC_UMM','A_YM'),('SC_DMM','A_H')]}
    for k,(stage,profile) in enumerate(zip(stages,run['profiles'])):
        token_points={};counts={'private_tables':0,'split_norms':0,'split_matrices':0,'public_zero_tail_words':0}
        for arg,meta in zip(stage['arguments'],profile['slots']):
            assert arg['slot']==meta['slot'];local={'A':0,'H':0};term=0;projections=[]
            for table in arg['tables']:
                if table['kind']!='private':continue
                role=table['role'];index=table['claim'];carrier=k;carrier_role=role
                if role=='Input':index+=2 if k else 0
                if role=='Output' and k+1<len(stages):carrier=k+1;carrier_role='Input'
                opening=opened[carrier][carrier_role];logn=opening['params']['log_cols']
                assert (1<<logn)==profile['N']
                key=(carrier,carrier_role,index);assert key not in used,'published claim reused';used.add(key)
                expected=rebuilt_claim(table,arg,logn,arg['terminals'][term]);term+=1
                assert opening['claims'][index]==expected,('native Tab/terminal-to-claim mismatch',k,arg['slot'],role,index)
                if role in ['A','H']:
                    plane=source_plane(profile,table)
                    assert table['mask_row']==meta['a_pairs' if role=='A' else 'h_pairs'][local[role]]
                    local[role]+=1
                    if role=='A' and meta['base'] in norm_bases|matrix_bases:
                        is_norm=meta['base'] in norm_bases
                        assert plane['name']==(norm_bases|matrix_bases)[meta['base']]
                        own=split_projection(table,plane,arg,profile,norm=is_norm)
                        projections.append((table,plane,own))
                    if role=='A' and meta['base'] in [constants['SC_IO_IN'],constants['SC_IO_OUT']]:
                        assert plane['name']==('A_X' if meta['base']==constants['SC_IO_IN'] else 'A_X2')
                        assert plane['part']==meta['part']
                        assert table['coordinates']==[{'rho':i} for i in range(table['log_size'])]
                else:
                    assert role in ['Input','Output'] and len(table['slices'])==1 and pair(table['slices'][0]['coefficient'])==ONE
                    piece={'Wide':0,'Narrow':1}[meta['part']]
                    assert table['slices'][0]['offset']==profile['joint_piece_offsets'][piece]
                    assert table['log_size']==profile['joint_piece_logs'][piece]
                    assert table['coordinates']==[{'rho':i} for i in range(table['log_size'])]
                    assert table['mask_row']==profile['joint_data_rows']+2*((2 if role=='Input' and k else 0)+piece)
                rows={table['mask_row'],table['mask_row']+1}
                assert rows<=set(opening['site_rows'])
                site=(tuple(opening['commitment']['root']),table['mask_row']);assert site not in site_pairs;site_pairs.add(site)
                counts['private_tables']+=1
            assert term==len(arg['terminals'])
            assert (local['A'],local['H'])==(len(meta['a_pairs']),len(meta['h_pairs']))
            if meta['base'] in norm_bases:
                assert len(arg['tables'])==4 and len(projections)==2
                assert [p['part'] for _,p,_ in projections]==['Wide','Narrow']
                lt=profile['t_pad'].bit_length()-1;wide=arg['tables'][0];narrow=arg['tables'][2]
                assert wide['kind']==narrow['kind']=='eq' and wide['start']==narrow['start']==0
                assert wide['point']==arg['definition_challenges'][:lt]
                omitted=projections[0][2]-projections[1][2]
                assert narrow['point']==wide['point']+[[0,0]]*omitted,'norm public zero selector'
                assert arg['degree']==3;counts['split_norms']+=1
            if meta['base'] in matrix_bases:
                assert len(arg['tables'])==2*len(projections)
                lt=profile['t_pad'].bit_length()-1
                point=projections[0][0]['coordinates'][:lt]
                assert all(t['coordinates'][:lt]==point for t,_,_ in projections)
                logical=meta['base'];group='qkv' if logical in [constants[x] for x in ['SC_QMM','SC_KMM','SC_VMM']] else 'wo' if logical==constants['SC_WO'] else 'ff' if logical in [constants[x] for x in ['SC_GMM','SC_UMM']] else 'down'
                fresh=logical==constants['SC_QMM'] or (logical in [constants[x] for x in ['SC_WO','SC_GMM','SC_DMM']] and meta['part']=='Wide')
                if fresh:
                    assert point==[{'fixed':v} for v in arg['definition_challenges'][:lt]]
                    token_points[group]=point
                assert token_points[group]==point,'matrix token point reset'
                for j,(_,_,own) in enumerate(projections):
                    table=arg['tables'][2*j+1];assert table['kind']=='public' and table['len']==1<<arg['main']
                    values=public_values(table);assert len(values)==table['len']
                    tail=values[1<<own:];assert all(v==ZERO for v in tail),'missing public zero lift'
                    counts['public_zero_tail_words']+=len(tail)
                counts['split_matrices']+=1
        # The sole H sum identity includes every actual physical component;
        # it is not a private terminal site and retains its own known identity.
        h=opened[k]['H'];parts=[]
        for plane in profile['physical_planes']:
            if plane['cm']!=1:continue
            sign=-1 if plane['name'] in ['H_GU8','H_GEXP','H_GACT','H_GDD'] else 1
            for component,coefficient in enumerate([ONE,U]):
                coefficient=mul((sign%P,0),coefficient)
                parts.append({'offset':plane['offset']+component*plane['rows_per_component']*profile['N'],
                    'log_size':plane['log'],'coefficient':list(coefficient),'point':[]})
        assert h['claims'][-1]=={'value':[0,0],'parts':parts}
        used.add((k,'H',len(h['claims'])-1));report.append({'stage':k,**counts})
    assert used=={(k,r['role'],i) for k,st in enumerate(stages) for r in st['roles'] for i in range(len(r['claims']))},'claim coverage incomplete'
    return {'stages':report,'published_claims_checked':len(used),'exclusive_site_pairs_checked':len(site_pairs)}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--bundle',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();assert not args.output.exists();here=Path(__file__).resolve().parent
    run=json.loads((args.bundle/'run.json').read_text());assert run['schema']=='hashline-native-capture/6-split-run' and run['fully_verified'] is True
    pin=json.loads((here/'sol-r14-capture-build-1.source.json').read_text());assert {v['file']:v['sha256'] for v in run['source_pins']}==pin['files']
    path=here/'capture-working-tree/hashline/src/private_block/layout.rs';assert sha(path)==pin['files']['hashline/src/private_block/layout.rs']
    constants={name:int(value) for name,value in re.findall(r'pub\(crate\) const (SC_\w+): usize = (\d+);',path.read_text())}
    stages=[json.loads((args.bundle/f'stage{k}.json').read_text()) for k in range(run['blocks'])]
    with (args.bundle/'arrays.bin').open('rb') as blob:
        def public_values(table):
            value=table['values']
            if isinstance(value,list):data=b''.join(struct.pack('<QQ',*pair(v)) for v in value)
            else:
                assert value['elem']=='fp2' and value['len']==table['len'] and value['bytes']==16*table['len']
                blob.seek(value['offset']);data=blob.read(value['bytes']);assert len(data)==value['bytes']
                assert hashlib.sha256(data).hexdigest()==value['array']
            assert hashlib.sha256(data).hexdigest()==table['sha256']
            return [pair(v) for v in struct.iter_unpack('<QQ',data)]
        result=check_run(run,stages,constants,public_values)
    result.update(schema=run['schema'],source=pin['tree_sha256'],checker_sha256=sha(Path(__file__)),
        field_helper_sha256=sha(here/'native_mask_checks.py'),privacy_acceptance=False,
        status='PASS native Tab/claim provenance, unscaled private projections and public B-gates',
        scope='Exact observed private terminal/PCS claim binding, all three-stage boundary sources, both new norm pieces and all matrix broadcasts/zero lifts. Does not reconstruct all host polynomials or global weight folds; full rank/NL1/privacy review still required.')
    args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'claims':result['published_claims_checked'],'status':'PASS limited native claim/projection checks','privacy_acceptance':False}))
if __name__=='__main__':main()
