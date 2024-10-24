#!/bin/bash

# # # Check if environment variables are set
# if [[ -z "$NASA_DATA_USER" || -z "$NASA_DATA_PASSWORD" ]]; then
#   echo "Error: Environment variables not set."
#   exit 1
# fi

# Path to the .netrc file
NETRC_FILE="/root/.netrc"

# Replace placeholders with environment variables
sed -i "s/default_user/$NASA_DATA_USER/g" "$NETRC_FILE"
sed -i "s/default_password/$NASA_DATA_PASSWORD/g" "$NETRC_FILE"

# Output the modified .netrc file
cat "$NETRC_FILE"