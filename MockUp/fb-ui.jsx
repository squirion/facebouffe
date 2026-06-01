/* fb-ui.jsx — Theme context, icon set, and shared UI primitives.
   Exposes everything on window for the screen/app files. */

// ──────────────────────────────────────────────────────────────
// Theme
// ──────────────────────────────────────────────────────────────
const ThemeCtx = React.createContext(null);
const useTheme = () => React.useContext(ThemeCtx);

// App-wide context: data, prefs, navigation, mutations. Set on window so the
// separately-transpiled screen scripts can reach the same context object.
const AppCtx = React.createContext(null);
const useApp = () => React.useContext(AppCtx);

const FONT_SCALE = { small: 0.92, medium: 1, large: 1.12 };

function buildTheme(tw) {
  const dark = !!tw.dark;
  const accent = tw.accent || "#C0563B";
  const scale = FONT_SCALE[tw.fontSize] || 1;
  const base = dark
    ? {
        canvas: "#19150F", canvas2: "#211C15", card: "#272019", cardSoft: "#2F271E",
        ink: "#F3ECE1", inkSoft: "#B7AC9D", inkFaint: "#857B6D",
        line: "rgba(255,255,255,0.09)", lineStrong: "rgba(255,255,255,0.16)",
        accentSoft: "rgba(217,115,79,0.18)", shadow: "0 8px 30px rgba(0,0,0,0.5)",
        glass: "rgba(33,28,21,0.82)", scrim: "rgba(0,0,0,0.6)",
      }
    : {
        canvas: "#FBF6EE", canvas2: "#F4ECE0", card: "#FFFFFF", cardSoft: "#FBF6EF",
        ink: "#2B2620", inkSoft: "#736A5E", inkFaint: "#A89E90",
        line: "rgba(43,38,32,0.10)", lineStrong: "rgba(43,38,32,0.16)",
        accentSoft: "rgba(192,86,59,0.10)", shadow: "0 10px 34px rgba(74,55,40,0.13)",
        glass: "rgba(251,246,238,0.82)", scrim: "rgba(40,30,22,0.5)",
      };
  return {
    ...base, dark, accent, scale, gold: "#F4B400",
    fs: (px) => Math.round(px * scale * 100) / 100,
    fontDisplay: '"Newsreader", Georgia, "Times New Roman", serif',
    fontUI: '"Hanken Grotesk", -apple-system, system-ui, sans-serif',
  };
}

