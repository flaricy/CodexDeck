# Contributing

Small, well-tested changes are welcome. Open an issue for broader changes before adding dependencies or expanding the control surface.

- Keep one to three large keys and stable ordering.
- Never infer a stopped task from silence or network failure.
- Prefer explicit structured events over guessing from conversation text.
- Keep all database reads read-only and all focus operations restricted to known UUIDs.
- Use sample data in screenshots and tests. Never upload a real session title or pairing QR.
- Keep the Chinese and English website pages consistent, including capability limitations.
- Generated binaries, signing material and user data do not belong in git.

Run the tests documented in README.md. UI changes need portrait and landscape checks at iPhone widths. Website changes need keyboard navigation, mobile overflow and reduced-motion checks.

The committed Xcode project can be regenerated with `cd iOS && xcodegen generate` when the YAML changes. Explain the behavior change and relevant validation in each pull request.
