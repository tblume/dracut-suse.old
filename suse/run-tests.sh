#!/bin/sh

# set -x
#export testdir directory
export basedir=/usr/lib/dracut/tests
export testdir=$basedir


if [ "$1" == "--help" ]; then
    echo "Running testsuite preparation:"
    echo "Usage: ./run-tests.sh --prepare"
    echo " "
    echo "Running test:"
    echo "Usage: ./run-tests.sh TEST-XX-NAME --\$option"
    echo " "
    echo "Options:"
    echo "--setup              prepare test"
    echo "--run                run test"
    echo "--all                clean, setup, run, clean-again for given test"
    exit 0
fi

[ -d logs ] || mkdir logs

function testsuite_prepare {
    VERSION=$(rpm -q dracut | sed -n 's/dracut-\([[:digit:]]*\).*/\1/p')
    echo "Preparing tests for version $VERSION"
    echo -e "\nChecking required packages"

    case "$VERSION" in
        049)
            ARCH=$(uname -m)
            case $ARCH in
                x86_64|i*86)
                     QEMU_PKG=qemu-x86
                     ;;
                ppc64*)
                     QEMU_PKG="qemu-ppc qemu-vgabios"
                     ;;
                s390x)
                     QEMU_PKG=qemu-s390
                     ;;
                aarch64)
                     QEMU_PKG=qemu-arm
                     ;;
            esac
            progs="screen sudo fping strace lvm2 mdadm cryptsetup plymouth $QEMU_PKG"
            for prog in $progs; do
                rpm -q --quiet $prog || zypper -n in --no-recommends "$prog"
                [[ $? -ne 0 ]] && { echo "error installing required packages"; exit 1; }
            done
	    echo "ok"
	    ;;
        044)
            ;;
        *)
            echo "unknown dracut version: $VERSION"
            exit 1
            ;;
    esac

    return 0
}

function check_test {
    testname=$(basename $(pwd))
    TESTDIR=$(sed -n 's/.*Creating image file [[:graph:]]\(\/[[:graph:]]*\)initramfs.testing.*/\1/p' ../logs/$1-setup.log)
    if [ -f $TESTDIR/result ]; then
        TESTRES=$(sed -n 1p $TESTDIR/result)
    else
	TESTIMG=$(find $TESTDIR -name '*root.[bei]*')
    fi
    if [ "$TESTRES" == 'dracut-root-block-success' ] || $(grep -q 'dracut-root-block-success' $TESTIMG); then
        TESTRES='\033[0;32m'"PASS"
    else
        TESTRES='\033[0;31m'"FAIL"
    fi
    echo -e "$TESTRES:" '\033[m'"$testname\n"
    echo ":test-result: ${TESTRES##*m}" > $basedir/logs/$testname.trs
}

function run_test {
    echo -e "\nRunning test: $1 $2"
    echo -e "============================================================\n"
    cd $1
    if [[ "$2" == "--setup" ]]; then
	./test.sh --cleanup || echo -e "test cleanup failed!\n"
	rm -f ../logs/$1*
        testsuite_prepare
	if [[ -z $3 ]]; then
            screen -D -m -L -Logfile ../logs/$1-setup.log ./test.sh $2 && echo -e "test setup ok\n" || echo -e "test setup failed!\n"
        elif [[ "$3" == "verbose" ]]; then
            screen -L -Logfile ../logs/$1-setup.log ./test.sh $2 && echo -e "test setup ok\n" || echo -e "test setup failed!\n"
        else
            echo "invalid parameter: $3"
	    exit 1
        fi
    elif [[ "$2" == "--run" ]]; then
	if [[ -z $3 ]]; then
            screen -D -m -L -Logfile  ../logs/$1-run.log ./test.sh $2
        elif [[ "$3" == "verbose" ]]; then
            screen -L -Logfile  ../logs/$1-run.log ./test.sh $2
        else
            echo "invalid parameter: $3"
	    exit 1
        fi
        check_test $1
    fi
    cd ..
}

test_options=(--setup --run )

if [ $# -eq 1 ]; then
    if [ "$1" == "--prepare" ]; then
        testsuite_prepare
    elif [ "$1" == "--all" ]; then
        for test in $(echo TEST-1*); do
            for opt in "${test_options[@]}"; do
                run_test $test $opt
            done
        done
    else
        echo "Invalid/missing parameters, see './run-tests.sh --help'"
        exit 1
    fi
else
    if [ $# -eq 2  ]; then
        run_test $1 $2
    elif [ $# -eq 3 ]; then
        run_test $1 $2 $3
    else
        echo "Invalid/missing parameters, see './run-tests.sh --help'"
        exit 1
    fi
fi
