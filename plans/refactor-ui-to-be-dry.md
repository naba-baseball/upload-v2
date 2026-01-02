# UI Refactoring Plan: DRY Improvements & Consistency

## 🧠 ULTRATHINK ANALYSIS: DRY Opportunities & Architecture

### **Critical Pattern Recognition**

From the codebase analysis, I've identified **12 major pattern categories** with the following breakdown:

**TIER 1 - IMMEDIATE HIGH-IMPACT CONSOLIDATION (Used 5+ times)**
1. **Card/Container Pattern** - 8+ instances across dashboard, admin, uploads
2. **Dark Mode Color Classes** - 100+ instances (every file)
3. **Icon + Link Patterns** - Multiple instances of back links and icon links
4. **Button Pattern Inconsistency** - 5 admin button components + limited CoreComponents.button (DaisyUI vs Tailwind, missing variants/sizes)

**TIER 2 - MODERATE IMPACT (Used 3-4 times)**
5. **Page Headers** - 4 different header patterns
6. **Empty States** - 3 implementations
7. **User Avatar/Profile Display** - 3 variations
8. **Form Actions (Submit/Cancel)** - Multiple admin forms

**TIER 3 - FUTURE-PROOFING (Used 1-2 times, but will grow)**
9. **Progress Bars** - Currently only uploads, but reusable
10. **Banner/Callout** - Admin access banner pattern
11. **Toggle Badge** - User-site assignment UI
12. **Grid Layouts** - Responsive patterns

---

## 📋 PHASED IMPLEMENTATION PLAN

### **Phase 1: Foundation Components (Week 1 Priority)**

#### 1.1 Enhance CoreComponents.button → Universal Button Component
**Current State:**
- CoreComponents.button has only 2 variants (primary, default) using DaisyUI classes
- AdminComponents has 5 separate button components using plain Tailwind
- Inconsistent styling approaches (DaisyUI vs Tailwind)
- No size variants

**Target:** Single enhanced `button` component in CoreComponents with:
- Multiple variants: `primary`, `success`, `secondary`, `danger`, `ghost`
- Size support: `default`, `sm`
- Navigation support (already exists)
- Plain Tailwind classes for consistency

```elixir
# Replace this fragmentation:
<.admin_button_success>Save</.admin_button_success>
<.admin_button_danger>Delete</.admin_button_danger>
<.admin_button_edit>Edit</.admin_button_edit>

# With this unified approach:
<.button variant="success">Save</.button>
<.button variant="danger" size="sm">Delete</.button>
<.button variant="primary" size="sm">Edit</.button>
```

**Migration Strategy:**
1. Enhance CoreComponents.button to support all needed variants
2. Add size attribute (default, sm) for different button sizes
3. Switch from DaisyUI classes to plain Tailwind for consistency
4. Update all admin views to use CoreComponents.button
5. Remove all admin_button* components from AdminComponents
6. Update any CoreComponents.button usage to new variant names

**Impact:**
- Reduces AdminComponents by ~100 lines
- Establishes variant pattern for all buttons
- Single source of truth for button styling
- Consistent button API across entire app

#### 1.2 Create Universal Card Component
**Variants:** `default`, `indigo`, `white`, `bordered`
**Features:** Hover effects, padding options, header/footer slots

```elixir
<.card variant="indigo" hover class="p-6">
  <:header>
    <h3 class="text-lg font-semibold">{site.name}</h3>
  </:header>
  <:body>
    {content}
  </:body>
  <:footer>
    {actions}
  </:footer>
</.card>
```

**Impact:** Eliminates 8+ repeated card patterns, ensures consistent spacing/colors

#### 1.3 Extract Link Components
Create two specialized link components:

```elixir

# Back navigation
<.back_link navigate={~p"/dashboard"}>
  Back to Dashboard
</.back_link>

# Generic icon link
<.icon_link navigate={path} icon="hero-arrow-right">
  View Details
</.icon_link>
```

**Impact:** DRYs up several link instances, ensures consistent visual design

---

### **Phase 2: User-Facing Components (Week 2)**

#### 2.1 User Avatar System
Create size-aware avatar with optional profile info:

```elixir
# Simple avatar
<.user_avatar user={@user} size="md" />

# Avatar with profile info
<.user_profile user={@user} show_email />
```

**Sizes:** `xs` (8x8), `sm` (12x12), `md` (16x16), `lg` (24x24)
**Impact:** Consistent user representation, accessibility improvements

