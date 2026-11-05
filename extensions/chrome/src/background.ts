import { activity, type Activity, type BrowserState } from "./state.js";

const sessionID = crypto.randomUUID();
let sequence = 0;
let generation = 0;
let port: NativePort | undefined;
let retryAfter = 0;

async function badge(connected: boolean): Promise<void> {
  await chrome.action.setBadgeText({ text: connected ? "" : "!" });
  await chrome.action.setTitle({ title: connected ? "SurfMeter connected" : "Open SurfMeter, then click to reconnect" });
}

function connection(): NativePort | undefined {
  if (port) return port;
  if (Date.now() < retryAfter) return undefined;
  try {
    const candidate = chrome.runtime.connectNative("dev.surfmeter.bridge");
    port = candidate;
    candidate.onDisconnect.addListener(() => {
      void chrome.runtime.lastError; // Consume diagnostics without logging browsing data.
      if (port !== candidate) return;
      port = undefined;
      retryAfter = Date.now() + 5000;
      void badge(false);
    });
    candidate.onMessage.addListener((reply: unknown) => {
      if (port !== candidate) return;
      const valid = typeof reply === "object" && reply !== null &&
        "protocolVersion" in reply && reply.protocolVersion === 1 &&
        "accepted" in reply && reply.accepted === true;
      void badge(valid);
    });
    return candidate;
  } catch { void badge(false); return undefined; }
}

async function refresh(): Promise<void> {
  const current = ++generation;
  let value: Activity = { state: "unavailable" };
  try {
    const window = await chrome.windows.getLastFocused();
    if (!window.focused) value = { state: "inactive" };
    else if (!window.incognito && window.type === "normal" && window.id !== undefined) {
      const [tab] = await chrome.tabs.query({ active: true, windowId: window.id });
      value = activity(true, tab?.incognito ?? true, tab?.url);
    }
  } catch { /* Missing windows and permission loss produce unavailable state. */ }
  if (current !== generation) return; // A slower prior query cannot overwrite a newer event.
  const message: BrowserState = { protocolVersion: 1, browser: "chrome", sessionID, sequence: sequence++, ...value };
  try { connection()?.postMessage(message); } catch { port = undefined; void badge(false); }
}

for (const event of [chrome.tabs.onActivated, chrome.tabs.onUpdated, chrome.tabs.onRemoved,
  chrome.windows.onFocusChanged, chrome.windows.onRemoved, chrome.runtime.onStartup,
  chrome.runtime.onInstalled, chrome.alarms.onAlarm]) event.addListener(() => { void refresh(); });
chrome.action.onClicked.addListener(() => { port?.disconnect(); port = undefined; retryAfter = 0; void refresh(); });
// A heartbeat establishes freshness, never duration. Alarms recover a suspended worker.
void chrome.alarms.create("surfmeter-reconnect", { periodInMinutes: 0.5 });
setInterval(() => { void refresh(); }, 1000);
void refresh();
