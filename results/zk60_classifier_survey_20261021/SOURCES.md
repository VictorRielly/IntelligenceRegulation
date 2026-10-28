# Sources for the classifier survey (accessed 2026-10-20/21 UTC)

Every source was fetched during this survey unless marked otherwise. "HF API" means the
Hugging Face model API (`/api/models/...`), which returns the official parameter count,
licence tag, gating and repository creation date even for gated repositories. "Mirror" means
an ungated third-party copy of a gated Meta repository. We used mirrors only for `config.json`,
the tokenizer and the chat template, and checked each one against an official fact (parameter
count or model card) where we could.

## Mistral
- S1. Shieldstral-1.0-3B model card. https://huggingface.co/mistralai/Shieldstral-1.0-3B
- S2. Shieldstral config.json. https://huggingface.co/mistralai/Shieldstral-1.0-3B/raw/main/config.json
- S3. Shieldstral chat template. https://huggingface.co/mistralai/Shieldstral-1.0-3B/raw/main/chat_template.jinja
- S4. HF API, Shieldstral: 3,849,090,048 parameters, apache-2.0, not gated, repo created 2026-07-16. https://huggingface.co/api/models/mistralai/Shieldstral-1.0-3B
- S5. Mistral blog, "Shieldstral", dated 2026-08-04. https://mistral.ai/news/shieldstral
- S6. Shieldstral paper, arXiv 2607.25857 (v1 2026-07-28, v2 2026-08-04). https://arxiv.org/abs/2607.25857
- S7. Mistral docs model page, Shieldstral 1.0: 2026-08-04, 3.8B, 32k context, public preview. https://docs.mistral.ai/models/shieldstral-1-0
- S8. Mistral cookbook, policy moderation with Shieldstral (scoring code, self-hosted only). https://docs.mistral.ai/resources/cookbooks/mistral-moderation-shieldstral_policy_moderation
- S9. Mistral docs, Moderation & Guardrailing (current categories, 2603 powers the service, 2411 deprecated). https://docs.mistral.ai/capabilities/guardrailing and https://docs.mistral.ai/studio/safety-moderation
- S10. Mistral docs model card, Mistral Moderation 2 (v26.03): 128k context, jailbreak detection, free. https://docs.mistral.ai/models/mistral-moderation-26-03
- S11. Mistral changelog: Moderation 2603 released 2026-03-12; Classifier Factory 2025-04-16; moderation API 2024-11-06. https://docs.mistral.ai/resources/changelogs
- S12. Mistral cookbook, "Moderation explored": "a classifier model based on Ministral 8B 24.10". https://docs.mistral.ai/resources/cookbooks/mistral-moderation-moderation-explored
- S13. Mistral blog, moderation API launch, 2024-11-07. https://mistral.ai/news/mistral-moderation
- S14. Mistral models overview: 2411 deprecated 2026-03-31, retires 2026-06-30. https://docs.mistral.ai/getting-started/models/
- S15. transformers `modeling_ministral3.py` (no QK-norm; llama-4 query scaling formula; RoPE attention factor). https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/ministral3/modeling_ministral3.py
- S16. transformers `modeling_pixtral.py` (RMSNorm, gated MLP, 2D RoPE, non-causal block-diagonal mask, bias-free patch conv). https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/pixtral/modeling_pixtral.py
- S17. transformers `modeling_mistral3.py` (projector: RMSNorm, 2x2 patch merger, linear, GELU, linear). https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/mistral3/modeling_mistral3.py
- S70. HF API listing of the mistralai organisation, newest first (Shieldstral is the only moderation model with weights). https://huggingface.co/api/models?author=mistralai&sort=createdAt&direction=-1&limit=40

