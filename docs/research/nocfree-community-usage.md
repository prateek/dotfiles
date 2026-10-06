---
status: active
doc_type: research
owner: Prateek
created: 2026-10-05
updated: 2026-10-05
related:
  - ../research/nocfree-lite-firmware.md
status_detail: "Desk survey of vendor pages, GitHub, Reddit, reviews, and forums as of 2026-10-05. Nothing was tried on the keyboard. Discord and X were not read."
---

# NocFree Community Usage: What People Do With It

[NocFree Lite Firmware](nocfree-lite-firmware.md) answered what the Lite's
stock Vial firmware *can* do. This doc is about what owners *do* with NocFree
keyboards: the layouts they share, the workflows they build around the board,
the mods, the complaints, and what the vendor has said back. Every claim links
its source. Three kinds of evidence appear:

- **Vendor**: nocfree.com pages, the vendor's Reddit account `u/nocfree`, and
  the vendor's GitHub account `NocFreeKB`.
- **Code**: public repositories, read at their current state on 2026-10-05.
- **Report**: what people say on Reddit, blogs, and review sites. A report is
  one person's account unless the text says otherwise.

Three models appear, and they are not interchangeable:

| Model | Configurator | Wireless | Status on 2026-10-05 |
| --- | --- | --- | --- |
| **Lite** (v1, Prateek's board) | Vial | 2.4G dongle | Shipping since 2024; one variant still in stock ([product page](https://www.nocfree.com/products/nocfree-lite)) |
| **Lite V2** | "in-house solution + Link software" | wired / 2.4G / Bluetooth | In development, target December 2026 ([vendor, r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1vwnzzw/nocfree_lite_v2_progress_update/)) |
| **&** (Ampersand) | NocFree Link, proprietary | wired / 2.4G / Bluetooth | Shipping since March 2026 ([vendor, r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1tnzbvt/nocfree_latest_shipping_update/)) |

The Lite V1 is the only NocFree that runs Vial, and the vendor says it has
"no plans to open source the customization side" of the &
([vendor, r/Nocfree, ~May 2026](https://www.reddit.com/r/Nocfree/comments/1tep0zh/software_options_to_customize_nocfree/)).
Reddit shows relative dates; the dates given below are approximate unless a
day is stated.

## What people actually do with it

Patterns that recur across independent sources. Single accounts, however
interesting, are in the later sections.

1. **A nav layer on a held key, arrows on IJKL or HJKL.** The vendor's own
   Vial guide suggests `Left Fn + J/K/L/I` for arrows
   ([vendor blog](https://www.nocfree.com/blogs/news/get-the-most-out-of-nocfree-lite-with-vial));
   three of the four public Lite `.vil` exports put arrows on the right-hand
   home row behind a layer key
   ([musgravej](https://github.com/musgravej/keyboard-config),
   [llan0](https://github.com/llan0/configs),
   [ThatNerdSquared](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498));
   the most developed & config holds Caps Lock for IJKL arrows
   ([mathiasi](https://github.com/mathiasi/nocfree-and-zmk-config)).
2. **Mods and layers moved to the host rather than the firmware.** The one
   Lite owner with a documented power-user workflow started with Vial home-row
   mods and dropped them for `keyd` "since I can make the combo keybinds apply
   to all my keyboards"
   ([report, r/ErgoMechKeyboards, ~Sep 2026](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w804i0/replacing_the_mouse_with_keyboard/)).
   Two & owners run Karabiner or Hammerspoon profiles keyed to the board
   ([tkhashi](https://github.com/tkhashi/dotfiles),
   [greenheadHQ](https://github.com/greenheadHQ/nixos-config)).
3. **Mostly stock, one or two tweaks.** The vendor's user stories and most
   reviews describe owners who remap almost nothing: "I'm actually pretty
   anti-layer. I only use it for brightness, volume, and tilde"
   ([vendor story, May 2026](https://www.nocfree.com/blogs/news/sarim-nocfree-lite-split-ergonomic-keyboard));
   "Never done key remapping and didn't need to"
   ([vendor story, Jun 2026](https://www.nocfree.com/blogs/news/leslie-wireless-split-keyboard-clean-desk));
   a reviewer who "thought about trying to reprogram the layout" and did not
   ([The Gadgeteer, Dec 2023](https://the-gadgeteer.com/2023/12/12/nocfree-lite-60-compact-split-wireless-mechanical-keyboard-review/)).
4. **The `/?` and right-Shift placement is the complaint.** Reviewers in 2023
   ([The Gadgeteer](https://the-gadgeteer.com/2023/12/12/nocfree-lite-60-compact-split-wireless-mechanical-keyboard-review/)),
   a keyboard database ("Note the displaced `/?` key. I'd recommend swapping
   it with RShift in configurator",
   [YAL-Tools](https://github.com/YAL-Tools/ergo-keyboards)), buyers
   ([r/Nocfree, 2025](https://www.reddit.com/r/Nocfree/comments/1mn6017/nocfree_lite_or/),
   [r/ErgoMechKeyboards, 2025](https://www.reddit.com/r/ErgoMechKeyboards/comments/1lwa7ov/qk_alice_duo_cool_build_quality_not_that_ergonomic/)),
   and a V2 commenter ("the biggest complaint from v1") all name it; the vendor
   confirmed V2 moves the key
   ([vendor, r/Nocfree, ~Sep 2026](https://www.reddit.com/r/Nocfree/comments/1vwnzzw/nocfree_lite_v2_progress_update/)).
5. **2.4G latency and stuck-repeat on the Lite, with a split verdict.** Four
   users in one thread describe wireless lag and a key repeating "until I stop
   it", wired mode fine
   ([reports, r/Nocfree, ~May 2026](https://www.reddit.com/r/Nocfree/comments/1sv9h98/nocfree_lite_65_wirelessly_mode_input_delay/));
   the vendor posted troubleshooting steps and a dongle firmware
   ([vendor](https://www.reddit.com/r/Nocfree/comments/1rd83yp/quick_wireless_troubleshooting_steps/),
   [vendor, 2026-03-17](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)).
   Others report "rock-solid" 2.4G
   ([report, r/Nocfree, late 2025](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/))
   and two Lites "bulletproof" over two years
   ([report, r/ErgoMechKeyboards, ~Sep 2026](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w81gfz/nocfree_is_simply_not_a_good_keyboard/)).
6. **Two keymaps, one `.vil`, swap the UID.** Owners keep wired and wireless
   in sync by exporting from one and editing the keyboard ID at the top before
   importing to the other
   ([report](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/));
   the public exports confirm two distinct Vial UIDs
   ([musgravej README](https://github.com/musgravej/keyboard-config): "wired
   and wireless version are different UUIDs in the config").
7. **Everything open-firmware is about the &, not the Lite.** Every firmware
   repository (ZMK, RMK, Rust) targets the &. The Lite has `.vil` exports,
   one macOS HID tool, and nothing else ([GitHub section](#github-projects)).

## What this adds to the firmware doc

Facts the earlier research did not have. None were tested on Prateek's unit.

- **The Lite dongle has a UF2 bootloader and the vendor ships firmware for
  it.** With the dongle plugged in and both halves in wireless mode,
  `Fn + Space + Backspace` makes "a drive" appear; the vendor attached
  `RCV3.uf2` (80,896 bytes) "if purchased after December 2024" and ends with
  "unplug and replug the dongle"
  ([vendor, r/Nocfree, 2026-03-17](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)).
  The chord is pressed on the halves, but the `RCV` name and the replug step
  say the drive is the receiver's. The post carries the generic "Support"
  flair; the December 2024 purchase date and the pre-& timing make it the
  Lite. The file's header uses UF2
  family `0x6a1b09b4`, which is not in the
  [public registry](https://github.com/microsoft/uf2/blob/master/utils/uf2families.json),
  and the image loads at `0x08004000` with a Cortex-M vector table (inspected
  2026-10-05, not flashed). Inference: a Cortex-M part with flash at
  `0x08000000` behind a 16 KiB vendor bootloader. This is the dongle only;
  nothing is known about the halves. Note the firmware doc's warning that a
  bootmagic-style entry can erase the keymap; export first.
- **The vendor lists tap-hold misbehaviour as a wireless symptom.** The same
  post names "home row mods not triggering correctly, or light taps being
  registered as long presses" as a "Wireless mode anomaly" the firmware
  update targets. One owner reported the update made lag "hilariously" worse
  ([report, same thread](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)).
- **Vial shows a Lighting tab in wired mode and hides it wireless.** "Even
  Vial disabled the lighting tab when used wirelessly"
  ([The Phonograph review](https://www.thephonograph.net/nocfree-lite-review/)).
  The same review says NKRO "is not enabled by default, you need to enable it
  through Vial".
- **Stock layer 1 has Mac/Win swap keys and layer 2 has `RESET`.** Two
  independent "default" exports put `MAGIC_SWAP_LALT_LGUI` and
  `MAGIC_UNSWAP_LALT_LGUI` on Fn+I and Fn+O, RGB keys on Fn+Tab/Q/W/E/R/T and
  Fn+A..G, `MO(2)` on layer 1, and `RESET` at the top-right of layer 2
  ([ThatNerdSquared](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498),
  [leonardbinet](https://github.com/leonardbinet/macos-setup)). That is
  probably the "keyboard shortcut lets you flip between Windows and Mac
  modes" a reviewer mentioned without naming the keys
  ([The Gadgeteer](https://the-gadgeteer.com/2023/12/12/nocfree-lite-60-compact-split-wireless-mechanical-keyboard-review/));
  the join is my inference.
  The exports disagree on which bottom-row position holds `MO(1)` by default
  (r4c3, r4c0, and r4c1 in three sources), so check the board rather than
  trust any one file.
- **The Lite V2 drops Vial.** It moves to "our in-house solution + Link
  software, with ongoing firmware updates", gains Bluetooth and a pin-hole
  reset, and does not say how many layers it will have
  ([vendor, r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1vwnzzw/nocfree_lite_v2_progress_update/),
  [survey page](https://www.nocfree.com/pages/lite-v2-feedback)). The vendor
  told a Lite owner asking for more than four layers that "our new model will
  support up to 8 layers", meaning the &
  ([vendor, r/Nocfree, ~Feb 2026](https://www.reddit.com/r/Nocfree/comments/1qt7qnk/is_there_any_way_to_increase_the_amount_of_layers/)).
- **Warranty excludes custom firmware.** "Unauthorized disassembly, modding,
  or custom firmware flashing" voids the one-year warranty on both models
  ([warranty policy](https://www.nocfree.com/pages/warranty-policy)).
- **A macOS Swift client already writes the Lite's keymap over raw HID.**
  [choijhyeok/my-key-mapping](https://github.com/choijhyeok/my-key-mapping)
  matches VID `0x4b45` PID `0x3635`, usage page `0xFF60`, and sends the Vial
  `0xFE 0x00` (UID), `0xFE 0x05` (unlock state), `0x05` (set key) commands to
  patch the Fn-layer digits. Its README says it is for the "KabeDon NocFree 65
  wired model" only. This is the reference the firmware doc lacked for its
  "no tool in this repo speaks raw HID yet".

## Vendor material

Enumerated from the site's sitemap on 2026-10-05: 23 pages, 16 products, 14
blog posts. Rows the firmware doc already covered are kept to one line.

| Document | Model | What it contains |
| --- | --- | --- |
| [Lite product page](https://www.nocfree.com/products/nocfree-lite) | Lite | Specs (65 keys, 2×1800 mAh, "1000Hz", RGB wired-only), "four layers", Vial. One of ten variants in stock. "Lite V2 is coming" banner. |
| [Lite quick-start guide](https://www.nocfree.com/pages/nocfree-lite-user-manual) | Lite | Three JPG pages, no text. Combos: macOS Setup Assistant asks for `Z` and `/?`; `Fn+Backspace` or `Fn+/?` = Delete; `Fn+number` = F-keys; RGB `Fn+Tab` toggle, `Fn+W/S` brightness, `Fn+Q/E` mode, `Fn+A/D` colour; spare-dongle pairing `Fn+Tab+5`; macOS remap: bottom row to `MO(1)`, `LCtrl`, `LAlt`, `LGui`. |
| [Lite troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting) | Lite | Nine Q&As: both toggles same mode; Matrix tester for dead keys; RGB is an add-on and wired-only; charging LED cannot be turned off; Vial is optional; wireless profile lives on the dongle, wired on the keyboard, "set them up separately"; no battery readout, "up to six months"; no Mac keycaps for grey/green/side-print sets; mass-storage enumeration on weak hubs. Links [vial-gui issue 160](https://github.com/vial-kb/vial-gui/issues/160) for macOS download trouble. |
| [FAQ](https://www.nocfree.com/pages/nocfree-faq) | Lite, & | Lite: no Bluetooth, "1000Hz", 30 m; no multi-channel ("all connected devices will receive the same input"); US QWERTY only; halves re-pair with `Ctrl + \ + 9`; for repeat/stick/delay "A USB 2.0 port may work better than a USB 3.0 port". & tab: 17 Q&As incl. backlight works wireless, TTC/Cherry/Jerrzi low-profile switches. |
| [Vial guide](https://www.nocfree.com/blogs/news/get-the-most-out-of-nocfree-lite-with-vial) | Lite | Jan 2025. `Left Fn + I/J/K/L` arrows, `Fn + [ ]` volume, swap `MO(1)` and `LGui` for Mac, double-tap right Shift macro for `Cmd+Shift+4/5`, Mac Shortcuts app for launching apps. Five embedded videos. |
| [Typing Through 2024](https://www.nocfree.com/blogs/news/typing-through-2024-dreaming-of-2025) | Lite V2 | Jan 2025 tease: "USB-C ports on the keyboard (finally!)", "Stronger wireless connections", "Lower latency". |
| [Lite V2 feedback survey](https://www.nocfree.com/pages/lite-v2-feedback) | Lite V2 | Sep 2026. ANSI/ISO/JIS/KR layout images; Space/Fn order options A and B; price bands "Under $150" to "$210 or above"; tester sign-up. Decoded ANSI image: right half ends `N M , . / Shift ↑ Del` with `/` back in the row. |
| [Sarim](https://www.nocfree.com/blogs/news/sarim-nocfree-lite-split-ergonomic-keyboard), [Leslie](https://www.nocfree.com/blogs/news/leslie-wireless-split-keyboard-clean-desk) user stories | Lite | Vendor-authored, May and Jun 2026. Glove80, Advantage 360, Defy, Moonlander, Q11 rejected; dongle in a dock to switch computers; almost no remapping. |
| [Switch guide](https://www.nocfree.com/pages/how-to-find-your-perfect-mechanical-keyboard-switch) | Lite | Linear/tactile/silent explainer with sound clips. |
| [Lite accessories](https://www.nocfree.com/collections/accessories) | Lite | Spare dongle $10, walnut palm rest $25, keycap sets, carrying case, switches (all sold out). |
| [Warranty](https://www.nocfree.com/pages/warranty-policy), [refund](https://www.nocfree.com/pages/refund-policy-1) | both | One year; custom firmware flashing excluded. Support "may first provide" troubleshooting and "official NocFree firmware and software guidance". |
| [& manual](https://www.nocfree.com/pages/nocfree-and-manual) | & | Mode switch positions, `Fn+1/2/3` Bluetooth, `Fn+Tab` backlight, `Fn+I` types firmware version and battery into the focused field, F-row table with Mission Control and Spotlight, sleep timers, Link needs wired mode. |
| [& troubleshooting](https://www.nocfree.com/pages/nocfree-and-troubleshooting) | & | 13 entries: half re-pair `Fn+4`/`Fn+9`, dongle re-pair `Fn+4` 5 s, DFU `Fn+5` (left) `Fn+0` (right), wrong-firmware recovery `Option+3` / right `Space + +`, numpad DFU, tenting-kit charging. |
| [Link changelog](https://www.nocfree.com/pages/link-changelog) | & | v2.0.0 (May 2026) to v2.4.5 beta (Sep 2026) with per-layout `.uf2` downloads and a "Firmware Care" app. v2.0.0 added MT/LT; v2.3.0 fixed "previous key inputs might remain active after switching layers"; v2.4.0 added OS battery display and capped backlight at 40%; v2.4.5 beta blames failures on "keyboard identity code" overwritten by pairing data. |
| [Firmware update guide](https://www.nocfree.com/blogs/news/nocfree-firmware-update-guide), [first-day guide](https://www.nocfree.com/blogs/news/nocfree-keyboard-setup-guide) | & | Aug 2026. Manual drag-and-drop order, macOS Finder error -36 is expected, 5 V/1 A charging only. |
| [About us](https://www.nocfree.com/pages/about-us) | general | Nine-person team, founder "Solar", Discord "800+ members". Operator is Happy NocNoc Ltd, Hong Kong ([terms](https://www.nocfree.com/pages/terms-of-service)). |

Not on the site: any Lite firmware download, Vial definition, `.vil`, factory
reset procedure, or mention of Vial's lock/unlock. The & firmware is
distributed; the Lite's only known firmware is the Reddit attachment above.
Discord invites and `contact@nocfree.com` appear on every support page.
Support is handled by named staff on Discord ("DM Eva",
[vendor](https://www.reddit.com/r/Nocfree/comments/1veir2o/devs_your_firmware_needs_daily_updates_atm/))
and email ("Emma", with "an 8-12-hour delay between messages",
[report](https://www.reddit.com/r/Nocfree/comments/1twinkh/how_to_fix_it_if_you_update_your_nocfree_with_the/)).

## GitHub projects

Searched with `gh search repos`, `gh search code`, `gh search commits`,
`gh search issues`, plus GitLab and Codeberg (both empty). Stars and dates as
of 2026-10-05. Forks that only mirror upstream are omitted.

| Repo | Model | What it is | Stars | Last push | Usable? |
| --- | --- | --- | --- | --- | --- |
| [NocFreeKB/NocFree-and-zmk](https://github.com/NocFreeKB/NocFree-and-zmk) | & | Vendor-hosted, community-written ZMK baseline (BLE split, USB). README: hardware is nRF52833 with PCA9555 I²C key scanning; "factory firmware are not open-source"; flashing may break the receiver and Link. | 9 | 2026-08-25 | Builds in CI; no releases; no dongle, battery, backlight, or numpad. |
| [sarimabbas/nocfree-and-rmk](https://github.com/sarimabbas/nocfree-and-rmk) | & | RMK firmware for left, right, and dongle plus a signed macOS/Windows/Linux "Companion" app that backs up stock firmware, installs RMK, and restores. Vial support, `.vil` presets, Homebrew cask. | 0 | 2026-10-05 | Four releases on 2026-10-05; ANSI only; the author's own open issues list untested hosts. |
| [jhkim0218/Nocfree-and-ZMK-rust](https://github.com/jhkim0218/Nocfree-and-ZMK-rust) | & | Independent `no_std` Rust firmware with its own 2.4G dongle image and NocFree Link protocol support. Caps-hold layer with arrows, mouse keys. | 3 | 2026-09-12 | Committed UF2s, no releases; ANSI and KR hardware-verified. |
| [obiwanblee/nocfree-zmk](https://github.com/obiwanblee/nocfree-zmk) | & | ZMK port with a BLE-to-USB dongle bridge, ZMK Studio, backlight sync, deep sleep. Warns the dongle "has no buttons and no reset pinhole". | 1 | 2026-08-26 | "Daily-driver stable"; three open issues unanswered. |
| [mathiasi/nocfree-and-zmk-config](https://github.com/mathiasi/nocfree-and-zmk-config) | & (Nordic ISO) | ZMK user config, separate Mac and Windows keymaps, Caps-hold nav layer. Documents the stock-to-ZMK-to-stock round trip and the stock bootloader (`Fn+5`/`Fn+0`). | 0 | 2026-10-05 | CI images with checksums; battery readout is a stub. |
| [Thie1e/NocFree-and-zmk](https://github.com/Thie1e/NocFree-and-zmk) | & (ISO DE) | ISO fork of the vendor baseline, "completely vibe-coded", no sleep. | 0 | 2026-09-12 | One release with UF2s. |
| [verzyo/NocFree-and-zmk](https://github.com/verzyo/NocFree-and-zmk) | & | Fork carrying a kanata-style keymap: home-row mods, Space layer-tap, Esc on Caps. | 0 | 2026-08-24 | Personal keymap. |
| [0hCome0n/nocfree-zmk](https://github.com/0hCome0n/nocfree-zmk) | & | Fork of obiwanblee with a mouse-and-numpad layer. Author later shorted the left battery PCB. | 1 | 2026-08-22 | Personal. |
| [musgravej/keyboard-config](https://github.com/musgravej/keyboard-config) | **Lite** | Five `.vil` exports: base, wired-mac, wired-linux, two 2.4G. | 0 | 2026-08-21 | Config only. |
| [llan0/configs](https://github.com/llan0/configs) | **Lite** | One `.vil` with LT and Hyper thumbs. | 0 | 2026-03-28 | Config only. |
| [leonardbinet/macos-setup](https://github.com/leonardbinet/macos-setup) | **Lite** | One `.vil`, near-stock, "Import nocfree keybinding via vial". | 0 | 2026-04-13 | Config only. |
| [ThatNerdSquared/dotfiles](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498) | **Lite** | Two `.vil` files (stock wired, custom 2.4G) added and removed the same day "after returning the board". | — | 2025-07-02 | Deleted; readable at the commit. |
| [choijhyeok/my-key-mapping](https://github.com/choijhyeok/my-key-mapping) | **Lite** | macOS app with a Swift raw-HID Vial client that patches the Fn-layer digits. | 0 | 2026-10-02 | v0.1.0 release. |
| [bgrolleman/dotfiles](https://github.com/bgrolleman/dotfiles) | Lite (by date) | Ansible task installing a udev rule for the Vial serial `vial:f64c2b3c`. | — | 2025-05-31 | Linux only. |
| [tkhashi/dotfiles](https://github.com/tkhashi/dotfiles) | & | Karabiner profile for the & plus Hammerspoon switcher; ADR on BLE channels having different addresses. | — | 2026-08 | macOS config. |
| [greenheadHQ/nixos-config](https://github.com/greenheadHQ/nixos-config) | & | Hammerspoon F11 binding; notes on F3 mismatch fixed in Link. | — | 2026-08 | macOS config. |
| [YAL-Tools/ergo-keyboards](https://github.com/YAL-Tools/ergo-keyboards) | Lite | Database entry: 65 keys, "firmware: QMK, software: Vial", displaced `/?`. | — | — | Reference. |
| [petems/petersouter.xyz](https://github.com/petems/petersouter.xyz) | Lite | Garden page, Mar 2026: the four RGB chords "I actually use". | — | 2026-04 | Blog. |
| [Scratch219/nocfreezmk](https://github.com/Scratch219/nocfreezmk) | ? | Empty repository. | 0 | 2026-05-08 | Nothing. |

The only vendor comment on GitHub is one reply in
[NocFreeKB issue #4](https://github.com/NocFreeKB/NocFree-and-zmk/issues/4)
(2026-08-20): "This is exactly why I set up this repository: to give people
who understand ZMK a place to share findings... I may not be able to
contribute deeply to every technical discussion." Two community PRs adding
numpad support and connection recovery have sat open since 2026-09-12.

Negatives for the Lite, after searching `nocfree`, `"NocFree 65"`,
`"NocFree 65U"`, `"NocFree 65W"`, `KabeDon`, `4B45`, and the two Vial UIDs:
no firmware source, no QMK/Vial/ZMK/RMK port, no kanata or Karabiner config,
no `.stl`/`.3mf`/`.scad`, no issues or PRs. Searches for "Lite V2" outside
this repo return nothing.

## Layouts and layer schemes people share

### Lite (Vial)

The matrix in every export is 5 rows × 13 columns, four layers, 16 macro
slots, 32 each of tap dance, combos, and key overrides. Two Vial UIDs:
`7369517445122672664` for the wired keyboard and `8481673586147325631` for
the 2.4G dongle ([musgravej](https://github.com/musgravej/keyboard-config),
[ThatNerdSquared](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498)).
An electrical oddity shows up in all of them: `6` and `Y` sit at row 4,
columns 5 and 6, between the two spacebars, and `/` is at row 3 column 12,
right of `Up`.

- **Stock** ([ThatNerdSquared "default-wired"](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498),
  [leonardbinet](https://github.com/leonardbinet/macos-setup)): layer 0
  `KC_GESC` top-left, bottom row `LCtrl LGui LAlt MO(1) Space | 6 Y Space RAlt
  RCtrl ← ↓ →`. Layer 1: `` ` `` and F1-F12 on the number row, `Delete` on
  Backspace, RGB keys on Tab/Q/W/E/R/T and A-G, `MAGIC_SWAP_LALT_LGUI` /
  `MAGIC_UNSWAP_LALT_LGUI` on I/O, `Insert PgUp Delete` and `Home PgDn End`
  near the arrows, `MO(2)`. Layer 2: `RESET` top-right. Layer 3: empty.
- **musgravej, macOS-first** ([repo](https://github.com/musgravej/keyboard-config)):
  `MO(1)` on the Caps position and on a right thumb; arrows on the right
  home row of layer 1 (`Up` r1c7, `Left/Down/Right` r2c7-9); layer 2 numpad on
  `U I O / J K L / M , .` plus the F-row; tap dance `TD(0)` right Shift tap,
  `/` on double tap (the `/?` fix as a tap dance); `TD(11)` F tap, hold
  `MO(2)`; `TD(8)` I tap, hold `LGui`; macros `M0-M7` for `Cmd+C/V/Z/T/F/S/A/R`
  and `M12 = Ctrl+Cmd+Q`; combos `LShift+Space` → `[` and `]`; `QK_BOOT` on
  layer 3 Backspace. A Linux variant swaps the macros to `Ctrl`.
- **llan0** ([repo](https://github.com/llan0/configs)): `LT3(Esc)` on Caps,
  `LT2(Space)` left thumb, `LT1(Backspace)` right thumb, `LCAG(KC_NO)` and
  `HYPR(KC_NO)` as thumb modifiers; layer 1 shifted symbols; layer 2 F-row,
  `HJKL` arrows, `QK_BOOT`; macros `M1 = Ctrl+B` (tmux prefix), `M2-M5 =
  Hyper+1-4`.
- **ThatNerdSquared, 2.4G** ([commit](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498)):
  `Esc` on Caps, `MO(1)` at r4c1, `LGUI_T(...)` mod-tap, `TD(0)` = `TG(1)`
  tap / `RGui`, layer 1 `HJKL` arrows and the macOS media row
  (`BRID BRIU MRWD MPLY MFFD MUTE VOLD VOLU`). The owner returned the board
  the same day they committed this.
- **Vendor guide** ([blog](https://www.nocfree.com/blogs/news/get-the-most-out-of-nocfree-lite-with-vial)):
  `Left Fn + I/J/K/L` arrows, `Fn + [ ]` volume, swap `MO(1)` and `LGui` so
  Ctrl sits left of Space as on a MacBook, a right-Shift double-tap macro that
  sends `Cmd+Shift+4` or `5`, and the Mac Shortcuts app to launch apps from a
  key Vial cannot otherwise bind.
- **Vial macros as portable text expansion** ([report, r/logseq, ~2023](https://www.reddit.com/r/logseq/comments/194w5t7/shortcut_to_trigger_specific_template/)):
  a Logseq template trigger is "part of my keyboard (Nocfree + Vial.rocks
  site) so it works both in my Windows and Linux environments."
- **Mouse replaced by keyboard, from a Lite** ([report, r/ErgoMechKeyboards, ~Sep 2026](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w804i0/replacing_the_mouse_with_keyboard/),
  [Fievel](https://www.reddit.com/r/ErgoMechKeyboards/comments/1wcmv14/fievel_emulate_mouse_movements_with_keyboard/)):
  BAUDR8 types on a Lite with `keyd` combos as home-row mods (`a+s` Super,
  `s+d` Ctrl, `s+f` free-mouse mode, mirrored on `u+i`/`i+o`, 25 ms window),
  `wl-kbptr` for on-screen click hints, and their own Rust tool Fievel for
  HJKL mouse movement with Space click and `NM<>` scroll. They "used [Vial]
  at first for homerow mods, but have since stopped". Linux and Wayland; for
  macOS they point at Neru and Mousemaster. The vendor reposted the video
  ([r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1w8rv4w/thanks_for_using_nocfree_lite_an_impressive/)).
  Single owner, so not a pattern, but the most complete Lite workflow found.

### & (NocFree Link or open firmware)

Not applicable to the Lite's firmware, but the layer ideas transfer.

- **Caps-hold nav, hold-preferred** ([mathiasi](https://github.com/mathiasi/nocfree-and-zmk-config)):
  `caps_nav` hold-tap with `tapping-term-ms = 200` and `flavor =
  "hold-preferred"`, because "tap-preferred resolves only on the timer, so
  every arrow would cost a 200 ms wait". `Caps+I` up, `Caps+J/K/L`
  left/down/right, everything else transparent. Separate Mac and Windows
  keymaps rather than a runtime toggle; F-row sends consumer usages by default
  and F1-F12 behind Fn, "which is how Apple's own keyboards behave".
- **Home-row mods, Space layer-tap** ([verzyo](https://github.com/verzyo/NocFree-and-zmk)):
  `hm` with `tapping-term-ms = 300`, `quick-tap-ms = 200`, `flavor =
  "balanced"`; `A S D F` = Gui Alt Shift Ctrl mirrored on `J K L ;`; both
  spacebars `lt SECONDARY SPACE`; backtick is a layer-tap to a window-switcher
  layer; Esc on Caps, Caps on right Shift.
- **Caps-hold layer in Rust firmware** ([jhkim0218](https://github.com/jhkim0218/Nocfree-and-ZMK-rust)):
  `Q` browser back, `W/A/S/D` arrows, `E/R` Home/End, `Z/X` PgUp/PgDn,
  `I/J/K/L` pointer, `U/M` wheel, `C/V/B` mouse buttons.
- **Stock Link limits** ([kbd.news review](https://kbd.news/NocFree-review-2892.html)):
  "no proper layer functions available. No double-function mod-tap option, no
  way to set up e.g. SpaceFN." The v2.0.0 firmware later added MT/LT
  ([changelog](https://www.nocfree.com/pages/link-changelog)), and a KR user
  notes Link offers "8 × 84 keymaps, 16 executable hotkeys"
  ([jhkim0218](https://github.com/jhkim0218/Nocfree-and-ZMK-rust)).

## macOS notes

- **Setup Assistant.** macOS asks for `Z` and `/?` on first connection
  ([quick-start](https://www.nocfree.com/pages/nocfree-lite-user-manual)).
- **Bottom row.** Stock Lite order is `Ctrl Win Alt Fn`; the vendor's Mac
  remap is `Fn Ctrl Opt Cmd` with keycaps moved
  ([quick-start](https://www.nocfree.com/pages/nocfree-lite-user-manual)).
  One Mac user's complaint is that all four keys are 1u, so "the first key
  closest to the space bar" cannot be wider as on a MacBook
  ([Medium, Nov 2024](https://leowu507.medium.com/a-personal-journey-to-ergonomic-comfort-nocfree-lite-keyboard-review-a5209e5defb9)).
  Mac-legend keycaps exist only for the default white top-print set
  ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
- **Mac/Win swap keys** on the stock Fn layer (`Fn+I`, `Fn+O`) are QMK's
  `MAGIC_SWAP_LALT_LGUI` family, so they persist in EEPROM like any QMK magic
  setting ([exports](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498)).
  Vial-level remapping is the documented route; the swap is a fallback.
- **Vial desktop on macOS.** The vendor links
  [vial-gui issue 160](https://github.com/vial-kb/vial-gui/issues/160) for
  download problems ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
  A reviewer found vial.rocks "slow to startup and laggy" and the desktop app
  "snappy" ([The Phonograph](https://www.thephonograph.net/nocfree-lite-review/)).
- **Launching apps.** Vial cannot open an application; the vendor's workaround
  is a Vial key bound to a Mac Shortcuts hotkey
  ([Vial guide](https://www.nocfree.com/blogs/news/get-the-most-out-of-nocfree-lite-with-vial)).
- **Wireless wake on a Mac.** The vendor's advice for "wireless mode not
  recognized after shutdown or long sleep" is to keep the Mac on mains power
  because "on battery, macOS sometimes cuts power to USB ports"
  ([vendor, r/Nocfree, ~Apr 2026](https://www.reddit.com/r/Nocfree/comments/1sb5yg3/how_to_fix_wireless_mode_not_recognized_after/)).
  Model not stated; the dongle advice fits the Lite.
- **Lite 2.4G lag on MacBooks.** The input-delay thread's original poster and
  one reply are on MacBooks
  ([reports](https://www.reddit.com/r/Nocfree/comments/1sv9h98/nocfree_lite_65_wirelessly_mode_input_delay/)).
- **& only.** The & uses `Fn+M`/`Fn+N` for Mac/Windows mode and "the position
  of FN changes between the two systems"
  ([kbd.news](https://kbd.news/NocFree-review-2892.html)); its BLE channels
  have different Bluetooth addresses, which broke address-pinned Karabiner
  device matching after sleep ([tkhashi ADR](https://github.com/tkhashi/dotfiles));
  F3 sent the wrong usage until remapped in Link
  ([greenheadHQ](https://github.com/greenheadHQ/nixos-config)); v2.3.0 claims
  "Improved typing stability when using faster key repeat settings on macOS"
  ([changelog](https://www.nocfree.com/pages/link-changelog)). None of this
  applies to the Lite.
- **Mac-user switch choice.** The vendor recommended the silent switch to a
  MacBook Air user ([report, ~Jun 2026](https://www.reddit.com/r/Nocfree/comments/1u8ct6i/which_nocfree_switch_for_a_longtime_macbook_user/)).

## Wireless and reliability notes

### Lite

- **Latency and stuck repeat over 2.4G.** "Noticeable latency to the point
  that it is difficult to use" on a MacBook; a second user: "it just writes
  'eeeeeeeeeeeeeeeeeeee' until I stop it"; a third: "only really got worse
  after my return window ended"; a fourth: "Feels laggy and choppy"
  ([reports, ~May 2026](https://www.reddit.com/r/Nocfree/comments/1sv9h98/nocfree_lite_65_wirelessly_mode_input_delay/)).
  A prospective buyer had "read some bad reviews on the Lite's wireless
  connectivity" ([report, 2025](https://www.reddit.com/r/Nocfree/comments/1mn6017/nocfree_lite_or/)).
- **Counter-reports.** "The 2.4GHz connection has been rock-solid so far"
  ([report, late 2025](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/));
  "two Lites that I've used for over two years... pretty much bulletproof"
  ([report, ~Sep 2026](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w81gfz/nocfree_is_simply_not_a_good_keyboard/));
  "the NocFree Lite offers true wireless connectivity... with a low latency
  that's perfect for work" ([Medium, Nov 2024](https://leowu507.medium.com/a-personal-journey-to-ergonomic-comfort-nocfree-lite-keyboard-review-a5209e5defb9)).
- **Vendor fixes offered.** Move the dongle off hubs, away from metal,
  "a USB 2.0 port may offer better wireless stability than USB 3.0", turn off
  idle Bluetooth devices
  ([vendor, ~Mar 2026](https://www.reddit.com/r/Nocfree/comments/1rd83yp/quick_wireless_troubleshooting_steps/)).
  A month later the sleep-recovery post says "Prefer a USB 3.0 port"
  ([vendor, ~Apr 2026](https://www.reddit.com/r/Nocfree/comments/1sb5yg3/how_to_fix_wireless_mode_not_recognized_after/)).
  The dongle firmware post promises "we will arrange a replacement unit" if
  flashing does not help
  ([vendor, 2026-03-17](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)).
- **Mass-storage enumeration.** On an underpowered hub the Lite can enumerate
  as a "Mass Storage Device" and get blocked by corporate USB policy; the
  vendor's answer is a direct port, 2.4G, or a powered hub
  ([vendor, ~May 2026](https://www.reddit.com/r/Nocfree/comments/1taunq0/qa_nocfree_lite_detected_as_mass_storage_device/)).
  Read with the UF2 finding above, this is the bootloader's drive showing up.
- **Hardware failure.** "The left half of my NocFree Lite stopped working
  after a month of use"
  ([report, ~Jun 2026](https://www.reddit.com/r/Nocfree/comments/1ub872h/nocfree_feedback/),
  repeated by the same user in the & thread).
- **Battery.** No readout; "a full charge can last up to six months"
  ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).
  No owner report contradicts or confirms the figure.
- **Dongle.** USB-A with a magnetic recess under the right half
  ([report](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/));
  no multi-channel, and a second dongle receives the same input
  ([FAQ](https://www.nocfree.com/pages/nocfree-faq)). One owner keeps it in
  a dock and switches computers by switching the dock
  ([vendor story](https://www.nocfree.com/blogs/news/sarim-nocfree-lite-split-ergonomic-keyboard));
  a prospective buyer wanted a dongle for the same reason, a monitor hub
  shared between machines
  ([report](https://www.reddit.com/r/ErgoMechKeyboards/comments/1upzgtd/looking_for_a_lowprofile_split_keyboard_with/)).

### & (for contrast)

The & has drawn more wireless complaints than the Lite and is patched monthly:
missed and stuck keys over 2.4G ([report, ~Aug 2026](https://www.reddit.com/r/Nocfree/comments/1vctxcd/the_dongle_has_horrible_connectivity_and_ruins/)),
a dongle that degrades when warm ([same thread](https://www.reddit.com/r/Nocfree/comments/1vctxcd/the_dongle_has_horrible_connectivity_and_ruins/)),
"I can barely go a few keystrokes without missing keystrokes" wired on macOS
([report, ~Aug 2026](https://www.reddit.com/r/Nocfree/comments/1veir2o/devs_your_firmware_needs_daily_updates_atm/)),
and "Patch 2.4 seems to have fixed the USB Dongle Issues" for one owner but
not another ([reports, ~Sep 2026](https://www.reddit.com/r/Nocfree/comments/1w5yscp/patch_24_seems_to_have_fixed_the_usb_dongle_issues/)).
The left half drains faster because its receiver "cannot be turned off"
([vendor](https://www.reddit.com/r/Nocfree/comments/1vlcjof/faq_battery_level_difference_between_left_and/));
with backlight on, "about 24 hours" ([vendor](https://www.reddit.com/r/Nocfree/comments/1u0yci7/faq_about_nocfree_battery_life/)).
Firmware updates have bricked boards, recovered by shorting pads with two
screwdrivers ([bulsuk, Aug 2026](https://www.bulsuk.com/2026/08/nocfree-ampersand-full-review.html),
[report](https://www.reddit.com/r/Nocfree/comments/1vbmha9/firmware_v230_issue/)).
Relevant to the Lite only as a forecast for V2, which moves to the same
"in-house solution + Link" stack.

## Physical mods

- **Wrist rest, 3D-printed.** "Simple wrist rest for the NocFree Lite split
  keyboard. Does not work for tenting", PLA, 108 g, 2.5 h, 33 downloads
  ([MakerWorld, notablesofa, 2025-11-03](https://makerworld.com/en/models/1955022-nocfree-split-keyboard-lite-wristrest)).
  The only printable part found anywhere.
- **Tenting.** Built-in legs tilt each half 7° from the centre
  ([The Phonograph](https://www.thephonograph.net/nocfree-lite-review/));
  the walnut palm rest has a magnetic riser matched to that angle (same
  source). An owner asked for lower-profile keycaps or a flatter angle while
  standing and was pointed at NuPhy or Keychron low-profile sets
  ([report, 2025](https://www.reddit.com/r/Nocfree/comments/1noimbv/keycap_height_and_angle/)).
  One owner is "a little worried [the legs] might break if I press too hard"
  ([vendor story](https://www.nocfree.com/blogs/news/sarim-nocfree-lite-split-ergonomic-keyboard)).
- **Switch swaps.** MX hot-swap. One owner moved Gateron Pro Browns from a
  Q11 and found the stock switches "seated really tight"; the supplied switch
  puller "bends and slips"
  ([report](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/),
  [Medium](https://leowu507.medium.com/a-personal-journey-to-ergonomic-comfort-nocfree-lite-keyboard-review-a5209e5defb9)).
  Stock silent switches are Outemu ([The Phonograph](https://www.thephonograph.net/nocfree-lite-review/)).
- **Keycaps.** Both spacebars are 2.25u ([vendor, ~Mar 2026](https://www.reddit.com/r/Nocfree/comments/1rxx4qb/how_big_are_the_spacebar_keycaps/));
  the blank-key set is "2x 1u, 2x 1.25u, and 1x 1.75u"
  ([FAQ](https://www.nocfree.com/pages/nocfree-faq)). Cherry-profile
  shine-through PBT stock; one reviewer wanted a duplicated `B` on the right
  half ([The Phonograph](https://www.thephonograph.net/nocfree-lite-review/)).
  The KR layout has "dual B keys"
  ([vendor, ~Apr 2026](https://www.reddit.com/r/Nocfree/comments/1s5vd4u/nocfree_at_the_2026_seoul_mechanical_keyboard_expo/)).
- **One-handed use.** A reviewer's suggestion, not a report: use the left half
  alone "as a dedicated gaming keypad"
  ([The Phonograph](https://www.thephonograph.net/nocfree-lite-review/)).
- **Foam.** The sound-absorbing foam add-on is recommended by one owner
  ([Medium](https://leowu507.medium.com/a-personal-journey-to-ergonomic-comfort-nocfree-lite-keyboard-review-a5209e5defb9))
  and can block the RGB LEDs
  ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)).

## Open complaints and vendor responses

| Complaint | Model | Vendor response |
| --- | --- | --- |
| `/?` and right Shift placement ([Gadgeteer 2023](https://the-gadgeteer.com/2023/12/12/nocfree-lite-60-compact-split-wireless-mechanical-keyboard-review/), [YAL-Tools](https://github.com/YAL-Tools/ergo-keyboards), [r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1mn6017/nocfree_lite_or/)) | Lite | "We've gotten a lot of feedback about the '?' key placement, so we're definitely adjusting it for V2" ([vendor, ~Sep 2026](https://www.reddit.com/r/Nocfree/comments/1vwnzzw/nocfree_lite_v2_progress_update/)). 2023: "Danbin" promised production improvements ([Gadgeteer comment](https://the-gadgeteer.com/2023/12/12/nocfree-lite-60-compact-split-wireless-mechanical-keyboard-review/)). |
| 2.4G latency and stuck keys ([r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1sv9h98/nocfree_lite_65_wirelessly_mode_input_delay/)) | Lite | Troubleshooting posts and a dongle `.uf2`; replacement if that fails ([vendor](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)). No reply in the input-delay thread itself. |
| Four layers is too few ([r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1qt7qnk/is_there_any_way_to_increase_the_amount_of_layers/)) | Lite | "The NocFree Lite currently supports up to 4 layers... our new model will support up to 8 layers" (the &). |
| No firmware source | Lite, & | Lite: never addressed publicly. &: "no plans to open source the customization side" ([vendor](https://www.reddit.com/r/Nocfree/comments/1tep0zh/software_options_to_customize_nocfree/)); the ZMK repo README repeats that factory firmware is not open source ([NocFreeKB](https://github.com/NocFreeKB/NocFree-and-zmk)). A user offered "about 100 devs here (include me) would happily submit a pull request to improve battery life" ([report](https://www.reddit.com/r/Nocfree/comments/1vlcjof/faq_battery_level_difference_between_left_and/)); no answer. |
| No Bluetooth, dongle is USB-A ([Phonograph](https://www.thephonograph.net/nocfree-lite-review/), [r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/)) | Lite | Lite V2 adds Bluetooth ([vendor](https://www.reddit.com/r/Nocfree/comments/1vwnzzw/nocfree_lite_v2_progress_update/)). |
| RGB off in wireless, no way round it ([Phonograph](https://www.thephonograph.net/nocfree-lite-review/)) | Lite | Documented as intended ([troubleshooting](https://www.nocfree.com/pages/nocfree-lite-troubleshooting)). |
| Left half died after a month ([r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1ub872h/nocfree_feedback/)) | Lite | None visible. |
| Limited colours ([r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1o8ehne/been_dallying_the_nocfree_for_about_a_month_so/)) | Lite | V2 survey asks about White, Black, Midnight Blue, Pink ([survey](https://www.nocfree.com/pages/lite-v2-feedback)). |
| Keyboard-only in corporate IT lockdown; "whether via even works" ([r/ErgoMechKeyboards, 2024](https://www.reddit.com/r/ErgoMechKeyboards/comments/1gpwrs1/recommendation_for_colleague_for_work_whos_had/)) | Lite | Not addressed; the firmware-level keymap means no software is needed after setup. |
| Jerrzi switch footprint, tenting kit, charging, shipping delays, bricking, left-battery drain ([1Project](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w81gfz/nocfree_is_simply_not_a_good_keyboard/), [bulsuk](https://www.bulsuk.com/2026/08/nocfree-ampersand-full-review.html), [r/Nocfree](https://www.reddit.com/r/Nocfree/comments/1vlcjof/faq_battery_level_difference_between_left_and/)) | & | Monthly firmware, a "Firmware Care" app, one-to-one Discord support, "this is actually normal behavior" on battery. Reviewers rate support fast and direct ([bulsuk](https://www.bulsuk.com/2026/08/nocfree-ampersand-full-review.html)). |

Sponsorship note: the most-cited negative & review says "Most of what I found
before purchasing was sponsored YouTube content, which NocFree leans on
heavily" ([1Project](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w81gfz/nocfree_is_simply_not_a_good_keyboard/)),
and calls the kbd.news review, written on a vendor-supplied tester unit,
sponsored too. Treat YouTube and vendor-blog praise accordingly.

## Ideas worth stealing for Prateek's setup

Ranked by how much they help a left-hand navigation layer, layer indication,
and host-visible layer state on a Vial board with two keymaps.

1. **Own the layer on the host, not in the firmware.** The only documented
   Lite power user went Vial → `keyd` so the same chords work "on all my
   keyboards"; the Karabiner equivalent survives the Lite's two-keymap split
   and the V2's loss of Vial
   ([BAUDR8](https://www.reddit.com/r/ErgoMechKeyboards/comments/1w804i0/replacing_the_mouse_with_keyboard/)).
   This matches the firmware doc's conclusion that the layer must live where
   macOS can see it.
2. **Test tap-hold through the dongle before committing.** The vendor itself
   lists "home row mods not triggering correctly, or light taps being
   registered as long presses" as a wireless-mode fault
   ([vendor](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)).
   Any `LT`/`MT` plan needs the firmware doc's check 4 run over 2.4G, not
   just on the cable.
3. **Sync wired and wireless keymaps by editing the `.vil` UID.** Export from
   one device, change the top-of-file ID to the other UID
   (`7369517445122672664` wired, `8481673586147325631` 2.4G), import
   ([daniel-weck](https://www.reddit.com/r/Nocfree/comments/1nssciz/nocfree_lite_my_positive_experience_so_far/),
   [musgravej](https://github.com/musgravej/keyboard-config)). Cheap to script.
4. **Reuse a working raw-HID client.** `choijhyeok/my-key-mapping` already
   opens the Lite over `0xFF60`, queries the unlock state, and writes keys
   ([repo](https://github.com/choijhyeok/my-key-mapping)). It answers the
   firmware doc's questions 8 and 9 with code rather than a throwaway script,
   and could drive `vialrgb_direct_fastset` if the lighting probe says yes.
5. **Caps-hold nav on IJKL with `hold-preferred`.** mathiasi's reasoning
   about tap-preferred costing a 200 ms wait per arrow applies to Vial's
   tap-hold settings too, if the QMK Settings tab exists
   ([mathiasi](https://github.com/mathiasi/nocfree-and-zmk-config)). The
   vendor's own suggestion is the same cluster on the Fn key
   ([Vial guide](https://www.nocfree.com/blogs/news/get-the-most-out-of-nocfree-lite-with-vial)).
6. **Fix `/?` with a tap dance, not a keycap swap.** `TD(0)`: right Shift on
   tap-hold, `/` on double tap ([musgravej](https://github.com/musgravej/keyboard-config));
   or just swap `/` and right Shift as the database suggests
   ([YAL-Tools](https://github.com/YAL-Tools/ergo-keyboards)).
7. **`Shift+Space` combos for brackets** and a second layer on `TD` hold of
   `F` ([musgravej](https://github.com/musgravej/keyboard-config)); `LT` on
   Caps and both thumbs with Hyper on a spare thumb
   ([llan0](https://github.com/llan0/configs)).
8. **Bootloader leads for the firmware doc's check 10.** Stock layer 2 has
   `RESET` top-right ([exports](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498));
   the dongle mounts a drive on `Fn+Space+Backspace`
   ([vendor](https://www.reddit.com/r/Nocfree/comments/1rvwwij/nocfree_firmware_update_how_to_solve_wireless_key/)).
   Either would confirm the bootloader family without opening the case.
   Export both keymaps first.
9. **Keep the stock Mac/Win swap keys off the layer you use.** `Fn+I`/`Fn+O`
   flip Alt and Gui in EEPROM; an accidental press looks like a broken
   keymap ([exports](https://github.com/ThatNerdSquared/dotfiles/commit/c4c02498)).
10. **Print the wrist rest if the walnut one is not around**
    ([MakerWorld](https://makerworld.com/en/models/1955022-nocfree-split-keyboard-lite-wristrest)).

## Coverage

What was read, what was not.

- **nocfree.com**: every page, product, and blog post in the sitemap (23 + 16
  + 14), `products.json`, the & firmware PDF and v2.4.5 zip, the Lite
  quick-start JPGs transcribed. Not read: `/ja/` mirrors, Korean PDF and
  JPGs, embedded YouTube videos, `link.nocfree.com`.
- **GitHub**: repo, code, commit, issue, and PR search across 40+ queries;
  every distinct repo's README, keymap, issues, and releases. GitLab and
  Codeberg returned nothing.
- **Reddit**: 80 threads from site search and r/Nocfree searches on 29
  terms, read in a browser tab; r/Nocfree, r/ErgoMechKeyboards,
  r/MechanicalKeyboards, r/logseq, r/sysadmin, r/adhdwomen. Site-wide search
  surfaced no threads from r/splitkeyboards or r/olkb.
- **Reviews and blogs**: The Gadgeteer (Lite, 2023), The Phonograph (Lite),
  Medium (Lite, 2024), petems (Lite, 2026), kbd.news (&), bulsuk ×3 (&),
  green-keys.info (Lite V2), KeebTalk Kickstarter thread (2023: vendor said
  "VIA", a user asked "No QMK and VIA support?").
- **Hacker News**: one comment, a happy owner in a split-keyboard thread
  ([2026-02](https://news.ycombinator.com/item?id=47088627)).
- **YouTube**: titles and channels only, via oEmbed (Kephren, CalmCode,
  Chris Parker, Chyrosran22 for the Lite; DeveloperAdam, Daihuku for the &).
  Not watched.
- **MakerWorld**: one model. Printables and Thingiverse: no hits in a
  domain-restricted web search.
- **geekhack**: zero results in search.
- **X**: search-indexed only; vendor promotion plus two Japanese reviewer
  links (Daihuku). Not read.
- **Discord**: invite-only, not read. Vendor posts name a
  `firmware-auto-update-app-test` channel and staff "Eva" and "Emma".
- **Amazon, Walmart, Kickstarter comments**: not fetched.
- **Prateek's own repos** (`prateek/dotfiles`, `prateek/keyplane`) appeared
  in GitHub search and were excluded as not independent.
