#!/usr/bin/env zsh

# This script runs a Docker container with the specified version and port.
# When -j or -t option is provided, Jupyter Notebook or TensorBoard is directly
# set up with the same port. Note that both options cannot be used at once.

# Mar. 17, 2023 Akinori F. Ebihara

# Set default values
docker_container="afemod_lambda22_pytorch2:ebihara"
port=42914
user="afe"
home="/home/$user"
docker_preferences="-it --rm --gpus all -v $home:$home -u $user"
isport=
isjupyter=
tb_logdir=

# Define a function to print the help message
function print_help() {
  echo "Usage: $0 [-v 1|2] [-p port] [-h]"
  echo "Run a Docker container with the specified version and port."
  echo "  -p port   Specify the port to use (to use default: $port, set -p '')."
  echo "  -j        Jupyter notebook option. Directly activate the notebook with the port."
  echo "  -t logdir TensorBoard option. Directly activate the TensorBoard with the port."
  echo "  -h        Show this help message and exit."
}

function restart_nvidia_uvm() {
    echo "Rebooting nvidia_uvm..."
    sudo rmmod nvidia_uvm
    sudo modprobe nvidia_uvm
    xset dpms force off
    sleep 2
    xset dpms force on
}

function wait_for_input(){
  # Get container ID
  container_id=$(docker ps -l -q)

  # Show Jupyter / Tensorboard logs running background
  sleep $wait_for # allow the container to print logs
  docker logs $container_id

  while true; do
      echo "Select an option:"
      echo "1. Restart nvidia_uvm and toggle xset dpms"
      echo "2. Run nvidia-smi"
      echo "3. Check GPU availability"
      echo "4. Print container logs"
      echo "5. Quit with shutting down the container"
      echo -n "Enter a number: "
      read input

      case $input in
          1)
              restart_nvidia_uvm
              ;;
          2)
              nvidia-smi
              ;;
          3)
              docker exec $container_id python /home/afe/Dropbox/PYTHON/SPRTproject/PytorchMAUS_dev/gpu_test_pytorch.py
              ;;
          4)
              docker logs $container_id
              ;;
          5)
              echo "Exiting..."
              # docker exec $container_id pkill -f "jupyter-notebook"
              docker stop $container_id
              break
              ;;
          *)
              echo "Invalid input. Please try again."
              ;;
      esac
  done
}

function build_cmd(){
    version=$1
    port=$2
    isjupyter=$3
    tb_logdir=$4

    # Build the docker run command based on the version and port
    cmd="docker run $docker_preferences"

    # portforward if -p option is provided
    if [[ -n $isport ]]; then
    cmd="$cmd -d -p $port:$port"
    echo "portforward option enabled: $port -> $port."
    fi

    # specify a container
    cmd="$cmd $docker_container /bin/bash"

    # Jupyter notebook option
    if [[ -n $isjupyter ]]; then
    echo "Setting up Jupyter Notebook."
    cmd="$cmd -c 'bash -c \"jupyter notebook --no-browser --allow-root --ip=0.0.0.0 --port=$port &\" && bash'"
    wait_for=0.3 #sec
    fi

    # TensorBoard option
    if [[ -n $tb_logdir ]]; then
    echo "Setting up TensorBoard."
    cmd="$cmd -c 'bash -c \"tensorboard --logdir=$tb_logdir --host=0.0.0.0 --port=$port &\" && bash'"
    wait_for=3 #sec
    fi
}


######################### main #########################

# Parse command-line options and arguments
while getopts ":v:p:jt:h" opt; do
  case $opt in
    v) version=$OPTARG;;
    p) isport=1
      if [[ -n $OPTARG ]]; then
        port=$OPTARG
      fi
      ;;
    j) isjupyter=1, isport=1;;
    t) isport=1
      if [[ -n $OPTARG ]]; then
        tb_logdir=$OPTARG
      fi
      ;;
    h) print_help; exit 0;;
    \?) echo "Invalid option: -$OPTARG"; print_help; exit 1;;
    :) echo "Option -$OPTARG requires an argument"; print_help; exit 1;;
  esac
done

if [[ -n $isjupyter && -n $tb_logdir ]]; then
  echo "Options -j and -t cannot be used together"
  print_help
  exit 1
fi

# Shift the command-line arguments to skip the parsed options
shift $((OPTIND - 1))

build_cmd "$version" "$port" "$isjupyter" "$tb_logdir"

# Run the docker container in background
# echo $cmd
eval $cmd

# Loop to wait for user input if the contaner is running background
if [[ -n $isport ]]; then
  wait_for_input
fi