## Meta
- S18. Llama Guard 3 1B model card. https://huggingface.co/meta-llama/Llama-Guard-3-1B
- S19. HF API, Llama-Guard-3-1B: 1,498,482,688 parameters, llama3.2 licence, gated (manual), created 2024-09-20. https://huggingface.co/api/models/meta-llama/Llama-Guard-3-1B
- S20. Mirror alpindale/Llama-Guard-3-1B (config, tokenizer, chat template). https://huggingface.co/alpindale/Llama-Guard-3-1B
- S21. PurpleLlama, Llama Guard 3 1B model card. https://github.com/meta-llama/PurpleLlama/blob/main/Llama-Guard3/1B/MODEL_CARD.md
- S22. Llama Guard 3-1B-INT4 paper, arXiv 2411.17713 (12 layers, MLP 6400, 20 output tokens, about 440 MB). https://arxiv.org/html/2411.17713
- S23. HF API, Llama-Guard-3-1B-INT4: files are an ExecuTorch `.pte` and no safetensors. https://huggingface.co/api/models/meta-llama/Llama-Guard-3-1B-INT4
- S24. Llama Guard 3 8B model card (unsafe score = first-token probability; F1/AUPRC tables). https://huggingface.co/meta-llama/Llama-Guard-3-8B
- S25. Mirror VincentGOURBIN/Llama-Guard-3-8B (config, tokenizer, chat template). https://huggingface.co/VincentGOURBIN/Llama-Guard-3-8B
- S26. Meta prompt-format page, Llama Guard 3. https://dev.meta.ai/llama/docs/model-cards-and-prompt-formats/llama-guard-3/
- S27. llama-cookbook `prompt_format_utils.py` (template ends at the assistant header). https://raw.githubusercontent.com/meta-llama/llama-cookbook/main/src/llama_cookbook/inference/prompt_format_utils.py
- S28. Llama Guard 4 12B model card. https://huggingface.co/meta-llama/Llama-Guard-4-12B
- S29. HF API, Llama-Guard-4-12B: 12,001,097,216 parameters, llama4 licence, gated, created 2025-04-23. https://huggingface.co/api/models/meta-llama/Llama-Guard-4-12B
- S30. Mirror unsloth/Llama-Guard-4-12B (config, tokenizer, chat template). https://huggingface.co/unsloth/Llama-Guard-4-12B
- S31. Hugging Face blog, "Welcome Llama Guard 4", 2025-04-29. https://huggingface.co/blog/llama-guard-4
- S32. HF API listing of meta-llama Guard models (no Llama Guard 5). https://huggingface.co/api/models?author=meta-llama&search=Guard
- S33. Llama 3.2 Community License (700M MAU clause, "Built with Llama", "Llama" name prefix). https://huggingface.co/meta-llama/Llama-3.2-1B/blob/main/LICENSE.txt
- S34. Llama Guard 3 11B Vision model card (EU restriction on multimodal Llama 3.2 rights). https://huggingface.co/meta-llama/Llama-Guard-3-11B-Vision

## Google
- S35. ShieldGemma 2B model card (prompt, Yes/No scoring, optimal F1 / AUPRC table). https://huggingface.co/google/shieldgemma-2b
- S36. HF API, shieldgemma-2b: 2,614,341,888 parameters, Gemma2ForCausalLM, gated. https://huggingface.co/api/models/google/shieldgemma-2b
- S37. gemma-2-2b config (ungated mirror unsloth/gemma-2-2b; same architecture as ShieldGemma 2B, parameter count matches S36). https://huggingface.co/unsloth/gemma-2-2b/raw/main/config.json
- S38. transformers `modeling_gemma2.py` ((1+w) RMSNorm, 4 norms per layer, sqrt(d) embedding scale, softcapping, alternating sliding window). https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/gemma2/modeling_gemma2.py
- S39. ShieldGemma 2 (4B) model card. https://huggingface.co/google/shieldgemma-2-4b-it
- S40. HF API, shieldgemma-2-4b-it: ShieldGemma2ForImageClassification, 4,300,079,472 parameters. https://huggingface.co/api/models/google/shieldgemma-2-4b-it
- S41. Gemma Terms of Use (last updated 2026-04-01). https://ai.google.dev/gemma/terms

## Alibaba Qwen
- S42. Qwen3Guard-Gen-0.6B model card. https://huggingface.co/Qwen/Qwen3Guard-Gen-0.6B
- S43. Qwen3Guard-Gen configs: https://huggingface.co/Qwen/Qwen3Guard-Gen-0.6B/raw/main/config.json , https://huggingface.co/Qwen/Qwen3Guard-Gen-4B/raw/main/config.json , https://huggingface.co/Qwen/Qwen3Guard-Gen-8B/raw/main/config.json
- S44. Qwen3Guard Technical Report, arXiv 2510.14276 (Tables 2 and 3). https://arxiv.org/html/2510.14276v1
- S45. transformers `modeling_qwen3.py` (q_norm/k_norm over head_dim before RoPE). https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/qwen3/modeling_qwen3.py
- S46. HF API listing of the Qwen organisation, newest first (no guard model newer than Qwen3Guard). https://huggingface.co/api/models?author=Qwen&sort=createdAt&direction=-1&limit=60

## OpenAI
- S47. gpt-oss-safeguard-20b model card. https://huggingface.co/openai/gpt-oss-safeguard-20b
- S48. gpt-oss-safeguard-20b config.json. https://huggingface.co/openai/gpt-oss-safeguard-20b/raw/main/config.json
- S49. OpenAI cookbook, user guide for gpt-oss-safeguard (policy length 400-600 tokens, reasoning channel). https://developers.openai.com/cookbook/articles/gpt-oss-safeguard-guide
- S50. OpenAI gpt-oss-safeguard technical report, dated 2025-10-29 (seen only as a search-result snippet; direct fetch returned HTTP 403). https://openai.com/index/gpt-oss-safeguard-technical-report
- S71. HF API listing of the openai organisation (repos created 2025-09-18). https://huggingface.co/api/models?author=openai&sort=createdAt&direction=-1&limit=30

