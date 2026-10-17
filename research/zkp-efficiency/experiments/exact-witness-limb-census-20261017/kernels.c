#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <limits.h>

/* Research-only, no external code. X is a checked norm/O8 plane, [-127,127].
 * W includes -128. All K coordinates, including supplied padding, participate.
 * orientation=0: W[output,input]; orientation=1: W[input,output].
 * Never apply this contract to h16 or to other wide planes.
 * Outputs stay i64; requant/range checks remain with the original caller.
 * Workspace and output allocations belong to caller in ALL timing arms. */
int mm(int variant, int orientation, size_t rows, size_t rowcap, size_t k,
       size_t n, size_t xs, size_t os, const int64_t *x,
       const int8_t *w, int8_t *packed, int64_t *out) {
    if (variant < 0 || variant > 2 || orientation < 0 || orientation > 1 ||
        rows > rowcap || xs < k || os < n) return -3;
    if (variant && k > INT32_MAX / (127 * 128)) return -1;
    if (variant) {
        for (size_t t=0; t<rows; ++t) for (size_t i=0; i<k; ++i) {
            int64_t v=x[t*xs+i];
            if (v < -127 || v > 127) return -2;
            packed[t*k+i]=(int8_t)v;
        }
    }
    memset(out,0,rowcap*os*sizeof(*out));
    for (size_t t=0; t<rows; ++t) {
        if (variant==0) {
            for (size_t j=0; j<n; ++j) {
                int64_t a=0;
                for (size_t i=0; i<k; ++i)
                    a+=x[t*xs+i]*(int64_t)w[orientation ? i*n+j : j*k+i];
                out[t*os+j]=a;
            }
        } else if (variant==1 || !orientation) {
            for (size_t j=0; j<n; ++j) {
                int32_t a=0;
                for (size_t i=0; i<k; ++i)
                    a+=(int32_t)packed[t*k+i]*(int32_t)w[orientation ? i*n+j : j*k+i];
                out[t*os+j]=(int64_t)a;
            }
        } else {
            for (size_t j0=0; j0<n; j0+=64) {
                int32_t acc[64]={0};
                size_t count=n-j0 < 64 ? n-j0 : 64;
                for (size_t i=0; i<k; ++i) {
                    const int8_t *wi=w+i*n+j0;
                    int32_t xi=(int32_t)packed[t*k+i];
                    for (size_t j=0; j<count; ++j) acc[j]+=xi*(int32_t)wi[j];
                }
                for (size_t j=0; j<count; ++j) out[t*os+j0+j]=(int64_t)acc[j];
            }
        }
    }
    return 0;
}
