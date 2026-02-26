# Script to download and install specific CUDA Toolkit and cuDNN versions on Windows GitHub Actions runners.
# Reads the target CUDA version from the $env:CUDA_VERSION environment variable.

param(
    # Example: $env:CUDA_VERSION = "12.3"
    # The script expects the version string to match the keys in the hashtables below.
)

## -------------------
## Constants
## -------------------

# Dictionary of known cuda versions and their download URLs
$CUDA_KNOWN_URLS = @{
      "12.3" = "https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cuda_12.3.2_windows_network.exe";
      "12.6" = "https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cuda_12.6.3_windows_network.exe";
      "12.9" = "https://developer.download.nvidia.com/compute/cuda/12.9.0/network_installers/cuda_12.9.0_windows_network.exe";
      # Add more versions and URLs as needed
}

# Dictionary matching CUDA versions to their expected network installer filenames
$CUDA_FILE_NAMES = @{
    "12.3" = "cuda_12.3.2_windows_network.exe";
    "12.6" = "cuda_12.6.3_windows_network.exe";
    "12.9" = "cuda_12.9.0_windows_network.exe";
    # Add more versions and filenames as needed
}

# Dictionary of known cuDNN versions corresponding to CUDA versions and their download URLs
$CUDNN_KNOWN_URLS = @{
      "12.3" = "https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cudnn-windows-x86_64-8.9.3.28_cuda12-archive.zip";
      "12.6" = "https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cudnn-windows-x86_64-9.5.0.50_cuda12-archive.zip";
      "12.9" = "https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cudnn-windows-x86_64-9.5.0.50_cuda12-archive.zip";
      # Add more versions and URLs as needed
}

# Default CUDA packages to install
$CUDA_PACKAGES_IN = @(
    "nvcc",
    "visual_studio_integration",
    "cublas_dev",
    "cusolver_dev",
    "curand_dev",
    "nvrtc_dev",
    "cudart" # Generally required for CUDA 11+
)


# Helper function to unzip files
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)
    Write-Output "Unzipping '$zipfile' to '$outpath'"
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
        Write-Output "Unzip successful."
    } catch {
        Write-Error "Failed to unzip '$zipfile': $($_.Exception.Message)"
        throw # Re-throw the exception to stop the script if unzipping fails
    }
}


## -------------------
## Select CUDA version
## -------------------

$CUDA_VERSION_FULL=$env:CUDA_VERSION
Write-Output "CUDA version input from environment: $CUDA_VERSION_FULL"

# Validate that the environment variable was set
if (-not $CUDA_VERSION_FULL) {
    Write-Error "Environment variable CUDA_VERSION is not set. Please provide the target CUDA version (e.g., '12.3')."
    exit 1
}

# Regex extract major/minor/patch from version string (patch is optional)
# Example formats matched: "11.6", "12.3.2"
$regexMatched = $CUDA_VERSION_FULL -match '^(?<major>\d{1,2})\.(?<minor>\d{1,2})(?:\.(?<patch>\d{1,}))?$'

# Validate that the regex matched successfully
if (-not $regexMatched) {
    Write-Error "Failed to parse CUDA version '$CUDA_VERSION_FULL'. Expected format like '11.6' or '12.3.2'."
    exit 1
}

# Assign parsed components
$CUDA_MAJOR=$Matches.major
$CUDA_MINOR=$Matches.minor
$CUDA_PATCH=$Matches.patch # This might be empty/null if only major.minor was provided
$CUDA_VERSION_KEY="$CUDA_MAJOR.$CUDA_MINOR"

Write-Output "Parsed CUDA Version - Major: $CUDA_MAJOR, Minor: $CUDA_MINOR, Patch: $CUDA_PATCH"
Write-Output "Using '$CUDA_VERSION_FULL' as the primary key for lookups (normalized key: '$CUDA_VERSION_KEY')."


## ------------------------------------------------
## Select CUDA packages to install from environment
## ------------------------------------------------

$CUDA_PACKAGES = "" # String to hold package arguments for the installer