## IBM
- S51. Granite Guardian 4.1 8B model card (April 2026; guardian block; OOD safety F1 table). https://huggingface.co/ibm-granite/granite-guardian-4.1-8b
- S52. Granite Guardian 4.1 8B config.json. https://huggingface.co/ibm-granite/granite-guardian-4.1-8b/raw/main/config.json
- S53. Granite Guardian 3.3 8B model card. https://huggingface.co/ibm-granite/granite-guardian-3.3-8b
- S54. Granite Guardian 3.1 2B model card, config and chat template. https://huggingface.co/ibm-granite/granite-guardian-3.1-2b
- S55. HF API listing of ibm-granite guardian models. https://huggingface.co/api/models?author=ibm-granite&search=guardian&sort=createdAt&direction=-1&limit=40

## NVIDIA
- S56. Nemotron-3.5-Content-Safety model card (2026-06-02). https://huggingface.co/nvidia/Nemotron-3.5-Content-Safety
- S57. Nemotron-3.5-Content-Safety config.json and chat template. https://huggingface.co/nvidia/Nemotron-3.5-Content-Safety/raw/main/config.json
- S58. Nemotron-3-Content-Safety model card (2026-03-16). https://huggingface.co/nvidia/Nemotron-3-Content-Safety
- S59. Llama-3.1-Nemotron-Safety-Guard-8B-v3 model card (2025-10-28). https://huggingface.co/nvidia/Llama-3.1-Nemotron-Safety-Guard-8B-v3
- S60. HF API listing of NVIDIA safety models. https://huggingface.co/api/models?author=nvidia&search=safety&sort=createdAt&direction=-1&limit=40

## Others
- S61. Kanana Safeguard 8B model card, config.json and tokenizer_config.json (Kakao). https://huggingface.co/kakaocorp/kanana-safeguard-8b
- S62. WildGuard model card (AI2). https://huggingface.co/allenai/wildguard
- S63. DuoGuard paper, arXiv 2502.05163, Table 1 (third-party Llama Guard 3 1B and ShieldGemma 2B scores). https://arxiv.org/html/2502.05163
- S64. GuardReasoner paper, arXiv 2501.18492, Tables II and V. https://arxiv.org/html/2501.18492
- S65. "Benchmarking Open-Source Safety Guard Models", arXiv 2605.28830 (ICLR 2026 workshop). https://arxiv.org/html/2605.28830v1
- S66. mozilla-ai/any-guardrail issue #179, June 2026 sweep of open guard models ("Llama Guard 5" and "Prompt Guard 3" do not exist). https://github.com/mozilla-ai/any-guardrail/issues/179
- S67. HF API listing of LlavaGuard models (AIML-TUDA). https://huggingface.co/api/models?author=AIML-TUDA&search=LlavaGuard
- S68. OmniGuard, arXiv 2512.02306 (2025-12-02). https://arxiv.org/abs/2512.02306v1
- S69. GuardReasoner-Omni, arXiv 2602.03328 (2026-02-03, v2 2026-05-27). https://arxiv.org/abs/2602.03328
- S73. Roblox newsroom: Roblox Guard 1.0 (July 2025); ROOST release of three safety models (August 2026). https://about.roblox.com/newsroom/2025/07/roblox-guard-advancing-safety-for-llms-with-robust-guardrails and https://about.roblox.com/newsroom/2026/08/roblox-open-source-safety-models-roost

## Local evidence (this repository)
- S72. Prover admission checks: `scripts/zk60_1b_checkpoint.py` lines 118-147 reject `rope_scaling`, `sliding_window`,
  tied embeddings and `head_dim != hidden/heads`. `scripts/m8b_int8_calibration.py` line 245 reads only
  `rope_theta` and does not look at `rope_scaling`. The 8B calibration used Meta-Llama-3-8B, which has no RoPE scaling
  (`results/zk60_8b_calibration_20261017/`).
- T1. `token_counts.json` in this directory: template token counts. `count_tokens.py` in this directory renders each
  model's own chat template (or the prompt documented on its model card) around one 41-token sample post and tokenizes
  the result with the model's own `tokenizer.json` (HF `tokenizers` 0.23.3, `jinja2`; installed only in the session
  scratchpad). The tokenizers came from S1, S20, S25, S30, S37, S42, S51, S54 and S56.
