# Software Requirements Specification — SurfMeter

Version: 0.1 (initial draft)  
Date: 2026-11-05  
Status: Proposed requirements; implementation has not started

## 1. Purpose

SurfMeter is a macOS menu bar app that helps a person understand how much time they spend on social media and other websites through their browser. It shows accumulated time for each platform today, yesterday's total for the same platform, and whether today's usage is lower or higher.

The primary outcome is a quick answer to: “How much time have I spent on this platform today, and how does that compare with yesterday?”

## 2. Scope

### 2.1 MVP

- Run as a macOS menu bar app with a dropdown dashboard.
- Track active use of supported browsers and attribute time to websites or platforms.
- Show today's and yesterday's time for each platform.
- Provide Daily and Weekly main tabs, with a dedicated Yesterday button inside Daily and a seven-day overview inside Weekly.
- Show a green comparison when today's time is below yesterday's and a red comparison when it is above yesterday's.
- Track general websites as well as social media platforms.
- Store activity locally, with pause, exclusion, and deletion controls.

### 2.2 Outside the MVP

- Tracking native social media apps or mobile devices.
- Website blocking, goals, reminders, productivity scores, and automated interventions.
- Accounts, cloud sync, shared dashboards, or team monitoring.
- Content inspection, screenshots, keystrokes, page titles, or full browsing history.
- Historical exploration beyond the daily and seven-day dashboards, and export features.

## 3. Intended user and main flow

The intended user is an individual tracking their own browsing habits on a Mac.

1. The user opens the app and completes setup for a supported browser.
2. The app explains what it measures and requests only the access needed for tracking.
3. The user browses normally; eligible active browsing time accumulates automatically.
4. The user clicks the menu bar item to see platforms ranked by today's time, yesterday's totals, and comparisons.
5. The user can pause tracking, exclude a website, or delete stored activity.

## 4. Product decisions and assumptions

The following defaults make the initial requirements implementable. They are proposed decisions, not confirmed technical capabilities.

| Topic | Proposed MVP decision |
| --- | --- |
| Presentation | Menu bar label shows today's total tracked browser time; clicking opens the per-platform dashboard. |
| Comparison | Compare today's accumulated time with yesterday's complete calendar-day total. |
| Meaning of green/red | Green means lower usage; red means higher usage. This reflects the user's comparison preference, not a judgment about a website. |
| Browser coverage | Target Safari and Google Chrome for the initial release, subject to a technical feasibility check. Identify supported browsers explicitly in setup. |
| Idle threshold | Stop counting after 60 seconds without keyboard or pointer input; make this configurable later. |
| Storage | Local-only, with no account or server required. |
| Retention | Retain daily totals for 30 calendar days by default; retain only transient data needed to calculate them. |
| Platform mapping | Use hostname-based rules to group recognized services; show unmatched websites by registrable domain. |
| Time zone | Use the Mac's local time zone for daily boundaries; preserve the day attribution of previously recorded activity. |

## 5. Functional requirements

### 5.1 Setup and menu bar behavior

| ID | Requirement |
| --- | --- |
| FR-01 | The app shall run in the macOS menu bar and provide a dropdown dashboard without requiring a main window to remain open. |
| FR-02 | The menu bar shall show today's total eligible browser time using compact units such as `2h 15m`. |
| FR-03 | Setup shall explain the tracking method, supported browsers, required permissions, and collected data before tracking starts. |
| FR-04 | The app shall identify missing permissions or a disconnected browser integration and explain how to restore tracking. |
| FR-05 | The user shall be able to pause/resume tracking and quit from the menu bar. Paused status shall be visible. |
| FR-06 | The user shall be able to enable or disable launch at login. It shall be opt-in. |

### 5.2 Activity measurement

