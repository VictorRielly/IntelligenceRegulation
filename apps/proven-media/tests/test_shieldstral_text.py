import copy
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from proven_media.classifier_cli import chunk_plan
from proven_media import prompting
from proven_media.prompting import ContentRefused
from proven_media.shieldstral_text import CategoryTemplate, ShieldstralTextEncoder, category_plans, check_category_coverage


class CategoryPlans(unittest.TestCase):
    def setUp(self):
        # Exact A1 public lengths at T128, with synthetic public words here.
        self.sexual = CategoryTemplate('sexual', 'test-sexual', (1,) + (1001,) * 72, (4,), 128, 8, 20)
        self.violence = replace(self.sexual, category='violence', policy_id='test-violence')
        self.hate = replace(self.sexual, category='hate', policy_id='test-hate', prefix=(1,) + (1001,) * 78)
        self.templates = (self.sexual, self.violence, self.hate)

    def test_categories_need_different_plans(self):
        plans = category_plans(54, self.templates)
        self.assertEqual(plans['sexual'], [{'index': 0, 'start': 0, 'end': 54}])
        self.assertEqual(plans['hate'], [{'index': 0, 'start': 0, 'end': 48},
                                        {'index': 1, 'start': 6, 'end': 54}])
        content = tuple(range(1000, 1054))
        self.assertEqual(self.hate.prompt_ids(content, plans['hate'][1]),
                         self.hate.prefix + content[6:54] + self.hate.suffix)

    def test_native_tail_and_all_tokens_covered(self):
        for template in self.templates:
            for n in (1, 11, 47, 48, 53, 54, 55, 99, 100, 168, 424, 455):
                plan = template.plan(n)
                self.assertEqual([(c['start'], c['end']) for c in plan],
                                 chunk_plan(n, template.chunk_size, template.overlap, allow_short=True))
                covered = {i for c in plan for i in range(c['start'], c['end'])}
                self.assertEqual(covered, set(range(n)))

    def test_empty_invalid_or_excessive_posts_refuse(self):
        for n in (0, -1, True, 10**12):
            with self.subTest(n=n), self.assertRaises(ContentRefused):
                category_plans(n, self.templates)

    def test_short_prompt_ends_with_public_pads_after_the_suffix(self):
        content = (1001,) * 11
        for template in self.templates:
            plan = template.plan(11)
            self.assertEqual(plan, [{'index': 0, 'start': 0, 'end': 11}])
            prompt = template.prompt_ids(content, plan[0])
            stop = len(template.prefix) + 11
            self.assertEqual(len(prompt), 128)
            self.assertEqual(prompt[:stop], template.prefix + content)
            self.assertEqual(prompt[stop], 4)
            self.assertEqual(prompt[stop + 1:], (11,) * (127 - stop))

    def statements(self, total):
        result = {}
        for template in self.templates:
            plan = template.plan(total)
            result[template.category] = []
            for chunk in plan:
                n = chunk['end'] - chunk['start']
                length = len(template.prefix) + n + 1
                result[template.category].append({
                    'schema': 'zk60-classify-run/3', 'policy': template.policy_id,
                    'content_length_n': n, 'template_prefix_ids': list(template.prefix),
                    'template_suffix_ids': [4], 'T': 128, 'item_length': length,
                    'pad_id': 11, 'pad_positions': 128 - length, 'verdict_row': length - 1,
                    'chunk': {'index': chunk['index'], 'count': len(plan), 'content_total': total,
                              'chunk_size': template.chunk_size, 'overlap': template.overlap,
                              'range': [chunk['start'], chunk['end']]}})
        return result

    def test_whole_post_count_is_from_the_encoder_not_the_receipts(self):
        encoder = object.__new__(ShieldstralTextEncoder)
        for total in (12, 54, 100):
            with patch.object(ShieldstralTextEncoder, 'content_ids', return_value=(1001,) * total) as encode:
                self.assertEqual(check_category_coverage('the entire post', encoder, self.templates,
                                                        self.statements(total)), total)
                encode.assert_called_once_with('the entire post')
                for prefix in (1, 11, total - 1):
                    with self.subTest(total=total, prefix=prefix), self.assertRaises(ContentRefused):
                        check_category_coverage('the entire post', encoder, self.templates, self.statements(prefix))

    def test_every_category_and_exact_ranges_are_required(self):
        encoder = object.__new__(ShieldstralTextEncoder)
        rows = self.statements(100)
        mutations = []
        bad = copy.deepcopy(rows); del bad['hate']; mutations.append(bad)
        bad = copy.deepcopy(rows); bad['hate'].pop(); mutations.append(bad)
        bad = copy.deepcopy(rows); bad['hate'][1] = bad['hate'][0]; mutations.append(bad)
        bad = copy.deepcopy(rows); bad['hate'][0]['chunk']['range'][1] -= 1; mutations.append(bad)
        bad = copy.deepcopy(rows); bad['hate'][0]['pad_id'] = 2; mutations.append(bad)
        bad = copy.deepcopy(rows); bad['hate'][0]['policy'] = 'test-sexual'; mutations.append(bad)
        with patch.object(ShieldstralTextEncoder, 'content_ids', return_value=(1001,) * 100):
            for bad in mutations:
                with self.assertRaises(ContentRefused):
                    check_category_coverage('entire post', encoder, self.templates, bad)

    def test_missing_duplicate_or_reused_policy_refuses(self):
        for templates in (self.templates[:2], (self.sexual, self.sexual, self.hate),
                          (self.sexual, self.violence, replace(self.hate, policy_id='test-sexual'))):
            with self.assertRaises(ContentRefused):
                category_plans(100, templates)

    def test_wrong_category_range_and_control_id_refuse(self):
        content = (1001,) * 54
        with self.assertRaises(ContentRefused):
            self.hate.prompt_ids(content, self.sexual.plan(54)[0])
        with self.assertRaises(ContentRefused):
            self.sexual.prompt_ids((1,) + content[1:], self.sexual.plan(54)[0])

    def test_invalid_geometry_refuses(self):
        for values in ({'overlap': 54}, {'overlap': -1}, {'max_chunks': 0},
                       {'context_tokens': 32}, {'suffix': (4, 2)}, {'prefix': (True, 1000)}):
            with self.subTest(values=values), self.assertRaises(ContentRefused):
                replace(self.sexual, **values)

    def test_tokenizer_pin_checked_before_optional_import(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'tekken.json'
            path.write_text('{}')
            with self.assertRaises(ContentRefused):
                ShieldstralTextEncoder(path)

    def test_real_prompt_route_requires_matching_category_and_native_range(self):
        encoder = object.__new__(ShieldstralTextEncoder)
        ids = tuple(range(1000, 1054))
        with patch.object(ShieldstralTextEncoder, 'content_ids', return_value=ids):
            options = {'shieldstral_encoder': encoder, 'shieldstral_template': self.hate}
            enc = prompting.build_prompt('shieldstral', 'fixture', 'hate', 6, 54, **options)
            self.assertEqual(enc.ids, list(self.hate.prefix + ids[6:] + self.hate.suffix))
            self.assertEqual(prompting.content_length('shieldstral', 'fixture', shieldstral_encoder=encoder), 54)
            self.assertEqual(len(prompting.plan_shieldstral('fixture', encoder, self.templates)['hate']), 2)
            for category, start, end in (('sexual', 6, 54), ('hate', 0, 54), ('hate', None, None)):
                with self.assertRaises(ContentRefused):
                    prompting.build_prompt('shieldstral', 'fixture', category, start, end, **options)

    def test_real_routes_never_fall_back_to_stub_tokenization(self):
        with self.assertRaises(ContentRefused):
            prompting.plan_for('shieldstral', 'hello')
        with self.assertRaises(ContentRefused):
            prompting.content_length('shieldstral', 'hello')


if __name__ == '__main__':
    unittest.main()
