#!/bin/bash

#作者：康林
#参数:
#    $1:编译目标(android、windows_msvc、windows_mingw、unix)
#    $2:源码的位置

#运行本脚本前,先运行 build_$1_envsetup.sh 进行环境变量设置,需要先设置下面变量:
#   RABBIT_BUILD_TARGERT   编译目标（android、windows_msvc、windows_mingw、unix)
#   RABBIT_BUILD_PREFIX=`pwd`/../${RABBIT_BUILD_TARGERT}  #修改这里为安装前缀
#   RABBIT_BUILD_SOURCE_CODE    #源码目录
#   RABBIT_BUILD_CROSS_PREFIX   #交叉编译前缀
#   RABBIT_BUILD_CROSS_SYSROOT  #交叉编译平台的 sysroot

set -e
HELP_STRING="Usage $0 PLATFORM(android|windows_msvc|windows_mingw|unix) [SOURCE_CODE_ROOT_DIRECTORY]"

case $1 in
    android|windows_msvc|windows_mingw|unix)
    RABBIT_BUILD_TARGERT=$1
    ;;
    *)
    echo "${HELP_STRING}"
    exit 1
    ;;
esac

if [ -z "${RABBIT_BUILD_PREFIX}" ]; then
    echo ". `pwd`/build_envsetup_${RABBIT_BUILD_TARGERT}.sh"
    . `pwd`/build_envsetup_${RABBIT_BUILD_TARGERT}.sh
fi

if [ -n "$2" ]; then
    RABBIT_BUILD_SOURCE_CODE=$2
else
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/boost
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    VERSION=1.65.0
    FILE_VERSION=1_65_0
    if [ "TRUE" = "${RABBIT_USE_REPOSITORIES}" ]; then
        git clone -q https://github.com/boostorg/boost.git ${RABBIT_BUILD_SOURCE_CODE}
	    git submodule update --init --recursive
	    git checkout -b boost-${VERSION} boost-${VERSION} 
    else
        mkdir -p ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        echo "wget -nv -c https://dl.bintray.com/boostorg/release/${VERSION}/source/boost_${FILE_VERSION}.tar.gz"
        wget -nv -c https://dl.bintray.com/boostorg/release/${VERSION}/source/boost_${FILE_VERSION}.tar.gz
        echo "tar xzf boost_${FILE_VERSION}.tar.gz"
        tar xzf boost_${FILE_VERSION}.tar.gz
        mv boost_${FILE_VERSION} ..
        rm -fr boost_${FILE_VERSION}.tar.gz ${RABBIT_BUILD_SOURCE_CODE}
        cd ..
        mv boost_${FILE_VERSION} ${RABBIT_BUILD_SOURCE_CODE} 
    fi
fi

cd ${RABBIT_BUILD_SOURCE_CODE}

echo ""
echo "RABBIT_BUILD_TARGERT:${RABBIT_BUILD_TARGERT}"
echo "RABBIT_BUILD_SOURCE_CODE:$RABBIT_BUILD_SOURCE_CODE"
echo "CUR_DIR:`pwd`"
echo "RABBIT_BUILD_PREFIX:$RABBIT_BUILD_PREFIX"
echo "RABBIT_BUILD_HOST:$RABBIT_BUILD_HOST"
echo "RABBIT_BUILD_CROSS_HOST:$RABBIT_BUILD_CROSS_HOST"
echo "RABBIT_BUILD_CROSS_PREFIX:$RABBIT_BUILD_CROSS_PREFIX"
echo "RABBIT_BUILD_CROSS_SYSROOT:$RABBIT_BUILD_CROSS_SYSROOT"
echo "RABBIT_BUILD_STATIC:$RABBIT_BUILD_STATIC"
echo "PKG_CONFIG_PATH:${PKG_CONFIG_PATH}"
echo "PKG_CONFIG_LIBDIR:${PKG_CONFIG_LIBDIR}"
echo "PATH:${PATH}"
echo ""

MAKE_PARA=" ${RABBIT_MAKE_JOB_PARA} "

if [ "$RABBIT_CONFIG" = "Release" ]; then
    variant=release
else
    variant=debug
fi

if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    link=static
else
    link=shared
fi

BOOTSTRAP="bootstrap.sh"
toolset=gcc
case ${RABBIT_BUILD_TARGERT} in
    android)
       ;;
    unix)
        MAKE_PARA="${MAKE_PARA} CFLAGS=-fPIC"
        if [ "$RABBIT_ARCH" = "x64" ]; then
            MAKE_PARA="${MAKE_PARA} address-model=64"
        fi
        ;;
    windows_msvc)
        if [ "$RABBIT_ARCH" = "x64" ]; then
            MAKE_PARA=" address-model=64"
        fi
        
        if [  "$RABBIT_TOOLCHAIN_VERSION" = "15" ]; then
            toolset=msvc-15.0
        fi

        if [  "$RABBIT_TOOLCHAIN_VERSION" = "14" ]; then
            toolset=msvc-14.0
        fi
        
        if [  "$RABBIT_TOOLCHAIN_VERSION" = "12" ]; then
            toolset=msvc-12.0
        fi
        BOOTSTRAP="bootstrap.bat"
        ;;
    windows_mingw)
        
        if [ "$RABBIT_ARCH" = "x64" ]; then
            MAKE_PARA="${MAKE_PARA} address-model=64 "
        fi
        ;;
    *)
        echo "${HELP_STRING}"
        cd $CUR_DIR
        exit 3
        ;;
esac

if [ "${RABBIT_CLEAN}" = "TRUE" ]; then
    if [ -f "b2" ]; then
        ./b2 --clean
        rm -fr bin.v2
    fi
fi
if [ ! -f "b2" ]; then
    bash ${BOOTSTRAP} --with-toolset=${toolset}
fi

./b2 --prefix=${RABBIT_BUILD_PREFIX} \
    --build-type=minimal \
    --layout=system \
    toolset=${toolset} ${MAKE_PARA} \
    variant=${variant} \
    --without-python \
    install  
    
cd $CUR_DIR
