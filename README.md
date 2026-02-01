# Incant

Menu bar speech-to-text using OpenAI Whisper API.

## Setup

Set your OpenAI API key via environment variable:

```bash
export OPENAI_API_KEY=sk-...
```

Or add to `~/.env`:

```
OPENAI_API_KEY=sk-...
```

## Build & Run

```bash
swift build
swift run
```

For release build:

```bash
swift build -c release
.build/release/Incant
```

## Usage

- **⌥ `** (Option + backtick) — Toggle recording
- **Click menu bar icon** — View costs, recent transcripts, settings

Transcripts are automatically copied to clipboard.

## Features

- Global hotkey works from any app
- Doesn't interrupt audio playback
- Cost tracking (daily/total)
- Model selection (Whisper vs GPT-4o-mini for half cost)
- Persistent transcript history
- Launch at login option

## Data Storage

- `~/Library/Application Support/Incant/costs.json` — Cost tracking
- `~/Library/Application Support/Incant/transcripts.json` — Transcript history
