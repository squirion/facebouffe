/* fb-import.jsx — Phase 1.5 import engine (designed-for; AI tiers mocked).
   Import is split into an ACTION and a CONFIGURATION:
   - Action: the "+" opens a method chooser (Manuellement / lien / photo / texte).
     Non-manual paths run a mocked tiered importer, then ALWAYS land on the
     sectioned Add/Edit screen as a reviewable draft — never a silent save.
   - Configuration: ImportSettings (backend tier + BYOK key + privacy) lives in
     Settings. Attached to window for the app/screen scripts. */

// A believable Québécois draft the mocked importer "produces". Temperatures are
// written as friendly "180 °C" text so the editor's auto-detector tags them.
function importedDraft(method, urlHost) {
  const sourceByMethod = {
    link: urlHost ? ("Importé · " + urlHost) : "Recette importée d'un lien",
    photo: "Importé d'une photo",
    text: "Importé d'un texte",
  };
  return {
    title: "Tarte au sucre",
    description: "Une tarte au sucre cr\u00e9meuse, dor\u00e9e et r\u00e9confortante \u2014 un classique du temps des F\u00eates.",
    source: sourceByMethod[method] || "",
    servings: 8, prepTimeMinutes: 15, cookTimeMinutes: 35,
    tags: ["tag-dessert"], heroImage: "new", gallery: [],
    ingredients: [
      { quantity: 1, unit: null, name: "abaisse de tarte", note: "non cuite" },
      { quantity: 250, unit: "g", name: "cassonade", note: "" },
      { quantity: 250, unit: "ml", name: "cr\u00e8me 35 %", note: "" },
      { quantity: 2, unit: "tbsp", name: "farine tout usage", note: "" },
      { quantity: 1, unit: null, name: "oeuf", note: "" },
      { quantity: 1, unit: "tsp", name: "vanille", note: "" },
    ],
    steps: [
      { text: "Pr\u00e9chauffer le four \u00e0 180 \u00b0C.", image: null, timerSeconds: null },
      { text: "M\u00e9langer la cassonade et la farine, puis incorporer la cr\u00e8me, l'oeuf et la vanille.", image: null, timerSeconds: null },
      { text: "Verser dans l'abaisse et cuire jusqu'\u00e0 ce que le centre soit l\u00e9g\u00e8rement pris.", image: null, timerSeconds: 2100 },
      { text: "Laisser refroidir compl\u00e8tement avant de servir.", image: null, timerSeconds: null },
    ],
    personal: { notes: "", rating: 0, lastCooked: null, madeCount: 0 },
    _imported: method,
  };
}

const IMPORT_METHODS = [
  { key: "manual", icon: "pencil", titleKey: "method_manual", subKey: "method_manual_sub" },
  { key: "link", icon: "link", titleKey: "method_link", subKey: "method_link_sub" },
  { key: "photo", icon: "camera", titleKey: "method_photo", subKey: "method_photo_sub" },
  { key: "text", icon: "note", titleKey: "method_text", subKey: "method_text_sub" },
];

// Bottom-sheet overlay covering the device frame. `flow` is null | {stage}.
function ImportOverlay({ flow, setFlow }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const close = () => setFlow(null);
  if (!flow) return null;
  const fade = app.reduceMotion ? "fbFade 120ms ease both" : "fbFade 200ms ease both";
  const slide = app.reduceMotion ? "fbFade 120ms ease both" : "fbSheetUp 280ms cubic-bezier(0.32,0.72,0,1) both";
  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 80, display: "flex", flexDirection: "column", justifyContent: "flex-end", alignItems: app.layout.tablet ? "center" : "stretch", animation: fade }}>
      <div onClick={close} style={{ position: "absolute", inset: 0, background: th.scrim }} />
      <div style={{ position: "relative", width: "100%", maxWidth: app.layout.tablet ? 560 : undefined, background: th.canvas, borderTopLeftRadius: 26, borderTopRightRadius: 26, borderBottomLeftRadius: app.layout.tablet ? 26 : 0, borderBottomRightRadius: app.layout.tablet ? 26 : 0, marginBottom: app.layout.tablet ? app.insets.bottom + 14 : 0, paddingBottom: app.insets.bottom + 14, boxShadow: "0 -16px 40px rgba(0,0,0,0.28)", animation: slide, maxHeight: "92%", overflowY: "auto" }} className="fb-scroll">
        <div style={{ display: "flex", justifyContent: "center", paddingTop: 10 }}>
          <div style={{ width: 40, height: 5, borderRadius: 99, background: th.lineStrong }} />
        </div>
        {flow.stage === "choose" ? <ChooseStage app={app} th={th} setFlow={setFlow} close={close} />
          : <InputStage app={app} th={th} method={flow.method} setFlow={setFlow} close={close} />}
      </div>
    </div>
  );
}

