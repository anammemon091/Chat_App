## ChatApp: Real-Time Messaging Solution
A robust, enterprise-grade chat infrastructure developed using Flutter and Firebase. This application is engineered for high-performance communication, featuring a minimalist geometric UI designed for cross-platform scalability.

## Core Technical Features
Real-Time Synchronization: Leverages Cloud Firestore for instantaneous message delivery and reactive state updates.

Complete Message Lifecycle: Supports full CRUD operations, including the ability to edit existing messages and perform soft or hard deletions.

Interactive Engagement: Built-in support for emoji reactions and live typing indicators to enhance user presence.

Search & Discovery: High-speed message filtering allows users to query conversation history by keywords.

## Architecture & Stack
Framework: Flutter (Android and Cross-Platform).

Backend as a Service (BaaS): Firebase (Firestore & Authentication).

State Management: Optimized for efficiency using StatefulWidget logic and StreamBuilder for real-time data flow.

## Getting Started
### Prerequisites
* Flutter SDK (Latest Stable version)
* Android Studio or VS Code
* A personal [Firebase Console](https://console.firebase.google.com/) account

### Step-by-Step Backend Integration

1. **Create a Firebase Project:**
   * Go to the Firebase Console and select **Add Project**.
   * Name your project and configure basic analytics settings.

2. **Register the Android Application:**
   * Select the Android icon on your Firebase Project overview panel.
   * Enter the precise package name found in your `android/app/build.gradle` file (e.g., `com.example.chatapp`).

3. **Download Configuration Metadata:**
   * Download the generated `google-services.json` config file from the setup wizard.

4. **Position the Configuration File:**
   * Move the downloaded `google-services.json` file directly into your local project workspace at the following directory destination:
     ```text
     your-project-root/android/app/google-services.json
     ```

5. **Initialize Database Rules:**
   * Navigate to **Cloud Firestore** within your Firebase console dashboard.
   * Enable Firestore and ensure your **Security Rules** allow read/write access for authenticated communication testers.

6. **Build and Execute:**
   ```bash
   flutter pub get
   flutter run

### Installation
Clone Repository:

```bash
git clone https://github.com/anammemon091/Chat_App

Dependency Management:

```bash
flutter pub get

Deployment:

```bash
flutter run