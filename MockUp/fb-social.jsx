/* fb-social.jsx — Phase 2 social layer: sign-in, account, friends, friend
   cookbooks, steal/link/fork controls, reviews, and the steal/migration sheets.
   Recipe-page modes (visiting / own+sharing / linked) are composed from the
   small controls exported here and wired into fb-screens-recipe.jsx.
   Everything attached to window for the cross-file React layer. */

// ── shared chrome ─────────────────────────────────────────────
function PushHeader({ title, onBack, accent, right }) {
  const th = useTheme();
  const app = useApp();
  return (
    <StickyHeader>
      <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px 14px" }}>
        <button onClick={onBack || (() => app.nav.back())} style={{ width: 40, height: 40, borderRadius: 999, border: "none", background: "transparent", cursor: "pointer", display: "grid", placeItems: "center" }}>
          <Icon name="back" size={th.fs(24)} color={th.ink} />
        </button>
        <h1 style={{ margin: 0, flex: 1, fontFamily: th.fontDisplay, fontSize: th.fs(25), fontWeight: 600, color: accent || th.ink }}>{title}</h1>
        {right}
      </div>
    </StickyHeader>
  );
}

// Bottom-sheet shell mirroring the import overlay's motion.
function SheetShell({ onClose, children }) {
  const th = useTheme();
  const app = useApp();
  const slide = app.reduceMotion ? "fbFade 120ms ease both" : "fbSheetUp 280ms cubic-bezier(0.32,0.72,0,1) both";
  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 85, display: "flex", flexDirection: "column", justifyContent: "flex-end", alignItems: app.layout.tablet ? "center" : "stretch", animation: app.reduceMotion ? "fbFade 120ms ease both" : "fbFade 200ms ease both" }}>
      <div onClick={onClose} style={{ position: "absolute", inset: 0, background: th.scrim }} />
      <div style={{ position: "relative", width: "100%", maxWidth: app.layout.tablet ? 560 : undefined, background: th.canvas, borderTopLeftRadius: 26, borderTopRightRadius: 26, borderBottomLeftRadius: app.layout.tablet ? 26 : 0, borderBottomRightRadius: app.layout.tablet ? 26 : 0, marginBottom: app.layout.tablet ? app.insets.bottom + 14 : 0, paddingBottom: app.insets.bottom + 16, boxShadow: "0 -16px 40px rgba(0,0,0,0.28)", animation: slide, maxHeight: "90%", overflowY: "auto" }} className="fb-scroll">
        <div style={{ display: "flex", justifyContent: "center", paddingTop: 10 }}>
          <div style={{ width: 40, height: 5, borderRadius: 99, background: th.lineStrong }} />
        </div>
        {children}
      </div>
    </div>
  );
}

function PrimaryBtn({ label, icon, onClick, disabled, tone }) {
  const th = useTheme();
  const bg = disabled ? th.line : (tone || th.accent);
  return (
    <button onClick={disabled ? undefined : onClick} disabled={disabled} style={{
      width: "100%", height: 52, borderRadius: 15, border: "none", cursor: disabled ? "default" : "pointer",
      background: bg, color: disabled ? th.inkFaint : "#fff", fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 700,
      display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
    }}>
      {icon && <Icon name={icon} size={th.fs(19)} color={disabled ? th.inkFaint : "#fff"} />} {label}
    </button>
  );
}