function ChooseStage({ app, th, setFlow, close }) {
  const { t, lang } = app;
  const pick = (key) => {
    if (key === "manual") { close(); app.nav.add(); return; }
    setFlow({ stage: "input", method: key });
  };
  return (
    <div style={{ padding: "14px 18px 6px" }}>
      <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(24), fontWeight: 600, color: th.ink, marginBottom: 4 }}>{t("add_method_title")}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 14 }}>
        {IMPORT_METHODS.map((m) => (
          <button key={m.key} onClick={() => pick(m.key)} style={{
            display: "flex", alignItems: "center", gap: 14, width: "100%", textAlign: "left", cursor: "pointer",
            border: `1px solid ${m.key === "manual" ? th.accent : th.line}`, background: m.key === "manual" ? th.accentSoft : th.card,
            borderRadius: 18, padding: "14px 16px", boxShadow: m.key === "manual" ? "none" : th.shadow,
          }}>
            <span style={{ width: 44, height: 44, borderRadius: 13, flexShrink: 0, display: "grid", placeItems: "center", background: m.key === "manual" ? th.accent : th.accentSoft }}>
              <Icon name={m.icon} size={21} color={m.key === "manual" ? "#fff" : th.accent} />
            </span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 700, color: th.ink }}>{t(m.titleKey)}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft, marginTop: 1 }}>{t(m.subKey)}</div>
            </div>
            <Icon name="chevR" size={th.fs(18)} color={th.inkFaint} />
          </button>
        ))}
      </div>
      <div style={{ display: "flex", gap: 8, alignItems: "flex-start", margin: "14px 4px 4px" }}>
        <Icon name="search" size={15} color={th.inkFaint} style={{ flexShrink: 0, marginTop: 1 }} />
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), color: th.inkFaint, lineHeight: 1.45 }}>{t("import_share_note")}</div>
      </div>
    </div>
  );
}

