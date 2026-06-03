import 'package:flutter/material.dart';

/// Maps the mockup's named glyphs to recognizable Material icons.
/// `fill` swaps to a filled variant where one exists (star, home).
class FbIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final bool fill;
  const FbIcon(this.name, {super.key, this.size = 22, this.color, this.fill = false});

  static const _outline = {
    'home': Icons.home_outlined,
    'search': Icons.search,
    'basket': Icons.shopping_basket_outlined,
    'sliders': Icons.tune,
    'star': Icons.star_border_rounded,
    'plus': Icons.add,
    'minus': Icons.remove,
    'chevL': Icons.chevron_left,
    'chevR': Icons.chevron_right,
    'chevD': Icons.keyboard_arrow_down,
    'x': Icons.close,
    'check': Icons.check,
    'clock': Icons.schedule,
    'users': Icons.people_outline,
    'user': Icons.person_outline,
    'flame': Icons.local_fire_department_outlined,
    'pencil': Icons.edit_outlined,
    'trash': Icons.delete_outline,
    'timer': Icons.timer_outlined,
    'play': Icons.play_arrow_rounded,
    'link': Icons.link,
    'more': Icons.more_horiz,
    'camera': Icons.photo_camera_outlined,
    'arrowL': Icons.arrow_back,
    'back': Icons.arrow_back_ios_new_rounded,
    'note': Icons.description_outlined,
    'sunrise': Icons.wb_twilight,
    'utensils': Icons.restaurant,
    'cake': Icons.cake_outlined,
    'shrimp': Icons.set_meal,
    'bowl': Icons.soup_kitchen,
    'leaf': Icons.eco_outlined,
    'dumbbell': Icons.fitness_center,
    'drag': Icons.drag_indicator,
    'refresh': Icons.refresh,
    'download': Icons.download_rounded,
    'sparkles': Icons.auto_awesome_outlined,
  };

  static const _filled = {
    'home': Icons.home_rounded,
    'star': Icons.star_rounded,
    'flame': Icons.local_fire_department,
    'check': Icons.check,
    'play': Icons.play_arrow_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final data = (fill ? _filled[name] : null) ?? _outline[name] ?? Icons.help_outline;
    return Icon(data, size: size, color: color ?? const Color(0xFF2B2620));
  }
}
