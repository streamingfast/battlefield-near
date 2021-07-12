#!/usr/bin/env bash

if [[ $DEBUG == "true" ]]; then
  set -x
fi

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"

source "$ROOT/bin/library.sh"

parent_pid="$$"
current_dir=`pwd`

main() {
  pushd "$ROOT" &> /dev/null

  component="all"
  wait_forever=
  pre_hook=

  while getopts "hwp:" opt; do
    case $opt in
      h) usage && exit 0;;
      w) wait_forever=true;;
      p) pre_hook=$OPTARG;;
      \?) usage_error "Invalid option: -$OPTARG";;
    esac
  done
  shift $((OPTIND-1))

  trap cleanup EXIT

  set -e
  if [[ "$pre_hook" != "" ]]; then
    echo "Running pre-hook prior running"
    bash -c "$pre_hook"
  fi

  killall "$neard_bin" &> /dev/null || true

  export RUST_BACKTRACE=1
  export RUST_LOG="debug,actix_web=info"

  recreate_data_directories local_node0 local_node1 local_node2 local_node3
  node0_pub_key=$(cat "${local_node0_data_dir}/node_key.json" | jq -r .public_key)

  echo "Starting Node0 process (log `relpath $local_node0_log_file`)"
  ($local_node0_neard_cmd \
    run $@ 2> "${local_node0_log_file}") &
  node0_pid=$!

  monitor "node0" $node0_pid $parent_pid "$local_node0_log_file" &

  echo "Starting Node1 process (log `relpath $local_node1_log_file`)"
  ($local_node1_neard_cmd \
    run \
     --boot-nodes "${node0_pub_key}@127.0.0.1:24560" \
     $@ 2> "${local_node1_log_file}") &
  node1_pid=$!

  monitor "node1" $node1_pid $parent_pid "$local_node1_log_file" &

  echo "Starting Node2 process (log `relpath $local_node2_log_file`)"
  ($local_node2_neard_cmd \
    run \
     --boot-nodes "${node0_pub_key}@127.0.0.1:24560" \
     $@ 2> "${local_node2_log_file}") &
  node2_pid=$!

  monitor "node2" $node2_pid $parent_pid "$local_node2_log_file" &

  echo "Starting Node3 process (log `relpath $local_node3_log_file`)"
  ($local_node3_neard_cmd \
    run \
     --boot-nodes "${node0_pub_key}@127.0.0.1:24560" \
     $@ 2> "${local_node3_log_file}") &
  node3_pid=$!

  monitor "node3" $node3_pid $parent_pid "$local_node3_log_file" &

  echo "Giving 10s for nodes to be ready"
  sleep 10s

  # while true; do
  #   ethc tx transfer b709229425af40b40573cb0726e95907752933c3 1 --signer-addr=3fb7c223f1ea395bf61c54d61b75e6458bf5474e --gas-limit=32000 --gas-price=1000000000 1> "$ethcLog"
  #   ethc tx transfer 91a7dfffd2874b02337c1055ea6719615a215ccf 1 --signer-addr=b709229425af40b40573cb0726e95907752933c3 --gas-limit=32000 --gas-price=1000000000 1> "$ethcLog"
  #   sleep 10

  #   ethc tx transfer ae8ad35a328d05e9b2717a8aa16a17ff13a5f59b 1 --signer-addr=3fb7c223f1ea395bf61c54d61b75e6458bf5474e --gas-limit=32000 --gas-price=1000000000 1> "$ethcLog"
  #   ethc tx transfer 3fb7c223f1ea395bf61c54d61b75e6458bf5474e 1 --signer-addr=b709229425af40b40573cb0726e95907752933c3 --gas-limit=32000 --gas-price=1000000000 1> "$ethcLog"
  #   sleep 10
  # done

  if [[ $wait_forever == "true" ]]; then
    echo "Sleeping forever"
    sleep_forever
  else
    echo "Waiting 5m and exiting"
    sleep 300
  fi
}

cleanup() {
  kill_pid "node0" $node0_pid
  # kill_pid "node1" $node1_pid
  # kill_pid "node2" $node2_pid
  # kill_pid "sync1" $sync1_pid

  # Let's kill everything else
  kill $( jobs -p ) &> /dev/null
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
  echo "usage: run_local.sh [-w]"
  echo ""
  echo ""
  echo "Options"
  echo "    -h          Display help about this script"
  echo "    -w          Wait forever once all transactions have been included instead of quitting, useful for debugging purposes"
}

main "$@"
