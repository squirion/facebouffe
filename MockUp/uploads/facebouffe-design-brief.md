# Facebouffe — Design Brief & Per-Page Schema

> **How to use this doc with Claude Design**
> Start a session by pasting **Section 1 (Brief)** + **Section 2 (Global Schema)** + attaching `facebouffe-seed.json`. That sets the context. Then work **one page at a time**: paste the relevant **Page** block from Section 3 and ask for that single mockup. If you start a fresh session, re-paste Sections 1 + 2 first.
> Suggested order: **Recipe page → Sous-chef → Home → Add/Edit → Shopping list → Search → Settings.** The recipe page is richest and sets the visual tone.

---

## 1. Design Brief

**What it is.** Facebouffe is a personal recipe catalog for your phone — add, organize, and cook from your own recipes. Phase 1 is standalone and local-only (no accounts, no feed). The name is a Québec pun on "Facebook"; the app should feel playful and warm, but it is a real cooking tool, not a gag.

**Roadmap.** **Phase 1** (this brief — all per-page specs below): standalone catalog + Sous-chef cooking mode, local-only. **Phase 1.5**: optional auto-generated nutritional label (§2e) and the AI-assisted import engine (§2f) — designed-for now, built later. **Phase 2** (future, not yet specced): social layer — sharing, comments, following — which is why recipes already carry `createdBy` and use UUIDs.

**Who it's for.** Home cooks who want their recipes in one tidy, good-looking place and a clean helper while actually cooking.

**Design principles**
- **Food-forward.** Photography and color carry the warmth. When a recipe has no image, a deterministic color from a curated palette (seeded by recipe id/title) stands in — these should look intentional, not broken.
- **Calm hierarchy.** Generous whitespace, clear typographic levels, one primary action per screen.
- **Bilingual by design.** Every label exists in FR and EN; nothing should break when a French label is ~20% longer than its English twin. Recipe *content* is never translated — only the UI chrome.
- **Lean when cooking.** The full recipe page is rich; Sous-chef mode is stripped, legible at arm's length, and glanceable.
- **Modern but not fussy.** Up to par with high-end consumer apps; rounded, soft shadows, restraint. No skeuomorphic kitsch.

**Visual direction (starting point, not a cage).** Warm, appetizing palette — the seed tags already lean terracotta/orange/green/gold; the app chrome can echo that. A friendly-but-legible type pairing (a characterful display face for titles, a clean neutral for body). Large tap targets. Think "well-art-directed cookbook meets a tidy utility app."

**Navigation skeleton**
- Bottom tab bar: **Accueil / Recherche / Liste d'épicerie / Réglages** (Home / Search / Shopping list / Settings).
- A floating **"+"** button for adding a recipe (present on Home; your call whether it floats elsewhere). It opens a small **method chooser** — Manuellement / lien / photo / texte (Manuellement first); all paths land on the same Add/Edit screen. The non-manual paths are the §2f import engine (Phase 1.5); in Phase 1 the "+" goes straight to manual add.
- **Favorites** are surfaced on Home, not a separate tab.

**Screen inventory.** Home · Filtered list · Recipe description page · Sous-chef mode (2 swipeable panes) · Add/Edit (sectioned flow) · Shopping list · Search · Settings.

---

## 2. Global Schema

All ids are UUIDs. Dates are ISO 8601. Image fields are local filenames (or `null`). This matches `facebouffe-seed.json`. *(Phase 1.5 adds optional nutrition fields to `Recipe`/`Ingredient` plus an `IngredientAliases` store — see §2e; absent in Phase 1 data.)*

