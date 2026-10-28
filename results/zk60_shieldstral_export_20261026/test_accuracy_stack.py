from fractions import Fraction
import unittest
import numpy as np
from accuracy_stack import common_shift, group_tables


class AccuracyArithmeticTests(unittest.TestCase):
    def test_group_product_before_rounding_matches_rational(self):
        shifts=np.array([5-delta for delta in range(-4,5)])
        common,coeff=common_shift(shifts)
        for a in (-32767,-19,-1,0,1,19,32767):
            for u in (-32768,-16,-1,1,16,32767):
                for shift,c in zip(shifts,coeff):
                    exact=Fraction(a*u,2**int(shift))+Fraction(1,2)
                    want=exact.numerator//exact.denominator
                    got=(a*u*int(c)+(1<<(common-1)))//(1<<common)
                    self.assertEqual(got,want)
        # Documented noncommuting-rounding counterexample.
        self.assertEqual((1*16*1+32)//64,0)
        self.assertEqual(Fraction((1*16+16)//32,2),Fraction(1,2))

    def test_gate_shift_coefficients_preserve_negative_ties(self):
        shifts=np.array([14,15,17,18,19,20])
        common,coeff=common_shift(shifts)
        for value in (-2**23,-2**17,-1,0,1,2**17,2**23):
            for shift,c in zip(shifts,coeff):
                exact=Fraction(value,2**int(shift))+Fraction(1,2)
                got=(value*int(c)+(1<<(common-1)))//(1<<common)
                self.assertEqual(got,exact.numerator//exact.denominator)
        with self.assertRaises(ValueError):common_shift(np.array([25]))

    def test_table_members_and_int12_rows(self):
        ej=np.array([-5,-4,-1,-5]);eoj=np.array([-13,-12,-9,-13])
        members,ids,tables=group_tables(ej,eoj)
        self.assertEqual(tables.shape,(3,4096))
        self.assertEqual(ids[0],ids[3])
        for channel in range(4):
            for v in (-2048,-127,-1,0,1,127,2047):
                x=v*2.0**(int(ej[channel])-4)
                value=x/(1+np.exp(-x))/2.0**int(eoj[channel])
                want=max(-32767,min(32767,int(np.floor(value+.5))))
                self.assertEqual(int(tables[ids[channel],v+2048]),want)


if __name__=='__main__':unittest.main()
