#!/bin/bash

set -eu
trap 'exit 130' INT

echo "Test case folder: ${1}"
NFOUND=$(find "${1}/id"* | wc -l)
echo "Cases found: ${NFOUND}"
echo "Port: ${2}"
echo "Iterations ${3}"

for i in $(seq 1 "${3}"); do
	for TESTCASE in "${1}/id"*; do
		./sabre ./libsbr-id.so -- ./fftp-deffer-sbr ./conf/fftp-deimos.conf "${2}" >/dev/null &
		BG_PID=$!
		disown

		./builds/aflnet/aflnet-replay "${TESTCASE}" FTP "${2}" &>/dev/null

		kill ${BG_PID} &>/dev/null || true
		# rm fftplog
	done
	echo "Iteration: ${i}"
done