// ──────────────────────────────────────────────────────────────
// Icons — simple stroke glyphs (UI + category tags)
// ──────────────────────────────────────────────────────────────
const ICON_PATHS = {
  home: "M3 11.5 12 4l9 7.5M5.5 10v9a1 1 0 0 0 1 1H9v-5.5h6V20h2.5a1 1 0 0 0 1-1v-9",
  search: "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14ZM20 20l-4-4",
  basket: "M5 9 12 3l7 6M3 9h18l-1.4 9.3a2 2 0 0 1-2 1.7H6.4a2 2 0 0 1-2-1.7L3 9ZM9.5 13v3M14.5 13v3",
  sliders: "M4 7h10M18 7h2M4 12h2M10 12h10M4 17h7M15 17h5",
  star: "M12 3.2l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.7 6.7 19.6l1.2-6-4.5-4.1 6-.7L12 3.2Z",
  plus: "M12 5v14M5 12h14",
  minus: "M5 12h14",
  chevL: "M15 4.5 8 12l7 7.5",
  chevR: "M9 4.5 16 12l-7 7.5",
  chevD: "M5 9l7 7 7-7",
  x: "M6 6l12 12M18 6 6 18",
  check: "M5 12.5l4.5 4.5L19 7",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 7.5V12l3 2",
  users: "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7ZM2.5 20v-1.5A4.5 4.5 0 0 1 7 14h4a4.5 4.5 0 0 1 4.5 4.5V20M17 4.3a3.5 3.5 0 0 1 0 6.8M21.5 20v-1.5a4.5 4.5 0 0 0-3.2-4.3",
  flame: "M12 3c.6 3.5 3.8 4.6 3.8 8.2a3.8 3.8 0 0 1-7.6 0c0-1.3.5-2.2 1.2-3 .3 1.4 1.4 1.6 2 .9-.7-1.6-.5-4.2.6-6.1Z",
  pencil: "M4 20l1-4L16 5l3 3L8 19l-4 1ZM14 7l3 3",
  trash: "M4 7h16M10 7V4.8a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1V7M6.5 7l.9 12.2a1 1 0 0 0 1 .8h7.2a1 1 0 0 0 1-.8L18.5 7",
  timer: "M12 21a8 8 0 1 0 0-16 8 8 0 0 0 0 16ZM12 9.5V13M9.5 2.5h5",
  play: "M7 4.5l12 7.5-12 7.5z",
  link: "M9.5 14.5l5-5M10 7l1.3-1.3a3.7 3.7 0 0 1 5.3 5.3L15.2 12M14 17l-1.3 1.3a3.7 3.7 0 0 1-5.3-5.3L8.8 12",
  more: "M5 12h.01M12 12h.01M19 12h.01",
  grip: "M9 6h0M15 6h0M9 12h0M15 12h0M9 18h0M15 18h0",
  camera: "M4 8a2 2 0 0 1 2-2h1.5l1.2-1.8h6.6L18.5 6H20a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8ZM12 16.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z",
  arrowL: "M20 12H4M11 5l-7 7 7 7",
  back: "M15 5l-7 7 7 7",
  note: "M5 4h14v12l-5 4H5z M14 20v-4h5",
  // category tags
  sunrise: "M12 3v3M5 11H2M22 11h-3M5.2 6.2 7 8M18.8 6.2 17 8M3 18h18M7 18a5 5 0 0 1 10 0",
  utensils: "M7 3v18M5 3v5a2 2 0 0 0 2 2 2 2 0 0 0 2-2V3M16 3c-1.5 1-2 4-2 6s.7 2.5 1.5 2.5V21",
  cake: "M4 21h16M5 21v-7a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v7M4 16c1.5-1.5 3 1.5 5 0s3.5 1.5 5 0 3.5 1.5 5 0M12 9V6M12 5.5a.8.8 0 1 0 0-.1Z",
  shrimp: "M17 7c-5-1-11 1-11 6 0 3 3 5 7 4M9 17c4 0 7-2 9-5M17 7a2 2 0 1 0-.1 0M7 21c2 0 3-1 3-3",
  bowl: "M3 11h18a9 9 0 0 1-18 0ZM7 4c-.5 1.2.5 2 0 3.2M11 3c-.5 1.2.5 2 0 3.2M15 4c-.5 1.2.5 2 0 3.2",
  leaf: "M4 20C4 11 11 4 20 4c0 9-7 16-16 16ZM8.5 15.5C11 13 14 11 17.5 9.5",
  dumbbell: "M2 12h2M20 12h2M5.5 8.5h3v7h-3zM15.5 8.5h3v7h-3zM8.5 12h7",
};

function Icon({ name, size = 22, color = "currentColor", stroke = 2, fill = false, style = {} }) {
  const d = ICON_PATHS[name];
  if (!d) return null;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill ? color : "none"}
      stroke={fill ? "none" : color} strokeWidth={stroke} strokeLinecap="round"
      strokeLinejoin="round" style={{ display: "block", flexShrink: 0, ...style }}>
      {d.split("M").filter(Boolean).map((seg, i) => <path key={i} d={"M" + seg} />)}
    </svg>
  );
}

