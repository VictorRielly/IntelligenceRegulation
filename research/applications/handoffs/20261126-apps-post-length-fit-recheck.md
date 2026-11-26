# Coordinator's check of A24 (2026-11-26)

Astra's handoff, [which texts fit the installed classifier](20261126-apps-post-length-fit.md), is carried forward for the rows I could check. Two rows stay as Astra's reading.

## Checked

[The script](20261126-apps-post-length-fit-recheck.py) reads my own copies of the documents and [prints](20261126-apps-post-length-fit-recheck.out.txt) 10 quotations found and 15 checks passed.

- **Text messages.** The study has "936 text messages in English" from "a sample of 139 students", and "Seven percent of messages exceeded the notional 160 character per message limit". So at least 93 percent are within 160 characters.
- **Comments on technology news.** The corpus has "311167 categorized, direct responses", and "the second and third quartile of the comment lengths range from 1 to 45 words".
- **Book reviews.** 101 online reviews with a mean of 244 words, "with well over half being 300 words or less". No share at 36, 41 or 187 words follows from that.
- **The conversion.** The cited page says "1 token is approximately 4 characters" and "1 token is approximately three-quarters of a word". The handoff's arithmetic from it is right: 49 tokens are 196 characters or 36 whole words, 55 are 220 or 41, 336 are 1,344 or 252, and 1,000 characters are about 187 words.
- **The bounds.** They follow from the statistics above: 93 to 100 percent for the messages; 25 to 75 percent for one chunk and 75 to 100 percent for a whole post for the comments.
- **The measured figures** the handoff repeats are in the linked record: 50 tokens need four proofs, 336 need 22, 337 is refused; the 1,000- and 1,001-character drafts have 223 tokens each; two strings of 196 characters have 18 and 98 tokens; the pilot post has 62 characters, 13 words and 14 tokens.
- **The byte rule.** The app encodes one leading space plus the text without start or end tokens (`apps/proven-media/proven_media/shieldstral_text.py`, line 55). A byte-level encoder emits at most one token per byte, so 48 bytes of content fit 49 tokens and 335 bytes fit 336.

## Not checked by me

- The first table row (short posts under a 140-character limit, 100 percent): the paper's PDF gave my extractor no text.
- The paragraph on the 280-character trial (2 percent over 190 characters): the page refused my request (HTTP 403).
- The words "counting spaces" in the text-message row.
- The native export's `profile.json`, which is on the project machine only, as the handoff says.

## Reading

- Every share here is a range of a length proxy, as the handoff says. The two 196-character strings at 18 and 98 tokens show that the proxy can be wrong by a factor of two or more in either direction.
- The comments row rests on one sentence of the paper; the paper gives no table of lengths.
- Two source addresses in the handoff contain the name of a service. The prose names none, and I left the addresses as citations.
- A33, which Astra has taken, replaces the proxy with the installed tokenizer on two retained benchmark releases.
