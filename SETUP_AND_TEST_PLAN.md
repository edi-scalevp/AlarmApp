# WakeUp App - Setup Instructions & Test Plan

## Part 1: Manual Setup Steps

### Step 1: Create Firebase Project (10 min)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Create a project"**
3. Name it `WakeUp` (or any name you prefer)
4. Disable Google Analytics (optional, simplifies setup)
5. Click **Create project**

### Step 2: Enable Firebase Phone Authentication (2 min)

1. In Firebase Console, go to **Build → Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Click **Phone** and toggle **Enable**
5. Click **Save**

### Step 3: Create Firestore Database (2 min)

1. In Firebase Console, go to **Build → Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (we'll add security rules later)
4. Select a location close to you (e.g., `us-central1`)
5. Click **Enable**

### Step 4: Add iOS App to Firebase (3 min)

1. In Firebase Console, click the **gear icon** → **Project settings**
2. Scroll down to **Your apps** section
3. Click the **iOS icon** (</>) to add an iOS app
4. Enter Bundle ID: `com.wakeup.app` (must match Xcode)
5. Enter App nickname: `WakeUp`
6. Skip App Store ID for now
7. Click **Register app**
8. **Download `GoogleService-Info.plist`** (important!)
9. Click through the remaining steps (we'll add SDK via SPM)

### Step 5: Set Up Cloud Messaging (APNs) (5 min)

For push notifications to work, you need an APNs key:

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Go to **Certificates, Identifiers & Profiles**
3. Click **Keys** in the sidebar
4. Click the **+** button to create a new key
5. Name it `WakeUp APNs Key`
6. Check **Apple Push Notifications service (APNs)**
7. Click **Continue** → **Register**
8. **Download the .p8 file** (you can only download once!)
9. Note the **Key ID** shown on the page

Now upload to Firebase:
1. Back in Firebase Console → **Project settings**
2. Go to **Cloud Messaging** tab
3. Under **Apple app configuration**, click **Upload** next to APNs Authentication Key
4. Upload the .p8 file
5. Enter your **Key ID** and **Team ID** (found in Apple Developer portal → Membership)

### Step 6: Open Project in Xcode (1 min)

```bash
cd /Users/edi/Projects/AlarmApp
open AlarmApp.xcodeproj
```

### Step 7: Add GoogleService-Info.plist to Xcode (2 min)

1. In Finder, locate the `GoogleService-Info.plist` you downloaded
2. Drag it into Xcode, dropping it in the `AlarmApp` folder (same level as `AlarmApp.swift`)
3. In the dialog:
   - Check **Copy items if needed**
   - Check **AlarmApp** target
   - Click **Finish**

### Step 8: Add Firebase SDK via Swift Package Manager (3 min)

1. In Xcode, go to **File → Add Package Dependencies...**
2. In the search bar, paste: `https://github.com/firebase/firebase-ios-sdk.git`
3. Click **Add Package** (wait for it to load)
4. Select these products:
   - [x] FirebaseAuth
   - [x] FirebaseFirestore
   - [x] FirebaseMessaging
   - [x] FirebaseFunctions
5. Click **Add Package**

### Step 9: Configure Code Signing (2 min)

1. In Xcode, click on **AlarmApp** in the project navigator (top blue icon)
2. Select **AlarmApp** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown
6. If Bundle Identifier is red, change it to something unique like `com.yourname.wakeup`
7. Repeat for **AlarmWidgetExtension** target

### Step 10: Add Required Capabilities (3 min)

1. With **AlarmApp** target selected, in **Signing & Capabilities**:
2. Click **+ Capability** and add:
   - **Push Notifications**
   - **Background Modes** (then check: `Background fetch`, `Remote notifications`)
3. For **AlarmWidgetExtension** target:
   - Ensure it has the same Team selected
   - Bundle ID should be `com.yourname.wakeup.widget`

### Step 11: Update Bundle IDs in Firebase (if changed) (1 min)

If you changed the bundle ID in Step 9:
1. Go to Firebase Console → Project settings
2. Under your iOS app, click **Edit** (pencil icon)
3. Update the Bundle ID to match what's in Xcode
4. Re-download `GoogleService-Info.plist` and replace the old one in Xcode

### Step 12: Deploy Cloud Functions (5 min)

1. Install Firebase CLI (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in the project:
   ```bash
   cd /Users/edi/Projects/AlarmApp
   firebase init
   ```
   - Select **Functions** (use space to select, enter to continue)
   - Select **Use an existing project** → select your WakeUp project
   - Choose **TypeScript**
   - Say **No** to ESLint
   - Say **Yes** to install dependencies

4. Deploy the functions:
   ```bash
   cd functions
   npm install
   npm run build
   firebase deploy --only functions
   ```

### Step 13: Add Firestore Security Rules (2 min)

1. In Firebase Console → **Firestore Database**
2. Go to **Rules** tab
3. Replace the rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
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

    // Escalations
    match /escalations/{eventId} {
      allow read: if request.auth != null &&
        resource.data.userId == request.auth.uid;
      allow write: if false; // Only cloud functions write
    }
  }
}
```

4. Click **Publish**

### Step 14: Build and Run on Device (2 min)

1. Connect your iPhone via USB
2. In Xcode, select your iPhone from the device dropdown (top of window)
3. Click the **Play** button (or Cmd+R)
4. If prompted, trust the developer certificate on your iPhone:
   - On iPhone: Settings → General → VPN & Device Management → tap your developer profile → Trust
5. Run again

---

## Part 2: Test Plan

### Prerequisites for Testing
- Two iPhones (yours and a friend's) for full escalation testing
- Both phones should have the app installed
- Both phones should be connected to the internet

---

### Test Suite A: Authentication Flow

#### Test A1: Phone Number Entry
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Launch app | See phone entry screen with country picker |
| 2 | Tap country picker | See list of countries with flags |
| 3 | Select a country | Country code updates |
| 4 | Enter invalid number (5 digits) | Continue button disabled |
| 5 | Enter valid 10-digit number | Continue button enabled |
| 6 | Tap Continue | Loading indicator shows, then navigate to verification screen |

#### Test A2: SMS Verification
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Wait for SMS | Receive 6-digit code from Firebase |
| 2 | Enter wrong code | Error message appears, fields clear |
| 3 | Enter correct code | Navigate to onboarding or main app |
| 4 | Test auto-fill | iOS should auto-fill code from SMS |

#### Test A3: Onboarding (First Launch Only)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View first page | See "Bulletproof Alarms" explanation |
| 2 | Tap Next | See "Social Accountability" page |
| 3 | Tap Next | See "Smart Notifications" page |
| 4 | Tap Get Started | Permission prompts appear |
| 5 | Allow notifications | Navigate to profile setup |

#### Test A4: Profile Setup
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter display name | Continue button enables |
| 2 | Tap profile photo | Photo picker opens |
| 3 | Select photo | Photo displays in circle |
| 4 | Tap Continue | Navigate to main app |

---

### Test Suite B: Alarm Management

#### Test B1: Create Alarm
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap + button | Create alarm sheet opens |
| 2 | Scroll time picker | Time updates smoothly |
| 3 | Enter label "Test Alarm" | Label field shows text |
| 4 | Tap day buttons (Mon, Wed, Fri) | Days highlight orange |
| 5 | Tap Sound row | Sound picker opens |
| 6 | Select different sound | Checkmark moves, sound previews |
| 7 | Toggle Snooze off | Snooze switch turns off |
| 8 | Tap Save | Alarm appears in list |

#### Test B2: Alarm List
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | View alarm list | See created alarm with time, label, repeat days |
| 2 | See "Next Alarm" card | Shows next alarm with countdown |
| 3 | Toggle alarm off | Alarm grays out, toggle turns off |
| 4 | Toggle alarm on | Alarm activates, toggle turns on |

#### Test B3: Edit Alarm
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap on alarm | Detail view opens |
| 2 | Change time | Time picker updates |
| 3 | Change label | Label updates |
| 4 | Tap Save | Returns to list with changes |

#### Test B4: Delete Alarm
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap on alarm | Detail view opens |
| 2 | Tap Delete Alarm | Confirmation dialog appears |
| 3 | Tap Delete | Alarm removed from list |

#### Test B5: Swipe to Delete
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Swipe left on alarm | Delete button appears |
| 2 | Tap Delete | Alarm removed |

---

### Test Suite C: Alarm Firing (Core Feature)

#### Test C1: Basic Alarm
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create alarm for 1 minute from now | Alarm saved |
| 2 | Lock phone | Phone locked |
| 3 | Wait for alarm | Notification appears (Live Activity if supported) |
| 4 | Tap Dismiss | Alarm stops |

#### Test C2: Snooze
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create alarm for 1 minute from now | Alarm saved |
| 2 | When alarm fires, tap Snooze | Alarm stops, snooze scheduled |
| 3 | Wait 9 minutes | Alarm fires again |
| 4 | Tap Dismiss | Alarm stops |

#### Test C3: Silent Mode (requires iOS 26 for AlarmKit)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Put phone in Silent Mode (flip switch) | Silent mode active |
| 2 | Create alarm for 1 minute from now | Alarm saved |
| 3 | Wait for alarm | Alarm should still sound |

---

### Test Suite D: Friends System

#### Test D1: View Friends List
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Friends tab | See friends list (empty if no friends) |
| 2 | See empty state | "No Friends Yet" message displayed |

#### Test D2: Request Contacts Permission
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap + button (Add Friend) | Permission request screen |
| 2 | Tap Allow Access to Contacts | iOS permission dialog |
| 3 | Allow permission | Contacts load |

#### Test D3: Add Friend (Requires Second Device)
Setup: Have a friend install the app and sign up with their phone number

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open Add Friend screen | See contacts list |
| 2 | Find friend in "On WakeUp" section | Friend shows with Add button |
| 3 | Tap Add | Friend request sent |
| 4 | **On friend's device**: See notification | "New Friend Request" notification |
| 5 | **On friend's device**: Open app | See pending request banner |
| 6 | **On friend's device**: Tap Accept | Becomes friends |
| 7 | Refresh your friends list | Friend appears in list |

#### Test D4: Invite Non-User
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Find contact not on WakeUp | Shows in "Invite" section |
| 2 | Tap Invite | Share sheet opens |
| 3 | Send via Messages | Invitation sent |

---

### Test Suite E: Social Accountability (Escalation)

#### Test E1: Create Alarm with Escalation
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap + to create alarm | Create alarm view |
| 2 | Set time for 2 minutes from now | Time set |
| 3 | Toggle "Social Accountability" on | Escalation options appear |
| 4 | Tap Select Friend | Friend picker opens |
| 5 | Select a friend | Friend selected |
| 6 | Choose "2 min" delay | Delay set to 2 minutes |
| 7 | Tap Save | Alarm saved with escalation badge |

#### Test E2: Escalation Prevention (Dismiss in Time)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Wait for alarm to fire | Alarm sounds |
| 2 | Dismiss within 2 minutes | Alarm stops |
| 3 | **Check friend's phone** | NO notification received |

#### Test E3: Escalation Triggered (Don't Dismiss)
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create alarm with 2-min escalation | Alarm saved |
| 2 | Let alarm ring without dismissing | Alarm keeps ringing |
| 3 | Wait 2+ minutes | Escalation triggers |
| 4 | **Check friend's phone** | Receives push: "[Name] needs help waking up!" |
| 5 | Friend taps "Call them" | Phone dialer opens |

---

### Test Suite F: Settings

#### Test F1: View Profile
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Tap Settings tab | See settings list |
| 2 | Tap profile section | Profile view opens |
| 3 | See phone number | Displayed (read-only) |
| 4 | See display name | Editable |

#### Test F2: Edit Profile
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Change display name | Name updates |
| 2 | Tap Save | Returns to settings |
| 3 | Re-open profile | New name persists |

#### Test F3: Sign Out
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Scroll to bottom of settings | See Sign Out button |
| 2 | Tap Sign Out | Confirmation dialog |
| 3 | Confirm Sign Out | Returns to phone entry screen |
| 4 | Sign back in | Account and data intact |

---

### Test Suite G: Edge Cases

#### Test G1: No Network
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enable Airplane Mode | No network |
| 2 | Create alarm | Alarm saves locally |
| 3 | Alarm fires | Still works (local) |
| 4 | Disable Airplane Mode | Data syncs to cloud |

#### Test G2: App Killed
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create alarm for 2 minutes | Alarm saved |
| 2 | Force quit app (swipe up) | App closed |
| 3 | Wait for alarm | Alarm still fires |

#### Test G3: Phone Restart
| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Create alarm for 5 minutes | Alarm saved |
| 2 | Restart phone | Phone reboots |
| 3 | Wait for alarm | Alarm still fires |

---

## Test Results Template

Use this to record your testing:

```
Date: ___________
Tester: ___________
Device: ___________
iOS Version: ___________

| Test ID | Pass/Fail | Notes |
|---------|-----------|-------|
| A1 | | |
| A2 | | |
| A3 | | |
| A4 | | |
| B1 | | |
| B2 | | |
| B3 | | |
| B4 | | |
| B5 | | |
| C1 | | |
| C2 | | |
| C3 | | |
| D1 | | |
| D2 | | |
| D3 | | |
| D4 | | |
| E1 | | |
| E2 | | |
| E3 | | |
| F1 | | |
| F2 | | |
| F3 | | |
| G1 | | |
| G2 | | |
| G3 | | |
```

---

## Troubleshooting

### "No such module 'FirebaseAuth'"
- Xcode → File → Packages → Reset Package Caches
- Clean build: Cmd+Shift+K
- Build again: Cmd+B

### Push notifications not working
1. Check APNs key is uploaded to Firebase
2. Verify Team ID is correct in Firebase
3. Check device has internet
4. Check notification permissions in Settings app

### Phone auth not sending SMS
1. Check Phone auth is enabled in Firebase
2. Add your phone to test numbers: Firebase → Authentication → Sign-in method → Phone → Phone numbers for testing

### Alarm not firing
- Check notification permissions granted
- For iOS 26 AlarmKit: must test on physical device
- Check Do Not Disturb allows time-sensitive notifications

### Contacts not loading
- Check Contacts permission in Settings
- Try removing and re-adding permission
