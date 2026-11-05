export type Activity = { state: "active"; hostname: string } | { state: "inactive" | "unavailable" };
export interface BrowserState {
  protocolVersion: 1;
  browser: "chrome";
  sessionID: string;
  sequence: number;
  state: Activity["state"];
  hostname?: string;
}

/** Strip sensitive URL components before crossing the native messaging boundary. */
export function activity(focused: boolean, incognito: boolean, url?: string): Activity {
  if (!focused) return { state: "inactive" };
  if (incognito || !url) return { state: "unavailable" };
  try {
    const parsed = new URL(url);
    if (!["http:", "https:"].includes(parsed.protocol)) return { state: "unavailable" };
    const hostname = parsed.hostname.toLowerCase().replace(/\.$/, "");
    // Match the Swift boundary. IPv6 is excluded for now rather than forwarding brackets/colons.
    if (!hostname || hostname.length > 253 || !hostname.split(".").every(label =>
      label.length > 0 && label.length <= 63 && /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(label))) {
      return { state: "unavailable" };
    }
    return { state: "active", hostname };
  } catch { return { state: "unavailable" }; }
}
