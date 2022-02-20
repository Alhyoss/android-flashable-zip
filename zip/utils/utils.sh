

#!/sbin/sh
# Shell Script EDIFY Replacement: Recovery Flashable Zip
# osm0sis @ xda-developers


# https://forum.xda-developers.com/t/dev-template-complete-shell-script-flashable-zip-replacement-signing-script.2934449/#post-56621519


# ui_print "<message>" ["<message 2>" ...]
ui_print() {
  while [ "$1" ]; do
    echo -e "ui_print $1
      ui_print" >> $OUTFD;
    shift;
  done;
}


# show_progress <amount> <time>
show_progress() { echo "progress $1 $2" >> $OUTFD; }


# set_progress <amount>
set_progress() { echo "set_progress $1" >> $OUTFD; }


# sleep <seconds> exists in shell


# is_substring <substring> <string>
is_substring() { case "$2" in *$1*) echo 1;; *) echo 0;; esac; }


# less_than_int <x> <y>
less_than_int() { if [ $1 -lt $2 ]; then echo 1; else echo 0; fi; }


# greater_than_int <x> <y>
greater_than_int() { if [ $1 -gt $2 ]; then echo 1; else echo 0; fi; }


# format(fs_type, partition_type, device, fs_size, mountpoint) {} is unneeded since specific format/wipe commands may be run directly


# mount <partition> exists in shell
# unmount <partition>
# unmount() { umount "$1"; }
# is_mounted <partition>
# is_mounted() { if [ "$(mount | grep " $1 ")" ]; then echo 1; else echo 0; fi; }
# tune2fs(device[, arg, …]) {} should be done directly with the tune2fs command

# write_raw_image <file> <block>
write_raw_image() { dd if="$1" of="$2"; }


# write_firmware_image() {} is a manufacturer command to apply further OEM update zips with hboot/uboot functions, so can't be duplicated
# wipe_block_device(block_dev, len) {} should be done directly with dd or flash_erase
# wipe_cache() {} should be done directly with format or rm -rf

# package_extract_file <file> <destination_file>
package_extract_file() { mkdir -p "$(dirname "$2")"; unzip -o "$ZIPFILE" "$1" -p > "$2"; }


# package_extract_dir <dir> <destination_dir>
package_extract_dir() {
  local entry outfile;
  for entry in $(unzip -l "$ZIPFILE" 2>/dev/null | tail -n+4 | grep -v '/$' | grep -o " $1.*$" | cut -c2-); do
    outfile="$(echo "$entry" | sed "s|${1}|${2}|")";
    mkdir -p "$(dirname "$outfile")";
    unzip -o "$ZIPFILE" "$entry" -p > "$outfile";
  done;
}


# rename <file> <destination_file>
rename() { mv -f "$1" "$2"; }


# delete <file> [<file2> ...]
delete() { rm -f "$@"; }


# delete_recursive <dir> [<dir2> ...]
delete_recursive() { rm -rf "$@"; }


# symlink <file/dir> <link> [<link2> ...]
symlink() {
  local file="$1";
  while [ "$2" ]; do
    ln -sf "$file" "$2";
    shift;
  done;
}


# set_metadata <file> <uid|gid|mode|capabilities|selabel> <value> [<uid|gid|mode|capabilities|selabel_2> <value2> ...]
set_metadata() {
  local file i;
  file="$1";
  shift;
  while [ "$2" ]; do
    case $1 in
      uid) chown $2 "$file";;
      gid) chown :$2 "$file";;
      mode) chmod $2 "$file";;
      capabilities) twrp setcap "$file" $2;;
      selabel)
        for i in /system/bin/toybox /system/toolbox /system/bin/toolbox; do
          (LD_LIBRARY_PATH=/system/lib $i chcon -h $2 "$file" || LD_LIBRARY_PATH=/system/lib $i chcon $2 "$file") 2>/dev/null;
        done || chcon -h $2 "$file" || chcon $2 "$file";
      ;;
      *) ;;
    esac;
    shift 2;
  done;
}


# set_metadata_recursive <dir> <uid|gid|dmode|fmode|capabilities|selabel> <value> [<uid|gid|dmode|fmode|capabilities|selabel_2> <value2> ...]
set_metadata_recursive() {
  local dir i;
  dir="$1";
  shift;
  while [ "$2" ]; do
    case $1 in
      uid) chown -R $2 "$dir";;
      gid) chown -R :$2 "$dir";;
      dmode) find "$dir" -type d -exec chmod $2 {} +;;
      fmode) find "$dir" -type f -exec chmod $2 {} +;;
      capabilities) find "$dir" -exec twrp setcap {} $2 +;;
      selabel)
        for i in /system/bin/toybox /system/toolbox /system/bin/toolbox; do
          (find "$dir" -exec LD_LIBRARY_PATH=/system/lib $i chcon -h $2 {} + || find "$dir" -exec LD_LIBRARY_PATH=/system/lib $i chcon $2 {} +) 2>/dev/null;
        done || find "$dir" -exec chcon -h $2 '{}' + || find "$dir" -exec chcon $2 '{}' +;
      ;;
      *) ;;
    esac;
    shift 2;
  done;
}


