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
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/libevent
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    VERSION=release-2.1.8-stable
    if [ "TRUE" = "${RABBIT_USE_REPOSITORIES}" ]; then
        echo "git clone -q --branch=${VERSION} https://github.com/libevent/libevent.git ${RABBIT_BUILD_SOURCE_CODE}"
        git clone -q --branch=$VERSION https://github.com/libevent/libevent.git ${RABBIT_BUILD_SOURCE_CODE}
    else
        mkdir -p ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        echo "wget -nv -c https://github.com/libevent/libevent/archive/${VERSION}.tar.gz"
        wget -nv -c https://github.com/libevent/libevent/archive/${VERSION}.tar.gz
        tar xzf ${VERSION}.tar.gz
        mv libevent-${VERSION} ..
        rm -fr libevent-${VERSION}.tar.gz ${RABBIT_BUILD_SOURCE_CODE}
        cd ..
        mv libevent-${VERSION} ${RABBIT_BUILD_SOURCE_CODE} 
    fi
fi

cd ${RABBIT_BUILD_SOURCE_CODE}

if [ ! -f configure -a "${RABBIT_BUILD_TARGERT}" != "windows_msvc" ]; then
    ./autogen.sh
fi

mkdir -p build_${RABBIT_BUILD_TARGERT}
cd build_${RABBIT_BUILD_TARGERT}
if [ "$RABBIT_CLEAN" = "TRUE" ]; then
    rm -fr *
fi

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

if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    CMAKE_PARA="-DEVENT__BUILD_SHARED_LIBRARIES=OFF"
    CONFIG_PARA="--enable-static --disable-shared"
else
    CMAKE_PARA="-DEVENT__BUILD_SHARED_LIBRARIES=ON"
    CONFIG_PARA="--disable-static --enable-shared"
fi

if [ "$RABBIT_CONFIG" = "Relase" ]; then
    CMAKE_PARA="${CMAKE_PARA} -DEVENT__DISABLE_DEBUG_MODE=ON"
else
    CMAKE_PARA="${CMAKE_PARA} -DEVENT__DISABLE_DEBUG_MODE=OFF"
fi
     
MAKE_PARA="-- ${RABBIT_MAKE_JOB_PARA}"
case ${RABBIT_BUILD_TARGERT} in
    android)
        if [ -n "$RABBIT_CMAKE_MAKE_PROGRAM" ]; then
            CMAKE_PARA="${CMAKE_PARA} -DCMAKE_MAKE_PROGRAM=$RABBIT_CMAKE_MAKE_PROGRAM" 
        fi
        CMAKE_PARA="${CMAKE_PARA} -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-android.cmake"
    ;;
    unix)
        #../configure --prefix=$RABBIT_BUILD_PREFIX ${CONFIG_PARA} \
        #   CFLAGS="-I${RABBIT_BUILD_PREFIX}/include" \
        #   CPPFLAGS="-I${RABBIT_BUILD_PREFIX}/include" \
        #   LIBS="-L${RABBIT_BUILD_PREFIX}/lib -lcrypto -lssl"
        #make ${RABBIT_MAKE_JOB_PARA} V=1
        #make install
        
        #cd $CUR_DIR
        #exit 0
        ;;
    windows_msvc)
        #RABBITIM_GENERATORS="Visual Studio 12 2013"
        MAKE_PARA=""
        ;;
    windows_mingw)
        case `uname -s` in
            Linux*|Unix*|CYGWIN*)
                CMAKE_PARA="${CMAKE_PARA} -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-mingw.cmake"
                
                ;;
            *)
            ;;
        esac
        
        ../configure --prefix=$RABBIT_BUILD_PREFIX ${CONFIG_PARA}
        make ${RABBIT_MAKE_JOB_PARA}
        make install
        
        cd $CUR_DIR
        exit 0
        ;;
    *)
    echo "${HELP_STRING}"
    cd $CUR_DIR
    return 2
    ;;
esac

echo "cmake .. -DCMAKE_INSTALL_PREFIX=$RABBIT_BUILD_PREFIX -DCMAKE_BUILD_TYPE=Release -G\"${RABBITIM_GENERATORS}\" ${CMAKE_PARA}"
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$RABBIT_BUILD_PREFIX" \
    -DEVENT__DISABLE_SAMPLES:BOOL=ON -DEVENT__DISABLE_TESTS:BOOL=ON \
    -G"${RABBITIM_GENERATORS}" ${CMAKE_PARA} 

cmake --build . --target install --config ${RABBIT_CONFIG} ${MAKE_PARA}
    
cd $CUR_DIR
