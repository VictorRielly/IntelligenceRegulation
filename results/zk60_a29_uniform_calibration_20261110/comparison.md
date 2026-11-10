| Group | Head | Refused (cur / L12 / uni) | Weighted agreement, accepted rows (cur / L12 / uni) | Float F1 | Integer F1 (cur / L12 / uni) | Paired cur vs uni: common rows, decision changes |
|---|---|---:|---:|---:|---:|---:|
| openai_mod/cat_hate | refusal_free | 2 / 0 / 0 | 0.9769 / 0.9827 / 0.9811 | 0.5727 | 0.5805 / 0.5794 / 0.5733 | 610, 3 |
| openai_mod/cat_hate | calibrated | 2 / 0 / 0 | 0.9909 / 0.9934 / 0.9959 | 0.5727 | 0.5761 / 0.5759 / 0.5722 | 610, 2 |
| openai_mod/cat_sexual | refusal_free | 0 / 0 / 0 | 0.9884 / 0.9884 / 0.9884 | 0.7402 | 0.7864 / 0.7887 / 0.7864 | 612, 0 |
| openai_mod/cat_sexual | calibrated | 0 / 0 / 0 | 0.9942 / 0.9942 / 0.9967 | 0.7402 | 0.7365 / 0.7365 / 0.7479 | 612, 1 |
| openai_mod/cat_violence | refusal_free | 0 / 0 / 0 | 0.9943 / 0.9951 / 0.9943 | 0.6718 | 0.6399 / 0.6480 / 0.6519 | 612, 2 |
| openai_mod/cat_violence | calibrated | 0 / 0 / 0 | 0.9968 / 0.9968 / 0.9968 | 0.6718 | 0.6641 / 0.6641 / 0.6641 | 612, 0 |
| openai_mod/mod_hate | refusal_free | 2 / 0 / 0 | 0.9760 / 0.9752 / 0.9753 | 0.5614 | 0.5651 / 0.5768 / 0.5657 | 610, 1 |
| openai_mod/mod_hate | calibrated | 2 / 0 / 0 | 0.9934 / 0.9934 / 0.9951 | 0.5614 | 0.5608 / 0.5644 / 0.5579 | 610, 2 |
| openai_mod/mod_sexual | refusal_free | 0 / 0 / 0 | 0.9950 / 0.9942 / 0.9926 | 0.7517 | 0.7760 / 0.7695 / 0.7670 | 612, 3 |
| openai_mod/mod_sexual | calibrated | 0 / 0 / 0 | 0.9967 / 0.9967 / 0.9942 | 0.7517 | 0.7365 / 0.7365 / 0.7479 | 612, 1 |
| openai_mod/mod_violence | refusal_free | 2 / 0 / 0 | 0.9918 / 0.9918 / 0.9918 | 0.6677 | 0.6480 / 0.6480 / 0.6480 | 610, 0 |
| openai_mod/mod_violence | calibrated | 2 / 0 / 0 | 0.9943 / 0.9943 / 0.9943 | 0.6677 | 0.6641 / 0.6641 / 0.6601 | 610, 2 |
| toxicchat/cat_hate | refusal_free | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.1875 | 0.1875 / 0.1875 / 0.1875 | 200, 0 |
| toxicchat/cat_hate | calibrated | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.1875 | 0.1875 / 0.1875 / 0.1875 | 200, 0 |
| toxicchat/cat_sexual | refusal_free | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.7407 | 0.7407 / 0.7407 / 0.7407 | 200, 0 |
| toxicchat/cat_sexual | calibrated | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.7407 | 0.7407 / 0.7407 / 0.7407 | 200, 0 |
| toxicchat/cat_violence | refusal_free | 0 / 0 / 0 | 0.9950 / 0.9950 / 0.9950 | 0.1212 | 0.1250 / 0.1250 / 0.1250 | 200, 0 |
| toxicchat/cat_violence | calibrated | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.1212 | 0.1212 / 0.1212 / 0.1212 | 200, 0 |
| toxicchat/mod_hate | refusal_free | 0 / 0 / 0 | 1.0000 / 1.0000 / 0.9950 | 0.1818 | 0.1818 / 0.1818 / 0.1875 | 200, 1 |
| toxicchat/mod_hate | calibrated | 0 / 0 / 0 | 1.0000 / 1.0000 / 0.9950 | 0.1818 | 0.1818 / 0.1818 / 0.1875 | 200, 1 |
| toxicchat/mod_sexual | refusal_free | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.7407 | 0.7407 / 0.7407 / 0.7407 | 200, 0 |
| toxicchat/mod_sexual | calibrated | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.7407 | 0.7407 / 0.7407 / 0.7407 | 200, 0 |
| toxicchat/mod_violence | refusal_free | 0 / 0 / 0 | 0.9950 / 0.9950 / 1.0000 | 0.1212 | 0.1250 / 0.1250 / 0.1212 | 200, 1 |
| toxicchat/mod_violence | calibrated | 0 / 0 / 0 | 1.0000 / 1.0000 / 1.0000 | 0.1212 | 0.1212 / 0.1212 / 0.1212 | 200, 0 |
