/* fb-screens-misc.jsx — Shopping list, Settings, Add/Edit recipe (sectioned). */

// ── Small shared controls ─────────────────────────────────────
function Segmented({ value, options, onChange, full = true }) {
  const th = useTheme();
  return (
    <div style={{ display: "flex", gap: 3, background: th.dark ? "rgba(255,255,255,0.06)" : th.canvas2, borderRadius: 12, padding: 3, width: full ? "100%" : "auto" }}>
      {options.map((o) => {
        const active = value === o.value;
        return (
          <button key={o.value} onClick={() => onChange(o.value)} style={{
            flex: full ? 1 : "none", padding: "8px 14px", borderRadius: 9, border: "none", cursor: "pointer",
            background: active ? th.card : "transparent", color: active ? th.ink : th.inkSoft,
            fontFamily: th.fontUI, fontSize: th.fs(14), fontWeight: active ? 700 : 600, whiteSpace: "nowrap",
            boxShadow: active ? th.shadow : "none", transition: "all 0.15s",
          }}>{o.label}</button>
        );
      })}
    </div>
  );
}

function SettingsRow({ label, children, sub }) {
  const th = useTheme();
  return (
    <div style={{ padding: "14px 18px", borderBottom: `1px solid ${th.line}` }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 14 }}>
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 600, color: th.ink, flexShrink: 0 }}>{label}</div>
        {children}
      </div>
      {sub && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint, marginTop: 4 }}>{sub}</div>}
    </div>
  );
}

function Group({ label, children }) {
  const th = useTheme();
  return (
    <div style={{ marginBottom: 22 }}>
      <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, padding: "0 6px 8px" }}>{label}</div>
      <div style={{ background: th.card, borderRadius: 18, overflow: "hidden", boxShadow: th.shadow }}>{children}</div>
    </div>
  );
}

function Toggle({ on, onClick }) {
  const th = useTheme();
  return (
    <button onClick={onClick} style={{ width: 50, height: 30, borderRadius: 999, border: "none", cursor: "pointer", background: on ? th.accent : th.lineStrong, position: "relative", transition: "background 0.2s", flexShrink: 0 }}>
      <span style={{ position: "absolute", top: 3, left: on ? 23 : 3, width: 24, height: 24, borderRadius: 999, background: "#fff", transition: "left 0.2s", boxShadow: "0 1px 3px rgba(0,0,0,0.3)" }} />
    </button>
  );
}

// ── Shopping list ─────────────────────────────────────────────
function ShoppingScreen() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const { items } = app.shopping;
  const [draft, setDraft] = React.useState("");
  const toBuy = items.filter((i) => !i.checked);
  const inCart = items.filter((i) => i.checked);

  const addDraft = () => {
    const v = draft.trim();
    if (!v) return;
    app.shopping.add({ name: v, quantity: null, unit: null, sourceRecipeId: null });
    setDraft("");
  };

  const Item = ({ it }) => {
    const src = it.sourceRecipeId ? app.getRecipe(it.sourceRecipeId) : null;
    const qty = it.quantity != null ? FB.fmtQtyForUnit(it.quantity, it.unit) + (it.unit ? " " + FB.unitLabel(it.unit, lang, it.quantity) : "") : "";
    return (
      <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 16px", background: th.card, borderBottom: `1px solid ${th.line}` }}>
        <button onClick={() => app.shopping.toggle(it.id)} style={{ width: 26, height: 26, borderRadius: 999, flexShrink: 0, border: `2px solid ${it.checked ? th.accent : th.lineStrong}`, background: it.checked ? th.accent : "transparent", cursor: "pointer", display: "grid", placeItems: "center" }}>
          {it.checked && <Icon name="check" size={15} color="#fff" stroke={3} />}
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), color: it.checked ? th.inkFaint : th.ink, textDecoration: it.checked ? "line-through" : "none", fontWeight: 500 }}>
            {qty && <span style={{ fontWeight: 700, color: it.checked ? th.inkFaint : th.accent }}>{qty} </span>}{it.name}
          </div>
          {src && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint, marginTop: 1 }}>{src.title}</div>}
        </div>
        <button onClick={() => app.shopping.remove(it.id)} style={{ border: "none", background: "none", cursor: "pointer", padding: 6, lineHeight: 0, flexShrink: 0 }}>
          <Icon name="x" size={th.fs(17)} color={th.inkFaint} />
        </button>
      </div>
    );
  };

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <StickyHeader>
        <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", padding: "8px 20px 12px" }}>
          <h1 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(28), fontWeight: 600, color: th.ink }}>{t("list_title")}</h1>
          {inCart.length > 0 && (
            <button onClick={() => app.shopping.clearChecked()} style={{ border: "none", background: "none", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600, color: th.accent }}>{t("clear_checked")}</button>
          )}
        </div>
      </StickyHeader>

      <div style={{ padding: "12px 16px", flexShrink: 0 }}>
        <div style={{ display: "flex", gap: 9, alignItems: "center", background: th.card, border: `1px solid ${th.line}`, borderRadius: 14, padding: "0 6px 0 14px", height: 48, boxShadow: th.shadow }}>
          <Icon name="plus" size={th.fs(19)} color={th.inkFaint} />
          <input value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => e.key === "Enter" && addDraft()} placeholder={t("add_item")}
            style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(16), color: th.ink, minWidth: 0 }} />
          {draft && <button onClick={addDraft} style={{ height: 38, padding: "0 16px", borderRadius: 10, border: "none", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(14), fontWeight: 700, cursor: "pointer" }}>{t("done")}</button>}
        </div>
      </div>

      <ScreenScroll padBottom={96}>
        {items.length === 0 ? (
          <div style={{ textAlign: "center", padding: "50px 30px" }}>
            <div style={{ width: 64, height: 64, borderRadius: 999, background: th.accentSoft, display: "grid", placeItems: "center", margin: "0 auto 16px" }}>
              <Icon name="basket" size={28} color={th.accent} />
            </div>
            <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(21), fontWeight: 600, color: th.ink }}>{t("list_empty")}</div>
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14), color: th.inkSoft, marginTop: 6, lineHeight: 1.5 }}>{t("list_empty_hint")}</div>
          </div>
        ) : (
          <div style={{ padding: "4px 16px" }}>
            {toBuy.length > 0 && (
              <>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, padding: "8px 4px" }}>{t("to_buy")} · {toBuy.length}</div>
                <div style={{ borderRadius: 16, overflow: "hidden", boxShadow: th.shadow }}>{toBuy.map((it) => <Item key={it.id} it={it} />)}</div>
              </>
            )}
            {inCart.length > 0 && (
              <>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, padding: "20px 4px 8px" }}>{t("in_cart")} · {inCart.length}</div>
                <div style={{ borderRadius: 16, overflow: "hidden", opacity: 0.75 }}>{inCart.map((it) => <Item key={it.id} it={it} />)}</div>
              </>
            )}
          </div>
        )}
      </ScreenScroll>
    </div>
  );
}

