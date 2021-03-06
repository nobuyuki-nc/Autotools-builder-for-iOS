#! /bin/sh

#  Automatic build script for iPhoneOS and iPhoneSimulator
#
#  Originally: https://github.com/x2on/OpenSSL-for-iPhone
#  Created by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################

ARCHS="i386 x86_64 armv7 armv7s arm64"

CURRENTPATH=$PWD
SOURCE_PREFIX=${SOURCE_PREFIX:-${CURRENTPATH}/src}
# asuume source is extracted under $SOURCE_PREFIX/<arch> and may be patched for that architecture

CONFIGURE=${CONFIGURE:-./configure}
CONFIGURE_OPT="${CONFIGURE_OPT:---host=arm-apple-darwin --disable-shared --enable-static}"
CONFIGURE_OPT_TARGET=--prefix

BUILDER=${BUILDER:-make}
BUILDER_OPT=${BUILDER_OPT:-}

INSTALLER=${INSTALLER:-make}
INSTALLER_OPT=${INSTALLER_OPT:-install}

CLEANER=${CLEANER:-make}
CLEANER_OPT=${CLEANER_OPT:-clean}

###########################################################################

SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
    echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
    echo "run"
    echo "sudo xcode-select -switch <xcode path>"
    echo "for default installation:"
    echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

case $DEVELOPER in  
    *\ * )
        echo "Your Xcode path contains whitespaces, which is not supported."
        exit 1
        ;;
esac

case $CURRENTPATH in  
    *\ * )
        echo "Your path contains whitespaces, which is not supported by 'make install'."
        exit 1
        ;;
esac

OBJECT_PREFIX=${CURRENTPATH}/obj
mkdir -p "${OBJECT_PREFIX}"
LIBRARY_DIRECTORY=${CURRENTPATH}/lib
mkdir -p "${LIBRARY_DIRECTORY}"
HEADER_DIRECTORY=${CURRENTPATH}/include
mkdir -p "${HEADER_DIRECTORY}"

set +e
for ARCH in ${ARCHS}; do
    pushd "${SOURCE_PREFIX}/${ARCH}"

    if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
        PLATFORM="iPhoneSimulator"
    else
        PLATFORM="iPhoneOS"
    fi
    
    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"

    echo "Configuring for ${PLATFORM} ${SDKVERSION} ${ARCH}..."
    export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0"
    export CXX="${BUILD_TOOLS}/usr/bin/g++ -arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0"
    export OBJC="${CC}"
    export OBJCXX="${CXX}"
    TARGET_DIRECTORY=${OBJECT_PREFIX}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk
    mkdir -p "${TARGET_DIRECTORY}"
    LOG="${TARGET_DIRECTORY}/configure.log"

    if [ "$1" == "verbose" ]; then
        eval '${CONFIGURE} ${CONFIGURE_OPT} ${CONFIGURE_OPT_'${ARCH}'} ${CONFIGURE_OPT_TARGET}="${TARGET_DIRECTORY}" 2>&1 | tee "${LOG}"'
    else
        eval '${CONFIGURE} ${CONFIGURE_OPT} ${CONFIGURE_OPT_'${ARCH}'} ${CONFIGURE_OPT_TARGET}="${TARGET_DIRECTORY}" >"${LOG}" 2>&1'
    fi
    
    if [ $? != 0 ]; then 
        echo "Problem while configure - Please check ${LOG}"
        exit 1
    fi

    echo "Building library..."
    LOG="${TARGET_DIRECTORY}/build.log"

    if [ "$1" == "verbose" ]; then
        ${BUILDER} ${BUILDER_OPT} 2>&1 | tee "${LOG}"
    else
        ${BUILDER} ${BUILDER_OPT} >"${LOG}" 2>&1
    fi
    
    if [ $? != 0 ]; then 
        echo "Problem while build - Please check ${LOG}"
        exit 1
    fi
    
    echo "Installing library..."
    LOG="${TARGET_DIRECTORY}/install.log"
    ${INSTALLER} ${INSTALLER_OPT} >"${LOG}" 2>&1
    ${CLEANER} ${CLEANER_OPT} >>"${LOG}" 2>&1

    popd
done
set -e

echo "Building universal / fat binary..."
for a in "${TARGET_DIRECTORY}"/lib/lib*.a; do
    archive=`basename "$a"`
    lipo -create "${OBJECT_PREFIX}"/*/lib/"$archive" -output "${LIBRARY_DIRECTORY}/$archive"
done

echo "Preparing pkg-config file..."
cp -R "${TARGET_DIRECTORY}"/lib/pkgconfig "${LIBRARY_DIRECTORY}"
sed -i.bak 's!'"${TARGET_DIRECTORY}"'!'"${CURRENTPATH}"'!g' "${LIBRARY_DIRECTORY}"/pkgconfig/*.pc

echo "Preparing header file...."
cp -R ${TARGET_DIRECTORY}/include/ ${HEADER_DIRECTORY}

echo "Building done."
echo "Done."