// ── Sign-in (Connexion) ───────────────────────────────────────
function SignInScreen() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const [email, setEmail] = React.useState("");
  const [sent, setSent] = React.useState(false);
  const valid = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim());

  const complete = () => {
    const res = app.social.signInComplete(email.trim());
    if (res === "needs_username") app.nav.go("username", { email: email.trim() });
    else app.nav.back();
  };

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <PushHeader title={t("signin")} />
      <ScreenScroll>
        <div style={{ padding: "8px 22px 0" }}>
          <div style={{ display: "flex", justifyContent: "center", margin: "18px 0 22px" }}>
            <div style={{ width: 76, height: 76, borderRadius: 24, background: th.accentSoft, display: "grid", placeItems: "center" }}>
              <Icon name="users" size={36} color={th.accent} />
            </div>
          </div>

          {!sent ? (
            <>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), lineHeight: 1.5, color: th.inkSoft, textAlign: "center", marginBottom: 22 }}>{t("signin_intro")}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 7 }}>{t("email_label")}</div>
              <div style={{ display: "flex", alignItems: "center", gap: 9, background: th.card, border: `1px solid ${th.line}`, borderRadius: 14, padding: "0 12px", height: 50, boxShadow: th.shadow }}>
                <Icon name="mail" size={th.fs(18)} color={th.inkFaint} />
                <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder={t("email_ph")} inputMode="email" autoCapitalize="off" style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), color: th.ink, minWidth: 0 }} />
              </div>
              <div style={{ marginTop: 18 }}>
                <PrimaryBtn label={t("send_magic")} icon="mail" disabled={!valid} onClick={() => setSent(true)} />
              </div>
              <div style={{ display: "flex", gap: 9, alignItems: "flex-start", margin: "18px 4px 0" }}>
                <Icon name="lock" size={15} color={th.inkFaint} style={{ flexShrink: 0, marginTop: 1 }} />
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint, lineHeight: 1.5 }}>{t("signin_local_note")}</div>
              </div>
            </>
          ) : (
            <>
              <div style={{ textAlign: "center" }}>
                <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(24), fontWeight: 600, color: th.ink }}>{t("magic_sent_title")}</div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.inkSoft, marginTop: 8, lineHeight: 1.5 }}>{t("magic_sent_sub")} <strong style={{ color: th.ink }}>{email.trim()}</strong></div>
              </div>
              <div style={{ marginTop: 26 }}>
                <PrimaryBtn label={t("magic_open")} icon="check" onClick={complete} />
              </div>
              <div style={{ display: "flex", justifyContent: "center", gap: 18, marginTop: 16 }}>
                <button onClick={() => setSent(true)} style={{ border: "none", background: "none", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600, color: th.accent }}>{t("magic_resend")}</button>
                <button onClick={() => setSent(false)} style={{ border: "none", background: "none", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600, color: th.inkSoft }}>{t("magic_change_email")}</button>
              </div>
            </>
          )}
        </div>
      </ScreenScroll>
    </div>
  );
}

// ── Username setup (first sign-in only) ───────────────────────
function UsernameSetupScreen({ route }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const email = (route && route.email) || "";
  const [val, setVal] = React.useState("");
  const [status, setStatus] = React.useState("idle"); // idle|checking|available|taken|invalid
  const TAKEN = ["marie", "leo", "sophie", "ahmed", "juliette", "marco", "demo", "admin"];

  React.useEffect(() => {
    const h = val.trim().toLowerCase();
    if (!h) { setStatus("idle"); return; }
    if (!/^[a-z0-9_]{3,20}$/.test(h)) { setStatus("invalid"); return; }
    setStatus("checking");
    const id = setTimeout(() => setStatus(TAKEN.includes(h) ? "taken" : "available"), 480);
    return () => clearTimeout(id);
  }, [val]);

  const msg = {
    checking: { color: th.inkSoft, icon: null, label: t("username_checking") },
    available: { color: "#4f7d4c", icon: "check", label: t("username_available") },
    taken: { color: "#C0563B", icon: "x", label: t("username_taken") },
    invalid: { color: "#9a6c1e", icon: "note", label: t("username_invalid") },
  }[status];

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <PushHeader title={t("choose_username")} />
      <ScreenScroll>
        <div style={{ padding: "14px 22px 0" }}>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15), lineHeight: 1.5, color: th.inkSoft, marginBottom: 22 }}>{t("username_intro")}</div>
          <div style={{ display: "flex", alignItems: "center", gap: 6, background: th.card, border: `1px solid ${status === "taken" ? "#C0563B" : status === "available" ? "#6BA368" : th.line}`, borderRadius: 14, padding: "0 14px", height: 54, boxShadow: th.shadow }}>
            <span style={{ fontFamily: th.fontDisplay, fontSize: th.fs(22), color: th.inkFaint }}>@</span>
            <input autoFocus value={val} onChange={(e) => setVal(e.target.value.toLowerCase())} placeholder={t("add_friend_ph")} autoCapitalize="off" style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink, minWidth: 0 }} />
            {msg && (msg.icon
              ? <Icon name={msg.icon} size={20} color={msg.color} stroke={2.6} />
              : <span className="fb-spin" style={{ width: 16, height: 16, borderRadius: 999, border: `2px solid ${th.line}`, borderTopColor: th.inkSoft }} />)}
          </div>
          {msg && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600, color: msg.color, margin: "9px 2px 0" }}>{status === "available" ? "✓ @" + val.trim() + " " + msg.label : msg.label}</div>}
          <div style={{ display: "flex", gap: 8, alignItems: "center", margin: "16px 2px 0", padding: "10px 13px", borderRadius: 12, background: th.cardSoft, border: `1px solid ${th.line}` }}>
            <Icon name="lock" size={15} color={th.inkFaint} />
            <span style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkSoft, fontWeight: 600 }}>{t("username_permanent")}</span>
          </div>
          <div style={{ marginTop: 22 }}>
            <PrimaryBtn label={t("continue_btn")} icon="check" disabled={status !== "available"} onClick={() => { app.social.finishSignup(val.trim(), email); app.nav.switchTab("home"); }} />
          </div>
        </div>
      </ScreenScroll>
    </div>
  );
}

