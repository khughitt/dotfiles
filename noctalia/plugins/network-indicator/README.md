# NetworkIndicator Plugin for Noctalia

A compact Noctalia bar widget that displays current network upload (TX) and download (RX) activity, with optional live throughput values.

## Features

- **TX/RX Activity Indicators**: Separate icons for upload (TX) and download (RX).
- **Active/Idle Coloring**: Icons switch between “active” and “silent” colors based on a configurable traffic threshold.
- **Optional Throughput Values**: Displays formatted TX/RX speeds as text (shown only when the bar is spacious and horizontal).
- **Unit Formatting**: Automatically switches between KB/s and MB/s, or can be configured to always display MB/s.
- **Theme Support**: Uses Noctalia theme colors by default, with optional custom colors.
- **Configurable Settings**: Provides a comprehensive set of user-adjustable options.

## Installation

This plugin is part of the `noctalia-plugins` repository.

## Configuration

Access the plugin settings in Noctalia to configure the following options:

- **Icon Type**: Select the icon style used for TX/RX: `arrow`, `arrow-narrow`, `caret`, `chevron`.
- **Minimum Widget Width**: Enforce a minimum width for the widget.
- **Show Active Threshold**: Set the traffic threshold in bytes per second (B/s) above which TX/RX is considered “active”.
- **Show Values**: Display formatted TX/RX speeds as numbers. This option is automatically hidden on vertical bars and when using “mini” density.
- **Force Megabytes**: Always display values in MB/s instead of switching to KB/s at low traffic levels.
- **Vertical Spacing**: Adjust the spacing between the TX and RX elements.
- **Font Size Modifier**: Scale the text size.
- **Icon Size Modifier**: Scale the icon size.
- **Custom Colors**: When enabled, configure the following colors: TX Active, RX Active, RX/TX Inactive, and Text.

## Usage

- Add the widget to your Noctalia bar.
- Configure the plugin settings as required.

## Requirements

- Noctalia 3.6.0 or later.

## Technical Details

- The widget reads `SystemStatService.txSpeed` and `SystemStatService.rxSpeed`; therefore, the polling interval is determined by that service.
