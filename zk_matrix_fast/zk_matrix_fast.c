#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef uint64_t u64;
typedef __uint128_t u128;

static const u64 Q = 2305843009213688669ULL;

static inline u64 addm(u64 a, u64 b) {
    u64 c = a + b;
    return c >= Q ? c - Q : c;
}

static inline u64 subm(u64 a, u64 b) {
    return a >= b ? a - b : Q - (b - a);
}

static inline u64 mulm(u64 a, u64 b) {
    return (u64)(((u128)a * (u128)b) % (u128)Q);
}

static u64 powm(u64 base, u64 exp) {
    u64 acc = 1;
    while (exp) {
        if (exp & 1) acc = mulm(acc, base);
        base = mulm(base, base);
        exp >>= 1;
    }
    return acc;
}

static inline u64 invm(u64 x) {
    return powm(x, Q - 2);
}

static u64 splitmix64(u64 *state) {
    u64 z = (*state += 0x9e3779b97f4a7c15ULL);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ULL;
    z = (z ^ (z >> 27)) * 0x94d049bb133111ebULL;
    return z ^ (z >> 31);
}

static u64 mix_value(u64 seed, u64 value) {
    seed ^= value + 0x9e3779b97f4a7c15ULL + (seed << 6) + (seed >> 2);
    return splitmix64(&seed);
}

static u64 challenge6(u64 domain, u64 round, u64 current, u64 scalar_base, u64 left, u64 right) {
    u64 s = 0xd6e8feb86659fd93ULL ^ domain;
    s = mix_value(s, round);
    s = mix_value(s, current);
    s = mix_value(s, scalar_base);
    s = mix_value(s, left);
    s = mix_value(s, right);
    u64 x = s % Q;
    return x ? x : 1;
}

static u64 challenge_statement(u64 domain, size_t n, u64 ca, u64 cb, u64 cc) {
    u64 s = 0xa0761d6478bd642fULL ^ domain;
    s = mix_value(s, (u64)n);
    s = mix_value(s, ca);
    s = mix_value(s, cb);
    s = mix_value(s, cc);
    u64 x = s % Q;
    return x ? x : 1;
}

static u64 challenge_commitments(
    u64 domain, size_t n, u64 ca, u64 cb, u64 cc,
    const u64 *items, size_t item_count
) {
    u64 s = 0xe7037ed1a0b428dbULL ^ domain;
    s = mix_value(s, (u64)n);
    s = mix_value(s, ca);
    s = mix_value(s, cb);
    s = mix_value(s, cc);
    for (size_t i = 0; i < item_count; i++) s = mix_value(s, items[i]);
    u64 x = s % Q;
    return x ? x : 1;
}

static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void *xcalloc(size_t count, size_t size) {
    void *ptr = calloc(count, size);
    if (!ptr) {
        fprintf(stderr, "allocation failed: %zu x %zu\n", count, size);
        exit(2);
    }
    return ptr;
}

static u64 *xcalloc_u64(size_t count) {
    return (u64 *)xcalloc(count, sizeof(u64));
}

static size_t next_power_of_two(size_t value) {
    size_t out = 1;
    while (out < value) out <<= 1;
    return out;
}

static size_t log2_power_of_two(size_t value) {
    size_t out = 0;
    while (value > 1) {
        value >>= 1;
        out++;
    }
    return out;
}

typedef struct {
    size_t n;
    size_t nn;
    u64 *a;
    u64 *b;
    u64 *c;
    u64 *ay;
    u64 *by;
    u64 scalar;
    u64 blind;
    u64 digest;
} Bases;

/* Protocol version, bumped whenever the transcript layout changes. */
static const u64 PROTOCOL_VERSION = 2;

/* Digest of the setup: protocol version, parameters and the generating
 * label set for all base families. Mixed into every Fiat-Shamir domain. */
static u64 setup_digest(size_t n) {
    u64 s = 0x5e70d16e57a0b001ULL;
    s = mix_value(s, PROTOCOL_VERSION);
    s = mix_value(s, (u64)n);
    s = mix_value(s, Q);
    s = mix_value(s, 0xA111);
    s = mix_value(s, 0xB222);
    s = mix_value(s, 0xC333);
    s = mix_value(s, 0xA444);
    s = mix_value(s, 0xB555);
    s = mix_value(s, 0xD666);
    s = mix_value(s, 0xE777);
    return s;
}

/* Bind the setup digest into a challenge domain constant. */
static u64 dom(const Bases *bases, u64 domain) {
    return mix_value(bases->digest, domain);
}

typedef struct {
    size_t n;
    u64 a_commit;
    u64 b_commit;
    u64 c_commit;
} Statement;

typedef struct {
    u64 *a;
    u64 *b;
    u64 *c;
    u64 a_blind;
    u64 b_blind;
    u64 c_blind;
} Witness;

typedef struct {
    size_t n;
    size_t rounds;
    u64 *left;
    u64 *right;
    u64 a_final;
    u64 b_final;
} IpProof;

typedef struct {
    u64 d_commit;
    u64 ay_commit;
    u64 by_commit;
    IpProof c_proj;
    IpProof a_proj;
    IpProof b_proj;
    IpProof product;
} CoreProof;

typedef struct {
    u64 mask_commit;
    u64 projected_mask_commit;
    u64 response_blind;
    u64 projected_response_blind;
    IpProof proof;
} ZkProjectionProof;

typedef struct {
    u64 alpha_commit;
    u64 beta_commit;
    u64 cross_commit;
    u64 alpha_beta_commit;
    u64 left_response_blind;
    u64 right_response_blind;
    u64 output_response_blind;
    IpProof proof;
} ZkProductProof;

