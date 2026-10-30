"""Python mirror of the planned Rust module follower (token round 19), to predict the closure and edges."""
import os, sys
ROOT = sys.argv[1]
def src(p): return open(os.path.join(ROOT, p)).read()
def prod(t):
    k = t.find("\n#[cfg(test)]\nmod tests {")
    return t if k < 0 else t[:k+1]

def lex(text):
    c = list(text); n = len(c); i = 0; line = 1; out = []
    def isid0(ch): return ch.isalpha() or ch == '_'
    def isid(ch): return ch.isalnum() or ch == '_'
    while i < n:
        ch = c[i]
        if ch == '\n': line += 1; i += 1; continue
        if ch.isspace(): i += 1; continue
        if ch == '/' and i+1 < n and c[i+1] == '/':
            while i < n and c[i] != '\n': i += 1
            continue
        if ch == '/' and i+1 < n and c[i+1] == '*':
            depth = 0
            while i < n:
                if c[i] == '/' and i+1 < n and c[i+1] == '*': depth += 1; i += 2; continue
                if c[i] == '*' and i+1 < n and c[i+1] == '/':
                    depth -= 1; i += 2
                    if depth == 0: break
                    continue
                if c[i] == '\n': line += 1
                i += 1
            else:
                raise ValueError(f"unterminated block comment at {line}")
            if depth: raise ValueError("unterminated block comment")
            continue
        def esc_string(i, line):
            # c[i] == '"'
            i += 1; s = []
            while True:
                if i >= n: raise ValueError(f"unterminated string at {line}")
                if c[i] == '\\': s.append(c[i]); s.append(c[i+1] if i+1<n else ''); 
                if c[i] == '\\':
                    if i+1 < n and c[i+1] == '\n': line += 1
                    i += 2; continue
                if c[i] == '"': return i+1, line, ''.join(s)
                if c[i] == '\n': line += 1
                s.append(c[i]); i += 1
        def raw_string(i, line):
            # c[i] in '#"'
            h = 0
            while i < n and c[i] == '#': h += 1; i += 1
            if i >= n or c[i] != '"': raise ValueError(f"bad raw string at {line}")
            i += 1; s = []
            while True:
                if i >= n: raise ValueError(f"unterminated raw string at {line}")
                if c[i] == '"' and all(i+1+k < n and c[i+1+k] == '#' for k in range(h)):
                    return i+1+h, line, ''.join(s)
                if c[i] == '\n': line += 1
                s.append(c[i]); i += 1
        def char_lit(i, line):
            # c[i] == "'"; returns (i, line, tok) for char literal or lifetime
            if i+1 < n and c[i+1] == '\\':
                j = i+2
                j += 1
                while j < n and c[j] != "'":
                    j += 1
                if j >= n: raise ValueError("unterminated char")
                return j+1, line, ('Other', None)
            if i+2 < n and c[i+2] == "'":
                return i+3, line, ('Other', None)
            j = i+1
            while j < n and isid(c[j]): j += 1
            return j, line, ('Other', None)
        if isid0(ch):
            j = i
            while j < n and isid(c[j]): j += 1
            word = ''.join(c[i:j])
            nx = c[j] if j < n else ''
            if word in ('r', 'br', 'cr') and (nx == '"' or (nx == '#' and j+1 < n and (c[j+1] == '"' or c[j+1] == '#'))):
                i, line2, s = raw_string(j, line); out.append(('Str', s, line)); line = line2; continue
            if word in ('b', 'c') and nx == '"':
                i, line2, s = esc_string(j, line); out.append(('Str', s, line)); line = line2; continue
            if word == 'b' and nx == "'":
                i, line, t = char_lit(j, line); out.append(('Other', None, line)); continue
            if word == 'r' and nx == '#' and j+1 < n and isid0(c[j+1]):
                k = j+1
                while k < n and isid(c[k]): k += 1
                out.append(('Ident', 'r#' + ''.join(c[j+1:k]), line)); i = k; continue
            out.append(('Ident', word, line)); i = j; continue
        if ch.isdigit():
            j = i
            while j < n and isid(c[j]): j += 1
            out.append(('Other', None, line)); i = j; continue
        if ch == '"':
            l0 = line
            i, line, s = esc_string(i, line); out.append(('Str', s, l0)); continue
        if ch == "'":
            i, line, t = char_lit(i, line); out.append(('Other', None, line)); continue
        out.append(('Punct', ch, line)); i += 1
    return out

def match_back(t, close, o, cl):
    d = 0; k = close
    while k >= 0:
        if t[k][0] == 'Punct' and t[k][1] == cl: d += 1
        elif t[k][0] == 'Punct' and t[k][1] == o:
            d -= 1
            if d == 0: return k
        k -= 1
    raise ValueError("unbalanced")

