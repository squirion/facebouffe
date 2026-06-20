/* fb-screens-recipe.jsx — Recipe detail page + Sous-chef cooking mode. */

// (rich text rendering — link + temperature chips — lives in fb-ui.jsx as RichText)


function StatBlock({ icon, label, value }) {
  const th = useTheme();
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 3, padding: "2px 4px" }}>
      <Icon name={icon} size={th.fs(19)} color={th.accent} stroke={2} />
      <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: th.ink, marginTop: 2, whiteSpace: "nowrap" }}>{value}</div>
      <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 600, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.4, whiteSpace: "nowrap" }}>{label}</div>
    </div>);

}

function RecipeScreen({ route }) {
  const th = useTheme();
  const app = useApp();
  const { lang, t, nav, isFav, prefs } = app;
  const recipe = app.resolveRecipe(route.id);
  const [servings, setServings] = React.useState(recipe ? recipe.servings : 1);
  const [addedFlash, setAddedFlash] = React.useState(false);
  const [favPulse, setFavPulse] = React.useState(0);
  React.useEffect(() => {if (recipe) setServings(recipe.servings);}, [route.id]);
  if (!recipe) return null;

  // Phase 2 — context mode: visiting a friend's (A) / your own (B) / linked-stolen (C)
  const mode = recipeMode(app, recipe, route);
  const isVisiting = mode === "visiting";
  const isLinked = mode === "linked";
  const isOwn = mode === "own";
  const loggedIn = !!app.account;
  const owner = isVisiting ? app.social.profileOf(route.ownerId) : null;

  const tag = primaryTag(recipe, app.tagsById);
  const ratio = servings / recipe.servings;
  const group = recipe.variantGroupId ? app.getVariantGroup(recipe.variantGroupId) : null;
  const members = group ? group.memberIds.map(app.resolveRecipe).filter(Boolean) : [];
  const linked = (recipe.links || []).map(app.resolveRecipe).filter(Boolean);
  const fav = isFav(recipe);
  // Tablet: cap + center the reading column; in landscape put ingredients
  // beside the method (two columns).
  const recipeMax = app.layout.recipeMax;
  const twoCol = app.layout.twoPane;
  const bodyGrid = twoCol ? { display: "grid", gridTemplateColumns: "minmax(0,0.82fr) minmax(0,1.18fr)", gap: 30, alignItems: "start", marginTop: 6 } : null;

  const addAll = () => {
    app.shopping.addMany(recipe.ingredients.map((ing) => {
      const conv = ing.quantity != null && ing.unit ? FB.convertIngredientUnit(ing.quantity * ratio, ing.unit, prefs) : { quantity: ing.quantity == null ? null : ing.quantity * ratio, unit: ing.unit };
      return { name: ing.name, quantity: conv.quantity, unit: conv.unit, sourceRecipeId: recipe.id };
    }));
    setAddedFlash(true);
    setTimeout(() => setAddedFlash(false), 1600);
  };

  // one coach mark at a time, by priority among controls present on this page
  const tipOrder = [];
  if (members.length > 1) tipOrder.push("variantChips");
  tipOrder.push("sousChef", "shoppingAdd", "variants", "pdfExport");
  let activeTip = tipOrder.find((f) => !app.tipsSeen[f]) || null;
  // Phase 2 coaches take precedence on their page so they never double up.
  const linkedCoach = isLinked && !app.tipsSeen.stolenRecipe;
  const shareCoach = isOwn && loggedIn && !app.tipsSeen.shareRecipe;
  if (linkedCoach || shareCoach || isVisiting) activeTip = null;

  // Gallery extracted so it can live under the steps (right column) on wide
  // tablets, or full-width on phones.
  const galleryBlock = recipe.gallery && recipe.gallery.length > 0 ? (
    <div style={{ marginTop: 30 }}>
      <h2 style={{ margin: "0 0 12px", fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("gallery")}</h2>
      <div className="fb-hscroll" style={{ display: "flex", gap: 10, overflowX: "auto", paddingBottom: 4 }}>
        {recipe.gallery.map((g, i) => (
          <div key={i} style={{ flexShrink: 0, width: 150 }}>
            <image-slot id={"fbgal-" + recipe.id + "-" + i} shape="rounded" radius="16" placeholder={g} style={{ display: "block", width: "150px", height: "150px", background: th.canvas2 }}></image-slot>
          </div>
        ))}
      </div>
    </div>
  ) : null;

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", position: "relative" }}>
      {isVisiting && owner && <VisitingBand friend={owner} onBack={() => nav.back()} />}
      <div className="fb-scroll" style={{ flex: 1, overflowY: "auto", overflowX: "hidden", paddingBottom: 32 + app.insets.bottom }}>
        {/* Hero */}
        <div style={{ position: "relative" }}>
          <HeroMedia recipe={recipe} tag={tag} height={app.layout.tablet ? 360 : 300} radius={0} slot={isOwn} />
          {!recipe.heroImage && <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom, rgba(0,0,0,0.18), transparent 30%, transparent 70%, rgba(0,0,0,0.12))", pointerEvents: "none" }} />}
          <div style={{ position: "absolute", top: isVisiting ? 6 : app.insets.top + 6, left: 14, right: 14, display: "flex", justifyContent: "space-between", pointerEvents: "none" }}>
            {!isVisiting ? <RoundBtn icon="back" onClick={() => nav.back()} /> : <span />}
            <div style={{ display: "flex", gap: 8, pointerEvents: "auto" }}>
              {!isVisiting && <RoundBtn icon="star" fill={fav} color={fav ? th.gold : "#fff"} pulse={favPulse} reduce={app.reduceMotion} onClick={() => {app.toggleFav(recipe.id);setFavPulse((p) => p + 1);}} />}
              {isOwn && <RoundBtn icon="pencil" onClick={() => nav.edit(recipe.id)} />}
            </div>
          </div>
        </div>

        <div style={{ padding: "0 20px", marginTop: -26, position: "relative", zIndex: 2, maxWidth: recipeMax || undefined, marginLeft: recipeMax ? "auto" : undefined, marginRight: recipeMax ? "auto" : undefined, boxSizing: "border-box" }}>
          <div style={{ background: th.card, borderRadius: 26, padding: "20px 20px 22px", boxShadow: th.shadow }}>
            {tag &&
            <div style={{ display: "flex", gap: 7, marginBottom: 10, flexWrap: "wrap" }}>
                {(recipe.tags || []).filter((id) => id !== "tag-fav").map((id) => app.tagsById[id]).filter(Boolean).map((tg) =>
              <TagChip key={tg.id} tag={tg} lang={lang} size="sm" onClick={() => nav.go("filter", { tagId: tg.id })} />
              )}
              </div>
            }
            <h1 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(30), lineHeight: 1.08, fontWeight: 600, color: th.ink, letterSpacing: 0.2 }}>{recipe.title}</h1>
            {recipe.source &&
            <div style={{ marginTop: 7, fontFamily: th.fontUI, fontSize: th.fs(13.5), fontStyle: "italic", color: th.inkSoft }}>{recipe.source}</div>
            }
            {(isLinked || isOwn && loggedIn && app.social.visibilityOf(recipe.id) === "friends") &&
            <div style={{ display: "flex", gap: 7, marginTop: 10, flexWrap: "wrap" }}>
                {isLinked && <LinkedOwnerChip recipe={recipe} />}
                {isOwn && <SharedBadge recipe={recipe} />}
              </div>
            }

            {members.length > 1 &&
            <Coach feature="variantChips" active={activeTip === "variantChips"} text={t("coach_chips")} placement="bottom" wrapStyle={{ marginTop: 16 }}>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, marginBottom: 8 }}>{t("variants")}</div>
                <div className="fb-hscroll" style={{ display: "flex", gap: 8, overflowX: "auto", paddingBottom: 2 }}>
                  {members.map((m) => {
                  const active = m.id === recipe.id;
                  return (
                    <button key={m.id} onClick={() => !active && nav.openRecipe(m.id, true)} style={{
                      flexShrink: 0, border: `1.5px solid ${active ? th.accent : th.line}`, background: active ? th.accent : th.card,
                      color: active ? "#fff" : th.ink, borderRadius: 13, padding: "8px 13px", cursor: "pointer",
                      fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 600, textAlign: "left", maxWidth: 220
                    }}>
                        <div style={{ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{m.title}</div>
                        {group.baseId === m.id && <div style={{ fontSize: th.fs(10.5), fontWeight: 600, opacity: 0.8, marginTop: 1 }}>{t("base_variant")}</div>}
                      </button>);

                })}
                </div>
              </Coach>
            }

            <p style={{ margin: "16px 0 0", fontFamily: th.fontUI, fontSize: th.fs(15.5), lineHeight: 1.6, color: th.inkSoft, textWrap: "pretty" }}><RichText text={recipe.description} onLink={(id) => nav.openRecipe(id)} /></p>

            <div style={{ display: "flex", marginTop: 20, padding: "14px 0", borderTop: `1px solid ${th.line}`, borderBottom: `1px solid ${th.line}` }}>
              <StatBlock icon="clock" label={t("prep")} value={FB.fmtDuration(recipe.prepTimeMinutes, lang)} />
              <div style={{ width: 1, background: th.line }} />
              <StatBlock icon="flame" label={t("cook")} value={FB.fmtDuration(recipe.cookTimeMinutes, lang)} />
              <div style={{ width: 1, background: th.line }} />
              <StatBlock icon="users" label={t("servings")} value={servings} />
            </div>
          </div>

          {/* Phase 2 — context controls */}
          {isVisiting && <div style={{ marginTop: 16 }}><StealAction recipe={recipe} /></div>}
          {isLinked && <LinkedControls recipe={recipe} active={linkedCoach} />}
          {isOwn && loggedIn && <VisibilityControl recipe={recipe} active={shareCoach} />}

          {/* Cook mode CTA — directly under the description card */}
          <Coach feature="sousChef" active={activeTip === "sousChef"} text={t("coach_souschef")} placement="bottom" wrapStyle={{ marginTop: 16 }}>
            <button onClick={() => nav.cook(recipe.id, servings)} style={{ width: "100%", height: 56, borderRadius: 18, border: "none", cursor: "pointer", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(17), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 9, boxShadow: "0 10px 26px " + th.accent + "55" }}>
              <Icon name="flame" size={th.fs(21)} fill /> {t("cook_mode")}
            </button>
          </Coach>

          {/* Ingredients | Method — two columns on wide tablets */}
          <div style={bodyGrid}>
          <div>
          {/* Servings stepper */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 22, marginBottom: 4 }}>
            <h2 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("ingredients")}</h2>
            <div style={{ display: "flex", alignItems: "center", gap: 4, background: th.card, border: `1px solid ${th.line}`, borderRadius: 999, padding: 4, boxShadow: th.shadow }}>
              <StepperBtn icon="minus" onClick={() => setServings((s) => Math.max(1, s - 1))} disabled={servings <= 1} />
              <div style={{ minWidth: 58, textAlign: "center" }}>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 700, color: th.ink, lineHeight: 1 }}>{servings}</div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(10), color: th.inkFaint, fontWeight: 600 }}>{servings === 1 ? t("serving_one") : t("servings")}</div>
              </div>
              <StepperBtn icon="plus" onClick={() => setServings((s) => s + 1)} />
            </div>
          </div>
          {servings !== recipe.servings &&
              <button onClick={() => setServings(recipe.servings)} style={{ border: "none", background: "none", cursor: "pointer", color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 600, padding: "2px 0 0" }}>↺ {t("scale_reset")}</button>
              }

          <div style={{ background: th.card, borderRadius: 20, marginTop: 12, padding: "6px 18px", boxShadow: th.shadow }}>
            {recipe.ingredients.map((ing, i) => {
                  const d = FB.displayIngredient(ing, ratio, prefs, lang);
                  return (
                    <div key={i} style={{ display: "flex", gap: 12, alignItems: "baseline", padding: "12px 0", borderBottom: i < recipe.ingredients.length - 1 ? `1px solid ${th.line}` : "none" }}>
                  <div style={{ minWidth: 74, fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 700, color: th.accent, fontVariantNumeric: "tabular-nums" }}>{d.qtyText}{d.unitText ? " " + d.unitText : ""}</div>
                  <div style={{ flex: 1 }}>
                    <span style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), color: th.ink }}>{d.name}</span>
                    {d.note && <span style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), fontStyle: "italic", color: th.inkFaint }}> · {d.note}</span>}
                  </div>
                </div>);

                })}
          </div>
          <Coach feature="shoppingAdd" active={activeTip === "shoppingAdd"} text={t("coach_shopping")} placement="top" wrapStyle={{ marginTop: 12 }}>
            <button onClick={addAll} style={{
                  width: "100%", height: 48, borderRadius: 14, cursor: "pointer",
                  border: `1.5px solid ${addedFlash ? "#6BA368" : th.accent}`, background: addedFlash ? "#6BA36818" : th.accentSoft,
                  color: addedFlash ? "#4f7d4c" : th.accent, fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700,
                  display: "flex", alignItems: "center", justifyContent: "center", gap: 8
                }}>
              <Icon name={addedFlash ? "check" : "basket"} size={th.fs(19)} /> {addedFlash ? t("added") : t("add_to_list")}
            </button>
          </Coach>

          {/* Nutrition under « Ajouter à l'épicerie » in the left column on wide tablets */}
          {twoCol && <NutritionCard recipe={recipe} />}

          </div>
          <div>
          {/* Steps */}
          <h2 style={{ margin: twoCol ? "22px 0 14px" : "30px 0 14px", fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("steps")}</h2>
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            {recipe.steps.map((s, i) =>
                <div key={i} style={{ display: "flex", gap: 14 }}>
                <div style={{ flexShrink: 0, width: 30, height: 30, borderRadius: 999, background: th.accent, color: "#fff", display: "grid", placeItems: "center", fontFamily: th.fontDisplay, fontSize: th.fs(16), fontWeight: 600 }}>{i + 1}</div>
                <div style={{ flex: 1, paddingTop: 2 }}>
                  <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15.5), lineHeight: 1.55, color: th.ink, textWrap: "pretty" }}><RichText text={s.text} onLink={(id) => nav.openRecipe(id)} /></div>
                  {s.image &&
                    <div style={{ marginTop: 10, width: "100%", maxWidth: 240 }}>
                      <image-slot id={"fbstep-" + recipe.id + "-" + i} shape="rounded" radius="14" placeholder={"Photo · " + s.image} style={{ display: "block", width: "100%", height: "150px", background: th.canvas2 }}></image-slot>
                    </div>
                    }
                  {s.timerSeconds != null &&
                    <div style={{ display: "inline-flex", alignItems: "center", gap: 6, marginTop: 10, padding: "5px 11px", borderRadius: 999, background: th.accentSoft, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: 700 }}>
                      <Icon name="timer" size={th.fs(15)} /> {FB.fmtTimer(s.timerSeconds)}
                    </div>
                    }
                </div>
              </div>
                )}
          </div>

          {/* Gallery under the steps (right column) on wide tablets */}
          {twoCol && galleryBlock}

          </div>
          </div>
          {/* Gallery */}
          {!twoCol && galleryBlock}

          {/* Nutrition (estimate) — saved label */}
          {!twoCol && <NutritionCard recipe={recipe} />}

          {/* Bottom — reviews beside journal/links/actions on wide tablets */}
          <div style={twoCol ? { display: "grid", gridTemplateColumns: "minmax(0,1.1fr) minmax(0,0.9fr)", gap: 30, alignItems: "start" } : undefined}>
          <div>
          {/* Phase 2 — reviews (Avis) */}
          {(isVisiting || isLinked) && <ReviewsSection recipeId={recipe.id} canReview canModerate={false} />}
          {isOwn && loggedIn && <ReviewsSection recipeId={recipe.id} canReview={false} canModerate />}
          </div>
          <div>
          {/* See also (links) */}
          {linked.length > 0 &&
          <div style={{ marginTop: 30 }}>
              <h2 style={{ margin: "0 0 12px", fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("see_also")}</h2>
              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                {linked.map((r) =>
              <button key={r.id} onClick={() => nav.openRecipe(r.id)} style={{ display: "flex", alignItems: "center", gap: 12, width: "100%", border: `1px solid ${th.line}`, background: th.card, borderRadius: 16, padding: 10, cursor: "pointer", textAlign: "left", boxShadow: th.shadow }}>
                    <span style={{ width: 30, height: 30, borderRadius: 9, display: "grid", placeItems: "center", background: th.accentSoft, flexShrink: 0 }}><Icon name="link" size={16} color={th.accent} /></span>
                    <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 600, color: th.ink }}>{r.title}</span>
                    <Icon name="chevR" size={th.fs(17)} color={th.inkFaint} />
                  </button>
              )}
              </div>
            </div>
          }

          {/* Personal journal */}
          {!isVisiting &&
          <div style={{ marginTop: 30, background: th.cardSoft, border: `1px solid ${th.line}`, borderRadius: 20, padding: "18px 18px 20px" }}>
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, marginBottom: 12 }}>{t("personal")}</div>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
              <Stars value={recipe.personal.rating} size={th.fs(24)} gap={4} interactive onChange={(v) => app.updateRecipe(recipe.id, (r) => ({ ...r, personal: { ...r.personal, rating: v } }))} />
              <span style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft, fontWeight: 600 }}>{recipe.personal.rating > 0 ? recipe.personal.rating + "/5" : t("unrated")}</span>
            </div>
            <div style={{ display: "flex", gap: 22, marginBottom: recipe.personal.notes ? 14 : 0 }}>
              <div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11), color: th.inkFaint, fontWeight: 600, textTransform: "uppercase", letterSpacing: 0.3 }}>{t("made_count")}</div>
                <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(18), color: th.ink, fontWeight: 600 }}>{recipe.personal.madeCount} {recipe.personal.madeCount === 1 ? t("time_once") : t("times")}</div>
              </div>
              <div>
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11), color: th.inkFaint, fontWeight: 600, textTransform: "uppercase", letterSpacing: 0.3 }}>{t("last_cooked")}</div>
                <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(18), color: th.ink, fontWeight: 600 }}>{FB.fmtRelDate(recipe.personal.lastCooked, lang)}</div>
              </div>
            </div>
            {recipe.personal.notes &&
            <div style={{ display: "flex", gap: 10, marginTop: 4, padding: "12px 14px", background: th.card, borderRadius: 14 }}>
                <Icon name="note" size={th.fs(17)} color={th.accent} style={{ flexShrink: 0, marginTop: 2 }} />
                <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), lineHeight: 1.5, color: th.inkSoft, fontStyle: "italic" }}>{recipe.personal.notes}</div>
              </div>
            }
          </div>
          }

          {/* Action row */}
          {isOwn &&
          <div style={{ display: "flex", gap: 10, marginTop: 18 }}>
            <Coach feature="variants" active={activeTip === "variants"} text={t("coach_variants")} placement="top" wrapStyle={{ flex: 1, display: "flex" }}>
              <SecondaryAction icon="plus" label={t("add_variant")} onClick={() => app.addVariant(recipe.id)} />
            </Coach>
            <Coach feature="pdfExport" active={activeTip === "pdfExport"} text={t("coach_pdf")} placement="top" wrapStyle={{ flex: 1, display: "flex" }}>
              <SecondaryAction icon="note" label={t("export_pdf")} onClick={() => window.print()} />
            </Coach>
            <SecondaryAction icon="pencil" label={t("edit")} onClick={() => nav.edit(recipe.id)} />
          </div>
          }
          {isLinked &&
          <div style={{ display: "flex", gap: 10, marginTop: 18 }}>
            <SecondaryAction icon="note" label={t("export_pdf")} onClick={() => window.print()} />
          </div>
          }
          </div>
          </div>
        </div>
      </div>
    </div>);

}

