/* fb-screens-home.jsx — Home, Search, Filtered list + shared screen chrome. */

// ── Shared screen chrome ──────────────────────────────────────
function ScreenScroll({ children, padBottom = 96 }) {
  const app = useApp();
  return (
    <div className="fb-scroll" style={{
      height: "100%", overflowY: "auto", overflowX: "hidden",
      WebkitOverflowScrolling: "touch", paddingBottom: padBottom + app.insets.bottom,
    }}>{children}</div>
  );
}

function StickyHeader({ children, blur = true }) {
  const th = useTheme();
  const app = useApp();
  return (
    <div style={{
      position: "sticky", top: 0, zIndex: 30, paddingTop: app.insets.top,
      background: blur ? th.glass : th.canvas,
      backdropFilter: blur ? "blur(16px) saturate(160%)" : "none",
      WebkitBackdropFilter: blur ? "blur(16px) saturate(160%)" : "none",
      borderBottom: `1px solid ${th.line}`,
    }}>{children}</div>
  );
}

function SectionLabel({ children, action, onAction }) {
  const th = useTheme();
  return (
    <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", padding: "0 20px", marginBottom: 12 }}>
      <h2 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(21), fontWeight: 600, color: th.ink, letterSpacing: 0.2 }}>{children}</h2>
      {action && (
        <button onClick={onAction} style={{ border: "none", background: "none", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600, color: th.accent, padding: 0 }}>{action}</button>
      )}
    </div>
  );
}

function HScroll({ children }) {
  return (
    <div className="fb-hscroll" style={{ display: "flex", gap: 14, overflowX: "auto", padding: "0 20px 4px", scrollSnapType: "x mandatory" }}>
      {React.Children.map(children, (c) => <div style={{ scrollSnapAlign: "start" }}>{c}</div>)}
    </div>
  );
}

// ── Brand wordmark — switchable titlebar lockups ──────────────
// The bowl logo is paired with five typographic treatments.
const LOGO_AR = 822 / 696; // intrinsic width / height

function BowlLogo({ h }) {
  const th = useTheme();
  return (
    <img src="facebouffe-logo.png" alt="" aria-hidden="true" style={{
      height: h, width: h * LOGO_AR, objectFit: "contain", flexShrink: 0, display: "block",
      filter: th.dark ? "saturate(1.05)" : "drop-shadow(0 2px 6px rgba(192,86,59,0.26))",
    }} />
  );
}

function HomeWordmark() {
  const th = useTheme();
  const app = useApp();
  const title = app.t("home_title");
  const greeting = app.t("home_greeting");

  const Greeting = ({ size = 13.5, caps = false, mt = 4 }) => (
    <div style={{
      fontFamily: th.fontUI, fontSize: th.fs(size), fontWeight: 600, color: th.inkSoft,
      letterSpacing: caps ? 1.4 : 0.2, textTransform: caps ? "uppercase" : "none", marginTop: mt,
    }}>{greeting}</div>
  );

  // Bistro: heavy condensed-feel grotesk, tight tracking
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, minWidth: 0 }}>
      <BowlLogo h={44} />
      <div style={{ minWidth: 0 }}>
        <div style={{ fontFamily: '"Bricolage Grotesque", "Hanken Grotesk", sans-serif', fontSize: th.fs(33), fontWeight: 800, color: th.accent, lineHeight: 0.94, letterSpacing: -0.6 }}>{title}</div>
        <Greeting size={12.5} mt={5} />
      </div>
    </div>
  );
}

