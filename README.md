# HashMan
**A high-speed TUI (Terminal User Interface) for managing .hash files.**

---

## Overview
`HashMan.ps1` is a high-speed TUI (Terminal User Interface) designed for managing `.hash` files. It allows users to seamlessly navigate complex directory structures, queue file verifications via corz checksum, and perform surgical line-item or full-file deletions.

### Operational Modes
The interface supports two primary layout views:
1. **Main Tree View**: Navigate through folder structures, expand directories, clear search filters, and manage the deletion or verification queues for entire hash containers or directories.
2. **Drill-Down View**: Step directly inside a specific `.hash` file to inspect individual entry lines, apply range-selections, and toggle individual line items for deletion or verification.

### Navigation & Controls
Standard keyboard shortcuts handle directory expansion and target selections within the interface:
* **[Arrows / PgUp / PgDn / Home / End]**: Standard movement within the tree and drill-down views.
* **[Right-Arrow / Enter]**: 
  * Main: Expand folder or 'Drill' into a .hash file to see entries.
  * Drill: Toggle file for verification.
* **[Left-Arrow]**: 
  * Main: Collapse folder or clear current search filter.
  * Drill: Return to the main tree view.
* **[Spacebar]**: Toggle the highlighted folder, file, or entry for verification.
* **[Delete]**: Toggle the highlighted file or entry for the Delete Queue.

---

## Usage Examples
```powershell
# Standard Execution (Launch the TUI in the current directory)
.\HashMan.ps1

# Display Internal Manual
.\HashMan.ps1 -Manual

# Launch with Development Debugging Enabled
.\HashMan.ps1 -DevDebug
```
## Parameter Reference

### Core Flags
| Flag | Description |
| :--- | :--- |
| `-Manual \| -h \| -help` | **Usage Guide:** Displays the internal manual and usage guide. |

### Advanced & Log Management Flags
| Flag | Description |
| :--- | :--- |
| `-DevDebug \| -Dev \| -DBG` | **Global Debugging:** Enables internal performance timers, payload count reporting, and real-time key-code logging for troubleshooting. |

---

## Action Shortcuts (Alt Keys)

| Shortcut | Description |
| :--- | :--- |
| `[Alt+V] Verify` | Executes the verification process for all items in the Verify Queue. |
| `[Alt+X] Delete` | Opens the Delete Task Summary to confirm removal of queued items. |
| `[Alt+S] Range Select` | **(Drill View Only)** Sets a starting anchor. Move the cursor and press Alt+S again to queue all entries between the anchor and cursor. |
| `[Alt+Del] Recursive` | **(Main View Only)** Toggles all .hash files within the selected folder and its subfolders for the Delete Queue. |
| `[Alt+C] Clear` | Clears the current search filter and resets any active range anchors. |

---

## Dependencies
* **corz checksum:** Required for verification tasks. Must be installed to `C:\Program Files\corz\checksum\checksum.exe`.

## Support & Maintenance
**This repository is provided "as-is" for archival purposes.** The author is not actively looking for feedback, feature requests, or bug reports. The issue tracker is disabled, and the author will not be responding to inquiries regarding setup or usage.

## Disclaimer
*This script executes deletion and validation operations on hash containers using external tools. While designed for structural safety, always ensure you have backups of your media before running batch operations across your storage volumes.*

---
> **Document Control**
> *This document is up-to-date with the following version of HashMan.*
> *2026.06.25__15.33.12*