function SecondaryAction({ icon, label, onClick }) {
  const th = useTheme();
  return (
    <button onClick={onClick} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6, border: `1px solid ${th.line}`, background: th.card, borderRadius: 16, padding: "12px 6px", cursor: "pointer", boxShadow: th.shadow }}>
      <Icon name={icon} size={th.fs(19)} color={th.accent} />
      <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), fontWeight: 600, color: th.ink, textAlign: "center", lineHeight: 1.2 }}>{label}</span>
    </button>);

}

function RoundBtn({ icon, onClick, fill, color = "#fff", pulse = 0, reduce = false }) {
  return (
    <button onClick={onClick} style={{
      pointerEvents: "auto", width: 40, height: 40, borderRadius: 999, border: "none", cursor: "pointer",
      background: "rgba(0,0,0,0.34)", backdropFilter: "blur(10px)", WebkitBackdropFilter: "blur(10px)",
      display: "grid", placeItems: "center"
    }}>
      <span key={pulse} style={{ display: "grid", placeItems: "center", animation: !reduce && pulse > 0 ? "fbPop 300ms cubic-bezier(0.4,0,0.2,1)" : "none" }}>
        <Icon name={icon} size={21} color={color} fill={fill} stroke={2.2} />
      </span>
    </button>);

}

