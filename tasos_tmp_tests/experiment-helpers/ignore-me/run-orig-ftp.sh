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
    echo "Normal run"
    exit 1
    ;;
  esac
done

AFL_ARGS="-m 512 -i ./conf/in-ftp -N tcp://127.0.0.1/2200 -x ./conf/ftp.dict -P FTP -D 10000 -q 3 -s 3 -E -R -c ./conf/ftpclean.sh"
TARGET_CONF="./conf/fftp-deimos.conf 2200"

AFL_BINS=("./afl-fuzz" "./afl-fuzz-print" "./afl-fuzz-noaffin" "./afl-fuzz-noaffin-print")
# TARGET_BINS=("./fftp" "./fftp-pthreadjoin" "./fftp-deffer" "./fftp-deffer-pthreadjoin")
TARGET_BINS=("./fftp" "./fftp-pthreadjoin")

ALL_BINS=("${AFL_BINS[@]}" "${TARGET_BINS[@]}")
for BIN in "${ALL_BINS[@]}"; do
  if [ ! -f "${BIN}" ]; then
    echo "${BIN} is missing."
    exit 1
  fi
done

if [ "$(find . -maxdepth 1 -name "aflout-*" | wc -l)" -ne 0 ]; then
  echo "Results alredy exists. (Re)move them to continue."
  exit 1
fi
if [ "$(find . -maxdepth 1 -name "output-*" | wc -l)" -ne 0 ]; then
  echo "Results alredy exists. (Re)move them to continue."
  exit 1
fi

echo "++++++++++++++++++++++++++++ STATS ++++++++++++++++++++++++++++"
echo "PWD: $(pwd)"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

IT=1
for AFL_BIN in "${AFL_BINS[@]}"; do
  for TARGET_BIN in "${TARGET_BINS[@]}"; do
    for TRY in {0..1}; do
      ALF_RESULT_DIR="aflout-${IT}.${TRY}"

      echo "Running ${IT}.${TRY}: ${AFL_BIN} + ${TARGET_BIN}"
      echo "Output: ${IT}.${TRY}-output.txt, ${ALF_RESULT_DIR}"
      CMD="${AFL_BIN} ${AFL_ARGS} -o ./${ALF_RESULT_DIR} ${TARGET_BIN} ${TARGET_CONF} &>./output-${IT}.${TRY}.txt"

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
RESULTS_DIR="results-orig-fftp-${TIMENOW}"
mkdir "${RESULTS_DIR}"
mv aflout-* output-* "${RESULTS_DIR}"
