# Synology DSM 7 - Compiling DVB Linux Kernel Modules

I'm writing this since it could be helpful to everyone trying to make common USB DVB work on Synology DSM 7 and above.

Some specs:

- Model: Synology DS720+ 
- Arch: x86_64
- Core Name: Gemini Lake
- OS: DSM 7.2.1-69057 Update 3
- Linux Kernel 4.4.302+
- The USB-DVB device I'm using is a [**Hauppauge WinTV-dualHD**](https://www.hauppauge.com/pages/products/data_dualhd.html), currently available on Amazon for about €70.
  - This device is reported to be supported inside the Linux Kernel from 4.17, but the Synology Kernel is 4.4.302+. So, we'll have to compile the kernel modules ourselves.

This guide will use the `media_build` repo from [**Linuxtv**](https://git.linuxtv.org/media_build.git) to compile the kernel modules. This repo backports patches to use more recent devices in legacy kernels. This repo is EOL, but it should work for a myriad of devices, and there are no other alternatives to my knowledge.


## Acknowledgements
First of all, I want to thank [**@th0ma7**](https://github.com/th0ma7) for the work on [**his Synology repo**](https://github.com/th0ma7/synology). His guide on how to compile kernel modules for Synology NAS (DSM 6) was very helpful for me, and I wanted to port it to DSM 7 since I could not find any guide for it.

Then, I want to thank [**@b-rad-NDi**](https://github.com/b-rad-NDi) for the work on the [**Embedded-MediaDrivers**](https://github.com/b-rad-NDi/Embedded-MediaDrivers) repo.

They both made my life so much easier for compiling and installing the kernel modules with the Synology toolchain. I used their work as a base for this guide.

## Warning
I cannot, and will not, be held responsible for any damage to your Synology. 

Moreover, this guide is provided as-is: I can't guarantee that it will work for other architectures, in fact it's known that **there are** architectures that have problems with compiling the kernel modules.

I'm just sharing what worked for me and my Gemini Lake architecture.

## Prerequisites
- A Synology NAS with DSM 7 installed
- A USB DVB device supported by the Linux Kernel (check [**this list**](https://www.linuxtv.org/wiki/index.php/DVB-T_USB_Devices) for reference)

# Step 1: Prepare the build environment
First of all, we need to prepare the build environment. 
I chose to do everything in a Docker container, to keep my system clean and tidy.

So I spun up an Ubuntu 22.04 container:

```bash
docker run -it --platform linux/amd64 --name dsm7-dvb-build -v <folder>:/export ubuntu:22.04 bash
```
   
   where `<folder>` is the path to your actual system you'll use as a bridge between the container and your system.

Now update and install the required packages:

```bash
apt update
apt install build-essential ncurses-dev bc libssl-dev libc6-i386 curl libproc-processtable-perl git wget kmod
```

Then, create a folder with all the tools needed for the compilation:
   
```bash
mkdir /compile
cd /compile
git clone https://github.com/b-rad-NDi/Embedded-MediaDrivers
```

This will clone the Embedded-MediaDrivers repo, which contains the tool you'll use to compile the kernel modules.

# Step 2: Download the toolchain and the GPL sources
## Synology Toolchain
On DSM 6 you could find the toolchain [**here**](https://sourceforge.net/projects/dsgpl/files/), but on DSM 7 and later they have been moved to: https://archive.synology.com/download/ToolChain.

So you'll have to browse the folders and download the appropriate version for your OS and your architecture. Once downloaded, transfer them to your container and put them in (create the folder, change for your architecture):
```bash
/compile/Embedded-MediaDrivers/dl/SYNO-Geminilake
```
- You can also use wget to download them directly from the container in the right folder.

## GPL Sources
Browse again the [archive.synology.com/download/ToolChain](https://archive.synology.com/download/ToolChain) folder and download the Synology NAS GPL sources for your architecture. Download the `linux-<kernelversion>.tgz` (in my case `linux-4.4.x.txz`) and transfer it to your container, in:
```bash
/compile/Embedded-MediaDrivers/dl/SYNO-Geminilake
```
- The same wget shortcut applies here too.


# Step 3: Configure the tool
## Creating the config file
Enter the folder, and in the `config` subfolder, you'll have to create a file containing the config for your architecture. To create mine, I used the b-rad-NDi one as a base (SYNO-Apollolake.conf) and modified for my Gemini Lake architecture (SYNO-Geminilake.conf). In particular, I did: 

- find and replace everything from Apollo to Gemini (make sure to replace always with the correct case).
- Adjust the TOOLCHAIN_LOCATION var at the top of the file to match the Toolchain file name you've donwloaded before.
- In my case, there KERNEL_LOCATION var was already correct, but you should check it too.
- Adjust the dead Linuxtv media_build repo link (copy mine)

You can find my modified file in this repo, in the `config` folder.


## Creating the board folder

Enter the Embedded-MediaDrivers folder and create a new subfolder in the `board` subfolder (mine is SYNO-Geminilake). This folder contains the board-specific patches for the kernel modules. 

b-rad-NDi already created one for Apollo Lake, so I just copied it and modified it for Gemini Lake. In his repo there are also other boards, so you can use them as a base for your architecture. On x86_64, it should be pretty straightforward to modify the Apollo Lake one for your architecture. For other architectures, you'll have to do some research.

- You can find my modified folder in this repo, in the `board` folder.

## Initializing the tool
I ran:
```bash
./md_builder.sh -i -d SYNO-Geminilake
```
to initialize the tool. This will create a `SYNO-Geminilake` folder in the `build` folder, containing the extracted kernel sources and toolchain.

# Step 4: Build the Synology Linux kernel
## Compile the headers for the downloaded kernel
I ran:
```bash
./md_builder.sh -B media -d SYNO-Geminilake
```
to compile the Synology kernel. This took a bit. If you want to speed up the process, edit the `config` file to leverage make multi-threading.

## Manipulating the media_build repo
in the `build` folder, you'll have now a new folder called `media_build` containing the Linuxtv repo. Go to this folder. Since this repo is EOL and files were deleted, I checked out the last working commit:
```bash
git checkout 0fe857b86addf382f6fd383948bd7736a3201403
```

Then, I opened the file `build` and commented out the lines that made the tool check for the latest version (the one that deletes the files). In particular, lines 504-505:

```bash
	print "****************************\n";
	print "Updating the building system\n";
	print "****************************\n";
	#run("git pull git://linuxtv.org/media_build.git master",
	#    "Can't clone tree from linuxtv.org");

	run("make -C linux/ download", "Download failed");
	run("make -C linux/ untar", "Untar failed");
```

### Extra (Only for Gemini Lake?)
I had to remove a specific patch in the `media_build/backports` folder, since it was causing the compilation to fail. The patch is `v4.11_vb2_kmap.patch`. 

This patch is just wrong for lots of kernels and has been reverted since (but not in this repo). Don't delete the file, just empty it.

# Step 5: Compiling the DVB kernel modules
Now, everything is ready to run the actual compilation:
```bash
./md_builder.sh -B media -d SYNO-Geminilake
```

This will take a while. You can speed up the process by editing the makefiles to leverage make multi-threading, but if you're not familiar with it, I suggest you don't and just wait.

You'll find the compiled kernel modules in the `build/media_build/v4l` folder. You'll need only the `.ko` files. 

# Step 6: Installing the kernel modules
Move the compiled kernel modules to the /export folder, and then to your NAS. 
Create a folder with the result from `uname -r` in the `/lib/modules` folder of your NAS. In my case, it was `/lib/modules/4.4.302+`.

To load them, I used the `hauppauge.sh` script from th0ma7's repo, but you can manually load them using the `insmod` linux command. I modified the script to load the modules I needed, and set up a scheduled task to load them at boot.

These are the modules I insert in the kernel for the dualHD (order is relevant):

1. mc.ko
2. rc-core.ko
3. videobuf-core.ko
4. videodev.ko
5. videobuf2-common.ko
6. videobuf2-v4l2.ko
7. videobuf2-memops.ko
8. videobuf2-vmalloc.ko
9.  dvb-core.ko
10. dvb-usb.ko
11. videobuf2-dvb.ko
12. dvb-pll.ko
13. tveeprom.ko
14. si2168.ko
15. em28xx.ko
16. em28xx-dvb.ko
17. si2157.ko

You'll see that something is wrong (missing modules, wrong module insert order) from the `dmesg` output, saying that it can't insert the module in the kernel due to unknown symbols, like:

```bash
[160210.957968] dvb_usb: Unknown symbol dvb_dmx_swfilter_raw (err 0)
[160210.964838] dvb_usb: Unknown symbol dvb_frontend_detach (err 0)
[160210.971773] dvb_usb: Unknown symbol dvb_net_release (err 0)
[160210.978227] dvb_usb: Unknown symbol dvb_unregister_frontend (err 0)
[160210.985570] dvb_usb: Unknown symbol dvb_register_frontend (err 0)
[160210.992588] dvb_usb: Unknown symbol dvb_create_media_graph (err 0)
[160210.999789] dvb_usb: Unknown symbol dvb_unregister_adapter (err 0)
```

# Step 7: Device firmware loading
In my case, I also needed to load the firmware for my device. In fact, `dmesg` was reporting the following error:
```bash
[164482.334837] si2168 8-0067: Direct firmware load for dvb-demod-si2168-d60-01.fw failed with error -2
[164482.345221] si2168 8-0067: Falling back to user helper
[164482.354917] si2168 6-0064: firmware file 'dvb-demod-si2168-d60-01.fw' not found
[164482.355050] si2168 8-0067: firmware file 'dvb-demod-si2168-d60-01.fw' not found
[164482.377077] si2157 9-0060: found a 'Silicon Labs Si2157-A30 ROM 0x50'
[164482.377134] si2157 10-0063: found a 'Silicon Labs Si2157-A30 ROM 0x50'
[164482.377154] si2157 10-0063: Direct firmware load for dvb_driver_si2157_rom50.fw failed with error -2
[164482.377155] si2157 10-0063: Falling back to user helper
[164482.380751] si2157 10-0063: error -11 when loading firmware
[164482.414631] si2157 9-0060: Direct firmware load for dvb_driver_si2157_rom50.fw failed with error -2
[164482.424993] si2157 9-0060: Falling back to user helper
```

This was due to missing firmware: I downloaded the correct firmwares from the [**CoreELEC repo**](https://github.com/CoreELEC/dvb-firmware/tree/master/firmware) 
and put it in the `/lib/firmware` folder of my NAS.
For my device, I needed the following firmware files:
- dvb-demod-si2168-d60-01.fw
- dvb-tuner-si2157-a30-01.fw (I had to rename it to dvb_driver_si2157_rom50.fw to make it work)



# Step 8: Enjoy!
To me, this "unsupported" device is now working flawlessly. I'm using it with Plex and it's working great. I also used it with TVHeadend and it worked great too.

In this repo's releases, I'm leaving the compiled kernel modules for my architecture and CPU family, in case someone needs them. I'm also leaving the modified files I used to compile them. Feel free to submit a pull request to add other configs and boards, if you successfully compiled the kmods!

From time to time, Synology may update the kernel, so you may have to wait for the sources to become available to update your system, should the kernel version may change. The good thing is that 4.4.302+ is the last 4.4 kernel, and it's EOL, so it should not change anymore. Synology also doesn't update major kernel versions, so you should be safe for a while.

Don't forget to star this repo if you found it useful!
