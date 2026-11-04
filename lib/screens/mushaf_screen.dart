import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/bookmark_store.dart';
import '../data/quran_repository.dart';
import '../data/reading_prefs.dart';
import '../state/settings_state.dart';
import '../theme.dart';
import '../utils/nav.dart';
import '../utils/arabic_numerals.dart';
import '../widgets/ayah_sheet.dart';
import 'mushaf_index_screen.dart';

/// The reader, paged like a physical mushaf: 604 pages, turned horizontally
/// by default (vertically if the reader prefers). Text and boundaries are
/// offline; only tafsir and recitation touch the network.
///
/// Each page is exactly one screen — a mushaf page, not a scroll. The
/// Madani mushaf keeps fifteen lines a page because it was typeset that
/// way; we have the words and the page breaks but not the glyph layout, so
/// each page is filled by fitting two things together: the font size, and
/// the leading between lines. The text is justified, and the leading is
/// then opened up just enough that the last line lands on the bottom
/// margin. Nothing to scroll to, and no slack left under the last ayah.
///
/// Tafsir is opened by pressing and dragging: hold on an ayah, drag across
/// the run you want, let go. A plain tap does nothing — it is too easy to
/// do by accident while turning pages.
class MushafScreen extends StatefulWidget {
  final int initialSurah;
  final int initialAyah;
  const MushafScreen({super.key, this.initialSurah = 1, this.initialAyah = 1});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

/// Font-size band, the leading the font is fitted at, and the ceiling the
/// leading may be opened to when a page has room to spare.
const double _kMinFont = 16;
const double _kMaxFont = 30;
const double _kBaseLeading = 1.6;
const double _kMaxLeading = 2.5;

/// Total width of an ayah mark as a multiple of the font size, margins
/// included — measurement has to reserve exactly this.
const double _kMarkWidth = 1.44;

class _MushafScreenState extends State<MushafScreen> {
  Color get _gold => AppColors.gold;

  late int _page =
      QuranRepo.pageOfAyah(AyahRef(widget.initialSurah, widget.initialAyah));
  late final PageController _controller = PageController(initialPage: _page - 1);

  /// The contiguous run under the finger during a press-drag, in mushaf
  /// order. Empty except while selecting or while the tafsir sheet is open.
  List<AyahRef> _selected = const [];
  AyahRef? _dragAnchor;

  /// The RichText of the *current* page, for hit-testing a drag to an ayah.
  final GlobalKey _textKey = GlobalKey();

  /// page|WxH -> fitted (font, leading). Fitting walks a handful of
  /// TextPainters, so it is done once per page per box and not on every
  /// selection rebuild.
  final Map<String, ({double font, double leading})> _layoutCache = {};

  ReadingMode _mode = ReadingMode.horizontal;
  AyahRef? _bookmark;

  @override
  void initState() {
    super.initState();
    BookmarkStore.read().then((b) {
      if (mounted) setState(() => _bookmark = b);
    });
    ReadingPrefs.read().then((m) {
      if (mounted) setState(() => _mode = m);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _selected = const [];
      _dragAnchor = null;
    });
    if (_controller.hasClients) _controller.jumpToPage(page - 1);
  }

  Future<void> _openIndex() async {
    final picked = await Navigator.of(context).push<AyahRef>(
      fadeThrough(MushafIndexScreen(currentSurah: _page)),
    );
    if (picked != null) _goToPage(QuranRepo.pageOfAyah(picked));
  }

