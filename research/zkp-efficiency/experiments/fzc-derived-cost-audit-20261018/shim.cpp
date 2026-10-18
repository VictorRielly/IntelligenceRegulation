// Serial CPU arithmetic/counting shim, not CUDA or native instruction evidence.
#include <cstdint>
#include <cstddef>
using u64=uint64_t;
constexpr u64 P=0xffffffff00000001ULL;
struct f2{u64 c0,c1;};
static u64 nm=0,na=0,ns=0,nread=0,nwrite=0;
static u64 gl_mul(u64 a,u64 b){nm++;return (u64)((unsigned __int128)a*b%P);}
static u64 gl_add(u64 a,u64 b){na++;return (u64)(((unsigned __int128)a+b)%P);}
static u64 gl_sub(u64 a,u64 b){ns++;return (u64)(((unsigned __int128)a+P-b)%P);}
static f2 f2_zero(){return {0,0};}
static f2 f2_add(f2 a,f2 b){return {gl_add(a.c0,b.c0),gl_add(a.c1,b.c1)};}
static f2 f2_sub(f2 a,f2 b){return {gl_sub(a.c0,b.c0),gl_sub(a.c1,b.c1)};}
static f2 f2_mul_base(f2 a,u64 b){return {gl_mul(a.c0,b),gl_mul(a.c1,b)};}
struct Dim{int x;};
static Dim blockIdx{0},threadIdx{0},blockDim{1};
#define __device__
#define __forceinline__ inline
#include "captured.hpp"
#include "candidate.hpp"
extern "C" void derive(u64* tabs,int L,int supp,int variant,int base,const u64* s,u64* counts){
 nm=na=ns=nread=nwrite=0; f2 weights[11];
 if(variant && supp) prepare_pad(s,weights);
 const u64 prep=nm;
 for(int i=0;i<L;i++) {
  threadIdx.x=i;
  if(!variant) {if(supp) fzs_derive_impl<true>(tabs,L,s);else fzs_derive_impl<false>(tabs,L,s);}
  else if(supp) {if(base) candidate_derive<true,true>(tabs,L,s,weights);else candidate_derive<true,false>(tabs,L,s,weights);}
  else {if(base) candidate_derive<false,true>(tabs,L,s,weights);else candidate_derive<false,false>(tabs,L,s,weights);}
 }
 counts[0]=nm;counts[1]=na;counts[2]=ns;counts[3]=nread;counts[4]=nwrite;counts[5]=prep;
}
