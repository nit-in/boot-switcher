#! /sbin/sh
# A script to switch boot targets between Android and Sailfish OS.
# https://git.io/fjSLY

# >>> TWRP init >>>

OUTFD="" # e.g. "/proc/self/fd/28"

# Temporary: Find TWRP screen output FD for logging to it from here
for FD in `ls /proc/$$/fd`; do
	readlink /proc/$$/fd/$FD 2>/dev/null | grep pipe >/dev/null
	if [ "$?" -eq "0" ]; then
		ps | grep " 3 $FD " | grep -v grep >/dev/null
		if [ "$?" -eq "0" ]; then
			OUTFD="/proc/self/fd/$FD"
			break
		fi
	fi
done

# Print some text ($1) on the screen
ui_print() {
	[ -z "$1" ] && echo -e "ui_print  \nui_print" > $OUTFD || echo -e "ui_print $@\nui_print" > $OUTFD
}

# Before quitting with an exit code ($1), show a message ($2)
abort() {
	ui_print "E$1: $2"
	exit $1
}

# <<< TWRP init <<<

# >>> Custom functions >>>

# Log some text ($1) for script debugging
log() {
	echo "switch-boot-target: $@"
}

# <<< Custom functions <<<

# Constants & variables
LOS_VER=""
TARGET_LOS_VER="15.1"
INIT_PERF="/vendor/etc/init/hw/init.target.performance.rc"
ROOT="/data/.stowaways/sailfishos"

# >>> Sanity checks >>>

# Treble
if [ ! -r /dev/block/bootdevice/by-name/vendor ]; then
	abort 1 "A vendor partition doesn't exist; you need to do an OTA from OxygenOS 5.1.5 to 5.1.6!"
fi

# Android
umount /vendor &> /dev/null
mount -o rw /vendor || abort 2 "Couldn't mount /vendor!"
umount /system &> /dev/null
mount /system || abort 3 "Couldn't mount /system!"
LOS_VER=`cat /system/build.prop | grep lineage.build.version= | cut -d'=' -f2` # e.g. "16.0"
[[ "$LOS_VER" = "$TARGET_LOS_VER" && -f $INIT_PERF ]] || abort 4 "Please factory reset & dirty flash LineageOS $TARGET_LOS_VER before this zip."
log "Android OS installation detected"

# Sailfish OS
umount /data &> /dev/null
mount /data || abort 5 "Couldn't mount /data; running e2fsck and rebooting may help."
[[ -f $ROOT/etc/os-release && -f $ROOT/boot/droid-boot.img ]] || abort 6 "Please install Sailfish OS before flashing this zip."

log "Sailfish OS installation detected"
log "Passed sanity checks (2/2)"

# <<< Sanity checks <<<

# >>> Script >>>

# Boot target to switch to
TARGET="droid"
TARGET_DROID_LOS=1
TARGET_PRETTY=""
TARGET_FILE="$ROOT/boot/droid_target"

if [ -f $TARGET_FILE ]; then # Sailfish OS
	rm $TARGET_FILE

	TARGET="hybris"
	SFOS_REL=`cat $ROOT/etc/os-release | grep VERSION= | cut -d'=' -f2 | cut -d'"' -f2` # e.g. "3.1.0.12 (Seitseminen)"
	TARGET_PRETTY="Sailfish OS $SFOS_REL" # e.g. "Sailfish OS 3.1.0.12 (Seitseminen)"
else                           # LineageOS
	touch "$TARGET_FILE"

	DROID_VER=`cat /system/build.prop | grep ro.build.version.release | cut -d'=' -f2` # e.g. "9"
	DROID_VER_MAJOR="$DROID_VER" # e.g. "9"
	DROID_VER_MINOR="0"
	if [[ "$DROID_VER" = *"."* ]]; then # e.g. "8.1.0"
		DROID_VER_MAJOR=`echo $DROID_VER | cut -d'.' -f1` # e.g. "8"
		DROID_VER_MINOR=`echo $DROID_VER | cut -d'.' -f2` # e.g. "1"
	fi
	DROID_REL="" # e.g. "Pie"

	if [ "$DROID_VER_MAJOR" = "9" ]; then
		DROID_REL="Pie"
	elif [ "$DROID_VER_MAJOR" = "8" ]; then
		DROID_REL="Oreo"
	elif [ "$DROID_VER_MAJOR" = "7" ]; then
		DROID_REL="Nougat"
	elif [ "$DROID_VER_MAJOR" = "6" ]; then
		DROID_REL="Marshmallow"
	elif [ "$DROID_VER_MAJOR" = "5" ]; then
		DROID_REL="Lollipop"
	elif [ "$DROID_VER_MAJOR" = "4" ]; then
		if [ "$DROID_VER_MINOR" = "4" ]; then
			DROID_REL="KitKat"
		elif [ "$DROID_VER_MINOR" = "0" ]; then
			DROID_REL="ICS"
		else
			DROID_REL="Jelly Bean"
		fi
	fi

	[ ! -z $DROID_REL ] && DROID_REL=" ($DROID_REL)" # e.g. " (Pie)"
	TARGET_PRETTY="Android $DROID_VER$DROID_REL" # e.g. "Android 7.1.1 (Nougat)"
	[ ! -z $LOS_VER ] && TARGET_PRETTY="LineageOS $LOS_VER$DROID_REL" || TARGET_DROID_LOS=0 # e.g. "LineageOS 16.0 (Pie)"
