# 🌱 Habits Quest 4 Life

**Habits Quest 4 Life** is an application built on the **Internet Computer (IC)** that helps users build good habits through a system of **roles**, **quests**, **stamina**, **coins**, and **inventory**. It combines elements of **RPG gamification** with daily **self-improvement**.

---

## 🚀 Key Features

### 👤 User System

- Unique user registration with a **username**.
- Stores user data (coins, stamina, inventory, quests, roles).
- **Automatic stamina regeneration** at set intervals.

### 🏅 Role System

- Default roles:
  - Codes
  - Sports
  - Arts
  - Traveler
  - Literature
- Each role has its own level & EXP.
- A user can only have **one active role** at a time and cannot switch roles while a quest is active.

### 🗡 Quest System

- Users can accept quests if they have **sufficient stamina**.
- Quests include:
  - Stamina cost
  - Coin & EXP rewards
  - Deadline (4 hours by default)
- Quest statuses: `OnProgress`, `Completed`, `Failed`.
- Quests automatically fail if the deadline is missed.
- Successful quests award **coins** & **EXP** to the active role.

### 🛍 Shop & Inventory

- An admin can add **Skins** to the shop.
- Users can purchase skins with coins.
- Purchased skins are added to the user's **inventory**.
- Users can set an **active skin**.

### 📊 Leaderboard

- **Role-based leaderboards** sorted by **EXP**.
- A global leaderboard for coins.

---

## ⚙️ Technology

- Language: [Motoko](https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity)
- SDK: [DFINITY SDK](https://internetcomputer.org/docs/current/developer-docs/getting-started/install/)
- State Management: `HashMap`, `Buffer`, and stable variables.

---

## 📂 File Structure

```
├── src/
│ ├── main.mo # Main actor implementation (system logic)
│ ├── types.mo # Global type definitions
│ └── ...
├── README.md
```

---

## 🔑 How to Run

### 1. Clone the repository

```bash
git clone [https://github.com/](https://github.com/)/habits-quest-4life.git
cd habits-quest-4life
```

### 2. Install the DFX SDK

```bash
sh -ci "$(curl -fsSL [https://internetcomputer.org/install.sh](https://internetcomputer.org/install.sh))"
```

### 3. Run Locally

```bash
dfx start --background
dfx deploy
```

### 4. Interact with the Canister

**Register a user**

```bash
dfx canister call habits_quest_4life registerUser '("Alice")'
```

**View profile**

```bash
dfx canister call habits_quest_4life getProfileUser
```

**Accept a quest**

```bash
dfx canister call habits_quest_4life acceptQuest '("Study for 30 mins", "Practice DApp coding", 5, 10, 20)'
```

**Complete a quest**

```bash
dfx canister call habits_quest_4life completeQuest '(0)'
```

**Buy a skin**

```bash
dfx canister call habits_quest_4life buySkin '(0)'
```

---

## 🎮 User Flow (Game Guide)

1.  **Register** → Create a unique username.
2.  **Choose a role** → Activate one of your favorite roles.
3.  **Accept a quest** → Requires stamina; quests have a 4-hour deadline.
4.  **Complete a quest** → Earn coins + EXP, which levels up your role.
5.  **Shop for skins** → Use your coins to buy items from the shop.
6.  **Manage inventory** → Set your active skin.
7.  **Follow the leaderboard** → Check your ranking by role or coins.

---

## 🔒 Admin Commands

- `addSkin` → Adds a new item to the shop.
- `grantCoinByUsername` → Gives coins to a specific user.

---

## 🌍 Vision

This application is designed to turn everyday habits into an exciting adventure. With a system of roles, quests, and leaderboards, users can stay motivated to maintain consistency in their lives.

---

## 📜 License

MIT License © 2025