// ── Account ───────────────────────────────────────────────────
function AccountScreen() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const acct = app.account;
  const [confirm, setConfirm] = React.useState(false);
  if (!acct) return null;

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <PushHeader title={t("account")} />
      <ScreenScroll>
        <div style={{ padding: "16px 16px 0" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14, background: th.card, borderRadius: 20, padding: 16, boxShadow: th.shadow, marginBottom: 22 }}>
            <Avatar name={acct.username} color={th.accent} size={56} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>@{acct.username}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkSoft }}>{acct.email}</div>
            </div>
          </div>

          <Group label={t("account_sync")}>
            <div style={{ display: "flex", alignItems: "center", gap: 11, padding: "14px 18px" }}>
              <span style={{ width: 10, height: 10, borderRadius: 999, background: "#6BA368", boxShadow: "0 0 8px #6BA368", flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 600, color: th.ink }}>{t("sync_synced")}</div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint }}>{t("sync_ago")}</div>
              </div>
              <Icon name="refresh" size={th.fs(18)} color={th.inkFaint} />
            </div>
          </Group>

          {app.social.localOnlyCount > 0 && (
            <Group label={t("migration_title")}>
              <button onClick={() => app.social.setMigrationPending(true)} style={{ display: "flex", alignItems: "center", gap: 13, width: "100%", border: "none", background: "transparent", cursor: "pointer", padding: "14px 18px", textAlign: "left" }}>
                <span style={{ width: 30, height: 30, borderRadius: 9, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="refresh" size={17} color={th.accent} /></span>
                <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 600, color: th.ink }}>{app.social.localOnlyCount} {t("shared_recipes").replace(lang === "fr" ? "partagées" : "shared ", lang === "fr" ? "locales" : "")}</span>
                <Icon name="chevR" size={th.fs(17)} color={th.inkFaint} />
              </button>
            </Group>
          )}

          <Group label={" "}>
            <button onClick={() => setConfirm(true)} style={{ display: "flex", alignItems: "center", gap: 13, width: "100%", border: "none", background: "transparent", cursor: "pointer", padding: "14px 18px", textAlign: "left" }}>
              <span style={{ width: 30, height: 30, borderRadius: 9, background: "#C0563B18", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="logout" size={17} color="#C0563B" /></span>
              <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 600, color: "#C0563B" }}>{t("signout")}</span>
            </button>
          </Group>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint, lineHeight: 1.5, padding: "0 6px" }}>{t("signout_note")}</div>
        </div>
      </ScreenScroll>

      {confirm && (
        <SheetShell onClose={() => setConfirm(false)}>
          <div style={{ padding: "12px 20px 4px" }}>
            <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink, marginBottom: 6 }}>{t("signout_confirm")}</div>
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14), color: th.inkSoft, lineHeight: 1.5, marginBottom: 18 }}>{t("signout_note")}</div>
            <PrimaryBtn label={t("signout")} icon="logout" tone="#C0563B" onClick={() => { setConfirm(false); app.social.signOut(); app.nav.switchTab("home"); }} />
            <button onClick={() => setConfirm(false)} style={{ width: "100%", height: 46, marginTop: 10, border: "none", background: "transparent", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: th.inkSoft }}>{t("cancel")}</button>
          </div>
        </SheetShell>
      )}
    </div>
  );
}

// ── Friends hub (Amis) ────────────────────────────────────────
function FriendRow({ p, onTap, action }) {
  const th = useTheme();
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 16px", borderBottom: `1px solid ${th.line}` }}>
      <button onClick={onTap} disabled={!onTap} style={{ display: "flex", alignItems: "center", gap: 12, flex: 1, minWidth: 0, border: "none", background: "transparent", cursor: onTap ? "pointer" : "default", textAlign: "left", padding: 0 }}>
        <Avatar name={p.name} color={p.color} size={42} />
        <div style={{ minWidth: 0 }}>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 600, color: th.ink }}>{p.name}</div>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint }}>@{p.username}</div>
        </div>
      </button>
      {action}
    </div>
  );
}

