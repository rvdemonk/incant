# Incant

Menu bar speech-to-text tool using OpenAI's Whisper API.

## Origin

Built to solve a specific friction point: Mac's native dictation doesn't work well with terminal applications like Claude Code. The cursor focus requirement breaks dictation when scrolling through long terminal output. Additionally, native dictation pauses audio playback, which is disruptive.

The name "incant" evokes speaking magic words — fitting for a tool that turns voice into text for an AI assistant.

## Design Decisions

**Swift Package over Xcode project**: Chose `Package.swift` over `.xcodeproj` for cleaner version control (no opaque pbxproj files), simpler terminal workflow (`swift build`/`swift run`), and easier code review. Xcode can still open it natively.

**AVAudioEngine tap over exclusive mic access**: Uses `installTap` rather than taking exclusive microphone control. This allows recording while music plays — a deliberate choice after experiencing how native dictation interrupts audio.

**Global hotkey via Carbon API**: Uses the legacy `RegisterEventHotKey` Carbon API because it works reliably without accessibility permissions for basic hotkeys. The key simulation for auto-paste modes uses CGEvent which may require accessibility permissions.

**Three hotkey modes**: The starting hotkey determines behavior on completion:
- `⌥`` ` `` — Copy only (clipboard, manual paste)
- `⌥⇧`` ` `` — Copy + auto-paste (simulates ⌘V)
- `⌥⌃`` ` `` — Copy + auto-paste + Enter (for sending messages)

This avoids needing different stop hotkeys — the mode is set when you start recording.

**GPT-4o-mini as default model**: Half the cost ($0.003/min vs $0.006/min) with acceptable quality for most dictation. However, it struggles with technical terms (transcribes "tmux" as "PMUX"). Keep Whisper available for technical contexts.

**Single-click menu, hotkey for recording**: Originally had left-click toggle recording, right-click show menu. Simplified to single-click always shows menu since trackpad right-clicks are unreliable and the global hotkey handles recording better anyway.

## Anti-patterns

**Don't add complex audio processing**: The goal is minimal latency from voice to clipboard. Noise cancellation, VAD, or local processing would add complexity without proportional benefit — Whisper handles noisy audio well.

**Don't add account systems or cloud sync**: This is a personal utility. Preferences and history are local files in `~/Library/Application Support/Incant/`. Keep it simple.

**Don't over-engineer the UI**: It's a menu bar utility, not an app. Resist adding preference windows, onboarding flows, or visual complexity. The menu is the entire interface.

## File Locations

- `~/Library/Application Support/Incant/costs.json` — Running cost totals
- `~/Library/Application Support/Incant/transcripts.json` — Persistent history (last 50)

## API Key Loading

Checks in order: `OPENAI_API_KEY` env var → `~/.env` file. Environment variable is the standard approach for public distribution; the `.env` fallback exists for local dev convenience.

## Sound Design

Pop-pop-glass pattern: Pop for toggle (start/stop recording), Glass for success (transcript ready). Avoided "Tink" for start — it's Apple's "rejection" sound (like backspace on empty field) and feels like an error.
