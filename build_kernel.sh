#/bin/bash

KERNEL_BUILD_DIR=kernel
DEF_CONFIG=goldennfc_defconfig
INITRDDIR=ramdisk-contents

while true
do
  case $# in 0) break ;; esac
    case "$1" in
	    clean|Clean)
		    echo "********************************************************************************"
		    echo "* Clean Kernel                                                                 *"
		    echo "********************************************************************************"

		    pushd $KERNEL_BUILD_DIR
		    make clean
		    popd
		    echo " It's done... "
		    exit
		    ;;
	    nobuildzimage)
		    nobuildzimage=true
		    shift
		    ;;
	    dontstoponkernelmakeerror)
		    dontstoponkernelmakeerror=true
		    shift
		    ;;
	    standardconfig)
		    standardconfig=true
		    shift
		    ;;
	    nocopymodules)
		    nocopymodules=true
		    shift
		    ;;
	    nobuildinitrdimg)
		    nobuildinitrdimg=true
		    shift
		    ;;
	    nobuildbootimg)
		    nobuildbootimg=true
		    shift
		    ;;
	    tar)
		    build_tar=true
		    shift
		    ;;
	    updatezip|updatezip/)
		    build_updatezip=true
		    shift
		    ;;
	    flashkernel)
		    flash_kernel=true
		    shift
		    ;;
	    *) break ;;
    esac
done

if [ "$CPU_JOB_NUM" = "" ] ; then
	CPU_JOB_NUM=8
fi

export PRJROOT=$PWD
export PROJECT_NAME
export HW_BOARD_REV

echo "************************************************************"
echo "* EXPORT VARIABLE		                            	 *"
echo "************************************************************"
echo "PRJROOT=$PRJROOT"
echo "************************************************************"

BUILD_KERNEL()
{
	echo "************************************************************"
	echo "*        BUILD                                             *"
	echo "************************************************************"
	echo

	pushd $KERNEL_BUILD_DIR

	export KDIR=`pwd`
	
	if  [ "$standardconfig" = "true" ]; then
	    make $DEF_CONFIG
	fi
	
	if  [ ! "$nobuildzimage" = "true" ]; then
	    # make kernel with codesourcery:
	    # make -j$CPU_JOB_NUM HOSTCFLAGS="-g -O2" CROSS_COMPILE=$TOOLCHAIN/$TOOLCHAIN_PREFIX
	    # make kernel with gnu gcc:
	    export LOCALVERSION="-790526"
	    export KBUILD_BUILD_USER="bln-kernel"
	    export KBUILD_BUILD_HOST="neldar"
	    export KBUILD_BUILD_VERSION="2"
	    make -j$CPU_JOB_NUM
	    kernelmakeerror=$?
	fi

	popd

	if [ ! $kernelmakeerror = 0 -a ! "$dontstoponkernelmakeerror" = "true" ]; then
	    echo "Stopped by kernel make error"
	    exit
	fi

	if  [ ! "$nocopymodules" = "true" ]; then
		cp ./$KERNEL_BUILD_DIR/drivers/interceptor/vpnclient.ko $INITRDDIR/lib/modules/
		cp ./$KERNEL_BUILD_DIR/drivers/scsi/scsi_wait_scan.ko $INITRDDIR/lib/modules/
		cp ./$KERNEL_BUILD_DIR/drivers/net/wireless/bcmdhd/dhd.ko $INITRDDIR/lib/modules/
		cp ./$KERNEL_BUILD_DIR/drivers/char/hw_random/rng-core.ko $INITRDDIR/lib/modules/
		cp ./$KERNEL_BUILD_DIR/drivers/char/hwreg/hwreg.ko $INITRDDIR/lib/modules/
		cp ./$KERNEL_BUILD_DIR/drivers/bluetooth/bthid/bthid.ko $INITRDDIR/lib/modules/
	fi

	if  [ ! "$nobuildinitrdimg" = "true" ]; then
		pushd $INITRDDIR
		find . | cpio -o -H newc | gzip > ../tmp/initrd.img
		popd
	fi

	if  [ ! "$nobuildbootimg" = "true" ]; then
		./bin/mkbootimg.Linux.x86_64 --cmdline "" --base 0x00000000 --kernel $KERNEL_BUILD_DIR/arch/arm/boot/zImage --ramdisk ./tmp/initrd.img -o ./out/boot.img
	fi
	
	if [ "$build_tar" = "true" ]; then
	    tar -cf ./bootimg.tar boot.img
	fi
	
	if [ "$build_updatezip" = "true" ]; then
	    pushd updatezip	  
	    cp ../out/boot.img ./
	    echo "make update.zip"
	    rm ../out/cwm-update.zip > /dev/null
	    zip -r ../out/cwm-update.zip META-INF/ system/ boot.img
	    java -jar \
	    ../bin/signapk.jar \
	    ../bin/testkey.x509.pem \
	    ../bin/testkey.pk8 \
	    ../out/cwm-update.zip ../out/cwm-update-signed.zip
	    popd
	fi
	
	if [ "$flash_kernel" = "true" ]; then
	    flashkernel.sh
	fi
}

# print title
PRINT_USAGE()
{
	echo "************************************************************"
	echo "* PLEASE TRY AGAIN                                         *"
	echo "************************************************************"
	echo
}

PRINT_TITLE()
{
	i=1
	echo
	echo "************************************************************"
	echo "*                     MAKE PACKAGES"
	echo "************************************************************"
if  [ "$standardconfig" = "true" ]; then
	    echo "* $i. generate : standardconfig"
	    i=$(($i+1))
fi

if  [ ! "$nobuildzimage" = "true" ]; then
	    echo "* $i. build : zImage"
	    i=$(($i+1))
fi

if  [ ! "$nocopymodules" = "true" ]; then
	    echo "* $i. initrd : copy modules"
	    i=$(($i+1))
fi

if  [ ! "$nobuildinitrdimg" = "true" ]; then
	    echo "* $i. build : initrd.img"
	    i=$(($i+1))
fi

if  [ ! "$nobuildbootimg" = "true" ]; then
	    echo "* $i. build : boot.img"
	    i=$(($i+1))
fi

if [ "$build_tar" = "true" ]; then
	echo "* $i. build : tar"
	i=$(($i+1))
fi

if [ "$build_updatezip" = "true" ]; then
	echo "* $i. build : update.zip"
	i=$(($i+1))
fi

if [ "$flash_kernel" = "true" ]; then
	echo "* $i. flash boot.img"
	i=$(($i+1))
fi
	echo "************************************************************"
}

##############################################################
#                   MAIN FUNCTION                            #
##############################################################
if [ $# -gt 4 ]
then
	echo
	echo "**************************************************************"
	echo "*  Option Error                                              *"
	PRINT_USAGE
	exit 1
fi

START_TIME=`date +%s`

PRINT_TITLE

BUILD_KERNEL
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo "Total compile time is $ELAPSED_TIME seconds"

