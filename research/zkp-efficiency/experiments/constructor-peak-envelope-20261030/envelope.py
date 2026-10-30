"""Requested field/digest payload model; NEVER an actual-fit admission gate.

Every phase additionally owes unknown witness/model/allocator/backend/scratch,
other blocks, proof/output and quarantine reserves. Host and device distinct.
"""
def constructor(rows,n,q=256,rate=4,workers=1):
 nn=n*rate
 data=rows*n*8;encoded=rows*nn*8;pads=rows*q*8
 salts=nn*32;pows=nn*8;leaves=nn*32;tree=(2*nn-1)*32
 base=data+encoded+pads+salts+pows
 phases={'encode':base+min(workers,rows)*n*8,
         'hash':base+leaves+min(workers,(nn+63)//64)*min(64,nn)*rows*8,
         'salt':base+2*leaves,
         'tree':base+leaves+tree}
 resident=data+encoded+pads+salts+tree
 return {'resident':resident,'phases':phases,'peak':max(phases.values()),
         'extra_above_resident':max(phases.values())-resident}

def proof_phases(c,meta,workers=1):
 t,w,f,h,dh,kv,lc,dd,nw,sw,low=c['v'];n=1<<lc
 ar,hr,m,slot_log,k,*_=c['metadata']
 looked,scores,acts,mrows,coeffs,slots=meta
 er=max(1,(1<<(t-1).bit_length())*(1<<(w-1).bit_length())//n)+5
 # Same endpoint geometry as prior partial ledger, explicitly not all run boundaries.
 E=constructor(er,n,workers=workers);A=constructor(ar,n,workers=workers);H=constructor(hr,n,workers=workers)
 md=4096;mm=512
 M=mrows*md*8+coeffs*16+2*slots*mm*8+4*2*mm*8+md*32+(2*md-1)*32
 transient=looked*8+scores*8+(0 if low else acts*8)
 phases={}
 # W marks the still-live witness whose capacity is deliberately unknown.
 for phase,v in A['phases'].items():phases['A_'+phase]={'known_bytes':2*E['resident']+v+transient,'witness_live':True}
 phases['M_hash']={'known_bytes':2*E['resident']+A['resident']+M-(2*md-1)*32+md*8+md*32+min(workers,md//64)*64*mrows*8+transient,'witness_live':True}
 phases['M_tree']={'known_bytes':2*E['resident']+A['resident']+M+md*8+md*32+transient,'witness_live':True}
 phases['H_helpers']={'known_bytes':2*E['resident']+A['resident']+M+hr*n*8+transient+32*max(scores,acts),'witness_live':True}
 for phase,v in H['phases'].items():phases['H_'+phase]={'known_bytes':2*E['resident']+A['resident']+M+v,'witness_live':False}
 phases['SC_SZC']={'known_bytes':2*E['resident']+A['resident']+H['resident']+M+k*(1<<slot_log)*16,'witness_live':False}
 return {'id':c['id'],'context_metadata':t,'workers_model_only':workers,'single_block_only':True,'endpoint_rows':er,
         'A':A,'H':H,'M_resident_payload':M,'known_transient_payload':transient,'phases':phases,
         'max_known_payload':max(x['known_bytes'] for x in phases.values()),'actual_fit':None,
         'missing_reserves':['witness capacity W while live','public/resident model','remaining run boundaries and other blocks','all omitted helper/DD/accuracy temporaries','Vec headers and capacity excess','backend offers and device buffers','NTT tables and caches','proof/open/serialization output','pools and pending frees/quarantine','allocator/driver/other processes']}

def reserve(known,unknown):
 """An incomplete manifest cannot establish admission, even at huge budgets."""
 if any(x is None for x in unknown.values()):return None
 if known<0 or any(x<0 for x in unknown.values()):raise ValueError('negative reserve')
 return known+sum(unknown.values())
