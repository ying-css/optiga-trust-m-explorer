#!/bin/sh
set -e

# Get the current directory
CURRENT_DIR="$(realpath "$PWD")"

# Find the "working_space" directory (must be directly under CURRENT_DIR)
WORKING_SPACE_PATH=$(find "$CURRENT_DIR" -maxdepth 2 -type d -name "working_space" -print -quit)

if [ -z "$WORKING_SPACE_PATH" ]; then
  echo "Error: No 'working_space' directory found in $CURRENT_DIR"
  exit 1
fi

# Extract its parent directory
GUI_PATH=$(dirname "$WORKING_SPACE_PATH")
GUI_NAME=$(basename "$GUI_PATH")
echo "Found 'working_space' inside: $GUI_NAME"

sudo apt update 
sudo apt -y install awscli git gcc g++ make cmake pkg-config libssl-dev gpiod libgpiod-dev
sudo apt -y install python3-pubsub xxd wxpython-tools

echo "-----> Clone components (no submodules)"

# Put clones inside the Explorer repo, under Python_TrustM_GUI/
COMP_DIR="${GUI_PATH}/components"
LINUX_TOOLS_PATH="${COMP_DIR}/linux-optiga-trust-m"
OPENSSL_PATH="${COMP_DIR}/optiga-trust-m-openssl"
OPENSSL_REF="${OPENSSL_REF:-master}"

mkdir -p "$COMP_DIR"

# Clone + checkout linux-optiga-trust-m (cli_dev)
if [ ! -d "$LINUX_TOOLS_PATH/.git" ]; then
  git clone https://github.com/ying-css/linux-optiga-trust-m.git "$LINUX_TOOLS_PATH"
fi
git -C "$LINUX_TOOLS_PATH" fetch --all --tags
git -C "$LINUX_TOOLS_PATH" checkout cli_dev
git -C "$LINUX_TOOLS_PATH" pull --ff-only || true

TRUSTM_LIB_COMMIT="$(git -C "$LINUX_TOOLS_PATH" ls-tree HEAD trustm_lib | awk '{print $3}')"
echo "trustm_lib commit expected: $TRUSTM_LIB_COMMIT"

TRUSTM_LIB_DIR="${LINUX_TOOLS_PATH}/trustm_lib"
if [ ! -d "$TRUSTM_LIB_DIR/.git" ]; then
  rm -rf "$TRUSTM_LIB_DIR" 2>/dev/null || true
  git clone https://github.com/Infineon/optiga-trust-m.git "$TRUSTM_LIB_DIR"
fi
git -C "$TRUSTM_LIB_DIR" fetch --all --tags
git -C "$TRUSTM_LIB_DIR" checkout "$TRUSTM_LIB_COMMIT"

# --- nested submodules inside trustm_lib: external/mbedtls + external/mbedtls-3.x ---
MBEDTLS_COMMIT="$(git -C "$TRUSTM_LIB_DIR" ls-tree HEAD external/mbedtls | awk '{print $3}')"
MBEDTLS3_COMMIT="$(git -C "$TRUSTM_LIB_DIR" ls-tree HEAD external/mbedtls-3.x | awk '{print $3}')"

echo "-----> mbedtls commit:    $MBEDTLS_COMMIT"
echo "-----> mbedtls-3.x commit: ${MBEDTLS3_COMMIT:-<none>}"

# mbedtls
if [ ! -d "${TRUSTM_LIB_DIR}/external/mbedtls/.git" ]; then
  rm -rf "${TRUSTM_LIB_DIR}/external/mbedtls"
  git clone https://github.com/Mbed-TLS/mbedtls.git "${TRUSTM_LIB_DIR}/external/mbedtls"
fi
git -C "${TRUSTM_LIB_DIR}/external/mbedtls" fetch --all --tags
git -C "${TRUSTM_LIB_DIR}/external/mbedtls" checkout "$MBEDTLS_COMMIT"

# mbedtls-3.x 
if [ -n "$MBEDTLS3_COMMIT" ]; then
  if [ ! -d "${TRUSTM_LIB_DIR}/external/mbedtls-3.x/.git" ]; then
    rm -rf "${TRUSTM_LIB_DIR}/external/mbedtls-3.x"
    git clone https://github.com/Mbed-TLS/mbedtls.git "${TRUSTM_LIB_DIR}/external/mbedtls-3.x"
  fi
  git -C "${TRUSTM_LIB_DIR}/external/mbedtls-3.x" fetch --all --tags
  git -C "${TRUSTM_LIB_DIR}/external/mbedtls-3.x" checkout "$MBEDTLS3_COMMIT"
else
  echo "-----> external/mbedtls-3.x not pinned (no commit found); skipping."
fi

## Clone optiga-trust-m-openssl (default branch)

