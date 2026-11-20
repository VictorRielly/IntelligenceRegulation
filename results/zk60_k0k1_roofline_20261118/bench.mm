// K0 / K1 roofline bench (2026-11-18). Standalone Objective-C++ on Metal.framework; timing by command-buffer GPU timestamps.
// Written for this folder; the dispatch geometry of K1 mirrors results/zk60_a27_app_20261107/kbench/main.rs (not edited),
// the dispatch geometry of the fold mirrors metal.rs dispatch_2d (2-D grid (half, k), threadgroup min(max, 256, half)).
//
//   bench k1 <lib.metal> <used.tabs> <kmax> <log_cap> <np> <reps> <warmups> <label>
//   bench k0 <k0.metal> <reps> <warmups>
//
// Every raw measurement is printed as a K1RAW / K0RAW line (milliseconds, GPU timestamps).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static constexpr uint64_t P = 0xFFFFFFFF00000001ULL;

struct RoundArgs { uint64_t nhalf; uint64_t cap; uint32_t eval_one; uint32_t nthreads; };
struct FoldDevArgs { uint64_t nhalf; uint64_t cap; uint64_t k; uint64_t roff; };

struct Rng {
    uint64_t s;
    explicit Rng(uint64_t seed) : s(seed) {}
    uint64_t next() { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s % P; }
};

static uint64_t mulmod(uint64_t a, uint64_t b) { return (uint64_t)(((unsigned __int128)a * b) % P); }
static uint64_t addmod(uint64_t a, uint64_t b) { unsigned __int128 r = (unsigned __int128)a + b; return (uint64_t)(r % P); }
static uint64_t submod(uint64_t a, uint64_t b) { return a >= b ? a - b : (uint64_t)(((unsigned __int128)a + P) - b); }

static id<MTLDevice> dev;
static id<MTLCommandQueue> q;

