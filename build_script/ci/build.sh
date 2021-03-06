#!/bin/bash
set -ev
    
#urlendcode
function urlencode()
{
    content=$1
    x=”
    content=`echo -n “$content” | od -An -tx1 | tr ‘ ‘ %`
    for i in $content
    do
              x=$x$i;
    done
    content=$x
    echo $content;
}

if [ "$BUILD_TARGERT" = "windows_mingw" \
    -a -n "$APPVEYOR" ]; then
    export PATH=/C/Qt/Tools/mingw${RABBIT_TOOLCHAIN_VERSION}_32/bin:$PATH
    export USER_ROOT_PATH=/C/Qt/Tools/mingw${RABBIT_TOOLCHAIN_VERSION}_32
fi
TARGET_OS=`uname -s`
case $TARGET_OS in
    MINGW* | CYGWIN* | MSYS*)
        export PKG_CONFIG=/c/msys64/mingw32/bin/pkg-config.exe
        ;;
    Linux* | Unix*)
    ;;
    *)
    ;;
esac
if [ "$BUILD_TARGERT" = "windows_msvc" ]; then
    export PATH=/C/Perl/bin:$PATH
    rm -fr /usr/include
fi

PROJECT_DIR=`pwd`
if [ -n "$1" ]; then
    PROJECT_DIR=$1
fi

SCRIPT_DIR=${PROJECT_DIR}/build_script
if [ -d ${PROJECT_DIR}/ThirdLibrary/build_script ]; then
    SCRIPT_DIR=${PROJECT_DIR}/ThirdLibrary/build_script
fi
cd ${SCRIPT_DIR}
SOURCE_DIR=${SCRIPT_DIR}/../src

if [ -z "${LIBRARY_NUMBER}" ]; then
    LIBRARY_NUMBER=0
fi

#下载预编译库
#DOWNLOAD_URL="https://github.com/KangLin/RabbitThirdLibrary/releases/download/${DOWNLOAD_VERSION}/RABBIT_${BUILD_TARGERT}${RABBIT_TOOLCHAIN_VERSION}_${RABBIT_ARCH}_qt${QT_VERSION}_${RABBIT_CONFIG}_${BUILD_VERSION}.zip"
#echo "wget -q -c -O ${SCRIPT_DIR}/../${BUILD_TARGERT}.zip ${DOWNLOAD_URL} "
if [ -n "$DOWNLOAD_URL" ]; then
    echo "appveyor DownloadFile \"${DOWNLOAD_URL}\" -FileName ${SCRIPT_DIR}/../${BUILD_TARGERT}.zip"
    appveyor DownloadFile "${DOWNLOAD_URL}" -FileName ${SCRIPT_DIR}/../${BUILD_TARGERT}.zip
    #wget --passive -c -p -O ${SCRIPT_DIR}/../${BUILD_TARGERT}.zip ${DOWNLOAD_URL}
    RABBIT_BUILD_PREFIX=${SCRIPT_DIR}/../${BUILD_TARGERT}
    if [ ! -d ${RABBIT_BUILD_PREFIX} ]; then
        mkdir -p ${RABBIT_BUILD_PREFIX}
    fi
    unzip -q -d ${RABBIT_BUILD_PREFIX} ${SCRIPT_DIR}/../${BUILD_TARGERT}.zip
    if [ "$PROJECT_NAME" != "RabbitThirdLibrary" \
        -a "$BUILD_TARGERT" != "windows_msvc" \
        -a -f "${RABBIT_BUILD_PREFIX}/change_prefix.sh" ]; then

        cd ${RABBIT_BUILD_PREFIX}

        THIRDLIBRARY_DIR_PREFIX=/c/projects/rabbitthirdlibrary/build_script/../${BUILD_TARGERT}

        echo "bash change_prefix.sh"
        bash change_prefix.sh
        cat ${SCRIPT_DIR}/../${BUILD_TARGERT}/lib/pkgconfig/libcurl.pc
        
        cd ${SCRIPT_DIR}
    fi
fi

if [ "$BUILD_TARGERT" = "android" ]; then
    export ANDROID_SDK_ROOT=${SCRIPT_DIR}/../Tools/android-sdk
    export ANDROID_NDK_ROOT=${SCRIPT_DIR}/../Tools/android-ndk
    if [ -z "$APPVEYOR" ]; then
        export JAVA_HOME="/C/Program Files (x86)/Java/jdk1.8.0"
    fi
    export QT_ROOT=${SCRIPT_DIR}/../Tools/Qt/${QT_VERSION}/${QT_VERSION_DIR}/android_armv7
    if [ "${QT_VERSION}" = "5.2.1" ]; then
        export QT_ROOT=${SCRIPT_DIR}/../Tools/Qt/${QT_VERSION}/android_armv7
    fi
    export PATH=${SCRIPT_DIR}/../Tools/apache-ant/bin:$JAVA_HOME:$PATH
fi
if [ "$BUILD_TARGERT" != "windows_msvc" ]; then
    RABBIT_MAKE_JOB_PARA="-j`cat /proc/cpuinfo |grep 'cpu cores' |wc -l`"  #make 同时工作进程参数
    if [ "$RABBIT_MAKE_JOB_PARA" = "-j1" ];then
            RABBIT_MAKE_JOB_PARA="-j2"
    fi
    export RABBIT_MAKE_JOB_PARA
fi

echo "---------------------------------------------------------------------------"
echo "RABBIT_BUILD_PREFIX:$RABBIT_BUILD_PREFIX"
echo "QT_BIN:$QT_BIN"
echo "QT_ROOT:$QT_ROOT"
echo "PKG_CONFIG_PATH:$PKG_CONFIG_PATH"
echo "PKG_CONFIG_SYSROOT_DIR:$PKG_CONFIG_SYSROOT_DIR"
echo "PATH=$PATH"
echo "RABBIT_BUILD_THIRDLIBRARY:$RABBIT_BUILD_THIRDLIBRARY"
echo "---------------------------------------------------------------------------"

for v in ${RABBITIM_LIBRARY}
do
    if [ "$v" = "rabbitim" ]; then
        bash ./build_$v.sh ${BUILD_TARGERT} # > /dev/null
    else
        if [ "$APPVEYOR" = "True" ]; then
            bash ./build_$v.sh ${BUILD_TARGERT} ${SOURCE_DIR}/$v
        else
            bash ./build_$v.sh ${BUILD_TARGERT} ${SOURCE_DIR}/$v > /dev/null
        fi
    fi
done
