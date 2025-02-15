#!/bin/bash

# Set your Grafana server URL
GRAFANA_URL="localhost:3000"

# Admin credentials
ADMIN_USER="admin"
ADMIN_PASSWORD="noluckSec!"

# New user details
NEW_USER="viewer"
NEW_USER_PASSWORD="noluckSec!"

# Create new user
response=$(curl -s -X POST "http://${ADMIN_USER}:${ADMIN_PASSWORD}@${GRAFANA_URL}/api/admin/users" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'${NEW_USER}'",
    "email": "'${NEW_USER}'@example.com",
    "login": "'${NEW_USER}'",
    "password": "'${NEW_USER_PASSWORD}'",
    "role": "Viewer"
  }')

# Check response
if [[ $response == *"User created"* ]]; then
  echo "User '${NEW_USER}' created successfully with Viewer role."
else
  echo "Failed to create user '${NEW_USER}'."
  echo "Response: ${response}"
fi
