# timesync-fork
Timesync Plugin alternative For Koreader

This was built because the default plugin was not working in my Kindle Paperwhite 10th generation, so this is a replacement of it, I don't know if this will work with other devices, but if it does please let me know!

The instalation process is the same as any other koreader plugin, just unzip and paste the folder into the koreader folder plugins.

## Features
- Auto-Sync: Automatically updates the time 5 seconds after a network connection is established.
- Timezone Support: Includes a comprehensive list of world timezones (UTC-12 to UTC+14) and quick-select options for major cities.
- Low Overhead: Uses a simple curl fetch against Google to retrieve UTC time without needing complex NTP protocols.

## Installation
- Connect your e-reader to your computer via USB.
- Navigate to the KOReader plugins directory: *koreader/plugins/*
- Create a new folder named *timesync-fork.koplugin*.
- Copy the following files into that folder:
  - _meta.lua
  - main.lua
- Restart KOReader.


## Usage

### 1. Setting your Timezone

Before syncing, you must set your local timezone so the plugin can calculate the correct local time from UTC:

1. Open the **Top Menu** in KOReader.
2. Go to the **Tools** (screwdriver/wrench icon) section.
3. Select **Internet Time Sync** > **Select Timezone**.
4. Choose your region from:
* **Common / Special Zones** (e.g., São Paulo, London, New York).
* **West (Negative UTC)**.
* **East (Positive UTC)**.


### 2. Manual Synchronization

To force a sync immediately:

1. Ensure Wi-Fi is turned on and connected.
2. Navigate to **Tools** > **Internet Time Sync**.
3. Tap **Sync Time Now**.
4. An "InfoMessage" will appear confirming if the sync was successful.

### 3. Automatic Synchronization

Every time your device connects to a network, the plugin will wait 5 seconds and then perform a silent background synchronization.

## Technical Details

* **Time Source:** The plugin executes `curl -sI --insecure https://google.com` to extract the `date:` header.
* **System Commands:** It utilizes `date -s`, `hwclock -w`, and `/usr/sbin/setdate` (for Kindle) to ensure the time is updated across all system layers.
* **Settings:** User preferences are stored in `settings/timesync_plugin.lua`.
