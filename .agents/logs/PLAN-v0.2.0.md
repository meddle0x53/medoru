# Medoru v0.2.0 Release Plan - Social & Gamification

## Overview
Major release introducing social features, real-time classroom games, user following system, and enhanced gamification.

**Estimated Duration**: 3-4 weeks  
**Depends On**: v0.1.2 completion  
**Theme**: Social Learning & Competition

---

## Epic 1: Real-Time Infrastructure Foundation

**Priority**: 🔴 CRITICAL (Required by Epics 2 & 3)

### Technical Requirements
Before implementing games and chat, we need to establish the real-time infrastructure:

1. **Phoenix PubSub Setup**
   - Configure PubSub for classroom channels
   - Topic naming: `classroom:{id}`, `game:{id}`, `chat:{classroom_id}`

2. **Presence Tracking**
   - Track online users per classroom
   - Track active game participants

3. **WebSocket Channel Structure**
   ```
   ClassroomChannel - handles classroom-level events
   GameChannel - handles real-time game state
   ChatChannel - handles chat messages
   ```

### Deliverables
- [ ] PubSub configured and tested
- [ ] Presence tracking working
- [ ] Channel authorization (only classroom members)
- [ ] Connection resilience (reconnect handling)

---

## Epic 2: Game Engine Architecture (Extensible)

### 2.1 Core Design Principles

The game system must be **plugin-based** and **extensible**:

```
Game Engine
├── Core (common to all games)
│   ├── Game lifecycle (create, start, pause, end)
│   ├── Team management
│   ├── Participant tracking
│   ├── Points/awards system
│   └── Event broadcasting
│
├── Game Types (plugins)
│   ├── MemoryCards (v0.2.0)
│   ├── QuizBattle (future)
│   ├── KanjiRace (future)
│   └── WordChain (future)
│
└── Game State Store
    ├── In-memory ETS (active games)
    └── Database persistence (history)
```

### 2.2 Database Schema (Game-Agnostic Core)

```elixir
# games table - game-agnostic core
create table(:games, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :classroom_id, references(:classrooms, type: :binary_id), null: false
  add :teacher_id, references(:users, type: :binary_id), null: false
  
  # Plugin system: game_type references a module
  add :game_type, :string, null: false  # "memory_cards", "quiz_battle", etc.
  
  # Game-agnostic status
  add :status, :string, default: "pending"  # pending, active, paused, completed
  
  # Universal configuration (plugin-specific data stored here)
  # Memory cards: %{word_count: 10, time_limit: 300, allow_steals: true}
  # Quiz battle: %{question_count: 20, time_per_question: 30}
  add :configuration, :map, default: %{}
  
  # Plugin-specific state (managed by game type module)
  # Memory cards: %{current_team_id: "...", revealed_cards: [], matched_pairs: []}
  # Quiz battle: %{current_question_index: 0, scores: %{}}
  add :game_state, :map, default: %{}
  
  add :started_at, :utc_datetime
  add :completed_at, :utc_datetime
  timestamps(type: :utc_datetime)
end

# game_teams table - universal team support
create table(:game_teams, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :game_id, references(:games, type: :binary_id), null: false
  add :name, :string, null: false
  add :color, :string  # hex color
  add :score, :integer, default: 0
  add :metadata, :map, default: %{}  # plugin-specific team data
  timestamps(type: :utc_datetime)
end

# game_participants table - who is playing
create table(:game_participants, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :game_id, references(:games, type: :binary_id), null: false
  add :user_id, references(:users, type: :binary_id), null: false
  add :team_id, references(:game_teams, type: :binary_id)
  add :status, :string, default: "joined"  # joined, active, left, disconnected
  add :individual_score, :integer, default: 0
  add :joined_at, :utc_datetime
  timestamps(type: :utc_datetime)
end

# game_events table - audit log (universal)
create table(:game_events, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :game_id, references(:games, type: :binary_id), null: false
  add :user_id, references(:users, type: :binary_id), null: false
  add :team_id, references(:game_teams, type: :binary_id)
  add :event_type, :string, null: false  # "move", "answer", "match", etc.
  add :event_data, :map, default: %{}  # plugin-specific
  add :points_earned, :integer, default: 0
  add :performed_at, :utc_datetime, null: false
end

# game_type_metadata table - plugin registry
create table(:game_type_metadata, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :type_key, :string, null: false  # "memory_cards"
  add :module_name, :string, null: false  # "Medoru.Games.MemoryCards.Game"
  add :display_name, :string, null: false
  add :description, :text
  add :min_players, :integer, default: 2
  add :max_players, :integer
  add :supports_teams, :boolean, default: true
  add :configuration_schema, :map  # JSON schema for config validation
  add :is_active, :boolean, default: true
  timestamps(type: :utc_datetime)
end
```

