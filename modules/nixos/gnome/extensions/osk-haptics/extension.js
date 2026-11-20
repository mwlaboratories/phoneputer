// A short vibration on every touch of GNOME's on-screen keyboard.
//
// GNOME Shell's keyboard has no haptic feedback of its own. This asks
// feedbackd (the daemon phones use for vibration and sounds) to play its
// "button-pressed" event whenever a finger lands on the keyboard. feedbackd
// picks the right vibration for the device from its theme.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class OskHapticsExtension extends Extension {
    enable() {
        this._handler = Main.layoutManager.keyboardBox.connect(
            'captured-event', (_actor, event) => {
                const type = event.type();
                if (type === Clutter.EventType.TOUCH_BEGIN ||
                    type === Clutter.EventType.BUTTON_PRESS)
                    this._buzz();
                return Clutter.EVENT_PROPAGATE;
            });
    }

    disable() {
        Main.layoutManager.keyboardBox.disconnect(this._handler);
        this._handler = null;
    }

    _buzz() {
        Gio.DBus.session.call(
            'org.sigxcpu.Feedback',
            '/org/sigxcpu/Feedback',
            'org.sigxcpu.Feedback',
            'TriggerFeedback',
            new GLib.Variant('(ssa{sv}i)',
                ['org.gnome.Shell', 'button-pressed', {}, -1]),
            null, Gio.DBusCallFlags.NONE, -1, null, null);
    }
}
