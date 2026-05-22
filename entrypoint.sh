#!/bin/sh

chown -R 1000:1000 /tool-src /home/devuser/.unison

echo "Permissions fixed. Dropping privileges to devuser..."
exec su-exec devuser "$@"