// ── Home ──────────────────────────────────────────────────────
function HomeScreen() {
  const th = useTheme();
  const app = useApp();
  const { recipes, tagsById, lang, t, nav, isFav } = app;

  const favs = recipes.filter(isFav);
  const recent = recipes.filter((r) => r.personal.lastCooked)
    .sort((a, b) => new Date(b.personal.lastCooked) - new Date(a.personal.lastCooked));
  // De-duplicate variant peers in the "all" list — show only the group's base.
  const all = recipes.filter((r) => {
    if (!r.variantGroupId) return true;
    const g = app.getVariantGroup(r.variantGroupId);
    return !g || g.baseId === r.id;
  });
  const browseTags = app.tags.filter((tg) => tg.special !== "favorite");

  return (
    <ScreenScroll>
      <StickyHeader>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 20px 12px" }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <HomeWordmark />
          </div>
          <button onClick={() => nav.switchTab("settings")} style={{ marginLeft: 12, flexShrink: 0, width: 42, height: 42, borderRadius: 999, border: `1px solid ${th.line}`, background: th.card, cursor: "pointer", display: "grid", placeItems: "center", boxShadow: th.shadow, fontFamily: th.fontDisplay, fontSize: th.fs(18), color: th.accent, fontWeight: 600 }}>
            {(app.username || "?")[0].toUpperCase()}
          </button>
        </div>
      </StickyHeader>

      {/* Category browse hub — colorful tag tiles */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, padding: "16px 20px 4px" }}>
        {browseTags.map((tg) => {
          const r = parseInt(tg.color.slice(1, 3), 16), g = parseInt(tg.color.slice(3, 5), 16), b = parseInt(tg.color.slice(5, 7), 16);
          const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
          const ink = lum > 0.62 ? "#3a2a12" : "#fff";
          const chipBg = lum > 0.62 ? "rgba(0,0,0,0.12)" : "rgba(255,255,255,0.25)";
          return (
            <button key={tg.id} onClick={() => nav.go("filter", { tagId: tg.id })} style={{
              display: "flex", alignItems: "center", gap: 11, border: "none", cursor: "pointer",
              background: tg.color, borderRadius: 16, padding: "13px 14px", textAlign: "left",
              boxShadow: th.dark ? "none" : "0 6px 15px " + tg.color + "40",
            }}>
              <span style={{ width: 34, height: 34, borderRadius: 10, background: chipBg, display: "grid", placeItems: "center", flexShrink: 0 }}>
                <Icon name={tg.icon} size={19} color={ink} stroke={2.2} />
              </span>
              <span style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 700, color: ink, letterSpacing: 0.2, lineHeight: 1.1 }}>{FB.tagName(tg, lang)}</span>
            </button>
          );
        })}
      </div>

      {/* Favorites */}
      {favs.length > 0 ? (
        <div style={{ marginTop: 26 }}>
          <SectionLabel>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}>
              <Icon name="star" size={th.fs(18)} fill color={th.gold} /> {t("sec_favorites")}
            </span>
          </SectionLabel>
          <HScroll>
            {favs.map((r) => <MiniCard key={r.id} recipe={r} tagsById={tagsById} lang={lang} isFav onOpen={() => nav.openRecipe(r.id)} />)}
          </HScroll>
        </div>
      ) : (
        <div style={{ marginTop: 26 }}>
          <SectionLabel>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}>
              <Icon name="star" size={th.fs(18)} fill color={th.gold} /> {t("sec_favorites")}
            </span>
          </SectionLabel>
          <div style={{ margin: "0 20px", display: "flex", gap: 12, alignItems: "center", background: th.card, border: `1px dashed ${th.lineStrong}`, borderRadius: 18, padding: "16px 18px" }}>
            <Icon name="star" size={th.fs(22)} color={th.gold} />
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), lineHeight: 1.45, color: th.inkSoft }}>{t("fav_empty")}</div>
          </div>
        </div>
      )}

      {/* Recently cooked */}
      {recent.length > 0 && (
        <div style={{ marginTop: 28 }}>
          <SectionLabel>{t("sec_recent")}</SectionLabel>
          <HScroll>
            {recent.map((r) => <MiniCard key={r.id} recipe={r} tagsById={tagsById} lang={lang} isFav={isFav(r)} onOpen={() => nav.openRecipe(r.id)} />)}
          </HScroll>
        </div>
      )}

      {/* All recipes */}
      <div style={{ marginTop: 30 }}>
        <SectionLabel action={t("filter_all") + " →"} onAction={() => nav.go("search")}>{t("sec_all")}</SectionLabel>
        {app.homeLayout === "grid" ? (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, padding: "0 20px" }}>
            {all.map((r) => <MiniCard key={r.id} recipe={r} tagsById={tagsById} lang={lang} isFav={isFav(r)} onOpen={() => nav.openRecipe(r.id)} width="100%" />)}
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 18, padding: "0 20px" }}>
            {all.map((r) => <FeatureCard key={r.id} recipe={r} tagsById={tagsById} lang={lang} isFav={isFav(r)} onOpen={() => nav.openRecipe(r.id)} />)}
          </div>
        )}
      </div>
    </ScreenScroll>
  );
}

