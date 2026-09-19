#![no_main]
use risc0_zkvm::guest::env;
use zk60_block_model::{Model,Request,MODEL_BYTES,REQUEST_BYTES};
use zk60_block_statement::{Statement,JOURNAL_BYTES};
risc0_zkvm::guest::entry!(main);

fn main() {
    let mut model=vec![0u8;MODEL_BYTES];
    let mut request=vec![0u8;REQUEST_BYTES];
    let mut policy=[0u8;JOURNAL_BYTES];
    env::read_slice(&mut model);
    env::read_slice(&mut request);
    env::read_slice(&mut policy);
    let model=Model::decode(&model).expect("public model refused");
    let request=Request::decode(&request).expect("private request refused");
    let expected=Statement::decode(&policy).expect("policy refused");
    let (actual,_)=request.compute(&model).expect("computation refused");
    assert!(actual==expected,"policy mismatch");
    env::commit_slice(&actual.encode());
}
