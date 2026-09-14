# Delivery record — 1.0.2

The user removed pending-question detection from the requested scope. This release delivers the remaining session keypad functions; no further work on pending-question detection is scheduled.

- iPhone: signed Release 1.0.2 installed and launched on the paired device. Dynamic one-to-three keys, hide/restore, titles, focus request feedback and keep-awake behavior were covered by earlier device runs and selection tests. Later XCTest runner bootstrapping failed before tests, so a complete automated rerun of the final build is not claimed.
- Branding: first-version icon retained. Header renders the same geometry directly in SwiftUI to avoid image-loading failures.
- Mac: public 1.0.2 archive downloaded, SHA-256 checked, code signature verified, and bundled bridge compared byte-for-byte with reviewed source. Installed locally with existing pairing retained.
- Connection: authenticated state fetch confirmed live history and account usage. Silence does not imply interruption; explicit stopped tasks retain green with STOP.
- Independent review: three defects found and fixed (TLS handshake blocking, redirect delegate placement, desktop filtering before history limit). All 11 regression tests passed locally; CI passed for release source commit c05aa12.
- Open source: GitHub repository, bilingual GitHub Pages site, release archive and checksum published. Website download links point to 1.0.2.

Distribution limitations remain documented: personal iPhone signing, no App Store/TestFlight distribution, and ad-hoc signed Apple Silicon Mac companion requiring Python 3.10+ and macOS 14+. Reliable live pending-question identification is outside the final requested scope.
