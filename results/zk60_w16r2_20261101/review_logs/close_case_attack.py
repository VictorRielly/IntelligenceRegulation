"""Close-case (lemma case (b)) attack on the hiding Ligero column test, at a toy
rate-1/2 geometry, in the Goldilocks field, with the zkp-core encoder's exact
convention (f = f_data + Z_n * g_pad, evaluated on h * G_N, h = 7).

The cheater commits U = Enc([M | P]) + E, E nonzero on e columns of row 0 only
(so U is within the unique-decoding radius: case (b)), and then opens a FALSE
claim. It passes every column check except on e + 1 columns, so the acceptance
probability is exactly (1 - (e+1)/N)^Q -- the lemma's bound is attained.
Base-field challenges are used (the algebra is identical over Fp2).
"""
import random, math

P = 2**64 - 2**32 + 1
def inv(a): return pow(a, P - 2, P)

def two_adic_root(k):
    # 7 generates Fp*; omega_k = 7^((P-1)/2^k)
    return pow(7, (P - 1) >> k, P)

def poly_eval(c, x):
    r = 0
    for a in reversed(c):
        r = (r * x + a) % P
    return r

def poly_mul_linear(c, z):  # c(X) * (X - z)
    out = [0] * (len(c) + 1)
    for i, a in enumerate(c):
        out[i + 1] = (out[i + 1] + a) % P
        out[i] = (out[i] - a * z) % P
    return out

def run(log_n=4, inv_rate=2, Q=4, rows=6, trials=20000, seed=1):
    rnd = random.Random(seed)
    n = 1 << log_n; N = n * inv_rate; K = n + Q
    e = (N - K) // 2
    w = two_adic_root(int(math.log2(N))); h = 7
    xs = [h * pow(w, j, P) % P for j in range(N)]           # the coset h * G_N
    wn = two_adic_root(log_n)
    gn = [pow(wn, i, P) for i in range(n)]                  # G_n (data points)

    def enc(msg, pad):
        # f_data = interpolation of msg on G_n (degree < n); f = f_data + Z_n * g_pad
        # (Lagrange on G_n via inverse DFT)
        ninv = inv(n)
        coef = [sum(msg[k] * pow(gn[k], (n - i) % n, P) for k in range(n)) * ninv % P for i in range(n)]
        f = coef + [0] * Q
        for i in range(Q):
            f[i] = (f[i] - pad[i]) % P
            f[n + i] = (f[n + i] + pad[i]) % P
        return [poly_eval(f, x) for x in xs], f

    def dec(f):  # polynomial of degree < K -> (msg, pad) under the same convention
        g_pad = f[n:n + Q] + [0] * (Q - len(f[n:n + Q]))
        f_data = f[:n]
        f_data = [(f_data[i] + (g_pad[i] if i < Q else 0)) % P for i in range(n)]
        msg = [poly_eval(f_data, x) for x in gn]
        return msg, g_pad

    # honest data rows and pads
    M = [[rnd.randrange(P) for _ in range(n)] for _ in range(rows)]
    Pd = [[rnd.randrange(P) for _ in range(Q)] for _ in range(rows)]
    V = [enc(M[i], Pd[i])[0] for i in range(rows)]
    # D0: the codeword vanishing on K-1 chosen columns Z
    cols = list(range(N)); rnd.shuffle(cols)
    Z, S, R = cols[:K - 1], cols[K - 1:K - 1 + e], cols[K - 1 + e:]
    assert len(R) == e + 1
    D0 = [1]
    for z in Z:
        D0 = poly_mul_linear(D0, xs[z])
    assert len(D0) == K
    D0e = [poly_eval(D0, x) for x in xs]
    assert all(D0e[z] == 0 for z in Z) and all(D0e[j] != 0 for j in S + R)
    # check dec/enc round trip on D0
    dm, dp = dec(D0)
    assert enc(dm, dp)[0] == D0e
    # the committed (cheating) matrix: row 0 corrupted on S by D0 (|S| = e: case (b))
    U = [row[:] for row in V]
    for j in S:
        U[0][j] = (U[0][j] + D0e[j]) % P
    # one claim: sum of row 0's data (column weights all-ones); claimed value is FALSE
    true_val = sum(M[0]) % P
    t0 = sum(dm) % P
    assert t0 != 0
    claimed = (true_val + t0) % P
    acc = 0
    for _ in range(trials):
        lam = rnd.randrange(1, P)
        rg = [lam] + [0] * (rows - 1)                       # group weights: lam on row 0
        rp = [rnd.randrange(P) for _ in range(rows)]        # proximity weights, independent
        # cheater's vectors: honest combination plus a multiple of dec(D0)
        yg_m = [(lam * M[0][k] + lam * dm[k]) % P for k in range(n)]
        yg_p = [(lam * Pd[0][k] + lam * dp[k]) % P for k in range(Q)]
        yp_m = [(sum(rp[i] * M[i][k] for i in range(rows)) + rp[0] * dm[k]) % P for k in range(n)]
        yp_p = [(sum(rp[i] * Pd[i][k] for i in range(rows)) + rp[0] * dp[k]) % P for k in range(Q)]
        # claim check: <y_g[..n], 1> == lam * claimed
        assert sum(yg_m) % P == lam * claimed % P
        Eg = enc(yg_m, yg_p)[0] if _ < 3 else None
        idx = [rnd.randrange(N) for _ in range(Q)]
        if _ < 3:
            Ep = enc(yp_m, yp_p)[0]
            bad = [j for j in range(N) if Eg[j] != sum(rg[i] * U[i][j] for i in range(rows)) % P or Ep[j] != sum(rp[i] * U[i][j] for i in range(rows)) % P]
            assert sorted(bad) == sorted(R), "the cheater fails exactly on R"
        acc += all(j not in R for j in idx)
    bound = (1 - (e + 1) / N) ** Q
    print(f"toy n={n} N={N} Q={Q} K={K} e={e}: false claim accepted {acc}/{trials} = {acc/trials:.4f}; lemma bound (1-(e+1)/N)^Q = {bound:.4f}")

def bits():
    def ud(log_n, r, q):
        n = 1 << log_n; N = n * r; K = n + q; e = (N - K) // 2
        return q * math.log2(1 - (e + 1) / N)
    def d3(log_n, r, q):
        n = 1 << log_n; N = n * r; K = n + q
        return q * math.log2((2 * N + K) / (3 * N))
    print(f"W16R2 (1/2, Q260): counted (delta/2) 2^{ud(14,2,260):.3f}; explicit close-case attack attains 2^{ud(14,2,260):.3f}")
    print(f"W16   (1/4, Q256): counted (delta/3) 2^{d3(14,4,256):.3f}; explicit close-case attack (unique radius) 2^{ud(14,4,256):.3f}")
    # run-level: 97 regular openings at 8B T128
    for name, o in [("W16R2", ud(14, 2, 260)), ("W16 best-known", ud(14, 4, 256))]:
        print(f"  {name}: 97 openings union 2^{o + math.log2(97):.2f}")

if __name__ == "__main__":
    run()
    bits()
