import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/dhikr.dart';
import 'adhkar_generated.dart';

// Dhikr text and repetition counts now come from adhkar_generated.dart,
// which tool/generate_adhkar.py produces from the official Hisn al-Muslim
// data. What stays in this file is presentation metadata only: which
// categories exist, what they are called, and how they look.
//
// Do not add dhikr text here. Add the chapter to the generator and re-run it.

/// One entry in the "الأذكار" category grid on the home screen.
class CategoryMeta {
  final String key;
  final String name;
  final IconData icon;
  final Color tint;
  const CategoryMeta({required this.key, required this.name, required this.icon, required this.tint});
}

/// key -> its dhikr list. Both [morning] and [evening] live here too so
/// the category grid and the time-based home-card preview share one
/// source of truth for "how many items, how many done".
final Map<String, List<DhikrItem>> adhkarSets = {
  'morning': morningAdhkar,
  'evening': eveningAdhkar,
  'afterPrayer': afterPrayerAdhkar,
  'mosque': mosqueAdhkar,
  'sleep': sleepAdhkar,
  'waking': wakingAdhkar,
  'travel': travelAdhkar,
  'food': foodAdhkar,
  'distress': distressAdhkar,
};

/// Display order for the category grid. Morning/evening lead the grid so
/// they're reachable even outside their own time window.
///
/// Icons come from Lucide, not Material. Material's outlined set silently
/// falls back to a solid silhouette for shapes like a crescent, a person or
/// a plane, so half the grid stayed filled however it was labelled. Lucide
/// is drawn as strokes with rounded caps throughout, which is the look this
/// grid needs; the tints are the only thing that varies between cards.
/// Ordered the way a day runs, with the two that are read every day at the
/// front: morning, evening, then waking, and the rest in the order they
/// come up — ending on sleep, which closes the day the way waking opens it.
/// This one list drives the home rail, the grid and the categories screen,
/// so they cannot drift into three different orders.
final List<CategoryMeta> catalog = [
  const CategoryMeta(key: 'morning', name: 'الصباح', icon: LucideIcons.sun, tint: Color(0xFFC2913A)),
  const CategoryMeta(key: 'evening', name: 'المساء', icon: LucideIcons.moonStar, tint: Color(0xFF3D54A0)),
  const CategoryMeta(key: 'waking', name: 'الاستيقاظ', icon: LucideIcons.sunrise, tint: Color(0xFFE0915C)),
  const CategoryMeta(key: 'afterPrayer', name: 'بعد الصلاة', icon: LucideIcons.handHelping, tint: Color(0xFFC2913A)),
  const CategoryMeta(key: 'mosque', name: 'المسجد', icon: LucideIcons.mosque, tint: Color(0xFF5B8F6D)),
  const CategoryMeta(key: 'travel', name: 'السفر', icon: LucideIcons.planeTakeoff, tint: Color(0xFF9C9086)),
  const CategoryMeta(key: 'food', name: 'الطعام', icon: LucideIcons.utensils, tint: Color(0xFF9C9086)),
  const CategoryMeta(key: 'distress', name: 'الهمّ والكرب', icon: LucideIcons.heartPulse, tint: Color(0xFF5B8F6D)),
  const CategoryMeta(key: 'sleep', name: 'النوم', icon: LucideIcons.bedDouble, tint: Color(0xFF3D54A0)),
];
