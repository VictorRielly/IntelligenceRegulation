"""Static-width affine Karatsuba within unchanged public-axis row factory."""
from collections import Counter
import coefficients
from axis_factory import AxisPlan

class KaratsubaPlan(AxisPlan):
    def __init__(self,*args,algorithm='karatsuba',**kwargs):
        super().__init__(*args,**kwargs)
        self.algorithm=algorithm
        self.k_work=Counter()

    def begin(self,values,differences):
        assert coefficients.ALGORITHM=='schoolbook'
        coefficients.K_WORK.clear()
        coefficients.ALGORITHM=self.algorithm
        try:
            super().begin(values,differences)
            self.k_work.update(coefficients.K_WORK)
        finally:
            coefficients.ALGORITHM='schoolbook'

