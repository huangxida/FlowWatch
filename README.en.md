<div align="center">
  <img src=".github/assets/app-icon.png" width="96" height="96" alt="FlowWatch" />
  <h1>FlowWatch</h1>
  <p>Lightweight macOS menu bar network monitor: live speed, traffic stats, and trends.</p>
</div>

[简体中文](README.md) | English

## Features
- Real-time upload/download speed in the menu bar
- Today/total traffic stats and charts (Charts, macOS 13+)
- Custom sampling interval and display style

## Data & Privacy
- Traffic stats are calculated locally from system network interface counters; no packet content is captured.
- Settings and daily totals are stored on your device only (UserDefaults).
- No account is required, and the app does not upload or sync your data.

## Install
```bash
brew tap huangxida/flowwatch
brew install --cask flowwatch
```

## Screenshots
| Status bar: speed | Status bar: today | Status bar: speed + today |
| --- | --- | --- |
| <img src=".github/assets/statusbar-speed.png" width="260" alt="Status bar speed" /> | <img src=".github/assets/statusbar-today.png" width="260" alt="Status bar today" /> | <img src=".github/assets/statusbar-speed-today.png" width="260" alt="Status bar speed and today" /> |

| Settings | Popup |
| --- | --- |
| <img src=".github/assets/settings-en.png" width="420" alt="Settings" /> | <img src=".github/assets/popup-en.png" width="420" alt="Popup" /> |
