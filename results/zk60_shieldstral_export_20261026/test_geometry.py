import hashlib
from pathlib import Path
import unittest
import numpy as np
import shieldstral_geometry as G

ROOT = Path(__file__).resolve().parents[2]


class GeometryTests(unittest.TestCase):
    def test_yarn_equals_prep_reference_bitwise(self):
        source = ROOT/'results/zk60_shieldstral_prep_20261021/crosscheck/rope_tables_reference.npz'
        ref = np.load(source)
        np.testing.assert_array_equal(G.inverse_frequencies(), ref['inv_freq'])
        cos, sin = G.rope_tables(2048)
        np.testing.assert_array_equal(cos, ref['cos'])
        np.testing.assert_array_equal(sin, ref['sin'])
        for got, key in zip(G.rope_tables(2048, 7), ('cos', 'sin')):
            np.testing.assert_array_equal(got, np.floor(ref[key] * 128 + .5).astype(np.int64))

    def test_rotated_matmuls_and_rms_are_equivalent(self):
        rng = np.random.default_rng(1)
        r = G.Rotation()
        x = rng.normal(size=(3, G.D))
        gamma = rng.normal(size=G.D)
        consumer = rng.normal(size=(17, G.D))
        writer = rng.normal(size=(G.D, 17))
        rotated = r.fwd(x)
        np.testing.assert_allclose(r.inv(rotated), x, rtol=1e-12, atol=1e-12)
        np.testing.assert_allclose((rotated**2).sum(-1), (x**2).sum(-1), rtol=1e-12)
        # Fold norm gamma into the consumers, preserving both consumer and writer maps.
        np.testing.assert_allclose(rotated @ r.fwd(consumer * gamma).T,
                                   (x * gamma) @ consumer.T, rtol=1e-11, atol=1e-11)
        h = rng.normal(size=(3, 17))
        np.testing.assert_allclose(h @ r.fwd(writer.T), r.fwd(h @ writer.T), rtol=1e-11, atol=1e-11)
        self.assertEqual(r.metadata()['sign_sha256'], hashlib.sha256(r.sign.astype('<f8').tobytes()).hexdigest())

    def test_query_axis_and_native_model_fields(self):
        self.assertEqual((G.D, G.QUERY_WIDTH, G.KV_HEADS * G.HEAD_DIM), (3072, 4096, 1024))
        for t in (128, 256):
            fields = G.profile_model_fields(t)
            self.assertEqual(fields['geometry'], f'shieldstral-3b-t{t}')
            self.assertEqual(fields['tied_embeddings']['sha256'], G.tied_source()['sha256'])
            self.assertEqual(fields['rope_scaling']['mscale'], 1.0)
            self.assertEqual(fields['rope_scaling']['mscale_all_dim'], 1.0)
        with self.assertRaises(ValueError): G.profile_model_fields(512)
        with self.assertRaises(ValueError): G.rope_tables(16385)
        with self.assertRaises(ValueError): G.Rotation(n=3072, block=2048)


if __name__ == '__main__': unittest.main()
