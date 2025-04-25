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
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-9.5.0.50_cuda12-archive.tar.xz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.3" ]]; then
    wget -O cudnn.tgz https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.7/local_installers/12.x/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "12.1" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.9.0/local_installers/12.x/cudnn-linux-x86_64-8.9.0.131_cuda12-archive.tar.xz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.8" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.6.0/local_installers/11.5/cudnn-linux-x86_64-8.6.0.163_cuda11-archive.tar.xz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.6" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.3.2/local_installers/11.5/cudnn-linux-x86_64-8.3.2.44_cuda11.5-archive.tar.xz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.4" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.2.2/cudnn-11.4-linux-x64-v8.2.2.26.tgz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.2" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.1.0/cudnn-11.2-linux-x64-v8.1.0.77.tgz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "11.0" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.0.4/cudnn-11.0-linux-x64-v8.0.4.30.tgz
elif [[ "${CUDA_MAJOR}.${CUDA_MINOR}" == "10.2" ]]; then
    wget -O cudnn.tgz https://developer.download.nvidia.com/compute/redist/cudnn/v8.2.2/cudnn-10.2-linux-x64-v8.2.2.26.tgz
else
    echo "Warning: No predefined cuDNN version for CUDA ${CUDA_MAJOR}.${CUDA_MINOR}. Skipping cuDNN installation."
    exit 0
fi

if [ -f cudnn.tgz ]; then
    echo "Installing cuDNN for CUDA ${CUDA_MAJOR}.${CUDA_MINOR}"
    
    # Handle different archive formats
    if [[ "$cudnn.tgz" == *".tar.xz" ]]; then
        mkdir -p cudnn_tmp
        tar -xf cudnn.tgz -C cudnn_tmp
        
        # Find the directory within the extracted archive
        CUDNN_DIR=$(find cudnn_tmp -type d -name "cudnn-*" -o -name "include" | head -1)
        if [ -z "$CUDNN_DIR" ]; then
            CUDNN_DIR="cudnn_tmp"
        fi
        
        # Copy files to CUDA directory
        sudo cp -rf cudnn_tmp/*/include/* "$CUDA_PATH/include/"
        sudo cp -rf cudnn_tmp/*/lib/* "$CUDA_PATH/lib64/"
        sudo cp -rf cudnn_tmp/*/lib64/* "$CUDA_PATH/lib64/" 2>/dev/null || true
        
        # Clean up
        rm -rf cudnn_tmp
    else
        # Standard tar.gz format
        sudo tar -xzf cudnn.tgz -C "$CUDA_PATH" --strip-components=1
    fi
    
    # Verify cuDNN installation
    if [ -f "$CUDA_PATH/include/cudnn.h" ]; then
        echo "cuDNN installed successfully."
    else
        echo "Warning: cuDNN installation may have failed. CUDA will still work for basic compilation."
    fi
    
    # Clean up
    rm -f cudnn.tgz
fi

echo "CUDA installation completed successfully."
echo "NVCC version:"
nvcc -V

# Add CUDA to system-wide paths
echo "export PATH=$CUDA_PATH/bin:\$PATH" | sudo tee /etc/profile.d/cuda.sh
echo "export LD_LIBRARY_PATH=$CUDA_PATH/lib64:\$LD_LIBRARY_PATH" | sudo tee -a /etc/profile.d/cuda.sh
sudo chmod +x /etc/profile.d/cuda.sh

echo "CUDA environment set up. Build servers are ready for CUDA compilation."
