# Facebouffe — Design Brief & Per-Page Schema

> **How to use this doc with Claude Design**
> Start a session by pasting **§1 (Brief)** + **§2 (Global Schema)** and attaching `facebouffe-seed.json`. That sets context. Then work **one page at a time**: paste the relevant **Page** block from §4 (and any **Concept** from §3 it references) and ask for that single mockup. If you start a fresh session, re-paste §1 + §2 first.
> Suggested order: **Recipe page → Sous-chef → Home → Add/Edit → Shopping list → Search → Settings → the AI/secondary pages.** The recipe page is richest and sets the visual tone.
>
> **What v2 is.** v1 described a Phase-1 catalog with nutrition and AI import "designed-for, built later." Those are now **built and shipped**, along with several features v1 never covered (ingredient/step **sections**, a **recycle bin**, **multi-recipe Sous-chef**, two **AI recipe generators**, **file import**). v2 describes the app **as it exists today**, in present tense. The only genuinely-future work is the **Phase 2 social layer** (see Roadmap).

---

## 1. Design Brief

**What it is.** Facebouffe is a personal recipe catalog for your phone — add, organize, cook from, and now *generate* your own recipes. It is standalone and local-first (no accounts, no feed; optional cloud AI is the user's own key). The name is a Québec pun on "Facebook"; the app feels playful and warm, but it is a real cooking tool, not a gag.

**Roadmap.** The standalone catalog, Sous-chef cooking mode, the auto nutrition label, and the full AI-assisted import + generation engine are **all shipped**. The only future chapter is **Phase 2 — a social layer** (sharing, comments, following), not yet specced; recipes already carry `createdBy` and UUIDs so that layer can attach cleanly later.

**Who it's for.** Home cooks who want their recipes in one tidy, good-looking place, a clean helper while actually cooking (even several dishes at once), and low-friction ways to get recipes *in* — type, paste, snap, import a file or link, or let an AI draft one.

**Design principles**
- **Food-forward.** Photography and color carry the warmth. With no image, a deterministic color from a curated palette (seeded by recipe id/title) stands in — intentional, not broken.
- **Calm hierarchy.** Generous whitespace, clear typographic levels, one primary action per screen.
- **Bilingual by design.** Every label exists in FR and EN; nothing breaks when a French label runs ~20% longer. Recipe *content* is never translated — only the UI chrome. (The AI generators write in the app's current language.)
- **Lean when cooking.** The full recipe page is rich; Sous-chef mode is stripped, legible at arm's length, glanceable — and can hold a small **stack** of recipes you cook in parallel.
- **AI assists, the human confirms — except where the user opts out.** Every *import* path fills the editor as a reviewable draft; nothing auto-saves. The two *generators* are the deliberate exception: they're explicit "surprise me" actions that save and open directly (no review by design).
- **Local-first, cloud-optional, transparent.** Everything works offline. Cloud AI requires the user's own API key (BYOK); whenever an action would send content off-device, the app says which engine is running and, on the on-device path, asks before anything leaves the phone.
- **Modern but not fussy.** Rounded, soft shadows, restraint; up to par with high-end consumer apps. No skeuomorphic kitsch.

**Visual direction (starting point, not a cage).** Warm, appetizing palette — terracotta/orange/green/gold; the app chrome echoes the seed tags. A characterful display face for titles, a clean neutral for body. Large tap targets. "Well-art-directed cookbook meets a tidy utility app."

**Navigation skeleton**
- Bottom tab bar: **Accueil / Recherche / Liste d'épicerie / Réglages** (Home / Search / Shopping list / Settings).
- A floating **"+"** on Home opens a **method chooser** — **Manuellement · À partir d'un lien · À partir d'une photo · À partir de texte** (Manuellement first). All paths land on the same Add/Edit screen as a reviewable draft. "From text" also imports a **file** (PDF, Word, TXT, HTML). See §3.5.
- **Favorites** are surfaced on Home, not a separate tab.
- **Two hidden long-press easter eggs** (only active when a BYOK key is set): long-press the **"+"** opens *"Je me sens aventureux !"* (invent a recipe); long-press a recipe's **"Ajouter une variante"** opens *"Ajouter une mutation"* (AI variant). See §3.5 / §4.

**Screen inventory.** Home · Filtered list · Recipe description page · Sous-chef mode (multi-recipe, 2 swipeable panes each) · Add/Edit (sectioned flow, with ingredient/step sections) · Import method chooser · Shopping list · Search · Settings · Advanced settings · **AI Import Assistant** · **Recently deleted (Corbeille)** · **"Je me sens aventureux !"** · **"Ajouter une mutation."**

---

## 2. Global Schema

All ids are UUIDs. Dates are ISO 8601. Image fields are local filenames/paths (or `null`). Optional fields are absent on older data and load as defaults.

```
Recipe {
  id              UUID
  title           string
  createdBy       string            // username; preserved on import, NOT tied to id
  dateAdded       ISO
  dateModified    ISO
  source          string | null     // attribution, e.g. "Recette de grand-maman", "Importé d'un lien", "Inventé par l'IA"
  heroImage       filename | null   // null => fallback palette color
  gallery         filename[]
  description     richtext          // prose; may contain {{link:<recipeId>}} + {{temp:v:u}} inline tokens
  servings        int               // base servings; scaling multiplies from here
  prepTimeMinutes int
  cookTimeMinutes int
  tags            tagId[]           // includes "tag-fav" when favorited
  variantGroupId  groupId | null
  links           recipeId[]        // references to OTHER dishes (≠ variants)
  ingredients     Ingredient[]
  steps           Step[]
  personal        Personal
  nutrition       Nutrition | null  // computed estimate; null until generated (§3.3)
}

Ingredient {
  quantity     number | null        // null = uncounted / handled via unit
  unit         enum | null          // g,kg,ml,l,tsp,tbsp,cup,oz,lb,pinch... null = countable (eggs, onions)
  name         string
  note         string?              // "à température pièce", "optionnel", "fondu"
  group        string?              // optional SECTION heading, e.g. "Pâte", "Glaçage"; null/empty = ungrouped (§3.2)
  nutritionRef NutritionRef | null  // per-row resolved CNF match (§3.3)
}

Step {
  text         string
  image        filename | null      // shows on recipe page step list ONLY; hidden in Sous-chef
  timerSeconds int | null           // null = no timer
  group        string?              // optional SECTION heading, e.g. "Préparation", "Montage" (§3.2)
}

Personal { notes string; rating int /*0–5, 0=unrated*/; lastCooked ISO|null; madeCount int }

NutritionRef {                      // per-ingredient, persisted (§3.3)
  foodCode      string              // CNF food code
  matchedName   string              // e.g. "Beurre, salé"
  confidence    number              // 0–1 matcher certainty
  includeInCalc bool                // false = excluded (frying oil, "sel au goût"…)
}

Nutrition {                         // computed once, stored on the recipe (§3.3)
  perServing { calories, protein, fat, carbs, sodium, … }
  total      { … }
  isEstimate   bool                 // always true; surfaced in UI
  hasUnmatched bool                 // ≥1 ingredient unmatched/excluded
  computedAt   ISO
}

Tag {
  id      tagId
  system  bool                      // true = built-in
  special "favorite"?               // only on the favorites tag: non-removable, non-renamable, star UI
  name    {fr,en} | string          // system tags: {fr,en}; user tags: a single string
  icon    string
  color   hex
}

VariantGroup { groupId; memberIds recipeId[]; baseId recipeId /*group's representative; reassignable*/ }

Profile {
  username  string
  language  "fr" | "en"
  units     { temperature:"celsius"|"fahrenheit", volume:"metric"|"imperial", weight:"metric"|"imperial" }
  fontSize  "small" | "medium" | "large"
  tipsSeen  { sousChef, variants, shoppingAdd, pdfExport, variantChips, cookStack,
              customTags, ingredientAliases, apiKeys, preferredAi : bool }   // §3.7
}

// App-state stores (local, not in the seed file):
ShoppingItem   { id UUID; name string; quantity number|null; unit enum|null; checked bool; sourceRecipeId recipeId|null }
IngredientAliases  { "<normalized name>": { foodCode, matchedName } }   // learned CNF defaults (§3.3)
RecentlyDeleted    [ { recipe Recipe, photo, gallery[], deletedAt ISO } ]  // soft-delete buffer, newest-first, capped 25 (§3.8)
ImportConfig   { preferredAI:"online"|"ondevice", byokKeys{claude?,openai?,gemini?}, onDeviceModelPresent bool }  // §3.5; keys in Keychain/Keystore
```

**Cross-cutting rules the designer should respect**
- **Variant ≠ link.** Variants are forks of the *same dish* (swipeable via chips on the recipe page); links are references to *different dishes* (inline in prose, navigate away). Links are inserted via a search picker (by title, up to 10, scrollable).
- **Sections (groups) are presentation over a flat list.** `ingredients`/`steps` stay flat; an optional `group` label clusters contiguous items under a heading. Ungrouped = today's look. Nutrition, shopping, search, scaling all ignore grouping (§3.2).
- **Scaling.** A servings stepper recomputes ingredient quantities from `servings`; show friendly fractions (¾ cup, not 0.75); same-dimension unit conversion only.
- **Fallback color.** `heroImage: null` → deterministic palette color seeded by id/title. The same color identifies a recipe elsewhere (e.g. Sous-chef tab tiles, picker dots).
- **Favorites** = the special `tag-fav`; toggled by a star, listed on Home; never shown as an editor pill.
- **Temperatures** in free text are inline `{{temp:value:unit}}` tokens, auto-detected as the user types, converted on display per `Profile.units.temperature` (§3.1).
- **Deletion is recoverable.** Deleting a recipe is a *soft* delete into a capped recycle bin, restorable from Settings (§3.8).

---

## 3. Concepts (cross-cutting)

### 3.1 Temperatures in free text
Temperatures live inside free-form text (`step.text`, `description`), unlike structured volume/weight ingredient fields. They are a **second inline token type** alongside `{{link:id}}`, sharing the same parse/render machinery.
- **Storage token** `{{temp:<value>:<unit>}}`, unit `c`|`f` (e.g. `{{temp:180:c}}`). Stores the **authored** value+unit; conversion happens only at display, so round-trips don't accumulate rounding error.
- **Capture — fully automatic.** As the user types, a number immediately followed by an explicit marker (`°C`,`°F`,`℃`,`℉`, case-insensitive) becomes a token; a detected temperature gets a subtle highlight in the editor. A bare `°` or "degrés/degrees" with no C/F is **ambiguous → left literal**. No manual tagging gesture.
- **Convenience pills.** The step/description editor toolbar offers **`°C`** and **`°F`** insert buttons — purely ergonomic (degree symbols are painful on phones) and they guarantee the marker the detector needs.
- **Display.** Authored unit == setting → as authored; authored unit ≠ setting → convert and **round to nearest 5°** in the target unit (e.g. 180 °C → 355 °F; the slight drift from oven-dial 350 is intentional). Mixed `c`/`f` in one recipe each convert independently.

### 3.2 Ingredient & step sections (groups)
A recipe can split its ingredients and/or steps into labelled **sections** — e.g. a cake with a "Pâte" and a "Glaçage", a build with "Préparation" then "Montage". Default is **no sections** (a flat list, exactly as before).
- **Model.** Each `Ingredient`/`Step` carries an optional `group` string. Display groups by **contiguous runs** of the same label: a section is a heading + the items beneath it until the next heading. Ingredient sections and step sections are independent and free-form (any name, per recipe).
- **Display (recipe page, Sous-chef, PDF).** A run with a label shows a small section heading above it; ungrouped runs show no heading. **Step numbering stays continuous (1…N) across sections** — headings just punctuate the list.
- **Editing.** The Ingredients and Steps editors let the user **"Ajouter une section"** (a header card) and **drag** items/headers to reorganize; an item belongs to the nearest header above it. Empty sections (no items) vanish on save (§4 Add/Edit).
- **Import.** A site's structured step sections (schema.org `HowToSection` names) carry through as step groups; the AI engines can emit a `group` per item. (Ingredient sections rarely exist in structured web data, so the rule-based parser leaves ingredients ungrouped; AI import can infer them.)
- **Logic ignores grouping.** Nutrition, shopping-list building, search, and scaling all operate on the flat list — sections are purely how the recipe reads.

### 3.3 Nutritional label
On the **Ingrédients** section of Add/Edit, the user can optionally **generate an estimated nutrition label**, shown per serving + total on the recipe page (and optionally in PDF). Always framed as an **estimate**, never a regulatory Nutrition Facts panel.
- **Data source — local Canadian Nutrient File (CNF), bundled.** Bilingual FR/EN (matches French ingredient names with no translate step), offline, free, Canadian-relevant. The label persists on the recipe and shows without a network.
- **Matching + correction.** Each ingredient auto-matches to a CNF food: **alias table first** (learned defaults) → **fuzzy match** fallback. The match shows inline and is **correctable** ("beurre → Beurre, salé ✎"); unmatched ingredients are flagged, not dropped. Each ingredient has an **include-in-calc** toggle (default-off for things like a 1.5 L frying bath or "sel au goût"). Volume→weight (e.g. "2 cups flour" → g) uses CNF household measures.
- **Learned alias table.** A recipe-independent local store mapping a normalized ingredient name → preferred CNF food, so a correction made once becomes the default thereafter. **Going-forward only** (doesn't rewrite finalized recipes), **override-able per row**, **normalized keys** (lowercased/trimmed). Viewable/editable in **Advanced settings → "Aliases d'ingrédients."**

### 3.4 Tag management
Two jobs: **managing** tags (create/rename/delete) lives in **Advanced settings → Tags personnalisés**; **applying** tags lives in the **Add/Edit editor**.
- **System tags** (Déjeuner, Dessert, Soupe…) and `tag-fav`: not editable/deletable; fixed bilingual names/icons/colors. **User tags**: single-string name, fully managed.
- **Managing.** New user tags auto-get a palette color + sensible icon (no required appearance step; changing it later is optional). **Delete drops the relationship, never destroys recipes**, and confirms with a count (*"…retiré de 3 recettes."*). **Rename propagates everywhere.** Names match **case-insensitively** (near-dupes warn "Ce tag existe déjà").
- **Applying (editor).** Selected tags as colored pills first, unselected as grayed pills (tap to toggle), plus **"+ tag"** opening the same search picker as the recipe-link picker, with **inline create** (auto color/icon, dup warning). The favorite **star is its own control**, never an editor pill.
- **"Hallucinations" tag.** The AI generators (§3.5) auto-create and apply a user tag named **Hallucinations** so AI-made recipes cluster under one filter; the user can re-tag freely afterward.

### 3.5 Import & AI assistance
Getting recipes *in* spans three ideas the designer should keep distinct: **engines** (who does the work), **sources** (what you start from), and **generation** (no source at all). Plus the **configuration** that powers the AI paths.

**Engines (tiers).** Every import resolves to one engine, and the UI always **shows which one is running** (a small badge), with a one-tap **"retry with <next engine>"** when one fails:
- **Rules (Tier 0)** — free, offline, zero-hallucination. Parses a web page's schema.org/Recipe structured data. Tried first for links.
- **On-device (Tier 1)** — a small local LLM (+ on-device OCR for photos). Free and private; requires a one-time **model download** (large; Wi-Fi recommended). Best-effort on messy input.
- **Online / BYOK (Tier 2)** — the user's own cloud API key (Claude / ChatGPT / Gemini). Best quality; billed to the user's account; sends content to the provider.

**Sources.**
- **Lien (URL).** Tier 0 first (works on any site with structured data). If the page has none — or is bot-protected — the app can fold to an AI engine: it fetches the page, strips it to readable text, and feeds that to the LLM. Sites that block direct fetching are recovered through a rendering reader service; because that sends the URL to a third party, the **on-device path asks for confirmation first** (the cloud path is external by definition, so it doesn't).
- **Texte.** Paste recipe text, **or import a file** — PDF, Word (.docx), plain text/Markdown, or HTML. The file's text is extracted into the editable box, then runs through the AI like pasted text. Image-only/scanned PDFs (no text layer) prompt the user to use the photo path instead.
- **Photo.** Camera or gallery; OCR + LLM. Optionally the user can **draw boxes** around the ingredient and step regions to guide a small model.
- **Share-sheet ("Partager vers Facebouffe").** Share a link or image from any app; it lands on the same review flow. (Browser shares that wrap the URL in a share/short link are unwrapped to the real page.)

**Decision tree (per source), connectivity-aware.** Link → Rules, else the preferred AI that's available; Text/Photo → the preferred AI (online if connected + a key exists, else on-device if the model is present), else fail with guidance. The chosen **"Preferred AI"** (on-device ↔ online) decides ordering when both are possible.

**Configuration — the "Assistant d'import IA" settings page.** A dedicated page (reached from a row just under *Paramètres avancés* in Réglages) holds, top to bottom: the **on-device model** download/manage group, the **clés API** (BYOK) group, and the **"Assistant IA préféré"** radio (Online API ↔ On-device, each greyed out until its prerequisite is configured). Keys live in the OS keystore, are never logged, and are sent only to their provider. *(Advanced settings keeps only Tags + Aliases — see §4.)*

**Non-negotiables for any AI import.** Validate the returned JSON against the schema (units ∈ enum, numeric quantities, required fields), then **land on the sectioned Add/Edit screen to confirm** — imports never auto-save. Preserve the source language. Give the model the schema + a seed example; use structured-output modes where available.

**AI generation (the two easter eggs — BYOK only).** Distinct from import: there is no source recipe, the LLM *invents*, and — by deliberate design — these **save and open directly without a review step** (they're explicit "surprise me" actions). Both tag their output **Hallucinations** (§3.4) and surface the model in a waiting overlay.
- **"Je me sens aventureux !"** — long-press the **"+"** add button. Pick a **meal** (required) and optionally toggle ingredient/cuisine pills (curated suggestions + free text) and free-form notes; **"Que l'aventure commence !"** generates a fitting new recipe and opens it.
- **"Ajouter une mutation"** — long-press a recipe's **"Ajouter une variante."** Optional ingredient/cuisine cues + free-form instructions; generates a twist on the current recipe, saved as a **variant in its group**, carrying the original's tags **plus** Hallucinations.

### 3.6 Motion & transitions
Selective and purposeful, not animating everything. Guardrails: **respect OS reduce-motion** (replace movement with a quick fade/cut); **prefer transform & opacity over blur/shadow** (GPU-cheap); **nothing looping in Sous-chef** (the screen is forced awake — one-shot transitions only). Durations ~200–300ms, natural easing. Lean on Flutter's platform-default page transitions.
- **Spend** on: navigation into a recipe (platform push/pop); the **Sous-chef toggle**; the **two-pane swipe** (gestural, tracks the finger); **favorite-star pop**; **editor row add/remove/drag** (animated list, with edge-of-screen **auto-scroll while dragging**); **variant-chip crossfade**; **Sous-chef tab switching** (a quick swap between stacked recipes).
- **Hold back** on: anything looping in Sous-chef; the timer countdown (update the number, don't animate digits); heavy blur/shadow tweens (set the Sous-chef dim, don't animate it).

### 3.7 Help & onboarding
Facebouffe is *intermittent-use*: **no upfront tutorial, nothing blocking.** Help arrives at the moment of need, three layers, cheapest first.
- **Layer 1 — labels.** Every primary control is **icon + text** ("Ajouter à la liste", "Exporter PDF", "Ajouter une variante"). *Exception:* "Mode sous-chef" keeps its brand label, explained by its first-use coach mark.
- **Layer 2 — empty states that teach** (no dismissal): empty shopping list, no favorites yet, empty recycle bin, etc.
- **Layer 3 — just-in-time coach marks, one feature at a time, never bundled.** Persisted seen-flags (`Profile.tipsSeen`). On the recipe page: **sousChef, variants, shoppingAdd, pdfExport, variantChips**. In Sous-chef: **cookStack** (a one-time hint introducing multi-recipe cooking). On the sub-pages, the first time each section is reached: **customTags** + **ingredientAliases** (Paramètres avancés), and **apiKeys** + **preferredAi** (Assistant d'import IA). One spotlight at a time per page, dismissible, fade per §3.6.
- **Persistent fallback — "Aide"** in Settings: a short bilingual glossary of the app's own terms (sous-chef, variante, tag, section/groupe, alias d'ingrédient, assistant d'import IA, clé API, Hallucinations) + a few how-tos.
- **"Revoir les astuces"** in Settings resets all seen-flags so coach marks reappear.
- All help copy exists in FR + EN; keep it short.

---

## 4. Per-Page Specs
Each block: **Purpose · Reads/Writes · Key UI · States & edges · Mockup seed.** Paste one block at a time.

### Page — Recipe Description (the full page)
- **Purpose.** The complete recipe as in a cookbook, read top-to-bottom by scrolling. *No left-right swipe here.*
- **Reads.** Full `Recipe`; `VariantGroup` (chips); resolved `Tag`s; linked recipe titles; `nutrition` if present.
- **Writes.** Favorite star; servings scale (session); "Ajouter à la liste" pushes scaled ingredients to the shopping list.
- **Key UI.** Hero (or fallback color) → **tag row** (colored pills, below image/above title) → title/source. **Variant chips** near the top when grouped. Favorite star. Servings stepper. Prep/cook time + rating. Then **prose** (with inline link + temperature chips) → **ingredients** (structured, scaled, with **section headings** where grouped) → **step-by-step** (continuous numbering across sections, per-step image/timer) → **nutrition card** (if generated; labeled *estimation*) → **gallery**. Action row: **Mode sous-chef**, **Ajouter une variante**, **Ajouter à la liste d'épicerie**, **Exporter en PDF**, edit.
- **Easter egg.** **Long-press "Ajouter une variante"** (only with a BYOK key set) opens *"Ajouter une mutation"* (§3.5).
- **States & edges.** No hero → palette color. No variants → no chips. Ungrouped recipe → no section headings (unchanged look). Long FR labels. First-use coach marks fire here (sousChef, variants, shoppingAdd, pdfExport, variantChips), one at a time.
- **Mockup seed.** "Recipe page for a layered cake with **ingredient sections** (Pâte / Glaçage) and **step sections** (Préparation / Montage): hero image, tag row (Dessert, ★), variant chips, servings stepper, prose with an inline link chip, sectioned ingredients, continuously-numbered steps under section headings with one step photo + a timer badge, an estimated nutrition card, gallery, and the action row with the Sous-chef toggle."

### Page — Sous-Chef Mode (multi-recipe)
- **Purpose.** Lean cooking helper, legible at arm's length — and able to hold a **stack of up to 4 recipes** cooked in parallel (e.g. a cake base + a frosting). Each recipe has two panes, **swiped left-right**: **Ingrédients** and **Étapes**.
- **Reads.** Per recipe: `ingredients` (scaled, with section headings), `steps` (text + timers; **no step images here**), `heroImage`/fallback for the dimmed background, `Profile.fontSize`.
- **Writes.** Starts/cancels timers (kept across recipe switches); keeps the screen awake (subtle indicator); marks a recipe cooked on finish.
- **Key UI.**
  - **Single recipe:** dimmed hero/fallback background; 2-dot pane indicator; big type sized by `fontSize`; tappable timers; a **running-timers tray** across both panes; an **"add recipe" (+)** affordance in the top bar; exit ✕.
  - **Stacked (≥2):** a **bottom tab bar** of recipes — each a small tile showing the recipe's **first letter on its assigned color**; the **active tile widens to show its title** and a close ✕ (long-press any tile to close; closing a tab with a running timer confirms first). A trailing **+ tile** adds more. Each tab is an independent session preserving its pane, step position, and ingredient checklist.
  - **Section headings** show in the ingredients checklist and as a **context heading on the current step**; the step progress bar marks section boundaries.
  - **Running-timers tray** spans all stacked recipes, each timer dotted with its recipe's color; tapping one jumps to that recipe + step.
- **Open another recipe.** The **+** opens a searchable, **text-only** picker: recipes **linked to / mentioned in** the current one pinned on top, then everything else by recency; current/open recipes excluded. Picking one prompts a **quick servings stepper**, then it joins the stack.
- **In-step links.** Tapping an inline `{{link}}` in a step offers **"Voir la recette"** or **"Ajouter à la cuisson"** (add it to the stack).
- **Finish / exit.** Reaching a recipe's last step marks it cooked and **closes just that tab** (exits Sous-chef if it was the last). The top-left ✕ exits the whole session.
- **States & edges.** No image → dimmed palette. 2–3 concurrent timers across recipes. Timers are scheduled OS notifications, not a guaranteed live countdown (the tray reflects this). Stack is **ephemeral** (lives while Sous-chef is open). First entry shows the **cookStack** hint (§3.7).
- **Mockup seed.** "Sous-chef with **two stacked recipes**: a bottom tab bar where the active tile reads 'G · Génoise' (its color) next to a compact 'C' tile and a + tile; the Étapes pane in big type with a 'Glaçage' section heading above the step, a 2-dot pane indicator, and a running-timers tray pinned on top showing one timer with a color dot for the *other* recipe."

### Page — Home (Accueil)
- **Purpose.** Entry point and browse-by-tag hub.
- **Reads.** All `Tag`s (icon+color buttons); favorited recipes; optionally recently cooked.
- **Key UI.** Grid of **tag buttons** (icon + color, bilingual) opening a filtered list; a **Favoris** carousel; optional "récemment cuisinés"; floating **"+"** (opens the method chooser); bottom tab bar.
- **Easter egg.** **Long-press "+"** (with a BYOK key set) opens *"Je me sens aventureux !"* (§3.5).
- **States & edges.** First launch with seed data. User tags sit alongside system tags. **Empty favorites → a short teaching prompt** about the star.
- **Mockup seed.** "Home: a colorful grid of tag buttons (Déjeuner, Souper, Dessert, Soupe, Salade, Hi-protéine, Hallucinations…), a Favoris carousel of 3 recipes, a floating + button, the 4-item bottom tab bar."

### Page — Import method chooser
- **Purpose.** The small sheet the "+" opens — choose how to start a recipe. Not a tab; an occasional action.
- **Key UI.** Four cards: **Manuellement** (first) · **À partir d'un lien** · **À partir d'une photo** · **À partir de texte**. A note points out the share-sheet alternative. All paths land on Add/Edit as a reviewable draft.
- **States & edges.** On the link/text/photo screens, a small **engine badge** shows which engine will run, and on failure a **"Réessayer avec <engine>"** offers the next tier. The text screen shows an **"Importer un fichier (PDF, Word, TXT)"** button; the photo screen offers an optional **"encadrer les régions"** (draw boxes) toggle.
- **Mockup seed.** "The '+' method-chooser sheet with four cards (Manuellement, À partir d'un lien, À partir d'une photo, À partir de texte) and a subtle 'ou partagez vers Facebouffe' hint; then the 'À partir de texte' screen showing the paste box, an 'Importer un fichier' button, an engine badge ('Gemini'), and the run button."

### Page — Add / Edit Recipe (sectioned flow)
- **Purpose.** Create/edit a recipe — the most complex screen, a **sectioned flow** (not one endless scroll). Also the **shared review destination for every import path** (§3.5): manual, link, photo, text/file, and share-sheet all land here pre-filled; imports never auto-commit.
- **Sections.** (1) **Infos** — hero (with camera capture), then the **tag row** (below image/above title), then title, source, servings, prep/cook. (2) **Ingrédients** — structured rows `{quantity, unit, name, note}` plus optional **section headers**; add/reorder/delete; **"Ajouter une section."** Optional **nutrition** panel (match/correct/include-toggle/generate, §3.3). (3) **Étapes** — rows with text, optional timer/photo, plus **section headers**; `°C`/`°F` insert pills + temperature auto-detect. (4) **Description** — prose + insert-link-to-recipe + gallery; same temperature aids. A section nav lets the user jump around.
- **Sections editor.** A header card ("Ajouter une section") sits inline among the rows; **drag** items and headers to reorganize (dragging near a screen edge auto-scrolls); an item joins the nearest header above it; empty sections drop on save (§3.2). Step numbering shown stays continuous.
- **File import.** On the Description/Texte path, "Importer un fichier" extracts a PDF/Word/TXT/HTML's text for review.
- **Delete.** Editing an existing recipe offers **Supprimer**, which **confirms** and then soft-deletes to the recycle bin (recoverable, §3.8).
- **Recipe-link picker.** "Insert link" opens a picker: search by title, up to 10 results (scrolls if more); empty query → 10 most-recently-modified; excludes the current recipe; inserts a `{{link:id}}` token.
- **States & edges.** Quick repeatable row adds; unit picker reflects dimension; validation (title + ≥1 ingredient); editing pre-fills everything; recognized temperatures highlight.
- **Mockup seed.** "Add/Edit, Ingrédients section mid-edit: two **section header cards** ('Pâte', 'Glaçage') with structured ingredient rows beneath each (quantity / unit picker / name / note), drag handles, an 'Ajouter un ingrédient' and 'Ajouter une section' button, and a collapsed nutrition panel below."

### Page — Shopping List (Liste d'épicerie)
- **Purpose.** Aggregated grocery list from recipes (scaled) + manual items.
- **Reads/Writes.** `ShoppingItem[]`; check-off; manual add; clear checked/all.
- **Key UI.** Grouped checkable rows; merge by matching name + compatible unit (convert within a dimension, else separate lines); subtle source-recipe hint; manual "+".
- **States & edges.** **Empty state teaches** ("Votre liste est vide…"). Unmergeable dupes as separate lines. Mixed checked/unchecked.
- **Mockup seed.** "Shopping list aggregated from two recipes (scaled), a couple checked, one manual item, grouped sensibly, with source hints."

### Page — Search (Recherche)
- **Purpose.** Find recipes by text and ingredient.
- **Reads.** All recipes (title + description + `ingredients.name`); tags as filter chips.
- **Key UI.** Search field; **ingredient filter** (preset buttons + free text); tag chips; recipe-card results; a base recipe shows once with a **variants badge**.
- **States & edges.** No results; multiple active filters; variant-base dedup.
- **Mockup seed.** "Search: query field, a row of preset ingredient buttons + tag chips, results as cards including a base donut card with a 'variantes' badge."

### Page — Settings (Réglages)
- **Purpose.** Everyday config + data management + help + entries to the sub-pages.
- **Reads/Writes.** `Profile`; load/save the JSON book; PDF export.
- **Key UI.** **Nom d'utilisateur** · **Langue** (FR/EN, default OS) · **Unités** (three independent toggles: température, volume, poids) · **Taille de police** · **Aide** (glossary + how-tos) · **Revoir les astuces** (reset tips) · **Charger / Sauvegarder les recettes** (JSON book) · **Exporter en livre (PDF)** (with recipe selection) · and a sub-page group: **Paramètres avancés ›**, **Assistant d'import IA ›**, **Corbeille ›** (recently deleted).
- **States & edges.** Load-merge messaging; PDF selection sheet; long bilingual labels; reset-tips confirmation.
- **Mockup seed.** "Settings: username, language toggle, three unit toggles, font-size selector, a Charger/Sauvegarder + Exporter en livre (PDF) block, and an 'Avancé' group with three nav rows — Paramètres avancés, Assistant d'import IA, Corbeille — each with icon + subtitle."

### Page — Advanced Settings (Paramètres avancés)
- **Purpose.** Occasional power-user config, kept out of everyday Settings. **Now scoped to just tags + aliases** (import/keys moved to the AI Import Assistant page).
- **Key UI — in order:** (1) **Tags personnalisés** — manage user tags: create (auto color/icon), rename, delete with affected-recipe count; system tags read-only/omitted (§3.4). (2) **Aliases d'ingrédients** — view/edit/remove the learned ingredient→CNF alias table (§3.3).
- **States & edges.** Tag delete confirms with count; duplicate name warns; empty alias-table state.
- **Mockup seed.** "Advanced settings: two stacked sections — Tags personnalisés (user-tag list with rename/delete) and Aliases d'ingrédients (ingredient → CNF-food rows with edit/remove) — and a back arrow to Réglages."

### Page — AI Import Assistant (Assistant d'import IA)
- **Purpose.** One home for everything that powers AI import/generation; reached from a row just under *Paramètres avancés*.
- **Key UI — top to bottom:** (1) **Modèle sur l'appareil** — download/progress/delete of the one-time on-device model (large; Wi-Fi recommended; stays local). (2) **Clés API** — BYOK provider keys (Claude / ChatGPT / Gemini): pick provider, paste/test/delete; masked with reveal; stored in the OS keystore. (3) **Assistant IA préféré** — a radio between **API en ligne** and **Sur l'appareil**, each **greyed out until configured** (no key / no model), with a one-line hint that this is used whenever an AI is needed (text, image, unrecognized link).
- **States & edges.** Model not downloaded vs downloading (progress) vs ready (delete); key valid/invalid/testing; both options greyed when nothing is set up.
- **Mockup seed.** "Assistant d'import IA page: an on-device-model card (a 'Télécharger le modèle (~Go)' button with a privacy note), an API-keys card (provider segmented control Claude/ChatGPT/Gemini, masked key field, Test/Delete), and a 'Assistant IA préféré' radio (API en ligne / Sur l'appareil) with the on-device option greyed and a 'téléchargez le modèle' reason."

### Page — Recently Deleted (Corbeille)
- **Purpose.** Restore a recently deleted recipe; reached from Settings.
- **Reads/Writes.** The `RecentlyDeleted` buffer (newest-first, capped **25**); restore or permanently purge an entry.
- **Key UI.** A short hint line; per-entry cards showing the recipe title + small ingredient/step counts, a **Restaurer** button, and a small **delete-forever** (purge, confirmed). Restoring returns the recipe (with its photos, steps, sections, nutrition) to the collection; older entries beyond 25 are evicted automatically.
- **States & edges.** **Empty state** ("Aucune recette supprimée récemment."). Restore shows a brief confirmation.
- **Mockup seed.** "Corbeille page: a hint that the last 25 deletions are kept, then two entry cards (title + '12 🧺 · 6 📝' counts) each with a Restaurer button and a faint trash icon, plus a back arrow."

### Page — "Je me sens aventureux !" (AI invent — easter egg)
- **Purpose.** Let the LLM **invent** a recipe from a few cues. Hidden: **long-press the "+"**, BYOK only.
- **Key UI.** ✦ header. A **required meal** picker (Déjeuner/Dîner/Souper/Collation/Dessert, single-select). Optional **ingredient** pills (curated suggestions + a free-text add) and **cuisine** pills (multi-select). A free-form **"Autres envies"** box. A primary **"Que l'aventure commence !"** (disabled until a meal is chosen). A full-screen **waiting overlay** ("Concoction en cours…") showing the model being used.
- **Behavior.** Generates → tags the result **Hallucinations** → **saves and opens it directly** (no review). On failure, an error and nothing saved.
- **Mockup seed.** "‘Je me sens aventureux !’ page: meal pills with 'Souper' selected, a wrap of ingredient suggestion pills (a couple selected) + an 'add ingredient' field, cuisine pills (Thaïe, Grecque), a notes box, and a big 'Que l'aventure commence !' button; plus the waiting overlay variant showing a spinner, 'Concoction en cours…', and a faint model id."

### Page — "Ajouter une mutation" (AI variant — easter egg)
- **Purpose.** Let the LLM produce a **variant** of the current recipe from cues. Hidden: **long-press "Ajouter une variante"** on a recipe, BYOK only.
- **Key UI.** ✦ header. Same shape as the invent page **minus the meal picker**: optional ingredient + cuisine pills, and a **free-form instructions** box. A primary **"Générer la mutation."** Same waiting overlay.
- **Behavior.** Generates a twist on the base recipe → saved as a **variant in its group** → tagged with the **original's tags + Hallucinations** → opens directly (no review).
- **Mockup seed.** "‘Ajouter une mutation’ page for an existing soup: ingredient + cuisine suggestion pills, a 'instructions' box ('rends-la plus épicée, version thaï'), and a 'Générer la mutation' button."

---

*Seed data: `facebouffe-seed.json` — recipes including a variant group, an inter-recipe link, mixed units, timers, a per-step image, favorites, temperature tokens, and image-less recipes for the fallback palette. (A refreshed seed could also showcase ingredient/step **sections** and a generated **nutrition** label.)*
