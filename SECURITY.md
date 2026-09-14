# Security

The bridge is a local-network control surface. It accepts a pairing bearer token over HTTPS. The iPhone pins the bridge certificate; credentials remain on the paired devices. Only a fresh, known session UUID may be opened. There is no arbitrary shell-command endpoint.

Do not publish tokens, pairing QR codes, private keys, account configuration, session databases, provisioning profiles or real user screenshots in issues. Do not disable TLS validation to work around a pairing problem.

For a suspected vulnerability, use GitHub's private vulnerability reporting if enabled on this repository. If unavailable, open a minimal issue asking for a private contact without including exploit details or secrets.

The local Codex database schema is an internal implementation detail and may change. A successful read does not prove an agent process is alive. Pending-input detection is not a reliable security or approval boundary.
