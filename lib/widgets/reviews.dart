import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/sync/sync_backend.dart' show Review;
import '../data/format.dart';
import '../theme.dart';
import 'common.dart' show Stars;
import 'fb_icon.dart';

/// Reviews (stars + text) on a recipe — one per friend. [canReview] shows your
/// editor (visiting a friend's recipe); [canModerate] shows a delete on each
/// review (you own the recipe). Loads on build.
class ReviewsSection extends StatefulWidget {
  final String recipeId;
  final bool canReview;
  final bool canModerate;
  const ReviewsSection({super.key, required this.recipeId, this.canReview = false, this.canModerate = false});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  bool _editing = false;
  int _stars = 0;
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadReviews(widget.recipeId);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _startEdit(Review? mine) {
    setState(() {
      _stars = mine?.stars ?? 0;
      _text.text = mine?.text ?? '';
      _editing = true;
    });
  }

  Future<void> _save(AppState app) async {
    if (_stars < 1) return;
    setState(() => _saving = true);
    await app.submitReview(widget.recipeId, _stars, _text.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.fb;
    final app = context.watch<AppState>();
    final lang = app.lang;
    final all = app.reviewsFor(widget.recipeId);
    final mine = app.myReview(widget.recipeId);
    final me = app.account?.id;
    // others = everyone but me when I have my own editor; otherwise all
    final others = all.where((c) => !widget.canReview || c.authorId != me).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Row(children: [
          Text(app.t('reviews'), style: fb.display(size: 22, weight: FontWeight.w600)),
          if (all.isNotEmpty) ...[
            const SizedBox(width: 9),
            Text('${all.length}', style: fb.ui(size: 13, weight: FontWeight.w700, color: fb.inkFaint)),
          ],
        ]),
        const SizedBox(height: 14),

        // your review editor (visiting a friend's recipe)
        if (widget.canReview)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(color: fb.card, borderRadius: BorderRadius.circular(18), boxShadow: fb.shadow, border: Border.all(color: fb.accent.withValues(alpha: 0.2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.t('your_review').toUpperCase(), style: fb.ui(size: 12, weight: FontWeight.w700, color: fb.inkFaint, letterSpacing: 0.4)),
                const SizedBox(height: 10),
                if (mine != null && !_editing) ...[
                  Row(children: [
                    Stars(value: mine.stars, size: fb.fs(18)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _startEdit(mine),
                      behavior: HitTestBehavior.opaque,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        FbIcon('pencil', size: fb.fs(14), color: fb.accent),
                        const SizedBox(width: 5),
                        Text(app.t('edit_review'), style: fb.ui(size: 13, weight: FontWeight.w700, color: fb.accent)),
                      ]),
                    ),
                  ]),
                  if (mine.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(mine.text, style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.5))),
                ] else ...[
                  Stars(value: _stars, size: fb.fs(26), gap: 5, interactive: true, onChange: (v) => setState(() => _stars = v)),
                  const SizedBox(height: 11),
                  TextField(
                    controller: _text,
                    minLines: 2,
                    maxLines: 4,
                    style: fb.ui(size: 14.5, height: 1.5),
                    decoration: InputDecoration(
                      hintText: app.t('review_ph'),
                      hintStyle: fb.ui(size: 14.5, color: fb.inkFaint),
                      isDense: true,
                      filled: true,
                      fillColor: fb.canvas2,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fb.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fb.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: fb.accent)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _stars < 1 || _saving ? null : () => _save(app),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(color: _stars < 1 ? fb.line : fb.accent, borderRadius: BorderRadius.circular(11)),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(app.t('save_review'), style: fb.ui(size: 14.5, weight: FontWeight.w700, color: _stars < 1 ? fb.inkFaint : Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // others' reviews
        if (others.isEmpty && mine == null)
          Text(app.t('no_reviews'), style: fb.ui(size: 14, color: fb.inkFaint, fontStyle: FontStyle.italic))
        else
          for (final c in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(color: fb.cardSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: fb.line)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: fb.accent, shape: BoxShape.circle), alignment: Alignment.center, child: Text((c.authorUsername?.isNotEmpty == true ? c.authorUsername! : '?').characters.first.toUpperCase(), style: fb.display(size: 16, weight: FontWeight.w600, color: Colors.white))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text('@${c.authorUsername ?? '…'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: fb.ui(size: 14.5, weight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            Text(fmtRelDate(c.updatedAt.toIso8601String(), lang), style: fb.ui(size: 11.5, color: fb.inkFaint)),
                            if (widget.canModerate) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () => app.deleteReview(widget.recipeId, c.id),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(padding: const EdgeInsets.all(3), child: FbIcon('trash', size: fb.fs(16), color: fb.inkFaint)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          Stars(value: c.stars, size: fb.fs(14)),
                          if (c.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text(c.text, style: fb.ui(size: 14.5, color: fb.inkSoft, height: 1.5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
