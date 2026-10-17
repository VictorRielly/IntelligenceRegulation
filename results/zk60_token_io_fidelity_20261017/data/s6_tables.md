## F1 constants

* final norm: g0 127, tn 10, Ceps 74429, window 32 bits, Cn configs {'cal_m1.50': 5664, 'diag_m1.00': 8497, 'diag_m1.25': 6797, 'diag_safe': 1024}
* calibration |xhat'| max 5.4537; y reaches 127 at |xhat'| = cal_m1.50 8.182, diag_m1.00 5.454, diag_m1.25 6.818, diag_safe 45.255
* head: {"d": 2048, "form": "W' = lm_head diag(norm_weight) R^T (rotated basis), int8, raw int32 logits, no requant", "per_row": {"clipped": 0, "minus128": 0, "s_w_max": 0.002675615738196207, "s_w_min": 0.0006707074581383189, "s_w_ratio_max_min": 3.989244052277139, "sha256_int8_row_major": "b99cbec5f457e47ca2441de517135ba1bd1870e2ae8abe2038dbd84617436280", "sha256_scales_f64": "5eb2b350e384749b9f7ab976e1f5027a4793e6a5a75515af9577e43ad5ea1b1c"}, "per_tensor": {"absmax_int": 127, "clipped": 0, "minus128": 0, "row_absmax_levels_quantiles": {"0.0": 31.83560552719403, "0.01": 44.07710252814844, "0.5": 62.01999579816392, "0.99": 89.8667181540533, "1.0": 127.0}, "s_w": 0.002675615738196207, "sha256_int8_row_major": "0f40a48d91a99df7d5118e1bc344b831b47c06da7b5e20877fbd84f2d986dd95"}, "vocab": 32000}
* fold check: {'logit_absmax': 31.263883590698242, 'max_abs_logit_diff': 1.5578259297654995e-05, 'positions': 512, 'top1_agreement': 1.0}
* selftests: {'final_norm_equals_i_norm': True, 'forced_tie_rows': 800, 'honest_delta_positive_off_argmax': True, 'keyed_argmax_equals_numpy_first_max': True, 'random_vectors': 800}

## T128

| set | positions | float head vs float model | cfg | refused | int pt vs float head | int pr exact vs float head | int pt vs float model | ties | KL pt | KL pr |
|---|---:|---|---|---:|---|---|---|---:|---:|---:|
| all | 9216 | 73.51 % (6775/9216) | cal_m1.50 | 0 | 98.50 % (9078/9216) | 99.00 % (9124/9216) | 73.57 % (6780/9216) | 0 | 0.00068 | 0.00038 |
| all | 9216 | 73.51 % (6775/9216) | diag_m1.00 | 0 | 98.67 % (9093/9216) | 99.12 % (9135/9216) | 73.58 % (6781/9216) | 0 | 0.00051 | 0.00021 |
| all | 9216 | 73.51 % (6775/9216) | diag_m1.25 | 0 | 98.40 % (9069/9216) | 99.07 % (9130/9216) | 73.49 % (6773/9216) | 0 | 0.00058 | 0.00028 |
| all | 9216 | 73.51 % (6775/9216) | diag_safe | 0 | 93.80 % (8645/9216) | 93.93 % (8657/9216) | 72.70 % (6700/9216) | 5 | 0.00972 | 0.00943 |
| domain:fineweb-edu | 4608 | 74.50 % (3433/4608) | cal_m1.50 | 0 | 98.46 % (4537/4608) | 98.76 % (4551/4608) | 74.70 % (3442/4608) | 0 | 0.00073 | 0.00040 |
| domain:fineweb-edu | 4608 | 74.50 % (3433/4608) | diag_m1.00 | 0 | 98.48 % (4538/4608) | 98.91 % (4558/4608) | 74.61 % (3438/4608) | 0 | 0.00054 | 0.00022 |
| domain:fineweb-edu | 4608 | 74.50 % (3433/4608) | diag_m1.25 | 0 | 98.20 % (4525/4608) | 98.85 % (4555/4608) | 74.41 % (3429/4608) | 0 | 0.00062 | 0.00030 |
| domain:fineweb-edu | 4608 | 74.50 % (3433/4608) | diag_safe | 0 | 93.73 % (4319/4608) | 93.82 % (4323/4608) | 73.55 % (3389/4608) | 4 | 0.01029 | 0.00998 |
| domain:licence-docstring | 4608 | 72.53 % (3342/4608) | cal_m1.50 | 0 | 98.55 % (4541/4608) | 99.24 % (4573/4608) | 72.44 % (3338/4608) | 0 | 0.00064 | 0.00035 |
| domain:licence-docstring | 4608 | 72.53 % (3342/4608) | diag_m1.00 | 0 | 98.85 % (4555/4608) | 99.33 % (4577/4608) | 72.55 % (3343/4608) | 0 | 0.00047 | 0.00019 |
| domain:licence-docstring | 4608 | 72.53 % (3342/4608) | diag_m1.25 | 0 | 98.61 % (4544/4608) | 99.28 % (4575/4608) | 72.57 % (3344/4608) | 0 | 0.00055 | 0.00027 |
| domain:licence-docstring | 4608 | 72.53 % (3342/4608) | diag_safe | 0 | 93.88 % (4326/4608) | 94.05 % (4334/4608) | 71.85 % (3311/4608) | 1 | 0.00915 | 0.00888 |
| last_position | 72 | 81.94 % (59/72) | cal_m1.50 | 0 | 98.61 % (71/72) | 98.61 % (71/72) | 83.33 % (60/72) | 0 | 0.00056 | 0.00032 |
| last_position | 72 | 81.94 % (59/72) | diag_m1.00 | 0 | 98.61 % (71/72) | 98.61 % (71/72) | 83.33 % (60/72) | 0 | 0.00043 | 0.00018 |
| last_position | 72 | 81.94 % (59/72) | diag_m1.25 | 0 | 100.00 % (72/72) | 100.00 % (72/72) | 81.94 % (59/72) | 0 | 0.00051 | 0.00025 |
| last_position | 72 | 81.94 % (59/72) | diag_safe | 0 | 95.83 % (69/72) | 95.83 % (69/72) | 80.56 % (58/72) | 0 | 0.00873 | 0.00857 |