function InputStage({ app, th, method, setFlow, close }) {
  const { t, lang } = app;
  const cfg = app.importCfg;
  const [value, setValue] = React.useState("");
  const [hasPhoto, setHasPhoto] = React.useState(false);
  const [phase, setPhase] = React.useState("input"); // input | analyzing
  const meta = IMPORT_METHODS.find((m) => m.key === method);
  // Tier 0 (structured parse) is always tried first for links; other inputs use
  // the configured engine, falling back if it's unavailable on this device/keys.
  const eff = method === "link" ? "tier0" : effectiveBackend(cfg, app.onDeviceAI);

  const runLabel = eff === "tier0" ? t("import_reading_web")
    : eff === "byok" ? t("import_byok_run") : t("import_ondevice_run");
  const tierBadge = eff === "tier0" ? "Tier 0 · " + t("import_tier0")
    : eff === "byok" ? "Tier 2 · " + t("import_byok") : "Tier 1 · " + t("import_ondevice");

  const ready = method === "photo" ? hasPhoto : value.trim().length > 0;

  const doImport = () => {
    let host = null;
    if (method === "link") { try { host = new URL(value.trim()).host.replace(/^www\./, ""); } catch (e) { host = null; } }
    const draft = importedDraft(method, host);
    setPhase("analyzing");
    const delay = app.reduceMotion ? 200 : 1300;
    setTimeout(() => { close(); app.nav.add(draft); }, delay);
  };

  return (
    <div style={{ padding: "10px 18px 6px" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
        <button onClick={() => setFlow({ stage: "choose" })} disabled={phase === "analyzing"} style={{ width: 36, height: 36, borderRadius: 999, border: `1px solid ${th.line}`, background: th.card, cursor: "pointer", display: "grid", placeItems: "center", flexShrink: 0, opacity: phase === "analyzing" ? 0.4 : 1 }}>
          <Icon name="back" size={18} color={th.inkSoft} />
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(20), fontWeight: 600, color: th.ink, lineHeight: 1.1 }}>{t(meta.titleKey)}</div>
        </div>
        <span style={{ padding: "4px 10px", borderRadius: 999, background: th.accentSoft, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 700, whiteSpace: "nowrap" }}>{tierBadge}</span>
      </div>

      {phase === "analyzing" ? (
        <div style={{ padding: "30px 10px 36px", textAlign: "center" }}>
          <div className="fb-spin" style={{ width: 46, height: 46, margin: "0 auto 18px", borderRadius: 999, border: `3px solid ${th.line}`, borderTopColor: th.accent }} />
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 700, color: th.ink }}>{runLabel}</div>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint, marginTop: 6, lineHeight: 1.45, maxWidth: 260, marginLeft: "auto", marginRight: "auto" }}>
            {lang === "fr" ? "Validation du r\u00e9sultat selon le sch\u00e9ma, puis ouverture de l'\u00e9diteur pour r\u00e9vision." : "Validating the result against the schema, then opening the editor for review."}
          </div>
        </div>
      ) : (
        <>
          {method === "link" && (
            <div style={{ display: "flex", alignItems: "center", gap: 9, background: th.card, border: `1px solid ${th.line}`, borderRadius: 14, padding: "0 12px", height: 50, boxShadow: th.shadow }}>
              <Icon name="link" size={th.fs(18)} color={th.inkFaint} />
              <input value={value} onChange={(e) => setValue(e.target.value)} placeholder={t("import_link_ph")} inputMode="url" style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), color: th.ink, minWidth: 0 }} />
            </div>
          )}
          {method === "text" && (
            <textarea value={value} onChange={(e) => setValue(e.target.value)} placeholder={t("import_text_ph")} rows={6} style={{ width: "100%", boxSizing: "border-box", border: `1px solid ${th.line}`, borderRadius: 14, background: th.card, padding: "12px 14px", fontFamily: th.fontUI, fontSize: th.fs(15), color: th.ink, outline: "none", resize: "vertical", lineHeight: 1.5, boxShadow: th.shadow }} />
          )}
          {method === "photo" && (
            <button onClick={() => setHasPhoto(true)} style={{ width: "100%", height: 168, borderRadius: 16, border: `2px dashed ${hasPhoto ? th.accent : th.lineStrong}`, background: hasPhoto ? th.accentSoft : th.card, cursor: "pointer", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
              <span style={{ width: 52, height: 52, borderRadius: 999, background: hasPhoto ? th.accent : th.accentSoft, display: "grid", placeItems: "center" }}>
                <Icon name={hasPhoto ? "check" : "camera"} size={24} color={hasPhoto ? "#fff" : th.accent} />
              </span>
              <span style={{ fontFamily: th.fontUI, fontSize: th.fs(14), fontWeight: 600, color: hasPhoto ? th.accent : th.inkSoft, textAlign: "center", padding: "0 20px" }}>
                {hasPhoto ? (lang === "fr" ? "Photo pr\u00eate" : "Photo ready") : t("import_photo_drop")}
              </span>
            </button>
          )}

          {/* sample helper */}
          <button onClick={() => { if (method === "photo") setHasPhoto(true); else setValue(method === "link" ? "https://www.ricardocuisine.ca/recettes/tarte-au-sucre" : "Tarte au sucre\n8 portions\n\n1 abaisse de tarte\n250 g cassonade\n250 ml cr\u00e8me 35 %\n2 c. \u00e0 soupe farine\n1 oeuf\n1 c. \u00e0 th\u00e9 vanille\n\nPr\u00e9chauffer le four \u00e0 180 \u00b0C\u2026"); }}
            style={{ marginTop: 10, display: "inline-flex", alignItems: "center", gap: 7, border: "none", background: "transparent", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600, color: th.accent }}>
            <Icon name="plus" size={14} color={th.accent} stroke={2.4} /> {t("import_use_sample")}
          </button>

          <button onClick={doImport} disabled={!ready} style={{
            width: "100%", height: 52, marginTop: 16, borderRadius: 15, border: "none", cursor: ready ? "pointer" : "default",
            background: ready ? th.accent : th.line, color: ready ? "#fff" : th.inkFaint,
            fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
          }}>
            <Icon name="plus" size={th.fs(19)} color={ready ? "#fff" : th.inkFaint} stroke={2.4} /> {t("import_run")}
          </button>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint, lineHeight: 1.45, margin: "10px 2px 4px", textAlign: "center" }}>
            {lang === "fr" ? "Le r\u00e9sultat ouvre toujours l'\u00e9diteur \u2014 rien n'est enregistr\u00e9 sans votre validation." : "The result always opens the editor — nothing is saved without your confirmation."}
          </div>
        </>
      )}
    </div>
  );
}

