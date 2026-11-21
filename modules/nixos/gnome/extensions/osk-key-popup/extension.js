// While a finger is on a key of the on-screen keyboard, an enlarged copy
// of its letter shows just above it, like Android's keyboards do; the
// finger hides the key itself.
//
// GNOME Shell 51's keyboard (ui/keyboard.js) has nothing like it: a key
// is an St.Button, and a long press on a letter opens its accent popup.
// This only watches each key button's `pressed` property and never
// touches its gestures or signals, so a tap and a long press do exactly
// what they did. `pressed` is true from the finger landing until it
// lifts, slides off the key, or the long press is recognised (the accent
// popup then takes over), so the bubble goes away in all of those.
//
// Only keys that type their label get a bubble: letters, digits and
// symbols. Keys with an action (shift, backspace, ?123, hide, ...) or a
// keyval (enter, space, arrows) don't, nor do keys showing an icon.
//
// The bubble is made once: a box styled like a key (the 'keyboard-key'
// class, so it follows the theme) with the letter centred in a bigger
// font, shown above the keyboard. It isn't reactive, so touches go
// through it.

import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as KeyboardUI from 'resource:///org/gnome/shell/ui/keyboard.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const proto = KeyboardUI.Keyboard.prototype;

// Bubble size relative to the key, and the gap between bubble and key, in
// GNOME's (logical) pixels.
const WIDTH = 1.25;
const HEIGHT = 1.3;
const GAP = 6;

export default class OskKeyPopupExtension extends Extension {
    enable() {
        // Key button -> its notify::pressed handler id, to undo on disable.
        this._buttons = new Map();
        // The button the bubble is showing for.
        this._owner = null;

        this._label = new St.Label({
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._bubble = new St.Bin({
            style_class: 'keyboard-key',
            style: 'font-size: 2.6em; font-weight: normal; ' +
                'box-shadow: 0 2px 6px 0 rgba(0, 0, 0, 0.45);',
            child: this._label,
            reactive: false,
            visible: false,
        });
        Main.layoutManager.addTopChrome(this._bubble);

        // Keys are made row by row in _addRowKeys(), for every keyboard
        // GNOME builds (a new one comes with every layout change).
        const ext = this;
        const origAddRowKeys = this._origAddRowKeys = proto._addRowKeys;
        proto._addRowKeys = function (keys, layout, ...rest) {
            origAddRowKeys.call(this, keys, layout, ...rest);
            ext._watchKeys(layout);
        };
        // The keyboard that already exists: its keys, not the emoji
        // picker's section tabs, which aren't made in _addRowKeys().
        const layout = Main.keyboard.keyboardActor?._currentLayout;
        if (layout)
            this._watchKeys(layout);
    }

    disable() {
        proto._addRowKeys = this._origAddRowKeys;
        for (const [button, id] of this._buttons)
            button.disconnect(id);
        this._buttons = null;
        this._owner = null;
        Main.layoutManager.removeChrome(this._bubble);
        this._bubble.destroy();
        this._bubble = null;
        this._label = null;
    }

    // A key (Key in ui/keyboard.js, not exported) is the actor with a
    // keyButton.
    _watchKeys(actor) {
        for (const child of actor.get_children()) {
            if (child.keyButton)
                this._watchKey(child);
            this._watchKeys(child);
        }
    }

    _watchKey(key) {
        const button = key.keyButton;
        if (key._hasAction || key._keyval || this._buttons.has(button))
            return;
        const label = button.label;
        if (!label || !label.trim())
            return;
        this._buttons.set(button, button.connect('notify::pressed', () => {
            if (button.pressed)
                this._show(button);
            else if (this._owner === button)
                this._hide();
        }));
        button.connect('destroy', () => {
            this._buttons?.delete(button);
            if (this._owner === button)
                this._hide();
        });
    }

    _show(button) {
        const [x, y] = button.get_transformed_position();
        const [w, h] = button.get_transformed_size();
        const bw = Math.round(w * WIDTH), bh = Math.round(h * HEIGHT);
        const stageWidth = global.stage.width;
        const bx = Math.min(Math.max(Math.round(x + (w - bw) / 2), 0), stageWidth - bw);
        this._owner = button;
        this._label.text = button.label;
        this._bubble.set_size(bw, bh);
        this._bubble.set_position(bx, Math.max(Math.round(y - GAP - bh), 0));
        this._bubble.show();
        this._bubble.get_parent()?.set_child_above_sibling(this._bubble, null);
    }

    _hide() {
        this._owner = null;
        this._bubble.hide();
    }
}
