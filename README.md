ChatApp: Real-Time Messaging Solution
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
Flutter SDK (Latest Stable Version)

Firebase Project with Firestore and Authentication enabled

Git installed for version control

### Installation
Clone Repository:

Bash
git clone https://github.com/anammemon091/flutter-chat-starter
Dependency Management:

Bash
flutter pub get
Deployment:

Bash
flutter run