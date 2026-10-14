<img src="Rehearse/Resources/rehearse.png" alt="Rehearse" width="220" />

Practice the interview, not just the questions.

An ongoing group project built to explore and test how real-time mock interviews work on iOS.

This repository currently contains the native iOS UI prototype and client application flows. It is an active work in progress. The live speech-to-text audio pipeline and conversational backend agent are not yet connected; all mock interview sessions, scoring breakdowns, and resume features currently run offline using local mock data and services.

Most engineering interview prep boils down to grinding LeetCode or memorizing definitions from a flashcard deck. That works fine for coding syntax tests, but it does almost nothing to prepare you for what an actual technical interview feels like.

When a senior engineer asks you why you chose PostgreSQL over MongoDB for an order service, or how you would handle 100x write traffic on a Friday evening, you cannot lean on a unit test runner. You have to explain your thought process out loud, justify your trade-offs, and handle follow-up scrutiny in real time.

Rehearse gives you a place to practice that verbal back-and-forth before it counts.


## How it works

You speak into your iPhone microphone. Rehearse listens, evaluates your answer in real time, and responds conversationally.

Instead of running down a generic checklist of questions, the interviewer adapts to what you actually say:
- Mention ACID guarantees, and it probes how your system behaves during a network partition.
- Mention sharding, and it asks how you deal with hot partitions and cross-shard queries.
- Mention Redis, and it asks about your cache invalidation strategy when writes spike.

It keeps track of time just like a real interview (10, 20, or 30 minutes) and moves between topics so you get a well-rounded conversation covering architecture, databases, concurrency, and teamwork.

If you connect a resume, it pulls from your actual past projects and tech stack instead of asking hypothetical questions.


## Targeted practice

At the end of each session, you get feedback broken down into three areas:
- Technical correctness: Did you explain the concepts accurately?
- Trade-off articulation: Did you justify your decisions and weigh alternatives?
- Communication: Was your answer structured and clear?

If you hit Rehearse Again, Rehearse automatically takes the biggest gap identified in that round and brings it up in the next interview. That way you spend time fixing the specific things you struggle to explain out loud.


## What is implemented

The current iOS client includes the complete interface and prototype interactions:
- Live interview room with timer controls, prompt progression, and answer review
- Feedback scorecards measuring technical precision, trade-offs, and structure
- Question library and domain collections
- Resume viewer, builder, scanner, and job-tailoring flows
- Onboarding, authentication, and interview readiness history

Live audio streaming, dynamic LLM follow-up generation, and backend account persistence are currently in progress.


## Privacy

Audio input is used exclusively for speech transcription and answer evaluation. No background audio is recorded or stored without your knowledge.

We do not run facial emotion tracking, eye-contact metrics, or speculative behavioral scores. The feedback is based purely on what you say and how you defend your technical choices.


## Running locally

### Requirements
- macOS 15.0 or later
- Xcode 16.0 or later
- iOS 18.0+ Simulator or connected iPhone

### Setup

Clone the repository:

```bash
git clone https://github.com/calmerism/RehearseiOS.git
cd RehearseiOS
```

Open the project in Xcode:

```bash
open Rehearse.xcodeproj
```

Select the **Rehearse** scheme and an iOS Simulator (e.g. iPhone 16 Pro) or your connected device, then press **⌘R** (or **Product > Run**).

The app includes built-in mock services and demo data out of the box, allowing you to run and test the complete interview loop, resume viewer, and feedback screens immediately offline.


## Built with

- SwiftUI & Swift 6
- Modern Observation (`@Observable`)
- Apple Human Interface Guidelines Design System
- Adaptive Light & Dark mode architecture


## License

MIT
