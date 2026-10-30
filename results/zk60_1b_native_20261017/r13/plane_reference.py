"""Independent pre-registered R13 role/domain inventory, before native layout.

This is a COUNTED construction reference, not evidence that a proof enforces
these roles. Native Ids/Shape/lookup lists must independently agree with it.
"""
from pathlib import Path
import json

def limbs(name,count):return [f'{name}{i}' for i in range(count)]

def inventory(stack,dd,ls):
    assert stack in ('low','low-h24') and ls in (2,3)
    h24=stack=='low-h24'
    d=['X',*limbs('XL',2),'Y',*limbs('YL',2),*limbs('NR',3),*limbs('NS',3),
       'AO',*limbs('AL',2),*limbs('RAL',3),'X1',*limbs('X1L',2),'YM',*limbs('YML',2),
       *limbs('MR',3),*limbs('MS',3),'Z',*limbs('ZL',2),*limbs('RDL',3 if h24 else 2),
       'X2',*limbs('X2L',2)]
    q=['Q',*limbs('QL',2),*limbs('RQL',2),'QR',*limbs('QRL',2),'RQRL',
       'O',*limbs('OL',2),*limbs('RO',2)]
    kv=['K',*limbs('KL',2),*limbs('RKL',2),'V',*limbs('VL',2),*limbs('RVL',2),
        'KR',*limbs('KRL',2),'RKRL']
    s=['S',*limbs('RSL',3),'ZSEL','E','P']
    division=[*limbs('PL',2),*limbs('SR',ls),*limbs('SG',ls)]
    if not dd:s+=division
    f=['G',*limbs('RGL',3),'A_SCALED','U',*limbs('UL',2),*limbs('RU',2),
       'H',*limbs('HL',3 if h24 else 2),*limbs('RH',2 if h24 else 3)]
    domains={'T':['D','DSQ','DM','DSQM'],'Ht':['MX','SUM'],'L':['LIMB','LIMBM'],
             'D':d,'Q':q,'Kv':kv,'S':s,'F':f}
    if dd:domains['Dd']=['PDICT',*division,'MDD']
    domains['Tab']=['MU8','MEXP','MACT']
    expected={'T':4,'Ht':2,'L':2,'D':39 if h24 else 38,'Q':14,'Kv':14,
              'S':7 if dd else 9+2*ls,'F':16,'Tab':3}
    if dd:expected['Dd']=4+2*ls
    assert {name:len(roles) for name,roles in domains.items()}==expected
    roles=[role for group in domains.values() for role in group]
    assert len(roles)==len(set(roles))
    assert not set(['NR3','NS3','MR3','MS3']).intersection(roles)
    lookups={'T':0,'Ht':0,'L':2,'D':34 if h24 else 33,'Q':14,'Kv':14,
             'S':6 if dd else 11+2*ls,'F':14,'Tab':0}
    if dd:lookups['Dd']=5+2*ls
    return {'stack':stack,'dd':dd,'sigma_limbs':ls,'domains':domains,'plane_counts':expected,
            'u8_lookups_per_position':lookups,'output_plane':roles.index('X2'),
            'absent_legacy_roles':['NR3','NS3','MR3','MS3']}

def main():
    rows=[inventory(stack,dd,ls) for stack in ('low','low-h24') for dd in (False,True) for ls in (2,3)]
    out=Path(__file__).with_name('plane_reference.json')
    out.write_text(json.dumps({'scope':'COUNTED reference only; native enforcement not yet implemented','cases':rows},indent=2)+'\n')
    print(json.dumps([{'stack':r['stack'],'dd':r['dd'],'ls':r['sigma_limbs'],'planes':sum(r['plane_counts'].values()),'output_plane':r['output_plane']} for r in rows]))

if __name__=='__main__':main()
