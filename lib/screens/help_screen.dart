import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/chrome.dart';
import '../widgets/fb_icon.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final fb = context.fb;
    final lang = app.lang;

    final glossary = lang == 'fr'
        ? const [
            ['Mode sous-chef', 'Vue de cuisson simplifiée : ingrédients à cocher et étapes en grand, avec minuteries. L\'écran reste allumé.'],
            ['Variante', 'Une autre version du même plat (ex. beignes frits vs au four). Les variantes sont regroupées ; basculez entre elles avec les pastilles en haut de la recette.'],
            ['Catégorie (tag)', 'Étiquette colorée (Déjeuner, Dessert, Soupe…) pour classer et filtrer vos recettes. Vous pouvez créer les vôtres.'],
            ['Lien de recette', 'Dans une description, un mot peut renvoyer à une autre recette. Touchez-le pour y aller.'],
          ]
        : const [
            ['Sous-chef mode', 'A simplified cooking view: a checklist of ingredients and large step-by-step instructions with timers. The screen stays awake.'],
            ['Variant', 'Another version of the same dish (e.g. fried vs baked donuts). Variants are grouped; switch between them with the chips at the top of a recipe.'],
            ['Category (tag)', 'A colored label (Breakfast, Dessert, Soup…) to organize and filter your recipes. You can create your own.'],
            ['Recipe link', 'Inside a description, a word can point to another recipe. Tap it to jump there.'],
          ];
    final howtos = lang == 'fr'
        ? const [
            ['flame', 'Cuisiner pas à pas', 'Ouvrez une recette puis touchez Mode sous-chef.'],
            ['basket', 'Composer l\'épicerie', 'Sur une recette, touchez Ajouter à l\'épicerie ; les quantités suivent les portions.'],
            ['plus', 'Créer une variante', 'Sur une recette, touchez Ajouter une variante pour partir d\'une copie.'],
            ['sliders', 'Unités, langue, thème', 'Tout se règle dans les Réglages.'],
          ]
        : const [
            ['flame', 'Cook step-by-step', 'Open a recipe, then tap Sous-chef mode.'],
            ['basket', 'Build your groceries', 'On a recipe, tap Add to groceries; amounts follow the servings.'],
            ['plus', 'Create a variant', 'On a recipe, tap Add a variant to start from a copy.'],
            ['sliders', 'Units, language, theme', 'Everything is set in Settings.'],
          ];

    return Scaffold(
      backgroundColor: fb.canvas,
      body: Column(
        children: [
          FbHeader(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 14),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: SizedBox(width: 40, height: 40, child: Center(child: FbIcon('back', size: fb.fs(22), color: fb.ink)))),
                const SizedBox(width: 4),
                Text(app.t('help_title'), style: fb.display(size: 25, weight: FontWeight.w600)),
              ]),
            ),
          ),
          Expanded(
            child: ScreenScroll(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                _card(fb, app.t('help_howto'), [
                  for (int i = 0; i < howtos.length; i++)
                    _row(fb, last: i == howtos.length - 1, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 32, height: 32, decoration: BoxDecoration(color: fb.accentSoft, borderRadius: BorderRadius.circular(9)), child: Center(child: FbIcon(howtos[i][0], size: 17, color: fb.accent))),
                      const SizedBox(width: 13),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(howtos[i][1], style: fb.ui(size: 14.5, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(howtos[i][2], style: fb.ui(size: 13, color: fb.inkSoft, height: 1.45)),
                      ])),
                    ])),
                ]),
                const SizedBox(height: 22),
                _card(fb, app.t('help_glossary'), [
                  for (int i = 0; i < glossary.length; i++)
                    _row(fb, last: i == glossary.length - 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(glossary[i][0], style: fb.display(size: 17, weight: FontWeight.w600, color: fb.accent)),
                      const SizedBox(height: 3),
                      Text(glossary[i][1], style: fb.ui(size: 13.5, color: fb.inkSoft, height: 1.5)),
                    ])),
                ]),
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(app.t('version'), style: fb.ui(size: 12.5, color: fb.inkFaint)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(FbTheme fb, String label, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Text(label.toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.5))),
          Container(decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), boxShadow: fb.shadow), clipBehavior: Clip.antiAlias, child: Column(children: children)),
        ],
      );

  Widget _row(FbTheme fb, {required Widget child, required bool last}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: fb.line))),
        child: child,
      );
}
