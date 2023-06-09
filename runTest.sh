#!/bin/bash
# package:		Part of vpl-jail-system
# copyright:    Copyright (C) 20XX Juan Carlos Rodriguez-del-Pino
# license:      GNU/GPL, see LICENSE.txt or http://www.gnu.org/licenses/gpl-3.0.txt
# Description:  Script to run tests for vpl-jail-system

CHECK_MARK="\u2713";
X_MARK="\u274C";
function writeHeading {
	echo -e "\e[33m RUNNING \e[0m \e[34m$1\e[0m"
}
function writeInfo {
	echo -e $3 "\e[33m$1\e[0m$2"
}
function writeError {
	echo -e "\e[31m$1\e[0m$2"
}

function writeCorrect {
	echo -e "\e[32m$1\e[0m$2"
}

function write {
	echo -e "$1"
}

export -f writeHeading
export -f writeInfo
export -f writeError
export -f write

function runTests() {
	local test
	local fmessages=messages.txt
	local ferrors=errors.txt
	local ntests=$#
	local n=1
	local testresult
	if [ $ntests -gt 1 ] ; then
		writeInfo "" "$ntests tests"
	fi
	while [ "$1" != "" ] ; do
		test=$1
		if [ $ntests -gt 1 ] ; then
			writeInfo "Test $n" ": $test " -n
		fi
		{
			"$test"
		} 1>$fmessages 2>$ferrors
		testresult=$?
		if [ "$testresult" != "0" -a "$testresult" != "111" ] ; then
			writeError "Errors found" " $X_MARK"
			writeInfo "Standard error" " max 100 lines"
			head -n 100 $ferrors
			writeInfo "Standard output" " max 100 lines"
			head -n 100 $fmessages
			rm $fmessages 2> /dev/null
			rm $ferrors 2> /dev/null
			exit 1
		else
			writeCorrect "$CHECK_MARK"
			if [ "$testresult" == "111" ] ; then
				echo "$(cat $fmessages)"
			fi
		fi
		((n=n+1))
		shift
	done
	rm $fmessages 2> /dev/null
	rm $ferrors 2> /dev/null
	write
	if [ $ntests -gt 1 ] ; then
		writeCorrect "All tests passed $CHECK_MARK"
	fi
}

function Autotools_execution() {
	aclocal
	autoheader
	autoconf
	automake
	./configure
}

function Packaging_for_distribution() {
	make distcheck
}

function Unit_tests() {
	local result
	cd tests
	make program-test 1>/dev/null
	if test -f program-test ; then
		rm -R cgroup.test 2> /dev/null
		cp -a cgroup cgroup.test
		valgrind ./program-test
		result=$?
		rm -R cgroup.test 2> /dev/null
		rm program-test
		cd ..
		if [ "$result" != "0" ] ; then
			tail /var/log/syslog
			return 1
		else
			return 111
		fi
	fi
	cd ..
	return 1
}

function WebSocket_tests() {
	local result
	local running
	cd tests
	make websocket-echo-test > /dev/null
	if test -f websocket-echo-test ; then
		./websocket-echo-test &
		running=$!
		python3 ./webSocketClient.py
		result=$?
		kill $running
		cd ..
		if [ "$result" != "0" ] ; then
			tail /var/log/syslog
			return 1
		else
			return 111
		fi
	else
		echo "Compilation of websocket-echo-test failed"
	fi
	cd ..
	return 1
}

function create_docs() {
	local result
	rm docs.zip 2> /dev/null
	cd docs
	make clean 1> /dev/null
	make html 1> /dev/null
	result=$?
	cd build
	zip -r ../../docs.zip html 1> /dev/null
	cd ../..
	if [ "$result" != "0" ] ; then
		return 1
	else
		return 111
	fi
}

if [ "$1" != "" ] ; then
	writeHeading "$1 of the vpl-jail-system"
	runTests $1
else
	writeHeading "Tests of the vpl-jail-system"
	runTests Autotools_execution Packaging_for_distribution Unit_tests WebSocket_tests create_docs
fi

