import unittest
from analyze_verdicts import metric,paired


class FidelityMetricTests(unittest.TestCase):
    def test_weighted_hand_count(self):
        result=metric([True,False,True],[True,True,False],[1,3,2])
        self.assertEqual(result['precision'],.25)
        self.assertEqual(result['recall'],1/3)
        self.assertEqual(result['f1'],2/7)

    def test_refusals_are_visible_in_all_item_and_accepted_metrics(self):
        rows=[];reference={}
        for index,(fm,im,truth,refused) in enumerate([(2.,1.,True,False),(-.1,.2,False,True),(-3.,-2.,False,False)]):
            ident=str(index);reference[ident]={'margin':fm,'n_content_tokens':3,'T':80,'cats':['H'] if truth else []}
            rows.append({'id':ident,'dataset':'openai_mod','template':'cat_hate','weight':1.,'content_tokens':3,'T':80,
                'cats':['H'] if truth else [],'stack_refused':refused,
                'heads':{'refusal_free':{'flagged':im>0,'margin_real':im,'head_refused':False}}})
        result=paired(rows,reference,'refusal_free')
        self.assertFalse(result['zero_refusals']);self.assertEqual(result['refused'],1)
        self.assertEqual(result['diagnostic_all']['agreement'],2/3)
        self.assertEqual(result['accepted_only']['agreement'],1.)
        self.assertEqual(result['accepted_only']['n'],2)
        self.assertEqual(result['margin_within_integer_error'],1)
        self.assertEqual(result['boundary_or_disagreement_items'][0]['id'],'1')
        reference['0']['T']=79
        with self.assertRaises(ValueError):paired(rows,reference,'refusal_free')
        reference['0']['T']=80
        reference['0']['weight']=2.
        with self.assertRaisesRegex(ValueError,'sampling weights'):paired(rows,reference,'refusal_free')


if __name__=='__main__':unittest.main()
