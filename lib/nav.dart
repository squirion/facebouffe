import 'package:flutter/material.dart';

import 'data/models.dart' show Recipe;
import 'screens/recipe_screen.dart';
import 'screens/souschef_screen.dart';
import 'screens/edit_screen.dart';
import 'screens/filter_screen.dart';
import 'screens/help_screen.dart';
import 'screens/advanced_settings_screen.dart';
import 'screens/gallery_viewer.dart';

/// Thin navigation layer over the root Navigator. Uses platform-default page
/// transitions (Material fade-through / Cupertino slide) per the brief.
class Nav {
  static Future<void> openRecipe(BuildContext context, String id, {bool replace = false}) {
    final route = MaterialPageRoute(builder: (_) => RecipeScreen(id: id));
    return replace ? Navigator.pushReplacement(context, route) : Navigator.push(context, route);
  }

  static Future<void> cook(BuildContext context, String id, int servings) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SousChefScreen(id: id, servings: servings)));

  static Future<void> editRecipe(BuildContext context, String id) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => EditScreen(id: id)));

  static Future<void> addRecipe(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const EditScreen()));

  /// Open the editor pre-filled with an unsaved recipe (e.g. from web import).
  static Future<void> editRecipeInitial(BuildContext context, Recipe recipe) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => EditScreen(initial: recipe)));

  static Future<void> openFilter(BuildContext context, String tagId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => FilterScreen(tagId: tagId)));

  static Future<void> openHelp(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));

  static Future<void> openAdvanced(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedSettingsScreen()));

  /// Fullscreen swipeable gallery viewer, opened from a recipe's gallery tiles.
  static Future<void> openGallery(BuildContext context, List<String> images, int index) =>
      Navigator.push(context, PageRouteBuilder(
        opaque: true,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        pageBuilder: (_, _, _) => GalleryViewerScreen(images: images, initialIndex: index),
      ));
}
