#!/usr/bin/env bash

set -eu
trap 'exit 130' INT

echo "++++++++++++++++++++++++++++ STATS ++++++++++++++++++++++++++++"
echo "PWD: $(pwd)"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

FINISH_DIR=$(pwd)

mkdir -p builds
cd builds
BUILD_DIR=$(pwd)

# sudo apt install -y libelf-dev
# sudo apt-get -y install sudo apt-utils build-essential openssl clang graphviz-dev git libgnutls28-dev

#### Build AFLNet ####
cd "${BUILD_DIR}"

BUILD_TARGETS=("afl-fuzz" "afl-fuzz-noaffin" "afl-fuzz-print" "afl-fuzz-noaffin-print" "afl-fuzz-noaffin-coredump" "afl-fuzz-long" "afl-fuzz-noaffin-long")
BUILD_FLAGS=("" "-DNOAFFIN_BENCH=1" "-DPRINT_BENCH=1" "-DNOAFFIN_BENCH=1 -DPRINT_BENCH=1" "-DNOAFFIN_BENCH=1 -DCORE_BENCH=1 -DLONG_BENCH=1" "-DLONG_BENCH=1" "-DNOAFFIN_BENCH=1 -DLONG_BENCH=1")

git clone https://github.com/andronat/aflnet.git --branch mymaster --single-branch aflnet
cd aflnet

IT=0
for TARGET in "${BUILD_TARGETS[@]}"; do
  echo "Building target: ${TARGET}"

  export CFLAGS="-O3 -funroll-loops ${BUILD_FLAGS[${IT}]}"
  touch afl-fuzz.c && touch debug.h
  make -j all && cd llvm_mode/ && make -j && echo $? && cd ..

  cp "./afl-fuzz" "${FINISH_DIR}/${TARGET}"
  cp "./aflnet-replay" "${FINISH_DIR}/aflnet-replay"
  ((IT = IT + 1))
done

#### Build SnapFuzz ####
cd "${BUILD_DIR}"

git clone https://github.com/andronat/SaBRe.git --branch snapfuzz_2.0 --single-branch sabre
cd sabre

mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=RELEASE ..
make -j
cp ./sabre "${FINISH_DIR}/sabre"
cp ./plugins/sbr-afl/libsbr-afl.so "${FINISH_DIR}/libsbr-afl.so"

#### Build LightFTP ####
cd "${BUILD_DIR}"

git clone https://github.com/andronat/LightFTP fftp
cd fftp

git checkout snapfuzz_aflnet
cd Source/Release
make clean
CC="${BUILD_DIR}/aflnet/afl-clang-fast" make -j all
cp ./fftp "${FINISH_DIR}/fftp"

make clean
CC="${BUILD_DIR}/aflnet/afl-clang-fast" CFLAGS="-fsanitize=address" make -j all
cp ./fftp "${FINISH_DIR}/fftp-asan"

make clean
CC="${BUILD_DIR}/aflnet/afl-clang-fast" CFLAGS="-fsanitize=thread" make -j all
cp ./fftp "${FINISH_DIR}/fftp-tsan"

# git checkout snapfuzz_aflnet_pthread
# CC="${BUILD_DIR}/aflnet/afl-clang-fast" make -j clean all
# cp ./fftp "${FINISH_DIR}/fftp-pthreadjoin"

#### Build dnsmasq ####
cd "${BUILD_DIR}"

git clone git://thekelleys.org.uk/dnsmasq.git dnsmasq
cd dnsmasq

git checkout v2.73rc6
CC="${BUILD_DIR}/aflnet/afl-clang-fast" make -j
cp ./src/dnsmasq "${FINISH_DIR}/dnsmasq"

make clean

sed -i 's/CFLAGS        = -Wall -W -O2/CFLAGS= -fsanitize=address/' Makefile
sed -i 's/LDFLAGS       =/LDFLAGS= -fsanitize=address/' Makefile

CC="${BUILD_DIR}/aflnet/afl-clang-fast" make -j
cp ./src/dnsmasq "${FINISH_DIR}/dnsmasq-asan"

#### Build DICOM ####
cd "${BUILD_DIR}"

export PATH="${PATH}:${BUILD_DIR}/aflnet"

git clone https://github.com/andronat/dcmtk --branch snapfuzz dcmtk
cd dcmtk

mkdir build && cd build
cmake ..
make -j dcmqrscp

cp ./bin/dcmqrscp "${FINISH_DIR}/dcmqrscp"

cd "${BUILD_DIR}/dcmtk"
git checkout snapfuzz_sanitizers
cd build
cmake ..
make -j dcmqrscp

cp ./bin/dcmqrscp "${FINISH_DIR}/dcmqrscp-asan"

#### Build live555 ####
cd "${BUILD_DIR}"

export PATH="${PATH}:${BUILD_DIR}/aflnet"
export AFL_PATH="${BUILD_DIR}/aflnet"

git clone https://github.com/andronat/live555.git --branch snapfuzz live555
cd live555

./genMakefiles linux
make -j clean all

cp ./testProgs/testOnDemandRTSPServer "${FINISH_DIR}/testOnDemandRTSPServer"
cp "${BUILD_DIR}/aflnet/tutorials/live555/sample_media_sources"/* "${FINISH_DIR}/"

cp "${BUILD_DIR}/aflnet/tutorials/live555/rtsp.dict" "${FINISH_DIR}/conf"
cp -r "${BUILD_DIR}/aflnet/tutorials/live555/in-rtsp" "${FINISH_DIR}/conf"

make clean

git checkout snapfuzz_asan
./genMakefiles linux
make -j clean all

cp ./testProgs/testOnDemandRTSPServer "${FINISH_DIR}/testOnDemandRTSPServer-asan"

#### Build TinyDTLS ####
cd "${BUILD_DIR}"

git clone https://github.com/andronat/tinydtls-fuzz.git tinydtls
cd tinydtls
git checkout 06995d4
cd tests
CC="${BUILD_DIR}/aflnet/afl-clang-fast" make clean all

cp "dtls-server" "${FINISH_DIR}/dtls-server"

cp -r "${BUILD_DIR}/aflnet/tutorials/tinydtls/handshake_captures" "${FINISH_DIR}/conf/in-dtls"

cd "${BUILD_DIR}/tinydtls"
git checkout snapfuzz_asan

make clean
cd tests
make clean
CC="${BUILD_DIR}/aflnet/afl-clang-fast" make all

cp "dtls-server" "${FINISH_DIR}/dtls-server-asan"

#### Build Pthsem ####

git clone https://github.com/linknx/pthsem
cd pthsem

./configure --enable-pthread
make

cp ".libs/libpthread.so.20.0.28" "${FINISH_DIR}/lib2pthread.so"

echo "Build done!"
