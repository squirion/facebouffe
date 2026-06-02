// Facebouffe data model — mirrors the Global Schema in the design brief and
// the shape of facebouffe-seed.json. All structures round-trip to/from JSON so
// import/export and local persistence share one serialization path.

/// Phase 1.5 — per-ingredient resolved CNF match, persisted on the recipe.
class NutritionRef {
  String? foodCode; // CNF food code
  String? matchedName; // e.g. "Beurre, salé"
  double confidence; // 0–1 matcher certainty
  bool includeInCalc; // false = excluded (frying oil, "sel au goût"…)
  bool fromAlias; // matched via the learned alias table (UI hint; persisted harmlessly)

  NutritionRef({this.foodCode, this.matchedName, this.confidence = 0, this.includeInCalc = true, this.fromAlias = false});

  bool get matched => foodCode != null && foodCode!.isNotEmpty;

  factory NutritionRef.fromJson(Map<String, dynamic> j) => NutritionRef(
        foodCode: j['foodCode'] as String?,
        matchedName: j['matchedName'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        includeInCalc: j['includeInCalc'] as bool? ?? true,
        fromAlias: j['fromAlias'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'foodCode': foodCode,
        'matchedName': matchedName,
        'confidence': confidence,
        'includeInCalc': includeInCalc,
        if (fromAlias) 'fromAlias': true,
      };

  NutritionRef copy() => NutritionRef(foodCode: foodCode, matchedName: matchedName, confidence: confidence, includeInCalc: includeInCalc, fromAlias: fromAlias);
}

class Ingredient {
  num? quantity; // null = uncounted / handled via unit
  String? unit; // g,kg,ml,l,tsp,tbsp,cup,oz,lb,pinch... null = countable
  String name;
  String? note;
  String? group; // optional section heading (e.g. "Pâte"); null/empty = ungrouped
  NutritionRef? nutritionRef; // Phase 1.5 CNF match

  Ingredient({this.quantity, this.unit, required this.name, this.note, this.group, this.nutritionRef});

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        quantity: j['quantity'] as num?,
        unit: j['unit'] as String?,
        name: j['name'] as String? ?? '',
        note: j['note'] as String?,
        group: j['group'] as String?,
        nutritionRef: j['nutritionRef'] != null ? NutritionRef.fromJson(j['nutritionRef'] as Map<String, dynamic>) : null,
      );

  Map<String, dynamic> toJson() => {
        'quantity': quantity,
        'unit': unit,
        'name': name,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (group != null && group!.isNotEmpty) 'group': group,
        if (nutritionRef != null) 'nutritionRef': nutritionRef!.toJson(),
      };

  Ingredient copy() => Ingredient(quantity: quantity, unit: unit, name: name, note: note, group: group, nutritionRef: nutritionRef?.copy());
}

/// Phase 1.5 — computed nutrition label, stored on the recipe. Always an estimate.
class Nutrition {
  Map<String, num> perServing;
  Map<String, num> total;
  bool isEstimate;
  bool hasUnmatched;
  String computedAt; // ISO
  int servingsBasis;

  Nutrition({required this.perServing, required this.total, this.isEstimate = true, this.hasUnmatched = false, this.computedAt = '', this.servingsBasis = 1});

  static Map<String, num> _numMap(dynamic v) {
    final out = <String, num>{};
    if (v is Map) {
      v.forEach((k, val) {
        if (val is num) out[k.toString()] = val;
      });
    }
    return out;
  }

