    #[test]
    fn accuracy_public_context_checks_stack_denominator_presence_and_symmetric_words() {
        use crate::private_block::{BlockPublic,trained_statement::LayerRecord};
        for original in development_shapes() {
            let(sh,data,public,ff)=case(original,3);
            let missing=BlockPublic::new(public.clone(),ff.clone());
            assert!(missing.check_accuracy_for_shape(&sh).unwrap_err().contains("missing"));
            let blk=missing.with_accuracy(data.clone());
            blk.check_accuracy_for_shape(&sh).unwrap();
            assert!(blk.check_for_shape(&sh).unwrap_err().contains("R13 proof profiles remain disabled"));
            let wrong=sh.clone().with_accuracy_gate_shift(if sh.accuracy_gate_shift==17 {18} else {17}).unwrap();
            assert!(blk.check_accuracy_for_shape(&wrong).unwrap_err().contains("denominator"));
            assert!(blk.check_accuracy_for_shape(&Shape::toy()).is_err());
            let mut bad_public=public.clone();bad_public.wq[0]=i8::MIN;
            assert!(BlockPublic::new(bad_public,ff.clone()).with_accuracy(data.clone())
                .check_accuracy_for_shape(&sh).unwrap_err().contains("symmetric"));
            let rec=LayerRecord::of_block(0,&blk,vec![]);
            assert_eq!(rec.accuracy_gate_shift,Some(data.folds().gate.shift));
            let raw:Vec<u8>=data.raw_tables().iter().flatten().flat_map(|w|w.to_le_bytes()).collect();
            assert_eq!(rec.table_sha256[2],crate::private_block::trained_block::sha256(&raw));
            let legacy:Vec<u8>=ff.act.iter().flat_map(|w|w.to_le_bytes()).collect();
            assert_ne!(rec.table_sha256[2],crate::private_block::trained_block::sha256(&legacy));
        }
    }
