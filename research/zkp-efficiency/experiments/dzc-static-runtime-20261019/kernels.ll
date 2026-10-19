; ModuleID = 'kernels.10eb82e2b480652b-cgu.0'
source_filename = "kernels.10eb82e2b480652b-cgu.0"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; <kernels::Fp2>::add
; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind nonlazybind willreturn memory(none) uwtable
define internal fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %self.0, i64 noundef %self.1, i64 noundef %o.0, i64 noundef %o.1) unnamed_addr #0 {
start:
  %_0.0.i.i = add i64 %o.0, %self.0
  %_0.1.i.i = icmp ult i64 %_0.0.i.i, %self.0
  %_0.i.i = add i64 %_0.0.i.i, 4294967295
  %spec.select = select i1 %_0.1.i.i, i64 %_0.i.i, i64 %_0.0.i.i
  %_2.i.i = icmp ugt i64 %spec.select, -4294967296
  %_3.i.i = add nsw i64 %spec.select, 4294967295
  %_0.sroa.0.0.i.i = select i1 %_2.i.i, i64 %_3.i.i, i64 %spec.select
  %_0.0.i11.i = add i64 %o.1, %self.1
  %_0.1.i12.i = icmp ult i64 %_0.0.i11.i, %self.1
  %_0.i10.i = add i64 %_0.0.i11.i, 4294967295
  %r.sroa.0.0.i.i = select i1 %_0.1.i12.i, i64 %_0.i10.i, i64 %_0.0.i11.i
  %_2.i7.i = icmp ugt i64 %r.sroa.0.0.i.i, -4294967296
  %_3.i8.i = add nsw i64 %r.sroa.0.0.i.i, 4294967295
  %_0.sroa.0.0.i9.i = select i1 %_2.i7.i, i64 %_3.i8.i, i64 %r.sroa.0.0.i.i
  %0 = insertvalue { i64, i64 } poison, i64 %_0.sroa.0.0.i.i, 0
  %1 = insertvalue { i64, i64 } %0, i64 %_0.sroa.0.0.i9.i, 1
  ret { i64, i64 } %1
}

; <kernels::Fp2>::mul
; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind nonlazybind willreturn memory(none) uwtable
define internal fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %self.0, i64 noundef %self.1, i64 noundef %o.0, i64 noundef %o.1) unnamed_addr #0 {
start:
  %_4.i19.i = zext i64 %self.0 to i128
  %_6.i20.i = zext i64 %o.0 to i128
  %_3.i21.i = mul nuw i128 %_6.i20.i, %_4.i19.i
  %x_lo.i70 = trunc i128 %_3.i21.i to i64
  %_4.i71 = lshr i128 %_3.i21.i, 64
  %x_hi.i72 = trunc nuw i128 %_4.i71 to i64
  %x_hi_hi.i73 = lshr i64 %x_hi.i72, 32
  %x_hi_lo.i74 = and i64 %x_hi.i72, 4294967295
  %_0.0.i3.i75 = sub i64 %x_lo.i70, %x_hi_hi.i73
  %_0.1.i4.i76 = icmp ugt i64 %x_hi_hi.i73, %x_lo.i70
  %_0.i2.i89 = add i64 %_0.0.i3.i75, -4294967295
  %spec.select = select i1 %_0.1.i4.i76, i64 %_0.i2.i89, i64 %_0.0.i3.i75
  %t1.i79 = mul nuw i64 %x_hi_lo.i74, 4294967295
  %_0.0.i.i80 = add i64 %spec.select, %t1.i79
  %_0.1.i.i81 = icmp ult i64 %_0.0.i.i80, %spec.select
  %_0.i.i87 = add i64 %_0.0.i.i80, 4294967295
  %res.sroa.0.0.i82 = select i1 %_0.1.i.i81, i64 %_0.i.i87, i64 %_0.0.i.i80
  %_2.i.i83 = icmp ugt i64 %res.sroa.0.0.i82, -4294967296
  %_3.i.i84 = add nsw i64 %res.sroa.0.0.i82, 4294967295
  %_0.sroa.0.0.i.i85 = select i1 %_2.i.i83, i64 %_3.i.i84, i64 %res.sroa.0.0.i82
  %_4.i15.i = zext i64 %self.1 to i128
  %_6.i16.i = zext i64 %o.1 to i128
  %_3.i17.i = mul nuw i128 %_6.i16.i, %_4.i15.i
  %x_lo.i49 = trunc i128 %_3.i17.i to i64
  %_4.i50 = lshr i128 %_3.i17.i, 64
  %x_hi.i51 = trunc nuw i128 %_4.i50 to i64
  %x_hi_hi.i52 = lshr i64 %x_hi.i51, 32
  %x_hi_lo.i53 = and i64 %x_hi.i51, 4294967295
  %_0.0.i3.i54 = sub i64 %x_lo.i49, %x_hi_hi.i52
  %_0.1.i4.i55 = icmp ugt i64 %x_hi_hi.i52, %x_lo.i49
  %_0.i2.i68 = add i64 %_0.0.i3.i54, -4294967295
  %t0.sroa.0.0.i57 = select i1 %_0.1.i4.i55, i64 %_0.i2.i68, i64 %_0.0.i3.i54
  %t1.i58 = mul nuw i64 %x_hi_lo.i53, 4294967295
  %_0.0.i.i59 = add i64 %t0.sroa.0.0.i57, %t1.i58
  %_0.1.i.i60 = icmp ult i64 %_0.0.i.i59, %t0.sroa.0.0.i57
  %_0.i.i66 = add i64 %_0.0.i.i59, 4294967295
  %res.sroa.0.0.i61 = select i1 %_0.1.i.i60, i64 %_0.i.i66, i64 %_0.0.i.i59
  %_2.i.i62 = icmp ugt i64 %res.sroa.0.0.i61, -4294967296
  %_3.i.i63 = add nsw i64 %res.sroa.0.0.i61, 4294967295
  %_0.sroa.0.0.i.i64 = select i1 %_2.i.i62, i64 %_3.i.i63, i64 %res.sroa.0.0.i61
  %_3.i13.i = mul nuw i128 %_6.i16.i, %_4.i19.i
  %x_lo.i28 = trunc i128 %_3.i13.i to i64
  %_4.i29 = lshr i128 %_3.i13.i, 64
  %x_hi.i30 = trunc nuw i128 %_4.i29 to i64
  %x_hi_hi.i31 = lshr i64 %x_hi.i30, 32
  %x_hi_lo.i32 = and i64 %x_hi.i30, 4294967295
  %_0.0.i3.i33 = sub i64 %x_lo.i28, %x_hi_hi.i31
  %_0.1.i4.i34 = icmp ugt i64 %x_hi_hi.i31, %x_lo.i28
  %_0.i2.i47 = add i64 %_0.0.i3.i33, -4294967295
  %t0.sroa.0.0.i36 = select i1 %_0.1.i4.i34, i64 %_0.i2.i47, i64 %_0.0.i3.i33
  %t1.i37 = mul nuw i64 %x_hi_lo.i32, 4294967295
  %_0.0.i.i38 = add i64 %t0.sroa.0.0.i36, %t1.i37
  %_0.1.i.i39 = icmp ult i64 %_0.0.i.i38, %t0.sroa.0.0.i36
  %_0.i.i45 = add i64 %_0.0.i.i38, 4294967295
  %res.sroa.0.0.i40 = select i1 %_0.1.i.i39, i64 %_0.i.i45, i64 %_0.0.i.i38
  %_2.i.i41 = icmp ugt i64 %res.sroa.0.0.i40, -4294967296
  %_3.i.i42 = add nsw i64 %res.sroa.0.0.i40, 4294967295
  %_0.sroa.0.0.i.i43 = select i1 %_2.i.i41, i64 %_3.i.i42, i64 %res.sroa.0.0.i40
  %_3.i9.i = mul nuw i128 %_6.i20.i, %_4.i15.i
  %x_lo.i7 = trunc i128 %_3.i9.i to i64
  %_4.i8 = lshr i128 %_3.i9.i, 64
  %x_hi.i9 = trunc nuw i128 %_4.i8 to i64
  %x_hi_hi.i10 = lshr i64 %x_hi.i9, 32
  %x_hi_lo.i11 = and i64 %x_hi.i9, 4294967295
  %_0.0.i3.i12 = sub i64 %x_lo.i7, %x_hi_hi.i10
  %_0.1.i4.i13 = icmp ugt i64 %x_hi_hi.i10, %x_lo.i7
  %_0.i2.i26 = add i64 %_0.0.i3.i12, -4294967295
  %t0.sroa.0.0.i15 = select i1 %_0.1.i4.i13, i64 %_0.i2.i26, i64 %_0.0.i3.i12
  %t1.i16 = mul nuw i64 %x_hi_lo.i11, 4294967295
  %_0.0.i.i17 = add i64 %t0.sroa.0.0.i15, %t1.i16
  %_0.1.i.i18 = icmp ult i64 %_0.0.i.i17, %t0.sroa.0.0.i15
  %_0.i.i24 = add i64 %_0.0.i.i17, 4294967295
  %res.sroa.0.0.i19 = select i1 %_0.1.i.i18, i64 %_0.i.i24, i64 %_0.0.i.i17
  %_2.i.i20 = icmp ugt i64 %res.sroa.0.0.i19, -4294967296
  %_3.i.i21 = add nsw i64 %res.sroa.0.0.i19, 4294967295
  %_0.sroa.0.0.i.i22 = select i1 %_2.i.i20, i64 %_3.i.i21, i64 %res.sroa.0.0.i19
  %_4.i.i = zext i64 %_0.sroa.0.0.i.i64 to i128
  %_3.i.i = mul nuw nsw i128 %_4.i.i, 7
  %x_lo.i = trunc i128 %_3.i.i to i64
  %_4.i = lshr i128 %_3.i.i, 64
  %x_hi.i = trunc nuw nsw i128 %_4.i to i64
  %t1.i = mul nuw nsw i64 %x_hi.i, 4294967295
  %_0.0.i.i1 = add i64 %t1.i, %x_lo.i
  %_0.1.i.i2 = icmp ult i64 %_0.0.i.i1, %x_lo.i
  %_0.i.i6 = add i64 %_0.0.i.i1, 4294967295
  %res.sroa.0.0.i = select i1 %_0.1.i.i2, i64 %_0.i.i6, i64 %_0.0.i.i1
  %_2.i.i3 = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_3.i.i4 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i.i5 = select i1 %_2.i.i3, i64 %_3.i.i4, i64 %res.sroa.0.0.i
  %_0.0.i.i = add i64 %_0.sroa.0.0.i.i5, %_0.sroa.0.0.i.i85
  %_0.1.i.i = icmp ult i64 %_0.0.i.i, %_0.sroa.0.0.i.i85
  %_0.i.i = add i64 %_0.0.i.i, 4294967295
  %r.sroa.0.0.i3.i = select i1 %_0.1.i.i, i64 %_0.i.i, i64 %_0.0.i.i
  %_2.i.i = icmp ugt i64 %r.sroa.0.0.i3.i, -4294967296
  %_3.i23.i = add nsw i64 %r.sroa.0.0.i3.i, 4294967295
  %_0.sroa.0.0.i.i = select i1 %_2.i.i, i64 %_3.i23.i, i64 %r.sroa.0.0.i3.i
  %_0.0.i28.i = add i64 %_0.sroa.0.0.i.i43, %_0.sroa.0.0.i.i22
  %_0.1.i29.i = icmp ult i64 %_0.0.i28.i, %_0.sroa.0.0.i.i43
  %_0.i27.i = add i64 %_0.0.i28.i, 4294967295
  %r.sroa.0.0.i.i = select i1 %_0.1.i29.i, i64 %_0.i27.i, i64 %_0.0.i28.i
  %_2.i24.i = icmp ugt i64 %r.sroa.0.0.i.i, -4294967296
  %_3.i25.i = add nsw i64 %r.sroa.0.0.i.i, 4294967295
  %_0.sroa.0.0.i26.i = select i1 %_2.i24.i, i64 %_3.i25.i, i64 %r.sroa.0.0.i.i
  %0 = insertvalue { i64, i64 } poison, i64 %_0.sroa.0.0.i.i, 0
  %1 = insertvalue { i64, i64 } %0, i64 %_0.sroa.0.0.i26.i, 1
  ret { i64, i64 } %1
}

; <kernels::Fp2>::sub
; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind nonlazybind willreturn memory(none) uwtable
define internal fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %self.0, i64 noundef %self.1, i64 noundef %o.0, i64 noundef %o.1) unnamed_addr #0 {
start:
  %_0.0.i.i = sub i64 %self.0, %o.0
  %_0.1.i.i = icmp ult i64 %self.0, %o.0
  %_0.i.i = add i64 %_0.0.i.i, -4294967295
  %spec.select = select i1 %_0.1.i.i, i64 %_0.i.i, i64 %_0.0.i.i
  %_0.0.i7.i = sub i64 %self.1, %o.1
  %_0.1.i8.i = icmp ult i64 %self.1, %o.1
  %_0.i6.i = add i64 %_0.0.i7.i, -4294967295
  %_8.sroa.0.0.i.i = select i1 %_0.1.i8.i, i64 %_0.i6.i, i64 %_0.0.i7.i
  %0 = insertvalue { i64, i64 } poison, i64 %spec.select, 0
  %1 = insertvalue { i64, i64 } %0, i64 %_8.sroa.0.0.i.i, 1
  ret { i64, i64 } %1
}

; <kernels::Fp2>::mul_base
; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind nonlazybind willreturn memory(none) uwtable
define internal fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %self.0, i64 noundef %self.1, i64 noundef %o) unnamed_addr #0 {
start:
  %_4.i1.i = zext i64 %self.0 to i128
  %_6.i2.i = zext i64 %o to i128
  %_3.i3.i = mul nuw i128 %_6.i2.i, %_4.i1.i
  %x_lo.i3 = trunc i128 %_3.i3.i to i64
  %_4.i4 = lshr i128 %_3.i3.i, 64
  %x_hi.i5 = trunc nuw i128 %_4.i4 to i64
  %x_hi_hi.i6 = lshr i64 %x_hi.i5, 32
  %x_hi_lo.i7 = and i64 %x_hi.i5, 4294967295
  %_0.0.i3.i8 = sub i64 %x_lo.i3, %x_hi_hi.i6
  %_0.1.i4.i9 = icmp ugt i64 %x_hi_hi.i6, %x_lo.i3
  %_0.i2.i21 = add i64 %_0.0.i3.i8, -4294967295
  %spec.select = select i1 %_0.1.i4.i9, i64 %_0.i2.i21, i64 %_0.0.i3.i8
  %t1.i12 = mul nuw i64 %x_hi_lo.i7, 4294967295
  %_0.0.i.i13 = add i64 %spec.select, %t1.i12
  %_0.1.i.i14 = icmp ult i64 %_0.0.i.i13, %spec.select
  %_0.i.i = add i64 %_0.0.i.i13, 4294967295
  %res.sroa.0.0.i15 = select i1 %_0.1.i.i14, i64 %_0.i.i, i64 %_0.0.i.i13
  %_2.i.i16 = icmp ugt i64 %res.sroa.0.0.i15, -4294967296
  %_3.i.i17 = add nsw i64 %res.sroa.0.0.i15, 4294967295
  %_0.sroa.0.0.i.i18 = select i1 %_2.i.i16, i64 %_3.i.i17, i64 %res.sroa.0.0.i15
  %_4.i.i = zext i64 %self.1 to i128
  %_3.i.i = mul nuw i128 %_6.i2.i, %_4.i.i
  %x_lo.i = trunc i128 %_3.i.i to i64
  %_4.i = lshr i128 %_3.i.i, 64
  %x_hi.i = trunc nuw i128 %_4.i to i64
  %x_hi_hi.i = lshr i64 %x_hi.i, 32
  %x_hi_lo.i = and i64 %x_hi.i, 4294967295
  %_0.0.i3.i = sub i64 %x_lo.i, %x_hi_hi.i
  %_0.1.i4.i = icmp ugt i64 %x_hi_hi.i, %x_lo.i
  %_0.i2.i = add i64 %_0.0.i3.i, -4294967295
  %t0.sroa.0.0.i = select i1 %_0.1.i4.i, i64 %_0.i2.i, i64 %_0.0.i3.i
  %t1.i = mul nuw i64 %x_hi_lo.i, 4294967295
  %_0.0.i.i = add i64 %t0.sroa.0.0.i, %t1.i
  %_0.1.i.i = icmp ult i64 %_0.0.i.i, %t0.sroa.0.0.i
  %_0.i.i2 = add i64 %_0.0.i.i, 4294967295
  %res.sroa.0.0.i = select i1 %_0.1.i.i, i64 %_0.i.i2, i64 %_0.0.i.i
  %_2.i.i = icmp ugt i64 %res.sroa.0.0.i, -4294967296
  %_3.i.i1 = add nsw i64 %res.sroa.0.0.i, 4294967295
  %_0.sroa.0.0.i.i = select i1 %_2.i.i, i64 %_3.i.i1, i64 %res.sroa.0.0.i
  %0 = insertvalue { i64, i64 } poison, i64 %_0.sroa.0.0.i.i18, 0
  %1 = insertvalue { i64, i64 } %0, i64 %_0.sroa.0.0.i.i, 1
  ret { i64, i64 } %1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind nonlazybind willreturn memory(argmem: readwrite) uwtable
define void @baseline(ptr noundef readonly %raw, ptr noundef readonly %params, ptr noundef readonly captures(none) %bases, ptr noundef writeonly captures(none) initializes((0, 80)) %out) unnamed_addr #1 personality ptr @rust_eh_personality {
start:
  %s0.0 = load i64, ptr %params, align 8, !noundef !3
  %0 = getelementptr inbounds nuw i8, ptr %params, i64 8
  %s0.1 = load i64, ptr %0, align 8, !noundef !3
  %_0.i250 = getelementptr inbounds nuw i8, ptr %params, i64 16
  %s1.0 = load i64, ptr %_0.i250, align 8, !noundef !3
  %1 = getelementptr inbounds nuw i8, ptr %params, i64 24
  %s1.1 = load i64, ptr %1, align 8, !noundef !3
  %_0.i249 = getelementptr inbounds nuw i8, ptr %raw, i64 160
  %s2.0 = load i64, ptr %_0.i249, align 8, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %raw, i64 168
  %s2.1 = load i64, ptr %2, align 8, !noundef !3
  %_0.i248 = getelementptr inbounds nuw i8, ptr %raw, i64 176
  %s3.0 = load i64, ptr %_0.i248, align 8, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %raw, i64 184
  %s3.1 = load i64, ptr %3, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %4 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s3.0, i64 noundef %s3.1, i64 noundef %s2.0, i64 noundef %s2.1)
  %s4.0 = extractvalue { i64, i64 } %4, 0
  %s4.1 = extractvalue { i64, i64 } %4, 1
  %_0.i247 = getelementptr inbounds nuw i8, ptr %params, i64 32
  %s5.0 = load i64, ptr %_0.i247, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %params, i64 40
  %s5.1 = load i64, ptr %5, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %6 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s2.0, i64 noundef %s2.1, i64 noundef %s5.0, i64 noundef %s5.1)
; call <kernels::Fp2>::mul
  %7 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s4.0, i64 noundef %s4.1, i64 noundef %s5.0, i64 noundef %s5.1)
  %s6.1 = extractvalue { i64, i64 } %6, 1
  %s6.0 = extractvalue { i64, i64 } %6, 0
; call <kernels::Fp2>::add
  %8 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s0.0, i64 noundef %s0.1, i64 noundef %s6.0, i64 noundef %s6.1)
  %s7.1 = extractvalue { i64, i64 } %7, 1
  %s7.0 = extractvalue { i64, i64 } %7, 0
  %s8.0 = extractvalue { i64, i64 } %8, 0
  %s8.1 = extractvalue { i64, i64 } %8, 1
; call <kernels::Fp2>::add
  %9 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1.0, i64 noundef %s1.1, i64 noundef %s7.0, i64 noundef %s7.1)
  %s9.0 = extractvalue { i64, i64 } %9, 0
  %s9.1 = extractvalue { i64, i64 } %9, 1
  %_0.i246 = getelementptr inbounds nuw i8, ptr %raw, i64 544
  %s10.0 = load i64, ptr %_0.i246, align 8, !noundef !3
  %10 = getelementptr inbounds nuw i8, ptr %raw, i64 552
  %s10.1 = load i64, ptr %10, align 8, !noundef !3
  %_0.i245 = getelementptr inbounds nuw i8, ptr %raw, i64 560
  %s11.0 = load i64, ptr %_0.i245, align 8, !noundef !3
  %11 = getelementptr inbounds nuw i8, ptr %raw, i64 568
  %s11.1 = load i64, ptr %11, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %12 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s11.0, i64 noundef %s11.1, i64 noundef %s10.0, i64 noundef %s10.1)
  %s12.0 = extractvalue { i64, i64 } %12, 0
  %s12.1 = extractvalue { i64, i64 } %12, 1
  %_0.i244 = getelementptr inbounds nuw i8, ptr %params, i64 48
  %s13.0 = load i64, ptr %_0.i244, align 8, !noundef !3
  %13 = getelementptr inbounds nuw i8, ptr %params, i64 56
  %s13.1 = load i64, ptr %13, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %14 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s10.0, i64 noundef %s10.1, i64 noundef %s13.0, i64 noundef %s13.1)
; call <kernels::Fp2>::mul
  %15 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s12.0, i64 noundef %s12.1, i64 noundef %s13.0, i64 noundef %s13.1)
  %s14.1 = extractvalue { i64, i64 } %14, 1
  %s14.0 = extractvalue { i64, i64 } %14, 0
; call <kernels::Fp2>::add
  %16 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s8.0, i64 noundef %s8.1, i64 noundef %s14.0, i64 noundef %s14.1)
  %s15.1 = extractvalue { i64, i64 } %15, 1
  %s15.0 = extractvalue { i64, i64 } %15, 0
  %s16.0 = extractvalue { i64, i64 } %16, 0
  %s16.1 = extractvalue { i64, i64 } %16, 1
; call <kernels::Fp2>::add
  %17 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s9.0, i64 noundef %s9.1, i64 noundef %s15.0, i64 noundef %s15.1)
  %s17.0 = extractvalue { i64, i64 } %17, 0
  %s17.1 = extractvalue { i64, i64 } %17, 1
  %_0.i243 = getelementptr inbounds nuw i8, ptr %raw, i64 672
  %s18.0 = load i64, ptr %_0.i243, align 8, !noundef !3
  %18 = getelementptr inbounds nuw i8, ptr %raw, i64 680
  %s18.1 = load i64, ptr %18, align 8, !noundef !3
  %_0.i242 = getelementptr inbounds nuw i8, ptr %raw, i64 688
  %s19.0 = load i64, ptr %_0.i242, align 8, !noundef !3
  %19 = getelementptr inbounds nuw i8, ptr %raw, i64 696
  %s19.1 = load i64, ptr %19, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %20 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s19.0, i64 noundef %s19.1, i64 noundef %s18.0, i64 noundef %s18.1)
  %s20.0 = extractvalue { i64, i64 } %20, 0
  %s20.1 = extractvalue { i64, i64 } %20, 1
  %_0.i241 = getelementptr inbounds nuw i8, ptr %params, i64 64
  %s21.0 = load i64, ptr %_0.i241, align 8, !noundef !3
  %21 = getelementptr inbounds nuw i8, ptr %params, i64 72
  %s21.1 = load i64, ptr %21, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %22 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s18.0, i64 noundef %s18.1, i64 noundef %s21.0, i64 noundef %s21.1)
; call <kernels::Fp2>::mul
  %23 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s20.0, i64 noundef %s20.1, i64 noundef %s21.0, i64 noundef %s21.1)
  %s22.1 = extractvalue { i64, i64 } %22, 1
  %s22.0 = extractvalue { i64, i64 } %22, 0
; call <kernels::Fp2>::add
  %24 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s16.0, i64 noundef %s16.1, i64 noundef %s22.0, i64 noundef %s22.1)
  %s23.1 = extractvalue { i64, i64 } %23, 1
  %s23.0 = extractvalue { i64, i64 } %23, 0
  %s24.0 = extractvalue { i64, i64 } %24, 0
  %s24.1 = extractvalue { i64, i64 } %24, 1
; call <kernels::Fp2>::add
  %25 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s17.0, i64 noundef %s17.1, i64 noundef %s23.0, i64 noundef %s23.1)
  %s25.0 = extractvalue { i64, i64 } %25, 0
  %s25.1 = extractvalue { i64, i64 } %25, 1
  %_0.i240 = getelementptr inbounds nuw i8, ptr %raw, i64 1088
  %s26.0 = load i64, ptr %_0.i240, align 8, !noundef !3
  %26 = getelementptr inbounds nuw i8, ptr %raw, i64 1096
  %s26.1 = load i64, ptr %26, align 8, !noundef !3
  %_0.i239 = getelementptr inbounds nuw i8, ptr %raw, i64 1104
  %s27.0 = load i64, ptr %_0.i239, align 8, !noundef !3
  %27 = getelementptr inbounds nuw i8, ptr %raw, i64 1112
  %s27.1 = load i64, ptr %27, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %28 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s27.0, i64 noundef %s27.1, i64 noundef %s26.0, i64 noundef %s26.1)
  %s28.0 = extractvalue { i64, i64 } %28, 0
  %s28.1 = extractvalue { i64, i64 } %28, 1
  %_0.i238 = getelementptr inbounds nuw i8, ptr %params, i64 80
  %s29.0 = load i64, ptr %_0.i238, align 8, !noundef !3
  %29 = getelementptr inbounds nuw i8, ptr %params, i64 88
  %s29.1 = load i64, ptr %29, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %30 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s26.0, i64 noundef %s26.1, i64 noundef %s29.0, i64 noundef %s29.1)
; call <kernels::Fp2>::mul
  %31 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s28.0, i64 noundef %s28.1, i64 noundef %s29.0, i64 noundef %s29.1)
  %s30.1 = extractvalue { i64, i64 } %30, 1
  %s30.0 = extractvalue { i64, i64 } %30, 0
; call <kernels::Fp2>::add
  %32 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s24.0, i64 noundef %s24.1, i64 noundef %s30.0, i64 noundef %s30.1)
  %s31.1 = extractvalue { i64, i64 } %31, 1
  %s31.0 = extractvalue { i64, i64 } %31, 0
  %s32.0 = extractvalue { i64, i64 } %32, 0
  %s32.1 = extractvalue { i64, i64 } %32, 1
; call <kernels::Fp2>::add
  %33 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s25.0, i64 noundef %s25.1, i64 noundef %s31.0, i64 noundef %s31.1)
  %s33.0 = extractvalue { i64, i64 } %33, 0
  %s33.1 = extractvalue { i64, i64 } %33, 1
  %_0.i237 = getelementptr inbounds nuw i8, ptr %raw, i64 1056
  %s34.0 = load i64, ptr %_0.i237, align 8, !noundef !3
  %34 = getelementptr inbounds nuw i8, ptr %raw, i64 1064
  %s34.1 = load i64, ptr %34, align 8, !noundef !3
  %_0.i236 = getelementptr inbounds nuw i8, ptr %raw, i64 1072
  %s35.0 = load i64, ptr %_0.i236, align 8, !noundef !3
  %35 = getelementptr inbounds nuw i8, ptr %raw, i64 1080
  %s35.1 = load i64, ptr %35, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %36 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s35.0, i64 noundef %s35.1, i64 noundef %s34.0, i64 noundef %s34.1)
  %s36.0 = extractvalue { i64, i64 } %36, 0
  %s36.1 = extractvalue { i64, i64 } %36, 1
  %_0.i235 = getelementptr inbounds nuw i8, ptr %params, i64 96
  %s37.0 = load i64, ptr %_0.i235, align 8, !noundef !3
  %37 = getelementptr inbounds nuw i8, ptr %params, i64 104
  %s37.1 = load i64, ptr %37, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %38 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s34.0, i64 noundef %s34.1, i64 noundef %s37.0, i64 noundef %s37.1)
; call <kernels::Fp2>::mul
  %39 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s36.0, i64 noundef %s36.1, i64 noundef %s37.0, i64 noundef %s37.1)
  %s38.1 = extractvalue { i64, i64 } %38, 1
  %s38.0 = extractvalue { i64, i64 } %38, 0
; call <kernels::Fp2>::add
  %40 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s32.0, i64 noundef %s32.1, i64 noundef %s38.0, i64 noundef %s38.1)
  %s39.1 = extractvalue { i64, i64 } %39, 1
  %s39.0 = extractvalue { i64, i64 } %39, 0
  %s40.0 = extractvalue { i64, i64 } %40, 0
  %s40.1 = extractvalue { i64, i64 } %40, 1
; call <kernels::Fp2>::add
  %41 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s33.0, i64 noundef %s33.1, i64 noundef %s39.0, i64 noundef %s39.1)
  %s41.0 = extractvalue { i64, i64 } %41, 0
  %s41.1 = extractvalue { i64, i64 } %41, 1
  %_0.i234 = getelementptr inbounds nuw i8, ptr %raw, i64 1280
  %s42.0 = load i64, ptr %_0.i234, align 8, !noundef !3
  %42 = getelementptr inbounds nuw i8, ptr %raw, i64 1288
  %s42.1 = load i64, ptr %42, align 8, !noundef !3
  %_0.i233 = getelementptr inbounds nuw i8, ptr %raw, i64 1296
  %s43.0 = load i64, ptr %_0.i233, align 8, !noundef !3
  %43 = getelementptr inbounds nuw i8, ptr %raw, i64 1304
  %s43.1 = load i64, ptr %43, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %44 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s43.0, i64 noundef %s43.1, i64 noundef %s42.0, i64 noundef %s42.1)
  %s44.0 = extractvalue { i64, i64 } %44, 0
  %s44.1 = extractvalue { i64, i64 } %44, 1
  %_0.i232 = getelementptr inbounds nuw i8, ptr %params, i64 112
  %s45.0 = load i64, ptr %_0.i232, align 8, !noundef !3
  %45 = getelementptr inbounds nuw i8, ptr %params, i64 120
  %s45.1 = load i64, ptr %45, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %46 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s42.0, i64 noundef %s42.1, i64 noundef %s45.0, i64 noundef %s45.1)
; call <kernels::Fp2>::mul
  %47 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s44.0, i64 noundef %s44.1, i64 noundef %s45.0, i64 noundef %s45.1)
  %s46.1 = extractvalue { i64, i64 } %46, 1
  %s46.0 = extractvalue { i64, i64 } %46, 0
; call <kernels::Fp2>::add
  %48 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s40.0, i64 noundef %s40.1, i64 noundef %s46.0, i64 noundef %s46.1)
  %s47.1 = extractvalue { i64, i64 } %47, 1
  %s47.0 = extractvalue { i64, i64 } %47, 0
  %s48.0 = extractvalue { i64, i64 } %48, 0
  %s48.1 = extractvalue { i64, i64 } %48, 1
; call <kernels::Fp2>::add
  %49 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s41.0, i64 noundef %s41.1, i64 noundef %s47.0, i64 noundef %s47.1)
  %s49.0 = extractvalue { i64, i64 } %49, 0
  %s49.1 = extractvalue { i64, i64 } %49, 1
  %_0.i231 = getelementptr inbounds nuw i8, ptr %raw, i64 1312
  %s50.0 = load i64, ptr %_0.i231, align 8, !noundef !3
  %50 = getelementptr inbounds nuw i8, ptr %raw, i64 1320
  %s50.1 = load i64, ptr %50, align 8, !noundef !3
  %_0.i230 = getelementptr inbounds nuw i8, ptr %raw, i64 1328
  %s51.0 = load i64, ptr %_0.i230, align 8, !noundef !3
  %51 = getelementptr inbounds nuw i8, ptr %raw, i64 1336
  %s51.1 = load i64, ptr %51, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %52 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s51.0, i64 noundef %s51.1, i64 noundef %s50.0, i64 noundef %s50.1)
  %s52.0 = extractvalue { i64, i64 } %52, 0
  %s52.1 = extractvalue { i64, i64 } %52, 1
  %_0.i229 = getelementptr inbounds nuw i8, ptr %params, i64 128
  %s53.0 = load i64, ptr %_0.i229, align 8, !noundef !3
  %53 = getelementptr inbounds nuw i8, ptr %params, i64 136
  %s53.1 = load i64, ptr %53, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %54 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s50.0, i64 noundef %s50.1, i64 noundef %s53.0, i64 noundef %s53.1)
; call <kernels::Fp2>::mul
  %55 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s52.0, i64 noundef %s52.1, i64 noundef %s53.0, i64 noundef %s53.1)
  %s54.1 = extractvalue { i64, i64 } %54, 1
  %s54.0 = extractvalue { i64, i64 } %54, 0
; call <kernels::Fp2>::add
  %56 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s48.0, i64 noundef %s48.1, i64 noundef %s54.0, i64 noundef %s54.1)
  %s55.1 = extractvalue { i64, i64 } %55, 1
  %s55.0 = extractvalue { i64, i64 } %55, 0
  %s56.0 = extractvalue { i64, i64 } %56, 0
  %s56.1 = extractvalue { i64, i64 } %56, 1
; call <kernels::Fp2>::add
  %57 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s49.0, i64 noundef %s49.1, i64 noundef %s55.0, i64 noundef %s55.1)
  %s57.0 = extractvalue { i64, i64 } %57, 0
  %s57.1 = extractvalue { i64, i64 } %57, 1
  %_0.i228 = getelementptr inbounds nuw i8, ptr %raw, i64 192
  %s58.0 = load i64, ptr %_0.i228, align 8, !noundef !3
  %58 = getelementptr inbounds nuw i8, ptr %raw, i64 200
  %s58.1 = load i64, ptr %58, align 8, !noundef !3
  %_0.i227 = getelementptr inbounds nuw i8, ptr %raw, i64 208
  %s59.0 = load i64, ptr %_0.i227, align 8, !noundef !3
  %59 = getelementptr inbounds nuw i8, ptr %raw, i64 216
  %s59.1 = load i64, ptr %59, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %60 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s59.0, i64 noundef %s59.1, i64 noundef %s58.0, i64 noundef %s58.1)
  %s60.0 = extractvalue { i64, i64 } %60, 0
  %s60.1 = extractvalue { i64, i64 } %60, 1
  %_0.i226 = getelementptr inbounds nuw i8, ptr %params, i64 144
  %s61.0 = load i64, ptr %_0.i226, align 8, !noundef !3
  %61 = getelementptr inbounds nuw i8, ptr %params, i64 152
  %s61.1 = load i64, ptr %61, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %62 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s58.0, i64 noundef %s58.1, i64 noundef %s61.0, i64 noundef %s61.1)
; call <kernels::Fp2>::mul
  %63 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s60.0, i64 noundef %s60.1, i64 noundef %s61.0, i64 noundef %s61.1)
  %s62.1 = extractvalue { i64, i64 } %62, 1
  %s62.0 = extractvalue { i64, i64 } %62, 0
; call <kernels::Fp2>::add
  %64 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s56.0, i64 noundef %s56.1, i64 noundef %s62.0, i64 noundef %s62.1)
  %s63.1 = extractvalue { i64, i64 } %63, 1
  %s63.0 = extractvalue { i64, i64 } %63, 0
  %s64.0 = extractvalue { i64, i64 } %64, 0
  %s64.1 = extractvalue { i64, i64 } %64, 1
; call <kernels::Fp2>::add
  %65 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s57.0, i64 noundef %s57.1, i64 noundef %s63.0, i64 noundef %s63.1)
  %s65.0 = extractvalue { i64, i64 } %65, 0
  %s65.1 = extractvalue { i64, i64 } %65, 1
  %_0.i225 = getelementptr inbounds nuw i8, ptr %raw, i64 224
  %s66.0 = load i64, ptr %_0.i225, align 8, !noundef !3
  %66 = getelementptr inbounds nuw i8, ptr %raw, i64 232
  %s66.1 = load i64, ptr %66, align 8, !noundef !3
  %_0.i224 = getelementptr inbounds nuw i8, ptr %raw, i64 240
  %s67.0 = load i64, ptr %_0.i224, align 8, !noundef !3
  %67 = getelementptr inbounds nuw i8, ptr %raw, i64 248
  %s67.1 = load i64, ptr %67, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %68 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s67.0, i64 noundef %s67.1, i64 noundef %s66.0, i64 noundef %s66.1)
  %s68.0 = extractvalue { i64, i64 } %68, 0
  %s68.1 = extractvalue { i64, i64 } %68, 1
  %_0.i223 = getelementptr inbounds nuw i8, ptr %params, i64 160
  %s69.0 = load i64, ptr %_0.i223, align 8, !noundef !3
  %69 = getelementptr inbounds nuw i8, ptr %params, i64 168
  %s69.1 = load i64, ptr %69, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %70 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s66.0, i64 noundef %s66.1, i64 noundef %s69.0, i64 noundef %s69.1)
; call <kernels::Fp2>::mul
  %71 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s68.0, i64 noundef %s68.1, i64 noundef %s69.0, i64 noundef %s69.1)
  %s70.1 = extractvalue { i64, i64 } %70, 1
  %s70.0 = extractvalue { i64, i64 } %70, 0
; call <kernels::Fp2>::add
  %72 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s64.0, i64 noundef %s64.1, i64 noundef %s70.0, i64 noundef %s70.1)
  %s71.1 = extractvalue { i64, i64 } %71, 1
  %s71.0 = extractvalue { i64, i64 } %71, 0
  %s72.0 = extractvalue { i64, i64 } %72, 0
  %s72.1 = extractvalue { i64, i64 } %72, 1
; call <kernels::Fp2>::add
  %73 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s65.0, i64 noundef %s65.1, i64 noundef %s71.0, i64 noundef %s71.1)
  %s73.0 = extractvalue { i64, i64 } %73, 0
  %s73.1 = extractvalue { i64, i64 } %73, 1
  %_0.i222 = getelementptr inbounds nuw i8, ptr %raw, i64 576
  %s74.0 = load i64, ptr %_0.i222, align 8, !noundef !3
  %74 = getelementptr inbounds nuw i8, ptr %raw, i64 584
  %s74.1 = load i64, ptr %74, align 8, !noundef !3
  %_0.i221 = getelementptr inbounds nuw i8, ptr %raw, i64 592
  %s75.0 = load i64, ptr %_0.i221, align 8, !noundef !3
  %75 = getelementptr inbounds nuw i8, ptr %raw, i64 600
  %s75.1 = load i64, ptr %75, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %76 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s75.0, i64 noundef %s75.1, i64 noundef %s74.0, i64 noundef %s74.1)
  %s76.0 = extractvalue { i64, i64 } %76, 0
  %s76.1 = extractvalue { i64, i64 } %76, 1
  %_0.i220 = getelementptr inbounds nuw i8, ptr %params, i64 176
  %s77.0 = load i64, ptr %_0.i220, align 8, !noundef !3
  %77 = getelementptr inbounds nuw i8, ptr %params, i64 184
  %s77.1 = load i64, ptr %77, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %78 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s74.0, i64 noundef %s74.1, i64 noundef %s77.0, i64 noundef %s77.1)
; call <kernels::Fp2>::mul
  %79 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s76.0, i64 noundef %s76.1, i64 noundef %s77.0, i64 noundef %s77.1)
  %s78.1 = extractvalue { i64, i64 } %78, 1
  %s78.0 = extractvalue { i64, i64 } %78, 0
; call <kernels::Fp2>::add
  %80 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s72.0, i64 noundef %s72.1, i64 noundef %s78.0, i64 noundef %s78.1)
  %s79.1 = extractvalue { i64, i64 } %79, 1
  %s79.0 = extractvalue { i64, i64 } %79, 0
  %s80.0 = extractvalue { i64, i64 } %80, 0
  %s80.1 = extractvalue { i64, i64 } %80, 1
; call <kernels::Fp2>::add
  %81 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s73.0, i64 noundef %s73.1, i64 noundef %s79.0, i64 noundef %s79.1)
  %s81.0 = extractvalue { i64, i64 } %81, 0
  %s81.1 = extractvalue { i64, i64 } %81, 1
  %_0.i219 = getelementptr inbounds nuw i8, ptr %raw, i64 608
  %s82.0 = load i64, ptr %_0.i219, align 8, !noundef !3
  %82 = getelementptr inbounds nuw i8, ptr %raw, i64 616
  %s82.1 = load i64, ptr %82, align 8, !noundef !3
  %_0.i218 = getelementptr inbounds nuw i8, ptr %raw, i64 624
  %s83.0 = load i64, ptr %_0.i218, align 8, !noundef !3
  %83 = getelementptr inbounds nuw i8, ptr %raw, i64 632
  %s83.1 = load i64, ptr %83, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %84 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s83.0, i64 noundef %s83.1, i64 noundef %s82.0, i64 noundef %s82.1)
  %s84.0 = extractvalue { i64, i64 } %84, 0
  %s84.1 = extractvalue { i64, i64 } %84, 1
  %_0.i217 = getelementptr inbounds nuw i8, ptr %params, i64 192
  %s85.0 = load i64, ptr %_0.i217, align 8, !noundef !3
  %85 = getelementptr inbounds nuw i8, ptr %params, i64 200
  %s85.1 = load i64, ptr %85, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %86 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s82.0, i64 noundef %s82.1, i64 noundef %s85.0, i64 noundef %s85.1)
; call <kernels::Fp2>::mul
  %87 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s84.0, i64 noundef %s84.1, i64 noundef %s85.0, i64 noundef %s85.1)
  %s86.1 = extractvalue { i64, i64 } %86, 1
  %s86.0 = extractvalue { i64, i64 } %86, 0
; call <kernels::Fp2>::add
  %88 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s80.0, i64 noundef %s80.1, i64 noundef %s86.0, i64 noundef %s86.1)
  %s87.1 = extractvalue { i64, i64 } %87, 1
  %s87.0 = extractvalue { i64, i64 } %87, 0
  %s88.0 = extractvalue { i64, i64 } %88, 0
  %s88.1 = extractvalue { i64, i64 } %88, 1
; call <kernels::Fp2>::add
  %89 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s81.0, i64 noundef %s81.1, i64 noundef %s87.0, i64 noundef %s87.1)
  %s89.0 = extractvalue { i64, i64 } %89, 0
  %s89.1 = extractvalue { i64, i64 } %89, 1
  %_0.i216 = getelementptr inbounds nuw i8, ptr %raw, i64 704
  %s90.0 = load i64, ptr %_0.i216, align 8, !noundef !3
  %90 = getelementptr inbounds nuw i8, ptr %raw, i64 712
  %s90.1 = load i64, ptr %90, align 8, !noundef !3
  %_0.i215 = getelementptr inbounds nuw i8, ptr %raw, i64 720
  %s91.0 = load i64, ptr %_0.i215, align 8, !noundef !3
  %91 = getelementptr inbounds nuw i8, ptr %raw, i64 728
  %s91.1 = load i64, ptr %91, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %92 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s91.0, i64 noundef %s91.1, i64 noundef %s90.0, i64 noundef %s90.1)
  %s92.0 = extractvalue { i64, i64 } %92, 0
  %s92.1 = extractvalue { i64, i64 } %92, 1
  %_0.i214 = getelementptr inbounds nuw i8, ptr %params, i64 208
  %s93.0 = load i64, ptr %_0.i214, align 8, !noundef !3
  %93 = getelementptr inbounds nuw i8, ptr %params, i64 216
  %s93.1 = load i64, ptr %93, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %94 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s90.0, i64 noundef %s90.1, i64 noundef %s93.0, i64 noundef %s93.1)
; call <kernels::Fp2>::mul
  %95 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s92.0, i64 noundef %s92.1, i64 noundef %s93.0, i64 noundef %s93.1)
  %s94.1 = extractvalue { i64, i64 } %94, 1
  %s94.0 = extractvalue { i64, i64 } %94, 0
; call <kernels::Fp2>::add
  %96 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s88.0, i64 noundef %s88.1, i64 noundef %s94.0, i64 noundef %s94.1)
  %s95.1 = extractvalue { i64, i64 } %95, 1
  %s95.0 = extractvalue { i64, i64 } %95, 0
  %s96.0 = extractvalue { i64, i64 } %96, 0
  %s96.1 = extractvalue { i64, i64 } %96, 1
; call <kernels::Fp2>::add
  %97 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s89.0, i64 noundef %s89.1, i64 noundef %s95.0, i64 noundef %s95.1)
  %s97.0 = extractvalue { i64, i64 } %97, 0
  %s97.1 = extractvalue { i64, i64 } %97, 1
  %_0.i213 = getelementptr inbounds nuw i8, ptr %raw, i64 736
  %s98.0 = load i64, ptr %_0.i213, align 8, !noundef !3
  %98 = getelementptr inbounds nuw i8, ptr %raw, i64 744
  %s98.1 = load i64, ptr %98, align 8, !noundef !3
  %_0.i212 = getelementptr inbounds nuw i8, ptr %raw, i64 752
  %s99.0 = load i64, ptr %_0.i212, align 8, !noundef !3
  %99 = getelementptr inbounds nuw i8, ptr %raw, i64 760
  %s99.1 = load i64, ptr %99, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %100 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s99.0, i64 noundef %s99.1, i64 noundef %s98.0, i64 noundef %s98.1)
  %s100.0 = extractvalue { i64, i64 } %100, 0
  %s100.1 = extractvalue { i64, i64 } %100, 1
  %_0.i211 = getelementptr inbounds nuw i8, ptr %params, i64 224
  %s101.0 = load i64, ptr %_0.i211, align 8, !noundef !3
  %101 = getelementptr inbounds nuw i8, ptr %params, i64 232
  %s101.1 = load i64, ptr %101, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %102 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s98.0, i64 noundef %s98.1, i64 noundef %s101.0, i64 noundef %s101.1)
; call <kernels::Fp2>::mul
  %103 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s100.0, i64 noundef %s100.1, i64 noundef %s101.0, i64 noundef %s101.1)
  %s102.1 = extractvalue { i64, i64 } %102, 1
  %s102.0 = extractvalue { i64, i64 } %102, 0
; call <kernels::Fp2>::add
  %104 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s96.0, i64 noundef %s96.1, i64 noundef %s102.0, i64 noundef %s102.1)
  %s103.1 = extractvalue { i64, i64 } %103, 1
  %s103.0 = extractvalue { i64, i64 } %103, 0
  %s104.0 = extractvalue { i64, i64 } %104, 0
  %s104.1 = extractvalue { i64, i64 } %104, 1
; call <kernels::Fp2>::add
  %105 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s97.0, i64 noundef %s97.1, i64 noundef %s103.0, i64 noundef %s103.1)
  %s105.0 = extractvalue { i64, i64 } %105, 0
  %s105.1 = extractvalue { i64, i64 } %105, 1
  %_0.i210 = getelementptr inbounds nuw i8, ptr %raw, i64 1120
  %s106.0 = load i64, ptr %_0.i210, align 8, !noundef !3
  %106 = getelementptr inbounds nuw i8, ptr %raw, i64 1128
  %s106.1 = load i64, ptr %106, align 8, !noundef !3
  %_0.i209 = getelementptr inbounds nuw i8, ptr %raw, i64 1136
  %s107.0 = load i64, ptr %_0.i209, align 8, !noundef !3
  %107 = getelementptr inbounds nuw i8, ptr %raw, i64 1144
  %s107.1 = load i64, ptr %107, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %108 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s107.0, i64 noundef %s107.1, i64 noundef %s106.0, i64 noundef %s106.1)
  %s108.0 = extractvalue { i64, i64 } %108, 0
  %s108.1 = extractvalue { i64, i64 } %108, 1
  %_0.i208 = getelementptr inbounds nuw i8, ptr %params, i64 240
  %s109.0 = load i64, ptr %_0.i208, align 8, !noundef !3
  %109 = getelementptr inbounds nuw i8, ptr %params, i64 248
  %s109.1 = load i64, ptr %109, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %110 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s106.0, i64 noundef %s106.1, i64 noundef %s109.0, i64 noundef %s109.1)
; call <kernels::Fp2>::mul
  %111 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s108.0, i64 noundef %s108.1, i64 noundef %s109.0, i64 noundef %s109.1)
  %s110.1 = extractvalue { i64, i64 } %110, 1
  %s110.0 = extractvalue { i64, i64 } %110, 0
; call <kernels::Fp2>::add
  %112 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s104.0, i64 noundef %s104.1, i64 noundef %s110.0, i64 noundef %s110.1)
  %s111.1 = extractvalue { i64, i64 } %111, 1
  %s111.0 = extractvalue { i64, i64 } %111, 0
  %s112.0 = extractvalue { i64, i64 } %112, 0
  %s112.1 = extractvalue { i64, i64 } %112, 1
; call <kernels::Fp2>::add
  %113 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s105.0, i64 noundef %s105.1, i64 noundef %s111.0, i64 noundef %s111.1)
  %s113.0 = extractvalue { i64, i64 } %113, 0
  %s113.1 = extractvalue { i64, i64 } %113, 1
  %_0.i207 = getelementptr inbounds nuw i8, ptr %raw, i64 1152
  %s114.0 = load i64, ptr %_0.i207, align 8, !noundef !3
  %114 = getelementptr inbounds nuw i8, ptr %raw, i64 1160
  %s114.1 = load i64, ptr %114, align 8, !noundef !3
  %_0.i206 = getelementptr inbounds nuw i8, ptr %raw, i64 1168
  %s115.0 = load i64, ptr %_0.i206, align 8, !noundef !3
  %115 = getelementptr inbounds nuw i8, ptr %raw, i64 1176
  %s115.1 = load i64, ptr %115, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %116 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s115.0, i64 noundef %s115.1, i64 noundef %s114.0, i64 noundef %s114.1)
  %s116.0 = extractvalue { i64, i64 } %116, 0
  %s116.1 = extractvalue { i64, i64 } %116, 1
  %_0.i205 = getelementptr inbounds nuw i8, ptr %params, i64 256
  %s117.0 = load i64, ptr %_0.i205, align 8, !noundef !3
  %117 = getelementptr inbounds nuw i8, ptr %params, i64 264
  %s117.1 = load i64, ptr %117, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %118 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s114.0, i64 noundef %s114.1, i64 noundef %s117.0, i64 noundef %s117.1)
; call <kernels::Fp2>::mul
  %119 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s116.0, i64 noundef %s116.1, i64 noundef %s117.0, i64 noundef %s117.1)
  %s118.1 = extractvalue { i64, i64 } %118, 1
  %s118.0 = extractvalue { i64, i64 } %118, 0
; call <kernels::Fp2>::add
  %120 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s112.0, i64 noundef %s112.1, i64 noundef %s118.0, i64 noundef %s118.1)
  %s119.1 = extractvalue { i64, i64 } %119, 1
  %s119.0 = extractvalue { i64, i64 } %119, 0
  %s120.0 = extractvalue { i64, i64 } %120, 0
  %s120.1 = extractvalue { i64, i64 } %120, 1
; call <kernels::Fp2>::add
  %121 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s113.0, i64 noundef %s113.1, i64 noundef %s119.0, i64 noundef %s119.1)
  %s121.0 = extractvalue { i64, i64 } %121, 0
  %s121.1 = extractvalue { i64, i64 } %121, 1
  %_0.i204 = getelementptr inbounds nuw i8, ptr %raw, i64 1184
  %s122.0 = load i64, ptr %_0.i204, align 8, !noundef !3
  %122 = getelementptr inbounds nuw i8, ptr %raw, i64 1192
  %s122.1 = load i64, ptr %122, align 8, !noundef !3
  %_0.i203 = getelementptr inbounds nuw i8, ptr %raw, i64 1200
  %s123.0 = load i64, ptr %_0.i203, align 8, !noundef !3
  %123 = getelementptr inbounds nuw i8, ptr %raw, i64 1208
  %s123.1 = load i64, ptr %123, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %124 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s123.0, i64 noundef %s123.1, i64 noundef %s122.0, i64 noundef %s122.1)
  %s124.0 = extractvalue { i64, i64 } %124, 0
  %s124.1 = extractvalue { i64, i64 } %124, 1
  %_0.i202 = getelementptr inbounds nuw i8, ptr %params, i64 272
  %s125.0 = load i64, ptr %_0.i202, align 8, !noundef !3
  %125 = getelementptr inbounds nuw i8, ptr %params, i64 280
  %s125.1 = load i64, ptr %125, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %126 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s122.0, i64 noundef %s122.1, i64 noundef %s125.0, i64 noundef %s125.1)
; call <kernels::Fp2>::mul
  %127 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s124.0, i64 noundef %s124.1, i64 noundef %s125.0, i64 noundef %s125.1)
  %s126.1 = extractvalue { i64, i64 } %126, 1
  %s126.0 = extractvalue { i64, i64 } %126, 0
; call <kernels::Fp2>::add
  %128 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s120.0, i64 noundef %s120.1, i64 noundef %s126.0, i64 noundef %s126.1)
  %s127.1 = extractvalue { i64, i64 } %127, 1
  %s127.0 = extractvalue { i64, i64 } %127, 0
  %s128.0 = extractvalue { i64, i64 } %128, 0
  %s128.1 = extractvalue { i64, i64 } %128, 1
; call <kernels::Fp2>::add
  %129 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s121.0, i64 noundef %s121.1, i64 noundef %s127.0, i64 noundef %s127.1)
  %s129.0 = extractvalue { i64, i64 } %129, 0
  %s129.1 = extractvalue { i64, i64 } %129, 1
  %_0.i201 = getelementptr inbounds nuw i8, ptr %raw, i64 1216
  %s130.0 = load i64, ptr %_0.i201, align 8, !noundef !3
  %130 = getelementptr inbounds nuw i8, ptr %raw, i64 1224
  %s130.1 = load i64, ptr %130, align 8, !noundef !3
  %_0.i200 = getelementptr inbounds nuw i8, ptr %raw, i64 1232
  %s131.0 = load i64, ptr %_0.i200, align 8, !noundef !3
  %131 = getelementptr inbounds nuw i8, ptr %raw, i64 1240
  %s131.1 = load i64, ptr %131, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %132 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s131.0, i64 noundef %s131.1, i64 noundef %s130.0, i64 noundef %s130.1)
  %s132.0 = extractvalue { i64, i64 } %132, 0
  %s132.1 = extractvalue { i64, i64 } %132, 1
  %_0.i199 = getelementptr inbounds nuw i8, ptr %params, i64 288
  %s133.0 = load i64, ptr %_0.i199, align 8, !noundef !3
  %133 = getelementptr inbounds nuw i8, ptr %params, i64 296
  %s133.1 = load i64, ptr %133, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %134 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s130.0, i64 noundef %s130.1, i64 noundef %s133.0, i64 noundef %s133.1)
; call <kernels::Fp2>::mul
  %135 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s132.0, i64 noundef %s132.1, i64 noundef %s133.0, i64 noundef %s133.1)
  %s134.1 = extractvalue { i64, i64 } %134, 1
  %s134.0 = extractvalue { i64, i64 } %134, 0
; call <kernels::Fp2>::add
  %136 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s128.0, i64 noundef %s128.1, i64 noundef %s134.0, i64 noundef %s134.1)
  %s135.1 = extractvalue { i64, i64 } %135, 1
  %s135.0 = extractvalue { i64, i64 } %135, 0
  %s136.0 = extractvalue { i64, i64 } %136, 0
  %s136.1 = extractvalue { i64, i64 } %136, 1
; call <kernels::Fp2>::add
  %137 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s129.0, i64 noundef %s129.1, i64 noundef %s135.0, i64 noundef %s135.1)
  %s137.0 = extractvalue { i64, i64 } %137, 0
  %s137.1 = extractvalue { i64, i64 } %137, 1
  %_0.i198 = getelementptr inbounds nuw i8, ptr %raw, i64 288
  %s138.0 = load i64, ptr %_0.i198, align 8, !noundef !3
  %138 = getelementptr inbounds nuw i8, ptr %raw, i64 296
  %s138.1 = load i64, ptr %138, align 8, !noundef !3
  %_0.i197 = getelementptr inbounds nuw i8, ptr %raw, i64 304
  %s139.0 = load i64, ptr %_0.i197, align 8, !noundef !3
  %139 = getelementptr inbounds nuw i8, ptr %raw, i64 312
  %s139.1 = load i64, ptr %139, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %140 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s139.0, i64 noundef %s139.1, i64 noundef %s138.0, i64 noundef %s138.1)
  %s140.0 = extractvalue { i64, i64 } %140, 0
  %s140.1 = extractvalue { i64, i64 } %140, 1
  %_0.i196 = getelementptr inbounds nuw i8, ptr %params, i64 304
  %s141.0 = load i64, ptr %_0.i196, align 8, !noundef !3
  %141 = getelementptr inbounds nuw i8, ptr %params, i64 312
  %s141.1 = load i64, ptr %141, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %142 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s138.0, i64 noundef %s138.1, i64 noundef %s141.0, i64 noundef %s141.1)
; call <kernels::Fp2>::mul
  %143 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s140.0, i64 noundef %s140.1, i64 noundef %s141.0, i64 noundef %s141.1)
  %s142.1 = extractvalue { i64, i64 } %142, 1
  %s142.0 = extractvalue { i64, i64 } %142, 0
; call <kernels::Fp2>::add
  %144 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s136.0, i64 noundef %s136.1, i64 noundef %s142.0, i64 noundef %s142.1)
  %s143.1 = extractvalue { i64, i64 } %143, 1
  %s143.0 = extractvalue { i64, i64 } %143, 0
  %s144.0 = extractvalue { i64, i64 } %144, 0
  %s144.1 = extractvalue { i64, i64 } %144, 1
; call <kernels::Fp2>::add
  %145 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s137.0, i64 noundef %s137.1, i64 noundef %s143.0, i64 noundef %s143.1)
  %s145.0 = extractvalue { i64, i64 } %145, 0
  %s145.1 = extractvalue { i64, i64 } %145, 1
  %_0.i195 = getelementptr inbounds nuw i8, ptr %raw, i64 320
  %s146.0 = load i64, ptr %_0.i195, align 8, !noundef !3
  %146 = getelementptr inbounds nuw i8, ptr %raw, i64 328
  %s146.1 = load i64, ptr %146, align 8, !noundef !3
  %_0.i194 = getelementptr inbounds nuw i8, ptr %raw, i64 336
  %s147.0 = load i64, ptr %_0.i194, align 8, !noundef !3
  %147 = getelementptr inbounds nuw i8, ptr %raw, i64 344
  %s147.1 = load i64, ptr %147, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %148 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s147.0, i64 noundef %s147.1, i64 noundef %s146.0, i64 noundef %s146.1)
  %s148.0 = extractvalue { i64, i64 } %148, 0
  %s148.1 = extractvalue { i64, i64 } %148, 1
  %_0.i193 = getelementptr inbounds nuw i8, ptr %params, i64 320
  %s149.0 = load i64, ptr %_0.i193, align 8, !noundef !3
  %149 = getelementptr inbounds nuw i8, ptr %params, i64 328
  %s149.1 = load i64, ptr %149, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %150 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s146.0, i64 noundef %s146.1, i64 noundef %s149.0, i64 noundef %s149.1)
; call <kernels::Fp2>::mul
  %151 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s148.0, i64 noundef %s148.1, i64 noundef %s149.0, i64 noundef %s149.1)
  %s150.1 = extractvalue { i64, i64 } %150, 1
  %s150.0 = extractvalue { i64, i64 } %150, 0
; call <kernels::Fp2>::add
  %152 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s144.0, i64 noundef %s144.1, i64 noundef %s150.0, i64 noundef %s150.1)
  %s151.1 = extractvalue { i64, i64 } %151, 1
  %s151.0 = extractvalue { i64, i64 } %151, 0
  %s152.0 = extractvalue { i64, i64 } %152, 0
  %s152.1 = extractvalue { i64, i64 } %152, 1
; call <kernels::Fp2>::add
  %153 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s145.0, i64 noundef %s145.1, i64 noundef %s151.0, i64 noundef %s151.1)
  %s153.0 = extractvalue { i64, i64 } %153, 0
  %s153.1 = extractvalue { i64, i64 } %153, 1
  %_0.i192 = getelementptr inbounds nuw i8, ptr %raw, i64 352
  %s154.0 = load i64, ptr %_0.i192, align 8, !noundef !3
  %154 = getelementptr inbounds nuw i8, ptr %raw, i64 360
  %s154.1 = load i64, ptr %154, align 8, !noundef !3
  %_0.i191 = getelementptr inbounds nuw i8, ptr %raw, i64 368
  %s155.0 = load i64, ptr %_0.i191, align 8, !noundef !3
  %155 = getelementptr inbounds nuw i8, ptr %raw, i64 376
  %s155.1 = load i64, ptr %155, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %156 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s155.0, i64 noundef %s155.1, i64 noundef %s154.0, i64 noundef %s154.1)
  %s156.0 = extractvalue { i64, i64 } %156, 0
  %s156.1 = extractvalue { i64, i64 } %156, 1
  %_0.i190 = getelementptr inbounds nuw i8, ptr %params, i64 336
  %s157.0 = load i64, ptr %_0.i190, align 8, !noundef !3
  %157 = getelementptr inbounds nuw i8, ptr %params, i64 344
  %s157.1 = load i64, ptr %157, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %158 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s154.0, i64 noundef %s154.1, i64 noundef %s157.0, i64 noundef %s157.1)
; call <kernels::Fp2>::mul
  %159 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s156.0, i64 noundef %s156.1, i64 noundef %s157.0, i64 noundef %s157.1)
  %s158.1 = extractvalue { i64, i64 } %158, 1
  %s158.0 = extractvalue { i64, i64 } %158, 0
; call <kernels::Fp2>::add
  %160 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s152.0, i64 noundef %s152.1, i64 noundef %s158.0, i64 noundef %s158.1)
  %s159.1 = extractvalue { i64, i64 } %159, 1
  %s159.0 = extractvalue { i64, i64 } %159, 0
  %s160.0 = extractvalue { i64, i64 } %160, 0
  %s160.1 = extractvalue { i64, i64 } %160, 1
; call <kernels::Fp2>::add
  %161 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s153.0, i64 noundef %s153.1, i64 noundef %s159.0, i64 noundef %s159.1)
  %s161.0 = extractvalue { i64, i64 } %161, 0
  %s161.1 = extractvalue { i64, i64 } %161, 1
  %_0.i189 = getelementptr inbounds nuw i8, ptr %raw, i64 384
  %s162.0 = load i64, ptr %_0.i189, align 8, !noundef !3
  %162 = getelementptr inbounds nuw i8, ptr %raw, i64 392
  %s162.1 = load i64, ptr %162, align 8, !noundef !3
  %_0.i188 = getelementptr inbounds nuw i8, ptr %raw, i64 400
  %s163.0 = load i64, ptr %_0.i188, align 8, !noundef !3
  %163 = getelementptr inbounds nuw i8, ptr %raw, i64 408
  %s163.1 = load i64, ptr %163, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %164 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s163.0, i64 noundef %s163.1, i64 noundef %s162.0, i64 noundef %s162.1)
  %s164.0 = extractvalue { i64, i64 } %164, 0
  %s164.1 = extractvalue { i64, i64 } %164, 1
  %_0.i187 = getelementptr inbounds nuw i8, ptr %params, i64 352
  %s165.0 = load i64, ptr %_0.i187, align 8, !noundef !3
  %165 = getelementptr inbounds nuw i8, ptr %params, i64 360
  %s165.1 = load i64, ptr %165, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %166 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s162.0, i64 noundef %s162.1, i64 noundef %s165.0, i64 noundef %s165.1)
; call <kernels::Fp2>::mul
  %167 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s164.0, i64 noundef %s164.1, i64 noundef %s165.0, i64 noundef %s165.1)
  %s166.1 = extractvalue { i64, i64 } %166, 1
  %s166.0 = extractvalue { i64, i64 } %166, 0
; call <kernels::Fp2>::add
  %168 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s160.0, i64 noundef %s160.1, i64 noundef %s166.0, i64 noundef %s166.1)
  %s167.1 = extractvalue { i64, i64 } %167, 1
  %s167.0 = extractvalue { i64, i64 } %167, 0
  %s168.0 = extractvalue { i64, i64 } %168, 0
  %s168.1 = extractvalue { i64, i64 } %168, 1
; call <kernels::Fp2>::add
  %169 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s161.0, i64 noundef %s161.1, i64 noundef %s167.0, i64 noundef %s167.1)
  %s169.0 = extractvalue { i64, i64 } %169, 0
  %s169.1 = extractvalue { i64, i64 } %169, 1
  %_0.i186 = getelementptr inbounds nuw i8, ptr %raw, i64 416
  %s170.0 = load i64, ptr %_0.i186, align 8, !noundef !3
  %170 = getelementptr inbounds nuw i8, ptr %raw, i64 424
  %s170.1 = load i64, ptr %170, align 8, !noundef !3
  %_0.i185 = getelementptr inbounds nuw i8, ptr %raw, i64 432
  %s171.0 = load i64, ptr %_0.i185, align 8, !noundef !3
  %171 = getelementptr inbounds nuw i8, ptr %raw, i64 440
  %s171.1 = load i64, ptr %171, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %172 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s171.0, i64 noundef %s171.1, i64 noundef %s170.0, i64 noundef %s170.1)
  %s172.0 = extractvalue { i64, i64 } %172, 0
  %s172.1 = extractvalue { i64, i64 } %172, 1
  %_0.i184 = getelementptr inbounds nuw i8, ptr %params, i64 368
  %s173.0 = load i64, ptr %_0.i184, align 8, !noundef !3
  %173 = getelementptr inbounds nuw i8, ptr %params, i64 376
  %s173.1 = load i64, ptr %173, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %174 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s170.0, i64 noundef %s170.1, i64 noundef %s173.0, i64 noundef %s173.1)
; call <kernels::Fp2>::mul
  %175 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s172.0, i64 noundef %s172.1, i64 noundef %s173.0, i64 noundef %s173.1)
  %s174.1 = extractvalue { i64, i64 } %174, 1
  %s174.0 = extractvalue { i64, i64 } %174, 0
; call <kernels::Fp2>::add
  %176 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s168.0, i64 noundef %s168.1, i64 noundef %s174.0, i64 noundef %s174.1)
  %s175.1 = extractvalue { i64, i64 } %175, 1
  %s175.0 = extractvalue { i64, i64 } %175, 0
  %s176.0 = extractvalue { i64, i64 } %176, 0
  %s176.1 = extractvalue { i64, i64 } %176, 1
; call <kernels::Fp2>::add
  %177 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s169.0, i64 noundef %s169.1, i64 noundef %s175.0, i64 noundef %s175.1)
  %s177.0 = extractvalue { i64, i64 } %177, 0
  %s177.1 = extractvalue { i64, i64 } %177, 1
  %_0.i183 = getelementptr inbounds nuw i8, ptr %raw, i64 448
  %s178.0 = load i64, ptr %_0.i183, align 8, !noundef !3
  %178 = getelementptr inbounds nuw i8, ptr %raw, i64 456
  %s178.1 = load i64, ptr %178, align 8, !noundef !3
  %_0.i182 = getelementptr inbounds nuw i8, ptr %raw, i64 464
  %s179.0 = load i64, ptr %_0.i182, align 8, !noundef !3
  %179 = getelementptr inbounds nuw i8, ptr %raw, i64 472
  %s179.1 = load i64, ptr %179, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %180 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s179.0, i64 noundef %s179.1, i64 noundef %s178.0, i64 noundef %s178.1)
  %s180.0 = extractvalue { i64, i64 } %180, 0
  %s180.1 = extractvalue { i64, i64 } %180, 1
  %_0.i181 = getelementptr inbounds nuw i8, ptr %params, i64 384
  %s181.0 = load i64, ptr %_0.i181, align 8, !noundef !3
  %181 = getelementptr inbounds nuw i8, ptr %params, i64 392
  %s181.1 = load i64, ptr %181, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %182 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s178.0, i64 noundef %s178.1, i64 noundef %s181.0, i64 noundef %s181.1)
; call <kernels::Fp2>::mul
  %183 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s180.0, i64 noundef %s180.1, i64 noundef %s181.0, i64 noundef %s181.1)
  %s182.1 = extractvalue { i64, i64 } %182, 1
  %s182.0 = extractvalue { i64, i64 } %182, 0
; call <kernels::Fp2>::add
  %184 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s176.0, i64 noundef %s176.1, i64 noundef %s182.0, i64 noundef %s182.1)
  %s183.1 = extractvalue { i64, i64 } %183, 1
  %s183.0 = extractvalue { i64, i64 } %183, 0
  %s184.0 = extractvalue { i64, i64 } %184, 0
  %s184.1 = extractvalue { i64, i64 } %184, 1
; call <kernels::Fp2>::add
  %185 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s177.0, i64 noundef %s177.1, i64 noundef %s183.0, i64 noundef %s183.1)
  %s185.0 = extractvalue { i64, i64 } %185, 0
  %s185.1 = extractvalue { i64, i64 } %185, 1
  %_0.i180 = getelementptr inbounds nuw i8, ptr %raw, i64 480
  %s186.0 = load i64, ptr %_0.i180, align 8, !noundef !3
  %186 = getelementptr inbounds nuw i8, ptr %raw, i64 488
  %s186.1 = load i64, ptr %186, align 8, !noundef !3
  %_0.i179 = getelementptr inbounds nuw i8, ptr %raw, i64 496
  %s187.0 = load i64, ptr %_0.i179, align 8, !noundef !3
  %187 = getelementptr inbounds nuw i8, ptr %raw, i64 504
  %s187.1 = load i64, ptr %187, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %188 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s187.0, i64 noundef %s187.1, i64 noundef %s186.0, i64 noundef %s186.1)
  %s188.0 = extractvalue { i64, i64 } %188, 0
  %s188.1 = extractvalue { i64, i64 } %188, 1
  %_0.i178 = getelementptr inbounds nuw i8, ptr %params, i64 400
  %s189.0 = load i64, ptr %_0.i178, align 8, !noundef !3
  %189 = getelementptr inbounds nuw i8, ptr %params, i64 408
  %s189.1 = load i64, ptr %189, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %190 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s186.0, i64 noundef %s186.1, i64 noundef %s189.0, i64 noundef %s189.1)
; call <kernels::Fp2>::mul
  %191 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s188.0, i64 noundef %s188.1, i64 noundef %s189.0, i64 noundef %s189.1)
  %s190.1 = extractvalue { i64, i64 } %190, 1
  %s190.0 = extractvalue { i64, i64 } %190, 0
; call <kernels::Fp2>::add
  %192 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s184.0, i64 noundef %s184.1, i64 noundef %s190.0, i64 noundef %s190.1)
  %s191.1 = extractvalue { i64, i64 } %191, 1
  %s191.0 = extractvalue { i64, i64 } %191, 0
  %s192.0 = extractvalue { i64, i64 } %192, 0
  %s192.1 = extractvalue { i64, i64 } %192, 1
; call <kernels::Fp2>::add
  %193 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s185.0, i64 noundef %s185.1, i64 noundef %s191.0, i64 noundef %s191.1)
  %s193.0 = extractvalue { i64, i64 } %193, 0
  %s193.1 = extractvalue { i64, i64 } %193, 1
  %_0.i177 = getelementptr inbounds nuw i8, ptr %raw, i64 512
  %s194.0 = load i64, ptr %_0.i177, align 8, !noundef !3
  %194 = getelementptr inbounds nuw i8, ptr %raw, i64 520
  %s194.1 = load i64, ptr %194, align 8, !noundef !3
  %_0.i176 = getelementptr inbounds nuw i8, ptr %raw, i64 528
  %s195.0 = load i64, ptr %_0.i176, align 8, !noundef !3
  %195 = getelementptr inbounds nuw i8, ptr %raw, i64 536
  %s195.1 = load i64, ptr %195, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %196 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s195.0, i64 noundef %s195.1, i64 noundef %s194.0, i64 noundef %s194.1)
  %s196.0 = extractvalue { i64, i64 } %196, 0
  %s196.1 = extractvalue { i64, i64 } %196, 1
  %_0.i175 = getelementptr inbounds nuw i8, ptr %params, i64 416
  %s197.0 = load i64, ptr %_0.i175, align 8, !noundef !3
  %197 = getelementptr inbounds nuw i8, ptr %params, i64 424
  %s197.1 = load i64, ptr %197, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %198 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s194.0, i64 noundef %s194.1, i64 noundef %s197.0, i64 noundef %s197.1)
; call <kernels::Fp2>::mul
  %199 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s196.0, i64 noundef %s196.1, i64 noundef %s197.0, i64 noundef %s197.1)
  %s198.1 = extractvalue { i64, i64 } %198, 1
  %s198.0 = extractvalue { i64, i64 } %198, 0
; call <kernels::Fp2>::add
  %200 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s192.0, i64 noundef %s192.1, i64 noundef %s198.0, i64 noundef %s198.1)
  %s199.1 = extractvalue { i64, i64 } %199, 1
  %s199.0 = extractvalue { i64, i64 } %199, 0
  %s200.0 = extractvalue { i64, i64 } %200, 0
  %s200.1 = extractvalue { i64, i64 } %200, 1
; call <kernels::Fp2>::add
  %201 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s193.0, i64 noundef %s193.1, i64 noundef %s199.0, i64 noundef %s199.1)
  %s201.0 = extractvalue { i64, i64 } %201, 0
  %s201.1 = extractvalue { i64, i64 } %201, 1
  %_0.i174 = getelementptr inbounds nuw i8, ptr %raw, i64 800
  %s202.0 = load i64, ptr %_0.i174, align 8, !noundef !3
  %202 = getelementptr inbounds nuw i8, ptr %raw, i64 808
  %s202.1 = load i64, ptr %202, align 8, !noundef !3
  %_0.i173 = getelementptr inbounds nuw i8, ptr %raw, i64 816
  %s203.0 = load i64, ptr %_0.i173, align 8, !noundef !3
  %203 = getelementptr inbounds nuw i8, ptr %raw, i64 824
  %s203.1 = load i64, ptr %203, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %204 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s203.0, i64 noundef %s203.1, i64 noundef %s202.0, i64 noundef %s202.1)
  %s204.0 = extractvalue { i64, i64 } %204, 0
  %s204.1 = extractvalue { i64, i64 } %204, 1
  %_0.i172 = getelementptr inbounds nuw i8, ptr %params, i64 432
  %s205.0 = load i64, ptr %_0.i172, align 8, !noundef !3
  %205 = getelementptr inbounds nuw i8, ptr %params, i64 440
  %s205.1 = load i64, ptr %205, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %206 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s202.0, i64 noundef %s202.1, i64 noundef %s205.0, i64 noundef %s205.1)
; call <kernels::Fp2>::mul
  %207 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s204.0, i64 noundef %s204.1, i64 noundef %s205.0, i64 noundef %s205.1)
  %s206.1 = extractvalue { i64, i64 } %206, 1
  %s206.0 = extractvalue { i64, i64 } %206, 0
; call <kernels::Fp2>::add
  %208 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s200.0, i64 noundef %s200.1, i64 noundef %s206.0, i64 noundef %s206.1)
  %s207.1 = extractvalue { i64, i64 } %207, 1
  %s207.0 = extractvalue { i64, i64 } %207, 0
  %s208.0 = extractvalue { i64, i64 } %208, 0
  %s208.1 = extractvalue { i64, i64 } %208, 1
; call <kernels::Fp2>::add
  %209 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s201.0, i64 noundef %s201.1, i64 noundef %s207.0, i64 noundef %s207.1)
  %s209.0 = extractvalue { i64, i64 } %209, 0
  %s209.1 = extractvalue { i64, i64 } %209, 1
  %_0.i171 = getelementptr inbounds nuw i8, ptr %raw, i64 832
  %s210.0 = load i64, ptr %_0.i171, align 8, !noundef !3
  %210 = getelementptr inbounds nuw i8, ptr %raw, i64 840
  %s210.1 = load i64, ptr %210, align 8, !noundef !3
  %_0.i170 = getelementptr inbounds nuw i8, ptr %raw, i64 848
  %s211.0 = load i64, ptr %_0.i170, align 8, !noundef !3
  %211 = getelementptr inbounds nuw i8, ptr %raw, i64 856
  %s211.1 = load i64, ptr %211, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %212 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s211.0, i64 noundef %s211.1, i64 noundef %s210.0, i64 noundef %s210.1)
  %s212.0 = extractvalue { i64, i64 } %212, 0
  %s212.1 = extractvalue { i64, i64 } %212, 1
  %_0.i169 = getelementptr inbounds nuw i8, ptr %params, i64 448
  %s213.0 = load i64, ptr %_0.i169, align 8, !noundef !3
  %213 = getelementptr inbounds nuw i8, ptr %params, i64 456
  %s213.1 = load i64, ptr %213, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %214 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s210.0, i64 noundef %s210.1, i64 noundef %s213.0, i64 noundef %s213.1)
; call <kernels::Fp2>::mul
  %215 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s212.0, i64 noundef %s212.1, i64 noundef %s213.0, i64 noundef %s213.1)
  %s214.1 = extractvalue { i64, i64 } %214, 1
  %s214.0 = extractvalue { i64, i64 } %214, 0
; call <kernels::Fp2>::add
  %216 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s208.0, i64 noundef %s208.1, i64 noundef %s214.0, i64 noundef %s214.1)
  %s215.1 = extractvalue { i64, i64 } %215, 1
  %s215.0 = extractvalue { i64, i64 } %215, 0
  %s216.0 = extractvalue { i64, i64 } %216, 0
  %s216.1 = extractvalue { i64, i64 } %216, 1
; call <kernels::Fp2>::add
  %217 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s209.0, i64 noundef %s209.1, i64 noundef %s215.0, i64 noundef %s215.1)
  %s217.0 = extractvalue { i64, i64 } %217, 0
  %s217.1 = extractvalue { i64, i64 } %217, 1
  %_0.i168 = getelementptr inbounds nuw i8, ptr %raw, i64 864
  %s218.0 = load i64, ptr %_0.i168, align 8, !noundef !3
  %218 = getelementptr inbounds nuw i8, ptr %raw, i64 872
  %s218.1 = load i64, ptr %218, align 8, !noundef !3
  %_0.i167 = getelementptr inbounds nuw i8, ptr %raw, i64 880
  %s219.0 = load i64, ptr %_0.i167, align 8, !noundef !3
  %219 = getelementptr inbounds nuw i8, ptr %raw, i64 888
  %s219.1 = load i64, ptr %219, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %220 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s219.0, i64 noundef %s219.1, i64 noundef %s218.0, i64 noundef %s218.1)
  %s220.0 = extractvalue { i64, i64 } %220, 0
  %s220.1 = extractvalue { i64, i64 } %220, 1
  %_0.i166 = getelementptr inbounds nuw i8, ptr %params, i64 464
  %s221.0 = load i64, ptr %_0.i166, align 8, !noundef !3
  %221 = getelementptr inbounds nuw i8, ptr %params, i64 472
  %s221.1 = load i64, ptr %221, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %222 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s218.0, i64 noundef %s218.1, i64 noundef %s221.0, i64 noundef %s221.1)
; call <kernels::Fp2>::mul
  %223 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s220.0, i64 noundef %s220.1, i64 noundef %s221.0, i64 noundef %s221.1)
  %s222.1 = extractvalue { i64, i64 } %222, 1
  %s222.0 = extractvalue { i64, i64 } %222, 0
; call <kernels::Fp2>::add
  %224 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s216.0, i64 noundef %s216.1, i64 noundef %s222.0, i64 noundef %s222.1)
  %s223.1 = extractvalue { i64, i64 } %223, 1
  %s223.0 = extractvalue { i64, i64 } %223, 0
  %s224.0 = extractvalue { i64, i64 } %224, 0
  %s224.1 = extractvalue { i64, i64 } %224, 1
; call <kernels::Fp2>::add
  %225 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s217.0, i64 noundef %s217.1, i64 noundef %s223.0, i64 noundef %s223.1)
  %s225.0 = extractvalue { i64, i64 } %225, 0
  %s225.1 = extractvalue { i64, i64 } %225, 1
  %_0.i165 = getelementptr inbounds nuw i8, ptr %raw, i64 896
  %s226.0 = load i64, ptr %_0.i165, align 8, !noundef !3
  %226 = getelementptr inbounds nuw i8, ptr %raw, i64 904
  %s226.1 = load i64, ptr %226, align 8, !noundef !3
  %_0.i164 = getelementptr inbounds nuw i8, ptr %raw, i64 912
  %s227.0 = load i64, ptr %_0.i164, align 8, !noundef !3
  %227 = getelementptr inbounds nuw i8, ptr %raw, i64 920
  %s227.1 = load i64, ptr %227, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %228 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s227.0, i64 noundef %s227.1, i64 noundef %s226.0, i64 noundef %s226.1)
  %s228.0 = extractvalue { i64, i64 } %228, 0
  %s228.1 = extractvalue { i64, i64 } %228, 1
  %_0.i163 = getelementptr inbounds nuw i8, ptr %params, i64 480
  %s229.0 = load i64, ptr %_0.i163, align 8, !noundef !3
  %229 = getelementptr inbounds nuw i8, ptr %params, i64 488
  %s229.1 = load i64, ptr %229, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %230 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s226.0, i64 noundef %s226.1, i64 noundef %s229.0, i64 noundef %s229.1)
; call <kernels::Fp2>::mul
  %231 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s228.0, i64 noundef %s228.1, i64 noundef %s229.0, i64 noundef %s229.1)
  %s230.1 = extractvalue { i64, i64 } %230, 1
  %s230.0 = extractvalue { i64, i64 } %230, 0
; call <kernels::Fp2>::add
  %232 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s224.0, i64 noundef %s224.1, i64 noundef %s230.0, i64 noundef %s230.1)
  %s231.1 = extractvalue { i64, i64 } %231, 1
  %s231.0 = extractvalue { i64, i64 } %231, 0
  %s232.0 = extractvalue { i64, i64 } %232, 0
  %s232.1 = extractvalue { i64, i64 } %232, 1
; call <kernels::Fp2>::add
  %233 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s225.0, i64 noundef %s225.1, i64 noundef %s231.0, i64 noundef %s231.1)
  %s233.0 = extractvalue { i64, i64 } %233, 0
  %s233.1 = extractvalue { i64, i64 } %233, 1
  %_0.i162 = getelementptr inbounds nuw i8, ptr %raw, i64 928
  %s234.0 = load i64, ptr %_0.i162, align 8, !noundef !3
  %234 = getelementptr inbounds nuw i8, ptr %raw, i64 936
  %s234.1 = load i64, ptr %234, align 8, !noundef !3
  %_0.i161 = getelementptr inbounds nuw i8, ptr %raw, i64 944
  %s235.0 = load i64, ptr %_0.i161, align 8, !noundef !3
  %235 = getelementptr inbounds nuw i8, ptr %raw, i64 952
  %s235.1 = load i64, ptr %235, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %236 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s235.0, i64 noundef %s235.1, i64 noundef %s234.0, i64 noundef %s234.1)
  %s236.0 = extractvalue { i64, i64 } %236, 0
  %s236.1 = extractvalue { i64, i64 } %236, 1
  %_0.i160 = getelementptr inbounds nuw i8, ptr %params, i64 496
  %s237.0 = load i64, ptr %_0.i160, align 8, !noundef !3
  %237 = getelementptr inbounds nuw i8, ptr %params, i64 504
  %s237.1 = load i64, ptr %237, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %238 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s234.0, i64 noundef %s234.1, i64 noundef %s237.0, i64 noundef %s237.1)
; call <kernels::Fp2>::mul
  %239 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s236.0, i64 noundef %s236.1, i64 noundef %s237.0, i64 noundef %s237.1)
  %s238.1 = extractvalue { i64, i64 } %238, 1
  %s238.0 = extractvalue { i64, i64 } %238, 0
; call <kernels::Fp2>::add
  %240 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s232.0, i64 noundef %s232.1, i64 noundef %s238.0, i64 noundef %s238.1)
  %s239.1 = extractvalue { i64, i64 } %239, 1
  %s239.0 = extractvalue { i64, i64 } %239, 0
  %s240.0 = extractvalue { i64, i64 } %240, 0
  %s240.1 = extractvalue { i64, i64 } %240, 1
; call <kernels::Fp2>::add
  %241 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s233.0, i64 noundef %s233.1, i64 noundef %s239.0, i64 noundef %s239.1)
  %s241.0 = extractvalue { i64, i64 } %241, 0
  %s241.1 = extractvalue { i64, i64 } %241, 1
  %_0.i159 = getelementptr inbounds nuw i8, ptr %raw, i64 960
  %s242.0 = load i64, ptr %_0.i159, align 8, !noundef !3
  %242 = getelementptr inbounds nuw i8, ptr %raw, i64 968
  %s242.1 = load i64, ptr %242, align 8, !noundef !3
  %_0.i158 = getelementptr inbounds nuw i8, ptr %raw, i64 976
  %s243.0 = load i64, ptr %_0.i158, align 8, !noundef !3
  %243 = getelementptr inbounds nuw i8, ptr %raw, i64 984
  %s243.1 = load i64, ptr %243, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %244 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s243.0, i64 noundef %s243.1, i64 noundef %s242.0, i64 noundef %s242.1)
  %s244.0 = extractvalue { i64, i64 } %244, 0
  %s244.1 = extractvalue { i64, i64 } %244, 1
  %_0.i157 = getelementptr inbounds nuw i8, ptr %params, i64 512
  %s245.0 = load i64, ptr %_0.i157, align 8, !noundef !3
  %245 = getelementptr inbounds nuw i8, ptr %params, i64 520
  %s245.1 = load i64, ptr %245, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %246 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s242.0, i64 noundef %s242.1, i64 noundef %s245.0, i64 noundef %s245.1)
; call <kernels::Fp2>::mul
  %247 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s244.0, i64 noundef %s244.1, i64 noundef %s245.0, i64 noundef %s245.1)
  %s246.1 = extractvalue { i64, i64 } %246, 1
  %s246.0 = extractvalue { i64, i64 } %246, 0
; call <kernels::Fp2>::add
  %248 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s240.0, i64 noundef %s240.1, i64 noundef %s246.0, i64 noundef %s246.1)
  %s247.1 = extractvalue { i64, i64 } %247, 1
  %s247.0 = extractvalue { i64, i64 } %247, 0
  %s248.0 = extractvalue { i64, i64 } %248, 0
  %s248.1 = extractvalue { i64, i64 } %248, 1
; call <kernels::Fp2>::add
  %249 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s241.0, i64 noundef %s241.1, i64 noundef %s247.0, i64 noundef %s247.1)
  %s249.0 = extractvalue { i64, i64 } %249, 0
  %s249.1 = extractvalue { i64, i64 } %249, 1
  %_0.i156 = getelementptr inbounds nuw i8, ptr %raw, i64 992
  %s250.0 = load i64, ptr %_0.i156, align 8, !noundef !3
  %250 = getelementptr inbounds nuw i8, ptr %raw, i64 1000
  %s250.1 = load i64, ptr %250, align 8, !noundef !3
  %_0.i155 = getelementptr inbounds nuw i8, ptr %raw, i64 1008
  %s251.0 = load i64, ptr %_0.i155, align 8, !noundef !3
  %251 = getelementptr inbounds nuw i8, ptr %raw, i64 1016
  %s251.1 = load i64, ptr %251, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %252 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s251.0, i64 noundef %s251.1, i64 noundef %s250.0, i64 noundef %s250.1)
  %s252.0 = extractvalue { i64, i64 } %252, 0
  %s252.1 = extractvalue { i64, i64 } %252, 1
  %_0.i154 = getelementptr inbounds nuw i8, ptr %params, i64 528
  %s253.0 = load i64, ptr %_0.i154, align 8, !noundef !3
  %253 = getelementptr inbounds nuw i8, ptr %params, i64 536
  %s253.1 = load i64, ptr %253, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %254 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s250.0, i64 noundef %s250.1, i64 noundef %s253.0, i64 noundef %s253.1)
; call <kernels::Fp2>::mul
  %255 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s252.0, i64 noundef %s252.1, i64 noundef %s253.0, i64 noundef %s253.1)
  %s254.1 = extractvalue { i64, i64 } %254, 1
  %s254.0 = extractvalue { i64, i64 } %254, 0
; call <kernels::Fp2>::add
  %256 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s248.0, i64 noundef %s248.1, i64 noundef %s254.0, i64 noundef %s254.1)
  %s255.1 = extractvalue { i64, i64 } %255, 1
  %s255.0 = extractvalue { i64, i64 } %255, 0
  %s256.0 = extractvalue { i64, i64 } %256, 0
  %s256.1 = extractvalue { i64, i64 } %256, 1
; call <kernels::Fp2>::add
  %257 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s249.0, i64 noundef %s249.1, i64 noundef %s255.0, i64 noundef %s255.1)
  %s257.0 = extractvalue { i64, i64 } %257, 0
  %s257.1 = extractvalue { i64, i64 } %257, 1
  %_0.i153 = getelementptr inbounds nuw i8, ptr %raw, i64 1024
  %s258.0 = load i64, ptr %_0.i153, align 8, !noundef !3
  %258 = getelementptr inbounds nuw i8, ptr %raw, i64 1032
  %s258.1 = load i64, ptr %258, align 8, !noundef !3
  %_0.i152 = getelementptr inbounds nuw i8, ptr %raw, i64 1040
  %s259.0 = load i64, ptr %_0.i152, align 8, !noundef !3
  %259 = getelementptr inbounds nuw i8, ptr %raw, i64 1048
  %s259.1 = load i64, ptr %259, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %260 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s259.0, i64 noundef %s259.1, i64 noundef %s258.0, i64 noundef %s258.1)
  %s260.0 = extractvalue { i64, i64 } %260, 0
  %s260.1 = extractvalue { i64, i64 } %260, 1
  %_0.i151 = getelementptr inbounds nuw i8, ptr %params, i64 544
  %s261.0 = load i64, ptr %_0.i151, align 8, !noundef !3
  %261 = getelementptr inbounds nuw i8, ptr %params, i64 552
  %s261.1 = load i64, ptr %261, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %262 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s258.0, i64 noundef %s258.1, i64 noundef %s261.0, i64 noundef %s261.1)
; call <kernels::Fp2>::mul
  %263 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s260.0, i64 noundef %s260.1, i64 noundef %s261.0, i64 noundef %s261.1)
  %s262.1 = extractvalue { i64, i64 } %262, 1
  %s262.0 = extractvalue { i64, i64 } %262, 0
; call <kernels::Fp2>::add
  %264 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s256.0, i64 noundef %s256.1, i64 noundef %s262.0, i64 noundef %s262.1)
  %s263.1 = extractvalue { i64, i64 } %263, 1
  %s263.0 = extractvalue { i64, i64 } %263, 0
  %s264.0 = extractvalue { i64, i64 } %264, 0
  %s264.1 = extractvalue { i64, i64 } %264, 1
; call <kernels::Fp2>::add
  %265 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s257.0, i64 noundef %s257.1, i64 noundef %s263.0, i64 noundef %s263.1)
  %s265.0 = extractvalue { i64, i64 } %265, 0
  %s265.1 = extractvalue { i64, i64 } %265, 1
  %_0.i150 = getelementptr inbounds nuw i8, ptr %raw, i64 96
  %s266.0 = load i64, ptr %_0.i150, align 8, !noundef !3
  %266 = getelementptr inbounds nuw i8, ptr %raw, i64 104
  %s266.1 = load i64, ptr %266, align 8, !noundef !3
  %_0.i149 = getelementptr inbounds nuw i8, ptr %raw, i64 112
  %s267.0 = load i64, ptr %_0.i149, align 8, !noundef !3
  %267 = getelementptr inbounds nuw i8, ptr %raw, i64 120
  %s267.1 = load i64, ptr %267, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %268 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s267.0, i64 noundef %s267.1, i64 noundef %s266.0, i64 noundef %s266.1)
  %s268.0 = extractvalue { i64, i64 } %268, 0
  %s268.1 = extractvalue { i64, i64 } %268, 1
; call <kernels::Fp2>::mul
  %269 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s266.0, i64 noundef %s266.1, i64 noundef %s2.0, i64 noundef %s2.1)
  %s269.0 = extractvalue { i64, i64 } %269, 0
  %s269.1 = extractvalue { i64, i64 } %269, 1
; call <kernels::Fp2>::mul
  %270 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s268.0, i64 noundef %s268.1, i64 noundef %s4.0, i64 noundef %s4.1)
  %s270.0 = extractvalue { i64, i64 } %270, 0
  %s270.1 = extractvalue { i64, i64 } %270, 1
; call <kernels::Fp2>::add
  %271 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s266.0, i64 noundef %s266.1, i64 noundef %s268.0, i64 noundef %s268.1)
; call <kernels::Fp2>::add
  %272 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s2.0, i64 noundef %s2.1, i64 noundef %s4.0, i64 noundef %s4.1)
  %s271.1 = extractvalue { i64, i64 } %271, 1
  %s271.0 = extractvalue { i64, i64 } %271, 0
  %s272.0 = extractvalue { i64, i64 } %272, 0
  %s272.1 = extractvalue { i64, i64 } %272, 1
; call <kernels::Fp2>::mul
  %273 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s271.0, i64 noundef %s271.1, i64 noundef %s272.0, i64 noundef %s272.1)
  %s273.0 = extractvalue { i64, i64 } %273, 0
  %s273.1 = extractvalue { i64, i64 } %273, 1
; call <kernels::Fp2>::sub
  %274 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s273.0, i64 noundef %s273.1, i64 noundef %s269.0, i64 noundef %s269.1)
  %s274.0 = extractvalue { i64, i64 } %274, 0
  %s274.1 = extractvalue { i64, i64 } %274, 1
; call <kernels::Fp2>::sub
  %275 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s274.0, i64 noundef %s274.1, i64 noundef %s270.0, i64 noundef %s270.1)
  %s275.0 = extractvalue { i64, i64 } %275, 0
  %s275.1 = extractvalue { i64, i64 } %275, 1
  %_0.i148 = getelementptr inbounds nuw i8, ptr %params, i64 560
  %s276.0 = load i64, ptr %_0.i148, align 8, !noundef !3
  %276 = getelementptr inbounds nuw i8, ptr %params, i64 568
  %s276.1 = load i64, ptr %276, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %277 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s269.0, i64 noundef %s269.1, i64 noundef %s276.0, i64 noundef %s276.1)
  %s277.0 = extractvalue { i64, i64 } %277, 0
  %s277.1 = extractvalue { i64, i64 } %277, 1
; call <kernels::Fp2>::mul
  %278 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s275.0, i64 noundef %s275.1, i64 noundef %s276.0, i64 noundef %s276.1)
  %s278.0 = extractvalue { i64, i64 } %278, 0
  %s278.1 = extractvalue { i64, i64 } %278, 1
; call <kernels::Fp2>::mul
  %279 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s270.0, i64 noundef %s270.1, i64 noundef %s276.0, i64 noundef %s276.1)
  %s279.0 = extractvalue { i64, i64 } %279, 0
  %s279.1 = extractvalue { i64, i64 } %279, 1
; call <kernels::Fp2>::add
  %280 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s264.0, i64 noundef %s264.1, i64 noundef %s277.0, i64 noundef %s277.1)
  %s280.0 = extractvalue { i64, i64 } %280, 0
  %s280.1 = extractvalue { i64, i64 } %280, 1
; call <kernels::Fp2>::add
  %281 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s265.0, i64 noundef %s265.1, i64 noundef %s278.0, i64 noundef %s278.1)
  %s281.0 = extractvalue { i64, i64 } %281, 0
  %s281.1 = extractvalue { i64, i64 } %281, 1
  %_0.i147 = getelementptr inbounds nuw i8, ptr %raw, i64 256
  %s282.0 = load i64, ptr %_0.i147, align 8, !noundef !3
  %282 = getelementptr inbounds nuw i8, ptr %raw, i64 264
  %s282.1 = load i64, ptr %282, align 8, !noundef !3
  %_0.i146 = getelementptr inbounds nuw i8, ptr %raw, i64 272
  %s283.0 = load i64, ptr %_0.i146, align 8, !noundef !3
  %283 = getelementptr inbounds nuw i8, ptr %raw, i64 280
  %s283.1 = load i64, ptr %283, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %284 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s283.0, i64 noundef %s283.1, i64 noundef %s282.0, i64 noundef %s282.1)
  %s284.0 = extractvalue { i64, i64 } %284, 0
  %s284.1 = extractvalue { i64, i64 } %284, 1
; call <kernels::Fp2>::mul
  %285 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s42.0, i64 noundef %s42.1, i64 noundef %s282.0, i64 noundef %s282.1)
  %s285.0 = extractvalue { i64, i64 } %285, 0
  %s285.1 = extractvalue { i64, i64 } %285, 1
; call <kernels::Fp2>::mul
  %286 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s44.0, i64 noundef %s44.1, i64 noundef %s284.0, i64 noundef %s284.1)
  %s286.0 = extractvalue { i64, i64 } %286, 0
  %s286.1 = extractvalue { i64, i64 } %286, 1
; call <kernels::Fp2>::add
  %287 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s42.0, i64 noundef %s42.1, i64 noundef %s44.0, i64 noundef %s44.1)
; call <kernels::Fp2>::add
  %288 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s282.0, i64 noundef %s282.1, i64 noundef %s284.0, i64 noundef %s284.1)
  %s287.1 = extractvalue { i64, i64 } %287, 1
  %s287.0 = extractvalue { i64, i64 } %287, 0
  %s288.0 = extractvalue { i64, i64 } %288, 0
  %s288.1 = extractvalue { i64, i64 } %288, 1
; call <kernels::Fp2>::mul
  %289 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s287.0, i64 noundef %s287.1, i64 noundef %s288.0, i64 noundef %s288.1)
  %s289.0 = extractvalue { i64, i64 } %289, 0
  %s289.1 = extractvalue { i64, i64 } %289, 1
; call <kernels::Fp2>::sub
  %290 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s289.0, i64 noundef %s289.1, i64 noundef %s285.0, i64 noundef %s285.1)
  %s290.0 = extractvalue { i64, i64 } %290, 0
  %s290.1 = extractvalue { i64, i64 } %290, 1
; call <kernels::Fp2>::sub
  %291 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s290.0, i64 noundef %s290.1, i64 noundef %s286.0, i64 noundef %s286.1)
  %s291.0 = extractvalue { i64, i64 } %291, 0
  %s291.1 = extractvalue { i64, i64 } %291, 1
  %_0.i145 = getelementptr inbounds nuw i8, ptr %params, i64 576
  %s292.0 = load i64, ptr %_0.i145, align 8, !noundef !3
  %292 = getelementptr inbounds nuw i8, ptr %params, i64 584
  %s292.1 = load i64, ptr %292, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %293 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s285.0, i64 noundef %s285.1, i64 noundef %s292.0, i64 noundef %s292.1)
  %s293.0 = extractvalue { i64, i64 } %293, 0
  %s293.1 = extractvalue { i64, i64 } %293, 1
; call <kernels::Fp2>::mul
  %294 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s291.0, i64 noundef %s291.1, i64 noundef %s292.0, i64 noundef %s292.1)
  %s294.0 = extractvalue { i64, i64 } %294, 0
  %s294.1 = extractvalue { i64, i64 } %294, 1
; call <kernels::Fp2>::mul
  %295 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s286.0, i64 noundef %s286.1, i64 noundef %s292.0, i64 noundef %s292.1)
  %s295.0 = extractvalue { i64, i64 } %295, 0
  %s295.1 = extractvalue { i64, i64 } %295, 1
; call <kernels::Fp2>::add
  %296 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s280.0, i64 noundef %s280.1, i64 noundef %s293.0, i64 noundef %s293.1)
  %s296.0 = extractvalue { i64, i64 } %296, 0
  %s296.1 = extractvalue { i64, i64 } %296, 1
; call <kernels::Fp2>::add
  %297 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s281.0, i64 noundef %s281.1, i64 noundef %s294.0, i64 noundef %s294.1)
  %s297.0 = extractvalue { i64, i64 } %297, 0
  %s297.1 = extractvalue { i64, i64 } %297, 1
; call <kernels::Fp2>::add
  %298 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s279.0, i64 noundef %s279.1, i64 noundef %s295.0, i64 noundef %s295.1)
  %s298.0 = extractvalue { i64, i64 } %298, 0
  %s298.1 = extractvalue { i64, i64 } %298, 1
  %_0.i144 = getelementptr inbounds nuw i8, ptr %raw, i64 128
  %s299.0 = load i64, ptr %_0.i144, align 8, !noundef !3
  %299 = getelementptr inbounds nuw i8, ptr %raw, i64 136
  %s299.1 = load i64, ptr %299, align 8, !noundef !3
  %_0.i143 = getelementptr inbounds nuw i8, ptr %raw, i64 144
  %s300.0 = load i64, ptr %_0.i143, align 8, !noundef !3
  %300 = getelementptr inbounds nuw i8, ptr %raw, i64 152
  %s300.1 = load i64, ptr %300, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %301 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s300.0, i64 noundef %s300.1, i64 noundef %s299.0, i64 noundef %s299.1)
  %s301.0 = extractvalue { i64, i64 } %301, 0
  %s301.1 = extractvalue { i64, i64 } %301, 1
; call <kernels::Fp2>::mul
  %302 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s299.0, i64 noundef %s299.1, i64 noundef %s18.0, i64 noundef %s18.1)
  %s302.0 = extractvalue { i64, i64 } %302, 0
  %s302.1 = extractvalue { i64, i64 } %302, 1
; call <kernels::Fp2>::mul
  %303 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s301.0, i64 noundef %s301.1, i64 noundef %s20.0, i64 noundef %s20.1)
  %s303.0 = extractvalue { i64, i64 } %303, 0
  %s303.1 = extractvalue { i64, i64 } %303, 1
; call <kernels::Fp2>::add
  %304 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s299.0, i64 noundef %s299.1, i64 noundef %s301.0, i64 noundef %s301.1)
; call <kernels::Fp2>::add
  %305 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s18.0, i64 noundef %s18.1, i64 noundef %s20.0, i64 noundef %s20.1)
  %s304.1 = extractvalue { i64, i64 } %304, 1
  %s304.0 = extractvalue { i64, i64 } %304, 0
  %s305.0 = extractvalue { i64, i64 } %305, 0
  %s305.1 = extractvalue { i64, i64 } %305, 1
; call <kernels::Fp2>::mul
  %306 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s304.0, i64 noundef %s304.1, i64 noundef %s305.0, i64 noundef %s305.1)
  %s306.0 = extractvalue { i64, i64 } %306, 0
  %s306.1 = extractvalue { i64, i64 } %306, 1
; call <kernels::Fp2>::sub
  %307 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s306.0, i64 noundef %s306.1, i64 noundef %s302.0, i64 noundef %s302.1)
  %s307.0 = extractvalue { i64, i64 } %307, 0
  %s307.1 = extractvalue { i64, i64 } %307, 1
; call <kernels::Fp2>::sub
  %308 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s307.0, i64 noundef %s307.1, i64 noundef %s303.0, i64 noundef %s303.1)
  %s308.0 = extractvalue { i64, i64 } %308, 0
  %s308.1 = extractvalue { i64, i64 } %308, 1
  %_0.i142 = getelementptr inbounds nuw i8, ptr %params, i64 592
  %s309.0 = load i64, ptr %_0.i142, align 8, !noundef !3
  %309 = getelementptr inbounds nuw i8, ptr %params, i64 600
  %s309.1 = load i64, ptr %309, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %310 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s302.0, i64 noundef %s302.1, i64 noundef %s309.0, i64 noundef %s309.1)
  %s310.0 = extractvalue { i64, i64 } %310, 0
  %s310.1 = extractvalue { i64, i64 } %310, 1
; call <kernels::Fp2>::mul
  %311 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s308.0, i64 noundef %s308.1, i64 noundef %s309.0, i64 noundef %s309.1)
  %s311.0 = extractvalue { i64, i64 } %311, 0
  %s311.1 = extractvalue { i64, i64 } %311, 1
; call <kernels::Fp2>::mul
  %312 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s303.0, i64 noundef %s303.1, i64 noundef %s309.0, i64 noundef %s309.1)
  %s312.0 = extractvalue { i64, i64 } %312, 0
  %s312.1 = extractvalue { i64, i64 } %312, 1
; call <kernels::Fp2>::add
  %313 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s296.0, i64 noundef %s296.1, i64 noundef %s310.0, i64 noundef %s310.1)
  %s313.0 = extractvalue { i64, i64 } %313, 0
  %s313.1 = extractvalue { i64, i64 } %313, 1
; call <kernels::Fp2>::add
  %314 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s297.0, i64 noundef %s297.1, i64 noundef %s311.0, i64 noundef %s311.1)
  %s314.0 = extractvalue { i64, i64 } %314, 0
  %s314.1 = extractvalue { i64, i64 } %314, 1
; call <kernels::Fp2>::add
  %315 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s298.0, i64 noundef %s298.1, i64 noundef %s312.0, i64 noundef %s312.1)
  %s315.0 = extractvalue { i64, i64 } %315, 0
  %s315.1 = extractvalue { i64, i64 } %315, 1
  %_0.i141 = getelementptr inbounds nuw i8, ptr %raw, i64 768
  %s316.0 = load i64, ptr %_0.i141, align 8, !noundef !3
  %316 = getelementptr inbounds nuw i8, ptr %raw, i64 776
  %s316.1 = load i64, ptr %316, align 8, !noundef !3
  %_0.i140 = getelementptr inbounds nuw i8, ptr %raw, i64 784
  %s317.0 = load i64, ptr %_0.i140, align 8, !noundef !3
  %317 = getelementptr inbounds nuw i8, ptr %raw, i64 792
  %s317.1 = load i64, ptr %317, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %318 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s317.0, i64 noundef %s317.1, i64 noundef %s316.0, i64 noundef %s316.1)
  %s318.0 = extractvalue { i64, i64 } %318, 0
  %s318.1 = extractvalue { i64, i64 } %318, 1
; call <kernels::Fp2>::mul
  %319 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s50.0, i64 noundef %s50.1, i64 noundef %s316.0, i64 noundef %s316.1)
  %s319.0 = extractvalue { i64, i64 } %319, 0
  %s319.1 = extractvalue { i64, i64 } %319, 1
; call <kernels::Fp2>::mul
  %320 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s52.0, i64 noundef %s52.1, i64 noundef %s318.0, i64 noundef %s318.1)
  %s320.0 = extractvalue { i64, i64 } %320, 0
  %s320.1 = extractvalue { i64, i64 } %320, 1
; call <kernels::Fp2>::add
  %321 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s50.0, i64 noundef %s50.1, i64 noundef %s52.0, i64 noundef %s52.1)
; call <kernels::Fp2>::add
  %322 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s316.0, i64 noundef %s316.1, i64 noundef %s318.0, i64 noundef %s318.1)
  %s321.1 = extractvalue { i64, i64 } %321, 1
  %s321.0 = extractvalue { i64, i64 } %321, 0
  %s322.0 = extractvalue { i64, i64 } %322, 0
  %s322.1 = extractvalue { i64, i64 } %322, 1
; call <kernels::Fp2>::mul
  %323 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s321.0, i64 noundef %s321.1, i64 noundef %s322.0, i64 noundef %s322.1)
  %s323.0 = extractvalue { i64, i64 } %323, 0
  %s323.1 = extractvalue { i64, i64 } %323, 1
; call <kernels::Fp2>::sub
  %324 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s323.0, i64 noundef %s323.1, i64 noundef %s319.0, i64 noundef %s319.1)
  %s324.0 = extractvalue { i64, i64 } %324, 0
  %s324.1 = extractvalue { i64, i64 } %324, 1
; call <kernels::Fp2>::sub
  %325 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s324.0, i64 noundef %s324.1, i64 noundef %s320.0, i64 noundef %s320.1)
  %s325.0 = extractvalue { i64, i64 } %325, 0
  %s325.1 = extractvalue { i64, i64 } %325, 1
  %_0.i139 = getelementptr inbounds nuw i8, ptr %params, i64 608
  %s326.0 = load i64, ptr %_0.i139, align 8, !noundef !3
  %326 = getelementptr inbounds nuw i8, ptr %params, i64 616
  %s326.1 = load i64, ptr %326, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %327 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s319.0, i64 noundef %s319.1, i64 noundef %s326.0, i64 noundef %s326.1)
  %s327.0 = extractvalue { i64, i64 } %327, 0
  %s327.1 = extractvalue { i64, i64 } %327, 1
; call <kernels::Fp2>::mul
  %328 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s325.0, i64 noundef %s325.1, i64 noundef %s326.0, i64 noundef %s326.1)
  %s328.0 = extractvalue { i64, i64 } %328, 0
  %s328.1 = extractvalue { i64, i64 } %328, 1
; call <kernels::Fp2>::mul
  %329 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s320.0, i64 noundef %s320.1, i64 noundef %s326.0, i64 noundef %s326.1)
  %s329.0 = extractvalue { i64, i64 } %329, 0
  %s329.1 = extractvalue { i64, i64 } %329, 1
; call <kernels::Fp2>::add
  %330 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s313.0, i64 noundef %s313.1, i64 noundef %s327.0, i64 noundef %s327.1)
  %s330.0 = extractvalue { i64, i64 } %330, 0
  %s330.1 = extractvalue { i64, i64 } %330, 1
; call <kernels::Fp2>::add
  %331 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s314.0, i64 noundef %s314.1, i64 noundef %s328.0, i64 noundef %s328.1)
  %s331.0 = extractvalue { i64, i64 } %331, 0
  %s331.1 = extractvalue { i64, i64 } %331, 1
; call <kernels::Fp2>::add
  %332 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s315.0, i64 noundef %s315.1, i64 noundef %s329.0, i64 noundef %s329.1)
  %s332.0 = extractvalue { i64, i64 } %332, 0
  %s332.1 = extractvalue { i64, i64 } %332, 1
  %_0.i138 = getelementptr inbounds nuw i8, ptr %params, i64 624
  %s333.0 = load i64, ptr %_0.i138, align 8, !noundef !3
  %333 = getelementptr inbounds nuw i8, ptr %params, i64 632
  %s333.1 = load i64, ptr %333, align 8, !noundef !3
  %_0.i137 = getelementptr inbounds nuw i8, ptr %params, i64 640
  %s334.0 = load i64, ptr %_0.i137, align 8, !noundef !3
  %334 = getelementptr inbounds nuw i8, ptr %params, i64 648
  %s334.1 = load i64, ptr %334, align 8, !noundef !3
  %s335 = load i64, ptr %bases, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %335 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s58.0, i64 noundef %s58.1, i64 noundef %s335)
; call <kernels::Fp2>::mul_base
  %336 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s60.0, i64 noundef %s60.1, i64 noundef %s335)
  %s336.1 = extractvalue { i64, i64 } %335, 1
  %s336.0 = extractvalue { i64, i64 } %335, 0
  %s337.0 = extractvalue { i64, i64 } %336, 0
  %s337.1 = extractvalue { i64, i64 } %336, 1
; call <kernels::Fp2>::sub
  %337 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s334.0, i64 noundef %s334.1, i64 noundef %s336.0, i64 noundef %s336.1)
  %s338.0 = extractvalue { i64, i64 } %337, 0
  %s338.1 = extractvalue { i64, i64 } %337, 1
  %_0.i136 = getelementptr inbounds nuw i8, ptr %params, i64 656
  %s339.0 = load i64, ptr %_0.i136, align 8, !noundef !3
  %338 = getelementptr inbounds nuw i8, ptr %params, i64 664
  %s339.1 = load i64, ptr %338, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %339 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s339.0, i64 noundef %s339.1, i64 noundef %s337.0, i64 noundef %s337.1)
  %s340.0 = extractvalue { i64, i64 } %339, 0
  %s340.1 = extractvalue { i64, i64 } %339, 1
  %_0.i135 = getelementptr inbounds nuw i8, ptr %params, i64 672
  %s341.0 = load i64, ptr %_0.i135, align 8, !noundef !3
  %340 = getelementptr inbounds nuw i8, ptr %params, i64 680
  %s341.1 = load i64, ptr %340, align 8, !noundef !3
  %_0.i286 = getelementptr inbounds nuw i8, ptr %bases, i64 8
  %s342 = load i64, ptr %_0.i286, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %341 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s66.0, i64 noundef %s66.1, i64 noundef %s342)
; call <kernels::Fp2>::mul_base
  %342 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s68.0, i64 noundef %s68.1, i64 noundef %s342)
  %s343.1 = extractvalue { i64, i64 } %341, 1
  %s343.0 = extractvalue { i64, i64 } %341, 0
  %s344.0 = extractvalue { i64, i64 } %342, 0
  %s344.1 = extractvalue { i64, i64 } %342, 1
; call <kernels::Fp2>::sub
  %343 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s341.0, i64 noundef %s341.1, i64 noundef %s343.0, i64 noundef %s343.1)
  %s345.0 = extractvalue { i64, i64 } %343, 0
  %s345.1 = extractvalue { i64, i64 } %343, 1
  %_0.i134 = getelementptr inbounds nuw i8, ptr %params, i64 688
  %s346.0 = load i64, ptr %_0.i134, align 8, !noundef !3
  %344 = getelementptr inbounds nuw i8, ptr %params, i64 696
  %s346.1 = load i64, ptr %344, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %345 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s346.0, i64 noundef %s346.1, i64 noundef %s344.0, i64 noundef %s344.1)
  %s347.0 = extractvalue { i64, i64 } %345, 0
  %s347.1 = extractvalue { i64, i64 } %345, 1
  %_0.i133 = getelementptr inbounds nuw i8, ptr %raw, i64 1344
  %s348.0 = load i64, ptr %_0.i133, align 8, !noundef !3
  %346 = getelementptr inbounds nuw i8, ptr %raw, i64 1352
  %s348.1 = load i64, ptr %346, align 8, !noundef !3
  %_0.i132 = getelementptr inbounds nuw i8, ptr %raw, i64 1360
  %s349.0 = load i64, ptr %_0.i132, align 8, !noundef !3
  %347 = getelementptr inbounds nuw i8, ptr %raw, i64 1368
  %s349.1 = load i64, ptr %347, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %348 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s349.0, i64 noundef %s349.1, i64 noundef %s348.0, i64 noundef %s348.1)
  %s350.0 = extractvalue { i64, i64 } %348, 0
  %s350.1 = extractvalue { i64, i64 } %348, 1
; call <kernels::Fp2>::mul
  %349 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s348.0, i64 noundef %s348.1, i64 noundef %s338.0, i64 noundef %s338.1)
  %s351.0 = extractvalue { i64, i64 } %349, 0
  %s351.1 = extractvalue { i64, i64 } %349, 1
; call <kernels::Fp2>::mul
  %350 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s350.0, i64 noundef %s350.1, i64 noundef %s340.0, i64 noundef %s340.1)
  %s352.0 = extractvalue { i64, i64 } %350, 0
  %s352.1 = extractvalue { i64, i64 } %350, 1
; call <kernels::Fp2>::add
  %351 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s348.0, i64 noundef %s348.1, i64 noundef %s350.0, i64 noundef %s350.1)
; call <kernels::Fp2>::add
  %352 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s338.0, i64 noundef %s338.1, i64 noundef %s340.0, i64 noundef %s340.1)
  %s353.1 = extractvalue { i64, i64 } %351, 1
  %s353.0 = extractvalue { i64, i64 } %351, 0
  %s354.0 = extractvalue { i64, i64 } %352, 0
  %s354.1 = extractvalue { i64, i64 } %352, 1
; call <kernels::Fp2>::mul
  %353 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s353.0, i64 noundef %s353.1, i64 noundef %s354.0, i64 noundef %s354.1)
  %s355.0 = extractvalue { i64, i64 } %353, 0
  %s355.1 = extractvalue { i64, i64 } %353, 1
; call <kernels::Fp2>::sub
  %354 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s355.0, i64 noundef %s355.1, i64 noundef %s351.0, i64 noundef %s351.1)
  %s356.0 = extractvalue { i64, i64 } %354, 0
  %s356.1 = extractvalue { i64, i64 } %354, 1
; call <kernels::Fp2>::sub
  %355 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s356.0, i64 noundef %s356.1, i64 noundef %s352.0, i64 noundef %s352.1)
  %s357.0 = extractvalue { i64, i64 } %355, 0
  %s357.1 = extractvalue { i64, i64 } %355, 1
; call <kernels::Fp2>::mul
  %356 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s351.0, i64 noundef %s351.1, i64 noundef %s345.0, i64 noundef %s345.1)
  %s358.0 = extractvalue { i64, i64 } %356, 0
  %s358.1 = extractvalue { i64, i64 } %356, 1
; call <kernels::Fp2>::mul
  %357 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s351.0, i64 noundef %s351.1, i64 noundef %s347.0, i64 noundef %s347.1)
; call <kernels::Fp2>::mul
  %358 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s357.0, i64 noundef %s357.1, i64 noundef %s345.0, i64 noundef %s345.1)
  %s359.1 = extractvalue { i64, i64 } %357, 1
  %s359.0 = extractvalue { i64, i64 } %357, 0
  %s360.0 = extractvalue { i64, i64 } %358, 0
  %s360.1 = extractvalue { i64, i64 } %358, 1
; call <kernels::Fp2>::add
  %359 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s359.0, i64 noundef %s359.1, i64 noundef %s360.0, i64 noundef %s360.1)
  %s361.0 = extractvalue { i64, i64 } %359, 0
  %s361.1 = extractvalue { i64, i64 } %359, 1
; call <kernels::Fp2>::mul
  %360 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s357.0, i64 noundef %s357.1, i64 noundef %s347.0, i64 noundef %s347.1)
; call <kernels::Fp2>::mul
  %361 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s352.0, i64 noundef %s352.1, i64 noundef %s345.0, i64 noundef %s345.1)
  %s362.1 = extractvalue { i64, i64 } %360, 1
  %s362.0 = extractvalue { i64, i64 } %360, 0
  %s363.0 = extractvalue { i64, i64 } %361, 0
  %s363.1 = extractvalue { i64, i64 } %361, 1
; call <kernels::Fp2>::add
  %362 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s362.0, i64 noundef %s362.1, i64 noundef %s363.0, i64 noundef %s363.1)
  %s364.0 = extractvalue { i64, i64 } %362, 0
  %s364.1 = extractvalue { i64, i64 } %362, 1
; call <kernels::Fp2>::mul
  %363 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s352.0, i64 noundef %s352.1, i64 noundef %s347.0, i64 noundef %s347.1)
  %s365.0 = extractvalue { i64, i64 } %363, 0
  %s365.1 = extractvalue { i64, i64 } %363, 1
; call <kernels::Fp2>::add
  %364 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s338.0, i64 noundef %s338.1, i64 noundef %s345.0, i64 noundef %s345.1)
; call <kernels::Fp2>::add
  %365 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s340.0, i64 noundef %s340.1, i64 noundef %s347.0, i64 noundef %s347.1)
  %s366.1 = extractvalue { i64, i64 } %364, 1
  %s366.0 = extractvalue { i64, i64 } %364, 0
; call <kernels::Fp2>::sub
  %366 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s358.0, i64 noundef %s358.1, i64 noundef %s366.0, i64 noundef %s366.1)
  %s367.1 = extractvalue { i64, i64 } %365, 1
  %s367.0 = extractvalue { i64, i64 } %365, 0
  %s368.0 = extractvalue { i64, i64 } %366, 0
  %s368.1 = extractvalue { i64, i64 } %366, 1
; call <kernels::Fp2>::sub
  %367 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s361.0, i64 noundef %s361.1, i64 noundef %s367.0, i64 noundef %s367.1)
  %s369.0 = extractvalue { i64, i64 } %367, 0
  %s369.1 = extractvalue { i64, i64 } %367, 1
  %_0.i131 = getelementptr inbounds nuw i8, ptr %params, i64 704
  %s370.0 = load i64, ptr %_0.i131, align 8, !noundef !3
  %368 = getelementptr inbounds nuw i8, ptr %params, i64 712
  %s370.1 = load i64, ptr %368, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %369 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s368.0, i64 noundef %s368.1, i64 noundef %s370.0, i64 noundef %s370.1)
  %s371.0 = extractvalue { i64, i64 } %369, 0
  %s371.1 = extractvalue { i64, i64 } %369, 1
; call <kernels::Fp2>::mul
  %370 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s369.0, i64 noundef %s369.1, i64 noundef %s370.0, i64 noundef %s370.1)
  %s372.0 = extractvalue { i64, i64 } %370, 0
  %s372.1 = extractvalue { i64, i64 } %370, 1
; call <kernels::Fp2>::mul
  %371 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s364.0, i64 noundef %s364.1, i64 noundef %s370.0, i64 noundef %s370.1)
  %s373.0 = extractvalue { i64, i64 } %371, 0
  %s373.1 = extractvalue { i64, i64 } %371, 1
; call <kernels::Fp2>::mul
  %372 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s365.0, i64 noundef %s365.1, i64 noundef %s370.0, i64 noundef %s370.1)
  %s374.0 = extractvalue { i64, i64 } %372, 0
  %s374.1 = extractvalue { i64, i64 } %372, 1
; call <kernels::Fp2>::add
  %373 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s333.0, i64 noundef %s333.1, i64 noundef %s371.0, i64 noundef %s371.1)
  %s375.0 = extractvalue { i64, i64 } %373, 0
  %s375.1 = extractvalue { i64, i64 } %373, 1
  %_0.i130 = getelementptr inbounds nuw i8, ptr %params, i64 720
  %s376.0 = load i64, ptr %_0.i130, align 8, !noundef !3
  %374 = getelementptr inbounds nuw i8, ptr %params, i64 728
  %s376.1 = load i64, ptr %374, align 8, !noundef !3
  %_0.i285 = getelementptr inbounds nuw i8, ptr %bases, i64 16
  %s377 = load i64, ptr %_0.i285, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %375 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s282.0, i64 noundef %s282.1, i64 noundef %s377)
; call <kernels::Fp2>::mul_base
  %376 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s284.0, i64 noundef %s284.1, i64 noundef %s377)
  %s378.1 = extractvalue { i64, i64 } %375, 1
  %s378.0 = extractvalue { i64, i64 } %375, 0
  %s379.0 = extractvalue { i64, i64 } %376, 0
  %s379.1 = extractvalue { i64, i64 } %376, 1
; call <kernels::Fp2>::sub
  %377 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s376.0, i64 noundef %s376.1, i64 noundef %s378.0, i64 noundef %s378.1)
  %s380.0 = extractvalue { i64, i64 } %377, 0
  %s380.1 = extractvalue { i64, i64 } %377, 1
  %_0.i129 = getelementptr inbounds nuw i8, ptr %params, i64 736
  %s381.0 = load i64, ptr %_0.i129, align 8, !noundef !3
  %378 = getelementptr inbounds nuw i8, ptr %params, i64 744
  %s381.1 = load i64, ptr %378, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %379 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s381.0, i64 noundef %s381.1, i64 noundef %s379.0, i64 noundef %s379.1)
  %s382.0 = extractvalue { i64, i64 } %379, 0
  %s382.1 = extractvalue { i64, i64 } %379, 1
  %_0.i128 = getelementptr inbounds nuw i8, ptr %params, i64 752
  %s383.0 = load i64, ptr %_0.i128, align 8, !noundef !3
  %380 = getelementptr inbounds nuw i8, ptr %params, i64 760
  %s383.1 = load i64, ptr %380, align 8, !noundef !3
  %_0.i284 = getelementptr inbounds nuw i8, ptr %bases, i64 24
  %s384 = load i64, ptr %_0.i284, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %381 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s282.0, i64 noundef %s282.1, i64 noundef %s384)
; call <kernels::Fp2>::mul_base
  %382 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s284.0, i64 noundef %s284.1, i64 noundef %s384)
  %s385.1 = extractvalue { i64, i64 } %381, 1
  %s385.0 = extractvalue { i64, i64 } %381, 0
  %s386.0 = extractvalue { i64, i64 } %382, 0
  %s386.1 = extractvalue { i64, i64 } %382, 1
; call <kernels::Fp2>::sub
  %383 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s383.0, i64 noundef %s383.1, i64 noundef %s385.0, i64 noundef %s385.1)
  %s387.0 = extractvalue { i64, i64 } %383, 0
  %s387.1 = extractvalue { i64, i64 } %383, 1
  %_0.i127 = getelementptr inbounds nuw i8, ptr %params, i64 768
  %s388.0 = load i64, ptr %_0.i127, align 8, !noundef !3
  %384 = getelementptr inbounds nuw i8, ptr %params, i64 776
  %s388.1 = load i64, ptr %384, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %385 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s388.0, i64 noundef %s388.1, i64 noundef %s386.0, i64 noundef %s386.1)
  %s389.0 = extractvalue { i64, i64 } %385, 0
  %s389.1 = extractvalue { i64, i64 } %385, 1
  %_0.i126 = getelementptr inbounds nuw i8, ptr %raw, i64 1376
  %s390.0 = load i64, ptr %_0.i126, align 8, !noundef !3
  %386 = getelementptr inbounds nuw i8, ptr %raw, i64 1384
  %s390.1 = load i64, ptr %386, align 8, !noundef !3
  %_0.i125 = getelementptr inbounds nuw i8, ptr %raw, i64 1392
  %s391.0 = load i64, ptr %_0.i125, align 8, !noundef !3
  %387 = getelementptr inbounds nuw i8, ptr %raw, i64 1400
  %s391.1 = load i64, ptr %387, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %388 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s391.0, i64 noundef %s391.1, i64 noundef %s390.0, i64 noundef %s390.1)
  %s392.0 = extractvalue { i64, i64 } %388, 0
  %s392.1 = extractvalue { i64, i64 } %388, 1
; call <kernels::Fp2>::mul
  %389 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s390.0, i64 noundef %s390.1, i64 noundef %s380.0, i64 noundef %s380.1)
  %s393.0 = extractvalue { i64, i64 } %389, 0
  %s393.1 = extractvalue { i64, i64 } %389, 1
; call <kernels::Fp2>::mul
  %390 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s392.0, i64 noundef %s392.1, i64 noundef %s382.0, i64 noundef %s382.1)
  %s394.0 = extractvalue { i64, i64 } %390, 0
  %s394.1 = extractvalue { i64, i64 } %390, 1
; call <kernels::Fp2>::add
  %391 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s390.0, i64 noundef %s390.1, i64 noundef %s392.0, i64 noundef %s392.1)
; call <kernels::Fp2>::add
  %392 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s380.0, i64 noundef %s380.1, i64 noundef %s382.0, i64 noundef %s382.1)
  %s395.1 = extractvalue { i64, i64 } %391, 1
  %s395.0 = extractvalue { i64, i64 } %391, 0
  %s396.0 = extractvalue { i64, i64 } %392, 0
  %s396.1 = extractvalue { i64, i64 } %392, 1
; call <kernels::Fp2>::mul
  %393 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s395.0, i64 noundef %s395.1, i64 noundef %s396.0, i64 noundef %s396.1)
  %s397.0 = extractvalue { i64, i64 } %393, 0
  %s397.1 = extractvalue { i64, i64 } %393, 1
; call <kernels::Fp2>::sub
  %394 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s397.0, i64 noundef %s397.1, i64 noundef %s393.0, i64 noundef %s393.1)
  %s398.0 = extractvalue { i64, i64 } %394, 0
  %s398.1 = extractvalue { i64, i64 } %394, 1
; call <kernels::Fp2>::sub
  %395 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s398.0, i64 noundef %s398.1, i64 noundef %s394.0, i64 noundef %s394.1)
  %s399.0 = extractvalue { i64, i64 } %395, 0
  %s399.1 = extractvalue { i64, i64 } %395, 1
; call <kernels::Fp2>::mul
  %396 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s393.0, i64 noundef %s393.1, i64 noundef %s387.0, i64 noundef %s387.1)
  %s400.0 = extractvalue { i64, i64 } %396, 0
  %s400.1 = extractvalue { i64, i64 } %396, 1
; call <kernels::Fp2>::mul
  %397 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s393.0, i64 noundef %s393.1, i64 noundef %s389.0, i64 noundef %s389.1)
; call <kernels::Fp2>::mul
  %398 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s399.0, i64 noundef %s399.1, i64 noundef %s387.0, i64 noundef %s387.1)
  %s401.1 = extractvalue { i64, i64 } %397, 1
  %s401.0 = extractvalue { i64, i64 } %397, 0
  %s402.0 = extractvalue { i64, i64 } %398, 0
  %s402.1 = extractvalue { i64, i64 } %398, 1
; call <kernels::Fp2>::add
  %399 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s401.0, i64 noundef %s401.1, i64 noundef %s402.0, i64 noundef %s402.1)
  %s403.0 = extractvalue { i64, i64 } %399, 0
  %s403.1 = extractvalue { i64, i64 } %399, 1
; call <kernels::Fp2>::mul
  %400 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s399.0, i64 noundef %s399.1, i64 noundef %s389.0, i64 noundef %s389.1)
; call <kernels::Fp2>::mul
  %401 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s394.0, i64 noundef %s394.1, i64 noundef %s387.0, i64 noundef %s387.1)
  %s404.1 = extractvalue { i64, i64 } %400, 1
  %s404.0 = extractvalue { i64, i64 } %400, 0
  %s405.0 = extractvalue { i64, i64 } %401, 0
  %s405.1 = extractvalue { i64, i64 } %401, 1
; call <kernels::Fp2>::add
  %402 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s404.0, i64 noundef %s404.1, i64 noundef %s405.0, i64 noundef %s405.1)
  %s406.0 = extractvalue { i64, i64 } %402, 0
  %s406.1 = extractvalue { i64, i64 } %402, 1
; call <kernels::Fp2>::mul
  %403 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s394.0, i64 noundef %s394.1, i64 noundef %s389.0, i64 noundef %s389.1)
  %s407.0 = extractvalue { i64, i64 } %403, 0
  %s407.1 = extractvalue { i64, i64 } %403, 1
; call <kernels::Fp2>::add
  %404 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s380.0, i64 noundef %s380.1, i64 noundef %s387.0, i64 noundef %s387.1)
; call <kernels::Fp2>::add
  %405 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s382.0, i64 noundef %s382.1, i64 noundef %s389.0, i64 noundef %s389.1)
  %s408.1 = extractvalue { i64, i64 } %404, 1
  %s408.0 = extractvalue { i64, i64 } %404, 0
; call <kernels::Fp2>::sub
  %406 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s400.0, i64 noundef %s400.1, i64 noundef %s408.0, i64 noundef %s408.1)
  %s409.1 = extractvalue { i64, i64 } %405, 1
  %s409.0 = extractvalue { i64, i64 } %405, 0
  %s410.0 = extractvalue { i64, i64 } %406, 0
  %s410.1 = extractvalue { i64, i64 } %406, 1
; call <kernels::Fp2>::sub
  %407 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s403.0, i64 noundef %s403.1, i64 noundef %s409.0, i64 noundef %s409.1)
  %s411.0 = extractvalue { i64, i64 } %407, 0
  %s411.1 = extractvalue { i64, i64 } %407, 1
  %_0.i124 = getelementptr inbounds nuw i8, ptr %params, i64 784
  %s412.0 = load i64, ptr %_0.i124, align 8, !noundef !3
  %408 = getelementptr inbounds nuw i8, ptr %params, i64 792
  %s412.1 = load i64, ptr %408, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %409 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s410.0, i64 noundef %s410.1, i64 noundef %s412.0, i64 noundef %s412.1)
  %s413.0 = extractvalue { i64, i64 } %409, 0
  %s413.1 = extractvalue { i64, i64 } %409, 1
; call <kernels::Fp2>::mul
  %410 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s411.0, i64 noundef %s411.1, i64 noundef %s412.0, i64 noundef %s412.1)
  %s414.0 = extractvalue { i64, i64 } %410, 0
  %s414.1 = extractvalue { i64, i64 } %410, 1
; call <kernels::Fp2>::mul
  %411 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s406.0, i64 noundef %s406.1, i64 noundef %s412.0, i64 noundef %s412.1)
  %s415.0 = extractvalue { i64, i64 } %411, 0
  %s415.1 = extractvalue { i64, i64 } %411, 1
; call <kernels::Fp2>::mul
  %412 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s407.0, i64 noundef %s407.1, i64 noundef %s412.0, i64 noundef %s412.1)
  %s416.0 = extractvalue { i64, i64 } %412, 0
  %s416.1 = extractvalue { i64, i64 } %412, 1
; call <kernels::Fp2>::add
  %413 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s375.0, i64 noundef %s375.1, i64 noundef %s413.0, i64 noundef %s413.1)
  %s417.0 = extractvalue { i64, i64 } %413, 0
  %s417.1 = extractvalue { i64, i64 } %413, 1
; call <kernels::Fp2>::add
  %414 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s372.0, i64 noundef %s372.1, i64 noundef %s414.0, i64 noundef %s414.1)
  %s418.0 = extractvalue { i64, i64 } %414, 0
  %s418.1 = extractvalue { i64, i64 } %414, 1
; call <kernels::Fp2>::add
  %415 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s373.0, i64 noundef %s373.1, i64 noundef %s415.0, i64 noundef %s415.1)
  %s419.0 = extractvalue { i64, i64 } %415, 0
  %s419.1 = extractvalue { i64, i64 } %415, 1
; call <kernels::Fp2>::add
  %416 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s374.0, i64 noundef %s374.1, i64 noundef %s416.0, i64 noundef %s416.1)
  %s420.0 = extractvalue { i64, i64 } %416, 0
  %s420.1 = extractvalue { i64, i64 } %416, 1
  %_0.i123 = getelementptr inbounds nuw i8, ptr %params, i64 800
  %s421.0 = load i64, ptr %_0.i123, align 8, !noundef !3
  %417 = getelementptr inbounds nuw i8, ptr %params, i64 808
  %s421.1 = load i64, ptr %417, align 8, !noundef !3
  %_0.i283 = getelementptr inbounds nuw i8, ptr %bases, i64 32
  %s422 = load i64, ptr %_0.i283, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %418 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s138.0, i64 noundef %s138.1, i64 noundef %s422)
; call <kernels::Fp2>::mul_base
  %419 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s140.0, i64 noundef %s140.1, i64 noundef %s422)
  %s423.1 = extractvalue { i64, i64 } %418, 1
  %s423.0 = extractvalue { i64, i64 } %418, 0
  %s424.0 = extractvalue { i64, i64 } %419, 0
  %s424.1 = extractvalue { i64, i64 } %419, 1
; call <kernels::Fp2>::sub
  %420 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s421.0, i64 noundef %s421.1, i64 noundef %s423.0, i64 noundef %s423.1)
  %s425.0 = extractvalue { i64, i64 } %420, 0
  %s425.1 = extractvalue { i64, i64 } %420, 1
  %_0.i122 = getelementptr inbounds nuw i8, ptr %params, i64 816
  %s426.0 = load i64, ptr %_0.i122, align 8, !noundef !3
  %421 = getelementptr inbounds nuw i8, ptr %params, i64 824
  %s426.1 = load i64, ptr %421, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %422 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s426.0, i64 noundef %s426.1, i64 noundef %s424.0, i64 noundef %s424.1)
  %s427.0 = extractvalue { i64, i64 } %422, 0
  %s427.1 = extractvalue { i64, i64 } %422, 1
  %_0.i121 = getelementptr inbounds nuw i8, ptr %params, i64 832
  %s428.0 = load i64, ptr %_0.i121, align 8, !noundef !3
  %423 = getelementptr inbounds nuw i8, ptr %params, i64 840
  %s428.1 = load i64, ptr %423, align 8, !noundef !3
  %_0.i282 = getelementptr inbounds nuw i8, ptr %bases, i64 40
  %s429 = load i64, ptr %_0.i282, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %424 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s146.0, i64 noundef %s146.1, i64 noundef %s429)
; call <kernels::Fp2>::mul_base
  %425 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s148.0, i64 noundef %s148.1, i64 noundef %s429)
  %s430.1 = extractvalue { i64, i64 } %424, 1
  %s430.0 = extractvalue { i64, i64 } %424, 0
  %s431.0 = extractvalue { i64, i64 } %425, 0
  %s431.1 = extractvalue { i64, i64 } %425, 1
; call <kernels::Fp2>::sub
  %426 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s428.0, i64 noundef %s428.1, i64 noundef %s430.0, i64 noundef %s430.1)
  %s432.0 = extractvalue { i64, i64 } %426, 0
  %s432.1 = extractvalue { i64, i64 } %426, 1
  %_0.i120 = getelementptr inbounds nuw i8, ptr %params, i64 848
  %s433.0 = load i64, ptr %_0.i120, align 8, !noundef !3
  %427 = getelementptr inbounds nuw i8, ptr %params, i64 856
  %s433.1 = load i64, ptr %427, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %428 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s433.0, i64 noundef %s433.1, i64 noundef %s431.0, i64 noundef %s431.1)
  %s434.0 = extractvalue { i64, i64 } %428, 0
  %s434.1 = extractvalue { i64, i64 } %428, 1
  %_0.i119 = getelementptr inbounds nuw i8, ptr %raw, i64 1408
  %s435.0 = load i64, ptr %_0.i119, align 8, !noundef !3
  %429 = getelementptr inbounds nuw i8, ptr %raw, i64 1416
  %s435.1 = load i64, ptr %429, align 8, !noundef !3
  %_0.i118 = getelementptr inbounds nuw i8, ptr %raw, i64 1424
  %s436.0 = load i64, ptr %_0.i118, align 8, !noundef !3
  %430 = getelementptr inbounds nuw i8, ptr %raw, i64 1432
  %s436.1 = load i64, ptr %430, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %431 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s436.0, i64 noundef %s436.1, i64 noundef %s435.0, i64 noundef %s435.1)
  %s437.0 = extractvalue { i64, i64 } %431, 0
  %s437.1 = extractvalue { i64, i64 } %431, 1
; call <kernels::Fp2>::mul
  %432 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s435.0, i64 noundef %s435.1, i64 noundef %s425.0, i64 noundef %s425.1)
  %s438.0 = extractvalue { i64, i64 } %432, 0
  %s438.1 = extractvalue { i64, i64 } %432, 1
; call <kernels::Fp2>::mul
  %433 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s437.0, i64 noundef %s437.1, i64 noundef %s427.0, i64 noundef %s427.1)
  %s439.0 = extractvalue { i64, i64 } %433, 0
  %s439.1 = extractvalue { i64, i64 } %433, 1
; call <kernels::Fp2>::add
  %434 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s435.0, i64 noundef %s435.1, i64 noundef %s437.0, i64 noundef %s437.1)
; call <kernels::Fp2>::add
  %435 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s425.0, i64 noundef %s425.1, i64 noundef %s427.0, i64 noundef %s427.1)
  %s440.1 = extractvalue { i64, i64 } %434, 1
  %s440.0 = extractvalue { i64, i64 } %434, 0
  %s441.0 = extractvalue { i64, i64 } %435, 0
  %s441.1 = extractvalue { i64, i64 } %435, 1
; call <kernels::Fp2>::mul
  %436 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s440.0, i64 noundef %s440.1, i64 noundef %s441.0, i64 noundef %s441.1)
  %s442.0 = extractvalue { i64, i64 } %436, 0
  %s442.1 = extractvalue { i64, i64 } %436, 1
; call <kernels::Fp2>::sub
  %437 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s442.0, i64 noundef %s442.1, i64 noundef %s438.0, i64 noundef %s438.1)
  %s443.0 = extractvalue { i64, i64 } %437, 0
  %s443.1 = extractvalue { i64, i64 } %437, 1
; call <kernels::Fp2>::sub
  %438 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s443.0, i64 noundef %s443.1, i64 noundef %s439.0, i64 noundef %s439.1)
  %s444.0 = extractvalue { i64, i64 } %438, 0
  %s444.1 = extractvalue { i64, i64 } %438, 1
; call <kernels::Fp2>::mul
  %439 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s438.0, i64 noundef %s438.1, i64 noundef %s432.0, i64 noundef %s432.1)
  %s445.0 = extractvalue { i64, i64 } %439, 0
  %s445.1 = extractvalue { i64, i64 } %439, 1
; call <kernels::Fp2>::mul
  %440 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s438.0, i64 noundef %s438.1, i64 noundef %s434.0, i64 noundef %s434.1)
; call <kernels::Fp2>::mul
  %441 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s444.0, i64 noundef %s444.1, i64 noundef %s432.0, i64 noundef %s432.1)
  %s446.1 = extractvalue { i64, i64 } %440, 1
  %s446.0 = extractvalue { i64, i64 } %440, 0
  %s447.0 = extractvalue { i64, i64 } %441, 0
  %s447.1 = extractvalue { i64, i64 } %441, 1
; call <kernels::Fp2>::add
  %442 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s446.0, i64 noundef %s446.1, i64 noundef %s447.0, i64 noundef %s447.1)
  %s448.0 = extractvalue { i64, i64 } %442, 0
  %s448.1 = extractvalue { i64, i64 } %442, 1
; call <kernels::Fp2>::mul
  %443 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s444.0, i64 noundef %s444.1, i64 noundef %s434.0, i64 noundef %s434.1)
; call <kernels::Fp2>::mul
  %444 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s439.0, i64 noundef %s439.1, i64 noundef %s432.0, i64 noundef %s432.1)
  %s449.1 = extractvalue { i64, i64 } %443, 1
  %s449.0 = extractvalue { i64, i64 } %443, 0
  %s450.0 = extractvalue { i64, i64 } %444, 0
  %s450.1 = extractvalue { i64, i64 } %444, 1
; call <kernels::Fp2>::add
  %445 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s449.0, i64 noundef %s449.1, i64 noundef %s450.0, i64 noundef %s450.1)
  %s451.0 = extractvalue { i64, i64 } %445, 0
  %s451.1 = extractvalue { i64, i64 } %445, 1
; call <kernels::Fp2>::mul
  %446 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s439.0, i64 noundef %s439.1, i64 noundef %s434.0, i64 noundef %s434.1)
  %s452.0 = extractvalue { i64, i64 } %446, 0
  %s452.1 = extractvalue { i64, i64 } %446, 1
; call <kernels::Fp2>::add
  %447 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s425.0, i64 noundef %s425.1, i64 noundef %s432.0, i64 noundef %s432.1)
; call <kernels::Fp2>::add
  %448 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s427.0, i64 noundef %s427.1, i64 noundef %s434.0, i64 noundef %s434.1)
  %s453.1 = extractvalue { i64, i64 } %447, 1
  %s453.0 = extractvalue { i64, i64 } %447, 0
; call <kernels::Fp2>::sub
  %449 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s445.0, i64 noundef %s445.1, i64 noundef %s453.0, i64 noundef %s453.1)
  %s454.1 = extractvalue { i64, i64 } %448, 1
  %s454.0 = extractvalue { i64, i64 } %448, 0
  %s455.0 = extractvalue { i64, i64 } %449, 0
  %s455.1 = extractvalue { i64, i64 } %449, 1
; call <kernels::Fp2>::sub
  %450 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s448.0, i64 noundef %s448.1, i64 noundef %s454.0, i64 noundef %s454.1)
  %s456.0 = extractvalue { i64, i64 } %450, 0
  %s456.1 = extractvalue { i64, i64 } %450, 1
  %_0.i117 = getelementptr inbounds nuw i8, ptr %params, i64 864
  %s457.0 = load i64, ptr %_0.i117, align 8, !noundef !3
  %451 = getelementptr inbounds nuw i8, ptr %params, i64 872
  %s457.1 = load i64, ptr %451, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %452 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s455.0, i64 noundef %s455.1, i64 noundef %s457.0, i64 noundef %s457.1)
  %s458.0 = extractvalue { i64, i64 } %452, 0
  %s458.1 = extractvalue { i64, i64 } %452, 1
; call <kernels::Fp2>::mul
  %453 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s456.0, i64 noundef %s456.1, i64 noundef %s457.0, i64 noundef %s457.1)
  %s459.0 = extractvalue { i64, i64 } %453, 0
  %s459.1 = extractvalue { i64, i64 } %453, 1
; call <kernels::Fp2>::mul
  %454 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s451.0, i64 noundef %s451.1, i64 noundef %s457.0, i64 noundef %s457.1)
  %s460.0 = extractvalue { i64, i64 } %454, 0
  %s460.1 = extractvalue { i64, i64 } %454, 1
; call <kernels::Fp2>::mul
  %455 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s452.0, i64 noundef %s452.1, i64 noundef %s457.0, i64 noundef %s457.1)
  %s461.0 = extractvalue { i64, i64 } %455, 0
  %s461.1 = extractvalue { i64, i64 } %455, 1
; call <kernels::Fp2>::add
  %456 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s417.0, i64 noundef %s417.1, i64 noundef %s458.0, i64 noundef %s458.1)
  %s462.0 = extractvalue { i64, i64 } %456, 0
  %s462.1 = extractvalue { i64, i64 } %456, 1
; call <kernels::Fp2>::add
  %457 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s418.0, i64 noundef %s418.1, i64 noundef %s459.0, i64 noundef %s459.1)
  %s463.0 = extractvalue { i64, i64 } %457, 0
  %s463.1 = extractvalue { i64, i64 } %457, 1
; call <kernels::Fp2>::add
  %458 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s419.0, i64 noundef %s419.1, i64 noundef %s460.0, i64 noundef %s460.1)
  %s464.0 = extractvalue { i64, i64 } %458, 0
  %s464.1 = extractvalue { i64, i64 } %458, 1
; call <kernels::Fp2>::add
  %459 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s420.0, i64 noundef %s420.1, i64 noundef %s461.0, i64 noundef %s461.1)
  %s465.0 = extractvalue { i64, i64 } %459, 0
  %s465.1 = extractvalue { i64, i64 } %459, 1
  %_0.i116 = getelementptr inbounds nuw i8, ptr %params, i64 880
  %s466.0 = load i64, ptr %_0.i116, align 8, !noundef !3
  %460 = getelementptr inbounds nuw i8, ptr %params, i64 888
  %s466.1 = load i64, ptr %460, align 8, !noundef !3
  %_0.i281 = getelementptr inbounds nuw i8, ptr %bases, i64 48
  %s467 = load i64, ptr %_0.i281, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %461 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s154.0, i64 noundef %s154.1, i64 noundef %s467)
; call <kernels::Fp2>::mul_base
  %462 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s156.0, i64 noundef %s156.1, i64 noundef %s467)
  %s468.1 = extractvalue { i64, i64 } %461, 1
  %s468.0 = extractvalue { i64, i64 } %461, 0
  %s469.0 = extractvalue { i64, i64 } %462, 0
  %s469.1 = extractvalue { i64, i64 } %462, 1
; call <kernels::Fp2>::sub
  %463 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s466.0, i64 noundef %s466.1, i64 noundef %s468.0, i64 noundef %s468.1)
  %s470.0 = extractvalue { i64, i64 } %463, 0
  %s470.1 = extractvalue { i64, i64 } %463, 1
  %_0.i115 = getelementptr inbounds nuw i8, ptr %params, i64 896
  %s471.0 = load i64, ptr %_0.i115, align 8, !noundef !3
  %464 = getelementptr inbounds nuw i8, ptr %params, i64 904
  %s471.1 = load i64, ptr %464, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %465 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s471.0, i64 noundef %s471.1, i64 noundef %s469.0, i64 noundef %s469.1)
  %s472.0 = extractvalue { i64, i64 } %465, 0
  %s472.1 = extractvalue { i64, i64 } %465, 1
  %_0.i114 = getelementptr inbounds nuw i8, ptr %params, i64 912
  %s473.0 = load i64, ptr %_0.i114, align 8, !noundef !3
  %466 = getelementptr inbounds nuw i8, ptr %params, i64 920
  %s473.1 = load i64, ptr %466, align 8, !noundef !3
  %_0.i280 = getelementptr inbounds nuw i8, ptr %bases, i64 56
  %s474 = load i64, ptr %_0.i280, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %467 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s162.0, i64 noundef %s162.1, i64 noundef %s474)
; call <kernels::Fp2>::mul_base
  %468 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s164.0, i64 noundef %s164.1, i64 noundef %s474)
  %s475.1 = extractvalue { i64, i64 } %467, 1
  %s475.0 = extractvalue { i64, i64 } %467, 0
  %s476.0 = extractvalue { i64, i64 } %468, 0
  %s476.1 = extractvalue { i64, i64 } %468, 1
; call <kernels::Fp2>::sub
  %469 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s473.0, i64 noundef %s473.1, i64 noundef %s475.0, i64 noundef %s475.1)
  %s477.0 = extractvalue { i64, i64 } %469, 0
  %s477.1 = extractvalue { i64, i64 } %469, 1
  %_0.i113 = getelementptr inbounds nuw i8, ptr %params, i64 928
  %s478.0 = load i64, ptr %_0.i113, align 8, !noundef !3
  %470 = getelementptr inbounds nuw i8, ptr %params, i64 936
  %s478.1 = load i64, ptr %470, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %471 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s478.0, i64 noundef %s478.1, i64 noundef %s476.0, i64 noundef %s476.1)
  %s479.0 = extractvalue { i64, i64 } %471, 0
  %s479.1 = extractvalue { i64, i64 } %471, 1
  %_0.i112 = getelementptr inbounds nuw i8, ptr %raw, i64 1440
  %s480.0 = load i64, ptr %_0.i112, align 8, !noundef !3
  %472 = getelementptr inbounds nuw i8, ptr %raw, i64 1448
  %s480.1 = load i64, ptr %472, align 8, !noundef !3
  %_0.i111 = getelementptr inbounds nuw i8, ptr %raw, i64 1456
  %s481.0 = load i64, ptr %_0.i111, align 8, !noundef !3
  %473 = getelementptr inbounds nuw i8, ptr %raw, i64 1464
  %s481.1 = load i64, ptr %473, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %474 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s481.0, i64 noundef %s481.1, i64 noundef %s480.0, i64 noundef %s480.1)
  %s482.0 = extractvalue { i64, i64 } %474, 0
  %s482.1 = extractvalue { i64, i64 } %474, 1
; call <kernels::Fp2>::mul
  %475 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s480.0, i64 noundef %s480.1, i64 noundef %s470.0, i64 noundef %s470.1)
  %s483.0 = extractvalue { i64, i64 } %475, 0
  %s483.1 = extractvalue { i64, i64 } %475, 1
; call <kernels::Fp2>::mul
  %476 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s482.0, i64 noundef %s482.1, i64 noundef %s472.0, i64 noundef %s472.1)
  %s484.0 = extractvalue { i64, i64 } %476, 0
  %s484.1 = extractvalue { i64, i64 } %476, 1
; call <kernels::Fp2>::add
  %477 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s480.0, i64 noundef %s480.1, i64 noundef %s482.0, i64 noundef %s482.1)
; call <kernels::Fp2>::add
  %478 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s470.0, i64 noundef %s470.1, i64 noundef %s472.0, i64 noundef %s472.1)
  %s485.1 = extractvalue { i64, i64 } %477, 1
  %s485.0 = extractvalue { i64, i64 } %477, 0
  %s486.0 = extractvalue { i64, i64 } %478, 0
  %s486.1 = extractvalue { i64, i64 } %478, 1
; call <kernels::Fp2>::mul
  %479 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s485.0, i64 noundef %s485.1, i64 noundef %s486.0, i64 noundef %s486.1)
  %s487.0 = extractvalue { i64, i64 } %479, 0
  %s487.1 = extractvalue { i64, i64 } %479, 1
; call <kernels::Fp2>::sub
  %480 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s487.0, i64 noundef %s487.1, i64 noundef %s483.0, i64 noundef %s483.1)
  %s488.0 = extractvalue { i64, i64 } %480, 0
  %s488.1 = extractvalue { i64, i64 } %480, 1
; call <kernels::Fp2>::sub
  %481 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s488.0, i64 noundef %s488.1, i64 noundef %s484.0, i64 noundef %s484.1)
  %s489.0 = extractvalue { i64, i64 } %481, 0
  %s489.1 = extractvalue { i64, i64 } %481, 1
; call <kernels::Fp2>::mul
  %482 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s483.0, i64 noundef %s483.1, i64 noundef %s477.0, i64 noundef %s477.1)
  %s490.0 = extractvalue { i64, i64 } %482, 0
  %s490.1 = extractvalue { i64, i64 } %482, 1
; call <kernels::Fp2>::mul
  %483 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s483.0, i64 noundef %s483.1, i64 noundef %s479.0, i64 noundef %s479.1)
; call <kernels::Fp2>::mul
  %484 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s489.0, i64 noundef %s489.1, i64 noundef %s477.0, i64 noundef %s477.1)
  %s491.1 = extractvalue { i64, i64 } %483, 1
  %s491.0 = extractvalue { i64, i64 } %483, 0
  %s492.0 = extractvalue { i64, i64 } %484, 0
  %s492.1 = extractvalue { i64, i64 } %484, 1
; call <kernels::Fp2>::add
  %485 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s491.0, i64 noundef %s491.1, i64 noundef %s492.0, i64 noundef %s492.1)
  %s493.0 = extractvalue { i64, i64 } %485, 0
  %s493.1 = extractvalue { i64, i64 } %485, 1
; call <kernels::Fp2>::mul
  %486 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s489.0, i64 noundef %s489.1, i64 noundef %s479.0, i64 noundef %s479.1)
; call <kernels::Fp2>::mul
  %487 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s484.0, i64 noundef %s484.1, i64 noundef %s477.0, i64 noundef %s477.1)
  %s494.1 = extractvalue { i64, i64 } %486, 1
  %s494.0 = extractvalue { i64, i64 } %486, 0
  %s495.0 = extractvalue { i64, i64 } %487, 0
  %s495.1 = extractvalue { i64, i64 } %487, 1
; call <kernels::Fp2>::add
  %488 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s494.0, i64 noundef %s494.1, i64 noundef %s495.0, i64 noundef %s495.1)
  %s496.0 = extractvalue { i64, i64 } %488, 0
  %s496.1 = extractvalue { i64, i64 } %488, 1
; call <kernels::Fp2>::mul
  %489 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s484.0, i64 noundef %s484.1, i64 noundef %s479.0, i64 noundef %s479.1)
  %s497.0 = extractvalue { i64, i64 } %489, 0
  %s497.1 = extractvalue { i64, i64 } %489, 1
; call <kernels::Fp2>::add
  %490 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s470.0, i64 noundef %s470.1, i64 noundef %s477.0, i64 noundef %s477.1)
; call <kernels::Fp2>::add
  %491 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s472.0, i64 noundef %s472.1, i64 noundef %s479.0, i64 noundef %s479.1)
  %s498.1 = extractvalue { i64, i64 } %490, 1
  %s498.0 = extractvalue { i64, i64 } %490, 0
; call <kernels::Fp2>::sub
  %492 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s490.0, i64 noundef %s490.1, i64 noundef %s498.0, i64 noundef %s498.1)
  %s499.1 = extractvalue { i64, i64 } %491, 1
  %s499.0 = extractvalue { i64, i64 } %491, 0
  %s500.0 = extractvalue { i64, i64 } %492, 0
  %s500.1 = extractvalue { i64, i64 } %492, 1
; call <kernels::Fp2>::sub
  %493 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s493.0, i64 noundef %s493.1, i64 noundef %s499.0, i64 noundef %s499.1)
  %s501.0 = extractvalue { i64, i64 } %493, 0
  %s501.1 = extractvalue { i64, i64 } %493, 1
  %_0.i110 = getelementptr inbounds nuw i8, ptr %params, i64 944
  %s502.0 = load i64, ptr %_0.i110, align 8, !noundef !3
  %494 = getelementptr inbounds nuw i8, ptr %params, i64 952
  %s502.1 = load i64, ptr %494, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %495 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s500.0, i64 noundef %s500.1, i64 noundef %s502.0, i64 noundef %s502.1)
  %s503.0 = extractvalue { i64, i64 } %495, 0
  %s503.1 = extractvalue { i64, i64 } %495, 1
; call <kernels::Fp2>::mul
  %496 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s501.0, i64 noundef %s501.1, i64 noundef %s502.0, i64 noundef %s502.1)
  %s504.0 = extractvalue { i64, i64 } %496, 0
  %s504.1 = extractvalue { i64, i64 } %496, 1
; call <kernels::Fp2>::mul
  %497 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s496.0, i64 noundef %s496.1, i64 noundef %s502.0, i64 noundef %s502.1)
  %s505.0 = extractvalue { i64, i64 } %497, 0
  %s505.1 = extractvalue { i64, i64 } %497, 1
; call <kernels::Fp2>::mul
  %498 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s497.0, i64 noundef %s497.1, i64 noundef %s502.0, i64 noundef %s502.1)
  %s506.0 = extractvalue { i64, i64 } %498, 0
  %s506.1 = extractvalue { i64, i64 } %498, 1
; call <kernels::Fp2>::add
  %499 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s462.0, i64 noundef %s462.1, i64 noundef %s503.0, i64 noundef %s503.1)
  %s507.0 = extractvalue { i64, i64 } %499, 0
  %s507.1 = extractvalue { i64, i64 } %499, 1
; call <kernels::Fp2>::add
  %500 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s463.0, i64 noundef %s463.1, i64 noundef %s504.0, i64 noundef %s504.1)
  %s508.0 = extractvalue { i64, i64 } %500, 0
  %s508.1 = extractvalue { i64, i64 } %500, 1
; call <kernels::Fp2>::add
  %501 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s464.0, i64 noundef %s464.1, i64 noundef %s505.0, i64 noundef %s505.1)
  %s509.0 = extractvalue { i64, i64 } %501, 0
  %s509.1 = extractvalue { i64, i64 } %501, 1
; call <kernels::Fp2>::add
  %502 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s465.0, i64 noundef %s465.1, i64 noundef %s506.0, i64 noundef %s506.1)
  %s510.0 = extractvalue { i64, i64 } %502, 0
  %s510.1 = extractvalue { i64, i64 } %502, 1
  %_0.i109 = getelementptr inbounds nuw i8, ptr %params, i64 960
  %s511.0 = load i64, ptr %_0.i109, align 8, !noundef !3
  %503 = getelementptr inbounds nuw i8, ptr %params, i64 968
  %s511.1 = load i64, ptr %503, align 8, !noundef !3
  %_0.i279 = getelementptr inbounds nuw i8, ptr %bases, i64 64
  %s512 = load i64, ptr %_0.i279, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %504 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s170.0, i64 noundef %s170.1, i64 noundef %s512)
; call <kernels::Fp2>::mul_base
  %505 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s172.0, i64 noundef %s172.1, i64 noundef %s512)
  %s513.1 = extractvalue { i64, i64 } %504, 1
  %s513.0 = extractvalue { i64, i64 } %504, 0
  %s514.0 = extractvalue { i64, i64 } %505, 0
  %s514.1 = extractvalue { i64, i64 } %505, 1
; call <kernels::Fp2>::sub
  %506 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s511.0, i64 noundef %s511.1, i64 noundef %s513.0, i64 noundef %s513.1)
  %s515.0 = extractvalue { i64, i64 } %506, 0
  %s515.1 = extractvalue { i64, i64 } %506, 1
  %_0.i108 = getelementptr inbounds nuw i8, ptr %params, i64 976
  %s516.0 = load i64, ptr %_0.i108, align 8, !noundef !3
  %507 = getelementptr inbounds nuw i8, ptr %params, i64 984
  %s516.1 = load i64, ptr %507, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %508 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s516.0, i64 noundef %s516.1, i64 noundef %s514.0, i64 noundef %s514.1)
  %s517.0 = extractvalue { i64, i64 } %508, 0
  %s517.1 = extractvalue { i64, i64 } %508, 1
  %_0.i107 = getelementptr inbounds nuw i8, ptr %params, i64 992
  %s518.0 = load i64, ptr %_0.i107, align 8, !noundef !3
  %509 = getelementptr inbounds nuw i8, ptr %params, i64 1000
  %s518.1 = load i64, ptr %509, align 8, !noundef !3
  %_0.i278 = getelementptr inbounds nuw i8, ptr %bases, i64 72
  %s519 = load i64, ptr %_0.i278, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %510 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s178.0, i64 noundef %s178.1, i64 noundef %s519)
; call <kernels::Fp2>::mul_base
  %511 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s180.0, i64 noundef %s180.1, i64 noundef %s519)
  %s520.1 = extractvalue { i64, i64 } %510, 1
  %s520.0 = extractvalue { i64, i64 } %510, 0
  %s521.0 = extractvalue { i64, i64 } %511, 0
  %s521.1 = extractvalue { i64, i64 } %511, 1
; call <kernels::Fp2>::sub
  %512 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s518.0, i64 noundef %s518.1, i64 noundef %s520.0, i64 noundef %s520.1)
  %s522.0 = extractvalue { i64, i64 } %512, 0
  %s522.1 = extractvalue { i64, i64 } %512, 1
  %_0.i106 = getelementptr inbounds nuw i8, ptr %params, i64 1008
  %s523.0 = load i64, ptr %_0.i106, align 8, !noundef !3
  %513 = getelementptr inbounds nuw i8, ptr %params, i64 1016
  %s523.1 = load i64, ptr %513, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %514 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s523.0, i64 noundef %s523.1, i64 noundef %s521.0, i64 noundef %s521.1)
  %s524.0 = extractvalue { i64, i64 } %514, 0
  %s524.1 = extractvalue { i64, i64 } %514, 1
  %_0.i105 = getelementptr inbounds nuw i8, ptr %raw, i64 1472
  %s525.0 = load i64, ptr %_0.i105, align 8, !noundef !3
  %515 = getelementptr inbounds nuw i8, ptr %raw, i64 1480
  %s525.1 = load i64, ptr %515, align 8, !noundef !3
  %_0.i104 = getelementptr inbounds nuw i8, ptr %raw, i64 1488
  %s526.0 = load i64, ptr %_0.i104, align 8, !noundef !3
  %516 = getelementptr inbounds nuw i8, ptr %raw, i64 1496
  %s526.1 = load i64, ptr %516, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %517 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s526.0, i64 noundef %s526.1, i64 noundef %s525.0, i64 noundef %s525.1)
  %s527.0 = extractvalue { i64, i64 } %517, 0
  %s527.1 = extractvalue { i64, i64 } %517, 1
; call <kernels::Fp2>::mul
  %518 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s525.0, i64 noundef %s525.1, i64 noundef %s515.0, i64 noundef %s515.1)
  %s528.0 = extractvalue { i64, i64 } %518, 0
  %s528.1 = extractvalue { i64, i64 } %518, 1
; call <kernels::Fp2>::mul
  %519 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s527.0, i64 noundef %s527.1, i64 noundef %s517.0, i64 noundef %s517.1)
  %s529.0 = extractvalue { i64, i64 } %519, 0
  %s529.1 = extractvalue { i64, i64 } %519, 1
; call <kernels::Fp2>::add
  %520 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s525.0, i64 noundef %s525.1, i64 noundef %s527.0, i64 noundef %s527.1)
; call <kernels::Fp2>::add
  %521 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s515.0, i64 noundef %s515.1, i64 noundef %s517.0, i64 noundef %s517.1)
  %s530.1 = extractvalue { i64, i64 } %520, 1
  %s530.0 = extractvalue { i64, i64 } %520, 0
  %s531.0 = extractvalue { i64, i64 } %521, 0
  %s531.1 = extractvalue { i64, i64 } %521, 1
; call <kernels::Fp2>::mul
  %522 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s530.0, i64 noundef %s530.1, i64 noundef %s531.0, i64 noundef %s531.1)
  %s532.0 = extractvalue { i64, i64 } %522, 0
  %s532.1 = extractvalue { i64, i64 } %522, 1
; call <kernels::Fp2>::sub
  %523 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s532.0, i64 noundef %s532.1, i64 noundef %s528.0, i64 noundef %s528.1)
  %s533.0 = extractvalue { i64, i64 } %523, 0
  %s533.1 = extractvalue { i64, i64 } %523, 1
; call <kernels::Fp2>::sub
  %524 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s533.0, i64 noundef %s533.1, i64 noundef %s529.0, i64 noundef %s529.1)
  %s534.0 = extractvalue { i64, i64 } %524, 0
  %s534.1 = extractvalue { i64, i64 } %524, 1
; call <kernels::Fp2>::mul
  %525 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s528.0, i64 noundef %s528.1, i64 noundef %s522.0, i64 noundef %s522.1)
  %s535.0 = extractvalue { i64, i64 } %525, 0
  %s535.1 = extractvalue { i64, i64 } %525, 1
; call <kernels::Fp2>::mul
  %526 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s528.0, i64 noundef %s528.1, i64 noundef %s524.0, i64 noundef %s524.1)
; call <kernels::Fp2>::mul
  %527 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s534.0, i64 noundef %s534.1, i64 noundef %s522.0, i64 noundef %s522.1)
  %s536.1 = extractvalue { i64, i64 } %526, 1
  %s536.0 = extractvalue { i64, i64 } %526, 0
  %s537.0 = extractvalue { i64, i64 } %527, 0
  %s537.1 = extractvalue { i64, i64 } %527, 1
; call <kernels::Fp2>::add
  %528 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s536.0, i64 noundef %s536.1, i64 noundef %s537.0, i64 noundef %s537.1)
  %s538.0 = extractvalue { i64, i64 } %528, 0
  %s538.1 = extractvalue { i64, i64 } %528, 1
; call <kernels::Fp2>::mul
  %529 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s534.0, i64 noundef %s534.1, i64 noundef %s524.0, i64 noundef %s524.1)
; call <kernels::Fp2>::mul
  %530 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s529.0, i64 noundef %s529.1, i64 noundef %s522.0, i64 noundef %s522.1)
  %s539.1 = extractvalue { i64, i64 } %529, 1
  %s539.0 = extractvalue { i64, i64 } %529, 0
  %s540.0 = extractvalue { i64, i64 } %530, 0
  %s540.1 = extractvalue { i64, i64 } %530, 1
; call <kernels::Fp2>::add
  %531 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s539.0, i64 noundef %s539.1, i64 noundef %s540.0, i64 noundef %s540.1)
  %s541.0 = extractvalue { i64, i64 } %531, 0
  %s541.1 = extractvalue { i64, i64 } %531, 1
; call <kernels::Fp2>::mul
  %532 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s529.0, i64 noundef %s529.1, i64 noundef %s524.0, i64 noundef %s524.1)
  %s542.0 = extractvalue { i64, i64 } %532, 0
  %s542.1 = extractvalue { i64, i64 } %532, 1
; call <kernels::Fp2>::add
  %533 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s515.0, i64 noundef %s515.1, i64 noundef %s522.0, i64 noundef %s522.1)
; call <kernels::Fp2>::add
  %534 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s517.0, i64 noundef %s517.1, i64 noundef %s524.0, i64 noundef %s524.1)
  %s543.1 = extractvalue { i64, i64 } %533, 1
  %s543.0 = extractvalue { i64, i64 } %533, 0
; call <kernels::Fp2>::sub
  %535 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s535.0, i64 noundef %s535.1, i64 noundef %s543.0, i64 noundef %s543.1)
  %s544.1 = extractvalue { i64, i64 } %534, 1
  %s544.0 = extractvalue { i64, i64 } %534, 0
  %s545.0 = extractvalue { i64, i64 } %535, 0
  %s545.1 = extractvalue { i64, i64 } %535, 1
; call <kernels::Fp2>::sub
  %536 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s538.0, i64 noundef %s538.1, i64 noundef %s544.0, i64 noundef %s544.1)
  %s546.0 = extractvalue { i64, i64 } %536, 0
  %s546.1 = extractvalue { i64, i64 } %536, 1
  %_0.i103 = getelementptr inbounds nuw i8, ptr %params, i64 1024
  %s547.0 = load i64, ptr %_0.i103, align 8, !noundef !3
  %537 = getelementptr inbounds nuw i8, ptr %params, i64 1032
  %s547.1 = load i64, ptr %537, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %538 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s545.0, i64 noundef %s545.1, i64 noundef %s547.0, i64 noundef %s547.1)
  %s548.0 = extractvalue { i64, i64 } %538, 0
  %s548.1 = extractvalue { i64, i64 } %538, 1
; call <kernels::Fp2>::mul
  %539 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s546.0, i64 noundef %s546.1, i64 noundef %s547.0, i64 noundef %s547.1)
  %s549.0 = extractvalue { i64, i64 } %539, 0
  %s549.1 = extractvalue { i64, i64 } %539, 1
; call <kernels::Fp2>::mul
  %540 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s541.0, i64 noundef %s541.1, i64 noundef %s547.0, i64 noundef %s547.1)
  %s550.0 = extractvalue { i64, i64 } %540, 0
  %s550.1 = extractvalue { i64, i64 } %540, 1
; call <kernels::Fp2>::mul
  %541 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s542.0, i64 noundef %s542.1, i64 noundef %s547.0, i64 noundef %s547.1)
  %s551.0 = extractvalue { i64, i64 } %541, 0
  %s551.1 = extractvalue { i64, i64 } %541, 1
; call <kernels::Fp2>::add
  %542 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s507.0, i64 noundef %s507.1, i64 noundef %s548.0, i64 noundef %s548.1)
  %s552.0 = extractvalue { i64, i64 } %542, 0
  %s552.1 = extractvalue { i64, i64 } %542, 1
; call <kernels::Fp2>::add
  %543 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s508.0, i64 noundef %s508.1, i64 noundef %s549.0, i64 noundef %s549.1)
  %s553.0 = extractvalue { i64, i64 } %543, 0
  %s553.1 = extractvalue { i64, i64 } %543, 1
; call <kernels::Fp2>::add
  %544 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s509.0, i64 noundef %s509.1, i64 noundef %s550.0, i64 noundef %s550.1)
  %s554.0 = extractvalue { i64, i64 } %544, 0
  %s554.1 = extractvalue { i64, i64 } %544, 1
; call <kernels::Fp2>::add
  %545 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s510.0, i64 noundef %s510.1, i64 noundef %s551.0, i64 noundef %s551.1)
  %s555.0 = extractvalue { i64, i64 } %545, 0
  %s555.1 = extractvalue { i64, i64 } %545, 1
  %_0.i102 = getelementptr inbounds nuw i8, ptr %params, i64 1040
  %s556.0 = load i64, ptr %_0.i102, align 8, !noundef !3
  %546 = getelementptr inbounds nuw i8, ptr %params, i64 1048
  %s556.1 = load i64, ptr %546, align 8, !noundef !3
  %_0.i277 = getelementptr inbounds nuw i8, ptr %bases, i64 80
  %s557 = load i64, ptr %_0.i277, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %547 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s186.0, i64 noundef %s186.1, i64 noundef %s557)
; call <kernels::Fp2>::mul_base
  %548 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s188.0, i64 noundef %s188.1, i64 noundef %s557)
  %s558.1 = extractvalue { i64, i64 } %547, 1
  %s558.0 = extractvalue { i64, i64 } %547, 0
  %s559.0 = extractvalue { i64, i64 } %548, 0
  %s559.1 = extractvalue { i64, i64 } %548, 1
; call <kernels::Fp2>::sub
  %549 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s556.0, i64 noundef %s556.1, i64 noundef %s558.0, i64 noundef %s558.1)
  %s560.0 = extractvalue { i64, i64 } %549, 0
  %s560.1 = extractvalue { i64, i64 } %549, 1
  %_0.i101 = getelementptr inbounds nuw i8, ptr %params, i64 1056
  %s561.0 = load i64, ptr %_0.i101, align 8, !noundef !3
  %550 = getelementptr inbounds nuw i8, ptr %params, i64 1064
  %s561.1 = load i64, ptr %550, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %551 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s561.0, i64 noundef %s561.1, i64 noundef %s559.0, i64 noundef %s559.1)
  %s562.0 = extractvalue { i64, i64 } %551, 0
  %s562.1 = extractvalue { i64, i64 } %551, 1
  %_0.i100 = getelementptr inbounds nuw i8, ptr %params, i64 1072
  %s563.0 = load i64, ptr %_0.i100, align 8, !noundef !3
  %552 = getelementptr inbounds nuw i8, ptr %params, i64 1080
  %s563.1 = load i64, ptr %552, align 8, !noundef !3
  %_0.i276 = getelementptr inbounds nuw i8, ptr %bases, i64 88
  %s564 = load i64, ptr %_0.i276, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %553 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s194.0, i64 noundef %s194.1, i64 noundef %s564)
; call <kernels::Fp2>::mul_base
  %554 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s196.0, i64 noundef %s196.1, i64 noundef %s564)
  %s565.1 = extractvalue { i64, i64 } %553, 1
  %s565.0 = extractvalue { i64, i64 } %553, 0
  %s566.0 = extractvalue { i64, i64 } %554, 0
  %s566.1 = extractvalue { i64, i64 } %554, 1
; call <kernels::Fp2>::sub
  %555 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s563.0, i64 noundef %s563.1, i64 noundef %s565.0, i64 noundef %s565.1)
  %s567.0 = extractvalue { i64, i64 } %555, 0
  %s567.1 = extractvalue { i64, i64 } %555, 1
  %_0.i99 = getelementptr inbounds nuw i8, ptr %params, i64 1088
  %s568.0 = load i64, ptr %_0.i99, align 8, !noundef !3
  %556 = getelementptr inbounds nuw i8, ptr %params, i64 1096
  %s568.1 = load i64, ptr %556, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %557 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s568.0, i64 noundef %s568.1, i64 noundef %s566.0, i64 noundef %s566.1)
  %s569.0 = extractvalue { i64, i64 } %557, 0
  %s569.1 = extractvalue { i64, i64 } %557, 1
  %_0.i98 = getelementptr inbounds nuw i8, ptr %raw, i64 1504
  %s570.0 = load i64, ptr %_0.i98, align 8, !noundef !3
  %558 = getelementptr inbounds nuw i8, ptr %raw, i64 1512
  %s570.1 = load i64, ptr %558, align 8, !noundef !3
  %_0.i97 = getelementptr inbounds nuw i8, ptr %raw, i64 1520
  %s571.0 = load i64, ptr %_0.i97, align 8, !noundef !3
  %559 = getelementptr inbounds nuw i8, ptr %raw, i64 1528
  %s571.1 = load i64, ptr %559, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %560 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s571.0, i64 noundef %s571.1, i64 noundef %s570.0, i64 noundef %s570.1)
  %s572.0 = extractvalue { i64, i64 } %560, 0
  %s572.1 = extractvalue { i64, i64 } %560, 1
; call <kernels::Fp2>::mul
  %561 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s570.0, i64 noundef %s570.1, i64 noundef %s560.0, i64 noundef %s560.1)
  %s573.0 = extractvalue { i64, i64 } %561, 0
  %s573.1 = extractvalue { i64, i64 } %561, 1
; call <kernels::Fp2>::mul
  %562 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s572.0, i64 noundef %s572.1, i64 noundef %s562.0, i64 noundef %s562.1)
  %s574.0 = extractvalue { i64, i64 } %562, 0
  %s574.1 = extractvalue { i64, i64 } %562, 1
; call <kernels::Fp2>::add
  %563 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s570.0, i64 noundef %s570.1, i64 noundef %s572.0, i64 noundef %s572.1)
; call <kernels::Fp2>::add
  %564 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s560.0, i64 noundef %s560.1, i64 noundef %s562.0, i64 noundef %s562.1)
  %s575.1 = extractvalue { i64, i64 } %563, 1
  %s575.0 = extractvalue { i64, i64 } %563, 0
  %s576.0 = extractvalue { i64, i64 } %564, 0
  %s576.1 = extractvalue { i64, i64 } %564, 1
; call <kernels::Fp2>::mul
  %565 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s575.0, i64 noundef %s575.1, i64 noundef %s576.0, i64 noundef %s576.1)
  %s577.0 = extractvalue { i64, i64 } %565, 0
  %s577.1 = extractvalue { i64, i64 } %565, 1
; call <kernels::Fp2>::sub
  %566 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s577.0, i64 noundef %s577.1, i64 noundef %s573.0, i64 noundef %s573.1)
  %s578.0 = extractvalue { i64, i64 } %566, 0
  %s578.1 = extractvalue { i64, i64 } %566, 1
; call <kernels::Fp2>::sub
  %567 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s578.0, i64 noundef %s578.1, i64 noundef %s574.0, i64 noundef %s574.1)
  %s579.0 = extractvalue { i64, i64 } %567, 0
  %s579.1 = extractvalue { i64, i64 } %567, 1
; call <kernels::Fp2>::mul
  %568 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s573.0, i64 noundef %s573.1, i64 noundef %s567.0, i64 noundef %s567.1)
  %s580.0 = extractvalue { i64, i64 } %568, 0
  %s580.1 = extractvalue { i64, i64 } %568, 1
; call <kernels::Fp2>::mul
  %569 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s573.0, i64 noundef %s573.1, i64 noundef %s569.0, i64 noundef %s569.1)
; call <kernels::Fp2>::mul
  %570 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s579.0, i64 noundef %s579.1, i64 noundef %s567.0, i64 noundef %s567.1)
  %s581.1 = extractvalue { i64, i64 } %569, 1
  %s581.0 = extractvalue { i64, i64 } %569, 0
  %s582.0 = extractvalue { i64, i64 } %570, 0
  %s582.1 = extractvalue { i64, i64 } %570, 1
; call <kernels::Fp2>::add
  %571 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s581.0, i64 noundef %s581.1, i64 noundef %s582.0, i64 noundef %s582.1)
  %s583.0 = extractvalue { i64, i64 } %571, 0
  %s583.1 = extractvalue { i64, i64 } %571, 1
; call <kernels::Fp2>::mul
  %572 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s579.0, i64 noundef %s579.1, i64 noundef %s569.0, i64 noundef %s569.1)
; call <kernels::Fp2>::mul
  %573 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s574.0, i64 noundef %s574.1, i64 noundef %s567.0, i64 noundef %s567.1)
  %s584.1 = extractvalue { i64, i64 } %572, 1
  %s584.0 = extractvalue { i64, i64 } %572, 0
  %s585.0 = extractvalue { i64, i64 } %573, 0
  %s585.1 = extractvalue { i64, i64 } %573, 1
; call <kernels::Fp2>::add
  %574 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s584.0, i64 noundef %s584.1, i64 noundef %s585.0, i64 noundef %s585.1)
  %s586.0 = extractvalue { i64, i64 } %574, 0
  %s586.1 = extractvalue { i64, i64 } %574, 1
; call <kernels::Fp2>::mul
  %575 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s574.0, i64 noundef %s574.1, i64 noundef %s569.0, i64 noundef %s569.1)
  %s587.0 = extractvalue { i64, i64 } %575, 0
  %s587.1 = extractvalue { i64, i64 } %575, 1
; call <kernels::Fp2>::add
  %576 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s560.0, i64 noundef %s560.1, i64 noundef %s567.0, i64 noundef %s567.1)
; call <kernels::Fp2>::add
  %577 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s562.0, i64 noundef %s562.1, i64 noundef %s569.0, i64 noundef %s569.1)
  %s588.1 = extractvalue { i64, i64 } %576, 1
  %s588.0 = extractvalue { i64, i64 } %576, 0
; call <kernels::Fp2>::sub
  %578 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s580.0, i64 noundef %s580.1, i64 noundef %s588.0, i64 noundef %s588.1)
  %s589.1 = extractvalue { i64, i64 } %577, 1
  %s589.0 = extractvalue { i64, i64 } %577, 0
  %s590.0 = extractvalue { i64, i64 } %578, 0
  %s590.1 = extractvalue { i64, i64 } %578, 1
; call <kernels::Fp2>::sub
  %579 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s583.0, i64 noundef %s583.1, i64 noundef %s589.0, i64 noundef %s589.1)
  %s591.0 = extractvalue { i64, i64 } %579, 0
  %s591.1 = extractvalue { i64, i64 } %579, 1
  %_0.i96 = getelementptr inbounds nuw i8, ptr %params, i64 1104
  %s592.0 = load i64, ptr %_0.i96, align 8, !noundef !3
  %580 = getelementptr inbounds nuw i8, ptr %params, i64 1112
  %s592.1 = load i64, ptr %580, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %581 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s590.0, i64 noundef %s590.1, i64 noundef %s592.0, i64 noundef %s592.1)
  %s593.0 = extractvalue { i64, i64 } %581, 0
  %s593.1 = extractvalue { i64, i64 } %581, 1
; call <kernels::Fp2>::mul
  %582 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s591.0, i64 noundef %s591.1, i64 noundef %s592.0, i64 noundef %s592.1)
  %s594.0 = extractvalue { i64, i64 } %582, 0
  %s594.1 = extractvalue { i64, i64 } %582, 1
; call <kernels::Fp2>::mul
  %583 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s586.0, i64 noundef %s586.1, i64 noundef %s592.0, i64 noundef %s592.1)
  %s595.0 = extractvalue { i64, i64 } %583, 0
  %s595.1 = extractvalue { i64, i64 } %583, 1
; call <kernels::Fp2>::mul
  %584 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s587.0, i64 noundef %s587.1, i64 noundef %s592.0, i64 noundef %s592.1)
  %s596.0 = extractvalue { i64, i64 } %584, 0
  %s596.1 = extractvalue { i64, i64 } %584, 1
; call <kernels::Fp2>::add
  %585 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s552.0, i64 noundef %s552.1, i64 noundef %s593.0, i64 noundef %s593.1)
  %s597.0 = extractvalue { i64, i64 } %585, 0
  %s597.1 = extractvalue { i64, i64 } %585, 1
; call <kernels::Fp2>::add
  %586 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s553.0, i64 noundef %s553.1, i64 noundef %s594.0, i64 noundef %s594.1)
  %s598.0 = extractvalue { i64, i64 } %586, 0
  %s598.1 = extractvalue { i64, i64 } %586, 1
; call <kernels::Fp2>::add
  %587 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s554.0, i64 noundef %s554.1, i64 noundef %s595.0, i64 noundef %s595.1)
  %s599.0 = extractvalue { i64, i64 } %587, 0
  %s599.1 = extractvalue { i64, i64 } %587, 1
; call <kernels::Fp2>::add
  %588 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s555.0, i64 noundef %s555.1, i64 noundef %s596.0, i64 noundef %s596.1)
  %s600.0 = extractvalue { i64, i64 } %588, 0
  %s600.1 = extractvalue { i64, i64 } %588, 1
  %_0.i95 = getelementptr inbounds nuw i8, ptr %params, i64 1120
  %s601.0 = load i64, ptr %_0.i95, align 8, !noundef !3
  %589 = getelementptr inbounds nuw i8, ptr %params, i64 1128
  %s601.1 = load i64, ptr %589, align 8, !noundef !3
  %_0.i275 = getelementptr inbounds nuw i8, ptr %bases, i64 96
  %s602 = load i64, ptr %_0.i275, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %590 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s74.0, i64 noundef %s74.1, i64 noundef %s602)
; call <kernels::Fp2>::mul_base
  %591 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s76.0, i64 noundef %s76.1, i64 noundef %s602)
  %s603.1 = extractvalue { i64, i64 } %590, 1
  %s603.0 = extractvalue { i64, i64 } %590, 0
  %s604.0 = extractvalue { i64, i64 } %591, 0
  %s604.1 = extractvalue { i64, i64 } %591, 1
; call <kernels::Fp2>::sub
  %592 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s601.0, i64 noundef %s601.1, i64 noundef %s603.0, i64 noundef %s603.1)
  %s605.0 = extractvalue { i64, i64 } %592, 0
  %s605.1 = extractvalue { i64, i64 } %592, 1
  %_0.i94 = getelementptr inbounds nuw i8, ptr %params, i64 1136
  %s606.0 = load i64, ptr %_0.i94, align 8, !noundef !3
  %593 = getelementptr inbounds nuw i8, ptr %params, i64 1144
  %s606.1 = load i64, ptr %593, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %594 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s606.0, i64 noundef %s606.1, i64 noundef %s604.0, i64 noundef %s604.1)
  %s607.0 = extractvalue { i64, i64 } %594, 0
  %s607.1 = extractvalue { i64, i64 } %594, 1
  %_0.i93 = getelementptr inbounds nuw i8, ptr %params, i64 1152
  %s608.0 = load i64, ptr %_0.i93, align 8, !noundef !3
  %595 = getelementptr inbounds nuw i8, ptr %params, i64 1160
  %s608.1 = load i64, ptr %595, align 8, !noundef !3
  %_0.i274 = getelementptr inbounds nuw i8, ptr %bases, i64 104
  %s609 = load i64, ptr %_0.i274, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %596 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s82.0, i64 noundef %s82.1, i64 noundef %s609)
; call <kernels::Fp2>::mul_base
  %597 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s84.0, i64 noundef %s84.1, i64 noundef %s609)
  %s610.1 = extractvalue { i64, i64 } %596, 1
  %s610.0 = extractvalue { i64, i64 } %596, 0
  %s611.0 = extractvalue { i64, i64 } %597, 0
  %s611.1 = extractvalue { i64, i64 } %597, 1
; call <kernels::Fp2>::sub
  %598 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s608.0, i64 noundef %s608.1, i64 noundef %s610.0, i64 noundef %s610.1)
  %s612.0 = extractvalue { i64, i64 } %598, 0
  %s612.1 = extractvalue { i64, i64 } %598, 1
  %_0.i92 = getelementptr inbounds nuw i8, ptr %params, i64 1168
  %s613.0 = load i64, ptr %_0.i92, align 8, !noundef !3
  %599 = getelementptr inbounds nuw i8, ptr %params, i64 1176
  %s613.1 = load i64, ptr %599, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %600 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s613.0, i64 noundef %s613.1, i64 noundef %s611.0, i64 noundef %s611.1)
  %s614.0 = extractvalue { i64, i64 } %600, 0
  %s614.1 = extractvalue { i64, i64 } %600, 1
  %_0.i91 = getelementptr inbounds nuw i8, ptr %raw, i64 1536
  %s615.0 = load i64, ptr %_0.i91, align 8, !noundef !3
  %601 = getelementptr inbounds nuw i8, ptr %raw, i64 1544
  %s615.1 = load i64, ptr %601, align 8, !noundef !3
  %_0.i90 = getelementptr inbounds nuw i8, ptr %raw, i64 1552
  %s616.0 = load i64, ptr %_0.i90, align 8, !noundef !3
  %602 = getelementptr inbounds nuw i8, ptr %raw, i64 1560
  %s616.1 = load i64, ptr %602, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %603 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s616.0, i64 noundef %s616.1, i64 noundef %s615.0, i64 noundef %s615.1)
  %s617.0 = extractvalue { i64, i64 } %603, 0
  %s617.1 = extractvalue { i64, i64 } %603, 1
; call <kernels::Fp2>::mul
  %604 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s615.0, i64 noundef %s615.1, i64 noundef %s605.0, i64 noundef %s605.1)
  %s618.0 = extractvalue { i64, i64 } %604, 0
  %s618.1 = extractvalue { i64, i64 } %604, 1
; call <kernels::Fp2>::mul
  %605 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s617.0, i64 noundef %s617.1, i64 noundef %s607.0, i64 noundef %s607.1)
  %s619.0 = extractvalue { i64, i64 } %605, 0
  %s619.1 = extractvalue { i64, i64 } %605, 1
; call <kernels::Fp2>::add
  %606 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s615.0, i64 noundef %s615.1, i64 noundef %s617.0, i64 noundef %s617.1)
; call <kernels::Fp2>::add
  %607 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s605.0, i64 noundef %s605.1, i64 noundef %s607.0, i64 noundef %s607.1)
  %s620.1 = extractvalue { i64, i64 } %606, 1
  %s620.0 = extractvalue { i64, i64 } %606, 0
  %s621.0 = extractvalue { i64, i64 } %607, 0
  %s621.1 = extractvalue { i64, i64 } %607, 1
; call <kernels::Fp2>::mul
  %608 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s620.0, i64 noundef %s620.1, i64 noundef %s621.0, i64 noundef %s621.1)
  %s622.0 = extractvalue { i64, i64 } %608, 0
  %s622.1 = extractvalue { i64, i64 } %608, 1
; call <kernels::Fp2>::sub
  %609 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s622.0, i64 noundef %s622.1, i64 noundef %s618.0, i64 noundef %s618.1)
  %s623.0 = extractvalue { i64, i64 } %609, 0
  %s623.1 = extractvalue { i64, i64 } %609, 1
; call <kernels::Fp2>::sub
  %610 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s623.0, i64 noundef %s623.1, i64 noundef %s619.0, i64 noundef %s619.1)
  %s624.0 = extractvalue { i64, i64 } %610, 0
  %s624.1 = extractvalue { i64, i64 } %610, 1
; call <kernels::Fp2>::mul
  %611 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s618.0, i64 noundef %s618.1, i64 noundef %s612.0, i64 noundef %s612.1)
  %s625.0 = extractvalue { i64, i64 } %611, 0
  %s625.1 = extractvalue { i64, i64 } %611, 1
; call <kernels::Fp2>::mul
  %612 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s618.0, i64 noundef %s618.1, i64 noundef %s614.0, i64 noundef %s614.1)
; call <kernels::Fp2>::mul
  %613 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s624.0, i64 noundef %s624.1, i64 noundef %s612.0, i64 noundef %s612.1)
  %s626.1 = extractvalue { i64, i64 } %612, 1
  %s626.0 = extractvalue { i64, i64 } %612, 0
  %s627.0 = extractvalue { i64, i64 } %613, 0
  %s627.1 = extractvalue { i64, i64 } %613, 1
; call <kernels::Fp2>::add
  %614 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s626.0, i64 noundef %s626.1, i64 noundef %s627.0, i64 noundef %s627.1)
  %s628.0 = extractvalue { i64, i64 } %614, 0
  %s628.1 = extractvalue { i64, i64 } %614, 1
; call <kernels::Fp2>::mul
  %615 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s624.0, i64 noundef %s624.1, i64 noundef %s614.0, i64 noundef %s614.1)
; call <kernels::Fp2>::mul
  %616 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s619.0, i64 noundef %s619.1, i64 noundef %s612.0, i64 noundef %s612.1)
  %s629.1 = extractvalue { i64, i64 } %615, 1
  %s629.0 = extractvalue { i64, i64 } %615, 0
  %s630.0 = extractvalue { i64, i64 } %616, 0
  %s630.1 = extractvalue { i64, i64 } %616, 1
; call <kernels::Fp2>::add
  %617 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s629.0, i64 noundef %s629.1, i64 noundef %s630.0, i64 noundef %s630.1)
  %s631.0 = extractvalue { i64, i64 } %617, 0
  %s631.1 = extractvalue { i64, i64 } %617, 1
; call <kernels::Fp2>::mul
  %618 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s619.0, i64 noundef %s619.1, i64 noundef %s614.0, i64 noundef %s614.1)
  %s632.0 = extractvalue { i64, i64 } %618, 0
  %s632.1 = extractvalue { i64, i64 } %618, 1
; call <kernels::Fp2>::add
  %619 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s605.0, i64 noundef %s605.1, i64 noundef %s612.0, i64 noundef %s612.1)
; call <kernels::Fp2>::add
  %620 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s607.0, i64 noundef %s607.1, i64 noundef %s614.0, i64 noundef %s614.1)
  %s633.1 = extractvalue { i64, i64 } %619, 1
  %s633.0 = extractvalue { i64, i64 } %619, 0
; call <kernels::Fp2>::sub
  %621 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s625.0, i64 noundef %s625.1, i64 noundef %s633.0, i64 noundef %s633.1)
  %s634.1 = extractvalue { i64, i64 } %620, 1
  %s634.0 = extractvalue { i64, i64 } %620, 0
  %s635.0 = extractvalue { i64, i64 } %621, 0
  %s635.1 = extractvalue { i64, i64 } %621, 1
; call <kernels::Fp2>::sub
  %622 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s628.0, i64 noundef %s628.1, i64 noundef %s634.0, i64 noundef %s634.1)
  %s636.0 = extractvalue { i64, i64 } %622, 0
  %s636.1 = extractvalue { i64, i64 } %622, 1
  %_0.i89 = getelementptr inbounds nuw i8, ptr %params, i64 1184
  %s637.0 = load i64, ptr %_0.i89, align 8, !noundef !3
  %623 = getelementptr inbounds nuw i8, ptr %params, i64 1192
  %s637.1 = load i64, ptr %623, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %624 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s635.0, i64 noundef %s635.1, i64 noundef %s637.0, i64 noundef %s637.1)
  %s638.0 = extractvalue { i64, i64 } %624, 0
  %s638.1 = extractvalue { i64, i64 } %624, 1
; call <kernels::Fp2>::mul
  %625 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s636.0, i64 noundef %s636.1, i64 noundef %s637.0, i64 noundef %s637.1)
  %s639.0 = extractvalue { i64, i64 } %625, 0
  %s639.1 = extractvalue { i64, i64 } %625, 1
; call <kernels::Fp2>::mul
  %626 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s631.0, i64 noundef %s631.1, i64 noundef %s637.0, i64 noundef %s637.1)
  %s640.0 = extractvalue { i64, i64 } %626, 0
  %s640.1 = extractvalue { i64, i64 } %626, 1
; call <kernels::Fp2>::mul
  %627 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s632.0, i64 noundef %s632.1, i64 noundef %s637.0, i64 noundef %s637.1)
  %s641.0 = extractvalue { i64, i64 } %627, 0
  %s641.1 = extractvalue { i64, i64 } %627, 1
; call <kernels::Fp2>::add
  %628 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s597.0, i64 noundef %s597.1, i64 noundef %s638.0, i64 noundef %s638.1)
  %s642.0 = extractvalue { i64, i64 } %628, 0
  %s642.1 = extractvalue { i64, i64 } %628, 1
; call <kernels::Fp2>::add
  %629 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s598.0, i64 noundef %s598.1, i64 noundef %s639.0, i64 noundef %s639.1)
  %s643.0 = extractvalue { i64, i64 } %629, 0
  %s643.1 = extractvalue { i64, i64 } %629, 1
; call <kernels::Fp2>::add
  %630 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s599.0, i64 noundef %s599.1, i64 noundef %s640.0, i64 noundef %s640.1)
  %s644.0 = extractvalue { i64, i64 } %630, 0
  %s644.1 = extractvalue { i64, i64 } %630, 1
; call <kernels::Fp2>::add
  %631 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s600.0, i64 noundef %s600.1, i64 noundef %s641.0, i64 noundef %s641.1)
  %s645.0 = extractvalue { i64, i64 } %631, 0
  %s645.1 = extractvalue { i64, i64 } %631, 1
  %_0.i88 = getelementptr inbounds nuw i8, ptr %params, i64 1200
  %s646.0 = load i64, ptr %_0.i88, align 8, !noundef !3
  %632 = getelementptr inbounds nuw i8, ptr %params, i64 1208
  %s646.1 = load i64, ptr %632, align 8, !noundef !3
  %_0.i87 = getelementptr inbounds nuw i8, ptr %raw, i64 640
  %s647.0 = load i64, ptr %_0.i87, align 8, !noundef !3
  %633 = getelementptr inbounds nuw i8, ptr %raw, i64 648
  %s647.1 = load i64, ptr %633, align 8, !noundef !3
  %_0.i86 = getelementptr inbounds nuw i8, ptr %raw, i64 656
  %s648.0 = load i64, ptr %_0.i86, align 8, !noundef !3
  %634 = getelementptr inbounds nuw i8, ptr %raw, i64 664
  %s648.1 = load i64, ptr %634, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %635 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s648.0, i64 noundef %s648.1, i64 noundef %s647.0, i64 noundef %s647.1)
  %s649.0 = extractvalue { i64, i64 } %635, 0
  %s649.1 = extractvalue { i64, i64 } %635, 1
  %_0.i273 = getelementptr inbounds nuw i8, ptr %bases, i64 112
  %s650 = load i64, ptr %_0.i273, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %636 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s647.0, i64 noundef %s647.1, i64 noundef %s650)
; call <kernels::Fp2>::mul_base
  %637 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s649.0, i64 noundef %s649.1, i64 noundef %s650)
  %s651.1 = extractvalue { i64, i64 } %636, 1
  %s651.0 = extractvalue { i64, i64 } %636, 0
  %s652.0 = extractvalue { i64, i64 } %637, 0
  %s652.1 = extractvalue { i64, i64 } %637, 1
; call <kernels::Fp2>::sub
  %638 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s646.0, i64 noundef %s646.1, i64 noundef %s651.0, i64 noundef %s651.1)
  %s653.0 = extractvalue { i64, i64 } %638, 0
  %s653.1 = extractvalue { i64, i64 } %638, 1
  %_0.i85 = getelementptr inbounds nuw i8, ptr %params, i64 1216
  %s654.0 = load i64, ptr %_0.i85, align 8, !noundef !3
  %639 = getelementptr inbounds nuw i8, ptr %params, i64 1224
  %s654.1 = load i64, ptr %639, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %640 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s654.0, i64 noundef %s654.1, i64 noundef %s652.0, i64 noundef %s652.1)
  %s655.0 = extractvalue { i64, i64 } %640, 0
  %s655.1 = extractvalue { i64, i64 } %640, 1
  %_0.i84 = getelementptr inbounds nuw i8, ptr %params, i64 1232
  %s656.0 = load i64, ptr %_0.i84, align 8, !noundef !3
  %641 = getelementptr inbounds nuw i8, ptr %params, i64 1240
  %s656.1 = load i64, ptr %641, align 8, !noundef !3
  %_0.i272 = getelementptr inbounds nuw i8, ptr %bases, i64 120
  %s657 = load i64, ptr %_0.i272, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %642 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s647.0, i64 noundef %s647.1, i64 noundef %s657)
; call <kernels::Fp2>::mul_base
  %643 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s649.0, i64 noundef %s649.1, i64 noundef %s657)
  %s658.1 = extractvalue { i64, i64 } %642, 1
  %s658.0 = extractvalue { i64, i64 } %642, 0
  %s659.0 = extractvalue { i64, i64 } %643, 0
  %s659.1 = extractvalue { i64, i64 } %643, 1
; call <kernels::Fp2>::sub
  %644 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s656.0, i64 noundef %s656.1, i64 noundef %s658.0, i64 noundef %s658.1)
  %s660.0 = extractvalue { i64, i64 } %644, 0
  %s660.1 = extractvalue { i64, i64 } %644, 1
  %_0.i83 = getelementptr inbounds nuw i8, ptr %params, i64 1248
  %s661.0 = load i64, ptr %_0.i83, align 8, !noundef !3
  %645 = getelementptr inbounds nuw i8, ptr %params, i64 1256
  %s661.1 = load i64, ptr %645, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %646 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s661.0, i64 noundef %s661.1, i64 noundef %s659.0, i64 noundef %s659.1)
  %s662.0 = extractvalue { i64, i64 } %646, 0
  %s662.1 = extractvalue { i64, i64 } %646, 1
  %_0.i82 = getelementptr inbounds nuw i8, ptr %raw, i64 1568
  %s663.0 = load i64, ptr %_0.i82, align 8, !noundef !3
  %647 = getelementptr inbounds nuw i8, ptr %raw, i64 1576
  %s663.1 = load i64, ptr %647, align 8, !noundef !3
  %_0.i81 = getelementptr inbounds nuw i8, ptr %raw, i64 1584
  %s664.0 = load i64, ptr %_0.i81, align 8, !noundef !3
  %648 = getelementptr inbounds nuw i8, ptr %raw, i64 1592
  %s664.1 = load i64, ptr %648, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %649 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s664.0, i64 noundef %s664.1, i64 noundef %s663.0, i64 noundef %s663.1)
  %s665.0 = extractvalue { i64, i64 } %649, 0
  %s665.1 = extractvalue { i64, i64 } %649, 1
; call <kernels::Fp2>::mul
  %650 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s663.0, i64 noundef %s663.1, i64 noundef %s653.0, i64 noundef %s653.1)
  %s666.0 = extractvalue { i64, i64 } %650, 0
  %s666.1 = extractvalue { i64, i64 } %650, 1
; call <kernels::Fp2>::mul
  %651 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s665.0, i64 noundef %s665.1, i64 noundef %s655.0, i64 noundef %s655.1)
  %s667.0 = extractvalue { i64, i64 } %651, 0
  %s667.1 = extractvalue { i64, i64 } %651, 1
; call <kernels::Fp2>::add
  %652 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s663.0, i64 noundef %s663.1, i64 noundef %s665.0, i64 noundef %s665.1)
; call <kernels::Fp2>::add
  %653 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s653.0, i64 noundef %s653.1, i64 noundef %s655.0, i64 noundef %s655.1)
  %s668.1 = extractvalue { i64, i64 } %652, 1
  %s668.0 = extractvalue { i64, i64 } %652, 0
  %s669.0 = extractvalue { i64, i64 } %653, 0
  %s669.1 = extractvalue { i64, i64 } %653, 1
; call <kernels::Fp2>::mul
  %654 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s668.0, i64 noundef %s668.1, i64 noundef %s669.0, i64 noundef %s669.1)
  %s670.0 = extractvalue { i64, i64 } %654, 0
  %s670.1 = extractvalue { i64, i64 } %654, 1
; call <kernels::Fp2>::sub
  %655 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s670.0, i64 noundef %s670.1, i64 noundef %s666.0, i64 noundef %s666.1)
  %s671.0 = extractvalue { i64, i64 } %655, 0
  %s671.1 = extractvalue { i64, i64 } %655, 1
; call <kernels::Fp2>::sub
  %656 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s671.0, i64 noundef %s671.1, i64 noundef %s667.0, i64 noundef %s667.1)
  %s672.0 = extractvalue { i64, i64 } %656, 0
  %s672.1 = extractvalue { i64, i64 } %656, 1
; call <kernels::Fp2>::mul
  %657 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s666.0, i64 noundef %s666.1, i64 noundef %s660.0, i64 noundef %s660.1)
  %s673.0 = extractvalue { i64, i64 } %657, 0
  %s673.1 = extractvalue { i64, i64 } %657, 1
; call <kernels::Fp2>::mul
  %658 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s666.0, i64 noundef %s666.1, i64 noundef %s662.0, i64 noundef %s662.1)
; call <kernels::Fp2>::mul
  %659 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s672.0, i64 noundef %s672.1, i64 noundef %s660.0, i64 noundef %s660.1)
  %s674.1 = extractvalue { i64, i64 } %658, 1
  %s674.0 = extractvalue { i64, i64 } %658, 0
  %s675.0 = extractvalue { i64, i64 } %659, 0
  %s675.1 = extractvalue { i64, i64 } %659, 1
; call <kernels::Fp2>::add
  %660 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s674.0, i64 noundef %s674.1, i64 noundef %s675.0, i64 noundef %s675.1)
  %s676.0 = extractvalue { i64, i64 } %660, 0
  %s676.1 = extractvalue { i64, i64 } %660, 1
; call <kernels::Fp2>::mul
  %661 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s672.0, i64 noundef %s672.1, i64 noundef %s662.0, i64 noundef %s662.1)
; call <kernels::Fp2>::mul
  %662 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s667.0, i64 noundef %s667.1, i64 noundef %s660.0, i64 noundef %s660.1)
  %s677.1 = extractvalue { i64, i64 } %661, 1
  %s677.0 = extractvalue { i64, i64 } %661, 0
  %s678.0 = extractvalue { i64, i64 } %662, 0
  %s678.1 = extractvalue { i64, i64 } %662, 1
; call <kernels::Fp2>::add
  %663 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s677.0, i64 noundef %s677.1, i64 noundef %s678.0, i64 noundef %s678.1)
  %s679.0 = extractvalue { i64, i64 } %663, 0
  %s679.1 = extractvalue { i64, i64 } %663, 1
; call <kernels::Fp2>::mul
  %664 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s667.0, i64 noundef %s667.1, i64 noundef %s662.0, i64 noundef %s662.1)
  %s680.0 = extractvalue { i64, i64 } %664, 0
  %s680.1 = extractvalue { i64, i64 } %664, 1
; call <kernels::Fp2>::add
  %665 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s653.0, i64 noundef %s653.1, i64 noundef %s660.0, i64 noundef %s660.1)
; call <kernels::Fp2>::add
  %666 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s655.0, i64 noundef %s655.1, i64 noundef %s662.0, i64 noundef %s662.1)
  %s681.1 = extractvalue { i64, i64 } %665, 1
  %s681.0 = extractvalue { i64, i64 } %665, 0
; call <kernels::Fp2>::sub
  %667 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s673.0, i64 noundef %s673.1, i64 noundef %s681.0, i64 noundef %s681.1)
  %s682.1 = extractvalue { i64, i64 } %666, 1
  %s682.0 = extractvalue { i64, i64 } %666, 0
  %s683.0 = extractvalue { i64, i64 } %667, 0
  %s683.1 = extractvalue { i64, i64 } %667, 1
; call <kernels::Fp2>::sub
  %668 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s676.0, i64 noundef %s676.1, i64 noundef %s682.0, i64 noundef %s682.1)
  %s684.0 = extractvalue { i64, i64 } %668, 0
  %s684.1 = extractvalue { i64, i64 } %668, 1
  %_0.i80 = getelementptr inbounds nuw i8, ptr %params, i64 1264
  %s685.0 = load i64, ptr %_0.i80, align 8, !noundef !3
  %669 = getelementptr inbounds nuw i8, ptr %params, i64 1272
  %s685.1 = load i64, ptr %669, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %670 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s683.0, i64 noundef %s683.1, i64 noundef %s685.0, i64 noundef %s685.1)
  %s686.0 = extractvalue { i64, i64 } %670, 0
  %s686.1 = extractvalue { i64, i64 } %670, 1
; call <kernels::Fp2>::mul
  %671 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s684.0, i64 noundef %s684.1, i64 noundef %s685.0, i64 noundef %s685.1)
  %s687.0 = extractvalue { i64, i64 } %671, 0
  %s687.1 = extractvalue { i64, i64 } %671, 1
; call <kernels::Fp2>::mul
  %672 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s679.0, i64 noundef %s679.1, i64 noundef %s685.0, i64 noundef %s685.1)
  %s688.0 = extractvalue { i64, i64 } %672, 0
  %s688.1 = extractvalue { i64, i64 } %672, 1
; call <kernels::Fp2>::mul
  %673 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s680.0, i64 noundef %s680.1, i64 noundef %s685.0, i64 noundef %s685.1)
  %s689.0 = extractvalue { i64, i64 } %673, 0
  %s689.1 = extractvalue { i64, i64 } %673, 1
; call <kernels::Fp2>::add
  %674 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s642.0, i64 noundef %s642.1, i64 noundef %s686.0, i64 noundef %s686.1)
  %s690.0 = extractvalue { i64, i64 } %674, 0
  %s690.1 = extractvalue { i64, i64 } %674, 1
; call <kernels::Fp2>::add
  %675 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s643.0, i64 noundef %s643.1, i64 noundef %s687.0, i64 noundef %s687.1)
  %s691.0 = extractvalue { i64, i64 } %675, 0
  %s691.1 = extractvalue { i64, i64 } %675, 1
; call <kernels::Fp2>::add
  %676 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s644.0, i64 noundef %s644.1, i64 noundef %s688.0, i64 noundef %s688.1)
  %s692.0 = extractvalue { i64, i64 } %676, 0
  %s692.1 = extractvalue { i64, i64 } %676, 1
; call <kernels::Fp2>::add
  %677 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s645.0, i64 noundef %s645.1, i64 noundef %s689.0, i64 noundef %s689.1)
  %s693.0 = extractvalue { i64, i64 } %677, 0
  %s693.1 = extractvalue { i64, i64 } %677, 1
  %_0.i79 = getelementptr inbounds nuw i8, ptr %params, i64 1280
  %s694.0 = load i64, ptr %_0.i79, align 8, !noundef !3
  %678 = getelementptr inbounds nuw i8, ptr %params, i64 1288
  %s694.1 = load i64, ptr %678, align 8, !noundef !3
  %_0.i271 = getelementptr inbounds nuw i8, ptr %bases, i64 128
  %s695 = load i64, ptr %_0.i271, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %679 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s90.0, i64 noundef %s90.1, i64 noundef %s695)
; call <kernels::Fp2>::mul_base
  %680 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s92.0, i64 noundef %s92.1, i64 noundef %s695)
  %s696.1 = extractvalue { i64, i64 } %679, 1
  %s696.0 = extractvalue { i64, i64 } %679, 0
  %s697.0 = extractvalue { i64, i64 } %680, 0
  %s697.1 = extractvalue { i64, i64 } %680, 1
; call <kernels::Fp2>::sub
  %681 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s694.0, i64 noundef %s694.1, i64 noundef %s696.0, i64 noundef %s696.1)
  %s698.0 = extractvalue { i64, i64 } %681, 0
  %s698.1 = extractvalue { i64, i64 } %681, 1
  %_0.i78 = getelementptr inbounds nuw i8, ptr %params, i64 1296
  %s699.0 = load i64, ptr %_0.i78, align 8, !noundef !3
  %682 = getelementptr inbounds nuw i8, ptr %params, i64 1304
  %s699.1 = load i64, ptr %682, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %683 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s699.0, i64 noundef %s699.1, i64 noundef %s697.0, i64 noundef %s697.1)
  %s700.0 = extractvalue { i64, i64 } %683, 0
  %s700.1 = extractvalue { i64, i64 } %683, 1
  %_0.i77 = getelementptr inbounds nuw i8, ptr %params, i64 1312
  %s701.0 = load i64, ptr %_0.i77, align 8, !noundef !3
  %684 = getelementptr inbounds nuw i8, ptr %params, i64 1320
  %s701.1 = load i64, ptr %684, align 8, !noundef !3
  %_0.i270 = getelementptr inbounds nuw i8, ptr %bases, i64 136
  %s702 = load i64, ptr %_0.i270, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %685 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s98.0, i64 noundef %s98.1, i64 noundef %s702)
; call <kernels::Fp2>::mul_base
  %686 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s100.0, i64 noundef %s100.1, i64 noundef %s702)
  %s703.1 = extractvalue { i64, i64 } %685, 1
  %s703.0 = extractvalue { i64, i64 } %685, 0
  %s704.0 = extractvalue { i64, i64 } %686, 0
  %s704.1 = extractvalue { i64, i64 } %686, 1
; call <kernels::Fp2>::sub
  %687 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s701.0, i64 noundef %s701.1, i64 noundef %s703.0, i64 noundef %s703.1)
  %s705.0 = extractvalue { i64, i64 } %687, 0
  %s705.1 = extractvalue { i64, i64 } %687, 1
  %_0.i76 = getelementptr inbounds nuw i8, ptr %params, i64 1328
  %s706.0 = load i64, ptr %_0.i76, align 8, !noundef !3
  %688 = getelementptr inbounds nuw i8, ptr %params, i64 1336
  %s706.1 = load i64, ptr %688, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %689 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s706.0, i64 noundef %s706.1, i64 noundef %s704.0, i64 noundef %s704.1)
  %s707.0 = extractvalue { i64, i64 } %689, 0
  %s707.1 = extractvalue { i64, i64 } %689, 1
  %_0.i75 = getelementptr inbounds nuw i8, ptr %raw, i64 1600
  %s708.0 = load i64, ptr %_0.i75, align 8, !noundef !3
  %690 = getelementptr inbounds nuw i8, ptr %raw, i64 1608
  %s708.1 = load i64, ptr %690, align 8, !noundef !3
  %_0.i74 = getelementptr inbounds nuw i8, ptr %raw, i64 1616
  %s709.0 = load i64, ptr %_0.i74, align 8, !noundef !3
  %691 = getelementptr inbounds nuw i8, ptr %raw, i64 1624
  %s709.1 = load i64, ptr %691, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %692 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s709.0, i64 noundef %s709.1, i64 noundef %s708.0, i64 noundef %s708.1)
  %s710.0 = extractvalue { i64, i64 } %692, 0
  %s710.1 = extractvalue { i64, i64 } %692, 1
; call <kernels::Fp2>::mul
  %693 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s708.0, i64 noundef %s708.1, i64 noundef %s698.0, i64 noundef %s698.1)
  %s711.0 = extractvalue { i64, i64 } %693, 0
  %s711.1 = extractvalue { i64, i64 } %693, 1
; call <kernels::Fp2>::mul
  %694 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s710.0, i64 noundef %s710.1, i64 noundef %s700.0, i64 noundef %s700.1)
  %s712.0 = extractvalue { i64, i64 } %694, 0
  %s712.1 = extractvalue { i64, i64 } %694, 1
; call <kernels::Fp2>::add
  %695 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s708.0, i64 noundef %s708.1, i64 noundef %s710.0, i64 noundef %s710.1)
; call <kernels::Fp2>::add
  %696 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s698.0, i64 noundef %s698.1, i64 noundef %s700.0, i64 noundef %s700.1)
  %s713.1 = extractvalue { i64, i64 } %695, 1
  %s713.0 = extractvalue { i64, i64 } %695, 0
  %s714.0 = extractvalue { i64, i64 } %696, 0
  %s714.1 = extractvalue { i64, i64 } %696, 1
; call <kernels::Fp2>::mul
  %697 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s713.0, i64 noundef %s713.1, i64 noundef %s714.0, i64 noundef %s714.1)
  %s715.0 = extractvalue { i64, i64 } %697, 0
  %s715.1 = extractvalue { i64, i64 } %697, 1
; call <kernels::Fp2>::sub
  %698 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s715.0, i64 noundef %s715.1, i64 noundef %s711.0, i64 noundef %s711.1)
  %s716.0 = extractvalue { i64, i64 } %698, 0
  %s716.1 = extractvalue { i64, i64 } %698, 1
; call <kernels::Fp2>::sub
  %699 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s716.0, i64 noundef %s716.1, i64 noundef %s712.0, i64 noundef %s712.1)
  %s717.0 = extractvalue { i64, i64 } %699, 0
  %s717.1 = extractvalue { i64, i64 } %699, 1
; call <kernels::Fp2>::mul
  %700 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s711.0, i64 noundef %s711.1, i64 noundef %s705.0, i64 noundef %s705.1)
  %s718.0 = extractvalue { i64, i64 } %700, 0
  %s718.1 = extractvalue { i64, i64 } %700, 1
; call <kernels::Fp2>::mul
  %701 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s711.0, i64 noundef %s711.1, i64 noundef %s707.0, i64 noundef %s707.1)
; call <kernels::Fp2>::mul
  %702 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s717.0, i64 noundef %s717.1, i64 noundef %s705.0, i64 noundef %s705.1)
  %s719.1 = extractvalue { i64, i64 } %701, 1
  %s719.0 = extractvalue { i64, i64 } %701, 0
  %s720.0 = extractvalue { i64, i64 } %702, 0
  %s720.1 = extractvalue { i64, i64 } %702, 1
; call <kernels::Fp2>::add
  %703 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s719.0, i64 noundef %s719.1, i64 noundef %s720.0, i64 noundef %s720.1)
  %s721.0 = extractvalue { i64, i64 } %703, 0
  %s721.1 = extractvalue { i64, i64 } %703, 1
; call <kernels::Fp2>::mul
  %704 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s717.0, i64 noundef %s717.1, i64 noundef %s707.0, i64 noundef %s707.1)
; call <kernels::Fp2>::mul
  %705 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s712.0, i64 noundef %s712.1, i64 noundef %s705.0, i64 noundef %s705.1)
  %s722.1 = extractvalue { i64, i64 } %704, 1
  %s722.0 = extractvalue { i64, i64 } %704, 0
  %s723.0 = extractvalue { i64, i64 } %705, 0
  %s723.1 = extractvalue { i64, i64 } %705, 1
; call <kernels::Fp2>::add
  %706 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s722.0, i64 noundef %s722.1, i64 noundef %s723.0, i64 noundef %s723.1)
  %s724.0 = extractvalue { i64, i64 } %706, 0
  %s724.1 = extractvalue { i64, i64 } %706, 1
; call <kernels::Fp2>::mul
  %707 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s712.0, i64 noundef %s712.1, i64 noundef %s707.0, i64 noundef %s707.1)
  %s725.0 = extractvalue { i64, i64 } %707, 0
  %s725.1 = extractvalue { i64, i64 } %707, 1
; call <kernels::Fp2>::add
  %708 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s698.0, i64 noundef %s698.1, i64 noundef %s705.0, i64 noundef %s705.1)
; call <kernels::Fp2>::add
  %709 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s700.0, i64 noundef %s700.1, i64 noundef %s707.0, i64 noundef %s707.1)
  %s726.1 = extractvalue { i64, i64 } %708, 1
  %s726.0 = extractvalue { i64, i64 } %708, 0
; call <kernels::Fp2>::sub
  %710 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s718.0, i64 noundef %s718.1, i64 noundef %s726.0, i64 noundef %s726.1)
  %s727.1 = extractvalue { i64, i64 } %709, 1
  %s727.0 = extractvalue { i64, i64 } %709, 0
  %s728.0 = extractvalue { i64, i64 } %710, 0
  %s728.1 = extractvalue { i64, i64 } %710, 1
; call <kernels::Fp2>::sub
  %711 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s721.0, i64 noundef %s721.1, i64 noundef %s727.0, i64 noundef %s727.1)
  %s729.0 = extractvalue { i64, i64 } %711, 0
  %s729.1 = extractvalue { i64, i64 } %711, 1
  %_0.i73 = getelementptr inbounds nuw i8, ptr %params, i64 1344
  %s730.0 = load i64, ptr %_0.i73, align 8, !noundef !3
  %712 = getelementptr inbounds nuw i8, ptr %params, i64 1352
  %s730.1 = load i64, ptr %712, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %713 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s728.0, i64 noundef %s728.1, i64 noundef %s730.0, i64 noundef %s730.1)
  %s731.0 = extractvalue { i64, i64 } %713, 0
  %s731.1 = extractvalue { i64, i64 } %713, 1
; call <kernels::Fp2>::mul
  %714 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s729.0, i64 noundef %s729.1, i64 noundef %s730.0, i64 noundef %s730.1)
  %s732.0 = extractvalue { i64, i64 } %714, 0
  %s732.1 = extractvalue { i64, i64 } %714, 1
; call <kernels::Fp2>::mul
  %715 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s724.0, i64 noundef %s724.1, i64 noundef %s730.0, i64 noundef %s730.1)
  %s733.0 = extractvalue { i64, i64 } %715, 0
  %s733.1 = extractvalue { i64, i64 } %715, 1
; call <kernels::Fp2>::mul
  %716 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s725.0, i64 noundef %s725.1, i64 noundef %s730.0, i64 noundef %s730.1)
  %s734.0 = extractvalue { i64, i64 } %716, 0
  %s734.1 = extractvalue { i64, i64 } %716, 1
; call <kernels::Fp2>::add
  %717 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s690.0, i64 noundef %s690.1, i64 noundef %s731.0, i64 noundef %s731.1)
  %s735.0 = extractvalue { i64, i64 } %717, 0
  %s735.1 = extractvalue { i64, i64 } %717, 1
; call <kernels::Fp2>::add
  %718 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s691.0, i64 noundef %s691.1, i64 noundef %s732.0, i64 noundef %s732.1)
  %s736.0 = extractvalue { i64, i64 } %718, 0
  %s736.1 = extractvalue { i64, i64 } %718, 1
; call <kernels::Fp2>::add
  %719 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s692.0, i64 noundef %s692.1, i64 noundef %s733.0, i64 noundef %s733.1)
  %s737.0 = extractvalue { i64, i64 } %719, 0
  %s737.1 = extractvalue { i64, i64 } %719, 1
; call <kernels::Fp2>::add
  %720 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s693.0, i64 noundef %s693.1, i64 noundef %s734.0, i64 noundef %s734.1)
  %s738.0 = extractvalue { i64, i64 } %720, 0
  %s738.1 = extractvalue { i64, i64 } %720, 1
  %_0.i72 = getelementptr inbounds nuw i8, ptr %params, i64 1360
  %s739.0 = load i64, ptr %_0.i72, align 8, !noundef !3
  %721 = getelementptr inbounds nuw i8, ptr %params, i64 1368
  %s739.1 = load i64, ptr %721, align 8, !noundef !3
  %_0.i269 = getelementptr inbounds nuw i8, ptr %bases, i64 144
  %s740 = load i64, ptr %_0.i269, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %722 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s316.0, i64 noundef %s316.1, i64 noundef %s740)
; call <kernels::Fp2>::mul_base
  %723 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s318.0, i64 noundef %s318.1, i64 noundef %s740)
  %s741.1 = extractvalue { i64, i64 } %722, 1
  %s741.0 = extractvalue { i64, i64 } %722, 0
  %s742.0 = extractvalue { i64, i64 } %723, 0
  %s742.1 = extractvalue { i64, i64 } %723, 1
; call <kernels::Fp2>::sub
  %724 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s739.0, i64 noundef %s739.1, i64 noundef %s741.0, i64 noundef %s741.1)
  %s743.0 = extractvalue { i64, i64 } %724, 0
  %s743.1 = extractvalue { i64, i64 } %724, 1
  %_0.i71 = getelementptr inbounds nuw i8, ptr %params, i64 1376
  %s744.0 = load i64, ptr %_0.i71, align 8, !noundef !3
  %725 = getelementptr inbounds nuw i8, ptr %params, i64 1384
  %s744.1 = load i64, ptr %725, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %726 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s744.0, i64 noundef %s744.1, i64 noundef %s742.0, i64 noundef %s742.1)
  %s745.0 = extractvalue { i64, i64 } %726, 0
  %s745.1 = extractvalue { i64, i64 } %726, 1
  %_0.i70 = getelementptr inbounds nuw i8, ptr %params, i64 1392
  %s746.0 = load i64, ptr %_0.i70, align 8, !noundef !3
  %727 = getelementptr inbounds nuw i8, ptr %params, i64 1400
  %s746.1 = load i64, ptr %727, align 8, !noundef !3
  %_0.i268 = getelementptr inbounds nuw i8, ptr %bases, i64 152
  %s747 = load i64, ptr %_0.i268, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %728 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s316.0, i64 noundef %s316.1, i64 noundef %s747)
; call <kernels::Fp2>::mul_base
  %729 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s318.0, i64 noundef %s318.1, i64 noundef %s747)
  %s748.1 = extractvalue { i64, i64 } %728, 1
  %s748.0 = extractvalue { i64, i64 } %728, 0
  %s749.0 = extractvalue { i64, i64 } %729, 0
  %s749.1 = extractvalue { i64, i64 } %729, 1
; call <kernels::Fp2>::sub
  %730 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s746.0, i64 noundef %s746.1, i64 noundef %s748.0, i64 noundef %s748.1)
  %s750.0 = extractvalue { i64, i64 } %730, 0
  %s750.1 = extractvalue { i64, i64 } %730, 1
  %_0.i69 = getelementptr inbounds nuw i8, ptr %params, i64 1408
  %s751.0 = load i64, ptr %_0.i69, align 8, !noundef !3
  %731 = getelementptr inbounds nuw i8, ptr %params, i64 1416
  %s751.1 = load i64, ptr %731, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %732 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s751.0, i64 noundef %s751.1, i64 noundef %s749.0, i64 noundef %s749.1)
  %s752.0 = extractvalue { i64, i64 } %732, 0
  %s752.1 = extractvalue { i64, i64 } %732, 1
  %_0.i68 = getelementptr inbounds nuw i8, ptr %raw, i64 1632
  %s753.0 = load i64, ptr %_0.i68, align 8, !noundef !3
  %733 = getelementptr inbounds nuw i8, ptr %raw, i64 1640
  %s753.1 = load i64, ptr %733, align 8, !noundef !3
  %_0.i67 = getelementptr inbounds nuw i8, ptr %raw, i64 1648
  %s754.0 = load i64, ptr %_0.i67, align 8, !noundef !3
  %734 = getelementptr inbounds nuw i8, ptr %raw, i64 1656
  %s754.1 = load i64, ptr %734, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %735 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s754.0, i64 noundef %s754.1, i64 noundef %s753.0, i64 noundef %s753.1)
  %s755.0 = extractvalue { i64, i64 } %735, 0
  %s755.1 = extractvalue { i64, i64 } %735, 1
; call <kernels::Fp2>::mul
  %736 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s753.0, i64 noundef %s753.1, i64 noundef %s743.0, i64 noundef %s743.1)
  %s756.0 = extractvalue { i64, i64 } %736, 0
  %s756.1 = extractvalue { i64, i64 } %736, 1
; call <kernels::Fp2>::mul
  %737 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s755.0, i64 noundef %s755.1, i64 noundef %s745.0, i64 noundef %s745.1)
  %s757.0 = extractvalue { i64, i64 } %737, 0
  %s757.1 = extractvalue { i64, i64 } %737, 1
; call <kernels::Fp2>::add
  %738 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s753.0, i64 noundef %s753.1, i64 noundef %s755.0, i64 noundef %s755.1)
; call <kernels::Fp2>::add
  %739 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s743.0, i64 noundef %s743.1, i64 noundef %s745.0, i64 noundef %s745.1)
  %s758.1 = extractvalue { i64, i64 } %738, 1
  %s758.0 = extractvalue { i64, i64 } %738, 0
  %s759.0 = extractvalue { i64, i64 } %739, 0
  %s759.1 = extractvalue { i64, i64 } %739, 1
; call <kernels::Fp2>::mul
  %740 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s758.0, i64 noundef %s758.1, i64 noundef %s759.0, i64 noundef %s759.1)
  %s760.0 = extractvalue { i64, i64 } %740, 0
  %s760.1 = extractvalue { i64, i64 } %740, 1
; call <kernels::Fp2>::sub
  %741 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s760.0, i64 noundef %s760.1, i64 noundef %s756.0, i64 noundef %s756.1)
  %s761.0 = extractvalue { i64, i64 } %741, 0
  %s761.1 = extractvalue { i64, i64 } %741, 1
; call <kernels::Fp2>::sub
  %742 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s761.0, i64 noundef %s761.1, i64 noundef %s757.0, i64 noundef %s757.1)
  %s762.0 = extractvalue { i64, i64 } %742, 0
  %s762.1 = extractvalue { i64, i64 } %742, 1
; call <kernels::Fp2>::mul
  %743 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s756.0, i64 noundef %s756.1, i64 noundef %s750.0, i64 noundef %s750.1)
  %s763.0 = extractvalue { i64, i64 } %743, 0
  %s763.1 = extractvalue { i64, i64 } %743, 1
; call <kernels::Fp2>::mul
  %744 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s756.0, i64 noundef %s756.1, i64 noundef %s752.0, i64 noundef %s752.1)
; call <kernels::Fp2>::mul
  %745 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s762.0, i64 noundef %s762.1, i64 noundef %s750.0, i64 noundef %s750.1)
  %s764.1 = extractvalue { i64, i64 } %744, 1
  %s764.0 = extractvalue { i64, i64 } %744, 0
  %s765.0 = extractvalue { i64, i64 } %745, 0
  %s765.1 = extractvalue { i64, i64 } %745, 1
; call <kernels::Fp2>::add
  %746 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s764.0, i64 noundef %s764.1, i64 noundef %s765.0, i64 noundef %s765.1)
  %s766.0 = extractvalue { i64, i64 } %746, 0
  %s766.1 = extractvalue { i64, i64 } %746, 1
; call <kernels::Fp2>::mul
  %747 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s762.0, i64 noundef %s762.1, i64 noundef %s752.0, i64 noundef %s752.1)
; call <kernels::Fp2>::mul
  %748 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s757.0, i64 noundef %s757.1, i64 noundef %s750.0, i64 noundef %s750.1)
  %s767.1 = extractvalue { i64, i64 } %747, 1
  %s767.0 = extractvalue { i64, i64 } %747, 0
  %s768.0 = extractvalue { i64, i64 } %748, 0
  %s768.1 = extractvalue { i64, i64 } %748, 1
; call <kernels::Fp2>::add
  %749 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s767.0, i64 noundef %s767.1, i64 noundef %s768.0, i64 noundef %s768.1)
  %s769.0 = extractvalue { i64, i64 } %749, 0
  %s769.1 = extractvalue { i64, i64 } %749, 1
; call <kernels::Fp2>::mul
  %750 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s757.0, i64 noundef %s757.1, i64 noundef %s752.0, i64 noundef %s752.1)
  %s770.0 = extractvalue { i64, i64 } %750, 0
  %s770.1 = extractvalue { i64, i64 } %750, 1
; call <kernels::Fp2>::add
  %751 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s743.0, i64 noundef %s743.1, i64 noundef %s750.0, i64 noundef %s750.1)
; call <kernels::Fp2>::add
  %752 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s745.0, i64 noundef %s745.1, i64 noundef %s752.0, i64 noundef %s752.1)
  %s771.1 = extractvalue { i64, i64 } %751, 1
  %s771.0 = extractvalue { i64, i64 } %751, 0
; call <kernels::Fp2>::sub
  %753 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s763.0, i64 noundef %s763.1, i64 noundef %s771.0, i64 noundef %s771.1)
  %s772.1 = extractvalue { i64, i64 } %752, 1
  %s772.0 = extractvalue { i64, i64 } %752, 0
  %s773.0 = extractvalue { i64, i64 } %753, 0
  %s773.1 = extractvalue { i64, i64 } %753, 1
; call <kernels::Fp2>::sub
  %754 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s766.0, i64 noundef %s766.1, i64 noundef %s772.0, i64 noundef %s772.1)
  %s774.0 = extractvalue { i64, i64 } %754, 0
  %s774.1 = extractvalue { i64, i64 } %754, 1
  %_0.i66 = getelementptr inbounds nuw i8, ptr %params, i64 1424
  %s775.0 = load i64, ptr %_0.i66, align 8, !noundef !3
  %755 = getelementptr inbounds nuw i8, ptr %params, i64 1432
  %s775.1 = load i64, ptr %755, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %756 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s773.0, i64 noundef %s773.1, i64 noundef %s775.0, i64 noundef %s775.1)
  %s776.0 = extractvalue { i64, i64 } %756, 0
  %s776.1 = extractvalue { i64, i64 } %756, 1
; call <kernels::Fp2>::mul
  %757 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s774.0, i64 noundef %s774.1, i64 noundef %s775.0, i64 noundef %s775.1)
  %s777.0 = extractvalue { i64, i64 } %757, 0
  %s777.1 = extractvalue { i64, i64 } %757, 1
; call <kernels::Fp2>::mul
  %758 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s769.0, i64 noundef %s769.1, i64 noundef %s775.0, i64 noundef %s775.1)
  %s778.0 = extractvalue { i64, i64 } %758, 0
  %s778.1 = extractvalue { i64, i64 } %758, 1
; call <kernels::Fp2>::mul
  %759 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s770.0, i64 noundef %s770.1, i64 noundef %s775.0, i64 noundef %s775.1)
  %s779.0 = extractvalue { i64, i64 } %759, 0
  %s779.1 = extractvalue { i64, i64 } %759, 1
; call <kernels::Fp2>::add
  %760 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s735.0, i64 noundef %s735.1, i64 noundef %s776.0, i64 noundef %s776.1)
  %s780.0 = extractvalue { i64, i64 } %760, 0
  %s780.1 = extractvalue { i64, i64 } %760, 1
; call <kernels::Fp2>::add
  %761 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s736.0, i64 noundef %s736.1, i64 noundef %s777.0, i64 noundef %s777.1)
  %s781.0 = extractvalue { i64, i64 } %761, 0
  %s781.1 = extractvalue { i64, i64 } %761, 1
; call <kernels::Fp2>::add
  %762 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s737.0, i64 noundef %s737.1, i64 noundef %s778.0, i64 noundef %s778.1)
  %s782.0 = extractvalue { i64, i64 } %762, 0
  %s782.1 = extractvalue { i64, i64 } %762, 1
; call <kernels::Fp2>::add
  %763 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s738.0, i64 noundef %s738.1, i64 noundef %s779.0, i64 noundef %s779.1)
  %s783.0 = extractvalue { i64, i64 } %763, 0
  %s783.1 = extractvalue { i64, i64 } %763, 1
  %_0.i65 = getelementptr inbounds nuw i8, ptr %params, i64 1440
  %s784.0 = load i64, ptr %_0.i65, align 8, !noundef !3
  %764 = getelementptr inbounds nuw i8, ptr %params, i64 1448
  %s784.1 = load i64, ptr %764, align 8, !noundef !3
  %_0.i267 = getelementptr inbounds nuw i8, ptr %bases, i64 160
  %s785 = load i64, ptr %_0.i267, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %765 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s202.0, i64 noundef %s202.1, i64 noundef %s785)
; call <kernels::Fp2>::mul_base
  %766 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s204.0, i64 noundef %s204.1, i64 noundef %s785)
  %s786.1 = extractvalue { i64, i64 } %765, 1
  %s786.0 = extractvalue { i64, i64 } %765, 0
  %s787.0 = extractvalue { i64, i64 } %766, 0
  %s787.1 = extractvalue { i64, i64 } %766, 1
; call <kernels::Fp2>::sub
  %767 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s784.0, i64 noundef %s784.1, i64 noundef %s786.0, i64 noundef %s786.1)
  %s788.0 = extractvalue { i64, i64 } %767, 0
  %s788.1 = extractvalue { i64, i64 } %767, 1
  %_0.i64 = getelementptr inbounds nuw i8, ptr %params, i64 1456
  %s789.0 = load i64, ptr %_0.i64, align 8, !noundef !3
  %768 = getelementptr inbounds nuw i8, ptr %params, i64 1464
  %s789.1 = load i64, ptr %768, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %769 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s789.0, i64 noundef %s789.1, i64 noundef %s787.0, i64 noundef %s787.1)
  %s790.0 = extractvalue { i64, i64 } %769, 0
  %s790.1 = extractvalue { i64, i64 } %769, 1
  %_0.i63 = getelementptr inbounds nuw i8, ptr %params, i64 1472
  %s791.0 = load i64, ptr %_0.i63, align 8, !noundef !3
  %770 = getelementptr inbounds nuw i8, ptr %params, i64 1480
  %s791.1 = load i64, ptr %770, align 8, !noundef !3
  %_0.i266 = getelementptr inbounds nuw i8, ptr %bases, i64 168
  %s792 = load i64, ptr %_0.i266, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %771 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s210.0, i64 noundef %s210.1, i64 noundef %s792)
; call <kernels::Fp2>::mul_base
  %772 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s212.0, i64 noundef %s212.1, i64 noundef %s792)
  %s793.1 = extractvalue { i64, i64 } %771, 1
  %s793.0 = extractvalue { i64, i64 } %771, 0
  %s794.0 = extractvalue { i64, i64 } %772, 0
  %s794.1 = extractvalue { i64, i64 } %772, 1
; call <kernels::Fp2>::sub
  %773 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s791.0, i64 noundef %s791.1, i64 noundef %s793.0, i64 noundef %s793.1)
  %s795.0 = extractvalue { i64, i64 } %773, 0
  %s795.1 = extractvalue { i64, i64 } %773, 1
  %_0.i62 = getelementptr inbounds nuw i8, ptr %params, i64 1488
  %s796.0 = load i64, ptr %_0.i62, align 8, !noundef !3
  %774 = getelementptr inbounds nuw i8, ptr %params, i64 1496
  %s796.1 = load i64, ptr %774, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %775 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s796.0, i64 noundef %s796.1, i64 noundef %s794.0, i64 noundef %s794.1)
  %s797.0 = extractvalue { i64, i64 } %775, 0
  %s797.1 = extractvalue { i64, i64 } %775, 1
  %_0.i61 = getelementptr inbounds nuw i8, ptr %raw, i64 1664
  %s798.0 = load i64, ptr %_0.i61, align 8, !noundef !3
  %776 = getelementptr inbounds nuw i8, ptr %raw, i64 1672
  %s798.1 = load i64, ptr %776, align 8, !noundef !3
  %_0.i60 = getelementptr inbounds nuw i8, ptr %raw, i64 1680
  %s799.0 = load i64, ptr %_0.i60, align 8, !noundef !3
  %777 = getelementptr inbounds nuw i8, ptr %raw, i64 1688
  %s799.1 = load i64, ptr %777, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %778 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s799.0, i64 noundef %s799.1, i64 noundef %s798.0, i64 noundef %s798.1)
  %s800.0 = extractvalue { i64, i64 } %778, 0
  %s800.1 = extractvalue { i64, i64 } %778, 1
; call <kernels::Fp2>::mul
  %779 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s798.0, i64 noundef %s798.1, i64 noundef %s788.0, i64 noundef %s788.1)
  %s801.0 = extractvalue { i64, i64 } %779, 0
  %s801.1 = extractvalue { i64, i64 } %779, 1
; call <kernels::Fp2>::mul
  %780 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s800.0, i64 noundef %s800.1, i64 noundef %s790.0, i64 noundef %s790.1)
  %s802.0 = extractvalue { i64, i64 } %780, 0
  %s802.1 = extractvalue { i64, i64 } %780, 1
; call <kernels::Fp2>::add
  %781 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s798.0, i64 noundef %s798.1, i64 noundef %s800.0, i64 noundef %s800.1)
; call <kernels::Fp2>::add
  %782 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s788.0, i64 noundef %s788.1, i64 noundef %s790.0, i64 noundef %s790.1)
  %s803.1 = extractvalue { i64, i64 } %781, 1
  %s803.0 = extractvalue { i64, i64 } %781, 0
  %s804.0 = extractvalue { i64, i64 } %782, 0
  %s804.1 = extractvalue { i64, i64 } %782, 1
; call <kernels::Fp2>::mul
  %783 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s803.0, i64 noundef %s803.1, i64 noundef %s804.0, i64 noundef %s804.1)
  %s805.0 = extractvalue { i64, i64 } %783, 0
  %s805.1 = extractvalue { i64, i64 } %783, 1
; call <kernels::Fp2>::sub
  %784 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s805.0, i64 noundef %s805.1, i64 noundef %s801.0, i64 noundef %s801.1)
  %s806.0 = extractvalue { i64, i64 } %784, 0
  %s806.1 = extractvalue { i64, i64 } %784, 1
; call <kernels::Fp2>::sub
  %785 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s806.0, i64 noundef %s806.1, i64 noundef %s802.0, i64 noundef %s802.1)
  %s807.0 = extractvalue { i64, i64 } %785, 0
  %s807.1 = extractvalue { i64, i64 } %785, 1
; call <kernels::Fp2>::mul
  %786 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s801.0, i64 noundef %s801.1, i64 noundef %s795.0, i64 noundef %s795.1)
  %s808.0 = extractvalue { i64, i64 } %786, 0
  %s808.1 = extractvalue { i64, i64 } %786, 1
; call <kernels::Fp2>::mul
  %787 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s801.0, i64 noundef %s801.1, i64 noundef %s797.0, i64 noundef %s797.1)
; call <kernels::Fp2>::mul
  %788 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s807.0, i64 noundef %s807.1, i64 noundef %s795.0, i64 noundef %s795.1)
  %s809.1 = extractvalue { i64, i64 } %787, 1
  %s809.0 = extractvalue { i64, i64 } %787, 0
  %s810.0 = extractvalue { i64, i64 } %788, 0
  %s810.1 = extractvalue { i64, i64 } %788, 1
; call <kernels::Fp2>::add
  %789 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s809.0, i64 noundef %s809.1, i64 noundef %s810.0, i64 noundef %s810.1)
  %s811.0 = extractvalue { i64, i64 } %789, 0
  %s811.1 = extractvalue { i64, i64 } %789, 1
; call <kernels::Fp2>::mul
  %790 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s807.0, i64 noundef %s807.1, i64 noundef %s797.0, i64 noundef %s797.1)
; call <kernels::Fp2>::mul
  %791 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s802.0, i64 noundef %s802.1, i64 noundef %s795.0, i64 noundef %s795.1)
  %s812.1 = extractvalue { i64, i64 } %790, 1
  %s812.0 = extractvalue { i64, i64 } %790, 0
  %s813.0 = extractvalue { i64, i64 } %791, 0
  %s813.1 = extractvalue { i64, i64 } %791, 1
; call <kernels::Fp2>::add
  %792 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s812.0, i64 noundef %s812.1, i64 noundef %s813.0, i64 noundef %s813.1)
  %s814.0 = extractvalue { i64, i64 } %792, 0
  %s814.1 = extractvalue { i64, i64 } %792, 1
; call <kernels::Fp2>::mul
  %793 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s802.0, i64 noundef %s802.1, i64 noundef %s797.0, i64 noundef %s797.1)
  %s815.0 = extractvalue { i64, i64 } %793, 0
  %s815.1 = extractvalue { i64, i64 } %793, 1
; call <kernels::Fp2>::add
  %794 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s788.0, i64 noundef %s788.1, i64 noundef %s795.0, i64 noundef %s795.1)
; call <kernels::Fp2>::add
  %795 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s790.0, i64 noundef %s790.1, i64 noundef %s797.0, i64 noundef %s797.1)
  %s816.1 = extractvalue { i64, i64 } %794, 1
  %s816.0 = extractvalue { i64, i64 } %794, 0
; call <kernels::Fp2>::sub
  %796 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s808.0, i64 noundef %s808.1, i64 noundef %s816.0, i64 noundef %s816.1)
  %s817.1 = extractvalue { i64, i64 } %795, 1
  %s817.0 = extractvalue { i64, i64 } %795, 0
  %s818.0 = extractvalue { i64, i64 } %796, 0
  %s818.1 = extractvalue { i64, i64 } %796, 1
; call <kernels::Fp2>::sub
  %797 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s811.0, i64 noundef %s811.1, i64 noundef %s817.0, i64 noundef %s817.1)
  %s819.0 = extractvalue { i64, i64 } %797, 0
  %s819.1 = extractvalue { i64, i64 } %797, 1
  %_0.i59 = getelementptr inbounds nuw i8, ptr %params, i64 1504
  %s820.0 = load i64, ptr %_0.i59, align 8, !noundef !3
  %798 = getelementptr inbounds nuw i8, ptr %params, i64 1512
  %s820.1 = load i64, ptr %798, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %799 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s818.0, i64 noundef %s818.1, i64 noundef %s820.0, i64 noundef %s820.1)
  %s821.0 = extractvalue { i64, i64 } %799, 0
  %s821.1 = extractvalue { i64, i64 } %799, 1
; call <kernels::Fp2>::mul
  %800 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s819.0, i64 noundef %s819.1, i64 noundef %s820.0, i64 noundef %s820.1)
  %s822.0 = extractvalue { i64, i64 } %800, 0
  %s822.1 = extractvalue { i64, i64 } %800, 1
; call <kernels::Fp2>::mul
  %801 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s814.0, i64 noundef %s814.1, i64 noundef %s820.0, i64 noundef %s820.1)
  %s823.0 = extractvalue { i64, i64 } %801, 0
  %s823.1 = extractvalue { i64, i64 } %801, 1
; call <kernels::Fp2>::mul
  %802 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s815.0, i64 noundef %s815.1, i64 noundef %s820.0, i64 noundef %s820.1)
  %s824.0 = extractvalue { i64, i64 } %802, 0
  %s824.1 = extractvalue { i64, i64 } %802, 1
; call <kernels::Fp2>::add
  %803 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s780.0, i64 noundef %s780.1, i64 noundef %s821.0, i64 noundef %s821.1)
  %s825.0 = extractvalue { i64, i64 } %803, 0
  %s825.1 = extractvalue { i64, i64 } %803, 1
; call <kernels::Fp2>::add
  %804 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s781.0, i64 noundef %s781.1, i64 noundef %s822.0, i64 noundef %s822.1)
  %s826.0 = extractvalue { i64, i64 } %804, 0
  %s826.1 = extractvalue { i64, i64 } %804, 1
; call <kernels::Fp2>::add
  %805 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s782.0, i64 noundef %s782.1, i64 noundef %s823.0, i64 noundef %s823.1)
  %s827.0 = extractvalue { i64, i64 } %805, 0
  %s827.1 = extractvalue { i64, i64 } %805, 1
; call <kernels::Fp2>::add
  %806 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s783.0, i64 noundef %s783.1, i64 noundef %s824.0, i64 noundef %s824.1)
  %s828.0 = extractvalue { i64, i64 } %806, 0
  %s828.1 = extractvalue { i64, i64 } %806, 1
  %_0.i58 = getelementptr inbounds nuw i8, ptr %params, i64 1520
  %s829.0 = load i64, ptr %_0.i58, align 8, !noundef !3
  %807 = getelementptr inbounds nuw i8, ptr %params, i64 1528
  %s829.1 = load i64, ptr %807, align 8, !noundef !3
  %_0.i265 = getelementptr inbounds nuw i8, ptr %bases, i64 176
  %s830 = load i64, ptr %_0.i265, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %808 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s218.0, i64 noundef %s218.1, i64 noundef %s830)
; call <kernels::Fp2>::mul_base
  %809 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s220.0, i64 noundef %s220.1, i64 noundef %s830)
  %s831.1 = extractvalue { i64, i64 } %808, 1
  %s831.0 = extractvalue { i64, i64 } %808, 0
  %s832.0 = extractvalue { i64, i64 } %809, 0
  %s832.1 = extractvalue { i64, i64 } %809, 1
; call <kernels::Fp2>::sub
  %810 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s829.0, i64 noundef %s829.1, i64 noundef %s831.0, i64 noundef %s831.1)
  %s833.0 = extractvalue { i64, i64 } %810, 0
  %s833.1 = extractvalue { i64, i64 } %810, 1
  %_0.i57 = getelementptr inbounds nuw i8, ptr %params, i64 1536
  %s834.0 = load i64, ptr %_0.i57, align 8, !noundef !3
  %811 = getelementptr inbounds nuw i8, ptr %params, i64 1544
  %s834.1 = load i64, ptr %811, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %812 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s834.0, i64 noundef %s834.1, i64 noundef %s832.0, i64 noundef %s832.1)
  %s835.0 = extractvalue { i64, i64 } %812, 0
  %s835.1 = extractvalue { i64, i64 } %812, 1
  %_0.i56 = getelementptr inbounds nuw i8, ptr %params, i64 1552
  %s836.0 = load i64, ptr %_0.i56, align 8, !noundef !3
  %813 = getelementptr inbounds nuw i8, ptr %params, i64 1560
  %s836.1 = load i64, ptr %813, align 8, !noundef !3
  %_0.i264 = getelementptr inbounds nuw i8, ptr %bases, i64 184
  %s837 = load i64, ptr %_0.i264, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %814 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s226.0, i64 noundef %s226.1, i64 noundef %s837)
; call <kernels::Fp2>::mul_base
  %815 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s228.0, i64 noundef %s228.1, i64 noundef %s837)
  %s838.1 = extractvalue { i64, i64 } %814, 1
  %s838.0 = extractvalue { i64, i64 } %814, 0
  %s839.0 = extractvalue { i64, i64 } %815, 0
  %s839.1 = extractvalue { i64, i64 } %815, 1
; call <kernels::Fp2>::sub
  %816 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s836.0, i64 noundef %s836.1, i64 noundef %s838.0, i64 noundef %s838.1)
  %s840.0 = extractvalue { i64, i64 } %816, 0
  %s840.1 = extractvalue { i64, i64 } %816, 1
  %_0.i55 = getelementptr inbounds nuw i8, ptr %params, i64 1568
  %s841.0 = load i64, ptr %_0.i55, align 8, !noundef !3
  %817 = getelementptr inbounds nuw i8, ptr %params, i64 1576
  %s841.1 = load i64, ptr %817, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %818 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s841.0, i64 noundef %s841.1, i64 noundef %s839.0, i64 noundef %s839.1)
  %s842.0 = extractvalue { i64, i64 } %818, 0
  %s842.1 = extractvalue { i64, i64 } %818, 1
  %_0.i54 = getelementptr inbounds nuw i8, ptr %raw, i64 1696
  %s843.0 = load i64, ptr %_0.i54, align 8, !noundef !3
  %819 = getelementptr inbounds nuw i8, ptr %raw, i64 1704
  %s843.1 = load i64, ptr %819, align 8, !noundef !3
  %_0.i53 = getelementptr inbounds nuw i8, ptr %raw, i64 1712
  %s844.0 = load i64, ptr %_0.i53, align 8, !noundef !3
  %820 = getelementptr inbounds nuw i8, ptr %raw, i64 1720
  %s844.1 = load i64, ptr %820, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %821 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s844.0, i64 noundef %s844.1, i64 noundef %s843.0, i64 noundef %s843.1)
  %s845.0 = extractvalue { i64, i64 } %821, 0
  %s845.1 = extractvalue { i64, i64 } %821, 1
; call <kernels::Fp2>::mul
  %822 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s843.0, i64 noundef %s843.1, i64 noundef %s833.0, i64 noundef %s833.1)
  %s846.0 = extractvalue { i64, i64 } %822, 0
  %s846.1 = extractvalue { i64, i64 } %822, 1
; call <kernels::Fp2>::mul
  %823 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s845.0, i64 noundef %s845.1, i64 noundef %s835.0, i64 noundef %s835.1)
  %s847.0 = extractvalue { i64, i64 } %823, 0
  %s847.1 = extractvalue { i64, i64 } %823, 1
; call <kernels::Fp2>::add
  %824 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s843.0, i64 noundef %s843.1, i64 noundef %s845.0, i64 noundef %s845.1)
; call <kernels::Fp2>::add
  %825 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s833.0, i64 noundef %s833.1, i64 noundef %s835.0, i64 noundef %s835.1)
  %s848.1 = extractvalue { i64, i64 } %824, 1
  %s848.0 = extractvalue { i64, i64 } %824, 0
  %s849.0 = extractvalue { i64, i64 } %825, 0
  %s849.1 = extractvalue { i64, i64 } %825, 1
; call <kernels::Fp2>::mul
  %826 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s848.0, i64 noundef %s848.1, i64 noundef %s849.0, i64 noundef %s849.1)
  %s850.0 = extractvalue { i64, i64 } %826, 0
  %s850.1 = extractvalue { i64, i64 } %826, 1
; call <kernels::Fp2>::sub
  %827 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s850.0, i64 noundef %s850.1, i64 noundef %s846.0, i64 noundef %s846.1)
  %s851.0 = extractvalue { i64, i64 } %827, 0
  %s851.1 = extractvalue { i64, i64 } %827, 1
; call <kernels::Fp2>::sub
  %828 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s851.0, i64 noundef %s851.1, i64 noundef %s847.0, i64 noundef %s847.1)
  %s852.0 = extractvalue { i64, i64 } %828, 0
  %s852.1 = extractvalue { i64, i64 } %828, 1
; call <kernels::Fp2>::mul
  %829 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s846.0, i64 noundef %s846.1, i64 noundef %s840.0, i64 noundef %s840.1)
  %s853.0 = extractvalue { i64, i64 } %829, 0
  %s853.1 = extractvalue { i64, i64 } %829, 1
; call <kernels::Fp2>::mul
  %830 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s846.0, i64 noundef %s846.1, i64 noundef %s842.0, i64 noundef %s842.1)
; call <kernels::Fp2>::mul
  %831 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s852.0, i64 noundef %s852.1, i64 noundef %s840.0, i64 noundef %s840.1)
  %s854.1 = extractvalue { i64, i64 } %830, 1
  %s854.0 = extractvalue { i64, i64 } %830, 0
  %s855.0 = extractvalue { i64, i64 } %831, 0
  %s855.1 = extractvalue { i64, i64 } %831, 1
; call <kernels::Fp2>::add
  %832 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s854.0, i64 noundef %s854.1, i64 noundef %s855.0, i64 noundef %s855.1)
  %s856.0 = extractvalue { i64, i64 } %832, 0
  %s856.1 = extractvalue { i64, i64 } %832, 1
; call <kernels::Fp2>::mul
  %833 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s852.0, i64 noundef %s852.1, i64 noundef %s842.0, i64 noundef %s842.1)
; call <kernels::Fp2>::mul
  %834 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s847.0, i64 noundef %s847.1, i64 noundef %s840.0, i64 noundef %s840.1)
  %s857.1 = extractvalue { i64, i64 } %833, 1
  %s857.0 = extractvalue { i64, i64 } %833, 0
  %s858.0 = extractvalue { i64, i64 } %834, 0
  %s858.1 = extractvalue { i64, i64 } %834, 1
; call <kernels::Fp2>::add
  %835 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s857.0, i64 noundef %s857.1, i64 noundef %s858.0, i64 noundef %s858.1)
  %s859.0 = extractvalue { i64, i64 } %835, 0
  %s859.1 = extractvalue { i64, i64 } %835, 1
; call <kernels::Fp2>::mul
  %836 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s847.0, i64 noundef %s847.1, i64 noundef %s842.0, i64 noundef %s842.1)
  %s860.0 = extractvalue { i64, i64 } %836, 0
  %s860.1 = extractvalue { i64, i64 } %836, 1
; call <kernels::Fp2>::add
  %837 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s833.0, i64 noundef %s833.1, i64 noundef %s840.0, i64 noundef %s840.1)
; call <kernels::Fp2>::add
  %838 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s835.0, i64 noundef %s835.1, i64 noundef %s842.0, i64 noundef %s842.1)
  %s861.1 = extractvalue { i64, i64 } %837, 1
  %s861.0 = extractvalue { i64, i64 } %837, 0
; call <kernels::Fp2>::sub
  %839 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s853.0, i64 noundef %s853.1, i64 noundef %s861.0, i64 noundef %s861.1)
  %s862.1 = extractvalue { i64, i64 } %838, 1
  %s862.0 = extractvalue { i64, i64 } %838, 0
  %s863.0 = extractvalue { i64, i64 } %839, 0
  %s863.1 = extractvalue { i64, i64 } %839, 1
; call <kernels::Fp2>::sub
  %840 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s856.0, i64 noundef %s856.1, i64 noundef %s862.0, i64 noundef %s862.1)
  %s864.0 = extractvalue { i64, i64 } %840, 0
  %s864.1 = extractvalue { i64, i64 } %840, 1
  %_0.i52 = getelementptr inbounds nuw i8, ptr %params, i64 1584
  %s865.0 = load i64, ptr %_0.i52, align 8, !noundef !3
  %841 = getelementptr inbounds nuw i8, ptr %params, i64 1592
  %s865.1 = load i64, ptr %841, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %842 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s863.0, i64 noundef %s863.1, i64 noundef %s865.0, i64 noundef %s865.1)
  %s866.0 = extractvalue { i64, i64 } %842, 0
  %s866.1 = extractvalue { i64, i64 } %842, 1
; call <kernels::Fp2>::mul
  %843 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s864.0, i64 noundef %s864.1, i64 noundef %s865.0, i64 noundef %s865.1)
  %s867.0 = extractvalue { i64, i64 } %843, 0
  %s867.1 = extractvalue { i64, i64 } %843, 1
; call <kernels::Fp2>::mul
  %844 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s859.0, i64 noundef %s859.1, i64 noundef %s865.0, i64 noundef %s865.1)
  %s868.0 = extractvalue { i64, i64 } %844, 0
  %s868.1 = extractvalue { i64, i64 } %844, 1
; call <kernels::Fp2>::mul
  %845 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s860.0, i64 noundef %s860.1, i64 noundef %s865.0, i64 noundef %s865.1)
  %s869.0 = extractvalue { i64, i64 } %845, 0
  %s869.1 = extractvalue { i64, i64 } %845, 1
; call <kernels::Fp2>::add
  %846 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s825.0, i64 noundef %s825.1, i64 noundef %s866.0, i64 noundef %s866.1)
  %s870.0 = extractvalue { i64, i64 } %846, 0
  %s870.1 = extractvalue { i64, i64 } %846, 1
; call <kernels::Fp2>::add
  %847 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s826.0, i64 noundef %s826.1, i64 noundef %s867.0, i64 noundef %s867.1)
  %s871.0 = extractvalue { i64, i64 } %847, 0
  %s871.1 = extractvalue { i64, i64 } %847, 1
; call <kernels::Fp2>::add
  %848 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s827.0, i64 noundef %s827.1, i64 noundef %s868.0, i64 noundef %s868.1)
  %s872.0 = extractvalue { i64, i64 } %848, 0
  %s872.1 = extractvalue { i64, i64 } %848, 1
; call <kernels::Fp2>::add
  %849 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s828.0, i64 noundef %s828.1, i64 noundef %s869.0, i64 noundef %s869.1)
  %s873.0 = extractvalue { i64, i64 } %849, 0
  %s873.1 = extractvalue { i64, i64 } %849, 1
  %_0.i51 = getelementptr inbounds nuw i8, ptr %params, i64 1600
  %s874.0 = load i64, ptr %_0.i51, align 8, !noundef !3
  %850 = getelementptr inbounds nuw i8, ptr %params, i64 1608
  %s874.1 = load i64, ptr %850, align 8, !noundef !3
  %_0.i263 = getelementptr inbounds nuw i8, ptr %bases, i64 192
  %s875 = load i64, ptr %_0.i263, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %851 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s234.0, i64 noundef %s234.1, i64 noundef %s875)
; call <kernels::Fp2>::mul_base
  %852 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s236.0, i64 noundef %s236.1, i64 noundef %s875)
  %s876.1 = extractvalue { i64, i64 } %851, 1
  %s876.0 = extractvalue { i64, i64 } %851, 0
  %s877.0 = extractvalue { i64, i64 } %852, 0
  %s877.1 = extractvalue { i64, i64 } %852, 1
; call <kernels::Fp2>::sub
  %853 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s874.0, i64 noundef %s874.1, i64 noundef %s876.0, i64 noundef %s876.1)
  %s878.0 = extractvalue { i64, i64 } %853, 0
  %s878.1 = extractvalue { i64, i64 } %853, 1
  %_0.i50 = getelementptr inbounds nuw i8, ptr %params, i64 1616
  %s879.0 = load i64, ptr %_0.i50, align 8, !noundef !3
  %854 = getelementptr inbounds nuw i8, ptr %params, i64 1624
  %s879.1 = load i64, ptr %854, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %855 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s879.0, i64 noundef %s879.1, i64 noundef %s877.0, i64 noundef %s877.1)
  %s880.0 = extractvalue { i64, i64 } %855, 0
  %s880.1 = extractvalue { i64, i64 } %855, 1
  %_0.i49 = getelementptr inbounds nuw i8, ptr %params, i64 1632
  %s881.0 = load i64, ptr %_0.i49, align 8, !noundef !3
  %856 = getelementptr inbounds nuw i8, ptr %params, i64 1640
  %s881.1 = load i64, ptr %856, align 8, !noundef !3
  %_0.i262 = getelementptr inbounds nuw i8, ptr %bases, i64 200
  %s882 = load i64, ptr %_0.i262, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %857 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s242.0, i64 noundef %s242.1, i64 noundef %s882)
; call <kernels::Fp2>::mul_base
  %858 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s244.0, i64 noundef %s244.1, i64 noundef %s882)
  %s883.1 = extractvalue { i64, i64 } %857, 1
  %s883.0 = extractvalue { i64, i64 } %857, 0
  %s884.0 = extractvalue { i64, i64 } %858, 0
  %s884.1 = extractvalue { i64, i64 } %858, 1
; call <kernels::Fp2>::sub
  %859 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s881.0, i64 noundef %s881.1, i64 noundef %s883.0, i64 noundef %s883.1)
  %s885.0 = extractvalue { i64, i64 } %859, 0
  %s885.1 = extractvalue { i64, i64 } %859, 1
  %_0.i48 = getelementptr inbounds nuw i8, ptr %params, i64 1648
  %s886.0 = load i64, ptr %_0.i48, align 8, !noundef !3
  %860 = getelementptr inbounds nuw i8, ptr %params, i64 1656
  %s886.1 = load i64, ptr %860, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %861 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s886.0, i64 noundef %s886.1, i64 noundef %s884.0, i64 noundef %s884.1)
  %s887.0 = extractvalue { i64, i64 } %861, 0
  %s887.1 = extractvalue { i64, i64 } %861, 1
  %_0.i47 = getelementptr inbounds nuw i8, ptr %raw, i64 1728
  %s888.0 = load i64, ptr %_0.i47, align 8, !noundef !3
  %862 = getelementptr inbounds nuw i8, ptr %raw, i64 1736
  %s888.1 = load i64, ptr %862, align 8, !noundef !3
  %_0.i46 = getelementptr inbounds nuw i8, ptr %raw, i64 1744
  %s889.0 = load i64, ptr %_0.i46, align 8, !noundef !3
  %863 = getelementptr inbounds nuw i8, ptr %raw, i64 1752
  %s889.1 = load i64, ptr %863, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %864 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s889.0, i64 noundef %s889.1, i64 noundef %s888.0, i64 noundef %s888.1)
  %s890.0 = extractvalue { i64, i64 } %864, 0
  %s890.1 = extractvalue { i64, i64 } %864, 1
; call <kernels::Fp2>::mul
  %865 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s888.0, i64 noundef %s888.1, i64 noundef %s878.0, i64 noundef %s878.1)
  %s891.0 = extractvalue { i64, i64 } %865, 0
  %s891.1 = extractvalue { i64, i64 } %865, 1
; call <kernels::Fp2>::mul
  %866 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s890.0, i64 noundef %s890.1, i64 noundef %s880.0, i64 noundef %s880.1)
  %s892.0 = extractvalue { i64, i64 } %866, 0
  %s892.1 = extractvalue { i64, i64 } %866, 1
; call <kernels::Fp2>::add
  %867 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s888.0, i64 noundef %s888.1, i64 noundef %s890.0, i64 noundef %s890.1)
; call <kernels::Fp2>::add
  %868 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s878.0, i64 noundef %s878.1, i64 noundef %s880.0, i64 noundef %s880.1)
  %s893.1 = extractvalue { i64, i64 } %867, 1
  %s893.0 = extractvalue { i64, i64 } %867, 0
  %s894.0 = extractvalue { i64, i64 } %868, 0
  %s894.1 = extractvalue { i64, i64 } %868, 1
; call <kernels::Fp2>::mul
  %869 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s893.0, i64 noundef %s893.1, i64 noundef %s894.0, i64 noundef %s894.1)
  %s895.0 = extractvalue { i64, i64 } %869, 0
  %s895.1 = extractvalue { i64, i64 } %869, 1
; call <kernels::Fp2>::sub
  %870 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s895.0, i64 noundef %s895.1, i64 noundef %s891.0, i64 noundef %s891.1)
  %s896.0 = extractvalue { i64, i64 } %870, 0
  %s896.1 = extractvalue { i64, i64 } %870, 1
; call <kernels::Fp2>::sub
  %871 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s896.0, i64 noundef %s896.1, i64 noundef %s892.0, i64 noundef %s892.1)
  %s897.0 = extractvalue { i64, i64 } %871, 0
  %s897.1 = extractvalue { i64, i64 } %871, 1
; call <kernels::Fp2>::mul
  %872 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s891.0, i64 noundef %s891.1, i64 noundef %s885.0, i64 noundef %s885.1)
  %s898.0 = extractvalue { i64, i64 } %872, 0
  %s898.1 = extractvalue { i64, i64 } %872, 1
; call <kernels::Fp2>::mul
  %873 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s891.0, i64 noundef %s891.1, i64 noundef %s887.0, i64 noundef %s887.1)
; call <kernels::Fp2>::mul
  %874 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s897.0, i64 noundef %s897.1, i64 noundef %s885.0, i64 noundef %s885.1)
  %s899.1 = extractvalue { i64, i64 } %873, 1
  %s899.0 = extractvalue { i64, i64 } %873, 0
  %s900.0 = extractvalue { i64, i64 } %874, 0
  %s900.1 = extractvalue { i64, i64 } %874, 1
; call <kernels::Fp2>::add
  %875 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s899.0, i64 noundef %s899.1, i64 noundef %s900.0, i64 noundef %s900.1)
  %s901.0 = extractvalue { i64, i64 } %875, 0
  %s901.1 = extractvalue { i64, i64 } %875, 1
; call <kernels::Fp2>::mul
  %876 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s897.0, i64 noundef %s897.1, i64 noundef %s887.0, i64 noundef %s887.1)
; call <kernels::Fp2>::mul
  %877 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s892.0, i64 noundef %s892.1, i64 noundef %s885.0, i64 noundef %s885.1)
  %s902.1 = extractvalue { i64, i64 } %876, 1
  %s902.0 = extractvalue { i64, i64 } %876, 0
  %s903.0 = extractvalue { i64, i64 } %877, 0
  %s903.1 = extractvalue { i64, i64 } %877, 1
; call <kernels::Fp2>::add
  %878 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s902.0, i64 noundef %s902.1, i64 noundef %s903.0, i64 noundef %s903.1)
  %s904.0 = extractvalue { i64, i64 } %878, 0
  %s904.1 = extractvalue { i64, i64 } %878, 1
; call <kernels::Fp2>::mul
  %879 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s892.0, i64 noundef %s892.1, i64 noundef %s887.0, i64 noundef %s887.1)
  %s905.0 = extractvalue { i64, i64 } %879, 0
  %s905.1 = extractvalue { i64, i64 } %879, 1
; call <kernels::Fp2>::add
  %880 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s878.0, i64 noundef %s878.1, i64 noundef %s885.0, i64 noundef %s885.1)
; call <kernels::Fp2>::add
  %881 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s880.0, i64 noundef %s880.1, i64 noundef %s887.0, i64 noundef %s887.1)
  %s906.1 = extractvalue { i64, i64 } %880, 1
  %s906.0 = extractvalue { i64, i64 } %880, 0
; call <kernels::Fp2>::sub
  %882 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s898.0, i64 noundef %s898.1, i64 noundef %s906.0, i64 noundef %s906.1)
  %s907.1 = extractvalue { i64, i64 } %881, 1
  %s907.0 = extractvalue { i64, i64 } %881, 0
  %s908.0 = extractvalue { i64, i64 } %882, 0
  %s908.1 = extractvalue { i64, i64 } %882, 1
; call <kernels::Fp2>::sub
  %883 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s901.0, i64 noundef %s901.1, i64 noundef %s907.0, i64 noundef %s907.1)
  %s909.0 = extractvalue { i64, i64 } %883, 0
  %s909.1 = extractvalue { i64, i64 } %883, 1
  %_0.i45 = getelementptr inbounds nuw i8, ptr %params, i64 1664
  %s910.0 = load i64, ptr %_0.i45, align 8, !noundef !3
  %884 = getelementptr inbounds nuw i8, ptr %params, i64 1672
  %s910.1 = load i64, ptr %884, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %885 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s908.0, i64 noundef %s908.1, i64 noundef %s910.0, i64 noundef %s910.1)
  %s911.0 = extractvalue { i64, i64 } %885, 0
  %s911.1 = extractvalue { i64, i64 } %885, 1
; call <kernels::Fp2>::mul
  %886 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s909.0, i64 noundef %s909.1, i64 noundef %s910.0, i64 noundef %s910.1)
  %s912.0 = extractvalue { i64, i64 } %886, 0
  %s912.1 = extractvalue { i64, i64 } %886, 1
; call <kernels::Fp2>::mul
  %887 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s904.0, i64 noundef %s904.1, i64 noundef %s910.0, i64 noundef %s910.1)
  %s913.0 = extractvalue { i64, i64 } %887, 0
  %s913.1 = extractvalue { i64, i64 } %887, 1
; call <kernels::Fp2>::mul
  %888 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s905.0, i64 noundef %s905.1, i64 noundef %s910.0, i64 noundef %s910.1)
  %s914.0 = extractvalue { i64, i64 } %888, 0
  %s914.1 = extractvalue { i64, i64 } %888, 1
; call <kernels::Fp2>::add
  %889 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s870.0, i64 noundef %s870.1, i64 noundef %s911.0, i64 noundef %s911.1)
  %s915.0 = extractvalue { i64, i64 } %889, 0
  %s915.1 = extractvalue { i64, i64 } %889, 1
; call <kernels::Fp2>::add
  %890 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s871.0, i64 noundef %s871.1, i64 noundef %s912.0, i64 noundef %s912.1)
  %s916.0 = extractvalue { i64, i64 } %890, 0
  %s916.1 = extractvalue { i64, i64 } %890, 1
; call <kernels::Fp2>::add
  %891 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s872.0, i64 noundef %s872.1, i64 noundef %s913.0, i64 noundef %s913.1)
  %s917.0 = extractvalue { i64, i64 } %891, 0
  %s917.1 = extractvalue { i64, i64 } %891, 1
; call <kernels::Fp2>::add
  %892 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s873.0, i64 noundef %s873.1, i64 noundef %s914.0, i64 noundef %s914.1)
  %s918.0 = extractvalue { i64, i64 } %892, 0
  %s918.1 = extractvalue { i64, i64 } %892, 1
  %_0.i44 = getelementptr inbounds nuw i8, ptr %params, i64 1680
  %s919.0 = load i64, ptr %_0.i44, align 8, !noundef !3
  %893 = getelementptr inbounds nuw i8, ptr %params, i64 1688
  %s919.1 = load i64, ptr %893, align 8, !noundef !3
  %_0.i261 = getelementptr inbounds nuw i8, ptr %bases, i64 208
  %s920 = load i64, ptr %_0.i261, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %894 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s250.0, i64 noundef %s250.1, i64 noundef %s920)
; call <kernels::Fp2>::mul_base
  %895 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s252.0, i64 noundef %s252.1, i64 noundef %s920)
  %s921.1 = extractvalue { i64, i64 } %894, 1
  %s921.0 = extractvalue { i64, i64 } %894, 0
  %s922.0 = extractvalue { i64, i64 } %895, 0
  %s922.1 = extractvalue { i64, i64 } %895, 1
; call <kernels::Fp2>::sub
  %896 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s919.0, i64 noundef %s919.1, i64 noundef %s921.0, i64 noundef %s921.1)
  %s923.0 = extractvalue { i64, i64 } %896, 0
  %s923.1 = extractvalue { i64, i64 } %896, 1
  %_0.i43 = getelementptr inbounds nuw i8, ptr %params, i64 1696
  %s924.0 = load i64, ptr %_0.i43, align 8, !noundef !3
  %897 = getelementptr inbounds nuw i8, ptr %params, i64 1704
  %s924.1 = load i64, ptr %897, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %898 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s924.0, i64 noundef %s924.1, i64 noundef %s922.0, i64 noundef %s922.1)
  %s925.0 = extractvalue { i64, i64 } %898, 0
  %s925.1 = extractvalue { i64, i64 } %898, 1
  %_0.i42 = getelementptr inbounds nuw i8, ptr %params, i64 1712
  %s926.0 = load i64, ptr %_0.i42, align 8, !noundef !3
  %899 = getelementptr inbounds nuw i8, ptr %params, i64 1720
  %s926.1 = load i64, ptr %899, align 8, !noundef !3
  %_0.i260 = getelementptr inbounds nuw i8, ptr %bases, i64 216
  %s927 = load i64, ptr %_0.i260, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %900 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s258.0, i64 noundef %s258.1, i64 noundef %s927)
; call <kernels::Fp2>::mul_base
  %901 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s260.0, i64 noundef %s260.1, i64 noundef %s927)
  %s928.1 = extractvalue { i64, i64 } %900, 1
  %s928.0 = extractvalue { i64, i64 } %900, 0
  %s929.0 = extractvalue { i64, i64 } %901, 0
  %s929.1 = extractvalue { i64, i64 } %901, 1
; call <kernels::Fp2>::sub
  %902 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s926.0, i64 noundef %s926.1, i64 noundef %s928.0, i64 noundef %s928.1)
  %s930.0 = extractvalue { i64, i64 } %902, 0
  %s930.1 = extractvalue { i64, i64 } %902, 1
  %_0.i41 = getelementptr inbounds nuw i8, ptr %params, i64 1728
  %s931.0 = load i64, ptr %_0.i41, align 8, !noundef !3
  %903 = getelementptr inbounds nuw i8, ptr %params, i64 1736
  %s931.1 = load i64, ptr %903, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %904 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s931.0, i64 noundef %s931.1, i64 noundef %s929.0, i64 noundef %s929.1)
  %s932.0 = extractvalue { i64, i64 } %904, 0
  %s932.1 = extractvalue { i64, i64 } %904, 1
  %_0.i40 = getelementptr inbounds nuw i8, ptr %raw, i64 1760
  %s933.0 = load i64, ptr %_0.i40, align 8, !noundef !3
  %905 = getelementptr inbounds nuw i8, ptr %raw, i64 1768
  %s933.1 = load i64, ptr %905, align 8, !noundef !3
  %_0.i39 = getelementptr inbounds nuw i8, ptr %raw, i64 1776
  %s934.0 = load i64, ptr %_0.i39, align 8, !noundef !3
  %906 = getelementptr inbounds nuw i8, ptr %raw, i64 1784
  %s934.1 = load i64, ptr %906, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %907 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s934.0, i64 noundef %s934.1, i64 noundef %s933.0, i64 noundef %s933.1)
  %s935.0 = extractvalue { i64, i64 } %907, 0
  %s935.1 = extractvalue { i64, i64 } %907, 1
; call <kernels::Fp2>::mul
  %908 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s933.0, i64 noundef %s933.1, i64 noundef %s923.0, i64 noundef %s923.1)
  %s936.0 = extractvalue { i64, i64 } %908, 0
  %s936.1 = extractvalue { i64, i64 } %908, 1
; call <kernels::Fp2>::mul
  %909 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s935.0, i64 noundef %s935.1, i64 noundef %s925.0, i64 noundef %s925.1)
  %s937.0 = extractvalue { i64, i64 } %909, 0
  %s937.1 = extractvalue { i64, i64 } %909, 1
; call <kernels::Fp2>::add
  %910 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s933.0, i64 noundef %s933.1, i64 noundef %s935.0, i64 noundef %s935.1)
; call <kernels::Fp2>::add
  %911 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s923.0, i64 noundef %s923.1, i64 noundef %s925.0, i64 noundef %s925.1)
  %s938.1 = extractvalue { i64, i64 } %910, 1
  %s938.0 = extractvalue { i64, i64 } %910, 0
  %s939.0 = extractvalue { i64, i64 } %911, 0
  %s939.1 = extractvalue { i64, i64 } %911, 1
; call <kernels::Fp2>::mul
  %912 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s938.0, i64 noundef %s938.1, i64 noundef %s939.0, i64 noundef %s939.1)
  %s940.0 = extractvalue { i64, i64 } %912, 0
  %s940.1 = extractvalue { i64, i64 } %912, 1
; call <kernels::Fp2>::sub
  %913 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s940.0, i64 noundef %s940.1, i64 noundef %s936.0, i64 noundef %s936.1)
  %s941.0 = extractvalue { i64, i64 } %913, 0
  %s941.1 = extractvalue { i64, i64 } %913, 1
; call <kernels::Fp2>::sub
  %914 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s941.0, i64 noundef %s941.1, i64 noundef %s937.0, i64 noundef %s937.1)
  %s942.0 = extractvalue { i64, i64 } %914, 0
  %s942.1 = extractvalue { i64, i64 } %914, 1
; call <kernels::Fp2>::mul
  %915 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s936.0, i64 noundef %s936.1, i64 noundef %s930.0, i64 noundef %s930.1)
  %s943.0 = extractvalue { i64, i64 } %915, 0
  %s943.1 = extractvalue { i64, i64 } %915, 1
; call <kernels::Fp2>::mul
  %916 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s936.0, i64 noundef %s936.1, i64 noundef %s932.0, i64 noundef %s932.1)
; call <kernels::Fp2>::mul
  %917 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s942.0, i64 noundef %s942.1, i64 noundef %s930.0, i64 noundef %s930.1)
  %s944.1 = extractvalue { i64, i64 } %916, 1
  %s944.0 = extractvalue { i64, i64 } %916, 0
  %s945.0 = extractvalue { i64, i64 } %917, 0
  %s945.1 = extractvalue { i64, i64 } %917, 1
; call <kernels::Fp2>::add
  %918 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s944.0, i64 noundef %s944.1, i64 noundef %s945.0, i64 noundef %s945.1)
  %s946.0 = extractvalue { i64, i64 } %918, 0
  %s946.1 = extractvalue { i64, i64 } %918, 1
; call <kernels::Fp2>::mul
  %919 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s942.0, i64 noundef %s942.1, i64 noundef %s932.0, i64 noundef %s932.1)
; call <kernels::Fp2>::mul
  %920 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s937.0, i64 noundef %s937.1, i64 noundef %s930.0, i64 noundef %s930.1)
  %s947.1 = extractvalue { i64, i64 } %919, 1
  %s947.0 = extractvalue { i64, i64 } %919, 0
  %s948.0 = extractvalue { i64, i64 } %920, 0
  %s948.1 = extractvalue { i64, i64 } %920, 1
; call <kernels::Fp2>::add
  %921 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s947.0, i64 noundef %s947.1, i64 noundef %s948.0, i64 noundef %s948.1)
  %s949.0 = extractvalue { i64, i64 } %921, 0
  %s949.1 = extractvalue { i64, i64 } %921, 1
; call <kernels::Fp2>::mul
  %922 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s937.0, i64 noundef %s937.1, i64 noundef %s932.0, i64 noundef %s932.1)
  %s950.0 = extractvalue { i64, i64 } %922, 0
  %s950.1 = extractvalue { i64, i64 } %922, 1
; call <kernels::Fp2>::add
  %923 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s923.0, i64 noundef %s923.1, i64 noundef %s930.0, i64 noundef %s930.1)
; call <kernels::Fp2>::add
  %924 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s925.0, i64 noundef %s925.1, i64 noundef %s932.0, i64 noundef %s932.1)
  %s951.1 = extractvalue { i64, i64 } %923, 1
  %s951.0 = extractvalue { i64, i64 } %923, 0
; call <kernels::Fp2>::sub
  %925 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s943.0, i64 noundef %s943.1, i64 noundef %s951.0, i64 noundef %s951.1)
  %s952.1 = extractvalue { i64, i64 } %924, 1
  %s952.0 = extractvalue { i64, i64 } %924, 0
  %s953.0 = extractvalue { i64, i64 } %925, 0
  %s953.1 = extractvalue { i64, i64 } %925, 1
; call <kernels::Fp2>::sub
  %926 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s946.0, i64 noundef %s946.1, i64 noundef %s952.0, i64 noundef %s952.1)
  %s954.0 = extractvalue { i64, i64 } %926, 0
  %s954.1 = extractvalue { i64, i64 } %926, 1
  %_0.i38 = getelementptr inbounds nuw i8, ptr %params, i64 1744
  %s955.0 = load i64, ptr %_0.i38, align 8, !noundef !3
  %927 = getelementptr inbounds nuw i8, ptr %params, i64 1752
  %s955.1 = load i64, ptr %927, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %928 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s953.0, i64 noundef %s953.1, i64 noundef %s955.0, i64 noundef %s955.1)
  %s956.0 = extractvalue { i64, i64 } %928, 0
  %s956.1 = extractvalue { i64, i64 } %928, 1
; call <kernels::Fp2>::mul
  %929 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s954.0, i64 noundef %s954.1, i64 noundef %s955.0, i64 noundef %s955.1)
  %s957.0 = extractvalue { i64, i64 } %929, 0
  %s957.1 = extractvalue { i64, i64 } %929, 1
; call <kernels::Fp2>::mul
  %930 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s949.0, i64 noundef %s949.1, i64 noundef %s955.0, i64 noundef %s955.1)
  %s958.0 = extractvalue { i64, i64 } %930, 0
  %s958.1 = extractvalue { i64, i64 } %930, 1
; call <kernels::Fp2>::mul
  %931 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s950.0, i64 noundef %s950.1, i64 noundef %s955.0, i64 noundef %s955.1)
  %s959.0 = extractvalue { i64, i64 } %931, 0
  %s959.1 = extractvalue { i64, i64 } %931, 1
; call <kernels::Fp2>::add
  %932 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s915.0, i64 noundef %s915.1, i64 noundef %s956.0, i64 noundef %s956.1)
  %s960.0 = extractvalue { i64, i64 } %932, 0
  %s960.1 = extractvalue { i64, i64 } %932, 1
; call <kernels::Fp2>::add
  %933 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s916.0, i64 noundef %s916.1, i64 noundef %s957.0, i64 noundef %s957.1)
  %s961.0 = extractvalue { i64, i64 } %933, 0
  %s961.1 = extractvalue { i64, i64 } %933, 1
; call <kernels::Fp2>::add
  %934 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s917.0, i64 noundef %s917.1, i64 noundef %s958.0, i64 noundef %s958.1)
  %s962.0 = extractvalue { i64, i64 } %934, 0
  %s962.1 = extractvalue { i64, i64 } %934, 1
; call <kernels::Fp2>::add
  %935 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s918.0, i64 noundef %s918.1, i64 noundef %s959.0, i64 noundef %s959.1)
  %s963.0 = extractvalue { i64, i64 } %935, 0
  %s963.1 = extractvalue { i64, i64 } %935, 1
  %_0.i37 = getelementptr inbounds nuw i8, ptr %params, i64 1760
  %s964.0 = load i64, ptr %_0.i37, align 8, !noundef !3
  %936 = getelementptr inbounds nuw i8, ptr %params, i64 1768
  %s964.1 = load i64, ptr %936, align 8, !noundef !3
  %_0.i259 = getelementptr inbounds nuw i8, ptr %bases, i64 224
  %s965 = load i64, ptr %_0.i259, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %937 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s106.0, i64 noundef %s106.1, i64 noundef %s965)
; call <kernels::Fp2>::mul_base
  %938 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s108.0, i64 noundef %s108.1, i64 noundef %s965)
  %s966.1 = extractvalue { i64, i64 } %937, 1
  %s966.0 = extractvalue { i64, i64 } %937, 0
  %s967.0 = extractvalue { i64, i64 } %938, 0
  %s967.1 = extractvalue { i64, i64 } %938, 1
; call <kernels::Fp2>::sub
  %939 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s964.0, i64 noundef %s964.1, i64 noundef %s966.0, i64 noundef %s966.1)
  %s968.0 = extractvalue { i64, i64 } %939, 0
  %s968.1 = extractvalue { i64, i64 } %939, 1
  %_0.i36 = getelementptr inbounds nuw i8, ptr %params, i64 1776
  %s969.0 = load i64, ptr %_0.i36, align 8, !noundef !3
  %940 = getelementptr inbounds nuw i8, ptr %params, i64 1784
  %s969.1 = load i64, ptr %940, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %941 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s969.0, i64 noundef %s969.1, i64 noundef %s967.0, i64 noundef %s967.1)
  %s970.0 = extractvalue { i64, i64 } %941, 0
  %s970.1 = extractvalue { i64, i64 } %941, 1
  %_0.i35 = getelementptr inbounds nuw i8, ptr %params, i64 1792
  %s971.0 = load i64, ptr %_0.i35, align 8, !noundef !3
  %942 = getelementptr inbounds nuw i8, ptr %params, i64 1800
  %s971.1 = load i64, ptr %942, align 8, !noundef !3
  %_0.i258 = getelementptr inbounds nuw i8, ptr %bases, i64 232
  %s972 = load i64, ptr %_0.i258, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %943 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s114.0, i64 noundef %s114.1, i64 noundef %s972)
; call <kernels::Fp2>::mul_base
  %944 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s116.0, i64 noundef %s116.1, i64 noundef %s972)
  %s973.1 = extractvalue { i64, i64 } %943, 1
  %s973.0 = extractvalue { i64, i64 } %943, 0
  %s974.0 = extractvalue { i64, i64 } %944, 0
  %s974.1 = extractvalue { i64, i64 } %944, 1
; call <kernels::Fp2>::sub
  %945 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s971.0, i64 noundef %s971.1, i64 noundef %s973.0, i64 noundef %s973.1)
  %s975.0 = extractvalue { i64, i64 } %945, 0
  %s975.1 = extractvalue { i64, i64 } %945, 1
  %_0.i34 = getelementptr inbounds nuw i8, ptr %params, i64 1808
  %s976.0 = load i64, ptr %_0.i34, align 8, !noundef !3
  %946 = getelementptr inbounds nuw i8, ptr %params, i64 1816
  %s976.1 = load i64, ptr %946, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %947 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s976.0, i64 noundef %s976.1, i64 noundef %s974.0, i64 noundef %s974.1)
  %s977.0 = extractvalue { i64, i64 } %947, 0
  %s977.1 = extractvalue { i64, i64 } %947, 1
  %_0.i33 = getelementptr inbounds nuw i8, ptr %raw, i64 1792
  %s978.0 = load i64, ptr %_0.i33, align 8, !noundef !3
  %948 = getelementptr inbounds nuw i8, ptr %raw, i64 1800
  %s978.1 = load i64, ptr %948, align 8, !noundef !3
  %_0.i32 = getelementptr inbounds nuw i8, ptr %raw, i64 1808
  %s979.0 = load i64, ptr %_0.i32, align 8, !noundef !3
  %949 = getelementptr inbounds nuw i8, ptr %raw, i64 1816
  %s979.1 = load i64, ptr %949, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %950 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s979.0, i64 noundef %s979.1, i64 noundef %s978.0, i64 noundef %s978.1)
  %s980.0 = extractvalue { i64, i64 } %950, 0
  %s980.1 = extractvalue { i64, i64 } %950, 1
; call <kernels::Fp2>::mul
  %951 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s978.0, i64 noundef %s978.1, i64 noundef %s968.0, i64 noundef %s968.1)
  %s981.0 = extractvalue { i64, i64 } %951, 0
  %s981.1 = extractvalue { i64, i64 } %951, 1
; call <kernels::Fp2>::mul
  %952 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s980.0, i64 noundef %s980.1, i64 noundef %s970.0, i64 noundef %s970.1)
  %s982.0 = extractvalue { i64, i64 } %952, 0
  %s982.1 = extractvalue { i64, i64 } %952, 1
; call <kernels::Fp2>::add
  %953 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s978.0, i64 noundef %s978.1, i64 noundef %s980.0, i64 noundef %s980.1)
; call <kernels::Fp2>::add
  %954 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s968.0, i64 noundef %s968.1, i64 noundef %s970.0, i64 noundef %s970.1)
  %s983.1 = extractvalue { i64, i64 } %953, 1
  %s983.0 = extractvalue { i64, i64 } %953, 0
  %s984.0 = extractvalue { i64, i64 } %954, 0
  %s984.1 = extractvalue { i64, i64 } %954, 1
; call <kernels::Fp2>::mul
  %955 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s983.0, i64 noundef %s983.1, i64 noundef %s984.0, i64 noundef %s984.1)
  %s985.0 = extractvalue { i64, i64 } %955, 0
  %s985.1 = extractvalue { i64, i64 } %955, 1
; call <kernels::Fp2>::sub
  %956 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s985.0, i64 noundef %s985.1, i64 noundef %s981.0, i64 noundef %s981.1)
  %s986.0 = extractvalue { i64, i64 } %956, 0
  %s986.1 = extractvalue { i64, i64 } %956, 1
; call <kernels::Fp2>::sub
  %957 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s986.0, i64 noundef %s986.1, i64 noundef %s982.0, i64 noundef %s982.1)
  %s987.0 = extractvalue { i64, i64 } %957, 0
  %s987.1 = extractvalue { i64, i64 } %957, 1
; call <kernels::Fp2>::mul
  %958 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s981.0, i64 noundef %s981.1, i64 noundef %s975.0, i64 noundef %s975.1)
  %s988.0 = extractvalue { i64, i64 } %958, 0
  %s988.1 = extractvalue { i64, i64 } %958, 1
; call <kernels::Fp2>::mul
  %959 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s981.0, i64 noundef %s981.1, i64 noundef %s977.0, i64 noundef %s977.1)
; call <kernels::Fp2>::mul
  %960 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s987.0, i64 noundef %s987.1, i64 noundef %s975.0, i64 noundef %s975.1)
  %s989.1 = extractvalue { i64, i64 } %959, 1
  %s989.0 = extractvalue { i64, i64 } %959, 0
  %s990.0 = extractvalue { i64, i64 } %960, 0
  %s990.1 = extractvalue { i64, i64 } %960, 1
; call <kernels::Fp2>::add
  %961 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s989.0, i64 noundef %s989.1, i64 noundef %s990.0, i64 noundef %s990.1)
  %s991.0 = extractvalue { i64, i64 } %961, 0
  %s991.1 = extractvalue { i64, i64 } %961, 1
; call <kernels::Fp2>::mul
  %962 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s987.0, i64 noundef %s987.1, i64 noundef %s977.0, i64 noundef %s977.1)
; call <kernels::Fp2>::mul
  %963 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s982.0, i64 noundef %s982.1, i64 noundef %s975.0, i64 noundef %s975.1)
  %s992.1 = extractvalue { i64, i64 } %962, 1
  %s992.0 = extractvalue { i64, i64 } %962, 0
  %s993.0 = extractvalue { i64, i64 } %963, 0
  %s993.1 = extractvalue { i64, i64 } %963, 1
; call <kernels::Fp2>::add
  %964 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s992.0, i64 noundef %s992.1, i64 noundef %s993.0, i64 noundef %s993.1)
  %s994.0 = extractvalue { i64, i64 } %964, 0
  %s994.1 = extractvalue { i64, i64 } %964, 1
; call <kernels::Fp2>::mul
  %965 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s982.0, i64 noundef %s982.1, i64 noundef %s977.0, i64 noundef %s977.1)
  %s995.0 = extractvalue { i64, i64 } %965, 0
  %s995.1 = extractvalue { i64, i64 } %965, 1
; call <kernels::Fp2>::add
  %966 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s968.0, i64 noundef %s968.1, i64 noundef %s975.0, i64 noundef %s975.1)
; call <kernels::Fp2>::add
  %967 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s970.0, i64 noundef %s970.1, i64 noundef %s977.0, i64 noundef %s977.1)
  %s996.1 = extractvalue { i64, i64 } %966, 1
  %s996.0 = extractvalue { i64, i64 } %966, 0
; call <kernels::Fp2>::sub
  %968 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s988.0, i64 noundef %s988.1, i64 noundef %s996.0, i64 noundef %s996.1)
  %s997.1 = extractvalue { i64, i64 } %967, 1
  %s997.0 = extractvalue { i64, i64 } %967, 0
  %s998.0 = extractvalue { i64, i64 } %968, 0
  %s998.1 = extractvalue { i64, i64 } %968, 1
; call <kernels::Fp2>::sub
  %969 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s991.0, i64 noundef %s991.1, i64 noundef %s997.0, i64 noundef %s997.1)
  %s999.0 = extractvalue { i64, i64 } %969, 0
  %s999.1 = extractvalue { i64, i64 } %969, 1
  %_0.i31 = getelementptr inbounds nuw i8, ptr %params, i64 1824
  %s1000.0 = load i64, ptr %_0.i31, align 8, !noundef !3
  %970 = getelementptr inbounds nuw i8, ptr %params, i64 1832
  %s1000.1 = load i64, ptr %970, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %971 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s998.0, i64 noundef %s998.1, i64 noundef %s1000.0, i64 noundef %s1000.1)
  %s1001.0 = extractvalue { i64, i64 } %971, 0
  %s1001.1 = extractvalue { i64, i64 } %971, 1
; call <kernels::Fp2>::mul
  %972 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s999.0, i64 noundef %s999.1, i64 noundef %s1000.0, i64 noundef %s1000.1)
  %s1002.0 = extractvalue { i64, i64 } %972, 0
  %s1002.1 = extractvalue { i64, i64 } %972, 1
; call <kernels::Fp2>::mul
  %973 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s994.0, i64 noundef %s994.1, i64 noundef %s1000.0, i64 noundef %s1000.1)
  %s1003.0 = extractvalue { i64, i64 } %973, 0
  %s1003.1 = extractvalue { i64, i64 } %973, 1
; call <kernels::Fp2>::mul
  %974 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s995.0, i64 noundef %s995.1, i64 noundef %s1000.0, i64 noundef %s1000.1)
  %s1004.0 = extractvalue { i64, i64 } %974, 0
  %s1004.1 = extractvalue { i64, i64 } %974, 1
; call <kernels::Fp2>::add
  %975 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s960.0, i64 noundef %s960.1, i64 noundef %s1001.0, i64 noundef %s1001.1)
  %s1005.0 = extractvalue { i64, i64 } %975, 0
  %s1005.1 = extractvalue { i64, i64 } %975, 1
; call <kernels::Fp2>::add
  %976 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s961.0, i64 noundef %s961.1, i64 noundef %s1002.0, i64 noundef %s1002.1)
  %s1006.0 = extractvalue { i64, i64 } %976, 0
  %s1006.1 = extractvalue { i64, i64 } %976, 1
; call <kernels::Fp2>::add
  %977 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s962.0, i64 noundef %s962.1, i64 noundef %s1003.0, i64 noundef %s1003.1)
  %s1007.0 = extractvalue { i64, i64 } %977, 0
  %s1007.1 = extractvalue { i64, i64 } %977, 1
; call <kernels::Fp2>::add
  %978 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s963.0, i64 noundef %s963.1, i64 noundef %s1004.0, i64 noundef %s1004.1)
  %s1008.0 = extractvalue { i64, i64 } %978, 0
  %s1008.1 = extractvalue { i64, i64 } %978, 1
  %_0.i30 = getelementptr inbounds nuw i8, ptr %params, i64 1840
  %s1009.0 = load i64, ptr %_0.i30, align 8, !noundef !3
  %979 = getelementptr inbounds nuw i8, ptr %params, i64 1848
  %s1009.1 = load i64, ptr %979, align 8, !noundef !3
  %_0.i257 = getelementptr inbounds nuw i8, ptr %bases, i64 240
  %s1010 = load i64, ptr %_0.i257, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %980 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s122.0, i64 noundef %s122.1, i64 noundef %s1010)
; call <kernels::Fp2>::mul_base
  %981 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s124.0, i64 noundef %s124.1, i64 noundef %s1010)
  %s1011.1 = extractvalue { i64, i64 } %980, 1
  %s1011.0 = extractvalue { i64, i64 } %980, 0
  %s1012.0 = extractvalue { i64, i64 } %981, 0
  %s1012.1 = extractvalue { i64, i64 } %981, 1
; call <kernels::Fp2>::sub
  %982 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1009.0, i64 noundef %s1009.1, i64 noundef %s1011.0, i64 noundef %s1011.1)
  %s1013.0 = extractvalue { i64, i64 } %982, 0
  %s1013.1 = extractvalue { i64, i64 } %982, 1
  %_0.i29 = getelementptr inbounds nuw i8, ptr %params, i64 1856
  %s1014.0 = load i64, ptr %_0.i29, align 8, !noundef !3
  %983 = getelementptr inbounds nuw i8, ptr %params, i64 1864
  %s1014.1 = load i64, ptr %983, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %984 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1014.0, i64 noundef %s1014.1, i64 noundef %s1012.0, i64 noundef %s1012.1)
  %s1015.0 = extractvalue { i64, i64 } %984, 0
  %s1015.1 = extractvalue { i64, i64 } %984, 1
  %_0.i28 = getelementptr inbounds nuw i8, ptr %params, i64 1872
  %s1016.0 = load i64, ptr %_0.i28, align 8, !noundef !3
  %985 = getelementptr inbounds nuw i8, ptr %params, i64 1880
  %s1016.1 = load i64, ptr %985, align 8, !noundef !3
  %_0.i256 = getelementptr inbounds nuw i8, ptr %bases, i64 248
  %s1017 = load i64, ptr %_0.i256, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %986 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s130.0, i64 noundef %s130.1, i64 noundef %s1017)
; call <kernels::Fp2>::mul_base
  %987 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s132.0, i64 noundef %s132.1, i64 noundef %s1017)
  %s1018.1 = extractvalue { i64, i64 } %986, 1
  %s1018.0 = extractvalue { i64, i64 } %986, 0
  %s1019.0 = extractvalue { i64, i64 } %987, 0
  %s1019.1 = extractvalue { i64, i64 } %987, 1
; call <kernels::Fp2>::sub
  %988 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1016.0, i64 noundef %s1016.1, i64 noundef %s1018.0, i64 noundef %s1018.1)
  %s1020.0 = extractvalue { i64, i64 } %988, 0
  %s1020.1 = extractvalue { i64, i64 } %988, 1
  %_0.i27 = getelementptr inbounds nuw i8, ptr %params, i64 1888
  %s1021.0 = load i64, ptr %_0.i27, align 8, !noundef !3
  %989 = getelementptr inbounds nuw i8, ptr %params, i64 1896
  %s1021.1 = load i64, ptr %989, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %990 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1021.0, i64 noundef %s1021.1, i64 noundef %s1019.0, i64 noundef %s1019.1)
  %s1022.0 = extractvalue { i64, i64 } %990, 0
  %s1022.1 = extractvalue { i64, i64 } %990, 1
  %_0.i26 = getelementptr inbounds nuw i8, ptr %raw, i64 1824
  %s1023.0 = load i64, ptr %_0.i26, align 8, !noundef !3
  %991 = getelementptr inbounds nuw i8, ptr %raw, i64 1832
  %s1023.1 = load i64, ptr %991, align 8, !noundef !3
  %_0.i25 = getelementptr inbounds nuw i8, ptr %raw, i64 1840
  %s1024.0 = load i64, ptr %_0.i25, align 8, !noundef !3
  %992 = getelementptr inbounds nuw i8, ptr %raw, i64 1848
  %s1024.1 = load i64, ptr %992, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %993 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1024.0, i64 noundef %s1024.1, i64 noundef %s1023.0, i64 noundef %s1023.1)
  %s1025.0 = extractvalue { i64, i64 } %993, 0
  %s1025.1 = extractvalue { i64, i64 } %993, 1
; call <kernels::Fp2>::mul
  %994 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1023.0, i64 noundef %s1023.1, i64 noundef %s1013.0, i64 noundef %s1013.1)
  %s1026.0 = extractvalue { i64, i64 } %994, 0
  %s1026.1 = extractvalue { i64, i64 } %994, 1
; call <kernels::Fp2>::mul
  %995 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1025.0, i64 noundef %s1025.1, i64 noundef %s1015.0, i64 noundef %s1015.1)
  %s1027.0 = extractvalue { i64, i64 } %995, 0
  %s1027.1 = extractvalue { i64, i64 } %995, 1
; call <kernels::Fp2>::add
  %996 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1023.0, i64 noundef %s1023.1, i64 noundef %s1025.0, i64 noundef %s1025.1)
; call <kernels::Fp2>::add
  %997 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1013.0, i64 noundef %s1013.1, i64 noundef %s1015.0, i64 noundef %s1015.1)
  %s1028.1 = extractvalue { i64, i64 } %996, 1
  %s1028.0 = extractvalue { i64, i64 } %996, 0
  %s1029.0 = extractvalue { i64, i64 } %997, 0
  %s1029.1 = extractvalue { i64, i64 } %997, 1
; call <kernels::Fp2>::mul
  %998 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1028.0, i64 noundef %s1028.1, i64 noundef %s1029.0, i64 noundef %s1029.1)
  %s1030.0 = extractvalue { i64, i64 } %998, 0
  %s1030.1 = extractvalue { i64, i64 } %998, 1
; call <kernels::Fp2>::sub
  %999 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1030.0, i64 noundef %s1030.1, i64 noundef %s1026.0, i64 noundef %s1026.1)
  %s1031.0 = extractvalue { i64, i64 } %999, 0
  %s1031.1 = extractvalue { i64, i64 } %999, 1
; call <kernels::Fp2>::sub
  %1000 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1031.0, i64 noundef %s1031.1, i64 noundef %s1027.0, i64 noundef %s1027.1)
  %s1032.0 = extractvalue { i64, i64 } %1000, 0
  %s1032.1 = extractvalue { i64, i64 } %1000, 1
; call <kernels::Fp2>::mul
  %1001 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1026.0, i64 noundef %s1026.1, i64 noundef %s1020.0, i64 noundef %s1020.1)
  %s1033.0 = extractvalue { i64, i64 } %1001, 0
  %s1033.1 = extractvalue { i64, i64 } %1001, 1
; call <kernels::Fp2>::mul
  %1002 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1026.0, i64 noundef %s1026.1, i64 noundef %s1022.0, i64 noundef %s1022.1)
; call <kernels::Fp2>::mul
  %1003 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1032.0, i64 noundef %s1032.1, i64 noundef %s1020.0, i64 noundef %s1020.1)
  %s1034.1 = extractvalue { i64, i64 } %1002, 1
  %s1034.0 = extractvalue { i64, i64 } %1002, 0
  %s1035.0 = extractvalue { i64, i64 } %1003, 0
  %s1035.1 = extractvalue { i64, i64 } %1003, 1
; call <kernels::Fp2>::add
  %1004 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1034.0, i64 noundef %s1034.1, i64 noundef %s1035.0, i64 noundef %s1035.1)
  %s1036.0 = extractvalue { i64, i64 } %1004, 0
  %s1036.1 = extractvalue { i64, i64 } %1004, 1
; call <kernels::Fp2>::mul
  %1005 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1032.0, i64 noundef %s1032.1, i64 noundef %s1022.0, i64 noundef %s1022.1)
; call <kernels::Fp2>::mul
  %1006 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1027.0, i64 noundef %s1027.1, i64 noundef %s1020.0, i64 noundef %s1020.1)
  %s1037.1 = extractvalue { i64, i64 } %1005, 1
  %s1037.0 = extractvalue { i64, i64 } %1005, 0
  %s1038.0 = extractvalue { i64, i64 } %1006, 0
  %s1038.1 = extractvalue { i64, i64 } %1006, 1
; call <kernels::Fp2>::add
  %1007 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1037.0, i64 noundef %s1037.1, i64 noundef %s1038.0, i64 noundef %s1038.1)
  %s1039.0 = extractvalue { i64, i64 } %1007, 0
  %s1039.1 = extractvalue { i64, i64 } %1007, 1
; call <kernels::Fp2>::mul
  %1008 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1027.0, i64 noundef %s1027.1, i64 noundef %s1022.0, i64 noundef %s1022.1)
  %s1040.0 = extractvalue { i64, i64 } %1008, 0
  %s1040.1 = extractvalue { i64, i64 } %1008, 1
; call <kernels::Fp2>::add
  %1009 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1013.0, i64 noundef %s1013.1, i64 noundef %s1020.0, i64 noundef %s1020.1)
; call <kernels::Fp2>::add
  %1010 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1015.0, i64 noundef %s1015.1, i64 noundef %s1022.0, i64 noundef %s1022.1)
  %s1041.1 = extractvalue { i64, i64 } %1009, 1
  %s1041.0 = extractvalue { i64, i64 } %1009, 0
; call <kernels::Fp2>::sub
  %1011 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1033.0, i64 noundef %s1033.1, i64 noundef %s1041.0, i64 noundef %s1041.1)
  %s1042.1 = extractvalue { i64, i64 } %1010, 1
  %s1042.0 = extractvalue { i64, i64 } %1010, 0
  %s1043.0 = extractvalue { i64, i64 } %1011, 0
  %s1043.1 = extractvalue { i64, i64 } %1011, 1
; call <kernels::Fp2>::sub
  %1012 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1036.0, i64 noundef %s1036.1, i64 noundef %s1042.0, i64 noundef %s1042.1)
  %s1044.0 = extractvalue { i64, i64 } %1012, 0
  %s1044.1 = extractvalue { i64, i64 } %1012, 1
  %_0.i24 = getelementptr inbounds nuw i8, ptr %params, i64 1904
  %s1045.0 = load i64, ptr %_0.i24, align 8, !noundef !3
  %1013 = getelementptr inbounds nuw i8, ptr %params, i64 1912
  %s1045.1 = load i64, ptr %1013, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1014 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1043.0, i64 noundef %s1043.1, i64 noundef %s1045.0, i64 noundef %s1045.1)
  %s1046.0 = extractvalue { i64, i64 } %1014, 0
  %s1046.1 = extractvalue { i64, i64 } %1014, 1
; call <kernels::Fp2>::mul
  %1015 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1044.0, i64 noundef %s1044.1, i64 noundef %s1045.0, i64 noundef %s1045.1)
  %s1047.0 = extractvalue { i64, i64 } %1015, 0
  %s1047.1 = extractvalue { i64, i64 } %1015, 1
; call <kernels::Fp2>::mul
  %1016 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1039.0, i64 noundef %s1039.1, i64 noundef %s1045.0, i64 noundef %s1045.1)
  %s1048.0 = extractvalue { i64, i64 } %1016, 0
  %s1048.1 = extractvalue { i64, i64 } %1016, 1
; call <kernels::Fp2>::mul
  %1017 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1040.0, i64 noundef %s1040.1, i64 noundef %s1045.0, i64 noundef %s1045.1)
  %s1049.0 = extractvalue { i64, i64 } %1017, 0
  %s1049.1 = extractvalue { i64, i64 } %1017, 1
; call <kernels::Fp2>::add
  %1018 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1005.0, i64 noundef %s1005.1, i64 noundef %s1046.0, i64 noundef %s1046.1)
  %s1050.0 = extractvalue { i64, i64 } %1018, 0
  %s1050.1 = extractvalue { i64, i64 } %1018, 1
; call <kernels::Fp2>::add
  %1019 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1006.0, i64 noundef %s1006.1, i64 noundef %s1047.0, i64 noundef %s1047.1)
  %s1051.0 = extractvalue { i64, i64 } %1019, 0
  %s1051.1 = extractvalue { i64, i64 } %1019, 1
; call <kernels::Fp2>::add
  %1020 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1007.0, i64 noundef %s1007.1, i64 noundef %s1048.0, i64 noundef %s1048.1)
  %s1052.0 = extractvalue { i64, i64 } %1020, 0
  %s1052.1 = extractvalue { i64, i64 } %1020, 1
; call <kernels::Fp2>::add
  %1021 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1008.0, i64 noundef %s1008.1, i64 noundef %s1049.0, i64 noundef %s1049.1)
  %s1053.0 = extractvalue { i64, i64 } %1021, 0
  %s1053.1 = extractvalue { i64, i64 } %1021, 1
  %_0.i23 = getelementptr inbounds nuw i8, ptr %params, i64 1920
  %s1054.0 = load i64, ptr %_0.i23, align 8, !noundef !3
  %1022 = getelementptr inbounds nuw i8, ptr %params, i64 1928
  %s1054.1 = load i64, ptr %1022, align 8, !noundef !3
  %_0.i22 = getelementptr inbounds nuw i8, ptr %raw, i64 1248
  %s1055.0 = load i64, ptr %_0.i22, align 8, !noundef !3
  %1023 = getelementptr inbounds nuw i8, ptr %raw, i64 1256
  %s1055.1 = load i64, ptr %1023, align 8, !noundef !3
  %_0.i21 = getelementptr inbounds nuw i8, ptr %raw, i64 1264
  %s1056.0 = load i64, ptr %_0.i21, align 8, !noundef !3
  %1024 = getelementptr inbounds nuw i8, ptr %raw, i64 1272
  %s1056.1 = load i64, ptr %1024, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1025 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1056.0, i64 noundef %s1056.1, i64 noundef %s1055.0, i64 noundef %s1055.1)
  %s1057.0 = extractvalue { i64, i64 } %1025, 0
  %s1057.1 = extractvalue { i64, i64 } %1025, 1
  %_0.i255 = getelementptr inbounds nuw i8, ptr %bases, i64 256
  %s1058 = load i64, ptr %_0.i255, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1026 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1055.0, i64 noundef %s1055.1, i64 noundef %s1058)
; call <kernels::Fp2>::mul_base
  %1027 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1057.0, i64 noundef %s1057.1, i64 noundef %s1058)
  %s1059.1 = extractvalue { i64, i64 } %1026, 1
  %s1059.0 = extractvalue { i64, i64 } %1026, 0
  %s1060.0 = extractvalue { i64, i64 } %1027, 0
  %s1060.1 = extractvalue { i64, i64 } %1027, 1
; call <kernels::Fp2>::sub
  %1028 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1054.0, i64 noundef %s1054.1, i64 noundef %s1059.0, i64 noundef %s1059.1)
  %s1061.0 = extractvalue { i64, i64 } %1028, 0
  %s1061.1 = extractvalue { i64, i64 } %1028, 1
  %_0.i20 = getelementptr inbounds nuw i8, ptr %params, i64 1936
  %s1062.0 = load i64, ptr %_0.i20, align 8, !noundef !3
  %1029 = getelementptr inbounds nuw i8, ptr %params, i64 1944
  %s1062.1 = load i64, ptr %1029, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1030 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1062.0, i64 noundef %s1062.1, i64 noundef %s1060.0, i64 noundef %s1060.1)
  %s1063.0 = extractvalue { i64, i64 } %1030, 0
  %s1063.1 = extractvalue { i64, i64 } %1030, 1
  %_0.i19 = getelementptr inbounds nuw i8, ptr %params, i64 1952
  %s1064.0 = load i64, ptr %_0.i19, align 8, !noundef !3
  %1031 = getelementptr inbounds nuw i8, ptr %params, i64 1960
  %s1064.1 = load i64, ptr %1031, align 8, !noundef !3
  %_0.i254 = getelementptr inbounds nuw i8, ptr %bases, i64 264
  %s1065 = load i64, ptr %_0.i254, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1032 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1055.0, i64 noundef %s1055.1, i64 noundef %s1065)
; call <kernels::Fp2>::mul_base
  %1033 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1057.0, i64 noundef %s1057.1, i64 noundef %s1065)
  %s1066.1 = extractvalue { i64, i64 } %1032, 1
  %s1066.0 = extractvalue { i64, i64 } %1032, 0
  %s1067.0 = extractvalue { i64, i64 } %1033, 0
  %s1067.1 = extractvalue { i64, i64 } %1033, 1
; call <kernels::Fp2>::sub
  %1034 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1064.0, i64 noundef %s1064.1, i64 noundef %s1066.0, i64 noundef %s1066.1)
  %s1068.0 = extractvalue { i64, i64 } %1034, 0
  %s1068.1 = extractvalue { i64, i64 } %1034, 1
  %_0.i18 = getelementptr inbounds nuw i8, ptr %params, i64 1968
  %s1069.0 = load i64, ptr %_0.i18, align 8, !noundef !3
  %1035 = getelementptr inbounds nuw i8, ptr %params, i64 1976
  %s1069.1 = load i64, ptr %1035, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1036 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1069.0, i64 noundef %s1069.1, i64 noundef %s1067.0, i64 noundef %s1067.1)
  %s1070.0 = extractvalue { i64, i64 } %1036, 0
  %s1070.1 = extractvalue { i64, i64 } %1036, 1
  %_0.i17 = getelementptr inbounds nuw i8, ptr %raw, i64 1856
  %s1071.0 = load i64, ptr %_0.i17, align 8, !noundef !3
  %1037 = getelementptr inbounds nuw i8, ptr %raw, i64 1864
  %s1071.1 = load i64, ptr %1037, align 8, !noundef !3
  %_0.i16 = getelementptr inbounds nuw i8, ptr %raw, i64 1872
  %s1072.0 = load i64, ptr %_0.i16, align 8, !noundef !3
  %1038 = getelementptr inbounds nuw i8, ptr %raw, i64 1880
  %s1072.1 = load i64, ptr %1038, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1039 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1072.0, i64 noundef %s1072.1, i64 noundef %s1071.0, i64 noundef %s1071.1)
  %s1073.0 = extractvalue { i64, i64 } %1039, 0
  %s1073.1 = extractvalue { i64, i64 } %1039, 1
; call <kernels::Fp2>::mul
  %1040 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1071.0, i64 noundef %s1071.1, i64 noundef %s1061.0, i64 noundef %s1061.1)
  %s1074.0 = extractvalue { i64, i64 } %1040, 0
  %s1074.1 = extractvalue { i64, i64 } %1040, 1
; call <kernels::Fp2>::mul
  %1041 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1073.0, i64 noundef %s1073.1, i64 noundef %s1063.0, i64 noundef %s1063.1)
  %s1075.0 = extractvalue { i64, i64 } %1041, 0
  %s1075.1 = extractvalue { i64, i64 } %1041, 1
; call <kernels::Fp2>::add
  %1042 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1071.0, i64 noundef %s1071.1, i64 noundef %s1073.0, i64 noundef %s1073.1)
; call <kernels::Fp2>::add
  %1043 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1061.0, i64 noundef %s1061.1, i64 noundef %s1063.0, i64 noundef %s1063.1)
  %s1076.1 = extractvalue { i64, i64 } %1042, 1
  %s1076.0 = extractvalue { i64, i64 } %1042, 0
  %s1077.0 = extractvalue { i64, i64 } %1043, 0
  %s1077.1 = extractvalue { i64, i64 } %1043, 1
; call <kernels::Fp2>::mul
  %1044 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1076.0, i64 noundef %s1076.1, i64 noundef %s1077.0, i64 noundef %s1077.1)
  %s1078.0 = extractvalue { i64, i64 } %1044, 0
  %s1078.1 = extractvalue { i64, i64 } %1044, 1
; call <kernels::Fp2>::sub
  %1045 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1078.0, i64 noundef %s1078.1, i64 noundef %s1074.0, i64 noundef %s1074.1)
  %s1079.0 = extractvalue { i64, i64 } %1045, 0
  %s1079.1 = extractvalue { i64, i64 } %1045, 1
; call <kernels::Fp2>::sub
  %1046 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1079.0, i64 noundef %s1079.1, i64 noundef %s1075.0, i64 noundef %s1075.1)
  %s1080.0 = extractvalue { i64, i64 } %1046, 0
  %s1080.1 = extractvalue { i64, i64 } %1046, 1
; call <kernels::Fp2>::mul
  %1047 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1074.0, i64 noundef %s1074.1, i64 noundef %s1068.0, i64 noundef %s1068.1)
  %s1081.0 = extractvalue { i64, i64 } %1047, 0
  %s1081.1 = extractvalue { i64, i64 } %1047, 1
; call <kernels::Fp2>::mul
  %1048 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1074.0, i64 noundef %s1074.1, i64 noundef %s1070.0, i64 noundef %s1070.1)
; call <kernels::Fp2>::mul
  %1049 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1080.0, i64 noundef %s1080.1, i64 noundef %s1068.0, i64 noundef %s1068.1)
  %s1082.1 = extractvalue { i64, i64 } %1048, 1
  %s1082.0 = extractvalue { i64, i64 } %1048, 0
  %s1083.0 = extractvalue { i64, i64 } %1049, 0
  %s1083.1 = extractvalue { i64, i64 } %1049, 1
; call <kernels::Fp2>::add
  %1050 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1082.0, i64 noundef %s1082.1, i64 noundef %s1083.0, i64 noundef %s1083.1)
  %s1084.0 = extractvalue { i64, i64 } %1050, 0
  %s1084.1 = extractvalue { i64, i64 } %1050, 1
; call <kernels::Fp2>::mul
  %1051 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1080.0, i64 noundef %s1080.1, i64 noundef %s1070.0, i64 noundef %s1070.1)
; call <kernels::Fp2>::mul
  %1052 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1075.0, i64 noundef %s1075.1, i64 noundef %s1068.0, i64 noundef %s1068.1)
  %s1085.1 = extractvalue { i64, i64 } %1051, 1
  %s1085.0 = extractvalue { i64, i64 } %1051, 0
  %s1086.0 = extractvalue { i64, i64 } %1052, 0
  %s1086.1 = extractvalue { i64, i64 } %1052, 1
; call <kernels::Fp2>::add
  %1053 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1085.0, i64 noundef %s1085.1, i64 noundef %s1086.0, i64 noundef %s1086.1)
  %s1087.0 = extractvalue { i64, i64 } %1053, 0
  %s1087.1 = extractvalue { i64, i64 } %1053, 1
; call <kernels::Fp2>::mul
  %1054 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1075.0, i64 noundef %s1075.1, i64 noundef %s1070.0, i64 noundef %s1070.1)
  %s1088.0 = extractvalue { i64, i64 } %1054, 0
  %s1088.1 = extractvalue { i64, i64 } %1054, 1
; call <kernels::Fp2>::add
  %1055 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1061.0, i64 noundef %s1061.1, i64 noundef %s1068.0, i64 noundef %s1068.1)
; call <kernels::Fp2>::add
  %1056 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1063.0, i64 noundef %s1063.1, i64 noundef %s1070.0, i64 noundef %s1070.1)
  %s1089.1 = extractvalue { i64, i64 } %1055, 1
  %s1089.0 = extractvalue { i64, i64 } %1055, 0
; call <kernels::Fp2>::sub
  %1057 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1081.0, i64 noundef %s1081.1, i64 noundef %s1089.0, i64 noundef %s1089.1)
  %s1090.1 = extractvalue { i64, i64 } %1056, 1
  %s1090.0 = extractvalue { i64, i64 } %1056, 0
  %s1091.0 = extractvalue { i64, i64 } %1057, 0
  %s1091.1 = extractvalue { i64, i64 } %1057, 1
; call <kernels::Fp2>::sub
  %1058 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1084.0, i64 noundef %s1084.1, i64 noundef %s1090.0, i64 noundef %s1090.1)
  %s1092.0 = extractvalue { i64, i64 } %1058, 0
  %s1092.1 = extractvalue { i64, i64 } %1058, 1
  %_0.i15 = getelementptr inbounds nuw i8, ptr %params, i64 1984
  %s1093.0 = load i64, ptr %_0.i15, align 8, !noundef !3
  %1059 = getelementptr inbounds nuw i8, ptr %params, i64 1992
  %s1093.1 = load i64, ptr %1059, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1060 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1091.0, i64 noundef %s1091.1, i64 noundef %s1093.0, i64 noundef %s1093.1)
  %s1094.0 = extractvalue { i64, i64 } %1060, 0
  %s1094.1 = extractvalue { i64, i64 } %1060, 1
; call <kernels::Fp2>::mul
  %1061 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1092.0, i64 noundef %s1092.1, i64 noundef %s1093.0, i64 noundef %s1093.1)
  %s1095.0 = extractvalue { i64, i64 } %1061, 0
  %s1095.1 = extractvalue { i64, i64 } %1061, 1
; call <kernels::Fp2>::mul
  %1062 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1087.0, i64 noundef %s1087.1, i64 noundef %s1093.0, i64 noundef %s1093.1)
  %s1096.0 = extractvalue { i64, i64 } %1062, 0
  %s1096.1 = extractvalue { i64, i64 } %1062, 1
; call <kernels::Fp2>::mul
  %1063 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1088.0, i64 noundef %s1088.1, i64 noundef %s1093.0, i64 noundef %s1093.1)
  %s1097.0 = extractvalue { i64, i64 } %1063, 0
  %s1097.1 = extractvalue { i64, i64 } %1063, 1
; call <kernels::Fp2>::add
  %1064 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1050.0, i64 noundef %s1050.1, i64 noundef %s1094.0, i64 noundef %s1094.1)
  %s1098.0 = extractvalue { i64, i64 } %1064, 0
  %s1098.1 = extractvalue { i64, i64 } %1064, 1
; call <kernels::Fp2>::add
  %1065 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1051.0, i64 noundef %s1051.1, i64 noundef %s1095.0, i64 noundef %s1095.1)
  %s1099.0 = extractvalue { i64, i64 } %1065, 0
  %s1099.1 = extractvalue { i64, i64 } %1065, 1
; call <kernels::Fp2>::add
  %1066 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1052.0, i64 noundef %s1052.1, i64 noundef %s1096.0, i64 noundef %s1096.1)
  %s1100.0 = extractvalue { i64, i64 } %1066, 0
  %s1100.1 = extractvalue { i64, i64 } %1066, 1
; call <kernels::Fp2>::add
  %1067 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1053.0, i64 noundef %s1053.1, i64 noundef %s1097.0, i64 noundef %s1097.1)
  %s1101.0 = extractvalue { i64, i64 } %1067, 0
  %s1101.1 = extractvalue { i64, i64 } %1067, 1
  %s1102.0 = load i64, ptr %raw, align 8, !noundef !3
  %1068 = getelementptr inbounds nuw i8, ptr %raw, i64 8
  %s1102.1 = load i64, ptr %1068, align 8, !noundef !3
  %_0.i13 = getelementptr inbounds nuw i8, ptr %raw, i64 16
  %s1103.0 = load i64, ptr %_0.i13, align 8, !noundef !3
  %1069 = getelementptr inbounds nuw i8, ptr %raw, i64 24
  %s1103.1 = load i64, ptr %1069, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1070 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1103.0, i64 noundef %s1103.1, i64 noundef %s1102.0, i64 noundef %s1102.1)
  %s1104.0 = extractvalue { i64, i64 } %1070, 0
  %s1104.1 = extractvalue { i64, i64 } %1070, 1
; call <kernels::Fp2>::add
  %1071 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1098.0, i64 noundef %s1098.1, i64 noundef %s330.0, i64 noundef %s330.1)
  %s1105.0 = extractvalue { i64, i64 } %1071, 0
  %s1105.1 = extractvalue { i64, i64 } %1071, 1
; call <kernels::Fp2>::add
  %1072 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1099.0, i64 noundef %s1099.1, i64 noundef %s331.0, i64 noundef %s331.1)
  %s1106.0 = extractvalue { i64, i64 } %1072, 0
  %s1106.1 = extractvalue { i64, i64 } %1072, 1
; call <kernels::Fp2>::add
  %1073 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1100.0, i64 noundef %s1100.1, i64 noundef %s332.0, i64 noundef %s332.1)
  %s1107.0 = extractvalue { i64, i64 } %1073, 0
  %s1107.1 = extractvalue { i64, i64 } %1073, 1
; call <kernels::Fp2>::mul
  %1074 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1105.0, i64 noundef %s1105.1)
  %s1108.0 = extractvalue { i64, i64 } %1074, 0
  %s1108.1 = extractvalue { i64, i64 } %1074, 1
; call <kernels::Fp2>::mul
  %1075 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1106.0, i64 noundef %s1106.1)
; call <kernels::Fp2>::mul
  %1076 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1105.0, i64 noundef %s1105.1)
  %s1109.1 = extractvalue { i64, i64 } %1075, 1
  %s1109.0 = extractvalue { i64, i64 } %1075, 0
  %s1110.0 = extractvalue { i64, i64 } %1076, 0
  %s1110.1 = extractvalue { i64, i64 } %1076, 1
; call <kernels::Fp2>::add
  %1077 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1109.0, i64 noundef %s1109.1, i64 noundef %s1110.0, i64 noundef %s1110.1)
  %s1111.0 = extractvalue { i64, i64 } %1077, 0
  %s1111.1 = extractvalue { i64, i64 } %1077, 1
; call <kernels::Fp2>::mul
  %1078 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1107.0, i64 noundef %s1107.1)
; call <kernels::Fp2>::mul
  %1079 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1106.0, i64 noundef %s1106.1)
  %s1112.1 = extractvalue { i64, i64 } %1078, 1
  %s1112.0 = extractvalue { i64, i64 } %1078, 0
  %s1113.0 = extractvalue { i64, i64 } %1079, 0
  %s1113.1 = extractvalue { i64, i64 } %1079, 1
; call <kernels::Fp2>::add
  %1080 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1112.0, i64 noundef %s1112.1, i64 noundef %s1113.0, i64 noundef %s1113.1)
  %s1114.0 = extractvalue { i64, i64 } %1080, 0
  %s1114.1 = extractvalue { i64, i64 } %1080, 1
; call <kernels::Fp2>::mul
  %1081 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1101.0, i64 noundef %s1101.1)
; call <kernels::Fp2>::mul
  %1082 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1107.0, i64 noundef %s1107.1)
  %s1115.1 = extractvalue { i64, i64 } %1081, 1
  %s1115.0 = extractvalue { i64, i64 } %1081, 0
  %s1116.0 = extractvalue { i64, i64 } %1082, 0
  %s1116.1 = extractvalue { i64, i64 } %1082, 1
; call <kernels::Fp2>::add
  %1083 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1115.0, i64 noundef %s1115.1, i64 noundef %s1116.0, i64 noundef %s1116.1)
  %s1117.0 = extractvalue { i64, i64 } %1083, 0
  %s1117.1 = extractvalue { i64, i64 } %1083, 1
; call <kernels::Fp2>::mul
  %1084 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1101.0, i64 noundef %s1101.1)
  %_0.i253 = getelementptr inbounds nuw i8, ptr %bases, i64 272
  %s1119 = load i64, ptr %_0.i253, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1085 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s10.0, i64 noundef %s10.1, i64 noundef %s1119)
; call <kernels::Fp2>::mul_base
  %1086 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s12.0, i64 noundef %s12.1, i64 noundef %s1119)
  %s1120.1 = extractvalue { i64, i64 } %1085, 1
  %s1120.0 = extractvalue { i64, i64 } %1085, 0
; call <kernels::Fp2>::add
  %1087 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1120.0, i64 noundef %s1120.1, i64 noundef %s647.0, i64 noundef %s647.1)
  %s1121.1 = extractvalue { i64, i64 } %1086, 1
  %s1121.0 = extractvalue { i64, i64 } %1086, 0
  %s1122.0 = extractvalue { i64, i64 } %1087, 0
  %s1122.1 = extractvalue { i64, i64 } %1087, 1
; call <kernels::Fp2>::add
  %1088 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1121.0, i64 noundef %s1121.1, i64 noundef %s649.0, i64 noundef %s649.1)
  %s1123.0 = extractvalue { i64, i64 } %1088, 0
  %s1123.1 = extractvalue { i64, i64 } %1088, 1
  %_0.i12 = getelementptr inbounds nuw i8, ptr %params, i64 2000
  %s1124.0 = load i64, ptr %_0.i12, align 8, !noundef !3
  %1089 = getelementptr inbounds nuw i8, ptr %params, i64 2008
  %s1124.1 = load i64, ptr %1089, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1090 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1122.0, i64 noundef %s1122.1, i64 noundef %s1124.0, i64 noundef %s1124.1)
  %s1125.0 = extractvalue { i64, i64 } %1090, 0
  %s1125.1 = extractvalue { i64, i64 } %1090, 1
  %_0.i11 = getelementptr inbounds nuw i8, ptr %raw, i64 32
  %s1126.0 = load i64, ptr %_0.i11, align 8, !noundef !3
  %1091 = getelementptr inbounds nuw i8, ptr %raw, i64 40
  %s1126.1 = load i64, ptr %1091, align 8, !noundef !3
  %_0.i10 = getelementptr inbounds nuw i8, ptr %raw, i64 48
  %s1127.0 = load i64, ptr %_0.i10, align 8, !noundef !3
  %1092 = getelementptr inbounds nuw i8, ptr %raw, i64 56
  %s1127.1 = load i64, ptr %1092, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1093 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1127.0, i64 noundef %s1127.1, i64 noundef %s1126.0, i64 noundef %s1126.1)
  %s1128.0 = extractvalue { i64, i64 } %1093, 0
  %s1128.1 = extractvalue { i64, i64 } %1093, 1
; call <kernels::Fp2>::mul
  %1094 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1126.0, i64 noundef %s1126.1, i64 noundef %s1125.0, i64 noundef %s1125.1)
  %s1129.0 = extractvalue { i64, i64 } %1094, 0
  %s1129.1 = extractvalue { i64, i64 } %1094, 1
; call <kernels::Fp2>::mul
  %1095 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1128.0, i64 noundef %s1128.1, i64 noundef %s1123.0, i64 noundef %s1123.1)
  %s1130.0 = extractvalue { i64, i64 } %1095, 0
  %s1130.1 = extractvalue { i64, i64 } %1095, 1
; call <kernels::Fp2>::add
  %1096 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1126.0, i64 noundef %s1126.1, i64 noundef %s1128.0, i64 noundef %s1128.1)
; call <kernels::Fp2>::add
  %1097 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1125.0, i64 noundef %s1125.1, i64 noundef %s1123.0, i64 noundef %s1123.1)
  %s1131.1 = extractvalue { i64, i64 } %1096, 1
  %s1131.0 = extractvalue { i64, i64 } %1096, 0
  %s1132.0 = extractvalue { i64, i64 } %1097, 0
  %s1132.1 = extractvalue { i64, i64 } %1097, 1
; call <kernels::Fp2>::mul
  %1098 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1131.0, i64 noundef %s1131.1, i64 noundef %s1132.0, i64 noundef %s1132.1)
  %s1133.0 = extractvalue { i64, i64 } %1098, 0
  %s1133.1 = extractvalue { i64, i64 } %1098, 1
; call <kernels::Fp2>::sub
  %1099 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1133.0, i64 noundef %s1133.1, i64 noundef %s1129.0, i64 noundef %s1129.1)
  %s1134.0 = extractvalue { i64, i64 } %1099, 0
  %s1134.1 = extractvalue { i64, i64 } %1099, 1
; call <kernels::Fp2>::sub
  %1100 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1134.0, i64 noundef %s1134.1, i64 noundef %s1130.0, i64 noundef %s1130.1)
  %s1135.0 = extractvalue { i64, i64 } %1100, 0
  %s1135.1 = extractvalue { i64, i64 } %1100, 1
  %_0.i9 = getelementptr inbounds nuw i8, ptr %params, i64 2016
  %s1136.0 = load i64, ptr %_0.i9, align 8, !noundef !3
  %1101 = getelementptr inbounds nuw i8, ptr %params, i64 2024
  %s1136.1 = load i64, ptr %1101, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1102 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1129.0, i64 noundef %s1129.1, i64 noundef %s1136.0, i64 noundef %s1136.1)
  %s1137.0 = extractvalue { i64, i64 } %1102, 0
  %s1137.1 = extractvalue { i64, i64 } %1102, 1
; call <kernels::Fp2>::mul
  %1103 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1135.0, i64 noundef %s1135.1, i64 noundef %s1136.0, i64 noundef %s1136.1)
  %s1138.0 = extractvalue { i64, i64 } %1103, 0
  %s1138.1 = extractvalue { i64, i64 } %1103, 1
; call <kernels::Fp2>::mul
  %1104 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1130.0, i64 noundef %s1130.1, i64 noundef %s1136.0, i64 noundef %s1136.1)
  %s1139.0 = extractvalue { i64, i64 } %1104, 0
  %s1139.1 = extractvalue { i64, i64 } %1104, 1
; call <kernels::Fp2>::add
  %1105 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1108.0, i64 noundef %s1108.1, i64 noundef %s1137.0, i64 noundef %s1137.1)
  %s1140.0 = extractvalue { i64, i64 } %1105, 0
  %s1140.1 = extractvalue { i64, i64 } %1105, 1
; call <kernels::Fp2>::add
  %1106 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1111.0, i64 noundef %s1111.1, i64 noundef %s1138.0, i64 noundef %s1138.1)
  %s1141.0 = extractvalue { i64, i64 } %1106, 0
  %s1141.1 = extractvalue { i64, i64 } %1106, 1
; call <kernels::Fp2>::add
  %1107 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1114.0, i64 noundef %s1114.1, i64 noundef %s1139.0, i64 noundef %s1139.1)
  %s1142.0 = extractvalue { i64, i64 } %1107, 0
  %s1142.1 = extractvalue { i64, i64 } %1107, 1
  %_0.i252 = getelementptr inbounds nuw i8, ptr %bases, i64 280
  %s1143 = load i64, ptr %_0.i252, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1108 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s34.0, i64 noundef %s34.1, i64 noundef %s1143)
; call <kernels::Fp2>::mul_base
  %1109 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s36.0, i64 noundef %s36.1, i64 noundef %s1143)
  %s1144.1 = extractvalue { i64, i64 } %1108, 1
  %s1144.0 = extractvalue { i64, i64 } %1108, 0
; call <kernels::Fp2>::add
  %1110 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1144.0, i64 noundef %s1144.1, i64 noundef %s1055.0, i64 noundef %s1055.1)
  %s1145.1 = extractvalue { i64, i64 } %1109, 1
  %s1145.0 = extractvalue { i64, i64 } %1109, 0
  %s1146.0 = extractvalue { i64, i64 } %1110, 0
  %s1146.1 = extractvalue { i64, i64 } %1110, 1
; call <kernels::Fp2>::add
  %1111 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1145.0, i64 noundef %s1145.1, i64 noundef %s1057.0, i64 noundef %s1057.1)
  %s1147.0 = extractvalue { i64, i64 } %1111, 0
  %s1147.1 = extractvalue { i64, i64 } %1111, 1
  %_0.i8 = getelementptr inbounds nuw i8, ptr %params, i64 2032
  %s1148.0 = load i64, ptr %_0.i8, align 8, !noundef !3
  %1112 = getelementptr inbounds nuw i8, ptr %params, i64 2040
  %s1148.1 = load i64, ptr %1112, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1113 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1146.0, i64 noundef %s1146.1, i64 noundef %s1148.0, i64 noundef %s1148.1)
  %s1149.0 = extractvalue { i64, i64 } %1113, 0
  %s1149.1 = extractvalue { i64, i64 } %1113, 1
  %_0.i7 = getelementptr inbounds nuw i8, ptr %raw, i64 64
  %s1150.0 = load i64, ptr %_0.i7, align 8, !noundef !3
  %1114 = getelementptr inbounds nuw i8, ptr %raw, i64 72
  %s1150.1 = load i64, ptr %1114, align 8, !noundef !3
  %_0.i6 = getelementptr inbounds nuw i8, ptr %raw, i64 80
  %s1151.0 = load i64, ptr %_0.i6, align 8, !noundef !3
  %1115 = getelementptr inbounds nuw i8, ptr %raw, i64 88
  %s1151.1 = load i64, ptr %1115, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1116 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1151.0, i64 noundef %s1151.1, i64 noundef %s1150.0, i64 noundef %s1150.1)
  %s1152.0 = extractvalue { i64, i64 } %1116, 0
  %s1152.1 = extractvalue { i64, i64 } %1116, 1
; call <kernels::Fp2>::mul
  %1117 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1150.0, i64 noundef %s1150.1, i64 noundef %s1149.0, i64 noundef %s1149.1)
  %s1153.0 = extractvalue { i64, i64 } %1117, 0
  %s1153.1 = extractvalue { i64, i64 } %1117, 1
; call <kernels::Fp2>::mul
  %1118 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1152.0, i64 noundef %s1152.1, i64 noundef %s1147.0, i64 noundef %s1147.1)
  %s1154.0 = extractvalue { i64, i64 } %1118, 0
  %s1154.1 = extractvalue { i64, i64 } %1118, 1
; call <kernels::Fp2>::add
  %1119 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1150.0, i64 noundef %s1150.1, i64 noundef %s1152.0, i64 noundef %s1152.1)
; call <kernels::Fp2>::add
  %1120 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1149.0, i64 noundef %s1149.1, i64 noundef %s1147.0, i64 noundef %s1147.1)
  %s1155.1 = extractvalue { i64, i64 } %1119, 1
  %s1155.0 = extractvalue { i64, i64 } %1119, 0
  %s1156.0 = extractvalue { i64, i64 } %1120, 0
  %s1156.1 = extractvalue { i64, i64 } %1120, 1
; call <kernels::Fp2>::mul
  %1121 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1155.0, i64 noundef %s1155.1, i64 noundef %s1156.0, i64 noundef %s1156.1)
  %s1157.0 = extractvalue { i64, i64 } %1121, 0
  %s1157.1 = extractvalue { i64, i64 } %1121, 1
; call <kernels::Fp2>::sub
  %1122 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1157.0, i64 noundef %s1157.1, i64 noundef %s1153.0, i64 noundef %s1153.1)
  %s1158.0 = extractvalue { i64, i64 } %1122, 0
  %s1158.1 = extractvalue { i64, i64 } %1122, 1
; call <kernels::Fp2>::sub
  %1123 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1158.0, i64 noundef %s1158.1, i64 noundef %s1154.0, i64 noundef %s1154.1)
  %s1159.0 = extractvalue { i64, i64 } %1123, 0
  %s1159.1 = extractvalue { i64, i64 } %1123, 1
  %_0.i5 = getelementptr inbounds nuw i8, ptr %params, i64 2048
  %s1160.0 = load i64, ptr %_0.i5, align 8, !noundef !3
  %1124 = getelementptr inbounds nuw i8, ptr %params, i64 2056
  %s1160.1 = load i64, ptr %1124, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1125 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1153.0, i64 noundef %s1153.1, i64 noundef %s1160.0, i64 noundef %s1160.1)
  %s1161.0 = extractvalue { i64, i64 } %1125, 0
  %s1161.1 = extractvalue { i64, i64 } %1125, 1
; call <kernels::Fp2>::mul
  %1126 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1159.0, i64 noundef %s1159.1, i64 noundef %s1160.0, i64 noundef %s1160.1)
  %s1162.0 = extractvalue { i64, i64 } %1126, 0
  %s1162.1 = extractvalue { i64, i64 } %1126, 1
; call <kernels::Fp2>::mul
  %1127 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1154.0, i64 noundef %s1154.1, i64 noundef %s1160.0, i64 noundef %s1160.1)
  %s1163.0 = extractvalue { i64, i64 } %1127, 0
  %s1163.1 = extractvalue { i64, i64 } %1127, 1
; call <kernels::Fp2>::add
  %1128 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1140.0, i64 noundef %s1140.1, i64 noundef %s1161.0, i64 noundef %s1161.1)
  %s1164.0 = extractvalue { i64, i64 } %1128, 0
  %s1164.1 = extractvalue { i64, i64 } %1128, 1
; call <kernels::Fp2>::add
  %1129 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1141.0, i64 noundef %s1141.1, i64 noundef %s1162.0, i64 noundef %s1162.1)
  %s1165.0 = extractvalue { i64, i64 } %1129, 0
  %s1165.1 = extractvalue { i64, i64 } %1129, 1
; call <kernels::Fp2>::add
  %1130 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1142.0, i64 noundef %s1142.1, i64 noundef %s1163.0, i64 noundef %s1163.1)
  %s1166.0 = extractvalue { i64, i64 } %1130, 0
  %s1166.1 = extractvalue { i64, i64 } %1130, 1
  store i64 %s1164.0, ptr %out, align 8
  %1131 = getelementptr inbounds nuw i8, ptr %out, i64 8
  store i64 %s1164.1, ptr %1131, align 8
  %_0.i3 = getelementptr inbounds nuw i8, ptr %out, i64 16
  store i64 %s1165.0, ptr %_0.i3, align 8
  %1132 = getelementptr inbounds nuw i8, ptr %out, i64 24
  store i64 %s1165.1, ptr %1132, align 8
  %_0.i2 = getelementptr inbounds nuw i8, ptr %out, i64 32
  store i64 %s1166.0, ptr %_0.i2, align 8
  %1133 = getelementptr inbounds nuw i8, ptr %out, i64 40
  store i64 %s1166.1, ptr %1133, align 8
  %_0.i1 = getelementptr inbounds nuw i8, ptr %out, i64 48
  store i64 %s1117.0, ptr %_0.i1, align 8
  %1134 = getelementptr inbounds nuw i8, ptr %out, i64 56
  store i64 %s1117.1, ptr %1134, align 8
  %_0.i = getelementptr inbounds nuw i8, ptr %out, i64 64
  %s1118.1 = extractvalue { i64, i64 } %1084, 1
  %s1118.0 = extractvalue { i64, i64 } %1084, 0
  store i64 %s1118.0, ptr %_0.i, align 8
  %1135 = getelementptr inbounds nuw i8, ptr %out, i64 72
  store i64 %s1118.1, ptr %1135, align 8
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind nonlazybind willreturn memory(argmem: readwrite) uwtable
define void @driven(ptr noundef readonly %raw, ptr noundef readonly %params, ptr noundef readonly captures(none) %bases, ptr noundef writeonly captures(none) initializes((0, 80)) %out) unnamed_addr #1 personality ptr @rust_eh_personality {
start:
  %s0.0 = load i64, ptr %params, align 8, !noundef !3
  %0 = getelementptr inbounds nuw i8, ptr %params, i64 8
  %s0.1 = load i64, ptr %0, align 8, !noundef !3
  %_0.i250 = getelementptr inbounds nuw i8, ptr %params, i64 16
  %s1.0 = load i64, ptr %_0.i250, align 8, !noundef !3
  %1 = getelementptr inbounds nuw i8, ptr %params, i64 24
  %s1.1 = load i64, ptr %1, align 8, !noundef !3
  %_0.i249 = getelementptr inbounds nuw i8, ptr %raw, i64 96
  %s2.0 = load i64, ptr %_0.i249, align 8, !noundef !3
  %2 = getelementptr inbounds nuw i8, ptr %raw, i64 104
  %s2.1 = load i64, ptr %2, align 8, !noundef !3
  %_0.i248 = getelementptr inbounds nuw i8, ptr %raw, i64 112
  %s3.0 = load i64, ptr %_0.i248, align 8, !noundef !3
  %3 = getelementptr inbounds nuw i8, ptr %raw, i64 120
  %s3.1 = load i64, ptr %3, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %4 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s3.0, i64 noundef %s3.1, i64 noundef %s2.0, i64 noundef %s2.1)
  %s4.0 = extractvalue { i64, i64 } %4, 0
  %s4.1 = extractvalue { i64, i64 } %4, 1
  %_0.i247 = getelementptr inbounds nuw i8, ptr %raw, i64 160
  %s5.0 = load i64, ptr %_0.i247, align 8, !noundef !3
  %5 = getelementptr inbounds nuw i8, ptr %raw, i64 168
  %s5.1 = load i64, ptr %5, align 8, !noundef !3
  %_0.i246 = getelementptr inbounds nuw i8, ptr %raw, i64 176
  %s6.0 = load i64, ptr %_0.i246, align 8, !noundef !3
  %6 = getelementptr inbounds nuw i8, ptr %raw, i64 184
  %s6.1 = load i64, ptr %6, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %7 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s6.0, i64 noundef %s6.1, i64 noundef %s5.0, i64 noundef %s5.1)
  %s7.0 = extractvalue { i64, i64 } %7, 0
  %s7.1 = extractvalue { i64, i64 } %7, 1
  %_0.i245 = getelementptr inbounds nuw i8, ptr %params, i64 32
  %s8.0 = load i64, ptr %_0.i245, align 8, !noundef !3
  %8 = getelementptr inbounds nuw i8, ptr %params, i64 40
  %s8.1 = load i64, ptr %8, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %9 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s5.0, i64 noundef %s5.1, i64 noundef %s8.0, i64 noundef %s8.1)
; call <kernels::Fp2>::mul
  %10 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s7.0, i64 noundef %s7.1, i64 noundef %s8.0, i64 noundef %s8.1)
  %s9.1 = extractvalue { i64, i64 } %9, 1
  %s9.0 = extractvalue { i64, i64 } %9, 0
; call <kernels::Fp2>::add
  %11 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s0.0, i64 noundef %s0.1, i64 noundef %s9.0, i64 noundef %s9.1)
  %s10.1 = extractvalue { i64, i64 } %10, 1
  %s10.0 = extractvalue { i64, i64 } %10, 0
  %s11.0 = extractvalue { i64, i64 } %11, 0
  %s11.1 = extractvalue { i64, i64 } %11, 1
; call <kernels::Fp2>::add
  %12 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1.0, i64 noundef %s1.1, i64 noundef %s10.0, i64 noundef %s10.1)
  %s12.0 = extractvalue { i64, i64 } %12, 0
  %s12.1 = extractvalue { i64, i64 } %12, 1
; call <kernels::Fp2>::mul
  %13 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s2.0, i64 noundef %s2.1, i64 noundef %s5.0, i64 noundef %s5.1)
  %s13.0 = extractvalue { i64, i64 } %13, 0
  %s13.1 = extractvalue { i64, i64 } %13, 1
; call <kernels::Fp2>::mul
  %14 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s4.0, i64 noundef %s4.1, i64 noundef %s7.0, i64 noundef %s7.1)
  %s14.0 = extractvalue { i64, i64 } %14, 0
  %s14.1 = extractvalue { i64, i64 } %14, 1
; call <kernels::Fp2>::add
  %15 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s2.0, i64 noundef %s2.1, i64 noundef %s4.0, i64 noundef %s4.1)
; call <kernels::Fp2>::add
  %16 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s5.0, i64 noundef %s5.1, i64 noundef %s7.0, i64 noundef %s7.1)
  %s15.1 = extractvalue { i64, i64 } %15, 1
  %s15.0 = extractvalue { i64, i64 } %15, 0
  %s16.0 = extractvalue { i64, i64 } %16, 0
  %s16.1 = extractvalue { i64, i64 } %16, 1
; call <kernels::Fp2>::mul
  %17 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s15.0, i64 noundef %s15.1, i64 noundef %s16.0, i64 noundef %s16.1)
  %s17.0 = extractvalue { i64, i64 } %17, 0
  %s17.1 = extractvalue { i64, i64 } %17, 1
; call <kernels::Fp2>::sub
  %18 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s17.0, i64 noundef %s17.1, i64 noundef %s13.0, i64 noundef %s13.1)
  %s18.0 = extractvalue { i64, i64 } %18, 0
  %s18.1 = extractvalue { i64, i64 } %18, 1
; call <kernels::Fp2>::sub
  %19 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s18.0, i64 noundef %s18.1, i64 noundef %s14.0, i64 noundef %s14.1)
  %s19.0 = extractvalue { i64, i64 } %19, 0
  %s19.1 = extractvalue { i64, i64 } %19, 1
  %_0.i244 = getelementptr inbounds nuw i8, ptr %params, i64 48
  %s20.0 = load i64, ptr %_0.i244, align 8, !noundef !3
  %20 = getelementptr inbounds nuw i8, ptr %params, i64 56
  %s20.1 = load i64, ptr %20, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %21 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s13.0, i64 noundef %s13.1, i64 noundef %s20.0, i64 noundef %s20.1)
  %s21.0 = extractvalue { i64, i64 } %21, 0
  %s21.1 = extractvalue { i64, i64 } %21, 1
; call <kernels::Fp2>::mul
  %22 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s19.0, i64 noundef %s19.1, i64 noundef %s20.0, i64 noundef %s20.1)
  %s22.0 = extractvalue { i64, i64 } %22, 0
  %s22.1 = extractvalue { i64, i64 } %22, 1
; call <kernels::Fp2>::mul
  %23 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s14.0, i64 noundef %s14.1, i64 noundef %s20.0, i64 noundef %s20.1)
  %s23.0 = extractvalue { i64, i64 } %23, 0
  %s23.1 = extractvalue { i64, i64 } %23, 1
; call <kernels::Fp2>::add
  %24 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s11.0, i64 noundef %s11.1, i64 noundef %s21.0, i64 noundef %s21.1)
  %s24.0 = extractvalue { i64, i64 } %24, 0
  %s24.1 = extractvalue { i64, i64 } %24, 1
; call <kernels::Fp2>::add
  %25 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s12.0, i64 noundef %s12.1, i64 noundef %s22.0, i64 noundef %s22.1)
  %s25.0 = extractvalue { i64, i64 } %25, 0
  %s25.1 = extractvalue { i64, i64 } %25, 1
  %_0.i243 = getelementptr inbounds nuw i8, ptr %raw, i64 1280
  %s26.0 = load i64, ptr %_0.i243, align 8, !noundef !3
  %26 = getelementptr inbounds nuw i8, ptr %raw, i64 1288
  %s26.1 = load i64, ptr %26, align 8, !noundef !3
  %_0.i242 = getelementptr inbounds nuw i8, ptr %raw, i64 1296
  %s27.0 = load i64, ptr %_0.i242, align 8, !noundef !3
  %27 = getelementptr inbounds nuw i8, ptr %raw, i64 1304
  %s27.1 = load i64, ptr %27, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %28 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s27.0, i64 noundef %s27.1, i64 noundef %s26.0, i64 noundef %s26.1)
  %s28.0 = extractvalue { i64, i64 } %28, 0
  %s28.1 = extractvalue { i64, i64 } %28, 1
  %_0.i241 = getelementptr inbounds nuw i8, ptr %params, i64 64
  %s29.0 = load i64, ptr %_0.i241, align 8, !noundef !3
  %29 = getelementptr inbounds nuw i8, ptr %params, i64 72
  %s29.1 = load i64, ptr %29, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %30 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s26.0, i64 noundef %s26.1, i64 noundef %s29.0, i64 noundef %s29.1)
; call <kernels::Fp2>::mul
  %31 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s28.0, i64 noundef %s28.1, i64 noundef %s29.0, i64 noundef %s29.1)
  %s30.1 = extractvalue { i64, i64 } %30, 1
  %s30.0 = extractvalue { i64, i64 } %30, 0
; call <kernels::Fp2>::add
  %32 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s24.0, i64 noundef %s24.1, i64 noundef %s30.0, i64 noundef %s30.1)
  %s31.1 = extractvalue { i64, i64 } %31, 1
  %s31.0 = extractvalue { i64, i64 } %31, 0
  %s32.0 = extractvalue { i64, i64 } %32, 0
  %s32.1 = extractvalue { i64, i64 } %32, 1
; call <kernels::Fp2>::add
  %33 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s25.0, i64 noundef %s25.1, i64 noundef %s31.0, i64 noundef %s31.1)
  %s33.0 = extractvalue { i64, i64 } %33, 0
  %s33.1 = extractvalue { i64, i64 } %33, 1
  %_0.i240 = getelementptr inbounds nuw i8, ptr %raw, i64 256
  %s34.0 = load i64, ptr %_0.i240, align 8, !noundef !3
  %34 = getelementptr inbounds nuw i8, ptr %raw, i64 264
  %s34.1 = load i64, ptr %34, align 8, !noundef !3
  %_0.i239 = getelementptr inbounds nuw i8, ptr %raw, i64 272
  %s35.0 = load i64, ptr %_0.i239, align 8, !noundef !3
  %35 = getelementptr inbounds nuw i8, ptr %raw, i64 280
  %s35.1 = load i64, ptr %35, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %36 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s35.0, i64 noundef %s35.1, i64 noundef %s34.0, i64 noundef %s34.1)
  %s36.0 = extractvalue { i64, i64 } %36, 0
  %s36.1 = extractvalue { i64, i64 } %36, 1
; call <kernels::Fp2>::mul
  %37 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s26.0, i64 noundef %s26.1, i64 noundef %s34.0, i64 noundef %s34.1)
  %s37.0 = extractvalue { i64, i64 } %37, 0
  %s37.1 = extractvalue { i64, i64 } %37, 1
; call <kernels::Fp2>::mul
  %38 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s28.0, i64 noundef %s28.1, i64 noundef %s36.0, i64 noundef %s36.1)
  %s38.0 = extractvalue { i64, i64 } %38, 0
  %s38.1 = extractvalue { i64, i64 } %38, 1
; call <kernels::Fp2>::add
  %39 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s26.0, i64 noundef %s26.1, i64 noundef %s28.0, i64 noundef %s28.1)
; call <kernels::Fp2>::add
  %40 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s34.0, i64 noundef %s34.1, i64 noundef %s36.0, i64 noundef %s36.1)
  %s39.1 = extractvalue { i64, i64 } %39, 1
  %s39.0 = extractvalue { i64, i64 } %39, 0
  %s40.0 = extractvalue { i64, i64 } %40, 0
  %s40.1 = extractvalue { i64, i64 } %40, 1
; call <kernels::Fp2>::mul
  %41 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s39.0, i64 noundef %s39.1, i64 noundef %s40.0, i64 noundef %s40.1)
  %s41.0 = extractvalue { i64, i64 } %41, 0
  %s41.1 = extractvalue { i64, i64 } %41, 1
; call <kernels::Fp2>::sub
  %42 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s41.0, i64 noundef %s41.1, i64 noundef %s37.0, i64 noundef %s37.1)
  %s42.0 = extractvalue { i64, i64 } %42, 0
  %s42.1 = extractvalue { i64, i64 } %42, 1
; call <kernels::Fp2>::sub
  %43 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s42.0, i64 noundef %s42.1, i64 noundef %s38.0, i64 noundef %s38.1)
  %s43.0 = extractvalue { i64, i64 } %43, 0
  %s43.1 = extractvalue { i64, i64 } %43, 1
  %_0.i238 = getelementptr inbounds nuw i8, ptr %params, i64 80
  %s44.0 = load i64, ptr %_0.i238, align 8, !noundef !3
  %44 = getelementptr inbounds nuw i8, ptr %params, i64 88
  %s44.1 = load i64, ptr %44, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %45 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s37.0, i64 noundef %s37.1, i64 noundef %s44.0, i64 noundef %s44.1)
  %s45.0 = extractvalue { i64, i64 } %45, 0
  %s45.1 = extractvalue { i64, i64 } %45, 1
; call <kernels::Fp2>::mul
  %46 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s43.0, i64 noundef %s43.1, i64 noundef %s44.0, i64 noundef %s44.1)
  %s46.0 = extractvalue { i64, i64 } %46, 0
  %s46.1 = extractvalue { i64, i64 } %46, 1
; call <kernels::Fp2>::mul
  %47 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s38.0, i64 noundef %s38.1, i64 noundef %s44.0, i64 noundef %s44.1)
  %s47.0 = extractvalue { i64, i64 } %47, 0
  %s47.1 = extractvalue { i64, i64 } %47, 1
; call <kernels::Fp2>::add
  %48 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s32.0, i64 noundef %s32.1, i64 noundef %s45.0, i64 noundef %s45.1)
  %s48.0 = extractvalue { i64, i64 } %48, 0
  %s48.1 = extractvalue { i64, i64 } %48, 1
; call <kernels::Fp2>::add
  %49 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s33.0, i64 noundef %s33.1, i64 noundef %s46.0, i64 noundef %s46.1)
  %s49.0 = extractvalue { i64, i64 } %49, 0
  %s49.1 = extractvalue { i64, i64 } %49, 1
; call <kernels::Fp2>::add
  %50 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s23.0, i64 noundef %s23.1, i64 noundef %s47.0, i64 noundef %s47.1)
  %s50.0 = extractvalue { i64, i64 } %50, 0
  %s50.1 = extractvalue { i64, i64 } %50, 1
  %_0.i237 = getelementptr inbounds nuw i8, ptr %raw, i64 128
  %s51.0 = load i64, ptr %_0.i237, align 8, !noundef !3
  %51 = getelementptr inbounds nuw i8, ptr %raw, i64 136
  %s51.1 = load i64, ptr %51, align 8, !noundef !3
  %_0.i236 = getelementptr inbounds nuw i8, ptr %raw, i64 144
  %s52.0 = load i64, ptr %_0.i236, align 8, !noundef !3
  %52 = getelementptr inbounds nuw i8, ptr %raw, i64 152
  %s52.1 = load i64, ptr %52, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %53 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s52.0, i64 noundef %s52.1, i64 noundef %s51.0, i64 noundef %s51.1)
  %s53.0 = extractvalue { i64, i64 } %53, 0
  %s53.1 = extractvalue { i64, i64 } %53, 1
  %_0.i235 = getelementptr inbounds nuw i8, ptr %raw, i64 672
  %s54.0 = load i64, ptr %_0.i235, align 8, !noundef !3
  %54 = getelementptr inbounds nuw i8, ptr %raw, i64 680
  %s54.1 = load i64, ptr %54, align 8, !noundef !3
  %_0.i234 = getelementptr inbounds nuw i8, ptr %raw, i64 688
  %s55.0 = load i64, ptr %_0.i234, align 8, !noundef !3
  %55 = getelementptr inbounds nuw i8, ptr %raw, i64 696
  %s55.1 = load i64, ptr %55, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %56 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s55.0, i64 noundef %s55.1, i64 noundef %s54.0, i64 noundef %s54.1)
  %s56.0 = extractvalue { i64, i64 } %56, 0
  %s56.1 = extractvalue { i64, i64 } %56, 1
  %_0.i233 = getelementptr inbounds nuw i8, ptr %params, i64 96
  %s57.0 = load i64, ptr %_0.i233, align 8, !noundef !3
  %57 = getelementptr inbounds nuw i8, ptr %params, i64 104
  %s57.1 = load i64, ptr %57, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %58 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s54.0, i64 noundef %s54.1, i64 noundef %s57.0, i64 noundef %s57.1)
; call <kernels::Fp2>::mul
  %59 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s56.0, i64 noundef %s56.1, i64 noundef %s57.0, i64 noundef %s57.1)
  %s58.1 = extractvalue { i64, i64 } %58, 1
  %s58.0 = extractvalue { i64, i64 } %58, 0
; call <kernels::Fp2>::add
  %60 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s48.0, i64 noundef %s48.1, i64 noundef %s58.0, i64 noundef %s58.1)
  %s59.1 = extractvalue { i64, i64 } %59, 1
  %s59.0 = extractvalue { i64, i64 } %59, 0
  %s60.0 = extractvalue { i64, i64 } %60, 0
  %s60.1 = extractvalue { i64, i64 } %60, 1
; call <kernels::Fp2>::add
  %61 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s49.0, i64 noundef %s49.1, i64 noundef %s59.0, i64 noundef %s59.1)
  %s61.0 = extractvalue { i64, i64 } %61, 0
  %s61.1 = extractvalue { i64, i64 } %61, 1
; call <kernels::Fp2>::mul
  %62 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s51.0, i64 noundef %s51.1, i64 noundef %s54.0, i64 noundef %s54.1)
  %s62.0 = extractvalue { i64, i64 } %62, 0
  %s62.1 = extractvalue { i64, i64 } %62, 1
; call <kernels::Fp2>::mul
  %63 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s53.0, i64 noundef %s53.1, i64 noundef %s56.0, i64 noundef %s56.1)
  %s63.0 = extractvalue { i64, i64 } %63, 0
  %s63.1 = extractvalue { i64, i64 } %63, 1
; call <kernels::Fp2>::add
  %64 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s51.0, i64 noundef %s51.1, i64 noundef %s53.0, i64 noundef %s53.1)
; call <kernels::Fp2>::add
  %65 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s54.0, i64 noundef %s54.1, i64 noundef %s56.0, i64 noundef %s56.1)
  %s64.1 = extractvalue { i64, i64 } %64, 1
  %s64.0 = extractvalue { i64, i64 } %64, 0
  %s65.0 = extractvalue { i64, i64 } %65, 0
  %s65.1 = extractvalue { i64, i64 } %65, 1
; call <kernels::Fp2>::mul
  %66 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s64.0, i64 noundef %s64.1, i64 noundef %s65.0, i64 noundef %s65.1)
  %s66.0 = extractvalue { i64, i64 } %66, 0
  %s66.1 = extractvalue { i64, i64 } %66, 1
; call <kernels::Fp2>::sub
  %67 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s66.0, i64 noundef %s66.1, i64 noundef %s62.0, i64 noundef %s62.1)
  %s67.0 = extractvalue { i64, i64 } %67, 0
  %s67.1 = extractvalue { i64, i64 } %67, 1
; call <kernels::Fp2>::sub
  %68 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s67.0, i64 noundef %s67.1, i64 noundef %s63.0, i64 noundef %s63.1)
  %s68.0 = extractvalue { i64, i64 } %68, 0
  %s68.1 = extractvalue { i64, i64 } %68, 1
  %_0.i232 = getelementptr inbounds nuw i8, ptr %params, i64 112
  %s69.0 = load i64, ptr %_0.i232, align 8, !noundef !3
  %69 = getelementptr inbounds nuw i8, ptr %params, i64 120
  %s69.1 = load i64, ptr %69, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %70 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s62.0, i64 noundef %s62.1, i64 noundef %s69.0, i64 noundef %s69.1)
  %s70.0 = extractvalue { i64, i64 } %70, 0
  %s70.1 = extractvalue { i64, i64 } %70, 1
; call <kernels::Fp2>::mul
  %71 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s68.0, i64 noundef %s68.1, i64 noundef %s69.0, i64 noundef %s69.1)
  %s71.0 = extractvalue { i64, i64 } %71, 0
  %s71.1 = extractvalue { i64, i64 } %71, 1
; call <kernels::Fp2>::mul
  %72 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s63.0, i64 noundef %s63.1, i64 noundef %s69.0, i64 noundef %s69.1)
  %s72.0 = extractvalue { i64, i64 } %72, 0
  %s72.1 = extractvalue { i64, i64 } %72, 1
; call <kernels::Fp2>::add
  %73 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s60.0, i64 noundef %s60.1, i64 noundef %s70.0, i64 noundef %s70.1)
  %s73.0 = extractvalue { i64, i64 } %73, 0
  %s73.1 = extractvalue { i64, i64 } %73, 1
; call <kernels::Fp2>::add
  %74 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s61.0, i64 noundef %s61.1, i64 noundef %s71.0, i64 noundef %s71.1)
  %s74.0 = extractvalue { i64, i64 } %74, 0
  %s74.1 = extractvalue { i64, i64 } %74, 1
; call <kernels::Fp2>::add
  %75 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s50.0, i64 noundef %s50.1, i64 noundef %s72.0, i64 noundef %s72.1)
  %s75.0 = extractvalue { i64, i64 } %75, 0
  %s75.1 = extractvalue { i64, i64 } %75, 1
  %_0.i231 = getelementptr inbounds nuw i8, ptr %raw, i64 1312
  %s76.0 = load i64, ptr %_0.i231, align 8, !noundef !3
  %76 = getelementptr inbounds nuw i8, ptr %raw, i64 1320
  %s76.1 = load i64, ptr %76, align 8, !noundef !3
  %_0.i230 = getelementptr inbounds nuw i8, ptr %raw, i64 1328
  %s77.0 = load i64, ptr %_0.i230, align 8, !noundef !3
  %77 = getelementptr inbounds nuw i8, ptr %raw, i64 1336
  %s77.1 = load i64, ptr %77, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %78 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s77.0, i64 noundef %s77.1, i64 noundef %s76.0, i64 noundef %s76.1)
  %s78.0 = extractvalue { i64, i64 } %78, 0
  %s78.1 = extractvalue { i64, i64 } %78, 1
  %_0.i229 = getelementptr inbounds nuw i8, ptr %params, i64 128
  %s79.0 = load i64, ptr %_0.i229, align 8, !noundef !3
  %79 = getelementptr inbounds nuw i8, ptr %params, i64 136
  %s79.1 = load i64, ptr %79, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %80 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s76.0, i64 noundef %s76.1, i64 noundef %s79.0, i64 noundef %s79.1)
; call <kernels::Fp2>::mul
  %81 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s78.0, i64 noundef %s78.1, i64 noundef %s79.0, i64 noundef %s79.1)
  %s80.1 = extractvalue { i64, i64 } %80, 1
  %s80.0 = extractvalue { i64, i64 } %80, 0
; call <kernels::Fp2>::add
  %82 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s73.0, i64 noundef %s73.1, i64 noundef %s80.0, i64 noundef %s80.1)
  %s81.1 = extractvalue { i64, i64 } %81, 1
  %s81.0 = extractvalue { i64, i64 } %81, 0
  %s82.0 = extractvalue { i64, i64 } %82, 0
  %s82.1 = extractvalue { i64, i64 } %82, 1
; call <kernels::Fp2>::add
  %83 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s74.0, i64 noundef %s74.1, i64 noundef %s81.0, i64 noundef %s81.1)
  %s83.0 = extractvalue { i64, i64 } %83, 0
  %s83.1 = extractvalue { i64, i64 } %83, 1
  %_0.i228 = getelementptr inbounds nuw i8, ptr %raw, i64 768
  %s84.0 = load i64, ptr %_0.i228, align 8, !noundef !3
  %84 = getelementptr inbounds nuw i8, ptr %raw, i64 776
  %s84.1 = load i64, ptr %84, align 8, !noundef !3
  %_0.i227 = getelementptr inbounds nuw i8, ptr %raw, i64 784
  %s85.0 = load i64, ptr %_0.i227, align 8, !noundef !3
  %85 = getelementptr inbounds nuw i8, ptr %raw, i64 792
  %s85.1 = load i64, ptr %85, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %86 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s85.0, i64 noundef %s85.1, i64 noundef %s84.0, i64 noundef %s84.1)
  %s86.0 = extractvalue { i64, i64 } %86, 0
  %s86.1 = extractvalue { i64, i64 } %86, 1
; call <kernels::Fp2>::mul
  %87 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s76.0, i64 noundef %s76.1, i64 noundef %s84.0, i64 noundef %s84.1)
  %s87.0 = extractvalue { i64, i64 } %87, 0
  %s87.1 = extractvalue { i64, i64 } %87, 1
; call <kernels::Fp2>::mul
  %88 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s78.0, i64 noundef %s78.1, i64 noundef %s86.0, i64 noundef %s86.1)
  %s88.0 = extractvalue { i64, i64 } %88, 0
  %s88.1 = extractvalue { i64, i64 } %88, 1
; call <kernels::Fp2>::add
  %89 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s76.0, i64 noundef %s76.1, i64 noundef %s78.0, i64 noundef %s78.1)
; call <kernels::Fp2>::add
  %90 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s84.0, i64 noundef %s84.1, i64 noundef %s86.0, i64 noundef %s86.1)
  %s89.1 = extractvalue { i64, i64 } %89, 1
  %s89.0 = extractvalue { i64, i64 } %89, 0
  %s90.0 = extractvalue { i64, i64 } %90, 0
  %s90.1 = extractvalue { i64, i64 } %90, 1
; call <kernels::Fp2>::mul
  %91 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s89.0, i64 noundef %s89.1, i64 noundef %s90.0, i64 noundef %s90.1)
  %s91.0 = extractvalue { i64, i64 } %91, 0
  %s91.1 = extractvalue { i64, i64 } %91, 1
; call <kernels::Fp2>::sub
  %92 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s91.0, i64 noundef %s91.1, i64 noundef %s87.0, i64 noundef %s87.1)
  %s92.0 = extractvalue { i64, i64 } %92, 0
  %s92.1 = extractvalue { i64, i64 } %92, 1
; call <kernels::Fp2>::sub
  %93 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s92.0, i64 noundef %s92.1, i64 noundef %s88.0, i64 noundef %s88.1)
  %s93.0 = extractvalue { i64, i64 } %93, 0
  %s93.1 = extractvalue { i64, i64 } %93, 1
  %_0.i226 = getelementptr inbounds nuw i8, ptr %params, i64 144
  %s94.0 = load i64, ptr %_0.i226, align 8, !noundef !3
  %94 = getelementptr inbounds nuw i8, ptr %params, i64 152
  %s94.1 = load i64, ptr %94, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %95 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s87.0, i64 noundef %s87.1, i64 noundef %s94.0, i64 noundef %s94.1)
  %s95.0 = extractvalue { i64, i64 } %95, 0
  %s95.1 = extractvalue { i64, i64 } %95, 1
; call <kernels::Fp2>::mul
  %96 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s93.0, i64 noundef %s93.1, i64 noundef %s94.0, i64 noundef %s94.1)
  %s96.0 = extractvalue { i64, i64 } %96, 0
  %s96.1 = extractvalue { i64, i64 } %96, 1
; call <kernels::Fp2>::mul
  %97 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s88.0, i64 noundef %s88.1, i64 noundef %s94.0, i64 noundef %s94.1)
  %s97.0 = extractvalue { i64, i64 } %97, 0
  %s97.1 = extractvalue { i64, i64 } %97, 1
; call <kernels::Fp2>::add
  %98 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s82.0, i64 noundef %s82.1, i64 noundef %s95.0, i64 noundef %s95.1)
  %s98.0 = extractvalue { i64, i64 } %98, 0
  %s98.1 = extractvalue { i64, i64 } %98, 1
; call <kernels::Fp2>::add
  %99 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s83.0, i64 noundef %s83.1, i64 noundef %s96.0, i64 noundef %s96.1)
  %s99.0 = extractvalue { i64, i64 } %99, 0
  %s99.1 = extractvalue { i64, i64 } %99, 1
; call <kernels::Fp2>::add
  %100 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s75.0, i64 noundef %s75.1, i64 noundef %s97.0, i64 noundef %s97.1)
  %s100.0 = extractvalue { i64, i64 } %100, 0
  %s100.1 = extractvalue { i64, i64 } %100, 1
  %_0.i225 = getelementptr inbounds nuw i8, ptr %params, i64 160
  %s101.0 = load i64, ptr %_0.i225, align 8, !noundef !3
  %101 = getelementptr inbounds nuw i8, ptr %params, i64 168
  %s101.1 = load i64, ptr %101, align 8, !noundef !3
  %_0.i224 = getelementptr inbounds nuw i8, ptr %params, i64 176
  %s102.0 = load i64, ptr %_0.i224, align 8, !noundef !3
  %102 = getelementptr inbounds nuw i8, ptr %params, i64 184
  %s102.1 = load i64, ptr %102, align 8, !noundef !3
  %_0.i223 = getelementptr inbounds nuw i8, ptr %raw, i64 192
  %s103.0 = load i64, ptr %_0.i223, align 8, !noundef !3
  %103 = getelementptr inbounds nuw i8, ptr %raw, i64 200
  %s103.1 = load i64, ptr %103, align 8, !noundef !3
  %_0.i222 = getelementptr inbounds nuw i8, ptr %raw, i64 208
  %s104.0 = load i64, ptr %_0.i222, align 8, !noundef !3
  %104 = getelementptr inbounds nuw i8, ptr %raw, i64 216
  %s104.1 = load i64, ptr %104, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %105 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s104.0, i64 noundef %s104.1, i64 noundef %s103.0, i64 noundef %s103.1)
  %s105.0 = extractvalue { i64, i64 } %105, 0
  %s105.1 = extractvalue { i64, i64 } %105, 1
  %_0.i221 = getelementptr inbounds nuw i8, ptr %params, i64 192
  %s106.0 = load i64, ptr %_0.i221, align 8, !noundef !3
  %106 = getelementptr inbounds nuw i8, ptr %params, i64 200
  %s106.1 = load i64, ptr %106, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %107 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s103.0, i64 noundef %s103.1, i64 noundef %s106.0, i64 noundef %s106.1)
; call <kernels::Fp2>::mul
  %108 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s105.0, i64 noundef %s105.1, i64 noundef %s106.0, i64 noundef %s106.1)
  %s107.1 = extractvalue { i64, i64 } %107, 1
  %s107.0 = extractvalue { i64, i64 } %107, 0
; call <kernels::Fp2>::add
  %109 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s98.0, i64 noundef %s98.1, i64 noundef %s107.0, i64 noundef %s107.1)
  %s108.1 = extractvalue { i64, i64 } %108, 1
  %s108.0 = extractvalue { i64, i64 } %108, 0
  %s109.0 = extractvalue { i64, i64 } %109, 0
  %s109.1 = extractvalue { i64, i64 } %109, 1
; call <kernels::Fp2>::add
  %110 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s99.0, i64 noundef %s99.1, i64 noundef %s108.0, i64 noundef %s108.1)
  %s110.0 = extractvalue { i64, i64 } %110, 0
  %s110.1 = extractvalue { i64, i64 } %110, 1
  %s111 = load i64, ptr %bases, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %111 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s103.0, i64 noundef %s103.1, i64 noundef %s111)
; call <kernels::Fp2>::mul_base
  %112 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s105.0, i64 noundef %s105.1, i64 noundef %s111)
  %s112.1 = extractvalue { i64, i64 } %111, 1
  %s112.0 = extractvalue { i64, i64 } %111, 0
  %s113.0 = extractvalue { i64, i64 } %112, 0
  %s113.1 = extractvalue { i64, i64 } %112, 1
; call <kernels::Fp2>::sub
  %113 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s102.0, i64 noundef %s102.1, i64 noundef %s112.0, i64 noundef %s112.1)
  %s114.0 = extractvalue { i64, i64 } %113, 0
  %s114.1 = extractvalue { i64, i64 } %113, 1
  %_0.i220 = getelementptr inbounds nuw i8, ptr %params, i64 208
  %s115.0 = load i64, ptr %_0.i220, align 8, !noundef !3
  %114 = getelementptr inbounds nuw i8, ptr %params, i64 216
  %s115.1 = load i64, ptr %114, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %115 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s115.0, i64 noundef %s115.1, i64 noundef %s113.0, i64 noundef %s113.1)
  %s116.0 = extractvalue { i64, i64 } %115, 0
  %s116.1 = extractvalue { i64, i64 } %115, 1
  %_0.i219 = getelementptr inbounds nuw i8, ptr %params, i64 224
  %s117.0 = load i64, ptr %_0.i219, align 8, !noundef !3
  %116 = getelementptr inbounds nuw i8, ptr %params, i64 232
  %s117.1 = load i64, ptr %116, align 8, !noundef !3
  %_0.i218 = getelementptr inbounds nuw i8, ptr %raw, i64 224
  %s118.0 = load i64, ptr %_0.i218, align 8, !noundef !3
  %117 = getelementptr inbounds nuw i8, ptr %raw, i64 232
  %s118.1 = load i64, ptr %117, align 8, !noundef !3
  %_0.i217 = getelementptr inbounds nuw i8, ptr %raw, i64 240
  %s119.0 = load i64, ptr %_0.i217, align 8, !noundef !3
  %118 = getelementptr inbounds nuw i8, ptr %raw, i64 248
  %s119.1 = load i64, ptr %118, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %119 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s119.0, i64 noundef %s119.1, i64 noundef %s118.0, i64 noundef %s118.1)
  %s120.0 = extractvalue { i64, i64 } %119, 0
  %s120.1 = extractvalue { i64, i64 } %119, 1
  %_0.i216 = getelementptr inbounds nuw i8, ptr %params, i64 240
  %s121.0 = load i64, ptr %_0.i216, align 8, !noundef !3
  %120 = getelementptr inbounds nuw i8, ptr %params, i64 248
  %s121.1 = load i64, ptr %120, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %121 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s118.0, i64 noundef %s118.1, i64 noundef %s121.0, i64 noundef %s121.1)
; call <kernels::Fp2>::mul
  %122 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s120.0, i64 noundef %s120.1, i64 noundef %s121.0, i64 noundef %s121.1)
  %s122.1 = extractvalue { i64, i64 } %121, 1
  %s122.0 = extractvalue { i64, i64 } %121, 0
; call <kernels::Fp2>::add
  %123 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s109.0, i64 noundef %s109.1, i64 noundef %s122.0, i64 noundef %s122.1)
  %s123.1 = extractvalue { i64, i64 } %122, 1
  %s123.0 = extractvalue { i64, i64 } %122, 0
  %s124.0 = extractvalue { i64, i64 } %123, 0
  %s124.1 = extractvalue { i64, i64 } %123, 1
; call <kernels::Fp2>::add
  %124 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s110.0, i64 noundef %s110.1, i64 noundef %s123.0, i64 noundef %s123.1)
  %s125.0 = extractvalue { i64, i64 } %124, 0
  %s125.1 = extractvalue { i64, i64 } %124, 1
  %_0.i286 = getelementptr inbounds nuw i8, ptr %bases, i64 8
  %s126 = load i64, ptr %_0.i286, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %125 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s118.0, i64 noundef %s118.1, i64 noundef %s126)
; call <kernels::Fp2>::mul_base
  %126 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s120.0, i64 noundef %s120.1, i64 noundef %s126)
  %s127.1 = extractvalue { i64, i64 } %125, 1
  %s127.0 = extractvalue { i64, i64 } %125, 0
  %s128.0 = extractvalue { i64, i64 } %126, 0
  %s128.1 = extractvalue { i64, i64 } %126, 1
; call <kernels::Fp2>::sub
  %127 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s117.0, i64 noundef %s117.1, i64 noundef %s127.0, i64 noundef %s127.1)
  %s129.0 = extractvalue { i64, i64 } %127, 0
  %s129.1 = extractvalue { i64, i64 } %127, 1
  %_0.i215 = getelementptr inbounds nuw i8, ptr %params, i64 256
  %s130.0 = load i64, ptr %_0.i215, align 8, !noundef !3
  %128 = getelementptr inbounds nuw i8, ptr %params, i64 264
  %s130.1 = load i64, ptr %128, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %129 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s130.0, i64 noundef %s130.1, i64 noundef %s128.0, i64 noundef %s128.1)
  %s131.0 = extractvalue { i64, i64 } %129, 0
  %s131.1 = extractvalue { i64, i64 } %129, 1
  %_0.i214 = getelementptr inbounds nuw i8, ptr %raw, i64 1344
  %s132.0 = load i64, ptr %_0.i214, align 8, !noundef !3
  %130 = getelementptr inbounds nuw i8, ptr %raw, i64 1352
  %s132.1 = load i64, ptr %130, align 8, !noundef !3
  %_0.i213 = getelementptr inbounds nuw i8, ptr %raw, i64 1360
  %s133.0 = load i64, ptr %_0.i213, align 8, !noundef !3
  %131 = getelementptr inbounds nuw i8, ptr %raw, i64 1368
  %s133.1 = load i64, ptr %131, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %132 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s133.0, i64 noundef %s133.1, i64 noundef %s132.0, i64 noundef %s132.1)
  %s134.0 = extractvalue { i64, i64 } %132, 0
  %s134.1 = extractvalue { i64, i64 } %132, 1
; call <kernels::Fp2>::mul
  %133 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s132.0, i64 noundef %s132.1, i64 noundef %s114.0, i64 noundef %s114.1)
  %s135.0 = extractvalue { i64, i64 } %133, 0
  %s135.1 = extractvalue { i64, i64 } %133, 1
; call <kernels::Fp2>::mul
  %134 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s134.0, i64 noundef %s134.1, i64 noundef %s116.0, i64 noundef %s116.1)
  %s136.0 = extractvalue { i64, i64 } %134, 0
  %s136.1 = extractvalue { i64, i64 } %134, 1
; call <kernels::Fp2>::add
  %135 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s132.0, i64 noundef %s132.1, i64 noundef %s134.0, i64 noundef %s134.1)
; call <kernels::Fp2>::add
  %136 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s114.0, i64 noundef %s114.1, i64 noundef %s116.0, i64 noundef %s116.1)
  %s137.1 = extractvalue { i64, i64 } %135, 1
  %s137.0 = extractvalue { i64, i64 } %135, 0
  %s138.0 = extractvalue { i64, i64 } %136, 0
  %s138.1 = extractvalue { i64, i64 } %136, 1
; call <kernels::Fp2>::mul
  %137 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s137.0, i64 noundef %s137.1, i64 noundef %s138.0, i64 noundef %s138.1)
  %s139.0 = extractvalue { i64, i64 } %137, 0
  %s139.1 = extractvalue { i64, i64 } %137, 1
; call <kernels::Fp2>::sub
  %138 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s139.0, i64 noundef %s139.1, i64 noundef %s135.0, i64 noundef %s135.1)
  %s140.0 = extractvalue { i64, i64 } %138, 0
  %s140.1 = extractvalue { i64, i64 } %138, 1
; call <kernels::Fp2>::sub
  %139 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s140.0, i64 noundef %s140.1, i64 noundef %s136.0, i64 noundef %s136.1)
  %s141.0 = extractvalue { i64, i64 } %139, 0
  %s141.1 = extractvalue { i64, i64 } %139, 1
; call <kernels::Fp2>::mul
  %140 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s135.0, i64 noundef %s135.1, i64 noundef %s129.0, i64 noundef %s129.1)
  %s142.0 = extractvalue { i64, i64 } %140, 0
  %s142.1 = extractvalue { i64, i64 } %140, 1
; call <kernels::Fp2>::mul
  %141 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s135.0, i64 noundef %s135.1, i64 noundef %s131.0, i64 noundef %s131.1)
; call <kernels::Fp2>::mul
  %142 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s141.0, i64 noundef %s141.1, i64 noundef %s129.0, i64 noundef %s129.1)
  %s143.1 = extractvalue { i64, i64 } %141, 1
  %s143.0 = extractvalue { i64, i64 } %141, 0
  %s144.0 = extractvalue { i64, i64 } %142, 0
  %s144.1 = extractvalue { i64, i64 } %142, 1
; call <kernels::Fp2>::add
  %143 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s143.0, i64 noundef %s143.1, i64 noundef %s144.0, i64 noundef %s144.1)
  %s145.0 = extractvalue { i64, i64 } %143, 0
  %s145.1 = extractvalue { i64, i64 } %143, 1
; call <kernels::Fp2>::mul
  %144 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s141.0, i64 noundef %s141.1, i64 noundef %s131.0, i64 noundef %s131.1)
; call <kernels::Fp2>::mul
  %145 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s136.0, i64 noundef %s136.1, i64 noundef %s129.0, i64 noundef %s129.1)
  %s146.1 = extractvalue { i64, i64 } %144, 1
  %s146.0 = extractvalue { i64, i64 } %144, 0
  %s147.0 = extractvalue { i64, i64 } %145, 0
  %s147.1 = extractvalue { i64, i64 } %145, 1
; call <kernels::Fp2>::add
  %146 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s146.0, i64 noundef %s146.1, i64 noundef %s147.0, i64 noundef %s147.1)
  %s148.0 = extractvalue { i64, i64 } %146, 0
  %s148.1 = extractvalue { i64, i64 } %146, 1
; call <kernels::Fp2>::mul
  %147 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s136.0, i64 noundef %s136.1, i64 noundef %s131.0, i64 noundef %s131.1)
  %s149.0 = extractvalue { i64, i64 } %147, 0
  %s149.1 = extractvalue { i64, i64 } %147, 1
; call <kernels::Fp2>::add
  %148 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s114.0, i64 noundef %s114.1, i64 noundef %s129.0, i64 noundef %s129.1)
; call <kernels::Fp2>::add
  %149 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s116.0, i64 noundef %s116.1, i64 noundef %s131.0, i64 noundef %s131.1)
  %s150.1 = extractvalue { i64, i64 } %148, 1
  %s150.0 = extractvalue { i64, i64 } %148, 0
; call <kernels::Fp2>::sub
  %150 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s142.0, i64 noundef %s142.1, i64 noundef %s150.0, i64 noundef %s150.1)
  %s151.1 = extractvalue { i64, i64 } %149, 1
  %s151.0 = extractvalue { i64, i64 } %149, 0
  %s152.0 = extractvalue { i64, i64 } %150, 0
  %s152.1 = extractvalue { i64, i64 } %150, 1
; call <kernels::Fp2>::sub
  %151 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s145.0, i64 noundef %s145.1, i64 noundef %s151.0, i64 noundef %s151.1)
  %s153.0 = extractvalue { i64, i64 } %151, 0
  %s153.1 = extractvalue { i64, i64 } %151, 1
  %_0.i212 = getelementptr inbounds nuw i8, ptr %params, i64 272
  %s154.0 = load i64, ptr %_0.i212, align 8, !noundef !3
  %152 = getelementptr inbounds nuw i8, ptr %params, i64 280
  %s154.1 = load i64, ptr %152, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %153 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s152.0, i64 noundef %s152.1, i64 noundef %s154.0, i64 noundef %s154.1)
  %s155.0 = extractvalue { i64, i64 } %153, 0
  %s155.1 = extractvalue { i64, i64 } %153, 1
; call <kernels::Fp2>::mul
  %154 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s153.0, i64 noundef %s153.1, i64 noundef %s154.0, i64 noundef %s154.1)
  %s156.0 = extractvalue { i64, i64 } %154, 0
  %s156.1 = extractvalue { i64, i64 } %154, 1
; call <kernels::Fp2>::mul
  %155 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s148.0, i64 noundef %s148.1, i64 noundef %s154.0, i64 noundef %s154.1)
  %s157.0 = extractvalue { i64, i64 } %155, 0
  %s157.1 = extractvalue { i64, i64 } %155, 1
; call <kernels::Fp2>::mul
  %156 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s149.0, i64 noundef %s149.1, i64 noundef %s154.0, i64 noundef %s154.1)
  %s158.0 = extractvalue { i64, i64 } %156, 0
  %s158.1 = extractvalue { i64, i64 } %156, 1
; call <kernels::Fp2>::add
  %157 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s101.0, i64 noundef %s101.1, i64 noundef %s155.0, i64 noundef %s155.1)
  %s159.0 = extractvalue { i64, i64 } %157, 0
  %s159.1 = extractvalue { i64, i64 } %157, 1
  %_0.i211 = getelementptr inbounds nuw i8, ptr %params, i64 288
  %s160.0 = load i64, ptr %_0.i211, align 8, !noundef !3
  %158 = getelementptr inbounds nuw i8, ptr %params, i64 296
  %s160.1 = load i64, ptr %158, align 8, !noundef !3
  %_0.i285 = getelementptr inbounds nuw i8, ptr %bases, i64 16
  %s161 = load i64, ptr %_0.i285, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %159 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s34.0, i64 noundef %s34.1, i64 noundef %s161)
; call <kernels::Fp2>::mul_base
  %160 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s36.0, i64 noundef %s36.1, i64 noundef %s161)
  %s162.1 = extractvalue { i64, i64 } %159, 1
  %s162.0 = extractvalue { i64, i64 } %159, 0
  %s163.0 = extractvalue { i64, i64 } %160, 0
  %s163.1 = extractvalue { i64, i64 } %160, 1
; call <kernels::Fp2>::sub
  %161 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s160.0, i64 noundef %s160.1, i64 noundef %s162.0, i64 noundef %s162.1)
  %s164.0 = extractvalue { i64, i64 } %161, 0
  %s164.1 = extractvalue { i64, i64 } %161, 1
  %_0.i210 = getelementptr inbounds nuw i8, ptr %params, i64 304
  %s165.0 = load i64, ptr %_0.i210, align 8, !noundef !3
  %162 = getelementptr inbounds nuw i8, ptr %params, i64 312
  %s165.1 = load i64, ptr %162, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %163 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s165.0, i64 noundef %s165.1, i64 noundef %s163.0, i64 noundef %s163.1)
  %s166.0 = extractvalue { i64, i64 } %163, 0
  %s166.1 = extractvalue { i64, i64 } %163, 1
  %_0.i209 = getelementptr inbounds nuw i8, ptr %params, i64 320
  %s167.0 = load i64, ptr %_0.i209, align 8, !noundef !3
  %164 = getelementptr inbounds nuw i8, ptr %params, i64 328
  %s167.1 = load i64, ptr %164, align 8, !noundef !3
  %_0.i284 = getelementptr inbounds nuw i8, ptr %bases, i64 24
  %s168 = load i64, ptr %_0.i284, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %165 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s34.0, i64 noundef %s34.1, i64 noundef %s168)
; call <kernels::Fp2>::mul_base
  %166 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s36.0, i64 noundef %s36.1, i64 noundef %s168)
  %s169.1 = extractvalue { i64, i64 } %165, 1
  %s169.0 = extractvalue { i64, i64 } %165, 0
  %s170.0 = extractvalue { i64, i64 } %166, 0
  %s170.1 = extractvalue { i64, i64 } %166, 1
; call <kernels::Fp2>::sub
  %167 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s167.0, i64 noundef %s167.1, i64 noundef %s169.0, i64 noundef %s169.1)
  %s171.0 = extractvalue { i64, i64 } %167, 0
  %s171.1 = extractvalue { i64, i64 } %167, 1
  %_0.i208 = getelementptr inbounds nuw i8, ptr %params, i64 336
  %s172.0 = load i64, ptr %_0.i208, align 8, !noundef !3
  %168 = getelementptr inbounds nuw i8, ptr %params, i64 344
  %s172.1 = load i64, ptr %168, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %169 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s172.0, i64 noundef %s172.1, i64 noundef %s170.0, i64 noundef %s170.1)
  %s173.0 = extractvalue { i64, i64 } %169, 0
  %s173.1 = extractvalue { i64, i64 } %169, 1
  %_0.i207 = getelementptr inbounds nuw i8, ptr %raw, i64 1376
  %s174.0 = load i64, ptr %_0.i207, align 8, !noundef !3
  %170 = getelementptr inbounds nuw i8, ptr %raw, i64 1384
  %s174.1 = load i64, ptr %170, align 8, !noundef !3
  %_0.i206 = getelementptr inbounds nuw i8, ptr %raw, i64 1392
  %s175.0 = load i64, ptr %_0.i206, align 8, !noundef !3
  %171 = getelementptr inbounds nuw i8, ptr %raw, i64 1400
  %s175.1 = load i64, ptr %171, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %172 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s175.0, i64 noundef %s175.1, i64 noundef %s174.0, i64 noundef %s174.1)
  %s176.0 = extractvalue { i64, i64 } %172, 0
  %s176.1 = extractvalue { i64, i64 } %172, 1
; call <kernels::Fp2>::mul
  %173 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s174.0, i64 noundef %s174.1, i64 noundef %s164.0, i64 noundef %s164.1)
  %s177.0 = extractvalue { i64, i64 } %173, 0
  %s177.1 = extractvalue { i64, i64 } %173, 1
; call <kernels::Fp2>::mul
  %174 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s176.0, i64 noundef %s176.1, i64 noundef %s166.0, i64 noundef %s166.1)
  %s178.0 = extractvalue { i64, i64 } %174, 0
  %s178.1 = extractvalue { i64, i64 } %174, 1
; call <kernels::Fp2>::add
  %175 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s174.0, i64 noundef %s174.1, i64 noundef %s176.0, i64 noundef %s176.1)
; call <kernels::Fp2>::add
  %176 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s164.0, i64 noundef %s164.1, i64 noundef %s166.0, i64 noundef %s166.1)
  %s179.1 = extractvalue { i64, i64 } %175, 1
  %s179.0 = extractvalue { i64, i64 } %175, 0
  %s180.0 = extractvalue { i64, i64 } %176, 0
  %s180.1 = extractvalue { i64, i64 } %176, 1
; call <kernels::Fp2>::mul
  %177 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s179.0, i64 noundef %s179.1, i64 noundef %s180.0, i64 noundef %s180.1)
  %s181.0 = extractvalue { i64, i64 } %177, 0
  %s181.1 = extractvalue { i64, i64 } %177, 1
; call <kernels::Fp2>::sub
  %178 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s181.0, i64 noundef %s181.1, i64 noundef %s177.0, i64 noundef %s177.1)
  %s182.0 = extractvalue { i64, i64 } %178, 0
  %s182.1 = extractvalue { i64, i64 } %178, 1
; call <kernels::Fp2>::sub
  %179 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s182.0, i64 noundef %s182.1, i64 noundef %s178.0, i64 noundef %s178.1)
  %s183.0 = extractvalue { i64, i64 } %179, 0
  %s183.1 = extractvalue { i64, i64 } %179, 1
; call <kernels::Fp2>::mul
  %180 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s177.0, i64 noundef %s177.1, i64 noundef %s171.0, i64 noundef %s171.1)
  %s184.0 = extractvalue { i64, i64 } %180, 0
  %s184.1 = extractvalue { i64, i64 } %180, 1
; call <kernels::Fp2>::mul
  %181 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s177.0, i64 noundef %s177.1, i64 noundef %s173.0, i64 noundef %s173.1)
; call <kernels::Fp2>::mul
  %182 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s183.0, i64 noundef %s183.1, i64 noundef %s171.0, i64 noundef %s171.1)
  %s185.1 = extractvalue { i64, i64 } %181, 1
  %s185.0 = extractvalue { i64, i64 } %181, 0
  %s186.0 = extractvalue { i64, i64 } %182, 0
  %s186.1 = extractvalue { i64, i64 } %182, 1
; call <kernels::Fp2>::add
  %183 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s185.0, i64 noundef %s185.1, i64 noundef %s186.0, i64 noundef %s186.1)
  %s187.0 = extractvalue { i64, i64 } %183, 0
  %s187.1 = extractvalue { i64, i64 } %183, 1
; call <kernels::Fp2>::mul
  %184 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s183.0, i64 noundef %s183.1, i64 noundef %s173.0, i64 noundef %s173.1)
; call <kernels::Fp2>::mul
  %185 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s178.0, i64 noundef %s178.1, i64 noundef %s171.0, i64 noundef %s171.1)
  %s188.1 = extractvalue { i64, i64 } %184, 1
  %s188.0 = extractvalue { i64, i64 } %184, 0
  %s189.0 = extractvalue { i64, i64 } %185, 0
  %s189.1 = extractvalue { i64, i64 } %185, 1
; call <kernels::Fp2>::add
  %186 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s188.0, i64 noundef %s188.1, i64 noundef %s189.0, i64 noundef %s189.1)
  %s190.0 = extractvalue { i64, i64 } %186, 0
  %s190.1 = extractvalue { i64, i64 } %186, 1
; call <kernels::Fp2>::mul
  %187 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s178.0, i64 noundef %s178.1, i64 noundef %s173.0, i64 noundef %s173.1)
  %s191.0 = extractvalue { i64, i64 } %187, 0
  %s191.1 = extractvalue { i64, i64 } %187, 1
; call <kernels::Fp2>::add
  %188 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s164.0, i64 noundef %s164.1, i64 noundef %s171.0, i64 noundef %s171.1)
; call <kernels::Fp2>::add
  %189 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s166.0, i64 noundef %s166.1, i64 noundef %s173.0, i64 noundef %s173.1)
  %s192.1 = extractvalue { i64, i64 } %188, 1
  %s192.0 = extractvalue { i64, i64 } %188, 0
; call <kernels::Fp2>::sub
  %190 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s184.0, i64 noundef %s184.1, i64 noundef %s192.0, i64 noundef %s192.1)
  %s193.1 = extractvalue { i64, i64 } %189, 1
  %s193.0 = extractvalue { i64, i64 } %189, 0
  %s194.0 = extractvalue { i64, i64 } %190, 0
  %s194.1 = extractvalue { i64, i64 } %190, 1
; call <kernels::Fp2>::sub
  %191 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s187.0, i64 noundef %s187.1, i64 noundef %s193.0, i64 noundef %s193.1)
  %s195.0 = extractvalue { i64, i64 } %191, 0
  %s195.1 = extractvalue { i64, i64 } %191, 1
  %_0.i205 = getelementptr inbounds nuw i8, ptr %params, i64 352
  %s196.0 = load i64, ptr %_0.i205, align 8, !noundef !3
  %192 = getelementptr inbounds nuw i8, ptr %params, i64 360
  %s196.1 = load i64, ptr %192, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %193 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s194.0, i64 noundef %s194.1, i64 noundef %s196.0, i64 noundef %s196.1)
  %s197.0 = extractvalue { i64, i64 } %193, 0
  %s197.1 = extractvalue { i64, i64 } %193, 1
; call <kernels::Fp2>::mul
  %194 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s195.0, i64 noundef %s195.1, i64 noundef %s196.0, i64 noundef %s196.1)
  %s198.0 = extractvalue { i64, i64 } %194, 0
  %s198.1 = extractvalue { i64, i64 } %194, 1
; call <kernels::Fp2>::mul
  %195 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s190.0, i64 noundef %s190.1, i64 noundef %s196.0, i64 noundef %s196.1)
  %s199.0 = extractvalue { i64, i64 } %195, 0
  %s199.1 = extractvalue { i64, i64 } %195, 1
; call <kernels::Fp2>::mul
  %196 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s191.0, i64 noundef %s191.1, i64 noundef %s196.0, i64 noundef %s196.1)
  %s200.0 = extractvalue { i64, i64 } %196, 0
  %s200.1 = extractvalue { i64, i64 } %196, 1
; call <kernels::Fp2>::add
  %197 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s159.0, i64 noundef %s159.1, i64 noundef %s197.0, i64 noundef %s197.1)
  %s201.0 = extractvalue { i64, i64 } %197, 0
  %s201.1 = extractvalue { i64, i64 } %197, 1
; call <kernels::Fp2>::add
  %198 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s156.0, i64 noundef %s156.1, i64 noundef %s198.0, i64 noundef %s198.1)
  %s202.0 = extractvalue { i64, i64 } %198, 0
  %s202.1 = extractvalue { i64, i64 } %198, 1
; call <kernels::Fp2>::add
  %199 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s157.0, i64 noundef %s157.1, i64 noundef %s199.0, i64 noundef %s199.1)
  %s203.0 = extractvalue { i64, i64 } %199, 0
  %s203.1 = extractvalue { i64, i64 } %199, 1
; call <kernels::Fp2>::add
  %200 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s158.0, i64 noundef %s158.1, i64 noundef %s200.0, i64 noundef %s200.1)
  %s204.0 = extractvalue { i64, i64 } %200, 0
  %s204.1 = extractvalue { i64, i64 } %200, 1
  %_0.i204 = getelementptr inbounds nuw i8, ptr %params, i64 368
  %s205.0 = load i64, ptr %_0.i204, align 8, !noundef !3
  %201 = getelementptr inbounds nuw i8, ptr %params, i64 376
  %s205.1 = load i64, ptr %201, align 8, !noundef !3
  %_0.i203 = getelementptr inbounds nuw i8, ptr %raw, i64 288
  %s206.0 = load i64, ptr %_0.i203, align 8, !noundef !3
  %202 = getelementptr inbounds nuw i8, ptr %raw, i64 296
  %s206.1 = load i64, ptr %202, align 8, !noundef !3
  %_0.i202 = getelementptr inbounds nuw i8, ptr %raw, i64 304
  %s207.0 = load i64, ptr %_0.i202, align 8, !noundef !3
  %203 = getelementptr inbounds nuw i8, ptr %raw, i64 312
  %s207.1 = load i64, ptr %203, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %204 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s207.0, i64 noundef %s207.1, i64 noundef %s206.0, i64 noundef %s206.1)
  %s208.0 = extractvalue { i64, i64 } %204, 0
  %s208.1 = extractvalue { i64, i64 } %204, 1
  %_0.i201 = getelementptr inbounds nuw i8, ptr %params, i64 384
  %s209.0 = load i64, ptr %_0.i201, align 8, !noundef !3
  %205 = getelementptr inbounds nuw i8, ptr %params, i64 392
  %s209.1 = load i64, ptr %205, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %206 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s206.0, i64 noundef %s206.1, i64 noundef %s209.0, i64 noundef %s209.1)
; call <kernels::Fp2>::mul
  %207 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s208.0, i64 noundef %s208.1, i64 noundef %s209.0, i64 noundef %s209.1)
  %s210.1 = extractvalue { i64, i64 } %206, 1
  %s210.0 = extractvalue { i64, i64 } %206, 0
; call <kernels::Fp2>::add
  %208 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s124.0, i64 noundef %s124.1, i64 noundef %s210.0, i64 noundef %s210.1)
  %s211.1 = extractvalue { i64, i64 } %207, 1
  %s211.0 = extractvalue { i64, i64 } %207, 0
  %s212.0 = extractvalue { i64, i64 } %208, 0
  %s212.1 = extractvalue { i64, i64 } %208, 1
; call <kernels::Fp2>::add
  %209 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s125.0, i64 noundef %s125.1, i64 noundef %s211.0, i64 noundef %s211.1)
  %s213.0 = extractvalue { i64, i64 } %209, 0
  %s213.1 = extractvalue { i64, i64 } %209, 1
  %_0.i283 = getelementptr inbounds nuw i8, ptr %bases, i64 32
  %s214 = load i64, ptr %_0.i283, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %210 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s206.0, i64 noundef %s206.1, i64 noundef %s214)
; call <kernels::Fp2>::mul_base
  %211 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s208.0, i64 noundef %s208.1, i64 noundef %s214)
  %s215.1 = extractvalue { i64, i64 } %210, 1
  %s215.0 = extractvalue { i64, i64 } %210, 0
  %s216.0 = extractvalue { i64, i64 } %211, 0
  %s216.1 = extractvalue { i64, i64 } %211, 1
; call <kernels::Fp2>::sub
  %212 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s205.0, i64 noundef %s205.1, i64 noundef %s215.0, i64 noundef %s215.1)
  %s217.0 = extractvalue { i64, i64 } %212, 0
  %s217.1 = extractvalue { i64, i64 } %212, 1
  %_0.i200 = getelementptr inbounds nuw i8, ptr %params, i64 400
  %s218.0 = load i64, ptr %_0.i200, align 8, !noundef !3
  %213 = getelementptr inbounds nuw i8, ptr %params, i64 408
  %s218.1 = load i64, ptr %213, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %214 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s218.0, i64 noundef %s218.1, i64 noundef %s216.0, i64 noundef %s216.1)
  %s219.0 = extractvalue { i64, i64 } %214, 0
  %s219.1 = extractvalue { i64, i64 } %214, 1
  %_0.i199 = getelementptr inbounds nuw i8, ptr %params, i64 416
  %s220.0 = load i64, ptr %_0.i199, align 8, !noundef !3
  %215 = getelementptr inbounds nuw i8, ptr %params, i64 424
  %s220.1 = load i64, ptr %215, align 8, !noundef !3
  %_0.i198 = getelementptr inbounds nuw i8, ptr %raw, i64 320
  %s221.0 = load i64, ptr %_0.i198, align 8, !noundef !3
  %216 = getelementptr inbounds nuw i8, ptr %raw, i64 328
  %s221.1 = load i64, ptr %216, align 8, !noundef !3
  %_0.i197 = getelementptr inbounds nuw i8, ptr %raw, i64 336
  %s222.0 = load i64, ptr %_0.i197, align 8, !noundef !3
  %217 = getelementptr inbounds nuw i8, ptr %raw, i64 344
  %s222.1 = load i64, ptr %217, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %218 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s222.0, i64 noundef %s222.1, i64 noundef %s221.0, i64 noundef %s221.1)
  %s223.0 = extractvalue { i64, i64 } %218, 0
  %s223.1 = extractvalue { i64, i64 } %218, 1
  %_0.i196 = getelementptr inbounds nuw i8, ptr %params, i64 432
  %s224.0 = load i64, ptr %_0.i196, align 8, !noundef !3
  %219 = getelementptr inbounds nuw i8, ptr %params, i64 440
  %s224.1 = load i64, ptr %219, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %220 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s221.0, i64 noundef %s221.1, i64 noundef %s224.0, i64 noundef %s224.1)
; call <kernels::Fp2>::mul
  %221 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s223.0, i64 noundef %s223.1, i64 noundef %s224.0, i64 noundef %s224.1)
  %s225.1 = extractvalue { i64, i64 } %220, 1
  %s225.0 = extractvalue { i64, i64 } %220, 0
; call <kernels::Fp2>::add
  %222 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s212.0, i64 noundef %s212.1, i64 noundef %s225.0, i64 noundef %s225.1)
  %s226.1 = extractvalue { i64, i64 } %221, 1
  %s226.0 = extractvalue { i64, i64 } %221, 0
  %s227.0 = extractvalue { i64, i64 } %222, 0
  %s227.1 = extractvalue { i64, i64 } %222, 1
; call <kernels::Fp2>::add
  %223 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s213.0, i64 noundef %s213.1, i64 noundef %s226.0, i64 noundef %s226.1)
  %s228.0 = extractvalue { i64, i64 } %223, 0
  %s228.1 = extractvalue { i64, i64 } %223, 1
  %_0.i282 = getelementptr inbounds nuw i8, ptr %bases, i64 40
  %s229 = load i64, ptr %_0.i282, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %224 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s221.0, i64 noundef %s221.1, i64 noundef %s229)
; call <kernels::Fp2>::mul_base
  %225 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s223.0, i64 noundef %s223.1, i64 noundef %s229)
  %s230.1 = extractvalue { i64, i64 } %224, 1
  %s230.0 = extractvalue { i64, i64 } %224, 0
  %s231.0 = extractvalue { i64, i64 } %225, 0
  %s231.1 = extractvalue { i64, i64 } %225, 1
; call <kernels::Fp2>::sub
  %226 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s220.0, i64 noundef %s220.1, i64 noundef %s230.0, i64 noundef %s230.1)
  %s232.0 = extractvalue { i64, i64 } %226, 0
  %s232.1 = extractvalue { i64, i64 } %226, 1
  %_0.i195 = getelementptr inbounds nuw i8, ptr %params, i64 448
  %s233.0 = load i64, ptr %_0.i195, align 8, !noundef !3
  %227 = getelementptr inbounds nuw i8, ptr %params, i64 456
  %s233.1 = load i64, ptr %227, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %228 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s233.0, i64 noundef %s233.1, i64 noundef %s231.0, i64 noundef %s231.1)
  %s234.0 = extractvalue { i64, i64 } %228, 0
  %s234.1 = extractvalue { i64, i64 } %228, 1
  %_0.i194 = getelementptr inbounds nuw i8, ptr %raw, i64 1408
  %s235.0 = load i64, ptr %_0.i194, align 8, !noundef !3
  %229 = getelementptr inbounds nuw i8, ptr %raw, i64 1416
  %s235.1 = load i64, ptr %229, align 8, !noundef !3
  %_0.i193 = getelementptr inbounds nuw i8, ptr %raw, i64 1424
  %s236.0 = load i64, ptr %_0.i193, align 8, !noundef !3
  %230 = getelementptr inbounds nuw i8, ptr %raw, i64 1432
  %s236.1 = load i64, ptr %230, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %231 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s236.0, i64 noundef %s236.1, i64 noundef %s235.0, i64 noundef %s235.1)
  %s237.0 = extractvalue { i64, i64 } %231, 0
  %s237.1 = extractvalue { i64, i64 } %231, 1
; call <kernels::Fp2>::mul
  %232 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s235.0, i64 noundef %s235.1, i64 noundef %s217.0, i64 noundef %s217.1)
  %s238.0 = extractvalue { i64, i64 } %232, 0
  %s238.1 = extractvalue { i64, i64 } %232, 1
; call <kernels::Fp2>::mul
  %233 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s237.0, i64 noundef %s237.1, i64 noundef %s219.0, i64 noundef %s219.1)
  %s239.0 = extractvalue { i64, i64 } %233, 0
  %s239.1 = extractvalue { i64, i64 } %233, 1
; call <kernels::Fp2>::add
  %234 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s235.0, i64 noundef %s235.1, i64 noundef %s237.0, i64 noundef %s237.1)
; call <kernels::Fp2>::add
  %235 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s217.0, i64 noundef %s217.1, i64 noundef %s219.0, i64 noundef %s219.1)
  %s240.1 = extractvalue { i64, i64 } %234, 1
  %s240.0 = extractvalue { i64, i64 } %234, 0
  %s241.0 = extractvalue { i64, i64 } %235, 0
  %s241.1 = extractvalue { i64, i64 } %235, 1
; call <kernels::Fp2>::mul
  %236 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s240.0, i64 noundef %s240.1, i64 noundef %s241.0, i64 noundef %s241.1)
  %s242.0 = extractvalue { i64, i64 } %236, 0
  %s242.1 = extractvalue { i64, i64 } %236, 1
; call <kernels::Fp2>::sub
  %237 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s242.0, i64 noundef %s242.1, i64 noundef %s238.0, i64 noundef %s238.1)
  %s243.0 = extractvalue { i64, i64 } %237, 0
  %s243.1 = extractvalue { i64, i64 } %237, 1
; call <kernels::Fp2>::sub
  %238 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s243.0, i64 noundef %s243.1, i64 noundef %s239.0, i64 noundef %s239.1)
  %s244.0 = extractvalue { i64, i64 } %238, 0
  %s244.1 = extractvalue { i64, i64 } %238, 1
; call <kernels::Fp2>::mul
  %239 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s238.0, i64 noundef %s238.1, i64 noundef %s232.0, i64 noundef %s232.1)
  %s245.0 = extractvalue { i64, i64 } %239, 0
  %s245.1 = extractvalue { i64, i64 } %239, 1
; call <kernels::Fp2>::mul
  %240 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s238.0, i64 noundef %s238.1, i64 noundef %s234.0, i64 noundef %s234.1)
; call <kernels::Fp2>::mul
  %241 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s244.0, i64 noundef %s244.1, i64 noundef %s232.0, i64 noundef %s232.1)
  %s246.1 = extractvalue { i64, i64 } %240, 1
  %s246.0 = extractvalue { i64, i64 } %240, 0
  %s247.0 = extractvalue { i64, i64 } %241, 0
  %s247.1 = extractvalue { i64, i64 } %241, 1
; call <kernels::Fp2>::add
  %242 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s246.0, i64 noundef %s246.1, i64 noundef %s247.0, i64 noundef %s247.1)
  %s248.0 = extractvalue { i64, i64 } %242, 0
  %s248.1 = extractvalue { i64, i64 } %242, 1
; call <kernels::Fp2>::mul
  %243 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s244.0, i64 noundef %s244.1, i64 noundef %s234.0, i64 noundef %s234.1)
; call <kernels::Fp2>::mul
  %244 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s239.0, i64 noundef %s239.1, i64 noundef %s232.0, i64 noundef %s232.1)
  %s249.1 = extractvalue { i64, i64 } %243, 1
  %s249.0 = extractvalue { i64, i64 } %243, 0
  %s250.0 = extractvalue { i64, i64 } %244, 0
  %s250.1 = extractvalue { i64, i64 } %244, 1
; call <kernels::Fp2>::add
  %245 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s249.0, i64 noundef %s249.1, i64 noundef %s250.0, i64 noundef %s250.1)
  %s251.0 = extractvalue { i64, i64 } %245, 0
  %s251.1 = extractvalue { i64, i64 } %245, 1
; call <kernels::Fp2>::mul
  %246 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s239.0, i64 noundef %s239.1, i64 noundef %s234.0, i64 noundef %s234.1)
  %s252.0 = extractvalue { i64, i64 } %246, 0
  %s252.1 = extractvalue { i64, i64 } %246, 1
; call <kernels::Fp2>::add
  %247 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s217.0, i64 noundef %s217.1, i64 noundef %s232.0, i64 noundef %s232.1)
; call <kernels::Fp2>::add
  %248 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s219.0, i64 noundef %s219.1, i64 noundef %s234.0, i64 noundef %s234.1)
  %s253.1 = extractvalue { i64, i64 } %247, 1
  %s253.0 = extractvalue { i64, i64 } %247, 0
; call <kernels::Fp2>::sub
  %249 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s245.0, i64 noundef %s245.1, i64 noundef %s253.0, i64 noundef %s253.1)
  %s254.1 = extractvalue { i64, i64 } %248, 1
  %s254.0 = extractvalue { i64, i64 } %248, 0
  %s255.0 = extractvalue { i64, i64 } %249, 0
  %s255.1 = extractvalue { i64, i64 } %249, 1
; call <kernels::Fp2>::sub
  %250 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s248.0, i64 noundef %s248.1, i64 noundef %s254.0, i64 noundef %s254.1)
  %s256.0 = extractvalue { i64, i64 } %250, 0
  %s256.1 = extractvalue { i64, i64 } %250, 1
  %_0.i192 = getelementptr inbounds nuw i8, ptr %params, i64 464
  %s257.0 = load i64, ptr %_0.i192, align 8, !noundef !3
  %251 = getelementptr inbounds nuw i8, ptr %params, i64 472
  %s257.1 = load i64, ptr %251, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %252 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s255.0, i64 noundef %s255.1, i64 noundef %s257.0, i64 noundef %s257.1)
  %s258.0 = extractvalue { i64, i64 } %252, 0
  %s258.1 = extractvalue { i64, i64 } %252, 1
; call <kernels::Fp2>::mul
  %253 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s256.0, i64 noundef %s256.1, i64 noundef %s257.0, i64 noundef %s257.1)
  %s259.0 = extractvalue { i64, i64 } %253, 0
  %s259.1 = extractvalue { i64, i64 } %253, 1
; call <kernels::Fp2>::mul
  %254 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s251.0, i64 noundef %s251.1, i64 noundef %s257.0, i64 noundef %s257.1)
  %s260.0 = extractvalue { i64, i64 } %254, 0
  %s260.1 = extractvalue { i64, i64 } %254, 1
; call <kernels::Fp2>::mul
  %255 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s252.0, i64 noundef %s252.1, i64 noundef %s257.0, i64 noundef %s257.1)
  %s261.0 = extractvalue { i64, i64 } %255, 0
  %s261.1 = extractvalue { i64, i64 } %255, 1
; call <kernels::Fp2>::add
  %256 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s201.0, i64 noundef %s201.1, i64 noundef %s258.0, i64 noundef %s258.1)
  %s262.0 = extractvalue { i64, i64 } %256, 0
  %s262.1 = extractvalue { i64, i64 } %256, 1
; call <kernels::Fp2>::add
  %257 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s202.0, i64 noundef %s202.1, i64 noundef %s259.0, i64 noundef %s259.1)
  %s263.0 = extractvalue { i64, i64 } %257, 0
  %s263.1 = extractvalue { i64, i64 } %257, 1
; call <kernels::Fp2>::add
  %258 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s203.0, i64 noundef %s203.1, i64 noundef %s260.0, i64 noundef %s260.1)
  %s264.0 = extractvalue { i64, i64 } %258, 0
  %s264.1 = extractvalue { i64, i64 } %258, 1
; call <kernels::Fp2>::add
  %259 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s204.0, i64 noundef %s204.1, i64 noundef %s261.0, i64 noundef %s261.1)
  %s265.0 = extractvalue { i64, i64 } %259, 0
  %s265.1 = extractvalue { i64, i64 } %259, 1
  %_0.i191 = getelementptr inbounds nuw i8, ptr %params, i64 480
  %s266.0 = load i64, ptr %_0.i191, align 8, !noundef !3
  %260 = getelementptr inbounds nuw i8, ptr %params, i64 488
  %s266.1 = load i64, ptr %260, align 8, !noundef !3
  %_0.i190 = getelementptr inbounds nuw i8, ptr %raw, i64 352
  %s267.0 = load i64, ptr %_0.i190, align 8, !noundef !3
  %261 = getelementptr inbounds nuw i8, ptr %raw, i64 360
  %s267.1 = load i64, ptr %261, align 8, !noundef !3
  %_0.i189 = getelementptr inbounds nuw i8, ptr %raw, i64 368
  %s268.0 = load i64, ptr %_0.i189, align 8, !noundef !3
  %262 = getelementptr inbounds nuw i8, ptr %raw, i64 376
  %s268.1 = load i64, ptr %262, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %263 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s268.0, i64 noundef %s268.1, i64 noundef %s267.0, i64 noundef %s267.1)
  %s269.0 = extractvalue { i64, i64 } %263, 0
  %s269.1 = extractvalue { i64, i64 } %263, 1
  %_0.i188 = getelementptr inbounds nuw i8, ptr %params, i64 496
  %s270.0 = load i64, ptr %_0.i188, align 8, !noundef !3
  %264 = getelementptr inbounds nuw i8, ptr %params, i64 504
  %s270.1 = load i64, ptr %264, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %265 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s267.0, i64 noundef %s267.1, i64 noundef %s270.0, i64 noundef %s270.1)
; call <kernels::Fp2>::mul
  %266 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s269.0, i64 noundef %s269.1, i64 noundef %s270.0, i64 noundef %s270.1)
  %s271.1 = extractvalue { i64, i64 } %265, 1
  %s271.0 = extractvalue { i64, i64 } %265, 0
; call <kernels::Fp2>::add
  %267 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s227.0, i64 noundef %s227.1, i64 noundef %s271.0, i64 noundef %s271.1)
  %s272.1 = extractvalue { i64, i64 } %266, 1
  %s272.0 = extractvalue { i64, i64 } %266, 0
  %s273.0 = extractvalue { i64, i64 } %267, 0
  %s273.1 = extractvalue { i64, i64 } %267, 1
; call <kernels::Fp2>::add
  %268 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s228.0, i64 noundef %s228.1, i64 noundef %s272.0, i64 noundef %s272.1)
  %s274.0 = extractvalue { i64, i64 } %268, 0
  %s274.1 = extractvalue { i64, i64 } %268, 1
  %_0.i281 = getelementptr inbounds nuw i8, ptr %bases, i64 48
  %s275 = load i64, ptr %_0.i281, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %269 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s267.0, i64 noundef %s267.1, i64 noundef %s275)
; call <kernels::Fp2>::mul_base
  %270 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s269.0, i64 noundef %s269.1, i64 noundef %s275)
  %s276.1 = extractvalue { i64, i64 } %269, 1
  %s276.0 = extractvalue { i64, i64 } %269, 0
  %s277.0 = extractvalue { i64, i64 } %270, 0
  %s277.1 = extractvalue { i64, i64 } %270, 1
; call <kernels::Fp2>::sub
  %271 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s266.0, i64 noundef %s266.1, i64 noundef %s276.0, i64 noundef %s276.1)
  %s278.0 = extractvalue { i64, i64 } %271, 0
  %s278.1 = extractvalue { i64, i64 } %271, 1
  %_0.i187 = getelementptr inbounds nuw i8, ptr %params, i64 512
  %s279.0 = load i64, ptr %_0.i187, align 8, !noundef !3
  %272 = getelementptr inbounds nuw i8, ptr %params, i64 520
  %s279.1 = load i64, ptr %272, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %273 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s279.0, i64 noundef %s279.1, i64 noundef %s277.0, i64 noundef %s277.1)
  %s280.0 = extractvalue { i64, i64 } %273, 0
  %s280.1 = extractvalue { i64, i64 } %273, 1
  %_0.i186 = getelementptr inbounds nuw i8, ptr %params, i64 528
  %s281.0 = load i64, ptr %_0.i186, align 8, !noundef !3
  %274 = getelementptr inbounds nuw i8, ptr %params, i64 536
  %s281.1 = load i64, ptr %274, align 8, !noundef !3
  %_0.i185 = getelementptr inbounds nuw i8, ptr %raw, i64 384
  %s282.0 = load i64, ptr %_0.i185, align 8, !noundef !3
  %275 = getelementptr inbounds nuw i8, ptr %raw, i64 392
  %s282.1 = load i64, ptr %275, align 8, !noundef !3
  %_0.i184 = getelementptr inbounds nuw i8, ptr %raw, i64 400
  %s283.0 = load i64, ptr %_0.i184, align 8, !noundef !3
  %276 = getelementptr inbounds nuw i8, ptr %raw, i64 408
  %s283.1 = load i64, ptr %276, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %277 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s283.0, i64 noundef %s283.1, i64 noundef %s282.0, i64 noundef %s282.1)
  %s284.0 = extractvalue { i64, i64 } %277, 0
  %s284.1 = extractvalue { i64, i64 } %277, 1
  %_0.i183 = getelementptr inbounds nuw i8, ptr %params, i64 544
  %s285.0 = load i64, ptr %_0.i183, align 8, !noundef !3
  %278 = getelementptr inbounds nuw i8, ptr %params, i64 552
  %s285.1 = load i64, ptr %278, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %279 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s282.0, i64 noundef %s282.1, i64 noundef %s285.0, i64 noundef %s285.1)
; call <kernels::Fp2>::mul
  %280 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s284.0, i64 noundef %s284.1, i64 noundef %s285.0, i64 noundef %s285.1)
  %s286.1 = extractvalue { i64, i64 } %279, 1
  %s286.0 = extractvalue { i64, i64 } %279, 0
; call <kernels::Fp2>::add
  %281 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s273.0, i64 noundef %s273.1, i64 noundef %s286.0, i64 noundef %s286.1)
  %s287.1 = extractvalue { i64, i64 } %280, 1
  %s287.0 = extractvalue { i64, i64 } %280, 0
  %s288.0 = extractvalue { i64, i64 } %281, 0
  %s288.1 = extractvalue { i64, i64 } %281, 1
; call <kernels::Fp2>::add
  %282 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s274.0, i64 noundef %s274.1, i64 noundef %s287.0, i64 noundef %s287.1)
  %s289.0 = extractvalue { i64, i64 } %282, 0
  %s289.1 = extractvalue { i64, i64 } %282, 1
  %_0.i280 = getelementptr inbounds nuw i8, ptr %bases, i64 56
  %s290 = load i64, ptr %_0.i280, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %283 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s282.0, i64 noundef %s282.1, i64 noundef %s290)
; call <kernels::Fp2>::mul_base
  %284 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s284.0, i64 noundef %s284.1, i64 noundef %s290)
  %s291.1 = extractvalue { i64, i64 } %283, 1
  %s291.0 = extractvalue { i64, i64 } %283, 0
  %s292.0 = extractvalue { i64, i64 } %284, 0
  %s292.1 = extractvalue { i64, i64 } %284, 1
; call <kernels::Fp2>::sub
  %285 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s281.0, i64 noundef %s281.1, i64 noundef %s291.0, i64 noundef %s291.1)
  %s293.0 = extractvalue { i64, i64 } %285, 0
  %s293.1 = extractvalue { i64, i64 } %285, 1
  %_0.i182 = getelementptr inbounds nuw i8, ptr %params, i64 560
  %s294.0 = load i64, ptr %_0.i182, align 8, !noundef !3
  %286 = getelementptr inbounds nuw i8, ptr %params, i64 568
  %s294.1 = load i64, ptr %286, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %287 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s294.0, i64 noundef %s294.1, i64 noundef %s292.0, i64 noundef %s292.1)
  %s295.0 = extractvalue { i64, i64 } %287, 0
  %s295.1 = extractvalue { i64, i64 } %287, 1
  %_0.i181 = getelementptr inbounds nuw i8, ptr %raw, i64 1440
  %s296.0 = load i64, ptr %_0.i181, align 8, !noundef !3
  %288 = getelementptr inbounds nuw i8, ptr %raw, i64 1448
  %s296.1 = load i64, ptr %288, align 8, !noundef !3
  %_0.i180 = getelementptr inbounds nuw i8, ptr %raw, i64 1456
  %s297.0 = load i64, ptr %_0.i180, align 8, !noundef !3
  %289 = getelementptr inbounds nuw i8, ptr %raw, i64 1464
  %s297.1 = load i64, ptr %289, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %290 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s297.0, i64 noundef %s297.1, i64 noundef %s296.0, i64 noundef %s296.1)
  %s298.0 = extractvalue { i64, i64 } %290, 0
  %s298.1 = extractvalue { i64, i64 } %290, 1
; call <kernels::Fp2>::mul
  %291 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s296.0, i64 noundef %s296.1, i64 noundef %s278.0, i64 noundef %s278.1)
  %s299.0 = extractvalue { i64, i64 } %291, 0
  %s299.1 = extractvalue { i64, i64 } %291, 1
; call <kernels::Fp2>::mul
  %292 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s298.0, i64 noundef %s298.1, i64 noundef %s280.0, i64 noundef %s280.1)
  %s300.0 = extractvalue { i64, i64 } %292, 0
  %s300.1 = extractvalue { i64, i64 } %292, 1
; call <kernels::Fp2>::add
  %293 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s296.0, i64 noundef %s296.1, i64 noundef %s298.0, i64 noundef %s298.1)
; call <kernels::Fp2>::add
  %294 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s278.0, i64 noundef %s278.1, i64 noundef %s280.0, i64 noundef %s280.1)
  %s301.1 = extractvalue { i64, i64 } %293, 1
  %s301.0 = extractvalue { i64, i64 } %293, 0
  %s302.0 = extractvalue { i64, i64 } %294, 0
  %s302.1 = extractvalue { i64, i64 } %294, 1
; call <kernels::Fp2>::mul
  %295 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s301.0, i64 noundef %s301.1, i64 noundef %s302.0, i64 noundef %s302.1)
  %s303.0 = extractvalue { i64, i64 } %295, 0
  %s303.1 = extractvalue { i64, i64 } %295, 1
; call <kernels::Fp2>::sub
  %296 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s303.0, i64 noundef %s303.1, i64 noundef %s299.0, i64 noundef %s299.1)
  %s304.0 = extractvalue { i64, i64 } %296, 0
  %s304.1 = extractvalue { i64, i64 } %296, 1
; call <kernels::Fp2>::sub
  %297 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s304.0, i64 noundef %s304.1, i64 noundef %s300.0, i64 noundef %s300.1)
  %s305.0 = extractvalue { i64, i64 } %297, 0
  %s305.1 = extractvalue { i64, i64 } %297, 1
; call <kernels::Fp2>::mul
  %298 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s299.0, i64 noundef %s299.1, i64 noundef %s293.0, i64 noundef %s293.1)
  %s306.0 = extractvalue { i64, i64 } %298, 0
  %s306.1 = extractvalue { i64, i64 } %298, 1
; call <kernels::Fp2>::mul
  %299 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s299.0, i64 noundef %s299.1, i64 noundef %s295.0, i64 noundef %s295.1)
; call <kernels::Fp2>::mul
  %300 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s305.0, i64 noundef %s305.1, i64 noundef %s293.0, i64 noundef %s293.1)
  %s307.1 = extractvalue { i64, i64 } %299, 1
  %s307.0 = extractvalue { i64, i64 } %299, 0
  %s308.0 = extractvalue { i64, i64 } %300, 0
  %s308.1 = extractvalue { i64, i64 } %300, 1
; call <kernels::Fp2>::add
  %301 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s307.0, i64 noundef %s307.1, i64 noundef %s308.0, i64 noundef %s308.1)
  %s309.0 = extractvalue { i64, i64 } %301, 0
  %s309.1 = extractvalue { i64, i64 } %301, 1
; call <kernels::Fp2>::mul
  %302 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s305.0, i64 noundef %s305.1, i64 noundef %s295.0, i64 noundef %s295.1)
; call <kernels::Fp2>::mul
  %303 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s300.0, i64 noundef %s300.1, i64 noundef %s293.0, i64 noundef %s293.1)
  %s310.1 = extractvalue { i64, i64 } %302, 1
  %s310.0 = extractvalue { i64, i64 } %302, 0
  %s311.0 = extractvalue { i64, i64 } %303, 0
  %s311.1 = extractvalue { i64, i64 } %303, 1
; call <kernels::Fp2>::add
  %304 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s310.0, i64 noundef %s310.1, i64 noundef %s311.0, i64 noundef %s311.1)
  %s312.0 = extractvalue { i64, i64 } %304, 0
  %s312.1 = extractvalue { i64, i64 } %304, 1
; call <kernels::Fp2>::mul
  %305 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s300.0, i64 noundef %s300.1, i64 noundef %s295.0, i64 noundef %s295.1)
  %s313.0 = extractvalue { i64, i64 } %305, 0
  %s313.1 = extractvalue { i64, i64 } %305, 1
; call <kernels::Fp2>::add
  %306 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s278.0, i64 noundef %s278.1, i64 noundef %s293.0, i64 noundef %s293.1)
; call <kernels::Fp2>::add
  %307 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s280.0, i64 noundef %s280.1, i64 noundef %s295.0, i64 noundef %s295.1)
  %s314.1 = extractvalue { i64, i64 } %306, 1
  %s314.0 = extractvalue { i64, i64 } %306, 0
; call <kernels::Fp2>::sub
  %308 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s306.0, i64 noundef %s306.1, i64 noundef %s314.0, i64 noundef %s314.1)
  %s315.1 = extractvalue { i64, i64 } %307, 1
  %s315.0 = extractvalue { i64, i64 } %307, 0
  %s316.0 = extractvalue { i64, i64 } %308, 0
  %s316.1 = extractvalue { i64, i64 } %308, 1
; call <kernels::Fp2>::sub
  %309 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s309.0, i64 noundef %s309.1, i64 noundef %s315.0, i64 noundef %s315.1)
  %s317.0 = extractvalue { i64, i64 } %309, 0
  %s317.1 = extractvalue { i64, i64 } %309, 1
  %_0.i179 = getelementptr inbounds nuw i8, ptr %params, i64 576
  %s318.0 = load i64, ptr %_0.i179, align 8, !noundef !3
  %310 = getelementptr inbounds nuw i8, ptr %params, i64 584
  %s318.1 = load i64, ptr %310, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %311 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s316.0, i64 noundef %s316.1, i64 noundef %s318.0, i64 noundef %s318.1)
  %s319.0 = extractvalue { i64, i64 } %311, 0
  %s319.1 = extractvalue { i64, i64 } %311, 1
; call <kernels::Fp2>::mul
  %312 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s317.0, i64 noundef %s317.1, i64 noundef %s318.0, i64 noundef %s318.1)
  %s320.0 = extractvalue { i64, i64 } %312, 0
  %s320.1 = extractvalue { i64, i64 } %312, 1
; call <kernels::Fp2>::mul
  %313 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s312.0, i64 noundef %s312.1, i64 noundef %s318.0, i64 noundef %s318.1)
  %s321.0 = extractvalue { i64, i64 } %313, 0
  %s321.1 = extractvalue { i64, i64 } %313, 1
; call <kernels::Fp2>::mul
  %314 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s313.0, i64 noundef %s313.1, i64 noundef %s318.0, i64 noundef %s318.1)
  %s322.0 = extractvalue { i64, i64 } %314, 0
  %s322.1 = extractvalue { i64, i64 } %314, 1
; call <kernels::Fp2>::add
  %315 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s262.0, i64 noundef %s262.1, i64 noundef %s319.0, i64 noundef %s319.1)
  %s323.0 = extractvalue { i64, i64 } %315, 0
  %s323.1 = extractvalue { i64, i64 } %315, 1
; call <kernels::Fp2>::add
  %316 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s263.0, i64 noundef %s263.1, i64 noundef %s320.0, i64 noundef %s320.1)
  %s324.0 = extractvalue { i64, i64 } %316, 0
  %s324.1 = extractvalue { i64, i64 } %316, 1
; call <kernels::Fp2>::add
  %317 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s264.0, i64 noundef %s264.1, i64 noundef %s321.0, i64 noundef %s321.1)
  %s325.0 = extractvalue { i64, i64 } %317, 0
  %s325.1 = extractvalue { i64, i64 } %317, 1
; call <kernels::Fp2>::add
  %318 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s265.0, i64 noundef %s265.1, i64 noundef %s322.0, i64 noundef %s322.1)
  %s326.0 = extractvalue { i64, i64 } %318, 0
  %s326.1 = extractvalue { i64, i64 } %318, 1
  %_0.i178 = getelementptr inbounds nuw i8, ptr %params, i64 592
  %s327.0 = load i64, ptr %_0.i178, align 8, !noundef !3
  %319 = getelementptr inbounds nuw i8, ptr %params, i64 600
  %s327.1 = load i64, ptr %319, align 8, !noundef !3
  %_0.i177 = getelementptr inbounds nuw i8, ptr %raw, i64 416
  %s328.0 = load i64, ptr %_0.i177, align 8, !noundef !3
  %320 = getelementptr inbounds nuw i8, ptr %raw, i64 424
  %s328.1 = load i64, ptr %320, align 8, !noundef !3
  %_0.i176 = getelementptr inbounds nuw i8, ptr %raw, i64 432
  %s329.0 = load i64, ptr %_0.i176, align 8, !noundef !3
  %321 = getelementptr inbounds nuw i8, ptr %raw, i64 440
  %s329.1 = load i64, ptr %321, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %322 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s329.0, i64 noundef %s329.1, i64 noundef %s328.0, i64 noundef %s328.1)
  %s330.0 = extractvalue { i64, i64 } %322, 0
  %s330.1 = extractvalue { i64, i64 } %322, 1
  %_0.i175 = getelementptr inbounds nuw i8, ptr %params, i64 608
  %s331.0 = load i64, ptr %_0.i175, align 8, !noundef !3
  %323 = getelementptr inbounds nuw i8, ptr %params, i64 616
  %s331.1 = load i64, ptr %323, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %324 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s328.0, i64 noundef %s328.1, i64 noundef %s331.0, i64 noundef %s331.1)
; call <kernels::Fp2>::mul
  %325 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s330.0, i64 noundef %s330.1, i64 noundef %s331.0, i64 noundef %s331.1)
  %s332.1 = extractvalue { i64, i64 } %324, 1
  %s332.0 = extractvalue { i64, i64 } %324, 0
; call <kernels::Fp2>::add
  %326 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s288.0, i64 noundef %s288.1, i64 noundef %s332.0, i64 noundef %s332.1)
  %s333.1 = extractvalue { i64, i64 } %325, 1
  %s333.0 = extractvalue { i64, i64 } %325, 0
  %s334.0 = extractvalue { i64, i64 } %326, 0
  %s334.1 = extractvalue { i64, i64 } %326, 1
; call <kernels::Fp2>::add
  %327 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s289.0, i64 noundef %s289.1, i64 noundef %s333.0, i64 noundef %s333.1)
  %s335.0 = extractvalue { i64, i64 } %327, 0
  %s335.1 = extractvalue { i64, i64 } %327, 1
  %_0.i279 = getelementptr inbounds nuw i8, ptr %bases, i64 64
  %s336 = load i64, ptr %_0.i279, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %328 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s328.0, i64 noundef %s328.1, i64 noundef %s336)
; call <kernels::Fp2>::mul_base
  %329 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s330.0, i64 noundef %s330.1, i64 noundef %s336)
  %s337.1 = extractvalue { i64, i64 } %328, 1
  %s337.0 = extractvalue { i64, i64 } %328, 0
  %s338.0 = extractvalue { i64, i64 } %329, 0
  %s338.1 = extractvalue { i64, i64 } %329, 1
; call <kernels::Fp2>::sub
  %330 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s327.0, i64 noundef %s327.1, i64 noundef %s337.0, i64 noundef %s337.1)
  %s339.0 = extractvalue { i64, i64 } %330, 0
  %s339.1 = extractvalue { i64, i64 } %330, 1
  %_0.i174 = getelementptr inbounds nuw i8, ptr %params, i64 624
  %s340.0 = load i64, ptr %_0.i174, align 8, !noundef !3
  %331 = getelementptr inbounds nuw i8, ptr %params, i64 632
  %s340.1 = load i64, ptr %331, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %332 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s340.0, i64 noundef %s340.1, i64 noundef %s338.0, i64 noundef %s338.1)
  %s341.0 = extractvalue { i64, i64 } %332, 0
  %s341.1 = extractvalue { i64, i64 } %332, 1
  %_0.i173 = getelementptr inbounds nuw i8, ptr %params, i64 640
  %s342.0 = load i64, ptr %_0.i173, align 8, !noundef !3
  %333 = getelementptr inbounds nuw i8, ptr %params, i64 648
  %s342.1 = load i64, ptr %333, align 8, !noundef !3
  %_0.i172 = getelementptr inbounds nuw i8, ptr %raw, i64 448
  %s343.0 = load i64, ptr %_0.i172, align 8, !noundef !3
  %334 = getelementptr inbounds nuw i8, ptr %raw, i64 456
  %s343.1 = load i64, ptr %334, align 8, !noundef !3
  %_0.i171 = getelementptr inbounds nuw i8, ptr %raw, i64 464
  %s344.0 = load i64, ptr %_0.i171, align 8, !noundef !3
  %335 = getelementptr inbounds nuw i8, ptr %raw, i64 472
  %s344.1 = load i64, ptr %335, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %336 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s344.0, i64 noundef %s344.1, i64 noundef %s343.0, i64 noundef %s343.1)
  %s345.0 = extractvalue { i64, i64 } %336, 0
  %s345.1 = extractvalue { i64, i64 } %336, 1
  %_0.i170 = getelementptr inbounds nuw i8, ptr %params, i64 656
  %s346.0 = load i64, ptr %_0.i170, align 8, !noundef !3
  %337 = getelementptr inbounds nuw i8, ptr %params, i64 664
  %s346.1 = load i64, ptr %337, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %338 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s343.0, i64 noundef %s343.1, i64 noundef %s346.0, i64 noundef %s346.1)
; call <kernels::Fp2>::mul
  %339 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s345.0, i64 noundef %s345.1, i64 noundef %s346.0, i64 noundef %s346.1)
  %s347.1 = extractvalue { i64, i64 } %338, 1
  %s347.0 = extractvalue { i64, i64 } %338, 0
; call <kernels::Fp2>::add
  %340 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s334.0, i64 noundef %s334.1, i64 noundef %s347.0, i64 noundef %s347.1)
  %s348.1 = extractvalue { i64, i64 } %339, 1
  %s348.0 = extractvalue { i64, i64 } %339, 0
  %s349.0 = extractvalue { i64, i64 } %340, 0
  %s349.1 = extractvalue { i64, i64 } %340, 1
; call <kernels::Fp2>::add
  %341 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s335.0, i64 noundef %s335.1, i64 noundef %s348.0, i64 noundef %s348.1)
  %s350.0 = extractvalue { i64, i64 } %341, 0
  %s350.1 = extractvalue { i64, i64 } %341, 1
  %_0.i278 = getelementptr inbounds nuw i8, ptr %bases, i64 72
  %s351 = load i64, ptr %_0.i278, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %342 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s343.0, i64 noundef %s343.1, i64 noundef %s351)
; call <kernels::Fp2>::mul_base
  %343 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s345.0, i64 noundef %s345.1, i64 noundef %s351)
  %s352.1 = extractvalue { i64, i64 } %342, 1
  %s352.0 = extractvalue { i64, i64 } %342, 0
  %s353.0 = extractvalue { i64, i64 } %343, 0
  %s353.1 = extractvalue { i64, i64 } %343, 1
; call <kernels::Fp2>::sub
  %344 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s342.0, i64 noundef %s342.1, i64 noundef %s352.0, i64 noundef %s352.1)
  %s354.0 = extractvalue { i64, i64 } %344, 0
  %s354.1 = extractvalue { i64, i64 } %344, 1
  %_0.i169 = getelementptr inbounds nuw i8, ptr %params, i64 672
  %s355.0 = load i64, ptr %_0.i169, align 8, !noundef !3
  %345 = getelementptr inbounds nuw i8, ptr %params, i64 680
  %s355.1 = load i64, ptr %345, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %346 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s355.0, i64 noundef %s355.1, i64 noundef %s353.0, i64 noundef %s353.1)
  %s356.0 = extractvalue { i64, i64 } %346, 0
  %s356.1 = extractvalue { i64, i64 } %346, 1
  %_0.i168 = getelementptr inbounds nuw i8, ptr %raw, i64 1472
  %s357.0 = load i64, ptr %_0.i168, align 8, !noundef !3
  %347 = getelementptr inbounds nuw i8, ptr %raw, i64 1480
  %s357.1 = load i64, ptr %347, align 8, !noundef !3
  %_0.i167 = getelementptr inbounds nuw i8, ptr %raw, i64 1488
  %s358.0 = load i64, ptr %_0.i167, align 8, !noundef !3
  %348 = getelementptr inbounds nuw i8, ptr %raw, i64 1496
  %s358.1 = load i64, ptr %348, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %349 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s358.0, i64 noundef %s358.1, i64 noundef %s357.0, i64 noundef %s357.1)
  %s359.0 = extractvalue { i64, i64 } %349, 0
  %s359.1 = extractvalue { i64, i64 } %349, 1
; call <kernels::Fp2>::mul
  %350 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s357.0, i64 noundef %s357.1, i64 noundef %s339.0, i64 noundef %s339.1)
  %s360.0 = extractvalue { i64, i64 } %350, 0
  %s360.1 = extractvalue { i64, i64 } %350, 1
; call <kernels::Fp2>::mul
  %351 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s359.0, i64 noundef %s359.1, i64 noundef %s341.0, i64 noundef %s341.1)
  %s361.0 = extractvalue { i64, i64 } %351, 0
  %s361.1 = extractvalue { i64, i64 } %351, 1
; call <kernels::Fp2>::add
  %352 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s357.0, i64 noundef %s357.1, i64 noundef %s359.0, i64 noundef %s359.1)
; call <kernels::Fp2>::add
  %353 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s339.0, i64 noundef %s339.1, i64 noundef %s341.0, i64 noundef %s341.1)
  %s362.1 = extractvalue { i64, i64 } %352, 1
  %s362.0 = extractvalue { i64, i64 } %352, 0
  %s363.0 = extractvalue { i64, i64 } %353, 0
  %s363.1 = extractvalue { i64, i64 } %353, 1
; call <kernels::Fp2>::mul
  %354 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s362.0, i64 noundef %s362.1, i64 noundef %s363.0, i64 noundef %s363.1)
  %s364.0 = extractvalue { i64, i64 } %354, 0
  %s364.1 = extractvalue { i64, i64 } %354, 1
; call <kernels::Fp2>::sub
  %355 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s364.0, i64 noundef %s364.1, i64 noundef %s360.0, i64 noundef %s360.1)
  %s365.0 = extractvalue { i64, i64 } %355, 0
  %s365.1 = extractvalue { i64, i64 } %355, 1
; call <kernels::Fp2>::sub
  %356 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s365.0, i64 noundef %s365.1, i64 noundef %s361.0, i64 noundef %s361.1)
  %s366.0 = extractvalue { i64, i64 } %356, 0
  %s366.1 = extractvalue { i64, i64 } %356, 1
; call <kernels::Fp2>::mul
  %357 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s360.0, i64 noundef %s360.1, i64 noundef %s354.0, i64 noundef %s354.1)
  %s367.0 = extractvalue { i64, i64 } %357, 0
  %s367.1 = extractvalue { i64, i64 } %357, 1
; call <kernels::Fp2>::mul
  %358 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s360.0, i64 noundef %s360.1, i64 noundef %s356.0, i64 noundef %s356.1)
; call <kernels::Fp2>::mul
  %359 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s366.0, i64 noundef %s366.1, i64 noundef %s354.0, i64 noundef %s354.1)
  %s368.1 = extractvalue { i64, i64 } %358, 1
  %s368.0 = extractvalue { i64, i64 } %358, 0
  %s369.0 = extractvalue { i64, i64 } %359, 0
  %s369.1 = extractvalue { i64, i64 } %359, 1
; call <kernels::Fp2>::add
  %360 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s368.0, i64 noundef %s368.1, i64 noundef %s369.0, i64 noundef %s369.1)
  %s370.0 = extractvalue { i64, i64 } %360, 0
  %s370.1 = extractvalue { i64, i64 } %360, 1
; call <kernels::Fp2>::mul
  %361 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s366.0, i64 noundef %s366.1, i64 noundef %s356.0, i64 noundef %s356.1)
; call <kernels::Fp2>::mul
  %362 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s361.0, i64 noundef %s361.1, i64 noundef %s354.0, i64 noundef %s354.1)
  %s371.1 = extractvalue { i64, i64 } %361, 1
  %s371.0 = extractvalue { i64, i64 } %361, 0
  %s372.0 = extractvalue { i64, i64 } %362, 0
  %s372.1 = extractvalue { i64, i64 } %362, 1
; call <kernels::Fp2>::add
  %363 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s371.0, i64 noundef %s371.1, i64 noundef %s372.0, i64 noundef %s372.1)
  %s373.0 = extractvalue { i64, i64 } %363, 0
  %s373.1 = extractvalue { i64, i64 } %363, 1
; call <kernels::Fp2>::mul
  %364 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s361.0, i64 noundef %s361.1, i64 noundef %s356.0, i64 noundef %s356.1)
  %s374.0 = extractvalue { i64, i64 } %364, 0
  %s374.1 = extractvalue { i64, i64 } %364, 1
; call <kernels::Fp2>::add
  %365 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s339.0, i64 noundef %s339.1, i64 noundef %s354.0, i64 noundef %s354.1)
; call <kernels::Fp2>::add
  %366 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s341.0, i64 noundef %s341.1, i64 noundef %s356.0, i64 noundef %s356.1)
  %s375.1 = extractvalue { i64, i64 } %365, 1
  %s375.0 = extractvalue { i64, i64 } %365, 0
; call <kernels::Fp2>::sub
  %367 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s367.0, i64 noundef %s367.1, i64 noundef %s375.0, i64 noundef %s375.1)
  %s376.1 = extractvalue { i64, i64 } %366, 1
  %s376.0 = extractvalue { i64, i64 } %366, 0
  %s377.0 = extractvalue { i64, i64 } %367, 0
  %s377.1 = extractvalue { i64, i64 } %367, 1
; call <kernels::Fp2>::sub
  %368 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s370.0, i64 noundef %s370.1, i64 noundef %s376.0, i64 noundef %s376.1)
  %s378.0 = extractvalue { i64, i64 } %368, 0
  %s378.1 = extractvalue { i64, i64 } %368, 1
  %_0.i166 = getelementptr inbounds nuw i8, ptr %params, i64 688
  %s379.0 = load i64, ptr %_0.i166, align 8, !noundef !3
  %369 = getelementptr inbounds nuw i8, ptr %params, i64 696
  %s379.1 = load i64, ptr %369, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %370 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s377.0, i64 noundef %s377.1, i64 noundef %s379.0, i64 noundef %s379.1)
  %s380.0 = extractvalue { i64, i64 } %370, 0
  %s380.1 = extractvalue { i64, i64 } %370, 1
; call <kernels::Fp2>::mul
  %371 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s378.0, i64 noundef %s378.1, i64 noundef %s379.0, i64 noundef %s379.1)
  %s381.0 = extractvalue { i64, i64 } %371, 0
  %s381.1 = extractvalue { i64, i64 } %371, 1
; call <kernels::Fp2>::mul
  %372 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s373.0, i64 noundef %s373.1, i64 noundef %s379.0, i64 noundef %s379.1)
  %s382.0 = extractvalue { i64, i64 } %372, 0
  %s382.1 = extractvalue { i64, i64 } %372, 1
; call <kernels::Fp2>::mul
  %373 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s374.0, i64 noundef %s374.1, i64 noundef %s379.0, i64 noundef %s379.1)
  %s383.0 = extractvalue { i64, i64 } %373, 0
  %s383.1 = extractvalue { i64, i64 } %373, 1
; call <kernels::Fp2>::add
  %374 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s323.0, i64 noundef %s323.1, i64 noundef %s380.0, i64 noundef %s380.1)
  %s384.0 = extractvalue { i64, i64 } %374, 0
  %s384.1 = extractvalue { i64, i64 } %374, 1
; call <kernels::Fp2>::add
  %375 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s324.0, i64 noundef %s324.1, i64 noundef %s381.0, i64 noundef %s381.1)
  %s385.0 = extractvalue { i64, i64 } %375, 0
  %s385.1 = extractvalue { i64, i64 } %375, 1
; call <kernels::Fp2>::add
  %376 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s325.0, i64 noundef %s325.1, i64 noundef %s382.0, i64 noundef %s382.1)
  %s386.0 = extractvalue { i64, i64 } %376, 0
  %s386.1 = extractvalue { i64, i64 } %376, 1
; call <kernels::Fp2>::add
  %377 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s326.0, i64 noundef %s326.1, i64 noundef %s383.0, i64 noundef %s383.1)
  %s387.0 = extractvalue { i64, i64 } %377, 0
  %s387.1 = extractvalue { i64, i64 } %377, 1
  %_0.i165 = getelementptr inbounds nuw i8, ptr %params, i64 704
  %s388.0 = load i64, ptr %_0.i165, align 8, !noundef !3
  %378 = getelementptr inbounds nuw i8, ptr %params, i64 712
  %s388.1 = load i64, ptr %378, align 8, !noundef !3
  %_0.i164 = getelementptr inbounds nuw i8, ptr %raw, i64 480
  %s389.0 = load i64, ptr %_0.i164, align 8, !noundef !3
  %379 = getelementptr inbounds nuw i8, ptr %raw, i64 488
  %s389.1 = load i64, ptr %379, align 8, !noundef !3
  %_0.i163 = getelementptr inbounds nuw i8, ptr %raw, i64 496
  %s390.0 = load i64, ptr %_0.i163, align 8, !noundef !3
  %380 = getelementptr inbounds nuw i8, ptr %raw, i64 504
  %s390.1 = load i64, ptr %380, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %381 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s390.0, i64 noundef %s390.1, i64 noundef %s389.0, i64 noundef %s389.1)
  %s391.0 = extractvalue { i64, i64 } %381, 0
  %s391.1 = extractvalue { i64, i64 } %381, 1
  %_0.i162 = getelementptr inbounds nuw i8, ptr %params, i64 720
  %s392.0 = load i64, ptr %_0.i162, align 8, !noundef !3
  %382 = getelementptr inbounds nuw i8, ptr %params, i64 728
  %s392.1 = load i64, ptr %382, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %383 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s389.0, i64 noundef %s389.1, i64 noundef %s392.0, i64 noundef %s392.1)
; call <kernels::Fp2>::mul
  %384 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s391.0, i64 noundef %s391.1, i64 noundef %s392.0, i64 noundef %s392.1)
  %s393.1 = extractvalue { i64, i64 } %383, 1
  %s393.0 = extractvalue { i64, i64 } %383, 0
; call <kernels::Fp2>::add
  %385 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s349.0, i64 noundef %s349.1, i64 noundef %s393.0, i64 noundef %s393.1)
  %s394.1 = extractvalue { i64, i64 } %384, 1
  %s394.0 = extractvalue { i64, i64 } %384, 0
  %s395.0 = extractvalue { i64, i64 } %385, 0
  %s395.1 = extractvalue { i64, i64 } %385, 1
; call <kernels::Fp2>::add
  %386 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s350.0, i64 noundef %s350.1, i64 noundef %s394.0, i64 noundef %s394.1)
  %s396.0 = extractvalue { i64, i64 } %386, 0
  %s396.1 = extractvalue { i64, i64 } %386, 1
  %_0.i277 = getelementptr inbounds nuw i8, ptr %bases, i64 80
  %s397 = load i64, ptr %_0.i277, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %387 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s389.0, i64 noundef %s389.1, i64 noundef %s397)
; call <kernels::Fp2>::mul_base
  %388 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s391.0, i64 noundef %s391.1, i64 noundef %s397)
  %s398.1 = extractvalue { i64, i64 } %387, 1
  %s398.0 = extractvalue { i64, i64 } %387, 0
  %s399.0 = extractvalue { i64, i64 } %388, 0
  %s399.1 = extractvalue { i64, i64 } %388, 1
; call <kernels::Fp2>::sub
  %389 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s388.0, i64 noundef %s388.1, i64 noundef %s398.0, i64 noundef %s398.1)
  %s400.0 = extractvalue { i64, i64 } %389, 0
  %s400.1 = extractvalue { i64, i64 } %389, 1
  %_0.i161 = getelementptr inbounds nuw i8, ptr %params, i64 736
  %s401.0 = load i64, ptr %_0.i161, align 8, !noundef !3
  %390 = getelementptr inbounds nuw i8, ptr %params, i64 744
  %s401.1 = load i64, ptr %390, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %391 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s401.0, i64 noundef %s401.1, i64 noundef %s399.0, i64 noundef %s399.1)
  %s402.0 = extractvalue { i64, i64 } %391, 0
  %s402.1 = extractvalue { i64, i64 } %391, 1
  %_0.i160 = getelementptr inbounds nuw i8, ptr %params, i64 752
  %s403.0 = load i64, ptr %_0.i160, align 8, !noundef !3
  %392 = getelementptr inbounds nuw i8, ptr %params, i64 760
  %s403.1 = load i64, ptr %392, align 8, !noundef !3
  %_0.i159 = getelementptr inbounds nuw i8, ptr %raw, i64 512
  %s404.0 = load i64, ptr %_0.i159, align 8, !noundef !3
  %393 = getelementptr inbounds nuw i8, ptr %raw, i64 520
  %s404.1 = load i64, ptr %393, align 8, !noundef !3
  %_0.i158 = getelementptr inbounds nuw i8, ptr %raw, i64 528
  %s405.0 = load i64, ptr %_0.i158, align 8, !noundef !3
  %394 = getelementptr inbounds nuw i8, ptr %raw, i64 536
  %s405.1 = load i64, ptr %394, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %395 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s405.0, i64 noundef %s405.1, i64 noundef %s404.0, i64 noundef %s404.1)
  %s406.0 = extractvalue { i64, i64 } %395, 0
  %s406.1 = extractvalue { i64, i64 } %395, 1
  %_0.i157 = getelementptr inbounds nuw i8, ptr %params, i64 768
  %s407.0 = load i64, ptr %_0.i157, align 8, !noundef !3
  %396 = getelementptr inbounds nuw i8, ptr %params, i64 776
  %s407.1 = load i64, ptr %396, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %397 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s404.0, i64 noundef %s404.1, i64 noundef %s407.0, i64 noundef %s407.1)
; call <kernels::Fp2>::mul
  %398 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s406.0, i64 noundef %s406.1, i64 noundef %s407.0, i64 noundef %s407.1)
  %s408.1 = extractvalue { i64, i64 } %397, 1
  %s408.0 = extractvalue { i64, i64 } %397, 0
; call <kernels::Fp2>::add
  %399 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s395.0, i64 noundef %s395.1, i64 noundef %s408.0, i64 noundef %s408.1)
  %s409.1 = extractvalue { i64, i64 } %398, 1
  %s409.0 = extractvalue { i64, i64 } %398, 0
  %s410.0 = extractvalue { i64, i64 } %399, 0
  %s410.1 = extractvalue { i64, i64 } %399, 1
; call <kernels::Fp2>::add
  %400 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s396.0, i64 noundef %s396.1, i64 noundef %s409.0, i64 noundef %s409.1)
  %s411.0 = extractvalue { i64, i64 } %400, 0
  %s411.1 = extractvalue { i64, i64 } %400, 1
  %_0.i276 = getelementptr inbounds nuw i8, ptr %bases, i64 88
  %s412 = load i64, ptr %_0.i276, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %401 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s404.0, i64 noundef %s404.1, i64 noundef %s412)
; call <kernels::Fp2>::mul_base
  %402 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s406.0, i64 noundef %s406.1, i64 noundef %s412)
  %s413.1 = extractvalue { i64, i64 } %401, 1
  %s413.0 = extractvalue { i64, i64 } %401, 0
  %s414.0 = extractvalue { i64, i64 } %402, 0
  %s414.1 = extractvalue { i64, i64 } %402, 1
; call <kernels::Fp2>::sub
  %403 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s403.0, i64 noundef %s403.1, i64 noundef %s413.0, i64 noundef %s413.1)
  %s415.0 = extractvalue { i64, i64 } %403, 0
  %s415.1 = extractvalue { i64, i64 } %403, 1
  %_0.i156 = getelementptr inbounds nuw i8, ptr %params, i64 784
  %s416.0 = load i64, ptr %_0.i156, align 8, !noundef !3
  %404 = getelementptr inbounds nuw i8, ptr %params, i64 792
  %s416.1 = load i64, ptr %404, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %405 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s416.0, i64 noundef %s416.1, i64 noundef %s414.0, i64 noundef %s414.1)
  %s417.0 = extractvalue { i64, i64 } %405, 0
  %s417.1 = extractvalue { i64, i64 } %405, 1
  %_0.i155 = getelementptr inbounds nuw i8, ptr %raw, i64 1504
  %s418.0 = load i64, ptr %_0.i155, align 8, !noundef !3
  %406 = getelementptr inbounds nuw i8, ptr %raw, i64 1512
  %s418.1 = load i64, ptr %406, align 8, !noundef !3
  %_0.i154 = getelementptr inbounds nuw i8, ptr %raw, i64 1520
  %s419.0 = load i64, ptr %_0.i154, align 8, !noundef !3
  %407 = getelementptr inbounds nuw i8, ptr %raw, i64 1528
  %s419.1 = load i64, ptr %407, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %408 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s419.0, i64 noundef %s419.1, i64 noundef %s418.0, i64 noundef %s418.1)
  %s420.0 = extractvalue { i64, i64 } %408, 0
  %s420.1 = extractvalue { i64, i64 } %408, 1
; call <kernels::Fp2>::mul
  %409 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s418.0, i64 noundef %s418.1, i64 noundef %s400.0, i64 noundef %s400.1)
  %s421.0 = extractvalue { i64, i64 } %409, 0
  %s421.1 = extractvalue { i64, i64 } %409, 1
; call <kernels::Fp2>::mul
  %410 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s420.0, i64 noundef %s420.1, i64 noundef %s402.0, i64 noundef %s402.1)
  %s422.0 = extractvalue { i64, i64 } %410, 0
  %s422.1 = extractvalue { i64, i64 } %410, 1
; call <kernels::Fp2>::add
  %411 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s418.0, i64 noundef %s418.1, i64 noundef %s420.0, i64 noundef %s420.1)
; call <kernels::Fp2>::add
  %412 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s400.0, i64 noundef %s400.1, i64 noundef %s402.0, i64 noundef %s402.1)
  %s423.1 = extractvalue { i64, i64 } %411, 1
  %s423.0 = extractvalue { i64, i64 } %411, 0
  %s424.0 = extractvalue { i64, i64 } %412, 0
  %s424.1 = extractvalue { i64, i64 } %412, 1
; call <kernels::Fp2>::mul
  %413 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s423.0, i64 noundef %s423.1, i64 noundef %s424.0, i64 noundef %s424.1)
  %s425.0 = extractvalue { i64, i64 } %413, 0
  %s425.1 = extractvalue { i64, i64 } %413, 1
; call <kernels::Fp2>::sub
  %414 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s425.0, i64 noundef %s425.1, i64 noundef %s421.0, i64 noundef %s421.1)
  %s426.0 = extractvalue { i64, i64 } %414, 0
  %s426.1 = extractvalue { i64, i64 } %414, 1
; call <kernels::Fp2>::sub
  %415 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s426.0, i64 noundef %s426.1, i64 noundef %s422.0, i64 noundef %s422.1)
  %s427.0 = extractvalue { i64, i64 } %415, 0
  %s427.1 = extractvalue { i64, i64 } %415, 1
; call <kernels::Fp2>::mul
  %416 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s421.0, i64 noundef %s421.1, i64 noundef %s415.0, i64 noundef %s415.1)
  %s428.0 = extractvalue { i64, i64 } %416, 0
  %s428.1 = extractvalue { i64, i64 } %416, 1
; call <kernels::Fp2>::mul
  %417 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s421.0, i64 noundef %s421.1, i64 noundef %s417.0, i64 noundef %s417.1)
; call <kernels::Fp2>::mul
  %418 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s427.0, i64 noundef %s427.1, i64 noundef %s415.0, i64 noundef %s415.1)
  %s429.1 = extractvalue { i64, i64 } %417, 1
  %s429.0 = extractvalue { i64, i64 } %417, 0
  %s430.0 = extractvalue { i64, i64 } %418, 0
  %s430.1 = extractvalue { i64, i64 } %418, 1
; call <kernels::Fp2>::add
  %419 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s429.0, i64 noundef %s429.1, i64 noundef %s430.0, i64 noundef %s430.1)
  %s431.0 = extractvalue { i64, i64 } %419, 0
  %s431.1 = extractvalue { i64, i64 } %419, 1
; call <kernels::Fp2>::mul
  %420 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s427.0, i64 noundef %s427.1, i64 noundef %s417.0, i64 noundef %s417.1)
; call <kernels::Fp2>::mul
  %421 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s422.0, i64 noundef %s422.1, i64 noundef %s415.0, i64 noundef %s415.1)
  %s432.1 = extractvalue { i64, i64 } %420, 1
  %s432.0 = extractvalue { i64, i64 } %420, 0
  %s433.0 = extractvalue { i64, i64 } %421, 0
  %s433.1 = extractvalue { i64, i64 } %421, 1
; call <kernels::Fp2>::add
  %422 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s432.0, i64 noundef %s432.1, i64 noundef %s433.0, i64 noundef %s433.1)
  %s434.0 = extractvalue { i64, i64 } %422, 0
  %s434.1 = extractvalue { i64, i64 } %422, 1
; call <kernels::Fp2>::mul
  %423 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s422.0, i64 noundef %s422.1, i64 noundef %s417.0, i64 noundef %s417.1)
  %s435.0 = extractvalue { i64, i64 } %423, 0
  %s435.1 = extractvalue { i64, i64 } %423, 1
; call <kernels::Fp2>::add
  %424 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s400.0, i64 noundef %s400.1, i64 noundef %s415.0, i64 noundef %s415.1)
; call <kernels::Fp2>::add
  %425 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s402.0, i64 noundef %s402.1, i64 noundef %s417.0, i64 noundef %s417.1)
  %s436.1 = extractvalue { i64, i64 } %424, 1
  %s436.0 = extractvalue { i64, i64 } %424, 0
; call <kernels::Fp2>::sub
  %426 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s428.0, i64 noundef %s428.1, i64 noundef %s436.0, i64 noundef %s436.1)
  %s437.1 = extractvalue { i64, i64 } %425, 1
  %s437.0 = extractvalue { i64, i64 } %425, 0
  %s438.0 = extractvalue { i64, i64 } %426, 0
  %s438.1 = extractvalue { i64, i64 } %426, 1
; call <kernels::Fp2>::sub
  %427 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s431.0, i64 noundef %s431.1, i64 noundef %s437.0, i64 noundef %s437.1)
  %s439.0 = extractvalue { i64, i64 } %427, 0
  %s439.1 = extractvalue { i64, i64 } %427, 1
  %_0.i153 = getelementptr inbounds nuw i8, ptr %params, i64 800
  %s440.0 = load i64, ptr %_0.i153, align 8, !noundef !3
  %428 = getelementptr inbounds nuw i8, ptr %params, i64 808
  %s440.1 = load i64, ptr %428, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %429 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s438.0, i64 noundef %s438.1, i64 noundef %s440.0, i64 noundef %s440.1)
  %s441.0 = extractvalue { i64, i64 } %429, 0
  %s441.1 = extractvalue { i64, i64 } %429, 1
; call <kernels::Fp2>::mul
  %430 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s439.0, i64 noundef %s439.1, i64 noundef %s440.0, i64 noundef %s440.1)
  %s442.0 = extractvalue { i64, i64 } %430, 0
  %s442.1 = extractvalue { i64, i64 } %430, 1
; call <kernels::Fp2>::mul
  %431 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s434.0, i64 noundef %s434.1, i64 noundef %s440.0, i64 noundef %s440.1)
  %s443.0 = extractvalue { i64, i64 } %431, 0
  %s443.1 = extractvalue { i64, i64 } %431, 1
; call <kernels::Fp2>::mul
  %432 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s435.0, i64 noundef %s435.1, i64 noundef %s440.0, i64 noundef %s440.1)
  %s444.0 = extractvalue { i64, i64 } %432, 0
  %s444.1 = extractvalue { i64, i64 } %432, 1
; call <kernels::Fp2>::add
  %433 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s384.0, i64 noundef %s384.1, i64 noundef %s441.0, i64 noundef %s441.1)
  %s445.0 = extractvalue { i64, i64 } %433, 0
  %s445.1 = extractvalue { i64, i64 } %433, 1
; call <kernels::Fp2>::add
  %434 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s385.0, i64 noundef %s385.1, i64 noundef %s442.0, i64 noundef %s442.1)
  %s446.0 = extractvalue { i64, i64 } %434, 0
  %s446.1 = extractvalue { i64, i64 } %434, 1
; call <kernels::Fp2>::add
  %435 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s386.0, i64 noundef %s386.1, i64 noundef %s443.0, i64 noundef %s443.1)
  %s447.0 = extractvalue { i64, i64 } %435, 0
  %s447.1 = extractvalue { i64, i64 } %435, 1
; call <kernels::Fp2>::add
  %436 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s387.0, i64 noundef %s387.1, i64 noundef %s444.0, i64 noundef %s444.1)
  %s448.0 = extractvalue { i64, i64 } %436, 0
  %s448.1 = extractvalue { i64, i64 } %436, 1
  %_0.i152 = getelementptr inbounds nuw i8, ptr %params, i64 816
  %s449.0 = load i64, ptr %_0.i152, align 8, !noundef !3
  %437 = getelementptr inbounds nuw i8, ptr %params, i64 824
  %s449.1 = load i64, ptr %437, align 8, !noundef !3
  %_0.i151 = getelementptr inbounds nuw i8, ptr %raw, i64 576
  %s450.0 = load i64, ptr %_0.i151, align 8, !noundef !3
  %438 = getelementptr inbounds nuw i8, ptr %raw, i64 584
  %s450.1 = load i64, ptr %438, align 8, !noundef !3
  %_0.i150 = getelementptr inbounds nuw i8, ptr %raw, i64 592
  %s451.0 = load i64, ptr %_0.i150, align 8, !noundef !3
  %439 = getelementptr inbounds nuw i8, ptr %raw, i64 600
  %s451.1 = load i64, ptr %439, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %440 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s451.0, i64 noundef %s451.1, i64 noundef %s450.0, i64 noundef %s450.1)
  %s452.0 = extractvalue { i64, i64 } %440, 0
  %s452.1 = extractvalue { i64, i64 } %440, 1
  %_0.i149 = getelementptr inbounds nuw i8, ptr %params, i64 832
  %s453.0 = load i64, ptr %_0.i149, align 8, !noundef !3
  %441 = getelementptr inbounds nuw i8, ptr %params, i64 840
  %s453.1 = load i64, ptr %441, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %442 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s450.0, i64 noundef %s450.1, i64 noundef %s453.0, i64 noundef %s453.1)
; call <kernels::Fp2>::mul
  %443 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s452.0, i64 noundef %s452.1, i64 noundef %s453.0, i64 noundef %s453.1)
  %s454.1 = extractvalue { i64, i64 } %442, 1
  %s454.0 = extractvalue { i64, i64 } %442, 0
; call <kernels::Fp2>::add
  %444 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s410.0, i64 noundef %s410.1, i64 noundef %s454.0, i64 noundef %s454.1)
  %s455.1 = extractvalue { i64, i64 } %443, 1
  %s455.0 = extractvalue { i64, i64 } %443, 0
  %s456.0 = extractvalue { i64, i64 } %444, 0
  %s456.1 = extractvalue { i64, i64 } %444, 1
; call <kernels::Fp2>::add
  %445 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s411.0, i64 noundef %s411.1, i64 noundef %s455.0, i64 noundef %s455.1)
  %s457.0 = extractvalue { i64, i64 } %445, 0
  %s457.1 = extractvalue { i64, i64 } %445, 1
  %_0.i275 = getelementptr inbounds nuw i8, ptr %bases, i64 96
  %s458 = load i64, ptr %_0.i275, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %446 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s450.0, i64 noundef %s450.1, i64 noundef %s458)
; call <kernels::Fp2>::mul_base
  %447 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s452.0, i64 noundef %s452.1, i64 noundef %s458)
  %s459.1 = extractvalue { i64, i64 } %446, 1
  %s459.0 = extractvalue { i64, i64 } %446, 0
  %s460.0 = extractvalue { i64, i64 } %447, 0
  %s460.1 = extractvalue { i64, i64 } %447, 1
; call <kernels::Fp2>::sub
  %448 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s449.0, i64 noundef %s449.1, i64 noundef %s459.0, i64 noundef %s459.1)
  %s461.0 = extractvalue { i64, i64 } %448, 0
  %s461.1 = extractvalue { i64, i64 } %448, 1
  %_0.i148 = getelementptr inbounds nuw i8, ptr %params, i64 848
  %s462.0 = load i64, ptr %_0.i148, align 8, !noundef !3
  %449 = getelementptr inbounds nuw i8, ptr %params, i64 856
  %s462.1 = load i64, ptr %449, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %450 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s462.0, i64 noundef %s462.1, i64 noundef %s460.0, i64 noundef %s460.1)
  %s463.0 = extractvalue { i64, i64 } %450, 0
  %s463.1 = extractvalue { i64, i64 } %450, 1
  %_0.i147 = getelementptr inbounds nuw i8, ptr %params, i64 864
  %s464.0 = load i64, ptr %_0.i147, align 8, !noundef !3
  %451 = getelementptr inbounds nuw i8, ptr %params, i64 872
  %s464.1 = load i64, ptr %451, align 8, !noundef !3
  %_0.i146 = getelementptr inbounds nuw i8, ptr %raw, i64 608
  %s465.0 = load i64, ptr %_0.i146, align 8, !noundef !3
  %452 = getelementptr inbounds nuw i8, ptr %raw, i64 616
  %s465.1 = load i64, ptr %452, align 8, !noundef !3
  %_0.i145 = getelementptr inbounds nuw i8, ptr %raw, i64 624
  %s466.0 = load i64, ptr %_0.i145, align 8, !noundef !3
  %453 = getelementptr inbounds nuw i8, ptr %raw, i64 632
  %s466.1 = load i64, ptr %453, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %454 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s466.0, i64 noundef %s466.1, i64 noundef %s465.0, i64 noundef %s465.1)
  %s467.0 = extractvalue { i64, i64 } %454, 0
  %s467.1 = extractvalue { i64, i64 } %454, 1
  %_0.i144 = getelementptr inbounds nuw i8, ptr %params, i64 880
  %s468.0 = load i64, ptr %_0.i144, align 8, !noundef !3
  %455 = getelementptr inbounds nuw i8, ptr %params, i64 888
  %s468.1 = load i64, ptr %455, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %456 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s465.0, i64 noundef %s465.1, i64 noundef %s468.0, i64 noundef %s468.1)
; call <kernels::Fp2>::mul
  %457 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s467.0, i64 noundef %s467.1, i64 noundef %s468.0, i64 noundef %s468.1)
  %s469.1 = extractvalue { i64, i64 } %456, 1
  %s469.0 = extractvalue { i64, i64 } %456, 0
; call <kernels::Fp2>::add
  %458 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s456.0, i64 noundef %s456.1, i64 noundef %s469.0, i64 noundef %s469.1)
  %s470.1 = extractvalue { i64, i64 } %457, 1
  %s470.0 = extractvalue { i64, i64 } %457, 0
  %s471.0 = extractvalue { i64, i64 } %458, 0
  %s471.1 = extractvalue { i64, i64 } %458, 1
; call <kernels::Fp2>::add
  %459 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s457.0, i64 noundef %s457.1, i64 noundef %s470.0, i64 noundef %s470.1)
  %s472.0 = extractvalue { i64, i64 } %459, 0
  %s472.1 = extractvalue { i64, i64 } %459, 1
  %_0.i274 = getelementptr inbounds nuw i8, ptr %bases, i64 104
  %s473 = load i64, ptr %_0.i274, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %460 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s465.0, i64 noundef %s465.1, i64 noundef %s473)
; call <kernels::Fp2>::mul_base
  %461 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s467.0, i64 noundef %s467.1, i64 noundef %s473)
  %s474.1 = extractvalue { i64, i64 } %460, 1
  %s474.0 = extractvalue { i64, i64 } %460, 0
  %s475.0 = extractvalue { i64, i64 } %461, 0
  %s475.1 = extractvalue { i64, i64 } %461, 1
; call <kernels::Fp2>::sub
  %462 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s464.0, i64 noundef %s464.1, i64 noundef %s474.0, i64 noundef %s474.1)
  %s476.0 = extractvalue { i64, i64 } %462, 0
  %s476.1 = extractvalue { i64, i64 } %462, 1
  %_0.i143 = getelementptr inbounds nuw i8, ptr %params, i64 896
  %s477.0 = load i64, ptr %_0.i143, align 8, !noundef !3
  %463 = getelementptr inbounds nuw i8, ptr %params, i64 904
  %s477.1 = load i64, ptr %463, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %464 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s477.0, i64 noundef %s477.1, i64 noundef %s475.0, i64 noundef %s475.1)
  %s478.0 = extractvalue { i64, i64 } %464, 0
  %s478.1 = extractvalue { i64, i64 } %464, 1
  %_0.i142 = getelementptr inbounds nuw i8, ptr %raw, i64 1536
  %s479.0 = load i64, ptr %_0.i142, align 8, !noundef !3
  %465 = getelementptr inbounds nuw i8, ptr %raw, i64 1544
  %s479.1 = load i64, ptr %465, align 8, !noundef !3
  %_0.i141 = getelementptr inbounds nuw i8, ptr %raw, i64 1552
  %s480.0 = load i64, ptr %_0.i141, align 8, !noundef !3
  %466 = getelementptr inbounds nuw i8, ptr %raw, i64 1560
  %s480.1 = load i64, ptr %466, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %467 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s480.0, i64 noundef %s480.1, i64 noundef %s479.0, i64 noundef %s479.1)
  %s481.0 = extractvalue { i64, i64 } %467, 0
  %s481.1 = extractvalue { i64, i64 } %467, 1
; call <kernels::Fp2>::mul
  %468 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s479.0, i64 noundef %s479.1, i64 noundef %s461.0, i64 noundef %s461.1)
  %s482.0 = extractvalue { i64, i64 } %468, 0
  %s482.1 = extractvalue { i64, i64 } %468, 1
; call <kernels::Fp2>::mul
  %469 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s481.0, i64 noundef %s481.1, i64 noundef %s463.0, i64 noundef %s463.1)
  %s483.0 = extractvalue { i64, i64 } %469, 0
  %s483.1 = extractvalue { i64, i64 } %469, 1
; call <kernels::Fp2>::add
  %470 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s479.0, i64 noundef %s479.1, i64 noundef %s481.0, i64 noundef %s481.1)
; call <kernels::Fp2>::add
  %471 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s461.0, i64 noundef %s461.1, i64 noundef %s463.0, i64 noundef %s463.1)
  %s484.1 = extractvalue { i64, i64 } %470, 1
  %s484.0 = extractvalue { i64, i64 } %470, 0
  %s485.0 = extractvalue { i64, i64 } %471, 0
  %s485.1 = extractvalue { i64, i64 } %471, 1
; call <kernels::Fp2>::mul
  %472 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s484.0, i64 noundef %s484.1, i64 noundef %s485.0, i64 noundef %s485.1)
  %s486.0 = extractvalue { i64, i64 } %472, 0
  %s486.1 = extractvalue { i64, i64 } %472, 1
; call <kernels::Fp2>::sub
  %473 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s486.0, i64 noundef %s486.1, i64 noundef %s482.0, i64 noundef %s482.1)
  %s487.0 = extractvalue { i64, i64 } %473, 0
  %s487.1 = extractvalue { i64, i64 } %473, 1
; call <kernels::Fp2>::sub
  %474 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s487.0, i64 noundef %s487.1, i64 noundef %s483.0, i64 noundef %s483.1)
  %s488.0 = extractvalue { i64, i64 } %474, 0
  %s488.1 = extractvalue { i64, i64 } %474, 1
; call <kernels::Fp2>::mul
  %475 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s482.0, i64 noundef %s482.1, i64 noundef %s476.0, i64 noundef %s476.1)
  %s489.0 = extractvalue { i64, i64 } %475, 0
  %s489.1 = extractvalue { i64, i64 } %475, 1
; call <kernels::Fp2>::mul
  %476 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s482.0, i64 noundef %s482.1, i64 noundef %s478.0, i64 noundef %s478.1)
; call <kernels::Fp2>::mul
  %477 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s488.0, i64 noundef %s488.1, i64 noundef %s476.0, i64 noundef %s476.1)
  %s490.1 = extractvalue { i64, i64 } %476, 1
  %s490.0 = extractvalue { i64, i64 } %476, 0
  %s491.0 = extractvalue { i64, i64 } %477, 0
  %s491.1 = extractvalue { i64, i64 } %477, 1
; call <kernels::Fp2>::add
  %478 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s490.0, i64 noundef %s490.1, i64 noundef %s491.0, i64 noundef %s491.1)
  %s492.0 = extractvalue { i64, i64 } %478, 0
  %s492.1 = extractvalue { i64, i64 } %478, 1
; call <kernels::Fp2>::mul
  %479 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s488.0, i64 noundef %s488.1, i64 noundef %s478.0, i64 noundef %s478.1)
; call <kernels::Fp2>::mul
  %480 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s483.0, i64 noundef %s483.1, i64 noundef %s476.0, i64 noundef %s476.1)
  %s493.1 = extractvalue { i64, i64 } %479, 1
  %s493.0 = extractvalue { i64, i64 } %479, 0
  %s494.0 = extractvalue { i64, i64 } %480, 0
  %s494.1 = extractvalue { i64, i64 } %480, 1
; call <kernels::Fp2>::add
  %481 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s493.0, i64 noundef %s493.1, i64 noundef %s494.0, i64 noundef %s494.1)
  %s495.0 = extractvalue { i64, i64 } %481, 0
  %s495.1 = extractvalue { i64, i64 } %481, 1
; call <kernels::Fp2>::mul
  %482 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s483.0, i64 noundef %s483.1, i64 noundef %s478.0, i64 noundef %s478.1)
  %s496.0 = extractvalue { i64, i64 } %482, 0
  %s496.1 = extractvalue { i64, i64 } %482, 1
; call <kernels::Fp2>::add
  %483 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s461.0, i64 noundef %s461.1, i64 noundef %s476.0, i64 noundef %s476.1)
; call <kernels::Fp2>::add
  %484 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s463.0, i64 noundef %s463.1, i64 noundef %s478.0, i64 noundef %s478.1)
  %s497.1 = extractvalue { i64, i64 } %483, 1
  %s497.0 = extractvalue { i64, i64 } %483, 0
; call <kernels::Fp2>::sub
  %485 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s489.0, i64 noundef %s489.1, i64 noundef %s497.0, i64 noundef %s497.1)
  %s498.1 = extractvalue { i64, i64 } %484, 1
  %s498.0 = extractvalue { i64, i64 } %484, 0
  %s499.0 = extractvalue { i64, i64 } %485, 0
  %s499.1 = extractvalue { i64, i64 } %485, 1
; call <kernels::Fp2>::sub
  %486 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s492.0, i64 noundef %s492.1, i64 noundef %s498.0, i64 noundef %s498.1)
  %s500.0 = extractvalue { i64, i64 } %486, 0
  %s500.1 = extractvalue { i64, i64 } %486, 1
  %_0.i140 = getelementptr inbounds nuw i8, ptr %params, i64 912
  %s501.0 = load i64, ptr %_0.i140, align 8, !noundef !3
  %487 = getelementptr inbounds nuw i8, ptr %params, i64 920
  %s501.1 = load i64, ptr %487, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %488 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s499.0, i64 noundef %s499.1, i64 noundef %s501.0, i64 noundef %s501.1)
  %s502.0 = extractvalue { i64, i64 } %488, 0
  %s502.1 = extractvalue { i64, i64 } %488, 1
; call <kernels::Fp2>::mul
  %489 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s500.0, i64 noundef %s500.1, i64 noundef %s501.0, i64 noundef %s501.1)
  %s503.0 = extractvalue { i64, i64 } %489, 0
  %s503.1 = extractvalue { i64, i64 } %489, 1
; call <kernels::Fp2>::mul
  %490 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s495.0, i64 noundef %s495.1, i64 noundef %s501.0, i64 noundef %s501.1)
  %s504.0 = extractvalue { i64, i64 } %490, 0
  %s504.1 = extractvalue { i64, i64 } %490, 1
; call <kernels::Fp2>::mul
  %491 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s496.0, i64 noundef %s496.1, i64 noundef %s501.0, i64 noundef %s501.1)
  %s505.0 = extractvalue { i64, i64 } %491, 0
  %s505.1 = extractvalue { i64, i64 } %491, 1
; call <kernels::Fp2>::add
  %492 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s445.0, i64 noundef %s445.1, i64 noundef %s502.0, i64 noundef %s502.1)
  %s506.0 = extractvalue { i64, i64 } %492, 0
  %s506.1 = extractvalue { i64, i64 } %492, 1
; call <kernels::Fp2>::add
  %493 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s446.0, i64 noundef %s446.1, i64 noundef %s503.0, i64 noundef %s503.1)
  %s507.0 = extractvalue { i64, i64 } %493, 0
  %s507.1 = extractvalue { i64, i64 } %493, 1
; call <kernels::Fp2>::add
  %494 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s447.0, i64 noundef %s447.1, i64 noundef %s504.0, i64 noundef %s504.1)
  %s508.0 = extractvalue { i64, i64 } %494, 0
  %s508.1 = extractvalue { i64, i64 } %494, 1
; call <kernels::Fp2>::add
  %495 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s448.0, i64 noundef %s448.1, i64 noundef %s505.0, i64 noundef %s505.1)
  %s509.0 = extractvalue { i64, i64 } %495, 0
  %s509.1 = extractvalue { i64, i64 } %495, 1
  %_0.i139 = getelementptr inbounds nuw i8, ptr %params, i64 928
  %s510.0 = load i64, ptr %_0.i139, align 8, !noundef !3
  %496 = getelementptr inbounds nuw i8, ptr %params, i64 936
  %s510.1 = load i64, ptr %496, align 8, !noundef !3
  %_0.i138 = getelementptr inbounds nuw i8, ptr %raw, i64 640
  %s511.0 = load i64, ptr %_0.i138, align 8, !noundef !3
  %497 = getelementptr inbounds nuw i8, ptr %raw, i64 648
  %s511.1 = load i64, ptr %497, align 8, !noundef !3
  %_0.i137 = getelementptr inbounds nuw i8, ptr %raw, i64 656
  %s512.0 = load i64, ptr %_0.i137, align 8, !noundef !3
  %498 = getelementptr inbounds nuw i8, ptr %raw, i64 664
  %s512.1 = load i64, ptr %498, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %499 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s512.0, i64 noundef %s512.1, i64 noundef %s511.0, i64 noundef %s511.1)
  %s513.0 = extractvalue { i64, i64 } %499, 0
  %s513.1 = extractvalue { i64, i64 } %499, 1
  %_0.i273 = getelementptr inbounds nuw i8, ptr %bases, i64 112
  %s514 = load i64, ptr %_0.i273, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %500 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s511.0, i64 noundef %s511.1, i64 noundef %s514)
; call <kernels::Fp2>::mul_base
  %501 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s513.0, i64 noundef %s513.1, i64 noundef %s514)
  %s515.1 = extractvalue { i64, i64 } %500, 1
  %s515.0 = extractvalue { i64, i64 } %500, 0
  %s516.0 = extractvalue { i64, i64 } %501, 0
  %s516.1 = extractvalue { i64, i64 } %501, 1
; call <kernels::Fp2>::sub
  %502 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s510.0, i64 noundef %s510.1, i64 noundef %s515.0, i64 noundef %s515.1)
  %s517.0 = extractvalue { i64, i64 } %502, 0
  %s517.1 = extractvalue { i64, i64 } %502, 1
  %_0.i136 = getelementptr inbounds nuw i8, ptr %params, i64 944
  %s518.0 = load i64, ptr %_0.i136, align 8, !noundef !3
  %503 = getelementptr inbounds nuw i8, ptr %params, i64 952
  %s518.1 = load i64, ptr %503, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %504 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s518.0, i64 noundef %s518.1, i64 noundef %s516.0, i64 noundef %s516.1)
  %s519.0 = extractvalue { i64, i64 } %504, 0
  %s519.1 = extractvalue { i64, i64 } %504, 1
  %_0.i135 = getelementptr inbounds nuw i8, ptr %params, i64 960
  %s520.0 = load i64, ptr %_0.i135, align 8, !noundef !3
  %505 = getelementptr inbounds nuw i8, ptr %params, i64 968
  %s520.1 = load i64, ptr %505, align 8, !noundef !3
  %_0.i272 = getelementptr inbounds nuw i8, ptr %bases, i64 120
  %s521 = load i64, ptr %_0.i272, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %506 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s511.0, i64 noundef %s511.1, i64 noundef %s521)
; call <kernels::Fp2>::mul_base
  %507 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s513.0, i64 noundef %s513.1, i64 noundef %s521)
  %s522.1 = extractvalue { i64, i64 } %506, 1
  %s522.0 = extractvalue { i64, i64 } %506, 0
  %s523.0 = extractvalue { i64, i64 } %507, 0
  %s523.1 = extractvalue { i64, i64 } %507, 1
; call <kernels::Fp2>::sub
  %508 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s520.0, i64 noundef %s520.1, i64 noundef %s522.0, i64 noundef %s522.1)
  %s524.0 = extractvalue { i64, i64 } %508, 0
  %s524.1 = extractvalue { i64, i64 } %508, 1
  %_0.i134 = getelementptr inbounds nuw i8, ptr %params, i64 976
  %s525.0 = load i64, ptr %_0.i134, align 8, !noundef !3
  %509 = getelementptr inbounds nuw i8, ptr %params, i64 984
  %s525.1 = load i64, ptr %509, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %510 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s525.0, i64 noundef %s525.1, i64 noundef %s523.0, i64 noundef %s523.1)
  %s526.0 = extractvalue { i64, i64 } %510, 0
  %s526.1 = extractvalue { i64, i64 } %510, 1
  %_0.i133 = getelementptr inbounds nuw i8, ptr %raw, i64 1568
  %s527.0 = load i64, ptr %_0.i133, align 8, !noundef !3
  %511 = getelementptr inbounds nuw i8, ptr %raw, i64 1576
  %s527.1 = load i64, ptr %511, align 8, !noundef !3
  %_0.i132 = getelementptr inbounds nuw i8, ptr %raw, i64 1584
  %s528.0 = load i64, ptr %_0.i132, align 8, !noundef !3
  %512 = getelementptr inbounds nuw i8, ptr %raw, i64 1592
  %s528.1 = load i64, ptr %512, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %513 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s528.0, i64 noundef %s528.1, i64 noundef %s527.0, i64 noundef %s527.1)
  %s529.0 = extractvalue { i64, i64 } %513, 0
  %s529.1 = extractvalue { i64, i64 } %513, 1
; call <kernels::Fp2>::mul
  %514 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s527.0, i64 noundef %s527.1, i64 noundef %s517.0, i64 noundef %s517.1)
  %s530.0 = extractvalue { i64, i64 } %514, 0
  %s530.1 = extractvalue { i64, i64 } %514, 1
; call <kernels::Fp2>::mul
  %515 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s529.0, i64 noundef %s529.1, i64 noundef %s519.0, i64 noundef %s519.1)
  %s531.0 = extractvalue { i64, i64 } %515, 0
  %s531.1 = extractvalue { i64, i64 } %515, 1
; call <kernels::Fp2>::add
  %516 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s527.0, i64 noundef %s527.1, i64 noundef %s529.0, i64 noundef %s529.1)
; call <kernels::Fp2>::add
  %517 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s517.0, i64 noundef %s517.1, i64 noundef %s519.0, i64 noundef %s519.1)
  %s532.1 = extractvalue { i64, i64 } %516, 1
  %s532.0 = extractvalue { i64, i64 } %516, 0
  %s533.0 = extractvalue { i64, i64 } %517, 0
  %s533.1 = extractvalue { i64, i64 } %517, 1
; call <kernels::Fp2>::mul
  %518 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s532.0, i64 noundef %s532.1, i64 noundef %s533.0, i64 noundef %s533.1)
  %s534.0 = extractvalue { i64, i64 } %518, 0
  %s534.1 = extractvalue { i64, i64 } %518, 1
; call <kernels::Fp2>::sub
  %519 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s534.0, i64 noundef %s534.1, i64 noundef %s530.0, i64 noundef %s530.1)
  %s535.0 = extractvalue { i64, i64 } %519, 0
  %s535.1 = extractvalue { i64, i64 } %519, 1
; call <kernels::Fp2>::sub
  %520 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s535.0, i64 noundef %s535.1, i64 noundef %s531.0, i64 noundef %s531.1)
  %s536.0 = extractvalue { i64, i64 } %520, 0
  %s536.1 = extractvalue { i64, i64 } %520, 1
; call <kernels::Fp2>::mul
  %521 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s530.0, i64 noundef %s530.1, i64 noundef %s524.0, i64 noundef %s524.1)
  %s537.0 = extractvalue { i64, i64 } %521, 0
  %s537.1 = extractvalue { i64, i64 } %521, 1
; call <kernels::Fp2>::mul
  %522 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s530.0, i64 noundef %s530.1, i64 noundef %s526.0, i64 noundef %s526.1)
; call <kernels::Fp2>::mul
  %523 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s536.0, i64 noundef %s536.1, i64 noundef %s524.0, i64 noundef %s524.1)
  %s538.1 = extractvalue { i64, i64 } %522, 1
  %s538.0 = extractvalue { i64, i64 } %522, 0
  %s539.0 = extractvalue { i64, i64 } %523, 0
  %s539.1 = extractvalue { i64, i64 } %523, 1
; call <kernels::Fp2>::add
  %524 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s538.0, i64 noundef %s538.1, i64 noundef %s539.0, i64 noundef %s539.1)
  %s540.0 = extractvalue { i64, i64 } %524, 0
  %s540.1 = extractvalue { i64, i64 } %524, 1
; call <kernels::Fp2>::mul
  %525 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s536.0, i64 noundef %s536.1, i64 noundef %s526.0, i64 noundef %s526.1)
; call <kernels::Fp2>::mul
  %526 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s531.0, i64 noundef %s531.1, i64 noundef %s524.0, i64 noundef %s524.1)
  %s541.1 = extractvalue { i64, i64 } %525, 1
  %s541.0 = extractvalue { i64, i64 } %525, 0
  %s542.0 = extractvalue { i64, i64 } %526, 0
  %s542.1 = extractvalue { i64, i64 } %526, 1
; call <kernels::Fp2>::add
  %527 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s541.0, i64 noundef %s541.1, i64 noundef %s542.0, i64 noundef %s542.1)
  %s543.0 = extractvalue { i64, i64 } %527, 0
  %s543.1 = extractvalue { i64, i64 } %527, 1
; call <kernels::Fp2>::mul
  %528 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s531.0, i64 noundef %s531.1, i64 noundef %s526.0, i64 noundef %s526.1)
  %s544.0 = extractvalue { i64, i64 } %528, 0
  %s544.1 = extractvalue { i64, i64 } %528, 1
; call <kernels::Fp2>::add
  %529 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s517.0, i64 noundef %s517.1, i64 noundef %s524.0, i64 noundef %s524.1)
; call <kernels::Fp2>::add
  %530 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s519.0, i64 noundef %s519.1, i64 noundef %s526.0, i64 noundef %s526.1)
  %s545.1 = extractvalue { i64, i64 } %529, 1
  %s545.0 = extractvalue { i64, i64 } %529, 0
; call <kernels::Fp2>::sub
  %531 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s537.0, i64 noundef %s537.1, i64 noundef %s545.0, i64 noundef %s545.1)
  %s546.1 = extractvalue { i64, i64 } %530, 1
  %s546.0 = extractvalue { i64, i64 } %530, 0
  %s547.0 = extractvalue { i64, i64 } %531, 0
  %s547.1 = extractvalue { i64, i64 } %531, 1
; call <kernels::Fp2>::sub
  %532 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s540.0, i64 noundef %s540.1, i64 noundef %s546.0, i64 noundef %s546.1)
  %s548.0 = extractvalue { i64, i64 } %532, 0
  %s548.1 = extractvalue { i64, i64 } %532, 1
  %_0.i131 = getelementptr inbounds nuw i8, ptr %params, i64 992
  %s549.0 = load i64, ptr %_0.i131, align 8, !noundef !3
  %533 = getelementptr inbounds nuw i8, ptr %params, i64 1000
  %s549.1 = load i64, ptr %533, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %534 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s547.0, i64 noundef %s547.1, i64 noundef %s549.0, i64 noundef %s549.1)
  %s550.0 = extractvalue { i64, i64 } %534, 0
  %s550.1 = extractvalue { i64, i64 } %534, 1
; call <kernels::Fp2>::mul
  %535 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s548.0, i64 noundef %s548.1, i64 noundef %s549.0, i64 noundef %s549.1)
  %s551.0 = extractvalue { i64, i64 } %535, 0
  %s551.1 = extractvalue { i64, i64 } %535, 1
; call <kernels::Fp2>::mul
  %536 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s543.0, i64 noundef %s543.1, i64 noundef %s549.0, i64 noundef %s549.1)
  %s552.0 = extractvalue { i64, i64 } %536, 0
  %s552.1 = extractvalue { i64, i64 } %536, 1
; call <kernels::Fp2>::mul
  %537 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s544.0, i64 noundef %s544.1, i64 noundef %s549.0, i64 noundef %s549.1)
  %s553.0 = extractvalue { i64, i64 } %537, 0
  %s553.1 = extractvalue { i64, i64 } %537, 1
; call <kernels::Fp2>::add
  %538 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s506.0, i64 noundef %s506.1, i64 noundef %s550.0, i64 noundef %s550.1)
  %s554.0 = extractvalue { i64, i64 } %538, 0
  %s554.1 = extractvalue { i64, i64 } %538, 1
; call <kernels::Fp2>::add
  %539 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s507.0, i64 noundef %s507.1, i64 noundef %s551.0, i64 noundef %s551.1)
  %s555.0 = extractvalue { i64, i64 } %539, 0
  %s555.1 = extractvalue { i64, i64 } %539, 1
; call <kernels::Fp2>::add
  %540 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s508.0, i64 noundef %s508.1, i64 noundef %s552.0, i64 noundef %s552.1)
  %s556.0 = extractvalue { i64, i64 } %540, 0
  %s556.1 = extractvalue { i64, i64 } %540, 1
; call <kernels::Fp2>::add
  %541 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s509.0, i64 noundef %s509.1, i64 noundef %s553.0, i64 noundef %s553.1)
  %s557.0 = extractvalue { i64, i64 } %541, 0
  %s557.1 = extractvalue { i64, i64 } %541, 1
  %_0.i130 = getelementptr inbounds nuw i8, ptr %params, i64 1008
  %s558.0 = load i64, ptr %_0.i130, align 8, !noundef !3
  %542 = getelementptr inbounds nuw i8, ptr %params, i64 1016
  %s558.1 = load i64, ptr %542, align 8, !noundef !3
  %_0.i129 = getelementptr inbounds nuw i8, ptr %raw, i64 704
  %s559.0 = load i64, ptr %_0.i129, align 8, !noundef !3
  %543 = getelementptr inbounds nuw i8, ptr %raw, i64 712
  %s559.1 = load i64, ptr %543, align 8, !noundef !3
  %_0.i128 = getelementptr inbounds nuw i8, ptr %raw, i64 720
  %s560.0 = load i64, ptr %_0.i128, align 8, !noundef !3
  %544 = getelementptr inbounds nuw i8, ptr %raw, i64 728
  %s560.1 = load i64, ptr %544, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %545 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s560.0, i64 noundef %s560.1, i64 noundef %s559.0, i64 noundef %s559.1)
  %s561.0 = extractvalue { i64, i64 } %545, 0
  %s561.1 = extractvalue { i64, i64 } %545, 1
  %_0.i127 = getelementptr inbounds nuw i8, ptr %params, i64 1024
  %s562.0 = load i64, ptr %_0.i127, align 8, !noundef !3
  %546 = getelementptr inbounds nuw i8, ptr %params, i64 1032
  %s562.1 = load i64, ptr %546, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %547 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s559.0, i64 noundef %s559.1, i64 noundef %s562.0, i64 noundef %s562.1)
; call <kernels::Fp2>::mul
  %548 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s561.0, i64 noundef %s561.1, i64 noundef %s562.0, i64 noundef %s562.1)
  %s563.1 = extractvalue { i64, i64 } %547, 1
  %s563.0 = extractvalue { i64, i64 } %547, 0
; call <kernels::Fp2>::add
  %549 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s471.0, i64 noundef %s471.1, i64 noundef %s563.0, i64 noundef %s563.1)
  %s564.1 = extractvalue { i64, i64 } %548, 1
  %s564.0 = extractvalue { i64, i64 } %548, 0
  %s565.0 = extractvalue { i64, i64 } %549, 0
  %s565.1 = extractvalue { i64, i64 } %549, 1
; call <kernels::Fp2>::add
  %550 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s472.0, i64 noundef %s472.1, i64 noundef %s564.0, i64 noundef %s564.1)
  %s566.0 = extractvalue { i64, i64 } %550, 0
  %s566.1 = extractvalue { i64, i64 } %550, 1
  %_0.i271 = getelementptr inbounds nuw i8, ptr %bases, i64 128
  %s567 = load i64, ptr %_0.i271, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %551 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s559.0, i64 noundef %s559.1, i64 noundef %s567)
; call <kernels::Fp2>::mul_base
  %552 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s561.0, i64 noundef %s561.1, i64 noundef %s567)
  %s568.1 = extractvalue { i64, i64 } %551, 1
  %s568.0 = extractvalue { i64, i64 } %551, 0
  %s569.0 = extractvalue { i64, i64 } %552, 0
  %s569.1 = extractvalue { i64, i64 } %552, 1
; call <kernels::Fp2>::sub
  %553 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s558.0, i64 noundef %s558.1, i64 noundef %s568.0, i64 noundef %s568.1)
  %s570.0 = extractvalue { i64, i64 } %553, 0
  %s570.1 = extractvalue { i64, i64 } %553, 1
  %_0.i126 = getelementptr inbounds nuw i8, ptr %params, i64 1040
  %s571.0 = load i64, ptr %_0.i126, align 8, !noundef !3
  %554 = getelementptr inbounds nuw i8, ptr %params, i64 1048
  %s571.1 = load i64, ptr %554, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %555 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s571.0, i64 noundef %s571.1, i64 noundef %s569.0, i64 noundef %s569.1)
  %s572.0 = extractvalue { i64, i64 } %555, 0
  %s572.1 = extractvalue { i64, i64 } %555, 1
  %_0.i125 = getelementptr inbounds nuw i8, ptr %params, i64 1056
  %s573.0 = load i64, ptr %_0.i125, align 8, !noundef !3
  %556 = getelementptr inbounds nuw i8, ptr %params, i64 1064
  %s573.1 = load i64, ptr %556, align 8, !noundef !3
  %_0.i124 = getelementptr inbounds nuw i8, ptr %raw, i64 736
  %s574.0 = load i64, ptr %_0.i124, align 8, !noundef !3
  %557 = getelementptr inbounds nuw i8, ptr %raw, i64 744
  %s574.1 = load i64, ptr %557, align 8, !noundef !3
  %_0.i123 = getelementptr inbounds nuw i8, ptr %raw, i64 752
  %s575.0 = load i64, ptr %_0.i123, align 8, !noundef !3
  %558 = getelementptr inbounds nuw i8, ptr %raw, i64 760
  %s575.1 = load i64, ptr %558, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %559 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s575.0, i64 noundef %s575.1, i64 noundef %s574.0, i64 noundef %s574.1)
  %s576.0 = extractvalue { i64, i64 } %559, 0
  %s576.1 = extractvalue { i64, i64 } %559, 1
  %_0.i122 = getelementptr inbounds nuw i8, ptr %params, i64 1072
  %s577.0 = load i64, ptr %_0.i122, align 8, !noundef !3
  %560 = getelementptr inbounds nuw i8, ptr %params, i64 1080
  %s577.1 = load i64, ptr %560, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %561 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s574.0, i64 noundef %s574.1, i64 noundef %s577.0, i64 noundef %s577.1)
; call <kernels::Fp2>::mul
  %562 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s576.0, i64 noundef %s576.1, i64 noundef %s577.0, i64 noundef %s577.1)
  %s578.1 = extractvalue { i64, i64 } %561, 1
  %s578.0 = extractvalue { i64, i64 } %561, 0
; call <kernels::Fp2>::add
  %563 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s565.0, i64 noundef %s565.1, i64 noundef %s578.0, i64 noundef %s578.1)
  %s579.1 = extractvalue { i64, i64 } %562, 1
  %s579.0 = extractvalue { i64, i64 } %562, 0
  %s580.0 = extractvalue { i64, i64 } %563, 0
  %s580.1 = extractvalue { i64, i64 } %563, 1
; call <kernels::Fp2>::add
  %564 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s566.0, i64 noundef %s566.1, i64 noundef %s579.0, i64 noundef %s579.1)
  %s581.0 = extractvalue { i64, i64 } %564, 0
  %s581.1 = extractvalue { i64, i64 } %564, 1
  %_0.i270 = getelementptr inbounds nuw i8, ptr %bases, i64 136
  %s582 = load i64, ptr %_0.i270, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %565 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s574.0, i64 noundef %s574.1, i64 noundef %s582)
; call <kernels::Fp2>::mul_base
  %566 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s576.0, i64 noundef %s576.1, i64 noundef %s582)
  %s583.1 = extractvalue { i64, i64 } %565, 1
  %s583.0 = extractvalue { i64, i64 } %565, 0
  %s584.0 = extractvalue { i64, i64 } %566, 0
  %s584.1 = extractvalue { i64, i64 } %566, 1
; call <kernels::Fp2>::sub
  %567 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s573.0, i64 noundef %s573.1, i64 noundef %s583.0, i64 noundef %s583.1)
  %s585.0 = extractvalue { i64, i64 } %567, 0
  %s585.1 = extractvalue { i64, i64 } %567, 1
  %_0.i121 = getelementptr inbounds nuw i8, ptr %params, i64 1088
  %s586.0 = load i64, ptr %_0.i121, align 8, !noundef !3
  %568 = getelementptr inbounds nuw i8, ptr %params, i64 1096
  %s586.1 = load i64, ptr %568, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %569 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s586.0, i64 noundef %s586.1, i64 noundef %s584.0, i64 noundef %s584.1)
  %s587.0 = extractvalue { i64, i64 } %569, 0
  %s587.1 = extractvalue { i64, i64 } %569, 1
  %_0.i120 = getelementptr inbounds nuw i8, ptr %raw, i64 1600
  %s588.0 = load i64, ptr %_0.i120, align 8, !noundef !3
  %570 = getelementptr inbounds nuw i8, ptr %raw, i64 1608
  %s588.1 = load i64, ptr %570, align 8, !noundef !3
  %_0.i119 = getelementptr inbounds nuw i8, ptr %raw, i64 1616
  %s589.0 = load i64, ptr %_0.i119, align 8, !noundef !3
  %571 = getelementptr inbounds nuw i8, ptr %raw, i64 1624
  %s589.1 = load i64, ptr %571, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %572 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s589.0, i64 noundef %s589.1, i64 noundef %s588.0, i64 noundef %s588.1)
  %s590.0 = extractvalue { i64, i64 } %572, 0
  %s590.1 = extractvalue { i64, i64 } %572, 1
; call <kernels::Fp2>::mul
  %573 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s588.0, i64 noundef %s588.1, i64 noundef %s570.0, i64 noundef %s570.1)
  %s591.0 = extractvalue { i64, i64 } %573, 0
  %s591.1 = extractvalue { i64, i64 } %573, 1
; call <kernels::Fp2>::mul
  %574 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s590.0, i64 noundef %s590.1, i64 noundef %s572.0, i64 noundef %s572.1)
  %s592.0 = extractvalue { i64, i64 } %574, 0
  %s592.1 = extractvalue { i64, i64 } %574, 1
; call <kernels::Fp2>::add
  %575 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s588.0, i64 noundef %s588.1, i64 noundef %s590.0, i64 noundef %s590.1)
; call <kernels::Fp2>::add
  %576 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s570.0, i64 noundef %s570.1, i64 noundef %s572.0, i64 noundef %s572.1)
  %s593.1 = extractvalue { i64, i64 } %575, 1
  %s593.0 = extractvalue { i64, i64 } %575, 0
  %s594.0 = extractvalue { i64, i64 } %576, 0
  %s594.1 = extractvalue { i64, i64 } %576, 1
; call <kernels::Fp2>::mul
  %577 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s593.0, i64 noundef %s593.1, i64 noundef %s594.0, i64 noundef %s594.1)
  %s595.0 = extractvalue { i64, i64 } %577, 0
  %s595.1 = extractvalue { i64, i64 } %577, 1
; call <kernels::Fp2>::sub
  %578 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s595.0, i64 noundef %s595.1, i64 noundef %s591.0, i64 noundef %s591.1)
  %s596.0 = extractvalue { i64, i64 } %578, 0
  %s596.1 = extractvalue { i64, i64 } %578, 1
; call <kernels::Fp2>::sub
  %579 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s596.0, i64 noundef %s596.1, i64 noundef %s592.0, i64 noundef %s592.1)
  %s597.0 = extractvalue { i64, i64 } %579, 0
  %s597.1 = extractvalue { i64, i64 } %579, 1
; call <kernels::Fp2>::mul
  %580 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s591.0, i64 noundef %s591.1, i64 noundef %s585.0, i64 noundef %s585.1)
  %s598.0 = extractvalue { i64, i64 } %580, 0
  %s598.1 = extractvalue { i64, i64 } %580, 1
; call <kernels::Fp2>::mul
  %581 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s591.0, i64 noundef %s591.1, i64 noundef %s587.0, i64 noundef %s587.1)
; call <kernels::Fp2>::mul
  %582 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s597.0, i64 noundef %s597.1, i64 noundef %s585.0, i64 noundef %s585.1)
  %s599.1 = extractvalue { i64, i64 } %581, 1
  %s599.0 = extractvalue { i64, i64 } %581, 0
  %s600.0 = extractvalue { i64, i64 } %582, 0
  %s600.1 = extractvalue { i64, i64 } %582, 1
; call <kernels::Fp2>::add
  %583 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s599.0, i64 noundef %s599.1, i64 noundef %s600.0, i64 noundef %s600.1)
  %s601.0 = extractvalue { i64, i64 } %583, 0
  %s601.1 = extractvalue { i64, i64 } %583, 1
; call <kernels::Fp2>::mul
  %584 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s597.0, i64 noundef %s597.1, i64 noundef %s587.0, i64 noundef %s587.1)
; call <kernels::Fp2>::mul
  %585 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s592.0, i64 noundef %s592.1, i64 noundef %s585.0, i64 noundef %s585.1)
  %s602.1 = extractvalue { i64, i64 } %584, 1
  %s602.0 = extractvalue { i64, i64 } %584, 0
  %s603.0 = extractvalue { i64, i64 } %585, 0
  %s603.1 = extractvalue { i64, i64 } %585, 1
; call <kernels::Fp2>::add
  %586 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s602.0, i64 noundef %s602.1, i64 noundef %s603.0, i64 noundef %s603.1)
  %s604.0 = extractvalue { i64, i64 } %586, 0
  %s604.1 = extractvalue { i64, i64 } %586, 1
; call <kernels::Fp2>::mul
  %587 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s592.0, i64 noundef %s592.1, i64 noundef %s587.0, i64 noundef %s587.1)
  %s605.0 = extractvalue { i64, i64 } %587, 0
  %s605.1 = extractvalue { i64, i64 } %587, 1
; call <kernels::Fp2>::add
  %588 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s570.0, i64 noundef %s570.1, i64 noundef %s585.0, i64 noundef %s585.1)
; call <kernels::Fp2>::add
  %589 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s572.0, i64 noundef %s572.1, i64 noundef %s587.0, i64 noundef %s587.1)
  %s606.1 = extractvalue { i64, i64 } %588, 1
  %s606.0 = extractvalue { i64, i64 } %588, 0
; call <kernels::Fp2>::sub
  %590 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s598.0, i64 noundef %s598.1, i64 noundef %s606.0, i64 noundef %s606.1)
  %s607.1 = extractvalue { i64, i64 } %589, 1
  %s607.0 = extractvalue { i64, i64 } %589, 0
  %s608.0 = extractvalue { i64, i64 } %590, 0
  %s608.1 = extractvalue { i64, i64 } %590, 1
; call <kernels::Fp2>::sub
  %591 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s601.0, i64 noundef %s601.1, i64 noundef %s607.0, i64 noundef %s607.1)
  %s609.0 = extractvalue { i64, i64 } %591, 0
  %s609.1 = extractvalue { i64, i64 } %591, 1
  %_0.i118 = getelementptr inbounds nuw i8, ptr %params, i64 1104
  %s610.0 = load i64, ptr %_0.i118, align 8, !noundef !3
  %592 = getelementptr inbounds nuw i8, ptr %params, i64 1112
  %s610.1 = load i64, ptr %592, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %593 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s608.0, i64 noundef %s608.1, i64 noundef %s610.0, i64 noundef %s610.1)
  %s611.0 = extractvalue { i64, i64 } %593, 0
  %s611.1 = extractvalue { i64, i64 } %593, 1
; call <kernels::Fp2>::mul
  %594 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s609.0, i64 noundef %s609.1, i64 noundef %s610.0, i64 noundef %s610.1)
  %s612.0 = extractvalue { i64, i64 } %594, 0
  %s612.1 = extractvalue { i64, i64 } %594, 1
; call <kernels::Fp2>::mul
  %595 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s604.0, i64 noundef %s604.1, i64 noundef %s610.0, i64 noundef %s610.1)
  %s613.0 = extractvalue { i64, i64 } %595, 0
  %s613.1 = extractvalue { i64, i64 } %595, 1
; call <kernels::Fp2>::mul
  %596 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s605.0, i64 noundef %s605.1, i64 noundef %s610.0, i64 noundef %s610.1)
  %s614.0 = extractvalue { i64, i64 } %596, 0
  %s614.1 = extractvalue { i64, i64 } %596, 1
; call <kernels::Fp2>::add
  %597 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s554.0, i64 noundef %s554.1, i64 noundef %s611.0, i64 noundef %s611.1)
  %s615.0 = extractvalue { i64, i64 } %597, 0
  %s615.1 = extractvalue { i64, i64 } %597, 1
; call <kernels::Fp2>::add
  %598 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s555.0, i64 noundef %s555.1, i64 noundef %s612.0, i64 noundef %s612.1)
  %s616.0 = extractvalue { i64, i64 } %598, 0
  %s616.1 = extractvalue { i64, i64 } %598, 1
; call <kernels::Fp2>::add
  %599 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s556.0, i64 noundef %s556.1, i64 noundef %s613.0, i64 noundef %s613.1)
  %s617.0 = extractvalue { i64, i64 } %599, 0
  %s617.1 = extractvalue { i64, i64 } %599, 1
; call <kernels::Fp2>::add
  %600 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s557.0, i64 noundef %s557.1, i64 noundef %s614.0, i64 noundef %s614.1)
  %s618.0 = extractvalue { i64, i64 } %600, 0
  %s618.1 = extractvalue { i64, i64 } %600, 1
  %_0.i117 = getelementptr inbounds nuw i8, ptr %params, i64 1120
  %s619.0 = load i64, ptr %_0.i117, align 8, !noundef !3
  %601 = getelementptr inbounds nuw i8, ptr %params, i64 1128
  %s619.1 = load i64, ptr %601, align 8, !noundef !3
  %_0.i269 = getelementptr inbounds nuw i8, ptr %bases, i64 144
  %s620 = load i64, ptr %_0.i269, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %602 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s84.0, i64 noundef %s84.1, i64 noundef %s620)
; call <kernels::Fp2>::mul_base
  %603 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s86.0, i64 noundef %s86.1, i64 noundef %s620)
  %s621.1 = extractvalue { i64, i64 } %602, 1
  %s621.0 = extractvalue { i64, i64 } %602, 0
  %s622.0 = extractvalue { i64, i64 } %603, 0
  %s622.1 = extractvalue { i64, i64 } %603, 1
; call <kernels::Fp2>::sub
  %604 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s619.0, i64 noundef %s619.1, i64 noundef %s621.0, i64 noundef %s621.1)
  %s623.0 = extractvalue { i64, i64 } %604, 0
  %s623.1 = extractvalue { i64, i64 } %604, 1
  %_0.i116 = getelementptr inbounds nuw i8, ptr %params, i64 1136
  %s624.0 = load i64, ptr %_0.i116, align 8, !noundef !3
  %605 = getelementptr inbounds nuw i8, ptr %params, i64 1144
  %s624.1 = load i64, ptr %605, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %606 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s624.0, i64 noundef %s624.1, i64 noundef %s622.0, i64 noundef %s622.1)
  %s625.0 = extractvalue { i64, i64 } %606, 0
  %s625.1 = extractvalue { i64, i64 } %606, 1
  %_0.i115 = getelementptr inbounds nuw i8, ptr %params, i64 1152
  %s626.0 = load i64, ptr %_0.i115, align 8, !noundef !3
  %607 = getelementptr inbounds nuw i8, ptr %params, i64 1160
  %s626.1 = load i64, ptr %607, align 8, !noundef !3
  %_0.i268 = getelementptr inbounds nuw i8, ptr %bases, i64 152
  %s627 = load i64, ptr %_0.i268, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %608 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s84.0, i64 noundef %s84.1, i64 noundef %s627)
; call <kernels::Fp2>::mul_base
  %609 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s86.0, i64 noundef %s86.1, i64 noundef %s627)
  %s628.1 = extractvalue { i64, i64 } %608, 1
  %s628.0 = extractvalue { i64, i64 } %608, 0
  %s629.0 = extractvalue { i64, i64 } %609, 0
  %s629.1 = extractvalue { i64, i64 } %609, 1
; call <kernels::Fp2>::sub
  %610 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s626.0, i64 noundef %s626.1, i64 noundef %s628.0, i64 noundef %s628.1)
  %s630.0 = extractvalue { i64, i64 } %610, 0
  %s630.1 = extractvalue { i64, i64 } %610, 1
  %_0.i114 = getelementptr inbounds nuw i8, ptr %params, i64 1168
  %s631.0 = load i64, ptr %_0.i114, align 8, !noundef !3
  %611 = getelementptr inbounds nuw i8, ptr %params, i64 1176
  %s631.1 = load i64, ptr %611, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %612 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s631.0, i64 noundef %s631.1, i64 noundef %s629.0, i64 noundef %s629.1)
  %s632.0 = extractvalue { i64, i64 } %612, 0
  %s632.1 = extractvalue { i64, i64 } %612, 1
  %_0.i113 = getelementptr inbounds nuw i8, ptr %raw, i64 1632
  %s633.0 = load i64, ptr %_0.i113, align 8, !noundef !3
  %613 = getelementptr inbounds nuw i8, ptr %raw, i64 1640
  %s633.1 = load i64, ptr %613, align 8, !noundef !3
  %_0.i112 = getelementptr inbounds nuw i8, ptr %raw, i64 1648
  %s634.0 = load i64, ptr %_0.i112, align 8, !noundef !3
  %614 = getelementptr inbounds nuw i8, ptr %raw, i64 1656
  %s634.1 = load i64, ptr %614, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %615 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s634.0, i64 noundef %s634.1, i64 noundef %s633.0, i64 noundef %s633.1)
  %s635.0 = extractvalue { i64, i64 } %615, 0
  %s635.1 = extractvalue { i64, i64 } %615, 1
; call <kernels::Fp2>::mul
  %616 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s633.0, i64 noundef %s633.1, i64 noundef %s623.0, i64 noundef %s623.1)
  %s636.0 = extractvalue { i64, i64 } %616, 0
  %s636.1 = extractvalue { i64, i64 } %616, 1
; call <kernels::Fp2>::mul
  %617 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s635.0, i64 noundef %s635.1, i64 noundef %s625.0, i64 noundef %s625.1)
  %s637.0 = extractvalue { i64, i64 } %617, 0
  %s637.1 = extractvalue { i64, i64 } %617, 1
; call <kernels::Fp2>::add
  %618 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s633.0, i64 noundef %s633.1, i64 noundef %s635.0, i64 noundef %s635.1)
; call <kernels::Fp2>::add
  %619 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s623.0, i64 noundef %s623.1, i64 noundef %s625.0, i64 noundef %s625.1)
  %s638.1 = extractvalue { i64, i64 } %618, 1
  %s638.0 = extractvalue { i64, i64 } %618, 0
  %s639.0 = extractvalue { i64, i64 } %619, 0
  %s639.1 = extractvalue { i64, i64 } %619, 1
; call <kernels::Fp2>::mul
  %620 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s638.0, i64 noundef %s638.1, i64 noundef %s639.0, i64 noundef %s639.1)
  %s640.0 = extractvalue { i64, i64 } %620, 0
  %s640.1 = extractvalue { i64, i64 } %620, 1
; call <kernels::Fp2>::sub
  %621 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s640.0, i64 noundef %s640.1, i64 noundef %s636.0, i64 noundef %s636.1)
  %s641.0 = extractvalue { i64, i64 } %621, 0
  %s641.1 = extractvalue { i64, i64 } %621, 1
; call <kernels::Fp2>::sub
  %622 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s641.0, i64 noundef %s641.1, i64 noundef %s637.0, i64 noundef %s637.1)
  %s642.0 = extractvalue { i64, i64 } %622, 0
  %s642.1 = extractvalue { i64, i64 } %622, 1
; call <kernels::Fp2>::mul
  %623 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s636.0, i64 noundef %s636.1, i64 noundef %s630.0, i64 noundef %s630.1)
  %s643.0 = extractvalue { i64, i64 } %623, 0
  %s643.1 = extractvalue { i64, i64 } %623, 1
; call <kernels::Fp2>::mul
  %624 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s636.0, i64 noundef %s636.1, i64 noundef %s632.0, i64 noundef %s632.1)
; call <kernels::Fp2>::mul
  %625 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s642.0, i64 noundef %s642.1, i64 noundef %s630.0, i64 noundef %s630.1)
  %s644.1 = extractvalue { i64, i64 } %624, 1
  %s644.0 = extractvalue { i64, i64 } %624, 0
  %s645.0 = extractvalue { i64, i64 } %625, 0
  %s645.1 = extractvalue { i64, i64 } %625, 1
; call <kernels::Fp2>::add
  %626 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s644.0, i64 noundef %s644.1, i64 noundef %s645.0, i64 noundef %s645.1)
  %s646.0 = extractvalue { i64, i64 } %626, 0
  %s646.1 = extractvalue { i64, i64 } %626, 1
; call <kernels::Fp2>::mul
  %627 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s642.0, i64 noundef %s642.1, i64 noundef %s632.0, i64 noundef %s632.1)
; call <kernels::Fp2>::mul
  %628 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s637.0, i64 noundef %s637.1, i64 noundef %s630.0, i64 noundef %s630.1)
  %s647.1 = extractvalue { i64, i64 } %627, 1
  %s647.0 = extractvalue { i64, i64 } %627, 0
  %s648.0 = extractvalue { i64, i64 } %628, 0
  %s648.1 = extractvalue { i64, i64 } %628, 1
; call <kernels::Fp2>::add
  %629 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s647.0, i64 noundef %s647.1, i64 noundef %s648.0, i64 noundef %s648.1)
  %s649.0 = extractvalue { i64, i64 } %629, 0
  %s649.1 = extractvalue { i64, i64 } %629, 1
; call <kernels::Fp2>::mul
  %630 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s637.0, i64 noundef %s637.1, i64 noundef %s632.0, i64 noundef %s632.1)
  %s650.0 = extractvalue { i64, i64 } %630, 0
  %s650.1 = extractvalue { i64, i64 } %630, 1
; call <kernels::Fp2>::add
  %631 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s623.0, i64 noundef %s623.1, i64 noundef %s630.0, i64 noundef %s630.1)
; call <kernels::Fp2>::add
  %632 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s625.0, i64 noundef %s625.1, i64 noundef %s632.0, i64 noundef %s632.1)
  %s651.1 = extractvalue { i64, i64 } %631, 1
  %s651.0 = extractvalue { i64, i64 } %631, 0
; call <kernels::Fp2>::sub
  %633 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s643.0, i64 noundef %s643.1, i64 noundef %s651.0, i64 noundef %s651.1)
  %s652.1 = extractvalue { i64, i64 } %632, 1
  %s652.0 = extractvalue { i64, i64 } %632, 0
  %s653.0 = extractvalue { i64, i64 } %633, 0
  %s653.1 = extractvalue { i64, i64 } %633, 1
; call <kernels::Fp2>::sub
  %634 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s646.0, i64 noundef %s646.1, i64 noundef %s652.0, i64 noundef %s652.1)
  %s654.0 = extractvalue { i64, i64 } %634, 0
  %s654.1 = extractvalue { i64, i64 } %634, 1
  %_0.i111 = getelementptr inbounds nuw i8, ptr %params, i64 1184
  %s655.0 = load i64, ptr %_0.i111, align 8, !noundef !3
  %635 = getelementptr inbounds nuw i8, ptr %params, i64 1192
  %s655.1 = load i64, ptr %635, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %636 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s653.0, i64 noundef %s653.1, i64 noundef %s655.0, i64 noundef %s655.1)
  %s656.0 = extractvalue { i64, i64 } %636, 0
  %s656.1 = extractvalue { i64, i64 } %636, 1
; call <kernels::Fp2>::mul
  %637 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s654.0, i64 noundef %s654.1, i64 noundef %s655.0, i64 noundef %s655.1)
  %s657.0 = extractvalue { i64, i64 } %637, 0
  %s657.1 = extractvalue { i64, i64 } %637, 1
; call <kernels::Fp2>::mul
  %638 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s649.0, i64 noundef %s649.1, i64 noundef %s655.0, i64 noundef %s655.1)
  %s658.0 = extractvalue { i64, i64 } %638, 0
  %s658.1 = extractvalue { i64, i64 } %638, 1
; call <kernels::Fp2>::mul
  %639 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s650.0, i64 noundef %s650.1, i64 noundef %s655.0, i64 noundef %s655.1)
  %s659.0 = extractvalue { i64, i64 } %639, 0
  %s659.1 = extractvalue { i64, i64 } %639, 1
; call <kernels::Fp2>::add
  %640 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s615.0, i64 noundef %s615.1, i64 noundef %s656.0, i64 noundef %s656.1)
  %s660.0 = extractvalue { i64, i64 } %640, 0
  %s660.1 = extractvalue { i64, i64 } %640, 1
; call <kernels::Fp2>::add
  %641 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s616.0, i64 noundef %s616.1, i64 noundef %s657.0, i64 noundef %s657.1)
  %s661.0 = extractvalue { i64, i64 } %641, 0
  %s661.1 = extractvalue { i64, i64 } %641, 1
; call <kernels::Fp2>::add
  %642 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s617.0, i64 noundef %s617.1, i64 noundef %s658.0, i64 noundef %s658.1)
  %s662.0 = extractvalue { i64, i64 } %642, 0
  %s662.1 = extractvalue { i64, i64 } %642, 1
; call <kernels::Fp2>::add
  %643 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s618.0, i64 noundef %s618.1, i64 noundef %s659.0, i64 noundef %s659.1)
  %s663.0 = extractvalue { i64, i64 } %643, 0
  %s663.1 = extractvalue { i64, i64 } %643, 1
  %_0.i110 = getelementptr inbounds nuw i8, ptr %params, i64 1200
  %s664.0 = load i64, ptr %_0.i110, align 8, !noundef !3
  %644 = getelementptr inbounds nuw i8, ptr %params, i64 1208
  %s664.1 = load i64, ptr %644, align 8, !noundef !3
  %_0.i109 = getelementptr inbounds nuw i8, ptr %raw, i64 800
  %s665.0 = load i64, ptr %_0.i109, align 8, !noundef !3
  %645 = getelementptr inbounds nuw i8, ptr %raw, i64 808
  %s665.1 = load i64, ptr %645, align 8, !noundef !3
  %_0.i108 = getelementptr inbounds nuw i8, ptr %raw, i64 816
  %s666.0 = load i64, ptr %_0.i108, align 8, !noundef !3
  %646 = getelementptr inbounds nuw i8, ptr %raw, i64 824
  %s666.1 = load i64, ptr %646, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %647 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s666.0, i64 noundef %s666.1, i64 noundef %s665.0, i64 noundef %s665.1)
  %s667.0 = extractvalue { i64, i64 } %647, 0
  %s667.1 = extractvalue { i64, i64 } %647, 1
  %_0.i107 = getelementptr inbounds nuw i8, ptr %params, i64 1216
  %s668.0 = load i64, ptr %_0.i107, align 8, !noundef !3
  %648 = getelementptr inbounds nuw i8, ptr %params, i64 1224
  %s668.1 = load i64, ptr %648, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %649 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s665.0, i64 noundef %s665.1, i64 noundef %s668.0, i64 noundef %s668.1)
; call <kernels::Fp2>::mul
  %650 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s667.0, i64 noundef %s667.1, i64 noundef %s668.0, i64 noundef %s668.1)
  %s669.1 = extractvalue { i64, i64 } %649, 1
  %s669.0 = extractvalue { i64, i64 } %649, 0
; call <kernels::Fp2>::add
  %651 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s580.0, i64 noundef %s580.1, i64 noundef %s669.0, i64 noundef %s669.1)
  %s670.1 = extractvalue { i64, i64 } %650, 1
  %s670.0 = extractvalue { i64, i64 } %650, 0
  %s671.0 = extractvalue { i64, i64 } %651, 0
  %s671.1 = extractvalue { i64, i64 } %651, 1
; call <kernels::Fp2>::add
  %652 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s581.0, i64 noundef %s581.1, i64 noundef %s670.0, i64 noundef %s670.1)
  %s672.0 = extractvalue { i64, i64 } %652, 0
  %s672.1 = extractvalue { i64, i64 } %652, 1
  %_0.i267 = getelementptr inbounds nuw i8, ptr %bases, i64 160
  %s673 = load i64, ptr %_0.i267, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %653 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s665.0, i64 noundef %s665.1, i64 noundef %s673)
; call <kernels::Fp2>::mul_base
  %654 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s667.0, i64 noundef %s667.1, i64 noundef %s673)
  %s674.1 = extractvalue { i64, i64 } %653, 1
  %s674.0 = extractvalue { i64, i64 } %653, 0
  %s675.0 = extractvalue { i64, i64 } %654, 0
  %s675.1 = extractvalue { i64, i64 } %654, 1
; call <kernels::Fp2>::sub
  %655 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s664.0, i64 noundef %s664.1, i64 noundef %s674.0, i64 noundef %s674.1)
  %s676.0 = extractvalue { i64, i64 } %655, 0
  %s676.1 = extractvalue { i64, i64 } %655, 1
  %_0.i106 = getelementptr inbounds nuw i8, ptr %params, i64 1232
  %s677.0 = load i64, ptr %_0.i106, align 8, !noundef !3
  %656 = getelementptr inbounds nuw i8, ptr %params, i64 1240
  %s677.1 = load i64, ptr %656, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %657 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s677.0, i64 noundef %s677.1, i64 noundef %s675.0, i64 noundef %s675.1)
  %s678.0 = extractvalue { i64, i64 } %657, 0
  %s678.1 = extractvalue { i64, i64 } %657, 1
  %_0.i105 = getelementptr inbounds nuw i8, ptr %params, i64 1248
  %s679.0 = load i64, ptr %_0.i105, align 8, !noundef !3
  %658 = getelementptr inbounds nuw i8, ptr %params, i64 1256
  %s679.1 = load i64, ptr %658, align 8, !noundef !3
  %_0.i104 = getelementptr inbounds nuw i8, ptr %raw, i64 832
  %s680.0 = load i64, ptr %_0.i104, align 8, !noundef !3
  %659 = getelementptr inbounds nuw i8, ptr %raw, i64 840
  %s680.1 = load i64, ptr %659, align 8, !noundef !3
  %_0.i103 = getelementptr inbounds nuw i8, ptr %raw, i64 848
  %s681.0 = load i64, ptr %_0.i103, align 8, !noundef !3
  %660 = getelementptr inbounds nuw i8, ptr %raw, i64 856
  %s681.1 = load i64, ptr %660, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %661 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s681.0, i64 noundef %s681.1, i64 noundef %s680.0, i64 noundef %s680.1)
  %s682.0 = extractvalue { i64, i64 } %661, 0
  %s682.1 = extractvalue { i64, i64 } %661, 1
  %_0.i102 = getelementptr inbounds nuw i8, ptr %params, i64 1264
  %s683.0 = load i64, ptr %_0.i102, align 8, !noundef !3
  %662 = getelementptr inbounds nuw i8, ptr %params, i64 1272
  %s683.1 = load i64, ptr %662, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %663 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s680.0, i64 noundef %s680.1, i64 noundef %s683.0, i64 noundef %s683.1)
; call <kernels::Fp2>::mul
  %664 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s682.0, i64 noundef %s682.1, i64 noundef %s683.0, i64 noundef %s683.1)
  %s684.1 = extractvalue { i64, i64 } %663, 1
  %s684.0 = extractvalue { i64, i64 } %663, 0
; call <kernels::Fp2>::add
  %665 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s671.0, i64 noundef %s671.1, i64 noundef %s684.0, i64 noundef %s684.1)
  %s685.1 = extractvalue { i64, i64 } %664, 1
  %s685.0 = extractvalue { i64, i64 } %664, 0
  %s686.0 = extractvalue { i64, i64 } %665, 0
  %s686.1 = extractvalue { i64, i64 } %665, 1
; call <kernels::Fp2>::add
  %666 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s672.0, i64 noundef %s672.1, i64 noundef %s685.0, i64 noundef %s685.1)
  %s687.0 = extractvalue { i64, i64 } %666, 0
  %s687.1 = extractvalue { i64, i64 } %666, 1
  %_0.i266 = getelementptr inbounds nuw i8, ptr %bases, i64 168
  %s688 = load i64, ptr %_0.i266, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %667 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s680.0, i64 noundef %s680.1, i64 noundef %s688)
; call <kernels::Fp2>::mul_base
  %668 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s682.0, i64 noundef %s682.1, i64 noundef %s688)
  %s689.1 = extractvalue { i64, i64 } %667, 1
  %s689.0 = extractvalue { i64, i64 } %667, 0
  %s690.0 = extractvalue { i64, i64 } %668, 0
  %s690.1 = extractvalue { i64, i64 } %668, 1
; call <kernels::Fp2>::sub
  %669 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s679.0, i64 noundef %s679.1, i64 noundef %s689.0, i64 noundef %s689.1)
  %s691.0 = extractvalue { i64, i64 } %669, 0
  %s691.1 = extractvalue { i64, i64 } %669, 1
  %_0.i101 = getelementptr inbounds nuw i8, ptr %params, i64 1280
  %s692.0 = load i64, ptr %_0.i101, align 8, !noundef !3
  %670 = getelementptr inbounds nuw i8, ptr %params, i64 1288
  %s692.1 = load i64, ptr %670, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %671 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s692.0, i64 noundef %s692.1, i64 noundef %s690.0, i64 noundef %s690.1)
  %s693.0 = extractvalue { i64, i64 } %671, 0
  %s693.1 = extractvalue { i64, i64 } %671, 1
  %_0.i100 = getelementptr inbounds nuw i8, ptr %raw, i64 1664
  %s694.0 = load i64, ptr %_0.i100, align 8, !noundef !3
  %672 = getelementptr inbounds nuw i8, ptr %raw, i64 1672
  %s694.1 = load i64, ptr %672, align 8, !noundef !3
  %_0.i99 = getelementptr inbounds nuw i8, ptr %raw, i64 1680
  %s695.0 = load i64, ptr %_0.i99, align 8, !noundef !3
  %673 = getelementptr inbounds nuw i8, ptr %raw, i64 1688
  %s695.1 = load i64, ptr %673, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %674 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s695.0, i64 noundef %s695.1, i64 noundef %s694.0, i64 noundef %s694.1)
  %s696.0 = extractvalue { i64, i64 } %674, 0
  %s696.1 = extractvalue { i64, i64 } %674, 1
; call <kernels::Fp2>::mul
  %675 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s694.0, i64 noundef %s694.1, i64 noundef %s676.0, i64 noundef %s676.1)
  %s697.0 = extractvalue { i64, i64 } %675, 0
  %s697.1 = extractvalue { i64, i64 } %675, 1
; call <kernels::Fp2>::mul
  %676 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s696.0, i64 noundef %s696.1, i64 noundef %s678.0, i64 noundef %s678.1)
  %s698.0 = extractvalue { i64, i64 } %676, 0
  %s698.1 = extractvalue { i64, i64 } %676, 1
; call <kernels::Fp2>::add
  %677 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s694.0, i64 noundef %s694.1, i64 noundef %s696.0, i64 noundef %s696.1)
; call <kernels::Fp2>::add
  %678 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s676.0, i64 noundef %s676.1, i64 noundef %s678.0, i64 noundef %s678.1)
  %s699.1 = extractvalue { i64, i64 } %677, 1
  %s699.0 = extractvalue { i64, i64 } %677, 0
  %s700.0 = extractvalue { i64, i64 } %678, 0
  %s700.1 = extractvalue { i64, i64 } %678, 1
; call <kernels::Fp2>::mul
  %679 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s699.0, i64 noundef %s699.1, i64 noundef %s700.0, i64 noundef %s700.1)
  %s701.0 = extractvalue { i64, i64 } %679, 0
  %s701.1 = extractvalue { i64, i64 } %679, 1
; call <kernels::Fp2>::sub
  %680 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s701.0, i64 noundef %s701.1, i64 noundef %s697.0, i64 noundef %s697.1)
  %s702.0 = extractvalue { i64, i64 } %680, 0
  %s702.1 = extractvalue { i64, i64 } %680, 1
; call <kernels::Fp2>::sub
  %681 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s702.0, i64 noundef %s702.1, i64 noundef %s698.0, i64 noundef %s698.1)
  %s703.0 = extractvalue { i64, i64 } %681, 0
  %s703.1 = extractvalue { i64, i64 } %681, 1
; call <kernels::Fp2>::mul
  %682 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s697.0, i64 noundef %s697.1, i64 noundef %s691.0, i64 noundef %s691.1)
  %s704.0 = extractvalue { i64, i64 } %682, 0
  %s704.1 = extractvalue { i64, i64 } %682, 1
; call <kernels::Fp2>::mul
  %683 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s697.0, i64 noundef %s697.1, i64 noundef %s693.0, i64 noundef %s693.1)
; call <kernels::Fp2>::mul
  %684 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s703.0, i64 noundef %s703.1, i64 noundef %s691.0, i64 noundef %s691.1)
  %s705.1 = extractvalue { i64, i64 } %683, 1
  %s705.0 = extractvalue { i64, i64 } %683, 0
  %s706.0 = extractvalue { i64, i64 } %684, 0
  %s706.1 = extractvalue { i64, i64 } %684, 1
; call <kernels::Fp2>::add
  %685 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s705.0, i64 noundef %s705.1, i64 noundef %s706.0, i64 noundef %s706.1)
  %s707.0 = extractvalue { i64, i64 } %685, 0
  %s707.1 = extractvalue { i64, i64 } %685, 1
; call <kernels::Fp2>::mul
  %686 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s703.0, i64 noundef %s703.1, i64 noundef %s693.0, i64 noundef %s693.1)
; call <kernels::Fp2>::mul
  %687 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s698.0, i64 noundef %s698.1, i64 noundef %s691.0, i64 noundef %s691.1)
  %s708.1 = extractvalue { i64, i64 } %686, 1
  %s708.0 = extractvalue { i64, i64 } %686, 0
  %s709.0 = extractvalue { i64, i64 } %687, 0
  %s709.1 = extractvalue { i64, i64 } %687, 1
; call <kernels::Fp2>::add
  %688 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s708.0, i64 noundef %s708.1, i64 noundef %s709.0, i64 noundef %s709.1)
  %s710.0 = extractvalue { i64, i64 } %688, 0
  %s710.1 = extractvalue { i64, i64 } %688, 1
; call <kernels::Fp2>::mul
  %689 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s698.0, i64 noundef %s698.1, i64 noundef %s693.0, i64 noundef %s693.1)
  %s711.0 = extractvalue { i64, i64 } %689, 0
  %s711.1 = extractvalue { i64, i64 } %689, 1
; call <kernels::Fp2>::add
  %690 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s676.0, i64 noundef %s676.1, i64 noundef %s691.0, i64 noundef %s691.1)
; call <kernels::Fp2>::add
  %691 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s678.0, i64 noundef %s678.1, i64 noundef %s693.0, i64 noundef %s693.1)
  %s712.1 = extractvalue { i64, i64 } %690, 1
  %s712.0 = extractvalue { i64, i64 } %690, 0
; call <kernels::Fp2>::sub
  %692 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s704.0, i64 noundef %s704.1, i64 noundef %s712.0, i64 noundef %s712.1)
  %s713.1 = extractvalue { i64, i64 } %691, 1
  %s713.0 = extractvalue { i64, i64 } %691, 0
  %s714.0 = extractvalue { i64, i64 } %692, 0
  %s714.1 = extractvalue { i64, i64 } %692, 1
; call <kernels::Fp2>::sub
  %693 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s707.0, i64 noundef %s707.1, i64 noundef %s713.0, i64 noundef %s713.1)
  %s715.0 = extractvalue { i64, i64 } %693, 0
  %s715.1 = extractvalue { i64, i64 } %693, 1
  %_0.i98 = getelementptr inbounds nuw i8, ptr %params, i64 1296
  %s716.0 = load i64, ptr %_0.i98, align 8, !noundef !3
  %694 = getelementptr inbounds nuw i8, ptr %params, i64 1304
  %s716.1 = load i64, ptr %694, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %695 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s714.0, i64 noundef %s714.1, i64 noundef %s716.0, i64 noundef %s716.1)
  %s717.0 = extractvalue { i64, i64 } %695, 0
  %s717.1 = extractvalue { i64, i64 } %695, 1
; call <kernels::Fp2>::mul
  %696 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s715.0, i64 noundef %s715.1, i64 noundef %s716.0, i64 noundef %s716.1)
  %s718.0 = extractvalue { i64, i64 } %696, 0
  %s718.1 = extractvalue { i64, i64 } %696, 1
; call <kernels::Fp2>::mul
  %697 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s710.0, i64 noundef %s710.1, i64 noundef %s716.0, i64 noundef %s716.1)
  %s719.0 = extractvalue { i64, i64 } %697, 0
  %s719.1 = extractvalue { i64, i64 } %697, 1
; call <kernels::Fp2>::mul
  %698 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s711.0, i64 noundef %s711.1, i64 noundef %s716.0, i64 noundef %s716.1)
  %s720.0 = extractvalue { i64, i64 } %698, 0
  %s720.1 = extractvalue { i64, i64 } %698, 1
; call <kernels::Fp2>::add
  %699 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s660.0, i64 noundef %s660.1, i64 noundef %s717.0, i64 noundef %s717.1)
  %s721.0 = extractvalue { i64, i64 } %699, 0
  %s721.1 = extractvalue { i64, i64 } %699, 1
; call <kernels::Fp2>::add
  %700 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s661.0, i64 noundef %s661.1, i64 noundef %s718.0, i64 noundef %s718.1)
  %s722.0 = extractvalue { i64, i64 } %700, 0
  %s722.1 = extractvalue { i64, i64 } %700, 1
; call <kernels::Fp2>::add
  %701 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s662.0, i64 noundef %s662.1, i64 noundef %s719.0, i64 noundef %s719.1)
  %s723.0 = extractvalue { i64, i64 } %701, 0
  %s723.1 = extractvalue { i64, i64 } %701, 1
; call <kernels::Fp2>::add
  %702 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s663.0, i64 noundef %s663.1, i64 noundef %s720.0, i64 noundef %s720.1)
  %s724.0 = extractvalue { i64, i64 } %702, 0
  %s724.1 = extractvalue { i64, i64 } %702, 1
  %_0.i97 = getelementptr inbounds nuw i8, ptr %params, i64 1312
  %s725.0 = load i64, ptr %_0.i97, align 8, !noundef !3
  %703 = getelementptr inbounds nuw i8, ptr %params, i64 1320
  %s725.1 = load i64, ptr %703, align 8, !noundef !3
  %_0.i96 = getelementptr inbounds nuw i8, ptr %raw, i64 864
  %s726.0 = load i64, ptr %_0.i96, align 8, !noundef !3
  %704 = getelementptr inbounds nuw i8, ptr %raw, i64 872
  %s726.1 = load i64, ptr %704, align 8, !noundef !3
  %_0.i95 = getelementptr inbounds nuw i8, ptr %raw, i64 880
  %s727.0 = load i64, ptr %_0.i95, align 8, !noundef !3
  %705 = getelementptr inbounds nuw i8, ptr %raw, i64 888
  %s727.1 = load i64, ptr %705, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %706 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s727.0, i64 noundef %s727.1, i64 noundef %s726.0, i64 noundef %s726.1)
  %s728.0 = extractvalue { i64, i64 } %706, 0
  %s728.1 = extractvalue { i64, i64 } %706, 1
  %_0.i94 = getelementptr inbounds nuw i8, ptr %params, i64 1328
  %s729.0 = load i64, ptr %_0.i94, align 8, !noundef !3
  %707 = getelementptr inbounds nuw i8, ptr %params, i64 1336
  %s729.1 = load i64, ptr %707, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %708 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s726.0, i64 noundef %s726.1, i64 noundef %s729.0, i64 noundef %s729.1)
; call <kernels::Fp2>::mul
  %709 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s728.0, i64 noundef %s728.1, i64 noundef %s729.0, i64 noundef %s729.1)
  %s730.1 = extractvalue { i64, i64 } %708, 1
  %s730.0 = extractvalue { i64, i64 } %708, 0
; call <kernels::Fp2>::add
  %710 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s686.0, i64 noundef %s686.1, i64 noundef %s730.0, i64 noundef %s730.1)
  %s731.1 = extractvalue { i64, i64 } %709, 1
  %s731.0 = extractvalue { i64, i64 } %709, 0
  %s732.0 = extractvalue { i64, i64 } %710, 0
  %s732.1 = extractvalue { i64, i64 } %710, 1
; call <kernels::Fp2>::add
  %711 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s687.0, i64 noundef %s687.1, i64 noundef %s731.0, i64 noundef %s731.1)
  %s733.0 = extractvalue { i64, i64 } %711, 0
  %s733.1 = extractvalue { i64, i64 } %711, 1
  %_0.i265 = getelementptr inbounds nuw i8, ptr %bases, i64 176
  %s734 = load i64, ptr %_0.i265, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %712 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s726.0, i64 noundef %s726.1, i64 noundef %s734)
; call <kernels::Fp2>::mul_base
  %713 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s728.0, i64 noundef %s728.1, i64 noundef %s734)
  %s735.1 = extractvalue { i64, i64 } %712, 1
  %s735.0 = extractvalue { i64, i64 } %712, 0
  %s736.0 = extractvalue { i64, i64 } %713, 0
  %s736.1 = extractvalue { i64, i64 } %713, 1
; call <kernels::Fp2>::sub
  %714 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s725.0, i64 noundef %s725.1, i64 noundef %s735.0, i64 noundef %s735.1)
  %s737.0 = extractvalue { i64, i64 } %714, 0
  %s737.1 = extractvalue { i64, i64 } %714, 1
  %_0.i93 = getelementptr inbounds nuw i8, ptr %params, i64 1344
  %s738.0 = load i64, ptr %_0.i93, align 8, !noundef !3
  %715 = getelementptr inbounds nuw i8, ptr %params, i64 1352
  %s738.1 = load i64, ptr %715, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %716 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s738.0, i64 noundef %s738.1, i64 noundef %s736.0, i64 noundef %s736.1)
  %s739.0 = extractvalue { i64, i64 } %716, 0
  %s739.1 = extractvalue { i64, i64 } %716, 1
  %_0.i92 = getelementptr inbounds nuw i8, ptr %params, i64 1360
  %s740.0 = load i64, ptr %_0.i92, align 8, !noundef !3
  %717 = getelementptr inbounds nuw i8, ptr %params, i64 1368
  %s740.1 = load i64, ptr %717, align 8, !noundef !3
  %_0.i91 = getelementptr inbounds nuw i8, ptr %raw, i64 896
  %s741.0 = load i64, ptr %_0.i91, align 8, !noundef !3
  %718 = getelementptr inbounds nuw i8, ptr %raw, i64 904
  %s741.1 = load i64, ptr %718, align 8, !noundef !3
  %_0.i90 = getelementptr inbounds nuw i8, ptr %raw, i64 912
  %s742.0 = load i64, ptr %_0.i90, align 8, !noundef !3
  %719 = getelementptr inbounds nuw i8, ptr %raw, i64 920
  %s742.1 = load i64, ptr %719, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %720 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s742.0, i64 noundef %s742.1, i64 noundef %s741.0, i64 noundef %s741.1)
  %s743.0 = extractvalue { i64, i64 } %720, 0
  %s743.1 = extractvalue { i64, i64 } %720, 1
  %_0.i89 = getelementptr inbounds nuw i8, ptr %params, i64 1376
  %s744.0 = load i64, ptr %_0.i89, align 8, !noundef !3
  %721 = getelementptr inbounds nuw i8, ptr %params, i64 1384
  %s744.1 = load i64, ptr %721, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %722 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s741.0, i64 noundef %s741.1, i64 noundef %s744.0, i64 noundef %s744.1)
; call <kernels::Fp2>::mul
  %723 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s743.0, i64 noundef %s743.1, i64 noundef %s744.0, i64 noundef %s744.1)
  %s745.1 = extractvalue { i64, i64 } %722, 1
  %s745.0 = extractvalue { i64, i64 } %722, 0
; call <kernels::Fp2>::add
  %724 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s732.0, i64 noundef %s732.1, i64 noundef %s745.0, i64 noundef %s745.1)
  %s746.1 = extractvalue { i64, i64 } %723, 1
  %s746.0 = extractvalue { i64, i64 } %723, 0
  %s747.0 = extractvalue { i64, i64 } %724, 0
  %s747.1 = extractvalue { i64, i64 } %724, 1
; call <kernels::Fp2>::add
  %725 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s733.0, i64 noundef %s733.1, i64 noundef %s746.0, i64 noundef %s746.1)
  %s748.0 = extractvalue { i64, i64 } %725, 0
  %s748.1 = extractvalue { i64, i64 } %725, 1
  %_0.i264 = getelementptr inbounds nuw i8, ptr %bases, i64 184
  %s749 = load i64, ptr %_0.i264, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %726 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s741.0, i64 noundef %s741.1, i64 noundef %s749)
; call <kernels::Fp2>::mul_base
  %727 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s743.0, i64 noundef %s743.1, i64 noundef %s749)
  %s750.1 = extractvalue { i64, i64 } %726, 1
  %s750.0 = extractvalue { i64, i64 } %726, 0
  %s751.0 = extractvalue { i64, i64 } %727, 0
  %s751.1 = extractvalue { i64, i64 } %727, 1
; call <kernels::Fp2>::sub
  %728 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s740.0, i64 noundef %s740.1, i64 noundef %s750.0, i64 noundef %s750.1)
  %s752.0 = extractvalue { i64, i64 } %728, 0
  %s752.1 = extractvalue { i64, i64 } %728, 1
  %_0.i88 = getelementptr inbounds nuw i8, ptr %params, i64 1392
  %s753.0 = load i64, ptr %_0.i88, align 8, !noundef !3
  %729 = getelementptr inbounds nuw i8, ptr %params, i64 1400
  %s753.1 = load i64, ptr %729, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %730 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s753.0, i64 noundef %s753.1, i64 noundef %s751.0, i64 noundef %s751.1)
  %s754.0 = extractvalue { i64, i64 } %730, 0
  %s754.1 = extractvalue { i64, i64 } %730, 1
  %_0.i87 = getelementptr inbounds nuw i8, ptr %raw, i64 1696
  %s755.0 = load i64, ptr %_0.i87, align 8, !noundef !3
  %731 = getelementptr inbounds nuw i8, ptr %raw, i64 1704
  %s755.1 = load i64, ptr %731, align 8, !noundef !3
  %_0.i86 = getelementptr inbounds nuw i8, ptr %raw, i64 1712
  %s756.0 = load i64, ptr %_0.i86, align 8, !noundef !3
  %732 = getelementptr inbounds nuw i8, ptr %raw, i64 1720
  %s756.1 = load i64, ptr %732, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %733 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s756.0, i64 noundef %s756.1, i64 noundef %s755.0, i64 noundef %s755.1)
  %s757.0 = extractvalue { i64, i64 } %733, 0
  %s757.1 = extractvalue { i64, i64 } %733, 1
; call <kernels::Fp2>::mul
  %734 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s755.0, i64 noundef %s755.1, i64 noundef %s737.0, i64 noundef %s737.1)
  %s758.0 = extractvalue { i64, i64 } %734, 0
  %s758.1 = extractvalue { i64, i64 } %734, 1
; call <kernels::Fp2>::mul
  %735 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s757.0, i64 noundef %s757.1, i64 noundef %s739.0, i64 noundef %s739.1)
  %s759.0 = extractvalue { i64, i64 } %735, 0
  %s759.1 = extractvalue { i64, i64 } %735, 1
; call <kernels::Fp2>::add
  %736 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s755.0, i64 noundef %s755.1, i64 noundef %s757.0, i64 noundef %s757.1)
; call <kernels::Fp2>::add
  %737 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s737.0, i64 noundef %s737.1, i64 noundef %s739.0, i64 noundef %s739.1)
  %s760.1 = extractvalue { i64, i64 } %736, 1
  %s760.0 = extractvalue { i64, i64 } %736, 0
  %s761.0 = extractvalue { i64, i64 } %737, 0
  %s761.1 = extractvalue { i64, i64 } %737, 1
; call <kernels::Fp2>::mul
  %738 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s760.0, i64 noundef %s760.1, i64 noundef %s761.0, i64 noundef %s761.1)
  %s762.0 = extractvalue { i64, i64 } %738, 0
  %s762.1 = extractvalue { i64, i64 } %738, 1
; call <kernels::Fp2>::sub
  %739 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s762.0, i64 noundef %s762.1, i64 noundef %s758.0, i64 noundef %s758.1)
  %s763.0 = extractvalue { i64, i64 } %739, 0
  %s763.1 = extractvalue { i64, i64 } %739, 1
; call <kernels::Fp2>::sub
  %740 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s763.0, i64 noundef %s763.1, i64 noundef %s759.0, i64 noundef %s759.1)
  %s764.0 = extractvalue { i64, i64 } %740, 0
  %s764.1 = extractvalue { i64, i64 } %740, 1
; call <kernels::Fp2>::mul
  %741 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s758.0, i64 noundef %s758.1, i64 noundef %s752.0, i64 noundef %s752.1)
  %s765.0 = extractvalue { i64, i64 } %741, 0
  %s765.1 = extractvalue { i64, i64 } %741, 1
; call <kernels::Fp2>::mul
  %742 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s758.0, i64 noundef %s758.1, i64 noundef %s754.0, i64 noundef %s754.1)
; call <kernels::Fp2>::mul
  %743 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s764.0, i64 noundef %s764.1, i64 noundef %s752.0, i64 noundef %s752.1)
  %s766.1 = extractvalue { i64, i64 } %742, 1
  %s766.0 = extractvalue { i64, i64 } %742, 0
  %s767.0 = extractvalue { i64, i64 } %743, 0
  %s767.1 = extractvalue { i64, i64 } %743, 1
; call <kernels::Fp2>::add
  %744 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s766.0, i64 noundef %s766.1, i64 noundef %s767.0, i64 noundef %s767.1)
  %s768.0 = extractvalue { i64, i64 } %744, 0
  %s768.1 = extractvalue { i64, i64 } %744, 1
; call <kernels::Fp2>::mul
  %745 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s764.0, i64 noundef %s764.1, i64 noundef %s754.0, i64 noundef %s754.1)
; call <kernels::Fp2>::mul
  %746 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s759.0, i64 noundef %s759.1, i64 noundef %s752.0, i64 noundef %s752.1)
  %s769.1 = extractvalue { i64, i64 } %745, 1
  %s769.0 = extractvalue { i64, i64 } %745, 0
  %s770.0 = extractvalue { i64, i64 } %746, 0
  %s770.1 = extractvalue { i64, i64 } %746, 1
; call <kernels::Fp2>::add
  %747 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s769.0, i64 noundef %s769.1, i64 noundef %s770.0, i64 noundef %s770.1)
  %s771.0 = extractvalue { i64, i64 } %747, 0
  %s771.1 = extractvalue { i64, i64 } %747, 1
; call <kernels::Fp2>::mul
  %748 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s759.0, i64 noundef %s759.1, i64 noundef %s754.0, i64 noundef %s754.1)
  %s772.0 = extractvalue { i64, i64 } %748, 0
  %s772.1 = extractvalue { i64, i64 } %748, 1
; call <kernels::Fp2>::add
  %749 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s737.0, i64 noundef %s737.1, i64 noundef %s752.0, i64 noundef %s752.1)
; call <kernels::Fp2>::add
  %750 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s739.0, i64 noundef %s739.1, i64 noundef %s754.0, i64 noundef %s754.1)
  %s773.1 = extractvalue { i64, i64 } %749, 1
  %s773.0 = extractvalue { i64, i64 } %749, 0
; call <kernels::Fp2>::sub
  %751 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s765.0, i64 noundef %s765.1, i64 noundef %s773.0, i64 noundef %s773.1)
  %s774.1 = extractvalue { i64, i64 } %750, 1
  %s774.0 = extractvalue { i64, i64 } %750, 0
  %s775.0 = extractvalue { i64, i64 } %751, 0
  %s775.1 = extractvalue { i64, i64 } %751, 1
; call <kernels::Fp2>::sub
  %752 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s768.0, i64 noundef %s768.1, i64 noundef %s774.0, i64 noundef %s774.1)
  %s776.0 = extractvalue { i64, i64 } %752, 0
  %s776.1 = extractvalue { i64, i64 } %752, 1
  %_0.i85 = getelementptr inbounds nuw i8, ptr %params, i64 1408
  %s777.0 = load i64, ptr %_0.i85, align 8, !noundef !3
  %753 = getelementptr inbounds nuw i8, ptr %params, i64 1416
  %s777.1 = load i64, ptr %753, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %754 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s775.0, i64 noundef %s775.1, i64 noundef %s777.0, i64 noundef %s777.1)
  %s778.0 = extractvalue { i64, i64 } %754, 0
  %s778.1 = extractvalue { i64, i64 } %754, 1
; call <kernels::Fp2>::mul
  %755 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s776.0, i64 noundef %s776.1, i64 noundef %s777.0, i64 noundef %s777.1)
  %s779.0 = extractvalue { i64, i64 } %755, 0
  %s779.1 = extractvalue { i64, i64 } %755, 1
; call <kernels::Fp2>::mul
  %756 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s771.0, i64 noundef %s771.1, i64 noundef %s777.0, i64 noundef %s777.1)
  %s780.0 = extractvalue { i64, i64 } %756, 0
  %s780.1 = extractvalue { i64, i64 } %756, 1
; call <kernels::Fp2>::mul
  %757 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s772.0, i64 noundef %s772.1, i64 noundef %s777.0, i64 noundef %s777.1)
  %s781.0 = extractvalue { i64, i64 } %757, 0
  %s781.1 = extractvalue { i64, i64 } %757, 1
; call <kernels::Fp2>::add
  %758 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s721.0, i64 noundef %s721.1, i64 noundef %s778.0, i64 noundef %s778.1)
  %s782.0 = extractvalue { i64, i64 } %758, 0
  %s782.1 = extractvalue { i64, i64 } %758, 1
; call <kernels::Fp2>::add
  %759 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s722.0, i64 noundef %s722.1, i64 noundef %s779.0, i64 noundef %s779.1)
  %s783.0 = extractvalue { i64, i64 } %759, 0
  %s783.1 = extractvalue { i64, i64 } %759, 1
; call <kernels::Fp2>::add
  %760 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s723.0, i64 noundef %s723.1, i64 noundef %s780.0, i64 noundef %s780.1)
  %s784.0 = extractvalue { i64, i64 } %760, 0
  %s784.1 = extractvalue { i64, i64 } %760, 1
; call <kernels::Fp2>::add
  %761 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s724.0, i64 noundef %s724.1, i64 noundef %s781.0, i64 noundef %s781.1)
  %s785.0 = extractvalue { i64, i64 } %761, 0
  %s785.1 = extractvalue { i64, i64 } %761, 1
  %_0.i84 = getelementptr inbounds nuw i8, ptr %params, i64 1424
  %s786.0 = load i64, ptr %_0.i84, align 8, !noundef !3
  %762 = getelementptr inbounds nuw i8, ptr %params, i64 1432
  %s786.1 = load i64, ptr %762, align 8, !noundef !3
  %_0.i83 = getelementptr inbounds nuw i8, ptr %raw, i64 928
  %s787.0 = load i64, ptr %_0.i83, align 8, !noundef !3
  %763 = getelementptr inbounds nuw i8, ptr %raw, i64 936
  %s787.1 = load i64, ptr %763, align 8, !noundef !3
  %_0.i82 = getelementptr inbounds nuw i8, ptr %raw, i64 944
  %s788.0 = load i64, ptr %_0.i82, align 8, !noundef !3
  %764 = getelementptr inbounds nuw i8, ptr %raw, i64 952
  %s788.1 = load i64, ptr %764, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %765 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s788.0, i64 noundef %s788.1, i64 noundef %s787.0, i64 noundef %s787.1)
  %s789.0 = extractvalue { i64, i64 } %765, 0
  %s789.1 = extractvalue { i64, i64 } %765, 1
  %_0.i81 = getelementptr inbounds nuw i8, ptr %params, i64 1440
  %s790.0 = load i64, ptr %_0.i81, align 8, !noundef !3
  %766 = getelementptr inbounds nuw i8, ptr %params, i64 1448
  %s790.1 = load i64, ptr %766, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %767 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s787.0, i64 noundef %s787.1, i64 noundef %s790.0, i64 noundef %s790.1)
; call <kernels::Fp2>::mul
  %768 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s789.0, i64 noundef %s789.1, i64 noundef %s790.0, i64 noundef %s790.1)
  %s791.1 = extractvalue { i64, i64 } %767, 1
  %s791.0 = extractvalue { i64, i64 } %767, 0
; call <kernels::Fp2>::add
  %769 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s747.0, i64 noundef %s747.1, i64 noundef %s791.0, i64 noundef %s791.1)
  %s792.1 = extractvalue { i64, i64 } %768, 1
  %s792.0 = extractvalue { i64, i64 } %768, 0
  %s793.0 = extractvalue { i64, i64 } %769, 0
  %s793.1 = extractvalue { i64, i64 } %769, 1
; call <kernels::Fp2>::add
  %770 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s748.0, i64 noundef %s748.1, i64 noundef %s792.0, i64 noundef %s792.1)
  %s794.0 = extractvalue { i64, i64 } %770, 0
  %s794.1 = extractvalue { i64, i64 } %770, 1
  %_0.i263 = getelementptr inbounds nuw i8, ptr %bases, i64 192
  %s795 = load i64, ptr %_0.i263, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %771 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s787.0, i64 noundef %s787.1, i64 noundef %s795)
; call <kernels::Fp2>::mul_base
  %772 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s789.0, i64 noundef %s789.1, i64 noundef %s795)
  %s796.1 = extractvalue { i64, i64 } %771, 1
  %s796.0 = extractvalue { i64, i64 } %771, 0
  %s797.0 = extractvalue { i64, i64 } %772, 0
  %s797.1 = extractvalue { i64, i64 } %772, 1
; call <kernels::Fp2>::sub
  %773 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s786.0, i64 noundef %s786.1, i64 noundef %s796.0, i64 noundef %s796.1)
  %s798.0 = extractvalue { i64, i64 } %773, 0
  %s798.1 = extractvalue { i64, i64 } %773, 1
  %_0.i80 = getelementptr inbounds nuw i8, ptr %params, i64 1456
  %s799.0 = load i64, ptr %_0.i80, align 8, !noundef !3
  %774 = getelementptr inbounds nuw i8, ptr %params, i64 1464
  %s799.1 = load i64, ptr %774, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %775 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s799.0, i64 noundef %s799.1, i64 noundef %s797.0, i64 noundef %s797.1)
  %s800.0 = extractvalue { i64, i64 } %775, 0
  %s800.1 = extractvalue { i64, i64 } %775, 1
  %_0.i79 = getelementptr inbounds nuw i8, ptr %params, i64 1472
  %s801.0 = load i64, ptr %_0.i79, align 8, !noundef !3
  %776 = getelementptr inbounds nuw i8, ptr %params, i64 1480
  %s801.1 = load i64, ptr %776, align 8, !noundef !3
  %_0.i78 = getelementptr inbounds nuw i8, ptr %raw, i64 960
  %s802.0 = load i64, ptr %_0.i78, align 8, !noundef !3
  %777 = getelementptr inbounds nuw i8, ptr %raw, i64 968
  %s802.1 = load i64, ptr %777, align 8, !noundef !3
  %_0.i77 = getelementptr inbounds nuw i8, ptr %raw, i64 976
  %s803.0 = load i64, ptr %_0.i77, align 8, !noundef !3
  %778 = getelementptr inbounds nuw i8, ptr %raw, i64 984
  %s803.1 = load i64, ptr %778, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %779 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s803.0, i64 noundef %s803.1, i64 noundef %s802.0, i64 noundef %s802.1)
  %s804.0 = extractvalue { i64, i64 } %779, 0
  %s804.1 = extractvalue { i64, i64 } %779, 1
  %_0.i76 = getelementptr inbounds nuw i8, ptr %params, i64 1488
  %s805.0 = load i64, ptr %_0.i76, align 8, !noundef !3
  %780 = getelementptr inbounds nuw i8, ptr %params, i64 1496
  %s805.1 = load i64, ptr %780, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %781 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s802.0, i64 noundef %s802.1, i64 noundef %s805.0, i64 noundef %s805.1)
; call <kernels::Fp2>::mul
  %782 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s804.0, i64 noundef %s804.1, i64 noundef %s805.0, i64 noundef %s805.1)
  %s806.1 = extractvalue { i64, i64 } %781, 1
  %s806.0 = extractvalue { i64, i64 } %781, 0
; call <kernels::Fp2>::add
  %783 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s793.0, i64 noundef %s793.1, i64 noundef %s806.0, i64 noundef %s806.1)
  %s807.1 = extractvalue { i64, i64 } %782, 1
  %s807.0 = extractvalue { i64, i64 } %782, 0
  %s808.0 = extractvalue { i64, i64 } %783, 0
  %s808.1 = extractvalue { i64, i64 } %783, 1
; call <kernels::Fp2>::add
  %784 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s794.0, i64 noundef %s794.1, i64 noundef %s807.0, i64 noundef %s807.1)
  %s809.0 = extractvalue { i64, i64 } %784, 0
  %s809.1 = extractvalue { i64, i64 } %784, 1
  %_0.i262 = getelementptr inbounds nuw i8, ptr %bases, i64 200
  %s810 = load i64, ptr %_0.i262, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %785 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s802.0, i64 noundef %s802.1, i64 noundef %s810)
; call <kernels::Fp2>::mul_base
  %786 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s804.0, i64 noundef %s804.1, i64 noundef %s810)
  %s811.1 = extractvalue { i64, i64 } %785, 1
  %s811.0 = extractvalue { i64, i64 } %785, 0
  %s812.0 = extractvalue { i64, i64 } %786, 0
  %s812.1 = extractvalue { i64, i64 } %786, 1
; call <kernels::Fp2>::sub
  %787 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s801.0, i64 noundef %s801.1, i64 noundef %s811.0, i64 noundef %s811.1)
  %s813.0 = extractvalue { i64, i64 } %787, 0
  %s813.1 = extractvalue { i64, i64 } %787, 1
  %_0.i75 = getelementptr inbounds nuw i8, ptr %params, i64 1504
  %s814.0 = load i64, ptr %_0.i75, align 8, !noundef !3
  %788 = getelementptr inbounds nuw i8, ptr %params, i64 1512
  %s814.1 = load i64, ptr %788, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %789 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s814.0, i64 noundef %s814.1, i64 noundef %s812.0, i64 noundef %s812.1)
  %s815.0 = extractvalue { i64, i64 } %789, 0
  %s815.1 = extractvalue { i64, i64 } %789, 1
  %_0.i74 = getelementptr inbounds nuw i8, ptr %raw, i64 1728
  %s816.0 = load i64, ptr %_0.i74, align 8, !noundef !3
  %790 = getelementptr inbounds nuw i8, ptr %raw, i64 1736
  %s816.1 = load i64, ptr %790, align 8, !noundef !3
  %_0.i73 = getelementptr inbounds nuw i8, ptr %raw, i64 1744
  %s817.0 = load i64, ptr %_0.i73, align 8, !noundef !3
  %791 = getelementptr inbounds nuw i8, ptr %raw, i64 1752
  %s817.1 = load i64, ptr %791, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %792 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s817.0, i64 noundef %s817.1, i64 noundef %s816.0, i64 noundef %s816.1)
  %s818.0 = extractvalue { i64, i64 } %792, 0
  %s818.1 = extractvalue { i64, i64 } %792, 1
; call <kernels::Fp2>::mul
  %793 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s816.0, i64 noundef %s816.1, i64 noundef %s798.0, i64 noundef %s798.1)
  %s819.0 = extractvalue { i64, i64 } %793, 0
  %s819.1 = extractvalue { i64, i64 } %793, 1
; call <kernels::Fp2>::mul
  %794 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s818.0, i64 noundef %s818.1, i64 noundef %s800.0, i64 noundef %s800.1)
  %s820.0 = extractvalue { i64, i64 } %794, 0
  %s820.1 = extractvalue { i64, i64 } %794, 1
; call <kernels::Fp2>::add
  %795 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s816.0, i64 noundef %s816.1, i64 noundef %s818.0, i64 noundef %s818.1)
; call <kernels::Fp2>::add
  %796 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s798.0, i64 noundef %s798.1, i64 noundef %s800.0, i64 noundef %s800.1)
  %s821.1 = extractvalue { i64, i64 } %795, 1
  %s821.0 = extractvalue { i64, i64 } %795, 0
  %s822.0 = extractvalue { i64, i64 } %796, 0
  %s822.1 = extractvalue { i64, i64 } %796, 1
; call <kernels::Fp2>::mul
  %797 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s821.0, i64 noundef %s821.1, i64 noundef %s822.0, i64 noundef %s822.1)
  %s823.0 = extractvalue { i64, i64 } %797, 0
  %s823.1 = extractvalue { i64, i64 } %797, 1
; call <kernels::Fp2>::sub
  %798 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s823.0, i64 noundef %s823.1, i64 noundef %s819.0, i64 noundef %s819.1)
  %s824.0 = extractvalue { i64, i64 } %798, 0
  %s824.1 = extractvalue { i64, i64 } %798, 1
; call <kernels::Fp2>::sub
  %799 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s824.0, i64 noundef %s824.1, i64 noundef %s820.0, i64 noundef %s820.1)
  %s825.0 = extractvalue { i64, i64 } %799, 0
  %s825.1 = extractvalue { i64, i64 } %799, 1
; call <kernels::Fp2>::mul
  %800 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s819.0, i64 noundef %s819.1, i64 noundef %s813.0, i64 noundef %s813.1)
  %s826.0 = extractvalue { i64, i64 } %800, 0
  %s826.1 = extractvalue { i64, i64 } %800, 1
; call <kernels::Fp2>::mul
  %801 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s819.0, i64 noundef %s819.1, i64 noundef %s815.0, i64 noundef %s815.1)
; call <kernels::Fp2>::mul
  %802 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s825.0, i64 noundef %s825.1, i64 noundef %s813.0, i64 noundef %s813.1)
  %s827.1 = extractvalue { i64, i64 } %801, 1
  %s827.0 = extractvalue { i64, i64 } %801, 0
  %s828.0 = extractvalue { i64, i64 } %802, 0
  %s828.1 = extractvalue { i64, i64 } %802, 1
; call <kernels::Fp2>::add
  %803 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s827.0, i64 noundef %s827.1, i64 noundef %s828.0, i64 noundef %s828.1)
  %s829.0 = extractvalue { i64, i64 } %803, 0
  %s829.1 = extractvalue { i64, i64 } %803, 1
; call <kernels::Fp2>::mul
  %804 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s825.0, i64 noundef %s825.1, i64 noundef %s815.0, i64 noundef %s815.1)
; call <kernels::Fp2>::mul
  %805 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s820.0, i64 noundef %s820.1, i64 noundef %s813.0, i64 noundef %s813.1)
  %s830.1 = extractvalue { i64, i64 } %804, 1
  %s830.0 = extractvalue { i64, i64 } %804, 0
  %s831.0 = extractvalue { i64, i64 } %805, 0
  %s831.1 = extractvalue { i64, i64 } %805, 1
; call <kernels::Fp2>::add
  %806 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s830.0, i64 noundef %s830.1, i64 noundef %s831.0, i64 noundef %s831.1)
  %s832.0 = extractvalue { i64, i64 } %806, 0
  %s832.1 = extractvalue { i64, i64 } %806, 1
; call <kernels::Fp2>::mul
  %807 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s820.0, i64 noundef %s820.1, i64 noundef %s815.0, i64 noundef %s815.1)
  %s833.0 = extractvalue { i64, i64 } %807, 0
  %s833.1 = extractvalue { i64, i64 } %807, 1
; call <kernels::Fp2>::add
  %808 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s798.0, i64 noundef %s798.1, i64 noundef %s813.0, i64 noundef %s813.1)
; call <kernels::Fp2>::add
  %809 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s800.0, i64 noundef %s800.1, i64 noundef %s815.0, i64 noundef %s815.1)
  %s834.1 = extractvalue { i64, i64 } %808, 1
  %s834.0 = extractvalue { i64, i64 } %808, 0
; call <kernels::Fp2>::sub
  %810 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s826.0, i64 noundef %s826.1, i64 noundef %s834.0, i64 noundef %s834.1)
  %s835.1 = extractvalue { i64, i64 } %809, 1
  %s835.0 = extractvalue { i64, i64 } %809, 0
  %s836.0 = extractvalue { i64, i64 } %810, 0
  %s836.1 = extractvalue { i64, i64 } %810, 1
; call <kernels::Fp2>::sub
  %811 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s829.0, i64 noundef %s829.1, i64 noundef %s835.0, i64 noundef %s835.1)
  %s837.0 = extractvalue { i64, i64 } %811, 0
  %s837.1 = extractvalue { i64, i64 } %811, 1
  %_0.i72 = getelementptr inbounds nuw i8, ptr %params, i64 1520
  %s838.0 = load i64, ptr %_0.i72, align 8, !noundef !3
  %812 = getelementptr inbounds nuw i8, ptr %params, i64 1528
  %s838.1 = load i64, ptr %812, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %813 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s836.0, i64 noundef %s836.1, i64 noundef %s838.0, i64 noundef %s838.1)
  %s839.0 = extractvalue { i64, i64 } %813, 0
  %s839.1 = extractvalue { i64, i64 } %813, 1
; call <kernels::Fp2>::mul
  %814 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s837.0, i64 noundef %s837.1, i64 noundef %s838.0, i64 noundef %s838.1)
  %s840.0 = extractvalue { i64, i64 } %814, 0
  %s840.1 = extractvalue { i64, i64 } %814, 1
; call <kernels::Fp2>::mul
  %815 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s832.0, i64 noundef %s832.1, i64 noundef %s838.0, i64 noundef %s838.1)
  %s841.0 = extractvalue { i64, i64 } %815, 0
  %s841.1 = extractvalue { i64, i64 } %815, 1
; call <kernels::Fp2>::mul
  %816 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s833.0, i64 noundef %s833.1, i64 noundef %s838.0, i64 noundef %s838.1)
  %s842.0 = extractvalue { i64, i64 } %816, 0
  %s842.1 = extractvalue { i64, i64 } %816, 1
; call <kernels::Fp2>::add
  %817 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s782.0, i64 noundef %s782.1, i64 noundef %s839.0, i64 noundef %s839.1)
  %s843.0 = extractvalue { i64, i64 } %817, 0
  %s843.1 = extractvalue { i64, i64 } %817, 1
; call <kernels::Fp2>::add
  %818 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s783.0, i64 noundef %s783.1, i64 noundef %s840.0, i64 noundef %s840.1)
  %s844.0 = extractvalue { i64, i64 } %818, 0
  %s844.1 = extractvalue { i64, i64 } %818, 1
; call <kernels::Fp2>::add
  %819 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s784.0, i64 noundef %s784.1, i64 noundef %s841.0, i64 noundef %s841.1)
  %s845.0 = extractvalue { i64, i64 } %819, 0
  %s845.1 = extractvalue { i64, i64 } %819, 1
; call <kernels::Fp2>::add
  %820 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s785.0, i64 noundef %s785.1, i64 noundef %s842.0, i64 noundef %s842.1)
  %s846.0 = extractvalue { i64, i64 } %820, 0
  %s846.1 = extractvalue { i64, i64 } %820, 1
  %_0.i71 = getelementptr inbounds nuw i8, ptr %params, i64 1536
  %s847.0 = load i64, ptr %_0.i71, align 8, !noundef !3
  %821 = getelementptr inbounds nuw i8, ptr %params, i64 1544
  %s847.1 = load i64, ptr %821, align 8, !noundef !3
  %_0.i70 = getelementptr inbounds nuw i8, ptr %raw, i64 992
  %s848.0 = load i64, ptr %_0.i70, align 8, !noundef !3
  %822 = getelementptr inbounds nuw i8, ptr %raw, i64 1000
  %s848.1 = load i64, ptr %822, align 8, !noundef !3
  %_0.i69 = getelementptr inbounds nuw i8, ptr %raw, i64 1008
  %s849.0 = load i64, ptr %_0.i69, align 8, !noundef !3
  %823 = getelementptr inbounds nuw i8, ptr %raw, i64 1016
  %s849.1 = load i64, ptr %823, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %824 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s849.0, i64 noundef %s849.1, i64 noundef %s848.0, i64 noundef %s848.1)
  %s850.0 = extractvalue { i64, i64 } %824, 0
  %s850.1 = extractvalue { i64, i64 } %824, 1
  %_0.i68 = getelementptr inbounds nuw i8, ptr %params, i64 1552
  %s851.0 = load i64, ptr %_0.i68, align 8, !noundef !3
  %825 = getelementptr inbounds nuw i8, ptr %params, i64 1560
  %s851.1 = load i64, ptr %825, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %826 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s848.0, i64 noundef %s848.1, i64 noundef %s851.0, i64 noundef %s851.1)
; call <kernels::Fp2>::mul
  %827 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s850.0, i64 noundef %s850.1, i64 noundef %s851.0, i64 noundef %s851.1)
  %s852.1 = extractvalue { i64, i64 } %826, 1
  %s852.0 = extractvalue { i64, i64 } %826, 0
; call <kernels::Fp2>::add
  %828 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s808.0, i64 noundef %s808.1, i64 noundef %s852.0, i64 noundef %s852.1)
  %s853.1 = extractvalue { i64, i64 } %827, 1
  %s853.0 = extractvalue { i64, i64 } %827, 0
  %s854.0 = extractvalue { i64, i64 } %828, 0
  %s854.1 = extractvalue { i64, i64 } %828, 1
; call <kernels::Fp2>::add
  %829 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s809.0, i64 noundef %s809.1, i64 noundef %s853.0, i64 noundef %s853.1)
  %s855.0 = extractvalue { i64, i64 } %829, 0
  %s855.1 = extractvalue { i64, i64 } %829, 1
  %_0.i261 = getelementptr inbounds nuw i8, ptr %bases, i64 208
  %s856 = load i64, ptr %_0.i261, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %830 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s848.0, i64 noundef %s848.1, i64 noundef %s856)
; call <kernels::Fp2>::mul_base
  %831 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s850.0, i64 noundef %s850.1, i64 noundef %s856)
  %s857.1 = extractvalue { i64, i64 } %830, 1
  %s857.0 = extractvalue { i64, i64 } %830, 0
  %s858.0 = extractvalue { i64, i64 } %831, 0
  %s858.1 = extractvalue { i64, i64 } %831, 1
; call <kernels::Fp2>::sub
  %832 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s847.0, i64 noundef %s847.1, i64 noundef %s857.0, i64 noundef %s857.1)
  %s859.0 = extractvalue { i64, i64 } %832, 0
  %s859.1 = extractvalue { i64, i64 } %832, 1
  %_0.i67 = getelementptr inbounds nuw i8, ptr %params, i64 1568
  %s860.0 = load i64, ptr %_0.i67, align 8, !noundef !3
  %833 = getelementptr inbounds nuw i8, ptr %params, i64 1576
  %s860.1 = load i64, ptr %833, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %834 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s860.0, i64 noundef %s860.1, i64 noundef %s858.0, i64 noundef %s858.1)
  %s861.0 = extractvalue { i64, i64 } %834, 0
  %s861.1 = extractvalue { i64, i64 } %834, 1
  %_0.i66 = getelementptr inbounds nuw i8, ptr %params, i64 1584
  %s862.0 = load i64, ptr %_0.i66, align 8, !noundef !3
  %835 = getelementptr inbounds nuw i8, ptr %params, i64 1592
  %s862.1 = load i64, ptr %835, align 8, !noundef !3
  %_0.i65 = getelementptr inbounds nuw i8, ptr %raw, i64 1024
  %s863.0 = load i64, ptr %_0.i65, align 8, !noundef !3
  %836 = getelementptr inbounds nuw i8, ptr %raw, i64 1032
  %s863.1 = load i64, ptr %836, align 8, !noundef !3
  %_0.i64 = getelementptr inbounds nuw i8, ptr %raw, i64 1040
  %s864.0 = load i64, ptr %_0.i64, align 8, !noundef !3
  %837 = getelementptr inbounds nuw i8, ptr %raw, i64 1048
  %s864.1 = load i64, ptr %837, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %838 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s864.0, i64 noundef %s864.1, i64 noundef %s863.0, i64 noundef %s863.1)
  %s865.0 = extractvalue { i64, i64 } %838, 0
  %s865.1 = extractvalue { i64, i64 } %838, 1
  %_0.i63 = getelementptr inbounds nuw i8, ptr %params, i64 1600
  %s866.0 = load i64, ptr %_0.i63, align 8, !noundef !3
  %839 = getelementptr inbounds nuw i8, ptr %params, i64 1608
  %s866.1 = load i64, ptr %839, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %840 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s863.0, i64 noundef %s863.1, i64 noundef %s866.0, i64 noundef %s866.1)
; call <kernels::Fp2>::mul
  %841 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s865.0, i64 noundef %s865.1, i64 noundef %s866.0, i64 noundef %s866.1)
  %s867.1 = extractvalue { i64, i64 } %840, 1
  %s867.0 = extractvalue { i64, i64 } %840, 0
; call <kernels::Fp2>::add
  %842 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s854.0, i64 noundef %s854.1, i64 noundef %s867.0, i64 noundef %s867.1)
  %s868.1 = extractvalue { i64, i64 } %841, 1
  %s868.0 = extractvalue { i64, i64 } %841, 0
  %s869.0 = extractvalue { i64, i64 } %842, 0
  %s869.1 = extractvalue { i64, i64 } %842, 1
; call <kernels::Fp2>::add
  %843 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s855.0, i64 noundef %s855.1, i64 noundef %s868.0, i64 noundef %s868.1)
  %s870.0 = extractvalue { i64, i64 } %843, 0
  %s870.1 = extractvalue { i64, i64 } %843, 1
  %_0.i260 = getelementptr inbounds nuw i8, ptr %bases, i64 216
  %s871 = load i64, ptr %_0.i260, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %844 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s863.0, i64 noundef %s863.1, i64 noundef %s871)
; call <kernels::Fp2>::mul_base
  %845 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s865.0, i64 noundef %s865.1, i64 noundef %s871)
  %s872.1 = extractvalue { i64, i64 } %844, 1
  %s872.0 = extractvalue { i64, i64 } %844, 0
  %s873.0 = extractvalue { i64, i64 } %845, 0
  %s873.1 = extractvalue { i64, i64 } %845, 1
; call <kernels::Fp2>::sub
  %846 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s862.0, i64 noundef %s862.1, i64 noundef %s872.0, i64 noundef %s872.1)
  %s874.0 = extractvalue { i64, i64 } %846, 0
  %s874.1 = extractvalue { i64, i64 } %846, 1
  %_0.i62 = getelementptr inbounds nuw i8, ptr %params, i64 1616
  %s875.0 = load i64, ptr %_0.i62, align 8, !noundef !3
  %847 = getelementptr inbounds nuw i8, ptr %params, i64 1624
  %s875.1 = load i64, ptr %847, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %848 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s875.0, i64 noundef %s875.1, i64 noundef %s873.0, i64 noundef %s873.1)
  %s876.0 = extractvalue { i64, i64 } %848, 0
  %s876.1 = extractvalue { i64, i64 } %848, 1
  %_0.i61 = getelementptr inbounds nuw i8, ptr %raw, i64 1760
  %s877.0 = load i64, ptr %_0.i61, align 8, !noundef !3
  %849 = getelementptr inbounds nuw i8, ptr %raw, i64 1768
  %s877.1 = load i64, ptr %849, align 8, !noundef !3
  %_0.i60 = getelementptr inbounds nuw i8, ptr %raw, i64 1776
  %s878.0 = load i64, ptr %_0.i60, align 8, !noundef !3
  %850 = getelementptr inbounds nuw i8, ptr %raw, i64 1784
  %s878.1 = load i64, ptr %850, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %851 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s878.0, i64 noundef %s878.1, i64 noundef %s877.0, i64 noundef %s877.1)
  %s879.0 = extractvalue { i64, i64 } %851, 0
  %s879.1 = extractvalue { i64, i64 } %851, 1
; call <kernels::Fp2>::mul
  %852 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s877.0, i64 noundef %s877.1, i64 noundef %s859.0, i64 noundef %s859.1)
  %s880.0 = extractvalue { i64, i64 } %852, 0
  %s880.1 = extractvalue { i64, i64 } %852, 1
; call <kernels::Fp2>::mul
  %853 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s879.0, i64 noundef %s879.1, i64 noundef %s861.0, i64 noundef %s861.1)
  %s881.0 = extractvalue { i64, i64 } %853, 0
  %s881.1 = extractvalue { i64, i64 } %853, 1
; call <kernels::Fp2>::add
  %854 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s877.0, i64 noundef %s877.1, i64 noundef %s879.0, i64 noundef %s879.1)
; call <kernels::Fp2>::add
  %855 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s859.0, i64 noundef %s859.1, i64 noundef %s861.0, i64 noundef %s861.1)
  %s882.1 = extractvalue { i64, i64 } %854, 1
  %s882.0 = extractvalue { i64, i64 } %854, 0
  %s883.0 = extractvalue { i64, i64 } %855, 0
  %s883.1 = extractvalue { i64, i64 } %855, 1
; call <kernels::Fp2>::mul
  %856 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s882.0, i64 noundef %s882.1, i64 noundef %s883.0, i64 noundef %s883.1)
  %s884.0 = extractvalue { i64, i64 } %856, 0
  %s884.1 = extractvalue { i64, i64 } %856, 1
; call <kernels::Fp2>::sub
  %857 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s884.0, i64 noundef %s884.1, i64 noundef %s880.0, i64 noundef %s880.1)
  %s885.0 = extractvalue { i64, i64 } %857, 0
  %s885.1 = extractvalue { i64, i64 } %857, 1
; call <kernels::Fp2>::sub
  %858 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s885.0, i64 noundef %s885.1, i64 noundef %s881.0, i64 noundef %s881.1)
  %s886.0 = extractvalue { i64, i64 } %858, 0
  %s886.1 = extractvalue { i64, i64 } %858, 1
; call <kernels::Fp2>::mul
  %859 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s880.0, i64 noundef %s880.1, i64 noundef %s874.0, i64 noundef %s874.1)
  %s887.0 = extractvalue { i64, i64 } %859, 0
  %s887.1 = extractvalue { i64, i64 } %859, 1
; call <kernels::Fp2>::mul
  %860 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s880.0, i64 noundef %s880.1, i64 noundef %s876.0, i64 noundef %s876.1)
; call <kernels::Fp2>::mul
  %861 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s886.0, i64 noundef %s886.1, i64 noundef %s874.0, i64 noundef %s874.1)
  %s888.1 = extractvalue { i64, i64 } %860, 1
  %s888.0 = extractvalue { i64, i64 } %860, 0
  %s889.0 = extractvalue { i64, i64 } %861, 0
  %s889.1 = extractvalue { i64, i64 } %861, 1
; call <kernels::Fp2>::add
  %862 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s888.0, i64 noundef %s888.1, i64 noundef %s889.0, i64 noundef %s889.1)
  %s890.0 = extractvalue { i64, i64 } %862, 0
  %s890.1 = extractvalue { i64, i64 } %862, 1
; call <kernels::Fp2>::mul
  %863 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s886.0, i64 noundef %s886.1, i64 noundef %s876.0, i64 noundef %s876.1)
; call <kernels::Fp2>::mul
  %864 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s881.0, i64 noundef %s881.1, i64 noundef %s874.0, i64 noundef %s874.1)
  %s891.1 = extractvalue { i64, i64 } %863, 1
  %s891.0 = extractvalue { i64, i64 } %863, 0
  %s892.0 = extractvalue { i64, i64 } %864, 0
  %s892.1 = extractvalue { i64, i64 } %864, 1
; call <kernels::Fp2>::add
  %865 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s891.0, i64 noundef %s891.1, i64 noundef %s892.0, i64 noundef %s892.1)
  %s893.0 = extractvalue { i64, i64 } %865, 0
  %s893.1 = extractvalue { i64, i64 } %865, 1
; call <kernels::Fp2>::mul
  %866 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s881.0, i64 noundef %s881.1, i64 noundef %s876.0, i64 noundef %s876.1)
  %s894.0 = extractvalue { i64, i64 } %866, 0
  %s894.1 = extractvalue { i64, i64 } %866, 1
; call <kernels::Fp2>::add
  %867 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s859.0, i64 noundef %s859.1, i64 noundef %s874.0, i64 noundef %s874.1)
; call <kernels::Fp2>::add
  %868 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s861.0, i64 noundef %s861.1, i64 noundef %s876.0, i64 noundef %s876.1)
  %s895.1 = extractvalue { i64, i64 } %867, 1
  %s895.0 = extractvalue { i64, i64 } %867, 0
; call <kernels::Fp2>::sub
  %869 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s887.0, i64 noundef %s887.1, i64 noundef %s895.0, i64 noundef %s895.1)
  %s896.1 = extractvalue { i64, i64 } %868, 1
  %s896.0 = extractvalue { i64, i64 } %868, 0
  %s897.0 = extractvalue { i64, i64 } %869, 0
  %s897.1 = extractvalue { i64, i64 } %869, 1
; call <kernels::Fp2>::sub
  %870 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s890.0, i64 noundef %s890.1, i64 noundef %s896.0, i64 noundef %s896.1)
  %s898.0 = extractvalue { i64, i64 } %870, 0
  %s898.1 = extractvalue { i64, i64 } %870, 1
  %_0.i59 = getelementptr inbounds nuw i8, ptr %params, i64 1632
  %s899.0 = load i64, ptr %_0.i59, align 8, !noundef !3
  %871 = getelementptr inbounds nuw i8, ptr %params, i64 1640
  %s899.1 = load i64, ptr %871, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %872 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s897.0, i64 noundef %s897.1, i64 noundef %s899.0, i64 noundef %s899.1)
  %s900.0 = extractvalue { i64, i64 } %872, 0
  %s900.1 = extractvalue { i64, i64 } %872, 1
; call <kernels::Fp2>::mul
  %873 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s898.0, i64 noundef %s898.1, i64 noundef %s899.0, i64 noundef %s899.1)
  %s901.0 = extractvalue { i64, i64 } %873, 0
  %s901.1 = extractvalue { i64, i64 } %873, 1
; call <kernels::Fp2>::mul
  %874 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s893.0, i64 noundef %s893.1, i64 noundef %s899.0, i64 noundef %s899.1)
  %s902.0 = extractvalue { i64, i64 } %874, 0
  %s902.1 = extractvalue { i64, i64 } %874, 1
; call <kernels::Fp2>::mul
  %875 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s894.0, i64 noundef %s894.1, i64 noundef %s899.0, i64 noundef %s899.1)
  %s903.0 = extractvalue { i64, i64 } %875, 0
  %s903.1 = extractvalue { i64, i64 } %875, 1
; call <kernels::Fp2>::add
  %876 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s843.0, i64 noundef %s843.1, i64 noundef %s900.0, i64 noundef %s900.1)
  %s904.0 = extractvalue { i64, i64 } %876, 0
  %s904.1 = extractvalue { i64, i64 } %876, 1
; call <kernels::Fp2>::add
  %877 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s844.0, i64 noundef %s844.1, i64 noundef %s901.0, i64 noundef %s901.1)
  %s905.0 = extractvalue { i64, i64 } %877, 0
  %s905.1 = extractvalue { i64, i64 } %877, 1
; call <kernels::Fp2>::add
  %878 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s845.0, i64 noundef %s845.1, i64 noundef %s902.0, i64 noundef %s902.1)
  %s906.0 = extractvalue { i64, i64 } %878, 0
  %s906.1 = extractvalue { i64, i64 } %878, 1
; call <kernels::Fp2>::add
  %879 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s846.0, i64 noundef %s846.1, i64 noundef %s903.0, i64 noundef %s903.1)
  %s907.0 = extractvalue { i64, i64 } %879, 0
  %s907.1 = extractvalue { i64, i64 } %879, 1
  %_0.i58 = getelementptr inbounds nuw i8, ptr %params, i64 1648
  %s908.0 = load i64, ptr %_0.i58, align 8, !noundef !3
  %880 = getelementptr inbounds nuw i8, ptr %params, i64 1656
  %s908.1 = load i64, ptr %880, align 8, !noundef !3
  %_0.i57 = getelementptr inbounds nuw i8, ptr %raw, i64 1120
  %s909.0 = load i64, ptr %_0.i57, align 8, !noundef !3
  %881 = getelementptr inbounds nuw i8, ptr %raw, i64 1128
  %s909.1 = load i64, ptr %881, align 8, !noundef !3
  %_0.i56 = getelementptr inbounds nuw i8, ptr %raw, i64 1136
  %s910.0 = load i64, ptr %_0.i56, align 8, !noundef !3
  %882 = getelementptr inbounds nuw i8, ptr %raw, i64 1144
  %s910.1 = load i64, ptr %882, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %883 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s910.0, i64 noundef %s910.1, i64 noundef %s909.0, i64 noundef %s909.1)
  %s911.0 = extractvalue { i64, i64 } %883, 0
  %s911.1 = extractvalue { i64, i64 } %883, 1
  %_0.i55 = getelementptr inbounds nuw i8, ptr %params, i64 1664
  %s912.0 = load i64, ptr %_0.i55, align 8, !noundef !3
  %884 = getelementptr inbounds nuw i8, ptr %params, i64 1672
  %s912.1 = load i64, ptr %884, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %885 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s909.0, i64 noundef %s909.1, i64 noundef %s912.0, i64 noundef %s912.1)
; call <kernels::Fp2>::mul
  %886 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s911.0, i64 noundef %s911.1, i64 noundef %s912.0, i64 noundef %s912.1)
  %s913.1 = extractvalue { i64, i64 } %885, 1
  %s913.0 = extractvalue { i64, i64 } %885, 0
; call <kernels::Fp2>::add
  %887 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s869.0, i64 noundef %s869.1, i64 noundef %s913.0, i64 noundef %s913.1)
  %s914.1 = extractvalue { i64, i64 } %886, 1
  %s914.0 = extractvalue { i64, i64 } %886, 0
  %s915.0 = extractvalue { i64, i64 } %887, 0
  %s915.1 = extractvalue { i64, i64 } %887, 1
; call <kernels::Fp2>::add
  %888 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s870.0, i64 noundef %s870.1, i64 noundef %s914.0, i64 noundef %s914.1)
  %s916.0 = extractvalue { i64, i64 } %888, 0
  %s916.1 = extractvalue { i64, i64 } %888, 1
  %_0.i259 = getelementptr inbounds nuw i8, ptr %bases, i64 224
  %s917 = load i64, ptr %_0.i259, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %889 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s909.0, i64 noundef %s909.1, i64 noundef %s917)
; call <kernels::Fp2>::mul_base
  %890 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s911.0, i64 noundef %s911.1, i64 noundef %s917)
  %s918.1 = extractvalue { i64, i64 } %889, 1
  %s918.0 = extractvalue { i64, i64 } %889, 0
  %s919.0 = extractvalue { i64, i64 } %890, 0
  %s919.1 = extractvalue { i64, i64 } %890, 1
; call <kernels::Fp2>::sub
  %891 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s908.0, i64 noundef %s908.1, i64 noundef %s918.0, i64 noundef %s918.1)
  %s920.0 = extractvalue { i64, i64 } %891, 0
  %s920.1 = extractvalue { i64, i64 } %891, 1
  %_0.i54 = getelementptr inbounds nuw i8, ptr %params, i64 1680
  %s921.0 = load i64, ptr %_0.i54, align 8, !noundef !3
  %892 = getelementptr inbounds nuw i8, ptr %params, i64 1688
  %s921.1 = load i64, ptr %892, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %893 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s921.0, i64 noundef %s921.1, i64 noundef %s919.0, i64 noundef %s919.1)
  %s922.0 = extractvalue { i64, i64 } %893, 0
  %s922.1 = extractvalue { i64, i64 } %893, 1
  %_0.i53 = getelementptr inbounds nuw i8, ptr %params, i64 1696
  %s923.0 = load i64, ptr %_0.i53, align 8, !noundef !3
  %894 = getelementptr inbounds nuw i8, ptr %params, i64 1704
  %s923.1 = load i64, ptr %894, align 8, !noundef !3
  %_0.i52 = getelementptr inbounds nuw i8, ptr %raw, i64 1152
  %s924.0 = load i64, ptr %_0.i52, align 8, !noundef !3
  %895 = getelementptr inbounds nuw i8, ptr %raw, i64 1160
  %s924.1 = load i64, ptr %895, align 8, !noundef !3
  %_0.i51 = getelementptr inbounds nuw i8, ptr %raw, i64 1168
  %s925.0 = load i64, ptr %_0.i51, align 8, !noundef !3
  %896 = getelementptr inbounds nuw i8, ptr %raw, i64 1176
  %s925.1 = load i64, ptr %896, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %897 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s925.0, i64 noundef %s925.1, i64 noundef %s924.0, i64 noundef %s924.1)
  %s926.0 = extractvalue { i64, i64 } %897, 0
  %s926.1 = extractvalue { i64, i64 } %897, 1
  %_0.i50 = getelementptr inbounds nuw i8, ptr %params, i64 1712
  %s927.0 = load i64, ptr %_0.i50, align 8, !noundef !3
  %898 = getelementptr inbounds nuw i8, ptr %params, i64 1720
  %s927.1 = load i64, ptr %898, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %899 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s924.0, i64 noundef %s924.1, i64 noundef %s927.0, i64 noundef %s927.1)
; call <kernels::Fp2>::mul
  %900 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s926.0, i64 noundef %s926.1, i64 noundef %s927.0, i64 noundef %s927.1)
  %s928.1 = extractvalue { i64, i64 } %899, 1
  %s928.0 = extractvalue { i64, i64 } %899, 0
; call <kernels::Fp2>::add
  %901 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s915.0, i64 noundef %s915.1, i64 noundef %s928.0, i64 noundef %s928.1)
  %s929.1 = extractvalue { i64, i64 } %900, 1
  %s929.0 = extractvalue { i64, i64 } %900, 0
  %s930.0 = extractvalue { i64, i64 } %901, 0
  %s930.1 = extractvalue { i64, i64 } %901, 1
; call <kernels::Fp2>::add
  %902 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s916.0, i64 noundef %s916.1, i64 noundef %s929.0, i64 noundef %s929.1)
  %s931.0 = extractvalue { i64, i64 } %902, 0
  %s931.1 = extractvalue { i64, i64 } %902, 1
  %_0.i258 = getelementptr inbounds nuw i8, ptr %bases, i64 232
  %s932 = load i64, ptr %_0.i258, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %903 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s924.0, i64 noundef %s924.1, i64 noundef %s932)
; call <kernels::Fp2>::mul_base
  %904 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s926.0, i64 noundef %s926.1, i64 noundef %s932)
  %s933.1 = extractvalue { i64, i64 } %903, 1
  %s933.0 = extractvalue { i64, i64 } %903, 0
  %s934.0 = extractvalue { i64, i64 } %904, 0
  %s934.1 = extractvalue { i64, i64 } %904, 1
; call <kernels::Fp2>::sub
  %905 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s923.0, i64 noundef %s923.1, i64 noundef %s933.0, i64 noundef %s933.1)
  %s935.0 = extractvalue { i64, i64 } %905, 0
  %s935.1 = extractvalue { i64, i64 } %905, 1
  %_0.i49 = getelementptr inbounds nuw i8, ptr %params, i64 1728
  %s936.0 = load i64, ptr %_0.i49, align 8, !noundef !3
  %906 = getelementptr inbounds nuw i8, ptr %params, i64 1736
  %s936.1 = load i64, ptr %906, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %907 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s936.0, i64 noundef %s936.1, i64 noundef %s934.0, i64 noundef %s934.1)
  %s937.0 = extractvalue { i64, i64 } %907, 0
  %s937.1 = extractvalue { i64, i64 } %907, 1
  %_0.i48 = getelementptr inbounds nuw i8, ptr %raw, i64 1792
  %s938.0 = load i64, ptr %_0.i48, align 8, !noundef !3
  %908 = getelementptr inbounds nuw i8, ptr %raw, i64 1800
  %s938.1 = load i64, ptr %908, align 8, !noundef !3
  %_0.i47 = getelementptr inbounds nuw i8, ptr %raw, i64 1808
  %s939.0 = load i64, ptr %_0.i47, align 8, !noundef !3
  %909 = getelementptr inbounds nuw i8, ptr %raw, i64 1816
  %s939.1 = load i64, ptr %909, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %910 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s939.0, i64 noundef %s939.1, i64 noundef %s938.0, i64 noundef %s938.1)
  %s940.0 = extractvalue { i64, i64 } %910, 0
  %s940.1 = extractvalue { i64, i64 } %910, 1
; call <kernels::Fp2>::mul
  %911 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s938.0, i64 noundef %s938.1, i64 noundef %s920.0, i64 noundef %s920.1)
  %s941.0 = extractvalue { i64, i64 } %911, 0
  %s941.1 = extractvalue { i64, i64 } %911, 1
; call <kernels::Fp2>::mul
  %912 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s940.0, i64 noundef %s940.1, i64 noundef %s922.0, i64 noundef %s922.1)
  %s942.0 = extractvalue { i64, i64 } %912, 0
  %s942.1 = extractvalue { i64, i64 } %912, 1
; call <kernels::Fp2>::add
  %913 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s938.0, i64 noundef %s938.1, i64 noundef %s940.0, i64 noundef %s940.1)
; call <kernels::Fp2>::add
  %914 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s920.0, i64 noundef %s920.1, i64 noundef %s922.0, i64 noundef %s922.1)
  %s943.1 = extractvalue { i64, i64 } %913, 1
  %s943.0 = extractvalue { i64, i64 } %913, 0
  %s944.0 = extractvalue { i64, i64 } %914, 0
  %s944.1 = extractvalue { i64, i64 } %914, 1
; call <kernels::Fp2>::mul
  %915 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s943.0, i64 noundef %s943.1, i64 noundef %s944.0, i64 noundef %s944.1)
  %s945.0 = extractvalue { i64, i64 } %915, 0
  %s945.1 = extractvalue { i64, i64 } %915, 1
; call <kernels::Fp2>::sub
  %916 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s945.0, i64 noundef %s945.1, i64 noundef %s941.0, i64 noundef %s941.1)
  %s946.0 = extractvalue { i64, i64 } %916, 0
  %s946.1 = extractvalue { i64, i64 } %916, 1
; call <kernels::Fp2>::sub
  %917 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s946.0, i64 noundef %s946.1, i64 noundef %s942.0, i64 noundef %s942.1)
  %s947.0 = extractvalue { i64, i64 } %917, 0
  %s947.1 = extractvalue { i64, i64 } %917, 1
; call <kernels::Fp2>::mul
  %918 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s941.0, i64 noundef %s941.1, i64 noundef %s935.0, i64 noundef %s935.1)
  %s948.0 = extractvalue { i64, i64 } %918, 0
  %s948.1 = extractvalue { i64, i64 } %918, 1
; call <kernels::Fp2>::mul
  %919 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s941.0, i64 noundef %s941.1, i64 noundef %s937.0, i64 noundef %s937.1)
; call <kernels::Fp2>::mul
  %920 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s947.0, i64 noundef %s947.1, i64 noundef %s935.0, i64 noundef %s935.1)
  %s949.1 = extractvalue { i64, i64 } %919, 1
  %s949.0 = extractvalue { i64, i64 } %919, 0
  %s950.0 = extractvalue { i64, i64 } %920, 0
  %s950.1 = extractvalue { i64, i64 } %920, 1
; call <kernels::Fp2>::add
  %921 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s949.0, i64 noundef %s949.1, i64 noundef %s950.0, i64 noundef %s950.1)
  %s951.0 = extractvalue { i64, i64 } %921, 0
  %s951.1 = extractvalue { i64, i64 } %921, 1
; call <kernels::Fp2>::mul
  %922 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s947.0, i64 noundef %s947.1, i64 noundef %s937.0, i64 noundef %s937.1)
; call <kernels::Fp2>::mul
  %923 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s942.0, i64 noundef %s942.1, i64 noundef %s935.0, i64 noundef %s935.1)
  %s952.1 = extractvalue { i64, i64 } %922, 1
  %s952.0 = extractvalue { i64, i64 } %922, 0
  %s953.0 = extractvalue { i64, i64 } %923, 0
  %s953.1 = extractvalue { i64, i64 } %923, 1
; call <kernels::Fp2>::add
  %924 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s952.0, i64 noundef %s952.1, i64 noundef %s953.0, i64 noundef %s953.1)
  %s954.0 = extractvalue { i64, i64 } %924, 0
  %s954.1 = extractvalue { i64, i64 } %924, 1
; call <kernels::Fp2>::mul
  %925 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s942.0, i64 noundef %s942.1, i64 noundef %s937.0, i64 noundef %s937.1)
  %s955.0 = extractvalue { i64, i64 } %925, 0
  %s955.1 = extractvalue { i64, i64 } %925, 1
; call <kernels::Fp2>::add
  %926 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s920.0, i64 noundef %s920.1, i64 noundef %s935.0, i64 noundef %s935.1)
; call <kernels::Fp2>::add
  %927 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s922.0, i64 noundef %s922.1, i64 noundef %s937.0, i64 noundef %s937.1)
  %s956.1 = extractvalue { i64, i64 } %926, 1
  %s956.0 = extractvalue { i64, i64 } %926, 0
; call <kernels::Fp2>::sub
  %928 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s948.0, i64 noundef %s948.1, i64 noundef %s956.0, i64 noundef %s956.1)
  %s957.1 = extractvalue { i64, i64 } %927, 1
  %s957.0 = extractvalue { i64, i64 } %927, 0
  %s958.0 = extractvalue { i64, i64 } %928, 0
  %s958.1 = extractvalue { i64, i64 } %928, 1
; call <kernels::Fp2>::sub
  %929 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s951.0, i64 noundef %s951.1, i64 noundef %s957.0, i64 noundef %s957.1)
  %s959.0 = extractvalue { i64, i64 } %929, 0
  %s959.1 = extractvalue { i64, i64 } %929, 1
  %_0.i46 = getelementptr inbounds nuw i8, ptr %params, i64 1744
  %s960.0 = load i64, ptr %_0.i46, align 8, !noundef !3
  %930 = getelementptr inbounds nuw i8, ptr %params, i64 1752
  %s960.1 = load i64, ptr %930, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %931 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s958.0, i64 noundef %s958.1, i64 noundef %s960.0, i64 noundef %s960.1)
  %s961.0 = extractvalue { i64, i64 } %931, 0
  %s961.1 = extractvalue { i64, i64 } %931, 1
; call <kernels::Fp2>::mul
  %932 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s959.0, i64 noundef %s959.1, i64 noundef %s960.0, i64 noundef %s960.1)
  %s962.0 = extractvalue { i64, i64 } %932, 0
  %s962.1 = extractvalue { i64, i64 } %932, 1
; call <kernels::Fp2>::mul
  %933 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s954.0, i64 noundef %s954.1, i64 noundef %s960.0, i64 noundef %s960.1)
  %s963.0 = extractvalue { i64, i64 } %933, 0
  %s963.1 = extractvalue { i64, i64 } %933, 1
; call <kernels::Fp2>::mul
  %934 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s955.0, i64 noundef %s955.1, i64 noundef %s960.0, i64 noundef %s960.1)
  %s964.0 = extractvalue { i64, i64 } %934, 0
  %s964.1 = extractvalue { i64, i64 } %934, 1
; call <kernels::Fp2>::add
  %935 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s904.0, i64 noundef %s904.1, i64 noundef %s961.0, i64 noundef %s961.1)
  %s965.0 = extractvalue { i64, i64 } %935, 0
  %s965.1 = extractvalue { i64, i64 } %935, 1
; call <kernels::Fp2>::add
  %936 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s905.0, i64 noundef %s905.1, i64 noundef %s962.0, i64 noundef %s962.1)
  %s966.0 = extractvalue { i64, i64 } %936, 0
  %s966.1 = extractvalue { i64, i64 } %936, 1
; call <kernels::Fp2>::add
  %937 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s906.0, i64 noundef %s906.1, i64 noundef %s963.0, i64 noundef %s963.1)
  %s967.0 = extractvalue { i64, i64 } %937, 0
  %s967.1 = extractvalue { i64, i64 } %937, 1
; call <kernels::Fp2>::add
  %938 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s907.0, i64 noundef %s907.1, i64 noundef %s964.0, i64 noundef %s964.1)
  %s968.0 = extractvalue { i64, i64 } %938, 0
  %s968.1 = extractvalue { i64, i64 } %938, 1
  %_0.i45 = getelementptr inbounds nuw i8, ptr %params, i64 1760
  %s969.0 = load i64, ptr %_0.i45, align 8, !noundef !3
  %939 = getelementptr inbounds nuw i8, ptr %params, i64 1768
  %s969.1 = load i64, ptr %939, align 8, !noundef !3
  %_0.i44 = getelementptr inbounds nuw i8, ptr %raw, i64 1184
  %s970.0 = load i64, ptr %_0.i44, align 8, !noundef !3
  %940 = getelementptr inbounds nuw i8, ptr %raw, i64 1192
  %s970.1 = load i64, ptr %940, align 8, !noundef !3
  %_0.i43 = getelementptr inbounds nuw i8, ptr %raw, i64 1200
  %s971.0 = load i64, ptr %_0.i43, align 8, !noundef !3
  %941 = getelementptr inbounds nuw i8, ptr %raw, i64 1208
  %s971.1 = load i64, ptr %941, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %942 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s971.0, i64 noundef %s971.1, i64 noundef %s970.0, i64 noundef %s970.1)
  %s972.0 = extractvalue { i64, i64 } %942, 0
  %s972.1 = extractvalue { i64, i64 } %942, 1
  %_0.i42 = getelementptr inbounds nuw i8, ptr %params, i64 1776
  %s973.0 = load i64, ptr %_0.i42, align 8, !noundef !3
  %943 = getelementptr inbounds nuw i8, ptr %params, i64 1784
  %s973.1 = load i64, ptr %943, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %944 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s970.0, i64 noundef %s970.1, i64 noundef %s973.0, i64 noundef %s973.1)
; call <kernels::Fp2>::mul
  %945 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s972.0, i64 noundef %s972.1, i64 noundef %s973.0, i64 noundef %s973.1)
  %s974.1 = extractvalue { i64, i64 } %944, 1
  %s974.0 = extractvalue { i64, i64 } %944, 0
; call <kernels::Fp2>::add
  %946 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s930.0, i64 noundef %s930.1, i64 noundef %s974.0, i64 noundef %s974.1)
  %s975.1 = extractvalue { i64, i64 } %945, 1
  %s975.0 = extractvalue { i64, i64 } %945, 0
  %s976.0 = extractvalue { i64, i64 } %946, 0
  %s976.1 = extractvalue { i64, i64 } %946, 1
; call <kernels::Fp2>::add
  %947 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s931.0, i64 noundef %s931.1, i64 noundef %s975.0, i64 noundef %s975.1)
  %s977.0 = extractvalue { i64, i64 } %947, 0
  %s977.1 = extractvalue { i64, i64 } %947, 1
  %_0.i257 = getelementptr inbounds nuw i8, ptr %bases, i64 240
  %s978 = load i64, ptr %_0.i257, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %948 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s970.0, i64 noundef %s970.1, i64 noundef %s978)
; call <kernels::Fp2>::mul_base
  %949 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s972.0, i64 noundef %s972.1, i64 noundef %s978)
  %s979.1 = extractvalue { i64, i64 } %948, 1
  %s979.0 = extractvalue { i64, i64 } %948, 0
  %s980.0 = extractvalue { i64, i64 } %949, 0
  %s980.1 = extractvalue { i64, i64 } %949, 1
; call <kernels::Fp2>::sub
  %950 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s969.0, i64 noundef %s969.1, i64 noundef %s979.0, i64 noundef %s979.1)
  %s981.0 = extractvalue { i64, i64 } %950, 0
  %s981.1 = extractvalue { i64, i64 } %950, 1
  %_0.i41 = getelementptr inbounds nuw i8, ptr %params, i64 1792
  %s982.0 = load i64, ptr %_0.i41, align 8, !noundef !3
  %951 = getelementptr inbounds nuw i8, ptr %params, i64 1800
  %s982.1 = load i64, ptr %951, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %952 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s982.0, i64 noundef %s982.1, i64 noundef %s980.0, i64 noundef %s980.1)
  %s983.0 = extractvalue { i64, i64 } %952, 0
  %s983.1 = extractvalue { i64, i64 } %952, 1
  %_0.i40 = getelementptr inbounds nuw i8, ptr %params, i64 1808
  %s984.0 = load i64, ptr %_0.i40, align 8, !noundef !3
  %953 = getelementptr inbounds nuw i8, ptr %params, i64 1816
  %s984.1 = load i64, ptr %953, align 8, !noundef !3
  %_0.i39 = getelementptr inbounds nuw i8, ptr %raw, i64 1216
  %s985.0 = load i64, ptr %_0.i39, align 8, !noundef !3
  %954 = getelementptr inbounds nuw i8, ptr %raw, i64 1224
  %s985.1 = load i64, ptr %954, align 8, !noundef !3
  %_0.i38 = getelementptr inbounds nuw i8, ptr %raw, i64 1232
  %s986.0 = load i64, ptr %_0.i38, align 8, !noundef !3
  %955 = getelementptr inbounds nuw i8, ptr %raw, i64 1240
  %s986.1 = load i64, ptr %955, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %956 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s986.0, i64 noundef %s986.1, i64 noundef %s985.0, i64 noundef %s985.1)
  %s987.0 = extractvalue { i64, i64 } %956, 0
  %s987.1 = extractvalue { i64, i64 } %956, 1
  %_0.i37 = getelementptr inbounds nuw i8, ptr %params, i64 1824
  %s988.0 = load i64, ptr %_0.i37, align 8, !noundef !3
  %957 = getelementptr inbounds nuw i8, ptr %params, i64 1832
  %s988.1 = load i64, ptr %957, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %958 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s985.0, i64 noundef %s985.1, i64 noundef %s988.0, i64 noundef %s988.1)
; call <kernels::Fp2>::mul
  %959 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s987.0, i64 noundef %s987.1, i64 noundef %s988.0, i64 noundef %s988.1)
  %s989.1 = extractvalue { i64, i64 } %958, 1
  %s989.0 = extractvalue { i64, i64 } %958, 0
; call <kernels::Fp2>::add
  %960 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s976.0, i64 noundef %s976.1, i64 noundef %s989.0, i64 noundef %s989.1)
  %s990.1 = extractvalue { i64, i64 } %959, 1
  %s990.0 = extractvalue { i64, i64 } %959, 0
  %s991.0 = extractvalue { i64, i64 } %960, 0
  %s991.1 = extractvalue { i64, i64 } %960, 1
; call <kernels::Fp2>::add
  %961 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s977.0, i64 noundef %s977.1, i64 noundef %s990.0, i64 noundef %s990.1)
  %s992.0 = extractvalue { i64, i64 } %961, 0
  %s992.1 = extractvalue { i64, i64 } %961, 1
  %_0.i256 = getelementptr inbounds nuw i8, ptr %bases, i64 248
  %s993 = load i64, ptr %_0.i256, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %962 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s985.0, i64 noundef %s985.1, i64 noundef %s993)
; call <kernels::Fp2>::mul_base
  %963 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s987.0, i64 noundef %s987.1, i64 noundef %s993)
  %s994.1 = extractvalue { i64, i64 } %962, 1
  %s994.0 = extractvalue { i64, i64 } %962, 0
  %s995.0 = extractvalue { i64, i64 } %963, 0
  %s995.1 = extractvalue { i64, i64 } %963, 1
; call <kernels::Fp2>::sub
  %964 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s984.0, i64 noundef %s984.1, i64 noundef %s994.0, i64 noundef %s994.1)
  %s996.0 = extractvalue { i64, i64 } %964, 0
  %s996.1 = extractvalue { i64, i64 } %964, 1
  %_0.i36 = getelementptr inbounds nuw i8, ptr %params, i64 1840
  %s997.0 = load i64, ptr %_0.i36, align 8, !noundef !3
  %965 = getelementptr inbounds nuw i8, ptr %params, i64 1848
  %s997.1 = load i64, ptr %965, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %966 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s997.0, i64 noundef %s997.1, i64 noundef %s995.0, i64 noundef %s995.1)
  %s998.0 = extractvalue { i64, i64 } %966, 0
  %s998.1 = extractvalue { i64, i64 } %966, 1
  %_0.i35 = getelementptr inbounds nuw i8, ptr %raw, i64 1824
  %s999.0 = load i64, ptr %_0.i35, align 8, !noundef !3
  %967 = getelementptr inbounds nuw i8, ptr %raw, i64 1832
  %s999.1 = load i64, ptr %967, align 8, !noundef !3
  %_0.i34 = getelementptr inbounds nuw i8, ptr %raw, i64 1840
  %s1000.0 = load i64, ptr %_0.i34, align 8, !noundef !3
  %968 = getelementptr inbounds nuw i8, ptr %raw, i64 1848
  %s1000.1 = load i64, ptr %968, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %969 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1000.0, i64 noundef %s1000.1, i64 noundef %s999.0, i64 noundef %s999.1)
  %s1001.0 = extractvalue { i64, i64 } %969, 0
  %s1001.1 = extractvalue { i64, i64 } %969, 1
; call <kernels::Fp2>::mul
  %970 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s999.0, i64 noundef %s999.1, i64 noundef %s981.0, i64 noundef %s981.1)
  %s1002.0 = extractvalue { i64, i64 } %970, 0
  %s1002.1 = extractvalue { i64, i64 } %970, 1
; call <kernels::Fp2>::mul
  %971 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1001.0, i64 noundef %s1001.1, i64 noundef %s983.0, i64 noundef %s983.1)
  %s1003.0 = extractvalue { i64, i64 } %971, 0
  %s1003.1 = extractvalue { i64, i64 } %971, 1
; call <kernels::Fp2>::add
  %972 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s999.0, i64 noundef %s999.1, i64 noundef %s1001.0, i64 noundef %s1001.1)
; call <kernels::Fp2>::add
  %973 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s981.0, i64 noundef %s981.1, i64 noundef %s983.0, i64 noundef %s983.1)
  %s1004.1 = extractvalue { i64, i64 } %972, 1
  %s1004.0 = extractvalue { i64, i64 } %972, 0
  %s1005.0 = extractvalue { i64, i64 } %973, 0
  %s1005.1 = extractvalue { i64, i64 } %973, 1
; call <kernels::Fp2>::mul
  %974 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1004.0, i64 noundef %s1004.1, i64 noundef %s1005.0, i64 noundef %s1005.1)
  %s1006.0 = extractvalue { i64, i64 } %974, 0
  %s1006.1 = extractvalue { i64, i64 } %974, 1
; call <kernels::Fp2>::sub
  %975 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1006.0, i64 noundef %s1006.1, i64 noundef %s1002.0, i64 noundef %s1002.1)
  %s1007.0 = extractvalue { i64, i64 } %975, 0
  %s1007.1 = extractvalue { i64, i64 } %975, 1
; call <kernels::Fp2>::sub
  %976 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1007.0, i64 noundef %s1007.1, i64 noundef %s1003.0, i64 noundef %s1003.1)
  %s1008.0 = extractvalue { i64, i64 } %976, 0
  %s1008.1 = extractvalue { i64, i64 } %976, 1
; call <kernels::Fp2>::mul
  %977 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1002.0, i64 noundef %s1002.1, i64 noundef %s996.0, i64 noundef %s996.1)
  %s1009.0 = extractvalue { i64, i64 } %977, 0
  %s1009.1 = extractvalue { i64, i64 } %977, 1
; call <kernels::Fp2>::mul
  %978 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1002.0, i64 noundef %s1002.1, i64 noundef %s998.0, i64 noundef %s998.1)
; call <kernels::Fp2>::mul
  %979 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1008.0, i64 noundef %s1008.1, i64 noundef %s996.0, i64 noundef %s996.1)
  %s1010.1 = extractvalue { i64, i64 } %978, 1
  %s1010.0 = extractvalue { i64, i64 } %978, 0
  %s1011.0 = extractvalue { i64, i64 } %979, 0
  %s1011.1 = extractvalue { i64, i64 } %979, 1
; call <kernels::Fp2>::add
  %980 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1010.0, i64 noundef %s1010.1, i64 noundef %s1011.0, i64 noundef %s1011.1)
  %s1012.0 = extractvalue { i64, i64 } %980, 0
  %s1012.1 = extractvalue { i64, i64 } %980, 1
; call <kernels::Fp2>::mul
  %981 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1008.0, i64 noundef %s1008.1, i64 noundef %s998.0, i64 noundef %s998.1)
; call <kernels::Fp2>::mul
  %982 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1003.0, i64 noundef %s1003.1, i64 noundef %s996.0, i64 noundef %s996.1)
  %s1013.1 = extractvalue { i64, i64 } %981, 1
  %s1013.0 = extractvalue { i64, i64 } %981, 0
  %s1014.0 = extractvalue { i64, i64 } %982, 0
  %s1014.1 = extractvalue { i64, i64 } %982, 1
; call <kernels::Fp2>::add
  %983 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1013.0, i64 noundef %s1013.1, i64 noundef %s1014.0, i64 noundef %s1014.1)
  %s1015.0 = extractvalue { i64, i64 } %983, 0
  %s1015.1 = extractvalue { i64, i64 } %983, 1
; call <kernels::Fp2>::mul
  %984 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1003.0, i64 noundef %s1003.1, i64 noundef %s998.0, i64 noundef %s998.1)
  %s1016.0 = extractvalue { i64, i64 } %984, 0
  %s1016.1 = extractvalue { i64, i64 } %984, 1
; call <kernels::Fp2>::add
  %985 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s981.0, i64 noundef %s981.1, i64 noundef %s996.0, i64 noundef %s996.1)
; call <kernels::Fp2>::add
  %986 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s983.0, i64 noundef %s983.1, i64 noundef %s998.0, i64 noundef %s998.1)
  %s1017.1 = extractvalue { i64, i64 } %985, 1
  %s1017.0 = extractvalue { i64, i64 } %985, 0
; call <kernels::Fp2>::sub
  %987 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1009.0, i64 noundef %s1009.1, i64 noundef %s1017.0, i64 noundef %s1017.1)
  %s1018.1 = extractvalue { i64, i64 } %986, 1
  %s1018.0 = extractvalue { i64, i64 } %986, 0
  %s1019.0 = extractvalue { i64, i64 } %987, 0
  %s1019.1 = extractvalue { i64, i64 } %987, 1
; call <kernels::Fp2>::sub
  %988 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1012.0, i64 noundef %s1012.1, i64 noundef %s1018.0, i64 noundef %s1018.1)
  %s1020.0 = extractvalue { i64, i64 } %988, 0
  %s1020.1 = extractvalue { i64, i64 } %988, 1
  %_0.i33 = getelementptr inbounds nuw i8, ptr %params, i64 1856
  %s1021.0 = load i64, ptr %_0.i33, align 8, !noundef !3
  %989 = getelementptr inbounds nuw i8, ptr %params, i64 1864
  %s1021.1 = load i64, ptr %989, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %990 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1019.0, i64 noundef %s1019.1, i64 noundef %s1021.0, i64 noundef %s1021.1)
  %s1022.0 = extractvalue { i64, i64 } %990, 0
  %s1022.1 = extractvalue { i64, i64 } %990, 1
; call <kernels::Fp2>::mul
  %991 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1020.0, i64 noundef %s1020.1, i64 noundef %s1021.0, i64 noundef %s1021.1)
  %s1023.0 = extractvalue { i64, i64 } %991, 0
  %s1023.1 = extractvalue { i64, i64 } %991, 1
; call <kernels::Fp2>::mul
  %992 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1015.0, i64 noundef %s1015.1, i64 noundef %s1021.0, i64 noundef %s1021.1)
  %s1024.0 = extractvalue { i64, i64 } %992, 0
  %s1024.1 = extractvalue { i64, i64 } %992, 1
; call <kernels::Fp2>::mul
  %993 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1016.0, i64 noundef %s1016.1, i64 noundef %s1021.0, i64 noundef %s1021.1)
  %s1025.0 = extractvalue { i64, i64 } %993, 0
  %s1025.1 = extractvalue { i64, i64 } %993, 1
; call <kernels::Fp2>::add
  %994 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s965.0, i64 noundef %s965.1, i64 noundef %s1022.0, i64 noundef %s1022.1)
  %s1026.0 = extractvalue { i64, i64 } %994, 0
  %s1026.1 = extractvalue { i64, i64 } %994, 1
; call <kernels::Fp2>::add
  %995 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s966.0, i64 noundef %s966.1, i64 noundef %s1023.0, i64 noundef %s1023.1)
  %s1027.0 = extractvalue { i64, i64 } %995, 0
  %s1027.1 = extractvalue { i64, i64 } %995, 1
; call <kernels::Fp2>::add
  %996 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s967.0, i64 noundef %s967.1, i64 noundef %s1024.0, i64 noundef %s1024.1)
  %s1028.0 = extractvalue { i64, i64 } %996, 0
  %s1028.1 = extractvalue { i64, i64 } %996, 1
; call <kernels::Fp2>::add
  %997 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s968.0, i64 noundef %s968.1, i64 noundef %s1025.0, i64 noundef %s1025.1)
  %s1029.0 = extractvalue { i64, i64 } %997, 0
  %s1029.1 = extractvalue { i64, i64 } %997, 1
  %_0.i32 = getelementptr inbounds nuw i8, ptr %params, i64 1872
  %s1030.0 = load i64, ptr %_0.i32, align 8, !noundef !3
  %998 = getelementptr inbounds nuw i8, ptr %params, i64 1880
  %s1030.1 = load i64, ptr %998, align 8, !noundef !3
  %_0.i31 = getelementptr inbounds nuw i8, ptr %raw, i64 1248
  %s1031.0 = load i64, ptr %_0.i31, align 8, !noundef !3
  %999 = getelementptr inbounds nuw i8, ptr %raw, i64 1256
  %s1031.1 = load i64, ptr %999, align 8, !noundef !3
  %_0.i30 = getelementptr inbounds nuw i8, ptr %raw, i64 1264
  %s1032.0 = load i64, ptr %_0.i30, align 8, !noundef !3
  %1000 = getelementptr inbounds nuw i8, ptr %raw, i64 1272
  %s1032.1 = load i64, ptr %1000, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1001 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1032.0, i64 noundef %s1032.1, i64 noundef %s1031.0, i64 noundef %s1031.1)
  %s1033.0 = extractvalue { i64, i64 } %1001, 0
  %s1033.1 = extractvalue { i64, i64 } %1001, 1
  %_0.i255 = getelementptr inbounds nuw i8, ptr %bases, i64 256
  %s1034 = load i64, ptr %_0.i255, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1002 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1031.0, i64 noundef %s1031.1, i64 noundef %s1034)
; call <kernels::Fp2>::mul_base
  %1003 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1033.0, i64 noundef %s1033.1, i64 noundef %s1034)
  %s1035.1 = extractvalue { i64, i64 } %1002, 1
  %s1035.0 = extractvalue { i64, i64 } %1002, 0
  %s1036.0 = extractvalue { i64, i64 } %1003, 0
  %s1036.1 = extractvalue { i64, i64 } %1003, 1
; call <kernels::Fp2>::sub
  %1004 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1030.0, i64 noundef %s1030.1, i64 noundef %s1035.0, i64 noundef %s1035.1)
  %s1037.0 = extractvalue { i64, i64 } %1004, 0
  %s1037.1 = extractvalue { i64, i64 } %1004, 1
  %_0.i29 = getelementptr inbounds nuw i8, ptr %params, i64 1888
  %s1038.0 = load i64, ptr %_0.i29, align 8, !noundef !3
  %1005 = getelementptr inbounds nuw i8, ptr %params, i64 1896
  %s1038.1 = load i64, ptr %1005, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1006 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1038.0, i64 noundef %s1038.1, i64 noundef %s1036.0, i64 noundef %s1036.1)
  %s1039.0 = extractvalue { i64, i64 } %1006, 0
  %s1039.1 = extractvalue { i64, i64 } %1006, 1
  %_0.i28 = getelementptr inbounds nuw i8, ptr %params, i64 1904
  %s1040.0 = load i64, ptr %_0.i28, align 8, !noundef !3
  %1007 = getelementptr inbounds nuw i8, ptr %params, i64 1912
  %s1040.1 = load i64, ptr %1007, align 8, !noundef !3
  %_0.i254 = getelementptr inbounds nuw i8, ptr %bases, i64 264
  %s1041 = load i64, ptr %_0.i254, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1008 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1031.0, i64 noundef %s1031.1, i64 noundef %s1041)
; call <kernels::Fp2>::mul_base
  %1009 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1033.0, i64 noundef %s1033.1, i64 noundef %s1041)
  %s1042.1 = extractvalue { i64, i64 } %1008, 1
  %s1042.0 = extractvalue { i64, i64 } %1008, 0
  %s1043.0 = extractvalue { i64, i64 } %1009, 0
  %s1043.1 = extractvalue { i64, i64 } %1009, 1
; call <kernels::Fp2>::sub
  %1010 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1040.0, i64 noundef %s1040.1, i64 noundef %s1042.0, i64 noundef %s1042.1)
  %s1044.0 = extractvalue { i64, i64 } %1010, 0
  %s1044.1 = extractvalue { i64, i64 } %1010, 1
  %_0.i27 = getelementptr inbounds nuw i8, ptr %params, i64 1920
  %s1045.0 = load i64, ptr %_0.i27, align 8, !noundef !3
  %1011 = getelementptr inbounds nuw i8, ptr %params, i64 1928
  %s1045.1 = load i64, ptr %1011, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1012 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1045.0, i64 noundef %s1045.1, i64 noundef %s1043.0, i64 noundef %s1043.1)
  %s1046.0 = extractvalue { i64, i64 } %1012, 0
  %s1046.1 = extractvalue { i64, i64 } %1012, 1
  %_0.i26 = getelementptr inbounds nuw i8, ptr %raw, i64 1856
  %s1047.0 = load i64, ptr %_0.i26, align 8, !noundef !3
  %1013 = getelementptr inbounds nuw i8, ptr %raw, i64 1864
  %s1047.1 = load i64, ptr %1013, align 8, !noundef !3
  %_0.i25 = getelementptr inbounds nuw i8, ptr %raw, i64 1872
  %s1048.0 = load i64, ptr %_0.i25, align 8, !noundef !3
  %1014 = getelementptr inbounds nuw i8, ptr %raw, i64 1880
  %s1048.1 = load i64, ptr %1014, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1015 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1048.0, i64 noundef %s1048.1, i64 noundef %s1047.0, i64 noundef %s1047.1)
  %s1049.0 = extractvalue { i64, i64 } %1015, 0
  %s1049.1 = extractvalue { i64, i64 } %1015, 1
; call <kernels::Fp2>::mul
  %1016 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1047.0, i64 noundef %s1047.1, i64 noundef %s1037.0, i64 noundef %s1037.1)
  %s1050.0 = extractvalue { i64, i64 } %1016, 0
  %s1050.1 = extractvalue { i64, i64 } %1016, 1
; call <kernels::Fp2>::mul
  %1017 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1049.0, i64 noundef %s1049.1, i64 noundef %s1039.0, i64 noundef %s1039.1)
  %s1051.0 = extractvalue { i64, i64 } %1017, 0
  %s1051.1 = extractvalue { i64, i64 } %1017, 1
; call <kernels::Fp2>::add
  %1018 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1047.0, i64 noundef %s1047.1, i64 noundef %s1049.0, i64 noundef %s1049.1)
; call <kernels::Fp2>::add
  %1019 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1037.0, i64 noundef %s1037.1, i64 noundef %s1039.0, i64 noundef %s1039.1)
  %s1052.1 = extractvalue { i64, i64 } %1018, 1
  %s1052.0 = extractvalue { i64, i64 } %1018, 0
  %s1053.0 = extractvalue { i64, i64 } %1019, 0
  %s1053.1 = extractvalue { i64, i64 } %1019, 1
; call <kernels::Fp2>::mul
  %1020 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1052.0, i64 noundef %s1052.1, i64 noundef %s1053.0, i64 noundef %s1053.1)
  %s1054.0 = extractvalue { i64, i64 } %1020, 0
  %s1054.1 = extractvalue { i64, i64 } %1020, 1
; call <kernels::Fp2>::sub
  %1021 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1054.0, i64 noundef %s1054.1, i64 noundef %s1050.0, i64 noundef %s1050.1)
  %s1055.0 = extractvalue { i64, i64 } %1021, 0
  %s1055.1 = extractvalue { i64, i64 } %1021, 1
; call <kernels::Fp2>::sub
  %1022 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1055.0, i64 noundef %s1055.1, i64 noundef %s1051.0, i64 noundef %s1051.1)
  %s1056.0 = extractvalue { i64, i64 } %1022, 0
  %s1056.1 = extractvalue { i64, i64 } %1022, 1
; call <kernels::Fp2>::mul
  %1023 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1050.0, i64 noundef %s1050.1, i64 noundef %s1044.0, i64 noundef %s1044.1)
  %s1057.0 = extractvalue { i64, i64 } %1023, 0
  %s1057.1 = extractvalue { i64, i64 } %1023, 1
; call <kernels::Fp2>::mul
  %1024 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1050.0, i64 noundef %s1050.1, i64 noundef %s1046.0, i64 noundef %s1046.1)
; call <kernels::Fp2>::mul
  %1025 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1056.0, i64 noundef %s1056.1, i64 noundef %s1044.0, i64 noundef %s1044.1)
  %s1058.1 = extractvalue { i64, i64 } %1024, 1
  %s1058.0 = extractvalue { i64, i64 } %1024, 0
  %s1059.0 = extractvalue { i64, i64 } %1025, 0
  %s1059.1 = extractvalue { i64, i64 } %1025, 1
; call <kernels::Fp2>::add
  %1026 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1058.0, i64 noundef %s1058.1, i64 noundef %s1059.0, i64 noundef %s1059.1)
  %s1060.0 = extractvalue { i64, i64 } %1026, 0
  %s1060.1 = extractvalue { i64, i64 } %1026, 1
; call <kernels::Fp2>::mul
  %1027 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1056.0, i64 noundef %s1056.1, i64 noundef %s1046.0, i64 noundef %s1046.1)
; call <kernels::Fp2>::mul
  %1028 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1051.0, i64 noundef %s1051.1, i64 noundef %s1044.0, i64 noundef %s1044.1)
  %s1061.1 = extractvalue { i64, i64 } %1027, 1
  %s1061.0 = extractvalue { i64, i64 } %1027, 0
  %s1062.0 = extractvalue { i64, i64 } %1028, 0
  %s1062.1 = extractvalue { i64, i64 } %1028, 1
; call <kernels::Fp2>::add
  %1029 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1061.0, i64 noundef %s1061.1, i64 noundef %s1062.0, i64 noundef %s1062.1)
  %s1063.0 = extractvalue { i64, i64 } %1029, 0
  %s1063.1 = extractvalue { i64, i64 } %1029, 1
; call <kernels::Fp2>::mul
  %1030 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1051.0, i64 noundef %s1051.1, i64 noundef %s1046.0, i64 noundef %s1046.1)
  %s1064.0 = extractvalue { i64, i64 } %1030, 0
  %s1064.1 = extractvalue { i64, i64 } %1030, 1
; call <kernels::Fp2>::add
  %1031 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1037.0, i64 noundef %s1037.1, i64 noundef %s1044.0, i64 noundef %s1044.1)
; call <kernels::Fp2>::add
  %1032 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1039.0, i64 noundef %s1039.1, i64 noundef %s1046.0, i64 noundef %s1046.1)
  %s1065.1 = extractvalue { i64, i64 } %1031, 1
  %s1065.0 = extractvalue { i64, i64 } %1031, 0
; call <kernels::Fp2>::sub
  %1033 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1057.0, i64 noundef %s1057.1, i64 noundef %s1065.0, i64 noundef %s1065.1)
  %s1066.1 = extractvalue { i64, i64 } %1032, 1
  %s1066.0 = extractvalue { i64, i64 } %1032, 0
  %s1067.0 = extractvalue { i64, i64 } %1033, 0
  %s1067.1 = extractvalue { i64, i64 } %1033, 1
; call <kernels::Fp2>::sub
  %1034 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1060.0, i64 noundef %s1060.1, i64 noundef %s1066.0, i64 noundef %s1066.1)
  %s1068.0 = extractvalue { i64, i64 } %1034, 0
  %s1068.1 = extractvalue { i64, i64 } %1034, 1
  %_0.i24 = getelementptr inbounds nuw i8, ptr %params, i64 1936
  %s1069.0 = load i64, ptr %_0.i24, align 8, !noundef !3
  %1035 = getelementptr inbounds nuw i8, ptr %params, i64 1944
  %s1069.1 = load i64, ptr %1035, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1036 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1067.0, i64 noundef %s1067.1, i64 noundef %s1069.0, i64 noundef %s1069.1)
  %s1070.0 = extractvalue { i64, i64 } %1036, 0
  %s1070.1 = extractvalue { i64, i64 } %1036, 1
; call <kernels::Fp2>::mul
  %1037 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1068.0, i64 noundef %s1068.1, i64 noundef %s1069.0, i64 noundef %s1069.1)
  %s1071.0 = extractvalue { i64, i64 } %1037, 0
  %s1071.1 = extractvalue { i64, i64 } %1037, 1
; call <kernels::Fp2>::mul
  %1038 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1063.0, i64 noundef %s1063.1, i64 noundef %s1069.0, i64 noundef %s1069.1)
  %s1072.0 = extractvalue { i64, i64 } %1038, 0
  %s1072.1 = extractvalue { i64, i64 } %1038, 1
; call <kernels::Fp2>::mul
  %1039 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1064.0, i64 noundef %s1064.1, i64 noundef %s1069.0, i64 noundef %s1069.1)
  %s1073.0 = extractvalue { i64, i64 } %1039, 0
  %s1073.1 = extractvalue { i64, i64 } %1039, 1
; call <kernels::Fp2>::add
  %1040 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1026.0, i64 noundef %s1026.1, i64 noundef %s1070.0, i64 noundef %s1070.1)
  %s1074.0 = extractvalue { i64, i64 } %1040, 0
  %s1074.1 = extractvalue { i64, i64 } %1040, 1
; call <kernels::Fp2>::add
  %1041 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1027.0, i64 noundef %s1027.1, i64 noundef %s1071.0, i64 noundef %s1071.1)
  %s1075.0 = extractvalue { i64, i64 } %1041, 0
  %s1075.1 = extractvalue { i64, i64 } %1041, 1
; call <kernels::Fp2>::add
  %1042 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1028.0, i64 noundef %s1028.1, i64 noundef %s1072.0, i64 noundef %s1072.1)
  %s1076.0 = extractvalue { i64, i64 } %1042, 0
  %s1076.1 = extractvalue { i64, i64 } %1042, 1
; call <kernels::Fp2>::add
  %1043 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1029.0, i64 noundef %s1029.1, i64 noundef %s1073.0, i64 noundef %s1073.1)
  %s1077.0 = extractvalue { i64, i64 } %1043, 0
  %s1077.1 = extractvalue { i64, i64 } %1043, 1
  %_0.i23 = getelementptr inbounds nuw i8, ptr %raw, i64 544
  %s1078.0 = load i64, ptr %_0.i23, align 8, !noundef !3
  %1044 = getelementptr inbounds nuw i8, ptr %raw, i64 552
  %s1078.1 = load i64, ptr %1044, align 8, !noundef !3
  %_0.i22 = getelementptr inbounds nuw i8, ptr %raw, i64 560
  %s1079.0 = load i64, ptr %_0.i22, align 8, !noundef !3
  %1045 = getelementptr inbounds nuw i8, ptr %raw, i64 568
  %s1079.1 = load i64, ptr %1045, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1046 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1079.0, i64 noundef %s1079.1, i64 noundef %s1078.0, i64 noundef %s1078.1)
  %s1080.0 = extractvalue { i64, i64 } %1046, 0
  %s1080.1 = extractvalue { i64, i64 } %1046, 1
  %_0.i21 = getelementptr inbounds nuw i8, ptr %params, i64 1952
  %s1081.0 = load i64, ptr %_0.i21, align 8, !noundef !3
  %1047 = getelementptr inbounds nuw i8, ptr %params, i64 1960
  %s1081.1 = load i64, ptr %1047, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1048 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1078.0, i64 noundef %s1078.1, i64 noundef %s1081.0, i64 noundef %s1081.1)
; call <kernels::Fp2>::mul
  %1049 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1080.0, i64 noundef %s1080.1, i64 noundef %s1081.0, i64 noundef %s1081.1)
  %s1082.1 = extractvalue { i64, i64 } %1048, 1
  %s1082.0 = extractvalue { i64, i64 } %1048, 0
; call <kernels::Fp2>::add
  %1050 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s991.0, i64 noundef %s991.1, i64 noundef %s1082.0, i64 noundef %s1082.1)
  %s1083.1 = extractvalue { i64, i64 } %1049, 1
  %s1083.0 = extractvalue { i64, i64 } %1049, 0
  %s1084.0 = extractvalue { i64, i64 } %1050, 0
  %s1084.1 = extractvalue { i64, i64 } %1050, 1
; call <kernels::Fp2>::add
  %1051 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s992.0, i64 noundef %s992.1, i64 noundef %s1083.0, i64 noundef %s1083.1)
  %s1085.0 = extractvalue { i64, i64 } %1051, 0
  %s1085.1 = extractvalue { i64, i64 } %1051, 1
  %_0.i20 = getelementptr inbounds nuw i8, ptr %raw, i64 1088
  %s1086.0 = load i64, ptr %_0.i20, align 8, !noundef !3
  %1052 = getelementptr inbounds nuw i8, ptr %raw, i64 1096
  %s1086.1 = load i64, ptr %1052, align 8, !noundef !3
  %_0.i19 = getelementptr inbounds nuw i8, ptr %raw, i64 1104
  %s1087.0 = load i64, ptr %_0.i19, align 8, !noundef !3
  %1053 = getelementptr inbounds nuw i8, ptr %raw, i64 1112
  %s1087.1 = load i64, ptr %1053, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1054 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1087.0, i64 noundef %s1087.1, i64 noundef %s1086.0, i64 noundef %s1086.1)
  %s1088.0 = extractvalue { i64, i64 } %1054, 0
  %s1088.1 = extractvalue { i64, i64 } %1054, 1
  %_0.i18 = getelementptr inbounds nuw i8, ptr %params, i64 1968
  %s1089.0 = load i64, ptr %_0.i18, align 8, !noundef !3
  %1055 = getelementptr inbounds nuw i8, ptr %params, i64 1976
  %s1089.1 = load i64, ptr %1055, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1056 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1086.0, i64 noundef %s1086.1, i64 noundef %s1089.0, i64 noundef %s1089.1)
; call <kernels::Fp2>::mul
  %1057 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1088.0, i64 noundef %s1088.1, i64 noundef %s1089.0, i64 noundef %s1089.1)
  %s1090.1 = extractvalue { i64, i64 } %1056, 1
  %s1090.0 = extractvalue { i64, i64 } %1056, 0
; call <kernels::Fp2>::add
  %1058 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1084.0, i64 noundef %s1084.1, i64 noundef %s1090.0, i64 noundef %s1090.1)
  %s1091.1 = extractvalue { i64, i64 } %1057, 1
  %s1091.0 = extractvalue { i64, i64 } %1057, 0
  %s1092.0 = extractvalue { i64, i64 } %1058, 0
  %s1092.1 = extractvalue { i64, i64 } %1058, 1
; call <kernels::Fp2>::add
  %1059 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1085.0, i64 noundef %s1085.1, i64 noundef %s1091.0, i64 noundef %s1091.1)
  %s1093.0 = extractvalue { i64, i64 } %1059, 0
  %s1093.1 = extractvalue { i64, i64 } %1059, 1
  %_0.i17 = getelementptr inbounds nuw i8, ptr %raw, i64 1056
  %s1094.0 = load i64, ptr %_0.i17, align 8, !noundef !3
  %1060 = getelementptr inbounds nuw i8, ptr %raw, i64 1064
  %s1094.1 = load i64, ptr %1060, align 8, !noundef !3
  %_0.i16 = getelementptr inbounds nuw i8, ptr %raw, i64 1072
  %s1095.0 = load i64, ptr %_0.i16, align 8, !noundef !3
  %1061 = getelementptr inbounds nuw i8, ptr %raw, i64 1080
  %s1095.1 = load i64, ptr %1061, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1062 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1095.0, i64 noundef %s1095.1, i64 noundef %s1094.0, i64 noundef %s1094.1)
  %s1096.0 = extractvalue { i64, i64 } %1062, 0
  %s1096.1 = extractvalue { i64, i64 } %1062, 1
  %_0.i15 = getelementptr inbounds nuw i8, ptr %params, i64 1984
  %s1097.0 = load i64, ptr %_0.i15, align 8, !noundef !3
  %1063 = getelementptr inbounds nuw i8, ptr %params, i64 1992
  %s1097.1 = load i64, ptr %1063, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1064 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1094.0, i64 noundef %s1094.1, i64 noundef %s1097.0, i64 noundef %s1097.1)
; call <kernels::Fp2>::mul
  %1065 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1096.0, i64 noundef %s1096.1, i64 noundef %s1097.0, i64 noundef %s1097.1)
  %s1098.1 = extractvalue { i64, i64 } %1064, 1
  %s1098.0 = extractvalue { i64, i64 } %1064, 0
; call <kernels::Fp2>::add
  %1066 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1092.0, i64 noundef %s1092.1, i64 noundef %s1098.0, i64 noundef %s1098.1)
  %s1099.1 = extractvalue { i64, i64 } %1065, 1
  %s1099.0 = extractvalue { i64, i64 } %1065, 0
  %s1100.0 = extractvalue { i64, i64 } %1066, 0
  %s1100.1 = extractvalue { i64, i64 } %1066, 1
; call <kernels::Fp2>::add
  %1067 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1093.0, i64 noundef %s1093.1, i64 noundef %s1099.0, i64 noundef %s1099.1)
  %s1101.0 = extractvalue { i64, i64 } %1067, 0
  %s1101.1 = extractvalue { i64, i64 } %1067, 1
  %s1102.0 = load i64, ptr %raw, align 8, !noundef !3
  %1068 = getelementptr inbounds nuw i8, ptr %raw, i64 8
  %s1102.1 = load i64, ptr %1068, align 8, !noundef !3
  %_0.i13 = getelementptr inbounds nuw i8, ptr %raw, i64 16
  %s1103.0 = load i64, ptr %_0.i13, align 8, !noundef !3
  %1069 = getelementptr inbounds nuw i8, ptr %raw, i64 24
  %s1103.1 = load i64, ptr %1069, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1070 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1103.0, i64 noundef %s1103.1, i64 noundef %s1102.0, i64 noundef %s1102.1)
  %s1104.0 = extractvalue { i64, i64 } %1070, 0
  %s1104.1 = extractvalue { i64, i64 } %1070, 1
; call <kernels::Fp2>::add
  %1071 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1074.0, i64 noundef %s1074.1, i64 noundef %s1100.0, i64 noundef %s1100.1)
  %s1105.0 = extractvalue { i64, i64 } %1071, 0
  %s1105.1 = extractvalue { i64, i64 } %1071, 1
; call <kernels::Fp2>::add
  %1072 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1075.0, i64 noundef %s1075.1, i64 noundef %s1101.0, i64 noundef %s1101.1)
  %s1106.0 = extractvalue { i64, i64 } %1072, 0
  %s1106.1 = extractvalue { i64, i64 } %1072, 1
; call <kernels::Fp2>::add
  %1073 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1076.0, i64 noundef %s1076.1, i64 noundef %s100.0, i64 noundef %s100.1)
  %s1107.0 = extractvalue { i64, i64 } %1073, 0
  %s1107.1 = extractvalue { i64, i64 } %1073, 1
; call <kernels::Fp2>::mul
  %1074 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1105.0, i64 noundef %s1105.1)
  %s1108.0 = extractvalue { i64, i64 } %1074, 0
  %s1108.1 = extractvalue { i64, i64 } %1074, 1
; call <kernels::Fp2>::mul
  %1075 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1106.0, i64 noundef %s1106.1)
; call <kernels::Fp2>::mul
  %1076 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1105.0, i64 noundef %s1105.1)
  %s1109.1 = extractvalue { i64, i64 } %1075, 1
  %s1109.0 = extractvalue { i64, i64 } %1075, 0
  %s1110.0 = extractvalue { i64, i64 } %1076, 0
  %s1110.1 = extractvalue { i64, i64 } %1076, 1
; call <kernels::Fp2>::add
  %1077 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1109.0, i64 noundef %s1109.1, i64 noundef %s1110.0, i64 noundef %s1110.1)
  %s1111.0 = extractvalue { i64, i64 } %1077, 0
  %s1111.1 = extractvalue { i64, i64 } %1077, 1
; call <kernels::Fp2>::mul
  %1078 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1107.0, i64 noundef %s1107.1)
; call <kernels::Fp2>::mul
  %1079 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1106.0, i64 noundef %s1106.1)
  %s1112.1 = extractvalue { i64, i64 } %1078, 1
  %s1112.0 = extractvalue { i64, i64 } %1078, 0
  %s1113.0 = extractvalue { i64, i64 } %1079, 0
  %s1113.1 = extractvalue { i64, i64 } %1079, 1
; call <kernels::Fp2>::add
  %1080 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1112.0, i64 noundef %s1112.1, i64 noundef %s1113.0, i64 noundef %s1113.1)
  %s1114.0 = extractvalue { i64, i64 } %1080, 0
  %s1114.1 = extractvalue { i64, i64 } %1080, 1
; call <kernels::Fp2>::mul
  %1081 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1102.0, i64 noundef %s1102.1, i64 noundef %s1077.0, i64 noundef %s1077.1)
; call <kernels::Fp2>::mul
  %1082 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1107.0, i64 noundef %s1107.1)
  %s1115.1 = extractvalue { i64, i64 } %1081, 1
  %s1115.0 = extractvalue { i64, i64 } %1081, 0
  %s1116.0 = extractvalue { i64, i64 } %1082, 0
  %s1116.1 = extractvalue { i64, i64 } %1082, 1
; call <kernels::Fp2>::add
  %1083 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1115.0, i64 noundef %s1115.1, i64 noundef %s1116.0, i64 noundef %s1116.1)
  %s1117.0 = extractvalue { i64, i64 } %1083, 0
  %s1117.1 = extractvalue { i64, i64 } %1083, 1
; call <kernels::Fp2>::mul
  %1084 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1104.0, i64 noundef %s1104.1, i64 noundef %s1077.0, i64 noundef %s1077.1)
  %_0.i253 = getelementptr inbounds nuw i8, ptr %bases, i64 272
  %s1119 = load i64, ptr %_0.i253, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1085 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1078.0, i64 noundef %s1078.1, i64 noundef %s1119)
; call <kernels::Fp2>::mul_base
  %1086 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1080.0, i64 noundef %s1080.1, i64 noundef %s1119)
  %s1120.1 = extractvalue { i64, i64 } %1085, 1
  %s1120.0 = extractvalue { i64, i64 } %1085, 0
; call <kernels::Fp2>::add
  %1087 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1120.0, i64 noundef %s1120.1, i64 noundef %s511.0, i64 noundef %s511.1)
  %s1121.1 = extractvalue { i64, i64 } %1086, 1
  %s1121.0 = extractvalue { i64, i64 } %1086, 0
  %s1122.0 = extractvalue { i64, i64 } %1087, 0
  %s1122.1 = extractvalue { i64, i64 } %1087, 1
; call <kernels::Fp2>::add
  %1088 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1121.0, i64 noundef %s1121.1, i64 noundef %s513.0, i64 noundef %s513.1)
  %s1123.0 = extractvalue { i64, i64 } %1088, 0
  %s1123.1 = extractvalue { i64, i64 } %1088, 1
  %_0.i12 = getelementptr inbounds nuw i8, ptr %params, i64 2000
  %s1124.0 = load i64, ptr %_0.i12, align 8, !noundef !3
  %1089 = getelementptr inbounds nuw i8, ptr %params, i64 2008
  %s1124.1 = load i64, ptr %1089, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1090 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1122.0, i64 noundef %s1122.1, i64 noundef %s1124.0, i64 noundef %s1124.1)
  %s1125.0 = extractvalue { i64, i64 } %1090, 0
  %s1125.1 = extractvalue { i64, i64 } %1090, 1
  %_0.i11 = getelementptr inbounds nuw i8, ptr %raw, i64 32
  %s1126.0 = load i64, ptr %_0.i11, align 8, !noundef !3
  %1091 = getelementptr inbounds nuw i8, ptr %raw, i64 40
  %s1126.1 = load i64, ptr %1091, align 8, !noundef !3
  %_0.i10 = getelementptr inbounds nuw i8, ptr %raw, i64 48
  %s1127.0 = load i64, ptr %_0.i10, align 8, !noundef !3
  %1092 = getelementptr inbounds nuw i8, ptr %raw, i64 56
  %s1127.1 = load i64, ptr %1092, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1093 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1127.0, i64 noundef %s1127.1, i64 noundef %s1126.0, i64 noundef %s1126.1)
  %s1128.0 = extractvalue { i64, i64 } %1093, 0
  %s1128.1 = extractvalue { i64, i64 } %1093, 1
; call <kernels::Fp2>::mul
  %1094 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1126.0, i64 noundef %s1126.1, i64 noundef %s1125.0, i64 noundef %s1125.1)
  %s1129.0 = extractvalue { i64, i64 } %1094, 0
  %s1129.1 = extractvalue { i64, i64 } %1094, 1
; call <kernels::Fp2>::mul
  %1095 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1128.0, i64 noundef %s1128.1, i64 noundef %s1123.0, i64 noundef %s1123.1)
  %s1130.0 = extractvalue { i64, i64 } %1095, 0
  %s1130.1 = extractvalue { i64, i64 } %1095, 1
; call <kernels::Fp2>::add
  %1096 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1126.0, i64 noundef %s1126.1, i64 noundef %s1128.0, i64 noundef %s1128.1)
; call <kernels::Fp2>::add
  %1097 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1125.0, i64 noundef %s1125.1, i64 noundef %s1123.0, i64 noundef %s1123.1)
  %s1131.1 = extractvalue { i64, i64 } %1096, 1
  %s1131.0 = extractvalue { i64, i64 } %1096, 0
  %s1132.0 = extractvalue { i64, i64 } %1097, 0
  %s1132.1 = extractvalue { i64, i64 } %1097, 1
; call <kernels::Fp2>::mul
  %1098 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1131.0, i64 noundef %s1131.1, i64 noundef %s1132.0, i64 noundef %s1132.1)
  %s1133.0 = extractvalue { i64, i64 } %1098, 0
  %s1133.1 = extractvalue { i64, i64 } %1098, 1
; call <kernels::Fp2>::sub
  %1099 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1133.0, i64 noundef %s1133.1, i64 noundef %s1129.0, i64 noundef %s1129.1)
  %s1134.0 = extractvalue { i64, i64 } %1099, 0
  %s1134.1 = extractvalue { i64, i64 } %1099, 1
; call <kernels::Fp2>::sub
  %1100 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1134.0, i64 noundef %s1134.1, i64 noundef %s1130.0, i64 noundef %s1130.1)
  %s1135.0 = extractvalue { i64, i64 } %1100, 0
  %s1135.1 = extractvalue { i64, i64 } %1100, 1
  %_0.i9 = getelementptr inbounds nuw i8, ptr %params, i64 2016
  %s1136.0 = load i64, ptr %_0.i9, align 8, !noundef !3
  %1101 = getelementptr inbounds nuw i8, ptr %params, i64 2024
  %s1136.1 = load i64, ptr %1101, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1102 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1129.0, i64 noundef %s1129.1, i64 noundef %s1136.0, i64 noundef %s1136.1)
  %s1137.0 = extractvalue { i64, i64 } %1102, 0
  %s1137.1 = extractvalue { i64, i64 } %1102, 1
; call <kernels::Fp2>::mul
  %1103 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1135.0, i64 noundef %s1135.1, i64 noundef %s1136.0, i64 noundef %s1136.1)
  %s1138.0 = extractvalue { i64, i64 } %1103, 0
  %s1138.1 = extractvalue { i64, i64 } %1103, 1
; call <kernels::Fp2>::mul
  %1104 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1130.0, i64 noundef %s1130.1, i64 noundef %s1136.0, i64 noundef %s1136.1)
  %s1139.0 = extractvalue { i64, i64 } %1104, 0
  %s1139.1 = extractvalue { i64, i64 } %1104, 1
; call <kernels::Fp2>::add
  %1105 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1108.0, i64 noundef %s1108.1, i64 noundef %s1137.0, i64 noundef %s1137.1)
  %s1140.0 = extractvalue { i64, i64 } %1105, 0
  %s1140.1 = extractvalue { i64, i64 } %1105, 1
; call <kernels::Fp2>::add
  %1106 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1111.0, i64 noundef %s1111.1, i64 noundef %s1138.0, i64 noundef %s1138.1)
  %s1141.0 = extractvalue { i64, i64 } %1106, 0
  %s1141.1 = extractvalue { i64, i64 } %1106, 1
; call <kernels::Fp2>::add
  %1107 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1114.0, i64 noundef %s1114.1, i64 noundef %s1139.0, i64 noundef %s1139.1)
  %s1142.0 = extractvalue { i64, i64 } %1107, 0
  %s1142.1 = extractvalue { i64, i64 } %1107, 1
  %_0.i252 = getelementptr inbounds nuw i8, ptr %bases, i64 280
  %s1143 = load i64, ptr %_0.i252, align 8, !noundef !3
; call <kernels::Fp2>::mul_base
  %1108 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1094.0, i64 noundef %s1094.1, i64 noundef %s1143)
; call <kernels::Fp2>::mul_base
  %1109 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp28mul_base(i64 noundef %s1096.0, i64 noundef %s1096.1, i64 noundef %s1143)
  %s1144.1 = extractvalue { i64, i64 } %1108, 1
  %s1144.0 = extractvalue { i64, i64 } %1108, 0
; call <kernels::Fp2>::add
  %1110 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1144.0, i64 noundef %s1144.1, i64 noundef %s1031.0, i64 noundef %s1031.1)
  %s1145.1 = extractvalue { i64, i64 } %1109, 1
  %s1145.0 = extractvalue { i64, i64 } %1109, 0
  %s1146.0 = extractvalue { i64, i64 } %1110, 0
  %s1146.1 = extractvalue { i64, i64 } %1110, 1
; call <kernels::Fp2>::add
  %1111 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1145.0, i64 noundef %s1145.1, i64 noundef %s1033.0, i64 noundef %s1033.1)
  %s1147.0 = extractvalue { i64, i64 } %1111, 0
  %s1147.1 = extractvalue { i64, i64 } %1111, 1
  %_0.i8 = getelementptr inbounds nuw i8, ptr %params, i64 2032
  %s1148.0 = load i64, ptr %_0.i8, align 8, !noundef !3
  %1112 = getelementptr inbounds nuw i8, ptr %params, i64 2040
  %s1148.1 = load i64, ptr %1112, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1113 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1146.0, i64 noundef %s1146.1, i64 noundef %s1148.0, i64 noundef %s1148.1)
  %s1149.0 = extractvalue { i64, i64 } %1113, 0
  %s1149.1 = extractvalue { i64, i64 } %1113, 1
  %_0.i7 = getelementptr inbounds nuw i8, ptr %raw, i64 64
  %s1150.0 = load i64, ptr %_0.i7, align 8, !noundef !3
  %1114 = getelementptr inbounds nuw i8, ptr %raw, i64 72
  %s1150.1 = load i64, ptr %1114, align 8, !noundef !3
  %_0.i6 = getelementptr inbounds nuw i8, ptr %raw, i64 80
  %s1151.0 = load i64, ptr %_0.i6, align 8, !noundef !3
  %1115 = getelementptr inbounds nuw i8, ptr %raw, i64 88
  %s1151.1 = load i64, ptr %1115, align 8, !noundef !3
; call <kernels::Fp2>::sub
  %1116 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1151.0, i64 noundef %s1151.1, i64 noundef %s1150.0, i64 noundef %s1150.1)
  %s1152.0 = extractvalue { i64, i64 } %1116, 0
  %s1152.1 = extractvalue { i64, i64 } %1116, 1
; call <kernels::Fp2>::mul
  %1117 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1150.0, i64 noundef %s1150.1, i64 noundef %s1149.0, i64 noundef %s1149.1)
  %s1153.0 = extractvalue { i64, i64 } %1117, 0
  %s1153.1 = extractvalue { i64, i64 } %1117, 1
; call <kernels::Fp2>::mul
  %1118 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1152.0, i64 noundef %s1152.1, i64 noundef %s1147.0, i64 noundef %s1147.1)
  %s1154.0 = extractvalue { i64, i64 } %1118, 0
  %s1154.1 = extractvalue { i64, i64 } %1118, 1
; call <kernels::Fp2>::add
  %1119 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1150.0, i64 noundef %s1150.1, i64 noundef %s1152.0, i64 noundef %s1152.1)
; call <kernels::Fp2>::add
  %1120 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1149.0, i64 noundef %s1149.1, i64 noundef %s1147.0, i64 noundef %s1147.1)
  %s1155.1 = extractvalue { i64, i64 } %1119, 1
  %s1155.0 = extractvalue { i64, i64 } %1119, 0
  %s1156.0 = extractvalue { i64, i64 } %1120, 0
  %s1156.1 = extractvalue { i64, i64 } %1120, 1
; call <kernels::Fp2>::mul
  %1121 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1155.0, i64 noundef %s1155.1, i64 noundef %s1156.0, i64 noundef %s1156.1)
  %s1157.0 = extractvalue { i64, i64 } %1121, 0
  %s1157.1 = extractvalue { i64, i64 } %1121, 1
; call <kernels::Fp2>::sub
  %1122 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1157.0, i64 noundef %s1157.1, i64 noundef %s1153.0, i64 noundef %s1153.1)
  %s1158.0 = extractvalue { i64, i64 } %1122, 0
  %s1158.1 = extractvalue { i64, i64 } %1122, 1
; call <kernels::Fp2>::sub
  %1123 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23sub(i64 noundef %s1158.0, i64 noundef %s1158.1, i64 noundef %s1154.0, i64 noundef %s1154.1)
  %s1159.0 = extractvalue { i64, i64 } %1123, 0
  %s1159.1 = extractvalue { i64, i64 } %1123, 1
  %_0.i5 = getelementptr inbounds nuw i8, ptr %params, i64 2048
  %s1160.0 = load i64, ptr %_0.i5, align 8, !noundef !3
  %1124 = getelementptr inbounds nuw i8, ptr %params, i64 2056
  %s1160.1 = load i64, ptr %1124, align 8, !noundef !3
; call <kernels::Fp2>::mul
  %1125 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1153.0, i64 noundef %s1153.1, i64 noundef %s1160.0, i64 noundef %s1160.1)
  %s1161.0 = extractvalue { i64, i64 } %1125, 0
  %s1161.1 = extractvalue { i64, i64 } %1125, 1
; call <kernels::Fp2>::mul
  %1126 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1159.0, i64 noundef %s1159.1, i64 noundef %s1160.0, i64 noundef %s1160.1)
  %s1162.0 = extractvalue { i64, i64 } %1126, 0
  %s1162.1 = extractvalue { i64, i64 } %1126, 1
; call <kernels::Fp2>::mul
  %1127 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23mul(i64 noundef %s1154.0, i64 noundef %s1154.1, i64 noundef %s1160.0, i64 noundef %s1160.1)
  %s1163.0 = extractvalue { i64, i64 } %1127, 0
  %s1163.1 = extractvalue { i64, i64 } %1127, 1
; call <kernels::Fp2>::add
  %1128 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1140.0, i64 noundef %s1140.1, i64 noundef %s1161.0, i64 noundef %s1161.1)
  %s1164.0 = extractvalue { i64, i64 } %1128, 0
  %s1164.1 = extractvalue { i64, i64 } %1128, 1
; call <kernels::Fp2>::add
  %1129 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1141.0, i64 noundef %s1141.1, i64 noundef %s1162.0, i64 noundef %s1162.1)
  %s1165.0 = extractvalue { i64, i64 } %1129, 0
  %s1165.1 = extractvalue { i64, i64 } %1129, 1
; call <kernels::Fp2>::add
  %1130 = tail call fastcc { i64, i64 } @_RNvMCs1s40fzKackN_7kernelsNtB2_3Fp23add(i64 noundef %s1142.0, i64 noundef %s1142.1, i64 noundef %s1163.0, i64 noundef %s1163.1)
  %s1166.0 = extractvalue { i64, i64 } %1130, 0
  %s1166.1 = extractvalue { i64, i64 } %1130, 1
  store i64 %s1164.0, ptr %out, align 8
  %1131 = getelementptr inbounds nuw i8, ptr %out, i64 8
  store i64 %s1164.1, ptr %1131, align 8
  %_0.i3 = getelementptr inbounds nuw i8, ptr %out, i64 16
  store i64 %s1165.0, ptr %_0.i3, align 8
  %1132 = getelementptr inbounds nuw i8, ptr %out, i64 24
  store i64 %s1165.1, ptr %1132, align 8
  %_0.i2 = getelementptr inbounds nuw i8, ptr %out, i64 32
  store i64 %s1166.0, ptr %_0.i2, align 8
  %1133 = getelementptr inbounds nuw i8, ptr %out, i64 40
  store i64 %s1166.1, ptr %1133, align 8
  %_0.i1 = getelementptr inbounds nuw i8, ptr %out, i64 48
  store i64 %s1117.0, ptr %_0.i1, align 8
  %1134 = getelementptr inbounds nuw i8, ptr %out, i64 56
  store i64 %s1117.1, ptr %1134, align 8
  %_0.i = getelementptr inbounds nuw i8, ptr %out, i64 64
  %s1118.1 = extractvalue { i64, i64 } %1084, 1
  %s1118.0 = extractvalue { i64, i64 } %1084, 0
  store i64 %s1118.0, ptr %_0.i, align 8
  %1135 = getelementptr inbounds nuw i8, ptr %out, i64 72
  store i64 %s1118.1, ptr %1135, align 8
  ret void
}

; Function Attrs: nounwind nonlazybind uwtable
declare noundef range(i32 0, 10) i32 @rust_eh_personality(i32 noundef, i32 noundef, i64 noundef, ptr noundef, ptr noundef) unnamed_addr #2

attributes #0 = { mustprogress nofree noinline norecurse nosync nounwind nonlazybind willreturn memory(none) uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #1 = { mustprogress nofree norecurse nosync nounwind nonlazybind willreturn memory(argmem: readwrite) uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }
attributes #2 = { nounwind nonlazybind uwtable "probe-stack"="inline-asm" "target-cpu"="x86-64" }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}

!0 = !{i32 8, !"PIC Level", i32 2}
!1 = !{i32 2, !"RtLibUseGOT", i32 1}
!2 = !{!"rustc version 1.97.1 (8bab26f4f 2026-07-14)"}
!3 = !{}
