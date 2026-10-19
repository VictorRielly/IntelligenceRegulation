import re, sys, json
html = open(sys.argv[1], encoding='utf-8', errors='replace').read()
chunks = re.findall(r'enqueue\("((?:[^"\\]|\\.)*)"\)', html)
text = ''
for c in chunks:
    try:
        text += json.loads('"' + c + '"')
    except Exception:
        pass
if not text:
    text = html
strs = re.findall(r'"((?:[^"\\]|\\.){300,})"', text)
out, seen = [], set()
for s in strs:
    try:
        v = json.loads('"' + s + '"')
    except Exception:
        continue
    if v in seen or v.count(' ') < 40 or v.startswith('http'):
        continue
    seen.add(v); out.append(v)
open(sys.argv[2], 'w').write('\n\n=====\n\n'.join(out))
print(sys.argv[1].split('/')[-2], len(out), 'blocks;', sum(len(x) for x in out), 'chars')
