import math
from types import SimpleNamespace
import unittest
import numpy as np
import calibration_port as P


class CalibrationPortTests(unittest.TestCase):
    def test_import_defaults_and_correct_rope(self):
        self.assertEqual(P.b3.norm_K(1024, 9), 512 * math.sqrt(3072) / 1024)
        c, s = P.tc.rope_f32(128)
        from shieldstral_geometry import rope_tables
        np.testing.assert_array_equal(c, rope_tables(128)[0].astype(np.float32))
        np.testing.assert_array_equal(s, rope_tables(128)[1].astype(np.float32))
        for got, want in zip(P.b3.rope_generate(128, 128, 1000000, 7), rope_tables(128, 7)):
            np.testing.assert_array_equal(got, want)

    def test_decoupled_query_axis_and_full_mask_statistics(self):
        # A small independent geometry deliberately has query_width != residual_width.
        g = P.tc.Geo(d=6, f=10, H=4, KV=2, dh=2)
        rng = np.random.default_rng(7)
        x = rng.normal(size=(2, 3, g.d)).astype(np.float32)
        W = {'input_layernorm.weight': np.ones(g.d, np.float32),
             'post_attention_layernorm.weight': np.ones(g.d, np.float32)}
        for name, shape in [('self_attn.q_proj.weight',(8,6)), ('self_attn.k_proj.weight',(4,6)),
                ('self_attn.v_proj.weight',(4,6)), ('self_attn.o_proj.weight',(6,8)),
                ('mlp.gate_proj.weight',(10,6)), ('mlp.up_proj.weight',(10,6)), ('mlp.down_proj.weight',(6,10))]:
            W[name] = rng.normal(scale=.1, size=shape).astype(np.float32)
        # Force a large gate: stats must retain it instead of dropping the sequence.
        W['mlp.gate_proj.weight'] *= 1000
        cos, sin = np.ones((3,1), np.float32), np.zeros((3,1), np.float32)
        st = {}
        got = P.b3.f_block_stats(x,W,cos,sin,st,g)
        want, parts = P.b3._f_block_parts(x,W,cos,sin,g)
        np.testing.assert_array_equal(got,want)
        np.testing.assert_allclose(got,P.tc.f_block(x,W,cos,sin,g=g),rtol=1e-6)
        self.assertEqual(st['rows'],6)
        self.assertEqual(st['excluded_total'],0)
        self.assertGreater(st['gate_absmax_all_sequences'],63.5)
        np.testing.assert_array_equal(st['raw_kv'],np.abs(parts['raw']).transpose(1,0,2,3,4).reshape(2,-1).max(1))
        # A masked-only outlier must affect the bound even though causal softmax ignores it.
        parts['raw'][:,:,:,0,2] = 1000000
        st2 = {}
        P.b3._accumulate(st2,x,want,parts,g)
        self.assertEqual(float(st2['raw_kv'].max()),1000000)
        self.assertLess(st2['raw_causal'],1000000)

    def test_integer_query_output_shape_without_large_weights(self):
        # Exercise the real 3072/4096 shape through rx_block with tiny mocked maps.
        g = P.tc.GEO
        c = dict(norm_cn_a=1,norm_cn_m=1,norm_tn=9,norm_ceps=1,wrho=P.tc.norm_window(g.d,9),
                 f_p=9,f_e=9,f_ro=7,sh_qkv=7,sh_rope=7,sh_s=6,sh_o=9,sh_ao=7,
                 sh_g=7,sh_u=0,sh_h=14,sh_z=6,silu=(-3,-11),e_s=-1)
        class Model:
            mods = frozenset()
            w = {'gamma_a':np.ones(g.d,np.int8),'gamma_m':np.ones(g.d,np.int8)}
            rope_int = (np.full((2,64),128.),np.zeros((2,64)))
            exp_t = P.b3.exp_generate(-1,128).astype(float)
            act_t = P.b3.silu_generate(-3,-11).astype(float)
            lam = 2**-1 / math.sqrt(128)
            def mat(self,name,exact):
                def mm(x):
                    expected = {'o':4096,'d':9216}.get(name,3072)
                    assert x.shape[-1] == expected, (name,x.shape)
                    width = {'q':4096,'k':1024,'v':1024,'g':9216,'u':9216}.get(name,3072)
                    return np.zeros((*x.shape[:-1],width))
                return mm
        m=Model(); m.c=c
        out=P.fl.rx_block(np.ones((1,2,g.d)),m,frozenset(P.fl.SITES))
        self.assertEqual(out.shape,(1,2,3072))
        np.testing.assert_array_equal(out,1)


if __name__ == '__main__': unittest.main()
