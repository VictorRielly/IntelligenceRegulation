move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let l2 = |o: usize| at(o).add(at(o + 1).mul_base(b_p1));
                // `limbs` with the weights as base constants and the `256^0`
                // multiply by one dropped: the first limb IS the running sum
                let lb = |w: &[(usize, Fp)]| match w.split_first() {
                    None => Fp2::ZERO,
                    Some(((i0, _), rest)) => rest.iter().fold(v[*i0], |a, (i, c)| a.add(v[*i].mul_base(*c))),
                };
                let (x, y, ao, x1, d) = (at(A_X), at(A_Y), at(A_AO), at(A_X1), v[id]);
                let (nm, x2, z16, dm) = (at(A_YM), at(A_X2), at(A_Z16), v[idm]);
                let (nr, ns) = (lb(&w_nr), lb(&w_ns));
                let (mr, ms) = (lb(&w_mr), lb(&w_ms));
                // **STAGE 35, LEVER (b)(ii): the two sub-products this arm
                // recomputes.** `k_den * d` is formed twice — once inside
                // c0's `k_den.mul(y).mul(d)`, which is `(k_den * d) * y`
                // reassociated, and once outright in c1 — and `k_den * dm`
                // twice in the same way in c6 and c7. Each is formed once
                // here. They are the ONLY pair the check's §5 found and the
                // only pair reading this arm turns up: `at(p)`, the two norm
                // gains, `delta`-like intermediates and the four limb folds
                // are already shared by a `let`.
                let (kd, kdm) = (d.mul_base(b_den), dm.mul_base(b_den));
                let c0 = v[ig].mul(x).mul_base(b_num).add(d.mul_base(b_dv)).sub(kd.mul(y)).sub(nr);
                let c1 = ns.add(nr).add(Fp2::ONE).sub(kd);
                let c2 = x.add(k(32768)).sub(l2(A_XL0));
                let c3 = ao.add(k(32768)).sub(l2(A_AL0));
                let c4 = x1.add(k(32768)).sub(l2(A_X1L0));
                let c5 = x1.sub(x).sub(ao);
                // norm_m: the identical relation with gamma_m and xres1 (T1 C.1)
                let c6 = v[igm].mul(x1).mul_base(b_num_m).add(dm.mul_base(b_dv)).sub(kdm.mul(nm)).sub(mr);
                let c7 = ms.add(mr).add(Fp2::ONE).sub(kdm);
                // residual 2 and z16's int16 class (T1 C.2, T2 C.2)
                let c8 = x2.add(k(32768)).sub(l2(A_X2L0));
                let c9 = x2.sub(x1).sub(z16);
                let c10 = z16.add(k(32768)).sub(l2(A_ZL0));
                let g = gd.at(v);
                // **STAGE 35, LEVER (b)(i): the support gate hoisted out of
                // the clause batch.** `sum_i mu_i g c_i = g sum_i mu_i c_i`
                // is distributivity in a commutative ring, and this one is
                // exact — `Fp` keeps canonical representatives everywhere
                // (`zkp-core/src/field.rs:1-9`), so the reassociation is not
                // an approximation and the field element out is the same
                // word. ELEVEN multiplications by `g` become ONE. The
                // stage-34 IR already encodes THIS grouping, so its equality
                // oracle covers the rewrite at every registered shape and
                // both pad branches, and `s35_tests` compares it against the
                // `89e393f` body on every definition.
                let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]) {
                    clauses = clauses.add(m.mul(c));
                }
                let zc = helper_sum(v, &lks, h0, alpha, &mu[11..]).add(pz.eval(v)).add(g.mul(clauses));
                let host_wo = ao.mul_base(b_ao).add(at(A_RAL)).sub(k_ao_half);
                let host_dmm = z16.mul_base(b_z).add(at(A_RDL)).sub(k_z_half);
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_wo)).add(nu[1].mul(v[2]).mul(g).mul(host_dmm))
            }
