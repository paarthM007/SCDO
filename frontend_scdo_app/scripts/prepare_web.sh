#!/bin/bash

# This script injects the Google Maps API key from .env into index.html for web builds.
# It assumes .env is in the root directory and index.html is in frontend_scdo_app/web/

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_PATH="$SCRIPT_DIR/../../../.env"
INDEX_PATH="$SCRIPT_DIR/../web/index.html"

# Load API key from .env
if [ -f "$ENV_PATH" ]; then
    export $(grep GOOGLE_MAPS_API_KEY "$ENV_PATH" | xargs)
else
    echo "Error: .env file not found at $ENV_PATH"
    exit 1
fi

if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
    echo "Error: GOOGLE_MAPS_API_KEY not found in .env."
    exit 1
fi

# Replace placeholder in index.html
SED_CMD="s/GOOGLE_MAPS_API_KEY_PLACEHOLDER/$GOOGLE_MAPS_API_KEY/g"

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$SED_CMD" "$INDEX_PATH"
else
    sed -i "$SED_CMD" "$INDEX_PATH"
fi

echo "Successfully injected API key into index.html"
