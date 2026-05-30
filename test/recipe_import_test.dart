import 'package:flutter_test/flutter_test.dart';
import 'package:facebouffe/services/recipe_import.dart';

// A trimmed-down, Ricardo-shaped schema.org/Recipe JSON-LD page.
const _html = '''
<html><head>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "WebPage", "name": "ignore me"},
    {
      "@type": "Recipe",
      "name": "Financiers au sucre d'érable",
      "author": {"@type": "Organization", "name": "Ricardo"},
      "url": "https://www.ricardocuisine.com/recettes/5615-financiers",
      "description": "Petits gâteaux moelleux.",
      "recipeYield": "12 financiers",
      "prepTime": "PT15M",
      "cookTime": "PT1H10M",
      "image": ["https://images.ricardocuisine.com/financiers.jpg"],
      "recipeCategory": "Desserts",
      "keywords": "érable, Sans noix",
      "recipeIngredient": [
        "180 ml (3/4 tasse) de beurre non salé",
        "1 ½ tasse de sucre d'érable",
        "115 g de farine",
        "4 blancs d'oeufs"
      ],
      "recipeInstructions": [
        {"@type": "HowToStep", "text": "Préchauffer le four à 180 °C (350 °F)."},
        {"@type": "HowToStep", "text": "Cuire de 10 à 12 minutes."}
      ]
    }
  ]
}
</script>
</head><body></body></html>
''';

void main() {
  test('parses a Ricardo-shaped JSON-LD recipe', () {
    final res = RecipeImport.parseHtml('https://www.ricardocuisine.com/recettes/5615', _html);
    final r = res.recipe;
    expect(r.title, 'Financiers au sucre d\'érable');
    expect(r.createdBy, 'Ricardo');
    expect(r.source, contains('ricardocuisine.com'));
    expect(r.servings, 12);
    expect(r.prepTimeMinutes, 15);
    expect(r.cookTimeMinutes, 70);
    expect(r.tags, contains('tag-dessert'));
    expect(res.heroImageUrl, 'https://images.ricardocuisine.com/financiers.jpg');

    // ingredient parsing
    expect(r.ingredients.length, 4);
    expect(r.ingredients[0].quantity, 180);
    expect(r.ingredients[0].unit, 'ml');
    expect(r.ingredients[0].name, contains('beurre'));
    expect(r.ingredients[1].quantity, 1.5);
    expect(r.ingredients[1].unit, 'cup');
    expect(r.ingredients[2].quantity, 115);
    expect(r.ingredients[2].unit, 'g');
    expect(r.ingredients[3].quantity, 4);
    expect(r.ingredients[3].unit, isNull); // countable

    // temperature tokenization (Celsius preferred from dual form)
    expect(r.steps.first.text, contains('{{temp:180:c}}'));
    expect(r.steps.first.text, isNot(contains('350')));

    // 'Sans noix' surfaced as a suggested user tag
    expect(res.suggestedTags, contains('Sans noix'));
  });

  test('isSupported matches ricardocuisine.com only', () {
    expect(RecipeImport.isSupported('https://www.ricardocuisine.com/recettes/123'), isTrue);
    expect(RecipeImport.isSupported('https://ricardocuisine.com/x'), isTrue);
    expect(RecipeImport.isSupported('https://www.example.com/recipe'), isFalse);
  });
}
