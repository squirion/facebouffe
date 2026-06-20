/* fb-tablet.jsx — Tablet device frame + left navigation rail.
   The app adapts to tablet sizes via app.layout (computed in fb-app):
   a left rail replaces the bottom tab bar, browse screens become
   multi-column grids, sous-chef and the recipe detail go two-pane in
   landscape. This file provides the bezel + rail chrome only.
   Exports to window: TabletDevice, NavRail. */

// ── Tablet bezel ──────────────────────────────────────────────
// Clean, uniform aluminium-style bezel (no notch). A slim status bar is
// drawn at the top inside the screen; the app pads its own headers by
// insets.top so they clear it. Works at any width/height (portrait or
// landscape) — the camera sits on whichever edge is "top".
function TabletDevice({ children, width = 1194, height = 834, dark = false }) {
  const landscape = width >= height;
  const statusC = dark ? "rgba(255,255,255,0.92)" : "rgba(0,0,0,0.8)";
  return (
    <div style={{
      width, height, borderRadius: 30, padding: 14, boxSizing: "border-box",
      background: dark ? "linear-gradient(150deg,#2a2a2e,#161618)" : "linear-gradient(150deg,#dfe1e5,#c5c8cd)",
      boxShadow: "0 50px 100px rgba(0,0,0,0.28), 0 0 0 1px rgba(0,0,0,0.10)",
      position: "relative",
    }}>
      {/* camera dot on the top edge (long edge in landscape) */}
      <div style={{
        position: "absolute", borderRadius: 999, background: dark ? "#0c0c0e" : "#9aa0a8",
        boxShadow: "inset 0 0 0 2px rgba(0,0,0,0.25)",
        ...(landscape
          ? { left: 6, top: "50%", transform: "translateY(-50%)", width: 7, height: 7 }
          : { top: 6, left: "50%", transform: "translateX(-50%)", width: 7, height: 7 }),
      }} />
      {/* screen */}
      <div style={{
        width: "100%", height: "100%", borderRadius: 18, overflow: "hidden", position: "relative",
        background: dark ? "#0d0b08" : "#F2EFE9", WebkitFontSmoothing: "antialiased",
      }}>
        {/* slim status bar (absolute, app pads under it) */}
        <div style={{
          position: "absolute", top: 0, left: 0, right: 0, height: 26, zIndex: 60,
          display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "0 22px", pointerEvents: "none",
          fontFamily: '-apple-system, system-ui, sans-serif', fontSize: 12.5, fontWeight: 600, color: statusC,
        }}>
          <span>9:41</span>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}>
            <svg width="17" height="11" viewBox="0 0 17 11"><path d="M8.5 2.6c1.9 0 3.6.7 4.9 1.9l.9-.9A8 8 0 0 0 8.5 1 8 8 0 0 0 2.7 3.6l.9.9A7 7 0 0 1 8.5 2.6Z" fill={statusC}/><circle cx="8.5" cy="8.6" r="1.4" fill={statusC}/></svg>
            <svg width="24" height="12" viewBox="0 0 24 12"><rect x="0.5" y="0.5" width="20" height="11" rx="3" stroke={statusC} strokeOpacity="0.5" fill="none"/><rect x="2" y="2" width="15" height="8" rx="1.6" fill={statusC}/><rect x="22" y="4" width="1.5" height="4" rx="0.75" fill={statusC} fillOpacity="0.5"/></svg>
          </span>
        </div>
        {children}
        {/* home indicator */}
        <div style={{ position: "absolute", bottom: 7, left: "50%", transform: "translateX(-50%)", width: landscape ? 150 : 130, height: 5, borderRadius: 100, background: dark ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.22)", zIndex: 60, pointerEvents: "none" }} />
      </div>
    </div>
  );
}

// ── Left navigation rail (tablet replacement for the bottom tab bar) ──
function NavRail({ activeTab, onTab, onAdd, basketCount, pendingCount }) {
  const th = useTheme();
  const app = useApp();
  const { lang, insets } = app;
  const items = [
    ["home", "home", "tab_home"],
    ["search", "search", "tab_search"],
    ["groceries", "basket", "tab_list"],
    ["settings", "sliders", "tab_settings"],
  ];
  const Item = ({ tab, icon, labelKey, badge }) => {
    const on = activeTab === tab;
    return (
      <button onClick={() => onTab(tab)} style={{
        position: "relative", width: 64, padding: "9px 0", borderRadius: 16, border: "none", cursor: "pointer",
        background: on ? th.accentSoft : "transparent",
        display: "flex", flexDirection: "column", alignItems: "center", gap: 5,
      }}>
        <span style={{ position: "relative", display: "grid", placeItems: "center" }}>
          <Icon name={icon} size={25} color={on ? th.accent : th.inkFaint} fill={on && tab === "home"} stroke={on ? 2.2 : 2} />
          {badge > 0 && (
            <span style={{ position: "absolute", top: -5, right: -9, minWidth: 16, height: 16, padding: "0 4px", borderRadius: 999, background: th.accent, color: "#fff", fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center", fontFamily: th.fontUI, boxShadow: `0 0 0 2px ${th.canvas}` }}>{badge}</span>
          )}
        </span>
        <span style={{ fontFamily: th.fontUI, fontSize: 10.5, fontWeight: on ? 700 : 600, color: on ? th.accent : th.inkFaint, letterSpacing: 0.1 }}>{FB.t(lang, labelKey)}</span>
      </button>
    );
  };
  return (
    <div style={{
      width: 92, flexShrink: 0, height: "100%", boxSizing: "border-box",
      paddingTop: insets.top + 16, paddingBottom: insets.bottom + 14,
      display: "flex", flexDirection: "column", alignItems: "center", gap: 8,
      background: th.glass, backdropFilter: "blur(20px) saturate(160%)", WebkitBackdropFilter: "blur(20px) saturate(160%)",
      borderRight: `1px solid ${th.line}`,
    }}>
      {/* brand */}
      <img src="facebouffe-logo.png" alt="" aria-hidden="true" style={{ height: 34, width: 34 * (822 / 696), objectFit: "contain", marginBottom: 6, filter: th.dark ? "none" : "drop-shadow(0 2px 5px rgba(192,86,59,0.28))" }} />
      {/* add (replaces FAB) */}
      <button onClick={onAdd} title={FB.t(lang, "add_method_title")} style={{
        width: 56, height: 56, borderRadius: 18, border: "none", cursor: "pointer", marginBottom: 6,
        background: th.accent, color: "#fff", display: "grid", placeItems: "center",
        boxShadow: "0 8px 20px " + th.accent + "55",
      }}>
        <Icon name="plus" size={26} color="#fff" stroke={2.6} />
      </button>
      {items.map(([tab, icon, key]) => (
        <Item key={tab} tab={tab} icon={icon} labelKey={key}
          badge={tab === "groceries" ? basketCount : tab === "home" && app.account ? 0 : 0} />
      ))}
    </div>
  );
}

Object.assign(window, { TabletDevice, NavRail });