# Construct the version object for comparisons
$currentVersionString = "$CUDA_MAJOR.$CUDA_MINOR"
if ($CUDA_PATCH) { $currentVersionString += ".$CUDA_PATCH" }
$currentVersion = [version]$currentVersionString

Write-Output "Processing package list for CUDA version $currentVersion"

Foreach ($package in $CUDA_PACKAGES_IN) {
    $packageNameForInstaller = $package
    # Adjust package names based on CUDA version if necessary (e.g., nvcc vs compiler)
    if($package -eq "nvcc" -and $currentVersion -lt [version]"9.1"){
        $packageNameForInstaller="compiler"
        Write-Output "Adjusting package name: 'nvcc' becomes 'compiler' for CUDA < 9.1"
    } elseif($package -eq "compiler" -and $currentVersion -ge [version]"9.1") {
        $packageNameForInstaller="nvcc"
         Write-Output "Adjusting package name: 'compiler' becomes 'nvcc' for CUDA >= 9.1"
    }
    # Append the required version suffix for the installer arguments
    $CUDA_PACKAGES += " $($packageNameForInstaller)_$($CUDA_MAJOR).$($CUDA_MINOR)"
}

# Trim leading space
$CUDA_PACKAGES = $CUDA_PACKAGES.TrimStart()
Write-Output "CUDA packages selected for install arguments: '$($CUDA_PACKAGES)'"


## -----------------
## Prepare download URLs and Filenames
## -----------------

# Select the CUDA download link
$CUDA_REPO_PKG_REMOTE=""
$cudaLookupKey=$CUDA_VERSION_FULL
if(-not $CUDA_KNOWN_URLS.ContainsKey($cudaLookupKey) -and $CUDA_KNOWN_URLS.ContainsKey($CUDA_VERSION_KEY)){
    $cudaLookupKey=$CUDA_VERSION_KEY
    Write-Output "CUDA URL not found for '$CUDA_VERSION_FULL'. Falling back to normalized key '$cudaLookupKey'."
}

if($CUDA_KNOWN_URLS.containsKey($cudaLookupKey)){
    $CUDA_REPO_PKG_REMOTE=$CUDA_KNOWN_URLS[$cudaLookupKey]
    Write-Output "Found known CUDA URL using key '$cudaLookupKey': $CUDA_REPO_PKG_REMOTE"
} else {
    # Attempt to guess the URL based on pattern (may be unreliable)
    Write-Warning "URL for CUDA '$CUDA_VERSION_FULL' (or '$CUDA_VERSION_KEY') not found in known URLs. Attempting to estimate."
    if ($CUDA_MAJOR -and $CUDA_MINOR -and $CUDA_PATCH) {
         # Example guess pattern - UPDATE THIS if NVIDIA changes their URL structure
         $CUDA_REPO_PKG_REMOTE="https://developer.download.nvidia.com/compute/cuda/$($CUDA_MAJOR).$($CUDA_MINOR).$($CUDA_PATCH)/network_installers/cuda_$($CUDA_MAJOR).$($CUDA_MINOR).$($CUDA_PATCH)_windows_network.exe"
         Write-Output "Estimated CUDA URL: $CUDA_REPO_PKG_REMOTE"
    } else {
         Write-Error "Cannot estimate CUDA URL because Major/Minor/Patch version components could not be fully determined from '$CUDA_VERSION_FULL'."
         exit 1
    }
}

# Select the CUDA local filename
$CUDA_REPO_PKG_LOCAL=""
$cudaFileLookupKey=$CUDA_VERSION_FULL
if(-not $CUDA_FILE_NAMES.ContainsKey($cudaFileLookupKey) -and $CUDA_FILE_NAMES.ContainsKey($CUDA_VERSION_KEY)){
    $cudaFileLookupKey=$CUDA_VERSION_KEY
    Write-Output "CUDA filename not found for '$CUDA_VERSION_FULL'. Falling back to normalized key '$cudaFileLookupKey'."
}