#### 2.2 Enhanced Empty State Component
Move from AdminComponents to CoreComponents with icon support:

```elixir
<.empty_state icon="hero-inbox">
  No sites assigned yet
</.empty_state>
```

**Impact:** Better UX consistency, reduces 3+ duplicate patterns

#### 2.3 Progress Bar Component
Extract from UploadComponents:

```elixir
<.progress_bar value={entry.progress} max={100} color="indigo" />
```

**Impact:** Reusable for any progress tracking (uploads, processing, etc.)

---

### **Phase 3: Advanced UI Patterns (Week 3)**

#### 3.1 Banner/Callout Component
```elixir
<.banner variant="info" dismissible>
  <:title>Admin Access</:title>
  <:body>Manage sites, users, and uploads</:body>
  <:action>
    <.link navigate={~p"/admin"}>Go to Admin Panel</.link>
  </:action>
</.banner>
```

**Variants:** `info`, `success`, `warning`, `error`
**Impact:** Flexible promotional/notification system

#### 3.2 Toggle Badge Component
```elixir
<.toggle_badge
  active={user_has_site?(user, site.id)}
  phx-click="toggle_user_site"
  phx-value-user-id={user.id}
  phx-value-site-id={site.id}
>
  {site.name}
</.toggle_badge>
```

**Impact:** Reusable for any multi-select badge UI

#### 3.3 Form Actions Component
```elixir
<.form_actions>
  <:submit variant="success">Save Changes</:submit>
  <:cancel phx-click="cancel_edit">Cancel</:cancel>
</.form_actions>
```

**Impact:** Consistent form button layouts

---

### **Phase 4: System-Level Improvements**

#### 4.1 Dark Mode Utility Classes
Add to `app.css`:

```css
@layer components {
  .text-primary {
    @apply text-gray-900 dark:text-gray-100;
  }

  .text-secondary {
    @apply text-gray-600 dark:text-gray-400;
  }

  .bg-surface {
    @apply bg-white dark:bg-gray-800;
  }

  .border-default {
    @apply border-gray-200 dark:border-gray-700;
  }
}
```

**Impact:** Reduces 100+ instances of repeated dark mode classes

#### 4.2 Enhanced CoreComponents.header
Extend existing header component with icon support and more variants:

```elixir
<.header icon="hero-globe-alt">
  <:title>Upload to {@site.name}</:title>
  <:subtitle>{site_url}</:subtitle>
  <:actions>
    <.back_link navigate={~p"/dashboard"} />
  </:actions>
</.header>
```

**Impact:** Consolidates 4 header patterns

---

## 🎯 RECOMMENDED COMPONENT HIERARCHY

```
CoreComponents (General-purpose, app-wide)
├── Layout & Structure
│   ├── card (NEW)
│   ├── banner (NEW)
│   ├── header (ENHANCE existing)
│   └── empty_state (MOVE from AdminComponents)
│
├── Navigation & Links
│   ├── button (ENHANCE - add variants: success, secondary, danger, ghost + sizes)
│   ├── back_link (NEW)
│   └── icon_link (NEW)
│
├── User Display
│   ├── user_avatar (NEW)
│   └── user_profile (NEW)
│
├── Forms & Input
│   ├── input (existing)
│   ├── form (existing via Phoenix.Component)
│   └── form_actions (NEW)
│
└── Feedback & Progress
    ├── flash (existing)
    ├── progress_bar (NEW - extracted from UploadComponents)
    └── table (existing)

AdminComponents (Admin-specific)
├── admin_layout (existing)
├── admin_card (REMOVE - use CoreComponents.card)
├── admin_button* (REMOVE ALL - use CoreComponents.button with variants)
└── toggle_badge (NEW or move to CoreComponents)

UploadComponents (Upload-specific)
├── upload_form (existing)
├── upload_entry (existing)
└── (progress_bar moved to CoreComponents)
```

---

## 📝 ADDITIONS TO AGENTS.MD

Here's what should be added to your `AGENTS.md` file:

