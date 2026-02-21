# timesync-fork

Timesync Plugin alternative for KOReader.

This plugin was developed as a replacement for the default time sync plugin. It provides a robust way to keep your device's clock accurate using modern web APIs.

## Features

* **Auto-Sync (Daily):** Automatically attempts to sync the time once per day when the device resumes.
* **Geolocation Support:** Can automatically detect your timezone based on your IP address using the `ip-api.com` service.
* **Manual Timezone Overrides:** Allows users to manually specify an IANA Timezone ID (e.g., `America/New_York`).
* **Reliable Time Source:** Uses `timeapi.io` to retrieve precise date and time data in JSON format.

## Installation

1. Connect your e-reader to your computer via USB.
2. Navigate to the KOReader plugins directory: `koreader/plugins/`
3. Create a new folder named `timesync-fork.koplugin`.
4. Copy the following files into that folder:
* `_meta.lua`
* `main.lua`


5. Restart KOReader.

## Usage

### 1. Accessing Settings

All options are located in the **Top Menu** under the **Tools** (screwdriver/wrench icon) section, labeled **Time Sync Settings**.

### 2. Automatic vs. Manual Mode

* **Automatic Mode (Default):** The plugin fetches your timezone automatically via `ip-api.com`.
* **Manual Mode:** Enable this in the settings to use a specific timezone ID of your choice.

### 3. Setting a Manual Timezone

If you prefer not to use IP-based detection:

1. Select **Set Manual Timezone ID** in the plugin menu.
2. Enter a valid IANA Timezone ID (e.g., `Europe/London` or `Asia/Tokyo`).
3. Saving a timezone will automatically enable **Manual Mode**.

### 4. Force Syncing

To update your time immediately, ensure Wi-Fi is connected and select **Force Sync Now**.

## Technical Details

* **Time API:** The plugin calls `https://timeapi.io/api/Time/current/zone?timeZone=` to get accurate local time.
* **Geolocation API:** Uses `http://ip-api.com/line/?fields=timezone` to determine location when not in manual mode.
* **System Commands:** Updates the system clock using `date -s` and synchronizes the hardware clock with `hwclock -w`.
* **Settings Path:** User preferences and the last sync date are stored in `settings/timesync_fork_tracker.lua`.
