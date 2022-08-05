#!/sbin/sh
# Credit: osm0sis @ xda-developers

# https://github.com/osm0sis/AnyKernel3/blob/3e99a63e924c5720c78d8d428e564661b38de810/META-INF/com/google/android/update-binary


find_slot() {
  local slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  [ "$slot" ] || slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
  if [ ! "$slot" ]; then
    slot=$(getprop ro.boot.slot 2>/dev/null)
    [ "$slot" ] || slot=$(grep -o 'androidboot.slot=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2)
    [ "$slot" ] && slot=_$slot
  fi
  [ "$slot" ] && echo "$slot"
}


setup_mountpoint() {
  [ -L $1 ] && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir -p $1
  fi
}


is_mounted() { mount | grep -q " $1 "; }


mount_apex() {
  [ -d /system_root/system/apex ] || return 1
  local apex dest loop minorx num
  setup_mountpoint /apex
  minorx=1
  [ -e /dev/block/loop1 ] && minorx=$(ls -l /dev/block/loop1 | awk '{ print $6 }')
  num=0
  for apex in /system_root/system/apex/*; do
    dest=/apex/$(basename $apex .apex)
    [ "$dest" = /apex/com.android.runtime.release ] && dest=/apex/com.android.runtime
    mkdir -p $dest
    case $apex in
      *.apex)
        unzip -qo $apex apex_payload.img -d /apex
        mv -f /apex/apex_payload.img $dest.img
        mount -t ext4 -o ro,noatime $dest.img $dest 2>/dev/null
        if [ $? != 0 ]; then
          while [ $num -lt 64 ]; do
            loop=/dev/block/loop$num
            (mknod $loop b 7 $((num * minorx))
            losetup $loop $dest.img) 2>/dev/null
            num=$((num + 1))
            losetup $loop | grep -q $dest.img && break
          done
          mount -t ext4 -o ro,loop,noatime $loop $dest
          if [ $? != 0 ]; then
            losetup -d $loop 2>/dev/null
          fi
        fi
      ;;
      *) mount -o bind $apex $dest;;
    esac
  done
  export ANDROID_RUNTIME_ROOT=/apex/com.android.runtime
  export ANDROID_TZDATA_ROOT=/apex/com.android.tzdata
  export BOOTCLASSPATH=/apex/com.android.runtime/javalib/core-oj.jar:/apex/com.android.runtime/javalib/core-libart.jar:/apex/com.android.runtime/javalib/okhttp.jar:/apex/com.android.runtime/javalib/bouncycastle.jar:/apex/com.android.runtime/javalib/apache-xml.jar:/system/framework/framework.jar:/system/framework/ext.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/ims-common.jar:/system/framework/android.test.base.jar:/system/framework/telephony-ext.jar:/apex/com.android.conscrypt/javalib/conscrypt.jar:/apex/com.android.media/javalib/updatable-media.jar
}


umount_apex() {
  [ -d /apex ] || return 1
  local dest loop
  for dest in $(find /apex -type d -mindepth 1 -maxdepth 1); do
    if [ -f $dest.img ]; then
      loop=$(mount | grep $dest | cut -d" " -f1)
    fi
    (umount -l $dest
    losetup -d $loop) 2>/dev/null
  done
  rm -rf /apex 2>/dev/null
  unset ANDROID_RUNTIME_ROOT ANDROID_TZDATA_ROOT BOOTCLASSPATH
}


mount_all() {
  if ! is_mounted /cache; then
    mount /cache 2>/dev/null && UMOUNT_CACHE=1
  fi
  if ! is_mounted /data; then
    mount /data && UMOUNT_DATA=1
  fi
  (mount -o ro -t auto /vendor
  mount -o ro -t auto /product
  mount -o ro -t auto /persist
  mount -o ro -t auto /system_ext) 2>/dev/null
  setup_mountpoint $ANDROID_ROOT
  if ! is_mounted $ANDROID_ROOT; then
    mount -o ro -t auto $ANDROID_ROOT 2>/dev/null
  fi
  case $ANDROID_ROOT in
    /system_root) setup_mountpoint /system;;
    /system)
      if ! is_mounted /system && ! is_mounted /system_root; then
        setup_mountpoint /system_root
        mount -o ro -t auto /system_root
      elif [ -f /system/system/build.prop ]; then
        setup_mountpoint /system_root
        mount --move /system /system_root
      fi
      if [ $? != 0 ]; then
        (umount /system
        umount -l /system) 2>/dev/null
        if [ -d /dev/block/mapper ]; then
          [ -e /dev/block/mapper/system ] || local slot=$(find_slot)
          mount -o ro -t auto /dev/block/mapper/vendor$slot /vendor
          mount -o ro -t auto /dev/block/mapper/product$slot /product 2>/dev/null
          mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext 2>/dev/null
          mount -o ro -t auto /dev/block/mapper/system$slot /system_root
        else
          [ -e /dev/block/bootdevice/by-name/system ] || local slot=$(find_slot)
          (mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot /vendor
          mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product
          mount -o ro -t auto /dev/block/bootdevice/by-name/persist$slot /persist
          mount -o ro -t auto /dev/block/bootdevice/by-name/system_ext$slot /system_ext) 2>/dev/null
          mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot /system_root
        fi
      fi
    ;;
  esac
  if is_mounted /system_root; then
    mount_apex
    if [ -f /system_root/build.prop ]; then
      mount -o bind /system_root /system
    else
      mount -o bind /system_root/system /system
    fi
  fi
}


umount_all() {
  local mount
  (umount /system
  umount -l /system
  if [ -e /system_root ]; then
    umount /system_root
    umount -l /system_root
  fi
  umount_apex
  for mount in /mnt/system /vendor /mnt/vendor /product /mnt/product /persist /system_ext /mnt/system_ext; do
    umount $mount
    umount -l $mount
  done
  if [ "$UMOUNT_DATA" ]; then
    umount /data
    umount -l /data
  fi
  if [ "$UMOUNT_CACHE" ]; then
    umount /cache
    umount -l /cache
  fi) 2>/dev/null
}


mount_partitions () {
  BOOTMODE=false
  ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
  $BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true

  [ "$ANDROID_ROOT" ] || ANDROID_ROOT=/system

  # emulators can only flash booted and may need /system (on legacy images), or / (on system-as-root images), remounted rw
  if ! $BOOTMODE; then
    mount -o bind /dev/urandom /dev/random
    if [ -L /etc ]; then
      setup_mountpoint /etc
      cp -af /etc_link/* /etc
      sed -i 's; / ; /system_root ;' /etc/fstab
    fi
    umount_all
    mount_all
  fi
  if [ -d /dev/block/mapper ]; then
    for block in system vendor product system_ext; do
      for slot in "" _a _b; do
        blockdev --setrw /dev/block/mapper/$block$slot 2>/dev/null
      done
    done
  fi
  mount -o rw,remount -t auto /system_root
  mount -o rw,remount -t auto /system || mount -o rw,remount -t auto /
  (mount -o rw,remount -t auto /vendor
  mount -o rw,remount -t auto /product
  mount -o rw,remount -t auto /system_ext) 2>/dev/null

  for m in /system_root /system /vendor /product /system_ext /data; do
    if [ ! -w $m ]; then
      abort "$m partitions could not be mounted as rw"
    fi
  done
}