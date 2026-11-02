# Hashline demo video: narration script (optional voiceover)

**The video:** `~/Downloads/Hashline_demo_captioned.mp4`, 2:00, captioned, no sound.
- **Source material:** real screenshots from the Oct 30 app run (`results/zk60_astra_20261026/real_app_demo_2/screenshots/`) plus the measured GPU numbers.
- **To rebuild:** compile `slides.swift`, render `slides.json`, then run the ffmpeg steps in the session notes.

**Voiceover (optional):**
1. Open QuickTime, choose File → New Audio Recording, and play the video muted beside it.
2. Read one block per slide, starting each block at the time shown (about 300 words, at a normal pace).
3. Save the recording to Downloads; Claude merges it with the video.

| Starts at | Slide | Say |
|---|---|---|
| 0:00 | Title | "This is Hashline: proofs of what an AI did, without the data." |
| 0:07 | Feed | "Here's a demo social app. Every post is labelled by a real AI safety classifier, Mistral's open Shieldstral model, for explicit content, violence and hate." |
| 0:23 | Post | "Each label comes with a zero-knowledge proof that this exact classifier, run on this post, produced this verdict. Checking the proof never requires seeing the post or the model's internal steps." |
| 0:41 | Labels table | "There's one proof per category, under a fixed, registered policy. It's proved once, when the post is created, and then the proof travels with the post." |
| 0:57 | Ledger | "The proof records are batched and anchored on a public chain. This is Base's test network, block 52,373,745." |
| 1:11 | GPU | "The same prover now runs on a GPU. One layer of an 8-billion-parameter model took 12 seconds on a laptop CPU; on an Apple GPU it takes a third of a second. That's about 11 proved tokens a second per request, and about 22 with several at once. Next is NVIDIA GPUs, aiming at 50." |
| 1:33 | Claims | "To be clear about what's claimed: the inputs, outputs and every intermediate value stay hidden, and soundness is about 97 bits. Our privacy statements passed internal review, and an external audit is next. This classifier's privacy statement is still pending, as the app says." |
| 1:51 | Close | "Next: open source, NVIDIA GPUs, and the first platform pilots. Thanks." |