# set_perm <owner> <group> <mode> <file> [<file2> ...]
set_perm() {
  local uid gid mod;
  uid=$1; gid=$2; mod=$3;
  shift 3;
  chown $uid:$gid "$@" || chown $uid.$gid "$@";
  chmod $mod "$@";
}


# set_perm_recursive <owner> <group> <dir_mode> <file_mode> <dir> [<dir2> ...]
set_perm_recursive() {
  local uid gid dmod fmod;
  uid=$1; gid=$2; dmod=$3; fmod=$4;
  shift 4;
  while [ "$1" ]; do
    chown -R $uid:$gid "$1" || chown -R $uid.$gid "$1";
    find "$1" -type d -exec chmod $dmod {} +;
    find "$1" -type f -exec chmod $fmod {} +;
    shift;
  done;
}


# ch_con <context> <file> [<file2> ...]
ch_con() {
  local con i;
  con=$1;
  shift;
  for i in /system/bin/toybox /system/toolbox /system/bin/toolbox; do
    (LD_LIBRARY_PATH=/system/lib $i chcon -h u:object_r:$con:s0 "$@" || LD_LIBRARY_PATH=/system/lib $i chcon u:object_r:$con:s0 "$@") 2>/dev/null;
  done || chcon -h u:object_r:$con:s0 "$@" || chcon u:object_r:$con:s0 "$@";
}


# ch_con_recursive <dir_context> <file_context> <dir> [<dir2> ...]
ch_con_recursive() {
  local dcon fcon i;
  dcon=$1; fcon=$2;
  shift 2;
  while [ "$1" ]; do
    for i in /system/bin/toybox /system/toolbox /system/bin/toolbox; do
      (find "$1" -type d -exec LD_LIBRARY_PATH=/system/lib $i chcon -h u:object_r:$dcon:s0 {} + || find "$1" -type d -exec LD_LIBRARY_PATH=/system/lib $i chcon u:object_r:$dcon:s0 {} +;
      find "$1" -type f -exec LD_LIBRARY_PATH=/system/lib $i chcon -h u:object_r:$fcon:s0 {} + || find "$1" -type f -exec LD_LIBRARY_PATH=/system/lib $i chcon u:object_r:$fcon:s0 {} +) 2>/dev/null;
    done || ( find "$1" -type d -exec chcon -h u:object_r:$dcon:s0 '{}' + || find "$1" -type d -exec chcon u:object_r:$dcon:s0 '{}' + ) || ( find "$1" -type f -exec chcon -h u:object_r:$fcon:s0 '{}' + || find "$1" -type f -exec chcon u:object_r:$fcon:s0 '{}' + );
    shift;
  done;
}


# restore_con <file/dir> [<file2/dir2> ...]
restore_con() {
  local i;
  for i in /system/bin/toybox /system/toolbox /system/bin/toolbox; do
    (LD_LIBRARY_PATH=/system/lib $i restorecon -R "$@") 2>/dev/null;
  done || restorecon -R "$@";
}


# read_file(filename) {} is unneeded since file contents can be read directly with the cat command
# concat(expr[, expr, ...]) {} is unneeded since string operations can be done directly
# stdout(expr[, expr, ...]) {} is unneeded since all output goes to stdout by default


# file_getprop <file> <property>
file_getprop() { grep "^$2=" "$1" | cut -d= -f2-; }


# getprop <property>
getprop() { if [ -e /sbin/getprop ]; then /sbin/getprop $1; else grep "^$1=" /default.prop | cut -d= -f2-; fi; }


# sha1_check <file> [<sha1_hex> [<sha1_hex2> ...]]
sha1_check() {
  local sum=$(sha1sum $1 | cut -c-40);
  if [ ! "$2" -o $(is_substring $sum "$*") == 1 ]; then
    echo $sum;
  fi;
}


# apply_patch <src_file> <tgt_file> <tgt_sha1> <tgt_size> [<src_sha1_1>:<patch1> [<src_sha1_2>:<patch2> ...]]
apply_patch() { LD_LIBRARY_PATH=/system/lib applypatch "$@"; }


# apply_patch_check <file> [<sha1_hex> [<sha1_hex2> ...]]
apply_patch_check() { LD_LIBRARY_PATH=/system/lib applypatch -c "$@"; }


# apply_patch_space <bytes>
apply_patch_space() { LD_LIBRARY_PATH=/system/lib applypatch -s $1; }


# run_program(program) {} is unneeded since programs may be run directly


# abort [<message>]
abort() { ui_print "$*"; exit 1; }


# assert "<command>" ["<command2>"]
assert() {
  while [ "$1" ]; do
    $1;
    test $? != 0 && abort 'assert failed('"$1"')';
    shift;
  done;
}


# backup_files <file> [<file2> ...]
backup_files() {
  while [ "$1" ]; do
    test ! -e "$1.bak" && cp -pf "$1" "$1.bak";
    shift;
  done;
}


# restore_files <file> [<file2> ...]
restore_files() {
  while [ "$1" ]; do
    mv -f "${1}.bak" "$1";
    shift;
  done;
}

