# Social Googol's Pagify 🛡️
> **"Secure to Grow - सुरक्षा से ग्रोथ तक"**

Pagify is an ultra-lightweight, 100% offline, privacy-first Android document viewer and editor developed by **Social Googol**. It allows users to view and perform lightweight edits on PDF, Excel (.xlsx, .csv), Word (.docx), and PowerPoint (.pptx) documents without paying any subscription fees or uploading files to the cloud.

---

## 🌟 Key Highlights

* **100% Offline & Private:** Zero cloud uploads. All document rendering and parsing occurs directly inside the device's volatile memory.
* **Ultra-Lightweight Target (<18 MB):** Engineered to run smoothly on any budget or flagship Android device without bloated 100MB+ office engines.
* **Free & Sideloaded:** No Google Play Console fees ($0 distribution cost). Direct installation via APK.
* **Legal Shield & Complete Indemnity:** Features a mandatory first-launch End-User License Agreement (EULA) and strict "AS-IS" limitation of liability that completely shields Social Googol from data loss or file corruption claims.
* **Company Branding & Instant Connect:**
  * Developer: **Social Googol**
  * Website: [https://www.socialgoogol.com](https://www.socialgoogol.com)
  * Helpline: `+91 81262 10003` (`8126210003`)
  * Direct 1-tap Phone Call and WhatsApp chat buttons built into the app.
* **Biometric App Lock:** Optional fingerprint/PIN security lock for opening documents.
* **Auto-Update Notifier:** Checks `https://www.socialgoogol.com/app/version.json` on launch to notify users whenever an updated APK is released.

---

## 📂 Project Architecture

```
pagify/
├── .github/workflows/
│   └── build_apk.yml            # Free GitHub Actions workflow to build release APK
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml  # Scoped storage & app intent queries (Call, WhatsApp, Web)
├── lib/
│   ├── constants/
│   │   ├── branding.dart        # Social Googol brand assets, phone, URLs, taglines
│   │   └── legal_terms.dart     # Strict EULA & indemnity clauses
│   ├── models/
│   │   └── document_file.dart   # File metadata & type detection
│   ├── services/
│   │   ├── document_service.dart# Scoped file picker, PDF, Excel, Word & PPT engines
│   │   ├── security_service.dart# EULA state, SharedPreferences, Biometric Auth
│   │   └── update_service.dart  # In-app version checker
│   ├── screens/
│   │   ├── splash_screen.dart   # Animated brand splash screen
│   │   ├── eula_screen.dart     # Mandatory legal acceptance screen
│   │   ├── home_screen.dart     # Dashboard, format filter chips & recent documents
│   │   ├── pdf_viewer_screen.dart   # Zoomable PDF reader
│   │   ├── excel_editor_screen.dart # Interactive spreadsheet & cell editor
│   │   ├── docx_viewer_screen.dart  # Word document reader & search
│   │   ├── pptx_viewer_screen.dart  # PowerPoint slide deck viewer
│   │   └── about_screen.dart    # Social Googol company profile & direct contact
│   ├── widgets/
│   │   └── brand_banner.dart    # Persistent brand bar with Call, Web & WhatsApp
│   └── main.dart                # App entry point & dark slate theme
├── pubspec.yaml                 # Dependencies configuration
└── version.json                 # Sample update payload for your website
```

---

## 🚀 How to Build the APK (Two Zero-Cost Methods)

### Method 1: Automated Free Build via GitHub Actions (Recommended)
1. Initialize a Git repository inside this directory and push it to a private or public repository on [GitHub](https://github.com):
   ```bash
   git init
   git add .
   git commit -m "Initial commit for Social Googol Pagify"
   git branch -M main
   git remote add origin <YOUR_GITHUB_REPO_URL>
   git push -u origin main
   ```
2. Open the **Actions** tab on your GitHub repository.
3. The `Build Social Googol Pagify Release APK` workflow will run automatically.
4. Once completed (approx. 3-4 minutes), download the ready-to-use `Pagify-universal-release` or `Pagify-arm64-v8a-release` APK from the GitHub workflow artifacts.

### Method 2: Local Build via Flutter CLI
When Flutter is installed on your computer:
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Build production APK
flutter build apk --release

# The output APK will be generated at:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 🌐 Hosting & Direct Distribution

1. Upload the generated `app-release.apk` to your server:
   `https://www.socialgoogol.com/download/pagify-release.apk`
2. Upload `version.json` to:
   `https://www.socialgoogol.com/app/version.json`
3. Direct users to download the file directly from your website or send it over WhatsApp/Telegram.
4. Users simply tap the APK, enable **"Install unknown apps"**, and enjoy **Social Googol's Pagify** completely free!
