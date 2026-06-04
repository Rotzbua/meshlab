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
STR_VERSION=$("$INSTALL_PATH/meshlab.exe" --version)
read -a strarr <<< "$STR_VERSION"
ML_VERSION=${strarr[1]} #get the meshlab version from the string

# Generate the WiX license dialog document from the bundled text resources
python3 - "$RESOURCES_PATH" "$INSTALL_PATH/LICENSE.rtf" <<'PY'
from pathlib import Path
import sys

resources_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

sections = [
    resources_path / "LICENSE.txt",
    resources_path / "privacy.txt",
]


def escape_rtf(text: str) -> str:
    chunks = []
    for char in text.replace("\r\n", "\n").replace("\r", "\n"):
        if char == "\\":
            chunks.append(r"\\")
        elif char == "{":
            chunks.append(r"\{")
        elif char == "}":
            chunks.append(r"\}")
        elif char == "\n":
            chunks.append("\\par\n")
        else:
            codepoint = ord(char)
            if 32 <= codepoint <= 126:
                chunks.append(char)
            else:
                signed_codepoint = codepoint if codepoint < 32768 else codepoint - 65536
                chunks.append(rf"\u{signed_codepoint}?")
    return "".join(chunks)


body = "\\par\\par\n".join(
    escape_rtf(section.read_text(encoding="utf-8").strip()) for section in sections
)

output_path.write_text(
    "{\\rtf1\\ansi\\deff0\n"
    "{\\fonttbl{\\f0\\fnil\\fcharset0 Arial;}}\n"
    "\\viewkind4\\uc1\\pard\\f0\\fs18\n"
    f"{body}\n"
    "}\n",
    encoding="utf-8",
)
PY

# Ensure dotnet global tools are on PATH (wix CLI is installed there)
export PATH="$PATH:$HOME/.dotnet/tools"

if ! command -v wix >/dev/null 2>&1; then
    echo "ERROR: wix CLI not found. Install it with: dotnet tool install --global wix --version 7.0.0"
    exit 1
fi

echo "Using WiX CLI: $(wix --version)"

# Ensure required WiX extensions are available
for WIX_EXT in WixToolset.UI.wixext WixToolset.Util.wixext WixToolset.Heat.wixext; do
    if ! wix extension list | grep -qx "$WIX_EXT"; then
        wix extension add "$WIX_EXT"
    fi
done

# Step 1 – Harvest all installed files into a component group
wix harvest directory "$INSTALL_PATH" \
    -ext WixToolset.Heat.wixext \
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

mkdir -p "$PACKAGES_PATH"

# Determine running architecture and build the final installer filename
ARCH=$(uname -m)
INSTALLER_NAME="MeshLab${ML_VERSION}-windows_${ARCH}.msi"

# Move the installer to the packages folder
mv "$INSTALL_PATH/MeshLab${ML_VERSION}-windows.msi" "$PACKAGES_PATH/$INSTALLER_NAME"
