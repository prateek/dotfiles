keychron-q3-qmk-configuration
=============================

- Use [Via](https://www.caniusevia.com/)
- How to configure these keycodes in Via: https://docs.keeb.io/via#how-to-use-any-key

- TODO: https://dreymar.colemak.org/layers-extend.html

| Original Key | QMK KeyCode            | Description                    |
| ------------ | ---------------------- | ------------------------------ |
| Caps Lock    | MT(MOD_LCTL,KC_ESCAPE) | CTRL if held, Esc if tapped.   |
| ;            | MT(MOD_HYPR,KC_SCLN)   | HYPER if held, ; if tapped.    |
| Right Shift  | MT(MOD_RSFT,KC_UP)     | Shift if held, Up if tapped.   |
| Right Ctrl   | MT(MOD_RCTL,KC_RGHT)   | CTRL if held, Right if tapped. |
| Right fn     | LT(1,KC_DOWN)          | FN if held, Down if tapped.    |
| Right Alt    | MT(MOD_RALT,KC_LEFT)   | ALT if held, Left if tapped.   |

### References
- QMK newb tutorial - https://docs.qmk.fm/#/newbs
- ModTap/LayerTap reference: https://thomasbaart.nl/2018/12/09/qmk-basics-tap-and-hold-actions/
- ModTap KeyCodes: https://docs.qmk.fm/#/mod_tap