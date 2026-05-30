# CozyTalk — Docs Index

Quick reference for finding code. Each file maps a domain to exact paths and class names.

## Features (CA backend)
- [auth](features/auth.md) — sign in, sign up, anonymous auth, Google auth
- [matchmaking](features/matchmaking.md) — 1v1 pool, group room, custom room, interest matching
- [chat](features/chat.md) — AES-256-GCM messages, RTDB presence/typing, session lifecycle
- [profile](features/profile.md) — display name, interest, thoughts
- [avatar](features/avatar.md) — hat, mood decoration
- [home](features/home.md) — navigation hub (no domain/data layers)
- [hello](features/hello.md) — smoke-test CF echo; canonical CA reference implementation
- [friends](features/friends.md) — friend requests, friend list, permanent direct chat
- [admin](features/admin.md) — report moderation, ban/unban, dashboard stats, chat log viewer
- [block](features/block.md) — user-level blocking, block list management, room enforcement
- [card_shuffle](features/card_shuffle.md) — icebreaker question deck, 100 questions, exhaustion-before-repeat (prototype)
- [jukebox](features/jukebox.md) — synced YouTube music queue for chat rooms
- [user_status](features/user_status.md) — RTDB online/in-room/offline presence for any user
- [report](features/report.md) — in-session abuse reporting via reportSession CF
- [word_filter](features/word_filter.md) — client-side profanity filter, Remote Config gated

## Frontend
- [screens](frontend/screens.md) — all production screens with class names, routes, integration status

## Backend
- [cloud-functions](backend/cloud-functions.md) — all 24 exported CFs with inputs/outputs

## Database
- [schema](database/schema.md) — Firestore collections + RTDB paths + security rule summary
