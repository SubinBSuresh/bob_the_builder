# Bob the Builder

A small Bash utility for building multiple Android projects from a single command.

## Why Bob?

Android projects often end up scattered across a workspace, each with its own Gradle wrapper and build output. Bob was created as a simple personal tool to make building a group of related projects less repetitive.

The goal is not to replace Gradle or introduce another build system. Bob simply orchestrates the repetitive parts around it.

## What it does

- Builds all configured projects or a selected subset
- Keeps project configuration outside the script
- Collects generated APKs into one `output/apk/` directory
- Keeps the latest build log for each project in `output/logs/`
- Installs newly built or previously available APKs through ADB
- Shows a completion notification when the run finishes

## How it works

Bob itself can live anywhere.

The directory from which `bob` is run is treated as the project root, while `bob.conf` is resolved relative to Bob's own location.

For example:

```text
workspace/
├── app/
├── services/
│   ├── ServiceA/
│   └── ServiceB/
└── output/
    ├── apk/
    └── logs/
```

Projects are defined in `bob.conf`:

```bash
PROJECT_App="./app"
PROJECT_ServiceA="./services/ServiceA"
PROJECT_ServiceB="./services/ServiceB"
```

Bob then runs each project's Gradle wrapper and collects the resulting debug APK.

## Usage

Configure Bob:

```bash
cp bob.conf.example bob.conf
```

Add your projects to `bob.conf`, then run:

```bash
cd /path/to/project
bob
```

Bob provides options for:

```text
Full Build
Partial Build
ADB Installation
```

## Output

```text
output/
├── apk/
│   ├── App-debug.apk
│   ├── ServiceA-debug.apk
│   └── ServiceB-debug.apk
└── logs/
    ├── App-debug.log
    ├── ServiceA-debug.log
    └── ServiceB-debug.log
```

Only the latest APK and log for each project are retained.

## Requirements

- Bash
- Android SDK
- JDK
- Android projects with `gradlew`
- ADB (for installation)

`notify-send` is optional and is used for the desktop notification.

## Installation

Clone Bob somewhere convenient and make it executable:

```bash
chmod +x bob.sh
```

Add an alias if desired:

```bash
alias bob="$HOME/tools/bob/bob.sh"
```

Then run `bob` from any configured Android project root.

## Configuration

See [`bob.conf.example`](bob.conf.example) for the configuration format.

`bob.conf` is machine-specific and should not be committed.
