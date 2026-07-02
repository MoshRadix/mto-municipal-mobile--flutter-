# Implementation Plan - Municipal Issue Reporting Flutter App

Bilingual (English/Dhivehi) municipal issue reporting mobile application for Addu City Council, featuring offline-first capabilities, role-based access control, automatic GPS location tracking, and camera photo overlay watermarking.

## User Review Required

> [!IMPORTANT]
> **API Base URL Configuration:**
> The Flutter app will communicate with the local Next.js server (`http://10.0.2.2:3000` for Android emulator, `http://localhost:3000` for iOS simulator, or a production Vercel URL like `https://mto-municipal.vercel.app`). We will make the Base URL configurable via the settings screen, defaulting to `https://mto-municipal.vercel.app`.

> [!IMPORTANT]
> **Authentication Bridge with NextAuth:**
> Since the Next.js API uses NextAuth (session cookies), the Flutter app will authenticate by:
> 1. Fetching the CSRF token from `/api/auth/csrf`.
> 2. Sending a `POST` request to `/api/auth/callback/credentials` with the credentials and CSRF token.
> 3. Capturing and saving the returned `next-auth.session-token` cookie.
> 4. Attaching this cookie in the `Cookie` header for all subsequent API requests.
> This ensures seamless compatibility with the existing web app's authorization guards.

> [!WARNING]
> **Permissions Requirements:**
> To support automatic GPS capture and camera watermarking, the app will request the following device permissions:
> - **Android:** `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`.
> - **iOS:** Location when in use description, Camera usage description, and Photo Library usage description in `Info.plist`.

## Open Questions

None. The fields, design requirements, and backend APIs are fully documented.

---

## Proposed Changes

### Project Initialization & Config

#### [NEW] [pubspec.yaml](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/pubspec.yaml)
Defines project dependencies:
- State Management: `provider`
- API calls: `http`, `flutter_secure_storage`, `shared_preferences`
- Database: `hive` & `hive_flutter` for offline drafts
- Location: `geolocator` (for coordinates), `geocoding` (for readable address)
- UI: `flutter_svg`, `intl` (date/time formatting)
- Image Capture: `image_picker`
- Dev Dependencies: `hive_generator`, `build_runner`

#### [NEW] [Faruma.ttf](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/assets/fonts/Faruma.ttf)
Thaana script font for Dhivehi, downloaded from the jsDelivr CDN.

#### [NEW] [logo.png](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/assets/images/logo.png)
Addu City Council logo copied from the Next.js web application.

---

### Data Models

#### [NEW] [user.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/models/user.dart)
Represents the authenticated user profile (ID, name, email, role).

#### [NEW] [issue.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/models/issue.dart)
Represents a municipal issue. Includes support for:
- JSON serialization/deserialization.
- Mapping to local Hive database (offline drafts).
- Status fields (`pending`, `in_progress`, `resolved`, `rejected`).

---

### Services & Providers

#### [NEW] [api_service.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/services/api_service.dart)
Handles HTTP communication with the Next.js API. Includes:
- NextAuth cookie authentication (CSRF token extraction + session token persistence).
- Fetching issues, updating issue status/assignee.
- Multipart POST requests for reporting issues (attaching multiple photos).

#### [NEW] [database_service.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/services/database_service.dart)
Manages the local database (Hive) for storing offline drafts, user profiles, and app configuration.

#### [NEW] [location_service.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/services/location_service.dart)
Retrieves the device's latitude/longitude and uses reverse geocoding to find the readable street address.

#### [NEW] [watermark_service.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/services/watermark_service.dart)
Uses Flutter's low-level `ui.Canvas` and `ui.PictureRecorder` to overlay a translucent panel on the captured photo.
Overlay specifications:
- Organization Name: "Addu City Council"
- Road Name (form input)
- GPS coordinates (latitude, longitude) + readable address
- Date & time in Maldives format (e.g. Wednesday, 1 July 2026 23:07 PM)
- Text layout handles both LTR and RTL text dynamically.

