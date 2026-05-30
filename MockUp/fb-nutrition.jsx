/* fb-nutrition.jsx — Phase 1.5 nutritional label (estimate).
   - NutritionFactsLabel: authentic Canadian bilingual "Nutrition Facts / Valeur
     nutritive" table. Values are generated (see fb-core mockNutrition), framed
     as an estimate — never a regulatory panel.
   - CnfPicker: searchable Canadian Nutrient File food picker (match correction).
   - NutritionPanel: editor control — generate, per-ingredient match + include
     toggle + correction, label preview.
   - NutritionCard: recipe-page display of a saved label.
   - AliasManager: Settings editor for the learned alias table.
   Everything is attached to window for the screen/app scripts. */

// Helvetica is the regulated typeface for the Canadian label — use it here
// (deliberately NOT the app's Hanken) so the artifact reads as authentic.
const NF_FONT = 'Helvetica, "Helvetica Neue", Arial, sans-serif';

function nfNum(v, unit) {
  if (v == null || isNaN(v)) return "0" + (unit ? " " + unit : "");
  let s;
  if (unit === "mg") s = (Math.abs(v) < 10 && v % 1 !== 0) ? String(Math.round(v * 10) / 10) : String(Math.round(v));
  else if (Math.abs(v) < 10) s = String(Math.round(v * 10) / 10);
  else s = String(Math.round(v));
  return s + (unit ? " " + unit : "");
}

// One nutrient line of the Nutrition Facts table.
function NFRow({ enName, frName, amount, dv, bold, indent, plus, last }) {
  return (
    <div style={{
      display: "flex", justifyContent: "space-between", alignItems: "baseline",
      padding: "1.5px 0", borderBottom: last ? "none" : "1px solid #000",
      paddingLeft: indent ? (plus ? 0 : 12) : 0,
    }}>
      <div style={{ fontWeight: bold ? 700 : 400, lineHeight: 1.2 }}>
        <span style={{ fontWeight: bold ? 700 : 400 }}>{enName}</span>
        <span style={{ fontWeight: 400, fontStyle: "italic" }}> / {frName}</span>
        <span style={{ fontWeight: 700 }}> {amount}</span>
      </div>
      {dv != null && <div style={{ fontWeight: 700, whiteSpace: "nowrap", paddingLeft: 8 }}>{dv} %</div>}
    </div>
  );
}

