# Qnap TS-h973AX - NAS server from scratch

[[__TOC__]]

## Board

### Specification

The QNAP TS-h973AX is a 9-bay NAS server in a compact tower design specification:

- CPU - AMD Ryzen™ Embedded V1500B 2.2 GHz 2 (8 treads)
- RAM - max 64GB DDR4 SO-DIMM
- Drive Bays - 9 bays
  - 5 x 3.5" SATA 6 Gb/s
  - 4 x 2.5" SATA 6 Gb/s/U.2 NVMe PCIe Gen 3 x4
  - 1x USB-DOM 4G internal contain `QuTS hero` OS
- Network - 3 ports
  - 1x 10GBase
  - 2x 2.5GBase
- USB
  - 1x UCB-C 3.2 Gen 2 10Gb/s
  - 2x USB-A 3.2 Gen 2 back
  - 1x USB-A 3.2 Gen 2 front

### UART

The Qnap TS-h973AX doesn't have a video card, but it is adapted to display BIOS, POST, and BOOT log information on the `UART`. Connect your UART dongle according with this picture.

UART parameters:

- baudrate -> 115200
- databits -> 8
- stopbits -> 1
- parity -> none
- flowcontrol -> none

!!! PICTURE HERE

You can use any UART terminal, I use `picocom`

```bash
picocom -b 115200 -f n /dev/ttyUSB0
```

!!! WARNING !!!

During POST, BIOS and for `QuTS hero`, the UART works stably without any issues, but with other distributions it works unstable and quickly hangs when another OS starts to boot.

I've spent many hours trying to understand why the `UART` works stably on `QuTS hero - Linux version 5.10.60-qnap` but very unstable on the newer official `Linux 6.X.` kernels. I've tried various distributions, even `TrueNAS`. The result is always the same: the UART freezes.

From my research, IRQ 4 seems to be acting unstable, losing interrupts. I also suspect that some registers are not set correctly by the SuperI/O processor, because calling ACPI `UAR1` -> asking about current settings causes it to unfreeze for a few seconds.

### BIOS

When your `UART` is already working, pressing `DEL` during POST information, you can entry to the BIOS

```bash
Version 2.20.1274. Copyright (C) 2021 American Megatrends, Inc.                 
BIOS Date: 07/21/2021 18:24:22 Ver: Q071AR10                                    
Press <DEL> or <ESC> to enter setup.
```

From interesting changes, are:

- turn off the `BIOS Beep Function` - no more noise beep
- adapt the `Restore AC Power Loss` - this can be managed from `QuTS hero`
- update `Boot Option Priorities` - setup your own boot order

```bash
                 Aptio Setup Utility - Copyright (C) 2021 American Megatrends, Inc.                 
    Main  Advanced  Chipset  Security  Boot  Save & Exit                                            
��������������������������������������������������������������������������������������������������Ŀ
�  Boot Configuration                                             �Select the keyboard NumLock     �
�  Bootup NumLock State                 [On]                      �state                           �
�  Quiet Boot                           [Disabled]                �                                �
�                                                                 �                                �
�  Boot Option Priorities                                         �                                �
�  Boot Option #1                       [UEFI OS (KINGSTON        �                                �
�                                       SNV3S500G)]               �                                �
�  Boot Option #2                       [KINGSTON SNV3S500G]      �                                �
�  Boot Option #3                       [UEFI: Built-in EFI       �                                �
�                                       Shell]                    �                                �
�                                                                 �                                �
�                                                                 �                                �
�                                                                 ��������������������������������ĳ
�                                                                 �><: Select Screen               �
�                                                                 �▒: Select Item                  �
�                                                                 �Enter: Select                   �
�                                                                 �+/-: Change Opt.                �
�                                                                 �F1: General Help                �
�                                                                 �F2: Previous Values             �
�                                                                 �F3: Optimized Defaults          �
�                                                                 �F4: Save & Exit                 �
�                                                                 �ESC: Exit                       �
�                                                                 �                                �
�                                                                 �                                �
�                                                                 �                                �
�                                                                 �                                �
����������������������������������������������������������������������������������������������������
                  Version 2.20.1274. Copyright (C) 2021 American Megatrends, Inc.     
```

