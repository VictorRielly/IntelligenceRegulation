// Exact extracted CUDA loop bodies with a one-thread CPU control-flow shim.
// This does not compile CUDA, emulate its arithmetic instructions or measure GPU registers.
#include <cstdint>
#include <cstddef>
#include <cassert>
#include <vector>
#include <iostream>
#include <fstream>
using u64=uint64_t;using u128=__uint128_t;
constexpr u64 P=0xffffffff00000001ULL;
struct f2{u64 c0,c1;};
struct Dim{int x;};Dim blockIdx,blockDim,threadIdx;
#define __global__
f2 f2_zero(){return {0,0};}
f2 f2_add(f2 a,f2 b){return {u64((u128(a.c0)+b.c0)%P),u64((u128(a.c1)+b.c1)%P)};}
f2 f2_mul_base(f2 a,u64 b){return {u64(u128(a.c0)*b%P),u64(u128(a.c1)*b%P)};}
f2 ld_f2(const u64*p,size_t i){return {p[2*i],p[2*i+1]};}
void st_f2(u64*p,size_t i,f2 a){p[2*i]=a.c0;p[2*i+1]=a.c1;}
#include "kernels_host.cpp.inc"
u64 state=202610300155ULL;
u64 next(){state^=state<<13;state^=state>>7;state^=state<<17;return state;}
u64 canonical(){return u64(u128(next())%P);}
std::vector<u64> invoke(const std::vector<u64>& d,const std::vector<u64>& r,int rows,int n,int k,bool candidate){
 assert(k>=1&&k<=(candidate?5:4));assert(d.size()==size_t(rows*n));assert(r.size()==size_t(2*rows*k));
 std::vector<u64> out(2*k*n+16,123456789);blockDim.x=32;
 for(int j=0;j<((n+31)/32)*32;j++){
  blockIdx.x=j/32;threadIdx.x=j%32;
  if(candidate)candidate_fold_rows(d.data(),r.data(),out.data(),rows,n,k);
  else baseline_fold_rows(d.data(),r.data(),out.data(),rows,n,k);
 }
 for(size_t i=2*k*n;i<out.size();i++)assert(out[i]==123456789);
 out.resize(2*k*n);return out;
}
void array(std::ostream&o,const std::vector<u64>&v){o<<'[';for(size_t i=0;i<v.size();i++){if(i)o<<',';o<<v[i];}o<<']';}
int main(){
 size_t cases=0,limbs=0,vectors=0;u64 digest=0;std::ofstream tv("cpp-public-vectors.jsonl");
 for(int rows:{0,1,3,17,257})for(int n:{1,7,33})for(int k:{1,2,3,4,5})for(int mode=0;mode<5;mode++){
  std::vector<u64>d(rows*n),r(2*rows*k),want(2*k*n);
  for(auto&v:d)v=mode==3?P-1:canonical();
  for(int g=0;g<k;g++)for(int i=0;i<rows;i++){
   bool live=mode==0||mode==2||mode==3||g==k-1||(i+g)%7==0||i+3>=rows;
   if(live){r[2*(g*rows+i)]=mode==2?0:mode==3?P-1:canonical();r[2*(g*rows+i)+1]=mode==3?P-1:canonical();}
  }
  // Independent row-first oracle. Each product reduced before the sum.
  for(int i=0;i<rows;i++)for(int g=0;g<k;g++)for(int j=0;j<n;j++)for(int l=0;l<2;l++){
   size_t at=2*(g*n+j)+l;want[at]=u64((u128(want[at])+u64(u128(r[2*(g*rows+i)+l])*d[i*n+j]%P))%P);
  }
  auto b=invoke(d,r,rows,n,k,true);std::vector<u64>a;
  for(int off=0;off<k;off+=4){int count=std::min(4,k-off);std::vector<u64>rs(r.begin()+2*off*rows,r.begin()+2*(off+count)*rows);auto part=invoke(d,rs,rows,n,count,false);a.insert(a.end(),part.begin(),part.end());}
  assert(a==want&&b==want);cases++;limbs+=b.size();for(auto v:b)digest=(digest<<5|digest>>59)^v;
  if(rows==17&&n==7){tv<<"{\"rows\":"<<rows<<",\"n\":"<<n<<",\"k\":"<<k<<",\"mode\":"<<mode<<",\"data\":";array(tv,d);tv<<",\"rho\":";array(tv,r);tv<<",\"out\":";array(tv,b);tv<<"}\n";vectors++;}
 }
 std::cout<<"{\"status\":\"PASS\",\"fixtures\":"<<cases<<",\"scalar_limb_outputs\":"<<limbs<<",\"python_vector_fixtures\":"<<vectors<<",\"overlaunch_and_guard_checks\":"<<cases<<",\"digest\":\""<<std::hex<<digest<<"\",\"scope\":\"Exact extracted kernel max4/max5 bodies in CPU shim; no CUDA compilation or timing\"}\n";
}
