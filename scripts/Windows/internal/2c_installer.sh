#!/bin/bash

SCRIPTS_PATH="$(dirname "$(realpath "$0")")"/..
RESOURCES_PATH=$SCRIPTS_PATH/../../resources
INSTALL_PATH=$SCRIPTS_PATH/../../install
PACKAGES_PATH=$SCRIPTS_PATH/../../packages

#checking for parameters
for i in "$@"
do
case $i in
    -i=*|--install_path=*)
        INSTALL_PATH="${i#*=}"
        shift # past argument=value
        ;;
    -p=*|--packages_path=*)
        PACKAGES_PATH="${i#*=}"
        shift # past argument=value
        ;;
    *)
        # unknown option
        ;;
esac
done

# Get MeshLab version from the installed binary
IFS=' ' #space delimiter
STR_VERSION=$($INSTALL_PATH/meshlab.exe --version)
read -a strarr <<< "$STR_VERSION"
ML_VERSION=${strarr[1]} #get the meshlab version from the string

# Copy LICENSE.rtf required by the WiX UI into the install directory
cp $RESOURCES_PATH/windows/LICENSE.rtf $INSTALL_PATH/

# Ensure dotnet global tools are on PATH (wix CLI is installed there)
export PATH="$PATH:$HOME/.dotnet/tools"

if ! command -v wix >/dev/null 2>&1; then
    echo "ERROR: wix CLI not found. Install it with: dotnet tool install --global wix --version 7.0.0"
    exit 1
fi

echo "Using WiX CLI: $(wix --version)"

# Ensure required WiX extensions are available
for WIX_EXT in WixToolset.UI.wixext WixToolset.Util.wixext WixToolset.Heat.wixext; do
    if ! wix extension list | grep -q "$WIX_EXT"; then
        wix extension add "$WIX_EXT"
    fi
done

# Step 1 – Harvest all installed files into a component group
wix harvest directory "$INSTALL_PATH" \
    -o "$INSTALL_PATH/meshlab_files.wxs" \
    -cg MeshLabFiles \
    -dr INSTALLFOLDER \
    -scom -sreg -sfrag -srd \
    --var var.SourceDir

# Step 2 – Build the MSI
wix build \
    "$RESOURCES_PATH/windows/meshlab.wxs" \
    "$INSTALL_PATH/meshlab_files.wxs" \
    -d "Version=$ML_VERSION" \
    -d "SourceDir=$INSTALL_PATH" \
    -arch x64 \
    -ext WixToolset.UI.wixext \
    -ext WixToolset.Util.wixext \
    -o "$INSTALL_PATH/MeshLab${ML_VERSION}-windows.msi"

# Cleanup temporary WiX build artifacts
rm -f "$INSTALL_PATH/meshlab_files.wxs" \
      "$INSTALL_PATH/MeshLab${ML_VERSION}-windows.wixpdb" \
      "$INSTALL_PATH/LICENSE.rtf"

mkdir -p $PACKAGES_PATH

# Determine running architecture and build the final installer filename
ARCH=$(uname -m)
INSTALLER_NAME="MeshLab${ML_VERSION}-windows_${ARCH}.msi"

# Move the installer to the packages folder
mv "$INSTALL_PATH/MeshLab${ML_VERSION}-windows.msi" "$PACKAGES_PATH/$INSTALLER_NAME"
