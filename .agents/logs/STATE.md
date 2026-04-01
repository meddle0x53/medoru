# Medoru - Current State

**Version**: 0.1.4 ✅ COMPLETE  
**Status**: Bug fixing period  
**Tests**: 630 passing  
**URL**: https://medoru.net  
**Last Updated**: 2026-03-31

---

## ✅ Completed (v0.1.4)

| Feature | Status | Notes |
|---------|--------|-------|
| Grammar Lessons | ✅ | Pattern builder, sentence validation |
| Alternative Forms | ✅ | Contracted forms (来ない→来な) |
| Admin Progress Reset | ✅ | Danger zone in user edit |
| ETS Caching | ✅ | 50x validation performance |

**Log**: [ITERATION-GRAMMAR-STUDENT-TAKING.md](ITERATION-GRAMMAR-STUDENT-TAKING.md)

---

## ✅ Completed (v0.1.2)

| Feature | Status | Notes |
|---------|--------|-------|
| Daily Test Preferences | ✅ | User-configurable step types |
| Fix Daily Tests Bug | ✅ | Unlearned words no longer appear |
| Public Kanji/Words | ✅ | Anonymous access enabled |
| Language Switching | ✅ | Header selector for all users |
| Word Picture Upload | ✅ | Admin upload 1-3 images |

**Log**: [PLAN-v0.1.2.md](PLAN-v0.1.2.md)

---

## 📋 Next Up (v0.2.0)

See [PLAN-v0.2.0.md](PLAN-v0.2.0.md) for full details.

**Epics:**
1. **Real-Time Infrastructure** - PubSub, Presence, Channels
2. **Game Engine** - Plugin-based architecture
3. **Memory Cards** - First game type
4. **Classroom Chat** - Real-time messaging
5. **User Tags & Following** - Social features
6. **User Level System** - XP and leveling
7. **Badge System Fixes** - Featured badge display

---

## 🔗 Quick Links

| Resource | Link |
|----------|------|
| **Main Docs** | [AGENTS.md](../../AGENTS.md) |
| **v0.2.0 Plan** | [PLAN-v0.2.0.md](PLAN-v0.2.0.md) |
| **Iteration Logs** | [ITERATION-*.md](./) |
| **Work Log** | [WORK_LOG.md](WORK_LOG.md) (archived) |

---

## 🛠️ Development

```bash
# Start dev server
mix phx.server

# Run tests
mix test

# Pre-commit checks
mix precommit

# QA server
bin/qa server
```

---

## 📊 Stats

- **Kanji**: 2,212 (N5-N1)
- **Words**: 145,936 (N5-N3)
- **Lessons**: 300+ (100 N5 + 100 N4 + 100 N3)
- **Tests**: 630
- **Conjugations**: 66,396

---

*For full project documentation, see [AGENTS.md](../../AGENTS.md)*
