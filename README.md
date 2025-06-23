build firmware:

```
cd firmware
cargo xtask build-rom-hex
```

ensure firmware is built before running vivado.

build using vivado. download a project archive and then extract it to the project/ directory.

the script will update any source and run synthesis:
the script assumes wsl environment (because i am using wsl)
```
vivado/vivado.sh
```

clean vivado build directory:

```
vivado/vivado.sh clean
```