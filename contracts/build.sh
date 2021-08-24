#!/usr/bin/env bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BROWN='\033[0;33m'
NC='\033[0m'

main() {
  pushd "$ROOT" &> /dev/null

  check_rustup_target

  clean=
  force=

  while getopts "hcf" opt; do
    case $opt in
      h) usage && exit 0;;
      f) force=true;;
      c) clean=true;;
      \?) usage_error "Invalid option: -$OPTARG";;
    esac
  done
  shift $((OPTIND-1))

  contracts="$@"
  if [[ $# -lt 1 ]]; then
    contracts=`ls . | grep -v -E ".*\.sh" | grep -v build`
  fi

  if [[ $clean == true ]]; then
    ./clean.sh
    echo ""
  fi

  mkdir -p ./build

  echo "Compiling contracts"
  for contract in $contracts; do
    build_contract "$contract" $force
  done
}

build_contract() {
  name="$1"
  force="$2"

  build_sum="./build/$name.sum"
  src_file="./$name/src/lib.rs"

  debug "Building contract $name (Source $src_file, Checksum $build_sum)"

  source_checksum=`cat $build_sum 2>/dev/null || echo "<File not found>"`
  actual_checksum=`revision $src_file`

  debug "Source $source_checksum | ($build_sum)"
  debug "Actual $actual_checksum | ($src_file)"

  if [[ $force == true || "$source_checksum" != "$actual_checksum" ]]; then
    echo "Compiling contract $1"

    pushd $name > /dev/null
      cargo build --target wasm32-unknown-unknown --release
    popd > /dev/null

    cp "$name/target/wasm32-unknown-unknown/release/battlefield.wasm" ./build
    echo $actual_checksum > $build_sum
  else
    echo "Contract $name source checksum is same as built one, skipping"
  fi
}

revision() {
  cmd=shasum256
  if [[ ! -x "$(command -v $cmd)" ]]; then
    cmd="shasum -a 256"
  fi

  debug "Command for checksum will be '$cmd $@'"
  echo `$cmd $1 | cut -f 1 -d ' '`
}

debug() {
  if [[ $DEBUG != "" ]]; then
    >&2 echo "$@"
  fi
}

check_rustup_target() {
  if rustup target list | grep "wasm32-unknown-unknown" | grep -q installed; then
    return
  fi

  if rustup target list | grep -q "wasm32-unknown-unknown"; then
    echo "Target 'wasm32-unknown-unknown' is available but not installed (tested using"
    echo "'rustup target list | grep \"wasm32-unknown-unknown\" | grep -q installed'). You"
    echo "can install it with the following command"
    echo ""
    echo "    rustup target add wasm32-unknown-unknown"
    echo ""
    exit 1
  else
    echo "Target 'wasm32-unknown-unknown' is not available in your rustup"
    echo "(via a call to 'rustup target list | grep -q \"wasm32-unknown-unknown\"')."
    echo "We are not able to compile the smart contracts for your platform."
    exit 1
  fi
}

usage_error() {
  message="$1"
  exit_code="$2"

  echo "ERROR: $message"
  echo ""
  usage
  exit ${exit_code:-1}
}

usage() {
  echo "usage: build.sh [-c] [<contract> ...]"
  echo ""
  echo "Build all (or specific) contracts found within this folder."
  echo ""
  echo "Options"
  echo "    -c          Clean prior building contracts"
  echo "    -f          Force build skipping checksum checks"
  echo "    -h          Display help about this script"
}

main "$@"
