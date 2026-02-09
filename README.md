# Qrophy

A Flutter quiz tournament app that generates quizzes from any content using Google Gemini AI, then lets you compete in a 1024-player single-elimination tournament against AI opponents.

## How Gemini API is Used

Qrophy uses the **Google Gemini API** (`gemini-3-flash-preview` model via REST) in three distinct ways:

### 1. Quiz Generation
When creating or adding questions to a project, the app sends content (extracted text from uploaded files, fetched web page text, or a user-written prompt) to Gemini with instructions to generate quiz question-answer pairs. Gemini returns a JSON array of `{"question": "...", "answer": "..."}` objects, which are parsed and stored in the local SQLite database.

- **Endpoint**: `generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent`
- **Input**: File contents (read as plain text), web page text (HTML stripped), and/or custom prompt
- **Output**: JSON array of question-answer pairs
- **Temperature**: 0.7 (for diverse question generation)

### 2. AI Weakness Analysis
After a tournament, the app collects all of the user's wrong answers (question, correct answer, user's answer) and sends them to Gemini for analysis. Gemini identifies weak areas, common mistake patterns, and provides improvement advice.

- **Input**: List of wrong answers with question text, correct answer, and user's answer
- **Output**: Free-text analysis (bullet points summarizing weaknesses)
- **Temperature**: 0.5 (for balanced, focused analysis)

### 3. AI Challenge (Semantic Answer Matching)
In fill-in-blank rounds (Semifinals/Finals), if the user's answer is marked wrong but they believe it's semantically equivalent (e.g., "green" vs "green color"), they can trigger an AI Challenge. Gemini judges whether the two answers mean the same thing while enforcing strict spelling.

- **Input**: Question text, correct answer, user's answer
- **Output**: Single word — `ACCEPT` or `REJECT`
- **Temperature**: 0.0 (for deterministic judging)

## Features

### Quiz Generation
- Generate quiz questions from **files** (PDF, TXT, MD, DOC), **URLs**, or **custom prompts** via Google Gemini API
- Add more questions to existing projects at any time (AI-generated or manual entry)
- Edit and delete individual questions

### Tournament System
- **1024-player single-elimination bracket** (you + 1023 AI personas)
- 10 rounds from Round of 1024 to Finals
- 3 questions per round (multiple choice)
- Semifinals and Finals use **fill-in-blank** format with character count hints
- View the full bracket after each round
- **Spectator mode** — continue watching the tournament after elimination
- Tie goes to the user

### AI Personas
- 1023 unique AI opponents with randomized names, countries, and win rates
- Win rate-based match simulation for AI vs AI matches
- Fully customizable — edit any persona's name, country, or stats

### Smart Features
- **AI Challenge** — for fill-in-blank questions, challenge a "wrong" answer if it's semantically equivalent to the correct answer (e.g., "green" vs "green color"). Strict on spelling.
- **AI Weakness Analysis** — collects your wrong answers across rounds and provides Gemini-powered analysis of your weak areas
- **No Time Limit mode** — alternating turns between you and AI until someone answers correctly

### Results & Rankings
- Championship points system (1st place: 3 pts, 2nd place: 1 pt)
- Per-project leaderboard with all participants
- Question usage tracking across tournaments
- Post-tournament question review

### Victory Celebration
- Trophy display with confetti animation
- Accelerometer-triggered crowd cheering (lift your phone!)

## Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter |
| State Management | Riverpod |
| Navigation | GoRouter |
| Local Database | SQLite (sqflite) |
| AI / Quiz Generation | Google Gemini API |
| Animations | Confetti |
| Sensors | sensors_plus |
| Audio | audioplayers |

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/       # App & API constants
│   ├── theme/           # Colors & theme
│   └── utils/           # String & random utilities
├── data/
│   ├── datasources/     # SQLite database service
│   └── models/          # Data models (Project, Question, Tournament, etc.)
├── presentation/
│   ├── providers/       # Riverpod providers (Gemini, Tournament, Project, etc.)
│   ├── router/          # GoRouter configuration
│   └── screens/         # All app screens
│       ├── home/
│       ├── project_creation/
│       ├── project_detail/
│       ├── pre_match/
│       ├── tournament/
│       ├── spectator/
│       ├── victory/
│       ├── results/
│       ├── rankings/
│       ├── analysis/
│       ├── personas/
│       └── user_profile/
└── services/
```

## Getting Started

### Prerequisites
- Flutter SDK ^3.9.2
- A Google Gemini API key

### Setup

1. Clone the repository
2. Create a `.env` file in the project root:
   ```
   GEMINI_API_KEY=your_api_key_here
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## How It Works

1. **Create a project** — upload files, paste URLs, or write a prompt to generate quiz questions
2. **Start a tournament** — you need at least 10 questions
3. **Compete** — answer 3 questions per round against a randomly matched AI opponent
4. **Advance or spectate** — win to advance, or watch the rest as a spectator
5. **Win the cup** — make it through all 10 rounds to become champion

## License
MIT License