  Future<void> _toggleMode() async {
    final strings = context.read<SettingsState>().strings;
    final next = _mode == ReadingMode.horizontal
        ? ReadingMode.vertical
        : ReadingMode.horizontal;
    await ReadingPrefs.save(next);
    if (!mounted) return;
    setState(() => _mode = next);
    _toast('${strings.pageMode}: ${next.label(strings)}');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Text(message, style: uiFont(size: 15, color: Colors.white)),
    ));
  }

  /// Asks before saving — the bookmark is a single slot, so confirming
  /// stops a stray press from silently throwing away the saved place.
  Future<void> _confirmBookmark() async {
    final strings = context.read<SettingsState>().strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(strings.setBookmark,
            style:
                uiFont(size: 19, weight: FontWeight.w600, color: AppColors.ink)),
        content: Text('${strings.bookmarkAsk} (${ar(_page)})؟',
            style: uiFont(size: 16, color: AppColors.ink2, height: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                Text(strings.no, style: uiFont(size: 16, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.yes,
                style: uiFont(
                    size: 16, weight: FontWeight.w600, color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final ref = QuranRepo.pageStart(_page);
    await BookmarkStore.save(ref);
    if (!mounted) return;
    setState(() => _bookmark = ref);
    _toast('${strings.bookmarkSet} ${ar(_page)}');
  }

  /// Jumping to the saved page loses where you are now, so it asks first —
  /// the same courtesy as saving a bookmark over an old one.
  Future<void> _confirmJumpToBookmark(int bookmarkPage) async {
    final strings = context.read<SettingsState>().strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(strings.backToBookmark,
            style:
                uiFont(size: 19, weight: FontWeight.w600, color: AppColors.ink)),
        content: Text(
          '${strings.jumpToBookmarkAsk} (${strings.page} ${ar(bookmarkPage)})؟',
          style: uiFont(size: 16, color: AppColors.ink2, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                Text(strings.no, style: uiFont(size: 16, color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.yes,
                style: uiFont(
                    size: 16, weight: FontWeight.w600, color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _goToPage(bookmarkPage);
    _toast('${strings.returnedTo} ${ar(bookmarkPage)}');
  }

  // ------------------------------------------------------------------
  // Layout: one screen per page, no scroll, no slack
  // ------------------------------------------------------------------

  /// Builds the page's spans once, plus the character range of every verse
  /// so a drag position can be turned back into an ayah. Each ayah mark is
  /// one placeholder character in the plain text, which is what
  /// `RenderParagraph.getPositionForOffset` counts it as.
  ///
  /// The verse text carries no trailing space: a space there gets stretched
  /// by justification and opens a gap beside the mark. The breathing room
  /// around the mark is fixed margin on the widget instead, so the stretch
  /// stays where it belongs — between the words.
  ({List<InlineSpan> spans, Map<AyahRef, List<int>> ranges}) _compose(
      List<AyahRef> refs, double fontSize) {
    final spans = <InlineSpan>[];
    final ranges = <AyahRef, List<int>>{};
    var cursor = 0;
    for (final ref in refs) {
      final verse = QuranRepo.verse(ref.surah, ref.ayah);
      final selected = _selected.contains(ref);
      ranges[ref] = [cursor, cursor + verse.length];
      cursor += verse.length + 1; // +1 for the mark placeholder

      spans.add(TextSpan(
        text: verse,
        style: selected
            ? TextStyle(backgroundColor: AppColors.gold.withOpacity(.16))
            : null,
      ));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AyahMark(
            n: ref.ayah, size: fontSize, active: selected, gold: AppColors.gold),
      ));
    }
    return (spans: spans, ranges: ranges);
  }

  /// The (font, leading) that fills a [maxW] x [maxH] box with the page's
  /// justified text and nothing left over.
  ///
  /// Two steps: binary-search the largest font that fits at a tight
  /// leading, then open the leading back up so the text reaches the bottom
  /// margin. Cached by page and box so selection rebuilds are free.
  ({double font, double leading}) _fitLayout(
      int page, List<AyahRef> refs, double maxW, double maxH) {
    final key = '$page|${maxW.round()}x${maxH.round()}';
    final hit = _layoutCache[key];
    if (hit != null) return hit;

    final scaler = MediaQuery.textScalerOf(context);
    double measure(double font, double leading) {
      final composed = _compose(refs, font);
      final tp = TextPainter(
        text: TextSpan(
          children: composed.spans,
          style: quranFont(size: font, height: leading, color: AppColors.ink),
        ),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        textScaler: scaler,
      )..setPlaceholderDimensions(List.filled(
          refs.length,
          PlaceholderDimensions(
            size: Size(font * _kMarkWidth, font),
            alignment: PlaceholderAlignment.middle,
          ),
        ));
      tp.layout(maxWidth: maxW);
      final h = tp.height;
      tp.dispose();
      return h;
    }

    // A few pixels of headroom: a line box does not scale perfectly
    // linearly with the height multiplier — Amiri's tall diacritics on the
    // first and last line push past a target set to the exact box — so the
    // fit aims a little under and the page still reads as full.
    final safeH = maxH - 10;

    double lo = _kMinFont, hi = _kMaxFont, font = _kMinFont;
    for (var i = 0; i < 8; i++) {
      final mid = (lo + hi) / 2;
      if (measure(mid, _kBaseLeading) <= safeH) {
        font = mid;
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final h0 = measure(font, _kBaseLeading);
    final leading = h0 <= 0
        ? _kBaseLeading
        : (_kBaseLeading * safeH / h0).clamp(_kBaseLeading, _kMaxLeading);

    return _layoutCache[key] = (font: font, leading: leading);
  }

  // ------------------------------------------------------------------
  // Press-and-drag selection
  // ------------------------------------------------------------------

  /// The ayah under [local] (RichText-local coordinates), clamped to the
  /// first/last on the page when the finger is above or below the text.
  AyahRef? _ayahAt(Offset local, Map<AyahRef, List<int>> ranges) {
    final ro = _textKey.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || ranges.isEmpty) return null;
    final offset = ro.getPositionForOffset(local).offset;
    final entries = ranges.entries.toList();
    if (offset <= 0) return entries.first.key;
    if (offset >= entries.last.value[1] + 1) return entries.last.key;
    for (final e in entries) {
      if (offset >= e.value[0] && offset <= e.value[1] + 1) return e.key;
    }
    return entries.last.key;
  }

  /// The run from [a] to [b] inclusive, in page order.
  List<AyahRef> _run(AyahRef a, AyahRef b) {
    final onPage = QuranRepo.ayatOnPage(_page);
    final i = onPage.indexOf(a), j = onPage.indexOf(b);
    if (i < 0 || j < 0) return [b];
    final lo = i < j ? i : j, hi = i < j ? j : i;
    return onPage.sublist(lo, hi + 1);
  }

  void _dragStart(Offset local, Map<AyahRef, List<int>> ranges) {
    final ref = _ayahAt(local, ranges);
    if (ref == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dragAnchor = ref;
      _selected = [ref];
    });
  }

  void _dragUpdate(Offset local, Map<AyahRef, List<int>> ranges) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final ref = _ayahAt(local, ranges);
    if (ref == null) return;
    final run = _run(anchor, ref);
    if (run.length != _selected.length) {
      HapticFeedback.selectionClick();
      setState(() => _selected = run);
    }
  }

  Future<void> _dragEnd() async {
    final run = _selected;
    _dragAnchor = null;
    if (run.isEmpty) return;
    await AyahSheet.show(context, run);
    if (mounted) setState(() => _selected = const []);
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<SettingsState>().strings;
    final bookmark = _bookmark;
    final bookmarkPage =
        bookmark == null ? null : QuranRepo.pageOfAyah(bookmark);
    final onBookmarkedPage = bookmarkPage == _page;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            QuranRepo.surahsOnPage(_page).map(QuranRepo.surahName).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                uiFont(size: 18, weight: FontWeight.w600, color: AppColors.ink),
          ),
          Text(
            '${strings.juz} ${ar(QuranRepo.juzOfPage(_page))} · '
            '${strings.hizb} ${ar(QuranRepo.hizbOfPage(_page))}',
            style: uiFont(size: 14, color: AppColors.ink3),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: '${strings.pageMode}: ${_mode.label(strings)}',
            icon: Icon(
              _mode == ReadingMode.horizontal
                  ? Icons.swap_horiz_rounded
                  : Icons.swap_vert_rounded,
              size: 24,
            ),
            onPressed: _toggleMode,
          ),
          if (bookmarkPage != null && !onBookmarkedPage)
            IconButton(
              tooltip:
                  '${strings.backToBookmark} (${strings.page} ${ar(bookmarkPage)})',
              icon: Icon(Icons.bookmark_rounded, size: 24, color: _gold),
              onPressed: () => _confirmJumpToBookmark(bookmarkPage),
            ),
          IconButton(
            tooltip: strings.setBookmark,
            icon: Icon(
              onBookmarkedPage
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_add_outlined,
              size: 24,
              color: onBookmarkedPage ? _gold : null,
            ),
            onPressed: _confirmBookmark,
          ),
          IconButton(
            tooltip: strings.index,
            icon: const Icon(Icons.menu_book_outlined, size: 24),
            onPressed: _openIndex,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        scrollDirection: _mode.axis,
        itemCount: QuranRepo.pageCount,
        onPageChanged: (i) => setState(() {
          _page = i + 1;
          _selected = const [];
          _dragAnchor = null;
        }),
        itemBuilder: (context, i) => _MushafPage(
          i + 1,
          bookmarked: bookmarkPage == i + 1,
          host: this,
        ),
      ),
    );
  }
}

/// One mushaf page: the justified text filling the space edge to edge, a
/// hairline footer with the hizb and the page number, and — when the page
/// is bookmarked — a gilded fore-edge down its outer margin. It never
/// scrolls.
class _MushafPage extends StatelessWidget {
  final int page;
  final bool bookmarked;
  final _MushafScreenState host;
  const _MushafPage(this.page, {required this.bookmarked, required this.host});

  bool get _isCurrent => page == host._page;

  @override
  Widget build(BuildContext context) {
    // Watched so the page rebuilds if the interface language changes.
    context.watch<SettingsState>();
    final refs = QuranRepo.ayatOnPage(page);
    final surahs = QuranRepo.surahsOnPage(page);

    // Surah banners + basmala for any surah that opens on this page. They
    // sit above the text as part of the same centred block, and their
    // height is taken out of what the text is fitted into.
    final openings = <Widget>[];
    var openingsHeight = 0.0;
    for (final surah in surahs) {
      final opensHere = refs.first.surah != surah || refs.first.ayah == 1;
      if (!opensHere) continue;
      openings.add(_surahBanner(surah));
      openingsHeight += 60;
      if (QuranRepo.showsBasmala(surah)) {
        openings.add(const SizedBox(height: 10));
        openings.add(Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textAlign: TextAlign.center,
            style: quranFont(size: 21, color: AppColors.gold)));
        openingsHeight += 46;
      }
      openings.add(const SizedBox(height: 14));
      openingsHeight += 14;
    }

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 2),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final l = host._fitLayout(page, refs, box.maxWidth,
                        box.maxHeight - openingsHeight);
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...openings,
                          _text(context, refs, l.font, l.leading, box.maxWidth),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            _footer(),
          ],
        ),
        if (bookmarked)
          const Positioned(left: 0, top: 0, bottom: 0, child: _GiltEdge()),
      ],
    );
  }

  // Just the page number, centred. The hizb it used to carry sits in the
  // app-bar subtitle now, and printing it twice was clutter.
  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
        child: Center(
          child: Text(ar(page),
              style: uiFont(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: AppColors.ink3)),
        ),
      );

  Widget _surahBanner(int surah) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x33785A28)),
            bottom: BorderSide(color: Color(0x33785A28)),
          ),
        ),
        child: Text(QuranRepo.surahName(surah),
            textAlign: TextAlign.center,
            style: quranFont(size: 22, color: AppColors.ink2)),
      );

  Widget _text(BuildContext context, List<AyahRef> refs, double fontSize,
      double leading, double width) {
    final composed = host._compose(refs, fontSize);
    // A page dense enough to have real lines reads best fully justified,
    // the way the printed page is set. A sparse page — few ayat, big font —
    // has only two or three words a line, and justifying it just tears
    // rivers of white through the text, so it is centred instead.
    final justified = fontSize <= 26;
    final rich = RichText(
      key: _isCurrent ? host._textKey : null,
      textAlign: justified ? TextAlign.justify : TextAlign.center,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        children: composed.spans,
        style:
            quranFont(size: fontSize, height: leading, color: AppColors.ink),
      ),
    );

    final sized = SizedBox(width: width, child: rich);
    if (!_isCurrent) return sized;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => host._dragStart(d.localPosition, composed.ranges),
      onLongPressMoveUpdate: (d) =>
          host._dragUpdate(d.localPosition, composed.ranges),
      onLongPressEnd: (_) => host._dragEnd(),
      child: sized,
    );
  }
}

