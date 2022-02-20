#!/bin/bash

usage() { 
    echo "Usage: $0 [OPTION...]" 1>&2; 
    echo " " 1>&2; 
    echo "Valid options: " 1>&2; 
    echo "    -h            Print this help." 1>&2; 
    echo "    -o ZIPFILE    Name of the flashable zip file. Default value is update.zip." 1>&2; 
    echo "    -d DIRECTORY  Directory to include in the zip file. Default value is zip." 1>&2; 
    echo "    -s            Sideload the flashable zip to the connected Android device." 1>&2; 
    exit 1; 
}

error(){
    echo "Error: $*" >>/dev/stderr;
    exit 1;
}

ZIPFILE="update.zip"
DIR="zip"
SIDELOAD=false

while getopts ":h:o:d:s" o; do
    case "${o}" in
        o)
            ZIPFILE=${OPTARG}
            ;;
        d)
            DIR=${OPTARG}
            ;;
        s)
            SIDELOAD=true
            ;;
        *)
            usage
            ;;
    esac
done

[ ! -d $DIR ] && error "$DIR directory does not exist."


echo "Building $ZIPFILE..."

current_dir=$(pwd)
cd $DIR

if [ "${ZIPFILE:0:1}" = "/" ]; then
    zip -r $ZIPFILE . 1>/dev/null 2>/dev/null
else
    zip -r $current_dir/$ZIPFILE . 1>/dev/null 2>/dev/null
fi

[ $? -ne 0 ] && error "Could not build $ZIPFILE, exiting..."

cd $current_dir

echo "Done."



[ $SIDELOAD = false ] && exit 0


ADB_PATH=$(which adb)

[ ! -f $ADB_PATH ] && error "Could not find adb."

IS_SIDELOAD=$($ADB_PATH devices 2>/dev/null | awk 'NR>1 {print $2}')

[ "$IS_SIDELOAD" != "sideload" ] && error "Cannot find sideload device."

echo "Sideloading..."

$ADB_PATH sideload $ZIPFILE 

exit 0