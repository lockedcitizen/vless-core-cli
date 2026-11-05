# E5786 TUN kernel module work

## Current status

The modem reports Linux 3.4.5, ARMv7, PREEMPT and Android 2.3.3 / SDK 10.
A candidate `tun.ko` loaded and registered a TUN driver, but the modem
restarted when this command was run:

```sh
ip tuntap add dev tun0 mode tun
```

Therefore, successful `insmod` is not sufficient evidence of runtime
compatibility. Do not repeat the interface-creation test with an unverified
module.

## Generic reference build

The workflow
`.github/workflows/e5786-generic-tun.yml` builds upstream Linux 3.4.5
`drivers/net/tun.c` for an ARMv7 VExpress reference configuration.

The resulting artifact is deliberately labelled:

`e5786-tun-linux-3.4.5-armv7-reference-NOT-FOR-INSTALL`

**Do not install this reference `tun.ko` on the Huawei E5786.** It is not
built against Huawei's vendor kernel tree and does not share the modem's
verified generated headers, exact configuration, symbol version data or
compiler flags. The vermagic string alone cannot establish ABI compatibility.

## What is needed for a real E5786 module

A deployable module requires the exact Huawei Hi6930 / Balong V7R2 kernel
build inputs for the installed firmware:

1. Complete matching kernel source tree, including Huawei vendor patches.
2. Exact generated kernel headers and configuration from that build.
3. Matching `Module.symvers` (or equivalent symbol CRC data if enabled).
4. Matching ARM cross-compiler version and kernel build flags.
5. A successful build of the unmodified vendor `drivers/net/tun.c` as a
   module, followed by offline ABI checks against the modem's exported symbols.

The saved runtime config and exported-symbol-name list are useful diagnostics,
but they are not a substitute for the kernel build tree or symbol CRC data.

## Safety

- Do not change the modem's default route.
- Do not alter `/system/etc/autorun.sh`.
- Do not test a candidate module with `ip tuntap add` until its build inputs
  are verified against the modem.
- Keep the existing VLESS userspace build separate from kernel-module work.
