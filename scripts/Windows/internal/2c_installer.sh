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

# Locate WiX Toolset (installed via choco install wixtoolset)
WIX_BIN=""
for WIX_DIR in \
    "/c/Program Files (x86)/WiX Toolset v3.11" \
    "/c/Program Files (x86)/WiX Toolset v3.14" \
    "/c/Program Files (x86)/WiX Toolset v3"* \
    "/c/Program Files/WiX Toolset v3"*; do
    if [ -d "$WIX_DIR/bin" ]; then
        WIX_BIN="$WIX_DIR/bin"
        break
    fi
done

if [ -z "$WIX_BIN" ]; then
    echo "ERROR: WiX Toolset not found. Install it with: choco install wixtoolset"
    exit 1
fi

echo "Using WiX Toolset at: $WIX_BIN"

# Step 1 – Harvest all installed files into a component group
"$WIX_BIN/heat.exe" dir "$INSTALL_PATH" \
    -cg MeshLabFiles \
    -dr INSTALLFOLDER \
    -ke -gg -scom -sreg -sfrag -srd \
    -var var.SourceDir \
    -out "$INSTALL_PATH/meshlab_files.wxs"

# Step 2 – Compile WiX sources
"$WIX_BIN/candle.exe" \
    -dVersion="$ML_VERSION" \
    -dSourceDir="$INSTALL_PATH" \
    -arch x64 \
    -ext WixUtilExtension \
    "$RESOURCES_PATH/windows/meshlab.wxs" \
    "$INSTALL_PATH/meshlab_files.wxs" \
    -out "$INSTALL_PATH/"

# Step 3 – Link and produce the MSI
"$WIX_BIN/light.exe" \
    -ext WixUIExtension \
    -ext WixUtilExtension \
    "$INSTALL_PATH/meshlab.wixobj" \
    "$INSTALL_PATH/meshlab_files.wixobj" \
    -out "$INSTALL_PATH/MeshLab${ML_VERSION}-windows.msi"

# Cleanup temporary WiX build artefacts
rm -f "$INSTALL_PATH/meshlab_files.wxs" \
      "$INSTALL_PATH/meshlab.wixobj" \
      "$INSTALL_PATH/meshlab_files.wixobj" \
      "$INSTALL_PATH/LICENSE.rtf"

mkdir -p $PACKAGES_PATH

# Determine running architecture and build the final installer filename
ARCH=$(uname -m)
INSTALLER_NAME="MeshLab${ML_VERSION}-windows_${ARCH}.msi"

# Move the installer to the packages folder
mv "$INSTALL_PATH/MeshLab${ML_VERSION}-windows.msi" "$PACKAGES_PATH/$INSTALLER_NAME"
