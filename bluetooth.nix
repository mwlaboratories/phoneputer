# Bluetooth (WCN3990 over UART, btqca) for the OnePlus 6.
#
# 1. NVM path. btqca asks for the board NVM at qca/OnePlus/enchilada/crnv21.bin
#    (the DT's firmware-name), but the OnePlus firmware package ships it as
#    qca/oneplus6/crnv21.bin. Without it: "QCA Failed to download NVM (-2)" and
#    a placeholder address 00:00:00:00:5A:AD. Same mismatch and fix as the
#    qcom/sdm845/OnePlus/enchilada link in configuration.nix.
#
# 2. Public address. No factory BD address reaches mainline (the WiFi MAC has
#    the same problem), so with a valid NVM the controller comes up
#    *unconfigured* ("missing options: public-address") and bluetoothd ignores
#    it. postmarketOS sets one with `bootmac`; here: a stable, locally
#    administered unicast address hashed from androidboot.serialno, so it is
#    the same on every boot and unique per phone.

{ config, pkgs, ... }:

let
  fw = config.mobile.device.firmware;
in
{
  hardware.firmware = [
    ((pkgs.runCommand "oneplus6-bt-firmware-symlink" { } ''
      mkdir -p $out/lib/firmware/qca/OnePlus
      ln -s ${fw}/lib/firmware/qca/oneplus6 $out/lib/firmware/qca/OnePlus/enchilada
    '') // { compressFirmware = false; })
  ];

  systemd.services.bluetooth-public-address = {
    description = "Set a stable Bluetooth public address from the device serial";
    # udev pulls in bluetooth.target once hci0 exists (after hci_uart loads).
    wantedBy = [ "bluetooth.target" ];
    before = [ "bluetooth.target" ];
    path = [ pkgs.bluez pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      # Wait for btqca setup to finish and the controller to report its state.
      for i in $(seq 60); do
        btmgmt --index 0 config 2>/dev/null | grep -q "supported options" && break
        sleep 0.5
      done
      if ! btmgmt --index 0 config | grep -q "missing options:.*public-address"; then
        echo "hci0 already has a public address; nothing to do"
        exit 0
      fi

      serial=$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^androidboot.serialno=//p' | head -1)
      [ -n "$serial" ] || serial=$(cat /etc/machine-id)
      h=$(printf 'bluetooth-%s' "$serial" | sha256sum | cut -c1-12)
      # First octet: set locally-administered (0x02), clear multicast (0x01).
      b0=$(( (0x''${h:0:2} | 0x02) & 0xfe ))
      mac=$(printf '%02X:%s:%s:%s:%s:%s' "$b0" "''${h:2:2}" "''${h:4:2}" "''${h:6:2}" "''${h:8:2}" "''${h:10:2}" | tr a-f A-F)
      echo "setting hci0 public address $mac"
      btmgmt --index 0 public-addr "$mac"
    '';
  };
}
