# Dependency Upgrade Notes

This document tracks outdated dependencies discovered while auditing the Linux
build, along with recommendations for future upgrade work. It is a planning
reference, not a changelog of completed work.

## 1. Qt: currently on Qt5 (5.15.13), not Qt6

The project is hard-pinned to Qt5 via `cmake/QtChooser.cmake`
(`find_package(Qt5 REQUIRED Core Widgets LinguistTools Xml Network
PrintSupport)`, plus `WebEngine WebEngineWidgets WebSockets WebChannel` and
`MacExtras` on macOS). The Linux build currently links against Qt
5.15.13 (Ubuntu 24.04's packaged version), which is the final Qt5 LTS release
— Qt5 itself is EOL upstream.

**Would Qt6 help?**
- Pros: continued security patches, better HiDPI/Wayland support, newer
  Chromium in QtWebEngine (security + modern JS/CSS), long-term ecosystem
  support.
- Cons / risks:
  - `QtWebEngine`/`QtWebEngineWidgets` init sequence and APIs changed
    meaningfully between Qt5 and Qt6; this app leans heavily on WebEngine for
    the note editor/viewer, making this the highest-risk area to port.
  - Deprecated APIs already surfaced as build warnings need fixing first,
    e.g. `QFlags(Zero)` constructor usage (`src/widgets/WizShareLinkDialog.h`)
    and `QWidget::setLayout` / `QFont::setPixelSize` warnings seen at runtime.
  - Legacy `qmake`-based `.pro` files (e.g. `src/src.pro`, `WizNote.pro`)
    still exist alongside the CMake build and would need parallel updates or
    removal.
  - Bundled third-party libs (QuaZip, Crypto++) need Qt6 compatibility
    verification (see below).
  - No usage of modules removed in Qt6 (e.g. `X11Extras`) was found in the
    codebase, so that particular blocker doesn't apply.

**Recommendation:** Treat as a deliberate, scoped migration project, not a
drop-in upgrade. Estimate multi-day effort with real regression risk,
justified mainly by long-term maintainability rather than immediate
user-facing wins.

## 2. Vendored/bundled third-party libraries

| Library | Location | Bundled version | Latest stable | Risk / notes |
|---|---|---|---|---|
| OpenSSL | `lib/openssl` | 1.0.1e (2013) | 3.x | **Critical.** This is the exact version vulnerable to Heartbleed (CVE-2014-0160, fixed in 1.0.1g). Only linked on the **macOS** build path (`APPLE` branch of `src/CMakeLists.txt`, lines ~550-563); the Linux build does not link it (relies on Qt's SSL backend / system libssl instead). Should be replaced with system OpenSSL or removed entirely from the macOS link step. |
| zlib | `lib/zlib` | 1.2.8 (2013) | 1.3.1 | Multiple known CVEs (e.g. buffer handling issues in `inflate`) patched in later releases. Only built on the **Windows** path per `lib/CMakeLists.txt`. |
| Crypto++ | `lib/cryptopp` | ~~5.6.1 / 5.6.2 (~2013)~~ **8.9.0 (2023, upgraded)** | 8.9+ | **Done.** Upgraded to the CRYPTOPP_8_9_0 tag. Compiled into every platform's build as the `cryptlib` target. See "Crypto++ upgrade notes" below for details. |
| JsonCpp | `src/share/jsoncpp` | ~~1.8.0 (2017)~~ **1.9.6 (upgraded)** | 1.9.6 | **Done.** Re-amalgamated from upstream tag `1.9.6` via `amalgamate.py`, replacing `jsoncpp.cpp`/`json/json.h`/`json/json-forwards.h` in place. |
| QuaZip | `lib/quazip` | Untagged vendored snapshot, pre-Qt6 API | Current upstream supports Qt5/Qt6 | No version marker present; API predates current upstream releases. Should be checked for Qt6 compatibility before any Qt6 migration. |

**Priority order suggested:**
1. Remove/replace bundled OpenSSL 1.0.1e (macOS build) — actively insecure.
2. ~~Upgrade Crypto++ — compiled into every platform's build.~~ Done, see below.
3. Upgrade zlib (Windows build) — known decompression CVEs.
4. ~~Upgrade JsonCpp~~ Done, see below. QuaZip remains — lower urgency, but a blocker for a Qt6 port.

### JsonCpp upgrade notes (completed)

`src/share/jsoncpp` was re-amalgamated from upstream tag `1.9.6` (previously
1.8.0) using upstream's `amalgamate.py` script, which regenerates the single
`jsoncpp.cpp` + `json/json.h` + `json/json-forwards.h` files this repo
vendors (no CMake/build changes were needed; the source files were swapped
in place). The APIs used throughout the codebase (`Json::Value`,
`Json::Reader`, `Json::FastWriter`) are deprecated-but-still-present in
1.9.6, so no call-site changes were required.

Verified: the full project builds cleanly with no new warnings/errors
attributable to JsonCpp, and a standalone parse→serialize→re-parse round
trip using `Json::Reader`/`Json::FastWriter` (the exact classes used by this
codebase) succeeds against the new 1.9.6 sources.

### Crypto++ upgrade notes (completed)

`lib/cryptopp` was upgraded in place from the vendored 5.6.1/5.6.2 snapshot to
upstream tag `CRYPTOPP_8_9_0`, keeping the repo's own hand-written
`lib/cryptopp/CMakeLists.txt` (upstream no longer ships a CMake build for the
library itself). Notable follow-up work required:

- Crypto++ 8.x splits `config.h` into several `config_*.h` headers; the
  library version is now read from `config_ver.h` instead of `config.h`.
- Crypto++ 8.x added several per-file SIMD source files (e.g.
  `blake2s_simd.cpp`, `chacha_avx.cpp`, `rijndael_simd.cpp`) that must be
  compiled with matching `-m<isa>` flags (`-mssse3`, `-msse4.1`, `-mavx2`,
  `-mpclmul`, `-maes`, `-msha`, etc.), mirroring what upstream's `GNUmakefile`
  does per-file. Without these flags GCC/Clang fail with "inlining failed ...
  target specific option mismatch" errors. These flags are now applied via
  `set_source_files_properties(... PROPERTIES COMPILE_OPTIONS ...)` in
  `lib/cryptopp/CMakeLists.txt`, guarded to GCC/Clang on x86/x86_64.
- The test/bench/validation source file names changed upstream (e.g.
  `regtest.cpp` → `regtest1..4.cpp`, `validat1..3.cpp` → `validat0..10.cpp`,
  `bench.cpp` → `bench1..3.cpp`). The `PROJECT_TEST` exclusion list in
  `lib/cryptopp/CMakeLists.txt` was updated to match, so these files are
  excluded from the `cryptlib` static library build as before.
- `CryptoPP::StreamTransformation::ProcessLastBlock` gained an explicit
  output-length parameter between 5.6.x and 8.x. `src/share/WizEnc.cpp`
  (`WizAES::encrypt`/`decrypt`) was updated to pass the output length (16
  bytes, matching the AES block size) explicitly.
- Verified: `cryptlib` builds cleanly, the full `WizNote` binary links, and a
  standalone AES-256-CBC/PKCS5 encrypt→decrypt round trip using the updated
  `ProcessLastBlock` calls produces the original plaintext.
- Not yet done: `src/src.pro` / `WizNote.pro` (legacy qmake build) were not
  updated — only the CMake build was verified. RSA (`CryptoPP::RSAES_PKCS1v15_*`)
  code paths compiled successfully but were not round-trip tested.

On Linux specifically, the system-provided Qt5, OpenSSL, and other libraries
pulled from apt are current; the vendored copies under `lib/` and
`src/share/jsoncpp` are the real technical debt, not the system packages.

## 3. Known CMake build gap (fixed)

`src/CMakeLists.txt` was missing `share/normalbrowserobject.cpp` /
`.h` from its source/header lists (present in the legacy `src/src.pro` but
never ported to CMake), causing a linker error:
`undefined reference to NormalBrowserObject::NormalBrowserObject(...)`.
Fixed by adding both files to `src/CMakeLists.txt`. Worth auditing the rest
of `src.pro` against `CMakeLists.txt` for other files that may have been
missed during the qmake→CMake migration.

## 4. Suggested next steps

- [ ] Audit `src/src.pro` vs `src/CMakeLists.txt` for any other missing
      source files from the qmake→CMake migration.
- [ ] Replace bundled OpenSSL 1.0.1e in the macOS build with system OpenSSL
      or a current vendored release.
- [x] Upgrade Crypto++ to a current release across all platforms. (done: 8.9.0)
- [ ] Upgrade zlib in the Windows build.
- [x] Upgrade JsonCpp. (done: 1.9.6) / [ ] Upgrade QuaZip.
- [ ] Once vendored libs are current, scope a dedicated Qt6 migration:
      fix deprecated API usage, update `.pro` files, update
      `cmake/QtChooser.cmake`, and validate QtWebEngine-based editor/viewer
      behavior end-to-end.