// ── Engine availability ───────────────────────────────────────
const IMPORT_PROVIDERS = [
  { key: "claude", label: "Claude" },
  { key: "gemini", label: "Gemini" },
  { key: "chatgpt", label: "ChatGPT" },
];
function anyImportKey(cfg) { return !!(cfg && cfg.keys && Object.values(cfg.keys).some((k) => k && k.trim())); }
function engineAvailable(key, cfg, onDeviceAI) {
  if (key === "tier0") return true;
  if (key === "ondevice") return !!onDeviceAI;
  if (key === "byok") return anyImportKey(cfg);
  return false;
}
function effectiveBackend(cfg, onDeviceAI) {
  return engineAvailable(cfg.backend, cfg, onDeviceAI) ? cfg.backend : "tier0";
}

// Settings — import configuration. Config only; the import action lives on "+".
function ImportSettings() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const cfg = app.importCfg;
  const tiers = [
    { key: "tier0", title: t("import_tier0"), sub: t("import_tier0_sub") },
    { key: "ondevice", title: t("import_ondevice"), sub: t("import_ondevice_sub"), reason: !app.onDeviceAI ? t("ondevice_unsupported") : null },
    { key: "byok", title: t("import_byok"), sub: t("import_byok_sub"), reason: !anyImportKey(cfg) ? t("byok_disabled") : null },
  ];
  // Don't leave a now-unavailable engine selected (keys deleted / device flips).
  React.useEffect(() => {
    if (!engineAvailable(cfg.backend, cfg, app.onDeviceAI)) app.setImportCfg({ backend: "tier0" });
  }, [cfg.backend, app.onDeviceAI, anyImportKey(cfg)]);

  return (
    <React.Fragment>
      <div style={{ padding: "12px 16px 6px", fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4 }}>{t("default_import_engine")}</div>
      {tiers.map((tier) => {
        const disabled = !!tier.reason;
        const on = cfg.backend === tier.key && !disabled;
        return (
          <div key={tier.key} style={{ borderBottom: `1px solid ${th.line}` }}>
            <button onClick={() => !disabled && app.setImportCfg({ backend: tier.key })} disabled={disabled} style={{
              display: "flex", alignItems: "flex-start", gap: 12, width: "100%", textAlign: "left", cursor: disabled ? "default" : "pointer",
              border: "none", background: "transparent", padding: "13px 16px", opacity: disabled ? 0.5 : 1,
            }}>
              <span style={{ width: 22, height: 22, borderRadius: 999, flexShrink: 0, marginTop: 1, border: `2px solid ${on ? th.accent : th.lineStrong}`, background: on ? th.accent : "transparent", display: "grid", placeItems: "center" }}>
                {on && <span style={{ width: 8, height: 8, borderRadius: 999, background: "#fff" }} />}
              </span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
                  <span style={{ fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: th.ink }}>{tier.title}</span>
                  {disabled && <Icon name="x" size={13} color={th.inkFaint} />}
                </div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkSoft, marginTop: 2, lineHeight: 1.4 }}>{tier.sub}</div>
                {disabled && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), color: "#9a6c1e", marginTop: 5, lineHeight: 1.4, fontWeight: 600 }}>{tier.reason}</div>}
              </div>
            </button>
          </div>
        );
      })}

      <div style={{ display: "flex", gap: 9, padding: "13px 16px", alignItems: "flex-start" }}>
        <Icon name="note" size={15} color={th.inkFaint} style={{ flexShrink: 0, marginTop: 1 }} />
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), color: th.inkFaint, lineHeight: 1.5 }}>{t("import_privacy")}</div>
      </div>
    </React.Fragment>
  );
}

