# Snap Sweep

**Snap Sweep** is a smart iOS photo management utility built with SwiftUI. It helps users reclaim storage by identifying screenshots, blurry photos, large videos, and similar "burst" photos using local processing.

**Developed by Kendall Starcevich, Maia Bentley, & Carla Segura** *Computer Science Capstone | Drake University*

## Key Features

* **Smart Similarity Scan:** Groups similar photos taken in short succession. Uses **Batch Scanning** (Newest, Oldest, or specific Year) to handle massive libraries without timing out.
* **Map Sweeper:** Visualize your photo library on an interactive map. Group photos by location to find and clean up "vacation clutter."
* **Blur Detection:** Local ML-based scanning to identify out-of-focus shots.
* **Protected Vault:** Securely "Keep" photos by marking them as protected, ensuring they are excluded from future scan results.
* **Storage Analytics:** Real-time gauge showing system storage and how much space you've reclaimed using the app.

## Tech Stack

* **UI:** SwiftUI
* **Frameworks:** Photos Framework, MapKit, Combine
* **Storage:** UserDefaults (for protection metadata and deletion tracking)

---

## How to Reproduce & Test (Simulator)

Testing photo-heavy apps in the Xcode Simulator can be tricky because the default simulator library only has 5-10 images. Follow these steps to test the full functionality:

### 1. Requirements
* Xcode 15+
* iOS 17.0+ Simulator

### 2. Setup the Simulator Library
To test **Similarity** and **Map Sweeper**, you need more than the default photos:
   *  **Drag & Drop:** Drag a folder of images from your Mac directly onto the Simulator window.

### 3. Run the Project
1.  Clone the repository: `git clone https://github.com/kendallstarcevich/SnapSweep.git`
2.  Open `SnapSweep.xcodeproj` in Xcode.
3.  Select a simulator (e.g., iPhone 15 Pro).
4.  Press `Cmd + R` to build and run.
5.  **Permission:** Accept the "Photos Library" access prompt on the first launch.

---

## Privacy & Safety
Snap Sweep performs all analysis **on-device**. No photo data or location metadata is ever transmitted to a server. Deletions use the standard system prompt, moving photos to the "Recently Deleted" album for safety.

---