// ──────────────────────────────────────────────────────────────
// Rating stars
// ──────────────────────────────────────────────────────────────
function Stars({ value = 0, size = 16, gap = 2, interactive = false, onChange }) {
  const th = useTheme();
  return (
    <div style={{ display: "flex", gap }}>
      {[1, 2, 3, 4, 5].map((i) => (
        <span key={i}
          onClick={interactive ? () => onChange && onChange(i === value ? 0 : i) : undefined}
          style={{ cursor: interactive ? "pointer" : "default", lineHeight: 0 }}>
          <Icon name="star" size={size} fill={i <= value} color={i <= value ? th.gold : th.inkFaint} />
        </span>
      ))}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────
// Tag chip
// ──────────────────────────────────────────────────────────────
function TagChip({ tag, lang, size = "md", active = false, onClick, showIcon = true }) {
  const th = useTheme();
  if (!tag) return null;
  const name = FB.tagName(tag, lang);
  const pad = size === "sm" ? "3px 9px" : "5px 12px";
  const fontSize = th.fs(size === "sm" ? 12 : 13.5);
  const bg = active ? tag.color : (th.dark ? "rgba(255,255,255,0.06)" : "#fff");
  const fg = active ? "#fff" : th.ink;
  return (
    <button onClick={onClick} style={{
      display: "inline-flex", alignItems: "center", gap: 5, padding: pad,
      borderRadius: 999, border: `1px solid ${active ? tag.color : th.line}`,
      background: bg, color: fg, fontFamily: th.fontUI, fontSize, fontWeight: 600,
      letterSpacing: 0.1, cursor: onClick ? "pointer" : "default", whiteSpace: "nowrap",
      boxShadow: active ? "none" : (th.dark ? "none" : "0 1px 2px rgba(74,55,40,0.05)"),
    }}>
      {showIcon && (
        <span style={{
          width: 16, height: 16, borderRadius: 999, display: "grid", placeItems: "center",
          background: active ? "rgba(255,255,255,0.25)" : tag.color + "22", flexShrink: 0,
        }}>
          <Icon name={tag.icon} size={11} color={active ? "#fff" : tag.color} stroke={2.2} />
        </span>
      )}
      {name}
    </button>
  );
}

// ──────────────────────────────────────────────────────────────
// Fallback tile — deterministic warm color + soft pattern + glyph.
// Used as hero/card art for recipes without a photo.
// ──────────────────────────────────────────────────────────────
function FallbackTile({ recipe, tag, radius = 20, glyphSize = 92, style = {}, children, label }) {
  const pal = FB.fallbackColor(recipe);
  const icon = (tag && tag.icon) || "utensils";
  const initial = (recipe.title || "?").trim()[0].toUpperCase();
  const dots = `radial-gradient(${pal.ink}1f 1.3px, transparent 1.3px)`;
  return (
    <div style={{
      position: "relative", overflow: "hidden", borderRadius: radius,
      background: pal.bg, color: pal.ink, ...style,
    }}>
      {/* soft dot texture */}
      <div style={{ position: "absolute", inset: 0, backgroundImage: dots, backgroundSize: "15px 15px", opacity: 0.5 }} />
      {/* warm sheen */}
      <div style={{ position: "absolute", inset: 0, background: `radial-gradient(120% 90% at 18% 12%, rgba(255,255,255,0.22), transparent 55%)` }} />
      {/* big glyph */}
      <div style={{ position: "absolute", right: -glyphSize * 0.18, bottom: -glyphSize * 0.2, opacity: 0.9 }}>
        <Icon name={icon} size={glyphSize} color={pal.ink} stroke={1.4} style={{ opacity: 0.35 }} />
      </div>
      {/* monogram */}
      <div style={{
        position: "absolute", left: 14, top: 10, fontFamily: '"Newsreader", serif',
        fontSize: glyphSize * 0.5, lineHeight: 1, fontWeight: 500, opacity: 0.92,
      }}>{initial}</div>
      {label && (
        <div style={{
          position: "absolute", left: 14, bottom: 12, fontFamily: "ui-monospace, monospace",
          fontSize: 10.5, letterSpacing: 0.3, opacity: 0.7,
        }}>{label}</div>
      )}
      {children}
    </div>
  );
}

// PhotoDrop — editable per-recipe photo target. Drop or click-to-browse;
// writes to the shared app photo store so the image appears on the hero AND
// in every list tile. Falls back to the deterministic color tile when empty.
function PhotoDrop({ photoId, recipe, tag, height, radius = 0, label, removable = false }) {
  const th = useTheme();
  const app = useApp();
  const inputRef = React.useRef(null);
  const [over, setOver] = React.useState(false);
  const photo = app.recipePhotos && app.recipePhotos[photoId];
  const onFile = (file) => {
    if (!file || !/^image\//.test(file.type)) return;
    const rd = new FileReader();
    rd.onload = () => app.setRecipePhoto(photoId, rd.result);
    rd.readAsDataURL(file);
  };
  return (
    <div
      onClick={() => inputRef.current && inputRef.current.click()}
      onDragOver={(e) => { e.preventDefault(); setOver(true); }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => { e.preventDefault(); setOver(false); onFile(e.dataTransfer.files && e.dataTransfer.files[0]); }}
      style={{ position: "relative", width: "100%", height: height + "px", borderRadius: radius + "px", overflow: "hidden", cursor: "pointer" }}
    >
      {photo
        ? <img src={photo} alt="" style={{ display: "block", width: "100%", height: "100%", objectFit: "cover" }} />
        : <FallbackTile recipe={recipe} tag={tag} radius={radius} glyphSize={Math.min(150, height * 0.7)} style={{ position: "absolute", inset: 0 }} label={label} />}
      <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", pointerEvents: "none" }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 7, padding: "8px 14px", borderRadius: 999, background: "rgba(0,0,0,0.45)", backdropFilter: "blur(8px)", WebkitBackdropFilter: "blur(8px)", color: "#fff", fontFamily: th.fontUI, fontSize: 13, fontWeight: 600, opacity: photo ? 0 : 1, transition: "opacity 0.15s" }}>
          <Icon name="camera" size={16} color="#fff" /> {app.t(photo ? "change_photo" : "add_photo")}
        </span>
      </div>
      {over && <div style={{ position: "absolute", inset: 0, border: "3px dashed #fff", borderRadius: radius + "px", background: "rgba(0,0,0,0.25)", pointerEvents: "none" }} />}
      {photo && removable && (
        <button
          onClick={(e) => { e.stopPropagation(); app.setRecipePhoto(photoId, null); }}
          style={{ position: "absolute", top: 10, right: 10, display: "inline-flex", alignItems: "center", gap: 6, padding: "7px 12px", borderRadius: 999, border: "none", cursor: "pointer", background: "rgba(0,0,0,0.5)", backdropFilter: "blur(8px)", WebkitBackdropFilter: "blur(8px)", color: "#fff", fontFamily: th.fontUI, fontSize: 12.5, fontWeight: 600 }}>
          <Icon name="trash" size={15} color="#fff" /> {app.t("remove_photo")}
        </button>
      )}
      <input ref={inputRef} type="file" accept="image/*" onChange={(e) => { onFile(e.target.files && e.target.files[0]); e.target.value = ""; }} style={{ display: "none" }} />
    </div>
  );
}

// Hero media: shows the recipe's main photo everywhere it's used. On editable
// surfaces (slot=true: recipe hero, edit form) it's a drop/browse target;
// elsewhere (list tiles) it's a read-only image or the color fallback.
function HeroMedia({ recipe, tag, height, radius = 0, slot = true }) {
  const app = useApp();
  const photo = app.recipePhotos && app.recipePhotos[recipe.id];
  if (slot) {
    return <PhotoDrop photoId={recipe.id} recipe={recipe} tag={tag} height={height} radius={radius} label={recipe.heroImage || null} />;
  }
  if (photo) {
    return <img src={photo} alt="" style={{ display: "block", width: "100%", height: height + "px", objectFit: "cover", borderRadius: radius + "px" }} />;
  }
  return <FallbackTile recipe={recipe} tag={tag} radius={radius} glyphSize={Math.min(150, height * 0.7)}
    style={{ width: "100%", height: height + "px" }} label={recipe.heroImage || null} />;
}

// ──────────────────────────────────────────────────────────────
// Rich text — renders free text with two inline chip types:
//   {{link:id}}  → tappable link chip (navigates)
//   {{temp:v:u}} → non-interactive temperature chip (display-converted)
// ──────────────────────────────────────────────────────────────
function TempChip({ value, unit, dark }) {
  const th = useTheme();
  const app = useApp();
  const pref = FB.prefTempUnit(app.prefs);
  return (
    <span style={{
      display: "inline-flex", alignItems: "baseline", padding: "0.04em 0.42em", margin: "0 0.08em",
      borderRadius: 6, border: `1px solid ${(dark ? "#fff" : th.accent)}66`,
      color: dark ? "#fff" : th.accent, fontWeight: 700, fontSize: "0.9em", whiteSpace: "nowrap",
      fontVariantNumeric: "tabular-nums",
    }}>{FB.fmtTemp(value, unit, pref)}</span>
  );
}

function RichText({ text, onLink, dark = false }) {
  const th = useTheme();
  const app = useApp();
  const parts = String(text || "").split(/(\{\{(?:link|temp):[^}]+\}\})/g);
  return (
    <React.Fragment>
      {parts.map((p, i) => {
        const lm = p.match(/^\{\{link:([^}]+)\}\}$/);
        if (lm) {
          const r = app.getRecipe(lm[1]);
          if (!r) return null;
          return (
            <button key={i} onClick={() => onLink && onLink(r.id)} style={{
              border: "none", background: dark ? "rgba(255,255,255,0.16)" : th.accentSoft, padding: "0.04em 0.45em", margin: "0 0.08em",
              cursor: "pointer", borderRadius: 6, fontFamily: "inherit", fontSize: "0.92em", fontWeight: 700,
              color: dark ? "#fff" : th.accent, display: "inline-flex", alignItems: "baseline", gap: 3,
            }}>{r.title}</button>
          );
        }
        const tm = p.match(/^\{\{temp:([0-9.]+):([cfCF])\}\}$/);
        if (tm) return <TempChip key={i} value={tm[1]} unit={tm[2]} dark={dark} />;
        return <span key={i}>{p}</span>;
      })}
    </React.Fragment>
  );
}

// ──────────────────────────────────────────────────────────────
// Meta row (time / servings)
// ──────────────────────────────────────────────────────────────
function MetaPill({ icon, children }) {
  const th = useTheme();
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 5, color: th.inkSoft,
      fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 500 }}>
      <Icon name={icon} size={th.fs(15)} color={th.inkFaint} stroke={2} />
      {children}
    </span>
  );
}

