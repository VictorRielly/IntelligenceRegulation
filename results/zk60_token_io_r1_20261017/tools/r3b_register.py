"""Stage R3-B: register the R3 token-I/O run profile (CS-7 arm, the token profile list, the census list)."""
import sys
ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io/hashline/src/private_block"


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70], s.count(old))
    open(path, "w").write(s.replace(old, new))


rep(ROOT + "/run.rs",
    "        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32 => Shape::tinyllama_trained(32, &cal, sh.f_e),\n",
    "        RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32 => Shape::tinyllama_trained(32, &cal, sh.f_e),\n"
    "        RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32 => Shape::llama3_8b_t32_trained(&cal, sh.f_e),\n")
rep(ROOT + "/run.rs",
    "pub(crate) const TOKEN_IO_RUN_PROFILES: [&str; 2] = [RUN_PROFILE_TOKEN_IO_RUNG_TC, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32];",
    "pub(crate) const TOKEN_IO_RUN_PROFILES: [&str; 3] = [RUN_PROFILE_TOKEN_IO_RUNG_TC, RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32];")
rep(ROOT + "/token_io.rs",
    "        (super::run::RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, Shape::tinyllama_trained(32, &r2_calibration(), R2_F_E).expect(\"the trained TinyLlama T32 shape\")),\n",
    "        (super::run::RUN_PROFILE_TOKEN_IO_TINYLLAMA_T32, Shape::tinyllama_trained(32, &r2_calibration(), R2_F_E).expect(\"the trained TinyLlama T32 shape\")),\n"
    "        (super::run::RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32, Shape::llama3_8b_t32_trained(&r3_calibration(), R3_F_E).expect(\"the trained Llama-3-8B T32 shape\")),\n")
print("registered")