typedef struct {
    u64 d_commit;
    u64 ay_commit;
    u64 by_commit;
    ZkProjectionProof c_proj;
    ZkProjectionProof a_proj;
    ZkProjectionProof b_proj;
    ZkProductProof product;
} ZkProof;

static void free_ip(IpProof *proof) {
    free(proof->left);
    free(proof->right);
    memset(proof, 0, sizeof(*proof));
}

static void free_core(CoreProof *proof) {
    free_ip(&proof->c_proj);
    free_ip(&proof->a_proj);
    free_ip(&proof->b_proj);
    free_ip(&proof->product);
}

static void free_zk_projection(ZkProjectionProof *proof) {
    free_ip(&proof->proof);
}

static void free_zk(ZkProof *proof) {
    free_zk_projection(&proof->c_proj);
    free_zk_projection(&proof->a_proj);
    free_zk_projection(&proof->b_proj);
    free_ip(&proof->product.proof);
}

static u64 basis_elem(u64 label, size_t index) {
    u64 s = 0x243f6a8885a308d3ULL ^ label;
    s = mix_value(s, (u64)index);
    u64 out = s % Q;
    return out ? out : 1;
}

static Bases make_bases(size_t n) {
    Bases bases;
    bases.n = n;
    bases.nn = n * n;
    bases.a = xcalloc_u64(bases.nn);
    bases.b = xcalloc_u64(bases.nn);
    bases.c = xcalloc_u64(bases.nn);
    bases.ay = xcalloc_u64(n);
    bases.by = xcalloc_u64(n);
    for (size_t i = 0; i < bases.nn; i++) {
        bases.a[i] = basis_elem(0xA111, i);
        bases.b[i] = basis_elem(0xB222, i);
        bases.c[i] = basis_elem(0xC333, i);
    }
    for (size_t i = 0; i < n; i++) {
        bases.ay[i] = basis_elem(0xA444, i);
        bases.by[i] = basis_elem(0xB555, i);
    }
    bases.scalar = basis_elem(0xD666, 0);
    bases.blind = basis_elem(0xE777, 0);
    bases.digest = setup_digest(n);
    return bases;
}

static void free_bases(Bases *bases) {
    free(bases->a);
    free(bases->b);
    free(bases->c);
    free(bases->ay);
    free(bases->by);
    memset(bases, 0, sizeof(*bases));
}

static u64 rng_field(u64 *rng) {
    return splitmix64(rng) % Q;
}

static u64 rng_small(u64 *rng, u64 max_entry) {
    return splitmix64(rng) % max_entry;
}

static u64 dot_product(const u64 *a, const u64 *b, size_t len) {
    u64 acc = 0;
    for (size_t i = 0; i < len; i++) acc = addm(acc, mulm(a[i], b[i]));
    return acc;
}

static u64 dot_optional(const u64 *a, size_t a_off, const u64 *b, size_t b_off, size_t len) {
    if (!a || !b) return 0;
    u64 acc = 0;
    for (size_t i = 0; i < len; i++) acc = addm(acc, mulm(a[a_off + i], b[b_off + i]));
    return acc;
}

static u64 commit_vec(const u64 *values, const u64 *bases, size_t len, u64 blind_base, u64 blind) {
    u64 acc = dot_product(values, bases, len);
    /* Unconditional blinding: a zero blind contributes the identity, so the
     * commitment value is unchanged but no data-dependent branch is taken. */
    acc = addm(acc, mulm(blind_base, blind));
    return acc;
}

static void matmul_mod(const u64 *a, const u64 *b, u64 *c, size_t n) {
    memset(c, 0, n * n * sizeof(u64));
    for (size_t i = 0; i < n; i++) {
        for (size_t k = 0; k < n; k++) {
            u64 aik = a[i * n + k];
            for (size_t j = 0; j < n; j++) {
                size_t idx = i * n + j;
                c[idx] = addm(c[idx], mulm(aik, b[k * n + j]));
            }
        }
    }
}

static void generate_witness(Witness *witness, size_t n, u64 seed, u64 max_entry, int valid) {
    size_t nn = n * n;
    u64 rng = seed;
    witness->a = xcalloc_u64(nn);
    witness->b = xcalloc_u64(nn);
    witness->c = xcalloc_u64(nn);
    for (size_t i = 0; i < nn; i++) {
        witness->a[i] = rng_small(&rng, max_entry);
        witness->b[i] = rng_small(&rng, max_entry);
    }
    matmul_mod(witness->a, witness->b, witness->c, n);
    if (!valid) witness->c[0] = addm(witness->c[0], 1);
    witness->a_blind = 0;
    witness->b_blind = 0;
    witness->c_blind = 0;
}

static void free_witness(Witness *witness) {
    free(witness->a);
    free(witness->b);
    free(witness->c);
    memset(witness, 0, sizeof(*witness));
}

static Statement commit_statement(const Bases *bases, Witness *witness, int blinded, u64 *rng) {
    if (blinded) {
        witness->a_blind = rng_field(rng);
        witness->b_blind = rng_field(rng);
        witness->c_blind = rng_field(rng);
    }
    Statement statement;
    statement.n = bases->n;
    statement.a_commit = commit_vec(witness->a, bases->a, bases->nn, bases->blind, witness->a_blind);
    statement.b_commit = commit_vec(witness->b, bases->b, bases->nn, bases->blind, witness->b_blind);
    statement.c_commit = commit_vec(witness->c, bases->c, bases->nn, bases->blind, witness->c_blind);
    return statement;
}

