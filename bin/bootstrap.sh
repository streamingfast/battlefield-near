#!/usr/bin/env bash

set -e

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

source "${ROOT}/bin/library.sh"

main() {
  pushd "$ROOT" &> /dev/null

  while getopts "h" opt; do
    case $opt in
      h) usage && exit 0;;
      \?) usage_error "Invalid option: -$OPTARG";;
    esac
  done
  shift $((OPTIND-1))

  echo -n "Enter network name (no validation): "
  read network

  log_dir="${RUN_DIR}/bootstrap"
  log_file="${log_dir}/${network}.log"
  network_boot_dir="${BOOT_DIR}/${network}"

  if [[ -d "$network_boot_dir" ]]; then
    echo -n "This will delete existing network (${network_boot_dir}), continue (y/n)? "
    read answer

    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      exit 0
    fi
  fi

  rm -rf "${log_dir}" && mkdir -p "$log_dir" &> /dev/null
  rm -rf "${network_boot_dir}" && mkdir -p "$network_boot_dir" &> /dev/null

  nodes=( "node0" "node1" "node2" "node3" )
  for node in "${nodes[@]}"; do
    node_dir="${network_boot_dir}/${node}"
    echo "Bootstrapping ${node} (in ${node_dir}" >> "${log_file}"
    mkdir -p "${node_dir}" &> /dev/null

    $neard_bin --home "${node_dir}" \
    init \
    --chain-id "${network}" \
    --fast \
    --account-id "${node}" \
    2>> "${log_file}"

    if [[ "${node}" == "node0" ]]; then
      mv "${node_dir}/genesis.json" "${network_boot_dir}"
    fi

    rm -rf "${node_dir}/genesis.json"
    echo "" >> "${log_file}"
  done

  echo ""
  echo "Edit ${network_boot_dir}/genesis.json files with those modifications:"
  echo ""
  echo " .num_block_producer_seats = 4"
  echo " .num_block_producer_seats_per_shard[0] = 4"
  echo " .validators[0] = { \"account_id\": \"node0\", \"public_key\": \"ed25519:<validator_key_node0>\", \"amount\": \"50000000000000000000000000000000\" }"
  echo " .validators[1] = { \"account_id\": \"node1\", \"public_key\": \"ed25519:<validator_key_node1>\", \"amount\": \"50000000000000000000000000000000\" }"
  echo " .validators[2] = { \"account_id\": \"node2\", \"public_key\": \"ed25519:<validator_key_node2>\", \"amount\": \"50000000000000000000000000000000\" }"
  echo " .validators[3] = { \"account_id\": \"node3\", \"public_key\": \"ed25519:<validator_key_node3>\", \"amount\": \"50000000000000000000000000000000\" }"
  echo " .records[0] = { <copy and adjust node0 structure > }"
  echo ""

  echo "Completed"
}

log() {
  echo "$@"
  echo "$@" >> $genesis_log
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
  echo "usage: bootstrap [-b]"
  echo ""
  echo "Generate all necessary data to boostrap local network for this chain."
  echo "The bootstrap phase generates keys for all hardcoded account as well as the"
  echo "genesis block information from the genesis configuration."
  echo ""
  echo "Most instructions and related information can be obtain from this"
  echo "docs post: https://docs.near.org/docs/develop/node/validator/compile-and-run-a-node"

  echo ""
  echo "Options"
  echo "    -h          Display help about this script"
}

main "$@"
