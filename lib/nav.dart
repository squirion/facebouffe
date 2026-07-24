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
/// Route names feed the crash-log breadcrumbs (CrashNavObserver).
class Nav {
  static RouteSettings _s(String name) => RouteSettings(name: name);

  static Future<void> openRecipe(BuildContext context, String id, {bool replace = false, bool visiting = false, String? ownerName}) {
    final route = MaterialPageRoute(settings: _s('recipe'), builder: (_) => RecipeScreen(id: id, visiting: visiting, ownerName: ownerName));
    return replace ? Navigator.pushReplacement(context, route) : Navigator.push(context, route);
  }

  static Future<void> openFriendCookbook(BuildContext context, String friendId, String username) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('cookbook'), builder: (_) => FriendCookbookScreen(friendId: friendId, username: username)));

  static Future<void> cook(BuildContext context, String id, int servings) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('souschef'), builder: (_) => SousChefScreen(id: id, servings: servings)));

  static Future<void> editRecipe(BuildContext context, String id) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('edit'), builder: (_) => EditScreen(id: id)));

  static Future<void> addRecipe(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('edit-new'), builder: (_) => const EditScreen()));

  /// Open the editor pre-filled with an unsaved recipe (e.g. from web import).
  static Future<void> editRecipeInitial(BuildContext context, Recipe recipe) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('edit-import'), builder: (_) => EditScreen(initial: recipe)));

  static Future<void> openFilter(BuildContext context, String tagId) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('filter'), builder: (_) => FilterScreen(tagId: tagId)));

  static Future<void> openHelp(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('help'), builder: (_) => const HelpScreen()));

  static Future<void> openAdvanced(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('advanced'), builder: (_) => const AdvancedSettingsScreen()));

  static Future<void> openAiImport(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('ai-import'), builder: (_) => const AIImportAssistantScreen()));

  static Future<void> openRecentlyDeleted(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('trash'), builder: (_) => const RecentlyDeletedScreen()));

  static Future<void> openAdventure(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('adventure'), builder: (_) => const AdventureScreen()));

  static Future<void> openMutation(BuildContext context, String baseId) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('mutation'), builder: (_) => AdventureScreen(baseId: baseId)));

  static Future<void> openSignIn(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('signin'), builder: (_) => const SignInScreen()));

  static Future<void> openAccount(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('account'), builder: (_) => const AccountScreen()));

  static Future<void> openFriends(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(settings: _s('friends'), builder: (_) => const FriendsScreen()));

  /// Fullscreen swipeable gallery viewer, opened from a recipe's gallery tiles.
  static Future<void> openGallery(BuildContext context, List<String> images, int index) =>
      Navigator.push(context, PageRouteBuilder(
        settings: _s('gallery'),
        opaque: true,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
        pageBuilder: (_, _, _) => GalleryViewerScreen(images: images, initialIndex: index),
      ));
}
