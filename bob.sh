#!/bin/bash

# ==========================================
#             BOB THE BUILDER
# ==========================================
# Universal Android build + APK installer
#
# bob.sh / bob.conf can live anywhere.
# The directory from which "bob" is invoked
# is treated as the project root.
# ==========================================

set -e

# ------------------------------------------
# Locate Bob
# ------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/bob.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Bob configuration file not found:"
    echo "$CONFIG_FILE"
    exit 1
fi

# Project root = where bob was invoked
ROOT_DIR="$(pwd)"

# Load configuration
source "$CONFIG_FILE"


# ------------------------------------------
# Android environment
# ------------------------------------------

if [ -n "$ANDROID_HOME" ]; then
    export ANDROID_HOME
else
    ANDROID_HOME="$HOME/Android/Sdk"
    export ANDROID_HOME
fi

if [ -n "$JAVA_HOME" ]; then
    export JAVA_HOME
fi


# ------------------------------------------
# Output directories
# ------------------------------------------

OUTPUT_DIR="$ROOT_DIR/output"
APK_DIR="$OUTPUT_DIR/apk"
LOG_DIR="$OUTPUT_DIR/logs"

mkdir -p "$APK_DIR"
mkdir -p "$LOG_DIR"


# ------------------------------------------
# Header
# ------------------------------------------

echo ""
echo "======================================"
echo "        BOB THE BUILDER"
echo "======================================"
echo "Project Root : $ROOT_DIR"
echo "Bob Location : $SCRIPT_DIR"
echo "APK Output   : $APK_DIR"
echo "Log Output   : $LOG_DIR"
echo "======================================"


# ------------------------------------------
# Read projects from config
# ------------------------------------------

ALL_PROJECTS=()

while IFS='=' read -r key value; do
    if [[ "$key" == PROJECT_* ]]; then
        project_name="${key#PROJECT_}"
        ALL_PROJECTS+=("$project_name")
    fi
done < <(grep '^PROJECT_' "$CONFIG_FILE")


