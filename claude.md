# WakeUp - Social Accountability Alarm App

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
├── AlarmApp/
│   ├── AlarmApp.swift              # App entry point, SwiftData setup
│   ├── AppDelegate.swift           # Firebase & push notification config
│   ├── Info.plist
│   │
│   ├── Models/
│   │   ├── User.swift              # User profile with phone auth
│   │   ├── Alarm.swift             # Alarm with escalation settings
│   │   ├── Friend.swift            # Friend relationship
│   │   └── FriendRequest.swift     # Friend request flow
│   │
│   ├── Services/
│   │   ├── AuthenticationService.swift   # Firebase Phone Auth
│   │   ├── AlarmKitService.swift         # AlarmKit + Live Activities
│   │   ├── ContactsService.swift         # Contact access & hashing
│   │   ├── FirestoreService.swift        # Database operations
│   │   └── EscalationService.swift       # Friend notification logic
│   │
│   ├── Repositories/
│   │   ├── AlarmRepository.swift   # Alarm CRUD + scheduling
│   │   └── FriendRepository.swift  # Friends & contact discovery
│   │
│   └── Features/
│       ├── Authentication/Views/
│       │   ├── PhoneEntryView.swift
│       │   ├── VerificationCodeView.swift
│       │   ├── ProfileSetupView.swift
│       │   └── OnboardingView.swift
│       │
│       ├── Alarms/Views/
│       │   ├── AlarmListView.swift
│       │   ├── CreateAlarmView.swift
│       │   ├── AlarmDetailView.swift
│       │   └── Components/
│       │       ├── AlarmCard.swift
│       │       └── TimePickerWheel.swift
│       │
│       ├── Friends/Views/
│       │   ├── FriendsListView.swift
│       │   ├── AddFriendView.swift
│       │   └── FriendRequestsView.swift
│       │
│       └── Settings/Views/
│           ├── SettingsView.swift
│           └── ProfileView.swift
│
├── AlarmWidgetExtension/
│   ├── AlarmActivityAttributes.swift    # Live Activity data model
│   ├── AlarmLiveActivity.swift          # Lock Screen & Dynamic Island UI
│   └── Info.plist
│
├── functions/                           # Firebase Cloud Functions
│   ├── src/index.ts                     # All cloud functions
│   ├── package.json
│   └── tsconfig.json
│
└── Package.swift                        # SPM dependencies
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

## Firebase Setup Required

### 1. Create Firebase Project
- Go to [Firebase Console](https://console.firebase.google.com)
- Create new project "WakeUp"
- Enable Phone Authentication
- Create Firestore database
- Enable Cloud Messaging

### 2. iOS App Configuration
- Add iOS app with bundle ID
- Download `GoogleService-Info.plist`
- Place in `AlarmApp/` directory

### 3. Deploy Cloud Functions
```bash
cd functions
npm install
firebase login
firebase deploy --only functions
```

### 4. Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Friends subcollection
      match /friends/{friendId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Friend requests
    match /friendRequests/{requestId} {
      allow read: if request.auth != null &&
        (resource.data.fromUserId == request.auth.uid ||
         resource.data.toUserId == request.auth.uid);
      allow create: if request.auth != null &&
        request.resource.data.fromUserId == request.auth.uid;
      allow update: if request.auth != null &&
        resource.data.toUserId == request.auth.uid;
    }

    // Escalations (read own, cloud functions write)
    match /escalations/{eventId} {
      allow read: if request.auth != null &&
        resource.data.userId == request.auth.uid;
    }
  }
}
```

## Xcode Project Setup

### Required Capabilities
- Push Notifications
- Background Modes (Remote notifications, Background fetch)
- App Groups (for widget extension)

### Required Entitlements
- `com.apple.developer.usernotifications.critical-alerts` (for alarm sounds)

### SPM Dependencies
```swift
// In Xcode: File > Add Package Dependencies
// URL: https://github.com/firebase/firebase-ios-sdk.git
// Products: FirebaseAuth, FirebaseFirestore, FirebaseMessaging, FirebaseFunctions
```

### Widget Extension Target
1. File > New > Target > Widget Extension
2. Name: "AlarmWidgetExtension"
3. Include Live Activity: Yes
4. Add files from `AlarmWidgetExtension/` folder

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

## Testing Checklist

- [ ] Phone auth: sign up, sign out, sign in
- [ ] Alarm: create, edit, delete, toggle
- [ ] Alarm fires in Silent Mode (requires AlarmKit on iOS 26)
- [ ] Live Activity shows on Lock Screen
- [ ] Snooze extends escalation timer
- [ ] Dismiss cancels escalation
- [ ] Friend request: send, accept, decline
- [ ] Contact discovery finds registered users
- [ ] Escalation triggers friend push notification
- [ ] Stats update after alarms

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

## Architecture Decisions

1. **SwiftData over Core Data**: Modern API, better SwiftUI integration
2. **@Observable over ObservableObject**: Cleaner syntax, automatic tracking
3. **Repository Pattern**: Separates data access from business logic
4. **Feature-Based Structure**: Each feature self-contained
5. **Firebase Phone Auth**: No passwords, phone = identity
6. **Contact Hashing**: Privacy-first friend discovery
