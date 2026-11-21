// A short vibration when a finger lands on a key of GNOME's on-screen
// keyboard.
//
// GNOME Shell's keyboard has no haptic feedback of its own. This asks
// feedbackd (the daemon phones use for vibration and sounds) to play its
// "button-pressed" event whenever a key is touched. feedbackd picks the
// vibration from its theme; ours makes it firmer than the stock one (see
// hosts/phoneputer/feedbackd.nix).

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class OskHapticsExtension extends Extension {
    enable() {
        const box = Main.layoutManager.keyboardBox;
        // 'captured-event' runs before the keyboard sees the event, for
        // every event aimed at anything inside the keyboard box.
        this._handler = box.connect('captured-event', (_actor, event) => {
            if (this._isPress(event) && this._onKey(event.get_source(), box))
                this._buzz();
            return Clutter.EVENT_PROPAGATE;
        });
    }

    disable() {
        Main.layoutManager.keyboardBox.disconnect(this._handler);
        this._handler = null;
    }

    // A finger or the mouse going down. A touch can also come with a fake
    // mouse press made from it ("pointer emulated"); skip that one, so a
    // single touch buzzes only once.
    _isPress(event) {
        switch (event.type()) {
        case Clutter.EventType.TOUCH_BEGIN:
            return true;
        case Clutter.EventType.BUTTON_PRESS:
            return !(event.get_flags() & Clutter.EventFlags.FLAG_POINTER_EMULATED);
        default:
            return false;
        }
    }

    // Whether the touched actor is a key, or something inside one (its
    // label or icon). In GNOME Shell's ui/keyboard.js every key is an
    // St.Button with the style class 'keyboard-key'. The gaps between keys
    // are padding of the containers around them, so a touch there finds no
    // key on the way up and stays silent.
    _onKey(actor, box) {
        for (; actor && actor !== box; actor = actor.get_parent()) {
            if (actor instanceof St.Button &&
                actor.has_style_class_name('keyboard-key'))
                return true;
        }
        return false;
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
