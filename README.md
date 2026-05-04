# CouchQueue

A two-part Apple app for groups to collaboratively queue and vote on what to watch, browse, or do next — displayed on Apple TV, controlled from iPhone.

## How it works

**CouchQueue (tvOS)** runs on the Apple TV. It hosts a local TCP server over Bonjour, displays the current queue ranked by votes, and shows a QR code with the room code.

**CouchQueueRemote (iOS)** runs on an iPhone on the same Wi-Fi. It discovers the Apple TV automatically via Bonjour, lets anyone submit ideas (links, searches, restaurants, anything), vote on items, and control an offscreen browser whose screen is streamed live to the TV.

```
iPhone (CouchQueueRemote)
  │  Bonjour discovery + TCP on port 8765
  ▼
Apple TV (CouchQueue)
  • Shows ranked queue
  • Streams browser frames from iPhone
  • Broadcasts room state to remote
```

## Features

- **Shared queue** — submit any title with an optional URL; items rank by vote count in real time
- **Voting** — tap to vote or unvote; one vote per person per item
- **Live browser** — iPhone runs an offscreen WebKit browser; frames stream to the TV at up to 30fps
- **Trackpad control** — single-finger pan moves the cursor, tap clicks, two-finger pan scrolls
- **Keyboard input** — type into focused web fields from the iPhone keyboard
- **Quick-launch shortcuts** — YouTube, Twitch, Reddit, Netflix, Plex, Google
- **Auto-reconnect** — remote reconnects automatically if the connection drops

## Requirements

- Apple TV running tvOS 16 or later
- iPhone running iOS 16 or later
- Both devices on the same Wi-Fi network
- Xcode 15+ with [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed

## Building

```bash
brew install xcodegen
git clone https://github.com/ramaraju3/CouchQueue.git
cd CouchQueue
./setup.sh
open CouchQueue.xcodeproj
```

Build the **CouchQueue** scheme to the Apple TV and the **CouchQueueRemote** scheme to the iPhone.

## Project structure

```
CouchQueue/          tvOS app — server, queue UI, QR code display
CouchQueueRemote/    iOS app — remote control, browser engine, trackpad
project.yml          XcodeGen project definition
setup.sh             Runs XcodeGen and opens the project
```

## Protocol

Both apps speak a simple binary protocol over TCP:

```
[type: 1 byte][length: 4 bytes big-endian][payload: N bytes]
```

| Type | Direction | Payload |
|------|-----------|---------|
| `0x01` | iPhone → TV | JSON `RemoteCommand` |
| `0x02` | iPhone → TV | JPEG frame (browser screenshot) |
| `0x03` | TV → iPhone | JSON `RoomState` |
