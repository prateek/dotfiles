---
status: active
doc_type: runbook
owner: Prateek
created: 2026-06-20
updated: 2026-06-20
---

# USB-C cable audit

This runbook drives a hands-on audit of a pile of unlabeled USB-C cables. It
captures each cable's speed class, power rating, generation, vendor, and
(optionally) Thunderbolt 5 capability into per-cable files plus a master
inventory. It is built around the `whatcable` CLI and Prateek's current Macs.

The work is a guided loop: an agent instructs the operator to plug a specific
cable into a specific "station," runs `whatcable` captures, interprets the
output, records a verdict, and moves to the next cable. The agent cannot plug
cables itself, so it always describes the physical connection and waits.

Use it when sorting a drawer of mystery cables, verifying one cable's rating, or
deciding keep vs toss.

## Prerequisites

- `whatcable` >= 1.1.0 (`brew install whatcable`). Apple Silicon, macOS 14+.
- Run the agent **on the M4 Pro MacBook Pro**. It is the only machine here that
  charges as a power sink, so it is the only one that can do the >3A power read.
- A 60W+ USB-C charger (the laptop brick is ideal), the Satechi USB4 NVMe SSD,
  and — only for TB5 checks — the M3 Ultra Mac Studio.

## Hardware this assumes

The prompt below encodes specific machines and their Thunderbolt tiers. Update
the prompt if the hardware changes.

| Device | Thunderbolt | Role in the audit |
| --- | --- | --- |
| MacBook Pro M4 Pro | TB5 / up to 120G | Host that runs the audit; only machine for the power station |
| Mac Studio M3 Ultra (2025) | TB5 / up to 120G | Second TB5 host — the only way to prove a cable does >40G |
| Satechi USB4 NVMe SSD | USB4 / 40G | Data + TB-link station |
| CalDigit TS4 dock | TB4 / 40G | Alternate TB-link station |
| Mac mini M4 (base) | TB4 / 40G | Not needed; cannot do the power read |
| MacBook Pro M3 Pro | TB4 / 40G | Not TB5; not a TB5 endpoint |
| iPad Pro M4 | TB4 / 40G | Data-speed only; never a power source |

## How to use it

Copy the prompt below into an agent (Claude Code or similar with shell + file
access) running on the MacBook Pro, then follow its instructions. It works one
cable at a time and pauses for you to physically swap cables and confirm.

## Agent prompt

````markdown
# USB-C Cable Audit — Operator Brief

You are driving a hands-on audit of a pile of unlabeled USB-C cables on macOS, using the
`whatcable` CLI plus the operator's hardware. You CANNOT plug cables yourself — you instruct
the operator (Prateek), wait for confirmation, then run captures and interpret them. Work ONE
cable at a time. Be patient and explicit about every physical connection.

## 0. Pre-flight (run once, before any cable)

1. Confirm `whatcable` is installed: `whatcable --version` (expect >=1.1.0). If missing, stop
   and tell the operator to `brew install whatcable`.
2. Confirm you are on the right host — the audit's power test ONLY works on the laptop:
   `system_profiler SPHardwareDataType | grep -E "Model|Chip"`
   Expect "MacBook Pro" + "Apple M4 Pro" (Thunderbolt 5, up to 120 Gb/s). If you're on a
   desktop Mac, warn that the power station won't work there.
3. Snapshot Thunderbolt + USB topology for the record:
   `system_profiler SPThunderboltDataType SPUSBDataType > ~/cable-audit/_host-topology.txt`
4. Create the output tree (see section 4) and write `README.md` summarizing this methodology.
5. Ask the operator to have physical labels ready (masking tape / cable tags) and a pen, so
   each cable gets tagged with its ID as it's tested.

## 1. The hardware you can use as "the other end"

| Station device | Role | TB/USB4 | Notes |
|---|---|---|---|
| 60W+ USB-C charger (laptop brick) | power-draw trigger | n/a | Charges INTO the MacBook; the only way to read a charging cable's e-marker |
| Satechi USB4 NVMe SSD (Samsung 990 PRO) | data + TB-link trigger | 40G | Reads e-marker via the USB4 link AND grades real data speed |
| Mac Studio (M3 Ultra, 2025) | TB5 endpoint | 80/120G | Second physical TB5 host — the ONLY way to prove a cable does >40G |
| CalDigit TS4 dock | alt TB-link trigger | 40G | Equivalent to the Satechi for triggering; usually tucked away — prefer the SSD |

