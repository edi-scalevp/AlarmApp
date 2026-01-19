# WakeUp - Social Accountability Alarm App

## Current Status

**GitHub**: https://github.com/edi-scalevp/AlarmApp

### What's Done
- [x] All Swift source code (37 files, 8,300+ lines)
- [x] Xcode project file with main app + widget extension targets
- [x] Firebase Cloud Functions (TypeScript)
- [x] Project documentation
- [x] Setup instructions and test plan
- [x] Pushed to GitHub

### What's Next (Manual Steps Required)
See `SETUP_AND_TEST_PLAN.md` for detailed instructions. Summary:

1. **Create Firebase Project** - console.firebase.google.com
2. **Enable Phone Auth** - Firebase → Authentication → Phone
3. **Create Firestore DB** - Firebase → Firestore → Create database
4. **Download GoogleService-Info.plist** - Add iOS app in Firebase
5. **Create APNs Key** - Apple Developer → Keys → APNs
6. **Upload APNs to Firebase** - Firebase → Cloud Messaging
7. **Open Xcode** - `open AlarmApp.xcodeproj`
8. **Add GoogleService-Info.plist** - Drag into AlarmApp folder
9. **Add Firebase SDK** - File → Add Package Dependencies → firebase-ios-sdk
10. **Configure Signing** - Select team, fix bundle ID if needed
11. **Add Capabilities** - Push Notifications, Background Modes
12. **Deploy Cloud Functions** - `cd functions && npm install && firebase deploy`
13. **Add Firestore Rules** - Copy from SETUP_AND_TEST_PLAN.md
14. **Run on Device** - Connect iPhone, build & run

### Quick Commands
```bash
# Open project
open /Users/edi/Projects/AlarmApp/AlarmApp.xcodeproj

# View setup guide
open /Users/edi/Projects/AlarmApp/SETUP_AND_TEST_PLAN.md

# Deploy cloud functions
cd /Users/edi/Projects/AlarmApp/functions && npm install && firebase deploy --only functions
```

---

## Project Overview

A bulletproof iPhone alarm app with social accountability. If you don't dismiss your alarm in time, your friend gets notified to help wake you up.

### Key Features
- **AlarmKit Integration**: System-level alarms that break through Silent Mode and Do Not Disturb
- **Live Activities**: Lock Screen and Dynamic Island display with dismiss/snooze actions
- **Firebase Phone Auth**: SMS-based authentication, no passwords needed
- **Contact-Based Friends**: Find friends automatically via phone number matching
- **Social Escalation**: Friends get push notifications if you oversleep

## Tech Stack

| Component | Technology |
|-----------|------------|
| Platform | iOS 17+ (targeting iOS 26 for AlarmKit) |
| UI Framework | SwiftUI with `@Observable` pattern |
| Local Storage | SwiftData |
| Authentication | Firebase Phone Auth |
| Database | Firebase Firestore |
| Push Notifications | Firebase Cloud Messaging |
| Backend | Firebase Cloud Functions (TypeScript) |
| Live Activities | ActivityKit + WidgetKit |

## Project Structure

```
AlarmApp/
├── AlarmApp.xcodeproj/            # Xcode project
├── AlarmApp/
│   ├── AlarmApp.swift             # App entry point, SwiftData setup
│   ├── AppDelegate.swift          # Firebase & push notification config
│   ├── Info.plist
│   ├── Models/
│   │   ├── User.swift             # User profile with phone auth
│   │   ├── Alarm.swift            # Alarm with escalation settings
│   │   ├── Friend.swift           # Friend relationship
│   │   └── FriendRequest.swift    # Friend request flow
│   ├── Services/
│   │   ├── AuthenticationService.swift   # Firebase Phone Auth
│   │   ├── AlarmKitService.swift         # AlarmKit + Live Activities
│   │   ├── ContactsService.swift         # Contact access & hashing
│   │   ├── FirestoreService.swift        # Database operations
│   │   └── EscalationService.swift       # Friend notification logic
│   ├── Repositories/
│   │   ├── AlarmRepository.swift  # Alarm CRUD + scheduling
│   │   └── FriendRepository.swift # Friends & contact discovery
│   └── Features/
│       ├── Authentication/Views/  # Phone entry, SMS code, onboarding, profile
│       ├── Alarms/Views/          # Alarm list, create, edit, components
│       ├── Friends/Views/         # Friends list, add friend, requests
│       └── Settings/Views/        # Settings, profile editing
├── AlarmWidgetExtension/
│   ├── AlarmActivityAttributes.swift    # Live Activity data model
│   ├── AlarmLiveActivity.swift          # Lock Screen & Dynamic Island UI
│   └── Info.plist
├── functions/                     # Firebase Cloud Functions
│   ├── src/index.ts               # All cloud functions
│   ├── package.json
│   └── tsconfig.json
├── SETUP_AND_TEST_PLAN.md         # Detailed setup + 25 test cases
├── README.md                      # GitHub readme
└── claude.md                      # This file
```

