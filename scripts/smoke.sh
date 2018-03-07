#!/bin/tcsh

module load codechecker/6.0.1

setenv SHA1 `git rev-parse HEAD`

git diff --name-status HEAD~1 | xargs echo

setenv MODIFIED_FILES `git diff --name-only HEAD~1 | grep '\.c' | xargs echo`

if ( `echo $MODIFIED_FILES` == "" ) then
    echo "No .c source files have been modified."
    echo "Not running coverity on an empty set."
    exit 0
endif


echo "=======check change======="

./config.opt/$ZEBOS_CONFIG
make

touch -c $MODIFIED_FILES

CodeChecker check -j22 -b "make -j22" -o ./report > report.txt
echo "=======check change done======="

setenv C_NUM `tac report.txt | sed -n 2p |sed -e 's/.*Total number of reports: \(.*\).*/\1/g'`

if ( $C_NUM == 0 ) then
    echo "No coverity issues found in uploaded code, not running coverity for base."
    exit 0
endif

setenv ADDED_FILE `git diff --name-status HEAD~1 |grep "^A" |awk '/^A/{print $2}'`
if ( `echo $ADDED_FILE` != "" ) then
    # if files have been added by the commit, we unfortunately need to rebuild from scratch
    # TODO is there any better way to do this?
    make clean
    rm -f $ADDED_FILE
endif

echo "=======check base======="
git rev-parse HEAD
git checkout HEAD~1
git rev-parse HEAD
make

touch -c $MODIFIED_FILES
CodeChecker check -j22 -b "make -j22" -o ./base > base.txt

echo "=======check base done======="

setenv B_NUM `tac base.txt | sed -n 2p |sed -e 's/.*Total number of reports: \(.*\).*/\1/g'`

echo "Defects from $C_NUM to $B_NUM"

if ( $C_NUM <= $B_NUM ) then
    echo "There are no new defects."
    exit 0
else
    echo "New defects detected, please check \'newdefect.txt\'"
    grep -e "\[HIGH\] " -e "\[MEDIUM\] " -e "\[LOW\] " -e "\[UNSPECIFIED\] " -A 1 base.txt > t1
    grep -e "\[HIGH\] " -e "\[MEDIUM\] " -e "\[LOW\] " -e "\[UNSPECIFIED\] " -A 1 report.txt > t2
    diff t1 t2 > newdefect.txt
    cat newdefect.txt
    exit 1
endif
