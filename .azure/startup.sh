#!/bin/bash

# Static file serving for React SPA
# This startup script is used by App Service to serve static files

# Install http-server globally if needed (lightweight static server)
npm install -g http-server

# Start the server from the current directory
# App Service will serve files from the deployed directory
echo "Starting static file server..."
http-server -p 8080 -c-1 -g