static id<MTLComputePipelineState> pipe_of(id<MTLLibrary> lib, const char* name) {
    id<MTLFunction> fn = [lib newFunctionWithName:[NSString stringWithUTF8String:name]];
    if (!fn) { fprintf(stderr, "missing function %s\n", name); exit(1); }
    NSError* e = nil;
    id<MTLComputePipelineState> p = [dev newComputePipelineStateWithFunction:fn error:&e];
    if (!p) { fprintf(stderr, "pipeline %s: %s\n", name, [[e localizedDescription] UTF8String]); exit(1); }
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

// ----------------------------------------------------------------------------------------------- K1
// one round of a K1/v13 style kernel; returns GPU ms
static double run_round(id<MTLComputePipelineState> pipe, id<MTLBuffer> tb, id<MTLBuffer> part, id<MTLBuffer> cf,
                        uint64_t half, uint64_t cap, uint32_t nthreads, uint32_t np) {
    RoundArgs args{half, cap, 0u, nthreads};
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:pipe];
    [enc setBuffer:tb offset:0 atIndex:0];
    [enc setBuffer:part offset:0 atIndex:1];
    [enc setBuffer:cf offset:0 atIndex:2];
    [enc setBytes:&args length:sizeof(args) atIndex:3];
    uint64_t grid = ((uint64_t(nthreads) + 31) / 32) * 32 * np;
    uint64_t tg = std::min<uint64_t>({(uint64_t)pipe.maxTotalThreadsPerThreadgroup, 64ULL, grid});
    [enc dispatchThreads:MTLSizeMake(grid, 1, 1) threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    return ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
}

// CPU reference of k_k1 (xor of every loaded word) for one round on a small case. part layout: (gid * 6 + d) * 2.
static void cpu_k1_ref(const std::vector<uint64_t>& tabs, const std::vector<int>& used, uint64_t cap, uint64_t nhalf,
                       uint32_t nthreads, uint32_t np, std::vector<uint64_t>& part, std::vector<char>& written) {
    const int D1 = 6;
    for (uint32_t gid = 0; gid < nthreads; ++gid) {
        for (uint32_t di = 0; di < np; ++di) {
            uint32_t d = di == 0 ? 0 : di + 1;
            uint64_t a0 = 0, a1 = 0;
            if (d != 1) {
                for (uint64_t i = gid; i < nhalf; i += nthreads) {
                    uint64_t x0 = 0, x1 = 0;
                    for (int ix : used) {
                        uint64_t lo = (uint64_t(ix) * cap + i) * 2, hi = (uint64_t(ix) * cap + i + nhalf) * 2;
                        if (d == 0) { x0 ^= tabs[lo]; x1 ^= tabs[lo + 1]; }
                        else if (d == 1) { x0 ^= tabs[hi]; x1 ^= tabs[hi + 1]; }
                        else { x0 ^= tabs[lo] ^ tabs[hi]; x1 ^= tabs[lo + 1] ^ tabs[hi + 1]; }
                    }
                    a0 ^= x0; a1 ^= x1;
                }
            }
            size_t o = (size_t(gid) * D1 + d) * 2;
            part[o] = a0; part[o + 1] = a1; written[o] = 1; written[o + 1] = 1;
        }
    }
}

static int k1_checks(id<MTLComputePipelineState> pk1, id<MTLComputePipelineState> pk1b, id<MTLComputePipelineState> pv13,
                     const std::vector<int>& used, uint32_t np, int kmax) {
    const uint64_t cap = 1024, nhalf = 256;
    int fails = 0;
    Rng rng(0x1234567ULL);
    std::vector<uint64_t> tabs(size_t(kmax) * cap * 2);
    for (auto& w : tabs) w = rng.next();
    std::vector<uint64_t> cfv(8192);
    for (auto& w : cfv) w = rng.next();
    id<MTLBuffer> tb = [dev newBufferWithBytes:tabs.data() length:tabs.size() * 8 options:MTLResourceStorageModeShared];
    id<MTLBuffer> cf = [dev newBufferWithBytes:cfv.data() length:cfv.size() * 8 options:MTLResourceStorageModeShared];
    const size_t part_words = 512 * 6 * 2;
    id<MTLBuffer> part = [dev newBufferWithLength:part_words * 8 options:MTLResourceStorageModeShared];
    uint32_t nts[2] = {256, 100};
    for (uint32_t nthreads : nts) {
        memset(part.contents, 0, part_words * 8);
        run_round(pk1, tb, part, cf, nhalf, cap, nthreads, np);
        std::vector<uint64_t> ref(part_words, 0);
        std::vector<char> wr(part_words, 0);
        cpu_k1_ref(tabs, used, cap, nhalf, nthreads, np, ref, wr);
        const uint64_t* got = (const uint64_t*)part.contents;
        size_t bad = 0, cmp = 0;
        for (size_t i = 0; i < part_words; ++i) {
            if (wr[i]) { ++cmp; if (got[i] != ref[i]) ++bad; }
            else if (got[i] != 0) ++bad;  // unwritten slots must stay untouched
        }
        printf("CHECK k_k1 vs CPU xor reference, nhalf %llu nthreads %u: %zu words compared, %zu mismatches\n",
               (unsigned long long)nhalf, nthreads, cmp, bad);
        if (bad) ++fails;
    }
    // k_k1 and k_k1b must depend on every table they load: flip one word in each table, the output must change
    struct { const char* name; id<MTLComputePipelineState> p; } ks[2] = {{"k_k1", pk1}, {"k_k1b", pk1b}};
    for (auto& k : ks) {
        memset(part.contents, 0, part_words * 8);
        run_round(k.p, tb, part, cf, nhalf, cap, 256, np);
        std::vector<uint64_t> base((uint64_t*)part.contents, (uint64_t*)part.contents + part_words);
        int unchanged = 0;
        uint64_t* tw = (uint64_t*)tb.contents;
        for (int ix : used) {
            for (int which = 0; which < 2; ++which) {
                // which 0: low c0 word of pair 3 (read at d == 0 and d >= 2); which 1: high c1 word of pair 3 (read at d >= 2)
                size_t w = which == 0 ? (size_t(ix) * cap + 3) * 2 : (size_t(ix) * cap + 3 + nhalf) * 2 + 1;
                uint64_t keep = tw[w];
                tw[w] = keep ^ 0x5A5Aull;
                memset(part.contents, 0, part_words * 8);
                run_round(k.p, tb, part, cf, nhalf, cap, 256, np);
                bool changed = memcmp(base.data(), part.contents, part_words * 8) != 0;
                tw[w] = keep;
                if (!changed) ++unchanged;
            }
        }
        printf("CHECK %s sensitivity: %zu table words flipped (one lo and one hi word per loaded table), %d had no effect on the output\n",
               k.name, used.size() * 2, unchanged);
        if (unchanged) ++fails;
    }
    // random-seed difference at the same shape for all three
    id<MTLComputePipelineState> all3[3] = {pk1, pk1b, pv13};
    const char* nm3[3] = {"k_k1", "k_k1b", "k_v13"};
    for (int k = 0; k < 3; ++k) {
        memset(part.contents, 0, part_words * 8);
        run_round(all3[k], tb, part, cf, nhalf, cap, 256, np);
        std::vector<uint64_t> a((uint64_t*)part.contents, (uint64_t*)part.contents + part_words);
        Rng r2(0x9999ULL);
        uint64_t* tw = (uint64_t*)tb.contents;
        std::vector<uint64_t> saved(tw, tw + tabs.size());
        for (size_t i = 0; i < tabs.size(); ++i) tw[i] = r2.next();
        memset(part.contents, 0, part_words * 8);
        run_round(all3[k], tb, part, cf, nhalf, cap, 256, np);
        bool differs = memcmp(a.data(), part.contents, part_words * 8) != 0;
        memcpy(tw, saved.data(), saved.size() * 8);
        printf("CHECK %s output differs when the input tables differ: %s\n", nm3[k], differs ? "yes" : "NO");
        if (!differs) ++fails;
    }
    return fails;
}

static int run_k1(int argc, char** argv) {
    if (argc < 10) { fprintf(stderr, "usage: bench k1 <lib.metal> <used.tabs> <kmax> <log_cap> <np> <reps> <warmups> <label>\n"); return 1; }
    std::string libp = argv[2], tabsp = argv[3];
    int kmax = atoi(argv[4]);
    int log_cap = atoi(argv[5]);
    uint32_t np = (uint32_t)atoi(argv[6]);
    int reps = atoi(argv[7]), warm = atoi(argv[8]);
    std::string label = argv[9];
    std::vector<int> used;
    { std::ifstream f(tabsp); int x; while (f >> x) used.push_back(x); }
    id<MTLLibrary> lib = lib_of(libp);
    id<MTLComputePipelineState> pv13 = pipe_of(lib, "k_v13"), pk1 = pipe_of(lib, "k_k1"), pk1b = pipe_of(lib, "k_k1b");
    printf("K1 %s: kmax %d, tables loaded %zu, cap 2^%d, np %u, max threads/tg v13 %lu k1 %lu k1b %lu\n", label.c_str(), kmax, used.size(),
           log_cap, np, (unsigned long)pv13.maxTotalThreadsPerThreadgroup, (unsigned long)pk1.maxTotalThreadsPerThreadgroup,
           (unsigned long)pk1b.maxTotalThreadsPerThreadgroup);
    int fails = k1_checks(pk1, pk1b, pv13, used, np, kmax);
    printf("K1 %s checks: %s\n", label.c_str(), fails ? "FAILED" : "all passed");
    if (fails) return 3;

    const uint64_t cap = 1ULL << log_cap;
    Rng rng(0x9e3779b97f4a7c15ULL);
    id<MTLBuffer> tb = [dev newBufferWithLength:size_t(kmax) * cap * 16 options:MTLResourceStorageModeShared];
    uint64_t* tw = (uint64_t*)tb.contents;
    for (size_t i = 0; i < size_t(kmax) * cap * 2; ++i) tw[i] = rng.next();
    std::vector<uint64_t> cfv(8192);
    for (auto& w : cfv) w = rng.next();
    id<MTLBuffer> cf = [dev newBufferWithBytes:cfv.data() length:cfv.size() * 8 options:MTLResourceStorageModeShared];
    const uint64_t d1 = 6;
    id<MTLBuffer> part = [dev newBufferWithLength:std::max<uint64_t>(1, std::min<uint64_t>(cap / 2, 1u << 17)) * d1 * 16 options:MTLResourceStorageModeShared];

    struct K { const char* name; id<MTLComputePipelineState> p; } ks[3] = {{"v13", pv13}, {"k1", pk1}, {"k1b", pk1b}};
    for (int rep = -warm; rep < reps; ++rep) {
        for (auto& k : ks) {
            std::string rounds;
            double total = 0;
            for (uint64_t half = cap / 4; half >= 1; half /= 2) {
                uint32_t nthreads = (uint32_t)std::min<uint64_t>(std::max<uint64_t>(half, 1), 1u << 17);
                double ms = run_round(k.p, tb, part, cf, half, cap, nthreads, np);
                total += ms;
                char b[32]; snprintf(b, sizeof b, "%s%.4f", rounds.empty() ? "" : ",", ms); rounds += b;
            }
            printf("K1RAW slot=%s rep=%d kernel=%s total_ms=%.4f rounds_ms=%s\n", label.c_str(), rep, k.name, total, rounds.c_str());
        }
        fflush(stdout);
    }
    return 0;
}

// ----------------------------------------------------------------------------------------------- K0
static double run_2d(id<MTLComputePipelineState> pipe, uint64_t w, uint64_t h, void (^bind)(id<MTLComputeCommandEncoder>)) {
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:pipe];
    bind(enc);
    uint64_t tg = std::min<uint64_t>({(uint64_t)pipe.maxTotalThreadsPerThreadgroup, 256ULL, std::max<uint64_t>(w, 1ULL)});
    [enc dispatchThreads:MTLSizeMake(w, h, 1) threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    return ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
}

static int k0_checks(id<MTLComputePipelineState> pfold, id<MTLComputePipelineState> pcpat, id<MTLComputePipelineState> pcvec) {
    const uint64_t cap = 256, half = 64, k = 3;
    Rng rng(0xABCDEFULL);
    std::vector<uint64_t> t(k * cap * 2);
    for (auto& w : t) w = rng.next();
    for (uint64_t i = 0; i < cap; ++i) t[(1 * cap + i) * 2 + 1] = 0;  // table 1 is a base table (c1 = 0): takes the d1 == 0 branch
    // a few pairs with equal imaginary parts in an extension table, to hit d1 == 0 with a non-base table too
    t[(2 * cap + 5) * 2 + 1] = t[(2 * cap + 5 + half) * 2 + 1];
    uint64_t r0 = rng.next(), r1 = rng.next();
    std::vector<uint64_t> rv = {r0, r1};
    id<MTLBuffer> rb = [dev newBufferWithBytes:rv.data() length:16 options:MTLResourceStorageModeShared];
    FoldDevArgs fa{half, cap, k, 0};
    id<MTLBuffer> tb = [dev newBufferWithBytes:t.data() length:t.size() * 8 options:MTLResourceStorageModeShared];
    run_2d(pfold, half, k, ^(id<MTLComputeCommandEncoder> e) {
        [e setBuffer:tb offset:0 atIndex:0]; [e setBytes:&fa length:sizeof fa atIndex:1]; [e setBuffer:rb offset:0 atIndex:2]; });
    std::vector<uint64_t> ref = t;
    for (uint64_t tt = 0; tt < k; ++tt)
        for (uint64_t i = 0; i < half; ++i) {
            size_t lo = (tt * cap + i) * 2, hi = (tt * cap + i + half) * 2;
            uint64_t l0 = t[lo], l1 = t[lo + 1], d0 = submod(t[hi], l0), d1 = submod(t[hi + 1], l1);
            // (r0 + r1 u)(d0 + d1 u), u^2 = 7, computed directly from the definition
            uint64_t m0 = addmod(mulmod(r0, d0), mulmod(7, mulmod(r1, d1)));
            uint64_t m1 = addmod(mulmod(r0, d1), mulmod(r1, d0));
            ref[lo] = addmod(l0, m0);
            ref[lo + 1] = addmod(l1, m1);
        }
    size_t bad = 0;
    const uint64_t* g = (const uint64_t*)tb.contents;
    for (size_t i = 0; i < t.size(); ++i) if (g[i] != ref[i]) ++bad;
    printf("CHECK k_fold_tables_dev3 vs CPU Fp2 reference (3 tables, 64 pairs, one base table, whole buffer %zu words): %zu mismatches\n", t.size(), bad);
    int fails = bad ? 1 : 0;

    // copy kernels against their obvious CPU result
    id<MTLBuffer> tb2 = [dev newBufferWithBytes:t.data() length:t.size() * 8 options:MTLResourceStorageModeShared];
    run_2d(pcpat, half, k, ^(id<MTLComputeCommandEncoder> e) {
        [e setBuffer:tb2 offset:0 atIndex:0]; [e setBytes:&fa length:sizeof fa atIndex:1]; [e setBuffer:rb offset:0 atIndex:2]; });
    std::vector<uint64_t> ref2 = t;
    for (uint64_t tt = 0; tt < k; ++tt)
        for (uint64_t i = 0; i < half; ++i) {
            size_t lo = (tt * cap + i) * 2, hi = (tt * cap + i + half) * 2;
            ref2[lo] = t[lo] ^ t[hi]; ref2[lo + 1] = t[lo + 1] ^ t[hi + 1];
        }
    bad = 0; g = (const uint64_t*)tb2.contents;
    for (size_t i = 0; i < t.size(); ++i) if (g[i] != ref2[i]) ++bad;
    printf("CHECK k_copy_pat vs CPU xor: %zu mismatches\n", bad);
    if (bad) ++fails;

    id<MTLBuffer> src = [dev newBufferWithBytes:t.data() length:t.size() * 8 options:MTLResourceStorageModeShared];
    id<MTLBuffer> dst = [dev newBufferWithLength:k * half * 16 options:MTLResourceStorageModeShared];
    run_2d(pcvec, half, k, ^(id<MTLComputeCommandEncoder> e) {
        [e setBuffer:src offset:0 atIndex:0]; [e setBuffer:dst offset:0 atIndex:1]; [e setBytes:&fa length:sizeof fa atIndex:2]; });
    bad = 0; g = (const uint64_t*)dst.contents;
    for (uint64_t tt = 0; tt < k; ++tt)
        for (uint64_t i = 0; i < half; ++i) {
            size_t lo = (tt * cap + i) * 2, hi = (tt * cap + i + half) * 2, o = (tt * half + i) * 2;
            if (g[o] != (t[lo] ^ t[hi]) || g[o + 1] != (t[lo + 1] ^ t[hi + 1])) ++bad;
        }
    printf("CHECK k_copy_vec vs CPU xor: %zu mismatches\n", bad);
    if (bad) ++fails;
    return fails;
}

static int run_k0(int argc, char** argv) {
    if (argc < 5) { fprintf(stderr, "usage: bench k0 <k0.metal> <reps> <warmups>\n"); return 1; }
    id<MTLLibrary> lib = lib_of(argv[2]);
    int reps = atoi(argv[3]), warm = atoi(argv[4]);
    id<MTLComputePipelineState> pfold = pipe_of(lib, "k_fold_tables_dev3"), pcpat = pipe_of(lib, "k_copy_pat"), pcvec = pipe_of(lib, "k_copy_vec");
    printf("K0 max threads/tg fold %lu copy_pat %lu copy_vec %lu\n", (unsigned long)pfold.maxTotalThreadsPerThreadgroup,
           (unsigned long)pcpat.maxTotalThreadsPerThreadgroup, (unsigned long)pcvec.maxTotalThreadsPerThreadgroup);
    int fails = k0_checks(pfold, pcpat, pcvec);
    printf("K0 checks: %s\n", fails ? "FAILED" : "all passed");
    if (fails) return 3;

    // slot 18 (W16R2_8B) window 1: 22 tables, cap 2^21, half 2^20 pairs
    const uint64_t cap = 1ULL << 21, half = cap / 2, K = 22, NBASE = 10;
    const size_t words = size_t(K) * cap * 2;
    id<MTLBuffer> src = [dev newBufferWithLength:words * 8 options:MTLResourceStorageModeShared];   // pristine all-extension tables
    id<MTLBuffer> tabs = [dev newBufferWithLength:words * 8 options:MTLResourceStorageModeShared];  // working copy (folded in place)
    id<MTLBuffer> dst = [dev newBufferWithLength:size_t(K) * half * 16 options:MTLResourceStorageModeShared];
    Rng rng(0x9e3779b97f4a7c15ULL);
    uint64_t* sp = (uint64_t*)src.contents;
    for (size_t i = 0; i < words; ++i) sp[i] = rng.next();
    uint64_t rv[2] = {rng.next(), rng.next()};
    id<MTLBuffer> rb = [dev newBufferWithBytes:rv length:16 options:MTLResourceStorageModeShared];
    FoldDevArgs fa{half, cap, K, 0};
    const double rd = double(K * half * 32), wr = double(K * half * 16);
    printf("K0 shape: %llu tables, cap 2^21, %llu pairs per table; fold reads %.0f B, writes %.0f B\n", (unsigned long long)K,
           (unsigned long long)half, rd, wr);

    auto reinit = [&](bool mixed) {
        memcpy(tabs.contents, src.contents, words * 8);
        if (mixed) {
            uint64_t* tp = (uint64_t*)tabs.contents;
            for (uint64_t t = 0; t < NBASE; ++t) for (uint64_t i = 0; i < cap; ++i) tp[(t * cap + i) * 2 + 1] = 0;
        }
    };
    const char* names[4] = {"fold_ext", "copy_pat", "copy_vec", "fold_mixed"};
    for (int rep = -warm; rep < reps; ++rep) {
        for (int k = 0; k < 4; ++k) {
            reinit(k == 3);
            double ms;
            if (k == 0 || k == 3) {
                ms = run_2d(pfold, half, K, ^(id<MTLComputeCommandEncoder> e) {
                    [e setBuffer:tabs offset:0 atIndex:0]; [e setBytes:&fa length:sizeof fa atIndex:1]; [e setBuffer:rb offset:0 atIndex:2]; });
            } else if (k == 1) {
                ms = run_2d(pcpat, half, K, ^(id<MTLComputeCommandEncoder> e) {
                    [e setBuffer:tabs offset:0 atIndex:0]; [e setBytes:&fa length:sizeof fa atIndex:1]; [e setBuffer:rb offset:0 atIndex:2]; });
            } else {
                ms = run_2d(pcvec, half, K, ^(id<MTLComputeCommandEncoder> e) {
                    [e setBuffer:src offset:0 atIndex:0]; [e setBuffer:dst offset:0 atIndex:1]; [e setBytes:&fa length:sizeof fa atIndex:2]; });
            }
            printf("K0RAW rep=%d kernel=%s ms=%.4f\n", rep, names[k], ms);
        }
        fflush(stdout);
    }
    // keep the compiler/OS honest: print a checksum of the working copy and destination
    uint64_t x = 0;
    const uint64_t* d = (const uint64_t*)dst.contents;
    for (size_t i = 0; i < size_t(K) * half * 2; i += 4093) x ^= d[i];
    printf("K0 dst checksum %llx\n", (unsigned long long)x);
    return 0;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        dev = MTLCreateSystemDefaultDevice();
        if (!dev) { fprintf(stderr, "no Metal device\n"); return 1; }
        q = [dev newCommandQueue];
        printf("device %s\n", [[dev name] UTF8String]);
        if (argc < 2) return 1;
        std::string mode = argv[1];
        if (mode == "k1") return run_k1(argc, argv);
        if (mode == "k0") return run_k0(argc, argv);
        fprintf(stderr, "mode k0 or k1\n");
        return 1;
    }
}