if [ ! -d "$OPENSSL_PATH/.git" ]; then
  git clone https://github.com/ying-css/optiga-trust-m-openssl.git "$OPENSSL_PATH"
fi
git -C "$OPENSSL_PATH" fetch --all --tags
git -C "$OPENSSL_PATH" checkout "$OPENSSL_REF"
git -C "$OPENSSL_PATH" pull --ff-only || true

# ===== Manual submodule clone: external/optiga-trust-m (required by optiga-trust-m-openssl) =====
OPENSSL_OPTIGA_DIR="${OPENSSL_PATH}/external/optiga-trust-m"
OPENSSL_OPTIGA_COMMIT="$(git -C "$OPENSSL_PATH" ls-tree HEAD external/optiga-trust-m | awk '{print $3}')"
echo "-----> openssl repo expects optiga-trust-m commit: $OPENSSL_OPTIGA_COMMIT"

if [ ! -d "${OPENSSL_OPTIGA_DIR}/.git" ]; then
  rm -rf "$OPENSSL_OPTIGA_DIR" 2>/dev/null || true
  mkdir -p "$(dirname "$OPENSSL_OPTIGA_DIR")"
  git clone https://github.com/Infineon/optiga-trust-m.git "$OPENSSL_OPTIGA_DIR"
fi
git -C "$OPENSSL_OPTIGA_DIR" fetch --all --tags
git -C "$OPENSSL_OPTIGA_DIR" checkout "$OPENSSL_OPTIGA_COMMIT"

# ===== Manual nested submodules inside external/optiga-trust-m: mbedtls + mbedtls-3.x =====
MBEDTLS_COMMIT2="$(git -C "$OPENSSL_OPTIGA_DIR" ls-tree HEAD external/mbedtls | awk '{print $3}')"
MBEDTLS3_COMMIT2="$(git -C "$OPENSSL_OPTIGA_DIR" ls-tree HEAD external/mbedtls-3.x | awk '{print $3}')"

echo "-----> openssl optiga-trust-m mbedtls commit: ${MBEDTLS_COMMIT2:-<none>}"
if [ -n "$MBEDTLS_COMMIT2" ]; then
  if [ ! -d "${OPENSSL_OPTIGA_DIR}/external/mbedtls/.git" ]; then
    rm -rf "${OPENSSL_OPTIGA_DIR}/external/mbedtls"
    git clone https://github.com/Mbed-TLS/mbedtls.git "${OPENSSL_OPTIGA_DIR}/external/mbedtls"
  fi
  git -C "${OPENSSL_OPTIGA_DIR}/external/mbedtls" fetch --all --tags
  git -C "${OPENSSL_OPTIGA_DIR}/external/mbedtls" checkout "$MBEDTLS_COMMIT2"
else
  echo "-----> external/mbedtls not pinned/found; skipping." >&2
fi

echo "-----> openssl optiga-trust-m mbedtls-3.x commit: ${MBEDTLS3_COMMIT2:-<none>}"
if [ -n "$MBEDTLS3_COMMIT2" ]; then
  if [ ! -d "${OPENSSL_OPTIGA_DIR}/external/mbedtls-3.x/.git" ]; then
    rm -rf "${OPENSSL_OPTIGA_DIR}/external/mbedtls-3.x"
    git clone https://github.com/Mbed-TLS/mbedtls.git "${OPENSSL_OPTIGA_DIR}/external/mbedtls-3.x"
  fi
  git -C "${OPENSSL_OPTIGA_DIR}/external/mbedtls-3.x" fetch --all --tags
  git -C "${OPENSSL_OPTIGA_DIR}/external/mbedtls-3.x" checkout "$MBEDTLS3_COMMIT2"
else
  echo "-----> external/mbedtls-3.x not pinned/found; skipping."
fi

cd "$LINUX_TOOLS_PATH"

echo "-----> Build Trust M Linux Tools"
sudo make uninstall
make -j5
sudo make install
echo "-----> Build Protected Update Set tool"
cd ex_protected_update_data_set/Linux/
make clean
make -j5
sudo make install

echo "-----> Build optiga-trust-m-openssl"
cd "$OPENSSL_PATH"
if [ -f CMakeLists.txt ]; then
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
  cmake --build build -j5
  sudo cmake --install build
else
  make -j5
  sudo make install
fi

echo "-----> Verify Trust M communication"
if [ -x "${LINUX_TOOLS_PATH}/bin/trustm_chipinfo" ]; then
  "${LINUX_TOOLS_PATH}/bin/trustm_chipinfo"
else
  echo "Warning: trustm_chipinfo not found at ${LINUX_TOOLS_PATH}/bin" >&2
fi
 
#~cd $CURRENT_DIR
echo "-----> Installation completed. Back to ${PWD}"


