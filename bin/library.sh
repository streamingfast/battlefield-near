export BIN_DIR=${ROOT}/bin
export BOOT_DIR=${ROOT}/boot
export RUN_DIR=${ROOT}/run

export neard_bin=${NEARD_BIN:-"neard"}

export local_node0_boot_dir="$BOOT_DIR/local/node0"
export local_node0_data_dir="$RUN_DIR/data/local/node0"
export local_node0_log_file="$RUN_DIR/data/local/node0.log"
export local_node0_neard_cmd="$neard_bin --home ${local_node0_data_dir} --verbose 10"

export local_node1_boot_dir="$BOOT_DIR/local/node1"
export local_node1_data_dir="$RUN_DIR/data/local/node1"
export local_node1_log_file="$RUN_DIR/data/local/node1.log"
export local_node1_neard_cmd="$neard_bin --home ${local_node1_data_dir} --verbose 10"

export local_node2_boot_dir="$BOOT_DIR/local/node2"
export local_node2_data_dir="$RUN_DIR/data/local/node2"
export local_node2_log_file="$RUN_DIR/data/local/node2.log"
export local_node2_neard_cmd="$neard_bin --home ${local_node2_data_dir} --verbose 10"

export local_node3_boot_dir="$BOOT_DIR/local/node3"
export local_node3_data_dir="$RUN_DIR/data/local/node3"
export local_node3_log_file="$RUN_DIR/data/local/node3.log"
export local_node3_neard_cmd="$neard_bin --home ${local_node3_data_dir} --verbose 10"

recreate_data_directories() {
  local component
  for component in "$@"; do
    # Dynamically access like `<something>_data_dir`
    boot_dir=`dynamic_var_name=${component}_boot_dir; echo ${!dynamic_var_name}`
    data_dir=`dynamic_var_name=${component}_data_dir; echo ${!dynamic_var_name}`

    rm -rf "$data_dir" && mkdir -p "$data_dir" &> /dev/null
    cp -R "${boot_dir}"/* "${data_dir}"
    cp "$BOOT_DIR/local/genesis.json" "${data_dir}/"
  done
}

# usage <name> <pid> <parent_pid> [<process_log>]
monitor() {
  name=$1
  pid=$2
  parent_pid=$3
  process_log=

  if [[ $# -gt 3 ]]; then
    process_log=$4
  fi

  while true; do
    if ! kill -0 $pid &> /dev/null; then
      sleep 2

      echo "Process $name ($pid) died, exiting parent"
      if [[ "$process_log" != "" ]]; then
        echo "Last 75 lines of log"
        tail -n 75 $process_log

        echo
        echo "See full logs with 'less `relpath $process_log`'"
      fi

      kill -s TERM $parent_pid &> /dev/null
      exit 0
    fi

    sleep 1
  done
}

kill_pid() {
  name=$1
  pid=$2

  if [[ $pid != "" ]]; then
    echo "Closing $name process..."
    kill -s TERM $pid &> /dev/null || true
    wait "$pid" &> /dev/null
  fi
}

sleep_forever() {
    while true; do sleep 1000000; done
}

to_dec() {
    value=`echo $1 | awk '{print toupper($0)}'`
    echo "ibase=16; ${value}" | bc
}

relpath() {
  if [[ $1 =~ /* ]]; then
    # Works only if path is already absolute and do not contain ,
    echo "$1" | sed s,$PWD,.,g
  else
    # Print as-is
    echo $1
  fi
}

# public_key <key_file_path>
public_key() {
  printf $(cat "$1" | jq -r .public_key)
}