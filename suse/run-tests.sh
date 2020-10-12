#!/bin/sh

#set -x

if [ "$1" == "--help" ]; then
    echo "Running testsuite preparation:"
    echo "Usage: ./run-tests.sh --prepare"
    echo " "
    echo "Running test:"
    echo "Usage: ./run-tests.sh TEST-XX-NAME --\$option"
    echo " "
    echo "Options:"
    echo "--clean              cleanup before test"
    echo "--setup              prepare test"
    echo "--run                run test"
    echo "--clean-again        cleanup after test"
    echo "--all                clean, setup, run, clean-again for given test"
    exit 0
fi

[ -d logs ] || mkdir logs

function testsuite_prepare {
    VERSION=$(rpm -q dracut | sed -n 's/dracut-\([[:digit:]]*\).*/\1/p')
    echo "Preparing tests for version $VERSION"
    echo -e "\nChecking required packages\n"

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
            progs="sudo fping strace $QEMU_PKG"
            for prog in $progs; do
                rpm -q $prog || zypper -n in --no-recommends "$prog"
                [[ $? -ne 0 ]] && { echo "error installing required packages"; exit 1; }
            done
	    ;;
        044)
            ;;
        *)
            echo "unknown dracut version: $VERSION"
            exit 1
            ;;
    esac

    #export testdir directory
    export basedir=/usr/lib/dracut/tests
    export testdir=$basedir
}

function check_test {
    testname=$(basename $(pwd))
    TESTRES=$(grep 'made it to the rootfs!' $basedir/logs/$testname-run.log)
    if [[ "$TESTRES" =~ 'made it to the rootfs!' ]]; then
        TESTRES='\033[0;32m'"PASS"
    else
        TESTRES='\033[0;31m'"FAIL"
    fi
    echo -e "\n$TESTRES:" '\033[m'"$testname"
    echo ":test-result: ${TESTRES##*m}" > $basedir/logs/$testname.trs
}

function run_test {
    echo -e "\nRunning test: $1 $2"
    echo -e "============================================================\n"
    cd $1
    if [[ "$2" == "--setup" ]]; then
        testsuite_prepare
        ./test.sh $2 | &>../logs/$1-setup.log
        [[ $? == 0 ]] && echo -e "\nsetup of test-initrd succeeded" || echo -e "\nfailure setting up test-initrd!" 
    elif [[ "$2" == "--run" ]]; then
        ./test.sh $2 &>../logs/$1-run.log
        check_test
    fi
    cd ..
}

test_options=(--setup --run )

if [[ $1 =~ "--prepare" ]]; then
    testsuite_prepare
elif [[ -z "$2" && "$1" == "--all" ]]; then
    for opt in "${test_options[@]}"; do
        run_test $1 $opt
    done
elif [[ -n "$1" && -n "$2" ]]; then
    run_test $1 $2
else
    echo "Invalid/missing parameters, see './run-tests.sh --help'"
    exit 1
fi
