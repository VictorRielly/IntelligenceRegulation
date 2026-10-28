import unittest
import numpy as np
import calibration_port as P
from signed_word_domain import AMENDED_SITES,S2RecPos

class SignedWordDomainTests(unittest.TestCase):
    def test_all_eight_sites_admit_only_one_additional_endpoint(self):
        values=np.array([[[-32769,-32768,-32767,0,32767,32768]]],dtype=np.float64)
        for site in AMENDED_SITES:
            rec=S2RecPos(1);out=P.fl._chk(rec,site,values,-32767,32767,0,True)
            np.testing.assert_array_equal(out,[[[-32768,-32768,-32767,0,32767,32767]]])
            self.assertEqual(rec.sites[site]['violations'],2)

    def test_norm_division_lands_exactly_on_new_endpoint(self):
        # D=isqrt(32768^2+1)=32768. -32768*256*256/(D*2)=-32768.
        x=np.array([[[-32768.]]]);gamma=np.array([1],dtype=np.int8)
        amended=S2RecPos(1)
        out=P.fl.rx_norm(x,gamma,256,1,1,24,True,True,amended,'norm_a',0,8)
        self.assertEqual(out.item(),-32768);self.assertIsNone(amended.first[0])
        old=P.fl.RecPos(1)
        original=P.fl.rx_norm(x,gamma,256,1,1,24,True,True,old,'norm_a',0,8)
        self.assertEqual(original.item(),-32767);self.assertIsNotNone(old.first[0])

    def test_score_int8_and_other_sites_keep_their_original_domains(self):
        for site,lo,hi,value in (('score',-127,127,-128),('Q',-127,127,-128),
                                ('unrelated',-32767,32767,-32768)):
            rec=S2RecPos(1);out=P.fl._chk(rec,site,np.array([[[value]]]),lo,hi,0,True)
            self.assertIsNotNone(rec.first[0]);self.assertEqual(out.item(),lo)

if __name__=='__main__':unittest.main()
