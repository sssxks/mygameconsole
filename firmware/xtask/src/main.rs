use anyhow::{bail, Context, Result};
use clap::Parser;
use std::{
    fs::{self, File},
    io::Write,
    path::{Path, PathBuf},
    process::Command,
};

const OBJCOPY: &str = "riscv32-unknown-elf-objcopy";
const MAX_WORDS: usize = 4096; // 16 KiB

#[derive(Parser)]
#[command(author, version, about)]
enum Cmd {
    /// Convert <elf> → rom.hex
    Generate { elf: PathBuf },
    /// Build the firmware in release mode and generate rom.hex
    Build,
}

fn main() -> Result<()> {
    match Cmd::parse() {
        Cmd::Generate { elf } => gen_rom_hex(&elf),
        Cmd::Build => build_rom_hex(),
    }
}

// Build firmware and then convert image
fn build_rom_hex() -> Result<()> {
    // Determine repository root (parent of xtask crate)
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();

    // Build firmware (release, default target from config.toml)
    Command::new("cargo")
        .args(["build", "--release"])
        .current_dir(root)
        .status()
        .context("building firmware")?
        .success()
        .then_some(())
        .context("cargo build failed")?;

    // Path to produced ELF
    let elf = root
        .join("target")
        .join("riscv32i-unknown-none-elf")
        .join("release")
        .join("firmware");

    gen_rom_hex(&elf)
}

fn gen_rom_hex(elf: &Path) -> Result<()> {
    if !elf.exists() {
        bail!("ELF not found: {}", elf.display());
    }

    let bin = elf.with_extension("bin");

    Command::new(OBJCOPY)
        .args(["-O", "binary"])
        .arg(elf)
        .arg(&bin)
        .status()
        .context("running objcopy")?
        .success()
        .then_some(())
        .context(format!("{OBJCOPY} failed"))?;

    let mut data = fs::read(&bin).context("reading .bin")?;
    while data.len() % 4 != 0 {
        data.push(0);
    }

    let mut words: Vec<u32> = data
        .chunks_exact(4)
        .map(|c| u32::from_le_bytes(c.try_into().unwrap()))
        .collect();

    if words.len() > MAX_WORDS {
        eprintln!(
            "warning: firmware exceeds {} bytes – truncating",
            MAX_WORDS * 4
        );
        words.truncate(MAX_WORDS);
    } else {
        words.resize(MAX_WORDS, 0);
    }

    // Place ROM inside src/memory for Verilog sim/builds
    let hex_path = repo_root(elf)?.parent().expect("no parent of repo root. place this ").join(["src", "memory", "rom.hex"].iter().collect::<PathBuf>());
    if let Some(parent) = hex_path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut f = File::create(&hex_path)?;
    for w in words {
        writeln!(f, "{w:08x}")?;
    }

    println!("Generated {}", hex_path.display());
    Ok(())
}

fn repo_root(p: &Path) -> Result<PathBuf> {
    // ascend four levels from .../firmware/target/…/firmware
    p.ancestors()
        .nth(4)
        .context("cannot determine repo root")
        .map(PathBuf::from)
}
