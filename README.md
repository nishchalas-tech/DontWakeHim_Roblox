# 🎮 DON'T WAKE HIM

### He's sleeping. You're trapped. Don't make a sound.

**DON'T WAKE HIM** is a Roblox co-op horror and stealth game concept where players must explore a dangerous house, find the items needed to escape, and avoid waking the sleeping man inside.

The challenge is simple: **every action has a risk.** Move too quickly, open the wrong door, or make too much noise, and a quiet escape can turn into a desperate chase.

> 🤫 Stay quiet. 🔑 Find the keys. 🏃 Escape together.
> **Whatever you do, DON'T WAKE HIM.**

---

## 📌 Table of Contents

* [About the Game](#-about-the-game)
* [Core Gameplay](#-core-gameplay)
* [Key Features](#-key-features)
* [The Sleeping Man](#-the-sleeping-man)
* [Noise and Stealth System](#-noise-and-stealth-system)
* [Multiplayer Experience](#-multiplayer-experience)
* [Technology Stack](#-technology-stack)
* [Project Architecture](#-project-architecture)
* [Getting Started](#-getting-started)
* [Development and Testing](#-development-and-testing)
* [Development Roadmap](#-development-roadmap)
* [Project Status](#-project-status)
* [Contributing](#-contributing)
* [License](#-license)

---

## 👻 About the Game

DON'T WAKE HIM is built around a simple horror-game premise: players are trapped inside a house with someone who must not wake up.

Instead of relying entirely on jumpscares, the gameplay is designed around tension, sound, decision-making, and cooperation.

Players must explore the environment, locate keys and other required items, interact with objects carefully, and find a way out. Every unnecessary action can increase the danger.

Playing with friends introduces another challenge: even if you are careful, someone else might not be.

### Game Overview

| Category                | Details                          |
| ----------------------- | -------------------------------- |
| Game title              | DON'T WAKE HIM                   |
| Platform                | Roblox                           |
| Genre                   | Co-op horror, stealth and escape |
| Target players          | 1–3 players                      |
| Core mechanic           | Noise management                 |
| Main objective          | Find required items and escape   |
| Primary antagonist      | The Sleeping Man                 |
| Intended round duration | Approximately 3–5 minutes        |
| Development language    | Luau                             |
| Development environment | Roblox Studio                    |

---

## 🎯 Core Gameplay

The game is designed around a short, replayable gameplay loop.

### 1. Enter the House

Players begin a round and enter a house filled with rooms, doors, interactable objects, hiding places, and objectives.

The environment should encourage exploration without making navigation unnecessarily complicated.

### 2. Search for Keys and Items

Players explore the house to locate the items required to unlock their escape route.

Items may be placed in different locations between rounds to make repeated attempts less predictable.

### 3. Control the Noise

Movement and interactions create risk. Players must decide whether to move quickly or take a slower, quieter approach.

A noise indicator is intended to help players understand how close they are to making a dangerous amount of noise.

### 4. Avoid the Sleeping Man

As noise increases, the Sleeping Man may become disturbed and eventually transition into an active threat.

Players must react to warning cues, avoid attracting attention, and use the environment to their advantage.

### 5. Hide, Cooperate, and Escape

When danger increases, players need to find hiding places, coordinate with teammates, and complete the escape objective.

The goal is to get out alive before the round turns into a disaster.

**The central gameplay question:** How much risk are you willing to take to escape faster?

---

## ✨ Key Features

The following features define the intended direction of the project.

* **Cooperative horror:** Designed for solo play and small groups of up to three players.
* **Noise-driven gameplay:** Noise is intended to influence the danger level rather than acting as a purely decorative meter.
* **Objective-based escape:** Players must find the required items before completing their escape.
* **Enemy state machine:** A structured approach to the Sleeping Man's behavior.
* **Environmental interaction:** Doors, keys, hiding locations, and other objects form part of the intended gameplay.
* **Short replayable rounds:** Compact sessions designed to encourage players to try again.
* **Server-authoritative architecture:** Important gameplay decisions should be validated by the server.
* **Mobile-aware design:** Controls and interfaces should remain usable on supported mobile devices.
* **Expandable codebase:** Separate services and controllers make individual systems easier to maintain.

*These are project goals and design features; they should not be interpreted as confirmation that every feature is already complete or tested.*

---

## 😴 The Sleeping Man

The Sleeping Man is the central antagonist and the main source of tension.

The intended behavior is organized into a series of states:

| State     | Intended behavior                                                  |
| --------- | ------------------------------------------------------------------ |
| Sleeping  | The man remains asleep while players explore.                      |
| Disturbed | Noise or other gameplay conditions begin to attract his attention. |
| Waking    | Warning cues signal that the danger is increasing.                 |
| Searching | The man investigates suspicious activity.                          |
| Chasing   | The man pursues a detected player.                                 |

The state-based design makes it easier to develop and test enemy behavior independently.

The goal is not to create an unnecessarily complicated enemy. Instead, the enemy's behavior should make ordinary player actions feel risky.

---

## 🔊 Noise and Stealth System

Noise is the defining mechanic of DON'T WAKE HIM.

Players should constantly balance speed against safety. Moving quickly may save time, but noisy actions can increase the chance of waking the man.

The planned noise system uses a range from **0 to 100**.

| Noise level | Intended classification |
| ----------- | ----------------------- |
| 0–39        | SAFE                    |
| 40–69       | ALERT                   |
| 70–89       | DANGER                  |
| 90–100      | WAKE                    |

Potential noise sources include:

* Player movement and sprinting
* Opening or closing doors
* Interacting with objects
* Other loud environmental events

The intended system also includes noise decay, allowing danger to decrease when players remain quiet.

The server should control the authoritative noise value. Clients should display the information and send valid interaction requests rather than directly deciding the game's danger state.

---

## 🤝 Multiplayer Experience

DON'T WAKE HIM is designed around small-group cooperation.

Players should be able to divide responsibilities, communicate about danger, search different rooms, and help one another complete the escape objective.

Multiplayer also creates opportunities for unpredictable moments. A player who rushes ahead or interacts carelessly can put the entire group at risk.

Important multiplayer considerations include:

* Supporting solo, two-player, and three-player sessions.
* Handling players leaving during an active round.
* Keeping objectives and enemy behavior consistent across clients.
* Preventing duplicate rewards or invalid objective completion.
* Resetting the round cleanly before another attempt.
* Ensuring that clients cannot directly grant themselves rewards or declare a successful escape.

---

## 🛠️ Technology Stack

| Technology            | Purpose                                                              |
| --------------------- | -------------------------------------------------------------------- |
| Roblox Studio         | Game development, scene editing, and playtesting                     |
| Luau                  | Gameplay scripting                                                   |
| Roblox server scripts | Authoritative gameplay systems                                       |
| Roblox LocalScripts   | Client-side input, UI, audio, and presentation                       |
| ReplicatedStorage     | Shared modules and configuration                                     |
| Git                   | Version control                                                      |
| GitHub                | Remote source-code hosting and collaboration                         |
| Python                | Project-building and test-support scripts included in the repository |

The project uses a modular structure to separate shared logic, server-side services, and client-side controllers.

---

## 🏗️ Project Architecture

The repository separates the project into shared modules, server services, and client controllers.

```text
DontWakeHim_Roblox/
│
├── src/
│   ├── ReplicatedStorage/
│   │   └── Shared/
│   │       ├── Config.luau
│   │       ├── Constants.luau
│   │       └── Utility.luau
│   │
│   ├── ServerScriptService/
│   │   ├── MainServer.server.luau
│   │   └── Services/
│   │       ├── AnalyticsService.luau
│   │       ├── DataService.luau
│   │       ├── InteractionService.luau
│   │       ├── MonetizationService.luau
│   │       ├── MonsterService.luau
│   │       ├── NoiseService.luau
│   │       ├── ObjectiveService.luau
│   │       ├── RewardService.luau
│   │       └── RoundService.luau
│   │
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           ├── MainClient.client.luau
│           └── Controllers/
│               ├── AudioController.luau
│               ├── CameraController.luau
│               ├── ClientController.luau
│               ├── InteractionController.luau
│               └── UIController.luau
│
├── DontWakeHim.rbxlx
├── build_place.py
├── run_tests.py
├── default.project.json
├── AGENTS.md
├── FINAL_REPORT.md
├── README.md
└── .gitignore
```

### Architecture Responsibilities

**Shared modules**

* `Config.luau` — central configuration values.
* `Constants.luau` — shared constants used across systems.
* `Utility.luau` — reusable helper functions.

**Server services**

* `RoundService.luau` — round lifecycle and state management.
* `NoiseService.luau` — noise-related game logic.
* `MonsterService.luau` — Sleeping Man behavior.
* `ObjectiveService.luau` — objectives and required items.
* `InteractionService.luau` — interaction-related validation and handling.
* `DataService.luau` — player data-related logic.
* `RewardService.luau` — reward-related logic.
* `MonetizationService.luau` — monetization-related logic.
* `AnalyticsService.luau` — gameplay analytics-related logic.

**Client controllers**

* `ClientController.luau` — client-side controller coordination.
* `InteractionController.luau` — player interaction input.
* `AudioController.luau` — sound and audio presentation.
* `CameraController.luau` — camera behavior and effects.
* `UIController.luau` — interface and gameplay information.

The intended architectural boundary is straightforward: the server owns important game state, while clients handle presentation and player input. The actual implementation and initialization paths still require validation in Roblox Studio.

---

## 🚀 Getting Started

### Prerequisites

Before working on the project, install:

* [Roblox Studio](https://create.roblox.com/)
* [Git](https://git-scm.com/)
* A GitHub account if you want to clone or contribute to the hosted repository.

### Option 1: Download the Project

1. Open the [DON'T WAKE HIM GitHub repository](https://github.com/nishchalas-tech/DontWakeHim_Roblox).
2. Select **Code → Download ZIP**.
3. Extract the downloaded archive.
4. Locate `DontWakeHim.rbxlx`.
5. Open the place file in Roblox Studio.

### Option 2: Clone the Repository

Open PowerShell or a terminal and run:

```bash
git clone https://github.com/nishchalas-tech/DontWakeHim_Roblox.git
cd DontWakeHim_Roblox
```

Open `DontWakeHim.rbxlx` in Roblox Studio to inspect the place.

The repository also contains the source scripts and `default.project.json`. If you want to sync the source tree into Studio using a tool such as Rojo, first confirm the required tooling and project configuration.

### Run and Inspect

1. Open the place in Roblox Studio.
2. Inspect the Explorer hierarchy and Output window.
3. Use **Play** to test the experience.
4. Check the Output window for script errors.
5. Verify interactions, movement, noise updates, objectives, and enemy behavior before treating the game as playable.

**Important:** Opening the place successfully does not guarantee that every script or gameplay system works. Use Studio playtests to verify behavior.

---

## 🧪 Development and Testing

Testing is particularly important for a multiplayer game where client and server state must remain consistent.

The repository includes `run_tests.py`, a Python test-support script. Its existence alone does not establish that all gameplay behavior has been tested inside Roblox Studio.

### Recommended Test Checklist

* [ ] The place opens without errors.
* [ ] The client bootstrap initializes successfully.
* [ ] The UI and interaction controls load.
* [ ] Doors and other supported interactions work.
* [ ] Noise increases in response to supported actions.
* [ ] Noise decreases when the player remains quiet.
* [ ] Objective items can be collected and tracked.
* [ ] The escape condition is validated by the server.
* [ ] The Sleeping Man changes states correctly.
* [ ] Hiding and chase behavior work as intended.
* [ ] The round resets without leaving old objects behind.
* [ ] Solo, two-player, and three-player sessions are tested.
* [ ] Player departure during a round is handled safely.
* [ ] Mobile controls and lower-end devices are tested.

### Security Principles

Gameplay-critical decisions should not trust arbitrary client requests.

* The server should validate item collection.
* The server should own rewards and progression.
* The server should control the authoritative noise and enemy state.
* Purchases and reward claims should be validated.
* Remote events should validate arguments, distance, permissions, and game state where appropriate.

These principles are implementation requirements, not claims that every security check has already passed an audit.

---

## 🗺️ Development Roadmap

The development roadmap prioritizes a complete playable loop before optional features.

### Phase 1 — Playable Foundation

* [ ] House layout and spawn points
* [ ] Working round lifecycle
* [ ] Door and object interactions
* [ ] Key placement and collection
* [ ] Exit requirements

### Phase 2 — Core Horror Mechanics

* [ ] Working noise meter
* [ ] Noise decay and danger thresholds
* [ ] Sleeping Man state machine
* [ ] Search and chase behavior
* [ ] Hiding mechanics and warning cues

### Phase 3 — Multiplayer and Reliability

* [ ] Solo, two-player, and three-player testing
* [ ] Player departure handling
* [ ] Objective and round-reset validation
* [ ] Server-side security checks
* [ ] Client initialization and error handling

### Phase 4 — Atmosphere and Polish

* [ ] Snoring and ambient audio
* [ ] Footsteps and interaction sounds
* [ ] Lighting and camera effects
* [ ] Improved UI and onboarding
* [ ] Mobile controls and performance optimization

### Phase 5 — Progression and Release Preparation

* [ ] Persistent player data
* [ ] Tested rewards and progression
* [ ] Optional cosmetics
* [ ] Analytics and performance review
* [ ] Icon, thumbnails, and game description
* [ ] Closed playtest and release-readiness review

Optional monetization and progression should not take priority over making the core game reliable and fun.

---

## 📍 Project Status

**Current status: Prototype / active development.**

The repository contains a Roblox place file, Luau source modules, project configuration, and Python development-support scripts.

The game is not yet confirmed to be release-ready. The following areas require verification in Roblox Studio:

* Client initialization and controller loading
* Actual house and level completeness
* Functional interactions and noise updates
* Enemy movement and state transitions
* Objective completion and round resets
* Multiplayer behavior and mobile usability

The project should be considered a work in progress until a complete round can be played successfully from start to finish.

---

## 🤝 Contributing

Contributions, bug reports, and practical improvement suggestions are welcome.

### Suggested Contribution Workflow

1. Fork the repository or request access if collaborating directly.
2. Create a separate branch for your changes.
3. Keep changes focused on one system.
4. Test the affected behavior in Roblox Studio.
5. Describe the changes and any remaining limitations.
6. Submit a pull request for review.

Example:

```bash
git checkout -b fix/noise-system
```

After making and testing changes:

```bash
git add .
git commit -m "Fix noise system behavior"
git push -u origin fix/noise-system
```

Please avoid committing credentials, personal configuration files, temporary automation scripts, or unrelated local data.

---

## 📄 License

No explicit open-source license is currently specified in this repository.

Until a license is added, do not assume that the code is freely available for redistribution, commercial reuse, or modification under an open-source license. The repository owner's permission and applicable law govern those uses.

---

## 🌙 Final Note

DON'T WAKE HIM is built around one small idea with a lot of potential: **the quieter your team is, the better your chances of survival.**

The aim is to combine simple controls, tense exploration, noise-driven danger, and chaotic cooperation into a short horror experience that players want to replay with friends.

Find the keys. Watch your noise. Trust your teammates.

And whatever you do—

# DON'T WAKE HIM. 🤫

---

**Repository:** [github.com/nishchalas-tech/DontWakeHim_Roblox](https://github.com/nishchalas-tech/DontWakeHim_Roblox)