static void compute_powers(u64 base, u64 *out, size_t len) {
    u64 cur = 1;
    for (size_t i = 0; i < len; i++) {
        out[i] = cur;
        cur = mulm(cur, base);
    }
}

static void compute_projections(
    const Bases *bases, const Witness *witness, const Statement *statement,
    u64 **yvec_out, u64 **yl_out, u64 **yr_out,
    u64 **ay_out, u64 **by_out, u64 *d_out
) {
    size_t n = bases->n;
    size_t nn = bases->nn;
    u64 y = challenge_statement(dom(bases, 0x1001), n, statement->a_commit, statement->b_commit, statement->c_commit);
    u64 *yvec = xcalloc_u64(nn);
    u64 *yl = xcalloc_u64(n);
    u64 *yr = xcalloc_u64(n);
    u64 *ay = xcalloc_u64(n);
    u64 *by = xcalloc_u64(n);
    compute_powers(y, yvec, nn);
    compute_powers(y, yr, n);
    for (size_t i = 0; i < n; i++) yl[i] = yvec[i * n];
    for (size_t j = 0; j < n; j++) {
        u64 acc = 0;
        for (size_t i = 0; i < n; i++) acc = addm(acc, mulm(yl[i], witness->a[i * n + j]));
        ay[j] = acc;
    }
    for (size_t i = 0; i < n; i++) {
        u64 acc = 0;
        for (size_t j = 0; j < n; j++) acc = addm(acc, mulm(witness->b[i * n + j], yr[j]));
        by[i] = acc;
    }
    *d_out = dot_product(witness->c, yvec, nn);
    *yvec_out = yvec;
    *yl_out = yl;
    *yr_out = yr;
    *ay_out = ay;
    *by_out = by;
}

/* Combined projection bases with the output family scaled by the fresh
 * decoupling challenge (paper Algorithms 2-3: x * C_out (+) C_in). */
static u64 *a_projection_bases(const Bases *bases, const u64 *yl, u64 scale) {
    size_t n = bases->n;
    u64 *out = xcalloc_u64(bases->nn);
    for (size_t i = 0; i < n; i++) {
        u64 coeff = mulm(scale, yl[i]);
        for (size_t j = 0; j < n; j++) {
            size_t idx = i * n + j;
            out[idx] = addm(bases->a[idx], mulm(coeff, bases->ay[j]));
        }
    }
    return out;
}

static u64 *b_projection_bases(const Bases *bases, const u64 *yr, u64 scale) {
    size_t n = bases->n;
    u64 *out = xcalloc_u64(bases->nn);
    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            size_t idx = i * n + j;
            out[idx] = addm(bases->b[idx], mulm(mulm(scale, yr[j]), bases->by[i]));
        }
    }
    return out;
}

static IpProof prove_ip(
    size_t input_n, u64 commitment, u64 scalar_base,
    const u64 *g_in, const u64 *h_in, const u64 *a_in, const u64 *b_in,
    u64 domain
) {
    IpProof proof;
    proof.n = next_power_of_two(input_n);
    proof.rounds = log2_power_of_two(proof.n);
    proof.left = xcalloc_u64(proof.rounds);
    proof.right = xcalloc_u64(proof.rounds);
    u64 *g = xcalloc_u64(proof.n);
    u64 *h = xcalloc_u64(proof.n);
    u64 *a = xcalloc_u64(proof.n);
    u64 *b = xcalloc_u64(proof.n);
    memcpy(g, g_in, input_n * sizeof(u64));
    if (h_in) memcpy(h, h_in, input_n * sizeof(u64));
    if (a_in) memcpy(a, a_in, input_n * sizeof(u64));
    if (b_in) memcpy(b, b_in, input_n * sizeof(u64));

    size_t len = proof.n;
    u64 current = commitment;
    for (size_t round = 0; round < proof.rounds; round++) {
        size_t half = len / 2;
        u64 left_cross = dot_optional(a, 0, b, half, half);
        u64 right_cross = dot_optional(a, half, b, 0, half);
        u64 left = addm(
            addm(dot_optional(a, 0, g, half, half), dot_optional(b, half, h, 0, half)),
            mulm(scalar_base, left_cross)
        );
        u64 right = addm(
            addm(dot_optional(a, half, g, 0, half), dot_optional(b, 0, h, half, half)),
            mulm(scalar_base, right_cross)
        );
        u64 x = challenge6(domain, round, current, scalar_base, left, right);
        u64 xi = invm(x);
        for (size_t i = 0; i < half; i++) {
            a[i] = addm(a[i], mulm(xi, a[half + i]));
            b[i] = addm(b[i], mulm(x, b[half + i]));
            g[i] = addm(g[i], mulm(x, g[half + i]));
            h[i] = addm(h[i], mulm(xi, h[half + i]));
        }
        current = addm(addm(mulm(x, left), current), mulm(xi, right));
        proof.left[round] = left;
        proof.right[round] = right;
        len = half;
    }
    proof.a_final = a[0];
    proof.b_final = b[0];
    free(g);
    free(h);
    free(a);
    free(b);
    return proof;
}

