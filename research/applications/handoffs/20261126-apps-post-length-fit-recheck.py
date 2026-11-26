"""Coordinator's check of applications handoff A24 (which published texts fit the installed app).
Usage: python3 -I this.py sms=FILE comments=FILE reviews=FILE tokens=FILE result=RESULT.json handoff=HANDOFF.md
The first four are my own copies of public documents the handoff cites (three PDFs, one web page); result is the
measured-boundaries record the handoff links; handoff is the handoff itself. The files are read as data; nothing is
executed. Prints the size and SHA-256 of each input, then for each statement found / NOT FOUND or ok / FAIL.
PDF text is taken from the compressed content streams by a small extractor that drops some spaces, so quotations are
compared with all whitespace removed. Exits non-zero if anything is NOT FOUND or FAIL."""
import hashlib
import html
import json
import re
import sys
import zlib

A = dict(a.split('=', 1) for a in sys.argv[1:])
ok = True


def say(label, cond):
    global ok
    print(('ok   ' if cond else 'FAIL ') + label)
    ok = ok and bool(cond)


def dec(tok):
    if tok.startswith(b'<'):
        h = re.sub(rb'\s+', b'', tok[1:-1])
        if len(h) % 2:
            h += b'0'
        return bytes.fromhex(h.decode()).decode('cp1252', errors='replace')
    return re.sub(rb'\\([()\\])', rb'\1', tok[1:-1]).decode('cp1252', errors='replace')


def pdf_text(data):
    parts = [data]
    for m in re.finditer(rb'stream\r?\n(.*?)\r?\nendstream', data, re.S):
        try:
            parts.append(zlib.decompress(m.group(1)))
        except Exception:
            pass
    out = []
    for m in re.finditer(rb'BT\b(.*?)\bET\b', b'\n'.join(parts), re.S):
        for t in re.finditer(rb'\[(.*?)\]\s*TJ|(<[0-9A-Fa-f\s]*>|\((?:\\.|[^\\)])*\))\s*Tj', m.group(1), re.S):
            if t.group(1) is not None:
                for p in re.finditer(rb'<[0-9A-Fa-f\s]*>|\((?:\\.|[^\\)])*\)', t.group(1)):
                    out.append(dec(p.group(0)))
            else:
                out.append(dec(t.group(2)))
    return ''.join(out)


def squeeze(s):
    return re.sub(r'\s+', '', s).lower()


texts = {}
for key in ('sms', 'comments', 'reviews', 'tokens', 'result', 'handoff'):
    raw = open(A[key], 'rb').read()
    print('%-9s bytes %8d  sha256 %s' % (key, len(raw), hashlib.sha256(raw).hexdigest()))
    if raw[:5] == b'%PDF-':
        texts[key] = pdf_text(raw)
    elif key == 'tokens':
        t = re.sub(r'(?is)<(script|style)\b.*?</\1>', ' ', raw.decode('utf-8', 'replace'))
        texts[key] = html.unescape(re.sub(r'<[^>]+>', ' ', t))
    else:
        texts[key] = raw.decode('utf-8')
QUOTES = [
    ('sms', '936 text messages in English'),
    ('sms', 'a sample of 139 students'),
    ('sms', 'Seven percent of messages exceeded the notional 160 character per message limit'),
    ('comments', '311167 categorized, direct responses'),
    ('comments', 'the second and third quartile of the comment lengths range from 1 to 45 words'),
    ('reviews', 'and 101 reviews'),
    ('reviews', 'reviews was 244'),
    ('reviews', 'with well over half being 300 words or less'),
    ('tokens', '1 token is approximately 4 characters'),
    ('tokens', '1 token is approximately three-quarters of a word'),
]
for key, q in QUOTES:
    found = squeeze(q) in squeeze(texts[key])
    print(('found     ' if found else 'NOT FOUND ') + key + ': ' + q)
    ok = ok and found

H = texts['handoff']
R = json.loads(texts['result'])
# the conversion arithmetic of the handoff (4 characters or 0.75 words per token)
say('49 tokens -> 196 characters or 36 whole words', (49 * 4, int(49 * 0.75)) == (196, 36) and '196 characters or 36 whole words' in H)
say('55 tokens -> 220 characters or 41 whole words', (55 * 4, int(55 * 0.75)) == (220, 41) and '220 characters or 41 whole words' in H)
say('336 tokens -> 1,344 characters or 252 words', (336 * 4, 336 * 0.75) == (1344, 252.0) and '1,344 characters or 252 words' in H)
say('1,000 characters -> about 187 whole words', int(1000 / 4 * 0.75) == 187 and '1,000 characters or about 187 whole words' in H)
# the bounds the handoff derives from the published statistics
say('messages: 7 percent over 160 characters and 160 < 196, so at least 93 percent fit one chunk and the whole post', 160 < 196 < 1000 and H.count('93–100%') >= 3)
say('comments: 36 and 41 words lie between the quartiles 1 and 45, so 25 to 75 percent; 187 words lies above, so 75 to 100 percent',
    1 <= 36 <= 45 and 1 <= 41 <= 45 < 187 and '| 75–100% | 25–75% | 25–75% |' in H)
say('reviews: a mean and a share at 300 words give no share at 36, 41 or 187 words', 300 > 187 and '| Unknown | Unknown | Unknown |' in H)
# the measured figures the handoff repeats from the linked record
tb = R['token_boundaries']
say('50 tokens need four proofs, 336 need 22, 337 is over the limit', sum(tb['50'].values()) == 4 and sum(tb['336'].values()) == 22 and tb['337'] == 'over token limit'
    and 'A 50-token test post needed four proofs, a 336-token post needed 22, and 337 tokens exceeded the limit' in H)
say('49 tokens need one proof per policy, 56 need two per policy', set(tb['49'].values()) == {1} and set(tb['56'].values()) == {2})
cb = R['character_boundaries']
say('the 1,000- and 1,001-character drafts have 223 tokens each; only the first is within the character limit',
    cb['1000'] == {'content_tokens': 223, 'within_character_limit': True} and cb['1001'] == {'content_tokens': 223, 'within_character_limit': False}
    and 'Two test drafts counted 223 tokens each' in H)
ex = sorted((v['characters'], v['content_tokens'], v['proofs']) for v in R['same_length_examples'].values())
say('two 196-character strings: 18 and 98 content tokens, three and seven proofs', ex == [(196, 18, 3), (196, 98, 7)]
    and '**18 and 98 actual content tokens**, requiring three and seven proofs' in H)
say('pilot fixture: 62 characters, 13 words, 14 tokens', R['public_fixture'] == {'characters': 62, 'whitespace_words': 13, 'content_tokens': 14}
    and '62 characters, 13 whitespace-delimited words and 14 tokens' in H)
say('capacities 55 / 55 / 49 in the record', [R['native_statements'][k]['chunk_tokens'] for k in ('sexual', 'violence', 'hate')] == [55, 55, 49])
say('no new native run in the record', R['new_native_runs'] == 0)
say('byte rule: one leading space plus 48 bytes is 49 bytes, plus 335 bytes is 336 (a byte-level encoder emits at most one token per byte)',
    1 + 48 == 49 and 1 + 335 == 336 and 'Up to 48 UTF-8 content bytes therefore fit the tightest policy, and up to 335 bytes fit the whole post' in H)
print('RESULT:', 'ALL CHECKS PASSED' if ok else 'SOMETHING FAILED')
sys.exit(0 if ok else 1)
