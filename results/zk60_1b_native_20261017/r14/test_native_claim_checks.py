"""Exact small-operator and refusal controls; not native capture acceptance."""
import copy,itertools,unittest
import native_claim_checks as c
from native_mask_checks import add,mul,sub,ONE,ZERO

def mle(words,point):
    out=ZERO
    for index,word in enumerate(words):
        factor=ONE
        for bit,r in zip([(index>>(len(point)-1-j))&1 for j in range(len(point))],point):
            factor=mul(factor,r if bit else sub(ONE,r))
        out=add(out,mul(word,factor))
    return out

def three_stage_fixture():
    # A deliberately small explicit IO-only graph. All claims below are
    # written directly from its row addresses; no rebuilt_claim call is used.
    keys=['SC_SS','SC_SSM','SC_QMM','SC_KMM','SC_VMM','SC_WO','SC_GMM','SC_UMM','SC_DMM']
    constants={name:i for i,name in enumerate(keys)};constants.update(SC_IO_IN=21,SC_IO_OUT=22)
    profiles=[];stages=[];endpoint=[[] for _ in range(4)]
    def claim(offset,log,mask,point,e,value):
        return {'value':list(value),'parts':[
            {'offset':offset,'log_size':log,'coefficient':list(sub(ONE,e)),'point':point},
            {'offset':mask*8,'log_size':3,'coefficient':list(e),'point':point[-3:]},
            {'offset':(mask+1)*8,'log_size':3,'coefficient':list(mul(e,c.U)),'point':point[-3:]}]}
    for k in range(3):
        planes=[]
        for i,(name,part,offset,log) in enumerate([('A_X','Wide',0,4),('A_X','Narrow',16,3),('A_X2','Wide',24,4),('A_X2','Narrow',40,3)]):
            planes.append({'cm':0,'offset':offset,'log':log,'rows_per_component':1 if log==3 else 2,
                'domain':'D','name':name,'part':part,'global_feature_width':4 if part=='Wide' else 2})
        planes.append({'cm':1,'offset':0,'log':3,'rows_per_component':1,'domain':'Tab','name':'H_U','part':'Whole'})
        args=[];metadata=[];ac=[]
        for s in range(4):
            outgoing=s>=2;piece=s%2;log=4-piece;point=[[j+k+s+2,j*3+s+1] for j in range(log)]
            e=(s+3,k+5);termA=(k*10+s+1,s+7);termIO=(k*10+s+21,s+27)
            private={'kind':'private','role':'A','claim':s,'log_size':log,'coordinates':[{'rho':j} for j in range(log)],
                'slices':[{'offset':planes[s]['offset'],'coefficient':[1,0]}],'mask_row':6+2*s,'extension_round':0}
            mask=3+2*((2 if not outgoing and k else 0)+piece)
            io=dict(private,role='Output' if outgoing else 'Input',claim=piece,
                slices=[{'offset':16*piece,'coefficient':[1,0]}],mask_row=mask)
            args.append({'slot':s,'main':log,'extension':1,'rho':point+[list(e)],'terminals':[list(termA),list(termIO)],'tables':[private,io]})
            metadata.append({'slot':s,'base':22 if outgoing else 21,'part':'Narrow' if piece else 'Wide','a_pairs':[6+2*s],'h_pairs':[]})
            ac.append(claim(planes[s]['offset'],log,6+2*s,point,e,termA))
            endpoint[k+int(outgoing)].append(claim(16*piece,log,mask,point,e,termIO))
        profiles.append({'N':8,'t_pad':4,'physical_planes':planes,'joint_piece_offsets':[0,16],
            'joint_piece_logs':[4,3],'joint_data_rows':3,'slots':metadata})
        def opening(role,root,claims,sites):return {'role':role,'params':{'log_cols':3},'commitment':{'root':[root]*32},'claims':claims,'site_rows':sites}
        hsum={'value':[0,0],'parts':[{'offset':0,'log_size':3,'coefficient':[1,0],'point':[]},
            {'offset':8,'log_size':3,'coefficient':[0,1],'point':[]}]}
        roles=[opening('A',k+1,ac,list(range(6,14))),opening('H',k+11,[hsum],[]),
            opening('Input',k+21,endpoint[k],list(range(3,11 if k else 7)))]
        if k==2:roles.append(opening('Output',24,endpoint[3],list(range(3,7))))
        stages.append({'arguments':args,'roles':roles})
    return {'blocks':3,'profiles':profiles},stages,constants