Out of scope (don't suggest): iPad/iPhone as a power source (wrong direction), port-to-port
loopback (no link trains), or a VM as the far end (bits never cross the wire).

## 2. How the signals actually get read (the rules)

- macOS reads a cable's **e-marker chip** (-> rated power, speed class, vendor, active/passive)
  ONLY when the connection forces it: **charging above 3A**, OR a **Thunderbolt/USB4 link**.
- A cable's **real data speed** comes from the **negotiated link** with a fast device.
- **"No e-marker detected" is NOT a failure** — it's normal for <=3A / USB-2 / charge-only
  cables, or means the connection didn't trigger a read. Re-test on the right station before
  concluding anything.
- Every measurement is capped by the **slowest endpoint**. The Satechi/TS4 are 40G, so a 40G
  result there does NOT distinguish a TB4 cable from a TB5 cable — only the Mac<->Studio station
  can. Negotiated rate = min(cable, host, device).
- **Power rating is only trustworthy from the e-marker.** If there's no e-marker, power is
  UNKNOWN — do not guess it from the connector or thickness.

## 3. The three stations (instruct the operator, then capture)

### Station A — Data + identity (default; resolves most cables)
Connection: **MacBook Pro USB-C port -> cable under test -> Satechi USB4 SSD.**
Disconnect other peripherals from the ports in use so the test port is unambiguous.
Reveals: speed class + power rating + maker (e-marker, for TB/USB4 cables), and the real data
link rate for everything (USB-2 480M -> USB4 40G). The SSD also enables a throughput benchmark.

### Station B — Power (only if Station A showed no e-marker AND the cable might be a high-power charger)
Connection: **60W+ charger -> cable under test -> MacBook Pro USB-C port.**
Preconditions you MUST verify first:
- **Unplug MagSafe** (else the Mac won't draw >3A through the test cable).
- Battery below ~95%: `pmset -g batt`. If higher, tell the operator to run the battery down or
  do other cables first; otherwise you'll see "negotiation hasn't completed yet" and no read.
Reveals: the e-marker on 5A charging cables, including non-Thunderbolt ones, plus the charger's
PD contract / PDOs.

### Station C — TB5 verdict (only if a cable maxed Station A at 40G AND its TB5 status matters)
Connection: **MacBook Pro M4 Pro -> cable under test -> Mac Studio M3 Ultra** (both TB5).
Reveals: the negotiated link rate. **80/120 Gb/s -> genuine TB5 cable; 40 Gb/s -> TB4 ceiling.**
Note in results: this proves the cable can *train* a TB5 link; it is not a sustained-80G
throughput test (Thunderbolt Bridge IP networking caps below line rate — that's the network
stack, not the cable).

## 4. Output layout (create under `~/cable-audit/`)

```
~/cable-audit/
  README.md              # this methodology, plus "how to read these files"
  inventory.md           # master table — ONE row per cable (schema in section 6)
  _host-topology.txt     # system_profiler dump from pre-flight
  cables/
    C01/
      whatcable.json     # whatcable --json  (note the relevant port object in notes.md)
      whatcable.txt      # whatcable          (human-readable)
      whatcable.raw.txt  # whatcable --raw    (IOKit props, full record)
      report.md          # whatcable --report (only if the cable is e-marked)
      benchmark.txt      # optional throughput (Station A) — see section 5
      notes.md           # physical description, which station(s) used, port id, verdict
    C02/ ...
```

## 5. Per-cable procedure

For each cable, assign the next ID (C01, C02, ...) and:

1. **Describe & label.** Ask the operator for: color, length, connector markings / printed text /
   any brand. Have them stick the ID label on the cable now. Record this in `cables/<ID>/notes.md`.
2. **Baseline.** Run `whatcable --json` and note current ports, so you can spot the test port
   after plugging.
3. **Station A.** Instruct the exact connection (section 3 A). Wait for "done." Then capture:
   ```
   D=~/cable-audit/cables/<ID>; mkdir -p "$D"
   whatcable           > "$D/whatcable.txt"
   whatcable --json    > "$D/whatcable.json"
   whatcable --raw     > "$D/whatcable.raw.txt"
   whatcable --report  > "$D/report.md" 2>/dev/null || true
   ```
   Identify the test port (the one now showing the Satechi SSD / the port that changed vs
   baseline). Read off: e-marker present?, speed class, power rating, vendor, active/passive,
   negotiated link rate, any bottleneck verdict.
4. **Decide if you need more stations:**
   - No e-marker + plausibly a charging cable -> **Station B**, re-capture (append, don't
     overwrite — suffix files `.stationB`).
   - Hit 40G on A and TB5 status matters -> **Station C**, capture link rate (`.stationC`).
   - Resolved already (e.g., clearly USB-2 480M charge cable, or e-marker fully read) -> done.
5. **(Optional) Throughput**, Station A only, if the operator wants real GB/s: prefer
   **AmorphousDiskMark** (GUI, accurate) and paste results into `benchmark.txt`. Quick CLI
   alternative (note macOS caching makes this approximate; use a file larger than RAM):
   `dd if=/dev/zero of=<ssd_mount>/_sdtest.bin bs=1m count=40000` then read it back with
   `dd if=<ssd_mount>/_sdtest.bin of=/dev/null bs=1m`; delete the file after. Capped at the
   SSD's ~40G link regardless of cable.
6. **Write the verdict** into `notes.md` and append a row to `inventory.md` (section 6).
7. **Next cable.** Tell the operator what to unplug/plug, and repeat.

## 6. `inventory.md` table schema (one row per cable)

| ID | Phys. description | E-marker? | Speed grade | Power grade | Vendor / brand | Active/Passive | Best observed link | TB5? | Verdict |
|----|-------------------|-----------|-------------|-------------|----------------|----------------|--------------------|------|---------|

Grading vocab to use consistently:
- **Speed:** USB 2.0 (480M) / USB 3.2 Gen1 (5G) / Gen2 (10G) / Gen2x2 (20G) / USB4 20G /
  USB4 40G / TB4-class / USB4v2 80G / TB5-class.
- **Power:** 60W (3A) / 100W (5A@20V) / 240W (5A@48V EPR) / unknown (no e-marker).
- **Verdict examples:** "Keep — 40G/100W TB4 cable" / "Charge-only USB-2, keep for power" /
  "Toss — USB-2 480M, no PD, frays" / "TB5 verified 80G".

## 7. Interaction rules

- One cable at a time. Always state the exact ports/devices to connect, then WAIT for the
  operator to confirm before running captures.
- Never conclude a cable is "bad" from a single station — apply section 2 (no-e-marker is normal;
  40G != not-TB5). Escalate stations as in section 5 before judging.
- Keep `inventory.md` updated after every cable so progress survives interruptions.
- At the end, print a summary: total cables, the keep/toss tally, any standout cables
  (TB5-verified, 240W, or surprising duds), and where the files live.
````

## Background: why each signal needs its own station

- macOS reads a cable's e-marker chip — which carries the rated power, speed
  class, vendor, and active/passive flag — only when the connection forces it:
  charging above 3A, or a Thunderbolt/USB4 link. A bare cable plugged into the
  Mac triggers neither, so it shows nothing.
- A cable's real data speed comes from the negotiated link with a fast device,
  so a cheap cable with no chip is graded by what link actually trains.
- Every reading is capped by the slowest endpoint. The Satechi SSD and TS4 dock
  are both 40G, so they cannot tell a TB4 cable from a TB5 one. Only a second
  TB5 host (the M3 Ultra Studio) proves a link above 40G.
- Dead ends that look clever but do nothing: an iPhone/iPad as a power source
  (the Mac becomes the source and caps near 15W, never crossing 3A), a cable
  looped between two ports of the same Mac (Thunderbolt forbids a loop in one
  host's fabric, so no link trains), and a VM as the far end (host-guest traffic
  stays in memory and never crosses the wire).

## Sources

- [whatcable](https://www.whatcable.uk/) and its [instructions](https://www.whatcable.uk/instructions)
- [ChargerLAB POWER-Z KM003C e-marker reading](https://www.chargerlab.com/e-marker-chip-detection-the-new-update-of-power-z-km003c/)
- [Thunderbolt 5 vs USB4 (Cable Matters)](https://www.cablematters.com/Blog/Thunderbolt/thunderbolt-5-vs-usb4)