#### [NEW] [sync_service.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/services/sync_service.dart)
Handles background connectivity monitoring (using `connectivity_plus` or network status polling) and uploads local drafts once a connection is detected.

#### [NEW] [auth_provider.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/providers/auth_provider.dart)
Exposes login/logout state and roles (`entry`, `read-only`, `admin`).

#### [NEW] [issue_provider.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/providers/issue_provider.dart)
Manages local drafts, fetched issues, status updates, and coordinates sync states.

#### [NEW] [language_provider.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/providers/language_provider.dart)
Handles switching between English and Dhivehi, updating locale and text direction (RTL/LTR).

---

### UI Views & Screens

#### [NEW] [splash_screen.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/views/splash_screen.dart)
Branded entrance screen displaying the Addu City Council logo with a smooth fading animation.

#### [NEW] [login_screen.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/views/login_screen.dart)
Login UI featuring:
- Username/Email and password inputs.
- High-fidelity Addu City Council branding.
- Quick-login preset buttons (Admin, Entry Officer, Inspector) for quick developer testing.
- Language switcher (English / Dhivehi).

#### [NEW] [dashboard_screen.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/views/dashboard_screen.dart)
Main dashboard showing:
- Quick stats cards (total, pending, resolved issues) categorized by status.
- Issues list showing thumbnails, category, road, and status badges.
- Filter options (filter by status, category, road, assignment).
- Role-based FAB: "Report Issue" button visible only to Admin and Staff/Entry level users.
- Manual "Sync Now" indicator when drafts are pending.

#### [NEW] [issue_form_screen.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/views/issue_form_screen.dart)
The bilingual issue submission form matching the web fields:
- Road Name: Text field.
- Issue Category: Dropdown selector (Street Lights, Land Plots, Roads Cleaning, Damaged Roads, Waste Management, Drainage, Other).
- Description: Multi-line text field.
- GPS Location: Automatic coordinate fetching with fallback text entry. Displays the resolved address.
- Photos: Multi-image picker (camera/gallery) with real-time watermark overlay generation and progress indicator.
- Submit Button: If offline, saves to drafts. If online, posts directly.

#### [NEW] [issue_detail_screen.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/views/issue_detail_screen.dart)
Displays full issue description, GPS coordinates on maps, audit log, and original watermarked images.
- Admin: Can update status, delete the issue, or assign to staff.
- Staff (Entry): Can update status/details if they created the issue.
- Inspector (Read-only): View only.

#### [NEW] [settings_screen.dart](file:///f:/dev2026/mto-municipal-mobile%20(flutter)/lib/views/settings_screen.dart)
Provides options to change language (EN/DV), view role details, trigger manual sync, and configure the API Base URL.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure clean compile and no lint issues.
- Verification script in `test/` to check watermark overlay calculations on sample canvas.

### Manual Verification
1. **Splashing & Branding:** Start the app, confirm Addu City Council logo and name display correctly.
2. **Localization:** Switch language to Dhivehi on login and settings screens. Verify Thaana script rendering with Faruma font and right-to-left layout alignment.
3. **Role Enforcement:**
   - Log in as `readonly@addu.gov.mv`. Verify the "Report Issue" button is hidden.
   - Log in as `entry@addu.gov.mv`. Verify the "Report Issue" button appears.
   - Log in as `admin@addu.gov.mv`. Verify ability to update assignment.
4. **Watermarking:** Select a photo from the gallery or take a picture. Verify that a translucent panel is added to the bottom showing road, GPS coordinates, local Maldives date/time, and "Addu City Council".
5. **Offline Operations:**
   - Turn off Wi-Fi/data or configure a fake offline API URL.
   - Submit an issue. Verify the app displays a toast saying "Saved as draft (offline)" and shows the draft in the dashboard.
   - Re-enable connection (or click "Sync Now"). Verify the draft is uploaded to the backend and removed from local drafts.
