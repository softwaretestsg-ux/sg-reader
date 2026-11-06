# Social Googol SG Reader - Changelog & Version History

All notable changes to the **Social Googol SG Reader** application are documented in this file.

---

## [1.3.1] - 2026-11-06 (Build 15)
### Added
- **Recent Documents Management & Clear Capabilities:**
  - **1-Tap "Clear All" with Confirmation:** Added a prominent `[🗑 Clear All]` button directly on the Recent Documents section header with a safety confirmation dialog. Clears the recents history without deleting files from storage.
  - **Swipe-to-Dismiss:** Users can swipe any document entry left-to-right or right-to-left to remove it from the recent list with an instant "Undo" toast.
  - **3-Dots Document Menu:** Each recent document now features an intuitive overflow menu with:
    - 📄 Open Document
    - 📤 Share File (WhatsApp / Email)
    - ❌ Remove from Recents
    - 🗑️ Delete Permanently (with confirmation)
  - **Drawer Clear Option:** Added a dedicated "Clear Recent Documents" option in the App Drawer.

---

## [1.3.0] - 2026-11-06 (Build 14)
### Added
- **In-Built Document Scanner & Auto-Refiner:**
  - Multi-page document camera capture and gallery photo import.
  - 100% offline background image enhancement algorithms:
    - 🪄 **Magic Auto-Refine:** Automatically neutralizes shadows, balances brightness, and sharpens text contours for professional document clarity.
    - 📄 **Crisp B&W:** High-contrast document binarization for clean printouts and pure white paper backgrounds.
    - 🔘 **Grayscale:** Smooth 8-bit document scanning.
    - 🎨 **Enhanced Color:** Intensifies colors for official stamps, signatures, colored letterheads, and certificates.
    - 🔄 **90° Rotation:** Rotate pages in any direction with instant preview.
- **Universal Multi-Format Export Engine:**
  - On completing a scan, users can save and export their documents into any desired format:
    - 📕 **PDF Document (.pdf):** Standard multi-page document layout, edge-to-edge scaling.
    - 📘 **Word Document (.docx):** Valid OpenXML document with embedded full-page scans, immediately editable in SG Reader and Microsoft Word.
    - 🖼️ **High-Resolution Images (.jpg):** Clean enhanced image files saved to device storage.
    - 🗂️ **Compressed ZIP Package (.zip):** Archive containing all scanned pages and text manifest.
- **Immediate In-App Integration:**
  - Automatically indexes newly scanned documents into the "Recent Documents" dashboard with 1-tap options to "Open in SG Reader" or "Share via WhatsApp / Email".
  - Added dual quick-action buttons on the Home dashboard: `[ 📸 Scan Doc ]` and `[ 📁 Open File ]`.

---

## [1.2.0] - 2026-11-06 (Build 13)
### Fixed
- **Full Document Page Flow & Layout:** Resolved the critical Blink flexbox height collapse issue that truncated Word document pages halfway down the screen. Changed document container from a constrained flex item to a full, continuous paper canvas (`display: block; height: auto !important`) on a neutral desktop (`#ECE8E1`). All pages, paragraphs, and multi-column tables are now 100% visible with crisp, high-contrast `#1A1A1A` text.
- **Responsive Resume & Table Formatting:** Added `width: 100% !important; table-layout: auto; word-break: break-word;` for all embedded tables, preventing resumes with complex layouts from spilling or clipping off-screen.
- **Direct In-Line Document Editing:** Removed confusing modal dialogs. Users can now tap directly anywhere in the text to position cursor, type, or select text, with a streamlined top formatting toolbar and quick paragraph actions (`+ Add Paragraph`, `🗑 Delete Line`, `Clear Style`, `Scroll to Top / Bottom`).
- **Real-Time Document Metrics:** Added automatic calculation of total estimated pages and word count (`N Pages • X words`) in the Word Processor header.
- **Robust Multi-Layer File Type Detection:** Enhanced Android `MainActivity.kt` and Dart `DocumentFile.detectType` to detect document types via file extension, Android MIME type, and file header magic bytes (`%PDF`, `PK\x03\x04` zip structure, and `0xD0 0xCF 0x11 0xE0` OLE2 compound files). Files shared from WhatsApp or Files without an explicit extension now open automatically in the correct editor.
- **Fallback Format Picker:** If an unrecognized file format is opened, the app prompts the user with an intuitive format picker dialog instead of failing.

