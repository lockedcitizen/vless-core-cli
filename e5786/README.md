# Huawei E5786: VLESS + TUN (ARMv5TE userspace)

This is a TCP/IPv4-only first build for the E5786. The workflow builds:
- `vless-core-e5786-armv5`: the existing C VLESS core, local SOCKS5 listener on 127.0.0.1:10808
- `tun2socks-e5786-armv5`: BadVPN tun2socks + lwIP TCP stack
- start/stop/one-host-route smoke-test scripts

Target compiler flags: ARMv5TE, ARM EABI, soft-float, `-Os`, static linking.
The VLESS core and tun2socks each cap active TCP flows at four.

## GitHub Actions

Push to branch `e5786-armv5-tun` or run the workflow manually from Actions.
Download artifact `e5786-vless-tun-armv5te`.

## Modem install

Copy the artifact files to `/online/vpn/`. Create a private URI file (no trailing newline):

```sh
mkdir -p /online/vpn/config
chmod 700 /online/vpn/config
printf '%s' 'vless://YOUR_REAL_URI' > /online/vpn/config/vless-uri.txt
chmod 600 /online/vpn/config/vless-uri.txt
```

The workflow does not embed a VLESS URI or credentials.

## TUN driver is separate

The workflow does not build a kernel module. Before starting, you must have the
module built for this exact modem kernel and confirm that it can create a TUN
interface. The candidate module previously supplied for this modem reports
`vermagic=3.4.5 preempt mod_unload ARMv7`, but runtime operation still needs
testing. After a maintenance-window test:

```sh
insmod /online/vpn/01_tun.ko
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun
```

Do not proceed if `insmod` fails or the modem becomes unstable.

## Start and test

```sh
cd /online/vpn
./start.sh
./route-test.sh 1.1.1.1
```

This adds only a single IPv4 host route through TUN. The default route remains
unchanged. Stop and remove the smoke-test route with:

```sh
./stop.sh
```

## Limitations

- TCP over IPv4 only. UDP, UDP DNS, QUIC, IPv6 and ICMP forwarding are not
  supported by this first profile.
- Do not install a default route through tun0.
- OpenVPN is not used. The workflow does not modify
  `/system/etc/autorun.sh`.
- This is a build artifact, not yet a modem-tested firmware package.