/// The ayah-end mark: the scalloped medallion a printed mushaf sets between
/// verses — one continuous flower-edged outline with the number inside, not
/// a scatter of dots. It fills gold while the ayah is in the current
/// selection.
class _AyahMark extends StatelessWidget {
  final int n;
  final double size;
  final bool active;
  final Color gold;
  const _AyahMark(
      {required this.n,
      required this.size,
      required this.active,
      required this.gold});

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.symmetric(horizontal: size * 0.16),
        width: size * 1.12,
        height: size * 1.12,
        alignment: Alignment.center,
        child: CustomPaint(
          size: Size(size * 1.12, size * 1.12),
          painter: _AyahMarkPainter(active: active, gold: gold),
          child: Center(
            child: Text(
              ar(n),
              textDirection: TextDirection.rtl,
              style: uiFont(
                size: size * 0.4,
                weight: FontWeight.w600,
                color: active ? Colors.white : gold,
              ),
            ),
          ),
        ),
      );
}

class _AyahMarkPainter extends CustomPainter {
  final bool active;
  final Color gold;
  const _AyahMarkPainter({required this.active, required this.gold});

  /// A closed scalloped circle: the radius swells and dips [petals] times
  /// around the turn, giving the medallion its flower edge.
  Path _scallop(Offset c, double base, int petals, double amp) {
    final path = Path();
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final r = base + amp * math.cos(petals * t);
      final p = c + Offset(math.cos(t), math.sin(t)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // A shallow scallop: mostly a circle, its edge just barely fluted, the
    // way a printed medallion is — not a cog.
    final outline = _scallop(c, r * 0.86, 11, r * 0.055);

    if (active) {
      canvas.drawPath(outline, Paint()..color = gold);
    } else {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.1, r * 0.085)
          ..strokeJoin = StrokeJoin.round
          ..color = gold,
      );
      // A hairline inner ring, the way the printed medallion is drawn.
      canvas.drawCircle(
        c,
        r * 0.58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, r * 0.045)
          ..color = gold.withOpacity(.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AyahMarkPainter old) =>
      old.active != active || old.gold != gold;
}

/// The mark for a bookmarked page: the gilded fore-edge of a fine mushaf.
/// Gold bleeds in from the outer margin and fades into the page, with a
/// short solid tab sitting flush to the very edge — a place kept, without a
/// paper flap drawn over the text.
class _GiltEdge extends StatelessWidget {
  const _GiltEdge();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.gold.withOpacity(.26),
                  AppColors.gold.withOpacity(0),
                ],
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 3.5,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(3)),
                ),
              ),
            ),
          ),
        ),
      );
}
