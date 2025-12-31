# Refactoring Plan: Many-to-Many Users ↔ Sites

## Current State → Target State

```
CURRENT (One-to-Many)              TARGET (Many-to-Many)
┌─────────┐     ┌─────────┐       ┌─────────┐     ┌────────────┐     ┌─────────┐
│  sites  │     │  users  │       │  sites  │     │ user_sites │     │  users  │
├─────────┤     ├─────────┤       ├─────────┤     ├────────────┤     ├─────────┤
│ id      │◄────│ site_id │  ──►  │ id      │◄────│ site_id    │     │ id      │
│ name    │     │ id      │       │ name    │     │ user_id    │────►│ name    │
│ ...     │     │ ...     │       │ ...     │     │ timestamps │     │ ...     │
└─────────┘     └─────────┘       └─────────┘     └────────────┘     └─────────┘
```

---

## Phase 1: Database Migration

**New file:** `priv/repo/migrations/TIMESTAMP_convert_to_many_to_many_user_sites.exs`

```elixir
def change do
  # 1. Create join table
  create table(:user_sites) do
    add :user_id, references(:users, on_delete: :delete_all), null: false
    add :site_id, references(:sites, on_delete: :delete_all), null: false
    timestamps(type: :utc_datetime)
  end

  create unique_index(:user_sites, [:user_id, :site_id])
  create index(:user_sites, [:site_id])

  # 2. Migrate existing data
  execute("""
    INSERT INTO user_sites (user_id, site_id, inserted_at, updated_at)
    SELECT id, site_id, NOW(), NOW() FROM users WHERE site_id IS NOT NULL
  """, "")

  # 3. Drop FK column
  alter table(:users) do
    remove :site_id
  end
end
```

---

## Phase 2: Schema Changes

| File | Change |
|------|--------|
| **NEW:** `lib/upload/sites/user_site.ex` | Join schema with `belongs_to :user` and `belongs_to :site` |
| `lib/upload/accounts/user.ex` | Remove `belongs_to :site` → Add `many_to_many :sites, through: UserSite` |
| `lib/upload/sites/site.ex` | Change `has_many :users` → `many_to_many :users, through: UserSite` |

---

## Phase 3: Context Updates

### `lib/upload/accounts.ex`

| Function | Change |
|----------|--------|
| `list_users/0` | Preload `:sites` (plural) instead of `:site` |
| `assign_user_to_site/2` | **Remove** (moved to Sites context) |
| `remove_user_from_site/1` | **Remove** (moved to Sites context) |

### `lib/upload/sites.ex`

| Function | Description |
|----------|-------------|
| `add_user_to_site/2` | Add a single user to a site |
| `remove_user_from_site/2` | Remove a user from a specific site |
| `set_user_sites/2` | Bulk replace all sites for a user |
| `get_user_sites/1` | Get all sites for a user |

---

## Phase 4: Admin UI Updates

### `lib/upload_web/live/admin/users_live.ex`

| Current | New |
|---------|-----|
| Single `<select>` dropdown per user | Checkbox list or multi-select for each user |
| `assign_user_site` event (single site) | `toggle_user_site` event (add/remove individual) |
| Shows `user.site_id` | Shows `user.sites` as badges |

### UI Concept

```
┌──────────────────────────────────────────────────────────────┐
│ User                │ Assigned Sites                         │
├─────────────────────┼────────────────────────────────────────┤
│ 👤 John Doe         │ ☑ Omaha Storm  ☑ Lincoln Stars  ☐ KC   │
│    john@email.com   │                                        │
├─────────────────────┼────────────────────────────────────────┤
│ 👤 Jane Smith       │ ☐ Omaha Storm  ☑ Lincoln Stars  ☐ KC   │
│    jane@email.com   │                                        │
└─────────────────────┴────────────────────────────────────────┘
```

---

## Phase 5: Dashboard UI Updates

### `lib/upload_web/live/dashboard_live.ex`

| Current | New |
|---------|-----|
| `@site` (singular) | `@sites` (list) |
| "Your Site" heading | "Your Sites" heading |
| Single site card | Grid/list of site cards |
| Preload `:site` | Preload `:sites` |

---

## Files Summary

| Action | File |
|--------|------|
| **CREATE** | `lib/upload/sites/user_site.ex` |
| **CREATE** | `priv/repo/migrations/*_convert_to_many_to_many_user_sites.exs` |
| **MODIFY** | `lib/upload/accounts/user.ex` |
| **MODIFY** | `lib/upload/sites/site.ex` |
| **MODIFY** | `lib/upload/accounts.ex` |
| **MODIFY** | `lib/upload/sites.ex` |
| **MODIFY** | `lib/upload_web/live/admin/users_live.ex` |
| **MODIFY** | `lib/upload_web/live/dashboard_live.ex` |

---

## Migration Cleanup Note

The existing migrations have redundancy (join table created then dropped). Options:
1. **Add new migration on top** (recommended - safe, works regardless of history)
2. **Squash migrations** (only if not yet deployed anywhere)
