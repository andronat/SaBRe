#!/usr/bin/env bash

set -eu
trap 'exit 130' INT

checks() {
  local -n _all_bins="${1}"

  for bin in "${_all_bins[@]}"; do
    if [ ! -f "${bin}" ]; then
      echo "${bin} is missing."
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

}

stats() {
  echo "++++++++++++++++++++++++++++ STATS ++++++++++++++++++++++++++++"
  echo "PWD: $(pwd)"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

engine() {
  declare -n _afl_bins="${1}"
  declare afl_args="${2}"

  declare -n _ftp_bins="${3}"
  declare ftp_conf="${4}"

  declare i=1

  for afl_bin in "${_afl_bins[@]}"; do
    for ftp_bin in "${_ftp_bins[@]}"; do
      for try in {0..1}; do
        afl_result_dir="aflout-${i}.${try}"

        echo "Running ${i}.${try}: ${afl_bin} + ${ftp_bin}"
        echo "Output: ${i}.${try}-output.txt, ${afl_result_dir}"
        # eval "${afl_bin} ${afl_args} -o ./${afl_result_dir} ${ftp_bin} ${ftp_conf} &>./output-${i}.${try}.txt"
        echo "${afl_bin} ${afl_args} -o ./${afl_result_dir} ${ftp_bin} ${ftp_conf} &>./output-${i}.${try}.txt"
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
      done
      ((i = i + 1))
    done
  done
}

run-orig() {
  declare afl_args="-m 512 -d -i ./conf/in-ftp -N tcp://127.0.0.1/2200 -x ./conf/ftp.dict -P FTP -D 10000 -q 3 -s 3 -E -R -c ./conf/ftpclean.sh"
  declare ftp_conf="./conf/fftp-deimos.conf 2200"

  declare -a afl_bins=("./afl-fuzz-orig" "./afl-fuzz-orig-print" "./afl-fuzz-orig-noaffin" "./afl-fuzz-orig-noaffin-print")
  declare -a ftp_bins=("./fftp" "./fftp-pthreadjoin" "./fftp-deffer" "./fftp-deffer-pthreadjoin")

  declare -a all_bins=("${afl_bins[@]}" "${ftp_bins[@]}")

  checks all_bins
  stats
  engine afl_bins "${afl_args}" ftp_bins "${ftp_conf}"
}

run-sbr() {
  declare afl_args="-A -m 512 -d -i ./conf/in-ftp -N tcp://127.0.0.1/2200 -x ./conf/ftp.dict -P FTP -q 3 -s 3 -E -R"
  declare ftp_conf="./conf/fftp-deimos.conf 2200"

  declare -a afl_bins=("./afl-fuzz-sbr" "./afl-fuzz-sbr-print" "./afl-fuzz-sbr-noaffin" "./afl-fuzz-sbr-noaffin-print")
  declare -a ftp_bins=("./fftp" "./fftp-pthreadjoin" "./fftp-deffer-sbr" "./fftp-deffer-sbr-pthreadjoin")
  # declare -a sbr_bins=("sabre" "libsbr-afl" "libsbr-afl-nosleeps.so" "libsbr-afl-nosleeps-nofs.so")
  declare -a sbr_bins=("sabre" "libsbr-afl.so")

  declare -a all_bins=("${afl_bins[@]}" "${ftp_bins[@]}" "${sbr_bins[@]}")

  checks all_bins
  stats
  engine afl_bins "${afl_args}" ftp_bins "${ftp_conf}"
}

help_wanted() {
  [ "$#" -ne "1" ] || [ "$1" = '-h' ] || [ "$1" = '--help' ] || [ "$1" = "-?" ]
}

usage() {
  cat <<EOF

Accepted arguments: [orig || sbr]

Usage:
     -h|--help                  Displays this help
EOF
}

if help_wanted "$@"; then
  usage
  exit 1
fi

if [ "$1" = 'orig' ]; then
  run-orig
elif [ "$1" = 'sbr' ]; then
  run-sbr
else
  usage
  exit 1
fi