// ── Settings ──────────────────────────────────────────────────
function SettingsScreen() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const set = app.setTweak;
  const tw = app.tw;
  const fileRef = React.useRef(null);
  const [flash, setFlash] = React.useState(null);
  const savedCount = app.recipes.filter((r) => !r.variantGroupId || (app.getVariantGroup(r.variantGroupId) || {}).baseId === r.id).length;

  const doExport = () => {
    const blob = new Blob([JSON.stringify(app.exportData(), null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = "facebouffe-livre.json"; a.click();
    URL.revokeObjectURL(url);
    setFlash(lang === "fr" ? "Livre exporté" : "Book exported");
    setTimeout(() => setFlash(null), 1800);
  };
  const doImport = (e) => {
    const f = e.target.files && e.target.files[0];
    if (!f) return;
    const rd = new FileReader();
    rd.onload = () => {
      try { const data = JSON.parse(rd.result); const n = app.importData(data); setFlash((lang === "fr" ? "Importé : " : "Imported: ") + n + (lang === "fr" ? " recettes" : " recipes")); }
      catch (err) { setFlash(lang === "fr" ? "Fichier invalide" : "Invalid file"); }
      setTimeout(() => setFlash(null), 2200);
    };
    rd.readAsText(f);
    e.target.value = "";
  };

  const ActionRow = ({ icon, label, onClick, isLast }) => (
    <button onClick={onClick} style={{ display: "flex", alignItems: "center", gap: 13, width: "100%", border: "none", background: "transparent", cursor: "pointer", padding: "14px 18px", borderBottom: isLast ? "none" : `1px solid ${th.line}`, textAlign: "left" }}>
      <span style={{ width: 30, height: 30, borderRadius: 9, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name={icon} size={17} color={th.accent} /></span>
      <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 600, color: th.ink }}>{label}</span>
      <Icon name="chevR" size={th.fs(17)} color={th.inkFaint} />
    </button>
  );

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <StickyHeader>
        <h1 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(28), fontWeight: 600, color: th.ink, padding: "8px 20px 12px" }}>{t("settings_title")}</h1>
      </StickyHeader>
      <ScreenScroll>
        <div style={{ padding: "16px 16px 0" }}>
          {/* profile */}
          <div style={{ display: "flex", alignItems: "center", gap: 14, background: th.card, borderRadius: 20, padding: 16, boxShadow: th.shadow, marginBottom: 22 }}>
            <div style={{ width: 56, height: 56, borderRadius: 999, background: th.accent, color: "#fff", display: "grid", placeItems: "center", fontFamily: th.fontDisplay, fontSize: th.fs(26), fontWeight: 600, flexShrink: 0 }}>{(app.username || "?")[0].toUpperCase()}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 3 }}>{t("username_label")}</div>
              <input value={app.username} onChange={(e) => app.setUsername(e.target.value)} style={{ width: "100%", border: "none", outline: "none", background: "transparent", fontFamily: th.fontDisplay, fontSize: th.fs(20), fontWeight: 600, color: th.ink }} />
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft }}>{savedCount} {t("recipes_saved")}</div>
            </div>
          </div>

          <Group label={t("set_language")}>
            <SettingsRow label={t("set_language")}>
              <div style={{ width: 168 }}><Segmented value={lang} onChange={(v) => set("lang", v)} options={[{ value: "fr", label: "Français" }, { value: "en", label: "English" }]} /></div>
            </SettingsRow>
          </Group>

          <Group label={t("set_units")}>
            <SettingsRow label={t("set_temp")}>
              <div style={{ width: 150 }}><Segmented value={tw.tempUnit} onChange={(v) => set("tempUnit", v)} options={[{ value: "celsius", label: "°C" }, { value: "fahrenheit", label: "°F" }]} /></div>
            </SettingsRow>
            <SettingsRow label={t("set_volume")}>
              <div style={{ width: 168 }}><Segmented value={tw.volUnit} onChange={(v) => set("volUnit", v)} options={[{ value: "metric", label: t("metric") }, { value: "imperial", label: t("imperial") }]} /></div>
            </SettingsRow>
            <SettingsRow label={t("set_weight")}>
              <div style={{ width: 168 }}><Segmented value={tw.weightUnit} onChange={(v) => set("weightUnit", v)} options={[{ value: "metric", label: t("metric") }, { value: "imperial", label: t("imperial") }]} /></div>
            </SettingsRow>
          </Group>

          <Group label={t("set_textsize")}>
            <SettingsRow label={t("set_textsize")}>
              <div style={{ width: 150 }}><Segmented value={tw.fontSize} onChange={(v) => set("fontSize", v)} options={[{ value: "small", label: "A" }, { value: "medium", label: "A" }, { value: "large", label: "A" }]} /></div>
            </SettingsRow>
          </Group>

          <Group label={lang === "fr" ? "Apparence" : "Appearance"}>
            <SettingsRow label={lang === "fr" ? "Thème sombre" : "Dark mode"}>
              <Toggle on={tw.dark} onClick={() => set("dark", !tw.dark)} />
            </SettingsRow>
            <SettingsRow label={lang === "fr" ? "Plateforme" : "Platform"} sub={lang === "fr" ? "Android natif · appli web iOS" : "Native Android · iOS web app"}>
              <div style={{ width: 150 }}><Segmented value={tw.device} onChange={(v) => set("device", v)} options={[{ value: "android", label: "Android" }, { value: "ios", label: "iOS" }]} /></div>
            </SettingsRow>
          </Group>

          <Group label={t("custom_tags")}>
            <TagManager />
          </Group>

          <Group label={t("import_export")}>
            <ActionRow icon="basket" label={t("import_book")} onClick={() => fileRef.current && fileRef.current.click()} />
            <ActionRow icon="note" label={t("export_json")} onClick={doExport} />
            <ActionRow icon="note" label={t("export_book_pdf")} onClick={() => window.print()} isLast />
          </Group>
          <input ref={fileRef} type="file" accept="application/json,.json" onChange={doImport} style={{ display: "none" }} />

          <Group label={t("help_section")}>
            <ActionRow icon="note" label={t("help_title")} onClick={() => app.nav.go("help")} />
            <button onClick={() => { app.resetTips(); setFlash(t("tips_reset_done")); setTimeout(() => setFlash(null), 1800); }} style={{ display: "flex", alignItems: "center", gap: 13, width: "100%", border: "none", background: "transparent", cursor: "pointer", padding: "14px 18px", textAlign: "left" }}>
              <span style={{ width: 30, height: 30, borderRadius: 9, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="timer" size={17} color={th.accent} /></span>
              <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 600, color: th.ink }}>{t("replay_tips")}</span>
              <Icon name="chevR" size={th.fs(17)} color={th.inkFaint} />
            </button>
          </Group>

          {flash && (
            <div style={{ position: "sticky", bottom: 12, margin: "0 auto 10px", width: "fit-content", padding: "10px 18px", borderRadius: 999, background: th.ink, color: th.canvas, fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600, boxShadow: th.shadow }}>{flash}</div>
          )}
          <div style={{ textAlign: "center", padding: "8px 0 4px", fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint }}>{t("version")}</div>
        </div>
      </ScreenScroll>
    </div>
  );
}