```
Recipe {
  id              UUID
  title           string
  createdBy       string            // username; preserved on import, NOT tied to id
  dateAdded       ISO
  dateModified    ISO
  source          string | null     // attribution, e.g. "Recette de grand-maman"
  heroImage       filename | null   // null => fallback palette color
  gallery         filename[]
  description     richtext          // prose; may contain {{link:<recipeId>}} inline tokens
  servings        int               // base servings; scaling multiplies from here
  prepTimeMinutes int
  cookTimeMinutes int
  tags            tagId[]           // includes "tag-fav" when favorited
  variantGroupId  groupId | null
  links           recipeId[]        // references to OTHER dishes (≠ variants)
  ingredients     Ingredient[]
  steps           Step[]
  personal        Personal
}

Ingredient {
  quantity  number | null           // null for things like "1 pinch" handled via unit, or uncounted
  unit      enum | null             // g,kg,ml,l,tsp,tbsp,cup,oz,lb,pinch... null = countable (eggs, onions)
  name      string
  note      string?                 // "à température pièce", "optionnel", "fondu"
}

Step {
  text         string
  image        filename | null      // shows on recipe page step list ONLY; hidden in Sous-chef
  timerSeconds int | null           // null = no timer
}

Personal {
  notes      string
  rating     int                    // 0–5; 0 = unrated
  lastCooked ISO | null
  madeCount  int
}

Tag {
  id      tagId
  system  bool                      // true = built-in
  special "favorite"?               // only on the favorites tag: non-removable, non-renamable, star UI
  name    {fr, en} | string         // system tags: {fr,en}; user tags: a single string
  icon    string                    // icon identifier
  color   hex
}

VariantGroup {
  groupId   groupId
  memberIds recipeId[]              // peers; full independent copies
  baseId    recipeId                // which member represents the group in lists (reassignable)
}

Profile {
  username  string
  language  "fr" | "en"
  units     { temperature: "celsius"|"fahrenheit",
              volume: "metric"|"imperial",
              weight: "metric"|"imperial" }
  fontSize  "small" | "medium" | "large"
  tipsSeen  { sousChef, variants, shoppingAdd, pdfExport, variantChips: bool }  // see 2c
}

// App state, not in the seed file:
ShoppingItem {
  id            UUID
  name          string
  quantity      number | null
  unit          enum | null
  checked       bool
  sourceRecipeId recipeId | null    // null = manually added
}
```

**Cross-cutting rules the designer should respect**
- **Variant ≠ link.** Variants are forks of the *same dish* (swipeable via chips on the recipe page); links are references to *different dishes* (inline in prose, navigate away). Links are inserted via a recipe-link picker (search by title, up to 10 results, scrollable) — see the Add/Edit page spec.
- **Scaling.** A servings stepper on the recipe page recomputes all ingredient quantities from `servings`. Display friendly fractions (¾ cup, not 0.75). Same-dimension unit conversion only.
- **Fallback color.** `heroImage: null` → deterministic palette color seeded by id/title.
- **Favorites** = the special `tag-fav`; toggled by a star, listed on Home.
- **Temperatures** in free text are inline `{{temp:value:unit}}` tokens, auto-detected as the user types, converted on display per `Profile.units.temperature`. See 2a.

---

## 2a. Temperatures in Free Text

Temperatures live inside free-form text (`step.text` and `description`), unlike volumes/weights which are structured ingredient fields. They're handled as a **second inline token type** alongside `{{link:id}}`, using the same parse-and-render machinery.

**Storage token.** `{{temp:<value>:<unit>}}` where `unit` is `c` or `f`, e.g. `{{temp:180:c}}`. The token stores the **value and unit the cook authored** — never a single canonical value — so round-trips don't accumulate rounding error. Conversion happens only at display time.

**Capture — fully automatic, no tagging gesture.** As the user types in the editor, scan for *number immediately followed by an explicit unit marker* — `°C`, `°F`, `℃`, `℉` (case-insensitive). Each match becomes a temperature token automatically; the user does nothing extra. In the editor, a detected temperature gets a **subtle highlight/underline** so the user can see it was recognized.
- **Explicit unit required.** A bare `°`, or words like "degrés"/"degrees" with no `C`/`F`, are **ambiguous → left as literal text, not converted.** This keeps false positives near zero. There is no manual "mark as temperature" action; if detection misses, the user simply edits the text to add the unit (the pills below make that trivial).
- Non-numeric heat language ("à température pièce", "feu moyen-vif") has no number, so it's never touched.

**Convenience pills (typing aid).** The step/description editor toolbar offers two insert buttons, **`°C`** and **`°F`**, that insert that literal string at the cursor. Their job is purely ergonomic — typing degree symbols on a phone is painful — but they double as a correctness nudge, since inserting `°C`/`°F` guarantees the marker the auto-detector needs. They do **not** tag a selection; they just type characters.

