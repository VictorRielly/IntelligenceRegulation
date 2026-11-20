// K3a / K3b / K4 bench (second run, 2026-11-18). Standalone Objective-C++ on Metal.framework; GPU timestamps per command buffer.
//
//   k3k4_bench k3 <lib.metal> <prog> <meta> <kmax> <log_cap> <np> <reps> <warmups> <label>
//   k3k4_bench k4 <k4.metal> <reps> <warmups>
//
// K3: kernels k_v13 (the shipped later-round kernel), k_k3a (K1b's loads + v13's product counts at low liveness),
//     k_bG_g (v13's polynomial split into G kernels, outputs added). Geometry as K1 (kbench/main.rs).
// K4: operation-cost kernels (throughput with eight independent chains per thread, and dependent chains).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

static constexpr uint64_t P = 0xFFFFFFFF00000001ULL;
struct RoundArgs { uint64_t nhalf; uint64_t cap; uint32_t eval_one; uint32_t nthreads; };

struct Rng {
    uint64_t s;
    explicit Rng(uint64_t seed) : s(seed) {}
    uint64_t next() { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s % P; }
};
static uint64_t mulmod(uint64_t a, uint64_t b) { return (uint64_t)(((unsigned __int128)a * b) % P); }
static uint64_t addmod(uint64_t a, uint64_t b) { return (uint64_t)(((unsigned __int128)a + b) % P); }
static uint64_t submod(uint64_t a, uint64_t b) { return a >= b ? a - b : (uint64_t)(((unsigned __int128)a + P) - b); }
struct F2 { uint64_t c0, c1; };
static F2 f2add(F2 a, F2 b) { return {addmod(a.c0, b.c0), addmod(a.c1, b.c1)}; }
static F2 f2mul(F2 a, F2 b) {
    return {addmod(mulmod(a.c0, b.c0), mulmod(7, mulmod(a.c1, b.c1))), addmod(mulmod(a.c0, b.c1), mulmod(a.c1, b.c0))};
}
static F2 f2mulb(F2 a, uint64_t b) { return {mulmod(a.c0, b), mulmod(a.c1, b)}; }

static id<MTLDevice> dev;
static id<MTLCommandQueue> q;

