// K5 bench (third run, 2026-11-18). Standalone Objective-C++ on Metal.framework; GPU timestamps per command buffer.
//
//   k5_bench <lib.metal> <meta> <ntabs> <nxtabs> <log_cap> <np> <D1> <reps> <warmups> <label> <round0 0|1>
//
// arms from the meta file (written by k5_gen.py):
//   ARM name kernel               one kernel, one output buffer
//   SPLIT name k0 k1 ...          kernels with separate output buffers, summed on the host in the exactness gate
//   ACCUM name k0 k1 ...          kernels sharing one output buffer (kernel g > 0 adds in place)
//   K1TAB buf ix ext|base         the tables k_k1 loads (for its CPU reference)
// Every arm is gated: its output must equal k_v13's on every word of every timed round of the full shape (0 mismatches),
// else no timing is done. k_k1 is checked against a CPU xor reference and a one-word-per-table sensitivity test instead.
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
struct Rng {
    uint64_t s;
    explicit Rng(uint64_t seed) : s(seed) {}
    uint64_t next() { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return s % P; }
};
static uint64_t addmod(uint64_t a, uint64_t b) { return (uint64_t)(((unsigned __int128)a + b) % P); }

static id<MTLDevice> dev;
static id<MTLCommandQueue> q;
static uint32_t NP, D1;
static bool HAVE_X = false;

static id<MTLComputePipelineState> pipe_of(id<MTLLibrary> lib, const std::string& name) {
    id<MTLFunction> fn = [lib newFunctionWithName:[NSString stringWithUTF8String:name.c_str()]];
    if (!fn) { fprintf(stderr, "missing function %s\n", name.c_str()); exit(1); }
    NSError* e = nil;
    id<MTLComputePipelineState> p = [dev newComputePipelineStateWithFunction:fn error:&e];
    if (!p) { fprintf(stderr, "pipeline %s: %s\n", name.c_str(), [[e localizedDescription] UTF8String]); exit(1); }
    return p;
}

struct Arm {
    std::string name, kind;
    std::vector<std::string> kernels;
    std::vector<id<MTLComputePipelineState>> pipes;
    int nparts() const { return kind == "SPLIT" ? (int)pipes.size() : 1; }
};

static double run_arm_round(const Arm& arm, id<MTLBuffer> tb, id<MTLBuffer> xt, const std::vector<id<MTLBuffer>>& parts, id<MTLBuffer> cf,
                            uint64_t half, uint64_t cap, uint32_t nthreads) {
    RoundArgs args{half, cap, 0u, nthreads};
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    for (size_t g = 0; g < arm.pipes.size(); ++g) {
        [enc setComputePipelineState:arm.pipes[g]];
        [enc setBuffer:tb offset:0 atIndex:0];
        [enc setBuffer:(arm.kind == "SPLIT" ? parts[g] : parts[0]) offset:0 atIndex:1];
        [enc setBuffer:cf offset:0 atIndex:2];
        [enc setBytes:&args length:sizeof(args) atIndex:3];
        if (HAVE_X) [enc setBuffer:xt offset:0 atIndex:4];
        uint64_t grid = ((uint64_t(nthreads) + 31) / 32) * 32 * NP;
        uint64_t tg = std::min<uint64_t>({(uint64_t)arm.pipes[g].maxTotalThreadsPerThreadgroup, 64ULL, grid});
        [enc dispatchThreads:MTLSizeMake(grid, 1, 1) threadsPerThreadgroup:MTLSizeMake(tg, 1, 1)];
    }
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    return ([cb GPUEndTime] - [cb GPUStartTime]) * 1000.0;
}

struct K1Tab { int buf; int ix; bool ext; };