function NutritionFactsLabel({ nutrition, lang, mode = "perServing", servings }) {
  if (!nutrition) return null;
  const d = mode === "total" ? nutrition.total : nutrition.perServing;
  const basis = nutrition.servingsBasis || servings || 1;
  const fz = 12.5;
  const perLine = mode === "total"
    ? (lang === "fr" ? `Recette enti\u00e8re (${basis} portions)` : `Whole recipe (${basis} servings)`)
    : (lang === "fr" ? "Par 1 portion" : "Per 1 serving");
  const satTransDv = FB.dvPct("satTrans", (d.satFat || 0) + (d.transFat || 0));

  return (
    <div style={{
      fontFamily: NF_FONT, color: "#000", background: "#fff", border: "1.5px solid #000",
      borderRadius: 3, padding: "6px 9px 8px", fontSize: fz, lineHeight: 1.25, width: "100%", boxSizing: "border-box",
    }}>
      <div style={{ fontSize: 23, fontWeight: 800, letterSpacing: -0.4, lineHeight: 0.98 }}>Nutrition Facts</div>
      <div style={{ fontSize: 19, fontWeight: 800, fontStyle: "italic", letterSpacing: -0.3, lineHeight: 1, marginBottom: 2 }}>Valeur nutritive</div>
      <div style={{ borderBottom: "1px solid #000", paddingBottom: 2 }}>{perLine}</div>

      {/* Calories */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", borderBottom: "8px solid #000", padding: "2px 0 1px" }}>
        <div style={{ fontWeight: 800, fontSize: 17 }}>Calories</div>
        <div style={{ fontWeight: 800, fontSize: 17 }}>{Math.round(d.calories)}</div>
      </div>

      {/* DV header */}
      <div style={{ textAlign: "right", fontWeight: 700, padding: "1.5px 0", borderBottom: "1px solid #000" }}>
        % {lang === "fr" ? "valeur quotidienne" : "Daily Value"}*
        <div style={{ fontStyle: "italic", fontWeight: 700 }}>{lang === "fr" ? "" : "% valeur quotidienne*"}</div>
      </div>

      <NFRow enName="Fat" frName="Lipides" amount={nfNum(d.fat, "g")} dv={FB.dvPct("fat", d.fat)} bold />
      <NFRow enName="Saturated" frName="saturés" amount={nfNum(d.satFat, "g")} dv={satTransDv} indent />
      <NFRow enName="+ Trans" frName="trans" amount={nfNum(d.transFat, "g")} indent plus />
      <NFRow enName="Carbohydrate" frName="Glucides" amount={nfNum(d.carbs, "g")} bold />
      <NFRow enName="Fibre" frName="Fibres" amount={nfNum(d.fiber, "g")} dv={FB.dvPct("fiber", d.fiber)} indent />
      <NFRow enName="Sugars" frName="Sucres" amount={nfNum(d.sugars, "g")} dv={FB.dvPct("sugars", d.sugars)} indent />
      <NFRow enName="Protein" frName="Protéines" amount={nfNum(d.protein, "g")} bold />
      <NFRow enName="Cholesterol" frName="Cholestérol" amount={nfNum(d.cholesterol, "mg")} bold />
      <div style={{ borderBottom: "8px solid #000" }}>
        <NFRow enName="Sodium" frName="Sodium" amount={nfNum(d.sodium, "mg")} dv={FB.dvPct("sodium", d.sodium)} bold last />
      </div>
      <NFRow enName="Potassium" frName="Potassium" amount={nfNum(d.potassium, "mg")} dv={FB.dvPct("potassium", d.potassium)} />
      <NFRow enName="Calcium" frName="Calcium" amount={nfNum(d.calcium, "mg")} dv={FB.dvPct("calcium", d.calcium)} />
      <NFRow enName="Iron" frName="Fer" amount={nfNum(d.iron, "mg")} dv={FB.dvPct("iron", d.iron)} last />

      <div style={{ borderTop: "4px solid #000", marginTop: 2, paddingTop: 3, fontSize: 10.5, lineHeight: 1.3 }}>
        {lang === "fr"
          ? "*5 % ou moins c'est peu, 15 % ou plus c'est beaucoup"
          : "*5% or less is a little, 15% or more is a lot"}
      </div>
    </div>
  );
}

// Searchable CNF food picker — same pattern as the tag/link pickers.
function CnfPicker({ onPick, onClose, remember, setRemember, ingredientName }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const [q, setQ] = React.useState("");
  const list = FB.CNF_FOODS.filter((f) => {
    const s = (f.fr + " " + f.en).toLowerCase();
    return s.includes(q.trim().toLowerCase());
  }).slice(0, 12);
  return (
    <div style={{ marginTop: 8, border: `1px solid ${th.line}`, borderRadius: 12, overflow: "hidden", background: th.card }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 12px", borderBottom: `1px solid ${th.line}` }}>
        <Icon name="search" size={16} color={th.inkFaint} />
        <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("match_search")} style={{ border: "none", outline: "none", background: "transparent", flex: 1, fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink, minWidth: 0 }} />
        <button onClick={onClose} style={{ border: "none", background: "none", cursor: "pointer", padding: 2, lineHeight: 0 }}><Icon name="x" size={16} color={th.inkFaint} /></button>
      </div>
      <div className="fb-scroll" style={{ maxHeight: 230, overflowY: "auto", WebkitOverflowScrolling: "touch" }}>
        {list.map((f, i) => (
          <button key={f.code} onClick={() => onPick(f)} style={{ display: "flex", alignItems: "center", gap: 10, width: "100%", border: "none", borderBottom: i < list.length - 1 ? `1px solid ${th.line}` : "none", background: "transparent", padding: "10px 13px", cursor: "pointer", textAlign: "left" }}>
            <span style={{ flex: 1, minWidth: 0 }}>
              <span style={{ display: "block", fontFamily: th.fontUI, fontSize: th.fs(14.5), color: th.ink, fontWeight: 500 }}>{FB.cnfName(f, lang)}</span>
              <span style={{ fontFamily: "ui-monospace, monospace", fontSize: th.fs(11), color: th.inkFaint }}>{t("cnf_label")} {f.code} · {f.kcal} kcal {t("per_100")}</span>
            </span>
          </button>
        ))}
        {list.length === 0 && <div style={{ padding: "14px 13px", fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkFaint }}>{t("no_results")}</div>}
      </div>
      <button onClick={() => setRemember(!remember)} style={{ display: "flex", alignItems: "center", gap: 9, width: "100%", border: "none", borderTop: `1px solid ${th.line}`, background: "transparent", padding: "10px 13px", cursor: "pointer", textAlign: "left" }}>
        <span style={{ width: 20, height: 20, borderRadius: 6, flexShrink: 0, border: `2px solid ${remember ? th.accent : th.lineStrong}`, background: remember ? th.accent : "transparent", display: "grid", placeItems: "center" }}>
          {remember && <Icon name="check" size={12} color="#fff" stroke={3} />}
        </span>
        <span style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft, fontWeight: 600 }}>{t("match_set_default")}{ingredientName ? ` \u00b7 \u00ab ${ingredientName} \u00bb` : ""}</span>
      </button>
    </div>
  );
}

