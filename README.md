# Rehearse (iOS)

An autonomous, voice-driven AI interview practice iOS application built in SwiftUI. Rehearse provides real-time verbal interview simulations tailored to your resume and technical domain, providing immediate feedback on technical correctness, trade-offs, and communication clarity.

## Overview

Rehearse gives developers and candidates a realistic space to practice conversational and technical interview scenarios before it counts. Rather than generic flashcards, the app adapts dynamically to responses and tracks readiness across topics over time.

### Key Features

- **Live Simulated Interviews**: Interactive voice and audio interview sessions with real-time prompt feedback.
- **Dynamic Question Engine**: Adaptive follow-up questions tailored to your resume, answers, and technical experience.
- **Post-Session Feedback Reports**: Detailed scoring and actionable takeaways on technical precision, articulation, and delivery.
- **Readiness Tracking**: Track readiness metrics and focus areas across sessions.
- **Native SwiftUI Design**: Crafted native iOS interface with custom typography and responsive design system.

## Project Structure

```
.
├── Rehearse/                   # Main iOS application source
│   ├── Components/             # Reusable UI controls and design components
│   ├── Models/                 # Data models (Interview, Question, Feedback, Resume)
│   ├── Resources/              # Bundled fonts, assets, and media
│   ├── Services/               # Application state and mock/backend services
│   ├── Theme/                  # Colors, typography, and styling tokens
│   └── Views/                  # Screen views (Home, Live Interview, Feedback, etc.)
├── Rehearse.xcodeproj          # Xcode project configuration
├── Google Stitch Design/       # UI specifications and design variants
└── Archive/                    # Archived components and earlier iterations
```

## Getting Started

### Prerequisites

- macOS running **Xcode 16.0** or later
- iOS 18.0+ SDK (Swift 6.0)

### Opening and Running the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/calmerism/RehearseiOS.git
   cd RehearseiOS
   ```
2. Open `Rehearse.xcodeproj` in Xcode:
   ```bash
   open Rehearse.xcodeproj
   ```
3. Select an iOS Simulator (e.g., iPhone 16 Pro) or a connected iOS device.
4. Build and run by pressing **⌘R** (or clicking **Product > Run**).

## Group Project & Contributing

This repository is maintained as an ongoing group project.

- Branching: Please create feature branches off `main` for new features and bug fixes (e.g. `feature/live-audio`, `fix/resume-parser`).
- Pull Requests: Submit pull requests to `main` with a clear description of changes.
