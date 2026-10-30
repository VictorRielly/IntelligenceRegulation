"""Small exact algebra controls; not a native R14 fixture or privacy result."""
import copy,itertools,unittest
import native_mask_checks as m

def g(coefficients,x,degree):
    # Independent literal polynomial evaluation, without checker weight maps.
    product=m.ONE
    for v in x:product=m.mul(product,v)
    out=m.add(coefficients[0],m.mul(coefficients[1],product))
    for j,v in enumerate(x):
        power=m.ONE
        for e in range(degree):
            power=m.mul(power,v);out=m.add(out,m.mul(coefficients[2+j*degree+e],power))
    return out
def total(coefficients,n,d):
    out=m.ZERO
    for point in itertools.product([m.ZERO,m.ONE],repeat=n):out=m.add(out,g(coefficients,point,d))
    return out
def fixture():
    n,d=3,3;length=n*d+2;kinds=['Private','Standalone','Host'];coef=(17,9)
    masks=[[(i+2*s+1,3*i+s+2) for i in range(length)] for s in range(3)]
    cs=[(s+2,s+3) for s in range(3)];rho=[[(j+s+2,2*j+s+1) for j in range(n)] for s in range(3)]
    gamma=[total(c,n,d) for c in masks];honest=[m.base(11),m.ZERO,m.mul(coef,m.base(11))]
    scalar=[m.add(honest[0],m.mul(cs[0],gamma[0])),m.mul(cs[1],gamma[1]),
        m.sub(m.mul(cs[2],gamma[2]),m.mul(coef,m.mul(cs[0],gamma[0])))]
    args=[];metadata=[]
    for s in range(3):
        rounds=[];constant=m.mul(honest[s],m.base(pow(1<<n,m.P-2,m.P)))
        for j in range(n):
            row=[]
            for x in range(d+1):
                out=m.ZERO
                for rest in itertools.product([m.ZERO,m.ONE],repeat=n-j-1):
                    value=m.add(constant,m.mul(cs[s],g(masks[s],rho[s][:j]+[m.base(x)]+list(rest),d)))
                    out=m.add(out,value)
                row.append(list(out))
            rounds.append(row)
        claimed=scalar[s] if s<2 else m.add(scalar[s],m.mul(coef,scalar[0]))
        mask_eval=g(masks[s],rho[s],d)
        args.append({'slot':s,'main':2,'extension':1,'degree':d,'rho':[list(v) for v in rho[s]],'c':list(cs[s]),
            'kind':kinds[s],'hosted':[] if s<2 else [{'slot':0,'coefficient':list(coef)}],
            'scalar':list(scalar[s]),'claimed_sum':list(claimed),'rounds':rounds,
            'sumcheck_final':list(m.add(constant,m.mul(cs[s],mask_eval))),'mask_eval':list(mask_eval)})
        metadata.append({'slot':s,'main':2,'extension':1,'degree':d,'base':s,'part':'Whole'})
    # Derive linear coefficients by evaluating literal polynomials on a
    # coefficient basis, independently of the checker's closed-form maps.
    weights=[]
    for s in range(3):
        sw=[];ew=[]
        for i in range(length):
            basis=[m.ZERO]*length;basis[i]=m.ONE
            sw.append(total(basis,n,d));ew.append(g(basis,rho[s],d))
        weights.append((sw,ew))
    def f(terms,value):return {'terms':[{'slot':s,'weights':[list(w) for w in wts]} for s,wts in terms],'value':list(value)}
    functionals=[f([(0,weights[0][1])],g(masks[0],rho[0],d)),
        f([(1,[m.mul(c,cs[1]) for c in weights[1][0]])],scalar[1]),
        f([(1,weights[1][1])],g(masks[1],rho[1],d)),
        f([(2,weights[2][1])],g(masks[2],rho[2],d)),
        f([(2,[m.mul(c,cs[2]) for c in weights[2][0]]),
           (0,[m.neg(m.mul(c,m.mul(coef,cs[0]))) for c in weights[0][0]])],scalar[2])]
    stage={'arguments':args,'mask':{'specs':[[n,d]]*3,'rows':10,'q':[list(m.ZERO)]*1024,
        'prox':{'array':'length-only test descriptor','len':1024},'columns':[{}]*256,'functionals':functionals}}
    return stage,{'m_rows':10,'slots':metadata}

class NativeMaskChecks(unittest.TestCase):
    def setUp(self):self.stage,self.profile=fixture()
    def test_literal_mask_polynomials_and_functional_basis_agree(self):
        result=m.check_stage(self.stage,self.profile)
        self.assertEqual((result['slots'],result['functionals'],result['max_CFS_coefficients']),(3,5,11))
    def test_wrong_functional_weight_refuses(self):
        self.stage['mask']['functionals'][0]['terms'][0]['weights'][0][0]+=1
        with self.assertRaisesRegex(AssertionError,'M functional'):m.check_stage(self.stage,self.profile)
    def test_reordered_functionals_refuse(self):
        fs=self.stage['mask']['functionals'];fs[0],fs[1]=fs[1],fs[0]
        with self.assertRaisesRegex(AssertionError,'M functional'):m.check_stage(self.stage,self.profile)
    def test_inconsistent_round_refuses(self):
        self.stage['arguments'][0]['rounds'][1][0][0]+=1
        with self.assertRaisesRegex(AssertionError,'sumcheck consistency'):m.check_stage(self.stage,self.profile)
    def test_zero_challenge_refuses(self):
        self.stage['arguments'][0]['c']=[0,0]
        with self.assertRaisesRegex(AssertionError,'zero CFS'):m.check_stage(self.stage,self.profile)
    def test_terminal_endpoint_challenge_refuses(self):
        self.stage['arguments'][0]['rho'][-1]=[1,0]
        with self.assertRaisesRegex(AssertionError,'terminal challenge'):m.check_stage(self.stage,self.profile)
    def test_message_overflow_refuses(self):
        a=self.stage['arguments'][0];a.update(main=255,extension=1,degree=1)
        self.profile['slots'][0].update(main=255,extension=1,degree=1);self.stage['mask']['specs'][0]=[256,1]
        with self.assertRaisesRegex(AssertionError,'message budget'):m.check_stage(self.stage,self.profile)
    def test_duplicate_hosting_refuses(self):
        self.stage['arguments'][2]['hosted'].append(copy.deepcopy(self.stage['arguments'][2]['hosted'][0]))
        with self.assertRaisesRegex(AssertionError,'masked scalar'):m.check_stage(self.stage,self.profile)
if __name__=='__main__':unittest.main()
