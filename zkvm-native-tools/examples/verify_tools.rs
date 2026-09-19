//! Public tool-provenance check; does not read a proof or private witness.
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args_os().collect();
    if args.len() != 2 {
        return Err("usage: verify_tools NATIVE_TOOL_DIRECTORY".into());
    }
    let checked = zk60_native_tools::validate_tool_directory(std::path::Path::new(&args[1]))?;
    println!("{}", zk60_native_tools::PINNED_SOURCE);
    for file in checked.files {
        println!("{} {} {}", file.sha256, file.len, file.name);
    }
    Ok(())
}