per-row integer multipliers (cal cfg, all positions): b=12: 99.00 % (9124/9216), b=16: 98.99 % (9123/9216), b=4: 79.42 % (7319/9216), b=8: 98.24 % (9054/9216)

details (cal cfg):
```
{
 "bound_d_127sq": 33032192,
 "disagreement_by_float_head_margin": {
  "[0.0,0.01)": {
   "disagree": 19,
   "positions": 57
  },
  "[0.01,0.03)": {
   "disagree": 43,
   "positions": 112
  },
  "[0.03,0.1)": {
   "disagree": 68,
   "positions": 423
  },
  "[0.1,0.3)": {
   "disagree": 8,
   "positions": 1042
  },
  "[0.3,1.0)": {
   "disagree": 0,
   "positions": 2609
  },
  "[1.0,3.0)": {
   "disagree": 0,
   "positions": 3141
  },
  "[3.0,1000000000.0)": {
   "disagree": 0,
   "positions": 1832
  }
 },
 "disagreement_float_rank_hist": {
  "1": 134,
  "2": 2,
  "4": 2
 },
 "disagreement_float_regret_quantiles": {
  "0.5": 0.03369712829589844,
  "0.9": 0.08199510574340821,
  "1.0": 0.14980697631835938
 },
 "disagreements": 138,
 "float_head_margin_quantiles": {
  "0.01": 0.015982627868652347,
  "0.05": 0.07688355445861816,
  "0.5": 1.1196188926696777
 },
 "int_margin_float_units_per_lsb": 0.00017237001086381598,
 "int_margin_hist_l1_minus_l2": {
  "[0,1)": 0,
  "[1,2)": 1,
  "[1024,4096)": 2327,
  "[16,64)": 45,
  "[2,4)": 1,
  "[256,1024)": 735,
  "[4,16)": 15,
  "[4096,4611686018427387904)": 5904,
  "[64,256)": 188
 },
 "keyed_delta_bits_needed": 33,
 "keyed_delta_fits_window": true,
 "keyed_delta_max": 8338427102,
 "keyed_delta_min_over_i_ne_j": 30884,
 "keyed_delta_window_bits_design": 41,
 "max_abs_logit": 181485,
 "max_abs_logit_bits": 17.469490786735552,
 "per_row_multiplier_delta_bits": {
  "4": 38,
  "8": 41,
  "12": 45,
  "16": 49
 },
 "per_row_multiplier_delta_min_over_i_ne_j": {
  "4": 161742,
  "8": 3699554,
  "12": 326434842,
  "16": 545488922
 },
 "per_row_multiplier_tie_positions": {
  "4": 0,
  "8": 0,
  "12": 0,
  "16": 0
 },
 "tie_positions": 0,
 "tie_positions_decided_by_lowest_index": 0
}
```

