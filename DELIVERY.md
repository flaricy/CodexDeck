# Delivery acceptance

The release candidate is not yet fully accepted. Passing unit tests alone does not establish the following end-to-end behavior.

| Requirement | Current evidence | Remaining acceptance |
| --- | --- | --- |
| One to three large session keys, hide/restore | Selection tests and prior device UI runs | Repeat on final candidate |
| Exact desktop session titles | SQLite name projection regression test | Confirm current desktop rename on final phone build |
| Running, completed, explicit STOP | Structured lifecycle tests; silence does not imply interruption | Final live session transition check |
| Orange pending question/approval | Structured item classifier only | Real desktop pending/resolved events remain unverified; this is a delivery gap |
| Tap phone to focus Mac task | Allowlisted deep link; prior phone request succeeded | Observe actual target task focused on Mac |
| Codex remaining usage and reset | Core-bucket parsing tests | Compare live final UI with account data |
| Foreground iPhone stays awake | Prior device idle timer and toggle tests | Final device regression; Mac sleep is independent |
| QR pairing and reconnection | Pinned HTTPS and Keychain; prior device connection | Final scan, cancel, network interruption and restart checks |
| Product icon | User selected the first version; repository and website SVG match | Retain first-version assets in final build |
| Open source and promotional site | Public repository and GitHub Pages | Publish final accepted assets and release artifacts |
| Independent review | Separate agent found three concrete defects; fixes implemented | TLS, CLI-history and actual URLSession redirect regressions passed; final product acceptance still pending |

Recent candidate fixes: manual pause survives Mac sleep/wake; malformed focus payloads return a controlled error; pairing HTTP requests reject redirects; cancelled or superseded phone requests cannot publish stale results; dismissed scanners ignore late authorization and QR callbacks.

Independent review follow-up: delayed TLS handshakes now run in request threads with a five-second timeout; a stalled peer no longer blocks authenticated HTTPS requests (loopback regression passed). Desktop source filtering now occurs before the history limit (70 newer CLI records regression passed). Redirect delegate was moved to the actual URLSession delegate; actual Apple URLSession returned 302 without following its Location (loopback regression passed).