def decls(file, text):
    t = lex(text); out = []; stack = []; pending = None
    P = lambda k, ch: 0 <= k < len(t) and t[k][0] == 'Punct' and t[k][1] == ch
    I = lambda k, w: 0 <= k < len(t) and t[k][0] == 'Ident' and t[k][1] == w
    for i, tok in enumerate(t):
        if P(i, '{'):
            if pending and pending[0] == i: stack.append(('mod', pending[1] or any(s[1] for s in stack)))
            else: stack.append(('other', any(s[1] for s in stack)))
            continue
        if P(i, '}'):
            if not stack: raise ValueError(f"{file}:{tok[2]}: unbalanced")
            stack.pop(); continue
        if not I(i, 'mod'): continue
        line = tok[2]
        if not (i+1 < len(t) and t[i+1][0] == 'Ident'): raise ValueError(f"{file}:{line}: mod without a name")
        name = t[i+1][1]
        if P(i+2, ';'): kind = 'file'
        elif P(i+2, '{'): kind = 'inline'
        else: raise ValueError(f"{file}:{line}: mod {name} followed by neither ; nor {{")
        b = i
        if P(b-1, ')'):
            k = match_back(t, b-1, '(', ')')
            if not I(k-1, 'pub'): raise ValueError(f"{file}:{line}: ( ) before mod is not a visibility")
            b = k-1
        elif I(b-1, 'pub'): b -= 1
        path = None; test = False
        while P(b-1, ']'):
            k = match_back(t, b-1, '[', ']')
            if P(k-1, '!') and P(k-2, '#'): break
            if not P(k-1, '#'): raise ValueError(f"{file}:{line}: ] before mod is not an attribute")
            body = t[k+1:b-1]
            if body and body[0][:2] == ('Ident', 'path'):
                if len(body) == 3 and body[1][:2] == ('Punct', '=') and body[2][0] == 'Str' and '\\' not in body[2][1] and path is None:
                    path = body[2][1]
                else: raise ValueError(f"{file}:{line}: path attribute I cannot read")
            elif body and body[0][:2] == ('Ident', 'cfg'):
                if [x[:2] for x in body] == [('Ident','cfg'),('Punct','('),('Ident','test'),('Punct',')')]: test = True
            elif body and body[0][:2] == ('Ident', 'cfg_attr'):
                if any(x[:2] == ('Ident', 'path') for x in body): raise ValueError(f"{file}:{line}: cfg_attr path")
            b = k-1
        if b > 0 and not (P(b-1, ';') or P(b-1, '}') or P(b-1, '{') or P(b-1, ']')):
            raise ValueError(f"{file}:{line}: mod {name} preceded by {t[b-1]}")
        if kind == 'inline':
            pending = (i+2, test); continue
        if stack:
            if any(s[1] for s in stack): test = True
            else: raise ValueError(f"{file}:{line}: a file module inside braces")
        out.append((name, path, test, line))
    if stack: raise ValueError(f"{file}: unbalanced at end")
    return out

def children(file, mod_rs, text):
    d = os.path.dirname(file)
    base = d if (mod_rs or os.path.basename(file) in ('mod.rs','lib.rs','main.rs')) else file[:-3]
    res = []
    for name, path, test, line in decls(file, text):
        if test: continue
        name = name[2:] if name.startswith('r#') else name
        if path is not None:
            c = os.path.normpath(os.path.join(d, path))
            if not os.path.isfile(os.path.join(ROOT, c)): raise ValueError(f"{file}:{line}: {c} missing")
            res.append((c, True))
        else:
            cands = [f"{base}/{name}.rs", f"{base}/{name}/mod.rs"]
            ex = [x for x in cands if os.path.isfile(os.path.join(ROOT, x))]
            if len(ex) != 1: raise ValueError(f"{file}:{line}: {name}: {ex}")
            res.append((ex[0], False))
    return res

def graph(roots):
    files = [(r, False) for r in roots]; edges = []; k = 0
    while k < len(files):
        f, m = files[k]
        for c, via in children(f, m, prod(src(f))):
            edges.append((f, c))
            got = [x for x in files if x[0] == c]
            if got:
                if got[0][1] != via: raise ValueError("kind clash")
            else: files.append((c, via))
        k += 1
    return files, sorted(edges)

files, edges = graph(["src/private_block.rs", "src/private_seam.rs"])
print(len(files), "files;", len(edges), "edges")
for e in edges: print("EDGE", e)
# old r18 set
def old():
    parent = src("src/private_block.rs"); lines = parent.split("\n"); out = []
    for i, l in enumerate(lines):
        s = l.strip()
        rest = s[4:] if s.startswith("mod ") else (s[8:] if s.startswith("pub mod ") else None)
        if rest is None or not rest.endswith(";"): continue
        name = rest[:-1]
        if i > 0 and lines[i-1].strip() == "#[cfg(test)]": continue
        path = f"src/private_block/{name}.rs"; text = src(path)
        sub = text.split("\n")
        for j, sl in enumerate(sub):
            t = sl.strip()
            for p in ("pub(crate) ", "pub(super) ", "pub "):
                if t.startswith(p): t = t[len(p):]; break
            if not t.startswith("mod "): continue
            r2 = t[4:]
            if not r2.endswith(";"): continue
            child = r2[:-1]
            if j > 0 and sub[j-1].strip() == "#[cfg(test)]": continue
            cp = f"src/private_block/{name}/{child}.rs"
            if os.path.exists(os.path.join(ROOT, cp)): out.append(cp)
        out.append(path)
    out.append("src/private_block.rs")
    if "src/private_block/tied_tables/derive.rs" not in out: out.append("src/private_block/tied_tables/derive.rs")
    out += ["src/private_block/trained_accuracy.rs", "src/private_block/witness_accuracy.rs", "src/private_block/argument_accuracy.rs", "src/private_seam.rs",
            "src/private_block/token_io/classify_batch.rs", "src/private_block/token_io/classify_batch_plan.rs"]
    return out
o = old()
print("old", len(o), "unique", len(set(o)))
nf = set(f for f, _ in files)
print("new-only", sorted(nf - set(o)))
print("old-only", sorted(set(o) - nf))