function FriendsScreen() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const S = app.social;
  const [handle, setHandle] = React.useState("");
  const [flash, setFlash] = React.useState(null);
  const [menuFor, setMenuFor] = React.useState(null);

  const submit = () => {
    if (!handle.trim()) return;
    const res = S.sendRequest(handle);
    if (res.error === "notfound") setFlash({ tone: "#C0563B", text: t("user_not_found") });
    else if (res.error === "already") setFlash({ tone: th.inkSoft, text: t("already_friend") });
    else if (res.ok) { setFlash({ tone: "#4f7d4c", text: t("request_sent") + " @" + res.profile.username }); setHandle(""); }
    setTimeout(() => setFlash(null), 2200);
  };

  const tipFriend = !app.tipsSeen.firstFriend && S.friends.length > 0;

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <PushHeader title={t("social_friends")} onBack={() => app.nav.home()} />
      <ScreenScroll>
        <div style={{ padding: "16px 16px 0" }}>
          {/* add friend */}
          <Group label={t("add_friend")}>
            <div style={{ padding: "12px 14px" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, background: th.canvas2, border: `1px solid ${th.line}`, borderRadius: 12, padding: "0 12px", height: 48 }}>
                <span style={{ fontFamily: th.fontDisplay, fontSize: th.fs(19), color: th.inkFaint }}>@</span>
                <input value={handle} onChange={(e) => setHandle(e.target.value.toLowerCase())} onKeyDown={(e) => e.key === "Enter" && submit()} placeholder={t("add_friend_ph")} autoCapitalize="off" style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15.5), color: th.ink, minWidth: 0 }} />
                <button onClick={submit} disabled={!handle.trim()} style={{ height: 36, padding: "0 14px", borderRadius: 10, border: "none", cursor: handle.trim() ? "pointer" : "default", background: handle.trim() ? th.accent : th.line, color: handle.trim() ? "#fff" : th.inkFaint, fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700 }}>{t("send_request")}</button>
              </div>
              {flash && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600, color: flash.tone, marginTop: 9 }}>{flash.text}</div>}
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint, marginTop: 9, lineHeight: 1.4 }}>{lang === "fr" ? "Essayez « juliette » ou « marco »." : "Try \u201cjuliette\u201d or \u201cmarco\u201d."}</div>
            </div>
          </Group>

          {/* requests received */}
          {S.requestsIn.length > 0 && (
            <Group label={t("requests_in")}>
              {S.requestsIn.map((p) => (
                <FriendRow key={p.id} p={p} action={
                  <div style={{ display: "flex", gap: 7, flexShrink: 0 }}>
                    <button onClick={() => S.acceptRequest(p.id)} style={{ height: 36, padding: "0 14px", borderRadius: 10, border: "none", background: th.accent, color: "#fff", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 700 }}>{t("accept")}</button>
                    <button onClick={() => S.declineRequest(p.id)} style={{ width: 36, height: 36, borderRadius: 10, border: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", display: "grid", placeItems: "center" }}><Icon name="x" size={16} color={th.inkSoft} /></button>
                  </div>
                } />
              ))}
            </Group>
          )}

          {/* requests sent */}
          {S.requestsOut.length > 0 && (
            <Group label={t("requests_out")}>
              {S.requestsOut.map((p) => (
                <FriendRow key={p.id} p={p} action={
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 6, fontFamily: th.fontUI, fontSize: th.fs(12.5), fontWeight: 600, color: th.inkFaint }}>
                    <Icon name="clock" size={14} color={th.inkFaint} /> {t("pending")}
                  </span>
                } />
              ))}
            </Group>
          )}

          {/* accepted friends */}
          <Coach feature="firstFriend" active={tipFriend} text={t("coach_firstfriend")} placement="top" wrapStyle={{ marginBottom: 22 }}>
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, padding: "0 6px 8px" }}>{t("friends_list")} · {S.friends.length}</div>
            <div style={{ background: th.card, borderRadius: 18, overflow: "hidden", boxShadow: th.shadow }}>
              {S.friends.length === 0 ? (
                <div style={{ padding: "26px 20px", textAlign: "center", fontFamily: th.fontUI, fontSize: th.fs(14), color: th.inkSoft, lineHeight: 1.5 }}>{t("friends_empty")}</div>
              ) : S.friends.map((p) => (
                <FriendRow key={p.id} p={p} onTap={() => app.nav.go("friendbook", { friendId: p.id })} action={
                  <div style={{ position: "relative", flexShrink: 0 }}>
                    <button onClick={() => setMenuFor(menuFor === p.id ? null : p.id)} style={{ width: 36, height: 36, borderRadius: 10, border: "none", background: "transparent", cursor: "pointer", display: "grid", placeItems: "center" }}><Icon name="more" size={20} color={th.inkSoft} /></button>
                    {menuFor === p.id && (
                      <div style={{ position: "absolute", right: 0, top: 40, zIndex: 20, background: th.card, borderRadius: 12, boxShadow: "0 10px 30px rgba(0,0,0,0.22)", border: `1px solid ${th.line}`, overflow: "hidden", minWidth: 150 }}>
                        <button onClick={() => { S.removeFriend(p.id); setMenuFor(null); }} style={{ display: "flex", alignItems: "center", gap: 9, width: "100%", border: "none", borderBottom: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", padding: "11px 14px", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(14), color: th.ink }}><Icon name="x" size={16} color={th.inkSoft} /> {t("remove_friend")}</button>
                        <button onClick={() => { S.block(p.id); setMenuFor(null); }} style={{ display: "flex", alignItems: "center", gap: 9, width: "100%", border: "none", background: "transparent", cursor: "pointer", padding: "11px 14px", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(14), color: "#C0563B" }}><Icon name="block" size={16} color="#C0563B" /> {t("block_user")}</button>
                      </div>
                    )}
                  </div>
                } />
              ))}
            </div>
          </Coach>
        </div>
      </ScreenScroll>
    </div>
  );
}

