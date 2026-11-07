"""D58 display scope controls; these do not execute a native prover."""
from copy import deepcopy
import unittest
from unittest.mock import patch

import test_app  # configure isolated storage before app imports
from proven_media import classifier_privacy as privacy
from proven_media import provers, shieldstral_runtime as runtime
from proven_media.shieldstral_prover import ShieldstralProver


def description(cls=ShieldstralProver):
    obj = object.__new__(cls)
    obj.templates = runtime.templates()
    return obj.describe()


class PrivacyScopeTests(unittest.TestCase):
    def test_current_cpu_adapter_reports_existing_acceptance_and_conditions(self):
        p = description()
        self.assertEqual(p['privacy_status'], 'CPU privacy statement accepted')
        self.assertEqual(p['privacy_statement']['decision'], 'D58')
        self.assertTrue(p['privacy_statement']['accepted'])
        self.assertFalse(p['privacy_statement']['permits_non_public_posts'])
        self.assertIn('public weights', p['privacy_statement']['scope'])
        self.assertIn('moderate', p['policy_selection'])
        self.assertNotIn('pending', p['policy_selection'])

    def test_binary_profile_identity_and_proving_path_are_independently_bound(self):
        good = description()
        changes = [{'binary_sha256': '00' * 32}, {'token_profile_digest': '00' * 32},
            {'model_digest': '00' * 32}, {'run_profile': 'other'}, {'cli': 'new build'},
            {'device': 'metal'}, {'device': 'cuda'}, {'proof_mode': 'prove-batch'},
            {'batch_proving': True}, {'batch_proving': 'false'},
            {'prover_binary_sha256': '11' * 32}, {'privacy_adapter_supported': False},
            {'policy_ids': ['shieldstral-1.0-3b-card-unsafe/1']},
            {'policy_ids': [good['policy_ids'][0]] * 3}]
        for delta in changes:
            with self.subTest(delta=delta):
                info = privacy.statement_info({**good, **delta})
                self.assertFalse(info['accepted'])
                self.assertEqual(info['status'], 'privacy statement pending')

    def test_rebuilt_runtime_pin_does_not_inherit_the_old_acceptance(self):
        with patch.object(runtime, 'BINARY_SHA', '00' * 32):
            self.assertFalse(description()['privacy_statement']['accepted'])
            self.assertFalse(runtime.privacy_statement()['accepted'])

    def test_new_profile_does_not_inherit_the_old_acceptance(self):
        with patch.object(runtime, 'PROFILE_SHA', '603b4b9cca34c20410b7529b96717f1ea90f6709cca1c1b491a853fafefd485e'):
            self.assertFalse(description()['privacy_statement']['accepted'])

    def test_description_uses_its_actual_policy_list(self):
        obj = object.__new__(ShieldstralProver)
        obj.templates = (runtime.templates()[0],) * 3
        self.assertFalse(obj.describe()['privacy_statement']['accepted'])

    def test_batch_and_other_subclasses_stay_pending_after_super_describe(self):
        class Batch(ShieldstralProver):
            batch_proving = True
            def describe(self):
                return {**super().describe(), 'prover_binary_sha256': 'aa' * 32,
                        'cli': 'candidate r18 prove-batch; reviewed r16b fresh verification'}
        class FutureGPU(ShieldstralProver):
            pass
        for cls in (Batch, FutureGPU):
            with self.subTest(adapter=cls.__name__):
                p = description(cls)
                self.assertFalse(p['privacy_statement']['accepted'])
                self.assertFalse(privacy.statement_info(p)['accepted'])
                self.assertFalse(provers.verify_instructions({'prover': p})['privacy_statement']['accepted'])

    def test_named_r17_descriptor_is_covered_but_not_selected_by_runtime(self):
        p = description()
        p.update(binary_sha256='81bd86248e9f42393c9fe739e6794b7af155ad9a0a06874c89efb7a7bba18317',
                 cli='zk60_classify r17, native R13, T128')
        self.assertTrue(privacy.statement_info(p)['accepted'])
        self.assertEqual(runtime.BINARY.name, 'zk60_classify.r16b.release.bin')

    def test_historical_record_is_annotated_without_mutation(self):
        p = description()
        for key in ('device', 'proof_mode', 'batch_proving', 'privacy_adapter_supported',
                    'policy_ids', 'privacy_statement'):
            p.pop(key)
        p['privacy_status'] = 'privacy statement pending'
        record = {'prover': p, 'statement': {'policy': 'shieldstral-1.0-3b-moderate-hate/1'}}
        before = deepcopy(record)
        instructions = provers.verify_instructions(record)
        self.assertTrue(instructions['privacy_statement']['accepted'])
        self.assertEqual(record, before)
        self.assertEqual(record['prover']['privacy_status'], 'privacy statement pending')

    def test_missing_or_malformed_descriptor_cannot_self_assert_acceptance(self):
        for value in (None, [], {}, {'privacy_status': 'CPU privacy statement accepted'},
                      {'binary_sha256': []}, {'policy_ids': [{}]}):
            with self.subTest(value=value):
                self.assertFalse(privacy.statement_info(value)['accepted'])


if __name__ == '__main__':
    unittest.main()