fi

# Calculate centering offset indent on left
offset=`echo -n $TARGET_PRETTY | wc -m` # Character length of the version string
offset=`expr 52 - 13 - $offset`         # Remove constant string chars from offset calculation
offset=`expr $start / 2`                # Get left offset char count instead of space on both sides

# Build the left side indentation offset string
for i in `seq 1 $offset`; do indent="${indent} "; done

# Splash
ui_print " "
ui_print "-=============- Boot Target Switcher -=============-"
ui_print " "
if [ "$TARGET" = "hybris" ]; then
	ui_print "                          .':oOl."
	ui_print "                       ':c::;ol."
	ui_print "                    .:do,   ,l."
	ui_print "                  .;k0l.   .ll.             .."
	ui_print "                 'ldkc   .,cdoc:'.    ..,;:::;"
	ui_print "                ,o,;o'.;::;'.  'coxxolc:;'."
	ui_print "               'o, 'ddc,.    .;::::,."
	ui_print "               cl   ,x:  .;:c:,."
	ui_print "               ;l.   .:ldoc,."
	ui_print "               .:c.    .:ll,"
	ui_print "                 'c;.    .;l:"
	ui_print "                   :xc.    ,o'"
	ui_print "                   'xxc.   ;o."
	ui_print "                   :l'c: ,lo,"
	ui_print "                  ,o'.ooclc'"
	ui_print "                .:l,,x0o;."
	ui_print "              .;llcldl,"
	ui_print "           .,oOOoc:'"
	ui_print "       .,:lddo:'."
	ui_print "      oxxo;."
else
	if [ "$TARGET_DROID_LOS" = "1" ]; then
		ui_print " "
		ui_print " "
		ui_print " "
		ui_print " "
		ui_print "                         __"
		ui_print "                      :clllcc:"
		ui_print "                   :okOOOOOOOOko:"
		ui_print "                 :o0K:   __   :00o:"
		ui_print "                :dK0l :lxxxxo: l0Kd:"
		ui_print "        _       c0Ko :xNMMMMNx: oK0c       _"
		ui_print "     lxOOOkoldxk0N0l c0WMMMMM0c l0N0kxdlokOOOxl"
		ui_print "    oK0dodOXX0kddOXx: lOKXXKOl :xX0dxk0XXOdod0Ko"
		ui_print "   :kXx   lK0l   cOKkl:      :lkKOc   c0Ko   xXk:"
		ui_print "    l0Kkxx0Kd:    :dO0OkxddxkO0Od:    :dK0xxkK0l"
		ui_print "     coxkkdl        :ldxkkkkxdl:        ldkkxoc"
		ui_print " "
		ui_print " "
		ui_print " "
		ui_print " "
		ui_print " "
	else
		ui_print "                  .od.        .do."
		ui_print "                   'kOolllllloOk'"
		ui_print "                 .cdl:'.    .':ldc."
		ui_print "                ;xl''          ''lx;"
		ui_print "               ;k:   ::      ::   :k;"
		ui_print "              .xx..................xx."
		ui_print "              .okddddddddddddddddddko."
		ui_print "         .loo:,dxolllllllllllllllloxo,:ool."
		ui_print "         ox.:kxkl                  lkxk:.xo"
		ui_print "         dd.  xkc                  ckx  .dd"
		ui_print "         od.  xkc                  ckx  .do"
		ui_print "         od.  xkc                  ckx  .do"
		ui_print "         od.  xkc                  ckx  .do"
		ui_print "         ckc,kokc                  ckok,ckc"
		ui_print "          ,c:.'kl                  lk'.:c,"
		ui_print "               :dlcc.  .cccc.  .ccld:"
		ui_print "                .'cOo  oOooOo  oOc'."
		ui_print "                  .xo  ox,,xo  ox."
		ui_print "                  .dx''xo..ox''xd."
		ui_print "                   ,k00k,  ,k00k,"
	fi
fi
ui_print " "
ui_print "${indent}Switching to $TARGET_PRETTY"
ui_print "                   Please wait ..."

log "New boot target: '$TARGET_PRETTY'"

# Start
log "Patching /vendor init files..."
if [ $TARGET = "droid" ]; then
	cp $INIT_PERF.bak $INIT_PERF || abort 7 "Failed to restore init files in /vendor."
else
	sed -e "s/cpus 0/cpuset.cpus 0/g" -e "s/mems 0/cpuset.mems 0/g" -i $INIT_PERF || abort 7 "Failed to patch init files in /vendor."
fi

log "Writing new boot image..."
dd if=$ROOT/boot/$TARGET-boot.img of=/dev/block/bootdevice/by-name/boot || abort 8 "Writing new boot image failed."

log "Cleaning up..."
umount /vendor &> /dev/null
umount /system &> /dev/null

# <<< Script <<<

# Succeeded.
log "Boot target updated successfully."
ui_print "            All done, enjoy your new OS!"
ui_print " "
exit 0