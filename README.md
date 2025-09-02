# 🚨 Emergency-SOS-System (resqmob)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-success)]()
[![License](https://img.shields.io/badge/License-Unspecified-lightgrey)]()

---

## 📑 Table of Contents

1. [Overview](#-overview)  
2. [Features](#-features)  
3. [Screenshots](#-screenshots)  
4. [Architecture](#-architecture)  
5. [Project Structure](#-project-structure)  
6. [Technologies](#-technologies)  
7. [Setup Instructions](#️-setup-instructions)  
8. [Running the App](#-running-the-app)  
9. [Testing](#-testing)  
10. [Roadmap](#-roadmap)  
11. [Contributing](#-contributing)  
12. [License](#-license)  
13. [Contact](#-contact)

---

## 📝 Overview

**Emergency-SOS-System (resqmob)** is a **cross-platform Flutter application** designed to provide quick and reliable **emergency assistance**.  
It integrates with **Firebase** for backend services and supports **Android, iOS, Web, and Windows desktop** platforms.  

This app is intended to act as a **personal safety tool** for emergency situations where fast action and communication are critical.

---

## 🚨 Features

✅ Trigger SOS alerts with one tap  
✅ Share **real-time location** with trusted contacts  
✅ Firebase-powered **authentication and database**  
✅ Works across **mobile, web, and desktop**  
✅ **Scalable modular architecture** for future expansion  
✅ Offline support (limited functionality)  
✅ Simple, user-friendly interface  

---

## 🖼 Screenshots

> *(Add screenshots of your app here once available)*

| Home Screen | SOS Trigger | Location Sharing |
|-------------|-------------|------------------|
| ![s1](docs/screenshots/home.png) | ![s2](docs/screenshots/sos.png) | ![s3](docs/screenshots/location.png) |

---

## 🏗 Architecture

This project follows a **layered, modular Flutter architecture**:

- **UI Layer** → Flutter widgets, responsive layouts  
- **State Management** → Provider / Riverpod / Bloc (depending on your choice)  
- **Business Logic Layer** → Handles SOS triggers, location updates, Firebase calls  
- **Data Layer** → Firebase Realtime Database, Firestore, Authentication  
- **Platform Integrations** → Location APIs, device sensors, Firebase hosting  

---

## 📁 Project Structure

```plaintext
.
├── android/              # Android-specific configuration & build files
├── ios/ (if present)     # iOS-specific files
├── web/                  # Web deployment configuration
├── windows/              # Windows desktop support files
├── lib/                  # Main Flutter application code
│   ├── main.dart         # Entry point
│   ├── screens/          # App screens (Home, SOS, Settings, etc.)
│   ├── services/         # Firebase, location, SOS service handlers
│   ├── models/           # Data models
│   └── widgets/          # Reusable UI components
├── assets/               # Images, fonts, and other static assets
├── .firebase/            # Firebase-related local config
├── firebase.json         # Firebase hosting & project settings
├── apphosting.yaml       # Hosting config for Firebase
├── pubspec.yaml          # Flutter dependencies and metadata
├── pubspec.lock          # Locked dependency versions
├── analysis_options.yaml # Code analysis rules
├── test/                 # Unit and widget tests
└── README.md             # Project documentation