// ──────────────────────────────────────────────────────────────
// Recipe cards
// ──────────────────────────────────────────────────────────────
function primaryTag(recipe, tagsById) {
  const id = (recipe.tags || []).find((t) => t !== "tag-fav");
  return tagsById[id] || tagsById[recipe.tags && recipe.tags[0]] || null;
}

// Large feature card (hero image + title overlaid)
function FeatureCard({ recipe, tagsById, lang, onOpen, isFav }) {
  const th = useTheme();
  const tag = primaryTag(recipe, tagsById);
  return (
    <button onClick={onOpen} style={{
      position: "relative", width: "100%", border: "none", padding: 0, cursor: "pointer",
      borderRadius: 24, overflow: "hidden", background: th.card, textAlign: "left",
      boxShadow: th.shadow, display: "block",
    }}>
      <div style={{ position: "relative" }}>
        <HeroMedia recipe={recipe} tag={tag} height={210} radius={0} slot={false} />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to top, rgba(0,0,0,0.55), rgba(0,0,0,0.05) 55%, transparent)" }} />
        {isFav && (
          <div style={{ position: "absolute", top: 12, right: 12, width: 32, height: 32, borderRadius: 999,
            background: "rgba(0,0,0,0.32)", backdropFilter: "blur(6px)", display: "grid", placeItems: "center" }}>
            <Icon name="star" size={17} fill color={th.gold} />
          </div>
        )}
        <div style={{ position: "absolute", left: 16, bottom: 14, right: 16 }}>
          {tag && (
            <div style={{ display: "inline-flex", alignItems: "center", gap: 5, padding: "3px 9px", borderRadius: 999,
              background: "rgba(255,255,255,0.9)", marginBottom: 8 }}>
              <Icon name={tag.icon} size={12} color={tag.color} stroke={2.2} />
              <span style={{ fontFamily: th.fontUI, fontSize: 11.5, fontWeight: 700, color: "#2B2620", letterSpacing: 0.2 }}>{FB.tagName(tag, lang)}</span>
            </div>
          )}
          <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(27), lineHeight: 1.05, color: "#fff", fontWeight: 500, letterSpacing: 0.2, textShadow: "0 1px 12px rgba(0,0,0,0.4)" }}>{recipe.title}</div>
        </div>
      </div>
    </button>
  );
}

