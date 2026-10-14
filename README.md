# Rehearse

An iOS app for practicing technical interviews out loud.

> **Project Status: Work in Progress (UI Prototype)**  
> This repository currently contains the native iOS user interface and client architecture. It is an active work in progress and does not yet include the live speech-to-text pipeline or backend conversational engine. All interview sessions, scoring reports, and resume features currently run offline using local mock services.

---

## What We Are Trying to Do

Most technical interview preparation focuses on solving algorithm puzzles on a whiteboard or memorizing flashcard definitions. In real technical interviews, senior engineers evaluate your ability to talk through complex systems, justify architectural decisions, and defend trade-offs in real time.

When asked why you selected PostgreSQL over MongoDB for an order service, or how your service handles database failover during peak traffic, you need to structure your answer verbally and address follow-up questions directly.

We are building Rehearse to give engineers a realistic space to practice those conversations out loud before actual interviews. The goal is an adaptive voice-driven interviewer that listens to candidate responses, asks relevant follow-up questions based on what was said, and provides constructive feedback on technical accuracy, trade-off analysis, and communication structure.

---

## Current Prototype Scope

This repository implements the complete frontend experience in SwiftUI:

- **Live Interview Room**: Interactive question flow, speaking state, timer management (10, 20, or 30 minutes), and turn-by-turn answer reviews.
- **Feedback & Scorecards**: Structured performance evaluation measuring technical accuracy, trade-off articulation, and clarity.
- **Question Library**: Curated technical questions organized by categories, tags, and custom collections.
- **Resume Hub**: Workflows for previewing resumes, tailoring resumes to specific job descriptions, and scanning key experience points.
- **Progress & History**: Dashboard tracking interview readiness over time, past session recordings, and upcoming scheduled interviews.
- **Onboarding & Authentication**: Account setup, skill selection, and preference configuration.

---

## Planned Development

The following backend systems and integrations are currently in progress:

1. **Audio Streaming & Transcription**: Low-latency on-device or server-side speech recognition.
2. **Conversational Interview Agent**: LLM-driven interviewer that detects key concepts in answers and generates dynamic technical follow-ups.
3. **Automated Rubric Scoring**: Backend evaluation model that assesses trade-off depth and clarity against objective benchmarks.
4. **Backend Sync & Storage**: Secure persistence for candidate resumes, session transcripts, and progress metrics.

---

## Requirements

- macOS 15.0 or later
- Xcode 16.0 or later
- iOS 18.0 or later (Simulator or physical device)

---

## Running Locally

1. Clone the repository:
   ```bash
   git clone https://github.com/calmerism/RehearseiOS.git
   cd RehearseiOS
   ```

2. Open the project in Xcode:
   ```bash
   open Rehearse.xcodeproj
   ```

3. Select the **Rehearse** scheme and an iOS Simulator (for example, iPhone 16 Pro) or your connected device.

4. Press **⌘R** (or select **Product > Run**) to build and launch the app. The app boots with sample data and mock services ready for local testing.

---

## Tech Stack & Architecture

- **UI Framework**: SwiftUI (Swift 6)
- **State Management**: Swift Observation framework (`@Observable`)
- **Design System**: Apple Human Interface Guidelines standards with San Francisco typography, semantic grouped surfaces, and full Light/Dark mode support
- **Project Structure**: Native Xcode 16 folder-synchronized project (`PBXFileSystemSynchronizedRootGroup`)

---

## License

MIT
