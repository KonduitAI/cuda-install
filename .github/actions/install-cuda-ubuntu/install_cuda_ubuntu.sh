#!/bin/bash
## -------------------
## Constants
## -------------------

# CUDA version from environment variable
CUDA_VERSION_MAJOR_MINOR=${cuda}

# Split the version
export CUDA_MAJOR=$(echo "${CUDA_VERSION_MAJOR_MINOR}" | cut -d. -f1)
export CUDA_MINOR=$(echo "${CUDA_VERSION_MAJOR_MINOR}" | cut -d. -f2)
export CUDA_PATCH=$(echo "${CUDA_VERSION_MAJOR_MINOR}" | cut -d. -f3)

echo "CUDA_MAJOR: ${CUDA_MAJOR}"
echo "CUDA_MINOR: ${CUDA_MINOR}"
echo "CUDA_PATCH: ${CUDA_PATCH}"

# If we don't know the CUDA_MAJOR or MINOR, error
if [ -z "${CUDA_MAJOR}" ] ; then
    echo "Error: Unknown CUDA Major version. Aborting."
    exit 1
fi
if [ -z "${CUDA_MINOR}" ] ; then
    echo "Error: Unknown CUDA Minor version. Aborting."
    exit 1
fi

## -------------------
## Download CUDA installer
## -------------------

# Handle CUDA 12.9 via official apt repository (local .run URL is not stable)
if [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.9" ]]; then
    echo "Installing CUDA ${CUDA_MAJOR}.${CUDA_MINOR} from NVIDIA apt repository"
    wget -q -O cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring.deb
    sudo apt-get update -y
    sudo apt-get install -y cuda-toolkit-12-9
    rm -f cuda-keyring.deb
    export CUDA_PATH=/usr/local/cuda-${CUDA_MAJOR}.${CUDA_MINOR}
else
    # URL templates for different CUDA versions
    if [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.6" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/12.6.0/local_installers/cuda_12.6.0_560.28.03_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.3" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/12.3.0/local_installers/cuda_12.3.0_545.23.06_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.1" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/12.1.0/local_installers/cuda_12.1.0_530.30.02_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.8" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.6" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.6.0/local_installers/cuda_11.6.0_510.39.01_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.4" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.4.0/local_installers/cuda_11.4.0_470.42.01_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.2" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.2.0/local_installers/cuda_11.2.0_460.27.04_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.0" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/11.0.2/local_installers/cuda_11.0.2_450.51.05_linux.run"
    elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "10.2" ]]; then
    CUDA_URL="https://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run"
    else
        echo "Error: Unsupported CUDA version ${CUDA_MAJOR}.${CUDA_MINOR}. Aborting."
        exit 1
    fi

    echo "Downloading CUDA installer from ${CUDA_URL}"
    wget -O cuda_installer.run ${CUDA_URL}

    if [ ! -f cuda_installer.run ]; then
        echo "Error: Failed to download CUDA installer. Aborting."
        exit 1
    fi

    chmod +x cuda_installer.run

    ## -------------------
    ## Install CUDA silently
    ## -------------------

    # Install CUDA toolkit with only necessary components for NVCC
    echo "Installing CUDA ${CUDA_MAJOR}.${CUDA_MINOR} silently"
    sudo ./cuda_installer.run --silent --toolkit --no-opengl-libs --no-drm --no-man-page --override

    export CUDA_PATH=/usr/local/cuda-${CUDA_MAJOR}.${CUDA_MINOR}
fi

if [ ! -x "${CUDA_PATH}/bin/nvcc" ]; then
    echo "Error: nvcc not found at ${CUDA_PATH}/bin/nvcc after CUDA installation."
    exit 1
fi

echo "CUDA_PATH=$CUDA_PATH"

# Set environment variables
export PATH="$CUDA_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_PATH/lib64:$LD_LIBRARY_PATH"

# Verify NVCC installation
echo "Verifying NVCC installation:"
nvcc -V

## -------------------
## Install cuDNN if needed
## -------------------

if [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.6" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-9.5.0.50_cuda12-archive.tar.xz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.3" ]]; then
    CUDNN_URL="https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.7/local_installers/12.x/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.1" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.9.0/local_installers/12.x/cudnn-linux-x86_64-8.9.0.131_cuda12-archive.tar.xz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.8" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/local_installers/11.5/cudnn-linux-x86_64-8.6.0.163_cuda11-archive.tar.xz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.6" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.3.2/local_installers/11.5/cudnn-linux-x86_64-8.3.2.44_cuda11.5-archive.tar.xz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.4" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.2.2/cudnn-11.4-linux-x64-v8.2.2.26.tgz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.2" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.1.0/cudnn-11.2-linux-x64-v8.1.0.77.tgz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.0" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.0.4/cudnn-11.0-linux-x64-v8.0.4.30.tgz"
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "10.2" ]]; then
    CUDNN_URL="https://developer.download.nvidia.com/compute/redist/cudnn/v8.2.2/cudnn-10.2-linux-x64-v8.2.2.26.tgz"
