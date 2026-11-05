# Browser state protocol v1

Implemented boundaries: `extensions/chrome/src/state.ts` and `Sources/SurfMeterCore/BrowserState.swift`. Safari is not implemented. This is an ephemeral connection snapshot, not a browsing-history or duration record.

```json
{
  "protocolVersion": 1,
  "browser": "chrome",
  "sessionID": "4AF58FF5-B099-44EA-BEFA-5D1BE73F5E72",
  "sequence": 0,
  "state": "active",
  "hostname": "www.youtube.com"
}
```

| Field | Rule |
| --- | --- |
| `protocolVersion` | Integer 1; other versions rejected. |
| `browser` | `chrome` or reserved `safari`; the Chrome helper accepts only `chrome`. |
| `sessionID` | UUID generated on worker startup, not a persistent user identifier. |
| `sequence` | Nonnegative integer, increasing within a worker session. The app rejects duplicate/older snapshots from its current session. |
| `state` | `active`, `inactive` (no focused window), or `unavailable` (private, unsupported, missing access, or query failure). |
| `hostname` | Required only for `active`; omitted or null otherwise. Lowercase ASCII DNS labels, including punycode; at most 253 bytes and 63 bytes per label. IPv4 accepted, IPv6 excluded in this foundation. This is not registrable-domain grouping. |

Unknown keys are rejected. No titles, full URLs, paths, queries, content, tab IDs, window IDs, or private-window identifiers cross the boundary. Private and unsupported pages share the same unavailable state. The extension reads the active tab URL using the tabs permission and reduces it to a hostname before calling native messaging. It does not persist the URL or log it.

## Transport and replies

Chrome uses `runtime.connectNative("dev.surfmeter.bridge")`. JSON UTF-8 messages have a four-byte native-order length header (little-endian on supported development Macs). SurfMeter caps frames at 16 KiB. Partial reads are assembled; truncated and oversized frames fail closed. Stdout carries protocol frames only.

The helper validates the origin supplied by Chrome against adjacent `host-config.json`, validates/re-encodes the message, and connects to the running app for each snapshot. The app listens on `~/Library/Application Support/SurfMeter/bridge.sock`. Both sides check the peer UID using `getpeereid`; the directory is mode 0700 and socket 0600. A process-held lock prevents a second instance from replacing a live endpoint. Socket reads/writes have a two-second timeout. No network port is opened.

Reply: `{"protocolVersion":1,"accepted":true}`. Validation, ordering, or app-connection failure gives `accepted:false`. Invalid initial origin/configuration and broken framing terminate the host. Payloads are omitted from diagnostics.

This is a **development IPC boundary**. Chrome's exact `allowed_origins` registration and origin argument check restrict normal extension access. UID checks do not authenticate another process owned by the same user; code-signature authentication and sandbox-compatible Safari IPC remain release gates. Do not describe this as authenticated production IPC.

## Freshness and recovery

Focus/tab events trigger a fresh snapshot. An asynchronous generation counter prevents older queries from overwriting newer results. A five-second heartbeat reports freshness, not usage time. A one-minute Chrome alarm retries after worker suspension; the toolbar action retries immediately. The app displays Disconnected after 15 seconds without a snapshot using a monotonic clock. Sleep/wake clears snapshots and requires fresh state.

The helper does not launch the app automatically: open SurfMeter first. If the app is missing, replies are negative. App launch/recovery latency must be validated before Task 1 closes. Multi-profile arbitration, permission revocation, private-window focus behavior, worker suspension, and browser lifecycle still need real-browser evidence. The freshness display is not an accounting policy; Task 2 must close intervals safely on native state changes and stale/disconnected signals without counting gaps.