// ── Add / Edit (sectioned flow) ───────────────────────────────
const UNIT_OPTS = [null, "g", "kg", "ml", "l", "tsp", "tbsp", "cup", "oz", "lb", "pinch"];
const EDIT_SECTIONS = [["infos", "sec_infos"], ["ing", "ingredients"], ["steps", "steps"], ["desc", "f_desc"]];

function move(arr, i, dir) {
  const j = i + dir;
  if (j < 0 || j >= arr.length) return arr;
  const next = arr.slice();
  const tmp = next[i]; next[i] = next[j]; next[j] = tmp;
  return next;
}

// Textarea with °C/°F insert pills + a live "recognized temperature" preview.
// Temperatures are stored as {{temp:v:u}} tokens; the editor shows friendly
// text and (de)tokenizes on load/save in EditScreen.
function TempTextarea({ value, onChange, placeholder, rows = 2, textareaStyle, children }) {
  const th = useTheme();
  const app = useApp();
  const ref = React.useRef(null);
  const insert = (s) => {
    const el = ref.current;
    const v = value || "";
    if (!el) { onChange(v + s); return; }
    const st = el.selectionStart != null ? el.selectionStart : v.length;
    const en = el.selectionEnd != null ? el.selectionEnd : v.length;
    onChange(v.slice(0, st) + s + v.slice(en));
    requestAnimationFrame(() => { try { el.focus(); el.selectionStart = el.selectionEnd = st + s.length; } catch (e) {} });
  };
  const detected = FB.findTemps(value);
  const pref = FB.prefTempUnit(app.prefs);
  const pill = { width: 48, height: 34, borderRadius: 9, border: `1px solid ${th.line}`, background: th.card, color: th.accent, cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700, display: "grid", placeItems: "center" };
  return (
    <div>
      <div style={{ display: "flex", gap: 8, alignItems: "flex-start" }}>
        <textarea ref={ref} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} rows={rows} style={{ ...textareaStyle, flex: 1, minWidth: 0 }} />
        <div style={{ display: "flex", flexDirection: "column", gap: 6, flexShrink: 0 }}>
          <button onClick={() => insert("°C")} style={pill}>°C</button>
          <button onClick={() => insert("°F")} style={pill}>°F</button>
        </div>
      </div>
      {(children || detected.length > 0) && (
        <div style={{ display: "flex", alignItems: "center", gap: 7, marginTop: 7, flexWrap: "wrap" }}>
          {children}
          {detected.length > 0 && (
            <div style={{ display: "inline-flex", alignItems: "center", gap: 6, marginLeft: 2, flexWrap: "wrap" }}>
              <Icon name="check" size={13} color="#6BA368" />
              {detected.map((d, i) => (
                <span key={i} style={{ display: "inline-flex", alignItems: "baseline", padding: "2px 8px", borderRadius: 999, border: `1px solid ${th.accent}55`, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700 }}>{FB.fmtTemp(d.value, d.unit, pref)}</span>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function TagSelector({ value, onChange }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const [picker, setPicker] = React.useState(false);
  const [q, setQ] = React.useState("");
  const all = app.tags.filter((tg) => tg.special !== "favorite");
  const selected = value.map((id) => app.tagsById[id]).filter(Boolean).filter((tg) => tg.special !== "favorite");
  const unselected = all.filter((tg) => !value.includes(tg.id));
  const toggle = (id) => onChange(value.includes(id) ? value.filter((x) => x !== id) : [...value, id]);
  const pickList = unselected.filter((tg) => FB.tagName(tg, lang).toLowerCase().includes(q.trim().toLowerCase()));
  const exactExists = !!app.findTagByName(q);
  const createNew = () => {
    const r = app.addTag(q.trim());
    if (!value.includes(r.id)) onChange([...value, r.id]);
    setQ(""); setPicker(false);
  };
  const Pill = ({ tg, on }) => (
    <button onClick={() => toggle(tg.id)} style={{
      display: "inline-flex", alignItems: "center", gap: 6, padding: "6px 12px 6px 7px", borderRadius: 999, cursor: "pointer",
      border: `1px solid ${on ? tg.color : th.line}`, background: on ? tg.color : "transparent", color: on ? "#fff" : th.inkFaint,
      fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600,
    }}>
      <span style={{ width: 17, height: 17, borderRadius: 999, display: "grid", placeItems: "center", background: on ? "rgba(255,255,255,0.25)" : th.line }}>
        <Icon name={tg.icon} size={11} color={on ? "#fff" : th.inkFaint} stroke={2.2} />
      </span>
      {FB.tagName(tg, lang)}
    </button>
  );
  return (
    <div>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        {selected.map((tg) => <Pill key={tg.id} tg={tg} on />)}
        {unselected.map((tg) => <Pill key={tg.id} tg={tg} on={false} />)}
        <button onClick={() => { setPicker((v) => !v); setQ(""); }} style={{ display: "inline-flex", alignItems: "center", gap: 5, padding: "6px 13px", borderRadius: 999, border: `1.5px dashed ${th.lineStrong}`, background: "transparent", color: th.accent, cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700 }}>
          <Icon name="plus" size={14} color={th.accent} stroke={2.4} /> tag
        </button>
      </div>
      {picker && (
        <div style={{ marginTop: 10, border: `1px solid ${th.line}`, borderRadius: 12, overflow: "hidden", background: th.card }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px", borderBottom: `1px solid ${th.line}` }}>
            <Icon name="search" size={16} color={th.inkFaint} />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("search_tag")} style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink, minWidth: 0 }} />
            {q && <button onClick={() => setQ("")} style={{ border: "none", background: "none", cursor: "pointer", padding: 2, lineHeight: 0 }}><Icon name="x" size={15} color={th.inkFaint} /></button>}
          </div>
          <div className="fb-scroll" style={{ maxHeight: 230, overflowY: "auto", WebkitOverflowScrolling: "touch" }}>
            {pickList.map((tg, i) => (
              <button key={tg.id} onClick={() => { toggle(tg.id); setPicker(false); setQ(""); }} style={{ display: "flex", alignItems: "center", gap: 9, width: "100%", border: "none", borderBottom: `1px solid ${th.line}`, background: "transparent", padding: "11px 13px", cursor: "pointer", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink }}>
                <span style={{ width: 18, height: 18, borderRadius: 999, display: "grid", placeItems: "center", background: tg.color + "22" }}><Icon name={tg.icon} size={12} color={tg.color} stroke={2.2} /></span>
                {FB.tagName(tg, lang)}
              </button>
            ))}
            {q.trim() && !exactExists && (
              <button onClick={createNew} style={{ display: "flex", alignItems: "center", gap: 9, width: "100%", border: "none", background: "transparent", padding: "12px 13px", cursor: "pointer", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(14), color: th.accent, fontWeight: 700 }}>
                <Icon name="plus" size={15} color={th.accent} stroke={2.4} /> {lang === "fr" ? `Aucun résultat — créer « ${q.trim()} » ?` : `No match — create “${q.trim()}”?`}
              </button>
            )}
            {q.trim() && exactExists && pickList.length === 0 && (
              <div style={{ padding: "12px 13px", fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkFaint }}>{t("tag_exists")}</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function EditScreen({ route }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const existing = route.id ? app.getRecipe(route.id) : null;
  const blank = () => ({
    title: "", description: "", source: "", servings: 4, prepTimeMinutes: 15, cookTimeMinutes: 20,
    tags: [], heroImage: "new", gallery: [],
    ingredients: [{ quantity: null, unit: null, name: "", note: "" }],
    steps: [{ text: "", image: null, timerSeconds: null }],
    personal: { notes: "", rating: 0, lastCooked: null, madeCount: 0 },
  });
  const [form, setForm] = React.useState(() => {
    const f = existing ? JSON.parse(JSON.stringify(existing)) : blank();
    f.description = FB.detokenizeTemps(f.description || "");
    f.steps = (f.steps || []).map((s) => ({ ...s, text: FB.detokenizeTemps(s.text || "") }));
    return f;
  });
  const [section, setSection] = React.useState("infos");
  React.useEffect(() => { if (!existing) app.setRecipePhoto("__draft", null); }, []);
  const [error, setError] = React.useState(null);
  const [linkPicker, setLinkPicker] = React.useState(false);
  const [linkQuery, setLinkQuery] = React.useState("");
  const [newTag, setNewTag] = React.useState("");
  const up = (patch) => setForm((f) => ({ ...f, ...patch }));
  const setIng = (i, patch) => setForm((f) => ({ ...f, ingredients: f.ingredients.map((x, j) => j === i ? { ...x, ...patch } : x) }));
  const setStep = (i, patch) => setForm((f) => ({ ...f, steps: f.steps.map((x, j) => j === i ? { ...x, ...patch } : x) }));

  const save = () => {
    if (!form.title.trim()) { setError(t("validation_title")); setSection("infos"); return; }
    if (!form.ingredients.some((x) => x.name.trim())) { setError(t("validation_ing")); setSection("ing"); return; }
    const clean = { ...form,
      description: FB.tokenizeTemps(form.description || ""),
      ingredients: form.ingredients.filter((x) => x.name.trim()),
      steps: form.steps.filter((x) => x.text.trim()).map((s) => ({ ...s, text: FB.tokenizeTemps(s.text) })),
    };
    app.saveRecipe(clean, existing);
    app.nav.back();
  };

  const inputStyle = { width: "100%", boxSizing: "border-box", border: `1px solid ${th.line}`, borderRadius: 13, background: th.card, padding: "12px 14px", fontFamily: th.fontUI, fontSize: th.fs(15.5), color: th.ink, outline: "none" };
  const labelStyle = { display: "block", fontFamily: th.fontUI, fontSize: th.fs(12.5), fontWeight: 700, color: th.inkSoft, textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 7 };
  const Field = ({ label, children }) => (<div style={{ marginBottom: 16 }}><label style={labelStyle}>{label}</label>{children}</div>);
  const MiniBtn = ({ icon, onClick, disabled }) => (
    <button onClick={onClick} disabled={disabled} style={{ width: 30, height: 30, borderRadius: 8, border: `1px solid ${th.line}`, background: th.card, cursor: disabled ? "default" : "pointer", opacity: disabled ? 0.35 : 1, display: "grid", placeItems: "center", flexShrink: 0 }}>
      <Icon name={icon} size={15} color={th.inkSoft} />
    </button>
  );

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <div style={{ paddingTop: app.insets.top, background: th.glass, backdropFilter: "blur(16px)", WebkitBackdropFilter: "blur(16px)", borderBottom: `1px solid ${th.line}`, flexShrink: 0 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "8px 14px 10px" }}>
          <button onClick={() => app.nav.back()} style={{ border: "none", background: "none", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 600, color: th.inkSoft }}>{t("cancel")}</button>
          <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(18), fontWeight: 600, color: th.ink }}>{existing ? t("edit_title") : t("add_title")}</div>
          <button onClick={save} style={{ border: "none", background: th.accent, color: "#fff", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, padding: "9px 16px", borderRadius: 11 }}>{t("save")}</button>
        </div>
        {/* section nav */}
        <div className="fb-hscroll" style={{ display: "flex", gap: 7, overflowX: "auto", padding: "0 14px 10px" }}>
          {EDIT_SECTIONS.map(([key, lk], i) => {
            const on = section === key;
            return (
              <button key={key} onClick={() => setSection(key)} style={{
                flexShrink: 0, display: "inline-flex", alignItems: "center", gap: 7, border: `1.5px solid ${on ? th.accent : th.line}`,
                background: on ? th.accent : th.card, color: on ? "#fff" : th.inkSoft, borderRadius: 999, padding: "7px 13px 7px 8px", cursor: "pointer",
                fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700,
              }}>
                <span style={{ width: 20, height: 20, borderRadius: 999, background: on ? "rgba(255,255,255,0.25)" : th.accentSoft, color: on ? "#fff" : th.accent, display: "grid", placeItems: "center", fontSize: th.fs(11.5) }}>{i + 1}</span>
                {t(lk)}
              </button>
            );
          })}
        </div>
      </div>

      <div className="fb-scroll" style={{ flex: 1, overflowY: "auto", padding: `18px 18px ${30 + app.insets.bottom}px` }}>
        {error && (
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 16, padding: "11px 14px", borderRadius: 12, background: "#C0563B18", border: "1px solid #C0563B55", color: "#9c3f29", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600 }}>
            <Icon name="x" size={16} color="#9c3f29" /> {error}
          </div>
        )}

        {/* INFOS */}
        {section === "infos" && (
          <>
            <Field label={t("sec_photo")}>
              <PhotoDrop photoId={existing ? existing.id : "__draft"} recipe={{ id: existing ? existing.id : "__draft", title: form.title || "?", heroImage: null }} tag={(form.tags || []).map((id) => app.tagsById[id]).filter(Boolean)[0] || null} height={190} radius={16} removable />
            </Field>
            <Field label={t("f_tags")}>
              <TagSelector value={form.tags || []} onChange={(tags) => up({ tags })} />
            </Field>
            <Field label={t("f_title")}><input value={form.title} onChange={(e) => up({ title: e.target.value })} placeholder={t("f_title_ph")} style={inputStyle} /></Field>
            <Field label={t("f_source")}><input value={form.source || ""} onChange={(e) => up({ source: e.target.value })} placeholder={t("f_source_ph")} style={inputStyle} /></Field>
            <div style={{ display: "flex", gap: 10 }}>
              {[["f_servings", "servings"], ["f_prep", "prepTimeMinutes"], ["f_cook", "cookTimeMinutes"]].map(([lk, key]) => (
                <div key={key} style={{ flex: 1 }}>
                  <label style={{ ...labelStyle, fontSize: th.fs(10.5), letterSpacing: 0.2, whiteSpace: "nowrap" }}>{t(lk)}</label>
                  <input type="number" min="0" value={form[key]} onChange={(e) => up({ [key]: parseInt(e.target.value) || 0 })} style={{ ...inputStyle, textAlign: "center", fontVariantNumeric: "tabular-nums", fontWeight: 700, padding: "12px 6px" }} />
                </div>
              ))}
            </div>
          </>
        )}

        {/* INGREDIENTS */}
        {section === "ing" && (
          <>
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              {form.ingredients.map((ing, i) => (
                <div key={i} className={app.reduceMotion ? undefined : "fb-row-in"} style={{ background: th.cardSoft, border: `1px solid ${th.line}`, borderRadius: 16, padding: 10 }}>
                  <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                    <input value={ing.quantity == null ? "" : ing.quantity} onChange={(e) => setIng(i, { quantity: e.target.value === "" ? null : parseFloat(e.target.value) })} placeholder={t("f_qty")} inputMode="decimal" style={{ ...inputStyle, width: 50, padding: "11px 4px", textAlign: "center" }} />
                    <select value={ing.unit || ""} onChange={(e) => setIng(i, { unit: e.target.value || null })} style={{ ...inputStyle, width: 82, padding: "11px 6px", appearance: "none" }}>
                      {UNIT_OPTS.map((u) => <option key={u || "none"} value={u || ""}>{u ? FB.unitLabel(u, lang) : "—"}</option>)}
                    </select>
                    <input value={ing.name} onChange={(e) => setIng(i, { name: e.target.value })} placeholder={t("f_ing_name")} style={{ ...inputStyle, flex: 1, padding: "11px 12px", minWidth: 0 }} />
                  </div>
                  <div style={{ display: "flex", gap: 6, alignItems: "center", marginTop: 7 }}>
                    <input value={ing.note || ""} onChange={(e) => setIng(i, { note: e.target.value })} placeholder={t("f_note") + " · " + t("f_note_ph")} style={{ ...inputStyle, flex: 1, padding: "9px 12px", fontSize: th.fs(13.5), fontStyle: "italic" }} />
                    <MiniBtn icon="chevD" onClick={() => up({ ingredients: move(form.ingredients, i, 1) })} disabled={i === form.ingredients.length - 1} />
                    <MiniBtn icon="trash" onClick={() => up({ ingredients: form.ingredients.filter((_, j) => j !== i) })} />
                  </div>
                </div>
              ))}
            </div>
            <AddRowBtn label={t("f_add_ing")} onClick={() => up({ ingredients: [...form.ingredients, { quantity: null, unit: null, name: "", note: "" }] })} />
          </>
        )}

        {/* STEPS */}
        {section === "steps" && (
          <>
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              {form.steps.map((s, i) => (
                <div key={i} className={app.reduceMotion ? undefined : "fb-row-in"} style={{ background: th.cardSoft, border: `1px solid ${th.line}`, borderRadius: 16, padding: 10 }}>
                  <div style={{ display: "flex", gap: 9 }}>
                    <div style={{ flexShrink: 0, width: 28, height: 28, borderRadius: 999, background: th.accent, color: "#fff", display: "grid", placeItems: "center", fontFamily: th.fontDisplay, fontSize: th.fs(15), fontWeight: 600, marginTop: 2 }}>{i + 1}</div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <TempTextarea value={s.text} onChange={(v) => setStep(i, { text: v })} placeholder={t("f_step") + " " + (i + 1)} rows={2} textareaStyle={{ ...inputStyle, resize: "vertical", lineHeight: 1.5 }} />
                    </div>
                  </div>
                  <div style={{ display: "flex", gap: 7, alignItems: "center", marginTop: 8, paddingLeft: 37 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 6, flex: 1 }}>
                      <Icon name="timer" size={16} color={th.inkFaint} />
                      <input type="number" min="0" value={s.timerSeconds == null ? "" : Math.round(s.timerSeconds / 60)} onChange={(e) => setStep(i, { timerSeconds: e.target.value === "" ? null : (parseInt(e.target.value) || 0) * 60 })} placeholder={t("f_timer")} style={{ ...inputStyle, width: 92, padding: "8px 10px", fontSize: th.fs(13.5) }} />
                    </div>
                    <button onClick={() => setStep(i, { image: s.image ? null : (existing ? existing.id : "new") + "-step" + i + ".jpg" })} style={{ height: 34, padding: "0 11px", borderRadius: 9, border: `1px solid ${s.image ? th.accent : th.line}`, background: s.image ? th.accentSoft : th.card, color: s.image ? th.accent : th.inkSoft, cursor: "pointer", display: "inline-flex", alignItems: "center", gap: 5, fontFamily: th.fontUI, fontSize: th.fs(12.5), fontWeight: 600 }}>
                      <Icon name="camera" size={15} /> {lang === "fr" ? "Photo" : "Photo"}
                    </button>
                    <MiniBtn icon="chevD" onClick={() => up({ steps: move(form.steps, i, 1) })} disabled={i === form.steps.length - 1} />
                    <MiniBtn icon="trash" onClick={() => up({ steps: form.steps.filter((_, j) => j !== i) })} />
                  </div>
                  {s.image && (
                    <div style={{ marginTop: 9, paddingLeft: 37, maxWidth: 220 }}>
                      <image-slot id={"fbeditstep-" + (existing ? existing.id : "new") + "-" + i} shape="rounded" radius="12" placeholder={lang === "fr" ? "Photo de l'étape" : "Step photo"} style={{ display: "block", width: "100%", height: "120px", background: th.canvas2 }}></image-slot>
                    </div>
                  )}
                </div>
              ))}
            </div>
            <AddRowBtn label={t("f_add_step")} onClick={() => up({ steps: [...form.steps, { text: "", image: null, timerSeconds: null }] })} />
          </>
        )}

        {/* DESCRIPTION */}
        {section === "desc" && (
          <>
            <Field label={t("f_desc")}>
              <TempTextarea value={form.description} onChange={(v) => up({ description: v })} placeholder={t("f_desc_ph")} rows={5} textareaStyle={{ ...inputStyle, resize: "vertical", lineHeight: 1.55 }}>
                <button onClick={() => setLinkPicker((v) => !v)} style={{ height: 30, display: "inline-flex", alignItems: "center", gap: 6, border: `1px solid ${th.line}`, background: th.card, borderRadius: 9, padding: "0 11px", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600, color: th.accent }}>
                  <Icon name="link" size={14} color={th.accent} /> {t("insert_link")}
                </button>
              </TempTextarea>
              {linkPicker && (
                <div style={{ marginTop: 8, border: `1px solid ${th.line}`, borderRadius: 12, overflow: "hidden", background: th.card }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px", borderBottom: `1px solid ${th.line}` }}>
                    <Icon name="search" size={16} color={th.inkFaint} />
                    <input value={linkQuery} onChange={(e) => setLinkQuery(e.target.value)} placeholder={lang === "fr" ? "Rechercher une recette" : "Search a recipe"} style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink, minWidth: 0 }} />
                    {linkQuery && <button onClick={() => setLinkQuery("")} style={{ border: "none", background: "none", cursor: "pointer", padding: 2, lineHeight: 0 }}><Icon name="x" size={15} color={th.inkFaint} /></button>}
                  </div>
                  <div className="fb-scroll" style={{ maxHeight: 264, overflowY: "auto", WebkitOverflowScrolling: "touch" }}>
                    {(() => {
                      const matches = app.recipes.filter((r) => r.id !== (existing && existing.id) && r.title.toLowerCase().includes(linkQuery.trim().toLowerCase())).slice(0, 10);
                      if (matches.length === 0) return <div style={{ padding: "14px 13px", fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkFaint }}>{t("no_results")}</div>;
                      return matches.map((r, i) => (
                        <button key={r.id} onClick={() => { up({ description: (form.description ? form.description + " " : "") + "{{link:" + r.id + "}}" }); setLinkPicker(false); setLinkQuery(""); }} style={{ display: "flex", alignItems: "center", gap: 9, width: "100%", border: "none", borderBottom: i < matches.length - 1 ? `1px solid ${th.line}` : "none", background: "transparent", padding: "11px 13px", cursor: "pointer", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink }}>
                          <Icon name="link" size={14} color={th.accent} /> {r.title}
                        </button>
                      ));
                    })()}
                  </div>
                </div>
              )}
            </Field>
            <Field label={t("gallery")}>
              <div className="fb-hscroll" style={{ display: "flex", gap: 10, overflowX: "auto", paddingBottom: 4 }}>
                {[0, 1, 2].map((i) => (
                  <div key={i} style={{ flexShrink: 0, width: 120 }}>
                    <image-slot id={"fbeditgal-" + (existing ? existing.id : "new") + "-" + i} shape="rounded" radius="14" placeholder={lang === "fr" ? "+ Photo" : "+ Photo"} style={{ display: "block", width: "120px", height: "120px", background: th.canvas2 }}></image-slot>
                  </div>
                ))}
              </div>
            </Field>
            <Field label={t("notes")}>
              <textarea value={form.personal.notes} onChange={(e) => up({ personal: { ...form.personal, notes: e.target.value } })} placeholder={t("f_notes_ph")} rows={2} style={{ ...inputStyle, resize: "vertical", lineHeight: 1.5 }} />
            </Field>
          </>
        )}

        {/* TAGS */}
        {existing && section === "infos" && (
          <button onClick={() => { app.deleteRecipe(existing.id); app.nav.home(); }} style={{ width: "100%", marginTop: 14, height: 48, borderRadius: 13, border: `1px solid ${th.line}`, background: "transparent", color: "#C0563B", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
            <Icon name="trash" size={th.fs(18)} /> {t("delete")}
          </button>
        )}
      </div>
    </div>
  );
}

function AddRowBtn({ label, onClick }) {
  const th = useTheme();
  return (
    <button onClick={onClick} style={{ marginTop: 12, display: "inline-flex", alignItems: "center", gap: 7, border: `1.5px dashed ${th.lineStrong}`, background: "transparent", borderRadius: 12, padding: "10px 15px", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(14), fontWeight: 600, color: th.accent }}>
      <Icon name="plus" size={th.fs(17)} color={th.accent} stroke={2.4} /> {label}
    </button>
  );
}

function TagManager() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const userTags = app.tags.filter((tg) => !tg.system);
  const [editId, setEditId] = React.useState(null);
  const [draft, setDraft] = React.useState("");
  const [warn, setWarn] = React.useState(null);
  const [confirmId, setConfirmId] = React.useState(null);
  const [newName, setNewName] = React.useState("");
  const [createWarn, setCreateWarn] = React.useState(false);
  const startRename = (tg) => { setEditId(tg.id); setDraft(typeof tg.name === "string" ? tg.name : FB.tagName(tg, lang)); setWarn(null); setConfirmId(null); };
  const commit = (tg) => { if (!draft.trim()) { setEditId(null); return; } if (!app.renameTag(tg.id, draft.trim())) { setWarn(tg.id); return; } setEditId(null); setWarn(null); };
  const doCreate = () => {
    const v = newName.trim();
    if (!v) return;
    const r = app.addTag(v);
    if (!r.created) { setCreateWarn(true); return; }
    setNewName(""); setCreateWarn(false);
  };
  return (
    <React.Fragment>
      {userTags.length === 0 && <div style={{ padding: "14px 18px", fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkFaint }}>{t("no_user_tags")}</div>}
      {userTags.map((tg, i) => {
        const editing = editId === tg.id;
        const name = FB.tagName(tg, lang);
        const n = app.recipesWithTag(tg.id);
        return (
          <div key={tg.id} style={{ borderBottom: i < userTags.length - 1 ? `1px solid ${th.line}` : "none" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 11, padding: "12px 16px" }}>
              <span style={{ width: 30, height: 30, borderRadius: 9, background: tg.color + "22", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name={tg.icon} size={16} color={tg.color} stroke={2.2} /></span>
              {editing ? (
                <input autoFocus value={draft} onChange={(e) => { setDraft(e.target.value); setWarn(null); }} onKeyDown={(e) => e.key === "Enter" && commit(tg)} style={{ flex: 1, border: `1px solid ${th.line}`, borderRadius: 9, background: th.canvas2, padding: "8px 10px", fontFamily: th.fontUI, fontSize: th.fs(15), color: th.ink, outline: "none", minWidth: 0 }} />
              ) : (
                <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 600, color: th.ink }}>{name}</span>
              )}
              {editing ? (
                <button onClick={() => commit(tg)} style={{ width: 34, height: 34, borderRadius: 9, border: "none", background: th.accent, cursor: "pointer", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="check" size={17} color="#fff" stroke={2.6} /></button>
              ) : (
                <button onClick={() => startRename(tg)} style={{ width: 34, height: 34, borderRadius: 9, border: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="pencil" size={16} color={th.inkSoft} /></button>
              )}
              <button onClick={() => { setConfirmId(confirmId === tg.id ? null : tg.id); setEditId(null); }} style={{ width: 34, height: 34, borderRadius: 9, border: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="trash" size={16} color={th.inkSoft} /></button>
            </div>
            {warn === tg.id && <div style={{ padding: "0 16px 12px 57px", fontFamily: th.fontUI, fontSize: th.fs(12.5), color: "#C0563B", fontWeight: 600 }}>{t("tag_exists")}</div>}
            {confirmId === tg.id && (
              <div style={{ padding: "0 16px 14px 57px" }}>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), lineHeight: 1.4, color: th.inkSoft, marginBottom: 9 }}>
                  {lang === "fr" ? `Supprimer « ${name} » ? Ce tag sera retiré de ${n} ${n === 1 ? "recette" : "recettes"}.` : `Delete “${name}”? It will be removed from ${n} ${n === 1 ? "recipe" : "recipes"}.`}
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <button onClick={() => setConfirmId(null)} style={{ height: 34, padding: "0 14px", borderRadius: 9, border: `1px solid ${th.line}`, background: "transparent", color: th.inkSoft, cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600 }}>{t("cancel")}</button>
                  <button onClick={() => { app.deleteTag(tg.id); setConfirmId(null); }} style={{ height: 34, padding: "0 14px", borderRadius: 9, border: "none", background: "#C0563B", color: "#fff", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 700 }}>{t("delete")}</button>
                </div>
              </div>
            )}
          </div>
        );
      })}
      <div style={{ padding: "12px 16px", borderTop: userTags.length > 0 ? `1px solid ${th.line}` : "none" }}>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <span style={{ width: 30, height: 30, borderRadius: 9, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="plus" size={16} color={th.accent} stroke={2.4} /></span>
          <input value={newName} onChange={(e) => { setNewName(e.target.value); setCreateWarn(false); }} onKeyDown={(e) => e.key === "Enter" && doCreate()} placeholder={t("add_tag")} style={{ flex: 1, border: `1px solid ${th.line}`, borderRadius: 9, background: th.canvas2, padding: "9px 11px", fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink, outline: "none", minWidth: 0 }} />
          <button onClick={doCreate} style={{ height: 36, padding: "0 15px", borderRadius: 9, border: "none", background: th.accent, color: "#fff", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700, flexShrink: 0 }}>{t("create_label")}</button>
        </div>
        {createWarn && <div style={{ marginTop: 8, paddingLeft: 41, fontFamily: th.fontUI, fontSize: th.fs(12.5), color: "#C0563B", fontWeight: 600 }}>{t("tag_exists")}</div>}
      </div>
    </React.Fragment>
  );
}

function HelpScreen() {
  const th = useTheme();
  const app = useApp();
  const { t, lang, nav } = app;
  const glossary = lang === "fr" ? [
    ["Mode sous-chef", "Vue de cuisson simplifiée : ingrédients à cocher et étapes en grand, avec minuteries. L'écran reste allumé."],
    ["Variante", "Une autre version du même plat (ex. beignes frits vs au four). Les variantes sont regroupées ; basculez entre elles avec les pastilles en haut de la recette."],
    ["Catégorie (tag)", "Étiquette colorée (Déjeuner, Dessert, Soupe…) pour classer et filtrer vos recettes. Vous pouvez créer les vôtres."],
    ["Lien de recette", "Dans une description, un mot peut renvoyer à une autre recette. Touchez-le pour y aller."],
  ] : [
    ["Sous-chef mode", "A simplified cooking view: a checklist of ingredients and large step-by-step instructions with timers. The screen stays awake."],
    ["Variant", "Another version of the same dish (e.g. fried vs baked donuts). Variants are grouped; switch between them with the chips at the top of a recipe."],
    ["Category (tag)", "A colored label (Breakfast, Dessert, Soup…) to organize and filter your recipes. You can create your own."],
    ["Recipe link", "Inside a description, a word can point to another recipe. Tap it to jump there."],
  ];
  const howtos = lang === "fr" ? [
    ["flame", "Cuisiner pas à pas", "Ouvrez une recette puis touchez Mode sous-chef."],
    ["basket", "Composer l'épicerie", "Sur une recette, touchez Ajouter à l'épicerie ; les quantités suivent les portions."],
    ["plus", "Créer une variante", "Sur une recette, touchez Ajouter une variante pour partir d'une copie."],
    ["sliders", "Unités, langue, thème", "Tout se règle dans les Réglages."],
  ] : [
    ["flame", "Cook step-by-step", "Open a recipe, then tap Sous-chef mode."],
    ["basket", "Build your groceries", "On a recipe, tap Add to groceries; amounts follow the servings."],
    ["plus", "Create a variant", "On a recipe, tap Add a variant to start from a copy."],
    ["sliders", "Units, language, theme", "Everything is set in Settings."],
  ];
  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <StickyHeader>
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px 14px" }}>
          <button onClick={() => nav.back()} style={{ width: 40, height: 40, borderRadius: 999, border: "none", background: "transparent", cursor: "pointer", display: "grid", placeItems: "center" }}>
            <Icon name="back" size={th.fs(24)} color={th.ink} />
          </button>
          <h1 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(25), fontWeight: 600, color: th.ink }}>{t("help_title")}</h1>
        </div>
      </StickyHeader>
      <ScreenScroll>
        <div style={{ padding: "16px 16px 0" }}>
          <Group label={t("help_howto")}>
            {howtos.map(([icon, title, body], i) => (
              <div key={i} style={{ display: "flex", gap: 13, padding: "14px 16px", borderBottom: i < howtos.length - 1 ? `1px solid ${th.line}` : "none" }}>
                <span style={{ width: 32, height: 32, borderRadius: 9, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name={icon} size={17} color={th.accent} /></span>
                <div>
                  <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 700, color: th.ink }}>{title}</div>
                  <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), lineHeight: 1.45, color: th.inkSoft, marginTop: 2 }}>{body}</div>
                </div>
              </div>
            ))}
          </Group>
          <Group label={t("help_glossary")}>
            {glossary.map(([term, def], i) => (
              <div key={i} style={{ padding: "14px 16px", borderBottom: i < glossary.length - 1 ? `1px solid ${th.line}` : "none" }}>
                <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(17), fontWeight: 600, color: th.accent }}>{term}</div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), lineHeight: 1.5, color: th.inkSoft, marginTop: 3 }}>{def}</div>
              </div>
            ))}
          </Group>
          <div style={{ textAlign: "center", padding: "4px 0 8px", fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint }}>{t("version")}</div>
        </div>
      </ScreenScroll>
    </div>
  );
}

Object.assign(window, { Segmented, SettingsRow, Group, Toggle, ShoppingScreen, SettingsScreen, EditScreen, AddRowBtn, HelpScreen, TagManager, TagSelector, TempTextarea });
