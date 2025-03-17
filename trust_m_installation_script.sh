#!/bin/sh

# Get the current directory
CURRENT_DIR="$(realpath "$PWD")"

# Step 1: Find the parent directory of "images"
IMAGES_PATH=$(find "$CURRENT_DIR" -maxdepth 2 -type d -name "images" -print -quit)

if [ -z "$IMAGES_PATH" ]; then
  echo "Error: No directory containing 'images' found."
  exit 1
fi

# Extract the parent directory of "images"
IMAGES_PARENT_PATH=$(dirname "$IMAGES_PATH")
IMAGES_PARENT_NAME=$(basename "$IMAGES_PARENT_PATH")

echo "Found 'images' directory inside: $IMAGES_PARENT_NAME"

# Step 2: Find a first-layer child directory inside IMAGES_PARENT_PATH that contains "bin"
BIN_PARENT_PATH=$(find "$IMAGES_PARENT_PATH" -mindepth 1 -maxdepth 1 -type d -exec sh -c '[ -d "$1/bin" ] && echo "$1"' _ {} \; -print -quit)

if [ -z "$BIN_PARENT_PATH" ]; then
  echo "Error: No directory containing 'bin' found inside $IMAGES_PARENT_NAME."
  exit 1
fi

# Extract only the name of the parent directory of "bin"
BIN_PARENT_NAME=$(basename "$BIN_PARENT_PATH")

echo "Found 'bin' directory inside: $BIN_PARENT_NAME"

# Now you can use this for further processing
LINUX_TOOLS_PATH="${IMAGES_PARENT_PATH}/${BIN_PARENT_NAME}/"

echo "Using LINUX_TOOLS_PATH: $LINUX_TOOLS_PATH"

echo "Using LINUX_TOOLS_PATH: $LINUX_TOOLS_PATH"

TRUSTM_LIB_PATH="${LINUX_TOOLS_PATH}/trustm_lib/"

echo "Using LINUX_TOOLS_PATH: $LINUX_TOOLS_PATH"
echo "Using TRUSTM_LIB_PATH: $TRUSTM_LIB_PATH"

sudo apt update 
sudo apt -y install awscli git gcc libssl-dev gpiod libgpiod-dev
sudo apt install python3-pubsub xxd wxpython-tools

echo $LINUX_TOOLS_PATH
cd $LINUX_TOOLS_PATH
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