if ($CUDA_FILE_NAMES.ContainsKey($cudaFileLookupKey)) {
    $CUDA_REPO_PKG_LOCAL=$CUDA_FILE_NAMES[$cudaFileLookupKey]
    Write-Output "Using known CUDA filename for key '$cudaFileLookupKey': $CUDA_REPO_PKG_LOCAL"
} else {
    # Default filename if not found in the known list
    $CUDA_REPO_PKG_LOCAL="cuda_${CUDA_VERSION_FULL}_windows_network.exe" # Example default
    Write-Warning "CUDA filename for version '$CUDA_VERSION_FULL' not found in known names. Defaulting to: $CUDA_REPO_PKG_LOCAL"
}

# Select the cuDNN download link
$CUDNN_URL=""
$cudnnLookupKey=$CUDA_VERSION_FULL
if(-not $CUDNN_KNOWN_URLS.ContainsKey($cudnnLookupKey) -and $CUDNN_KNOWN_URLS.ContainsKey($CUDA_VERSION_KEY)){
    $cudnnLookupKey=$CUDA_VERSION_KEY
    Write-Output "cuDNN URL not found for '$CUDA_VERSION_FULL'. Falling back to normalized key '$cudnnLookupKey'."
}

if ($CUDNN_KNOWN_URLS.ContainsKey($cudnnLookupKey)) {
    $CUDNN_URL = $CUDNN_KNOWN_URLS[$cudnnLookupKey]
    Write-Output "Found known cuDNN URL using key '$cudnnLookupKey': $CUDNN_URL"
} else {
    Write-Error "cuDNN URL for CUDA version '$CUDA_VERSION_FULL' (or '$CUDA_VERSION_KEY') not found in known URLs. Cannot proceed."
    exit 1
}


## ------------
## Download Files
## ------------

Write-Output "Downloading CUDA Network Installer for $CUDA_VERSION_FULL from: $CUDA_REPO_PKG_REMOTE"
try {
    Invoke-WebRequest $CUDA_REPO_PKG_REMOTE -OutFile $CUDA_REPO_PKG_LOCAL -UseBasicParsing -TimeoutSec 600 # Added timeout
    Write-Output "CUDA Download Complete: $CUDA_REPO_PKG_LOCAL"
} catch {
    Write-Error "Failed to download CUDA from '$CUDA_REPO_PKG_REMOTE': $($_.Exception.Message)"
    exit 1
}
# Verify download
if (-not (Test-Path -Path $CUDA_REPO_PKG_LOCAL)) {
     Write-Error "Error: CUDA file '$($CUDA_REPO_PKG_LOCAL)' not found after download attempt."
     exit 1
}


Write-Output "Downloading cuDNN for CUDA $CUDA_VERSION_FULL from: $CUDNN_URL"
$CUDNN_ZIP_FILE = "cudnn.zip"
try {
    Invoke-WebRequest $CUDNN_URL -OutFile $CUDNN_ZIP_FILE -UseBasicParsing -TimeoutSec 600 # Added timeout
    Write-Output "cuDNN Download Complete: $CUDNN_ZIP_FILE"
} catch {
    Write-Error "Failed to download cuDNN from '$CUDNN_URL': $($_.Exception.Message)"
    exit 1
}
# Verify download
if (-not (Test-Path -Path $CUDNN_ZIP_FILE)) {
     Write-Error "Error: cuDNN file '$($CUDNN_ZIP_FILE)' not found after download attempt."
     exit 1
}

Write-Output "Current directory contents before installation:"
Get-ChildItem


## ------------
## Install CUDA
## ------------

Write-Output "Installing CUDA $CUDA_VERSION_FULL. Using arguments: -s $CUDA_PACKAGES. Installer: $CUDA_REPO_PKG_LOCAL"
# Use .\ to ensure it runs from the current directory
$InstallerPath = ".\$($CUDA_REPO_PKG_LOCAL)"
$InstallerArgs = "-s $CUDA_PACKAGES" # Silent install with specific packages

