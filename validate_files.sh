#!/bin/bash

# Set directory paths
UTILITIES_DIR="utilities"
IMAGES_OTD_DIR="images-otd"

# Expected file counts
EXPECTED_UTILITIES_COUNT=14
EXPECTED_IMAGES_OTD_COUNT=24

# Count .deb files in utilities directory including subdirectories
actual_utilities_count=$(find "$UTILITIES_DIR" -type f -name "*.deb" | wc -l)

# Count files in images-otd directory excluding subdirectories
actual_images_otd_count=$(find "$IMAGES_OTD_DIR" -maxdepth 1 -type f | wc -l)

# Validate counts
if [ "$actual_utilities_count" -lt "$EXPECTED_UTILITIES_COUNT" ]; then
  echo "false"  # Return false if there are fewer .deb files in utilities
  exit 1
fi

if [ "$actual_images_otd_count" -lt "$EXPECTED_IMAGES_OTD_COUNT" ]; then
  echo "false"  # Return false if there are fewer files in images-otd
  exit 1
fi

echo "true"  # Return true if all files are present
exit 0
