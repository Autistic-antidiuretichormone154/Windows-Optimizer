# 🛠️ WinOptimizer v2.1

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/NishantJLU/Windows-Optimizer?color=blue&style=flat-square)](https://github.com/NishantJLU/Windows-Optimizer/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![OS: Windows](https://img.shields.io/badge/OS-Windows-0078D6?logo=windows&style=flat-square)](https://www.microsoft.com/windows)

A comprehensive, modular Windows 10/11 optimization and setup utility designed for power users, developers, and gamers. This script automates system maintenance, privacy hardening, and software installation via a simple, data-driven CLI interface.

---

## 🚀 Quick Start

### Option 1: The "One-Liner" (Recommended)
Open **PowerShell as Administrator** and run:
```powershell
irm nishantjlu.github.io/Windows-Optimizer/Run.ps1 | iex
```
*Note: This downloads the latest components to a temporary folder and launches the utility.*

### Option 2: Manual Install
1.  **Download:** Grab the latest **[WinOptimizer-v2.1.zip](https://github.com/NishantJLU/Windows-Optimizer/releases/latest)**.
2.  **Extract:** Unzip the folder to a location of your choice.
3.  **Launch:** Right-click `Launch-WinOptimizer.bat` and select **Run as Administrator**.

---

## ❓ Why WinOptimizer?
While there are many Windows optimization scripts, WinOptimizer focuses on **transparency and safety**:
*   **🛡️ Safety First:** Automatically creates a **System Restore Point** before any changes are made.
*   **🔄 Modular Backups:** WinOptimizer exports a `.reg` backup for *every single change*. If a specific tweak causes issues, you can restore just that one setting from `C:\WinOptimizer\backups`.
*   **⚙️ Data-Driven:** No need to dive into PowerShell code. All bloatware lists, registry tweaks, and dev apps are managed in a simple `config.json`.
*   **📜 Full Logging:** Every action is logged to `C:\WinOptimizer\logs` with timestamps and status reports.

---

## 💬 Community & Feedback
*   **Discussion:** Have a suggestion or need help? [Join the Discussion](https://github.com/NishantJLU/Windows-Optimizer/discussions).
*   **Bugs:** Found a bug? [Open an Issue](https://github.com/NishantJLU/Windows-Optimizer/issues).
*   **Support:** If this tool helped you, please consider giving it a ⭐!

---

## 👤 User Profiles (New in v2.1)
WinOptimizer now supports smart profiles to automate your setup based on your needs:

*   **🎮 Gamer:** Focuses on pure performance. Removes all Xbox services, social bloat, and optimizes power plans for zero-latency gaming.
*   **💻 Developer:** Turns a fresh Windows install into a workstation. Automatically installs **Git, Node.js, Python 3, VS Code, and Docker Desktop** via Winget.
*   **🍃 Minimalist:** A "light touch" profile. Removes only the most intrusive bloatware and applies essential privacy hardening.
*   **⚙️ Manual:** Skip the automation and pick-and-choose from the 15 available modules.

---

## 🛠 Features & Modules

### 1-5: System Maintenance
*   **Bloatware Nuke:** Removes pre-installed UWP apps (Teams, Bing, Xbox, etc.).
*   **Startup Booster:** Disables hidden startup items and telemetry-heavy scheduled tasks.
*   **Junk Cleaner:** Reclaims GBs of space by cleaning Temp files, Prefetch, and DISM component stores.

### 6-10: Performance & Privacy
*   **Privacy Hardener:** Disables Telemetry, Advertising IDs, and Bing-in-Start menu.
*   **Gaming Mode:** One-click toggle for High-Performance power plans and Defender pausing.
*   **Visual Tweaks:** Disables animations and transparency for maximum UI responsiveness.

### 11-15: Power Tools & Safety
*   **Safe Uninstall:** A deep-scanning uninstaller that finds hidden registry-based apps.
*   **Focus Mode:** A timer-based website blocker for productivity (auto-unblocks via Scheduled Task).
*   **Update All:** One-command to update every app on your system via Winget.
*   **🔄 Restore Center:** (New) Dedicated menu to merge registry backups or launch System Restore.

---

## 🔄 Safety & Recovery
Your system's safety is our priority:
1.  **Restore Points:** Created automatically before any optimization begins.
2.  **Registry Backups:** Every single registry change is exported to `.reg` files in `C:\WinOptimizer\backups`.
3.  **Restore Center:** Use **Module 15** to pick a backup and undo any specific change instantly.
4.  **Logging:** Detailed execution history is saved to `C:\WinOptimizer\logs`.

---

## ⚙️ Customization (`config.json`)
You can customize the script without editing the code! Open `config.json` to:
*   Add/remove apps from the **Bloatware** lists.
*   Change the **Developer App** suite.
*   Add your own custom **Registry Tweaks** or **Services** to disable.

---

## ⚠️ Disclaimer
*This utility makes system-level changes to the Windows Registry and System Services. While every effort has been made to include safety features, the author is not responsible for any system instability. Always ensure your important data is backed up before running system optimization tools.*

---
**Created by [NishantJLU](https://github.com/NishantJLU)**