// Confidence / state badge for a match row. (Unmatched is already shown by the
// inline row text, so no badge for that case.)
function MatchBadge({ ref, t, th }) {
  if (!ref || !ref.foodCode) return null;
  if (!ref.includeInCalc) return <Badge color={th.inkFaint} bg={th.line} label={t("match_excluded")} icon="minus" th={th} />;
  if (ref.confidence < 0.6) return <Badge color="#C58A2E" bg="#C58A2E1f" label={t("match_check")} icon="note" th={th} />;
  return null;
}
function Badge({ color, bg, label, icon, th }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 4, padding: "2px 8px", borderRadius: 999, background: bg, color, fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 700, whiteSpace: "nowrap" }}>
      <Icon name={icon} size={11} color={color} stroke={2.4} /> {label}
    </span>
  );
}

// Editor control: generate + per-ingredient matching + label preview.
function NutritionPanel({ form, setForm, existing }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const named = form.ingredients.filter((x) => x.name.trim());
  const generated = !!form.nutrition;
  const [editingIdx, setEditingIdx] = React.useState(null);
  const [remember, setRemember] = React.useState(true);
  const [mode, setMode] = React.useState("perServing");

  const recompute = (ings) => {
    const inc = ings.filter((x) => x.name.trim() && x.nutritionRef && x.nutritionRef.includeInCalc).length;
    const unmatched = ings.some((x) => x.name.trim() && (!x.nutritionRef || !x.nutritionRef.foodCode || !x.nutritionRef.includeInCalc));
    return FB.mockNutrition(
      { id: existing ? existing.id : "__draft", title: form.title, servings: form.servings },
      { servings: form.servings, includedCount: inc, hasUnmatched: unmatched }
    );
  };

  const generate = () => {
    setForm((f) => {
      const ings = f.ingredients.map((x) => {
        if (!x.name.trim()) return x;
        if (x.nutritionRef) return x;
        return { ...x, nutritionRef: FB.resolveMatch(x, app.aliases) };
      });
      return { ...f, ingredients: ings, nutrition: recompute(ings) };
    });
  };

  const setRef = (idx, patch) => {
    setForm((f) => {
      const ings = f.ingredients.map((x, j) => j === idx ? { ...x, nutritionRef: { ...(x.nutritionRef || {}), ...patch } } : x);
      return { ...f, ingredients: ings, nutrition: recompute(ings) };
    });
  };

  const pickFood = (idx, food) => {
    const ing = form.ingredients[idx];
    setRef(idx, { foodCode: food.code, matchedName: FB.cnfName(food, "fr"), confidence: 1, includeInCalc: ing.nutritionRef ? ing.nutritionRef.includeInCalc : !FB.defaultExcluded(ing) });
    if (remember && ing.name.trim()) app.addAlias(ing.name, food.code);
    setEditingIdx(null);
  };

  if (named.length === 0) {
    return (
      <div style={{ padding: "14px 16px", borderRadius: 14, background: th.cardSoft, border: `1px dashed ${th.lineStrong}`, fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkFaint, lineHeight: 1.5 }}>
        {lang === "fr" ? "Ajoutez des ingr\u00e9dients ci-dessus, puis g\u00e9n\u00e9rez l'\u00e9tiquette nutritionnelle." : "Add ingredients above, then generate the nutrition label."}
      </div>
    );
  }

  return (
    <div>
      {/* Heading */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
        <span style={{ width: 28, height: 28, borderRadius: 8, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="note" size={16} color={th.accent} /></span>
        <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(18), fontWeight: 600, color: th.ink }}>{t("nutrition_section")}</div>
        <span style={{ padding: "2px 8px", borderRadius: 999, background: th.line, color: th.inkSoft, fontFamily: th.fontUI, fontSize: th.fs(10.5), fontWeight: 700, textTransform: "uppercase", letterSpacing: 0.4 }}>{t("nutrition_estimate")}</span>
      </div>
      <div style={{ fontFamily: th.fontUI, fontSize: th.fs(13), color: th.inkSoft, lineHeight: 1.5, marginBottom: 12 }}>{t("nutrition_intro")}</div>

      {!generated ? (
        <button onClick={generate} style={{ width: "100%", height: 50, borderRadius: 14, border: "none", cursor: "pointer", background: th.accent, color: "#fff", fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          <Icon name="note" size={th.fs(18)} color="#fff" /> {t("nutrition_gen")}
        </button>
      ) : (
        <>
          {/* Matching list */}
          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), fontWeight: 700, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.5, margin: "4px 0 8px" }}>{t("match_title")}</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {form.ingredients.map((ing, i) => {
              if (!ing.name.trim()) return null;
              const ref = ing.nutritionRef;
              const matched = ref && ref.foodCode;
              const on = ref && ref.includeInCalc;
              return (
                <div key={i} style={{ background: th.cardSoft, border: `1px solid ${th.line}`, borderRadius: 14, padding: "10px 12px" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    {/* include toggle */}
                    <button onClick={() => setRef(i, { includeInCalc: !on })} title={t("match_include")} style={{ width: 24, height: 24, borderRadius: 7, flexShrink: 0, cursor: "pointer", border: `2px solid ${on ? th.accent : th.lineStrong}`, background: on ? th.accent : "transparent", display: "grid", placeItems: "center" }}>
                      {on && <Icon name="check" size={14} color="#fff" stroke={3} />}
                    </button>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 600, color: th.ink, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ing.name}</div>
                      <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 2, flexWrap: "wrap" }}>
                        <span style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: matched ? th.inkSoft : th.inkFaint, fontStyle: matched ? "normal" : "italic" }}>
                          {matched ? "\u2192 " + FB.cnfName(ref.foodCode, lang) : t("match_unmatched")}
                        </span>
                        {ref && ref.fromAlias && <Icon name="check" size={12} color={th.accent} />}
                        <MatchBadge ref={ref} t={t} th={th} />
                      </div>
                    </div>
                    <button onClick={() => { setEditingIdx(editingIdx === i ? null : i); setRemember(true); }} title={t("match_correct")} style={{ width: 32, height: 32, borderRadius: 9, flexShrink: 0, border: `1px solid ${th.line}`, background: th.card, cursor: "pointer", display: "grid", placeItems: "center" }}>
                      <Icon name="pencil" size={15} color={th.inkSoft} />
                    </button>
                  </div>
                  {editingIdx === i && (
                    <CnfPicker ingredientName={ing.name} remember={remember} setRemember={setRemember}
                      onPick={(food) => pickFood(i, food)} onClose={() => setEditingIdx(null)} />
                  )}
                </div>
              );
            })}
          </div>

          {form.nutrition.hasUnmatched && (
            <div style={{ display: "flex", gap: 8, marginTop: 12, padding: "10px 13px", borderRadius: 12, background: "#C58A2E15", border: "1px solid #C58A2E55" }}>
              <Icon name="note" size={16} color="#9a6c1e" style={{ flexShrink: 0, marginTop: 1 }} />
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: "#8a6018", lineHeight: 1.45, fontWeight: 600 }}>{t("nutrition_unmatched")}</div>
            </div>
          )}

          {/* Label preview */}
          <div style={{ display: "flex", gap: 4, margin: "16px 0 10px", background: th.dark ? "rgba(255,255,255,0.06)" : th.canvas2, borderRadius: 11, padding: 3 }}>
            {[["perServing", t("nutrition_per_serving")], ["total", t("nutrition_amount_total")]].map(([m, lbl]) => (
              <button key={m} onClick={() => setMode(m)} style={{ flex: 1, padding: "8px 6px", borderRadius: 9, border: "none", cursor: "pointer", background: mode === m ? th.card : "transparent", color: mode === m ? th.ink : th.inkSoft, fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: mode === m ? 700 : 600, boxShadow: mode === m ? th.shadow : "none" }}>{lbl}</button>
            ))}
          </div>
          <NutritionFactsLabel nutrition={form.nutrition} lang={lang} mode={mode} servings={form.servings} />

          <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint, lineHeight: 1.45, margin: "9px 2px 0" }}>{t("nutrition_disclaimer")}</div>

          <button onClick={generate} style={{ marginTop: 12, display: "inline-flex", alignItems: "center", gap: 7, border: `1px solid ${th.line}`, background: th.card, borderRadius: 11, padding: "9px 14px", cursor: "pointer", fontFamily: th.fontUI, fontSize: th.fs(13.5), fontWeight: 700, color: th.accent }}>
            <Icon name="timer" size={15} color={th.accent} /> {t("nutrition_regen")}
          </button>
        </>
      )}
    </div>
  );
}