## [1.1.0] - 2026-11-06 (Build 12)
### Added
- **Version Indicator on Initial Loading Page:** Added visible version badge (`Version v1.1.0 • Build 12`) on the initial launch `SplashScreen` and app footer so users always know their installed build version.
- **Dynamic In-Place Updates:** Configured automated `--build-number` and `--build-name` tracking in GitHub Actions CI/CD to eliminate the need to uninstall previous builds before updating.
- **Direct WhatsApp / Files "Open With" Integration:** Implemented native `MainActivity.kt` Intent handler and Flutter `MethodChannel` (`com.socialgoogol.sgreader/open_file`). When any document is tapped in WhatsApp, Gmail, Telegram, or File Manager, SG Reader automatically detects the document type, copies the file securely to sandbox cache, and launches the appropriate viewer/editor immediately.
- **Mobile Active Cell & Formula Bar (Spreadsheets):** Added a dedicated touch editing bar at the top of the spreadsheet with current cell badge (`[Cell: A1]`), full keyboard input, formula injection (`=SUM`, `=AVERAGE`), row insertion below, column insertion right, and row deletion.
- **Dynamic Full Page Rendering (Excel):** Removed static 100-row clamping; dynamic grid now scales to actual workbook dimensions (`Math.max(rows + 50, 200)` and `Math.max(cols + 15, 30)`).
- **Focus Edit Modal (Word Processor):** Added smart 1-tap block selection and a clean editing modal with full keyboard control to edit, add, or delete specific lines and paragraphs without fighting Android touch selection handles.
- **Continuous Flow PDF Rendering:** Enabled `PdfPageLayoutMode.continuous` and vertical scrolling for seamless multi-page PDF viewing.

### Fixed
- **Status Bar Collision:** Moved the Social Googol branding header out of `Scaffold.appBar` and into the body `SafeArea(top: true)` with a 10px safe buffer, ensuring complete clearance below the status bar (time, Wi-Fi, battery %, camera punch-hole).

---

## [1.0.5] - 2026-11-06 (Build 11)
### Fixed
- Upgraded Android NDK version to `28.2.13676358` in `android/app/build.gradle` to resolve native plugin compilation dependency warnings.
- Added `_hasUnsavedEdits` state field in `PptxViewerScreen`.

---

## [1.0.4] - 2026-11-06 (Build 10)
### Added
- **Path B Production Offline Suite Engine:** Bundled **SheetJS** (`xlsx.full.min.js`) and **x-spreadsheet** in app assets (`assets/offline_editors/excel/`) to provide real spreadsheet editing with formulas.
- **Legacy Excel Support:** Enabled opening, rendering, and editing of legacy `.xls` (BIFF8 binary compound structure) in addition to `.xlsx` and `.csv`.
- **WYSIWYG Word Processor:** Bundled **Mammoth.js** and **html-docx.js** (`assets/offline_editors/word/`) to provide real in-line Word document editing with formatting toolbar (Bold, Italic, Headings, Lists, Alignment).

---

## [1.0.2] - 2026-11-06 (Build 5)
### Added
- Official Social Googol app launcher mipmap icons across all Android display densities (MDPI, HDPI, XHDPI, XXHDPI, XXXHDPI).
- Anchored deterministic release keystore (`socialgoogol_release.jks`) with v1 and v2 signing schemes.

### Fixed
- Removed misleading `<  >` navigation arrows from the lower bottom panel of the PDF viewer.

---

## [1.0.0] - 2026-11-06 (Build 1)
### Added
- Initial release of **Social Googol's SG Reader** for Android.
- 100% Offline processing sandbox with zero cloud tracking.
- Mandatory legal EULA & strict indemnity disclaimer protecting Social Googol from liabilities.
- Biometric & PIN app lock.
- Support for PDF, Excel, Word, and PowerPoint formats.