if [ ${#ALL_PROJECTS[@]} -eq 0 ]; then
    echo "ERROR: No projects found in:"
    echo "$CONFIG_FILE"
    exit 1
fi


# ------------------------------------------
# Get project path
# ------------------------------------------

get_project_path() {
    local project_name="$1"
    local line

    line=$(grep "^PROJECT_${project_name}=" "$CONFIG_FILE" | head -n 1)

    if [ -z "$line" ]; then
        echo ""
        return
    fi

    local path
    path="${line#*=}"

    # Remove surrounding quotes
    path="${path%\"}"
    path="${path#\"}"

    echo "$path"
}


# ------------------------------------------
# Build project
# ------------------------------------------

BUILT_PROJECTS=()

build_project() {
    local project_name="$1"
    local project_dir="$2"

    local apk_file="$APK_DIR/${project_name}-debug.apk"
    local log_file="$LOG_DIR/${project_name}-debug.log"

    echo ""
    echo "--------------------------------------"
    echo "Building: $project_name"
    echo "Path    : $project_dir"
    echo "--------------------------------------"

    if [ ! -d "$project_dir" ]; then
        echo "WARNING: Directory not found."
        echo "Skipping $project_name."
        return
    fi

    cd "$project_dir"

    if [ ! -f "./gradlew" ]; then
        echo "WARNING: No gradlew found."
        echo "Skipping $project_name."
        cd "$ROOT_DIR"
        return
    fi

    chmod +x ./gradlew

    local start_time
    start_time=$(date +%s)

    # Build
    if ./gradlew assembleDebug --no-daemon > "$log_file" 2>&1; then

        local apk_path

        apk_path=$(find app/build/outputs/apk/debug \
            -name "*.apk" 2>/dev/null | head -n 1)

        if [ -z "$apk_path" ]; then
            apk_path=$(find build/outputs/apk/debug \
                -name "*.apk" 2>/dev/null | head -n 1)
        fi

        if [ -n "$apk_path" ]; then

            cp "$apk_path" "$apk_file"

            local end_time
            local elapsed

            end_time=$(date +%s)
            elapsed=$((end_time - start_time))

            echo "SUCCESS: $project_name"
            echo "APK    : $apk_file"
            echo "Log    : $log_file"
            echo "Time   : ${elapsed}s"

            BUILT_PROJECTS+=("$project_name")

        else
            local end_time
            local elapsed

            end_time=$(date +%s)
            elapsed=$((end_time - start_time))

            echo "WARNING: Build succeeded but no APK was found."
            echo "Log: $log_file"
            echo "Time: ${elapsed}s"
        fi

    else

        local end_time
        local elapsed

        end_time=$(date +%s)
        elapsed=$((end_time - start_time))

        echo "ERROR: Build failed for $project_name."
        echo "Log : $log_file"
        echo "Time: ${elapsed}s"
    fi

    cd "$ROOT_DIR"
}


# ------------------------------------------
# Build selection
# ------------------------------------------

echo ""
echo "Select build type:"
echo "1) Full Build"
echo "2) Partial Build"

read -p "Enter your choice (1 or 2): " BUILD_CHOICE


if [ "$BUILD_CHOICE" == "1" ]; then

    echo ""
    echo "Full build selected."

    SELECTED_PROJECTS=("${ALL_PROJECTS[@]}")

elif [ "$BUILD_CHOICE" == "2" ]; then

    echo ""
    echo "Available projects:"
    echo ""

    for i in "${!ALL_PROJECTS[@]}"; do
        echo "$((i + 1))) ${ALL_PROJECTS[$i]}"
    done

    echo ""

    read -p "Enter project numbers (e.g. '1 3 5'): " USER_SELECTION

    SELECTED_PROJECTS=()

    for num in $USER_SELECTION; do

        if [[ "$num" =~ ^[0-9]+$ ]] &&
           [ "$num" -ge 1 ] &&
           [ "$num" -le "${#ALL_PROJECTS[@]}" ]; then

            index=$((num - 1))
            SELECTED_PROJECTS+=("${ALL_PROJECTS[$index]}")

        else
            echo "WARNING: Invalid selection '$num'. Ignoring."
        fi

    done

    if [ ${#SELECTED_PROJECTS[@]} -eq 0 ]; then
        echo "ERROR: No valid projects selected."
        exit 1
    fi

else

    echo "ERROR: Invalid choice."
    exit 1

fi


# ------------------------------------------
# Start builds
# ------------------------------------------

echo ""
echo "======================================"
echo "Starting builds..."
echo "======================================"

TOTAL_START_TIME=$(date +%s)


for project in "${SELECTED_PROJECTS[@]}"; do

    project_path=$(get_project_path "$project")

    if [ -z "$project_path" ]; then
        echo ""
        echo "WARNING: No path configured for:"
        echo "$project"
        continue
    fi

    # Resolve relative project paths against
    # the directory where bob was invoked.

    if [[ "$project_path" != /* ]]; then
        project_path="$ROOT_DIR/${project_path#./}"
    fi

    build_project "$project" "$project_path"

done


TOTAL_END_TIME=$(date +%s)
TOTAL_ELAPSED=$((TOTAL_END_TIME - TOTAL_START_TIME))


# ------------------------------------------
# Build summary
# ------------------------------------------

echo ""
echo "======================================"
echo "        BUILD SUMMARY"
echo "======================================"

echo "Successful builds: ${#BUILT_PROJECTS[@]}"
echo "Total time       : ${TOTAL_ELAPSED}s"


if [ ${#BUILT_PROJECTS[@]} -gt 0 ]; then

    echo ""
    echo "Generated APKs:"

    for project in "${BUILT_PROJECTS[@]}"; do
        echo "  ✓ $project"
    done

else

    echo ""
    echo "No APKs were generated."

fi


# ------------------------------------------
# ADB installation
# ------------------------------------------

echo ""

read -p \
"Do you want to install APKs to a connected Android device? (y/n): " \
INSTALL_CHOICE


if [[ ! "$INSTALL_CHOICE" =~ ^[yY]([eE][sS])?$ ]]; then
    echo "Skipping installation."
else

    ADB_PATH="$ANDROID_HOME/platform-tools/adb"

    if [ ! -f "$ADB_PATH" ]; then
        ADB_PATH="$(command -v adb || true)"
    fi

    if [ -z "$ADB_PATH" ]; then
        echo "ERROR: adb not found."
        exit 1
    fi


    if ! "$ADB_PATH" get-state >/dev/null 2>&1; then
        echo "ERROR: No Android device/emulator found."
        exit 1
    fi


    if [ ${#BUILT_PROJECTS[@]} -eq 0 ]; then
        echo "No newly built APKs available."
    else

        echo ""
        echo "ADB installation options:"
        echo "1) Install newly built APKs"
        echo "2) Install all available APKs"
        echo "3) Skip installation"

        read -p "Enter your choice (1, 2 or 3): " ADB_CHOICE


        install_project_apk() {

            local project="$1"
            local apk="$APK_DIR/${project}-debug.apk"

            if [ ! -f "$apk" ]; then
                echo "WARNING: APK not found for $project"
                return
            fi

            echo ""
            echo "Installing $project..."

            if "$ADB_PATH" install -r -t -d "$apk"; then
                echo "SUCCESS: $project installed."
            else
                echo "WARNING: Failed to install $project."
            fi
        }


        if [ "$ADB_CHOICE" == "1" ]; then

            echo ""
            echo "Installing newly built APKs..."

            for project in "${BUILT_PROJECTS[@]}"; do
                install_project_apk "$project"
            done


        elif [ "$ADB_CHOICE" == "2" ]; then

            echo ""
            echo "Installing all available APKs..."

            for apk in "$APK_DIR"/*-debug.apk; do

                if [ ! -f "$apk" ]; then
                    continue
                fi

                project=$(basename "$apk" "-debug.apk")
                install_project_apk "$project"

            done


        elif [ "$ADB_CHOICE" == "3" ]; then

            echo "Skipping installation."

        else

            echo "Invalid choice."
            echo "Skipping installation."

        fi

    fi

fi


# ------------------------------------------
# Completion
# ------------------------------------------

echo ""
echo "======================================"
echo "       BOB THE BUILDER DONE"
echo "======================================"
echo ""

printf '\a'

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Bob the Builder" "Build process complete!"
fi