### 2.3 Game Type Plugin Architecture (Behaviours)

```elixir
# lib/medoru/games/game_type.ex

defmodule Medoru.Games.GameType do
  @moduledoc """
  Behaviour for game type plugins.
  
  Each game type (MemoryCards, QuizBattle, etc.) implements this behaviour.
  """

  @doc "Initialize game state when game starts"
  @callback init_state(game :: Game.t(), config :: map()) :: {:ok, map()} | {:error, term()}

  @doc "Validate a player action"
  @callback validate_action(game :: Game.t(), action :: atom(), params :: map(), context :: map()) :: 
    :ok | {:error, term()}

  @doc "Process a player action, return updated state and events"
  @callback handle_action(game :: Game.t(), action :: atom(), params :: map(), context :: map()) ::
    {:ok, new_state :: map(), events :: list()} | {:error, term()}

  @doc "Check if game is complete"
  @callback game_complete?(game :: Game.t()) :: boolean()

  @doc "Calculate final scores"
  @callback calculate_scores(game :: Game.t()) :: map()

  @doc "Get current game view for a specific user (hides hidden info)"
  @callback get_user_view(game :: Game.t(), user_id :: binary_id()) :: map()

  @doc "Get teacher/moderator view (full game state)"
  @callback get_teacher_view(game :: Game.t()) :: map()

  @doc "Default configuration for this game type"
  @callback default_configuration() :: map()

  @doc "Validate configuration before game starts"
  @callback validate_configuration(config :: map()) :: :ok | {:error, term()}
end
```

### 2.4 Game Registry & Dispatcher

```elixir
# lib/medoru/games/registry.ex

defmodule Medoru.Games.Registry do
  @moduledoc """
  Registry for game type plugins.
  Maps game_type string to implementing module.
  """
  
  def register(type_key, module_name) do
    # Store in ETS or database
  end
  
  def get_module(type_key) do
    # Lookup module for game type
    # "memory_cards" -> Medoru.Games.MemoryCards.Game
  end
  
  def list_available_games do
    # Return all active game types with metadata
  end
end

# lib/medoru/games/dispatcher.ex

defmodule Medoru.Games.Dispatcher do
  @moduledoc """
  Dispatches game actions to the correct game type module.
  """
  
  def dispatch_action(%Game{game_type: type} = game, action, params, context) do
    module = Registry.get_module(type)
    module.handle_action(game, action, params, context)
  end
  
  def get_view(%Game{game_type: type} = game, user_id, role) do
    module = Registry.get_module(type)
    
    case role do
      :teacher -> module.get_teacher_view(game)
      :student -> module.get_user_view(game, user_id)
    end
  end
end
```

---

## Epic 3: Memory Cards Game (First Game Type)

### 3.1 Memory Cards Implementation

```elixir
# lib/medoru/games/memory_cards/game.ex

defmodule Medoru.Games.MemoryCards.Game do
  @moduledoc """
  Memory card matching game implementation.
  
  Game Rules:
  1. Cards are arranged face-down (2 cards per word)
  2. Teams take turns flipping 2 cards
  3. If cards match (same word), team must type meaning + reading
  4. Correct answer: Team captures the cards (points)
  5. Wrong answer: Other teams can steal
  6. Continue until all cards captured
  """
  
  @behaviour Medoru.Games.GameType
  
  alias Medoru.Games.MemoryCards.Card
  
  @impl true
  def init_state(%Game{} = game, config) do
    word_ids = config.word_ids
    cards = create_card_pairs(word_ids) |> shuffle()
    
    state = %{
      cards: cards,  # [%Card{id: "...", word_id: "...", position: 0, status: :hidden}]
      current_team_id: determine_first_team(game),
      revealed_cards: [],  # Cards currently revealed
      matched_pairs: [],   # Successfully matched pairs
      turn_phase: :selecting_first_card,  # :selecting_first_card, :selecting_second_card, :answering, :stealing
      pending_answer: nil, # %{team_id: "...", word_id: "...", cards: [...]}
      steal_queue: [],     # Teams waiting to steal
      team_stats: initialize_team_stats(game.teams)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_action(game, :reveal_card, %{card_id: card_id}, %{team_id: team_id}) do
    case game.game_state.turn_phase do
      :selecting_first_card ->
        reveal_first_card(game, card_id, team_id)
        
      :selecting_second_card ->
        reveal_second_card(game, card_id, team_id)
    end
  end
  
  def handle_action(game, :submit_answer, %{meaning: m, reading: r}, %{team_id: team_id}) do
    validate_answer(game, team_id, m, r)
  end
  
  def handle_action(game, :steal_attempt, %{meaning: m, reading: r}, %{team_id: team_id}) do
    attempt_steal(game, team_id, m, r)
  end
  
  # ... other callbacks
end
```

