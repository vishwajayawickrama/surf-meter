// Narrow declarations for the APIs used here; no unchecked any at the browser boundary.
interface ChromeEvent<T extends (...args: never[]) => void> { addListener(callback: T): void }
interface NativePort {
  postMessage(message: import("./state.js").BrowserState): void;
  onDisconnect: ChromeEvent<() => void>;
  onMessage: ChromeEvent<(message: unknown) => void>;
}
declare const chrome: {
  runtime: {
    connectNative(name: string): NativePort;
    lastError?: { message?: string };
    onStartup: ChromeEvent<() => void>;
    onInstalled: ChromeEvent<() => void>;
  };
  tabs: {
    query(query: { active: boolean; windowId: number }): Promise<Array<{ incognito: boolean; url?: string }>>;
    onActivated: ChromeEvent<() => void>;
    onUpdated: ChromeEvent<() => void>;
    onRemoved: ChromeEvent<() => void>;
  };
  windows: {
    getLastFocused(): Promise<{ id?: number; focused: boolean; incognito: boolean; type?: string }>;
    onFocusChanged: ChromeEvent<() => void>;
    onRemoved: ChromeEvent<() => void>;
  };
  alarms: {
    create(name: string, info: { periodInMinutes: number }): Promise<void>;
    onAlarm: ChromeEvent<() => void>;
  };
  action: {
    onClicked: ChromeEvent<() => void>;
    setBadgeText(details: { text: string }): Promise<void>;
    setTitle(details: { title: string }): Promise<void>;
  };
};