| ID | Requirement |
| --- | --- |
| FR-07 | The app shall count time only for the selected tab in the focused window of the foreground supported browser while the user is active. |
| FR-08 | The app shall attribute an eligible interval to exactly one platform or website. Multiple tabs, windows, or browsers shall not cause double counting. |
| FR-09 | Switching tabs, changing the active tab's website, changing the focused browser window, or switching apps shall end the previous eligible interval and re-evaluate tracking. |
| FR-10 | Background tabs, background browsers, minimized windows, and media playing without eligible foreground activity shall not accumulate time. |
| FR-11 | Tracking shall stop when the screen locks, the Mac sleeps, tracking is paused, or idle time reaches the threshold. It shall resume only when eligibility is restored. |
| FR-12 | Idle time shall be excluded starting at the instant the idle threshold is reached. The initial 60 seconds without input still count if otherwise eligible; idle time shall not be counted retroactively on resume. |
| FR-13 | Browser-internal pages, blank/new-tab pages, local files, and unsupported URL schemes shall not count as website usage. |
| FR-14 | If the active website cannot be determined, the app shall leave that interval uncounted and show tracking availability rather than guess or continue attributing time to the previous site. |
| FR-15 | Private/incognito browsing shall be excluded by default. If an integration cannot guarantee this, it shall not be enabled until that limitation is resolved and clearly disclosed. |
| FR-16 | Activity crossing local midnight shall be split between the corresponding calendar days. |
| FR-17 | Time shall be measured using elapsed durations resilient to wall-clock corrections. Sleep, restart, or downtime shall never be interpreted as browsing time. |

### 5.3 Platform identification

| ID | Requirement |
| --- | --- |
| FR-18 | Recognized hostnames shall be grouped into a single platform; for example, `youtube.com` and `www.youtube.com` shall appear as YouTube. |
| FR-19 | The initial platform catalog shall cover YouTube, Facebook, Instagram, X/Twitter, Reddit, TikTok, and LinkedIn. Domain aliases shall be explicitly mapped and reviewed during implementation. |
| FR-20 | Websites outside the catalog shall be grouped by registrable domain, with public-suffix-aware handling so unrelated sites under suffixes such as `co.uk` are not merged. |
| FR-21 | Classification shall use exact hostnames or valid subdomain boundaries; a lookalike hostname such as `youtube.com.example.org` shall not be classified as YouTube. |
| FR-22 | The user shall be able to exclude a website from future tracking. Existing totals shall remain until deleted. |

### 5.4 Dashboard and comparison

| ID | Requirement |
| --- | --- |
| FR-23 | The dropdown shall show today's total, yesterday's total, and a list of platforms with platform name, today's duration, yesterday's duration, and a comparison indicator. |
| FR-24 | The list shall include platforms with usage on either day, including platforms used yesterday with zero usage today. It shall be sorted by today's duration descending, with ties sorted by name. |
| FR-25 | For each platform, compute `delta = today_seconds - yesterday_seconds`. A negative delta shall be green with a “less” label; a positive delta shall be red with a “more” label; zero shall be neutral with a “same” label. |
| FR-26 | Comparisons shall use text or symbols in addition to color so they remain understandable without color perception. |
| FR-27 | A platform with no tracked time yesterday and positive time today shall show yesterday as `0m` and today's full duration as “more.” No percentage or division by zero shall be used. |
| FR-28 | If no data exists for yesterday, the dashboard shall state “No data recorded yesterday.” Zero means no recorded usage, not proof that the browser was unused. The first-run dashboard shall not imply a measured improvement. |
| FR-29 | The dashboard shall state that the comparison is with yesterday's full day and shall indicate known partial coverage, such as first-run or paused tracking, when applicable. |
| FR-30 | Totals shall be calculated in seconds and displayed in hours and minutes, using `<1m` for positive durations below one minute. Comparison direction shall be determined before display rounding; a sub-minute difference shall be labeled `<1m more/less`. |
| FR-31 | The dashboard shall refresh while open and shall show current totals on opening. The menu bar total shall update during eligible tracking. |

Example dashboard content:

```text
Today: 2h 10m                 Yesterday: 2h 45m
Compared with yesterday's full day

Platform     Today      Yesterday     Change
YouTube      1h 20m     1h 50m        ↓ 30m less  [green]
Instagram      40m        25m         ↑ 15m more  [red]
Reddit         10m        30m         ↓ 20m less  [green]

Pause tracking · Settings · Quit
```

### 5.5 Local data and controls

