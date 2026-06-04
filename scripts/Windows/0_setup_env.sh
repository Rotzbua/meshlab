#!/bin/bash
# this is a script shell sets up a Windows environment where
# MeshLab can be compiled, deployed and packaged.
#
# Run this script if you never installed any of the MeshLab dependencies.
#
# Requires: choco

DONT_INSTALL_QT=false

#checking for parameters
for i in "$@"
do
case $i in
    --dont_install_qt)
        DONT_INSTALL_QT=true
        shift # past argument=value
        ;;
    *)
        # unknown option
        ;;
esac
done

choco install --no-progress cmake ninja ccache wget dotnet-sdk python

# Install WiX CLI v7 via dotnet tool (do not use outdated choco wixtoolset package)
if dotnet tool list --global | grep -q '^wix '; then
    dotnet tool update --global wix --version 7.0.0
else
    dotnet tool install --global wix --version 7.0.0
fi

if [ "$DONT_INSTALL_QT" = false ] ; then
    echo "=== installing qt packages..."

    choco install qt5-default
else
    echo "=== jumping installation of qt packages..."
fi