// ── Friend's cookbook ─────────────────────────────────────────
function FriendCookbookScreen({ route }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const friend = app.social.profileOf(route.friendId);
  const shared = app.social.sharedRecipesOf(route.friendId);

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column" }}>
      <VisitingBand friend={friend} onBack={() => app.nav.back()} />
      <ScreenScroll wide>
        <div style={{ padding: "16px 16px 0" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 11, marginBottom: 16, padding: "0 4px" }}>
            <Avatar name={friend.name} color={friend.color} size={46} />
            <div>
              <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(23), fontWeight: 600, color: th.ink, lineHeight: 1.05 }}>{t("friend_cookbook")} {friend.name}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft }}>{shared.length} {t("shared_recipes")}</div>
            </div>
          </div>

          {shared.length === 0 ? (
            <div style={{ textAlign: "center", padding: "50px 30px" }}>
              <div style={{ width: 60, height: 60, borderRadius: 999, background: friend.color + "22", display: "grid", placeItems: "center", margin: "0 auto 14px" }}>
                <Icon name="bowl" size={26} color={friend.color} />
              </div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.inkSoft, lineHeight: 1.5 }}>@{friend.username} {t("cookbook_empty")}</div>
            </div>
          ) : (
            <div style={{ display: "grid", gridTemplateColumns: `repeat(${app.layout.gridCols || 2}, minmax(0,1fr))`, gap: 14 }}>
              {shared.map((r) => (
                <div key={r.id} style={{ position: "relative" }}>
                  <MiniCard recipe={r} tagsById={app.tagsById} lang={lang} width="100%" onOpen={() => app.nav.go("recipe", { id: r.id, visiting: true, ownerId: route.friendId })} />
                  {app.social.isLinked(r.id) && (
                    <span style={{ position: "absolute", top: 8, left: 8, display: "inline-flex", alignItems: "center", gap: 4, padding: "3px 8px", borderRadius: 999, background: "rgba(0,0,0,0.5)", backdropFilter: "blur(6px)", color: "#fff", fontFamily: th.fontUI, fontSize: 10.5, fontWeight: 700 }}><Icon name="check" size={11} color="#fff" stroke={3} /> {t("already_stolen")}</span>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </ScreenScroll>
    </div>
  );
}

// ── Reviews (Avis) section — used on recipe page modes A & B ──
function ReviewsSection({ recipeId, canReview, canModerate }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const S = app.social;
  const comments = S.commentsFor(recipeId);
  const mine = S.myComment(recipeId);
  const [editing, setEditing] = React.useState(false);
  const [stars, setStars] = React.useState(mine ? mine.stars : 0);
  const [text, setText] = React.useState(mine ? mine.text : "");
  const others = comments.filter((c) => c.authorId !== S.ME || !canReview);

  const startEdit = () => { setStars(mine ? mine.stars : 0); setText(mine ? mine.text : ""); setEditing(true); };
  const save = () => { if (stars > 0) { S.upsertComment(recipeId, stars, text.trim()); setEditing(false); } };

  return (
    <div style={{ marginTop: 30 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 9, marginBottom: 14 }}>
        <h2 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("reviews")}</h2>
        {comments.length > 0 && <span style={{ fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 700, color: th.inkFaint }}>{comments.length}</span>}
      </div>

      {/* your review editor (visiting mode) */}
      {canReview && (
        <div style={{ background: th.card, borderRadius: 18, padding: "14px 16px", boxShadow: th.shadow, marginBottom: 14, border: `1.5px solid ${th.accent}33` }}>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 10 }}>{t("your_review")}</div>
          {mine && !editing ? (
            <div>
              <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
                <Stars value={mine.stars} size={th.fs(18)} />
                <button onClick={startEdit} style={{ marginLeft: "auto", border: "none", background: "none", cursor: "pointer", display: "inline-flex", alignItems: "center", gap: 5, fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 700, color: th.accent }}><Icon name="pencil" size={14} color={th.accent} /> {t("edit_review")}</button>
              </div>
              {mine.text && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.inkSoft, lineHeight: 1.5 }}>{mine.text}</div>}
            </div>
          ) : (
            <div>
              <div style={{ marginBottom: 11 }}><Stars value={stars} size={th.fs(26)} gap={5} interactive onChange={setStars} /></div>
              <textarea value={text} onChange={(e) => setText(e.target.value)} placeholder={t("review_ph")} rows={2} style={{ width: "100%", boxSizing: "border-box", border: `1px solid ${th.line}`, borderRadius: 12, background: th.canvas2, padding: "10px 12px", fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink, outline: "none", resize: "none", lineHeight: 1.5 }} />
              <button onClick={save} disabled={stars === 0} style={{ marginTop: 10, height: 42, width: "100%", borderRadius: 11, border: "none", cursor: stars ? "pointer" : "default", background: stars ? th.accent : th.line, color: stars ? "#fff" : th.inkFaint, fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 700 }}>{t("save_review")}</button>
            </div>
          )}
        </div>
      )}

      {/* others' reviews */}
      {others.length === 0 && !mine ? (
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14), color: th.inkFaint, fontStyle: "italic", padding: "4px 4px" }}>{t("no_reviews")}</div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {others.map((c) => (
            <div key={c.id} style={{ display: "flex", gap: 12, background: th.cardSoft, border: `1px solid ${th.line}`, borderRadius: 16, padding: "12px 14px" }}>
              <Avatar name={c.authorName} color={c.authorColor} size={36} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <span style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 700, color: th.ink }}>{c.authorName}</span>
                  <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint }}>{FB.fmtRelDate(c.date, lang)}</span>
                  {canModerate && (
                    <button onClick={() => S.deleteComment(recipeId, c.id)} title={t("moderate_delete")} style={{ marginLeft: "auto", border: "none", background: "none", cursor: "pointer", padding: 3, lineHeight: 0 }}><Icon name="trash" size={16} color={th.inkFaint} /></button>
                  )}
                </div>
                <div style={{ margin: "4px 0 5px" }}><Stars value={c.stars} size={th.fs(14)} /></div>
                {c.text && <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.inkSoft, lineHeight: 1.5, textWrap: "pretty" }}>{c.text}</div>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Recipe-page controls (composed into RecipeScreen) ─────────
