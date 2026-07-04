import 'package:flutter/material.dart';
import '../services/database_service.dart';

class LanguageProvider with ChangeNotifier {
  final DatabaseService _dbService;
  static const String kLanguageKey = 'selected_language';

  String _locale = 'en'; // 'en' or 'dv'

  LanguageProvider({required this._dbService}) {
    _loadLanguage();
  }

  String get locale => _locale;
  bool get isRtl => _locale == 'dv';

  Future<void> _loadLanguage() async {
    final savedLang = await _dbService.getSetting(kLanguageKey);
    if (savedLang != null) {
      _locale = savedLang;
      notifyListeners();
    }
  }

  Future<void> toggleLanguage() async {
    _locale = _locale == 'en' ? 'dv' : 'en';
    await _dbService.saveSetting(kLanguageKey, _locale);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (lang == 'en' || lang == 'dv') {
      _locale = lang;
      await _dbService.saveSetting(kLanguageKey, _locale);
      notifyListeners();
    }
  }

  String t(String key) {
    if (_locale == 'dv') {
      return _dvTranslations[key] ?? _enTranslations[key] ?? key;
    }
    return _enTranslations[key] ?? key;
  }

  static const Map<String, String> _enTranslations = {
    "title": "Municipal Issue Reporting",
    "council": "Addu City",
    "loginTitle": "Staff Login",
    "loginSubtitle": "Municipal Issue Reporting System",
    "preparingWorkspace": "Preparing workspace",
    "email": "Email Address",
    "usernameOrEmail": "Username or Email Address",
    "password": "Password",
    "signIn": "Sign In",
    "signingIn": "Signing In...",
    "language": "Dhivehi",
    "signOut": "Sign Out",
    "welcome": "Welcome",
    "role": "Role",
    "role_admin": "Admin",
    "role_entry": "Entry Officer",
    "role_readonly": "Read-only",
    "role_superadmin": "Super Admin",
    "addIssue": "Report New Issue",
    "editIssue": "Edit Issue",
    "viewDetails": "View Details",
    "issueUpdates": "Issue Updates",
    "viewUpdates": "View updates",
    "viewUpdatesHint": "Progress notes and activity history",
    "addUpdate": "Add Update",
    "updateNotes": "Update notes",
    "updateNotesHint": "What changed?",
    "updateHistory": "Update history",
    "noUpdates": "No updates have been added yet.",
    "updatesClosed": "This issue is complete. New updates cannot be added.",
    "updateAdded": "Update added successfully.",
    "retry": "Retry",
    "delete": "Delete",
    "save": "Save Changes",
    "cancel": "Cancel",
    "all": "All",
    "noIssues": "No issues reported matching filters.",
    "searchRoad": "Filter by issue title...",
    "filterCategory": "All Categories",
    "filterStatus": "All Statuses",
    "filterUser": "All Assigned Users",
    "createdIssues": "Created Issues",
    "colPhoto": "Photos",
    "colGps": "GPS",
    "colRoad": "Issue Title",
    "colCategory": "Category",
    "colDescription": "Description",
    "colStatus": "Status",
    "colCreatedBy": "Created By",
    "colUpdatedBy": "Last Updated By",
    "colAssignedTo": "Assigned To",
    "colCreatedAt": "Created At",
    "colActions": "Actions",
    "formRoadName": "Issue Title",
    "formCategory": "Issue Category",
    "formDescription": "Detailed Description",
    "formPhotos": "Upload Photos",
    "formGps": "GPS Location (Latitude, Longitude)",
    "formCaptureGps": "Auto-Capture GPS",
    "formCapturing": "Fetching GPS...",
    "formGpsSuccess": "GPS coordinates captured successfully",
    "formGpsError": "Failed to get location. Enter manually.",
    "formPhotosCount": "files selected",
    "status_pending": "Pending",
    "status_in_progress": "In Progress",
    "status_resolved": "Resolved",
    "status_rejected": "Rejected",
    "cat_street_lights": "Street Lights",
    "cat_land_plots": "Land Plots",
    "cat_roads_cleaning": "Roads Cleaning",
    "cat_damaged_roads": "Damaged Roads",
    "cat_waste_management": "Waste Management",
    "cat_drainage_issues": "Drainage Issues",
    "cat_mosque": "Mosque",
    "cat_parks_playgrounds": "Parks & Playgrounds",
    "cat_public_buildings": "Public Buildings",
    "cat_harbors_jetties": "Harbors & Jetties",
    "cat_beaches_coastal": "Beaches & Coastal Areas",
    "cat_cemeteries": "Cemeteries",
    "cat_public_toilets": "Public Toilets",
    "cat_stray_animals": "Stray Animals",
    "cat_other": "Other",
    "updateStatusTitle": "Update Status & Details",
    "assignToUser": "Assign to staff member",
    "unassigned": "Unassigned",
    "deleteConfirm":
        "Are you sure you want to delete this issue? This action is permanent.",
    "changePassword": "Change Password",
    "oldPassword": "Current Password",
    "newPassword": "New Password",
    "confirmPassword": "Confirm New Password",
    "addUser": "Add New Staff",
    "editUser": "Edit Staff Member",
    "colUsername": "Username",
    "colName": "Full Name",
    "colEmail": "Email Address",
    "colRole": "System Role",
  };

