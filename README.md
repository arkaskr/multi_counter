# Daily Counter (Meal & Expense Tracker)

An offline-first Flutter counter and meal tracking app with Neumorphic UI, Android Glance homescreen widget, OTP authentication via Nodemailer (SMTP), and bidirectional cloud sync with MongoDB Atlas.

---

## Repository Structure

```
widget/
├── App/                # Mobile client (Flutter app)
│   ├── android/        # Native Android code & Glance Home Screen Widget
│   ├── assets/         # App icons and assets
│   ├── lib/            # Flutter Dart application code
│   │   ├── core/       # Constants, DatabaseHelper (SQLite), theme, services
│   │   ├── features/   # Home, History, Daily Edit, Settings, Auth
│   │   └── shared/     # Models, Neumorphic components
│   ├── test/           # Comprehensive Flutter unit & widget test suite
│   ├── pubspec.yaml    # Flutter dependencies
│   └── analysis_options.yaml
│
├── Backend/            # Cloud backend server (Node.js & Express)
│   ├── src/
│   │   ├── models/     # Mongoose models (User, Otp, DailyRecord, Settings)
│   │   ├── routes/     # Auth (send/verify OTP) & Sync (2-way offline sync)
│   │   ├── services/   # Mailer (Nodemailer SMTP with dev console fallback)
│   │   ├── middleware/ # JWT authentication
│   │   ├── db.js       # MongoDB Atlas connection
│   │   ├── config.js   # Environment config loader
│   │   └── index.js    # Express application entrypoint
│   ├── test/           # Backend integration test suite
│   └── package.json
│
├── .env                # Secret environment variables (ignored by git)
├── .env.example        # Environment variables template
└── .gitignore          # Properly configured ignore rules
```

---

## Getting Started

### 1. Environment Configuration

Copy `.env.example` to `.env` (or configure the provided `.env`):

```bash
# MongoDB Connection URI
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster-url>.mongodb.net/daily_counter?retryWrites=true&w=majority

# Backend Server Configuration
PORT=5000
JWT_SECRET=your_jwt_secret_key_here

# SMTP Credentials for Nodemailer (Replace dummy credentials with real ones when available)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password
SMTP_FROM="Daily Counter" <your_email@gmail.com>

# Mobile App API URL
API_BASE_URL=http://localhost:5000/api
```

> **Note on Dummy SMTP**: If dummy SMTP credentials are used, the server automatically catches errors and prints the 6-digit verification code directly into the server terminal console (`[DEVELOPMENT / DUMMY SMTP FALLBACK] OTP Code: >>> XXXXXX <<<`) so you can test login immediately.

---

### 2. Backend Server

Run the backend server:

```bash
cd Backend
npm install
npm start
```

For development with hot reload:
```bash
npm run dev
```

Run backend tests:
```bash
npm test
```

---

### 3. Flutter Application

Run the Flutter app:

```bash
cd App
flutter pub get
flutter run
```

Run Flutter tests:
```bash
cd App
flutter test
```

---

## Features

- **Accurate Food Days Counter**: The day counter increments **only** on days where food was actually logged (`count > 0`). Days with 0 meals do not increment the count.
- **Offline-First Storage**: Local SQLite database acts as the instant source of truth; all counter actions, widget updates, and settings changes work smoothly without internet.
- **MongoDB Atlas Cloud Sync**: Automatically syncs local records and preferences with MongoDB when an internet connection is detected, with manual "Sync Now" support in Settings.
- **Email OTP Authentication**: Passwordless login/signup using user's Name, Email, and 6-digit OTP code sent via SMTP (Nodemailer).
- **Guest / Offline Mode**: Users can skip login and continue tracking locally at any time.
- **Android Glance Widget**: Interactive squircle widget on Android home screen with real-time meal counting, theme support, and active food days tracking.
