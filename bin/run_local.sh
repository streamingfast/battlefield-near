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
  (FIREHOSE_ENABLED=true $local_node1_neard_cmd \
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

  echo "Giving 5s for nodes to be ready"
  sleep 5s

  keys="${BOOT_DIR}/local/keystore/local"
  near_cmd="near --node_url http://localhost:3030 --network_id local"
  # near_log_file="${RUN_DIR}/run_local.log"

  # Execute all transactions
  node -r ts-node/register src/index.ts

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
  kill_pid "node1" $node1_pid
  kill_pid "node2" $node2_pid
  kill_pid "node3" $node3_pid

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