static int k1_checks(const Arm& k1, const std::vector<K1Tab>& ktabs, int nt, int nx) {
    const uint64_t cap = 1024, nhalf = 256;
    int fails = 0;
    Rng rng(0x1234567ULL);
    std::vector<uint64_t> tabs(size_t(std::max(nt, 1)) * cap * 2), xt(size_t(std::max(nx, 1)) * cap * 2), cfv(8192);
    for (auto& w : tabs) w = rng.next();
    for (auto& w : xt) w = rng.next();
    for (auto& w : cfv) w = rng.next();
    id<MTLBuffer> tb = [dev newBufferWithBytes:tabs.data() length:tabs.size() * 8 options:MTLResourceStorageModeShared];
    id<MTLBuffer> xb = [dev newBufferWithBytes:xt.data() length:xt.size() * 8 options:MTLResourceStorageModeShared];
    id<MTLBuffer> cf = [dev newBufferWithBytes:cfv.data() length:cfv.size() * 8 options:MTLResourceStorageModeShared];
    const size_t pw = 512 * D1 * 2;
    std::vector<id<MTLBuffer>> parts = {[dev newBufferWithLength:pw * 8 options:MTLResourceStorageModeShared]};
    uint32_t nts[2] = {256, 100};
    for (uint32_t nth : nts) {
        memset(parts[0].contents, 0, pw * 8);
        run_arm_round(k1, tb, xb, parts, cf, nhalf, cap, nth);
        std::vector<uint64_t> ref(pw, 0);
        std::vector<char> wr(pw, 0);
        for (uint32_t gid = 0; gid < nth; ++gid)
            for (uint32_t di = 0; di < NP; ++di) {
                uint32_t d = di == 0 ? 0 : di + 1;
                uint64_t a0 = 0, a1 = 0;
                if (d != 1)
                    for (uint64_t i = gid; i < nhalf; i += nth) {
                        uint64_t x0 = 0, x1 = 0;
                        for (const K1Tab& t : ktabs) {
                            const std::vector<uint64_t>& T = t.buf ? xt : tabs;
                            size_t lo = (uint64_t(t.ix) * cap + i) * 2, hi = (uint64_t(t.ix) * cap + i + nhalf) * 2;
                            if (t.ext) {
                                if (d == 0) { x0 ^= T[lo]; x1 ^= T[lo + 1]; } else { x0 ^= T[lo] ^ T[hi]; x1 ^= T[lo + 1] ^ T[hi + 1]; }
                            } else {
                                if (d == 0) x0 ^= T[lo]; else x0 ^= T[lo] ^ T[hi];
                            }
                        }
                        a0 ^= x0; a1 ^= x1;
                    }
                size_t o = (size_t(gid) * D1 + d) * 2;
                ref[o] = a0; ref[o + 1] = a1; wr[o] = wr[o + 1] = 1;
            }
        const uint64_t* got = (const uint64_t*)parts[0].contents;
        size_t bad = 0, cmp = 0;
        for (size_t i = 0; i < pw; ++i) { if (wr[i]) { ++cmp; if (got[i] != ref[i]) ++bad; } else if (got[i]) ++bad; }
        printf("CHECK k_k1 vs CPU xor reference, nhalf %llu nthreads %u: %zu words compared, %zu mismatches\n", (unsigned long long)nhalf, nth, cmp, bad);
        if (bad) ++fails;
    }
    memset(parts[0].contents, 0, pw * 8);
    run_arm_round(k1, tb, xb, parts, cf, nhalf, cap, 256);
    std::vector<uint64_t> base((uint64_t*)parts[0].contents, (uint64_t*)parts[0].contents + pw);
    int unchanged = 0, flips = 0;
    for (const K1Tab& t : ktabs) {
        uint64_t* tw = (uint64_t*)(t.buf ? xb : tb).contents;
        for (int which = 0; which < 2; ++which) {
            size_t w = which == 0 ? (uint64_t(t.ix) * cap + 3) * 2 : (uint64_t(t.ix) * cap + 3 + nhalf) * 2 + (t.ext ? 1 : 0);
            uint64_t keep = tw[w];
            tw[w] = keep ^ 0x5A5Aull;
            memset(parts[0].contents, 0, pw * 8);
            run_arm_round(k1, tb, xb, parts, cf, nhalf, cap, 256);
            if (memcmp(base.data(), parts[0].contents, pw * 8) == 0) ++unchanged;
            tw[w] = keep;
            ++flips;
        }
    }
    printf("CHECK k_k1 sensitivity: %d table words flipped (one lo and one hi word per loaded table), %d had no effect\n", flips, unchanged);
    if (unchanged) ++fails;
    return fails;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        if (argc < 12) { fprintf(stderr, "usage: see source\n"); return 1; }
        std::string libp = argv[1], metap = argv[2];
        int nt = atoi(argv[3]), nx = atoi(argv[4]), log_cap = atoi(argv[5]);
        NP = (uint32_t)atoi(argv[6]); D1 = (uint32_t)atoi(argv[7]);
        int reps = atoi(argv[8]), warm = atoi(argv[9]);
        std::string label = argv[10];
        bool round0 = atoi(argv[11]) != 0;
        HAVE_X = nx > 0;
        dev = MTLCreateSystemDefaultDevice();
        q = [dev newCommandQueue];
        printf("device %s\n", [[dev name] UTF8String]);

        std::ifstream lf(libp);
        std::string src((std::istreambuf_iterator<char>(lf)), std::istreambuf_iterator<char>());
        NSError* e = nil;
        id<MTLLibrary> lib = [dev newLibraryWithSource:[NSString stringWithUTF8String:src.c_str()] options:[[MTLCompileOptions alloc] init] error:&e];
        if (!lib) { fprintf(stderr, "compile: %s\n", [[e localizedDescription] UTF8String]); return 1; }

        std::vector<Arm> arms;
        std::vector<K1Tab> ktabs;
        {
            std::ifstream mf(metap);
            std::string line;
            while (std::getline(mf, line)) {
                std::istringstream ss(line);
                std::string kind; ss >> kind;
                if (kind == "K1TAB") { std::string b, t; int ix; ss >> b >> ix >> t; ktabs.push_back({b == "xtabs" ? 1 : 0, ix, t == "ext"}); continue; }
                Arm a; a.kind = kind;
                ss >> a.name;
                std::string k;
                while (ss >> k) { a.kernels.push_back(k); a.pipes.push_back(pipe_of(lib, k)); }
                arms.push_back(a);
            }
        }
        printf("K5 %s: %d tabs + %d xtabs, cap 2^%d, np %u, D1 %u, round0 %d, %zu arms, %zu K1 tables\n", label.c_str(), nt, nx, log_cap, NP, D1, round0 ? 1 : 0, arms.size(), ktabs.size());
        const Arm* v13 = nullptr; const Arm* k1 = nullptr;
        size_t maxparts = 1;
        for (auto& a : arms) { if (a.name == "v13") v13 = &a; if (a.name == "k1") k1 = &a; maxparts = std::max<size_t>(maxparts, a.nparts()); }
        int fails = k1_checks(*k1, ktabs, nt, nx);

        const uint64_t cap = 1ULL << log_cap;
        Rng rng(0x9e3779b97f4a7c15ULL);
        id<MTLBuffer> tb = [dev newBufferWithLength:size_t(nt) * cap * 16 options:MTLResourceStorageModeShared];
        id<MTLBuffer> xb = [dev newBufferWithLength:size_t(std::max(nx, 1)) * cap * 16 options:MTLResourceStorageModeShared];
        { uint64_t* w = (uint64_t*)tb.contents; for (size_t i = 0; i < size_t(nt) * cap * 2; ++i) w[i] = rng.next(); }
        { uint64_t* w = (uint64_t*)xb.contents; for (size_t i = 0; i < size_t(nx) * cap * 2; ++i) w[i] = rng.next(); }
        std::vector<uint64_t> cfv(8192);
        for (auto& w : cfv) w = rng.next();
        id<MTLBuffer> cf = [dev newBufferWithBytes:cfv.data() length:cfv.size() * 8 options:MTLResourceStorageModeShared];
        const size_t part_bytes = std::max<uint64_t>(1, std::min<uint64_t>(cap / 2, 1u << 17)) * D1 * 16;
        std::vector<id<MTLBuffer>> parts;
        for (size_t i = 0; i < maxparts; ++i) parts.push_back([dev newBufferWithLength:part_bytes options:MTLResourceStorageModeShared]);
        id<MTLBuffer> vpart = [dev newBufferWithLength:part_bytes options:MTLResourceStorageModeShared];

        std::vector<uint64_t> halves;
        if (round0) halves.push_back(cap / 2);
        else for (uint64_t h = cap / 4; h >= 1; h /= 2) halves.push_back(h);
        auto nth_of = [](uint64_t half) { return (uint32_t)std::min<uint64_t>(std::max<uint64_t>(half, 1), 1u << 17); };

        // exactness gate
        for (const Arm& a : arms) {
            if (a.name == "v13" || a.name == "k1") continue;
            size_t bad = 0, words = 0;
            for (uint64_t half : halves) {
                for (auto& b : parts) memset(b.contents, 0, part_bytes);
                memset(vpart.contents, 0, part_bytes);
                std::vector<id<MTLBuffer>> vp = {vpart};
                run_arm_round(*v13, tb, xb, vp, cf, half, cap, nth_of(half));
                run_arm_round(a, tb, xb, parts, cf, half, cap, nth_of(half));
                const uint64_t* v = (const uint64_t*)vpart.contents;
                for (size_t w = 0; w < part_bytes / 8; ++w) {
                    uint64_t s = 0;
                    for (int g = 0; g < a.nparts(); ++g) s = addmod(s, ((const uint64_t*)parts[g].contents)[w]);
                    ++words;
                    if (s != v[w]) ++bad;
                }
            }
            printf("CHECK arm %s (%s, %zu kernels): output vs v13, full shape, %zu rounds, %zu words: %zu mismatches\n", a.name.c_str(), a.kind.c_str(),
                   a.pipes.size(), halves.size(), words, bad);
            if (bad) ++fails;
        }
        printf("K5 %s checks: %s\n", label.c_str(), fails ? "FAILED" : "all passed");
        fflush(stdout);
        if (fails) return 3;

        for (int rep = -warm; rep < reps; ++rep) {
            for (const Arm& a : arms) {
                std::string rounds;
                double total = 0;
                for (uint64_t half : halves) {
                    double ms = run_arm_round(a, tb, xb, parts, cf, half, cap, nth_of(half));
                    total += ms;
                    char b[32]; snprintf(b, sizeof b, "%s%.4f", rounds.empty() ? "" : ",", ms); rounds += b;
                }
                printf("K5RAW slot=%s rep=%d arm=%s total_ms=%.4f rounds_ms=%s\n", label.c_str(), rep, a.name.c_str(), total, rounds.c_str());
            }
            fflush(stdout);
        }
    }
    return 0;
}