## T32

| set | positions | float head vs float model | cfg | refused | int pt vs float head | int pr exact vs float head | int pt vs float model | ties | KL pt | KL pr |
|---|---:|---|---|---:|---|---|---|---:|---:|---:|
| all | 2304 | 68.92 % (1588/2304) | cal_m1.50 | 0 | 98.26 % (2264/2304) | 98.52 % (2270/2304) | 68.32 % (1574/2304) | 0 | 0.00078 | 0.00045 |
| all | 2304 | 68.92 % (1588/2304) | diag_m1.00 | 0 | 98.57 % (2271/2304) | 99.00 % (2281/2304) | 68.62 % (1581/2304) | 0 | 0.00057 | 0.00024 |
| all | 2304 | 68.92 % (1588/2304) | diag_m1.25 | 0 | 98.44 % (2268/2304) | 98.91 % (2279/2304) | 68.36 % (1575/2304) | 1 | 0.00066 | 0.00033 |
| all | 2304 | 68.92 % (1588/2304) | diag_safe | 0 | 93.06 % (2144/2304) | 92.88 % (2140/2304) | 67.66 % (1559/2304) | 2 | 0.01127 | 0.01093 |
| domain:fineweb-edu | 1152 | 69.36 % (799/1152) | cal_m1.50 | 0 | 98.52 % (1135/1152) | 98.52 % (1135/1152) | 69.36 % (799/1152) | 0 | 0.00081 | 0.00046 |
| domain:fineweb-edu | 1152 | 69.36 % (799/1152) | diag_m1.00 | 0 | 98.35 % (1133/1152) | 98.52 % (1135/1152) | 69.36 % (799/1152) | 0 | 0.00059 | 0.00025 |
| domain:fineweb-edu | 1152 | 69.36 % (799/1152) | diag_m1.25 | 0 | 98.18 % (1131/1152) | 98.70 % (1137/1152) | 69.10 % (796/1152) | 0 | 0.00068 | 0.00035 |
| domain:fineweb-edu | 1152 | 69.36 % (799/1152) | diag_safe | 0 | 92.80 % (1069/1152) | 92.53 % (1066/1152) | 68.58 % (790/1152) | 2 | 0.01191 | 0.01155 |
| domain:licence-docstring | 1152 | 68.49 % (789/1152) | cal_m1.50 | 0 | 98.00 % (1129/1152) | 98.52 % (1135/1152) | 67.27 % (775/1152) | 0 | 0.00074 | 0.00043 |
| domain:licence-docstring | 1152 | 68.49 % (789/1152) | diag_m1.00 | 0 | 98.78 % (1138/1152) | 99.48 % (1146/1152) | 67.88 % (782/1152) | 0 | 0.00055 | 0.00023 |
| domain:licence-docstring | 1152 | 68.49 % (789/1152) | diag_m1.25 | 0 | 98.70 % (1137/1152) | 99.13 % (1142/1152) | 67.62 % (779/1152) | 1 | 0.00064 | 0.00032 |
| domain:licence-docstring | 1152 | 68.49 % (789/1152) | diag_safe | 0 | 93.32 % (1075/1152) | 93.23 % (1074/1152) | 66.75 % (769/1152) | 0 | 0.01062 | 0.01031 |
| last_position | 72 | 80.56 % (58/72) | cal_m1.50 | 0 | 100.00 % (72/72) | 97.22 % (70/72) | 80.56 % (58/72) | 0 | 0.00058 | 0.00032 |
| last_position | 72 | 80.56 % (58/72) | diag_m1.00 | 0 | 97.22 % (70/72) | 98.61 % (71/72) | 80.56 % (58/72) | 0 | 0.00045 | 0.00017 |
| last_position | 72 | 80.56 % (58/72) | diag_m1.25 | 0 | 97.22 % (70/72) | 97.22 % (70/72) | 80.56 % (58/72) | 1 | 0.00055 | 0.00025 |
| last_position | 72 | 80.56 % (58/72) | diag_safe | 0 | 97.22 % (70/72) | 97.22 % (70/72) | 77.78 % (56/72) | 0 | 0.00797 | 0.00784 |

per-row integer multipliers (cal cfg, all positions): b=12: 98.39 % (2267/2304), b=16: 98.48 % (2269/2304), b=4: 77.30 % (1781/2304), b=8: 98.00 % (2258/2304)

