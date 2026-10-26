# EX201 Studio

This started as part of a speaker build. The EX201 board had the EQ and DSP
controls I wanted, but I couldn't get past the Android app's login screen.
I wanted to tune the board from Linux and understand what each setting did.

EX201 Studio is the result: a Flutter app that talks to the board over
Bluetooth, with visual EQ controls, explanations, presets and backups.
Everything runs locally, and no vendor account is needed.

**Made with OpenAI Codex.** Codex did much of the protocol investigation,
implementation and testing, including the move from the first Python/web
version to Flutter and Dart. I supplied the hardware and product information,
helped with the physical power-cycle checks, and tried the controls on the board.

![EX201 Studio equalizer — labelled demo workspace](screenshots/equalizer.png)

## How we got the Bluetooth controls working

The starting point was the JavaScript bundled with the manufacturer's
[YOULI Android client](https://likeyou168.cn/YOULI/download-center.html).
Codex inspected it to find the BP10 command format, Bluetooth services and
parameter controls. We then checked those findings against the actual EX201.

The useful discovery was how to get a reply. The board exposes an `AB00`
control service and an `AB01` read/write characteristic. Notifications alone
weren't giving us the responses we needed: after writing a command, we had
to wait briefly and **explicitly read AB01**. That gave us a reliable way to
ask for the firmware, effect catalogue and parameter blocks.

From there, we worked through the parameter scales and write commands one
control at a time. Some settings are individual words; others, such as the
DRC thresholds, are written as a group. Changing one path therefore means
preserving the other values in that group. Each test read the whole block
back and restored the previous settings afterwards. We also checked that
the board's save command survived a physical power cycle.

That research became the first Python/Bleak controller. This version carries
the protocol over to Dart and talks to Linux BlueZ directly. The cloud login
and local Bluetooth controls turned out to be separate, so the desktop app
can work without the vendor login.

The main pieces are [message framing](lib/domain/protocol.dart),
[Bluetooth transport](lib/infrastructure/bluez_transport.dart), and the
[controller and readback checks](lib/application/controller.dart).

## Install

Download `EX201-Studio-1.0.0-x86_64.flatpak` from
[Releases](https://github.com/big-yellow-duck/ex201-studio/releases), then open it
with your software manager, or run:

```sh
flatpak install --user EX201-Studio-1.0.0-x86_64.flatpak
flatpak run io.github.big_yellow_duck.EX201Studio
```

The x86_64 bundle uses the Freedesktop 26.08 runtime from Flathub. It requests
the display, graphics acceleration and access to the host BlueZ service.
It has no network or general home-directory access. Import/export uses the
desktop file chooser; backups stay in the application’s data directory.

## Using it

1. Connect the board’s **BLE control device**, then read its settings.
2. Export a preset before changing your tuning.
3. Edit a filter or explore a lesson. All effect edits remain local drafts.
4. **Apply changes** sends a draft and verifies the complete returned block.
5. **Store on board** retains the applied DSP tuning across power-off.

The separate Bluetooth audio link is managed through Linux’s normal audio
settings. Use one controller application at a time.

You can explore every editor without hardware:

```sh
flatpak run io.github.big_yellow_duck.EX201Studio --demo
```

Close an existing instance before launching the demo action. The amber demo
banner marks a separate in-memory transport; it never connects to Bluetooth.
Demo backups are kept separately from real-board backups.

## What it can do

- All **19 discovered DSP blocks and 401 typed controls**, including six ten-band EQs.
- Draggable EQ handles, exact numeric values, selected-band and combined curves,
  preamp and an estimated peak-boost/headroom note.
- Nine filter shapes with explanations and a local interactive explorer.
- Full-band and multiband dynamics with transfer/timing illustrations and active-path guidance.
- Gain/mute, noise suppression, virtual bass, 3D spatial, widening, exciter and polarity.
- Master volume/mute, three board preset slots and last-read DSP diagnostics.
- Compatible v2 preset files, older EQ-only snapshots, automatic backups and recovery.
- A searchable beginner guide, staged edits and a compact learning-off view.

![Filter explorer](screenshots/filter-explorer.png)

## Supported hardware and limits

Hardware verification used an **EX201 / seller EX201MAX**, BP10_B1, firmware
0.3.1, library 2.30.0. The EX202 and other firmware profiles have not been
hardware-tested. Remote input selection and renaming are unavailable when
the firmware returns no status. TWS, firmware updates and factory reset are
outside this application’s scope.

The charts are teaching models: EQ assumes 48 kHz; dynamics uses ideal
transfer/timing examples; proprietary effect pictures are conceptual.
They are not measurements of the board, amplifier, enclosure or speaker,
and do not constitute a speaker-protection or crossover design.

## Build and check

Pinned toolchain: **Flutter 3.47.8 / Dart 3.13.7**. Install Flutter’s Linux
desktop prerequisites, then:

```sh
flutter pub get
flutter test
flutter analyze
flutter build linux --release
```

`tools/in-sdk.sh` runs Flutter in the Freedesktop 26.08 SDK with LLVM 22,
which is useful on immutable distributions such as Bazzite. Set
`EX201_FLUTTER_SDK` when Flutter is not on your PATH.

For the installable Flatpak:

```sh
flutter precache --linux
tools/build-flatpak.sh
```

The preparation step snapshots the pinned SDK and package cache, verifies the
Flutter commit, and records checksums. The actual Flatpak build resolves
dependencies offline and compiles in its SDK sandbox. Build inputs under
`.flatpak-deps/` are not bundled with the installed application.

## Validation

The tests compare **1,436 parameter plans** with the original Python reference,
including encoding and grouped-write order. Controller tests exercise preset
compatibility, invalid input, full-block readback, failure recovery, volume,
mute and all preset selectors through an explicit simulator. UI checks cover
all editors, local learning drafts, and narrow windows.

Physical EX201 checks verified temporary cuts in already-bypassed EQ, DRC and
gain blocks, restored the original values, and matched all 19 blocks against
the handoff snapshot. The installed Flatpak also read all 401 controls through
its sandboxed BlueZ connection. No flash save or preset switch was used in
these physical migration checks. A sanitized report is in
[docs/validation.json](docs/validation.json).

The original Python/web implementation is preserved alongside this project
in the original workspace; it is not needed to build or run this edition.
The protocol definitions and reference vectors were carried forward from that
implementation and manufacturer-client research.

See [README.txt](README.txt) for the full operating, storage and build reference.
Application source is MIT licensed. Manrope is distributed under the
[SIL Open Font License](assets/fonts/OFL.txt); Flutter bundles dependency notices.
