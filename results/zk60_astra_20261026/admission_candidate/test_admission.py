"""Admission classification only; the actual shared resource guard is unchanged."""
import unittest
from test_execution import pipeline,ProverError


class AdmissionTests(unittest.TestCase):
    def check(self,jobs):return pipeline.prove_preflight_busy({'live_guarded_jobs':jobs})

    def test_quiet_machine_and_small_light_jobs_allow_guard_admission(self):
        self.assertFalse(self.check([]))
        self.assertFalse(self.check([{'class':'light','need_gib':0.7}]))
        self.assertFalse(self.check([{'class':'light','need_gib':1},{'class':'light','need_gib':0.4}]))

    def test_any_heavy_class_keeps_the_preflight_waiting(self):
        for kind in ('cpu','build','gpu'):
            with self.subTest(kind=kind):self.assertTrue(self.check([{'class':kind,'need_gib':0.5}]))

    def test_light_above_one_gib_keeps_the_preflight_waiting(self):
        for need in (1.01,2.9,3,8):
            with self.subTest(need=need):self.assertTrue(self.check([{'class':'light','need_gib':need}]))

    def test_unknown_or_malformed_job_status_fails_closed(self):
        for status in ({},[],{'live_guarded_jobs':None},{'live_guarded_jobs':[{}]},
                       {'live_guarded_jobs':[{'class':'light','need_gib':True}]},
                       {'live_guarded_jobs':[{'class':'light','need_gib':float('nan')}]},
                       {'live_guarded_jobs':[{'class':'light','need_gib':float('inf')}]},
                       {'live_guarded_jobs':[{'class':'future','need_gib':0.5}]}):
            with self.subTest(status=status),self.assertRaises(ProverError):pipeline.prove_preflight_busy(status)


if __name__=='__main__':unittest.main()