```markdown
## Component Reuse Guidelines

### Core Component Library

This project has a comprehensive component library. **ALWAYS** use existing components before creating new markup:

#### Available CoreComponents (lib/upload_web/components/core_components.ex)

**Layout & Structure:**
- `<.card variant="default|indigo|white" hover>` - Container cards with consistent styling
- `<.banner variant="info|success|warning|error">` - Promotional/notification banners
- `<.header>` with `:title`, `:subtitle`, `:actions` slots - Page headers with icon support
- `<.empty_state icon="hero-*">` - Empty state messages

**Navigation & Links:**
- `<.button variant="primary|success|secondary|danger|ghost" size="default|sm">` - Universal button component with variants and sizes (supports navigate/patch/href)
- `<.back_link navigate={path}>` - Back navigation with left arrow icon
- `<.icon_link navigate={path} icon="hero-*">` - Links with custom icons

**User Display:**
- `<.user_avatar user={@user} size="xs|sm|md|lg">` - User avatar images
- `<.user_profile user={@user} show_email>` - Avatar + name/email display

**Forms:**
- `<.input field={@form[:field]}>` - All form inputs (existing)
- `<.form for={@form}>` - Form wrapper (existing via Phoenix.Component)
- `<.form_actions>` with `:submit` and `:cancel` slots - Consistent submit/cancel layouts

**Feedback & Progress:**
- `<.flash>` - Flash messages (existing)
- `<.progress_bar value={progress} max={100} color="indigo">` - Progress indicators
- `<.table rows={@rows}>` - Data tables (existing)

**Icons:**
- `<.icon name="hero-*" class="w-X h-X">` - Heroicons (existing)

#### Available AdminComponents (lib/upload_web/components/admin_components.ex)

- `<.admin_layout>` - Admin page wrapper (existing)
- `<.toggle_badge active={boolean}>` - Multi-select badge toggles (if implemented)

#### Dark Mode Color Utilities (app.css)

**ALWAYS use semantic color utilities instead of repeating dark mode classes:**
- `.text-primary` instead of `text-gray-900 dark:text-gray-100`
- `.text-secondary` instead of `text-gray-600 dark:text-gray-400`
- `.bg-surface` instead of `bg-white dark:bg-gray-800`
- `.border-default` instead of `border-gray-200 dark:border-gray-700`

### Component Usage Rules

1. **NEVER create raw card containers** - Use `<.card>` component
2. **NEVER duplicate button color variants** - Use `<.button variant="...">`
3. **NEVER use admin_button components** - Use `<.button>` from CoreComponents instead
4. **NEVER write inline dark mode color pairs** - Use semantic utilities
5. **ALWAYS use existing form components** - `<.input>`, `<.form_actions>`
6. **ALWAYS use avatar components for user images** - `<.user_avatar>` or `<.user_profile>`
7. **ALWAYS use `<.empty_state>` for empty lists/collections**

### Component Creation Guidelines

Before creating a new component, check if it can be:
1. A variant of an existing component (add `variant` attribute)
2. A composition of existing components (use slots)
3. A utility class in `app.css` (for pure styling)

Only create new components if:
- The pattern appears 2+ times in the codebase
- It has unique behavior/interaction logic
- It improves accessibility or UX consistency

### Standard Pattern Reference

**Site Cards:**
```elixir
<.card variant="indigo" hover>
  <:header><h3 class="text-lg font-semibold">{site.name}</h3></:header>
  <:body>
    <a
      href={"https://#{site.subdomain}.example.com"}
      target="_blank"
      rel="noopener noreferrer"
      class="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline font-mono text-sm"
    >
      <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
      {site.subdomain}.example.com
    </a>
  </:body>
  <:footer>
    <.link navigate={~p"/sites/#{site}/upload"}>Upload</.link>
  </:footer>
</.card>
```

**Page Headers:**
```elixir
<.header icon="hero-globe-alt">
  <:title>Upload to {@site.name}</:title>
  <:subtitle>{@site.subdomain}.example.com</:subtitle>
  <:actions>
    <.back_link navigate={~p"/dashboard"}>Back to Dashboard</.back_link>
  </:actions>
</.header>
```

**Admin Forms:**
```elixir
<.form for={@form} id="site-form" phx-submit="save" phx-change="validate">
  <div class="space-y-4">
    <.input field={@form[:name]} type="text" label="Site Name" required />
    <.input field={@form[:subdomain]} type="text" label="Subdomain" required />
  </div>

  <.form_actions>
    <:submit variant="success">Save Changes</:submit>
    <:cancel phx-click="cancel_edit">Cancel</:cancel>
  </.form_actions>
</.form>
```

**Buttons:**
```elixir
<%!-- Primary action --%>
<.button variant="primary">Create Site</.button>

<%!-- Success/Save action --%>
<.button variant="success" type="submit">Save Changes</.button>

<%!-- Secondary/Cancel action --%>
<.button variant="secondary" phx-click="cancel">Cancel</.button>

<%!-- Danger/Delete action --%>
<.button variant="danger" size="sm" data-confirm="Are you sure?">Delete</.button>

