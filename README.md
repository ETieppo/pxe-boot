# Arch Linux PXE Boot from macOS

PXE boot infrastructure to launch the Arch Linux installer on any PC without a USB drive,
using a Mac as the PXE server over a direct Ethernet cable.

Built and tested on macOS (Apple Silicon) booting an Avell laptop with Insyde UEFI.

## Why this exists

If you ever wipe your `/dev` thinking you were listing files at disk unmmount (it happens), and your
only spare machine is a Mac with no USB pendrive in sight, this gets you back into a
working Arch live environment in a few minutes.

## Requirements

- macOS with [Homebrew](https://brew.sh)
- USB-Ethernet adapter (tested with a Baseus USB-C to RJ45)
- Ethernet cable
- Target PC with modern UEFI and IPv4 PXE Boot support
- Arch Linux ISO

## Initial setup

```bash
./setup.sh /path/to/archlinux-2026.05.01-x86_64.iso
```

This will:

- Install `dnsmasq` and `pv` via Homebrew
- Extract the ISO into `./iso/`
- Build the TFTP tree in `./tftp/`
- Download a vanilla iPXE binary
- Generate the dnsmasq config and the iPXE boot script

You only need to pass the ISO path on the first run.

## Usage

Plug the USB-Ethernet adapter into the Mac and connect the cable directly to the target PC.

Set a static IP on the USB interface:

```bash
sudo networksetup -setmanual "USB 10/100/1000 LAN" 192.168.99.1 255.255.255.0 ""
sudo launchctl unload -w /System/Library/LaunchDaemons/bootps.plist
sudo launchctl disable system/com.apple.tftpd
sudo launchctl disable system/com.apple.bootpd
sudo launchctl kickstart -k system/com.apple.bootpd
```

In separate terminals, run:

```bash
./start-dnsmasq.sh   # Proxy DHCP + TFTP server
./start-http.sh      # HTTP server for kernel / initrd / airootfs.sfs
```

On the target PC:

- In the BIOS: enable `LAN Remote Boot`, disable `Secure Boot` and `VMD` (Intel)
- Boot menu (F7 on Insyde, varies by vendor) → `IPv4 PXE Boot`

## Restoring the Mac

When you're done, run:

```bash
./restore-mac.sh
```

This puts the USB-Ethernet interface back on DHCP, kills the servers, and re-enables the
macOS daemons that were disabled.

## Layout

iso/                # ISO contents (served over HTTP)
tftp/               # Served over TFTP by dnsmasq

## How it works

1. Target PC sends a DHCP request → dnsmasq replies with `ipxe.efi` over TFTP
2. PC loads vanilla iPXE
3. iPXE sends a second DHCP request → dnsmasq detects the `iPXE` user-class and replies
   with the HTTP URL of `boot.ipxe`
4. iPXE fetches and executes `boot.ipxe`, loading kernel + initrd over HTTP
5. The kernel starts, the initramfs configures the network and downloads `airootfs.sfs`
   over HTTP
6. The Arch live system comes up at the `root@archiso ~#` prompt

## Giving the target internet access during install

Once the live system is up, enable Internet Sharing on the Mac so the target can reach
the package mirrors:

- System Settings → General → Sharing → Internet Sharing
- Share connection from: Wi-Fi
- To computers using: USB 10/100/1000 LAN

The Mac becomes the gateway at `192.168.2.1`. On the Arch live system:

```bash
ip addr flush dev eth0
ip addr add 192.168.2.50/24 dev eth0
ip route add default via 192.168.2.1
echo "nameserver 1.1.1.1" > /etc/resolv.conf
```

Then proceed with the usual Arch install (`pacstrap`, `genfstab`, `arch-chroot`, etc).

## Troubleshooting

**`SIOCGIFFLAGS: No such device` flooding the screen, then dropped to `[rootfs ~]#`**
The initramfs timed out waiting for the Ethernet link. The boot script already passes
`rd.net.timeout.carrier=30` and `rd.net.timeout.dhcp=60`, which usually fixes it on the
second boot once the link has settled.

**dnsmasq exits silently with no error**
Run with `--test` to validate the config:

```bash
sudo /opt/homebrew/opt/dnsmasq/sbin/dnsmasq --test --conf-file=/opt/homebrew/etc/dnsmasq.conf
```

Also check that the USB interface still has the expected static IP — macOS sometimes
reverts USB Ethernet adapters back to DHCP when the link is renegotiated. Use
`networksetup -setmanual` (persists across reconnects) instead of `ifconfig` (temporary).

**Target PC isn't listed in the BIOS boot menu**
Many laptops don't power USB Ethernet adapters before the OS loads. If the adapter has
no power at POST, the BIOS can't see it. Use the PC's built-in NIC instead.

**`Can't assign requested address` from the Python HTTP server**
The USB interface doesn't have `192.168.99.1` assigned. Re-run the `networksetup` command
above.

## License

MIT.