static int verify_ip(
    size_t input_n, u64 commitment, u64 scalar_base,
    const u64 *g_in, const u64 *h_in, const IpProof *proof, u64 domain
) {
    if (proof->n != next_power_of_two(input_n)) return 0;
    if (proof->rounds != log2_power_of_two(proof->n)) return 0;
    u64 *g = xcalloc_u64(proof->n);
    u64 *h = xcalloc_u64(proof->n);
    memcpy(g, g_in, input_n * sizeof(u64));
    if (h_in) memcpy(h, h_in, input_n * sizeof(u64));
    size_t len = proof->n;
    u64 current = commitment;
    for (size_t round = 0; round < proof->rounds; round++) {
        size_t half = len / 2;
        u64 left = proof->left[round];
        u64 right = proof->right[round];
        u64 x = challenge6(domain, round, current, scalar_base, left, right);
        u64 xi = invm(x);
        for (size_t i = 0; i < half; i++) {
            g[i] = addm(g[i], mulm(x, g[half + i]));
            h[i] = addm(h[i], mulm(xi, h[half + i]));
        }
        current = addm(addm(mulm(x, left), current), mulm(xi, right));
        len = half;
    }
    u64 expected = addm(
        addm(mulm(scalar_base, mulm(proof->a_final, proof->b_final)), mulm(g[0], proof->a_final)),
        mulm(h[0], proof->b_final)
    );
    free(g);
    free(h);
    return current == expected;
}

