#!/bin/sh

# Get the current directory
CURRENT_DIR="$(realpath "$PWD")"

# Step 1: Find the "working_space" directory (must be directly under CURRENT_DIR)
WORKING_SPACE_PATH=$(find "$CURRENT_DIR" -maxdepth 2 -type d -name "working_space" -print -quit)

if [ -z "$WORKING_SPACE_PATH" ]; then
  echo "Error: No 'working_space' directory found in $CURRENT_DIR"
  exit 1
fi

# Step 2: Extract its parent directory
GUI_PATH=$(dirname "$WORKING_SPACE_PATH")
GUI_NAME=$(basename "$GUI_PATH")
echo "Found 'working_space' inside: $GUI_NAME"

# Step 3: Look inside GUI_PATH for a subdirectory that contains 'scripts'
SCRIPTS_PARENT_PATH=$(find "$GUI_PATH" -mindepth 1 -maxdepth 1 -type d -exec sh -c '[ -d "$1/scripts" ] && echo "$1"' _ {} \; -print -quit)

if [ -z "$SCRIPTS_PARENT_PATH" ]; then
  echo "Error: No directory containing 'scripts' found inside $GUI_NAME"
  exit 1
fi

# Extract only the name of the parent directory of "bin"
SCRIPTS_PARENT_NAME=$(basename "$SCRIPTS_PARENT_PATH")

echo "Found 'scripts' directory inside: $SCRIPTS_PARENT_NAME"

LINUX_TOOLS_PATH="${GUI_PATH}/${SCRIPTS_PARENT_NAME}/"

TRUSTM_LIB_PATH="${LINUX_TOOLS_PATH}/trustm_lib/"

sudo apt update 
sudo apt -y install awscli git gcc libssl-dev gpiod libgpiod-dev
sudo apt install python3-pubsub xxd wxpython-tools

echo $LINUX_TOOLS_PATH
cd $LINUX_TOOLS_PATH

if [ -d "${LINUX_TOOLS_PATH}/pbs" ]; then
    echo "0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F40" > "${LINUX_TOOLS_PATH}/pbs/pbsfile.txt"
else
  echo "-----> No 'pbsfile.txt' directory found."
fi

set -e
echo "-----> Build Trust M Linux Tools"
sudo make uninstall
make -j5
sudo make install
echo "-----> Build Protected Update Set tool"
cd ex_protected_update_data_set/Linux/
make clean
make -j5
sudo make install
 
#~cd $CURRENT_DIR
echo "-----> Installation completed. Back to ${PWD}"