!!! Important !!!

This BIOS v2.20.1274 allowing to boot only from USB device or NVMe disk.
SATA disk are not available in a `BOOT Option`, so you have two options to make is working:

1. Use internal USB-DOM as EFI partition, which will allow to boot system from SATA disk

   ```bash
   +-----------+      +-------------------------------+
   |  USB DOM  |      |            HDD                |
   |   (EFI)   |      |         (OS DATA)             |
   +-----------+      +-------------------------------+
   |           |      |                               |
   |  EFI      |      |         Linux OS              |
   | Partition |      |                               |
   |           |      |                               |
   +-----------+      +-------------------------------+
   ```

   - __USB DOM__: Small USB device used exclusively to host the EFI partition
   - __HDD__: Main disk storage for the operating system

   This setup doesn't require any interaction with `BOOT Option` because bios already booting OS from USB-DOM.

2. Use a QNAP U.2 NVMe adapter to use an NVMe drive. Thanks to a dedicated onboard interface, this drive is accessible at full speed to the motherboard. The NVMe drive is also available as a boot option.

   TIP: The 3rd party adapter from NVMe -> SATA will not allow to seen this disk as NVMe. because it uses only the SATA interface.

   ```bash
   +-------------------------------+
   |           NVMe SSD            |
   |            1 disk             |
   +-----------+-------------------+
   |           |                   |
   |   EFI     |      Linus OS     |
   | Partition |                   |
   |           |                   |
   +-------------------------------+
   ```

   - __NVMe SSD__: Single NVMe device for both boot and root
   - __EFI Partition__: Dedicated EFI System Partition (usually 100–512 MB, FAT32)

   This setup requires interaction with `BOOT Option`, but the system loads very quickly.

   !!! picture of adapter !!!

## Arch installation

Arch Linux live distributions always start with an already running SSH server, you just need to set a root password and this will allow you to successfully log in to the Arch live distribution. So you need wait a few minutes until boot is finished and type following command (ofc. connect keyboard to QNAP)

```bash
passwd root
```

and repeat password twice, check full flow

```base
passwd root
New password: 
Retype new password:
passwd: password updated successfully
```

then you can use SSH, but if something goes wrong, without video/UART it will be difficult to troubleshoot (go to [Kernel parameters](Kernel parameters) section)

!!! validate link !!!

