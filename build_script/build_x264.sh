#!/bin/bash

#作者：康林
#参数:
#    $1:编译目标(android、windows_msvc、windows_mingw、unix)
#    $2:源码的位置 

#运行本脚本前,先运行 build_$1_envsetup.sh 进行环境变量设置,需要先设置下面变量:
#   RABBIT_BUILD_TARGERT   编译目标（android、windows_msvc、windows_mingw、unix）
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
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/x264
fi

#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    X264_VERSION=stable
    echo "git clone -q git://git.videolan.org/x264.git ${RABBIT_BUILD_SOURCE_CODE}"
    #git clone -q git://git.videolan.org/x264.git ${RABBIT_BUILD_SOURCE_CODE}
    git clone -q -b ${X264_VERSION} git://git.videolan.org/x264.git ${RABBIT_BUILD_SOURCE_CODE}
fi

CUR_DIR=`pwd`
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
echo ""

if [ "$RABBIT_CLEAN" = "TRUE" ]; then
    if [ -d ".git" ]; then
        git clean -xdf
    else
        make distclean
    fi
fi

echo "configure ..."
if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    CONFIG_PARA="--enable-static"
else
    CONFIG_PARA="--enable-shared"
fi
case ${RABBIT_BUILD_TARGERT} in
    android)
        export CC=${RABBIT_BUILD_CROSS_PREFIX}gcc 
        export CXX=${RABBIT_BUILD_CROSS_PREFIX}g++
        export AR=${RABBIT_BUILD_CROSS_PREFIX}ar
        export LD=${RABBIT_BUILD_CROSS_PREFIX}ld
        #export AS=${RABBIT_BUILD_CROSS_PREFIX}as
        export STRIP=${RABBIT_BUILD_CROSS_PREFIX}strip
        export NM=${RABBIT_BUILD_CROSS_PREFIX}nm
        #export RANLIB=${RABBIT_BUILD_CROSS_PREFIX}ranlib
        CONFIG_PARA="--cross-prefix=${RABBIT_BUILD_CROSS_PREFIX} --enable-static --host=$RABBIT_BUILD_CROSS_HOST"
        CONFIG_PARA="${CONFIG_PARA} --sysroot=${RABBIT_BUILD_CROSS_SYSROOT}"
        if [ "${RABBIT_ARCH}" = "arm" ]; then
            CFLAGS="-march=armv7-a -mfpu=neon"
            CPPFLAGS="-march=armv7-a -mfpu=neon"
            ASFLAGS="-march=armv7-a -mfpu=neon"
        fi
        CFLAGS="${CFLAGS} --sysroot=${RABBIT_BUILD_CROSS_SYSROOT}"
        CPPFLAGS="${CPPFLAGS} --sysroot=${RABBIT_BUILD_CROSS_SYSROOT}"
        ;;
    unix)
    ;;
    windows_msvc)
        cd $CUR_DIR
        exit 0
        export MSYSTEM=MINGW32
        export CC=cl
    ;;
    windows_mingw)
        case `uname -s` in
            Linux*|Unix*|CYGWIN*)
                CONFIG_PARA="${CONFIG_PARA} --cross-prefix=${RABBIT_BUILD_CROSS_PREFIX} --host=$RABBIT_BUILD_CROSS_HOST"
                ;;
            MSYS*|MINGW*)
                CONFIG_PARA="${CONFIG_PARA} --host=$RABBIT_BUILD_CROSS_HOST"
                ;;
        *)
            ;;
        esac
        ;;
    *)
        echo "${HELP_STRING}"
        cd $CUR_DIR
        exit 2
        ;;
esac

CONFIG_PARA="${CONFIG_PARA} --prefix=$RABBIT_BUILD_PREFIX --disable-cli --disable-opencl --enable-pic "

echo "./configure ${CONFIG_PARA} --extra-cflags=\"${CFLAGS}\" --extra-asflags=\"${ASFLAGS}\""
if [ -n "$ASFLAGS" ]; then
    ./configure ${CONFIG_PARA} --extra-cflags="${CFLAGS}" --extra-asflags="${ASFLAGS}"
else
    ./configure ${CONFIG_PARA} --extra-cflags="${CFLAGS}" 
fi

echo "make install"
make ${RABBIT_MAKE_JOB_PARA} 
make install

cd $CUR_DIR