// mode helper
function recipeMode(app, recipe, route) {
  if (route && route.visiting) return "visiting";
  if (app.social.isLinked(recipe.id)) return "linked";
  return "own";
}

// Mode A — steal action (visiting a friend's recipe)
function StealAction({ recipe }) {
  const th = useTheme();
  const app = useApp();
  const { t } = app;
  const already = app.social.isLinked(recipe.id) || app.recipes.some((r) => r.id === recipe.id);
  const onSteal = () => {
    const bundle = app.social.stealBundle(recipe.id);
    const newExtras = bundle.extras.filter((e) => !e.already);
    if (newExtras.length >= 1) app.social.setStealPreview({ recipe, bundle });
    else app.social.doSteal(recipe.id);
  };
  if (already) {
    return (
      <div style={{ width: "100%", height: 56, borderRadius: 18, background: th.accentSoft, color: th.accent, display: "flex", alignItems: "center", justifyContent: "center", gap: 9, fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 700 }}>
        <Icon name="check" size={th.fs(20)} color={th.accent} stroke={2.6} /> {t("already_stolen")}
      </div>
    );
  }
  return (
    <button onClick={onSteal} style={{ width: "100%", height: 56, borderRadius: 18, border: "none", cursor: "pointer", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(17), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 9, boxShadow: "0 10px 26px " + th.accent + "55" }}>
      <Icon name="share" size={th.fs(20)} fill /> {t("steal_recipe")}
    </button>
  );
}