**Display.** In all read/render surfaces (recipe description page, Sous-chef), a token renders as an inline chip showing the value in the user's chosen unit:
- Authored unit **==** setting → show as authored (`{{temp:180:c}}` with Celsius setting → "180 °C").
- Authored unit **≠** setting → convert, then **round to the nearest 5°** in the target unit (e.g. 180 °C → 355 °F). *Known/accepted behavior:* nearest-5 can differ slightly from conventional oven-dial numbers (355 °F vs. the dial's 350) — this is intentional, not a bug.
- A recipe may contain a mix of `c` and `f` tokens; each converts independently.

**Designer-facing summary.** Rich-text fields host two inline chip types — link chips (`{{link:id}}`, tappable, navigate away) and temperature chips (`{{temp:v:u}}`, non-interactive, display-converted). Editor adds two toolbar buttons (`°C`, `°F`) and a subtle recognized-temperature highlight. No modal, no per-number tagging UI.

---

## 2b. Motion & Transitions

Tasteful motion raises perceived quality; the goal is *selective and purposeful*, not animating everything. Three guardrails govern all motion:

1. **Respect reduce-motion.** Honor the OS "reduce motion" setting (Flutter: `MediaQuery.disableAnimations` / `accessibleNavigation`). When on, replace movement-heavy transitions with a quick fade or an instant cut. This is an accessibility requirement, not polish.
2. **Transform & opacity over blur & shadow.** Slide, fade, and scale are GPU-cheap and stay at 60/120fps. Animated blur, large shadow changes, and layout-thrashing animations are expensive — avoid animating them; if unavoidable, budget and test on a real low-end device.
3. **Nothing looping in Sous-chef.** The screen is already forced awake for a long cooking session — ambient/looping motion there wastes battery and adds heat. One-shot transitions only.

**Durations & easing.** Most transitions ~200–300ms with natural easing (standard Material/Cupertino curves; avoid linear). Longer reads as waiting; linear reads as cheap.

**Platform behavior.** Lean on Flutter's default page transitions, which already adapt per platform (Cupertino slide-and-parallax on iOS, Material fade-through on Android). The engine renders identically across platforms, so consistency is free; the only inconsistency risk is hand-rolling custom transitions that ignore one platform's conventions.

**Where to spend the budget**
- **Navigation into a recipe** — platform-default push/pop.
- **Sous-chef toggle** — a deliberate transition so the mode shift (rich page → lean cooking mode) reads clearly.
- **Sous-chef two-pane swipe** — gestural; must track the finger (a `PageView`-style transition).
- **Favorite-star tap** — a small one-shot pop/scale.
- **Editor row add/remove** — animated list insert/remove (items shouldn't pop in/out abruptly).
- **Variant-chip switching** — a quick crossfade so the content change is legible.

**Where to hold back**
- Anything looping in Sous-chef (see guardrail 3).
- The **timer countdown** — update the number; do not animate digit changes frame-by-frame.
- Heavy blur/shadow transitions anywhere (e.g. don't animate the Sous-chef background dim/blur — set it, don't tween it).

---

## 2c. Help & Onboarding

**Framing.** Facebouffe is an *intermittent-use* app — people cook a few times a week and meet a given feature for the first time weeks apart. Therefore: **no upfront tutorial carousel, no mandatory full-screen tour, nothing that blocks the user from proceeding.** Help arrives at the moment of need. Three layers, cheapest first.

**Layer 1 — labels reduce the need.** Every primary control shows **icon + text label**, never icon-only: "Ajouter à la liste", "Exporter PDF", "Ajouter une variante", etc. This alone prevents most "what does this do?" questions.
- *Exception:* **"Mode sous-chef" stays as-is** — no plain-language suffix (the brand label is already long). Its explanation is carried by its first-encounter coach mark (Layer 3) instead of an inline subtitle.

**Layer 2 — empty states that teach.** Empty/first-use states double as instruction and appear exactly when relevant, with no dismissal needed. Each affected page spec carries an empty-state line. Examples:
- Empty shopping list → "Votre liste est vide. Ajoutez les ingrédients d'une recette depuis sa page." / "Your list is empty. Add a recipe's ingredients from its page."
- No favorites yet → short prompt explaining the star.
- Recipe with no variants → nothing intrusive; the "Ajouter une variante" action is self-explaining via its label.

**Layer 3 — just-in-time coach marks (one feature at a time).** The first time a user reaches a non-trivial control, show a single small spotlight/tooltip for *that one thing*, then never again. **Never a bundled tour.** Dismissible, never a trapping modal flow, fade in/out (respect reduce-motion per §2b). Features that earn a coach mark:
- **Mode sous-chef toggle** (carries the "vue simplifiée pour cuisiner" explanation).
- **Ajouter une variante** (what a variant is vs. a normal recipe).
- **Ajouter à la liste d'épicerie** (sends *scaled* ingredients to the list).
- **Exporter en PDF** (single recipe here / book from Settings).
- **Variant chips** (switching between forks of the same dish).

**Persistent fallback.** A **Help / Aide** entry in Settings: a short plain-language glossary of the app's own terms (sous-chef, variante, tag) plus a few how-tos. Low discovery, but the safety net for "I need to look it up."

**Replay.** Settings includes **"Revoir les astuces"** (reset tips) that clears all seen-flags so coach marks reappear. Important for nervous users who dismissed a tip and fear it's gone forever.

**Teach on the seed data.** The seeded donut recipe doubles as a no-stakes tutorial surface — its description can gently invite trying a feature ("Essayez : touchez Mode sous-chef…") on realistic content. No separate sandbox needed.

**Data-model addition.** Coach marks need per-feature seen-flags persisted locally, plus a global reset:
```
Profile.tipsSeen {
  sousChef:    bool,
  variants:    bool,
  shoppingAdd: bool,
  pdfExport:   bool,
  variantChips:bool
}   // "Revoir les astuces" sets all → false
```

**Bilingual note.** Every word of help copy (empty states, coach marks, glossary) exists in FR + EN — keep it short, partly for that reason.

---

## 2d. Tag Management

Two distinct jobs: **managing** tags (create/rename/delete) lives in **Settings**; **applying** tags to a recipe lives in the **Add/Edit editor**. Recall `Tag { id, system, special?, name, icon, color }` (§2).

**System vs. user tags.**
- **System tags** (Déjeuner, Dessert, Soupe…) and the special `tag-fav`: **not editable or deletable.** Their bilingual `{fr,en}` names and default icons/colors are fixed. Settings may list them read-only, or omit them.
- **User tags** (e.g. Hi-protéine): single-string name, fully managed by the user.

**Managing (Settings → "Tags personnalisés").** Lists user tags only, each with rename + delete.
- **Auto appearance on creation.** A new user tag is auto-assigned a palette color and a sensible default icon — the user is **not** required to configure appearance. Changing icon/color afterward is *optional*, not a creation step. (Lowest friction for novices.)
- **Delete = drop relationship, never destroy recipes.** Deleting a user tag removes it from any recipes carrying it; the recipes are untouched. Confirmation states the count: *"Supprimer 'Hi-protéine'? Ce tag sera retiré de 3 recettes."*
- **Rename is the single source of truth.** Renaming here propagates everywhere the tag appears. The editor never renames — it only toggles on/off.
- **Duplicates.** Tag names are matched **case-insensitively**; attempting a near-duplicate ("végé" vs "Végé") warns *"Ce tag existe déjà"* rather than silently creating a second tag.

**Applying (Add/Edit → Infos section).** The tag control sits **below the hero image, above the title**, mirroring the recipe page's tag placement so the layouts rhyme.
- **Selected tags first**, as colored pills (the answer to "what's on this recipe now").
- **Below them, unselected tags** as grayed pills; tapping a pill toggles it. Colored = on, grayed = off.
- **"+ tag" affordance** opens the **same searchable picker pattern as the recipe-link picker** (search by name, scrollable list) — the scale valve when the tag list is long, and a familiar interaction the user has already met.
- **Inline creation is allowed** from that picker: if the search yields no match, offer *"Aucun résultat — créer 'Végé'?"*. A tag born here gets the same auto color/icon treatment, and the case-insensitive duplicate warning applies.
- **The favorite star is NOT a pill here.** It stays its own distinct control on the recipe page header; `tag-fav` never renders in the editor pill row (avoids two ways to do one thing).

**Designer-facing summary.** Editor tag row = colored selected pills + grayed unselected pills (tap to toggle) + a "+ tag" button opening the search picker with inline-create. Settings tag manager = list of user tags with rename/delete, delete shows affected-recipe count, creation auto-assigns color/icon. Star excluded from both pill contexts.

---

## 2e. Nutritional Label — **Phase 1.5 (designed-for, built later)**

> **Scope flag.** This is *not* part of the Phase 1 build. It is documented now so the data model and editor leave room for it, but it's a substantial, near-standalone component deferred to **Phase 1.5**. Phase 1 ships without it. (Roadmap context: Phase 1 = standalone catalog/cooking app — *complete*; Phase 1.5 = auto nutrition; Phase 2 = social — sharing, comments, following — a separate brainstorming effort.)

**Goal.** During recipe create/edit (on the **Ingrédients** section), optionally auto-generate an estimated nutrition label, shown per serving + total.

**Data source — local Canadian Nutrient File (CNF).** Bundle Health Canada's CNF locally rather than calling an online API. Rationale, tied to the app's DNA: it's **bilingual FR/EN** (matches French ingredient names with no translate step), **offline** (consistent with local-first; the label persists on the recipe and shows without a network), **free, no rate limits, no attribution/caching restrictions**, and **Canadian-relevant**. (A commercial API like Edamam is a fine *prototype* or fallback-for-misses, but its terms forbid storing results — at odds with persisting a label locally — so CNF is the foundation.)

**The label is an estimate.** Always framed and labeled as an *estimation*, never a regulatory Nutrition Facts panel. Important for trust and for anyone with allergies/medical diets — do not imply CFIA-grade accuracy.

**Ingredient matching (the hard part) + correction UX.**
- Each ingredient is auto-matched to a CNF food. Resolution order: **alias table first** (learned defaults, below) → **CNF fuzzy match** fallback.
- Show the match inline and make it **correctable** ("beurre → Beurre, salé ✎"). Unmatched ingredients are flagged, not silently dropped.
- Each ingredient carries an **include-in-calc** toggle. Default-off for things you don't eat — the canonical case is the **1.5 L frying oil** in the donut recipe, plus "sel au goût"/pinch items.
- **Density / volume→weight** (e.g. "2 cups flour" → grams) leans on CNF's household-measure entries; this is the same volume↔weight problem deliberately excluded from §2-unit conversion, reappearing here and handled via CNF measures.

**Learned alias table (quality-of-life, CNF-path only).** A recipe-independent local store mapping a normalized ingredient name → preferred CNF food, so a correction made once becomes the default thereafter.
- **Going-forward only.** Correcting "beurre" sets the default for *future* matches; it does **not** retroactively rewrite recipes already finalized (same principle as variant "full copy, no retroactive inheritance" — consistent mental model). Past rows keep their resolved match unless the user re-opens and re-matches.
- **Override-able.** An alias is a remembered default, always overridable per row; the full table is viewable/editable in **Settings**, as a sibling to "Tags personnalisés" ("Aliases d'ingrédients").
- **Normalized keys.** Lowercased + trimmed, so "Beurre", "beurre", "beurre " collapse to one alias (same case-insensitive instinct as tag de-duplication).
- This learning behavior is itself Phase 1.5 scope; the per-row `nutritionRef` alone is enough to ship a working label, with the alias layer as the upgrade on top.

**Where it surfaces (all Phase 1.5).** Ingredients section of Add/Edit (matching + correction + per-ingredient include toggle + "générer l'étiquette"); the recipe description page (display the saved label); optionally the PDF export; Settings (the alias table editor). A coach mark would join the §2c set when introduced.

### Phase 1.5 schema additions (optional fields; absent in Phase 1 data)
```
Ingredient (+) {
  nutritionRef {                 // per-row resolved match, persisted
    foodCode      string         // CNF food code
    matchedName   string         // e.g. "Beurre, salé"
    confidence    number         // 0–1, matcher certainty (drives "check this" hints)
    includeInCalc bool           // false = excluded (frying oil, "sel au goût"…)
  } | null
}

Recipe (+) {
  nutrition {                    // computed once, stored on the recipe
    perServing   { calories, protein, fat, carbs, sodium, … }
    total        { … }
    isEstimate   bool            // always true; surfaced in UI
    hasUnmatched bool            // ≥1 ingredient unmatched or excluded
    computedAt   ISO
  } | null
}

// New top-level local store, recipe-independent:
IngredientAliases {              // learned defaults: normalized name → preferred CNF food
  "<normalized name>": { foodCode, matchedName }
  // e.g. "beurre": { "foodCode": "…", "matchedName": "Beurre, salé" }
  // keys lowercased+trimmed · editable in Settings · going-forward only · CNF-path only
}
```

---

## 2f. Import Engine — **Phase 1.5 / 2 (designed-for, built later)**

> **Scope flag.** Not part of the Phase 1 build. Tier 0 (below) already exists as a standalone script; the AI tiers are a deferred "magic import" upgrade. Documented here so the data model, the add/edit flow, and Settings leave room for it.

**Goal.** Reduce friction when adding a recipe by turning text, a web page, a screenshot, or a photo into a draft Facebouffe recipe — without Anthropic-style central API costs falling on the developer.

**Hard constraint that shapes everything: subscription ≠ API.** Do **not** build on "drive the user's Claude/ChatGPT/Gemini *subscription* from the app." As of 2026 this is disallowed (Anthropic prohibits subscription OAuth tokens in third-party tools with billing enforcement; Google did the same for Gemini CLI; OpenAI's "Sign in with ChatGPT" is Codex-scoped and is identity, not plan-API access). The workable equivalent is the user's own **API key** (BYOK), which is permitted because keys are meant for programmatic use.

**Tiered backends (one `RecipeImporter` interface, pluggable; user picks default in Settings).**
- **Tier 0 — Structured parse, no AI (free; exists).** For URLs, parse the page's schema.org/Recipe JSON-LD (the Ricardo converter). Always tried first for web input — zero cost, zero hallucination.
- **Tier 1 — On-device, free to the developer.** On-device OCR (Apple Vision / Android ML Kit Text Recognition — free, local, no network) turns a photo/screenshot into text; an on-device small LLM (Apple Foundation Models / Android Gemini Nano, both free, with schema-guided structured output and French support) turns text into the Facebouffe schema. Caveat: small models — strong on clean text/web, more variable on messy photos/handwriting; gated to capable devices. Good free default for "snap a recipe."
- **Tier 2 — BYOK cloud LLM (best quality; the *user* pays pennies).** User pastes their own provider key (Anthropic/OpenAI/Google); the app sends input (text, HTML, or image as base64) + the schema + a strict prompt and gets JSON. Handles the hardest multimodal cases. "Sign in with ChatGPT" is a friendlier on-ramp (grants prepaid API credits) but is BYOK-equivalent, not subscription drive-through.

**Cost model.** $0 to the developer by default (Tiers 0–1); Tier 2 is opt-in and billed to the user's own account. Fits the local-first, user-controlled ethos.

**Non-negotiable rules for any AI tier.**
- **Never auto-commit — validate, then review.** LLMs hallucinate quantities, invent out-of-enum units, mis-split ingredients. Validate returned JSON against the schema (unit ∈ enum, quantity numeric, required fields), then **land the user on the sectioned Add/Edit screen to confirm before saving.** The importer fills the form; the human approves it — same "AI assists, user confirms" principle as nutrition matching (§2e).
- **Schema + seed = the prompt.** Give the model the schema and one seed recipe as a few-shot example; instruct it to emit Facebouffe conventions directly — structured `{quantity, unit, name, note}`, `{{temp:v:u}}` and `{{link:id}}` tokens — and to **preserve the source language** (no translation, matching the UI-bilingual / content-not-translated rule). Use guided/structured-output modes where available.
- **Key security & privacy (Tier 2).** Store the key in Keychain/Keystore, never log it, send it only to the provider, allow revoke/delete. Disclose plainly that Tier 2 sends recipe content (and images) to a third party under the user's own account, while Tiers 0–1 stay on-device.

**Where it surfaces — action vs. configuration are separate, and live in different places.**
Import is not one component; it's an *action* (bring a recipe in now) and a *configuration* (which backend, the key, privacy). Splitting them keeps it simple.
- **Action → the "+" method chooser.** "+" no longer opens a blank form directly; it opens a small chooser — **Manuellement · À partir d'un lien · À partir d'une photo · À partir de texte** — with *Manuellement listed first* (thumb-reflex for the common case). All four paths funnel into the **same sectioned Add/Edit review screen**. Import isn't a feature parallel to "add a recipe"; it *is* adding a recipe with a different starting point. Output always opens the editor for review — never a silent save.
- **Configuration → Settings, "Importation" group.** Backend choice (rule-based only / on-device / your own key), the BYOK key field, and the privacy note live here beside "Tags personnalisés" — where setup belongs and where the tier/key complexity stays out of the way 99% of the time.
- **Bonus, lowest-friction path → OS share-sheet target ("Partager vers Facebouffe").** Share a URL from the browser or an image from Photos straight into the app; both land on the same review screen. No button, no tab — the user is already looking at the recipe and just shares it over. Complements the "+", doesn't replace it. **(Phase 1.5, designed-for.)**
- **Not a bottom tab.** The tab bar is for destinations you return to; import is an occasional action and doesn't earn that real estate (and would crowd the bar with long FR labels). And the *action* never lives in Settings — Settings configures, it doesn't do.

Also surfaces in the Ingredients section of Add/Edit when the imported draft is reviewed (the structured ingredients/steps the model produced are editable like any other).

---

## 3. Per-Page Specs

Each block: **Purpose · Reads/Writes · Key UI · States & edges · Mockup seed.** Paste one block at a time. *(All Phase 1 unless noted; nutrition is Phase 1.5 — see §2e.)*

### Page — Recipe Description (the full page)
- **Purpose.** The complete recipe as in a cookbook: read top-to-bottom by scrolling. *No left-right swipe here.*
- **Reads.** Full `Recipe`; `VariantGroup` (for chips); resolved `Tag`s; linked recipe titles for `{{link:id}}` tokens.
- **Writes.** Favorite star (toggles `tag-fav`); servings scale (session state); "Ajouter à la liste" pushes scaled ingredients to shopping list.
- **Key UI.** Hero image (or fallback color), then a **tag row** (colored pills, below image / above title — mirrored by the editor, see §2d), then title/source. **Variant chips** near the top ("Frits · Au four") when `variantGroupId` is set. **Favorite star.** **Servings stepper.** Prep/cook time + rating. Sections in order: **prose description** (with inline link chips) → **ingredients** (structured, scaled) → **step-by-step** (numbered; a step may show its own image; timer indicated) → **gallery**. Actions: **Mode sous-chef** toggle, **Ajouter une variante**, **Ajouter à la liste d'épicerie**, **Exporter en PDF** (single recipe), edit.
- **States & edges.** No hero image → palette color. No variants → no chips. Long FR labels. Some steps have images, most don't. A linked recipe should look tappable inline. **First-use coach marks** (§2c) fire here on first encounter: Mode sous-chef, Ajouter une variante, Ajouter à la liste, Exporter PDF, variant chips — one at a time, never bundled.
- **Mockup seed.** "Render the description page for the fried donuts (`rec-beignes-frits`): hero image, a tag row of colored pills (Dessert, ★) below it, variant chips (Frits/Au four), favorite star active, servings stepper at 12, prose with an inline link to the maple glaze, structured ingredients, numbered steps with one step photo and timer badges, gallery, and the action row including the Sous-chef toggle."

### Page — Sous-Chef Mode
- **Purpose.** Lean cooking helper. Two panes, **swipe left-right between them**: **Ingredients** and **Step-by-step**. Each should fit one screen where possible.
- **Reads.** `Recipe.ingredients` (scaled), `Recipe.steps` (text + timers only — **no step images here**), `heroImage`/fallback for dimmed background, `Profile.fontSize`.
- **Writes.** Starts/cancels timers; keeps screen awake (indicate the awake state subtly).
- **Key UI.** Dimmed hero (or fallback) background for legibility. Pane indicator (2 dots). Big readable type sized by `fontSize` setting. Tappable timer on relevant steps. A persistent **running-timers overlay/tray** visible across both panes, each timer labeled by its step. Exit back to the full page.
- **States & edges.** No image → dimmed palette color. Multiple concurrent timers (design the tray for 2–3). Backgrounding fires a notification (timers are scheduled notifications, not a guaranteed live countdown — the tray reflects this). On first entry, a one-time coach mark explains what Sous-chef mode is (§2c).
- **Mockup seed.** "Sous-chef mode for the pea soup (`rec-soupe-pois`, no hero image → dimmed palette background): show the Step-by-step pane with large type, the 2-dot pane indicator, a step with a long simmer timer running, and a running-timers tray pinned above the panes."

### Page — Home (Accueil)
- **Purpose.** Entry point and browse-by-tag hub.
- **Reads.** All `Tag`s (icon+color buttons); favorited recipes (`tag-fav`); maybe recently cooked (`personal.lastCooked`).
- **Key UI.** Grid/row of **tag buttons** (icon + color, bilingual label) that open a filtered list. A **Favoris** section (cards/carousel). Optional "récemment cuisinés." Floating **"+"** (Phase 1: opens manual Add/Edit directly; Phase 1.5: opens the method chooser — Manuellement / lien / photo / texte, see §2f). Bottom tab bar.
- **States & edges.** First launch with seed data populated. A user-created tag (hi-protein) sits alongside system tags. **Empty favorites → a short teaching prompt** explaining the star (§2c), not a blank gap.
- **Mockup seed.** "Home screen: a colorful grid of tag buttons (Déjeuner, Souper, Dessert, Soupe, Salade, Hi-protéine…), a Favoris carousel showing the 3 favorited recipes, a floating + button, and the 4-item bottom tab bar."

### Page — Add / Edit Recipe (sectioned flow)
- **Purpose.** Create or edit a recipe. The most complex screen — a **sectioned flow** with easy navigation between sections, not one endless scroll. It is also the **shared review destination for every import path** (§2f): manual, from link, photo, text, or share-sheet all land here pre-filled for the user to confirm before saving — imports never auto-commit.
- **Reads/Writes.** Builds/edits a full `Recipe`.
- **Sections.** (1) **Infos** — hero image (with **camera capture**), then the **tag row** (below image / above title, see §2d), then title, source, servings, prep/cook time. (2) **Ingrédients** — structured rows `{quantity, unit, name, note}`, add/reorder/delete. (3) **Étapes** — rows with text, optional timer, optional photo, add/reorder/delete. Text editor here auto-detects temperatures and offers **`°C` / `°F` insert pills** in its toolbar (see 2a). (4) **Description** — prose + insert-link-to-recipe + gallery; same temperature auto-detect + pills. A section nav (stepper, tabs, or a side index) lets the user jump around freely.
- **Tag row (Infos).** Colored selected pills + grayed unselected pills (tap to toggle), plus a **"+ tag"** button opening the search picker with **inline create** (§2d). Settings is where tags are renamed/deleted; the editor only toggles and creates.
- **States & edges.** Adding an ingredient row vs. a step row should feel quick and repeatable. Unit picker reflects the dimension. Validation (title + ≥1 ingredient). Editing an existing recipe pre-fills everything. A recognized temperature shows a subtle highlight in the editor.
- **Recipe-link picker.** "Insert link to recipe" (in the Description editor) opens a picker to choose the target. It has a **search bar that filters by recipe title only** and a list of candidate recipes showing **up to 10 at a time**; if more match, the list **scrolls** (scroll gesture enabled). With an **empty query, the list defaults to the 10 most-recently-modified recipes** (by `dateModified`). Selecting one inserts a `{{link:id}}` token at the cursor. (The current recipe should not link to itself — exclude it from the list.)
- **Mockup seed.** "Add/Edit recipe, sectioned: (a) the **Infos** section showing the tag row below the image (colored selected pills + grayed unselected pills + a '+ tag' button) above the title field; and (b) the **Ingrédients** section mid-edit with three structured rows (quantity / unit picker / name / optional note) and an 'add ingredient' affordance."

### Page — Shopping List (Liste d'épicerie)
- **Purpose.** Aggregated grocery list built from recipes (scaled) plus manual items.
- **Reads/Writes.** `ShoppingItem[]`; check-off toggles `checked`; manual add; clear checked/all.
- **Key UI.** Grouped, checkable rows. Items merge by matching name + compatible unit (convert within a dimension; otherwise list separately). Show source recipe subtly. Manual "+" for non-recipe items (e.g. essuie-tout).
- **States & edges.** **Empty state teaches** (§2c): "Votre liste est vide. Ajoutez les ingrédients d'une recette depuis sa page." Unmergeable duplicates shown as separate lines ("1 oignon" vs "½ cup oignon haché"). Mixed checked/unchecked.
- **Mockup seed.** "Shopping list with items aggregated from the chili and crêpes (scaled), a couple checked off, one manually added item, grouped sensibly, with source-recipe hints."

### Page — Search (Recherche)
- **Purpose.** Find recipes by text and by ingredient.
- **Reads.** All recipes (search `title` + description + `ingredients.name`); tags as filter chips.
- **Key UI.** Search field (titles & text). **Ingredient filter:** preset buttons for common ingredients + free text. Tag filter chips. Results as recipe cards; a base recipe shows once with a **variants badge**.
- **States & edges.** No results. Multiple active filters. Variant-base dedup in results.
- **Mockup seed.** "Search screen: query field, a row of preset ingredient filter buttons plus tag chips, and a results list of recipe cards — include the donut base card showing a 'variantes' badge."

### Page — Settings (Réglages)
- **Purpose.** Configure profile, language, units, font size; load/save the recipe book and PDF export.
- **Reads/Writes.** `Profile`; triggers **Charger un livre** (load a JSON book) / **Sauvegarder un livre** (save book as JSON) / **Exporter en PDF** (book, with recipe selection).
- **Key UI.** **Nom d'utilisateur.** **Langue** (FR/EN, default OS). **Unités** — three independent toggles: température (°C/°F), volume (métrique/impérial), poids (métrique/impérial). **Taille de police** (small/medium/large). **Tags personnalisés** — manage user tags: create (auto color/icon), rename, delete (with affected-recipe count); system tags read-only/omitted (see §2d). **Importation** (Phase 1.5, §2f) — import-backend choice (rule-based only / on-device / your own key), the BYOK key field, and the privacy note; this is *configuration* only, the import *action* lives on the "+". **Aide** — glossary + how-tos (§2c). **Revoir les astuces** — resets all `tipsSeen` flags so coach marks reappear. **Charger un livre** (load a JSON book — merge-by-id). **Sauvegarder un livre** (save the whole book as JSON — backup). **Exporter en PDF** (book → prompts for recipe selection, renders in current language + units).
- **States & edges.** Load (JSON book) conflict/merge messaging. PDF selection sheet. Long bilingual labels. "Revoir les astuces" gives brief confirmation feedback. Tag delete confirms with count; duplicate tag name warns "ce tag existe déjà".
- **Mockup seed.** "Settings screen: username field, language toggle, three separate unit toggles (temperature/volume/weight), font-size selector, and a Charger / Sauvegarder un livre (load/save) section plus Exporter en PDF."

---

*Seed data: `facebouffe-seed.json` — 7 recipes including a variant group (donuts), an inter-recipe link (maple glaze), mixed units, timers, a per-step image, favorites, temperature tokens (`{{temp:180:c}}`, `{{temp:190:c}}`), and several image-less recipes to exercise the fallback palette.*