  factory Nutrition.fromJson(Map<String, dynamic> j) => Nutrition(
        perServing: _numMap(j['perServing']),
        total: _numMap(j['total']),
        isEstimate: j['isEstimate'] as bool? ?? true,
        hasUnmatched: j['hasUnmatched'] as bool? ?? false,
        computedAt: j['computedAt'] as String? ?? '',
        servingsBasis: (j['servingsBasis'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'perServing': perServing,
        'total': total,
        'isEstimate': isEstimate,
        'hasUnmatched': hasUnmatched,
        'computedAt': computedAt,
        'servingsBasis': servingsBasis,
      };

  Nutrition copy() => Nutrition.fromJson(toJson());
}

class Step {
  String text;
  String? image; // shown on recipe page step list only; hidden in Sous-chef
  int? timerSeconds;
  String? group; // optional section heading (e.g. "Glaçage"); null/empty = ungrouped

  Step({required this.text, this.image, this.timerSeconds, this.group});

  factory Step.fromJson(Map<String, dynamic> j) => Step(
        text: j['text'] as String? ?? '',
        image: j['image'] as String?,
        timerSeconds: (j['timerSeconds'] as num?)?.toInt(),
        group: j['group'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'image': image,
        'timerSeconds': timerSeconds,
        if (group != null && group!.isNotEmpty) 'group': group,
      };

  Step copy() => Step(text: text, image: image, timerSeconds: timerSeconds, group: group);
}

/// A contiguous run of list items sharing the same group label. Lets the UI and
/// export render group headers over the flat ingredient/step lists without
/// changing them. [name] null/empty means an ungrouped run (no header drawn).
class GroupSection<T> {
  final String? name;
  final List<T> items;
  final List<int> indices; // original positions in the source list
  GroupSection(this.name, this.items, this.indices);

  bool get hasHeader => name != null && name!.trim().isNotEmpty;
}

/// Split [items] into contiguous sections by [groupOf]; order is preserved and a
/// new section starts whenever the trimmed group label changes. Group names are
/// trimmed; null/blank collapse to a single ungrouped run.
List<GroupSection<T>> groupedSections<T>(List<T> items, String? Function(T) groupOf) {
  final out = <GroupSection<T>>[];
  String? curKey;
  for (var i = 0; i < items.length; i++) {
    final raw = groupOf(items[i]);
    final key = (raw == null || raw.trim().isEmpty) ? null : raw.trim();
    if (out.isEmpty || key != curKey) {
      out.add(GroupSection<T>(key, [items[i]], [i]));
      curKey = key;
    } else {
      out.last.items.add(items[i]);
      out.last.indices.add(i);
    }
  }
  return out;
}

class Personal {
  String notes;
  int rating; // 0–5; 0 = unrated
  String? lastCooked; // ISO
  int madeCount;

  Personal({this.notes = '', this.rating = 0, this.lastCooked, this.madeCount = 0});

  factory Personal.fromJson(Map<String, dynamic> j) => Personal(
        notes: j['notes'] as String? ?? '',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        lastCooked: j['lastCooked'] as String?,
        madeCount: (j['madeCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'notes': notes,
        'rating': rating,
        'lastCooked': lastCooked,
        'madeCount': madeCount,
      };

  Personal copy() => Personal(notes: notes, rating: rating, lastCooked: lastCooked, madeCount: madeCount);
}

class Recipe {
  String id;
  String title;
  String createdBy;
  String dateAdded;
  String dateModified;
  String? source;
  String? heroImage; // null => fallback palette color
  List<String> gallery;
  String description; // may contain {{link:id}} and {{temp:v:u}} tokens
  int servings;
  int prepTimeMinutes;
  int cookTimeMinutes;
  List<String> tags; // includes "tag-fav" when favorited
  String? variantGroupId;
  List<String> links;
  List<Ingredient> ingredients;
  List<Step> steps;
  Personal personal;
  Nutrition? nutrition; // Phase 1.5 — computed estimate, null until generated

  Recipe({
    required this.id,
    required this.title,
    this.createdBy = '',
    this.dateAdded = '',
    this.dateModified = '',
    this.source,
    this.heroImage,
    List<String>? gallery,
    this.description = '',
    this.servings = 4,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    List<String>? tags,
    this.variantGroupId,
    List<String>? links,
    List<Ingredient>? ingredients,
    List<Step>? steps,
    Personal? personal,
    this.nutrition,
  })  : gallery = gallery ?? [],
        tags = tags ?? [],
        links = links ?? [],
        ingredients = ingredients ?? [],
        steps = steps ?? [],
        personal = personal ?? Personal();

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        createdBy: j['createdBy'] as String? ?? '',
        dateAdded: j['dateAdded'] as String? ?? '',
        dateModified: j['dateModified'] as String? ?? '',
        source: j['source'] as String?,
        heroImage: j['heroImage'] as String?,
        gallery: (j['gallery'] as List?)?.map((e) => e as String).toList() ?? [],
        description: j['description'] as String? ?? '',
        servings: (j['servings'] as num?)?.toInt() ?? 4,
        prepTimeMinutes: (j['prepTimeMinutes'] as num?)?.toInt() ?? 0,
        cookTimeMinutes: (j['cookTimeMinutes'] as num?)?.toInt() ?? 0,
        tags: (j['tags'] as List?)?.map((e) => e as String).toList() ?? [],
        variantGroupId: j['variantGroupId'] as String?,
        links: (j['links'] as List?)?.map((e) => e as String).toList() ?? [],
        ingredients: (j['ingredients'] as List?)?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        steps: (j['steps'] as List?)?.map((e) => Step.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        personal: j['personal'] != null ? Personal.fromJson(j['personal'] as Map<String, dynamic>) : Personal(),
        nutrition: j['nutrition'] != null ? Nutrition.fromJson(j['nutrition'] as Map<String, dynamic>) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdBy': createdBy,
        'dateAdded': dateAdded,
        'dateModified': dateModified,
        'source': source,
        'heroImage': heroImage,
        'gallery': gallery,
        'description': description,
        'servings': servings,
        'prepTimeMinutes': prepTimeMinutes,
        'cookTimeMinutes': cookTimeMinutes,
        'tags': tags,
        'variantGroupId': variantGroupId,
        'links': links,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'personal': personal.toJson(),
        if (nutrition != null) 'nutrition': nutrition!.toJson(),
      };

  Recipe deepCopy() => Recipe.fromJson(toJson());

  bool get isFav => tags.contains('tag-fav');
  int get totalTime => prepTimeMinutes + cookTimeMinutes;
}

class Tag {
  String id;
  bool system;
  String? special; // "favorite" only on the favorites tag
  dynamic name; // {fr,en} map for system tags; String for user tags
  String icon;
  String color; // hex

  Tag({required this.id, this.system = false, this.special, required this.name, required this.icon, required this.color});

  factory Tag.fromJson(Map<String, dynamic> j) => Tag(
        id: j['id'] as String,
        system: j['system'] as bool? ?? false,
        special: j['special'] as String?,
        name: j['name'],
        icon: j['icon'] as String? ?? 'utensils',
        color: j['color'] as String? ?? '#C0563B',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'system': system,
        if (special != null) 'special': special,
        'name': name,
        'icon': icon,
        'color': color,
      };

  bool get isFavorite => special == 'favorite';

  String displayName(String lang) {
    final n = name;
    if (n is String) return n;
    if (n is Map) return (n[lang] ?? n['fr'] ?? '').toString();
    return '';
  }

  /// All names a tag can be matched against (case-insensitive duplicate checks).
  List<String> get allNames {
    final n = name;
    if (n is String) return [n];
    if (n is Map) return n.values.map((e) => e.toString()).toList();
    return [];
  }
}

class VariantGroup {
  String groupId;
  List<String> memberIds;
  String baseId;

  VariantGroup({required this.groupId, required this.memberIds, required this.baseId});

  factory VariantGroup.fromJson(Map<String, dynamic> j) => VariantGroup(
        groupId: j['groupId'] as String,
        memberIds: (j['memberIds'] as List).map((e) => e as String).toList(),
        baseId: j['baseId'] as String,
      );

  Map<String, dynamic> toJson() => {'groupId': groupId, 'memberIds': memberIds, 'baseId': baseId};
}

class Profile {
  String username;
  String language; // "fr" | "en"
  String temperature; // celsius | fahrenheit
  String volume; // metric | imperial
  String weight; // metric | imperial
  String fontSize; // small | medium | large

  Profile({
    this.username = 'demo_chef',
    this.language = 'fr',
    this.temperature = 'celsius',
    this.volume = 'metric',
    this.weight = 'metric',
    this.fontSize = 'medium',
  });

  factory Profile.fromJson(Map<String, dynamic> j) {
    final units = (j['units'] as Map<String, dynamic>?) ?? {};
    return Profile(
      username: j['username'] as String? ?? 'demo_chef',
      language: j['language'] as String? ?? 'fr',
      temperature: units['temperature'] as String? ?? 'celsius',
      volume: units['volume'] as String? ?? 'metric',
      weight: units['weight'] as String? ?? 'metric',
      fontSize: j['fontSize'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'language': language,
        'units': {'temperature': temperature, 'volume': volume, 'weight': weight},
        'fontSize': fontSize,
      };
}

class ShoppingItem {
  String id;
  String name;
  num? quantity;
  String? unit;
  bool checked;
  String? sourceRecipeId; // null = manually added

  ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.checked = false,
    this.sourceRecipeId,
  });
}

class TipsSeen {
  bool sousChef, variants, shoppingAdd, pdfExport, variantChips, cookStack;
  TipsSeen({this.sousChef = false, this.variants = false, this.shoppingAdd = false, this.pdfExport = false, this.variantChips = false, this.cookStack = false});

  bool seen(String key) => toMap()[key] ?? false;

  Map<String, bool> toMap() => {
        'sousChef': sousChef,
        'variants': variants,
        'shoppingAdd': shoppingAdd,
        'pdfExport': pdfExport,
        'variantChips': variantChips,
        'cookStack': cookStack,
      };

  factory TipsSeen.fromMap(Map<String, dynamic> m) => TipsSeen(
        sousChef: m['sousChef'] == true,
        variants: m['variants'] == true,
        shoppingAdd: m['shoppingAdd'] == true,
        pdfExport: m['pdfExport'] == true,
        variantChips: m['variantChips'] == true,
        cookStack: m['cookStack'] == true,
      );
}
