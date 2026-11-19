# Stage-2 USB gadget: NCM networking + ACM serial console over USB-C.
#
# Mobile NixOS only builds a USB gadget in stage-1 (the initrd) and leaves an
# empty `g1` behind once the system has booted, so a PC sees nothing at all
# over the cable. This rebuilds g1 after boot with:
#   - ncm.usb0 -> phone 172.16.42.1/24; NetworkManager "shared" gives the PC an
#                 address by DHCP, so `ssh root@172.16.42.1` works without WiFi.
#   - acm.GS0  -> serial console on the phone's /dev/ttyGS0
#                 (on the PC: `screen /dev/ttyACM0 115200`).
# 172.16.42.1 is the same address postmarketOS uses for USB networking.

{ config, lib, pkgs, ... }:

let
  gadget = "/sys/kernel/config/usb_gadget/g1";
  udc = "a600000.usb";

  teardown = ''
    if [ -d ${gadget} ]; then
      echo "" > ${gadget}/UDC 2>/dev/null || true
      find ${gadget}/configs -mindepth 2 -maxdepth 2 -type l -delete
      for d in ${gadget}/configs/*/strings/* ${gadget}/configs/* \
               ${gadget}/functions/* ${gadget}/strings/*; do
        [ -d "$d" ] && rmdir "$d"
      done
      rmdir ${gadget}
    fi
  '';
in
{
  systemd.services.usb-gadget = {
    description = "USB gadget (NCM network + ACM serial)";
    wantedBy = [ "multi-user.target" ];
    after = [ "sys-kernel-config.mount" ];
    requires = [ "sys-kernel-config.mount" ];
    before = [ "NetworkManager.service" "serial-getty@ttyGS0.service" ];
    path = [ pkgs.coreutils pkgs.findutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      # The USB controller (dwc3) can probe late.
      for i in $(seq 50); do [ -e /sys/class/udc/${udc} ] && break; sleep 0.2; done

      # Remove the empty gadget stage-1 left behind.
      ${teardown}

      mkdir ${gadget}
      cd ${gadget}
      echo 0x${config.mobile.usb.idVendor} > idVendor
      echo 0x${config.mobile.usb.idProduct} > idProduct
      mkdir strings/0x409
      echo OnePlus > strings/0x409/manufacturer
      echo "${config.networking.hostName} (Mobile NixOS)" > strings/0x409/product
      cat /proc/device-tree/serial-number 2>/dev/null | tr -d '\0' > strings/0x409/serialnumber \
        || echo ${config.networking.hostName} > strings/0x409/serialnumber

      mkdir functions/ncm.usb0
      # Fixed MACs give the PC a stable interface name and lease across reboots.
      echo 02:00:00:1c:a7:01 > functions/ncm.usb0/dev_addr
      echo 02:00:00:1c:a7:02 > functions/ncm.usb0/host_addr
      mkdir functions/acm.GS0

      mkdir configs/c.1
      mkdir configs/c.1/strings/0x409
      echo "NCM + ACM" > configs/c.1/strings/0x409/configuration
      echo 500 > configs/c.1/MaxPower
      ln -s functions/ncm.usb0 configs/c.1/
      ln -s functions/acm.GS0 configs/c.1/

      echo ${udc} > UDC
    '';
    preStop = teardown;
  };

  # Serial console over the ACM function.
  systemd.services."serial-getty@ttyGS0" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    after = [ "usb-gadget.service" ];
    requires = [ "usb-gadget.service" ];
  };

  networking.networkmanager.ensureProfiles.profiles.usb-gadget = {
    connection = {
      id = "usb-gadget";
      type = "ethernet";
      interface-name = "usb0";
      autoconnect = "true";
    };
    ipv4 = {
      method = "shared";
      address1 = "172.16.42.1/24";
    };
    ipv6.method = "ignore";
  };

  # NetworkManager's stock 85-nm-unmanaged.rules ignores every gadget-side
  # interface, so without this the profile above never activates.
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add|change", KERNEL=="usb0", ENV{DEVTYPE}=="gadget", ENV{NM_UNMANAGED}="0"
  '';

  # DHCP/DNS to the PC and SSH over the cable.
  networking.firewall.trustedInterfaces = [ "usb0" ];
}