// Horizontal scroll card (compact)
function MiniCard({ recipe, tagsById, lang, onOpen, isFav, width = 156 }) {
  const th = useTheme();
  const tag = primaryTag(recipe, tagsById);
  return (
    <button onClick={onOpen} style={{
      width, flexShrink: 0, border: "none", padding: 0, cursor: "pointer", background: "transparent", textAlign: "left",
    }}>
      <div style={{ position: "relative" }}>
        <HeroMedia recipe={recipe} tag={tag} height={132} radius={18} slot={false} />
        {isFav && (
          <div style={{ position: "absolute", top: 8, right: 8, width: 26, height: 26, borderRadius: 999,
            background: "rgba(0,0,0,0.3)", backdropFilter: "blur(6px)", display: "grid", placeItems: "center" }}>
            <Icon name="star" size={14} fill color={th.gold} />
          </div>
        )}
      </div>
      <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(16.5), lineHeight: 1.12, color: th.ink, fontWeight: 500, marginTop: 8 }}>{recipe.title}</div>
      <div style={{ display: "flex", gap: 10, marginTop: 4 }}>
        <MetaPill icon="clock">{FB.fmtDuration(FB.totalTime(recipe), lang)}</MetaPill>
      </div>
    </button>
  );
}

// List row card (used in search / filtered list)
function ListCard({ recipe, tagsById, lang, onOpen, isFav, variantCount = 0 }) {
  const th = useTheme();
  const tag = primaryTag(recipe, tagsById);
  return (
    <button onClick={onOpen} style={{
      display: "flex", gap: 14, width: "100%", border: "none", textAlign: "left", cursor: "pointer",
      background: th.card, borderRadius: 20, padding: 10, boxShadow: th.shadow, alignItems: "center",
    }}>
      <div style={{ width: 86, height: 86, flexShrink: 0 }}>
        <HeroMedia recipe={recipe} tag={tag} height={86} radius={14} slot={false} />
      </div>
      <div style={{ flex: 1, minWidth: 0, paddingRight: 4 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          {tag && <Icon name={tag.icon} size={13} color={tag.color} stroke={2.2} />}
          <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), fontWeight: 700, color: tag ? tag.color : th.inkSoft, letterSpacing: 0.3, textTransform: "uppercase" }}>{tag ? FB.tagName(tag, lang) : ""}</span>
          {isFav && <Icon name="star" size={13} fill color={th.gold} style={{ marginLeft: "auto" }} />}
        </div>
        <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(18.5), lineHeight: 1.1, color: th.ink, fontWeight: 500, margin: "3px 0 5px" }}>{recipe.title}</div>
        <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
          <MetaPill icon="clock">{FB.fmtDuration(FB.totalTime(recipe), lang)}</MetaPill>
          <MetaPill icon="users">{recipe.servings}</MetaPill>
          {variantCount > 1 && (
            <span style={{ display: "inline-flex", alignItems: "center", gap: 4, padding: "2px 8px", borderRadius: 999, background: th.accentSoft, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 700, whiteSpace: "nowrap" }}>
              {variantCount} {FB.t(lang, "variants").toLowerCase()}
            </span>
          )}
          {variantCount <= 1 && recipe.personal.rating > 0 && <Stars value={recipe.personal.rating} size={th.fs(12)} />}
        </div>
      </div>
    </button>
  );
}

