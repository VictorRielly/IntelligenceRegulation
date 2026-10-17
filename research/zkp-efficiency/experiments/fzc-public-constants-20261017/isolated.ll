; ModuleID = 'isolated.f4c85602b064d7c4-cgu.0'
source_filename = "isolated.f4c85602b064d7c4-cgu.0"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%LkT = type { %"alloc::vec::Vec<(usize, field::Fp)>", %"field::Fp2" }
%"alloc::vec::Vec<(usize, field::Fp)>" = type { %"alloc::raw_vec::RawVec<(usize, field::Fp)>", i64 }
%"alloc::raw_vec::RawVec<(usize, field::Fp)>" = type { %"alloc::raw_vec::RawVecInner", %"core::marker::PhantomData<(usize, field::Fp)>" }
%"alloc::raw_vec::RawVecInner" = type { i64, ptr, %"alloc::alloc::Global" }
%"alloc::alloc::Global" = type {}
%"core::marker::PhantomData<(usize, field::Fp)>" = type {}
%"field::Fp2" = type { i64, i64 }
%"alloc::vec::Vec<(usize, field::Fp2)>" = type { %"alloc::raw_vec::RawVec<(usize, field::Fp2)>", i64 }
%"alloc::raw_vec::RawVec<(usize, field::Fp2)>" = type { %"alloc::raw_vec::RawVecInner", %"core::marker::PhantomData<(usize, field::Fp2)>" }
%"core::marker::PhantomData<(usize, field::Fp2)>" = type {}
%"core::mem::maybe_uninit::MaybeUninit<field::Fp2>" = type { [2 x i64] }

@alloc_0f470ba9a8dafd09cc9f4992af3b1f93 = private unnamed_addr constant [12 x i8] c"isolated.rs\00", align 1
@alloc_239c1709703ec0aea80b5578885ba055 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00`\01\00\00P\00\00\00" }>, align 8
@alloc_14e9b0f3c1e82842e326b949d03d992d = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\AF\01\00\00*\00\00\00" }>, align 8
@alloc_eca36810f664faabadbd931684be3603 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\AF\01\00\00%\00\00\00" }>, align 8
@alloc_826b68913cf630c35a865efbea8045e3 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\CE\01\00\00*\00\00\00" }>, align 8
@alloc_11ff538006900e8109ee309b459a2f83 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\CE\01\00\00%\00\00\00" }>, align 8
@alloc_623270749f7c2c7eb7abf12a5ce81bec = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\ED\01\00\00*\00\00\00" }>, align 8
@alloc_23cbb2e7863b02fb8b64518d13a27720 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\ED\01\00\00%\00\00\00" }>, align 8
@alloc_3473ff63602946e5bae196369fb1e157 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\0E\02\00\00*\00\00\00" }>, align 8
@alloc_8bedb038257b840dda514362a0f0e6d8 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\0E\02\00\00%\00\00\00" }>, align 8
@alloc_8a0667c067a77bb698bb88e8b54ac9d2 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\AB\01\00\00E\00\00\00" }>, align 8
@alloc_251b78bda4aeb9a619eb192d691b2e6c = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\B5\01\00\00\1D\00\00\00" }>, align 8
@alloc_03bbe1d0fcdbd86f2216092eb0f02e36 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\9C\01\00\00\18\00\00\00" }>, align 8
@alloc_60764c2be1deec61362b17f60211fd40 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\BE\01\00\00$\00\00\00" }>, align 8
@alloc_0115ca0cf6aba2d7c2ca2e69392e3726 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\BE\01\00\00,\00\00\00" }>, align 8
@alloc_7672b3fd58eaeff1a7f945549344b36b = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\BE\01\00\00L\00\00\00" }>, align 8
@alloc_0d7c3282f4d1b6d0ea38e377caef0ba7 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\BE\01\00\00T\00\00\00" }>, align 8
@alloc_85ee655d0ee76a931ab97ae7956c61fa = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\B7\01\00\00@\00\00\00" }>, align 8
@alloc_28926e658ad846032cbbfac196c44ac3 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\CA\01\00\00E\00\00\00" }>, align 8
@alloc_8c5249903caae8a4f890768ea185f763 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\D4\01\00\00\1D\00\00\00" }>, align 8
@alloc_0f40a973e4ef77172839bcec3485a3cf = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\DD\01\00\00$\00\00\00" }>, align 8
@alloc_7893f8279e457884a76b55b3c0e38bce = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\DD\01\00\00,\00\00\00" }>, align 8
@alloc_01d88d31381230f5daa9de4874523a4f = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\DD\01\00\00L\00\00\00" }>, align 8
@alloc_89fc8f3b37234d0552cb47d22f5f3be5 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\DD\01\00\00T\00\00\00" }>, align 8
@alloc_dd86d8d2da9777486edeb4de51cc3012 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\D6\01\00\00@\00\00\00" }>, align 8
@alloc_9ff3b8d94994bf8c3f90654c665568fa = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\E9\01\00\00E\00\00\00" }>, align 8
@alloc_33f4d218739df51bc601f47114eed12f = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\F3\01\00\00\1D\00\00\00" }>, align 8
@alloc_80ab1297b78c18879967432c54c1e54e = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\FE\01\00\00$\00\00\00" }>, align 8
@alloc_f604f896c68dd8f0a4007dacc23397d5 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\FE\01\00\00,\00\00\00" }>, align 8
@alloc_18a70e0bda0ee5b1c3fd14bc973a5c99 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\FE\01\00\00L\00\00\00" }>, align 8
@alloc_f3da9c566178cc480d49fd92cad34aad = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\FE\01\00\00T\00\00\00" }>, align 8
@alloc_783adf84c4437dc3f5e730641bb4655a = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\F5\01\00\00@\00\00\00" }>, align 8
@alloc_413c07112253bea69b9c0ea7f62d2d3b = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\0A\02\00\00E\00\00\00" }>, align 8
@alloc_d0a18ec8c4590cc3d9111a1a11b11099 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\14\02\00\00\1D\00\00\00" }>, align 8
@alloc_38b3a9f276003767a8ae4525b00c9940 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\1F\02\00\00$\00\00\00" }>, align 8
@alloc_95c9a529b9c6675768dc03a5e4eb87b8 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\1F\02\00\00,\00\00\00" }>, align 8
@alloc_f1afeffee25b8cbad41bb5872529e5be = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\1F\02\00\00L\00\00\00" }>, align 8
@alloc_e7192de98d175da682c169f6595d4522 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\1F\02\00\00T\00\00\00" }>, align 8
@alloc_354dc1959db4c84bf13af6f86d635aee = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\16\02\00\00@\00\00\00" }>, align 8
@alloc_10b6528b98bd905c6309b430b77c3a07 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00c\01\00\00\11\00\00\00" }>, align 8
@alloc_976e0beddddec32ff42087070bcd77a5 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00d\01\00\00\17\00\00\00" }>, align 8
@alloc_96d987a87d97c3b145ef68c6e71dd047 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00l\01\00\00\17\00\00\00" }>, align 8
@alloc_d29c77d346acbe694cb7ba8ee7faff56 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\A5\01\00\00#\00\00\00" }>, align 8
@alloc_a51995a9f594fb331ed053838b7be924 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\A5\01\00\00>\00\00\00" }>, align 8
@alloc_23b5d640586d465cb57fc69fc0fb3828 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\AD\01\00\00\13\00\00\00" }>, align 8
@alloc_0e8d56a95944120dff42b51dc5d24e92 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\AD\01\00\00U\00\00\00" }>, align 8
@vtable.0 = private unnamed_addr constant <{ ptr, [16 x i8], ptr, ptr, ptr }> <{ ptr @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_, [16 x i8] c"(\01\00\00\00\00\00\00\08\00\00\00\00\00\00\00", ptr @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_ }>, align 8
@alloc_1343241238dcbe085445d5b11ba0a378 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\AB\01\00\00\17\00\00\00" }>, align 8
@alloc_f0438cd97fee7f47e6788e32f762b012 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\C4\01\00\00#\00\00\00" }>, align 8
@alloc_cedfa6dae4663ae34151168cdec22263 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\C4\01\00\00>\00\00\00" }>, align 8
@alloc_058578575a98bb3429578f82748d5aad = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\CC\01\00\00\13\00\00\00" }>, align 8
@alloc_7f7b0d1637cd18edc5b90423efa8f2ac = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\CC\01\00\00U\00\00\00" }>, align 8
@vtable.1 = private unnamed_addr constant <{ ptr, [16 x i8], ptr, ptr, ptr }> <{ ptr @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_, [16 x i8] c"\10\01\00\00\00\00\00\00\08\00\00\00\00\00\00\00", ptr @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_ }>, align 8
@alloc_9441bbbb1bffb9011b99cd574d638c7a = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\CA\01\00\00\17\00\00\00" }>, align 8
@alloc_4d6b7a825e6461216f128f0802dfe2ec = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\E3\01\00\00#\00\00\00" }>, align 8
@alloc_b8ba05bf1ee24e89bc9451481eb89547 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\E3\01\00\00>\00\00\00" }>, align 8
@alloc_0c9e7887a13d11b191a330181159523c = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\EB\01\00\00\13\00\00\00" }>, align 8
@alloc_5b806d1bdaa4e2f1b1b427dca973f7a4 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\EB\01\00\00U\00\00\00" }>, align 8
@vtable.2 = private unnamed_addr constant <{ ptr, [16 x i8], ptr, ptr, ptr }> <{ ptr @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_, [16 x i8] c"(\01\00\00\00\00\00\00\08\00\00\00\00\00\00\00", ptr @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_ }>, align 8
@alloc_16fb6e1cf5412ccbca18445a9781d2ea = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\E9\01\00\00\17\00\00\00" }>, align 8
@alloc_26fc8e81fc819c8a9f630ccd48e47036 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\04\02\00\00#\00\00\00" }>, align 8
@alloc_529870ce56aabb58b099913f27113d23 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\04\02\00\00>\00\00\00" }>, align 8
@alloc_f861b8e02d0300dcb721b5d1c9a678c4 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\0C\02\00\00\13\00\00\00" }>, align 8
@alloc_20064a57f7955b3dc6ee7ae10e9bd5ab = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\0C\02\00\00U\00\00\00" }>, align 8
@vtable.3 = private unnamed_addr constant <{ ptr, [16 x i8], ptr, ptr, ptr }> <{ ptr @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_, [16 x i8] c"\10\01\00\00\00\00\00\00\08\00\00\00\00\00\00\00", ptr @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_, ptr @_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_ }>, align 8
@alloc_36684b31319358aad4985691b5adb1d1 = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\0A\02\00\00\17\00\00\00" }>, align 8
@alloc_3819371618053aaf30fd9948083359db = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\8D\01\00\00%\00\00\00" }>, align 8
@alloc_953b7a28a8a2723f809dd5bd246c70bc = private unnamed_addr constant <{ ptr, [16 x i8] }> <{ ptr @alloc_0f470ba9a8dafd09cc9f4992af3b1f93, [16 x i8] c"\0B\00\00\00\00\00\00\00\90\01\00\00)\00\00\00" }>, align 8

; core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
; Function Attrs: nounwind nonlazybind uwtable
define internal fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef nonnull readonly align 8 captures(none) dereferenceable(24) %_1) unnamed_addr #0 personality ptr @rust_eh_personality {
start:
  %0 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %_1.val = load ptr, ptr %0, align 8, !nonnull !3, !noundef !3
  %1 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  %_1.val1 = load i64, ptr %1, align 8, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !4)
  %_711.i.i = icmp eq i64 %_1.val1, 0
  br i1 %_711.i.i, label %bb4, label %bb5.i.i

bb5.i.i:                                          ; preds = %start, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i
  %_3.sroa.0.012.i.i = phi i64 [ %2, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i ], [ 0, %start ]
  %_6.i.i = getelementptr inbounds nuw %LkT, ptr %_1.val, i64 %_3.sroa.0.012.i.i
  %2 = add nuw nsw i64 %_3.sroa.0.012.i.i, 1
  %_6.val.i.i = load i64, ptr %_6.i.i, align 8, !alias.scope !4
  %3 = icmp eq i64 %_6.val.i.i, 0
  br i1 %3, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i, label %bb2.i.i.i4.i.i.i.i

bb2.i.i.i4.i.i.i.i:                               ; preds = %bb5.i.i
  %4 = getelementptr i8, ptr %_6.i.i, i64 8
  %_6.val7.i.i = load ptr, ptr %4, align 8, !alias.scope !4, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i.i.i.i = shl nuw i64 %_6.val.i.i, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_6.val7.i.i, i64 noundef %alloc_size.i.i.i.i5.i.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !4
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i: ; preds = %bb2.i.i.i4.i.i.i.i, %bb5.i.i
  %_7.i.i = icmp eq i64 %2, %_1.val1
  br i1 %_7.i.i, label %bb4, label %bb5.i.i

bb4:                                              ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i, %start
  %_1.val4 = load i64, ptr %_1, align 8, !range !7, !noundef !3
  %5 = icmp eq i64 %_1.val4, 0
  br i1 %5, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc7raw_vec6RawVecNtCsl0YfJI2rrfI_8isolated3LkTEEB1h_.exit8, label %bb2.i.i.i6

bb2.i.i.i6:                                       ; preds = %bb4
  %alloc_size.i.i.i.i7 = mul nuw i64 %_1.val4, 40
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.val, i64 noundef %alloc_size.i.i.i.i7, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc7raw_vec6RawVecNtCsl0YfJI2rrfI_8isolated3LkTEEB1h_.exit8

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc7raw_vec6RawVecNtCsl0YfJI2rrfI_8isolated3LkTEEB1h_.exit8: ; preds = %bb4, %bb2.i.i.i6
  ret void
}

; core::ptr::drop_glue::<alloc::vec::Vec<isolated::field::Fp2>>
; Function Attrs: nounwind nonlazybind uwtable
define internal fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_(i64 %_1.0.val, ptr captures(address) %_1.8.val) unnamed_addr #0 personality ptr @rust_eh_personality {
bb4:
  %0 = icmp eq i64 %_1.0.val, 0
  br i1 %0, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc7raw_vec6RawVecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1j_.exit6, label %bb2.i.i.i4

bb2.i.i.i4:                                       ; preds = %bb4
  %alloc_size.i.i.i.i5 = shl nuw i64 %_1.0.val, 4
  %1 = icmp ne ptr %_1.8.val, null
  tail call void @llvm.assume(i1 %1)
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.8.val, i64 noundef %alloc_size.i.i.i.i5, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc7raw_vec6RawVecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1j_.exit6

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc7raw_vec6RawVecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1j_.exit6: ; preds = %bb4, %bb2.i.i.i4
  ret void
}

; core::ptr::drop_glue::<alloc::boxed::Box<dyn for<'a> core::ops::function::Fn<(&'a [isolated::field::Fp2],), Output = isolated::field::Fp2>>>
; Function Attrs: nonlazybind uwtable
define internal fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_(ptr %_1.0.val, ptr readonly captures(address_is_null) %_1.8.val) unnamed_addr #1 personality ptr @rust_eh_personality {
start:
  %0 = icmp ne ptr %_1.8.val, null
  tail call void @llvm.assume(i1 %0)
  %1 = load ptr, ptr %_1.8.val, align 8, !invariant.load !3
  %.not = icmp eq ptr %1, null
  br i1 %.not, label %bb3, label %is_not_null

is_not_null:                                      ; preds = %start
  %2 = icmp ne ptr %_1.0.val, null
  tail call void @llvm.assume(i1 %2)
  invoke void %1(ptr noundef nonnull %_1.0.val)
          to label %bb3 unwind label %cleanup

bb3:                                              ; preds = %is_not_null, %start
  %3 = getelementptr inbounds nuw i8, ptr %_1.8.val, i64 8
  %4 = load i64, ptr %3, align 8, !range !7, !invariant.load !3
  %5 = icmp eq i64 %4, 0
  br i1 %5, label %_RNvXs8_NtCs40k4W9msRzi_5alloc5boxedINtB5_3BoxDG_INtNtNtCscI6d9CVNmLh_4core3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1w_EL_ENtNtBP_4drop4Drop4dropB1A_.exit, label %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i

_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i: ; preds = %bb3
  %6 = getelementptr inbounds nuw i8, ptr %_1.8.val, i64 16
  %7 = load i64, ptr %6, align 8, !range !8, !invariant.load !3
  %8 = icmp ne ptr %_1.0.val, null
  tail call void @llvm.assume(i1 %8)
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.0.val, i64 noundef %4, i64 noundef range(i64 1, -9223372036854775807) %7) #20
  br label %_RNvXs8_NtCs40k4W9msRzi_5alloc5boxedINtB5_3BoxDG_INtNtNtCscI6d9CVNmLh_4core3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1w_EL_ENtNtBP_4drop4Drop4dropB1A_.exit

_RNvXs8_NtCs40k4W9msRzi_5alloc5boxedINtB5_3BoxDG_INtNtNtCscI6d9CVNmLh_4core3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1w_EL_ENtNtBP_4drop4Drop4dropB1A_.exit: ; preds = %bb3, %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i
  ret void

cleanup:                                          ; preds = %is_not_null
  %9 = landingpad { ptr, i32 }
          cleanup
  %10 = getelementptr inbounds nuw i8, ptr %_1.8.val, i64 8
  %11 = load i64, ptr %10, align 8, !range !7, !invariant.load !3
  %12 = icmp eq i64 %11, 0
  br i1 %12, label %bb1, label %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i4

_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i4: ; preds = %cleanup
  %13 = getelementptr inbounds nuw i8, ptr %_1.8.val, i64 16
  %14 = load i64, ptr %13, align 8, !range !8, !invariant.load !3
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.0.val, i64 noundef %11, i64 noundef range(i64 1, -9223372036854775807) %14) #20
  br label %bb1

bb1:                                              ; preds = %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i4, %cleanup
  resume { ptr, i32 } %9
}

; core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
; Function Attrs: nounwind nonlazybind uwtable
define internal void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef readonly align 8 captures(none) dereferenceable(296) %_1) unnamed_addr #0 personality ptr @rust_eh_personality {
start:
  %0 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  %.val16 = load i64, ptr %0, align 8
  %1 = icmp eq i64 %.val16, 0
  br i1 %1, label %bb10, label %bb2.i.i.i4.i

bb2.i.i.i4.i:                                     ; preds = %start
  %2 = getelementptr inbounds nuw i8, ptr %_1, i64 24
  %.val17 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i = shl nuw i64 %.val16, 3
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %.val17, i64 noundef %alloc_size.i.i.i.i5.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb10

bb10:                                             ; preds = %bb2.i.i.i4.i, %start
  %3 = getelementptr inbounds nuw i8, ptr %_1, i64 40
  tail call void @llvm.experimental.noalias.scope.decl(metadata !9)
  %4 = getelementptr inbounds nuw i8, ptr %_1, i64 48
  %_1.val.i = load ptr, ptr %4, align 8, !alias.scope !9, !nonnull !3, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %_1, i64 56
  %_1.val1.i = load i64, ptr %5, align 8, !alias.scope !9, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !12)
  %_711.i.i.i = icmp eq i64 %_1.val1.i, 0
  br i1 %_711.i.i.i, label %bb4.i, label %bb5.i.i.i

bb5.i.i.i:                                        ; preds = %bb10, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i
  %_3.sroa.0.012.i.i.i = phi i64 [ %6, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i ], [ 0, %bb10 ]
  %_6.i.i.i = getelementptr inbounds nuw %LkT, ptr %_1.val.i, i64 %_3.sroa.0.012.i.i.i
  %6 = add nuw nsw i64 %_3.sroa.0.012.i.i.i, 1
  %_6.val.i.i.i = load i64, ptr %_6.i.i.i, align 8, !alias.scope !12, !noalias !9
  %7 = icmp eq i64 %_6.val.i.i.i, 0
  br i1 %7, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i, label %bb2.i.i.i4.i.i.i.i.i

bb2.i.i.i4.i.i.i.i.i:                             ; preds = %bb5.i.i.i
  %8 = getelementptr i8, ptr %_6.i.i.i, i64 8
  %_6.val7.i.i.i = load ptr, ptr %8, align 8, !alias.scope !12, !noalias !9, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i.i.i.i.i = shl nuw i64 %_6.val.i.i.i, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_6.val7.i.i.i, i64 noundef %alloc_size.i.i.i.i5.i.i.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !15
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i: ; preds = %bb2.i.i.i4.i.i.i.i.i, %bb5.i.i.i
  %_7.i.i.i = icmp eq i64 %6, %_1.val1.i
  br i1 %_7.i.i.i, label %bb4.i, label %bb5.i.i.i

bb4.i:                                            ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i, %bb10
  %_1.val4.i = load i64, ptr %3, align 8, !range !7, !alias.scope !9, !noundef !3
  %9 = icmp eq i64 %_1.val4.i, 0
  br i1 %9, label %bb9, label %bb2.i.i.i6.i

bb2.i.i.i6.i:                                     ; preds = %bb4.i
  %alloc_size.i.i.i.i7.i = mul nuw i64 %_1.val4.i, 40
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.val.i, i64 noundef %alloc_size.i.i.i.i7.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !9
  br label %bb9

bb9:                                              ; preds = %bb2.i.i.i6.i, %bb4.i
  %10 = getelementptr inbounds nuw i8, ptr %_1, i64 64
  %.val14 = load i64, ptr %10, align 8
  %11 = icmp eq i64 %.val14, 0
  br i1 %11, label %bb8, label %bb2.i.i.i4.i22

bb2.i.i.i4.i22:                                   ; preds = %bb9
  %12 = getelementptr inbounds nuw i8, ptr %_1, i64 72
  %.val15 = load ptr, ptr %12, align 8, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i23 = shl nuw i64 %.val14, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %.val15, i64 noundef %alloc_size.i.i.i.i5.i23, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb8

bb8:                                              ; preds = %bb2.i.i.i4.i22, %bb9
  %13 = getelementptr inbounds nuw i8, ptr %_1, i64 88
  tail call void @llvm.experimental.noalias.scope.decl(metadata !16)
  tail call void @llvm.experimental.noalias.scope.decl(metadata !19)
  %14 = getelementptr inbounds nuw i8, ptr %_1, i64 96
  %_1.val.i.i = load ptr, ptr %14, align 8, !alias.scope !22, !nonnull !3, !noundef !3
  %15 = getelementptr inbounds nuw i8, ptr %_1, i64 104
  %_1.val1.i.i = load i64, ptr %15, align 8, !alias.scope !22, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !23)
  %_711.i.i.i.i = icmp eq i64 %_1.val1.i.i, 0
  br i1 %_711.i.i.i.i, label %bb4.i.i, label %bb5.i.i.i.i

bb5.i.i.i.i:                                      ; preds = %bb8, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i
  %_3.sroa.0.012.i.i.i.i = phi i64 [ %16, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i ], [ 0, %bb8 ]
  %_6.i.i.i.i = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_1.val.i.i, i64 %_3.sroa.0.012.i.i.i.i
  %16 = add nuw nsw i64 %_3.sroa.0.012.i.i.i.i, 1
  %17 = getelementptr i8, ptr %_6.i.i.i.i, i64 8
  %_6.val.i.i.i.i = load i64, ptr %17, align 8, !alias.scope !23, !noalias !22
  %18 = icmp eq i64 %_6.val.i.i.i.i, 0
  br i1 %18, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i, label %bb2.i.i.i4.i.i.i.i.i.i

bb2.i.i.i4.i.i.i.i.i.i:                           ; preds = %bb5.i.i.i.i
  %19 = getelementptr i8, ptr %_6.i.i.i.i, i64 16
  %_6.val7.i.i.i.i = load ptr, ptr %19, align 8, !alias.scope !23, !noalias !22, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i.i.i.i.i.i = mul nuw i64 %_6.val.i.i.i.i, 24
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_6.val7.i.i.i.i, i64 noundef %alloc_size.i.i.i.i5.i.i.i.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !26
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i: ; preds = %bb2.i.i.i4.i.i.i.i.i.i, %bb5.i.i.i.i
  %_7.i.i.i.i = icmp eq i64 %16, %_1.val1.i.i
  br i1 %_7.i.i.i.i, label %bb4.i.i, label %bb5.i.i.i.i

bb4.i.i:                                          ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i, %bb8
  %_1.val4.i.i = load i64, ptr %13, align 8, !range !7, !alias.scope !22, !noundef !3
  %20 = icmp eq i64 %_1.val4.i.i, 0
  br i1 %20, label %bb7, label %bb2.i.i.i6.i.i

bb2.i.i.i6.i.i:                                   ; preds = %bb4.i.i
  %alloc_size.i.i.i.i7.i.i = shl nuw i64 %_1.val4.i.i, 5
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.val.i.i, i64 noundef %alloc_size.i.i.i.i7.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !22
  br label %bb7

bb7:                                              ; preds = %bb2.i.i.i6.i.i, %bb4.i.i
  %21 = getelementptr inbounds nuw i8, ptr %_1, i64 128
  %.val12 = load i64, ptr %21, align 8
  %22 = icmp eq i64 %.val12, 0
  br i1 %22, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit32, label %bb2.i.i.i4.i30

bb2.i.i.i4.i30:                                   ; preds = %bb7
  %23 = getelementptr inbounds nuw i8, ptr %_1, i64 136
  %.val13 = load ptr, ptr %23, align 8, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i31 = shl nuw i64 %.val12, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %.val13, i64 noundef %alloc_size.i.i.i.i5.i31, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit32

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit32: ; preds = %bb7, %bb2.i.i.i4.i30
  ret void
}

; core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
; Function Attrs: nounwind nonlazybind uwtable
define internal void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef readonly align 8 captures(none) dereferenceable(272) %_1) unnamed_addr #0 personality ptr @rust_eh_personality {
start:
  %0 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  %.val16 = load i64, ptr %0, align 8
  %1 = icmp eq i64 %.val16, 0
  br i1 %1, label %bb10, label %bb2.i.i.i4.i

bb2.i.i.i4.i:                                     ; preds = %start
  %2 = getelementptr inbounds nuw i8, ptr %_1, i64 24
  %.val17 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i = shl nuw i64 %.val16, 3
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %.val17, i64 noundef %alloc_size.i.i.i.i5.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb10

bb10:                                             ; preds = %bb2.i.i.i4.i, %start
  %3 = getelementptr inbounds nuw i8, ptr %_1, i64 40
  tail call void @llvm.experimental.noalias.scope.decl(metadata !27)
  %4 = getelementptr inbounds nuw i8, ptr %_1, i64 48
  %_1.val.i = load ptr, ptr %4, align 8, !alias.scope !27, !nonnull !3, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %_1, i64 56
  %_1.val1.i = load i64, ptr %5, align 8, !alias.scope !27, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !30)
  %_711.i.i.i = icmp eq i64 %_1.val1.i, 0
  br i1 %_711.i.i.i, label %bb4.i, label %bb5.i.i.i

bb5.i.i.i:                                        ; preds = %bb10, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i
  %_3.sroa.0.012.i.i.i = phi i64 [ %6, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i ], [ 0, %bb10 ]
  %_6.i.i.i = getelementptr inbounds nuw %LkT, ptr %_1.val.i, i64 %_3.sroa.0.012.i.i.i
  %6 = add nuw nsw i64 %_3.sroa.0.012.i.i.i, 1
  %_6.val.i.i.i = load i64, ptr %_6.i.i.i, align 8, !alias.scope !30, !noalias !27
  %7 = icmp eq i64 %_6.val.i.i.i, 0
  br i1 %7, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i, label %bb2.i.i.i4.i.i.i.i.i

bb2.i.i.i4.i.i.i.i.i:                             ; preds = %bb5.i.i.i
  %8 = getelementptr i8, ptr %_6.i.i.i, i64 8
  %_6.val7.i.i.i = load ptr, ptr %8, align 8, !alias.scope !30, !noalias !27, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i.i.i.i.i = shl nuw i64 %_6.val.i.i.i, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_6.val7.i.i.i, i64 noundef %alloc_size.i.i.i.i5.i.i.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !33
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i: ; preds = %bb2.i.i.i4.i.i.i.i.i, %bb5.i.i.i
  %_7.i.i.i = icmp eq i64 %6, %_1.val1.i
  br i1 %_7.i.i.i, label %bb4.i, label %bb5.i.i.i

bb4.i:                                            ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated3LkTEBD_.exit.i.i.i, %bb10
  %_1.val4.i = load i64, ptr %3, align 8, !range !7, !alias.scope !27, !noundef !3
  %9 = icmp eq i64 %_1.val4.i, 0
  br i1 %9, label %bb9, label %bb2.i.i.i6.i

bb2.i.i.i6.i:                                     ; preds = %bb4.i
  %alloc_size.i.i.i.i7.i = mul nuw i64 %_1.val4.i, 40
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.val.i, i64 noundef %alloc_size.i.i.i.i7.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !27
  br label %bb9

bb9:                                              ; preds = %bb2.i.i.i6.i, %bb4.i
  %10 = getelementptr inbounds nuw i8, ptr %_1, i64 64
  %.val14 = load i64, ptr %10, align 8
  %11 = icmp eq i64 %.val14, 0
  br i1 %11, label %bb8, label %bb2.i.i.i4.i22

bb2.i.i.i4.i22:                                   ; preds = %bb9
  %12 = getelementptr inbounds nuw i8, ptr %_1, i64 72
  %.val15 = load ptr, ptr %12, align 8, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i23 = shl nuw i64 %.val14, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %.val15, i64 noundef %alloc_size.i.i.i.i5.i23, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb8

bb8:                                              ; preds = %bb2.i.i.i4.i22, %bb9
  %13 = getelementptr inbounds nuw i8, ptr %_1, i64 88
  tail call void @llvm.experimental.noalias.scope.decl(metadata !34)
  tail call void @llvm.experimental.noalias.scope.decl(metadata !37)
  %14 = getelementptr inbounds nuw i8, ptr %_1, i64 96
  %_1.val.i.i = load ptr, ptr %14, align 8, !alias.scope !40, !nonnull !3, !noundef !3
  %15 = getelementptr inbounds nuw i8, ptr %_1, i64 104
  %_1.val1.i.i = load i64, ptr %15, align 8, !alias.scope !40, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !41)
  %_711.i.i.i.i = icmp eq i64 %_1.val1.i.i, 0
  br i1 %_711.i.i.i.i, label %bb4.i.i, label %bb5.i.i.i.i

bb5.i.i.i.i:                                      ; preds = %bb8, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i
  %_3.sroa.0.012.i.i.i.i = phi i64 [ %16, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i ], [ 0, %bb8 ]
  %_6.i.i.i.i = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_1.val.i.i, i64 %_3.sroa.0.012.i.i.i.i
  %16 = add nuw nsw i64 %_3.sroa.0.012.i.i.i.i, 1
  %17 = getelementptr i8, ptr %_6.i.i.i.i, i64 8
  %_6.val.i.i.i.i = load i64, ptr %17, align 8, !alias.scope !41, !noalias !40
  %18 = icmp eq i64 %_6.val.i.i.i.i, 0
  br i1 %18, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i, label %bb2.i.i.i4.i.i.i.i.i.i

bb2.i.i.i4.i.i.i.i.i.i:                           ; preds = %bb5.i.i.i.i
  %19 = getelementptr i8, ptr %_6.i.i.i.i, i64 16
  %_6.val7.i.i.i.i = load ptr, ptr %19, align 8, !alias.scope !41, !noalias !40, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i.i.i.i.i.i = mul nuw i64 %_6.val.i.i.i.i, 24
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_6.val7.i.i.i.i, i64 noundef %alloc_size.i.i.i.i5.i.i.i.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !44
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i: ; preds = %bb2.i.i.i4.i.i.i.i.i.i, %bb5.i.i.i.i
  %_7.i.i.i.i = icmp eq i64 %16, %_1.val1.i.i
  br i1 %_7.i.i.i.i, label %bb4.i.i, label %bb5.i.i.i.i

bb4.i.i:                                          ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i.i, %bb8
  %_1.val4.i.i = load i64, ptr %13, align 8, !range !7, !alias.scope !40, !noundef !3
  %20 = icmp eq i64 %_1.val4.i.i, 0
  br i1 %20, label %bb7, label %bb2.i.i.i6.i.i

bb2.i.i.i6.i.i:                                   ; preds = %bb4.i.i
  %alloc_size.i.i.i.i7.i.i = shl nuw i64 %_1.val4.i.i, 5
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.val.i.i, i64 noundef %alloc_size.i.i.i.i7.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !40
  br label %bb7

bb7:                                              ; preds = %bb2.i.i.i6.i.i, %bb4.i.i
  %21 = getelementptr inbounds nuw i8, ptr %_1, i64 128
  %.val12 = load i64, ptr %21, align 8
  %22 = icmp eq i64 %.val12, 0
  br i1 %22, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit32, label %bb2.i.i.i4.i30

bb2.i.i.i4.i30:                                   ; preds = %bb7
  %23 = getelementptr inbounds nuw i8, ptr %_1, i64 136
  %.val13 = load ptr, ptr %23, align 8, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i31 = shl nuw i64 %.val12, 4
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %.val13, i64 noundef %alloc_size.i.i.i.i5.i31, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit32

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit32: ; preds = %bb7, %bb2.i.i.i4.i30
  ret void
}

; core::ptr::drop_glue::<isolated::PadTerm>
; Function Attrs: nounwind nonlazybind uwtable
define internal fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_(ptr noalias noundef nonnull readonly align 8 captures(none) dereferenceable(40) %_1) unnamed_addr #0 personality ptr @rust_eh_personality {
start:
  tail call void @llvm.experimental.noalias.scope.decl(metadata !45)
  %0 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %_1.val.i = load ptr, ptr %0, align 8, !alias.scope !45, !nonnull !3, !noundef !3
  %1 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  %_1.val1.i = load i64, ptr %1, align 8, !alias.scope !45, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !48)
  %_711.i.i.i = icmp eq i64 %_1.val1.i, 0
  br i1 %_711.i.i.i, label %bb4.i, label %bb5.i.i.i

bb5.i.i.i:                                        ; preds = %start, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i
  %_3.sroa.0.012.i.i.i = phi i64 [ %2, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i ], [ 0, %start ]
  %_6.i.i.i = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_1.val.i, i64 %_3.sroa.0.012.i.i.i
  %2 = add nuw nsw i64 %_3.sroa.0.012.i.i.i, 1
  %3 = getelementptr i8, ptr %_6.i.i.i, i64 8
  %_6.val.i.i.i = load i64, ptr %3, align 8, !alias.scope !48, !noalias !45
  %4 = icmp eq i64 %_6.val.i.i.i, 0
  br i1 %4, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i, label %bb2.i.i.i4.i.i.i.i.i

bb2.i.i.i4.i.i.i.i.i:                             ; preds = %bb5.i.i.i
  %5 = getelementptr i8, ptr %_6.i.i.i, i64 16
  %_6.val7.i.i.i = load ptr, ptr %5, align 8, !alias.scope !48, !noalias !45, !nonnull !3, !noundef !3
  %alloc_size.i.i.i.i5.i.i.i.i.i = mul nuw i64 %_6.val.i.i.i, 24
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_6.val7.i.i.i, i64 noundef %alloc_size.i.i.i.i5.i.i.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !51
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i: ; preds = %bb2.i.i.i4.i.i.i.i.i, %bb5.i.i.i
  %_7.i.i.i = icmp eq i64 %2, %_1.val1.i
  br i1 %_7.i.i.i, label %bb4.i, label %bb5.i.i.i

bb4.i:                                            ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1g_.exit.i.i.i, %start
  %_1.val4.i = load i64, ptr %_1, align 8, !range !7, !alias.scope !45, !noundef !3
  %6 = icmp eq i64 %_1.val4.i, 0
  br i1 %6, label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_.exit, label %bb2.i.i.i6.i

bb2.i.i.i6.i:                                     ; preds = %bb4.i
  %alloc_size.i.i.i.i7.i = shl nuw i64 %_1.val4.i, 5
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_1.val.i, i64 noundef %alloc_size.i.i.i.i7.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20, !noalias !45
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_.exit

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_.exit: ; preds = %bb4.i, %bb2.i.i.i6.i
  ret void
}

; isolated::factory_0::{closure#1}::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_(ptr readonly captures(address_is_null) %_1.0.val, ptr readonly captures(address_is_null) %_1.8.val, i64 noundef range(i64 71, 77) %o) unnamed_addr #2 {
start:
  %0 = icmp ne ptr %_1.0.val, null
  tail call void @llvm.assume(i1 %0)
  %1 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 16
  %_14 = load ptr, ptr %1, align 8, !nonnull !3, !align !52, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %_14, i64 8
  %_19 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_14, i64 16
  %_18 = load i64, ptr %3, align 8, !noundef !3
  %_20 = icmp ult i64 %o, %_18
  br i1 %_20, label %bb4, label %panic

bb4:                                              ; preds = %start
  %_11 = getelementptr inbounds nuw i64, ptr %_19, i64 %o
  %_10 = load i64, ptr %_11, align 8, !noundef !3
  %_15.0 = load ptr, ptr %_1.0.val, align 8, !nonnull !3, !align !52, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 8
  %_15.1 = load i64, ptr %4, align 8, !noundef !3
  %_13 = icmp ult i64 %_10, %_15.1
  br i1 %_13, label %bb3, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %o, i64 noundef %_18, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_14e9b0f3c1e82842e326b949d03d992d) #21
  unreachable

bb3:                                              ; preds = %bb4
  %5 = getelementptr inbounds nuw %"field::Fp2", ptr %_15.0, i64 %_10
  %_3.0 = load i64, ptr %5, align 8, !noundef !3
  %6 = getelementptr inbounds nuw i8, ptr %5, i64 8
  %_3.1 = load i64, ptr %6, align 8, !noundef !3
  %_6 = add nuw nsw i64 %o, 1
  %_24 = icmp ult i64 %_6, %_18
  br i1 %_24, label %bb6, label %panic2

panic1:                                           ; preds = %bb4
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_10, i64 noundef %_15.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable

bb6:                                              ; preds = %bb3
  %_22 = getelementptr inbounds nuw i64, ptr %_19, i64 %_6
  %_21 = load i64, ptr %_22, align 8, !noundef !3
  %_23 = icmp ult i64 %_21, %_15.1
  br i1 %_23, label %bb5, label %panic3

panic2:                                           ; preds = %bb3
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_6, i64 noundef %_18, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_14e9b0f3c1e82842e326b949d03d992d) #21
  unreachable

bb5:                                              ; preds = %bb6
  %7 = getelementptr inbounds nuw %"field::Fp2", ptr %_15.0, i64 %_21
  %_5.0 = load i64, ptr %7, align 8, !noundef !3
  %8 = getelementptr inbounds nuw i8, ptr %7, i64 8
  %_5.1 = load i64, ptr %8, align 8, !noundef !3
  %9 = icmp ne ptr %_1.8.val, null
  tail call void @llvm.assume(i1 %9)
  %_7.0 = load i64, ptr %_1.8.val, align 8, !noundef !3
  %10 = getelementptr inbounds nuw i8, ptr %_1.8.val, i64 8
  %_7.1 = load i64, ptr %10, align 8, !noundef !3
  %_11.i = zext i64 %_5.0 to i128
  %_12.i = zext i64 %_7.0 to i128
  %_10.i4 = mul nuw i128 %_12.i, %_11.i
  %x_lo.i58 = trunc i128 %_10.i4 to i64
  %_4.i59 = lshr i128 %_10.i4, 64
  %x_hi.i60 = trunc nuw i128 %_4.i59 to i64
  %x_hi_hi.i61 = lshr i64 %x_hi.i60, 32
  %x_hi_lo.i62 = and i64 %x_hi.i60, 4294967295
  %_9.0.i63 = sub i64 %x_lo.i58, %x_hi_hi.i61
  %_9.1.i64 = icmp ugt i64 %x_hi_hi.i61, %x_lo.i58
  %_10.i65 = add i64 %_9.0.i63, -4294967295
  %spec.select.i66 = select i1 %_9.1.i64, i64 %_10.i65, i64 %_9.0.i63
  %t1.i67 = mul nuw i64 %x_hi_lo.i62, 4294967295
  %_14.0.i68 = add i64 %spec.select.i66, %t1.i67
  %_14.1.i69 = icmp ult i64 %_14.0.i68, %spec.select.i66
  %11 = add i64 %_14.0.i68, 4294967295
  %res.sroa.0.0.i70 = select i1 %_14.1.i69, i64 %11, i64 %_14.0.i68
  %_16.i71 = icmp ugt i64 %res.sroa.0.0.i70, -4294967296
  %_17.i72 = add nsw i64 %res.sroa.0.0.i70, 4294967295
  %_0.sroa.0.0.i73 = select i1 %_16.i71, i64 %_17.i72, i64 %res.sroa.0.0.i70
  %_14.i = zext i64 %_5.1 to i128
  %_15.i5 = zext i64 %_7.1 to i128
  %_13.i = mul nuw i128 %_15.i5, %_14.i
  %x_lo.i42 = trunc i128 %_13.i to i64
  %_4.i43 = lshr i128 %_13.i, 64
  %x_hi.i44 = trunc nuw i128 %_4.i43 to i64
  %x_hi_hi.i45 = lshr i64 %x_hi.i44, 32
  %x_hi_lo.i46 = and i64 %x_hi.i44, 4294967295
  %_9.0.i47 = sub i64 %x_lo.i42, %x_hi_hi.i45
  %_9.1.i48 = icmp ugt i64 %x_hi_hi.i45, %x_lo.i42
  %_10.i49 = add i64 %_9.0.i47, -4294967295
  %spec.select.i50 = select i1 %_9.1.i48, i64 %_10.i49, i64 %_9.0.i47
  %t1.i51 = mul nuw i64 %x_hi_lo.i46, 4294967295
  %_14.0.i52 = add i64 %spec.select.i50, %t1.i51
  %_14.1.i53 = icmp ult i64 %_14.0.i52, %spec.select.i50
  %12 = add i64 %_14.0.i52, 4294967295
  %res.sroa.0.0.i54 = select i1 %_14.1.i53, i64 %12, i64 %_14.0.i52
  %_16.i55 = icmp ugt i64 %res.sroa.0.0.i54, -4294967296
  %_17.i56 = add nsw i64 %res.sroa.0.0.i54, 4294967295
  %_0.sroa.0.0.i57 = select i1 %_16.i55, i64 %_17.i56, i64 %res.sroa.0.0.i54
  %_16.i6 = mul nuw i128 %_15.i5, %_11.i
  %x_lo.i26 = trunc i128 %_16.i6 to i64
  %_4.i27 = lshr i128 %_16.i6, 64
  %x_hi.i28 = trunc nuw i128 %_4.i27 to i64
  %x_hi_hi.i29 = lshr i64 %x_hi.i28, 32
  %x_hi_lo.i30 = and i64 %x_hi.i28, 4294967295
  %_9.0.i31 = sub i64 %x_lo.i26, %x_hi_hi.i29
  %_9.1.i32 = icmp ugt i64 %x_hi_hi.i29, %x_lo.i26
  %_10.i33 = add i64 %_9.0.i31, -4294967295
  %spec.select.i34 = select i1 %_9.1.i32, i64 %_10.i33, i64 %_9.0.i31
  %t1.i35 = mul nuw i64 %x_hi_lo.i30, 4294967295
  %_14.0.i36 = add i64 %spec.select.i34, %t1.i35
  %_14.1.i37 = icmp ult i64 %_14.0.i36, %spec.select.i34
  %13 = add i64 %_14.0.i36, 4294967295
  %res.sroa.0.0.i38 = select i1 %_14.1.i37, i64 %13, i64 %_14.0.i36
  %_16.i39 = icmp ugt i64 %res.sroa.0.0.i38, -4294967296
  %_17.i40 = add nsw i64 %res.sroa.0.0.i38, 4294967295
  %_0.sroa.0.0.i41 = select i1 %_16.i39, i64 %_17.i40, i64 %res.sroa.0.0.i38
  %_17.i = mul nuw i128 %_12.i, %_14.i
  %x_lo.i10 = trunc i128 %_17.i to i64
  %_4.i11 = lshr i128 %_17.i, 64
  %x_hi.i12 = trunc nuw i128 %_4.i11 to i64
  %x_hi_hi.i13 = lshr i64 %x_hi.i12, 32
  %x_hi_lo.i14 = and i64 %x_hi.i12, 4294967295
  %_9.0.i15 = sub i64 %x_lo.i10, %x_hi_hi.i13
  %_9.1.i16 = icmp ugt i64 %x_hi_hi.i13, %x_lo.i10
  %_10.i17 = add i64 %_9.0.i15, -4294967295
  %spec.select.i18 = select i1 %_9.1.i16, i64 %_10.i17, i64 %_9.0.i15
  %t1.i19 = mul nuw i64 %x_hi_lo.i14, 4294967295
  %_14.0.i20 = add i64 %spec.select.i18, %t1.i19
  %_14.1.i21 = icmp ult i64 %_14.0.i20, %spec.select.i18
  %14 = add i64 %_14.0.i20, 4294967295
  %res.sroa.0.0.i22 = select i1 %_14.1.i21, i64 %14, i64 %_14.0.i20
  %_16.i23 = icmp ugt i64 %res.sroa.0.0.i22, -4294967296
  %_17.i24 = add nsw i64 %res.sroa.0.0.i22, 4294967295
  %_0.sroa.0.0.i25 = select i1 %_16.i23, i64 %_17.i24, i64 %res.sroa.0.0.i22
  %_19.i = zext i64 %_0.sroa.0.0.i57 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i = trunc i128 %_18.i to i64
  %_4.i = lshr i128 %_18.i, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %15 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %15, i64 %_14.0.i
  %_16.i8 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i9 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i8, i64 %_17.i9, i64 %res.sroa.0.0.i
  %_22.0.i = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i73
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i73
  %16 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %16, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i41, %_0.sroa.0.0.i25
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i41
  %17 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %17, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %_3.0
  %_7.1.i = icmp ult i64 %_7.0.i, %_3.0
  %18 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %18, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %_3.1
  %_13.1.i = icmp ult i64 %_13.0.i, %_3.1
  %19 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %19, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %20 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i, 0
  %21 = insertvalue { i64, i64 } %20, i64 %_4.sroa.0.0.i, 1
  ret { i64, i64 } %21

panic3:                                           ; preds = %bb6
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_21, i64 noundef %_15.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable
}

; isolated::factory_1::{closure#1}::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_(ptr readonly captures(address_is_null) %_1.0.val, ptr readonly captures(address_is_null) %_1.8.val, i64 noundef range(i64 71, 77) %o) unnamed_addr #2 {
start:
  %0 = icmp ne ptr %_1.0.val, null
  tail call void @llvm.assume(i1 %0)
  %1 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 16
  %_12 = load ptr, ptr %1, align 8, !nonnull !3, !align !52, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %_12, i64 8
  %_17 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_12, i64 16
  %_16 = load i64, ptr %3, align 8, !noundef !3
  %_18 = icmp ult i64 %o, %_16
  br i1 %_18, label %bb3, label %panic

bb3:                                              ; preds = %start
  %_9 = getelementptr inbounds nuw i64, ptr %_17, i64 %o
  %_8 = load i64, ptr %_9, align 8, !noundef !3
  %_13.0 = load ptr, ptr %_1.0.val, align 8, !nonnull !3, !align !52, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 8
  %_13.1 = load i64, ptr %4, align 8, !noundef !3
  %_11 = icmp ult i64 %_8, %_13.1
  br i1 %_11, label %bb2, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %o, i64 noundef %_16, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_826b68913cf630c35a865efbea8045e3) #21
  unreachable

bb2:                                              ; preds = %bb3
  %5 = getelementptr inbounds nuw %"field::Fp2", ptr %_13.0, i64 %_8
  %_3.0 = load i64, ptr %5, align 8, !noundef !3
  %6 = getelementptr inbounds nuw i8, ptr %5, i64 8
  %_3.1 = load i64, ptr %6, align 8, !noundef !3
  %_5 = add nuw nsw i64 %o, 1
  %_22 = icmp ult i64 %_5, %_16
  br i1 %_22, label %bb5, label %panic2

panic1:                                           ; preds = %bb3
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_8, i64 noundef %_13.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable

bb5:                                              ; preds = %bb2
  %_20 = getelementptr inbounds nuw i64, ptr %_17, i64 %_5
  %_19 = load i64, ptr %_20, align 8, !noundef !3
  %_21 = icmp ult i64 %_19, %_13.1
  br i1 %_21, label %bb4, label %panic3

panic2:                                           ; preds = %bb2
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_5, i64 noundef %_16, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_826b68913cf630c35a865efbea8045e3) #21
  unreachable

bb4:                                              ; preds = %bb5
  %7 = getelementptr inbounds nuw %"field::Fp2", ptr %_13.0, i64 %_19
  %_31 = load i64, ptr %7, align 8, !noundef !3
  %8 = getelementptr inbounds nuw i8, ptr %7, i64 8
  %_32 = load i64, ptr %8, align 8, !noundef !3
  %9 = icmp ne ptr %_1.8.val, null
  tail call void @llvm.assume(i1 %9)
  %_30 = load i64, ptr %_1.8.val, align 8, !noundef !3
  %_26 = zext i64 %_31 to i128
  %_27 = zext i64 %_30 to i128
  %_25 = mul nuw i128 %_27, %_26
  %x_lo.i6 = trunc i128 %_25 to i64
  %_4.i7 = lshr i128 %_25, 64
  %x_hi.i8 = trunc nuw i128 %_4.i7 to i64
  %x_hi_hi.i9 = lshr i64 %x_hi.i8, 32
  %x_hi_lo.i10 = and i64 %x_hi.i8, 4294967295
  %_9.0.i11 = sub i64 %x_lo.i6, %x_hi_hi.i9
  %_9.1.i12 = icmp ugt i64 %x_hi_hi.i9, %x_lo.i6
  %_10.i13 = add i64 %_9.0.i11, -4294967295
  %spec.select.i14 = select i1 %_9.1.i12, i64 %_10.i13, i64 %_9.0.i11
  %t1.i15 = mul nuw i64 %x_hi_lo.i10, 4294967295
  %_14.0.i16 = add i64 %spec.select.i14, %t1.i15
  %_14.1.i17 = icmp ult i64 %_14.0.i16, %spec.select.i14
  %10 = add i64 %_14.0.i16, 4294967295
  %res.sroa.0.0.i18 = select i1 %_14.1.i17, i64 %10, i64 %_14.0.i16
  %_16.i19 = icmp ugt i64 %res.sroa.0.0.i18, -4294967296
  %_17.i20 = add nsw i64 %res.sroa.0.0.i18, 4294967295
  %_0.sroa.0.0.i21 = select i1 %_16.i19, i64 %_17.i20, i64 %res.sroa.0.0.i18
  %_29 = zext i64 %_32 to i128
  %_28 = mul nuw i128 %_27, %_29
  %x_lo.i = trunc i128 %_28 to i64
  %_4.i = lshr i128 %_28, 64
  %x_hi.i = trunc nuw i128 %_4.i to i64
  %x_hi_hi.i = lshr i64 %x_hi.i, 32
  %x_hi_lo.i = and i64 %x_hi.i, 4294967295
  %_9.0.i = sub i64 %x_lo.i, %x_hi_hi.i
  %_9.1.i = icmp ugt i64 %x_hi_hi.i, %x_lo.i
  %_10.i4 = add i64 %_9.0.i, -4294967295
  %spec.select.i = select i1 %_9.1.i, i64 %_10.i4, i64 %_9.0.i
  %t1.i = mul nuw i64 %x_hi_lo.i, 4294967295
  %_14.0.i = add i64 %spec.select.i, %t1.i
  %_14.1.i = icmp ult i64 %_14.0.i, %spec.select.i
  %11 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %11, i64 %_14.0.i
  %_16.i5 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i5, i64 %_17.i, i64 %res.sroa.0.0.i
  %_7.0.i = add i64 %_0.sroa.0.0.i21, %_3.0
  %_7.1.i = icmp ult i64 %_7.0.i, %_3.0
  %12 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %12, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_0.sroa.0.0.i, %_3.1
  %_13.1.i = icmp ult i64 %_13.0.i, %_3.1
  %13 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %13, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %14 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i, 0
  %15 = insertvalue { i64, i64 } %14, i64 %_4.sroa.0.0.i, 1
  ret { i64, i64 } %15

panic3:                                           ; preds = %bb5
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_19, i64 noundef %_13.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable
}

; isolated::factory_2::{closure#1}::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_(ptr readonly captures(address_is_null) %_1.0.val, ptr readonly captures(address_is_null) %_1.8.val, i64 noundef range(i64 71, 77) %o) unnamed_addr #2 {
start:
  %0 = icmp ne ptr %_1.0.val, null
  tail call void @llvm.assume(i1 %0)
  %1 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 16
  %_14 = load ptr, ptr %1, align 8, !nonnull !3, !align !52, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %_14, i64 8
  %_19 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_14, i64 16
  %_18 = load i64, ptr %3, align 8, !noundef !3
  %_20 = icmp ult i64 %o, %_18
  br i1 %_20, label %bb4, label %panic

bb4:                                              ; preds = %start
  %_11 = getelementptr inbounds nuw i64, ptr %_19, i64 %o
  %_10 = load i64, ptr %_11, align 8, !noundef !3
  %_15.0 = load ptr, ptr %_1.0.val, align 8, !nonnull !3, !align !52, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 8
  %_15.1 = load i64, ptr %4, align 8, !noundef !3
  %_13 = icmp ult i64 %_10, %_15.1
  br i1 %_13, label %bb3, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %o, i64 noundef %_18, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_623270749f7c2c7eb7abf12a5ce81bec) #21
  unreachable

bb3:                                              ; preds = %bb4
  %5 = getelementptr inbounds nuw %"field::Fp2", ptr %_15.0, i64 %_10
  %_3.0 = load i64, ptr %5, align 8, !noundef !3
  %6 = getelementptr inbounds nuw i8, ptr %5, i64 8
  %_3.1 = load i64, ptr %6, align 8, !noundef !3
  %_6 = add nuw nsw i64 %o, 1
  %_24 = icmp ult i64 %_6, %_18
  br i1 %_24, label %bb6, label %panic2

panic1:                                           ; preds = %bb4
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_10, i64 noundef %_15.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable

bb6:                                              ; preds = %bb3
  %_22 = getelementptr inbounds nuw i64, ptr %_19, i64 %_6
  %_21 = load i64, ptr %_22, align 8, !noundef !3
  %_23 = icmp ult i64 %_21, %_15.1
  br i1 %_23, label %bb5, label %panic3

panic2:                                           ; preds = %bb3
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_6, i64 noundef %_18, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_623270749f7c2c7eb7abf12a5ce81bec) #21
  unreachable

bb5:                                              ; preds = %bb6
  %7 = getelementptr inbounds nuw %"field::Fp2", ptr %_15.0, i64 %_21
  %_5.0 = load i64, ptr %7, align 8, !noundef !3
  %8 = getelementptr inbounds nuw i8, ptr %7, i64 8
  %_5.1 = load i64, ptr %8, align 8, !noundef !3
  %9 = icmp ne ptr %_1.8.val, null
  tail call void @llvm.assume(i1 %9)
  %_7.0 = load i64, ptr %_1.8.val, align 8, !noundef !3
  %10 = getelementptr inbounds nuw i8, ptr %_1.8.val, i64 8
  %_7.1 = load i64, ptr %10, align 8, !noundef !3
  %_11.i = zext i64 %_5.0 to i128
  %_12.i = zext i64 %_7.0 to i128
  %_10.i4 = mul nuw i128 %_12.i, %_11.i
  %x_lo.i58 = trunc i128 %_10.i4 to i64
  %_4.i59 = lshr i128 %_10.i4, 64
  %x_hi.i60 = trunc nuw i128 %_4.i59 to i64
  %x_hi_hi.i61 = lshr i64 %x_hi.i60, 32
  %x_hi_lo.i62 = and i64 %x_hi.i60, 4294967295
  %_9.0.i63 = sub i64 %x_lo.i58, %x_hi_hi.i61
  %_9.1.i64 = icmp ugt i64 %x_hi_hi.i61, %x_lo.i58
  %_10.i65 = add i64 %_9.0.i63, -4294967295
  %spec.select.i66 = select i1 %_9.1.i64, i64 %_10.i65, i64 %_9.0.i63
  %t1.i67 = mul nuw i64 %x_hi_lo.i62, 4294967295
  %_14.0.i68 = add i64 %spec.select.i66, %t1.i67
  %_14.1.i69 = icmp ult i64 %_14.0.i68, %spec.select.i66
  %11 = add i64 %_14.0.i68, 4294967295
  %res.sroa.0.0.i70 = select i1 %_14.1.i69, i64 %11, i64 %_14.0.i68
  %_16.i71 = icmp ugt i64 %res.sroa.0.0.i70, -4294967296
  %_17.i72 = add nsw i64 %res.sroa.0.0.i70, 4294967295
  %_0.sroa.0.0.i73 = select i1 %_16.i71, i64 %_17.i72, i64 %res.sroa.0.0.i70
  %_14.i = zext i64 %_5.1 to i128
  %_15.i5 = zext i64 %_7.1 to i128
  %_13.i = mul nuw i128 %_15.i5, %_14.i
  %x_lo.i42 = trunc i128 %_13.i to i64
  %_4.i43 = lshr i128 %_13.i, 64
  %x_hi.i44 = trunc nuw i128 %_4.i43 to i64
  %x_hi_hi.i45 = lshr i64 %x_hi.i44, 32
  %x_hi_lo.i46 = and i64 %x_hi.i44, 4294967295
  %_9.0.i47 = sub i64 %x_lo.i42, %x_hi_hi.i45
  %_9.1.i48 = icmp ugt i64 %x_hi_hi.i45, %x_lo.i42
  %_10.i49 = add i64 %_9.0.i47, -4294967295
  %spec.select.i50 = select i1 %_9.1.i48, i64 %_10.i49, i64 %_9.0.i47
  %t1.i51 = mul nuw i64 %x_hi_lo.i46, 4294967295
  %_14.0.i52 = add i64 %spec.select.i50, %t1.i51
  %_14.1.i53 = icmp ult i64 %_14.0.i52, %spec.select.i50
  %12 = add i64 %_14.0.i52, 4294967295
  %res.sroa.0.0.i54 = select i1 %_14.1.i53, i64 %12, i64 %_14.0.i52
  %_16.i55 = icmp ugt i64 %res.sroa.0.0.i54, -4294967296
  %_17.i56 = add nsw i64 %res.sroa.0.0.i54, 4294967295
  %_0.sroa.0.0.i57 = select i1 %_16.i55, i64 %_17.i56, i64 %res.sroa.0.0.i54
  %_16.i6 = mul nuw i128 %_15.i5, %_11.i
  %x_lo.i26 = trunc i128 %_16.i6 to i64
  %_4.i27 = lshr i128 %_16.i6, 64
  %x_hi.i28 = trunc nuw i128 %_4.i27 to i64
  %x_hi_hi.i29 = lshr i64 %x_hi.i28, 32
  %x_hi_lo.i30 = and i64 %x_hi.i28, 4294967295
  %_9.0.i31 = sub i64 %x_lo.i26, %x_hi_hi.i29
  %_9.1.i32 = icmp ugt i64 %x_hi_hi.i29, %x_lo.i26
  %_10.i33 = add i64 %_9.0.i31, -4294967295
  %spec.select.i34 = select i1 %_9.1.i32, i64 %_10.i33, i64 %_9.0.i31
  %t1.i35 = mul nuw i64 %x_hi_lo.i30, 4294967295
  %_14.0.i36 = add i64 %spec.select.i34, %t1.i35
  %_14.1.i37 = icmp ult i64 %_14.0.i36, %spec.select.i34
  %13 = add i64 %_14.0.i36, 4294967295
  %res.sroa.0.0.i38 = select i1 %_14.1.i37, i64 %13, i64 %_14.0.i36
  %_16.i39 = icmp ugt i64 %res.sroa.0.0.i38, -4294967296
  %_17.i40 = add nsw i64 %res.sroa.0.0.i38, 4294967295
  %_0.sroa.0.0.i41 = select i1 %_16.i39, i64 %_17.i40, i64 %res.sroa.0.0.i38
  %_17.i = mul nuw i128 %_12.i, %_14.i
  %x_lo.i10 = trunc i128 %_17.i to i64
  %_4.i11 = lshr i128 %_17.i, 64
  %x_hi.i12 = trunc nuw i128 %_4.i11 to i64
  %x_hi_hi.i13 = lshr i64 %x_hi.i12, 32
  %x_hi_lo.i14 = and i64 %x_hi.i12, 4294967295
  %_9.0.i15 = sub i64 %x_lo.i10, %x_hi_hi.i13
  %_9.1.i16 = icmp ugt i64 %x_hi_hi.i13, %x_lo.i10
  %_10.i17 = add i64 %_9.0.i15, -4294967295
  %spec.select.i18 = select i1 %_9.1.i16, i64 %_10.i17, i64 %_9.0.i15
  %t1.i19 = mul nuw i64 %x_hi_lo.i14, 4294967295
  %_14.0.i20 = add i64 %spec.select.i18, %t1.i19
  %_14.1.i21 = icmp ult i64 %_14.0.i20, %spec.select.i18
  %14 = add i64 %_14.0.i20, 4294967295
  %res.sroa.0.0.i22 = select i1 %_14.1.i21, i64 %14, i64 %_14.0.i20
  %_16.i23 = icmp ugt i64 %res.sroa.0.0.i22, -4294967296
  %_17.i24 = add nsw i64 %res.sroa.0.0.i22, 4294967295
  %_0.sroa.0.0.i25 = select i1 %_16.i23, i64 %_17.i24, i64 %res.sroa.0.0.i22
  %_19.i = zext i64 %_0.sroa.0.0.i57 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i = trunc i128 %_18.i to i64
  %_4.i = lshr i128 %_18.i, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %15 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %15, i64 %_14.0.i
  %_16.i8 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i9 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i8, i64 %_17.i9, i64 %res.sroa.0.0.i
  %_22.0.i = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i73
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i73
  %16 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %16, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i41, %_0.sroa.0.0.i25
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i41
  %17 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %17, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %_3.0
  %_7.1.i = icmp ult i64 %_7.0.i, %_3.0
  %18 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %18, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %_3.1
  %_13.1.i = icmp ult i64 %_13.0.i, %_3.1
  %19 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %19, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %20 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i, 0
  %21 = insertvalue { i64, i64 } %20, i64 %_4.sroa.0.0.i, 1
  ret { i64, i64 } %21

panic3:                                           ; preds = %bb6
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_21, i64 noundef %_15.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable
}

; isolated::factory_3::{closure#1}::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_(ptr readonly captures(address_is_null) %_1.0.val, ptr readonly captures(address_is_null) %_1.8.val, i64 noundef range(i64 71, 77) %o) unnamed_addr #2 {
start:
  %0 = icmp ne ptr %_1.0.val, null
  tail call void @llvm.assume(i1 %0)
  %1 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 16
  %_12 = load ptr, ptr %1, align 8, !nonnull !3, !align !52, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %_12, i64 8
  %_17 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_12, i64 16
  %_16 = load i64, ptr %3, align 8, !noundef !3
  %_18 = icmp ult i64 %o, %_16
  br i1 %_18, label %bb3, label %panic

bb3:                                              ; preds = %start
  %_9 = getelementptr inbounds nuw i64, ptr %_17, i64 %o
  %_8 = load i64, ptr %_9, align 8, !noundef !3
  %_13.0 = load ptr, ptr %_1.0.val, align 8, !nonnull !3, !align !52, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %_1.0.val, i64 8
  %_13.1 = load i64, ptr %4, align 8, !noundef !3
  %_11 = icmp ult i64 %_8, %_13.1
  br i1 %_11, label %bb2, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %o, i64 noundef %_16, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3473ff63602946e5bae196369fb1e157) #21
  unreachable

bb2:                                              ; preds = %bb3
  %5 = getelementptr inbounds nuw %"field::Fp2", ptr %_13.0, i64 %_8
  %_3.0 = load i64, ptr %5, align 8, !noundef !3
  %6 = getelementptr inbounds nuw i8, ptr %5, i64 8
  %_3.1 = load i64, ptr %6, align 8, !noundef !3
  %_5 = add nuw nsw i64 %o, 1
  %_22 = icmp ult i64 %_5, %_16
  br i1 %_22, label %bb5, label %panic2

panic1:                                           ; preds = %bb3
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_8, i64 noundef %_13.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable

bb5:                                              ; preds = %bb2
  %_20 = getelementptr inbounds nuw i64, ptr %_17, i64 %_5
  %_19 = load i64, ptr %_20, align 8, !noundef !3
  %_21 = icmp ult i64 %_19, %_13.1
  br i1 %_21, label %bb4, label %panic3

panic2:                                           ; preds = %bb2
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_5, i64 noundef %_16, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3473ff63602946e5bae196369fb1e157) #21
  unreachable

bb4:                                              ; preds = %bb5
  %7 = getelementptr inbounds nuw %"field::Fp2", ptr %_13.0, i64 %_19
  %_31 = load i64, ptr %7, align 8, !noundef !3
  %8 = getelementptr inbounds nuw i8, ptr %7, i64 8
  %_32 = load i64, ptr %8, align 8, !noundef !3
  %9 = icmp ne ptr %_1.8.val, null
  tail call void @llvm.assume(i1 %9)
  %_30 = load i64, ptr %_1.8.val, align 8, !noundef !3
  %_26 = zext i64 %_31 to i128
  %_27 = zext i64 %_30 to i128
  %_25 = mul nuw i128 %_27, %_26
  %x_lo.i6 = trunc i128 %_25 to i64
  %_4.i7 = lshr i128 %_25, 64
  %x_hi.i8 = trunc nuw i128 %_4.i7 to i64
  %x_hi_hi.i9 = lshr i64 %x_hi.i8, 32
  %x_hi_lo.i10 = and i64 %x_hi.i8, 4294967295
  %_9.0.i11 = sub i64 %x_lo.i6, %x_hi_hi.i9
  %_9.1.i12 = icmp ugt i64 %x_hi_hi.i9, %x_lo.i6
  %_10.i13 = add i64 %_9.0.i11, -4294967295
  %spec.select.i14 = select i1 %_9.1.i12, i64 %_10.i13, i64 %_9.0.i11
  %t1.i15 = mul nuw i64 %x_hi_lo.i10, 4294967295
  %_14.0.i16 = add i64 %spec.select.i14, %t1.i15
  %_14.1.i17 = icmp ult i64 %_14.0.i16, %spec.select.i14
  %10 = add i64 %_14.0.i16, 4294967295
  %res.sroa.0.0.i18 = select i1 %_14.1.i17, i64 %10, i64 %_14.0.i16
  %_16.i19 = icmp ugt i64 %res.sroa.0.0.i18, -4294967296
  %_17.i20 = add nsw i64 %res.sroa.0.0.i18, 4294967295
  %_0.sroa.0.0.i21 = select i1 %_16.i19, i64 %_17.i20, i64 %res.sroa.0.0.i18
  %_29 = zext i64 %_32 to i128
  %_28 = mul nuw i128 %_27, %_29
  %x_lo.i = trunc i128 %_28 to i64
  %_4.i = lshr i128 %_28, 64
  %x_hi.i = trunc nuw i128 %_4.i to i64
  %x_hi_hi.i = lshr i64 %x_hi.i, 32
  %x_hi_lo.i = and i64 %x_hi.i, 4294967295
  %_9.0.i = sub i64 %x_lo.i, %x_hi_hi.i
  %_9.1.i = icmp ugt i64 %x_hi_hi.i, %x_lo.i
  %_10.i4 = add i64 %_9.0.i, -4294967295
  %spec.select.i = select i1 %_9.1.i, i64 %_10.i4, i64 %_9.0.i
  %t1.i = mul nuw i64 %x_hi_lo.i, 4294967295
  %_14.0.i = add i64 %spec.select.i, %t1.i
  %_14.1.i = icmp ult i64 %_14.0.i, %spec.select.i
  %11 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %11, i64 %_14.0.i
  %_16.i5 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i5, i64 %_17.i, i64 %res.sroa.0.0.i
  %_7.0.i = add i64 %_0.sroa.0.0.i21, %_3.0
  %_7.1.i = icmp ult i64 %_7.0.i, %_3.0
  %12 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %12, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_0.sroa.0.0.i, %_3.1
  %_13.1.i = icmp ult i64 %_13.0.i, %_3.1
  %13 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %13, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %14 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i, 0
  %15 = insertvalue { i64, i64 } %14, i64 %_4.sroa.0.0.i, 1
  ret { i64, i64 } %15

panic3:                                           ; preds = %bb5
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_19, i64 noundef %_13.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable
}

; isolated::helper_sum::{closure#0}
; Function Attrs: inlinehint nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_(ptr noalias noundef nonnull readonly align 8 captures(none) dereferenceable(24) %_1, ptr noalias noundef nonnull readonly align 8 captures(none) dereferenceable(40) %l) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
  %_7 = load ptr, ptr %_1, align 8, !nonnull !3, !align !52, !noundef !3
  %_33 = load i64, ptr %_7, align 8, !noundef !3
  %0 = getelementptr inbounds nuw i8, ptr %_7, i64 8
  %_34 = load i64, ptr %0, align 8, !noundef !3
  %1 = getelementptr inbounds nuw i8, ptr %l, i64 8
  %_12 = load ptr, ptr %1, align 8, !nonnull !3, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %l, i64 16
  %_11 = load i64, ptr %2, align 8, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %l, i64 24
  %_5.0 = load i64, ptr %3, align 8, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %l, i64 32
  %_5.1 = load i64, ptr %4, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %_8.0 = load ptr, ptr %5, align 8, !nonnull !3, !align !52, !noundef !3
  %6 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  %_8.1 = load i64, ptr %6, align 8, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !53)
  %7 = icmp eq i64 %_11, 0
  br i1 %7, label %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjNtNtCsl0YfJI2rrfI_8isolated5field2FpEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldNtBU_3Fp2NCNCNvBW_10helper_sum00EBW_.exit, label %bb8.i

bb8.i:                                            ; preds = %start, %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i
  %i.sroa.0.0.i = phi i64 [ %_27.i, %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i ], [ 0, %start ]
  %acc.sroa.6.0.i = phi i64 [ %_4.sroa.0.0.i.i.i, %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i ], [ %_5.1, %start ]
  %acc.sroa.0.0.i = phi i64 [ %_3.sroa.0.0.i.i.i, %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i ], [ %_5.0, %start ]
  %_45.i = getelementptr inbounds nuw { i64, i64 }, ptr %_12, i64 %i.sroa.0.0.i
  %_45.val.i = load i64, ptr %_45.i, align 8, !noalias !53, !noundef !3
  %_9.i.i = icmp ult i64 %_45.val.i, %_8.1
  br i1 %_9.i.i, label %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i, label %panic.i.i

panic.i.i:                                        ; preds = %bb8.i
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_45.val.i, i64 noundef %_8.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_239c1709703ec0aea80b5578885ba055) #21, !noalias !53
  unreachable

_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i: ; preds = %bb8.i
  %8 = getelementptr i8, ptr %_45.i, i64 8
  %_45.val6.i = load i64, ptr %8, align 8, !noalias !53
  %9 = getelementptr inbounds nuw %"field::Fp2", ptr %_8.0, i64 %_45.val.i
  %_20.i.i = load i64, ptr %9, align 8, !alias.scope !53, !noundef !3
  %10 = getelementptr inbounds nuw i8, ptr %9, i64 8
  %_21.i.i = load i64, ptr %10, align 8, !alias.scope !53, !noundef !3
  %_15.i.i = zext i64 %_20.i.i to i128
  %_16.i.i = zext i64 %_45.val6.i to i128
  %_14.i.i = mul nuw i128 %_15.i.i, %_16.i.i
  %x_lo.i3.i.i = trunc i128 %_14.i.i to i64
  %_4.i4.i.i = lshr i128 %_14.i.i, 64
  %x_hi.i5.i.i = trunc nuw i128 %_4.i4.i.i to i64
  %x_hi_hi.i6.i.i = lshr i64 %x_hi.i5.i.i, 32
  %x_hi_lo.i7.i.i = and i64 %x_hi.i5.i.i, 4294967295
  %_9.0.i8.i.i = sub i64 %x_lo.i3.i.i, %x_hi_hi.i6.i.i
  %_9.1.i9.i.i = icmp ugt i64 %x_hi_hi.i6.i.i, %x_lo.i3.i.i
  %_10.i10.i.i = add i64 %_9.0.i8.i.i, -4294967295
  %spec.select.i11.i.i = select i1 %_9.1.i9.i.i, i64 %_10.i10.i.i, i64 %_9.0.i8.i.i
  %t1.i12.i.i = mul nuw i64 %x_hi_lo.i7.i.i, 4294967295
  %_14.0.i13.i.i = add i64 %spec.select.i11.i.i, %t1.i12.i.i
  %_14.1.i14.i.i = icmp ult i64 %_14.0.i13.i.i, %spec.select.i11.i.i
  %11 = add i64 %_14.0.i13.i.i, 4294967295
  %res.sroa.0.0.i15.i.i = select i1 %_14.1.i14.i.i, i64 %11, i64 %_14.0.i13.i.i
  %_16.i16.i.i = icmp ugt i64 %res.sroa.0.0.i15.i.i, -4294967296
  %_17.i17.i.i = add nsw i64 %res.sroa.0.0.i15.i.i, 4294967295
  %_0.sroa.0.0.i18.i.i = select i1 %_16.i16.i.i, i64 %_17.i17.i.i, i64 %res.sroa.0.0.i15.i.i
  %_18.i.i = zext i64 %_21.i.i to i128
  %_17.i.i = mul nuw i128 %_18.i.i, %_16.i.i
  %x_lo.i.i.i = trunc i128 %_17.i.i to i64
  %_4.i.i.i = lshr i128 %_17.i.i, 64
  %x_hi.i.i.i = trunc nuw i128 %_4.i.i.i to i64
  %x_hi_hi.i.i.i = lshr i64 %x_hi.i.i.i, 32
  %x_hi_lo.i.i.i = and i64 %x_hi.i.i.i, 4294967295
  %_9.0.i.i.i = sub i64 %x_lo.i.i.i, %x_hi_hi.i.i.i
  %_9.1.i.i.i = icmp ugt i64 %x_hi_hi.i.i.i, %x_lo.i.i.i
  %_10.i1.i.i = add i64 %_9.0.i.i.i, -4294967295
  %spec.select.i.i.i = select i1 %_9.1.i.i.i, i64 %_10.i1.i.i, i64 %_9.0.i.i.i
  %t1.i.i.i = mul nuw i64 %x_hi_lo.i.i.i, 4294967295
  %_14.0.i.i.i = add i64 %spec.select.i.i.i, %t1.i.i.i
  %_14.1.i.i.i = icmp ult i64 %_14.0.i.i.i, %spec.select.i.i.i
  %12 = add i64 %_14.0.i.i.i, 4294967295
  %res.sroa.0.0.i.i.i = select i1 %_14.1.i.i.i, i64 %12, i64 %_14.0.i.i.i
  %_16.i2.i.i = icmp ugt i64 %res.sroa.0.0.i.i.i, -4294967296
  %_17.i.i.i = add nsw i64 %res.sroa.0.0.i.i.i, 4294967295
  %_0.sroa.0.0.i.i.i = select i1 %_16.i2.i.i, i64 %_17.i.i.i, i64 %res.sroa.0.0.i.i.i
  %_7.0.i.i.i = add i64 %_0.sroa.0.0.i18.i.i, %acc.sroa.0.0.i
  %_7.1.i.i.i = icmp ult i64 %_7.0.i.i.i, %acc.sroa.0.0.i
  %13 = add i64 %_7.0.i.i.i, 4294967295
  %_8.sroa.0.0.i.i.i = select i1 %_7.1.i.i.i, i64 %13, i64 %_7.0.i.i.i
  %_9.i.i.i = icmp ugt i64 %_8.sroa.0.0.i.i.i, -4294967296
  %_10.i.i.i = add nsw i64 %_8.sroa.0.0.i.i.i, 4294967295
  %_3.sroa.0.0.i.i.i = select i1 %_9.i.i.i, i64 %_10.i.i.i, i64 %_8.sroa.0.0.i.i.i
  %_13.0.i.i.i = add i64 %_0.sroa.0.0.i.i.i, %acc.sroa.6.0.i
  %_13.1.i.i.i = icmp ult i64 %_13.0.i.i.i, %acc.sroa.6.0.i
  %14 = add i64 %_13.0.i.i.i, 4294967295
  %_14.sroa.0.0.i.i.i = select i1 %_13.1.i.i.i, i64 %14, i64 %_13.0.i.i.i
  %_15.i.i.i = icmp ugt i64 %_14.sroa.0.0.i.i.i, -4294967296
  %_16.i.i.i = add nsw i64 %_14.sroa.0.0.i.i.i, 4294967295
  %_4.sroa.0.0.i.i.i = select i1 %_15.i.i.i, i64 %_16.i.i.i, i64 %_14.sroa.0.0.i.i.i
  %_27.i = add nuw i64 %i.sroa.0.0.i, 1
  %_28.i = icmp eq i64 %_27.i, %_11
  br i1 %_28.i, label %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjNtNtCsl0YfJI2rrfI_8isolated5field2FpEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldNtBU_3Fp2NCNCNvBW_10helper_sum00EBW_.exit, label %bb8.i

_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjNtNtCsl0YfJI2rrfI_8isolated5field2FpEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldNtBU_3Fp2NCNCNvBW_10helper_sum00EBW_.exit: ; preds = %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i, %start
  %init.0.pn.i = phi i64 [ %_5.0, %start ], [ %_3.sroa.0.0.i.i.i, %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i ]
  %init.1.pn.i = phi i64 [ %_5.1, %start ], [ %_4.sroa.0.0.i.i.i, %_RNCNCNvCsl0YfJI2rrfI_8isolated10helper_sum00B5_.exit.i ]
  %_25.0 = sub i64 %_33, %init.0.pn.i
  %_25.1 = icmp ult i64 %_33, %init.0.pn.i
  %15 = add i64 %_25.0, -4294967295
  %_26.sroa.0.0 = select i1 %_25.1, i64 %15, i64 %_25.0
  %_29.0 = sub i64 %_34, %init.1.pn.i
  %_29.1 = icmp ult i64 %_34, %init.1.pn.i
  %16 = add i64 %_29.0, -4294967295
  %_30.sroa.0.0 = select i1 %_29.1, i64 %16, i64 %_29.0
  %17 = insertvalue { i64, i64 } poison, i64 %_26.sroa.0.0, 0
  %18 = insertvalue { i64, i64 } %17, i64 %_30.sroa.0.0, 1
  ret { i64, i64 } %18
}

; isolated::factory_0::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(296) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
  %iter = alloca [96 x i8], align 8
  %at = alloca [24 x i8], align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %at)
  %_4 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  store ptr %v.0, ptr %at, align 8
  %0 = getelementptr inbounds nuw i8, ptr %at, i64 8
  store i64 %v.1, ptr %0, align 8
  %1 = getelementptr inbounds nuw i8, ptr %at, i64 16
  store ptr %_4, ptr %1, align 8
  %_7 = getelementptr inbounds nuw i8, ptr %_1, i64 152
  %2 = getelementptr inbounds nuw i8, ptr %_1, i64 24
  %_101 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_1, i64 32
  %_100 = load i64, ptr %3, align 8, !noundef !3
  %_102 = icmp ugt i64 %_100, 67
  br i1 %_102, label %bb46, label %panic

bb46:                                             ; preds = %start
  %_95 = getelementptr inbounds nuw i8, ptr %_101, i64 536
  %_94 = load i64, ptr %_95, align 8, !noundef !3
  %_97 = icmp ult i64 %_94, %v.1
  br i1 %_97, label %bb45, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 67, i64 noundef %_100, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_14e9b0f3c1e82842e326b949d03d992d) #21
  unreachable

bb45:                                             ; preds = %bb46
  %4 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_94
  %g8.0 = load i64, ptr %4, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 8
  %g8.1 = load i64, ptr %5, align 8, !noundef !3
  %_106 = icmp ugt i64 %_100, 69
  br i1 %_106, label %bb48, label %panic2

panic1:                                           ; preds = %bb46
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_94, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable

bb48:                                             ; preds = %bb45
  %_104 = getelementptr inbounds nuw i8, ptr %_101, i64 552
  %_103 = load i64, ptr %_104, align 8, !noundef !3
  %_105 = icmp ult i64 %_103, %v.1
  br i1 %_105, label %bb47, label %panic3

panic2:                                           ; preds = %bb45
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 69, i64 noundef %_100, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_14e9b0f3c1e82842e326b949d03d992d) #21
  unreachable

bb47:                                             ; preds = %bb48
  %6 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_103
  %a16.0 = load i64, ptr %6, align 8, !noundef !3
  %7 = getelementptr inbounds nuw i8, ptr %6, i64 8
  %a16.1 = load i64, ptr %7, align 8, !noundef !3
  %_110.not = icmp eq i64 %_100, 70
  br i1 %_110.not, label %panic4, label %bb50

panic3:                                           ; preds = %bb48
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_103, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable

bb50:                                             ; preds = %bb47
  %_108 = getelementptr inbounds nuw i8, ptr %_101, i64 560
  %_107 = load i64, ptr %_108, align 8, !noundef !3
  %_109 = icmp ult i64 %_107, %v.1
  br i1 %_109, label %bb49, label %panic5

panic4:                                           ; preds = %bb47
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 70, i64 noundef 70, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_14e9b0f3c1e82842e326b949d03d992d) #21
  unreachable

bb49:                                             ; preds = %bb50
  %8 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_107
  %u16.0 = load i64, ptr %8, align 8, !noundef !3
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 8
  %u16.1 = load i64, ptr %9, align 8, !noundef !3
  %_114 = icmp ugt i64 %_100, 73
  br i1 %_114, label %bb52, label %panic6

panic5:                                           ; preds = %bb50
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_107, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable

bb52:                                             ; preds = %bb49
  %_112 = getelementptr inbounds nuw i8, ptr %_101, i64 584
  %_111 = load i64, ptr %_112, align 8, !noundef !3
  %_113 = icmp ult i64 %_111, %v.1
  br i1 %_113, label %bb51, label %panic7

panic6:                                           ; preds = %bb49
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 73, i64 noundef %_100, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_14e9b0f3c1e82842e326b949d03d992d) #21
  unreachable

bb51:                                             ; preds = %bb52
  %10 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_111
  %h16.0 = load i64, ptr %10, align 8, !noundef !3
  %11 = getelementptr inbounds nuw i8, ptr %10, i64 8
  %h16.1 = load i64, ptr %11, align 8, !noundef !3
  %_11.i517 = zext i64 %a16.0 to i128
  %_12.i518 = zext i64 %u16.0 to i128
  %_10.i519 = mul nuw i128 %_12.i518, %_11.i517
  %x_lo.i595 = trunc i128 %_10.i519 to i64
  %_4.i596 = lshr i128 %_10.i519, 64
  %x_hi.i597 = trunc nuw i128 %_4.i596 to i64
  %x_hi_hi.i598 = lshr i64 %x_hi.i597, 32
  %x_hi_lo.i599 = and i64 %x_hi.i597, 4294967295
  %_9.0.i600 = sub i64 %x_lo.i595, %x_hi_hi.i598
  %_9.1.i601 = icmp ugt i64 %x_hi_hi.i598, %x_lo.i595
  %_10.i602 = add i64 %_9.0.i600, -4294967295
  %spec.select.i603 = select i1 %_9.1.i601, i64 %_10.i602, i64 %_9.0.i600
  %t1.i604 = mul nuw i64 %x_hi_lo.i599, 4294967295
  %_14.0.i605 = add i64 %spec.select.i603, %t1.i604
  %_14.1.i606 = icmp ult i64 %_14.0.i605, %spec.select.i603
  %12 = add i64 %_14.0.i605, 4294967295
  %res.sroa.0.0.i607 = select i1 %_14.1.i606, i64 %12, i64 %_14.0.i605
  %_16.i608 = icmp ugt i64 %res.sroa.0.0.i607, -4294967296
  %_17.i609 = add nsw i64 %res.sroa.0.0.i607, 4294967295
  %_0.sroa.0.0.i610 = select i1 %_16.i608, i64 %_17.i609, i64 %res.sroa.0.0.i607
  %_14.i521 = zext i64 %a16.1 to i128
  %_15.i522 = zext i64 %u16.1 to i128
  %_13.i523 = mul nuw i128 %_15.i522, %_14.i521
  %x_lo.i579 = trunc i128 %_13.i523 to i64
  %_4.i580 = lshr i128 %_13.i523, 64
  %x_hi.i581 = trunc nuw i128 %_4.i580 to i64
  %x_hi_hi.i582 = lshr i64 %x_hi.i581, 32
  %x_hi_lo.i583 = and i64 %x_hi.i581, 4294967295
  %_9.0.i584 = sub i64 %x_lo.i579, %x_hi_hi.i582
  %_9.1.i585 = icmp ugt i64 %x_hi_hi.i582, %x_lo.i579
  %_10.i586 = add i64 %_9.0.i584, -4294967295
  %spec.select.i587 = select i1 %_9.1.i585, i64 %_10.i586, i64 %_9.0.i584
  %t1.i588 = mul nuw i64 %x_hi_lo.i583, 4294967295
  %_14.0.i589 = add i64 %spec.select.i587, %t1.i588
  %_14.1.i590 = icmp ult i64 %_14.0.i589, %spec.select.i587
  %13 = add i64 %_14.0.i589, 4294967295
  %res.sroa.0.0.i591 = select i1 %_14.1.i590, i64 %13, i64 %_14.0.i589
  %_16.i592 = icmp ugt i64 %res.sroa.0.0.i591, -4294967296
  %_17.i593 = add nsw i64 %res.sroa.0.0.i591, 4294967295
  %_0.sroa.0.0.i594 = select i1 %_16.i592, i64 %_17.i593, i64 %res.sroa.0.0.i591
  %_16.i525 = mul nuw i128 %_15.i522, %_11.i517
  %x_lo.i563 = trunc i128 %_16.i525 to i64
  %_4.i564 = lshr i128 %_16.i525, 64
  %x_hi.i565 = trunc nuw i128 %_4.i564 to i64
  %x_hi_hi.i566 = lshr i64 %x_hi.i565, 32
  %x_hi_lo.i567 = and i64 %x_hi.i565, 4294967295
  %_9.0.i568 = sub i64 %x_lo.i563, %x_hi_hi.i566
  %_9.1.i569 = icmp ugt i64 %x_hi_hi.i566, %x_lo.i563
  %_10.i570 = add i64 %_9.0.i568, -4294967295
  %spec.select.i571 = select i1 %_9.1.i569, i64 %_10.i570, i64 %_9.0.i568
  %t1.i572 = mul nuw i64 %x_hi_lo.i567, 4294967295
  %_14.0.i573 = add i64 %spec.select.i571, %t1.i572
  %_14.1.i574 = icmp ult i64 %_14.0.i573, %spec.select.i571
  %14 = add i64 %_14.0.i573, 4294967295
  %res.sroa.0.0.i575 = select i1 %_14.1.i574, i64 %14, i64 %_14.0.i573
  %_16.i576 = icmp ugt i64 %res.sroa.0.0.i575, -4294967296
  %_17.i577 = add nsw i64 %res.sroa.0.0.i575, 4294967295
  %_0.sroa.0.0.i578 = select i1 %_16.i576, i64 %_17.i577, i64 %res.sroa.0.0.i575
  %_17.i527 = mul nuw i128 %_12.i518, %_14.i521
  %x_lo.i547 = trunc i128 %_17.i527 to i64
  %_4.i548 = lshr i128 %_17.i527, 64
  %x_hi.i549 = trunc nuw i128 %_4.i548 to i64
  %x_hi_hi.i550 = lshr i64 %x_hi.i549, 32
  %x_hi_lo.i551 = and i64 %x_hi.i549, 4294967295
  %_9.0.i552 = sub i64 %x_lo.i547, %x_hi_hi.i550
  %_9.1.i553 = icmp ugt i64 %x_hi_hi.i550, %x_lo.i547
  %_10.i554 = add i64 %_9.0.i552, -4294967295
  %spec.select.i555 = select i1 %_9.1.i553, i64 %_10.i554, i64 %_9.0.i552
  %t1.i556 = mul nuw i64 %x_hi_lo.i551, 4294967295
  %_14.0.i557 = add i64 %spec.select.i555, %t1.i556
  %_14.1.i558 = icmp ult i64 %_14.0.i557, %spec.select.i555
  %15 = add i64 %_14.0.i557, 4294967295
  %res.sroa.0.0.i559 = select i1 %_14.1.i558, i64 %15, i64 %_14.0.i557
  %_16.i560 = icmp ugt i64 %res.sroa.0.0.i559, -4294967296
  %_17.i561 = add nsw i64 %res.sroa.0.0.i559, 4294967295
  %_0.sroa.0.0.i562 = select i1 %_16.i560, i64 %_17.i561, i64 %res.sroa.0.0.i559
  %_19.i529 = zext i64 %_0.sroa.0.0.i594 to i128
  %_18.i530 = mul nuw nsw i128 %_19.i529, 7
  %x_lo.i = trunc i128 %_18.i530 to i64
  %_4.i = lshr i128 %_18.i530, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %16 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %16, i64 %_14.0.i
  %_16.i545 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i546 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i545, i64 %_17.i546, i64 %res.sroa.0.0.i
  %_22.0.i532 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i610
  %_22.1.i533 = icmp ult i64 %_22.0.i532, %_0.sroa.0.0.i610
  %17 = add nuw i64 %_22.0.i532, 4294967295
  %_24.sroa.0.0.i534 = select i1 %_22.1.i533, i64 %17, i64 %_22.0.i532
  %_25.i535 = icmp ugt i64 %_24.sroa.0.0.i534, -4294967296
  %_26.i536 = add nsw i64 %_24.sroa.0.0.i534, 4294967295
  %_7.sroa.0.0.i537 = select i1 %_25.i535, i64 %_26.i536, i64 %_24.sroa.0.0.i534
  %_29.0.i538 = add i64 %_0.sroa.0.0.i578, %_0.sroa.0.0.i562
  %_29.1.i539 = icmp ult i64 %_29.0.i538, %_0.sroa.0.0.i578
  %18 = add nuw i64 %_29.0.i538, 4294967295
  %_30.sroa.0.0.i540 = select i1 %_29.1.i539, i64 %18, i64 %_29.0.i538
  %_31.i541 = icmp ugt i64 %_30.sroa.0.0.i540, -4294967296
  %_32.i542 = add nsw i64 %_30.sroa.0.0.i540, 4294967295
  %_9.sroa.0.0.i543 = select i1 %_31.i541, i64 %_32.i542, i64 %_30.sroa.0.0.i540
  %19 = getelementptr inbounds nuw i8, ptr %_1, i64 168
  %_16.0 = load i64, ptr %19, align 8, !noundef !3
  %20 = getelementptr inbounds nuw i8, ptr %_1, i64 176
  %_16.1 = load i64, ptr %20, align 8, !noundef !3
  %_11.i490 = zext i64 %_16.0 to i128
  %_12.i491 = zext i64 %h16.0 to i128
  %_10.i492 = mul nuw i128 %_11.i490, %_12.i491
  %x_lo.i675 = trunc i128 %_10.i492 to i64
  %_4.i676 = lshr i128 %_10.i492, 64
  %x_hi.i677 = trunc nuw i128 %_4.i676 to i64
  %x_hi_hi.i678 = lshr i64 %x_hi.i677, 32
  %x_hi_lo.i679 = and i64 %x_hi.i677, 4294967295
  %_9.0.i680 = sub i64 %x_lo.i675, %x_hi_hi.i678
  %_9.1.i681 = icmp ugt i64 %x_hi_hi.i678, %x_lo.i675
  %_10.i682 = add i64 %_9.0.i680, -4294967295
  %spec.select.i683 = select i1 %_9.1.i681, i64 %_10.i682, i64 %_9.0.i680
  %t1.i684 = mul nuw i64 %x_hi_lo.i679, 4294967295
  %_14.0.i685 = add i64 %spec.select.i683, %t1.i684
  %_14.1.i686 = icmp ult i64 %_14.0.i685, %spec.select.i683
  %21 = add i64 %_14.0.i685, 4294967295
  %res.sroa.0.0.i687 = select i1 %_14.1.i686, i64 %21, i64 %_14.0.i685
  %_16.i688 = icmp ugt i64 %res.sroa.0.0.i687, -4294967296
  %_17.i689 = add nsw i64 %res.sroa.0.0.i687, 4294967295
  %_0.sroa.0.0.i690 = select i1 %_16.i688, i64 %_17.i689, i64 %res.sroa.0.0.i687
  %_14.i494 = zext i64 %_16.1 to i128
  %_15.i495 = zext i64 %h16.1 to i128
  %_13.i496 = mul nuw i128 %_14.i494, %_15.i495
  %x_lo.i659 = trunc i128 %_13.i496 to i64
  %_4.i660 = lshr i128 %_13.i496, 64
  %x_hi.i661 = trunc nuw i128 %_4.i660 to i64
  %x_hi_hi.i662 = lshr i64 %x_hi.i661, 32
  %x_hi_lo.i663 = and i64 %x_hi.i661, 4294967295
  %_9.0.i664 = sub i64 %x_lo.i659, %x_hi_hi.i662
  %_9.1.i665 = icmp ugt i64 %x_hi_hi.i662, %x_lo.i659
  %_10.i666 = add i64 %_9.0.i664, -4294967295
  %spec.select.i667 = select i1 %_9.1.i665, i64 %_10.i666, i64 %_9.0.i664
  %t1.i668 = mul nuw i64 %x_hi_lo.i663, 4294967295
  %_14.0.i669 = add i64 %spec.select.i667, %t1.i668
  %_14.1.i670 = icmp ult i64 %_14.0.i669, %spec.select.i667
  %22 = add i64 %_14.0.i669, 4294967295
  %res.sroa.0.0.i671 = select i1 %_14.1.i670, i64 %22, i64 %_14.0.i669
  %_16.i672 = icmp ugt i64 %res.sroa.0.0.i671, -4294967296
  %_17.i673 = add nsw i64 %res.sroa.0.0.i671, 4294967295
  %_0.sroa.0.0.i674 = select i1 %_16.i672, i64 %_17.i673, i64 %res.sroa.0.0.i671
  %_16.i498 = mul nuw i128 %_11.i490, %_15.i495
  %x_lo.i643 = trunc i128 %_16.i498 to i64
  %_4.i644 = lshr i128 %_16.i498, 64
  %x_hi.i645 = trunc nuw i128 %_4.i644 to i64
  %x_hi_hi.i646 = lshr i64 %x_hi.i645, 32
  %x_hi_lo.i647 = and i64 %x_hi.i645, 4294967295
  %_9.0.i648 = sub i64 %x_lo.i643, %x_hi_hi.i646
  %_9.1.i649 = icmp ugt i64 %x_hi_hi.i646, %x_lo.i643
  %_10.i650 = add i64 %_9.0.i648, -4294967295
  %spec.select.i651 = select i1 %_9.1.i649, i64 %_10.i650, i64 %_9.0.i648
  %t1.i652 = mul nuw i64 %x_hi_lo.i647, 4294967295
  %_14.0.i653 = add i64 %spec.select.i651, %t1.i652
  %_14.1.i654 = icmp ult i64 %_14.0.i653, %spec.select.i651
  %23 = add i64 %_14.0.i653, 4294967295
  %res.sroa.0.0.i655 = select i1 %_14.1.i654, i64 %23, i64 %_14.0.i653
  %_16.i656 = icmp ugt i64 %res.sroa.0.0.i655, -4294967296
  %_17.i657 = add nsw i64 %res.sroa.0.0.i655, 4294967295
  %_0.sroa.0.0.i658 = select i1 %_16.i656, i64 %_17.i657, i64 %res.sroa.0.0.i655
  %_17.i500 = mul nuw i128 %_14.i494, %_12.i491
  %x_lo.i627 = trunc i128 %_17.i500 to i64
  %_4.i628 = lshr i128 %_17.i500, 64
  %x_hi.i629 = trunc nuw i128 %_4.i628 to i64
  %x_hi_hi.i630 = lshr i64 %x_hi.i629, 32
  %x_hi_lo.i631 = and i64 %x_hi.i629, 4294967295
  %_9.0.i632 = sub i64 %x_lo.i627, %x_hi_hi.i630
  %_9.1.i633 = icmp ugt i64 %x_hi_hi.i630, %x_lo.i627
  %_10.i634 = add i64 %_9.0.i632, -4294967295
  %spec.select.i635 = select i1 %_9.1.i633, i64 %_10.i634, i64 %_9.0.i632
  %t1.i636 = mul nuw i64 %x_hi_lo.i631, 4294967295
  %_14.0.i637 = add i64 %spec.select.i635, %t1.i636
  %_14.1.i638 = icmp ult i64 %_14.0.i637, %spec.select.i635
  %24 = add i64 %_14.0.i637, 4294967295
  %res.sroa.0.0.i639 = select i1 %_14.1.i638, i64 %24, i64 %_14.0.i637
  %_16.i640 = icmp ugt i64 %res.sroa.0.0.i639, -4294967296
  %_17.i641 = add nsw i64 %res.sroa.0.0.i639, 4294967295
  %_0.sroa.0.0.i642 = select i1 %_16.i640, i64 %_17.i641, i64 %res.sroa.0.0.i639
  %_19.i502 = zext i64 %_0.sroa.0.0.i674 to i128
  %_18.i503 = mul nuw nsw i128 %_19.i502, 7
  %x_lo.i611 = trunc i128 %_18.i503 to i64
  %_4.i612 = lshr i128 %_18.i503, 64
  %x_hi.i613 = trunc nuw nsw i128 %_4.i612 to i64
  %t1.i620 = mul nuw nsw i64 %x_hi.i613, 4294967295
  %_14.0.i621 = add i64 %t1.i620, %x_lo.i611
  %_14.1.i622 = icmp ult i64 %_14.0.i621, %x_lo.i611
  %25 = add i64 %_14.0.i621, 4294967295
  %res.sroa.0.0.i623 = select i1 %_14.1.i622, i64 %25, i64 %_14.0.i621
  %_16.i624 = icmp ugt i64 %res.sroa.0.0.i623, -4294967296
  %_17.i625 = add nsw i64 %res.sroa.0.0.i623, 4294967295
  %_0.sroa.0.0.i626 = select i1 %_16.i624, i64 %_17.i625, i64 %res.sroa.0.0.i623
  %_22.0.i505 = add i64 %_0.sroa.0.0.i626, %_0.sroa.0.0.i690
  %_22.1.i506 = icmp ult i64 %_22.0.i505, %_0.sroa.0.0.i690
  %26 = add nuw i64 %_22.0.i505, 4294967295
  %_24.sroa.0.0.i507 = select i1 %_22.1.i506, i64 %26, i64 %_22.0.i505
  %_25.i508 = icmp ugt i64 %_24.sroa.0.0.i507, -4294967296
  %_26.i509 = add nsw i64 %_24.sroa.0.0.i507, 4294967295
  %_7.sroa.0.0.i510 = select i1 %_25.i508, i64 %_26.i509, i64 %_24.sroa.0.0.i507
  %_29.0.i511 = add i64 %_0.sroa.0.0.i642, %_0.sroa.0.0.i658
  %_29.1.i512 = icmp ult i64 %_29.0.i511, %_0.sroa.0.0.i658
  %27 = add nuw i64 %_29.0.i511, 4294967295
  %_30.sroa.0.0.i513 = select i1 %_29.1.i512, i64 %27, i64 %_29.0.i511
  %_31.i514 = icmp ugt i64 %_30.sroa.0.0.i513, -4294967296
  %_32.i515 = add nsw i64 %_30.sroa.0.0.i513, 4294967295
  %_9.sroa.0.0.i516 = select i1 %_31.i514, i64 %_32.i515, i64 %_30.sroa.0.0.i513
  %_117.0 = sub i64 %_7.sroa.0.0.i537, %_7.sroa.0.0.i510
  %_117.1 = icmp ult i64 %_7.sroa.0.0.i537, %_7.sroa.0.0.i510
  %28 = add i64 %_117.0, -4294967295
  %_118.sroa.0.0 = select i1 %_117.1, i64 %28, i64 %_117.0
  %_121.0 = sub i64 %_9.sroa.0.0.i543, %_9.sroa.0.0.i516
  %_121.1 = icmp ult i64 %_9.sroa.0.0.i543, %_9.sroa.0.0.i516
  %29 = add i64 %_121.0, -4294967295
  %_122.sroa.0.0 = select i1 %_121.1, i64 %29, i64 %_121.0
; call isolated::factory_0::{closure#1}::{closure#1}
  %30 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 76)
  %_17.0 = extractvalue { i64, i64 } %30, 0
  %_17.1 = extractvalue { i64, i64 } %30, 1
  %_131.0 = sub i64 %_118.sroa.0.0, %_17.0
  %_131.1 = icmp ult i64 %_118.sroa.0.0, %_17.0
  %31 = add i64 %_131.0, -4294967295
  %_132.sroa.0.0 = select i1 %_131.1, i64 %31, i64 %_131.0
  %_135.0 = sub i64 %_122.sroa.0.0, %_17.1
  %_135.1 = icmp ult i64 %_122.sroa.0.0, %_17.1
  %32 = add i64 %_135.0, -4294967295
  %_136.sroa.0.0 = select i1 %_135.1, i64 %32, i64 %_135.0
  %33 = getelementptr inbounds nuw i8, ptr %_1, i64 184
  %_19.0 = load i64, ptr %33, align 8, !noundef !3
  %34 = getelementptr inbounds nuw i8, ptr %_1, i64 192
  %_19.1 = load i64, ptr %34, align 8, !noundef !3
  %_7.0.i146 = add i64 %_132.sroa.0.0, %_19.0
  %_7.1.i147 = icmp ult i64 %_7.0.i146, %_132.sroa.0.0
  %35 = add i64 %_7.0.i146, 4294967295
  %_8.sroa.0.0.i148 = select i1 %_7.1.i147, i64 %35, i64 %_7.0.i146
  %_9.i149 = icmp ugt i64 %_8.sroa.0.0.i148, -4294967296
  %_10.i150 = add nsw i64 %_8.sroa.0.0.i148, 4294967295
  %_3.sroa.0.0.i151 = select i1 %_9.i149, i64 %_10.i150, i64 %_8.sroa.0.0.i148
  %_13.0.i152 = add i64 %_136.sroa.0.0, %_19.1
  %_13.1.i153 = icmp ult i64 %_13.0.i152, %_136.sroa.0.0
  %36 = add i64 %_13.0.i152, 4294967295
  %_14.sroa.0.0.i154 = select i1 %_13.1.i153, i64 %36, i64 %_13.0.i152
  %_15.i155 = icmp ugt i64 %_14.sroa.0.0.i154, -4294967296
  %_16.i156 = add nsw i64 %_14.sroa.0.0.i154, 4294967295
  %_4.sroa.0.0.i157 = select i1 %_15.i155, i64 %_16.i156, i64 %_14.sroa.0.0.i154
  %_7.1.i135 = icmp ugt i64 %u16.0, -32769
  %_8.sroa.0.0.i136.v = select i1 %_7.1.i135, i64 4295000063, i64 32768
  %_8.sroa.0.0.i136 = add i64 %_8.sroa.0.0.i136.v, %u16.0
  %_9.i137 = icmp ugt i64 %_8.sroa.0.0.i136, -4294967296
  %_10.i138 = add nsw i64 %_8.sroa.0.0.i136, 4294967295
  %_3.sroa.0.0.i139 = select i1 %_9.i137, i64 %_10.i138, i64 %_8.sroa.0.0.i136
  %_15.i143 = icmp ugt i64 %u16.1, -4294967296
  %_16.i144 = add nsw i64 %u16.1, 4294967295
  %_4.sroa.0.0.i145 = select i1 %_15.i143, i64 %_16.i144, i64 %u16.1
; call isolated::factory_0::{closure#1}::{closure#1}
  %37 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 71)
  %_23.0 = extractvalue { i64, i64 } %37, 0
  %_23.1 = extractvalue { i64, i64 } %37, 1
  %_144.0 = sub i64 %_3.sroa.0.0.i139, %_23.0
  %_144.1 = icmp ult i64 %_3.sroa.0.0.i139, %_23.0
  %38 = add i64 %_144.0, -4294967295
  %_145.sroa.0.0 = select i1 %_144.1, i64 %38, i64 %_144.0
  %_148.0 = sub i64 %_4.sroa.0.0.i145, %_23.1
  %_148.1 = icmp ult i64 %_4.sroa.0.0.i145, %_23.1
  %39 = add i64 %_148.0, -4294967295
  %_149.sroa.0.0 = select i1 %_148.1, i64 %39, i64 %_148.0
  %_7.1.i123 = icmp ugt i64 %h16.0, -32769
  %_8.sroa.0.0.i124.v = select i1 %_7.1.i123, i64 4295000063, i64 32768
  %_8.sroa.0.0.i124 = add i64 %_8.sroa.0.0.i124.v, %h16.0
  %_9.i125 = icmp ugt i64 %_8.sroa.0.0.i124, -4294967296
  %_10.i126 = add nsw i64 %_8.sroa.0.0.i124, 4294967295
  %_3.sroa.0.0.i127 = select i1 %_9.i125, i64 %_10.i126, i64 %_8.sroa.0.0.i124
  %_15.i131 = icmp ugt i64 %h16.1, -4294967296
  %_16.i132 = add nsw i64 %h16.1, 4294967295
  %_4.sroa.0.0.i133 = select i1 %_15.i131, i64 %_16.i132, i64 %h16.1
; call isolated::factory_0::{closure#1}::{closure#1}
  %40 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 74)
  %_28.0 = extractvalue { i64, i64 } %40, 0
  %_28.1 = extractvalue { i64, i64 } %40, 1
  %_159.0 = sub i64 %_3.sroa.0.0.i127, %_28.0
  %_159.1 = icmp ult i64 %_3.sroa.0.0.i127, %_28.0
  %41 = add i64 %_159.0, -4294967295
  %_160.sroa.0.0 = select i1 %_159.1, i64 %41, i64 %_159.0
  %_163.0 = sub i64 %_4.sroa.0.0.i133, %_28.1
  %_163.1 = icmp ult i64 %_4.sroa.0.0.i133, %_28.1
  %42 = add i64 %_163.0, -4294967295
  %_164.sroa.0.0 = select i1 %_163.1, i64 %42, i64 %_163.0
  %43 = getelementptr inbounds nuw i8, ptr %_1, i64 200
  %_33 = load i64, ptr %43, align 8, !noundef !3
  %_34 = icmp ult i64 %_33, %v.1
  br i1 %_34, label %bb9, label %panic8

panic7:                                           ; preds = %bb52
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_111, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable

bb9:                                              ; preds = %bb51
  %44 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_33
  %_32.0 = load i64, ptr %44, align 8, !noundef !3
  %45 = getelementptr inbounds nuw i8, ptr %44, i64 8
  %_32.1 = load i64, ptr %45, align 8, !noundef !3
  %46 = getelementptr inbounds nuw i8, ptr %_1, i64 208
  %_240 = load i64, ptr %46, align 8, !noundef !3
  %47 = getelementptr inbounds nuw i8, ptr %_1, i64 216
  %_241 = load i64, ptr %47, align 8, !noundef !3
  %_7.1.i111 = icmp ugt i64 %g8.0, -129
  %_8.sroa.0.0.i112.v = select i1 %_7.1.i111, i64 4294967423, i64 128
  %_8.sroa.0.0.i112 = add i64 %_8.sroa.0.0.i112.v, %g8.0
  %_9.i113 = icmp ugt i64 %_8.sroa.0.0.i112, -4294967296
  %_10.i114 = add nsw i64 %_8.sroa.0.0.i112, 4294967295
  %_3.sroa.0.0.i115 = select i1 %_9.i113, i64 %_10.i114, i64 %_8.sroa.0.0.i112
  %_15.i119 = icmp ugt i64 %g8.1, -4294967296
  %_16.i120 = add nsw i64 %g8.1, 4294967295
  %_4.sroa.0.0.i121 = select i1 %_15.i119, i64 %_16.i120, i64 %g8.1
  %48 = getelementptr inbounds nuw i8, ptr %_1, i64 224
  %_41.0 = load i64, ptr %48, align 8, !noundef !3
  %49 = getelementptr inbounds nuw i8, ptr %_1, i64 232
  %_41.1 = load i64, ptr %49, align 8, !noundef !3
  %_11.i463 = zext i64 %_41.0 to i128
  %_10.i465 = mul nuw i128 %_11.i463, %_11.i517
  %x_lo.i755 = trunc i128 %_10.i465 to i64
  %_4.i756 = lshr i128 %_10.i465, 64
  %x_hi.i757 = trunc nuw i128 %_4.i756 to i64
  %x_hi_hi.i758 = lshr i64 %x_hi.i757, 32
  %x_hi_lo.i759 = and i64 %x_hi.i757, 4294967295
  %_9.0.i760 = sub i64 %x_lo.i755, %x_hi_hi.i758
  %_9.1.i761 = icmp ugt i64 %x_hi_hi.i758, %x_lo.i755
  %_10.i762 = add i64 %_9.0.i760, -4294967295
  %spec.select.i763 = select i1 %_9.1.i761, i64 %_10.i762, i64 %_9.0.i760
  %t1.i764 = mul nuw i64 %x_hi_lo.i759, 4294967295
  %_14.0.i765 = add i64 %spec.select.i763, %t1.i764
  %_14.1.i766 = icmp ult i64 %_14.0.i765, %spec.select.i763
  %50 = add i64 %_14.0.i765, 4294967295
  %res.sroa.0.0.i767 = select i1 %_14.1.i766, i64 %50, i64 %_14.0.i765
  %_16.i768 = icmp ugt i64 %res.sroa.0.0.i767, -4294967296
  %_17.i769 = add nsw i64 %res.sroa.0.0.i767, 4294967295
  %_0.sroa.0.0.i770 = select i1 %_16.i768, i64 %_17.i769, i64 %res.sroa.0.0.i767
  %_14.i467 = zext i64 %_41.1 to i128
  %_13.i469 = mul nuw i128 %_14.i467, %_14.i521
  %x_lo.i739 = trunc i128 %_13.i469 to i64
  %_4.i740 = lshr i128 %_13.i469, 64
  %x_hi.i741 = trunc nuw i128 %_4.i740 to i64
  %x_hi_hi.i742 = lshr i64 %x_hi.i741, 32
  %x_hi_lo.i743 = and i64 %x_hi.i741, 4294967295
  %_9.0.i744 = sub i64 %x_lo.i739, %x_hi_hi.i742
  %_9.1.i745 = icmp ugt i64 %x_hi_hi.i742, %x_lo.i739
  %_10.i746 = add i64 %_9.0.i744, -4294967295
  %spec.select.i747 = select i1 %_9.1.i745, i64 %_10.i746, i64 %_9.0.i744
  %t1.i748 = mul nuw i64 %x_hi_lo.i743, 4294967295
  %_14.0.i749 = add i64 %spec.select.i747, %t1.i748
  %_14.1.i750 = icmp ult i64 %_14.0.i749, %spec.select.i747
  %51 = add i64 %_14.0.i749, 4294967295
  %res.sroa.0.0.i751 = select i1 %_14.1.i750, i64 %51, i64 %_14.0.i749
  %_16.i752 = icmp ugt i64 %res.sroa.0.0.i751, -4294967296
  %_17.i753 = add nsw i64 %res.sroa.0.0.i751, 4294967295
  %_0.sroa.0.0.i754 = select i1 %_16.i752, i64 %_17.i753, i64 %res.sroa.0.0.i751
  %_16.i471 = mul nuw i128 %_11.i463, %_14.i521
  %x_lo.i723 = trunc i128 %_16.i471 to i64
  %_4.i724 = lshr i128 %_16.i471, 64
  %x_hi.i725 = trunc nuw i128 %_4.i724 to i64
  %x_hi_hi.i726 = lshr i64 %x_hi.i725, 32
  %x_hi_lo.i727 = and i64 %x_hi.i725, 4294967295
  %_9.0.i728 = sub i64 %x_lo.i723, %x_hi_hi.i726
  %_9.1.i729 = icmp ugt i64 %x_hi_hi.i726, %x_lo.i723
  %_10.i730 = add i64 %_9.0.i728, -4294967295
  %spec.select.i731 = select i1 %_9.1.i729, i64 %_10.i730, i64 %_9.0.i728
  %t1.i732 = mul nuw i64 %x_hi_lo.i727, 4294967295
  %_14.0.i733 = add i64 %spec.select.i731, %t1.i732
  %_14.1.i734 = icmp ult i64 %_14.0.i733, %spec.select.i731
  %52 = add i64 %_14.0.i733, 4294967295
  %res.sroa.0.0.i735 = select i1 %_14.1.i734, i64 %52, i64 %_14.0.i733
  %_16.i736 = icmp ugt i64 %res.sroa.0.0.i735, -4294967296
  %_17.i737 = add nsw i64 %res.sroa.0.0.i735, 4294967295
  %_0.sroa.0.0.i738 = select i1 %_16.i736, i64 %_17.i737, i64 %res.sroa.0.0.i735
  %_17.i473 = mul nuw i128 %_14.i467, %_11.i517
  %x_lo.i707 = trunc i128 %_17.i473 to i64
  %_4.i708 = lshr i128 %_17.i473, 64
  %x_hi.i709 = trunc nuw i128 %_4.i708 to i64
  %x_hi_hi.i710 = lshr i64 %x_hi.i709, 32
  %x_hi_lo.i711 = and i64 %x_hi.i709, 4294967295
  %_9.0.i712 = sub i64 %x_lo.i707, %x_hi_hi.i710
  %_9.1.i713 = icmp ugt i64 %x_hi_hi.i710, %x_lo.i707
  %_10.i714 = add i64 %_9.0.i712, -4294967295
  %spec.select.i715 = select i1 %_9.1.i713, i64 %_10.i714, i64 %_9.0.i712
  %t1.i716 = mul nuw i64 %x_hi_lo.i711, 4294967295
  %_14.0.i717 = add i64 %spec.select.i715, %t1.i716
  %_14.1.i718 = icmp ult i64 %_14.0.i717, %spec.select.i715
  %53 = add i64 %_14.0.i717, 4294967295
  %res.sroa.0.0.i719 = select i1 %_14.1.i718, i64 %53, i64 %_14.0.i717
  %_16.i720 = icmp ugt i64 %res.sroa.0.0.i719, -4294967296
  %_17.i721 = add nsw i64 %res.sroa.0.0.i719, 4294967295
  %_0.sroa.0.0.i722 = select i1 %_16.i720, i64 %_17.i721, i64 %res.sroa.0.0.i719
  %_19.i475 = zext i64 %_0.sroa.0.0.i754 to i128
  %_18.i476 = mul nuw nsw i128 %_19.i475, 7
  %x_lo.i691 = trunc i128 %_18.i476 to i64
  %_4.i692 = lshr i128 %_18.i476, 64
  %x_hi.i693 = trunc nuw nsw i128 %_4.i692 to i64
  %t1.i700 = mul nuw nsw i64 %x_hi.i693, 4294967295
  %_14.0.i701 = add i64 %t1.i700, %x_lo.i691
  %_14.1.i702 = icmp ult i64 %_14.0.i701, %x_lo.i691
  %54 = add i64 %_14.0.i701, 4294967295
  %res.sroa.0.0.i703 = select i1 %_14.1.i702, i64 %54, i64 %_14.0.i701
  %_16.i704 = icmp ugt i64 %res.sroa.0.0.i703, -4294967296
  %_17.i705 = add nsw i64 %res.sroa.0.0.i703, 4294967295
  %_0.sroa.0.0.i706 = select i1 %_16.i704, i64 %_17.i705, i64 %res.sroa.0.0.i703
  %_22.0.i478 = add i64 %_0.sroa.0.0.i706, %_0.sroa.0.0.i770
  %_22.1.i479 = icmp ult i64 %_22.0.i478, %_0.sroa.0.0.i770
  %55 = add nuw i64 %_22.0.i478, 4294967295
  %_24.sroa.0.0.i480 = select i1 %_22.1.i479, i64 %55, i64 %_22.0.i478
  %_25.i481 = icmp ugt i64 %_24.sroa.0.0.i480, -4294967296
  %_26.i482 = add nsw i64 %_24.sroa.0.0.i480, 4294967295
  %_7.sroa.0.0.i483 = select i1 %_25.i481, i64 %_26.i482, i64 %_24.sroa.0.0.i480
  %_29.0.i484 = add i64 %_0.sroa.0.0.i722, %_0.sroa.0.0.i738
  %_29.1.i485 = icmp ult i64 %_29.0.i484, %_0.sroa.0.0.i738
  %56 = add nuw i64 %_29.0.i484, 4294967295
  %_30.sroa.0.0.i486 = select i1 %_29.1.i485, i64 %56, i64 %_29.0.i484
  %_31.i487 = icmp ugt i64 %_30.sroa.0.0.i486, -4294967296
  %_32.i488 = add nsw i64 %_30.sroa.0.0.i486, 4294967295
  %_9.sroa.0.0.i489 = select i1 %_31.i487, i64 %_32.i488, i64 %_30.sroa.0.0.i486
  %_7.0.i98 = add i64 %_7.sroa.0.0.i483, %_3.sroa.0.0.i115
  %_7.1.i99 = icmp ult i64 %_7.0.i98, %_3.sroa.0.0.i115
  %57 = add i64 %_7.0.i98, 4294967295
  %_8.sroa.0.0.i100 = select i1 %_7.1.i99, i64 %57, i64 %_7.0.i98
  %_9.i101 = icmp ugt i64 %_8.sroa.0.0.i100, -4294967296
  %_10.i102 = add nsw i64 %_8.sroa.0.0.i100, 4294967295
  %_3.sroa.0.0.i103 = select i1 %_9.i101, i64 %_10.i102, i64 %_8.sroa.0.0.i100
  %_13.0.i104 = add i64 %_9.sroa.0.0.i489, %_4.sroa.0.0.i121
  %_13.1.i105 = icmp ult i64 %_13.0.i104, %_4.sroa.0.0.i121
  %58 = add i64 %_13.0.i104, 4294967295
  %_14.sroa.0.0.i106 = select i1 %_13.1.i105, i64 %58, i64 %_13.0.i104
  %_15.i107 = icmp ugt i64 %_14.sroa.0.0.i106, -4294967296
  %_16.i108 = add nsw i64 %_14.sroa.0.0.i106, 4294967295
  %_4.sroa.0.0.i109 = select i1 %_15.i107, i64 %_16.i108, i64 %_14.sroa.0.0.i106
  %59 = getelementptr inbounds nuw i8, ptr %_1, i64 240
  %_42.0 = load i64, ptr %59, align 8, !noundef !3
  %60 = getelementptr inbounds nuw i8, ptr %_1, i64 248
  %_42.1 = load i64, ptr %60, align 8, !noundef !3
  %_7.0.i86 = add i64 %_3.sroa.0.0.i103, %_42.0
  %_7.1.i87 = icmp ult i64 %_7.0.i86, %_3.sroa.0.0.i103
  %61 = add i64 %_7.0.i86, 4294967295
  %_8.sroa.0.0.i88 = select i1 %_7.1.i87, i64 %61, i64 %_7.0.i86
  %_9.i89 = icmp ugt i64 %_8.sroa.0.0.i88, -4294967296
  %_10.i90 = add nsw i64 %_8.sroa.0.0.i88, 4294967295
  %_3.sroa.0.0.i91 = select i1 %_9.i89, i64 %_10.i90, i64 %_8.sroa.0.0.i88
  %_13.0.i92 = add i64 %_4.sroa.0.0.i109, %_42.1
  %_13.1.i93 = icmp ult i64 %_13.0.i92, %_4.sroa.0.0.i109
  %62 = add i64 %_13.0.i92, 4294967295
  %_14.sroa.0.0.i94 = select i1 %_13.1.i93, i64 %62, i64 %_13.0.i92
  %_15.i95 = icmp ugt i64 %_14.sroa.0.0.i94, -4294967296
  %_16.i96 = add nsw i64 %_14.sroa.0.0.i94, 4294967295
  %_4.sroa.0.0.i97 = select i1 %_15.i95, i64 %_16.i96, i64 %_14.sroa.0.0.i94
  %_174.0 = sub i64 %_240, %_3.sroa.0.0.i91
  %_174.1 = icmp ult i64 %_240, %_3.sroa.0.0.i91
  %63 = add i64 %_174.0, -4294967295
  %_175.sroa.0.0 = select i1 %_174.1, i64 %63, i64 %_174.0
  %_178.0 = sub i64 %_241, %_4.sroa.0.0.i97
  %_178.1 = icmp ult i64 %_241, %_4.sroa.0.0.i97
  %64 = add i64 %_178.0, -4294967295
  %_179.sroa.0.0 = select i1 %_178.1, i64 %64, i64 %_178.0
  %_11.i436 = zext i64 %_32.0 to i128
  %_12.i437 = zext i64 %_175.sroa.0.0 to i128
  %_10.i438 = mul nuw i128 %_12.i437, %_11.i436
  %x_lo.i835 = trunc i128 %_10.i438 to i64
  %_4.i836 = lshr i128 %_10.i438, 64
  %x_hi.i837 = trunc nuw i128 %_4.i836 to i64
  %x_hi_hi.i838 = lshr i64 %x_hi.i837, 32
  %x_hi_lo.i839 = and i64 %x_hi.i837, 4294967295
  %_9.0.i840 = sub i64 %x_lo.i835, %x_hi_hi.i838
  %_9.1.i841 = icmp ugt i64 %x_hi_hi.i838, %x_lo.i835
  %_10.i842 = add i64 %_9.0.i840, -4294967295
  %spec.select.i843 = select i1 %_9.1.i841, i64 %_10.i842, i64 %_9.0.i840
  %t1.i844 = mul nuw i64 %x_hi_lo.i839, 4294967295
  %_14.0.i845 = add i64 %spec.select.i843, %t1.i844
  %_14.1.i846 = icmp ult i64 %_14.0.i845, %spec.select.i843
  %65 = add i64 %_14.0.i845, 4294967295
  %res.sroa.0.0.i847 = select i1 %_14.1.i846, i64 %65, i64 %_14.0.i845
  %_16.i848 = icmp ugt i64 %res.sroa.0.0.i847, -4294967296
  %_17.i849 = add nsw i64 %res.sroa.0.0.i847, 4294967295
  %_0.sroa.0.0.i850 = select i1 %_16.i848, i64 %_17.i849, i64 %res.sroa.0.0.i847
  %_14.i440 = zext i64 %_32.1 to i128
  %_15.i441 = zext i64 %_179.sroa.0.0 to i128
  %_13.i442 = mul nuw i128 %_15.i441, %_14.i440
  %x_lo.i819 = trunc i128 %_13.i442 to i64
  %_4.i820 = lshr i128 %_13.i442, 64
  %x_hi.i821 = trunc nuw i128 %_4.i820 to i64
  %x_hi_hi.i822 = lshr i64 %x_hi.i821, 32
  %x_hi_lo.i823 = and i64 %x_hi.i821, 4294967295
  %_9.0.i824 = sub i64 %x_lo.i819, %x_hi_hi.i822
  %_9.1.i825 = icmp ugt i64 %x_hi_hi.i822, %x_lo.i819
  %_10.i826 = add i64 %_9.0.i824, -4294967295
  %spec.select.i827 = select i1 %_9.1.i825, i64 %_10.i826, i64 %_9.0.i824
  %t1.i828 = mul nuw i64 %x_hi_lo.i823, 4294967295
  %_14.0.i829 = add i64 %spec.select.i827, %t1.i828
  %_14.1.i830 = icmp ult i64 %_14.0.i829, %spec.select.i827
  %66 = add i64 %_14.0.i829, 4294967295
  %res.sroa.0.0.i831 = select i1 %_14.1.i830, i64 %66, i64 %_14.0.i829
  %_16.i832 = icmp ugt i64 %res.sroa.0.0.i831, -4294967296
  %_17.i833 = add nsw i64 %res.sroa.0.0.i831, 4294967295
  %_0.sroa.0.0.i834 = select i1 %_16.i832, i64 %_17.i833, i64 %res.sroa.0.0.i831
  %_16.i444 = mul nuw i128 %_15.i441, %_11.i436
  %x_lo.i803 = trunc i128 %_16.i444 to i64
  %_4.i804 = lshr i128 %_16.i444, 64
  %x_hi.i805 = trunc nuw i128 %_4.i804 to i64
  %x_hi_hi.i806 = lshr i64 %x_hi.i805, 32
  %x_hi_lo.i807 = and i64 %x_hi.i805, 4294967295
  %_9.0.i808 = sub i64 %x_lo.i803, %x_hi_hi.i806
  %_9.1.i809 = icmp ugt i64 %x_hi_hi.i806, %x_lo.i803
  %_10.i810 = add i64 %_9.0.i808, -4294967295
  %spec.select.i811 = select i1 %_9.1.i809, i64 %_10.i810, i64 %_9.0.i808
  %t1.i812 = mul nuw i64 %x_hi_lo.i807, 4294967295
  %_14.0.i813 = add i64 %spec.select.i811, %t1.i812
  %_14.1.i814 = icmp ult i64 %_14.0.i813, %spec.select.i811
  %67 = add i64 %_14.0.i813, 4294967295
  %res.sroa.0.0.i815 = select i1 %_14.1.i814, i64 %67, i64 %_14.0.i813
  %_16.i816 = icmp ugt i64 %res.sroa.0.0.i815, -4294967296
  %_17.i817 = add nsw i64 %res.sroa.0.0.i815, 4294967295
  %_0.sroa.0.0.i818 = select i1 %_16.i816, i64 %_17.i817, i64 %res.sroa.0.0.i815
  %_17.i446 = mul nuw i128 %_12.i437, %_14.i440
  %x_lo.i787 = trunc i128 %_17.i446 to i64
  %_4.i788 = lshr i128 %_17.i446, 64
  %x_hi.i789 = trunc nuw i128 %_4.i788 to i64
  %x_hi_hi.i790 = lshr i64 %x_hi.i789, 32
  %x_hi_lo.i791 = and i64 %x_hi.i789, 4294967295
  %_9.0.i792 = sub i64 %x_lo.i787, %x_hi_hi.i790
  %_9.1.i793 = icmp ugt i64 %x_hi_hi.i790, %x_lo.i787
  %_10.i794 = add i64 %_9.0.i792, -4294967295
  %spec.select.i795 = select i1 %_9.1.i793, i64 %_10.i794, i64 %_9.0.i792
  %t1.i796 = mul nuw i64 %x_hi_lo.i791, 4294967295
  %_14.0.i797 = add i64 %spec.select.i795, %t1.i796
  %_14.1.i798 = icmp ult i64 %_14.0.i797, %spec.select.i795
  %68 = add i64 %_14.0.i797, 4294967295
  %res.sroa.0.0.i799 = select i1 %_14.1.i798, i64 %68, i64 %_14.0.i797
  %_16.i800 = icmp ugt i64 %res.sroa.0.0.i799, -4294967296
  %_17.i801 = add nsw i64 %res.sroa.0.0.i799, 4294967295
  %_0.sroa.0.0.i802 = select i1 %_16.i800, i64 %_17.i801, i64 %res.sroa.0.0.i799
  %_19.i448 = zext i64 %_0.sroa.0.0.i834 to i128
  %_18.i449 = mul nuw nsw i128 %_19.i448, 7
  %x_lo.i771 = trunc i128 %_18.i449 to i64
  %_4.i772 = lshr i128 %_18.i449, 64
  %x_hi.i773 = trunc nuw nsw i128 %_4.i772 to i64
  %t1.i780 = mul nuw nsw i64 %x_hi.i773, 4294967295
  %_14.0.i781 = add i64 %t1.i780, %x_lo.i771
  %_14.1.i782 = icmp ult i64 %_14.0.i781, %x_lo.i771
  %69 = add i64 %_14.0.i781, 4294967295
  %res.sroa.0.0.i783 = select i1 %_14.1.i782, i64 %69, i64 %_14.0.i781
  %_16.i784 = icmp ugt i64 %res.sroa.0.0.i783, -4294967296
  %_17.i785 = add nsw i64 %res.sroa.0.0.i783, 4294967295
  %_0.sroa.0.0.i786 = select i1 %_16.i784, i64 %_17.i785, i64 %res.sroa.0.0.i783
  %_22.0.i451 = add i64 %_0.sroa.0.0.i850, %_0.sroa.0.0.i786
  %_22.1.i452 = icmp ult i64 %_22.0.i451, %_0.sroa.0.0.i850
  %70 = add nuw i64 %_22.0.i451, 4294967295
  %_24.sroa.0.0.i453 = select i1 %_22.1.i452, i64 %70, i64 %_22.0.i451
  %_25.i454 = icmp ugt i64 %_24.sroa.0.0.i453, -4294967296
  %_26.i455 = add nsw i64 %_24.sroa.0.0.i453, 4294967295
  %_7.sroa.0.0.i456 = select i1 %_25.i454, i64 %_26.i455, i64 %_24.sroa.0.0.i453
  %_29.0.i457 = add i64 %_0.sroa.0.0.i802, %_0.sroa.0.0.i818
  %_29.1.i458 = icmp ult i64 %_29.0.i457, %_0.sroa.0.0.i818
  %71 = add nuw i64 %_29.0.i457, 4294967295
  %_30.sroa.0.0.i459 = select i1 %_29.1.i458, i64 %71, i64 %_29.0.i457
  %_31.i460 = icmp ugt i64 %_30.sroa.0.0.i459, -4294967296
  %_32.i461 = add nsw i64 %_30.sroa.0.0.i459, 4294967295
  %_9.sroa.0.0.i462 = select i1 %_31.i460, i64 %_32.i461, i64 %_30.sroa.0.0.i459
  %_186.1 = icmp eq i64 %_7.sroa.0.0.i456, 0
  %_186.0 = add i64 %_7.sroa.0.0.i456, -1
  %_187.sroa.0.0 = select i1 %_186.1, i64 -4294967296, i64 %_186.0
  %72 = load i64, ptr %_1, align 8, !range !56, !noundef !3
  %73 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %74 = load i64, ptr %73, align 8
  %75 = trunc nuw i64 %72 to i1
  br i1 %75, label %bb88, label %bb86

panic8:                                           ; preds = %bb51
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_33, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_251b78bda4aeb9a619eb192d691b2e6c) #21
  unreachable

bb88:                                             ; preds = %bb9
  %_192 = icmp ult i64 %74, %v.1
  br i1 %_192, label %bb89, label %panic9

bb86:                                             ; preds = %bb9, %bb89
  %g.sroa.5.0 = phi i64 [ %80, %bb89 ], [ 0, %bb9 ]
  %g.sroa.0.0 = phi i64 [ %78, %bb89 ], [ 1, %bb9 ]
  %76 = getelementptr inbounds nuw i8, ptr %_1, i64 80
  %_199 = load i64, ptr %76, align 8, !noundef !3
  %_201 = icmp ult i64 %_199, 4
  br i1 %_201, label %bb90, label %bb9.i.lr.ph, !prof !57

bb89:                                             ; preds = %bb88
  %77 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %74
  %78 = load i64, ptr %77, align 8, !noundef !3
  %79 = getelementptr inbounds nuw i8, ptr %77, i64 8
  %80 = load i64, ptr %79, align 8, !noundef !3
  br label %bb86

panic9:                                           ; preds = %bb88
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %74, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_03bbe1d0fcdbd86f2216092eb0f02e36) #21
  unreachable

bb9.i.lr.ph:                                      ; preds = %bb86
  %81 = getelementptr inbounds nuw i8, ptr %_1, i64 72
  %_200 = load ptr, ptr %81, align 8, !nonnull !3, !noundef !3
  %82 = getelementptr inbounds nuw i8, ptr %_1, i64 256
  %_48 = load i64, ptr %82, align 8, !noundef !3
  %83 = getelementptr inbounds nuw i8, ptr %_1, i64 56
  %_195 = load i64, ptr %83, align 8, !noundef !3
  %84 = getelementptr inbounds nuw i8, ptr %_1, i64 48
  %_196 = load ptr, ptr %84, align 8, !nonnull !3, !noundef !3
  %_203 = add i64 %_199, -4
  %_207 = getelementptr inbounds nuw i8, ptr %_200, i64 64
; call isolated::helper_sum
  %85 = call fastcc { i64, i64 } @_RNvCsl0YfJI2rrfI_8isolated10helper_sum(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_196, i64 noundef %_195, i64 noundef %_48, i64 noundef %_240, i64 noundef %_241, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_207, i64 noundef %_203)
  %_53 = getelementptr inbounds nuw i8, ptr %_200, i64 48
  %_52.0 = load i64, ptr %_53, align 8, !noundef !3
  %86 = getelementptr inbounds nuw i8, ptr %_200, i64 56
  %_52.1 = load i64, ptr %86, align 8, !noundef !3
  %_55 = getelementptr inbounds nuw i8, ptr %_1, i64 88
; call <isolated::PadTerm>::eval
  %87 = call fastcc { i64, i64 } @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(40) %_55, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1)
  %_212.idx = shl nuw nsw i64 %_199, 4
  %_212 = getelementptr inbounds nuw i8, ptr %_200, i64 %_212.idx
  %_56.sroa.6.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 80
  call void @llvm.lifetime.start.p0(ptr nonnull %iter)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %_56.sroa.6.0.iter.sroa_idx, i8 0, i64 16, i1 false)
  %_56.sroa.5.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 32
  store i64 %_3.sroa.0.0.i151, ptr %_56.sroa.5.0.iter.sroa_idx, align 8
  %_56.sroa.5.sroa.2.0._56.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 40
  store i64 %_4.sroa.0.0.i157, ptr %_56.sroa.5.sroa.2.0._56.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_56.sroa.5.sroa.3.0._56.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 48
  store i64 %_145.sroa.0.0, ptr %_56.sroa.5.sroa.3.0._56.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_56.sroa.5.sroa.4.0._56.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 56
  store i64 %_149.sroa.0.0, ptr %_56.sroa.5.sroa.4.0._56.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_56.sroa.5.sroa.5.0._56.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 64
  store i64 %_160.sroa.0.0, ptr %_56.sroa.5.sroa.5.0._56.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_56.sroa.5.sroa.6.0._56.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 72
  store i64 %_164.sroa.0.0, ptr %_56.sroa.5.sroa.6.0._56.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_14.i413 = zext i64 %_52.1 to i128
  %_12.i410 = zext i64 %_187.sroa.0.0 to i128
  %_17.i419 = mul nuw i128 %_14.i413, %_12.i410
  %_4.i868 = lshr i128 %_17.i419, 64
  %x_hi.i869 = trunc nuw i128 %_4.i868 to i64
  %x_hi_hi.i870 = lshr i64 %x_hi.i869, 32
  %x_lo.i867 = trunc i128 %_17.i419 to i64
  %_9.1.i873 = icmp ugt i64 %x_hi_hi.i870, %x_lo.i867
  %_9.0.i872 = sub i64 %x_lo.i867, %x_hi_hi.i870
  %_10.i874 = add i64 %_9.0.i872, -4294967295
  %spec.select.i875 = select i1 %_9.1.i873, i64 %_10.i874, i64 %_9.0.i872
  %x_hi_lo.i871 = and i64 %x_hi.i869, 4294967295
  %t1.i876 = mul nuw i64 %x_hi_lo.i871, 4294967295
  %_14.0.i877 = add i64 %spec.select.i875, %t1.i876
  %_14.1.i878 = icmp ult i64 %_14.0.i877, %spec.select.i875
  %88 = add i64 %_14.0.i877, 4294967295
  %res.sroa.0.0.i879 = select i1 %_14.1.i878, i64 %88, i64 %_14.0.i877
  %_16.i880 = icmp ugt i64 %res.sroa.0.0.i879, -4294967296
  %_17.i881 = add nsw i64 %res.sroa.0.0.i879, 4294967295
  %_0.sroa.0.0.i882 = select i1 %_16.i880, i64 %_17.i881, i64 %res.sroa.0.0.i879
  %_11.i409 = zext i64 %_52.0 to i128
  %_15.i414 = zext i64 %_9.sroa.0.0.i462 to i128
  %_16.i417 = mul nuw i128 %_11.i409, %_15.i414
  %_4.i884 = lshr i128 %_16.i417, 64
  %x_hi.i885 = trunc nuw i128 %_4.i884 to i64
  %x_hi_hi.i886 = lshr i64 %x_hi.i885, 32
  %x_lo.i883 = trunc i128 %_16.i417 to i64
  %_9.1.i889 = icmp ugt i64 %x_hi_hi.i886, %x_lo.i883
  %_9.0.i888 = sub i64 %x_lo.i883, %x_hi_hi.i886
  %_10.i890 = add i64 %_9.0.i888, -4294967295
  %spec.select.i891 = select i1 %_9.1.i889, i64 %_10.i890, i64 %_9.0.i888
  %x_hi_lo.i887 = and i64 %x_hi.i885, 4294967295
  %t1.i892 = mul nuw i64 %x_hi_lo.i887, 4294967295
  %_14.0.i893 = add i64 %spec.select.i891, %t1.i892
  %_14.1.i894 = icmp ult i64 %_14.0.i893, %spec.select.i891
  %89 = add i64 %_14.0.i893, 4294967295
  %res.sroa.0.0.i895 = select i1 %_14.1.i894, i64 %89, i64 %_14.0.i893
  %_16.i896 = icmp ugt i64 %res.sroa.0.0.i895, -4294967296
  %_17.i897 = add nsw i64 %res.sroa.0.0.i895, 4294967295
  %_0.sroa.0.0.i898 = select i1 %_16.i896, i64 %_17.i897, i64 %res.sroa.0.0.i895
  %_29.0.i430 = add i64 %_0.sroa.0.0.i882, %_0.sroa.0.0.i898
  %_29.1.i431 = icmp ult i64 %_29.0.i430, %_0.sroa.0.0.i898
  %90 = add nuw i64 %_29.0.i430, 4294967295
  %_30.sroa.0.0.i432 = select i1 %_29.1.i431, i64 %90, i64 %_29.0.i430
  %_31.i433 = icmp ugt i64 %_30.sroa.0.0.i432, -4294967296
  %_32.i434 = add nsw i64 %_30.sroa.0.0.i432, 4294967295
  %_9.sroa.0.0.i435 = select i1 %_31.i433, i64 %_32.i434, i64 %_30.sroa.0.0.i432
  %_46.1 = extractvalue { i64, i64 } %85, 1
  %_13.0.i80 = add i64 %_9.sroa.0.0.i435, %_46.1
  %_13.1.i81 = icmp ult i64 %_13.0.i80, %_46.1
  %91 = add i64 %_13.0.i80, 4294967295
  %_14.sroa.0.0.i82 = select i1 %_13.1.i81, i64 %91, i64 %_13.0.i80
  %_15.i83 = icmp ugt i64 %_14.sroa.0.0.i82, -4294967296
  %_16.i84 = add nsw i64 %_14.sroa.0.0.i82, 4294967295
  %_4.sroa.0.0.i85 = select i1 %_15.i83, i64 %_16.i84, i64 %_14.sroa.0.0.i82
  %_54.1 = extractvalue { i64, i64 } %87, 1
  %_13.0.i68 = add i64 %_4.sroa.0.0.i85, %_54.1
  %_13.1.i69 = icmp ult i64 %_13.0.i68, %_4.sroa.0.0.i85
  %92 = add i64 %_13.0.i68, 4294967295
  %_14.sroa.0.0.i70 = select i1 %_13.1.i69, i64 %92, i64 %_13.0.i68
  %_15.i71 = icmp ugt i64 %_14.sroa.0.0.i70, -4294967296
  %_16.i72 = add nsw i64 %_14.sroa.0.0.i70, 4294967295
  %_4.sroa.0.0.i73 = select i1 %_15.i71, i64 %_16.i72, i64 %_14.sroa.0.0.i70
  %_13.i415 = mul nuw i128 %_14.i413, %_15.i414
  %_4.i900 = lshr i128 %_13.i415, 64
  %x_hi.i901 = trunc nuw i128 %_4.i900 to i64
  %x_hi_hi.i902 = lshr i64 %x_hi.i901, 32
  %x_lo.i899 = trunc i128 %_13.i415 to i64
  %_9.1.i905 = icmp ugt i64 %x_hi_hi.i902, %x_lo.i899
  %_9.0.i904 = sub i64 %x_lo.i899, %x_hi_hi.i902
  %_10.i906 = add i64 %_9.0.i904, -4294967295
  %spec.select.i907 = select i1 %_9.1.i905, i64 %_10.i906, i64 %_9.0.i904
  %x_hi_lo.i903 = and i64 %x_hi.i901, 4294967295
  %t1.i908 = mul nuw i64 %x_hi_lo.i903, 4294967295
  %_14.0.i909 = add i64 %spec.select.i907, %t1.i908
  %_14.1.i910 = icmp ult i64 %_14.0.i909, %spec.select.i907
  %93 = add i64 %_14.0.i909, 4294967295
  %res.sroa.0.0.i911 = select i1 %_14.1.i910, i64 %93, i64 %_14.0.i909
  %_16.i912 = icmp ugt i64 %res.sroa.0.0.i911, -4294967296
  %_17.i913 = add nsw i64 %res.sroa.0.0.i911, 4294967295
  %_0.sroa.0.0.i914 = select i1 %_16.i912, i64 %_17.i913, i64 %res.sroa.0.0.i911
  %_19.i421 = zext i64 %_0.sroa.0.0.i914 to i128
  %_18.i422 = mul nuw nsw i128 %_19.i421, 7
  %_4.i852 = lshr i128 %_18.i422, 64
  %x_hi.i853 = trunc nuw nsw i128 %_4.i852 to i64
  %t1.i860 = mul nuw nsw i64 %x_hi.i853, 4294967295
  %x_lo.i851 = trunc i128 %_18.i422 to i64
  %_14.0.i861 = add i64 %t1.i860, %x_lo.i851
  %_14.1.i862 = icmp ult i64 %_14.0.i861, %x_lo.i851
  %94 = add i64 %_14.0.i861, 4294967295
  %res.sroa.0.0.i863 = select i1 %_14.1.i862, i64 %94, i64 %_14.0.i861
  %_16.i864 = icmp ugt i64 %res.sroa.0.0.i863, -4294967296
  %_17.i865 = add nsw i64 %res.sroa.0.0.i863, 4294967295
  %_0.sroa.0.0.i866 = select i1 %_16.i864, i64 %_17.i865, i64 %res.sroa.0.0.i863
  %_10.i411 = mul nuw i128 %_11.i409, %_12.i410
  %_4.i916 = lshr i128 %_10.i411, 64
  %x_hi.i917 = trunc nuw i128 %_4.i916 to i64
  %x_hi_hi.i918 = lshr i64 %x_hi.i917, 32
  %x_lo.i915 = trunc i128 %_10.i411 to i64
  %_9.1.i921 = icmp ugt i64 %x_hi_hi.i918, %x_lo.i915
  %_9.0.i920 = sub i64 %x_lo.i915, %x_hi_hi.i918
  %_10.i922 = add i64 %_9.0.i920, -4294967295
  %spec.select.i923 = select i1 %_9.1.i921, i64 %_10.i922, i64 %_9.0.i920
  %x_hi_lo.i919 = and i64 %x_hi.i917, 4294967295
  %t1.i924 = mul nuw i64 %x_hi_lo.i919, 4294967295
  %_14.0.i925 = add i64 %spec.select.i923, %t1.i924
  %_14.1.i926 = icmp ult i64 %_14.0.i925, %spec.select.i923
  %95 = add i64 %_14.0.i925, 4294967295
  %res.sroa.0.0.i927 = select i1 %_14.1.i926, i64 %95, i64 %_14.0.i925
  %_16.i928 = icmp ugt i64 %res.sroa.0.0.i927, -4294967296
  %_17.i929 = add nsw i64 %res.sroa.0.0.i927, 4294967295
  %_0.sroa.0.0.i930 = select i1 %_16.i928, i64 %_17.i929, i64 %res.sroa.0.0.i927
  %_22.0.i424 = add i64 %_0.sroa.0.0.i866, %_0.sroa.0.0.i930
  %_22.1.i425 = icmp ult i64 %_22.0.i424, %_0.sroa.0.0.i930
  %96 = add nuw i64 %_22.0.i424, 4294967295
  %_24.sroa.0.0.i426 = select i1 %_22.1.i425, i64 %96, i64 %_22.0.i424
  %_25.i427 = icmp ugt i64 %_24.sroa.0.0.i426, -4294967296
  %_26.i428 = add nsw i64 %_24.sroa.0.0.i426, 4294967295
  %_7.sroa.0.0.i429 = select i1 %_25.i427, i64 %_26.i428, i64 %_24.sroa.0.0.i426
  %_46.0 = extractvalue { i64, i64 } %85, 0
  %_7.0.i74 = add i64 %_7.sroa.0.0.i429, %_46.0
  %_7.1.i75 = icmp ult i64 %_7.0.i74, %_46.0
  %97 = add i64 %_7.0.i74, 4294967295
  %_8.sroa.0.0.i76 = select i1 %_7.1.i75, i64 %97, i64 %_7.0.i74
  %_9.i77 = icmp ugt i64 %_8.sroa.0.0.i76, -4294967296
  %_10.i78 = add nsw i64 %_8.sroa.0.0.i76, 4294967295
  %_3.sroa.0.0.i79 = select i1 %_9.i77, i64 %_10.i78, i64 %_8.sroa.0.0.i76
  %_54.0 = extractvalue { i64, i64 } %87, 0
  %_7.0.i62 = add i64 %_3.sroa.0.0.i79, %_54.0
  %_7.1.i63 = icmp ult i64 %_7.0.i62, %_3.sroa.0.0.i79
  %98 = add i64 %_7.0.i62, 4294967295
  %_8.sroa.0.0.i64 = select i1 %_7.1.i63, i64 %98, i64 %_7.0.i62
  %_9.i65 = icmp ugt i64 %_8.sroa.0.0.i64, -4294967296
  %_10.i66 = add nsw i64 %_8.sroa.0.0.i64, 4294967295
  %_3.sroa.0.0.i67 = select i1 %_9.i65, i64 %_10.i66, i64 %_8.sroa.0.0.i64
  %_12.i167 = zext i64 %g.sroa.0.0 to i128
  %_15.i170 = zext i64 %g.sroa.5.0 to i128
  br label %bb9.i

bb90:                                             ; preds = %bb86
; call core::slice::index::slice_index_fail
  call void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 4, i64 noundef %_199, i64 noundef %_199, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_85ee655d0ee76a931ab97ae7956c61fa) #21
  unreachable

bb9.i:                                            ; preds = %bb9.i.lr.ph, %bb27
  %_4.sroa.0.0.i73.pn1757 = phi i64 [ %_4.sroa.0.0.i73, %bb9.i.lr.ph ], [ %_4.sroa.0.0.i, %bb27 ]
  %_3.sroa.0.0.i67.pn1756 = phi i64 [ %_3.sroa.0.0.i67, %bb9.i.lr.ph ], [ %_3.sroa.0.0.i, %bb27 ]
  %ptr.i.i17381755 = phi ptr [ %_200, %bb9.i.lr.ph ], [ %_16.i.i, %bb27 ]
  %_10.i.i.i17401754 = phi i64 [ 0, %bb9.i.lr.ph ], [ %_11.i.i.i, %bb27 ]
  %_5.not.i.i.i = icmp eq i64 %_10.i.i.i17401754, 3
  br i1 %_5.not.i.i.i, label %bb24, label %bb27

bb24:                                             ; preds = %bb9.i, %bb27
  %_3.sroa.0.0.i67.pn.lcssa.ph = phi i64 [ %_3.sroa.0.0.i, %bb27 ], [ %_3.sroa.0.0.i67.pn1756, %bb9.i ]
  %_4.sroa.0.0.i73.pn.lcssa.ph = phi i64 [ %_4.sroa.0.0.i, %bb27 ], [ %_4.sroa.0.0.i73.pn1757, %bb9.i ]
  call void @llvm.lifetime.end.p0(ptr nonnull %iter)
  %_218 = getelementptr inbounds nuw i8, ptr %_101, i64 544
  %_217 = load i64, ptr %_218, align 8, !noundef !3
  %_219 = icmp ult i64 %_217, %v.1
  br i1 %_219, label %bb94, label %panic12

bb94:                                             ; preds = %bb24
  %99 = getelementptr inbounds nuw i8, ptr %_1, i64 264
  %_73.0 = load i64, ptr %99, align 8, !noundef !3
  %100 = getelementptr inbounds nuw i8, ptr %_1, i64 272
  %_73.1 = load i64, ptr %100, align 8, !noundef !3
  %101 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_217
  %_74.0 = load i64, ptr %101, align 8, !noundef !3
  %102 = getelementptr inbounds nuw i8, ptr %101, i64 8
  %_74.1 = load i64, ptr %102, align 8, !noundef !3
  %103 = getelementptr inbounds nuw i8, ptr %_1, i64 280
  %_242 = load i64, ptr %103, align 8, !noundef !3
  %104 = getelementptr inbounds nuw i8, ptr %_1, i64 288
  %_243 = load i64, ptr %104, align 8, !noundef !3
  %_77.0 = load i64, ptr %v.0, align 8, !noundef !3
  %105 = getelementptr inbounds nuw i8, ptr %v.0, i64 8
  %_77.1 = load i64, ptr %105, align 8, !noundef !3
  %106 = getelementptr inbounds nuw i8, ptr %_1, i64 136
  %_236 = load ptr, ptr %106, align 8, !nonnull !3, !noundef !3
  %107 = getelementptr inbounds nuw i8, ptr %_1, i64 144
  %_235 = load i64, ptr %107, align 8, !noundef !3
  %_237.not = icmp eq i64 %_235, 0
  br i1 %_237.not, label %panic14, label %bb102

panic12:                                          ; preds = %bb24
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_217, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_eca36810f664faabadbd931684be3603) #21
  unreachable

bb102:                                            ; preds = %bb94
  %_85 = icmp samesign ugt i64 %v.1, 1
  br i1 %_85, label %bb33, label %panic15

panic14:                                          ; preds = %bb94
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 0, i64 noundef 0, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_60764c2be1deec61362b17f60211fd40) #21
  unreachable

bb33:                                             ; preds = %bb102
  %108 = getelementptr inbounds nuw i8, ptr %_236, i64 8
  %_82.1 = load i64, ptr %108, align 8, !noundef !3
  %_82.0 = load i64, ptr %_236, align 8, !noundef !3
  %109 = getelementptr inbounds nuw i8, ptr %v.0, i64 16
  %_84.0 = load i64, ptr %109, align 8, !noundef !3
  %110 = getelementptr inbounds nuw i8, ptr %v.0, i64 24
  %_84.1 = load i64, ptr %110, align 8, !noundef !3
  %_238.not = icmp eq i64 %_235, 1
  br i1 %_238.not, label %panic16, label %bb103

panic15:                                          ; preds = %bb102
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_0115ca0cf6aba2d7c2ca2e69392e3726) #21
  unreachable

bb103:                                            ; preds = %bb33
  %_93.not = icmp eq i64 %v.1, 2
  br i1 %_93.not, label %panic17, label %bb38

panic16:                                          ; preds = %bb33
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef 1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_7672b3fd58eaeff1a7f945549344b36b) #21
  unreachable

bb38:                                             ; preds = %bb103
  %_11.i355 = zext i64 %_77.0 to i128
  %_15.i360 = zext i64 %_4.sroa.0.0.i73.pn.lcssa.ph to i128
  %_16.i363 = mul nuw i128 %_11.i355, %_15.i360
  %_4.i1044 = lshr i128 %_16.i363, 64
  %x_hi.i1045 = trunc nuw i128 %_4.i1044 to i64
  %x_hi_hi.i1046 = lshr i64 %x_hi.i1045, 32
  %x_lo.i1043 = trunc i128 %_16.i363 to i64
  %_9.1.i1049 = icmp ugt i64 %x_hi_hi.i1046, %x_lo.i1043
  %_9.0.i1048 = sub i64 %x_lo.i1043, %x_hi_hi.i1046
  %_10.i1050 = add i64 %_9.0.i1048, -4294967295
  %spec.select.i1051 = select i1 %_9.1.i1049, i64 %_10.i1050, i64 %_9.0.i1048
  %x_hi_lo.i1047 = and i64 %x_hi.i1045, 4294967295
  %t1.i1052 = mul nuw i64 %x_hi_lo.i1047, 4294967295
  %_14.0.i1053 = add i64 %spec.select.i1051, %t1.i1052
  %_14.1.i1054 = icmp ult i64 %_14.0.i1053, %spec.select.i1051
  %111 = add i64 %_14.0.i1053, 4294967295
  %res.sroa.0.0.i1055 = select i1 %_14.1.i1054, i64 %111, i64 %_14.0.i1053
  %_16.i1056 = icmp ugt i64 %res.sroa.0.0.i1055, -4294967296
  %_17.i1057 = add nsw i64 %res.sroa.0.0.i1055, 4294967295
  %_0.sroa.0.0.i1058 = select i1 %_16.i1056, i64 %_17.i1057, i64 %res.sroa.0.0.i1055
  %_14.i359 = zext i64 %_77.1 to i128
  %_12.i356 = zext i64 %_3.sroa.0.0.i67.pn.lcssa.ph to i128
  %_17.i365 = mul nuw i128 %_14.i359, %_12.i356
  %_4.i1028 = lshr i128 %_17.i365, 64
  %x_hi.i1029 = trunc nuw i128 %_4.i1028 to i64
  %x_hi_hi.i1030 = lshr i64 %x_hi.i1029, 32
  %x_lo.i1027 = trunc i128 %_17.i365 to i64
  %_9.1.i1033 = icmp ugt i64 %x_hi_hi.i1030, %x_lo.i1027
  %_9.0.i1032 = sub i64 %x_lo.i1027, %x_hi_hi.i1030
  %_10.i1034 = add i64 %_9.0.i1032, -4294967295
  %spec.select.i1035 = select i1 %_9.1.i1033, i64 %_10.i1034, i64 %_9.0.i1032
  %x_hi_lo.i1031 = and i64 %x_hi.i1029, 4294967295
  %t1.i1036 = mul nuw i64 %x_hi_lo.i1031, 4294967295
  %_14.0.i1037 = add i64 %spec.select.i1035, %t1.i1036
  %_14.1.i1038 = icmp ult i64 %_14.0.i1037, %spec.select.i1035
  %112 = add i64 %_14.0.i1037, 4294967295
  %res.sroa.0.0.i1039 = select i1 %_14.1.i1038, i64 %112, i64 %_14.0.i1037
  %_16.i1040 = icmp ugt i64 %res.sroa.0.0.i1039, -4294967296
  %_17.i1041 = add nsw i64 %res.sroa.0.0.i1039, 4294967295
  %_0.sroa.0.0.i1042 = select i1 %_16.i1040, i64 %_17.i1041, i64 %res.sroa.0.0.i1039
  %_29.0.i376 = add i64 %_0.sroa.0.0.i1042, %_0.sroa.0.0.i1058
  %_29.1.i377 = icmp ult i64 %_29.0.i376, %_0.sroa.0.0.i1058
  %113 = add nuw i64 %_29.0.i376, 4294967295
  %_30.sroa.0.0.i378 = select i1 %_29.1.i377, i64 %113, i64 %_29.0.i376
  %_31.i379 = icmp ugt i64 %_30.sroa.0.0.i378, -4294967296
  %_32.i380 = add nsw i64 %_30.sroa.0.0.i378, 4294967295
  %_9.sroa.0.0.i381 = select i1 %_31.i379, i64 %_32.i380, i64 %_30.sroa.0.0.i378
  %_11.i328 = zext i64 %_82.0 to i128
  %_12.i329 = zext i64 %_84.0 to i128
  %_10.i330 = mul nuw i128 %_12.i329, %_11.i328
  %_4.i1156 = lshr i128 %_10.i330, 64
  %x_hi.i1157 = trunc nuw i128 %_4.i1156 to i64
  %x_hi_hi.i1158 = lshr i64 %x_hi.i1157, 32
  %x_lo.i1155 = trunc i128 %_10.i330 to i64
  %_9.1.i1161 = icmp ugt i64 %x_hi_hi.i1158, %x_lo.i1155
  %_9.0.i1160 = sub i64 %x_lo.i1155, %x_hi_hi.i1158
  %_10.i1162 = add i64 %_9.0.i1160, -4294967295
  %spec.select.i1163 = select i1 %_9.1.i1161, i64 %_10.i1162, i64 %_9.0.i1160
  %x_hi_lo.i1159 = and i64 %x_hi.i1157, 4294967295
  %t1.i1164 = mul nuw i64 %x_hi_lo.i1159, 4294967295
  %_14.0.i1165 = add i64 %spec.select.i1163, %t1.i1164
  %_14.1.i1166 = icmp ult i64 %_14.0.i1165, %spec.select.i1163
  %114 = add i64 %_14.0.i1165, 4294967295
  %res.sroa.0.0.i1167 = select i1 %_14.1.i1166, i64 %114, i64 %_14.0.i1165
  %_16.i1168 = icmp ugt i64 %res.sroa.0.0.i1167, -4294967296
  %_17.i1169 = add nsw i64 %res.sroa.0.0.i1167, 4294967295
  %_0.sroa.0.0.i1170 = select i1 %_16.i1168, i64 %_17.i1169, i64 %res.sroa.0.0.i1167
  %_14.i332 = zext i64 %_82.1 to i128
  %_15.i333 = zext i64 %_84.1 to i128
  %_13.i334 = mul nuw i128 %_15.i333, %_14.i332
  %_4.i1140 = lshr i128 %_13.i334, 64
  %x_hi.i1141 = trunc nuw i128 %_4.i1140 to i64
  %x_hi_hi.i1142 = lshr i64 %x_hi.i1141, 32
  %x_lo.i1139 = trunc i128 %_13.i334 to i64
  %_9.1.i1145 = icmp ugt i64 %x_hi_hi.i1142, %x_lo.i1139
  %_9.0.i1144 = sub i64 %x_lo.i1139, %x_hi_hi.i1142
  %_10.i1146 = add i64 %_9.0.i1144, -4294967295
  %spec.select.i1147 = select i1 %_9.1.i1145, i64 %_10.i1146, i64 %_9.0.i1144
  %x_hi_lo.i1143 = and i64 %x_hi.i1141, 4294967295
  %t1.i1148 = mul nuw i64 %x_hi_lo.i1143, 4294967295
  %_14.0.i1149 = add i64 %spec.select.i1147, %t1.i1148
  %_14.1.i1150 = icmp ult i64 %_14.0.i1149, %spec.select.i1147
  %115 = add i64 %_14.0.i1149, 4294967295
  %res.sroa.0.0.i1151 = select i1 %_14.1.i1150, i64 %115, i64 %_14.0.i1149
  %_16.i1152 = icmp ugt i64 %res.sroa.0.0.i1151, -4294967296
  %_17.i1153 = add nsw i64 %res.sroa.0.0.i1151, 4294967295
  %_0.sroa.0.0.i1154 = select i1 %_16.i1152, i64 %_17.i1153, i64 %res.sroa.0.0.i1151
  %_19.i340 = zext i64 %_0.sroa.0.0.i1154 to i128
  %_18.i341 = mul nuw nsw i128 %_19.i340, 7
  %_4.i1092 = lshr i128 %_18.i341, 64
  %x_hi.i1093 = trunc nuw nsw i128 %_4.i1092 to i64
  %t1.i1100 = mul nuw nsw i64 %x_hi.i1093, 4294967295
  %x_lo.i1091 = trunc i128 %_18.i341 to i64
  %_14.0.i1101 = add i64 %t1.i1100, %x_lo.i1091
  %_14.1.i1102 = icmp ult i64 %_14.0.i1101, %x_lo.i1091
  %116 = add i64 %_14.0.i1101, 4294967295
  %res.sroa.0.0.i1103 = select i1 %_14.1.i1102, i64 %116, i64 %_14.0.i1101
  %_16.i1104 = icmp ugt i64 %res.sroa.0.0.i1103, -4294967296
  %_17.i1105 = add nsw i64 %res.sroa.0.0.i1103, 4294967295
  %_0.sroa.0.0.i1106 = select i1 %_16.i1104, i64 %_17.i1105, i64 %res.sroa.0.0.i1103
  %_22.0.i343 = add i64 %_0.sroa.0.0.i1106, %_0.sroa.0.0.i1170
  %_22.1.i344 = icmp ult i64 %_22.0.i343, %_0.sroa.0.0.i1170
  %117 = add nuw i64 %_22.0.i343, 4294967295
  %_24.sroa.0.0.i345 = select i1 %_22.1.i344, i64 %117, i64 %_22.0.i343
  %_25.i346 = icmp ugt i64 %_24.sroa.0.0.i345, -4294967296
  %_26.i347 = add nsw i64 %_24.sroa.0.0.i345, 4294967295
  %_7.sroa.0.0.i348 = select i1 %_25.i346, i64 %_26.i347, i64 %_24.sroa.0.0.i345
  %_11.i301 = zext i64 %_7.sroa.0.0.i348 to i128
  %_12.i302 = zext i64 %g.sroa.0.0 to i128
  %_10.i303 = mul nuw i128 %_11.i301, %_12.i302
  %_4.i1236 = lshr i128 %_10.i303, 64
  %x_hi.i1237 = trunc nuw i128 %_4.i1236 to i64
  %x_hi_hi.i1238 = lshr i64 %x_hi.i1237, 32
  %x_lo.i1235 = trunc i128 %_10.i303 to i64
  %_9.1.i1241 = icmp ugt i64 %x_hi_hi.i1238, %x_lo.i1235
  %_9.0.i1240 = sub i64 %x_lo.i1235, %x_hi_hi.i1238
  %_10.i1242 = add i64 %_9.0.i1240, -4294967295
  %spec.select.i1243 = select i1 %_9.1.i1241, i64 %_10.i1242, i64 %_9.0.i1240
  %x_hi_lo.i1239 = and i64 %x_hi.i1237, 4294967295
  %t1.i1244 = mul nuw i64 %x_hi_lo.i1239, 4294967295
  %_14.0.i1245 = add i64 %spec.select.i1243, %t1.i1244
  %_14.1.i1246 = icmp ult i64 %_14.0.i1245, %spec.select.i1243
  %118 = add i64 %_14.0.i1245, 4294967295
  %res.sroa.0.0.i1247 = select i1 %_14.1.i1246, i64 %118, i64 %_14.0.i1245
  %_16.i1248 = icmp ugt i64 %res.sroa.0.0.i1247, -4294967296
  %_17.i1249 = add nsw i64 %res.sroa.0.0.i1247, 4294967295
  %_0.sroa.0.0.i1250 = select i1 %_16.i1248, i64 %_17.i1249, i64 %res.sroa.0.0.i1247
  %_16.i336 = mul nuw i128 %_15.i333, %_11.i328
  %_4.i1124 = lshr i128 %_16.i336, 64
  %x_hi.i1125 = trunc nuw i128 %_4.i1124 to i64
  %x_hi_hi.i1126 = lshr i64 %x_hi.i1125, 32
  %x_lo.i1123 = trunc i128 %_16.i336 to i64
  %_9.1.i1129 = icmp ugt i64 %x_hi_hi.i1126, %x_lo.i1123
  %_9.0.i1128 = sub i64 %x_lo.i1123, %x_hi_hi.i1126
  %_10.i1130 = add i64 %_9.0.i1128, -4294967295
  %spec.select.i1131 = select i1 %_9.1.i1129, i64 %_10.i1130, i64 %_9.0.i1128
  %x_hi_lo.i1127 = and i64 %x_hi.i1125, 4294967295
  %t1.i1132 = mul nuw i64 %x_hi_lo.i1127, 4294967295
  %_14.0.i1133 = add i64 %spec.select.i1131, %t1.i1132
  %_14.1.i1134 = icmp ult i64 %_14.0.i1133, %spec.select.i1131
  %119 = add i64 %_14.0.i1133, 4294967295
  %res.sroa.0.0.i1135 = select i1 %_14.1.i1134, i64 %119, i64 %_14.0.i1133
  %_16.i1136 = icmp ugt i64 %res.sroa.0.0.i1135, -4294967296
  %_17.i1137 = add nsw i64 %res.sroa.0.0.i1135, 4294967295
  %_0.sroa.0.0.i1138 = select i1 %_16.i1136, i64 %_17.i1137, i64 %res.sroa.0.0.i1135
  %_17.i338 = mul nuw i128 %_12.i329, %_14.i332
  %_4.i1108 = lshr i128 %_17.i338, 64
  %x_hi.i1109 = trunc nuw i128 %_4.i1108 to i64
  %x_hi_hi.i1110 = lshr i64 %x_hi.i1109, 32
  %x_lo.i1107 = trunc i128 %_17.i338 to i64
  %_9.1.i1113 = icmp ugt i64 %x_hi_hi.i1110, %x_lo.i1107
  %_9.0.i1112 = sub i64 %x_lo.i1107, %x_hi_hi.i1110
  %_10.i1114 = add i64 %_9.0.i1112, -4294967295
  %spec.select.i1115 = select i1 %_9.1.i1113, i64 %_10.i1114, i64 %_9.0.i1112
  %x_hi_lo.i1111 = and i64 %x_hi.i1109, 4294967295
  %t1.i1116 = mul nuw i64 %x_hi_lo.i1111, 4294967295
  %_14.0.i1117 = add i64 %spec.select.i1115, %t1.i1116
  %_14.1.i1118 = icmp ult i64 %_14.0.i1117, %spec.select.i1115
  %120 = add i64 %_14.0.i1117, 4294967295
  %res.sroa.0.0.i1119 = select i1 %_14.1.i1118, i64 %120, i64 %_14.0.i1117
  %_16.i1120 = icmp ugt i64 %res.sroa.0.0.i1119, -4294967296
  %_17.i1121 = add nsw i64 %res.sroa.0.0.i1119, 4294967295
  %_0.sroa.0.0.i1122 = select i1 %_16.i1120, i64 %_17.i1121, i64 %res.sroa.0.0.i1119
  %_29.0.i349 = add i64 %_0.sroa.0.0.i1138, %_0.sroa.0.0.i1122
  %_29.1.i350 = icmp ult i64 %_29.0.i349, %_0.sroa.0.0.i1138
  %121 = add nuw i64 %_29.0.i349, 4294967295
  %_30.sroa.0.0.i351 = select i1 %_29.1.i350, i64 %121, i64 %_29.0.i349
  %_31.i352 = icmp ugt i64 %_30.sroa.0.0.i351, -4294967296
  %_32.i353 = add nsw i64 %_30.sroa.0.0.i351, 4294967295
  %_9.sroa.0.0.i354 = select i1 %_31.i352, i64 %_32.i353, i64 %_30.sroa.0.0.i351
  %_14.i305 = zext i64 %_9.sroa.0.0.i354 to i128
  %_15.i306 = zext i64 %g.sroa.5.0 to i128
  %_13.i307 = mul nuw i128 %_14.i305, %_15.i306
  %_4.i1220 = lshr i128 %_13.i307, 64
  %x_hi.i1221 = trunc nuw i128 %_4.i1220 to i64
  %x_hi_hi.i1222 = lshr i64 %x_hi.i1221, 32
  %x_lo.i1219 = trunc i128 %_13.i307 to i64
  %_9.1.i1225 = icmp ugt i64 %x_hi_hi.i1222, %x_lo.i1219
  %_9.0.i1224 = sub i64 %x_lo.i1219, %x_hi_hi.i1222
  %_10.i1226 = add i64 %_9.0.i1224, -4294967295
  %spec.select.i1227 = select i1 %_9.1.i1225, i64 %_10.i1226, i64 %_9.0.i1224
  %x_hi_lo.i1223 = and i64 %x_hi.i1221, 4294967295
  %t1.i1228 = mul nuw i64 %x_hi_lo.i1223, 4294967295
  %_14.0.i1229 = add i64 %spec.select.i1227, %t1.i1228
  %_14.1.i1230 = icmp ult i64 %_14.0.i1229, %spec.select.i1227
  %122 = add i64 %_14.0.i1229, 4294967295
  %res.sroa.0.0.i1231 = select i1 %_14.1.i1230, i64 %122, i64 %_14.0.i1229
  %_16.i1232 = icmp ugt i64 %res.sroa.0.0.i1231, -4294967296
  %_17.i1233 = add nsw i64 %res.sroa.0.0.i1231, 4294967295
  %_0.sroa.0.0.i1234 = select i1 %_16.i1232, i64 %_17.i1233, i64 %res.sroa.0.0.i1231
  %_19.i313 = zext i64 %_0.sroa.0.0.i1234 to i128
  %_18.i314 = mul nuw nsw i128 %_19.i313, 7
  %_4.i1172 = lshr i128 %_18.i314, 64
  %x_hi.i1173 = trunc nuw nsw i128 %_4.i1172 to i64
  %t1.i1180 = mul nuw nsw i64 %x_hi.i1173, 4294967295
  %x_lo.i1171 = trunc i128 %_18.i314 to i64
  %_14.0.i1181 = add i64 %t1.i1180, %x_lo.i1171
  %_14.1.i1182 = icmp ult i64 %_14.0.i1181, %x_lo.i1171
  %123 = add i64 %_14.0.i1181, 4294967295
  %res.sroa.0.0.i1183 = select i1 %_14.1.i1182, i64 %123, i64 %_14.0.i1181
  %_16.i1184 = icmp ugt i64 %res.sroa.0.0.i1183, -4294967296
  %_17.i1185 = add nsw i64 %res.sroa.0.0.i1183, 4294967295
  %_0.sroa.0.0.i1186 = select i1 %_16.i1184, i64 %_17.i1185, i64 %res.sroa.0.0.i1183
  %_22.0.i316 = add i64 %_0.sroa.0.0.i1250, %_0.sroa.0.0.i1186
  %_22.1.i317 = icmp ult i64 %_22.0.i316, %_0.sroa.0.0.i1250
  %124 = add nuw i64 %_22.0.i316, 4294967295
  %_24.sroa.0.0.i318 = select i1 %_22.1.i317, i64 %124, i64 %_22.0.i316
  %_25.i319 = icmp ugt i64 %_24.sroa.0.0.i318, -4294967296
  %_26.i320 = add nsw i64 %_24.sroa.0.0.i318, 4294967295
  %_7.sroa.0.0.i321 = select i1 %_25.i319, i64 %_26.i320, i64 %_24.sroa.0.0.i318
  %_11.i274 = zext i64 %_7.sroa.0.0.i321 to i128
  %_11.i382 = zext i64 %_73.0 to i128
  %_15.i387 = zext i64 %g8.1 to i128
  %_16.i390 = mul nuw i128 %_11.i382, %_15.i387
  %_4.i964 = lshr i128 %_16.i390, 64
  %x_hi.i965 = trunc nuw i128 %_4.i964 to i64
  %x_hi_hi.i966 = lshr i64 %x_hi.i965, 32
  %x_lo.i963 = trunc i128 %_16.i390 to i64
  %_9.1.i969 = icmp ugt i64 %x_hi_hi.i966, %x_lo.i963
  %_9.0.i968 = sub i64 %x_lo.i963, %x_hi_hi.i966
  %_10.i970 = add i64 %_9.0.i968, -4294967295
  %spec.select.i971 = select i1 %_9.1.i969, i64 %_10.i970, i64 %_9.0.i968
  %x_hi_lo.i967 = and i64 %x_hi.i965, 4294967295
  %t1.i972 = mul nuw i64 %x_hi_lo.i967, 4294967295
  %_14.0.i973 = add i64 %spec.select.i971, %t1.i972
  %_14.1.i974 = icmp ult i64 %_14.0.i973, %spec.select.i971
  %125 = add i64 %_14.0.i973, 4294967295
  %res.sroa.0.0.i975 = select i1 %_14.1.i974, i64 %125, i64 %_14.0.i973
  %_16.i976 = icmp ugt i64 %res.sroa.0.0.i975, -4294967296
  %_17.i977 = add nsw i64 %res.sroa.0.0.i975, 4294967295
  %_0.sroa.0.0.i978 = select i1 %_16.i976, i64 %_17.i977, i64 %res.sroa.0.0.i975
  %_14.i386 = zext i64 %_73.1 to i128
  %_12.i383 = zext i64 %g8.0 to i128
  %_17.i392 = mul nuw i128 %_14.i386, %_12.i383
  %_4.i948 = lshr i128 %_17.i392, 64
  %x_hi.i949 = trunc nuw i128 %_4.i948 to i64
  %x_hi_hi.i950 = lshr i64 %x_hi.i949, 32
  %x_lo.i947 = trunc i128 %_17.i392 to i64
  %_9.1.i953 = icmp ugt i64 %x_hi_hi.i950, %x_lo.i947
  %_9.0.i952 = sub i64 %x_lo.i947, %x_hi_hi.i950
  %_10.i954 = add i64 %_9.0.i952, -4294967295
  %spec.select.i955 = select i1 %_9.1.i953, i64 %_10.i954, i64 %_9.0.i952
  %x_hi_lo.i951 = and i64 %x_hi.i949, 4294967295
  %t1.i956 = mul nuw i64 %x_hi_lo.i951, 4294967295
  %_14.0.i957 = add i64 %spec.select.i955, %t1.i956
  %_14.1.i958 = icmp ult i64 %_14.0.i957, %spec.select.i955
  %126 = add i64 %_14.0.i957, 4294967295
  %res.sroa.0.0.i959 = select i1 %_14.1.i958, i64 %126, i64 %_14.0.i957
  %_16.i960 = icmp ugt i64 %res.sroa.0.0.i959, -4294967296
  %_17.i961 = add nsw i64 %res.sroa.0.0.i959, 4294967295
  %_0.sroa.0.0.i962 = select i1 %_16.i960, i64 %_17.i961, i64 %res.sroa.0.0.i959
  %_29.0.i403 = add i64 %_0.sroa.0.0.i962, %_0.sroa.0.0.i978
  %_29.1.i404 = icmp ult i64 %_29.0.i403, %_0.sroa.0.0.i978
  %127 = add nuw i64 %_29.0.i403, 4294967295
  %_30.sroa.0.0.i405 = select i1 %_29.1.i404, i64 %127, i64 %_29.0.i403
  %_31.i406 = icmp ugt i64 %_30.sroa.0.0.i405, -4294967296
  %_32.i407 = add nsw i64 %_30.sroa.0.0.i405, 4294967295
  %_9.sroa.0.0.i408 = select i1 %_31.i406, i64 %_32.i407, i64 %_30.sroa.0.0.i405
  %_13.0.i56 = add i64 %_9.sroa.0.0.i408, %_74.1
  %_13.1.i57 = icmp ult i64 %_13.0.i56, %_9.sroa.0.0.i408
  %128 = add i64 %_13.0.i56, 4294967295
  %_14.sroa.0.0.i58 = select i1 %_13.1.i57, i64 %128, i64 %_13.0.i56
  %_15.i59 = icmp ugt i64 %_14.sroa.0.0.i58, -4294967296
  %_16.i60 = add nsw i64 %_14.sroa.0.0.i58, 4294967295
  %_4.sroa.0.0.i61 = select i1 %_15.i59, i64 %_16.i60, i64 %_14.sroa.0.0.i58
  %_229.1 = icmp ult i64 %_4.sroa.0.0.i61, %_243
  %_229.0 = sub i64 %_4.sroa.0.0.i61, %_243
  %129 = add i64 %_229.0, -4294967295
  %_230.sroa.0.0 = select i1 %_229.1, i64 %129, i64 %_229.0
  %_15.i279 = zext i64 %_230.sroa.0.0 to i128
  %_16.i282 = mul nuw i128 %_11.i274, %_15.i279
  %_4.i1284 = lshr i128 %_16.i282, 64
  %x_hi.i1285 = trunc nuw i128 %_4.i1284 to i64
  %x_hi_hi.i1286 = lshr i64 %x_hi.i1285, 32
  %x_lo.i1283 = trunc i128 %_16.i282 to i64
  %_9.1.i1289 = icmp ugt i64 %x_hi_hi.i1286, %x_lo.i1283
  %_9.0.i1288 = sub i64 %x_lo.i1283, %x_hi_hi.i1286
  %_10.i1290 = add i64 %_9.0.i1288, -4294967295
  %spec.select.i1291 = select i1 %_9.1.i1289, i64 %_10.i1290, i64 %_9.0.i1288
  %x_hi_lo.i1287 = and i64 %x_hi.i1285, 4294967295
  %t1.i1292 = mul nuw i64 %x_hi_lo.i1287, 4294967295
  %_14.0.i1293 = add i64 %spec.select.i1291, %t1.i1292
  %_14.1.i1294 = icmp ult i64 %_14.0.i1293, %spec.select.i1291
  %130 = add i64 %_14.0.i1293, 4294967295
  %res.sroa.0.0.i1295 = select i1 %_14.1.i1294, i64 %130, i64 %_14.0.i1293
  %_16.i1296 = icmp ugt i64 %res.sroa.0.0.i1295, -4294967296
  %_17.i1297 = add nsw i64 %res.sroa.0.0.i1295, 4294967295
  %_0.sroa.0.0.i1298 = select i1 %_16.i1296, i64 %_17.i1297, i64 %res.sroa.0.0.i1295
  %_16.i309 = mul nuw i128 %_11.i301, %_15.i306
  %_4.i1204 = lshr i128 %_16.i309, 64
  %x_hi.i1205 = trunc nuw i128 %_4.i1204 to i64
  %x_hi_hi.i1206 = lshr i64 %x_hi.i1205, 32
  %x_lo.i1203 = trunc i128 %_16.i309 to i64
  %_9.1.i1209 = icmp ugt i64 %x_hi_hi.i1206, %x_lo.i1203
  %_9.0.i1208 = sub i64 %x_lo.i1203, %x_hi_hi.i1206
  %_10.i1210 = add i64 %_9.0.i1208, -4294967295
  %spec.select.i1211 = select i1 %_9.1.i1209, i64 %_10.i1210, i64 %_9.0.i1208
  %x_hi_lo.i1207 = and i64 %x_hi.i1205, 4294967295
  %t1.i1212 = mul nuw i64 %x_hi_lo.i1207, 4294967295
  %_14.0.i1213 = add i64 %spec.select.i1211, %t1.i1212
  %_14.1.i1214 = icmp ult i64 %_14.0.i1213, %spec.select.i1211
  %131 = add i64 %_14.0.i1213, 4294967295
  %res.sroa.0.0.i1215 = select i1 %_14.1.i1214, i64 %131, i64 %_14.0.i1213
  %_16.i1216 = icmp ugt i64 %res.sroa.0.0.i1215, -4294967296
  %_17.i1217 = add nsw i64 %res.sroa.0.0.i1215, 4294967295
  %_0.sroa.0.0.i1218 = select i1 %_16.i1216, i64 %_17.i1217, i64 %res.sroa.0.0.i1215
  %_17.i311 = mul nuw i128 %_14.i305, %_12.i302
  %_4.i1188 = lshr i128 %_17.i311, 64
  %x_hi.i1189 = trunc nuw i128 %_4.i1188 to i64
  %x_hi_hi.i1190 = lshr i64 %x_hi.i1189, 32
  %x_lo.i1187 = trunc i128 %_17.i311 to i64
  %_9.1.i1193 = icmp ugt i64 %x_hi_hi.i1190, %x_lo.i1187
  %_9.0.i1192 = sub i64 %x_lo.i1187, %x_hi_hi.i1190
  %_10.i1194 = add i64 %_9.0.i1192, -4294967295
  %spec.select.i1195 = select i1 %_9.1.i1193, i64 %_10.i1194, i64 %_9.0.i1192
  %x_hi_lo.i1191 = and i64 %x_hi.i1189, 4294967295
  %t1.i1196 = mul nuw i64 %x_hi_lo.i1191, 4294967295
  %_14.0.i1197 = add i64 %spec.select.i1195, %t1.i1196
  %_14.1.i1198 = icmp ult i64 %_14.0.i1197, %spec.select.i1195
  %132 = add i64 %_14.0.i1197, 4294967295
  %res.sroa.0.0.i1199 = select i1 %_14.1.i1198, i64 %132, i64 %_14.0.i1197
  %_16.i1200 = icmp ugt i64 %res.sroa.0.0.i1199, -4294967296
  %_17.i1201 = add nsw i64 %res.sroa.0.0.i1199, 4294967295
  %_0.sroa.0.0.i1202 = select i1 %_16.i1200, i64 %_17.i1201, i64 %res.sroa.0.0.i1199
  %_29.0.i322 = add i64 %_0.sroa.0.0.i1218, %_0.sroa.0.0.i1202
  %_29.1.i323 = icmp ult i64 %_29.0.i322, %_0.sroa.0.0.i1218
  %133 = add nuw i64 %_29.0.i322, 4294967295
  %_30.sroa.0.0.i324 = select i1 %_29.1.i323, i64 %133, i64 %_29.0.i322
  %_31.i325 = icmp ugt i64 %_30.sroa.0.0.i324, -4294967296
  %_32.i326 = add nsw i64 %_30.sroa.0.0.i324, 4294967295
  %_9.sroa.0.0.i327 = select i1 %_31.i325, i64 %_32.i326, i64 %_30.sroa.0.0.i324
  %_14.i278 = zext i64 %_9.sroa.0.0.i327 to i128
  %_10.i384 = mul nuw i128 %_11.i382, %_12.i383
  %_4.i996 = lshr i128 %_10.i384, 64
  %x_hi.i997 = trunc nuw i128 %_4.i996 to i64
  %x_hi_hi.i998 = lshr i64 %x_hi.i997, 32
  %x_lo.i995 = trunc i128 %_10.i384 to i64
  %_9.1.i1001 = icmp ugt i64 %x_hi_hi.i998, %x_lo.i995
  %_9.0.i1000 = sub i64 %x_lo.i995, %x_hi_hi.i998
  %_10.i1002 = add i64 %_9.0.i1000, -4294967295
  %spec.select.i1003 = select i1 %_9.1.i1001, i64 %_10.i1002, i64 %_9.0.i1000
  %x_hi_lo.i999 = and i64 %x_hi.i997, 4294967295
  %t1.i1004 = mul nuw i64 %x_hi_lo.i999, 4294967295
  %_14.0.i1005 = add i64 %spec.select.i1003, %t1.i1004
  %_14.1.i1006 = icmp ult i64 %_14.0.i1005, %spec.select.i1003
  %134 = add i64 %_14.0.i1005, 4294967295
  %res.sroa.0.0.i1007 = select i1 %_14.1.i1006, i64 %134, i64 %_14.0.i1005
  %_16.i1008 = icmp ugt i64 %res.sroa.0.0.i1007, -4294967296
  %_17.i1009 = add nsw i64 %res.sroa.0.0.i1007, 4294967295
  %_0.sroa.0.0.i1010 = select i1 %_16.i1008, i64 %_17.i1009, i64 %res.sroa.0.0.i1007
  %_13.i388 = mul nuw i128 %_14.i386, %_15.i387
  %_4.i980 = lshr i128 %_13.i388, 64
  %x_hi.i981 = trunc nuw i128 %_4.i980 to i64
  %x_hi_hi.i982 = lshr i64 %x_hi.i981, 32
  %x_lo.i979 = trunc i128 %_13.i388 to i64
  %_9.1.i985 = icmp ugt i64 %x_hi_hi.i982, %x_lo.i979
  %_9.0.i984 = sub i64 %x_lo.i979, %x_hi_hi.i982
  %_10.i986 = add i64 %_9.0.i984, -4294967295
  %spec.select.i987 = select i1 %_9.1.i985, i64 %_10.i986, i64 %_9.0.i984
  %x_hi_lo.i983 = and i64 %x_hi.i981, 4294967295
  %t1.i988 = mul nuw i64 %x_hi_lo.i983, 4294967295
  %_14.0.i989 = add i64 %spec.select.i987, %t1.i988
  %_14.1.i990 = icmp ult i64 %_14.0.i989, %spec.select.i987
  %135 = add i64 %_14.0.i989, 4294967295
  %res.sroa.0.0.i991 = select i1 %_14.1.i990, i64 %135, i64 %_14.0.i989
  %_16.i992 = icmp ugt i64 %res.sroa.0.0.i991, -4294967296
  %_17.i993 = add nsw i64 %res.sroa.0.0.i991, 4294967295
  %_0.sroa.0.0.i994 = select i1 %_16.i992, i64 %_17.i993, i64 %res.sroa.0.0.i991
  %_19.i394 = zext i64 %_0.sroa.0.0.i994 to i128
  %_18.i395 = mul nuw nsw i128 %_19.i394, 7
  %_4.i932 = lshr i128 %_18.i395, 64
  %x_hi.i933 = trunc nuw nsw i128 %_4.i932 to i64
  %t1.i940 = mul nuw nsw i64 %x_hi.i933, 4294967295
  %x_lo.i931 = trunc i128 %_18.i395 to i64
  %_14.0.i941 = add i64 %t1.i940, %x_lo.i931
  %_14.1.i942 = icmp ult i64 %_14.0.i941, %x_lo.i931
  %136 = add i64 %_14.0.i941, 4294967295
  %res.sroa.0.0.i943 = select i1 %_14.1.i942, i64 %136, i64 %_14.0.i941
  %_16.i944 = icmp ugt i64 %res.sroa.0.0.i943, -4294967296
  %_17.i945 = add nsw i64 %res.sroa.0.0.i943, 4294967295
  %_0.sroa.0.0.i946 = select i1 %_16.i944, i64 %_17.i945, i64 %res.sroa.0.0.i943
  %_22.0.i397 = add i64 %_0.sroa.0.0.i946, %_0.sroa.0.0.i1010
  %_22.1.i398 = icmp ult i64 %_22.0.i397, %_0.sroa.0.0.i1010
  %137 = add nuw i64 %_22.0.i397, 4294967295
  %_24.sroa.0.0.i399 = select i1 %_22.1.i398, i64 %137, i64 %_22.0.i397
  %_25.i400 = icmp ugt i64 %_24.sroa.0.0.i399, -4294967296
  %_26.i401 = add nsw i64 %_24.sroa.0.0.i399, 4294967295
  %_7.sroa.0.0.i402 = select i1 %_25.i400, i64 %_26.i401, i64 %_24.sroa.0.0.i399
  %_7.0.i50 = add i64 %_7.sroa.0.0.i402, %_74.0
  %_7.1.i51 = icmp ult i64 %_7.0.i50, %_7.sroa.0.0.i402
  %138 = add i64 %_7.0.i50, 4294967295
  %_8.sroa.0.0.i52 = select i1 %_7.1.i51, i64 %138, i64 %_7.0.i50
  %_9.i53 = icmp ugt i64 %_8.sroa.0.0.i52, -4294967296
  %_10.i54 = add nsw i64 %_8.sroa.0.0.i52, 4294967295
  %_3.sroa.0.0.i55 = select i1 %_9.i53, i64 %_10.i54, i64 %_8.sroa.0.0.i52
  %_225.1 = icmp ult i64 %_3.sroa.0.0.i55, %_242
  %_225.0 = sub i64 %_3.sroa.0.0.i55, %_242
  %139 = add i64 %_225.0, -4294967295
  %_226.sroa.0.0 = select i1 %_225.1, i64 %139, i64 %_225.0
  %_12.i275 = zext i64 %_226.sroa.0.0 to i128
  %_17.i284 = mul nuw i128 %_14.i278, %_12.i275
  %_4.i1268 = lshr i128 %_17.i284, 64
  %x_hi.i1269 = trunc nuw i128 %_4.i1268 to i64
  %x_hi_hi.i1270 = lshr i64 %x_hi.i1269, 32
  %x_lo.i1267 = trunc i128 %_17.i284 to i64
  %_9.1.i1273 = icmp ugt i64 %x_hi_hi.i1270, %x_lo.i1267
  %_9.0.i1272 = sub i64 %x_lo.i1267, %x_hi_hi.i1270
  %_10.i1274 = add i64 %_9.0.i1272, -4294967295
  %spec.select.i1275 = select i1 %_9.1.i1273, i64 %_10.i1274, i64 %_9.0.i1272
  %x_hi_lo.i1271 = and i64 %x_hi.i1269, 4294967295
  %t1.i1276 = mul nuw i64 %x_hi_lo.i1271, 4294967295
  %_14.0.i1277 = add i64 %spec.select.i1275, %t1.i1276
  %_14.1.i1278 = icmp ult i64 %_14.0.i1277, %spec.select.i1275
  %140 = add i64 %_14.0.i1277, 4294967295
  %res.sroa.0.0.i1279 = select i1 %_14.1.i1278, i64 %140, i64 %_14.0.i1277
  %_16.i1280 = icmp ugt i64 %res.sroa.0.0.i1279, -4294967296
  %_17.i1281 = add nsw i64 %res.sroa.0.0.i1279, 4294967295
  %_0.sroa.0.0.i1282 = select i1 %_16.i1280, i64 %_17.i1281, i64 %res.sroa.0.0.i1279
  %_29.0.i295 = add i64 %_0.sroa.0.0.i1298, %_0.sroa.0.0.i1282
  %_29.1.i296 = icmp ult i64 %_29.0.i295, %_0.sroa.0.0.i1298
  %141 = add nuw i64 %_29.0.i295, 4294967295
  %_30.sroa.0.0.i297 = select i1 %_29.1.i296, i64 %141, i64 %_29.0.i295
  %_31.i298 = icmp ugt i64 %_30.sroa.0.0.i297, -4294967296
  %_32.i299 = add nsw i64 %_30.sroa.0.0.i297, 4294967295
  %_9.sroa.0.0.i300 = select i1 %_31.i298, i64 %_32.i299, i64 %_30.sroa.0.0.i297
  %_13.0.i44 = add i64 %_9.sroa.0.0.i300, %_9.sroa.0.0.i381
  %_13.1.i45 = icmp ult i64 %_13.0.i44, %_9.sroa.0.0.i381
  %142 = add i64 %_13.0.i44, 4294967295
  %_14.sroa.0.0.i46 = select i1 %_13.1.i45, i64 %142, i64 %_13.0.i44
  %_15.i47 = icmp ugt i64 %_14.sroa.0.0.i46, -4294967296
  %_16.i48 = add nsw i64 %_14.sroa.0.0.i46, 4294967295
  %_4.sroa.0.0.i49 = select i1 %_15.i47, i64 %_16.i48, i64 %_14.sroa.0.0.i46
  %_10.i357 = mul nuw i128 %_11.i355, %_12.i356
  %_4.i1076 = lshr i128 %_10.i357, 64
  %x_hi.i1077 = trunc nuw i128 %_4.i1076 to i64
  %x_hi_hi.i1078 = lshr i64 %x_hi.i1077, 32
  %x_lo.i1075 = trunc i128 %_10.i357 to i64
  %_9.1.i1081 = icmp ugt i64 %x_hi_hi.i1078, %x_lo.i1075
  %_9.0.i1080 = sub i64 %x_lo.i1075, %x_hi_hi.i1078
  %_10.i1082 = add i64 %_9.0.i1080, -4294967295
  %spec.select.i1083 = select i1 %_9.1.i1081, i64 %_10.i1082, i64 %_9.0.i1080
  %x_hi_lo.i1079 = and i64 %x_hi.i1077, 4294967295
  %t1.i1084 = mul nuw i64 %x_hi_lo.i1079, 4294967295
  %_14.0.i1085 = add i64 %spec.select.i1083, %t1.i1084
  %_14.1.i1086 = icmp ult i64 %_14.0.i1085, %spec.select.i1083
  %143 = add i64 %_14.0.i1085, 4294967295
  %res.sroa.0.0.i1087 = select i1 %_14.1.i1086, i64 %143, i64 %_14.0.i1085
  %_16.i1088 = icmp ugt i64 %res.sroa.0.0.i1087, -4294967296
  %_17.i1089 = add nsw i64 %res.sroa.0.0.i1087, 4294967295
  %_0.sroa.0.0.i1090 = select i1 %_16.i1088, i64 %_17.i1089, i64 %res.sroa.0.0.i1087
  %_13.i361 = mul nuw i128 %_14.i359, %_15.i360
  %_4.i1060 = lshr i128 %_13.i361, 64
  %x_hi.i1061 = trunc nuw i128 %_4.i1060 to i64
  %x_hi_hi.i1062 = lshr i64 %x_hi.i1061, 32
  %x_lo.i1059 = trunc i128 %_13.i361 to i64
  %_9.1.i1065 = icmp ugt i64 %x_hi_hi.i1062, %x_lo.i1059
  %_9.0.i1064 = sub i64 %x_lo.i1059, %x_hi_hi.i1062
  %_10.i1066 = add i64 %_9.0.i1064, -4294967295
  %spec.select.i1067 = select i1 %_9.1.i1065, i64 %_10.i1066, i64 %_9.0.i1064
  %x_hi_lo.i1063 = and i64 %x_hi.i1061, 4294967295
  %t1.i1068 = mul nuw i64 %x_hi_lo.i1063, 4294967295
  %_14.0.i1069 = add i64 %spec.select.i1067, %t1.i1068
  %_14.1.i1070 = icmp ult i64 %_14.0.i1069, %spec.select.i1067
  %144 = add i64 %_14.0.i1069, 4294967295
  %res.sroa.0.0.i1071 = select i1 %_14.1.i1070, i64 %144, i64 %_14.0.i1069
  %_16.i1072 = icmp ugt i64 %res.sroa.0.0.i1071, -4294967296
  %_17.i1073 = add nsw i64 %res.sroa.0.0.i1071, 4294967295
  %_0.sroa.0.0.i1074 = select i1 %_16.i1072, i64 %_17.i1073, i64 %res.sroa.0.0.i1071
  %_19.i367 = zext i64 %_0.sroa.0.0.i1074 to i128
  %_18.i368 = mul nuw nsw i128 %_19.i367, 7
  %_4.i1012 = lshr i128 %_18.i368, 64
  %x_hi.i1013 = trunc nuw nsw i128 %_4.i1012 to i64
  %t1.i1020 = mul nuw nsw i64 %x_hi.i1013, 4294967295
  %x_lo.i1011 = trunc i128 %_18.i368 to i64
  %_14.0.i1021 = add i64 %t1.i1020, %x_lo.i1011
  %_14.1.i1022 = icmp ult i64 %_14.0.i1021, %x_lo.i1011
  %145 = add i64 %_14.0.i1021, 4294967295
  %res.sroa.0.0.i1023 = select i1 %_14.1.i1022, i64 %145, i64 %_14.0.i1021
  %_16.i1024 = icmp ugt i64 %res.sroa.0.0.i1023, -4294967296
  %_17.i1025 = add nsw i64 %res.sroa.0.0.i1023, 4294967295
  %_0.sroa.0.0.i1026 = select i1 %_16.i1024, i64 %_17.i1025, i64 %res.sroa.0.0.i1023
  %_22.0.i370 = add i64 %_0.sroa.0.0.i1026, %_0.sroa.0.0.i1090
  %_22.1.i371 = icmp ult i64 %_22.0.i370, %_0.sroa.0.0.i1090
  %146 = add nuw i64 %_22.0.i370, 4294967295
  %_24.sroa.0.0.i372 = select i1 %_22.1.i371, i64 %146, i64 %_22.0.i370
  %_25.i373 = icmp ugt i64 %_24.sroa.0.0.i372, -4294967296
  %_26.i374 = add nsw i64 %_24.sroa.0.0.i372, 4294967295
  %_7.sroa.0.0.i375 = select i1 %_25.i373, i64 %_26.i374, i64 %_24.sroa.0.0.i372
  %_10.i276 = mul nuw i128 %_11.i274, %_12.i275
  %_4.i1316 = lshr i128 %_10.i276, 64
  %x_hi.i1317 = trunc nuw i128 %_4.i1316 to i64
  %x_hi_hi.i1318 = lshr i64 %x_hi.i1317, 32
  %x_lo.i1315 = trunc i128 %_10.i276 to i64
  %_9.1.i1321 = icmp ugt i64 %x_hi_hi.i1318, %x_lo.i1315
  %_9.0.i1320 = sub i64 %x_lo.i1315, %x_hi_hi.i1318
  %_10.i1322 = add i64 %_9.0.i1320, -4294967295
  %spec.select.i1323 = select i1 %_9.1.i1321, i64 %_10.i1322, i64 %_9.0.i1320
  %x_hi_lo.i1319 = and i64 %x_hi.i1317, 4294967295
  %t1.i1324 = mul nuw i64 %x_hi_lo.i1319, 4294967295
  %_14.0.i1325 = add i64 %spec.select.i1323, %t1.i1324
  %_14.1.i1326 = icmp ult i64 %_14.0.i1325, %spec.select.i1323
  %147 = add i64 %_14.0.i1325, 4294967295
  %res.sroa.0.0.i1327 = select i1 %_14.1.i1326, i64 %147, i64 %_14.0.i1325
  %_16.i1328 = icmp ugt i64 %res.sroa.0.0.i1327, -4294967296
  %_17.i1329 = add nsw i64 %res.sroa.0.0.i1327, 4294967295
  %_0.sroa.0.0.i1330 = select i1 %_16.i1328, i64 %_17.i1329, i64 %res.sroa.0.0.i1327
  %_13.i280 = mul nuw i128 %_14.i278, %_15.i279
  %_4.i1300 = lshr i128 %_13.i280, 64
  %x_hi.i1301 = trunc nuw i128 %_4.i1300 to i64
  %x_hi_hi.i1302 = lshr i64 %x_hi.i1301, 32
  %x_lo.i1299 = trunc i128 %_13.i280 to i64
  %_9.1.i1305 = icmp ugt i64 %x_hi_hi.i1302, %x_lo.i1299
  %_9.0.i1304 = sub i64 %x_lo.i1299, %x_hi_hi.i1302
  %_10.i1306 = add i64 %_9.0.i1304, -4294967295
  %spec.select.i1307 = select i1 %_9.1.i1305, i64 %_10.i1306, i64 %_9.0.i1304
  %x_hi_lo.i1303 = and i64 %x_hi.i1301, 4294967295
  %t1.i1308 = mul nuw i64 %x_hi_lo.i1303, 4294967295
  %_14.0.i1309 = add i64 %spec.select.i1307, %t1.i1308
  %_14.1.i1310 = icmp ult i64 %_14.0.i1309, %spec.select.i1307
  %148 = add i64 %_14.0.i1309, 4294967295
  %res.sroa.0.0.i1311 = select i1 %_14.1.i1310, i64 %148, i64 %_14.0.i1309
  %_16.i1312 = icmp ugt i64 %res.sroa.0.0.i1311, -4294967296
  %_17.i1313 = add nsw i64 %res.sroa.0.0.i1311, 4294967295
  %_0.sroa.0.0.i1314 = select i1 %_16.i1312, i64 %_17.i1313, i64 %res.sroa.0.0.i1311
  %_19.i286 = zext i64 %_0.sroa.0.0.i1314 to i128
  %_18.i287 = mul nuw nsw i128 %_19.i286, 7
  %_4.i1252 = lshr i128 %_18.i287, 64
  %x_hi.i1253 = trunc nuw nsw i128 %_4.i1252 to i64
  %t1.i1260 = mul nuw nsw i64 %x_hi.i1253, 4294967295
  %x_lo.i1251 = trunc i128 %_18.i287 to i64
  %_14.0.i1261 = add i64 %t1.i1260, %x_lo.i1251
  %_14.1.i1262 = icmp ult i64 %_14.0.i1261, %x_lo.i1251
  %149 = add i64 %_14.0.i1261, 4294967295
  %res.sroa.0.0.i1263 = select i1 %_14.1.i1262, i64 %149, i64 %_14.0.i1261
  %_16.i1264 = icmp ugt i64 %res.sroa.0.0.i1263, -4294967296
  %_17.i1265 = add nsw i64 %res.sroa.0.0.i1263, 4294967295
  %_0.sroa.0.0.i1266 = select i1 %_16.i1264, i64 %_17.i1265, i64 %res.sroa.0.0.i1263
  %_22.0.i289 = add i64 %_0.sroa.0.0.i1266, %_0.sroa.0.0.i1330
  %_22.1.i290 = icmp ult i64 %_22.0.i289, %_0.sroa.0.0.i1330
  %150 = add nuw i64 %_22.0.i289, 4294967295
  %_24.sroa.0.0.i291 = select i1 %_22.1.i290, i64 %150, i64 %_22.0.i289
  %_25.i292 = icmp ugt i64 %_24.sroa.0.0.i291, -4294967296
  %_26.i293 = add nsw i64 %_24.sroa.0.0.i291, 4294967295
  %_7.sroa.0.0.i294 = select i1 %_25.i292, i64 %_26.i293, i64 %_24.sroa.0.0.i291
  %_7.0.i38 = add i64 %_7.sroa.0.0.i294, %_7.sroa.0.0.i375
  %_7.1.i39 = icmp ult i64 %_7.0.i38, %_7.sroa.0.0.i375
  %151 = add i64 %_7.0.i38, 4294967295
  %_8.sroa.0.0.i40 = select i1 %_7.1.i39, i64 %151, i64 %_7.0.i38
  %_9.i41 = icmp ugt i64 %_8.sroa.0.0.i40, -4294967296
  %_10.i42 = add nsw i64 %_8.sroa.0.0.i40, 4294967295
  %_3.sroa.0.0.i43 = select i1 %_9.i41, i64 %_10.i42, i64 %_8.sroa.0.0.i40
  %152 = getelementptr inbounds nuw i8, ptr %_236, i64 24
  %_90.1 = load i64, ptr %152, align 8, !noundef !3
  %_91 = getelementptr inbounds nuw i8, ptr %_236, i64 16
  %_90.0 = load i64, ptr %_91, align 8, !noundef !3
  %153 = getelementptr inbounds nuw i8, ptr %v.0, i64 32
  %_92.0 = load i64, ptr %153, align 8, !noundef !3
  %154 = getelementptr inbounds nuw i8, ptr %v.0, i64 40
  %_92.1 = load i64, ptr %154, align 8, !noundef !3
  %_11.i247 = zext i64 %_90.0 to i128
  %_12.i248 = zext i64 %_92.0 to i128
  %_10.i249 = mul nuw i128 %_12.i248, %_11.i247
  %x_lo.i1395 = trunc i128 %_10.i249 to i64
  %_4.i1396 = lshr i128 %_10.i249, 64
  %x_hi.i1397 = trunc nuw i128 %_4.i1396 to i64
  %x_hi_hi.i1398 = lshr i64 %x_hi.i1397, 32
  %x_hi_lo.i1399 = and i64 %x_hi.i1397, 4294967295
  %_9.0.i1400 = sub i64 %x_lo.i1395, %x_hi_hi.i1398
  %_9.1.i1401 = icmp ugt i64 %x_hi_hi.i1398, %x_lo.i1395
  %_10.i1402 = add i64 %_9.0.i1400, -4294967295
  %spec.select.i1403 = select i1 %_9.1.i1401, i64 %_10.i1402, i64 %_9.0.i1400
  %t1.i1404 = mul nuw i64 %x_hi_lo.i1399, 4294967295
  %_14.0.i1405 = add i64 %spec.select.i1403, %t1.i1404
  %_14.1.i1406 = icmp ult i64 %_14.0.i1405, %spec.select.i1403
  %155 = add i64 %_14.0.i1405, 4294967295
  %res.sroa.0.0.i1407 = select i1 %_14.1.i1406, i64 %155, i64 %_14.0.i1405
  %_16.i1408 = icmp ugt i64 %res.sroa.0.0.i1407, -4294967296
  %_17.i1409 = add nsw i64 %res.sroa.0.0.i1407, 4294967295
  %_0.sroa.0.0.i1410 = select i1 %_16.i1408, i64 %_17.i1409, i64 %res.sroa.0.0.i1407
  %_14.i251 = zext i64 %_90.1 to i128
  %_15.i252 = zext i64 %_92.1 to i128
  %_13.i253 = mul nuw i128 %_15.i252, %_14.i251
  %x_lo.i1379 = trunc i128 %_13.i253 to i64
  %_4.i1380 = lshr i128 %_13.i253, 64
  %x_hi.i1381 = trunc nuw i128 %_4.i1380 to i64
  %x_hi_hi.i1382 = lshr i64 %x_hi.i1381, 32
  %x_hi_lo.i1383 = and i64 %x_hi.i1381, 4294967295
  %_9.0.i1384 = sub i64 %x_lo.i1379, %x_hi_hi.i1382
  %_9.1.i1385 = icmp ugt i64 %x_hi_hi.i1382, %x_lo.i1379
  %_10.i1386 = add i64 %_9.0.i1384, -4294967295
  %spec.select.i1387 = select i1 %_9.1.i1385, i64 %_10.i1386, i64 %_9.0.i1384
  %t1.i1388 = mul nuw i64 %x_hi_lo.i1383, 4294967295
  %_14.0.i1389 = add i64 %spec.select.i1387, %t1.i1388
  %_14.1.i1390 = icmp ult i64 %_14.0.i1389, %spec.select.i1387
  %156 = add i64 %_14.0.i1389, 4294967295
  %res.sroa.0.0.i1391 = select i1 %_14.1.i1390, i64 %156, i64 %_14.0.i1389
  %_16.i1392 = icmp ugt i64 %res.sroa.0.0.i1391, -4294967296
  %_17.i1393 = add nsw i64 %res.sroa.0.0.i1391, 4294967295
  %_0.sroa.0.0.i1394 = select i1 %_16.i1392, i64 %_17.i1393, i64 %res.sroa.0.0.i1391
  %_16.i255 = mul nuw i128 %_15.i252, %_11.i247
  %x_lo.i1363 = trunc i128 %_16.i255 to i64
  %_4.i1364 = lshr i128 %_16.i255, 64
  %x_hi.i1365 = trunc nuw i128 %_4.i1364 to i64
  %x_hi_hi.i1366 = lshr i64 %x_hi.i1365, 32
  %x_hi_lo.i1367 = and i64 %x_hi.i1365, 4294967295
  %_9.0.i1368 = sub i64 %x_lo.i1363, %x_hi_hi.i1366
  %_9.1.i1369 = icmp ugt i64 %x_hi_hi.i1366, %x_lo.i1363
  %_10.i1370 = add i64 %_9.0.i1368, -4294967295
  %spec.select.i1371 = select i1 %_9.1.i1369, i64 %_10.i1370, i64 %_9.0.i1368
  %t1.i1372 = mul nuw i64 %x_hi_lo.i1367, 4294967295
  %_14.0.i1373 = add i64 %spec.select.i1371, %t1.i1372
  %_14.1.i1374 = icmp ult i64 %_14.0.i1373, %spec.select.i1371
  %157 = add i64 %_14.0.i1373, 4294967295
  %res.sroa.0.0.i1375 = select i1 %_14.1.i1374, i64 %157, i64 %_14.0.i1373
  %_16.i1376 = icmp ugt i64 %res.sroa.0.0.i1375, -4294967296
  %_17.i1377 = add nsw i64 %res.sroa.0.0.i1375, 4294967295
  %_0.sroa.0.0.i1378 = select i1 %_16.i1376, i64 %_17.i1377, i64 %res.sroa.0.0.i1375
  %_17.i257 = mul nuw i128 %_12.i248, %_14.i251
  %x_lo.i1347 = trunc i128 %_17.i257 to i64
  %_4.i1348 = lshr i128 %_17.i257, 64
  %x_hi.i1349 = trunc nuw i128 %_4.i1348 to i64
  %x_hi_hi.i1350 = lshr i64 %x_hi.i1349, 32
  %x_hi_lo.i1351 = and i64 %x_hi.i1349, 4294967295
  %_9.0.i1352 = sub i64 %x_lo.i1347, %x_hi_hi.i1350
  %_9.1.i1353 = icmp ugt i64 %x_hi_hi.i1350, %x_lo.i1347
  %_10.i1354 = add i64 %_9.0.i1352, -4294967295
  %spec.select.i1355 = select i1 %_9.1.i1353, i64 %_10.i1354, i64 %_9.0.i1352
  %t1.i1356 = mul nuw i64 %x_hi_lo.i1351, 4294967295
  %_14.0.i1357 = add i64 %spec.select.i1355, %t1.i1356
  %_14.1.i1358 = icmp ult i64 %_14.0.i1357, %spec.select.i1355
  %158 = add i64 %_14.0.i1357, 4294967295
  %res.sroa.0.0.i1359 = select i1 %_14.1.i1358, i64 %158, i64 %_14.0.i1357
  %_16.i1360 = icmp ugt i64 %res.sroa.0.0.i1359, -4294967296
  %_17.i1361 = add nsw i64 %res.sroa.0.0.i1359, 4294967295
  %_0.sroa.0.0.i1362 = select i1 %_16.i1360, i64 %_17.i1361, i64 %res.sroa.0.0.i1359
  %_19.i259 = zext i64 %_0.sroa.0.0.i1394 to i128
  %_18.i260 = mul nuw nsw i128 %_19.i259, 7
  %x_lo.i1331 = trunc i128 %_18.i260 to i64
  %_4.i1332 = lshr i128 %_18.i260, 64
  %x_hi.i1333 = trunc nuw nsw i128 %_4.i1332 to i64
  %t1.i1340 = mul nuw nsw i64 %x_hi.i1333, 4294967295
  %_14.0.i1341 = add i64 %t1.i1340, %x_lo.i1331
  %_14.1.i1342 = icmp ult i64 %_14.0.i1341, %x_lo.i1331
  %159 = add i64 %_14.0.i1341, 4294967295
  %res.sroa.0.0.i1343 = select i1 %_14.1.i1342, i64 %159, i64 %_14.0.i1341
  %_16.i1344 = icmp ugt i64 %res.sroa.0.0.i1343, -4294967296
  %_17.i1345 = add nsw i64 %res.sroa.0.0.i1343, 4294967295
  %_0.sroa.0.0.i1346 = select i1 %_16.i1344, i64 %_17.i1345, i64 %res.sroa.0.0.i1343
  %_22.0.i262 = add i64 %_0.sroa.0.0.i1346, %_0.sroa.0.0.i1410
  %_22.1.i263 = icmp ult i64 %_22.0.i262, %_0.sroa.0.0.i1410
  %160 = add nuw i64 %_22.0.i262, 4294967295
  %_24.sroa.0.0.i264 = select i1 %_22.1.i263, i64 %160, i64 %_22.0.i262
  %_25.i265 = icmp ugt i64 %_24.sroa.0.0.i264, -4294967296
  %_26.i266 = add nsw i64 %_24.sroa.0.0.i264, 4294967295
  %_7.sroa.0.0.i267 = select i1 %_25.i265, i64 %_26.i266, i64 %_24.sroa.0.0.i264
  %_29.0.i268 = add i64 %_0.sroa.0.0.i1378, %_0.sroa.0.0.i1362
  %_29.1.i269 = icmp ult i64 %_29.0.i268, %_0.sroa.0.0.i1378
  %161 = add nuw i64 %_29.0.i268, 4294967295
  %_30.sroa.0.0.i270 = select i1 %_29.1.i269, i64 %161, i64 %_29.0.i268
  %_31.i271 = icmp ugt i64 %_30.sroa.0.0.i270, -4294967296
  %_32.i272 = add nsw i64 %_30.sroa.0.0.i270, 4294967295
  %_9.sroa.0.0.i273 = select i1 %_31.i271, i64 %_32.i272, i64 %_30.sroa.0.0.i270
  %_11.i220 = zext i64 %_7.sroa.0.0.i267 to i128
  %_10.i222 = mul nuw i128 %_11.i220, %_12.i302
  %x_lo.i1475 = trunc i128 %_10.i222 to i64
  %_4.i1476 = lshr i128 %_10.i222, 64
  %x_hi.i1477 = trunc nuw i128 %_4.i1476 to i64
  %x_hi_hi.i1478 = lshr i64 %x_hi.i1477, 32
  %x_hi_lo.i1479 = and i64 %x_hi.i1477, 4294967295
  %_9.0.i1480 = sub i64 %x_lo.i1475, %x_hi_hi.i1478
  %_9.1.i1481 = icmp ugt i64 %x_hi_hi.i1478, %x_lo.i1475
  %_10.i1482 = add i64 %_9.0.i1480, -4294967295
  %spec.select.i1483 = select i1 %_9.1.i1481, i64 %_10.i1482, i64 %_9.0.i1480
  %t1.i1484 = mul nuw i64 %x_hi_lo.i1479, 4294967295
  %_14.0.i1485 = add i64 %spec.select.i1483, %t1.i1484
  %_14.1.i1486 = icmp ult i64 %_14.0.i1485, %spec.select.i1483
  %162 = add i64 %_14.0.i1485, 4294967295
  %res.sroa.0.0.i1487 = select i1 %_14.1.i1486, i64 %162, i64 %_14.0.i1485
  %_16.i1488 = icmp ugt i64 %res.sroa.0.0.i1487, -4294967296
  %_17.i1489 = add nsw i64 %res.sroa.0.0.i1487, 4294967295
  %_0.sroa.0.0.i1490 = select i1 %_16.i1488, i64 %_17.i1489, i64 %res.sroa.0.0.i1487
  %_14.i224 = zext i64 %_9.sroa.0.0.i273 to i128
  %_13.i226 = mul nuw i128 %_14.i224, %_15.i306
  %x_lo.i1459 = trunc i128 %_13.i226 to i64
  %_4.i1460 = lshr i128 %_13.i226, 64
  %x_hi.i1461 = trunc nuw i128 %_4.i1460 to i64
  %x_hi_hi.i1462 = lshr i64 %x_hi.i1461, 32
  %x_hi_lo.i1463 = and i64 %x_hi.i1461, 4294967295
  %_9.0.i1464 = sub i64 %x_lo.i1459, %x_hi_hi.i1462
  %_9.1.i1465 = icmp ugt i64 %x_hi_hi.i1462, %x_lo.i1459
  %_10.i1466 = add i64 %_9.0.i1464, -4294967295
  %spec.select.i1467 = select i1 %_9.1.i1465, i64 %_10.i1466, i64 %_9.0.i1464
  %t1.i1468 = mul nuw i64 %x_hi_lo.i1463, 4294967295
  %_14.0.i1469 = add i64 %spec.select.i1467, %t1.i1468
  %_14.1.i1470 = icmp ult i64 %_14.0.i1469, %spec.select.i1467
  %163 = add i64 %_14.0.i1469, 4294967295
  %res.sroa.0.0.i1471 = select i1 %_14.1.i1470, i64 %163, i64 %_14.0.i1469
  %_16.i1472 = icmp ugt i64 %res.sroa.0.0.i1471, -4294967296
  %_17.i1473 = add nsw i64 %res.sroa.0.0.i1471, 4294967295
  %_0.sroa.0.0.i1474 = select i1 %_16.i1472, i64 %_17.i1473, i64 %res.sroa.0.0.i1471
  %_16.i228 = mul nuw i128 %_11.i220, %_15.i306
  %x_lo.i1443 = trunc i128 %_16.i228 to i64
  %_4.i1444 = lshr i128 %_16.i228, 64
  %x_hi.i1445 = trunc nuw i128 %_4.i1444 to i64
  %x_hi_hi.i1446 = lshr i64 %x_hi.i1445, 32
  %x_hi_lo.i1447 = and i64 %x_hi.i1445, 4294967295
  %_9.0.i1448 = sub i64 %x_lo.i1443, %x_hi_hi.i1446
  %_9.1.i1449 = icmp ugt i64 %x_hi_hi.i1446, %x_lo.i1443
  %_10.i1450 = add i64 %_9.0.i1448, -4294967295
  %spec.select.i1451 = select i1 %_9.1.i1449, i64 %_10.i1450, i64 %_9.0.i1448
  %t1.i1452 = mul nuw i64 %x_hi_lo.i1447, 4294967295
  %_14.0.i1453 = add i64 %spec.select.i1451, %t1.i1452
  %_14.1.i1454 = icmp ult i64 %_14.0.i1453, %spec.select.i1451
  %164 = add i64 %_14.0.i1453, 4294967295
  %res.sroa.0.0.i1455 = select i1 %_14.1.i1454, i64 %164, i64 %_14.0.i1453
  %_16.i1456 = icmp ugt i64 %res.sroa.0.0.i1455, -4294967296
  %_17.i1457 = add nsw i64 %res.sroa.0.0.i1455, 4294967295
  %_0.sroa.0.0.i1458 = select i1 %_16.i1456, i64 %_17.i1457, i64 %res.sroa.0.0.i1455
  %_17.i230 = mul nuw i128 %_14.i224, %_12.i302
  %x_lo.i1427 = trunc i128 %_17.i230 to i64
  %_4.i1428 = lshr i128 %_17.i230, 64
  %x_hi.i1429 = trunc nuw i128 %_4.i1428 to i64
  %x_hi_hi.i1430 = lshr i64 %x_hi.i1429, 32
  %x_hi_lo.i1431 = and i64 %x_hi.i1429, 4294967295
  %_9.0.i1432 = sub i64 %x_lo.i1427, %x_hi_hi.i1430
  %_9.1.i1433 = icmp ugt i64 %x_hi_hi.i1430, %x_lo.i1427
  %_10.i1434 = add i64 %_9.0.i1432, -4294967295
  %spec.select.i1435 = select i1 %_9.1.i1433, i64 %_10.i1434, i64 %_9.0.i1432
  %t1.i1436 = mul nuw i64 %x_hi_lo.i1431, 4294967295
  %_14.0.i1437 = add i64 %spec.select.i1435, %t1.i1436
  %_14.1.i1438 = icmp ult i64 %_14.0.i1437, %spec.select.i1435
  %165 = add i64 %_14.0.i1437, 4294967295
  %res.sroa.0.0.i1439 = select i1 %_14.1.i1438, i64 %165, i64 %_14.0.i1437
  %_16.i1440 = icmp ugt i64 %res.sroa.0.0.i1439, -4294967296
  %_17.i1441 = add nsw i64 %res.sroa.0.0.i1439, 4294967295
  %_0.sroa.0.0.i1442 = select i1 %_16.i1440, i64 %_17.i1441, i64 %res.sroa.0.0.i1439
  %_19.i232 = zext i64 %_0.sroa.0.0.i1474 to i128
  %_18.i233 = mul nuw nsw i128 %_19.i232, 7
  %x_lo.i1411 = trunc i128 %_18.i233 to i64
  %_4.i1412 = lshr i128 %_18.i233, 64
  %x_hi.i1413 = trunc nuw nsw i128 %_4.i1412 to i64
  %t1.i1420 = mul nuw nsw i64 %x_hi.i1413, 4294967295
  %_14.0.i1421 = add i64 %t1.i1420, %x_lo.i1411
  %_14.1.i1422 = icmp ult i64 %_14.0.i1421, %x_lo.i1411
  %166 = add i64 %_14.0.i1421, 4294967295
  %res.sroa.0.0.i1423 = select i1 %_14.1.i1422, i64 %166, i64 %_14.0.i1421
  %_16.i1424 = icmp ugt i64 %res.sroa.0.0.i1423, -4294967296
  %_17.i1425 = add nsw i64 %res.sroa.0.0.i1423, 4294967295
  %_0.sroa.0.0.i1426 = select i1 %_16.i1424, i64 %_17.i1425, i64 %res.sroa.0.0.i1423
  %_22.0.i235 = add i64 %_0.sroa.0.0.i1490, %_0.sroa.0.0.i1426
  %_22.1.i236 = icmp ult i64 %_22.0.i235, %_0.sroa.0.0.i1490
  %167 = add nuw i64 %_22.0.i235, 4294967295
  %_24.sroa.0.0.i237 = select i1 %_22.1.i236, i64 %167, i64 %_22.0.i235
  %_25.i238 = icmp ugt i64 %_24.sroa.0.0.i237, -4294967296
  %_26.i239 = add nsw i64 %_24.sroa.0.0.i237, 4294967295
  %_7.sroa.0.0.i240 = select i1 %_25.i238, i64 %_26.i239, i64 %_24.sroa.0.0.i237
  %_29.0.i241 = add i64 %_0.sroa.0.0.i1458, %_0.sroa.0.0.i1442
  %_29.1.i242 = icmp ult i64 %_29.0.i241, %_0.sroa.0.0.i1458
  %168 = add nuw i64 %_29.0.i241, 4294967295
  %_30.sroa.0.0.i243 = select i1 %_29.1.i242, i64 %168, i64 %_29.0.i241
  %_31.i244 = icmp ugt i64 %_30.sroa.0.0.i243, -4294967296
  %_32.i245 = add nsw i64 %_30.sroa.0.0.i243, 4294967295
  %_9.sroa.0.0.i246 = select i1 %_31.i244, i64 %_32.i245, i64 %_30.sroa.0.0.i243
  %_11.i198 = zext i64 %_7.sroa.0.0.i240 to i128
  %_10.i200 = mul nuw i128 %_11.i198, %_12.i518
  %x_lo.i1555 = trunc i128 %_10.i200 to i64
  %_4.i1556 = lshr i128 %_10.i200, 64
  %x_hi.i1557 = trunc nuw i128 %_4.i1556 to i64
  %x_hi_hi.i1558 = lshr i64 %x_hi.i1557, 32
  %x_hi_lo.i1559 = and i64 %x_hi.i1557, 4294967295
  %_9.0.i1560 = sub i64 %x_lo.i1555, %x_hi_hi.i1558
  %_9.1.i1561 = icmp ugt i64 %x_hi_hi.i1558, %x_lo.i1555
  %_10.i1562 = add i64 %_9.0.i1560, -4294967295
  %spec.select.i1563 = select i1 %_9.1.i1561, i64 %_10.i1562, i64 %_9.0.i1560
  %t1.i1564 = mul nuw i64 %x_hi_lo.i1559, 4294967295
  %_14.0.i1565 = add i64 %spec.select.i1563, %t1.i1564
  %_14.1.i1566 = icmp ult i64 %_14.0.i1565, %spec.select.i1563
  %169 = add i64 %_14.0.i1565, 4294967295
  %res.sroa.0.0.i1567 = select i1 %_14.1.i1566, i64 %169, i64 %_14.0.i1565
  %_16.i1568 = icmp ugt i64 %res.sroa.0.0.i1567, -4294967296
  %_17.i1569 = add nsw i64 %res.sroa.0.0.i1567, 4294967295
  %_0.sroa.0.0.i1570 = select i1 %_16.i1568, i64 %_17.i1569, i64 %res.sroa.0.0.i1567
  %_14.i201 = zext i64 %_9.sroa.0.0.i246 to i128
  %_13.i203 = mul nuw i128 %_14.i201, %_15.i522
  %x_lo.i1539 = trunc i128 %_13.i203 to i64
  %_4.i1540 = lshr i128 %_13.i203, 64
  %x_hi.i1541 = trunc nuw i128 %_4.i1540 to i64
  %x_hi_hi.i1542 = lshr i64 %x_hi.i1541, 32
  %x_hi_lo.i1543 = and i64 %x_hi.i1541, 4294967295
  %_9.0.i1544 = sub i64 %x_lo.i1539, %x_hi_hi.i1542
  %_9.1.i1545 = icmp ugt i64 %x_hi_hi.i1542, %x_lo.i1539
  %_10.i1546 = add i64 %_9.0.i1544, -4294967295
  %spec.select.i1547 = select i1 %_9.1.i1545, i64 %_10.i1546, i64 %_9.0.i1544
  %t1.i1548 = mul nuw i64 %x_hi_lo.i1543, 4294967295
  %_14.0.i1549 = add i64 %spec.select.i1547, %t1.i1548
  %_14.1.i1550 = icmp ult i64 %_14.0.i1549, %spec.select.i1547
  %170 = add i64 %_14.0.i1549, 4294967295
  %res.sroa.0.0.i1551 = select i1 %_14.1.i1550, i64 %170, i64 %_14.0.i1549
  %_16.i1552 = icmp ugt i64 %res.sroa.0.0.i1551, -4294967296
  %_17.i1553 = add nsw i64 %res.sroa.0.0.i1551, 4294967295
  %_0.sroa.0.0.i1554 = select i1 %_16.i1552, i64 %_17.i1553, i64 %res.sroa.0.0.i1551
  %_16.i204 = mul nuw i128 %_11.i198, %_15.i522
  %x_lo.i1523 = trunc i128 %_16.i204 to i64
  %_4.i1524 = lshr i128 %_16.i204, 64
  %x_hi.i1525 = trunc nuw i128 %_4.i1524 to i64
  %x_hi_hi.i1526 = lshr i64 %x_hi.i1525, 32
  %x_hi_lo.i1527 = and i64 %x_hi.i1525, 4294967295
  %_9.0.i1528 = sub i64 %x_lo.i1523, %x_hi_hi.i1526
  %_9.1.i1529 = icmp ugt i64 %x_hi_hi.i1526, %x_lo.i1523
  %_10.i1530 = add i64 %_9.0.i1528, -4294967295
  %spec.select.i1531 = select i1 %_9.1.i1529, i64 %_10.i1530, i64 %_9.0.i1528
  %t1.i1532 = mul nuw i64 %x_hi_lo.i1527, 4294967295
  %_14.0.i1533 = add i64 %spec.select.i1531, %t1.i1532
  %_14.1.i1534 = icmp ult i64 %_14.0.i1533, %spec.select.i1531
  %171 = add i64 %_14.0.i1533, 4294967295
  %res.sroa.0.0.i1535 = select i1 %_14.1.i1534, i64 %171, i64 %_14.0.i1533
  %_16.i1536 = icmp ugt i64 %res.sroa.0.0.i1535, -4294967296
  %_17.i1537 = add nsw i64 %res.sroa.0.0.i1535, 4294967295
  %_0.sroa.0.0.i1538 = select i1 %_16.i1536, i64 %_17.i1537, i64 %res.sroa.0.0.i1535
  %_17.i205 = mul nuw i128 %_14.i201, %_12.i518
  %x_lo.i1507 = trunc i128 %_17.i205 to i64
  %_4.i1508 = lshr i128 %_17.i205, 64
  %x_hi.i1509 = trunc nuw i128 %_4.i1508 to i64
  %x_hi_hi.i1510 = lshr i64 %x_hi.i1509, 32
  %x_hi_lo.i1511 = and i64 %x_hi.i1509, 4294967295
  %_9.0.i1512 = sub i64 %x_lo.i1507, %x_hi_hi.i1510
  %_9.1.i1513 = icmp ugt i64 %x_hi_hi.i1510, %x_lo.i1507
  %_10.i1514 = add i64 %_9.0.i1512, -4294967295
  %spec.select.i1515 = select i1 %_9.1.i1513, i64 %_10.i1514, i64 %_9.0.i1512
  %t1.i1516 = mul nuw i64 %x_hi_lo.i1511, 4294967295
  %_14.0.i1517 = add i64 %spec.select.i1515, %t1.i1516
  %_14.1.i1518 = icmp ult i64 %_14.0.i1517, %spec.select.i1515
  %172 = add i64 %_14.0.i1517, 4294967295
  %res.sroa.0.0.i1519 = select i1 %_14.1.i1518, i64 %172, i64 %_14.0.i1517
  %_16.i1520 = icmp ugt i64 %res.sroa.0.0.i1519, -4294967296
  %_17.i1521 = add nsw i64 %res.sroa.0.0.i1519, 4294967295
  %_0.sroa.0.0.i1522 = select i1 %_16.i1520, i64 %_17.i1521, i64 %res.sroa.0.0.i1519
  %_19.i206 = zext i64 %_0.sroa.0.0.i1554 to i128
  %_18.i207 = mul nuw nsw i128 %_19.i206, 7
  %x_lo.i1491 = trunc i128 %_18.i207 to i64
  %_4.i1492 = lshr i128 %_18.i207, 64
  %x_hi.i1493 = trunc nuw nsw i128 %_4.i1492 to i64
  %t1.i1500 = mul nuw nsw i64 %x_hi.i1493, 4294967295
  %_14.0.i1501 = add i64 %t1.i1500, %x_lo.i1491
  %_14.1.i1502 = icmp ult i64 %_14.0.i1501, %x_lo.i1491
  %173 = add i64 %_14.0.i1501, 4294967295
  %res.sroa.0.0.i1503 = select i1 %_14.1.i1502, i64 %173, i64 %_14.0.i1501
  %_16.i1504 = icmp ugt i64 %res.sroa.0.0.i1503, -4294967296
  %_17.i1505 = add nsw i64 %res.sroa.0.0.i1503, 4294967295
  %_0.sroa.0.0.i1506 = select i1 %_16.i1504, i64 %_17.i1505, i64 %res.sroa.0.0.i1503
  %_22.0.i208 = add i64 %_0.sroa.0.0.i1506, %_0.sroa.0.0.i1570
  %_22.1.i209 = icmp ult i64 %_22.0.i208, %_0.sroa.0.0.i1570
  %174 = add nuw i64 %_22.0.i208, 4294967295
  %_24.sroa.0.0.i210 = select i1 %_22.1.i209, i64 %174, i64 %_22.0.i208
  %_25.i211 = icmp ugt i64 %_24.sroa.0.0.i210, -4294967296
  %_26.i212 = add nsw i64 %_24.sroa.0.0.i210, 4294967295
  %_7.sroa.0.0.i213 = select i1 %_25.i211, i64 %_26.i212, i64 %_24.sroa.0.0.i210
  %_29.0.i214 = add i64 %_0.sroa.0.0.i1538, %_0.sroa.0.0.i1522
  %_29.1.i215 = icmp ult i64 %_29.0.i214, %_0.sroa.0.0.i1538
  %175 = add nuw i64 %_29.0.i214, 4294967295
  %_30.sroa.0.0.i216 = select i1 %_29.1.i215, i64 %175, i64 %_29.0.i214
  %_31.i217 = icmp ugt i64 %_30.sroa.0.0.i216, -4294967296
  %_32.i218 = add nsw i64 %_30.sroa.0.0.i216, 4294967295
  %_9.sroa.0.0.i219 = select i1 %_31.i217, i64 %_32.i218, i64 %_30.sroa.0.0.i216
  %_7.0.i26 = add i64 %_7.sroa.0.0.i213, %_3.sroa.0.0.i43
  %_7.1.i27 = icmp ult i64 %_7.0.i26, %_3.sroa.0.0.i43
  %176 = add i64 %_7.0.i26, 4294967295
  %_8.sroa.0.0.i28 = select i1 %_7.1.i27, i64 %176, i64 %_7.0.i26
  %_9.i29 = icmp ugt i64 %_8.sroa.0.0.i28, -4294967296
  %_10.i30 = add nsw i64 %_8.sroa.0.0.i28, 4294967295
  %_3.sroa.0.0.i31 = select i1 %_9.i29, i64 %_10.i30, i64 %_8.sroa.0.0.i28
  %_13.0.i32 = add i64 %_9.sroa.0.0.i219, %_4.sroa.0.0.i49
  %_13.1.i33 = icmp ult i64 %_13.0.i32, %_4.sroa.0.0.i49
  %177 = add i64 %_13.0.i32, 4294967295
  %_14.sroa.0.0.i34 = select i1 %_13.1.i33, i64 %177, i64 %_13.0.i32
  %_15.i35 = icmp ugt i64 %_14.sroa.0.0.i34, -4294967296
  %_16.i36 = add nsw i64 %_14.sroa.0.0.i34, 4294967295
  %_4.sroa.0.0.i37 = select i1 %_15.i35, i64 %_16.i36, i64 %_14.sroa.0.0.i34
  %178 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i31, 0
  %179 = insertvalue { i64, i64 } %178, i64 %_4.sroa.0.0.i37, 1
  call void @llvm.lifetime.end.p0(ptr nonnull %at)
  ret { i64, i64 } %179

panic17:                                          ; preds = %bb103
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 2, i64 noundef 2, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_0d7c3282f4d1b6d0ea38e377caef0ba7) #21
  unreachable

bb27:                                             ; preds = %bb9.i
  %_16.i.i = getelementptr inbounds nuw i8, ptr %ptr.i.i17381755, i64 16
  %_11.i.i.i = add nuw nsw i64 %_10.i.i.i17401754, 1
  %self3.i.i.i = getelementptr inbounds nuw %"core::mem::maybe_uninit::MaybeUninit<field::Fp2>", ptr %_56.sroa.5.0.iter.sroa_idx, i64 %_10.i.i.i17401754
  %_14.0.i.i.i = load i64, ptr %self3.i.i.i, align 8, !alias.scope !58, !noalias !65, !noundef !3
  %180 = getelementptr inbounds nuw i8, ptr %self3.i.i.i, i64 8
  %_14.1.i.i.i = load i64, ptr %180, align 8, !alias.scope !58, !noalias !65, !noundef !3
  %_68.0 = load i64, ptr %ptr.i.i17381755, align 8, !noundef !3
  %181 = getelementptr inbounds nuw i8, ptr %ptr.i.i17381755, i64 8
  %_68.1 = load i64, ptr %181, align 8, !noundef !3
  %_11.i166 = zext i64 %_68.0 to i128
  %_10.i168 = mul nuw i128 %_11.i166, %_12.i167
  %x_lo.i1635 = trunc i128 %_10.i168 to i64
  %_4.i1636 = lshr i128 %_10.i168, 64
  %x_hi.i1637 = trunc nuw i128 %_4.i1636 to i64
  %x_hi_hi.i1638 = lshr i64 %x_hi.i1637, 32
  %x_hi_lo.i1639 = and i64 %x_hi.i1637, 4294967295
  %_9.0.i1640 = sub i64 %x_lo.i1635, %x_hi_hi.i1638
  %_9.1.i1641 = icmp ugt i64 %x_hi_hi.i1638, %x_lo.i1635
  %_10.i1642 = add i64 %_9.0.i1640, -4294967295
  %spec.select.i1643 = select i1 %_9.1.i1641, i64 %_10.i1642, i64 %_9.0.i1640
  %t1.i1644 = mul nuw i64 %x_hi_lo.i1639, 4294967295
  %_14.0.i1645 = add i64 %spec.select.i1643, %t1.i1644
  %_14.1.i1646 = icmp ult i64 %_14.0.i1645, %spec.select.i1643
  %182 = add i64 %_14.0.i1645, 4294967295
  %res.sroa.0.0.i1647 = select i1 %_14.1.i1646, i64 %182, i64 %_14.0.i1645
  %_16.i1648 = icmp ugt i64 %res.sroa.0.0.i1647, -4294967296
  %_17.i1649 = add nsw i64 %res.sroa.0.0.i1647, 4294967295
  %_0.sroa.0.0.i1650 = select i1 %_16.i1648, i64 %_17.i1649, i64 %res.sroa.0.0.i1647
  %_14.i169 = zext i64 %_68.1 to i128
  %_13.i171 = mul nuw i128 %_14.i169, %_15.i170
  %x_lo.i1619 = trunc i128 %_13.i171 to i64
  %_4.i1620 = lshr i128 %_13.i171, 64
  %x_hi.i1621 = trunc nuw i128 %_4.i1620 to i64
  %x_hi_hi.i1622 = lshr i64 %x_hi.i1621, 32
  %x_hi_lo.i1623 = and i64 %x_hi.i1621, 4294967295
  %_9.0.i1624 = sub i64 %x_lo.i1619, %x_hi_hi.i1622
  %_9.1.i1625 = icmp ugt i64 %x_hi_hi.i1622, %x_lo.i1619
  %_10.i1626 = add i64 %_9.0.i1624, -4294967295
  %spec.select.i1627 = select i1 %_9.1.i1625, i64 %_10.i1626, i64 %_9.0.i1624
  %t1.i1628 = mul nuw i64 %x_hi_lo.i1623, 4294967295
  %_14.0.i1629 = add i64 %spec.select.i1627, %t1.i1628
  %_14.1.i1630 = icmp ult i64 %_14.0.i1629, %spec.select.i1627
  %183 = add i64 %_14.0.i1629, 4294967295
  %res.sroa.0.0.i1631 = select i1 %_14.1.i1630, i64 %183, i64 %_14.0.i1629
  %_16.i1632 = icmp ugt i64 %res.sroa.0.0.i1631, -4294967296
  %_17.i1633 = add nsw i64 %res.sroa.0.0.i1631, 4294967295
  %_0.sroa.0.0.i1634 = select i1 %_16.i1632, i64 %_17.i1633, i64 %res.sroa.0.0.i1631
  %_16.i172 = mul nuw i128 %_11.i166, %_15.i170
  %x_lo.i1603 = trunc i128 %_16.i172 to i64
  %_4.i1604 = lshr i128 %_16.i172, 64
  %x_hi.i1605 = trunc nuw i128 %_4.i1604 to i64
  %x_hi_hi.i1606 = lshr i64 %x_hi.i1605, 32
  %x_hi_lo.i1607 = and i64 %x_hi.i1605, 4294967295
  %_9.0.i1608 = sub i64 %x_lo.i1603, %x_hi_hi.i1606
  %_9.1.i1609 = icmp ugt i64 %x_hi_hi.i1606, %x_lo.i1603
  %_10.i1610 = add i64 %_9.0.i1608, -4294967295
  %spec.select.i1611 = select i1 %_9.1.i1609, i64 %_10.i1610, i64 %_9.0.i1608
  %t1.i1612 = mul nuw i64 %x_hi_lo.i1607, 4294967295
  %_14.0.i1613 = add i64 %spec.select.i1611, %t1.i1612
  %_14.1.i1614 = icmp ult i64 %_14.0.i1613, %spec.select.i1611
  %184 = add i64 %_14.0.i1613, 4294967295
  %res.sroa.0.0.i1615 = select i1 %_14.1.i1614, i64 %184, i64 %_14.0.i1613
  %_16.i1616 = icmp ugt i64 %res.sroa.0.0.i1615, -4294967296
  %_17.i1617 = add nsw i64 %res.sroa.0.0.i1615, 4294967295
  %_0.sroa.0.0.i1618 = select i1 %_16.i1616, i64 %_17.i1617, i64 %res.sroa.0.0.i1615
  %_17.i173 = mul nuw i128 %_14.i169, %_12.i167
  %x_lo.i1587 = trunc i128 %_17.i173 to i64
  %_4.i1588 = lshr i128 %_17.i173, 64
  %x_hi.i1589 = trunc nuw i128 %_4.i1588 to i64
  %x_hi_hi.i1590 = lshr i64 %x_hi.i1589, 32
  %x_hi_lo.i1591 = and i64 %x_hi.i1589, 4294967295
  %_9.0.i1592 = sub i64 %x_lo.i1587, %x_hi_hi.i1590
  %_9.1.i1593 = icmp ugt i64 %x_hi_hi.i1590, %x_lo.i1587
  %_10.i1594 = add i64 %_9.0.i1592, -4294967295
  %spec.select.i1595 = select i1 %_9.1.i1593, i64 %_10.i1594, i64 %_9.0.i1592
  %t1.i1596 = mul nuw i64 %x_hi_lo.i1591, 4294967295
  %_14.0.i1597 = add i64 %spec.select.i1595, %t1.i1596
  %_14.1.i1598 = icmp ult i64 %_14.0.i1597, %spec.select.i1595
  %185 = add i64 %_14.0.i1597, 4294967295
  %res.sroa.0.0.i1599 = select i1 %_14.1.i1598, i64 %185, i64 %_14.0.i1597
  %_16.i1600 = icmp ugt i64 %res.sroa.0.0.i1599, -4294967296
  %_17.i1601 = add nsw i64 %res.sroa.0.0.i1599, 4294967295
  %_0.sroa.0.0.i1602 = select i1 %_16.i1600, i64 %_17.i1601, i64 %res.sroa.0.0.i1599
  %_19.i174 = zext i64 %_0.sroa.0.0.i1634 to i128
  %_18.i175 = mul nuw nsw i128 %_19.i174, 7
  %x_lo.i1571 = trunc i128 %_18.i175 to i64
  %_4.i1572 = lshr i128 %_18.i175, 64
  %x_hi.i1573 = trunc nuw nsw i128 %_4.i1572 to i64
  %t1.i1580 = mul nuw nsw i64 %x_hi.i1573, 4294967295
  %_14.0.i1581 = add i64 %t1.i1580, %x_lo.i1571
  %_14.1.i1582 = icmp ult i64 %_14.0.i1581, %x_lo.i1571
  %186 = add i64 %_14.0.i1581, 4294967295
  %res.sroa.0.0.i1583 = select i1 %_14.1.i1582, i64 %186, i64 %_14.0.i1581
  %_16.i1584 = icmp ugt i64 %res.sroa.0.0.i1583, -4294967296
  %_17.i1585 = add nsw i64 %res.sroa.0.0.i1583, 4294967295
  %_0.sroa.0.0.i1586 = select i1 %_16.i1584, i64 %_17.i1585, i64 %res.sroa.0.0.i1583
  %_22.0.i176 = add i64 %_0.sroa.0.0.i1586, %_0.sroa.0.0.i1650
  %_22.1.i177 = icmp ult i64 %_22.0.i176, %_0.sroa.0.0.i1650
  %187 = add nuw i64 %_22.0.i176, 4294967295
  %_24.sroa.0.0.i178 = select i1 %_22.1.i177, i64 %187, i64 %_22.0.i176
  %_25.i179 = icmp ugt i64 %_24.sroa.0.0.i178, -4294967296
  %_26.i180 = add nsw i64 %_24.sroa.0.0.i178, 4294967295
  %_7.sroa.0.0.i181 = select i1 %_25.i179, i64 %_26.i180, i64 %_24.sroa.0.0.i178
  %_29.0.i182 = add i64 %_0.sroa.0.0.i1602, %_0.sroa.0.0.i1618
  %_29.1.i183 = icmp ult i64 %_29.0.i182, %_0.sroa.0.0.i1618
  %188 = add nuw i64 %_29.0.i182, 4294967295
  %_30.sroa.0.0.i184 = select i1 %_29.1.i183, i64 %188, i64 %_29.0.i182
  %_31.i185 = icmp ugt i64 %_30.sroa.0.0.i184, -4294967296
  %_32.i186 = add nsw i64 %_30.sroa.0.0.i184, 4294967295
  %_9.sroa.0.0.i187 = select i1 %_31.i185, i64 %_32.i186, i64 %_30.sroa.0.0.i184
  %_11.i = zext i64 %_7.sroa.0.0.i181 to i128
  %_12.i = zext i64 %_14.0.i.i.i to i128
  %_10.i158 = mul nuw i128 %_11.i, %_12.i
  %x_lo.i1715 = trunc i128 %_10.i158 to i64
  %_4.i1716 = lshr i128 %_10.i158, 64
  %x_hi.i1717 = trunc nuw i128 %_4.i1716 to i64
  %x_hi_hi.i1718 = lshr i64 %x_hi.i1717, 32
  %x_hi_lo.i1719 = and i64 %x_hi.i1717, 4294967295
  %_9.0.i1720 = sub i64 %x_lo.i1715, %x_hi_hi.i1718
  %_9.1.i1721 = icmp ugt i64 %x_hi_hi.i1718, %x_lo.i1715
  %_10.i1722 = add i64 %_9.0.i1720, -4294967295
  %spec.select.i1723 = select i1 %_9.1.i1721, i64 %_10.i1722, i64 %_9.0.i1720
  %t1.i1724 = mul nuw i64 %x_hi_lo.i1719, 4294967295
  %_14.0.i1725 = add i64 %spec.select.i1723, %t1.i1724
  %_14.1.i1726 = icmp ult i64 %_14.0.i1725, %spec.select.i1723
  %189 = add i64 %_14.0.i1725, 4294967295
  %res.sroa.0.0.i1727 = select i1 %_14.1.i1726, i64 %189, i64 %_14.0.i1725
  %_16.i1728 = icmp ugt i64 %res.sroa.0.0.i1727, -4294967296
  %_17.i1729 = add nsw i64 %res.sroa.0.0.i1727, 4294967295
  %_0.sroa.0.0.i1730 = select i1 %_16.i1728, i64 %_17.i1729, i64 %res.sroa.0.0.i1727
  %_14.i = zext i64 %_9.sroa.0.0.i187 to i128
  %_15.i159 = zext i64 %_14.1.i.i.i to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i159
  %x_lo.i1699 = trunc i128 %_13.i to i64
  %_4.i1700 = lshr i128 %_13.i, 64
  %x_hi.i1701 = trunc nuw i128 %_4.i1700 to i64
  %x_hi_hi.i1702 = lshr i64 %x_hi.i1701, 32
  %x_hi_lo.i1703 = and i64 %x_hi.i1701, 4294967295
  %_9.0.i1704 = sub i64 %x_lo.i1699, %x_hi_hi.i1702
  %_9.1.i1705 = icmp ugt i64 %x_hi_hi.i1702, %x_lo.i1699
  %_10.i1706 = add i64 %_9.0.i1704, -4294967295
  %spec.select.i1707 = select i1 %_9.1.i1705, i64 %_10.i1706, i64 %_9.0.i1704
  %t1.i1708 = mul nuw i64 %x_hi_lo.i1703, 4294967295
  %_14.0.i1709 = add i64 %spec.select.i1707, %t1.i1708
  %_14.1.i1710 = icmp ult i64 %_14.0.i1709, %spec.select.i1707
  %190 = add i64 %_14.0.i1709, 4294967295
  %res.sroa.0.0.i1711 = select i1 %_14.1.i1710, i64 %190, i64 %_14.0.i1709
  %_16.i1712 = icmp ugt i64 %res.sroa.0.0.i1711, -4294967296
  %_17.i1713 = add nsw i64 %res.sroa.0.0.i1711, 4294967295
  %_0.sroa.0.0.i1714 = select i1 %_16.i1712, i64 %_17.i1713, i64 %res.sroa.0.0.i1711
  %_16.i160 = mul nuw i128 %_11.i, %_15.i159
  %x_lo.i1683 = trunc i128 %_16.i160 to i64
  %_4.i1684 = lshr i128 %_16.i160, 64
  %x_hi.i1685 = trunc nuw i128 %_4.i1684 to i64
  %x_hi_hi.i1686 = lshr i64 %x_hi.i1685, 32
  %x_hi_lo.i1687 = and i64 %x_hi.i1685, 4294967295
  %_9.0.i1688 = sub i64 %x_lo.i1683, %x_hi_hi.i1686
  %_9.1.i1689 = icmp ugt i64 %x_hi_hi.i1686, %x_lo.i1683
  %_10.i1690 = add i64 %_9.0.i1688, -4294967295
  %spec.select.i1691 = select i1 %_9.1.i1689, i64 %_10.i1690, i64 %_9.0.i1688
  %t1.i1692 = mul nuw i64 %x_hi_lo.i1687, 4294967295
  %_14.0.i1693 = add i64 %spec.select.i1691, %t1.i1692
  %_14.1.i1694 = icmp ult i64 %_14.0.i1693, %spec.select.i1691
  %191 = add i64 %_14.0.i1693, 4294967295
  %res.sroa.0.0.i1695 = select i1 %_14.1.i1694, i64 %191, i64 %_14.0.i1693
  %_16.i1696 = icmp ugt i64 %res.sroa.0.0.i1695, -4294967296
  %_17.i1697 = add nsw i64 %res.sroa.0.0.i1695, 4294967295
  %_0.sroa.0.0.i1698 = select i1 %_16.i1696, i64 %_17.i1697, i64 %res.sroa.0.0.i1695
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i1667 = trunc i128 %_17.i to i64
  %_4.i1668 = lshr i128 %_17.i, 64
  %x_hi.i1669 = trunc nuw i128 %_4.i1668 to i64
  %x_hi_hi.i1670 = lshr i64 %x_hi.i1669, 32
  %x_hi_lo.i1671 = and i64 %x_hi.i1669, 4294967295
  %_9.0.i1672 = sub i64 %x_lo.i1667, %x_hi_hi.i1670
  %_9.1.i1673 = icmp ugt i64 %x_hi_hi.i1670, %x_lo.i1667
  %_10.i1674 = add i64 %_9.0.i1672, -4294967295
  %spec.select.i1675 = select i1 %_9.1.i1673, i64 %_10.i1674, i64 %_9.0.i1672
  %t1.i1676 = mul nuw i64 %x_hi_lo.i1671, 4294967295
  %_14.0.i1677 = add i64 %spec.select.i1675, %t1.i1676
  %_14.1.i1678 = icmp ult i64 %_14.0.i1677, %spec.select.i1675
  %192 = add i64 %_14.0.i1677, 4294967295
  %res.sroa.0.0.i1679 = select i1 %_14.1.i1678, i64 %192, i64 %_14.0.i1677
  %_16.i1680 = icmp ugt i64 %res.sroa.0.0.i1679, -4294967296
  %_17.i1681 = add nsw i64 %res.sroa.0.0.i1679, 4294967295
  %_0.sroa.0.0.i1682 = select i1 %_16.i1680, i64 %_17.i1681, i64 %res.sroa.0.0.i1679
  %_19.i = zext i64 %_0.sroa.0.0.i1714 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i1651 = trunc i128 %_18.i to i64
  %_4.i1652 = lshr i128 %_18.i, 64
  %x_hi.i1653 = trunc nuw nsw i128 %_4.i1652 to i64
  %t1.i1660 = mul nuw nsw i64 %x_hi.i1653, 4294967295
  %_14.0.i1661 = add i64 %t1.i1660, %x_lo.i1651
  %_14.1.i1662 = icmp ult i64 %_14.0.i1661, %x_lo.i1651
  %193 = add i64 %_14.0.i1661, 4294967295
  %res.sroa.0.0.i1663 = select i1 %_14.1.i1662, i64 %193, i64 %_14.0.i1661
  %_16.i1664 = icmp ugt i64 %res.sroa.0.0.i1663, -4294967296
  %_17.i1665 = add nsw i64 %res.sroa.0.0.i1663, 4294967295
  %_0.sroa.0.0.i1666 = select i1 %_16.i1664, i64 %_17.i1665, i64 %res.sroa.0.0.i1663
  %_22.0.i = add i64 %_0.sroa.0.0.i1730, %_0.sroa.0.0.i1666
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i1730
  %194 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %194, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i1698, %_0.sroa.0.0.i1682
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i1698
  %195 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %195, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %_3.sroa.0.0.i67.pn1756
  %_7.1.i = icmp ult i64 %_7.0.i, %_3.sroa.0.0.i67.pn1756
  %196 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %196, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %_4.sroa.0.0.i73.pn1757
  %_13.1.i = icmp ult i64 %_13.0.i, %_4.sroa.0.0.i73.pn1757
  %197 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %197, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %_6.i.i = icmp eq ptr %_16.i.i, %_212
  br i1 %_6.i.i, label %bb24, label %bb9.i
}

; isolated::factory_1::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(272) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
  %iter = alloca [96 x i8], align 8
  %at = alloca [24 x i8], align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %at)
  %_4 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  store ptr %v.0, ptr %at, align 8
  %0 = getelementptr inbounds nuw i8, ptr %at, i64 8
  store i64 %v.1, ptr %0, align 8
  %1 = getelementptr inbounds nuw i8, ptr %at, i64 16
  store ptr %_4, ptr %1, align 8
  %_7 = getelementptr inbounds nuw i8, ptr %_1, i64 152
  %2 = getelementptr inbounds nuw i8, ptr %_1, i64 24
  %_98 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_1, i64 32
  %_97 = load i64, ptr %3, align 8, !noundef !3
  %_99 = icmp ugt i64 %_97, 67
  br i1 %_99, label %bb44, label %panic

bb44:                                             ; preds = %start
  %_92 = getelementptr inbounds nuw i8, ptr %_98, i64 536
  %_91 = load i64, ptr %_92, align 8, !noundef !3
  %_94 = icmp ult i64 %_91, %v.1
  br i1 %_94, label %bb43, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 67, i64 noundef %_97, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_826b68913cf630c35a865efbea8045e3) #21
  unreachable

bb43:                                             ; preds = %bb44
  %4 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_91
  %g8.0 = load i64, ptr %4, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 8
  %g8.1 = load i64, ptr %5, align 8, !noundef !3
  %_103 = icmp ugt i64 %_97, 69
  br i1 %_103, label %bb46, label %panic2

panic1:                                           ; preds = %bb44
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_91, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable

bb46:                                             ; preds = %bb43
  %_101 = getelementptr inbounds nuw i8, ptr %_98, i64 552
  %_100 = load i64, ptr %_101, align 8, !noundef !3
  %_102 = icmp ult i64 %_100, %v.1
  br i1 %_102, label %bb45, label %panic3

panic2:                                           ; preds = %bb43
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 69, i64 noundef %_97, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_826b68913cf630c35a865efbea8045e3) #21
  unreachable

bb45:                                             ; preds = %bb46
  %6 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_100
  %a16.0 = load i64, ptr %6, align 8, !noundef !3
  %7 = getelementptr inbounds nuw i8, ptr %6, i64 8
  %a16.1 = load i64, ptr %7, align 8, !noundef !3
  %_107.not = icmp eq i64 %_97, 70
  br i1 %_107.not, label %panic4, label %bb48

panic3:                                           ; preds = %bb46
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_100, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable

bb48:                                             ; preds = %bb45
  %_105 = getelementptr inbounds nuw i8, ptr %_98, i64 560
  %_104 = load i64, ptr %_105, align 8, !noundef !3
  %_106 = icmp ult i64 %_104, %v.1
  br i1 %_106, label %bb47, label %panic5

panic4:                                           ; preds = %bb45
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 70, i64 noundef 70, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_826b68913cf630c35a865efbea8045e3) #21
  unreachable

bb47:                                             ; preds = %bb48
  %8 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_104
  %u16.0 = load i64, ptr %8, align 8, !noundef !3
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 8
  %u16.1 = load i64, ptr %9, align 8, !noundef !3
  %_111 = icmp ugt i64 %_97, 73
  br i1 %_111, label %bb50, label %panic6

panic5:                                           ; preds = %bb48
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_104, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable

bb50:                                             ; preds = %bb47
  %_109 = getelementptr inbounds nuw i8, ptr %_98, i64 584
  %_108 = load i64, ptr %_109, align 8, !noundef !3
  %_110 = icmp ult i64 %_108, %v.1
  br i1 %_110, label %bb49, label %panic7

panic6:                                           ; preds = %bb47
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 73, i64 noundef %_97, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_826b68913cf630c35a865efbea8045e3) #21
  unreachable

bb49:                                             ; preds = %bb50
  %10 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_108
  %h16.0 = load i64, ptr %10, align 8, !noundef !3
  %11 = getelementptr inbounds nuw i8, ptr %10, i64 8
  %h16.1 = load i64, ptr %11, align 8, !noundef !3
  %_11.i463 = zext i64 %a16.0 to i128
  %_12.i464 = zext i64 %u16.0 to i128
  %_10.i465 = mul nuw i128 %_12.i464, %_11.i463
  %x_lo.i541 = trunc i128 %_10.i465 to i64
  %_4.i542 = lshr i128 %_10.i465, 64
  %x_hi.i543 = trunc nuw i128 %_4.i542 to i64
  %x_hi_hi.i544 = lshr i64 %x_hi.i543, 32
  %x_hi_lo.i545 = and i64 %x_hi.i543, 4294967295
  %_9.0.i546 = sub i64 %x_lo.i541, %x_hi_hi.i544
  %_9.1.i547 = icmp ugt i64 %x_hi_hi.i544, %x_lo.i541
  %_10.i548 = add i64 %_9.0.i546, -4294967295
  %spec.select.i549 = select i1 %_9.1.i547, i64 %_10.i548, i64 %_9.0.i546
  %t1.i550 = mul nuw i64 %x_hi_lo.i545, 4294967295
  %_14.0.i551 = add i64 %spec.select.i549, %t1.i550
  %_14.1.i552 = icmp ult i64 %_14.0.i551, %spec.select.i549
  %12 = add i64 %_14.0.i551, 4294967295
  %res.sroa.0.0.i553 = select i1 %_14.1.i552, i64 %12, i64 %_14.0.i551
  %_16.i554 = icmp ugt i64 %res.sroa.0.0.i553, -4294967296
  %_17.i555 = add nsw i64 %res.sroa.0.0.i553, 4294967295
  %_0.sroa.0.0.i556 = select i1 %_16.i554, i64 %_17.i555, i64 %res.sroa.0.0.i553
  %_14.i467 = zext i64 %a16.1 to i128
  %_15.i468 = zext i64 %u16.1 to i128
  %_13.i469 = mul nuw i128 %_15.i468, %_14.i467
  %x_lo.i525 = trunc i128 %_13.i469 to i64
  %_4.i526 = lshr i128 %_13.i469, 64
  %x_hi.i527 = trunc nuw i128 %_4.i526 to i64
  %x_hi_hi.i528 = lshr i64 %x_hi.i527, 32
  %x_hi_lo.i529 = and i64 %x_hi.i527, 4294967295
  %_9.0.i530 = sub i64 %x_lo.i525, %x_hi_hi.i528
  %_9.1.i531 = icmp ugt i64 %x_hi_hi.i528, %x_lo.i525
  %_10.i532 = add i64 %_9.0.i530, -4294967295
  %spec.select.i533 = select i1 %_9.1.i531, i64 %_10.i532, i64 %_9.0.i530
  %t1.i534 = mul nuw i64 %x_hi_lo.i529, 4294967295
  %_14.0.i535 = add i64 %spec.select.i533, %t1.i534
  %_14.1.i536 = icmp ult i64 %_14.0.i535, %spec.select.i533
  %13 = add i64 %_14.0.i535, 4294967295
  %res.sroa.0.0.i537 = select i1 %_14.1.i536, i64 %13, i64 %_14.0.i535
  %_16.i538 = icmp ugt i64 %res.sroa.0.0.i537, -4294967296
  %_17.i539 = add nsw i64 %res.sroa.0.0.i537, 4294967295
  %_0.sroa.0.0.i540 = select i1 %_16.i538, i64 %_17.i539, i64 %res.sroa.0.0.i537
  %_16.i471 = mul nuw i128 %_15.i468, %_11.i463
  %x_lo.i509 = trunc i128 %_16.i471 to i64
  %_4.i510 = lshr i128 %_16.i471, 64
  %x_hi.i511 = trunc nuw i128 %_4.i510 to i64
  %x_hi_hi.i512 = lshr i64 %x_hi.i511, 32
  %x_hi_lo.i513 = and i64 %x_hi.i511, 4294967295
  %_9.0.i514 = sub i64 %x_lo.i509, %x_hi_hi.i512
  %_9.1.i515 = icmp ugt i64 %x_hi_hi.i512, %x_lo.i509
  %_10.i516 = add i64 %_9.0.i514, -4294967295
  %spec.select.i517 = select i1 %_9.1.i515, i64 %_10.i516, i64 %_9.0.i514
  %t1.i518 = mul nuw i64 %x_hi_lo.i513, 4294967295
  %_14.0.i519 = add i64 %spec.select.i517, %t1.i518
  %_14.1.i520 = icmp ult i64 %_14.0.i519, %spec.select.i517
  %14 = add i64 %_14.0.i519, 4294967295
  %res.sroa.0.0.i521 = select i1 %_14.1.i520, i64 %14, i64 %_14.0.i519
  %_16.i522 = icmp ugt i64 %res.sroa.0.0.i521, -4294967296
  %_17.i523 = add nsw i64 %res.sroa.0.0.i521, 4294967295
  %_0.sroa.0.0.i524 = select i1 %_16.i522, i64 %_17.i523, i64 %res.sroa.0.0.i521
  %_17.i473 = mul nuw i128 %_12.i464, %_14.i467
  %x_lo.i493 = trunc i128 %_17.i473 to i64
  %_4.i494 = lshr i128 %_17.i473, 64
  %x_hi.i495 = trunc nuw i128 %_4.i494 to i64
  %x_hi_hi.i496 = lshr i64 %x_hi.i495, 32
  %x_hi_lo.i497 = and i64 %x_hi.i495, 4294967295
  %_9.0.i498 = sub i64 %x_lo.i493, %x_hi_hi.i496
  %_9.1.i499 = icmp ugt i64 %x_hi_hi.i496, %x_lo.i493
  %_10.i500 = add i64 %_9.0.i498, -4294967295
  %spec.select.i501 = select i1 %_9.1.i499, i64 %_10.i500, i64 %_9.0.i498
  %t1.i502 = mul nuw i64 %x_hi_lo.i497, 4294967295
  %_14.0.i503 = add i64 %spec.select.i501, %t1.i502
  %_14.1.i504 = icmp ult i64 %_14.0.i503, %spec.select.i501
  %15 = add i64 %_14.0.i503, 4294967295
  %res.sroa.0.0.i505 = select i1 %_14.1.i504, i64 %15, i64 %_14.0.i503
  %_16.i506 = icmp ugt i64 %res.sroa.0.0.i505, -4294967296
  %_17.i507 = add nsw i64 %res.sroa.0.0.i505, 4294967295
  %_0.sroa.0.0.i508 = select i1 %_16.i506, i64 %_17.i507, i64 %res.sroa.0.0.i505
  %_19.i475 = zext i64 %_0.sroa.0.0.i540 to i128
  %_18.i476 = mul nuw nsw i128 %_19.i475, 7
  %x_lo.i = trunc i128 %_18.i476 to i64
  %_4.i = lshr i128 %_18.i476, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %16 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %16, i64 %_14.0.i
  %_16.i491 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i492 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i491, i64 %_17.i492, i64 %res.sroa.0.0.i
  %_22.0.i478 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i556
  %_22.1.i479 = icmp ult i64 %_22.0.i478, %_0.sroa.0.0.i556
  %17 = add nuw i64 %_22.0.i478, 4294967295
  %_24.sroa.0.0.i480 = select i1 %_22.1.i479, i64 %17, i64 %_22.0.i478
  %_25.i481 = icmp ugt i64 %_24.sroa.0.0.i480, -4294967296
  %_26.i482 = add nsw i64 %_24.sroa.0.0.i480, 4294967295
  %_7.sroa.0.0.i483 = select i1 %_25.i481, i64 %_26.i482, i64 %_24.sroa.0.0.i480
  %_29.0.i484 = add i64 %_0.sroa.0.0.i524, %_0.sroa.0.0.i508
  %_29.1.i485 = icmp ult i64 %_29.0.i484, %_0.sroa.0.0.i524
  %18 = add nuw i64 %_29.0.i484, 4294967295
  %_30.sroa.0.0.i486 = select i1 %_29.1.i485, i64 %18, i64 %_29.0.i484
  %_31.i487 = icmp ugt i64 %_30.sroa.0.0.i486, -4294967296
  %_32.i488 = add nsw i64 %_30.sroa.0.0.i486, 4294967295
  %_9.sroa.0.0.i489 = select i1 %_31.i487, i64 %_32.i488, i64 %_30.sroa.0.0.i486
  %19 = getelementptr inbounds nuw i8, ptr %_1, i64 160
  %_248 = load i64, ptr %19, align 8, !noundef !3
  %_115 = zext i64 %h16.0 to i128
  %_116 = zext i64 %_248 to i128
  %_114 = mul nuw i128 %_116, %_115
  %x_lo.i1565 = trunc i128 %_114 to i64
  %_4.i1566 = lshr i128 %_114, 64
  %x_hi.i1567 = trunc nuw i128 %_4.i1566 to i64
  %x_hi_hi.i1568 = lshr i64 %x_hi.i1567, 32
  %x_hi_lo.i1569 = and i64 %x_hi.i1567, 4294967295
  %_9.0.i1570 = sub i64 %x_lo.i1565, %x_hi_hi.i1568
  %_9.1.i1571 = icmp ugt i64 %x_hi_hi.i1568, %x_lo.i1565
  %_10.i1572 = add i64 %_9.0.i1570, -4294967295
  %spec.select.i1573 = select i1 %_9.1.i1571, i64 %_10.i1572, i64 %_9.0.i1570
  %t1.i1574 = mul nuw i64 %x_hi_lo.i1569, 4294967295
  %_14.0.i1575 = add i64 %spec.select.i1573, %t1.i1574
  %_14.1.i1576 = icmp ult i64 %_14.0.i1575, %spec.select.i1573
  %20 = add i64 %_14.0.i1575, 4294967295
  %res.sroa.0.0.i1577 = select i1 %_14.1.i1576, i64 %20, i64 %_14.0.i1575
  %_16.i1578 = icmp ugt i64 %res.sroa.0.0.i1577, -4294967296
  %_17.i1579 = add nsw i64 %res.sroa.0.0.i1577, 4294967295
  %_0.sroa.0.0.i1580 = select i1 %_16.i1578, i64 %_17.i1579, i64 %res.sroa.0.0.i1577
  %_118 = zext i64 %h16.1 to i128
  %_117 = mul nuw i128 %_116, %_118
  %x_lo.i1549 = trunc i128 %_117 to i64
  %_4.i1550 = lshr i128 %_117, 64
  %x_hi.i1551 = trunc nuw i128 %_4.i1550 to i64
  %x_hi_hi.i1552 = lshr i64 %x_hi.i1551, 32
  %x_hi_lo.i1553 = and i64 %x_hi.i1551, 4294967295
  %_9.0.i1554 = sub i64 %x_lo.i1549, %x_hi_hi.i1552
  %_9.1.i1555 = icmp ugt i64 %x_hi_hi.i1552, %x_lo.i1549
  %_10.i1556 = add i64 %_9.0.i1554, -4294967295
  %spec.select.i1557 = select i1 %_9.1.i1555, i64 %_10.i1556, i64 %_9.0.i1554
  %t1.i1558 = mul nuw i64 %x_hi_lo.i1553, 4294967295
  %_14.0.i1559 = add i64 %spec.select.i1557, %t1.i1558
  %_14.1.i1560 = icmp ult i64 %_14.0.i1559, %spec.select.i1557
  %21 = add i64 %_14.0.i1559, 4294967295
  %res.sroa.0.0.i1561 = select i1 %_14.1.i1560, i64 %21, i64 %_14.0.i1559
  %_16.i1562 = icmp ugt i64 %res.sroa.0.0.i1561, -4294967296
  %_17.i1563 = add nsw i64 %res.sroa.0.0.i1561, 4294967295
  %_0.sroa.0.0.i1564 = select i1 %_16.i1562, i64 %_17.i1563, i64 %res.sroa.0.0.i1561
  %_121.0 = sub i64 %_7.sroa.0.0.i483, %_0.sroa.0.0.i1580
  %_121.1 = icmp ult i64 %_7.sroa.0.0.i483, %_0.sroa.0.0.i1580
  %22 = add i64 %_121.0, -4294967295
  %_122.sroa.0.0 = select i1 %_121.1, i64 %22, i64 %_121.0
  %_125.0 = sub i64 %_9.sroa.0.0.i489, %_0.sroa.0.0.i1564
  %_125.1 = icmp ult i64 %_9.sroa.0.0.i489, %_0.sroa.0.0.i1564
  %23 = add i64 %_125.0, -4294967295
  %_126.sroa.0.0 = select i1 %_125.1, i64 %23, i64 %_125.0
; call isolated::factory_1::{closure#1}::{closure#1}
  %24 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 76)
  %_15.0 = extractvalue { i64, i64 } %24, 0
  %_15.1 = extractvalue { i64, i64 } %24, 1
  %_133.0 = sub i64 %_122.sroa.0.0, %_15.0
  %_133.1 = icmp ult i64 %_122.sroa.0.0, %_15.0
  %25 = add i64 %_133.0, -4294967295
  %_134.sroa.0.0 = select i1 %_133.1, i64 %25, i64 %_133.0
  %_137.0 = sub i64 %_126.sroa.0.0, %_15.1
  %_137.1 = icmp ult i64 %_126.sroa.0.0, %_15.1
  %26 = add i64 %_137.0, -4294967295
  %_138.sroa.0.0 = select i1 %_137.1, i64 %26, i64 %_137.0
  %27 = getelementptr inbounds nuw i8, ptr %_1, i64 168
  %_17.0 = load i64, ptr %27, align 8, !noundef !3
  %28 = getelementptr inbounds nuw i8, ptr %_1, i64 176
  %_17.1 = load i64, ptr %28, align 8, !noundef !3
  %_7.0.i146 = add i64 %_134.sroa.0.0, %_17.0
  %_7.1.i147 = icmp ult i64 %_7.0.i146, %_134.sroa.0.0
  %29 = add i64 %_7.0.i146, 4294967295
  %_8.sroa.0.0.i148 = select i1 %_7.1.i147, i64 %29, i64 %_7.0.i146
  %_9.i149 = icmp ugt i64 %_8.sroa.0.0.i148, -4294967296
  %_10.i150 = add nsw i64 %_8.sroa.0.0.i148, 4294967295
  %_3.sroa.0.0.i151 = select i1 %_9.i149, i64 %_10.i150, i64 %_8.sroa.0.0.i148
  %_13.0.i152 = add i64 %_138.sroa.0.0, %_17.1
  %_13.1.i153 = icmp ult i64 %_13.0.i152, %_138.sroa.0.0
  %30 = add i64 %_13.0.i152, 4294967295
  %_14.sroa.0.0.i154 = select i1 %_13.1.i153, i64 %30, i64 %_13.0.i152
  %_15.i155 = icmp ugt i64 %_14.sroa.0.0.i154, -4294967296
  %_16.i156 = add nsw i64 %_14.sroa.0.0.i154, 4294967295
  %_4.sroa.0.0.i157 = select i1 %_15.i155, i64 %_16.i156, i64 %_14.sroa.0.0.i154
  %_7.1.i135 = icmp ugt i64 %u16.0, -32769
  %_8.sroa.0.0.i136.v = select i1 %_7.1.i135, i64 4295000063, i64 32768
  %_8.sroa.0.0.i136 = add i64 %_8.sroa.0.0.i136.v, %u16.0
  %_9.i137 = icmp ugt i64 %_8.sroa.0.0.i136, -4294967296
  %_10.i138 = add nsw i64 %_8.sroa.0.0.i136, 4294967295
  %_3.sroa.0.0.i139 = select i1 %_9.i137, i64 %_10.i138, i64 %_8.sroa.0.0.i136
  %_15.i143 = icmp ugt i64 %u16.1, -4294967296
  %_16.i144 = add nsw i64 %u16.1, 4294967295
  %_4.sroa.0.0.i145 = select i1 %_15.i143, i64 %_16.i144, i64 %u16.1
; call isolated::factory_1::{closure#1}::{closure#1}
  %31 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 71)
  %_21.0 = extractvalue { i64, i64 } %31, 0
  %_21.1 = extractvalue { i64, i64 } %31, 1
  %_146.0 = sub i64 %_3.sroa.0.0.i139, %_21.0
  %_146.1 = icmp ult i64 %_3.sroa.0.0.i139, %_21.0
  %32 = add i64 %_146.0, -4294967295
  %_147.sroa.0.0 = select i1 %_146.1, i64 %32, i64 %_146.0
  %_150.0 = sub i64 %_4.sroa.0.0.i145, %_21.1
  %_150.1 = icmp ult i64 %_4.sroa.0.0.i145, %_21.1
  %33 = add i64 %_150.0, -4294967295
  %_151.sroa.0.0 = select i1 %_150.1, i64 %33, i64 %_150.0
  %_7.1.i123 = icmp ugt i64 %h16.0, -32769
  %_8.sroa.0.0.i124.v = select i1 %_7.1.i123, i64 4295000063, i64 32768
  %_8.sroa.0.0.i124 = add i64 %_8.sroa.0.0.i124.v, %h16.0
  %_9.i125 = icmp ugt i64 %_8.sroa.0.0.i124, -4294967296
  %_10.i126 = add nsw i64 %_8.sroa.0.0.i124, 4294967295
  %_3.sroa.0.0.i127 = select i1 %_9.i125, i64 %_10.i126, i64 %_8.sroa.0.0.i124
  %_15.i131 = icmp ugt i64 %h16.1, -4294967296
  %_16.i132 = add nsw i64 %h16.1, 4294967295
  %_4.sroa.0.0.i133 = select i1 %_15.i131, i64 %_16.i132, i64 %h16.1
; call isolated::factory_1::{closure#1}::{closure#1}
  %34 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 74)
  %_26.0 = extractvalue { i64, i64 } %34, 0
  %_26.1 = extractvalue { i64, i64 } %34, 1
  %_161.0 = sub i64 %_3.sroa.0.0.i127, %_26.0
  %_161.1 = icmp ult i64 %_3.sroa.0.0.i127, %_26.0
  %35 = add i64 %_161.0, -4294967295
  %_162.sroa.0.0 = select i1 %_161.1, i64 %35, i64 %_161.0
  %_165.0 = sub i64 %_4.sroa.0.0.i133, %_26.1
  %_165.1 = icmp ult i64 %_4.sroa.0.0.i133, %_26.1
  %36 = add i64 %_165.0, -4294967295
  %_166.sroa.0.0 = select i1 %_165.1, i64 %36, i64 %_165.0
  %37 = getelementptr inbounds nuw i8, ptr %_1, i64 184
  %_31 = load i64, ptr %37, align 8, !noundef !3
  %_32 = icmp ult i64 %_31, %v.1
  br i1 %_32, label %bb8, label %panic8

panic7:                                           ; preds = %bb50
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_108, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable

bb8:                                              ; preds = %bb49
  %38 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_31
  %_30.0 = load i64, ptr %38, align 8, !noundef !3
  %39 = getelementptr inbounds nuw i8, ptr %38, i64 8
  %_30.1 = load i64, ptr %39, align 8, !noundef !3
  %40 = getelementptr inbounds nuw i8, ptr %_1, i64 192
  %_255 = load i64, ptr %40, align 8, !noundef !3
  %41 = getelementptr inbounds nuw i8, ptr %_1, i64 200
  %_256 = load i64, ptr %41, align 8, !noundef !3
  %_7.1.i111 = icmp ugt i64 %g8.0, -129
  %_8.sroa.0.0.i112.v = select i1 %_7.1.i111, i64 4294967423, i64 128
  %_8.sroa.0.0.i112 = add i64 %_8.sroa.0.0.i112.v, %g8.0
  %_9.i113 = icmp ugt i64 %_8.sroa.0.0.i112, -4294967296
  %_10.i114 = add nsw i64 %_8.sroa.0.0.i112, 4294967295
  %_3.sroa.0.0.i115 = select i1 %_9.i113, i64 %_10.i114, i64 %_8.sroa.0.0.i112
  %_15.i119 = icmp ugt i64 %g8.1, -4294967296
  %_16.i120 = add nsw i64 %g8.1, 4294967295
  %_4.sroa.0.0.i121 = select i1 %_15.i119, i64 %_16.i120, i64 %g8.1
  %42 = getelementptr inbounds nuw i8, ptr %_1, i64 208
  %_39.0 = load i64, ptr %42, align 8, !noundef !3
  %43 = getelementptr inbounds nuw i8, ptr %_1, i64 216
  %_39.1 = load i64, ptr %43, align 8, !noundef !3
  %_11.i436 = zext i64 %_39.0 to i128
  %_10.i438 = mul nuw i128 %_11.i436, %_11.i463
  %x_lo.i621 = trunc i128 %_10.i438 to i64
  %_4.i622 = lshr i128 %_10.i438, 64
  %x_hi.i623 = trunc nuw i128 %_4.i622 to i64
  %x_hi_hi.i624 = lshr i64 %x_hi.i623, 32
  %x_hi_lo.i625 = and i64 %x_hi.i623, 4294967295
  %_9.0.i626 = sub i64 %x_lo.i621, %x_hi_hi.i624
  %_9.1.i627 = icmp ugt i64 %x_hi_hi.i624, %x_lo.i621
  %_10.i628 = add i64 %_9.0.i626, -4294967295
  %spec.select.i629 = select i1 %_9.1.i627, i64 %_10.i628, i64 %_9.0.i626
  %t1.i630 = mul nuw i64 %x_hi_lo.i625, 4294967295
  %_14.0.i631 = add i64 %spec.select.i629, %t1.i630
  %_14.1.i632 = icmp ult i64 %_14.0.i631, %spec.select.i629
  %44 = add i64 %_14.0.i631, 4294967295
  %res.sroa.0.0.i633 = select i1 %_14.1.i632, i64 %44, i64 %_14.0.i631
  %_16.i634 = icmp ugt i64 %res.sroa.0.0.i633, -4294967296
  %_17.i635 = add nsw i64 %res.sroa.0.0.i633, 4294967295
  %_0.sroa.0.0.i636 = select i1 %_16.i634, i64 %_17.i635, i64 %res.sroa.0.0.i633
  %_14.i440 = zext i64 %_39.1 to i128
  %_13.i442 = mul nuw i128 %_14.i440, %_14.i467
  %x_lo.i605 = trunc i128 %_13.i442 to i64
  %_4.i606 = lshr i128 %_13.i442, 64
  %x_hi.i607 = trunc nuw i128 %_4.i606 to i64
  %x_hi_hi.i608 = lshr i64 %x_hi.i607, 32
  %x_hi_lo.i609 = and i64 %x_hi.i607, 4294967295
  %_9.0.i610 = sub i64 %x_lo.i605, %x_hi_hi.i608
  %_9.1.i611 = icmp ugt i64 %x_hi_hi.i608, %x_lo.i605
  %_10.i612 = add i64 %_9.0.i610, -4294967295
  %spec.select.i613 = select i1 %_9.1.i611, i64 %_10.i612, i64 %_9.0.i610
  %t1.i614 = mul nuw i64 %x_hi_lo.i609, 4294967295
  %_14.0.i615 = add i64 %spec.select.i613, %t1.i614
  %_14.1.i616 = icmp ult i64 %_14.0.i615, %spec.select.i613
  %45 = add i64 %_14.0.i615, 4294967295
  %res.sroa.0.0.i617 = select i1 %_14.1.i616, i64 %45, i64 %_14.0.i615
  %_16.i618 = icmp ugt i64 %res.sroa.0.0.i617, -4294967296
  %_17.i619 = add nsw i64 %res.sroa.0.0.i617, 4294967295
  %_0.sroa.0.0.i620 = select i1 %_16.i618, i64 %_17.i619, i64 %res.sroa.0.0.i617
  %_16.i444 = mul nuw i128 %_11.i436, %_14.i467
  %x_lo.i589 = trunc i128 %_16.i444 to i64
  %_4.i590 = lshr i128 %_16.i444, 64
  %x_hi.i591 = trunc nuw i128 %_4.i590 to i64
  %x_hi_hi.i592 = lshr i64 %x_hi.i591, 32
  %x_hi_lo.i593 = and i64 %x_hi.i591, 4294967295
  %_9.0.i594 = sub i64 %x_lo.i589, %x_hi_hi.i592
  %_9.1.i595 = icmp ugt i64 %x_hi_hi.i592, %x_lo.i589
  %_10.i596 = add i64 %_9.0.i594, -4294967295
  %spec.select.i597 = select i1 %_9.1.i595, i64 %_10.i596, i64 %_9.0.i594
  %t1.i598 = mul nuw i64 %x_hi_lo.i593, 4294967295
  %_14.0.i599 = add i64 %spec.select.i597, %t1.i598
  %_14.1.i600 = icmp ult i64 %_14.0.i599, %spec.select.i597
  %46 = add i64 %_14.0.i599, 4294967295
  %res.sroa.0.0.i601 = select i1 %_14.1.i600, i64 %46, i64 %_14.0.i599
  %_16.i602 = icmp ugt i64 %res.sroa.0.0.i601, -4294967296
  %_17.i603 = add nsw i64 %res.sroa.0.0.i601, 4294967295
  %_0.sroa.0.0.i604 = select i1 %_16.i602, i64 %_17.i603, i64 %res.sroa.0.0.i601
  %_17.i446 = mul nuw i128 %_14.i440, %_11.i463
  %x_lo.i573 = trunc i128 %_17.i446 to i64
  %_4.i574 = lshr i128 %_17.i446, 64
  %x_hi.i575 = trunc nuw i128 %_4.i574 to i64
  %x_hi_hi.i576 = lshr i64 %x_hi.i575, 32
  %x_hi_lo.i577 = and i64 %x_hi.i575, 4294967295
  %_9.0.i578 = sub i64 %x_lo.i573, %x_hi_hi.i576
  %_9.1.i579 = icmp ugt i64 %x_hi_hi.i576, %x_lo.i573
  %_10.i580 = add i64 %_9.0.i578, -4294967295
  %spec.select.i581 = select i1 %_9.1.i579, i64 %_10.i580, i64 %_9.0.i578
  %t1.i582 = mul nuw i64 %x_hi_lo.i577, 4294967295
  %_14.0.i583 = add i64 %spec.select.i581, %t1.i582
  %_14.1.i584 = icmp ult i64 %_14.0.i583, %spec.select.i581
  %47 = add i64 %_14.0.i583, 4294967295
  %res.sroa.0.0.i585 = select i1 %_14.1.i584, i64 %47, i64 %_14.0.i583
  %_16.i586 = icmp ugt i64 %res.sroa.0.0.i585, -4294967296
  %_17.i587 = add nsw i64 %res.sroa.0.0.i585, 4294967295
  %_0.sroa.0.0.i588 = select i1 %_16.i586, i64 %_17.i587, i64 %res.sroa.0.0.i585
  %_19.i448 = zext i64 %_0.sroa.0.0.i620 to i128
  %_18.i449 = mul nuw nsw i128 %_19.i448, 7
  %x_lo.i557 = trunc i128 %_18.i449 to i64
  %_4.i558 = lshr i128 %_18.i449, 64
  %x_hi.i559 = trunc nuw nsw i128 %_4.i558 to i64
  %t1.i566 = mul nuw nsw i64 %x_hi.i559, 4294967295
  %_14.0.i567 = add i64 %t1.i566, %x_lo.i557
  %_14.1.i568 = icmp ult i64 %_14.0.i567, %x_lo.i557
  %48 = add i64 %_14.0.i567, 4294967295
  %res.sroa.0.0.i569 = select i1 %_14.1.i568, i64 %48, i64 %_14.0.i567
  %_16.i570 = icmp ugt i64 %res.sroa.0.0.i569, -4294967296
  %_17.i571 = add nsw i64 %res.sroa.0.0.i569, 4294967295
  %_0.sroa.0.0.i572 = select i1 %_16.i570, i64 %_17.i571, i64 %res.sroa.0.0.i569
  %_22.0.i451 = add i64 %_0.sroa.0.0.i572, %_0.sroa.0.0.i636
  %_22.1.i452 = icmp ult i64 %_22.0.i451, %_0.sroa.0.0.i636
  %49 = add nuw i64 %_22.0.i451, 4294967295
  %_24.sroa.0.0.i453 = select i1 %_22.1.i452, i64 %49, i64 %_22.0.i451
  %_25.i454 = icmp ugt i64 %_24.sroa.0.0.i453, -4294967296
  %_26.i455 = add nsw i64 %_24.sroa.0.0.i453, 4294967295
  %_7.sroa.0.0.i456 = select i1 %_25.i454, i64 %_26.i455, i64 %_24.sroa.0.0.i453
  %_29.0.i457 = add i64 %_0.sroa.0.0.i588, %_0.sroa.0.0.i604
  %_29.1.i458 = icmp ult i64 %_29.0.i457, %_0.sroa.0.0.i604
  %50 = add nuw i64 %_29.0.i457, 4294967295
  %_30.sroa.0.0.i459 = select i1 %_29.1.i458, i64 %50, i64 %_29.0.i457
  %_31.i460 = icmp ugt i64 %_30.sroa.0.0.i459, -4294967296
  %_32.i461 = add nsw i64 %_30.sroa.0.0.i459, 4294967295
  %_9.sroa.0.0.i462 = select i1 %_31.i460, i64 %_32.i461, i64 %_30.sroa.0.0.i459
  %_7.0.i98 = add i64 %_7.sroa.0.0.i456, %_3.sroa.0.0.i115
  %_7.1.i99 = icmp ult i64 %_7.0.i98, %_3.sroa.0.0.i115
  %51 = add i64 %_7.0.i98, 4294967295
  %_8.sroa.0.0.i100 = select i1 %_7.1.i99, i64 %51, i64 %_7.0.i98
  %_9.i101 = icmp ugt i64 %_8.sroa.0.0.i100, -4294967296
  %_10.i102 = add nsw i64 %_8.sroa.0.0.i100, 4294967295
  %_3.sroa.0.0.i103 = select i1 %_9.i101, i64 %_10.i102, i64 %_8.sroa.0.0.i100
  %_13.0.i104 = add i64 %_9.sroa.0.0.i462, %_4.sroa.0.0.i121
  %_13.1.i105 = icmp ult i64 %_13.0.i104, %_4.sroa.0.0.i121
  %52 = add i64 %_13.0.i104, 4294967295
  %_14.sroa.0.0.i106 = select i1 %_13.1.i105, i64 %52, i64 %_13.0.i104
  %_15.i107 = icmp ugt i64 %_14.sroa.0.0.i106, -4294967296
  %_16.i108 = add nsw i64 %_14.sroa.0.0.i106, 4294967295
  %_4.sroa.0.0.i109 = select i1 %_15.i107, i64 %_16.i108, i64 %_14.sroa.0.0.i106
  %53 = getelementptr inbounds nuw i8, ptr %_1, i64 224
  %_40.0 = load i64, ptr %53, align 8, !noundef !3
  %54 = getelementptr inbounds nuw i8, ptr %_1, i64 232
  %_40.1 = load i64, ptr %54, align 8, !noundef !3
  %_7.0.i86 = add i64 %_3.sroa.0.0.i103, %_40.0
  %_7.1.i87 = icmp ult i64 %_7.0.i86, %_3.sroa.0.0.i103
  %55 = add i64 %_7.0.i86, 4294967295
  %_8.sroa.0.0.i88 = select i1 %_7.1.i87, i64 %55, i64 %_7.0.i86
  %_9.i89 = icmp ugt i64 %_8.sroa.0.0.i88, -4294967296
  %_10.i90 = add nsw i64 %_8.sroa.0.0.i88, 4294967295
  %_3.sroa.0.0.i91 = select i1 %_9.i89, i64 %_10.i90, i64 %_8.sroa.0.0.i88
  %_13.0.i92 = add i64 %_4.sroa.0.0.i109, %_40.1
  %_13.1.i93 = icmp ult i64 %_13.0.i92, %_4.sroa.0.0.i109
  %56 = add i64 %_13.0.i92, 4294967295
  %_14.sroa.0.0.i94 = select i1 %_13.1.i93, i64 %56, i64 %_13.0.i92
  %_15.i95 = icmp ugt i64 %_14.sroa.0.0.i94, -4294967296
  %_16.i96 = add nsw i64 %_14.sroa.0.0.i94, 4294967295
  %_4.sroa.0.0.i97 = select i1 %_15.i95, i64 %_16.i96, i64 %_14.sroa.0.0.i94
  %_176.0 = sub i64 %_255, %_3.sroa.0.0.i91
  %_176.1 = icmp ult i64 %_255, %_3.sroa.0.0.i91
  %57 = add i64 %_176.0, -4294967295
  %_177.sroa.0.0 = select i1 %_176.1, i64 %57, i64 %_176.0
  %_180.0 = sub i64 %_256, %_4.sroa.0.0.i97
  %_180.1 = icmp ult i64 %_256, %_4.sroa.0.0.i97
  %58 = add i64 %_180.0, -4294967295
  %_181.sroa.0.0 = select i1 %_180.1, i64 %58, i64 %_180.0
  %_11.i409 = zext i64 %_30.0 to i128
  %_12.i410 = zext i64 %_177.sroa.0.0 to i128
  %_10.i411 = mul nuw i128 %_12.i410, %_11.i409
  %x_lo.i701 = trunc i128 %_10.i411 to i64
  %_4.i702 = lshr i128 %_10.i411, 64
  %x_hi.i703 = trunc nuw i128 %_4.i702 to i64
  %x_hi_hi.i704 = lshr i64 %x_hi.i703, 32
  %x_hi_lo.i705 = and i64 %x_hi.i703, 4294967295
  %_9.0.i706 = sub i64 %x_lo.i701, %x_hi_hi.i704
  %_9.1.i707 = icmp ugt i64 %x_hi_hi.i704, %x_lo.i701
  %_10.i708 = add i64 %_9.0.i706, -4294967295
  %spec.select.i709 = select i1 %_9.1.i707, i64 %_10.i708, i64 %_9.0.i706
  %t1.i710 = mul nuw i64 %x_hi_lo.i705, 4294967295
  %_14.0.i711 = add i64 %spec.select.i709, %t1.i710
  %_14.1.i712 = icmp ult i64 %_14.0.i711, %spec.select.i709
  %59 = add i64 %_14.0.i711, 4294967295
  %res.sroa.0.0.i713 = select i1 %_14.1.i712, i64 %59, i64 %_14.0.i711
  %_16.i714 = icmp ugt i64 %res.sroa.0.0.i713, -4294967296
  %_17.i715 = add nsw i64 %res.sroa.0.0.i713, 4294967295
  %_0.sroa.0.0.i716 = select i1 %_16.i714, i64 %_17.i715, i64 %res.sroa.0.0.i713
  %_14.i413 = zext i64 %_30.1 to i128
  %_15.i414 = zext i64 %_181.sroa.0.0 to i128
  %_13.i415 = mul nuw i128 %_15.i414, %_14.i413
  %x_lo.i685 = trunc i128 %_13.i415 to i64
  %_4.i686 = lshr i128 %_13.i415, 64
  %x_hi.i687 = trunc nuw i128 %_4.i686 to i64
  %x_hi_hi.i688 = lshr i64 %x_hi.i687, 32
  %x_hi_lo.i689 = and i64 %x_hi.i687, 4294967295
  %_9.0.i690 = sub i64 %x_lo.i685, %x_hi_hi.i688
  %_9.1.i691 = icmp ugt i64 %x_hi_hi.i688, %x_lo.i685
  %_10.i692 = add i64 %_9.0.i690, -4294967295
  %spec.select.i693 = select i1 %_9.1.i691, i64 %_10.i692, i64 %_9.0.i690
  %t1.i694 = mul nuw i64 %x_hi_lo.i689, 4294967295
  %_14.0.i695 = add i64 %spec.select.i693, %t1.i694
  %_14.1.i696 = icmp ult i64 %_14.0.i695, %spec.select.i693
  %60 = add i64 %_14.0.i695, 4294967295
  %res.sroa.0.0.i697 = select i1 %_14.1.i696, i64 %60, i64 %_14.0.i695
  %_16.i698 = icmp ugt i64 %res.sroa.0.0.i697, -4294967296
  %_17.i699 = add nsw i64 %res.sroa.0.0.i697, 4294967295
  %_0.sroa.0.0.i700 = select i1 %_16.i698, i64 %_17.i699, i64 %res.sroa.0.0.i697
  %_16.i417 = mul nuw i128 %_15.i414, %_11.i409
  %x_lo.i669 = trunc i128 %_16.i417 to i64
  %_4.i670 = lshr i128 %_16.i417, 64
  %x_hi.i671 = trunc nuw i128 %_4.i670 to i64
  %x_hi_hi.i672 = lshr i64 %x_hi.i671, 32
  %x_hi_lo.i673 = and i64 %x_hi.i671, 4294967295
  %_9.0.i674 = sub i64 %x_lo.i669, %x_hi_hi.i672
  %_9.1.i675 = icmp ugt i64 %x_hi_hi.i672, %x_lo.i669
  %_10.i676 = add i64 %_9.0.i674, -4294967295
  %spec.select.i677 = select i1 %_9.1.i675, i64 %_10.i676, i64 %_9.0.i674
  %t1.i678 = mul nuw i64 %x_hi_lo.i673, 4294967295
  %_14.0.i679 = add i64 %spec.select.i677, %t1.i678
  %_14.1.i680 = icmp ult i64 %_14.0.i679, %spec.select.i677
  %61 = add i64 %_14.0.i679, 4294967295
  %res.sroa.0.0.i681 = select i1 %_14.1.i680, i64 %61, i64 %_14.0.i679
  %_16.i682 = icmp ugt i64 %res.sroa.0.0.i681, -4294967296
  %_17.i683 = add nsw i64 %res.sroa.0.0.i681, 4294967295
  %_0.sroa.0.0.i684 = select i1 %_16.i682, i64 %_17.i683, i64 %res.sroa.0.0.i681
  %_17.i419 = mul nuw i128 %_12.i410, %_14.i413
  %x_lo.i653 = trunc i128 %_17.i419 to i64
  %_4.i654 = lshr i128 %_17.i419, 64
  %x_hi.i655 = trunc nuw i128 %_4.i654 to i64
  %x_hi_hi.i656 = lshr i64 %x_hi.i655, 32
  %x_hi_lo.i657 = and i64 %x_hi.i655, 4294967295
  %_9.0.i658 = sub i64 %x_lo.i653, %x_hi_hi.i656
  %_9.1.i659 = icmp ugt i64 %x_hi_hi.i656, %x_lo.i653
  %_10.i660 = add i64 %_9.0.i658, -4294967295
  %spec.select.i661 = select i1 %_9.1.i659, i64 %_10.i660, i64 %_9.0.i658
  %t1.i662 = mul nuw i64 %x_hi_lo.i657, 4294967295
  %_14.0.i663 = add i64 %spec.select.i661, %t1.i662
  %_14.1.i664 = icmp ult i64 %_14.0.i663, %spec.select.i661
  %62 = add i64 %_14.0.i663, 4294967295
  %res.sroa.0.0.i665 = select i1 %_14.1.i664, i64 %62, i64 %_14.0.i663
  %_16.i666 = icmp ugt i64 %res.sroa.0.0.i665, -4294967296
  %_17.i667 = add nsw i64 %res.sroa.0.0.i665, 4294967295
  %_0.sroa.0.0.i668 = select i1 %_16.i666, i64 %_17.i667, i64 %res.sroa.0.0.i665
  %_19.i421 = zext i64 %_0.sroa.0.0.i700 to i128
  %_18.i422 = mul nuw nsw i128 %_19.i421, 7
  %x_lo.i637 = trunc i128 %_18.i422 to i64
  %_4.i638 = lshr i128 %_18.i422, 64
  %x_hi.i639 = trunc nuw nsw i128 %_4.i638 to i64
  %t1.i646 = mul nuw nsw i64 %x_hi.i639, 4294967295
  %_14.0.i647 = add i64 %t1.i646, %x_lo.i637
  %_14.1.i648 = icmp ult i64 %_14.0.i647, %x_lo.i637
  %63 = add i64 %_14.0.i647, 4294967295
  %res.sroa.0.0.i649 = select i1 %_14.1.i648, i64 %63, i64 %_14.0.i647
  %_16.i650 = icmp ugt i64 %res.sroa.0.0.i649, -4294967296
  %_17.i651 = add nsw i64 %res.sroa.0.0.i649, 4294967295
  %_0.sroa.0.0.i652 = select i1 %_16.i650, i64 %_17.i651, i64 %res.sroa.0.0.i649
  %_22.0.i424 = add i64 %_0.sroa.0.0.i716, %_0.sroa.0.0.i652
  %_22.1.i425 = icmp ult i64 %_22.0.i424, %_0.sroa.0.0.i716
  %64 = add nuw i64 %_22.0.i424, 4294967295
  %_24.sroa.0.0.i426 = select i1 %_22.1.i425, i64 %64, i64 %_22.0.i424
  %_25.i427 = icmp ugt i64 %_24.sroa.0.0.i426, -4294967296
  %_26.i428 = add nsw i64 %_24.sroa.0.0.i426, 4294967295
  %_7.sroa.0.0.i429 = select i1 %_25.i427, i64 %_26.i428, i64 %_24.sroa.0.0.i426
  %_29.0.i430 = add i64 %_0.sroa.0.0.i668, %_0.sroa.0.0.i684
  %_29.1.i431 = icmp ult i64 %_29.0.i430, %_0.sroa.0.0.i684
  %65 = add nuw i64 %_29.0.i430, 4294967295
  %_30.sroa.0.0.i432 = select i1 %_29.1.i431, i64 %65, i64 %_29.0.i430
  %_31.i433 = icmp ugt i64 %_30.sroa.0.0.i432, -4294967296
  %_32.i434 = add nsw i64 %_30.sroa.0.0.i432, 4294967295
  %_9.sroa.0.0.i435 = select i1 %_31.i433, i64 %_32.i434, i64 %_30.sroa.0.0.i432
  %_188.1 = icmp eq i64 %_7.sroa.0.0.i429, 0
  %_188.0 = add i64 %_7.sroa.0.0.i429, -1
  %_189.sroa.0.0 = select i1 %_188.1, i64 -4294967296, i64 %_188.0
  %66 = load i64, ptr %_1, align 8, !range !56, !noundef !3
  %67 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %68 = load i64, ptr %67, align 8
  %69 = trunc nuw i64 %66 to i1
  br i1 %69, label %bb88, label %bb86

panic8:                                           ; preds = %bb49
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_31, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8c5249903caae8a4f890768ea185f763) #21
  unreachable

bb88:                                             ; preds = %bb8
  %_194 = icmp ult i64 %68, %v.1
  br i1 %_194, label %bb89, label %panic9

bb86:                                             ; preds = %bb8, %bb89
  %g.sroa.5.0 = phi i64 [ %74, %bb89 ], [ 0, %bb8 ]
  %g.sroa.0.0 = phi i64 [ %72, %bb89 ], [ 1, %bb8 ]
  %70 = getelementptr inbounds nuw i8, ptr %_1, i64 80
  %_201 = load i64, ptr %70, align 8, !noundef !3
  %_203 = icmp ult i64 %_201, 4
  br i1 %_203, label %bb90, label %bb9.i.lr.ph, !prof !57

bb89:                                             ; preds = %bb88
  %71 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %68
  %72 = load i64, ptr %71, align 8, !noundef !3
  %73 = getelementptr inbounds nuw i8, ptr %71, i64 8
  %74 = load i64, ptr %73, align 8, !noundef !3
  br label %bb86

panic9:                                           ; preds = %bb88
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %68, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_03bbe1d0fcdbd86f2216092eb0f02e36) #21
  unreachable

bb9.i.lr.ph:                                      ; preds = %bb86
  %75 = getelementptr inbounds nuw i8, ptr %_1, i64 72
  %_202 = load ptr, ptr %75, align 8, !nonnull !3, !noundef !3
  %76 = getelementptr inbounds nuw i8, ptr %_1, i64 240
  %_46 = load i64, ptr %76, align 8, !noundef !3
  %77 = getelementptr inbounds nuw i8, ptr %_1, i64 56
  %_197 = load i64, ptr %77, align 8, !noundef !3
  %78 = getelementptr inbounds nuw i8, ptr %_1, i64 48
  %_198 = load ptr, ptr %78, align 8, !nonnull !3, !noundef !3
  %_205 = add i64 %_201, -4
  %_209 = getelementptr inbounds nuw i8, ptr %_202, i64 64
; call isolated::helper_sum
  %79 = call fastcc { i64, i64 } @_RNvCsl0YfJI2rrfI_8isolated10helper_sum(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_198, i64 noundef %_197, i64 noundef %_46, i64 noundef %_255, i64 noundef %_256, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_209, i64 noundef %_205)
  %_51 = getelementptr inbounds nuw i8, ptr %_202, i64 48
  %_50.0 = load i64, ptr %_51, align 8, !noundef !3
  %80 = getelementptr inbounds nuw i8, ptr %_202, i64 56
  %_50.1 = load i64, ptr %80, align 8, !noundef !3
  %_53 = getelementptr inbounds nuw i8, ptr %_1, i64 88
; call <isolated::PadTerm>::eval
  %81 = call fastcc { i64, i64 } @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(40) %_53, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1)
  %_214.idx = shl nuw nsw i64 %_201, 4
  %_214 = getelementptr inbounds nuw i8, ptr %_202, i64 %_214.idx
  %_54.sroa.6.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 80
  call void @llvm.lifetime.start.p0(ptr nonnull %iter)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %_54.sroa.6.0.iter.sroa_idx, i8 0, i64 16, i1 false)
  %_54.sroa.5.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 32
  store i64 %_3.sroa.0.0.i151, ptr %_54.sroa.5.0.iter.sroa_idx, align 8
  %_54.sroa.5.sroa.2.0._54.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 40
  store i64 %_4.sroa.0.0.i157, ptr %_54.sroa.5.sroa.2.0._54.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_54.sroa.5.sroa.3.0._54.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 48
  store i64 %_147.sroa.0.0, ptr %_54.sroa.5.sroa.3.0._54.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_54.sroa.5.sroa.4.0._54.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 56
  store i64 %_151.sroa.0.0, ptr %_54.sroa.5.sroa.4.0._54.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_54.sroa.5.sroa.5.0._54.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 64
  store i64 %_162.sroa.0.0, ptr %_54.sroa.5.sroa.5.0._54.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_54.sroa.5.sroa.6.0._54.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 72
  store i64 %_166.sroa.0.0, ptr %_54.sroa.5.sroa.6.0._54.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_14.i386 = zext i64 %_50.1 to i128
  %_12.i383 = zext i64 %_189.sroa.0.0 to i128
  %_17.i392 = mul nuw i128 %_14.i386, %_12.i383
  %_4.i734 = lshr i128 %_17.i392, 64
  %x_hi.i735 = trunc nuw i128 %_4.i734 to i64
  %x_hi_hi.i736 = lshr i64 %x_hi.i735, 32
  %x_lo.i733 = trunc i128 %_17.i392 to i64
  %_9.1.i739 = icmp ugt i64 %x_hi_hi.i736, %x_lo.i733
  %_9.0.i738 = sub i64 %x_lo.i733, %x_hi_hi.i736
  %_10.i740 = add i64 %_9.0.i738, -4294967295
  %spec.select.i741 = select i1 %_9.1.i739, i64 %_10.i740, i64 %_9.0.i738
  %x_hi_lo.i737 = and i64 %x_hi.i735, 4294967295
  %t1.i742 = mul nuw i64 %x_hi_lo.i737, 4294967295
  %_14.0.i743 = add i64 %spec.select.i741, %t1.i742
  %_14.1.i744 = icmp ult i64 %_14.0.i743, %spec.select.i741
  %82 = add i64 %_14.0.i743, 4294967295
  %res.sroa.0.0.i745 = select i1 %_14.1.i744, i64 %82, i64 %_14.0.i743
  %_16.i746 = icmp ugt i64 %res.sroa.0.0.i745, -4294967296
  %_17.i747 = add nsw i64 %res.sroa.0.0.i745, 4294967295
  %_0.sroa.0.0.i748 = select i1 %_16.i746, i64 %_17.i747, i64 %res.sroa.0.0.i745
  %_11.i382 = zext i64 %_50.0 to i128
  %_15.i387 = zext i64 %_9.sroa.0.0.i435 to i128
  %_16.i390 = mul nuw i128 %_11.i382, %_15.i387
  %_4.i750 = lshr i128 %_16.i390, 64
  %x_hi.i751 = trunc nuw i128 %_4.i750 to i64
  %x_hi_hi.i752 = lshr i64 %x_hi.i751, 32
  %x_lo.i749 = trunc i128 %_16.i390 to i64
  %_9.1.i755 = icmp ugt i64 %x_hi_hi.i752, %x_lo.i749
  %_9.0.i754 = sub i64 %x_lo.i749, %x_hi_hi.i752
  %_10.i756 = add i64 %_9.0.i754, -4294967295
  %spec.select.i757 = select i1 %_9.1.i755, i64 %_10.i756, i64 %_9.0.i754
  %x_hi_lo.i753 = and i64 %x_hi.i751, 4294967295
  %t1.i758 = mul nuw i64 %x_hi_lo.i753, 4294967295
  %_14.0.i759 = add i64 %spec.select.i757, %t1.i758
  %_14.1.i760 = icmp ult i64 %_14.0.i759, %spec.select.i757
  %83 = add i64 %_14.0.i759, 4294967295
  %res.sroa.0.0.i761 = select i1 %_14.1.i760, i64 %83, i64 %_14.0.i759
  %_16.i762 = icmp ugt i64 %res.sroa.0.0.i761, -4294967296
  %_17.i763 = add nsw i64 %res.sroa.0.0.i761, 4294967295
  %_0.sroa.0.0.i764 = select i1 %_16.i762, i64 %_17.i763, i64 %res.sroa.0.0.i761
  %_29.0.i403 = add i64 %_0.sroa.0.0.i748, %_0.sroa.0.0.i764
  %_29.1.i404 = icmp ult i64 %_29.0.i403, %_0.sroa.0.0.i764
  %84 = add nuw i64 %_29.0.i403, 4294967295
  %_30.sroa.0.0.i405 = select i1 %_29.1.i404, i64 %84, i64 %_29.0.i403
  %_31.i406 = icmp ugt i64 %_30.sroa.0.0.i405, -4294967296
  %_32.i407 = add nsw i64 %_30.sroa.0.0.i405, 4294967295
  %_9.sroa.0.0.i408 = select i1 %_31.i406, i64 %_32.i407, i64 %_30.sroa.0.0.i405
  %_44.1 = extractvalue { i64, i64 } %79, 1
  %_13.0.i80 = add i64 %_9.sroa.0.0.i408, %_44.1
  %_13.1.i81 = icmp ult i64 %_13.0.i80, %_44.1
  %85 = add i64 %_13.0.i80, 4294967295
  %_14.sroa.0.0.i82 = select i1 %_13.1.i81, i64 %85, i64 %_13.0.i80
  %_15.i83 = icmp ugt i64 %_14.sroa.0.0.i82, -4294967296
  %_16.i84 = add nsw i64 %_14.sroa.0.0.i82, 4294967295
  %_4.sroa.0.0.i85 = select i1 %_15.i83, i64 %_16.i84, i64 %_14.sroa.0.0.i82
  %_52.1 = extractvalue { i64, i64 } %81, 1
  %_13.0.i68 = add i64 %_4.sroa.0.0.i85, %_52.1
  %_13.1.i69 = icmp ult i64 %_13.0.i68, %_4.sroa.0.0.i85
  %86 = add i64 %_13.0.i68, 4294967295
  %_14.sroa.0.0.i70 = select i1 %_13.1.i69, i64 %86, i64 %_13.0.i68
  %_15.i71 = icmp ugt i64 %_14.sroa.0.0.i70, -4294967296
  %_16.i72 = add nsw i64 %_14.sroa.0.0.i70, 4294967295
  %_4.sroa.0.0.i73 = select i1 %_15.i71, i64 %_16.i72, i64 %_14.sroa.0.0.i70
  %_13.i388 = mul nuw i128 %_14.i386, %_15.i387
  %_4.i766 = lshr i128 %_13.i388, 64
  %x_hi.i767 = trunc nuw i128 %_4.i766 to i64
  %x_hi_hi.i768 = lshr i64 %x_hi.i767, 32
  %x_lo.i765 = trunc i128 %_13.i388 to i64
  %_9.1.i771 = icmp ugt i64 %x_hi_hi.i768, %x_lo.i765
  %_9.0.i770 = sub i64 %x_lo.i765, %x_hi_hi.i768
  %_10.i772 = add i64 %_9.0.i770, -4294967295
  %spec.select.i773 = select i1 %_9.1.i771, i64 %_10.i772, i64 %_9.0.i770
  %x_hi_lo.i769 = and i64 %x_hi.i767, 4294967295
  %t1.i774 = mul nuw i64 %x_hi_lo.i769, 4294967295
  %_14.0.i775 = add i64 %spec.select.i773, %t1.i774
  %_14.1.i776 = icmp ult i64 %_14.0.i775, %spec.select.i773
  %87 = add i64 %_14.0.i775, 4294967295
  %res.sroa.0.0.i777 = select i1 %_14.1.i776, i64 %87, i64 %_14.0.i775
  %_16.i778 = icmp ugt i64 %res.sroa.0.0.i777, -4294967296
  %_17.i779 = add nsw i64 %res.sroa.0.0.i777, 4294967295
  %_0.sroa.0.0.i780 = select i1 %_16.i778, i64 %_17.i779, i64 %res.sroa.0.0.i777
  %_19.i394 = zext i64 %_0.sroa.0.0.i780 to i128
  %_18.i395 = mul nuw nsw i128 %_19.i394, 7
  %_4.i718 = lshr i128 %_18.i395, 64
  %x_hi.i719 = trunc nuw nsw i128 %_4.i718 to i64
  %t1.i726 = mul nuw nsw i64 %x_hi.i719, 4294967295
  %x_lo.i717 = trunc i128 %_18.i395 to i64
  %_14.0.i727 = add i64 %t1.i726, %x_lo.i717
  %_14.1.i728 = icmp ult i64 %_14.0.i727, %x_lo.i717
  %88 = add i64 %_14.0.i727, 4294967295
  %res.sroa.0.0.i729 = select i1 %_14.1.i728, i64 %88, i64 %_14.0.i727
  %_16.i730 = icmp ugt i64 %res.sroa.0.0.i729, -4294967296
  %_17.i731 = add nsw i64 %res.sroa.0.0.i729, 4294967295
  %_0.sroa.0.0.i732 = select i1 %_16.i730, i64 %_17.i731, i64 %res.sroa.0.0.i729
  %_10.i384 = mul nuw i128 %_11.i382, %_12.i383
  %_4.i782 = lshr i128 %_10.i384, 64
  %x_hi.i783 = trunc nuw i128 %_4.i782 to i64
  %x_hi_hi.i784 = lshr i64 %x_hi.i783, 32
  %x_lo.i781 = trunc i128 %_10.i384 to i64
  %_9.1.i787 = icmp ugt i64 %x_hi_hi.i784, %x_lo.i781
  %_9.0.i786 = sub i64 %x_lo.i781, %x_hi_hi.i784
  %_10.i788 = add i64 %_9.0.i786, -4294967295
  %spec.select.i789 = select i1 %_9.1.i787, i64 %_10.i788, i64 %_9.0.i786
  %x_hi_lo.i785 = and i64 %x_hi.i783, 4294967295
  %t1.i790 = mul nuw i64 %x_hi_lo.i785, 4294967295
  %_14.0.i791 = add i64 %spec.select.i789, %t1.i790
  %_14.1.i792 = icmp ult i64 %_14.0.i791, %spec.select.i789
  %89 = add i64 %_14.0.i791, 4294967295
  %res.sroa.0.0.i793 = select i1 %_14.1.i792, i64 %89, i64 %_14.0.i791
  %_16.i794 = icmp ugt i64 %res.sroa.0.0.i793, -4294967296
  %_17.i795 = add nsw i64 %res.sroa.0.0.i793, 4294967295
  %_0.sroa.0.0.i796 = select i1 %_16.i794, i64 %_17.i795, i64 %res.sroa.0.0.i793
  %_22.0.i397 = add i64 %_0.sroa.0.0.i732, %_0.sroa.0.0.i796
  %_22.1.i398 = icmp ult i64 %_22.0.i397, %_0.sroa.0.0.i796
  %90 = add nuw i64 %_22.0.i397, 4294967295
  %_24.sroa.0.0.i399 = select i1 %_22.1.i398, i64 %90, i64 %_22.0.i397
  %_25.i400 = icmp ugt i64 %_24.sroa.0.0.i399, -4294967296
  %_26.i401 = add nsw i64 %_24.sroa.0.0.i399, 4294967295
  %_7.sroa.0.0.i402 = select i1 %_25.i400, i64 %_26.i401, i64 %_24.sroa.0.0.i399
  %_44.0 = extractvalue { i64, i64 } %79, 0
  %_7.0.i74 = add i64 %_7.sroa.0.0.i402, %_44.0
  %_7.1.i75 = icmp ult i64 %_7.0.i74, %_44.0
  %91 = add i64 %_7.0.i74, 4294967295
  %_8.sroa.0.0.i76 = select i1 %_7.1.i75, i64 %91, i64 %_7.0.i74
  %_9.i77 = icmp ugt i64 %_8.sroa.0.0.i76, -4294967296
  %_10.i78 = add nsw i64 %_8.sroa.0.0.i76, 4294967295
  %_3.sroa.0.0.i79 = select i1 %_9.i77, i64 %_10.i78, i64 %_8.sroa.0.0.i76
  %_52.0 = extractvalue { i64, i64 } %81, 0
  %_7.0.i62 = add i64 %_3.sroa.0.0.i79, %_52.0
  %_7.1.i63 = icmp ult i64 %_7.0.i62, %_3.sroa.0.0.i79
  %92 = add i64 %_7.0.i62, 4294967295
  %_8.sroa.0.0.i64 = select i1 %_7.1.i63, i64 %92, i64 %_7.0.i62
  %_9.i65 = icmp ugt i64 %_8.sroa.0.0.i64, -4294967296
  %_10.i66 = add nsw i64 %_8.sroa.0.0.i64, 4294967295
  %_3.sroa.0.0.i67 = select i1 %_9.i65, i64 %_10.i66, i64 %_8.sroa.0.0.i64
  %_12.i167 = zext i64 %g.sroa.0.0 to i128
  %_15.i170 = zext i64 %g.sroa.5.0 to i128
  br label %bb9.i

bb90:                                             ; preds = %bb86
; call core::slice::index::slice_index_fail
  call void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 4, i64 noundef %_201, i64 noundef %_201, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_dd86d8d2da9777486edeb4de51cc3012) #21
  unreachable

bb9.i:                                            ; preds = %bb9.i.lr.ph, %bb26
  %_4.sroa.0.0.i73.pn1607 = phi i64 [ %_4.sroa.0.0.i73, %bb9.i.lr.ph ], [ %_4.sroa.0.0.i, %bb26 ]
  %_3.sroa.0.0.i67.pn1606 = phi i64 [ %_3.sroa.0.0.i67, %bb9.i.lr.ph ], [ %_3.sroa.0.0.i, %bb26 ]
  %ptr.i.i15881605 = phi ptr [ %_202, %bb9.i.lr.ph ], [ %_16.i.i, %bb26 ]
  %_10.i.i.i15901604 = phi i64 [ 0, %bb9.i.lr.ph ], [ %_11.i.i.i, %bb26 ]
  %_5.not.i.i.i = icmp eq i64 %_10.i.i.i15901604, 3
  br i1 %_5.not.i.i.i, label %bb23, label %bb26

bb23:                                             ; preds = %bb9.i, %bb26
  %_3.sroa.0.0.i67.pn.lcssa.ph = phi i64 [ %_3.sroa.0.0.i, %bb26 ], [ %_3.sroa.0.0.i67.pn1606, %bb9.i ]
  %_4.sroa.0.0.i73.pn.lcssa.ph = phi i64 [ %_4.sroa.0.0.i, %bb26 ], [ %_4.sroa.0.0.i73.pn1607, %bb9.i ]
  call void @llvm.lifetime.end.p0(ptr nonnull %iter)
  %_227 = getelementptr inbounds nuw i8, ptr %_98, i64 544
  %_226 = load i64, ptr %_227, align 8, !noundef !3
  %_228 = icmp ult i64 %_226, %v.1
  br i1 %_228, label %bb96, label %panic12

bb96:                                             ; preds = %bb23
  %93 = getelementptr inbounds nuw i8, ptr %_1, i64 248
  %_250 = load i64, ptr %93, align 8, !noundef !3
  %94 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_226
  %_71.0 = load i64, ptr %94, align 8, !noundef !3
  %95 = getelementptr inbounds nuw i8, ptr %94, i64 8
  %_71.1 = load i64, ptr %95, align 8, !noundef !3
  %96 = getelementptr inbounds nuw i8, ptr %_1, i64 256
  %_259 = load i64, ptr %96, align 8, !noundef !3
  %97 = getelementptr inbounds nuw i8, ptr %_1, i64 264
  %_260 = load i64, ptr %97, align 8, !noundef !3
  %_74.0 = load i64, ptr %v.0, align 8, !noundef !3
  %98 = getelementptr inbounds nuw i8, ptr %v.0, i64 8
  %_74.1 = load i64, ptr %98, align 8, !noundef !3
  %99 = getelementptr inbounds nuw i8, ptr %_1, i64 136
  %_245 = load ptr, ptr %99, align 8, !nonnull !3, !noundef !3
  %100 = getelementptr inbounds nuw i8, ptr %_1, i64 144
  %_244 = load i64, ptr %100, align 8, !noundef !3
  %_246.not = icmp eq i64 %_244, 0
  br i1 %_246.not, label %panic14, label %bb104

panic12:                                          ; preds = %bb23
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_226, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_11ff538006900e8109ee309b459a2f83) #21
  unreachable

bb104:                                            ; preds = %bb96
  %_82 = icmp samesign ugt i64 %v.1, 1
  br i1 %_82, label %bb31, label %panic15

panic14:                                          ; preds = %bb96
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 0, i64 noundef 0, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_0f40a973e4ef77172839bcec3485a3cf) #21
  unreachable

bb31:                                             ; preds = %bb104
  %101 = getelementptr inbounds nuw i8, ptr %_245, i64 8
  %_79.1 = load i64, ptr %101, align 8, !noundef !3
  %_79.0 = load i64, ptr %_245, align 8, !noundef !3
  %102 = getelementptr inbounds nuw i8, ptr %v.0, i64 16
  %_81.0 = load i64, ptr %102, align 8, !noundef !3
  %103 = getelementptr inbounds nuw i8, ptr %v.0, i64 24
  %_81.1 = load i64, ptr %103, align 8, !noundef !3
  %_247.not = icmp eq i64 %_244, 1
  br i1 %_247.not, label %panic16, label %bb105

panic15:                                          ; preds = %bb104
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_7893f8279e457884a76b55b3c0e38bce) #21
  unreachable

bb105:                                            ; preds = %bb31
  %_90.not = icmp eq i64 %v.1, 2
  br i1 %_90.not, label %panic17, label %bb36

panic16:                                          ; preds = %bb31
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef 1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_01d88d31381230f5daa9de4874523a4f) #21
  unreachable

bb36:                                             ; preds = %bb105
  %_11.i355 = zext i64 %_74.0 to i128
  %_15.i360 = zext i64 %_4.sroa.0.0.i73.pn.lcssa.ph to i128
  %_16.i363 = mul nuw i128 %_11.i355, %_15.i360
  %_4.i830 = lshr i128 %_16.i363, 64
  %x_hi.i831 = trunc nuw i128 %_4.i830 to i64
  %x_hi_hi.i832 = lshr i64 %x_hi.i831, 32
  %x_lo.i829 = trunc i128 %_16.i363 to i64
  %_9.1.i835 = icmp ugt i64 %x_hi_hi.i832, %x_lo.i829
  %_9.0.i834 = sub i64 %x_lo.i829, %x_hi_hi.i832
  %_10.i836 = add i64 %_9.0.i834, -4294967295
  %spec.select.i837 = select i1 %_9.1.i835, i64 %_10.i836, i64 %_9.0.i834
  %x_hi_lo.i833 = and i64 %x_hi.i831, 4294967295
  %t1.i838 = mul nuw i64 %x_hi_lo.i833, 4294967295
  %_14.0.i839 = add i64 %spec.select.i837, %t1.i838
  %_14.1.i840 = icmp ult i64 %_14.0.i839, %spec.select.i837
  %104 = add i64 %_14.0.i839, 4294967295
  %res.sroa.0.0.i841 = select i1 %_14.1.i840, i64 %104, i64 %_14.0.i839
  %_16.i842 = icmp ugt i64 %res.sroa.0.0.i841, -4294967296
  %_17.i843 = add nsw i64 %res.sroa.0.0.i841, 4294967295
  %_0.sroa.0.0.i844 = select i1 %_16.i842, i64 %_17.i843, i64 %res.sroa.0.0.i841
  %_14.i359 = zext i64 %_74.1 to i128
  %_12.i356 = zext i64 %_3.sroa.0.0.i67.pn.lcssa.ph to i128
  %_17.i365 = mul nuw i128 %_14.i359, %_12.i356
  %_4.i814 = lshr i128 %_17.i365, 64
  %x_hi.i815 = trunc nuw i128 %_4.i814 to i64
  %x_hi_hi.i816 = lshr i64 %x_hi.i815, 32
  %x_lo.i813 = trunc i128 %_17.i365 to i64
  %_9.1.i819 = icmp ugt i64 %x_hi_hi.i816, %x_lo.i813
  %_9.0.i818 = sub i64 %x_lo.i813, %x_hi_hi.i816
  %_10.i820 = add i64 %_9.0.i818, -4294967295
  %spec.select.i821 = select i1 %_9.1.i819, i64 %_10.i820, i64 %_9.0.i818
  %x_hi_lo.i817 = and i64 %x_hi.i815, 4294967295
  %t1.i822 = mul nuw i64 %x_hi_lo.i817, 4294967295
  %_14.0.i823 = add i64 %spec.select.i821, %t1.i822
  %_14.1.i824 = icmp ult i64 %_14.0.i823, %spec.select.i821
  %105 = add i64 %_14.0.i823, 4294967295
  %res.sroa.0.0.i825 = select i1 %_14.1.i824, i64 %105, i64 %_14.0.i823
  %_16.i826 = icmp ugt i64 %res.sroa.0.0.i825, -4294967296
  %_17.i827 = add nsw i64 %res.sroa.0.0.i825, 4294967295
  %_0.sroa.0.0.i828 = select i1 %_16.i826, i64 %_17.i827, i64 %res.sroa.0.0.i825
  %_29.0.i376 = add i64 %_0.sroa.0.0.i828, %_0.sroa.0.0.i844
  %_29.1.i377 = icmp ult i64 %_29.0.i376, %_0.sroa.0.0.i844
  %106 = add nuw i64 %_29.0.i376, 4294967295
  %_30.sroa.0.0.i378 = select i1 %_29.1.i377, i64 %106, i64 %_29.0.i376
  %_31.i379 = icmp ugt i64 %_30.sroa.0.0.i378, -4294967296
  %_32.i380 = add nsw i64 %_30.sroa.0.0.i378, 4294967295
  %_9.sroa.0.0.i381 = select i1 %_31.i379, i64 %_32.i380, i64 %_30.sroa.0.0.i378
  %_11.i328 = zext i64 %_79.0 to i128
  %_12.i329 = zext i64 %_81.0 to i128
  %_10.i330 = mul nuw i128 %_12.i329, %_11.i328
  %_4.i942 = lshr i128 %_10.i330, 64
  %x_hi.i943 = trunc nuw i128 %_4.i942 to i64
  %x_hi_hi.i944 = lshr i64 %x_hi.i943, 32
  %x_lo.i941 = trunc i128 %_10.i330 to i64
  %_9.1.i947 = icmp ugt i64 %x_hi_hi.i944, %x_lo.i941
  %_9.0.i946 = sub i64 %x_lo.i941, %x_hi_hi.i944
  %_10.i948 = add i64 %_9.0.i946, -4294967295
  %spec.select.i949 = select i1 %_9.1.i947, i64 %_10.i948, i64 %_9.0.i946
  %x_hi_lo.i945 = and i64 %x_hi.i943, 4294967295
  %t1.i950 = mul nuw i64 %x_hi_lo.i945, 4294967295
  %_14.0.i951 = add i64 %spec.select.i949, %t1.i950
  %_14.1.i952 = icmp ult i64 %_14.0.i951, %spec.select.i949
  %107 = add i64 %_14.0.i951, 4294967295
  %res.sroa.0.0.i953 = select i1 %_14.1.i952, i64 %107, i64 %_14.0.i951
  %_16.i954 = icmp ugt i64 %res.sroa.0.0.i953, -4294967296
  %_17.i955 = add nsw i64 %res.sroa.0.0.i953, 4294967295
  %_0.sroa.0.0.i956 = select i1 %_16.i954, i64 %_17.i955, i64 %res.sroa.0.0.i953
  %_14.i332 = zext i64 %_79.1 to i128
  %_15.i333 = zext i64 %_81.1 to i128
  %_13.i334 = mul nuw i128 %_15.i333, %_14.i332
  %_4.i926 = lshr i128 %_13.i334, 64
  %x_hi.i927 = trunc nuw i128 %_4.i926 to i64
  %x_hi_hi.i928 = lshr i64 %x_hi.i927, 32
  %x_lo.i925 = trunc i128 %_13.i334 to i64
  %_9.1.i931 = icmp ugt i64 %x_hi_hi.i928, %x_lo.i925
  %_9.0.i930 = sub i64 %x_lo.i925, %x_hi_hi.i928
  %_10.i932 = add i64 %_9.0.i930, -4294967295
  %spec.select.i933 = select i1 %_9.1.i931, i64 %_10.i932, i64 %_9.0.i930
  %x_hi_lo.i929 = and i64 %x_hi.i927, 4294967295
  %t1.i934 = mul nuw i64 %x_hi_lo.i929, 4294967295
  %_14.0.i935 = add i64 %spec.select.i933, %t1.i934
  %_14.1.i936 = icmp ult i64 %_14.0.i935, %spec.select.i933
  %108 = add i64 %_14.0.i935, 4294967295
  %res.sroa.0.0.i937 = select i1 %_14.1.i936, i64 %108, i64 %_14.0.i935
  %_16.i938 = icmp ugt i64 %res.sroa.0.0.i937, -4294967296
  %_17.i939 = add nsw i64 %res.sroa.0.0.i937, 4294967295
  %_0.sroa.0.0.i940 = select i1 %_16.i938, i64 %_17.i939, i64 %res.sroa.0.0.i937
  %_19.i340 = zext i64 %_0.sroa.0.0.i940 to i128
  %_18.i341 = mul nuw nsw i128 %_19.i340, 7
  %_4.i878 = lshr i128 %_18.i341, 64
  %x_hi.i879 = trunc nuw nsw i128 %_4.i878 to i64
  %t1.i886 = mul nuw nsw i64 %x_hi.i879, 4294967295
  %x_lo.i877 = trunc i128 %_18.i341 to i64
  %_14.0.i887 = add i64 %t1.i886, %x_lo.i877
  %_14.1.i888 = icmp ult i64 %_14.0.i887, %x_lo.i877
  %109 = add i64 %_14.0.i887, 4294967295
  %res.sroa.0.0.i889 = select i1 %_14.1.i888, i64 %109, i64 %_14.0.i887
  %_16.i890 = icmp ugt i64 %res.sroa.0.0.i889, -4294967296
  %_17.i891 = add nsw i64 %res.sroa.0.0.i889, 4294967295
  %_0.sroa.0.0.i892 = select i1 %_16.i890, i64 %_17.i891, i64 %res.sroa.0.0.i889
  %_22.0.i343 = add i64 %_0.sroa.0.0.i892, %_0.sroa.0.0.i956
  %_22.1.i344 = icmp ult i64 %_22.0.i343, %_0.sroa.0.0.i956
  %110 = add nuw i64 %_22.0.i343, 4294967295
  %_24.sroa.0.0.i345 = select i1 %_22.1.i344, i64 %110, i64 %_22.0.i343
  %_25.i346 = icmp ugt i64 %_24.sroa.0.0.i345, -4294967296
  %_26.i347 = add nsw i64 %_24.sroa.0.0.i345, 4294967295
  %_7.sroa.0.0.i348 = select i1 %_25.i346, i64 %_26.i347, i64 %_24.sroa.0.0.i345
  %_11.i301 = zext i64 %_7.sroa.0.0.i348 to i128
  %_12.i302 = zext i64 %g.sroa.0.0 to i128
  %_10.i303 = mul nuw i128 %_11.i301, %_12.i302
  %_4.i1022 = lshr i128 %_10.i303, 64
  %x_hi.i1023 = trunc nuw i128 %_4.i1022 to i64
  %x_hi_hi.i1024 = lshr i64 %x_hi.i1023, 32
  %x_lo.i1021 = trunc i128 %_10.i303 to i64
  %_9.1.i1027 = icmp ugt i64 %x_hi_hi.i1024, %x_lo.i1021
  %_9.0.i1026 = sub i64 %x_lo.i1021, %x_hi_hi.i1024
  %_10.i1028 = add i64 %_9.0.i1026, -4294967295
  %spec.select.i1029 = select i1 %_9.1.i1027, i64 %_10.i1028, i64 %_9.0.i1026
  %x_hi_lo.i1025 = and i64 %x_hi.i1023, 4294967295
  %t1.i1030 = mul nuw i64 %x_hi_lo.i1025, 4294967295
  %_14.0.i1031 = add i64 %spec.select.i1029, %t1.i1030
  %_14.1.i1032 = icmp ult i64 %_14.0.i1031, %spec.select.i1029
  %111 = add i64 %_14.0.i1031, 4294967295
  %res.sroa.0.0.i1033 = select i1 %_14.1.i1032, i64 %111, i64 %_14.0.i1031
  %_16.i1034 = icmp ugt i64 %res.sroa.0.0.i1033, -4294967296
  %_17.i1035 = add nsw i64 %res.sroa.0.0.i1033, 4294967295
  %_0.sroa.0.0.i1036 = select i1 %_16.i1034, i64 %_17.i1035, i64 %res.sroa.0.0.i1033
  %_16.i336 = mul nuw i128 %_15.i333, %_11.i328
  %_4.i910 = lshr i128 %_16.i336, 64
  %x_hi.i911 = trunc nuw i128 %_4.i910 to i64
  %x_hi_hi.i912 = lshr i64 %x_hi.i911, 32
  %x_lo.i909 = trunc i128 %_16.i336 to i64
  %_9.1.i915 = icmp ugt i64 %x_hi_hi.i912, %x_lo.i909
  %_9.0.i914 = sub i64 %x_lo.i909, %x_hi_hi.i912
  %_10.i916 = add i64 %_9.0.i914, -4294967295
  %spec.select.i917 = select i1 %_9.1.i915, i64 %_10.i916, i64 %_9.0.i914
  %x_hi_lo.i913 = and i64 %x_hi.i911, 4294967295
  %t1.i918 = mul nuw i64 %x_hi_lo.i913, 4294967295
  %_14.0.i919 = add i64 %spec.select.i917, %t1.i918
  %_14.1.i920 = icmp ult i64 %_14.0.i919, %spec.select.i917
  %112 = add i64 %_14.0.i919, 4294967295
  %res.sroa.0.0.i921 = select i1 %_14.1.i920, i64 %112, i64 %_14.0.i919
  %_16.i922 = icmp ugt i64 %res.sroa.0.0.i921, -4294967296
  %_17.i923 = add nsw i64 %res.sroa.0.0.i921, 4294967295
  %_0.sroa.0.0.i924 = select i1 %_16.i922, i64 %_17.i923, i64 %res.sroa.0.0.i921
  %_17.i338 = mul nuw i128 %_12.i329, %_14.i332
  %_4.i894 = lshr i128 %_17.i338, 64
  %x_hi.i895 = trunc nuw i128 %_4.i894 to i64
  %x_hi_hi.i896 = lshr i64 %x_hi.i895, 32
  %x_lo.i893 = trunc i128 %_17.i338 to i64
  %_9.1.i899 = icmp ugt i64 %x_hi_hi.i896, %x_lo.i893
  %_9.0.i898 = sub i64 %x_lo.i893, %x_hi_hi.i896
  %_10.i900 = add i64 %_9.0.i898, -4294967295
  %spec.select.i901 = select i1 %_9.1.i899, i64 %_10.i900, i64 %_9.0.i898
  %x_hi_lo.i897 = and i64 %x_hi.i895, 4294967295
  %t1.i902 = mul nuw i64 %x_hi_lo.i897, 4294967295
  %_14.0.i903 = add i64 %spec.select.i901, %t1.i902
  %_14.1.i904 = icmp ult i64 %_14.0.i903, %spec.select.i901
  %113 = add i64 %_14.0.i903, 4294967295
  %res.sroa.0.0.i905 = select i1 %_14.1.i904, i64 %113, i64 %_14.0.i903
  %_16.i906 = icmp ugt i64 %res.sroa.0.0.i905, -4294967296
  %_17.i907 = add nsw i64 %res.sroa.0.0.i905, 4294967295
  %_0.sroa.0.0.i908 = select i1 %_16.i906, i64 %_17.i907, i64 %res.sroa.0.0.i905
  %_29.0.i349 = add i64 %_0.sroa.0.0.i924, %_0.sroa.0.0.i908
  %_29.1.i350 = icmp ult i64 %_29.0.i349, %_0.sroa.0.0.i924
  %114 = add nuw i64 %_29.0.i349, 4294967295
  %_30.sroa.0.0.i351 = select i1 %_29.1.i350, i64 %114, i64 %_29.0.i349
  %_31.i352 = icmp ugt i64 %_30.sroa.0.0.i351, -4294967296
  %_32.i353 = add nsw i64 %_30.sroa.0.0.i351, 4294967295
  %_9.sroa.0.0.i354 = select i1 %_31.i352, i64 %_32.i353, i64 %_30.sroa.0.0.i351
  %_14.i305 = zext i64 %_9.sroa.0.0.i354 to i128
  %_15.i306 = zext i64 %g.sroa.5.0 to i128
  %_13.i307 = mul nuw i128 %_14.i305, %_15.i306
  %_4.i1006 = lshr i128 %_13.i307, 64
  %x_hi.i1007 = trunc nuw i128 %_4.i1006 to i64
  %x_hi_hi.i1008 = lshr i64 %x_hi.i1007, 32
  %x_lo.i1005 = trunc i128 %_13.i307 to i64
  %_9.1.i1011 = icmp ugt i64 %x_hi_hi.i1008, %x_lo.i1005
  %_9.0.i1010 = sub i64 %x_lo.i1005, %x_hi_hi.i1008
  %_10.i1012 = add i64 %_9.0.i1010, -4294967295
  %spec.select.i1013 = select i1 %_9.1.i1011, i64 %_10.i1012, i64 %_9.0.i1010
  %x_hi_lo.i1009 = and i64 %x_hi.i1007, 4294967295
  %t1.i1014 = mul nuw i64 %x_hi_lo.i1009, 4294967295
  %_14.0.i1015 = add i64 %spec.select.i1013, %t1.i1014
  %_14.1.i1016 = icmp ult i64 %_14.0.i1015, %spec.select.i1013
  %115 = add i64 %_14.0.i1015, 4294967295
  %res.sroa.0.0.i1017 = select i1 %_14.1.i1016, i64 %115, i64 %_14.0.i1015
  %_16.i1018 = icmp ugt i64 %res.sroa.0.0.i1017, -4294967296
  %_17.i1019 = add nsw i64 %res.sroa.0.0.i1017, 4294967295
  %_0.sroa.0.0.i1020 = select i1 %_16.i1018, i64 %_17.i1019, i64 %res.sroa.0.0.i1017
  %_19.i313 = zext i64 %_0.sroa.0.0.i1020 to i128
  %_18.i314 = mul nuw nsw i128 %_19.i313, 7
  %_4.i958 = lshr i128 %_18.i314, 64
  %x_hi.i959 = trunc nuw nsw i128 %_4.i958 to i64
  %t1.i966 = mul nuw nsw i64 %x_hi.i959, 4294967295
  %x_lo.i957 = trunc i128 %_18.i314 to i64
  %_14.0.i967 = add i64 %t1.i966, %x_lo.i957
  %_14.1.i968 = icmp ult i64 %_14.0.i967, %x_lo.i957
  %116 = add i64 %_14.0.i967, 4294967295
  %res.sroa.0.0.i969 = select i1 %_14.1.i968, i64 %116, i64 %_14.0.i967
  %_16.i970 = icmp ugt i64 %res.sroa.0.0.i969, -4294967296
  %_17.i971 = add nsw i64 %res.sroa.0.0.i969, 4294967295
  %_0.sroa.0.0.i972 = select i1 %_16.i970, i64 %_17.i971, i64 %res.sroa.0.0.i969
  %_22.0.i316 = add i64 %_0.sroa.0.0.i1036, %_0.sroa.0.0.i972
  %_22.1.i317 = icmp ult i64 %_22.0.i316, %_0.sroa.0.0.i1036
  %117 = add nuw i64 %_22.0.i316, 4294967295
  %_24.sroa.0.0.i318 = select i1 %_22.1.i317, i64 %117, i64 %_22.0.i316
  %_25.i319 = icmp ugt i64 %_24.sroa.0.0.i318, -4294967296
  %_26.i320 = add nsw i64 %_24.sroa.0.0.i318, 4294967295
  %_7.sroa.0.0.i321 = select i1 %_25.i319, i64 %_26.i320, i64 %_24.sroa.0.0.i318
  %_11.i274 = zext i64 %_7.sroa.0.0.i321 to i128
  %_225 = zext i64 %g8.1 to i128
  %_223 = zext i64 %_250 to i128
  %_224 = mul nuw i128 %_223, %_225
  %_4.i1518 = lshr i128 %_224, 64
  %x_hi.i1519 = trunc nuw i128 %_4.i1518 to i64
  %x_hi_hi.i1520 = lshr i64 %x_hi.i1519, 32
  %x_lo.i1517 = trunc i128 %_224 to i64
  %_9.1.i1523 = icmp ugt i64 %x_hi_hi.i1520, %x_lo.i1517
  %_9.0.i1522 = sub i64 %x_lo.i1517, %x_hi_hi.i1520
  %_10.i1524 = add i64 %_9.0.i1522, -4294967295
  %spec.select.i1525 = select i1 %_9.1.i1523, i64 %_10.i1524, i64 %_9.0.i1522
  %x_hi_lo.i1521 = and i64 %x_hi.i1519, 4294967295
  %t1.i1526 = mul nuw i64 %x_hi_lo.i1521, 4294967295
  %_14.0.i1527 = add i64 %spec.select.i1525, %t1.i1526
  %_14.1.i1528 = icmp ult i64 %_14.0.i1527, %spec.select.i1525
  %118 = add i64 %_14.0.i1527, 4294967295
  %res.sroa.0.0.i1529 = select i1 %_14.1.i1528, i64 %118, i64 %_14.0.i1527
  %_16.i1530 = icmp ugt i64 %res.sroa.0.0.i1529, -4294967296
  %_17.i1531 = add nsw i64 %res.sroa.0.0.i1529, 4294967295
  %_0.sroa.0.0.i1532 = select i1 %_16.i1530, i64 %_17.i1531, i64 %res.sroa.0.0.i1529
  %_13.0.i56 = add i64 %_0.sroa.0.0.i1532, %_71.1
  %_13.1.i57 = icmp ult i64 %_13.0.i56, %_0.sroa.0.0.i1532
  %119 = add i64 %_13.0.i56, 4294967295
  %_14.sroa.0.0.i58 = select i1 %_13.1.i57, i64 %119, i64 %_13.0.i56
  %_15.i59 = icmp ugt i64 %_14.sroa.0.0.i58, -4294967296
  %_16.i60 = add nsw i64 %_14.sroa.0.0.i58, 4294967295
  %_4.sroa.0.0.i61 = select i1 %_15.i59, i64 %_16.i60, i64 %_14.sroa.0.0.i58
  %_238.1 = icmp ult i64 %_4.sroa.0.0.i61, %_260
  %_238.0 = sub i64 %_4.sroa.0.0.i61, %_260
  %120 = add i64 %_238.0, -4294967295
  %_239.sroa.0.0 = select i1 %_238.1, i64 %120, i64 %_238.0
  %_15.i279 = zext i64 %_239.sroa.0.0 to i128
  %_16.i282 = mul nuw i128 %_11.i274, %_15.i279
  %_4.i1070 = lshr i128 %_16.i282, 64
  %x_hi.i1071 = trunc nuw i128 %_4.i1070 to i64
  %x_hi_hi.i1072 = lshr i64 %x_hi.i1071, 32
  %x_lo.i1069 = trunc i128 %_16.i282 to i64
  %_9.1.i1075 = icmp ugt i64 %x_hi_hi.i1072, %x_lo.i1069
  %_9.0.i1074 = sub i64 %x_lo.i1069, %x_hi_hi.i1072
  %_10.i1076 = add i64 %_9.0.i1074, -4294967295
  %spec.select.i1077 = select i1 %_9.1.i1075, i64 %_10.i1076, i64 %_9.0.i1074
  %x_hi_lo.i1073 = and i64 %x_hi.i1071, 4294967295
  %t1.i1078 = mul nuw i64 %x_hi_lo.i1073, 4294967295
  %_14.0.i1079 = add i64 %spec.select.i1077, %t1.i1078
  %_14.1.i1080 = icmp ult i64 %_14.0.i1079, %spec.select.i1077
  %121 = add i64 %_14.0.i1079, 4294967295
  %res.sroa.0.0.i1081 = select i1 %_14.1.i1080, i64 %121, i64 %_14.0.i1079
  %_16.i1082 = icmp ugt i64 %res.sroa.0.0.i1081, -4294967296
  %_17.i1083 = add nsw i64 %res.sroa.0.0.i1081, 4294967295
  %_0.sroa.0.0.i1084 = select i1 %_16.i1082, i64 %_17.i1083, i64 %res.sroa.0.0.i1081
  %_16.i309 = mul nuw i128 %_11.i301, %_15.i306
  %_4.i990 = lshr i128 %_16.i309, 64
  %x_hi.i991 = trunc nuw i128 %_4.i990 to i64
  %x_hi_hi.i992 = lshr i64 %x_hi.i991, 32
  %x_lo.i989 = trunc i128 %_16.i309 to i64
  %_9.1.i995 = icmp ugt i64 %x_hi_hi.i992, %x_lo.i989
  %_9.0.i994 = sub i64 %x_lo.i989, %x_hi_hi.i992
  %_10.i996 = add i64 %_9.0.i994, -4294967295
  %spec.select.i997 = select i1 %_9.1.i995, i64 %_10.i996, i64 %_9.0.i994
  %x_hi_lo.i993 = and i64 %x_hi.i991, 4294967295
  %t1.i998 = mul nuw i64 %x_hi_lo.i993, 4294967295
  %_14.0.i999 = add i64 %spec.select.i997, %t1.i998
  %_14.1.i1000 = icmp ult i64 %_14.0.i999, %spec.select.i997
  %122 = add i64 %_14.0.i999, 4294967295
  %res.sroa.0.0.i1001 = select i1 %_14.1.i1000, i64 %122, i64 %_14.0.i999
  %_16.i1002 = icmp ugt i64 %res.sroa.0.0.i1001, -4294967296
  %_17.i1003 = add nsw i64 %res.sroa.0.0.i1001, 4294967295
  %_0.sroa.0.0.i1004 = select i1 %_16.i1002, i64 %_17.i1003, i64 %res.sroa.0.0.i1001
  %_17.i311 = mul nuw i128 %_14.i305, %_12.i302
  %_4.i974 = lshr i128 %_17.i311, 64
  %x_hi.i975 = trunc nuw i128 %_4.i974 to i64
  %x_hi_hi.i976 = lshr i64 %x_hi.i975, 32
  %x_lo.i973 = trunc i128 %_17.i311 to i64
  %_9.1.i979 = icmp ugt i64 %x_hi_hi.i976, %x_lo.i973
  %_9.0.i978 = sub i64 %x_lo.i973, %x_hi_hi.i976
  %_10.i980 = add i64 %_9.0.i978, -4294967295
  %spec.select.i981 = select i1 %_9.1.i979, i64 %_10.i980, i64 %_9.0.i978
  %x_hi_lo.i977 = and i64 %x_hi.i975, 4294967295
  %t1.i982 = mul nuw i64 %x_hi_lo.i977, 4294967295
  %_14.0.i983 = add i64 %spec.select.i981, %t1.i982
  %_14.1.i984 = icmp ult i64 %_14.0.i983, %spec.select.i981
  %123 = add i64 %_14.0.i983, 4294967295
  %res.sroa.0.0.i985 = select i1 %_14.1.i984, i64 %123, i64 %_14.0.i983
  %_16.i986 = icmp ugt i64 %res.sroa.0.0.i985, -4294967296
  %_17.i987 = add nsw i64 %res.sroa.0.0.i985, 4294967295
  %_0.sroa.0.0.i988 = select i1 %_16.i986, i64 %_17.i987, i64 %res.sroa.0.0.i985
  %_29.0.i322 = add i64 %_0.sroa.0.0.i1004, %_0.sroa.0.0.i988
  %_29.1.i323 = icmp ult i64 %_29.0.i322, %_0.sroa.0.0.i1004
  %124 = add nuw i64 %_29.0.i322, 4294967295
  %_30.sroa.0.0.i324 = select i1 %_29.1.i323, i64 %124, i64 %_29.0.i322
  %_31.i325 = icmp ugt i64 %_30.sroa.0.0.i324, -4294967296
  %_32.i326 = add nsw i64 %_30.sroa.0.0.i324, 4294967295
  %_9.sroa.0.0.i327 = select i1 %_31.i325, i64 %_32.i326, i64 %_30.sroa.0.0.i324
  %_14.i278 = zext i64 %_9.sroa.0.0.i327 to i128
  %_222 = zext i64 %g8.0 to i128
  %_221 = mul nuw i128 %_223, %_222
  %_4.i1534 = lshr i128 %_221, 64
  %x_hi.i1535 = trunc nuw i128 %_4.i1534 to i64
  %x_hi_hi.i1536 = lshr i64 %x_hi.i1535, 32
  %x_lo.i1533 = trunc i128 %_221 to i64
  %_9.1.i1539 = icmp ugt i64 %x_hi_hi.i1536, %x_lo.i1533
  %_9.0.i1538 = sub i64 %x_lo.i1533, %x_hi_hi.i1536
  %_10.i1540 = add i64 %_9.0.i1538, -4294967295
  %spec.select.i1541 = select i1 %_9.1.i1539, i64 %_10.i1540, i64 %_9.0.i1538
  %x_hi_lo.i1537 = and i64 %x_hi.i1535, 4294967295
  %t1.i1542 = mul nuw i64 %x_hi_lo.i1537, 4294967295
  %_14.0.i1543 = add i64 %spec.select.i1541, %t1.i1542
  %_14.1.i1544 = icmp ult i64 %_14.0.i1543, %spec.select.i1541
  %125 = add i64 %_14.0.i1543, 4294967295
  %res.sroa.0.0.i1545 = select i1 %_14.1.i1544, i64 %125, i64 %_14.0.i1543
  %_16.i1546 = icmp ugt i64 %res.sroa.0.0.i1545, -4294967296
  %_17.i1547 = add nsw i64 %res.sroa.0.0.i1545, 4294967295
  %_0.sroa.0.0.i1548 = select i1 %_16.i1546, i64 %_17.i1547, i64 %res.sroa.0.0.i1545
  %_7.0.i50 = add i64 %_0.sroa.0.0.i1548, %_71.0
  %_7.1.i51 = icmp ult i64 %_7.0.i50, %_0.sroa.0.0.i1548
  %126 = add i64 %_7.0.i50, 4294967295
  %_8.sroa.0.0.i52 = select i1 %_7.1.i51, i64 %126, i64 %_7.0.i50
  %_9.i53 = icmp ugt i64 %_8.sroa.0.0.i52, -4294967296
  %_10.i54 = add nsw i64 %_8.sroa.0.0.i52, 4294967295
  %_3.sroa.0.0.i55 = select i1 %_9.i53, i64 %_10.i54, i64 %_8.sroa.0.0.i52
  %_234.1 = icmp ult i64 %_3.sroa.0.0.i55, %_259
  %_234.0 = sub i64 %_3.sroa.0.0.i55, %_259
  %127 = add i64 %_234.0, -4294967295
  %_235.sroa.0.0 = select i1 %_234.1, i64 %127, i64 %_234.0
  %_12.i275 = zext i64 %_235.sroa.0.0 to i128
  %_17.i284 = mul nuw i128 %_14.i278, %_12.i275
  %_4.i1054 = lshr i128 %_17.i284, 64
  %x_hi.i1055 = trunc nuw i128 %_4.i1054 to i64
  %x_hi_hi.i1056 = lshr i64 %x_hi.i1055, 32
  %x_lo.i1053 = trunc i128 %_17.i284 to i64
  %_9.1.i1059 = icmp ugt i64 %x_hi_hi.i1056, %x_lo.i1053
  %_9.0.i1058 = sub i64 %x_lo.i1053, %x_hi_hi.i1056
  %_10.i1060 = add i64 %_9.0.i1058, -4294967295
  %spec.select.i1061 = select i1 %_9.1.i1059, i64 %_10.i1060, i64 %_9.0.i1058
  %x_hi_lo.i1057 = and i64 %x_hi.i1055, 4294967295
  %t1.i1062 = mul nuw i64 %x_hi_lo.i1057, 4294967295
  %_14.0.i1063 = add i64 %spec.select.i1061, %t1.i1062
  %_14.1.i1064 = icmp ult i64 %_14.0.i1063, %spec.select.i1061
  %128 = add i64 %_14.0.i1063, 4294967295
  %res.sroa.0.0.i1065 = select i1 %_14.1.i1064, i64 %128, i64 %_14.0.i1063
  %_16.i1066 = icmp ugt i64 %res.sroa.0.0.i1065, -4294967296
  %_17.i1067 = add nsw i64 %res.sroa.0.0.i1065, 4294967295
  %_0.sroa.0.0.i1068 = select i1 %_16.i1066, i64 %_17.i1067, i64 %res.sroa.0.0.i1065
  %_29.0.i295 = add i64 %_0.sroa.0.0.i1084, %_0.sroa.0.0.i1068
  %_29.1.i296 = icmp ult i64 %_29.0.i295, %_0.sroa.0.0.i1084
  %129 = add nuw i64 %_29.0.i295, 4294967295
  %_30.sroa.0.0.i297 = select i1 %_29.1.i296, i64 %129, i64 %_29.0.i295
  %_31.i298 = icmp ugt i64 %_30.sroa.0.0.i297, -4294967296
  %_32.i299 = add nsw i64 %_30.sroa.0.0.i297, 4294967295
  %_9.sroa.0.0.i300 = select i1 %_31.i298, i64 %_32.i299, i64 %_30.sroa.0.0.i297
  %_13.0.i44 = add i64 %_9.sroa.0.0.i300, %_9.sroa.0.0.i381
  %_13.1.i45 = icmp ult i64 %_13.0.i44, %_9.sroa.0.0.i381
  %130 = add i64 %_13.0.i44, 4294967295
  %_14.sroa.0.0.i46 = select i1 %_13.1.i45, i64 %130, i64 %_13.0.i44
  %_15.i47 = icmp ugt i64 %_14.sroa.0.0.i46, -4294967296
  %_16.i48 = add nsw i64 %_14.sroa.0.0.i46, 4294967295
  %_4.sroa.0.0.i49 = select i1 %_15.i47, i64 %_16.i48, i64 %_14.sroa.0.0.i46
  %_10.i357 = mul nuw i128 %_11.i355, %_12.i356
  %_4.i862 = lshr i128 %_10.i357, 64
  %x_hi.i863 = trunc nuw i128 %_4.i862 to i64
  %x_hi_hi.i864 = lshr i64 %x_hi.i863, 32
  %x_lo.i861 = trunc i128 %_10.i357 to i64
  %_9.1.i867 = icmp ugt i64 %x_hi_hi.i864, %x_lo.i861
  %_9.0.i866 = sub i64 %x_lo.i861, %x_hi_hi.i864
  %_10.i868 = add i64 %_9.0.i866, -4294967295
  %spec.select.i869 = select i1 %_9.1.i867, i64 %_10.i868, i64 %_9.0.i866
  %x_hi_lo.i865 = and i64 %x_hi.i863, 4294967295
  %t1.i870 = mul nuw i64 %x_hi_lo.i865, 4294967295
  %_14.0.i871 = add i64 %spec.select.i869, %t1.i870
  %_14.1.i872 = icmp ult i64 %_14.0.i871, %spec.select.i869
  %131 = add i64 %_14.0.i871, 4294967295
  %res.sroa.0.0.i873 = select i1 %_14.1.i872, i64 %131, i64 %_14.0.i871
  %_16.i874 = icmp ugt i64 %res.sroa.0.0.i873, -4294967296
  %_17.i875 = add nsw i64 %res.sroa.0.0.i873, 4294967295
  %_0.sroa.0.0.i876 = select i1 %_16.i874, i64 %_17.i875, i64 %res.sroa.0.0.i873
  %_13.i361 = mul nuw i128 %_14.i359, %_15.i360
  %_4.i846 = lshr i128 %_13.i361, 64
  %x_hi.i847 = trunc nuw i128 %_4.i846 to i64
  %x_hi_hi.i848 = lshr i64 %x_hi.i847, 32
  %x_lo.i845 = trunc i128 %_13.i361 to i64
  %_9.1.i851 = icmp ugt i64 %x_hi_hi.i848, %x_lo.i845
  %_9.0.i850 = sub i64 %x_lo.i845, %x_hi_hi.i848
  %_10.i852 = add i64 %_9.0.i850, -4294967295
  %spec.select.i853 = select i1 %_9.1.i851, i64 %_10.i852, i64 %_9.0.i850
  %x_hi_lo.i849 = and i64 %x_hi.i847, 4294967295
  %t1.i854 = mul nuw i64 %x_hi_lo.i849, 4294967295
  %_14.0.i855 = add i64 %spec.select.i853, %t1.i854
  %_14.1.i856 = icmp ult i64 %_14.0.i855, %spec.select.i853
  %132 = add i64 %_14.0.i855, 4294967295
  %res.sroa.0.0.i857 = select i1 %_14.1.i856, i64 %132, i64 %_14.0.i855
  %_16.i858 = icmp ugt i64 %res.sroa.0.0.i857, -4294967296
  %_17.i859 = add nsw i64 %res.sroa.0.0.i857, 4294967295
  %_0.sroa.0.0.i860 = select i1 %_16.i858, i64 %_17.i859, i64 %res.sroa.0.0.i857
  %_19.i367 = zext i64 %_0.sroa.0.0.i860 to i128
  %_18.i368 = mul nuw nsw i128 %_19.i367, 7
  %_4.i798 = lshr i128 %_18.i368, 64
  %x_hi.i799 = trunc nuw nsw i128 %_4.i798 to i64
  %t1.i806 = mul nuw nsw i64 %x_hi.i799, 4294967295
  %x_lo.i797 = trunc i128 %_18.i368 to i64
  %_14.0.i807 = add i64 %t1.i806, %x_lo.i797
  %_14.1.i808 = icmp ult i64 %_14.0.i807, %x_lo.i797
  %133 = add i64 %_14.0.i807, 4294967295
  %res.sroa.0.0.i809 = select i1 %_14.1.i808, i64 %133, i64 %_14.0.i807
  %_16.i810 = icmp ugt i64 %res.sroa.0.0.i809, -4294967296
  %_17.i811 = add nsw i64 %res.sroa.0.0.i809, 4294967295
  %_0.sroa.0.0.i812 = select i1 %_16.i810, i64 %_17.i811, i64 %res.sroa.0.0.i809
  %_22.0.i370 = add i64 %_0.sroa.0.0.i812, %_0.sroa.0.0.i876
  %_22.1.i371 = icmp ult i64 %_22.0.i370, %_0.sroa.0.0.i876
  %134 = add nuw i64 %_22.0.i370, 4294967295
  %_24.sroa.0.0.i372 = select i1 %_22.1.i371, i64 %134, i64 %_22.0.i370
  %_25.i373 = icmp ugt i64 %_24.sroa.0.0.i372, -4294967296
  %_26.i374 = add nsw i64 %_24.sroa.0.0.i372, 4294967295
  %_7.sroa.0.0.i375 = select i1 %_25.i373, i64 %_26.i374, i64 %_24.sroa.0.0.i372
  %_10.i276 = mul nuw i128 %_11.i274, %_12.i275
  %_4.i1102 = lshr i128 %_10.i276, 64
  %x_hi.i1103 = trunc nuw i128 %_4.i1102 to i64
  %x_hi_hi.i1104 = lshr i64 %x_hi.i1103, 32
  %x_lo.i1101 = trunc i128 %_10.i276 to i64
  %_9.1.i1107 = icmp ugt i64 %x_hi_hi.i1104, %x_lo.i1101
  %_9.0.i1106 = sub i64 %x_lo.i1101, %x_hi_hi.i1104
  %_10.i1108 = add i64 %_9.0.i1106, -4294967295
  %spec.select.i1109 = select i1 %_9.1.i1107, i64 %_10.i1108, i64 %_9.0.i1106
  %x_hi_lo.i1105 = and i64 %x_hi.i1103, 4294967295
  %t1.i1110 = mul nuw i64 %x_hi_lo.i1105, 4294967295
  %_14.0.i1111 = add i64 %spec.select.i1109, %t1.i1110
  %_14.1.i1112 = icmp ult i64 %_14.0.i1111, %spec.select.i1109
  %135 = add i64 %_14.0.i1111, 4294967295
  %res.sroa.0.0.i1113 = select i1 %_14.1.i1112, i64 %135, i64 %_14.0.i1111
  %_16.i1114 = icmp ugt i64 %res.sroa.0.0.i1113, -4294967296
  %_17.i1115 = add nsw i64 %res.sroa.0.0.i1113, 4294967295
  %_0.sroa.0.0.i1116 = select i1 %_16.i1114, i64 %_17.i1115, i64 %res.sroa.0.0.i1113
  %_13.i280 = mul nuw i128 %_14.i278, %_15.i279
  %_4.i1086 = lshr i128 %_13.i280, 64
  %x_hi.i1087 = trunc nuw i128 %_4.i1086 to i64
  %x_hi_hi.i1088 = lshr i64 %x_hi.i1087, 32
  %x_lo.i1085 = trunc i128 %_13.i280 to i64
  %_9.1.i1091 = icmp ugt i64 %x_hi_hi.i1088, %x_lo.i1085
  %_9.0.i1090 = sub i64 %x_lo.i1085, %x_hi_hi.i1088
  %_10.i1092 = add i64 %_9.0.i1090, -4294967295
  %spec.select.i1093 = select i1 %_9.1.i1091, i64 %_10.i1092, i64 %_9.0.i1090
  %x_hi_lo.i1089 = and i64 %x_hi.i1087, 4294967295
  %t1.i1094 = mul nuw i64 %x_hi_lo.i1089, 4294967295
  %_14.0.i1095 = add i64 %spec.select.i1093, %t1.i1094
  %_14.1.i1096 = icmp ult i64 %_14.0.i1095, %spec.select.i1093
  %136 = add i64 %_14.0.i1095, 4294967295
  %res.sroa.0.0.i1097 = select i1 %_14.1.i1096, i64 %136, i64 %_14.0.i1095
  %_16.i1098 = icmp ugt i64 %res.sroa.0.0.i1097, -4294967296
  %_17.i1099 = add nsw i64 %res.sroa.0.0.i1097, 4294967295
  %_0.sroa.0.0.i1100 = select i1 %_16.i1098, i64 %_17.i1099, i64 %res.sroa.0.0.i1097
  %_19.i286 = zext i64 %_0.sroa.0.0.i1100 to i128
  %_18.i287 = mul nuw nsw i128 %_19.i286, 7
  %_4.i1038 = lshr i128 %_18.i287, 64
  %x_hi.i1039 = trunc nuw nsw i128 %_4.i1038 to i64
  %t1.i1046 = mul nuw nsw i64 %x_hi.i1039, 4294967295
  %x_lo.i1037 = trunc i128 %_18.i287 to i64
  %_14.0.i1047 = add i64 %t1.i1046, %x_lo.i1037
  %_14.1.i1048 = icmp ult i64 %_14.0.i1047, %x_lo.i1037
  %137 = add i64 %_14.0.i1047, 4294967295
  %res.sroa.0.0.i1049 = select i1 %_14.1.i1048, i64 %137, i64 %_14.0.i1047
  %_16.i1050 = icmp ugt i64 %res.sroa.0.0.i1049, -4294967296
  %_17.i1051 = add nsw i64 %res.sroa.0.0.i1049, 4294967295
  %_0.sroa.0.0.i1052 = select i1 %_16.i1050, i64 %_17.i1051, i64 %res.sroa.0.0.i1049
  %_22.0.i289 = add i64 %_0.sroa.0.0.i1052, %_0.sroa.0.0.i1116
  %_22.1.i290 = icmp ult i64 %_22.0.i289, %_0.sroa.0.0.i1116
  %138 = add nuw i64 %_22.0.i289, 4294967295
  %_24.sroa.0.0.i291 = select i1 %_22.1.i290, i64 %138, i64 %_22.0.i289
  %_25.i292 = icmp ugt i64 %_24.sroa.0.0.i291, -4294967296
  %_26.i293 = add nsw i64 %_24.sroa.0.0.i291, 4294967295
  %_7.sroa.0.0.i294 = select i1 %_25.i292, i64 %_26.i293, i64 %_24.sroa.0.0.i291
  %_7.0.i38 = add i64 %_7.sroa.0.0.i294, %_7.sroa.0.0.i375
  %_7.1.i39 = icmp ult i64 %_7.0.i38, %_7.sroa.0.0.i375
  %139 = add i64 %_7.0.i38, 4294967295
  %_8.sroa.0.0.i40 = select i1 %_7.1.i39, i64 %139, i64 %_7.0.i38
  %_9.i41 = icmp ugt i64 %_8.sroa.0.0.i40, -4294967296
  %_10.i42 = add nsw i64 %_8.sroa.0.0.i40, 4294967295
  %_3.sroa.0.0.i43 = select i1 %_9.i41, i64 %_10.i42, i64 %_8.sroa.0.0.i40
  %140 = getelementptr inbounds nuw i8, ptr %_245, i64 24
  %_87.1 = load i64, ptr %140, align 8, !noundef !3
  %_88 = getelementptr inbounds nuw i8, ptr %_245, i64 16
  %_87.0 = load i64, ptr %_88, align 8, !noundef !3
  %141 = getelementptr inbounds nuw i8, ptr %v.0, i64 32
  %_89.0 = load i64, ptr %141, align 8, !noundef !3
  %142 = getelementptr inbounds nuw i8, ptr %v.0, i64 40
  %_89.1 = load i64, ptr %142, align 8, !noundef !3
  %_11.i247 = zext i64 %_87.0 to i128
  %_12.i248 = zext i64 %_89.0 to i128
  %_10.i249 = mul nuw i128 %_12.i248, %_11.i247
  %x_lo.i1181 = trunc i128 %_10.i249 to i64
  %_4.i1182 = lshr i128 %_10.i249, 64
  %x_hi.i1183 = trunc nuw i128 %_4.i1182 to i64
  %x_hi_hi.i1184 = lshr i64 %x_hi.i1183, 32
  %x_hi_lo.i1185 = and i64 %x_hi.i1183, 4294967295
  %_9.0.i1186 = sub i64 %x_lo.i1181, %x_hi_hi.i1184
  %_9.1.i1187 = icmp ugt i64 %x_hi_hi.i1184, %x_lo.i1181
  %_10.i1188 = add i64 %_9.0.i1186, -4294967295
  %spec.select.i1189 = select i1 %_9.1.i1187, i64 %_10.i1188, i64 %_9.0.i1186
  %t1.i1190 = mul nuw i64 %x_hi_lo.i1185, 4294967295
  %_14.0.i1191 = add i64 %spec.select.i1189, %t1.i1190
  %_14.1.i1192 = icmp ult i64 %_14.0.i1191, %spec.select.i1189
  %143 = add i64 %_14.0.i1191, 4294967295
  %res.sroa.0.0.i1193 = select i1 %_14.1.i1192, i64 %143, i64 %_14.0.i1191
  %_16.i1194 = icmp ugt i64 %res.sroa.0.0.i1193, -4294967296
  %_17.i1195 = add nsw i64 %res.sroa.0.0.i1193, 4294967295
  %_0.sroa.0.0.i1196 = select i1 %_16.i1194, i64 %_17.i1195, i64 %res.sroa.0.0.i1193
  %_14.i251 = zext i64 %_87.1 to i128
  %_15.i252 = zext i64 %_89.1 to i128
  %_13.i253 = mul nuw i128 %_15.i252, %_14.i251
  %x_lo.i1165 = trunc i128 %_13.i253 to i64
  %_4.i1166 = lshr i128 %_13.i253, 64
  %x_hi.i1167 = trunc nuw i128 %_4.i1166 to i64
  %x_hi_hi.i1168 = lshr i64 %x_hi.i1167, 32
  %x_hi_lo.i1169 = and i64 %x_hi.i1167, 4294967295
  %_9.0.i1170 = sub i64 %x_lo.i1165, %x_hi_hi.i1168
  %_9.1.i1171 = icmp ugt i64 %x_hi_hi.i1168, %x_lo.i1165
  %_10.i1172 = add i64 %_9.0.i1170, -4294967295
  %spec.select.i1173 = select i1 %_9.1.i1171, i64 %_10.i1172, i64 %_9.0.i1170
  %t1.i1174 = mul nuw i64 %x_hi_lo.i1169, 4294967295
  %_14.0.i1175 = add i64 %spec.select.i1173, %t1.i1174
  %_14.1.i1176 = icmp ult i64 %_14.0.i1175, %spec.select.i1173
  %144 = add i64 %_14.0.i1175, 4294967295
  %res.sroa.0.0.i1177 = select i1 %_14.1.i1176, i64 %144, i64 %_14.0.i1175
  %_16.i1178 = icmp ugt i64 %res.sroa.0.0.i1177, -4294967296
  %_17.i1179 = add nsw i64 %res.sroa.0.0.i1177, 4294967295
  %_0.sroa.0.0.i1180 = select i1 %_16.i1178, i64 %_17.i1179, i64 %res.sroa.0.0.i1177
  %_16.i255 = mul nuw i128 %_15.i252, %_11.i247
  %x_lo.i1149 = trunc i128 %_16.i255 to i64
  %_4.i1150 = lshr i128 %_16.i255, 64
  %x_hi.i1151 = trunc nuw i128 %_4.i1150 to i64
  %x_hi_hi.i1152 = lshr i64 %x_hi.i1151, 32
  %x_hi_lo.i1153 = and i64 %x_hi.i1151, 4294967295
  %_9.0.i1154 = sub i64 %x_lo.i1149, %x_hi_hi.i1152
  %_9.1.i1155 = icmp ugt i64 %x_hi_hi.i1152, %x_lo.i1149
  %_10.i1156 = add i64 %_9.0.i1154, -4294967295
  %spec.select.i1157 = select i1 %_9.1.i1155, i64 %_10.i1156, i64 %_9.0.i1154
  %t1.i1158 = mul nuw i64 %x_hi_lo.i1153, 4294967295
  %_14.0.i1159 = add i64 %spec.select.i1157, %t1.i1158
  %_14.1.i1160 = icmp ult i64 %_14.0.i1159, %spec.select.i1157
  %145 = add i64 %_14.0.i1159, 4294967295
  %res.sroa.0.0.i1161 = select i1 %_14.1.i1160, i64 %145, i64 %_14.0.i1159
  %_16.i1162 = icmp ugt i64 %res.sroa.0.0.i1161, -4294967296
  %_17.i1163 = add nsw i64 %res.sroa.0.0.i1161, 4294967295
  %_0.sroa.0.0.i1164 = select i1 %_16.i1162, i64 %_17.i1163, i64 %res.sroa.0.0.i1161
  %_17.i257 = mul nuw i128 %_12.i248, %_14.i251
  %x_lo.i1133 = trunc i128 %_17.i257 to i64
  %_4.i1134 = lshr i128 %_17.i257, 64
  %x_hi.i1135 = trunc nuw i128 %_4.i1134 to i64
  %x_hi_hi.i1136 = lshr i64 %x_hi.i1135, 32
  %x_hi_lo.i1137 = and i64 %x_hi.i1135, 4294967295
  %_9.0.i1138 = sub i64 %x_lo.i1133, %x_hi_hi.i1136
  %_9.1.i1139 = icmp ugt i64 %x_hi_hi.i1136, %x_lo.i1133
  %_10.i1140 = add i64 %_9.0.i1138, -4294967295
  %spec.select.i1141 = select i1 %_9.1.i1139, i64 %_10.i1140, i64 %_9.0.i1138
  %t1.i1142 = mul nuw i64 %x_hi_lo.i1137, 4294967295
  %_14.0.i1143 = add i64 %spec.select.i1141, %t1.i1142
  %_14.1.i1144 = icmp ult i64 %_14.0.i1143, %spec.select.i1141
  %146 = add i64 %_14.0.i1143, 4294967295
  %res.sroa.0.0.i1145 = select i1 %_14.1.i1144, i64 %146, i64 %_14.0.i1143
  %_16.i1146 = icmp ugt i64 %res.sroa.0.0.i1145, -4294967296
  %_17.i1147 = add nsw i64 %res.sroa.0.0.i1145, 4294967295
  %_0.sroa.0.0.i1148 = select i1 %_16.i1146, i64 %_17.i1147, i64 %res.sroa.0.0.i1145
  %_19.i259 = zext i64 %_0.sroa.0.0.i1180 to i128
  %_18.i260 = mul nuw nsw i128 %_19.i259, 7
  %x_lo.i1117 = trunc i128 %_18.i260 to i64
  %_4.i1118 = lshr i128 %_18.i260, 64
  %x_hi.i1119 = trunc nuw nsw i128 %_4.i1118 to i64
  %t1.i1126 = mul nuw nsw i64 %x_hi.i1119, 4294967295
  %_14.0.i1127 = add i64 %t1.i1126, %x_lo.i1117
  %_14.1.i1128 = icmp ult i64 %_14.0.i1127, %x_lo.i1117
  %147 = add i64 %_14.0.i1127, 4294967295
  %res.sroa.0.0.i1129 = select i1 %_14.1.i1128, i64 %147, i64 %_14.0.i1127
  %_16.i1130 = icmp ugt i64 %res.sroa.0.0.i1129, -4294967296
  %_17.i1131 = add nsw i64 %res.sroa.0.0.i1129, 4294967295
  %_0.sroa.0.0.i1132 = select i1 %_16.i1130, i64 %_17.i1131, i64 %res.sroa.0.0.i1129
  %_22.0.i262 = add i64 %_0.sroa.0.0.i1132, %_0.sroa.0.0.i1196
  %_22.1.i263 = icmp ult i64 %_22.0.i262, %_0.sroa.0.0.i1196
  %148 = add nuw i64 %_22.0.i262, 4294967295
  %_24.sroa.0.0.i264 = select i1 %_22.1.i263, i64 %148, i64 %_22.0.i262
  %_25.i265 = icmp ugt i64 %_24.sroa.0.0.i264, -4294967296
  %_26.i266 = add nsw i64 %_24.sroa.0.0.i264, 4294967295
  %_7.sroa.0.0.i267 = select i1 %_25.i265, i64 %_26.i266, i64 %_24.sroa.0.0.i264
  %_29.0.i268 = add i64 %_0.sroa.0.0.i1164, %_0.sroa.0.0.i1148
  %_29.1.i269 = icmp ult i64 %_29.0.i268, %_0.sroa.0.0.i1164
  %149 = add nuw i64 %_29.0.i268, 4294967295
  %_30.sroa.0.0.i270 = select i1 %_29.1.i269, i64 %149, i64 %_29.0.i268
  %_31.i271 = icmp ugt i64 %_30.sroa.0.0.i270, -4294967296
  %_32.i272 = add nsw i64 %_30.sroa.0.0.i270, 4294967295
  %_9.sroa.0.0.i273 = select i1 %_31.i271, i64 %_32.i272, i64 %_30.sroa.0.0.i270
  %_11.i220 = zext i64 %_7.sroa.0.0.i267 to i128
  %_10.i222 = mul nuw i128 %_11.i220, %_12.i302
  %x_lo.i1261 = trunc i128 %_10.i222 to i64
  %_4.i1262 = lshr i128 %_10.i222, 64
  %x_hi.i1263 = trunc nuw i128 %_4.i1262 to i64
  %x_hi_hi.i1264 = lshr i64 %x_hi.i1263, 32
  %x_hi_lo.i1265 = and i64 %x_hi.i1263, 4294967295
  %_9.0.i1266 = sub i64 %x_lo.i1261, %x_hi_hi.i1264
  %_9.1.i1267 = icmp ugt i64 %x_hi_hi.i1264, %x_lo.i1261
  %_10.i1268 = add i64 %_9.0.i1266, -4294967295
  %spec.select.i1269 = select i1 %_9.1.i1267, i64 %_10.i1268, i64 %_9.0.i1266
  %t1.i1270 = mul nuw i64 %x_hi_lo.i1265, 4294967295
  %_14.0.i1271 = add i64 %spec.select.i1269, %t1.i1270
  %_14.1.i1272 = icmp ult i64 %_14.0.i1271, %spec.select.i1269
  %150 = add i64 %_14.0.i1271, 4294967295
  %res.sroa.0.0.i1273 = select i1 %_14.1.i1272, i64 %150, i64 %_14.0.i1271
  %_16.i1274 = icmp ugt i64 %res.sroa.0.0.i1273, -4294967296
  %_17.i1275 = add nsw i64 %res.sroa.0.0.i1273, 4294967295
  %_0.sroa.0.0.i1276 = select i1 %_16.i1274, i64 %_17.i1275, i64 %res.sroa.0.0.i1273
  %_14.i224 = zext i64 %_9.sroa.0.0.i273 to i128
  %_13.i226 = mul nuw i128 %_14.i224, %_15.i306
  %x_lo.i1245 = trunc i128 %_13.i226 to i64
  %_4.i1246 = lshr i128 %_13.i226, 64
  %x_hi.i1247 = trunc nuw i128 %_4.i1246 to i64
  %x_hi_hi.i1248 = lshr i64 %x_hi.i1247, 32
  %x_hi_lo.i1249 = and i64 %x_hi.i1247, 4294967295
  %_9.0.i1250 = sub i64 %x_lo.i1245, %x_hi_hi.i1248
  %_9.1.i1251 = icmp ugt i64 %x_hi_hi.i1248, %x_lo.i1245
  %_10.i1252 = add i64 %_9.0.i1250, -4294967295
  %spec.select.i1253 = select i1 %_9.1.i1251, i64 %_10.i1252, i64 %_9.0.i1250
  %t1.i1254 = mul nuw i64 %x_hi_lo.i1249, 4294967295
  %_14.0.i1255 = add i64 %spec.select.i1253, %t1.i1254
  %_14.1.i1256 = icmp ult i64 %_14.0.i1255, %spec.select.i1253
  %151 = add i64 %_14.0.i1255, 4294967295
  %res.sroa.0.0.i1257 = select i1 %_14.1.i1256, i64 %151, i64 %_14.0.i1255
  %_16.i1258 = icmp ugt i64 %res.sroa.0.0.i1257, -4294967296
  %_17.i1259 = add nsw i64 %res.sroa.0.0.i1257, 4294967295
  %_0.sroa.0.0.i1260 = select i1 %_16.i1258, i64 %_17.i1259, i64 %res.sroa.0.0.i1257
  %_16.i228 = mul nuw i128 %_11.i220, %_15.i306
  %x_lo.i1229 = trunc i128 %_16.i228 to i64
  %_4.i1230 = lshr i128 %_16.i228, 64
  %x_hi.i1231 = trunc nuw i128 %_4.i1230 to i64
  %x_hi_hi.i1232 = lshr i64 %x_hi.i1231, 32
  %x_hi_lo.i1233 = and i64 %x_hi.i1231, 4294967295
  %_9.0.i1234 = sub i64 %x_lo.i1229, %x_hi_hi.i1232
  %_9.1.i1235 = icmp ugt i64 %x_hi_hi.i1232, %x_lo.i1229
  %_10.i1236 = add i64 %_9.0.i1234, -4294967295
  %spec.select.i1237 = select i1 %_9.1.i1235, i64 %_10.i1236, i64 %_9.0.i1234
  %t1.i1238 = mul nuw i64 %x_hi_lo.i1233, 4294967295
  %_14.0.i1239 = add i64 %spec.select.i1237, %t1.i1238
  %_14.1.i1240 = icmp ult i64 %_14.0.i1239, %spec.select.i1237
  %152 = add i64 %_14.0.i1239, 4294967295
  %res.sroa.0.0.i1241 = select i1 %_14.1.i1240, i64 %152, i64 %_14.0.i1239
  %_16.i1242 = icmp ugt i64 %res.sroa.0.0.i1241, -4294967296
  %_17.i1243 = add nsw i64 %res.sroa.0.0.i1241, 4294967295
  %_0.sroa.0.0.i1244 = select i1 %_16.i1242, i64 %_17.i1243, i64 %res.sroa.0.0.i1241
  %_17.i230 = mul nuw i128 %_14.i224, %_12.i302
  %x_lo.i1213 = trunc i128 %_17.i230 to i64
  %_4.i1214 = lshr i128 %_17.i230, 64
  %x_hi.i1215 = trunc nuw i128 %_4.i1214 to i64
  %x_hi_hi.i1216 = lshr i64 %x_hi.i1215, 32
  %x_hi_lo.i1217 = and i64 %x_hi.i1215, 4294967295
  %_9.0.i1218 = sub i64 %x_lo.i1213, %x_hi_hi.i1216
  %_9.1.i1219 = icmp ugt i64 %x_hi_hi.i1216, %x_lo.i1213
  %_10.i1220 = add i64 %_9.0.i1218, -4294967295
  %spec.select.i1221 = select i1 %_9.1.i1219, i64 %_10.i1220, i64 %_9.0.i1218
  %t1.i1222 = mul nuw i64 %x_hi_lo.i1217, 4294967295
  %_14.0.i1223 = add i64 %spec.select.i1221, %t1.i1222
  %_14.1.i1224 = icmp ult i64 %_14.0.i1223, %spec.select.i1221
  %153 = add i64 %_14.0.i1223, 4294967295
  %res.sroa.0.0.i1225 = select i1 %_14.1.i1224, i64 %153, i64 %_14.0.i1223
  %_16.i1226 = icmp ugt i64 %res.sroa.0.0.i1225, -4294967296
  %_17.i1227 = add nsw i64 %res.sroa.0.0.i1225, 4294967295
  %_0.sroa.0.0.i1228 = select i1 %_16.i1226, i64 %_17.i1227, i64 %res.sroa.0.0.i1225
  %_19.i232 = zext i64 %_0.sroa.0.0.i1260 to i128
  %_18.i233 = mul nuw nsw i128 %_19.i232, 7
  %x_lo.i1197 = trunc i128 %_18.i233 to i64
  %_4.i1198 = lshr i128 %_18.i233, 64
  %x_hi.i1199 = trunc nuw nsw i128 %_4.i1198 to i64
  %t1.i1206 = mul nuw nsw i64 %x_hi.i1199, 4294967295
  %_14.0.i1207 = add i64 %t1.i1206, %x_lo.i1197
  %_14.1.i1208 = icmp ult i64 %_14.0.i1207, %x_lo.i1197
  %154 = add i64 %_14.0.i1207, 4294967295
  %res.sroa.0.0.i1209 = select i1 %_14.1.i1208, i64 %154, i64 %_14.0.i1207
  %_16.i1210 = icmp ugt i64 %res.sroa.0.0.i1209, -4294967296
  %_17.i1211 = add nsw i64 %res.sroa.0.0.i1209, 4294967295
  %_0.sroa.0.0.i1212 = select i1 %_16.i1210, i64 %_17.i1211, i64 %res.sroa.0.0.i1209
  %_22.0.i235 = add i64 %_0.sroa.0.0.i1276, %_0.sroa.0.0.i1212
  %_22.1.i236 = icmp ult i64 %_22.0.i235, %_0.sroa.0.0.i1276
  %155 = add nuw i64 %_22.0.i235, 4294967295
  %_24.sroa.0.0.i237 = select i1 %_22.1.i236, i64 %155, i64 %_22.0.i235
  %_25.i238 = icmp ugt i64 %_24.sroa.0.0.i237, -4294967296
  %_26.i239 = add nsw i64 %_24.sroa.0.0.i237, 4294967295
  %_7.sroa.0.0.i240 = select i1 %_25.i238, i64 %_26.i239, i64 %_24.sroa.0.0.i237
  %_29.0.i241 = add i64 %_0.sroa.0.0.i1244, %_0.sroa.0.0.i1228
  %_29.1.i242 = icmp ult i64 %_29.0.i241, %_0.sroa.0.0.i1244
  %156 = add nuw i64 %_29.0.i241, 4294967295
  %_30.sroa.0.0.i243 = select i1 %_29.1.i242, i64 %156, i64 %_29.0.i241
  %_31.i244 = icmp ugt i64 %_30.sroa.0.0.i243, -4294967296
  %_32.i245 = add nsw i64 %_30.sroa.0.0.i243, 4294967295
  %_9.sroa.0.0.i246 = select i1 %_31.i244, i64 %_32.i245, i64 %_30.sroa.0.0.i243
  %_11.i198 = zext i64 %_7.sroa.0.0.i240 to i128
  %_10.i200 = mul nuw i128 %_11.i198, %_12.i464
  %x_lo.i1341 = trunc i128 %_10.i200 to i64
  %_4.i1342 = lshr i128 %_10.i200, 64
  %x_hi.i1343 = trunc nuw i128 %_4.i1342 to i64
  %x_hi_hi.i1344 = lshr i64 %x_hi.i1343, 32
  %x_hi_lo.i1345 = and i64 %x_hi.i1343, 4294967295
  %_9.0.i1346 = sub i64 %x_lo.i1341, %x_hi_hi.i1344
  %_9.1.i1347 = icmp ugt i64 %x_hi_hi.i1344, %x_lo.i1341
  %_10.i1348 = add i64 %_9.0.i1346, -4294967295
  %spec.select.i1349 = select i1 %_9.1.i1347, i64 %_10.i1348, i64 %_9.0.i1346
  %t1.i1350 = mul nuw i64 %x_hi_lo.i1345, 4294967295
  %_14.0.i1351 = add i64 %spec.select.i1349, %t1.i1350
  %_14.1.i1352 = icmp ult i64 %_14.0.i1351, %spec.select.i1349
  %157 = add i64 %_14.0.i1351, 4294967295
  %res.sroa.0.0.i1353 = select i1 %_14.1.i1352, i64 %157, i64 %_14.0.i1351
  %_16.i1354 = icmp ugt i64 %res.sroa.0.0.i1353, -4294967296
  %_17.i1355 = add nsw i64 %res.sroa.0.0.i1353, 4294967295
  %_0.sroa.0.0.i1356 = select i1 %_16.i1354, i64 %_17.i1355, i64 %res.sroa.0.0.i1353
  %_14.i201 = zext i64 %_9.sroa.0.0.i246 to i128
  %_13.i203 = mul nuw i128 %_14.i201, %_15.i468
  %x_lo.i1325 = trunc i128 %_13.i203 to i64
  %_4.i1326 = lshr i128 %_13.i203, 64
  %x_hi.i1327 = trunc nuw i128 %_4.i1326 to i64
  %x_hi_hi.i1328 = lshr i64 %x_hi.i1327, 32
  %x_hi_lo.i1329 = and i64 %x_hi.i1327, 4294967295
  %_9.0.i1330 = sub i64 %x_lo.i1325, %x_hi_hi.i1328
  %_9.1.i1331 = icmp ugt i64 %x_hi_hi.i1328, %x_lo.i1325
  %_10.i1332 = add i64 %_9.0.i1330, -4294967295
  %spec.select.i1333 = select i1 %_9.1.i1331, i64 %_10.i1332, i64 %_9.0.i1330
  %t1.i1334 = mul nuw i64 %x_hi_lo.i1329, 4294967295
  %_14.0.i1335 = add i64 %spec.select.i1333, %t1.i1334
  %_14.1.i1336 = icmp ult i64 %_14.0.i1335, %spec.select.i1333
  %158 = add i64 %_14.0.i1335, 4294967295
  %res.sroa.0.0.i1337 = select i1 %_14.1.i1336, i64 %158, i64 %_14.0.i1335
  %_16.i1338 = icmp ugt i64 %res.sroa.0.0.i1337, -4294967296
  %_17.i1339 = add nsw i64 %res.sroa.0.0.i1337, 4294967295
  %_0.sroa.0.0.i1340 = select i1 %_16.i1338, i64 %_17.i1339, i64 %res.sroa.0.0.i1337
  %_16.i204 = mul nuw i128 %_11.i198, %_15.i468
  %x_lo.i1309 = trunc i128 %_16.i204 to i64
  %_4.i1310 = lshr i128 %_16.i204, 64
  %x_hi.i1311 = trunc nuw i128 %_4.i1310 to i64
  %x_hi_hi.i1312 = lshr i64 %x_hi.i1311, 32
  %x_hi_lo.i1313 = and i64 %x_hi.i1311, 4294967295
  %_9.0.i1314 = sub i64 %x_lo.i1309, %x_hi_hi.i1312
  %_9.1.i1315 = icmp ugt i64 %x_hi_hi.i1312, %x_lo.i1309
  %_10.i1316 = add i64 %_9.0.i1314, -4294967295
  %spec.select.i1317 = select i1 %_9.1.i1315, i64 %_10.i1316, i64 %_9.0.i1314
  %t1.i1318 = mul nuw i64 %x_hi_lo.i1313, 4294967295
  %_14.0.i1319 = add i64 %spec.select.i1317, %t1.i1318
  %_14.1.i1320 = icmp ult i64 %_14.0.i1319, %spec.select.i1317
  %159 = add i64 %_14.0.i1319, 4294967295
  %res.sroa.0.0.i1321 = select i1 %_14.1.i1320, i64 %159, i64 %_14.0.i1319
  %_16.i1322 = icmp ugt i64 %res.sroa.0.0.i1321, -4294967296
  %_17.i1323 = add nsw i64 %res.sroa.0.0.i1321, 4294967295
  %_0.sroa.0.0.i1324 = select i1 %_16.i1322, i64 %_17.i1323, i64 %res.sroa.0.0.i1321
  %_17.i205 = mul nuw i128 %_14.i201, %_12.i464
  %x_lo.i1293 = trunc i128 %_17.i205 to i64
  %_4.i1294 = lshr i128 %_17.i205, 64
  %x_hi.i1295 = trunc nuw i128 %_4.i1294 to i64
  %x_hi_hi.i1296 = lshr i64 %x_hi.i1295, 32
  %x_hi_lo.i1297 = and i64 %x_hi.i1295, 4294967295
  %_9.0.i1298 = sub i64 %x_lo.i1293, %x_hi_hi.i1296
  %_9.1.i1299 = icmp ugt i64 %x_hi_hi.i1296, %x_lo.i1293
  %_10.i1300 = add i64 %_9.0.i1298, -4294967295
  %spec.select.i1301 = select i1 %_9.1.i1299, i64 %_10.i1300, i64 %_9.0.i1298
  %t1.i1302 = mul nuw i64 %x_hi_lo.i1297, 4294967295
  %_14.0.i1303 = add i64 %spec.select.i1301, %t1.i1302
  %_14.1.i1304 = icmp ult i64 %_14.0.i1303, %spec.select.i1301
  %160 = add i64 %_14.0.i1303, 4294967295
  %res.sroa.0.0.i1305 = select i1 %_14.1.i1304, i64 %160, i64 %_14.0.i1303
  %_16.i1306 = icmp ugt i64 %res.sroa.0.0.i1305, -4294967296
  %_17.i1307 = add nsw i64 %res.sroa.0.0.i1305, 4294967295
  %_0.sroa.0.0.i1308 = select i1 %_16.i1306, i64 %_17.i1307, i64 %res.sroa.0.0.i1305
  %_19.i206 = zext i64 %_0.sroa.0.0.i1340 to i128
  %_18.i207 = mul nuw nsw i128 %_19.i206, 7
  %x_lo.i1277 = trunc i128 %_18.i207 to i64
  %_4.i1278 = lshr i128 %_18.i207, 64
  %x_hi.i1279 = trunc nuw nsw i128 %_4.i1278 to i64
  %t1.i1286 = mul nuw nsw i64 %x_hi.i1279, 4294967295
  %_14.0.i1287 = add i64 %t1.i1286, %x_lo.i1277
  %_14.1.i1288 = icmp ult i64 %_14.0.i1287, %x_lo.i1277
  %161 = add i64 %_14.0.i1287, 4294967295
  %res.sroa.0.0.i1289 = select i1 %_14.1.i1288, i64 %161, i64 %_14.0.i1287
  %_16.i1290 = icmp ugt i64 %res.sroa.0.0.i1289, -4294967296
  %_17.i1291 = add nsw i64 %res.sroa.0.0.i1289, 4294967295
  %_0.sroa.0.0.i1292 = select i1 %_16.i1290, i64 %_17.i1291, i64 %res.sroa.0.0.i1289
  %_22.0.i208 = add i64 %_0.sroa.0.0.i1292, %_0.sroa.0.0.i1356
  %_22.1.i209 = icmp ult i64 %_22.0.i208, %_0.sroa.0.0.i1356
  %162 = add nuw i64 %_22.0.i208, 4294967295
  %_24.sroa.0.0.i210 = select i1 %_22.1.i209, i64 %162, i64 %_22.0.i208
  %_25.i211 = icmp ugt i64 %_24.sroa.0.0.i210, -4294967296
  %_26.i212 = add nsw i64 %_24.sroa.0.0.i210, 4294967295
  %_7.sroa.0.0.i213 = select i1 %_25.i211, i64 %_26.i212, i64 %_24.sroa.0.0.i210
  %_29.0.i214 = add i64 %_0.sroa.0.0.i1324, %_0.sroa.0.0.i1308
  %_29.1.i215 = icmp ult i64 %_29.0.i214, %_0.sroa.0.0.i1324
  %163 = add nuw i64 %_29.0.i214, 4294967295
  %_30.sroa.0.0.i216 = select i1 %_29.1.i215, i64 %163, i64 %_29.0.i214
  %_31.i217 = icmp ugt i64 %_30.sroa.0.0.i216, -4294967296
  %_32.i218 = add nsw i64 %_30.sroa.0.0.i216, 4294967295
  %_9.sroa.0.0.i219 = select i1 %_31.i217, i64 %_32.i218, i64 %_30.sroa.0.0.i216
  %_7.0.i26 = add i64 %_7.sroa.0.0.i213, %_3.sroa.0.0.i43
  %_7.1.i27 = icmp ult i64 %_7.0.i26, %_3.sroa.0.0.i43
  %164 = add i64 %_7.0.i26, 4294967295
  %_8.sroa.0.0.i28 = select i1 %_7.1.i27, i64 %164, i64 %_7.0.i26
  %_9.i29 = icmp ugt i64 %_8.sroa.0.0.i28, -4294967296
  %_10.i30 = add nsw i64 %_8.sroa.0.0.i28, 4294967295
  %_3.sroa.0.0.i31 = select i1 %_9.i29, i64 %_10.i30, i64 %_8.sroa.0.0.i28
  %_13.0.i32 = add i64 %_9.sroa.0.0.i219, %_4.sroa.0.0.i49
  %_13.1.i33 = icmp ult i64 %_13.0.i32, %_4.sroa.0.0.i49
  %165 = add i64 %_13.0.i32, 4294967295
  %_14.sroa.0.0.i34 = select i1 %_13.1.i33, i64 %165, i64 %_13.0.i32
  %_15.i35 = icmp ugt i64 %_14.sroa.0.0.i34, -4294967296
  %_16.i36 = add nsw i64 %_14.sroa.0.0.i34, 4294967295
  %_4.sroa.0.0.i37 = select i1 %_15.i35, i64 %_16.i36, i64 %_14.sroa.0.0.i34
  %166 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i31, 0
  %167 = insertvalue { i64, i64 } %166, i64 %_4.sroa.0.0.i37, 1
  call void @llvm.lifetime.end.p0(ptr nonnull %at)
  ret { i64, i64 } %167

panic17:                                          ; preds = %bb105
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 2, i64 noundef 2, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_89fc8f3b37234d0552cb47d22f5f3be5) #21
  unreachable

bb26:                                             ; preds = %bb9.i
  %_16.i.i = getelementptr inbounds nuw i8, ptr %ptr.i.i15881605, i64 16
  %_11.i.i.i = add nuw nsw i64 %_10.i.i.i15901604, 1
  %self3.i.i.i = getelementptr inbounds nuw %"core::mem::maybe_uninit::MaybeUninit<field::Fp2>", ptr %_54.sroa.5.0.iter.sroa_idx, i64 %_10.i.i.i15901604
  %_14.0.i.i.i = load i64, ptr %self3.i.i.i, align 8, !alias.scope !69, !noalias !76, !noundef !3
  %168 = getelementptr inbounds nuw i8, ptr %self3.i.i.i, i64 8
  %_14.1.i.i.i = load i64, ptr %168, align 8, !alias.scope !69, !noalias !76, !noundef !3
  %_66.0 = load i64, ptr %ptr.i.i15881605, align 8, !noundef !3
  %169 = getelementptr inbounds nuw i8, ptr %ptr.i.i15881605, i64 8
  %_66.1 = load i64, ptr %169, align 8, !noundef !3
  %_11.i166 = zext i64 %_66.0 to i128
  %_10.i168 = mul nuw i128 %_11.i166, %_12.i167
  %x_lo.i1421 = trunc i128 %_10.i168 to i64
  %_4.i1422 = lshr i128 %_10.i168, 64
  %x_hi.i1423 = trunc nuw i128 %_4.i1422 to i64
  %x_hi_hi.i1424 = lshr i64 %x_hi.i1423, 32
  %x_hi_lo.i1425 = and i64 %x_hi.i1423, 4294967295
  %_9.0.i1426 = sub i64 %x_lo.i1421, %x_hi_hi.i1424
  %_9.1.i1427 = icmp ugt i64 %x_hi_hi.i1424, %x_lo.i1421
  %_10.i1428 = add i64 %_9.0.i1426, -4294967295
  %spec.select.i1429 = select i1 %_9.1.i1427, i64 %_10.i1428, i64 %_9.0.i1426
  %t1.i1430 = mul nuw i64 %x_hi_lo.i1425, 4294967295
  %_14.0.i1431 = add i64 %spec.select.i1429, %t1.i1430
  %_14.1.i1432 = icmp ult i64 %_14.0.i1431, %spec.select.i1429
  %170 = add i64 %_14.0.i1431, 4294967295
  %res.sroa.0.0.i1433 = select i1 %_14.1.i1432, i64 %170, i64 %_14.0.i1431
  %_16.i1434 = icmp ugt i64 %res.sroa.0.0.i1433, -4294967296
  %_17.i1435 = add nsw i64 %res.sroa.0.0.i1433, 4294967295
  %_0.sroa.0.0.i1436 = select i1 %_16.i1434, i64 %_17.i1435, i64 %res.sroa.0.0.i1433
  %_14.i169 = zext i64 %_66.1 to i128
  %_13.i171 = mul nuw i128 %_14.i169, %_15.i170
  %x_lo.i1405 = trunc i128 %_13.i171 to i64
  %_4.i1406 = lshr i128 %_13.i171, 64
  %x_hi.i1407 = trunc nuw i128 %_4.i1406 to i64
  %x_hi_hi.i1408 = lshr i64 %x_hi.i1407, 32
  %x_hi_lo.i1409 = and i64 %x_hi.i1407, 4294967295
  %_9.0.i1410 = sub i64 %x_lo.i1405, %x_hi_hi.i1408
  %_9.1.i1411 = icmp ugt i64 %x_hi_hi.i1408, %x_lo.i1405
  %_10.i1412 = add i64 %_9.0.i1410, -4294967295
  %spec.select.i1413 = select i1 %_9.1.i1411, i64 %_10.i1412, i64 %_9.0.i1410
  %t1.i1414 = mul nuw i64 %x_hi_lo.i1409, 4294967295
  %_14.0.i1415 = add i64 %spec.select.i1413, %t1.i1414
  %_14.1.i1416 = icmp ult i64 %_14.0.i1415, %spec.select.i1413
  %171 = add i64 %_14.0.i1415, 4294967295
  %res.sroa.0.0.i1417 = select i1 %_14.1.i1416, i64 %171, i64 %_14.0.i1415
  %_16.i1418 = icmp ugt i64 %res.sroa.0.0.i1417, -4294967296
  %_17.i1419 = add nsw i64 %res.sroa.0.0.i1417, 4294967295
  %_0.sroa.0.0.i1420 = select i1 %_16.i1418, i64 %_17.i1419, i64 %res.sroa.0.0.i1417
  %_16.i172 = mul nuw i128 %_11.i166, %_15.i170
  %x_lo.i1389 = trunc i128 %_16.i172 to i64
  %_4.i1390 = lshr i128 %_16.i172, 64
  %x_hi.i1391 = trunc nuw i128 %_4.i1390 to i64
  %x_hi_hi.i1392 = lshr i64 %x_hi.i1391, 32
  %x_hi_lo.i1393 = and i64 %x_hi.i1391, 4294967295
  %_9.0.i1394 = sub i64 %x_lo.i1389, %x_hi_hi.i1392
  %_9.1.i1395 = icmp ugt i64 %x_hi_hi.i1392, %x_lo.i1389
  %_10.i1396 = add i64 %_9.0.i1394, -4294967295
  %spec.select.i1397 = select i1 %_9.1.i1395, i64 %_10.i1396, i64 %_9.0.i1394
  %t1.i1398 = mul nuw i64 %x_hi_lo.i1393, 4294967295
  %_14.0.i1399 = add i64 %spec.select.i1397, %t1.i1398
  %_14.1.i1400 = icmp ult i64 %_14.0.i1399, %spec.select.i1397
  %172 = add i64 %_14.0.i1399, 4294967295
  %res.sroa.0.0.i1401 = select i1 %_14.1.i1400, i64 %172, i64 %_14.0.i1399
  %_16.i1402 = icmp ugt i64 %res.sroa.0.0.i1401, -4294967296
  %_17.i1403 = add nsw i64 %res.sroa.0.0.i1401, 4294967295
  %_0.sroa.0.0.i1404 = select i1 %_16.i1402, i64 %_17.i1403, i64 %res.sroa.0.0.i1401
  %_17.i173 = mul nuw i128 %_14.i169, %_12.i167
  %x_lo.i1373 = trunc i128 %_17.i173 to i64
  %_4.i1374 = lshr i128 %_17.i173, 64
  %x_hi.i1375 = trunc nuw i128 %_4.i1374 to i64
  %x_hi_hi.i1376 = lshr i64 %x_hi.i1375, 32
  %x_hi_lo.i1377 = and i64 %x_hi.i1375, 4294967295
  %_9.0.i1378 = sub i64 %x_lo.i1373, %x_hi_hi.i1376
  %_9.1.i1379 = icmp ugt i64 %x_hi_hi.i1376, %x_lo.i1373
  %_10.i1380 = add i64 %_9.0.i1378, -4294967295
  %spec.select.i1381 = select i1 %_9.1.i1379, i64 %_10.i1380, i64 %_9.0.i1378
  %t1.i1382 = mul nuw i64 %x_hi_lo.i1377, 4294967295
  %_14.0.i1383 = add i64 %spec.select.i1381, %t1.i1382
  %_14.1.i1384 = icmp ult i64 %_14.0.i1383, %spec.select.i1381
  %173 = add i64 %_14.0.i1383, 4294967295
  %res.sroa.0.0.i1385 = select i1 %_14.1.i1384, i64 %173, i64 %_14.0.i1383
  %_16.i1386 = icmp ugt i64 %res.sroa.0.0.i1385, -4294967296
  %_17.i1387 = add nsw i64 %res.sroa.0.0.i1385, 4294967295
  %_0.sroa.0.0.i1388 = select i1 %_16.i1386, i64 %_17.i1387, i64 %res.sroa.0.0.i1385
  %_19.i174 = zext i64 %_0.sroa.0.0.i1420 to i128
  %_18.i175 = mul nuw nsw i128 %_19.i174, 7
  %x_lo.i1357 = trunc i128 %_18.i175 to i64
  %_4.i1358 = lshr i128 %_18.i175, 64
  %x_hi.i1359 = trunc nuw nsw i128 %_4.i1358 to i64
  %t1.i1366 = mul nuw nsw i64 %x_hi.i1359, 4294967295
  %_14.0.i1367 = add i64 %t1.i1366, %x_lo.i1357
  %_14.1.i1368 = icmp ult i64 %_14.0.i1367, %x_lo.i1357
  %174 = add i64 %_14.0.i1367, 4294967295
  %res.sroa.0.0.i1369 = select i1 %_14.1.i1368, i64 %174, i64 %_14.0.i1367
  %_16.i1370 = icmp ugt i64 %res.sroa.0.0.i1369, -4294967296
  %_17.i1371 = add nsw i64 %res.sroa.0.0.i1369, 4294967295
  %_0.sroa.0.0.i1372 = select i1 %_16.i1370, i64 %_17.i1371, i64 %res.sroa.0.0.i1369
  %_22.0.i176 = add i64 %_0.sroa.0.0.i1372, %_0.sroa.0.0.i1436
  %_22.1.i177 = icmp ult i64 %_22.0.i176, %_0.sroa.0.0.i1436
  %175 = add nuw i64 %_22.0.i176, 4294967295
  %_24.sroa.0.0.i178 = select i1 %_22.1.i177, i64 %175, i64 %_22.0.i176
  %_25.i179 = icmp ugt i64 %_24.sroa.0.0.i178, -4294967296
  %_26.i180 = add nsw i64 %_24.sroa.0.0.i178, 4294967295
  %_7.sroa.0.0.i181 = select i1 %_25.i179, i64 %_26.i180, i64 %_24.sroa.0.0.i178
  %_29.0.i182 = add i64 %_0.sroa.0.0.i1388, %_0.sroa.0.0.i1404
  %_29.1.i183 = icmp ult i64 %_29.0.i182, %_0.sroa.0.0.i1404
  %176 = add nuw i64 %_29.0.i182, 4294967295
  %_30.sroa.0.0.i184 = select i1 %_29.1.i183, i64 %176, i64 %_29.0.i182
  %_31.i185 = icmp ugt i64 %_30.sroa.0.0.i184, -4294967296
  %_32.i186 = add nsw i64 %_30.sroa.0.0.i184, 4294967295
  %_9.sroa.0.0.i187 = select i1 %_31.i185, i64 %_32.i186, i64 %_30.sroa.0.0.i184
  %_11.i = zext i64 %_7.sroa.0.0.i181 to i128
  %_12.i = zext i64 %_14.0.i.i.i to i128
  %_10.i158 = mul nuw i128 %_11.i, %_12.i
  %x_lo.i1501 = trunc i128 %_10.i158 to i64
  %_4.i1502 = lshr i128 %_10.i158, 64
  %x_hi.i1503 = trunc nuw i128 %_4.i1502 to i64
  %x_hi_hi.i1504 = lshr i64 %x_hi.i1503, 32
  %x_hi_lo.i1505 = and i64 %x_hi.i1503, 4294967295
  %_9.0.i1506 = sub i64 %x_lo.i1501, %x_hi_hi.i1504
  %_9.1.i1507 = icmp ugt i64 %x_hi_hi.i1504, %x_lo.i1501
  %_10.i1508 = add i64 %_9.0.i1506, -4294967295
  %spec.select.i1509 = select i1 %_9.1.i1507, i64 %_10.i1508, i64 %_9.0.i1506
  %t1.i1510 = mul nuw i64 %x_hi_lo.i1505, 4294967295
  %_14.0.i1511 = add i64 %spec.select.i1509, %t1.i1510
  %_14.1.i1512 = icmp ult i64 %_14.0.i1511, %spec.select.i1509
  %177 = add i64 %_14.0.i1511, 4294967295
  %res.sroa.0.0.i1513 = select i1 %_14.1.i1512, i64 %177, i64 %_14.0.i1511
  %_16.i1514 = icmp ugt i64 %res.sroa.0.0.i1513, -4294967296
  %_17.i1515 = add nsw i64 %res.sroa.0.0.i1513, 4294967295
  %_0.sroa.0.0.i1516 = select i1 %_16.i1514, i64 %_17.i1515, i64 %res.sroa.0.0.i1513
  %_14.i = zext i64 %_9.sroa.0.0.i187 to i128
  %_15.i159 = zext i64 %_14.1.i.i.i to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i159
  %x_lo.i1485 = trunc i128 %_13.i to i64
  %_4.i1486 = lshr i128 %_13.i, 64
  %x_hi.i1487 = trunc nuw i128 %_4.i1486 to i64
  %x_hi_hi.i1488 = lshr i64 %x_hi.i1487, 32
  %x_hi_lo.i1489 = and i64 %x_hi.i1487, 4294967295
  %_9.0.i1490 = sub i64 %x_lo.i1485, %x_hi_hi.i1488
  %_9.1.i1491 = icmp ugt i64 %x_hi_hi.i1488, %x_lo.i1485
  %_10.i1492 = add i64 %_9.0.i1490, -4294967295
  %spec.select.i1493 = select i1 %_9.1.i1491, i64 %_10.i1492, i64 %_9.0.i1490
  %t1.i1494 = mul nuw i64 %x_hi_lo.i1489, 4294967295
  %_14.0.i1495 = add i64 %spec.select.i1493, %t1.i1494
  %_14.1.i1496 = icmp ult i64 %_14.0.i1495, %spec.select.i1493
  %178 = add i64 %_14.0.i1495, 4294967295
  %res.sroa.0.0.i1497 = select i1 %_14.1.i1496, i64 %178, i64 %_14.0.i1495
  %_16.i1498 = icmp ugt i64 %res.sroa.0.0.i1497, -4294967296
  %_17.i1499 = add nsw i64 %res.sroa.0.0.i1497, 4294967295
  %_0.sroa.0.0.i1500 = select i1 %_16.i1498, i64 %_17.i1499, i64 %res.sroa.0.0.i1497
  %_16.i160 = mul nuw i128 %_11.i, %_15.i159
  %x_lo.i1469 = trunc i128 %_16.i160 to i64
  %_4.i1470 = lshr i128 %_16.i160, 64
  %x_hi.i1471 = trunc nuw i128 %_4.i1470 to i64
  %x_hi_hi.i1472 = lshr i64 %x_hi.i1471, 32
  %x_hi_lo.i1473 = and i64 %x_hi.i1471, 4294967295
  %_9.0.i1474 = sub i64 %x_lo.i1469, %x_hi_hi.i1472
  %_9.1.i1475 = icmp ugt i64 %x_hi_hi.i1472, %x_lo.i1469
  %_10.i1476 = add i64 %_9.0.i1474, -4294967295
  %spec.select.i1477 = select i1 %_9.1.i1475, i64 %_10.i1476, i64 %_9.0.i1474
  %t1.i1478 = mul nuw i64 %x_hi_lo.i1473, 4294967295
  %_14.0.i1479 = add i64 %spec.select.i1477, %t1.i1478
  %_14.1.i1480 = icmp ult i64 %_14.0.i1479, %spec.select.i1477
  %179 = add i64 %_14.0.i1479, 4294967295
  %res.sroa.0.0.i1481 = select i1 %_14.1.i1480, i64 %179, i64 %_14.0.i1479
  %_16.i1482 = icmp ugt i64 %res.sroa.0.0.i1481, -4294967296
  %_17.i1483 = add nsw i64 %res.sroa.0.0.i1481, 4294967295
  %_0.sroa.0.0.i1484 = select i1 %_16.i1482, i64 %_17.i1483, i64 %res.sroa.0.0.i1481
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i1453 = trunc i128 %_17.i to i64
  %_4.i1454 = lshr i128 %_17.i, 64
  %x_hi.i1455 = trunc nuw i128 %_4.i1454 to i64
  %x_hi_hi.i1456 = lshr i64 %x_hi.i1455, 32
  %x_hi_lo.i1457 = and i64 %x_hi.i1455, 4294967295
  %_9.0.i1458 = sub i64 %x_lo.i1453, %x_hi_hi.i1456
  %_9.1.i1459 = icmp ugt i64 %x_hi_hi.i1456, %x_lo.i1453
  %_10.i1460 = add i64 %_9.0.i1458, -4294967295
  %spec.select.i1461 = select i1 %_9.1.i1459, i64 %_10.i1460, i64 %_9.0.i1458
  %t1.i1462 = mul nuw i64 %x_hi_lo.i1457, 4294967295
  %_14.0.i1463 = add i64 %spec.select.i1461, %t1.i1462
  %_14.1.i1464 = icmp ult i64 %_14.0.i1463, %spec.select.i1461
  %180 = add i64 %_14.0.i1463, 4294967295
  %res.sroa.0.0.i1465 = select i1 %_14.1.i1464, i64 %180, i64 %_14.0.i1463
  %_16.i1466 = icmp ugt i64 %res.sroa.0.0.i1465, -4294967296
  %_17.i1467 = add nsw i64 %res.sroa.0.0.i1465, 4294967295
  %_0.sroa.0.0.i1468 = select i1 %_16.i1466, i64 %_17.i1467, i64 %res.sroa.0.0.i1465
  %_19.i = zext i64 %_0.sroa.0.0.i1500 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i1437 = trunc i128 %_18.i to i64
  %_4.i1438 = lshr i128 %_18.i, 64
  %x_hi.i1439 = trunc nuw nsw i128 %_4.i1438 to i64
  %t1.i1446 = mul nuw nsw i64 %x_hi.i1439, 4294967295
  %_14.0.i1447 = add i64 %t1.i1446, %x_lo.i1437
  %_14.1.i1448 = icmp ult i64 %_14.0.i1447, %x_lo.i1437
  %181 = add i64 %_14.0.i1447, 4294967295
  %res.sroa.0.0.i1449 = select i1 %_14.1.i1448, i64 %181, i64 %_14.0.i1447
  %_16.i1450 = icmp ugt i64 %res.sroa.0.0.i1449, -4294967296
  %_17.i1451 = add nsw i64 %res.sroa.0.0.i1449, 4294967295
  %_0.sroa.0.0.i1452 = select i1 %_16.i1450, i64 %_17.i1451, i64 %res.sroa.0.0.i1449
  %_22.0.i = add i64 %_0.sroa.0.0.i1516, %_0.sroa.0.0.i1452
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i1516
  %182 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %182, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i1484, %_0.sroa.0.0.i1468
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i1484
  %183 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %183, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %_3.sroa.0.0.i67.pn1606
  %_7.1.i = icmp ult i64 %_7.0.i, %_3.sroa.0.0.i67.pn1606
  %184 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %184, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %_4.sroa.0.0.i73.pn1607
  %_13.1.i = icmp ult i64 %_13.0.i, %_4.sroa.0.0.i73.pn1607
  %185 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %185, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %_6.i.i = icmp eq ptr %_16.i.i, %_214
  br i1 %_6.i.i, label %bb23, label %bb9.i
}

; isolated::factory_2::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(296) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
  %iter = alloca [96 x i8], align 8
  %at = alloca [24 x i8], align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %at)
  %_4 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  store ptr %v.0, ptr %at, align 8
  %0 = getelementptr inbounds nuw i8, ptr %at, i64 8
  store i64 %v.1, ptr %0, align 8
  %1 = getelementptr inbounds nuw i8, ptr %at, i64 16
  store ptr %_4, ptr %1, align 8
  %_7 = getelementptr inbounds nuw i8, ptr %_1, i64 152
  %2 = getelementptr inbounds nuw i8, ptr %_1, i64 24
  %_103 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_1, i64 32
  %_102 = load i64, ptr %3, align 8, !noundef !3
  %_104 = icmp ugt i64 %_102, 67
  br i1 %_104, label %bb47, label %panic

bb47:                                             ; preds = %start
  %_97 = getelementptr inbounds nuw i8, ptr %_103, i64 536
  %_96 = load i64, ptr %_97, align 8, !noundef !3
  %_99 = icmp ult i64 %_96, %v.1
  br i1 %_99, label %bb46, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 67, i64 noundef %_102, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_623270749f7c2c7eb7abf12a5ce81bec) #21
  unreachable

bb46:                                             ; preds = %bb47
  %4 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_96
  %g8.0 = load i64, ptr %4, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 8
  %g8.1 = load i64, ptr %5, align 8, !noundef !3
  %_108 = icmp ugt i64 %_102, 69
  br i1 %_108, label %bb49, label %panic2

panic1:                                           ; preds = %bb47
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_96, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable

bb49:                                             ; preds = %bb46
  %_106 = getelementptr inbounds nuw i8, ptr %_103, i64 552
  %_105 = load i64, ptr %_106, align 8, !noundef !3
  %_107 = icmp ult i64 %_105, %v.1
  br i1 %_107, label %bb48, label %panic3

panic2:                                           ; preds = %bb46
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 69, i64 noundef %_102, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_623270749f7c2c7eb7abf12a5ce81bec) #21
  unreachable

bb48:                                             ; preds = %bb49
  %6 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_105
  %a16.0 = load i64, ptr %6, align 8, !noundef !3
  %7 = getelementptr inbounds nuw i8, ptr %6, i64 8
  %a16.1 = load i64, ptr %7, align 8, !noundef !3
  %_112.not = icmp eq i64 %_102, 70
  br i1 %_112.not, label %panic4, label %bb51

panic3:                                           ; preds = %bb49
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_105, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable

bb51:                                             ; preds = %bb48
  %_110 = getelementptr inbounds nuw i8, ptr %_103, i64 560
  %_109 = load i64, ptr %_110, align 8, !noundef !3
  %_111 = icmp ult i64 %_109, %v.1
  br i1 %_111, label %bb50, label %panic5

panic4:                                           ; preds = %bb48
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 70, i64 noundef 70, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_623270749f7c2c7eb7abf12a5ce81bec) #21
  unreachable

bb50:                                             ; preds = %bb51
  %8 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_109
  %u16.0 = load i64, ptr %8, align 8, !noundef !3
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 8
  %u16.1 = load i64, ptr %9, align 8, !noundef !3
  %_116 = icmp ugt i64 %_102, 73
  br i1 %_116, label %bb53, label %panic6

panic5:                                           ; preds = %bb51
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_109, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable

bb53:                                             ; preds = %bb50
  %_114 = getelementptr inbounds nuw i8, ptr %_103, i64 584
  %_113 = load i64, ptr %_114, align 8, !noundef !3
  %_115 = icmp ult i64 %_113, %v.1
  br i1 %_115, label %bb52, label %panic7

panic6:                                           ; preds = %bb50
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 73, i64 noundef %_102, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_623270749f7c2c7eb7abf12a5ce81bec) #21
  unreachable

bb52:                                             ; preds = %bb53
  %10 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_113
  %h16.0 = load i64, ptr %10, align 8, !noundef !3
  %11 = getelementptr inbounds nuw i8, ptr %10, i64 8
  %h16.1 = load i64, ptr %11, align 8, !noundef !3
  %_11.i525 = zext i64 %a16.0 to i128
  %_12.i526 = zext i64 %u16.0 to i128
  %_10.i527 = mul nuw i128 %_12.i526, %_11.i525
  %x_lo.i603 = trunc i128 %_10.i527 to i64
  %_4.i604 = lshr i128 %_10.i527, 64
  %x_hi.i605 = trunc nuw i128 %_4.i604 to i64
  %x_hi_hi.i606 = lshr i64 %x_hi.i605, 32
  %x_hi_lo.i607 = and i64 %x_hi.i605, 4294967295
  %_9.0.i608 = sub i64 %x_lo.i603, %x_hi_hi.i606
  %_9.1.i609 = icmp ugt i64 %x_hi_hi.i606, %x_lo.i603
  %_10.i610 = add i64 %_9.0.i608, -4294967295
  %spec.select.i611 = select i1 %_9.1.i609, i64 %_10.i610, i64 %_9.0.i608
  %t1.i612 = mul nuw i64 %x_hi_lo.i607, 4294967295
  %_14.0.i613 = add i64 %spec.select.i611, %t1.i612
  %_14.1.i614 = icmp ult i64 %_14.0.i613, %spec.select.i611
  %12 = add i64 %_14.0.i613, 4294967295
  %res.sroa.0.0.i615 = select i1 %_14.1.i614, i64 %12, i64 %_14.0.i613
  %_16.i616 = icmp ugt i64 %res.sroa.0.0.i615, -4294967296
  %_17.i617 = add nsw i64 %res.sroa.0.0.i615, 4294967295
  %_0.sroa.0.0.i618 = select i1 %_16.i616, i64 %_17.i617, i64 %res.sroa.0.0.i615
  %_14.i529 = zext i64 %a16.1 to i128
  %_15.i530 = zext i64 %u16.1 to i128
  %_13.i531 = mul nuw i128 %_15.i530, %_14.i529
  %x_lo.i587 = trunc i128 %_13.i531 to i64
  %_4.i588 = lshr i128 %_13.i531, 64
  %x_hi.i589 = trunc nuw i128 %_4.i588 to i64
  %x_hi_hi.i590 = lshr i64 %x_hi.i589, 32
  %x_hi_lo.i591 = and i64 %x_hi.i589, 4294967295
  %_9.0.i592 = sub i64 %x_lo.i587, %x_hi_hi.i590
  %_9.1.i593 = icmp ugt i64 %x_hi_hi.i590, %x_lo.i587
  %_10.i594 = add i64 %_9.0.i592, -4294967295
  %spec.select.i595 = select i1 %_9.1.i593, i64 %_10.i594, i64 %_9.0.i592
  %t1.i596 = mul nuw i64 %x_hi_lo.i591, 4294967295
  %_14.0.i597 = add i64 %spec.select.i595, %t1.i596
  %_14.1.i598 = icmp ult i64 %_14.0.i597, %spec.select.i595
  %13 = add i64 %_14.0.i597, 4294967295
  %res.sroa.0.0.i599 = select i1 %_14.1.i598, i64 %13, i64 %_14.0.i597
  %_16.i600 = icmp ugt i64 %res.sroa.0.0.i599, -4294967296
  %_17.i601 = add nsw i64 %res.sroa.0.0.i599, 4294967295
  %_0.sroa.0.0.i602 = select i1 %_16.i600, i64 %_17.i601, i64 %res.sroa.0.0.i599
  %_16.i533 = mul nuw i128 %_15.i530, %_11.i525
  %x_lo.i571 = trunc i128 %_16.i533 to i64
  %_4.i572 = lshr i128 %_16.i533, 64
  %x_hi.i573 = trunc nuw i128 %_4.i572 to i64
  %x_hi_hi.i574 = lshr i64 %x_hi.i573, 32
  %x_hi_lo.i575 = and i64 %x_hi.i573, 4294967295
  %_9.0.i576 = sub i64 %x_lo.i571, %x_hi_hi.i574
  %_9.1.i577 = icmp ugt i64 %x_hi_hi.i574, %x_lo.i571
  %_10.i578 = add i64 %_9.0.i576, -4294967295
  %spec.select.i579 = select i1 %_9.1.i577, i64 %_10.i578, i64 %_9.0.i576
  %t1.i580 = mul nuw i64 %x_hi_lo.i575, 4294967295
  %_14.0.i581 = add i64 %spec.select.i579, %t1.i580
  %_14.1.i582 = icmp ult i64 %_14.0.i581, %spec.select.i579
  %14 = add i64 %_14.0.i581, 4294967295
  %res.sroa.0.0.i583 = select i1 %_14.1.i582, i64 %14, i64 %_14.0.i581
  %_16.i584 = icmp ugt i64 %res.sroa.0.0.i583, -4294967296
  %_17.i585 = add nsw i64 %res.sroa.0.0.i583, 4294967295
  %_0.sroa.0.0.i586 = select i1 %_16.i584, i64 %_17.i585, i64 %res.sroa.0.0.i583
  %_17.i535 = mul nuw i128 %_12.i526, %_14.i529
  %x_lo.i555 = trunc i128 %_17.i535 to i64
  %_4.i556 = lshr i128 %_17.i535, 64
  %x_hi.i557 = trunc nuw i128 %_4.i556 to i64
  %x_hi_hi.i558 = lshr i64 %x_hi.i557, 32
  %x_hi_lo.i559 = and i64 %x_hi.i557, 4294967295
  %_9.0.i560 = sub i64 %x_lo.i555, %x_hi_hi.i558
  %_9.1.i561 = icmp ugt i64 %x_hi_hi.i558, %x_lo.i555
  %_10.i562 = add i64 %_9.0.i560, -4294967295
  %spec.select.i563 = select i1 %_9.1.i561, i64 %_10.i562, i64 %_9.0.i560
  %t1.i564 = mul nuw i64 %x_hi_lo.i559, 4294967295
  %_14.0.i565 = add i64 %spec.select.i563, %t1.i564
  %_14.1.i566 = icmp ult i64 %_14.0.i565, %spec.select.i563
  %15 = add i64 %_14.0.i565, 4294967295
  %res.sroa.0.0.i567 = select i1 %_14.1.i566, i64 %15, i64 %_14.0.i565
  %_16.i568 = icmp ugt i64 %res.sroa.0.0.i567, -4294967296
  %_17.i569 = add nsw i64 %res.sroa.0.0.i567, 4294967295
  %_0.sroa.0.0.i570 = select i1 %_16.i568, i64 %_17.i569, i64 %res.sroa.0.0.i567
  %_19.i537 = zext i64 %_0.sroa.0.0.i602 to i128
  %_18.i538 = mul nuw nsw i128 %_19.i537, 7
  %x_lo.i = trunc i128 %_18.i538 to i64
  %_4.i = lshr i128 %_18.i538, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %16 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %16, i64 %_14.0.i
  %_16.i553 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i554 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i553, i64 %_17.i554, i64 %res.sroa.0.0.i
  %_22.0.i540 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i618
  %_22.1.i541 = icmp ult i64 %_22.0.i540, %_0.sroa.0.0.i618
  %17 = add nuw i64 %_22.0.i540, 4294967295
  %_24.sroa.0.0.i542 = select i1 %_22.1.i541, i64 %17, i64 %_22.0.i540
  %_25.i543 = icmp ugt i64 %_24.sroa.0.0.i542, -4294967296
  %_26.i544 = add nsw i64 %_24.sroa.0.0.i542, 4294967295
  %_7.sroa.0.0.i545 = select i1 %_25.i543, i64 %_26.i544, i64 %_24.sroa.0.0.i542
  %_29.0.i546 = add i64 %_0.sroa.0.0.i586, %_0.sroa.0.0.i570
  %_29.1.i547 = icmp ult i64 %_29.0.i546, %_0.sroa.0.0.i586
  %18 = add nuw i64 %_29.0.i546, 4294967295
  %_30.sroa.0.0.i548 = select i1 %_29.1.i547, i64 %18, i64 %_29.0.i546
  %_31.i549 = icmp ugt i64 %_30.sroa.0.0.i548, -4294967296
  %_32.i550 = add nsw i64 %_30.sroa.0.0.i548, 4294967295
  %_9.sroa.0.0.i551 = select i1 %_31.i549, i64 %_32.i550, i64 %_30.sroa.0.0.i548
  %19 = getelementptr inbounds nuw i8, ptr %_1, i64 168
  %_16.0 = load i64, ptr %19, align 8, !noundef !3
  %20 = getelementptr inbounds nuw i8, ptr %_1, i64 176
  %_16.1 = load i64, ptr %20, align 8, !noundef !3
  %_11.i498 = zext i64 %_16.0 to i128
  %_12.i499 = zext i64 %h16.0 to i128
  %_10.i500 = mul nuw i128 %_11.i498, %_12.i499
  %x_lo.i683 = trunc i128 %_10.i500 to i64
  %_4.i684 = lshr i128 %_10.i500, 64
  %x_hi.i685 = trunc nuw i128 %_4.i684 to i64
  %x_hi_hi.i686 = lshr i64 %x_hi.i685, 32
  %x_hi_lo.i687 = and i64 %x_hi.i685, 4294967295
  %_9.0.i688 = sub i64 %x_lo.i683, %x_hi_hi.i686
  %_9.1.i689 = icmp ugt i64 %x_hi_hi.i686, %x_lo.i683
  %_10.i690 = add i64 %_9.0.i688, -4294967295
  %spec.select.i691 = select i1 %_9.1.i689, i64 %_10.i690, i64 %_9.0.i688
  %t1.i692 = mul nuw i64 %x_hi_lo.i687, 4294967295
  %_14.0.i693 = add i64 %spec.select.i691, %t1.i692
  %_14.1.i694 = icmp ult i64 %_14.0.i693, %spec.select.i691
  %21 = add i64 %_14.0.i693, 4294967295
  %res.sroa.0.0.i695 = select i1 %_14.1.i694, i64 %21, i64 %_14.0.i693
  %_16.i696 = icmp ugt i64 %res.sroa.0.0.i695, -4294967296
  %_17.i697 = add nsw i64 %res.sroa.0.0.i695, 4294967295
  %_0.sroa.0.0.i698 = select i1 %_16.i696, i64 %_17.i697, i64 %res.sroa.0.0.i695
  %_14.i502 = zext i64 %_16.1 to i128
  %_15.i503 = zext i64 %h16.1 to i128
  %_13.i504 = mul nuw i128 %_14.i502, %_15.i503
  %x_lo.i667 = trunc i128 %_13.i504 to i64
  %_4.i668 = lshr i128 %_13.i504, 64
  %x_hi.i669 = trunc nuw i128 %_4.i668 to i64
  %x_hi_hi.i670 = lshr i64 %x_hi.i669, 32
  %x_hi_lo.i671 = and i64 %x_hi.i669, 4294967295
  %_9.0.i672 = sub i64 %x_lo.i667, %x_hi_hi.i670
  %_9.1.i673 = icmp ugt i64 %x_hi_hi.i670, %x_lo.i667
  %_10.i674 = add i64 %_9.0.i672, -4294967295
  %spec.select.i675 = select i1 %_9.1.i673, i64 %_10.i674, i64 %_9.0.i672
  %t1.i676 = mul nuw i64 %x_hi_lo.i671, 4294967295
  %_14.0.i677 = add i64 %spec.select.i675, %t1.i676
  %_14.1.i678 = icmp ult i64 %_14.0.i677, %spec.select.i675
  %22 = add i64 %_14.0.i677, 4294967295
  %res.sroa.0.0.i679 = select i1 %_14.1.i678, i64 %22, i64 %_14.0.i677
  %_16.i680 = icmp ugt i64 %res.sroa.0.0.i679, -4294967296
  %_17.i681 = add nsw i64 %res.sroa.0.0.i679, 4294967295
  %_0.sroa.0.0.i682 = select i1 %_16.i680, i64 %_17.i681, i64 %res.sroa.0.0.i679
  %_16.i506 = mul nuw i128 %_11.i498, %_15.i503
  %x_lo.i651 = trunc i128 %_16.i506 to i64
  %_4.i652 = lshr i128 %_16.i506, 64
  %x_hi.i653 = trunc nuw i128 %_4.i652 to i64
  %x_hi_hi.i654 = lshr i64 %x_hi.i653, 32
  %x_hi_lo.i655 = and i64 %x_hi.i653, 4294967295
  %_9.0.i656 = sub i64 %x_lo.i651, %x_hi_hi.i654
  %_9.1.i657 = icmp ugt i64 %x_hi_hi.i654, %x_lo.i651
  %_10.i658 = add i64 %_9.0.i656, -4294967295
  %spec.select.i659 = select i1 %_9.1.i657, i64 %_10.i658, i64 %_9.0.i656
  %t1.i660 = mul nuw i64 %x_hi_lo.i655, 4294967295
  %_14.0.i661 = add i64 %spec.select.i659, %t1.i660
  %_14.1.i662 = icmp ult i64 %_14.0.i661, %spec.select.i659
  %23 = add i64 %_14.0.i661, 4294967295
  %res.sroa.0.0.i663 = select i1 %_14.1.i662, i64 %23, i64 %_14.0.i661
  %_16.i664 = icmp ugt i64 %res.sroa.0.0.i663, -4294967296
  %_17.i665 = add nsw i64 %res.sroa.0.0.i663, 4294967295
  %_0.sroa.0.0.i666 = select i1 %_16.i664, i64 %_17.i665, i64 %res.sroa.0.0.i663
  %_17.i508 = mul nuw i128 %_14.i502, %_12.i499
  %x_lo.i635 = trunc i128 %_17.i508 to i64
  %_4.i636 = lshr i128 %_17.i508, 64
  %x_hi.i637 = trunc nuw i128 %_4.i636 to i64
  %x_hi_hi.i638 = lshr i64 %x_hi.i637, 32
  %x_hi_lo.i639 = and i64 %x_hi.i637, 4294967295
  %_9.0.i640 = sub i64 %x_lo.i635, %x_hi_hi.i638
  %_9.1.i641 = icmp ugt i64 %x_hi_hi.i638, %x_lo.i635
  %_10.i642 = add i64 %_9.0.i640, -4294967295
  %spec.select.i643 = select i1 %_9.1.i641, i64 %_10.i642, i64 %_9.0.i640
  %t1.i644 = mul nuw i64 %x_hi_lo.i639, 4294967295
  %_14.0.i645 = add i64 %spec.select.i643, %t1.i644
  %_14.1.i646 = icmp ult i64 %_14.0.i645, %spec.select.i643
  %24 = add i64 %_14.0.i645, 4294967295
  %res.sroa.0.0.i647 = select i1 %_14.1.i646, i64 %24, i64 %_14.0.i645
  %_16.i648 = icmp ugt i64 %res.sroa.0.0.i647, -4294967296
  %_17.i649 = add nsw i64 %res.sroa.0.0.i647, 4294967295
  %_0.sroa.0.0.i650 = select i1 %_16.i648, i64 %_17.i649, i64 %res.sroa.0.0.i647
  %_19.i510 = zext i64 %_0.sroa.0.0.i682 to i128
  %_18.i511 = mul nuw nsw i128 %_19.i510, 7
  %x_lo.i619 = trunc i128 %_18.i511 to i64
  %_4.i620 = lshr i128 %_18.i511, 64
  %x_hi.i621 = trunc nuw nsw i128 %_4.i620 to i64
  %t1.i628 = mul nuw nsw i64 %x_hi.i621, 4294967295
  %_14.0.i629 = add i64 %t1.i628, %x_lo.i619
  %_14.1.i630 = icmp ult i64 %_14.0.i629, %x_lo.i619
  %25 = add i64 %_14.0.i629, 4294967295
  %res.sroa.0.0.i631 = select i1 %_14.1.i630, i64 %25, i64 %_14.0.i629
  %_16.i632 = icmp ugt i64 %res.sroa.0.0.i631, -4294967296
  %_17.i633 = add nsw i64 %res.sroa.0.0.i631, 4294967295
  %_0.sroa.0.0.i634 = select i1 %_16.i632, i64 %_17.i633, i64 %res.sroa.0.0.i631
  %_22.0.i513 = add i64 %_0.sroa.0.0.i634, %_0.sroa.0.0.i698
  %_22.1.i514 = icmp ult i64 %_22.0.i513, %_0.sroa.0.0.i698
  %26 = add nuw i64 %_22.0.i513, 4294967295
  %_24.sroa.0.0.i515 = select i1 %_22.1.i514, i64 %26, i64 %_22.0.i513
  %_25.i516 = icmp ugt i64 %_24.sroa.0.0.i515, -4294967296
  %_26.i517 = add nsw i64 %_24.sroa.0.0.i515, 4294967295
  %_7.sroa.0.0.i518 = select i1 %_25.i516, i64 %_26.i517, i64 %_24.sroa.0.0.i515
  %_29.0.i519 = add i64 %_0.sroa.0.0.i650, %_0.sroa.0.0.i666
  %_29.1.i520 = icmp ult i64 %_29.0.i519, %_0.sroa.0.0.i666
  %27 = add nuw i64 %_29.0.i519, 4294967295
  %_30.sroa.0.0.i521 = select i1 %_29.1.i520, i64 %27, i64 %_29.0.i519
  %_31.i522 = icmp ugt i64 %_30.sroa.0.0.i521, -4294967296
  %_32.i523 = add nsw i64 %_30.sroa.0.0.i521, 4294967295
  %_9.sroa.0.0.i524 = select i1 %_31.i522, i64 %_32.i523, i64 %_30.sroa.0.0.i521
  %_119.0 = sub i64 %_7.sroa.0.0.i545, %_7.sroa.0.0.i518
  %_119.1 = icmp ult i64 %_7.sroa.0.0.i545, %_7.sroa.0.0.i518
  %28 = add i64 %_119.0, -4294967295
  %_120.sroa.0.0 = select i1 %_119.1, i64 %28, i64 %_119.0
  %_123.0 = sub i64 %_9.sroa.0.0.i551, %_9.sroa.0.0.i524
  %_123.1 = icmp ult i64 %_9.sroa.0.0.i551, %_9.sroa.0.0.i524
  %29 = add i64 %_123.0, -4294967295
  %_124.sroa.0.0 = select i1 %_123.1, i64 %29, i64 %_123.0
; call isolated::factory_2::{closure#1}::{closure#1}
  %30 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 76)
  %_17.0 = extractvalue { i64, i64 } %30, 0
  %_17.1 = extractvalue { i64, i64 } %30, 1
  %_133.0 = sub i64 %_120.sroa.0.0, %_17.0
  %_133.1 = icmp ult i64 %_120.sroa.0.0, %_17.0
  %31 = add i64 %_133.0, -4294967295
  %_134.sroa.0.0 = select i1 %_133.1, i64 %31, i64 %_133.0
  %_137.0 = sub i64 %_124.sroa.0.0, %_17.1
  %_137.1 = icmp ult i64 %_124.sroa.0.0, %_17.1
  %32 = add i64 %_137.0, -4294967295
  %_138.sroa.0.0 = select i1 %_137.1, i64 %32, i64 %_137.0
  %33 = getelementptr inbounds nuw i8, ptr %_1, i64 184
  %_19.0 = load i64, ptr %33, align 8, !noundef !3
  %34 = getelementptr inbounds nuw i8, ptr %_1, i64 192
  %_19.1 = load i64, ptr %34, align 8, !noundef !3
  %_7.0.i159 = add i64 %_134.sroa.0.0, %_19.0
  %_7.1.i160 = icmp ult i64 %_7.0.i159, %_134.sroa.0.0
  %35 = add i64 %_7.0.i159, 4294967295
  %_8.sroa.0.0.i161 = select i1 %_7.1.i160, i64 %35, i64 %_7.0.i159
  %_9.i162 = icmp ugt i64 %_8.sroa.0.0.i161, -4294967296
  %_10.i163 = add nsw i64 %_8.sroa.0.0.i161, 4294967295
  %_3.sroa.0.0.i164 = select i1 %_9.i162, i64 %_10.i163, i64 %_8.sroa.0.0.i161
  %_13.0.i165 = add i64 %_138.sroa.0.0, %_19.1
  %_13.1.i166 = icmp ult i64 %_13.0.i165, %_138.sroa.0.0
  %36 = add i64 %_13.0.i165, 4294967295
  %_14.sroa.0.0.i167 = select i1 %_13.1.i166, i64 %36, i64 %_13.0.i165
  %_15.i168 = icmp ugt i64 %_14.sroa.0.0.i167, -4294967296
  %_16.i169 = add nsw i64 %_14.sroa.0.0.i167, 4294967295
  %_4.sroa.0.0.i170 = select i1 %_15.i168, i64 %_16.i169, i64 %_14.sroa.0.0.i167
  %_7.1.i148 = icmp ugt i64 %u16.0, -32769
  %_8.sroa.0.0.i149.v = select i1 %_7.1.i148, i64 4295000063, i64 32768
  %_8.sroa.0.0.i149 = add i64 %_8.sroa.0.0.i149.v, %u16.0
  %_9.i150 = icmp ugt i64 %_8.sroa.0.0.i149, -4294967296
  %_10.i151 = add nsw i64 %_8.sroa.0.0.i149, 4294967295
  %_3.sroa.0.0.i152 = select i1 %_9.i150, i64 %_10.i151, i64 %_8.sroa.0.0.i149
  %_15.i156 = icmp ugt i64 %u16.1, -4294967296
  %_16.i157 = add nsw i64 %u16.1, 4294967295
  %_4.sroa.0.0.i158 = select i1 %_15.i156, i64 %_16.i157, i64 %u16.1
; call isolated::factory_2::{closure#1}::{closure#1}
  %37 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 71)
  %_23.0 = extractvalue { i64, i64 } %37, 0
  %_23.1 = extractvalue { i64, i64 } %37, 1
  %_146.0 = sub i64 %_3.sroa.0.0.i152, %_23.0
  %_146.1 = icmp ult i64 %_3.sroa.0.0.i152, %_23.0
  %38 = add i64 %_146.0, -4294967295
  %_147.sroa.0.0 = select i1 %_146.1, i64 %38, i64 %_146.0
  %_150.0 = sub i64 %_4.sroa.0.0.i158, %_23.1
  %_150.1 = icmp ult i64 %_4.sroa.0.0.i158, %_23.1
  %39 = add i64 %_150.0, -4294967295
  %_151.sroa.0.0 = select i1 %_150.1, i64 %39, i64 %_150.0
  %_7.1.i136 = icmp ugt i64 %h16.0, -32769
  %_8.sroa.0.0.i137.v = select i1 %_7.1.i136, i64 4295000063, i64 32768
  %_8.sroa.0.0.i137 = add i64 %_8.sroa.0.0.i137.v, %h16.0
  %_9.i138 = icmp ugt i64 %_8.sroa.0.0.i137, -4294967296
  %_10.i139 = add nsw i64 %_8.sroa.0.0.i137, 4294967295
  %_3.sroa.0.0.i140 = select i1 %_9.i138, i64 %_10.i139, i64 %_8.sroa.0.0.i137
  %_15.i144 = icmp ugt i64 %h16.1, -4294967296
  %_16.i145 = add nsw i64 %h16.1, 4294967295
  %_4.sroa.0.0.i146 = select i1 %_15.i144, i64 %_16.i145, i64 %h16.1
; call isolated::factory_2::{closure#1}::{closure#1}
  %40 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 74)
  %_28.0 = extractvalue { i64, i64 } %40, 0
  %_28.1 = extractvalue { i64, i64 } %40, 1
  %_161.0 = sub i64 %_3.sroa.0.0.i140, %_28.0
  %_161.1 = icmp ult i64 %_3.sroa.0.0.i140, %_28.0
  %41 = add i64 %_161.0, -4294967295
  %_162.sroa.0.0 = select i1 %_161.1, i64 %41, i64 %_161.0
  %_165.0 = sub i64 %_4.sroa.0.0.i146, %_28.1
  %_165.1 = icmp ult i64 %_4.sroa.0.0.i146, %_28.1
  %42 = add i64 %_165.0, -4294967295
  %_166.sroa.0.0 = select i1 %_165.1, i64 %42, i64 %_165.0
  %43 = getelementptr inbounds nuw i8, ptr %_1, i64 200
  %_33 = load i64, ptr %43, align 8, !noundef !3
  %_34 = icmp ult i64 %_33, %v.1
  br i1 %_34, label %bb9, label %panic8

panic7:                                           ; preds = %bb53
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_113, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable

bb9:                                              ; preds = %bb52
  %44 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_33
  %_32.0 = load i64, ptr %44, align 8, !noundef !3
  %45 = getelementptr inbounds nuw i8, ptr %44, i64 8
  %_32.1 = load i64, ptr %45, align 8, !noundef !3
  %46 = getelementptr inbounds nuw i8, ptr %_1, i64 208
  %_242 = load i64, ptr %46, align 8, !noundef !3
  %47 = getelementptr inbounds nuw i8, ptr %_1, i64 216
  %_243 = load i64, ptr %47, align 8, !noundef !3
  %48 = getelementptr inbounds nuw i8, ptr %_1, i64 224
  %_41.0 = load i64, ptr %48, align 8, !noundef !3
  %49 = getelementptr inbounds nuw i8, ptr %_1, i64 232
  %_41.1 = load i64, ptr %49, align 8, !noundef !3
  %50 = getelementptr inbounds nuw i8, ptr %_1, i64 240
  %_42.0 = load i64, ptr %50, align 8, !noundef !3
  %51 = getelementptr inbounds nuw i8, ptr %_1, i64 248
  %_42.1 = load i64, ptr %51, align 8, !noundef !3
  %52 = load i64, ptr %_1, align 8, !range !56, !noundef !3
  %53 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %54 = load i64, ptr %53, align 8
  %55 = trunc nuw i64 %52 to i1
  br i1 %55, label %bb89, label %bb87

panic8:                                           ; preds = %bb52
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_33, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_33f4d218739df51bc601f47114eed12f) #21
  unreachable

bb89:                                             ; preds = %bb9
  %_194 = icmp ult i64 %54, %v.1
  br i1 %_194, label %bb90, label %panic9

bb87:                                             ; preds = %bb9, %bb90
  %g.sroa.5.0 = phi i64 [ %60, %bb90 ], [ 0, %bb9 ]
  %g.sroa.0.0 = phi i64 [ %58, %bb90 ], [ 1, %bb9 ]
  %56 = getelementptr inbounds nuw i8, ptr %_1, i64 80
  %_201 = load i64, ptr %56, align 8, !noundef !3
  %_203 = icmp ult i64 %_201, 4
  br i1 %_203, label %bb91, label %bb9.i.preheader, !prof !57

bb90:                                             ; preds = %bb89
  %57 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %54
  %58 = load i64, ptr %57, align 8, !noundef !3
  %59 = getelementptr inbounds nuw i8, ptr %57, i64 8
  %60 = load i64, ptr %59, align 8, !noundef !3
  br label %bb87

panic9:                                           ; preds = %bb89
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %54, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_03bbe1d0fcdbd86f2216092eb0f02e36) #21
  unreachable

bb9.i.preheader:                                  ; preds = %bb87
  %61 = getelementptr inbounds nuw i8, ptr %_1, i64 72
  %_202 = load ptr, ptr %61, align 8, !nonnull !3, !noundef !3
  %62 = getelementptr inbounds nuw i8, ptr %_1, i64 256
  %_48 = load i64, ptr %62, align 8, !noundef !3
  %63 = getelementptr inbounds nuw i8, ptr %_1, i64 56
  %_197 = load i64, ptr %63, align 8, !noundef !3
  %64 = getelementptr inbounds nuw i8, ptr %_1, i64 48
  %_198 = load ptr, ptr %64, align 8, !nonnull !3, !noundef !3
  %_205 = add i64 %_201, -4
  %_209 = getelementptr inbounds nuw i8, ptr %_202, i64 64
; call isolated::helper_sum
  %65 = call fastcc { i64, i64 } @_RNvCsl0YfJI2rrfI_8isolated10helper_sum(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_198, i64 noundef %_197, i64 noundef %_48, i64 noundef %_242, i64 noundef %_243, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_209, i64 noundef %_205)
  %_53 = getelementptr inbounds nuw i8, ptr %_202, i64 48
  %_52.0 = load i64, ptr %_53, align 8, !noundef !3
  %66 = getelementptr inbounds nuw i8, ptr %_202, i64 56
  %_52.1 = load i64, ptr %66, align 8, !noundef !3
  %_55 = getelementptr inbounds nuw i8, ptr %_1, i64 88
; call <isolated::PadTerm>::eval
  %67 = call fastcc { i64, i64 } @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(40) %_55, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1)
  %_214.idx = shl nuw nsw i64 %_201, 4
  %_214 = getelementptr inbounds nuw i8, ptr %_202, i64 %_214.idx
  %_57.sroa.6.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 80
  call void @llvm.lifetime.start.p0(ptr nonnull %iter)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %_57.sroa.6.0.iter.sroa_idx, i8 0, i64 16, i1 false)
  %_57.sroa.5.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 32
  store i64 %_3.sroa.0.0.i164, ptr %_57.sroa.5.0.iter.sroa_idx, align 8
  %_57.sroa.5.sroa.2.0._57.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 40
  store i64 %_4.sroa.0.0.i170, ptr %_57.sroa.5.sroa.2.0._57.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_57.sroa.5.sroa.3.0._57.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 48
  store i64 %_147.sroa.0.0, ptr %_57.sroa.5.sroa.3.0._57.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_57.sroa.5.sroa.4.0._57.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 56
  store i64 %_151.sroa.0.0, ptr %_57.sroa.5.sroa.4.0._57.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_57.sroa.5.sroa.5.0._57.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 64
  store i64 %_162.sroa.0.0, ptr %_57.sroa.5.sroa.5.0._57.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_57.sroa.5.sroa.6.0._57.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 72
  store i64 %_166.sroa.0.0, ptr %_57.sroa.5.sroa.6.0._57.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  br label %bb9.i

bb91:                                             ; preds = %bb87
; call core::slice::index::slice_index_fail
  call void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 4, i64 noundef %_201, i64 noundef %_201, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_783adf84c4437dc3f5e730641bb4655a) #21
  unreachable

bb9.i:                                            ; preds = %bb9.i.preheader, %bb26
  %clauses.sroa.0.01763 = phi i64 [ %_3.sroa.0.0.i, %bb26 ], [ 0, %bb9.i.preheader ]
  %clauses.sroa.4.01762 = phi i64 [ %_4.sroa.0.0.i, %bb26 ], [ 0, %bb9.i.preheader ]
  %ptr.i.i17461761 = phi ptr [ %_16.i.i, %bb26 ], [ %_202, %bb9.i.preheader ]
  %_10.i.i.i17481760 = phi i64 [ %_11.i.i.i, %bb26 ], [ 0, %bb9.i.preheader ]
  %_5.not.i.i.i = icmp eq i64 %_10.i.i.i17481760, 3
  br i1 %_5.not.i.i.i, label %bb24, label %bb26

bb24:                                             ; preds = %bb9.i, %bb26
  %clauses.sroa.4.0.lcssa.ph = phi i64 [ %_4.sroa.0.0.i, %bb26 ], [ %clauses.sroa.4.01762, %bb9.i ]
  %clauses.sroa.0.0.lcssa.ph = phi i64 [ %_3.sroa.0.0.i, %bb26 ], [ %clauses.sroa.0.01763, %bb9.i ]
  call void @llvm.lifetime.end.p0(ptr nonnull %iter)
  %_220 = getelementptr inbounds nuw i8, ptr %_103, i64 544
  %_219 = load i64, ptr %_220, align 8, !noundef !3
  %_221 = icmp ult i64 %_219, %v.1
  br i1 %_221, label %bb95, label %panic12

bb95:                                             ; preds = %bb24
  %68 = getelementptr inbounds nuw i8, ptr %_1, i64 264
  %_75.0 = load i64, ptr %68, align 8, !noundef !3
  %69 = getelementptr inbounds nuw i8, ptr %_1, i64 272
  %_75.1 = load i64, ptr %69, align 8, !noundef !3
  %70 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_219
  %_76.0 = load i64, ptr %70, align 8, !noundef !3
  %71 = getelementptr inbounds nuw i8, ptr %70, i64 8
  %_76.1 = load i64, ptr %71, align 8, !noundef !3
  %72 = getelementptr inbounds nuw i8, ptr %_1, i64 280
  %_244 = load i64, ptr %72, align 8, !noundef !3
  %73 = getelementptr inbounds nuw i8, ptr %_1, i64 288
  %_245 = load i64, ptr %73, align 8, !noundef !3
  %_79.0 = load i64, ptr %v.0, align 8, !noundef !3
  %74 = getelementptr inbounds nuw i8, ptr %v.0, i64 8
  %_79.1 = load i64, ptr %74, align 8, !noundef !3
  %75 = getelementptr inbounds nuw i8, ptr %_1, i64 136
  %_238 = load ptr, ptr %75, align 8, !nonnull !3, !noundef !3
  %76 = getelementptr inbounds nuw i8, ptr %_1, i64 144
  %_237 = load i64, ptr %76, align 8, !noundef !3
  %_239.not = icmp eq i64 %_237, 0
  br i1 %_239.not, label %panic14, label %bb103

panic12:                                          ; preds = %bb24
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_219, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23cbb2e7863b02fb8b64518d13a27720) #21
  unreachable

bb103:                                            ; preds = %bb95
  %_87 = icmp samesign ugt i64 %v.1, 1
  br i1 %_87, label %bb34, label %panic15

panic14:                                          ; preds = %bb95
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 0, i64 noundef 0, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_80ab1297b78c18879967432c54c1e54e) #21
  unreachable

bb34:                                             ; preds = %bb103
  %77 = getelementptr inbounds nuw i8, ptr %_238, i64 8
  %_84.1 = load i64, ptr %77, align 8, !noundef !3
  %_84.0 = load i64, ptr %_238, align 8, !noundef !3
  %78 = getelementptr inbounds nuw i8, ptr %v.0, i64 16
  %_86.0 = load i64, ptr %78, align 8, !noundef !3
  %79 = getelementptr inbounds nuw i8, ptr %v.0, i64 24
  %_86.1 = load i64, ptr %79, align 8, !noundef !3
  %_240.not = icmp eq i64 %_237, 1
  br i1 %_240.not, label %panic16, label %bb104

panic15:                                          ; preds = %bb103
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_f604f896c68dd8f0a4007dacc23397d5) #21
  unreachable

bb104:                                            ; preds = %bb34
  %_95.not = icmp eq i64 %v.1, 2
  br i1 %_95.not, label %panic17, label %bb39

panic16:                                          ; preds = %bb34
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef 1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_18a70e0bda0ee5b1c3fd14bc973a5c99) #21
  unreachable

bb39:                                             ; preds = %bb104
  %_11.i336 = zext i64 %_79.0 to i128
  %_46.1 = extractvalue { i64, i64 } %65, 1
  %_11.i417 = zext i64 %_52.0 to i128
  %_11.i444 = zext i64 %_32.0 to i128
  %_15.i132 = icmp ugt i64 %g8.1, -4294967296
  %_16.i133 = add nsw i64 %g8.1, 4294967295
  %_4.sroa.0.0.i134 = select i1 %_15.i132, i64 %_16.i133, i64 %g8.1
  %_11.i471 = zext i64 %_41.0 to i128
  %_16.i479 = mul nuw i128 %_11.i471, %_14.i529
  %_4.i732 = lshr i128 %_16.i479, 64
  %x_hi.i733 = trunc nuw i128 %_4.i732 to i64
  %x_hi_hi.i734 = lshr i64 %x_hi.i733, 32
  %x_lo.i731 = trunc i128 %_16.i479 to i64
  %_9.1.i737 = icmp ugt i64 %x_hi_hi.i734, %x_lo.i731
  %_9.0.i736 = sub i64 %x_lo.i731, %x_hi_hi.i734
  %_10.i738 = add i64 %_9.0.i736, -4294967295
  %spec.select.i739 = select i1 %_9.1.i737, i64 %_10.i738, i64 %_9.0.i736
  %x_hi_lo.i735 = and i64 %x_hi.i733, 4294967295
  %t1.i740 = mul nuw i64 %x_hi_lo.i735, 4294967295
  %_14.0.i741 = add i64 %spec.select.i739, %t1.i740
  %_14.1.i742 = icmp ult i64 %_14.0.i741, %spec.select.i739
  %80 = add i64 %_14.0.i741, 4294967295
  %res.sroa.0.0.i743 = select i1 %_14.1.i742, i64 %80, i64 %_14.0.i741
  %_16.i744 = icmp ugt i64 %res.sroa.0.0.i743, -4294967296
  %_17.i745 = add nsw i64 %res.sroa.0.0.i743, 4294967295
  %_0.sroa.0.0.i746 = select i1 %_16.i744, i64 %_17.i745, i64 %res.sroa.0.0.i743
  %_14.i475 = zext i64 %_41.1 to i128
  %_17.i481 = mul nuw i128 %_14.i475, %_11.i525
  %_4.i716 = lshr i128 %_17.i481, 64
  %x_hi.i717 = trunc nuw i128 %_4.i716 to i64
  %x_hi_hi.i718 = lshr i64 %x_hi.i717, 32
  %x_lo.i715 = trunc i128 %_17.i481 to i64
  %_9.1.i721 = icmp ugt i64 %x_hi_hi.i718, %x_lo.i715
  %_9.0.i720 = sub i64 %x_lo.i715, %x_hi_hi.i718
  %_10.i722 = add i64 %_9.0.i720, -4294967295
  %spec.select.i723 = select i1 %_9.1.i721, i64 %_10.i722, i64 %_9.0.i720
  %x_hi_lo.i719 = and i64 %x_hi.i717, 4294967295
  %t1.i724 = mul nuw i64 %x_hi_lo.i719, 4294967295
  %_14.0.i725 = add i64 %spec.select.i723, %t1.i724
  %_14.1.i726 = icmp ult i64 %_14.0.i725, %spec.select.i723
  %81 = add i64 %_14.0.i725, 4294967295
  %res.sroa.0.0.i727 = select i1 %_14.1.i726, i64 %81, i64 %_14.0.i725
  %_16.i728 = icmp ugt i64 %res.sroa.0.0.i727, -4294967296
  %_17.i729 = add nsw i64 %res.sroa.0.0.i727, 4294967295
  %_0.sroa.0.0.i730 = select i1 %_16.i728, i64 %_17.i729, i64 %res.sroa.0.0.i727
  %_29.0.i492 = add i64 %_0.sroa.0.0.i730, %_0.sroa.0.0.i746
  %_29.1.i493 = icmp ult i64 %_29.0.i492, %_0.sroa.0.0.i746
  %82 = add nuw i64 %_29.0.i492, 4294967295
  %_30.sroa.0.0.i494 = select i1 %_29.1.i493, i64 %82, i64 %_29.0.i492
  %_31.i495 = icmp ugt i64 %_30.sroa.0.0.i494, -4294967296
  %_32.i496 = add nsw i64 %_30.sroa.0.0.i494, 4294967295
  %_9.sroa.0.0.i497 = select i1 %_31.i495, i64 %_32.i496, i64 %_30.sroa.0.0.i494
  %_13.0.i117 = add i64 %_9.sroa.0.0.i497, %_4.sroa.0.0.i134
  %_13.1.i118 = icmp ult i64 %_13.0.i117, %_4.sroa.0.0.i134
  %83 = add i64 %_13.0.i117, 4294967295
  %_14.sroa.0.0.i119 = select i1 %_13.1.i118, i64 %83, i64 %_13.0.i117
  %_15.i120 = icmp ugt i64 %_14.sroa.0.0.i119, -4294967296
  %_16.i121 = add nsw i64 %_14.sroa.0.0.i119, 4294967295
  %_4.sroa.0.0.i122 = select i1 %_15.i120, i64 %_16.i121, i64 %_14.sroa.0.0.i119
  %_13.0.i105 = add i64 %_4.sroa.0.0.i122, %_42.1
  %_13.1.i106 = icmp ult i64 %_13.0.i105, %_4.sroa.0.0.i122
  %84 = add i64 %_13.0.i105, 4294967295
  %_14.sroa.0.0.i107 = select i1 %_13.1.i106, i64 %84, i64 %_13.0.i105
  %_15.i108 = icmp ugt i64 %_14.sroa.0.0.i107, -4294967296
  %_16.i109 = add nsw i64 %_14.sroa.0.0.i107, 4294967295
  %_4.sroa.0.0.i110 = select i1 %_15.i108, i64 %_16.i109, i64 %_14.sroa.0.0.i107
  %_180.1 = icmp ult i64 %_243, %_4.sroa.0.0.i110
  %_180.0 = sub i64 %_243, %_4.sroa.0.0.i110
  %85 = add i64 %_180.0, -4294967295
  %_181.sroa.0.0 = select i1 %_180.1, i64 %85, i64 %_180.0
  %_15.i449 = zext i64 %_181.sroa.0.0 to i128
  %_16.i452 = mul nuw i128 %_15.i449, %_11.i444
  %_4.i812 = lshr i128 %_16.i452, 64
  %x_hi.i813 = trunc nuw i128 %_4.i812 to i64
  %x_hi_hi.i814 = lshr i64 %x_hi.i813, 32
  %x_lo.i811 = trunc i128 %_16.i452 to i64
  %_9.1.i817 = icmp ugt i64 %x_hi_hi.i814, %x_lo.i811
  %_9.0.i816 = sub i64 %x_lo.i811, %x_hi_hi.i814
  %_10.i818 = add i64 %_9.0.i816, -4294967295
  %spec.select.i819 = select i1 %_9.1.i817, i64 %_10.i818, i64 %_9.0.i816
  %x_hi_lo.i815 = and i64 %x_hi.i813, 4294967295
  %t1.i820 = mul nuw i64 %x_hi_lo.i815, 4294967295
  %_14.0.i821 = add i64 %spec.select.i819, %t1.i820
  %_14.1.i822 = icmp ult i64 %_14.0.i821, %spec.select.i819
  %86 = add i64 %_14.0.i821, 4294967295
  %res.sroa.0.0.i823 = select i1 %_14.1.i822, i64 %86, i64 %_14.0.i821
  %_16.i824 = icmp ugt i64 %res.sroa.0.0.i823, -4294967296
  %_17.i825 = add nsw i64 %res.sroa.0.0.i823, 4294967295
  %_0.sroa.0.0.i826 = select i1 %_16.i824, i64 %_17.i825, i64 %res.sroa.0.0.i823
  %_14.i448 = zext i64 %_32.1 to i128
  %_7.1.i124 = icmp ugt i64 %g8.0, -129
  %_8.sroa.0.0.i125.v = select i1 %_7.1.i124, i64 4294967423, i64 128
  %_8.sroa.0.0.i125 = add i64 %_8.sroa.0.0.i125.v, %g8.0
  %_9.i126 = icmp ugt i64 %_8.sroa.0.0.i125, -4294967296
  %_10.i127 = add nsw i64 %_8.sroa.0.0.i125, 4294967295
  %_3.sroa.0.0.i128 = select i1 %_9.i126, i64 %_10.i127, i64 %_8.sroa.0.0.i125
  %_10.i473 = mul nuw i128 %_11.i471, %_11.i525
  %_4.i764 = lshr i128 %_10.i473, 64
  %x_hi.i765 = trunc nuw i128 %_4.i764 to i64
  %x_hi_hi.i766 = lshr i64 %x_hi.i765, 32
  %x_lo.i763 = trunc i128 %_10.i473 to i64
  %_9.1.i769 = icmp ugt i64 %x_hi_hi.i766, %x_lo.i763
  %_9.0.i768 = sub i64 %x_lo.i763, %x_hi_hi.i766
  %_10.i770 = add i64 %_9.0.i768, -4294967295
  %spec.select.i771 = select i1 %_9.1.i769, i64 %_10.i770, i64 %_9.0.i768
  %x_hi_lo.i767 = and i64 %x_hi.i765, 4294967295
  %t1.i772 = mul nuw i64 %x_hi_lo.i767, 4294967295
  %_14.0.i773 = add i64 %spec.select.i771, %t1.i772
  %_14.1.i774 = icmp ult i64 %_14.0.i773, %spec.select.i771
  %87 = add i64 %_14.0.i773, 4294967295
  %res.sroa.0.0.i775 = select i1 %_14.1.i774, i64 %87, i64 %_14.0.i773
  %_16.i776 = icmp ugt i64 %res.sroa.0.0.i775, -4294967296
  %_17.i777 = add nsw i64 %res.sroa.0.0.i775, 4294967295
  %_0.sroa.0.0.i778 = select i1 %_16.i776, i64 %_17.i777, i64 %res.sroa.0.0.i775
  %_13.i477 = mul nuw i128 %_14.i475, %_14.i529
  %_4.i748 = lshr i128 %_13.i477, 64
  %x_hi.i749 = trunc nuw i128 %_4.i748 to i64
  %x_hi_hi.i750 = lshr i64 %x_hi.i749, 32
  %x_lo.i747 = trunc i128 %_13.i477 to i64
  %_9.1.i753 = icmp ugt i64 %x_hi_hi.i750, %x_lo.i747
  %_9.0.i752 = sub i64 %x_lo.i747, %x_hi_hi.i750
  %_10.i754 = add i64 %_9.0.i752, -4294967295
  %spec.select.i755 = select i1 %_9.1.i753, i64 %_10.i754, i64 %_9.0.i752
  %x_hi_lo.i751 = and i64 %x_hi.i749, 4294967295
  %t1.i756 = mul nuw i64 %x_hi_lo.i751, 4294967295
  %_14.0.i757 = add i64 %spec.select.i755, %t1.i756
  %_14.1.i758 = icmp ult i64 %_14.0.i757, %spec.select.i755
  %88 = add i64 %_14.0.i757, 4294967295
  %res.sroa.0.0.i759 = select i1 %_14.1.i758, i64 %88, i64 %_14.0.i757
  %_16.i760 = icmp ugt i64 %res.sroa.0.0.i759, -4294967296
  %_17.i761 = add nsw i64 %res.sroa.0.0.i759, 4294967295
  %_0.sroa.0.0.i762 = select i1 %_16.i760, i64 %_17.i761, i64 %res.sroa.0.0.i759
  %_19.i483 = zext i64 %_0.sroa.0.0.i762 to i128
  %_18.i484 = mul nuw nsw i128 %_19.i483, 7
  %_4.i700 = lshr i128 %_18.i484, 64
  %x_hi.i701 = trunc nuw nsw i128 %_4.i700 to i64
  %t1.i708 = mul nuw nsw i64 %x_hi.i701, 4294967295
  %x_lo.i699 = trunc i128 %_18.i484 to i64
  %_14.0.i709 = add i64 %t1.i708, %x_lo.i699
  %_14.1.i710 = icmp ult i64 %_14.0.i709, %x_lo.i699
  %89 = add i64 %_14.0.i709, 4294967295
  %res.sroa.0.0.i711 = select i1 %_14.1.i710, i64 %89, i64 %_14.0.i709
  %_16.i712 = icmp ugt i64 %res.sroa.0.0.i711, -4294967296
  %_17.i713 = add nsw i64 %res.sroa.0.0.i711, 4294967295
  %_0.sroa.0.0.i714 = select i1 %_16.i712, i64 %_17.i713, i64 %res.sroa.0.0.i711
  %_22.0.i486 = add i64 %_0.sroa.0.0.i714, %_0.sroa.0.0.i778
  %_22.1.i487 = icmp ult i64 %_22.0.i486, %_0.sroa.0.0.i778
  %90 = add nuw i64 %_22.0.i486, 4294967295
  %_24.sroa.0.0.i488 = select i1 %_22.1.i487, i64 %90, i64 %_22.0.i486
  %_25.i489 = icmp ugt i64 %_24.sroa.0.0.i488, -4294967296
  %_26.i490 = add nsw i64 %_24.sroa.0.0.i488, 4294967295
  %_7.sroa.0.0.i491 = select i1 %_25.i489, i64 %_26.i490, i64 %_24.sroa.0.0.i488
  %_7.0.i111 = add i64 %_7.sroa.0.0.i491, %_3.sroa.0.0.i128
  %_7.1.i112 = icmp ult i64 %_7.0.i111, %_3.sroa.0.0.i128
  %91 = add i64 %_7.0.i111, 4294967295
  %_8.sroa.0.0.i113 = select i1 %_7.1.i112, i64 %91, i64 %_7.0.i111
  %_9.i114 = icmp ugt i64 %_8.sroa.0.0.i113, -4294967296
  %_10.i115 = add nsw i64 %_8.sroa.0.0.i113, 4294967295
  %_3.sroa.0.0.i116 = select i1 %_9.i114, i64 %_10.i115, i64 %_8.sroa.0.0.i113
  %_7.0.i99 = add i64 %_3.sroa.0.0.i116, %_42.0
  %_7.1.i100 = icmp ult i64 %_7.0.i99, %_3.sroa.0.0.i116
  %92 = add i64 %_7.0.i99, 4294967295
  %_8.sroa.0.0.i101 = select i1 %_7.1.i100, i64 %92, i64 %_7.0.i99
  %_9.i102 = icmp ugt i64 %_8.sroa.0.0.i101, -4294967296
  %_10.i103 = add nsw i64 %_8.sroa.0.0.i101, 4294967295
  %_3.sroa.0.0.i104 = select i1 %_9.i102, i64 %_10.i103, i64 %_8.sroa.0.0.i101
  %_176.1 = icmp ult i64 %_242, %_3.sroa.0.0.i104
  %_176.0 = sub i64 %_242, %_3.sroa.0.0.i104
  %93 = add i64 %_176.0, -4294967295
  %_177.sroa.0.0 = select i1 %_176.1, i64 %93, i64 %_176.0
  %_12.i445 = zext i64 %_177.sroa.0.0 to i128
  %_17.i454 = mul nuw i128 %_12.i445, %_14.i448
  %_4.i796 = lshr i128 %_17.i454, 64
  %x_hi.i797 = trunc nuw i128 %_4.i796 to i64
  %x_hi_hi.i798 = lshr i64 %x_hi.i797, 32
  %x_lo.i795 = trunc i128 %_17.i454 to i64
  %_9.1.i801 = icmp ugt i64 %x_hi_hi.i798, %x_lo.i795
  %_9.0.i800 = sub i64 %x_lo.i795, %x_hi_hi.i798
  %_10.i802 = add i64 %_9.0.i800, -4294967295
  %spec.select.i803 = select i1 %_9.1.i801, i64 %_10.i802, i64 %_9.0.i800
  %x_hi_lo.i799 = and i64 %x_hi.i797, 4294967295
  %t1.i804 = mul nuw i64 %x_hi_lo.i799, 4294967295
  %_14.0.i805 = add i64 %spec.select.i803, %t1.i804
  %_14.1.i806 = icmp ult i64 %_14.0.i805, %spec.select.i803
  %94 = add i64 %_14.0.i805, 4294967295
  %res.sroa.0.0.i807 = select i1 %_14.1.i806, i64 %94, i64 %_14.0.i805
  %_16.i808 = icmp ugt i64 %res.sroa.0.0.i807, -4294967296
  %_17.i809 = add nsw i64 %res.sroa.0.0.i807, 4294967295
  %_0.sroa.0.0.i810 = select i1 %_16.i808, i64 %_17.i809, i64 %res.sroa.0.0.i807
  %_29.0.i465 = add i64 %_0.sroa.0.0.i810, %_0.sroa.0.0.i826
  %_29.1.i466 = icmp ult i64 %_29.0.i465, %_0.sroa.0.0.i826
  %95 = add nuw i64 %_29.0.i465, 4294967295
  %_30.sroa.0.0.i467 = select i1 %_29.1.i466, i64 %95, i64 %_29.0.i465
  %_31.i468 = icmp ugt i64 %_30.sroa.0.0.i467, -4294967296
  %_32.i469 = add nsw i64 %_30.sroa.0.0.i467, 4294967295
  %_9.sroa.0.0.i470 = select i1 %_31.i468, i64 %_32.i469, i64 %_30.sroa.0.0.i467
  %_15.i422 = zext i64 %_9.sroa.0.0.i470 to i128
  %_16.i425 = mul nuw i128 %_11.i417, %_15.i422
  %_4.i892 = lshr i128 %_16.i425, 64
  %x_hi.i893 = trunc nuw i128 %_4.i892 to i64
  %x_hi_hi.i894 = lshr i64 %x_hi.i893, 32
  %x_lo.i891 = trunc i128 %_16.i425 to i64
  %_9.1.i897 = icmp ugt i64 %x_hi_hi.i894, %x_lo.i891
  %_9.0.i896 = sub i64 %x_lo.i891, %x_hi_hi.i894
  %_10.i898 = add i64 %_9.0.i896, -4294967295
  %spec.select.i899 = select i1 %_9.1.i897, i64 %_10.i898, i64 %_9.0.i896
  %x_hi_lo.i895 = and i64 %x_hi.i893, 4294967295
  %t1.i900 = mul nuw i64 %x_hi_lo.i895, 4294967295
  %_14.0.i901 = add i64 %spec.select.i899, %t1.i900
  %_14.1.i902 = icmp ult i64 %_14.0.i901, %spec.select.i899
  %96 = add i64 %_14.0.i901, 4294967295
  %res.sroa.0.0.i903 = select i1 %_14.1.i902, i64 %96, i64 %_14.0.i901
  %_16.i904 = icmp ugt i64 %res.sroa.0.0.i903, -4294967296
  %_17.i905 = add nsw i64 %res.sroa.0.0.i903, 4294967295
  %_0.sroa.0.0.i906 = select i1 %_16.i904, i64 %_17.i905, i64 %res.sroa.0.0.i903
  %_14.i421 = zext i64 %_52.1 to i128
  %_10.i446 = mul nuw i128 %_12.i445, %_11.i444
  %_4.i844 = lshr i128 %_10.i446, 64
  %x_hi.i845 = trunc nuw i128 %_4.i844 to i64
  %x_hi_hi.i846 = lshr i64 %x_hi.i845, 32
  %x_lo.i843 = trunc i128 %_10.i446 to i64
  %_9.1.i849 = icmp ugt i64 %x_hi_hi.i846, %x_lo.i843
  %_9.0.i848 = sub i64 %x_lo.i843, %x_hi_hi.i846
  %_10.i850 = add i64 %_9.0.i848, -4294967295
  %spec.select.i851 = select i1 %_9.1.i849, i64 %_10.i850, i64 %_9.0.i848
  %x_hi_lo.i847 = and i64 %x_hi.i845, 4294967295
  %t1.i852 = mul nuw i64 %x_hi_lo.i847, 4294967295
  %_14.0.i853 = add i64 %spec.select.i851, %t1.i852
  %_14.1.i854 = icmp ult i64 %_14.0.i853, %spec.select.i851
  %97 = add i64 %_14.0.i853, 4294967295
  %res.sroa.0.0.i855 = select i1 %_14.1.i854, i64 %97, i64 %_14.0.i853
  %_16.i856 = icmp ugt i64 %res.sroa.0.0.i855, -4294967296
  %_17.i857 = add nsw i64 %res.sroa.0.0.i855, 4294967295
  %_0.sroa.0.0.i858 = select i1 %_16.i856, i64 %_17.i857, i64 %res.sroa.0.0.i855
  %_13.i450 = mul nuw i128 %_15.i449, %_14.i448
  %_4.i828 = lshr i128 %_13.i450, 64
  %x_hi.i829 = trunc nuw i128 %_4.i828 to i64
  %x_hi_hi.i830 = lshr i64 %x_hi.i829, 32
  %x_lo.i827 = trunc i128 %_13.i450 to i64
  %_9.1.i833 = icmp ugt i64 %x_hi_hi.i830, %x_lo.i827
  %_9.0.i832 = sub i64 %x_lo.i827, %x_hi_hi.i830
  %_10.i834 = add i64 %_9.0.i832, -4294967295
  %spec.select.i835 = select i1 %_9.1.i833, i64 %_10.i834, i64 %_9.0.i832
  %x_hi_lo.i831 = and i64 %x_hi.i829, 4294967295
  %t1.i836 = mul nuw i64 %x_hi_lo.i831, 4294967295
  %_14.0.i837 = add i64 %spec.select.i835, %t1.i836
  %_14.1.i838 = icmp ult i64 %_14.0.i837, %spec.select.i835
  %98 = add i64 %_14.0.i837, 4294967295
  %res.sroa.0.0.i839 = select i1 %_14.1.i838, i64 %98, i64 %_14.0.i837
  %_16.i840 = icmp ugt i64 %res.sroa.0.0.i839, -4294967296
  %_17.i841 = add nsw i64 %res.sroa.0.0.i839, 4294967295
  %_0.sroa.0.0.i842 = select i1 %_16.i840, i64 %_17.i841, i64 %res.sroa.0.0.i839
  %_19.i456 = zext i64 %_0.sroa.0.0.i842 to i128
  %_18.i457 = mul nuw nsw i128 %_19.i456, 7
  %_4.i780 = lshr i128 %_18.i457, 64
  %x_hi.i781 = trunc nuw nsw i128 %_4.i780 to i64
  %t1.i788 = mul nuw nsw i64 %x_hi.i781, 4294967295
  %x_lo.i779 = trunc i128 %_18.i457 to i64
  %_14.0.i789 = add i64 %t1.i788, %x_lo.i779
  %_14.1.i790 = icmp ult i64 %_14.0.i789, %x_lo.i779
  %99 = add i64 %_14.0.i789, 4294967295
  %res.sroa.0.0.i791 = select i1 %_14.1.i790, i64 %99, i64 %_14.0.i789
  %_16.i792 = icmp ugt i64 %res.sroa.0.0.i791, -4294967296
  %_17.i793 = add nsw i64 %res.sroa.0.0.i791, 4294967295
  %_0.sroa.0.0.i794 = select i1 %_16.i792, i64 %_17.i793, i64 %res.sroa.0.0.i791
  %_22.0.i459 = add i64 %_0.sroa.0.0.i858, %_0.sroa.0.0.i794
  %_22.1.i460 = icmp ult i64 %_22.0.i459, %_0.sroa.0.0.i858
  %100 = add nuw i64 %_22.0.i459, 4294967295
  %_24.sroa.0.0.i461 = select i1 %_22.1.i460, i64 %100, i64 %_22.0.i459
  %_25.i462 = icmp ugt i64 %_24.sroa.0.0.i461, -4294967296
  %_26.i463 = add nsw i64 %_24.sroa.0.0.i461, 4294967295
  %_7.sroa.0.0.i464 = select i1 %_25.i462, i64 %_26.i463, i64 %_24.sroa.0.0.i461
  %_188.1 = icmp eq i64 %_7.sroa.0.0.i464, 0
  %_188.0 = add i64 %_7.sroa.0.0.i464, -1
  %_189.sroa.0.0 = select i1 %_188.1, i64 -4294967296, i64 %_188.0
  %_12.i418 = zext i64 %_189.sroa.0.0 to i128
  %_17.i427 = mul nuw i128 %_14.i421, %_12.i418
  %_4.i876 = lshr i128 %_17.i427, 64
  %x_hi.i877 = trunc nuw i128 %_4.i876 to i64
  %x_hi_hi.i878 = lshr i64 %x_hi.i877, 32
  %x_lo.i875 = trunc i128 %_17.i427 to i64
  %_9.1.i881 = icmp ugt i64 %x_hi_hi.i878, %x_lo.i875
  %_9.0.i880 = sub i64 %x_lo.i875, %x_hi_hi.i878
  %_10.i882 = add i64 %_9.0.i880, -4294967295
  %spec.select.i883 = select i1 %_9.1.i881, i64 %_10.i882, i64 %_9.0.i880
  %x_hi_lo.i879 = and i64 %x_hi.i877, 4294967295
  %t1.i884 = mul nuw i64 %x_hi_lo.i879, 4294967295
  %_14.0.i885 = add i64 %spec.select.i883, %t1.i884
  %_14.1.i886 = icmp ult i64 %_14.0.i885, %spec.select.i883
  %101 = add i64 %_14.0.i885, 4294967295
  %res.sroa.0.0.i887 = select i1 %_14.1.i886, i64 %101, i64 %_14.0.i885
  %_16.i888 = icmp ugt i64 %res.sroa.0.0.i887, -4294967296
  %_17.i889 = add nsw i64 %res.sroa.0.0.i887, 4294967295
  %_0.sroa.0.0.i890 = select i1 %_16.i888, i64 %_17.i889, i64 %res.sroa.0.0.i887
  %_29.0.i438 = add i64 %_0.sroa.0.0.i890, %_0.sroa.0.0.i906
  %_29.1.i439 = icmp ult i64 %_29.0.i438, %_0.sroa.0.0.i906
  %102 = add nuw i64 %_29.0.i438, 4294967295
  %_30.sroa.0.0.i440 = select i1 %_29.1.i439, i64 %102, i64 %_29.0.i438
  %_31.i441 = icmp ugt i64 %_30.sroa.0.0.i440, -4294967296
  %_32.i442 = add nsw i64 %_30.sroa.0.0.i440, 4294967295
  %_9.sroa.0.0.i443 = select i1 %_31.i441, i64 %_32.i442, i64 %_30.sroa.0.0.i440
  %_13.0.i93 = add i64 %_9.sroa.0.0.i443, %_46.1
  %_13.1.i94 = icmp ult i64 %_13.0.i93, %_46.1
  %103 = add i64 %_13.0.i93, 4294967295
  %_14.sroa.0.0.i95 = select i1 %_13.1.i94, i64 %103, i64 %_13.0.i93
  %_15.i96 = icmp ugt i64 %_14.sroa.0.0.i95, -4294967296
  %_16.i97 = add nsw i64 %_14.sroa.0.0.i95, 4294967295
  %_4.sroa.0.0.i98 = select i1 %_15.i96, i64 %_16.i97, i64 %_14.sroa.0.0.i95
  %_54.1 = extractvalue { i64, i64 } %67, 1
  %_13.0.i81 = add i64 %_4.sroa.0.0.i98, %_54.1
  %_13.1.i82 = icmp ult i64 %_13.0.i81, %_4.sroa.0.0.i98
  %104 = add i64 %_13.0.i81, 4294967295
  %_14.sroa.0.0.i83 = select i1 %_13.1.i82, i64 %104, i64 %_13.0.i81
  %_15.i84 = icmp ugt i64 %_14.sroa.0.0.i83, -4294967296
  %_16.i85 = add nsw i64 %_14.sroa.0.0.i83, 4294967295
  %_4.sroa.0.0.i86 = select i1 %_15.i84, i64 %_16.i85, i64 %_14.sroa.0.0.i83
  %_11.i390 = zext i64 %g.sroa.0.0 to i128
  %_15.i395 = zext i64 %clauses.sroa.4.0.lcssa.ph to i128
  %_16.i398 = mul nuw i128 %_15.i395, %_11.i390
  %_4.i972 = lshr i128 %_16.i398, 64
  %x_hi.i973 = trunc nuw i128 %_4.i972 to i64
  %x_hi_hi.i974 = lshr i64 %x_hi.i973, 32
  %x_lo.i971 = trunc i128 %_16.i398 to i64
  %_9.1.i977 = icmp ugt i64 %x_hi_hi.i974, %x_lo.i971
  %_9.0.i976 = sub i64 %x_lo.i971, %x_hi_hi.i974
  %_10.i978 = add i64 %_9.0.i976, -4294967295
  %spec.select.i979 = select i1 %_9.1.i977, i64 %_10.i978, i64 %_9.0.i976
  %x_hi_lo.i975 = and i64 %x_hi.i973, 4294967295
  %t1.i980 = mul nuw i64 %x_hi_lo.i975, 4294967295
  %_14.0.i981 = add i64 %spec.select.i979, %t1.i980
  %_14.1.i982 = icmp ult i64 %_14.0.i981, %spec.select.i979
  %105 = add i64 %_14.0.i981, 4294967295
  %res.sroa.0.0.i983 = select i1 %_14.1.i982, i64 %105, i64 %_14.0.i981
  %_16.i984 = icmp ugt i64 %res.sroa.0.0.i983, -4294967296
  %_17.i985 = add nsw i64 %res.sroa.0.0.i983, 4294967295
  %_0.sroa.0.0.i986 = select i1 %_16.i984, i64 %_17.i985, i64 %res.sroa.0.0.i983
  %_14.i394 = zext i64 %g.sroa.5.0 to i128
  %_12.i391 = zext i64 %clauses.sroa.0.0.lcssa.ph to i128
  %_17.i400 = mul nuw i128 %_12.i391, %_14.i394
  %_4.i956 = lshr i128 %_17.i400, 64
  %x_hi.i957 = trunc nuw i128 %_4.i956 to i64
  %x_hi_hi.i958 = lshr i64 %x_hi.i957, 32
  %x_lo.i955 = trunc i128 %_17.i400 to i64
  %_9.1.i961 = icmp ugt i64 %x_hi_hi.i958, %x_lo.i955
  %_9.0.i960 = sub i64 %x_lo.i955, %x_hi_hi.i958
  %_10.i962 = add i64 %_9.0.i960, -4294967295
  %spec.select.i963 = select i1 %_9.1.i961, i64 %_10.i962, i64 %_9.0.i960
  %x_hi_lo.i959 = and i64 %x_hi.i957, 4294967295
  %t1.i964 = mul nuw i64 %x_hi_lo.i959, 4294967295
  %_14.0.i965 = add i64 %spec.select.i963, %t1.i964
  %_14.1.i966 = icmp ult i64 %_14.0.i965, %spec.select.i963
  %106 = add i64 %_14.0.i965, 4294967295
  %res.sroa.0.0.i967 = select i1 %_14.1.i966, i64 %106, i64 %_14.0.i965
  %_16.i968 = icmp ugt i64 %res.sroa.0.0.i967, -4294967296
  %_17.i969 = add nsw i64 %res.sroa.0.0.i967, 4294967295
  %_0.sroa.0.0.i970 = select i1 %_16.i968, i64 %_17.i969, i64 %res.sroa.0.0.i967
  %_29.0.i411 = add i64 %_0.sroa.0.0.i970, %_0.sroa.0.0.i986
  %_29.1.i412 = icmp ult i64 %_29.0.i411, %_0.sroa.0.0.i986
  %107 = add nuw i64 %_29.0.i411, 4294967295
  %_30.sroa.0.0.i413 = select i1 %_29.1.i412, i64 %107, i64 %_29.0.i411
  %_31.i414 = icmp ugt i64 %_30.sroa.0.0.i413, -4294967296
  %_32.i415 = add nsw i64 %_30.sroa.0.0.i413, 4294967295
  %_9.sroa.0.0.i416 = select i1 %_31.i414, i64 %_32.i415, i64 %_30.sroa.0.0.i413
  %_13.0.i69 = add i64 %_9.sroa.0.0.i416, %_4.sroa.0.0.i86
  %_13.1.i70 = icmp ult i64 %_13.0.i69, %_4.sroa.0.0.i86
  %108 = add i64 %_13.0.i69, 4294967295
  %_14.sroa.0.0.i71 = select i1 %_13.1.i70, i64 %108, i64 %_13.0.i69
  %_15.i72 = icmp ugt i64 %_14.sroa.0.0.i71, -4294967296
  %_16.i73 = add nsw i64 %_14.sroa.0.0.i71, 4294967295
  %_4.sroa.0.0.i74 = select i1 %_15.i72, i64 %_16.i73, i64 %_14.sroa.0.0.i71
  %_15.i341 = zext i64 %_4.sroa.0.0.i74 to i128
  %_16.i344 = mul nuw i128 %_11.i336, %_15.i341
  %_4.i1132 = lshr i128 %_16.i344, 64
  %x_hi.i1133 = trunc nuw i128 %_4.i1132 to i64
  %x_hi_hi.i1134 = lshr i64 %x_hi.i1133, 32
  %x_lo.i1131 = trunc i128 %_16.i344 to i64
  %_9.1.i1137 = icmp ugt i64 %x_hi_hi.i1134, %x_lo.i1131
  %_9.0.i1136 = sub i64 %x_lo.i1131, %x_hi_hi.i1134
  %_10.i1138 = add i64 %_9.0.i1136, -4294967295
  %spec.select.i1139 = select i1 %_9.1.i1137, i64 %_10.i1138, i64 %_9.0.i1136
  %x_hi_lo.i1135 = and i64 %x_hi.i1133, 4294967295
  %t1.i1140 = mul nuw i64 %x_hi_lo.i1135, 4294967295
  %_14.0.i1141 = add i64 %spec.select.i1139, %t1.i1140
  %_14.1.i1142 = icmp ult i64 %_14.0.i1141, %spec.select.i1139
  %109 = add i64 %_14.0.i1141, 4294967295
  %res.sroa.0.0.i1143 = select i1 %_14.1.i1142, i64 %109, i64 %_14.0.i1141
  %_16.i1144 = icmp ugt i64 %res.sroa.0.0.i1143, -4294967296
  %_17.i1145 = add nsw i64 %res.sroa.0.0.i1143, 4294967295
  %_0.sroa.0.0.i1146 = select i1 %_16.i1144, i64 %_17.i1145, i64 %res.sroa.0.0.i1143
  %_14.i340 = zext i64 %_79.1 to i128
  %_46.0 = extractvalue { i64, i64 } %65, 0
  %_10.i419 = mul nuw i128 %_11.i417, %_12.i418
  %_4.i924 = lshr i128 %_10.i419, 64
  %x_hi.i925 = trunc nuw i128 %_4.i924 to i64
  %x_hi_hi.i926 = lshr i64 %x_hi.i925, 32
  %x_lo.i923 = trunc i128 %_10.i419 to i64
  %_9.1.i929 = icmp ugt i64 %x_hi_hi.i926, %x_lo.i923
  %_9.0.i928 = sub i64 %x_lo.i923, %x_hi_hi.i926
  %_10.i930 = add i64 %_9.0.i928, -4294967295
  %spec.select.i931 = select i1 %_9.1.i929, i64 %_10.i930, i64 %_9.0.i928
  %x_hi_lo.i927 = and i64 %x_hi.i925, 4294967295
  %t1.i932 = mul nuw i64 %x_hi_lo.i927, 4294967295
  %_14.0.i933 = add i64 %spec.select.i931, %t1.i932
  %_14.1.i934 = icmp ult i64 %_14.0.i933, %spec.select.i931
  %110 = add i64 %_14.0.i933, 4294967295
  %res.sroa.0.0.i935 = select i1 %_14.1.i934, i64 %110, i64 %_14.0.i933
  %_16.i936 = icmp ugt i64 %res.sroa.0.0.i935, -4294967296
  %_17.i937 = add nsw i64 %res.sroa.0.0.i935, 4294967295
  %_0.sroa.0.0.i938 = select i1 %_16.i936, i64 %_17.i937, i64 %res.sroa.0.0.i935
  %_13.i423 = mul nuw i128 %_14.i421, %_15.i422
  %_4.i908 = lshr i128 %_13.i423, 64
  %x_hi.i909 = trunc nuw i128 %_4.i908 to i64
  %x_hi_hi.i910 = lshr i64 %x_hi.i909, 32
  %x_lo.i907 = trunc i128 %_13.i423 to i64
  %_9.1.i913 = icmp ugt i64 %x_hi_hi.i910, %x_lo.i907
  %_9.0.i912 = sub i64 %x_lo.i907, %x_hi_hi.i910
  %_10.i914 = add i64 %_9.0.i912, -4294967295
  %spec.select.i915 = select i1 %_9.1.i913, i64 %_10.i914, i64 %_9.0.i912
  %x_hi_lo.i911 = and i64 %x_hi.i909, 4294967295
  %t1.i916 = mul nuw i64 %x_hi_lo.i911, 4294967295
  %_14.0.i917 = add i64 %spec.select.i915, %t1.i916
  %_14.1.i918 = icmp ult i64 %_14.0.i917, %spec.select.i915
  %111 = add i64 %_14.0.i917, 4294967295
  %res.sroa.0.0.i919 = select i1 %_14.1.i918, i64 %111, i64 %_14.0.i917
  %_16.i920 = icmp ugt i64 %res.sroa.0.0.i919, -4294967296
  %_17.i921 = add nsw i64 %res.sroa.0.0.i919, 4294967295
  %_0.sroa.0.0.i922 = select i1 %_16.i920, i64 %_17.i921, i64 %res.sroa.0.0.i919
  %_19.i429 = zext i64 %_0.sroa.0.0.i922 to i128
  %_18.i430 = mul nuw nsw i128 %_19.i429, 7
  %_4.i860 = lshr i128 %_18.i430, 64
  %x_hi.i861 = trunc nuw nsw i128 %_4.i860 to i64
  %t1.i868 = mul nuw nsw i64 %x_hi.i861, 4294967295
  %x_lo.i859 = trunc i128 %_18.i430 to i64
  %_14.0.i869 = add i64 %t1.i868, %x_lo.i859
  %_14.1.i870 = icmp ult i64 %_14.0.i869, %x_lo.i859
  %112 = add i64 %_14.0.i869, 4294967295
  %res.sroa.0.0.i871 = select i1 %_14.1.i870, i64 %112, i64 %_14.0.i869
  %_16.i872 = icmp ugt i64 %res.sroa.0.0.i871, -4294967296
  %_17.i873 = add nsw i64 %res.sroa.0.0.i871, 4294967295
  %_0.sroa.0.0.i874 = select i1 %_16.i872, i64 %_17.i873, i64 %res.sroa.0.0.i871
  %_22.0.i432 = add i64 %_0.sroa.0.0.i874, %_0.sroa.0.0.i938
  %_22.1.i433 = icmp ult i64 %_22.0.i432, %_0.sroa.0.0.i938
  %113 = add nuw i64 %_22.0.i432, 4294967295
  %_24.sroa.0.0.i434 = select i1 %_22.1.i433, i64 %113, i64 %_22.0.i432
  %_25.i435 = icmp ugt i64 %_24.sroa.0.0.i434, -4294967296
  %_26.i436 = add nsw i64 %_24.sroa.0.0.i434, 4294967295
  %_7.sroa.0.0.i437 = select i1 %_25.i435, i64 %_26.i436, i64 %_24.sroa.0.0.i434
  %_7.0.i87 = add i64 %_7.sroa.0.0.i437, %_46.0
  %_7.1.i88 = icmp ult i64 %_7.0.i87, %_46.0
  %114 = add i64 %_7.0.i87, 4294967295
  %_8.sroa.0.0.i89 = select i1 %_7.1.i88, i64 %114, i64 %_7.0.i87
  %_9.i90 = icmp ugt i64 %_8.sroa.0.0.i89, -4294967296
  %_10.i91 = add nsw i64 %_8.sroa.0.0.i89, 4294967295
  %_3.sroa.0.0.i92 = select i1 %_9.i90, i64 %_10.i91, i64 %_8.sroa.0.0.i89
  %_54.0 = extractvalue { i64, i64 } %67, 0
  %_7.0.i75 = add i64 %_3.sroa.0.0.i92, %_54.0
  %_7.1.i76 = icmp ult i64 %_7.0.i75, %_3.sroa.0.0.i92
  %115 = add i64 %_7.0.i75, 4294967295
  %_8.sroa.0.0.i77 = select i1 %_7.1.i76, i64 %115, i64 %_7.0.i75
  %_9.i78 = icmp ugt i64 %_8.sroa.0.0.i77, -4294967296
  %_10.i79 = add nsw i64 %_8.sroa.0.0.i77, 4294967295
  %_3.sroa.0.0.i80 = select i1 %_9.i78, i64 %_10.i79, i64 %_8.sroa.0.0.i77
  %_10.i392 = mul nuw i128 %_12.i391, %_11.i390
  %_4.i1004 = lshr i128 %_10.i392, 64
  %x_hi.i1005 = trunc nuw i128 %_4.i1004 to i64
  %x_hi_hi.i1006 = lshr i64 %x_hi.i1005, 32
  %x_lo.i1003 = trunc i128 %_10.i392 to i64
  %_9.1.i1009 = icmp ugt i64 %x_hi_hi.i1006, %x_lo.i1003
  %_9.0.i1008 = sub i64 %x_lo.i1003, %x_hi_hi.i1006
  %_10.i1010 = add i64 %_9.0.i1008, -4294967295
  %spec.select.i1011 = select i1 %_9.1.i1009, i64 %_10.i1010, i64 %_9.0.i1008
  %x_hi_lo.i1007 = and i64 %x_hi.i1005, 4294967295
  %t1.i1012 = mul nuw i64 %x_hi_lo.i1007, 4294967295
  %_14.0.i1013 = add i64 %spec.select.i1011, %t1.i1012
  %_14.1.i1014 = icmp ult i64 %_14.0.i1013, %spec.select.i1011
  %116 = add i64 %_14.0.i1013, 4294967295
  %res.sroa.0.0.i1015 = select i1 %_14.1.i1014, i64 %116, i64 %_14.0.i1013
  %_16.i1016 = icmp ugt i64 %res.sroa.0.0.i1015, -4294967296
  %_17.i1017 = add nsw i64 %res.sroa.0.0.i1015, 4294967295
  %_0.sroa.0.0.i1018 = select i1 %_16.i1016, i64 %_17.i1017, i64 %res.sroa.0.0.i1015
  %_13.i396 = mul nuw i128 %_15.i395, %_14.i394
  %_4.i988 = lshr i128 %_13.i396, 64
  %x_hi.i989 = trunc nuw i128 %_4.i988 to i64
  %x_hi_hi.i990 = lshr i64 %x_hi.i989, 32
  %x_lo.i987 = trunc i128 %_13.i396 to i64
  %_9.1.i993 = icmp ugt i64 %x_hi_hi.i990, %x_lo.i987
  %_9.0.i992 = sub i64 %x_lo.i987, %x_hi_hi.i990
  %_10.i994 = add i64 %_9.0.i992, -4294967295
  %spec.select.i995 = select i1 %_9.1.i993, i64 %_10.i994, i64 %_9.0.i992
  %x_hi_lo.i991 = and i64 %x_hi.i989, 4294967295
  %t1.i996 = mul nuw i64 %x_hi_lo.i991, 4294967295
  %_14.0.i997 = add i64 %spec.select.i995, %t1.i996
  %_14.1.i998 = icmp ult i64 %_14.0.i997, %spec.select.i995
  %117 = add i64 %_14.0.i997, 4294967295
  %res.sroa.0.0.i999 = select i1 %_14.1.i998, i64 %117, i64 %_14.0.i997
  %_16.i1000 = icmp ugt i64 %res.sroa.0.0.i999, -4294967296
  %_17.i1001 = add nsw i64 %res.sroa.0.0.i999, 4294967295
  %_0.sroa.0.0.i1002 = select i1 %_16.i1000, i64 %_17.i1001, i64 %res.sroa.0.0.i999
  %_19.i402 = zext i64 %_0.sroa.0.0.i1002 to i128
  %_18.i403 = mul nuw nsw i128 %_19.i402, 7
  %_4.i940 = lshr i128 %_18.i403, 64
  %x_hi.i941 = trunc nuw nsw i128 %_4.i940 to i64
  %t1.i948 = mul nuw nsw i64 %x_hi.i941, 4294967295
  %x_lo.i939 = trunc i128 %_18.i403 to i64
  %_14.0.i949 = add i64 %t1.i948, %x_lo.i939
  %_14.1.i950 = icmp ult i64 %_14.0.i949, %x_lo.i939
  %118 = add i64 %_14.0.i949, 4294967295
  %res.sroa.0.0.i951 = select i1 %_14.1.i950, i64 %118, i64 %_14.0.i949
  %_16.i952 = icmp ugt i64 %res.sroa.0.0.i951, -4294967296
  %_17.i953 = add nsw i64 %res.sroa.0.0.i951, 4294967295
  %_0.sroa.0.0.i954 = select i1 %_16.i952, i64 %_17.i953, i64 %res.sroa.0.0.i951
  %_22.0.i405 = add i64 %_0.sroa.0.0.i954, %_0.sroa.0.0.i1018
  %_22.1.i406 = icmp ult i64 %_22.0.i405, %_0.sroa.0.0.i1018
  %119 = add nuw i64 %_22.0.i405, 4294967295
  %_24.sroa.0.0.i407 = select i1 %_22.1.i406, i64 %119, i64 %_22.0.i405
  %_25.i408 = icmp ugt i64 %_24.sroa.0.0.i407, -4294967296
  %_26.i409 = add nsw i64 %_24.sroa.0.0.i407, 4294967295
  %_7.sroa.0.0.i410 = select i1 %_25.i408, i64 %_26.i409, i64 %_24.sroa.0.0.i407
  %_7.0.i63 = add i64 %_7.sroa.0.0.i410, %_3.sroa.0.0.i80
  %_7.1.i64 = icmp ult i64 %_7.0.i63, %_3.sroa.0.0.i80
  %120 = add i64 %_7.0.i63, 4294967295
  %_8.sroa.0.0.i65 = select i1 %_7.1.i64, i64 %120, i64 %_7.0.i63
  %_9.i66 = icmp ugt i64 %_8.sroa.0.0.i65, -4294967296
  %_10.i67 = add nsw i64 %_8.sroa.0.0.i65, 4294967295
  %_3.sroa.0.0.i68 = select i1 %_9.i66, i64 %_10.i67, i64 %_8.sroa.0.0.i65
  %_12.i337 = zext i64 %_3.sroa.0.0.i68 to i128
  %_17.i346 = mul nuw i128 %_14.i340, %_12.i337
  %_4.i1116 = lshr i128 %_17.i346, 64
  %x_hi.i1117 = trunc nuw i128 %_4.i1116 to i64
  %x_hi_hi.i1118 = lshr i64 %x_hi.i1117, 32
  %x_lo.i1115 = trunc i128 %_17.i346 to i64
  %_9.1.i1121 = icmp ugt i64 %x_hi_hi.i1118, %x_lo.i1115
  %_9.0.i1120 = sub i64 %x_lo.i1115, %x_hi_hi.i1118
  %_10.i1122 = add i64 %_9.0.i1120, -4294967295
  %spec.select.i1123 = select i1 %_9.1.i1121, i64 %_10.i1122, i64 %_9.0.i1120
  %x_hi_lo.i1119 = and i64 %x_hi.i1117, 4294967295
  %t1.i1124 = mul nuw i64 %x_hi_lo.i1119, 4294967295
  %_14.0.i1125 = add i64 %spec.select.i1123, %t1.i1124
  %_14.1.i1126 = icmp ult i64 %_14.0.i1125, %spec.select.i1123
  %121 = add i64 %_14.0.i1125, 4294967295
  %res.sroa.0.0.i1127 = select i1 %_14.1.i1126, i64 %121, i64 %_14.0.i1125
  %_16.i1128 = icmp ugt i64 %res.sroa.0.0.i1127, -4294967296
  %_17.i1129 = add nsw i64 %res.sroa.0.0.i1127, 4294967295
  %_0.sroa.0.0.i1130 = select i1 %_16.i1128, i64 %_17.i1129, i64 %res.sroa.0.0.i1127
  %_29.0.i357 = add i64 %_0.sroa.0.0.i1130, %_0.sroa.0.0.i1146
  %_29.1.i358 = icmp ult i64 %_29.0.i357, %_0.sroa.0.0.i1146
  %122 = add nuw i64 %_29.0.i357, 4294967295
  %_30.sroa.0.0.i359 = select i1 %_29.1.i358, i64 %122, i64 %_29.0.i357
  %_31.i360 = icmp ugt i64 %_30.sroa.0.0.i359, -4294967296
  %_32.i361 = add nsw i64 %_30.sroa.0.0.i359, 4294967295
  %_9.sroa.0.0.i362 = select i1 %_31.i360, i64 %_32.i361, i64 %_30.sroa.0.0.i359
  %_11.i309 = zext i64 %_84.0 to i128
  %_12.i310 = zext i64 %_86.0 to i128
  %_10.i311 = mul nuw i128 %_12.i310, %_11.i309
  %_4.i1244 = lshr i128 %_10.i311, 64
  %x_hi.i1245 = trunc nuw i128 %_4.i1244 to i64
  %x_hi_hi.i1246 = lshr i64 %x_hi.i1245, 32
  %x_lo.i1243 = trunc i128 %_10.i311 to i64
  %_9.1.i1249 = icmp ugt i64 %x_hi_hi.i1246, %x_lo.i1243
  %_9.0.i1248 = sub i64 %x_lo.i1243, %x_hi_hi.i1246
  %_10.i1250 = add i64 %_9.0.i1248, -4294967295
  %spec.select.i1251 = select i1 %_9.1.i1249, i64 %_10.i1250, i64 %_9.0.i1248
  %x_hi_lo.i1247 = and i64 %x_hi.i1245, 4294967295
  %t1.i1252 = mul nuw i64 %x_hi_lo.i1247, 4294967295
  %_14.0.i1253 = add i64 %spec.select.i1251, %t1.i1252
  %_14.1.i1254 = icmp ult i64 %_14.0.i1253, %spec.select.i1251
  %123 = add i64 %_14.0.i1253, 4294967295
  %res.sroa.0.0.i1255 = select i1 %_14.1.i1254, i64 %123, i64 %_14.0.i1253
  %_16.i1256 = icmp ugt i64 %res.sroa.0.0.i1255, -4294967296
  %_17.i1257 = add nsw i64 %res.sroa.0.0.i1255, 4294967295
  %_0.sroa.0.0.i1258 = select i1 %_16.i1256, i64 %_17.i1257, i64 %res.sroa.0.0.i1255
  %_14.i313 = zext i64 %_84.1 to i128
  %_15.i314 = zext i64 %_86.1 to i128
  %_13.i315 = mul nuw i128 %_15.i314, %_14.i313
  %_4.i1228 = lshr i128 %_13.i315, 64
  %x_hi.i1229 = trunc nuw i128 %_4.i1228 to i64
  %x_hi_hi.i1230 = lshr i64 %x_hi.i1229, 32
  %x_lo.i1227 = trunc i128 %_13.i315 to i64
  %_9.1.i1233 = icmp ugt i64 %x_hi_hi.i1230, %x_lo.i1227
  %_9.0.i1232 = sub i64 %x_lo.i1227, %x_hi_hi.i1230
  %_10.i1234 = add i64 %_9.0.i1232, -4294967295
  %spec.select.i1235 = select i1 %_9.1.i1233, i64 %_10.i1234, i64 %_9.0.i1232
  %x_hi_lo.i1231 = and i64 %x_hi.i1229, 4294967295
  %t1.i1236 = mul nuw i64 %x_hi_lo.i1231, 4294967295
  %_14.0.i1237 = add i64 %spec.select.i1235, %t1.i1236
  %_14.1.i1238 = icmp ult i64 %_14.0.i1237, %spec.select.i1235
  %124 = add i64 %_14.0.i1237, 4294967295
  %res.sroa.0.0.i1239 = select i1 %_14.1.i1238, i64 %124, i64 %_14.0.i1237
  %_16.i1240 = icmp ugt i64 %res.sroa.0.0.i1239, -4294967296
  %_17.i1241 = add nsw i64 %res.sroa.0.0.i1239, 4294967295
  %_0.sroa.0.0.i1242 = select i1 %_16.i1240, i64 %_17.i1241, i64 %res.sroa.0.0.i1239
  %_19.i321 = zext i64 %_0.sroa.0.0.i1242 to i128
  %_18.i322 = mul nuw nsw i128 %_19.i321, 7
  %_4.i1180 = lshr i128 %_18.i322, 64
  %x_hi.i1181 = trunc nuw nsw i128 %_4.i1180 to i64
  %t1.i1188 = mul nuw nsw i64 %x_hi.i1181, 4294967295
  %x_lo.i1179 = trunc i128 %_18.i322 to i64
  %_14.0.i1189 = add i64 %t1.i1188, %x_lo.i1179
  %_14.1.i1190 = icmp ult i64 %_14.0.i1189, %x_lo.i1179
  %125 = add i64 %_14.0.i1189, 4294967295
  %res.sroa.0.0.i1191 = select i1 %_14.1.i1190, i64 %125, i64 %_14.0.i1189
  %_16.i1192 = icmp ugt i64 %res.sroa.0.0.i1191, -4294967296
  %_17.i1193 = add nsw i64 %res.sroa.0.0.i1191, 4294967295
  %_0.sroa.0.0.i1194 = select i1 %_16.i1192, i64 %_17.i1193, i64 %res.sroa.0.0.i1191
  %_22.0.i324 = add i64 %_0.sroa.0.0.i1194, %_0.sroa.0.0.i1258
  %_22.1.i325 = icmp ult i64 %_22.0.i324, %_0.sroa.0.0.i1258
  %126 = add nuw i64 %_22.0.i324, 4294967295
  %_24.sroa.0.0.i326 = select i1 %_22.1.i325, i64 %126, i64 %_22.0.i324
  %_25.i327 = icmp ugt i64 %_24.sroa.0.0.i326, -4294967296
  %_26.i328 = add nsw i64 %_24.sroa.0.0.i326, 4294967295
  %_7.sroa.0.0.i329 = select i1 %_25.i327, i64 %_26.i328, i64 %_24.sroa.0.0.i326
  %_11.i282 = zext i64 %_7.sroa.0.0.i329 to i128
  %_10.i284 = mul nuw i128 %_11.i282, %_11.i390
  %_4.i1324 = lshr i128 %_10.i284, 64
  %x_hi.i1325 = trunc nuw i128 %_4.i1324 to i64
  %x_hi_hi.i1326 = lshr i64 %x_hi.i1325, 32
  %x_lo.i1323 = trunc i128 %_10.i284 to i64
  %_9.1.i1329 = icmp ugt i64 %x_hi_hi.i1326, %x_lo.i1323
  %_9.0.i1328 = sub i64 %x_lo.i1323, %x_hi_hi.i1326
  %_10.i1330 = add i64 %_9.0.i1328, -4294967295
  %spec.select.i1331 = select i1 %_9.1.i1329, i64 %_10.i1330, i64 %_9.0.i1328
  %x_hi_lo.i1327 = and i64 %x_hi.i1325, 4294967295
  %t1.i1332 = mul nuw i64 %x_hi_lo.i1327, 4294967295
  %_14.0.i1333 = add i64 %spec.select.i1331, %t1.i1332
  %_14.1.i1334 = icmp ult i64 %_14.0.i1333, %spec.select.i1331
  %127 = add i64 %_14.0.i1333, 4294967295
  %res.sroa.0.0.i1335 = select i1 %_14.1.i1334, i64 %127, i64 %_14.0.i1333
  %_16.i1336 = icmp ugt i64 %res.sroa.0.0.i1335, -4294967296
  %_17.i1337 = add nsw i64 %res.sroa.0.0.i1335, 4294967295
  %_0.sroa.0.0.i1338 = select i1 %_16.i1336, i64 %_17.i1337, i64 %res.sroa.0.0.i1335
  %_16.i317 = mul nuw i128 %_15.i314, %_11.i309
  %_4.i1212 = lshr i128 %_16.i317, 64
  %x_hi.i1213 = trunc nuw i128 %_4.i1212 to i64
  %x_hi_hi.i1214 = lshr i64 %x_hi.i1213, 32
  %x_lo.i1211 = trunc i128 %_16.i317 to i64
  %_9.1.i1217 = icmp ugt i64 %x_hi_hi.i1214, %x_lo.i1211
  %_9.0.i1216 = sub i64 %x_lo.i1211, %x_hi_hi.i1214
  %_10.i1218 = add i64 %_9.0.i1216, -4294967295
  %spec.select.i1219 = select i1 %_9.1.i1217, i64 %_10.i1218, i64 %_9.0.i1216
  %x_hi_lo.i1215 = and i64 %x_hi.i1213, 4294967295
  %t1.i1220 = mul nuw i64 %x_hi_lo.i1215, 4294967295
  %_14.0.i1221 = add i64 %spec.select.i1219, %t1.i1220
  %_14.1.i1222 = icmp ult i64 %_14.0.i1221, %spec.select.i1219
  %128 = add i64 %_14.0.i1221, 4294967295
  %res.sroa.0.0.i1223 = select i1 %_14.1.i1222, i64 %128, i64 %_14.0.i1221
  %_16.i1224 = icmp ugt i64 %res.sroa.0.0.i1223, -4294967296
  %_17.i1225 = add nsw i64 %res.sroa.0.0.i1223, 4294967295
  %_0.sroa.0.0.i1226 = select i1 %_16.i1224, i64 %_17.i1225, i64 %res.sroa.0.0.i1223
  %_17.i319 = mul nuw i128 %_12.i310, %_14.i313
  %_4.i1196 = lshr i128 %_17.i319, 64
  %x_hi.i1197 = trunc nuw i128 %_4.i1196 to i64
  %x_hi_hi.i1198 = lshr i64 %x_hi.i1197, 32
  %x_lo.i1195 = trunc i128 %_17.i319 to i64
  %_9.1.i1201 = icmp ugt i64 %x_hi_hi.i1198, %x_lo.i1195
  %_9.0.i1200 = sub i64 %x_lo.i1195, %x_hi_hi.i1198
  %_10.i1202 = add i64 %_9.0.i1200, -4294967295
  %spec.select.i1203 = select i1 %_9.1.i1201, i64 %_10.i1202, i64 %_9.0.i1200
  %x_hi_lo.i1199 = and i64 %x_hi.i1197, 4294967295
  %t1.i1204 = mul nuw i64 %x_hi_lo.i1199, 4294967295
  %_14.0.i1205 = add i64 %spec.select.i1203, %t1.i1204
  %_14.1.i1206 = icmp ult i64 %_14.0.i1205, %spec.select.i1203
  %129 = add i64 %_14.0.i1205, 4294967295
  %res.sroa.0.0.i1207 = select i1 %_14.1.i1206, i64 %129, i64 %_14.0.i1205
  %_16.i1208 = icmp ugt i64 %res.sroa.0.0.i1207, -4294967296
  %_17.i1209 = add nsw i64 %res.sroa.0.0.i1207, 4294967295
  %_0.sroa.0.0.i1210 = select i1 %_16.i1208, i64 %_17.i1209, i64 %res.sroa.0.0.i1207
  %_29.0.i330 = add i64 %_0.sroa.0.0.i1226, %_0.sroa.0.0.i1210
  %_29.1.i331 = icmp ult i64 %_29.0.i330, %_0.sroa.0.0.i1226
  %130 = add nuw i64 %_29.0.i330, 4294967295
  %_30.sroa.0.0.i332 = select i1 %_29.1.i331, i64 %130, i64 %_29.0.i330
  %_31.i333 = icmp ugt i64 %_30.sroa.0.0.i332, -4294967296
  %_32.i334 = add nsw i64 %_30.sroa.0.0.i332, 4294967295
  %_9.sroa.0.0.i335 = select i1 %_31.i333, i64 %_32.i334, i64 %_30.sroa.0.0.i332
  %_14.i286 = zext i64 %_9.sroa.0.0.i335 to i128
  %_13.i288 = mul nuw i128 %_14.i286, %_14.i394
  %_4.i1308 = lshr i128 %_13.i288, 64
  %x_hi.i1309 = trunc nuw i128 %_4.i1308 to i64
  %x_hi_hi.i1310 = lshr i64 %x_hi.i1309, 32
  %x_lo.i1307 = trunc i128 %_13.i288 to i64
  %_9.1.i1313 = icmp ugt i64 %x_hi_hi.i1310, %x_lo.i1307
  %_9.0.i1312 = sub i64 %x_lo.i1307, %x_hi_hi.i1310
  %_10.i1314 = add i64 %_9.0.i1312, -4294967295
  %spec.select.i1315 = select i1 %_9.1.i1313, i64 %_10.i1314, i64 %_9.0.i1312
  %x_hi_lo.i1311 = and i64 %x_hi.i1309, 4294967295
  %t1.i1316 = mul nuw i64 %x_hi_lo.i1311, 4294967295
  %_14.0.i1317 = add i64 %spec.select.i1315, %t1.i1316
  %_14.1.i1318 = icmp ult i64 %_14.0.i1317, %spec.select.i1315
  %131 = add i64 %_14.0.i1317, 4294967295
  %res.sroa.0.0.i1319 = select i1 %_14.1.i1318, i64 %131, i64 %_14.0.i1317
  %_16.i1320 = icmp ugt i64 %res.sroa.0.0.i1319, -4294967296
  %_17.i1321 = add nsw i64 %res.sroa.0.0.i1319, 4294967295
  %_0.sroa.0.0.i1322 = select i1 %_16.i1320, i64 %_17.i1321, i64 %res.sroa.0.0.i1319
  %_19.i294 = zext i64 %_0.sroa.0.0.i1322 to i128
  %_18.i295 = mul nuw nsw i128 %_19.i294, 7
  %_4.i1260 = lshr i128 %_18.i295, 64
  %x_hi.i1261 = trunc nuw nsw i128 %_4.i1260 to i64
  %t1.i1268 = mul nuw nsw i64 %x_hi.i1261, 4294967295
  %x_lo.i1259 = trunc i128 %_18.i295 to i64
  %_14.0.i1269 = add i64 %t1.i1268, %x_lo.i1259
  %_14.1.i1270 = icmp ult i64 %_14.0.i1269, %x_lo.i1259
  %132 = add i64 %_14.0.i1269, 4294967295
  %res.sroa.0.0.i1271 = select i1 %_14.1.i1270, i64 %132, i64 %_14.0.i1269
  %_16.i1272 = icmp ugt i64 %res.sroa.0.0.i1271, -4294967296
  %_17.i1273 = add nsw i64 %res.sroa.0.0.i1271, 4294967295
  %_0.sroa.0.0.i1274 = select i1 %_16.i1272, i64 %_17.i1273, i64 %res.sroa.0.0.i1271
  %_22.0.i297 = add i64 %_0.sroa.0.0.i1338, %_0.sroa.0.0.i1274
  %_22.1.i298 = icmp ult i64 %_22.0.i297, %_0.sroa.0.0.i1338
  %133 = add nuw i64 %_22.0.i297, 4294967295
  %_24.sroa.0.0.i299 = select i1 %_22.1.i298, i64 %133, i64 %_22.0.i297
  %_25.i300 = icmp ugt i64 %_24.sroa.0.0.i299, -4294967296
  %_26.i301 = add nsw i64 %_24.sroa.0.0.i299, 4294967295
  %_7.sroa.0.0.i302 = select i1 %_25.i300, i64 %_26.i301, i64 %_24.sroa.0.0.i299
  %_11.i255 = zext i64 %_7.sroa.0.0.i302 to i128
  %_11.i363 = zext i64 %_75.0 to i128
  %_15.i368 = zext i64 %g8.1 to i128
  %_16.i371 = mul nuw i128 %_11.i363, %_15.i368
  %_4.i1052 = lshr i128 %_16.i371, 64
  %x_hi.i1053 = trunc nuw i128 %_4.i1052 to i64
  %x_hi_hi.i1054 = lshr i64 %x_hi.i1053, 32
  %x_lo.i1051 = trunc i128 %_16.i371 to i64
  %_9.1.i1057 = icmp ugt i64 %x_hi_hi.i1054, %x_lo.i1051
  %_9.0.i1056 = sub i64 %x_lo.i1051, %x_hi_hi.i1054
  %_10.i1058 = add i64 %_9.0.i1056, -4294967295
  %spec.select.i1059 = select i1 %_9.1.i1057, i64 %_10.i1058, i64 %_9.0.i1056
  %x_hi_lo.i1055 = and i64 %x_hi.i1053, 4294967295
  %t1.i1060 = mul nuw i64 %x_hi_lo.i1055, 4294967295
  %_14.0.i1061 = add i64 %spec.select.i1059, %t1.i1060
  %_14.1.i1062 = icmp ult i64 %_14.0.i1061, %spec.select.i1059
  %134 = add i64 %_14.0.i1061, 4294967295
  %res.sroa.0.0.i1063 = select i1 %_14.1.i1062, i64 %134, i64 %_14.0.i1061
  %_16.i1064 = icmp ugt i64 %res.sroa.0.0.i1063, -4294967296
  %_17.i1065 = add nsw i64 %res.sroa.0.0.i1063, 4294967295
  %_0.sroa.0.0.i1066 = select i1 %_16.i1064, i64 %_17.i1065, i64 %res.sroa.0.0.i1063
  %_14.i367 = zext i64 %_75.1 to i128
  %_12.i364 = zext i64 %g8.0 to i128
  %_17.i373 = mul nuw i128 %_14.i367, %_12.i364
  %_4.i1036 = lshr i128 %_17.i373, 64
  %x_hi.i1037 = trunc nuw i128 %_4.i1036 to i64
  %x_hi_hi.i1038 = lshr i64 %x_hi.i1037, 32
  %x_lo.i1035 = trunc i128 %_17.i373 to i64
  %_9.1.i1041 = icmp ugt i64 %x_hi_hi.i1038, %x_lo.i1035
  %_9.0.i1040 = sub i64 %x_lo.i1035, %x_hi_hi.i1038
  %_10.i1042 = add i64 %_9.0.i1040, -4294967295
  %spec.select.i1043 = select i1 %_9.1.i1041, i64 %_10.i1042, i64 %_9.0.i1040
  %x_hi_lo.i1039 = and i64 %x_hi.i1037, 4294967295
  %t1.i1044 = mul nuw i64 %x_hi_lo.i1039, 4294967295
  %_14.0.i1045 = add i64 %spec.select.i1043, %t1.i1044
  %_14.1.i1046 = icmp ult i64 %_14.0.i1045, %spec.select.i1043
  %135 = add i64 %_14.0.i1045, 4294967295
  %res.sroa.0.0.i1047 = select i1 %_14.1.i1046, i64 %135, i64 %_14.0.i1045
  %_16.i1048 = icmp ugt i64 %res.sroa.0.0.i1047, -4294967296
  %_17.i1049 = add nsw i64 %res.sroa.0.0.i1047, 4294967295
  %_0.sroa.0.0.i1050 = select i1 %_16.i1048, i64 %_17.i1049, i64 %res.sroa.0.0.i1047
  %_29.0.i384 = add i64 %_0.sroa.0.0.i1050, %_0.sroa.0.0.i1066
  %_29.1.i385 = icmp ult i64 %_29.0.i384, %_0.sroa.0.0.i1066
  %136 = add nuw i64 %_29.0.i384, 4294967295
  %_30.sroa.0.0.i386 = select i1 %_29.1.i385, i64 %136, i64 %_29.0.i384
  %_31.i387 = icmp ugt i64 %_30.sroa.0.0.i386, -4294967296
  %_32.i388 = add nsw i64 %_30.sroa.0.0.i386, 4294967295
  %_9.sroa.0.0.i389 = select i1 %_31.i387, i64 %_32.i388, i64 %_30.sroa.0.0.i386
  %_13.0.i57 = add i64 %_9.sroa.0.0.i389, %_76.1
  %_13.1.i58 = icmp ult i64 %_13.0.i57, %_9.sroa.0.0.i389
  %137 = add i64 %_13.0.i57, 4294967295
  %_14.sroa.0.0.i59 = select i1 %_13.1.i58, i64 %137, i64 %_13.0.i57
  %_15.i60 = icmp ugt i64 %_14.sroa.0.0.i59, -4294967296
  %_16.i61 = add nsw i64 %_14.sroa.0.0.i59, 4294967295
  %_4.sroa.0.0.i62 = select i1 %_15.i60, i64 %_16.i61, i64 %_14.sroa.0.0.i59
  %_231.1 = icmp ult i64 %_4.sroa.0.0.i62, %_245
  %_231.0 = sub i64 %_4.sroa.0.0.i62, %_245
  %138 = add i64 %_231.0, -4294967295
  %_232.sroa.0.0 = select i1 %_231.1, i64 %138, i64 %_231.0
  %_15.i260 = zext i64 %_232.sroa.0.0 to i128
  %_16.i263 = mul nuw i128 %_11.i255, %_15.i260
  %_4.i1372 = lshr i128 %_16.i263, 64
  %x_hi.i1373 = trunc nuw i128 %_4.i1372 to i64
  %x_hi_hi.i1374 = lshr i64 %x_hi.i1373, 32
  %x_lo.i1371 = trunc i128 %_16.i263 to i64
  %_9.1.i1377 = icmp ugt i64 %x_hi_hi.i1374, %x_lo.i1371
  %_9.0.i1376 = sub i64 %x_lo.i1371, %x_hi_hi.i1374
  %_10.i1378 = add i64 %_9.0.i1376, -4294967295
  %spec.select.i1379 = select i1 %_9.1.i1377, i64 %_10.i1378, i64 %_9.0.i1376
  %x_hi_lo.i1375 = and i64 %x_hi.i1373, 4294967295
  %t1.i1380 = mul nuw i64 %x_hi_lo.i1375, 4294967295
  %_14.0.i1381 = add i64 %spec.select.i1379, %t1.i1380
  %_14.1.i1382 = icmp ult i64 %_14.0.i1381, %spec.select.i1379
  %139 = add i64 %_14.0.i1381, 4294967295
  %res.sroa.0.0.i1383 = select i1 %_14.1.i1382, i64 %139, i64 %_14.0.i1381
  %_16.i1384 = icmp ugt i64 %res.sroa.0.0.i1383, -4294967296
  %_17.i1385 = add nsw i64 %res.sroa.0.0.i1383, 4294967295
  %_0.sroa.0.0.i1386 = select i1 %_16.i1384, i64 %_17.i1385, i64 %res.sroa.0.0.i1383
  %_16.i290 = mul nuw i128 %_11.i282, %_14.i394
  %_4.i1292 = lshr i128 %_16.i290, 64
  %x_hi.i1293 = trunc nuw i128 %_4.i1292 to i64
  %x_hi_hi.i1294 = lshr i64 %x_hi.i1293, 32
  %x_lo.i1291 = trunc i128 %_16.i290 to i64
  %_9.1.i1297 = icmp ugt i64 %x_hi_hi.i1294, %x_lo.i1291
  %_9.0.i1296 = sub i64 %x_lo.i1291, %x_hi_hi.i1294
  %_10.i1298 = add i64 %_9.0.i1296, -4294967295
  %spec.select.i1299 = select i1 %_9.1.i1297, i64 %_10.i1298, i64 %_9.0.i1296
  %x_hi_lo.i1295 = and i64 %x_hi.i1293, 4294967295
  %t1.i1300 = mul nuw i64 %x_hi_lo.i1295, 4294967295
  %_14.0.i1301 = add i64 %spec.select.i1299, %t1.i1300
  %_14.1.i1302 = icmp ult i64 %_14.0.i1301, %spec.select.i1299
  %140 = add i64 %_14.0.i1301, 4294967295
  %res.sroa.0.0.i1303 = select i1 %_14.1.i1302, i64 %140, i64 %_14.0.i1301
  %_16.i1304 = icmp ugt i64 %res.sroa.0.0.i1303, -4294967296
  %_17.i1305 = add nsw i64 %res.sroa.0.0.i1303, 4294967295
  %_0.sroa.0.0.i1306 = select i1 %_16.i1304, i64 %_17.i1305, i64 %res.sroa.0.0.i1303
  %_17.i292 = mul nuw i128 %_14.i286, %_11.i390
  %_4.i1276 = lshr i128 %_17.i292, 64
  %x_hi.i1277 = trunc nuw i128 %_4.i1276 to i64
  %x_hi_hi.i1278 = lshr i64 %x_hi.i1277, 32
  %x_lo.i1275 = trunc i128 %_17.i292 to i64
  %_9.1.i1281 = icmp ugt i64 %x_hi_hi.i1278, %x_lo.i1275
  %_9.0.i1280 = sub i64 %x_lo.i1275, %x_hi_hi.i1278
  %_10.i1282 = add i64 %_9.0.i1280, -4294967295
  %spec.select.i1283 = select i1 %_9.1.i1281, i64 %_10.i1282, i64 %_9.0.i1280
  %x_hi_lo.i1279 = and i64 %x_hi.i1277, 4294967295
  %t1.i1284 = mul nuw i64 %x_hi_lo.i1279, 4294967295
  %_14.0.i1285 = add i64 %spec.select.i1283, %t1.i1284
  %_14.1.i1286 = icmp ult i64 %_14.0.i1285, %spec.select.i1283
  %141 = add i64 %_14.0.i1285, 4294967295
  %res.sroa.0.0.i1287 = select i1 %_14.1.i1286, i64 %141, i64 %_14.0.i1285
  %_16.i1288 = icmp ugt i64 %res.sroa.0.0.i1287, -4294967296
  %_17.i1289 = add nsw i64 %res.sroa.0.0.i1287, 4294967295
  %_0.sroa.0.0.i1290 = select i1 %_16.i1288, i64 %_17.i1289, i64 %res.sroa.0.0.i1287
  %_29.0.i303 = add i64 %_0.sroa.0.0.i1306, %_0.sroa.0.0.i1290
  %_29.1.i304 = icmp ult i64 %_29.0.i303, %_0.sroa.0.0.i1306
  %142 = add nuw i64 %_29.0.i303, 4294967295
  %_30.sroa.0.0.i305 = select i1 %_29.1.i304, i64 %142, i64 %_29.0.i303
  %_31.i306 = icmp ugt i64 %_30.sroa.0.0.i305, -4294967296
  %_32.i307 = add nsw i64 %_30.sroa.0.0.i305, 4294967295
  %_9.sroa.0.0.i308 = select i1 %_31.i306, i64 %_32.i307, i64 %_30.sroa.0.0.i305
  %_14.i259 = zext i64 %_9.sroa.0.0.i308 to i128
  %_10.i365 = mul nuw i128 %_11.i363, %_12.i364
  %_4.i1084 = lshr i128 %_10.i365, 64
  %x_hi.i1085 = trunc nuw i128 %_4.i1084 to i64
  %x_hi_hi.i1086 = lshr i64 %x_hi.i1085, 32
  %x_lo.i1083 = trunc i128 %_10.i365 to i64
  %_9.1.i1089 = icmp ugt i64 %x_hi_hi.i1086, %x_lo.i1083
  %_9.0.i1088 = sub i64 %x_lo.i1083, %x_hi_hi.i1086
  %_10.i1090 = add i64 %_9.0.i1088, -4294967295
  %spec.select.i1091 = select i1 %_9.1.i1089, i64 %_10.i1090, i64 %_9.0.i1088
  %x_hi_lo.i1087 = and i64 %x_hi.i1085, 4294967295
  %t1.i1092 = mul nuw i64 %x_hi_lo.i1087, 4294967295
  %_14.0.i1093 = add i64 %spec.select.i1091, %t1.i1092
  %_14.1.i1094 = icmp ult i64 %_14.0.i1093, %spec.select.i1091
  %143 = add i64 %_14.0.i1093, 4294967295
  %res.sroa.0.0.i1095 = select i1 %_14.1.i1094, i64 %143, i64 %_14.0.i1093
  %_16.i1096 = icmp ugt i64 %res.sroa.0.0.i1095, -4294967296
  %_17.i1097 = add nsw i64 %res.sroa.0.0.i1095, 4294967295
  %_0.sroa.0.0.i1098 = select i1 %_16.i1096, i64 %_17.i1097, i64 %res.sroa.0.0.i1095
  %_13.i369 = mul nuw i128 %_14.i367, %_15.i368
  %_4.i1068 = lshr i128 %_13.i369, 64
  %x_hi.i1069 = trunc nuw i128 %_4.i1068 to i64
  %x_hi_hi.i1070 = lshr i64 %x_hi.i1069, 32
  %x_lo.i1067 = trunc i128 %_13.i369 to i64
  %_9.1.i1073 = icmp ugt i64 %x_hi_hi.i1070, %x_lo.i1067
  %_9.0.i1072 = sub i64 %x_lo.i1067, %x_hi_hi.i1070
  %_10.i1074 = add i64 %_9.0.i1072, -4294967295
  %spec.select.i1075 = select i1 %_9.1.i1073, i64 %_10.i1074, i64 %_9.0.i1072
  %x_hi_lo.i1071 = and i64 %x_hi.i1069, 4294967295
  %t1.i1076 = mul nuw i64 %x_hi_lo.i1071, 4294967295
  %_14.0.i1077 = add i64 %spec.select.i1075, %t1.i1076
  %_14.1.i1078 = icmp ult i64 %_14.0.i1077, %spec.select.i1075
  %144 = add i64 %_14.0.i1077, 4294967295
  %res.sroa.0.0.i1079 = select i1 %_14.1.i1078, i64 %144, i64 %_14.0.i1077
  %_16.i1080 = icmp ugt i64 %res.sroa.0.0.i1079, -4294967296
  %_17.i1081 = add nsw i64 %res.sroa.0.0.i1079, 4294967295
  %_0.sroa.0.0.i1082 = select i1 %_16.i1080, i64 %_17.i1081, i64 %res.sroa.0.0.i1079
  %_19.i375 = zext i64 %_0.sroa.0.0.i1082 to i128
  %_18.i376 = mul nuw nsw i128 %_19.i375, 7
  %_4.i1020 = lshr i128 %_18.i376, 64
  %x_hi.i1021 = trunc nuw nsw i128 %_4.i1020 to i64
  %t1.i1028 = mul nuw nsw i64 %x_hi.i1021, 4294967295
  %x_lo.i1019 = trunc i128 %_18.i376 to i64
  %_14.0.i1029 = add i64 %t1.i1028, %x_lo.i1019
  %_14.1.i1030 = icmp ult i64 %_14.0.i1029, %x_lo.i1019
  %145 = add i64 %_14.0.i1029, 4294967295
  %res.sroa.0.0.i1031 = select i1 %_14.1.i1030, i64 %145, i64 %_14.0.i1029
  %_16.i1032 = icmp ugt i64 %res.sroa.0.0.i1031, -4294967296
  %_17.i1033 = add nsw i64 %res.sroa.0.0.i1031, 4294967295
  %_0.sroa.0.0.i1034 = select i1 %_16.i1032, i64 %_17.i1033, i64 %res.sroa.0.0.i1031
  %_22.0.i378 = add i64 %_0.sroa.0.0.i1034, %_0.sroa.0.0.i1098
  %_22.1.i379 = icmp ult i64 %_22.0.i378, %_0.sroa.0.0.i1098
  %146 = add nuw i64 %_22.0.i378, 4294967295
  %_24.sroa.0.0.i380 = select i1 %_22.1.i379, i64 %146, i64 %_22.0.i378
  %_25.i381 = icmp ugt i64 %_24.sroa.0.0.i380, -4294967296
  %_26.i382 = add nsw i64 %_24.sroa.0.0.i380, 4294967295
  %_7.sroa.0.0.i383 = select i1 %_25.i381, i64 %_26.i382, i64 %_24.sroa.0.0.i380
  %_7.0.i51 = add i64 %_7.sroa.0.0.i383, %_76.0
  %_7.1.i52 = icmp ult i64 %_7.0.i51, %_7.sroa.0.0.i383
  %147 = add i64 %_7.0.i51, 4294967295
  %_8.sroa.0.0.i53 = select i1 %_7.1.i52, i64 %147, i64 %_7.0.i51
  %_9.i54 = icmp ugt i64 %_8.sroa.0.0.i53, -4294967296
  %_10.i55 = add nsw i64 %_8.sroa.0.0.i53, 4294967295
  %_3.sroa.0.0.i56 = select i1 %_9.i54, i64 %_10.i55, i64 %_8.sroa.0.0.i53
  %_227.1 = icmp ult i64 %_3.sroa.0.0.i56, %_244
  %_227.0 = sub i64 %_3.sroa.0.0.i56, %_244
  %148 = add i64 %_227.0, -4294967295
  %_228.sroa.0.0 = select i1 %_227.1, i64 %148, i64 %_227.0
  %_12.i256 = zext i64 %_228.sroa.0.0 to i128
  %_17.i265 = mul nuw i128 %_14.i259, %_12.i256
  %_4.i1356 = lshr i128 %_17.i265, 64
  %x_hi.i1357 = trunc nuw i128 %_4.i1356 to i64
  %x_hi_hi.i1358 = lshr i64 %x_hi.i1357, 32
  %x_lo.i1355 = trunc i128 %_17.i265 to i64
  %_9.1.i1361 = icmp ugt i64 %x_hi_hi.i1358, %x_lo.i1355
  %_9.0.i1360 = sub i64 %x_lo.i1355, %x_hi_hi.i1358
  %_10.i1362 = add i64 %_9.0.i1360, -4294967295
  %spec.select.i1363 = select i1 %_9.1.i1361, i64 %_10.i1362, i64 %_9.0.i1360
  %x_hi_lo.i1359 = and i64 %x_hi.i1357, 4294967295
  %t1.i1364 = mul nuw i64 %x_hi_lo.i1359, 4294967295
  %_14.0.i1365 = add i64 %spec.select.i1363, %t1.i1364
  %_14.1.i1366 = icmp ult i64 %_14.0.i1365, %spec.select.i1363
  %149 = add i64 %_14.0.i1365, 4294967295
  %res.sroa.0.0.i1367 = select i1 %_14.1.i1366, i64 %149, i64 %_14.0.i1365
  %_16.i1368 = icmp ugt i64 %res.sroa.0.0.i1367, -4294967296
  %_17.i1369 = add nsw i64 %res.sroa.0.0.i1367, 4294967295
  %_0.sroa.0.0.i1370 = select i1 %_16.i1368, i64 %_17.i1369, i64 %res.sroa.0.0.i1367
  %_29.0.i276 = add i64 %_0.sroa.0.0.i1386, %_0.sroa.0.0.i1370
  %_29.1.i277 = icmp ult i64 %_29.0.i276, %_0.sroa.0.0.i1386
  %150 = add nuw i64 %_29.0.i276, 4294967295
  %_30.sroa.0.0.i278 = select i1 %_29.1.i277, i64 %150, i64 %_29.0.i276
  %_31.i279 = icmp ugt i64 %_30.sroa.0.0.i278, -4294967296
  %_32.i280 = add nsw i64 %_30.sroa.0.0.i278, 4294967295
  %_9.sroa.0.0.i281 = select i1 %_31.i279, i64 %_32.i280, i64 %_30.sroa.0.0.i278
  %_13.0.i45 = add i64 %_9.sroa.0.0.i281, %_9.sroa.0.0.i362
  %_13.1.i46 = icmp ult i64 %_13.0.i45, %_9.sroa.0.0.i362
  %151 = add i64 %_13.0.i45, 4294967295
  %_14.sroa.0.0.i47 = select i1 %_13.1.i46, i64 %151, i64 %_13.0.i45
  %_15.i48 = icmp ugt i64 %_14.sroa.0.0.i47, -4294967296
  %_16.i49 = add nsw i64 %_14.sroa.0.0.i47, 4294967295
  %_4.sroa.0.0.i50 = select i1 %_15.i48, i64 %_16.i49, i64 %_14.sroa.0.0.i47
  %_10.i338 = mul nuw i128 %_11.i336, %_12.i337
  %_4.i1164 = lshr i128 %_10.i338, 64
  %x_hi.i1165 = trunc nuw i128 %_4.i1164 to i64
  %x_hi_hi.i1166 = lshr i64 %x_hi.i1165, 32
  %x_lo.i1163 = trunc i128 %_10.i338 to i64
  %_9.1.i1169 = icmp ugt i64 %x_hi_hi.i1166, %x_lo.i1163
  %_9.0.i1168 = sub i64 %x_lo.i1163, %x_hi_hi.i1166
  %_10.i1170 = add i64 %_9.0.i1168, -4294967295
  %spec.select.i1171 = select i1 %_9.1.i1169, i64 %_10.i1170, i64 %_9.0.i1168
  %x_hi_lo.i1167 = and i64 %x_hi.i1165, 4294967295
  %t1.i1172 = mul nuw i64 %x_hi_lo.i1167, 4294967295
  %_14.0.i1173 = add i64 %spec.select.i1171, %t1.i1172
  %_14.1.i1174 = icmp ult i64 %_14.0.i1173, %spec.select.i1171
  %152 = add i64 %_14.0.i1173, 4294967295
  %res.sroa.0.0.i1175 = select i1 %_14.1.i1174, i64 %152, i64 %_14.0.i1173
  %_16.i1176 = icmp ugt i64 %res.sroa.0.0.i1175, -4294967296
  %_17.i1177 = add nsw i64 %res.sroa.0.0.i1175, 4294967295
  %_0.sroa.0.0.i1178 = select i1 %_16.i1176, i64 %_17.i1177, i64 %res.sroa.0.0.i1175
  %_13.i342 = mul nuw i128 %_14.i340, %_15.i341
  %_4.i1148 = lshr i128 %_13.i342, 64
  %x_hi.i1149 = trunc nuw i128 %_4.i1148 to i64
  %x_hi_hi.i1150 = lshr i64 %x_hi.i1149, 32
  %x_lo.i1147 = trunc i128 %_13.i342 to i64
  %_9.1.i1153 = icmp ugt i64 %x_hi_hi.i1150, %x_lo.i1147
  %_9.0.i1152 = sub i64 %x_lo.i1147, %x_hi_hi.i1150
  %_10.i1154 = add i64 %_9.0.i1152, -4294967295
  %spec.select.i1155 = select i1 %_9.1.i1153, i64 %_10.i1154, i64 %_9.0.i1152
  %x_hi_lo.i1151 = and i64 %x_hi.i1149, 4294967295
  %t1.i1156 = mul nuw i64 %x_hi_lo.i1151, 4294967295
  %_14.0.i1157 = add i64 %spec.select.i1155, %t1.i1156
  %_14.1.i1158 = icmp ult i64 %_14.0.i1157, %spec.select.i1155
  %153 = add i64 %_14.0.i1157, 4294967295
  %res.sroa.0.0.i1159 = select i1 %_14.1.i1158, i64 %153, i64 %_14.0.i1157
  %_16.i1160 = icmp ugt i64 %res.sroa.0.0.i1159, -4294967296
  %_17.i1161 = add nsw i64 %res.sroa.0.0.i1159, 4294967295
  %_0.sroa.0.0.i1162 = select i1 %_16.i1160, i64 %_17.i1161, i64 %res.sroa.0.0.i1159
  %_19.i348 = zext i64 %_0.sroa.0.0.i1162 to i128
  %_18.i349 = mul nuw nsw i128 %_19.i348, 7
  %_4.i1100 = lshr i128 %_18.i349, 64
  %x_hi.i1101 = trunc nuw nsw i128 %_4.i1100 to i64
  %t1.i1108 = mul nuw nsw i64 %x_hi.i1101, 4294967295
  %x_lo.i1099 = trunc i128 %_18.i349 to i64
  %_14.0.i1109 = add i64 %t1.i1108, %x_lo.i1099
  %_14.1.i1110 = icmp ult i64 %_14.0.i1109, %x_lo.i1099
  %154 = add i64 %_14.0.i1109, 4294967295
  %res.sroa.0.0.i1111 = select i1 %_14.1.i1110, i64 %154, i64 %_14.0.i1109
  %_16.i1112 = icmp ugt i64 %res.sroa.0.0.i1111, -4294967296
  %_17.i1113 = add nsw i64 %res.sroa.0.0.i1111, 4294967295
  %_0.sroa.0.0.i1114 = select i1 %_16.i1112, i64 %_17.i1113, i64 %res.sroa.0.0.i1111
  %_22.0.i351 = add i64 %_0.sroa.0.0.i1114, %_0.sroa.0.0.i1178
  %_22.1.i352 = icmp ult i64 %_22.0.i351, %_0.sroa.0.0.i1178
  %155 = add nuw i64 %_22.0.i351, 4294967295
  %_24.sroa.0.0.i353 = select i1 %_22.1.i352, i64 %155, i64 %_22.0.i351
  %_25.i354 = icmp ugt i64 %_24.sroa.0.0.i353, -4294967296
  %_26.i355 = add nsw i64 %_24.sroa.0.0.i353, 4294967295
  %_7.sroa.0.0.i356 = select i1 %_25.i354, i64 %_26.i355, i64 %_24.sroa.0.0.i353
  %_10.i257 = mul nuw i128 %_11.i255, %_12.i256
  %_4.i1404 = lshr i128 %_10.i257, 64
  %x_hi.i1405 = trunc nuw i128 %_4.i1404 to i64
  %x_hi_hi.i1406 = lshr i64 %x_hi.i1405, 32
  %x_lo.i1403 = trunc i128 %_10.i257 to i64
  %_9.1.i1409 = icmp ugt i64 %x_hi_hi.i1406, %x_lo.i1403
  %_9.0.i1408 = sub i64 %x_lo.i1403, %x_hi_hi.i1406
  %_10.i1410 = add i64 %_9.0.i1408, -4294967295
  %spec.select.i1411 = select i1 %_9.1.i1409, i64 %_10.i1410, i64 %_9.0.i1408
  %x_hi_lo.i1407 = and i64 %x_hi.i1405, 4294967295
  %t1.i1412 = mul nuw i64 %x_hi_lo.i1407, 4294967295
  %_14.0.i1413 = add i64 %spec.select.i1411, %t1.i1412
  %_14.1.i1414 = icmp ult i64 %_14.0.i1413, %spec.select.i1411
  %156 = add i64 %_14.0.i1413, 4294967295
  %res.sroa.0.0.i1415 = select i1 %_14.1.i1414, i64 %156, i64 %_14.0.i1413
  %_16.i1416 = icmp ugt i64 %res.sroa.0.0.i1415, -4294967296
  %_17.i1417 = add nsw i64 %res.sroa.0.0.i1415, 4294967295
  %_0.sroa.0.0.i1418 = select i1 %_16.i1416, i64 %_17.i1417, i64 %res.sroa.0.0.i1415
  %_13.i261 = mul nuw i128 %_14.i259, %_15.i260
  %_4.i1388 = lshr i128 %_13.i261, 64
  %x_hi.i1389 = trunc nuw i128 %_4.i1388 to i64
  %x_hi_hi.i1390 = lshr i64 %x_hi.i1389, 32
  %x_lo.i1387 = trunc i128 %_13.i261 to i64
  %_9.1.i1393 = icmp ugt i64 %x_hi_hi.i1390, %x_lo.i1387
  %_9.0.i1392 = sub i64 %x_lo.i1387, %x_hi_hi.i1390
  %_10.i1394 = add i64 %_9.0.i1392, -4294967295
  %spec.select.i1395 = select i1 %_9.1.i1393, i64 %_10.i1394, i64 %_9.0.i1392
  %x_hi_lo.i1391 = and i64 %x_hi.i1389, 4294967295
  %t1.i1396 = mul nuw i64 %x_hi_lo.i1391, 4294967295
  %_14.0.i1397 = add i64 %spec.select.i1395, %t1.i1396
  %_14.1.i1398 = icmp ult i64 %_14.0.i1397, %spec.select.i1395
  %157 = add i64 %_14.0.i1397, 4294967295
  %res.sroa.0.0.i1399 = select i1 %_14.1.i1398, i64 %157, i64 %_14.0.i1397
  %_16.i1400 = icmp ugt i64 %res.sroa.0.0.i1399, -4294967296
  %_17.i1401 = add nsw i64 %res.sroa.0.0.i1399, 4294967295
  %_0.sroa.0.0.i1402 = select i1 %_16.i1400, i64 %_17.i1401, i64 %res.sroa.0.0.i1399
  %_19.i267 = zext i64 %_0.sroa.0.0.i1402 to i128
  %_18.i268 = mul nuw nsw i128 %_19.i267, 7
  %_4.i1340 = lshr i128 %_18.i268, 64
  %x_hi.i1341 = trunc nuw nsw i128 %_4.i1340 to i64
  %t1.i1348 = mul nuw nsw i64 %x_hi.i1341, 4294967295
  %x_lo.i1339 = trunc i128 %_18.i268 to i64
  %_14.0.i1349 = add i64 %t1.i1348, %x_lo.i1339
  %_14.1.i1350 = icmp ult i64 %_14.0.i1349, %x_lo.i1339
  %158 = add i64 %_14.0.i1349, 4294967295
  %res.sroa.0.0.i1351 = select i1 %_14.1.i1350, i64 %158, i64 %_14.0.i1349
  %_16.i1352 = icmp ugt i64 %res.sroa.0.0.i1351, -4294967296
  %_17.i1353 = add nsw i64 %res.sroa.0.0.i1351, 4294967295
  %_0.sroa.0.0.i1354 = select i1 %_16.i1352, i64 %_17.i1353, i64 %res.sroa.0.0.i1351
  %_22.0.i270 = add i64 %_0.sroa.0.0.i1354, %_0.sroa.0.0.i1418
  %_22.1.i271 = icmp ult i64 %_22.0.i270, %_0.sroa.0.0.i1418
  %159 = add nuw i64 %_22.0.i270, 4294967295
  %_24.sroa.0.0.i272 = select i1 %_22.1.i271, i64 %159, i64 %_22.0.i270
  %_25.i273 = icmp ugt i64 %_24.sroa.0.0.i272, -4294967296
  %_26.i274 = add nsw i64 %_24.sroa.0.0.i272, 4294967295
  %_7.sroa.0.0.i275 = select i1 %_25.i273, i64 %_26.i274, i64 %_24.sroa.0.0.i272
  %_7.0.i39 = add i64 %_7.sroa.0.0.i275, %_7.sroa.0.0.i356
  %_7.1.i40 = icmp ult i64 %_7.0.i39, %_7.sroa.0.0.i356
  %160 = add i64 %_7.0.i39, 4294967295
  %_8.sroa.0.0.i41 = select i1 %_7.1.i40, i64 %160, i64 %_7.0.i39
  %_9.i42 = icmp ugt i64 %_8.sroa.0.0.i41, -4294967296
  %_10.i43 = add nsw i64 %_8.sroa.0.0.i41, 4294967295
  %_3.sroa.0.0.i44 = select i1 %_9.i42, i64 %_10.i43, i64 %_8.sroa.0.0.i41
  %161 = getelementptr inbounds nuw i8, ptr %_238, i64 24
  %_92.1 = load i64, ptr %161, align 8, !noundef !3
  %_93 = getelementptr inbounds nuw i8, ptr %_238, i64 16
  %_92.0 = load i64, ptr %_93, align 8, !noundef !3
  %162 = getelementptr inbounds nuw i8, ptr %v.0, i64 32
  %_94.0 = load i64, ptr %162, align 8, !noundef !3
  %163 = getelementptr inbounds nuw i8, ptr %v.0, i64 40
  %_94.1 = load i64, ptr %163, align 8, !noundef !3
  %_11.i228 = zext i64 %_92.0 to i128
  %_12.i229 = zext i64 %_94.0 to i128
  %_10.i230 = mul nuw i128 %_12.i229, %_11.i228
  %x_lo.i1483 = trunc i128 %_10.i230 to i64
  %_4.i1484 = lshr i128 %_10.i230, 64
  %x_hi.i1485 = trunc nuw i128 %_4.i1484 to i64
  %x_hi_hi.i1486 = lshr i64 %x_hi.i1485, 32
  %x_hi_lo.i1487 = and i64 %x_hi.i1485, 4294967295
  %_9.0.i1488 = sub i64 %x_lo.i1483, %x_hi_hi.i1486
  %_9.1.i1489 = icmp ugt i64 %x_hi_hi.i1486, %x_lo.i1483
  %_10.i1490 = add i64 %_9.0.i1488, -4294967295
  %spec.select.i1491 = select i1 %_9.1.i1489, i64 %_10.i1490, i64 %_9.0.i1488
  %t1.i1492 = mul nuw i64 %x_hi_lo.i1487, 4294967295
  %_14.0.i1493 = add i64 %spec.select.i1491, %t1.i1492
  %_14.1.i1494 = icmp ult i64 %_14.0.i1493, %spec.select.i1491
  %164 = add i64 %_14.0.i1493, 4294967295
  %res.sroa.0.0.i1495 = select i1 %_14.1.i1494, i64 %164, i64 %_14.0.i1493
  %_16.i1496 = icmp ugt i64 %res.sroa.0.0.i1495, -4294967296
  %_17.i1497 = add nsw i64 %res.sroa.0.0.i1495, 4294967295
  %_0.sroa.0.0.i1498 = select i1 %_16.i1496, i64 %_17.i1497, i64 %res.sroa.0.0.i1495
  %_14.i232 = zext i64 %_92.1 to i128
  %_15.i233 = zext i64 %_94.1 to i128
  %_13.i234 = mul nuw i128 %_15.i233, %_14.i232
  %x_lo.i1467 = trunc i128 %_13.i234 to i64
  %_4.i1468 = lshr i128 %_13.i234, 64
  %x_hi.i1469 = trunc nuw i128 %_4.i1468 to i64
  %x_hi_hi.i1470 = lshr i64 %x_hi.i1469, 32
  %x_hi_lo.i1471 = and i64 %x_hi.i1469, 4294967295
  %_9.0.i1472 = sub i64 %x_lo.i1467, %x_hi_hi.i1470
  %_9.1.i1473 = icmp ugt i64 %x_hi_hi.i1470, %x_lo.i1467
  %_10.i1474 = add i64 %_9.0.i1472, -4294967295
  %spec.select.i1475 = select i1 %_9.1.i1473, i64 %_10.i1474, i64 %_9.0.i1472
  %t1.i1476 = mul nuw i64 %x_hi_lo.i1471, 4294967295
  %_14.0.i1477 = add i64 %spec.select.i1475, %t1.i1476
  %_14.1.i1478 = icmp ult i64 %_14.0.i1477, %spec.select.i1475
  %165 = add i64 %_14.0.i1477, 4294967295
  %res.sroa.0.0.i1479 = select i1 %_14.1.i1478, i64 %165, i64 %_14.0.i1477
  %_16.i1480 = icmp ugt i64 %res.sroa.0.0.i1479, -4294967296
  %_17.i1481 = add nsw i64 %res.sroa.0.0.i1479, 4294967295
  %_0.sroa.0.0.i1482 = select i1 %_16.i1480, i64 %_17.i1481, i64 %res.sroa.0.0.i1479
  %_16.i236 = mul nuw i128 %_15.i233, %_11.i228
  %x_lo.i1451 = trunc i128 %_16.i236 to i64
  %_4.i1452 = lshr i128 %_16.i236, 64
  %x_hi.i1453 = trunc nuw i128 %_4.i1452 to i64
  %x_hi_hi.i1454 = lshr i64 %x_hi.i1453, 32
  %x_hi_lo.i1455 = and i64 %x_hi.i1453, 4294967295
  %_9.0.i1456 = sub i64 %x_lo.i1451, %x_hi_hi.i1454
  %_9.1.i1457 = icmp ugt i64 %x_hi_hi.i1454, %x_lo.i1451
  %_10.i1458 = add i64 %_9.0.i1456, -4294967295
  %spec.select.i1459 = select i1 %_9.1.i1457, i64 %_10.i1458, i64 %_9.0.i1456
  %t1.i1460 = mul nuw i64 %x_hi_lo.i1455, 4294967295
  %_14.0.i1461 = add i64 %spec.select.i1459, %t1.i1460
  %_14.1.i1462 = icmp ult i64 %_14.0.i1461, %spec.select.i1459
  %166 = add i64 %_14.0.i1461, 4294967295
  %res.sroa.0.0.i1463 = select i1 %_14.1.i1462, i64 %166, i64 %_14.0.i1461
  %_16.i1464 = icmp ugt i64 %res.sroa.0.0.i1463, -4294967296
  %_17.i1465 = add nsw i64 %res.sroa.0.0.i1463, 4294967295
  %_0.sroa.0.0.i1466 = select i1 %_16.i1464, i64 %_17.i1465, i64 %res.sroa.0.0.i1463
  %_17.i238 = mul nuw i128 %_12.i229, %_14.i232
  %x_lo.i1435 = trunc i128 %_17.i238 to i64
  %_4.i1436 = lshr i128 %_17.i238, 64
  %x_hi.i1437 = trunc nuw i128 %_4.i1436 to i64
  %x_hi_hi.i1438 = lshr i64 %x_hi.i1437, 32
  %x_hi_lo.i1439 = and i64 %x_hi.i1437, 4294967295
  %_9.0.i1440 = sub i64 %x_lo.i1435, %x_hi_hi.i1438
  %_9.1.i1441 = icmp ugt i64 %x_hi_hi.i1438, %x_lo.i1435
  %_10.i1442 = add i64 %_9.0.i1440, -4294967295
  %spec.select.i1443 = select i1 %_9.1.i1441, i64 %_10.i1442, i64 %_9.0.i1440
  %t1.i1444 = mul nuw i64 %x_hi_lo.i1439, 4294967295
  %_14.0.i1445 = add i64 %spec.select.i1443, %t1.i1444
  %_14.1.i1446 = icmp ult i64 %_14.0.i1445, %spec.select.i1443
  %167 = add i64 %_14.0.i1445, 4294967295
  %res.sroa.0.0.i1447 = select i1 %_14.1.i1446, i64 %167, i64 %_14.0.i1445
  %_16.i1448 = icmp ugt i64 %res.sroa.0.0.i1447, -4294967296
  %_17.i1449 = add nsw i64 %res.sroa.0.0.i1447, 4294967295
  %_0.sroa.0.0.i1450 = select i1 %_16.i1448, i64 %_17.i1449, i64 %res.sroa.0.0.i1447
  %_19.i240 = zext i64 %_0.sroa.0.0.i1482 to i128
  %_18.i241 = mul nuw nsw i128 %_19.i240, 7
  %x_lo.i1419 = trunc i128 %_18.i241 to i64
  %_4.i1420 = lshr i128 %_18.i241, 64
  %x_hi.i1421 = trunc nuw nsw i128 %_4.i1420 to i64
  %t1.i1428 = mul nuw nsw i64 %x_hi.i1421, 4294967295
  %_14.0.i1429 = add i64 %t1.i1428, %x_lo.i1419
  %_14.1.i1430 = icmp ult i64 %_14.0.i1429, %x_lo.i1419
  %168 = add i64 %_14.0.i1429, 4294967295
  %res.sroa.0.0.i1431 = select i1 %_14.1.i1430, i64 %168, i64 %_14.0.i1429
  %_16.i1432 = icmp ugt i64 %res.sroa.0.0.i1431, -4294967296
  %_17.i1433 = add nsw i64 %res.sroa.0.0.i1431, 4294967295
  %_0.sroa.0.0.i1434 = select i1 %_16.i1432, i64 %_17.i1433, i64 %res.sroa.0.0.i1431
  %_22.0.i243 = add i64 %_0.sroa.0.0.i1434, %_0.sroa.0.0.i1498
  %_22.1.i244 = icmp ult i64 %_22.0.i243, %_0.sroa.0.0.i1498
  %169 = add nuw i64 %_22.0.i243, 4294967295
  %_24.sroa.0.0.i245 = select i1 %_22.1.i244, i64 %169, i64 %_22.0.i243
  %_25.i246 = icmp ugt i64 %_24.sroa.0.0.i245, -4294967296
  %_26.i247 = add nsw i64 %_24.sroa.0.0.i245, 4294967295
  %_7.sroa.0.0.i248 = select i1 %_25.i246, i64 %_26.i247, i64 %_24.sroa.0.0.i245
  %_29.0.i249 = add i64 %_0.sroa.0.0.i1466, %_0.sroa.0.0.i1450
  %_29.1.i250 = icmp ult i64 %_29.0.i249, %_0.sroa.0.0.i1466
  %170 = add nuw i64 %_29.0.i249, 4294967295
  %_30.sroa.0.0.i251 = select i1 %_29.1.i250, i64 %170, i64 %_29.0.i249
  %_31.i252 = icmp ugt i64 %_30.sroa.0.0.i251, -4294967296
  %_32.i253 = add nsw i64 %_30.sroa.0.0.i251, 4294967295
  %_9.sroa.0.0.i254 = select i1 %_31.i252, i64 %_32.i253, i64 %_30.sroa.0.0.i251
  %_11.i201 = zext i64 %_7.sroa.0.0.i248 to i128
  %_10.i203 = mul nuw i128 %_11.i201, %_11.i390
  %x_lo.i1563 = trunc i128 %_10.i203 to i64
  %_4.i1564 = lshr i128 %_10.i203, 64
  %x_hi.i1565 = trunc nuw i128 %_4.i1564 to i64
  %x_hi_hi.i1566 = lshr i64 %x_hi.i1565, 32
  %x_hi_lo.i1567 = and i64 %x_hi.i1565, 4294967295
  %_9.0.i1568 = sub i64 %x_lo.i1563, %x_hi_hi.i1566
  %_9.1.i1569 = icmp ugt i64 %x_hi_hi.i1566, %x_lo.i1563
  %_10.i1570 = add i64 %_9.0.i1568, -4294967295
  %spec.select.i1571 = select i1 %_9.1.i1569, i64 %_10.i1570, i64 %_9.0.i1568
  %t1.i1572 = mul nuw i64 %x_hi_lo.i1567, 4294967295
  %_14.0.i1573 = add i64 %spec.select.i1571, %t1.i1572
  %_14.1.i1574 = icmp ult i64 %_14.0.i1573, %spec.select.i1571
  %171 = add i64 %_14.0.i1573, 4294967295
  %res.sroa.0.0.i1575 = select i1 %_14.1.i1574, i64 %171, i64 %_14.0.i1573
  %_16.i1576 = icmp ugt i64 %res.sroa.0.0.i1575, -4294967296
  %_17.i1577 = add nsw i64 %res.sroa.0.0.i1575, 4294967295
  %_0.sroa.0.0.i1578 = select i1 %_16.i1576, i64 %_17.i1577, i64 %res.sroa.0.0.i1575
  %_14.i205 = zext i64 %_9.sroa.0.0.i254 to i128
  %_13.i207 = mul nuw i128 %_14.i205, %_14.i394
  %x_lo.i1547 = trunc i128 %_13.i207 to i64
  %_4.i1548 = lshr i128 %_13.i207, 64
  %x_hi.i1549 = trunc nuw i128 %_4.i1548 to i64
  %x_hi_hi.i1550 = lshr i64 %x_hi.i1549, 32
  %x_hi_lo.i1551 = and i64 %x_hi.i1549, 4294967295
  %_9.0.i1552 = sub i64 %x_lo.i1547, %x_hi_hi.i1550
  %_9.1.i1553 = icmp ugt i64 %x_hi_hi.i1550, %x_lo.i1547
  %_10.i1554 = add i64 %_9.0.i1552, -4294967295
  %spec.select.i1555 = select i1 %_9.1.i1553, i64 %_10.i1554, i64 %_9.0.i1552
  %t1.i1556 = mul nuw i64 %x_hi_lo.i1551, 4294967295
  %_14.0.i1557 = add i64 %spec.select.i1555, %t1.i1556
  %_14.1.i1558 = icmp ult i64 %_14.0.i1557, %spec.select.i1555
  %172 = add i64 %_14.0.i1557, 4294967295
  %res.sroa.0.0.i1559 = select i1 %_14.1.i1558, i64 %172, i64 %_14.0.i1557
  %_16.i1560 = icmp ugt i64 %res.sroa.0.0.i1559, -4294967296
  %_17.i1561 = add nsw i64 %res.sroa.0.0.i1559, 4294967295
  %_0.sroa.0.0.i1562 = select i1 %_16.i1560, i64 %_17.i1561, i64 %res.sroa.0.0.i1559
  %_16.i209 = mul nuw i128 %_11.i201, %_14.i394
  %x_lo.i1531 = trunc i128 %_16.i209 to i64
  %_4.i1532 = lshr i128 %_16.i209, 64
  %x_hi.i1533 = trunc nuw i128 %_4.i1532 to i64
  %x_hi_hi.i1534 = lshr i64 %x_hi.i1533, 32
  %x_hi_lo.i1535 = and i64 %x_hi.i1533, 4294967295
  %_9.0.i1536 = sub i64 %x_lo.i1531, %x_hi_hi.i1534
  %_9.1.i1537 = icmp ugt i64 %x_hi_hi.i1534, %x_lo.i1531
  %_10.i1538 = add i64 %_9.0.i1536, -4294967295
  %spec.select.i1539 = select i1 %_9.1.i1537, i64 %_10.i1538, i64 %_9.0.i1536
  %t1.i1540 = mul nuw i64 %x_hi_lo.i1535, 4294967295
  %_14.0.i1541 = add i64 %spec.select.i1539, %t1.i1540
  %_14.1.i1542 = icmp ult i64 %_14.0.i1541, %spec.select.i1539
  %173 = add i64 %_14.0.i1541, 4294967295
  %res.sroa.0.0.i1543 = select i1 %_14.1.i1542, i64 %173, i64 %_14.0.i1541
  %_16.i1544 = icmp ugt i64 %res.sroa.0.0.i1543, -4294967296
  %_17.i1545 = add nsw i64 %res.sroa.0.0.i1543, 4294967295
  %_0.sroa.0.0.i1546 = select i1 %_16.i1544, i64 %_17.i1545, i64 %res.sroa.0.0.i1543
  %_17.i211 = mul nuw i128 %_14.i205, %_11.i390
  %x_lo.i1515 = trunc i128 %_17.i211 to i64
  %_4.i1516 = lshr i128 %_17.i211, 64
  %x_hi.i1517 = trunc nuw i128 %_4.i1516 to i64
  %x_hi_hi.i1518 = lshr i64 %x_hi.i1517, 32
  %x_hi_lo.i1519 = and i64 %x_hi.i1517, 4294967295
  %_9.0.i1520 = sub i64 %x_lo.i1515, %x_hi_hi.i1518
  %_9.1.i1521 = icmp ugt i64 %x_hi_hi.i1518, %x_lo.i1515
  %_10.i1522 = add i64 %_9.0.i1520, -4294967295
  %spec.select.i1523 = select i1 %_9.1.i1521, i64 %_10.i1522, i64 %_9.0.i1520
  %t1.i1524 = mul nuw i64 %x_hi_lo.i1519, 4294967295
  %_14.0.i1525 = add i64 %spec.select.i1523, %t1.i1524
  %_14.1.i1526 = icmp ult i64 %_14.0.i1525, %spec.select.i1523
  %174 = add i64 %_14.0.i1525, 4294967295
  %res.sroa.0.0.i1527 = select i1 %_14.1.i1526, i64 %174, i64 %_14.0.i1525
  %_16.i1528 = icmp ugt i64 %res.sroa.0.0.i1527, -4294967296
  %_17.i1529 = add nsw i64 %res.sroa.0.0.i1527, 4294967295
  %_0.sroa.0.0.i1530 = select i1 %_16.i1528, i64 %_17.i1529, i64 %res.sroa.0.0.i1527
  %_19.i213 = zext i64 %_0.sroa.0.0.i1562 to i128
  %_18.i214 = mul nuw nsw i128 %_19.i213, 7
  %x_lo.i1499 = trunc i128 %_18.i214 to i64
  %_4.i1500 = lshr i128 %_18.i214, 64
  %x_hi.i1501 = trunc nuw nsw i128 %_4.i1500 to i64
  %t1.i1508 = mul nuw nsw i64 %x_hi.i1501, 4294967295
  %_14.0.i1509 = add i64 %t1.i1508, %x_lo.i1499
  %_14.1.i1510 = icmp ult i64 %_14.0.i1509, %x_lo.i1499
  %175 = add i64 %_14.0.i1509, 4294967295
  %res.sroa.0.0.i1511 = select i1 %_14.1.i1510, i64 %175, i64 %_14.0.i1509
  %_16.i1512 = icmp ugt i64 %res.sroa.0.0.i1511, -4294967296
  %_17.i1513 = add nsw i64 %res.sroa.0.0.i1511, 4294967295
  %_0.sroa.0.0.i1514 = select i1 %_16.i1512, i64 %_17.i1513, i64 %res.sroa.0.0.i1511
  %_22.0.i216 = add i64 %_0.sroa.0.0.i1578, %_0.sroa.0.0.i1514
  %_22.1.i217 = icmp ult i64 %_22.0.i216, %_0.sroa.0.0.i1578
  %176 = add nuw i64 %_22.0.i216, 4294967295
  %_24.sroa.0.0.i218 = select i1 %_22.1.i217, i64 %176, i64 %_22.0.i216
  %_25.i219 = icmp ugt i64 %_24.sroa.0.0.i218, -4294967296
  %_26.i220 = add nsw i64 %_24.sroa.0.0.i218, 4294967295
  %_7.sroa.0.0.i221 = select i1 %_25.i219, i64 %_26.i220, i64 %_24.sroa.0.0.i218
  %_29.0.i222 = add i64 %_0.sroa.0.0.i1546, %_0.sroa.0.0.i1530
  %_29.1.i223 = icmp ult i64 %_29.0.i222, %_0.sroa.0.0.i1546
  %177 = add nuw i64 %_29.0.i222, 4294967295
  %_30.sroa.0.0.i224 = select i1 %_29.1.i223, i64 %177, i64 %_29.0.i222
  %_31.i225 = icmp ugt i64 %_30.sroa.0.0.i224, -4294967296
  %_32.i226 = add nsw i64 %_30.sroa.0.0.i224, 4294967295
  %_9.sroa.0.0.i227 = select i1 %_31.i225, i64 %_32.i226, i64 %_30.sroa.0.0.i224
  %_11.i179 = zext i64 %_7.sroa.0.0.i221 to i128
  %_10.i181 = mul nuw i128 %_11.i179, %_12.i526
  %x_lo.i1643 = trunc i128 %_10.i181 to i64
  %_4.i1644 = lshr i128 %_10.i181, 64
  %x_hi.i1645 = trunc nuw i128 %_4.i1644 to i64
  %x_hi_hi.i1646 = lshr i64 %x_hi.i1645, 32
  %x_hi_lo.i1647 = and i64 %x_hi.i1645, 4294967295
  %_9.0.i1648 = sub i64 %x_lo.i1643, %x_hi_hi.i1646
  %_9.1.i1649 = icmp ugt i64 %x_hi_hi.i1646, %x_lo.i1643
  %_10.i1650 = add i64 %_9.0.i1648, -4294967295
  %spec.select.i1651 = select i1 %_9.1.i1649, i64 %_10.i1650, i64 %_9.0.i1648
  %t1.i1652 = mul nuw i64 %x_hi_lo.i1647, 4294967295
  %_14.0.i1653 = add i64 %spec.select.i1651, %t1.i1652
  %_14.1.i1654 = icmp ult i64 %_14.0.i1653, %spec.select.i1651
  %178 = add i64 %_14.0.i1653, 4294967295
  %res.sroa.0.0.i1655 = select i1 %_14.1.i1654, i64 %178, i64 %_14.0.i1653
  %_16.i1656 = icmp ugt i64 %res.sroa.0.0.i1655, -4294967296
  %_17.i1657 = add nsw i64 %res.sroa.0.0.i1655, 4294967295
  %_0.sroa.0.0.i1658 = select i1 %_16.i1656, i64 %_17.i1657, i64 %res.sroa.0.0.i1655
  %_14.i182 = zext i64 %_9.sroa.0.0.i227 to i128
  %_13.i184 = mul nuw i128 %_14.i182, %_15.i530
  %x_lo.i1627 = trunc i128 %_13.i184 to i64
  %_4.i1628 = lshr i128 %_13.i184, 64
  %x_hi.i1629 = trunc nuw i128 %_4.i1628 to i64
  %x_hi_hi.i1630 = lshr i64 %x_hi.i1629, 32
  %x_hi_lo.i1631 = and i64 %x_hi.i1629, 4294967295
  %_9.0.i1632 = sub i64 %x_lo.i1627, %x_hi_hi.i1630
  %_9.1.i1633 = icmp ugt i64 %x_hi_hi.i1630, %x_lo.i1627
  %_10.i1634 = add i64 %_9.0.i1632, -4294967295
  %spec.select.i1635 = select i1 %_9.1.i1633, i64 %_10.i1634, i64 %_9.0.i1632
  %t1.i1636 = mul nuw i64 %x_hi_lo.i1631, 4294967295
  %_14.0.i1637 = add i64 %spec.select.i1635, %t1.i1636
  %_14.1.i1638 = icmp ult i64 %_14.0.i1637, %spec.select.i1635
  %179 = add i64 %_14.0.i1637, 4294967295
  %res.sroa.0.0.i1639 = select i1 %_14.1.i1638, i64 %179, i64 %_14.0.i1637
  %_16.i1640 = icmp ugt i64 %res.sroa.0.0.i1639, -4294967296
  %_17.i1641 = add nsw i64 %res.sroa.0.0.i1639, 4294967295
  %_0.sroa.0.0.i1642 = select i1 %_16.i1640, i64 %_17.i1641, i64 %res.sroa.0.0.i1639
  %_16.i185 = mul nuw i128 %_11.i179, %_15.i530
  %x_lo.i1611 = trunc i128 %_16.i185 to i64
  %_4.i1612 = lshr i128 %_16.i185, 64
  %x_hi.i1613 = trunc nuw i128 %_4.i1612 to i64
  %x_hi_hi.i1614 = lshr i64 %x_hi.i1613, 32
  %x_hi_lo.i1615 = and i64 %x_hi.i1613, 4294967295
  %_9.0.i1616 = sub i64 %x_lo.i1611, %x_hi_hi.i1614
  %_9.1.i1617 = icmp ugt i64 %x_hi_hi.i1614, %x_lo.i1611
  %_10.i1618 = add i64 %_9.0.i1616, -4294967295
  %spec.select.i1619 = select i1 %_9.1.i1617, i64 %_10.i1618, i64 %_9.0.i1616
  %t1.i1620 = mul nuw i64 %x_hi_lo.i1615, 4294967295
  %_14.0.i1621 = add i64 %spec.select.i1619, %t1.i1620
  %_14.1.i1622 = icmp ult i64 %_14.0.i1621, %spec.select.i1619
  %180 = add i64 %_14.0.i1621, 4294967295
  %res.sroa.0.0.i1623 = select i1 %_14.1.i1622, i64 %180, i64 %_14.0.i1621
  %_16.i1624 = icmp ugt i64 %res.sroa.0.0.i1623, -4294967296
  %_17.i1625 = add nsw i64 %res.sroa.0.0.i1623, 4294967295
  %_0.sroa.0.0.i1626 = select i1 %_16.i1624, i64 %_17.i1625, i64 %res.sroa.0.0.i1623
  %_17.i186 = mul nuw i128 %_14.i182, %_12.i526
  %x_lo.i1595 = trunc i128 %_17.i186 to i64
  %_4.i1596 = lshr i128 %_17.i186, 64
  %x_hi.i1597 = trunc nuw i128 %_4.i1596 to i64
  %x_hi_hi.i1598 = lshr i64 %x_hi.i1597, 32
  %x_hi_lo.i1599 = and i64 %x_hi.i1597, 4294967295
  %_9.0.i1600 = sub i64 %x_lo.i1595, %x_hi_hi.i1598
  %_9.1.i1601 = icmp ugt i64 %x_hi_hi.i1598, %x_lo.i1595
  %_10.i1602 = add i64 %_9.0.i1600, -4294967295
  %spec.select.i1603 = select i1 %_9.1.i1601, i64 %_10.i1602, i64 %_9.0.i1600
  %t1.i1604 = mul nuw i64 %x_hi_lo.i1599, 4294967295
  %_14.0.i1605 = add i64 %spec.select.i1603, %t1.i1604
  %_14.1.i1606 = icmp ult i64 %_14.0.i1605, %spec.select.i1603
  %181 = add i64 %_14.0.i1605, 4294967295
  %res.sroa.0.0.i1607 = select i1 %_14.1.i1606, i64 %181, i64 %_14.0.i1605
  %_16.i1608 = icmp ugt i64 %res.sroa.0.0.i1607, -4294967296
  %_17.i1609 = add nsw i64 %res.sroa.0.0.i1607, 4294967295
  %_0.sroa.0.0.i1610 = select i1 %_16.i1608, i64 %_17.i1609, i64 %res.sroa.0.0.i1607
  %_19.i187 = zext i64 %_0.sroa.0.0.i1642 to i128
  %_18.i188 = mul nuw nsw i128 %_19.i187, 7
  %x_lo.i1579 = trunc i128 %_18.i188 to i64
  %_4.i1580 = lshr i128 %_18.i188, 64
  %x_hi.i1581 = trunc nuw nsw i128 %_4.i1580 to i64
  %t1.i1588 = mul nuw nsw i64 %x_hi.i1581, 4294967295
  %_14.0.i1589 = add i64 %t1.i1588, %x_lo.i1579
  %_14.1.i1590 = icmp ult i64 %_14.0.i1589, %x_lo.i1579
  %182 = add i64 %_14.0.i1589, 4294967295
  %res.sroa.0.0.i1591 = select i1 %_14.1.i1590, i64 %182, i64 %_14.0.i1589
  %_16.i1592 = icmp ugt i64 %res.sroa.0.0.i1591, -4294967296
  %_17.i1593 = add nsw i64 %res.sroa.0.0.i1591, 4294967295
  %_0.sroa.0.0.i1594 = select i1 %_16.i1592, i64 %_17.i1593, i64 %res.sroa.0.0.i1591
  %_22.0.i189 = add i64 %_0.sroa.0.0.i1594, %_0.sroa.0.0.i1658
  %_22.1.i190 = icmp ult i64 %_22.0.i189, %_0.sroa.0.0.i1658
  %183 = add nuw i64 %_22.0.i189, 4294967295
  %_24.sroa.0.0.i191 = select i1 %_22.1.i190, i64 %183, i64 %_22.0.i189
  %_25.i192 = icmp ugt i64 %_24.sroa.0.0.i191, -4294967296
  %_26.i193 = add nsw i64 %_24.sroa.0.0.i191, 4294967295
  %_7.sroa.0.0.i194 = select i1 %_25.i192, i64 %_26.i193, i64 %_24.sroa.0.0.i191
  %_29.0.i195 = add i64 %_0.sroa.0.0.i1626, %_0.sroa.0.0.i1610
  %_29.1.i196 = icmp ult i64 %_29.0.i195, %_0.sroa.0.0.i1626
  %184 = add nuw i64 %_29.0.i195, 4294967295
  %_30.sroa.0.0.i197 = select i1 %_29.1.i196, i64 %184, i64 %_29.0.i195
  %_31.i198 = icmp ugt i64 %_30.sroa.0.0.i197, -4294967296
  %_32.i199 = add nsw i64 %_30.sroa.0.0.i197, 4294967295
  %_9.sroa.0.0.i200 = select i1 %_31.i198, i64 %_32.i199, i64 %_30.sroa.0.0.i197
  %_7.0.i27 = add i64 %_7.sroa.0.0.i194, %_3.sroa.0.0.i44
  %_7.1.i28 = icmp ult i64 %_7.0.i27, %_3.sroa.0.0.i44
  %185 = add i64 %_7.0.i27, 4294967295
  %_8.sroa.0.0.i29 = select i1 %_7.1.i28, i64 %185, i64 %_7.0.i27
  %_9.i30 = icmp ugt i64 %_8.sroa.0.0.i29, -4294967296
  %_10.i31 = add nsw i64 %_8.sroa.0.0.i29, 4294967295
  %_3.sroa.0.0.i32 = select i1 %_9.i30, i64 %_10.i31, i64 %_8.sroa.0.0.i29
  %_13.0.i33 = add i64 %_9.sroa.0.0.i200, %_4.sroa.0.0.i50
  %_13.1.i34 = icmp ult i64 %_13.0.i33, %_4.sroa.0.0.i50
  %186 = add i64 %_13.0.i33, 4294967295
  %_14.sroa.0.0.i35 = select i1 %_13.1.i34, i64 %186, i64 %_13.0.i33
  %_15.i36 = icmp ugt i64 %_14.sroa.0.0.i35, -4294967296
  %_16.i37 = add nsw i64 %_14.sroa.0.0.i35, 4294967295
  %_4.sroa.0.0.i38 = select i1 %_15.i36, i64 %_16.i37, i64 %_14.sroa.0.0.i35
  %187 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i32, 0
  %188 = insertvalue { i64, i64 } %187, i64 %_4.sroa.0.0.i38, 1
  call void @llvm.lifetime.end.p0(ptr nonnull %at)
  ret { i64, i64 } %188

panic17:                                          ; preds = %bb104
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 2, i64 noundef 2, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_f3da9c566178cc480d49fd92cad34aad) #21
  unreachable

bb26:                                             ; preds = %bb9.i
  %_16.i.i = getelementptr inbounds nuw i8, ptr %ptr.i.i17461761, i64 16
  %_11.i.i.i = add nuw nsw i64 %_10.i.i.i17481760, 1
  %self3.i.i.i = getelementptr inbounds nuw %"core::mem::maybe_uninit::MaybeUninit<field::Fp2>", ptr %_57.sroa.5.0.iter.sroa_idx, i64 %_10.i.i.i17481760
  %_14.0.i.i.i = load i64, ptr %self3.i.i.i, align 8, !alias.scope !80, !noalias !87, !noundef !3
  %189 = getelementptr inbounds nuw i8, ptr %self3.i.i.i, i64 8
  %_14.1.i.i.i = load i64, ptr %189, align 8, !alias.scope !80, !noalias !87, !noundef !3
  %_68.0 = load i64, ptr %ptr.i.i17461761, align 8, !noundef !3
  %190 = getelementptr inbounds nuw i8, ptr %ptr.i.i17461761, i64 8
  %_68.1 = load i64, ptr %190, align 8, !noundef !3
  %_11.i = zext i64 %_68.0 to i128
  %_12.i = zext i64 %_14.0.i.i.i to i128
  %_10.i171 = mul nuw i128 %_11.i, %_12.i
  %x_lo.i1723 = trunc i128 %_10.i171 to i64
  %_4.i1724 = lshr i128 %_10.i171, 64
  %x_hi.i1725 = trunc nuw i128 %_4.i1724 to i64
  %x_hi_hi.i1726 = lshr i64 %x_hi.i1725, 32
  %x_hi_lo.i1727 = and i64 %x_hi.i1725, 4294967295
  %_9.0.i1728 = sub i64 %x_lo.i1723, %x_hi_hi.i1726
  %_9.1.i1729 = icmp ugt i64 %x_hi_hi.i1726, %x_lo.i1723
  %_10.i1730 = add i64 %_9.0.i1728, -4294967295
  %spec.select.i1731 = select i1 %_9.1.i1729, i64 %_10.i1730, i64 %_9.0.i1728
  %t1.i1732 = mul nuw i64 %x_hi_lo.i1727, 4294967295
  %_14.0.i1733 = add i64 %spec.select.i1731, %t1.i1732
  %_14.1.i1734 = icmp ult i64 %_14.0.i1733, %spec.select.i1731
  %191 = add i64 %_14.0.i1733, 4294967295
  %res.sroa.0.0.i1735 = select i1 %_14.1.i1734, i64 %191, i64 %_14.0.i1733
  %_16.i1736 = icmp ugt i64 %res.sroa.0.0.i1735, -4294967296
  %_17.i1737 = add nsw i64 %res.sroa.0.0.i1735, 4294967295
  %_0.sroa.0.0.i1738 = select i1 %_16.i1736, i64 %_17.i1737, i64 %res.sroa.0.0.i1735
  %_14.i = zext i64 %_68.1 to i128
  %_15.i172 = zext i64 %_14.1.i.i.i to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i172
  %x_lo.i1707 = trunc i128 %_13.i to i64
  %_4.i1708 = lshr i128 %_13.i, 64
  %x_hi.i1709 = trunc nuw i128 %_4.i1708 to i64
  %x_hi_hi.i1710 = lshr i64 %x_hi.i1709, 32
  %x_hi_lo.i1711 = and i64 %x_hi.i1709, 4294967295
  %_9.0.i1712 = sub i64 %x_lo.i1707, %x_hi_hi.i1710
  %_9.1.i1713 = icmp ugt i64 %x_hi_hi.i1710, %x_lo.i1707
  %_10.i1714 = add i64 %_9.0.i1712, -4294967295
  %spec.select.i1715 = select i1 %_9.1.i1713, i64 %_10.i1714, i64 %_9.0.i1712
  %t1.i1716 = mul nuw i64 %x_hi_lo.i1711, 4294967295
  %_14.0.i1717 = add i64 %spec.select.i1715, %t1.i1716
  %_14.1.i1718 = icmp ult i64 %_14.0.i1717, %spec.select.i1715
  %192 = add i64 %_14.0.i1717, 4294967295
  %res.sroa.0.0.i1719 = select i1 %_14.1.i1718, i64 %192, i64 %_14.0.i1717
  %_16.i1720 = icmp ugt i64 %res.sroa.0.0.i1719, -4294967296
  %_17.i1721 = add nsw i64 %res.sroa.0.0.i1719, 4294967295
  %_0.sroa.0.0.i1722 = select i1 %_16.i1720, i64 %_17.i1721, i64 %res.sroa.0.0.i1719
  %_16.i173 = mul nuw i128 %_11.i, %_15.i172
  %x_lo.i1691 = trunc i128 %_16.i173 to i64
  %_4.i1692 = lshr i128 %_16.i173, 64
  %x_hi.i1693 = trunc nuw i128 %_4.i1692 to i64
  %x_hi_hi.i1694 = lshr i64 %x_hi.i1693, 32
  %x_hi_lo.i1695 = and i64 %x_hi.i1693, 4294967295
  %_9.0.i1696 = sub i64 %x_lo.i1691, %x_hi_hi.i1694
  %_9.1.i1697 = icmp ugt i64 %x_hi_hi.i1694, %x_lo.i1691
  %_10.i1698 = add i64 %_9.0.i1696, -4294967295
  %spec.select.i1699 = select i1 %_9.1.i1697, i64 %_10.i1698, i64 %_9.0.i1696
  %t1.i1700 = mul nuw i64 %x_hi_lo.i1695, 4294967295
  %_14.0.i1701 = add i64 %spec.select.i1699, %t1.i1700
  %_14.1.i1702 = icmp ult i64 %_14.0.i1701, %spec.select.i1699
  %193 = add i64 %_14.0.i1701, 4294967295
  %res.sroa.0.0.i1703 = select i1 %_14.1.i1702, i64 %193, i64 %_14.0.i1701
  %_16.i1704 = icmp ugt i64 %res.sroa.0.0.i1703, -4294967296
  %_17.i1705 = add nsw i64 %res.sroa.0.0.i1703, 4294967295
  %_0.sroa.0.0.i1706 = select i1 %_16.i1704, i64 %_17.i1705, i64 %res.sroa.0.0.i1703
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i1675 = trunc i128 %_17.i to i64
  %_4.i1676 = lshr i128 %_17.i, 64
  %x_hi.i1677 = trunc nuw i128 %_4.i1676 to i64
  %x_hi_hi.i1678 = lshr i64 %x_hi.i1677, 32
  %x_hi_lo.i1679 = and i64 %x_hi.i1677, 4294967295
  %_9.0.i1680 = sub i64 %x_lo.i1675, %x_hi_hi.i1678
  %_9.1.i1681 = icmp ugt i64 %x_hi_hi.i1678, %x_lo.i1675
  %_10.i1682 = add i64 %_9.0.i1680, -4294967295
  %spec.select.i1683 = select i1 %_9.1.i1681, i64 %_10.i1682, i64 %_9.0.i1680
  %t1.i1684 = mul nuw i64 %x_hi_lo.i1679, 4294967295
  %_14.0.i1685 = add i64 %spec.select.i1683, %t1.i1684
  %_14.1.i1686 = icmp ult i64 %_14.0.i1685, %spec.select.i1683
  %194 = add i64 %_14.0.i1685, 4294967295
  %res.sroa.0.0.i1687 = select i1 %_14.1.i1686, i64 %194, i64 %_14.0.i1685
  %_16.i1688 = icmp ugt i64 %res.sroa.0.0.i1687, -4294967296
  %_17.i1689 = add nsw i64 %res.sroa.0.0.i1687, 4294967295
  %_0.sroa.0.0.i1690 = select i1 %_16.i1688, i64 %_17.i1689, i64 %res.sroa.0.0.i1687
  %_19.i = zext i64 %_0.sroa.0.0.i1722 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i1659 = trunc i128 %_18.i to i64
  %_4.i1660 = lshr i128 %_18.i, 64
  %x_hi.i1661 = trunc nuw nsw i128 %_4.i1660 to i64
  %t1.i1668 = mul nuw nsw i64 %x_hi.i1661, 4294967295
  %_14.0.i1669 = add i64 %t1.i1668, %x_lo.i1659
  %_14.1.i1670 = icmp ult i64 %_14.0.i1669, %x_lo.i1659
  %195 = add i64 %_14.0.i1669, 4294967295
  %res.sroa.0.0.i1671 = select i1 %_14.1.i1670, i64 %195, i64 %_14.0.i1669
  %_16.i1672 = icmp ugt i64 %res.sroa.0.0.i1671, -4294967296
  %_17.i1673 = add nsw i64 %res.sroa.0.0.i1671, 4294967295
  %_0.sroa.0.0.i1674 = select i1 %_16.i1672, i64 %_17.i1673, i64 %res.sroa.0.0.i1671
  %_22.0.i = add i64 %_0.sroa.0.0.i1674, %_0.sroa.0.0.i1738
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i1738
  %196 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %196, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i1690, %_0.sroa.0.0.i1706
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i1706
  %197 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %197, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %clauses.sroa.0.01763
  %_7.1.i = icmp ult i64 %_7.0.i, %clauses.sroa.0.01763
  %198 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %198, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %clauses.sroa.4.01762
  %_13.1.i = icmp ult i64 %_13.0.i, %clauses.sroa.4.01762
  %199 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %199, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %_6.i.i = icmp eq ptr %_16.i.i, %_214
  br i1 %_6.i.i, label %bb24, label %bb9.i
}

; isolated::factory_3::{closure#1}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(272) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
  %iter = alloca [96 x i8], align 8
  %at = alloca [24 x i8], align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %at)
  %_4 = getelementptr inbounds nuw i8, ptr %_1, i64 16
  store ptr %v.0, ptr %at, align 8
  %0 = getelementptr inbounds nuw i8, ptr %at, i64 8
  store i64 %v.1, ptr %0, align 8
  %1 = getelementptr inbounds nuw i8, ptr %at, i64 16
  store ptr %_4, ptr %1, align 8
  %_7 = getelementptr inbounds nuw i8, ptr %_1, i64 152
  %2 = getelementptr inbounds nuw i8, ptr %_1, i64 24
  %_100 = load ptr, ptr %2, align 8, !nonnull !3, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %_1, i64 32
  %_99 = load i64, ptr %3, align 8, !noundef !3
  %_101 = icmp ugt i64 %_99, 67
  br i1 %_101, label %bb45, label %panic

bb45:                                             ; preds = %start
  %_94 = getelementptr inbounds nuw i8, ptr %_100, i64 536
  %_93 = load i64, ptr %_94, align 8, !noundef !3
  %_96 = icmp ult i64 %_93, %v.1
  br i1 %_96, label %bb44, label %panic1

panic:                                            ; preds = %start
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 67, i64 noundef %_99, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3473ff63602946e5bae196369fb1e157) #21
  unreachable

bb44:                                             ; preds = %bb45
  %4 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_93
  %g8.0 = load i64, ptr %4, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 8
  %g8.1 = load i64, ptr %5, align 8, !noundef !3
  %_105 = icmp ugt i64 %_99, 69
  br i1 %_105, label %bb47, label %panic2

panic1:                                           ; preds = %bb45
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_93, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable

bb47:                                             ; preds = %bb44
  %_103 = getelementptr inbounds nuw i8, ptr %_100, i64 552
  %_102 = load i64, ptr %_103, align 8, !noundef !3
  %_104 = icmp ult i64 %_102, %v.1
  br i1 %_104, label %bb46, label %panic3

panic2:                                           ; preds = %bb44
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 69, i64 noundef %_99, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3473ff63602946e5bae196369fb1e157) #21
  unreachable

bb46:                                             ; preds = %bb47
  %6 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_102
  %a16.0 = load i64, ptr %6, align 8, !noundef !3
  %7 = getelementptr inbounds nuw i8, ptr %6, i64 8
  %a16.1 = load i64, ptr %7, align 8, !noundef !3
  %_109.not = icmp eq i64 %_99, 70
  br i1 %_109.not, label %panic4, label %bb49

panic3:                                           ; preds = %bb47
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_102, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable

bb49:                                             ; preds = %bb46
  %_107 = getelementptr inbounds nuw i8, ptr %_100, i64 560
  %_106 = load i64, ptr %_107, align 8, !noundef !3
  %_108 = icmp ult i64 %_106, %v.1
  br i1 %_108, label %bb48, label %panic5

panic4:                                           ; preds = %bb46
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 70, i64 noundef 70, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3473ff63602946e5bae196369fb1e157) #21
  unreachable

bb48:                                             ; preds = %bb49
  %8 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_106
  %u16.0 = load i64, ptr %8, align 8, !noundef !3
  %9 = getelementptr inbounds nuw i8, ptr %8, i64 8
  %u16.1 = load i64, ptr %9, align 8, !noundef !3
  %_113 = icmp ugt i64 %_99, 73
  br i1 %_113, label %bb51, label %panic6

panic5:                                           ; preds = %bb49
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_106, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable

bb51:                                             ; preds = %bb48
  %_111 = getelementptr inbounds nuw i8, ptr %_100, i64 584
  %_110 = load i64, ptr %_111, align 8, !noundef !3
  %_112 = icmp ult i64 %_110, %v.1
  br i1 %_112, label %bb50, label %panic7

panic6:                                           ; preds = %bb48
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 73, i64 noundef %_99, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3473ff63602946e5bae196369fb1e157) #21
  unreachable

bb50:                                             ; preds = %bb51
  %10 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_110
  %h16.0 = load i64, ptr %10, align 8, !noundef !3
  %11 = getelementptr inbounds nuw i8, ptr %10, i64 8
  %h16.1 = load i64, ptr %11, align 8, !noundef !3
  %_11.i471 = zext i64 %a16.0 to i128
  %_12.i472 = zext i64 %u16.0 to i128
  %_10.i473 = mul nuw i128 %_12.i472, %_11.i471
  %x_lo.i549 = trunc i128 %_10.i473 to i64
  %_4.i550 = lshr i128 %_10.i473, 64
  %x_hi.i551 = trunc nuw i128 %_4.i550 to i64
  %x_hi_hi.i552 = lshr i64 %x_hi.i551, 32
  %x_hi_lo.i553 = and i64 %x_hi.i551, 4294967295
  %_9.0.i554 = sub i64 %x_lo.i549, %x_hi_hi.i552
  %_9.1.i555 = icmp ugt i64 %x_hi_hi.i552, %x_lo.i549
  %_10.i556 = add i64 %_9.0.i554, -4294967295
  %spec.select.i557 = select i1 %_9.1.i555, i64 %_10.i556, i64 %_9.0.i554
  %t1.i558 = mul nuw i64 %x_hi_lo.i553, 4294967295
  %_14.0.i559 = add i64 %spec.select.i557, %t1.i558
  %_14.1.i560 = icmp ult i64 %_14.0.i559, %spec.select.i557
  %12 = add i64 %_14.0.i559, 4294967295
  %res.sroa.0.0.i561 = select i1 %_14.1.i560, i64 %12, i64 %_14.0.i559
  %_16.i562 = icmp ugt i64 %res.sroa.0.0.i561, -4294967296
  %_17.i563 = add nsw i64 %res.sroa.0.0.i561, 4294967295
  %_0.sroa.0.0.i564 = select i1 %_16.i562, i64 %_17.i563, i64 %res.sroa.0.0.i561
  %_14.i475 = zext i64 %a16.1 to i128
  %_15.i476 = zext i64 %u16.1 to i128
  %_13.i477 = mul nuw i128 %_15.i476, %_14.i475
  %x_lo.i533 = trunc i128 %_13.i477 to i64
  %_4.i534 = lshr i128 %_13.i477, 64
  %x_hi.i535 = trunc nuw i128 %_4.i534 to i64
  %x_hi_hi.i536 = lshr i64 %x_hi.i535, 32
  %x_hi_lo.i537 = and i64 %x_hi.i535, 4294967295
  %_9.0.i538 = sub i64 %x_lo.i533, %x_hi_hi.i536
  %_9.1.i539 = icmp ugt i64 %x_hi_hi.i536, %x_lo.i533
  %_10.i540 = add i64 %_9.0.i538, -4294967295
  %spec.select.i541 = select i1 %_9.1.i539, i64 %_10.i540, i64 %_9.0.i538
  %t1.i542 = mul nuw i64 %x_hi_lo.i537, 4294967295
  %_14.0.i543 = add i64 %spec.select.i541, %t1.i542
  %_14.1.i544 = icmp ult i64 %_14.0.i543, %spec.select.i541
  %13 = add i64 %_14.0.i543, 4294967295
  %res.sroa.0.0.i545 = select i1 %_14.1.i544, i64 %13, i64 %_14.0.i543
  %_16.i546 = icmp ugt i64 %res.sroa.0.0.i545, -4294967296
  %_17.i547 = add nsw i64 %res.sroa.0.0.i545, 4294967295
  %_0.sroa.0.0.i548 = select i1 %_16.i546, i64 %_17.i547, i64 %res.sroa.0.0.i545
  %_16.i479 = mul nuw i128 %_15.i476, %_11.i471
  %x_lo.i517 = trunc i128 %_16.i479 to i64
  %_4.i518 = lshr i128 %_16.i479, 64
  %x_hi.i519 = trunc nuw i128 %_4.i518 to i64
  %x_hi_hi.i520 = lshr i64 %x_hi.i519, 32
  %x_hi_lo.i521 = and i64 %x_hi.i519, 4294967295
  %_9.0.i522 = sub i64 %x_lo.i517, %x_hi_hi.i520
  %_9.1.i523 = icmp ugt i64 %x_hi_hi.i520, %x_lo.i517
  %_10.i524 = add i64 %_9.0.i522, -4294967295
  %spec.select.i525 = select i1 %_9.1.i523, i64 %_10.i524, i64 %_9.0.i522
  %t1.i526 = mul nuw i64 %x_hi_lo.i521, 4294967295
  %_14.0.i527 = add i64 %spec.select.i525, %t1.i526
  %_14.1.i528 = icmp ult i64 %_14.0.i527, %spec.select.i525
  %14 = add i64 %_14.0.i527, 4294967295
  %res.sroa.0.0.i529 = select i1 %_14.1.i528, i64 %14, i64 %_14.0.i527
  %_16.i530 = icmp ugt i64 %res.sroa.0.0.i529, -4294967296
  %_17.i531 = add nsw i64 %res.sroa.0.0.i529, 4294967295
  %_0.sroa.0.0.i532 = select i1 %_16.i530, i64 %_17.i531, i64 %res.sroa.0.0.i529
  %_17.i481 = mul nuw i128 %_12.i472, %_14.i475
  %x_lo.i501 = trunc i128 %_17.i481 to i64
  %_4.i502 = lshr i128 %_17.i481, 64
  %x_hi.i503 = trunc nuw i128 %_4.i502 to i64
  %x_hi_hi.i504 = lshr i64 %x_hi.i503, 32
  %x_hi_lo.i505 = and i64 %x_hi.i503, 4294967295
  %_9.0.i506 = sub i64 %x_lo.i501, %x_hi_hi.i504
  %_9.1.i507 = icmp ugt i64 %x_hi_hi.i504, %x_lo.i501
  %_10.i508 = add i64 %_9.0.i506, -4294967295
  %spec.select.i509 = select i1 %_9.1.i507, i64 %_10.i508, i64 %_9.0.i506
  %t1.i510 = mul nuw i64 %x_hi_lo.i505, 4294967295
  %_14.0.i511 = add i64 %spec.select.i509, %t1.i510
  %_14.1.i512 = icmp ult i64 %_14.0.i511, %spec.select.i509
  %15 = add i64 %_14.0.i511, 4294967295
  %res.sroa.0.0.i513 = select i1 %_14.1.i512, i64 %15, i64 %_14.0.i511
  %_16.i514 = icmp ugt i64 %res.sroa.0.0.i513, -4294967296
  %_17.i515 = add nsw i64 %res.sroa.0.0.i513, 4294967295
  %_0.sroa.0.0.i516 = select i1 %_16.i514, i64 %_17.i515, i64 %res.sroa.0.0.i513
  %_19.i483 = zext i64 %_0.sroa.0.0.i548 to i128
  %_18.i484 = mul nuw nsw i128 %_19.i483, 7
  %x_lo.i = trunc i128 %_18.i484 to i64
  %_4.i = lshr i128 %_18.i484, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %16 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %16, i64 %_14.0.i
  %_16.i499 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i500 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i499, i64 %_17.i500, i64 %res.sroa.0.0.i
  %_22.0.i486 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i564
  %_22.1.i487 = icmp ult i64 %_22.0.i486, %_0.sroa.0.0.i564
  %17 = add nuw i64 %_22.0.i486, 4294967295
  %_24.sroa.0.0.i488 = select i1 %_22.1.i487, i64 %17, i64 %_22.0.i486
  %_25.i489 = icmp ugt i64 %_24.sroa.0.0.i488, -4294967296
  %_26.i490 = add nsw i64 %_24.sroa.0.0.i488, 4294967295
  %_7.sroa.0.0.i491 = select i1 %_25.i489, i64 %_26.i490, i64 %_24.sroa.0.0.i488
  %_29.0.i492 = add i64 %_0.sroa.0.0.i532, %_0.sroa.0.0.i516
  %_29.1.i493 = icmp ult i64 %_29.0.i492, %_0.sroa.0.0.i532
  %18 = add nuw i64 %_29.0.i492, 4294967295
  %_30.sroa.0.0.i494 = select i1 %_29.1.i493, i64 %18, i64 %_29.0.i492
  %_31.i495 = icmp ugt i64 %_30.sroa.0.0.i494, -4294967296
  %_32.i496 = add nsw i64 %_30.sroa.0.0.i494, 4294967295
  %_9.sroa.0.0.i497 = select i1 %_31.i495, i64 %_32.i496, i64 %_30.sroa.0.0.i494
  %19 = getelementptr inbounds nuw i8, ptr %_1, i64 160
  %_250 = load i64, ptr %19, align 8, !noundef !3
  %_117 = zext i64 %h16.0 to i128
  %_118 = zext i64 %_250 to i128
  %_116 = mul nuw i128 %_118, %_117
  %x_lo.i1573 = trunc i128 %_116 to i64
  %_4.i1574 = lshr i128 %_116, 64
  %x_hi.i1575 = trunc nuw i128 %_4.i1574 to i64
  %x_hi_hi.i1576 = lshr i64 %x_hi.i1575, 32
  %x_hi_lo.i1577 = and i64 %x_hi.i1575, 4294967295
  %_9.0.i1578 = sub i64 %x_lo.i1573, %x_hi_hi.i1576
  %_9.1.i1579 = icmp ugt i64 %x_hi_hi.i1576, %x_lo.i1573
  %_10.i1580 = add i64 %_9.0.i1578, -4294967295
  %spec.select.i1581 = select i1 %_9.1.i1579, i64 %_10.i1580, i64 %_9.0.i1578
  %t1.i1582 = mul nuw i64 %x_hi_lo.i1577, 4294967295
  %_14.0.i1583 = add i64 %spec.select.i1581, %t1.i1582
  %_14.1.i1584 = icmp ult i64 %_14.0.i1583, %spec.select.i1581
  %20 = add i64 %_14.0.i1583, 4294967295
  %res.sroa.0.0.i1585 = select i1 %_14.1.i1584, i64 %20, i64 %_14.0.i1583
  %_16.i1586 = icmp ugt i64 %res.sroa.0.0.i1585, -4294967296
  %_17.i1587 = add nsw i64 %res.sroa.0.0.i1585, 4294967295
  %_0.sroa.0.0.i1588 = select i1 %_16.i1586, i64 %_17.i1587, i64 %res.sroa.0.0.i1585
  %_120 = zext i64 %h16.1 to i128
  %_119 = mul nuw i128 %_118, %_120
  %x_lo.i1557 = trunc i128 %_119 to i64
  %_4.i1558 = lshr i128 %_119, 64
  %x_hi.i1559 = trunc nuw i128 %_4.i1558 to i64
  %x_hi_hi.i1560 = lshr i64 %x_hi.i1559, 32
  %x_hi_lo.i1561 = and i64 %x_hi.i1559, 4294967295
  %_9.0.i1562 = sub i64 %x_lo.i1557, %x_hi_hi.i1560
  %_9.1.i1563 = icmp ugt i64 %x_hi_hi.i1560, %x_lo.i1557
  %_10.i1564 = add i64 %_9.0.i1562, -4294967295
  %spec.select.i1565 = select i1 %_9.1.i1563, i64 %_10.i1564, i64 %_9.0.i1562
  %t1.i1566 = mul nuw i64 %x_hi_lo.i1561, 4294967295
  %_14.0.i1567 = add i64 %spec.select.i1565, %t1.i1566
  %_14.1.i1568 = icmp ult i64 %_14.0.i1567, %spec.select.i1565
  %21 = add i64 %_14.0.i1567, 4294967295
  %res.sroa.0.0.i1569 = select i1 %_14.1.i1568, i64 %21, i64 %_14.0.i1567
  %_16.i1570 = icmp ugt i64 %res.sroa.0.0.i1569, -4294967296
  %_17.i1571 = add nsw i64 %res.sroa.0.0.i1569, 4294967295
  %_0.sroa.0.0.i1572 = select i1 %_16.i1570, i64 %_17.i1571, i64 %res.sroa.0.0.i1569
  %_123.0 = sub i64 %_7.sroa.0.0.i491, %_0.sroa.0.0.i1588
  %_123.1 = icmp ult i64 %_7.sroa.0.0.i491, %_0.sroa.0.0.i1588
  %22 = add i64 %_123.0, -4294967295
  %_124.sroa.0.0 = select i1 %_123.1, i64 %22, i64 %_123.0
  %_127.0 = sub i64 %_9.sroa.0.0.i497, %_0.sroa.0.0.i1572
  %_127.1 = icmp ult i64 %_9.sroa.0.0.i497, %_0.sroa.0.0.i1572
  %23 = add i64 %_127.0, -4294967295
  %_128.sroa.0.0 = select i1 %_127.1, i64 %23, i64 %_127.0
; call isolated::factory_3::{closure#1}::{closure#1}
  %24 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 76)
  %_15.0 = extractvalue { i64, i64 } %24, 0
  %_15.1 = extractvalue { i64, i64 } %24, 1
  %_135.0 = sub i64 %_124.sroa.0.0, %_15.0
  %_135.1 = icmp ult i64 %_124.sroa.0.0, %_15.0
  %25 = add i64 %_135.0, -4294967295
  %_136.sroa.0.0 = select i1 %_135.1, i64 %25, i64 %_135.0
  %_139.0 = sub i64 %_128.sroa.0.0, %_15.1
  %_139.1 = icmp ult i64 %_128.sroa.0.0, %_15.1
  %26 = add i64 %_139.0, -4294967295
  %_140.sroa.0.0 = select i1 %_139.1, i64 %26, i64 %_139.0
  %27 = getelementptr inbounds nuw i8, ptr %_1, i64 168
  %_17.0 = load i64, ptr %27, align 8, !noundef !3
  %28 = getelementptr inbounds nuw i8, ptr %_1, i64 176
  %_17.1 = load i64, ptr %28, align 8, !noundef !3
  %_7.0.i159 = add i64 %_136.sroa.0.0, %_17.0
  %_7.1.i160 = icmp ult i64 %_7.0.i159, %_136.sroa.0.0
  %29 = add i64 %_7.0.i159, 4294967295
  %_8.sroa.0.0.i161 = select i1 %_7.1.i160, i64 %29, i64 %_7.0.i159
  %_9.i162 = icmp ugt i64 %_8.sroa.0.0.i161, -4294967296
  %_10.i163 = add nsw i64 %_8.sroa.0.0.i161, 4294967295
  %_3.sroa.0.0.i164 = select i1 %_9.i162, i64 %_10.i163, i64 %_8.sroa.0.0.i161
  %_13.0.i165 = add i64 %_140.sroa.0.0, %_17.1
  %_13.1.i166 = icmp ult i64 %_13.0.i165, %_140.sroa.0.0
  %30 = add i64 %_13.0.i165, 4294967295
  %_14.sroa.0.0.i167 = select i1 %_13.1.i166, i64 %30, i64 %_13.0.i165
  %_15.i168 = icmp ugt i64 %_14.sroa.0.0.i167, -4294967296
  %_16.i169 = add nsw i64 %_14.sroa.0.0.i167, 4294967295
  %_4.sroa.0.0.i170 = select i1 %_15.i168, i64 %_16.i169, i64 %_14.sroa.0.0.i167
  %_7.1.i148 = icmp ugt i64 %u16.0, -32769
  %_8.sroa.0.0.i149.v = select i1 %_7.1.i148, i64 4295000063, i64 32768
  %_8.sroa.0.0.i149 = add i64 %_8.sroa.0.0.i149.v, %u16.0
  %_9.i150 = icmp ugt i64 %_8.sroa.0.0.i149, -4294967296
  %_10.i151 = add nsw i64 %_8.sroa.0.0.i149, 4294967295
  %_3.sroa.0.0.i152 = select i1 %_9.i150, i64 %_10.i151, i64 %_8.sroa.0.0.i149
  %_15.i156 = icmp ugt i64 %u16.1, -4294967296
  %_16.i157 = add nsw i64 %u16.1, 4294967295
  %_4.sroa.0.0.i158 = select i1 %_15.i156, i64 %_16.i157, i64 %u16.1
; call isolated::factory_3::{closure#1}::{closure#1}
  %31 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 71)
  %_21.0 = extractvalue { i64, i64 } %31, 0
  %_21.1 = extractvalue { i64, i64 } %31, 1
  %_148.0 = sub i64 %_3.sroa.0.0.i152, %_21.0
  %_148.1 = icmp ult i64 %_3.sroa.0.0.i152, %_21.0
  %32 = add i64 %_148.0, -4294967295
  %_149.sroa.0.0 = select i1 %_148.1, i64 %32, i64 %_148.0
  %_152.0 = sub i64 %_4.sroa.0.0.i158, %_21.1
  %_152.1 = icmp ult i64 %_4.sroa.0.0.i158, %_21.1
  %33 = add i64 %_152.0, -4294967295
  %_153.sroa.0.0 = select i1 %_152.1, i64 %33, i64 %_152.0
  %_7.1.i136 = icmp ugt i64 %h16.0, -32769
  %_8.sroa.0.0.i137.v = select i1 %_7.1.i136, i64 4295000063, i64 32768
  %_8.sroa.0.0.i137 = add i64 %_8.sroa.0.0.i137.v, %h16.0
  %_9.i138 = icmp ugt i64 %_8.sroa.0.0.i137, -4294967296
  %_10.i139 = add nsw i64 %_8.sroa.0.0.i137, 4294967295
  %_3.sroa.0.0.i140 = select i1 %_9.i138, i64 %_10.i139, i64 %_8.sroa.0.0.i137
  %_15.i144 = icmp ugt i64 %h16.1, -4294967296
  %_16.i145 = add nsw i64 %h16.1, 4294967295
  %_4.sroa.0.0.i146 = select i1 %_15.i144, i64 %_16.i145, i64 %h16.1
; call isolated::factory_3::{closure#1}::{closure#1}
  %34 = call fastcc { i64, i64 } @_RNCNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0s_0B5_(ptr nonnull %at, ptr nonnull %_7, i64 noundef 74)
  %_26.0 = extractvalue { i64, i64 } %34, 0
  %_26.1 = extractvalue { i64, i64 } %34, 1
  %_163.0 = sub i64 %_3.sroa.0.0.i140, %_26.0
  %_163.1 = icmp ult i64 %_3.sroa.0.0.i140, %_26.0
  %35 = add i64 %_163.0, -4294967295
  %_164.sroa.0.0 = select i1 %_163.1, i64 %35, i64 %_163.0
  %_167.0 = sub i64 %_4.sroa.0.0.i146, %_26.1
  %_167.1 = icmp ult i64 %_4.sroa.0.0.i146, %_26.1
  %36 = add i64 %_167.0, -4294967295
  %_168.sroa.0.0 = select i1 %_167.1, i64 %36, i64 %_167.0
  %37 = getelementptr inbounds nuw i8, ptr %_1, i64 184
  %_31 = load i64, ptr %37, align 8, !noundef !3
  %_32 = icmp ult i64 %_31, %v.1
  br i1 %_32, label %bb8, label %panic8

panic7:                                           ; preds = %bb51
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_110, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable

bb8:                                              ; preds = %bb50
  %38 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_31
  %_30.0 = load i64, ptr %38, align 8, !noundef !3
  %39 = getelementptr inbounds nuw i8, ptr %38, i64 8
  %_30.1 = load i64, ptr %39, align 8, !noundef !3
  %40 = getelementptr inbounds nuw i8, ptr %_1, i64 192
  %_257 = load i64, ptr %40, align 8, !noundef !3
  %41 = getelementptr inbounds nuw i8, ptr %_1, i64 200
  %_258 = load i64, ptr %41, align 8, !noundef !3
  %42 = getelementptr inbounds nuw i8, ptr %_1, i64 208
  %_39.0 = load i64, ptr %42, align 8, !noundef !3
  %43 = getelementptr inbounds nuw i8, ptr %_1, i64 216
  %_39.1 = load i64, ptr %43, align 8, !noundef !3
  %44 = getelementptr inbounds nuw i8, ptr %_1, i64 224
  %_40.0 = load i64, ptr %44, align 8, !noundef !3
  %45 = getelementptr inbounds nuw i8, ptr %_1, i64 232
  %_40.1 = load i64, ptr %45, align 8, !noundef !3
  %46 = load i64, ptr %_1, align 8, !range !56, !noundef !3
  %47 = getelementptr inbounds nuw i8, ptr %_1, i64 8
  %48 = load i64, ptr %47, align 8
  %49 = trunc nuw i64 %46 to i1
  br i1 %49, label %bb89, label %bb87

panic8:                                           ; preds = %bb50
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_31, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_d0a18ec8c4590cc3d9111a1a11b11099) #21
  unreachable

bb89:                                             ; preds = %bb8
  %_196 = icmp ult i64 %48, %v.1
  br i1 %_196, label %bb90, label %panic9

bb87:                                             ; preds = %bb8, %bb90
  %g.sroa.5.0 = phi i64 [ %54, %bb90 ], [ 0, %bb8 ]
  %g.sroa.0.0 = phi i64 [ %52, %bb90 ], [ 1, %bb8 ]
  %50 = getelementptr inbounds nuw i8, ptr %_1, i64 80
  %_203 = load i64, ptr %50, align 8, !noundef !3
  %_205 = icmp ult i64 %_203, 4
  br i1 %_205, label %bb91, label %bb9.i.preheader, !prof !57

bb90:                                             ; preds = %bb89
  %51 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %48
  %52 = load i64, ptr %51, align 8, !noundef !3
  %53 = getelementptr inbounds nuw i8, ptr %51, i64 8
  %54 = load i64, ptr %53, align 8, !noundef !3
  br label %bb87

panic9:                                           ; preds = %bb89
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %48, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_03bbe1d0fcdbd86f2216092eb0f02e36) #21
  unreachable

bb9.i.preheader:                                  ; preds = %bb87
  %55 = getelementptr inbounds nuw i8, ptr %_1, i64 72
  %_204 = load ptr, ptr %55, align 8, !nonnull !3, !noundef !3
  %56 = getelementptr inbounds nuw i8, ptr %_1, i64 240
  %_46 = load i64, ptr %56, align 8, !noundef !3
  %57 = getelementptr inbounds nuw i8, ptr %_1, i64 56
  %_199 = load i64, ptr %57, align 8, !noundef !3
  %58 = getelementptr inbounds nuw i8, ptr %_1, i64 48
  %_200 = load ptr, ptr %58, align 8, !nonnull !3, !noundef !3
  %_207 = add i64 %_203, -4
  %_211 = getelementptr inbounds nuw i8, ptr %_204, i64 64
; call isolated::helper_sum
  %59 = call fastcc { i64, i64 } @_RNvCsl0YfJI2rrfI_8isolated10helper_sum(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_200, i64 noundef %_199, i64 noundef %_46, i64 noundef %_257, i64 noundef %_258, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %_211, i64 noundef %_207)
  %_51 = getelementptr inbounds nuw i8, ptr %_204, i64 48
  %_50.0 = load i64, ptr %_51, align 8, !noundef !3
  %60 = getelementptr inbounds nuw i8, ptr %_204, i64 56
  %_50.1 = load i64, ptr %60, align 8, !noundef !3
  %_53 = getelementptr inbounds nuw i8, ptr %_1, i64 88
; call <isolated::PadTerm>::eval
  %61 = call fastcc { i64, i64 } @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(40) %_53, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef %v.1)
  %_216.idx = shl nuw nsw i64 %_203, 4
  %_216 = getelementptr inbounds nuw i8, ptr %_204, i64 %_216.idx
  %_55.sroa.6.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 80
  call void @llvm.lifetime.start.p0(ptr nonnull %iter)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %_55.sroa.6.0.iter.sroa_idx, i8 0, i64 16, i1 false)
  %_55.sroa.5.0.iter.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 32
  store i64 %_3.sroa.0.0.i164, ptr %_55.sroa.5.0.iter.sroa_idx, align 8
  %_55.sroa.5.sroa.2.0._55.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 40
  store i64 %_4.sroa.0.0.i170, ptr %_55.sroa.5.sroa.2.0._55.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_55.sroa.5.sroa.3.0._55.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 48
  store i64 %_149.sroa.0.0, ptr %_55.sroa.5.sroa.3.0._55.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_55.sroa.5.sroa.4.0._55.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 56
  store i64 %_153.sroa.0.0, ptr %_55.sroa.5.sroa.4.0._55.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_55.sroa.5.sroa.5.0._55.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 64
  store i64 %_164.sroa.0.0, ptr %_55.sroa.5.sroa.5.0._55.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  %_55.sroa.5.sroa.6.0._55.sroa.5.0.iter.sroa_idx.sroa_idx = getelementptr inbounds nuw i8, ptr %iter, i64 72
  store i64 %_168.sroa.0.0, ptr %_55.sroa.5.sroa.6.0._55.sroa.5.0.iter.sroa_idx.sroa_idx, align 8
  br label %bb9.i

bb91:                                             ; preds = %bb87
; call core::slice::index::slice_index_fail
  call void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 4, i64 noundef %_203, i64 noundef %_203, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_354dc1959db4c84bf13af6f86d635aee) #21
  unreachable

bb9.i:                                            ; preds = %bb9.i.preheader, %bb25
  %clauses.sroa.0.01613 = phi i64 [ %_3.sroa.0.0.i, %bb25 ], [ 0, %bb9.i.preheader ]
  %clauses.sroa.4.01612 = phi i64 [ %_4.sroa.0.0.i, %bb25 ], [ 0, %bb9.i.preheader ]
  %ptr.i.i15961611 = phi ptr [ %_16.i.i, %bb25 ], [ %_204, %bb9.i.preheader ]
  %_10.i.i.i15981610 = phi i64 [ %_11.i.i.i, %bb25 ], [ 0, %bb9.i.preheader ]
  %_5.not.i.i.i = icmp eq i64 %_10.i.i.i15981610, 3
  br i1 %_5.not.i.i.i, label %bb23, label %bb25

bb23:                                             ; preds = %bb9.i, %bb25
  %clauses.sroa.4.0.lcssa.ph = phi i64 [ %_4.sroa.0.0.i, %bb25 ], [ %clauses.sroa.4.01612, %bb9.i ]
  %clauses.sroa.0.0.lcssa.ph = phi i64 [ %_3.sroa.0.0.i, %bb25 ], [ %clauses.sroa.0.01613, %bb9.i ]
  call void @llvm.lifetime.end.p0(ptr nonnull %iter)
  %_229 = getelementptr inbounds nuw i8, ptr %_100, i64 544
  %_228 = load i64, ptr %_229, align 8, !noundef !3
  %_230 = icmp ult i64 %_228, %v.1
  br i1 %_230, label %bb97, label %panic12

bb97:                                             ; preds = %bb23
  %62 = getelementptr inbounds nuw i8, ptr %_1, i64 248
  %_252 = load i64, ptr %62, align 8, !noundef !3
  %63 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_228
  %_73.0 = load i64, ptr %63, align 8, !noundef !3
  %64 = getelementptr inbounds nuw i8, ptr %63, i64 8
  %_73.1 = load i64, ptr %64, align 8, !noundef !3
  %65 = getelementptr inbounds nuw i8, ptr %_1, i64 256
  %_261 = load i64, ptr %65, align 8, !noundef !3
  %66 = getelementptr inbounds nuw i8, ptr %_1, i64 264
  %_262 = load i64, ptr %66, align 8, !noundef !3
  %_76.0 = load i64, ptr %v.0, align 8, !noundef !3
  %67 = getelementptr inbounds nuw i8, ptr %v.0, i64 8
  %_76.1 = load i64, ptr %67, align 8, !noundef !3
  %68 = getelementptr inbounds nuw i8, ptr %_1, i64 136
  %_247 = load ptr, ptr %68, align 8, !nonnull !3, !noundef !3
  %69 = getelementptr inbounds nuw i8, ptr %_1, i64 144
  %_246 = load i64, ptr %69, align 8, !noundef !3
  %_248.not = icmp eq i64 %_246, 0
  br i1 %_248.not, label %panic14, label %bb105

panic12:                                          ; preds = %bb23
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_228, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8bedb038257b840dda514362a0f0e6d8) #21
  unreachable

bb105:                                            ; preds = %bb97
  %_84 = icmp samesign ugt i64 %v.1, 1
  br i1 %_84, label %bb32, label %panic15

panic14:                                          ; preds = %bb97
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 0, i64 noundef 0, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_38b3a9f276003767a8ae4525b00c9940) #21
  unreachable

bb32:                                             ; preds = %bb105
  %70 = getelementptr inbounds nuw i8, ptr %_247, i64 8
  %_81.1 = load i64, ptr %70, align 8, !noundef !3
  %_81.0 = load i64, ptr %_247, align 8, !noundef !3
  %71 = getelementptr inbounds nuw i8, ptr %v.0, i64 16
  %_83.0 = load i64, ptr %71, align 8, !noundef !3
  %72 = getelementptr inbounds nuw i8, ptr %v.0, i64 24
  %_83.1 = load i64, ptr %72, align 8, !noundef !3
  %_249.not = icmp eq i64 %_246, 1
  br i1 %_249.not, label %panic16, label %bb106

panic15:                                          ; preds = %bb105
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_95c9a529b9c6675768dc03a5e4eb87b8) #21
  unreachable

bb106:                                            ; preds = %bb32
  %_92.not = icmp eq i64 %v.1, 2
  br i1 %_92.not, label %panic17, label %bb37

panic16:                                          ; preds = %bb32
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 1, i64 noundef 1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_f1afeffee25b8cbad41bb5872529e5be) #21
  unreachable

bb37:                                             ; preds = %bb106
  %_11.i336 = zext i64 %_76.0 to i128
  %_44.1 = extractvalue { i64, i64 } %59, 1
  %_11.i390 = zext i64 %_50.0 to i128
  %_11.i417 = zext i64 %_30.0 to i128
  %_15.i132 = icmp ugt i64 %g8.1, -4294967296
  %_16.i133 = add nsw i64 %g8.1, 4294967295
  %_4.sroa.0.0.i134 = select i1 %_15.i132, i64 %_16.i133, i64 %g8.1
  %_11.i444 = zext i64 %_39.0 to i128
  %_16.i452 = mul nuw i128 %_11.i444, %_14.i475
  %_4.i598 = lshr i128 %_16.i452, 64
  %x_hi.i599 = trunc nuw i128 %_4.i598 to i64
  %x_hi_hi.i600 = lshr i64 %x_hi.i599, 32
  %x_lo.i597 = trunc i128 %_16.i452 to i64
  %_9.1.i603 = icmp ugt i64 %x_hi_hi.i600, %x_lo.i597
  %_9.0.i602 = sub i64 %x_lo.i597, %x_hi_hi.i600
  %_10.i604 = add i64 %_9.0.i602, -4294967295
  %spec.select.i605 = select i1 %_9.1.i603, i64 %_10.i604, i64 %_9.0.i602
  %x_hi_lo.i601 = and i64 %x_hi.i599, 4294967295
  %t1.i606 = mul nuw i64 %x_hi_lo.i601, 4294967295
  %_14.0.i607 = add i64 %spec.select.i605, %t1.i606
  %_14.1.i608 = icmp ult i64 %_14.0.i607, %spec.select.i605
  %73 = add i64 %_14.0.i607, 4294967295
  %res.sroa.0.0.i609 = select i1 %_14.1.i608, i64 %73, i64 %_14.0.i607
  %_16.i610 = icmp ugt i64 %res.sroa.0.0.i609, -4294967296
  %_17.i611 = add nsw i64 %res.sroa.0.0.i609, 4294967295
  %_0.sroa.0.0.i612 = select i1 %_16.i610, i64 %_17.i611, i64 %res.sroa.0.0.i609
  %_14.i448 = zext i64 %_39.1 to i128
  %_17.i454 = mul nuw i128 %_14.i448, %_11.i471
  %_4.i582 = lshr i128 %_17.i454, 64
  %x_hi.i583 = trunc nuw i128 %_4.i582 to i64
  %x_hi_hi.i584 = lshr i64 %x_hi.i583, 32
  %x_lo.i581 = trunc i128 %_17.i454 to i64
  %_9.1.i587 = icmp ugt i64 %x_hi_hi.i584, %x_lo.i581
  %_9.0.i586 = sub i64 %x_lo.i581, %x_hi_hi.i584
  %_10.i588 = add i64 %_9.0.i586, -4294967295
  %spec.select.i589 = select i1 %_9.1.i587, i64 %_10.i588, i64 %_9.0.i586
  %x_hi_lo.i585 = and i64 %x_hi.i583, 4294967295
  %t1.i590 = mul nuw i64 %x_hi_lo.i585, 4294967295
  %_14.0.i591 = add i64 %spec.select.i589, %t1.i590
  %_14.1.i592 = icmp ult i64 %_14.0.i591, %spec.select.i589
  %74 = add i64 %_14.0.i591, 4294967295
  %res.sroa.0.0.i593 = select i1 %_14.1.i592, i64 %74, i64 %_14.0.i591
  %_16.i594 = icmp ugt i64 %res.sroa.0.0.i593, -4294967296
  %_17.i595 = add nsw i64 %res.sroa.0.0.i593, 4294967295
  %_0.sroa.0.0.i596 = select i1 %_16.i594, i64 %_17.i595, i64 %res.sroa.0.0.i593
  %_29.0.i465 = add i64 %_0.sroa.0.0.i596, %_0.sroa.0.0.i612
  %_29.1.i466 = icmp ult i64 %_29.0.i465, %_0.sroa.0.0.i612
  %75 = add nuw i64 %_29.0.i465, 4294967295
  %_30.sroa.0.0.i467 = select i1 %_29.1.i466, i64 %75, i64 %_29.0.i465
  %_31.i468 = icmp ugt i64 %_30.sroa.0.0.i467, -4294967296
  %_32.i469 = add nsw i64 %_30.sroa.0.0.i467, 4294967295
  %_9.sroa.0.0.i470 = select i1 %_31.i468, i64 %_32.i469, i64 %_30.sroa.0.0.i467
  %_13.0.i117 = add i64 %_9.sroa.0.0.i470, %_4.sroa.0.0.i134
  %_13.1.i118 = icmp ult i64 %_13.0.i117, %_4.sroa.0.0.i134
  %76 = add i64 %_13.0.i117, 4294967295
  %_14.sroa.0.0.i119 = select i1 %_13.1.i118, i64 %76, i64 %_13.0.i117
  %_15.i120 = icmp ugt i64 %_14.sroa.0.0.i119, -4294967296
  %_16.i121 = add nsw i64 %_14.sroa.0.0.i119, 4294967295
  %_4.sroa.0.0.i122 = select i1 %_15.i120, i64 %_16.i121, i64 %_14.sroa.0.0.i119
  %_13.0.i105 = add i64 %_4.sroa.0.0.i122, %_40.1
  %_13.1.i106 = icmp ult i64 %_13.0.i105, %_4.sroa.0.0.i122
  %77 = add i64 %_13.0.i105, 4294967295
  %_14.sroa.0.0.i107 = select i1 %_13.1.i106, i64 %77, i64 %_13.0.i105
  %_15.i108 = icmp ugt i64 %_14.sroa.0.0.i107, -4294967296
  %_16.i109 = add nsw i64 %_14.sroa.0.0.i107, 4294967295
  %_4.sroa.0.0.i110 = select i1 %_15.i108, i64 %_16.i109, i64 %_14.sroa.0.0.i107
  %_182.1 = icmp ult i64 %_258, %_4.sroa.0.0.i110
  %_182.0 = sub i64 %_258, %_4.sroa.0.0.i110
  %78 = add i64 %_182.0, -4294967295
  %_183.sroa.0.0 = select i1 %_182.1, i64 %78, i64 %_182.0
  %_15.i422 = zext i64 %_183.sroa.0.0 to i128
  %_16.i425 = mul nuw i128 %_15.i422, %_11.i417
  %_4.i678 = lshr i128 %_16.i425, 64
  %x_hi.i679 = trunc nuw i128 %_4.i678 to i64
  %x_hi_hi.i680 = lshr i64 %x_hi.i679, 32
  %x_lo.i677 = trunc i128 %_16.i425 to i64
  %_9.1.i683 = icmp ugt i64 %x_hi_hi.i680, %x_lo.i677
  %_9.0.i682 = sub i64 %x_lo.i677, %x_hi_hi.i680
  %_10.i684 = add i64 %_9.0.i682, -4294967295
  %spec.select.i685 = select i1 %_9.1.i683, i64 %_10.i684, i64 %_9.0.i682
  %x_hi_lo.i681 = and i64 %x_hi.i679, 4294967295
  %t1.i686 = mul nuw i64 %x_hi_lo.i681, 4294967295
  %_14.0.i687 = add i64 %spec.select.i685, %t1.i686
  %_14.1.i688 = icmp ult i64 %_14.0.i687, %spec.select.i685
  %79 = add i64 %_14.0.i687, 4294967295
  %res.sroa.0.0.i689 = select i1 %_14.1.i688, i64 %79, i64 %_14.0.i687
  %_16.i690 = icmp ugt i64 %res.sroa.0.0.i689, -4294967296
  %_17.i691 = add nsw i64 %res.sroa.0.0.i689, 4294967295
  %_0.sroa.0.0.i692 = select i1 %_16.i690, i64 %_17.i691, i64 %res.sroa.0.0.i689
  %_14.i421 = zext i64 %_30.1 to i128
  %_7.1.i124 = icmp ugt i64 %g8.0, -129
  %_8.sroa.0.0.i125.v = select i1 %_7.1.i124, i64 4294967423, i64 128
  %_8.sroa.0.0.i125 = add i64 %_8.sroa.0.0.i125.v, %g8.0
  %_9.i126 = icmp ugt i64 %_8.sroa.0.0.i125, -4294967296
  %_10.i127 = add nsw i64 %_8.sroa.0.0.i125, 4294967295
  %_3.sroa.0.0.i128 = select i1 %_9.i126, i64 %_10.i127, i64 %_8.sroa.0.0.i125
  %_10.i446 = mul nuw i128 %_11.i444, %_11.i471
  %_4.i630 = lshr i128 %_10.i446, 64
  %x_hi.i631 = trunc nuw i128 %_4.i630 to i64
  %x_hi_hi.i632 = lshr i64 %x_hi.i631, 32
  %x_lo.i629 = trunc i128 %_10.i446 to i64
  %_9.1.i635 = icmp ugt i64 %x_hi_hi.i632, %x_lo.i629
  %_9.0.i634 = sub i64 %x_lo.i629, %x_hi_hi.i632
  %_10.i636 = add i64 %_9.0.i634, -4294967295
  %spec.select.i637 = select i1 %_9.1.i635, i64 %_10.i636, i64 %_9.0.i634
  %x_hi_lo.i633 = and i64 %x_hi.i631, 4294967295
  %t1.i638 = mul nuw i64 %x_hi_lo.i633, 4294967295
  %_14.0.i639 = add i64 %spec.select.i637, %t1.i638
  %_14.1.i640 = icmp ult i64 %_14.0.i639, %spec.select.i637
  %80 = add i64 %_14.0.i639, 4294967295
  %res.sroa.0.0.i641 = select i1 %_14.1.i640, i64 %80, i64 %_14.0.i639
  %_16.i642 = icmp ugt i64 %res.sroa.0.0.i641, -4294967296
  %_17.i643 = add nsw i64 %res.sroa.0.0.i641, 4294967295
  %_0.sroa.0.0.i644 = select i1 %_16.i642, i64 %_17.i643, i64 %res.sroa.0.0.i641
  %_13.i450 = mul nuw i128 %_14.i448, %_14.i475
  %_4.i614 = lshr i128 %_13.i450, 64
  %x_hi.i615 = trunc nuw i128 %_4.i614 to i64
  %x_hi_hi.i616 = lshr i64 %x_hi.i615, 32
  %x_lo.i613 = trunc i128 %_13.i450 to i64
  %_9.1.i619 = icmp ugt i64 %x_hi_hi.i616, %x_lo.i613
  %_9.0.i618 = sub i64 %x_lo.i613, %x_hi_hi.i616
  %_10.i620 = add i64 %_9.0.i618, -4294967295
  %spec.select.i621 = select i1 %_9.1.i619, i64 %_10.i620, i64 %_9.0.i618
  %x_hi_lo.i617 = and i64 %x_hi.i615, 4294967295
  %t1.i622 = mul nuw i64 %x_hi_lo.i617, 4294967295
  %_14.0.i623 = add i64 %spec.select.i621, %t1.i622
  %_14.1.i624 = icmp ult i64 %_14.0.i623, %spec.select.i621
  %81 = add i64 %_14.0.i623, 4294967295
  %res.sroa.0.0.i625 = select i1 %_14.1.i624, i64 %81, i64 %_14.0.i623
  %_16.i626 = icmp ugt i64 %res.sroa.0.0.i625, -4294967296
  %_17.i627 = add nsw i64 %res.sroa.0.0.i625, 4294967295
  %_0.sroa.0.0.i628 = select i1 %_16.i626, i64 %_17.i627, i64 %res.sroa.0.0.i625
  %_19.i456 = zext i64 %_0.sroa.0.0.i628 to i128
  %_18.i457 = mul nuw nsw i128 %_19.i456, 7
  %_4.i566 = lshr i128 %_18.i457, 64
  %x_hi.i567 = trunc nuw nsw i128 %_4.i566 to i64
  %t1.i574 = mul nuw nsw i64 %x_hi.i567, 4294967295
  %x_lo.i565 = trunc i128 %_18.i457 to i64
  %_14.0.i575 = add i64 %t1.i574, %x_lo.i565
  %_14.1.i576 = icmp ult i64 %_14.0.i575, %x_lo.i565
  %82 = add i64 %_14.0.i575, 4294967295
  %res.sroa.0.0.i577 = select i1 %_14.1.i576, i64 %82, i64 %_14.0.i575
  %_16.i578 = icmp ugt i64 %res.sroa.0.0.i577, -4294967296
  %_17.i579 = add nsw i64 %res.sroa.0.0.i577, 4294967295
  %_0.sroa.0.0.i580 = select i1 %_16.i578, i64 %_17.i579, i64 %res.sroa.0.0.i577
  %_22.0.i459 = add i64 %_0.sroa.0.0.i580, %_0.sroa.0.0.i644
  %_22.1.i460 = icmp ult i64 %_22.0.i459, %_0.sroa.0.0.i644
  %83 = add nuw i64 %_22.0.i459, 4294967295
  %_24.sroa.0.0.i461 = select i1 %_22.1.i460, i64 %83, i64 %_22.0.i459
  %_25.i462 = icmp ugt i64 %_24.sroa.0.0.i461, -4294967296
  %_26.i463 = add nsw i64 %_24.sroa.0.0.i461, 4294967295
  %_7.sroa.0.0.i464 = select i1 %_25.i462, i64 %_26.i463, i64 %_24.sroa.0.0.i461
  %_7.0.i111 = add i64 %_7.sroa.0.0.i464, %_3.sroa.0.0.i128
  %_7.1.i112 = icmp ult i64 %_7.0.i111, %_3.sroa.0.0.i128
  %84 = add i64 %_7.0.i111, 4294967295
  %_8.sroa.0.0.i113 = select i1 %_7.1.i112, i64 %84, i64 %_7.0.i111
  %_9.i114 = icmp ugt i64 %_8.sroa.0.0.i113, -4294967296
  %_10.i115 = add nsw i64 %_8.sroa.0.0.i113, 4294967295
  %_3.sroa.0.0.i116 = select i1 %_9.i114, i64 %_10.i115, i64 %_8.sroa.0.0.i113
  %_7.0.i99 = add i64 %_3.sroa.0.0.i116, %_40.0
  %_7.1.i100 = icmp ult i64 %_7.0.i99, %_3.sroa.0.0.i116
  %85 = add i64 %_7.0.i99, 4294967295
  %_8.sroa.0.0.i101 = select i1 %_7.1.i100, i64 %85, i64 %_7.0.i99
  %_9.i102 = icmp ugt i64 %_8.sroa.0.0.i101, -4294967296
  %_10.i103 = add nsw i64 %_8.sroa.0.0.i101, 4294967295
  %_3.sroa.0.0.i104 = select i1 %_9.i102, i64 %_10.i103, i64 %_8.sroa.0.0.i101
  %_178.1 = icmp ult i64 %_257, %_3.sroa.0.0.i104
  %_178.0 = sub i64 %_257, %_3.sroa.0.0.i104
  %86 = add i64 %_178.0, -4294967295
  %_179.sroa.0.0 = select i1 %_178.1, i64 %86, i64 %_178.0
  %_12.i418 = zext i64 %_179.sroa.0.0 to i128
  %_17.i427 = mul nuw i128 %_12.i418, %_14.i421
  %_4.i662 = lshr i128 %_17.i427, 64
  %x_hi.i663 = trunc nuw i128 %_4.i662 to i64
  %x_hi_hi.i664 = lshr i64 %x_hi.i663, 32
  %x_lo.i661 = trunc i128 %_17.i427 to i64
  %_9.1.i667 = icmp ugt i64 %x_hi_hi.i664, %x_lo.i661
  %_9.0.i666 = sub i64 %x_lo.i661, %x_hi_hi.i664
  %_10.i668 = add i64 %_9.0.i666, -4294967295
  %spec.select.i669 = select i1 %_9.1.i667, i64 %_10.i668, i64 %_9.0.i666
  %x_hi_lo.i665 = and i64 %x_hi.i663, 4294967295
  %t1.i670 = mul nuw i64 %x_hi_lo.i665, 4294967295
  %_14.0.i671 = add i64 %spec.select.i669, %t1.i670
  %_14.1.i672 = icmp ult i64 %_14.0.i671, %spec.select.i669
  %87 = add i64 %_14.0.i671, 4294967295
  %res.sroa.0.0.i673 = select i1 %_14.1.i672, i64 %87, i64 %_14.0.i671
  %_16.i674 = icmp ugt i64 %res.sroa.0.0.i673, -4294967296
  %_17.i675 = add nsw i64 %res.sroa.0.0.i673, 4294967295
  %_0.sroa.0.0.i676 = select i1 %_16.i674, i64 %_17.i675, i64 %res.sroa.0.0.i673
  %_29.0.i438 = add i64 %_0.sroa.0.0.i676, %_0.sroa.0.0.i692
  %_29.1.i439 = icmp ult i64 %_29.0.i438, %_0.sroa.0.0.i692
  %88 = add nuw i64 %_29.0.i438, 4294967295
  %_30.sroa.0.0.i440 = select i1 %_29.1.i439, i64 %88, i64 %_29.0.i438
  %_31.i441 = icmp ugt i64 %_30.sroa.0.0.i440, -4294967296
  %_32.i442 = add nsw i64 %_30.sroa.0.0.i440, 4294967295
  %_9.sroa.0.0.i443 = select i1 %_31.i441, i64 %_32.i442, i64 %_30.sroa.0.0.i440
  %_15.i395 = zext i64 %_9.sroa.0.0.i443 to i128
  %_16.i398 = mul nuw i128 %_11.i390, %_15.i395
  %_4.i758 = lshr i128 %_16.i398, 64
  %x_hi.i759 = trunc nuw i128 %_4.i758 to i64
  %x_hi_hi.i760 = lshr i64 %x_hi.i759, 32
  %x_lo.i757 = trunc i128 %_16.i398 to i64
  %_9.1.i763 = icmp ugt i64 %x_hi_hi.i760, %x_lo.i757
  %_9.0.i762 = sub i64 %x_lo.i757, %x_hi_hi.i760
  %_10.i764 = add i64 %_9.0.i762, -4294967295
  %spec.select.i765 = select i1 %_9.1.i763, i64 %_10.i764, i64 %_9.0.i762
  %x_hi_lo.i761 = and i64 %x_hi.i759, 4294967295
  %t1.i766 = mul nuw i64 %x_hi_lo.i761, 4294967295
  %_14.0.i767 = add i64 %spec.select.i765, %t1.i766
  %_14.1.i768 = icmp ult i64 %_14.0.i767, %spec.select.i765
  %89 = add i64 %_14.0.i767, 4294967295
  %res.sroa.0.0.i769 = select i1 %_14.1.i768, i64 %89, i64 %_14.0.i767
  %_16.i770 = icmp ugt i64 %res.sroa.0.0.i769, -4294967296
  %_17.i771 = add nsw i64 %res.sroa.0.0.i769, 4294967295
  %_0.sroa.0.0.i772 = select i1 %_16.i770, i64 %_17.i771, i64 %res.sroa.0.0.i769
  %_14.i394 = zext i64 %_50.1 to i128
  %_10.i419 = mul nuw i128 %_12.i418, %_11.i417
  %_4.i710 = lshr i128 %_10.i419, 64
  %x_hi.i711 = trunc nuw i128 %_4.i710 to i64
  %x_hi_hi.i712 = lshr i64 %x_hi.i711, 32
  %x_lo.i709 = trunc i128 %_10.i419 to i64
  %_9.1.i715 = icmp ugt i64 %x_hi_hi.i712, %x_lo.i709
  %_9.0.i714 = sub i64 %x_lo.i709, %x_hi_hi.i712
  %_10.i716 = add i64 %_9.0.i714, -4294967295
  %spec.select.i717 = select i1 %_9.1.i715, i64 %_10.i716, i64 %_9.0.i714
  %x_hi_lo.i713 = and i64 %x_hi.i711, 4294967295
  %t1.i718 = mul nuw i64 %x_hi_lo.i713, 4294967295
  %_14.0.i719 = add i64 %spec.select.i717, %t1.i718
  %_14.1.i720 = icmp ult i64 %_14.0.i719, %spec.select.i717
  %90 = add i64 %_14.0.i719, 4294967295
  %res.sroa.0.0.i721 = select i1 %_14.1.i720, i64 %90, i64 %_14.0.i719
  %_16.i722 = icmp ugt i64 %res.sroa.0.0.i721, -4294967296
  %_17.i723 = add nsw i64 %res.sroa.0.0.i721, 4294967295
  %_0.sroa.0.0.i724 = select i1 %_16.i722, i64 %_17.i723, i64 %res.sroa.0.0.i721
  %_13.i423 = mul nuw i128 %_15.i422, %_14.i421
  %_4.i694 = lshr i128 %_13.i423, 64
  %x_hi.i695 = trunc nuw i128 %_4.i694 to i64
  %x_hi_hi.i696 = lshr i64 %x_hi.i695, 32
  %x_lo.i693 = trunc i128 %_13.i423 to i64
  %_9.1.i699 = icmp ugt i64 %x_hi_hi.i696, %x_lo.i693
  %_9.0.i698 = sub i64 %x_lo.i693, %x_hi_hi.i696
  %_10.i700 = add i64 %_9.0.i698, -4294967295
  %spec.select.i701 = select i1 %_9.1.i699, i64 %_10.i700, i64 %_9.0.i698
  %x_hi_lo.i697 = and i64 %x_hi.i695, 4294967295
  %t1.i702 = mul nuw i64 %x_hi_lo.i697, 4294967295
  %_14.0.i703 = add i64 %spec.select.i701, %t1.i702
  %_14.1.i704 = icmp ult i64 %_14.0.i703, %spec.select.i701
  %91 = add i64 %_14.0.i703, 4294967295
  %res.sroa.0.0.i705 = select i1 %_14.1.i704, i64 %91, i64 %_14.0.i703
  %_16.i706 = icmp ugt i64 %res.sroa.0.0.i705, -4294967296
  %_17.i707 = add nsw i64 %res.sroa.0.0.i705, 4294967295
  %_0.sroa.0.0.i708 = select i1 %_16.i706, i64 %_17.i707, i64 %res.sroa.0.0.i705
  %_19.i429 = zext i64 %_0.sroa.0.0.i708 to i128
  %_18.i430 = mul nuw nsw i128 %_19.i429, 7
  %_4.i646 = lshr i128 %_18.i430, 64
  %x_hi.i647 = trunc nuw nsw i128 %_4.i646 to i64
  %t1.i654 = mul nuw nsw i64 %x_hi.i647, 4294967295
  %x_lo.i645 = trunc i128 %_18.i430 to i64
  %_14.0.i655 = add i64 %t1.i654, %x_lo.i645
  %_14.1.i656 = icmp ult i64 %_14.0.i655, %x_lo.i645
  %92 = add i64 %_14.0.i655, 4294967295
  %res.sroa.0.0.i657 = select i1 %_14.1.i656, i64 %92, i64 %_14.0.i655
  %_16.i658 = icmp ugt i64 %res.sroa.0.0.i657, -4294967296
  %_17.i659 = add nsw i64 %res.sroa.0.0.i657, 4294967295
  %_0.sroa.0.0.i660 = select i1 %_16.i658, i64 %_17.i659, i64 %res.sroa.0.0.i657
  %_22.0.i432 = add i64 %_0.sroa.0.0.i724, %_0.sroa.0.0.i660
  %_22.1.i433 = icmp ult i64 %_22.0.i432, %_0.sroa.0.0.i724
  %93 = add nuw i64 %_22.0.i432, 4294967295
  %_24.sroa.0.0.i434 = select i1 %_22.1.i433, i64 %93, i64 %_22.0.i432
  %_25.i435 = icmp ugt i64 %_24.sroa.0.0.i434, -4294967296
  %_26.i436 = add nsw i64 %_24.sroa.0.0.i434, 4294967295
  %_7.sroa.0.0.i437 = select i1 %_25.i435, i64 %_26.i436, i64 %_24.sroa.0.0.i434
  %_190.1 = icmp eq i64 %_7.sroa.0.0.i437, 0
  %_190.0 = add i64 %_7.sroa.0.0.i437, -1
  %_191.sroa.0.0 = select i1 %_190.1, i64 -4294967296, i64 %_190.0
  %_12.i391 = zext i64 %_191.sroa.0.0 to i128
  %_17.i400 = mul nuw i128 %_14.i394, %_12.i391
  %_4.i742 = lshr i128 %_17.i400, 64
  %x_hi.i743 = trunc nuw i128 %_4.i742 to i64
  %x_hi_hi.i744 = lshr i64 %x_hi.i743, 32
  %x_lo.i741 = trunc i128 %_17.i400 to i64
  %_9.1.i747 = icmp ugt i64 %x_hi_hi.i744, %x_lo.i741
  %_9.0.i746 = sub i64 %x_lo.i741, %x_hi_hi.i744
  %_10.i748 = add i64 %_9.0.i746, -4294967295
  %spec.select.i749 = select i1 %_9.1.i747, i64 %_10.i748, i64 %_9.0.i746
  %x_hi_lo.i745 = and i64 %x_hi.i743, 4294967295
  %t1.i750 = mul nuw i64 %x_hi_lo.i745, 4294967295
  %_14.0.i751 = add i64 %spec.select.i749, %t1.i750
  %_14.1.i752 = icmp ult i64 %_14.0.i751, %spec.select.i749
  %94 = add i64 %_14.0.i751, 4294967295
  %res.sroa.0.0.i753 = select i1 %_14.1.i752, i64 %94, i64 %_14.0.i751
  %_16.i754 = icmp ugt i64 %res.sroa.0.0.i753, -4294967296
  %_17.i755 = add nsw i64 %res.sroa.0.0.i753, 4294967295
  %_0.sroa.0.0.i756 = select i1 %_16.i754, i64 %_17.i755, i64 %res.sroa.0.0.i753
  %_29.0.i411 = add i64 %_0.sroa.0.0.i756, %_0.sroa.0.0.i772
  %_29.1.i412 = icmp ult i64 %_29.0.i411, %_0.sroa.0.0.i772
  %95 = add nuw i64 %_29.0.i411, 4294967295
  %_30.sroa.0.0.i413 = select i1 %_29.1.i412, i64 %95, i64 %_29.0.i411
  %_31.i414 = icmp ugt i64 %_30.sroa.0.0.i413, -4294967296
  %_32.i415 = add nsw i64 %_30.sroa.0.0.i413, 4294967295
  %_9.sroa.0.0.i416 = select i1 %_31.i414, i64 %_32.i415, i64 %_30.sroa.0.0.i413
  %_13.0.i93 = add i64 %_9.sroa.0.0.i416, %_44.1
  %_13.1.i94 = icmp ult i64 %_13.0.i93, %_44.1
  %96 = add i64 %_13.0.i93, 4294967295
  %_14.sroa.0.0.i95 = select i1 %_13.1.i94, i64 %96, i64 %_13.0.i93
  %_15.i96 = icmp ugt i64 %_14.sroa.0.0.i95, -4294967296
  %_16.i97 = add nsw i64 %_14.sroa.0.0.i95, 4294967295
  %_4.sroa.0.0.i98 = select i1 %_15.i96, i64 %_16.i97, i64 %_14.sroa.0.0.i95
  %_52.1 = extractvalue { i64, i64 } %61, 1
  %_13.0.i81 = add i64 %_4.sroa.0.0.i98, %_52.1
  %_13.1.i82 = icmp ult i64 %_13.0.i81, %_4.sroa.0.0.i98
  %97 = add i64 %_13.0.i81, 4294967295
  %_14.sroa.0.0.i83 = select i1 %_13.1.i82, i64 %97, i64 %_13.0.i81
  %_15.i84 = icmp ugt i64 %_14.sroa.0.0.i83, -4294967296
  %_16.i85 = add nsw i64 %_14.sroa.0.0.i83, 4294967295
  %_4.sroa.0.0.i86 = select i1 %_15.i84, i64 %_16.i85, i64 %_14.sroa.0.0.i83
  %_11.i363 = zext i64 %g.sroa.0.0 to i128
  %_15.i368 = zext i64 %clauses.sroa.4.0.lcssa.ph to i128
  %_16.i371 = mul nuw i128 %_15.i368, %_11.i363
  %_4.i838 = lshr i128 %_16.i371, 64
  %x_hi.i839 = trunc nuw i128 %_4.i838 to i64
  %x_hi_hi.i840 = lshr i64 %x_hi.i839, 32
  %x_lo.i837 = trunc i128 %_16.i371 to i64
  %_9.1.i843 = icmp ugt i64 %x_hi_hi.i840, %x_lo.i837
  %_9.0.i842 = sub i64 %x_lo.i837, %x_hi_hi.i840
  %_10.i844 = add i64 %_9.0.i842, -4294967295
  %spec.select.i845 = select i1 %_9.1.i843, i64 %_10.i844, i64 %_9.0.i842
  %x_hi_lo.i841 = and i64 %x_hi.i839, 4294967295
  %t1.i846 = mul nuw i64 %x_hi_lo.i841, 4294967295
  %_14.0.i847 = add i64 %spec.select.i845, %t1.i846
  %_14.1.i848 = icmp ult i64 %_14.0.i847, %spec.select.i845
  %98 = add i64 %_14.0.i847, 4294967295
  %res.sroa.0.0.i849 = select i1 %_14.1.i848, i64 %98, i64 %_14.0.i847
  %_16.i850 = icmp ugt i64 %res.sroa.0.0.i849, -4294967296
  %_17.i851 = add nsw i64 %res.sroa.0.0.i849, 4294967295
  %_0.sroa.0.0.i852 = select i1 %_16.i850, i64 %_17.i851, i64 %res.sroa.0.0.i849
  %_14.i367 = zext i64 %g.sroa.5.0 to i128
  %_12.i364 = zext i64 %clauses.sroa.0.0.lcssa.ph to i128
  %_17.i373 = mul nuw i128 %_12.i364, %_14.i367
  %_4.i822 = lshr i128 %_17.i373, 64
  %x_hi.i823 = trunc nuw i128 %_4.i822 to i64
  %x_hi_hi.i824 = lshr i64 %x_hi.i823, 32
  %x_lo.i821 = trunc i128 %_17.i373 to i64
  %_9.1.i827 = icmp ugt i64 %x_hi_hi.i824, %x_lo.i821
  %_9.0.i826 = sub i64 %x_lo.i821, %x_hi_hi.i824
  %_10.i828 = add i64 %_9.0.i826, -4294967295
  %spec.select.i829 = select i1 %_9.1.i827, i64 %_10.i828, i64 %_9.0.i826
  %x_hi_lo.i825 = and i64 %x_hi.i823, 4294967295
  %t1.i830 = mul nuw i64 %x_hi_lo.i825, 4294967295
  %_14.0.i831 = add i64 %spec.select.i829, %t1.i830
  %_14.1.i832 = icmp ult i64 %_14.0.i831, %spec.select.i829
  %99 = add i64 %_14.0.i831, 4294967295
  %res.sroa.0.0.i833 = select i1 %_14.1.i832, i64 %99, i64 %_14.0.i831
  %_16.i834 = icmp ugt i64 %res.sroa.0.0.i833, -4294967296
  %_17.i835 = add nsw i64 %res.sroa.0.0.i833, 4294967295
  %_0.sroa.0.0.i836 = select i1 %_16.i834, i64 %_17.i835, i64 %res.sroa.0.0.i833
  %_29.0.i384 = add i64 %_0.sroa.0.0.i836, %_0.sroa.0.0.i852
  %_29.1.i385 = icmp ult i64 %_29.0.i384, %_0.sroa.0.0.i852
  %100 = add nuw i64 %_29.0.i384, 4294967295
  %_30.sroa.0.0.i386 = select i1 %_29.1.i385, i64 %100, i64 %_29.0.i384
  %_31.i387 = icmp ugt i64 %_30.sroa.0.0.i386, -4294967296
  %_32.i388 = add nsw i64 %_30.sroa.0.0.i386, 4294967295
  %_9.sroa.0.0.i389 = select i1 %_31.i387, i64 %_32.i388, i64 %_30.sroa.0.0.i386
  %_13.0.i69 = add i64 %_9.sroa.0.0.i389, %_4.sroa.0.0.i86
  %_13.1.i70 = icmp ult i64 %_13.0.i69, %_4.sroa.0.0.i86
  %101 = add i64 %_13.0.i69, 4294967295
  %_14.sroa.0.0.i71 = select i1 %_13.1.i70, i64 %101, i64 %_13.0.i69
  %_15.i72 = icmp ugt i64 %_14.sroa.0.0.i71, -4294967296
  %_16.i73 = add nsw i64 %_14.sroa.0.0.i71, 4294967295
  %_4.sroa.0.0.i74 = select i1 %_15.i72, i64 %_16.i73, i64 %_14.sroa.0.0.i71
  %_15.i341 = zext i64 %_4.sroa.0.0.i74 to i128
  %_16.i344 = mul nuw i128 %_11.i336, %_15.i341
  %_4.i918 = lshr i128 %_16.i344, 64
  %x_hi.i919 = trunc nuw i128 %_4.i918 to i64
  %x_hi_hi.i920 = lshr i64 %x_hi.i919, 32
  %x_lo.i917 = trunc i128 %_16.i344 to i64
  %_9.1.i923 = icmp ugt i64 %x_hi_hi.i920, %x_lo.i917
  %_9.0.i922 = sub i64 %x_lo.i917, %x_hi_hi.i920
  %_10.i924 = add i64 %_9.0.i922, -4294967295
  %spec.select.i925 = select i1 %_9.1.i923, i64 %_10.i924, i64 %_9.0.i922
  %x_hi_lo.i921 = and i64 %x_hi.i919, 4294967295
  %t1.i926 = mul nuw i64 %x_hi_lo.i921, 4294967295
  %_14.0.i927 = add i64 %spec.select.i925, %t1.i926
  %_14.1.i928 = icmp ult i64 %_14.0.i927, %spec.select.i925
  %102 = add i64 %_14.0.i927, 4294967295
  %res.sroa.0.0.i929 = select i1 %_14.1.i928, i64 %102, i64 %_14.0.i927
  %_16.i930 = icmp ugt i64 %res.sroa.0.0.i929, -4294967296
  %_17.i931 = add nsw i64 %res.sroa.0.0.i929, 4294967295
  %_0.sroa.0.0.i932 = select i1 %_16.i930, i64 %_17.i931, i64 %res.sroa.0.0.i929
  %_14.i340 = zext i64 %_76.1 to i128
  %_44.0 = extractvalue { i64, i64 } %59, 0
  %_10.i392 = mul nuw i128 %_11.i390, %_12.i391
  %_4.i790 = lshr i128 %_10.i392, 64
  %x_hi.i791 = trunc nuw i128 %_4.i790 to i64
  %x_hi_hi.i792 = lshr i64 %x_hi.i791, 32
  %x_lo.i789 = trunc i128 %_10.i392 to i64
  %_9.1.i795 = icmp ugt i64 %x_hi_hi.i792, %x_lo.i789
  %_9.0.i794 = sub i64 %x_lo.i789, %x_hi_hi.i792
  %_10.i796 = add i64 %_9.0.i794, -4294967295
  %spec.select.i797 = select i1 %_9.1.i795, i64 %_10.i796, i64 %_9.0.i794
  %x_hi_lo.i793 = and i64 %x_hi.i791, 4294967295
  %t1.i798 = mul nuw i64 %x_hi_lo.i793, 4294967295
  %_14.0.i799 = add i64 %spec.select.i797, %t1.i798
  %_14.1.i800 = icmp ult i64 %_14.0.i799, %spec.select.i797
  %103 = add i64 %_14.0.i799, 4294967295
  %res.sroa.0.0.i801 = select i1 %_14.1.i800, i64 %103, i64 %_14.0.i799
  %_16.i802 = icmp ugt i64 %res.sroa.0.0.i801, -4294967296
  %_17.i803 = add nsw i64 %res.sroa.0.0.i801, 4294967295
  %_0.sroa.0.0.i804 = select i1 %_16.i802, i64 %_17.i803, i64 %res.sroa.0.0.i801
  %_13.i396 = mul nuw i128 %_14.i394, %_15.i395
  %_4.i774 = lshr i128 %_13.i396, 64
  %x_hi.i775 = trunc nuw i128 %_4.i774 to i64
  %x_hi_hi.i776 = lshr i64 %x_hi.i775, 32
  %x_lo.i773 = trunc i128 %_13.i396 to i64
  %_9.1.i779 = icmp ugt i64 %x_hi_hi.i776, %x_lo.i773
  %_9.0.i778 = sub i64 %x_lo.i773, %x_hi_hi.i776
  %_10.i780 = add i64 %_9.0.i778, -4294967295
  %spec.select.i781 = select i1 %_9.1.i779, i64 %_10.i780, i64 %_9.0.i778
  %x_hi_lo.i777 = and i64 %x_hi.i775, 4294967295
  %t1.i782 = mul nuw i64 %x_hi_lo.i777, 4294967295
  %_14.0.i783 = add i64 %spec.select.i781, %t1.i782
  %_14.1.i784 = icmp ult i64 %_14.0.i783, %spec.select.i781
  %104 = add i64 %_14.0.i783, 4294967295
  %res.sroa.0.0.i785 = select i1 %_14.1.i784, i64 %104, i64 %_14.0.i783
  %_16.i786 = icmp ugt i64 %res.sroa.0.0.i785, -4294967296
  %_17.i787 = add nsw i64 %res.sroa.0.0.i785, 4294967295
  %_0.sroa.0.0.i788 = select i1 %_16.i786, i64 %_17.i787, i64 %res.sroa.0.0.i785
  %_19.i402 = zext i64 %_0.sroa.0.0.i788 to i128
  %_18.i403 = mul nuw nsw i128 %_19.i402, 7
  %_4.i726 = lshr i128 %_18.i403, 64
  %x_hi.i727 = trunc nuw nsw i128 %_4.i726 to i64
  %t1.i734 = mul nuw nsw i64 %x_hi.i727, 4294967295
  %x_lo.i725 = trunc i128 %_18.i403 to i64
  %_14.0.i735 = add i64 %t1.i734, %x_lo.i725
  %_14.1.i736 = icmp ult i64 %_14.0.i735, %x_lo.i725
  %105 = add i64 %_14.0.i735, 4294967295
  %res.sroa.0.0.i737 = select i1 %_14.1.i736, i64 %105, i64 %_14.0.i735
  %_16.i738 = icmp ugt i64 %res.sroa.0.0.i737, -4294967296
  %_17.i739 = add nsw i64 %res.sroa.0.0.i737, 4294967295
  %_0.sroa.0.0.i740 = select i1 %_16.i738, i64 %_17.i739, i64 %res.sroa.0.0.i737
  %_22.0.i405 = add i64 %_0.sroa.0.0.i740, %_0.sroa.0.0.i804
  %_22.1.i406 = icmp ult i64 %_22.0.i405, %_0.sroa.0.0.i804
  %106 = add nuw i64 %_22.0.i405, 4294967295
  %_24.sroa.0.0.i407 = select i1 %_22.1.i406, i64 %106, i64 %_22.0.i405
  %_25.i408 = icmp ugt i64 %_24.sroa.0.0.i407, -4294967296
  %_26.i409 = add nsw i64 %_24.sroa.0.0.i407, 4294967295
  %_7.sroa.0.0.i410 = select i1 %_25.i408, i64 %_26.i409, i64 %_24.sroa.0.0.i407
  %_7.0.i87 = add i64 %_7.sroa.0.0.i410, %_44.0
  %_7.1.i88 = icmp ult i64 %_7.0.i87, %_44.0
  %107 = add i64 %_7.0.i87, 4294967295
  %_8.sroa.0.0.i89 = select i1 %_7.1.i88, i64 %107, i64 %_7.0.i87
  %_9.i90 = icmp ugt i64 %_8.sroa.0.0.i89, -4294967296
  %_10.i91 = add nsw i64 %_8.sroa.0.0.i89, 4294967295
  %_3.sroa.0.0.i92 = select i1 %_9.i90, i64 %_10.i91, i64 %_8.sroa.0.0.i89
  %_52.0 = extractvalue { i64, i64 } %61, 0
  %_7.0.i75 = add i64 %_3.sroa.0.0.i92, %_52.0
  %_7.1.i76 = icmp ult i64 %_7.0.i75, %_3.sroa.0.0.i92
  %108 = add i64 %_7.0.i75, 4294967295
  %_8.sroa.0.0.i77 = select i1 %_7.1.i76, i64 %108, i64 %_7.0.i75
  %_9.i78 = icmp ugt i64 %_8.sroa.0.0.i77, -4294967296
  %_10.i79 = add nsw i64 %_8.sroa.0.0.i77, 4294967295
  %_3.sroa.0.0.i80 = select i1 %_9.i78, i64 %_10.i79, i64 %_8.sroa.0.0.i77
  %_10.i365 = mul nuw i128 %_12.i364, %_11.i363
  %_4.i870 = lshr i128 %_10.i365, 64
  %x_hi.i871 = trunc nuw i128 %_4.i870 to i64
  %x_hi_hi.i872 = lshr i64 %x_hi.i871, 32
  %x_lo.i869 = trunc i128 %_10.i365 to i64
  %_9.1.i875 = icmp ugt i64 %x_hi_hi.i872, %x_lo.i869
  %_9.0.i874 = sub i64 %x_lo.i869, %x_hi_hi.i872
  %_10.i876 = add i64 %_9.0.i874, -4294967295
  %spec.select.i877 = select i1 %_9.1.i875, i64 %_10.i876, i64 %_9.0.i874
  %x_hi_lo.i873 = and i64 %x_hi.i871, 4294967295
  %t1.i878 = mul nuw i64 %x_hi_lo.i873, 4294967295
  %_14.0.i879 = add i64 %spec.select.i877, %t1.i878
  %_14.1.i880 = icmp ult i64 %_14.0.i879, %spec.select.i877
  %109 = add i64 %_14.0.i879, 4294967295
  %res.sroa.0.0.i881 = select i1 %_14.1.i880, i64 %109, i64 %_14.0.i879
  %_16.i882 = icmp ugt i64 %res.sroa.0.0.i881, -4294967296
  %_17.i883 = add nsw i64 %res.sroa.0.0.i881, 4294967295
  %_0.sroa.0.0.i884 = select i1 %_16.i882, i64 %_17.i883, i64 %res.sroa.0.0.i881
  %_13.i369 = mul nuw i128 %_15.i368, %_14.i367
  %_4.i854 = lshr i128 %_13.i369, 64
  %x_hi.i855 = trunc nuw i128 %_4.i854 to i64
  %x_hi_hi.i856 = lshr i64 %x_hi.i855, 32
  %x_lo.i853 = trunc i128 %_13.i369 to i64
  %_9.1.i859 = icmp ugt i64 %x_hi_hi.i856, %x_lo.i853
  %_9.0.i858 = sub i64 %x_lo.i853, %x_hi_hi.i856
  %_10.i860 = add i64 %_9.0.i858, -4294967295
  %spec.select.i861 = select i1 %_9.1.i859, i64 %_10.i860, i64 %_9.0.i858
  %x_hi_lo.i857 = and i64 %x_hi.i855, 4294967295
  %t1.i862 = mul nuw i64 %x_hi_lo.i857, 4294967295
  %_14.0.i863 = add i64 %spec.select.i861, %t1.i862
  %_14.1.i864 = icmp ult i64 %_14.0.i863, %spec.select.i861
  %110 = add i64 %_14.0.i863, 4294967295
  %res.sroa.0.0.i865 = select i1 %_14.1.i864, i64 %110, i64 %_14.0.i863
  %_16.i866 = icmp ugt i64 %res.sroa.0.0.i865, -4294967296
  %_17.i867 = add nsw i64 %res.sroa.0.0.i865, 4294967295
  %_0.sroa.0.0.i868 = select i1 %_16.i866, i64 %_17.i867, i64 %res.sroa.0.0.i865
  %_19.i375 = zext i64 %_0.sroa.0.0.i868 to i128
  %_18.i376 = mul nuw nsw i128 %_19.i375, 7
  %_4.i806 = lshr i128 %_18.i376, 64
  %x_hi.i807 = trunc nuw nsw i128 %_4.i806 to i64
  %t1.i814 = mul nuw nsw i64 %x_hi.i807, 4294967295
  %x_lo.i805 = trunc i128 %_18.i376 to i64
  %_14.0.i815 = add i64 %t1.i814, %x_lo.i805
  %_14.1.i816 = icmp ult i64 %_14.0.i815, %x_lo.i805
  %111 = add i64 %_14.0.i815, 4294967295
  %res.sroa.0.0.i817 = select i1 %_14.1.i816, i64 %111, i64 %_14.0.i815
  %_16.i818 = icmp ugt i64 %res.sroa.0.0.i817, -4294967296
  %_17.i819 = add nsw i64 %res.sroa.0.0.i817, 4294967295
  %_0.sroa.0.0.i820 = select i1 %_16.i818, i64 %_17.i819, i64 %res.sroa.0.0.i817
  %_22.0.i378 = add i64 %_0.sroa.0.0.i820, %_0.sroa.0.0.i884
  %_22.1.i379 = icmp ult i64 %_22.0.i378, %_0.sroa.0.0.i884
  %112 = add nuw i64 %_22.0.i378, 4294967295
  %_24.sroa.0.0.i380 = select i1 %_22.1.i379, i64 %112, i64 %_22.0.i378
  %_25.i381 = icmp ugt i64 %_24.sroa.0.0.i380, -4294967296
  %_26.i382 = add nsw i64 %_24.sroa.0.0.i380, 4294967295
  %_7.sroa.0.0.i383 = select i1 %_25.i381, i64 %_26.i382, i64 %_24.sroa.0.0.i380
  %_7.0.i63 = add i64 %_7.sroa.0.0.i383, %_3.sroa.0.0.i80
  %_7.1.i64 = icmp ult i64 %_7.0.i63, %_3.sroa.0.0.i80
  %113 = add i64 %_7.0.i63, 4294967295
  %_8.sroa.0.0.i65 = select i1 %_7.1.i64, i64 %113, i64 %_7.0.i63
  %_9.i66 = icmp ugt i64 %_8.sroa.0.0.i65, -4294967296
  %_10.i67 = add nsw i64 %_8.sroa.0.0.i65, 4294967295
  %_3.sroa.0.0.i68 = select i1 %_9.i66, i64 %_10.i67, i64 %_8.sroa.0.0.i65
  %_12.i337 = zext i64 %_3.sroa.0.0.i68 to i128
  %_17.i346 = mul nuw i128 %_14.i340, %_12.i337
  %_4.i902 = lshr i128 %_17.i346, 64
  %x_hi.i903 = trunc nuw i128 %_4.i902 to i64
  %x_hi_hi.i904 = lshr i64 %x_hi.i903, 32
  %x_lo.i901 = trunc i128 %_17.i346 to i64
  %_9.1.i907 = icmp ugt i64 %x_hi_hi.i904, %x_lo.i901
  %_9.0.i906 = sub i64 %x_lo.i901, %x_hi_hi.i904
  %_10.i908 = add i64 %_9.0.i906, -4294967295
  %spec.select.i909 = select i1 %_9.1.i907, i64 %_10.i908, i64 %_9.0.i906
  %x_hi_lo.i905 = and i64 %x_hi.i903, 4294967295
  %t1.i910 = mul nuw i64 %x_hi_lo.i905, 4294967295
  %_14.0.i911 = add i64 %spec.select.i909, %t1.i910
  %_14.1.i912 = icmp ult i64 %_14.0.i911, %spec.select.i909
  %114 = add i64 %_14.0.i911, 4294967295
  %res.sroa.0.0.i913 = select i1 %_14.1.i912, i64 %114, i64 %_14.0.i911
  %_16.i914 = icmp ugt i64 %res.sroa.0.0.i913, -4294967296
  %_17.i915 = add nsw i64 %res.sroa.0.0.i913, 4294967295
  %_0.sroa.0.0.i916 = select i1 %_16.i914, i64 %_17.i915, i64 %res.sroa.0.0.i913
  %_29.0.i357 = add i64 %_0.sroa.0.0.i916, %_0.sroa.0.0.i932
  %_29.1.i358 = icmp ult i64 %_29.0.i357, %_0.sroa.0.0.i932
  %115 = add nuw i64 %_29.0.i357, 4294967295
  %_30.sroa.0.0.i359 = select i1 %_29.1.i358, i64 %115, i64 %_29.0.i357
  %_31.i360 = icmp ugt i64 %_30.sroa.0.0.i359, -4294967296
  %_32.i361 = add nsw i64 %_30.sroa.0.0.i359, 4294967295
  %_9.sroa.0.0.i362 = select i1 %_31.i360, i64 %_32.i361, i64 %_30.sroa.0.0.i359
  %_11.i309 = zext i64 %_81.0 to i128
  %_12.i310 = zext i64 %_83.0 to i128
  %_10.i311 = mul nuw i128 %_12.i310, %_11.i309
  %_4.i1030 = lshr i128 %_10.i311, 64
  %x_hi.i1031 = trunc nuw i128 %_4.i1030 to i64
  %x_hi_hi.i1032 = lshr i64 %x_hi.i1031, 32
  %x_lo.i1029 = trunc i128 %_10.i311 to i64
  %_9.1.i1035 = icmp ugt i64 %x_hi_hi.i1032, %x_lo.i1029
  %_9.0.i1034 = sub i64 %x_lo.i1029, %x_hi_hi.i1032
  %_10.i1036 = add i64 %_9.0.i1034, -4294967295
  %spec.select.i1037 = select i1 %_9.1.i1035, i64 %_10.i1036, i64 %_9.0.i1034
  %x_hi_lo.i1033 = and i64 %x_hi.i1031, 4294967295
  %t1.i1038 = mul nuw i64 %x_hi_lo.i1033, 4294967295
  %_14.0.i1039 = add i64 %spec.select.i1037, %t1.i1038
  %_14.1.i1040 = icmp ult i64 %_14.0.i1039, %spec.select.i1037
  %116 = add i64 %_14.0.i1039, 4294967295
  %res.sroa.0.0.i1041 = select i1 %_14.1.i1040, i64 %116, i64 %_14.0.i1039
  %_16.i1042 = icmp ugt i64 %res.sroa.0.0.i1041, -4294967296
  %_17.i1043 = add nsw i64 %res.sroa.0.0.i1041, 4294967295
  %_0.sroa.0.0.i1044 = select i1 %_16.i1042, i64 %_17.i1043, i64 %res.sroa.0.0.i1041
  %_14.i313 = zext i64 %_81.1 to i128
  %_15.i314 = zext i64 %_83.1 to i128
  %_13.i315 = mul nuw i128 %_15.i314, %_14.i313
  %_4.i1014 = lshr i128 %_13.i315, 64
  %x_hi.i1015 = trunc nuw i128 %_4.i1014 to i64
  %x_hi_hi.i1016 = lshr i64 %x_hi.i1015, 32
  %x_lo.i1013 = trunc i128 %_13.i315 to i64
  %_9.1.i1019 = icmp ugt i64 %x_hi_hi.i1016, %x_lo.i1013
  %_9.0.i1018 = sub i64 %x_lo.i1013, %x_hi_hi.i1016
  %_10.i1020 = add i64 %_9.0.i1018, -4294967295
  %spec.select.i1021 = select i1 %_9.1.i1019, i64 %_10.i1020, i64 %_9.0.i1018
  %x_hi_lo.i1017 = and i64 %x_hi.i1015, 4294967295
  %t1.i1022 = mul nuw i64 %x_hi_lo.i1017, 4294967295
  %_14.0.i1023 = add i64 %spec.select.i1021, %t1.i1022
  %_14.1.i1024 = icmp ult i64 %_14.0.i1023, %spec.select.i1021
  %117 = add i64 %_14.0.i1023, 4294967295
  %res.sroa.0.0.i1025 = select i1 %_14.1.i1024, i64 %117, i64 %_14.0.i1023
  %_16.i1026 = icmp ugt i64 %res.sroa.0.0.i1025, -4294967296
  %_17.i1027 = add nsw i64 %res.sroa.0.0.i1025, 4294967295
  %_0.sroa.0.0.i1028 = select i1 %_16.i1026, i64 %_17.i1027, i64 %res.sroa.0.0.i1025
  %_19.i321 = zext i64 %_0.sroa.0.0.i1028 to i128
  %_18.i322 = mul nuw nsw i128 %_19.i321, 7
  %_4.i966 = lshr i128 %_18.i322, 64
  %x_hi.i967 = trunc nuw nsw i128 %_4.i966 to i64
  %t1.i974 = mul nuw nsw i64 %x_hi.i967, 4294967295
  %x_lo.i965 = trunc i128 %_18.i322 to i64
  %_14.0.i975 = add i64 %t1.i974, %x_lo.i965
  %_14.1.i976 = icmp ult i64 %_14.0.i975, %x_lo.i965
  %118 = add i64 %_14.0.i975, 4294967295
  %res.sroa.0.0.i977 = select i1 %_14.1.i976, i64 %118, i64 %_14.0.i975
  %_16.i978 = icmp ugt i64 %res.sroa.0.0.i977, -4294967296
  %_17.i979 = add nsw i64 %res.sroa.0.0.i977, 4294967295
  %_0.sroa.0.0.i980 = select i1 %_16.i978, i64 %_17.i979, i64 %res.sroa.0.0.i977
  %_22.0.i324 = add i64 %_0.sroa.0.0.i980, %_0.sroa.0.0.i1044
  %_22.1.i325 = icmp ult i64 %_22.0.i324, %_0.sroa.0.0.i1044
  %119 = add nuw i64 %_22.0.i324, 4294967295
  %_24.sroa.0.0.i326 = select i1 %_22.1.i325, i64 %119, i64 %_22.0.i324
  %_25.i327 = icmp ugt i64 %_24.sroa.0.0.i326, -4294967296
  %_26.i328 = add nsw i64 %_24.sroa.0.0.i326, 4294967295
  %_7.sroa.0.0.i329 = select i1 %_25.i327, i64 %_26.i328, i64 %_24.sroa.0.0.i326
  %_11.i282 = zext i64 %_7.sroa.0.0.i329 to i128
  %_10.i284 = mul nuw i128 %_11.i282, %_11.i363
  %_4.i1110 = lshr i128 %_10.i284, 64
  %x_hi.i1111 = trunc nuw i128 %_4.i1110 to i64
  %x_hi_hi.i1112 = lshr i64 %x_hi.i1111, 32
  %x_lo.i1109 = trunc i128 %_10.i284 to i64
  %_9.1.i1115 = icmp ugt i64 %x_hi_hi.i1112, %x_lo.i1109
  %_9.0.i1114 = sub i64 %x_lo.i1109, %x_hi_hi.i1112
  %_10.i1116 = add i64 %_9.0.i1114, -4294967295
  %spec.select.i1117 = select i1 %_9.1.i1115, i64 %_10.i1116, i64 %_9.0.i1114
  %x_hi_lo.i1113 = and i64 %x_hi.i1111, 4294967295
  %t1.i1118 = mul nuw i64 %x_hi_lo.i1113, 4294967295
  %_14.0.i1119 = add i64 %spec.select.i1117, %t1.i1118
  %_14.1.i1120 = icmp ult i64 %_14.0.i1119, %spec.select.i1117
  %120 = add i64 %_14.0.i1119, 4294967295
  %res.sroa.0.0.i1121 = select i1 %_14.1.i1120, i64 %120, i64 %_14.0.i1119
  %_16.i1122 = icmp ugt i64 %res.sroa.0.0.i1121, -4294967296
  %_17.i1123 = add nsw i64 %res.sroa.0.0.i1121, 4294967295
  %_0.sroa.0.0.i1124 = select i1 %_16.i1122, i64 %_17.i1123, i64 %res.sroa.0.0.i1121
  %_16.i317 = mul nuw i128 %_15.i314, %_11.i309
  %_4.i998 = lshr i128 %_16.i317, 64
  %x_hi.i999 = trunc nuw i128 %_4.i998 to i64
  %x_hi_hi.i1000 = lshr i64 %x_hi.i999, 32
  %x_lo.i997 = trunc i128 %_16.i317 to i64
  %_9.1.i1003 = icmp ugt i64 %x_hi_hi.i1000, %x_lo.i997
  %_9.0.i1002 = sub i64 %x_lo.i997, %x_hi_hi.i1000
  %_10.i1004 = add i64 %_9.0.i1002, -4294967295
  %spec.select.i1005 = select i1 %_9.1.i1003, i64 %_10.i1004, i64 %_9.0.i1002
  %x_hi_lo.i1001 = and i64 %x_hi.i999, 4294967295
  %t1.i1006 = mul nuw i64 %x_hi_lo.i1001, 4294967295
  %_14.0.i1007 = add i64 %spec.select.i1005, %t1.i1006
  %_14.1.i1008 = icmp ult i64 %_14.0.i1007, %spec.select.i1005
  %121 = add i64 %_14.0.i1007, 4294967295
  %res.sroa.0.0.i1009 = select i1 %_14.1.i1008, i64 %121, i64 %_14.0.i1007
  %_16.i1010 = icmp ugt i64 %res.sroa.0.0.i1009, -4294967296
  %_17.i1011 = add nsw i64 %res.sroa.0.0.i1009, 4294967295
  %_0.sroa.0.0.i1012 = select i1 %_16.i1010, i64 %_17.i1011, i64 %res.sroa.0.0.i1009
  %_17.i319 = mul nuw i128 %_12.i310, %_14.i313
  %_4.i982 = lshr i128 %_17.i319, 64
  %x_hi.i983 = trunc nuw i128 %_4.i982 to i64
  %x_hi_hi.i984 = lshr i64 %x_hi.i983, 32
  %x_lo.i981 = trunc i128 %_17.i319 to i64
  %_9.1.i987 = icmp ugt i64 %x_hi_hi.i984, %x_lo.i981
  %_9.0.i986 = sub i64 %x_lo.i981, %x_hi_hi.i984
  %_10.i988 = add i64 %_9.0.i986, -4294967295
  %spec.select.i989 = select i1 %_9.1.i987, i64 %_10.i988, i64 %_9.0.i986
  %x_hi_lo.i985 = and i64 %x_hi.i983, 4294967295
  %t1.i990 = mul nuw i64 %x_hi_lo.i985, 4294967295
  %_14.0.i991 = add i64 %spec.select.i989, %t1.i990
  %_14.1.i992 = icmp ult i64 %_14.0.i991, %spec.select.i989
  %122 = add i64 %_14.0.i991, 4294967295
  %res.sroa.0.0.i993 = select i1 %_14.1.i992, i64 %122, i64 %_14.0.i991
  %_16.i994 = icmp ugt i64 %res.sroa.0.0.i993, -4294967296
  %_17.i995 = add nsw i64 %res.sroa.0.0.i993, 4294967295
  %_0.sroa.0.0.i996 = select i1 %_16.i994, i64 %_17.i995, i64 %res.sroa.0.0.i993
  %_29.0.i330 = add i64 %_0.sroa.0.0.i1012, %_0.sroa.0.0.i996
  %_29.1.i331 = icmp ult i64 %_29.0.i330, %_0.sroa.0.0.i1012
  %123 = add nuw i64 %_29.0.i330, 4294967295
  %_30.sroa.0.0.i332 = select i1 %_29.1.i331, i64 %123, i64 %_29.0.i330
  %_31.i333 = icmp ugt i64 %_30.sroa.0.0.i332, -4294967296
  %_32.i334 = add nsw i64 %_30.sroa.0.0.i332, 4294967295
  %_9.sroa.0.0.i335 = select i1 %_31.i333, i64 %_32.i334, i64 %_30.sroa.0.0.i332
  %_14.i286 = zext i64 %_9.sroa.0.0.i335 to i128
  %_13.i288 = mul nuw i128 %_14.i286, %_14.i367
  %_4.i1094 = lshr i128 %_13.i288, 64
  %x_hi.i1095 = trunc nuw i128 %_4.i1094 to i64
  %x_hi_hi.i1096 = lshr i64 %x_hi.i1095, 32
  %x_lo.i1093 = trunc i128 %_13.i288 to i64
  %_9.1.i1099 = icmp ugt i64 %x_hi_hi.i1096, %x_lo.i1093
  %_9.0.i1098 = sub i64 %x_lo.i1093, %x_hi_hi.i1096
  %_10.i1100 = add i64 %_9.0.i1098, -4294967295
  %spec.select.i1101 = select i1 %_9.1.i1099, i64 %_10.i1100, i64 %_9.0.i1098
  %x_hi_lo.i1097 = and i64 %x_hi.i1095, 4294967295
  %t1.i1102 = mul nuw i64 %x_hi_lo.i1097, 4294967295
  %_14.0.i1103 = add i64 %spec.select.i1101, %t1.i1102
  %_14.1.i1104 = icmp ult i64 %_14.0.i1103, %spec.select.i1101
  %124 = add i64 %_14.0.i1103, 4294967295
  %res.sroa.0.0.i1105 = select i1 %_14.1.i1104, i64 %124, i64 %_14.0.i1103
  %_16.i1106 = icmp ugt i64 %res.sroa.0.0.i1105, -4294967296
  %_17.i1107 = add nsw i64 %res.sroa.0.0.i1105, 4294967295
  %_0.sroa.0.0.i1108 = select i1 %_16.i1106, i64 %_17.i1107, i64 %res.sroa.0.0.i1105
  %_19.i294 = zext i64 %_0.sroa.0.0.i1108 to i128
  %_18.i295 = mul nuw nsw i128 %_19.i294, 7
  %_4.i1046 = lshr i128 %_18.i295, 64
  %x_hi.i1047 = trunc nuw nsw i128 %_4.i1046 to i64
  %t1.i1054 = mul nuw nsw i64 %x_hi.i1047, 4294967295
  %x_lo.i1045 = trunc i128 %_18.i295 to i64
  %_14.0.i1055 = add i64 %t1.i1054, %x_lo.i1045
  %_14.1.i1056 = icmp ult i64 %_14.0.i1055, %x_lo.i1045
  %125 = add i64 %_14.0.i1055, 4294967295
  %res.sroa.0.0.i1057 = select i1 %_14.1.i1056, i64 %125, i64 %_14.0.i1055
  %_16.i1058 = icmp ugt i64 %res.sroa.0.0.i1057, -4294967296
  %_17.i1059 = add nsw i64 %res.sroa.0.0.i1057, 4294967295
  %_0.sroa.0.0.i1060 = select i1 %_16.i1058, i64 %_17.i1059, i64 %res.sroa.0.0.i1057
  %_22.0.i297 = add i64 %_0.sroa.0.0.i1124, %_0.sroa.0.0.i1060
  %_22.1.i298 = icmp ult i64 %_22.0.i297, %_0.sroa.0.0.i1124
  %126 = add nuw i64 %_22.0.i297, 4294967295
  %_24.sroa.0.0.i299 = select i1 %_22.1.i298, i64 %126, i64 %_22.0.i297
  %_25.i300 = icmp ugt i64 %_24.sroa.0.0.i299, -4294967296
  %_26.i301 = add nsw i64 %_24.sroa.0.0.i299, 4294967295
  %_7.sroa.0.0.i302 = select i1 %_25.i300, i64 %_26.i301, i64 %_24.sroa.0.0.i299
  %_11.i255 = zext i64 %_7.sroa.0.0.i302 to i128
  %_227 = zext i64 %g8.1 to i128
  %_225 = zext i64 %_252 to i128
  %_226 = mul nuw i128 %_225, %_227
  %_4.i1526 = lshr i128 %_226, 64
  %x_hi.i1527 = trunc nuw i128 %_4.i1526 to i64
  %x_hi_hi.i1528 = lshr i64 %x_hi.i1527, 32
  %x_lo.i1525 = trunc i128 %_226 to i64
  %_9.1.i1531 = icmp ugt i64 %x_hi_hi.i1528, %x_lo.i1525
  %_9.0.i1530 = sub i64 %x_lo.i1525, %x_hi_hi.i1528
  %_10.i1532 = add i64 %_9.0.i1530, -4294967295
  %spec.select.i1533 = select i1 %_9.1.i1531, i64 %_10.i1532, i64 %_9.0.i1530
  %x_hi_lo.i1529 = and i64 %x_hi.i1527, 4294967295
  %t1.i1534 = mul nuw i64 %x_hi_lo.i1529, 4294967295
  %_14.0.i1535 = add i64 %spec.select.i1533, %t1.i1534
  %_14.1.i1536 = icmp ult i64 %_14.0.i1535, %spec.select.i1533
  %127 = add i64 %_14.0.i1535, 4294967295
  %res.sroa.0.0.i1537 = select i1 %_14.1.i1536, i64 %127, i64 %_14.0.i1535
  %_16.i1538 = icmp ugt i64 %res.sroa.0.0.i1537, -4294967296
  %_17.i1539 = add nsw i64 %res.sroa.0.0.i1537, 4294967295
  %_0.sroa.0.0.i1540 = select i1 %_16.i1538, i64 %_17.i1539, i64 %res.sroa.0.0.i1537
  %_13.0.i57 = add i64 %_0.sroa.0.0.i1540, %_73.1
  %_13.1.i58 = icmp ult i64 %_13.0.i57, %_0.sroa.0.0.i1540
  %128 = add i64 %_13.0.i57, 4294967295
  %_14.sroa.0.0.i59 = select i1 %_13.1.i58, i64 %128, i64 %_13.0.i57
  %_15.i60 = icmp ugt i64 %_14.sroa.0.0.i59, -4294967296
  %_16.i61 = add nsw i64 %_14.sroa.0.0.i59, 4294967295
  %_4.sroa.0.0.i62 = select i1 %_15.i60, i64 %_16.i61, i64 %_14.sroa.0.0.i59
  %_240.1 = icmp ult i64 %_4.sroa.0.0.i62, %_262
  %_240.0 = sub i64 %_4.sroa.0.0.i62, %_262
  %129 = add i64 %_240.0, -4294967295
  %_241.sroa.0.0 = select i1 %_240.1, i64 %129, i64 %_240.0
  %_15.i260 = zext i64 %_241.sroa.0.0 to i128
  %_16.i263 = mul nuw i128 %_11.i255, %_15.i260
  %_4.i1158 = lshr i128 %_16.i263, 64
  %x_hi.i1159 = trunc nuw i128 %_4.i1158 to i64
  %x_hi_hi.i1160 = lshr i64 %x_hi.i1159, 32
  %x_lo.i1157 = trunc i128 %_16.i263 to i64
  %_9.1.i1163 = icmp ugt i64 %x_hi_hi.i1160, %x_lo.i1157
  %_9.0.i1162 = sub i64 %x_lo.i1157, %x_hi_hi.i1160
  %_10.i1164 = add i64 %_9.0.i1162, -4294967295
  %spec.select.i1165 = select i1 %_9.1.i1163, i64 %_10.i1164, i64 %_9.0.i1162
  %x_hi_lo.i1161 = and i64 %x_hi.i1159, 4294967295
  %t1.i1166 = mul nuw i64 %x_hi_lo.i1161, 4294967295
  %_14.0.i1167 = add i64 %spec.select.i1165, %t1.i1166
  %_14.1.i1168 = icmp ult i64 %_14.0.i1167, %spec.select.i1165
  %130 = add i64 %_14.0.i1167, 4294967295
  %res.sroa.0.0.i1169 = select i1 %_14.1.i1168, i64 %130, i64 %_14.0.i1167
  %_16.i1170 = icmp ugt i64 %res.sroa.0.0.i1169, -4294967296
  %_17.i1171 = add nsw i64 %res.sroa.0.0.i1169, 4294967295
  %_0.sroa.0.0.i1172 = select i1 %_16.i1170, i64 %_17.i1171, i64 %res.sroa.0.0.i1169
  %_16.i290 = mul nuw i128 %_11.i282, %_14.i367
  %_4.i1078 = lshr i128 %_16.i290, 64
  %x_hi.i1079 = trunc nuw i128 %_4.i1078 to i64
  %x_hi_hi.i1080 = lshr i64 %x_hi.i1079, 32
  %x_lo.i1077 = trunc i128 %_16.i290 to i64
  %_9.1.i1083 = icmp ugt i64 %x_hi_hi.i1080, %x_lo.i1077
  %_9.0.i1082 = sub i64 %x_lo.i1077, %x_hi_hi.i1080
  %_10.i1084 = add i64 %_9.0.i1082, -4294967295
  %spec.select.i1085 = select i1 %_9.1.i1083, i64 %_10.i1084, i64 %_9.0.i1082
  %x_hi_lo.i1081 = and i64 %x_hi.i1079, 4294967295
  %t1.i1086 = mul nuw i64 %x_hi_lo.i1081, 4294967295
  %_14.0.i1087 = add i64 %spec.select.i1085, %t1.i1086
  %_14.1.i1088 = icmp ult i64 %_14.0.i1087, %spec.select.i1085
  %131 = add i64 %_14.0.i1087, 4294967295
  %res.sroa.0.0.i1089 = select i1 %_14.1.i1088, i64 %131, i64 %_14.0.i1087
  %_16.i1090 = icmp ugt i64 %res.sroa.0.0.i1089, -4294967296
  %_17.i1091 = add nsw i64 %res.sroa.0.0.i1089, 4294967295
  %_0.sroa.0.0.i1092 = select i1 %_16.i1090, i64 %_17.i1091, i64 %res.sroa.0.0.i1089
  %_17.i292 = mul nuw i128 %_14.i286, %_11.i363
  %_4.i1062 = lshr i128 %_17.i292, 64
  %x_hi.i1063 = trunc nuw i128 %_4.i1062 to i64
  %x_hi_hi.i1064 = lshr i64 %x_hi.i1063, 32
  %x_lo.i1061 = trunc i128 %_17.i292 to i64
  %_9.1.i1067 = icmp ugt i64 %x_hi_hi.i1064, %x_lo.i1061
  %_9.0.i1066 = sub i64 %x_lo.i1061, %x_hi_hi.i1064
  %_10.i1068 = add i64 %_9.0.i1066, -4294967295
  %spec.select.i1069 = select i1 %_9.1.i1067, i64 %_10.i1068, i64 %_9.0.i1066
  %x_hi_lo.i1065 = and i64 %x_hi.i1063, 4294967295
  %t1.i1070 = mul nuw i64 %x_hi_lo.i1065, 4294967295
  %_14.0.i1071 = add i64 %spec.select.i1069, %t1.i1070
  %_14.1.i1072 = icmp ult i64 %_14.0.i1071, %spec.select.i1069
  %132 = add i64 %_14.0.i1071, 4294967295
  %res.sroa.0.0.i1073 = select i1 %_14.1.i1072, i64 %132, i64 %_14.0.i1071
  %_16.i1074 = icmp ugt i64 %res.sroa.0.0.i1073, -4294967296
  %_17.i1075 = add nsw i64 %res.sroa.0.0.i1073, 4294967295
  %_0.sroa.0.0.i1076 = select i1 %_16.i1074, i64 %_17.i1075, i64 %res.sroa.0.0.i1073
  %_29.0.i303 = add i64 %_0.sroa.0.0.i1092, %_0.sroa.0.0.i1076
  %_29.1.i304 = icmp ult i64 %_29.0.i303, %_0.sroa.0.0.i1092
  %133 = add nuw i64 %_29.0.i303, 4294967295
  %_30.sroa.0.0.i305 = select i1 %_29.1.i304, i64 %133, i64 %_29.0.i303
  %_31.i306 = icmp ugt i64 %_30.sroa.0.0.i305, -4294967296
  %_32.i307 = add nsw i64 %_30.sroa.0.0.i305, 4294967295
  %_9.sroa.0.0.i308 = select i1 %_31.i306, i64 %_32.i307, i64 %_30.sroa.0.0.i305
  %_14.i259 = zext i64 %_9.sroa.0.0.i308 to i128
  %_224 = zext i64 %g8.0 to i128
  %_223 = mul nuw i128 %_225, %_224
  %_4.i1542 = lshr i128 %_223, 64
  %x_hi.i1543 = trunc nuw i128 %_4.i1542 to i64
  %x_hi_hi.i1544 = lshr i64 %x_hi.i1543, 32
  %x_lo.i1541 = trunc i128 %_223 to i64
  %_9.1.i1547 = icmp ugt i64 %x_hi_hi.i1544, %x_lo.i1541
  %_9.0.i1546 = sub i64 %x_lo.i1541, %x_hi_hi.i1544
  %_10.i1548 = add i64 %_9.0.i1546, -4294967295
  %spec.select.i1549 = select i1 %_9.1.i1547, i64 %_10.i1548, i64 %_9.0.i1546
  %x_hi_lo.i1545 = and i64 %x_hi.i1543, 4294967295
  %t1.i1550 = mul nuw i64 %x_hi_lo.i1545, 4294967295
  %_14.0.i1551 = add i64 %spec.select.i1549, %t1.i1550
  %_14.1.i1552 = icmp ult i64 %_14.0.i1551, %spec.select.i1549
  %134 = add i64 %_14.0.i1551, 4294967295
  %res.sroa.0.0.i1553 = select i1 %_14.1.i1552, i64 %134, i64 %_14.0.i1551
  %_16.i1554 = icmp ugt i64 %res.sroa.0.0.i1553, -4294967296
  %_17.i1555 = add nsw i64 %res.sroa.0.0.i1553, 4294967295
  %_0.sroa.0.0.i1556 = select i1 %_16.i1554, i64 %_17.i1555, i64 %res.sroa.0.0.i1553
  %_7.0.i51 = add i64 %_0.sroa.0.0.i1556, %_73.0
  %_7.1.i52 = icmp ult i64 %_7.0.i51, %_0.sroa.0.0.i1556
  %135 = add i64 %_7.0.i51, 4294967295
  %_8.sroa.0.0.i53 = select i1 %_7.1.i52, i64 %135, i64 %_7.0.i51
  %_9.i54 = icmp ugt i64 %_8.sroa.0.0.i53, -4294967296
  %_10.i55 = add nsw i64 %_8.sroa.0.0.i53, 4294967295
  %_3.sroa.0.0.i56 = select i1 %_9.i54, i64 %_10.i55, i64 %_8.sroa.0.0.i53
  %_236.1 = icmp ult i64 %_3.sroa.0.0.i56, %_261
  %_236.0 = sub i64 %_3.sroa.0.0.i56, %_261
  %136 = add i64 %_236.0, -4294967295
  %_237.sroa.0.0 = select i1 %_236.1, i64 %136, i64 %_236.0
  %_12.i256 = zext i64 %_237.sroa.0.0 to i128
  %_17.i265 = mul nuw i128 %_14.i259, %_12.i256
  %_4.i1142 = lshr i128 %_17.i265, 64
  %x_hi.i1143 = trunc nuw i128 %_4.i1142 to i64
  %x_hi_hi.i1144 = lshr i64 %x_hi.i1143, 32
  %x_lo.i1141 = trunc i128 %_17.i265 to i64
  %_9.1.i1147 = icmp ugt i64 %x_hi_hi.i1144, %x_lo.i1141
  %_9.0.i1146 = sub i64 %x_lo.i1141, %x_hi_hi.i1144
  %_10.i1148 = add i64 %_9.0.i1146, -4294967295
  %spec.select.i1149 = select i1 %_9.1.i1147, i64 %_10.i1148, i64 %_9.0.i1146
  %x_hi_lo.i1145 = and i64 %x_hi.i1143, 4294967295
  %t1.i1150 = mul nuw i64 %x_hi_lo.i1145, 4294967295
  %_14.0.i1151 = add i64 %spec.select.i1149, %t1.i1150
  %_14.1.i1152 = icmp ult i64 %_14.0.i1151, %spec.select.i1149
  %137 = add i64 %_14.0.i1151, 4294967295
  %res.sroa.0.0.i1153 = select i1 %_14.1.i1152, i64 %137, i64 %_14.0.i1151
  %_16.i1154 = icmp ugt i64 %res.sroa.0.0.i1153, -4294967296
  %_17.i1155 = add nsw i64 %res.sroa.0.0.i1153, 4294967295
  %_0.sroa.0.0.i1156 = select i1 %_16.i1154, i64 %_17.i1155, i64 %res.sroa.0.0.i1153
  %_29.0.i276 = add i64 %_0.sroa.0.0.i1172, %_0.sroa.0.0.i1156
  %_29.1.i277 = icmp ult i64 %_29.0.i276, %_0.sroa.0.0.i1172
  %138 = add nuw i64 %_29.0.i276, 4294967295
  %_30.sroa.0.0.i278 = select i1 %_29.1.i277, i64 %138, i64 %_29.0.i276
  %_31.i279 = icmp ugt i64 %_30.sroa.0.0.i278, -4294967296
  %_32.i280 = add nsw i64 %_30.sroa.0.0.i278, 4294967295
  %_9.sroa.0.0.i281 = select i1 %_31.i279, i64 %_32.i280, i64 %_30.sroa.0.0.i278
  %_13.0.i45 = add i64 %_9.sroa.0.0.i281, %_9.sroa.0.0.i362
  %_13.1.i46 = icmp ult i64 %_13.0.i45, %_9.sroa.0.0.i362
  %139 = add i64 %_13.0.i45, 4294967295
  %_14.sroa.0.0.i47 = select i1 %_13.1.i46, i64 %139, i64 %_13.0.i45
  %_15.i48 = icmp ugt i64 %_14.sroa.0.0.i47, -4294967296
  %_16.i49 = add nsw i64 %_14.sroa.0.0.i47, 4294967295
  %_4.sroa.0.0.i50 = select i1 %_15.i48, i64 %_16.i49, i64 %_14.sroa.0.0.i47
  %_10.i338 = mul nuw i128 %_11.i336, %_12.i337
  %_4.i950 = lshr i128 %_10.i338, 64
  %x_hi.i951 = trunc nuw i128 %_4.i950 to i64
  %x_hi_hi.i952 = lshr i64 %x_hi.i951, 32
  %x_lo.i949 = trunc i128 %_10.i338 to i64
  %_9.1.i955 = icmp ugt i64 %x_hi_hi.i952, %x_lo.i949
  %_9.0.i954 = sub i64 %x_lo.i949, %x_hi_hi.i952
  %_10.i956 = add i64 %_9.0.i954, -4294967295
  %spec.select.i957 = select i1 %_9.1.i955, i64 %_10.i956, i64 %_9.0.i954
  %x_hi_lo.i953 = and i64 %x_hi.i951, 4294967295
  %t1.i958 = mul nuw i64 %x_hi_lo.i953, 4294967295
  %_14.0.i959 = add i64 %spec.select.i957, %t1.i958
  %_14.1.i960 = icmp ult i64 %_14.0.i959, %spec.select.i957
  %140 = add i64 %_14.0.i959, 4294967295
  %res.sroa.0.0.i961 = select i1 %_14.1.i960, i64 %140, i64 %_14.0.i959
  %_16.i962 = icmp ugt i64 %res.sroa.0.0.i961, -4294967296
  %_17.i963 = add nsw i64 %res.sroa.0.0.i961, 4294967295
  %_0.sroa.0.0.i964 = select i1 %_16.i962, i64 %_17.i963, i64 %res.sroa.0.0.i961
  %_13.i342 = mul nuw i128 %_14.i340, %_15.i341
  %_4.i934 = lshr i128 %_13.i342, 64
  %x_hi.i935 = trunc nuw i128 %_4.i934 to i64
  %x_hi_hi.i936 = lshr i64 %x_hi.i935, 32
  %x_lo.i933 = trunc i128 %_13.i342 to i64
  %_9.1.i939 = icmp ugt i64 %x_hi_hi.i936, %x_lo.i933
  %_9.0.i938 = sub i64 %x_lo.i933, %x_hi_hi.i936
  %_10.i940 = add i64 %_9.0.i938, -4294967295
  %spec.select.i941 = select i1 %_9.1.i939, i64 %_10.i940, i64 %_9.0.i938
  %x_hi_lo.i937 = and i64 %x_hi.i935, 4294967295
  %t1.i942 = mul nuw i64 %x_hi_lo.i937, 4294967295
  %_14.0.i943 = add i64 %spec.select.i941, %t1.i942
  %_14.1.i944 = icmp ult i64 %_14.0.i943, %spec.select.i941
  %141 = add i64 %_14.0.i943, 4294967295
  %res.sroa.0.0.i945 = select i1 %_14.1.i944, i64 %141, i64 %_14.0.i943
  %_16.i946 = icmp ugt i64 %res.sroa.0.0.i945, -4294967296
  %_17.i947 = add nsw i64 %res.sroa.0.0.i945, 4294967295
  %_0.sroa.0.0.i948 = select i1 %_16.i946, i64 %_17.i947, i64 %res.sroa.0.0.i945
  %_19.i348 = zext i64 %_0.sroa.0.0.i948 to i128
  %_18.i349 = mul nuw nsw i128 %_19.i348, 7
  %_4.i886 = lshr i128 %_18.i349, 64
  %x_hi.i887 = trunc nuw nsw i128 %_4.i886 to i64
  %t1.i894 = mul nuw nsw i64 %x_hi.i887, 4294967295
  %x_lo.i885 = trunc i128 %_18.i349 to i64
  %_14.0.i895 = add i64 %t1.i894, %x_lo.i885
  %_14.1.i896 = icmp ult i64 %_14.0.i895, %x_lo.i885
  %142 = add i64 %_14.0.i895, 4294967295
  %res.sroa.0.0.i897 = select i1 %_14.1.i896, i64 %142, i64 %_14.0.i895
  %_16.i898 = icmp ugt i64 %res.sroa.0.0.i897, -4294967296
  %_17.i899 = add nsw i64 %res.sroa.0.0.i897, 4294967295
  %_0.sroa.0.0.i900 = select i1 %_16.i898, i64 %_17.i899, i64 %res.sroa.0.0.i897
  %_22.0.i351 = add i64 %_0.sroa.0.0.i900, %_0.sroa.0.0.i964
  %_22.1.i352 = icmp ult i64 %_22.0.i351, %_0.sroa.0.0.i964
  %143 = add nuw i64 %_22.0.i351, 4294967295
  %_24.sroa.0.0.i353 = select i1 %_22.1.i352, i64 %143, i64 %_22.0.i351
  %_25.i354 = icmp ugt i64 %_24.sroa.0.0.i353, -4294967296
  %_26.i355 = add nsw i64 %_24.sroa.0.0.i353, 4294967295
  %_7.sroa.0.0.i356 = select i1 %_25.i354, i64 %_26.i355, i64 %_24.sroa.0.0.i353
  %_10.i257 = mul nuw i128 %_11.i255, %_12.i256
  %_4.i1190 = lshr i128 %_10.i257, 64
  %x_hi.i1191 = trunc nuw i128 %_4.i1190 to i64
  %x_hi_hi.i1192 = lshr i64 %x_hi.i1191, 32
  %x_lo.i1189 = trunc i128 %_10.i257 to i64
  %_9.1.i1195 = icmp ugt i64 %x_hi_hi.i1192, %x_lo.i1189
  %_9.0.i1194 = sub i64 %x_lo.i1189, %x_hi_hi.i1192
  %_10.i1196 = add i64 %_9.0.i1194, -4294967295
  %spec.select.i1197 = select i1 %_9.1.i1195, i64 %_10.i1196, i64 %_9.0.i1194
  %x_hi_lo.i1193 = and i64 %x_hi.i1191, 4294967295
  %t1.i1198 = mul nuw i64 %x_hi_lo.i1193, 4294967295
  %_14.0.i1199 = add i64 %spec.select.i1197, %t1.i1198
  %_14.1.i1200 = icmp ult i64 %_14.0.i1199, %spec.select.i1197
  %144 = add i64 %_14.0.i1199, 4294967295
  %res.sroa.0.0.i1201 = select i1 %_14.1.i1200, i64 %144, i64 %_14.0.i1199
  %_16.i1202 = icmp ugt i64 %res.sroa.0.0.i1201, -4294967296
  %_17.i1203 = add nsw i64 %res.sroa.0.0.i1201, 4294967295
  %_0.sroa.0.0.i1204 = select i1 %_16.i1202, i64 %_17.i1203, i64 %res.sroa.0.0.i1201
  %_13.i261 = mul nuw i128 %_14.i259, %_15.i260
  %_4.i1174 = lshr i128 %_13.i261, 64
  %x_hi.i1175 = trunc nuw i128 %_4.i1174 to i64
  %x_hi_hi.i1176 = lshr i64 %x_hi.i1175, 32
  %x_lo.i1173 = trunc i128 %_13.i261 to i64
  %_9.1.i1179 = icmp ugt i64 %x_hi_hi.i1176, %x_lo.i1173
  %_9.0.i1178 = sub i64 %x_lo.i1173, %x_hi_hi.i1176
  %_10.i1180 = add i64 %_9.0.i1178, -4294967295
  %spec.select.i1181 = select i1 %_9.1.i1179, i64 %_10.i1180, i64 %_9.0.i1178
  %x_hi_lo.i1177 = and i64 %x_hi.i1175, 4294967295
  %t1.i1182 = mul nuw i64 %x_hi_lo.i1177, 4294967295
  %_14.0.i1183 = add i64 %spec.select.i1181, %t1.i1182
  %_14.1.i1184 = icmp ult i64 %_14.0.i1183, %spec.select.i1181
  %145 = add i64 %_14.0.i1183, 4294967295
  %res.sroa.0.0.i1185 = select i1 %_14.1.i1184, i64 %145, i64 %_14.0.i1183
  %_16.i1186 = icmp ugt i64 %res.sroa.0.0.i1185, -4294967296
  %_17.i1187 = add nsw i64 %res.sroa.0.0.i1185, 4294967295
  %_0.sroa.0.0.i1188 = select i1 %_16.i1186, i64 %_17.i1187, i64 %res.sroa.0.0.i1185
  %_19.i267 = zext i64 %_0.sroa.0.0.i1188 to i128
  %_18.i268 = mul nuw nsw i128 %_19.i267, 7
  %_4.i1126 = lshr i128 %_18.i268, 64
  %x_hi.i1127 = trunc nuw nsw i128 %_4.i1126 to i64
  %t1.i1134 = mul nuw nsw i64 %x_hi.i1127, 4294967295
  %x_lo.i1125 = trunc i128 %_18.i268 to i64
  %_14.0.i1135 = add i64 %t1.i1134, %x_lo.i1125
  %_14.1.i1136 = icmp ult i64 %_14.0.i1135, %x_lo.i1125
  %146 = add i64 %_14.0.i1135, 4294967295
  %res.sroa.0.0.i1137 = select i1 %_14.1.i1136, i64 %146, i64 %_14.0.i1135
  %_16.i1138 = icmp ugt i64 %res.sroa.0.0.i1137, -4294967296
  %_17.i1139 = add nsw i64 %res.sroa.0.0.i1137, 4294967295
  %_0.sroa.0.0.i1140 = select i1 %_16.i1138, i64 %_17.i1139, i64 %res.sroa.0.0.i1137
  %_22.0.i270 = add i64 %_0.sroa.0.0.i1140, %_0.sroa.0.0.i1204
  %_22.1.i271 = icmp ult i64 %_22.0.i270, %_0.sroa.0.0.i1204
  %147 = add nuw i64 %_22.0.i270, 4294967295
  %_24.sroa.0.0.i272 = select i1 %_22.1.i271, i64 %147, i64 %_22.0.i270
  %_25.i273 = icmp ugt i64 %_24.sroa.0.0.i272, -4294967296
  %_26.i274 = add nsw i64 %_24.sroa.0.0.i272, 4294967295
  %_7.sroa.0.0.i275 = select i1 %_25.i273, i64 %_26.i274, i64 %_24.sroa.0.0.i272
  %_7.0.i39 = add i64 %_7.sroa.0.0.i275, %_7.sroa.0.0.i356
  %_7.1.i40 = icmp ult i64 %_7.0.i39, %_7.sroa.0.0.i356
  %148 = add i64 %_7.0.i39, 4294967295
  %_8.sroa.0.0.i41 = select i1 %_7.1.i40, i64 %148, i64 %_7.0.i39
  %_9.i42 = icmp ugt i64 %_8.sroa.0.0.i41, -4294967296
  %_10.i43 = add nsw i64 %_8.sroa.0.0.i41, 4294967295
  %_3.sroa.0.0.i44 = select i1 %_9.i42, i64 %_10.i43, i64 %_8.sroa.0.0.i41
  %149 = getelementptr inbounds nuw i8, ptr %_247, i64 24
  %_89.1 = load i64, ptr %149, align 8, !noundef !3
  %_90 = getelementptr inbounds nuw i8, ptr %_247, i64 16
  %_89.0 = load i64, ptr %_90, align 8, !noundef !3
  %150 = getelementptr inbounds nuw i8, ptr %v.0, i64 32
  %_91.0 = load i64, ptr %150, align 8, !noundef !3
  %151 = getelementptr inbounds nuw i8, ptr %v.0, i64 40
  %_91.1 = load i64, ptr %151, align 8, !noundef !3
  %_11.i228 = zext i64 %_89.0 to i128
  %_12.i229 = zext i64 %_91.0 to i128
  %_10.i230 = mul nuw i128 %_12.i229, %_11.i228
  %x_lo.i1269 = trunc i128 %_10.i230 to i64
  %_4.i1270 = lshr i128 %_10.i230, 64
  %x_hi.i1271 = trunc nuw i128 %_4.i1270 to i64
  %x_hi_hi.i1272 = lshr i64 %x_hi.i1271, 32
  %x_hi_lo.i1273 = and i64 %x_hi.i1271, 4294967295
  %_9.0.i1274 = sub i64 %x_lo.i1269, %x_hi_hi.i1272
  %_9.1.i1275 = icmp ugt i64 %x_hi_hi.i1272, %x_lo.i1269
  %_10.i1276 = add i64 %_9.0.i1274, -4294967295
  %spec.select.i1277 = select i1 %_9.1.i1275, i64 %_10.i1276, i64 %_9.0.i1274
  %t1.i1278 = mul nuw i64 %x_hi_lo.i1273, 4294967295
  %_14.0.i1279 = add i64 %spec.select.i1277, %t1.i1278
  %_14.1.i1280 = icmp ult i64 %_14.0.i1279, %spec.select.i1277
  %152 = add i64 %_14.0.i1279, 4294967295
  %res.sroa.0.0.i1281 = select i1 %_14.1.i1280, i64 %152, i64 %_14.0.i1279
  %_16.i1282 = icmp ugt i64 %res.sroa.0.0.i1281, -4294967296
  %_17.i1283 = add nsw i64 %res.sroa.0.0.i1281, 4294967295
  %_0.sroa.0.0.i1284 = select i1 %_16.i1282, i64 %_17.i1283, i64 %res.sroa.0.0.i1281
  %_14.i232 = zext i64 %_89.1 to i128
  %_15.i233 = zext i64 %_91.1 to i128
  %_13.i234 = mul nuw i128 %_15.i233, %_14.i232
  %x_lo.i1253 = trunc i128 %_13.i234 to i64
  %_4.i1254 = lshr i128 %_13.i234, 64
  %x_hi.i1255 = trunc nuw i128 %_4.i1254 to i64
  %x_hi_hi.i1256 = lshr i64 %x_hi.i1255, 32
  %x_hi_lo.i1257 = and i64 %x_hi.i1255, 4294967295
  %_9.0.i1258 = sub i64 %x_lo.i1253, %x_hi_hi.i1256
  %_9.1.i1259 = icmp ugt i64 %x_hi_hi.i1256, %x_lo.i1253
  %_10.i1260 = add i64 %_9.0.i1258, -4294967295
  %spec.select.i1261 = select i1 %_9.1.i1259, i64 %_10.i1260, i64 %_9.0.i1258
  %t1.i1262 = mul nuw i64 %x_hi_lo.i1257, 4294967295
  %_14.0.i1263 = add i64 %spec.select.i1261, %t1.i1262
  %_14.1.i1264 = icmp ult i64 %_14.0.i1263, %spec.select.i1261
  %153 = add i64 %_14.0.i1263, 4294967295
  %res.sroa.0.0.i1265 = select i1 %_14.1.i1264, i64 %153, i64 %_14.0.i1263
  %_16.i1266 = icmp ugt i64 %res.sroa.0.0.i1265, -4294967296
  %_17.i1267 = add nsw i64 %res.sroa.0.0.i1265, 4294967295
  %_0.sroa.0.0.i1268 = select i1 %_16.i1266, i64 %_17.i1267, i64 %res.sroa.0.0.i1265
  %_16.i236 = mul nuw i128 %_15.i233, %_11.i228
  %x_lo.i1237 = trunc i128 %_16.i236 to i64
  %_4.i1238 = lshr i128 %_16.i236, 64
  %x_hi.i1239 = trunc nuw i128 %_4.i1238 to i64
  %x_hi_hi.i1240 = lshr i64 %x_hi.i1239, 32
  %x_hi_lo.i1241 = and i64 %x_hi.i1239, 4294967295
  %_9.0.i1242 = sub i64 %x_lo.i1237, %x_hi_hi.i1240
  %_9.1.i1243 = icmp ugt i64 %x_hi_hi.i1240, %x_lo.i1237
  %_10.i1244 = add i64 %_9.0.i1242, -4294967295
  %spec.select.i1245 = select i1 %_9.1.i1243, i64 %_10.i1244, i64 %_9.0.i1242
  %t1.i1246 = mul nuw i64 %x_hi_lo.i1241, 4294967295
  %_14.0.i1247 = add i64 %spec.select.i1245, %t1.i1246
  %_14.1.i1248 = icmp ult i64 %_14.0.i1247, %spec.select.i1245
  %154 = add i64 %_14.0.i1247, 4294967295
  %res.sroa.0.0.i1249 = select i1 %_14.1.i1248, i64 %154, i64 %_14.0.i1247
  %_16.i1250 = icmp ugt i64 %res.sroa.0.0.i1249, -4294967296
  %_17.i1251 = add nsw i64 %res.sroa.0.0.i1249, 4294967295
  %_0.sroa.0.0.i1252 = select i1 %_16.i1250, i64 %_17.i1251, i64 %res.sroa.0.0.i1249
  %_17.i238 = mul nuw i128 %_12.i229, %_14.i232
  %x_lo.i1221 = trunc i128 %_17.i238 to i64
  %_4.i1222 = lshr i128 %_17.i238, 64
  %x_hi.i1223 = trunc nuw i128 %_4.i1222 to i64
  %x_hi_hi.i1224 = lshr i64 %x_hi.i1223, 32
  %x_hi_lo.i1225 = and i64 %x_hi.i1223, 4294967295
  %_9.0.i1226 = sub i64 %x_lo.i1221, %x_hi_hi.i1224
  %_9.1.i1227 = icmp ugt i64 %x_hi_hi.i1224, %x_lo.i1221
  %_10.i1228 = add i64 %_9.0.i1226, -4294967295
  %spec.select.i1229 = select i1 %_9.1.i1227, i64 %_10.i1228, i64 %_9.0.i1226
  %t1.i1230 = mul nuw i64 %x_hi_lo.i1225, 4294967295
  %_14.0.i1231 = add i64 %spec.select.i1229, %t1.i1230
  %_14.1.i1232 = icmp ult i64 %_14.0.i1231, %spec.select.i1229
  %155 = add i64 %_14.0.i1231, 4294967295
  %res.sroa.0.0.i1233 = select i1 %_14.1.i1232, i64 %155, i64 %_14.0.i1231
  %_16.i1234 = icmp ugt i64 %res.sroa.0.0.i1233, -4294967296
  %_17.i1235 = add nsw i64 %res.sroa.0.0.i1233, 4294967295
  %_0.sroa.0.0.i1236 = select i1 %_16.i1234, i64 %_17.i1235, i64 %res.sroa.0.0.i1233
  %_19.i240 = zext i64 %_0.sroa.0.0.i1268 to i128
  %_18.i241 = mul nuw nsw i128 %_19.i240, 7
  %x_lo.i1205 = trunc i128 %_18.i241 to i64
  %_4.i1206 = lshr i128 %_18.i241, 64
  %x_hi.i1207 = trunc nuw nsw i128 %_4.i1206 to i64
  %t1.i1214 = mul nuw nsw i64 %x_hi.i1207, 4294967295
  %_14.0.i1215 = add i64 %t1.i1214, %x_lo.i1205
  %_14.1.i1216 = icmp ult i64 %_14.0.i1215, %x_lo.i1205
  %156 = add i64 %_14.0.i1215, 4294967295
  %res.sroa.0.0.i1217 = select i1 %_14.1.i1216, i64 %156, i64 %_14.0.i1215
  %_16.i1218 = icmp ugt i64 %res.sroa.0.0.i1217, -4294967296
  %_17.i1219 = add nsw i64 %res.sroa.0.0.i1217, 4294967295
  %_0.sroa.0.0.i1220 = select i1 %_16.i1218, i64 %_17.i1219, i64 %res.sroa.0.0.i1217
  %_22.0.i243 = add i64 %_0.sroa.0.0.i1220, %_0.sroa.0.0.i1284
  %_22.1.i244 = icmp ult i64 %_22.0.i243, %_0.sroa.0.0.i1284
  %157 = add nuw i64 %_22.0.i243, 4294967295
  %_24.sroa.0.0.i245 = select i1 %_22.1.i244, i64 %157, i64 %_22.0.i243
  %_25.i246 = icmp ugt i64 %_24.sroa.0.0.i245, -4294967296
  %_26.i247 = add nsw i64 %_24.sroa.0.0.i245, 4294967295
  %_7.sroa.0.0.i248 = select i1 %_25.i246, i64 %_26.i247, i64 %_24.sroa.0.0.i245
  %_29.0.i249 = add i64 %_0.sroa.0.0.i1252, %_0.sroa.0.0.i1236
  %_29.1.i250 = icmp ult i64 %_29.0.i249, %_0.sroa.0.0.i1252
  %158 = add nuw i64 %_29.0.i249, 4294967295
  %_30.sroa.0.0.i251 = select i1 %_29.1.i250, i64 %158, i64 %_29.0.i249
  %_31.i252 = icmp ugt i64 %_30.sroa.0.0.i251, -4294967296
  %_32.i253 = add nsw i64 %_30.sroa.0.0.i251, 4294967295
  %_9.sroa.0.0.i254 = select i1 %_31.i252, i64 %_32.i253, i64 %_30.sroa.0.0.i251
  %_11.i201 = zext i64 %_7.sroa.0.0.i248 to i128
  %_10.i203 = mul nuw i128 %_11.i201, %_11.i363
  %x_lo.i1349 = trunc i128 %_10.i203 to i64
  %_4.i1350 = lshr i128 %_10.i203, 64
  %x_hi.i1351 = trunc nuw i128 %_4.i1350 to i64
  %x_hi_hi.i1352 = lshr i64 %x_hi.i1351, 32
  %x_hi_lo.i1353 = and i64 %x_hi.i1351, 4294967295
  %_9.0.i1354 = sub i64 %x_lo.i1349, %x_hi_hi.i1352
  %_9.1.i1355 = icmp ugt i64 %x_hi_hi.i1352, %x_lo.i1349
  %_10.i1356 = add i64 %_9.0.i1354, -4294967295
  %spec.select.i1357 = select i1 %_9.1.i1355, i64 %_10.i1356, i64 %_9.0.i1354
  %t1.i1358 = mul nuw i64 %x_hi_lo.i1353, 4294967295
  %_14.0.i1359 = add i64 %spec.select.i1357, %t1.i1358
  %_14.1.i1360 = icmp ult i64 %_14.0.i1359, %spec.select.i1357
  %159 = add i64 %_14.0.i1359, 4294967295
  %res.sroa.0.0.i1361 = select i1 %_14.1.i1360, i64 %159, i64 %_14.0.i1359
  %_16.i1362 = icmp ugt i64 %res.sroa.0.0.i1361, -4294967296
  %_17.i1363 = add nsw i64 %res.sroa.0.0.i1361, 4294967295
  %_0.sroa.0.0.i1364 = select i1 %_16.i1362, i64 %_17.i1363, i64 %res.sroa.0.0.i1361
  %_14.i205 = zext i64 %_9.sroa.0.0.i254 to i128
  %_13.i207 = mul nuw i128 %_14.i205, %_14.i367
  %x_lo.i1333 = trunc i128 %_13.i207 to i64
  %_4.i1334 = lshr i128 %_13.i207, 64
  %x_hi.i1335 = trunc nuw i128 %_4.i1334 to i64
  %x_hi_hi.i1336 = lshr i64 %x_hi.i1335, 32
  %x_hi_lo.i1337 = and i64 %x_hi.i1335, 4294967295
  %_9.0.i1338 = sub i64 %x_lo.i1333, %x_hi_hi.i1336
  %_9.1.i1339 = icmp ugt i64 %x_hi_hi.i1336, %x_lo.i1333
  %_10.i1340 = add i64 %_9.0.i1338, -4294967295
  %spec.select.i1341 = select i1 %_9.1.i1339, i64 %_10.i1340, i64 %_9.0.i1338
  %t1.i1342 = mul nuw i64 %x_hi_lo.i1337, 4294967295
  %_14.0.i1343 = add i64 %spec.select.i1341, %t1.i1342
  %_14.1.i1344 = icmp ult i64 %_14.0.i1343, %spec.select.i1341
  %160 = add i64 %_14.0.i1343, 4294967295
  %res.sroa.0.0.i1345 = select i1 %_14.1.i1344, i64 %160, i64 %_14.0.i1343
  %_16.i1346 = icmp ugt i64 %res.sroa.0.0.i1345, -4294967296
  %_17.i1347 = add nsw i64 %res.sroa.0.0.i1345, 4294967295
  %_0.sroa.0.0.i1348 = select i1 %_16.i1346, i64 %_17.i1347, i64 %res.sroa.0.0.i1345
  %_16.i209 = mul nuw i128 %_11.i201, %_14.i367
  %x_lo.i1317 = trunc i128 %_16.i209 to i64
  %_4.i1318 = lshr i128 %_16.i209, 64
  %x_hi.i1319 = trunc nuw i128 %_4.i1318 to i64
  %x_hi_hi.i1320 = lshr i64 %x_hi.i1319, 32
  %x_hi_lo.i1321 = and i64 %x_hi.i1319, 4294967295
  %_9.0.i1322 = sub i64 %x_lo.i1317, %x_hi_hi.i1320
  %_9.1.i1323 = icmp ugt i64 %x_hi_hi.i1320, %x_lo.i1317
  %_10.i1324 = add i64 %_9.0.i1322, -4294967295
  %spec.select.i1325 = select i1 %_9.1.i1323, i64 %_10.i1324, i64 %_9.0.i1322
  %t1.i1326 = mul nuw i64 %x_hi_lo.i1321, 4294967295
  %_14.0.i1327 = add i64 %spec.select.i1325, %t1.i1326
  %_14.1.i1328 = icmp ult i64 %_14.0.i1327, %spec.select.i1325
  %161 = add i64 %_14.0.i1327, 4294967295
  %res.sroa.0.0.i1329 = select i1 %_14.1.i1328, i64 %161, i64 %_14.0.i1327
  %_16.i1330 = icmp ugt i64 %res.sroa.0.0.i1329, -4294967296
  %_17.i1331 = add nsw i64 %res.sroa.0.0.i1329, 4294967295
  %_0.sroa.0.0.i1332 = select i1 %_16.i1330, i64 %_17.i1331, i64 %res.sroa.0.0.i1329
  %_17.i211 = mul nuw i128 %_14.i205, %_11.i363
  %x_lo.i1301 = trunc i128 %_17.i211 to i64
  %_4.i1302 = lshr i128 %_17.i211, 64
  %x_hi.i1303 = trunc nuw i128 %_4.i1302 to i64
  %x_hi_hi.i1304 = lshr i64 %x_hi.i1303, 32
  %x_hi_lo.i1305 = and i64 %x_hi.i1303, 4294967295
  %_9.0.i1306 = sub i64 %x_lo.i1301, %x_hi_hi.i1304
  %_9.1.i1307 = icmp ugt i64 %x_hi_hi.i1304, %x_lo.i1301
  %_10.i1308 = add i64 %_9.0.i1306, -4294967295
  %spec.select.i1309 = select i1 %_9.1.i1307, i64 %_10.i1308, i64 %_9.0.i1306
  %t1.i1310 = mul nuw i64 %x_hi_lo.i1305, 4294967295
  %_14.0.i1311 = add i64 %spec.select.i1309, %t1.i1310
  %_14.1.i1312 = icmp ult i64 %_14.0.i1311, %spec.select.i1309
  %162 = add i64 %_14.0.i1311, 4294967295
  %res.sroa.0.0.i1313 = select i1 %_14.1.i1312, i64 %162, i64 %_14.0.i1311
  %_16.i1314 = icmp ugt i64 %res.sroa.0.0.i1313, -4294967296
  %_17.i1315 = add nsw i64 %res.sroa.0.0.i1313, 4294967295
  %_0.sroa.0.0.i1316 = select i1 %_16.i1314, i64 %_17.i1315, i64 %res.sroa.0.0.i1313
  %_19.i213 = zext i64 %_0.sroa.0.0.i1348 to i128
  %_18.i214 = mul nuw nsw i128 %_19.i213, 7
  %x_lo.i1285 = trunc i128 %_18.i214 to i64
  %_4.i1286 = lshr i128 %_18.i214, 64
  %x_hi.i1287 = trunc nuw nsw i128 %_4.i1286 to i64
  %t1.i1294 = mul nuw nsw i64 %x_hi.i1287, 4294967295
  %_14.0.i1295 = add i64 %t1.i1294, %x_lo.i1285
  %_14.1.i1296 = icmp ult i64 %_14.0.i1295, %x_lo.i1285
  %163 = add i64 %_14.0.i1295, 4294967295
  %res.sroa.0.0.i1297 = select i1 %_14.1.i1296, i64 %163, i64 %_14.0.i1295
  %_16.i1298 = icmp ugt i64 %res.sroa.0.0.i1297, -4294967296
  %_17.i1299 = add nsw i64 %res.sroa.0.0.i1297, 4294967295
  %_0.sroa.0.0.i1300 = select i1 %_16.i1298, i64 %_17.i1299, i64 %res.sroa.0.0.i1297
  %_22.0.i216 = add i64 %_0.sroa.0.0.i1364, %_0.sroa.0.0.i1300
  %_22.1.i217 = icmp ult i64 %_22.0.i216, %_0.sroa.0.0.i1364
  %164 = add nuw i64 %_22.0.i216, 4294967295
  %_24.sroa.0.0.i218 = select i1 %_22.1.i217, i64 %164, i64 %_22.0.i216
  %_25.i219 = icmp ugt i64 %_24.sroa.0.0.i218, -4294967296
  %_26.i220 = add nsw i64 %_24.sroa.0.0.i218, 4294967295
  %_7.sroa.0.0.i221 = select i1 %_25.i219, i64 %_26.i220, i64 %_24.sroa.0.0.i218
  %_29.0.i222 = add i64 %_0.sroa.0.0.i1332, %_0.sroa.0.0.i1316
  %_29.1.i223 = icmp ult i64 %_29.0.i222, %_0.sroa.0.0.i1332
  %165 = add nuw i64 %_29.0.i222, 4294967295
  %_30.sroa.0.0.i224 = select i1 %_29.1.i223, i64 %165, i64 %_29.0.i222
  %_31.i225 = icmp ugt i64 %_30.sroa.0.0.i224, -4294967296
  %_32.i226 = add nsw i64 %_30.sroa.0.0.i224, 4294967295
  %_9.sroa.0.0.i227 = select i1 %_31.i225, i64 %_32.i226, i64 %_30.sroa.0.0.i224
  %_11.i179 = zext i64 %_7.sroa.0.0.i221 to i128
  %_10.i181 = mul nuw i128 %_11.i179, %_12.i472
  %x_lo.i1429 = trunc i128 %_10.i181 to i64
  %_4.i1430 = lshr i128 %_10.i181, 64
  %x_hi.i1431 = trunc nuw i128 %_4.i1430 to i64
  %x_hi_hi.i1432 = lshr i64 %x_hi.i1431, 32
  %x_hi_lo.i1433 = and i64 %x_hi.i1431, 4294967295
  %_9.0.i1434 = sub i64 %x_lo.i1429, %x_hi_hi.i1432
  %_9.1.i1435 = icmp ugt i64 %x_hi_hi.i1432, %x_lo.i1429
  %_10.i1436 = add i64 %_9.0.i1434, -4294967295
  %spec.select.i1437 = select i1 %_9.1.i1435, i64 %_10.i1436, i64 %_9.0.i1434
  %t1.i1438 = mul nuw i64 %x_hi_lo.i1433, 4294967295
  %_14.0.i1439 = add i64 %spec.select.i1437, %t1.i1438
  %_14.1.i1440 = icmp ult i64 %_14.0.i1439, %spec.select.i1437
  %166 = add i64 %_14.0.i1439, 4294967295
  %res.sroa.0.0.i1441 = select i1 %_14.1.i1440, i64 %166, i64 %_14.0.i1439
  %_16.i1442 = icmp ugt i64 %res.sroa.0.0.i1441, -4294967296
  %_17.i1443 = add nsw i64 %res.sroa.0.0.i1441, 4294967295
  %_0.sroa.0.0.i1444 = select i1 %_16.i1442, i64 %_17.i1443, i64 %res.sroa.0.0.i1441
  %_14.i182 = zext i64 %_9.sroa.0.0.i227 to i128
  %_13.i184 = mul nuw i128 %_14.i182, %_15.i476
  %x_lo.i1413 = trunc i128 %_13.i184 to i64
  %_4.i1414 = lshr i128 %_13.i184, 64
  %x_hi.i1415 = trunc nuw i128 %_4.i1414 to i64
  %x_hi_hi.i1416 = lshr i64 %x_hi.i1415, 32
  %x_hi_lo.i1417 = and i64 %x_hi.i1415, 4294967295
  %_9.0.i1418 = sub i64 %x_lo.i1413, %x_hi_hi.i1416
  %_9.1.i1419 = icmp ugt i64 %x_hi_hi.i1416, %x_lo.i1413
  %_10.i1420 = add i64 %_9.0.i1418, -4294967295
  %spec.select.i1421 = select i1 %_9.1.i1419, i64 %_10.i1420, i64 %_9.0.i1418
  %t1.i1422 = mul nuw i64 %x_hi_lo.i1417, 4294967295
  %_14.0.i1423 = add i64 %spec.select.i1421, %t1.i1422
  %_14.1.i1424 = icmp ult i64 %_14.0.i1423, %spec.select.i1421
  %167 = add i64 %_14.0.i1423, 4294967295
  %res.sroa.0.0.i1425 = select i1 %_14.1.i1424, i64 %167, i64 %_14.0.i1423
  %_16.i1426 = icmp ugt i64 %res.sroa.0.0.i1425, -4294967296
  %_17.i1427 = add nsw i64 %res.sroa.0.0.i1425, 4294967295
  %_0.sroa.0.0.i1428 = select i1 %_16.i1426, i64 %_17.i1427, i64 %res.sroa.0.0.i1425
  %_16.i185 = mul nuw i128 %_11.i179, %_15.i476
  %x_lo.i1397 = trunc i128 %_16.i185 to i64
  %_4.i1398 = lshr i128 %_16.i185, 64
  %x_hi.i1399 = trunc nuw i128 %_4.i1398 to i64
  %x_hi_hi.i1400 = lshr i64 %x_hi.i1399, 32
  %x_hi_lo.i1401 = and i64 %x_hi.i1399, 4294967295
  %_9.0.i1402 = sub i64 %x_lo.i1397, %x_hi_hi.i1400
  %_9.1.i1403 = icmp ugt i64 %x_hi_hi.i1400, %x_lo.i1397
  %_10.i1404 = add i64 %_9.0.i1402, -4294967295
  %spec.select.i1405 = select i1 %_9.1.i1403, i64 %_10.i1404, i64 %_9.0.i1402
  %t1.i1406 = mul nuw i64 %x_hi_lo.i1401, 4294967295
  %_14.0.i1407 = add i64 %spec.select.i1405, %t1.i1406
  %_14.1.i1408 = icmp ult i64 %_14.0.i1407, %spec.select.i1405
  %168 = add i64 %_14.0.i1407, 4294967295
  %res.sroa.0.0.i1409 = select i1 %_14.1.i1408, i64 %168, i64 %_14.0.i1407
  %_16.i1410 = icmp ugt i64 %res.sroa.0.0.i1409, -4294967296
  %_17.i1411 = add nsw i64 %res.sroa.0.0.i1409, 4294967295
  %_0.sroa.0.0.i1412 = select i1 %_16.i1410, i64 %_17.i1411, i64 %res.sroa.0.0.i1409
  %_17.i186 = mul nuw i128 %_14.i182, %_12.i472
  %x_lo.i1381 = trunc i128 %_17.i186 to i64
  %_4.i1382 = lshr i128 %_17.i186, 64
  %x_hi.i1383 = trunc nuw i128 %_4.i1382 to i64
  %x_hi_hi.i1384 = lshr i64 %x_hi.i1383, 32
  %x_hi_lo.i1385 = and i64 %x_hi.i1383, 4294967295
  %_9.0.i1386 = sub i64 %x_lo.i1381, %x_hi_hi.i1384
  %_9.1.i1387 = icmp ugt i64 %x_hi_hi.i1384, %x_lo.i1381
  %_10.i1388 = add i64 %_9.0.i1386, -4294967295
  %spec.select.i1389 = select i1 %_9.1.i1387, i64 %_10.i1388, i64 %_9.0.i1386
  %t1.i1390 = mul nuw i64 %x_hi_lo.i1385, 4294967295
  %_14.0.i1391 = add i64 %spec.select.i1389, %t1.i1390
  %_14.1.i1392 = icmp ult i64 %_14.0.i1391, %spec.select.i1389
  %169 = add i64 %_14.0.i1391, 4294967295
  %res.sroa.0.0.i1393 = select i1 %_14.1.i1392, i64 %169, i64 %_14.0.i1391
  %_16.i1394 = icmp ugt i64 %res.sroa.0.0.i1393, -4294967296
  %_17.i1395 = add nsw i64 %res.sroa.0.0.i1393, 4294967295
  %_0.sroa.0.0.i1396 = select i1 %_16.i1394, i64 %_17.i1395, i64 %res.sroa.0.0.i1393
  %_19.i187 = zext i64 %_0.sroa.0.0.i1428 to i128
  %_18.i188 = mul nuw nsw i128 %_19.i187, 7
  %x_lo.i1365 = trunc i128 %_18.i188 to i64
  %_4.i1366 = lshr i128 %_18.i188, 64
  %x_hi.i1367 = trunc nuw nsw i128 %_4.i1366 to i64
  %t1.i1374 = mul nuw nsw i64 %x_hi.i1367, 4294967295
  %_14.0.i1375 = add i64 %t1.i1374, %x_lo.i1365
  %_14.1.i1376 = icmp ult i64 %_14.0.i1375, %x_lo.i1365
  %170 = add i64 %_14.0.i1375, 4294967295
  %res.sroa.0.0.i1377 = select i1 %_14.1.i1376, i64 %170, i64 %_14.0.i1375
  %_16.i1378 = icmp ugt i64 %res.sroa.0.0.i1377, -4294967296
  %_17.i1379 = add nsw i64 %res.sroa.0.0.i1377, 4294967295
  %_0.sroa.0.0.i1380 = select i1 %_16.i1378, i64 %_17.i1379, i64 %res.sroa.0.0.i1377
  %_22.0.i189 = add i64 %_0.sroa.0.0.i1380, %_0.sroa.0.0.i1444
  %_22.1.i190 = icmp ult i64 %_22.0.i189, %_0.sroa.0.0.i1444
  %171 = add nuw i64 %_22.0.i189, 4294967295
  %_24.sroa.0.0.i191 = select i1 %_22.1.i190, i64 %171, i64 %_22.0.i189
  %_25.i192 = icmp ugt i64 %_24.sroa.0.0.i191, -4294967296
  %_26.i193 = add nsw i64 %_24.sroa.0.0.i191, 4294967295
  %_7.sroa.0.0.i194 = select i1 %_25.i192, i64 %_26.i193, i64 %_24.sroa.0.0.i191
  %_29.0.i195 = add i64 %_0.sroa.0.0.i1412, %_0.sroa.0.0.i1396
  %_29.1.i196 = icmp ult i64 %_29.0.i195, %_0.sroa.0.0.i1412
  %172 = add nuw i64 %_29.0.i195, 4294967295
  %_30.sroa.0.0.i197 = select i1 %_29.1.i196, i64 %172, i64 %_29.0.i195
  %_31.i198 = icmp ugt i64 %_30.sroa.0.0.i197, -4294967296
  %_32.i199 = add nsw i64 %_30.sroa.0.0.i197, 4294967295
  %_9.sroa.0.0.i200 = select i1 %_31.i198, i64 %_32.i199, i64 %_30.sroa.0.0.i197
  %_7.0.i27 = add i64 %_7.sroa.0.0.i194, %_3.sroa.0.0.i44
  %_7.1.i28 = icmp ult i64 %_7.0.i27, %_3.sroa.0.0.i44
  %173 = add i64 %_7.0.i27, 4294967295
  %_8.sroa.0.0.i29 = select i1 %_7.1.i28, i64 %173, i64 %_7.0.i27
  %_9.i30 = icmp ugt i64 %_8.sroa.0.0.i29, -4294967296
  %_10.i31 = add nsw i64 %_8.sroa.0.0.i29, 4294967295
  %_3.sroa.0.0.i32 = select i1 %_9.i30, i64 %_10.i31, i64 %_8.sroa.0.0.i29
  %_13.0.i33 = add i64 %_9.sroa.0.0.i200, %_4.sroa.0.0.i50
  %_13.1.i34 = icmp ult i64 %_13.0.i33, %_4.sroa.0.0.i50
  %174 = add i64 %_13.0.i33, 4294967295
  %_14.sroa.0.0.i35 = select i1 %_13.1.i34, i64 %174, i64 %_13.0.i33
  %_15.i36 = icmp ugt i64 %_14.sroa.0.0.i35, -4294967296
  %_16.i37 = add nsw i64 %_14.sroa.0.0.i35, 4294967295
  %_4.sroa.0.0.i38 = select i1 %_15.i36, i64 %_16.i37, i64 %_14.sroa.0.0.i35
  %175 = insertvalue { i64, i64 } poison, i64 %_3.sroa.0.0.i32, 0
  %176 = insertvalue { i64, i64 } %175, i64 %_4.sroa.0.0.i38, 1
  call void @llvm.lifetime.end.p0(ptr nonnull %at)
  ret { i64, i64 } %176

panic17:                                          ; preds = %bb106
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 2, i64 noundef 2, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_e7192de98d175da682c169f6595d4522) #21
  unreachable

bb25:                                             ; preds = %bb9.i
  %_16.i.i = getelementptr inbounds nuw i8, ptr %ptr.i.i15961611, i64 16
  %_11.i.i.i = add nuw nsw i64 %_10.i.i.i15981610, 1
  %self3.i.i.i = getelementptr inbounds nuw %"core::mem::maybe_uninit::MaybeUninit<field::Fp2>", ptr %_55.sroa.5.0.iter.sroa_idx, i64 %_10.i.i.i15981610
  %_14.0.i.i.i = load i64, ptr %self3.i.i.i, align 8, !alias.scope !91, !noalias !98, !noundef !3
  %177 = getelementptr inbounds nuw i8, ptr %self3.i.i.i, i64 8
  %_14.1.i.i.i = load i64, ptr %177, align 8, !alias.scope !91, !noalias !98, !noundef !3
  %_66.0 = load i64, ptr %ptr.i.i15961611, align 8, !noundef !3
  %178 = getelementptr inbounds nuw i8, ptr %ptr.i.i15961611, i64 8
  %_66.1 = load i64, ptr %178, align 8, !noundef !3
  %_11.i = zext i64 %_66.0 to i128
  %_12.i = zext i64 %_14.0.i.i.i to i128
  %_10.i171 = mul nuw i128 %_11.i, %_12.i
  %x_lo.i1509 = trunc i128 %_10.i171 to i64
  %_4.i1510 = lshr i128 %_10.i171, 64
  %x_hi.i1511 = trunc nuw i128 %_4.i1510 to i64
  %x_hi_hi.i1512 = lshr i64 %x_hi.i1511, 32
  %x_hi_lo.i1513 = and i64 %x_hi.i1511, 4294967295
  %_9.0.i1514 = sub i64 %x_lo.i1509, %x_hi_hi.i1512
  %_9.1.i1515 = icmp ugt i64 %x_hi_hi.i1512, %x_lo.i1509
  %_10.i1516 = add i64 %_9.0.i1514, -4294967295
  %spec.select.i1517 = select i1 %_9.1.i1515, i64 %_10.i1516, i64 %_9.0.i1514
  %t1.i1518 = mul nuw i64 %x_hi_lo.i1513, 4294967295
  %_14.0.i1519 = add i64 %spec.select.i1517, %t1.i1518
  %_14.1.i1520 = icmp ult i64 %_14.0.i1519, %spec.select.i1517
  %179 = add i64 %_14.0.i1519, 4294967295
  %res.sroa.0.0.i1521 = select i1 %_14.1.i1520, i64 %179, i64 %_14.0.i1519
  %_16.i1522 = icmp ugt i64 %res.sroa.0.0.i1521, -4294967296
  %_17.i1523 = add nsw i64 %res.sroa.0.0.i1521, 4294967295
  %_0.sroa.0.0.i1524 = select i1 %_16.i1522, i64 %_17.i1523, i64 %res.sroa.0.0.i1521
  %_14.i = zext i64 %_66.1 to i128
  %_15.i172 = zext i64 %_14.1.i.i.i to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i172
  %x_lo.i1493 = trunc i128 %_13.i to i64
  %_4.i1494 = lshr i128 %_13.i, 64
  %x_hi.i1495 = trunc nuw i128 %_4.i1494 to i64
  %x_hi_hi.i1496 = lshr i64 %x_hi.i1495, 32
  %x_hi_lo.i1497 = and i64 %x_hi.i1495, 4294967295
  %_9.0.i1498 = sub i64 %x_lo.i1493, %x_hi_hi.i1496
  %_9.1.i1499 = icmp ugt i64 %x_hi_hi.i1496, %x_lo.i1493
  %_10.i1500 = add i64 %_9.0.i1498, -4294967295
  %spec.select.i1501 = select i1 %_9.1.i1499, i64 %_10.i1500, i64 %_9.0.i1498
  %t1.i1502 = mul nuw i64 %x_hi_lo.i1497, 4294967295
  %_14.0.i1503 = add i64 %spec.select.i1501, %t1.i1502
  %_14.1.i1504 = icmp ult i64 %_14.0.i1503, %spec.select.i1501
  %180 = add i64 %_14.0.i1503, 4294967295
  %res.sroa.0.0.i1505 = select i1 %_14.1.i1504, i64 %180, i64 %_14.0.i1503
  %_16.i1506 = icmp ugt i64 %res.sroa.0.0.i1505, -4294967296
  %_17.i1507 = add nsw i64 %res.sroa.0.0.i1505, 4294967295
  %_0.sroa.0.0.i1508 = select i1 %_16.i1506, i64 %_17.i1507, i64 %res.sroa.0.0.i1505
  %_16.i173 = mul nuw i128 %_11.i, %_15.i172
  %x_lo.i1477 = trunc i128 %_16.i173 to i64
  %_4.i1478 = lshr i128 %_16.i173, 64
  %x_hi.i1479 = trunc nuw i128 %_4.i1478 to i64
  %x_hi_hi.i1480 = lshr i64 %x_hi.i1479, 32
  %x_hi_lo.i1481 = and i64 %x_hi.i1479, 4294967295
  %_9.0.i1482 = sub i64 %x_lo.i1477, %x_hi_hi.i1480
  %_9.1.i1483 = icmp ugt i64 %x_hi_hi.i1480, %x_lo.i1477
  %_10.i1484 = add i64 %_9.0.i1482, -4294967295
  %spec.select.i1485 = select i1 %_9.1.i1483, i64 %_10.i1484, i64 %_9.0.i1482
  %t1.i1486 = mul nuw i64 %x_hi_lo.i1481, 4294967295
  %_14.0.i1487 = add i64 %spec.select.i1485, %t1.i1486
  %_14.1.i1488 = icmp ult i64 %_14.0.i1487, %spec.select.i1485
  %181 = add i64 %_14.0.i1487, 4294967295
  %res.sroa.0.0.i1489 = select i1 %_14.1.i1488, i64 %181, i64 %_14.0.i1487
  %_16.i1490 = icmp ugt i64 %res.sroa.0.0.i1489, -4294967296
  %_17.i1491 = add nsw i64 %res.sroa.0.0.i1489, 4294967295
  %_0.sroa.0.0.i1492 = select i1 %_16.i1490, i64 %_17.i1491, i64 %res.sroa.0.0.i1489
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i1461 = trunc i128 %_17.i to i64
  %_4.i1462 = lshr i128 %_17.i, 64
  %x_hi.i1463 = trunc nuw i128 %_4.i1462 to i64
  %x_hi_hi.i1464 = lshr i64 %x_hi.i1463, 32
  %x_hi_lo.i1465 = and i64 %x_hi.i1463, 4294967295
  %_9.0.i1466 = sub i64 %x_lo.i1461, %x_hi_hi.i1464
  %_9.1.i1467 = icmp ugt i64 %x_hi_hi.i1464, %x_lo.i1461
  %_10.i1468 = add i64 %_9.0.i1466, -4294967295
  %spec.select.i1469 = select i1 %_9.1.i1467, i64 %_10.i1468, i64 %_9.0.i1466
  %t1.i1470 = mul nuw i64 %x_hi_lo.i1465, 4294967295
  %_14.0.i1471 = add i64 %spec.select.i1469, %t1.i1470
  %_14.1.i1472 = icmp ult i64 %_14.0.i1471, %spec.select.i1469
  %182 = add i64 %_14.0.i1471, 4294967295
  %res.sroa.0.0.i1473 = select i1 %_14.1.i1472, i64 %182, i64 %_14.0.i1471
  %_16.i1474 = icmp ugt i64 %res.sroa.0.0.i1473, -4294967296
  %_17.i1475 = add nsw i64 %res.sroa.0.0.i1473, 4294967295
  %_0.sroa.0.0.i1476 = select i1 %_16.i1474, i64 %_17.i1475, i64 %res.sroa.0.0.i1473
  %_19.i = zext i64 %_0.sroa.0.0.i1508 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i1445 = trunc i128 %_18.i to i64
  %_4.i1446 = lshr i128 %_18.i, 64
  %x_hi.i1447 = trunc nuw nsw i128 %_4.i1446 to i64
  %t1.i1454 = mul nuw nsw i64 %x_hi.i1447, 4294967295
  %_14.0.i1455 = add i64 %t1.i1454, %x_lo.i1445
  %_14.1.i1456 = icmp ult i64 %_14.0.i1455, %x_lo.i1445
  %183 = add i64 %_14.0.i1455, 4294967295
  %res.sroa.0.0.i1457 = select i1 %_14.1.i1456, i64 %183, i64 %_14.0.i1455
  %_16.i1458 = icmp ugt i64 %res.sroa.0.0.i1457, -4294967296
  %_17.i1459 = add nsw i64 %res.sroa.0.0.i1457, 4294967295
  %_0.sroa.0.0.i1460 = select i1 %_16.i1458, i64 %_17.i1459, i64 %res.sroa.0.0.i1457
  %_22.0.i = add i64 %_0.sroa.0.0.i1460, %_0.sroa.0.0.i1524
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i1524
  %184 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %184, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i1476, %_0.sroa.0.0.i1492
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i1492
  %185 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %185, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %clauses.sroa.0.01613
  %_7.1.i = icmp ult i64 %_7.0.i, %clauses.sroa.0.01613
  %186 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %186, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %clauses.sroa.4.01612
  %_13.1.i = icmp ult i64 %_13.0.i, %clauses.sroa.4.01612
  %187 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %187, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %_6.i.i = icmp eq ptr %_16.i.i, %_216
  br i1 %_6.i.i, label %bb23, label %bb9.i
}

; <isolated::factory_0::{closure#1} as core::ops::function::FnOnce<(&[isolated::field::Fp2],)>>::call_once::{shim:vtable#0}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_(ptr noundef nonnull captures(address, read_provenance) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
; invoke isolated::factory_0::{closure#1}
  %2 = invoke { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0B3_(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) dereferenceable(296) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1)
          to label %_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit unwind label %cleanup.i

cleanup.i:                                        ; preds = %start
  %3 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(296) %_1) #22
  resume { ptr, i32 } %3

_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit: ; preds = %start
; call core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(296) %_1)
  ret { i64, i64 } %2
}

; <isolated::factory_1::{closure#1} as core::ops::function::FnOnce<(&[isolated::field::Fp2],)>>::call_once::{shim:vtable#0}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_(ptr noundef nonnull captures(address, read_provenance) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
; invoke isolated::factory_1::{closure#1}
  %2 = invoke { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0B3_(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) dereferenceable(272) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1)
          to label %_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit unwind label %cleanup.i

cleanup.i:                                        ; preds = %start
  %3 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(272) %_1) #22
  resume { ptr, i32 } %3

_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit: ; preds = %start
; call core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(272) %_1)
  ret { i64, i64 } %2
}

; <isolated::factory_2::{closure#1} as core::ops::function::FnOnce<(&[isolated::field::Fp2],)>>::call_once::{shim:vtable#0}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_(ptr noundef nonnull captures(address, read_provenance) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
; invoke isolated::factory_2::{closure#1}
  %2 = invoke { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0B3_(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) dereferenceable(296) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1)
          to label %_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit unwind label %cleanup.i

cleanup.i:                                        ; preds = %start
  %3 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(296) %_1) #22
  resume { ptr, i32 } %3

_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit: ; preds = %start
; call core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(296) %_1)
  ret { i64, i64 } %2
}

; <isolated::factory_3::{closure#1} as core::ops::function::FnOnce<(&[isolated::field::Fp2],)>>::call_once::{shim:vtable#0}
; Function Attrs: inlinehint nonlazybind uwtable
define internal { i64, i64 } @_RNSNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB8_5field3Fp2EE9call_once6vtableB8_(ptr noundef nonnull captures(address, read_provenance) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1) unnamed_addr #2 personality ptr @rust_eh_personality {
start:
; invoke isolated::factory_3::{closure#1}
  %2 = invoke { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0B3_(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) dereferenceable(272) %_1, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef range(i64 0, 576460752303423488) %1)
          to label %_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit unwind label %cleanup.i

cleanup.i:                                        ; preds = %start
  %3 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(272) %_1) #22
  resume { ptr, i32 } %3

_RNvYNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0INtNtNtCscI6d9CVNmLh_4core3ops8function6FnOnceTRSNtNtB6_5field3Fp2EE9call_onceB6_.exit: ; preds = %start
; call core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
  tail call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(272) %_1)
  ret { i64, i64 } %2
}

; isolated::helper_sum
; Function Attrs: nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNvCsl0YfJI2rrfI_8isolated10helper_sum(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1, ptr noalias noundef nonnull readonly align 8 captures(none) %lks.0, i64 noundef range(i64 0, 230584300921369396) %lks.1, i64 noundef %h0, i64 noundef %0, i64 noundef %1, ptr noalias noundef nonnull readonly align 8 captures(none) %mu.0, i64 noundef range(i64 0, 576460752303423488) %mu.1) unnamed_addr #1 {
start:
  %den = alloca [24 x i8], align 8
  %alpha = alloca [16 x i8], align 8
  store i64 %0, ptr %alpha, align 8
  %2 = getelementptr inbounds nuw i8, ptr %alpha, i64 8
  store i64 %1, ptr %2, align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %den)
  store ptr %alpha, ptr %den, align 8
  %3 = getelementptr inbounds nuw i8, ptr %den, i64 8
  store ptr %v.0, ptr %3, align 8
  %4 = getelementptr inbounds nuw i8, ptr %den, i64 16
  store i64 %v.1, ptr %4, align 8
  %_41423.not = icmp eq i64 %lks.1, 0
  br i1 %_41423.not, label %bb18, label %bb17.preheader

bb17.preheader:                                   ; preds = %start
  %_387 = lshr i64 %lks.1, 1
  %iter.sroa.0.0 = sub nsw i64 %lks.1, %_387
  %5 = add nuw nsw i64 %lks.1, 1
  %6 = lshr i64 %5, 1
  %umax = call i64 @llvm.umax.i64(i64 %iter.sroa.0.0, i64 1)
  br label %bb17

bb18:                                             ; preds = %bb11, %start
  %acc.sroa.4.0.lcssa = phi i64 [ 0, %start ], [ %_4.sroa.0.0.i, %bb11 ]
  %acc.sroa.0.0.lcssa = phi i64 [ 0, %start ], [ %_3.sroa.0.0.i, %bb11 ]
  call void @llvm.lifetime.end.p0(ptr nonnull %den)
  %7 = insertvalue { i64, i64 } poison, i64 %acc.sroa.0.0.lcssa, 0
  %8 = insertvalue { i64, i64 } %7, i64 %acc.sroa.4.0.lcssa, 1
  ret { i64, i64 } %8

bb17:                                             ; preds = %bb17.preheader, %bb11
  %acc.sroa.0.0426 = phi i64 [ %_3.sroa.0.0.i, %bb11 ], [ 0, %bb17.preheader ]
  %acc.sroa.4.0425 = phi i64 [ %_4.sroa.0.0.i, %bb11 ], [ 0, %bb17.preheader ]
  %iter1.sroa.0.0424 = phi i64 [ %9, %bb11 ], [ 0, %bb17.preheader ]
  %9 = add nuw nsw i64 %iter1.sroa.0.0424, 1
  %_13 = add nuw nsw i64 %iter1.sroa.0.0424, %h0
  %_15 = icmp ult i64 %_13, %v.1
  br i1 %_15, label %bb2, label %panic

bb2:                                              ; preds = %bb17
  %10 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_13
  %h.0 = load i64, ptr %10, align 8, !noundef !3
  %11 = getelementptr inbounds nuw i8, ptr %10, i64 8
  %h.1 = load i64, ptr %11, align 8, !noundef !3
  %_20 = shl nuw nsw i64 %iter1.sroa.0.0424, 1
  %exitcond.not = icmp eq i64 %iter1.sroa.0.0424, %6
  br i1 %exitcond.not, label %panic2, label %bb3

panic:                                            ; preds = %bb17
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_13, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_10b6528b98bd905c6309b430b77c3a07) #21
  unreachable

bb3:                                              ; preds = %bb2
  %_19 = getelementptr inbounds nuw %LkT, ptr %lks.0, i64 %_20
; call isolated::helper_sum::{closure#0}
  %12 = call fastcc { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) %den, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(40) %_19)
  %d1.0 = extractvalue { i64, i64 } %12, 0
  %d1.1 = extractvalue { i64, i64 } %12, 1
  %_24 = or disjoint i64 %_20, 1
  %_45 = icmp samesign ult i64 %_24, %lks.1
  br i1 %_45, label %bb19, label %bb20

panic2:                                           ; preds = %bb2
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_20, i64 noundef %lks.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_976e0beddddec32ff42087070bcd77a5) #21
  unreachable

bb20:                                             ; preds = %bb3
  %_11.i77 = zext i64 %h.0 to i128
  %_12.i78 = zext i64 %d1.0 to i128
  %_10.i79 = mul nuw i128 %_12.i78, %_11.i77
  %x_lo.i155 = trunc i128 %_10.i79 to i64
  %_4.i156 = lshr i128 %_10.i79, 64
  %x_hi.i157 = trunc nuw i128 %_4.i156 to i64
  %x_hi_hi.i158 = lshr i64 %x_hi.i157, 32
  %x_hi_lo.i159 = and i64 %x_hi.i157, 4294967295
  %_9.0.i160 = sub i64 %x_lo.i155, %x_hi_hi.i158
  %_9.1.i161 = icmp ugt i64 %x_hi_hi.i158, %x_lo.i155
  %_10.i162 = add i64 %_9.0.i160, -4294967295
  %spec.select.i163 = select i1 %_9.1.i161, i64 %_10.i162, i64 %_9.0.i160
  %t1.i164 = mul nuw i64 %x_hi_lo.i159, 4294967295
  %_14.0.i165 = add i64 %spec.select.i163, %t1.i164
  %_14.1.i166 = icmp ult i64 %_14.0.i165, %spec.select.i163
  %13 = add i64 %_14.0.i165, 4294967295
  %res.sroa.0.0.i167 = select i1 %_14.1.i166, i64 %13, i64 %_14.0.i165
  %_16.i168 = icmp ugt i64 %res.sroa.0.0.i167, -4294967296
  %_17.i169 = add nsw i64 %res.sroa.0.0.i167, 4294967295
  %_0.sroa.0.0.i170 = select i1 %_16.i168, i64 %_17.i169, i64 %res.sroa.0.0.i167
  %_14.i81 = zext i64 %h.1 to i128
  %_15.i82 = zext i64 %d1.1 to i128
  %_13.i83 = mul nuw i128 %_15.i82, %_14.i81
  %x_lo.i139 = trunc i128 %_13.i83 to i64
  %_4.i140 = lshr i128 %_13.i83, 64
  %x_hi.i141 = trunc nuw i128 %_4.i140 to i64
  %x_hi_hi.i142 = lshr i64 %x_hi.i141, 32
  %x_hi_lo.i143 = and i64 %x_hi.i141, 4294967295
  %_9.0.i144 = sub i64 %x_lo.i139, %x_hi_hi.i142
  %_9.1.i145 = icmp ugt i64 %x_hi_hi.i142, %x_lo.i139
  %_10.i146 = add i64 %_9.0.i144, -4294967295
  %spec.select.i147 = select i1 %_9.1.i145, i64 %_10.i146, i64 %_9.0.i144
  %t1.i148 = mul nuw i64 %x_hi_lo.i143, 4294967295
  %_14.0.i149 = add i64 %spec.select.i147, %t1.i148
  %_14.1.i150 = icmp ult i64 %_14.0.i149, %spec.select.i147
  %14 = add i64 %_14.0.i149, 4294967295
  %res.sroa.0.0.i151 = select i1 %_14.1.i150, i64 %14, i64 %_14.0.i149
  %_16.i152 = icmp ugt i64 %res.sroa.0.0.i151, -4294967296
  %_17.i153 = add nsw i64 %res.sroa.0.0.i151, 4294967295
  %_0.sroa.0.0.i154 = select i1 %_16.i152, i64 %_17.i153, i64 %res.sroa.0.0.i151
  %_16.i85 = mul nuw i128 %_15.i82, %_11.i77
  %x_lo.i123 = trunc i128 %_16.i85 to i64
  %_4.i124 = lshr i128 %_16.i85, 64
  %x_hi.i125 = trunc nuw i128 %_4.i124 to i64
  %x_hi_hi.i126 = lshr i64 %x_hi.i125, 32
  %x_hi_lo.i127 = and i64 %x_hi.i125, 4294967295
  %_9.0.i128 = sub i64 %x_lo.i123, %x_hi_hi.i126
  %_9.1.i129 = icmp ugt i64 %x_hi_hi.i126, %x_lo.i123
  %_10.i130 = add i64 %_9.0.i128, -4294967295
  %spec.select.i131 = select i1 %_9.1.i129, i64 %_10.i130, i64 %_9.0.i128
  %t1.i132 = mul nuw i64 %x_hi_lo.i127, 4294967295
  %_14.0.i133 = add i64 %spec.select.i131, %t1.i132
  %_14.1.i134 = icmp ult i64 %_14.0.i133, %spec.select.i131
  %15 = add i64 %_14.0.i133, 4294967295
  %res.sroa.0.0.i135 = select i1 %_14.1.i134, i64 %15, i64 %_14.0.i133
  %_16.i136 = icmp ugt i64 %res.sroa.0.0.i135, -4294967296
  %_17.i137 = add nsw i64 %res.sroa.0.0.i135, 4294967295
  %_0.sroa.0.0.i138 = select i1 %_16.i136, i64 %_17.i137, i64 %res.sroa.0.0.i135
  %_17.i87 = mul nuw i128 %_12.i78, %_14.i81
  %x_lo.i107 = trunc i128 %_17.i87 to i64
  %_4.i108 = lshr i128 %_17.i87, 64
  %x_hi.i109 = trunc nuw i128 %_4.i108 to i64
  %x_hi_hi.i110 = lshr i64 %x_hi.i109, 32
  %x_hi_lo.i111 = and i64 %x_hi.i109, 4294967295
  %_9.0.i112 = sub i64 %x_lo.i107, %x_hi_hi.i110
  %_9.1.i113 = icmp ugt i64 %x_hi_hi.i110, %x_lo.i107
  %_10.i114 = add i64 %_9.0.i112, -4294967295
  %spec.select.i115 = select i1 %_9.1.i113, i64 %_10.i114, i64 %_9.0.i112
  %t1.i116 = mul nuw i64 %x_hi_lo.i111, 4294967295
  %_14.0.i117 = add i64 %spec.select.i115, %t1.i116
  %_14.1.i118 = icmp ult i64 %_14.0.i117, %spec.select.i115
  %16 = add i64 %_14.0.i117, 4294967295
  %res.sroa.0.0.i119 = select i1 %_14.1.i118, i64 %16, i64 %_14.0.i117
  %_16.i120 = icmp ugt i64 %res.sroa.0.0.i119, -4294967296
  %_17.i121 = add nsw i64 %res.sroa.0.0.i119, 4294967295
  %_0.sroa.0.0.i122 = select i1 %_16.i120, i64 %_17.i121, i64 %res.sroa.0.0.i119
  %_19.i89 = zext i64 %_0.sroa.0.0.i154 to i128
  %_18.i90 = mul nuw nsw i128 %_19.i89, 7
  %x_lo.i = trunc i128 %_18.i90 to i64
  %_4.i = lshr i128 %_18.i90, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %17 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %17, i64 %_14.0.i
  %_16.i105 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i106 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i105, i64 %_17.i106, i64 %res.sroa.0.0.i
  %_22.0.i92 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i170
  %_22.1.i93 = icmp ult i64 %_22.0.i92, %_0.sroa.0.0.i170
  %18 = add nuw i64 %_22.0.i92, 4294967295
  %_24.sroa.0.0.i94 = select i1 %_22.1.i93, i64 %18, i64 %_22.0.i92
  %_25.i95 = icmp ugt i64 %_24.sroa.0.0.i94, -4294967296
  %_26.i96 = add nsw i64 %_24.sroa.0.0.i94, 4294967295
  %_7.sroa.0.0.i97 = select i1 %_25.i95, i64 %_26.i96, i64 %_24.sroa.0.0.i94
  %_29.0.i98 = add i64 %_0.sroa.0.0.i138, %_0.sroa.0.0.i122
  %_29.1.i99 = icmp ult i64 %_29.0.i98, %_0.sroa.0.0.i138
  %19 = add nuw i64 %_29.0.i98, 4294967295
  %_30.sroa.0.0.i100 = select i1 %_29.1.i99, i64 %19, i64 %_29.0.i98
  %_31.i101 = icmp ugt i64 %_30.sroa.0.0.i100, -4294967296
  %_32.i102 = add nsw i64 %_30.sroa.0.0.i100, 4294967295
  %_9.sroa.0.0.i103 = select i1 %_31.i101, i64 %_32.i102, i64 %_30.sroa.0.0.i100
  %_65.1 = icmp eq i64 %_7.sroa.0.0.i97, 0
  %_65.0 = add i64 %_7.sroa.0.0.i97, -1
  %_66.sroa.0.0 = select i1 %_65.1, i64 -4294967296, i64 %_65.0
  br label %bb10

bb19:                                             ; preds = %bb3
  %_46 = getelementptr inbounds nuw %LkT, ptr %lks.0, i64 %_24
; call isolated::helper_sum::{closure#0}
  %20 = call fastcc { i64, i64 } @_RNCNvCsl0YfJI2rrfI_8isolated10helper_sum0B3_(ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) %den, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(40) %_46)
  %d2.0 = extractvalue { i64, i64 } %20, 0
  %d2.1 = extractvalue { i64, i64 } %20, 1
  %_11.i50 = zext i64 %h.0 to i128
  %_12.i51 = zext i64 %d1.0 to i128
  %_10.i52 = mul nuw i128 %_12.i51, %_11.i50
  %x_lo.i235 = trunc i128 %_10.i52 to i64
  %_4.i236 = lshr i128 %_10.i52, 64
  %x_hi.i237 = trunc nuw i128 %_4.i236 to i64
  %x_hi_hi.i238 = lshr i64 %x_hi.i237, 32
  %x_hi_lo.i239 = and i64 %x_hi.i237, 4294967295
  %_9.0.i240 = sub i64 %x_lo.i235, %x_hi_hi.i238
  %_9.1.i241 = icmp ugt i64 %x_hi_hi.i238, %x_lo.i235
  %_10.i242 = add i64 %_9.0.i240, -4294967295
  %spec.select.i243 = select i1 %_9.1.i241, i64 %_10.i242, i64 %_9.0.i240
  %t1.i244 = mul nuw i64 %x_hi_lo.i239, 4294967295
  %_14.0.i245 = add i64 %spec.select.i243, %t1.i244
  %_14.1.i246 = icmp ult i64 %_14.0.i245, %spec.select.i243
  %21 = add i64 %_14.0.i245, 4294967295
  %res.sroa.0.0.i247 = select i1 %_14.1.i246, i64 %21, i64 %_14.0.i245
  %_16.i248 = icmp ugt i64 %res.sroa.0.0.i247, -4294967296
  %_17.i249 = add nsw i64 %res.sroa.0.0.i247, 4294967295
  %_0.sroa.0.0.i250 = select i1 %_16.i248, i64 %_17.i249, i64 %res.sroa.0.0.i247
  %_14.i54 = zext i64 %h.1 to i128
  %_15.i55 = zext i64 %d1.1 to i128
  %_13.i56 = mul nuw i128 %_15.i55, %_14.i54
  %x_lo.i219 = trunc i128 %_13.i56 to i64
  %_4.i220 = lshr i128 %_13.i56, 64
  %x_hi.i221 = trunc nuw i128 %_4.i220 to i64
  %x_hi_hi.i222 = lshr i64 %x_hi.i221, 32
  %x_hi_lo.i223 = and i64 %x_hi.i221, 4294967295
  %_9.0.i224 = sub i64 %x_lo.i219, %x_hi_hi.i222
  %_9.1.i225 = icmp ugt i64 %x_hi_hi.i222, %x_lo.i219
  %_10.i226 = add i64 %_9.0.i224, -4294967295
  %spec.select.i227 = select i1 %_9.1.i225, i64 %_10.i226, i64 %_9.0.i224
  %t1.i228 = mul nuw i64 %x_hi_lo.i223, 4294967295
  %_14.0.i229 = add i64 %spec.select.i227, %t1.i228
  %_14.1.i230 = icmp ult i64 %_14.0.i229, %spec.select.i227
  %22 = add i64 %_14.0.i229, 4294967295
  %res.sroa.0.0.i231 = select i1 %_14.1.i230, i64 %22, i64 %_14.0.i229
  %_16.i232 = icmp ugt i64 %res.sroa.0.0.i231, -4294967296
  %_17.i233 = add nsw i64 %res.sroa.0.0.i231, 4294967295
  %_0.sroa.0.0.i234 = select i1 %_16.i232, i64 %_17.i233, i64 %res.sroa.0.0.i231
  %_16.i58 = mul nuw i128 %_15.i55, %_11.i50
  %x_lo.i203 = trunc i128 %_16.i58 to i64
  %_4.i204 = lshr i128 %_16.i58, 64
  %x_hi.i205 = trunc nuw i128 %_4.i204 to i64
  %x_hi_hi.i206 = lshr i64 %x_hi.i205, 32
  %x_hi_lo.i207 = and i64 %x_hi.i205, 4294967295
  %_9.0.i208 = sub i64 %x_lo.i203, %x_hi_hi.i206
  %_9.1.i209 = icmp ugt i64 %x_hi_hi.i206, %x_lo.i203
  %_10.i210 = add i64 %_9.0.i208, -4294967295
  %spec.select.i211 = select i1 %_9.1.i209, i64 %_10.i210, i64 %_9.0.i208
  %t1.i212 = mul nuw i64 %x_hi_lo.i207, 4294967295
  %_14.0.i213 = add i64 %spec.select.i211, %t1.i212
  %_14.1.i214 = icmp ult i64 %_14.0.i213, %spec.select.i211
  %23 = add i64 %_14.0.i213, 4294967295
  %res.sroa.0.0.i215 = select i1 %_14.1.i214, i64 %23, i64 %_14.0.i213
  %_16.i216 = icmp ugt i64 %res.sroa.0.0.i215, -4294967296
  %_17.i217 = add nsw i64 %res.sroa.0.0.i215, 4294967295
  %_0.sroa.0.0.i218 = select i1 %_16.i216, i64 %_17.i217, i64 %res.sroa.0.0.i215
  %_17.i60 = mul nuw i128 %_12.i51, %_14.i54
  %x_lo.i187 = trunc i128 %_17.i60 to i64
  %_4.i188 = lshr i128 %_17.i60, 64
  %x_hi.i189 = trunc nuw i128 %_4.i188 to i64
  %x_hi_hi.i190 = lshr i64 %x_hi.i189, 32
  %x_hi_lo.i191 = and i64 %x_hi.i189, 4294967295
  %_9.0.i192 = sub i64 %x_lo.i187, %x_hi_hi.i190
  %_9.1.i193 = icmp ugt i64 %x_hi_hi.i190, %x_lo.i187
  %_10.i194 = add i64 %_9.0.i192, -4294967295
  %spec.select.i195 = select i1 %_9.1.i193, i64 %_10.i194, i64 %_9.0.i192
  %t1.i196 = mul nuw i64 %x_hi_lo.i191, 4294967295
  %_14.0.i197 = add i64 %spec.select.i195, %t1.i196
  %_14.1.i198 = icmp ult i64 %_14.0.i197, %spec.select.i195
  %24 = add i64 %_14.0.i197, 4294967295
  %res.sroa.0.0.i199 = select i1 %_14.1.i198, i64 %24, i64 %_14.0.i197
  %_16.i200 = icmp ugt i64 %res.sroa.0.0.i199, -4294967296
  %_17.i201 = add nsw i64 %res.sroa.0.0.i199, 4294967295
  %_0.sroa.0.0.i202 = select i1 %_16.i200, i64 %_17.i201, i64 %res.sroa.0.0.i199
  %_19.i62 = zext i64 %_0.sroa.0.0.i234 to i128
  %_18.i63 = mul nuw nsw i128 %_19.i62, 7
  %x_lo.i171 = trunc i128 %_18.i63 to i64
  %_4.i172 = lshr i128 %_18.i63, 64
  %x_hi.i173 = trunc nuw nsw i128 %_4.i172 to i64
  %t1.i180 = mul nuw nsw i64 %x_hi.i173, 4294967295
  %_14.0.i181 = add i64 %t1.i180, %x_lo.i171
  %_14.1.i182 = icmp ult i64 %_14.0.i181, %x_lo.i171
  %25 = add i64 %_14.0.i181, 4294967295
  %res.sroa.0.0.i183 = select i1 %_14.1.i182, i64 %25, i64 %_14.0.i181
  %_16.i184 = icmp ugt i64 %res.sroa.0.0.i183, -4294967296
  %_17.i185 = add nsw i64 %res.sroa.0.0.i183, 4294967295
  %_0.sroa.0.0.i186 = select i1 %_16.i184, i64 %_17.i185, i64 %res.sroa.0.0.i183
  %_22.0.i65 = add i64 %_0.sroa.0.0.i186, %_0.sroa.0.0.i250
  %_22.1.i66 = icmp ult i64 %_22.0.i65, %_0.sroa.0.0.i250
  %26 = add nuw i64 %_22.0.i65, 4294967295
  %_24.sroa.0.0.i67 = select i1 %_22.1.i66, i64 %26, i64 %_22.0.i65
  %_25.i68 = icmp ugt i64 %_24.sroa.0.0.i67, -4294967296
  %_26.i69 = add nsw i64 %_24.sroa.0.0.i67, 4294967295
  %_7.sroa.0.0.i70 = select i1 %_25.i68, i64 %_26.i69, i64 %_24.sroa.0.0.i67
  %_29.0.i71 = add i64 %_0.sroa.0.0.i218, %_0.sroa.0.0.i202
  %_29.1.i72 = icmp ult i64 %_29.0.i71, %_0.sroa.0.0.i218
  %27 = add nuw i64 %_29.0.i71, 4294967295
  %_30.sroa.0.0.i73 = select i1 %_29.1.i72, i64 %27, i64 %_29.0.i71
  %_31.i74 = icmp ugt i64 %_30.sroa.0.0.i73, -4294967296
  %_32.i75 = add nsw i64 %_30.sroa.0.0.i73, 4294967295
  %_9.sroa.0.0.i76 = select i1 %_31.i74, i64 %_32.i75, i64 %_30.sroa.0.0.i73
  %_11.i23 = zext i64 %_7.sroa.0.0.i70 to i128
  %_12.i24 = zext i64 %d2.0 to i128
  %_10.i25 = mul nuw i128 %_12.i24, %_11.i23
  %x_lo.i315 = trunc i128 %_10.i25 to i64
  %_4.i316 = lshr i128 %_10.i25, 64
  %x_hi.i317 = trunc nuw i128 %_4.i316 to i64
  %x_hi_hi.i318 = lshr i64 %x_hi.i317, 32
  %x_hi_lo.i319 = and i64 %x_hi.i317, 4294967295
  %_9.0.i320 = sub i64 %x_lo.i315, %x_hi_hi.i318
  %_9.1.i321 = icmp ugt i64 %x_hi_hi.i318, %x_lo.i315
  %_10.i322 = add i64 %_9.0.i320, -4294967295
  %spec.select.i323 = select i1 %_9.1.i321, i64 %_10.i322, i64 %_9.0.i320
  %t1.i324 = mul nuw i64 %x_hi_lo.i319, 4294967295
  %_14.0.i325 = add i64 %spec.select.i323, %t1.i324
  %_14.1.i326 = icmp ult i64 %_14.0.i325, %spec.select.i323
  %28 = add i64 %_14.0.i325, 4294967295
  %res.sroa.0.0.i327 = select i1 %_14.1.i326, i64 %28, i64 %_14.0.i325
  %_16.i328 = icmp ugt i64 %res.sroa.0.0.i327, -4294967296
  %_17.i329 = add nsw i64 %res.sroa.0.0.i327, 4294967295
  %_0.sroa.0.0.i330 = select i1 %_16.i328, i64 %_17.i329, i64 %res.sroa.0.0.i327
  %_14.i27 = zext i64 %_9.sroa.0.0.i76 to i128
  %_15.i28 = zext i64 %d2.1 to i128
  %_13.i29 = mul nuw i128 %_15.i28, %_14.i27
  %x_lo.i299 = trunc i128 %_13.i29 to i64
  %_4.i300 = lshr i128 %_13.i29, 64
  %x_hi.i301 = trunc nuw i128 %_4.i300 to i64
  %x_hi_hi.i302 = lshr i64 %x_hi.i301, 32
  %x_hi_lo.i303 = and i64 %x_hi.i301, 4294967295
  %_9.0.i304 = sub i64 %x_lo.i299, %x_hi_hi.i302
  %_9.1.i305 = icmp ugt i64 %x_hi_hi.i302, %x_lo.i299
  %_10.i306 = add i64 %_9.0.i304, -4294967295
  %spec.select.i307 = select i1 %_9.1.i305, i64 %_10.i306, i64 %_9.0.i304
  %t1.i308 = mul nuw i64 %x_hi_lo.i303, 4294967295
  %_14.0.i309 = add i64 %spec.select.i307, %t1.i308
  %_14.1.i310 = icmp ult i64 %_14.0.i309, %spec.select.i307
  %29 = add i64 %_14.0.i309, 4294967295
  %res.sroa.0.0.i311 = select i1 %_14.1.i310, i64 %29, i64 %_14.0.i309
  %_16.i312 = icmp ugt i64 %res.sroa.0.0.i311, -4294967296
  %_17.i313 = add nsw i64 %res.sroa.0.0.i311, 4294967295
  %_0.sroa.0.0.i314 = select i1 %_16.i312, i64 %_17.i313, i64 %res.sroa.0.0.i311
  %_16.i31 = mul nuw i128 %_15.i28, %_11.i23
  %x_lo.i283 = trunc i128 %_16.i31 to i64
  %_4.i284 = lshr i128 %_16.i31, 64
  %x_hi.i285 = trunc nuw i128 %_4.i284 to i64
  %x_hi_hi.i286 = lshr i64 %x_hi.i285, 32
  %x_hi_lo.i287 = and i64 %x_hi.i285, 4294967295
  %_9.0.i288 = sub i64 %x_lo.i283, %x_hi_hi.i286
  %_9.1.i289 = icmp ugt i64 %x_hi_hi.i286, %x_lo.i283
  %_10.i290 = add i64 %_9.0.i288, -4294967295
  %spec.select.i291 = select i1 %_9.1.i289, i64 %_10.i290, i64 %_9.0.i288
  %t1.i292 = mul nuw i64 %x_hi_lo.i287, 4294967295
  %_14.0.i293 = add i64 %spec.select.i291, %t1.i292
  %_14.1.i294 = icmp ult i64 %_14.0.i293, %spec.select.i291
  %30 = add i64 %_14.0.i293, 4294967295
  %res.sroa.0.0.i295 = select i1 %_14.1.i294, i64 %30, i64 %_14.0.i293
  %_16.i296 = icmp ugt i64 %res.sroa.0.0.i295, -4294967296
  %_17.i297 = add nsw i64 %res.sroa.0.0.i295, 4294967295
  %_0.sroa.0.0.i298 = select i1 %_16.i296, i64 %_17.i297, i64 %res.sroa.0.0.i295
  %_17.i33 = mul nuw i128 %_12.i24, %_14.i27
  %x_lo.i267 = trunc i128 %_17.i33 to i64
  %_4.i268 = lshr i128 %_17.i33, 64
  %x_hi.i269 = trunc nuw i128 %_4.i268 to i64
  %x_hi_hi.i270 = lshr i64 %x_hi.i269, 32
  %x_hi_lo.i271 = and i64 %x_hi.i269, 4294967295
  %_9.0.i272 = sub i64 %x_lo.i267, %x_hi_hi.i270
  %_9.1.i273 = icmp ugt i64 %x_hi_hi.i270, %x_lo.i267
  %_10.i274 = add i64 %_9.0.i272, -4294967295
  %spec.select.i275 = select i1 %_9.1.i273, i64 %_10.i274, i64 %_9.0.i272
  %t1.i276 = mul nuw i64 %x_hi_lo.i271, 4294967295
  %_14.0.i277 = add i64 %spec.select.i275, %t1.i276
  %_14.1.i278 = icmp ult i64 %_14.0.i277, %spec.select.i275
  %31 = add i64 %_14.0.i277, 4294967295
  %res.sroa.0.0.i279 = select i1 %_14.1.i278, i64 %31, i64 %_14.0.i277
  %_16.i280 = icmp ugt i64 %res.sroa.0.0.i279, -4294967296
  %_17.i281 = add nsw i64 %res.sroa.0.0.i279, 4294967295
  %_0.sroa.0.0.i282 = select i1 %_16.i280, i64 %_17.i281, i64 %res.sroa.0.0.i279
  %_19.i35 = zext i64 %_0.sroa.0.0.i314 to i128
  %_18.i36 = mul nuw nsw i128 %_19.i35, 7
  %x_lo.i251 = trunc i128 %_18.i36 to i64
  %_4.i252 = lshr i128 %_18.i36, 64
  %x_hi.i253 = trunc nuw nsw i128 %_4.i252 to i64
  %t1.i260 = mul nuw nsw i64 %x_hi.i253, 4294967295
  %_14.0.i261 = add i64 %t1.i260, %x_lo.i251
  %_14.1.i262 = icmp ult i64 %_14.0.i261, %x_lo.i251
  %32 = add i64 %_14.0.i261, 4294967295
  %res.sroa.0.0.i263 = select i1 %_14.1.i262, i64 %32, i64 %_14.0.i261
  %_16.i264 = icmp ugt i64 %res.sroa.0.0.i263, -4294967296
  %_17.i265 = add nsw i64 %res.sroa.0.0.i263, 4294967295
  %_0.sroa.0.0.i266 = select i1 %_16.i264, i64 %_17.i265, i64 %res.sroa.0.0.i263
  %_22.0.i38 = add i64 %_0.sroa.0.0.i266, %_0.sroa.0.0.i330
  %_22.1.i39 = icmp ult i64 %_22.0.i38, %_0.sroa.0.0.i330
  %33 = add nuw i64 %_22.0.i38, 4294967295
  %_24.sroa.0.0.i40 = select i1 %_22.1.i39, i64 %33, i64 %_22.0.i38
  %_25.i41 = icmp ugt i64 %_24.sroa.0.0.i40, -4294967296
  %_26.i42 = add nsw i64 %_24.sroa.0.0.i40, 4294967295
  %_7.sroa.0.0.i43 = select i1 %_25.i41, i64 %_26.i42, i64 %_24.sroa.0.0.i40
  %_29.0.i44 = add i64 %_0.sroa.0.0.i298, %_0.sroa.0.0.i282
  %_29.1.i45 = icmp ult i64 %_29.0.i44, %_0.sroa.0.0.i298
  %34 = add nuw i64 %_29.0.i44, 4294967295
  %_30.sroa.0.0.i46 = select i1 %_29.1.i45, i64 %34, i64 %_29.0.i44
  %_31.i47 = icmp ugt i64 %_30.sroa.0.0.i46, -4294967296
  %_32.i48 = add nsw i64 %_30.sroa.0.0.i46, 4294967295
  %_9.sroa.0.0.i49 = select i1 %_31.i47, i64 %_32.i48, i64 %_30.sroa.0.0.i46
  %_7.0.i8 = add i64 %d2.0, %d1.0
  %_7.1.i9 = icmp ult i64 %_7.0.i8, %d1.0
  %35 = add i64 %_7.0.i8, 4294967295
  %_8.sroa.0.0.i10 = select i1 %_7.1.i9, i64 %35, i64 %_7.0.i8
  %_9.i11 = icmp ugt i64 %_8.sroa.0.0.i10, -4294967296
  %_10.i12 = add nsw i64 %_8.sroa.0.0.i10, 4294967295
  %_3.sroa.0.0.i13 = select i1 %_9.i11, i64 %_10.i12, i64 %_8.sroa.0.0.i10
  %_13.0.i14 = add i64 %d2.1, %d1.1
  %_13.1.i15 = icmp ult i64 %_13.0.i14, %d1.1
  %36 = add i64 %_13.0.i14, 4294967295
  %_14.sroa.0.0.i16 = select i1 %_13.1.i15, i64 %36, i64 %_13.0.i14
  %_15.i17 = icmp ugt i64 %_14.sroa.0.0.i16, -4294967296
  %_16.i18 = add nsw i64 %_14.sroa.0.0.i16, 4294967295
  %_4.sroa.0.0.i19 = select i1 %_15.i17, i64 %_16.i18, i64 %_14.sroa.0.0.i16
  %_51.0 = sub i64 %_7.sroa.0.0.i43, %_3.sroa.0.0.i13
  %_51.1 = icmp ult i64 %_7.sroa.0.0.i43, %_3.sroa.0.0.i13
  %37 = add i64 %_51.0, -4294967295
  %_52.sroa.0.0 = select i1 %_51.1, i64 %37, i64 %_51.0
  %_55.0 = sub i64 %_9.sroa.0.0.i49, %_4.sroa.0.0.i19
  %_55.1 = icmp ult i64 %_9.sroa.0.0.i49, %_4.sroa.0.0.i19
  %38 = add i64 %_55.0, -4294967295
  %_56.sroa.0.0 = select i1 %_55.1, i64 %38, i64 %_55.0
  br label %bb10

bb10:                                             ; preds = %bb19, %bb20
  %rel.sroa.3.0 = phi i64 [ %_56.sroa.0.0, %bb19 ], [ %_9.sroa.0.0.i103, %bb20 ]
  %rel.sroa.0.0 = phi i64 [ %_52.sroa.0.0, %bb19 ], [ %_66.sroa.0.0, %bb20 ]
  %exitcond436.not = icmp eq i64 %iter1.sroa.0.0424, %mu.1
  br i1 %exitcond436.not, label %panic3, label %bb11

bb11:                                             ; preds = %bb10
  %39 = getelementptr inbounds nuw %"field::Fp2", ptr %mu.0, i64 %iter1.sroa.0.0424
  %_35.0 = load i64, ptr %39, align 8, !noundef !3
  %40 = getelementptr inbounds nuw i8, ptr %39, i64 8
  %_35.1 = load i64, ptr %40, align 8, !noundef !3
  %_11.i = zext i64 %_35.0 to i128
  %_12.i = zext i64 %rel.sroa.0.0 to i128
  %_10.i20 = mul nuw i128 %_11.i, %_12.i
  %x_lo.i395 = trunc i128 %_10.i20 to i64
  %_4.i396 = lshr i128 %_10.i20, 64
  %x_hi.i397 = trunc nuw i128 %_4.i396 to i64
  %x_hi_hi.i398 = lshr i64 %x_hi.i397, 32
  %x_hi_lo.i399 = and i64 %x_hi.i397, 4294967295
  %_9.0.i400 = sub i64 %x_lo.i395, %x_hi_hi.i398
  %_9.1.i401 = icmp ugt i64 %x_hi_hi.i398, %x_lo.i395
  %_10.i402 = add i64 %_9.0.i400, -4294967295
  %spec.select.i403 = select i1 %_9.1.i401, i64 %_10.i402, i64 %_9.0.i400
  %t1.i404 = mul nuw i64 %x_hi_lo.i399, 4294967295
  %_14.0.i405 = add i64 %spec.select.i403, %t1.i404
  %_14.1.i406 = icmp ult i64 %_14.0.i405, %spec.select.i403
  %41 = add i64 %_14.0.i405, 4294967295
  %res.sroa.0.0.i407 = select i1 %_14.1.i406, i64 %41, i64 %_14.0.i405
  %_16.i408 = icmp ugt i64 %res.sroa.0.0.i407, -4294967296
  %_17.i409 = add nsw i64 %res.sroa.0.0.i407, 4294967295
  %_0.sroa.0.0.i410 = select i1 %_16.i408, i64 %_17.i409, i64 %res.sroa.0.0.i407
  %_14.i = zext i64 %_35.1 to i128
  %_15.i21 = zext i64 %rel.sroa.3.0 to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i21
  %x_lo.i379 = trunc i128 %_13.i to i64
  %_4.i380 = lshr i128 %_13.i, 64
  %x_hi.i381 = trunc nuw i128 %_4.i380 to i64
  %x_hi_hi.i382 = lshr i64 %x_hi.i381, 32
  %x_hi_lo.i383 = and i64 %x_hi.i381, 4294967295
  %_9.0.i384 = sub i64 %x_lo.i379, %x_hi_hi.i382
  %_9.1.i385 = icmp ugt i64 %x_hi_hi.i382, %x_lo.i379
  %_10.i386 = add i64 %_9.0.i384, -4294967295
  %spec.select.i387 = select i1 %_9.1.i385, i64 %_10.i386, i64 %_9.0.i384
  %t1.i388 = mul nuw i64 %x_hi_lo.i383, 4294967295
  %_14.0.i389 = add i64 %spec.select.i387, %t1.i388
  %_14.1.i390 = icmp ult i64 %_14.0.i389, %spec.select.i387
  %42 = add i64 %_14.0.i389, 4294967295
  %res.sroa.0.0.i391 = select i1 %_14.1.i390, i64 %42, i64 %_14.0.i389
  %_16.i392 = icmp ugt i64 %res.sroa.0.0.i391, -4294967296
  %_17.i393 = add nsw i64 %res.sroa.0.0.i391, 4294967295
  %_0.sroa.0.0.i394 = select i1 %_16.i392, i64 %_17.i393, i64 %res.sroa.0.0.i391
  %_16.i22 = mul nuw i128 %_11.i, %_15.i21
  %x_lo.i363 = trunc i128 %_16.i22 to i64
  %_4.i364 = lshr i128 %_16.i22, 64
  %x_hi.i365 = trunc nuw i128 %_4.i364 to i64
  %x_hi_hi.i366 = lshr i64 %x_hi.i365, 32
  %x_hi_lo.i367 = and i64 %x_hi.i365, 4294967295
  %_9.0.i368 = sub i64 %x_lo.i363, %x_hi_hi.i366
  %_9.1.i369 = icmp ugt i64 %x_hi_hi.i366, %x_lo.i363
  %_10.i370 = add i64 %_9.0.i368, -4294967295
  %spec.select.i371 = select i1 %_9.1.i369, i64 %_10.i370, i64 %_9.0.i368
  %t1.i372 = mul nuw i64 %x_hi_lo.i367, 4294967295
  %_14.0.i373 = add i64 %spec.select.i371, %t1.i372
  %_14.1.i374 = icmp ult i64 %_14.0.i373, %spec.select.i371
  %43 = add i64 %_14.0.i373, 4294967295
  %res.sroa.0.0.i375 = select i1 %_14.1.i374, i64 %43, i64 %_14.0.i373
  %_16.i376 = icmp ugt i64 %res.sroa.0.0.i375, -4294967296
  %_17.i377 = add nsw i64 %res.sroa.0.0.i375, 4294967295
  %_0.sroa.0.0.i378 = select i1 %_16.i376, i64 %_17.i377, i64 %res.sroa.0.0.i375
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i347 = trunc i128 %_17.i to i64
  %_4.i348 = lshr i128 %_17.i, 64
  %x_hi.i349 = trunc nuw i128 %_4.i348 to i64
  %x_hi_hi.i350 = lshr i64 %x_hi.i349, 32
  %x_hi_lo.i351 = and i64 %x_hi.i349, 4294967295
  %_9.0.i352 = sub i64 %x_lo.i347, %x_hi_hi.i350
  %_9.1.i353 = icmp ugt i64 %x_hi_hi.i350, %x_lo.i347
  %_10.i354 = add i64 %_9.0.i352, -4294967295
  %spec.select.i355 = select i1 %_9.1.i353, i64 %_10.i354, i64 %_9.0.i352
  %t1.i356 = mul nuw i64 %x_hi_lo.i351, 4294967295
  %_14.0.i357 = add i64 %spec.select.i355, %t1.i356
  %_14.1.i358 = icmp ult i64 %_14.0.i357, %spec.select.i355
  %44 = add i64 %_14.0.i357, 4294967295
  %res.sroa.0.0.i359 = select i1 %_14.1.i358, i64 %44, i64 %_14.0.i357
  %_16.i360 = icmp ugt i64 %res.sroa.0.0.i359, -4294967296
  %_17.i361 = add nsw i64 %res.sroa.0.0.i359, 4294967295
  %_0.sroa.0.0.i362 = select i1 %_16.i360, i64 %_17.i361, i64 %res.sroa.0.0.i359
  %_19.i = zext i64 %_0.sroa.0.0.i394 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i331 = trunc i128 %_18.i to i64
  %_4.i332 = lshr i128 %_18.i, 64
  %x_hi.i333 = trunc nuw nsw i128 %_4.i332 to i64
  %t1.i340 = mul nuw nsw i64 %x_hi.i333, 4294967295
  %_14.0.i341 = add i64 %t1.i340, %x_lo.i331
  %_14.1.i342 = icmp ult i64 %_14.0.i341, %x_lo.i331
  %45 = add i64 %_14.0.i341, 4294967295
  %res.sroa.0.0.i343 = select i1 %_14.1.i342, i64 %45, i64 %_14.0.i341
  %_16.i344 = icmp ugt i64 %res.sroa.0.0.i343, -4294967296
  %_17.i345 = add nsw i64 %res.sroa.0.0.i343, 4294967295
  %_0.sroa.0.0.i346 = select i1 %_16.i344, i64 %_17.i345, i64 %res.sroa.0.0.i343
  %_22.0.i = add i64 %_0.sroa.0.0.i346, %_0.sroa.0.0.i410
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i410
  %46 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %46, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i362, %_0.sroa.0.0.i378
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i378
  %47 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %47, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %_7.0.i = add i64 %_7.sroa.0.0.i, %acc.sroa.0.0426
  %_7.1.i = icmp ult i64 %_7.0.i, %acc.sroa.0.0426
  %48 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %48, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i, %acc.sroa.4.0425
  %_13.1.i = icmp ult i64 %_13.0.i, %acc.sroa.4.0425
  %49 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %49, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %exitcond437.not = icmp eq i64 %9, %umax
  br i1 %exitcond437.not, label %bb18, label %bb17

panic3:                                           ; preds = %bb10
; call core::panicking::panic_bounds_check
  call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %mu.1, i64 noundef %mu.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_96d987a87d97c3b145ef68c6e71dd047) #21
  unreachable
}

; isolated::factory_0
; Function Attrs: noinline nonlazybind uwtable
define internal fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_0(ptr noalias noundef nonnull readonly align 8 captures(none) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %pad, i64 noundef %nlk) unnamed_addr #3 personality ptr @rust_eh_personality {
start:
  %vector.i = alloca [24 x i8], align 8
  %poly = alloca [296 x i8], align 8
  %pz = alloca [40 x i8], align 8
  %lks = alloca [24 x i8], align 8
  %cols = alloca [144 x i8], align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !102
; call __rustc::__rust_alloc
  %0 = tail call noundef align 8 dereferenceable_or_null(624) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 624, i64 noundef 8) #20, !noalias !102
  %1 = icmp eq ptr %0, null
  br i1 %1, label %bb3.i.i, label %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit

bb3.i.i:                                          ; preds = %start
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 624) #21, !noalias !107
  unreachable

_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit: ; preds = %start
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(624) %0, i8 -1, i64 624, i1 false), !noalias !107
  br label %bb2.i36

bb2.i36:                                          ; preds = %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit, %bb2.i36
  %iter.sroa.0.0114 = phi i64 [ 67, %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit ], [ %spec.select106, %bb2.i36 ]
  %_0.i3.i = icmp eq i64 %iter.sroa.0.0114, 77
  %_0.i4.i = add nuw nsw i64 %iter.sroa.0.0114, 1
  %spec.select106 = select i1 %_0.i3.i, i64 77, i64 %_0.i4.i
  %_13 = getelementptr inbounds nuw i64, ptr %0, i64 %iter.sroa.0.0114
  %2 = add nsw i64 %iter.sroa.0.0114, -64
  store i64 %2, ptr %_13, align 8
  %_0.i.not.i = icmp samesign ugt i64 %spec.select106, 77
  %or.cond = select i1 %_0.i3.i, i1 true, i1 %_0.i.not.i
  br i1 %or.cond, label %bb4, label %bb2.i36

cleanup:                                          ; preds = %bb40, %bb38
  %3 = landingpad { ptr, i32 }
          cleanup
  br label %bb2.i.i.i4.i64

bb4:                                              ; preds = %bb2.i36
  %_76 = icmp samesign ugt i64 %v.1, 34
  br i1 %_76, label %bb37, label %bb38, !prof !108

bb38:                                             ; preds = %bb4
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 25, i64 noundef 35, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_d29c77d346acbe694cb7ba8ee7faff56) #21
          to label %unreachable unwind label %cleanup

bb37:                                             ; preds = %bb4
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !109
; call __rustc::__rust_alloc
  %4 = tail call noundef align 8 dereferenceable_or_null(160) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 160, i64 noundef 8) #20, !noalias !109
  %5 = icmp eq ptr %4, null
  br i1 %5, label %bb40, label %bb41

unreachable:                                      ; preds = %bb40, %bb45, %bb102, %panic8, %panic6, %bb43, %bb38
  unreachable

bb40:                                             ; preds = %bb37
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 160) #21
          to label %unreachable unwind label %cleanup

bb41:                                             ; preds = %bb37
  %_83 = getelementptr inbounds nuw i8, ptr %v.0, i64 400
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(160) %4, ptr noundef nonnull align 8 dereferenceable(160) %_83, i64 160, i1 false)
  %_99 = icmp samesign ugt i64 %v.1, 36
  br i1 %_99, label %bb42, label %bb43, !prof !108

bb43:                                             ; preds = %bb41
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 35, i64 noundef 37, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_a51995a9f594fb331ed053838b7be924) #21
          to label %unreachable unwind label %cleanup1

bb42:                                             ; preds = %bb41
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !112
; call __rustc::__rust_alloc
  %6 = tail call noundef align 8 dereferenceable_or_null(32) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 32, i64 noundef 8) #20, !noalias !112
  %7 = icmp eq ptr %6, null
  br i1 %7, label %bb45, label %bb46

cleanup1:                                         ; preds = %bb45, %bb43
  %8 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

bb45:                                             ; preds = %bb42
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 32) #21
          to label %unreachable unwind label %cleanup1

bb46:                                             ; preds = %bb42
  %_104 = getelementptr inbounds nuw i8, ptr %v.0, i64 560
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %6, ptr noundef nonnull align 8 dereferenceable(32) %_104, i64 32, i1 false)
  %9 = getelementptr inbounds nuw i8, ptr %v.0, i64 336
  %10 = load <2 x i64>, ptr %9, align 8
  %11 = getelementptr inbounds nuw i8, ptr %v.0, i64 352
  %12 = load <2 x i64>, ptr %11, align 8
  %13 = getelementptr inbounds nuw i8, ptr %v.0, i64 368
  %14 = load <2 x i64>, ptr %13, align 8
  %15 = getelementptr inbounds nuw i8, ptr %v.0, i64 384
  %16 = load <2 x i64>, ptr %15, align 8
  %17 = and i32 %hh, 63
  %_122.not = icmp eq i32 %17, 63
  %18 = zext nneg i32 %17 to i64
  %_27 = shl nuw i64 1, %18
  %_121.sroa.0.0 = select i1 %_122.not, i64 9223372032559808513, i64 %_27
  %19 = and i32 %gg, 63
  %_134.not = icmp eq i32 %19, 63
  %20 = zext nneg i32 %19 to i64
  %_29 = shl nuw i64 1, %20
  %_133.sroa.0.0 = select i1 %_134.not, i64 9223372032559808513, i64 %_29
  %21 = icmp eq i32 %hh, 0
  %_32 = add i32 %hh, 63
  %22 = and i32 %_32, 63
  %23 = zext nneg i32 %22 to i64
  %24 = shl nuw i64 1, %23
  %_31.sroa.0.0 = select i1 %21, i64 0, i64 %24
  %_164 = icmp sgt i64 %_31.sroa.0.0, -1
  %_163.sroa.0.0 = select i1 %_164, i64 %_31.sroa.0.0, i64 9223372032559808513
  %25 = icmp eq i32 %gg, 0
  %_35 = add i32 %gg, 63
  %26 = and i32 %_35, 63
  %27 = zext nneg i32 %26 to i64
  %28 = shl nuw i64 1, %27
  %_34.sroa.0.0 = select i1 %25, i64 0, i64 %28
  %_176 = icmp sgt i64 %_34.sroa.0.0, -1
  %_175.sroa.0.0 = select i1 %_176, i64 %_34.sroa.0.0, i64 9223372032559808513
  call void @llvm.lifetime.start.p0(ptr nonnull %cols)
  %_39 = sub i32 8, %gg
  %29 = and i32 %_39, 63
  %30 = zext nneg i32 %29 to i64
  %_38 = shl nuw i64 1, %30
  %_42 = sub i32 16, %hh
  %31 = and i32 %_42, 63
  %32 = zext nneg i32 %31 to i64
  %_41 = shl nuw i64 1, %32
  store i64 68, ptr %cols, align 8
  %33 = getelementptr inbounds nuw i8, ptr %cols, i64 8
  store i64 1, ptr %33, align 8
  %34 = getelementptr inbounds nuw i8, ptr %cols, i64 16
  store i64 68, ptr %34, align 8
  %35 = getelementptr inbounds nuw i8, ptr %cols, i64 24
  store i64 %_38, ptr %35, align 8
  %36 = getelementptr inbounds nuw i8, ptr %cols, i64 32
  store i64 71, ptr %36, align 8
  %37 = getelementptr inbounds nuw i8, ptr %cols, i64 40
  store i64 1, ptr %37, align 8
  %38 = getelementptr inbounds nuw i8, ptr %cols, i64 48
  store i64 72, ptr %38, align 8
  %39 = getelementptr inbounds nuw i8, ptr %cols, i64 56
  store i64 1, ptr %39, align 8
  %40 = getelementptr inbounds nuw i8, ptr %cols, i64 64
  store i64 74, ptr %40, align 8
  %41 = getelementptr inbounds nuw i8, ptr %cols, i64 72
  store i64 1, ptr %41, align 8
  %42 = getelementptr inbounds nuw i8, ptr %cols, i64 80
  store i64 75, ptr %42, align 8
  %43 = getelementptr inbounds nuw i8, ptr %cols, i64 88
  store i64 1, ptr %43, align 8
  %44 = getelementptr inbounds nuw i8, ptr %cols, i64 96
  store i64 76, ptr %44, align 8
  %45 = getelementptr inbounds nuw i8, ptr %cols, i64 104
  store i64 1, ptr %45, align 8
  %46 = getelementptr inbounds nuw i8, ptr %cols, i64 112
  store i64 77, ptr %46, align 8
  %47 = getelementptr inbounds nuw i8, ptr %cols, i64 120
  store i64 1, ptr %47, align 8
  %48 = getelementptr inbounds nuw i8, ptr %cols, i64 128
  store i64 77, ptr %48, align 8
  %49 = getelementptr inbounds nuw i8, ptr %cols, i64 136
  store i64 %_41, ptr %49, align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %lks)
  %_188 = icmp ult i64 %nlk, 10
  br i1 %_188, label %bb101, label %bb102, !prof !115

cleanup2:                                         ; preds = %bb3.i.i43, %bb102
  %50 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb102:                                            ; preds = %bb46
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 0, i64 noundef %nlk, i64 noundef 9, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_1343241238dcbe085445d5b11ba0a378) #21
          to label %unreachable unwind label %cleanup2

bb101:                                            ; preds = %bb46
  call void @llvm.lifetime.start.p0(ptr nonnull %vector.i), !noalias !116
  %_34.0.i.i.i = mul nuw nsw i64 %nlk, 40
  %51 = icmp eq i64 %nlk, 0
  br i1 %51, label %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread, label %bb3.i.i.i

_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread: ; preds = %bb101
  store i64 0, ptr %vector.i, align 8, !noalias !116
  %52 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %52, align 8, !noalias !116
  %53 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  br label %bb105

bb3.i.i.i:                                        ; preds = %bb101
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !120
; call __rustc::__rust_alloc
  %54 = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) %_34.0.i.i.i, i64 noundef 8) #20, !noalias !120
  %55 = icmp eq ptr %54, null
  br i1 %55, label %bb3.i.i43, label %bb8.i.i.i.i.i.i.preheader

bb3.i.i43:                                        ; preds = %bb3.i.i.i
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 %_34.0.i.i.i) #21
          to label %.noexc unwind label %cleanup2

.noexc:                                           ; preds = %bb3.i.i43
  unreachable

bb8.i.i.i.i.i.i.preheader:                        ; preds = %bb3.i.i.i
  store i64 %nlk, ptr %vector.i, align 8, !noalias !116
  %56 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr %54, ptr %56, align 8, !noalias !116
  %57 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  tail call void @llvm.experimental.noalias.scope.decl(metadata !123)
  tail call void @llvm.experimental.noalias.scope.decl(metadata !126)
  br label %bb8.i.i.i.i.i.i

cleanup.i.i.i.i.i.i:                              ; preds = %bb2.i.i.i.i.i.i.i.i.i
  %58 = landingpad { ptr, i32 }
          cleanup
  br label %cleanup1.body.i

bb8.i.i.i.i.i.i:                                  ; preds = %bb8.i.i.i.i.i.i.preheader, %bb27.i.i.i.i.i.i
  %f.val9.i.i.i.i.i.i = phi i64 [ %67, %bb27.i.i.i.i.i.i ], [ 0, %bb8.i.i.i.i.i.i.preheader ]
  %_45.i.i.i.i.i.i = getelementptr inbounds nuw { i64, i64 }, ptr %cols, i64 %f.val9.i.i.i.i.i.i
  %_45.val.i.i.i.i.i.i = load i64, ptr %_45.i.i.i.i.i.i, align 8, !noalias !129
  %59 = getelementptr i8, ptr %_45.i.i.i.i.i.i, i64 8
  %_45.val10.i.i.i.i.i.i = load i64, ptr %59, align 8, !noalias !129
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !140
; call __rustc::__rust_alloc
  %60 = tail call noundef align 8 dereferenceable_or_null(16) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 16, i64 noundef 8) #20, !noalias !140
  %61 = icmp eq ptr %60, null
  br i1 %61, label %bb2.i.i.i.i.i.i.i.i.i, label %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i, !prof !57

bb2.i.i.i.i.i.i.i.i.i:                            ; preds = %bb8.i.i.i.i.i.i
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 16) #21
          to label %.noexc.i.i.i.i.i.i unwind label %cleanup.i.i.i.i.i.i, !noalias !129

.noexc.i.i.i.i.i.i:                               ; preds = %bb2.i.i.i.i.i.i.i.i.i
  unreachable

_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i: ; preds = %bb8.i.i.i.i.i.i
  %_23.i.i.i.i.i.i.i.i = icmp ult i64 %_45.val.i.i.i.i.i.i, 78
  br i1 %_23.i.i.i.i.i.i.i.i, label %bb27.i.i.i.i.i.i, label %panic.i.i.i.i.i.i.i.i

panic.i.i.i.i.i.i.i.i:                            ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_45.val.i.i.i.i.i.i, i64 noundef 78, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_8a0667c067a77bb698bb88e8b54ac9d2) #21
          to label %unreachable.i.i.i.i.i.i.i.i unwind label %bb2.i.i.i.i.i.i.i.i, !noalias !140

unreachable.i.i.i.i.i.i.i.i:                      ; preds = %panic.i.i.i.i.i.i.i.i
  unreachable

bb2.i.i.i.i.i.i.i.i:                              ; preds = %panic.i.i.i.i.i.i.i.i
  %62 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %60, i64 noundef 16, i64 noundef 8) #20, !noalias !140
  br label %cleanup1.body.i

bb27.i.i.i.i.i.i:                                 ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
  %_10.i.i.i.i.i.i.i.i = getelementptr inbounds nuw i64, ptr %0, i64 %_45.val.i.i.i.i.i.i
  %_9.i.i.i.i.i.i.i.i = load i64, ptr %_10.i.i.i.i.i.i.i.i, align 8, !noalias !140, !noundef !3
  %63 = add i64 %_45.val10.i.i.i.i.i.i, -4294967296
  %64 = icmp ult i64 %63, -4294967295
  %65 = select i1 %64, i64 -4294967295, i64 -8589934590
  %_241.i.i.i.i.i.i.i.i = icmp slt i64 %_45.val10.i.i.i.i.i.i, 0
  %_26.i.i.i.i.i.i.i.i = select i1 %_241.i.i.i.i.i.i.i.i, i64 %65, i64 0
  %_12.sroa.0.0.i.i.i.i.i.i.i.i = add i64 %_26.i.i.i.i.i.i.i.i, %_45.val10.i.i.i.i.i.i
  store i64 %_9.i.i.i.i.i.i.i.i, ptr %60, align 8, !noalias !140
  %66 = getelementptr inbounds nuw i8, ptr %60, i64 8
  store i64 %_12.sroa.0.0.i.i.i.i.i.i.i.i, ptr %66, align 8, !noalias !140
  %_3.i.i.i.i.i.i.i.i.i = getelementptr inbounds nuw %LkT, ptr %54, i64 %f.val9.i.i.i.i.i.i
  store i64 1, ptr %_3.i.i.i.i.i.i.i.i.i, align 8, !noalias !145
  %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 8
  store ptr %60, ptr %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !145
  %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 16
  store i64 1, ptr %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !145
  %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 24
  store <2 x i64> %16, ptr %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !145
  %67 = add nuw i64 %f.val9.i.i.i.i.i.i, 1
  %_28.i.i.i.i.i.i = icmp eq i64 %67, %nlk
  br i1 %_28.i.i.i.i.i.i, label %bb105, label %bb8.i.i.i.i.i.i

cleanup1.body.i:                                  ; preds = %bb2.i.i.i.i.i.i.i.i, %cleanup.i.i.i.i.i.i
  %eh.lpad-body.i.i.i.i.i.i = phi { ptr, i32 } [ %58, %cleanup.i.i.i.i.i.i ], [ %62, %bb2.i.i.i.i.i.i.i.i ]
  store i64 %f.val9.i.i.i.i.i.i, ptr %57, align 8, !alias.scope !150, !noalias !151
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %vector.i) #22, !noalias !116
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb105:                                            ; preds = %bb27.i.i.i.i.i.i, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread
  %68 = phi ptr [ %53, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread ], [ %57, %bb27.i.i.i.i.i.i ]
  store i64 %nlk, ptr %68, align 8, !alias.scope !150, !noalias !151
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %lks, ptr noundef nonnull align 8 dereferenceable(24) %vector.i, i64 24, i1 false), !noalias !152
  call void @llvm.lifetime.end.p0(ptr nonnull %vector.i), !noalias !116
  call void @llvm.lifetime.start.p0(ptr nonnull %pz)
  store i64 0, ptr %pz, align 8
  %_202.sroa.8.0.pz.sroa_idx19 = getelementptr inbounds nuw i8, ptr %pz, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %_202.sroa.8.0.pz.sroa_idx19, align 8
  %_202.sroa.10.0.pz.sroa_idx21 = getelementptr inbounds nuw i8, ptr %pz, i64 16
  %69 = getelementptr inbounds nuw i8, ptr %pz, i64 24
  br i1 %pad, label %bb15, label %bb16

bb16:                                             ; preds = %bb105
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_202.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br label %bb20

bb15:                                             ; preds = %bb105
  %_20323 = lshr i64 %nlk, 1
  %_56.sroa.0.0 = sub nsw i64 %nlk, %_20323
  %_55 = add nuw nsw i64 %_56.sroa.0.0, 4
  %_210 = icmp ult i64 %_56.sroa.0.0, 6
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_202.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br i1 %_210, label %bb109, label %panic6

bb20:                                             ; preds = %bb19, %bb16
  %gf.sroa.0.0 = phi i64 [ 1, %bb19 ], [ 0, %bb16 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %poly)
  %70 = getelementptr inbounds nuw i8, ptr %poly, i64 16
  store i64 78, ptr %70, align 8
  %idx.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 24
  store ptr %0, ptr %idx.sroa.5.0..sroa_idx, align 8
  %idx.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 32
  store i64 78, ptr %idx.sroa.7.0..sroa_idx, align 8
  %71 = getelementptr inbounds nuw i8, ptr %poly, i64 152
  store i64 256, ptr %71, align 8
  %72 = getelementptr inbounds nuw i8, ptr %poly, i64 160
  store i64 0, ptr %72, align 8
  %73 = getelementptr inbounds nuw i8, ptr %poly, i64 168
  store i64 %_121.sroa.0.0, ptr %73, align 8
  %74 = getelementptr inbounds nuw i8, ptr %poly, i64 176
  store i64 0, ptr %74, align 8
  %75 = getelementptr inbounds nuw i8, ptr %poly, i64 184
  store i64 %_163.sroa.0.0, ptr %75, align 8
  %76 = getelementptr inbounds nuw i8, ptr %poly, i64 192
  store i64 0, ptr %76, align 8
  %77 = getelementptr inbounds nuw i8, ptr %poly, i64 200
  store i64 19, ptr %77, align 8
  %78 = getelementptr inbounds nuw i8, ptr %poly, i64 208
  store <2 x i64> %10, ptr %78, align 8
  %79 = getelementptr inbounds nuw i8, ptr %poly, i64 224
  store <2 x i64> %12, ptr %79, align 8
  %80 = getelementptr inbounds nuw i8, ptr %poly, i64 240
  store <2 x i64> %14, ptr %80, align 8
  store i64 %gf.sroa.0.0, ptr %poly, align 8
  %81 = getelementptr inbounds nuw i8, ptr %poly, i64 8
  store i64 20, ptr %81, align 8
  %82 = getelementptr inbounds nuw i8, ptr %poly, i64 40
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %82, ptr noundef nonnull align 8 dereferenceable(24) %lks, i64 24, i1 false)
  %83 = getelementptr inbounds nuw i8, ptr %poly, i64 256
  store i64 14, ptr %83, align 8
  %84 = getelementptr inbounds nuw i8, ptr %poly, i64 64
  store i64 10, ptr %84, align 8
  %mu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 72
  store ptr %4, ptr %mu.sroa.5.0..sroa_idx, align 8
  %mu.sroa.8.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 80
  store i64 10, ptr %mu.sroa.8.0..sroa_idx, align 8
  %85 = getelementptr inbounds nuw i8, ptr %poly, i64 88
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(40) %85, ptr noundef nonnull align 8 dereferenceable(40) %pz, i64 40, i1 false)
  %86 = getelementptr inbounds nuw i8, ptr %poly, i64 264
  store i64 %_133.sroa.0.0, ptr %86, align 8
  %87 = getelementptr inbounds nuw i8, ptr %poly, i64 272
  store i64 0, ptr %87, align 8
  %88 = getelementptr inbounds nuw i8, ptr %poly, i64 280
  store i64 %_175.sroa.0.0, ptr %88, align 8
  %89 = getelementptr inbounds nuw i8, ptr %poly, i64 288
  store i64 0, ptr %89, align 8
  %90 = getelementptr inbounds nuw i8, ptr %poly, i64 128
  store i64 2, ptr %90, align 8
  %nu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 136
  store ptr %6, ptr %nu.sroa.5.0..sroa_idx, align 8
  %nu.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 144
  store i64 2, ptr %nu.sroa.7.0..sroa_idx, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !153
; call __rustc::__rust_alloc
  %91 = tail call noundef align 8 dereferenceable_or_null(296) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 296, i64 noundef 8) #20, !noalias !153
  %92 = icmp eq ptr %91, null
  br i1 %92, label %bb2.i45, label %bb21, !prof !57

bb2.i45:                                          ; preds = %bb20
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 296) #21
          to label %.noexc46 unwind label %cleanup.i

.noexc46:                                         ; preds = %bb2.i45
  unreachable

cleanup.i:                                        ; preds = %bb2.i45
  %93 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
  call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(296) %poly) #22
  br label %bb23

bb109:                                            ; preds = %bb15
  %_54 = getelementptr inbounds nuw %"field::Fp2", ptr %4, i64 %_55
  %94 = load <2 x i64>, ptr %_54, align 8
  store <2 x i64> %94, ptr %69, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !156
; call __rustc::__rust_alloc
  %95 = tail call noundef align 8 dereferenceable_or_null(88) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 88, i64 noundef 8) #20, !noalias !156
  %96 = icmp eq ptr %95, null
  br i1 %96, label %bb3.i.i49, label %bb110

bb3.i.i49:                                        ; preds = %bb109
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 88) #21
          to label %.noexc50 unwind label %bb25

.noexc50:                                         ; preds = %bb3.i.i49
  unreachable

panic6:                                           ; preds = %bb15
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_55, i64 noundef 10, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_23b5d640586d465cb57fc69fc0fb3828) #21
          to label %unreachable unwind label %bb25

bb25:                                             ; preds = %panic6, %bb3.i.i49
  %97 = landingpad { ptr, i32 }
          cleanup
  br label %bb24

bb110:                                            ; preds = %bb109
  store i64 3, ptr %95, align 8, !noalias !161
  %_3.i.i.1.i.i.i.i.i = getelementptr i8, ptr %95, i64 8
  store i64 4, ptr %_3.i.i.1.i.i.i.i.i, align 8, !noalias !174
  %_3.i.i.2.i.i.i.i.i = getelementptr i8, ptr %95, i64 16
  store i64 5, ptr %_3.i.i.2.i.i.i.i.i, align 8, !noalias !177
  %_3.i.i.3.i.i.i.i.i = getelementptr i8, ptr %95, i64 24
  store i64 6, ptr %_3.i.i.3.i.i.i.i.i, align 8, !noalias !180
  %_3.i.i.4.i.i.i.i.i = getelementptr i8, ptr %95, i64 32
  store i64 7, ptr %_3.i.i.4.i.i.i.i.i, align 8, !noalias !183
  %_3.i.i.5.i.i.i.i.i = getelementptr i8, ptr %95, i64 40
  store i64 8, ptr %_3.i.i.5.i.i.i.i.i, align 8, !noalias !186
  %_3.i.i.6.i.i.i.i.i = getelementptr i8, ptr %95, i64 48
  store i64 9, ptr %_3.i.i.6.i.i.i.i.i, align 8, !noalias !189
  %_3.i.i.7.i.i.i.i.i = getelementptr i8, ptr %95, i64 56
  store i64 10, ptr %_3.i.i.7.i.i.i.i.i, align 8, !noalias !192
  %_3.i.i.8.i.i.i.i.i = getelementptr i8, ptr %95, i64 64
  store i64 11, ptr %_3.i.i.8.i.i.i.i.i, align 8, !noalias !195
  %_3.i.i.9.i.i.i.i.i = getelementptr i8, ptr %95, i64 72
  store i64 12, ptr %_3.i.i.9.i.i.i.i.i, align 8, !noalias !198
  %_3.i.i.10.i.i.i.i.i = getelementptr i8, ptr %95, i64 80
  store i64 13, ptr %_3.i.i.10.i.i.i.i.i, align 8, !noalias !201
  %_62.not = icmp eq i64 %v.1, 37
  br i1 %_62.not, label %panic8, label %bb17

bb17:                                             ; preds = %bb110
  %98 = getelementptr inbounds nuw i8, ptr %v.0, i64 592
  %_61.0 = load i64, ptr %98, align 8, !noundef !3
  %99 = getelementptr inbounds nuw i8, ptr %v.0, i64 600
  %_61.1 = load i64, ptr %99, align 8, !noundef !3
; invoke <isolated::PadTerm>::add
  invoke fastcc void @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add(ptr noalias noundef align 8 dereferenceable(40) %pz, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %95, i64 noundef 11, i64 noundef %_61.0, i64 noundef %_61.1)
          to label %bb19 unwind label %bb25.thread

panic8:                                           ; preds = %bb110
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 37, i64 noundef 37, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_0e8d56a95944120dff42b51dc5d24e92) #21
          to label %unreachable unwind label %bb25.thread

bb25.thread:                                      ; preds = %bb17, %panic8
  %100 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %95, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb24

bb19:                                             ; preds = %bb17
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %95, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb20

bb21:                                             ; preds = %bb20
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(296) %91, ptr noundef nonnull align 8 dereferenceable(296) %poly, i64 296, i1 false)
  call void @llvm.lifetime.end.p0(ptr nonnull %poly)
  call void @llvm.lifetime.end.p0(ptr nonnull %pz)
  call void @llvm.lifetime.end.p0(ptr nonnull %lks)
  call void @llvm.lifetime.end.p0(ptr nonnull %cols)
  %101 = insertvalue { ptr, ptr } poison, ptr %91, 0
  %102 = insertvalue { ptr, ptr } %101, ptr @vtable.0, 1
  ret { ptr, ptr } %102

bb24:                                             ; preds = %bb25, %bb25.thread
  %.pn101 = phi { ptr, i32 } [ %100, %bb25.thread ], [ %97, %bb25 ]
; call core::ptr::drop_glue::<isolated::PadTerm>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_(ptr noalias noundef align 8 dereferenceable(40) %pz) #22
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %lks) #22
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit: ; preds = %bb24, %cleanup1.body.i, %cleanup2
  %.pn.pn.ph = phi { ptr, i32 } [ %.pn101, %bb24 ], [ %50, %cleanup2 ], [ %eh.lpad-body.i.i.i.i.i.i, %cleanup1.body.i ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %6, i64 noundef 32, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62: ; preds = %cleanup1, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit
  %.pn26.ph = phi { ptr, i32 } [ %.pn.pn.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit ], [ %8, %cleanup1 ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %4, i64 noundef 160, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb2.i.i.i4.i64

bb23:                                             ; preds = %cleanup.i, %bb2.i.i.i4.i64
  %.pn2872 = phi { ptr, i32 } [ %.pn28.ph, %bb2.i.i.i4.i64 ], [ %93, %cleanup.i ]
  resume { ptr, i32 } %.pn2872

bb2.i.i.i4.i64:                                   ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62, %cleanup
  %.pn28.ph = phi { ptr, i32 } [ %.pn26.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62 ], [ %3, %cleanup ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %0, i64 noundef 624, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb23
}

; isolated::factory_1
; Function Attrs: noinline nonlazybind uwtable
define internal fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_1(ptr noalias noundef nonnull readonly align 8 captures(none) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %pad, i64 noundef %nlk) unnamed_addr #3 personality ptr @rust_eh_personality {
start:
  %vector.i = alloca [24 x i8], align 8
  %poly = alloca [272 x i8], align 8
  %pz = alloca [40 x i8], align 8
  %lks = alloca [24 x i8], align 8
  %cols = alloca [144 x i8], align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !204
; call __rustc::__rust_alloc
  %0 = tail call noundef align 8 dereferenceable_or_null(624) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 624, i64 noundef 8) #20, !noalias !204
  %1 = icmp eq ptr %0, null
  br i1 %1, label %bb3.i.i, label %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit

bb3.i.i:                                          ; preds = %start
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 624) #21, !noalias !209
  unreachable

_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit: ; preds = %start
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(624) %0, i8 -1, i64 624, i1 false), !noalias !209
  br label %bb2.i36

bb2.i36:                                          ; preds = %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit, %bb2.i36
  %iter.sroa.0.0114 = phi i64 [ 67, %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit ], [ %spec.select106, %bb2.i36 ]
  %_0.i3.i = icmp eq i64 %iter.sroa.0.0114, 77
  %_0.i4.i = add nuw nsw i64 %iter.sroa.0.0114, 1
  %spec.select106 = select i1 %_0.i3.i, i64 77, i64 %_0.i4.i
  %_13 = getelementptr inbounds nuw i64, ptr %0, i64 %iter.sroa.0.0114
  %2 = add nsw i64 %iter.sroa.0.0114, -64
  store i64 %2, ptr %_13, align 8
  %_0.i.not.i = icmp samesign ugt i64 %spec.select106, 77
  %or.cond = select i1 %_0.i3.i, i1 true, i1 %_0.i.not.i
  br i1 %or.cond, label %bb4, label %bb2.i36

cleanup:                                          ; preds = %bb40, %bb38
  %3 = landingpad { ptr, i32 }
          cleanup
  br label %bb2.i.i.i4.i64

bb4:                                              ; preds = %bb2.i36
  %_76 = icmp samesign ugt i64 %v.1, 34
  br i1 %_76, label %bb37, label %bb38, !prof !108

bb38:                                             ; preds = %bb4
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 25, i64 noundef 35, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_f0438cd97fee7f47e6788e32f762b012) #21
          to label %unreachable unwind label %cleanup

bb37:                                             ; preds = %bb4
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !210
; call __rustc::__rust_alloc
  %4 = tail call noundef align 8 dereferenceable_or_null(160) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 160, i64 noundef 8) #20, !noalias !210
  %5 = icmp eq ptr %4, null
  br i1 %5, label %bb40, label %bb41

unreachable:                                      ; preds = %bb40, %bb45, %bb102, %panic8, %panic6, %bb43, %bb38
  unreachable

bb40:                                             ; preds = %bb37
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 160) #21
          to label %unreachable unwind label %cleanup

bb41:                                             ; preds = %bb37
  %_83 = getelementptr inbounds nuw i8, ptr %v.0, i64 400
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(160) %4, ptr noundef nonnull align 8 dereferenceable(160) %_83, i64 160, i1 false)
  %_99 = icmp samesign ugt i64 %v.1, 36
  br i1 %_99, label %bb42, label %bb43, !prof !108

bb43:                                             ; preds = %bb41
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 35, i64 noundef 37, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_cedfa6dae4663ae34151168cdec22263) #21
          to label %unreachable unwind label %cleanup1

bb42:                                             ; preds = %bb41
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !213
; call __rustc::__rust_alloc
  %6 = tail call noundef align 8 dereferenceable_or_null(32) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 32, i64 noundef 8) #20, !noalias !213
  %7 = icmp eq ptr %6, null
  br i1 %7, label %bb45, label %bb46

cleanup1:                                         ; preds = %bb45, %bb43
  %8 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

bb45:                                             ; preds = %bb42
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 32) #21
          to label %unreachable unwind label %cleanup1

bb46:                                             ; preds = %bb42
  %_104 = getelementptr inbounds nuw i8, ptr %v.0, i64 560
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %6, ptr noundef nonnull align 8 dereferenceable(32) %_104, i64 32, i1 false)
  %9 = getelementptr inbounds nuw i8, ptr %v.0, i64 336
  %10 = load <2 x i64>, ptr %9, align 8
  %11 = getelementptr inbounds nuw i8, ptr %v.0, i64 352
  %12 = load <2 x i64>, ptr %11, align 8
  %13 = getelementptr inbounds nuw i8, ptr %v.0, i64 368
  %14 = load <2 x i64>, ptr %13, align 8
  %15 = getelementptr inbounds nuw i8, ptr %v.0, i64 384
  %16 = load <2 x i64>, ptr %15, align 8
  %17 = and i32 %hh, 63
  %18 = zext nneg i32 %17 to i64
  %_26 = shl nuw i64 1, %18
  %_120.not = icmp eq i32 %17, 63
  %19 = and i32 %gg, 63
  %20 = zext nneg i32 %19 to i64
  %_27 = shl nuw i64 1, %20
  %_130.not = icmp eq i32 %19, 63
  %b_h.sroa.0.0 = select i1 %_120.not, i64 9223372032559808513, i64 %_26
  %b_g.sroa.0.0 = select i1 %_130.not, i64 9223372032559808513, i64 %_27
  %21 = icmp eq i32 %hh, 0
  %_32 = add i32 %hh, 63
  %22 = and i32 %_32, 63
  %23 = zext nneg i32 %22 to i64
  %24 = shl nuw i64 1, %23
  %_31.sroa.0.0 = select i1 %21, i64 0, i64 %24
  %_161 = icmp sgt i64 %_31.sroa.0.0, -1
  %_160.sroa.0.0 = select i1 %_161, i64 %_31.sroa.0.0, i64 9223372032559808513
  %25 = icmp eq i32 %gg, 0
  %_35 = add i32 %gg, 63
  %26 = and i32 %_35, 63
  %27 = zext nneg i32 %26 to i64
  %28 = shl nuw i64 1, %27
  %_34.sroa.0.0 = select i1 %25, i64 0, i64 %28
  %_173 = icmp sgt i64 %_34.sroa.0.0, -1
  %_172.sroa.0.0 = select i1 %_173, i64 %_34.sroa.0.0, i64 9223372032559808513
  call void @llvm.lifetime.start.p0(ptr nonnull %cols)
  %_39 = sub i32 8, %gg
  %29 = and i32 %_39, 63
  %30 = zext nneg i32 %29 to i64
  %_38 = shl nuw i64 1, %30
  %_42 = sub i32 16, %hh
  %31 = and i32 %_42, 63
  %32 = zext nneg i32 %31 to i64
  %_41 = shl nuw i64 1, %32
  store i64 68, ptr %cols, align 8
  %33 = getelementptr inbounds nuw i8, ptr %cols, i64 8
  store i64 1, ptr %33, align 8
  %34 = getelementptr inbounds nuw i8, ptr %cols, i64 16
  store i64 68, ptr %34, align 8
  %35 = getelementptr inbounds nuw i8, ptr %cols, i64 24
  store i64 %_38, ptr %35, align 8
  %36 = getelementptr inbounds nuw i8, ptr %cols, i64 32
  store i64 71, ptr %36, align 8
  %37 = getelementptr inbounds nuw i8, ptr %cols, i64 40
  store i64 1, ptr %37, align 8
  %38 = getelementptr inbounds nuw i8, ptr %cols, i64 48
  store i64 72, ptr %38, align 8
  %39 = getelementptr inbounds nuw i8, ptr %cols, i64 56
  store i64 1, ptr %39, align 8
  %40 = getelementptr inbounds nuw i8, ptr %cols, i64 64
  store i64 74, ptr %40, align 8
  %41 = getelementptr inbounds nuw i8, ptr %cols, i64 72
  store i64 1, ptr %41, align 8
  %42 = getelementptr inbounds nuw i8, ptr %cols, i64 80
  store i64 75, ptr %42, align 8
  %43 = getelementptr inbounds nuw i8, ptr %cols, i64 88
  store i64 1, ptr %43, align 8
  %44 = getelementptr inbounds nuw i8, ptr %cols, i64 96
  store i64 76, ptr %44, align 8
  %45 = getelementptr inbounds nuw i8, ptr %cols, i64 104
  store i64 1, ptr %45, align 8
  %46 = getelementptr inbounds nuw i8, ptr %cols, i64 112
  store i64 77, ptr %46, align 8
  %47 = getelementptr inbounds nuw i8, ptr %cols, i64 120
  store i64 1, ptr %47, align 8
  %48 = getelementptr inbounds nuw i8, ptr %cols, i64 128
  store i64 77, ptr %48, align 8
  %49 = getelementptr inbounds nuw i8, ptr %cols, i64 136
  store i64 %_41, ptr %49, align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %lks)
  %_185 = icmp ult i64 %nlk, 10
  br i1 %_185, label %bb101, label %bb102, !prof !115

cleanup2:                                         ; preds = %bb3.i.i43, %bb102
  %50 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb102:                                            ; preds = %bb46
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 0, i64 noundef %nlk, i64 noundef 9, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_9441bbbb1bffb9011b99cd574d638c7a) #21
          to label %unreachable unwind label %cleanup2

bb101:                                            ; preds = %bb46
  call void @llvm.lifetime.start.p0(ptr nonnull %vector.i), !noalias !216
  %_34.0.i.i.i = mul nuw nsw i64 %nlk, 40
  %51 = icmp eq i64 %nlk, 0
  br i1 %51, label %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread, label %bb3.i.i.i

_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread: ; preds = %bb101
  store i64 0, ptr %vector.i, align 8, !noalias !216
  %52 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %52, align 8, !noalias !216
  %53 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  br label %bb105

bb3.i.i.i:                                        ; preds = %bb101
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !220
; call __rustc::__rust_alloc
  %54 = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) %_34.0.i.i.i, i64 noundef 8) #20, !noalias !220
  %55 = icmp eq ptr %54, null
  br i1 %55, label %bb3.i.i43, label %bb8.i.i.i.i.i.i.preheader

bb3.i.i43:                                        ; preds = %bb3.i.i.i
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 %_34.0.i.i.i) #21
          to label %.noexc unwind label %cleanup2

.noexc:                                           ; preds = %bb3.i.i43
  unreachable

bb8.i.i.i.i.i.i.preheader:                        ; preds = %bb3.i.i.i
  store i64 %nlk, ptr %vector.i, align 8, !noalias !216
  %56 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr %54, ptr %56, align 8, !noalias !216
  %57 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  tail call void @llvm.experimental.noalias.scope.decl(metadata !223)
  tail call void @llvm.experimental.noalias.scope.decl(metadata !226)
  br label %bb8.i.i.i.i.i.i

cleanup.i.i.i.i.i.i:                              ; preds = %bb2.i.i.i.i.i.i.i.i.i
  %58 = landingpad { ptr, i32 }
          cleanup
  br label %cleanup1.body.i

bb8.i.i.i.i.i.i:                                  ; preds = %bb8.i.i.i.i.i.i.preheader, %bb27.i.i.i.i.i.i
  %f.val9.i.i.i.i.i.i = phi i64 [ %67, %bb27.i.i.i.i.i.i ], [ 0, %bb8.i.i.i.i.i.i.preheader ]
  %_45.i.i.i.i.i.i = getelementptr inbounds nuw { i64, i64 }, ptr %cols, i64 %f.val9.i.i.i.i.i.i
  %_45.val.i.i.i.i.i.i = load i64, ptr %_45.i.i.i.i.i.i, align 8, !noalias !229
  %59 = getelementptr i8, ptr %_45.i.i.i.i.i.i, i64 8
  %_45.val10.i.i.i.i.i.i = load i64, ptr %59, align 8, !noalias !229
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !240
; call __rustc::__rust_alloc
  %60 = tail call noundef align 8 dereferenceable_or_null(16) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 16, i64 noundef 8) #20, !noalias !240
  %61 = icmp eq ptr %60, null
  br i1 %61, label %bb2.i.i.i.i.i.i.i.i.i, label %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i, !prof !57

bb2.i.i.i.i.i.i.i.i.i:                            ; preds = %bb8.i.i.i.i.i.i
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 16) #21
          to label %.noexc.i.i.i.i.i.i unwind label %cleanup.i.i.i.i.i.i, !noalias !229

.noexc.i.i.i.i.i.i:                               ; preds = %bb2.i.i.i.i.i.i.i.i.i
  unreachable

_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i: ; preds = %bb8.i.i.i.i.i.i
  %_23.i.i.i.i.i.i.i.i = icmp ult i64 %_45.val.i.i.i.i.i.i, 78
  br i1 %_23.i.i.i.i.i.i.i.i, label %bb27.i.i.i.i.i.i, label %panic.i.i.i.i.i.i.i.i

panic.i.i.i.i.i.i.i.i:                            ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_45.val.i.i.i.i.i.i, i64 noundef 78, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_28926e658ad846032cbbfac196c44ac3) #21
          to label %unreachable.i.i.i.i.i.i.i.i unwind label %bb2.i.i.i.i.i.i.i.i, !noalias !240

unreachable.i.i.i.i.i.i.i.i:                      ; preds = %panic.i.i.i.i.i.i.i.i
  unreachable

bb2.i.i.i.i.i.i.i.i:                              ; preds = %panic.i.i.i.i.i.i.i.i
  %62 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %60, i64 noundef 16, i64 noundef 8) #20, !noalias !240
  br label %cleanup1.body.i

bb27.i.i.i.i.i.i:                                 ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
  %_10.i.i.i.i.i.i.i.i = getelementptr inbounds nuw i64, ptr %0, i64 %_45.val.i.i.i.i.i.i
  %_9.i.i.i.i.i.i.i.i = load i64, ptr %_10.i.i.i.i.i.i.i.i, align 8, !noalias !240, !noundef !3
  %63 = add i64 %_45.val10.i.i.i.i.i.i, -4294967296
  %64 = icmp ult i64 %63, -4294967295
  %65 = select i1 %64, i64 -4294967295, i64 -8589934590
  %_241.i.i.i.i.i.i.i.i = icmp slt i64 %_45.val10.i.i.i.i.i.i, 0
  %_26.i.i.i.i.i.i.i.i = select i1 %_241.i.i.i.i.i.i.i.i, i64 %65, i64 0
  %_12.sroa.0.0.i.i.i.i.i.i.i.i = add i64 %_26.i.i.i.i.i.i.i.i, %_45.val10.i.i.i.i.i.i
  store i64 %_9.i.i.i.i.i.i.i.i, ptr %60, align 8, !noalias !240
  %66 = getelementptr inbounds nuw i8, ptr %60, i64 8
  store i64 %_12.sroa.0.0.i.i.i.i.i.i.i.i, ptr %66, align 8, !noalias !240
  %_3.i.i.i.i.i.i.i.i.i = getelementptr inbounds nuw %LkT, ptr %54, i64 %f.val9.i.i.i.i.i.i
  store i64 1, ptr %_3.i.i.i.i.i.i.i.i.i, align 8, !noalias !245
  %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 8
  store ptr %60, ptr %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !245
  %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 16
  store i64 1, ptr %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !245
  %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 24
  store <2 x i64> %16, ptr %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !245
  %67 = add nuw i64 %f.val9.i.i.i.i.i.i, 1
  %_28.i.i.i.i.i.i = icmp eq i64 %67, %nlk
  br i1 %_28.i.i.i.i.i.i, label %bb105, label %bb8.i.i.i.i.i.i

cleanup1.body.i:                                  ; preds = %bb2.i.i.i.i.i.i.i.i, %cleanup.i.i.i.i.i.i
  %eh.lpad-body.i.i.i.i.i.i = phi { ptr, i32 } [ %58, %cleanup.i.i.i.i.i.i ], [ %62, %bb2.i.i.i.i.i.i.i.i ]
  store i64 %f.val9.i.i.i.i.i.i, ptr %57, align 8, !alias.scope !250, !noalias !251
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %vector.i) #22, !noalias !216
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb105:                                            ; preds = %bb27.i.i.i.i.i.i, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread
  %68 = phi ptr [ %53, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread ], [ %57, %bb27.i.i.i.i.i.i ]
  store i64 %nlk, ptr %68, align 8, !alias.scope !250, !noalias !251
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %lks, ptr noundef nonnull align 8 dereferenceable(24) %vector.i, i64 24, i1 false), !noalias !252
  call void @llvm.lifetime.end.p0(ptr nonnull %vector.i), !noalias !216
  call void @llvm.lifetime.start.p0(ptr nonnull %pz)
  store i64 0, ptr %pz, align 8
  %_199.sroa.8.0.pz.sroa_idx19 = getelementptr inbounds nuw i8, ptr %pz, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %_199.sroa.8.0.pz.sroa_idx19, align 8
  %_199.sroa.10.0.pz.sroa_idx21 = getelementptr inbounds nuw i8, ptr %pz, i64 16
  %69 = getelementptr inbounds nuw i8, ptr %pz, i64 24
  br i1 %pad, label %bb15, label %bb16

bb16:                                             ; preds = %bb105
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_199.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br label %bb20

bb15:                                             ; preds = %bb105
  %_20023 = lshr i64 %nlk, 1
  %_56.sroa.0.0 = sub nsw i64 %nlk, %_20023
  %_55 = add nuw nsw i64 %_56.sroa.0.0, 4
  %_207 = icmp ult i64 %_56.sroa.0.0, 6
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_199.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br i1 %_207, label %bb109, label %panic6

bb20:                                             ; preds = %bb19, %bb16
  %gf.sroa.0.0 = phi i64 [ 1, %bb19 ], [ 0, %bb16 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %poly)
  %70 = getelementptr inbounds nuw i8, ptr %poly, i64 16
  store i64 78, ptr %70, align 8
  %idx.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 24
  store ptr %0, ptr %idx.sroa.5.0..sroa_idx, align 8
  %idx.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 32
  store i64 78, ptr %idx.sroa.7.0..sroa_idx, align 8
  %71 = getelementptr inbounds nuw i8, ptr %poly, i64 152
  store i64 256, ptr %71, align 8
  %72 = getelementptr inbounds nuw i8, ptr %poly, i64 160
  store i64 %b_h.sroa.0.0, ptr %72, align 8
  %73 = getelementptr inbounds nuw i8, ptr %poly, i64 168
  store i64 %_160.sroa.0.0, ptr %73, align 8
  %74 = getelementptr inbounds nuw i8, ptr %poly, i64 176
  store i64 0, ptr %74, align 8
  %75 = getelementptr inbounds nuw i8, ptr %poly, i64 184
  store i64 19, ptr %75, align 8
  %76 = getelementptr inbounds nuw i8, ptr %poly, i64 192
  store <2 x i64> %10, ptr %76, align 8
  %77 = getelementptr inbounds nuw i8, ptr %poly, i64 208
  store <2 x i64> %12, ptr %77, align 8
  %78 = getelementptr inbounds nuw i8, ptr %poly, i64 224
  store <2 x i64> %14, ptr %78, align 8
  store i64 %gf.sroa.0.0, ptr %poly, align 8
  %79 = getelementptr inbounds nuw i8, ptr %poly, i64 8
  store i64 20, ptr %79, align 8
  %80 = getelementptr inbounds nuw i8, ptr %poly, i64 40
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %80, ptr noundef nonnull align 8 dereferenceable(24) %lks, i64 24, i1 false)
  %81 = getelementptr inbounds nuw i8, ptr %poly, i64 240
  store i64 14, ptr %81, align 8
  %82 = getelementptr inbounds nuw i8, ptr %poly, i64 64
  store i64 10, ptr %82, align 8
  %mu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 72
  store ptr %4, ptr %mu.sroa.5.0..sroa_idx, align 8
  %mu.sroa.8.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 80
  store i64 10, ptr %mu.sroa.8.0..sroa_idx, align 8
  %83 = getelementptr inbounds nuw i8, ptr %poly, i64 88
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(40) %83, ptr noundef nonnull align 8 dereferenceable(40) %pz, i64 40, i1 false)
  %84 = getelementptr inbounds nuw i8, ptr %poly, i64 248
  store i64 %b_g.sroa.0.0, ptr %84, align 8
  %85 = getelementptr inbounds nuw i8, ptr %poly, i64 256
  store i64 %_172.sroa.0.0, ptr %85, align 8
  %86 = getelementptr inbounds nuw i8, ptr %poly, i64 264
  store i64 0, ptr %86, align 8
  %87 = getelementptr inbounds nuw i8, ptr %poly, i64 128
  store i64 2, ptr %87, align 8
  %nu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 136
  store ptr %6, ptr %nu.sroa.5.0..sroa_idx, align 8
  %nu.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 144
  store i64 2, ptr %nu.sroa.7.0..sroa_idx, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !253
; call __rustc::__rust_alloc
  %88 = tail call noundef align 8 dereferenceable_or_null(272) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 272, i64 noundef 8) #20, !noalias !253
  %89 = icmp eq ptr %88, null
  br i1 %89, label %bb2.i45, label %bb21, !prof !57

bb2.i45:                                          ; preds = %bb20
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 272) #21
          to label %.noexc46 unwind label %cleanup.i

.noexc46:                                         ; preds = %bb2.i45
  unreachable

cleanup.i:                                        ; preds = %bb2.i45
  %90 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
  call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(272) %poly) #22
  br label %bb23

bb109:                                            ; preds = %bb15
  %_54 = getelementptr inbounds nuw %"field::Fp2", ptr %4, i64 %_55
  %91 = load <2 x i64>, ptr %_54, align 8
  store <2 x i64> %91, ptr %69, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !256
; call __rustc::__rust_alloc
  %92 = tail call noundef align 8 dereferenceable_or_null(88) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 88, i64 noundef 8) #20, !noalias !256
  %93 = icmp eq ptr %92, null
  br i1 %93, label %bb3.i.i49, label %bb110

bb3.i.i49:                                        ; preds = %bb109
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 88) #21
          to label %.noexc50 unwind label %bb25

.noexc50:                                         ; preds = %bb3.i.i49
  unreachable

panic6:                                           ; preds = %bb15
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_55, i64 noundef 10, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_058578575a98bb3429578f82748d5aad) #21
          to label %unreachable unwind label %bb25

bb25:                                             ; preds = %panic6, %bb3.i.i49
  %94 = landingpad { ptr, i32 }
          cleanup
  br label %bb24

bb110:                                            ; preds = %bb109
  store i64 3, ptr %92, align 8, !noalias !261
  %_3.i.i.1.i.i.i.i.i = getelementptr i8, ptr %92, i64 8
  store i64 4, ptr %_3.i.i.1.i.i.i.i.i, align 8, !noalias !274
  %_3.i.i.2.i.i.i.i.i = getelementptr i8, ptr %92, i64 16
  store i64 5, ptr %_3.i.i.2.i.i.i.i.i, align 8, !noalias !277
  %_3.i.i.3.i.i.i.i.i = getelementptr i8, ptr %92, i64 24
  store i64 6, ptr %_3.i.i.3.i.i.i.i.i, align 8, !noalias !280
  %_3.i.i.4.i.i.i.i.i = getelementptr i8, ptr %92, i64 32
  store i64 7, ptr %_3.i.i.4.i.i.i.i.i, align 8, !noalias !283
  %_3.i.i.5.i.i.i.i.i = getelementptr i8, ptr %92, i64 40
  store i64 8, ptr %_3.i.i.5.i.i.i.i.i, align 8, !noalias !286
  %_3.i.i.6.i.i.i.i.i = getelementptr i8, ptr %92, i64 48
  store i64 9, ptr %_3.i.i.6.i.i.i.i.i, align 8, !noalias !289
  %_3.i.i.7.i.i.i.i.i = getelementptr i8, ptr %92, i64 56
  store i64 10, ptr %_3.i.i.7.i.i.i.i.i, align 8, !noalias !292
  %_3.i.i.8.i.i.i.i.i = getelementptr i8, ptr %92, i64 64
  store i64 11, ptr %_3.i.i.8.i.i.i.i.i, align 8, !noalias !295
  %_3.i.i.9.i.i.i.i.i = getelementptr i8, ptr %92, i64 72
  store i64 12, ptr %_3.i.i.9.i.i.i.i.i, align 8, !noalias !298
  %_3.i.i.10.i.i.i.i.i = getelementptr i8, ptr %92, i64 80
  store i64 13, ptr %_3.i.i.10.i.i.i.i.i, align 8, !noalias !301
  %_62.not = icmp eq i64 %v.1, 37
  br i1 %_62.not, label %panic8, label %bb17

bb17:                                             ; preds = %bb110
  %95 = getelementptr inbounds nuw i8, ptr %v.0, i64 592
  %_61.0 = load i64, ptr %95, align 8, !noundef !3
  %96 = getelementptr inbounds nuw i8, ptr %v.0, i64 600
  %_61.1 = load i64, ptr %96, align 8, !noundef !3
; invoke <isolated::PadTerm>::add
  invoke fastcc void @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add(ptr noalias noundef align 8 dereferenceable(40) %pz, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %92, i64 noundef 11, i64 noundef %_61.0, i64 noundef %_61.1)
          to label %bb19 unwind label %bb25.thread

panic8:                                           ; preds = %bb110
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 37, i64 noundef 37, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_7f7b0d1637cd18edc5b90423efa8f2ac) #21
          to label %unreachable unwind label %bb25.thread

bb25.thread:                                      ; preds = %bb17, %panic8
  %97 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %92, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb24

bb19:                                             ; preds = %bb17
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %92, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb20

bb21:                                             ; preds = %bb20
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(272) %88, ptr noundef nonnull align 8 dereferenceable(272) %poly, i64 272, i1 false)
  call void @llvm.lifetime.end.p0(ptr nonnull %poly)
  call void @llvm.lifetime.end.p0(ptr nonnull %pz)
  call void @llvm.lifetime.end.p0(ptr nonnull %lks)
  call void @llvm.lifetime.end.p0(ptr nonnull %cols)
  %98 = insertvalue { ptr, ptr } poison, ptr %88, 0
  %99 = insertvalue { ptr, ptr } %98, ptr @vtable.1, 1
  ret { ptr, ptr } %99

bb24:                                             ; preds = %bb25, %bb25.thread
  %.pn101 = phi { ptr, i32 } [ %97, %bb25.thread ], [ %94, %bb25 ]
; call core::ptr::drop_glue::<isolated::PadTerm>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_(ptr noalias noundef align 8 dereferenceable(40) %pz) #22
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %lks) #22
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit: ; preds = %bb24, %cleanup1.body.i, %cleanup2
  %.pn.pn.ph = phi { ptr, i32 } [ %.pn101, %bb24 ], [ %50, %cleanup2 ], [ %eh.lpad-body.i.i.i.i.i.i, %cleanup1.body.i ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %6, i64 noundef 32, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62: ; preds = %cleanup1, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit
  %.pn26.ph = phi { ptr, i32 } [ %.pn.pn.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit ], [ %8, %cleanup1 ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %4, i64 noundef 160, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb2.i.i.i4.i64

bb23:                                             ; preds = %cleanup.i, %bb2.i.i.i4.i64
  %.pn2872 = phi { ptr, i32 } [ %.pn28.ph, %bb2.i.i.i4.i64 ], [ %90, %cleanup.i ]
  resume { ptr, i32 } %.pn2872

bb2.i.i.i4.i64:                                   ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62, %cleanup
  %.pn28.ph = phi { ptr, i32 } [ %.pn26.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62 ], [ %3, %cleanup ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %0, i64 noundef 624, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb23
}

; isolated::factory_2
; Function Attrs: noinline nonlazybind uwtable
define internal fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_2(ptr noalias noundef nonnull readonly align 8 captures(none) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %pad, i64 noundef %nlk) unnamed_addr #3 personality ptr @rust_eh_personality {
start:
  %vector.i = alloca [24 x i8], align 8
  %poly = alloca [296 x i8], align 8
  %pz = alloca [40 x i8], align 8
  %lks = alloca [24 x i8], align 8
  %cols = alloca [144 x i8], align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !304
; call __rustc::__rust_alloc
  %0 = tail call noundef align 8 dereferenceable_or_null(624) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 624, i64 noundef 8) #20, !noalias !304
  %1 = icmp eq ptr %0, null
  br i1 %1, label %bb3.i.i, label %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit

bb3.i.i:                                          ; preds = %start
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 624) #21, !noalias !309
  unreachable

_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit: ; preds = %start
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(624) %0, i8 -1, i64 624, i1 false), !noalias !309
  br label %bb2.i36

bb2.i36:                                          ; preds = %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit, %bb2.i36
  %iter.sroa.0.0114 = phi i64 [ 67, %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit ], [ %spec.select106, %bb2.i36 ]
  %_0.i3.i = icmp eq i64 %iter.sroa.0.0114, 77
  %_0.i4.i = add nuw nsw i64 %iter.sroa.0.0114, 1
  %spec.select106 = select i1 %_0.i3.i, i64 77, i64 %_0.i4.i
  %_13 = getelementptr inbounds nuw i64, ptr %0, i64 %iter.sroa.0.0114
  %2 = add nsw i64 %iter.sroa.0.0114, -64
  store i64 %2, ptr %_13, align 8
  %_0.i.not.i = icmp samesign ugt i64 %spec.select106, 77
  %or.cond = select i1 %_0.i3.i, i1 true, i1 %_0.i.not.i
  br i1 %or.cond, label %bb4, label %bb2.i36

cleanup:                                          ; preds = %bb40, %bb38
  %3 = landingpad { ptr, i32 }
          cleanup
  br label %bb2.i.i.i4.i64

bb4:                                              ; preds = %bb2.i36
  %_76 = icmp samesign ugt i64 %v.1, 34
  br i1 %_76, label %bb37, label %bb38, !prof !108

bb38:                                             ; preds = %bb4
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 25, i64 noundef 35, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_4d6b7a825e6461216f128f0802dfe2ec) #21
          to label %unreachable unwind label %cleanup

bb37:                                             ; preds = %bb4
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !310
; call __rustc::__rust_alloc
  %4 = tail call noundef align 8 dereferenceable_or_null(160) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 160, i64 noundef 8) #20, !noalias !310
  %5 = icmp eq ptr %4, null
  br i1 %5, label %bb40, label %bb41

unreachable:                                      ; preds = %bb40, %bb45, %bb102, %panic8, %panic6, %bb43, %bb38
  unreachable

bb40:                                             ; preds = %bb37
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 160) #21
          to label %unreachable unwind label %cleanup

bb41:                                             ; preds = %bb37
  %_83 = getelementptr inbounds nuw i8, ptr %v.0, i64 400
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(160) %4, ptr noundef nonnull align 8 dereferenceable(160) %_83, i64 160, i1 false)
  %_99 = icmp samesign ugt i64 %v.1, 36
  br i1 %_99, label %bb42, label %bb43, !prof !108

bb43:                                             ; preds = %bb41
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 35, i64 noundef 37, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_b8ba05bf1ee24e89bc9451481eb89547) #21
          to label %unreachable unwind label %cleanup1

bb42:                                             ; preds = %bb41
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !313
; call __rustc::__rust_alloc
  %6 = tail call noundef align 8 dereferenceable_or_null(32) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 32, i64 noundef 8) #20, !noalias !313
  %7 = icmp eq ptr %6, null
  br i1 %7, label %bb45, label %bb46

cleanup1:                                         ; preds = %bb45, %bb43
  %8 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

bb45:                                             ; preds = %bb42
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 32) #21
          to label %unreachable unwind label %cleanup1

bb46:                                             ; preds = %bb42
  %_104 = getelementptr inbounds nuw i8, ptr %v.0, i64 560
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %6, ptr noundef nonnull align 8 dereferenceable(32) %_104, i64 32, i1 false)
  %9 = getelementptr inbounds nuw i8, ptr %v.0, i64 336
  %10 = load <2 x i64>, ptr %9, align 8
  %11 = getelementptr inbounds nuw i8, ptr %v.0, i64 352
  %12 = load <2 x i64>, ptr %11, align 8
  %13 = getelementptr inbounds nuw i8, ptr %v.0, i64 368
  %14 = load <2 x i64>, ptr %13, align 8
  %15 = getelementptr inbounds nuw i8, ptr %v.0, i64 384
  %16 = load <2 x i64>, ptr %15, align 8
  %17 = and i32 %hh, 63
  %_122.not = icmp eq i32 %17, 63
  %18 = zext nneg i32 %17 to i64
  %_27 = shl nuw i64 1, %18
  %_121.sroa.0.0 = select i1 %_122.not, i64 9223372032559808513, i64 %_27
  %19 = and i32 %gg, 63
  %_134.not = icmp eq i32 %19, 63
  %20 = zext nneg i32 %19 to i64
  %_29 = shl nuw i64 1, %20
  %_133.sroa.0.0 = select i1 %_134.not, i64 9223372032559808513, i64 %_29
  %21 = icmp eq i32 %hh, 0
  %_32 = add i32 %hh, 63
  %22 = and i32 %_32, 63
  %23 = zext nneg i32 %22 to i64
  %24 = shl nuw i64 1, %23
  %_31.sroa.0.0 = select i1 %21, i64 0, i64 %24
  %_164 = icmp sgt i64 %_31.sroa.0.0, -1
  %_163.sroa.0.0 = select i1 %_164, i64 %_31.sroa.0.0, i64 9223372032559808513
  %25 = icmp eq i32 %gg, 0
  %_35 = add i32 %gg, 63
  %26 = and i32 %_35, 63
  %27 = zext nneg i32 %26 to i64
  %28 = shl nuw i64 1, %27
  %_34.sroa.0.0 = select i1 %25, i64 0, i64 %28
  %_176 = icmp sgt i64 %_34.sroa.0.0, -1
  %_175.sroa.0.0 = select i1 %_176, i64 %_34.sroa.0.0, i64 9223372032559808513
  call void @llvm.lifetime.start.p0(ptr nonnull %cols)
  %_39 = sub i32 8, %gg
  %29 = and i32 %_39, 63
  %30 = zext nneg i32 %29 to i64
  %_38 = shl nuw i64 1, %30
  %_42 = sub i32 16, %hh
  %31 = and i32 %_42, 63
  %32 = zext nneg i32 %31 to i64
  %_41 = shl nuw i64 1, %32
  store i64 68, ptr %cols, align 8
  %33 = getelementptr inbounds nuw i8, ptr %cols, i64 8
  store i64 1, ptr %33, align 8
  %34 = getelementptr inbounds nuw i8, ptr %cols, i64 16
  store i64 68, ptr %34, align 8
  %35 = getelementptr inbounds nuw i8, ptr %cols, i64 24
  store i64 %_38, ptr %35, align 8
  %36 = getelementptr inbounds nuw i8, ptr %cols, i64 32
  store i64 71, ptr %36, align 8
  %37 = getelementptr inbounds nuw i8, ptr %cols, i64 40
  store i64 1, ptr %37, align 8
  %38 = getelementptr inbounds nuw i8, ptr %cols, i64 48
  store i64 72, ptr %38, align 8
  %39 = getelementptr inbounds nuw i8, ptr %cols, i64 56
  store i64 1, ptr %39, align 8
  %40 = getelementptr inbounds nuw i8, ptr %cols, i64 64
  store i64 74, ptr %40, align 8
  %41 = getelementptr inbounds nuw i8, ptr %cols, i64 72
  store i64 1, ptr %41, align 8
  %42 = getelementptr inbounds nuw i8, ptr %cols, i64 80
  store i64 75, ptr %42, align 8
  %43 = getelementptr inbounds nuw i8, ptr %cols, i64 88
  store i64 1, ptr %43, align 8
  %44 = getelementptr inbounds nuw i8, ptr %cols, i64 96
  store i64 76, ptr %44, align 8
  %45 = getelementptr inbounds nuw i8, ptr %cols, i64 104
  store i64 1, ptr %45, align 8
  %46 = getelementptr inbounds nuw i8, ptr %cols, i64 112
  store i64 77, ptr %46, align 8
  %47 = getelementptr inbounds nuw i8, ptr %cols, i64 120
  store i64 1, ptr %47, align 8
  %48 = getelementptr inbounds nuw i8, ptr %cols, i64 128
  store i64 77, ptr %48, align 8
  %49 = getelementptr inbounds nuw i8, ptr %cols, i64 136
  store i64 %_41, ptr %49, align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %lks)
  %_188 = icmp ult i64 %nlk, 10
  br i1 %_188, label %bb101, label %bb102, !prof !115

cleanup2:                                         ; preds = %bb3.i.i43, %bb102
  %50 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb102:                                            ; preds = %bb46
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 0, i64 noundef %nlk, i64 noundef 9, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_16fb6e1cf5412ccbca18445a9781d2ea) #21
          to label %unreachable unwind label %cleanup2

bb101:                                            ; preds = %bb46
  call void @llvm.lifetime.start.p0(ptr nonnull %vector.i), !noalias !316
  %_34.0.i.i.i = mul nuw nsw i64 %nlk, 40
  %51 = icmp eq i64 %nlk, 0
  br i1 %51, label %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread, label %bb3.i.i.i

_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread: ; preds = %bb101
  store i64 0, ptr %vector.i, align 8, !noalias !316
  %52 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %52, align 8, !noalias !316
  %53 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  br label %bb105

bb3.i.i.i:                                        ; preds = %bb101
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !320
; call __rustc::__rust_alloc
  %54 = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) %_34.0.i.i.i, i64 noundef 8) #20, !noalias !320
  %55 = icmp eq ptr %54, null
  br i1 %55, label %bb3.i.i43, label %bb8.i.i.i.i.i.i.preheader

bb3.i.i43:                                        ; preds = %bb3.i.i.i
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 %_34.0.i.i.i) #21
          to label %.noexc unwind label %cleanup2

.noexc:                                           ; preds = %bb3.i.i43
  unreachable

bb8.i.i.i.i.i.i.preheader:                        ; preds = %bb3.i.i.i
  store i64 %nlk, ptr %vector.i, align 8, !noalias !316
  %56 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr %54, ptr %56, align 8, !noalias !316
  %57 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  tail call void @llvm.experimental.noalias.scope.decl(metadata !323)
  tail call void @llvm.experimental.noalias.scope.decl(metadata !326)
  br label %bb8.i.i.i.i.i.i

cleanup.i.i.i.i.i.i:                              ; preds = %bb2.i.i.i.i.i.i.i.i.i
  %58 = landingpad { ptr, i32 }
          cleanup
  br label %cleanup1.body.i

bb8.i.i.i.i.i.i:                                  ; preds = %bb8.i.i.i.i.i.i.preheader, %bb27.i.i.i.i.i.i
  %f.val9.i.i.i.i.i.i = phi i64 [ %67, %bb27.i.i.i.i.i.i ], [ 0, %bb8.i.i.i.i.i.i.preheader ]
  %_45.i.i.i.i.i.i = getelementptr inbounds nuw { i64, i64 }, ptr %cols, i64 %f.val9.i.i.i.i.i.i
  %_45.val.i.i.i.i.i.i = load i64, ptr %_45.i.i.i.i.i.i, align 8, !noalias !329
  %59 = getelementptr i8, ptr %_45.i.i.i.i.i.i, i64 8
  %_45.val10.i.i.i.i.i.i = load i64, ptr %59, align 8, !noalias !329
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !340
; call __rustc::__rust_alloc
  %60 = tail call noundef align 8 dereferenceable_or_null(16) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 16, i64 noundef 8) #20, !noalias !340
  %61 = icmp eq ptr %60, null
  br i1 %61, label %bb2.i.i.i.i.i.i.i.i.i, label %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i, !prof !57

bb2.i.i.i.i.i.i.i.i.i:                            ; preds = %bb8.i.i.i.i.i.i
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 16) #21
          to label %.noexc.i.i.i.i.i.i unwind label %cleanup.i.i.i.i.i.i, !noalias !329

.noexc.i.i.i.i.i.i:                               ; preds = %bb2.i.i.i.i.i.i.i.i.i
  unreachable

_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i: ; preds = %bb8.i.i.i.i.i.i
  %_23.i.i.i.i.i.i.i.i = icmp ult i64 %_45.val.i.i.i.i.i.i, 78
  br i1 %_23.i.i.i.i.i.i.i.i, label %bb27.i.i.i.i.i.i, label %panic.i.i.i.i.i.i.i.i

panic.i.i.i.i.i.i.i.i:                            ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_45.val.i.i.i.i.i.i, i64 noundef 78, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_9ff3b8d94994bf8c3f90654c665568fa) #21
          to label %unreachable.i.i.i.i.i.i.i.i unwind label %bb2.i.i.i.i.i.i.i.i, !noalias !340

unreachable.i.i.i.i.i.i.i.i:                      ; preds = %panic.i.i.i.i.i.i.i.i
  unreachable

bb2.i.i.i.i.i.i.i.i:                              ; preds = %panic.i.i.i.i.i.i.i.i
  %62 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %60, i64 noundef 16, i64 noundef 8) #20, !noalias !340
  br label %cleanup1.body.i

bb27.i.i.i.i.i.i:                                 ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
  %_10.i.i.i.i.i.i.i.i = getelementptr inbounds nuw i64, ptr %0, i64 %_45.val.i.i.i.i.i.i
  %_9.i.i.i.i.i.i.i.i = load i64, ptr %_10.i.i.i.i.i.i.i.i, align 8, !noalias !340, !noundef !3
  %63 = add i64 %_45.val10.i.i.i.i.i.i, -4294967296
  %64 = icmp ult i64 %63, -4294967295
  %65 = select i1 %64, i64 -4294967295, i64 -8589934590
  %_241.i.i.i.i.i.i.i.i = icmp slt i64 %_45.val10.i.i.i.i.i.i, 0
  %_26.i.i.i.i.i.i.i.i = select i1 %_241.i.i.i.i.i.i.i.i, i64 %65, i64 0
  %_12.sroa.0.0.i.i.i.i.i.i.i.i = add i64 %_26.i.i.i.i.i.i.i.i, %_45.val10.i.i.i.i.i.i
  store i64 %_9.i.i.i.i.i.i.i.i, ptr %60, align 8, !noalias !340
  %66 = getelementptr inbounds nuw i8, ptr %60, i64 8
  store i64 %_12.sroa.0.0.i.i.i.i.i.i.i.i, ptr %66, align 8, !noalias !340
  %_3.i.i.i.i.i.i.i.i.i = getelementptr inbounds nuw %LkT, ptr %54, i64 %f.val9.i.i.i.i.i.i
  store i64 1, ptr %_3.i.i.i.i.i.i.i.i.i, align 8, !noalias !345
  %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 8
  store ptr %60, ptr %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !345
  %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 16
  store i64 1, ptr %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !345
  %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 24
  store <2 x i64> %16, ptr %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !345
  %67 = add nuw i64 %f.val9.i.i.i.i.i.i, 1
  %_28.i.i.i.i.i.i = icmp eq i64 %67, %nlk
  br i1 %_28.i.i.i.i.i.i, label %bb105, label %bb8.i.i.i.i.i.i

cleanup1.body.i:                                  ; preds = %bb2.i.i.i.i.i.i.i.i, %cleanup.i.i.i.i.i.i
  %eh.lpad-body.i.i.i.i.i.i = phi { ptr, i32 } [ %58, %cleanup.i.i.i.i.i.i ], [ %62, %bb2.i.i.i.i.i.i.i.i ]
  store i64 %f.val9.i.i.i.i.i.i, ptr %57, align 8, !alias.scope !350, !noalias !351
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %vector.i) #22, !noalias !316
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb105:                                            ; preds = %bb27.i.i.i.i.i.i, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread
  %68 = phi ptr [ %53, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread ], [ %57, %bb27.i.i.i.i.i.i ]
  store i64 %nlk, ptr %68, align 8, !alias.scope !350, !noalias !351
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %lks, ptr noundef nonnull align 8 dereferenceable(24) %vector.i, i64 24, i1 false), !noalias !352
  call void @llvm.lifetime.end.p0(ptr nonnull %vector.i), !noalias !316
  call void @llvm.lifetime.start.p0(ptr nonnull %pz)
  store i64 0, ptr %pz, align 8
  %_202.sroa.8.0.pz.sroa_idx19 = getelementptr inbounds nuw i8, ptr %pz, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %_202.sroa.8.0.pz.sroa_idx19, align 8
  %_202.sroa.10.0.pz.sroa_idx21 = getelementptr inbounds nuw i8, ptr %pz, i64 16
  %69 = getelementptr inbounds nuw i8, ptr %pz, i64 24
  br i1 %pad, label %bb15, label %bb16

bb16:                                             ; preds = %bb105
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_202.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br label %bb20

bb15:                                             ; preds = %bb105
  %_20323 = lshr i64 %nlk, 1
  %_56.sroa.0.0 = sub nsw i64 %nlk, %_20323
  %_55 = add nuw nsw i64 %_56.sroa.0.0, 4
  %_210 = icmp ult i64 %_56.sroa.0.0, 6
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_202.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br i1 %_210, label %bb109, label %panic6

bb20:                                             ; preds = %bb19, %bb16
  %gf.sroa.0.0 = phi i64 [ 1, %bb19 ], [ 0, %bb16 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %poly)
  %70 = getelementptr inbounds nuw i8, ptr %poly, i64 16
  store i64 78, ptr %70, align 8
  %idx.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 24
  store ptr %0, ptr %idx.sroa.5.0..sroa_idx, align 8
  %idx.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 32
  store i64 78, ptr %idx.sroa.7.0..sroa_idx, align 8
  %71 = getelementptr inbounds nuw i8, ptr %poly, i64 152
  store i64 256, ptr %71, align 8
  %72 = getelementptr inbounds nuw i8, ptr %poly, i64 160
  store i64 0, ptr %72, align 8
  %73 = getelementptr inbounds nuw i8, ptr %poly, i64 168
  store i64 %_121.sroa.0.0, ptr %73, align 8
  %74 = getelementptr inbounds nuw i8, ptr %poly, i64 176
  store i64 0, ptr %74, align 8
  %75 = getelementptr inbounds nuw i8, ptr %poly, i64 184
  store i64 %_163.sroa.0.0, ptr %75, align 8
  %76 = getelementptr inbounds nuw i8, ptr %poly, i64 192
  store i64 0, ptr %76, align 8
  %77 = getelementptr inbounds nuw i8, ptr %poly, i64 200
  store i64 19, ptr %77, align 8
  %78 = getelementptr inbounds nuw i8, ptr %poly, i64 208
  store <2 x i64> %10, ptr %78, align 8
  %79 = getelementptr inbounds nuw i8, ptr %poly, i64 224
  store <2 x i64> %12, ptr %79, align 8
  %80 = getelementptr inbounds nuw i8, ptr %poly, i64 240
  store <2 x i64> %14, ptr %80, align 8
  store i64 %gf.sroa.0.0, ptr %poly, align 8
  %81 = getelementptr inbounds nuw i8, ptr %poly, i64 8
  store i64 20, ptr %81, align 8
  %82 = getelementptr inbounds nuw i8, ptr %poly, i64 40
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %82, ptr noundef nonnull align 8 dereferenceable(24) %lks, i64 24, i1 false)
  %83 = getelementptr inbounds nuw i8, ptr %poly, i64 256
  store i64 14, ptr %83, align 8
  %84 = getelementptr inbounds nuw i8, ptr %poly, i64 64
  store i64 10, ptr %84, align 8
  %mu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 72
  store ptr %4, ptr %mu.sroa.5.0..sroa_idx, align 8
  %mu.sroa.8.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 80
  store i64 10, ptr %mu.sroa.8.0..sroa_idx, align 8
  %85 = getelementptr inbounds nuw i8, ptr %poly, i64 88
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(40) %85, ptr noundef nonnull align 8 dereferenceable(40) %pz, i64 40, i1 false)
  %86 = getelementptr inbounds nuw i8, ptr %poly, i64 264
  store i64 %_133.sroa.0.0, ptr %86, align 8
  %87 = getelementptr inbounds nuw i8, ptr %poly, i64 272
  store i64 0, ptr %87, align 8
  %88 = getelementptr inbounds nuw i8, ptr %poly, i64 280
  store i64 %_175.sroa.0.0, ptr %88, align 8
  %89 = getelementptr inbounds nuw i8, ptr %poly, i64 288
  store i64 0, ptr %89, align 8
  %90 = getelementptr inbounds nuw i8, ptr %poly, i64 128
  store i64 2, ptr %90, align 8
  %nu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 136
  store ptr %6, ptr %nu.sroa.5.0..sroa_idx, align 8
  %nu.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 144
  store i64 2, ptr %nu.sroa.7.0..sroa_idx, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !353
; call __rustc::__rust_alloc
  %91 = tail call noundef align 8 dereferenceable_or_null(296) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 296, i64 noundef 8) #20, !noalias !353
  %92 = icmp eq ptr %91, null
  br i1 %92, label %bb2.i45, label %bb21, !prof !57

bb2.i45:                                          ; preds = %bb20
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 296) #21
          to label %.noexc46 unwind label %cleanup.i

.noexc46:                                         ; preds = %bb2.i45
  unreachable

cleanup.i:                                        ; preds = %bb2.i45
  %93 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_0::{closure#1}>
  call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(296) %poly) #22
  br label %bb23

bb109:                                            ; preds = %bb15
  %_54 = getelementptr inbounds nuw %"field::Fp2", ptr %4, i64 %_55
  %94 = load <2 x i64>, ptr %_54, align 8
  store <2 x i64> %94, ptr %69, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !356
; call __rustc::__rust_alloc
  %95 = tail call noundef align 8 dereferenceable_or_null(88) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 88, i64 noundef 8) #20, !noalias !356
  %96 = icmp eq ptr %95, null
  br i1 %96, label %bb3.i.i49, label %bb110

bb3.i.i49:                                        ; preds = %bb109
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 88) #21
          to label %.noexc50 unwind label %bb25

.noexc50:                                         ; preds = %bb3.i.i49
  unreachable

panic6:                                           ; preds = %bb15
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_55, i64 noundef 10, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_0c9e7887a13d11b191a330181159523c) #21
          to label %unreachable unwind label %bb25

bb25:                                             ; preds = %panic6, %bb3.i.i49
  %97 = landingpad { ptr, i32 }
          cleanup
  br label %bb24

bb110:                                            ; preds = %bb109
  store i64 3, ptr %95, align 8, !noalias !361
  %_3.i.i.1.i.i.i.i.i = getelementptr i8, ptr %95, i64 8
  store i64 4, ptr %_3.i.i.1.i.i.i.i.i, align 8, !noalias !374
  %_3.i.i.2.i.i.i.i.i = getelementptr i8, ptr %95, i64 16
  store i64 5, ptr %_3.i.i.2.i.i.i.i.i, align 8, !noalias !377
  %_3.i.i.3.i.i.i.i.i = getelementptr i8, ptr %95, i64 24
  store i64 6, ptr %_3.i.i.3.i.i.i.i.i, align 8, !noalias !380
  %_3.i.i.4.i.i.i.i.i = getelementptr i8, ptr %95, i64 32
  store i64 7, ptr %_3.i.i.4.i.i.i.i.i, align 8, !noalias !383
  %_3.i.i.5.i.i.i.i.i = getelementptr i8, ptr %95, i64 40
  store i64 8, ptr %_3.i.i.5.i.i.i.i.i, align 8, !noalias !386
  %_3.i.i.6.i.i.i.i.i = getelementptr i8, ptr %95, i64 48
  store i64 9, ptr %_3.i.i.6.i.i.i.i.i, align 8, !noalias !389
  %_3.i.i.7.i.i.i.i.i = getelementptr i8, ptr %95, i64 56
  store i64 10, ptr %_3.i.i.7.i.i.i.i.i, align 8, !noalias !392
  %_3.i.i.8.i.i.i.i.i = getelementptr i8, ptr %95, i64 64
  store i64 11, ptr %_3.i.i.8.i.i.i.i.i, align 8, !noalias !395
  %_3.i.i.9.i.i.i.i.i = getelementptr i8, ptr %95, i64 72
  store i64 12, ptr %_3.i.i.9.i.i.i.i.i, align 8, !noalias !398
  %_3.i.i.10.i.i.i.i.i = getelementptr i8, ptr %95, i64 80
  store i64 13, ptr %_3.i.i.10.i.i.i.i.i, align 8, !noalias !401
  %_62.not = icmp eq i64 %v.1, 37
  br i1 %_62.not, label %panic8, label %bb17

bb17:                                             ; preds = %bb110
  %98 = getelementptr inbounds nuw i8, ptr %v.0, i64 592
  %_61.0 = load i64, ptr %98, align 8, !noundef !3
  %99 = getelementptr inbounds nuw i8, ptr %v.0, i64 600
  %_61.1 = load i64, ptr %99, align 8, !noundef !3
; invoke <isolated::PadTerm>::add
  invoke fastcc void @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add(ptr noalias noundef align 8 dereferenceable(40) %pz, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %95, i64 noundef 11, i64 noundef %_61.0, i64 noundef %_61.1)
          to label %bb19 unwind label %bb25.thread

panic8:                                           ; preds = %bb110
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 37, i64 noundef 37, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_5b806d1bdaa4e2f1b1b427dca973f7a4) #21
          to label %unreachable unwind label %bb25.thread

bb25.thread:                                      ; preds = %bb17, %panic8
  %100 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %95, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb24

bb19:                                             ; preds = %bb17
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %95, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb20

bb21:                                             ; preds = %bb20
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(296) %91, ptr noundef nonnull align 8 dereferenceable(296) %poly, i64 296, i1 false)
  call void @llvm.lifetime.end.p0(ptr nonnull %poly)
  call void @llvm.lifetime.end.p0(ptr nonnull %pz)
  call void @llvm.lifetime.end.p0(ptr nonnull %lks)
  call void @llvm.lifetime.end.p0(ptr nonnull %cols)
  %101 = insertvalue { ptr, ptr } poison, ptr %91, 0
  %102 = insertvalue { ptr, ptr } %101, ptr @vtable.2, 1
  ret { ptr, ptr } %102

bb24:                                             ; preds = %bb25, %bb25.thread
  %.pn101 = phi { ptr, i32 } [ %100, %bb25.thread ], [ %97, %bb25 ]
; call core::ptr::drop_glue::<isolated::PadTerm>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_(ptr noalias noundef align 8 dereferenceable(40) %pz) #22
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %lks) #22
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit: ; preds = %bb24, %cleanup1.body.i, %cleanup2
  %.pn.pn.ph = phi { ptr, i32 } [ %.pn101, %bb24 ], [ %50, %cleanup2 ], [ %eh.lpad-body.i.i.i.i.i.i, %cleanup1.body.i ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %6, i64 noundef 32, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62: ; preds = %cleanup1, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit
  %.pn26.ph = phi { ptr, i32 } [ %.pn.pn.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit ], [ %8, %cleanup1 ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %4, i64 noundef 160, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb2.i.i.i4.i64

bb23:                                             ; preds = %cleanup.i, %bb2.i.i.i4.i64
  %.pn2872 = phi { ptr, i32 } [ %.pn28.ph, %bb2.i.i.i4.i64 ], [ %93, %cleanup.i ]
  resume { ptr, i32 } %.pn2872

bb2.i.i.i4.i64:                                   ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62, %cleanup
  %.pn28.ph = phi { ptr, i32 } [ %.pn26.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62 ], [ %3, %cleanup ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %0, i64 noundef 624, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb23
}

; isolated::factory_3
; Function Attrs: noinline nonlazybind uwtable
define internal fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_3(ptr noalias noundef nonnull readonly align 8 captures(none) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %pad, i64 noundef %nlk) unnamed_addr #3 personality ptr @rust_eh_personality {
start:
  %vector.i = alloca [24 x i8], align 8
  %poly = alloca [272 x i8], align 8
  %pz = alloca [40 x i8], align 8
  %lks = alloca [24 x i8], align 8
  %cols = alloca [144 x i8], align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !404
; call __rustc::__rust_alloc
  %0 = tail call noundef align 8 dereferenceable_or_null(624) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 624, i64 noundef 8) #20, !noalias !404
  %1 = icmp eq ptr %0, null
  br i1 %1, label %bb3.i.i, label %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit

bb3.i.i:                                          ; preds = %start
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 624) #21, !noalias !409
  unreachable

_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit: ; preds = %start
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(624) %0, i8 -1, i64 624, i1 false), !noalias !409
  br label %bb2.i36

bb2.i36:                                          ; preds = %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit, %bb2.i36
  %iter.sroa.0.0114 = phi i64 [ 67, %_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated.exit ], [ %spec.select106, %bb2.i36 ]
  %_0.i3.i = icmp eq i64 %iter.sroa.0.0114, 77
  %_0.i4.i = add nuw nsw i64 %iter.sroa.0.0114, 1
  %spec.select106 = select i1 %_0.i3.i, i64 77, i64 %_0.i4.i
  %_13 = getelementptr inbounds nuw i64, ptr %0, i64 %iter.sroa.0.0114
  %2 = add nsw i64 %iter.sroa.0.0114, -64
  store i64 %2, ptr %_13, align 8
  %_0.i.not.i = icmp samesign ugt i64 %spec.select106, 77
  %or.cond = select i1 %_0.i3.i, i1 true, i1 %_0.i.not.i
  br i1 %or.cond, label %bb4, label %bb2.i36

cleanup:                                          ; preds = %bb40, %bb38
  %3 = landingpad { ptr, i32 }
          cleanup
  br label %bb2.i.i.i4.i64

bb4:                                              ; preds = %bb2.i36
  %_76 = icmp samesign ugt i64 %v.1, 34
  br i1 %_76, label %bb37, label %bb38, !prof !108

bb38:                                             ; preds = %bb4
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 25, i64 noundef 35, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_26fc8e81fc819c8a9f630ccd48e47036) #21
          to label %unreachable unwind label %cleanup

bb37:                                             ; preds = %bb4
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !410
; call __rustc::__rust_alloc
  %4 = tail call noundef align 8 dereferenceable_or_null(160) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 160, i64 noundef 8) #20, !noalias !410
  %5 = icmp eq ptr %4, null
  br i1 %5, label %bb40, label %bb41

unreachable:                                      ; preds = %bb40, %bb45, %bb102, %panic8, %panic6, %bb43, %bb38
  unreachable

bb40:                                             ; preds = %bb37
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 160) #21
          to label %unreachable unwind label %cleanup

bb41:                                             ; preds = %bb37
  %_83 = getelementptr inbounds nuw i8, ptr %v.0, i64 400
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(160) %4, ptr noundef nonnull align 8 dereferenceable(160) %_83, i64 160, i1 false)
  %_99 = icmp samesign ugt i64 %v.1, 36
  br i1 %_99, label %bb42, label %bb43, !prof !108

bb43:                                             ; preds = %bb41
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 35, i64 noundef 37, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_529870ce56aabb58b099913f27113d23) #21
          to label %unreachable unwind label %cleanup1

bb42:                                             ; preds = %bb41
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !413
; call __rustc::__rust_alloc
  %6 = tail call noundef align 8 dereferenceable_or_null(32) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 32, i64 noundef 8) #20, !noalias !413
  %7 = icmp eq ptr %6, null
  br i1 %7, label %bb45, label %bb46

cleanup1:                                         ; preds = %bb45, %bb43
  %8 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

bb45:                                             ; preds = %bb42
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 32) #21
          to label %unreachable unwind label %cleanup1

bb46:                                             ; preds = %bb42
  %_104 = getelementptr inbounds nuw i8, ptr %v.0, i64 560
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(32) %6, ptr noundef nonnull align 8 dereferenceable(32) %_104, i64 32, i1 false)
  %9 = getelementptr inbounds nuw i8, ptr %v.0, i64 336
  %10 = load <2 x i64>, ptr %9, align 8
  %11 = getelementptr inbounds nuw i8, ptr %v.0, i64 352
  %12 = load <2 x i64>, ptr %11, align 8
  %13 = getelementptr inbounds nuw i8, ptr %v.0, i64 368
  %14 = load <2 x i64>, ptr %13, align 8
  %15 = getelementptr inbounds nuw i8, ptr %v.0, i64 384
  %16 = load <2 x i64>, ptr %15, align 8
  %17 = and i32 %hh, 63
  %18 = zext nneg i32 %17 to i64
  %_26 = shl nuw i64 1, %18
  %_120.not = icmp eq i32 %17, 63
  %19 = and i32 %gg, 63
  %20 = zext nneg i32 %19 to i64
  %_27 = shl nuw i64 1, %20
  %_130.not = icmp eq i32 %19, 63
  %b_h.sroa.0.0 = select i1 %_120.not, i64 9223372032559808513, i64 %_26
  %b_g.sroa.0.0 = select i1 %_130.not, i64 9223372032559808513, i64 %_27
  %21 = icmp eq i32 %hh, 0
  %_32 = add i32 %hh, 63
  %22 = and i32 %_32, 63
  %23 = zext nneg i32 %22 to i64
  %24 = shl nuw i64 1, %23
  %_31.sroa.0.0 = select i1 %21, i64 0, i64 %24
  %_161 = icmp sgt i64 %_31.sroa.0.0, -1
  %_160.sroa.0.0 = select i1 %_161, i64 %_31.sroa.0.0, i64 9223372032559808513
  %25 = icmp eq i32 %gg, 0
  %_35 = add i32 %gg, 63
  %26 = and i32 %_35, 63
  %27 = zext nneg i32 %26 to i64
  %28 = shl nuw i64 1, %27
  %_34.sroa.0.0 = select i1 %25, i64 0, i64 %28
  %_173 = icmp sgt i64 %_34.sroa.0.0, -1
  %_172.sroa.0.0 = select i1 %_173, i64 %_34.sroa.0.0, i64 9223372032559808513
  call void @llvm.lifetime.start.p0(ptr nonnull %cols)
  %_39 = sub i32 8, %gg
  %29 = and i32 %_39, 63
  %30 = zext nneg i32 %29 to i64
  %_38 = shl nuw i64 1, %30
  %_42 = sub i32 16, %hh
  %31 = and i32 %_42, 63
  %32 = zext nneg i32 %31 to i64
  %_41 = shl nuw i64 1, %32
  store i64 68, ptr %cols, align 8
  %33 = getelementptr inbounds nuw i8, ptr %cols, i64 8
  store i64 1, ptr %33, align 8
  %34 = getelementptr inbounds nuw i8, ptr %cols, i64 16
  store i64 68, ptr %34, align 8
  %35 = getelementptr inbounds nuw i8, ptr %cols, i64 24
  store i64 %_38, ptr %35, align 8
  %36 = getelementptr inbounds nuw i8, ptr %cols, i64 32
  store i64 71, ptr %36, align 8
  %37 = getelementptr inbounds nuw i8, ptr %cols, i64 40
  store i64 1, ptr %37, align 8
  %38 = getelementptr inbounds nuw i8, ptr %cols, i64 48
  store i64 72, ptr %38, align 8
  %39 = getelementptr inbounds nuw i8, ptr %cols, i64 56
  store i64 1, ptr %39, align 8
  %40 = getelementptr inbounds nuw i8, ptr %cols, i64 64
  store i64 74, ptr %40, align 8
  %41 = getelementptr inbounds nuw i8, ptr %cols, i64 72
  store i64 1, ptr %41, align 8
  %42 = getelementptr inbounds nuw i8, ptr %cols, i64 80
  store i64 75, ptr %42, align 8
  %43 = getelementptr inbounds nuw i8, ptr %cols, i64 88
  store i64 1, ptr %43, align 8
  %44 = getelementptr inbounds nuw i8, ptr %cols, i64 96
  store i64 76, ptr %44, align 8
  %45 = getelementptr inbounds nuw i8, ptr %cols, i64 104
  store i64 1, ptr %45, align 8
  %46 = getelementptr inbounds nuw i8, ptr %cols, i64 112
  store i64 77, ptr %46, align 8
  %47 = getelementptr inbounds nuw i8, ptr %cols, i64 120
  store i64 1, ptr %47, align 8
  %48 = getelementptr inbounds nuw i8, ptr %cols, i64 128
  store i64 77, ptr %48, align 8
  %49 = getelementptr inbounds nuw i8, ptr %cols, i64 136
  store i64 %_41, ptr %49, align 8
  call void @llvm.lifetime.start.p0(ptr nonnull %lks)
  %_185 = icmp ult i64 %nlk, 10
  br i1 %_185, label %bb101, label %bb102, !prof !115

cleanup2:                                         ; preds = %bb3.i.i43, %bb102
  %50 = landingpad { ptr, i32 }
          cleanup
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb102:                                            ; preds = %bb46
; invoke core::slice::index::slice_index_fail
  invoke void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef 0, i64 noundef %nlk, i64 noundef 9, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_36684b31319358aad4985691b5adb1d1) #21
          to label %unreachable unwind label %cleanup2

bb101:                                            ; preds = %bb46
  call void @llvm.lifetime.start.p0(ptr nonnull %vector.i), !noalias !416
  %_34.0.i.i.i = mul nuw nsw i64 %nlk, 40
  %51 = icmp eq i64 %nlk, 0
  br i1 %51, label %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread, label %bb3.i.i.i

_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread: ; preds = %bb101
  store i64 0, ptr %vector.i, align 8, !noalias !416
  %52 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %52, align 8, !noalias !416
  %53 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  br label %bb105

bb3.i.i.i:                                        ; preds = %bb101
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !420
; call __rustc::__rust_alloc
  %54 = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) %_34.0.i.i.i, i64 noundef 8) #20, !noalias !420
  %55 = icmp eq ptr %54, null
  br i1 %55, label %bb3.i.i43, label %bb8.i.i.i.i.i.i.preheader

bb3.i.i43:                                        ; preds = %bb3.i.i.i
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 %_34.0.i.i.i) #21
          to label %.noexc unwind label %cleanup2

.noexc:                                           ; preds = %bb3.i.i43
  unreachable

bb8.i.i.i.i.i.i.preheader:                        ; preds = %bb3.i.i.i
  store i64 %nlk, ptr %vector.i, align 8, !noalias !416
  %56 = getelementptr inbounds nuw i8, ptr %vector.i, i64 8
  store ptr %54, ptr %56, align 8, !noalias !416
  %57 = getelementptr inbounds nuw i8, ptr %vector.i, i64 16
  tail call void @llvm.experimental.noalias.scope.decl(metadata !423)
  tail call void @llvm.experimental.noalias.scope.decl(metadata !426)
  br label %bb8.i.i.i.i.i.i

cleanup.i.i.i.i.i.i:                              ; preds = %bb2.i.i.i.i.i.i.i.i.i
  %58 = landingpad { ptr, i32 }
          cleanup
  br label %cleanup1.body.i

bb8.i.i.i.i.i.i:                                  ; preds = %bb8.i.i.i.i.i.i.preheader, %bb27.i.i.i.i.i.i
  %f.val9.i.i.i.i.i.i = phi i64 [ %67, %bb27.i.i.i.i.i.i ], [ 0, %bb8.i.i.i.i.i.i.preheader ]
  %_45.i.i.i.i.i.i = getelementptr inbounds nuw { i64, i64 }, ptr %cols, i64 %f.val9.i.i.i.i.i.i
  %_45.val.i.i.i.i.i.i = load i64, ptr %_45.i.i.i.i.i.i, align 8, !noalias !429
  %59 = getelementptr i8, ptr %_45.i.i.i.i.i.i, i64 8
  %_45.val10.i.i.i.i.i.i = load i64, ptr %59, align 8, !noalias !429
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !440
; call __rustc::__rust_alloc
  %60 = tail call noundef align 8 dereferenceable_or_null(16) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 16, i64 noundef 8) #20, !noalias !440
  %61 = icmp eq ptr %60, null
  br i1 %61, label %bb2.i.i.i.i.i.i.i.i.i, label %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i, !prof !57

bb2.i.i.i.i.i.i.i.i.i:                            ; preds = %bb8.i.i.i.i.i.i
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 16) #21
          to label %.noexc.i.i.i.i.i.i unwind label %cleanup.i.i.i.i.i.i, !noalias !429

.noexc.i.i.i.i.i.i:                               ; preds = %bb2.i.i.i.i.i.i.i.i.i
  unreachable

_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i: ; preds = %bb8.i.i.i.i.i.i
  %_23.i.i.i.i.i.i.i.i = icmp ult i64 %_45.val.i.i.i.i.i.i, 78
  br i1 %_23.i.i.i.i.i.i.i.i, label %bb27.i.i.i.i.i.i, label %panic.i.i.i.i.i.i.i.i

panic.i.i.i.i.i.i.i.i:                            ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_45.val.i.i.i.i.i.i, i64 noundef 78, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_413c07112253bea69b9c0ea7f62d2d3b) #21
          to label %unreachable.i.i.i.i.i.i.i.i unwind label %bb2.i.i.i.i.i.i.i.i, !noalias !440

unreachable.i.i.i.i.i.i.i.i:                      ; preds = %panic.i.i.i.i.i.i.i.i
  unreachable

bb2.i.i.i.i.i.i.i.i:                              ; preds = %panic.i.i.i.i.i.i.i.i
  %62 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %60, i64 noundef 16, i64 noundef 8) #20, !noalias !440
  br label %cleanup1.body.i

bb27.i.i.i.i.i.i:                                 ; preds = %_RNvNtCs40k4W9msRzi_5alloc5boxed14box_new_uninit.exit.i.i.i.i.i.i.i.i
  %_10.i.i.i.i.i.i.i.i = getelementptr inbounds nuw i64, ptr %0, i64 %_45.val.i.i.i.i.i.i
  %_9.i.i.i.i.i.i.i.i = load i64, ptr %_10.i.i.i.i.i.i.i.i, align 8, !noalias !440, !noundef !3
  %63 = add i64 %_45.val10.i.i.i.i.i.i, -4294967296
  %64 = icmp ult i64 %63, -4294967295
  %65 = select i1 %64, i64 -4294967295, i64 -8589934590
  %_241.i.i.i.i.i.i.i.i = icmp slt i64 %_45.val10.i.i.i.i.i.i, 0
  %_26.i.i.i.i.i.i.i.i = select i1 %_241.i.i.i.i.i.i.i.i, i64 %65, i64 0
  %_12.sroa.0.0.i.i.i.i.i.i.i.i = add i64 %_26.i.i.i.i.i.i.i.i, %_45.val10.i.i.i.i.i.i
  store i64 %_9.i.i.i.i.i.i.i.i, ptr %60, align 8, !noalias !440
  %66 = getelementptr inbounds nuw i8, ptr %60, i64 8
  store i64 %_12.sroa.0.0.i.i.i.i.i.i.i.i, ptr %66, align 8, !noalias !440
  %_3.i.i.i.i.i.i.i.i.i = getelementptr inbounds nuw %LkT, ptr %54, i64 %f.val9.i.i.i.i.i.i
  store i64 1, ptr %_3.i.i.i.i.i.i.i.i.i, align 8, !noalias !445
  %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 8
  store ptr %60, ptr %_5.sroa.4.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !445
  %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 16
  store i64 1, ptr %_5.sroa.5.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !445
  %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %_3.i.i.i.i.i.i.i.i.i, i64 24
  store <2 x i64> %16, ptr %_5.sroa.6.0._3.i.i.sroa_idx.i.i.i.i.i.i.i, align 8, !noalias !445
  %67 = add nuw i64 %f.val9.i.i.i.i.i.i, 1
  %_28.i.i.i.i.i.i = icmp eq i64 %67, %nlk
  br i1 %_28.i.i.i.i.i.i, label %bb105, label %bb8.i.i.i.i.i.i

cleanup1.body.i:                                  ; preds = %bb2.i.i.i.i.i.i.i.i, %cleanup.i.i.i.i.i.i
  %eh.lpad-body.i.i.i.i.i.i = phi { ptr, i32 } [ %58, %cleanup.i.i.i.i.i.i ], [ %62, %bb2.i.i.i.i.i.i.i.i ]
  store i64 %f.val9.i.i.i.i.i.i, ptr %57, align 8, !alias.scope !450, !noalias !451
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %vector.i) #22, !noalias !416
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

bb105:                                            ; preds = %bb27.i.i.i.i.i.i, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread
  %68 = phi ptr [ %53, %_RNvMs_NtCs40k4W9msRzi_5alloc3vecINtB4_3VecNtCsl0YfJI2rrfI_8isolated3LkTE7reserveBG_.exit.i.i.i.thread ], [ %57, %bb27.i.i.i.i.i.i ]
  store i64 %nlk, ptr %68, align 8, !alias.scope !450, !noalias !451
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %lks, ptr noundef nonnull align 8 dereferenceable(24) %vector.i, i64 24, i1 false), !noalias !452
  call void @llvm.lifetime.end.p0(ptr nonnull %vector.i), !noalias !416
  call void @llvm.lifetime.start.p0(ptr nonnull %pz)
  store i64 0, ptr %pz, align 8
  %_199.sroa.8.0.pz.sroa_idx19 = getelementptr inbounds nuw i8, ptr %pz, i64 8
  store ptr inttoptr (i64 8 to ptr), ptr %_199.sroa.8.0.pz.sroa_idx19, align 8
  %_199.sroa.10.0.pz.sroa_idx21 = getelementptr inbounds nuw i8, ptr %pz, i64 16
  %69 = getelementptr inbounds nuw i8, ptr %pz, i64 24
  br i1 %pad, label %bb15, label %bb16

bb16:                                             ; preds = %bb105
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_199.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br label %bb20

bb15:                                             ; preds = %bb105
  %_20023 = lshr i64 %nlk, 1
  %_56.sroa.0.0 = sub nsw i64 %nlk, %_20023
  %_55 = add nuw nsw i64 %_56.sroa.0.0, 4
  %_207 = icmp ult i64 %_56.sroa.0.0, 6
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %_199.sroa.10.0.pz.sroa_idx21, i8 0, i64 24, i1 false)
  br i1 %_207, label %bb109, label %panic6

bb20:                                             ; preds = %bb19, %bb16
  %gf.sroa.0.0 = phi i64 [ 1, %bb19 ], [ 0, %bb16 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %poly)
  %70 = getelementptr inbounds nuw i8, ptr %poly, i64 16
  store i64 78, ptr %70, align 8
  %idx.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 24
  store ptr %0, ptr %idx.sroa.5.0..sroa_idx, align 8
  %idx.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 32
  store i64 78, ptr %idx.sroa.7.0..sroa_idx, align 8
  %71 = getelementptr inbounds nuw i8, ptr %poly, i64 152
  store i64 256, ptr %71, align 8
  %72 = getelementptr inbounds nuw i8, ptr %poly, i64 160
  store i64 %b_h.sroa.0.0, ptr %72, align 8
  %73 = getelementptr inbounds nuw i8, ptr %poly, i64 168
  store i64 %_160.sroa.0.0, ptr %73, align 8
  %74 = getelementptr inbounds nuw i8, ptr %poly, i64 176
  store i64 0, ptr %74, align 8
  %75 = getelementptr inbounds nuw i8, ptr %poly, i64 184
  store i64 19, ptr %75, align 8
  %76 = getelementptr inbounds nuw i8, ptr %poly, i64 192
  store <2 x i64> %10, ptr %76, align 8
  %77 = getelementptr inbounds nuw i8, ptr %poly, i64 208
  store <2 x i64> %12, ptr %77, align 8
  %78 = getelementptr inbounds nuw i8, ptr %poly, i64 224
  store <2 x i64> %14, ptr %78, align 8
  store i64 %gf.sroa.0.0, ptr %poly, align 8
  %79 = getelementptr inbounds nuw i8, ptr %poly, i64 8
  store i64 20, ptr %79, align 8
  %80 = getelementptr inbounds nuw i8, ptr %poly, i64 40
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(24) %80, ptr noundef nonnull align 8 dereferenceable(24) %lks, i64 24, i1 false)
  %81 = getelementptr inbounds nuw i8, ptr %poly, i64 240
  store i64 14, ptr %81, align 8
  %82 = getelementptr inbounds nuw i8, ptr %poly, i64 64
  store i64 10, ptr %82, align 8
  %mu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 72
  store ptr %4, ptr %mu.sroa.5.0..sroa_idx, align 8
  %mu.sroa.8.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 80
  store i64 10, ptr %mu.sroa.8.0..sroa_idx, align 8
  %83 = getelementptr inbounds nuw i8, ptr %poly, i64 88
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(40) %83, ptr noundef nonnull align 8 dereferenceable(40) %pz, i64 40, i1 false)
  %84 = getelementptr inbounds nuw i8, ptr %poly, i64 248
  store i64 %b_g.sroa.0.0, ptr %84, align 8
  %85 = getelementptr inbounds nuw i8, ptr %poly, i64 256
  store i64 %_172.sroa.0.0, ptr %85, align 8
  %86 = getelementptr inbounds nuw i8, ptr %poly, i64 264
  store i64 0, ptr %86, align 8
  %87 = getelementptr inbounds nuw i8, ptr %poly, i64 128
  store i64 2, ptr %87, align 8
  %nu.sroa.5.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 136
  store ptr %6, ptr %nu.sroa.5.0..sroa_idx, align 8
  %nu.sroa.7.0..sroa_idx = getelementptr inbounds nuw i8, ptr %poly, i64 144
  store i64 2, ptr %nu.sroa.7.0..sroa_idx, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !453
; call __rustc::__rust_alloc
  %88 = tail call noundef align 8 dereferenceable_or_null(272) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 272, i64 noundef 8) #20, !noalias !453
  %89 = icmp eq ptr %88, null
  br i1 %89, label %bb2.i45, label %bb21, !prof !57

bb2.i45:                                          ; preds = %bb20
; invoke alloc::alloc::handle_alloc_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef 8, i64 noundef 272) #21
          to label %.noexc46 unwind label %cleanup.i

.noexc46:                                         ; preds = %bb2.i45
  unreachable

cleanup.i:                                        ; preds = %bb2.i45
  %90 = landingpad { ptr, i32 }
          cleanup
; call core::ptr::drop_glue::<isolated::factory_1::{closure#1}>
  call void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0EBF_(ptr noalias noundef nonnull align 8 dereferenceable(272) %poly) #22
  br label %bb23

bb109:                                            ; preds = %bb15
  %_54 = getelementptr inbounds nuw %"field::Fp2", ptr %4, i64 %_55
  %91 = load <2 x i64>, ptr %_54, align 8
  store <2 x i64> %91, ptr %69, align 8
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !456
; call __rustc::__rust_alloc
  %92 = tail call noundef align 8 dereferenceable_or_null(88) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 88, i64 noundef 8) #20, !noalias !456
  %93 = icmp eq ptr %92, null
  br i1 %93, label %bb3.i.i49, label %bb110

bb3.i.i49:                                        ; preds = %bb109
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 88) #21
          to label %.noexc50 unwind label %bb25

.noexc50:                                         ; preds = %bb3.i.i49
  unreachable

panic6:                                           ; preds = %bb15
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_55, i64 noundef 10, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_f861b8e02d0300dcb721b5d1c9a678c4) #21
          to label %unreachable unwind label %bb25

bb25:                                             ; preds = %panic6, %bb3.i.i49
  %94 = landingpad { ptr, i32 }
          cleanup
  br label %bb24

bb110:                                            ; preds = %bb109
  store i64 3, ptr %92, align 8, !noalias !461
  %_3.i.i.1.i.i.i.i.i = getelementptr i8, ptr %92, i64 8
  store i64 4, ptr %_3.i.i.1.i.i.i.i.i, align 8, !noalias !474
  %_3.i.i.2.i.i.i.i.i = getelementptr i8, ptr %92, i64 16
  store i64 5, ptr %_3.i.i.2.i.i.i.i.i, align 8, !noalias !477
  %_3.i.i.3.i.i.i.i.i = getelementptr i8, ptr %92, i64 24
  store i64 6, ptr %_3.i.i.3.i.i.i.i.i, align 8, !noalias !480
  %_3.i.i.4.i.i.i.i.i = getelementptr i8, ptr %92, i64 32
  store i64 7, ptr %_3.i.i.4.i.i.i.i.i, align 8, !noalias !483
  %_3.i.i.5.i.i.i.i.i = getelementptr i8, ptr %92, i64 40
  store i64 8, ptr %_3.i.i.5.i.i.i.i.i, align 8, !noalias !486
  %_3.i.i.6.i.i.i.i.i = getelementptr i8, ptr %92, i64 48
  store i64 9, ptr %_3.i.i.6.i.i.i.i.i, align 8, !noalias !489
  %_3.i.i.7.i.i.i.i.i = getelementptr i8, ptr %92, i64 56
  store i64 10, ptr %_3.i.i.7.i.i.i.i.i, align 8, !noalias !492
  %_3.i.i.8.i.i.i.i.i = getelementptr i8, ptr %92, i64 64
  store i64 11, ptr %_3.i.i.8.i.i.i.i.i, align 8, !noalias !495
  %_3.i.i.9.i.i.i.i.i = getelementptr i8, ptr %92, i64 72
  store i64 12, ptr %_3.i.i.9.i.i.i.i.i, align 8, !noalias !498
  %_3.i.i.10.i.i.i.i.i = getelementptr i8, ptr %92, i64 80
  store i64 13, ptr %_3.i.i.10.i.i.i.i.i, align 8, !noalias !501
  %_62.not = icmp eq i64 %v.1, 37
  br i1 %_62.not, label %panic8, label %bb17

bb17:                                             ; preds = %bb110
  %95 = getelementptr inbounds nuw i8, ptr %v.0, i64 592
  %_61.0 = load i64, ptr %95, align 8, !noundef !3
  %96 = getelementptr inbounds nuw i8, ptr %v.0, i64 600
  %_61.1 = load i64, ptr %96, align 8, !noundef !3
; invoke <isolated::PadTerm>::add
  invoke fastcc void @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add(ptr noalias noundef align 8 dereferenceable(40) %pz, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %92, i64 noundef 11, i64 noundef %_61.0, i64 noundef %_61.1)
          to label %bb19 unwind label %bb25.thread

panic8:                                           ; preds = %bb110
; invoke core::panicking::panic_bounds_check
  invoke void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef 37, i64 noundef 37, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_20064a57f7955b3dc6ee7ae10e9bd5ab) #21
          to label %unreachable unwind label %bb25.thread

bb25.thread:                                      ; preds = %bb17, %panic8
  %97 = landingpad { ptr, i32 }
          cleanup
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %92, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb24

bb19:                                             ; preds = %bb17
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %92, i64 noundef 88, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb20

bb21:                                             ; preds = %bb20
  call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(272) %88, ptr noundef nonnull align 8 dereferenceable(272) %poly, i64 272, i1 false)
  call void @llvm.lifetime.end.p0(ptr nonnull %poly)
  call void @llvm.lifetime.end.p0(ptr nonnull %pz)
  call void @llvm.lifetime.end.p0(ptr nonnull %lks)
  call void @llvm.lifetime.end.p0(ptr nonnull %cols)
  %98 = insertvalue { ptr, ptr } poison, ptr %88, 0
  %99 = insertvalue { ptr, ptr } %98, ptr @vtable.3, 1
  ret { ptr, ptr } %99

bb24:                                             ; preds = %bb25, %bb25.thread
  %.pn101 = phi { ptr, i32 } [ %97, %bb25.thread ], [ %94, %bb25 ]
; call core::ptr::drop_glue::<isolated::PadTerm>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_(ptr noalias noundef align 8 dereferenceable(40) %pz) #22
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::LkT>>
  call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_(ptr noalias noundef align 8 dereferenceable(24) %lks) #22
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit: ; preds = %bb24, %cleanup1.body.i, %cleanup2
  %.pn.pn.ph = phi { ptr, i32 } [ %.pn101, %bb24 ], [ %50, %cleanup2 ], [ %eh.lpad-body.i.i.i.i.i.i, %cleanup1.body.i ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %6, i64 noundef 32, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62

_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62: ; preds = %cleanup1, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit
  %.pn26.ph = phi { ptr, i32 } [ %.pn.pn.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit ], [ %8, %cleanup1 ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %4, i64 noundef 160, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb2.i.i.i4.i64

bb23:                                             ; preds = %cleanup.i, %bb2.i.i.i4.i64
  %.pn2872 = phi { ptr, i32 } [ %.pn28.ph, %bb2.i.i.i4.i64 ], [ %90, %cleanup.i ]
  resume { ptr, i32 } %.pn2872

bb2.i.i.i4.i64:                                   ; preds = %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62, %cleanup
  %.pn28.ph = phi { ptr, i32 } [ %.pn26.ph, %_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_.exit62 ], [ %3, %cleanup ]
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %0, i64 noundef 624, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb23
}

; <isolated::PadTerm>::add
; Function Attrs: nonlazybind uwtable
define internal fastcc void @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm3add(ptr noalias noundef nonnull align 8 captures(none) dereferenceable(40) %self, ptr noalias noundef nonnull readonly align 8 captures(address) %planes.0, i64 noundef range(i64 0, 1152921504606846976) %planes.1, i64 noundef %zeta.0, i64 noundef %zeta.1) unnamed_addr #1 personality ptr @rust_eh_personality {
start:
  %g = alloca [24 x i8], align 8
  %0 = icmp eq i64 %planes.1, 0
  br i1 %0, label %bb9, label %bb3

bb9:                                              ; preds = %start, %bb22
  ret void

bb3:                                              ; preds = %start
  %1 = getelementptr inbounds nuw i8, ptr %self, i64 8
  %_28 = load ptr, ptr %1, align 8, !nonnull !3, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %self, i64 16
  %_27 = load i64, ptr %2, align 8, !noundef !3
  %3 = icmp eq i64 %_27, 0
  br i1 %3, label %bb15, label %bb8.i.preheader

bb8.i.preheader:                                  ; preds = %bb3
  %xtraiter = and i64 %_27, 3
  %4 = icmp ult i64 %_27, 4
  br i1 %4, label %bb8.i.epil.preheader, label %bb8.i.preheader.new

bb8.i.preheader.new:                              ; preds = %bb8.i.preheader
  %unroll_iter = and i64 %_27, -4
  br label %bb8.i

bb8.i:                                            ; preds = %bb8.i, %bb8.i.preheader.new
  %i.sroa.0.0.i = phi i64 [ 0, %bb8.i.preheader.new ], [ %_27.i.3, %bb8.i ]
  %acc.sroa.0.0.i = phi i64 [ 0, %bb8.i.preheader.new ], [ %_4.0.i.i.i.3, %bb8.i ]
  %niter = phi i64 [ 0, %bb8.i.preheader.new ], [ %niter.next.3, %bb8.i ]
  %_45.i = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_28, i64 %i.sroa.0.0.i
  %5 = getelementptr i8, ptr %_45.i, i64 24
  %_45.val.i = load i64, ptr %5, align 8, !noundef !3
  %_4.i.i.i = icmp ult i64 %_45.val.i, 384307168202282326
  tail call void @llvm.assume(i1 %_4.i.i.i)
  %_4.0.i.i.i = add i64 %_45.val.i, %acc.sroa.0.0.i
  %6 = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_28, i64 %i.sroa.0.0.i
  %7 = getelementptr i8, ptr %6, i64 56
  %_45.val.i.1 = load i64, ptr %7, align 8, !noundef !3
  %_4.i.i.i.1 = icmp ult i64 %_45.val.i.1, 384307168202282326
  tail call void @llvm.assume(i1 %_4.i.i.i.1)
  %_4.0.i.i.i.1 = add i64 %_45.val.i.1, %_4.0.i.i.i
  %8 = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_28, i64 %i.sroa.0.0.i
  %9 = getelementptr i8, ptr %8, i64 88
  %_45.val.i.2 = load i64, ptr %9, align 8, !noundef !3
  %_4.i.i.i.2 = icmp ult i64 %_45.val.i.2, 384307168202282326
  tail call void @llvm.assume(i1 %_4.i.i.i.2)
  %_4.0.i.i.i.2 = add i64 %_45.val.i.2, %_4.0.i.i.i.1
  %10 = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_28, i64 %i.sroa.0.0.i
  %11 = getelementptr i8, ptr %10, i64 120
  %_45.val.i.3 = load i64, ptr %11, align 8, !noundef !3
  %_4.i.i.i.3 = icmp ult i64 %_45.val.i.3, 384307168202282326
  tail call void @llvm.assume(i1 %_4.i.i.i.3)
  %_4.0.i.i.i.3 = add i64 %_45.val.i.3, %_4.0.i.i.i.2
  %_27.i.3 = add nuw i64 %i.sroa.0.0.i, 4
  %niter.next.3 = add i64 %niter, 4
  %niter.ncmp.3 = icmp eq i64 %niter.next.3, %unroll_iter
  br i1 %niter.ncmp.3, label %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa, label %bb8.i

_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa: ; preds = %bb8.i
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0
  br i1 %lcmp.mod.not, label %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit, label %bb8.i.epil.preheader

bb8.i.epil.preheader:                             ; preds = %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa, %bb8.i.preheader
  %i.sroa.0.0.i.epil.init = phi i64 [ 0, %bb8.i.preheader ], [ %_27.i.3, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa ]
  %acc.sroa.0.0.i.epil.init = phi i64 [ 0, %bb8.i.preheader ], [ %_4.0.i.i.i.3, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa ]
  %lcmp.mod2 = icmp ne i64 %xtraiter, 0
  tail call void @llvm.assume(i1 %lcmp.mod2)
  br label %bb8.i.epil

bb8.i.epil:                                       ; preds = %bb8.i.epil, %bb8.i.epil.preheader
  %i.sroa.0.0.i.epil = phi i64 [ %_27.i.epil, %bb8.i.epil ], [ %i.sroa.0.0.i.epil.init, %bb8.i.epil.preheader ]
  %acc.sroa.0.0.i.epil = phi i64 [ %_4.0.i.i.i.epil, %bb8.i.epil ], [ %acc.sroa.0.0.i.epil.init, %bb8.i.epil.preheader ]
  %epil.iter = phi i64 [ %epil.iter.next, %bb8.i.epil ], [ 0, %bb8.i.epil.preheader ]
  %_45.i.epil = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_28, i64 %i.sroa.0.0.i.epil
  %12 = getelementptr i8, ptr %_45.i.epil, i64 24
  %_45.val.i.epil = load i64, ptr %12, align 8, !noundef !3
  %_4.i.i.i.epil = icmp ult i64 %_45.val.i.epil, 384307168202282326
  tail call void @llvm.assume(i1 %_4.i.i.i.epil)
  %_4.0.i.i.i.epil = add i64 %_45.val.i.epil, %acc.sroa.0.0.i.epil
  %_27.i.epil = add nuw i64 %i.sroa.0.0.i.epil, 1
  %epil.iter.next = add i64 %epil.iter, 1
  %epil.iter.cmp.not = icmp eq i64 %epil.iter.next, %xtraiter
  br i1 %epil.iter.cmp.not, label %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit, label %bb8.i.epil, !llvm.loop !504

_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit: ; preds = %bb8.i.epil, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa
  %_4.0.i.i.i.lcssa = phi i64 [ %_4.0.i.i.i.3, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit.unr-lcssa ], [ %_4.0.i.i.i.epil, %bb8.i.epil ]
  %_37209.not = icmp eq i64 %_4.0.i.i.i.lcssa, 0
  br i1 %_37209.not, label %bb15, label %bb14.lr.ph

bb14.lr.ph:                                       ; preds = %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit
  %_12.i = zext i64 %zeta.0 to i128
  %_15.i = zext i64 %zeta.1 to i128
  br label %bb14

bb15:                                             ; preds = %bb14, %bb3, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit
  %p.sroa.0.0.lcssa = phi i64 [ 1, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit ], [ 1, %bb3 ], [ %_7.sroa.0.0.i, %bb14 ]
  %p.sroa.6.0.lcssa = phi i64 [ 0, %_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldjNCINvNtNtB2c_8adapters3map8map_foldRBQ_jjNCNvMB1v_NtB1v_7PadTerm3add0NCINvXsK_NtB2a_5accumjNtB47_3Sum3sumINtB2W_3MapBF_B3w_EE0E0EB1v_.exit ], [ 0, %bb3 ], [ %_9.sroa.0.0.i, %bb14 ]
  call void @llvm.lifetime.start.p0(ptr nonnull %g)
  %_34.0.i = mul i64 %planes.1, 24
  %or.cond.not.i = icmp samesign ugt i64 %planes.1, 384307168202282325
  br i1 %or.cond.not.i, label %bb17, label %bb18.i, !prof !506

bb18.i:                                           ; preds = %bb15
  %13 = icmp eq i64 %_34.0.i, 0
  br i1 %13, label %bb20.lr.ph, label %bb3.i

bb3.i:                                            ; preds = %bb18.i
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !507
; call __rustc::__rust_alloc
  %14 = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) %_34.0.i, i64 noundef 8) #20, !noalias !507
  %15 = icmp eq ptr %14, null
  br i1 %15, label %bb17, label %bb10.i

bb10.i:                                           ; preds = %bb3.i
  %16 = ptrtoint ptr %14 to i64
  br label %bb20.lr.ph

bb14:                                             ; preds = %bb14.lr.ph, %bb14
  %iter1.sroa.0.0212 = phi i64 [ 0, %bb14.lr.ph ], [ %_38, %bb14 ]
  %p.sroa.6.0211 = phi i64 [ 0, %bb14.lr.ph ], [ %_9.sroa.0.0.i, %bb14 ]
  %p.sroa.0.0210 = phi i64 [ 1, %bb14.lr.ph ], [ %_7.sroa.0.0.i, %bb14 ]
  %_38 = add nuw i64 %iter1.sroa.0.0212, 1
  %_11.i = zext i64 %p.sroa.0.0210 to i128
  %_10.i = mul nuw i128 %_11.i, %_12.i
  %x_lo.i173 = trunc i128 %_10.i to i64
  %_4.i174 = lshr i128 %_10.i, 64
  %x_hi.i175 = trunc nuw i128 %_4.i174 to i64
  %x_hi_hi.i176 = lshr i64 %x_hi.i175, 32
  %x_hi_lo.i177 = and i64 %x_hi.i175, 4294967295
  %_9.0.i178 = sub i64 %x_lo.i173, %x_hi_hi.i176
  %_9.1.i179 = icmp ugt i64 %x_hi_hi.i176, %x_lo.i173
  %_10.i180 = add i64 %_9.0.i178, -4294967295
  %spec.select.i181 = select i1 %_9.1.i179, i64 %_10.i180, i64 %_9.0.i178
  %t1.i182 = mul nuw i64 %x_hi_lo.i177, 4294967295
  %_14.0.i183 = add i64 %spec.select.i181, %t1.i182
  %_14.1.i184 = icmp ult i64 %_14.0.i183, %spec.select.i181
  %17 = add i64 %_14.0.i183, 4294967295
  %res.sroa.0.0.i185 = select i1 %_14.1.i184, i64 %17, i64 %_14.0.i183
  %_16.i186 = icmp ugt i64 %res.sroa.0.0.i185, -4294967296
  %_17.i187 = add nsw i64 %res.sroa.0.0.i185, 4294967295
  %_0.sroa.0.0.i188 = select i1 %_16.i186, i64 %_17.i187, i64 %res.sroa.0.0.i185
  %_14.i = zext i64 %p.sroa.6.0211 to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i
  %x_lo.i157 = trunc i128 %_13.i to i64
  %_4.i158 = lshr i128 %_13.i, 64
  %x_hi.i159 = trunc nuw i128 %_4.i158 to i64
  %x_hi_hi.i160 = lshr i64 %x_hi.i159, 32
  %x_hi_lo.i161 = and i64 %x_hi.i159, 4294967295
  %_9.0.i162 = sub i64 %x_lo.i157, %x_hi_hi.i160
  %_9.1.i163 = icmp ugt i64 %x_hi_hi.i160, %x_lo.i157
  %_10.i164 = add i64 %_9.0.i162, -4294967295
  %spec.select.i165 = select i1 %_9.1.i163, i64 %_10.i164, i64 %_9.0.i162
  %t1.i166 = mul nuw i64 %x_hi_lo.i161, 4294967295
  %_14.0.i167 = add i64 %spec.select.i165, %t1.i166
  %_14.1.i168 = icmp ult i64 %_14.0.i167, %spec.select.i165
  %18 = add i64 %_14.0.i167, 4294967295
  %res.sroa.0.0.i169 = select i1 %_14.1.i168, i64 %18, i64 %_14.0.i167
  %_16.i170 = icmp ugt i64 %res.sroa.0.0.i169, -4294967296
  %_17.i171 = add nsw i64 %res.sroa.0.0.i169, 4294967295
  %_0.sroa.0.0.i172 = select i1 %_16.i170, i64 %_17.i171, i64 %res.sroa.0.0.i169
  %_16.i = mul nuw i128 %_11.i, %_15.i
  %x_lo.i141 = trunc i128 %_16.i to i64
  %_4.i142 = lshr i128 %_16.i, 64
  %x_hi.i143 = trunc nuw i128 %_4.i142 to i64
  %x_hi_hi.i144 = lshr i64 %x_hi.i143, 32
  %x_hi_lo.i145 = and i64 %x_hi.i143, 4294967295
  %_9.0.i146 = sub i64 %x_lo.i141, %x_hi_hi.i144
  %_9.1.i147 = icmp ugt i64 %x_hi_hi.i144, %x_lo.i141
  %_10.i148 = add i64 %_9.0.i146, -4294967295
  %spec.select.i149 = select i1 %_9.1.i147, i64 %_10.i148, i64 %_9.0.i146
  %t1.i150 = mul nuw i64 %x_hi_lo.i145, 4294967295
  %_14.0.i151 = add i64 %spec.select.i149, %t1.i150
  %_14.1.i152 = icmp ult i64 %_14.0.i151, %spec.select.i149
  %19 = add i64 %_14.0.i151, 4294967295
  %res.sroa.0.0.i153 = select i1 %_14.1.i152, i64 %19, i64 %_14.0.i151
  %_16.i154 = icmp ugt i64 %res.sroa.0.0.i153, -4294967296
  %_17.i155 = add nsw i64 %res.sroa.0.0.i153, 4294967295
  %_0.sroa.0.0.i156 = select i1 %_16.i154, i64 %_17.i155, i64 %res.sroa.0.0.i153
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i125 = trunc i128 %_17.i to i64
  %_4.i126 = lshr i128 %_17.i, 64
  %x_hi.i127 = trunc nuw i128 %_4.i126 to i64
  %x_hi_hi.i128 = lshr i64 %x_hi.i127, 32
  %x_hi_lo.i129 = and i64 %x_hi.i127, 4294967295
  %_9.0.i130 = sub i64 %x_lo.i125, %x_hi_hi.i128
  %_9.1.i131 = icmp ugt i64 %x_hi_hi.i128, %x_lo.i125
  %_10.i132 = add i64 %_9.0.i130, -4294967295
  %spec.select.i133 = select i1 %_9.1.i131, i64 %_10.i132, i64 %_9.0.i130
  %t1.i134 = mul nuw i64 %x_hi_lo.i129, 4294967295
  %_14.0.i135 = add i64 %spec.select.i133, %t1.i134
  %_14.1.i136 = icmp ult i64 %_14.0.i135, %spec.select.i133
  %20 = add i64 %_14.0.i135, 4294967295
  %res.sroa.0.0.i137 = select i1 %_14.1.i136, i64 %20, i64 %_14.0.i135
  %_16.i138 = icmp ugt i64 %res.sroa.0.0.i137, -4294967296
  %_17.i139 = add nsw i64 %res.sroa.0.0.i137, 4294967295
  %_0.sroa.0.0.i140 = select i1 %_16.i138, i64 %_17.i139, i64 %res.sroa.0.0.i137
  %_19.i = zext i64 %_0.sroa.0.0.i172 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i109 = trunc i128 %_18.i to i64
  %_4.i110 = lshr i128 %_18.i, 64
  %x_hi.i111 = trunc nuw nsw i128 %_4.i110 to i64
  %t1.i118 = mul nuw nsw i64 %x_hi.i111, 4294967295
  %_14.0.i119 = add i64 %t1.i118, %x_lo.i109
  %_14.1.i120 = icmp ult i64 %_14.0.i119, %x_lo.i109
  %21 = add i64 %_14.0.i119, 4294967295
  %res.sroa.0.0.i121 = select i1 %_14.1.i120, i64 %21, i64 %_14.0.i119
  %_16.i122 = icmp ugt i64 %res.sroa.0.0.i121, -4294967296
  %_17.i123 = add nsw i64 %res.sroa.0.0.i121, 4294967295
  %_0.sroa.0.0.i124 = select i1 %_16.i122, i64 %_17.i123, i64 %res.sroa.0.0.i121
  %_22.0.i = add i64 %_0.sroa.0.0.i124, %_0.sroa.0.0.i188
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i188
  %22 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %22, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i140, %_0.sroa.0.0.i156
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i156
  %23 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %23, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %exitcond.not = icmp eq i64 %_38, %_4.0.i.i.i.lcssa
  br i1 %exitcond.not, label %bb15, label %bb14

bb17:                                             ; preds = %bb15, %bb3.i
  %_42.sroa.4.0.ph = phi i64 [ 8, %bb3.i ], [ 0, %bb15 ]
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef %_42.sroa.4.0.ph, i64 %_34.0.i) #21
  unreachable

bb20.lr.ph:                                       ; preds = %bb18.i, %bb10.i
  %_42.sroa.4.0 = phi i64 [ %planes.1, %bb10.i ], [ 0, %bb18.i ]
  %_42.sroa.10.0 = phi i64 [ %16, %bb10.i ], [ 8, %bb18.i ]
  %24 = inttoptr i64 %_42.sroa.10.0 to ptr
  %_45 = icmp samesign ule i64 %planes.1, %_42.sroa.4.0
  tail call void @llvm.assume(i1 %_45)
  store i64 %_42.sroa.4.0, ptr %g, align 8
  %25 = getelementptr inbounds nuw i8, ptr %g, i64 8
  store ptr %24, ptr %25, align 8
  %26 = getelementptr inbounds nuw i8, ptr %g, i64 16
  store i64 0, ptr %26, align 8
  %_54.idx = shl nuw nsw i64 %planes.1, 3
  %_54 = getelementptr inbounds nuw i8, ptr %planes.0, i64 %_54.idx
  %_12.i11 = zext i64 %zeta.0 to i128
  %_15.i15 = zext i64 %zeta.1 to i128
  br label %bb20

bb20:                                             ; preds = %bb20.lr.ph, %bb8
  %iter.sroa.0.0217 = phi ptr [ %planes.0, %bb20.lr.ph ], [ %_67, %bb8 ]
  %p.sroa.6.1216 = phi i64 [ %p.sroa.6.0.lcssa, %bb20.lr.ph ], [ %_9.sroa.0.0.i36, %bb8 ]
  %p.sroa.0.1215 = phi i64 [ %p.sroa.0.0.lcssa, %bb20.lr.ph ], [ %_7.sroa.0.0.i30, %bb8 ]
  %_67 = getelementptr inbounds nuw i8, ptr %iter.sroa.0.0217, i64 8
  %_16 = load i64, ptr %iter.sroa.0.0217, align 8, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !510)
  %len.i = load i64, ptr %26, align 8, !alias.scope !510, !noalias !513, !noundef !3
  %self1.i = load i64, ptr %g, align 8, !range !7, !alias.scope !510, !noalias !513, !noundef !3
  %_4.i192 = icmp eq i64 %len.i, %self1.i
  br i1 %_4.i192, label %bb1.i, label %bb8

bb1.i:                                            ; preds = %bb20
; invoke <alloc::raw_vec::RawVec<(usize, isolated::field::Fp2)>>::grow_one
  invoke fastcc void @_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_(ptr noalias noundef nonnull align 8 dereferenceable(24) %g)
          to label %bb8 unwind label %bb11

bb19:                                             ; preds = %bb8
  %_22.sroa.0.0.copyload.pre = load i64, ptr %g, align 8
  %_22.sroa.4.0.copyload.pre = load ptr, ptr %25, align 8
  %_22.sroa.5.0.copyload.pre = load i64, ptr %26, align 8
  tail call void @llvm.experimental.noalias.scope.decl(metadata !515)
  %self1.i195 = load i64, ptr %self, align 8, !range !7, !alias.scope !515, !noalias !518, !noundef !3
  %_4.i196 = icmp eq i64 %_27, %self1.i195
  br i1 %_4.i196, label %bb1.i199, label %bb22

bb1.i199:                                         ; preds = %bb19
; invoke <alloc::raw_vec::RawVec<(usize, alloc::vec::Vec<(usize, isolated::field::Fp2)>)>>::grow_one
  invoke fastcc void @_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_(ptr noalias noundef nonnull align 8 dereferenceable(24) %self)
          to label %bb22 unwind label %cleanup.i, !noalias !518

cleanup.i:                                        ; preds = %bb1.i199
  %27 = landingpad { ptr, i32 }
          cleanup
  %28 = icmp eq i64 %_22.sroa.0.0.copyload.pre, 0
  br i1 %28, label %bb10, label %bb2.i.i.i4.i.i.i

bb2.i.i.i4.i.i.i:                                 ; preds = %cleanup.i
  %29 = icmp ne ptr %_22.sroa.4.0.copyload.pre, null
  tail call void @llvm.assume(i1 %29)
  br label %bb10.sink.split

bb8:                                              ; preds = %bb20, %bb1.i
  %_14.i193 = load ptr, ptr %25, align 8, !alias.scope !510, !noalias !513, !nonnull !3, !noundef !3
  %end.i = getelementptr inbounds nuw { i64, %"field::Fp2" }, ptr %_14.i193, i64 %len.i
  store i64 %_16, ptr %end.i, align 8, !noalias !510
  %_15.sroa.4.0.end.i.sroa_idx = getelementptr inbounds nuw i8, ptr %end.i, i64 8
  store i64 %p.sroa.0.1215, ptr %_15.sroa.4.0.end.i.sroa_idx, align 8, !noalias !510
  %_15.sroa.5.0.end.i.sroa_idx = getelementptr inbounds nuw i8, ptr %end.i, i64 16
  store i64 %p.sroa.6.1216, ptr %_15.sroa.5.0.end.i.sroa_idx, align 8, !noalias !510
  %30 = add i64 %len.i, 1
  store i64 %30, ptr %26, align 8, !alias.scope !510, !noalias !513
  %_11.i10 = zext i64 %p.sroa.0.1215 to i128
  %_10.i12 = mul nuw i128 %_11.i10, %_12.i11
  %x_lo.i93 = trunc i128 %_10.i12 to i64
  %_4.i94 = lshr i128 %_10.i12, 64
  %x_hi.i95 = trunc nuw i128 %_4.i94 to i64
  %x_hi_hi.i96 = lshr i64 %x_hi.i95, 32
  %x_hi_lo.i97 = and i64 %x_hi.i95, 4294967295
  %_9.0.i98 = sub i64 %x_lo.i93, %x_hi_hi.i96
  %_9.1.i99 = icmp ugt i64 %x_hi_hi.i96, %x_lo.i93
  %_10.i100 = add i64 %_9.0.i98, -4294967295
  %spec.select.i101 = select i1 %_9.1.i99, i64 %_10.i100, i64 %_9.0.i98
  %t1.i102 = mul nuw i64 %x_hi_lo.i97, 4294967295
  %_14.0.i103 = add i64 %spec.select.i101, %t1.i102
  %_14.1.i104 = icmp ult i64 %_14.0.i103, %spec.select.i101
  %31 = add i64 %_14.0.i103, 4294967295
  %res.sroa.0.0.i105 = select i1 %_14.1.i104, i64 %31, i64 %_14.0.i103
  %_16.i106 = icmp ugt i64 %res.sroa.0.0.i105, -4294967296
  %_17.i107 = add nsw i64 %res.sroa.0.0.i105, 4294967295
  %_0.sroa.0.0.i108 = select i1 %_16.i106, i64 %_17.i107, i64 %res.sroa.0.0.i105
  %_14.i14 = zext i64 %p.sroa.6.1216 to i128
  %_13.i16 = mul nuw i128 %_14.i14, %_15.i15
  %x_lo.i77 = trunc i128 %_13.i16 to i64
  %_4.i78 = lshr i128 %_13.i16, 64
  %x_hi.i79 = trunc nuw i128 %_4.i78 to i64
  %x_hi_hi.i80 = lshr i64 %x_hi.i79, 32
  %x_hi_lo.i81 = and i64 %x_hi.i79, 4294967295
  %_9.0.i82 = sub i64 %x_lo.i77, %x_hi_hi.i80
  %_9.1.i83 = icmp ugt i64 %x_hi_hi.i80, %x_lo.i77
  %_10.i84 = add i64 %_9.0.i82, -4294967295
  %spec.select.i85 = select i1 %_9.1.i83, i64 %_10.i84, i64 %_9.0.i82
  %t1.i86 = mul nuw i64 %x_hi_lo.i81, 4294967295
  %_14.0.i87 = add i64 %spec.select.i85, %t1.i86
  %_14.1.i88 = icmp ult i64 %_14.0.i87, %spec.select.i85
  %32 = add i64 %_14.0.i87, 4294967295
  %res.sroa.0.0.i89 = select i1 %_14.1.i88, i64 %32, i64 %_14.0.i87
  %_16.i90 = icmp ugt i64 %res.sroa.0.0.i89, -4294967296
  %_17.i91 = add nsw i64 %res.sroa.0.0.i89, 4294967295
  %_0.sroa.0.0.i92 = select i1 %_16.i90, i64 %_17.i91, i64 %res.sroa.0.0.i89
  %_16.i18 = mul nuw i128 %_11.i10, %_15.i15
  %x_lo.i61 = trunc i128 %_16.i18 to i64
  %_4.i62 = lshr i128 %_16.i18, 64
  %x_hi.i63 = trunc nuw i128 %_4.i62 to i64
  %x_hi_hi.i64 = lshr i64 %x_hi.i63, 32
  %x_hi_lo.i65 = and i64 %x_hi.i63, 4294967295
  %_9.0.i66 = sub i64 %x_lo.i61, %x_hi_hi.i64
  %_9.1.i67 = icmp ugt i64 %x_hi_hi.i64, %x_lo.i61
  %_10.i68 = add i64 %_9.0.i66, -4294967295
  %spec.select.i69 = select i1 %_9.1.i67, i64 %_10.i68, i64 %_9.0.i66
  %t1.i70 = mul nuw i64 %x_hi_lo.i65, 4294967295
  %_14.0.i71 = add i64 %spec.select.i69, %t1.i70
  %_14.1.i72 = icmp ult i64 %_14.0.i71, %spec.select.i69
  %33 = add i64 %_14.0.i71, 4294967295
  %res.sroa.0.0.i73 = select i1 %_14.1.i72, i64 %33, i64 %_14.0.i71
  %_16.i74 = icmp ugt i64 %res.sroa.0.0.i73, -4294967296
  %_17.i75 = add nsw i64 %res.sroa.0.0.i73, 4294967295
  %_0.sroa.0.0.i76 = select i1 %_16.i74, i64 %_17.i75, i64 %res.sroa.0.0.i73
  %_17.i20 = mul nuw i128 %_14.i14, %_12.i11
  %x_lo.i45 = trunc i128 %_17.i20 to i64
  %_4.i46 = lshr i128 %_17.i20, 64
  %x_hi.i47 = trunc nuw i128 %_4.i46 to i64
  %x_hi_hi.i48 = lshr i64 %x_hi.i47, 32
  %x_hi_lo.i49 = and i64 %x_hi.i47, 4294967295
  %_9.0.i50 = sub i64 %x_lo.i45, %x_hi_hi.i48
  %_9.1.i51 = icmp ugt i64 %x_hi_hi.i48, %x_lo.i45
  %_10.i52 = add i64 %_9.0.i50, -4294967295
  %spec.select.i53 = select i1 %_9.1.i51, i64 %_10.i52, i64 %_9.0.i50
  %t1.i54 = mul nuw i64 %x_hi_lo.i49, 4294967295
  %_14.0.i55 = add i64 %spec.select.i53, %t1.i54
  %_14.1.i56 = icmp ult i64 %_14.0.i55, %spec.select.i53
  %34 = add i64 %_14.0.i55, 4294967295
  %res.sroa.0.0.i57 = select i1 %_14.1.i56, i64 %34, i64 %_14.0.i55
  %_16.i58 = icmp ugt i64 %res.sroa.0.0.i57, -4294967296
  %_17.i59 = add nsw i64 %res.sroa.0.0.i57, 4294967295
  %_0.sroa.0.0.i60 = select i1 %_16.i58, i64 %_17.i59, i64 %res.sroa.0.0.i57
  %_19.i22 = zext i64 %_0.sroa.0.0.i92 to i128
  %_18.i23 = mul nuw nsw i128 %_19.i22, 7
  %x_lo.i = trunc i128 %_18.i23 to i64
  %_4.i = lshr i128 %_18.i23, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %35 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %35, i64 %_14.0.i
  %_16.i43 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i44 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i43, i64 %_17.i44, i64 %res.sroa.0.0.i
  %_22.0.i25 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i108
  %_22.1.i26 = icmp ult i64 %_22.0.i25, %_0.sroa.0.0.i108
  %36 = add nuw i64 %_22.0.i25, 4294967295
  %_24.sroa.0.0.i27 = select i1 %_22.1.i26, i64 %36, i64 %_22.0.i25
  %_25.i28 = icmp ugt i64 %_24.sroa.0.0.i27, -4294967296
  %_26.i29 = add nsw i64 %_24.sroa.0.0.i27, 4294967295
  %_7.sroa.0.0.i30 = select i1 %_25.i28, i64 %_26.i29, i64 %_24.sroa.0.0.i27
  %_29.0.i31 = add i64 %_0.sroa.0.0.i60, %_0.sroa.0.0.i76
  %_29.1.i32 = icmp ult i64 %_29.0.i31, %_0.sroa.0.0.i76
  %37 = add nuw i64 %_29.0.i31, 4294967295
  %_30.sroa.0.0.i33 = select i1 %_29.1.i32, i64 %37, i64 %_29.0.i31
  %_31.i34 = icmp ugt i64 %_30.sroa.0.0.i33, -4294967296
  %_32.i35 = add nsw i64 %_30.sroa.0.0.i33, 4294967295
  %_9.sroa.0.0.i36 = select i1 %_31.i34, i64 %_32.i35, i64 %_30.sroa.0.0.i33
  %_61.not = icmp eq ptr %_67, %_54
  br i1 %_61.not, label %bb19, label %bb20

bb22:                                             ; preds = %bb1.i199, %bb19
  %_14.i197 = load ptr, ptr %1, align 8, !alias.scope !515, !noalias !518, !nonnull !3, !noundef !3
  %end.i198 = getelementptr inbounds nuw { i64, %"alloc::vec::Vec<(usize, field::Fp2)>" }, ptr %_14.i197, i64 %_27
  store i64 20, ptr %end.i198, align 8, !noalias !515
  %_21.sroa.4.0.end.i198.sroa_idx = getelementptr inbounds nuw i8, ptr %end.i198, i64 8
  store i64 %_22.sroa.0.0.copyload.pre, ptr %_21.sroa.4.0.end.i198.sroa_idx, align 8, !noalias !515
  %_21.sroa.6.0.end.i198.sroa_idx = getelementptr inbounds nuw i8, ptr %end.i198, i64 16
  store ptr %_22.sroa.4.0.copyload.pre, ptr %_21.sroa.6.0.end.i198.sroa_idx, align 8, !noalias !515
  %_21.sroa.7.0.end.i198.sroa_idx = getelementptr inbounds nuw i8, ptr %end.i198, i64 24
  store i64 %_22.sroa.5.0.copyload.pre, ptr %_21.sroa.7.0.end.i198.sroa_idx, align 8, !noalias !515
  %38 = add i64 %_27, 1
  store i64 %38, ptr %2, align 8, !alias.scope !515, !noalias !518
  call void @llvm.lifetime.end.p0(ptr nonnull %g)
  br label %bb9

bb10.sink.split:                                  ; preds = %bb2.i.i.i4.i, %bb2.i.i.i4.i.i.i
  %_22.sroa.0.0.copyload.pre.sink = phi i64 [ %_22.sroa.0.0.copyload.pre, %bb2.i.i.i4.i.i.i ], [ %g.val, %bb2.i.i.i4.i ]
  %_22.sroa.4.0.copyload.pre.sink = phi ptr [ %_22.sroa.4.0.copyload.pre, %bb2.i.i.i4.i.i.i ], [ %g.val189, %bb2.i.i.i4.i ]
  %eh.lpad-body208.ph = phi { ptr, i32 } [ %27, %bb2.i.i.i4.i.i.i ], [ %39, %bb2.i.i.i4.i ]
  %alloc_size.i.i.i.i5.i.i.i = mul nuw i64 %_22.sroa.0.0.copyload.pre.sink, 24
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %_22.sroa.4.0.copyload.pre.sink, i64 noundef %alloc_size.i.i.i.i5.i.i.i, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  br label %bb10

bb10:                                             ; preds = %bb10.sink.split, %cleanup.i, %bb11
  %eh.lpad-body208 = phi { ptr, i32 } [ %27, %cleanup.i ], [ %39, %bb11 ], [ %eh.lpad-body208.ph, %bb10.sink.split ]
  resume { ptr, i32 } %eh.lpad-body208

bb11:                                             ; preds = %bb1.i
  %39 = landingpad { ptr, i32 }
          cleanup
  %g.val = load i64, ptr %g, align 8
  %40 = icmp eq i64 %g.val, 0
  br i1 %40, label %bb10, label %bb2.i.i.i4.i

bb2.i.i.i4.i:                                     ; preds = %bb11
  %g.val189 = load ptr, ptr %25, align 8, !nonnull !3, !noundef !3
  br label %bb10.sink.split
}

; <isolated::PadTerm>::eval
; Function Attrs: nonlazybind uwtable
define internal fastcc { i64, i64 } @_RNvMCsl0YfJI2rrfI_8isolatedNtB2_7PadTerm4eval(ptr noalias noundef nonnull readonly align 8 captures(none) dereferenceable(40) %self, ptr noalias noundef nonnull readonly align 8 captures(none) %v.0, i64 noundef range(i64 0, 576460752303423488) %v.1) unnamed_addr #1 {
start:
  %0 = getelementptr inbounds nuw i8, ptr %self, i64 8
  %_33 = load ptr, ptr %0, align 8, !nonnull !3, !noundef !3
  %1 = getelementptr inbounds nuw i8, ptr %self, i64 16
  %_32 = load i64, ptr %1, align 8, !noundef !3
  %_37.idx = shl nuw nsw i64 %_32, 5
  %_37 = getelementptr inbounds nuw i8, ptr %_33, i64 %_37.idx
  %_43315 = icmp eq i64 %_32, 0
  br i1 %_43315, label %bb10, label %bb11

bb11:                                             ; preds = %start, %bb18
  %iter.sroa.0.0318 = phi ptr [ %_49, %bb18 ], [ %_33, %start ]
  %acc.sroa.4.0317 = phi i64 [ %_4.sroa.0.0.i, %bb18 ], [ 0, %start ]
  %acc.sroa.0.0316 = phi i64 [ %_3.sroa.0.0.i, %bb18 ], [ 0, %start ]
  %_49 = getelementptr inbounds nuw i8, ptr %iter.sroa.0.0318, i64 32
  %_8 = load i64, ptr %iter.sroa.0.0318, align 8, !noundef !3
  %_10 = icmp ult i64 %_8, %v.1
  br i1 %_10, label %bb2, label %panic

bb10:                                             ; preds = %bb18, %start
  %acc.sroa.0.0.lcssa = phi i64 [ 0, %start ], [ %_3.sroa.0.0.i, %bb18 ]
  %acc.sroa.4.0.lcssa = phi i64 [ 0, %start ], [ %_4.sroa.0.0.i, %bb18 ]
  %2 = getelementptr inbounds nuw i8, ptr %self, i64 24
  %_25.0 = load i64, ptr %2, align 8, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %self, i64 32
  %_25.1 = load i64, ptr %3, align 8, !noundef !3
  %_11.i = zext i64 %_25.0 to i128
  %_12.i = zext i64 %acc.sroa.0.0.lcssa to i128
  %_10.i19 = mul nuw i128 %_11.i, %_12.i
  %x_lo.i287 = trunc i128 %_10.i19 to i64
  %_4.i288 = lshr i128 %_10.i19, 64
  %x_hi.i289 = trunc nuw i128 %_4.i288 to i64
  %x_hi_hi.i290 = lshr i64 %x_hi.i289, 32
  %x_hi_lo.i291 = and i64 %x_hi.i289, 4294967295
  %_9.0.i292 = sub i64 %x_lo.i287, %x_hi_hi.i290
  %_9.1.i293 = icmp ugt i64 %x_hi_hi.i290, %x_lo.i287
  %_10.i294 = add i64 %_9.0.i292, -4294967295
  %spec.select.i295 = select i1 %_9.1.i293, i64 %_10.i294, i64 %_9.0.i292
  %t1.i296 = mul nuw i64 %x_hi_lo.i291, 4294967295
  %_14.0.i297 = add i64 %spec.select.i295, %t1.i296
  %_14.1.i298 = icmp ult i64 %_14.0.i297, %spec.select.i295
  %4 = add i64 %_14.0.i297, 4294967295
  %res.sroa.0.0.i299 = select i1 %_14.1.i298, i64 %4, i64 %_14.0.i297
  %_16.i300 = icmp ugt i64 %res.sroa.0.0.i299, -4294967296
  %_17.i301 = add nsw i64 %res.sroa.0.0.i299, 4294967295
  %_0.sroa.0.0.i302 = select i1 %_16.i300, i64 %_17.i301, i64 %res.sroa.0.0.i299
  %_14.i = zext i64 %_25.1 to i128
  %_15.i20 = zext i64 %acc.sroa.4.0.lcssa to i128
  %_13.i = mul nuw i128 %_14.i, %_15.i20
  %x_lo.i271 = trunc i128 %_13.i to i64
  %_4.i272 = lshr i128 %_13.i, 64
  %x_hi.i273 = trunc nuw i128 %_4.i272 to i64
  %x_hi_hi.i274 = lshr i64 %x_hi.i273, 32
  %x_hi_lo.i275 = and i64 %x_hi.i273, 4294967295
  %_9.0.i276 = sub i64 %x_lo.i271, %x_hi_hi.i274
  %_9.1.i277 = icmp ugt i64 %x_hi_hi.i274, %x_lo.i271
  %_10.i278 = add i64 %_9.0.i276, -4294967295
  %spec.select.i279 = select i1 %_9.1.i277, i64 %_10.i278, i64 %_9.0.i276
  %t1.i280 = mul nuw i64 %x_hi_lo.i275, 4294967295
  %_14.0.i281 = add i64 %spec.select.i279, %t1.i280
  %_14.1.i282 = icmp ult i64 %_14.0.i281, %spec.select.i279
  %5 = add i64 %_14.0.i281, 4294967295
  %res.sroa.0.0.i283 = select i1 %_14.1.i282, i64 %5, i64 %_14.0.i281
  %_16.i284 = icmp ugt i64 %res.sroa.0.0.i283, -4294967296
  %_17.i285 = add nsw i64 %res.sroa.0.0.i283, 4294967295
  %_0.sroa.0.0.i286 = select i1 %_16.i284, i64 %_17.i285, i64 %res.sroa.0.0.i283
  %_16.i21 = mul nuw i128 %_11.i, %_15.i20
  %x_lo.i255 = trunc i128 %_16.i21 to i64
  %_4.i256 = lshr i128 %_16.i21, 64
  %x_hi.i257 = trunc nuw i128 %_4.i256 to i64
  %x_hi_hi.i258 = lshr i64 %x_hi.i257, 32
  %x_hi_lo.i259 = and i64 %x_hi.i257, 4294967295
  %_9.0.i260 = sub i64 %x_lo.i255, %x_hi_hi.i258
  %_9.1.i261 = icmp ugt i64 %x_hi_hi.i258, %x_lo.i255
  %_10.i262 = add i64 %_9.0.i260, -4294967295
  %spec.select.i263 = select i1 %_9.1.i261, i64 %_10.i262, i64 %_9.0.i260
  %t1.i264 = mul nuw i64 %x_hi_lo.i259, 4294967295
  %_14.0.i265 = add i64 %spec.select.i263, %t1.i264
  %_14.1.i266 = icmp ult i64 %_14.0.i265, %spec.select.i263
  %6 = add i64 %_14.0.i265, 4294967295
  %res.sroa.0.0.i267 = select i1 %_14.1.i266, i64 %6, i64 %_14.0.i265
  %_16.i268 = icmp ugt i64 %res.sroa.0.0.i267, -4294967296
  %_17.i269 = add nsw i64 %res.sroa.0.0.i267, 4294967295
  %_0.sroa.0.0.i270 = select i1 %_16.i268, i64 %_17.i269, i64 %res.sroa.0.0.i267
  %_17.i = mul nuw i128 %_14.i, %_12.i
  %x_lo.i239 = trunc i128 %_17.i to i64
  %_4.i240 = lshr i128 %_17.i, 64
  %x_hi.i241 = trunc nuw i128 %_4.i240 to i64
  %x_hi_hi.i242 = lshr i64 %x_hi.i241, 32
  %x_hi_lo.i243 = and i64 %x_hi.i241, 4294967295
  %_9.0.i244 = sub i64 %x_lo.i239, %x_hi_hi.i242
  %_9.1.i245 = icmp ugt i64 %x_hi_hi.i242, %x_lo.i239
  %_10.i246 = add i64 %_9.0.i244, -4294967295
  %spec.select.i247 = select i1 %_9.1.i245, i64 %_10.i246, i64 %_9.0.i244
  %t1.i248 = mul nuw i64 %x_hi_lo.i243, 4294967295
  %_14.0.i249 = add i64 %spec.select.i247, %t1.i248
  %_14.1.i250 = icmp ult i64 %_14.0.i249, %spec.select.i247
  %7 = add i64 %_14.0.i249, 4294967295
  %res.sroa.0.0.i251 = select i1 %_14.1.i250, i64 %7, i64 %_14.0.i249
  %_16.i252 = icmp ugt i64 %res.sroa.0.0.i251, -4294967296
  %_17.i253 = add nsw i64 %res.sroa.0.0.i251, 4294967295
  %_0.sroa.0.0.i254 = select i1 %_16.i252, i64 %_17.i253, i64 %res.sroa.0.0.i251
  %_19.i = zext i64 %_0.sroa.0.0.i286 to i128
  %_18.i = mul nuw nsw i128 %_19.i, 7
  %x_lo.i223 = trunc i128 %_18.i to i64
  %_4.i224 = lshr i128 %_18.i, 64
  %x_hi.i225 = trunc nuw nsw i128 %_4.i224 to i64
  %t1.i232 = mul nuw nsw i64 %x_hi.i225, 4294967295
  %_14.0.i233 = add i64 %t1.i232, %x_lo.i223
  %_14.1.i234 = icmp ult i64 %_14.0.i233, %x_lo.i223
  %8 = add i64 %_14.0.i233, 4294967295
  %res.sroa.0.0.i235 = select i1 %_14.1.i234, i64 %8, i64 %_14.0.i233
  %_16.i236 = icmp ugt i64 %res.sroa.0.0.i235, -4294967296
  %_17.i237 = add nsw i64 %res.sroa.0.0.i235, 4294967295
  %_0.sroa.0.0.i238 = select i1 %_16.i236, i64 %_17.i237, i64 %res.sroa.0.0.i235
  %_22.0.i = add i64 %_0.sroa.0.0.i238, %_0.sroa.0.0.i302
  %_22.1.i = icmp ult i64 %_22.0.i, %_0.sroa.0.0.i302
  %9 = add nuw i64 %_22.0.i, 4294967295
  %_24.sroa.0.0.i = select i1 %_22.1.i, i64 %9, i64 %_22.0.i
  %_25.i = icmp ugt i64 %_24.sroa.0.0.i, -4294967296
  %_26.i = add nsw i64 %_24.sroa.0.0.i, 4294967295
  %_7.sroa.0.0.i = select i1 %_25.i, i64 %_26.i, i64 %_24.sroa.0.0.i
  %_29.0.i = add i64 %_0.sroa.0.0.i254, %_0.sroa.0.0.i270
  %_29.1.i = icmp ult i64 %_29.0.i, %_0.sroa.0.0.i270
  %10 = add nuw i64 %_29.0.i, 4294967295
  %_30.sroa.0.0.i = select i1 %_29.1.i, i64 %10, i64 %_29.0.i
  %_31.i = icmp ugt i64 %_30.sroa.0.0.i, -4294967296
  %_32.i = add nsw i64 %_30.sroa.0.0.i, 4294967295
  %_9.sroa.0.0.i = select i1 %_31.i, i64 %_32.i, i64 %_30.sroa.0.0.i
  %11 = insertvalue { i64, i64 } poison, i64 %_7.sroa.0.0.i, 0
  %12 = insertvalue { i64, i64 } %11, i64 %_9.sroa.0.0.i, 1
  ret { i64, i64 } %12

bb2:                                              ; preds = %bb11
  %13 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_8
  %_82 = load i64, ptr %13, align 8, !noundef !3
  %14 = getelementptr inbounds nuw i8, ptr %13, i64 8
  %_83 = load i64, ptr %14, align 8, !noundef !3
  %_55.1 = icmp ugt i64 %_82, 1
  %. = select i1 %_55.1, i64 -4294967294, i64 1
  %_56.sroa.0.0 = sub i64 %., %_82
  %_59.1.not = icmp eq i64 %_83, 0
  %15 = sub i64 -4294967295, %_83
  %_60.sroa.0.0 = select i1 %_59.1.not, i64 0, i64 %15
  %16 = getelementptr inbounds nuw i8, ptr %iter.sroa.0.0318, i64 16
  %_64 = load ptr, ptr %16, align 8, !nonnull !3, !noundef !3
  %17 = getelementptr inbounds nuw i8, ptr %iter.sroa.0.0318, i64 24
  %_63 = load i64, ptr %17, align 8, !noundef !3
  %_68.idx = mul nuw nsw i64 %_63, 24
  %_68 = getelementptr inbounds nuw i8, ptr %_64, i64 %_68.idx
  %_74310 = icmp eq i64 %_63, 0
  br i1 %_74310, label %bb18, label %bb19

panic:                                            ; preds = %bb11
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_8, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_3819371618053aaf30fd9948083359db) #21
  unreachable

bb19:                                             ; preds = %bb2, %bb4
  %iter1.sroa.0.0313 = phi ptr [ %_80, %bb4 ], [ %_64, %bb2 ]
  %inner.sroa.0.0312 = phi i64 [ %_3.sroa.0.0.i12, %bb4 ], [ 0, %bb2 ]
  %inner.sroa.4.0311 = phi i64 [ %_4.sroa.0.0.i18, %bb4 ], [ 0, %bb2 ]
  %_20 = load i64, ptr %iter1.sroa.0.0313, align 8, !noundef !3
  %_21 = icmp ult i64 %_20, %v.1
  br i1 %_21, label %bb4, label %panic2

bb18:                                             ; preds = %bb4, %bb2
  %inner.sroa.4.0.lcssa = phi i64 [ 0, %bb2 ], [ %_4.sroa.0.0.i18, %bb4 ]
  %inner.sroa.0.0.lcssa = phi i64 [ 0, %bb2 ], [ %_3.sroa.0.0.i12, %bb4 ]
  %_11.i22 = zext i64 %_56.sroa.0.0 to i128
  %_12.i23 = zext i64 %inner.sroa.0.0.lcssa to i128
  %_10.i24 = mul nuw i128 %_12.i23, %_11.i22
  %x_lo.i207 = trunc i128 %_10.i24 to i64
  %_4.i208 = lshr i128 %_10.i24, 64
  %x_hi.i209 = trunc nuw i128 %_4.i208 to i64
  %x_hi_hi.i210 = lshr i64 %x_hi.i209, 32
  %x_hi_lo.i211 = and i64 %x_hi.i209, 4294967295
  %_9.0.i212 = sub i64 %x_lo.i207, %x_hi_hi.i210
  %_9.1.i213 = icmp ugt i64 %x_hi_hi.i210, %x_lo.i207
  %_10.i214 = add i64 %_9.0.i212, -4294967295
  %spec.select.i215 = select i1 %_9.1.i213, i64 %_10.i214, i64 %_9.0.i212
  %t1.i216 = mul nuw i64 %x_hi_lo.i211, 4294967295
  %_14.0.i217 = add i64 %spec.select.i215, %t1.i216
  %_14.1.i218 = icmp ult i64 %_14.0.i217, %spec.select.i215
  %18 = add i64 %_14.0.i217, 4294967295
  %res.sroa.0.0.i219 = select i1 %_14.1.i218, i64 %18, i64 %_14.0.i217
  %_16.i220 = icmp ugt i64 %res.sroa.0.0.i219, -4294967296
  %_17.i221 = add nsw i64 %res.sroa.0.0.i219, 4294967295
  %_0.sroa.0.0.i222 = select i1 %_16.i220, i64 %_17.i221, i64 %res.sroa.0.0.i219
  %_14.i26 = zext i64 %_60.sroa.0.0 to i128
  %_15.i27 = zext i64 %inner.sroa.4.0.lcssa to i128
  %_13.i28 = mul nuw i128 %_15.i27, %_14.i26
  %x_lo.i191 = trunc i128 %_13.i28 to i64
  %_4.i192 = lshr i128 %_13.i28, 64
  %x_hi.i193 = trunc nuw i128 %_4.i192 to i64
  %x_hi_hi.i194 = lshr i64 %x_hi.i193, 32
  %x_hi_lo.i195 = and i64 %x_hi.i193, 4294967295
  %_9.0.i196 = sub i64 %x_lo.i191, %x_hi_hi.i194
  %_9.1.i197 = icmp ugt i64 %x_hi_hi.i194, %x_lo.i191
  %_10.i198 = add i64 %_9.0.i196, -4294967295
  %spec.select.i199 = select i1 %_9.1.i197, i64 %_10.i198, i64 %_9.0.i196
  %t1.i200 = mul nuw i64 %x_hi_lo.i195, 4294967295
  %_14.0.i201 = add i64 %spec.select.i199, %t1.i200
  %_14.1.i202 = icmp ult i64 %_14.0.i201, %spec.select.i199
  %19 = add i64 %_14.0.i201, 4294967295
  %res.sroa.0.0.i203 = select i1 %_14.1.i202, i64 %19, i64 %_14.0.i201
  %_16.i204 = icmp ugt i64 %res.sroa.0.0.i203, -4294967296
  %_17.i205 = add nsw i64 %res.sroa.0.0.i203, 4294967295
  %_0.sroa.0.0.i206 = select i1 %_16.i204, i64 %_17.i205, i64 %res.sroa.0.0.i203
  %_16.i30 = mul nuw i128 %_15.i27, %_11.i22
  %x_lo.i175 = trunc i128 %_16.i30 to i64
  %_4.i176 = lshr i128 %_16.i30, 64
  %x_hi.i177 = trunc nuw i128 %_4.i176 to i64
  %x_hi_hi.i178 = lshr i64 %x_hi.i177, 32
  %x_hi_lo.i179 = and i64 %x_hi.i177, 4294967295
  %_9.0.i180 = sub i64 %x_lo.i175, %x_hi_hi.i178
  %_9.1.i181 = icmp ugt i64 %x_hi_hi.i178, %x_lo.i175
  %_10.i182 = add i64 %_9.0.i180, -4294967295
  %spec.select.i183 = select i1 %_9.1.i181, i64 %_10.i182, i64 %_9.0.i180
  %t1.i184 = mul nuw i64 %x_hi_lo.i179, 4294967295
  %_14.0.i185 = add i64 %spec.select.i183, %t1.i184
  %_14.1.i186 = icmp ult i64 %_14.0.i185, %spec.select.i183
  %20 = add i64 %_14.0.i185, 4294967295
  %res.sroa.0.0.i187 = select i1 %_14.1.i186, i64 %20, i64 %_14.0.i185
  %_16.i188 = icmp ugt i64 %res.sroa.0.0.i187, -4294967296
  %_17.i189 = add nsw i64 %res.sroa.0.0.i187, 4294967295
  %_0.sroa.0.0.i190 = select i1 %_16.i188, i64 %_17.i189, i64 %res.sroa.0.0.i187
  %_17.i32 = mul nuw i128 %_12.i23, %_14.i26
  %x_lo.i159 = trunc i128 %_17.i32 to i64
  %_4.i160 = lshr i128 %_17.i32, 64
  %x_hi.i161 = trunc nuw i128 %_4.i160 to i64
  %x_hi_hi.i162 = lshr i64 %x_hi.i161, 32
  %x_hi_lo.i163 = and i64 %x_hi.i161, 4294967295
  %_9.0.i164 = sub i64 %x_lo.i159, %x_hi_hi.i162
  %_9.1.i165 = icmp ugt i64 %x_hi_hi.i162, %x_lo.i159
  %_10.i166 = add i64 %_9.0.i164, -4294967295
  %spec.select.i167 = select i1 %_9.1.i165, i64 %_10.i166, i64 %_9.0.i164
  %t1.i168 = mul nuw i64 %x_hi_lo.i163, 4294967295
  %_14.0.i169 = add i64 %spec.select.i167, %t1.i168
  %_14.1.i170 = icmp ult i64 %_14.0.i169, %spec.select.i167
  %21 = add i64 %_14.0.i169, 4294967295
  %res.sroa.0.0.i171 = select i1 %_14.1.i170, i64 %21, i64 %_14.0.i169
  %_16.i172 = icmp ugt i64 %res.sroa.0.0.i171, -4294967296
  %_17.i173 = add nsw i64 %res.sroa.0.0.i171, 4294967295
  %_0.sroa.0.0.i174 = select i1 %_16.i172, i64 %_17.i173, i64 %res.sroa.0.0.i171
  %_19.i34 = zext i64 %_0.sroa.0.0.i206 to i128
  %_18.i35 = mul nuw nsw i128 %_19.i34, 7
  %x_lo.i143 = trunc i128 %_18.i35 to i64
  %_4.i144 = lshr i128 %_18.i35, 64
  %x_hi.i145 = trunc nuw nsw i128 %_4.i144 to i64
  %t1.i152 = mul nuw nsw i64 %x_hi.i145, 4294967295
  %_14.0.i153 = add i64 %t1.i152, %x_lo.i143
  %_14.1.i154 = icmp ult i64 %_14.0.i153, %x_lo.i143
  %22 = add i64 %_14.0.i153, 4294967295
  %res.sroa.0.0.i155 = select i1 %_14.1.i154, i64 %22, i64 %_14.0.i153
  %_16.i156 = icmp ugt i64 %res.sroa.0.0.i155, -4294967296
  %_17.i157 = add nsw i64 %res.sroa.0.0.i155, 4294967295
  %_0.sroa.0.0.i158 = select i1 %_16.i156, i64 %_17.i157, i64 %res.sroa.0.0.i155
  %_22.0.i37 = add i64 %_0.sroa.0.0.i158, %_0.sroa.0.0.i222
  %_22.1.i38 = icmp ult i64 %_22.0.i37, %_0.sroa.0.0.i222
  %23 = add nuw i64 %_22.0.i37, 4294967295
  %_24.sroa.0.0.i39 = select i1 %_22.1.i38, i64 %23, i64 %_22.0.i37
  %_25.i40 = icmp ugt i64 %_24.sroa.0.0.i39, -4294967296
  %_26.i41 = add nsw i64 %_24.sroa.0.0.i39, 4294967295
  %_7.sroa.0.0.i42 = select i1 %_25.i40, i64 %_26.i41, i64 %_24.sroa.0.0.i39
  %_29.0.i43 = add i64 %_0.sroa.0.0.i174, %_0.sroa.0.0.i190
  %_29.1.i44 = icmp ult i64 %_29.0.i43, %_0.sroa.0.0.i190
  %24 = add nuw i64 %_29.0.i43, 4294967295
  %_30.sroa.0.0.i45 = select i1 %_29.1.i44, i64 %24, i64 %_29.0.i43
  %_31.i46 = icmp ugt i64 %_30.sroa.0.0.i45, -4294967296
  %_32.i47 = add nsw i64 %_30.sroa.0.0.i45, 4294967295
  %_9.sroa.0.0.i48 = select i1 %_31.i46, i64 %_32.i47, i64 %_30.sroa.0.0.i45
  %_7.0.i = add i64 %_7.sroa.0.0.i42, %acc.sroa.0.0316
  %_7.1.i = icmp ult i64 %_7.0.i, %acc.sroa.0.0316
  %25 = add i64 %_7.0.i, 4294967295
  %_8.sroa.0.0.i = select i1 %_7.1.i, i64 %25, i64 %_7.0.i
  %_9.i = icmp ugt i64 %_8.sroa.0.0.i, -4294967296
  %_10.i = add nsw i64 %_8.sroa.0.0.i, 4294967295
  %_3.sroa.0.0.i = select i1 %_9.i, i64 %_10.i, i64 %_8.sroa.0.0.i
  %_13.0.i = add i64 %_9.sroa.0.0.i48, %acc.sroa.4.0317
  %_13.1.i = icmp ult i64 %_13.0.i, %acc.sroa.4.0317
  %26 = add i64 %_13.0.i, 4294967295
  %_14.sroa.0.0.i = select i1 %_13.1.i, i64 %26, i64 %_13.0.i
  %_15.i = icmp ugt i64 %_14.sroa.0.0.i, -4294967296
  %_16.i = add nsw i64 %_14.sroa.0.0.i, 4294967295
  %_4.sroa.0.0.i = select i1 %_15.i, i64 %_16.i, i64 %_14.sroa.0.0.i
  %_43 = icmp eq ptr %_49, %_37
  br i1 %_43, label %bb10, label %bb11

bb4:                                              ; preds = %bb19
  %27 = getelementptr inbounds nuw i8, ptr %iter1.sroa.0.0313, i64 16
  %_18.1 = load i64, ptr %27, align 8, !noundef !3
  %28 = getelementptr inbounds nuw i8, ptr %iter1.sroa.0.0313, i64 8
  %_18.0 = load i64, ptr %28, align 8, !noundef !3
  %_80 = getelementptr inbounds nuw i8, ptr %iter1.sroa.0.0313, i64 24
  %29 = getelementptr inbounds nuw %"field::Fp2", ptr %v.0, i64 %_20
  %_19.0 = load i64, ptr %29, align 8, !noundef !3
  %30 = getelementptr inbounds nuw i8, ptr %29, i64 8
  %_19.1 = load i64, ptr %30, align 8, !noundef !3
  %_11.i49 = zext i64 %_18.0 to i128
  %_12.i50 = zext i64 %_19.0 to i128
  %_10.i51 = mul nuw i128 %_12.i50, %_11.i49
  %x_lo.i127 = trunc i128 %_10.i51 to i64
  %_4.i128 = lshr i128 %_10.i51, 64
  %x_hi.i129 = trunc nuw i128 %_4.i128 to i64
  %x_hi_hi.i130 = lshr i64 %x_hi.i129, 32
  %x_hi_lo.i131 = and i64 %x_hi.i129, 4294967295
  %_9.0.i132 = sub i64 %x_lo.i127, %x_hi_hi.i130
  %_9.1.i133 = icmp ugt i64 %x_hi_hi.i130, %x_lo.i127
  %_10.i134 = add i64 %_9.0.i132, -4294967295
  %spec.select.i135 = select i1 %_9.1.i133, i64 %_10.i134, i64 %_9.0.i132
  %t1.i136 = mul nuw i64 %x_hi_lo.i131, 4294967295
  %_14.0.i137 = add i64 %spec.select.i135, %t1.i136
  %_14.1.i138 = icmp ult i64 %_14.0.i137, %spec.select.i135
  %31 = add i64 %_14.0.i137, 4294967295
  %res.sroa.0.0.i139 = select i1 %_14.1.i138, i64 %31, i64 %_14.0.i137
  %_16.i140 = icmp ugt i64 %res.sroa.0.0.i139, -4294967296
  %_17.i141 = add nsw i64 %res.sroa.0.0.i139, 4294967295
  %_0.sroa.0.0.i142 = select i1 %_16.i140, i64 %_17.i141, i64 %res.sroa.0.0.i139
  %_14.i53 = zext i64 %_18.1 to i128
  %_15.i54 = zext i64 %_19.1 to i128
  %_13.i55 = mul nuw i128 %_15.i54, %_14.i53
  %x_lo.i111 = trunc i128 %_13.i55 to i64
  %_4.i112 = lshr i128 %_13.i55, 64
  %x_hi.i113 = trunc nuw i128 %_4.i112 to i64
  %x_hi_hi.i114 = lshr i64 %x_hi.i113, 32
  %x_hi_lo.i115 = and i64 %x_hi.i113, 4294967295
  %_9.0.i116 = sub i64 %x_lo.i111, %x_hi_hi.i114
  %_9.1.i117 = icmp ugt i64 %x_hi_hi.i114, %x_lo.i111
  %_10.i118 = add i64 %_9.0.i116, -4294967295
  %spec.select.i119 = select i1 %_9.1.i117, i64 %_10.i118, i64 %_9.0.i116
  %t1.i120 = mul nuw i64 %x_hi_lo.i115, 4294967295
  %_14.0.i121 = add i64 %spec.select.i119, %t1.i120
  %_14.1.i122 = icmp ult i64 %_14.0.i121, %spec.select.i119
  %32 = add i64 %_14.0.i121, 4294967295
  %res.sroa.0.0.i123 = select i1 %_14.1.i122, i64 %32, i64 %_14.0.i121
  %_16.i124 = icmp ugt i64 %res.sroa.0.0.i123, -4294967296
  %_17.i125 = add nsw i64 %res.sroa.0.0.i123, 4294967295
  %_0.sroa.0.0.i126 = select i1 %_16.i124, i64 %_17.i125, i64 %res.sroa.0.0.i123
  %_16.i57 = mul nuw i128 %_15.i54, %_11.i49
  %x_lo.i95 = trunc i128 %_16.i57 to i64
  %_4.i96 = lshr i128 %_16.i57, 64
  %x_hi.i97 = trunc nuw i128 %_4.i96 to i64
  %x_hi_hi.i98 = lshr i64 %x_hi.i97, 32
  %x_hi_lo.i99 = and i64 %x_hi.i97, 4294967295
  %_9.0.i100 = sub i64 %x_lo.i95, %x_hi_hi.i98
  %_9.1.i101 = icmp ugt i64 %x_hi_hi.i98, %x_lo.i95
  %_10.i102 = add i64 %_9.0.i100, -4294967295
  %spec.select.i103 = select i1 %_9.1.i101, i64 %_10.i102, i64 %_9.0.i100
  %t1.i104 = mul nuw i64 %x_hi_lo.i99, 4294967295
  %_14.0.i105 = add i64 %spec.select.i103, %t1.i104
  %_14.1.i106 = icmp ult i64 %_14.0.i105, %spec.select.i103
  %33 = add i64 %_14.0.i105, 4294967295
  %res.sroa.0.0.i107 = select i1 %_14.1.i106, i64 %33, i64 %_14.0.i105
  %_16.i108 = icmp ugt i64 %res.sroa.0.0.i107, -4294967296
  %_17.i109 = add nsw i64 %res.sroa.0.0.i107, 4294967295
  %_0.sroa.0.0.i110 = select i1 %_16.i108, i64 %_17.i109, i64 %res.sroa.0.0.i107
  %_17.i59 = mul nuw i128 %_12.i50, %_14.i53
  %x_lo.i79 = trunc i128 %_17.i59 to i64
  %_4.i80 = lshr i128 %_17.i59, 64
  %x_hi.i81 = trunc nuw i128 %_4.i80 to i64
  %x_hi_hi.i82 = lshr i64 %x_hi.i81, 32
  %x_hi_lo.i83 = and i64 %x_hi.i81, 4294967295
  %_9.0.i84 = sub i64 %x_lo.i79, %x_hi_hi.i82
  %_9.1.i85 = icmp ugt i64 %x_hi_hi.i82, %x_lo.i79
  %_10.i86 = add i64 %_9.0.i84, -4294967295
  %spec.select.i87 = select i1 %_9.1.i85, i64 %_10.i86, i64 %_9.0.i84
  %t1.i88 = mul nuw i64 %x_hi_lo.i83, 4294967295
  %_14.0.i89 = add i64 %spec.select.i87, %t1.i88
  %_14.1.i90 = icmp ult i64 %_14.0.i89, %spec.select.i87
  %34 = add i64 %_14.0.i89, 4294967295
  %res.sroa.0.0.i91 = select i1 %_14.1.i90, i64 %34, i64 %_14.0.i89
  %_16.i92 = icmp ugt i64 %res.sroa.0.0.i91, -4294967296
  %_17.i93 = add nsw i64 %res.sroa.0.0.i91, 4294967295
  %_0.sroa.0.0.i94 = select i1 %_16.i92, i64 %_17.i93, i64 %res.sroa.0.0.i91
  %_19.i61 = zext i64 %_0.sroa.0.0.i126 to i128
  %_18.i62 = mul nuw nsw i128 %_19.i61, 7
  %x_lo.i = trunc i128 %_18.i62 to i64
  %_4.i = lshr i128 %_18.i62, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_14.0.i = add i64 %t1.i, %x_lo.i
  %_14.1.i = icmp ult i64 %_14.0.i, %x_lo.i
  %35 = add i64 %_14.0.i, 4294967295
  %res.sroa.0.0.i = select i1 %_14.1.i, i64 %35, i64 %_14.0.i
  %_16.i77 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_17.i78 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i = select i1 %_16.i77, i64 %_17.i78, i64 %res.sroa.0.0.i
  %_22.0.i64 = add i64 %_0.sroa.0.0.i, %_0.sroa.0.0.i142
  %_22.1.i65 = icmp ult i64 %_22.0.i64, %_0.sroa.0.0.i142
  %36 = add nuw i64 %_22.0.i64, 4294967295
  %_24.sroa.0.0.i66 = select i1 %_22.1.i65, i64 %36, i64 %_22.0.i64
  %_25.i67 = icmp ugt i64 %_24.sroa.0.0.i66, -4294967296
  %_26.i68 = add nsw i64 %_24.sroa.0.0.i66, 4294967295
  %_7.sroa.0.0.i69 = select i1 %_25.i67, i64 %_26.i68, i64 %_24.sroa.0.0.i66
  %_29.0.i70 = add i64 %_0.sroa.0.0.i110, %_0.sroa.0.0.i94
  %_29.1.i71 = icmp ult i64 %_29.0.i70, %_0.sroa.0.0.i110
  %37 = add nuw i64 %_29.0.i70, 4294967295
  %_30.sroa.0.0.i72 = select i1 %_29.1.i71, i64 %37, i64 %_29.0.i70
  %_31.i73 = icmp ugt i64 %_30.sroa.0.0.i72, -4294967296
  %_32.i74 = add nsw i64 %_30.sroa.0.0.i72, 4294967295
  %_9.sroa.0.0.i75 = select i1 %_31.i73, i64 %_32.i74, i64 %_30.sroa.0.0.i72
  %_7.0.i7 = add i64 %_7.sroa.0.0.i69, %inner.sroa.0.0312
  %_7.1.i8 = icmp ult i64 %_7.0.i7, %inner.sroa.0.0312
  %38 = add i64 %_7.0.i7, 4294967295
  %_8.sroa.0.0.i9 = select i1 %_7.1.i8, i64 %38, i64 %_7.0.i7
  %_9.i10 = icmp ugt i64 %_8.sroa.0.0.i9, -4294967296
  %_10.i11 = add nsw i64 %_8.sroa.0.0.i9, 4294967295
  %_3.sroa.0.0.i12 = select i1 %_9.i10, i64 %_10.i11, i64 %_8.sroa.0.0.i9
  %_13.0.i13 = add i64 %_9.sroa.0.0.i75, %inner.sroa.4.0311
  %_13.1.i14 = icmp ult i64 %_13.0.i13, %inner.sroa.4.0311
  %39 = add i64 %_13.0.i13, 4294967295
  %_14.sroa.0.0.i15 = select i1 %_13.1.i14, i64 %39, i64 %_13.0.i13
  %_15.i16 = icmp ugt i64 %_14.sroa.0.0.i15, -4294967296
  %_16.i17 = add nsw i64 %_14.sroa.0.0.i15, 4294967295
  %_4.sroa.0.0.i18 = select i1 %_15.i16, i64 %_16.i17, i64 %_14.sroa.0.0.i15
  %_74 = icmp eq ptr %_80, %_68
  br i1 %_74, label %bb18, label %bb19

panic2:                                           ; preds = %bb19
; call core::panicking::panic_bounds_check
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef %_20, i64 noundef %v.1, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24) @alloc_953b7a28a8a2723f809dd5bd246c70bc) #21
  unreachable
}

; <alloc::raw_vec::RawVec<(usize, alloc::vec::Vec<(usize, isolated::field::Fp2)>)>>::grow_one
; Function Attrs: cold noinline nonlazybind uwtable
define internal fastcc void @_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjINtNtB7_3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8grow_oneB1a_(ptr noalias noundef nonnull align 8 captures(none) dereferenceable(16) %self) unnamed_addr #4 personality ptr @rust_eh_personality {
start:
  %self3.i = alloca [24 x i8], align 8
  %self1 = load i64, ptr %self, align 8, !range !7, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !520)
  %v16.i = shl nuw i64 %self1, 1
  %0 = tail call i64 @llvm.umax.i64(i64 %v16.i, i64 4)
  call void @llvm.lifetime.start.p0(ptr nonnull %self3.i), !noalias !520
  %1 = getelementptr inbounds nuw i8, ptr %self, i64 8
  %self.val15.i = load ptr, ptr %1, align 8, !alias.scope !520
; call <alloc::raw_vec::RawVecInner>::finish_grow
  call fastcc void @_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated(ptr noalias noundef align 8 captures(none) dereferenceable(24) %self3.i, i64 %self1, ptr %self.val15.i, i64 noundef %0, i64 noundef 32)
  %_37.i = load i64, ptr %self3.i, align 8, !range !56, !noalias !520, !noundef !3
  %2 = trunc nuw i64 %_37.i to i1
  %3 = getelementptr inbounds nuw i8, ptr %self3.i, i64 8
  br i1 %2, label %bb18.i, label %bb3

bb18.i:                                           ; preds = %start
  %e.0.i = load i64, ptr %3, align 8, !range !523, !noalias !520, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %self3.i, i64 16
  %e.1.i = load i64, ptr %4, align 8, !noalias !520
  call void @llvm.lifetime.end.p0(ptr nonnull %self3.i), !noalias !520
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef %e.0.i, i64 %e.1.i) #21
  unreachable

bb3:                                              ; preds = %start
  %v.0.i = load ptr, ptr %3, align 8, !noalias !520, !nonnull !3, !noundef !3
  call void @llvm.lifetime.end.p0(ptr nonnull %self3.i), !noalias !520
  store ptr %v.0.i, ptr %1, align 8, !alias.scope !520
  %5 = icmp sgt i64 %0, -1
  tail call void @llvm.assume(i1 %5)
  store i64 %0, ptr %self, align 8, !alias.scope !520
  ret void
}

; <alloc::raw_vec::RawVec<(usize, isolated::field::Fp2)>>::grow_one
; Function Attrs: cold noinline nonlazybind uwtable
define internal fastcc void @_RNvMs3_NtCs40k4W9msRzi_5alloc7raw_vecINtB5_6RawVecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8grow_oneBS_(ptr noalias noundef nonnull align 8 captures(none) dereferenceable(16) %self) unnamed_addr #4 personality ptr @rust_eh_personality {
start:
  %self3.i = alloca [24 x i8], align 8
  %self1 = load i64, ptr %self, align 8, !range !7, !noundef !3
  tail call void @llvm.experimental.noalias.scope.decl(metadata !524)
  %v16.i = shl nuw i64 %self1, 1
  %0 = tail call i64 @llvm.umax.i64(i64 %v16.i, i64 4)
  call void @llvm.lifetime.start.p0(ptr nonnull %self3.i), !noalias !524
  %1 = getelementptr inbounds nuw i8, ptr %self, i64 8
  %self.val15.i = load ptr, ptr %1, align 8, !alias.scope !524
; call <alloc::raw_vec::RawVecInner>::finish_grow
  call fastcc void @_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated(ptr noalias noundef align 8 captures(none) dereferenceable(24) %self3.i, i64 %self1, ptr %self.val15.i, i64 noundef %0, i64 noundef 24)
  %_37.i = load i64, ptr %self3.i, align 8, !range !56, !noalias !524, !noundef !3
  %2 = trunc nuw i64 %_37.i to i1
  %3 = getelementptr inbounds nuw i8, ptr %self3.i, i64 8
  br i1 %2, label %bb18.i, label %bb3

bb18.i:                                           ; preds = %start
  %e.0.i = load i64, ptr %3, align 8, !range !523, !noalias !524, !noundef !3
  %4 = getelementptr inbounds nuw i8, ptr %self3.i, i64 16
  %e.1.i = load i64, ptr %4, align 8, !noalias !524
  call void @llvm.lifetime.end.p0(ptr nonnull %self3.i), !noalias !524
; call alloc::raw_vec::handle_error
  tail call void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef %e.0.i, i64 %e.1.i) #21
  unreachable

bb3:                                              ; preds = %start
  %v.0.i = load ptr, ptr %3, align 8, !noalias !524, !nonnull !3, !noundef !3
  call void @llvm.lifetime.end.p0(ptr nonnull %self3.i), !noalias !524
  store ptr %v.0.i, ptr %1, align 8, !alias.scope !524
  %5 = icmp sgt i64 %0, -1
  tail call void @llvm.assume(i1 %5)
  store i64 %0, ptr %self, align 8, !alias.scope !524
  ret void
}

; <alloc::raw_vec::RawVecInner>::finish_grow
; Function Attrs: cold nounwind nonlazybind uwtable
define internal fastcc void @_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner11finish_growCsl0YfJI2rrfI_8isolated(ptr dead_on_unwind noalias noundef nonnull writable writeonly align 8 captures(none) dereferenceable(24) initializes((0, 8)) %_0, i64 %self.0.val, ptr %self.8.val, i64 noundef %cap, i64 noundef range(i64 8, 41) %elem_layout.1) unnamed_addr #5 {
start:
  %0 = tail call { i64, i1 } @llvm.umul.with.overflow.i64(i64 %elem_layout.1, i64 %cap)
  %_34.0 = extractvalue { i64, i1 } %0, 0
  %_34.1 = extractvalue { i64, i1 } %0, 1
  %_39 = icmp ugt i64 %_34.0, 9223372036854775800
  %or.cond.not = or i1 %_34.1, %_39
  br i1 %or.cond.not, label %bb11, label %bb15, !prof !506

bb15:                                             ; preds = %start
  %1 = icmp eq i64 %self.0.val, 0
  br i1 %1, label %bb5, label %bb3

bb3:                                              ; preds = %bb15
  %alloc_size.i = mul nuw i64 %elem_layout.1, %self.0.val
  %2 = icmp ne ptr %self.8.val, null
  tail call void @llvm.assume(i1 %2)
  %cond.i.i = icmp uge i64 %_34.0, %alloc_size.i
  tail call void @llvm.assume(i1 %cond.i.i)
; call __rustc::__rust_realloc
  %raw_ptr.i.i = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc14___rust_realloc(ptr noundef nonnull %self.8.val, i64 noundef %alloc_size.i, i64 noundef 8, i64 noundef range(i64 0, 9223372036854775801) %_34.0) #20
  br label %bb7

bb5:                                              ; preds = %bb15
  %3 = icmp eq i64 %_34.0, 0
  br i1 %3, label %bb9, label %bb1.i.i

bb1.i.i:                                          ; preds = %bb5
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20
; call __rustc::__rust_alloc
  %4 = tail call noundef align 8 ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) %_34.0, i64 noundef 8) #20
  br label %bb7

bb7:                                              ; preds = %bb1.i.i, %bb3
  %raw_ptr.i.i.pn = phi ptr [ %raw_ptr.i.i, %bb3 ], [ %4, %bb1.i.i ]
  %5 = icmp eq ptr %raw_ptr.i.i.pn, null
  br i1 %5, label %bb8, label %bb9

bb8:                                              ; preds = %bb7
  %6 = getelementptr inbounds nuw i8, ptr %_0, i64 8
  store i64 8, ptr %6, align 8
  br label %bb11

bb9:                                              ; preds = %bb5, %bb7
  %raw_ptr.i.i.pn8 = phi ptr [ %raw_ptr.i.i.pn, %bb7 ], [ inttoptr (i64 8 to ptr), %bb5 ]
  %7 = getelementptr inbounds nuw i8, ptr %_0, i64 8
  store ptr %raw_ptr.i.i.pn8, ptr %7, align 8
  br label %bb11

bb11:                                             ; preds = %start, %bb9, %bb8
  %.sink9 = phi i64 [ 16, %bb9 ], [ 16, %bb8 ], [ 8, %start ]
  %_34.0.sink = phi i64 [ %_34.0, %bb9 ], [ %_34.0, %bb8 ], [ 0, %start ]
  %storemerge9 = phi i64 [ 0, %bb9 ], [ 1, %bb8 ], [ 1, %start ]
  %8 = getelementptr inbounds nuw i8, ptr %_0, i64 %.sink9
  store i64 %_34.0.sink, ptr %8, align 8
  store i64 %storemerge9, ptr %_0, align 8
  ret void
}

; Function Attrs: nounwind nonlazybind uwtable
define void @fzc(ptr noundef writeonly captures(none) %out, ptr noundef readonly captures(none) %words, i32 noundef %hh, i32 noundef %gg, i32 noundef %pad, i64 noundef %nlk, i32 noundef %mode) unnamed_addr #0 personality ptr @rust_eh_personality {
bb3.i.i.i:
; call __rustc::__rust_no_alloc_shim_is_unstable_v2
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() #20, !noalias !527
; call __rustc::__rust_alloc
  %0 = tail call noundef align 8 dereferenceable_or_null(608) ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef range(i64 0, 9223372036854775801) 608, i64 noundef 8) #20, !noalias !527
  %1 = icmp eq ptr %0, null
  br i1 %1, label %bb3.i.i, label %bb3.i.i.i.i.i.i

terminate.body:                                   ; preds = %bb3.i.i
  %2 = landingpad { ptr, i32 }
          filter [0 x ptr] zeroinitializer
; call core::panicking::panic_cannot_unwind
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking19panic_cannot_unwind() #23
  unreachable

bb3.i.i:                                          ; preds = %bb3.i.i.i
; invoke alloc::raw_vec::handle_error
  invoke void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef 8, i64 608) #21
          to label %.noexc10 unwind label %terminate.body

.noexc10:                                         ; preds = %bb3.i.i
  unreachable

bb3.i.i.i.i.i.i:                                  ; preds = %bb3.i.i.i
  %data.i.i.i.i.i.i.i.i = getelementptr inbounds nuw i8, ptr %words, i64 16
  tail call void @llvm.experimental.noalias.scope.decl(metadata !533)
  %3 = load <2 x i64>, ptr %words, align 8, !alias.scope !536, !noalias !539
  store <2 x i64> %3, ptr %0, align 8, !noalias !556
  %data.i.i.i.i.i.i.i.i.1 = getelementptr inbounds nuw i8, ptr %words, i64 32
  tail call void @llvm.experimental.noalias.scope.decl(metadata !561)
  %_3.i.i.i.i.i.i.i.i.i.1 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %4 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i, align 8, !alias.scope !563, !noalias !539
  store <2 x i64> %4, ptr %_3.i.i.i.i.i.i.i.i.i.1, align 8, !noalias !564
  %data.i.i.i.i.i.i.i.i.2 = getelementptr inbounds nuw i8, ptr %words, i64 48
  tail call void @llvm.experimental.noalias.scope.decl(metadata !565)
  %_3.i.i.i.i.i.i.i.i.i.2 = getelementptr inbounds nuw i8, ptr %0, i64 32
  %5 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.1, align 8, !alias.scope !567, !noalias !539
  store <2 x i64> %5, ptr %_3.i.i.i.i.i.i.i.i.i.2, align 8, !noalias !568
  %data.i.i.i.i.i.i.i.i.3 = getelementptr inbounds nuw i8, ptr %words, i64 64
  tail call void @llvm.experimental.noalias.scope.decl(metadata !569)
  %_3.i.i.i.i.i.i.i.i.i.3 = getelementptr inbounds nuw i8, ptr %0, i64 48
  %6 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.2, align 8, !alias.scope !571, !noalias !539
  store <2 x i64> %6, ptr %_3.i.i.i.i.i.i.i.i.i.3, align 8, !noalias !572
  %data.i.i.i.i.i.i.i.i.4 = getelementptr inbounds nuw i8, ptr %words, i64 80
  tail call void @llvm.experimental.noalias.scope.decl(metadata !573)
  %_3.i.i.i.i.i.i.i.i.i.4 = getelementptr inbounds nuw i8, ptr %0, i64 64
  %7 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.3, align 8, !alias.scope !575, !noalias !539
  store <2 x i64> %7, ptr %_3.i.i.i.i.i.i.i.i.i.4, align 8, !noalias !576
  %data.i.i.i.i.i.i.i.i.5 = getelementptr inbounds nuw i8, ptr %words, i64 96
  tail call void @llvm.experimental.noalias.scope.decl(metadata !577)
  %_3.i.i.i.i.i.i.i.i.i.5 = getelementptr inbounds nuw i8, ptr %0, i64 80
  %8 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.4, align 8, !alias.scope !579, !noalias !539
  store <2 x i64> %8, ptr %_3.i.i.i.i.i.i.i.i.i.5, align 8, !noalias !580
  %data.i.i.i.i.i.i.i.i.6 = getelementptr inbounds nuw i8, ptr %words, i64 112
  tail call void @llvm.experimental.noalias.scope.decl(metadata !581)
  %_3.i.i.i.i.i.i.i.i.i.6 = getelementptr inbounds nuw i8, ptr %0, i64 96
  %9 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.5, align 8, !alias.scope !583, !noalias !539
  store <2 x i64> %9, ptr %_3.i.i.i.i.i.i.i.i.i.6, align 8, !noalias !584
  %data.i.i.i.i.i.i.i.i.7 = getelementptr inbounds nuw i8, ptr %words, i64 128
  tail call void @llvm.experimental.noalias.scope.decl(metadata !585)
  %_3.i.i.i.i.i.i.i.i.i.7 = getelementptr inbounds nuw i8, ptr %0, i64 112
  %10 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.6, align 8, !alias.scope !587, !noalias !539
  store <2 x i64> %10, ptr %_3.i.i.i.i.i.i.i.i.i.7, align 8, !noalias !588
  %data.i.i.i.i.i.i.i.i.8 = getelementptr inbounds nuw i8, ptr %words, i64 144
  tail call void @llvm.experimental.noalias.scope.decl(metadata !589)
  %_3.i.i.i.i.i.i.i.i.i.8 = getelementptr inbounds nuw i8, ptr %0, i64 128
  %11 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.7, align 8, !alias.scope !591, !noalias !539
  store <2 x i64> %11, ptr %_3.i.i.i.i.i.i.i.i.i.8, align 8, !noalias !592
  %data.i.i.i.i.i.i.i.i.9 = getelementptr inbounds nuw i8, ptr %words, i64 160
  tail call void @llvm.experimental.noalias.scope.decl(metadata !593)
  %_3.i.i.i.i.i.i.i.i.i.9 = getelementptr inbounds nuw i8, ptr %0, i64 144
  %12 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.8, align 8, !alias.scope !595, !noalias !539
  store <2 x i64> %12, ptr %_3.i.i.i.i.i.i.i.i.i.9, align 8, !noalias !596
  %data.i.i.i.i.i.i.i.i.10 = getelementptr inbounds nuw i8, ptr %words, i64 176
  tail call void @llvm.experimental.noalias.scope.decl(metadata !597)
  %_3.i.i.i.i.i.i.i.i.i.10 = getelementptr inbounds nuw i8, ptr %0, i64 160
  %13 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.9, align 8, !alias.scope !599, !noalias !539
  store <2 x i64> %13, ptr %_3.i.i.i.i.i.i.i.i.i.10, align 8, !noalias !600
  %data.i.i.i.i.i.i.i.i.11 = getelementptr inbounds nuw i8, ptr %words, i64 192
  tail call void @llvm.experimental.noalias.scope.decl(metadata !601)
  %_3.i.i.i.i.i.i.i.i.i.11 = getelementptr inbounds nuw i8, ptr %0, i64 176
  %14 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.10, align 8, !alias.scope !603, !noalias !539
  store <2 x i64> %14, ptr %_3.i.i.i.i.i.i.i.i.i.11, align 8, !noalias !604
  %data.i.i.i.i.i.i.i.i.12 = getelementptr inbounds nuw i8, ptr %words, i64 208
  tail call void @llvm.experimental.noalias.scope.decl(metadata !605)
  %_3.i.i.i.i.i.i.i.i.i.12 = getelementptr inbounds nuw i8, ptr %0, i64 192
  %15 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.11, align 8, !alias.scope !607, !noalias !539
  store <2 x i64> %15, ptr %_3.i.i.i.i.i.i.i.i.i.12, align 8, !noalias !608
  %data.i.i.i.i.i.i.i.i.13 = getelementptr inbounds nuw i8, ptr %words, i64 224
  tail call void @llvm.experimental.noalias.scope.decl(metadata !609)
  %_3.i.i.i.i.i.i.i.i.i.13 = getelementptr inbounds nuw i8, ptr %0, i64 208
  %16 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.12, align 8, !alias.scope !611, !noalias !539
  store <2 x i64> %16, ptr %_3.i.i.i.i.i.i.i.i.i.13, align 8, !noalias !612
  %data.i.i.i.i.i.i.i.i.14 = getelementptr inbounds nuw i8, ptr %words, i64 240
  tail call void @llvm.experimental.noalias.scope.decl(metadata !613)
  %_3.i.i.i.i.i.i.i.i.i.14 = getelementptr inbounds nuw i8, ptr %0, i64 224
  %17 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.13, align 8, !alias.scope !615, !noalias !539
  store <2 x i64> %17, ptr %_3.i.i.i.i.i.i.i.i.i.14, align 8, !noalias !616
  %data.i.i.i.i.i.i.i.i.15 = getelementptr inbounds nuw i8, ptr %words, i64 256
  tail call void @llvm.experimental.noalias.scope.decl(metadata !617)
  %_3.i.i.i.i.i.i.i.i.i.15 = getelementptr inbounds nuw i8, ptr %0, i64 240
  %18 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.14, align 8, !alias.scope !619, !noalias !539
  store <2 x i64> %18, ptr %_3.i.i.i.i.i.i.i.i.i.15, align 8, !noalias !620
  %data.i.i.i.i.i.i.i.i.16 = getelementptr inbounds nuw i8, ptr %words, i64 272
  tail call void @llvm.experimental.noalias.scope.decl(metadata !621)
  %_3.i.i.i.i.i.i.i.i.i.16 = getelementptr inbounds nuw i8, ptr %0, i64 256
  %19 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.15, align 8, !alias.scope !623, !noalias !539
  store <2 x i64> %19, ptr %_3.i.i.i.i.i.i.i.i.i.16, align 8, !noalias !624
  %data.i.i.i.i.i.i.i.i.17 = getelementptr inbounds nuw i8, ptr %words, i64 288
  tail call void @llvm.experimental.noalias.scope.decl(metadata !625)
  %_3.i.i.i.i.i.i.i.i.i.17 = getelementptr inbounds nuw i8, ptr %0, i64 272
  %20 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.16, align 8, !alias.scope !627, !noalias !539
  store <2 x i64> %20, ptr %_3.i.i.i.i.i.i.i.i.i.17, align 8, !noalias !628
  %data.i.i.i.i.i.i.i.i.18 = getelementptr inbounds nuw i8, ptr %words, i64 304
  tail call void @llvm.experimental.noalias.scope.decl(metadata !629)
  %_3.i.i.i.i.i.i.i.i.i.18 = getelementptr inbounds nuw i8, ptr %0, i64 288
  %21 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.17, align 8, !alias.scope !631, !noalias !539
  store <2 x i64> %21, ptr %_3.i.i.i.i.i.i.i.i.i.18, align 8, !noalias !632
  %data.i.i.i.i.i.i.i.i.19 = getelementptr inbounds nuw i8, ptr %words, i64 320
  tail call void @llvm.experimental.noalias.scope.decl(metadata !633)
  %_3.i.i.i.i.i.i.i.i.i.19 = getelementptr inbounds nuw i8, ptr %0, i64 304
  %22 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.18, align 8, !alias.scope !635, !noalias !539
  store <2 x i64> %22, ptr %_3.i.i.i.i.i.i.i.i.i.19, align 8, !noalias !636
  %data.i.i.i.i.i.i.i.i.20 = getelementptr inbounds nuw i8, ptr %words, i64 336
  tail call void @llvm.experimental.noalias.scope.decl(metadata !637)
  %_3.i.i.i.i.i.i.i.i.i.20 = getelementptr inbounds nuw i8, ptr %0, i64 320
  %23 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.19, align 8, !alias.scope !639, !noalias !539
  store <2 x i64> %23, ptr %_3.i.i.i.i.i.i.i.i.i.20, align 8, !noalias !640
  %data.i.i.i.i.i.i.i.i.21 = getelementptr inbounds nuw i8, ptr %words, i64 352
  tail call void @llvm.experimental.noalias.scope.decl(metadata !641)
  %_3.i.i.i.i.i.i.i.i.i.21 = getelementptr inbounds nuw i8, ptr %0, i64 336
  %24 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.20, align 8, !alias.scope !643, !noalias !539
  store <2 x i64> %24, ptr %_3.i.i.i.i.i.i.i.i.i.21, align 8, !noalias !644
  %data.i.i.i.i.i.i.i.i.22 = getelementptr inbounds nuw i8, ptr %words, i64 368
  tail call void @llvm.experimental.noalias.scope.decl(metadata !645)
  %_3.i.i.i.i.i.i.i.i.i.22 = getelementptr inbounds nuw i8, ptr %0, i64 352
  %25 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.21, align 8, !alias.scope !647, !noalias !539
  store <2 x i64> %25, ptr %_3.i.i.i.i.i.i.i.i.i.22, align 8, !noalias !648
  %data.i.i.i.i.i.i.i.i.23 = getelementptr inbounds nuw i8, ptr %words, i64 384
  tail call void @llvm.experimental.noalias.scope.decl(metadata !649)
  %_3.i.i.i.i.i.i.i.i.i.23 = getelementptr inbounds nuw i8, ptr %0, i64 368
  %26 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.22, align 8, !alias.scope !651, !noalias !539
  store <2 x i64> %26, ptr %_3.i.i.i.i.i.i.i.i.i.23, align 8, !noalias !652
  %data.i.i.i.i.i.i.i.i.24 = getelementptr inbounds nuw i8, ptr %words, i64 400
  tail call void @llvm.experimental.noalias.scope.decl(metadata !653)
  %_3.i.i.i.i.i.i.i.i.i.24 = getelementptr inbounds nuw i8, ptr %0, i64 384
  %27 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.23, align 8, !alias.scope !655, !noalias !539
  store <2 x i64> %27, ptr %_3.i.i.i.i.i.i.i.i.i.24, align 8, !noalias !656
  %data.i.i.i.i.i.i.i.i.25 = getelementptr inbounds nuw i8, ptr %words, i64 416
  tail call void @llvm.experimental.noalias.scope.decl(metadata !657)
  %_3.i.i.i.i.i.i.i.i.i.25 = getelementptr inbounds nuw i8, ptr %0, i64 400
  %28 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.24, align 8, !alias.scope !659, !noalias !539
  store <2 x i64> %28, ptr %_3.i.i.i.i.i.i.i.i.i.25, align 8, !noalias !660
  %data.i.i.i.i.i.i.i.i.26 = getelementptr inbounds nuw i8, ptr %words, i64 432
  tail call void @llvm.experimental.noalias.scope.decl(metadata !661)
  %_3.i.i.i.i.i.i.i.i.i.26 = getelementptr inbounds nuw i8, ptr %0, i64 416
  %29 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.25, align 8, !alias.scope !663, !noalias !539
  store <2 x i64> %29, ptr %_3.i.i.i.i.i.i.i.i.i.26, align 8, !noalias !664
  %data.i.i.i.i.i.i.i.i.27 = getelementptr inbounds nuw i8, ptr %words, i64 448
  tail call void @llvm.experimental.noalias.scope.decl(metadata !665)
  %_3.i.i.i.i.i.i.i.i.i.27 = getelementptr inbounds nuw i8, ptr %0, i64 432
  %30 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.26, align 8, !alias.scope !667, !noalias !539
  store <2 x i64> %30, ptr %_3.i.i.i.i.i.i.i.i.i.27, align 8, !noalias !668
  %data.i.i.i.i.i.i.i.i.28 = getelementptr inbounds nuw i8, ptr %words, i64 464
  tail call void @llvm.experimental.noalias.scope.decl(metadata !669)
  %_3.i.i.i.i.i.i.i.i.i.28 = getelementptr inbounds nuw i8, ptr %0, i64 448
  %31 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.27, align 8, !alias.scope !671, !noalias !539
  store <2 x i64> %31, ptr %_3.i.i.i.i.i.i.i.i.i.28, align 8, !noalias !672
  %data.i.i.i.i.i.i.i.i.29 = getelementptr inbounds nuw i8, ptr %words, i64 480
  tail call void @llvm.experimental.noalias.scope.decl(metadata !673)
  %_3.i.i.i.i.i.i.i.i.i.29 = getelementptr inbounds nuw i8, ptr %0, i64 464
  %32 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.28, align 8, !alias.scope !675, !noalias !539
  store <2 x i64> %32, ptr %_3.i.i.i.i.i.i.i.i.i.29, align 8, !noalias !676
  %data.i.i.i.i.i.i.i.i.30 = getelementptr inbounds nuw i8, ptr %words, i64 496
  tail call void @llvm.experimental.noalias.scope.decl(metadata !677)
  %_3.i.i.i.i.i.i.i.i.i.30 = getelementptr inbounds nuw i8, ptr %0, i64 480
  %33 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.29, align 8, !alias.scope !679, !noalias !539
  store <2 x i64> %33, ptr %_3.i.i.i.i.i.i.i.i.i.30, align 8, !noalias !680
  %data.i.i.i.i.i.i.i.i.31 = getelementptr inbounds nuw i8, ptr %words, i64 512
  tail call void @llvm.experimental.noalias.scope.decl(metadata !681)
  %_3.i.i.i.i.i.i.i.i.i.31 = getelementptr inbounds nuw i8, ptr %0, i64 496
  %34 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.30, align 8, !alias.scope !683, !noalias !539
  store <2 x i64> %34, ptr %_3.i.i.i.i.i.i.i.i.i.31, align 8, !noalias !684
  %data.i.i.i.i.i.i.i.i.32 = getelementptr inbounds nuw i8, ptr %words, i64 528
  tail call void @llvm.experimental.noalias.scope.decl(metadata !685)
  %_3.i.i.i.i.i.i.i.i.i.32 = getelementptr inbounds nuw i8, ptr %0, i64 512
  %35 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.31, align 8, !alias.scope !687, !noalias !539
  store <2 x i64> %35, ptr %_3.i.i.i.i.i.i.i.i.i.32, align 8, !noalias !688
  %data.i.i.i.i.i.i.i.i.33 = getelementptr inbounds nuw i8, ptr %words, i64 544
  tail call void @llvm.experimental.noalias.scope.decl(metadata !689)
  %_3.i.i.i.i.i.i.i.i.i.33 = getelementptr inbounds nuw i8, ptr %0, i64 528
  %36 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.32, align 8, !alias.scope !691, !noalias !539
  store <2 x i64> %36, ptr %_3.i.i.i.i.i.i.i.i.i.33, align 8, !noalias !692
  %data.i.i.i.i.i.i.i.i.34 = getelementptr inbounds nuw i8, ptr %words, i64 560
  tail call void @llvm.experimental.noalias.scope.decl(metadata !693)
  %_3.i.i.i.i.i.i.i.i.i.34 = getelementptr inbounds nuw i8, ptr %0, i64 544
  %37 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.33, align 8, !alias.scope !695, !noalias !539
  store <2 x i64> %37, ptr %_3.i.i.i.i.i.i.i.i.i.34, align 8, !noalias !696
  %data.i.i.i.i.i.i.i.i.35 = getelementptr inbounds nuw i8, ptr %words, i64 576
  tail call void @llvm.experimental.noalias.scope.decl(metadata !697)
  %_3.i.i.i.i.i.i.i.i.i.35 = getelementptr inbounds nuw i8, ptr %0, i64 560
  %38 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.34, align 8, !alias.scope !699, !noalias !539
  store <2 x i64> %38, ptr %_3.i.i.i.i.i.i.i.i.i.35, align 8, !noalias !700
  %data.i.i.i.i.i.i.i.i.36 = getelementptr inbounds nuw i8, ptr %words, i64 592
  tail call void @llvm.experimental.noalias.scope.decl(metadata !701)
  %_3.i.i.i.i.i.i.i.i.i.36 = getelementptr inbounds nuw i8, ptr %0, i64 576
  %39 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.35, align 8, !alias.scope !703, !noalias !539
  store <2 x i64> %39, ptr %_3.i.i.i.i.i.i.i.i.i.36, align 8, !noalias !704
  tail call void @llvm.experimental.noalias.scope.decl(metadata !705)
  %_3.i.i.i.i.i.i.i.i.i.37 = getelementptr inbounds nuw i8, ptr %0, i64 592
  %40 = load <2 x i64>, ptr %data.i.i.i.i.i.i.i.i.36, align 8, !alias.scope !707, !noalias !539
  store <2 x i64> %40, ptr %_3.i.i.i.i.i.i.i.i.i.37, align 8, !noalias !708
  %_23 = icmp ne i32 %pad, 0
  switch i32 %mode, label %bb2 [
    i32 0, label %bb5
    i32 1, label %bb4
    i32 2, label %bb3
  ]

bb2:                                              ; preds = %bb3.i.i.i.i.i.i
; invoke isolated::factory_3
  %41 = invoke fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_3(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef 38, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %_23, i64 noundef %nlk)
          to label %bb17 unwind label %cleanup

bb5:                                              ; preds = %bb3.i.i.i.i.i.i
; invoke isolated::factory_0
  %42 = invoke fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_0(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef 38, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %_23, i64 noundef %nlk)
          to label %bb17 unwind label %cleanup

bb4:                                              ; preds = %bb3.i.i.i.i.i.i
; invoke isolated::factory_1
  %43 = invoke fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_1(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef 38, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %_23, i64 noundef %nlk)
          to label %bb17 unwind label %cleanup

bb3:                                              ; preds = %bb3.i.i.i.i.i.i
; invoke isolated::factory_2
  %44 = invoke fastcc { ptr, ptr } @_RNvCsl0YfJI2rrfI_8isolated9factory_2(ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef 38, i32 noundef %hh, i32 noundef %gg, i1 noundef zeroext %_23, i64 noundef %nlk)
          to label %bb17 unwind label %cleanup

bb14:                                             ; preds = %cleanup.i, %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i4.i, %cleanup, %cleanup1
; call core::ptr::drop_glue::<alloc::vec::Vec<isolated::field::Fp2>>
  tail call fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEB1c_(i64 38, ptr nonnull %0) #22
; call core::panicking::panic_cannot_unwind
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking19panic_cannot_unwind() #23
  unreachable

cleanup:                                          ; preds = %bb2, %bb3, %bb4, %bb5
  %45 = landingpad { ptr, i32 }
          cleanup
  br label %bb14

bb17:                                             ; preds = %bb5, %bb4, %bb3, %bb2
  %.pn = phi { ptr, ptr } [ %44, %bb3 ], [ %43, %bb4 ], [ %42, %bb5 ], [ %41, %bb2 ]
  %f.sroa.9.0 = phi ptr [ @vtable.2, %bb3 ], [ @vtable.1, %bb4 ], [ @vtable.0, %bb5 ], [ @vtable.3, %bb2 ]
  %f.sroa.0.0 = extractvalue { ptr, ptr } %.pn, 0
  %46 = icmp ne ptr %f.sroa.0.0, null
  tail call void @llvm.assume(i1 %46)
  %47 = getelementptr inbounds nuw i8, ptr %f.sroa.9.0, i64 40
  %48 = load ptr, ptr %47, align 8, !invariant.load !3, !nonnull !3
  %49 = invoke { i64, i64 } %48(ptr noundef nonnull %f.sroa.0.0, ptr noalias noundef nonnull readonly align 8 captures(address, read_provenance) %0, i64 noundef 21)
          to label %bb19 unwind label %cleanup1

cleanup1:                                         ; preds = %bb17
  %50 = landingpad { ptr, i32 }
          cleanup
; invoke core::ptr::drop_glue::<alloc::boxed::Box<dyn for<'a> core::ops::function::Fn<(&'a [isolated::field::Fp2],), Output = isolated::field::Fp2>>>
  invoke fastcc void @_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc5boxed3BoxDG_INtNtNtB4_3ops8function2FnTRL0_SNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEp6OutputB1J_EL_EEB1N_(ptr nonnull %f.sroa.0.0, ptr nonnull %f.sroa.9.0) #22
          to label %bb14 unwind label %terminate3

bb19:                                             ; preds = %bb17
  %z.0 = extractvalue { i64, i64 } %49, 0
  %z.1 = extractvalue { i64, i64 } %49, 1
  store i64 %z.0, ptr %out, align 8
  %_29 = getelementptr inbounds nuw i8, ptr %out, i64 8
  store i64 %z.1, ptr %_29, align 8
  %51 = load ptr, ptr %f.sroa.9.0, align 8, !invariant.load !3
  %.not.i = icmp eq ptr %51, null
  br i1 %.not.i, label %bb3.i11, label %is_not_null.i

is_not_null.i:                                    ; preds = %bb19
  invoke void %51(ptr noundef nonnull %f.sroa.0.0)
          to label %bb3.i11 unwind label %cleanup.i

bb3.i11:                                          ; preds = %is_not_null.i, %bb19
  %52 = getelementptr inbounds nuw i8, ptr %f.sroa.9.0, i64 8
  %53 = load i64, ptr %52, align 8, !range !7, !invariant.load !3
  %54 = icmp eq i64 %53, 0
  br i1 %54, label %bb12, label %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i.i

_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i.i: ; preds = %bb3.i11
  %55 = getelementptr inbounds nuw i8, ptr %f.sroa.9.0, i64 16
  %56 = load i64, ptr %55, align 8, !range !8, !invariant.load !3
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %f.sroa.0.0, i64 noundef %53, i64 noundef range(i64 1, -9223372036854775807) %56) #20
  br label %bb12

cleanup.i:                                        ; preds = %is_not_null.i
  %57 = landingpad { ptr, i32 }
          cleanup
  %58 = getelementptr inbounds nuw i8, ptr %f.sroa.9.0, i64 8
  %59 = load i64, ptr %58, align 8, !range !7, !invariant.load !3
  %60 = icmp eq i64 %59, 0
  br i1 %60, label %bb14, label %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i4.i

_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i4.i: ; preds = %cleanup.i
  %61 = getelementptr inbounds nuw i8, ptr %f.sroa.9.0, i64 16
  %62 = load i64, ptr %61, align 8, !range !8, !invariant.load !3
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %f.sroa.0.0, i64 noundef %59, i64 noundef range(i64 1, -9223372036854775807) %62) #20
  br label %bb14

bb12:                                             ; preds = %bb3.i11, %_RNvXs_NtCs40k4W9msRzi_5alloc5allocNtB4_6GlobalNtNtCscI6d9CVNmLh_4core5alloc9Allocator10deallocate.exit.i.i
; call __rustc::__rust_dealloc
  tail call void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr noundef nonnull %0, i64 noundef 608, i64 noundef range(i64 1, -9223372036854775807) 8) #20
  ret void

terminate3:                                       ; preds = %cleanup1
  %63 = landingpad { ptr, i32 }
          filter [0 x ptr] zeroinitializer
; call core::panicking::panic_in_cleanup
  tail call void @_RNvNtCscI6d9CVNmLh_4core9panicking16panic_in_cleanup() #23
  unreachable
}

; Function Attrs: nounwind nonlazybind uwtable
declare noundef range(i32 0, 10) i32 @rust_eh_personality(i32 noundef, i32 noundef, i64 noundef, ptr noundef, ptr noundef) unnamed_addr #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #6

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #6

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #7

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #8

; core::panicking::panic_in_cleanup
; Function Attrs: cold minsize noinline noreturn nounwind nonlazybind optsize uwtable
declare void @_RNvNtCscI6d9CVNmLh_4core9panicking16panic_in_cleanup() unnamed_addr #9

; alloc::raw_vec::handle_error
; Function Attrs: cold minsize noreturn nonlazybind optsize uwtable
declare void @_RNvNtCs40k4W9msRzi_5alloc7raw_vec12handle_error(i64 noundef range(i64 0, -9223372036854775807), i64) unnamed_addr #10

; core::panicking::panic_bounds_check
; Function Attrs: cold minsize noinline noreturn nonlazybind optsize uwtable
declare void @_RNvNtCscI6d9CVNmLh_4core9panicking18panic_bounds_check(i64 noundef, i64 noundef, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24)) unnamed_addr #11

; core::slice::index::slice_index_fail
; Function Attrs: cold noinline noreturn nonlazybind uwtable
declare void @_RNvNtNtCscI6d9CVNmLh_4core5slice5index16slice_index_fail(i64 noundef, i64 noundef, i64 noundef, ptr noalias noundef readonly align 8 captures(address, read_provenance) dereferenceable(24)) unnamed_addr #12

; __rustc::__rust_dealloc
; Function Attrs: nounwind nonlazybind allockind("free") uwtable
declare void @_RNvCs9hJ03s5DiqP_7___rustc14___rust_dealloc(ptr allocptr noundef nonnull captures(address), i64 noundef, i64 noundef range(i64 1, -9223372036854775807)) unnamed_addr #13

; __rustc::__rust_realloc
; Function Attrs: nounwind nonlazybind allockind("realloc,aligned") allocsize(3) uwtable
declare noalias noundef ptr @_RNvCs9hJ03s5DiqP_7___rustc14___rust_realloc(ptr allocptr noundef nonnull, i64 noundef, i64 allocalign noundef range(i64 1, -9223372036854775807), i64 noundef) unnamed_addr #14

; __rustc::__rust_no_alloc_shim_is_unstable_v2
; Function Attrs: nounwind nonlazybind uwtable
declare void @_RNvCs9hJ03s5DiqP_7___rustc35___rust_no_alloc_shim_is_unstable_v2() unnamed_addr #0

; __rustc::__rust_alloc
; Function Attrs: nounwind nonlazybind allockind("alloc,uninitialized,aligned") allocsize(0) uwtable
declare noalias noundef ptr @_RNvCs9hJ03s5DiqP_7___rustc12___rust_alloc(i64 noundef, i64 allocalign noundef range(i64 1, -9223372036854775807)) unnamed_addr #15

; Function Attrs: mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.umul.with.overflow.i64(i64, i64) #16

; alloc::alloc::handle_alloc_error
; Function Attrs: cold minsize noreturn nonlazybind optsize uwtable
declare void @_RNvNtCs40k4W9msRzi_5alloc5alloc18handle_alloc_error(i64 noundef range(i64 1, -9223372036854775807), i64 noundef) unnamed_addr #10

; core::panicking::panic_cannot_unwind
; Function Attrs: cold minsize noinline noreturn nounwind nonlazybind optsize uwtable
declare void @_RNvNtCscI6d9CVNmLh_4core9panicking19panic_cannot_unwind() unnamed_addr #9

; Function Attrs: nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite)
declare void @llvm.experimental.noalias.scope.decl(metadata) #17

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.umax.i64(i64, i64) #18

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #19

attributes #0 = { nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #1 = { nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #2 = { inlinehint nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #3 = { noinline nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #4 = { cold noinline nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #5 = { cold nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #6 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #7 = { mustprogress nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #8 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #9 = { cold minsize noinline noreturn nounwind nonlazybind optsize uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #10 = { cold minsize noreturn nonlazybind optsize uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #11 = { cold minsize noinline noreturn nonlazybind optsize uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #12 = { cold noinline noreturn nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #13 = { nounwind nonlazybind allockind("free") uwtable "alloc-family"="__rust_alloc" "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #14 = { nounwind nonlazybind allockind("realloc,aligned") allocsize(3) uwtable "alloc-family"="__rust_alloc" "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #15 = { nounwind nonlazybind allockind("alloc,uninitialized,aligned") allocsize(0) uwtable "alloc-family"="__rust_alloc" "alloc-variant-zeroed"="_RNvCs9hJ03s5DiqP_7___rustc19___rust_alloc_zeroed" "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #16 = { mustprogress nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #17 = { nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: readwrite) }
attributes #18 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #19 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #20 = { nounwind }
attributes #21 = { noreturn }
attributes #22 = { cold }
attributes #23 = { cold noreturn nounwind }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 2, !"RtLibUseGOT", i32 1}
!2 = !{!"rustc version 1.97.0 (2d8144b78 2026-07-07)"}
!3 = !{}
!4 = !{!5}
!5 = distinct !{!5, !6, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSNtCsl0YfJI2rrfI_8isolated3LkTEBE_: %_1.0"}
!6 = distinct !{!6, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSNtCsl0YfJI2rrfI_8isolated3LkTEBE_"}
!7 = !{i64 0, i64 -9223372036854775808}
!8 = !{i64 1, i64 536870913}
!9 = !{!10}
!10 = distinct !{!10, !11, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_: %_1"}
!11 = distinct !{!11, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_"}
!12 = !{!13}
!13 = distinct !{!13, !14, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSNtCsl0YfJI2rrfI_8isolated3LkTEBE_: %_1.0"}
!14 = distinct !{!14, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSNtCsl0YfJI2rrfI_8isolated3LkTEBE_"}
!15 = !{!13, !10}
!16 = !{!17}
!17 = distinct !{!17, !18, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_: %_1"}
!18 = distinct !{!18, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_"}
!19 = !{!20}
!20 = distinct !{!20, !21, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_: %_1"}
!21 = distinct !{!21, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_"}
!22 = !{!20, !17}
!23 = !{!24}
!24 = distinct !{!24, !25, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1h_: %_1.0"}
!25 = distinct !{!25, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1h_"}
!26 = !{!24, !20, !17}
!27 = !{!28}
!28 = distinct !{!28, !29, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_: %_1"}
!29 = distinct !{!29, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecNtCsl0YfJI2rrfI_8isolated3LkTEEB1a_"}
!30 = !{!31}
!31 = distinct !{!31, !32, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSNtCsl0YfJI2rrfI_8isolated3LkTEBE_: %_1.0"}
!32 = distinct !{!32, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSNtCsl0YfJI2rrfI_8isolated3LkTEBE_"}
!33 = !{!31, !28}
!34 = !{!35}
!35 = distinct !{!35, !36, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_: %_1"}
!36 = distinct !{!36, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueNtCsl0YfJI2rrfI_8isolated7PadTermEBD_"}
!37 = !{!38}
!38 = distinct !{!38, !39, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_: %_1"}
!39 = distinct !{!39, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_"}
!40 = !{!38, !35}
!41 = !{!42}
!42 = distinct !{!42, !43, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1h_: %_1.0"}
!43 = distinct !{!43, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1h_"}
!44 = !{!42, !38, !35}
!45 = !{!46}
!46 = distinct !{!46, !47, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_: %_1"}
!47 = distinct !{!47, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueINtNtCs40k4W9msRzi_5alloc3vec3VecTjIBC_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEEB1k_"}
!48 = !{!49}
!49 = distinct !{!49, !50, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1h_: %_1.0"}
!50 = distinct !{!50, !"_RINvNtCscI6d9CVNmLh_4core3ptr9drop_glueSTjINtNtCs40k4W9msRzi_5alloc3vec3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEEB1h_"}
!51 = !{!49, !46}
!52 = !{i64 8}
!53 = !{!54}
!54 = distinct !{!54, !55, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjNtNtCsl0YfJI2rrfI_8isolated5field2FpEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldNtBU_3Fp2NCNCNvBW_10helper_sum00EBW_: argument 0"}
!55 = distinct !{!55, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjNtNtCsl0YfJI2rrfI_8isolated5field2FpEENtNtNtNtBb_4iter6traits8iterator8Iterator4foldNtBU_3Fp2NCNCNvBW_10helper_sum00EBW_"}
!56 = !{i64 0, i64 2}
!57 = !{!"branch_weights", !"expected", i32 1, i32 2000}
!58 = !{!59, !61, !63}
!59 = distinct !{!59, !60, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %self.0"}
!60 = distinct !{!60, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_"}
!61 = distinct !{!61, !62, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %self"}
!62 = distinct !{!62, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_"}
!63 = distinct !{!63, !64, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %self"}
!64 = distinct !{!64, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_"}
!65 = !{!66, !67, !68}
!66 = distinct !{!66, !60, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %_0"}
!67 = distinct !{!67, !62, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %_0"}
!68 = distinct !{!68, !64, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %_0"}
!69 = !{!70, !72, !74}
!70 = distinct !{!70, !71, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %self.0"}
!71 = distinct !{!71, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_"}
!72 = distinct !{!72, !73, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %self"}
!73 = distinct !{!73, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_"}
!74 = distinct !{!74, !75, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %self"}
!75 = distinct !{!75, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_"}
!76 = !{!77, !78, !79}
!77 = distinct !{!77, !71, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %_0"}
!78 = distinct !{!78, !73, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %_0"}
!79 = distinct !{!79, !75, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %_0"}
!80 = !{!81, !83, !85}
!81 = distinct !{!81, !82, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %self.0"}
!82 = distinct !{!82, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_"}
!83 = distinct !{!83, !84, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %self"}
!84 = distinct !{!84, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_"}
!85 = distinct !{!85, !86, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %self"}
!86 = distinct !{!86, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_"}
!87 = !{!88, !89, !90}
!88 = distinct !{!88, !82, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %_0"}
!89 = distinct !{!89, !84, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %_0"}
!90 = distinct !{!90, !86, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %_0"}
!91 = !{!92, !94, !96}
!92 = distinct !{!92, !93, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %self.0"}
!93 = distinct !{!93, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_"}
!94 = distinct !{!94, !95, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %self"}
!95 = distinct !{!95, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_"}
!96 = distinct !{!96, !97, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %self"}
!97 = distinct !{!97, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_"}
!98 = !{!99, !100, !101}
!99 = distinct !{!99, !93, !"_RNvMs6_NtNtNtCscI6d9CVNmLh_4core5array4iter10iter_innerINtB5_15PolymorphicIterSINtNtNtBb_3mem12maybe_uninit11MaybeUninitNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE4nextB1Y_: %_0"}
!100 = distinct !{!100, !95, !"_RNvXs2_NtNtCscI6d9CVNmLh_4core5array4iterINtB5_8IntoIterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2Kj3_ENtNtNtNtB9_4iter6traits8iterator8Iterator4nextBW_: %_0"}
!101 = distinct !{!101, !97, !"_RNvXs2_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3zipINtB5_3ZipINtNtNtBb_5slice4iter4IterNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtNtNtBb_5array4iter8IntoIterB1m_Kj3_EEINtB5_7ZipImplBW_B1Y_E4nextB1q_: %_0"}
!102 = !{!103, !105}
!103 = distinct !{!103, !104, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!104 = distinct !{!104, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!105 = distinct !{!105, !106, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated: %_0"}
!106 = distinct !{!106, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated"}
!107 = !{!105}
!108 = !{!"branch_weights", !"expected", i32 2000, i32 1}
!109 = !{!110}
!110 = distinct !{!110, !111, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!111 = distinct !{!111, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!112 = !{!113}
!113 = distinct !{!113, !114, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!114 = distinct !{!114, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!115 = !{!"branch_weights", i32 4000000, i32 4001}
!116 = !{!117, !119}
!117 = distinct !{!117, !118, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_00EE9from_iterB15_: %_0"}
!118 = distinct !{!118, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_00EE9from_iterB15_"}
!119 = distinct !{!119, !118, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_00EE9from_iterB15_: %iterator"}
!120 = !{!121, !117, !119}
!121 = distinct !{!121, !122, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!122 = distinct !{!122, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!123 = !{!124}
!124 = distinct !{!124, !125, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_00EE11spec_extendBV_: %self"}
!125 = distinct !{!125, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_00EE11spec_extendBV_"}
!126 = !{!127}
!127 = distinct !{!127, !128, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_00EEBI_: %self"}
!128 = distinct !{!128, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_00EEBI_"}
!129 = !{!130, !132, !134, !135, !137, !127, !138, !124, !139, !117, !119}
!130 = distinct !{!130, !131, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_00NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_: %f"}
!131 = distinct !{!131, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_00NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_"}
!132 = distinct !{!132, !133, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_00ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %self"}
!133 = distinct !{!133, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_00ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_"}
!134 = distinct !{!134, !133, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_00ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %g"}
!135 = distinct !{!135, !136, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_00ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %self"}
!136 = distinct !{!136, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_00ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_"}
!137 = distinct !{!137, !136, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_00ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %f"}
!138 = distinct !{!138, !128, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_00EEBI_: %iterator"}
!139 = distinct !{!139, !125, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_00EE11spec_extendBV_: %iterator"}
!140 = !{!141, !143, !130, !132, !134, !135, !137, !127, !138, !124, !139, !117, !119}
!141 = distinct !{!141, !142, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_00B3_: %_0"}
!142 = distinct !{!142, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_00B3_"}
!143 = distinct !{!143, !144, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_00NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_: %_1"}
!144 = distinct !{!144, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_00NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_"}
!145 = !{!146, !148, !143, !130, !132, !134, !135, !137, !127, !138, !124, !139, !117, !119}
!146 = distinct !{!146, !147, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_00EE0BK_: %_1"}
!147 = distinct !{!147, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_00EE0BK_"}
!148 = distinct !{!148, !149, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_00EE0E0B1h_: %_1"}
!149 = distinct !{!149, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_00EE0E0B1h_"}
!150 = !{!127, !124}
!151 = !{!130, !132, !134, !135, !137, !138, !139, !117, !119}
!152 = !{!119}
!153 = !{!154}
!154 = distinct !{!154, !155, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0E3newBI_: %x"}
!155 = distinct !{!155, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_0s_0E3newBI_"}
!156 = !{!157, !159}
!157 = distinct !{!157, !158, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!158 = distinct !{!158, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!159 = distinct !{!159, !160, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated: %_0"}
!160 = distinct !{!160, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated"}
!161 = !{!162, !164, !166, !168, !170, !172, !159}
!162 = distinct !{!162, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1"}
!163 = distinct !{!163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated"}
!164 = distinct !{!164, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1"}
!165 = distinct !{!165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated"}
!166 = distinct !{!166, !167, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated: %f"}
!167 = distinct !{!167, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated"}
!168 = distinct !{!168, !169, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated: %f"}
!169 = distinct !{!169, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated"}
!170 = distinct !{!170, !171, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated: %self"}
!171 = distinct !{!171, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated"}
!172 = distinct !{!172, !173, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated: %self"}
!173 = distinct !{!173, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated"}
!174 = !{!175, !176, !166, !168, !170, !172, !159}
!175 = distinct !{!175, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!176 = distinct !{!176, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!177 = !{!178, !179, !166, !168, !170, !172, !159}
!178 = distinct !{!178, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!179 = distinct !{!179, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!180 = !{!181, !182, !166, !168, !170, !172, !159}
!181 = distinct !{!181, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!182 = distinct !{!182, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!183 = !{!184, !185, !166, !168, !170, !172, !159}
!184 = distinct !{!184, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!185 = distinct !{!185, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!186 = !{!187, !188, !166, !168, !170, !172, !159}
!187 = distinct !{!187, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!188 = distinct !{!188, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!189 = !{!190, !191, !166, !168, !170, !172, !159}
!190 = distinct !{!190, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!191 = distinct !{!191, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!192 = !{!193, !194, !166, !168, !170, !172, !159}
!193 = distinct !{!193, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!194 = distinct !{!194, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!195 = !{!196, !197, !166, !168, !170, !172, !159}
!196 = distinct !{!196, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!197 = distinct !{!197, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!198 = !{!199, !200, !166, !168, !170, !172, !159}
!199 = distinct !{!199, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!200 = distinct !{!200, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!201 = !{!202, !203, !166, !168, !170, !172, !159}
!202 = distinct !{!202, !163, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!203 = distinct !{!203, !165, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!204 = !{!205, !207}
!205 = distinct !{!205, !206, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!206 = distinct !{!206, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!207 = distinct !{!207, !208, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated: %_0"}
!208 = distinct !{!208, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated"}
!209 = !{!207}
!210 = !{!211}
!211 = distinct !{!211, !212, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!212 = distinct !{!212, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!213 = !{!214}
!214 = distinct !{!214, !215, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!215 = distinct !{!215, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!216 = !{!217, !219}
!217 = distinct !{!217, !218, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_10EE9from_iterB15_: %_0"}
!218 = distinct !{!218, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_10EE9from_iterB15_"}
!219 = distinct !{!219, !218, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_10EE9from_iterB15_: %iterator"}
!220 = !{!221, !217, !219}
!221 = distinct !{!221, !222, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!222 = distinct !{!222, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!223 = !{!224}
!224 = distinct !{!224, !225, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_10EE11spec_extendBV_: %self"}
!225 = distinct !{!225, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_10EE11spec_extendBV_"}
!226 = !{!227}
!227 = distinct !{!227, !228, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_10EEBI_: %self"}
!228 = distinct !{!228, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_10EEBI_"}
!229 = !{!230, !232, !234, !235, !237, !227, !238, !224, !239, !217, !219}
!230 = distinct !{!230, !231, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_10NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_: %f"}
!231 = distinct !{!231, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_10NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_"}
!232 = distinct !{!232, !233, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_10ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %self"}
!233 = distinct !{!233, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_10ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_"}
!234 = distinct !{!234, !233, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_10ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %g"}
!235 = distinct !{!235, !236, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_10ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %self"}
!236 = distinct !{!236, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_10ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_"}
!237 = distinct !{!237, !236, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_10ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %f"}
!238 = distinct !{!238, !228, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_10EEBI_: %iterator"}
!239 = distinct !{!239, !225, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_10EE11spec_extendBV_: %iterator"}
!240 = !{!241, !243, !230, !232, !234, !235, !237, !227, !238, !224, !239, !217, !219}
!241 = distinct !{!241, !242, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_10B3_: %_0"}
!242 = distinct !{!242, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_10B3_"}
!243 = distinct !{!243, !244, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_10NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_: %_1"}
!244 = distinct !{!244, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_10NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_"}
!245 = !{!246, !248, !243, !230, !232, !234, !235, !237, !227, !238, !224, !239, !217, !219}
!246 = distinct !{!246, !247, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_10EE0BK_: %_1"}
!247 = distinct !{!247, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_10EE0BK_"}
!248 = distinct !{!248, !249, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_10EE0E0B1h_: %_1"}
!249 = distinct !{!249, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_10EE0E0B1h_"}
!250 = !{!227, !224}
!251 = !{!230, !232, !234, !235, !237, !238, !239, !217, !219}
!252 = !{!219}
!253 = !{!254}
!254 = distinct !{!254, !255, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0E3newBI_: %x"}
!255 = distinct !{!255, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_1s_0E3newBI_"}
!256 = !{!257, !259}
!257 = distinct !{!257, !258, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!258 = distinct !{!258, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!259 = distinct !{!259, !260, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated: %_0"}
!260 = distinct !{!260, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated"}
!261 = !{!262, !264, !266, !268, !270, !272, !259}
!262 = distinct !{!262, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1"}
!263 = distinct !{!263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated"}
!264 = distinct !{!264, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1"}
!265 = distinct !{!265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated"}
!266 = distinct !{!266, !267, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated: %f"}
!267 = distinct !{!267, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated"}
!268 = distinct !{!268, !269, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated: %f"}
!269 = distinct !{!269, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated"}
!270 = distinct !{!270, !271, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated: %self"}
!271 = distinct !{!271, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated"}
!272 = distinct !{!272, !273, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated: %self"}
!273 = distinct !{!273, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated"}
!274 = !{!275, !276, !266, !268, !270, !272, !259}
!275 = distinct !{!275, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!276 = distinct !{!276, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!277 = !{!278, !279, !266, !268, !270, !272, !259}
!278 = distinct !{!278, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!279 = distinct !{!279, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!280 = !{!281, !282, !266, !268, !270, !272, !259}
!281 = distinct !{!281, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!282 = distinct !{!282, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!283 = !{!284, !285, !266, !268, !270, !272, !259}
!284 = distinct !{!284, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!285 = distinct !{!285, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!286 = !{!287, !288, !266, !268, !270, !272, !259}
!287 = distinct !{!287, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!288 = distinct !{!288, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!289 = !{!290, !291, !266, !268, !270, !272, !259}
!290 = distinct !{!290, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!291 = distinct !{!291, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!292 = !{!293, !294, !266, !268, !270, !272, !259}
!293 = distinct !{!293, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!294 = distinct !{!294, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!295 = !{!296, !297, !266, !268, !270, !272, !259}
!296 = distinct !{!296, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!297 = distinct !{!297, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!298 = !{!299, !300, !266, !268, !270, !272, !259}
!299 = distinct !{!299, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!300 = distinct !{!300, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!301 = !{!302, !303, !266, !268, !270, !272, !259}
!302 = distinct !{!302, !263, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!303 = distinct !{!303, !265, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!304 = !{!305, !307}
!305 = distinct !{!305, !306, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!306 = distinct !{!306, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!307 = distinct !{!307, !308, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated: %_0"}
!308 = distinct !{!308, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated"}
!309 = !{!307}
!310 = !{!311}
!311 = distinct !{!311, !312, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!312 = distinct !{!312, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!313 = !{!314}
!314 = distinct !{!314, !315, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!315 = distinct !{!315, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!316 = !{!317, !319}
!317 = distinct !{!317, !318, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_20EE9from_iterB15_: %_0"}
!318 = distinct !{!318, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_20EE9from_iterB15_"}
!319 = distinct !{!319, !318, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_20EE9from_iterB15_: %iterator"}
!320 = !{!321, !317, !319}
!321 = distinct !{!321, !322, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!322 = distinct !{!322, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!323 = !{!324}
!324 = distinct !{!324, !325, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_20EE11spec_extendBV_: %self"}
!325 = distinct !{!325, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_20EE11spec_extendBV_"}
!326 = !{!327}
!327 = distinct !{!327, !328, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_20EEBI_: %self"}
!328 = distinct !{!328, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_20EEBI_"}
!329 = !{!330, !332, !334, !335, !337, !327, !338, !324, !339, !317, !319}
!330 = distinct !{!330, !331, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_20NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_: %f"}
!331 = distinct !{!331, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_20NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_"}
!332 = distinct !{!332, !333, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_20ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %self"}
!333 = distinct !{!333, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_20ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_"}
!334 = distinct !{!334, !333, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_20ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %g"}
!335 = distinct !{!335, !336, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_20ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %self"}
!336 = distinct !{!336, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_20ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_"}
!337 = distinct !{!337, !336, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_20ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %f"}
!338 = distinct !{!338, !328, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_20EEBI_: %iterator"}
!339 = distinct !{!339, !325, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_20EE11spec_extendBV_: %iterator"}
!340 = !{!341, !343, !330, !332, !334, !335, !337, !327, !338, !324, !339, !317, !319}
!341 = distinct !{!341, !342, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_20B3_: %_0"}
!342 = distinct !{!342, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_20B3_"}
!343 = distinct !{!343, !344, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_20NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_: %_1"}
!344 = distinct !{!344, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_20NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_"}
!345 = !{!346, !348, !343, !330, !332, !334, !335, !337, !327, !338, !324, !339, !317, !319}
!346 = distinct !{!346, !347, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_20EE0BK_: %_1"}
!347 = distinct !{!347, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_20EE0BK_"}
!348 = distinct !{!348, !349, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_20EE0E0B1h_: %_1"}
!349 = distinct !{!349, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_20EE0E0B1h_"}
!350 = !{!327, !324}
!351 = !{!330, !332, !334, !335, !337, !338, !339, !317, !319}
!352 = !{!319}
!353 = !{!354}
!354 = distinct !{!354, !355, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0E3newBI_: %x"}
!355 = distinct !{!355, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_2s_0E3newBI_"}
!356 = !{!357, !359}
!357 = distinct !{!357, !358, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!358 = distinct !{!358, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!359 = distinct !{!359, !360, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated: %_0"}
!360 = distinct !{!360, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated"}
!361 = !{!362, !364, !366, !368, !370, !372, !359}
!362 = distinct !{!362, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1"}
!363 = distinct !{!363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated"}
!364 = distinct !{!364, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1"}
!365 = distinct !{!365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated"}
!366 = distinct !{!366, !367, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated: %f"}
!367 = distinct !{!367, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated"}
!368 = distinct !{!368, !369, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated: %f"}
!369 = distinct !{!369, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated"}
!370 = distinct !{!370, !371, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated: %self"}
!371 = distinct !{!371, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated"}
!372 = distinct !{!372, !373, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated: %self"}
!373 = distinct !{!373, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated"}
!374 = !{!375, !376, !366, !368, !370, !372, !359}
!375 = distinct !{!375, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!376 = distinct !{!376, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!377 = !{!378, !379, !366, !368, !370, !372, !359}
!378 = distinct !{!378, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!379 = distinct !{!379, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!380 = !{!381, !382, !366, !368, !370, !372, !359}
!381 = distinct !{!381, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!382 = distinct !{!382, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!383 = !{!384, !385, !366, !368, !370, !372, !359}
!384 = distinct !{!384, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!385 = distinct !{!385, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!386 = !{!387, !388, !366, !368, !370, !372, !359}
!387 = distinct !{!387, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!388 = distinct !{!388, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!389 = !{!390, !391, !366, !368, !370, !372, !359}
!390 = distinct !{!390, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!391 = distinct !{!391, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!392 = !{!393, !394, !366, !368, !370, !372, !359}
!393 = distinct !{!393, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!394 = distinct !{!394, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!395 = !{!396, !397, !366, !368, !370, !372, !359}
!396 = distinct !{!396, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!397 = distinct !{!397, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!398 = !{!399, !400, !366, !368, !370, !372, !359}
!399 = distinct !{!399, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!400 = distinct !{!400, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!401 = !{!402, !403, !366, !368, !370, !372, !359}
!402 = distinct !{!402, !363, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!403 = distinct !{!403, !365, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!404 = !{!405, !407}
!405 = distinct !{!405, !406, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!406 = distinct !{!406, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!407 = distinct !{!407, !408, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated: %_0"}
!408 = distinct !{!408, !"_RINvXs_NtNtCs40k4W9msRzi_5alloc3vec14spec_from_elemjNtB5_12SpecFromElem9from_elemNtNtB9_5alloc6GlobalECsl0YfJI2rrfI_8isolated"}
!409 = !{!407}
!410 = !{!411}
!411 = distinct !{!411, !412, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!412 = distinct !{!412, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!413 = !{!414}
!414 = distinct !{!414, !415, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!415 = distinct !{!415, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!416 = !{!417, !419}
!417 = distinct !{!417, !418, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_30EE9from_iterB15_: %_0"}
!418 = distinct !{!418, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_30EE9from_iterB15_"}
!419 = distinct !{!419, !418, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2a_5slice4iter4IterTjxEENCNvB15_9factory_30EE9from_iterB15_: %iterator"}
!420 = !{!421, !417, !419}
!421 = distinct !{!421, !422, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!422 = distinct !{!422, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!423 = !{!424}
!424 = distinct !{!424, !425, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_30EE11spec_extendBV_: %self"}
!425 = distinct !{!425, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_30EE11spec_extendBV_"}
!426 = !{!427}
!427 = distinct !{!427, !428, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_30EEBI_: %self"}
!428 = distinct !{!428, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_30EEBI_"}
!429 = !{!430, !432, !434, !435, !437, !427, !438, !424, !439, !417, !419}
!430 = distinct !{!430, !431, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_30NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_: %f"}
!431 = distinct !{!431, !"_RINvXs2J_NtNtCscI6d9CVNmLh_4core5slice4iterINtB7_4IterTjxEENtNtNtNtBb_4iter6traits8iterator8Iterator4folduNCINvNtNtB11_8adapters3map8map_foldRBQ_NtCsl0YfJI2rrfI_8isolated3LkTuNCNvB2l_9factory_30NCINvNvBV_8for_each4callB2j_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3H_3VecB2j_E14extend_trustedINtB1L_3MapBF_B2N_EE0E0E0EB2l_"}
!432 = distinct !{!432, !433, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_30ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %self"}
!433 = distinct !{!433, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_30ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_"}
!434 = distinct !{!434, !433, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_30ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB25_8for_each4callNtB1w_3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3r_3VecB38_E14extend_trustedBN_E0E0EB1w_: %g"}
!435 = distinct !{!435, !436, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_30ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %self"}
!436 = distinct !{!436, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_30ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_"}
!437 = distinct !{!437, !436, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter4IterTjxEENCNvCsl0YfJI2rrfI_8isolated9factory_30ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2P_3VecNtB1q_3LkTE14extend_trustedB3_E0EB1q_: %f"}
!438 = distinct !{!438, !428, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1z_5slice4iter4IterTjxEENCNvBI_9factory_30EEBI_: %iterator"}
!439 = distinct !{!439, !425, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtCsl0YfJI2rrfI_8isolated3LkTEINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1R_5slice4iter4IterTjxEENCNvBV_9factory_30EE11spec_extendBV_: %iterator"}
!440 = !{!441, !443, !430, !432, !434, !435, !437, !427, !438, !424, !439, !417, !419}
!441 = distinct !{!441, !442, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_30B3_: %_0"}
!442 = distinct !{!442, !"_RNCNvCsl0YfJI2rrfI_8isolated9factory_30B3_"}
!443 = distinct !{!443, !444, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_30NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_: %_1"}
!444 = distinct !{!444, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRTjxENtCsl0YfJI2rrfI_8isolated3LkTuNCNvB11_9factory_30NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBZ_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBZ_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter4IterBV_EB1t_EE0E0E0B11_"}
!445 = !{!446, !448, !443, !430, !432, !434, !435, !437, !427, !438, !424, !439, !417, !419}
!446 = distinct !{!446, !447, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_30EE0BK_: %_1"}
!447 = distinct !{!447, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtCsl0YfJI2rrfI_8isolated3LkTE14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1B_5slice4iter4IterTjxEENCNvBK_9factory_30EE0BK_"}
!448 = distinct !{!448, !449, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_30EE0E0B1h_: %_1"}
!449 = distinct !{!449, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtCsl0YfJI2rrfI_8isolated3LkTNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1R_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter4IterTjxEENCNvB1h_9factory_30EE0E0B1h_"}
!450 = !{!427, !424}
!451 = !{!430, !432, !434, !435, !437, !438, !439, !417, !419}
!452 = !{!419}
!453 = !{!454}
!454 = distinct !{!454, !455, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0E3newBI_: %x"}
!455 = distinct !{!455, !"_RNvMNtCs40k4W9msRzi_5alloc5boxedINtB2_3BoxNCNvCsl0YfJI2rrfI_8isolated9factory_3s_0E3newBI_"}
!456 = !{!457, !459}
!457 = distinct !{!457, !458, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!458 = distinct !{!458, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!459 = distinct !{!459, !460, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated: %_0"}
!460 = distinct !{!460, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecjEINtB4_18SpecFromIterNestedjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE9from_iterCsl0YfJI2rrfI_8isolated"}
!461 = !{!462, !464, !466, !468, !470, !472, !459}
!462 = distinct !{!462, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1"}
!463 = distinct !{!463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated"}
!464 = distinct !{!464, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1"}
!465 = distinct !{!465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated"}
!466 = distinct !{!466, !467, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated: %f"}
!467 = distinct !{!467, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNvBL_8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB24_3VecjE14extend_trustedB3_E0E0ECsl0YfJI2rrfI_8isolated"}
!468 = distinct !{!468, !469, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated: %f"}
!469 = distinct !{!469, !"_RINvYINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejENtNtNtNtBa_4iter6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1I_3VecjE14extend_trustedB3_E0ECsl0YfJI2rrfI_8isolated"}
!470 = distinct !{!470, !471, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated: %self"}
!471 = distinct !{!471, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEECsl0YfJI2rrfI_8isolated"}
!472 = distinct !{!472, !473, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated: %self"}
!473 = distinct !{!473, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecjEINtB4_10SpecExtendjINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE11spec_extendCsl0YfJI2rrfI_8isolated"}
!474 = !{!475, !476, !466, !468, !470, !472, !459}
!475 = distinct !{!475, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!476 = distinct !{!476, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It1"}
!477 = !{!478, !479, !466, !468, !470, !472, !459}
!478 = distinct !{!478, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!479 = distinct !{!479, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It2"}
!480 = !{!481, !482, !466, !468, !470, !472, !459}
!481 = distinct !{!481, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!482 = distinct !{!482, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It3"}
!483 = !{!484, !485, !466, !468, !470, !472, !459}
!484 = distinct !{!484, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!485 = distinct !{!485, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It4"}
!486 = !{!487, !488, !466, !468, !470, !472, !459}
!487 = distinct !{!487, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!488 = distinct !{!488, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It5"}
!489 = !{!490, !491, !466, !468, !470, !472, !459}
!490 = distinct !{!490, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!491 = distinct !{!491, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It6"}
!492 = !{!493, !494, !466, !468, !470, !472, !459}
!493 = distinct !{!493, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!494 = distinct !{!494, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It7"}
!495 = !{!496, !497, !466, !468, !470, !472, !459}
!496 = distinct !{!496, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!497 = distinct !{!497, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It8"}
!498 = !{!499, !500, !466, !468, !470, !472, !459}
!499 = distinct !{!499, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!500 = distinct !{!500, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It9"}
!501 = !{!502, !503, !466, !468, !470, !472, !459}
!502 = distinct !{!502, !463, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecjE14extend_trustedINtNtNtCscI6d9CVNmLh_4core3ops5range5RangejEE0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!503 = distinct !{!503, !465, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4calljNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1p_3VecjE14extend_trustedINtNtNtBe_3ops5range5RangejEE0E0Csl0YfJI2rrfI_8isolated: %_1:It10"}
!504 = distinct !{!504, !505}
!505 = !{!"llvm.loop.unroll.disable"}
!506 = !{!"branch_weights", i32 2002, i32 2000}
!507 = !{!508}
!508 = distinct !{!508, !509, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!509 = distinct !{!509, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!510 = !{!511}
!511 = distinct !{!511, !512, !"_RNvMsF_NtCs40k4W9msRzi_5alloc3vecINtB5_3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8push_mutBL_: %self"}
!512 = distinct !{!512, !"_RNvMsF_NtCs40k4W9msRzi_5alloc3vecINtB5_3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8push_mutBL_"}
!513 = !{!514}
!514 = distinct !{!514, !512, !"_RNvMsF_NtCs40k4W9msRzi_5alloc3vecINtB5_3VecTjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EE8push_mutBL_: %value"}
!515 = !{!516}
!516 = distinct !{!516, !517, !"_RNvMsF_NtCs40k4W9msRzi_5alloc3vecINtB5_3VecTjIBw_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8push_mutBR_: %self"}
!517 = distinct !{!517, !"_RNvMsF_NtCs40k4W9msRzi_5alloc3vecINtB5_3VecTjIBw_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8push_mutBR_"}
!518 = !{!519}
!519 = distinct !{!519, !517, !"_RNvMsF_NtCs40k4W9msRzi_5alloc3vecINtB5_3VecTjIBw_TjNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EEEE8push_mutBR_: %value"}
!520 = !{!521}
!521 = distinct !{!521, !522, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner14grow_amortizedCsl0YfJI2rrfI_8isolated: %self"}
!522 = distinct !{!522, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner14grow_amortizedCsl0YfJI2rrfI_8isolated"}
!523 = !{i64 0, i64 -9223372036854775807}
!524 = !{!525}
!525 = distinct !{!525, !526, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner14grow_amortizedCsl0YfJI2rrfI_8isolated: %self"}
!526 = distinct !{!526, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner14grow_amortizedCsl0YfJI2rrfI_8isolated"}
!527 = !{!528, !530, !532}
!528 = distinct !{!528, !529, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated: %_0"}
!529 = distinct !{!529, !"_RNvMs4_NtCs40k4W9msRzi_5alloc7raw_vecNtB5_11RawVecInner15try_allocate_inCsl0YfJI2rrfI_8isolated"}
!530 = distinct !{!530, !531, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2i_5slice4iter11ChunksExactyENCNvB17_3fzc0EE9from_iterB17_: %_0"}
!531 = distinct !{!531, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2i_5slice4iter11ChunksExactyENCNvB17_3fzc0EE9from_iterB17_"}
!532 = distinct !{!532, !531, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec21spec_from_iter_nestedINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtB4_18SpecFromIterNestedB13_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB2i_5slice4iter11ChunksExactyENCNvB17_3fzc0EE9from_iterB17_: %iterator"}
!533 = !{!534}
!534 = distinct !{!534, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0"}
!535 = distinct !{!535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_"}
!536 = !{!537, !534}
!537 = distinct !{!537, !538, !"_RNCNvCsl0YfJI2rrfI_8isolated3fzc0B3_: %x.0"}
!538 = distinct !{!538, !"_RNCNvCsl0YfJI2rrfI_8isolated3fzc0B3_"}
!539 = !{!540, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!540 = distinct !{!540, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %_1"}
!541 = distinct !{!541, !542, !"_RINvYINtNtNtCscI6d9CVNmLh_4core5slice4iter11ChunksExactyENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNtNtBZ_8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB2j_3fzc0NCINvNvBT_8for_each4callB2f_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3F_3VecB2f_E14extend_trustedINtB1J_3MapB3_B2R_EE0E0E0EB2j_: %self"}
!542 = distinct !{!542, !"_RINvYINtNtNtCscI6d9CVNmLh_4core5slice4iter11ChunksExactyENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNtNtBZ_8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB2j_3fzc0NCINvNvBT_8for_each4callB2f_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3F_3VecB2f_E14extend_trustedINtB1J_3MapB3_B2R_EE0E0E0EB2j_"}
!543 = distinct !{!543, !542, !"_RINvYINtNtNtCscI6d9CVNmLh_4core5slice4iter11ChunksExactyENtNtNtNtBa_4iter6traits8iterator8Iterator4folduNCINvNtNtBZ_8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB2j_3fzc0NCINvNvBT_8for_each4callB2f_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3F_3VecB2f_E14extend_trustedINtB1J_3MapB3_B2R_EE0E0E0EB2j_: %f"}
!544 = distinct !{!544, !545, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter11ChunksExactyENCNvCsl0YfJI2rrfI_8isolated3fzc0ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB24_8for_each4callNtNtB1B_5field3Fp2NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3y_3VecB37_E14extend_trustedBN_E0E0EB1B_: %self"}
!545 = distinct !{!545, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter11ChunksExactyENCNvCsl0YfJI2rrfI_8isolated3fzc0ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB24_8for_each4callNtNtB1B_5field3Fp2NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3y_3VecB37_E14extend_trustedBN_E0E0EB1B_"}
!546 = distinct !{!546, !545, !"_RINvXs0_NtNtNtCscI6d9CVNmLh_4core4iter8adapters3mapINtB6_3MapINtNtNtBc_5slice4iter11ChunksExactyENCNvCsl0YfJI2rrfI_8isolated3fzc0ENtNtNtBa_6traits8iterator8Iterator4folduNCINvNvB24_8for_each4callNtNtB1B_5field3Fp2NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB3y_3VecB37_E14extend_trustedBN_E0E0EB1B_: %g"}
!547 = distinct !{!547, !548, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter11ChunksExactyENCNvCsl0YfJI2rrfI_8isolated3fzc0ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2O_3VecNtNtB1v_5field3Fp2E14extend_trustedB3_E0EB1v_: %self"}
!548 = distinct !{!548, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter11ChunksExactyENCNvCsl0YfJI2rrfI_8isolated3fzc0ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2O_3VecNtNtB1v_5field3Fp2E14extend_trustedB3_E0EB1v_"}
!549 = distinct !{!549, !548, !"_RINvYINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtBc_5slice4iter11ChunksExactyENCNvCsl0YfJI2rrfI_8isolated3fzc0ENtNtNtBa_6traits8iterator8Iterator8for_eachNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2O_3VecNtNtB1v_5field3Fp2E14extend_trustedB3_E0EB1v_: %f"}
!550 = distinct !{!550, !551, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2E14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1H_5slice4iter11ChunksExactyENCNvBK_3fzc0EEBK_: %self"}
!551 = distinct !{!551, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2E14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1H_5slice4iter11ChunksExactyENCNvBK_3fzc0EEBK_"}
!552 = distinct !{!552, !551, !"_RINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2E14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1H_5slice4iter11ChunksExactyENCNvBK_3fzc0EEBK_: %iterator"}
!553 = distinct !{!553, !554, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1Z_5slice4iter11ChunksExactyENCNvBX_3fzc0EE11spec_extendBX_: %self"}
!554 = distinct !{!554, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1Z_5slice4iter11ChunksExactyENCNvBX_3fzc0EE11spec_extendBX_"}
!555 = distinct !{!555, !554, !"_RNvXs_NtNtCs40k4W9msRzi_5alloc3vec11spec_extendINtB6_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2EINtB4_10SpecExtendBT_INtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1Z_5slice4iter11ChunksExactyENCNvBX_3fzc0EE11spec_extendBX_: %iterator"}
!556 = !{!557, !559, !540, !534, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!557 = distinct !{!557, !558, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2E14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1J_5slice4iter11ChunksExactyENCNvBM_3fzc0EE0BM_: %_1"}
!558 = distinct !{!558, !"_RNCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB8_3VecNtNtCsl0YfJI2rrfI_8isolated5field3Fp2E14extend_trustedINtNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map3MapINtNtNtB1J_5slice4iter11ChunksExactyENCNvBM_3fzc0EE0BM_"}
!559 = distinct !{!559, !560, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtNtCsl0YfJI2rrfI_8isolated5field3Fp2NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1Z_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter11ChunksExactyENCNvB1j_3fzc0EE0E0B1j_: %_1"}
!560 = distinct !{!560, !"_RNCINvNvNtNtNtNtCscI6d9CVNmLh_4core4iter6traits8iterator8Iterator8for_each4callNtNtCsl0YfJI2rrfI_8isolated5field3Fp2NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB1Z_3VecB1f_E14extend_trustedINtNtNtBc_8adapters3map3MapINtNtNtBe_5slice4iter11ChunksExactyENCNvB1j_3fzc0EE0E0B1j_"}
!561 = !{!562}
!562 = distinct !{!562, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It1"}
!563 = !{!537, !562}
!564 = !{!557, !559, !540, !562, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!565 = !{!566}
!566 = distinct !{!566, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It2"}
!567 = !{!537, !566}
!568 = !{!557, !559, !540, !566, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!569 = !{!570}
!570 = distinct !{!570, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It3"}
!571 = !{!537, !570}
!572 = !{!557, !559, !540, !570, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!573 = !{!574}
!574 = distinct !{!574, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It4"}
!575 = !{!537, !574}
!576 = !{!557, !559, !540, !574, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!577 = !{!578}
!578 = distinct !{!578, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It5"}
!579 = !{!537, !578}
!580 = !{!557, !559, !540, !578, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!581 = !{!582}
!582 = distinct !{!582, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It6"}
!583 = !{!537, !582}
!584 = !{!557, !559, !540, !582, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!585 = !{!586}
!586 = distinct !{!586, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It7"}
!587 = !{!537, !586}
!588 = !{!557, !559, !540, !586, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!589 = !{!590}
!590 = distinct !{!590, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It8"}
!591 = !{!537, !590}
!592 = !{!557, !559, !540, !590, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!593 = !{!594}
!594 = distinct !{!594, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It9"}
!595 = !{!537, !594}
!596 = !{!557, !559, !540, !594, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!597 = !{!598}
!598 = distinct !{!598, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It10"}
!599 = !{!537, !598}
!600 = !{!557, !559, !540, !598, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!601 = !{!602}
!602 = distinct !{!602, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It11"}
!603 = !{!537, !602}
!604 = !{!557, !559, !540, !602, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!605 = !{!606}
!606 = distinct !{!606, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It12"}
!607 = !{!537, !606}
!608 = !{!557, !559, !540, !606, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!609 = !{!610}
!610 = distinct !{!610, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It13"}
!611 = !{!537, !610}
!612 = !{!557, !559, !540, !610, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!613 = !{!614}
!614 = distinct !{!614, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It14"}
!615 = !{!537, !614}
!616 = !{!557, !559, !540, !614, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!617 = !{!618}
!618 = distinct !{!618, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It15"}
!619 = !{!537, !618}
!620 = !{!557, !559, !540, !618, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!621 = !{!622}
!622 = distinct !{!622, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It16"}
!623 = !{!537, !622}
!624 = !{!557, !559, !540, !622, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!625 = !{!626}
!626 = distinct !{!626, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It17"}
!627 = !{!537, !626}
!628 = !{!557, !559, !540, !626, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!629 = !{!630}
!630 = distinct !{!630, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It18"}
!631 = !{!537, !630}
!632 = !{!557, !559, !540, !630, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!633 = !{!634}
!634 = distinct !{!634, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It19"}
!635 = !{!537, !634}
!636 = !{!557, !559, !540, !634, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!637 = !{!638}
!638 = distinct !{!638, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It20"}
!639 = !{!537, !638}
!640 = !{!557, !559, !540, !638, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!641 = !{!642}
!642 = distinct !{!642, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It21"}
!643 = !{!537, !642}
!644 = !{!557, !559, !540, !642, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!645 = !{!646}
!646 = distinct !{!646, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It22"}
!647 = !{!537, !646}
!648 = !{!557, !559, !540, !646, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!649 = !{!650}
!650 = distinct !{!650, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It23"}
!651 = !{!537, !650}
!652 = !{!557, !559, !540, !650, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!653 = !{!654}
!654 = distinct !{!654, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It24"}
!655 = !{!537, !654}
!656 = !{!557, !559, !540, !654, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!657 = !{!658}
!658 = distinct !{!658, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It25"}
!659 = !{!537, !658}
!660 = !{!557, !559, !540, !658, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!661 = !{!662}
!662 = distinct !{!662, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It26"}
!663 = !{!537, !662}
!664 = !{!557, !559, !540, !662, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!665 = !{!666}
!666 = distinct !{!666, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It27"}
!667 = !{!537, !666}
!668 = !{!557, !559, !540, !666, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!669 = !{!670}
!670 = distinct !{!670, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It28"}
!671 = !{!537, !670}
!672 = !{!557, !559, !540, !670, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!673 = !{!674}
!674 = distinct !{!674, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It29"}
!675 = !{!537, !674}
!676 = !{!557, !559, !540, !674, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!677 = !{!678}
!678 = distinct !{!678, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It30"}
!679 = !{!537, !678}
!680 = !{!557, !559, !540, !678, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!681 = !{!682}
!682 = distinct !{!682, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It31"}
!683 = !{!537, !682}
!684 = !{!557, !559, !540, !682, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!685 = !{!686}
!686 = distinct !{!686, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It32"}
!687 = !{!537, !686}
!688 = !{!557, !559, !540, !686, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!689 = !{!690}
!690 = distinct !{!690, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It33"}
!691 = !{!537, !690}
!692 = !{!557, !559, !540, !690, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!693 = !{!694}
!694 = distinct !{!694, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It34"}
!695 = !{!537, !694}
!696 = !{!557, !559, !540, !694, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!697 = !{!698}
!698 = distinct !{!698, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It35"}
!699 = !{!537, !698}
!700 = !{!557, !559, !540, !698, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!701 = !{!702}
!702 = distinct !{!702, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It36"}
!703 = !{!537, !702}
!704 = !{!557, !559, !540, !702, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
!705 = !{!706}
!706 = distinct !{!706, !535, !"_RNCINvNtNtNtCscI6d9CVNmLh_4core4iter8adapters3map8map_foldRSyNtNtCsl0YfJI2rrfI_8isolated5field3Fp2uNCNvB11_3fzc0NCINvNvNtNtNtB8_6traits8iterator8Iterator8for_each4callBX_NCINvMsj_NtCs40k4W9msRzi_5alloc3vecINtB2R_3VecBX_E14extend_trustedINtB4_3MapINtNtNtBa_5slice4iter11ChunksExactyEB1z_EE0E0E0B11_: %elt.0:It37"}
!707 = !{!537, !706}
!708 = !{!557, !559, !540, !706, !541, !543, !544, !546, !547, !549, !550, !552, !553, !555, !530, !532}
