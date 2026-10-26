<img src="Rehearse/Resources/rehearse.png" alt="Rehearse" width="220" />

Practice the interview, not just the questions.

An ongoing group project built to explore and test how real-time mock interviews work on iOS.

This repository contains the native iOS app and its Supabase backend. It is an active work in progress. Accounts, sync, the question bank, speech-to-text and reminders are real; the AI interviewer is not connected yet, so interview questions and answer evaluation still come from prepared mock data. Without Supabase keys, the whole app runs offline on that mock data.

Most engineering interview prep boils down to grinding LeetCode or memorizing definitions from a flashcard deck. That works fine for coding syntax tests, but it does almost nothing to prepare you for what an actual technical interview feels like.

When a senior engineer asks you why you chose PostgreSQL over MongoDB for an order service, or how you would handle 100x write traffic on a Friday evening, you cannot lean on a unit test runner. You have to explain your thought process out loud, justify your trade-offs, and handle follow-up scrutiny in real time.

Rehearse gives you a place to practice that verbal back-and-forth before it counts.


## How it works

You speak into your iPhone microphone. Rehearse transcribes your answer on the device and measures how you said it: your pace, filler words, long pauses and hedging.

The goal is an interviewer that adapts to what you actually say:
- Mention ACID guarantees, and it probes how your system behaves during a network partition.
- Mention sharding, and it asks how you deal with hot partitions and cross-shard queries.
- Mention Redis, and it asks about your cache invalidation strategy when writes spike.

Those follow-ups need the AI step, which is in progress. Today the questions follow a prepared script.

It keeps track of time just like a real interview (10, 20, or 30 minutes) and moves between topics so you get a well-rounded conversation covering architecture, databases, concurrency, and teamwork.

If you add a resume, Rehearse reads it (PDF, text, or a photo of a printed page) and pulls out your skills and education, so the interview can be about your real projects.


## Targeted practice

At the end of each session, you get a score out of 100 made of six areas:
- Technical Knowledge: Did you explain the concepts accurately?
- Problem Solving: Did you lay out a plan and weigh the trade-offs?
- Communication: Pace, filler words, response time and repeated words, measured from your speech.
- Project Depth: Did you say why you built things the way you did?
- Handling Uncertainty: Did you say plainly when you weren't sure, and reason it through?
- Confidence: Pauses, hedging, whether your voice held steady, and eye contact (from the front camera, on the phone; estimated until that's built).

The judged areas will be scored as a checklist against each question's key points, and code turns that checklist into numbers, so the model never just picks a score.

If you hit Rehearse Again, Rehearse automatically takes the biggest gap identified in that round and brings it up in the next interview. That way you spend time fixing the specific things you struggle to explain out loud.


## What is implemented

- Live interview room with timer controls, prompt progression, and answer review
- Speech-to-text and speech measurements, on the device
- Feedback reports across the six areas, showing how each score is worked out
- A question library of 11,483 questions, with search, difficulty and subject filters, playlists, and a daily Warm Up
- Accounts with Supabase: email sign up, log in, password reset, Delete Account, and sync of your profile, interviews, practice and playlists
- Resume reading, viewer, builder, scanner, Resume Library, and job-tailoring flows
- Interview Reminders: notifications 3 days, 1 day and 2 hours before each upcoming interview
- Home Screen widgets for your next interview and your latest score
- Onboarding, progress history, and a launch animation in light and dark

In progress: the AI interviewer (follow-up questions and answer judging), syncing resumes, and Sign in with Apple.


## Privacy

Audio is used only to transcribe your answers, on your iPhone. Audio is never saved or uploaded; only the transcript is kept.

Your interviews, transcripts and scores are stored in your own account, and the database only lets each account read its own rows. Reminders are scheduled on the phone and never sent through a server.

We do not run facial emotion tracking or speculative personality scores. Eye contact, once built, is worked out on the phone and no video is saved. The feedback is based on what you say, how you say it, and how you defend your technical choices.


## Running locally

### Requirements
- macOS with Xcode 26 or later
- iOS 26+ Simulator or connected iPhone (speech recognition needs a real iPhone)

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

Select the **Rehearse** scheme and an iOS Simulator or your connected device, then press **⌘R** (or **Product > Run**).

Out of the box, the app runs on built-in mock data, so you can try the whole interview loop, resume tools and feedback screens offline.

### Connecting Supabase (optional)

1. Create a Supabase project and run `supabase/schema.sql`, then the files in `supabase/migrations` in order, in the SQL Editor.
2. Import your questions into the `questions` table.
3. Put your project URL and **anon** key in `Rehearse/Backend/BackendSecrets.swift`. Never put the service role key in the app.


## Built with

- SwiftUI & Swift 6, with Observation (`@Observable`)
- Supabase (Auth, Postgres with row level security, Storage)
- Speech, AVFoundation, PDFKit and Vision
- WidgetKit and UserNotifications
- Apple Human Interface Guidelines, in light and dark mode


## Credits

Practice questions come from the [open-interview](https://github.com/open-interview/open-interview) project, used under the MIT licence.


## License

MIT
