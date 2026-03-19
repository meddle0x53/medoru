# Medoru v0.1.0 Iteration Plan

## Overview
**STATUS: ✅ COMPLETE - DEPLOYED TO PRODUCTION**

This document outlines the iterations completed for Medoru version 0.1.0. All iterations have been successfully implemented, reviewed, and deployed.

**Live URL**: https://medoru.net

---

## ✅ Completed Iterations Summary

| Iteration | Title | Status | Date |
|-----------|-------|--------|------|
| 1 | OAuth & Accounts | ✅ APPROVED | 2026-03-05 |
| 2 | Kanji & Readings | ✅ APPROVED | 2026-03-05 |
| 3 | Words with Reading Links | ✅ APPROVED | 2026-03-06 |
| 4 | Lessons | ✅ APPROVED | 2026-03-06 |
| 5 | Learning Core | ✅ APPROVED | 2026-03-06 |
| 6 | Daily Reviews & Streaks | ✅ APPROVED | 2026-03-06 |
| 7 | Polish & Integration | ✅ APPROVED | 2026-03-07 |
| 8 | User Types & Admin Foundation | ✅ APPROVED | 2026-03-07 |
| 9 | Enhanced Profiles | ✅ APPROVED | 2026-03-07 |
| 10 | Badge System | ✅ APPROVED | 2026-03-07 |
| 11 | Logging Infrastructure | ✅ APPROVED | 2026-03-08 |
| 12 | Kanji Stroke Animation | ✅ APPROVED | 2026-03-08 |
| 14 | Multi-Step Test System | ✅ APPROVED | 2026-03-08 |
| 16 | Auto-Generated Daily Tests | ✅ APPROVED | 2026-03-09 |
| 17 | Vocabulary Lesson System | ✅ APPROVED | 2026-03-09 |
| 18 | Classroom Core | ✅ APPROVED | 2026-03-11 |
| 19 | Classroom Membership | ✅ APPROVED | 2026-03-11 |
| 20 | Classroom Tests, Lessons & Rankings | ✅ APPROVED | 2026-03-11 |
| 21 | Admin Dashboard | ✅ APPROVED | 2026-03-16 |
| 22 | Kanji Writing Test Step | ✅ APPROVED | 2026-03-08 |
| 23 | Reading Comprehension Text Input | ✅ APPROVED | 2026-03-10 |
| 24A | UI Internationalization (i18n) | ✅ APPROVED | 2026-03-15 |
| 24B | Content Translation | ✅ APPROVED | 2026-03-18 |
| 25 | Step Builder Framework | ✅ APPROVED | 2026-03-12 |
| 26 | Multi-Choice Step Builder | ✅ APPROVED | 2026-03-13 |
| 27 | Typing Step Builder | ✅ APPROVED | 2026-03-13 |
| 28 | Kanji Writing Step Builder | ✅ APPROVED | 2026-03-13 |
| 29 | Classroom Publishing | ✅ APPROVED | 2026-03-12 |
| 30 | Complete Test Taking | ✅ APPROVED | 2026-03-15 |
| 31 | Teacher Custom Lessons | ✅ APPROVED | 2026-03-15 |
| 32 | UI Polish & Mobile Responsiveness | ✅ APPROVED | 2026-03-18 |
| 33 | Deployment & Production Setup | ✅ APPROVED | 2026-03-18 |

---

## 🗂️ Backlog (Post v0.1.0 - v0.2.0 Planning)

### Iteration 13: Admin Badge Management
**Status**: ⏳ BACKLOGGED  
**Priority**: 🟡 MEDIUM  
**Planned For**: v0.2.0 or later

**Reason**: Admin can already manage content (kanji, words, lessons) via the dashboard. Badge management is a nice-to-have but not critical for MVP launch.

---

## v0.2.0 Feature Ideas (Pending Planning)

### Social Features
- Real-time 1v1 duels
- Friends system
- Global and friend leaderboards
- Duel history and statistics

### Content Expansion
- Grammar lessons and tests
- Listening comprehension (audio)
- Speaking tests (voice recording)
- N4-N1 vocabulary expansion

### Platform
- Mobile app (React Native/Flutter)
- Offline mode
- AI-powered learning recommendations

---

## Deployment Summary

**Server**: VPS at 178.104.91.176  
**Domain**: medoru.net  
**SSL**: Let's Encrypt  
**Database**: PostgreSQL 16  
**App Server**: Phoenix/Elixir via systemd  
**Reverse Proxy**: Nginx  

**Deployment Method**: Ansible playbooks
- `setup.yml` - Initial server setup
- `update.yml` - Application updates

---

**v0.1.0 Status: ✅ COMPLETE AND DEPLOYED**

See individual iteration logs for detailed implementation notes.
