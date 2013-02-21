#/bin/bash

while true
do
  case $# in 0) break ;; esac
    case "$1" in
	    recovery)
		    recovery_flash=true
		    shift
		    ;;
	    *) break ;;
    esac
done

adb push ./out/boot.img /sdcard/boot.img

if  [ "$recovery_flash" = "true" ]; then
	adb shell dd if=/sdcard/boot.img of=/dev/block/mmcblk0p20
else
	adb shell su -c dd if=/sdcard/boot.img of=/dev/block/mmcblk0p20
fi

adb reboot
