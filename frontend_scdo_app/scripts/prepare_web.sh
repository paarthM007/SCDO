#!/bin/bash

# This script injects the Google Maps API key from .env into index.html for web builds.
# It assumes .env is in the root directory and index.html is in frontend_scdo_app/web/

# Load API key from .env
if [ -f "../../.env" ]; then
    export $(grep GOOGLE_MAPS_API_KEY ../../.env | xargs)
else
    echo "Error: .env file not found in root directory."
    exit 1
fi

if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
    echo "Error: GOOGLE_MAPS_API_KEY not found in .env."
    exit 1
fi

# Replace placeholder in index.html
SED_CMD="s/GOOGLE_MAPS_API_KEY_PLACEHOLDER/$GOOGLE_MAPS_API_KEY/g"

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$SED_CMD" ../web/index.html
else
    sed -i "$SED_CMD" ../web/index.html
fi

echo "Successfully injected API key into index.html"
