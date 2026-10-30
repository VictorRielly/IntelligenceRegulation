// CPU control-flow shim for the two exact extracted CUDA kernel bodies.
// This is not device compilation, a CUDA ABI test, or GPU timing evidence.
#include <cstdint>
#include <cstddef>
#include <cassert>
#include <vector>
#include <iostream>
using u64=uint64_t;
using u128=__uint128_t;
constexpr u64 P=0xffffffff00000001ULL;
struct f2{u64 c0,c1;};
bool operator==(f2 a,f2 b){return a.c0==b.c0&&a.c1==b.c1;}
struct Dim{int x;};
Dim blockIdx,blockDim,threadIdx;
#define __global__
f2 f2_zero(){return {0,0};}
f2 f2_add(f2 a,f2 b){return {u64((u128(a.c0)+b.c0)%P),u64((u128(a.c1)+b.c1)%P)};}
f2 f2_mul_base(f2 a,u64 b){return {u64(u128(a.c0)*b%P),u64(u128(a.c1)*b%P)};}
f2 ld_f2(const u64*p,size_t i){return {p[2*i],p[2*i+1]};}
void st_f2(u64*p,size_t i,f2 a){p[2*i]=a.c0;p[2*i+1]=a.c1;}
#include "kernels_host.cpp.inc"
u64 state=202610290147ULL;
u64 next(){state^=state<<13;state^=state>>7;state^=state<<17;return state;}
u64 canonical(){return u64(u128(next())%P);}
int main(){
 size_t cases=0,values=0,controls=0;u64 digest=0;
 for(int rows:{1,3,17})for(int n:{1,7,33})for(int k:{1,2,3,4})for(int mode=0;mode<8;mode++){
  std::vector<u64>data(rows*n),rho(2*rows*k),want(2*n*k),a(2*n*k,~0ULL),b=a;
  for(auto&v:data)v=canonical();
  for(int g=0;g<k;g++)for(int i=0;i<rows;i++){
   bool active=mode==0||(mode==2&&i%k==g)||(mode==3&&(i+g)%4==0)||(mode==4&&(g==k-1||i%k==g))||(mode==5&&i==rows-1)||(mode==6&&i==0)||(mode==7&&next()%8==0);
   if(active){rho[2*(g*rows+i)]=(i+g)%3==0?0:canonical();rho[2*(g*rows+i)+1]=canonical();}
  }
  // Row-first independently materializes every product; no zero checks.
  for(int i=0;i<rows;i++)for(int g=0;g<k;g++)for(int j=0;j<n;j++)for(int limb=0;limb<2;limb++){
   size_t at=2*(g*n+j)+limb;u64 v=u64(u128(rho[2*(g*rows+i)+limb])*data[i*n+j]%P);want[at]=u64((u128(want[at])+v)%P);
  }
  blockDim.x=32;
  // Also invoke overlaunch threads: actual CUDA j>=n guard must hold.
  for(int j=0;j<((n+31)/32)*32;j++){
   blockIdx.x=j/32;threadIdx.x=j%32;
   baseline_fold_rows(data.data(),rho.data(),a.data(),rows,n,k);
   candidate_fold_rows(data.data(),rho.data(),b.data(),rows,n,k);
  }
  assert(a==want&&b==want);cases++;values+=2*k*n;
  for(auto v:b)digest=(digest<<5|digest>>59)^v;
 }
 // The imaginary limb must participate in both the union and group predicate.
 std::vector<u64> data={7},rho={0,1},a(2),b(2);
 blockIdx.x=threadIdx.x=0;blockDim.x=32;
 baseline_fold_rows(data.data(),rho.data(),a.data(),1,1,1);
 candidate_fold_rows(data.data(),rho.data(),b.data(),1,1,1);
 assert(a==b&&b[0]==0&&b[1]==7);controls++;
 // A changed private word must still affect a live group, including mask rows.
 data[0]=11;candidate_fold_rows(data.data(),rho.data(),b.data(),1,1,1);assert(a!=b);controls++;
 // Unused tail lanes must not write outside the true k*n output.
 std::vector<u64> guarded(2+8,123456789);candidate_fold_rows(data.data(),rho.data(),guarded.data(),1,1,1);
 for(size_t i=2;i<guarded.size();i++)assert(guarded[i]==123456789);controls++;
 std::cout<<"{\"status\":\"PASS\",\"fixtures\":"<<cases<<",\"scalar_limb_outputs_compared\":"<<values<<",\"controls\":"<<controls<<",\"digest\":\""<<std::hex<<digest<<"\",\"scope\":\"Exact extracted original/candidate kernel bodies in CPU C++ shim, independent row-first modular reference; no device build/launch, register or performance evidence.\"}\n";
}