details (cal cfg):
```
{
 "bound_d_127sq": 33032192,
 "disagreement_by_float_head_margin": {
  "[0.0,0.01)": {
   "disagree": 8,
   "positions": 21
  },
  "[0.01,0.03)": {
   "disagree": 9,
   "positions": 33
  },
  "[0.03,0.1)": {
   "disagree": 21,
   "positions": 111
  },
  "[0.1,0.3)": {
   "disagree": 2,
   "positions": 313
  },
  "[0.3,1.0)": {
   "disagree": 0,
   "positions": 749
  },
  "[1.0,3.0)": {
   "disagree": 0,
   "positions": 727
  },
  "[3.0,1000000000.0)": {
   "disagree": 0,
   "positions": 350
  }
 },
 "disagreement_float_rank_hist": {
  "1": 38,
  "2": 2
 },
 "disagreement_float_regret_quantiles": {
  "0.5": 0.04052019119262695,
  "0.9": 0.07871294021606448,
  "1.0": 0.17594623565673828
 },
 "disagreements": 40,
 "float_head_margin_quantiles": {
  "0.01": 0.011855268478393556,
  "0.05": 0.06894054412841798,
  "0.5": 0.909243106842041
 },
 "int_margin_float_units_per_lsb": 0.00017237001086381598,
 "int_margin_hist_l1_minus_l2": {
  "[0,1)": 0,
  "[1,2)": 1,
  "[1024,4096)": 706,
  "[16,64)": 18,
  "[2,4)": 2,
  "[256,1024)": 206,
  "[4,16)": 2,
  "[4096,4611686018427387904)": 1305,
  "[64,256)": 64
 },
 "keyed_delta_bits_needed": 33,
 "keyed_delta_fits_window": true,
 "keyed_delta_max": 7697003650,
 "keyed_delta_min_over_i_ne_j": 33435,
 "keyed_delta_window_bits_design": 41,
 "max_abs_logit": 154459,
 "max_abs_logit_bits": 17.236864410647282,
 "per_row_multiplier_delta_bits": {
  "4": 37,
  "8": 41,
  "12": 45,
  "16": 49
 },
 "per_row_multiplier_delta_min_over_i_ne_j": {
  "4": 1572854,
  "8": 65925870,
  "12": 326434842,
  "16": 545488922
 },
 "per_row_multiplier_tie_positions": {
  "4": 0,
  "8": 0,
  "12": 0,
  "16": 0
 },
 "tie_positions": 0,
 "tie_positions_decided_by_lowest_index": 0
}
```

## pooled

```
{
 "cal_m1.50": {
  "int_pr_exact_vs_float_head": {
   "agree": 11394,
   "n": 11520,
   "rate": 0.9890625
  },
  "int_pr_m12_vs_float_head": {
   "agree": 11391,
   "n": 11520,
   "rate": 0.9888020833333333
  },
  "int_pr_m16_vs_float_head": {
   "agree": 11392,
   "n": 11520,
   "rate": 0.9888888888888889
  },
  "int_pr_m4_vs_float_head": {
   "agree": 9100,
   "n": 11520,
   "rate": 0.7899305555555556
  },
  "int_pr_m8_vs_float_head": {
   "agree": 11312,
   "n": 11520,
   "rate": 0.9819444444444444
  },
  "int_pt_vs_float_head": {
   "agree": 11342,
   "n": 11520,
   "rate": 0.9845486111111111
  },
  "refused_positions": 0
 },
 "diag_m1.00": {
  "int_pr_exact_vs_float_head": {
   "agree": 11416,
   "n": 11520,
   "rate": 0.9909722222222223
  },
  "int_pt_vs_float_head": {
   "agree": 11364,
   "n": 11520,
   "rate": 0.9864583333333333
  },
  "refused_positions": 0
 },
 "diag_m1.25": {
  "int_pr_exact_vs_float_head": {
   "agree": 11409,
   "n": 11520,
   "rate": 0.9903645833333333
  },
  "int_pt_vs_float_head": {
   "agree": 11337,
   "n": 11520,
   "rate": 0.9841145833333333
  },
  "refused_positions": 0
 },
 "diag_safe": {
  "int_pr_exact_vs_float_head": {
   "agree": 10797,
   "n": 11520,
   "rate": 0.9372395833333333
  },
  "int_pt_vs_float_head": {
   "agree": 10789,
   "n": 11520,
   "rate": 0.9365451388888889
  },
  "refused_positions": 0
 }
}
```