try {
    # Start the process and wait for it to complete
    $process = Start-Process -Wait -FilePath $InstallerPath -ArgumentList $InstallerArgs -PassThru -ErrorAction Stop
    $exitCode = $process.ExitCode
    Write-Output "CUDA Installer process completed with Exit Code: $exitCode"

    # Check the exit code for success (typically 0)
    if ($exitCode -ne 0) {
        Write-Error "CUDA installer failed with Exit Code: $exitCode."
        # Attempt to display installer logs if they exist at a known location
        $logPath = Join-Path $env:TEMP "NVIDIA Corporation\cuda_installer.log" # Common log location
        if (Test-Path $logPath) {
            Write-Warning "Displaying content of CUDA installer log: $logPath"
            Get-Content $logPath | Out-String | Write-Warning
        } else {
            Write-Warning "CUDA installer log not found at $logPath"
        }
        exit 1 # Exit the script due to installer failure
    } else {
        Write-Output "CUDA Installation seems successful."
    }
} catch {
    Write-Error "Failed to start or run CUDA installer '$InstallerPath': $($_.Exception.Message)"
    exit 1
}


## ------------
## Post-Install Setup (cuDNN Copy & Environment)
## ------------

# Define expected CUDA installation path
$CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($CUDA_MAJOR).$($CUDA_MINOR)"
Write-Output "Expected CUDA Path: $CUDA_PATH"

# Verify CUDA installation directory exists
if (-not (Test-Path -Path $CUDA_PATH -PathType Container)) {
    Write-Error "CUDA installation directory NOT found at expected path: '$CUDA_PATH'. Installation may have failed silently or path is incorrect."
    # List contents of potential parent directory for debugging
    $parentDir = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA"
    if (Test-Path $parentDir) {
         Write-Warning "Contents of '$parentDir':"
         Get-ChildItem $parentDir | Select-Object -ExpandProperty Name | Write-Warning
    }
    exit 1
} else {
    Write-Output "CUDA installation directory confirmed at '$CUDA_PATH'."
    # Optionally list some contents
    # Get-ChildItem $CUDA_PATH | Select-Object -First 5 -ExpandProperty Name
}

# Unzip cuDNN
$CUDNN_EXTRACT_DIR = ".\cudnn_extracted"
if (Test-Path $CUDNN_EXTRACT_DIR) { Remove-Item -Recurse -Force $CUDNN_EXTRACT_DIR } # Clean up previous attempts
New-Item -ItemType Directory -Force -Path $CUDNN_EXTRACT_DIR | Out-Null
Unzip $CUDNN_ZIP_FILE $CUDNN_EXTRACT_DIR # Unzip to a dedicated directory

# Find the actual directory *inside* the extracted folder (often named 'cudnn-...' or 'cuda')
$cudnnSourceDir = Get-ChildItem -Path $CUDNN_EXTRACT_DIR -Directory | Select-Object -First 1
if (-not $cudnnSourceDir) {
    Write-Error "Could not find the primary cuDNN directory inside '$CUDNN_EXTRACT_DIR' after unzipping."
    exit 1
}
Write-Output "Found unzipped cuDNN source directory: $($cudnnSourceDir.FullName)"


# Copy cuDNN files to CUDA installation directory
Write-Output "Copying cuDNN files from '$($cudnnSourceDir.FullName)' to '$CUDA_PATH'"
try {
    # Copy the *contents* of the source directory
    Copy-Item -Path (Join-Path $cudnnSourceDir.FullName "*") -Destination $CUDA_PATH -Recurse -Force -ErrorAction Stop
    Write-Output "cuDNN files copied successfully."
} catch {
     Write-Error "Failed to copy cuDNN files: $($_.Exception.Message)"
     exit 1
}


# Set environment variables for subsequent steps in GitHub Actions
Write-Output "Setting CUDA_PATH environment variable for GitHub Actions environment."
# This makes $env:CUDA_PATH available to later steps in the same job
echo "CUDA_PATH=$($CUDA_PATH)" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

Write-Output "Script completed successfully."
