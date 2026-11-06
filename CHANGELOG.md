# Social Googol SG Reader - Changelog & Version History

All notable changes to the **Social Googol SG Reader** application are documented in this file.

---

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
