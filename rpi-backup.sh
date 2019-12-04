#!/bin/sh

if [  $# != 2 ]; then
  echo "argument error: Usage: $0 boot_device_name root_device_name"
  echo "example: $0 /dev/mmcblk0p1 /dev/mmcblk0p2"
  exit 0
fi
dev_boot=$1
dev_root=$2
mounted_boot=`df -h | grep $dev_boot | awk '{print $6}'`
mounted_root=`df -h | grep $dev_root | awk '{print $6}'`
img=rpi-`date +%Y%m%d-%H%M`.img

#install tools
sudo apt-get install dosfstools dump parted kpartx

echo =====================   part 1, prepare workspace    ===============================
mkdir ~/backupimg
cd ~/backupimg

echo ===================== part 2, create a new blank img ===============================
# New img file
#sudo rm $img

bootsz=`df -P | grep $dev_boot | awk '{print $2}'`
rootsz=`df -P | grep $dev_root | awk '{print $3}'`
totalsz=`echo $bootsz $rootsz | awk '{print int(($1+$2)*1.3/1024)}'`
sudo dd if=/dev/zero of=$img bs=1M count=$totalsz
#sync
echo "...created a blank img, size ${totalsz}M "

# format virtual disk
bootstart=`sudo fdisk -l | grep $dev_boot | awk '{print $2}'`
bootend=`sudo fdisk -l | grep $dev_boot | awk '{print $3}'`
rootstart=`sudo fdisk -l | grep $dev_root | awk '{print $2}'`
echo "boot: $bootstart >>> $bootend, root: $rootstart >>> end"
#有些系统 sudo fdisk -l 时boot分区的boot标记会标记为*,此时bootstart和bootend最后应改为 $3 和 $4
#rootend=`sudo fdisk -l /dev/mmcblk0 | grep mmcblk0p2 | awk '{print $3}'`

sudo parted $img --script -- mklabel msdos
sudo parted $img --script -- mkpart primary fat32 ${bootstart}s ${bootend}s
sudo parted $img --script -- mkpart primary ext4 ${rootstart}s -1

echo =====================  part 3, mount img to system  ===============================
loopdevice=`sudo losetup -f --show $img`
device=/dev/mapper/`sudo kpartx -va $loopdevice | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
sleep 5
sudo mkfs.vfat ${device}p1 -n boot
sudo mkfs.ext4 ${device}p2 -L rootfs
#在backupimg文件夹下新建两个文件夹，将两个分区挂载在下面
mkdir tgt_boot tgt_Root
#这里没有使用id命令来查看uid和gid，而是假设uid和gid都和当前用户名相同
uid=`whoami`
gid=$uid
sudo mount -t vfat -o uid=${uid},gid=${gid},umask=0000 ${device}p1 ./tgt_boot/
sudo mount -t ext4 ${device}p2 ./tgt_Root/


echo ===================== part 4, backup /boot =========================
sudo cp -rfp ${mounted_boot}/* ./tgt_boot/
sync
echo "...Boot partition done"

echo ===================== part 5, backup / =========================
sudo chmod 777 ./tgt_Root
sudo chown ${uid}.${gid} tgt_Root
sudo rm -rf ./tgt_Root/*
cd tgt_Root/
# start backup
sudo dump -0uaf - ${mounted_root}/ | sudo restore -rf -
sync 
echo "...Root partition done"
cd ..

echo ===================== part 6, replace PARTUUID =========================

# replace PARTUUID
opartuuidb=`sudo blkid -o export $dev_boot | grep PARTUUID`
opartuuidr=`sudo blkid -o export $dev_root | grep PARTUUID`
npartuuidb=`sudo blkid -o export ${device}p1 | grep PARTUUID`
npartuuidr=`sudo blkid -o export ${device}p2 | grep PARTUUID`
sudo sed -i "s/$opartuuidr/$npartuuidr/g" ./tgt_boot/cmdline.txt
sudo sed -i "s/$opartuuidb/$npartuuidb/g" ./tgt_Root/etc/fstab
sudo sed -i "s/$opartuuidr/$npartuuidr/g" ./tgt_Root/etc/fstab
echo "...replace PARTUUID done"

echo "remove auto generated files"
#下面内容是删除树莓派中系统自动产生的文件、临时文件等
cd ~/backupimg/tgt_Root
sudo rm -rf ./.gvfs ./dev/* ./media/* ./mnt/* ./proc/* ./run/* ./sys/* ./tmp/* ./lost+found/ ./restoresymtable
cd ..

echo ===================== part 7, unmount =========================
sudo umount tgt_boot tgt_Root
sudo kpartx -d $loopdevice
sudo losetup -d $loopdevice
rmdir tgt_boot tgt_Root


echo "==== All done. img file is under ~/backupimg/ "