class NativeClaimChecks(unittest.TestCase):
    def setUp(self):
        self.profile={'N':8,'t_pad':4,'physical_planes':[{'cm':0,'offset':0,'log':4,'rows_per_component':2,
            'domain':'D','global_feature_width':4,'name':'A_X','part':'Narrow'}]}
        self.table={'kind':'private','role':'A','log_size':2,'coordinates':[{'rho':1},{'fixed':[7,9]}],
            'slices':[{'offset':1,'coefficient':[1,0]}],'mask_row':10,'extension_round':0}
        self.arg={'main':3,'extension':2,'rho':[[2,1],[4,3],[6,5],[3,4],[5,6]]}
    def test_full_claim_matches_literal_two_extension_operator_on_subrow(self):
        data=[(i+1,i*2+3) for i in range(96)]
        point=[(4,3),(7,9)];e0=(3,4);e1=(5,6)
        original=mle(data[1:5],point);mask=mle([add(data[81+i],mul(c.U,data[89+i])) for i in range(4)],point)
        # At the first extension this table is replaced by its own reserved
        # pair; the second extension scales both by (1-e1).
        literal=mul(sub(ONE,e1),add(mul(sub(ONE,e0),original),mul(e0,mask)))
        claim=c.rebuilt_claim(self.table,self.arg,3,literal);evaluated=ZERO
        for part in claim['parts']:
            start=part['offset'];words=data[start:start+(1<<part['log_size'])]
            evaluated=add(evaluated,mul(tuple(part['coefficient']),mle(words,[tuple(v) for v in part['point']])))
        self.assertEqual(evaluated,literal)
        self.assertEqual(claim['parts'][1]['offset'],81)
        self.assertEqual(claim['parts'][2]['offset'],89)
    def test_second_extension_uses_its_own_mask_without_earlier_scaling(self):
        self.table['extension_round']=1
        claim=c.rebuilt_claim(self.table,self.arg,3,(11,13))
        self.assertEqual(claim['parts'][1]['coefficient'],[5,6])
        self.assertEqual(claim['parts'][2]['coefficient'],list(mul((5,6),c.U)))
    def test_duplicate_source_coordinate_refuses(self):
        self.table['coordinates']=[{'rho':1},{'flip':1}]
        with self.assertRaisesRegex(AssertionError,'repeated moving'):c.rebuilt_claim(self.table,self.arg,3,(0,0))
    def test_private_functional_cannot_use_extension_challenge(self):
        self.table['coordinates'][0]={'rho':3}
        with self.assertRaises(AssertionError):c.rebuilt_claim(self.table,self.arg,3,(0,0))
    def test_narrow_norm_projection_catches_lost_omitted_bit(self):
        table={'coordinates':[{'rho':i} for i in [0,1,3,4]],'slices':[{'offset':0}],'log_size':4}
        plane=self.profile['physical_planes'][0]
        self.assertEqual(c.split_projection(table,plane,{'main':5},self.profile,norm=True),2)
        table['coordinates'][2]={'rho':2}
        with self.assertRaisesRegex(AssertionError,'omitted feature'):c.split_projection(table,plane,{'main':5},self.profile,norm=True)
    def test_matrix_token_fixed_and_narrow_feature_suffix(self):
        table={'coordinates':[{'fixed':[3,5]},{'fixed':[7,9]},{'rho':1},{'rho':2}],
            'slices':[{'offset':0}],'log_size':4}
        plane=self.profile['physical_planes'][0]
        self.assertEqual(c.split_projection(table,plane,{'main':3},self.profile),2)
        table['coordinates'][0]={'rho':0}
        with self.assertRaisesRegex(AssertionError,'token point'):c.split_projection(table,plane,{'main':3},self.profile)
    def test_private_lift_coefficient_refuses(self):
        self.table.update(log_size=4,slices=[{'offset':0,'coefficient':[5,7]}])
        with self.assertRaisesRegex(AssertionError,'lift/foreign'):c.source_plane(self.profile,self.table)
    def test_H_components_must_name_same_physical_role_and_offset(self):
        plane=copy.deepcopy(self.profile['physical_planes'][0]);plane.update(cm=1,name='H_D0')
        self.profile['physical_planes']=[plane]
        table={'role':'H','log_size':4,'slices':[{'offset':0,'coefficient':[1,0]},{'offset':16,'coefficient':[0,1]}]}
        self.assertEqual(c.source_plane(self.profile,table)['name'],'H_D0')
        table['slices'][1]['offset']+=1
        with self.assertRaisesRegex(AssertionError,'crosses or aliases'):c.source_plane(self.profile,table)
    def test_three_stage_boundary_has_both_outgoing_and_incoming_claim_sites(self):
        run,stages,constants=three_stage_fixture()
        result=c.check_run(run,stages,constants,lambda _:None)
        self.assertEqual(result['published_claims_checked'],27)
        self.assertEqual(result['exclusive_site_pairs_checked'],24)
        self.assertEqual([s['private_tables'] for s in result['stages']],[8,8,8])
    def test_boundary_piece_swap_refuses_even_with_same_single_commitment(self):
        run,stages,constants=three_stage_fixture()
        claims=stages[1]['roles'][2]['claims'];claims[0],claims[1]=claims[1],claims[0]
        with self.assertRaisesRegex(AssertionError,'Tab/terminal-to-claim'):c.check_run(run,stages,constants,lambda _:None)
if __name__=='__main__':unittest.main()
