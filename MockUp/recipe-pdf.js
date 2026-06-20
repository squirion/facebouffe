/* recipe-pdf.js — Facebouffe recipe → print-ready cookbook page.
   Vanilla JS. Reads the real seed (window.FB.SEED) and the app's own
   formatting helpers, renders the recipe into editorial "blocks", then a
   measure-based paginator flows those blocks into framed US-Letter (or A4)
   sheets — one printed page per sheet. No React; image-slot.js supplies the
   user-fillable photo frames. */
(function () {
  "use strict";
  var FB = window.FB;
  var PREFS = FB.SEED.profile.units;
  var LANG = FB.SEED.profile.language || "fr";
  var TAGS = {};
  FB.SEED.tags.forEach(function (t) { TAGS[t.id] = t; });

  // ── tiny helpers ───────────────────────────────────────────
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }
  function node(html) {
    var d = document.createElement("div");
    d.innerHTML = html.trim();
    return d.firstElementChild;
  }
  function recipeById(id) {
    return FB.SEED.recipes.filter(function (r) { return r.id === id; })[0] || null;
  }
  function nonFavTags(recipe) {
    return (recipe.tags || []).filter(function (id) { return id !== "tag-fav"; })
      .map(function (id) { return TAGS[id]; }).filter(Boolean);
  }
  function categoryLabel(recipe) {
    var t = nonFavTags(recipe)[0];
    return t ? FB.tagName(t, LANG) : (LANG === "fr" ? "Recette" : "Recipe");
  }

  // ── rich text: {{temp:v:u}} → converted, {{link:id}} → recipe title ──
  function renderRich(text) {
    var prefU = FB.prefTempUnit(PREFS);
    var parts = String(text || "").split(/(\{\{[^}]+\}\})/g);
    return parts.map(function (p) {
      var tm = p.match(/^\{\{temp:([0-9.]+):([cfCF])\}\}$/);
      if (tm) return '<span class="rich-temp">' + esc(FB.fmtTemp(tm[1], tm[2], prefU)) + "</span>";
      var lm = p.match(/^\{\{link:([^}]+)\}\}$/);
      if (lm) {
        var r = recipeById(lm[1]);
        return '<span class="rich-link">' + esc(r ? r.title : "—") + "</span>";
      }
      return esc(p);
    }).join("");
  }

  // ── nutrition facts label (vanilla port of the app's bilingual panel) ──
  function nfNum(v, unit) {
    if (v == null || isNaN(v)) return "0" + (unit ? " " + unit : "");
    var s;
    if (unit === "mg") s = (Math.abs(v) < 10 && v % 1 !== 0) ? String(Math.round(v * 10) / 10) : String(Math.round(v));
    else if (Math.abs(v) < 10) s = String(Math.round(v * 10) / 10);
    else s = String(Math.round(v));
    return s + (unit ? "\u00a0" + unit : "");
  }
  function nfRow(en, fr, amount, dv, opt) {
    opt = opt || {};
    var cls = "nf-row" + (opt.bold ? " nf-bold" : "") + (opt.indent ? " nf-indent" : "") +
      (opt.plus ? " nf-plus" : "") + (opt.last ? " nf-last" : "");
    return '<div class="' + cls + '"><div class="nf-name">' +
      '<span class="' + (opt.bold ? "nf-b" : "") + '">' + en + '</span>' +
      '<span class="nf-fr"> / ' + fr + '</span>' +
      '<span class="nf-amt"> ' + amount + '</span></div>' +
      (dv != null ? '<div class="nf-dv">' + dv + ' %</div>' : "") + "</div>";
  }
  function nutritionLabelHTML(n, mode) {
    var d = mode === "total" ? n.total : n.perServing;
    var basis = n.servingsBasis || 1;
    var per = mode === "total"
      ? (LANG === "fr" ? "Recette enti\u00e8re (" + basis + " portions)" : "Whole recipe (" + basis + " servings)")
      : (LANG === "fr" ? "Par 1 portion" : "Per 1 serving");
    var satTransDv = FB.dvPct("satTrans", (d.satFat || 0) + (d.transFat || 0));
    var foot = LANG === "fr"
      ? "*5 % ou moins c'est peu, 15 % ou plus c'est beaucoup"
      : "*5% or less is a little, 15% or more is a lot";
    return '' +
      '<div class="nf">' +
      '<div class="nf-t1">Nutrition Facts</div>' +
      '<div class="nf-t2">Valeur nutritive</div>' +
      '<div class="nf-per">' + per + "</div>" +
      '<div class="nf-cal"><span>Calories</span><span>' + Math.round(d.calories) + "</span></div>" +
      '<div class="nf-dvhead">% ' + (LANG === "fr" ? "valeur quotidienne" : "Daily Value") + "*</div>" +
      nfRow("Fat", "Lipides", nfNum(d.fat, "g"), FB.dvPct("fat", d.fat), { bold: true }) +
      nfRow("Saturated", "satur\u00e9s", nfNum(d.satFat, "g"), satTransDv, { indent: true }) +
      nfRow("+ Trans", "trans", nfNum(d.transFat, "g"), null, { indent: true, plus: true }) +
      nfRow("Carbohydrate", "Glucides", nfNum(d.carbs, "g"), null, { bold: true }) +
      nfRow("Fibre", "Fibres", nfNum(d.fiber, "g"), FB.dvPct("fiber", d.fiber), { indent: true }) +
      nfRow("Sugars", "Sucres", nfNum(d.sugars, "g"), FB.dvPct("sugars", d.sugars), { indent: true }) +
      nfRow("Protein", "Prot\u00e9ines", nfNum(d.protein, "g"), null, { bold: true }) +
      nfRow("Cholesterol", "Cholest\u00e9rol", nfNum(d.cholesterol, "mg"), null, { bold: true }) +
      '<div class="nf-thick">' + nfRow("Sodium", "Sodium", nfNum(d.sodium, "mg"), FB.dvPct("sodium", d.sodium), { bold: true, last: true }) + "</div>" +
      nfRow("Potassium", "Potassium", nfNum(d.potassium, "mg"), FB.dvPct("potassium", d.potassium)) +
      nfRow("Calcium", "Calcium", nfNum(d.calcium, "mg"), FB.dvPct("calcium", d.calcium)) +
      nfRow("Iron", "Fer", nfNum(d.iron, "mg"), FB.dvPct("iron", d.iron), { last: true }) +
      '<div class="nf-foot">' + foot + "</div>" +
      "</div>";
  }

  // ── photo frame: image-slot when a filename exists, else color panel ──
  function heroFrameHTML(recipe) {
    var cat = esc(categoryLabel(recipe).toUpperCase());
    if (recipe.heroImage) {
      return '<div class="hero hero-photo">' +
        '<image-slot id="pdf-hero-' + esc(recipe.id) + '" shape="rect" fit="cover" ' +
        'placeholder="' + esc(recipe.heroImage) + '" style="display:block;width:100%;height:100%;"></image-slot>' +
        '</div>';
    }
    var pal = FB.fallbackColor(recipe);
    var initial = esc((recipe.title || "?").trim().charAt(0).toUpperCase());
    return '<div class="hero hero-fallback" style="background:' + pal.bg + ';color:' + pal.ink + ';">' +
      '<div class="hero-monogram">' + initial + "</div>" +
      '<div class="hero-kicker">' + cat + "</div>" +
      "</div>";
  }

  // ── blocks ──────────────────────────────────────────────────
  function openerBlock(recipe) {
    var chips = nonFavTags(recipe).map(function (t) {
      return '<span class="chip"><span class="chip-dot" style="background:' + t.color + '"></span>' +
        esc(FB.tagName(t, LANG)) + "</span>";
    }).join("");
    var src = recipe.source ? '<div class="opener-source">' + esc(recipe.source) + "</div>" : "";
    return node(
      '<div class="block b-opener">' +
        heroFrameHTML(recipe) +
        '<div class="opener-head">' +
          (chips ? '<div class="chips">' + chips + "</div>" : "") +
          '<h1 class="opener-title">' + esc(recipe.title) + "</h1>" +
          src +
        "</div>" +
      "</div>"
    );
  }

  function metaBlock(recipe) {
    var cells = [
      [LANG === "fr" ? "Pr\u00e9paration" : "Prep", FB.fmtDuration(recipe.prepTimeMinutes, LANG)],
      [LANG === "fr" ? "Cuisson" : "Cook", FB.fmtDuration(recipe.cookTimeMinutes, LANG)],
      [LANG === "fr" ? "Total" : "Total", FB.fmtDuration(FB.totalTime(recipe), LANG)],
      [LANG === "fr" ? "Portions" : "Servings", String(recipe.servings)]
    ];
    var html = cells.map(function (c, i) {
      return (i ? '<div class="meta-div"></div>' : "") +
        '<div class="meta-cell"><div class="meta-val">' + esc(c[1]) +
        '</div><div class="meta-lbl">' + esc(c[0]) + "</div></div>";
    }).join("");
    return node('<div class="block b-meta"><div class="meta-strip">' + html + "</div></div>");
  }

  function headnoteBlock(recipe) {
    if (!recipe.description) return null;
    var raw = String(recipe.description).replace(/^\s+/, "");
    var first = raw.charAt(0);
    var rest = raw.slice(1);
    var html = '<span class="dropcap">' + esc(first) + "</span>" + renderRich(rest);
    return node('<div class="block b-headnote"><p class="headnote">' + html + "</p></div>");
  }

  function sectionHeadHTML(title, right, suite) {
    return '<div class="sec-head">' +
      '<span class="sec-rule"></span>' +
      '<span class="sec-title">' + esc(title) + (suite ? ' <span class="sec-suite">(suite)</span>' : "") + "</span>" +
      (right ? '<span class="sec-right">' + esc(right) + "</span>" : "") +
      "</div>";
  }

  function nutritionBlock(recipe) {
    var n = recipe.nutrition;
    var per = n.perServing;
    var quick = [
      [Math.round(per.calories), "Calories"],
      [nfNum(per.protein, "g"), LANG === "fr" ? "Prot\u00e9ines" : "Protein"],
      [nfNum(per.fat, "g"), LANG === "fr" ? "Lipides" : "Fat"],
      [nfNum(per.carbs, "g"), LANG === "fr" ? "Glucides" : "Carbs"]
    ];
    var qh = quick.map(function (q, i) {
      return (i ? '<div class="meta-div"></div>' : "") +
        '<div class="meta-cell"><div class="meta-val">' + esc(q[0]) +
        '</div><div class="meta-lbl">' + esc(q[1]) + "</div></div>";
    }).join("");
    var basis = FB.t(LANG, "nutrition_per_serving") + " \u00b7 " + n.servingsBasis + " " +
      (n.servingsBasis === 1 ? FB.t(LANG, "serving_one") : FB.t(LANG, "servings"));
    var disc = FB.t(LANG, "nutrition_disclaimer") + (n.hasUnmatched ? " " + FB.t(LANG, "nutrition_unmatched") : "");
    return node(
      '<div class="block b-nutrition">' +
        sectionHeadHTML(FB.t(LANG, "nutrition_section"), FB.t(LANG, "nutrition_estimate"), false) +
        '<div class="nut-grid">' +
          '<div class="nut-left">' +
            '<div class="meta-strip nut-quick">' + qh + "</div>" +
            '<div class="nut-basis">' + esc(basis) + "</div>" +
            '<div class="nut-disc">' + esc(disc) + "</div>" +
          "</div>" +
          '<div class="nut-right">' + nutritionLabelHTML(n, "perServing") + "</div>" +
        "</div>" +
      "</div>"
    );
  }

  function ingredientRowHTML(ing) {
    var d = FB.displayIngredient(ing, 1, PREFS, LANG);
    var qty = d.qtyText + (d.unitText ? " " + d.unitText : "");
    var note = d.note ? ' <span class="ing-note">· ' + esc(d.note) + "</span>" : "";
    return '<div class="ing-row">' +
      '<span class="ing-qty">' + esc(qty || "—") + "</span>" +
      '<span class="ing-name">' + esc(d.name) + note + "</span></div>";
  }

  function stepRowHTML(step, idx) {
    var img = step.image
      ? '<div class="step-photo"><image-slot id="pdf-step-' + esc(currentRecipeId) + "-" + idx +
        '" shape="rect" fit="cover" placeholder="' + esc(step.image) +
        '" style="display:block;width:100%;height:100%;"></image-slot></div>'
      : "";
    var timer = step.timerSeconds != null
      ? '<span class="step-timer">&#9719; ' + esc(FB.fmtTimer(step.timerSeconds)) + "</span>"
      : "";
    return '<div class="step-row">' +
      '<div class="step-num">' + (idx + 1) + "</div>" +
      '<div class="step-body"><div class="step-text">' + renderRich(step.text) + "</div>" +
      (timer ? '<div class="step-meta">' + timer + "</div>" : "") + img + "</div></div>";
  }

  var currentRecipeId = null;

  // ── builds the ordered list of flow items for one recipe ─────
  function buildItems(recipe) {
    currentRecipeId = recipe.id;
    var items = [];
    items.push({ kind: "atomic", el: openerBlock(recipe) });
    items.push({ kind: "atomic", el: metaBlock(recipe) });
    var hn = headnoteBlock(recipe);
    if (hn) items.push({ kind: "atomic", el: hn });

    var yieldNote = recipe.servings + " " + (recipe.servings === 1 ? FB.t(LANG, "serving_one") : FB.t(LANG, "servings"));
    var ingTitle = FB.t(LANG, "ingredients");

    // Ingredients — splittable group (fills the title page, flows cleanly).
    items.push({
      kind: "group",
      makeHead: function (suite) { return node('<div class="block sec-head-block">' + sectionHeadHTML(ingTitle, suite ? "" : yieldNote, suite) + "</div>"); },
      rows: recipe.ingredients.map(function (ing) { return node('<div class="ing-row-block">' + ingredientRowHTML(ing) + "</div>"); })
    });

    // Steps — splittable group, continuous numbering.
    var stepTitle = FB.t(LANG, "steps");
    items.push({
      kind: "group",
      makeHead: function (suite) { return node('<div class="block sec-head-block">' + sectionHeadHTML(stepTitle, "", suite) + "</div>"); },
      rows: recipe.steps.map(function (s, i) { return node('<div class="step-block">' + stepRowHTML(s, i) + "</div>"); })
    });

    // Nutrition (estimate) — its own full-width band, if generated.
    if (recipe.nutrition) items.push({ kind: "atomic", el: nutritionBlock(recipe) });

    // Cook's note (personal journal) — only if present.
    if (recipe.personal && recipe.personal.notes) {
      items.push({ kind: "atomic", el: node(
        '<div class="block b-note"><div class="note-label">' +
        (LANG === "fr" ? "Note du cuisinier" : "Cook's note") + "</div>" +
        '<p class="note-text">' + esc(recipe.personal.notes) + "</p></div>"
      )});
    }

    // Gallery — framed detail shots.
    if (recipe.gallery && recipe.gallery.length) {
      var gh = recipe.gallery.map(function (g, i) {
        return '<div class="gal-item"><div class="gal-frame"><image-slot id="pdf-gal-' + esc(recipe.id) + "-" + i +
          '" shape="rect" fit="cover" placeholder="' + esc(g) +
          '" style="display:block;width:100%;height:100%;"></image-slot></div></div>';
      }).join("");
      items.push({ kind: "atomic", el: node(
        '<div class="block b-gallery">' + sectionHeadHTML(FB.t(LANG, "gallery"), "", false) +
        '<div class="gal-row">' + gh + "</div></div>"
      )});
    }

    // See also (linked recipes).
    var linked = (recipe.links || []).map(recipeById).filter(Boolean);
    if (linked.length) {
      var ls = linked.map(function (r) {
        return '<div class="see-row"><span class="see-mark">&#10022;</span><span class="see-title">' +
          esc(r.title) + "</span></div>";
      }).join("");
      items.push({ kind: "atomic", el: node(
        '<div class="block b-see">' + sectionHeadHTML(FB.t(LANG, "see_also"), "", false) + ls + "</div>"
      )});
    }
    return items;
  }

  // ── page factory ────────────────────────────────────────────
  function makePage(recipe) {
    var cat = esc(categoryLabel(recipe).toUpperCase());
    var p = node(
      '<div class="page">' +
        '<div class="page-frame"></div>' +
        '<div class="page-corner tl"></div><div class="page-corner tr"></div>' +
        '<div class="page-corner bl"></div><div class="page-corner br"></div>' +
        '<div class="page-inner">' +
          '<div class="runhead">' +
            '<span class="rh-mark">Facebouffe</span>' +
            '<span class="rh-title">' + esc(recipe.title) + "</span>" +
            '<span class="rh-cat">' + cat + "</span>" +
          "</div>" +
          '<div class="content"></div>' +
          '<div class="runfoot">' +
            '<span class="rf-left">' + esc(recipe.source || (LANG === "fr" ? "Carnet de recettes" : "Recipe book")) + "</span>" +
            '<span class="rf-mark">&#10022;</span>' +
            '<span class="rf-page"></span>' +
          "</div>" +
        "</div>" +
      "</div>"
    );
    return p;
  }

  // ── the paginator ───────────────────────────────────────────
  function layout(recipe) {
    var root = document.getElementById("doc");
    root.innerHTML = "";
    var items = buildItems(recipe);

    var pages = [];
    var page, content, budget;

    function fresh() {
      page = makePage(recipe);
      root.appendChild(page);
      content = page.querySelector(".content");
      pages.push(page);
      // budget = inner height minus runhead, gap, and reserved footer zone.
      var inner = page.querySelector(".page-inner");
      var rh = page.querySelector(".runhead");
      var innerH = inner.clientHeight;
      var pad = parseFloat(getComputedStyle(content).marginTop) || 0;
      budget = innerH - rh.offsetHeight - pad - FOOTER_ZONE;
    }
    var FOOTER_ZONE = 46;

    function fits() { return content.scrollHeight <= budget + 0.5; }
    function placeAtomic(el) {
      content.appendChild(el);
      if (!fits() && content.childElementCount > 1) {
        content.removeChild(el);
        fresh();
        content.appendChild(el);
      }
    }
    function placeGroup(g) {
      var head = g.makeHead(false);
      content.appendChild(head);
      var placedUnderHead = 0;
      if (!fits() && content.childElementCount > 1) {
        content.removeChild(head);
        fresh();
        head = g.makeHead(false);
        content.appendChild(head);
      }
      g.rows.forEach(function (row) {
        content.appendChild(row);
        if (!fits()) {
          content.removeChild(row);
          // orphan heading at page bottom → drop it before breaking
          if (placedUnderHead === 0 && head && head.parentNode === content) {
            content.removeChild(head);
          }
          fresh();
          head = g.makeHead(true);
          content.appendChild(head);
          placedUnderHead = 0;
          content.appendChild(row);
        }
        placedUnderHead++;
      });
    }

    fresh();
    items.forEach(function (it) {
      if (it.kind === "atomic") placeAtomic(it.el);
      else placeGroup(it);
    });

    // footer page numbers
    var n = pages.length;
    pages.forEach(function (pg, i) {
      pg.querySelector(".rf-page").textContent = (LANG === "fr" ? "p. " : "p. ") + (i + 1) + " / " + n;
    });
  }

  // ── recipe picker + controls (screen only) ──────────────────
  function buildToolbar() {
    var sel = document.getElementById("recipe-select");
    FB.SEED.recipes.forEach(function (r) {
      var o = document.createElement("option");
      o.value = r.id; o.textContent = r.title;
      sel.appendChild(o);
    });
    var saved = null;
    try { saved = localStorage.getItem("fb-pdf-recipe"); } catch (e) {}
    if (saved && recipeById(saved)) sel.value = saved;
    else sel.value = "rec-beignes-frits";
    sel.addEventListener("change", function () {
      try { localStorage.setItem("fb-pdf-recipe", sel.value); } catch (e) {}
      render();
    });

    var paper = document.getElementById("paper-select");
    var savedPaper = null;
    try { savedPaper = localStorage.getItem("fb-pdf-paper"); } catch (e) {}
    if (savedPaper) paper.value = savedPaper;
    document.documentElement.classList.toggle("a4", paper.value === "a4");
    paper.addEventListener("change", function () {
      try { localStorage.setItem("fb-pdf-paper", paper.value); } catch (e) {}
      document.documentElement.classList.toggle("a4", paper.value === "a4");
      render();
    });

    document.getElementById("print-btn").addEventListener("click", function () { window.print(); });
  }

  function render() {
    var id = document.getElementById("recipe-select").value;
    var recipe = recipeById(id);
    if (recipe) layout(recipe);
  }

  function boot() {
    buildToolbar();
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(render);
      // also render immediately so something shows before fonts settle
      render();
    } else {
      render();
    }
    window.addEventListener("resize", debounce(render, 250));
  }
  function debounce(fn, ms) {
    var t; return function () { clearTimeout(t); t = setTimeout(fn, ms); };
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
