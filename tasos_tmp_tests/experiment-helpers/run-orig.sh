#!/bin/bash

set -eu
trap 'exit 130' INT

DEBUG=0

while getopts "d" opt; do
  case $opt in
  d)
    echo "Debug mode ON"
    DEBUG=1
    ;;
  *)
    echo "Uknown flag!"
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

# AFL_BINS=("./afl-fuzz" "./afl-fuzz-print" "./afl-fuzz-noaffin" "./afl-fuzz-noaffin-print")
AFL_BINS=("./afl-fuzz")

case "$1" in
dicom)
  PROJECT_NAME="dicom"
  AFL_ARGS="-m 512 -i ./conf/in-dicom -N tcp://127.0.0.1/5158 -P DICOM -c ./conf/dicomclean.sh -D 10000 -E -K -R -W 5"
  TARGET_CONF=""
  TARGET_BINS=("./dcmqrscp")
  export DCMDICTPATH="./conf/dicom.dic"
  ;;
dns)
  PROJECT_NAME="dns"
  AFL_ARGS="-m 512 -i ./conf/in-dns -N tcp://127.0.0.1/5353 -P DNS -D 10000 -K -R"
  TARGET_CONF="-C ./conf/dnsmasq-deimos.conf"
  TARGET_BINS=("./dnsmasq")
  ;;
dtls)
  PROJECT_NAME="dtls"
  AFL_ARGS="-m 512 -i ./conf/in-dtls -N udp://127.0.0.1/20220 -P DTLS12 -D 10000 -q 3 -s 3 -E -K -R -W 2"
  TARGET_CONF=""
  TARGET_BINS=("./dtls-server")
  ;;
dtls-orig)
  PROJECT_NAME="dtls-orig"
  AFL_ARGS="-m 512 -i ./conf/in-dtls -N udp://127.0.0.1/20220 -P DTLS12 -D 10000 -q 3 -s 3 -E -K -R -W 30"
  TARGET_CONF=""
  TARGET_BINS=("./dtls-server")
  ;;
ftp)
  PROJECT_NAME="ftp"
  AFL_ARGS="-m 512 -i ./conf/in-ftp -N tcp://127.0.0.1/2200 -x ./conf/ftp.dict -P FTP -D 10000 -q 3 -s 3 -E -R -c ./conf/ftpclean.sh"
  TARGET_CONF="./conf/fftp-deimos.conf 2200"
  # TARGET_BINS=("./fftp" "./fftp-pthreadjoin" "./fftp-deffer" "./fftp-deffer-pthreadjoin")
  TARGET_BINS=("./fftp")
  ;;
rtsp)
  PROJECT_NAME="rtsp"
  AFL_ARGS="-m 512 -i ./conf/in-rtsp -N tcp://127.0.0.1/8554 -x ./conf/rtsp.dict -P RTSP -D 10000 -q 3 -s 3 -E -K -R"
  TARGET_CONF="8554"
  TARGET_BINS=("./testOnDemandRTSPServer")
  ;;
ftp-asan)
  PROJECT_NAME="ftp-asan"
  AFL_ARGS="-m none -i ./conf/in-ftp -N tcp://127.0.0.1/2200 -x ./conf/ftp.dict -P FTP -D 10000 -q 3 -s 3 -E -R -c ./conf/ftpclean.sh"
  TARGET_CONF="./conf/fftp-deimos.conf 2200"
  TARGET_BINS=("./fftp-asan")
  ;;
ftp-tsan)
  PROJECT_NAME="ftp-tsan"
  AFL_ARGS="-m none -i ./conf/in-ftp -N tcp://127.0.0.1/2200 -x ./conf/ftp.dict -P FTP -D 10000 -W 15 -q 3 -s 3 -E -R -c ./conf/ftpclean.sh"
  TARGET_CONF="./conf/fftp-deimos.conf 2200"
  TARGET_BINS=("./fftp-tsan")
  ;;
*)
  echo "Unknown command. Try one of {dicom,dns,dtls,ftp,rtsp}"
  exit 1
  ;;
esac

ALL_BINS=("${AFL_BINS[@]}" "${TARGET_BINS[@]}")
for BIN in "${ALL_BINS[@]}"; do
  if [ ! -f "${BIN}" ]; then
    echo "${BIN} is missing."
    exit 1
  fi
done

if [ "$(find . -maxdepth 1 -name "aflout-${PROJECT_NAME}-*" | wc -l)" -ne 0 ]; then
  echo "Aflout directories alredy exists. (Re)move them to continue."
  exit 1
fi
if [ "$(find . -maxdepth 1 -name "output-${PROJECT_NAME}-*" | wc -l)" -ne 0 ]; then
  echo "Output files alredy exists. (Re)move them to continue."
  exit 1
fi

echo "++++++++++++++++++++++++++++ STATS ++++++++++++++++++++++++++++"
echo "PWD: $(pwd)"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

IT=1
for AFL_BIN in "${AFL_BINS[@]}"; do
  for TARGET_BIN in "${TARGET_BINS[@]}"; do
    for TRY in {0..4}; do
      ALF_RESULT_DIR="aflout-${PROJECT_NAME}-${IT}.${TRY}"
      OUTPUT_FILE="output-${PROJECT_NAME}-${IT}.${TRY}.txt"

      echo "Running ${IT}.${TRY}: ${AFL_BIN} + ${TARGET_BIN}"
      echo "Output: ${OUTPUT_FILE}, ${ALF_RESULT_DIR}"
      CMD="${AFL_BIN} ${AFL_ARGS} -o ./${ALF_RESULT_DIR} ${TARGET_BIN} ${TARGET_CONF} &>./${OUTPUT_FILE}"

      if [ "${DEBUG}" == 1 ]; then
        echo "${CMD}"
        exit 1
      else
        # eval "AFL_BENCH_JUST_ONE=1 ${CMD}"
        eval "${CMD}"
      fi
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    done
    ((IT = IT + 1))
  done
done

TIMENOW=$(date +%Y-%m-%d-%H-%M)
RESULTS_DIR="results-orig-${PROJECT_NAME}-${TIMENOW}"
mkdir "${RESULTS_DIR}"
mv aflout-${PROJECT_NAME}-* output-${PROJECT_NAME}-* "${RESULTS_DIR}"