// ──────────────────────────────────────────────────────────────
// Coach mark — single just-in-time tooltip anchored to a control.
// Shows only when `active` and the feature hasn't been seen. Fades
// (reduce-motion aware). Dismiss writes the seen-flag.
// ──────────────────────────────────────────────────────────────
function Coach({ feature, active, text, placement = "top", children, wrapStyle }) {
  const th = useTheme();
  const app = useApp();
  const show = active && !(app.tipsSeen && app.tipsSeen[feature]);
  const fade = app.reduceMotion ? "fbFade 120ms ease both" : "fbFade 240ms ease both";
  const isTop = placement === "top";
  return (
    <div style={{ position: "relative", ...wrapStyle }}>
      {children}
      {show && (
        <React.Fragment>
          <div style={{ position: "absolute", inset: -4, borderRadius: 20, boxShadow: `0 0 0 3px ${th.accent}`, pointerEvents: "none", animation: fade }} />
          <div onClick={(e) => e.stopPropagation()} style={{
            position: "absolute", left: "50%", transform: "translateX(-50%)",
            [isTop ? "bottom" : "top"]: "calc(100% + 12px)", width: 250, maxWidth: "78vw", zIndex: 95,
            background: th.ink, color: th.canvas, borderRadius: 14, padding: "13px 15px",
            boxShadow: "0 14px 34px rgba(0,0,0,0.32)", animation: fade,
          }}>
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), lineHeight: 1.45, fontWeight: 500 }}>{text}</div>
            <button onClick={() => app.markTipSeen(feature)} style={{ marginTop: 11, border: "none", background: th.accent, color: "#fff", borderRadius: 9, padding: "7px 15px", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 700, cursor: "pointer" }}>{app.t("got_it")}</button>
            <div style={{ position: "absolute", left: "50%", transform: "translateX(-50%) rotate(45deg)", [isTop ? "bottom" : "top"]: -5, width: 12, height: 12, background: th.ink }} />
          </div>
        </React.Fragment>
      )}
    </div>
  );
}

Object.assign(window, {
  ThemeCtx, useTheme, AppCtx, useApp, buildTheme, FONT_SCALE,
  Icon, ICON_PATHS, Stars, TagChip, FallbackTile, PhotoDrop, HeroMedia, MetaPill,
  RichText, TempChip, Coach,
  primaryTag, FeatureCard, MiniCard, ListCard,
});
