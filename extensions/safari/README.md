# Safari adapter — pending Xcode feasibility

There is no installable Safari extension yet. The Chrome background worker must not be loaded into Safari unchanged: native messaging, private-window permission behavior, background lifetime, signing, and sandbox/App Group IPC need separate validation.

Use `docs/BROWSER-PROTOCOL.md` for the common payload. Package a Safari Web Extension and `SafariWebExtensionHandler` in a containing Mac app using full Xcode; the handler must validate a Safari payload and relay it to the sole main-app writer. The current development Unix socket is verified for an unsandboxed Chrome helper, not a sandboxed Safari handler. Evaluate App Group IPC or authenticated XPC if sandbox access requires it. Do not relax the sandbox to make the Chrome path appear validated for Safari.

Task 1 remains in progress until real Safari focus/tab/private/reconnect and app launch checks are recorded in `docs/FOUNDATION-VALIDATION.md`.