<%!-- Ghost/subtle action --%>
<.button variant="ghost" size="sm">Edit</.button>

<%!-- Button with navigation --%>
<.button variant="primary" navigate={~p"/admin/sites"}>Go to Sites</.button>
```

**Empty States:**
```elixir
<.empty_state icon="hero-inbox">
  No sites assigned yet. Contact your administrator to get access.
</.empty_state>
```

**User Display:**
```elixir
<%!-- Simple avatar --%>
<.user_avatar user={@current_user} size="md" />

<%!-- Avatar with info --%>
<.user_profile user={@current_user} show_email />
```

### File Organization

- **CoreComponents**: General-purpose, reusable across the entire app
- **AdminComponents**: Admin-specific components (admin_button, admin_layout)
- **UploadComponents**: Upload-specific logic (upload_form, upload_entry)
- **app.css**: Semantic utility classes for colors, spacing, etc.

Never create component files outside of `lib/upload_web/components/` without good reason.
```

---

## 🎬 IMMEDIATE NEXT STEPS

### Quick Wins (2-3 hours total)
1. **Phase 1a**: Enhance CoreComponents.button with variants + sizes (45 min) - Highest ROI
   - Update button component with all variants and sizes
   - Migrate admin views to use new button component
   - Remove admin_button* components
2. **Phase 1b**: Create card component (45 min) - Eliminates most duplication
3. **Phase 1c**: Add semantic color utilities to CSS (15 min) - Quick win
4. **Update AGENTS.md** with component guidelines (15 min)

### Full Implementation Order
1. Phase 1: Foundation Components
2. Phase 2: User-Facing Components
3. Phase 3: Advanced UI Patterns
4. Phase 4: System-Level Improvements

---

## 📊 DETAILED PATTERN ANALYSIS

### 1. REPEATED CARD/CONTAINER PATTERNS

#### Site Display Cards (DashboardLive.ex lines 130-154)
**Pattern Found:**
```elixir
<div class="bg-indigo-50 dark:bg-indigo-950/50 border border-indigo-200 dark:border-indigo-800 rounded-lg p-6 hover:bg-indigo-100 dark:hover:bg-indigo-900/50 transition-colors">
  <h3 class="text-lg font-semibold mb-2 text-gray-900 dark:text-gray-100">{site.name}</h3>
  <div class="flex flex-col gap-2">
    <a href={...} class="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline font-mono text-sm">
      <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
      {site_url}
    </a>
    <.link navigate={...}>Upload</.link>
  </div>
</div>
```

**Repeated in:**
- DashboardLive.ex (lines 96-164): Multiple card containers
- SiteUploadLive.ex (lines 78-94): Container card
- AdminComponents (lines 111-123): `admin_card` component

**Opportunity:** Create a general-purpose `card` component with variants (default, indigo, white) and optional hover effects.

---

### 2. PAGE HEADER/TITLE PATTERNS

**Pattern Found in Multiple Files:**

**DashboardLive.ex (lines 73-77):**
```elixir
<h1 class="text-4xl font-bold mb-2 text-gray-900 dark:text-gray-100">
  Welcome, {@current_user.name}!
</h1>
<p class="text-gray-600 dark:text-gray-400">Your personal dashboard</p>
```

**SiteUploadLive.ex (lines 80-86):**
```elixir
<h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
  Upload to {@site.name}
</h1>
<p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
  <.icon name="hero-globe-alt" class="w-4 h-4 inline" />
  {site_url}
</p>
```

**AdminComponents (admin_layout, lines 50-55):**
```elixir
<h2 class="text-2xl font-semibold text-gray-900 dark:text-gray-100">{@page_title}</h2>
```

**Opportunity:** Enhance the existing `CoreComponents.header/1` component (lines 315-329) to support more variants, or create a `page_header` component with title, subtitle, and optional icon support.

---

### 3. LINK/BUTTON WITH ICON PATTERNS

**External Link Pattern (repeated 3+ times):**
```elixir
<a
  href={"https://#{site_url}"}
  target="_blank"
  rel="noopener noreferrer"
  class="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline font-mono text-sm"
>
  <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
  {site_url}
</a>
```

**Locations:**
- DashboardLive.ex lines 103-111
- DashboardLive.ex lines 138-146
- SiteUploadLive.ex lines 84-86 (inline icon)

**Back Link Pattern:**
```elixir
<.link
  navigate={~p"/dashboard"}
  class="inline-flex items-center gap-1 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200"
>
  <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Dashboard
</.link>
```

