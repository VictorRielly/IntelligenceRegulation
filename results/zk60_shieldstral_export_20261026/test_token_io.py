from fractions import Fraction
import math
import unittest
import numpy as np
from build_token_io import quantized_rows,embedding_rows,norm_parameters
from shieldstral_geometry import D,Rotation
import calibration_port as P


class TokenTableTests(unittest.TestCase):
    def test_direct_difference_uses_one_int16_rounding_and_zero_rows(self):
        rows=np.array([[0,0,0,0],[-3,-1,1,3]],dtype=np.float64)
        words,scales=quantized_rows(rows,32767)
        self.assertEqual(scales[0],0);np.testing.assert_array_equal(words[0],0)
        for i,value in enumerate((-3,-1,1,3)):
            expected=Fraction(value*32767,3)+Fraction(1,2)
            self.assertEqual(int(words[1,i]),expected.numerator//expected.denominator)
        self.assertEqual(words[1,0],-32767);self.assertEqual(words[1,-1],32767)

    def test_embedding_matches_float32_rotation_boundary_and_refuses_overflow(self):
        values=np.array([[1.,-1.,2.,-2.],[0.,0.,0.,0.]],dtype=np.float32)
        raw=(values.view(np.uint32)>>16).astype(np.uint16);rot=Rotation(4,1,4)
        expected=np.floor(rot.fwd(values).astype(np.float32).astype(np.float64)/.25+.5).astype(np.int16)
        np.testing.assert_array_equal(embedding_rows(raw,rot,.25),expected)
        with self.assertRaises(ValueError):embedding_rows(raw,rot,1e-12)

    def test_classifier_refusal_free_norm_and_exact_ties(self):
        fn=norm_parameters(np.full(D,8.),.001,10)
        self.assertEqual(fn['window_bits'],32)
        rng=np.random.default_rng(10);x=rng.integers(-32768,32768,size=(4,D),dtype=np.int64)
        x[0]=0;x[1]=0;x[1,0]=-32768;x[2]=32767
        rec=P.tc.Rec(1)
        y,_=P.tc.i_norm(x[None],np.full(D,127,dtype=np.int8),1<<10,10,fn['ceps'],32,rec,'final',0,False)
        self.assertLessEqual(int(np.abs(y).max()),127)
        for row in range(len(x)):
            denominator=math.isqrt(fn['ceps']+sum(int(v)**2 for v in x[row]))
            for col in (0,1,D-1):
                expected=Fraction(int(x[row,col])*127,denominator)+Fraction(1,2)
                self.assertEqual(int(y[0,row,col]),expected.numerator//expected.denominator)


if __name__=='__main__':unittest.main()
