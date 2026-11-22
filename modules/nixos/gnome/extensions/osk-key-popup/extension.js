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
// The bubble is made once and shown above the keyboard. It isn't
// reactive, so touches go through it. Its look follows Android's open
// keyboard (AOSP LatinIME, which Gboard grew out of): about 1.3 times as
// tall as a key, the letter 82% of the key's height, right above the
// key. It takes the key's own colours but fully opaque: the theme's keys
// are see-through, and a see-through bubble over the app looked muddy.

import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as KeyboardUI from 'resource:///org/gnome/shell/ui/keyboard.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const proto = KeyboardUI.Keyboard.prototype;

// Bubble size relative to the key, and the gap between bubble and key, in
// GNOME's (logical) pixels.
const WIDTH = 1.2;
const HEIGHT = 1.3;
const TEXT = 0.82; // letter size relative to the key's height
const GAP = 2;

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
        this._bubble.style = this._style(button, h);
        this._bubble.set_size(bw, bh);
        this._bubble.set_position(bx, Math.max(Math.round(y - GAP - bh), 0));
        this._bubble.show();
        this._bubble.get_parent()?.set_child_above_sibling(this._bubble, null);
    }

    // The key's colours, made opaque: its background laid over the
    // keyboard's, and that over black if the keyboard is see-through too.
    _style(button, keyHeight) {
        const node = button.get_theme_node();
        const over = (top, below) => {
            const a = top.alpha / 255;
            return {
                red: Math.round(top.red * a + below.red * (1 - a)),
                green: Math.round(top.green * a + below.green * (1 - a)),
                blue: Math.round(top.blue * a + below.blue * (1 - a)),
            };
        };
        const black = {red: 0, green: 0, blue: 0};
        const keyboard = Main.keyboard.keyboardActor?.get_theme_node();
        const base = keyboard ? over(keyboard.get_background_color(), black) : black;
        const bg = over(node.get_background_color(), base);
        const fg = node.get_foreground_color();
        const radius = node.get_border_radius(St.Corner.TOPLEFT);
        return `background-color: rgb(${bg.red}, ${bg.green}, ${bg.blue}); ` +
            `color: rgb(${fg.red}, ${fg.green}, ${fg.blue}); ` +
            `border-radius: ${radius}px; ` +
            `font-size: ${Math.round(keyHeight * TEXT)}px;`;
    }

    _hide() {
        this._owner = null;
        this._bubble.hide();
    }
}