// ── Search ────────────────────────────────────────────────────
const PRESET_INGREDIENTS = ["farine", "oeufs", "lait", "beurre", "sucre", "oignon", "boeuf haché"];

function SearchScreen() {
  const th = useTheme();
  const app = useApp();
  const { recipes, tagsById, lang, t, nav, isFav } = app;
  const [q, setQ] = React.useState("");
  const [activeTag, setActiveTag] = React.useState(null);
  const [ingFilter, setIngFilter] = React.useState([]);
  const browseTags = app.tags;
  const toggleIng = (ing) => setIngFilter((f) => (f.includes(ing) ? f.filter((x) => x !== ing) : [...f, ing]));

  const matches = recipes.filter((r) => {
    // variant-base dedup: a group shows once via its base
    if (r.variantGroupId) { const g = app.getVariantGroup(r.variantGroupId); if (g && g.baseId !== r.id) return false; }
    if (activeTag === "tag-fav" && !isFav(r)) return false;
    if (activeTag && activeTag !== "tag-fav" && !(r.tags || []).includes(activeTag)) return false;
    for (const ing of ingFilter) { if (!r.ingredients.some((x) => x.name.toLowerCase().includes(ing))) return false; }
    if (!q.trim()) return true;
    const hay = (r.title + " " + r.description + " " + r.ingredients.map((i) => i.name).join(" ")).toLowerCase();
    return hay.includes(q.trim().toLowerCase());
  });
  const vcount = (r) => { const g = r.variantGroupId ? app.getVariantGroup(r.variantGroupId) : null; return g ? g.memberIds.length : 0; };

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <StickyHeader>
        <div style={{ padding: "8px 16px 12px" }}>
          <h1 style={{ margin: "4px 4px 12px", fontFamily: th.fontDisplay, fontSize: th.fs(28), fontWeight: 600, color: th.ink }}>{t("tab_search")}</h1>
          <div style={{ display: "flex", alignItems: "center", gap: 9, background: th.card, border: `1px solid ${th.line}`, borderRadius: 14, padding: "0 12px", height: 46, boxShadow: th.shadow }}>
            <Icon name="search" size={th.fs(19)} color={th.inkFaint} />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("search_placeholder")}
              style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(16), color: th.ink, minWidth: 0 }} />
            {q && <button onClick={() => setQ("")} style={{ border: "none", background: "none", cursor: "pointer", padding: 4, lineHeight: 0 }}><Icon name="x" size={th.fs(17)} color={th.inkFaint} /></button>}
          </div>
        </div>
        <div className="fb-hscroll" style={{ display: "flex", gap: 8, overflowX: "auto", padding: "0 16px 10px" }}>
          {browseTags.map((tg) => (
            <div key={tg.id} style={{ flexShrink: 0 }}>
              <TagChip tag={tg} lang={lang} active={activeTag === tg.id} onClick={() => setActiveTag(activeTag === tg.id ? null : tg.id)} />
            </div>
          ))}
        </div>
        {/* preset ingredient filters */}
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "0 16px 12px" }}>
          <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4, flexShrink: 0 }}>{t("presets")}</span>
          <div className="fb-hscroll" style={{ display: "flex", gap: 7, overflowX: "auto" }}>
            {PRESET_INGREDIENTS.map((ing) => {
              const on = ingFilter.includes(ing);
              return (
                <button key={ing} onClick={() => toggleIng(ing)} style={{
                  flexShrink: 0, border: `1px solid ${on ? th.accent : th.line}`, background: on ? th.accent : th.card, color: on ? "#fff" : th.inkSoft,
                  borderRadius: 999, padding: "5px 12px", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600, whiteSpace: "nowrap",
                }}>{ing}</button>
              );
            })}
          </div>
        </div>
      </StickyHeader>

      <ScreenScroll padBottom={96}>
        <div style={{ padding: "14px 16px 0", display: "flex", flexDirection: "column", gap: 12 }}>
          {matches.length === 0 ? (
            <div style={{ textAlign: "center", padding: "60px 24px", color: th.inkSoft }}>
              <div style={{ width: 60, height: 60, borderRadius: 999, background: th.accentSoft, display: "grid", placeItems: "center", margin: "0 auto 16px" }}>
                <Icon name="search" size={26} color={th.accent} />
              </div>
              <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(20), color: th.ink, fontWeight: 600 }}>{t("no_results")}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14), marginTop: 6 }}>{t("search_hint")}</div>
            </div>
          ) : (
            <>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft, fontWeight: 600, paddingLeft: 4 }}>
                {matches.length} {matches.length === 1 ? t("result") : t("results")}
              </div>
              {matches.map((r) => <ListCard key={r.id} recipe={r} tagsById={tagsById} lang={lang} isFav={isFav(r)} variantCount={vcount(r)} onOpen={() => nav.openRecipe(r.id)} />)}
            </>
          )}
        </div>
      </ScreenScroll>
    </div>
  );
}

