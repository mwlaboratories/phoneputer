#!/usr/bin/env bash
# Plays candidate key-press vibrations on the phone, to pick one by feel.
#
#   tests/haptics-sweep.sh [root@PHONE]             all candidates, in turn
#   tests/haptics-sweep.sh [root@PHONE] B           only candidate B
#   tests/haptics-sweep.sh [root@PHONE] 0.3:10      any pattern of your own
#
# Each candidate plays as a burst of taps at typing speed (6 taps, 150 ms
# apart), the way you feel it on the keyboard. Hold the phone as you
# usually type.
#
# A pattern is what feedbackd's theme takes (hosts/phoneputer/feedbackd.nix):
# steps of magnitude:milliseconds, comma-separated, magnitude 0 a pause.
# E.g. 0.7:4,0.25:8 is a 4 ms kick and an 8 ms soft tail. The winner goes
# into feedbackd.nix as magnitudes = [ 0.7 0.25 ]; durations = [ 4 8 ];
#
# What the numbers do on the OnePlus 6 (drivers/input/misc/
# qcom-pmi8998-haptics.c and drivers/input/ff-memless.c):
#
# - Magnitude sets the motor's drive voltage, nothing else. feedbackd sets
#   the motor's gain to 75%, and the driver turns the rest into
#   116 mV + 34.8 mV per percent, up to its 3596 mV maximum. So a magnitude
#   of 0.52 and up is already full strength (today's 0.7 is), and below
#   that there are about 30 steps.
# - Milliseconds is how long the motor is driven; when it stops, the chip
#   brakes it.
# - Waveform and frequency can't be chosen: the driver only plays rumble.
#   The kernel turns a sine, square or triangle request into a plain rumble
#   of the same strength (that's how it can claim to support them), and
#   the motor always runs at its own resonance. Changing that means
#   changing the driver.
#
# This plays straight on the motor (as root, over SSH), the same way
# feedbackd does, so it feels the same as it would through feedbackd. It
# leaves feedbackd and its settings alone.

set -euo pipefail

phone=root@192.168.0.237
if [[ ${1:-} == *@* ]]; then phone=$1; shift; fi
choice=${1:-all}
taps=${HAPTICS_TAPS:-6}  # taps per candidate

# name|pattern|what it is
candidates='A|0.7:12|today: full strength, 12 ms
B|0.7:6|crisp: full strength, half as long
C|0.3:10|soft: about 60% strength, 10 ms
D|0.7:4,0.25:8|kick and tail: a 4 ms full-strength kick, then 8 ms soft
E|0.7:20|firm: full strength, 20 ms'

play() { # pattern, taps
    ssh "$phone" perl - "$1" "$2" <<'PERL'
use strict; use warnings; use Time::HiRes qw(usleep);
my ($pattern, $taps) = @ARGV;
my @steps = map { [split /:/] } split /,/, $pattern;

# The vibration motor: the input device with force feedback named
# spmi_haptics.
sub name { open my $f, '<', "$_[0]/device/name" or return ''; scalar <$f> }
my ($dev) = grep { name($_) =~ /^spmi_haptics/ } glob '/sys/class/input/event*';
die "no spmi_haptics input device\n" unless $dev;
$dev =~ s{.*/}{/dev/input/};
open my $fd, '+<', $dev or die "$dev: $!\n";
binmode $fd;

# struct ff_effect (48 bytes on arm64): type, id, direction, trigger,
# replay {length, delay}, padding, then the union: rumble {strong, weak}.
my $EVIOCSFF = 0x40304580; my $EVIOCRMFF = 0x40044581;
my $FF_RUMBLE = 0x50; my $EV_FF = 0x15;
my $id = -1;
sub rumble {
    my ($magnitude, $ms) = @_;
    my $buf = pack('S s S S S S S x2 S S x28', $FF_RUMBLE, $id, 0, 0, 0,
        $ms, 0, int(0xFFFF * $magnitude), 0);
    ioctl($fd, $EVIOCSFF, $buf) or die "upload: $!\n";
    $id = unpack('x2 s', $buf);
    # struct input_event: timeval (16 bytes), type, code, value.
    syswrite($fd, pack('x16 S S l', $EV_FF, $id, 1)) == 24 or die "play: $!\n";
}
for my $tap (1 .. $taps) {
    for my $s (@steps) {
        my ($m, $ms) = @$s;
        rumble($m, $ms) if $m > 0;
        usleep($ms * 1000);
    }
    usleep(150_000);
}
usleep(100_000);
ioctl($fd, $EVIOCRMFF, pack('l', $id)) if $id >= 0;
PERL
}

if [[ $choice == *:* ]]; then
    echo "playing $choice"
    play "$choice" "$taps"
    exit
fi

found=false
while IFS='|' read -r name pattern what; do
    [[ $choice == all || $choice == "$name" ]] || continue
    found=true
    printf '%s  %-14s %s\n' "$name" "$pattern" "$what"
    play "$pattern" "$taps"
    [[ $choice == all ]] && sleep 2
done <<<"$candidates"
$found || { echo "no candidate $choice (A-E, or a pattern like 0.3:10)"; exit 1; }