function StepperBtn({ icon, onClick, disabled }) {
  const th = useTheme();
  return (
    <button onClick={onClick} disabled={disabled} style={{
      width: 38, height: 38, borderRadius: 999, border: "none", cursor: disabled ? "default" : "pointer",
      background: disabled ? "transparent" : th.accentSoft, display: "grid", placeItems: "center", opacity: disabled ? 0.35 : 1
    }}>
      <Icon name={icon} size={th.fs(19)} color={th.accent} stroke={2.4} />
    </button>);

}

// ── Sous-chef mode ────────────────────────────────────────────
function SousChefScreen({ route }) {
  const th = useTheme();
  const app = useApp();
  const { lang, t, nav, prefs } = app;
  const recipe = app.resolveRecipe(route.id);
  const servings = route.servings || recipe && recipe.servings || 1;
  const tag = recipe ? primaryTag(recipe, app.tagsById) : null;
  const [pane, setPane] = React.useState(0);
  const [checked, setChecked] = React.useState({});
  const [stepIdx, setStepIdx] = React.useState(0);
  const [timers, setTimers] = React.useState([]); // {key, stepIdx, total, left, running}
  const touch = React.useRef(null);
  const [drag, setDrag] = React.useState(0);
  const [dragging, setDragging] = React.useState(false);

  // single ticker for all running timers
  React.useEffect(() => {
    const active = timers.some((x) => x.running && x.left > 0);
    if (!active) return;
    const id = setInterval(() => setTimers((ts) => ts.map((x) => x.running && x.left > 0 ? { ...x, left: x.left - 1 } : x)), 1000);
    return () => clearInterval(id);
  }, [timers]);

  if (!recipe) return null;
  const ratio = servings / recipe.servings;
  const steps = recipe.steps;
  const finished = stepIdx >= steps.length;
  const pal = FB.fallbackColor(recipe);
  const tp = app.layout.twoPane; // both panes visible side-by-side

  // dark cooking-mode palette
  const sc = {
    text: "#fff", dim: "rgba(255,255,255,0.66)", faint: "rgba(255,255,255,0.42)",
    surface: "rgba(255,255,255,0.10)", surfaceSolid: "rgba(20,16,12,0.55)",
    line: "rgba(255,255,255,0.16)", accent: th.accent, good: "#7FC47B"
  };

  const startStepTimer = (idx) => {
    const total = steps[idx].timerSeconds;
    if (total == null) return;
    setTimers((ts) => {
      const ex = ts.find((x) => x.stepIdx === idx);
      if (ex) return ts.map((x) => x.stepIdx === idx ? { ...x, left: total, running: true } : x);
      return [...ts, { key: idx + "-" + Date.now(), stepIdx: idx, total, left: total, running: true }];
    });
  };
  const toggleTimer = (key) => setTimers((ts) => ts.map((x) => x.key === key ? { ...x, running: !x.running, left: x.left <= 0 ? x.total : x.left } : x));
  const dismissTimer = (key) => setTimers((ts) => ts.filter((x) => x.key !== key));
  const myTimer = timers.find((x) => x.stepIdx === stepIdx);

  const onTouchStart = (e) => {touch.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };};
  const onTouchMove = (e) => {
    if (!touch.current) return;
    const dx = e.touches[0].clientX - touch.current.x;
    const dy = e.touches[0].clientY - touch.current.y;
    if (!dragging && Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy)) setDragging(true);
    if (dragging || Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy)) {
      let d = dx;
      if (pane === 0 && d > 0 || pane === 1 && d < 0) d = d * 0.3; // resist at edges
      setDrag(d);
    }
  };
  const onTouchEnd = (e) => {
    if (!touch.current) {setDragging(false);setDrag(0);return;}
    const dx = e.changedTouches[0].clientX - touch.current.x;
    const dy = e.changedTouches[0].clientY - touch.current.y;
    if (Math.abs(dx) > 55 && Math.abs(dx) > Math.abs(dy) * 1.4) setPane(dx < 0 ? 1 : 0);
    touch.current = null;
    setDragging(false);
    setDrag(0);
  };

  return (
    <div style={{ height: "100%", position: "relative", overflow: "hidden", color: sc.text }}>
      {/* dimmed hero / fallback background */}
      <div style={{ position: "absolute", inset: 0, zIndex: 0 }}>
        <div style={{ position: "absolute", inset: -30, background: pal.bg, filter: "blur(2px)" }} />
        <div style={{ position: "absolute", inset: 0, backgroundImage: `radial-gradient(${pal.ink}26 1.4px, transparent 1.4px)`, backgroundSize: "18px 18px" }} />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(160deg, rgba(0,0,0,0.55), rgba(0,0,0,0.78))" }} />
      </div>

      <div style={{ position: "relative", zIndex: 1, height: "100%", display: "flex", flexDirection: "column" }}>
        {/* top bar */}
        <div style={{ paddingTop: app.insets.top, flexShrink: 0 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 14px 6px" }}>
            <button onClick={() => nav.back()} style={{ width: 40, height: 40, borderRadius: 999, border: "none", background: sc.surface, cursor: "pointer", display: "grid", placeItems: "center" }}>
              <Icon name="x" size={th.fs(22)} color="#fff" />
            </button>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(17), fontWeight: 600, color: "#fff", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{recipe.title}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), color: sc.dim, fontWeight: 600 }}>{servings} {servings === 1 ? t("serving_one") : t("servings")}</div>
            </div>
            {/* awake indicator */}
            <div style={{ display: "inline-flex", alignItems: "center", gap: 6, padding: "6px 10px", borderRadius: 999, background: sc.surface }}>
              <span style={{ width: 7, height: 7, borderRadius: 999, background: sc.good, boxShadow: `0 0 8px ${sc.good}` }} />
              <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 600, color: sc.dim }}>{t("awake")}</span>
            </div>
          </div>

          {/* running-timers tray */}
          {timers.length > 0 &&
          <div style={{ padding: "4px 12px 8px" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "0 4px 6px" }}>
                <Icon name="timer" size={th.fs(13)} color={sc.dim} />
                <span style={{ fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 700, color: sc.dim, textTransform: "uppercase", letterSpacing: 0.4 }}>{t("timers_running")}</span>
                <span style={{ fontFamily: th.fontUI, fontSize: th.fs(10.5), color: sc.faint, marginLeft: "auto" }}>{t("scheduled_note")}</span>
              </div>
              <div className="fb-hscroll" style={{ display: "flex", gap: 8, overflowX: "auto" }}>
                {timers.map((tm) => {
                const done = tm.left <= 0;
                return (
                  <div key={tm.key} style={{ flexShrink: 0, minWidth: 138, display: "flex", alignItems: "center", gap: 8, padding: "8px 8px 8px 12px", borderRadius: 14, background: done ? "rgba(127,196,123,0.22)" : sc.surface, border: `1px solid ${done ? sc.good : sc.line}` }}>
                      <button onClick={() => done ? toggleTimer(tm.key) : toggleTimer(tm.key)} style={{ border: "none", background: "none", cursor: "pointer", padding: 0, display: "grid", placeItems: "center" }}>
                        <Icon name={done ? "check" : tm.running ? "timer" : "play"} size={th.fs(16)} color={done ? sc.good : "#fff"} fill={done} />
                      </button>
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, color: done ? sc.good : "#fff", fontVariantNumeric: "tabular-nums", lineHeight: 1 }}>{done ? t("sc_timer_done") : FB.fmtTimer(tm.left)}</div>
                        <button onClick={() => {setStepIdx(tm.stepIdx);setPane(1);}} style={{ border: "none", background: "none", padding: 0, cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(10.5), color: sc.dim, marginTop: 2 }}>{t("sc_step")} {tm.stepIdx + 1}</button>
                      </div>
                      <button onClick={() => dismissTimer(tm.key)} style={{ marginLeft: "auto", border: "none", background: "none", cursor: "pointer", padding: 2, lineHeight: 0 }}><Icon name="x" size={th.fs(15)} color={sc.faint} /></button>
                    </div>);

              })}
              </div>
            </div>
          }

          {/* pane toggle + 2-dot indicator (hidden when both panes are shown) */}
          {!tp &&
          <div style={{ padding: "0 12px 6px" }}>
            <div style={{ display: "flex", gap: 4 }}>
              {[t("sc_ingredients"), t("sc_steps")].map((label, i) =>
              <button key={i} onClick={() => setPane(i)} style={{
                flex: 1, height: 40, borderRadius: 12, border: "none", cursor: "pointer",
                background: pane === i ? th.accent : sc.surface, color: "#fff",
                fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, opacity: pane === i ? 1 : 0.7
              }}>{label}{i === 1 ? `  ${Math.min(stepIdx + 1, steps.length)}/${steps.length}` : ``}</button>
              )}
            </div>
            <div style={{ display: "flex", justifyContent: "center", gap: 7, marginTop: 8 }}>
              {[0, 1].map((i) =>
              <span key={i} style={{ width: pane === i ? 18 : 7, height: 7, borderRadius: 999, background: pane === i ? "#fff" : sc.faint, transition: "all 0.25s" }} />
              )}
            </div>
          </div>
          }
        </div>

        {/* panes */}
        <div style={{ flex: 1, overflow: "hidden", position: "relative" }} onTouchStart={tp ? undefined : onTouchStart} onTouchMove={tp ? undefined : onTouchMove} onTouchEnd={tp ? undefined : onTouchEnd}>
          <div style={{ display: "flex", width: "100%", height: "100%", transform: tp ? "none" : `translateX(calc(${pane * -100}% + ${drag}px))`, transition: dragging ? "none" : app.reduceMotion ? "transform 120ms ease" : "transform 0.34s cubic-bezier(0.4,0,0.2,1)" }}>
            {/* Pane 1: ingredients checklist */}
            <div style={{ flex: tp ? "0 0 38%" : "0 0 100%", width: tp ? "auto" : "100%", height: "100%", overflowY: "auto", padding: `8px 22px ${30 + app.insets.bottom}px`, borderRight: tp ? `1px solid ${sc.line}` : "none" }} className="fb-scroll">
              {recipe.ingredients.map((ing, i) => {
                const d = FB.displayIngredient(ing, ratio, prefs, lang);
                const on = checked[i];
                return (
                  <button key={i} onClick={() => setChecked((c) => ({ ...c, [i]: !c[i] }))} style={{
                    display: "flex", gap: 14, alignItems: "center", width: "100%", textAlign: "left", cursor: "pointer",
                    border: "none", background: "transparent", padding: "14px 0", borderBottom: `1px solid ${sc.line}`
                  }}>
                    <span style={{ width: 26, height: 26, borderRadius: 8, flexShrink: 0, border: `2px solid ${on ? sc.accent : "rgba(255,255,255,0.4)"}`, background: on ? sc.accent : "transparent", display: "grid", placeItems: "center" }}>
                      {on && <Icon name="check" size={16} color="#fff" stroke={3} />}
                    </span>
                    <span style={{ flex: 1, fontFamily: th.fontUI, fontSize: th.fs(18), color: on ? sc.faint : "#fff", textDecoration: on ? "line-through" : "none", lineHeight: 1.35 }}>
                      <strong style={{ color: on ? sc.faint : sc.accent, fontWeight: 700 }}>{d.qtyText}{d.unitText ? " " + d.unitText : ""}</strong> {d.name}
                      {d.note && <span style={{ fontStyle: "italic", color: sc.faint }}> · {d.note}</span>}
                    </span>
                  </button>);

              })}
            </div>

            {/* Pane 2: step-by-step */}
            <div style={{ flex: tp ? "0 0 62%" : "0 0 100%", width: tp ? "auto" : "100%", height: "100%", display: "flex", flexDirection: "column" }}>
              {finished ?
              <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 30, textAlign: "center" }}>
                  <div style={{ width: 96, height: 96, borderRadius: 999, background: sc.surface, display: "grid", placeItems: "center", marginBottom: 20 }}>
                    <Icon name="check" size={48} color={sc.good} stroke={2.4} />
                  </div>
                  <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(32), fontWeight: 600, color: "#fff" }}>{t("sc_all_done")}</div>
                  <div style={{ fontFamily: th.fontUI, fontSize: th.fs(16), color: sc.dim, marginTop: 6 }}>{t("sc_all_done_sub")}</div>
                  <button onClick={() => {app.markCooked(recipe.id);nav.back();}} style={{ marginTop: 28, height: 52, padding: "0 30px", borderRadius: 16, border: "none", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(16), fontWeight: 700, cursor: "pointer" }}>{t("sc_close")}</button>
                </div> :

              <>
                  <div style={{ flex: 1, overflowY: "auto", padding: `20px 24px 16px` }} className="fb-scroll">
                    <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700, color: sc.accent, textTransform: "uppercase", letterSpacing: 0.6 }}>{t("sc_step")} {stepIdx + 1} {t("sc_of")} {steps.length}</div>
                    <div style={{ display: "flex", gap: 6, margin: "12px 0 24px" }}>
                      {steps.map((_, i) => <div key={i} style={{ flex: 1, height: 5, borderRadius: 99, background: i <= stepIdx ? sc.accent : "rgba(255,255,255,0.2)" }} />)}
                    </div>
                    <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(27), lineHeight: 1.32, color: "#fff", fontWeight: 500, letterSpacing: 0.2, textWrap: "pretty" }}><RichText text={steps[stepIdx].text} dark onLink={(id) => nav.openRecipe(id)} /></div>
                    {steps[stepIdx].timerSeconds != null &&
                  <button onClick={() => startStepTimer(stepIdx)} style={{
                    marginTop: 22, display: "inline-flex", alignItems: "center", gap: 9, height: 50, padding: "0 20px", borderRadius: 14, cursor: "pointer",
                    border: `1.5px solid ${myTimer ? sc.accent : sc.line}`, background: myTimer ? "rgba(192,86,59,0.2)" : sc.surface, color: "#fff",
                    fontFamily: th.fontUI, fontSize: th.fs(15.5), fontWeight: 700
                  }}>
                        <Icon name="timer" size={th.fs(19)} color={sc.accent} />
                        {myTimer ? myTimer.left <= 0 ? t("sc_timer_done") : FB.fmtTimer(myTimer.left) + " · " + t("timers_running") : t("sc_start_timer") + " · " + FB.fmtTimer(steps[stepIdx].timerSeconds)}
                      </button>
                  }
                  </div>
                  <div style={{ display: "flex", gap: 12, padding: `12px 20px ${18 + app.insets.bottom}px`, flexShrink: 0 }}>
                    <button onClick={() => setStepIdx((s) => Math.max(0, s - 1))} disabled={stepIdx === 0} style={{ width: 56, height: 56, borderRadius: 16, border: `1.5px solid ${sc.line}`, background: sc.surface, cursor: stepIdx === 0 ? "default" : "pointer", opacity: stepIdx === 0 ? 0.4 : 1, display: "grid", placeItems: "center" }}>
                      <Icon name="chevL" size={24} color="#fff" />
                    </button>
                    <button onClick={() => setStepIdx((s) => s + 1)} style={{ flex: 1, height: 56, borderRadius: 16, border: "none", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(17), fontWeight: 700, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
                      {stepIdx === steps.length - 1 ? t("sc_finish") : t("sc_next")} <Icon name="chevR" size={22} color="#fff" />
                    </button>
                  </div>
                </>
              }
            </div>
          </div>
        </div>
      </div>
    </div>);

}

Object.assign(window, { RecipeScreen, SousChefScreen, RoundBtn, StepperBtn, SecondaryAction, StatBlock });