"""Prospective semantic obligations, NOT native claims or an accepted ZK design.

Identifiers include ordered original expression, column, layer, branch and
component. Counting them does not prove binding or give a minimum PCS budget.
"""
import hashlib, json
from fp2 import E

ORDER = ('L', 'D', 'Q', 'Kv', 'F', 'S', 'Dd')

def expression(plane, coef=1, cst=0):
    return {'terms': [[plane, coef]], 'cst': cst}

def lookups(T, dd):
    """Symbolic shaped plane names from pinned layout::lookups_at, w32/fE9."""
    ln, ls, lp = 4, ((T.bit_length()-1+9)+7)//8, 2
    w = T.bit_length()-1+9
    out = {d: [] for d in ORDER}
    def byte(d, p): out[d].append(expression(p))
    def scaled(d, p, k): out[d].append(expression(p, k))
    def sym(d, p): out[d].extend([expression(p,1,127), expression(p,-1,127)])
    def seq(d, *ps):
        for p in ps: byte(d,p)
    seq('L','A_LIMB','A_LIMBM')
    seq('D','A_XL0','A_XL1'); sym('D','A_Y')
    seq('D',*[f'nr:{k}' for k in range(ln)],*[f'ns:{k}' for k in range(ln)])
    seq('D','A_AL0','A_AL1','A_RAL'); scaled('D','A_RAL',2)
    seq('D','A_X1L0','A_X1L1');sym('D','A_YM')
    seq('D',*[f'mr:{k}' for k in range(ln)],*[f'ms:{k}' for k in range(ln)])
    seq('D','A_X2L0','A_X2L1','A_ZL0','A_ZL1','A_RDL');scaled('D','A_RDL',4)
    seq('F','A_RGL');scaled('F','A_RGL',2)
    seq('F','A_UL0','A_UL1','A_HL0','A_HL1','A_RH0','A_RH1');scaled('F','A_RH1',4)
    sym('Q','A_Q8');byte('Q','A_RQL');scaled('Q','A_RQL',2)
    sym('Q','A_QR8');byte('Q','A_RQRL');scaled('Q','A_RQRL',2)
    sym('Q','A_O8');seq('Q','A_RO0','A_RO1');scaled('Q','A_RO1',128)
    for p, rem in [('A_K8','A_RKL'),('A_V8','A_RVL'),('A_KR8','A_RKRL')]:
        sym('Kv',p);byte('Kv',rem);scaled('Kv',rem,2)
    sym('S','A_S8');byte('S','A_RSL');scaled('S','A_RSL',4)
    d = 'Dd' if dd else 'S'
    seq(d,*[f'pl:{k}' for k in range(lp)]);scaled(d,f'pl:{lp-1}',64)
    for name in ('sr','sg'):
        seq(d,*[f'{name}:{k}' for k in range(ls)])
        scaled(d,f'{name}:{ls-1}',1 << (8*ls-w))
    return out

def fingerprint(obj):
    return hashlib.sha256(json.dumps(obj,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def columns(fixture):
    desc=lookups(fixture['T'],fixture['dd']);out=[];j=0
    for dom in ORDER:
        for ordinal,expr in enumerate(desc[dom]):
            out.append({'column':j,'domain':dom,'ordinal':ordinal,'expression':expr,
                        'expression_hash':fingerprint(expr),'size':fixture['sizes'][j],
                        'source':'original_A','leaf_private_component':'D'})
            j+=1
    assert j+1==len(fixture['sizes']) and fixture['sizes'][-1]==256
    out.append({'column':j,'domain':'Tab','ordinal':0,'expression':{'plane':'A_MU8'},
                'expression_hash':fingerprint({'plane':'A_MU8'}),'size':256,
                'source':'single_global_A_MU8','leaf_private_component':'N'})
    return out

def obligations(fixture):
    out=[]
    for col in columns(fixture):
        h=col['size'].bit_length()-1
        for depth in range(1,h+1):
            for branch in (0,1):
                for component in ('N','D'):
                    leaf=depth==h
                    private=not leaf or component==col['leaf_private_component']
                    out.append({'column':col['column'],'domain':col['domain'],
                        'ordinal':col['ordinal'],'expression_hash':col['expression_hash'],
                        'depth':depth,'branch':branch,'component':component,
                        'point_rule':'reverse(data_rho_lsb) || branch',
                        'privacy':'private' if private else 'public',
                        'binding':'original_A' if leaf and private else
                                  'public_leaf' if leaf else 'recursive_internal',
                        'native_site':None,'reserved_mask_pair':None,
                        'opening_group':None})
    return out

def validate_ledger(candidate, fixture):
    # Exact ordered provenance, not just count, uniqueness or multiset.
    if candidate != obligations(fixture): raise ValueError('ordered obligation provenance')

def native_child_point(rho_lsb, branch):
    if branch not in (0,1): raise ValueError('branch')
    return list(reversed(rho_lsb))+[E(branch)]

def native_merged_point(rho_lsb, eta):
    return list(reversed(rho_lsb))+[eta]

def mask_payload_if_separate_native_pairs(obligation_count, log_cols):
    # Only 2 reserved BASE-field rows per hypothetical native claim; omits
    # proximity, data, encoding, Merkle trees, CFS, groups and all transfers.
    return 2*obligation_count*(1 << log_cols)*8

def summary(fixture):
    o=obligations(fixture);priv=[x for x in o if x['privacy']=='private']
    leaf=[x for x in priv if x['binding']=='original_A']
    cols=columns(fixture)
    return {'model':fixture['model'],'T':fixture['T'],'dd':fixture['dd'],
        'scope':fixture['scope'],'ordered_lookup_columns':len(cols)-1,'global_tables':1,
        'tree_layers':sum(c['size'].bit_length()-1 for c in cols),
        'all_semantic_terminals':len(o),'private_semantic_terminals':len(priv),
        'unmerged_original_A_leaf_obligations':len(leaf),
        'ledger_sha256':fingerprint(o),
        'conditional_private_pair_payload_by_log_cols':{str(k):mask_payload_if_separate_native_pairs(len(priv),k) for k in (13,14,15)},
        'conditional_leaf_pair_payload_by_log_cols':{str(k):mask_payload_if_separate_native_pairs(len(leaf),k) for k in (13,14,15)},
        'old_U8_helper_bytes_carried':fixture['old_U8_helper_bytes'],
        'actual_new_private_claim_sites':None,'actual_extension_rounds':None,
        'actual_CFS_coefficients':None,'actual_PCS_groups':None,
        'native_net_memory_saving_bytes':None,'native_time_saving_s':None}
