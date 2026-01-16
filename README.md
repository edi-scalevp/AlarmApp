# WakeUp - Social Accountability Alarm App

An iPhone alarm app where if you don't dismiss your alarm in time, your friend gets notified to help wake you up.

![iOS](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Firebase](https://img.shields.io/badge/Firebase-Phone%20Auth%20%7C%20Firestore-yellow)

## Features

- **Bulletproof Alarms** - AlarmKit integration breaks through Silent Mode and Do Not Disturb
- **Live Activities** - See your alarm on Lock Screen and Dynamic Island
- **Social Accountability** - Friends get notified if you don't wake up in time
- **Contact-Based Friends** - Find friends automatically via phone number matching
- **Privacy-First** - Phone numbers are hashed locally before matching

## Screenshots

*Coming soon*

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Firebase account
- Apple Developer account (for push notifications)

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/edi-scalevp/AlarmApp.git
cd AlarmApp
```

### 2. Firebase Configuration

1. Create a project in [Firebase Console](https://console.firebase.google.com)
2. Enable Phone Authentication
3. Create a Firestore database
4. Enable Cloud Messaging
5. Download `GoogleService-Info.plist` and add to `AlarmApp/` folder

### 3. Add Firebase SDK

In Xcode: File > Add Package Dependencies
- URL: `https://github.com/firebase/firebase-ios-sdk.git`
- Select: FirebaseAuth, FirebaseFirestore, FirebaseMessaging, FirebaseFunctions

### 4. Deploy Cloud Functions

```bash
cd functions
npm install
firebase login
firebase deploy --only functions
```

### 5. Open in Xcode

```bash
open AlarmApp.xcodeproj
```

## Architecture

```
AlarmApp/
├── Models/           # SwiftData models
├── Services/         # Business logic
├── Repositories/     # Data access layer
└── Features/         # Feature-based UI modules
    ├── Authentication/
    ├── Alarms/
    ├── Friends/
    └── Settings/
```

## How It Works

1. **Sign up** with your phone number (SMS verification)
2. **Add friends** from your contacts who are also on the app
3. **Create an alarm** and enable "Social Accountability"
4. **Select a friend** to notify if you don't wake up
5. **Sleep tight** - your alarm will go off even in Silent Mode
6. **Dismiss in time** or your friend gets a push notification

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI + @Observable |
| Storage | SwiftData |
| Auth | Firebase Phone Auth |
| Database | Firebase Firestore |
| Push | Firebase Cloud Messaging |
| Backend | Firebase Cloud Functions |

## Documentation

See [claude.md](claude.md) for detailed implementation notes.

## License

MIT