## Core Flows

### Authentication Flow
1. User enters phone number with country code
2. Firebase sends SMS verification code
3. User enters 6-digit code (auto-filled from SMS)
4. New users see onboarding explaining the concept
5. Profile setup: display name and optional photo

### Alarm Creation Flow
1. Select time using wheel picker
2. Set label, repeat days, sound
3. Enable "Social Accountability" toggle
4. Select friend(s) to notify
5. Choose delay (2, 5, 10, or 15 minutes)
6. Optional custom message

### Escalation Flow
```
Alarm fires → Live Activity shows on Lock Screen →
  User has X minutes to dismiss →
    ├─ Dismissed in time: Success, friend NOT notified
    └─ Not dismissed: Cloud Function sends push to friend
```

### Friend Discovery Flow
1. User grants Contacts permission
2. App hashes phone numbers locally (SHA256)
3. Hashes sent to backend
4. Backend matches against registered users
5. Matched contacts shown with "Add" button
6. Non-registered contacts can be invited

## Cloud Functions

Located in `functions/src/index.ts`:

| Function | Trigger | Purpose |
|----------|---------|---------|
| `findFriendsFromContacts` | HTTPS callable | Match phone hashes to registered users |
| `onAlarmTriggered` | HTTPS callable | Create escalation event when alarm fires |
| `onAlarmDismissed` | HTTPS callable | Cancel escalation when user dismisses |
| `onAlarmSnoozed` | HTTPS callable | Extend escalation deadline |
| `processEscalations` | Scheduled (1 min) | Send push to friends for pending escalations |
| `onFriendRequestCreated` | Firestore trigger | Send push for new friend requests |
| `onFriendRequestAccepted` | Firestore trigger | Send push when request accepted |
| `getWakeUpStats` | HTTPS callable | Get user's alarm statistics |
| `getEscalationHistory` | HTTPS callable | Get past escalation events |
| `canNotifyFriend` | HTTPS callable | Check rate limits before notifying |
| `onUserDeleted` | Auth trigger | Clean up user data on account deletion |

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /friends/{friendId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    match /friendRequests/{requestId} {
      allow read: if request.auth != null &&
        (resource.data.fromUserId == request.auth.uid ||
         resource.data.toUserId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.fromUserId == request.auth.uid;
      allow update: if request.auth != null &&
        resource.data.toUserId == request.auth.uid;
    }
    match /escalations/{eventId} {
      allow read: if request.auth != null &&
        resource.data.userId == request.auth.uid;
    }
  }
}
```

## Key Implementation Notes

### Phone Number Hashing
- Normalize to E.164 format (+1XXXXXXXXXX)
- SHA256 hash for privacy-preserving contact matching
- Backend only stores hashes, not raw numbers

### AlarmKit (iOS 26+)
- Currently using local notifications as fallback
- AlarmKit API available in iOS 26 beta
- Live Activities work on iOS 16.1+

### Escalation Timing
- Cloud Function runs every minute checking pending escalations
- For production, use Cloud Tasks for precise timing
- Local backup timer on device in case of network issues

### Rate Limiting
- Max 3 notifications per friend per hour
- Prevents abuse of the escalation feature

## Testing

Full test plan in `SETUP_AND_TEST_PLAN.md` with 25+ test cases covering:
- Authentication (phone, SMS, onboarding, profile)
- Alarm management (create, list, edit, delete)
- Alarm firing (basic, snooze, silent mode)
- Friends system (list, permissions, add, invite)
- Social accountability/escalation
- Settings
- Edge cases (no network, app killed, phone restart)

## Common Issues

### Push Notifications Not Working
1. Check `GoogleService-Info.plist` is in project
2. Verify APNs key is uploaded to Firebase
3. Ensure device token is being sent to Firestore
4. Check `fcmToken` field in user document

### Contacts Not Loading
1. Check NSContactsUsageDescription in Info.plist
2. Verify permission granted in Settings
3. Test on device (not simulator)

### Live Activity Not Showing
1. Check NSSupportsLiveActivities in Info.plist
2. Verify widget extension is properly configured
3. Check ActivityAuthorizationInfo().areActivitiesEnabled

### "No such module 'FirebaseAuth'"
- Xcode → File → Packages → Reset Package Caches
- Clean build: Cmd+Shift+K
- Build again: Cmd+B

## Architecture Decisions

1. **SwiftData over Core Data**: Modern API, better SwiftUI integration
2. **@Observable over ObservableObject**: Cleaner syntax, automatic tracking
3. **Repository Pattern**: Separates data access from business logic
4. **Feature-Based Structure**: Each feature self-contained
5. **Firebase Phone Auth**: No passwords, phone = identity
6. **Contact Hashing**: Privacy-first friend discovery
