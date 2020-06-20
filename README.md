# RedPitaya Operating System


## Prerequisits

In order to build the SD card image for the Red Pitaya Counter, you need a host
computer running Ubuntu 16.04. The easiest way to get one is by running a
virtual machine in VirtualBox.

Install VirtualBox ([https://www.virtualbox.org/]), e.g. on Ubuntu:

```bash
$ sudo apt-get install virtualbox
```

Setup a virtual machine with at least 4GB of ram and 2 CPU cores and install
Ubuntu 16.04. Alternatively, download a ready made virtual machine image from
e.g. [https://www.osboxes.org/ubuntu/].

Start the virtual machine, log in, you are all set.

## Installing FPGA development tools

In order to build the FPGA code, you need the Vivado build tools from Xilinx. In
order to get them, you will need to register with Xilinx and accept their
license agreement. There is a free (as in you don't have to pay anything)
edition of the Vivado HL Suite called WebPack.
*Important: we need the version 2017.2!*

Go download the _Vivado HLx 2017.2: WebPACK and Editions - Linux Self Extracting
Web Installer_ (MD5 SUM Value : eaee62b9dd33d97955dd77694ed1ba20, size: 85.24
MB) from here:
[https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html]
and install it with the command

```bash
chmod +x Xilinx_Vivado_SDK_2017.2_0616_1_Lin64.bin
sudo ./Xilinx_Vivado_SDK_2017.2_0616_1_Lin64.bin
```

*Important: Install Vivado into the default location /opt/Xilinx/*

## Installing other build tools

You will need other tools on your freshly made virtual machine. First of all,
you will need _git_ in order to download this repository. Run:

```bash
sudo apt-get install git
git clone https://github.com/uni-leipzig-sum/RedPitaya.git ~/RedPitaya
sudo apt-get install debootstrap qemu-user-static
```

## Build the Red Pitaya ecosystem

The RedPitaya OS is built in two parts:
- The ecosystem: Contains the linux kernel image, FPGA bitstream, tools, etc.
- The OS userspace: Contains Ubuntu 16.04 userspace with some usefull packages preinstalled
  
You first have to build the ecosystem in order to build the userspace. This will
take quite some time. Simply run the following command:

```bash
cd ~/RedPitaya/build_scripts
sudo ./build_Z10.sh
```

Go take a coffee, as this will take some time. I mean it!

## Building the OS userspace and SD card image

If everything went smoothly, you should now have a file called something like
`ecosystem-XXX.zip` in the ~/RedPitaya directory. It's time to build the SD card
image. Run the following commands:

```bash
cd ~/RedPitaya
sudo OS/debian/image.sh
```

Once the script is done, you should have a file called `redpitaya_OS_XXX.img` in
the ~/RedPitaya directory. This is the SD card image! You are almost done.

The last remaining step consists in burning the image to a physical SD card.
This should be done outside the virtual machine, as accessing the SD card from
within it is a pain. One more thing needs to be done before you can shut down
the virtual machine: you need to transfer the SD image you just created to your
physical host computer. In VirtualBox, this can easily be done using shared
folders.

## Burning the SD card image onto a card

For this step you will need two more things:
- A microSD card with at least 4GB capacity
- A microSD reader/writer

Plug-in the microSD card into the reader. If your operating system recognizes
the SD card and mounts an existing filesystem, unmount it before you proceed.

If the SD card you are using already contains a RedPitaya image, you should
probably make a backup, just in case. Run the following command in order to make
a backup of a preexisting image:
```bash
BACKUP_PATH="~/CHANGE_THIS_TO_SOME_BACKUP_LOCATION/"
mkdir -p $BACKUP_PATH
sudo dd bs=4M if=/dev/mmcblk0 of=$BACKUP_PATH/redpitaya_OS_backup.img
```

Note: Change the path to something more suited to hold a backup ;)

Now you can burn your freshly made image onto the microSD card:
```bash
sudo dd bs=4M if=/PATH/TO/THE/IMAGE/redpitaya_OS_XXX.img of=/dev/mmcblk0
```

After some time (depending on the quality of the SD card), the microSD card is
ready to be used. Insert it into the RedPitaya and off you go.