| ID | Requirement |
| --- | --- |
| FR-32 | The app shall persist daily per-platform totals across restarts and enforce the retention period automatically. |
| FR-33 | Persisted usage shall contain only the local calendar date, platform/domain identifier, accumulated duration, and minimal coverage/settings metadata. Full URLs, paths, queries, page content, and page titles shall not be persisted or logged. |
| FR-34 | The app shall provide a delete-all-activity action with an explicit confirmation. Deletion shall clear stored activity and refresh visible totals; tracking may then start accumulating new usage. |
| FR-35 | Collection and comparison shall work offline. No browsing activity shall be sent to external services. |
| FR-36 | Permission loss or integration failure shall stop affected tracking promptly and mark the affected period as incomplete rather than recording assumed usage. |

### 5.6 Daily and Weekly navigation

| ID | Requirement |
| --- | --- |
| FR-37 | The dashboard shall have Daily and Weekly main tabs. Daily shall open on today and provide a dedicated Yesterday toggle; selecting it again shall return to today. Returning from Weekly to Daily shall open today. |
| FR-38 | Weekly shall show the last seven local calendar days, including today so far, with an explicit date range, daily chart, total duration, daily average, and per-platform totals sorted descending. The daily average shall divide the recorded total by seven; missing activity shall not be implied to be measured zero usage. Known partial coverage shall be indicated. |
| FR-39 | Website details shall follow the selected period: hourly detail for the selected daily date, or seven daily totals and a daily average for Weekly. Returning from details shall preserve the selected period and day. Weekly shall not apply the red/green yesterday comparison to seven-day totals. |

## 6. Quality requirements

| ID | Requirement / target |
| --- | --- |
| NFR-01 | On a supported integration, site/focus changes shall be reflected within 2 seconds under normal operating conditions. A controlled 10-minute tracking session shall have no more than 5 seconds of attribution error. |
| NFR-02 | Opening the dashboard shall display locally stored totals within 500 ms under normal conditions on the reference test Mac. |
| NFR-03 | Target average CPU usage below 1% of one core over a 30-minute normal browsing session, and resident memory below 100 MB. Record the reference hardware and measurement method during validation. |
| NFR-04 | Tracking shall avoid excessive polling and disk writes. A crash shall lose no more than 30 seconds of accumulated eligible activity. |
| NFR-05 | The dashboard shall follow Apple's Liquid Glass visual direction using system materials where supported, with a compatible fallback for older supported macOS versions. It shall support light/dark appearance, Reduce Transparency, Increase Contrast, Reduce Motion, keyboard navigation, VoiceOver labels, and readable comparison indicators. |
| NFR-06 | The app shall not require administrator privileges or collect more browser access than its tracking method needs. |
| NFR-07 | Platform aggregation and daily rollover logic shall be independently testable without an actual browser session. |
| NFR-08 | Errors and diagnostics shall exclude browsing content and full URLs. |

## 7. Conceptual data model

| Entity | Key fields | Purpose |
| --- | --- | --- |
| Daily usage | Local date, platform/domain ID, duration in seconds | Persist accumulated time by platform and day. |
| Platform rule | Platform ID, display name, allowed hostnames/domain rules | Normalize website hosts into platform names. |
| Settings | Pause state, excluded domains, login preference, retention | Store user tracking preferences. |
| Coverage metadata | Day, tracking start/stop or incomplete status, reason | Explain first-run, paused, or unavailable coverage without recording URL history. |
| Active interval (transient) | Current platform, monotonic start, eligibility state | Accumulate one active website at a time; discard URL details after classification. |

Persist only the minimum coverage detail needed to describe incomplete days. This is a logical model, not a commitment to a storage engine.

## 8. Technical discovery and release gates

The implementation language, macOS deployment target, storage engine, and browser integration are not selected by this SRS. A native menu bar app is the proposed direction. Browser extensions with a local app connection and supported macOS browser automation are integration options to evaluate.

Before implementing the full MVP:

