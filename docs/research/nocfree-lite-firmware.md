---
status: active
doc_type: research
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
status_detail: "Desk research plus earlier captures from Prateek's own keyboard; the device was not attached on 2026-10-05, so the items in the last section are still open."
---

# NocFree Lite Firmware: What It Allows

Background for adding a left-hand navigation layer, a layer indicator, and
host-visible layer state to the NocFree Lite. Each claim links the source that
owns it. Three kinds of evidence appear, and they are labelled:

- **Vendor**: nocfree.com pages and the printed quick-start guide.
- **Source**: the `vial-qmk` and `vial-gui` repositories at pinned commits.
  These describe what Vial firmware does in general. NocFree has not published
  the Lite's build, so they show what the Lite *can* do only where the vendor
  or a device capture confirms the feature is switched on.
- **Device capture**: `hidutil`, `ioreg`, and `system_profiler` output and a
  `.vil` export recorded from Prateek's Lite in earlier agent sessions (May
  to September 2026, in the private session archive). Nothing was
  re-measured for this doc: `hidutil list` on 2026-10-05 showed no NocFree
  device attached.

## Summary

1. **Firmware.** The Lite runs Vial firmware, which is a QMK fork. The official
   configurator is [vial.rocks](https://vial.rocks) or the Vial desktop app.
   It does not use usevia.app and has no VIA JSON definition; Vial firmware
   carries its own definition. Confidence: high.
2. **Layer keys.** Four layers. `MO`, `TG`, `TT`, `LT`, `OSL`, `TO`, `DF`,
   mod-taps, and an "Any" keycode box are standard Vial GUI features, and the
   Lite's stock keymap already uses `MO(1)`. A navigation layer on a tap-hold
   or momentary key needs no custom firmware. Confidence: high for
   `MO`/`TG` and the layer count, medium for `LT`/`TT`/mod-tap on this board
   until tried once.
3. **Per-layer RGB.** No source shows any layer-linked lighting on stock
   firmware, and Vial's lighting protocol has no such setting. RGB is an
   optional add-on that works in wired mode only. Confidence: high that
   wireless mode has no RGB; medium that wired mode has no layer indication.
4. **Custom firmware.** No source for the Lite is published anywhere I could
   find, the MCU and bootloader are unidentified, and the 2.4G link is
   proprietary. A custom build is not a practical path today. Confidence: high
   that no source is public; the rest is unknown.
5. **USB IDs.** Vendor ID `0x4B45` (19269). Product ID `0x3635` (13877) over
   cable, product name `NocFree 65_wired`; `0x3634` (13876) for the 2.4G
   receiver, product name `NocFree 65_2.4G`. Confidence: high (device
   capture).
6. **Raw HID from macOS.** Both the cable and the receiver expose the VIA/Vial
   raw HID interface (usage page `0xFF60`, usage `0x61`). Neither protocol has
   a command that returns the active layer. A host can read and write the
   keymap, and can set lighting if the build enables VialRGB, which is
   unverified. Confidence: high for the interface and the missing layer query;
   unknown for lighting control.

Two facts shape the design more than any other:

- **Wired and wireless are two separate Vial devices with separate keymaps.**
  The vendor says wireless-mode profiles are stored on the dongle and
  wired-mode profiles on the keyboard, so every keymap change has to be made
  twice or exported and re-imported
  ([Lite troubleshooting, "Keymapping"](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
- **RGB cannot indicate anything in wireless mode.** Lighting is wired-only and
  needs the RGB add-on
  ([product page](https://www.nocfree.com/products/nocfree-lite),
  [Lite troubleshooting, "Lighting"](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).

## Lite versus NocFree &

Almost everything on GitHub under the NocFree name is about the other model,
the NocFree & ("Ampersand"), and does not apply to the Lite.

| | NocFree Lite | NocFree & |
| --- | --- | --- |
| Configurator | Vial ([vendor](https://www.nocfree.com/products/nocfree-lite)) | "NocFree Link", a vendor tool ([user manuals index](https://www.nocfree.com/pages/user-manuals), [changelog](https://www.nocfree.com/pages/link-changelog)) |
| Wireless | 2.4G dongle only; no Bluetooth ([FAQ](https://www.nocfree.com/pages/nocfree-faq)) | 2.4G receiver plus BLE ([porting guide](https://github.com/NocFreeKB/NocFree-and-zmk)) |
| MCU | Not published | nRF52833 in each half ([porting guide](https://github.com/NocFreeKB/NocFree-and-zmk)) |
| Open firmware | None found | Community ZMK and RMK ports; the vendor's porting guide says factory firmware is not open source ([NocFreeKB/NocFree-and-zmk](https://github.com/NocFreeKB/NocFree-and-zmk), [sarimabbas/nocfree-and-rmk](https://github.com/sarimabbas/nocfree-and-rmk)) |

The Ampersand porting guide describes nRF52833 controllers, an ESB radio link,
and PCA9555 key scanning. Do not assume any of that for the Lite: it is an
older product with a different configurator and no Bluetooth.

## 1. Firmware and configurator

- The vendor names Vial as the configurator: "Utilize the Vial web interface
  for a user-friendly experience with no software downloads"
  ([product page](https://www.nocfree.com/products/nocfree-lite)). The
  [quick-start guide](https://www.nocfree.com/pages/nocfree-lite-user-manual)
  sends users to `https://vial.rocks` and shows the device listed as
  "NocFree 65W". The vendor's
  [Vial guide](https://www.nocfree.com/blogs/news/get-the-most-out-of-nocfree-lite-with-vial)
  and [troubleshooting page](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)
  say the same, and the latter links the
  [Vial desktop download](https://get.vial.today/download/).
- Device capture agrees. Both USB devices report the serial number
  `vial:f64c2b3c`, the marker Vial firmware puts in the serial so the app can
  find it; `vial-gui` matches on that string
  ([`util.py`](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/util.py#L20)).
  The marker is the same for every Vial keyboard, so it identifies the
  firmware family and not this board.
- Prateek's `.vil` export recorded `via_protocol` 9 and `vial_protocol` 6
  (device capture). Those match the constants in current `vial-qmk`
  ([`via.h` `VIA_PROTOCOL_VERSION 0x0009`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/via.h#L42),
  [`vial.h` `VIAL_PROTOCOL_VERSION 6`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vial.h#L25)),
  so the firmware was built from a recent `vial-qmk` tree, or from something
  that reimplements its protocol. No source lets me tell those two apart.
- "It uses VIA" is wrong in the sense that matters. usevia.app needs a
  definition from [the-via/keyboards](https://github.com/the-via/keyboards) or a
  sideloaded JSON, and there is none: a code search for `nocfree` in
  `the-via/keyboards`, `qmk/qmk_firmware`, and `vial-kb/vial-qmk` returned zero
  results on 2026-10-05. Vial does not need one because the firmware serves its
  own definition over HID
  ([`vial_get_size` / `vial_get_def`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vial.h#L36-L51)).
  A `.vil` file is a keymap export, not a definition.
- The dongle is a Vial device in its own right. It enumerates with the same
  Vial serial, and the vendor says wireless profiles live on it
  ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).

Confidence: high.

## 2. Layer keys

- **Layer count: four.** The product page says "remappable keys, macros, and
  shortcuts across four layers"
  ([vendor](https://www.nocfree.com/products/nocfree-lite)); the quick-start
  guide's Vial screenshot shows layers 0 to 3; the `.vil` export held four
  layers of 5 rows by 13 columns (device capture).
- **`MO` works and ships in the default keymap.** The quick-start guide tells
  users to keep `MO(1)` on the Fn key and shows `MO(0)`, `MO(1)`, `MO(2)` in
  Vial's Layers tab
  ([vendor](https://www.nocfree.com/pages/nocfree-lite-user-manual)). The
  export contained `MO(2)` and `TG(1)` (device capture).
- **The other layer keycodes come from the Vial GUI, for every Vial board.**
  The citations here are to the desktop app's source. vial.rocks is published
  from [vial-kb/vial-web](https://github.com/vial-kb/vial-web), which I did
  not inspect, so use the desktop app if the web version lacks something.
  `vial-gui` generates `MO`, `DF`, `TG`, `TT`, `OSL`, `TO`, and `LT<n>(kc)` for
  each layer the keyboard reports
  ([`keycodes.py`](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/keycodes/keycodes.py#L870-L903)),
  offers mod-taps such as `LCTL_T(kc)`
  ([same file](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/keycodes/keycodes.py#L397)),
  and has an "Any" button that accepts a typed keycode expression
  ([`tabbed_keycodes.py`](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/tabbed_keycodes.py#L168),
  [`any_keycode_dialog.py`](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/any_keycode_dialog.py)).
  These are ordinary QMK keycodes stored in the dynamic keymap, so the firmware
  handles them unless the vendor compiled a feature out. No vendor page
  mentions `LT`, `TT`, or mod-tap by name; that is why they are medium
  confidence.
- **Tap Dance, Combos, Macros** are present: the quick-start guide shows those
  tabs and names "Macros, Tap Dance, and more"
  ([vendor](https://www.nocfree.com/pages/nocfree-lite-user-manual)), and a
  test fixture derived from the Lite's export had 32 slots each for macros,
  tap dances, combos, and key overrides (device capture, second-hand).
- **Tap-hold tuning** (tapping term, permissive hold, and similar) depends on
  whether the build includes Vial's QMK Settings. The protocol has the
  commands
  ([`vial_qmk_settings_*`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vial.h#L46-L49));
  whether the Lite answers them is unverified.

Confidence: high for four layers, `MO`, `TG`, tap dance, combos, and macros;
medium for `LT`, `TT`, mod-tap, and QMK Settings.

## 3. RGB and layer indication

- RGB is an add-on: "The default NocFree Lite does not support lighting without
  this addon"
  ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
- RGB works in wired mode only
  ([product page](https://www.nocfree.com/products/nocfree-lite),
  [troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
- The documented controls are key combos on the Fn layer: Fn+Tab toggles,
  Fn+W/S changes brightness, Fn+Q/E changes mode, Fn+A/D changes colour
  ([quick-start guide](https://www.nocfree.com/pages/nocfree-lite-user-manual)).
  The product page counts 31 effects with adjustable colour, brightness, and
  speed. Those combos are presumably the stock QMK RGB keycodes sitting on layer 1
  (inference): the guide warns that they stop working unless `MO(1)` is on the
  Fn key.
- The Tab and `]` keys light while charging. The indicator cannot be turned
  off manually; it goes out when charging completes
  ([quick-start guide](https://www.nocfree.com/pages/nocfree-lite-user-manual),
  [troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
  Whether firmware or a charge circuit drives it is not documented.
- No vendor page mentions lighting that follows the layer. In QMK, layer
  indication is compiled in (`rgblight` layers or an `rgb_matrix` indicator
  callback); it is not a runtime setting. Vial's lighting protocol offers only
  a global mode, speed, and colour, plus a host-driven direct mode
  ([`vialrgb.h`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vialrgb.h#L11-L22)).
  So per-layer RGB on stock firmware would require the vendor to have built it
  in, and nothing suggests they did.
- Whether Vial shows a Lighting tab for the Lite is not recorded in any source
  I found, including the vendor guide and earlier sessions. The tab appears
  only when the firmware's definition declares `lighting`
  ([`keyboard_comm.py`](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/protocol/keyboard_comm.py#L236-L239)).

Confidence: high that RGB is wired-only and an add-on; medium that stock
firmware has no layer indication (absence of evidence, plus how QMK works).

## 4. Custom firmware

- **No published source.** Zero code-search results for `nocfree` in
  `qmk/qmk_firmware`, `vial-kb/vial-qmk`, and `the-via/keyboards`; neither
  `keyboards/nocfree` nor a NocFree entry under `keyboards/kabedon` exists in
  QMK. The vendor's only GitHub presence, `NocFreeKB`, has one repository and
  it covers the Ampersand. The Lite pages on nocfree.com offer no firmware
  download or update procedure. `vial-qmk` is GPL-2.0-or-later, so a firmware
  built from it carries a source obligation; that is a licensing fact, and I
  found no sign the vendor has been asked or has answered.
- **MCU and bootloader: unknown.** No vendor page names them. The FCC listing
  for the Lite (grantee code 2BFHX) exists, but fccid.io, fcc.report, and two
  manual mirrors returned HTTP 403 to automated fetches, so I could not read
  the internal photos.
- **OEM lead, unverified.** The USB vendor string is `KabeDon` (device
  capture). KabeDon is a keyboard maker with three boards in QMK under
  [`keyboards/kabedon`](https://github.com/qmk/qmk_firmware/tree/master/keyboards/kabedon),
  which use vendor ID `0x4B44` and product IDs that spell the model in ASCII
  (`0x3938` is "98"). The Lite's `0x4B45` with `0x3634`/`0x3635` ("64"/"65")
  follows the same pattern. That points at KabeDon as the firmware author. It
  says nothing reliable about the Lite's MCU: KabeDon's QMK boards use
  ATmega32U4 and STM32F103, and neither is a wireless part.
- **Bootloader hint, unverified.** The vendor's troubleshooting page has an
  entry for the Lite being "detected as a Mass Storage Device" on unstable
  hubs. A keyboard that falls back to a mass-storage device on a brown-out may
  have a UF2-style or similar drag-and-drop bootloader. This is inference from
  one sentence.
- **Wireless.** The dongle is not a dumb receiver; it holds the wireless keymap
  and runs the Vial protocol. In wireless mode the halves therefore send
  something other than finished keycodes to the dongle over a 2.4G link whose
  protocol is unpublished. An open build for the halves would at best keep
  wired mode working. Keeping wireless would also mean replacing the dongle
  firmware or reverse-engineering the link. The vendor's own guide for the
  Ampersand warns that open firmware breaks the stock receiver and
  configurator there
  ([porting guide](https://github.com/NocFreeKB/NocFree-and-zmk)); expect the
  same or worse on the Lite, which has no community port to start from.

Confidence: high that no source is public; MCU, bootloader, and link protocol
are unknown.

## 5. USB identifiers

From `hidutil list`, `ioreg`, and `system_profiler SPUSBDataType` on Prateek's
Macs (device capture):

| Connection | Vendor ID | Product ID | Product name |
| --- | --- | --- | --- |
| USB cable | `0x4B45` (19269) | `0x3635` (13877) | `NocFree 65_wired` |
| 2.4G receiver | `0x4B45` (19269) | `0x3634` (13876) | `NocFree 65_2.4G` |

Both report vendor name `KabeDon`, serial `vial:f64c2b3c`, `bcdDevice` 2, and
USB full speed. Each exposes three HID interfaces: keyboard (usage page 1,
usage 6), mouse (1, 2), and raw HID (65376, 97, which is `0xFF60`/`0x61`).
Karabiner-Elements grabbed both under those product names in September 2026.

The vendor's guide says Vial lists the keyboard as "NocFree 65U" (wired) or
"NocFree 65W" (wireless). Those are the names in the Vial definition; the USB
product strings above are what macOS and Karabiner see.

For this repo, the entries would join the `:devices` map in
`home/dot_config/karabiner.edn.tmpl`:

```clojure
:nocfree [{:vendor_id 19269 :product_id 13877}
          {:vendor_id 19269 :product_id 13876}]
```

The IDs were captured on one unit. A firmware update could change them, though
the vendor publishes none for the Lite.

Confidence: high.

## 6. Reading the layer or setting RGB from macOS

- **The channel exists on both connections.** Usage page `0xFF60`, usage
  `0x61` is the QMK raw HID interface VIA and Vial use, and it is present on
  the cable and the receiver (device capture).
- **Neither protocol can report the active layer.** The complete VIA command
  list in `vial-qmk` covers protocol version, keyboard values, keymap
  read/write, lighting, macros, and layer *count*
  ([`via.h`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/via.h#L55-L78));
  the keyboard-value IDs are uptime, layout options, switch matrix state,
  firmware version, and device indication
  ([`via.h`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/via.h#L82-L86)).
  Vial adds definition, encoder, unlock, QMK settings, and dynamic entries
  ([`vial.h`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vial.h#L36-L51)).
  None returns `layer_state`, and stock firmware pushes nothing unsolicited.
- **A workaround exists but is poor.** `id_switch_matrix_state` returns which
  switches are physically down, so a host could poll it, read the keymap, and
  work out the layer itself. Vial firmware refuses that command until the
  keyboard is unlocked, calling it a "wannabe keylogger" guard
  ([`via.c`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/via.c#L250-L255)).
  Unlocking needs a physical key combo, and the unlocked flag is a RAM
  variable, so expect to repeat it after each power cycle unless the vendor
  built with `VIAL_INSECURE`. Polling also competes
  with the Vial app for the same interface.
- **Lighting from the host depends on the build.** If the firmware enables
  VialRGB, a host can set mode, speed, and colour with `vialrgb_set_mode` and
  paint individual LEDs with `vialrgb_direct_fastset`
  ([`vialrgb.h`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vialrgb.h#L11-L22)).
  The reply to `vial_get_keyboard_id` carries a flag byte that says whether
  VialRGB is compiled in
  ([`vial.c`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/vial.c#L94-L106)).
  If the build uses QMK `rgblight` instead, the VIA lighting channel offers
  brightness, effect, speed, and colour. Which of these the Lite has is
  unverified, and all of it is wired-only.
- **What this means for host-visible layers.** On stock firmware the keyboard
  cannot tell macOS which layer is active. The layer has to be made visible
  some other way: have the layer key send a real keycode that Karabiner can
  see (for example an unused F-key or modifier that Karabiner turns into the
  layer), which moves the layer to the host; or accept that the firmware layer
  is invisible to macOS. A host that owns the layer could also show it on the
  keyboard through `vialrgb_direct_fastset`, in wired mode only and only if
  VialRGB turns out to be enabled.

Confidence: high that the raw HID interface exists and that there is no layer
query; unknown for lighting control until the device is probed.

## Open questions that need the physical keyboard

Run each check twice where it applies: once on the cable (both mode switches
on Wired) and once through the 2.4G receiver.

1. **Confirm the USB IDs and interfaces are unchanged.**

   ```sh
   hidutil list | grep -i nocfree
   ioreg -p IOUSB -l -w0 | grep -A25 'NocFree 65'
   system_profiler SPUSBDataType | grep -B2 -A12 'NocFree 65'
   ```

   Expect vendor `0x4b45`, products `0x3635` and `0x3634`, and a row with
   usage page 65376, usage 97 for each.

2. **Does this unit have the RGB add-on?** In wired mode press Fn+Tab, then
   Fn+W. No light at all means no add-on, and questions 3 and 5 are moot.

3. **Does Vial show a Lighting tab, and which kind?** Open
   [vial.rocks](https://vial.rocks) in Chrome or the desktop app, connect, and
   look for a Lighting tab. A tab with a per-effect list and colour picker
   means VialRGB; brightness/effect/speed sliders only means `rgblight`; no tab
   means no host lighting control. Check through the receiver as well; expect
   none there.

4. **Do `LT`, `TT`, and mod-tap behave?** On a spare key in Vial set
   `LT1(KC_SPACE)` from the Layers tab, then `TT(1)`, then `LCTL_T(KC_ESC)`
   from the Quantum tab. Tap and hold each. Then use the Any button to enter
   `LT(2, KC_F)` and confirm it is accepted. Note whether behaviour differs
   between cable and receiver.

5. **Is there a QMK Settings tab?** If so, record the tapping term and whether
   permissive hold and hold-on-other-key-press are offered. Tap-hold on a home
   position is hard to tune without them.

6. **Does the layer key reach macOS?** Open Karabiner-EventViewer, hold the
   Fn (`MO(1)`) key. Expect no event. Then map a key to `LT1(KC_F18)` or
   similar and confirm the tap produces `f18` while the hold produces
   nothing.

7. **Dump the embedded definition.** The Vial app has no menu item for this
   (File > "Save current layout..." writes the `.vil` keymap, not the
   definition). Fetch it over raw HID with `vial_get_size` (`FE 01`) and
   `vial_get_def` (`FE 02` plus a block number), then LZMA-decompress the
   result; `vial-gui`'s
   [`keyboard_comm.py`](https://github.com/vial-kb/vial-gui/blob/aef8222a2d0429a183b2ed692d5f9efcfd383f08/src/main/python/protocol/keyboard_comm.py)
   shows the sequence. Read the `lighting`, `matrix`, and `customKeycodes`
   keys. This settles question 3 and shows any vendor-specific keycodes.

8. **Is Vial locked?** Open the Security menu in the Vial desktop app. If
   Unlock is enabled, note the key combo it asks for. If the Matrix tester works without
   unlocking, the build is `VIAL_INSECURE` and the matrix-polling workaround in
   section 6 needs no manual step.

9. **Probe the VialRGB flag directly** (optional, replaces guesswork in
   section 6). With the Vial app closed, send the 32-byte raw HID report
   `FE 00` followed by zeros to the `0xFF60` interface and read the reply:
   bytes 0 to 3 are the Vial protocol version, 4 to 11 the keyboard UID, and
   byte 12 is `01` if VialRGB is compiled in. hidapi on macOS wants a leading
   `00` report-ID byte before the 32 payload bytes; without it the write
   fails quietly. Any hidapi client works; do it
   from a throwaway script, since no tool in this repo speaks raw HID yet.

10. **Identify the MCU and bootloader.** Read the chip markings through the
    switch plate or with the case open, on a half and on the dongle. First export a `.vil` in both modes: QMK bootmagic erases the EEPROM, where
    the keymap lives, before it jumps to the bootloader
    ([`bootmagic.c`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/bootmagic/bootmagic.c#L35-L74)),
    so expect the wired keymap to reset to vendor defaults if it triggers.
    Then, with the
    keyboard off, hold Esc (QMK bootmagic's usual key) while plugging in the
    cable and run `system_profiler SPUSBDataType` and `diskutil list` to see
    whether a DFU device or a mass-storage volume appears. Vial's
    Security > "Reboot to bootloader" is the other way in; on a secure build
    it works only after Unlock
    ([`via.c`](https://github.com/vial-kb/vial-qmk/blob/dd43959ae5c08d8a28d38a1acf7b04e86b14a344/quantum/via.c#L434-L438)).
    Do not write anything to a volume that appears; unplugging and replugging
    normally leaves a bootloader.

11. **Ask the vendor.** Whether Lite firmware source or a factory image is
    available on request is a question for NocFree support or their Discord,
    linked from the
    [user manual page](https://www.nocfree.com/pages/nocfree-lite-user-manual).
    Without a factory image to restore, do not flash anything.