### 3.2 Memory Cards Schema (Plugin-Specific)

```elixir
# lib/medoru/games/memory_cards/card.ex

defmodule Medoru.Games.MemoryCards.Card do
  @moduledoc """
  Card schema for memory card game.
  Stored within game_state, not as separate DB table.
  """
  
  defstruct [
    :id,
    :word_id,
    :pair_id,      # "a" or "b" to identify matching pair
    :position,     # 0-based position on board
    :status,       # :hidden, :revealed, :matched
    :matched_by_team_id,
    :revealed_at
  ]
end

# lib/medoru/games/memory_cards/configuration.ex

defmodule Medoru.Games.MemoryCards.Configuration do
  @moduledoc """
  Configuration schema for memory card games.
  """
  
  defstruct [
    :word_ids,           # List of word IDs to use
    :time_limit,         # Optional time limit in seconds
    :allow_steals,       # Boolean - can other teams steal?
    :steal_time_limit,   # Seconds to answer for steal
    :points_per_card,    # Default: 2
    :bonus_for_most_cards  # Default: 10
  ]
  
  def validate(config) do
    # Validate word_ids present and count is even
    # Validate time limits are positive integers
  end
end
```

### 3.3 Game Flow State Machine

```
States:
┌─────────────────────────────────────────────────────────────┐
│  :waiting_for_start                                         │
│  Teacher starts game → transition to :selecting_first_card │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  :selecting_first_card                                      │
│  Current team clicks card → :selecting_second_card         │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  :selecting_second_card                                     │
│  Current team clicks card → check match                    │
│  Match? → :answering                                        │
│  No match? → flip back, next team → :selecting_first_card  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  :answering                                                 │
│  Team submits answer → validate                            │
│  Correct? → capture cards, check game end, continue        │
│  Wrong? → :stealing (if enabled) or next team              │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  :stealing                                                  │
│  Other teams can submit answers in order                   │
│  Correct steal? → stealing team gets cards                 │
│  No correct steals? → cards flip back, next team           │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 Memory Cards UI

**Teacher View (Game Management)**
```
┌─────────────────────────────────────────────────────┐
│ Memory Cards - Configure Game                       │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Word Selection:                                     │
│ [Search words...]                                   │
│ Selected: 10 words (20 cards)                      │
│ [Word1] [Word2] [Word3] ... [x]                    │
│                                                     │
│ Teams:                                              │
│ ┌─────────────┐  ┌─────────────┐                   │
│ │ Team Red    │  │ Team Blue   │                   │
│ │ • Student A │  │ • Student C │                   │
│ │ • Student B │  │ • Student D │                   │
│ │ [+ Add]     │  │ [+ Add]     │                   │
│ └─────────────┘  └─────────────┘                   │
│                                                     │
│ Configuration:                                      │
│ [✓] Allow steals                                   │
│ Steal time limit: [15] seconds                     │
│                                                     │
│ [Start Game]                                        │
└─────────────────────────────────────────────────────┘
```

**Student View (Active Game)**
```
┌─────────────────────────────────────────────────────┐
│ Memory Cards - Team Red's Turn                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Score: Red: 12 | Blue: 8                           │
│                                                     │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐               │
│ │ ?? │ │ ?? │ │ 日 │ │ ?? │ │ ?? │               │
│ └────┘ └────┘ └────┘ └────┘ └────┘               │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐               │
│ │ ?? │ │ ?? │ │ ?? │ │ ?? │ │ ?? │               │
│ └────┘ └────┘ └────┘ └────┘ └────┘               │
│ ... (card grid)                                    │
│                                                     │
│ Chat:                                              │
│ [Team Red is thinking...]                          │
│ [________________________________] [Send]          │
└─────────────────────────────────────────────────────┘
```

**Answer Modal (When Match Found)**
```
┌─────────────────────────────────────────────────────┐
│ Match Found!                                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│ You revealed: 日本                                  │
│                                                     │
│ Type the meaning:                                   │
│ [________________]                                  │
│                                                     │
│ Type the reading (hiragana):                        │
│ [________________]                                  │
│                                                     │
│ [Submit Answer]            Time: 0:24              │
└─────────────────────────────────────────────────────┘
```

---

## Epic 4: Real-Time Classroom Chat

### 4.1 Chat Schema

```elixir
# chat_messages table
create table(:chat_messages, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :classroom_id, references(:classrooms, type: :binary_id), null: false
  add :user_id, references(:users, type: :binary_id), null: false
  add :game_id, references(:games, type: :binary_id)  # null = general chat
  add :message_type, :string, default: "text"  # text, system, game_event
  add :content, :text, null: false
  add :metadata, :map, default: %{}  # reactions, mentions, etc.
  add :edited_at, :utc_datetime
  timestamps(type: :utc_datetime)
end

# chat_participants (presence tracking)
create table(:chat_participants, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :classroom_id, references(:classrooms, type: :binary_id), null: false
  add :user_id, references(:users, type: :binary_id), null: false
  add :last_read_at, :utc_datetime
  add :unread_count, :integer, default: 0
  add :is_online, :boolean, default: false
  timestamps(type: :utc_datetime)
end
```

### 4.2 Chat Features

- [ ] Real-time message delivery via PubSub
- [ ] Message history (load last 50, infinite scroll)
- [ ] System messages ("Game started", "User joined", etc.)
- [ ] Typing indicators
- [ ] Online presence list
- [ ] Unread message count
- [ ] Game-specific chat rooms
- [ ] Teacher moderation (delete messages, mute)
- [ ] @mentions support

### 4.3 Chat UI Integration

- [ ] Chat panel in classroom view
- [ ] Collapsible chat in game view
- [ ] Unread badge on classroom navigation
- [ ] Mobile-optimized chat drawer

---

## Epic 5: User Tags & Following System

### 5.1 Tags Schema

```elixir
# tags table (global curated list + user-created)
create table(:tags, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :name, :string, null: false
  add :slug, :string, null: false
  add :category, :string  # "level", "interest", "goal"
  add :description, :text
  add :is_official, :boolean, default: false
  add :usage_count, :integer, default: 0
  add :created_by_id, references(:users, type: :binary_id)
  timestamps(type: :utc_datetime)
end

# user_tags (many-to-many)
create table(:user_tags, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:users, type: :binary_id), null: false
  add :tag_id, references(:tags, type: :binary_id), null: false
  add :is_public, :boolean, default: true
  timestamps(type: :utc_datetime)
end

# follows table
create table(:follows, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :follower_id, references(:users, type: :binary_id), null: false
  add :following_id, references(:users, type: :binary_id), null: false
  add :followed_at, :utc_datetime, null: false
  timestamps(type: :utc_datetime)
end

# user_search_materialized_view (for efficient search)
# PostgreSQL materialized view combining:
# - display_name (trigram index)
# - tags
# - featured_badge
```

### 5.2 Predefined Tags

**Level Tags:**
- `jlpt-n5`, `jlpt-n4`, `jlpt-n3`, `jlpt-n2`, `jlpt-n1`
- `beginner`, `intermediate`, `advanced`

**Interest Tags:**
- `anime`, `manga`, `j-pop`, `j-drama`, `movies`
- `travel`, `food`, `culture`, `history`
- `business`, `academic`, `conversation`

**Goal Tags:**
- `move-to-japan`, `pass-jlpt`, `work-in-japan`, `study-abroad`
- `travel-japan`, `read-manga-raw`, `watch-anime-without-subs`

### 5.3 User Search

Search by:
- Display name (fuzzy match)
- Tags (AND/OR filter)
- Level range
- Recent activity

Results show:
- Avatar + display name
- Featured badge
- Tags
- Level
- Follow button

### 5.4 Following Features

- [ ] Follow/unfollow users
- [ ] Follower/following counts
- [ ] "Following" dashboard page
- [ ] Mutual follow indicator
- [ ] Block user (future)

---

## Epic 6: User Level System

### 6.1 Level Schema

```elixir
# user_levels table
create table(:user_levels, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:users, type: :binary_id), null: false, unique: true
  add :current_level, :integer, default: 1
  add :total_xp, :integer, default: 0
  add :xp_to_next_level, :integer, default: 100
  add :lifetime_stats, :map, default: %{
    daily_tests_completed: 0,
    words_learned: 0,
    kanji_learned: 0,
    lessons_completed: 0,
    classroom_tests_completed: 0,
    games_participated: 0,
    games_won: 0,
    chat_messages_sent: 0
  }
  timestamps(type: :utc_datetime)
end

# xp_transactions table (audit log)
create table(:xp_transactions, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:users, type: :binary_id), null: false
  add :amount, :integer, null: false
  add :source_type, :string, null: false
  add :source_id, :string
  add :description, :string
  add :awarded_at, :utc_datetime, null: false
end
```

### 6.2 XP Sources

| Activity | XP Awarded |
|----------|-----------|
| Complete daily test | 50 XP |
| Learn a new word | 10 XP |
| Learn a new kanji | 20 XP |
| Complete lesson | 100 XP |
| Complete classroom test | 75 XP |
| Win a game | 200 XP |
| Participate in game | 50 XP |
| Earn a badge | 150-500 XP |
| 7-day streak | 100 XP bonus |
| 30-day streak | 500 XP bonus |

### 6.3 Level Thresholds

Formula: `xp_to_next = min(5000, 100 + (level - 1) * 50)`

| Level | XP Required | Cumulative XP |
|-------|-------------|---------------|
| 1 | 0 | 0 |
| 2 | 100 | 100 |
| 5 | 250 | 700 |
| 10 | 500 | 2,250 |
| 20 | 1,000 | 9,750 |
| 50 | 5,000 | 100,000+ |

### 6.4 Level UI

- [ ] Level badge on profile
- [ ] XP progress bar
- [ ] Level-up animation
- [ ] XP breakdown (sources)
- [ ] Level in search results

---

## Epic 7: Badge System Fixes

### 7.1 Fixes Required

1. **Featured Badge Display**
   - Show in user search results
   - Show in followed users list
   - Show in classroom member list
   - Show in game participant list
   - Show in chat user info

2. **Badge Awarding Logic**
   - Review all badge triggers
   - Ensure async badge checking
   - Add missing badge notifications

### 7.2 Badge Display Locations

Update views:
- [ ] User profile
- [ ] User search results
- [ ] Followed users list
- [ ] Classroom members
- [ ] Game participants
- [ ] Chat hover/click popup

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- PubSub configuration
- Presence tracking
- Channel authorization
- Game engine core (behaviours, registry, dispatcher)

### Phase 2: Chat (Week 1-2)
- Chat schema
- Chat UI
- Real-time message delivery
- Classroom integration

### Phase 3: Game Engine (Week 2)
- Game type plugin system
- Memory cards implementation
- Game state management
- Teacher game creation UI

### Phase 4: Memory Cards Game (Week 2-3)
- Card matching logic
- Answer validation
- Real-time updates
- Student game UI
- Points integration

### Phase 5: Social Features (Week 3)
- Tags system
- Following system
- User search
- Followed users dashboard

### Phase 6: Gamification (Week 3-4)
- User levels
- XP tracking
- Level UI
- Badge fixes

---

## New Contexts & Modules

```
lib/medoru/
├── games/
│   ├── game.ex                    # Core game schema
│   ├── game_team.ex
│   ├── game_participant.ex
│   ├── game_event.ex
│   ├── game_type.ex               # Behaviour
│   ├── registry.ex                # Plugin registry
│   ├── dispatcher.ex              # Action dispatcher
│   ├── context.ex                 # Games context
│   └── memory_cards/
│       ├── game.ex                # Memory cards implementation
│       ├── card.ex
│       └── configuration.ex
├── chat/
│   ├── message.ex
│   ├── participant.ex
│   └── context.ex
├── social/
│   ├── tag.ex
│   ├── user_tag.ex
│   ├── follow.ex
│   └── context.ex
└── levels/
    ├── user_level.ex
    ├── xp_transaction.ex
    └── context.ex
```

---

## Database Migrations

| Migration | Purpose |
|-----------|---------|
| `create_games.exs` | Games table |
| `create_game_teams.exs` | Teams |
| `create_game_participants.exs` | Participants |
| `create_game_events.exs` | Event audit log |
| `create_game_type_metadata.exs` | Plugin registry |
| `create_chat_messages.exs` | Chat messages |
| `create_chat_participants.exs` | Chat presence |
| `create_tags.exs` | Tags |
| `create_user_tags.exs` | User tags |
| `create_follows.exs` | Follows |
| `create_user_search_index.exs` | Search index |
| `create_user_levels.exs` | User levels |
| `create_xp_transactions.exs` | XP log |

---

## Testing Strategy

- Unit tests for game type behaviours
- Integration tests for game flow
- Channel tests for real-time features
- LiveView tests for UI
- Load tests for concurrent games

---

**Last Updated**: 2026-03-22  
**Status**: 📝 Planning Phase  
**Next Step**: Complete v0.1.2, then begin v0.2.0 Phase 1
