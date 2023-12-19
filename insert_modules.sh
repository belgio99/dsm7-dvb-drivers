#!/bin/sh

#-------------------------------------------
# insert_modules.sh
#
# by: belgio99
#
# Loads the Kernel Modules required to make
# USB-DVB devices work. Change the MODULES variable
# according to the modules you need to load.
#-------------------------------------------

MODULE_PATH=/usr/local/lib/modules/$(uname -r)
MODULES="mc rc-core videobuf-core videodev videobuf2-common videobuf2-v4l2 videobuf2-memops videobuf2-vmalloc dvb-core dvb-usb videobuf2-dvb dvb-pll tveeprom si2168 em28xx em28xx-dvb si2157"

for module in $MODULES; do
    # Add ".ko" to get the module file name
    module_file=$(echo "${module}.ko")
    # Convert hyphens to underscores for the loaded module name
    module_loaded=$(echo "${module}" | sed 's/-/_/g')

    # Check if the module is already loaded
    # Note: Using grep -E for extended regex to match exact module name
    if lsmod | grep -E "^${module_loaded} "> /dev/null; then
        printf '\t%-30s' "${module_file}"
        echo "Loaded"
    else
        # Attempt to load the module
        printf '\t%-30s' "${module_file}"
        if insmod "${MODULE_PATH}/${module_file}"; then
            echo "OK"
        else
            echo "ERROR"
        fi
    fi
done

