# DevScope

**A lightweight, native macOS system monitoring tool.**

DevScope is an open-source macOS application built with Swift and SwiftUI. It provides a simple interface for inspecting running processes, monitoring system resources, and identifying applications listening on TCP ports.

The goal is to make system information accessible through a clean, fast, and native macOS experience.

## Features

- **System Overview** — View active ports, running processes, and port conflicts.
- **Process Inspector** — Inspect running processes, including their PID, parent PID, CPU usage, and memory usage.
- **Port Inspector** — View applications listening on TCP ports and identify port conflicts.
- **Resource Monitoring** — Monitor overall CPU and RAM usage.
- **Automatic Refresh** — Configure how frequently system information is refreshed.
- **Appearance Settings** — Choose between Light, Dark, and System appearance.

## Built With

- Swift
- SwiftUI
- macOS native system APIs
- Apple's Darwin and Foundation frameworks

## Requirements

- macOS 14.0 or later (depending on the configured deployment target)
- Xcode for building from source

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/ArihantSharma/DevScope.git
   ```

2. Open the Xcode project.

3. Select the DevScope scheme.

4. Build and run using Xcode.

## Project Status

DevScope is currently in its early development stage. Features and functionality may change as development continues.

## Privacy

DevScope is designed to inspect local system information. It does not require a user account or a remote backend.

## License

This project is licensed under the [MIT License](LICENSE).

You are free to use, modify, distribute, and build upon this software under the terms of the license.

## Author

**Arihant Sharma**

Creator and developer of DevScope.

- GitHub: [@ArihantSharma](https://github.com/ArihantSharma)

---

Built with Swift on macOS.
