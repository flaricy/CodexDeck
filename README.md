<p align="center"><img src="Brand/icon-256.png" width="100" alt="Codex Deck"></p>
<h1 align="center">Codex Deck</h1>
<p align="center">Work on Mac. Stay in flow.</p>
<p align="center"><a href="https://flaricy.github.io/CodexDeck/">Website</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="INSTALL.md">Install</a> · <a href="https://github.com/flaricy/CodexDeck/releases">Releases</a></p>

Turn an iPhone into a native Codex session deck. Keep it beside your keyboard, glance at task status and remaining usage, and tap a large key to open that session on your Mac.

![Codex Deck](docs/assets/social.png)

## Features

- **One to three keys.** Adapts to portrait and landscape. New sessions join without filling empty keys with historical tasks.
- **Desktop names.** Uses Codex's sidebar name, including manual renames.
- **Clear states.** Blue for running, green for done and STOP. Output silence never implies a stopped task.
- **A personal deck.** Hide inactive sessions; choices survive restarts and address changes for the same paired Mac.
- **Real usage.** Shows the core Codex quota windows actually returned by the account, with reset times.
- **Keep your iPhone awake.** On by default in the foreground; the sun button toggles it with haptic feedback. It does not keep the Mac awake. Reconnects after network loss and preserves the last deck while disconnected.
- **A menu-bar companion.** QR pairing, optional launch at login, and no terminal window during normal use.
- **Local HTTPS.** Bearer pairing token, certificate pinning and an allowlist of session IDs. No relay service.

## Install

See the [installation guide](INSTALL.md).

- iPhone: iOS 17+, built and signed with your own Apple ID in Xcode.
- Mac: macOS 14+, Python 3.10+ and a signed-in Codex desktop installation. The prebuilt companion targets Apple Silicon.
- There is no App Store/TestFlight release yet. The Mac binary is ad-hoc signed, not notarized.

## Current scope

Session status is a read-only projection of local Codex records, not a liveness guarantee. Local desktop/extension main sessions are supported; SSH hosts and subagents are not.

**Pending questions and approvals are not reliably detected.** Do not use the absence of an orange state as evidence that no input is waiting. The internal desktop socket is not accessed or bypassed. These limitations are also visible in the app's status help.

A successful tap means macOS accepted the `codex://threads/<id>` link. The app does not send prompts or answers.

## Repository

| Path | Purpose |
| --- | --- |
| `iOS/` | Native SwiftUI iPhone/iPad app and Xcode project |
| `macOS/` | Menu-bar companion and build script |
| `Bridge/` | Read-only history adapter, quota reader and HTTPS server |
| `Tests/` | Bridge and session-selection regression tests |
| `Brand/` | Original SVG identity and generated app icons |
| `docs/` | Static, bilingual GitHub Pages website |

```sh
python3 -m unittest discover -s Tests -v
swiftc iOS/CodexDeck/SessionSelection.swift Tests/SelectionTests.swift -o /tmp/deck-tests
/tmp/deck-tests
python3 macOS/build.py
```

The generated Xcode project is committed. XcodeGen is only needed after editing `iOS/project.yml`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [TESTING.md](TESTING.md) and [SECURITY.md](SECURITY.md). Never commit pairing tokens, certificates, account details, personal screenshots, provisioning profiles or signed iPhone builds.

MIT licensed. Inspired by [herdr](https://github.com/herdrdev/herdr)'s session deck interaction; no herdr code is included. Website direction references [SwiftNote](https://flaricy.github.io/SwiftNote/), with original implementation and assets.

Codex Deck is an independent project by flaricy and is not affiliated with or endorsed by OpenAI.
