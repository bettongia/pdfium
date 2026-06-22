#!/usr/bin/env bash

# Copyright 2026 The Authors. See the AUTHORS file for details.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Set the name of your Podman machine (defaults to podman-machine-default)
MACHINE_NAME="${1:-podman-machine-default}"

if xcodebuild -version 2>&1 | grep -q "Xcode"; then
    echo "Match found: Xcode is installed."
else
    echo "Match not found or command failed."
    exit 1
fi

echo "Checking the status of Podman machine: '${MACHINE_NAME}'..."

# Extract the exact state using the Go template
CURRENT_STATE=$(podman machine inspect --format "{{.State}}" "$MACHINE_NAME" 2>/dev/null)

# Handle errors if the machine does not exist
if [ -z "$CURRENT_STATE" ]; then
    echo "Error: Machine '${MACHINE_NAME}' not found."
    exit 1
fi

echo "Current state is: ${CURRENT_STATE}"

# Check the state and start if necessary
if [ "$CURRENT_STATE" != "running" ]; then
    echo "Machine is not running. Starting it now..."
    podman machine start "$MACHINE_NAME"
else
    echo "Machine is already running. No action needed."
fi