static id<MTLComputePipelineState> pipe_of(id<MTLLibrary> lib, const std::string& name) {
    id<MTLFunction> fn = [lib newFunctionWithName:[NSString stringWithUTF8String:name.c_str()]];
    if (!fn) { fprintf(stderr, "missing function %s\n", name.c_str()); exit(1); }
    NSError* e = nil;
    id<MTLComputePipelineState> p = [dev newComputePipelineStateWithFunction:fn error:&e];
    if (!p) { fprintf(stderr, "pipeline %s: %s\n", name.c_str(), [[e localizedDescription] UTF8String]); exit(1); }
    return p;
}
static id<MTLLibrary> lib_of(const std::string& path) {
    std::ifstream f(path);
    std::string src((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    NSError* e = nil;
    id<MTLLibrary> l = [dev newLibraryWithSource:[NSString stringWithUTF8String:src.c_str()] options:[[MTLCompileOptions alloc] init] error:&e];
    if (!l) { fprintf(stderr, "compile %s: %s\n", path.c_str(), [[e localizedDescription] UTF8String]); exit(1); }
    return l;
}

// ------------------------------------------------------------------------------------------------ K3
static double run_round_multi(const std::vector<id<MTLComputePipelineState>>& pipes, id<MTLBuffer> tb, const std::vector<id<MTLBuffer>>& parts,
                              id<MTLBuffer> cf, uint64_t half, uint64_t cap, uint32_t nthreads, uint32_t np) {
    RoundArgs args{half, cap, 0u, nthreads};
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    for (size_t g = 0; g < pipes.size(); ++g) {
        [enc setComputePipelineState:pipes[g]];
        [enc setBuffer:tb offset:0 atIndex:0];
        [enc setBuffer:parts[g] offset:0 atIndex:1];
        [enc setBuffer:cf offset:0 atIndex:2];
        [enc setBytes:&args length:sizeof(args) atIndex:3];
        uint64_t grid = ((uint64_t(nthreads) + 31) / 32) * 32 * np;
        uint64_t tg = std::min<uint64_t>({(uint64_t)pipes[g].maxTotalThreadsPerThreadgroup, 64ULL, grid});
        [enc dispatchThreads:MTLSizeMake(grid, 1, 1) threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
    }
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    return ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
}
static double run_round(id<MTLComputePipelineState> p, id<MTLBuffer> tb, id<MTLBuffer> part, id<MTLBuffer> cf, uint64_t half, uint64_t cap, uint32_t nt, uint32_t np) {
    return run_round_multi({p}, tb, {part}, cf, half, cap, nt, np);
}

struct Op { char kind; int a, b, c; char t; };  // LD m ix | EE k m t idx | EB k m idx | BB m idx
static std::vector<Op> load_prog(const std::string& path) {
    std::vector<Op> v;
    std::ifstream f(path);
    std::string line;
    while (std::getline(f, line)) {
        std::istringstream ss(line);
        std::string k; ss >> k;
        Op o{0, 0, 0, 0, 0};
        if (k == "LD") { o.kind = 'L'; ss >> o.a >> o.b; }
        else if (k == "EE") { o.kind = 'E'; std::string t; ss >> o.a >> o.b >> t >> o.c; o.t = t[0]; }
        else if (k == "EB") { o.kind = 'B'; ss >> o.a >> o.b >> o.c; }
        else if (k == "BB") { o.kind = 'D'; ss >> o.a >> o.b; }
        else continue;
        v.push_back(o);
    }
    return v;
}

// CPU reference of k_k3a for one round: part words (gid * 6 + d) * 2
static void cpu_k3a(const std::vector<uint64_t>& tabs, const std::vector<uint64_t>& cf, const std::vector<Op>& prog, uint64_t cap, uint64_t nhalf,
                    uint32_t nthreads, uint32_t np, std::vector<uint64_t>& part, std::vector<char>& wr) {
    for (uint32_t gid = 0; gid < nthreads; ++gid)
        for (uint32_t di = 0; di < np; ++di) {
            uint32_t d = di == 0 ? 0 : di + 1;
            F2 accT{0, 0};
            if (d != 1) {
                for (uint64_t i = gid; i < nhalf; i += nthreads) {
                    std::vector<F2> w(128);
                    F2 a[4] = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
                    uint64_t bacc = 0;
                    for (const Op& o : prog) {
                        if (o.kind == 'L') {
                            size_t lo = (uint64_t(o.b) * cap + i) * 2, hi = (uint64_t(o.b) * cap + i + nhalf) * 2;
                            F2 l{tabs[lo], tabs[lo + 1]}, h{tabs[hi], tabs[hi + 1]};
                            if (d == 0) w[o.a] = l;
                            else if (d == 1) w[o.a] = h;
                            else {
                                F2 st{submod(h.c0, l.c0), submod(h.c1, l.c1)};
                                w[o.a] = f2add(l, f2mulb(st, d));
                            }
                        } else if (o.kind == 'E') {
                            F2 other = o.t == 'v' ? w[o.c] : F2{cf[2 * o.c], cf[2 * o.c + 1]};
                            a[o.a] = f2add(a[o.a], f2mul(w[o.b], other));
                        } else if (o.kind == 'B') {
                            a[o.a] = f2add(a[o.a], f2mulb(w[o.b], cf[o.c]));
                        } else {
                            bacc = addmod(bacc, mulmod(w[o.a].c0, cf[o.b]));
                        }
                    }
                    F2 out = f2add(f2add(a[0], a[1]), f2add(a[2], a[3]));
                    out.c0 = addmod(out.c0, bacc);
                    accT = f2add(accT, out);
                }
            }
            size_t o = (size_t(gid) * 6 + d) * 2;
            part[o] = accT.c0; part[o + 1] = accT.c1; wr[o] = wr[o + 1] = 1;
        }
}

static std::vector<int> prog_tables(const std::vector<Op>& prog) {
    std::vector<int> t;
    for (const Op& o : prog) if (o.kind == 'L') t.push_back(o.b);
    return t;
}

static int k3a_checks(id<MTLComputePipelineState> p, const std::vector<Op>& prog, uint32_t np, int kmax) {
    const uint64_t cap = 1024, nhalf = 256;
    int fails = 0;
    Rng rng(0x7654321ULL);
    std::vector<uint64_t> tabs(size_t(kmax) * cap * 2), cfv(8192);
    for (auto& w : tabs) w = rng.next();
    for (auto& w : cfv) w = rng.next();
    id<MTLBuffer> tb = [dev newBufferWithBytes:tabs.data() length:tabs.size() * 8 options:MTLResourceStorageModeShared];
    id<MTLBuffer> cf = [dev newBufferWithBytes:cfv.data() length:cfv.size() * 8 options:MTLResourceStorageModeShared];
    const size_t pw = 512 * 6 * 2;
    id<MTLBuffer> part = [dev newBufferWithLength:pw * 8 options:MTLResourceStorageModeShared];
    uint32_t nts[2] = {256, 100};
    for (uint32_t nt : nts) {
        memset(part.contents, 0, pw * 8);
        run_round(p, tb, part, cf, nhalf, cap, nt, np);
        std::vector<uint64_t> ref(pw, 0);
        std::vector<char> wr(pw, 0);
        cpu_k3a(tabs, cfv, prog, cap, nhalf, nt, np, ref, wr);
        const uint64_t* got = (const uint64_t*)part.contents;
        size_t bad = 0, cmp = 0;
        for (size_t i = 0; i < pw; ++i) { if (wr[i]) { ++cmp; if (got[i] != ref[i]) ++bad; } else if (got[i]) ++bad; }
        printf("CHECK k_k3a vs CPU reference (exact field arithmetic), nhalf %llu nthreads %u: %zu words compared, %zu mismatches\n",
               (unsigned long long)nhalf, nt, cmp, bad);
        if (bad) ++fails;
    }
    // sensitivity: flipping one lo word and one hi word of every loaded table changes the output
    memset(part.contents, 0, pw * 8);
    run_round(p, tb, part, cf, nhalf, cap, 256, np);
    std::vector<uint64_t> base((uint64_t*)part.contents, (uint64_t*)part.contents + pw);
    uint64_t* tw = (uint64_t*)tb.contents;
    int unchanged = 0, flips = 0;
    for (int ix : prog_tables(prog)) {
        for (int which = 0; which < 2; ++which) {
            size_t w = which == 0 ? (size_t(ix) * cap + 3) * 2 : (size_t(ix) * cap + 3 + nhalf) * 2 + 1;
            uint64_t keep = tw[w];
            tw[w] = keep ^ 0x5A5Aull;
            memset(part.contents, 0, pw * 8);
            run_round(p, tb, part, cf, nhalf, cap, 256, np);
            if (memcmp(base.data(), part.contents, pw * 8) == 0) ++unchanged;
            tw[w] = keep;
            ++flips;
        }
    }
    printf("CHECK k_k3a sensitivity: %d table words flipped (one lo, one hi per loaded table), %d had no effect\n", flips, unchanged);
    if (unchanged) ++fails;
    return fails;
}

static int run_k3(int argc, char** argv) {
    if (argc < 11) { fprintf(stderr, "usage\n"); return 1; }
    std::string libp = argv[2], progp = argv[3], metap = argv[4];
    int kmax = atoi(argv[5]), log_cap = atoi(argv[6]);
    uint32_t np = (uint32_t)atoi(argv[7]);
    int reps = atoi(argv[8]), warm = atoi(argv[9]);
    std::string label = argv[10];
    std::vector<Op> prog = load_prog(progp);
    std::map<int, std::vector<std::string>> splits;
    { std::ifstream f(metap); std::string line; while (std::getline(f, line)) { std::istringstream ss(line); std::string k; int G; ss >> k >> G; std::string n; while (ss >> n) splits[G].push_back(n); } }
    id<MTLLibrary> lib = lib_of(libp);
    id<MTLComputePipelineState> pv13 = pipe_of(lib, "k_v13"), pk3a = pipe_of(lib, "k_k3a");
    std::map<int, std::vector<id<MTLComputePipelineState>>> sp;
    for (auto& kv : splits) for (auto& n : kv.second) sp[kv.first].push_back(pipe_of(lib, n));
    printf("K3 %s: kmax %d, K3a program %zu ops over %zu loaded tables, cap 2^%d, np %u; max threads/tg v13 %lu k3a %lu",
           label.c_str(), kmax, prog.size(), prog_tables(prog).size(), log_cap, np, (unsigned long)pv13.maxTotalThreadsPerThreadgroup,
           (unsigned long)pk3a.maxTotalThreadsPerThreadgroup);
    for (auto& kv : sp) { printf("; split%d:", kv.first); for (auto& p : kv.second) printf(" %lu", (unsigned long)p.maxTotalThreadsPerThreadgroup); }
    printf("\n");
    int fails = k3a_checks(pk3a, prog, np, kmax);

    const uint64_t cap = 1ULL << log_cap;
    Rng rng(0x9e3779b97f4a7c15ULL);
    id<MTLBuffer> tb = [dev newBufferWithLength:size_t(kmax) * cap * 16 options:MTLResourceStorageModeShared];
    uint64_t* tw = (uint64_t*)tb.contents;
    for (size_t i = 0; i < size_t(kmax) * cap * 2; ++i) tw[i] = rng.next();
    std::vector<uint64_t> cfv(8192);
    for (auto& w : cfv) w = rng.next();
    id<MTLBuffer> cf = [dev newBufferWithBytes:cfv.data() length:cfv.size() * 8 options:MTLResourceStorageModeShared];
    const uint64_t d1 = 6;
    const size_t part_bytes = std::max<uint64_t>(1, std::min<uint64_t>(cap / 2, 1u << 17)) * d1 * 16;
    std::vector<id<MTLBuffer>> parts, ref_part;
    for (int i = 0; i < 4; ++i) parts.push_back([dev newBufferWithLength:part_bytes options:MTLResourceStorageModeShared]);
    id<MTLBuffer> vpart = [dev newBufferWithLength:part_bytes options:MTLResourceStorageModeShared];

    // K3b exactness gate: sum of the G kernels' parts == v13's part, every word, every round of the full shape
    for (auto& kv : sp) {
        size_t bad = 0, words = 0;
        int rounds = 0;
        for (uint64_t half = cap / 4; half >= 1; half /= 2) {
            uint32_t nt = (uint32_t)std::min<uint64_t>(std::max<uint64_t>(half, 1), 1u << 17);
            for (auto& b : parts) memset(b.contents, 0, part_bytes);
            memset(vpart.contents, 0, part_bytes);
            run_round(pv13, tb, vpart, cf, half, cap, nt, np);
            std::vector<id<MTLBuffer>> pp(parts.begin(), parts.begin() + kv.second.size());
            run_round_multi(kv.second, tb, pp, cf, half, cap, nt, np);
            const uint64_t* v = (const uint64_t*)vpart.contents;
            for (size_t w = 0; w < part_bytes / 8; ++w) {
                uint64_t s = 0;
                for (auto& b : pp) s = addmod(s, ((const uint64_t*)b.contents)[w]);
                ++words;
                if (s != v[w]) ++bad;
            }
            ++rounds;
        }
        printf("CHECK split G=%d: sum of the %zu kernels' part buffers vs v13's, full shape, %d rounds, %zu words: %zu mismatches\n",
               kv.first, kv.second.size(), rounds, words, bad);
        if (bad) ++fails;
    }
    printf("K3 %s checks: %s\n", label.c_str(), fails ? "FAILED" : "all passed");
    fflush(stdout);
    if (fails) return 3;

    struct Arm { std::string name; std::vector<id<MTLComputePipelineState>> pipes; };
    std::vector<Arm> arms = {{"v13", {pv13}}, {"k3a", {pk3a}}, {"split2", sp[2]}, {"split4", sp[4]}};
    for (int rep = -warm; rep < reps; ++rep) {
        for (auto& arm : arms) {
            std::vector<id<MTLBuffer>> pp(parts.begin(), parts.begin() + arm.pipes.size());
            std::string rounds;
            double total = 0;
            for (uint64_t half = cap / 4; half >= 1; half /= 2) {
                uint32_t nt = (uint32_t)std::min<uint64_t>(std::max<uint64_t>(half, 1), 1u << 17);
                double ms = run_round_multi(arm.pipes, tb, pp, cf, half, cap, nt, np);
                total += ms;
                char b[32]; snprintf(b, sizeof b, "%s%.4f", rounds.empty() ? "" : ",", ms); rounds += b;
            }
            printf("K3RAW slot=%s rep=%d kernel=%s total_ms=%.4f rounds_ms=%s\n", label.c_str(), rep, arm.name.c_str(), total, rounds.c_str());
        }
        fflush(stdout);
    }
    return 0;
}

// ------------------------------------------------------------------------------------------------ K4
static uint64_t k4_u(uint32_t tid, uint64_t c, uint64_t a, uint64_t b, uint64_t z) {
    uint64_t v = uint64_t(tid) * a + c * b + z;
    return v >= P ? v - P : v;
}
static const uint64_t KA = 0x9E3779B97F4A7C15ULL, KB = 0xD1B54A32D192ED03ULL, KC = 0xBF58476D1CE4E5B9ULL, KD = 0x94D049BB133111EBULL,
                      KE = 0xA24BAED4963EE407ULL, KF = 0x9FB21C651E98DF25ULL;

static uint64_t cpu_k4(const std::string& kind, uint32_t tid, uint32_t rep, bool dependent) {
    int chains = dependent ? 1 : 8;
    uint64_t res = 0;
    bool ext = kind == "f2_mul" || kind == "f2_mulb";
    int steps = dependent ? (int)rep : (int)rep * 8;
    for (int c = 0; c < chains; ++c) {
        F2 x, y;
        if (!ext) { x = {k4_u(tid, c, KA, KB, 0), 0}; y = {k4_u(tid, c, KC, KD, 1), 0}; }
        else {
            x = {k4_u(tid, c, KA, KB, 0), k4_u(tid, c, KE, KF, 7)};
            y = {k4_u(tid, c, KC, KD, 1), k4_u(tid, c, KF, KA, 3)};
        }
        for (int s = 0; s < steps; ++s) {
            if (kind == "gl_add") x.c0 = addmod(x.c0, y.c0);
            else if (kind == "gl_mul") x.c0 = mulmod(x.c0, y.c0);
            else if (kind == "f2_mul") x = f2mul(x, y);
            else x = f2mulb(x, y.c0);
        }
        res ^= ext ? (x.c0 ^ x.c1) : x.c0;
    }
    return res;
}

static double run_k4(id<MTLComputePipelineState> p, id<MTLBuffer> out, uint32_t param, uint64_t threads, uint64_t tgmax) {
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:p];
    [enc setBuffer:out offset:0 atIndex:0];
    [enc setBytes:&param length:4 atIndex:1];
    uint64_t tg = std::min<uint64_t>({(uint64_t)p.maxTotalThreadsPerThreadgroup, tgmax, threads});
    [enc dispatchThreads:MTLSizeMake(threads, 1, 1) threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    return ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
}

static int run_k4(int argc, char** argv) {
    if (argc < 5) return 1;
    id<MTLLibrary> lib = lib_of(argv[2]);
    int reps = atoi(argv[3]), warm = atoi(argv[4]);
    const char* ths[4] = {"gl_add", "gl_mul", "f2_mul", "f2_mulb"};
    const char* dps[3] = {"gl_add", "gl_mul", "f2_mul"};
    std::map<std::string, id<MTLComputePipelineState>> pt, pd;
    for (auto n : ths) pt[n] = pipe_of(lib, std::string("k4_") + n);
    for (auto n : dps) pd[n] = pipe_of(lib, std::string("k4d_") + n);
    printf("K4 max threads/tg:");
    for (auto n : ths) printf(" %s %lu", n, (unsigned long)pt[n].maxTotalThreadsPerThreadgroup);
    for (auto n : dps) printf(" dep_%s %lu", n, (unsigned long)pd[n].maxTotalThreadsPerThreadgroup);
    printf("\n");
    // correctness: 256 threads against the CPU's exact arithmetic
    int fails = 0;
    id<MTLBuffer> small = [dev newBufferWithLength:256 * 8 options:MTLResourceStorageModeShared];
    for (auto n : ths) {
        memset(small.contents, 0, 256 * 8);
        run_k4(pt[n], small, 2, 256, 256);
        size_t bad = 0;
        for (uint32_t t = 0; t < 256; ++t) if (((uint64_t*)small.contents)[t] != cpu_k4(n, t, 2, false)) ++bad;
        printf("CHECK k4_%s (8 chains, rep 2, 256 threads) vs CPU: %zu mismatches\n", n, bad);
        if (bad) ++fails;
    }
    for (auto n : dps) {
        memset(small.contents, 0, 256 * 8);
        run_k4(pd[n], small, 50, 256, 256);
        size_t bad = 0;
        for (uint32_t t = 0; t < 256; ++t) if (((uint64_t*)small.contents)[t] != cpu_k4(n, t, 50, true)) ++bad;
        printf("CHECK k4d_%s (dependent chain n 50, 256 threads) vs CPU: %zu mismatches\n", n, bad);
        if (bad) ++fails;
    }
    printf("K4 checks: %s\n", fails ? "FAILED" : "all passed");
    fflush(stdout);
    if (fails) return 3;

    const uint64_t THREADS = 1ULL << 20;
    id<MTLBuffer> out = [dev newBufferWithLength:THREADS * 8 options:MTLResourceStorageModeShared];
    uint32_t t_reps[2] = {16, 128};
    uint32_t d_ns[2] = {16384, 65536};
    for (int rep = -warm; rep < reps; ++rep) {
        for (auto n : ths)
            for (uint32_t r : t_reps)
                printf("K4RAW rep=%d kind=thr op=%s param=%u ms=%.5f\n", rep, n, r, run_k4(pt[n], out, r, THREADS, 256));
        for (auto n : dps)
            for (uint32_t r : d_ns)
                printf("K4RAW rep=%d kind=dep op=%s param=%u ms=%.5f\n", rep, n, r, run_k4(pd[n], out, r, 32, 32));
        fflush(stdout);
    }
    return 0;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        dev = MTLCreateSystemDefaultDevice();
        if (!dev) return 1;
        q = [dev newCommandQueue];
        printf("device %s\n", [[dev name] UTF8String]);
        if (argc < 2) return 1;
        std::string mode = argv[1];
        if (mode == "k3") return run_k3(argc, argv);
        if (mode == "k4") return run_k4(argc, argv);
        return 1;
    }
}
