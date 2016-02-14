#!/usr/bin/env bash

# stop the script if a single command fails
set -e

# define an echo that only outputs to stderr
echoerr() { echo "$@" 1>&2; }
#  try to use curl if possible
if [[ `which curl 2> /dev/null` ]]; then
	DOWNLOAD="curl --silent --location --compressed ";
	DOWNLOAD_TO="$DOWNLOAD --output ";
elif [[ `which wget 2> /dev/null` ]]; then
	DOWNLOAD_TO="wget --quiet --output-document=";
	DOWNLOAD="$DOWNLOAD_TO-";
else
	echo "Please install curl or wget on your machine";
	exit 1
fi




# ARGUMENT HANDLING =============================================================
if { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
	echo "This script downloads the stable Pharo VM for 50.
The following artifacts are created:
    pharo      Script to run the downloaded VM in headless mode
    pharo-ui   Script to run the downloaded VM in UI mode
    pharo-vm/  Directory containing the VM
"
	exit 0;
elif [ $# -gt 0 ]; then
	echo "--help is the only argument allowed"
	exit 1;
fi


# RELEASE VERSION ===============================================================
VERSION="50-preSpur"
FILES_URL="http://files.pharo.org/get-files/${VERSION}"


# VM PROPERTIES =================================================================
VM_TYPE="pharo"
VM_BINARY_NAME="Pharo"
VM_BINARY_NAME_LINUX="pharo"
VM_STATUS="stable"


# DETECT SYSTEM PROPERTIES ======================================================
TMP_OS=`uname | tr "[:upper:]" "[:lower:]"`
if [[ "{$TMP_OS}" = *darwin* ]]; then
    OS="mac";
elif [[ "{$TMP_OS}" = *linux* ]]; then
    OS="linux";
elif [[ "{$TMP_OS}" = *win* ]]; then
    OS="win";
elif [[ "{$TMP_OS}" = *mingw* ]]; then
    OS="win";
else
    echo "Unsupported OS";
    exit 1;
fi

if [ -z "$ARCHITECTURE" ] ; then
    ARCHITECTURE=32;
fi


# DOWNLOAD PHARO FOR 50 VM ======================================================
VM_URL="${FILES_URL}/${VM_TYPE}-${OS}-${VM_STATUS}.zip"
VM_DIR="pharo-vm"

echoerr "Downloading the latest ${VM_TYPE}VM:"
echoerr "	$VM_URL"

mkdir $VM_DIR
$DOWNLOAD_TO$VM_DIR/vm.zip $VM_URL

unzip -q $VM_DIR/vm.zip -d $VM_DIR
rm -rf $VM_DIR/vm.zip

if [ "$OS" == "win" ]; then
    PHARO_VM=`find $VM_DIR -name ${VM_BINARY_NAME}.exe`
elif [ "$OS" == "mac" ]; then
    PHARO_VM=`find $VM_DIR -name ${VM_BINARY_NAME}`
elif [ "$OS" == "linux" ]; then
    PHARO_VM=`find $VM_DIR -name ${VM_BINARY_NAME_LINUX}`
fi

echo $PHARO_VM


# DOWNLOAD THE PHARO ARCHIVED SOURCES FILE ======================================
if [ "$OS" = "mac" ]; then
	SOURCES_DIR=$VM_DIR;
else
	SOURCES_DIR=`dirname $PHARO_VM`;
fi

echoerr "Downloading PharoV${VERSION}.sources:"
echoerr "	$FILES_URL/sources.zip"
$DOWNLOAD_TO$VM_DIR/sources.zip $FILES_URL/sources.zip
unzip -q $VM_DIR/sources.zip -d $SOURCES_DIR
rm -rf $VM_DIR/sources.zip


# CREATE THE VM LAUNCHER SCRIPTS ================================================
create_vm_script() {
	VM_SCRIPT=$1

	echo "#!/usr/bin/env bash" > $VM_SCRIPT
	echo '# some magic to find out the real location of this script dealing with symlinks
DIR=`readlink "$0"` || DIR="$0";
DIR=`dirname "$DIR"`;
cd "$DIR"
DIR=`pwd`
cd - > /dev/null
# disable parameter expansion to forward all arguments unprocessed to the VM
set -f
# run the VM and pass along all arguments as is' >> $VM_SCRIPT

	# make sure we only substite $PHARO_VM but put "$DIR" in the script
	echo -n \"\$DIR\"/\"$PHARO_VM\" >> $VM_SCRIPT

	# only output the headless option if the VM_SCRIPT name does not include "ui"
	if [[ "{$VM_SCRIPT}" != *ui* ]]; then
		# output the headless option, which varies under each platform
		if [ "$OS" == "linux" ]; then
		    echo -n " --nodisplay " >> $VM_SCRIPT
		else
		    echo -n " --headless" >> $VM_SCRIPT
		fi
	fi

	# forward all arguments unprocessed using $@
	echo " \"\$@\"" >> $VM_SCRIPT

	# make the script executable
	chmod +x $VM_SCRIPT
}

echoerr "Creating starter scripts pharo and pharo-ui"
create_vm_script "pharo"
create_vm_script "pharo-ui"


# TEST VM REQUIREMENTS UNDER LINUX ==============================================
if [ "$OS" == "linux" ]; then
	$PHARO_VM --help --vm-display-null &> /dev/null 2>&1 || (\
		echo "On a 64-bit system? You must install the 32-bit libraries"; \
		echo '   Try `sudo aptitude install ia32-libs` or see http://pharo.org/gnu-linux-installation#64-bit-System-Setup for more info' )
fi