// Mode B — visibility control (your own recipe)
function VisibilityControl({ recipe, active }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const v = app.social.visibilityOf(recipe.id);
  return (
    <Coach feature="shareRecipe" active={active} text={t("coach_share")} placement="bottom" wrapStyle={{ marginTop: 16 }}>
      <div style={{ background: th.card, borderRadius: 16, padding: "12px 14px", boxShadow: th.shadow, display: "flex", alignItems: "center", gap: 12 }}>
        <span style={{ width: 34, height: 34, borderRadius: 10, background: v === "friends" ? th.accentSoft : th.canvas2, display: "grid", placeItems: "center", flexShrink: 0 }}>
          <Icon name={v === "friends" ? "users" : "lock"} size={18} color={v === "friends" ? th.accent : th.inkFaint} />
        </span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700, color: th.ink }}>{t("visibility")}</div>
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), color: th.inkFaint }}>{v === "friends" ? t("vis_friends") : t("vis_private")}</div>
        </div>
        <div style={{ width: 168, flexShrink: 0 }}>
          <Segmented value={v} onChange={(nv) => app.social.setVisibility(recipe.id, nv)} options={[{ value: "private", label: t("vis_private") }, { value: "friends", label: lang === "fr" ? "Amis" : "Friends" }]} />
        </div>
      </div>
    </Coach>
  );
}

// Mode C — linked banner + lock chip + fork menu
function LinkedControls({ recipe, active }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const info = app.social.linkInfo(recipe.id);
  const updatable = app.social.updateAvailable(recipe.id);
  const [menu, setMenu] = React.useState(false);
  if (!info) return null;
  return (
    <div style={{ marginTop: 16 }}>
      {updatable && (
        <div style={{ display: "flex", alignItems: "center", gap: 11, padding: "12px 14px", borderRadius: 14, background: th.accentSoft, border: `1px solid ${th.accent}55`, marginBottom: 12 }}>
          <Icon name="refresh" size={th.fs(19)} color={th.accent} style={{ flexShrink: 0 }} />
          <div style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700, color: th.ink }}>{t("update_available")}</div>
          <button onClick={() => app.social.pullUpdate(recipe.id)} style={{ height: 38, padding: "0 16px", borderRadius: 11, border: "none", background: th.accent, color: "#fff", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700 }}>{t("refresh")}</button>
        </div>
      )}
      <div style={{ position: "relative" }}>
      <Coach feature="stolenRecipe" active={active} text={t("coach_stolen")} placement="top" wrapStyle={{ display: "block" }}>
        <button onClick={() => setMenu((m) => !m)} style={{ width: "100%", height: 50, borderRadius: 14, border: `1px solid ${th.line}`, background: th.card, cursor: "pointer", display: "flex", alignItems: "center", gap: 10, padding: "0 16px", boxShadow: th.shadow }}>
          <Icon name="lock" size={th.fs(18)} color={th.inkSoft} />
          <span style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 600, color: th.inkSoft }}>{t("locked_readonly")}</span>
          <Icon name="chevD" size={th.fs(18)} color={th.inkFaint} style={{ marginLeft: "auto" }} />
        </button>
      </Coach>
        {menu && (
          <div style={{ position: "absolute", left: 0, right: 0, top: 56, zIndex: 20, background: th.card, borderRadius: 14, boxShadow: "0 12px 30px rgba(0,0,0,0.22)", border: `1px solid ${th.line}`, overflow: "hidden" }}>
            <button onClick={() => { setMenu(false); app.addVariant(recipe.id); }} style={{ display: "flex", alignItems: "center", gap: 11, width: "100%", border: "none", borderBottom: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", padding: "14px 16px", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 600, color: th.ink }}><Icon name="plus" size={18} color={th.accent} /> {t("make_variant")}</button>
            <button onClick={() => { setMenu(false); app.social.unlink(recipe.id); }} style={{ display: "flex", alignItems: "center", gap: 11, width: "100%", border: "none", background: "transparent", cursor: "pointer", padding: "14px 16px", textAlign: "left", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 600, color: th.ink }}><Icon name="link" size={18} color={th.accent} /> {t("unlink_source")}</button>
          </div>
        )}
      </div>
    </div>
  );
}

// Small lock chip "de @marie" rendered in the title card (mode C)
function LinkedOwnerChip({ recipe }) {
  const th = useTheme();
  const app = useApp();
  const { t } = app;
  const info = app.social.linkInfo(recipe.id);
  if (!info) return null;
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 6, padding: "4px 10px", borderRadius: 999, background: info.owner.color + (th.dark ? "33" : "1c"), color: th.ink, fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700 }}>
      <Icon name="lock" size={12} color={info.owner.color} /> {t("from_owner")} @{info.owner.username}
    </span>
  );
}

