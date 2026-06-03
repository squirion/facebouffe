import 'package:flutter/material.dart';

import 'data/models.dart' show Recipe;
import 'screens/recipe_screen.dart';
import 'screens/souschef_screen.dart';
import 'screens/edit_screen.dart';
import 'screens/filter_screen.dart';
import 'screens/help_screen.dart';
import 'screens/advanced_settings_screen.dart';
import 'screens/ai_import_settings_screen.dart';
import 'screens/recently_deleted_screen.dart';
import 'screens/adventure_screen.dart';
import 'screens/gallery_viewer.dart';
import 'screens/account_screens.dart';
import 'screens/friends_screen.dart';
import 'screens/friend_cookbook_screen.dart';

/// Thin navigation layer over the root Navigator. Uses platform-default page
/// transitions (Material fade-through / Cupertino slide) per the brief.
class Nav {
  static Future<void> openRecipe(BuildContext context, String id, {bool replace = false, bool visiting = false, String? ownerName}) {
    final route = MaterialPageRoute(builder: (_) => RecipeScreen(id: id, visiting: visiting, ownerName: ownerName));
    return replace ? Navigator.pushReplacement(context, route) : Navigator.push(context, route);
  }

  static Future<void> openFriendCookbook(BuildContext context, String friendId, String username) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => FriendCookbookScreen(friendId: friendId, username: username)));

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

  static Future<void> openAiImport(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AIImportAssistantScreen()));

  static Future<void> openRecentlyDeleted(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RecentlyDeletedScreen()));

  static Future<void> openAdventure(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdventureScreen()));

  static Future<void> openMutation(BuildContext context, String baseId) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureScreen(baseId: baseId)));

  static Future<void> openSignIn(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));

  static Future<void> openAccount(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));

  static Future<void> openFriends(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen()));

  /// Fullscreen swipeable gallery viewer, opened from a recipe's gallery tiles.
  static Future<void> openGallery(BuildContext context, List<String> images, int index) =>
      Navigator.push(context, PageRouteBuilder(
        opaque: true,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        pageBuilder: (_, _, _) => GalleryViewerScreen(images: images, initialIndex: index),
      ));
}
