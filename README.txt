EX201 STUDIO 1.0.0 — NATIVE FLUTTER / DART EDITION

A local desktop controller for EX201 / seller EX201MAX Bluetooth DSP boards.
The interface and controller are implemented in Dart. The runtime does not
start a Python process, web server or browser. BlueZ supplies Linux Bluetooth.

INSTALL THE FLATPAK BUNDLE
  flatpak install --user EX201-Studio-1.0.0-x86_64.flatpak
Open EX201 Studio from your applications menu, or run:
  flatpak run io.github.big_yellow_duck.EX201Studio
Flathub must be configured to obtain the org.freedesktop.Platform 26.08
runtime. The application bundle targets Linux x86_64. Other architectures
and operating systems have not been packaged or hardware-tested here.

FIRST SESSION
1. Power on the EX201 and close other apps controlling its BLE interface.
2. Choose Connect, then scan for the BLE control device. You can also enter
   its Bluetooth address. The separate audio device is selected through
   Linux's normal Bluetooth/audio settings.
3. Read board settings and export a preset before changing your tuning.
4. Edit an effect. Every switch and numeric control is a local draft.
   Apply changes sends the draft and checks the complete returned block.
5. Store on board saves applied DSP settings in the selected preset slot
   across power-off. Export keeps a separate recovery file on your computer.

The last successfully connected board is remembered for the next launch.
The control connection is independent from Bluetooth audio playback.
The app neither plays nor records audio and needs no vendor account.

DEMO / LEARNING TOOLS
Choose Explore a demo workspace, or use the app-menu demo action:
  flatpak run io.github.big_yellow_duck.EX201Studio --demo
The demo uses a separate in-memory transport. Its amber banner explicitly
marks simulated controls. It never creates a BlueZ client or writes hardware.
The beginner guide, filter explorer and all effect editors work in demo mode.
Return to real hardware using the sidebar action.

The EQ chart shows enabled draft bands, their combined response and preamp.
Drag a handle to change its frequency (and gain for bell/shelf filters), or
use exact numeric values. Band chips select the detailed controls. The
explorer explains all nine filter types and can copy an example into a band
draft. Flat starting point stages ten neutral bell filters and bypass.
Neither operation changes hardware until Apply changes.

DRC pictures illustrate threshold/ratio and timing. The active mode identifies
which stored paths are used. The 4:1 lesson fills a draft only. Noise, gain,
polarity, bass and spatial panels include related visual explanations.
Learning mode can be hidden for a more compact editor. The guide includes
a glossary, every effect, output-path notes and troubleshooting.

SCOPE / MODEL LIMITS
All 19 discovered blocks and 401 typed controls are represented: six EQs,
two dynamics blocks, three gain/mute blocks, noise suppression, 3D spatial,
music/DACX virtual bass, classic virtual bass, stereo widening, exciter and
polarity. Master volume/mute, three board slots, diagnostics, import/export,
automatic backups and recovery are included.

EX201 firmware 0.3.1 returns empty results for the known input-selection and
renaming queries. Those controls are shown as unavailable. The EX202 has
not been hardware-tested. TWS remains excluded at the owner's request.
There is no firmware-update or factory-reset function.

EQ charts use standard filter equations at an assumed 48 kHz, not a measured
speaker response. Dynamics curves use ideal models without a measured knee,
detector or envelope. Proprietary effect illustrations are conceptual.
The headroom estimate excludes source level and other DSP blocks.

PRESETS & DATA
Full v2 preset files from the Python reference are compatible when device
identity, firmware and block layouts match. Older EQ-only snapshots are
also accepted; unspecified effects are preserved. Import/restore changes
DSP parameters in the current slot, not volume or preset-slot selection.
Store on board is still required for power-off persistence.

The controller saves snapshots before/after edits and checks whole-block
readback after each group. Failed edits attempt to restore the preceding
block. Failed multi-effect imports attempt to restore all affected blocks.

App data uses XDG_DATA_HOME/ex201-studio. In the installed Flatpak this is:
  ~/.var/app/io.github.big_yellow_duck.EX201Studio/data/ex201-studio/
settings.json contains local preferences and the last BLE board address.
backups/ contains recovery presets; protocol-trace.jsonl records requests
and replies for diagnosis. No source-directory write access is required.
Files chosen for import/export use the desktop file chooser.

REFERENCE IMPLEMENTATION
The existing Python/web app remains at ../ex201/ with its source files
unchanged. reference-hashes.json records the starting reference source hashes.
Use one controller at a time: close the Flutter app before starting the
reference ex201-eq.service, and stop that service before connecting Flutter.
Do not operate both controllers against the same board simultaneously.

BUILD FROM SOURCE
Pinned SDK: Flutter 3.47.8 (commit 737ba8f885dc774b53b442759999a312c9461e4e),
Dart 3.13.7. The pubspec.lock pins Dart/plugin packages.
  flutter pub get
  flutter precache --linux
  flutter test
  flutter analyze
  flutter build linux --release

On this Bazzite machine, tools/in-sdk.sh invokes Flutter inside the installed
Freedesktop SDK 26.08 + LLVM 22 extension, supplying GTK and compiler headers.
Set EX201_FLUTTER_SDK to use another SDK location. Required development
Flatpaks: org.freedesktop.Sdk//26.08 and its llvm22 extension.

BUILD A DISTRIBUTABLE BUNDLE
  tools/build-flatpak.sh
prepare-flatpak.py snapshots the pinned local SDK and pub cache into
.flatpak-deps/ and pins their checksums in the manifest. The Flatpak build
then resolves packages offline and compiles the app in its SDK sandbox.
The build does not depend on Python at application runtime.
Do not distribute .flatpak-deps/ as application files: they are build inputs.

The result is dist/EX201-Studio-1.0.0-x86_64.flatpak with SHA256SUMS.
The manifest, desktop entry, icon, AppStream metadata and licenses are in
packaging/. Publishing to a public repository/Flathub is a separate action;
no public repository or verified publisher identity is assumed here.

VALIDATION
test/domain_test.dart compares 1,436 parameter plans against the reference,
including quantization and grouped-write ordering. It also checks frame
parsing, ranges, board decoding and known chart properties.
test/controller_test.dart checks complete catalogue coverage, grouped writes,
EQ enable ordering, preset compatibility/rejection, failure recovery, volume,
mute and all three preset selectors using an explicitly simulated transport.
test/ui_test.dart exercises all editor pages, local learning drafts and
responsive layouts; screenshots/ holds rendered interface previews.
Physical-board and packaged-runtime results are recorded in docs/.

LICENSES
Application source: MIT (LICENSE). Manrope font: SIL Open Font License
(assets/fonts/OFL.txt). Flutter and Dart package licenses are bundled by
Flutter in the application assets. Bluetooth protocol definitions are derived
from the manufacturer-linked client and prior readback research, referenced
in the preserved implementation's manual.
