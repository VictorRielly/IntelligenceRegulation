// Local native-primitives mirror plus locally authored root plan action.
#include <cstddef>
#define __device__
#define __forceinline__ inline
inline unsigned long long __umul64hi(unsigned long long a, unsigned long long b) {
    return (static_cast<unsigned __int128>(a)*b)>>64;
}
#include "native/primitives.cuh"
static unsigned long long root_general_calls=0, root_shift_calls=0, root_word_reads=0;
#define ROOT_COUNT(name) (++name)
#include "root_action.proposed.cuh"
extern "C" u64 action(u64 a, const u64* low, u32 s, u32 k, int inv) {
    return root_action(a,low,s,k,inv != 0);
}
extern "C" u64 shift_action(u64 a, u32 e) { return root_shift(a,e); }
extern "C" u64 parts_action(u64 a, u64 low, int has_low, u32 high, int inv) {
    return root_apply_parts(a,low,has_low!=0,high,inv!=0);
}
extern "C" void counters(u64* out, int reset) {
    out[0]=root_general_calls; out[1]=root_shift_calls; out[2]=root_word_reads;
    if(reset) root_general_calls=root_shift_calls=root_word_reads=0;
}
extern "C" int transform(const u64* src, size_t nsrc, u32 lg, const u64* roots,
                          u64* a, int inv, u32 skipped, int compressed) {
    if(lg>16 || skipped>lg || nsrc>(size_t(1)<<lg) || !nsrc) return -1;
    const size_t n=size_t(1)<<lg;
    for(size_t i=0;i<n;++i) {
        size_t j=0,x=i;
        for(u32 b=0;b<lg;++b) { j=(j<<1)|(x&1); x>>=1; }
        a[i]=j<nsrc ? src[j] : 0;
    }
    // skipped>0 is valid only for the native aligned zero-pad input premise;
    // its skipped stages broadcast the one surviving entry in each group.
    if(skipped) for(size_t i=0;i<n;i+=(size_t(1)<<skipped))
        for(size_t j=1;j<(size_t(1)<<skipped);++j) a[i+j]=a[i];
    for(u32 st=skipped+1;st<=lg;++st) {
        const size_t half=size_t(1)<<(st-1);
        for(size_t begin=0;begin<n;begin+=2*half) for(size_t k=0;k<half;++k) {
            u64 u=a[begin+k];
            u64 v=compressed ? root_action(a[begin+k+half],roots,st,k,inv!=0)
                             : gl_mul(a[begin+k+half],roots[half-1+k]);
            a[begin+k]=gl_add(u,v); a[begin+k+half]=gl_sub(u,v);
        }
    }
    return 0;
}
