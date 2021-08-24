## NEAR - Battlefield

A repository containing contracts and scripts to effectively testing
all aspects of our NEAR instrumentation.

This repository assumes you have the following tool in available
globally through your terminal:

- `neard` (or set `NEARD_BIN` environment variable to `neard` binary)
- `yarn` (1.13+)
- `jq`

### Running

Running the whole battlefield test set is simply a matter of
first installing script dependencies (mainly near.js to interact
with the chain):

```shell
yarn install
```

> This needs to be done only once (and each time new dependencies are added).

For now, a single thing can be done, launching a pre-configured chain and executing some small transactions.

```shell
./bin/run_local.sh
```

> You can use `-r` flag to repeatedly run transactions, use `-h` to see all available flags.

#### Compiling Contracts

Contracts are pre-compiled and checked in as part of this repository. To re-compile them, you will need the following:

- `rustup`
- `wasm32-unknown-unknown` target (install with `rustup target add wasm32-unknown-unknown`)

You can then use the provided `build.sh` script in the contracts directory:

```shell
./contracts/build.sh
```

> **Caveat!** The file `lib.rs` is checksumed and the build will happen only if changed compared to a previous version. If you change the `Cargo.toml`, use `-f` flag on the script.

This checks that `wasm32-unknown-unknown` target is available and installed and compiles the various contracts.
