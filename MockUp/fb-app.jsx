/* fb-app.jsx — App shell: state, navigation, device frame, tab bar, FAB, tweaks. */

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "device": "android",
  "dark": false,
  "accent": "#C0563B",
  "lang": "fr",
  "fontSize": "medium",
  "homeLayout": "editorial",
  "onDeviceAI": true,
  "tempUnit": "celsius",
  "volUnit": "metric",
  "weightUnit": "metric"
}/*EDITMODE-END*/;

const TAB_SCREENS = ["home", "search", "groceries", "settings"];
const INSETS = {
  ios: { top: 55, bottom: 24 },
  android: { top: 10, bottom: 8 },
};

function useStage(W, H) {
  const [scale, setScale] = React.useState(1);
  React.useLayoutEffect(() => {
    const fit = () => {
      const pad = 24;
      const s = Math.min((window.innerWidth - pad) / W, (window.innerHeight - pad) / H, 1.15);
      setScale(s);
    };
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, [W, H]);
  return scale;
}

function usePrefersReducedMotion() {
  const [reduce, setReduce] = React.useState(() => {
    try { return window.matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) { return false; }
  });
  React.useEffect(() => {
    let mq;
    try { mq = window.matchMedia("(prefers-reduced-motion: reduce)"); } catch (e) { return; }
    const fn = () => setReduce(mq.matches);
    mq.addEventListener ? mq.addEventListener("change", fn) : mq.addListener(fn);
    return () => { mq.removeEventListener ? mq.removeEventListener("change", fn) : mq.removeListener(fn); };
  }, []);
  return reduce;
}

function App() {
  const [tw, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const theme = React.useMemo(() => buildTheme({ dark: tw.dark, accent: tw.accent, fontSize: tw.fontSize }), [tw.dark, tw.accent, tw.fontSize]);
  const lang = tw.lang;
  const prefs = { temperature: tw.tempUnit, volume: tw.volUnit, weight: tw.weightUnit };
  const device = tw.device === "ios" ? "ios" : "android";
  const insets = INSETS[device];

  // ── data state ──
  const [recipes, setRecipes] = React.useState(() => JSON.parse(JSON.stringify(FB.SEED.recipes)));
  const [tags, setTags] = React.useState(() => JSON.parse(JSON.stringify(FB.SEED.tags)));
  const tagsById = React.useMemo(() => Object.fromEntries(tags.map((t) => [t.id, t])), [tags]);
  const [variantGroups, setVariantGroups] = React.useState(() => JSON.parse(JSON.stringify(FB.SEED.variantGroups)));
  const profile = FB.SEED.profile;
  const [username, setUsername] = React.useState(profile.username);
  const [shopping, setShopping] = React.useState([]);
  // shared per-recipe main photo store (dataURLs), persisted in localStorage
  const [recipePhotos, setRecipePhotosState] = React.useState(() => {
    try { return JSON.parse(localStorage.getItem("fb_recipe_photos") || "{}"); } catch (e) { return {}; }
  });
  const setRecipePhoto = React.useCallback((id, url) => {
    setRecipePhotosState((p) => {
      const next = { ...p };
      if (url == null) delete next[id]; else next[id] = url;
      try { localStorage.setItem("fb_recipe_photos", JSON.stringify(next)); } catch (e) {}
      return next;
    });
  }, []);
  // Phase 1.5 — learned ingredient→CNF alias table (going-forward defaults).
  const [aliases, setAliasesState] = React.useState(() => {
    try { const v = JSON.parse(localStorage.getItem("fb_aliases") || "null"); return v || { "beurre": { foodCode: "F-0142", matchedName: "Beurre, sal\u00e9" } }; } catch (e) { return {}; }
  });
  const addAlias = React.useCallback((name, foodCode) => {
    const key = FB.normalizeName(name);
    if (!key) return;
    setAliasesState((a) => { const next = { ...a, [key]: { foodCode, matchedName: FB.cnfName(foodCode, "fr") } }; try { localStorage.setItem("fb_aliases", JSON.stringify(next)); } catch (e) {} return next; });
  }, []);
  const removeAlias = React.useCallback((key) => {
    setAliasesState((a) => { const next = { ...a }; delete next[key]; try { localStorage.setItem("fb_aliases", JSON.stringify(next)); } catch (e) {} return next; });
  }, []);
  // Phase 1.5 — import engine configuration (backend tier + per-provider keys).
  const [importCfg, setImportCfgState] = React.useState(() => {
    const base = { backend: "ondevice", provider: "claude", keys: { claude: "", gemini: "", chatgpt: "" } };
    try {
      const saved = JSON.parse(localStorage.getItem("fb_import_cfg") || "{}");
      const keys = { ...base.keys, ...(saved.keys || {}) };
      if (saved.key && !keys.claude) keys.claude = saved.key; // migrate old single-key shape
      return { ...base, ...saved, keys };
    } catch (e) { return base; }
  });
  const setImportCfg = React.useCallback((patch) => {
    setImportCfgState((c) => { const next = { ...c, ...patch }; try { localStorage.setItem("fb_import_cfg", JSON.stringify(next)); } catch (e) {} return next; });
  }, []);
  const setImportKey = React.useCallback((provider, value) => {
    setImportCfgState((c) => { const next = { ...c, keys: { ...c.keys, [provider]: value } }; try { localStorage.setItem("fb_import_cfg", JSON.stringify(next)); } catch (e) {} return next; });
  }, []);
  const [importFlow, setImportFlow] = React.useState(null);
  // coach-mark seen flags (Profile.tipsSeen), persisted; reset via Settings
  const TIP_KEYS = { sousChef: false, variants: false, shoppingAdd: false, pdfExport: false, variantChips: false, customTags: false, ingredientAliases: false, importEngine: false, apiKeys: false };
  const [tipsSeen, setTipsSeen] = React.useState(() => {
    try { return { ...TIP_KEYS, ...JSON.parse(localStorage.getItem("fb_tips_seen") || "{}") }; } catch (e) { return { ...TIP_KEYS }; }
  });
  const markTipSeen = React.useCallback((k) => {
    setTipsSeen((p) => { const next = { ...p, [k]: true }; try { localStorage.setItem("fb_tips_seen", JSON.stringify(next)); } catch (e) {} return next; });
  }, []);
  const resetTips = React.useCallback(() => {
    const next = { sousChef: false, variants: false, shoppingAdd: false, pdfExport: false, variantChips: false, customTags: false, ingredientAliases: false, importEngine: false, apiKeys: false };
    setTipsSeen(next); try { localStorage.setItem("fb_tips_seen", JSON.stringify(next)); } catch (e) {}
  }, []);

  // ── navigation ──
  const [stack, setStack] = React.useState([{ screen: "home", params: {} }]);
  const [activeTab, setActiveTab] = React.useState("home");
  const current = stack[stack.length - 1];
  const scrollKey = stack.length + ":" + current.screen + ":" + (current.params.id || current.params.tagId || "");

  const nav = React.useMemo(() => ({
    go: (screen, params = {}) => setStack((s) => [...s, { screen, params }]),
    back: () => setStack((s) => (s.length > 1 ? s.slice(0, -1) : s)),
    switchTab: (tab) => { setActiveTab(tab); setStack([{ screen: tab, params: {} }]); },
    openRecipe: (id, replace) => setStack((s) => replace ? [...s.slice(0, -1), { screen: "recipe", params: { id } }] : [...s, { screen: "recipe", params: { id } }]),
    cook: (id, servings) => setStack((s) => [...s, { screen: "souschef", params: { id, servings } }]),
    edit: (id) => setStack((s) => [...s, { screen: "edit", params: { id } }]),
    add: (draft) => setStack((s) => [...s, { screen: "edit", params: draft ? { draft } : {} }]),
    home: () => { setActiveTab("home"); setStack([{ screen: "home", params: {} }]); },
  }), []);

  // ── helpers ──
  const getRecipe = React.useCallback((id) => recipes.find((r) => r.id === id), [recipes]);
  const getVariantGroup = React.useCallback((gid) => variantGroups.find((g) => g.groupId === gid), [variantGroups]);
  const isFav = React.useCallback((r) => r && (r.tags || []).includes("tag-fav"), []);
  const updateRecipe = (id, fn) => setRecipes((rs) => rs.map((r) => (r.id === id ? fn(r) : r)));
  const toggleFav = (id) => updateRecipe(id, (r) => ({ ...r, tags: isFav(r) ? r.tags.filter((t) => t !== "tag-fav") : [...r.tags, "tag-fav"] }));
  const markCooked = (id) => updateRecipe(id, (r) => ({ ...r, personal: { ...r.personal, madeCount: r.personal.madeCount + 1, lastCooked: "2026-05-28T00:00:00Z" } }));
  const deleteRecipe = (id) => setRecipes((rs) => rs.filter((r) => r.id !== id));
  const addVariant = (id) => {
    const base = recipes.find((r) => r.id === id);
    if (!base) return;
    const newId = FB.uuid();
    let gid = base.variantGroupId;
    if (gid) {
      setVariantGroups((gs) => gs.map((g) => (g.groupId === gid ? { ...g, memberIds: [...g.memberIds, newId] } : g)));
    } else {
      gid = "vg-" + FB.uuid();
      setVariantGroups((gs) => [...gs, { groupId: gid, memberIds: [id, newId], baseId: id }]);
      setRecipes((rs) => rs.map((r) => (r.id === id ? { ...r, variantGroupId: gid } : r)));
    }
    const now = new Date().toISOString();
    const copy = JSON.parse(JSON.stringify(base));
    copy.id = newId;
    copy.title = base.title + (lang === "fr" ? " (variante)" : " (variant)");
    copy.variantGroupId = gid; copy.dateAdded = now; copy.dateModified = now;
    copy.tags = (copy.tags || []).filter((t) => t !== "tag-fav");
    copy.personal = { notes: "", rating: 0, lastCooked: null, madeCount: 0 };
    copy.heroImage = null; copy.gallery = []; copy.links = [];
    setRecipes((rs) => [copy, ...rs]);
    setStack((s) => [...s, { screen: "edit", params: { id: newId } }]);
  };
  const saveRecipe = (form, existing) => {
    if (existing) { updateRecipe(existing.id, () => ({ ...form })); }
    else {
      const now = new Date().toISOString();
      const id = FB.uuid();
      setRecipes((rs) => [{ ...form, id, createdBy: username, dateAdded: now, dateModified: now, source: form.source || null, gallery: form.gallery || [], variantGroupId: form.variantGroupId || null, links: form.links || [] }, ...rs]);
      // migrate any photo dropped on the draft form to the new recipe id
      setRecipePhotosState((p) => {
        if (!p.__draft) return p;
        const next = { ...p, [id]: p.__draft };
        delete next.__draft;
        try { localStorage.setItem("fb_recipe_photos", JSON.stringify(next)); } catch (e) {}
        return next;
      });
    }
  };
  const PALETTE_TAGS = ["#C0563B", "#E0A458", "#6BA368", "#9C6B8E", "#4A7BA6", "#C58A2E", "#5B8C7E"];
  const TAG_ICONS = ["leaf", "flame", "bowl", "cake", "utensils", "sunrise", "dumbbell", "shrimp"];
  const tagDisplayNames = (tg) => (typeof tg.name === "string" ? [tg.name] : [tg.name.fr, tg.name.en]);
  const findTagByName = (name) => {
    const n = String(name || "").trim().toLowerCase();
    if (!n) return null;
    return tags.find((tg) => tagDisplayNames(tg).some((x) => x.toLowerCase() === n)) || null;
  };
  const addTag = (name) => {
    const existing = findTagByName(name);
    if (existing) return { id: existing.id, created: false };
    const id = "tag-" + FB.uuid();
    setTags((ts) => [...ts, { id, system: false, name: name.trim(), icon: TAG_ICONS[ts.length % TAG_ICONS.length], color: PALETTE_TAGS[ts.length % PALETTE_TAGS.length] }]);
    return { id, created: true };
  };
  const renameTag = (id, name) => {
    const dup = findTagByName(name);
    if (dup && dup.id !== id) return false;
    setTags((ts) => ts.map((tg) => (tg.id === id ? { ...tg, name: name.trim() } : tg)));
    return true;
  };
  const deleteTag = (id) => {
    setTags((ts) => ts.filter((tg) => tg.id !== id));
    setRecipes((rs) => rs.map((r) => ({ ...r, tags: (r.tags || []).filter((t) => t !== id) })));
  };
  const recipesWithTag = (id) => recipes.filter((r) => (r.tags || []).includes(id)).length;
  const exportData = () => ({ schemaVersion: 1, profile: { ...profile, username }, tags, variantGroups, recipes });
  const importData = (data) => {
    if (!data || !Array.isArray(data.recipes)) throw new Error("bad");
    const merge = (cur, incoming, keyFn) => {
      const map = Object.fromEntries(cur.map((x) => [keyFn(x), x]));
      incoming.forEach((x) => { map[keyFn(x)] = x; });
      return Object.values(map);
    };
    setRecipes((rs) => merge(rs, data.recipes, (r) => r.id));
    if (Array.isArray(data.tags)) setTags((ts) => merge(ts, data.tags, (x) => x.id));
    if (Array.isArray(data.variantGroups)) setVariantGroups((gs) => merge(gs, data.variantGroups, (x) => x.groupId));
    return data.recipes.length;
  };

  const shoppingApi = {
    items: shopping,
    add: (it) => setShopping((s) => [...s, { ...it, id: FB.uuid(), checked: false }]),
    addMany: (arr) => setShopping((s) => {
      const next = [...s];
      arr.forEach((it) => {
        const idx = next.findIndex((x) => !x.checked && x.name === it.name && x.unit === it.unit);
        if (idx >= 0 && it.quantity != null && next[idx].quantity != null) next[idx] = { ...next[idx], quantity: next[idx].quantity + it.quantity };
        else next.push({ ...it, id: FB.uuid(), checked: false });
      });
      return next;
    }),
    toggle: (id) => setShopping((s) => s.map((x) => (x.id === id ? { ...x, checked: !x.checked } : x))),
    remove: (id) => setShopping((s) => s.filter((x) => x.id !== id)),
    clearChecked: () => setShopping((s) => s.filter((x) => !x.checked)),
  };

  const reduceMotion = usePrefersReducedMotion();
  const appValue = {
    recipes, tags, tagsById, variantGroups, profile, username, setUsername, lang, prefs, insets, device,
    t: (k) => FB.t(lang, k), tw, setTweak, homeLayout: tw.homeLayout, reduceMotion,
    nav, getRecipe, getVariantGroup, isFav, toggleFav, updateRecipe, markCooked, deleteRecipe, saveRecipe, addVariant,
    addTag, exportData, importData, recipePhotos, setRecipePhoto,
    renameTag, deleteTag, findTagByName, recipesWithTag,
    tipsSeen, markTipSeen, resetTips,
    aliases, addAlias, removeAlias, importCfg, setImportCfg, setImportKey, onDeviceAI: tw.onDeviceAI !== false,
    shopping: shoppingApi,
  };

  // ── render the active screen ──
  let screen;
  switch (current.screen) {
    case "home": screen = <HomeScreen />; break;
    case "search": screen = <SearchScreen />; break;
    case "groceries": screen = <ShoppingScreen />; break;
    case "settings": screen = <SettingsScreen />; break;
    case "advanced": screen = <AdvancedSettingsScreen />; break;
    case "help": screen = <HelpScreen />; break;
    case "filter": screen = <ListFilterScreen route={current.params} />; break;
    case "recipe": screen = <RecipeScreen route={current.params} />; break;
    case "souschef": screen = <SousChefScreen route={current.params} />; break;
    case "edit": screen = <EditScreen route={current.params} />; break;
    default: screen = <HomeScreen />;
  }

  const showTabBar = TAB_SCREENS.includes(current.screen);
  const showFab = ["home", "search", "filter"].includes(current.screen);

  const Frame = device === "ios" ? IOSDevice : AndroidDevice;
  const W = device === "ios" ? 402 : 412;
  const H = device === "ios" ? 874 : 892;
  const scale = useStage(W, H);

  // ── screen transition: platform-aware, computed only when the route changes,
  // honoring reduce-motion. Transform/opacity only (no blur/shadow tweens). ──
  const navRef = React.useRef({ len: stack.length, screen: current.screen });
  const animRef = React.useRef({ key: null, anim: "none" });
  if (animRef.current.key !== scrollKey) {
    const prev = navRef.current;
    let kind = "replace";
    if (stack.length > prev.len) kind = "push";
    else if (stack.length < prev.len) kind = "pop";
    let anim;
    if (reduceMotion) anim = "fbFade 120ms ease both";
    else if (device === "ios") anim = kind === "pop"
      ? "fbSlideFromLeft 300ms cubic-bezier(0.32,0.72,0,1) both"
      : kind === "push" ? "fbSlideFromRight 300ms cubic-bezier(0.32,0.72,0,1) both" : "fbFade 200ms ease both";
    else anim = "fbFadeThrough 240ms cubic-bezier(0.4,0,0.2,1) both";
    animRef.current = { key: scrollKey, anim };
    navRef.current = { len: stack.length, screen: current.screen };
  }

  const inner = (
    <div key={device + tw.dark} style={{ position: "relative", height: "100%", width: "100%", background: theme.canvas, overflow: "hidden", fontFamily: theme.fontUI, color: theme.ink }}>
      {/* screen (key forces scroll reset + transition on nav change) */}
      <div key={scrollKey} style={{ position: "absolute", inset: 0, animation: animRef.current.anim, willChange: "transform, opacity" }}>{screen}</div>

      {/* FAB */}
      {showFab && (
        <button onClick={() => setImportFlow({ stage: "choose" })} style={{
          position: "absolute", right: 18, bottom: 76 + insets.bottom, zIndex: 40,
          width: 60, height: 60, borderRadius: 20, border: "none", cursor: "pointer",
          background: theme.accent, color: "#fff", display: "grid", placeItems: "center",
          boxShadow: "0 10px 26px " + theme.accent + "66, 0 2px 6px rgba(0,0,0,0.2)",
        }}>
          <Icon name="plus" size={28} color="#fff" stroke={2.6} />
        </button>
      )}

      {/* Bottom tab bar */}
      {showTabBar && (
        <div style={{
          position: "absolute", left: 0, right: 0, bottom: 0, zIndex: 50,
          paddingBottom: insets.bottom, background: theme.glass,
          backdropFilter: "blur(20px) saturate(160%)", WebkitBackdropFilter: "blur(20px) saturate(160%)",
          borderTop: `1px solid ${theme.line}`,
        }}>
          <div style={{ display: "flex", padding: "8px 6px 4px" }}>
            {[["home", "home", "tab_home"], ["search", "search", "tab_search"], ["groceries", "basket", "tab_list"], ["settings", "sliders", "tab_settings"]].map(([tab, icon, key]) => {
              const on = activeTab === tab;
              return (
                <button key={tab} onClick={() => nav.switchTab(tab)} style={{
                  flex: 1, border: "none", background: "none", cursor: "pointer", padding: "4px 0",
                  display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
                }}>
                  <div style={{ position: "relative" }}>
                    {tab === "groceries" && shopping.filter((x) => !x.checked).length > 0 && (
                      <span style={{ position: "absolute", top: -3, right: -8, minWidth: 16, height: 16, padding: "0 4px", borderRadius: 999, background: theme.accent, color: "#fff", fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center", fontFamily: theme.fontUI }}>{shopping.filter((x) => !x.checked).length}</span>
                    )}
                    <Icon name={icon} size={25} color={on ? theme.accent : theme.inkFaint} fill={on && tab === "home"} stroke={on ? 2.2 : 2} />
                  </div>
                  <span style={{ fontFamily: theme.fontUI, fontSize: 10.5, fontWeight: on ? 700 : 600, color: on ? theme.accent : theme.inkFaint, letterSpacing: 0.1 }}>{FB.t(lang, key)}</span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Phase 1.5 — import method chooser / input (covers the frame) */}
      <ImportOverlay flow={importFlow} setFlow={setImportFlow} />
    </div>
  );

  return (
    <ThemeCtx.Provider value={theme}>
      <AppCtx.Provider value={appValue}>
        <div style={{ position: "fixed", inset: 0, display: "grid", placeItems: "center", background: theme.dark ? "#0d0b08" : "#e7ddcd", overflow: "hidden" }}>
          <div style={{ transform: `scale(${scale})`, transformOrigin: "center center" }}>
            <Frame width={W} height={H} dark={tw.dark}>
              {inner}
            </Frame>
          </div>
        </div>

        {/* Tweaks */}
        <TweaksPanel title="Tweaks">
          <TweakSection label={lang === "fr" ? "Plateforme" : "Platform"} />
          <TweakRadio label={lang === "fr" ? "Appareil" : "Device"} value={tw.device} options={[{ value: "android", label: "Android" }, { value: "ios", label: "iOS web" }]} onChange={(v) => setTweak("device", v)} />
          <TweakSection label={lang === "fr" ? "Langue & texte" : "Language & text"} />
          <TweakRadio label={lang === "fr" ? "Langue" : "Language"} value={tw.lang} options={[{ value: "fr", label: "FR" }, { value: "en", label: "EN" }]} onChange={(v) => setTweak("lang", v)} />
          <TweakRadio label={lang === "fr" ? "Taille du texte" : "Text size"} value={tw.fontSize} options={[{ value: "small", label: lang === "fr" ? "Petit" : "Small" }, { value: "medium", label: lang === "fr" ? "Moyen" : "Med" }, { value: "large", label: lang === "fr" ? "Grand" : "Large" }]} onChange={(v) => setTweak("fontSize", v)} />
          <TweakSection label={lang === "fr" ? "Apparence" : "Appearance"} />
          <TweakToggle label={lang === "fr" ? "Thème sombre" : "Dark mode"} value={tw.dark} onChange={(v) => setTweak("dark", v)} />
          <TweakColor label={lang === "fr" ? "Couleur d'accent" : "Accent color"} value={tw.accent} options={["#C0563B", "#C58A2E", "#6BA368", "#9C6B8E", "#4A7BA6"]} onChange={(v) => setTweak("accent", v)} />
          <TweakRadio label={lang === "fr" ? "Accueil" : "Home layout"} value={tw.homeLayout} options={[{ value: "editorial", label: lang === "fr" ? "Éditorial" : "Editorial" }, { value: "grid", label: lang === "fr" ? "Grille" : "Grid" }]} onChange={(v) => setTweak("homeLayout", v)} />
          <TweakToggle label={lang === "fr" ? "Appareil compatible IA sur appareil" : "Device supports on-device AI"} value={tw.onDeviceAI} onChange={(v) => setTweak("onDeviceAI", v)} />
        </TweaksPanel>
      </AppCtx.Provider>
    </ThemeCtx.Provider>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