  static const Map<String, String> _dvTranslations = {
    "title": "މުނިސިޕަލް މައްސަލަ ރިޕޯޓްކުރުން",
    "council": "އައްޑޫ ސިޓީ",
    "loginTitle": "މުވައްޒަފުން ވަނުމަށް",
    "loginSubtitle": "މުނިސިޕަލް މައްސަލަ ރިޕޯޓްކުރާ ނިޒާމް",
    "preparingWorkspace": "ނިޒާމް ތައްޔާރުކުރަނީ",
    "email": "އީމެއިލް އެޑްރެސް",
    "usernameOrEmail": "ޔޫސަރނޭމް ނުވަތަ އީމެއިލް",
    "password": "ޕާސްވޯޑް",
    "signIn": "ވަނުން",
    "signingIn": "ވަންނަނީ...",
    "language": "English",
    "signOut": "ސައިން އައުޓް",
    "welcome": "މަރުޙަބާ",
    "role": "މަގާމު",
    "role_admin": "އެޑްމިން",
    "role_entry": "އެންޓްރީ އޮފިސަރު",
    "role_readonly": "އިންސްޕެކްޓަރު",
    "role_superadmin": "ސުޕަރ އެޑްމިން",
    "addIssue": "އާ މައްސަލައެއް ހުށަހެޅުން",
    "editIssue": "ބަދަލު ގެނައުން",
    "viewDetails": "ތަފްސީލް ބެލުން",
    "delete": "ފޮހެލާ",
    "save": "ބަދަލުތައް ރައްކާކުރޭ",
    "cancel": "ކެންސަލް",
    "all": "ހުރިހާ",
    "noIssues": "މި ފިލްޓަރާ ދިމާވާ އެއްވެސް މައްސަލައެއް ނެތް.",
    "searchRoad": "މައްސަލައިގެ ސުރުޚީން ހޯދާ...",
    "filterCategory": "ހުރިހާ ދާއިރާތައް",
    "filterStatus": "ހުރިހާ ހާލަތްތައް",
    "filterUser": "ހަވާލުކުރެވިފައިވާ ހުރިހާ މުވައްޒަފުން",
    "createdIssues": "ހުށަހަޅާފައިވާ މައްސަލަތައް",
    "colPhoto": "ފޮޓޯ",
    "colGps": "ޖީޕީއެސް",
    "colRoad": "މައްސަލައިގެ ސުރުޚީ",
    "colCategory": "ދާއިރާ",
    "colDescription": "ތަފްސީލް",
    "colStatus": "ހާލަތު",
    "colCreatedBy": "ހުށަހެޅީ",
    "colUpdatedBy": "އިސްލާހުކުރީ",
    "colAssignedTo": "ހަވާލުކުރީ",
    "colCreatedAt": "ހުށަހެޅި ތާރީޚް",
    "colActions": "އަމަލުތައް",
    "formRoadName": "މައްސަލައިގެ ސުރުޚީ",
    "formCategory": "މައްސަލައިގެ ދާއިރާ",
    "formDescription": "ތަފްސީލް ބަޔާން",
    "formPhotos": "ފޮޓޯ އަޕްލޯޑް ކުރޭ",
    "formGps": "ޖީޕީއެސް ލޮކޭޝަން (ލެޓިޓިއުޑް، ލޮންގިޓިއުޑ)",
    "formCaptureGps": "ޖީޕީއެސް އޮޓޯއިން ހޯދާ",
    "formCapturing": "ލޮކޭޝަން ހޯދަނީ...",
    "formGpsSuccess": "ޖީޕީއެސް ކޯޑިނޭޓް ހޯދިއްޖެ",
    "formGpsError": "ލޮކޭޝަން ނުލިބުނު. އަމިއްލައަށް ލިޔުއްވާ.",
    "formPhotosCount": "ފައިލް ހޮވިއްޖެ",
    "status_pending": "މަޑުޖެހިފައި",
    "status_in_progress": "ހިނގަމުންދަނީ",
    "status_resolved": "ހައްލުކުރެވިފައި",
    "status_rejected": "ނޫނެކޭ ބުނެފައި",
    "cat_street_lights": "މަގު ބައްތި",
    "cat_land_plots": "ބަންޑާރަ ގޯތި",
    "cat_roads_cleaning": "މަގުތައް ކުނިކެހުން",
    "cat_damaged_roads": "ހަލާކުވެފައިވާ މަގުތައް",
    "cat_waste_management": "ކުނި މެނޭޖްކުރުން",
    "cat_drainage_issues": "ނަރުދަމާ މައްސަލަ",
    "cat_mosque": "މިސްކިތް",
    "cat_parks_playgrounds": "ޕާކުތަކާއި ކުޅޭ ބިން",
    "cat_public_buildings": "އާންމު އިމާރާތްތައް",
    "cat_harbors_jetties": "ބަނދަރާއި ޖެޓީ",
    "cat_beaches_coastal": "ބީޗްތަކާއި ކަނޑުދޮށް",
    "cat_cemeteries": "ކަށިވަޅު",
    "cat_public_toilets": "އާންމު ފާހާނާ",
    "cat_stray_animals": "ވަލު ޖަނަވާރު",
    "cat_other": "އެހެނިހެން",
    "updateStatusTitle": "ހާލަތާއި ތަފްސީލް ބަދަލުކުރުން",
    "assignToUser": "މުވައްޒަފަކާ ހަވާލުކުރޭ",
    "unassigned": "ހަވާލު ނުކުރޭ",
    "deleteConfirm":
        "މި މައްސަލަ ފޮހެލަން ބޭނުންކަން ޔަގީންތަ؟ މިއީ އަނބުރާ ގެނެވޭނެ އަމަލެއް ނޫނެވެ.",
    "changePassword": "ޕާސްވޯޑް ބަދަލުކުރޭ",
    "oldPassword": "ކުރީގެ ޕާސްވޯޑް",
    "newPassword": "އާ ޕާސްވޯޑް",
    "confirmPassword": "އާ ޕާސްވޯޑް ކަށަވަރުކުރޭ",
    "addUser": "އާ މުވައްޒަފަކު އިތުރުކުރުން",
    "editUser": "މުވައްޒަފުގެ މައުލޫމާތު ބަދަލުކުރުން",
    "colUsername": "ޔޫސަރނޭމް",
    "colName": "ފުރިހަމަ ނަން",
    "colEmail": "އީމެއިލް އެޑްރެސް",
    "colRole": "މަގާމު",
  };
}