This installation process only extends the great [Arch Installation guide](<https://wiki.archlinux.org/title/Installation_guide>) which I recommend.

### Kernel parameters

The following kernel parameters make the UART work stably __ONLY__ when receiving logs (one-way communication). __The order of parameters are maters.__

```bash
earlycon=uart8250,io,0x3f8,115200 console=ttyS0,115200n8 console=tty0 loglevel=6 no_console_suspend 8250.nr_uarts=1 8250.share_irqs=1 8250.skip_tx_test=1 8250.autoflow=0
```

TODO: Would require validate parameters again

### OS Partition

Partitioning depends on the approach you choose, with or without USB-DOM. I prefer to use a single NVMe drive for the entire system (without USB-DOM)

   ```bash
   +-------------------------------+
   |           NVMe SSD            |
   |            1 disk             |
   +-----------+-------------------+
   |           |                   |
   |   EFI     |      Linus OS     |
   | Partition |                   |
   |           |                   |
   +-------------------------------+
   ```

### Basic settings, packages, users

System initialization

```bash
pacstrap /mnt base base-devel vim linux linux-headers linux-firmware amd-ucode openssh bash-completion

```

Remember to generate `fstab`

```bash
genfstab -U -p /mnt > /mnt/etc/fstab
```

Chroot to new OS

```bash
arch-chroot /mnt
```

#### Set root password

```bash
passwd root
```

#### Install basic packages

```bash
pacman -Syy

pacman -S acpi acpid acpi_call-dkms \
  btrfs-progs \
  dmidecode \
  git \
  go \
  htop \
  iotop \
  lm_sensors \
  mdadm \
  minidlna \
  nvme-cli \
  samba \
  smartmontools \
  snapper \
  sysstat
```

#### Service to enable

```bash
systemctl enable acpid
systemctl enable sshd
systemctl enable systemd-network
systemctl enable systemd-resolved
```

#### Create user

```bash
useradd my_user -g users -G wheel,lock
passwd my_user
```

#### Install YAY

Remember to to switch to regular user `my_user`

```bash
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -is
```

```bash
yay -S setserial
```

#### Configure network

```conf
# /etc/systemd/network/10-nic.network 

# Enable DHCPv4 and DHCPv6 on all physical ethernet links
[Match]
Kind=!*
Type=ether

[Network]
DHCP=yes
```

#### Initramfs image

I use `BTRFS` as files system, is good to add `btrfs` module

```conf
# /etc/mkinitcpio.conf
...
MODULES=(vfat)
...

BINARIES=(btrfs)

```bash
bootctl install
```

next, create entry for boot with UART support

```conf
# /boot/loader/entries/arch.conf 
title Arch
linux /vmlinuz-linux
initrd /initramfs-linux.img
initrd /amd-ucode.img
options root=UUID=ROOT_UUID rw mitigations=auto audit=0 earlycon=uart8250,io,0x3f8,115200 console=ttyS0,115200n8 console=tty0 loglevel=6 no_console_suspend 8250.nr_uarts=1 8250.share_irqs=1 8250.skip_tx_test=1 8250.autoflow=0
```

#### UEFI boot manager

## After first boot

### Other basic settings

enable ntp
hostnamcetl
timedatectl

### Optimization

#### Network

```conf
# /etc/sysctl.d/99-nas-net.conf

net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_rmem = 4096 1048576 67108864
net.ipv4.tcp_wmem = 4096 1048576 67108864
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

- `net.core.rmem_max = 134217728` (128 MiB)

   The hard upper limit for any socket’s receive buffer (all protocols, not just TCP). TCP’s auto-tuning won’t grow a socket above this cap.

- `net.core.wmem_max = 134217728` (128 MiB)

   The hard upper limit for any socket’s send buffer. TCP auto-tuning and apps can’t exceed this.

- `net.core.netdev_max_backlog` = 32768

   Max number of packets the kernel can queue per CPU on an interface’s ingress backlog when it can’t process them fast enough. If this fills up, packets are dropped before they reach sockets. A higher value helps absorb bursts on fast NICs.

- `net.ipv4.tcp_rmem` = 4096 1048576 67108864 (4 KiB, 1 MiB, 64 MiB)

  Per-TCP-socket receive buffer auto-tuning triplet: min / default (initial) / max in bytes.
  - The kernel starts near 1 MiB and can grow up to 64 MiB if the flow needs it (but never beyond rmem_max).
  - Larger max helps high-throughput, high-latency (“long fat”) links.

- `net.ipv4.tcp_wmem` = 4096 1048576 67108864 (4 KiB, 1 MiB, 64 MiB)

  Per-TCP-socket send buffer auto-tuning triplet: min / default / max in bytes.
  - The kernel starts near 1 MiB and can grow up to 64 MiB (but never beyond wmem_max).
  - Bigger max can improve single-flow throughput on high-bandwidth, higher-RTT paths.

- `net.core.default_qdisc` = fq

  Sets the default egress queuing discipline to FQ (Fair Queue). It creates per-flow queues and supports pacing, reducing head-of-line blocking and helping latency. It’s a good companion for modern congestion control like BBR. (Note: fq ≠ fq_codel; fq_codel also fights bufferbloat but in a different way.)

- `net.ipv4.tcp_congestion_control` = bbr

  Makes BBR the default TCP congestion control. BBR estimates bottleneck bandwidth and RTT to send at the path’s BDP, usually giving high throughput with low queueing delay. It works best with a pacing qdisc such as fq.

#### RAM/IO (cache, inotify)

```conf
# /etc/sysctl.d/99-nas-tuning.conf 

vm.dirty_background_bytes = 1073741824
vm.dirty_bytes            = 4294967296
vm.vfs_cache_pressure     = 50
fs.inotify.max_user_watches = 1048576
```

- `vm.dirty_background_bytes` = 1073741824 (1 GiB)

  When the total amount of dirty (not-yet-written) page cache in RAM exceeds 1 GiB, the kernel’s flusher threads start writing it to disk in the background. This is a start writing threshold, not a cap.

- `vm.dirty_bytes` = 4294967296 (4 GiB)

  A hard ceiling for dirty page cache. When total dirty data reaches 4 GiB, tasks that keep writing are throttled (they’ll synchronously write/slow down) until writeback clears space.
  - Because you’re using the *_bytes knobs, the percentage-based knobs (vm.dirty_ratio, vm.dirty_background_ratio) are ignored.
  - Rule of thumb: set dirty_background_bytes well below dirty_bytes (you did: 1 GiB < 4 GiB) so background writeback kicks in before writers hit the hard cap.

- `vm.vfs_cache_pressure` = 50

  Controls how aggressively the kernel reclaims the VFS inode/dentry caches versus page cache.
  - 100 is the neutral/default behavior.
  - 50 makes the kernel less aggressive about dropping inode/dentry caches, so it tends to keep filesystem metadata around longer. That can speed up path lookups and stat()-heavy workloads, at the cost of slightly less RAM available for file data cache and other uses.

- `fs.inotify.max_user_watches` = 1048576 (≈1.05 million)

  Maximum number of inotify watches per user. Higher limits are useful for tools like IDEs, file sync/backup daemons, or build systems that watch many directories.
  - Each watch consumes kernel memory (order of hundreds of bytes to ~1 KiB depending on kernel/build), so 1 M watches can mean hundreds of MiB of RAM reserved in the worst case. Make sure your system has headroom.

#### RAID

```conf
# /etc/sysctl.d/99-md-raid.conf
dev.raid.speed_limit_min = 50000
dev.raid.speed_limit_max = 800000
```

- `dev.raid.speed_limit_min` = 50000 (≈ 50,000 KiB/s ≈ 49 MiB/s ≈ 50 MB/s)

  A soft floor for MD RAID background operations (resync, rebuild/recovery, reshape, consistency check). The kernel will try to keep these tasks moving at at least ~50 MB/s when the system isn’t under heavy I/O pressure. It’s not an absolute guarantee, but it nudges the scheduler to give rebuild work enough I/O so it doesn’t starve.

- `dev.raid.speed_limit_max` = 800000 (≈ 800,000 KiB/s ≈ 781 MiB/s ≈ 0.78 GiB/s ≈ 800 MB/s)

  A throttle ceiling for those same background tasks. If the array and disks are fast enough, the kernel won’t let resync/rebuild exceed ~0.8 GB/s. Higher values finish rebuilds sooner (reducing time-at-risk) but can steal I/O from your applications while the operation runs.

### UDEV

#### UART fix

In the [Board/UART] section it was mentioned that in newer Linux `6.X` kernels the UART interface of this board on ttyS0 is unstable in case of interrupts (IRQs), which causes transmission/reception to stop. The udev rule switches to polling mode (timer-controlled) by running:

```bash
setserial /dev/ttyS0 uart 16550A port 0x3f8 irq 0
```

and disables runtime power management:

```bash
echo on | sudo tee /sys/class/tty/ttyS0/device/power/control
```

To make it automaticly every boot, create following `udev` rule:

```conf
# /etc/udev/rules.d/99-ttyS0-nopm.rules

KERNEL=="ttyS0", RUN+="/sbin/setserial /dev/ttyS0 uart 16550A port 0x3f8 irq 0"
ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyS0", ATTR{device/power/control}="on"
```

TIP: Remember ro install `setserial` from [AUR](https://aur.archlinux.org/packages/setserial)

## NAS Server

### Disk Topology

```bash
# Files (private + media) — each LV with dedicated cache
RAID6 mdadm - 5x4TB HDD
  └─ cryptsetup - encrypt whole space
       └─ Luks2 - PV: crypt_files + crypt_cache_files
            ├─ lv_files → Btrfs (-n 16k) + Snapper + dm-cache (NVMe, writethrough)
            └─ lv_media → Btrfs (-n 16k) + Snapper + dm-cache (NVMe, writethrough)


# ISCSI — dedicated aray for ISCSI
RAID1 mdadm - 2x500G HDD
  └─ cryptsetup - encrypt whole space
       └─ Luks2 - PV: crypt_iscsi + crypt_cache_iscsi
            └─ lv_iscsi → backstore=block (LIO) + dm-cache (NVMe, writeback)
```

`writethrough` - allow to sleep disk,
`writeback` - UPS required

#### Partitions

For RAID6 the partition table needs to be a `GPT` and partition need to be `Linux RAID`

```bash
Disk /dev/sdc: 3.64 TiB, 4000787030016 bytes, 7814037168 sectors
Disk model: WDC WD40EFZX-68A
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: gpt
Disk identifier: 3852A24F-D753-41A8-BAAF-CEFD322598BD

Device     Start        End    Sectors  Size Type
/dev/sdc1   2048 7814035455 7814033408  3.6T Linux RAID
```

For RAID1 the same

```bash
Disk /dev/sda: 465.76 GiB, 500107862016 bytes, 976773168 sectors
Disk model: HGST HTS725050A7
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: gpt
Disk identifier: AE1FFFE4-0DE0-46D4-9EC7-01B071742FB0

Device     Start       End   Sectors   Size Type
/dev/sda1   2048 976773119 976771072 465.8G Linux RAID
```

NVMe disk, which will be used for `dm-cache` need to be split for each raid instance, in this case needs to be split to two partitions:

- 650G for files
- 200G for iscsi

TIP: is good to not use whole space, to safe some space for replacing broken memory, what can happen for SSD disk

```bash
Disk model: IR-SSDPR-P34B-01T-80                    
Units: sectors of 1 * 4096 = 4096 bytes
Sector size (logical/physical): 4096 bytes / 4096 bytes
I/O size (minimum/optimal): 4096 bytes / 4096 bytes
Disklabel type: gpt
Disk identifier: AA8AF26B-4AFA-47A0-B3B3-BBEE1F8B2D0A

Device             Start       End   Sectors  Size Type
/dev/nvme1n1p1       256 170393855 170393600  650G Linux filesystem
/dev/nvme1n1p2 170393856 222822655  52428800  200G Linux filesystem
```

#### Create Raid

Create RAID6

```bash
mdadm --create /dev/md0 --level=6 \
  --raid-devices=5 \
  --metadata=1.2 \
  --chunk=256 --bitmap=internal \ 
  --name=files \
  /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1
```

Create RAID1

mdadm --create /dev/md0 --level=1 \
  --raid-devices=2 \
  --metadata=1.2 \
  --chunk=256 --bitmap=internal \
  --name=files \
  /dev/sdf1 /dev/sdg1

```

It's required to add map of raid to `/etc/mdadm.conf`

```bash
sudo mdadm --detail --scan | sudo tee /etc/mdadm.conf
```

which should lokks like this

```conf
cat /etc/mdadm.conf 
ARRAY /dev/md0 metadata=1.2 UUID=e9ab286b:4d2232ae:fbb328ae:96b98307
ARRAY /dev/md1 metadata=1.2 UUID=cd295687:710983a2:93d611f8:2e32e0cf
```

You can check the status of raid with following command

```bash
cat /proc/mdstat 
Personalities : [raid1] [raid4] [raid5] [raid6] 
md1 : active raid1 sdb1[1] sda1[0]
      488253440 blocks super 1.2 [2/2] [UU]
      bitmap: 0/4 pages [0KB], 65536KB chunk

md0 : active raid6 sde1[2] sdd1[1] sdf1[3] sdc1[0] sdg1[4]
      11720653824 blocks super 1.2 level 6, 256k chunk, algorithm 2 [5/5] [UUUUU]
      bitmap: 0/30 pages [0KB], 65536KB chunk

unused devices: <none>
```

## UPS

## TODO

- AES-NI ?
