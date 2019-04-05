![DELL XPS 9570](https://github.com/gocho1/dell-XPS-9570-conf/raw/master/xps9570.png)<br>

This repo is intented for my own usage and corresponds to my needs.<br>
Please note that is heavily based on things found on internet.<br>

# Ubuntu installation
As I want to keep dual boot possible but also want to encrypt my data, I could not use the Ubuntu installation process feature to encrypt my disk (because it uses all the disk and prevent dual boot)<br><br>

The folling sequence is heavily based on [this tutorial](http://www.cim.mcgill.ca/~anqixu/blog/index.php/2018/06/20/install-18-04-on-encrypted-partitions-xps15-cuda/)<br>

## Windows prerequisite
In order to install Ubuntu, you need to make some room for it.<br>
To do that easily, you can start Windows and launch the disk management tool.<br>
Then select the larger partition (whatever its name is) and righ click to shrink it to the desire size.<br>
No need to format now, it will be done after :)<br>

## Disable Secure boot
Reboot your laptop and press _F12_ when Dell logo appears.<br>
Select _Secure Boot_ and Uncheck _Enable_.<br>
Then _Apply_ and _Exit_<br>

## Boot on Ubuntu USB stick
Non verified information : It maybe required to add _nomodeset_ boot option to achieve the installation (I didn't try without...)<br>
To do that, after Grub loads, move the cursor to _Try Ubuntu_<br>
Then press _e_ to edit the boot options<br>
find the line containing _linux /boot/vmlinuz..._ and add _nomodeset_ right after _splash_<br>
Then press _F10_ to load the kernel<br>


##Create partitions 

 Do not launch the installation now, as you need to create partitions before

```
sudo gparted
```
 - open a terminal (Ctrl+Alt+t)
 - run _$ sudo gparted_
 - delete your existing Ubuntu and other outdated partitions
	I’m assuming that your drive’s partition table uses EFI and not MBR, otherwise you might need to adjust steps below (especially about creating many primary partitions)
 - create a new primary partition with 500MB-1GB size, formatted to _ext4_, and labelled as _boot_; make note of its partition path (e.g. /dev/sda2 or /dev/nvme0n1p3), which I’ll hereby refer to as </dev/DEV_BOOT>
 - create another new primary partition, formatted to _ext4_, and labelled as _rootfs_. I’ll hereby refer its partition path as </dev/DEV_ROOTFS>
 - optionally, you may wish to preserve your home folder or personal data on a separate encrypted partition in case your Linux OS breaks; in this case, create a third new primary partition, formatted to _ext4_, and labelled as home; I’ll hereby refer its partition path as <dev/DEV_HOME>
 - if you wish to create a swap partition, then do so now (and you should probably encrypt it by adapting the steps below or from here)
 - execute the partition changes by clicking on the Checkmark icon, then close GParted once done

My installation looks like <br>
 - /boot : 1 Go
 - / : 65 Go
 - /home : all space left

## Create encrypted volumes using LUKS and LVM
We will now create LUKS containers cryptroot and crypthome on </dev/DEV_ROOTFS>  and</dev/DEV_HOME>, initialize LVM physical volumes lvroot and lvhome, and configure logical volumes vgroot and vghome. Run the following commands in a terminal:
```
    $ sudo cryptsetup luksFormat </dev/DEV_ROOTFS>
    $ sudo cryptsetup luksOpen </dev/DEV_ROOTFS> cryptroot
    $ sudo cryptsetup luksFormat </dev/DEV_HOME>
    $ sudo cryptsetup luksOpen </dev/DEV_HOME> crypthome
```
At this point, if you want to be really secure, overwrite the containers to erase existing content (which will take some time; I didn’t do this):
```
    $ sudo dd if=/dev/zero of=/dev/mapper/cryptroot bs=16M status=progress
    $ sudo dd if=/dev/zero of=/dev/mapper/crypthome bs=16M status=progress
```
Continuing:
```
    $ sudo pvcreate /dev/mapper/cryptroot
    $ sudo vgcreate vgroot /dev/mapper/cryptroot
    $ sudo lvcreate -n lvroot -l 100%FREE vgroot
    $ sudo pvcreate /dev/mapper/crypthome
    $ sudo vgcreate vghome /dev/mapper/crypthome
    $ sudo lvcreate -n lvhome -l 100%FREE vghome
```
After these steps, you will have the following mounted encrypted partitions: /dev/mapper/vgroot-lvroot and /dev/mapper/vghome-lvhome.<br>
NB : Don't worry if you can't see them for now, it's normal as partitions are not mounted yet.<br>
NB2 : if you previously created these encrypted partitions but failed the installer, you only need to run the cryptsetup luksOpen ... commands to remount the existing partitions.<br>

## Go through the Ubuntu installer process

double-clicking the _Install Ubuntu_ icon on the desktop<br>
choose your language, keyboard layout, optionally configure WiFi settings, choose installation options (I chose Normal installation and checked boxes for Download updates ... and Install third-party software ...)<br>
on the _Installation type_ screen, select _Something else_<br><br>

In the next screen, configure the following partitions by double-clicking on their paths:<br><br>

    </dev/DEV_BOOT>: use as ext4, format, mount as /boot<br>
    /dev/mapper/vgroot-lvroot: use as ext4, format, mount as /<br>
    /dev/mapper/vghome-lvhome: use as ext4, format, mount as /home<br>
    if you have a swap partition, use as swap<br>
    then, choose your entire drive as the target device for boot loader installation, e.g. choose /dev/nvme0n1 or /dev/sda, and not partitions like /dev/nvme0n1p6 or /dev/sda3<br><br>

The rest of the installer process should be straight-forward.<br>

DO NOT REBOOT after the installer finishes, and instead click Continue testing.<br>

## Update kernel to load encrypted partitions

First, note down the UUIDs of your encrypted partitions by running the following commands in a terminal (just open a second terminal beside, no need to note them on paper...)
```
    $ sudo blkid </dev/DEV_ROOTFS>
    $ sudo blkid </dev/DEV_HOME>
```
Next, mount the installed OS on /mnt and chroot into it:
```
    $ sudo mount /dev/mapper/vgroot-lvroot /mnt
    $ sudo mount </dev/DEV_BOOT> /mnt/boot
    $ sudo mount /dev/mapper/vghome-lvhome /mnt/home
    $ sudo mount --bind /dev /mnt/dev
    $ sudo chroot /mnt
```
	The following commands are in the chrooted environment, and you are root in it. So _sudo_ is not needed anymore.
```    
    $ > mount -t proc proc /proc
    $ > mount -t sysfs sys /sys
    $ > mount -t devpts devpts /dev/pts
```
Now, create a file named /etc/crypttab in the chrooted environment, e.g.
```
    $ > sudo nano /etc/crypttab
```
and write the following lines, while replacing <UUID_ROOTFS> and <UUID_HOME>:
```
	# <target name> <source device> <key file> <options>
	cryptroot UUID=<UUID_ROOTFS> none luks,discard
	crypthome UUID=<UUID_HOME> none luks,discard
```
Then, recreate the initramfs in the chrooted environment:
```
	$ > update-initramfs -k all -c
```
Finally, reboot out of the Live environment and into your newly installed Ubuntu 18.04 OS!<br>
If everything is fine, it should ask your LUKS passphrase then launch Grub ! <br>

# XPS 9570 customization

## Install some softs for you daily work (at least curl is needed for the next steps)
```
	sudo apt install -y vim curl zsh git fonts-hack-ttf gnome-tweaks libinput-tools libxdo-dev g++
	chsh -s /usr/bin/zsh 
```

## Tweak your system to best suit XPS 9570
In order to do that, I used the excellent [JackHack96 script](https://github.com/JackHack96/dell-xps-9570-ubuntu-respin), with no modifications
```
	sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/JackHack96/dell-xps-9570-ubuntu-respin/master/xps-tweaks.sh)"
```

## Change the grub theme to fit 4k display (if you have one)
This theme has been designed by [arjmacedo](https://github.com/arjmacedo/grub_theme_hidpi)
```
	sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/gocho1/dell-XPS-9570-conf/master/change-grub-theme4k.sh)"
```

## Install a cool font to handle prompt pictos (used for zsh prompts)
```
	wget -O /tmp/Hack.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/Hack.zip
	mkdir -p ~/.fonts && unzip /tmp/Hack.zip -d ~/.fonts && rm -f /tmp/Hack.zip
	fc-cache -fv
```
You may restart your station in order to get everything work

## Customize Terminal appearance
Custom font : Hack Regular size 12<br>
Uncheck "Use system theme"<br>
Use "Dark Solarized" theme<br>
Use "Tango" colors<br>
Check "Display bold text with light colors"<br>

## Download dotfiles
These files are based on [tonylambiris](https://github.com/tonylambiris/dotfiles) and slightly customized
```
	wget -O ~/.inputrc https://raw.githubusercontent.com/gocho1/dotfiles/master/dot.inputrc 
	wget -O ~/.zshrc https://raw.githubusercontent.com/gocho1/dotfiles/master/dot.zshrc
```
Then you can start zsh
```
	zsh
```
Zsh will prompt you to install some plugins.

## Add experimental feature of gnome to get different scale for multiple monitors setup
This way, you can use an external monitor properly with no DPI side effects.<br>
Please note that you need to change the rendering server to _Ubuntu with Wayland_ on the login screen (click on the wheel next to _Login_ button
Also note that this feature is experimental and may be discontinued in further releases
```
	gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
```

## Add swipe gestures to change workspaces
This part is based on [Hikari9 comfortable-swipe](https://github.com/Hikari9/comfortable-swipe)
```
	
	
```

# Optional

## Install docker if you need it
```
	sudo apt remove docker docker-engine docker.io containerd runc
	curl -fsSL https://get.docker.com/ | sh
```
As displayed at the end of the previous script, you can add your user in docker group if you want to use docker without sudoing all the time<br>
Warning : Please note that this action will grant the ability to run containers which can be used to obtain root privileges on the docker host.
```
	sudo groupadd docker
	sudo usermod -aG docker $USER
	sudo systemctl restart docker
```


## Minikube (https://github.com/kubernetes/minikube#other-ways-to-install)

### Install KVM2 driver
To install the KVM2 driver, first install and configure the prereqs:
```
	sudo apt install libvirt-clients libvirt-daemon-system qemu-kvm
```
Enable,start, and verify the libvirtd service has started.
```
	sudo systemctl enable libvirtd.service
	sudo systemctl start libvirtd.service
	sudo systemctl status libvirtd.service
```
Then you will need to add yourself to libvirt group (older distributions may use libvirtd instead)
```
	sudo usermod -a -G libvirt $(whoami)	
```
Then to join the group with your current user session:
```
	newgrp libvirt
```
Now install the driver:
```
	curl -LO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2 && sudo install docker-machine-driver-kvm2 /usr/local/bin/
```
Get minikube binary
```
	curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube
```
Here’s an easy way to add the Minikube executable to your path:
```
	sudo cp minikube /usr/local/bin && rm minikube
```
Then you can configure minikube to use kvm2 driver as default
```
	minikube config set vm-driver kvm2
```
And start minikube 
```
	minikube start
```