// Recipe-page display of a saved label (collapsible to stay calm).
function NutritionCard({ recipe }) {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const [open, setOpen] = React.useState(false);
  const [mode, setMode] = React.useState("perServing");
  const n = recipe.nutrition;
  if (!n) return null;
  const per = n.perServing;
  const quick = [
    [Math.round(per.calories), lang === "fr" ? "Cal" : "Cal"],
    [nfNum(per.protein, "g"), lang === "fr" ? "Prot." : "Protein"],
    [nfNum(per.fat, "g"), lang === "fr" ? "Lip." : "Fat"],
    [nfNum(per.carbs, "g"), lang === "fr" ? "Gluc." : "Carbs"],
  ];
  return (
    <div style={{ marginTop: 30 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 9, margin: "0 0 12px" }}>
        <h2 style={{ margin: 0, fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink }}>{t("nutrition_section")}</h2>
        <span style={{ padding: "3px 9px", borderRadius: 999, background: th.accentSoft, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(10.5), fontWeight: 700, textTransform: "uppercase", letterSpacing: 0.4 }}>{t("nutrition_estimate")}</span>
      </div>
      <div style={{ background: th.card, borderRadius: 20, padding: "16px 18px", boxShadow: th.shadow }}>
        {/* quick per-serving readout */}
        <div style={{ display: "flex", justifyContent: "space-between", gap: 6 }}>
          {quick.map(([v, l], i) => (
            <div key={i} style={{ flex: 1, textAlign: "center" }}>
              <div style={{ fontFamily: th.fontDisplay, fontSize: th.fs(22), fontWeight: 600, color: th.ink, lineHeight: 1 }}>{v}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11), fontWeight: 600, color: th.inkFaint, textTransform: "uppercase", letterSpacing: 0.3, marginTop: 4 }}>{l}</div>
            </div>
          ))}
        </div>
        <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint, textAlign: "center", marginTop: 8 }}>{t("nutrition_per_serving")} · {n.servingsBasis} {n.servingsBasis === 1 ? t("serving_one") : t("servings")}</div>

        {n.hasUnmatched && (
          <div style={{ display: "flex", gap: 7, marginTop: 12, padding: "9px 12px", borderRadius: 11, background: "#C58A2E15" }}>
            <Icon name="note" size={15} color="#9a6c1e" style={{ flexShrink: 0, marginTop: 1 }} />
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12), color: "#8a6018", lineHeight: 1.4, fontWeight: 600 }}>{t("nutrition_unmatched")}</div>
          </div>
        )}

        <button onClick={() => setOpen((v) => !v)} style={{ width: "100%", marginTop: 14, height: 44, borderRadius: 12, cursor: "pointer", border: `1.5px solid ${th.accent}`, background: th.accentSoft, color: th.accent, fontFamily: th.fontUI, fontSize: th.fs(14.5), fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          <Icon name={open ? "chevD" : "note"} size={th.fs(17)} color={th.accent} /> {open ? t("nutrition_hide") : t("nutrition_view")}
        </button>

        {open && (
          <div style={{ marginTop: 14 }}>
            <div style={{ display: "flex", gap: 4, marginBottom: 10, background: th.dark ? "rgba(255,255,255,0.06)" : th.canvas2, borderRadius: 11, padding: 3 }}>
              {[["perServing", t("nutrition_per_serving")], ["total", t("nutrition_amount_total")]].map(([m, lbl]) => (
                <button key={m} onClick={() => setMode(m)} style={{ flex: 1, padding: "8px 6px", borderRadius: 9, border: "none", cursor: "pointer", background: mode === m ? th.card : "transparent", color: mode === m ? th.ink : th.inkSoft, fontFamily: th.fontUI, fontSize: th.fs(13), fontWeight: mode === m ? 700 : 600, boxShadow: mode === m ? th.shadow : "none" }}>{lbl}</button>
              ))}
            </div>
            <NutritionFactsLabel nutrition={n} lang={lang} mode={mode} servings={recipe.servings} />
            <div style={{ fontFamily: th.fontUI, fontSize: th.fs(11.5), color: th.inkFaint, lineHeight: 1.45, marginTop: 9 }}>{t("nutrition_disclaimer")}</div>
          </div>
        )}
      </div>
    </div>
  );
}

