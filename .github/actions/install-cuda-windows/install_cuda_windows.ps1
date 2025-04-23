## -------------------
## Constants
## -------------------

# Dictionary of known cuda versions and thier download URLS, which do not follow a consistent pattern :(
$CUDA_KNOWN_URLS = @{
      "12.3" = "https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cuda_12.3.2_windows_network.exe";
      "12.6" = https://github.com/KonduitAI/dl4j-artifacts/releases/download/1.0.0-M3/cuda_12.6.3_windows_network.exe";

}

$CUDA_FILE_NAMES = @{
    "12.3" = "cuda_12.3.2_windows_network.exe";
    "12.6" = "cuda_12.6.3_windows_network.exe";

}

# https://developer.nvidia.com/compute/machine-learning/cudnn/secure/8.0.4/11.0_20200923/cudnn-11.0-windows-x64-v8.0.4.30.zip

$CUDNN_KNOWN_URLS = @{
      "12.3" = "https://developer.nvidia.com/downloads/compute/cudnn/secure/8.9.7/local_installers/12.x/cudnn-windows-x86_64-8.9.7.29_cuda12-archive.zip";
      "12.6" = "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/windows-x86_64/cudnn-windows-x86_64-9.5.0.50_cuda12-archive.zip";

}

# cuda_runtime.h is in nvcc <= 10.2, but cudart >= 11.0
# @todo - make this easier to vary per CUDA version.
$CUDA_PACKAGES_IN = @(
    "nvcc",
    "visual_studio_integration",
    "curand_dev",
    "nvrtc_dev",
    "cudart"
)


# See: https://stackoverflow.com/questions/27768303/how-to-unzip-a-file-in-powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}


## -------------------
## Select CUDA version
## -------------------


$CUDA_MAJOR=$Matches.major
$CUDA_MINOR=$Matches.minor
$CUDA_PATCH=$Matches.patch



## ------------------------------------------------
## Select CUDA packages to install from environment
## ------------------------------------------------

$CUDA_PACKAGES = ""

# for CUDA >= 11 cudart is a required package.
# if([version]$CUDA_VERSION_FULL -ge [version]"11.0") {
#     if(-not $CUDA_PACKAGES_IN -contains "cudart") {
#         $CUDA_PACKAGES_IN += 'cudart'
#     }
# }

Foreach ($package in $CUDA_PACKAGES_IN) {
    # Make sure the correct package name is used for nvcc.
    if($package -eq "nvcc" -and [version]$CUDA_VERSION_FULL -lt [version]"9.1"){
        $package="compiler"
    } elseif($package -eq "compiler" -and [version]$CUDA_VERSION_FULL -ge [version]"9.1") {
        $package="nvcc"
    }
    $CUDA_PACKAGES += " $($package)_$($CUDA_MAJOR).$($CUDA_MINOR)"

}
echo "$($CUDA_PACKAGES)"
## -----------------
## Prepare download
## -----------------

# Select the download link if known, otherwise have a guess.
$CUDA_REPO_PKG_REMOTE=""
if($CUDA_KNOWN_URLS.containsKey($CUDA_VERSION_FULL)){
    $CUDA_REPO_PKG_REMOTE=$CUDA_KNOWN_URLS[$CUDA_VERSION_FULL]
} else{
    # Guess what the url is given the most recent pattern (at the time of writing, 10.1)
    Write-Output "note: URL for CUDA ${$CUDA_VERSION_FULL} not known, estimating."
    $CUDA_REPO_PKG_REMOTE="http://developer.download.nvidia.com/compute/cuda/$($CUDA_MAJOR).$($CUDA_MINOR).$($CUDA_PATCH)/network_installers/cuda_$($CUDA_VERSION_FULL)_win10_network.exe"
}



$CUDA_REPO_PKG_LOCAL=$CUDA_FILE_NAMES[$CUDA_VERSION_FULL]
Write-Output "After downloading, attempting to use file name ${$CUDA_REPO_PKG_LOCAL}, files in directory are:"
Get-ChildItem

## ------------
## Install CUDA
## ------------

# Get CUDA network installer
Write-Output "Downloading CUDA Network Installer for $($CUDA_VERSION_FULL) from: $($CUDA_REPO_PKG_REMOTE)"
Invoke-WebRequest $CUDA_REPO_PKG_REMOTE -OutFile $CUDA_REPO_PKG_LOCAL | Out-Null
if(Test-Path -Path $CUDA_REPO_PKG_LOCAL){
    Write-Output "Downloading Complete"
} else {
    Write-Output "Error: Failed to download $($CUDA_REPO_PKG_LOCAL) from $($CUDA_REPO_PKG_REMOTE)"
    exit 1
}


$CUDNN_URL = $CUDNN_KNOWN_URLS[$CUDA_VERSION_FULL]
Write-Output "Downloading CUDNN $($CUDA_VERSION_FULL) from: $($CUDNN_URL)"
Invoke-WebRequest $($CUDNN_URL) -OutFile "cudnn.zip" | Out-Null
echo "Wrote file cudnn.zip, listing directory contents at directory"
echo "$(pwd)"
Unzip "cudnn.zip" .
echo "$(Get-ChildItem -Force)"

# Invoke silent install of CUDA (via network installer)
Write-Output "Installing CUDA $($CUDA_VERSION_FULL). Subpackages $($CUDA_PACKAGES) using file $($CUDA_REPO_PKG_LOCAL)"
Start-Process -Wait -FilePath .\"$($CUDA_REPO_PKG_LOCAL)" -ArgumentList "-s"

# Check the return status of the CUDA installer.
if (!$?) {
    Write-Output "Error: CUDA installer reported error. $($LASTEXITCODE)"
    exit 1 
}

# Store the CUDA_PATH in the environment for the current session, to be forwarded in the action.
$CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$($CUDA_MAJOR).$($CUDA_MINOR)"
$CUDA_PATH_VX_Y = "CUDA_PATH_V$($CUDA_MAJOR)_$($CUDA_MINOR)" 
# Set environmental variables in this session
$env:CUDA_PATH = "$($CUDA_PATH)"
$env:CUDA_PATH_VX_Y = "$($CUDA_PATH_VX_Y)"
Write-Output "CUDA_PATH $($CUDA_PATH)"
Write-Output "CUDA_PATH_VX_Y $($CUDA_PATH_VX_Y)"
Get-ChildItem $CUDA_PATH


$Source = 'cudnn'
if("$CUDA_VERSION_FULL" -eq "11.6.0") {
   echo "Renaming cuda directory to cudnn for cuda 11.6"
   Copy-Item -Path "cudnn-windows-x86_64-8.3.2.44_cuda11.5-archive\*" -Destination $CUDA_PATH -Recurse -Force  -ErrorAction SilentlyContinue
} else {
   Copy-Item -Path "cuda\*" -Destination $CUDA_PATH -Recurse -Force 
}




echo "CUDA_PATH=$($CUDA_PATH))" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
echo "CUDA PATH: $CUDA_PATH"
# PATH needs updating elsewhere, anything in here won't persist.
# Append $CUDA_PATH/bin to path.
# Set CUDA_PATH as an environmental variable