**Location:** SiteUploadLive.ex lines 70-75

**Opportunity:** Create reusable components:
- `back_link` - for navigation back with left arrow icon
- `icon_link` - for links with custom icons
- Consider enhancing `CoreComponents.button` to support icon slots

---

### 4. BUTTON PATTERN DUPLICATION & INCONSISTENCY

**Current State:**
- **CoreComponents.button** (lines 81-117): Only 2 variants using DaisyUI classes
  - `variant="primary"` → DaisyUI `btn btn-primary`
  - `variant=nil` (default) → DaisyUI `btn btn-primary btn-soft`
  - Supports navigation (navigate, patch, href)

- **AdminComponents** (lines 128-236): 5 separate button components using plain Tailwind
  - `admin_button` - indigo/primary (px-4 py-2)
  - `admin_button_success` - green (px-4 py-2)
  - `admin_button_secondary` - gray (px-4 py-2)
  - `admin_button_danger` - red (px-3 py-1, text-sm)
  - `admin_button_edit` - indigo (px-3 py-1, text-sm)
  - No navigation support

**Problems:**
1. Inconsistent styling approaches (DaisyUI vs plain Tailwind)
2. Duplicate button implementations across files
3. No shared size variants (admin has 2 sizes, core has none)
4. Admin buttons missing navigation support

**Pattern:** All admin buttons share nearly identical structure with only color/size variations:
```elixir
<button
  type={@type}
  class={["px-4 py-2 bg-COLOR text-white rounded hover:bg-COLOR transition-colors disabled:opacity-50", @class]}
  {@rest}
>
  {render_slot(@inner_block)}
</button>
```

**Opportunity:**
1. Enhance CoreComponents.button to support all variants (primary, success, secondary, danger, ghost)
2. Add size attribute (default, sm) for different button sizes
3. Standardize on plain Tailwind classes (remove DaisyUI dependency for buttons)
4. Keep navigation support from CoreComponents.button
5. Remove all admin_button* components entirely
6. Single button API used consistently throughout the app

**Proposed Implementation:**
```elixir
# In CoreComponents
attr :variant, :string,
  values: ~w(primary success secondary danger ghost),
  default: "primary"
attr :size, :string,
  values: ~w(default sm),
  default: "default"
```

---

### 5. EMPTY STATE PATTERNS

**Pattern Found:**
```elixir
<div class="bg-gray-50 dark:bg-gray-900/50 border border-gray-200 dark:border-gray-700 rounded-lg p-6">
  <p class="text-gray-600 dark:text-gray-400">
    {empty_message}
  </p>
</div>
```

**Locations:**
- DashboardLive.ex lines 157-162 (no sites assigned)
- UsersLive.ex lines 100-105 (no sites assigned to user)
- AdminComponents lines 282-291 (`admin_empty_state`)

**Opportunity:** Create a general `empty_state` component with optional icon support (AdminComponents already has a basic version that could be enhanced and moved to CoreComponents).

---

### 6. USER AVATAR/PROFILE DISPLAY

**Pattern Repeated:**
```elixir
<img
  src={user.avatar_url}
  alt={user.name}
  class="h-X w-X rounded-full ring-2 ring-gray-200 dark:ring-gray-700"
/>
```

**Locations:**
- DashboardLive.ex lines 172-176 (16x16 avatar with name/email)
- UsersLive.ex lines 54-59 (8x8 avatar in table)

**Pattern with user info:**
```elixir
<div class="flex items-center gap-3">
  <img src={@current_user.avatar_url} alt={@current_user.name} class="w-16 h-16 rounded-full ring-2 ring-gray-200 dark:ring-gray-700" />
  <div>
    <p class="font-semibold text-gray-900 dark:text-gray-100">{@current_user.name}</p>
    <p class="text-sm text-gray-600 dark:text-gray-400">{@current_user.email}</p>
  </div>
</div>
```

**Opportunity:** Create `user_avatar` and `user_profile` components with size variants (sm, md, lg) and optional info display.

---

### 7. FORM VALIDATION/SUBMIT PATTERNS

**Inline Editing Pattern (SitesLive.ex lines 196-223):**
```elixir
<.form
  for={@form}
  id={@id}
  phx-submit="save_site"
  phx-change="validate_site"
>
  <div class="space-y-4">
    <div class="grid grid-cols-2 gap-4">
      <.input field={@form[:name]} type="text" label="Site Name" required />
      <.input field={@form[:subdomain]} type="text" label="Subdomain" required />
    </div>
    <div class="flex gap-2">
      <.admin_button_success type="submit">{@submit_label}</.admin_button_success>
      <.admin_button_secondary type="button" phx-click="cancel_site_edit">Cancel</.admin_button_secondary>
    </div>
  </div>
</.form>
```