// Settings — per-provider API key configuration (BYOK). Select a provider,
// paste a key, test it, or delete it.
function ApiKeyManager() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const cfg = app.importCfg;
  const provider = cfg.provider || "claude";
  const key = (cfg.keys && cfg.keys[provider]) || "";
  const [test, setTest] = React.useState(null); // null | testing | valid | invalid | empty
  React.useEffect(() => { setTest(null); }, [provider]);

  const runTest = () => {
    if (!key.trim()) { setTest("empty"); return; }
    setTest("testing");
    setTimeout(() => setTest(key.trim().length >= 8 ? "valid" : "invalid"), app.reduceMotion ? 150 : 900);
  };
  const status = {
    testing: { color: th.inkSoft, icon: null, label: t("key_testing") },
    valid: { color: "#4f7d4c", icon: "check", label: t("key_valid") },
    invalid: { color: "#C0563B", icon: "x", label: t("key_invalid") },
    empty: { color: "#9a6c1e", icon: "note", label: t("key_empty") },
  }[test];

  return (
    <React.Fragment>
      {/* provider selector */}
      <div style={{ padding: "12px 16px 4px", fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4 }}>{t("provider")}</div>
      <div style={{ padding: "0 16px 12px" }}>
        <div style={{ display: "flex", gap: 3, background: th.dark ? "rgba(255,255,255,0.06)" : th.canvas2, borderRadius: 12, padding: 3 }}>
          {IMPORT_PROVIDERS.map((p) => {
            const on = provider === p.key;
            const has = (cfg.keys && cfg.keys[p.key] && cfg.keys[p.key].trim());
            return (
              <button key={p.key} onClick={() => app.setImportCfg({ provider: p.key })} style={{
                flex: 1, padding: "9px 6px", borderRadius: 9, border: "none", cursor: "pointer",
                background: on ? th.card : "transparent", color: on ? th.ink : th.inkSoft,
                fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: on ? 700 : 600,
                boxShadow: on ? th.shadow : "none", display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 5,
              }}>
                {p.label}
                {has && <span style={{ width: 6, height: 6, borderRadius: 999, background: "#6BA368" }} />}
              </button>
            );
          })}
        </div>
      </div>

      {/* key field */}
      <div style={{ padding: "0 16px 12px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, background: th.canvas2, border: `1px solid ${th.line}`, borderRadius: 12, padding: "0 12px", height: 46 }}>
          <Icon name="link" size={16} color={th.inkFaint} />
          <input type="password" value={key} onChange={(e) => { app.setImportKey(provider, e.target.value); }} placeholder={t("import_key_ph")} style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: "ui-monospace, monospace", fontSize: th.fs(14), color: th.ink, minWidth: 0, letterSpacing: 1 }} />
        </div>

        {/* status line */}
        {status && (
          <div style={{ display: "flex", alignItems: "center", gap: 7, marginTop: 9, fontFamily: th.fontUI, fontSize: th.fs(12.5), fontWeight: 600, color: status.color }}>
            {test === "testing"
              ? <span className="fb-spin" style={{ width: 14, height: 14, borderRadius: 999, border: `2px solid ${th.line}`, borderTopColor: th.inkSoft, flexShrink: 0 }} />
              : <Icon name={status.icon} size={14} color={status.color} stroke={2.4} />}
            {status.label}
          </div>
        )}

        {/* actions */}
        <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
          <button onClick={runTest} disabled={test === "testing"} style={{ flex: 1, height: 42, borderRadius: 11, border: "none", cursor: test === "testing" ? "default" : "pointer", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(14), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 7 }}>
            <Icon name="check" size={th.fs(16)} color="#fff" stroke={2.4} /> {t("test_key")}
          </button>
          <button onClick={() => { app.setImportKey(provider, ""); setTest(null); }} disabled={!key.trim()} style={{ height: 42, padding: "0 16px", borderRadius: 11, border: `1px solid ${th.line}`, cursor: key.trim() ? "pointer" : "default", background: "transparent", color: key.trim() ? "#C0563B" : th.inkFaint, opacity: key.trim() ? 1 : 0.5, fontFamily: th.fontUI, fontSize: th.fs(14), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 7 }}>
            <Icon name="trash" size={th.fs(16)} color={key.trim() ? "#C0563B" : th.inkFaint} /> {t("delete_key")}
          </button>
        </div>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, { ImportOverlay, ImportSettings, ApiKeyManager, importedDraft, effectiveBackend, engineAvailable, anyImportKey });
