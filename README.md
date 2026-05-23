# ChatApp — Real-Time Messaging with Flutter & Firebase

A full-featured, production-ready chat application built with Flutter and Firebase. Clean UI, real-time everything, and a solid feature set built from the ground up.

---

## Features

**Messaging**
- Real-time message delivery via Cloud Firestore
- Edit and delete messages
- Reply to messages with inline thread preview
- Emoji reactions (👍 ❤️ 😂 😮 😢 🔥)
- Message search across conversation history
- Date separators (Today / Yesterday / date)

**Media & Files**
- Send images from gallery or camera
- Send documents (PDF, DOCX, TXT, ZIP) up to 900KB
- File attachment cards with type, name, and size info
- Open received files with native device apps

**User Presence**
- Online / offline status with green indicator dot
- Last seen timestamp ("last seen 5m ago")
- Real-time typing indicator

**Notifications & UX**
- Push notifications via Firebase Cloud Messaging (FCM)
- Unread message count badge on chat list
- Read receipts (✓ sent, ✓✓ seen)
- Bold preview text for unread conversations
- Reply / edit banner above input field

**Auth & Navigation**
- Email/password authentication via Firebase Auth
- Search users by email to start new conversations
- Proper logout clearing full navigation stack

---

## Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Android & cross-platform) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Notifications | Firebase Cloud Messaging |
| State | StatefulWidget + StreamBuilder |
| File handling | Base64 encoded in Firestore (no Storage needed) |

---

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio or VS Code
- A [Firebase Console](https://console.firebase.google.com/) account

### Setup

**1. Clone the repo**
```bash
git clone https://github.com/anammemon091/Chat_App
cd Chat_App
```

**2. Create a Firebase project**
- Go to Firebase Console → Add Project
- Enable **Authentication** (Email/Password)
- Enable **Cloud Firestore**
- Enable **Cloud Messaging**

**3. Register your Android app**
- In Firebase Console → Project Settings → Add App → Android
- Enter your package name from `android/app/build.gradle`
- Download `google-services.json` and place it at:
  ```
  android/app/google-services.json
  ```

**4. Set Firestore security rules**
```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /conversations/{convoId} {
      allow read, write: if request.auth != null &&
        request.auth.uid in resource.data.participants;
      match /messages/{msgId} {
        allow read, write: if request.auth != null;
      }
    }
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

**5. Install dependencies and run**
```bash
flutter pub get
flutter run
```

---

## Project Structure

```
lib/
├── screens/
│   ├── chat_list_screen.dart   # Conversations list with unread badges
│   ├── chat_screen.dart        # Main chat UI with all messaging features
│   └── new_chat_screen.dart    # User search to start new conversations
└── main.dart
```

---

## Known Limitations

- File sharing uses Base64 encoding stored in Firestore — max file size ~900KB
- Video sharing requires upgrading to Firebase Blaze plan (Firebase Storage)
- Push notification delivery requires a Cloud Functions backend to send FCM messages

---