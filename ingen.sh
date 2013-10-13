#!/bin/env bash 

if [[ $1 != *-env* ]]
   then
   
       #Create the new partions, boot partition, swap partition, and root partion.
       echo -e 'n\np\n1\n\n+32M\na\n1\nn\np\n2\n\n+512M\nt\n2\n82\nn\np\n3\n\n\n\nw\nq' | fdisk /dev/sda
       #Create the file systems and activate them. 
       mkfs.ext2 /dev/sda1 
       mkfs.ext4 /dev/sda3
       mkswap /dev/sda2
       swapon /dev/sda2

       #Mount the root partion and the boot partiton.
       mount /dev/sda3 /mnt/gentoo 
       mkdir /mnt/gentoo/boot
       mount /dev/sda1 /mnt/gentoo/boot

       #Download the stage3 tarbal and unpack it.
       cd /mnt/gentoo && wget 'http://192.168.1.30:8000/stage3-i686-20130827.tar.bz2' 
       cd /mnt/gentoo && tar xvjpf stage3-i686-20130827.tar.bz2
       cd /mnt/gentoo && rm stage3-i686-20130827.tar.bz2
       echo MAKEOPTS='"'-j3'"' >> /etc/portage/make.conf #Set the number of parallel compilations that should occur.

       #Copy DNS info for the new environment.
       cp -L /etc/resolv.conf /mnt/gentoo/etc/

       #Mount the necessary filesystems.
       mount -t proc none /mnt/gentoo/proc
       mount --rbind /sys /mnt/gentoo/sys
       mount --rbind /var /mnt/gentoo/var
       cp /root/ingen.sh /mnt/gentoo/home/
       chroot /mnt/gentoo /bin/bash -c "su - -c 'bash /home/ingen.sh -env'"
       
   fi

if [[ $1 == *-env* ]] 
   then 
       source /etc/profile 
       export PS1="(chroot) $PS1" 
       emerge-webrsync
       #Install a portage snapshot and update it.
       emerge --sync

       #Handiling portage news.
       eselect new list
       eselect news read

       #Select a profile.
       eselect profile set 1

       #Set the timezone.
       cp /usr/share/zoneinfo/Australia/Canberra /etc/localtime
       echo "Austrlia/Canberra" >> /etc/timezone

       #Choose a kernel and ccmpile it, this is assuming you already have a preconfigured kernel.
       emerge gentoo-sources
       cd /usr/src/linux && make && make modules_install
       cp arch/x86/boot/bzImage /boot/kernel-3.8.13-gentoo

       #Set the kernel modules that should load automatically.
       OIFS=$IFS                   
       IFS='/'                     
       find /lib/modules/3.8.13-gentoo/ -type f -iname '*.o' -or -iname '*.ko' | less | while read line; 
       do 
        for itter in $line;
        do
           if [[ $itter == *.ko* ]]
           then
               echo modules_3_8='"'$itter'"' | sed -r 's/[.ko]+//g' >> /etc/conf.d/modules
                   
           fi
        done      
       done
       IFS=$OIFS

       #Set the partions that should mount automatically.
       echo /dev/sda1   /boot        ext2    defaults,noatime     0 2 >> /etc/fstab
       echo /dev/sda2   none         swap    sw                   0 0 >> /etc/fstab
       echo /dev/sda3   /            ext4    noatime              0 1 >> /etc/fstab
       echo /dev/cdrom  /mnt/cdrom   auto    noauto,user          0 0 >> /etc/fstab

       #Automatically start networking at boot. 
       cd /etc/init.d && ln -s net.lo.net.wlan0
       rc-update add net.wlan0 default

       #Set up network information.
       echo 127.0.0.1	localhost >> /etc/hosts
       echo 127.0.1.1	emmanuel-HP-Pavilion-dv6-Notebook-PC >> /etc/hosts       
       echo "# The following lines are desirable for IPv6 capable hosts" >> /etc/hosts
       echo ::1     ip6-localhost ip6-loopback >> /etc/hosts
       echo fe00::0 ip6-localnet >> /etc/hosts
       echo ff00::0 ip6-mcastprefix >> /etc/hosts
       echo ff02::1 ip6-allnodes >> /etc/hosts
       echo ff02::2 ip6-allrouters >> /etc/hosts

       #Set up charactor formats.
       echo en_US ISO-8859-1 >> /etc/locale.gen
       echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
       echo de_DE ISO-8859-1 >> /etc/locale.gen
       echo de_DE@euro ISO-8859-15 >> /etc/locale.gen
       local-gen
       echo LANG='"'de_DE.UTF-8'"' >> /etc/env.d/02locale
       echo LC_COLLATE='"'C'"' >> /etc/env.d/02locale

       #Reload the environment.
       env-update && source /etc/profile

       #Install a system logger.
       emerge syslog-ng
       rc-update add syslog-ng default

       #Install a cron daemon. 
       emerge vixie-cron
       rc-update add vixie-cron default

       #Install a dhcp client.
       emerge dhcpcd

       #Set up grub and install it.
       emerge sys-boot/grub:0
       echo "# Which listing to boot as default. 0 is the first, 1 the second etc." >> /boot/grub/grub.conf
       echo default 0 >> /boot/grub/grub.conf
       echo "# How many seconds to wait before the default listing is booted." >> /boot/grub/grub.conf
       echo timeout 30 >> /boot/grub/grub.conf
       echo "# Nice, fat splash-image to spice things up :)" >> /boot/grub/grub.conf
       echo "# Comment out if you don't have a graphics card installed" | tee /boot/grub/grub.conf
       echo "splashimage=(hd0,0)/boot/grub/splash.xpm.gz" >> /boot/grub/grub.conf

       echo title Gentoo Linux 3.3.8 >> /boot/grub/grub.conf
       echo "# Partition where the kernel image (or operating system) is located" >> /boot/grub/grub.conf
       echo "root (hd0,0)" >> /boot/grub/grub.conf
       echo kernel /boot/kernel-3.3.8-gentoo root=/dev/sda3 >> /boot/grub/grub.conf

       echo "title Gentoo Linux 3.3.8 (rescue)" >> /boot/grub/grub.conf
       echo "# Partition where the kernel image (or operating system) is located" >> /boot/grub/grub.conf
       echo "root (hd0,0)" >> /boot/grub/grub.conf
       echo kernel /boot/kernel-3.3.8-gentoo root=/dev/sda3 init=/bin/bb >> /boot/grub/grub.conf
       grep -v roofs /proc/mounts > /etc/mtab
       echo "(hd0)  /dev/vda" >> /boot/grub/device.map
       grub-install --no-floppy /dev/sda

       #Exit the environment, and unmount everything.
       exit 
       cd
       umount -l /mnt/gentoo/dev{/shm,/pts,}
       umount -l /mnt/gentoo{/boot,/proc,}
       echo Gentoo has been installed.
       echo You can restart the system now.
       
   fi    
