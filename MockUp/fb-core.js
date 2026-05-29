/* fb-core.js — Facebouffe data, i18n strings, and utility functions.
   Plain JS; everything is attached to window for the React layer to use. */
(function () {
  'use strict';

  // ──────────────────────────────────────────────────────────
  // Seed database (from facebouffe-seed.json)
  // ──────────────────────────────────────────────────────────
  const SEED = {
    "schemaVersion": 1,
    "profile": {
      "username": "demo_chef",
      "language": "fr",
      "units": { "temperature": "celsius", "volume": "metric", "weight": "metric" },
      "fontSize": "medium"
    },
    "tags": [
      { "id": "tag-fav",       "system": true,  "special": "favorite", "name": { "fr": "Favoris",      "en": "Favorites" }, "icon": "star",     "color": "#F4B400" },
      { "id": "tag-breakfast", "system": true,  "name": { "fr": "Déjeuner",    "en": "Breakfast" }, "icon": "sunrise",  "color": "#F6A23C" },
      { "id": "tag-dinner",    "system": true,  "name": { "fr": "Souper",      "en": "Dinner" },    "icon": "utensils", "color": "#C0563B" },
      { "id": "tag-dessert",   "system": true,  "name": { "fr": "Dessert",     "en": "Dessert" },   "icon": "cake",     "color": "#D98AB0" },
      { "id": "tag-appetizer", "system": true,  "name": { "fr": "Entrée",      "en": "Appetizer" }, "icon": "shrimp",   "color": "#7FB069" },
      { "id": "tag-soup",      "system": true,  "name": { "fr": "Soupe",       "en": "Soup" },      "icon": "bowl",     "color": "#E0A458" },
      { "id": "tag-salad",     "system": true,  "name": { "fr": "Salade",      "en": "Salad" },     "icon": "leaf",     "color": "#6BA368" },
      { "id": "tag-hiprotein", "system": false, "name": { "fr": "Hi-protéine", "en": "Hi-protein" }, "icon": "dumbbell", "color": "#4A7BA6" }
    ],
    "variantGroups": [
      { "groupId": "vg-beignes", "memberIds": ["rec-beignes-frits", "rec-beignes-four"], "baseId": "rec-beignes-frits" }
    ],
    "recipes": [
      {
        "id": "rec-beignes-frits", "title": "Beignes traditionnels frits", "createdBy": "demo_chef",
        "dateAdded": "2026-01-12T09:30:00Z", "dateModified": "2026-02-03T14:10:00Z",
        "source": "Recette de grand-maman Thérèse", "heroImage": "beignes-frits.jpg",
        "gallery": ["beignes-frits.jpg", "beignes-frits-pate.jpg"],
        "description": "Le beigne de base, moelleux à l'intérieur et légèrement croustillant à l'extérieur. Cette pâte sert de fondation : nappez-la du glaçage de votre choix. Voir le {{link:rec-glacage-erable}} pour la version classique du temps des sucres.",
        "servings": 12, "prepTimeMinutes": 30, "cookTimeMinutes": 15,
        "tags": ["tag-dessert", "tag-fav"], "variantGroupId": "vg-beignes", "links": ["rec-glacage-erable"],
        "ingredients": [
          { "quantity": 500, "unit": "g",   "name": "farine tout usage" },
          { "quantity": 200, "unit": "g",   "name": "sucre" },
          { "quantity": 2,   "unit": "tsp", "name": "poudre à pâte" },
          { "quantity": 0.5, "unit": "tsp", "name": "sel" },
          { "quantity": 2,   "unit": null,  "name": "oeufs", "note": "gros, à température pièce" },
          { "quantity": 250, "unit": "ml",  "name": "lait" },
          { "quantity": 60,  "unit": "g",   "name": "beurre", "note": "fondu" },
          { "quantity": 1.5, "unit": "l",   "name": "huile végétale", "note": "pour la friture" }
        ],
        "steps": [
          { "text": "Mélanger les ingrédients secs : farine, sucre, poudre à pâte et sel.", "image": null, "timerSeconds": null },
          { "text": "Dans un autre bol, battre les oeufs avec le lait et le beurre fondu.", "image": null, "timerSeconds": null },
          { "text": "Combiner le tout sans trop mélanger, puis laisser reposer la pâte.", "image": "beignes-frits-pate.jpg", "timerSeconds": 900 },
          { "text": "Chauffer l'huile à {{temp:180:c}}. Façonner les beignes et les frire jusqu'à ce qu'ils soient dorés.", "image": null, "timerSeconds": 180 },
          { "text": "Égoutter sur un papier absorbant et glacer au goût.", "image": null, "timerSeconds": null }
        ],
        "personal": { "notes": "La pâte gagne à reposer 20 min plutôt que 15. Ne pas surcharger la friteuse.", "rating": 5, "lastCooked": "2026-02-03T00:00:00Z", "madeCount": 4 }
      },
      {
        "id": "rec-beignes-four", "title": "Beignes au four (plus légers)", "createdBy": "demo_chef",
        "dateAdded": "2026-02-05T11:00:00Z", "dateModified": "2026-02-05T11:00:00Z",
        "source": "Variante de la recette de grand-maman", "heroImage": null, "gallery": [],
        "description": "Une version cuite au four, sans friture — plus légère et plus rapide à nettoyer. Nécessite un moule à beignes. Même esprit que la {{link:rec-beignes-frits}}, mais moins de gras.",
        "servings": 12, "prepTimeMinutes": 20, "cookTimeMinutes": 12,
        "tags": ["tag-dessert"], "variantGroupId": "vg-beignes", "links": ["rec-beignes-frits"],
        "ingredients": [
          { "quantity": 500, "unit": "g",   "name": "farine tout usage" },
          { "quantity": 150, "unit": "g",   "name": "sucre" },
          { "quantity": 2,   "unit": "tsp", "name": "poudre à pâte" },
          { "quantity": 0.5, "unit": "tsp", "name": "sel" },
          { "quantity": 2,   "unit": null,  "name": "oeufs", "note": "gros" },
          { "quantity": 250, "unit": "ml",  "name": "lait" },
          { "quantity": 45,  "unit": "g",   "name": "beurre", "note": "fondu" }
        ],
        "steps": [
          { "text": "Préchauffer le four à {{temp:190:c}} et beurrer un moule à beignes.", "image": null, "timerSeconds": null },
          { "text": "Mélanger les secs, puis incorporer les liquides sans trop travailler la pâte.", "image": null, "timerSeconds": null },
          { "text": "Répartir la pâte dans le moule et cuire jusqu'à ce qu'un cure-dent ressorte propre.", "image": null, "timerSeconds": 720 },
          { "text": "Démouler, laisser tiédir et glacer.", "image": null, "timerSeconds": null }
        ],
        "personal": { "notes": "", "rating": 4, "lastCooked": null, "madeCount": 1 }
      },
      {
        "id": "rec-glacage-erable", "title": "Glaçage à l'érable", "createdBy": "demo_chef",
        "dateAdded": "2026-01-12T10:00:00Z", "dateModified": "2026-01-12T10:00:00Z",
        "source": null, "heroImage": null, "gallery": [],
        "description": "Un glaçage brillant au sirop d'érable, parfait pour napper les beignes. Se prépare en 5 minutes pendant que les beignes refroidissent.",
        "servings": 12, "prepTimeMinutes": 5, "cookTimeMinutes": 0,
        "tags": ["tag-dessert"], "variantGroupId": null, "links": [],
        "ingredients": [
          { "quantity": 250, "unit": "g",  "name": "sucre à glacer" },
          { "quantity": 60,  "unit": "ml", "name": "sirop d'érable", "note": "ambré de préférence" },
          { "quantity": 15,  "unit": "ml", "name": "lait", "note": "ajuster pour la consistance" }
        ],
        "steps": [
          { "text": "Fouetter tous les ingrédients jusqu'à consistance lisse et nappante.", "image": null, "timerSeconds": null },
          { "text": "Tremper le dessus des beignes tièdes et laisser figer.", "image": null, "timerSeconds": 600 }
        ],
        "personal": { "notes": "", "rating": 0, "lastCooked": null, "madeCount": 0 }
      },
      {
        "id": "rec-crepes", "title": "Crêpes du dimanche", "createdBy": "demo_chef",
        "dateAdded": "2026-01-20T08:15:00Z", "dateModified": "2026-01-20T08:15:00Z",
        "source": null, "heroImage": "crepes.jpg", "gallery": ["crepes.jpg"],
        "description": "Des crêpes fines et souples, prêtes en un tournemain. Le repos de la pâte fait toute la différence.",
        "servings": 4, "prepTimeMinutes": 10, "cookTimeMinutes": 20,
        "tags": ["tag-breakfast", "tag-fav"], "variantGroupId": null, "links": [],
        "ingredients": [
          { "quantity": 250, "unit": "g",  "name": "farine tout usage" },
          { "quantity": 3,   "unit": null, "name": "oeufs" },
          { "quantity": 500, "unit": "ml", "name": "lait" },
          { "quantity": 30,  "unit": "g",  "name": "beurre", "note": "fondu" },
          { "quantity": 1,   "unit": "pinch", "name": "sel" }
        ],
        "steps": [
          { "text": "Fouetter la farine, les oeufs et le sel, puis détendre avec le lait.", "image": null, "timerSeconds": null },
          { "text": "Incorporer le beurre fondu et laisser reposer la pâte.", "image": null, "timerSeconds": 1800 },
          { "text": "Cuire chaque crêpe dans une poêle chaude légèrement beurrée.", "image": null, "timerSeconds": 90 }
        ],
        "personal": { "notes": "Doubler la recette : elles partent vite.", "rating": 5, "lastCooked": "2026-05-24T00:00:00Z", "madeCount": 9 }
      },
      {
        "id": "rec-soupe-pois", "title": "Soupe aux pois jaunes", "createdBy": "demo_chef",
        "dateAdded": "2026-01-08T17:40:00Z", "dateModified": "2026-01-08T17:40:00Z",
        "source": "Classique québécois", "heroImage": null, "gallery": [],
        "description": "La soupe réconfortante par excellence. Longue à mijoter, mais presque sans effort. Encore meilleure le lendemain.",
        "servings": 8, "prepTimeMinutes": 15, "cookTimeMinutes": 150,
        "tags": ["tag-soup", "tag-dinner"], "variantGroupId": null, "links": [],
        "ingredients": [
          { "quantity": 450, "unit": "g",  "name": "pois jaunes secs", "note": "rincés" },
          { "quantity": 1,   "unit": null, "name": "oignon", "note": "haché" },
          { "quantity": 2,   "unit": null, "name": "carottes", "note": "en dés" },
          { "quantity": 200, "unit": "g",  "name": "jambon", "note": "en cubes" },
          { "quantity": 2,   "unit": "l",  "name": "eau" },
          { "quantity": 1,   "unit": "tsp", "name": "sarriette" },
          { "quantity": 1,   "unit": "tsp", "name": "sel" }
        ],
        "steps": [
          { "text": "Faire revenir l'oignon dans une grande casserole.", "image": null, "timerSeconds": null },
          { "text": "Ajouter tous les autres ingrédients et porter à ébullition.", "image": null, "timerSeconds": null },
          { "text": "Réduire le feu et laisser mijoter à couvert, en remuant de temps en temps.", "image": null, "timerSeconds": 9000 },
          { "text": "Rectifier l'assaisonnement avant de servir.", "image": null, "timerSeconds": null }
        ],
        "personal": { "notes": "", "rating": 4, "lastCooked": null, "madeCount": 2 }
      },
      {
        "id": "rec-cesar", "title": "Salade César maison", "createdBy": "demo_chef",
        "dateAdded": "2026-03-02T19:00:00Z", "dateModified": "2026-03-02T19:00:00Z",
        "source": null, "heroImage": null, "gallery": [],
        "description": "Une César avec une vraie vinaigrette maison, sans compromis. Croûtons à l'ail faits maison.",
        "servings": 4, "prepTimeMinutes": 20, "cookTimeMinutes": 10,
        "tags": ["tag-salad", "tag-appetizer"], "variantGroupId": null, "links": [],
        "ingredients": [
          { "quantity": 1,  "unit": null, "name": "laitue romaine", "note": "grosse" },
          { "quantity": 2,  "unit": null, "name": "gousses d'ail" },
          { "quantity": 1,  "unit": null, "name": "jaune d'oeuf" },
          { "quantity": 60, "unit": "ml", "name": "huile d'olive" },
          { "quantity": 30, "unit": "g",  "name": "parmesan", "note": "râpé" },
          { "quantity": 4,  "unit": null, "name": "filets d'anchois", "note": "optionnel" },
          { "quantity": 2,  "unit": "cup","name": "pain", "note": "en cubes, pour les croûtons" }
        ],
        "steps": [
          { "text": "Faire dorer les cubes de pain à l'ail au four.", "image": null, "timerSeconds": 600 },
          { "text": "Émulsionner le jaune d'oeuf, l'ail, les anchois et l'huile.", "image": null, "timerSeconds": null },
          { "text": "Mélanger la romaine avec la vinaigrette, le parmesan et les croûtons.", "image": null, "timerSeconds": null }
        ],
        "personal": { "notes": "", "rating": 0, "lastCooked": null, "madeCount": 0 }
      },
      {
        "id": "rec-chili-proteine", "title": "Chili hi-protéine", "createdBy": "demo_chef",
        "dateAdded": "2026-04-11T18:20:00Z", "dateModified": "2026-04-11T18:20:00Z",
        "source": null, "heroImage": "chili.jpg", "gallery": ["chili.jpg"],
        "description": "Un chili copieux et riche en protéines, idéal pour la préparation de repas (meal prep). Se congèle très bien.",
        "servings": 6, "prepTimeMinutes": 15, "cookTimeMinutes": 45,
        "tags": ["tag-dinner", "tag-hiprotein", "tag-fav"], "variantGroupId": null, "links": [],
        "ingredients": [
          { "quantity": 600, "unit": "g",  "name": "boeuf haché maigre" },
          { "quantity": 1,   "unit": null, "name": "oignon", "note": "haché" },
          { "quantity": 2,   "unit": null, "name": "gousses d'ail", "note": "émincées" },
          { "quantity": 800, "unit": "g",  "name": "tomates en dés", "note": "en conserve" },
          { "quantity": 540, "unit": "ml", "name": "haricots rouges", "note": "rincés" },
          { "quantity": 540, "unit": "ml", "name": "haricots noirs", "note": "rincés" },
          { "quantity": 2,   "unit": "tbsp","name": "poudre de chili" },
          { "quantity": 1,   "unit": "tsp", "name": "cumin moulu" }
        ],
        "steps": [
          { "text": "Faire revenir l'oignon et l'ail, puis ajouter le boeuf et défaire à la cuillère.", "image": null, "timerSeconds": null },
          { "text": "Ajouter les épices et bien enrober la viande.", "image": null, "timerSeconds": null },
          { "text": "Verser les tomates et les haricots, puis laisser mijoter à découvert.", "image": null, "timerSeconds": 2400 },
          { "text": "Rectifier l'assaisonnement et servir.", "image": null, "timerSeconds": null }
        ],
        "personal": { "notes": "~38 g de protéines par portion. Excellent avec un peu de yogourt grec sur le dessus.", "rating": 5, "lastCooked": "2026-05-18T00:00:00Z", "madeCount": 6 }
      }
    ]
  };

  // ──────────────────────────────────────────────────────────
  // i18n — UI chrome only. Recipe content is never translated.
  // ──────────────────────────────────────────────────────────
  const I18N = {
    fr: {
      tab_home: "Accueil", tab_search: "Recherche", tab_list: "Épicerie", tab_settings: "Réglages",
      home_title: "Facebouffe", home_greeting: "Qu'est-ce qu'on cuisine\u00A0?",
      sec_favorites: "Favoris", sec_recent: "Cuisinés récemment", sec_all: "Toutes les recettes",
      sec_quick: "Vite faits", recipes_count: "recettes",
      servings: "portions", serving_one: "portion", prep: "Prép.", cook: "Cuisson", total: "Total",
      ingredients: "Ingrédients", steps: "Préparation", notes: "Mes notes", source: "Source",
      personal: "Mon journal", made_count: "Cuisiné", times: "fois", time_once: "fois",
      last_cooked: "Dernière fois", never_cooked: "Jamais cuisiné",
      add_to_list: "Ajouter à l'épicerie", added: "Ajouté\u00A0!", cook_mode: "Mode sous-chef",
      variants: "Variantes", see_also: "Voir aussi", edit: "Modifier", min: "min", hours: "h",
      add_variant: "Ajouter une variante", export_pdf: "Exporter en PDF", gallery: "Galerie",
      add_photo: "Ajouter une photo", change_photo: "Changer la photo",
      remove_photo: "Retirer la photo",
      got_it: "Compris", help_title: "Aide", help_section: "Aide & astuces",
      help_glossary: "Glossaire", help_howto: "Comment faire", replay_tips: "Revoir les astuces",
      tips_reset_done: "Astuces réinitialisées",
      coach_souschef: "Vue simplifiée pour cuisiner : ingrédients à cocher et étapes pas à pas, avec minuteries.",
      coach_variants: "Une variante est une autre version du même plat (frit / au four), gardée avec la recette.",
      coach_shopping: "Envoie les ingrédients, ajustés aux portions, vers votre liste d'épicerie.",
      coach_pdf: "Exporte cette recette en PDF. Depuis les Réglages, exportez tout un livre.",
      coach_chips: "Touchez une pastille pour basculer entre les versions du plat.",
      fav_empty: "Aucun favori pour l'instant. Touchez l'étoile ★ d'une recette pour l'épingler ici.",
      custom_tags: "Tags personnalisés", tag_exists: "Ce tag existe déjà", search_tag: "Rechercher ou créer un tag",
      no_user_tags: "Aucun tag personnalisé pour l'instant.", create_label: "Créer", add_tag: "Ajouter un tag",
      awake: "Écran allumé", timers_running: "Minuteries", scheduled_note: "Programmées comme notifications",
      ing_filter: "Ingrédients", presets: "Fréquents", create_tag: "Créer une catégorie",
      sec_infos: "Infos", validation_title: "Donnez un titre à la recette", validation_ing: "Ajoutez au moins un ingrédient",
      f_note: "Note", f_note_ph: "ex. fondu, optionnel", f_timer: "Minuteur (min)", insert_link: "Lier une recette",
      import_export: "Importer / Exporter", import_book: "Importer un livre (JSON)", export_json: "Exporter (JSON)",
      export_book_pdf: "Exporter en livre (PDF)", username_label: "Nom d'utilisateur", reorder: "Déplacer",
      search_placeholder: "Rechercher une recette", filter_all: "Tout", no_results: "Aucune recette trouvée",
      results: "résultats", result: "résultat", search_hint: "Cherchez par nom, ingrédient ou catégorie",
      list_title: "Liste d'épicerie", list_empty: "Votre liste est vide",
      list_empty_hint: "Ajoutez les ingrédients d'une recette depuis sa page, ou tapez-les ici.",
      add_item: "Ajouter un article", clear_checked: "Effacer les cochés", items: "articles", item: "article",
      to_buy: "À acheter", in_cart: "Dans le panier",
      settings_title: "Réglages", profile: "Profil", set_language: "Langue", set_units: "Unités",
      set_temp: "Température", set_volume: "Volume", set_weight: "Poids", set_textsize: "Taille du texte",
      metric: "Métrique", imperial: "Impérial", celsius: "Celsius", fahrenheit: "Fahrenheit",
      size_small: "Petit", size_medium: "Moyen", size_large: "Grand", about: "À propos",
      version: "Facebouffe — version 1.0", recipes_saved: "recettes enregistrées",
      sc_ingredients: "Ingrédients", sc_steps: "Étapes", sc_step: "Étape", sc_of: "sur",
      sc_done: "Terminé\u00A0!", sc_next: "Suivante", sc_prev: "Précédente", sc_finish: "Terminer",
      sc_swipe: "Glissez", sc_start_timer: "Démarrer le minuteur", sc_timer_done: "Minuteur terminé",
      sc_all_done: "Bon appétit\u00A0!", sc_all_done_sub: "Recette terminée.", sc_close: "Fermer",
      add_title: "Nouvelle recette", edit_title: "Modifier la recette", sec_photo: "Photo",
      f_title: "Titre", f_title_ph: "Nom de la recette", f_desc: "Description", f_desc_ph: "Décrivez le plat…",
      f_details: "Détails", f_servings: "Portions", f_prep: "Prép. (min)", f_cook: "Cuisson (min)",
      f_source: "Source", f_source_ph: "ex. Recette de grand-maman", f_tags: "Catégories",
      f_add_ing: "Ajouter un ingrédient", f_add_step: "Ajouter une étape", f_step: "Étape",
      f_qty: "Qté", f_unit: "Unité", f_ing_name: "Ingrédient", f_notes_ph: "Astuces, ajustements…",
      save: "Enregistrer", cancel: "Annuler", delete: "Supprimer", done: "OK",
      fav_add: "Ajouter aux favoris", fav_remove: "Retirer des favoris",
      unrated: "Non noté", base_variant: "Recette principale", scale_reset: "Rétablir",
    },
    en: {
      tab_home: "Home", tab_search: "Search", tab_list: "Groceries", tab_settings: "Settings",
      home_title: "Facebouffe", home_greeting: "What are we cooking?",
      sec_favorites: "Favorites", sec_recent: "Recently cooked", sec_all: "All recipes",
      sec_quick: "Quick fixes", recipes_count: "recipes",
      servings: "servings", serving_one: "serving", prep: "Prep", cook: "Cook", total: "Total",
      ingredients: "Ingredients", steps: "Method", notes: "My notes", source: "Source",
      personal: "My log", made_count: "Cooked", times: "times", time_once: "time",
      last_cooked: "Last cooked", never_cooked: "Never cooked",
      add_to_list: "Add to groceries", added: "Added!", cook_mode: "Sous-chef mode",
      variants: "Variants", see_also: "See also", edit: "Edit", min: "min", hours: "h",
      add_variant: "Add a variant", export_pdf: "Export to PDF", gallery: "Gallery",
      add_photo: "Add a photo", change_photo: "Change photo",
      remove_photo: "Remove photo",
      got_it: "Got it", help_title: "Help", help_section: "Help & tips",
      help_glossary: "Glossary", help_howto: "How-to", replay_tips: "Replay tips",
      tips_reset_done: "Tips reset",
      coach_souschef: "A stripped-down cooking view: a checklist of ingredients and step-by-step instructions with timers.",
      coach_variants: "A variant is another version of the same dish (fried / baked), kept alongside the recipe.",
      coach_shopping: "Sends the ingredients, scaled to your servings, to your shopping list.",
      coach_pdf: "Exports this recipe as a PDF. From Settings, you can export a whole book.",
      coach_chips: "Tap a chip to switch between versions of the dish.",
      fav_empty: "No favorites yet. Tap the ★ on any recipe to pin it here.",
      custom_tags: "Custom tags", tag_exists: "This tag already exists", search_tag: "Search or create a tag",
      no_user_tags: "No custom tags yet.", create_label: "Create", add_tag: "Add a tag",
      awake: "Screen on", timers_running: "Timers", scheduled_note: "Scheduled as notifications",
      ing_filter: "Ingredients", presets: "Common", create_tag: "Create a category",
      sec_infos: "Info", validation_title: "Give the recipe a title", validation_ing: "Add at least one ingredient",
      f_note: "Note", f_note_ph: "e.g. melted, optional", f_timer: "Timer (min)", insert_link: "Link a recipe",
      import_export: "Import / Export", import_book: "Import a book (JSON)", export_json: "Export (JSON)",
      export_book_pdf: "Export as book (PDF)", username_label: "Username", reorder: "Move",
      search_placeholder: "Search a recipe", filter_all: "All", no_results: "No recipes found",
      results: "results", result: "result", search_hint: "Search by name, ingredient or category",
      list_title: "Shopping list", list_empty: "Your list is empty",
      list_empty_hint: "Add a recipe's ingredients from its page, or type them here.",
      add_item: "Add an item", clear_checked: "Clear checked", items: "items", item: "item",
      to_buy: "To buy", in_cart: "In cart",
      settings_title: "Settings", profile: "Profile", set_language: "Language", set_units: "Units",
      set_temp: "Temperature", set_volume: "Volume", set_weight: "Weight", set_textsize: "Text size",
      metric: "Metric", imperial: "Imperial", celsius: "Celsius", fahrenheit: "Fahrenheit",
      size_small: "Small", size_medium: "Medium", size_large: "Large", about: "About",
      version: "Facebouffe — version 1.0", recipes_saved: "recipes saved",
      sc_ingredients: "Ingredients", sc_steps: "Steps", sc_step: "Step", sc_of: "of",
      sc_done: "Done!", sc_next: "Next", sc_prev: "Previous", sc_finish: "Finish",
      sc_swipe: "Swipe", sc_start_timer: "Start timer", sc_timer_done: "Timer done",
      sc_all_done: "Bon appétit!", sc_all_done_sub: "Recipe complete.", sc_close: "Close",
      add_title: "New recipe", edit_title: "Edit recipe", sec_photo: "Photo",
      f_title: "Title", f_title_ph: "Recipe name", f_desc: "Description", f_desc_ph: "Describe the dish…",
      f_details: "Details", f_servings: "Servings", f_prep: "Prep (min)", f_cook: "Cook (min)",
      f_source: "Source", f_source_ph: "e.g. Grandma's recipe", f_tags: "Categories",
      f_add_ing: "Add an ingredient", f_add_step: "Add a step", f_step: "Step",
      f_qty: "Qty", f_unit: "Unit", f_ing_name: "Ingredient", f_notes_ph: "Tips, tweaks…",
      save: "Save", cancel: "Cancel", delete: "Delete", done: "Done",
      fav_add: "Add to favorites", fav_remove: "Remove from favorites",
      unrated: "Unrated", base_variant: "Main recipe", scale_reset: "Reset",
    },
  };

  // Month names for friendly dates
  const MONTHS = {
    fr: ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juill.", "août", "sept.", "oct.", "nov.", "déc."],
    en: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
  };

  function t(lang, key) {
    return (I18N[lang] && I18N[lang][key]) || (I18N.fr[key]) || key;
  }

  function tagName(tag, lang) {
    if (!tag) return "";
    if (typeof tag.name === "string") return tag.name;
    return tag.name[lang] || tag.name.fr;
  }

  // ──────────────────────────────────────────────────────────
  // Fallback color — deterministic palette seeded by id/title.
  // Curated warm, muted cookbook tones that read as intentional.
  // ──────────────────────────────────────────────────────────
  const FALLBACK_PALETTE = [
    { bg: "#C0563B", ink: "#FFF3EC" }, // terracotta
    { bg: "#E0A458", ink: "#3A2A12" }, // ochre
    { bg: "#6BA368", ink: "#F2F8EE" }, // sage
    { bg: "#4A7BA6", ink: "#EAF2F8" }, // slate blue
    { bg: "#B8743F", ink: "#FFF1E4" }, // clay
    { bg: "#9C6B8E", ink: "#FBEEF6" }, // plum
    { bg: "#7E8B4E", ink: "#F6F8EC" }, // olive
    { bg: "#D08552", ink: "#FFF1E6" }, // apricot
    { bg: "#5B8C7E", ink: "#ECF6F2" }, // pine
    { bg: "#C58A2E", ink: "#FFF6E6" }, // mustard
  ];

  function hashStr(str) {
    let h = 0;
    str = String(str || "");
    for (let i = 0; i < str.length; i++) {
      h = (h << 5) - h + str.charCodeAt(i);
      h |= 0;
    }
    return Math.abs(h);
  }

  function fallbackColor(recipe) {
    const seed = (recipe && (recipe.id || recipe.title)) || "x";
    return FALLBACK_PALETTE[hashStr(seed) % FALLBACK_PALETTE.length];
  }

  // ──────────────────────────────────────────────────────────
  // Friendly fractions — display 0.75 as ¾, not "0.75".
  // ──────────────────────────────────────────────────────────
  const FRACTIONS = [
    [1 / 8, "⅛"], [1 / 4, "¼"], [1 / 3, "⅓"], [3 / 8, "⅜"], [1 / 2, "½"],
    [5 / 8, "⅝"], [2 / 3, "⅔"], [3 / 4, "¾"], [7 / 8, "⅞"],
  ];

  function fmtQty(n) {
    if (n == null || isNaN(n)) return "";
    if (n === 0) return "0";
    const sign = n < 0 ? "-" : "";
    n = Math.abs(n);
    const whole = Math.floor(n);
    const frac = n - whole;
    // snap to nearest known fraction within tolerance
    let best = null, bestErr = 0.04;
    for (const [val, glyph] of FRACTIONS) {
      const err = Math.abs(frac - val);
      if (err < bestErr) { best = glyph; bestErr = err; }
    }
    if (frac < 0.02) return sign + String(whole);
    if (best) return sign + (whole > 0 ? whole + " " + best : best);
    // otherwise: round to a tidy decimal
    let rounded = Math.round(n * 100) / 100;
    if (rounded >= 10) rounded = Math.round(n * 10) / 10;
    return sign + String(rounded).replace(".", lang_decimal());
  }
  // keep decimal separator simple (period) — French uses comma but recipe
  // quantities with a period read fine and avoid CSV-style confusion.
  function lang_decimal() { return "."; }

  // ──────────────────────────────────────────────────────────
  // Unit conversion — same-dimension only, driven by profile prefs.
  // ──────────────────────────────────────────────────────────
  const UNIT_LABEL = {
    fr: { g: "g", kg: "kg", ml: "ml", l: "l", tsp: "c. à thé", tbsp: "c. à soupe", cup: "tasse", oz: "oz", lb: "lb", pinch: "pincée", floz: "oz liq." },
    en: { g: "g", kg: "kg", ml: "ml", l: "l", tsp: "tsp", tbsp: "tbsp", cup: "cup", oz: "oz", lb: "lb", pinch: "pinch", floz: "fl oz" },
  };
  function unitLabel(unit, lang, qty) {
    if (!unit) return "";
    const l = (UNIT_LABEL[lang] && UNIT_LABEL[lang][unit]) || unit;
    // pluralize "tasse" / "cup"
    if (qty != null && qty > 1) {
      if (unit === "cup" && lang === "en") return "cups";
      if (unit === "cup" && lang === "fr") return "tasses";
      if (unit === "pinch" && lang === "en") return "pinches";
    }
    return l;
  }

  // grams base for weight, ml base for volume
  const TO_BASE = { g: 1, kg: 1000, ml: 1, l: 1000, tsp: 4.92892, tbsp: 14.7868, cup: 236.588, floz: 29.5735, oz: 28.3495, lb: 453.592 };
  const WEIGHT_UNITS = ["g", "kg", "oz", "lb"];
  const VOLUME_UNITS = ["ml", "l", "tsp", "tbsp", "cup", "floz"];
  // Universal small measures — never auto-converted across systems (tsp/tbsp
  // are used in both metric and imperial kitchens; pinch is symbolic).
  const SMALL_PASS = ["tsp", "tbsp", "pinch"];

  function dimensionOf(unit) {
    if (WEIGHT_UNITS.includes(unit)) return "weight";
    if (VOLUME_UNITS.includes(unit)) return "volume";
    return null;
  }

  // Convert a {quantity, unit} to the preferred system, returning {quantity, unit}.
  function convertIngredientUnit(qty, unit, prefs) {
    if (qty == null || !unit) return { quantity: qty, unit };
    if (SMALL_PASS.includes(unit)) return { quantity: qty, unit };
    const dim = dimensionOf(unit);
    if (!dim) return { quantity: qty, unit }; // countable
    const base = qty * TO_BASE[unit]; // in g or ml
    if (dim === "weight") {
      if (prefs.weight === "imperial") {
        if (base >= TO_BASE.lb * 0.9) return { quantity: base / TO_BASE.lb, unit: "lb" };
        return { quantity: base / TO_BASE.oz, unit: "oz" };
      }
      if (base >= 1000) return { quantity: base / 1000, unit: "kg" };
      return { quantity: base, unit: "g" };
    }
    // volume — convert only bulk units; cup stays cup unless metric requested
    if (prefs.volume === "imperial") {
      if (base >= TO_BASE.cup * 0.95) return { quantity: base / TO_BASE.cup, unit: "cup" };
      return { quantity: base / TO_BASE.floz, unit: "floz" };
    }
    if (base >= 1000) return { quantity: base / 1000, unit: "l" };
    return { quantity: base, unit: "ml" };
  }

  // Quantity formatting that respects the unit: metric bulk units read as
  // whole/tidy numbers; cups/spoons/counts use friendly fractions.
  function fmtQtyForUnit(qty, unit) {
    if (qty == null || isNaN(qty)) return "";
    if (unit === "g" || unit === "ml") {
      if (qty >= 20) return String(Math.round(qty));
      return fmtQty(Math.round(qty * 10) / 10);
    }
    if (unit === "kg" || unit === "l") {
      return String(Math.round(qty * 100) / 100);
    }
    return fmtQty(qty);
  }

  // Full pipeline: scale by servings ratio, convert units, format.
  function displayIngredient(ing, ratio, prefs, lang) {
    let qty = ing.quantity == null ? null : ing.quantity * ratio;
    let unit = ing.unit;
    if (qty != null && unit && prefs && (prefs.volume || prefs.weight)) {
      const conv = convertIngredientUnit(qty, unit, prefs);
      qty = conv.quantity; unit = conv.unit;
    }
    return {
      qtyText: fmtQtyForUnit(qty, unit),
      unitText: unitLabel(unit, lang, qty),
      name: ing.name,
      note: ing.note || null,
    };
  }

  // ──────────────────────────────────────────────────────────
  // Time formatting
  // ──────────────────────────────────────────────────────────
  function fmtDuration(min, lang) {
    if (min == null) return "—";
    if (min < 60) return min + " " + t(lang, "min");
    const h = Math.floor(min / 60);
    const m = min % 60;
    return m === 0 ? h + " " + t(lang, "hours") : h + " " + t(lang, "hours") + " " + (m < 10 ? "0" : "") + m;
  }

  function fmtTimer(sec) {
    if (sec == null) return "";
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return m + ":" + (s < 10 ? "0" : "") + s;
  }

  function fmtDate(iso, lang) {
    if (!iso) return null;
    const d = new Date(iso);
    if (isNaN(d)) return null;
    const m = MONTHS[lang][d.getUTCMonth()];
    return lang === "fr" ? `${d.getUTCDate()} ${m} ${d.getUTCFullYear()}` : `${m} ${d.getUTCDate()}, ${d.getUTCFullYear()}`;
  }

  // Relative-ish friendly date for "last cooked"
  function fmtRelDate(iso, lang) {
    if (!iso) return t(lang, "never_cooked");
    const d = new Date(iso);
    const now = new Date("2026-05-28T00:00:00Z");
    const days = Math.round((now - d) / 86400000);
    if (days <= 0) return lang === "fr" ? "aujourd'hui" : "today";
    if (days === 1) return lang === "fr" ? "hier" : "yesterday";
    if (days < 7) return lang === "fr" ? `il y a ${days} jours` : `${days} days ago`;
    if (days < 14) return lang === "fr" ? "la semaine dernière" : "last week";
    if (days < 60) return lang === "fr" ? `il y a ${Math.round(days / 7)} semaines` : `${Math.round(days / 7)} weeks ago`;
    return fmtDate(iso, lang);
  }

  // ──────────────────────────────────────────────────────────
  // Temperatures — inline {{temp:value:unit}} tokens in free text.
  // Stored as authored value+unit; converted only at display time.
  // ──────────────────────────────────────────────────────────
  function prefTempUnit(prefs) {
    return prefs && prefs.temperature === "fahrenheit" ? "f" : "c";
  }
  // Display a temperature value/unit in the preferred unit.
  function fmtTemp(value, unit, prefUnit) {
    const v = Number(value);
    unit = String(unit || "c").toLowerCase();
    if (isNaN(v)) return "";
    if (unit === prefUnit) {
      const n = Math.abs(v % 1) < 0.01 ? Math.round(v) : v;
      return n + " °" + unit.toUpperCase();
    }
    let conv = unit === "c" ? v * 9 / 5 + 32 : (v - 32) * 5 / 9;
    conv = Math.round(conv / 5) * 5; // nearest 5° in target unit (intentional)
    return conv + " °" + prefUnit.toUpperCase();
  }
  // Detection regex: a number immediately followed by an explicit C/F marker.
  const TEMP_RE = /(\d+(?:[.,]\d+)?)\s*(?:°\s*([cCfF])|([℃℉]))/g;
  function _unitFrom(letter, glyph) {
    if (glyph === "℃") return "c";
    if (glyph === "℉") return "f";
    return String(letter || "").toLowerCase();
  }
  // Find temperatures in free text (no mutation) → [{value, unit}].
  function findTemps(text) {
    const out = [];
    String(text || "").replace(TEMP_RE, (m, num, letter, glyph) => {
      out.push({ value: Number(String(num).replace(",", ".")), unit: _unitFrom(letter, glyph) });
      return m;
    });
    return out;
  }
  // Replace literal "180 °C" markers with {{temp:180:c}} tokens (capture step).
  function tokenizeTemps(text) {
    return String(text || "").replace(TEMP_RE, (m, num, letter, glyph) =>
      "{{temp:" + String(num).replace(",", ".") + ":" + _unitFrom(letter, glyph) + "}}");
  }
  // Replace {{temp:v:u}} tokens with friendly "v °U" text (for the editor).
  function detokenizeTemps(text) {
    return String(text || "").replace(/\{\{temp:([0-9.]+):([cfCF])\}\}/g, (m, v, u) => v + " °" + u.toUpperCase());
  }

  // ──────────────────────────────────────────────────────────
  // Misc helpers
  // ──────────────────────────────────────────────────────────
  function uuid() {
    return "id-" + Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
  }

  function totalTime(r) {
    return (r.prepTimeMinutes || 0) + (r.cookTimeMinutes || 0);
  }

  window.FB = {
    SEED, I18N, MONTHS, FALLBACK_PALETTE,
    t, tagName, fallbackColor, hashStr,
    fmtQty, fmtQtyForUnit, unitLabel, convertIngredientUnit, displayIngredient, dimensionOf,
    fmtDuration, fmtTimer, fmtDate, fmtRelDate,
    prefTempUnit, fmtTemp, findTemps, tokenizeTemps, detokenizeTemps,
    uuid, totalTime,
  };
})();
