# Waydroid: Android apps in a container, off by default. Turn it on in
# hosts/phoneputer/configuration.nix with
#
#   virtualisation.waydroid.enable = true;
#
# That is NixOS' own Waydroid module (Waydroid 1.6.3 in the nixpkgs this
# repository pins). It brings the container service, LXC, the binder
# configuration and the D-Bus policy that lets the root container service
# own id.waydro.Container; nothing extra is needed for D-Bus. The kernel
# side (Rust Binder, binderfs, memfd, PSI, the iptables targets Waydroid
# uses) is in the Mobile NixOS fork. (NixOS' module asks for the older C
# binder, ANDROID_BINDER_IPC; Mobile NixOS skips such kernel checks, and
# the Rust one does the same job.) This file only narrows what the
# Android container may reach on the phone, and does nothing while
# Waydroid is off.
#
# Rebuild, then fetch the Android images once (about 1 GB, LineageOS 20
# without Google apps):
#
#   sudo waydroid init
#
# and open "Waydroid" from the app grid.
#
# NixOS' module also adds the kernel parameter psi=1. The kernel has PSI
# built in, and Android booted without the parameter on 2026-11-22, so a
# switch alone is enough. The parameter does change the boot image, though,
# so it only takes effect once that is flashed (with the next kernel update,
# for instance).

{ config, lib, ... }:

{
  config = lib.mkIf config.virtualisation.waydroid.enable {
    # NixOS' module trusts the container's interface (waydroid0) entirely,
    # so Android could reach every service on the phone, SSH included.
    # Trust only the loopback interface (NixOS' own default) instead; if you
    # trust another interface, add it here, because this list replaces all
    # others.
    networking.firewall.trustedInterfaces = lib.mkForce [ "lo" ];
    # Android only needs the phone for an address (DHCP) and for name lookups
    # (DNS), both from the dnsmasq that Waydroid starts on waydroid0.
    networking.firewall.interfaces.waydroid0 = {
      allowedUDPPorts = [ 53 67 ];
      allowedTCPPorts = [ 53 ];
    };

    # Waydroid's network script turns on IPv4 forwarding for the whole phone
    # (and leaves it on after Android stops, until the next boot) and adds
    # its own accept-all forwarding rules. On its own that would make the
    # phone a router between Wi-Fi, mobile data and USB. These rules stay in
    # place whether Android runs or not, so only Android's own traffic is
    # ever forwarded: out
    # through the phone's connection (masqueraded, like any app's), and the
    # replies back in. Nothing from outside can open a connection into
    # Android, and no other traffic is forwarded, just as when Waydroid is
    # off.
    networking.firewall.extraCommands = ''
      iptables -w -D FORWARD -j waydroid-fwd 2>/dev/null || true
      iptables -w -F waydroid-fwd 2>/dev/null || true
      iptables -w -X waydroid-fwd 2>/dev/null || true
      iptables -w -N waydroid-fwd
      iptables -w -A waydroid-fwd -i waydroid0 ! -o waydroid0 -j ACCEPT
      iptables -w -A waydroid-fwd -o waydroid0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      iptables -w -A waydroid-fwd -j DROP
      iptables -w -A FORWARD -j waydroid-fwd
    '';
    networking.firewall.extraStopCommands = ''
      iptables -w -D FORWARD -j waydroid-fwd 2>/dev/null || true
      iptables -w -F waydroid-fwd 2>/dev/null || true
      iptables -w -X waydroid-fwd 2>/dev/null || true
    '';
  };
}
