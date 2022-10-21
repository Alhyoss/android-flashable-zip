# Android flashable zip

Boilerplate code for a flashable zip file that can be sideloaded to an Android device to make modifications to the system. 

The `zip` directory is the directory that is to be zipped and sideloaded to the device.

The `flashable.sh` script is a shell script that will create the zip file and sideload it to your device.


## REMARK

Sideloading the zip file to modify your Android device requires the bootloader to be unlocked. 
You may also need to flash/boot a custom recovery (such as TWRP).

Be aware that unlocking the bootloader of your device and modifying the system entails risks. Your device may no longer function properly, and some applications may refuse to run.


## Requirements

* No DM-verity
* Custom recovery (e.g. TWRP)


## Usage

Modify the `zip/update.sh` file to include the modifications you want to make to your Android device. 
Helper functions are available to use. See `zip/utils/utils.sh` for the list of helper functions.

You can also add additional files (scripts, binaries, ...) and extract them from the zip file using unzip or the helper functions.

The following partitions should be accessible in read-write:
* `/system_root` (Root of the Android filesystem)
* `/system`
* `/system_ext`
* `/vendor`
* `/product`
* `/data`

You therefore do not need to bother with mounting the partitions before modifying them. 
If for some reason the partitions cannot be mounted on your device, you will need to fix the issue in the `zip/utils/mount_utils.sh` file.


Once the update script has been modified, you can use the provided `flashable.sh` script to build the zip file and sideload it if you want:

```
Usage: ./flashable.sh [OPTION...]
 
Valid options: 
    -h            Print this help.
    -o ZIPFILE    Name of the flashable zip file. Default value is update.zip.
    -d DIRECTORY  Directory to include in the zip file. Default value is zip.
    -s            Sideload the flashable zip to the connected Android device.
```

Examples:
```
$ ./flashable.sh

$ ./flashable.sh -o update.zip -d ./dir -s
```

## Files
```
android-flashable-zip
├── zip
│   ├── META-INF/com/google/android
│   │   ├── update-binary                 <---- First file to be executed. Prepares the installation, mounts the partitions and runs update.sh
│   │   └── updater-script                <---- Required dummy file
│   │
│   ├── utils
│   │   ├── arm64-v8a/sepolicy-inject     <---- arm64 binary of sepolicy-inject
│   │   ├── arm64-v7a/sepolicy-inject     <---- arm32 binary of sepolicy-inject
│   │   ├── x86_64/sepolicy-inject        <---- x86_64 binary of sepolicy-inject
│   │   ├── x86/sepolicy-inject           <---- x86 binary of sepolicy-inject
│   │   ├── utils.sh                      <---- Contains helper functions
│   │   └── mount_utils.sh                <---- Contains all functions related to mounting the partitions
│   │
│   ├── update.sh                         <---- Put your code in this file
|   └── ...                               <---- You can add any additional file
│ 
└── flashable.zip                         <---- Helper script to build the zip file and sideload it to the device
 
```