**Pattern:** Form with validation + submit/cancel button group appears in admin forms.

**Opportunity:** Create a `form_actions` component for consistent submit/cancel button layouts.

---

### 8. TOGGLE BUTTON/BADGE PATTERN

**Complex Toggle Badge (UsersLive.ex lines 68-98):**
```elixir
<button
  phx-click="toggle_user_site"
  phx-value-user-id={user.id}
  phx-value-site-id={site.id}
  class={[
    "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium transition-all duration-150",
    if(user_has_site?(user, site.id),
      do: "bg-indigo-100 dark:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 ring-2 ring-indigo-500 dark:ring-indigo-400",
      else: "bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600"
    )
  ]}
>
  <span class={[
    "w-4 h-4 rounded border-2 flex items-center justify-center transition-colors",
    if(user_has_site?(user, site.id),
      do: "bg-indigo-500 border-indigo-500 dark:bg-indigo-400 dark:border-indigo-400",
      else: "border-gray-400 dark:border-gray-500"
    )
  ]}>
    <.icon :if={user_has_site?(user, site.id)} name="hero-check" class="w-3 h-3 text-white" />
  </span>
  {site.name}
</button>
```

**Opportunity:** Create a `toggle_badge` or `checkbox_badge` component for this interactive selection pattern.

---

### 9. ADMIN ACCESS BANNER

**Unique Pattern (DashboardLive.ex lines 79-94):**
```elixir
<div class="mb-6 bg-indigo-600 dark:bg-indigo-700 text-white rounded-lg p-4 flex justify-between items-center">
  <div>
    <h3 class="font-semibold">Admin Access</h3>
    <p class="text-sm text-indigo-100 dark:text-indigo-200">Manage sites, users, and uploads</p>
  </div>
  <.link navigate={~p"/admin/sites"} class="px-4 py-2 bg-white dark:bg-gray-100 text-indigo-600 dark:text-indigo-700 rounded hover:bg-indigo-50 dark:hover:bg-gray-200 font-semibold transition-colors">
    Go to Admin Panel
  </.link>
</div>
```

**Opportunity:** Create a `banner` or `callout` component with variant support (info, warning, success) for promotional/informational content.

---

### 10. DARK MODE COLOR CLASSES

**Heavily Repeated Pattern:**
```
text-gray-900 dark:text-gray-100
text-gray-600 dark:text-gray-400
bg-white dark:bg-gray-800
border-gray-200 dark:border-gray-700
```

**Locations:** Every single LiveView file and component

**Opportunity:** While these can't be fully extracted, consider:
- Adding semantic color utilities to CSS
- Creating wrapper components that handle dark mode automatically
- Documenting standard color pairings

---

### 11. PROGRESS BAR PATTERN

**Upload Progress (UploadComponents lines 42-64):**
```elixir
<div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2.5">
  <div
    class="bg-indigo-600 dark:bg-indigo-500 h-2.5 rounded-full transition-all duration-300"
    style={"width: #{entry.progress}%"}
  >
  </div>
</div>
```

**Opportunity:** Extract into a reusable `progress_bar` component that can be used outside of upload contexts.

---

### 12. GRID LAYOUTS

**Two-Column Grid Pattern:**
```elixir
<div class="grid gap-4 sm:grid-cols-2">
  {items}
</div>
```

**Locations:**
- DashboardLive.ex line 129
- SitesLive.ex line 205 (form grid with grid-cols-2 gap-4)

**Opportunity:** Create responsive grid wrapper components or document standard grid patterns.

---

## 📁 FILE LOCATIONS

**Files to consider updating:**
- `/Users/kaleb/Code/naba-baseball/upload-elixir/upload/lib/upload_web/components/core_components.ex` - Add general-purpose components
- `/Users/kaleb/Code/naba-baseball/upload-elixir/upload/lib/upload_web/components/admin_components.ex` - Consolidate button variants
- `/Users/kaleb/Code/naba-baseball/upload-elixir/upload/lib/upload_web/components/upload_components.ex` - Extract progress bar
- `/Users/kaleb/Code/naba-baseball/upload-elixir/upload/assets/css/app.css` - Add semantic color utilities