// ── Filtered list (opened from a category chip) ───────────────
function ListFilterScreen({ route }) {
  const th = useTheme();
  const app = useApp();
  const { recipes, tagsById, lang, t, nav, isFav } = app;
  const tag = app.tagsById[route.tagId];
  const matches = recipes.filter((r) => route.tagId === "tag-fav" ? isFav(r) : (r.tags || []).includes(route.tagId));

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <StickyHeader>
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px 14px" }}>
          <button onClick={() => nav.back()} style={{ width: 40, height: 40, borderRadius: 999, border: "none", background: "transparent", cursor: "pointer", display: "grid", placeItems: "center" }}>
            <Icon name="back" size={th.fs(24)} color={th.ink} />
          </button>
          <div style={{ display: "flex", alignItems: "center", gap: 9 }}>
            {tag && (
              <span style={{ width: 30, height: 30, borderRadius: 9, display: "grid", placeItems: "center", background: tag.color + "22" }}>
                <Icon name={tag.icon} size={17} color={tag.color} stroke={2.2} />
              </span>
            )}
            <h1 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(25), fontWeight: 600, color: th.ink }}>{tag ? FB.tagName(tag, lang) : ""}</h1>
          </div>
        </div>
      </StickyHeader>
      <ScreenScroll>
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft, fontWeight: 600, padding: "14px 20px 6px" }}>
          {matches.length} {matches.length === 1 ? t("result") : t("results")}
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 12, padding: "0 16px" }}>
          {matches.map((r) => <ListCard key={r.id} recipe={r} tagsById={tagsById} lang={lang} isFav={isFav(r)} onOpen={() => nav.openRecipe(r.id)} />)}
        </div>
      </ScreenScroll>
    </div>
  );
}

Object.assign(window, {
  ScreenScroll, StickyHeader, SectionLabel, HScroll,
  HomeScreen, SearchScreen, ListFilterScreen,
});