1. Verify how Safari and Chrome expose the active hostname, selected tab, focused window, and private-browsing state with user-authorized access.
2. Validate focus, idle, sleep, lock, and resume detection on the proposed minimum macOS version.
3. Select the integration method based on accuracy, privacy, permissions, reliability, and installation effort. If extensions are required, include their installation and connection state in setup.
4. Decide the exact supported browser versions and minimum macOS version and publish that support matrix before release.
5. Verify the private-browsing exclusion requirement for every supported integration. If a target browser cannot meet it, document the constraint and revise release scope before shipping support for that browser.

## 9. Acceptance criteria

| ID | Scenario | Expected result |
| --- | --- | --- |
| AC-01 | Actively browse YouTube for 10 minutes in a supported foreground browser. | YouTube and today's total increase by 10 minutes within the NFR-01 tolerance. |
| AC-02 | Leave YouTube open in the background while using another app for 5 minutes. | No YouTube time accumulates during those 5 minutes. |
| AC-03 | Switch between two websites and two supported browsers. | Each interval is attributed once to the selected foreground website; the total does not exceed eligible elapsed time. |
| AC-04 | Stop input for 3 minutes with the default threshold. | Only the first 60 seconds of that idle spell count. Tracking resumes on input if the website is eligible. |
| AC-05 | Lock or sleep the Mac, then resume. | The locked/asleep period contributes zero usage. |
| AC-06 | Yesterday's Instagram total is 60 minutes; today's is 45 minutes. | Show `45m`, `1h`, and a green `15m less` indicator. |
| AC-07 | Today's Instagram total increases to 75 minutes. | Show a red `15m more` indicator. At exactly 60 minutes, show a neutral `same` indicator. |
| AC-08 | Today's Reddit usage is 10 minutes and yesterday's is zero. | Show yesterday as `0m` and a red `10m more`, with no percentage. If yesterday has no records, also show the no-data explanation. |
| AC-09 | First launch has no stored data. | Show an informative empty state and no claim that usage has improved. |
| AC-10 | An eligible interval spans 23:59 to 00:01 local time. | Attribute one minute to each day and roll the today/yesterday dashboard forward. |
| AC-11 | Browse a platform subdomain, a lookalike domain, an excluded site, an internal page, and a private window. | Group only valid platform hosts; leave excluded, internal, and private browsing uncounted. |
| AC-12 | Pause, restart, then resume the app. | Stored totals survive; paused state remains in effect until explicitly resumed; downtime adds no usage. |
| AC-13 | Revoke browser access while tracking. | Stop affected tracking, display a recovery status, and do not attribute later time to the last known website. |
| AC-14 | Delete all activity and relaunch. | Old totals remain deleted. New eligible activity can accumulate after deletion. |
| AC-15 | Change the system clock or local time zone. | Do not generate negative or inflated durations; preserve historical day attribution and use the new local date for subsequent activity. |
| AC-16 | Inspect local storage and diagnostics after browsing a URL containing a path and query. | No full URL, query, page title, or page content is stored or logged. |
| AC-17 | Open Daily, select Yesterday, then select Yesterday again. | Show today by default, yesterday's full-day totals when selected, and today's totals again when deselected. |
| AC-18 | Open Weekly and select a platform. | Show an explicit seven-day range including today so far; chart, aggregate, daily average, and platform detail shall agree with the daily records. Back shall preserve Weekly. |
| AC-19 | Switch from Weekly to Daily. | Daily opens on today; the menu bar continues to show today's total regardless of the dashboard period. |

## 10. Suggested delivery order

1. Browser/OS feasibility prototype and finalized support matrix.
2. Activity eligibility, platform classification, daily aggregation, and local storage.
3. Menu bar total and today/yesterday dropdown with accessible comparison colors and text.
4. Setup, pause/resume, exclusions, retention, deletion, and launch-at-login preference.
5. Acceptance validation, performance measurement, and packaging for local installation.

## 11. Decisions to confirm before implementation

- Whether Safari and Chrome cover the user's initial browser needs.
- Minimum macOS version, informed by the user's Mac and the feasibility prototype.
- Whether the menu bar should show total browsing time as proposed, or the currently active platform's time.
- Whether comparison against yesterday's full day is sufficient; a same-time-of-day comparison would require additional time-bucket data and a revised storage specification.

These decisions do not block the initial repository or requirements draft.
