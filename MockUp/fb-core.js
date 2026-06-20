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
          { "quantity": 500, "unit": "g",   "name": "farine tout usage", "nutritionRef": { "foodCode": "F-2587", "matchedName": "Farine de blé, tout usage", "confidence": 0.92, "includeInCalc": true } },
          { "quantity": 200, "unit": "g",   "name": "sucre", "nutritionRef": { "foodCode": "F-1903", "matchedName": "Sucre blanc, granulé", "confidence": 0.88, "includeInCalc": true } },
          { "quantity": 2,   "unit": "tsp", "name": "poudre à pâte", "nutritionRef": { "foodCode": "F-0780", "matchedName": "Poudre à pâte", "confidence": 0.81, "includeInCalc": true } },
          { "quantity": 0.5, "unit": "tsp", "name": "sel", "nutritionRef": { "foodCode": "F-0500", "matchedName": "Sel de table", "confidence": 0.86, "includeInCalc": false } },
          { "quantity": 2,   "unit": null,  "name": "oeufs", "note": "gros, à température pièce", "nutritionRef": { "foodCode": "F-0123", "matchedName": "Œuf, entier, cru", "confidence": 0.74, "includeInCalc": true } },
          { "quantity": 250, "unit": "ml",  "name": "lait", "nutritionRef": { "foodCode": "F-0011", "matchedName": "Lait, 2 % M.G.", "confidence": 0.83, "includeInCalc": true } },
          { "quantity": 60,  "unit": "g",   "name": "beurre", "note": "fondu", "nutritionRef": { "foodCode": "F-0142", "matchedName": "Beurre, salé", "confidence": 0.9, "includeInCalc": true } },
          { "quantity": 1.5, "unit": "l",   "name": "huile végétale", "note": "pour la friture", "nutritionRef": { "foodCode": "F-0451", "matchedName": "Huile végétale", "confidence": 0.88, "includeInCalc": false } }
        ],
        "steps": [
          { "text": "Mélanger les ingrédients secs : farine, sucre, poudre à pâte et sel.", "image": null, "timerSeconds": null },
          { "text": "Dans un autre bol, battre les oeufs avec le lait et le beurre fondu.", "image": null, "timerSeconds": null },
          { "text": "Combiner le tout sans trop mélanger, puis laisser reposer la pâte.", "image": "beignes-frits-pate.jpg", "timerSeconds": 900 },
          { "text": "Chauffer l'huile à {{temp:180:c}}. Façonner les beignes et les frire jusqu'à ce qu'ils soient dorés.", "image": null, "timerSeconds": 180 },
          { "text": "Égoutter sur un papier absorbant et glacer au goût.", "image": null, "timerSeconds": null }
        ],
        "personal": { "notes": "La pâte gagne à reposer 20 min plutôt que 15. Ne pas surcharger la friteuse.", "rating": 5, "lastCooked": "2026-02-03T00:00:00Z", "madeCount": 4 },
        "nutrition": {
          "perServing": { "calories": 240, "fat": 9, "satFat": 3.5, "transFat": 0, "carbs": 36, "fiber": 1, "sugars": 16, "protein": 4, "cholesterol": 35, "sodium": 180, "potassium": 70, "calcium": 60, "iron": 1.6 },
          "total": { "calories": 2880, "fat": 108, "satFat": 42, "transFat": 0, "carbs": 432, "fiber": 12, "sugars": 192, "protein": 48, "cholesterol": 420, "sodium": 2160, "potassium": 840, "calcium": 720, "iron": 19.2 },
          "isEstimate": true, "hasUnmatched": true, "computedAt": "2026-02-03T14:10:00Z", "servingsBasis": 12
        }
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
        "personal": { "notes": "~38 g de protéines par portion. Excellent avec un peu de yogourt grec sur le dessus.", "rating": 5, "lastCooked": "2026-05-18T00:00:00Z", "madeCount": 6 },
        "nutrition": {
          "perServing": { "calories": 330, "fat": 11, "satFat": 4, "transFat": 0.3, "carbs": 24, "fiber": 8, "sugars": 6, "protein": 32, "cholesterol": 75, "sodium": 520, "potassium": 900, "calcium": 90, "iron": 5 },
          "total": { "calories": 1980, "fat": 66, "satFat": 24, "transFat": 1.8, "carbs": 144, "fiber": 48, "sugars": 36, "protein": 192, "cholesterol": 450, "sodium": 3120, "potassium": 5400, "calcium": 540, "iron": 30 },
          "isEstimate": true, "hasUnmatched": false, "computedAt": "2026-04-11T18:20:00Z", "servingsBasis": 6
        }
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
      version: "Facebouffe — version 1.1.0", recipes_saved: "recettes enregistrées",
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
      // Phase 1.5 — books (save/load), import engine, nutrition
      book_group: "Mon livre", save_book: "Sauvegarder les recettes", load_book: "Charger des recettes",
      save_book_sub: "Copie de sauvegarde (JSON)", load_book_sub: "Fusionner un fichier (JSON)",
      book_saved: "Livre sauvegardé", book_loaded: "Chargé",
      import_group: "Importation", import_backend: "Moteur d'import",
      import_tier0: "Règles seules", import_ondevice: "Sur l'appareil", import_byok: "Votre clé API",
      import_tier0_sub: "Lit les pages web structurées · gratuit, hors ligne.",
      import_ondevice_sub: "OCR + petit modèle local · gratuit, privé.",
      import_byok_sub: "Meilleure qualité · facturé à votre compte.",
      import_key_label: "Clé API", import_key_ph: "collez votre clé…", import_key_saved: "Clé enregistrée",
      import_privacy: "Les niveaux 0–1 restent sur l'appareil. Avec votre clé, le contenu de la recette (et les images) est envoyé au fournisseur, sous votre compte.",
      import_share_note: "Partager vers Facebouffe : envoyez un lien ou une photo depuis une autre app — vous arrivez sur le même écran de révision.",
      add_method_title: "Ajouter une recette",
      method_manual: "Manuellement", method_manual_sub: "Page blanche",
      method_link: "À partir d'un lien", method_link_sub: "Coller l'URL d'une recette",
      method_photo: "À partir d'une photo", method_photo_sub: "Numériser une recette",
      method_text: "À partir de texte", method_text_sub: "Coller le texte d'une recette",
      import_run: "Importer", import_link_ph: "https://…",
      import_text_ph: "Collez le texte de la recette ici…",
      import_photo_drop: "Déposez une photo ou touchez pour choisir",
      import_use_sample: "Utiliser un exemple", import_paste_sample: "Coller un exemple",
      import_reading_web: "Lecture de la page (Niveau 0)…",
      import_ondevice_run: "Modèle sur l'appareil…", import_byok_run: "Modèle infonuagique…",
      import_done_draft: "Brouillon prêt", import_need_key: "Ajoutez d'abord votre clé API dans les Réglages.",
      import_review_banner: "Brouillon importé — vérifiez et ajustez avant d'enregistrer.",
      import_via_link: "Importé d'un lien", import_via_photo: "Importé d'une photo", import_via_text: "Importé d'un texte",
      nutrition_section: "Valeur nutritive", nutrition_estimate: "Estimation",
      nutrition_gen: "Générer l'étiquette nutritionnelle", nutrition_regen: "Recalculer l'étiquette",
      nutrition_view: "Voir la valeur nutritive", nutrition_hide: "Masquer",
      nutrition_per_serving: "par portion", nutrition_amount_total: "Recette entière",
      nutrition_disclaimer: "Estimation calculée à partir des ingrédients. Ce n'est pas un tableau réglementaire de valeur nutritive.",
      nutrition_unmatched: "Des ingrédients sont exclus ou non appariés — l'estimation est approximative.",
      nutrition_intro: "Apparie chaque ingrédient à un aliment du Fichier canadien sur les éléments nutritifs, puis estime la valeur nutritive.",
      match_title: "Appariement des ingrédients", match_include: "Inclure", match_excluded: "Exclu",
      match_unmatched: "Non apparié", match_check: "À vérifier",
      match_correct: "Corriger l'appariement", match_search: "Rechercher un aliment (FCÉN)",
      match_set_default: "Définir par défaut pour cet ingrédient", match_default_done: "Défini par défaut",
      cnf_label: "FCÉN", per_100: "/ 100 g",
      aliases_title: "Aliases d'ingrédients",
      aliases_empty: "Aucun alias appris. Corrigez un appariement et touchez « Définir par défaut ».",
      aliases_hint: "Appariements appris : nom d'ingrédient → aliment préféré.",
      default_import_engine: "Moteur d'import par défaut",
      ondevice_unsupported: "Non pris en charge sur cet appareil (nécessite l'IA sur appareil : Apple Foundation Models ou Android Gemini Nano).",
      byok_disabled: "Ajoutez une clé API ci-dessous pour activer cette option.",
      api_keys: "Clés API", provider: "Fournisseur",
      test_key: "Tester la clé", delete_key: "Supprimer la clé",
      key_testing: "Test en cours…", key_valid: "Clé valide", key_invalid: "Clé invalide",
      key_empty: "Entrez une clé d'abord", key_none: "Aucune clé enregistrée", key_saved_prov: "Clé enregistrée",
      tw_ondevice: "IA sur appareil",
      advanced: "Paramètres avancés", advanced_sub: "Tags, alias, importation, clés API",
      coach_tags: "Créez, renommez ou supprimez vos propres catégories. Supprimer un tag le retire des recettes, sans les effacer.",
      coach_aliases: "Quand vous corrigez l'appariement d'un ingrédient, votre choix est mémorisé ici comme défaut pour la prochaine fois.",
      coach_import_engine: "Choisissez le moteur utilisé par défaut pour importer une recette : règles, IA sur appareil, ou votre propre clé API.",
      coach_apikeys: "Ajoutez la clé d'un fournisseur (Claude, Gemini, ChatGPT) pour activer l'import infonuagique. Vous pouvez la tester ou la supprimer.",
      // Phase 2 — social layer
      social_friends: "Amis", social_hub_sub: "Partagez et découvrez des recettes",
      signin: "Se connecter", account: "Compte", signout: "Se déconnecter",
      signin_intro: "La connexion est optionnelle — elle active le partage entre amis et la synchro multi-appareils.",
      signin_local_note: "Sans compte, l'appli fonctionne entièrement hors ligne. Vos recettes restent sur l'appareil.",
      email_label: "Courriel", email_ph: "vous@exemple.ca",
      send_magic: "Envoyer le lien magique", magic_sent_title: "Vérifiez vos courriels",
      magic_sent_sub: "Nous avons envoyé un lien de connexion à", magic_open: "J'ai ouvert le lien (démo)",
      magic_resend: "Renvoyer", magic_change_email: "Changer de courriel",
      offline_note: "Hors ligne — reconnectez-vous pour utiliser le social.",
      choose_username: "Choisissez votre nom d'utilisateur",
      username_intro: "C'est ainsi que vos amis vous trouvent. Il est unique et permanent.",
      username_permanent: "Ce nom est permanent", username_available: "disponible",
      username_taken: "déjà pris", username_invalid: "3–20 caractères : lettres minuscules, chiffres, _",
      username_checking: "Vérification…", continue_btn: "Continuer",
      account_sync: "Synchronisation", sync_synced: "Synchronisé", sync_syncing: "Synchronisation…",
      sync_offline: "Hors ligne", sync_ago: "il y a 2 min",
      signout_note: "Le partage et la synchro se mettent en pause, mais votre livre reste sur l'appareil.",
      signout_confirm: "Se déconnecter ?", cancel: "Annuler",
      add_friend: "Ajouter un ami", add_friend_ph: "nom d'utilisateur", send_request: "Envoyer",
      requests_in: "Demandes reçues", requests_out: "Demandes envoyées", friends_list: "Amis",
      accept: "Accepter", decline: "Refuser", pending: "En attente",
      friends_empty: "Aucun ami pour l'instant. Ajoutez quelqu'un par son nom d'utilisateur.",
      request_sent: "Demande envoyée à", user_not_found: "Nom d'utilisateur introuvable",
      already_friend: "Déjà dans vos amis", remove_friend: "Retirer", block_user: "Bloquer",
      friend_cookbook: "Carnet de", visiting_band: "Carnet de", shared_recipes: "recettes partagées",
      cookbook_empty: "n'a encore rien partagé.", cookbook_offline: "Reconnectez-vous pour voir le carnet de",
      steal_recipe: "Voler cette recette", already_stolen: "Déjà dans votre carnet",
      steal_added: "Ajouté à votre carnet", view_recipe: "Voir la recette",
      reviews: "Avis", your_review: "Votre avis", add_review: "Laisser un avis",
      review_ph: "Écrivez un mot sur cette recette…", save_review: "Publier", edit_review: "Modifier",
      no_reviews: "Aucun avis pour l'instant.", moderate_delete: "Supprimer (modération)",
      visibility: "Visibilité", vis_private: "Privé", vis_friends: "Partagé avec mes amis",
      shared_badge: "Partagé", from_owner: "de", locked_readonly: "Recette liée · lecture seule",
      update_available: "Mise à jour disponible", refresh: "Actualiser", up_to_date: "À jour",
      make_variant: "Créer une variante", unlink_source: "Détacher de la source",
      unlinked_notice: "Cette recette a été détachée — vous pouvez maintenant la modifier.",
      source_deleted: "L'auteur a retiré cette recette — elle a été détachée et vous appartient.",
      steal_preview_title: "Voler cette recette", steal_bundles: "entraîne aussi",
      steal_n_linked: "recettes liées", steal_all: "Tout ajouter", steal_already: "déjà présent",
      migration_title: "Recettes locales", migration_body: "recettes sur cet appareil ne sont pas dans votre compte. Les ajouter ?",
      migration_add: "Ajouter", migration_later: "Plus tard", migration_synced: "Recettes synchronisées",
      coach_firstfriend: "Touchez un ami pour parcourir son carnet et voler ses recettes.",
      coach_share: "Activez le partage pour qu'un ami puisse voir et voler cette recette.",
      coach_stolen: "Recette liée : modifiez-la en créant une variante ou en la détachant. Vos notes privées restent éditables.",
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
      version: "Facebouffe — version 1.1.0", recipes_saved: "recipes saved",
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
      // Phase 1.5 — books (save/load), import engine, nutrition
      book_group: "My book", save_book: "Save recipes", load_book: "Load recipes",
      save_book_sub: "Backup copy (JSON)", load_book_sub: "Merge a file (JSON)",
      book_saved: "Book saved", book_loaded: "Loaded",
      import_group: "Import", import_backend: "Import engine",
      import_tier0: "Rules only", import_ondevice: "On-device", import_byok: "Your API key",
      import_tier0_sub: "Reads structured web pages · free, offline.",
      import_ondevice_sub: "On-device OCR + small model · free, private.",
      import_byok_sub: "Best quality · billed to your account.",
      import_key_label: "API key", import_key_ph: "paste your key…", import_key_saved: "Key saved",
      import_privacy: "Tiers 0–1 stay on-device. With your key, recipe content (and images) is sent to the provider, under your account.",
      import_share_note: "Share to Facebouffe: send a link or photo from another app — you land on the same review screen.",
      add_method_title: "Add a recipe",
      method_manual: "Manually", method_manual_sub: "Blank page",
      method_link: "From a link", method_link_sub: "Paste a recipe URL",
      method_photo: "From a photo", method_photo_sub: "Scan a recipe",
      method_text: "From text", method_text_sub: "Paste recipe text",
      import_run: "Import", import_link_ph: "https://…",
      import_text_ph: "Paste the recipe text here…",
      import_photo_drop: "Drop a photo or tap to choose",
      import_use_sample: "Use a sample", import_paste_sample: "Paste a sample",
      import_reading_web: "Reading page (Tier 0)…",
      import_ondevice_run: "On-device model…", import_byok_run: "Cloud model…",
      import_done_draft: "Draft ready", import_need_key: "Add your API key in Settings first.",
      import_review_banner: "Imported draft — review and adjust before saving.",
      import_via_link: "Imported from a link", import_via_photo: "Imported from a photo", import_via_text: "Imported from text",
      nutrition_section: "Nutrition", nutrition_estimate: "Estimate",
      nutrition_gen: "Generate nutrition label", nutrition_regen: "Recalculate label",
      nutrition_view: "View nutrition", nutrition_hide: "Hide",
      nutrition_per_serving: "per serving", nutrition_amount_total: "Whole recipe",
      nutrition_disclaimer: "Estimated from the ingredients. This is not a regulatory Nutrition Facts table.",
      nutrition_unmatched: "Some ingredients are excluded or unmatched — the estimate is approximate.",
      nutrition_intro: "Matches each ingredient to a food in the Canadian Nutrient File, then estimates nutrition.",
      match_title: "Ingredient matching", match_include: "Include", match_excluded: "Excluded",
      match_unmatched: "Unmatched", match_check: "Check this",
      match_correct: "Correct match", match_search: "Search a food (CNF)",
      match_set_default: "Set as default for this ingredient", match_default_done: "Set as default",
      cnf_label: "CNF", per_100: "/ 100 g",
      aliases_title: "Ingredient aliases",
      aliases_empty: "No learned aliases yet. Correct a match and tap “Set as default”.",
      aliases_hint: "Learned matches: ingredient name → preferred food.",
      default_import_engine: "Default import engine",
      ondevice_unsupported: "Not supported on this device (requires on-device AI: Apple Foundation Models or Android Gemini Nano).",
      byok_disabled: "Add an API key below to enable this option.",
      api_keys: "API keys", provider: "Provider",
      test_key: "Test key", delete_key: "Delete key",
      key_testing: "Testing…", key_valid: "Key valid", key_invalid: "Key invalid",
      key_empty: "Enter a key first", key_none: "No key saved", key_saved_prov: "Key saved",
      tw_ondevice: "On-device AI",
      advanced: "Advanced settings", advanced_sub: "Tags, aliases, import, API keys",
      coach_tags: "Create, rename or delete your own categories. Deleting a tag removes it from recipes without deleting them.",
      coach_aliases: "When you correct an ingredient's match, your choice is remembered here as the default next time.",
      coach_import_engine: "Pick the engine used by default to import a recipe: rules, on-device AI, or your own API key.",
      coach_apikeys: "Add a provider key (Claude, Gemini, ChatGPT) to enable cloud import. You can test or delete it.",
      // Phase 2 — social layer
      social_friends: "Friends", social_hub_sub: "Share and discover recipes",
      signin: "Sign in", account: "Account", signout: "Sign out",
      signin_intro: "Signing in is optional — it unlocks sharing with friends and multi-device sync.",
      signin_local_note: "Without an account the app works fully offline. Your recipes stay on the device.",
      email_label: "Email", email_ph: "you@example.com",
      send_magic: "Send magic link", magic_sent_title: "Check your email",
      magic_sent_sub: "We sent a sign-in link to", magic_open: "I opened the link (demo)",
      magic_resend: "Resend", magic_change_email: "Change email",
      offline_note: "Offline — reconnect to use social features.",
      choose_username: "Choose your username",
      username_intro: "This is how friends find you. It's unique and permanent.",
      username_permanent: "This name is permanent", username_available: "available",
      username_taken: "already taken", username_invalid: "3–20 chars: lowercase letters, digits, _",
      username_checking: "Checking…", continue_btn: "Continue",
      account_sync: "Sync", sync_synced: "Synced", sync_syncing: "Syncing…",
      sync_offline: "Offline", sync_ago: "2 min ago",
      signout_note: "Sharing and sync pause, but your book stays on the device.",
      signout_confirm: "Sign out?", cancel: "Cancel",
      add_friend: "Add a friend", add_friend_ph: "username", send_request: "Send",
      requests_in: "Requests received", requests_out: "Requests sent", friends_list: "Friends",
      accept: "Accept", decline: "Decline", pending: "Pending",
      friends_empty: "No friends yet. Add someone by their username.",
      request_sent: "Request sent to", user_not_found: "Username not found",
      already_friend: "Already a friend", remove_friend: "Remove", block_user: "Block",
      friend_cookbook: "Cookbook of", visiting_band: "Cookbook of", shared_recipes: "shared recipes",
      cookbook_empty: "hasn't shared anything yet.", cookbook_offline: "Reconnect to see the cookbook of",
      steal_recipe: "Steal this recipe", already_stolen: "Already in your book",
      steal_added: "Added to your book", view_recipe: "View recipe",
      reviews: "Reviews", your_review: "Your review", add_review: "Leave a review",
      review_ph: "Write a note about this recipe…", save_review: "Post", edit_review: "Edit",
      no_reviews: "No reviews yet.", moderate_delete: "Delete (moderation)",
      visibility: "Visibility", vis_private: "Private", vis_friends: "Shared with friends",
      shared_badge: "Shared", from_owner: "from", locked_readonly: "Linked recipe · read-only",
      update_available: "Update available", refresh: "Refresh", up_to_date: "Up to date",
      make_variant: "Create a variant", unlink_source: "Unlink from source",
      unlinked_notice: "This recipe has been unlinked — you can now edit it.",
      source_deleted: "The author removed this recipe — it's been unlinked and is now yours.",
      steal_preview_title: "Steal this recipe", steal_bundles: "also brings in",
      steal_n_linked: "linked recipes", steal_all: "Add all", steal_already: "already in book",
      migration_title: "Local recipes", migration_body: "recipes on this device aren't in your account. Add them?",
      migration_add: "Add", migration_later: "Later", migration_synced: "Recipes synced",
      coach_firstfriend: "Tap a friend to browse their cookbook and steal their recipes.",
      coach_share: "Turn on sharing so a friend can see and steal this recipe.",
      coach_stolen: "Linked recipe: edit it by creating a variant or unlinking. Your private notes stay editable.",
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

  // ──────────────────────────────────────────────────────────
  // Phase 1.5 — Nutrition (estimate). The label values are GENERATED
  // (deterministic, plausible) and intentionally NOT computed from the CNF;
  // the CNF list below only powers the ingredient-match picker UI.
  // ──────────────────────────────────────────────────────────
  const CNF_FOODS = [
    { code: "F-2587", fr: "Farine de blé, tout usage", en: "Wheat flour, all-purpose", kcal: 364 },
    { code: "F-1903", fr: "Sucre blanc, granulé", en: "Sugar, white, granulated", kcal: 387 },
    { code: "F-1904", fr: "Cassonade", en: "Brown sugar", kcal: 380 },
    { code: "F-0902", fr: "Sucre à glacer", en: "Icing sugar", kcal: 389 },
    { code: "F-0142", fr: "Beurre, salé", en: "Butter, salted", kcal: 717 },
    { code: "F-0143", fr: "Beurre, non salé", en: "Butter, unsalted", kcal: 717 },
    { code: "F-0011", fr: "Lait, 2 % M.G.", en: "Milk, 2% fat", kcal: 50 },
    { code: "F-0014", fr: "Crème à cuisson 35 %", en: "Cream, 35% (cooking)", kcal: 340 },
    { code: "F-0123", fr: "Œuf, entier, cru", en: "Egg, whole, raw", kcal: 143 },
    { code: "F-0905", fr: "Vanille, extrait", en: "Vanilla extract", kcal: 288 },
    { code: "F-2588", fr: "Pâte à tarte, abaisse", en: "Pie crust, shell", kcal: 480 },
    { code: "F-0451", fr: "Huile végétale", en: "Vegetable oil", kcal: 884 },
    { code: "F-0500", fr: "Sel de table", en: "Salt, table", kcal: 0 },
    { code: "F-0780", fr: "Poudre à pâte", en: "Baking powder", kcal: 53 },
    { code: "F-0901", fr: "Sirop d'érable", en: "Maple syrup", kcal: 260 },
    { code: "F-2001", fr: "Bœuf haché, maigre", en: "Beef, ground, lean", kcal: 176 },
    { code: "F-2002", fr: "Bœuf haché, mi-maigre", en: "Beef, ground, medium", kcal: 254 },
    { code: "F-3001", fr: "Oignon, cru", en: "Onion, raw", kcal: 40 },
    { code: "F-3002", fr: "Ail, cru", en: "Garlic, raw", kcal: 149 },
    { code: "F-3003", fr: "Carotte, crue", en: "Carrot, raw", kcal: 41 },
    { code: "F-3100", fr: "Tomates, en conserve, en dés", en: "Tomatoes, canned, diced", kcal: 32 },
    { code: "F-3200", fr: "Haricots rouges, en conserve", en: "Kidney beans, canned", kcal: 127 },
    { code: "F-3201", fr: "Haricots noirs, en conserve", en: "Black beans, canned", kcal: 132 },
    { code: "F-4001", fr: "Pois jaunes, secs", en: "Split peas, yellow, dry", kcal: 352 },
    { code: "F-4100", fr: "Jambon, cuit", en: "Ham, cooked", kcal: 145 },
    { code: "F-5001", fr: "Laitue romaine", en: "Lettuce, romaine", kcal: 17 },
    { code: "F-5002", fr: "Parmesan, râpé", en: "Parmesan, grated", kcal: 431 },
    { code: "F-5003", fr: "Huile d'olive", en: "Olive oil", kcal: 884 },
    { code: "F-5004", fr: "Anchois, en conserve", en: "Anchovy, canned", kcal: 210 },
    { code: "F-5005", fr: "Pain, blanc", en: "Bread, white", kcal: 266 },
    { code: "F-6001", fr: "Poudre de chili", en: "Chili powder", kcal: 282 },
    { code: "F-6002", fr: "Cumin, moulu", en: "Cumin, ground", kcal: 375 },
    { code: "F-6003", fr: "Sarriette, séchée", en: "Savory, dried", kcal: 272 },
  ];
  const CNF_BY_CODE = Object.fromEntries(CNF_FOODS.map((f) => [f.code, f]));
  function cnfName(food, lang) {
    if (typeof food === "string") food = CNF_BY_CODE[food];
    return food ? (lang === "en" ? food.en : food.fr) : "";
  }
  function normalizeName(name) { return String(name || "").toLowerCase().trim().replace(/\s+/g, " "); }
  // Fold for fuzzy matching: lowercase, strip diacritics, normalize ligatures.
  function foldStr(s) {
    return String(s || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\u0153/g, "oe").replace(/\u00e6/g, "ae");
  }

  // Crude fuzzy match: token overlap against bilingual names. Returns
  // { food, confidence } or null.
  function cnfMatch(name) {
    const n = foldStr(normalizeName(name));
    if (!n) return null;
    const toks = n.split(/[\s,]+/).filter((w) => w.length > 2);
    let best = null, bestScore = 0;
    for (const f of CNF_FOODS) {
      const hay = foldStr(f.fr + " " + f.en);
      let score = 0;
      toks.forEach((w) => { if (hay.includes(w)) score += w.length; });
      if (score > bestScore) { bestScore = score; best = f; }
    }
    if (!best) return null;
    return { food: best, confidence: Math.min(0.98, 0.4 + bestScore / 16) };
  }

  // Default include-in-calc: false for things you don't actually eat —
  // frying oil, "sel au goût", pinch items.
  function defaultExcluded(ing) {
    const n = normalizeName(ing.name);
    const note = normalizeName(ing.note);
    if (ing.unit === "pinch") return true;
    if (/\bsel\b|\bsalt\b/.test(n)) return true;
    if (/(huile|oil)/.test(n) && (ing.unit === "l" || (ing.unit === "ml" && (ing.quantity || 0) >= 500) || /(friture|frying)/.test(n + " " + note))) return true;
    return false;
  }

  // Resolve a per-ingredient match, honoring the learned alias table first.
  function resolveMatch(ing, aliases) {
    const key = normalizeName(ing.name);
    const alias = aliases && aliases[key];
    if (alias && CNF_BY_CODE[alias.foodCode]) {
      return { foodCode: alias.foodCode, matchedName: cnfName(alias.foodCode, "fr"), confidence: 1, includeInCalc: !defaultExcluded(ing), fromAlias: true };
    }
    const m = cnfMatch(ing.name);
    if (!m) return { foodCode: null, matchedName: null, confidence: 0, includeInCalc: !defaultExcluded(ing) };
    return { foodCode: m.food.code, matchedName: m.food.fr, confidence: Math.round(m.confidence * 100) / 100, includeInCalc: !defaultExcluded(ing) };
  }

  // Deterministic plausible nutrition (NOT from CNF) — stable per recipe id.
  function mockNutrition(recipe, opts) {
    opts = opts || {};
    const servings = opts.servings || recipe.servings || 1;
    const id = recipe.id || recipe.title || "x";
    const inc = opts.includedCount == null ? 6 : opts.includedCount;
    const r = (salt, lo, hi) => { const h = hashStr(id + ":" + salt + ":" + inc); return lo + (h % 1000) / 1000 * (hi - lo); };
    const per = {
      calories: Math.round(r("cal", 170, 520) / 5) * 5,
      fat: Math.round(r("fat", 4, 26)),
      satFat: Math.round(r("sat", 1, 9) * 10) / 10,
      transFat: Math.round(r("trans", 0, 0.6) * 10) / 10,
      carbs: Math.round(r("carb", 14, 48)),
      fiber: Math.round(r("fiber", 1, 10)),
      sugars: Math.round(r("sug", 2, 22)),
      protein: Math.round(r("pro", 3, 34)),
      cholesterol: Math.round(r("chol", 5, 95) / 5) * 5,
      sodium: Math.round(r("sod", 60, 620) / 10) * 10,
      potassium: Math.round(r("pot", 60, 950) / 10) * 10,
      calcium: Math.round(r("cal2", 20, 220) / 5) * 5,
      iron: Math.round(r("iron", 0.4, 6) * 10) / 10,
    };
    const total = {};
    Object.keys(per).forEach((k) => { total[k] = Math.round(per[k] * servings * 10) / 10; });
    return { perServing: per, total, isEstimate: true, hasUnmatched: !!opts.hasUnmatched, computedAt: new Date().toISOString(), servingsBasis: servings };
  }

  // Daily Value reference amounts (Canada, 2016 regulations).
  const DV_REF = { fat: 75, satTrans: 20, sodium: 2300, fiber: 28, sugars: 100, potassium: 3400, calcium: 1300, iron: 18 };
  function dvPct(key, value) {
    const ref = DV_REF[key];
    if (!ref) return null;
    return Math.round((value / ref) * 100);
  }

  // ────────────────────────────────────────────────────────────
  // Phase 2 — Social layer mock data (friends, their cookbooks, reviews).
  // Friend recipes are full Recipe objects + ownerId + version, so they
  // render in the normal recipe page (visiting mode) and Sous-chef.
  // ────────────────────────────────────────────────────────────
  const _p = (notes) => ({ notes: notes || "", rating: 0, lastCooked: null, madeCount: 0 });
  const FRIEND_RECIPES = [
    {
      id: "fr-marie-tourtiere", ownerId: "u-marie", version: 3,
      title: "Tourtière du Lac-Saint-Jean", createdBy: "marie", source: "Recette de ma grand-mère",
      dateAdded: "2026-01-05T00:00:00Z", dateModified: "2026-05-20T00:00:00Z",
      heroImage: null, gallery: [], variantGroupId: null, links: [],
      description: "La vraie tourtière du Lac : un pâté profond de cubes de viande et de pommes de terre, mijoté des heures au four. Cuire à {{temp:160:c}} pendant 4 à 5 heures.",
      servings: 8, prepTimeMinutes: 60, cookTimeMinutes: 270, tags: ["tag-dinner"],
      ingredients: [
        { quantity: 1.5, unit: "kg", name: "cubes de porc et de bœuf", note: "moitié-moitié" },
        { quantity: 6, unit: null, name: "pommes de terre", note: "en cubes" },
        { quantity: 2, unit: null, name: "oignons", note: "hachés" },
        { quantity: 2, unit: null, name: "abaisses de pâte brisée", note: "" },
        { quantity: 500, unit: "ml", name: "bouillon de bœuf", note: "" },
      ],
      steps: [
        { text: "Couper la viande en petits cubes et mariner avec les oignons une nuit.", image: null, timerSeconds: null },
        { text: "Foncer un grand plat profond d'une abaisse, y déposer viande et pommes de terre.", image: null, timerSeconds: null },
        { text: "Couvrir de bouillon, sceller avec la seconde abaisse et cuire à {{temp:160:c}}.", image: null, timerSeconds: 16200 },
      ],
      personal: _p(""), nutrition: null,
    },
    {
      id: "fr-marie-galette", ownerId: "u-marie", version: 1,
      title: "Galette des Rois", createdBy: "marie", source: null,
      dateAdded: "2026-02-01T00:00:00Z", dateModified: "2026-02-01T00:00:00Z",
      heroImage: null, gallery: [], variantGroupId: null, links: ["fr-marie-creme"],
      description: "Feuilletage doré et frangipane. Servir avec un peu de {{link:fr-marie-creme}} pour les gourmands. Four à {{temp:200:c}}.",
      servings: 6, prepTimeMinutes: 30, cookTimeMinutes: 35, tags: ["tag-dessert"],
      ingredients: [
        { quantity: 2, unit: null, name: "pâtes feuilletées", note: "" },
        { quantity: 150, unit: "g", name: "poudre d'amandes", note: "" },
        { quantity: 100, unit: "g", name: "beurre mou", note: "" },
        { quantity: 100, unit: "g", name: "sucre", note: "" },
        { quantity: 2, unit: null, name: "œufs", note: "" },
      ],
      steps: [
        { text: "Crémer le beurre et le sucre, ajouter la poudre d'amandes et les œufs.", image: null, timerSeconds: null },
        { text: "Garnir une abaisse, couvrir de la seconde, sceller et dorer.", image: null, timerSeconds: null },
        { text: "Cuire à {{temp:200:c}} jusqu'à ce que ce soit gonflé et doré.", image: null, timerSeconds: 2100 },
      ],
      personal: _p(""), nutrition: null,
    },
    {
      id: "fr-marie-creme", ownerId: "u-marie", version: 1,
      title: "Crème pâtissière", createdBy: "marie", source: null,
      dateAdded: "2026-02-01T00:00:00Z", dateModified: "2026-02-01T00:00:00Z",
      heroImage: null, gallery: [], variantGroupId: null, links: [],
      description: "La base de tous les desserts garnis. Ne pas faire bouillir après l'ajout des jaunes.",
      servings: 4, prepTimeMinutes: 10, cookTimeMinutes: 10, tags: ["tag-dessert"],
      ingredients: [
        { quantity: 500, unit: "ml", name: "lait", note: "" },
        { quantity: 4, unit: null, name: "jaunes d'œufs", note: "" },
        { quantity: 80, unit: "g", name: "sucre", note: "" },
        { quantity: 40, unit: "g", name: "fécule de maïs", note: "" },
      ],
      steps: [
        { text: "Chauffer le lait. Blanchir les jaunes avec le sucre et la fécule.", image: null, timerSeconds: null },
        { text: "Verser le lait chaud, remettre sur feu doux et fouetter jusqu'à épaississement.", image: null, timerSeconds: 300 },
      ],
      personal: _p(""), nutrition: null,
    },
    {
      id: "fr-leo-poke", ownerId: "u-leo", version: 2,
      title: "Bol poké au saumon", createdBy: "leo", source: null,
      dateAdded: "2026-03-10T00:00:00Z", dateModified: "2026-05-25T00:00:00Z",
      heroImage: null, gallery: [], variantGroupId: null, links: [],
      description: "Mon lunch d'après-gym : riz, saumon cru mariné, edamames et avocat. Frais et plein de protéines.",
      servings: 2, prepTimeMinutes: 20, cookTimeMinutes: 15, tags: ["tag-dinner", "tag-hiprotein"],
      ingredients: [
        { quantity: 300, unit: "g", name: "saumon pour sushi", note: "très frais" },
        { quantity: 200, unit: "g", name: "riz à sushi", note: "" },
        { quantity: 1, unit: null, name: "avocat", note: "tranché" },
        { quantity: 100, unit: "g", name: "edamames", note: "écossés" },
        { quantity: 3, unit: "tbsp", name: "sauce soya", note: "" },
      ],
      steps: [
        { text: "Cuire le riz et le laisser tiédir.", image: null, timerSeconds: 720 },
        { text: "Couper le saumon en cubes et mariner dans la sauce soya 10 min.", image: null, timerSeconds: 600 },
        { text: "Monter les bols : riz, saumon, avocat, edamames.", image: null, timerSeconds: null },
      ],
      personal: _p(""), nutrition: null,
    },
    {
      id: "fr-leo-smoothie", ownerId: "u-leo", version: 1,
      title: "Smoothie protéiné cacao-banane", createdBy: "leo", source: null,
      dateAdded: "2026-04-02T00:00:00Z", dateModified: "2026-04-02T00:00:00Z",
      heroImage: null, gallery: [], variantGroupId: null, links: [],
      description: "30 g de protéines au déjeuner, prêt en deux minutes au mélangeur.",
      servings: 1, prepTimeMinutes: 3, cookTimeMinutes: 0, tags: ["tag-breakfast", "tag-hiprotein"],
      ingredients: [
        { quantity: 1, unit: null, name: "banane", note: "congelée" },
        { quantity: 1, unit: "scoop", name: "protéine de chocolat", note: "" },
        { quantity: 250, unit: "ml", name: "lait d'amande", note: "" },
        { quantity: 1, unit: "tbsp", name: "beurre d'arachide", note: "" },
      ],
      steps: [
        { text: "Mettre tous les ingrédients au mélangeur.", image: null, timerSeconds: null },
        { text: "Mélanger jusqu'à consistance lisse et servir aussitôt.", image: null, timerSeconds: null },
      ],
      personal: _p(""), nutrition: null,
    },
  ];

  const SOCIAL_SEED = {
    me: { email: "demo@exemple.ca" },
    friends: [
      { id: "u-marie", username: "marie", name: "Marie", color: "#C0563B" },
      { id: "u-leo", username: "leo", name: "Léo", color: "#6BA368" },
    ],
    requestsIn: [{ id: "u-sophie", username: "sophie", name: "Sophie", color: "#9C6B8E" }],
    requestsOut: [{ id: "u-ahmed", username: "ahmed", name: "Ahmed", color: "#4A7BA6" }],
    directory: [
      { id: "u-juliette", username: "juliette", name: "Juliette", color: "#C58A2E" },
      { id: "u-marco", username: "marco", name: "Marco", color: "#4A7BA6" },
    ],
    friendRecipes: FRIEND_RECIPES,
    comments: {
      "fr-marie-tourtiere": [
        { id: "c1", authorId: "u-leo", authorName: "Léo", authorColor: "#6BA368", stars: 5, text: "La meilleure que j'ai goûtée. J'ai mis un peu plus de poivre.", date: "2026-05-22T00:00:00Z" },
        { id: "c2", authorId: "u-sophie", authorName: "Sophie", authorColor: "#9C6B8E", stars: 4, text: "Longue à cuire mais ça vaut le coup !", date: "2026-05-23T00:00:00Z" },
      ],
      "fr-leo-poke": [
        { id: "c3", authorId: "u-marie", authorName: "Marie", authorColor: "#C0563B", stars: 5, text: "Parfait pour un lunch léger. Merci Léo.", date: "2026-05-26T00:00:00Z" },
      ],
      "rec-beignes-frits": [
        { id: "c4", authorId: "u-marie", authorName: "Marie", authorColor: "#C0563B", stars: 5, text: "Mes enfants en redemandent ! Recette adoptée.", date: "2026-05-10T00:00:00Z" },
        { id: "c5", authorId: "u-leo", authorName: "Léo", authorColor: "#6BA368", stars: 4, text: "Bien dodus. J'ai réduit le sucre de moitié.", date: "2026-05-12T00:00:00Z" },
      ],
    },
  };

  window.FB = {
    SEED, I18N, MONTHS, FALLBACK_PALETTE, SOCIAL_SEED,
    t, tagName, fallbackColor, hashStr,
    fmtQty, fmtQtyForUnit, unitLabel, convertIngredientUnit, displayIngredient, dimensionOf,
    fmtDuration, fmtTimer, fmtDate, fmtRelDate,
    prefTempUnit, fmtTemp, findTemps, tokenizeTemps, detokenizeTemps,
    uuid, totalTime,
    CNF_FOODS, CNF_BY_CODE, cnfName, normalizeName, cnfMatch, defaultExcluded, resolveMatch,
    mockNutrition, DV_REF, dvPct,
  };
})();