else
    echo "Warning: No predefined cuDNN version for CUDA ${CUDA_MAJOR}.${CUDA_MINOR}. Skipping cuDNN installation."
    exit 0
fi

echo "Downloading cuDNN from ${CUDNN_URL}"
wget -O cudnn_archive.tar.xz "${CUDNN_URL}"

if [ ! -f cudnn_archive.tar.xz ]; then
    echo "Error: Failed to download cuDNN. Continuing without cuDNN."
    exit 0
fi

echo "Installing cuDNN for CUDA ${CUDA_MAJOR}.${CUDA_MINOR}"

# Create temporary directory for extraction
mkdir -p cudnn_tmp
cd cudnn_tmp

# Extract the archive
if [[ "$CUDNN_URL" == *".tar.xz" ]]; then
    tar -xf ../cudnn_archive.tar.xz
else
    tar -xzf ../cudnn_archive.tar.xz
fi

# Find the extracted directory
CUDNN_EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "cudnn-*" | head -1)
if [ -z "$CUDNN_EXTRACTED_DIR" ]; then
    # If no cudnn-* directory, look for direct include/lib structure
    if [ -d "include" ] && [ -d "lib" -o -d "lib64" ]; then
        CUDNN_EXTRACTED_DIR="."
    else
        echo "Error: Could not find cuDNN directory structure after extraction"
        cd ..
        rm -rf cudnn_tmp cudnn_archive.tar.xz
        exit 0
    fi
fi

echo "Found cuDNN directory: $CUDNN_EXTRACTED_DIR"

# Copy include files
if [ -d "$CUDNN_EXTRACTED_DIR/include" ]; then
    echo "Copying cuDNN headers to $CUDA_PATH/include/"
    sudo cp -rf "$CUDNN_EXTRACTED_DIR/include/"* "$CUDA_PATH/include/"
    echo "cuDNN headers copied successfully"
else
    echo "Warning: No include directory found in cuDNN archive"
fi

# Copy library files (try both lib and lib64)
LIB_COPIED=false
if [ -d "$CUDNN_EXTRACTED_DIR/lib64" ]; then
    echo "Copying cuDNN libraries from lib64 to $CUDA_PATH/lib64/"
    sudo cp -rf "$CUDNN_EXTRACTED_DIR/lib64/"* "$CUDA_PATH/lib64/"
    LIB_COPIED=true
fi

if [ -d "$CUDNN_EXTRACTED_DIR/lib" ]; then
    echo "Copying cuDNN libraries from lib to $CUDA_PATH/lib64/"
    sudo cp -rf "$CUDNN_EXTRACTED_DIR/lib/"* "$CUDA_PATH/lib64/"
    LIB_COPIED=true
fi

if [ "$LIB_COPIED" = false ]; then
    echo "Warning: No lib or lib64 directory found in cuDNN archive"
fi

# Go back and clean up
cd ..
rm -rf cudnn_tmp cudnn_archive.tar.xz

# Verify cuDNN installation
if [ -f "$CUDA_PATH/include/cudnn.h" ]; then
    echo "✅ cuDNN installed successfully."
    echo "cuDNN header location: $CUDA_PATH/include/cudnn.h"
    
    # Check for library files
    if ls "$CUDA_PATH/lib64/"*cudnn* 1> /dev/null 2>&1; then
        echo "✅ cuDNN libraries found in $CUDA_PATH/lib64/"
        ls -la "$CUDA_PATH/lib64/"*cudnn*
    else
        echo "⚠️  Warning: cuDNN libraries not found in $CUDA_PATH/lib64/"
    fi
    
    # Set environment variables for cuDNN
    export CUDNN_ROOT_DIR="$CUDA_PATH"
    echo "export CUDNN_ROOT_DIR=$CUDA_PATH" | sudo tee -a /etc/profile.d/cuda.sh
    
else
    echo "❌ Error: cuDNN installation failed. cudnn.h not found."
    echo "Listing contents of $CUDA_PATH/include/ for debugging:"
    ls -la "$CUDA_PATH/include/" | grep -i cudnn || echo "No cuDNN files found"
fi

echo "CUDA installation completed successfully."
echo "NVCC version:"
nvcc -V

# Add CUDA to system-wide paths
echo "export PATH=$CUDA_PATH/bin:\$PATH" | sudo tee /etc/profile.d/cuda.sh
echo "export LD_LIBRARY_PATH=$CUDA_PATH/lib64:\$LD_LIBRARY_PATH" | sudo tee -a /etc/profile.d/cuda.sh
sudo chmod +x /etc/profile.d/cuda.sh

echo "CUDA environment set up. Build servers are ready for CUDA compilation."
