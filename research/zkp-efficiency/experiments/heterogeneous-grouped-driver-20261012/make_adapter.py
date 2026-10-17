"""Mechanical, research-only serial adapter of the PINNED native evaluator.

UNCOMPILED output belongs alongside driver.rs in one owner-selected module.
No production files are touched. The source itself remains the review anchor.
"""
from pathlib import Path
HERE=Path(__file__).resolve().parent
native=(HERE/'native/zkp-core__src__sumcheck__grouped.rs').read_text()
s=native.split('#[cfg(test)]')[0]
s=s.replace('//! Experimental equality-factored round evaluator. No transcript or RNG access.',
'''//! UNCOMPILED, UNAPPLIED serial mixed-table GroupedEqRounds adapter.
//! Include alongside driver.rs in ONE owner-selected module; Python is tested.
//! No native compilation or masked/receipt validation has occurred.''')
s=s.replace('use super::SumcheckRounds;\n','').replace('use crate::field::Fp2;\n','')
s=s.replace('use crate::mle::{eq_table_msb, interpolate_eval};','use crate::mle::eq_table_msb;')
s=s.replace('use rayon::prelude::*;\n','')
s=s.replace("&'a mut Vec<Vec<Fp2>>","&'a mut Tables")
s=s.replace("!tables.is_empty()", "!tables.entries.is_empty()")
s=s.replace('let len = tables[0].len();\n        assert!(len.is_power_of_two() && tables.iter().all(|t| t.len() == len));\n        let n_vars = len.trailing_zeros() as usize;',
'''assert_eq!(tables.next, 0);
        let n_vars = tables.n;''')
s=s.replace('let k = self.tables.len();\n        let half = self.tables[0].len() / 2;\n        let small = half * k <= 1 << 16;\n        let chunk = if small { half.max(1) } else { half.min(1024) };',
'''let k = self.tables.entries.len();
        let half = 1usize << (self.n_vars - j - 1);
        let chunk = half.min(1024).max(1);''')
s=s.replace('let mut dif = vec![Fp2::ZERO; k];','let mut dif = vec![Fp2::ZERO; k];\n            let mut high = vec![Fp2::ZERO; k];')
s=s.replace('for (t, tb) in self.tables.iter().enumerate() {\n                    cur[t] = tb[i];\n                    dif[t] = tb[i + half].sub(tb[i]);\n                }',
'''self.tables.row(i, &mut cur).expect("admitted low row");
                self.tables.row(i + half, &mut high).expect("admitted high row");
                for t in 0..k { dif[t] = high[t].sub(cur[t]); }''')
lo=s.index('let mut hs = if small { part(0) } else {');hi=s.index('\n        let mut result =',lo)
s=s[:lo]+'''let mut hs = zero();
        for ci in 0..half.div_ceil(chunk) {
            for (a, b) in hs.iter_mut().zip(part(ci)) {
                for (v, w) in a.iter_mut().zip(b) { *v = v.add(w); }
            }
        }'''+s[hi:]
lo=s.index('let half = self.tables[0].len() / 2;');hi=s.index('\n        self.next += 1;',lo)
s=s[:lo]+'''// One bind per table after all immutable round reads/reductions.
        self.tables.bind(r);'''+s[hi:]
s=s.replace('self.tables.iter().map(|t| t[0]).collect()','self.tables.finals()')
assert 'par_iter' not in s and 'tables[0]' not in s and "&'a mut Vec<Vec<Fp2>>" not in s
(HERE/'grouped_adapter.rs').write_text(s)
print('Saved unapplied, uncompiled serial mixed-table adapter:',len(s),'bytes')
