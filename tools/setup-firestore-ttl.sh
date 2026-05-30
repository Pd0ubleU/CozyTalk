#!/usr/bin/env bash
# Deploys the Firestore TTL policy for chat_rooms/{id}/messages.
#
# Firestore TTL policies cannot be expressed in firebase.json or firestore.rules,
# so they must be applied once via the gcloud CLI.  Running this script a second
# time is safe — gcloud is idempotent for TTL field definitions.
#
# Required: gcloud CLI authenticated and the cozytalk-5d984 project selected.
#   gcloud auth login
#   gcloud config set project cozytalk-5d984
#
# What this sets up:
#   Collection group : messages  (matches chat_rooms/{any}/messages/{any})
#   TTL field        : expiresAt
#
# sendMessage.ts sets expiresAt = now + 3 days on every message.
# Without this policy, messages from crashed/abandoned sessions never delete.

set -euo pipefail

PROJECT="cozytalk-5d984"
COLLECTION_GROUP="messages"
TTL_FIELD="expiresAt"

echo "Applying Firestore TTL policy..."
echo "  Project         : $PROJECT"
echo "  Collection group: $COLLECTION_GROUP"
echo "  TTL field       : $TTL_FIELD"
echo ""

gcloud firestore fields ttls update "$TTL_FIELD" \
  --collection-group="$COLLECTION_GROUP" \
  --project="$PROJECT" \
  --enable-ttl

echo ""
echo "TTL policy applied. Messages will be deleted 3 days after expiresAt."
echo "Propagation can take up to 24 hours to take effect on existing documents."