// Settings — learned alias table editor (sibling to "Tags personnalisés").
function AliasManager() {
  const th = useTheme();
  const app = useApp();
  const { t, lang } = app;
  const entries = Object.entries(app.aliases || {});
  const [editKey, setEditKey] = React.useState(null);
  const [remember, setRemember] = React.useState(true);
  return (
    <React.Fragment>
      <div style={{ padding: "12px 16px 8px", fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkFaint, lineHeight: 1.45, borderBottom: entries.length ? `1px solid ${th.line}` : "none" }}>{t("aliases_hint")}</div>
      {entries.length === 0 && <div style={{ padding: "8px 16px 14px", fontFamily: th.fontUI, fontSize: th.fs(13.5), color: th.inkFaint, lineHeight: 1.5 }}>{t("aliases_empty")}</div>}
      {entries.map(([key, val], i) => (
        <div key={key} style={{ borderBottom: i < entries.length - 1 ? `1px solid ${th.line}` : "none" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 11, padding: "12px 16px" }}>
            <span style={{ width: 30, height: 30, borderRadius: 9, background: th.accentSoft, display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="leaf" size={15} color={th.accent} stroke={2.2} /></span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(15), fontWeight: 600, color: th.ink }}>{key}</div>
              <div style={{ fontFamily: th.fontUI, fontSize: th.fs(12.5), color: th.inkSoft }}>{"\u2192 " + FB.cnfName(val.foodCode, lang)}</div>
            </div>
            <button onClick={() => { setEditKey(editKey === key ? null : key); setRemember(true); }} style={{ width: 34, height: 34, borderRadius: 9, border: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="pencil" size={16} color={th.inkSoft} /></button>
            <button onClick={() => app.removeAlias(key)} style={{ width: 34, height: 34, borderRadius: 9, border: `1px solid ${th.line}`, background: "transparent", cursor: "pointer", display: "grid", placeItems: "center", flexShrink: 0 }}><Icon name="trash" size={16} color={th.inkSoft} /></button>
          </div>
          {editKey === key && (
            <div style={{ padding: "0 16px 12px" }}>
              <CnfPicker ingredientName={key} remember={remember} setRemember={setRemember}
                onPick={(food) => { app.addAlias(key, food.code); setEditKey(null); }}
                onClose={() => setEditKey(null)} />
            </div>
          )}
        </div>
      ))}
    </React.Fragment>
  );
}

Object.assign(window, { NutritionFactsLabel, CnfPicker, NutritionPanel, NutritionCard, AliasManager, nfNum });