static CoreProof prove_core(const Bases *bases, const Statement *statement, const Witness *witness) {
    CoreProof proof;
    memset(&proof, 0, sizeof(proof));
    u64 *yvec, *yl, *yr, *ay, *by;
    u64 d;
    compute_projections(bases, witness, statement, &yvec, &yl, &yr, &ay, &by, &d);
    proof.d_commit = mulm(bases->scalar, d);
    proof.ay_commit = commit_vec(ay, bases->ay, bases->n, 0, 0);
    proof.by_commit = commit_vec(by, bases->by, bases->n, 0, 0);

    /* Fresh decoupling challenges, sampled after d/ay/by commitments. */
    u64 dec_items[3] = {proof.d_commit, proof.ay_commit, proof.by_commit};
    u64 xc = challenge_commitments(dom(bases, 0x5EC1), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    u64 xa = challenge_commitments(dom(bases, 0x5EC2), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    u64 xb = challenge_commitments(dom(bases, 0x5EC3), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    u64 xp = challenge_commitments(dom(bases, 0x5EC4), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);

    proof.c_proj = prove_ip(
        bases->nn, addm(mulm(xc, proof.d_commit), statement->c_commit), mulm(xc, bases->scalar),
        bases->c, NULL, witness->c, yvec, dom(bases, 0xC001)
    );
    u64 *apb = a_projection_bases(bases, yl, xa);
    proof.a_proj = prove_ip(
        bases->nn, addm(statement->a_commit, mulm(xa, proof.ay_commit)), 0,
        apb, NULL, witness->a, NULL, dom(bases, 0xA002)
    );
    u64 *bpb = b_projection_bases(bases, yr, xb);
    proof.b_proj = prove_ip(
        bases->nn, addm(statement->b_commit, mulm(xb, proof.by_commit)), 0,
        bpb, NULL, witness->b, NULL, dom(bases, 0xB003)
    );
    proof.product = prove_ip(
        bases->n, addm(mulm(xp, proof.d_commit), addm(proof.ay_commit, proof.by_commit)), mulm(xp, bases->scalar),
        bases->ay, bases->by, ay, by, dom(bases, 0xD004)
    );
    free(yvec);
    free(yl);
    free(yr);
    free(ay);
    free(by);
    free(apb);
    free(bpb);
    return proof;
}

static int verify_core(const Bases *bases, const Statement *statement, const CoreProof *proof) {
    u64 y = challenge_statement(dom(bases, 0x1001), bases->n, statement->a_commit, statement->b_commit, statement->c_commit);
    u64 *yvec = xcalloc_u64(bases->nn);
    u64 *yl = xcalloc_u64(bases->n);
    u64 *yr = xcalloc_u64(bases->n);
    compute_powers(y, yvec, bases->nn);
    compute_powers(y, yr, bases->n);
    for (size_t i = 0; i < bases->n; i++) yl[i] = yvec[i * bases->n];
    u64 dec_items[3] = {proof->d_commit, proof->ay_commit, proof->by_commit};
    u64 xc = challenge_commitments(dom(bases, 0x5EC1), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    u64 xa = challenge_commitments(dom(bases, 0x5EC2), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    u64 xb = challenge_commitments(dom(bases, 0x5EC3), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    u64 xp = challenge_commitments(dom(bases, 0x5EC4), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, dec_items, 3);
    int ok = verify_ip(
        bases->nn, addm(mulm(xc, proof->d_commit), statement->c_commit), mulm(xc, bases->scalar),
        bases->c, NULL, &proof->c_proj, dom(bases, 0xC001)
    );
    u64 *apb = a_projection_bases(bases, yl, xa);
    if (ok) ok = verify_ip(
        bases->nn, addm(statement->a_commit, mulm(xa, proof->ay_commit)), 0,
        apb, NULL, &proof->a_proj, dom(bases, 0xA002)
    );
    u64 *bpb = b_projection_bases(bases, yr, xb);
    if (ok) ok = verify_ip(
        bases->nn, addm(statement->b_commit, mulm(xb, proof->by_commit)), 0,
        bpb, NULL, &proof->b_proj, dom(bases, 0xB003)
    );
    if (ok) ok = verify_ip(
        bases->n, addm(mulm(xp, proof->d_commit), addm(proof->ay_commit, proof->by_commit)), mulm(xp, bases->scalar),
        bases->ay, bases->by, &proof->product, dom(bases, 0xD004)
    );
    free(yvec);
    free(yl);
    free(yr);
    free(apb);
    free(bpb);
    return ok;
}

static ZkProjectionProof prove_zk_public_ip(
    const Bases *bases, const Statement *statement,
    u64 input_commit, u64 output_commit,
    const u64 *input_values, const u64 *public_values,
    const u64 *input_bases, u64 output_base,
    u64 input_blind, u64 output_blind,
    size_t len, u64 domain, u64 *rng
) {
    ZkProjectionProof proof;
    memset(&proof, 0, sizeof(proof));
    u64 *alpha = xcalloc_u64(len);
    for (size_t i = 0; i < len; i++) alpha[i] = rng_field(rng);
    u64 projected_alpha = dot_product(alpha, public_values, len);
    u64 alpha_blind = rng_field(rng);
    u64 projected_alpha_blind = rng_field(rng);
    proof.mask_commit = commit_vec(alpha, input_bases, len, bases->blind, alpha_blind);
    proof.projected_mask_commit = addm(mulm(output_base, projected_alpha), mulm(bases->blind, projected_alpha_blind));
    u64 items[4] = {input_commit, output_commit, proof.mask_commit, proof.projected_mask_commit};
    u64 x = challenge_commitments(domain, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, items, 4);
    proof.response_blind = addm(input_blind, mulm(x, alpha_blind));
    proof.projected_response_blind = addm(output_blind, mulm(x, projected_alpha_blind));
    for (size_t i = 0; i < len; i++) alpha[i] = addm(input_values[i], mulm(x, alpha[i]));
    u64 masked_input = subm(addm(input_commit, mulm(x, proof.mask_commit)), mulm(bases->blind, proof.response_blind));
    u64 masked_output = subm(addm(output_commit, mulm(x, proof.projected_mask_commit)), mulm(bases->blind, proof.projected_response_blind));
    u64 sep_items[6] = {input_commit, output_commit, proof.mask_commit, proof.projected_mask_commit, proof.response_blind, proof.projected_response_blind};
    u64 xs = challenge_commitments(domain ^ 0x5EC0, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, sep_items, 6);
    proof.proof = prove_ip(len, addm(mulm(xs, masked_output), masked_input), mulm(xs, output_base), input_bases, NULL, alpha, public_values, domain ^ 0x9999);
    free(alpha);
    return proof;
}

static int verify_zk_public_ip(
    const Bases *bases, const Statement *statement,
    u64 input_commit, u64 output_commit,
    const u64 *public_values, const u64 *input_bases, u64 output_base,
    size_t len, const ZkProjectionProof *proof, u64 domain
) {
    (void)public_values;
    u64 items[4] = {input_commit, output_commit, proof->mask_commit, proof->projected_mask_commit};
    u64 x = challenge_commitments(domain, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, items, 4);
    u64 masked_input = subm(addm(input_commit, mulm(x, proof->mask_commit)), mulm(bases->blind, proof->response_blind));
    u64 masked_output = subm(addm(output_commit, mulm(x, proof->projected_mask_commit)), mulm(bases->blind, proof->projected_response_blind));
    u64 sep_items[6] = {input_commit, output_commit, proof->mask_commit, proof->projected_mask_commit, proof->response_blind, proof->projected_response_blind};
    u64 xs = challenge_commitments(domain ^ 0x5EC0, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, sep_items, 6);
    return verify_ip(len, addm(mulm(xs, masked_output), masked_input), mulm(xs, output_base), input_bases, NULL, &proof->proof, domain ^ 0x9999);
}

/* Combined bases for the masked projection relation with the output family
 * scaled by the decoupling challenge. */
static u64 *weighted_projection_bases(
    const Bases *bases, const u64 *input_bases, const u64 *output_bases,
    const u64 *coeffs, int axis_rows, u64 scale
) {
    size_t n = bases->n;
    u64 *out = xcalloc_u64(bases->nn);
    for (size_t i = 0; i < n; i++) {
        for (size_t j = 0; j < n; j++) {
            size_t idx = i * n + j;
            u64 coeff = axis_rows ? mulm(scale, coeffs[i]) : mulm(scale, coeffs[j]);
            u64 output_base = axis_rows ? output_bases[j] : output_bases[i];
            out[idx] = addm(input_bases[idx], mulm(coeff, output_base));
        }
    }
    return out;
}

static ZkProjectionProof prove_zk_projection(
    const Bases *bases, const Statement *statement,
    u64 input_commit, u64 output_commit,
    const u64 *input_values, const u64 *coeffs,
    const u64 *input_bases, const u64 *output_bases,
    u64 input_blind, u64 output_blind,
    int axis_rows, u64 domain, u64 *rng
) {
    size_t n = bases->n;
    ZkProjectionProof proof;
    memset(&proof, 0, sizeof(proof));
    u64 *alpha = xcalloc_u64(bases->nn);
    u64 *projected_alpha = xcalloc_u64(n);
    for (size_t i = 0; i < bases->nn; i++) alpha[i] = rng_field(rng);
    if (axis_rows) {
        for (size_t col = 0; col < n; col++) {
            u64 acc = 0;
            for (size_t row = 0; row < n; row++) acc = addm(acc, mulm(coeffs[row], alpha[row * n + col]));
            projected_alpha[col] = acc;
        }
    } else {
        for (size_t row = 0; row < n; row++) {
            u64 acc = 0;
            for (size_t col = 0; col < n; col++) acc = addm(acc, mulm(alpha[row * n + col], coeffs[col]));
            projected_alpha[row] = acc;
        }
    }
    u64 alpha_blind = rng_field(rng);
    u64 projected_alpha_blind = rng_field(rng);
    proof.mask_commit = commit_vec(alpha, input_bases, bases->nn, bases->blind, alpha_blind);
    proof.projected_mask_commit = commit_vec(projected_alpha, output_bases, n, bases->blind, projected_alpha_blind);
    u64 items[4] = {input_commit, output_commit, proof.mask_commit, proof.projected_mask_commit};
    u64 x = challenge_commitments(domain, n, statement->a_commit, statement->b_commit, statement->c_commit, items, 4);
    proof.response_blind = addm(input_blind, mulm(x, alpha_blind));
    proof.projected_response_blind = addm(output_blind, mulm(x, projected_alpha_blind));
    for (size_t i = 0; i < bases->nn; i++) alpha[i] = addm(input_values[i], mulm(x, alpha[i]));
    u64 masked_input = subm(addm(input_commit, mulm(x, proof.mask_commit)), mulm(bases->blind, proof.response_blind));
    u64 masked_output = subm(addm(output_commit, mulm(x, proof.projected_mask_commit)), mulm(bases->blind, proof.projected_response_blind));
    u64 sep_items[6] = {input_commit, output_commit, proof.mask_commit, proof.projected_mask_commit, proof.response_blind, proof.projected_response_blind};
    u64 xs = challenge_commitments(domain ^ 0x5EC0, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, sep_items, 6);
    u64 *projected_bases = weighted_projection_bases(bases, input_bases, output_bases, coeffs, axis_rows, xs);
    proof.proof = prove_ip(bases->nn, addm(masked_input, mulm(xs, masked_output)), 0, projected_bases, NULL, alpha, NULL, domain ^ 0x8888);
    free(projected_bases);
    free(alpha);
    free(projected_alpha);
    return proof;
}

static int verify_zk_projection(
    const Bases *bases, const Statement *statement,
    u64 input_commit, u64 output_commit,
    const u64 *input_bases, const u64 *output_bases,
    const u64 *coeffs, int axis_rows,
    const ZkProjectionProof *proof, u64 domain
) {
    u64 items[4] = {input_commit, output_commit, proof->mask_commit, proof->projected_mask_commit};
    u64 x = challenge_commitments(domain, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, items, 4);
    u64 masked_input = subm(addm(input_commit, mulm(x, proof->mask_commit)), mulm(bases->blind, proof->response_blind));
    u64 masked_output = subm(addm(output_commit, mulm(x, proof->projected_mask_commit)), mulm(bases->blind, proof->projected_response_blind));
    u64 sep_items[6] = {input_commit, output_commit, proof->mask_commit, proof->projected_mask_commit, proof->response_blind, proof->projected_response_blind};
    u64 xs = challenge_commitments(domain ^ 0x5EC0, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, sep_items, 6);
    u64 *projected_bases = weighted_projection_bases(bases, input_bases, output_bases, coeffs, axis_rows, xs);
    int ok = verify_ip(bases->nn, addm(masked_input, mulm(xs, masked_output)), 0, projected_bases, NULL, &proof->proof, domain ^ 0x8888);
    free(projected_bases);
    return ok;
}

static ZkProductProof prove_zk_product(
    const Bases *bases, const Statement *statement,
    u64 output_commit, u64 left_commit, u64 right_commit,
    const u64 *left_values, const u64 *right_values,
    u64 output_blind, u64 left_blind, u64 right_blind,
    u64 *rng
) {
    size_t n = bases->n;
    ZkProductProof proof;
    memset(&proof, 0, sizeof(proof));
    u64 *alpha = xcalloc_u64(n);
    u64 *beta = xcalloc_u64(n);
    for (size_t i = 0; i < n; i++) {
        alpha[i] = rng_field(rng);
        beta[i] = rng_field(rng);
    }
    u64 alpha_beta = dot_product(alpha, beta, n);
    u64 cross = addm(dot_product(alpha, right_values, n), dot_product(left_values, beta, n));
    u64 alpha_blind = rng_field(rng);
    u64 beta_blind = rng_field(rng);
    u64 cross_blind = rng_field(rng);
    u64 alpha_beta_blind = rng_field(rng);
    proof.alpha_commit = commit_vec(alpha, bases->ay, n, bases->blind, alpha_blind);
    proof.beta_commit = commit_vec(beta, bases->by, n, bases->blind, beta_blind);
    proof.cross_commit = addm(mulm(bases->scalar, cross), mulm(bases->blind, cross_blind));
    proof.alpha_beta_commit = addm(mulm(bases->scalar, alpha_beta), mulm(bases->blind, alpha_beta_blind));
    u64 items[7] = {output_commit, left_commit, right_commit, proof.alpha_commit, proof.beta_commit, proof.cross_commit, proof.alpha_beta_commit};
    u64 x = challenge_commitments(dom(bases, 0xD0D0), n, statement->a_commit, statement->b_commit, statement->c_commit, items, 7);
    u64 x2 = mulm(x, x);
    proof.left_response_blind = addm(left_blind, mulm(x, alpha_blind));
    proof.right_response_blind = addm(right_blind, mulm(x, beta_blind));
    proof.output_response_blind = addm(addm(output_blind, mulm(x, cross_blind)), mulm(x2, alpha_beta_blind));
    for (size_t i = 0; i < n; i++) {
        alpha[i] = addm(left_values[i], mulm(x, alpha[i]));
        beta[i] = addm(right_values[i], mulm(x, beta[i]));
    }
    u64 masked_left = subm(addm(left_commit, mulm(x, proof.alpha_commit)), mulm(bases->blind, proof.left_response_blind));
    u64 masked_right = subm(addm(right_commit, mulm(x, proof.beta_commit)), mulm(bases->blind, proof.right_response_blind));
    u64 masked_output = subm(addm(addm(output_commit, mulm(x, proof.cross_commit)), mulm(x2, proof.alpha_beta_commit)), mulm(bases->blind, proof.output_response_blind));
    u64 sep_items[10] = {output_commit, left_commit, right_commit, proof.alpha_commit, proof.beta_commit, proof.cross_commit, proof.alpha_beta_commit, proof.left_response_blind, proof.right_response_blind, proof.output_response_blind};
    u64 xs = challenge_commitments(dom(bases, 0xD0D0) ^ 0x5EC0, n, statement->a_commit, statement->b_commit, statement->c_commit, sep_items, 10);
    proof.proof = prove_ip(n, addm(mulm(xs, masked_output), addm(masked_left, masked_right)), mulm(xs, bases->scalar), bases->ay, bases->by, alpha, beta, dom(bases, 0xD0D1));
    free(alpha);
    free(beta);
    return proof;
}

static int verify_zk_product(
    const Bases *bases, const Statement *statement,
    u64 output_commit, u64 left_commit, u64 right_commit,
    const ZkProductProof *proof
) {
    u64 items[7] = {output_commit, left_commit, right_commit, proof->alpha_commit, proof->beta_commit, proof->cross_commit, proof->alpha_beta_commit};
    u64 x = challenge_commitments(dom(bases, 0xD0D0), bases->n, statement->a_commit, statement->b_commit, statement->c_commit, items, 7);
    u64 x2 = mulm(x, x);
    u64 masked_left = subm(addm(left_commit, mulm(x, proof->alpha_commit)), mulm(bases->blind, proof->left_response_blind));
    u64 masked_right = subm(addm(right_commit, mulm(x, proof->beta_commit)), mulm(bases->blind, proof->right_response_blind));
    u64 masked_output = subm(addm(addm(output_commit, mulm(x, proof->cross_commit)), mulm(x2, proof->alpha_beta_commit)), mulm(bases->blind, proof->output_response_blind));
    u64 sep_items[10] = {output_commit, left_commit, right_commit, proof->alpha_commit, proof->beta_commit, proof->cross_commit, proof->alpha_beta_commit, proof->left_response_blind, proof->right_response_blind, proof->output_response_blind};
    u64 xs = challenge_commitments(dom(bases, 0xD0D0) ^ 0x5EC0, bases->n, statement->a_commit, statement->b_commit, statement->c_commit, sep_items, 10);
    return verify_ip(bases->n, addm(mulm(xs, masked_output), addm(masked_left, masked_right)), mulm(xs, bases->scalar), bases->ay, bases->by, &proof->proof, dom(bases, 0xD0D1));
}

static ZkProof prove_zk(const Bases *bases, const Statement *statement, const Witness *witness, u64 *rng) {
    ZkProof proof;
    memset(&proof, 0, sizeof(proof));
    u64 *yvec, *yl, *yr, *ay, *by;
    u64 d;
    compute_projections(bases, witness, statement, &yvec, &yl, &yr, &ay, &by, &d);
    u64 d_blind = rng_field(rng);
    u64 ay_blind = rng_field(rng);
    u64 by_blind = rng_field(rng);
    proof.d_commit = addm(mulm(bases->scalar, d), mulm(bases->blind, d_blind));
    proof.ay_commit = commit_vec(ay, bases->ay, bases->n, bases->blind, ay_blind);
    proof.by_commit = commit_vec(by, bases->by, bases->n, bases->blind, by_blind);
    proof.c_proj = prove_zk_public_ip(
        bases, statement, statement->c_commit, proof.d_commit, witness->c, yvec,
        bases->c, bases->scalar, witness->c_blind, d_blind, bases->nn, dom(bases, 0xC101), rng
    );
    proof.a_proj = prove_zk_projection(
        bases, statement, statement->a_commit, proof.ay_commit, witness->a, yl,
        bases->a, bases->ay, witness->a_blind, ay_blind, 1, dom(bases, 0xA102), rng
    );
    proof.b_proj = prove_zk_projection(
        bases, statement, statement->b_commit, proof.by_commit, witness->b, yr,
        bases->b, bases->by, witness->b_blind, by_blind, 0, dom(bases, 0xB103), rng
    );
    proof.product = prove_zk_product(
        bases, statement, proof.d_commit, proof.ay_commit, proof.by_commit,
        ay, by, d_blind, ay_blind, by_blind, rng
    );
    free(yvec);
    free(yl);
    free(yr);
    free(ay);
    free(by);
    return proof;
}

static int verify_zk(const Bases *bases, const Statement *statement, const ZkProof *proof) {
    u64 y = challenge_statement(dom(bases, 0x1001), bases->n, statement->a_commit, statement->b_commit, statement->c_commit);
    u64 *yvec = xcalloc_u64(bases->nn);
    u64 *yl = xcalloc_u64(bases->n);
    u64 *yr = xcalloc_u64(bases->n);
    compute_powers(y, yvec, bases->nn);
    compute_powers(y, yr, bases->n);
    for (size_t i = 0; i < bases->n; i++) yl[i] = yvec[i * bases->n];
    int ok = verify_zk_public_ip(
        bases, statement, statement->c_commit, proof->d_commit, yvec, bases->c,
        bases->scalar, bases->nn, &proof->c_proj, dom(bases, 0xC101)
    );
    if (ok) ok = verify_zk_projection(
        bases, statement, statement->a_commit, proof->ay_commit,
        bases->a, bases->ay, yl, 1, &proof->a_proj, dom(bases, 0xA102)
    );
    if (ok) ok = verify_zk_projection(
        bases, statement, statement->b_commit, proof->by_commit,
        bases->b, bases->by, yr, 0, &proof->b_proj, dom(bases, 0xB103)
    );
    if (ok) ok = verify_zk_product(
        bases, statement, proof->d_commit, proof->ay_commit, proof->by_commit, &proof->product
    );
    free(yvec);
    free(yl);
    free(yr);
    return ok;
}

static int run_case(const char *mode, size_t n, u64 seed, int valid) {
    Bases bases = make_bases(n);
    Witness witness;
    generate_witness(&witness, n, seed, 64, valid);
    u64 rng = seed ^ 0x5151515151515151ULL;
    int is_zk = strcmp(mode, "zk") == 0;
    Statement statement = commit_statement(&bases, &witness, is_zk, &rng);
    int verified = 0;
    if (is_zk) {
        ZkProof proof = prove_zk(&bases, &statement, &witness, &rng);
        verified = verify_zk(&bases, &statement, &proof);
        free_zk(&proof);
    } else {
        CoreProof proof = prove_core(&bases, &statement, &witness);
        verified = verify_core(&bases, &statement, &proof);
        free_core(&proof);
    }
    free_witness(&witness);
    free_bases(&bases);
    return verified;
}

static void bench_one(const char *mode, size_t n, u64 seed) {
    Bases bases = make_bases(n);
    Witness witness;
    size_t nn = n * n;
    u64 rng_gen = seed;
    witness.a = xcalloc_u64(nn);
    witness.b = xcalloc_u64(nn);
    witness.c = xcalloc_u64(nn);
    for (size_t i = 0; i < nn; i++) {
        witness.a[i] = rng_small(&rng_gen, 64);
        witness.b[i] = rng_small(&rng_gen, 64);
    }
    double start = now_seconds();
    matmul_mod(witness.a, witness.b, witness.c, n);
    double matmul_s = now_seconds() - start;
    witness.a_blind = witness.b_blind = witness.c_blind = 0;
    u64 rng = seed ^ 0x5151515151515151ULL;
    int is_zk = strcmp(mode, "zk") == 0;
    Statement statement = commit_statement(&bases, &witness, is_zk, &rng);
    double prove_s = 0.0;
    double verify_s = 0.0;
    int verified = 0;
    if (is_zk) {
        start = now_seconds();
        ZkProof proof = prove_zk(&bases, &statement, &witness, &rng);
        prove_s = now_seconds() - start;
        start = now_seconds();
        verified = verify_zk(&bases, &statement, &proof);
        verify_s = now_seconds() - start;
        free_zk(&proof);
    } else {
        start = now_seconds();
        CoreProof proof = prove_core(&bases, &statement, &witness);
        prove_s = now_seconds() - start;
        start = now_seconds();
        verified = verify_core(&bases, &statement, &proof);
        verify_s = now_seconds() - start;
        free_core(&proof);
    }
    printf("%s,%zu,%.9f,%.9f,%.9f,%.3f,%s\n",
           mode, n, matmul_s, prove_s, verify_s, prove_s / matmul_s, verified ? "True" : "False");
    fflush(stdout);
    free_witness(&witness);
    free_bases(&bases);
}

static int self_test(void) {
    size_t sizes[] = {2, 4, 8, 16};
    const char *modes[] = {"core", "zk"};
    for (size_t mi = 0; mi < 2; mi++) {
        for (size_t si = 0; si < 4; si++) {
            int valid_ok = run_case(modes[mi], sizes[si], 1000 + sizes[si], 1);
            int invalid_ok = run_case(modes[mi], sizes[si], 2000 + sizes[si], 0);
            if (!valid_ok || invalid_ok) {
                fprintf(stderr, "self-test failed: mode=%s n=%zu valid=%d invalid=%d\n",
                        modes[mi], sizes[si], valid_ok, invalid_ok);
                return 1;
            }
        }
    }
    printf("self-test ok\n");
    return 0;
}

static void usage(const char *name) {
    fprintf(stderr,
            "usage:\n"
            "  %s self-test\n"
            "  %s case <core|zk> <n> <seed> <valid|invalid>\n"
            "  %s bench <core|zk> <n> [n...]\n",
            name, name, name);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        usage(argv[0]);
        return 1;
    }
    if (strcmp(argv[1], "self-test") == 0) return self_test();
    if (strcmp(argv[1], "case") == 0) {
        if (argc != 6) {
            usage(argv[0]);
            return 1;
        }
        const char *mode = argv[2];
        size_t n = (size_t)strtoull(argv[3], NULL, 10);
        u64 seed = (u64)strtoull(argv[4], NULL, 10);
        int valid = strcmp(argv[5], "valid") == 0;
        if (!(strcmp(mode, "core") == 0 || strcmp(mode, "zk") == 0) ||
            !(valid || strcmp(argv[5], "invalid") == 0)) {
            usage(argv[0]);
            return 1;
        }
        int verified = run_case(mode, n, seed, valid);
        printf("verified=%d\n", verified);
        return 0;
    }
    if (strcmp(argv[1], "bench") == 0) {
        if (argc < 4) {
            usage(argv[0]);
            return 1;
        }
        const char *mode = argv[2];
        if (!(strcmp(mode, "core") == 0 || strcmp(mode, "zk") == 0)) {
            usage(argv[0]);
            return 1;
        }
        printf("mode,n,exact_matmul_s,prove_s,verify_s,proof_over_exact_matmul,verified\n");
        for (int i = 3; i < argc; i++) {
            size_t n = (size_t)strtoull(argv[i], NULL, 10);
            bench_one(mode, n, 0xABC000 + (u64)n);
        }
        return 0;
    }
    usage(argv[0]);
    return 1;
}