// "Partagé" badge in title card (mode B, when shared)
function SharedBadge({ recipe }) {
  const th = useTheme();
  const app = useApp();
  if (app.social.visibilityOf(recipe.id) !== "friends") return null;
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 5, padding: "4px 10px", borderRadius: 999, background: th.accentSoft, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(12), fontWeight: 700 }}>
      <Icon name="users" size={12} color={th.accent} /> {app.t("shared_badge")}
    </span>
  );
}

// ── Steal preview sheet ───────────────────────────────────────
function StealPreviewSheet() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const sp = app.social.stealPreview;
  if (!sp) return null;
  const newExtras = sp.bundle.extras.filter((e) => !e.already);
  const close = () => app.social.setStealPreview(null);
  return (
    <SheetShell onClose={close}>
      <div style={{ padding: "12px 20px 4px" }}>
        <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(23), fontWeight: 600, color: th.ink, marginBottom: 4 }}>{t("steal_preview_title")}</div>
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.inkSoft, lineHeight: 1.5, marginBottom: 16 }}>
          « {sp.recipe.title} » {t("steal_bundles")} {newExtras.length} {t("steal_n_linked")}.
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8, marginBottom: 18 }}>
          {/* primary */}
          <div style={{ display: "flex", alignItems: "center", gap: 11, padding: "10px 12px", borderRadius: 13, background: th.accentSoft, border: `1px solid ${th.accent}44` }}>
            <Icon name="share" size={18} color={th.accent} />
            <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: th.ink }}>{sp.recipe.title}</span>
          </div>
          {sp.bundle.extras.map((e) => (
            <div key={e.recipe.id} style={{ display: "flex", alignItems: "center", gap: 11, padding: "10px 12px", borderRadius: 13, background: th.cardSoft, border: `1px solid ${th.line}`, opacity: e.already ? 0.55 : 1 }}>
              <Icon name="link" size={17} color={th.inkSoft} />
              <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 600, color: th.ink }}>{e.recipe.title}</span>
              {e.already && <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), fontWeight: 600, color: th.inkFaint }}>{t("steal_already")}</span>}
            </div>
          ))}
        </div>
        <PrimaryBtn label={t("steal_all")} icon="share" onClick={() => { app.social.doSteal(sp.recipe.id); close(); }} />
        <button onClick={close} style={{ width: "100%", height: 46, marginTop: 10, border: "none", background: "transparent", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: th.inkSoft }}>{t("cancel")}</button>
      </div>
    </SheetShell>
  );
}

// ── First-login migration sheet ───────────────────────────────
function MigrationSheet() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const [done, setDone] = React.useState(false);
  if (!app.social.migrationPending) return null;
  const n = app.social.localOnlyCount;
  const close = () => { app.social.setMigrationPending(false); setDone(false); };
  return (
    <SheetShell onClose={close}>
      <div style={{ padding: "12px 20px 4px" }}>
        <div style={{ display: "flex", justifyContent: "center", margin: "6px 0 16px" }}>
          <div style={{ width: 60, height: 60, borderRadius: 18, background: th.accentSoft, display: "grid", placeItems: "center" }}>
            <Icon name={done ? "check" : "refresh"} size={28} color={th.accent} stroke={2.4} />
          </div>
        </div>
        {done ? (
          <div style={{ textAlign: "center", paddingBottom: 8 }}>
            <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("migration_synced")}</div>
          </div>
        ) : (
          <>
            <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink, marginBottom: 6, textAlign: "center" }}>{t("migration_title")}</div>
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.inkSoft, lineHeight: 1.5, marginBottom: 18, textAlign: "center" }}>{n} {t("migration_body")}</div>
            <PrimaryBtn label={t("migration_add")} icon="check" onClick={() => { setDone(true); setTimeout(close, 1100); }} />
            <button onClick={close} style={{ width: "100%", height: 46, marginTop: 10, border: "none", background: "transparent", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: th.inkSoft }}>{t("migration_later")}</button>
          </>
        )}
      </div>
    </SheetShell>
  );
}

Object.assign(window, {
  SignInScreen, UsernameSetupScreen, AccountScreen, FriendsScreen, FriendCookbookScreen,
  ReviewsSection, StealAction, VisibilityControl, LinkedControls, LinkedOwnerChip, SharedBadge,
  StealPreviewSheet, MigrationSheet, recipeMode, PushHeader, SheetShell,
});
